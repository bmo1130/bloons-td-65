param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$reports = @{}
foreach ($phase in @('before','after')) {
    foreach ($surface in @('cpu','render')) {
        $key = "$phase-$surface"
        $reports[$key] = Get-Content -LiteralPath (Join-Path $ProjectRoot "benchmarks/bomb-v0111-$key.json") -Raw | ConvertFrom-Json
    }
}
$pairs = @(@('before-cpu','after-cpu'), @('before-render','after-render'), @('before-cpu','before-render'), @('after-cpu','after-render'))
$compared = 0
foreach ($pair in $pairs) {
    foreach ($row in $reports[$pair[0]].rows) {
        $matches = @($reports[$pair[1]].rows | Where-Object { $_.mode -eq $row.mode -and $_.speed -eq $row.speed -and $_.trial -eq $row.trial })
        if ($matches.Count -ne 1) { throw 'Missing or duplicate benchmark counterpart' }
        if (($row.fingerprint | ConvertTo-Json -Depth 80 -Compress) -ne ($matches[0].fingerprint | ConvertTo-Json -Depth 80 -Compress)) {
            throw "Combat differs: $($pair[0])/$($pair[1])/$($row.mode)/$($row.speed)/$($row.trial)"
        }
        $compared++
    }
}
function Get-Aggregate {
    param($Rows)
    $samples = @($Rows | ForEach-Object { $_.samples_ms })
    $sorted = @($samples | Sort-Object)
    return @{ mean = ($samples | Measure-Object -Average).Average; p95 = $sorted[[math]::Ceiling($sorted.Count * 0.95) - 1]; samples = $samples.Count }
}
$ablationPairs = 0
foreach ($hidden in @('balloons','effects')) {
    $path = Join-Path $ProjectRoot "benchmarks/bomb-v0111-before-render-hide-$hidden.json"
    if (Test-Path -LiteralPath $path) {
        $ablation = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        foreach ($row in $ablation.rows) {
            $reference = @($reports['before-cpu'].rows | Where-Object { $_.mode -eq $row.mode -and $_.speed -eq $row.speed -and $_.trial -eq $row.trial })
            if ($reference.Count -ne 1 -or ($row.fingerprint | ConvertTo-Json -Depth 80 -Compress) -ne ($reference[0].fingerprint | ConvertTo-Json -Depth 80 -Compress)) {
                throw "Ablation changed combat: $hidden/$($row.mode)"
            }
            $ablationPairs++
        }
    }
}
$summary = @()
foreach ($mode in @('bomb_base10','bomb_frag10','bomb_cluster10')) {
    foreach ($speed in @(1,2)) {
        $entry = [ordered]@{mode = $mode; speed = $speed}
        foreach ($key in @('before-cpu','after-cpu','before-render','after-render')) {
            $rows = @($reports[$key].rows | Where-Object { $_.mode -eq $mode -and $_.speed -eq $speed })
            $aggregate = Get-Aggregate $rows
            $entry["$key-mean"] = $aggregate.mean
            $entry["$key-p95"] = $aggregate.p95
            $entry["$key-samples"] = $aggregate.samples
        }
        $entry['render_improvement_percent'] = 100 * (1 - $entry['after-render-mean'] / $entry['before-render-mean'])
        $summary += [pscustomobject]$entry
    }
}
$output = @{version = 'v0.11.1'; matching_combat_pairs = $compared; ablation_matching_pairs = $ablationPairs; conditions = 'Pool 120 frame samples from each of two trials: 240 samples/case; nearest-rank P95 of pooled frames, not mean of per-trial P95s. CPU/render and before/after fingerprints include all live balloon IDs/HP/distances and per-tower counters. Speed1/2 stress rows run different simulation durations; equal-time speed invariance is tested separately in40micro+5normalbudget campaigns.'; rows = $summary}
$output | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath (Join-Path $ProjectRoot 'benchmarks/bomb-v0111-comparison.json') -Encoding utf8
foreach ($row in $summary) {
    Write-Output ('{0} x{1}: CPU {2:N3}/{3:N3} -> {4:N3}/{5:N3}; render {6:N3}/{7:N3} -> {8:N3}/{9:N3} ms (mean/P95)' -f $row.mode,$row.speed,$row.'before-cpu-mean',$row.'before-cpu-p95',$row.'after-cpu-mean',$row.'after-cpu-p95',$row.'before-render-mean',$row.'before-render-p95',$row.'after-render-mean',$row.'after-render-p95')
}
Write-Output "BOMB STABILITY COMPARISON: $compared combat pairs match."
Write-Output "Ablation combat pairs: $ablationPairs match."
