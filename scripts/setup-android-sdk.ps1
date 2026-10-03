# Headless Android toolchain for Flutter on Windows: Temurin JDK 17 + Android command-line tools +
# platform/build tools. No Android Studio. Idempotent; re-run to add packages.
#
#   powershell -ExecutionPolicy Bypass -File scripts\setup-android-sdk.ps1 -Root D:\dev
#
param(
  [string]$Root = "D:\dev",
  [string]$Platform = "android-36",
  [string]$BuildTools = "36.0.0",
  [string]$Ndk = "",
  [string]$Flutter = "D:\dev\flutter\bin\flutter.bat"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$jdk = Join-Path $Root "jdk-17"
$sdk = Join-Path $Root "android-sdk"
$tmp = Join-Path $Root "_downloads"
New-Item -ItemType Directory -Force $Root, $sdk, $tmp | Out-Null

$downloader = Join-Path $PSScriptRoot "download.py"
function Get-File($url, $dest) {
  if (Test-Path $dest) { Write-Host "have $dest"; return }
  Write-Host "downloading $url"
  & python $downloader $url $dest
  if ($LASTEXITCODE -ne 0) { throw "download failed for $url" }
}

# --- JDK 17 (Temurin) ---
if (-not (Test-Path (Join-Path $jdk "bin\java.exe"))) {
  $zip = Join-Path $tmp "openjdk17.zip"
  # Microsoft Build of OpenJDK 17 (Adoptium's API fails the TLS handshake on some networks).
  Get-File "https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip" $zip
  Expand-Archive $zip -DestinationPath $tmp -Force
  $extracted = Get-ChildItem $tmp -Directory | Where-Object { $_.Name -like "jdk-17*" } | Select-Object -First 1
  Move-Item $extracted.FullName $jdk
}
$env:JAVA_HOME = $jdk
$env:Path = "$jdk\bin;$env:Path"
& "$jdk\bin\java.exe" -version

# --- command-line tools ---
$cmdline = Join-Path $sdk "cmdline-tools\latest"
if (-not (Test-Path (Join-Path $cmdline "bin\sdkmanager.bat"))) {
  $zip = Join-Path $tmp "cmdline-tools.zip"
  Get-File "https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip" $zip
  Expand-Archive $zip -DestinationPath $tmp -Force
  New-Item -ItemType Directory -Force (Split-Path $cmdline) | Out-Null
  if (Test-Path $cmdline) { Remove-Item $cmdline -Recurse -Force }
  Move-Item (Join-Path $tmp "cmdline-tools") $cmdline
}
$env:ANDROID_HOME = $sdk
$sdkmanager = Join-Path $cmdline "bin\sdkmanager.bat"

# --- licenses (written directly; piping "y" into sdkmanager.bat is unreliable from PowerShell) ---
$licenses = Join-Path $sdk "licenses"
New-Item -ItemType Directory -Force $licenses | Out-Null
Set-Content -Path (Join-Path $licenses "android-sdk-license") -Encoding ascii -Value @(
  "8933bad161af4178b1185d1a37fbf41ea5269c55",
  "d56f5187479451eabf01fb78af6dfcb131a6481e",
  "24333f8a63b6825ea9c5514f83c2829b004d1fee"
)
Set-Content -Path (Join-Path $licenses "android-sdk-preview-license") -Encoding ascii -Value "84831b9409646a918e30573bab4c9c91346d8abd"

# --- packages ---
$packages = @("platform-tools", "platforms;$Platform", "build-tools;$BuildTools")
if ($Ndk) { $packages += "ndk;$Ndk" }
& $sdkmanager --sdk_root=$sdk $packages
if ($LASTEXITCODE -ne 0) { throw "sdkmanager failed ($LASTEXITCODE)" }

# --- persist for future shells ---
[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdk, "User")
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdk, "User")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
foreach ($p in @("$jdk\bin", "$sdk\platform-tools")) {
  if ($userPath -notlike "*$p*") { $userPath = "$p;$userPath" }
}
[Environment]::SetEnvironmentVariable("Path", $userPath, "User")

if (Test-Path $Flutter) {
  & $Flutter config --android-sdk $sdk
  & $Flutter config --jdk-dir $jdk
  $yes | & $Flutter doctor --android-licenses | Out-Null
  & $Flutter doctor
}
Write-Host "`nAndroid SDK: $sdk`nJDK: $jdk`nOpen a new terminal for the environment variables to apply."
