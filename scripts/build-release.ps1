param(
  [string]$DriveRoot = "G:\My Drive\Archive Productivity Tracker"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AndroidRoot = Join-Path $ProjectRoot "android"
$BuiltApk = Join-Path $AndroidRoot "app\build\outputs\apk\debug\app-debug.apk"
$Version = (Get-Content -Raw (Join-Path $ProjectRoot "VERSION")).Trim()
$PackageVersion = (Get-Content -Raw (Join-Path $ProjectRoot "package.json") | ConvertFrom-Json).version

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  throw "VERSION must contain a semantic version such as 0.2.0. Found '$Version'."
}

if ($PackageVersion -ne $Version) {
  throw "package.json version '$PackageVersion' does not match VERSION '$Version'."
}

$ReleaseName = "Archive-v$Version.apk"
$LocalReleaseDir = Join-Path $ProjectRoot "releases\v$Version"
$LocalReleaseApk = Join-Path $LocalReleaseDir $ReleaseName
$LocalChecksum = "$LocalReleaseApk.sha256"
$DriveReleaseDir = Join-Path $DriveRoot "Releases\v$Version"
$DriveReleaseApk = Join-Path $DriveReleaseDir $ReleaseName
$DriveChecksum = "$DriveReleaseApk.sha256"
$DriveReleaseNotes = Join-Path $DriveReleaseDir "Archive-v$Version-release-notes.md"

foreach ($Path in @($LocalReleaseApk, $LocalChecksum, $DriveReleaseApk, $DriveChecksum, $DriveReleaseNotes)) {
  if (Test-Path -LiteralPath $Path) {
    throw "Refusing to overwrite existing release artifact '$Path'. Increase VERSION for a new build."
  }
}

Push-Location $ProjectRoot
try {
  npm.cmd run build
  if ($LASTEXITCODE -ne 0) {
    throw "The web build failed with exit code $LASTEXITCODE."
  }

  npx.cmd cap sync android
  if ($LASTEXITCODE -ne 0) {
    throw "Capacitor sync failed with exit code $LASTEXITCODE."
  }

  Push-Location $AndroidRoot
  try {
    .\gradlew.bat assembleDebug
    if ($LASTEXITCODE -ne 0) {
      throw "The Android build failed with exit code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }

  if (!(Test-Path -LiteralPath $BuiltApk)) {
    throw "Expected APK was not produced at '$BuiltApk'."
  }

  New-Item -ItemType Directory -Path $LocalReleaseDir -Force | Out-Null
  New-Item -ItemType Directory -Path $DriveReleaseDir -Force | Out-Null

  Copy-Item -LiteralPath $BuiltApk -Destination $LocalReleaseApk
  Copy-Item -LiteralPath $BuiltApk -Destination $DriveReleaseApk

  $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $LocalReleaseApk).Hash.ToLowerInvariant()
  "$Hash  $ReleaseName" | Set-Content -Encoding ascii -NoNewline -LiteralPath $LocalChecksum
  "$Hash  $ReleaseName" | Set-Content -Encoding ascii -NoNewline -LiteralPath $DriveChecksum
  Copy-Item -LiteralPath (Join-Path $ProjectRoot "CHANGELOG.md") -Destination $DriveReleaseNotes

  Copy-Item -LiteralPath (Join-Path $ProjectRoot "CHANGELOG.md") -Destination (Join-Path $DriveRoot "CHANGELOG.md") -Force
  Copy-Item -LiteralPath (Join-Path $ProjectRoot "RELEASES.md") -Destination (Join-Path $DriveRoot "RELEASES.md") -Force

  $DriveHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $DriveReleaseApk).Hash.ToLowerInvariant()
  if ($DriveHash -ne $Hash) {
    throw "The Google Drive APK checksum does not match the local release."
  }

  Write-Host ""
  Write-Host "Archive v$Version created successfully." -ForegroundColor Green
  Write-Host "Local: $LocalReleaseApk"
  Write-Host "Drive: $DriveReleaseApk"
  Write-Host "SHA-256: $Hash"
} finally {
  Pop-Location
}
