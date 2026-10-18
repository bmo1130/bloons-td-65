param(
    [string]$Godot = 'godot',
    [switch]$Visual
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
    param([string]$Name, [string[]]$Arguments)
    $logPath = Join-Path $resultsPath "$Name.log"
    & $Godot --path $projectRoot --log-file $logPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE"
    }
    # Godot editor import can return zero even when a script failed to parse.
    if (Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR:|ERROR:' -Quiet) {
        throw "$Name reported errors. See $logPath"
    }
}

try {
    Invoke-GodotCheck -Name 'import' -Arguments @('--headless', '--editor', '--quit')
    Invoke-GodotCheck -Name 'tests' -Arguments @('--headless', '--script', 'res://tests/run_tests.gd')
    Invoke-GodotCheck -Name 'main' -Arguments @('--headless', '--quit-after', '120')
    if ($Visual) {
        Invoke-GodotCheck -Name 'visual' -Arguments @('--script', 'res://tests/visual_smoke.gd')
    }
    Write-Output 'All requested checks passed.'
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
