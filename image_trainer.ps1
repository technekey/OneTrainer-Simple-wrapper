<#
.SYNOPSIS
    Automated LoRA Trainer for OneTrainer.
    JSON-DRIVEN EDITION: Fully parameterized with Custom Help Menu.
#>

param(
    [string]$InputImagesDir = "",
    [string]$OutputModelName = "",
    [string]$TriggerWord = "",
    [string]$BaseModelPath = "Models/sd_xl_base_1.0.safetensors",
    [string]$ParamsJsonPath = "training_params.json",
    [switch]$ShowHelp
)

$ErrorActionPreference = "Stop"

# --- 1. HELP MENU ---
if ($ShowHelp -or $InputImagesDir -eq "" -or $OutputModelName -eq "" -or $TriggerWord -eq "") {
    Write-Host ""
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host " ONETRAINER AUTOMATED LORA PIPELINE (JSON DRIVEN)" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host "Usage:"
    Write-Host "  .\image_trainer.ps1 -InputImagesDir <path> -OutputModelName <name> -TriggerWord <word>"
    Write-Host ""
    Write-Host "Required Parameters:"
    Write-Host "  -InputImagesDir     : Folder containing training images (and .txt caption files)."
    Write-Host "  -OutputModelName    : The name of the final .safetensors file."
    Write-Host "  -TriggerWord        : The unique token to summon your subject (e.g., 'ankita')."
    Write-Host ""
    Write-Host "Optional Parameters:"
    Write-Host "  -ParamsJsonPath     : Path to JSON file containing training math. Default: 'training_params.json'."
    Write-Host "  -BaseModelPath      : Path to base SDXL model."
    Write-Host "  -ShowHelp           : Show this help message."
    Write-Host ""
    Write-Host "Example:"
    Write-Host "  .\image_trainer.ps1 -InputImagesDir `"D:\ankita_photos\`" -OutputModelName `"AnkitaFace`" -TriggerWord `"ankita`""
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host ""
    exit
}

$OneTrainerRoot = Get-Location
$PythonPath = "$OneTrainerRoot\venv\Scripts\python.exe"
$TrainScript = "$OneTrainerRoot\scripts\train.py"

Add-Type -AssemblyName System.Drawing

# --- 2. LOAD JSON PARAMETERS ---
Write-Host " [System] Loading training parameters from: $ParamsJsonPath" -ForegroundColor Cyan
if (-not (Test-Path $ParamsJsonPath)) {
    Write-Error "Could not find parameters file at $ParamsJsonPath. Please create it."
}

$Params = Get-Content -Path $ParamsJsonPath | ConvertFrom-Json
$Repeats = [int]$Params.repeats
$Epochs = [int]$Params.epochs
$BatchSize = [int]$Params.batch_size
$UnetLR = [double]$Params.unet_learning_rate
$TextEncoderLR = [double]$Params.text_encoder_learning_rate
$Resolution = [string]$Params.resolution
$Scheduler = [string]$Params.scheduler
$Rank = [int]$Params.lora_rank
$Alpha = [double]$Params.lora_alpha

Write-Host "   -> Targets: $Repeats Repeats | $Epochs Epochs | Batch Size $BatchSize" -ForegroundColor Gray
Write-Host "   -> Network: Rank $Rank | Alpha $Alpha" -ForegroundColor Gray
Write-Host "   -> LR: UNet ($UnetLR) | Text Encoders ($TextEncoderLR)" -ForegroundColor Gray

if (-not (Test-Path $PythonPath)) {
    Write-Error "Could not find OneTrainer Python venv. Please run this script from inside the OneTrainer folder."
}

# --- 3. WORKSPACE SETUP ---
$WorkspaceDir = "$OneTrainerRoot\Workspaces\$OutputModelName"
$TrainingDataDir = "$WorkspaceDir\training_data"
$ModelOutDir = "$WorkspaceDir\output"
$LogDir = "$WorkspaceDir\logs"

New-Item -ItemType Directory -Force -Path $TrainingDataDir | Out-Null
New-Item -ItemType Directory -Force -Path $ModelOutDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

Write-Host " [System] Workspace created at: $WorkspaceDir" -ForegroundColor Green

# --- 4. IMAGE RESIZING & CAPTION HANDLING ---
Write-Host " [Data] Locally Resizing and Prepping Images..." -ForegroundColor Cyan

$ImageExtensions = @("*.jpg", "*.jpeg", "*.png", "*.webp")
$Images = Get-ChildItem -Path $InputImagesDir -Include $ImageExtensions -Recurse

if ($Images.Count -eq 0) { Write-Error "No images found in $InputImagesDir" }

$MaxDim = [double]$Resolution
$ValidImagesCount = 0

