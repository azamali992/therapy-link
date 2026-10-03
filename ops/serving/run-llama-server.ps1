# Start Eve's llama-server from ml/registry.json, on 127.0.0.1 only, behind an API key.
#
#   $env:TL_LLM_API_KEY = "<at least 24 random characters>"
#   powershell -ExecutionPolicy Bypass -File ops\serving\run-llama-server.ps1
#
# What it does, in order:
#   1. reads ml/registry.json and picks the base + adapter that `serve` names
#   2. refuses a rejected adapter; refuses an unapproved one unless TL_LLM_ALLOW_UNAPPROVED=1
#      (never allowed with TL_ENV=prod)
#   3. checks size and sha256 of both GGUF files against the registry
#   4. starts llama-server in the foreground: 127.0.0.1, API key from the environment (not the
#      command line, so it doesn't show in the process list), --lora, --metrics, no web UI,
#      no /slots (it shows prompt text), CORS limited to localhost
#
# Environment (all optional except the key):
#   TL_LLM_API_KEY           required, >= 24 characters
#   TL_MODELS_DIR            default D:\dev\models
#   TL_LLAMA_SERVER          default D:\dev\llama\llama-server.exe
#   TL_LLM_REGISTRY          default <repo>\ml\registry.json
#   TL_LLM_ADAPTER           adapter id, default registry serve.adapter
#   TL_LLM_PORT              default 8080
#   TL_LLM_PARALLEL          slots (-np), default 2 (a 4 GB laptop GPU; use 4 on an L4)
#   TL_LLM_CTX_PER_SLOT      context per slot, default 8192 (-c is this times -np)
#   TL_LLM_NGL               GPU layers, default 99
#   TL_LLM_LOG_FILE          optional llama-server log file
#   TL_LLM_ALLOW_UNAPPROVED  1 to serve a `candidate` before clinician sign-off (dev/staging only)

$ErrorActionPreference = "Stop"

function Fail($msg) { [Console]::Error.WriteLine("run-llama-server: $msg"); exit 1 }
function EnvOr($name, $default) { $v = [Environment]::GetEnvironmentVariable($name); if ([string]::IsNullOrEmpty($v)) { $default } else { $v } }

$key = $env:TL_LLM_API_KEY
if ([string]::IsNullOrEmpty($key)) { Fail "TL_LLM_API_KEY is not set. Refusing to start llama-server without an API key." }
if ($key.Length -lt 24) { Fail "TL_LLM_API_KEY is shorter than 24 characters." }

$repo = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$registryPath = EnvOr "TL_LLM_REGISTRY" (Join-Path $repo "ml\registry.json")
$modelsDir = EnvOr "TL_MODELS_DIR" "D:\dev\models"
$server = EnvOr "TL_LLAMA_SERVER" "D:\dev\llama\llama-server.exe"
$port = [int](EnvOr "TL_LLM_PORT" "8080")
$parallel = [int](EnvOr "TL_LLM_PARALLEL" "2")
$ctxPerSlot = [int](EnvOr "TL_LLM_CTX_PER_SLOT" "8192")
$ngl = EnvOr "TL_LLM_NGL" "99"

if (-not (Test-Path $registryPath)) { Fail "registry not found: $registryPath" }
if (-not (Test-Path $server)) { Fail "llama-server not found: $server" }
$reg = Get-Content -Raw -Encoding UTF8 $registryPath | ConvertFrom-Json
$all = @($reg.base_models) + @($reg.adapters)

$adapterId = EnvOr "TL_LLM_ADAPTER" $reg.serve.adapter
$adapter = $reg.adapters | Where-Object { $_.id -eq $adapterId } | Select-Object -First 1
if ($null -eq $adapter) { Fail "adapter '$adapterId' is not in $registryPath" }
$base = $all | Where-Object { $_.id -eq $adapter.base_model } | Select-Object -First 1
if ($null -eq $base) { Fail "adapter '$adapterId' names unknown base model '$($adapter.base_model)'" }
if ($adapter.prompt_id -ne $reg.serve.prompt_id) { Fail "adapter '$adapterId' was trained on prompt '$($adapter.prompt_id)', the registry serves '$($reg.serve.prompt_id)'" }

foreach ($e in @($base, $adapter)) {
  if ($e.status -eq "rejected") { Fail "'$($e.id)' is rejected: $($e.status_reason)" }
}
$approved = ($base.status -eq "approved" -and $base.approved_by) -and ($adapter.status -eq "approved" -and $adapter.approved_by)
if (-not $approved) {
  if ($env:TL_ENV -eq "prod") { Fail "'$adapterId' has no clinician approval (approved_by is empty). TL_ENV=prod never serves an unapproved model." }
  if ($env:TL_LLM_ALLOW_UNAPPROVED -ne "1") { Fail "'$adapterId' is '$($adapter.status)' with no clinician approval. Set TL_LLM_ALLOW_UNAPPROVED=1 to serve it outside prod." }
  Write-Warning "serving '$adapterId' ($($adapter.status)) without clinician approval (TL_LLM_ALLOW_UNAPPROVED=1)"
}

function Test-Entry($e) {
  $path = Join-Path $modelsDir $e.file
  if (-not (Test-Path $path)) { Fail "$($e.id): $path not found" }
  $size = (Get-Item $path).Length
  if ($size -ne [int64]$e.size_bytes) { Fail "$($e.id): size $size != registered $($e.size_bytes)" }
  $t = [Diagnostics.Stopwatch]::StartNew()
  $sha = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()
  if ($sha -ne $e.sha256) { Fail "$($e.id): sha256 $sha != registered $($e.sha256)" }
  Write-Host ("verified {0} {1} ({2:N1} s)" -f $e.id, $sha.Substring(0, 12), $t.Elapsed.TotalSeconds)
  return $path
}
$basePath = Test-Entry $base
$adapterPath = Test-Entry $adapter

$llamaArgs = @(
  "-m", $basePath,
  "--lora", $adapterPath,
  "--host", "127.0.0.1",
  "--port", "$port",
  "-c", "$($ctxPerSlot * $parallel)",
  "-np", "$parallel",
  "-ngl", "$ngl",
  "-n", "1024",
  "--alias", "eve",
  "--reasoning", "off",
  "--metrics",
  "--no-webui",
  "--no-slots",
  "--cors-origins", "localhost",
  "--no-cors-credentials",
  "--swa-full"
)
if ($env:TL_LLM_LOG_FILE) { $llamaArgs += @("--log-file", $env:TL_LLM_LOG_FILE) }

# llama-server reads --api-key from LLAMA_API_KEY; keep it off the command line.
$env:LLAMA_API_KEY = $key
Remove-Item Env:TL_LLM_API_KEY
Write-Host "serving $($adapter.id) on $($base.id), prompt $($adapter.prompt_id) $($adapter.prompt_sha256.Substring(0, 12)), http://127.0.0.1:$port, -np $parallel, $ctxPerSlot tokens per slot"
& $server @llamaArgs
exit $LASTEXITCODE
