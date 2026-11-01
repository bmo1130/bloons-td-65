param(
    [string]$Godot = 'godot',
    [switch]$Visual,
    [switch]$Benchmark,
    [switch]$Balance,
    [switch]$RenderBenchmark,
    [switch]$FanBenchmark,
    [switch]$Tier5Benchmark,
    [switch]$PropertiesBenchmark,
    [switch]$MoabBenchmark,
    [switch]$DdtBadBenchmark,
    [switch]$BombBenchmark,
    [switch]$StabilityBenchmark,
    [switch]$BombTier5Benchmark,
    [switch]$BoomerangBenchmark,
    [switch]$ChainBenchmark,
    [switch]$ChainStability,
    [switch]$BoomerangTier5Benchmark,
    [switch]$TackBenchmark,
    [switch]$TackTier5Benchmark
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
    if (Select-String -LiteralPath $logPath,$consolePath -Pattern 'SCRIPT ERROR:|ERROR:|WARNING:' -Quiet) {
        throw "$Name reported errors/warnings. See $logPath"
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
        Invoke-GodotCheck -Name 'visual-tack-v016' -Arguments @('--script','res://tests/tack_tier5_visual.gd','--quit-after','4000') -ExpectedResult 'TACK TIER5 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-tack-v015' -Arguments @('--script','res://tests/tack_visual.gd','--quit-after','3000') -ExpectedResult 'TACK VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-boomerang-v014' -Arguments @('--script','res://tests/boomerang_tier5_visual.gd','--quit-after','4000') -ExpectedResult 'BOOMERANG TIER5 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-boomerang-v013' -Arguments @('--script', 'res://tests/boomerang_visual.gd', '--quit-after', '2000') -ExpectedResult 'BOOMERANG VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-bomb-v012' -Arguments @('--script', 'res://tests/bomb_tier5_visual.gd', '--quit-after', '1800') -ExpectedResult 'BOMB TIER5 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-cache-v0111' -Arguments @('--script', 'res://tests/balloon_cache_visual.gd', '--quit-after', '600') -ExpectedResult 'BALLOON CACHE VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-bomb-v011' -Arguments @('--script', 'res://tests/bomb_upgrades_visual.gd', '--quit-after', '1600') -ExpectedResult 'BOMB VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual' -Arguments @('--script', 'res://tests/visual_smoke.gd', '--quit-after', '600') -ExpectedResult 'VISUAL INPUT RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v03' -Arguments @('--script', 'res://tests/attributes_visual.gd', '--quit-after', '600') -ExpectedResult 'V0.3 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v04' -Arguments @('--script', 'res://tests/upgrades_visual.gd', '--quit-after', '600') -ExpectedResult 'V0.4 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v05' -Arguments @('--script', 'res://tests/crosspaths_visual.gd', '--quit-after', '600') -ExpectedResult 'V0.5 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v06' -Arguments @('--script', 'res://tests/statistics_visual.gd', '--quit-after', '600') -ExpectedResult 'V0.6 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v07' -Arguments @('--script', 'res://tests/tier4_visual.gd', '--quit-after', '600') -ExpectedResult 'V0.7 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v08' -Arguments @('--script', 'res://tests/tier5_visual.gd', '--quit-after', '600') -ExpectedResult 'V0.8 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v011' -Arguments @('--script', 'res://tests/ddt_bad_visual.gd', '--quit-after', '1600') -ExpectedResult 'V0.11 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v010' -Arguments @('--script', 'res://tests/moab_visual.gd', '--quit-after', '1200') -ExpectedResult 'V0.10 VISUAL RESULT: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'visual-v09' -Arguments @('--script', 'res://tests/properties_visual.gd', '--quit-after', '1000') -ExpectedResult 'V0.9 VISUAL RESULT: \d+ checks, 0 failures'
    }
    if ($Benchmark) {
        foreach ($variant in @('on','off','cluster-on','cluster-off')) {
            $benchArgs = @('--headless', '--script', 'res://tests/benchmark.gd', '--quit-after', '600', '--', '--crosspath', '--v016', '--bomb-upgrades')
            if ($variant.EndsWith('off')) { $benchArgs += '--stats-off' }
            if ($variant.StartsWith('cluster')) { $benchArgs += '--concentrated' }
            Invoke-GodotCheck -Name "benchmark-v0131-legacy-$variant" -Arguments $benchArgs -ExpectedResult 'BENCHMARK COMPLETE:'
        }
    }
    if ($Balance) {
        Invoke-GodotCheck -Name 'balance-v0111' -Arguments @('--headless', '--script', 'res://tests/analyze_bomb_stability.gd', '--quit-after', '600') -ExpectedResult 'BOMB STABILITY ANALYSIS COMPLETE:'
    }
    if ($RenderBenchmark) {
        Invoke-GodotCheck -Name 'render-benchmark' -Arguments @('--script', 'res://tests/render_benchmark.gd', '--quit-after', '3000') -ExpectedResult 'RENDER BENCHMARK COMPLETE:'
    }
    if ($FanBenchmark) {
        Invoke-GodotCheck -Name 'fanclub-cpu-v011' -Arguments @('--headless', '--script', 'res://tests/fanclub_benchmark.gd', '--quit-after', '3000', '--', '--v011') -ExpectedResult 'FANCLUB BENCHMARK COMPLETE:'
        Invoke-GodotCheck -Name 'fanclub-render-v011' -Arguments @('--script', 'res://tests/fanclub_benchmark.gd', '--quit-after', '3000', '--', '--render', '--v011') -ExpectedResult 'FANCLUB BENCHMARK COMPLETE:'
    }
    if ($Tier5Benchmark) {
        foreach ($rendered in @($false,$true)) {
            foreach ($uncached in @($false,$true)) {
                $benchArgs = @('--script', 'res://tests/tier5_benchmark.gd', '--quit-after', '10000', '--', '--v011')
                $label = 'cpu'
                if ($rendered) { $benchArgs += '--render'; $label = 'render' }
                else { $benchArgs = @('--headless') + $benchArgs }
                if ($uncached) { $benchArgs += '--uncached-ui'; $label += '-uncached' }
                Invoke-GodotCheck -Name "tier5-benchmark-v011-$label" -Arguments $benchArgs -ExpectedResult 'TIER5 BENCHMARK COMPLETE:'
            }
        }
        $cpuReport = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/tier5-v011-cpu.json') -Raw | ConvertFrom-Json
        $renderReport = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/tier5-v011-render.json') -Raw | ConvertFrom-Json
        foreach ($label in @('cpu','render')) {
            $cached = Get-Content -LiteralPath (Join-Path $projectRoot "benchmarks/tier5-v011-$label.json") -Raw | ConvertFrom-Json
            $uncached = Get-Content -LiteralPath (Join-Path $projectRoot "benchmarks/tier5-v011-$label-uncached.json") -Raw | ConvertFrom-Json
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
            $userArgs = @('--v011')
            $label = 'render'
            if ($rendered) { $userArgs += '--render' }
            else { $prefix += '--headless'; $label = 'cpu' }
            Invoke-GodotCheck -Name "properties-benchmark-v011-$label" -Arguments ($prefix + @('--script', 'res://tests/properties_benchmark.gd', '--quit-after', '3000', '--') + $userArgs) -ExpectedResult 'PROPERTIES BENCHMARK COMPLETE:'
            Invoke-GodotCheck -Name "campaign-benchmark-v011-$label" -Arguments ($prefix + @('--script', 'res://tests/tier5_benchmark.gd', '--quit-after', '3000', '--', '--v011', '--campaign-only') + $userArgs) -ExpectedResult 'TIER5 BENCHMARK COMPLETE:'
        }
        $cpu = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/properties-v011-cpu.json') -Raw | ConvertFrom-Json
        $render = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/properties-v011-render.json') -Raw | ConvertFrom-Json
        foreach ($row in $render.rows) {
            $match = $cpu.rows | Where-Object { $_.case -eq $row.case -and $_.count -eq $row.count -and $_.speed -eq $row.speed }
            if (($match.fingerprint | ConvertTo-Json -Depth 40 -Compress) -ne ($row.fingerprint | ConvertTo-Json -Depth 40 -Compress)) { throw 'Properties CPU/render combat mismatch' }
        }
        Write-Output 'Properties CPU/render combat fingerprints match.'
    }
    if ($MoabBenchmark) {
        foreach ($rendered in @($false,$true)) {
            $benchArgs = @('--script', 'res://tests/moab_benchmark.gd', '--quit-after', '10000', '--', '--v011')
            $label = 'cpu'
            if ($rendered) { $benchArgs += '--render'; $label = 'render' }
            else { $benchArgs = @('--headless') + $benchArgs }
            Invoke-GodotCheck -Name "moab-benchmark-v011-$label" -Arguments $benchArgs -ExpectedResult 'MOAB BENCHMARK COMPLETE:'
        }
        $cpu = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/moab-v011-cpu.json') -Raw | ConvertFrom-Json
        $render = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/moab-v011-render.json') -Raw | ConvertFrom-Json
        foreach ($row in $render.rows | Where-Object { $_.mode -ne 'normal20_checkpoint' }) {
            $match = $cpu.rows | Where-Object { $_.mode -eq $row.mode -and $_.balloons -eq $row.balloons -and $_.speed -eq $row.speed }
            if (($match.fingerprint | ConvertTo-Json -Depth 40 -Compress) -ne ($row.fingerprint | ConvertTo-Json -Depth 40 -Compress)) { throw "MOAB CPU/render mismatch: $($row.mode)/$($row.speed)" }
        }
        Write-Output 'MOAB CPU/render combat fingerprints match.'
    }
    if ($DdtBadBenchmark) {
        foreach ($rendered in @($false,$true)) {
            $benchArgs = @('--script', 'res://tests/ddt_bad_benchmark.gd', '--quit-after', '10000')
            $label = 'cpu'
            if ($rendered) { $benchArgs += @('--', '--render'); $label = 'render' }
            else { $benchArgs = @('--headless') + $benchArgs }
            Invoke-GodotCheck -Name "ddt-bad-benchmark-v011-$label" -Arguments $benchArgs -ExpectedResult 'DDT BAD BENCHMARK COMPLETE:'
        }
        $cpu = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/ddt-bad-v011-cpu.json') -Raw | ConvertFrom-Json
        $render = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/ddt-bad-v011-render.json') -Raw | ConvertFrom-Json
        foreach ($row in $render.rows | Where-Object { $_.mode -ne 'normal20_checkpoint' }) {
            $match = $cpu.rows | Where-Object { $_.mode -eq $row.mode -and $_.balloons -eq $row.balloons -and $_.speed -eq $row.speed }
            if (($match.fingerprint | ConvertTo-Json -Depth 40 -Compress) -ne ($row.fingerprint | ConvertTo-Json -Depth 40 -Compress)) { throw "DDT/BAD CPU/render mismatch: $($row.mode)/$($row.speed)" }
        }
        Write-Output 'DDT/BAD CPU/render combat fingerprints match.'
    }
    if ($BombBenchmark) {
        foreach ($rendered in @($false,$true)) {
            $benchArgs = @('--script', 'res://tests/bomb_benchmark.gd', '--quit-after', '10000')
            $label = 'cpu'
            if ($rendered) { $benchArgs += @('--', '--render', '--v0111'); $label = 'render' }
            else { $benchArgs = @('--headless') + $benchArgs + @('--', '--v0111') }
            Invoke-GodotCheck -Name "bomb-benchmark-v0111-$label" -Arguments $benchArgs -ExpectedResult 'BOMB BENCHMARK COMPLETE:'
        }
        $cpu = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/bomb-v0111-cpu.json') -Raw | ConvertFrom-Json
        $render = Get-Content -LiteralPath (Join-Path $projectRoot 'benchmarks/bomb-v0111-render.json') -Raw | ConvertFrom-Json
        foreach ($row in $render.rows | Where-Object { $_.mode -ne 'normal20_checkpoint' }) {
            $match = $cpu.rows | Where-Object { $_.mode -eq $row.mode -and $_.balloons -eq $row.balloons -and $_.speed -eq $row.speed }
            if (($match.fingerprint | ConvertTo-Json -Depth 40 -Compress) -ne ($row.fingerprint | ConvertTo-Json -Depth 40 -Compress)) { throw "Bomb CPU/render mismatch: $($row.mode)/$($row.speed)" }
        }
        Write-Output 'Bomb CPU/render combat fingerprints match.'
    }
    if ($StabilityBenchmark) {
        foreach ($phase in @('before','after')) {
            foreach ($surface in @('cpu','render')) {
                $benchArgs = @('--script', 'res://tests/bomb_stability_benchmark.gd', '--quit-after', '10000', '--', "--phase=$phase")
                if ($surface -eq 'cpu') { $benchArgs = @('--headless') + $benchArgs }
                else { $benchArgs += '--render' }
                if ($phase -eq 'before') { $benchArgs += '--uncached-draw' }
                Invoke-GodotCheck -Name "bomb-v0111-$phase-$surface" -Arguments $benchArgs -ExpectedResult 'BOMB STABILITY BENCHMARK COMPLETE:'
            }
        }
        & (Join-Path $PSScriptRoot 'compare_bomb_stability.ps1') -ProjectRoot $projectRoot
    }
    if ($BombTier5Benchmark) {
        foreach ($surface in @('cpu','render')) {
            $benchArgs = @('--script', 'res://tests/bomb_tier5_benchmark.gd', '--quit-after', '10000')
            if ($surface -eq 'cpu') { $benchArgs = @('--headless') + $benchArgs }
            else { $benchArgs += @('--', '--render') }
            Invoke-GodotCheck -Name "bomb-v012-$surface" -Arguments $benchArgs -ExpectedResult 'BOMB TIER5 BENCHMARK COMPLETE:'
        }
        Invoke-GodotCheck -Name 'bomb-v012-crosspaths' -Arguments @('--headless', '--script', 'res://tests/analyze_bomb_tier5.gd') -ExpectedResult 'BOMB TIER5 CROSSPATH COMPLETE:'
        & (Join-Path $PSScriptRoot 'compare_bomb_tier5.ps1') -ProjectRoot $projectRoot
    }
    if ($BoomerangBenchmark) {
        foreach ($surface in @('cpu','render')) {
            $benchArgs = @('--script', 'res://tests/boomerang_benchmark.gd', '--quit-after', '30000')
            if ($surface -eq 'cpu') { $benchArgs = @('--headless') + $benchArgs }
            else { $benchArgs += @('--', '--render') }
            Invoke-GodotCheck -Name "boomerang-v013-$surface" -Arguments $benchArgs -ExpectedResult 'BOOMERANG BENCHMARK COMPLETE:'
        }
        Invoke-GodotCheck -Name 'boomerang-v013-analysis' -Arguments @('--headless','--script','res://tests/analyze_boomerang.gd') -ExpectedResult 'BOOMERANG ANALYSIS COMPLETE:'
        & (Join-Path $PSScriptRoot 'compare_boomerang.ps1') -ProjectRoot $projectRoot
    }
    if ($ChainBenchmark) {
        foreach ($surface in @('cpu','render')) {
            $benchArgs = @('--script','res://tests/chain_benchmark.gd','--quit-after','30000','--','--matrix','--phase=after','--output-prefix=boomerang-v014-legacy')
            if ($surface -eq 'cpu') { $benchArgs = @('--headless') + $benchArgs }
            else { $benchArgs += '--render' }
            Invoke-GodotCheck -Name "boomerang-v0131-after-$surface" -Arguments $benchArgs -ExpectedResult 'CHAIN BENCHMARK COMPLETE:'
        }
        Invoke-GodotCheck -Name 'boomerang-v0131-crosspaths' -Arguments @('--headless','--script','res://tests/analyze_boomerang.gd','--','--v014') -ExpectedResult 'BOOMERANG ANALYSIS COMPLETE:'
        foreach ($control in @('on','off')) {
            $ablationArgs = @('--headless','--script','res://tests/boomerang_benchmark.gd','--','--mode=030','--trials=1','--quick','--output-prefix=boomerang-v014-ablation')
            if ($control -eq 'off') { $ablationArgs += '--unfiltered-flight' }
            Invoke-GodotCheck -Name "boomerang-v014-ablation-$control" -Arguments $ablationArgs -ExpectedResult 'BOOMERANG BENCHMARK COMPLETE:'
        }
        & (Join-Path $PSScriptRoot 'compare_boomerang.ps1') -ProjectRoot $projectRoot -CurrentPrefix 'boomerang-v014-legacy-after' -OutputPrefix 'boomerang-v014-legacy-matrix' -FilteredReport 'boomerang-v014-ablation-cpu-quick' -UnfilteredReport 'boomerang-v014-ablation-cpu-quick-unfiltered'
        & (Join-Path $PSScriptRoot 'compare_chain.ps1') -ProjectRoot $projectRoot -CurrentPrefix 'boomerang-v014-legacy-after' -CrossPrefix 'boomerang-v014-legacy-crosspaths' -OutputPrefix 'boomerang-v014-legacy-comparison'
    }
    if ($ChainStability) {
        foreach ($surface in @('cpu','render')) {
            $prefix = @()
            $userArgs = @('--output-prefix=tack-v016')
            if ($surface -eq 'cpu') { $prefix = @('--headless') }
            else { $userArgs += '--render' }
            Invoke-GodotCheck -Name "boomerang-v0131-repeat-$surface" -Arguments ($prefix + @('--script','res://tests/chain_repeat.gd','--quit-after','6000','--') + $userArgs) -ExpectedResult 'CHAIN REPEAT COMPLETE:'
            Invoke-GodotCheck -Name "boomerang-v0131-stability-$surface" -Arguments ($prefix + @('--script','res://tests/chain_stability.gd','--quit-after','6000','--') + $userArgs) -ExpectedResult 'CHAIN STABILITY COMPLETE: \d+ checks, 0 failures'
            Invoke-GodotCheck -Name "boomerang-v0131-campaign-$surface" -Arguments ($prefix + @('--script','res://tests/chain_campaign.gd','--quit-after','6000','--') + $userArgs) -ExpectedResult 'CHAIN CAMPAIGN COMPLETE:'
        }
        Invoke-GodotCheck -Name 'boomerang-v0131-stability-cpu-short' -Arguments @('--headless','--script','res://tests/chain_stability.gd','--','--short','--output-prefix=tack-v016') -ExpectedResult 'CHAIN STABILITY COMPLETE: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'boomerang-v0131-stability-render-profile' -Arguments @('--script','res://tests/chain_stability.gd','--','--render','--capture-stages','--output-prefix=tack-v016') -ExpectedResult 'CHAIN STABILITY COMPLETE: \d+ checks, 0 failures'
        Invoke-GodotCheck -Name 'boomerang-v0131-probe-after' -Arguments @('--headless','--script','res://tests/chain_benchmark.gd','--','--core','--phase=probe-after','--trials=2','--detail','--output-prefix=tack-v016') -ExpectedResult 'CHAIN BENCHMARK COMPLETE:'
        & (Join-Path $PSScriptRoot 'analyze_chain_profiles.ps1') -ProjectRoot $projectRoot -CurrentPrefix 'tack-v016'
    }
    if ($BoomerangTier5Benchmark) {
        foreach ($surface in @('cpu','render')) {
            $benchArgs = @('--script','res://tests/boomerang_tier5_benchmark.gd','--quit-after','30000','--')
            if ($surface -eq 'cpu') { $benchArgs = @('--headless') + $benchArgs }
            else { $benchArgs += '--render' }
            Invoke-GodotCheck -Name "boomerang-v014-after-$surface" -Arguments $benchArgs -ExpectedResult 'BOOMERANG TIER5 BENCHMARK COMPLETE:'
        }
        & (Join-Path $PSScriptRoot 'compare_boomerang_tier5.ps1') -ProjectRoot $projectRoot
    }
    if ($TackTier5Benchmark -or $TackBenchmark) {
        foreach ($surface in @('cpu','render')) {
            $benchArgs = @('--script','res://tests/tack_tier5_benchmark.gd','--quit-after','50000','--')
            if ($surface -eq 'cpu') { $benchArgs = @('--headless') + $benchArgs }
            else { $benchArgs += '--render' }
            Invoke-GodotCheck -Name "tack-v016-$surface" -Arguments $benchArgs -ExpectedResult 'TACK TIER5 BENCHMARK COMPLETE:140rows'
        }
        & (Join-Path $PSScriptRoot 'compare_tack_tier5.ps1') -ProjectRoot $projectRoot
    }
    Write-Output 'All requested checks passed.'

} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
