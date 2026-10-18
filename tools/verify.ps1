param(
    [string]$Godot = 'godot',
    [switch]$Visual,
    [switch]$Benchmark,
    [switch]$Balance,
    [switch]$RenderBenchmark,
    [switch]$FanBenchmark,
    [switch]$Tier5Benchmark,
    [switch]$PropertiesBenchmark
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$resultsPath = Join-Path $projectRoot 'test-results'
New-Item -ItemType Directory -Force -Path $resultsPath | Out-Null
Set-Content -LiteralPath (Join-Path $resultsPath '.gdignore') -Value '' -Encoding utf8

# Keep test/editor preferences inside the workspace, including in sandboxes.
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$env:APPDATA = Join-Path $resultsPath 'profile/Roaming'
$env:LOCALAPPDATA = Join-Path $resultsPath 'profile/Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null

function Invoke-GodotCheck {
    param([string]$Name, [string[]]$Arguments, [string]$ExpectedResult = '')
    $logPath = Join-Path $resultsPath "$Name.log"
    $consolePath = Join-Path $resultsPath "$Name.console.log"
    & $Godot --path $projectRoot --log-file $logPath @Arguments 2>&1 | Tee-Object -FilePath $consolePath
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
    # Godot editor import can return zero even when a script failed to parse.
    if (Select-String -LiteralPath $logPath,$consolePath -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet) {
        throw "$Name reported errors. See $logPath"
    }
    if ($ExpectedResult -and -not (Select-String -LiteralPath $logPath -Pattern $ExpectedResult -Quiet)) {
        throw "$Name did not complete. See $logPath"
    }
}

try {
    Invoke-GodotCheck -Name 'import' -Arguments @('--headless', '--editor', '--quit')
    Invoke-GodotCheck -Name 'tests' -Arguments @('--headless', '--script', 'res://tests/run_tests.gd', '--quit-after', '600') -ExpectedResult 'TEST RESULT: \d+ checks, 0 failures'
    Invoke-GodotCheck -Name 'main' -Arguments @('--headless', '--quit-after', '120')
    if ($Visual) {
        Invoke-GodotCheck -Name 'visual' -Arguments @('--script', 'res://tests/visual_smoke.gd', '--quit-after', '600') -ExpectedResult 'VISUAL INPUT RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v03' -Arguments @('--script', 'res://tests/attributes_visual.gd', '--quit-after', '600') -ExpectedResult 'V0.3 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v04' -Arguments @('--script', 'res://tests/upgrades_visual.gd', '--quit-after', '600') -ExpectedResult 'V0.4 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v05' -Arguments @('--script', 'res://tests/crosspaths_visual.gd', '--quit-after', '600') -ExpectedResult 'V0.5 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v06' -Arguments @('--script', 'res://tests/statistics_visual.gd', '--quit-after', '600') -ExpectedResult 'V0.6 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v07' -Arguments @('--script', 'res://tests/tier4_visual.gd', '--quit-after', '600') -ExpectedResult 'V0.7 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v08' -Arguments @('--script', 'res://tests/tier5_visual.gd', '--quit-after', '600') -ExpectedResult 'V0.8 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v09' -Arguments @('--script', 'res://tests/properties_visual.gd', '--quit-after', '1000') -ExpectedResult 'V0.9 VISUAL RESULT: \d+ checks, 0 failures'
    }
    if ($Benchmark) {
        foreach ($variant in @('on','off','cluster-on','cluster-off')) {
            $benchArgs = @('--headless', '--script', 'res://tests/benchmark.gd', '--quit-after', '600', '--', '--crosspath', '--v09')
            if ($variant.EndsWith('off')) { $benchArgs += '--stats-off' }
            if ($variant.StartsWith('cluster')) { $benchArgs += '--concentrated' }
            Invoke-GodotCheck -Name "benchmark-v09-$variant" -Arguments $benchArgs -ExpectedResult 'BENCHMARK COMPLETE:'
        }
    }
    if ($Balance) {
        Invoke-GodotCheck -Name 'balance' -Arguments @('--headless', '--script', 'res://tests/analyze_balance.gd', '--quit-after', '600') -ExpectedResult 'BALANCE COMPLETE:'
    }
    if ($RenderBenchmark) {
        Invoke-GodotCheck -Name 'render-benchmark' -Arguments @('--script', 'res://tests/render_benchmark.gd', '--quit-after', '3000') -ExpectedResult 'RENDER BENCHMARK COMPLETE:'
    }
    if ($FanBenchmark) {
        Invoke-GodotCheck -Name 'fanclub-cpu-v09' -Arguments @('--headless', '--script', 'res://tests/fanclub_benchmark.gd', '--quit-after', '3000', '--', '--v09') -ExpectedResult 'FANCLUB BENCHMARK COMPLETE:'
        Invoke-GodotCheck -Name 'fanclub-render-v09' -Arguments @('--script', 'res://tests/fanclub_benchmark.gd', '--quit-after', '3000', '--', '--render', '--v09') -ExpectedResult 'FANCLUB BENCHMARK COMPLETE:'
    }
    if ($Tier5Benchmark) {
        foreach ($rendered in @($false,$true)) {
            foreach ($uncached in @($false,$true)) {
                $benchArgs = @('--script', 'res://tests/tier5_benchmark.gd', '--quit-after', '10000', '--', '--v09')
                $label = 'cpu'
                if ($rendered) { $benchArgs += '--render'; $label = 'render' }
                else { $benchArgs = @('--headless') + $benchArgs }
                if ($uncached) { $benchArgs += '--uncached-ui'; $label += '-uncached' }
                Invoke-GodotCheck -Name "tier5-benchmark-v09-$label" -Arguments $benchArgs -ExpectedResult 'TIER5 BENCHMARK COMPLETE:'
            }
        }
        $cpuReport = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/tier5-v09-cpu.json') -Raw | ConvertFrom-Json
        $renderReport = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/tier5-v09-render.json') -Raw | ConvertFrom-Json
        foreach ($label in @('cpu','render')) {
            $cached = Get-Content -LiteralPath (Join-Path $projectRoot "benchmarks/tier5-v09-$label.json") -Raw | ConvertFrom-Json
            $uncached = Get-Content -LiteralPath (Join-Path $projectRoot "benchmarks/tier5-v09-$label-uncached.json") -Raw | ConvertFrom-Json
            foreach ($row in $uncached.rows) {
                $match = $cached.rows | Where-Object { $_.mode -eq $row.mode -and $_.balloons -eq $row.balloons -and $_.speed -eq $row.speed }
                if (($match.fingerprint | ConvertTo-Json -Depth 40 -Compress) -ne ($row.fingerprint | ConvertTo-Json -Depth 40 -Compress)) {
                    throw "Tier5 UI optimization changed combat in $label/$($row.mode)/$($row.speed)"
                }
            }
        }
        foreach ($row in $renderReport.rows | Where-Object { $_.mode -ne 'normal20_checkpoint' }) {
            $match = $cpuReport.rows | Where-Object { $_.mode -eq $row.mode -and $_.balloons -eq $row.balloons -and $_.speed -eq $row.speed }
            if (($match.fingerprint | ConvertTo-Json -Depth 40 -Compress) -ne ($row.fingerprint | ConvertTo-Json -Depth 40 -Compress)) {
                throw "Tier5 rendered combat differs: $($row.mode)/$($row.balloons)/$($row.speed)"
            }
        }
        Write-Output 'Tier5 benchmark combat fingerprints match (CPU/render/UI modes).'
    }
    if ($PropertiesBenchmark) {
        foreach ($rendered in @($false,$true)) {
            $prefix = @()
            $userArgs = @()
            $label = 'render'
            if ($rendered) { $userArgs += '--render' }
            else { $prefix += '--headless'; $label = 'cpu' }
            Invoke-GodotCheck -Name "properties-benchmark-v09-$label" -Arguments ($prefix + @('--script', 'res://tests/properties_benchmark.gd', '--quit-after', '3000', '--') + $userArgs) -ExpectedResult 'PROPERTIES BENCHMARK COMPLETE:'
            Invoke-GodotCheck -Name "campaign-benchmark-v09-$label" -Arguments ($prefix + @('--script', 'res://tests/tier5_benchmark.gd', '--quit-after', '3000', '--', '--v09', '--campaign-only') + $userArgs) -ExpectedResult 'TIER5 BENCHMARK COMPLETE:'
        }
        $cpu = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/properties-v09-cpu.json') -Raw | ConvertFrom-Json
        $render = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/properties-v09-render.json') -Raw | ConvertFrom-Json
        foreach ($row in $render.rows) {
            $match = $cpu.rows | Where-Object { $_.case -eq $row.case -and $_.count -eq $row.count -and $_.speed -eq $row.speed }
            if (($match.fingerprint | ConvertTo-Json -Depth 40 -Compress) -ne ($row.fingerprint | ConvertTo-Json -Depth 40 -Compress)) { throw 'Properties CPU/render combat mismatch' }
        }
        Write-Output 'Properties CPU/render combat fingerprints match.'
    }
    Write-Output 'All requested checks passed.'
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
