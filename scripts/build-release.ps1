param(
  [string]$DriveRoot = "G:\My Drive\Archive Productivity Tracker"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$AndroidRoot = Join-Path $ProjectRoot "android"
$BuiltApk = Join-Path $AndroidRoot "app\build\outputs\apk\release\app-release.apk"
$GeneratedAppBuild = Join-Path $AndroidRoot "app\build"
$ReleasesDocument = Join-Path $ProjectRoot "RELEASES.md"
$Version = (Get-Content -Raw (Join-Path $ProjectRoot "VERSION")).Trim()
$PackageVersion = (Get-Content -Raw (Join-Path $ProjectRoot "package.json") | ConvertFrom-Json).version
$PackageLockText = Get-Content -Raw (Join-Path $ProjectRoot "package-lock.json")
$PackageLockVersions = [regex]::Matches($PackageLockText, '"version"\s*:\s*"([^"]+)"')

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  throw "VERSION must contain a semantic version such as 0.2.0. Found '$Version'."
}

if ($PackageVersion -ne $Version) {
  throw "package.json version '$PackageVersion' does not match VERSION '$Version'."
}

if ($PackageLockVersions.Count -lt 2) {
  throw "package-lock.json does not contain the expected root version references."
}

$PackageLockVersion = $PackageLockVersions[0].Groups[1].Value
$PackageLockRootVersion = $PackageLockVersions[1].Groups[1].Value
if ($PackageLockVersion -ne $Version -or $PackageLockRootVersion -ne $Version) {
  throw "package-lock.json versions '$PackageLockVersion' and '$PackageLockRootVersion' do not both match VERSION '$Version'."
}

$ReleaseName = "Archive-v$Version.apk"
$LocalReleasesRoot = Join-Path $ProjectRoot "releases"
$LocalReleaseDir = Join-Path $LocalReleasesRoot "v$Version"
$LocalReleaseApk = Join-Path $LocalReleaseDir $ReleaseName
$DriveReleasesRoot = Join-Path $DriveRoot "Releases"
$DriveReleaseDir = Join-Path $DriveReleasesRoot "v$Version"
$DriveReleaseApk = Join-Path $DriveReleaseDir $ReleaseName
$StagingId = [guid]::NewGuid().ToString('N')
$LocalStagingDir = Join-Path $LocalReleasesRoot ".staging-archive-v$Version-$StagingId"
$DriveStagingDir = Join-Path $DriveReleasesRoot ".staging-archive-v$Version-$StagingId"
$LocalStagingApk = Join-Path $LocalStagingDir $ReleaseName
$LocalStagingChecksum = "$LocalStagingApk.sha256"
$DriveStagingApk = Join-Path $DriveStagingDir $ReleaseName
$DriveStagingChecksum = "$DriveStagingApk.sha256"
$DriveStagingReleaseNotes = Join-Path $DriveStagingDir "RELEASE_NOTES.md"
$DriveStagingNamedReleaseNotes = Join-Path $DriveStagingDir "Archive-v$Version-release-notes.md"
$ReleaseTag = "v$Version"
$ReleaseTagPushed = $false
$DrivePublishCompleted = $false

foreach ($Path in @($LocalReleaseDir, $DriveReleaseDir)) {
  if (Test-Path -LiteralPath $Path) {
    throw "Refusing to overwrite existing release directory '$Path'. Increase VERSION for a new build."
  }
}

$GitStatus = @(& git -C $ProjectRoot status --porcelain)
if ($LASTEXITCODE -ne 0) {
  throw "Could not read Git status."
}
if ($GitStatus.Count) {
  throw "Refusing to publish from a dirty worktree. Commit and push the release changes first."
}

$Branch = (& git -C $ProjectRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $Branch -ne 'main') {
  throw "Releases must be published from the main branch."
}
& git -C $ProjectRoot fetch --quiet origin $Branch
if ($LASTEXITCODE -ne 0) {
  throw "Could not fetch origin/$Branch. Check GitHub authentication and network access."
}
$Head = (& git -C $ProjectRoot rev-parse HEAD).Trim()
$RemoteHead = (& git -C $ProjectRoot rev-parse "origin/$Branch").Trim()
if ($LASTEXITCODE -ne 0 -or $Head -ne $RemoteHead) {
  throw "Local main must exactly match origin/main before publishing a release."
}
$ExistingRemoteTag = @(& git -C $ProjectRoot ls-remote --tags origin "refs/tags/$ReleaseTag")
if ($LASTEXITCODE -ne 0) {
  throw "Could not inspect remote release tags."
}
if ($ExistingRemoteTag.Count) {
  throw "Remote release tag '$ReleaseTag' already exists. Increase VERSION."
}

