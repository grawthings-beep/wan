$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
Set-Location -LiteralPath $repoRoot

$requiredFiles = @(
    "README.md",
    "NOTICE.md",
    "docs/dependencies.md",
    "manifests/custom_nodes.json",
    "manifests/models.json",
    "scripts/download-hf-models.ps1",
    "scripts/download_hf_models.py",
    "scripts/install_custom_nodes.py",
    "runpod/start.sh",
    "runpod/README.md",
    "workflows/WAN2.2-I2V-AutoPrompt-Story.json"
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Missing required file: $file"
    }
}

$customNodes = Get-Content -LiteralPath "manifests/custom_nodes.json" -Raw | ConvertFrom-Json
$models = Get-Content -LiteralPath "manifests/models.json" -Raw | ConvertFrom-Json
$workflow = Get-Content -LiteralPath "workflows/WAN2.2-I2V-AutoPrompt-Story.json" -Raw | ConvertFrom-Json

if (-not $customNodes.custom_nodes -or $customNodes.custom_nodes.Count -lt 1) {
    throw "custom_nodes.json does not contain any custom node entries."
}

if (-not $models.models -or $models.models.Count -lt 1) {
    throw "models.json does not contain any model entries."
}

if (-not $workflow.nodes -or $workflow.nodes.Count -lt 1) {
    throw "Workflow JSON does not contain any nodes."
}

$trackedFiles = @(git ls-files)
$blockedExtensions = @(
    ".safetensors", ".ckpt", ".pt", ".pth", ".bin", ".gguf", ".onnx", ".engine", ".pkl",
    ".mp4", ".mov", ".avi", ".mkv", ".webm", ".wav", ".flac", ".mp3",
    ".png", ".jpg", ".jpeg", ".webp"
)

$blockedTracked = @(
    $trackedFiles | Where-Object {
        $extension = [System.IO.Path]::GetExtension($_).ToLowerInvariant()
        $blockedExtensions -contains $extension
    }
)

if ($blockedTracked.Count -gt 0) {
    throw "Large model/media artifacts are tracked: $($blockedTracked -join ', ')"
}

Write-Host "Repository validation passed."
Write-Host "Custom nodes: $($customNodes.custom_nodes.Count)"
Write-Host "Model entries: $($models.models.Count)"
Write-Host "Workflow nodes: $($workflow.nodes.Count)"
