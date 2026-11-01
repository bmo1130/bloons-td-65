param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot), [string]$CurrentPrefix = 'boomerang-v0131-after', [string]$CrossPrefix = 'boomerang-v0131-crosspaths', [string]$OutputPrefix = 'boomerang-v0131-comparison')
$ErrorActionPreference = 'Stop'
function Read-Data([string]$Name) { Get-Content -LiteralPath (Join-Path $ProjectRoot "benchmarks/$Name.json") -Raw | ConvertFrom-Json }
function Rows($Report) { @($Report.rows) + @($Report.legacy_rows) + @($Report.extra_rows) | Where-Object { $null -ne $_ } }
function Match-Row($All,$Row) {
    $matches = @($All | Where-Object {$_.mode -eq $Row.mode -and $_.balloons -eq $Row.balloons -and $_.speed -eq $Row.speed -and $_.trial -eq $Row.trial})
    if ($matches.Count -ne 1) { throw "Missing counterpart: $($Row.mode)/$($Row.speed)/$($Row.trial)" }
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
$pairs = @{before_after=0;v013_after=0;before_cpu_render=0;stage_reference=0;mixed_cpu_render=0}
$summary = @()
foreach ($surface in @('cpu','render')) {
    $before = Read-Data "boomerang-v0131-before-$surface"
    $after = Read-Data "$CurrentPrefix-$surface"
    $historical = Read-Data "boomerang-v013-$surface"
    $afterRows = @(Rows $after)
    foreach ($row in (Rows $before)) {
        Assert-Same $row (Match-Row $afterRows $row) "before/after/$surface"
        $pairs.before_after++
    }
    foreach ($row in (Rows $historical)) {
        Assert-Same $row (Match-Row $afterRows $row) "v013/after/$surface"
        $pairs.v013_after++
    }
    foreach ($group in ((Rows $before) | Group-Object mode,balloons,speed)) {
        $first = $group.Group[0]
        $matched = @($afterRows | Where-Object {$_.mode -eq $first.mode -and $_.balloons -eq $first.balloons -and $_.speed -eq $first.speed})
        $a = Aggregate $group.Group
        $b = Aggregate $matched
        $summary += [pscustomobject]@{surface=$surface;mode=$first.mode;balloons=$first.balloons;speed=$first.speed;before_mean=$a.mean;before_p95=$a.p95;before_max=$a.max;before_stddev=$a.stddev;after_mean=$b.mean;after_p95=$b.p95;after_max=$b.max;after_stddev=$b.stddev;mean_change_percent=100*($b.mean/$a.mean-1);p95_change_percent=100*($b.p95/$a.p95-1);samples=$a.samples;before_trial_means=$a.trial_means;after_trial_means=$b.trial_means}
    }
    foreach ($stage in @('stage1','stage2','stage3','stage4')) {
        $data = Read-Data "boomerang-v0131-$stage-$surface"
        foreach ($row in $data.rows) {
            Assert-Same $row (Match-Row (Rows $before) $row) "$stage/$surface"
            $pairs.stage_reference++
        }
    }
}
$beforeCpu = Read-Data 'boomerang-v0131-before-cpu'
$beforeRender = Read-Data 'boomerang-v0131-before-render'
foreach ($row in (Rows $beforeCpu)) { Assert-Same $row (Match-Row (Rows $beforeRender) $row) 'beforeCPU/render'; $pairs.before_cpu_render++ }
$afterCpu = Read-Data "$CurrentPrefix-cpu"
$afterRender = Read-Data "$CurrentPrefix-render"
foreach ($row in $afterCpu.extra_rows) { Assert-Same $row (Match-Row $afterRender.extra_rows $row) 'mixedCPU/render'; $pairs.mixed_cpu_render++ }
$oldCross = Read-Data 'boomerang-v013-crosspaths'
$newCross = Read-Data $CrossPrefix
if (($oldCross | ConvertTo-Json -Depth 90 -Compress) -ne ($newCross | ConvertTo-Json -Depth 90 -Compress)) { throw 'Crosspath48conditions/6equal-time battles changed' }
$output = @{version='v0.13.1';pairs=$pairs;original150='Replayed separately by compare_boomerang with CurrentPrefix=boomerang-v0131-after; 128 CPU/render +16v012legacy +6historical ablations.';crosspaths='All48micro cases and6equal-time battles exactly match v013';rows=$summary}
if ($CurrentPrefix.StartsWith('boomerang-v014')) { $output.version = 'v0.14'; $output.fixture_version = 'v0.13.1' }
$output | ConvertTo-Json -Depth 90 | Set-Content -LiteralPath (Join-Path $ProjectRoot "benchmarks/$OutputPrefix.json") -Encoding utf8
$summary | Select-Object surface,mode,balloons,speed,before_mean,before_p95,before_max,before_stddev,after_mean,after_p95,after_max,after_stddev,mean_change_percent,p95_change_percent,samples | Export-Csv -LiteralPath (Join-Path $ProjectRoot "benchmarks/$OutputPrefix.csv") -Encoding utf8 -NoTypeInformation
foreach ($row in ($summary | Where-Object {$_.mode -eq 'boomerang_320' -and $_.speed -eq 2})) {
    '{0}320x2 before {1:F3}/{2:F3}, after {3:F3}/{4:F3} ms (mean/P95)' -f $row.surface,$row.before_mean,$row.before_p95,$row.after_mean,$row.after_p95
}
Write-Output ('CHAIN COMPARISON: all before/after, historical, stage, mixed and48/6crosspath fingerprints match: ' + ($pairs | ConvertTo-Json -Compress))
