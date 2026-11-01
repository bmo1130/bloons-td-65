param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
function Read-Data([string]$Name) { Get-Content -LiteralPath (Join-Path $ProjectRoot "benchmarks/$Name.json") -Raw | ConvertFrom-Json }
function Match-Row($All,$Row) {
    $matches = @($All | Where-Object {$_.mode -eq $Row.mode -and $_.speed -eq $Row.speed -and $_.trial -eq $Row.trial})
    if ($matches.Count -ne 1) { throw "Missing counterpart $($Row.mode)/$($Row.speed)/$($Row.trial)" }
    $matches[0]
}
function Assert-Same($A,$B,[string]$Label) {
    if (($A.fingerprint | ConvertTo-Json -Depth 90 -Compress) -ne ($B.fingerprint | ConvertTo-Json -Depth 90 -Compress)) { throw "Combat changed: $Label" }
}
function Aggregate($Group) {
    $samples = @($Group | ForEach-Object {$_.samples_ms})
    $mean = ($samples | Measure-Object -Average).Average
    $sorted = @($samples | Sort-Object)
    $variance = ($samples | ForEach-Object {($_ - $mean)*($_ - $mean)} | Measure-Object -Average).Average
    @{mean=$mean;p95=$sorted[[math]::Ceiling($sorted.Count*.95)-1];max=($samples|Measure-Object -Maximum).Maximum;stddev=[math]::Sqrt($variance);samples=$samples.Count;trial_means=@($Group|ForEach-Object {$_.mean_ms})}
}
$cpu = Read-Data 'boomerang-v014-after-cpu'
$render = Read-Data 'boomerang-v014-after-render'
$pairs = @{cpu_render=0;local_before_after=0;blitz_v012=0}
foreach ($row in $cpu.rows) { Assert-Same $row (Match-Row $render.rows $row) 'newCPU/render'; $pairs.cpu_render++ }
$summary = @()
foreach ($surface in @('cpu','render')) {
    $before = Read-Data "boomerang-v014-before-$surface"
    $after = if ($surface -eq 'cpu') {$cpu} else {$render}
    foreach ($row in $before.rows) { Assert-Same $row (Match-Row $after.rows $row) 'localBefore/after'; $pairs.local_before_after++ }
    $legacy = Read-Data "bomb-v012-$surface"
    foreach ($row in @($after.rows | Where-Object {$_.mode -eq 'bomb_blitz_mix10'})) { Assert-Same $row (Match-Row $legacy.rows $row) 'Blitz/v012'; $pairs.blitz_v012++ }
    foreach ($group in ($after.rows | Group-Object mode,speed)) {
        $first = $group.Group[0]
        $a = Aggregate $group.Group
        $old = @($before.rows | Where-Object {$_.mode -eq $first.mode -and $_.speed -eq $first.speed})
        $b = if ($old.Count -gt 0) {Aggregate $old} else {$null}
        $summary += [pscustomobject]@{surface=$surface;mode=$first.mode;speed=$first.speed;mean=$a.mean;p95=$a.p95;max=$a.max;stddev=$a.stddev;samples=$a.samples;trial_means=$a.trial_means;before_mean=if ($b) {$b.mean} else {$null};before_p95=if ($b) {$b.p95} else {$null}}
    }
}
@{version='v0.14';pairs=$pairs;conditions='240 pooled frames each mean and nearest-rank P95; new stress is not normal campaign FPS; inclusive timers overlap';rows=$summary} | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $ProjectRoot 'benchmarks/boomerang-v014-summary.json') -Encoding utf8
$summary | Select-Object surface,mode,speed,mean,p95,max,stddev,samples,@{Name='trial_means';Expression={$_.trial_means -join ';'}},before_mean,before_p95 | Export-Csv -LiteralPath (Join-Path $ProjectRoot 'benchmarks/boomerang-v014-summary.csv') -NoTypeInformation -Encoding utf8
$components = @()
$fields = @('cpu','movement','tower','trajectory','candidates','narrow','resolution','creation','sort','chain_search_ms','aoe_query_ms','aoe_sort_ms','aoe_damage_ms','effect_update_ms','effect_apply_ms','dot_damage_ms','press_ms','balloon_draw_ms','effect_draw_ms','projectile_draw_ms','projectile_allocations','auxiliary_order_ids','dot_count')
foreach ($surface in @('cpu','render')) {
    $report = if ($surface -eq 'cpu') {$cpu} else {$render}
    foreach ($group in ($report.rows | Group-Object mode,speed)) {
        $first = $group.Group[0]
        $frames = @($group.Group | ForEach-Object {$_.frame_details})
        $entry = [ordered]@{surface=$surface;mode=$first.mode;speed=$first.speed;samples=$frames.Count}
        foreach ($field in $fields) {
            $entry[$field] = if ($frames.Count -gt 0 -and $null -ne $frames[0].PSObject.Properties[$field]) {($frames | ForEach-Object {[double]$_.$field} | Measure-Object -Average).Average} else {$null}
        }
        $entry.dot_count_max = ($frames | ForEach-Object {$_.dot_count} | Measure-Object -Maximum).Maximum
        $components += [pscustomobject]$entry
    }
}
@{conditions='Inclusive component timers in milliseconds overlap; do not sum. Constructor/event counts are allocation proxies, not heap bytes. Sparse DOT population is the observed workload, not1000 simultaneous effects.';rows=$components} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $ProjectRoot 'benchmarks/boomerang-v014-components.json') -Encoding utf8
$components | Export-Csv -LiteralPath (Join-Path $ProjectRoot 'benchmarks/boomerang-v014-components.csv') -NoTypeInformation -Encoding utf8
$summary | Format-Table surface,mode,speed,mean,p95,max,before_mean,before_p95 -AutoSize
Write-Output ('V014 COMPARISON: '+($pairs|ConvertTo-Json -Compress))
