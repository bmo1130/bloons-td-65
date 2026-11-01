param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot), [string]$CurrentPrefix = 'boomerang-v0131')
$ErrorActionPreference = 'Stop'
function Read-Data([string]$Name) { Get-Content -LiteralPath (Join-Path $ProjectRoot "benchmarks/$Name.json") -Raw | ConvertFrom-Json }
function Aggregate($Rows) {
    $samples = @($Rows | ForEach-Object {$_.samples_ms})
    $mean = ($samples | Measure-Object -Average).Average
    $sorted = @($samples | Sort-Object)
    $variance = ($samples | ForEach-Object {($_-$mean)*($_-$mean)} | Measure-Object -Average).Average
    @{mean=$mean;p95=$sorted[[math]::Ceiling($samples.Count*.95)-1];max=$sorted[-1];stddev=[math]::Sqrt($variance);samples=$samples.Count;trial_means=@($Rows|ForEach-Object {$_.mean_ms})}
}
$before = Read-Data 'boomerang-v0131-probe-before-cpu'
$after = Read-Data "$CurrentPrefix-probe-after-cpu"
$beforeFrames = @($before.rows | ForEach-Object {$_.frame_details})
$afterFrames = @($after.rows | ForEach-Object {$_.frame_details})
$keys = @(@($beforeFrames + $afterFrames) | ForEach-Object {$_.detail.PSObject.Properties.Name} | Sort-Object -Unique)
$profile = @()
foreach ($key in $keys) {
    $a = @($beforeFrames | ForEach-Object {[double]$_.detail.$key})
    $b = @($afterFrames | ForEach-Object {[double]$_.detail.$key})
    $profile += [pscustomobject]@{metric=$key;before_mean=($a|Measure-Object -Average).Average;before_max=($a|Measure-Object -Maximum).Maximum;after_mean=($b|Measure-Object -Average).Average;after_max=($b|Measure-Object -Maximum).Maximum}
}
$repeat = @()
$repeatPairs = 0
foreach ($surface in @('cpu','render')) {
    $data = Read-Data "$CurrentPrefix-repeat-$surface"
    foreach ($mode in @(0,3)) {
        $rows = @($data.rows | Where-Object {$_.search_mode -eq $mode})
        $stats = Aggregate $rows
        $repeat += [pscustomobject]@{surface=$surface;search_mode=$mode;summary=$stats}
    }
    foreach ($row in ($data.rows | Select-Object -Skip 1)) {
        if (($row.fingerprint|ConvertTo-Json -Depth 90 -Compress) -ne ($data.rows[0].fingerprint|ConvertTo-Json -Depth 90 -Compress)) { throw 'Repeat fingerprint changed' }
        $repeatPairs++
    }
}
$repeatCpu = Read-Data "$CurrentPrefix-repeat-cpu"
$repeatRender = Read-Data "$CurrentPrefix-repeat-render"
$repeatRenderPairs = 0
foreach ($row in $repeatCpu.rows) {
    $match = @($repeatRender.rows | Where-Object {$_.trial -eq $row.trial -and $_.search_mode -eq $row.search_mode})
    if ($match.Count -ne 1 -or ($row.fingerprint|ConvertTo-Json -Depth 90 -Compress) -ne ($match[0].fingerprint|ConvertTo-Json -Depth 90 -Compress)) { throw 'Repeat CPU/render differs' }
    $repeatRenderPairs++
}
$cpuShort = Read-Data "$CurrentPrefix-stability-cpu-short"
$renderShort = Read-Data "$CurrentPrefix-stability-render"
$stability = Read-Data "$CurrentPrefix-stability-cpu"
foreach ($row in $stability.rows | Where-Object {$_.statistics}) {
    if ($row.pops_when_enabled -ne $stability.rows[0].pops_when_enabled) { throw 'Endurance pops changed' }
}
foreach ($row in $renderShort.rows) {
    if (($row.fingerprint|ConvertTo-Json -Depth 90 -Compress) -ne ($cpuShort.rows[0].fingerprint|ConvertTo-Json -Depth 90 -Compress)) { throw 'Endurance CPU/render/cache changed' }
}
$renderProfile = Read-Data "$CurrentPrefix-stability-render-profile"
$drawProfile = @()
foreach ($row in $renderProfile.rows) {
    if (($row.fingerprint|ConvertTo-Json -Depth 90 -Compress) -ne ($cpuShort.rows[0].fingerprint|ConvertTo-Json -Depth 90 -Compress)) { throw 'Detailed render control changed combat' }
    $drawProfile += [pscustomobject]@{draw_cache=$row.draw_cache;mean=$row.mean_ms;p95=$row.p95_ms;cpu_mean=($row.frame_stages.cpu|Measure-Object -Average).Average;balloon_draw_mean=($row.frame_stages.balloon_draw_ms|Measure-Object -Average).Average;projectile_draw_mean=($row.frame_stages.projectile_draw_ms|Measure-Object -Average).Average;draw_calls_mean=($row.frame_stages.draw_calls|Measure-Object -Average).Average}
}
$campaign = @()
$campaignSpeedPairs = 0
foreach ($surface in @('cpu','render')) {
    $data = Read-Data "$CurrentPrefix-campaign-$surface"
    if ($surface -eq 'cpu') {
        foreach ($row in ($data.rows | Where-Object {$_.speed -eq 1})) {
            $match = @($data.rows | Where-Object {$_.speed -eq 2 -and $_.trial -eq $row.trial -and $_.search_mode -eq $row.search_mode})
            if ($match.Count -ne 1 -or ($row.fingerprint|ConvertTo-Json -Depth 90 -Compress) -ne ($match[0].fingerprint|ConvertTo-Json -Depth 90 -Compress)) { throw 'Normal20 equal-time speed result changed' }
            $campaignSpeedPairs++
        }
    }
    foreach ($speed in @(1,2)) {
        foreach ($mode in @(0,3)) {
            $rows = @($data.rows | Where-Object {$_.speed -eq $speed -and $_.search_mode -eq $mode})
            $campaign += [pscustomobject]@{surface=$surface;speed=$speed;search_mode=$mode;summary=(Aggregate $rows)}
        }
    }
}
$output = @{version='v0.13.1';profile=$profile;repeat=$repeat;repeat_fingerprints=$repeatPairs;repeat_cpu_render_pairs=$repeatRenderPairs;stability_checks=$stability.checks;short_checks=$cpuShort.checks;render_checks=$renderShort.checks;render_profile_checks=$renderProfile.checks;draw_profile=$drawProfile;stability='Reference/optimized, stats ON/OFF and CPU/actual-render cache ON/OFF fingerprints match; 90game-second CPU endurance,10game-second rendered control.';campaign=$campaign;campaign_speed_pairs=$campaignSpeedPairs;conditions='Detailed probe timers include observer overhead, are nested and not production frame time. Counter/Array/Dictionary numbers are construction proxies. Native float-sort comparisons are not counted. Repeat4alternating trials pool480frames/mode. Campaign CPU whole20waves differs from renderwave20checkpoint; never compare those endpoints as identical.'}
if ($CurrentPrefix.StartsWith('boomerang-v014')) { $output.version = 'v0.14'; $output.fixture_version = 'v0.13.1' }
if ($CurrentPrefix.StartsWith('tack-v015')) { $output.version = 'v0.15'; $output.fixture_version = 'v0.13.1' }
if ($CurrentPrefix.StartsWith('tack-v016')) { $output.version = 'v0.16'; $output.fixture_version = 'v0.13.1' }
$output | ConvertTo-Json -Depth 90 | Set-Content -LiteralPath (Join-Path $ProjectRoot "benchmarks/$CurrentPrefix-profile-summary.json") -Encoding utf8
$profile | Export-Csv -LiteralPath (Join-Path $ProjectRoot "benchmarks/$CurrentPrefix-profile-comparison.csv") -NoTypeInformation -Encoding utf8
foreach ($row in $repeat) { 'Repeat {0}/mode{1}: {2:F3}/{3:F3}, max{4:F3}, stddev{5:F3} ms' -f $row.surface,$row.search_mode,$row.summary.mean,$row.summary.p95,$row.summary.max,$row.summary.stddev }
Write-Output 'CHAIN PROFILE ANALYSIS COMPLETE: repeat/endurance/campaign controls verified; detailed metrics exported.'
