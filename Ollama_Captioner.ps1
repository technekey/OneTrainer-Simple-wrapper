<#
.SYNOPSIS
    All-in-One Ollama Auto-Captioner (with Native HEIC Auto-Conversion)
#>

param(
    [string]$ImagesDir = "",
    [string]$TriggerWord = "",
    [string]$OllamaModel = "llava",
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# --- HELP MENU LOGIC ---
if ($Help -or $ImagesDir -eq "" -or $TriggerWord -eq "") {
    Write-Host ""
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host " OLLAMA VISION AUTO-CAPTIONER (HEIC SUPPORTED)" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "Usage:"
    Write-Host "  .\Ollama_Captioner.ps1 -ImagesDir <path> -TriggerWord <word> [-OllamaModel <model>]"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -ImagesDir     : (REQUIRED) Directory containing your images (JPG, PNG, WEBP, HEIC)."
    Write-Host "  -TriggerWord   : (REQUIRED) The specific trigger word for your LoRA."
    Write-Host "  -OllamaModel   : (OPTIONAL) Vision model to use. Default is 'llava'."
    Write-Host "  -Help          : Show this help message."
    Write-Host ""
    Write-Host "Example:"
    Write-Host "  .\Ollama_Captioner.ps1 -ImagesDir `"D:\ankita_photos\`" -TriggerWord `"ankita`""
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host ""
    exit
}

Write-Host " [System] Checking for Ollama on localhost:11434..." -ForegroundColor Cyan
try {
    $check = Invoke-RestMethod -Uri "http://localhost:11434/" -Method Get -TimeoutSec 2
} catch {
    Write-Error "Ollama does not appear to be running. Please start Ollama first."
}

# --- 1. HEIC AUTO-CONVERSION BLOCK ---
$heicFiles = Get-ChildItem -Path $ImagesDir -Filter "*.heic" -Recurse
if ($heicFiles.Count -gt 0) {
    Write-Host " [System] Found $($heicFiles.Count) HEIC files. Converting to JPG in the background..." -ForegroundColor Yellow

    $PythonPath = "$PWD\venv\Scripts\python.exe"
    $SafeDir = $ImagesDir -replace '\\', '\\' # Escape backslashes for Python

    $PyScript = @"
import sys, os, subprocess
try:
    from PIL import Image
    import pillow_heif
except ImportError:
    print('   -> Installing pillow-heif into OneTrainer environment...')
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'pillow-heif', '-q'])
    from PIL import Image
    import pillow_heif

pillow_heif.register_heif_opener()
folder = "$SafeDir"
backup_dir = os.path.join(folder, 'HEIC_Originals')
os.makedirs(backup_dir, exist_ok=True)

for filename in os.listdir(folder):
    if filename.lower().endswith('.heic'):
        heic_path = os.path.join(folder, filename)
        jpg_path = os.path.join(folder, filename[:filename.rfind('.')] + '.jpg')

        img = Image.open(heic_path)
        img.save(jpg_path, 'JPEG')
        os.replace(heic_path, os.path.join(backup_dir, filename))
print('   -> HEIC conversion complete!')
"@

    $PyFile = "$PWD\temp_convert.py"
    Set-Content -Path $PyFile -Value $PyScript
    if (Test-Path $PythonPath) {
        & $PythonPath $PyFile
    } else {
        & python $PyFile
    }
    Remove-Item $PyFile
}

# --- 2. OLLAMA CAPTIONING BLOCK ---
$ImageExtensions = @("*.jpg", "*.jpeg", "*.png", "*.webp") # HEIC excluded as they are now JPGs
$Images = Get-ChildItem -Path $ImagesDir -Include $ImageExtensions -Recurse

if ($Images.Count -eq 0) {
    Write-Error "No valid images found in $ImagesDir to caption."
}

Write-Host " [Action] Processing $($Images.Count) images with $OllamaModel..." -ForegroundColor Green
Write-Host "--------------------------------------------------------"

foreach ($img in $Images) {
    Write-Host " -> Reading: $($img.Name) " -NoNewline

    $base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($img.FullName))
    $txtPath = Join-Path $img.DirectoryName ($img.BaseName + ".txt")

    $ollamaPrompt = "You are a machine learning image tagger. Output ONLY a single line of comma-separated keywords describing the lighting, clothing, background, and pose. DO NOT use full sentences. DO NOT use numbers, bullet points, or line breaks. DO NOT use prefixes like 'Lighting:'."

    $body = @{
        model = $OllamaModel
        prompt = $ollamaPrompt
        images = @($base64)
        stream = $false
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 120
        $ollamaText = $response.response.Trim()

        # Aggressive Sanitization
        $ollamaText = $ollamaText -replace "`r`n", ", " -replace "`n", ", "
        $ollamaText = $ollamaText -replace "\d+[\.\)]\s*", ""
        $ollamaText = $ollamaText -replace "(?i)(camera angle|lighting|background|subject's clothing|hair style|facial expression|image shows|photo features):\s*", ""
        $ollamaText = $ollamaText -replace '\.$', ''
        $ollamaText = $ollamaText -replace ",+", "," -replace "\s+,", "," -replace ",\s+", ", "

        $finalCaption = "photo of $TriggerWord person, " + $ollamaText.Trim()

        Set-Content -Path $txtPath -Value $finalCaption
        Write-Host "[DONE]" -ForegroundColor Green
        Write-Host "    Caption: $finalCaption" -ForegroundColor DarkGray

    } catch {
        Write-Host "[FAILED]" -ForegroundColor Red
        Write-Host "    Error communicating with Ollama for this image." -ForegroundColor Red
    }
}

Write-Host "--------------------------------------------------------"
Write-Host " [Success] All images captioned! You can now run the main trainer script." -ForegroundColor Green
