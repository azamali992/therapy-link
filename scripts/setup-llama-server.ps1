# Prebuilt llama.cpp (CUDA 12.4) + a Gemma 4 E2B GGUF for local eval and the tunnelled cloud path.
# No compiler needed. Idempotent.
#
#   powershell -ExecutionPolicy Bypass -File scripts\setup-llama-server.ps1 -Root D:\dev
#   D:\dev\llama\llama-server.exe -m D:\dev\models\gemma-4-E2B-it-Q4_K_M.gguf --port 8080 -ngl 99 -c 4096
#
param(
  [string]$Root = "D:\dev",
  [string]$Build = "b10955",
  [string]$GgufRepo = "unsloth/gemma-4-E2B-it-GGUF",
  [string]$Gguf = "gemma-4-E2B-it-Q4_K_M.gguf",
  [switch]$Cpu
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$llama = Join-Path $Root "llama"
$models = Join-Path $Root "models"
$tmp = Join-Path $Root "_downloads"
New-Item -ItemType Directory -Force $llama, $models, $tmp | Out-Null

function Get-File($url, $dest) {
  if (Test-Path $dest) { Write-Host "have $dest"; return }
  Write-Host "downloading $url"
  & curl.exe -L --fail --retry 3 --retry-delay 5 -o $dest $url
  if ($LASTEXITCODE -ne 0) { throw "curl failed ($LASTEXITCODE) for $url" }
}

$base = "https://github.com/ggml-org/llama.cpp/releases/download/$Build"
if ($Cpu) {
  $zips = @("llama-$Build-bin-win-cpu-x64.zip")
} else {
  $zips = @("llama-$Build-bin-win-cuda-12.4-x64.zip", "cudart-llama-bin-win-cuda-12.4-x64.zip")
}
foreach ($z in $zips) {
  $dest = Join-Path $tmp $z
  Get-File "$base/$z" $dest
  Expand-Archive $dest -DestinationPath $llama -Force
}

Get-File "https://huggingface.co/$GgufRepo/resolve/main/$Gguf" (Join-Path $models $Gguf)

$exe = Get-ChildItem $llama -Recurse -Filter llama-server.exe | Select-Object -First 1
Write-Host "`nllama-server: $($exe.FullName)`nmodel: $(Join-Path $models $Gguf)"
Write-Host "run:  `"$($exe.FullName)`" -m `"$(Join-Path $models $Gguf)`" --port 8080 -ngl 99 -c 4096"
Write-Host "eval: tl-eval generate --backend `"openai:http://localhost:8080/v1|gemma-4-e2b`" --name base-e2b"
