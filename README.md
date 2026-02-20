# Automated SDXL LoRA Pipeline for OneTrainer

This is a simple vibe-coded project, where we have two powershell scripts, one is to generate captions using ollama(llava) model. The other script takes input directory with images(and acaptions) and create the LORA file.  This absreaction is to simplify the process by hiding the jargons , just shoot and forget. 


**NOTE:**
1. If you have the SDXL base model downloaded, provide the path during training using `-BaseModelPath` , else the script will auto-download it.
2. You must have Ollama running on the PC with the `llava` model working for auto smart captioning.


**IMPORTANT** 

If you understand these parameters, please feel free to further fine tune these. (this is vibe coded and may not be the best). The main work is done by OneTrainer, all credits to them. This is just a wrapper. 

---

## Step 0: Clone OneTrainer.

```git clone https://github.com/Nerogar/OneTrainer.git```

```cd OneTrainer```

## Step 1: Review and edit the configuration file
*If you do not understand these parameters, just leave them as is, these works fine for me*

```json
technekey D:\OneTrainer> cat .\training_params.json
{
    "repeats": 5,
    "epochs": 13,
    "batch_size": 1,
    "unet_learning_rate": 0.0001,
    "text_encoder_learning_rate": 0.00001,
    "resolution": 1024,
    "scheduler": "COSINE",
    "lora_rank": 32,
    "lora_alpha": 16.0
}
```

---

## Step 2: Generate Captions, OR manually create them.

Run the captioner script. You can use the help flag to see available options:

```powershell
technekey D:\OneTrainer> .\Ollama_Captioner.ps1 -help

=====================================================
 OLLAMA VISION AUTO-CAPTIONER (HEIC SUPPORTED)
=====================================================
Usage:
  .\Ollama_Captioner.ps1 -ImagesDir <path> -TriggerWord <word> [-OllamaModel <model>]

Parameters:
  -ImagesDir     : (REQUIRED) Directory containing your images (JPG, PNG, WEBP, HEIC).
  -TriggerWord   : (REQUIRED) The specific trigger word for your LoRA.
  -OllamaModel   : (OPTIONAL) Vision model to use. Default is 'llava'.
  -Help          : Show this help message.

Example:
  .\Ollama_Captioner.ps1 -ImagesDir "D:\john_photos\" -TriggerWord "john"
=====================================================
```

**Example Run:**

```powershell
technekey D:\OneTrainer> .\Ollama_Captioner.ps1 -ImagesDir "D:\john_photos\" -TriggerWord "john"
 [System] Checking for Ollama on localhost:11434...
 [Action] Processing 11 images with llava...
--------------------------------------------------------
 -> Reading: 20250719_174539.jpg [DONE]
    Caption: photo of john person, man, pose, daylight, casual dress
 -> Reading: 20250731_192818.jpg [DONE]
    Caption: photo of john person, man, glasses, sunglasses, city, skyscraper, outdoors, daytime, black jacket, long hair, sunglasses on head, white buildings, smiling
 -> Reading: 20250918_101821.jpg [DONE]
    Caption: photo of john person, man, money, camera phone, selfie, indoors, dark hair
 -> Reading: 20251019_172245.jpg [DONE]
```

---

## Step 3: Review the captions