foreach ($img in $Images) {
    try {
        $origImg = [System.Drawing.Image]::FromFile($img.FullName)
        $width = $origImg.Width
        $height = $origImg.Height
        $ratio = [math]::Min($MaxDim / $width, $MaxDim / $height)

        if ($ratio -lt 1.0) {
            $newW = [int][math]::Round($width * $ratio)
            $newH = [int][math]::Round($height * $ratio)
        } else {
            $newW = $width
            $newH = $height
        }

        $newBmp = New-Object System.Drawing.Bitmap($newW, $newH)
        $graphics = [System.Drawing.Graphics]::FromImage($newBmp)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($origImg, 0, 0, $newW, $newH)

        $safeName = $img.BaseName -replace '[^a-zA-Z0-9]', '_'
        $destImg = Join-Path $TrainingDataDir ($safeName + ".jpg")
        $newBmp.Save($destImg, [System.Drawing.Imaging.ImageFormat]::Jpeg)

        $graphics.Dispose(); $newBmp.Dispose(); $origImg.Dispose()

        # DYNAMIC CAPTIONING
        $txtDestPath = Join-Path $TrainingDataDir ($safeName + ".txt")
        $sourceTxtPath = Join-Path $img.DirectoryName ($img.BaseName + ".txt")

        if (Test-Path $sourceTxtPath) {
            Copy-Item -Path $sourceTxtPath -Destination $txtDestPath
        } else {
            $cleanFilename = $img.BaseName -replace '[_-]', ' ' -replace '\d+', ''
            $captionContent = "photo of $TriggerWord person, $cleanFilename"
            Set-Content -Path $txtDestPath -Value $captionContent.Trim()
        }

        Write-Host "   + Processed: $($img.Name) -> ${newW}x${newH}" -ForegroundColor Gray
        $ValidImagesCount++

    } catch {
        Write-Host "   - SKIPPED: $($img.Name) -> Unreadable/Corrupted" -ForegroundColor Red
    }
}

if ($ValidImagesCount -eq 0) { Write-Error "No valid images could be processed." }

# --- 5. BASE MODEL CHECK ---
if (-not (Test-Path $BaseModelPath)) {
    Write-Host " [Model] Base model not found at $BaseModelPath" -ForegroundColor Yellow
    $Download = Read-Host "Would you like to download standard SDXL Base 1.0? (Y/N)"
    if ($Download -eq 'Y') {
        Write-Host " [Download] Downloading SDXL Base (approx 7GB)..." -ForegroundColor Magenta
        $URL = "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors"
        New-Item -ItemType Directory -Force -Path (Split-Path $BaseModelPath) | Out-Null
        Invoke-WebRequest -Uri $URL -OutFile $BaseModelPath
    } else {
        Write-Error "Base model is required to train."
    }
}

# --- 6. GENERATE CONFIGURATION (INJECTING JSON DATA) ---
Write-Host " [Config] Generating Training Configuration from JSON..." -ForegroundColor Cyan

