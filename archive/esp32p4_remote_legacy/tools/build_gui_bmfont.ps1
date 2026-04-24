[CmdletBinding()]
param(
    [string]$CharsetDir = "docs/gui_charset",
    [string]$OutputDir = "docs/gui_bmfont/package/gui-ui",
    [int[]]$SizesPx = @(16, 20, 28),
    [string[]]$Locales = @("zh-CN", "ja-JP")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$canvasBase = 64
$fontChains = @{
    "zh-CN" = @("Noto Sans SC", "Microsoft YaHei UI", "SimHei", "Segoe UI Symbol", "Segoe UI Emoji")
    "ja-JP" = @("Noto Sans JP", "Meiryo", "Yu Gothic UI", "MS Gothic", "Segoe UI Symbol", "Segoe UI Emoji")
}
$specialFontOverrides = @{
    0x1F3E0 = "Segoe UI Emoji"
    0x1F512 = "Segoe UI Emoji"
}
$fontCache = @{}
$rendererCache = @{}
$installedFamilies = New-Object "System.Collections.Generic.HashSet[string]" ([System.StringComparer]::OrdinalIgnoreCase)
(New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object {
    [void]$installedFamilies.Add($_.Name)
}

function Get-RelativeUnixPath {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    $baseUri = [System.Uri]::new((Resolve-Path $BasePath).Path.TrimEnd("\") + "\")
    $targetUri = [System.Uri]::new((Resolve-Path $TargetPath).Path)
    return $baseUri.MakeRelativeUri($targetUri).ToString()
}

function Read-CodepointsBin {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $Path))
    if ($bytes.Length -lt 12) {
        throw "Invalid charset binary: too short: $Path"
    }

    $magic = [System.Text.Encoding]::ASCII.GetString($bytes, 0, 4)
    if ($magic -ne "UCS4") {
        throw "Invalid charset binary magic in ${Path}: $magic"
    }

    $count = [System.BitConverter]::ToUInt32($bytes, 8)
    $expectedLength = 12 + ($count * 4)
    if ($bytes.Length -ne $expectedLength) {
        throw "Invalid charset binary length in ${Path}: expected $expectedLength, got $($bytes.Length)"
    }

    $codepoints = New-Object "System.Collections.Generic.List[uint32]"
    for ($index = 0; $index -lt $count; $index++) {
        $offset = 12 + ($index * 4)
        [void]$codepoints.Add([System.BitConverter]::ToUInt32($bytes, $offset))
    }

    return $codepoints
}

function Get-Font {
    param(
        [string]$FamilyName,
        [int]$SizePx
    )

    $key = "$FamilyName|$SizePx"
    if (-not $script:fontCache.ContainsKey($key)) {
        if (-not $script:installedFamilies.Contains($FamilyName)) {
            throw "Font family not installed: $FamilyName"
        }

        $script:fontCache[$key] = [System.Drawing.Font]::new(
            $FamilyName,
            [float]$SizePx,
            [System.Drawing.FontStyle]::Regular,
            [System.Drawing.GraphicsUnit]::Pixel
        )
    }

    return $script:fontCache[$key]
}

function Get-Renderer {
    param(
        [string]$FamilyName,
        [int]$SizePx
    )

    $key = "$FamilyName|$SizePx"
    if (-not $script:rendererCache.ContainsKey($key)) {
        $canvasSize = [Math]::Max($script:canvasBase, $SizePx * 4)
        $pad = [Math]::Max(4, [Math]::Ceiling($SizePx / 2.0))
        $bitmap = [System.Drawing.Bitmap]::new(
            $canvasSize,
            $canvasSize,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
        $format = [System.Drawing.StringFormat]::GenericTypographic
        $format.FormatFlags = $format.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces

        $script:rendererCache[$key] = [pscustomobject]@{
            FamilyName = $FamilyName
            SizePx = $SizePx
            Pad = $pad
            CanvasSize = $canvasSize
            Bitmap = $bitmap
            Graphics = $graphics
            Brush = $brush
            Format = $format
        }
    }

    return $script:rendererCache[$key]
}

function Get-FontMetrics {
    param(
        [string]$FamilyName,
        [int]$SizePx
    )

    $renderer = Get-Renderer -FamilyName $FamilyName -SizePx $SizePx
    $font = Get-Font -FamilyName $FamilyName -SizePx $SizePx
    $family = $font.FontFamily
    $emHeight = $family.GetEmHeight($font.Style)
    $ascender = [Math]::Ceiling($SizePx * $family.GetCellAscent($font.Style) / $emHeight)
    $descender = [Math]::Ceiling($SizePx * $family.GetCellDescent($font.Style) / $emHeight)
    $lineHeight = [Math]::Ceiling($font.GetHeight($renderer.Graphics))

    return [pscustomobject]@{
        LineHeightPx = [int]$lineHeight
        AscenderPx = [int]$ascender
        DescenderPx = [int]$descender
    }
}

function Get-AlphaBoundsAndData {
    param([System.Drawing.Bitmap]$Bitmap)

    $rect = [System.Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
    $lock = $Bitmap.LockBits(
        $rect,
        [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )

    try {
        $buffer = New-Object byte[] ($lock.Stride * $lock.Height)
        [System.Runtime.InteropServices.Marshal]::Copy($lock.Scan0, $buffer, 0, $buffer.Length)

        $minX = $Bitmap.Width
        $minY = $Bitmap.Height
        $maxX = -1
        $maxY = -1

        for ($y = 0; $y -lt $Bitmap.Height; $y++) {
            $rowBase = $y * $lock.Stride
            for ($x = 0; $x -lt $Bitmap.Width; $x++) {
                $alpha = $buffer[$rowBase + ($x * 4) + 3]
                if ($alpha -gt 0) {
                    if ($x -lt $minX) { $minX = $x }
                    if ($y -lt $minY) { $minY = $y }
                    if ($x -gt $maxX) { $maxX = $x }
                    if ($y -gt $maxY) { $maxY = $y }
                }
            }
        }

        return [pscustomobject]@{
            Pixels = $buffer
            Stride = $lock.Stride
            MinX = $minX
            MinY = $minY
            MaxX = $maxX
            MaxY = $maxY
        }
    }
    finally {
        $Bitmap.UnlockBits($lock)
    }
}

function Get-GlyphBitmapA8 {
    param(
        [byte[]]$Pixels,
        [int]$Stride,
        [int]$MinX,
        [int]$MinY,
        [int]$Width,
        [int]$Height
    )

    $output = New-Object byte[] ($Width * $Height)
    for ($y = 0; $y -lt $Height; $y++) {
        $srcRowBase = (($MinY + $y) * $Stride) + ($MinX * 4)
        $dstRowBase = $y * $Width
        for ($x = 0; $x -lt $Width; $x++) {
            $output[$dstRowBase + $x] = $Pixels[$srcRowBase + ($x * 4) + 3]
        }
    }

    return $output
}

function Get-CodepointText {
    param([uint32]$Codepoint)

    return [System.Char]::ConvertFromUtf32([int]$Codepoint)
}

function Get-FontCandidates {
    param(
        [string]$Locale,
        [uint32]$Codepoint
    )

    $candidates = New-Object "System.Collections.Generic.List[string]"
    if ($script:specialFontOverrides.ContainsKey([int]$Codepoint)) {
        [void]$candidates.Add($script:specialFontOverrides[[int]$Codepoint])
    }

    foreach ($familyName in $script:fontChains[$Locale]) {
        if (-not $candidates.Contains($familyName)) {
            [void]$candidates.Add($familyName)
        }
    }

    return $candidates
}

function Render-GlyphWithFamily {
    param(
        [string]$FamilyName,
        [int]$SizePx,
        [uint32]$Codepoint
    )

    $renderer = Get-Renderer -FamilyName $FamilyName -SizePx $SizePx
    $font = Get-Font -FamilyName $FamilyName -SizePx $SizePx
    $text = Get-CodepointText -Codepoint $Codepoint

    $renderer.Graphics.Clear([System.Drawing.Color]::Transparent)
    $renderer.Graphics.DrawString(
        $text,
        $font,
        $renderer.Brush,
        [float]$renderer.Pad,
        [float]$renderer.Pad,
        $renderer.Format
    )

    $advance = [Math]::Ceiling(($renderer.Graphics.MeasureString($text, $font, 0, $renderer.Format)).Width)
    if ($advance -lt 0) {
        $advance = 0
    }

    $alphaData = Get-AlphaBoundsAndData -Bitmap $renderer.Bitmap
    $hasInk = $alphaData.MaxX -ge 0

    if (-not $hasInk) {
        return [pscustomobject]@{
            FamilyName = $FamilyName
            HasInk = $false
            Width = 0
            Height = 0
            XOffset = 0
            YOffset = 0
            AdvanceX = [int]$advance
            Bitmap = [byte[]]::new(0)
        }
    }

    $width = ($alphaData.MaxX - $alphaData.MinX) + 1
    $height = ($alphaData.MaxY - $alphaData.MinY) + 1
    $glyphBitmap = Get-GlyphBitmapA8 `
        -Pixels $alphaData.Pixels `
        -Stride $alphaData.Stride `
        -MinX $alphaData.MinX `
        -MinY $alphaData.MinY `
        -Width $width `
        -Height $height

    return [pscustomobject]@{
        FamilyName = $FamilyName
        HasInk = $true
        Width = [int]$width
        Height = [int]$height
        XOffset = [int]($alphaData.MinX - $renderer.Pad)
        YOffset = [int]($alphaData.MinY - $renderer.Pad)
        AdvanceX = [int]$advance
        Bitmap = [byte[]]$glyphBitmap
    }
}

function Render-Glyph {
    param(
        [string]$Locale,
        [int]$SizePx,
        [uint32]$Codepoint
    )

    $text = Get-CodepointText -Codepoint $Codepoint
    $isWhitespace = [string]::IsNullOrWhiteSpace($text)
    $candidates = Get-FontCandidates -Locale $Locale -Codepoint $Codepoint
    $lastResult = $null

    foreach ($familyName in $candidates) {
        $lastResult = Render-GlyphWithFamily -FamilyName $familyName -SizePx $SizePx -Codepoint $Codepoint
        if ($lastResult.HasInk -or $isWhitespace) {
            return $lastResult
        }
    }

    return $lastResult
}

function Write-VariantPackage {
    param(
        [string]$Locale,
        [int]$SizePx,
        [System.Collections.Generic.List[uint32]]$Codepoints,
        [string]$VariantDir
    )

    [void][System.IO.Directory]::CreateDirectory($VariantDir)

    $primaryFamily = $script:fontChains[$Locale][0]
    $metrics = Get-FontMetrics -FamilyName $primaryFamily -SizePx $SizePx
    $glyphStream = [System.IO.MemoryStream]::new()
    $glyphWriter = [System.IO.BinaryWriter]::new($glyphStream)
    $entries = New-Object System.Collections.Generic.List[object]
    $missingCodepoints = New-Object "System.Collections.Generic.List[string]"
    $familyUsage = @{}

    foreach ($codepoint in $Codepoints) {
        $glyph = Render-Glyph -Locale $Locale -SizePx $SizePx -Codepoint $codepoint
        if ($null -eq $glyph) {
            throw "Failed to render codepoint U+$('{0:X4}' -f [int]$codepoint) for $Locale $SizePx"
        }

        if (-not $familyUsage.ContainsKey($glyph.FamilyName)) {
            $familyUsage[$glyph.FamilyName] = 0
        }
        $familyUsage[$glyph.FamilyName]++

        if ((-not $glyph.HasInk) -and ($codepoint -ne 0x20)) {
            [void]$missingCodepoints.Add(("U+{0:X4}" -f [int]$codepoint))
        }

        $offset = [int]$glyphStream.Position
        $glyphBytesForEntry = [byte[]]$glyph.Bitmap
        $glyphWriter.Write($glyphBytesForEntry)
        $bitmapSize = $glyphBytesForEntry.Length

        [void]$entries.Add([pscustomobject]@{
            Codepoint = [uint32]$codepoint
            Offset = [uint32]$offset
            BitmapSize = [uint32]$bitmapSize
            Width = [uint16]$glyph.Width
            Height = [uint16]$glyph.Height
            XOffset = [int16]$glyph.XOffset
            YOffset = [int16]$glyph.YOffset
            AdvanceX = [uint16]$glyph.AdvanceX
        })
    }

    $glyphWriter.Flush()
    $glyphBytes = $glyphStream.ToArray()
    $glyphWriter.Dispose()
    $glyphStream.Dispose()

    $glyphPath = Join-Path $VariantDir "glyph.bin"
    $glyphFile = [System.IO.File]::Open($glyphPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
        $writer = [System.IO.BinaryWriter]::new($glyphFile)
        try {
            $writer.Write([System.Text.Encoding]::ASCII.GetBytes("BMFG"))
            $writer.Write([uint16]1)
            $writer.Write([uint16]1)
            $writer.Write([uint32]$glyphBytes.Length)
            $writer.Write([uint32]0)
            $writer.Write($glyphBytes)
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $glyphFile.Dispose()
    }

    $indexPath = Join-Path $VariantDir "index.bin"
    $indexFile = [System.IO.File]::Open($indexPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    try {
        $writer = [System.IO.BinaryWriter]::new($indexFile)
        try {
            $writer.Write([System.Text.Encoding]::ASCII.GetBytes("BMFI"))
            $writer.Write([uint16]1)
            $writer.Write([uint16]0)
            $writer.Write([uint32]$entries.Count)
            $writer.Write([uint16]$SizePx)
            $writer.Write([uint16]$metrics.LineHeightPx)
            $writer.Write([int16]$metrics.AscenderPx)
            $writer.Write([int16]$metrics.DescenderPx)
            $writer.Write([uint32]0)

            foreach ($entry in $entries) {
                $writer.Write([uint32]$entry.Codepoint)
                $writer.Write([uint32]$entry.Offset)
                $writer.Write([uint32]$entry.BitmapSize)
                $writer.Write([uint16]$entry.Width)
                $writer.Write([uint16]$entry.Height)
                $writer.Write([int16]$entry.XOffset)
                $writer.Write([int16]$entry.YOffset)
                $writer.Write([uint16]$entry.AdvanceX)
                $writer.Write([uint16]0)
            }
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $indexFile.Dispose()
    }

    $familyUsageOrdered = [ordered]@{}
    foreach ($name in ($familyUsage.Keys | Sort-Object)) {
        $familyUsageOrdered[$name] = $familyUsage[$name]
    }

    return [ordered]@{
        font_size_px = $SizePx
        line_height_px = $metrics.LineHeightPx
        ascender_px = $metrics.AscenderPx
        descender_px = $metrics.DescenderPx
        glyph_count = $entries.Count
        glyph_data_bytes = $glyphBytes.Length
        index_file = "index.bin"
        glyph_file = "glyph.bin"
        family_usage = $familyUsageOrdered
        missing_codepoints = @($missingCodepoints)
    }
}

[void][System.IO.Directory]::CreateDirectory($OutputDir)

$manifest = [ordered]@{
    package_name = "gui-ui-bmfont"
    format_version = 1
    generated_at = (Get-Date).ToString("s")
    pixel_format = "A8"
    charset_dir = (Resolve-Path $CharsetDir).Path
    output_dir = (Resolve-Path $OutputDir).Path
    default_sizes_px = $SizesPx
    locales = [ordered]@{}
}

foreach ($locale in $Locales) {
    if (-not $fontChains.ContainsKey($locale)) {
        throw "No font chain configured for locale: $locale"
    }

    $charsetPath = Join-Path $CharsetDir "$locale.codepoints.bin"
    if (-not (Test-Path $charsetPath)) {
        throw "Missing charset binary: $charsetPath"
    }

    $codepoints = Read-CodepointsBin -Path $charsetPath
    $localeDir = Join-Path $OutputDir $locale
    [void][System.IO.Directory]::CreateDirectory($localeDir)

    $localeManifest = [ordered]@{
        codepoint_source = Get-RelativeUnixPath -BasePath $OutputDir -TargetPath $charsetPath
        font_chain = $fontChains[$locale]
        sizes = [ordered]@{}
    }

    foreach ($sizePx in $SizesPx) {
        $variantDir = Join-Path $localeDir "$sizePx"
        $variantManifest = Write-VariantPackage `
            -Locale $locale `
            -SizePx $sizePx `
            -Codepoints $codepoints `
            -VariantDir $variantDir

        $localeManifest.sizes["$sizePx"] = $variantManifest
    }

    $manifest.locales[$locale] = $localeManifest
}

$manifestPath = Join-Path $OutputDir "manifest.json"
[System.IO.File]::WriteAllText(
    $manifestPath,
    (($manifest | ConvertTo-Json -Depth 8) + [Environment]::NewLine),
    $utf8NoBom
)

foreach ($renderer in $rendererCache.Values) {
    $renderer.Format.Dispose()
    $renderer.Brush.Dispose()
    $renderer.Graphics.Dispose()
    $renderer.Bitmap.Dispose()
}

foreach ($font in $fontCache.Values) {
    $font.Dispose()
}
