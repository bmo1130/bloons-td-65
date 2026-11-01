param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot), [string]$CurrentPrefix = 'boomerang-v013', [string]$OutputPrefix = 'boomerang-v013-comparison', [string]$FilteredReport = 'boomerang-v013-cpu-quick', [string]$UnfilteredReport = 'boomerang-v013-unfiltered-cpu')
$ErrorActionPreference = 'Stop'
function Read-Report([string]$Name) { Get-Content -LiteralPath (Join-Path $ProjectRoot "benchmarks/$Name.json") -Raw | ConvertFrom-Json }
function Assert-Fingerprint($First,$Second,[string]$Label) {
    if (($First.fingerprint | ConvertTo-Json -Depth 80 -Compress) -ne ($Second.fingerprint | ConvertTo-Json -Depth 80 -Compress)) { throw "Combat mismatch: $Label" }
}
$cpu = Read-Report "$CurrentPrefix-cpu"
$render = Read-Report "$CurrentPrefix-render"
$pairs = 0
foreach ($entry in @(@{left=$cpu.rows;right=$render.rows},@{left=$cpu.legacy_rows;right=$render.legacy_rows})) {
    foreach ($row in $entry.left) {
        $matches = @($entry.right | Where-Object { $_.mode -eq $row.mode -and $_.balloons -eq $row.balloons -and $_.speed -eq $row.speed -and $_.trial -eq $row.trial })
        if ($matches.Count -ne 1) { throw 'Missing/duplicate CPU/render counterpart' }
        Assert-Fingerprint $row $matches[0] "$($row.mode)/$($row.balloons)/$($row.speed)/$($row.trial)"
        $pairs++
    }
}
$legacyPairs = 0
foreach ($surface in @('cpu','render')) {
    $old = Read-Report "bomb-v012-$surface"
    $current = if ($surface -eq 'cpu') { $cpu } else { $render }
    foreach ($row in $current.legacy_rows) {
        $matches = @($old.rows | Where-Object { $_.mode -eq $row.mode -and $_.speed -eq $row.speed -and $_.trial -eq $row.trial })
        if ($matches.Count -ne 1) { throw 'Missing legacy baseline' }
        Assert-Fingerprint $row $matches[0] "v012/v013/$surface/$($row.mode)/$($row.speed)"
        $legacyPairs++
    }
}
$unfiltered = Read-Report $UnfilteredReport
$filtered = Read-Report $FilteredReport
$filterPairs = 0
foreach ($row in $unfiltered.rows) {
    $matches = @($filtered.rows | Where-Object { $_.mode -eq $row.mode -and $_.balloons -eq $row.balloons -and $_.speed -eq $row.speed -and $_.trial -eq $row.trial })
    if ($matches.Count -ne 1) { throw 'Missing broadphase ablation counterpart' }
    Assert-Fingerprint $row $matches[0] "conservative bounds/$($row.balloons)/$($row.speed)"
    $filterPairs++
}
function Aggregate($Rows) {
    $samples = @($Rows | ForEach-Object { $_.samples_ms })
    $sorted = @($samples | Sort-Object)
    @{mean=($samples | Measure-Object -Average).Average;p95=$sorted[[math]::Ceiling($sorted.Count * 0.95)-1];samples=$samples.Count}
}
$summary = @()
foreach ($group in ($cpu.rows | Group-Object mode,balloons,speed)) {
    $first = $group.Group[0]
    $renderRows = @($render.rows | Where-Object { $_.mode -eq $first.mode -and $_.balloons -eq $first.balloons -and $_.speed -eq $first.speed })
    $cpuAggregate = Aggregate $group.Group
    $renderAggregate = Aggregate $renderRows
    $summary += [pscustomobject]@{mode=$first.mode;balloons=$first.balloons;speed=$first.speed;cpu_mean=$cpuAggregate.mean;cpu_p95=$cpuAggregate.p95;render_mean=$renderAggregate.mean;render_p95=$renderAggregate.p95;samples=$cpuAggregate.samples}
}
$version = if ($CurrentPrefix.StartsWith('boomerang-v014')) {'v0.14'} elseif ($CurrentPrefix.StartsWith('boomerang-v0131')) {'v0.13.1'} else {'v0.13'}
$output = @{version=$version;cpu_render_pairs=$pairs;legacy_pairs=$legacyPairs;filter_pairs=$filterPairs;conditions='240 pooled frames/case, nearest-rankP95. New120+legacy8 rows match CPU/render;16 legacy v012/v013 rows;6paired broadphase ablations. Separate6x20s mixed battles and48single-shot micro cases in crosspaths.json; not double-counted in automated assertions.';rows=$summary}
$output | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath (Join-Path $ProjectRoot "benchmarks/$OutputPrefix.json") -Encoding utf8
$summary | Export-Csv -LiteralPath (Join-Path $ProjectRoot "benchmarks/$OutputPrefix.csv") -NoTypeInformation -Encoding utf8
foreach ($row in ($summary | Where-Object {$_.balloons -eq 1000})) {
    Write-Output ('{0} x{1}: CPU {2:N3}/{3:N3}; render {4:N3}/{5:N3} ms (mean/P95)' -f $row.mode,$row.speed,$row.cpu_mean,$row.cpu_p95,$row.render_mean,$row.render_p95)
}
Write-Output "BOOMERANG COMPARISON: $pairs CPU/render, $legacyPairs legacy, $filterPairs bounds pairs match."
