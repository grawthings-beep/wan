param(
    [Parameter(Mandatory = $true)]
    [string]$ComfyUIPath,

    [ValidateSet("gguf", "fp8", "mmaudio", "qwen", "optional", "all")]
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

function Test-TemplateValue {
    param([string]$Value)

    return $Value -match "\{\{.+?\}\}|\$\{[A-Za-z_][A-Za-z0-9_]*\}|\$[A-Za-z_][A-Za-z0-9_]*"
}

function Resolve-CivitaiUrl {
    param($Model)

    if ($Model.model_version_id) {
        return "https://civitai.com/api/download/models/$($Model.model_version_id)"
    }

    if ($Model.source_url -match "modelVersionId=([0-9]+)") {
        return "https://civitai.com/api/download/models/$($Matches[1])"
    }

    return $Model.source_url
}

function Get-DownloadHeaders {
    param($Model)

    $headers = @{}
    foreach ($requiredName in @($Model.requires_env | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })) {
        $requiredValue = [Environment]::GetEnvironmentVariable([string]$requiredName)
        if ([string]::IsNullOrWhiteSpace($requiredValue) -or (Test-TemplateValue $requiredValue)) {
            if ($DryRun) {
                Write-Host "DRY-RUN warning: missing required env for $($Model.filename): $requiredName"
                return $null
            }
            throw "missing required env for $($Model.filename): $requiredName"
        }
    }

    if ($Model.source_url -like "*civitai.com*") {
        $tokenName = if ($Model.token_env) { [string]$Model.token_env } else { "CIVITAI_TOKEN" }
        $token = [Environment]::GetEnvironmentVariable($tokenName)
        if ([string]::IsNullOrWhiteSpace($token) -or (Test-TemplateValue $token)) {
            if ($DryRun) {
                Write-Host "DRY-RUN warning: missing required env for $($Model.filename): $tokenName"
                return $null
            }
            throw "missing required env for $($Model.filename): $tokenName"
        }
        $headers["Authorization"] = "Bearer $token"
    }
    elseif ($Model.source_url -like "*huggingface.co*" -and $env:HF_TOKEN) {
        $headers["Authorization"] = "Bearer $env:HF_TOKEN"
    }

    return $headers
}

$selected = @($manifest.models | Where-Object { Test-ProfileMatch $_ })
$downloadable = @($selected | Where-Object { $_.downloadable -eq $true -and $_.source_url })
$manual = @($selected | Where-Object { $_.downloadable -ne $true -or -not $_.source_url })

foreach ($model in $downloadable) {
    if (-not $model.target_path -or $model.target_path -eq "custom-node-specific") {
        $manual += $model
        continue
    }

    $targetDir = Join-Path $root $model.target_path
    $targetFile = Join-Path $targetDir $model.filename
    $downloadUrl = if ($model.source_url -like "*civitai.com*") { Resolve-CivitaiUrl $model } else { $model.source_url }
    $headers = Get-DownloadHeaders $model
    if ($null -eq $headers) {
        continue
    }

    if (Test-Path -LiteralPath $targetFile) {
        Write-Host "Exists: $targetFile"
        continue
    }

    Write-Host "Download: $($model.filename)"
    Write-Host "  -> $targetFile"

    if ($DryRun) {
        Write-Host "  URL: $downloadUrl"
        continue
    }

    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    Invoke-WebRequest -Uri $downloadUrl -Headers $headers -OutFile $targetFile
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
