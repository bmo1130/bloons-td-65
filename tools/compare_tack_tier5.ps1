param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop'
function Read-Report([string]$Name) { Get-Content -LiteralPath (Join-Path $ProjectRoot "benchmarks/$Name.json") -Raw | ConvertFrom-Json }
function Signature($Row) { $Row.fingerprint | ConvertTo-Json -Depth 100 -Compress }
# v015 legacy Bomb report predates the auxiliary snapshot inserted at index7
# by tack_benchmark._report. Compare every historical field; current auxiliary
# data remains compared strictly in local-before and CPU/render pairs.
function Historical-Signature($Row) {
    if($Row.mode -eq 'bomb_blitz_mix10' -and $Row.fingerprint.Count -eq 9) {
        $copy=@()
        for($i=0;$i -lt $Row.fingerprint.Count;$i++) { if($i -ne 7) { $copy += ,$Row.fingerprint[$i] } }
        return (ConvertTo-Json -InputObject $copy -Depth 100 -Compress)
    }
    Signature $Row
}
function Match($Rows,$Row) { @($Rows | Where-Object { $_.mode -eq $Row.mode -and $_.balloons -eq $Row.balloons -and $_.speed -eq $Row.speed -and $_.trial -eq $Row.trial }) }
function Aggregate($Rows) {
    $samples=@($Rows | ForEach-Object {$_.samples_ms})
    $sorted=@($samples | Sort-Object)
    $mean=($samples|Measure-Object -Average).Average
    $variance=($samples|ForEach-Object {($_-$mean)*($_-$mean)}|Measure-Object -Average).Average
    [ordered]@{mean_ms=$mean;p95_ms=$sorted[[math]::Ceiling($samples.Count*.95)-1];max_ms=$sorted[-1];stddev_ms=[math]::Sqrt($variance);samples=$samples.Count;trial_means=@($Rows|ForEach-Object {$_.mean_ms})}
}
$cpu=Read-Report 'tack-v016-cpu'
$render=Read-Report 'tack-v016-render'
if($cpu.rows.Count -ne 140 -or $render.rows.Count -ne 140){throw 'Expected140rows per surface'}
$pairs=0
foreach($row in $cpu.rows){
    $other=@(Match $render.rows $row)
    if($other.Count -ne 1 -or (Signature $row) -ne (Signature $other[0])){throw "CPU/render changed $($row.mode)/$($row.balloons)/$($row.speed)/$($row.trial)"}
    $pairs++
}
$beforePairs=0
$historicalPairs=0
$summary=@()
$beforeAfter=@()
foreach($surface in @('cpu','render')){
    $current=if($surface -eq 'cpu'){$cpu}else{$render}
    $before=Read-Report "tack-v016-before-$surface"
    foreach($row in $before.rows){
        $other=@(Match $current.rows $row)
        if($other.Count -ne 1 -or (Signature $row) -ne (Signature $other[0])){throw "Actual local before changed $surface/$($row.mode)/$($row.speed)/$($row.trial)"}
        $beforePairs++
    }
    $history=Read-Report "tack-v015-$surface"
    $bomb=Read-Report "tack-v015-legacy-after-$surface"
    $oldRows=@($history.rows | Where-Object {$_.balloons -eq 1000 -and $_.mode -in @('tack_032','tack_230','boomerang_320')})+@($bomb.rows|Where-Object {$_.mode -eq 'bomb_blitz_mix10'})
    foreach($row in $oldRows){
        $other=@(Match $current.rows $row)
        if($other.Count -ne 1 -or (Signature $row) -ne (Historical-Signature $other[0])){throw "Historical v015 changed $surface/$($row.mode)/$($row.speed)/$($row.trial)"}
        $historicalPairs++
    }
    foreach($group in ($current.rows|Group-Object mode,balloons,speed)){
        $r=$group.Group[0];$pooled=Aggregate $group.Group
        $entry=[ordered]@{surface=$surface;mode=$r.mode;balloons=$r.balloons;speed=$r.speed;mean_ms=$pooled.mean_ms;p95_ms=$pooled.p95_ms;max_ms=$pooled.max_ms;stddev_ms=$pooled.stddev_ms;samples=$pooled.samples;trial_means=$pooled.trial_means}
        foreach($field in @('cpu_mean_ms','candidates_ms','projectile_combat_ms','projectile_allocations_mean','segments_mean','draw_commands_ms','projectiles_mean','projectiles_per_game_second','queries_mean','checks_mean','candidates_mean','tower_ms','creation_ms','removal_ms','grid_ms','trajectory_ms','narrow_ms','resolution_ms','sort_ms','tower_draw_ms_mean','balloon_draw_ms_mean','projectile_draw_ms_mean','objects_mean','static_bytes_mean','draw_calls_mean','active_samples','active_mean_ms','aoe_query_ms_mean','aoe_sort_ms_mean','aoe_damage_ms_mean')){
            $entry[$field]=($group.Group|Measure-Object -Property $field -Average).Average
        }
        $entry.projectiles_max=($group.Group|Measure-Object -Property projectiles_max -Maximum).Maximum
        $summary += [pscustomobject]$entry
    }
    foreach($mode in @('tack_032','tack_230','boomerang_320','bomb_blitz_mix10')){
        foreach($speed in @(1,2)){
            $a=Aggregate @($before.rows|Where-Object {$_.mode -eq $mode -and $_.speed -eq $speed})
            $b=Aggregate @($current.rows|Where-Object {$_.mode -eq $mode -and $_.balloons -eq 1000 -and $_.speed -eq $speed})
            $beforeAfter += [pscustomobject]@{surface=$surface;mode=$mode;speed=$speed;before=$a;after=$b}
        }
    }
}
[ordered]@{cpu_render_pairs=$pairs;actual_local_before_pairs=$beforePairs;historical_v015_pairs=$historicalPairs;historical_bomb_auxiliary_bridge='v015 omits current auxiliary snapshot at index7; every historical field compared; full current auxiliary compared separately';failures=0}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $ProjectRoot 'benchmarks/tack-v016-validation.json') -Encoding utf8
$summary|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $ProjectRoot 'benchmarks/tack-v016-summary.json') -Encoding utf8
$summary|Export-Csv -LiteralPath (Join-Path $ProjectRoot 'benchmarks/tack-v016-summary.csv') -NoTypeInformation -Encoding utf8
$beforeAfter|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $ProjectRoot 'benchmarks/tack-v016-before-after.json') -Encoding utf8
Write-Output "TACK TIER5 COMPARISON COMPLETE:$pairs CPU/render,$beforePairs actual-before,$historicalPairs historical-v015;0failures"

