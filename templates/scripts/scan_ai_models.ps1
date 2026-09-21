# scan_ai_models.ps1 — modèles IA locaux (Ollama, HF, LM Studio, GPT4All, SD, ComfyUI)
# Read-only
param(
    [int]$TopN = 50
)

. "$PSScriptRoot\_common.ps1"

_Write-Phase "scan_ai_models : providers connus"

$providers = @(
    @{ name = 'ollama';      path = "$env:USERPROFILE\.ollama\models" }
    @{ name = 'huggingface'; path = "$env:USERPROFILE\.cache\huggingface" }
    @{ name = 'lmstudio';    path = "$env:USERPROFILE\.lmstudio" }
    @{ name = 'lmstudio2';   path = "$env:USERPROFILE\.cache\lm-studio" }
    @{ name = 'gpt4all';     path = "$env:LOCALAPPDATA\nomic.ai\GPT4All" }
    @{ name = 'gpt4all2';    path = "$env:USERPROFILE\AppData\Local\nomic.ai\GPT4All" }
    @{ name = 'sd-webui';    path = "$env:USERPROFILE\stable-diffusion-webui\models" }
    @{ name = 'comfyui';     path = "$env:USERPROFILE\ComfyUI\models" }
    @{ name = 'koboldcpp';   path = "$env:USERPROFILE\KoboldCpp\models" }
    @{ name = 'jan';         path = "$env:USERPROFILE\jan\models" }
)

$byProvider = @{}
foreach ($p in $providers) {
    if (-not (Test-Path -LiteralPath $p.path)) { continue }
    _Write-Phase ("  - {0}" -f $p.name)
    $size = _Get-FolderSize -Path $p.path -TimeoutSeconds 60
    if ($size -gt 0) {
        # Top fichiers modèles
        $files = Get-ChildItem -LiteralPath $p.path -Recurse -File -Force `
            -Include '*.gguf','*.safetensors','*.bin','*.ckpt','*.pt','*.pth','*.onnx' `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Length -gt 200MB -and ($_.Attributes -notmatch 'Offline|RecallOnOpen|RecallOnDataAccess')
            } |
            Sort-Object Length -Descending |
            Select-Object -First 20 |
            ForEach-Object {
                [PSCustomObject]@{
                    name       = $_.Name
                    path       = $_.FullName
                    size_gb    = _To-GB $_.Length
                    size_human = _Format-Size $_.Length
                    modified   = $_.LastWriteTime.ToString('yyyy-MM-dd')
                }
            }
        $byProvider[$p.name] = [PSCustomObject]@{
            path       = $p.path
            size_gb    = _To-GB $size
            size_human = _Format-Size $size
            top_files  = @($files)
        }
    }
}

_Write-Phase "scan_ai_models : fichiers .gguf/.safetensors orphelins (dossiers de stockage)"
# Limité aux dossiers de stockage habituels (pas AppData/Local complet)
$orphanZones = @(
    "$env:USERPROFILE\Downloads"
    "$env:USERPROFILE\Documents"
    "$env:USERPROFILE\Desktop"
    "$env:USERPROFILE\models"
    "$env:USERPROFILE\AI"
    "$env:USERPROFILE\ml"
) | Where-Object { Test-Path -LiteralPath $_ }

$orphans = foreach ($zone in $orphanZones) {
    Get-ChildItem -LiteralPath $zone -Recurse -File -Force `
        -Include '*.gguf','*.safetensors' -ErrorAction SilentlyContinue -Depth 5 |
        Where-Object {
            $_.Length -gt 1GB -and ($_.Attributes -notmatch 'Offline|RecallOnOpen|RecallOnDataAccess')
        }
}

# Exclure ceux déjà comptés dans les providers
$knownPaths = $byProvider.Values | ForEach-Object { $_.path }
$orphanFiles = @($orphans | Where-Object {
    $f = $_.FullName
    -not ($knownPaths | Where-Object { $f.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) })
} | Sort-Object Length -Descending | Select-Object -First $TopN | ForEach-Object {
    _New-Finding -Category 'ai_model' -Label 'orphan' -Path $_.FullName -SizeBytes $_.Length `
        -Risk 'yellow' -ToolHint 'manual' `
        -Recommendation "Modèle IA hors dossier provider connu — vérifier provenance avant suppression"
})

_Report-ScanStats

$totalGb = ($byProvider.Values | Measure-Object size_gb -Sum).Sum + (($orphanFiles | Measure-Object size_gb -Sum).Sum)

$output = [PSCustomObject]@{
    category     = 'ai_models'
    by_provider  = $byProvider
    orphan_files = $orphanFiles
    totals       = [PSCustomObject]@{
        providers_count = $byProvider.Count
        orphans_count   = ($orphanFiles | Measure-Object).Count
        total_gb        = [math]::Round($totalGb, 2)
    }
}

_Emit-Json $output -Depth 8