Review the generated `.txt` files in your image directory (e.g., `D:\john_photos\`). Modify them manually if needed to ensure the AI captured the correct clothing, lighting, and background details without describing the subject's face.

---

## Step 4: Start the training

Once captions are generated and reviewed, you can start the training process. Use `-ShowHelp` to view the required arguments.

```powershell
technekey D:\OneTrainer> .\image_trainer.ps1 -ShowHelp

=====================================================
 ONETRAINER AUTOMATED LORA PIPELINE (JSON DRIVEN)
=====================================================
Usage:
  .\image_trainer.ps1 -InputImagesDir <path> -OutputModelName <name> -TriggerWord <word>

Required Parameters:
  -InputImagesDir     : Folder containing training images (and .txt caption files).
  -OutputModelName    : The name of the final .safetensors file.
  -TriggerWord        : The unique token to summon your subject (e.g., 'john').

Optional Parameters:
  -ParamsJsonPath     : Path to JSON file containing training math. Default: 'training_params.json'.
  -BaseModelPath      : Path to base SDXL model.
  -ShowHelp           : Show this help message.

Example:
  .\image_trainer.ps1 -InputImagesDir "D:\john_photos\" -OutputModelName "johnFace" -TriggerWord "john"
=====================================================
```

**Example Run:**

```powershell
technekey D:\OneTrainer> .\image_trainer.ps1 -InputImagesDir "D:\john_photos\" -OutputModelName "johnFace" -TriggerWord "john"  -ParamsJsonPath .\training_params.json
 [System] Loading training parameters from: .\training_params.json
   -> Targets: 5 Repeats | 13 Epochs | Batch Size 1
   -> Network: Rank 32 | Alpha 16
   -> LR: UNet (0.0001) | Text Encoders (1E-05)
 [System] Workspace created at: D:\AUDIO-WEBUI\OneTrainer\Workspaces\johnFace
 [Data] Locally Resizing and Prepping Images...
   + Processed: 20250526_194625.jpg -> 768x1024
   + Processed: 20250719_174539.jpg -> 1024x768
   + Processed: 20250731_192818.jpg -> 1024x768
   + Processed: 20250731_193827.jpg -> 768x1024
   + Processed: 20250731_195410.jpg -> 768x1024
   + Processed: 20250731_195415.jpg -> 768x1024
   + Processed: 20250731_211124.jpg -> 768x1024
   + Processed: 20250801_174314.jpg -> 768x1024
   + Processed: 20250802_201000.jpg -> 768x1024
   + Processed: 20250802_201037.jpg -> 768x1024
   + Processed: 20250802_201356.jpg -> 768x1024
   + Processed: 20250802_201437.jpg -> 768x1024
   + Processed: 20250803_110747.jpg -> 768x1024
   + Processed: 20250918_101716.jpg -> 576x1024
   + Processed: 20250918_101821.jpg -> 1024x577
   + Processed: 20251019_172245.jpg -> 1024x768
   + Processed: 20251019_172325.jpg -> 1024x768
   + Processed: 20251020_193242.jpg -> 1024x768
   + Processed: 20251020_193701.jpg -> 577x1024
   + Processed: 20251023_134321.jpg -> 768x1024
   + Processed: 20251030_213216.jpg -> 576x1024
   + Processed: 20251129_133631.jpg -> 1024x768
   + Processed: 20251223_130047.jpg -> 1024x768
   + Processed: 20251226_150504.jpg -> 576x1024
   + Processed: 20251227_115758.jpg -> 768x1024
   + Processed: 20251228_152135.jpg -> 768x1024
   + Processed: 20260113_153706.jpg -> 768x1024
   + Processed: 20260115_131418.jpg -> 1024x768
   + Processed: 20260115_132158.jpg -> 768x1024
   + Processed: 20260124_144929.jpg -> 1024x768
   + Processed: 20260124_161213.jpg -> 768x1024
   + Processed: 20260129_194720.jpg -> 768x1024
   + Processed: 20260129_194742.jpg -> 576x1024
   + Processed: 20260129_195630.jpg -> 577x1024
   + Processed: 20260129_201453.jpg -> 768x1024
   + Processed: 20260208_175429.jpg -> 768x1024
   + Processed: 20260211_202117.jpg -> 768x1024
   + Processed: IMG-20250815-WA0024.jpg -> 768x1024
   + Processed: IMG-20260124-WA0044(1).jpg -> 768x1024
 [Config] Generating Training Configuration from JSON...
 [Action] Starting OneTrainer...
--------------------------------------------------------
Could not set optimizer as ADAMW8BIT
Clearing cache directory D:\AUDIO-WEBUI\OneTrainer\Workspaces\johnFace\cache! You can disable this if you want to continue using the same cache.
D:\AUDIO-WEBUI\OneTrainer\venv\Lib\site-packages\tensorboard\default.py:30: UserWarning: pkg_resources is deprecated as an API. See https://setuptools.pypa.io/en/latest/pkg_resources.html. The pkg_resources package is slated for removal as early as 2025-11-30. Refrain from using this package or pin to Setuptools<81.
  import pkg_resources
Fetching 17 files: 100%|██████████████████████████████████████████████████████████████████████████████████████████████████████████████████████| 17/17 [00:00<00:00, 266056.60it/s]
Loading pipeline components...:  57%|███████████████████████████████████████████████████████████████▍                                               | 4/7 [00:00<00:00,  4.42it/s]TensorFlow installation not found - running with reduced feature set.
E0220 12:11:00.308032 28476 program.py:300] TensorBoard could not bind to port 6006, it was already in use
ERROR: TensorBoard could not bind to port 6006, it was already in use
Loading pipeline components...: 100%|███████████████████████████████████████████████████████████████████████████████████████████████████████████████| 7/7 [00:06<00:00,  1.07it/s]
Selected layers: 794
Deselected layers: 0
Note: Enable Debug mode to see the full list of layer names
enumerating sample paths: 100%|████████████████████████████████████████████████████████████████████████████████████████████████████████████████████| 1/1 [00:00<00:00, 749.12it/s]
caching: 100%|████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [00:12<00:00,  3.18it/s]
step: 100%|██████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [01:28<00:00,  2.27s/it, loss=0.00467, smooth loss=0.133]
step: 100%|████████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [02:16<00:00,  3.50s/it, loss=0.287, smooth loss=0.139]
step: 100%|████████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [01:09<00:00,  1.79s/it, loss=0.313, smooth loss=0.131]
step: 100%|████████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [01:05<00:00,  1.67s/it, loss=0.317, smooth loss=0.127]
step: 100%|████████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [01:07<00:00,  1.73s/it, loss=0.263, smooth loss=0.133]
step: 100%|██████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [01:03<00:00,  1.62s/it, loss=0.00558, smooth loss=0.129]
step: 100%|███████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [01:02<00:00,  1.61s/it, loss=0.00741, smooth loss=0.13]
step: 100%|████████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [01:03<00:00,  1.63s/it, loss=0.0158, smooth loss=0.14]
step: 100%|████████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [01:06<00:00,  1.70s/it, loss=0.159, smooth loss=0.142]
step: 100%|███████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [01:03<00:00,  1.62s/it, loss=0.0425, smooth loss=0.143]
step: 100%|████████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [01:09<00:00,  1.78s/it, loss=0.109, smooth loss=0.149]
step: 100%|████████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [01:18<00:00,  2.02s/it, loss=0.055, smooth loss=0.142]
step: 100%|█████████████████████████████████████████████████████████████████████████████████████████████████████████| 39/39 [01:05<00:00,  1.69s/it, loss=0.179, smooth loss=0.14]
epoch: 100%|██████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████| 13/13 [16:20<00:00, 75.42s/it]
Creating Backup D:\AUDIO-WEBUI\OneTrainer\Workspaces\johnFace\backup\2026-02-20_12-27-42-backup-507-13-0
Saving D:\AUDIO-WEBUI\OneTrainer\Workspaces\johnFace\output\johnFace.safetensors
--------------------------------------------------------
 [Success] Training Complete!
 LoRA saved to: D:\OneTrainer\Workspaces\johnFace\output\johnFace.safetensors
technekey D:\OneTrainer>
   ...
 [Config] Generating Training Configuration from JSON...
 [Action] Starting OneTrainer...
--------------------------------------------------------
```