# Applied only after the first unfiltered CPU/render matrix has finished.
$pairs=0
$optimization=@()
foreach($surface in @('cpu','render')) {
    $original=Read-Report "tack-v016-unfiltered-$surface"
    $current=if($surface -eq 'cpu'){$cpu}else{$render}
    foreach($row in $original.rows) {
        $other=@(Match $current.rows $row)
        if($other.Count -ne 1 -or (Signature $row) -ne (Signature $other[0])) { throw "Blade broadphase changed combat $surface/$($row.mode)/$($row.balloons)/$($row.speed)/$($row.trial)" }
        $pairs++
    }
    foreach($group in ($current.rows|Group-Object mode,balloons,speed)) {
        $r=$group.Group[0]
        $old=@($original.rows|Where-Object {$_.mode -eq $r.mode -and $_.balloons -eq $r.balloons -and $_.speed -eq $r.speed})
        $a=Aggregate $old;$b=Aggregate $group.Group
        $optimization += [pscustomobject]@{surface=$surface;mode=$r.mode;balloons=$r.balloons;speed=$r.speed;unfiltered=$a;filtered=$b;unfiltered_checks=($old|Measure-Object checks_mean -Average).Average;filtered_checks=($group.Group|Measure-Object checks_mean -Average).Average;unfiltered_narrow_ms=($old|Measure-Object narrow_ms -Average).Average;filtered_narrow_ms=($group.Group|Measure-Object narrow_ms -Average).Average}
    }
}
$optimization|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $ProjectRoot 'benchmarks/tack-v016-optimization.json') -Encoding utf8
[ordered]@{cpu_render_pairs=140;unfiltered_filtered_pairs=$pairs;actual_local_before_pairs=$beforePairs;historical_v015_pairs=$historicalPairs;historical_bomb_auxiliary_bridge='v015 omits current auxiliary snapshot at index7; every historical field compared; full current auxiliary compared separately';failures=0}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $ProjectRoot 'benchmarks/tack-v016-validation.json') -Encoding utf8
Write-Output "TACK BLADE BROADPHASE COMPLETE:$pairs exact unfiltered/filtered pairs;0failures"
