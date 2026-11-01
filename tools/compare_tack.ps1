param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop'
function Read-Report([string]$Name) { Get-Content -LiteralPath (Join-Path $ProjectRoot "benchmarks/$Name.json") -Raw | ConvertFrom-Json }
function Signature($Row) { $Row.fingerprint | ConvertTo-Json -Depth 100 -Compress }
$cpu=Read-Report 'tack-v015-cpu'
$render=Read-Report 'tack-v015-render'
if ($cpu.rows.Count -ne 72 -or $render.rows.Count -ne 72) { throw 'Expected72 rows per surface' }
$pairs=0
$legacyPairs=0
$beforePairs=0
foreach ($row in $cpu.rows) {
    $other=@($render.rows | Where-Object { $_.mode -eq $row.mode -and $_.balloons -eq $row.balloons -and $_.speed -eq $row.speed -and $_.trial -eq $row.trial })
    if ($other.Count -ne 1 -or (Signature $row) -ne (Signature $other[0])) { throw "CPU/render mismatch: $($row.mode)/$($row.balloons)/$($row.speed)/$($row.trial)" }
    $pairs++
}
foreach ($surface in @('cpu','render')) {
    $old=Read-Report "boomerang-v014-after-$surface"
    $now=Read-Report "tack-v015-legacy-after-$surface"
    if ($old.rows.Count -ne 44 -or $now.rows.Count -ne 44) { throw 'Expected44legacy rows' }
    foreach ($row in $old.rows) {
        $other=@($now.rows | Where-Object { $_.mode -eq $row.mode -and $_.speed -eq $row.speed -and $_.trial -eq $row.trial })
        if ($other.Count -ne 1 -or (Signature $row) -ne (Signature $other[0])) { throw "Legacy14 changed $surface/$($row.mode)/$($row.speed)/$($row.trial)" }
        $legacyPairs++
    }
    $before=Read-Report "tack-v015-before-$surface"
    $now=Read-Report "tack-v015-$surface"
    foreach ($row in $before.rows) {
        $other=@($now.rows | Where-Object { $_.mode -eq 'boomerang_320' -and $_.speed -eq $row.speed -and $_.trial -eq $row.trial })
        if ($other.Count -ne 1 -or (Signature $row) -ne (Signature $other[0])) { throw "Local before320 changed $surface/$($row.speed)/$($row.trial)" }
        $beforePairs++
    }
}
$legacyRenderPairs=0
$legacyCpu=Read-Report 'tack-v015-legacy-after-cpu'
$legacyRender=Read-Report 'tack-v015-legacy-after-render'
foreach ($row in $legacyCpu.rows) {
    $other=@($legacyRender.rows | Where-Object { $_.mode -eq $row.mode -and $_.speed -eq $row.speed -and $_.trial -eq $row.trial })
    if ($other.Count -ne 1 -or (Signature $row) -ne (Signature $other[0])) { throw "Legacy CPU/render changed $($row.mode)/$($row.speed)/$($row.trial)" }
    $legacyRenderPairs++
}
$result=[ordered]@{cpu_render_pairs=$pairs;legacy_cpu_render_pairs=$legacyRenderPairs;legacy14_pairs=$legacyPairs;local_before_pairs=$beforePairs;failures=0}
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ProjectRoot 'benchmarks/tack-v015-validation.json') -Encoding utf8
Write-Output "TACK COMPARISON COMPLETE: $pairs CPU/render, $legacyPairs historical14, $beforePairs actual local-before pairs;0failures"
# Aggregate the240 measured samples for each case; P95 is nearest rank.
function Aggregate-Tack($Rows) {
    $samples=@($Rows | ForEach-Object { $_.samples_ms })
    $sorted=@($samples | Sort-Object)
    $mean=($samples | Measure-Object -Average).Average
    $variance=($samples | ForEach-Object { ($_-$mean)*($_-$mean) } | Measure-Object -Average).Average
    [ordered]@{mean_ms=$mean;p95_ms=$sorted[[math]::Ceiling($samples.Count*.95)-1];max_ms=$sorted[-1];stddev_ms=[math]::Sqrt($variance);samples=$samples.Count;trial_means=@($Rows | ForEach-Object { $_.mean_ms })}
}
$summary=@()
foreach ($surface in @('cpu','render')) {
    $report=Read-Report "tack-v015-$surface"
    foreach ($group in ($report.rows | Group-Object mode,balloons,speed)) {
        $r=$group.Group[0]
        $pooled=Aggregate-Tack $group.Group
        $entry=[ordered]@{surface=$surface;mode=$r.mode;balloons=$r.balloons;speed=$r.speed;mean_ms=$pooled.mean_ms;p95_ms=$pooled.p95_ms;max_ms=$pooled.max_ms;stddev_ms=$pooled.stddev_ms;samples=$pooled.samples;trial_means=$pooled.trial_means}
        foreach ($field in @('projectiles_mean','projectile_allocations_mean','projectiles_per_game_second','queries_mean','checks_mean','candidates_mean','tower_ms','creation_ms','removal_ms','grid_ms','trajectory_ms','narrow_ms','resolution_ms','sort_ms','tower_draw_ms_mean','balloon_draw_ms_mean','projectile_draw_ms_mean','objects_mean','static_bytes_mean','draw_calls_mean')) {
            $entry[$field]=($group.Group | Measure-Object -Property $field -Average).Average
        }
        $entry.projectiles_max=($group.Group | Measure-Object -Property projectiles_max -Maximum).Maximum
        $summary += [pscustomobject]$entry
    }
}
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $ProjectRoot 'benchmarks/tack-v015-summary.json') -Encoding utf8
$summary | Export-Csv -LiteralPath (Join-Path $ProjectRoot 'benchmarks/tack-v015-summary.csv') -NoTypeInformation -Encoding utf8
$baseline=@()
foreach ($surface in @('cpu','render')) {
    $before=Read-Report "tack-v015-before-$surface"
    $after=Read-Report "tack-v015-$surface"
    foreach ($speed in @(1,2)) {
        $old=Aggregate-Tack @($before.rows | Where-Object { $_.speed -eq $speed })
        $now=Aggregate-Tack @($after.rows | Where-Object { $_.mode -eq 'boomerang_320' -and $_.speed -eq $speed })
        $baseline += [pscustomobject]@{surface=$surface;speed=$speed;before=$old;after=$now}
    }
}
$baseline | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $ProjectRoot 'benchmarks/tack-v015-before-after.json') -Encoding utf8
Write-Output 'TACK SUMMARY COMPLETE:72pooled surface/cases;240samples/case;actual local-before comparison saved'
