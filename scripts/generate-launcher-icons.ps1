param(
  [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$ResourceRoot = Join-Path $ProjectRoot "android\app\src\main\res"
$BrandRoot = Join-Path $ProjectRoot "resources\branding"
$Supersample = 4
$AdaptiveForegroundScale = 0.72

$DensitySizes = [ordered]@{
  "mdpi" = @{ Legacy = 48; Foreground = 108 }
  "hdpi" = @{ Legacy = 72; Foreground = 162 }
  "xhdpi" = @{ Legacy = 96; Foreground = 216 }
  "xxhdpi" = @{ Legacy = 144; Foreground = 324 }
  "xxxhdpi" = @{ Legacy = 192; Foreground = 432 }
}

function New-RoundedRectanglePath {
  param(
    [System.Drawing.RectangleF]$Bounds,
    [single]$Radius
  )

  $diameter = $Radius * 2
  $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $path.AddArc($Bounds.Left, $Bounds.Top, $diameter, $diameter, 180, 90)
  $path.AddArc($Bounds.Right - $diameter, $Bounds.Top, $diameter, $diameter, 270, 90)
  $path.AddArc($Bounds.Right - $diameter, $Bounds.Bottom - $diameter, $diameter, $diameter, 0, 90)
  $path.AddArc($Bounds.Left, $Bounds.Bottom - $diameter, $diameter, $diameter, 90, 90)
  $path.CloseFigure()
  return $path
}

function New-ArchiveGradientBrush {
  param([single]$Scale)

  $start = [System.Drawing.PointF]::new(18 * $Scale, 54 * $Scale)
  $end = [System.Drawing.PointF]::new(90 * $Scale, 54 * $Scale)
  $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    $start,
    $end,
    [System.Drawing.ColorTranslator]::FromHtml("#FFC5D3"),
    [System.Drawing.ColorTranslator]::FromHtml("#E5F9E4")
  )
  $blend = [System.Drawing.Drawing2D.ColorBlend]::new(4)
  $blend.Colors = [System.Drawing.Color[]]@(
    [System.Drawing.ColorTranslator]::FromHtml("#FFC5D3"),
    [System.Drawing.ColorTranslator]::FromHtml("#C9A0DC"),
    [System.Drawing.ColorTranslator]::FromHtml("#A2BFFE"),
    [System.Drawing.ColorTranslator]::FromHtml("#E5F9E4")
  )
  $blend.Positions = [single[]]@(0, 0.34, 0.68, 1)
  $brush.InterpolationColors = $blend
  return $brush
}

function Draw-ArchiveMark {
  param(
    [System.Drawing.Graphics]$Graphics,
    [single]$Scale
  )

  $gradient = New-ArchiveGradientBrush -Scale $Scale
  $outerPen = [System.Drawing.Pen]::new($gradient, 7.2 * $Scale)
  $outerPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $outerPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $outerPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $wavePen = [System.Drawing.Pen]::new($gradient, 5.6 * $Scale)
  $wavePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $wavePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $wavePen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

  $outer = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $outer.StartFigure()
  $outer.AddBezier(
    [System.Drawing.PointF]::new(22 * $Scale, 76 * $Scale),
    [System.Drawing.PointF]::new(27 * $Scale, 83 * $Scale),
    [System.Drawing.PointF]::new(32 * $Scale, 83 * $Scale),
    [System.Drawing.PointF]::new(35 * $Scale, 74 * $Scale)
  )
  $outer.AddLine(35 * $Scale, 74 * $Scale, 49.5 * $Scale, 30 * $Scale)
  $outer.AddBezier(
    [System.Drawing.PointF]::new(49.5 * $Scale, 30 * $Scale),
    [System.Drawing.PointF]::new(51.1 * $Scale, 24.5 * $Scale),
    [System.Drawing.PointF]::new(56.9 * $Scale, 24.5 * $Scale),
    [System.Drawing.PointF]::new(58.5 * $Scale, 30 * $Scale)
  )
  $outer.AddLine(58.5 * $Scale, 30 * $Scale, 73 * $Scale, 74 * $Scale)
  $outer.AddBezier(
    [System.Drawing.PointF]::new(73 * $Scale, 74 * $Scale),
    [System.Drawing.PointF]::new(76 * $Scale, 83 * $Scale),
    [System.Drawing.PointF]::new(81 * $Scale, 82 * $Scale),
    [System.Drawing.PointF]::new(84 * $Scale, 76 * $Scale)
  )

  $wave = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $wave.StartFigure()
  $wave.AddBezier(
    [System.Drawing.PointF]::new(39.5 * $Scale, 60.5 * $Scale),
    [System.Drawing.PointF]::new(41.3 * $Scale, 56.4 * $Scale),
    [System.Drawing.PointF]::new(43.8 * $Scale, 56.4 * $Scale),
    [System.Drawing.PointF]::new(46.75 * $Scale, 60.5 * $Scale)
  )
  $wave.AddBezier(
    [System.Drawing.PointF]::new(46.75 * $Scale, 60.5 * $Scale),
    [System.Drawing.PointF]::new(48.55 * $Scale, 64.6 * $Scale),
    [System.Drawing.PointF]::new(51.05 * $Scale, 64.6 * $Scale),
    [System.Drawing.PointF]::new(53.75 * $Scale, 60.5 * $Scale)
  )
  $wave.AddBezier(
    [System.Drawing.PointF]::new(53.75 * $Scale, 60.5 * $Scale),
    [System.Drawing.PointF]::new(55.55 * $Scale, 56.4 * $Scale),
    [System.Drawing.PointF]::new(58.05 * $Scale, 56.4 * $Scale),
    [System.Drawing.PointF]::new(61 * $Scale, 60.5 * $Scale)
  )
  $wave.AddBezier(
    [System.Drawing.PointF]::new(61 * $Scale, 60.5 * $Scale),
    [System.Drawing.PointF]::new(62.8 * $Scale, 64.6 * $Scale),
    [System.Drawing.PointF]::new(65.3 * $Scale, 64.6 * $Scale),
    [System.Drawing.PointF]::new(68.5 * $Scale, 60.5 * $Scale)
  )

  $Graphics.DrawPath($outerPen, $outer)
  $Graphics.DrawPath($wavePen, $wave)

  $green = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml("#E5F9E4"))
  $Graphics.FillEllipse($green, (85.2 - 4.4) * $Scale, (76.5 - 4.4) * $Scale, 8.8 * $Scale, 8.8 * $Scale)

  $green.Dispose()
  $wave.Dispose()
  $outer.Dispose()
  $wavePen.Dispose()
  $outerPen.Dispose()
  $gradient.Dispose()
}

