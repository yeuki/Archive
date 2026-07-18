param(
  [switch]$SkipBuild,
  [switch]$NoLaunch,
  [string]$AdbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$AndroidRoot = Join-Path $ProjectRoot "android"
$ApkPath = Join-Path $AndroidRoot "app\build\outputs\apk\release\app-release.apk"
$AppId = "com.kyle.archive"

function Invoke-Step {
  param(
    [string]$Message,
    [scriptblock]$Action
  )

  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
  & $Action
}

if (!(Test-Path -LiteralPath $AdbPath)) {
  $ResolvedAdb = Get-Command adb -ErrorAction SilentlyContinue
  if ($ResolvedAdb) {
    $AdbPath = $ResolvedAdb.Source
  } else {
    throw "ADB was not found. Expected it at '$AdbPath'. Install Android platform-tools or pass -AdbPath."
  }
}

Push-Location $ProjectRoot
try {
  if (!$SkipBuild) {
    Invoke-Step "Building web assets" {
      npm.cmd run build
      if ($LASTEXITCODE -ne 0) {
        throw "The web build failed with exit code $LASTEXITCODE."
      }
    }

    Invoke-Step "Syncing Capacitor Android project" {
      npx.cmd cap sync android
      if ($LASTEXITCODE -ne 0) {
        throw "Capacitor sync failed with exit code $LASTEXITCODE."
      }
    }

    Invoke-Step "Building certificate-verified Android release APK" {
      Push-Location $AndroidRoot
      try {
        .\gradlew.bat assembleRelease
        if ($LASTEXITCODE -ne 0) {
          throw "The certificate-verified release build failed with exit code $LASTEXITCODE."
        }
      } finally {
        Pop-Location
      }
    }
  }

  if (!(Test-Path -LiteralPath $ApkPath)) {
    throw "APK not found at '$ApkPath'. Run without -SkipBuild first."
  }

  Invoke-Step "Checking connected phone" {
    & $AdbPath start-server | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "ADB server startup failed with exit code $LASTEXITCODE."
    }
    $Devices = & $AdbPath devices
    if ($LASTEXITCODE -ne 0) {
      throw "ADB device discovery failed with exit code $LASTEXITCODE."
    }
    $ReadyDevices = @($Devices | Where-Object { $_ -match "\tdevice$" })
    $UnauthorizedDevices = @($Devices | Where-Object { $_ -match "\tunauthorized$" })

    if ($UnauthorizedDevices.Count) {
      throw "Phone is connected but unauthorized. Unlock it and accept the USB debugging prompt, then rerun this script."
    }

    if (!$ReadyDevices.Count) {
      throw "No authorized Android device found. Connect your phone, enable USB debugging, and run 'adb devices'."
    }

    $ReadyDevices | ForEach-Object { Write-Host $_ }
  }

  Invoke-Step "Installing Archive on phone" {
    & $AdbPath install -r $ApkPath
    if ($LASTEXITCODE -ne 0) {
      throw "ADB install failed with exit code $LASTEXITCODE."
    }
  }

  if (!$NoLaunch) {
    Invoke-Step "Launching Archive" {
      & $AdbPath shell monkey -p $AppId -c android.intent.category.LAUNCHER 1 | Out-Null
      if ($LASTEXITCODE -ne 0) {
        throw "Archive launch failed with exit code $LASTEXITCODE."
      }
    }
  }

  Write-Host ""
  Write-Host "Archive deployed successfully." -ForegroundColor Green
} finally {
  Pop-Location
}