$ConfigTemplate = @{
    "__version" = 10
    "training_method" = "LORA"
    "model_type" = "STABLE_DIFFUSION_XL_10_BASE"
    "workspace_dir" = $WorkspaceDir
    "cache_dir" = "$WorkspaceDir\cache"
    "tensorboard" = $true
    "tensorboard_expose" = $false
    "tensorboard_always_on" = $false
    "tensorboard_port" = 6006
    "validation" = $false
    "base_model_name" = $BaseModelPath
    "output_dtype" = "FLOAT_16"
    "output_model_format" = "SAFETENSORS"
    "output_model_destination" = "$ModelOutDir\$OutputModelName.safetensors"
    "gradient_checkpointing" = "ON"
    "enable_async_offloading" = $true
    "enable_activation_offloading" = $true

    "concepts" = @(
        @{
            "name" = "concept_1"
            "path" = $TrainingDataDir
            "class_tokens" = "person"
            "num_repeats" = $Repeats
            "aspect_ratio_bucketing" = $true
        }
    )

    "aspect_ratio_bucketing" = $true
    "latent_caching" = $true
    "clear_cache_before_training" = $true

    "learning_rate_scheduler" = $Scheduler
    "learning_rate" = $UnetLR
    "learning_rate_warmup_steps" = 100.0
    "epochs" = $Epochs
    "batch_size" = $BatchSize

    "gradient_accumulation_steps" = 1
    "train_device" = "cuda"
    "temp_device" = "cpu"
    "train_dtype" = "BFLOAT_16"
    "resolution" = $Resolution

    "unet" = @{
        "include" = $true
        "train" = $true
        "learning_rate" = $null
        "weight_dtype" = "FLOAT_32"
    }
    "prior" = @{ "include" = $true; "train" = $false }
    "transformer" = @{ "include" = $true; "train" = $true }

    "text_encoder" = @{
        "include" = $true
        "train" = $true
        "learning_rate" = $TextEncoderLR
        "weight_dtype" = "FLOAT_32"
    }
    "text_encoder_sequence_length" = 512
    "text_encoder_2" = @{
        "include" = $true
        "train" = $true
        "learning_rate" = $TextEncoderLR
        "weight_dtype" = "FLOAT_32"
    }
    "text_encoder_2_sequence_length" = 77
    "text_encoder_3" = @{ "include" = $true; "train" = $false }
    "text_encoder_4" = @{ "include" = $true; "train" = $false }
    "vae" = @{ "include" = $true; "train" = $false }

    "peft_type" = "LORA"
    "lora_rank" = $Rank
    "lora_alpha" = $Alpha
    "lora_decompose" = $false
    "lora_weight_dtype" = "FLOAT_32"

    "optimizer" = @{
        "__version" = 0
        "optimizer" = "ADAMW8BIT"
        "adam_w_mode" = $true
        "alpha" = $null
        "amsgrad" = $false
        "beta1" = 0.9
        "beta2" = 0.999
        "beta3" = $null
        "bias_correction" = $false
        "block_wise" = $false
        "capturable" = $false
        "centered" = $false
        "clip_threshold" = $null
        "d0" = $null
        "d_coef" = $null
        "dampening" = $null
        "decay_rate" = $null
        "decouple" = $false
        "differentiable" = $false
        "eps" = 1e-08
        "eps2" = $null
        "foreach" = $false
        "fsdp_in_use" = $false
        "fused" = $false
        "fused_back_pass" = $false
        "growth_rate" = $null
        "initial_accumulator_value" = $null
        "initial_accumulator" = $null
        "is_paged" = $false
        "log_every" = $null
        "lr_decay" = $null
        "max_unorm" = $null
        "maximize" = $false
        "min_8bit_size" = $null
        "quant_block_size" = $null
        "momentum" = $null
        "nesterov" = $false
        "no_prox" = $false
        "optim_bits" = $null
        "percentile_clipping" = $null
        "r" = $null
        "relative_step" = $false
        "safeguard_warmup" = $false
        "scale_parameter" = $false
        "stochastic_rounding" = $false
        "use_bias_correction" = $false
        "use_triton" = $false
        "warmup_init" = $false
        "weight_decay" = 0.01
        "weight_lr_power" = $null
        "decoupled_decay" = $false
        "fixed_decay" = $false
        "rectify" = $false
        "degenerated_to_sgd" = $false
        "k" = $null
        "xi" = $null
        "n_sma_threshold" = $null
        "ams_bound" = $false
        "adanorm" = $false
        "adam_debias" = $false
        "slice_p" = $null
        "cautious" = $false
        "weight_decay_by_lr" = $true
        "prodigy_steps" = $null
        "use_speed" = $false
        "split_groups" = $true
        "split_groups_mean" = $true
        "factored" = $true
        "factored_fp32" = $true
        "use_stableadamw" = $true
        "use_cautious" = $false
        "use_grams" = $false
        "use_adopt" = $false
        "d_limiter" = $true
        "use_schedulefree" = $true
        "use_orthograd" = $false
        "nnmf_factor" = $false
        "orthogonal_gradient" = $false
        "use_atan2" = $false
        "use_AdEMAMix" = $false
        "beta3_ema" = $null
        "alpha_grad" = $null
        "beta1_warmup" = $null
        "min_beta1" = $null
        "Simplified_AdEMAMix" = $false
        "cautious_mask" = $false
        "grams_moment" = $false
        "kourkoutas_beta" = $false
        "k_warmup_steps" = $null
        "schedulefree_c" = $null
        "ns_steps" = $null
        "MuonWithAuxAdam" = $false
        "muon_hidden_layers" = $null
        "muon_adam_regex" = $false
        "muon_adam_lr" = $null
        "muon_te1_adam_lr" = $null
        "muon_te2_adam_lr" = $null
        "muon_adam_config" = $null
        "rms_rescaling" = $true
        "normuon_variant" = $false
        "beta2_normuon" = $null
        "normuon_eps" = $null
        "low_rank_ortho" = $false
        "ortho_rank" = $null
        "accelerated_ns" = $false
        "cautious_wd" = $false
        "approx_mars" = $false
        "kappa_p" = $null
        "auto_kappa_p" = $false
        "compile" = $false
    }
}

$ConfigJson = $ConfigTemplate | ConvertTo-Json -Depth 10
$ConfigPath = "$WorkspaceDir\training_config.json"
Set-Content -Path $ConfigPath -Value $ConfigJson

# --- 7. RUN TRAINING ---
Write-Host " [Action] Starting OneTrainer..." -ForegroundColor Green
Write-Host "--------------------------------------------------------"

$ProcessArgs = @("$TrainScript", "--config-path", "$ConfigPath")
& $PythonPath $ProcessArgs

if ($LASTEXITCODE -eq 0) {
    Write-Host "--------------------------------------------------------"
    Write-Host " [Success] Training Complete!" -ForegroundColor Green
    Write-Host " LoRA saved to: $ModelOutDir\$OutputModelName.safetensors"
} else {
    Write-Host " [Error] Training failed. Check the logs above." -ForegroundColor Red
}