function New-ArchiveBitmap {
  param(
    [int]$Size,
    [ValidateSet("foreground", "rounded", "round")]
    [string]$Variant,
    [string]$TargetPath
  )

  $renderSize = $Size * $Supersample
  $bitmap = [System.Drawing.Bitmap]::new($renderSize, $renderSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.Clear([System.Drawing.Color]::Transparent)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

  if ($Variant -ne "foreground") {
    $charcoal = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml("#1D1D1F"))
    $edgePen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml("#454548"), 1.5 * ($renderSize / 108))
    if ($Variant -eq "round") {
      $graphics.FillEllipse($charcoal, 0, 0, $renderSize - 1, $renderSize - 1)
      $graphics.DrawEllipse($edgePen, 1, 1, $renderSize - 3, $renderSize - 3)
    } else {
      $bounds = [System.Drawing.RectangleF]::new(0, 0, $renderSize - 1, $renderSize - 1)
      $rounded = New-RoundedRectanglePath -Bounds $bounds -Radius (24 * ($renderSize / 108))
      $graphics.FillPath($charcoal, $rounded)
      $graphics.DrawPath($edgePen, $rounded)
      $rounded.Dispose()
    }
    $edgePen.Dispose()
    $charcoal.Dispose()
  }

  Draw-ArchiveMark -Graphics $graphics -Scale ($renderSize / 108)
  $graphics.Dispose()

  if ($Variant -eq "foreground") {
    # Adaptive launchers render the 108dp foreground through a tighter moving mask.
    # Keep the complete mark inside the 66dp universal safe zone so launchers such
    # as Samsung One UI cannot visually zoom or crop the A against the icon edge.
    $paddedBitmap = [System.Drawing.Bitmap]::new($renderSize, $renderSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $paddedGraphics = [System.Drawing.Graphics]::FromImage($paddedBitmap)
    $paddedGraphics.Clear([System.Drawing.Color]::Transparent)
    $paddedGraphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $paddedGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $paddedGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $paddedGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $adaptiveSize = $renderSize * $AdaptiveForegroundScale
    $adaptiveInset = ($renderSize - $adaptiveSize) / 2
    $paddedGraphics.DrawImage($bitmap, $adaptiveInset, $adaptiveInset, $adaptiveSize, $adaptiveSize)
    $paddedGraphics.Dispose()
    $bitmap.Dispose()
    $bitmap = $paddedBitmap
  }

  $final = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $finalGraphics = [System.Drawing.Graphics]::FromImage($final)
  $finalGraphics.Clear([System.Drawing.Color]::Transparent)
  $finalGraphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $finalGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $finalGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $finalGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $finalGraphics.DrawImage($bitmap, 0, 0, $Size, $Size)
  $finalGraphics.Dispose()
  $bitmap.Dispose()

  $targetDirectory = Split-Path -Parent $TargetPath
  New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
  $final.Save($TargetPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $final.Dispose()
}

New-ArchiveBitmap -Size 1024 -Variant "rounded" -TargetPath (Join-Path $BrandRoot "archive-icon-1024.png")
New-ArchiveBitmap -Size 1024 -Variant "foreground" -TargetPath (Join-Path $BrandRoot "archive-icon-foreground-1024.png")

foreach ($density in $DensitySizes.Keys) {
  $directory = Join-Path $ResourceRoot "mipmap-$density"
  $legacySize = $DensitySizes[$density].Legacy
  $foregroundSize = $DensitySizes[$density].Foreground
  New-ArchiveBitmap -Size $legacySize -Variant "rounded" -TargetPath (Join-Path $directory "ic_launcher.png")
  New-ArchiveBitmap -Size $legacySize -Variant "round" -TargetPath (Join-Path $directory "ic_launcher_round.png")
  New-ArchiveBitmap -Size $foregroundSize -Variant "foreground" -TargetPath (Join-Path $directory "ic_launcher_foreground.png")
}

Write-Host "Generated Archive launcher assets from the approved brand geometry."
