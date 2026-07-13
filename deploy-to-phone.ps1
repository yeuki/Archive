param(
  [switch]$SkipBuild,
  [switch]$SkipDriveCopy,
  [switch]$NoLaunch,
  [string]$AdbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$AndroidRoot = Join-Path $ProjectRoot "android"
$ApkPath = Join-Path $AndroidRoot "app\build\outputs\apk\debug\app-debug.apk"
$Version = (Get-Content -Raw (Join-Path $ProjectRoot "VERSION")).Trim()
$ReleaseFileName = "Archive-v$Version.apk"
$DriveApkPath = "G:\My Drive\Archive Productivity Tracker\Releases\v$Version\$ReleaseFileName"
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
    }

    Invoke-Step "Syncing Capacitor Android project" {
      npx.cmd cap sync android
    }

    Invoke-Step "Building Android debug APK" {
      Push-Location $AndroidRoot
      try {
        .\gradlew.bat assembleDebug
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
    $Devices = & $AdbPath devices
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
  }

  if (!$SkipDriveCopy) {
    Invoke-Step "Archiving versioned Google Drive APK" {
      $DriveDir = Split-Path -Parent $DriveApkPath
      if (!(Test-Path -LiteralPath $DriveDir)) {
        New-Item -ItemType Directory -Path $DriveDir | Out-Null
      }

      if (Test-Path -LiteralPath $DriveApkPath) {
        $SourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ApkPath).Hash
        $DriveHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $DriveApkPath).Hash
        if ($SourceHash -ne $DriveHash) {
          throw "Release '$ReleaseFileName' already exists with different contents. Increase VERSION before archiving another major build."
        }
        Write-Host "The matching versioned Drive APK is already archived; leaving it unchanged."
      } else {
        Copy-Item -LiteralPath $ApkPath -Destination $DriveApkPath
      }
      Get-Item -LiteralPath $DriveApkPath | Select-Object FullName, Length, LastWriteTime
    }
  }

  if (!$NoLaunch) {
    Invoke-Step "Launching Archive" {
      & $AdbPath shell monkey -p $AppId -c android.intent.category.LAUNCHER 1 | Out-Null
    }
  }

  Write-Host ""
  Write-Host "Archive deployed successfully." -ForegroundColor Green
} finally {
  Pop-Location
}