Push-Location $ProjectRoot
try {
  npm.cmd run verify
  if ($LASTEXITCODE -ne 0) {
    throw "Archive verification failed with exit code $LASTEXITCODE."
  }

  npx.cmd cap sync android
  if ($LASTEXITCODE -ne 0) {
    throw "Capacitor sync failed with exit code $LASTEXITCODE."
  }

  Push-Location $AndroidRoot
  try {
    .\gradlew.bat --stop
    if ($LASTEXITCODE -ne 0) {
      throw "Gradle daemon shutdown failed with exit code $LASTEXITCODE."
    }

    if (Test-Path -LiteralPath $GeneratedAppBuild) {
      $ResolvedAppBuild = (Resolve-Path -LiteralPath $GeneratedAppBuild).Path
      if ($ResolvedAppBuild -ne $GeneratedAppBuild -or -not $ResolvedAppBuild.StartsWith($AndroidRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clear an unexpected generated Android path: '$ResolvedAppBuild'."
      }
      Get-ChildItem -LiteralPath $ResolvedAppBuild -Recurse -Force | ForEach-Object {
        if ($_.Attributes -band [IO.FileAttributes]::ReadOnly) {
          $_.Attributes = $_.Attributes -bxor [IO.FileAttributes]::ReadOnly
        }
      }
      $AppBuildItem = Get-Item -LiteralPath $ResolvedAppBuild -Force
      if ($AppBuildItem.Attributes -band [IO.FileAttributes]::ReadOnly) {
        $AppBuildItem.Attributes = $AppBuildItem.Attributes -bxor [IO.FileAttributes]::ReadOnly
      }
      Remove-Item -LiteralPath $ResolvedAppBuild -Recurse -Force
    }

    .\gradlew.bat test lint assembleRelease --no-daemon
    if ($LASTEXITCODE -ne 0) {
      throw "The Android build failed with exit code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }

  if (!(Test-Path -LiteralPath $BuiltApk)) {
    throw "Expected APK was not produced at '$BuiltApk'."
  }

  $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $BuiltApk).Hash.ToLowerInvariant()

  $ReleasesText = [IO.File]::ReadAllText($ReleasesDocument)
  $ReleaseHeading = "## $Version "
  $ReleaseSectionStart = $ReleasesText.IndexOf($ReleaseHeading, [StringComparison]::Ordinal)
  if ($ReleaseSectionStart -lt 0) {
    throw "RELEASES.md does not contain a detail section for version '$Version'."
  }
  $NextReleaseSection = $ReleasesText.IndexOf("`n## ", $ReleaseSectionStart + $ReleaseHeading.Length, [StringComparison]::Ordinal)
  $ReleaseSectionLength = if ($NextReleaseSection -lt 0) {
    $ReleasesText.Length - $ReleaseSectionStart
  } else {
    $NextReleaseSection - $ReleaseSectionStart
  }
  $ReleaseSection = $ReleasesText.Substring($ReleaseSectionStart, $ReleaseSectionLength)
  $PendingChecksumLine = '- SHA-256: `PENDING-FINAL-BUILD`'
  $FinalChecksumLine = "- SHA-256: ``$Hash``"

  if ($ReleaseSection.Contains($PendingChecksumLine)) {
    $FinalReleaseSection = $ReleaseSection.Replace($PendingChecksumLine, $FinalChecksumLine)
    $FinalReleasesText = $ReleasesText.Substring(0, $ReleaseSectionStart) +
      $FinalReleaseSection +
      $ReleasesText.Substring($ReleaseSectionStart + $ReleaseSectionLength)
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($ReleasesDocument, $FinalReleasesText, $Utf8NoBom)

    & git -C $ProjectRoot add -- RELEASES.md
    if ($LASTEXITCODE -ne 0) {
      throw "Could not stage the finalized release checksum."
    }
    & git -C $ProjectRoot commit -m "Finalize Archive v$Version checksum"
    if ($LASTEXITCODE -ne 0) {
      throw "Could not commit the finalized release checksum."
    }
    & git -C $ProjectRoot push origin main
    if ($LASTEXITCODE -ne 0) {
      throw "Could not push the finalized release checksum to origin/main."
    }
  } else {
    $RecordedHashMatch = [regex]::Match($ReleaseSection, '- SHA-256: `([0-9a-fA-F]{64})`')
    if (!$RecordedHashMatch.Success -or $RecordedHashMatch.Groups[1].Value.ToLowerInvariant() -ne $Hash) {
      throw "The recorded v$Version checksum does not match the final APK and is not pending."
    }
  }

  New-Item -ItemType Directory -Path $LocalReleasesRoot -Force | Out-Null
  New-Item -ItemType Directory -Path $DriveReleasesRoot -Force | Out-Null
  New-Item -ItemType Directory -Path $LocalStagingDir | Out-Null
  New-Item -ItemType Directory -Path $DriveStagingDir | Out-Null

  Copy-Item -LiteralPath $BuiltApk -Destination $LocalStagingApk
  Copy-Item -LiteralPath $BuiltApk -Destination $DriveStagingApk
  "$Hash  $ReleaseName" | Set-Content -Encoding ascii -NoNewline -LiteralPath $LocalStagingChecksum
  "$Hash  $ReleaseName" | Set-Content -Encoding ascii -NoNewline -LiteralPath $DriveStagingChecksum
  Copy-Item -LiteralPath (Join-Path $ProjectRoot "CHANGELOG.md") -Destination $DriveStagingReleaseNotes
  Copy-Item -LiteralPath (Join-Path $ProjectRoot "CHANGELOG.md") -Destination $DriveStagingNamedReleaseNotes

  $LocalStagedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $LocalStagingApk).Hash.ToLowerInvariant()
  $DriveStagedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $DriveStagingApk).Hash.ToLowerInvariant()
  if ($LocalStagedHash -ne $Hash -or $DriveStagedHash -ne $Hash) {
    throw "A staged release APK checksum does not match the built APK."
  }

  # The unique annotated tag object is the shared cross-computer release claim.
  # A competing publisher receives a non-fast-forward tag rejection.
  & git -C $ProjectRoot tag -a $ReleaseTag -m "Archive $ReleaseTag release claim $StagingId"
  if ($LASTEXITCODE -ne 0) {
    throw "Could not create local release tag '$ReleaseTag'."
  }
  & git -C $ProjectRoot push origin "refs/tags/${ReleaseTag}:refs/tags/${ReleaseTag}"
  if ($LASTEXITCODE -ne 0) {
    & git -C $ProjectRoot tag -d $ReleaseTag | Out-Null
    throw "Could not claim remote release tag '$ReleaseTag'; another computer may have published it."
  }
  $ReleaseTagPushed = $true

  # Each move prevents a partial final folder on its own volume. Neither move
  # merges or overwrites; the Git tag above provides distributed uniqueness.
  [IO.Directory]::Move($DriveStagingDir, $DriveReleaseDir)
  $DrivePublishCompleted = $true
  [IO.Directory]::Move($LocalStagingDir, $LocalReleaseDir)

  Copy-Item -LiteralPath (Join-Path $ProjectRoot "CHANGELOG.md") -Destination (Join-Path $DriveRoot "CHANGELOG.md") -Force
  Copy-Item -LiteralPath $ReleasesDocument -Destination (Join-Path $DriveRoot "RELEASES.md") -Force

  Write-Host ""
  Write-Host "Archive v$Version created successfully." -ForegroundColor Green
  Write-Host "Local: $LocalReleaseApk"
  Write-Host "Drive: $DriveReleaseApk"
  Write-Host "SHA-256: $Hash"
} finally {
  if ($ReleaseTagPushed -and !$DrivePublishCompleted) {
    Write-Warning "Remote tag '$ReleaseTag' reserved this version, but Drive publication did not finish. Inspect the tag and staging error before retrying; do not overwrite or delete release files blindly."
  }
  foreach ($StagingDir in @($LocalStagingDir, $DriveStagingDir)) {
    if (Test-Path -LiteralPath $StagingDir) {
      $ResolvedStagingDir = (Resolve-Path -LiteralPath $StagingDir).Path
      $ExpectedRoot = if ($StagingDir -eq $LocalStagingDir) { $LocalReleasesRoot } else { $DriveReleasesRoot }
      $ResolvedExpectedRoot = [IO.Path]::GetFullPath($ExpectedRoot)
      if (!$ResolvedStagingDir.StartsWith($ResolvedExpectedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
          !(Split-Path -Leaf $ResolvedStagingDir).StartsWith('.staging-archive-')) {
        throw "Refusing to clean an unexpected staging path '$ResolvedStagingDir'."
      }
      Remove-Item -LiteralPath $ResolvedStagingDir -Recurse -Force
    }
  }
  Pop-Location
}
