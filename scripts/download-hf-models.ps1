param(
    [Parameter(Mandatory = $true)]
    [string]$ComfyUIPath,

    [ValidateSet("gguf", "fp8", "mmaudio", "optional", "all")]
    [string]$Profile = "gguf",

    [string]$ManifestPath,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $PSScriptRoot "..\manifests\models.json"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$root = (Resolve-Path -LiteralPath $ComfyUIPath).Path

function Test-ProfileMatch {
    param($Model)

    if ($Profile -eq "all") {
        return $true
    }

    $profiles = @($Model.profiles)
    return ($profiles -contains $Profile) -or ($profiles -contains "base")
}

$selected = @($manifest.models | Where-Object { Test-ProfileMatch $_ })
$downloadable = @($selected | Where-Object { $_.downloadable -eq $true -and $_.source_url })
$manual = @($selected | Where-Object { $_.downloadable -ne $true -or -not $_.source_url })

foreach ($model in $downloadable) {
    $targetDir = Join-Path $root $model.target_path
    $targetFile = Join-Path $targetDir $model.filename

    if (Test-Path -LiteralPath $targetFile) {
        Write-Host "Exists: $targetFile"
        continue
    }

    Write-Host "Download: $($model.filename)"
    Write-Host "  -> $targetFile"

    if ($DryRun) {
        continue
    }

    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Invoke-WebRequest -Uri $model.source_url -OutFile $targetFile
}

if ($manual.Count -gt 0) {
    Write-Host ""
    Write-Host "Manual downloads still needed:"
    foreach ($model in $manual) {
        Write-Host "- $($model.filename) -> $($model.target_path)"
        if ($model.source_url) {
            Write-Host "  $($model.source_url)"
        }
        if ($model.notes) {
            Write-Host "  Note: $($model.notes)"
        }
    }
}
