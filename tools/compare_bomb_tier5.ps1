param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$reports = @{}
foreach ($key in @('before-cpu','before-render','cpu','render','status-before-cpu')) {
    $reports[$key] = Get-Content -LiteralPath (Join-Path $ProjectRoot "benchmarks/bomb-v012-$key.json") -Raw | ConvertFrom-Json
}
$compared = 0
foreach ($pair in @(@('before-cpu','cpu'), @('before-render','render'), @('cpu','render'), @('status-before-cpu','cpu'))) {
    foreach ($row in $reports[$pair[0]].rows) {
        $matches = @($reports[$pair[1]].rows | Where-Object { $_.mode -eq $row.mode -and $_.speed -eq $row.speed -and $_.trial -eq $row.trial })
        if ($matches.Count -ne 1) { throw 'Missing or duplicate benchmark counterpart' }
        if (($row.fingerprint | ConvertTo-Json -Depth 80 -Compress) -ne ($matches[0].fingerprint | ConvertTo-Json -Depth 80 -Compress)) {
            throw "Combat differs: $($pair[0])/$($pair[1])/$($row.mode)/$($row.speed)"
        }
        $compared++
    }
}
if (($reports.cpu.battles | ConvertTo-Json -Depth 80 -Compress) -ne ($reports.render.battles | ConvertTo-Json -Depth 80 -Compress)) { throw 'Equal-time ability/control battles differ between CPU and renderer' }
function Get-Aggregate {
    param($Rows)
    $samples = @($Rows | ForEach-Object { $_.samples_ms })
    $sorted = @($samples | Sort-Object)
    return @{ mean = ($samples | Measure-Object -Average).Average; p95 = $sorted[[math]::Ceiling($sorted.Count * 0.95) - 1]; samples = $samples.Count }
}
$summary = @()
foreach ($mode in @('bomb_base10','bomb_frag10','bomb_cluster10','bomb_recursive10','bomb_recursive_fast10','bomb_blitz_mix10')) {
    foreach ($speed in @(1,2)) {
        $entry = [ordered]@{mode = $mode; speed = $speed}
        foreach ($key in @('before-cpu','before-render','status-before-cpu','cpu','render')) {
            $rows = @($reports[$key].rows | Where-Object { $_.mode -eq $mode -and $_.speed -eq $speed })
            if ($rows.Count -eq 0) { continue }
            $aggregate = Get-Aggregate $rows
            $entry["$key-mean"] = $aggregate.mean
            $entry["$key-p95"] = $aggregate.p95
            $entry["$key-samples"] = $aggregate.samples
        }
        $summary += [pscustomobject]$entry
        Write-Output ('{0} x{1}: CPU {2:N3}/{3:N3}; render {4:N3}/{5:N3} ms (mean/P95)' -f $mode,$speed,$entry['cpu-mean'],$entry['cpu-p95'],$entry['render-mean'],$entry['render-p95'])
    }
}
@{version='v0.12'; matching_combat_pairs=$compared; equal_time_battles=6; conditions='240 samples/case pooled across2trials, nearest-rankP95. Stress1x/2x runs different simulated durations, compared only across matching fixtures. Six equal-time20s battles separately compare1x/2x and CPU/render. Benchmark comparisons are excluded from automatic assertion totals.'; rows=$summary} | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath (Join-Path $ProjectRoot 'benchmarks/bomb-v012-comparison.json') -Encoding utf8
Write-Output "BOMB TIER5 COMPARISON: $compared combat pairs and6equal-time battles match."
