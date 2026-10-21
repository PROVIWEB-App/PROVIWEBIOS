# generate-appicon.ps1 — genera los PNG de AppIcon.appiconset a partir del
# logo de Android (ic_launcher_foreground.png) compuesto sobre fondo blanco.
# Sin alpha en los PNG (requisito de validacion del App Store).
param(
    [string]$Source = "C:\Users\viweb\Desktop\PROYECTO\PROVIWEB-master\PROVIWEB-master\app\src\main\res\mipmap-xxxhdpi\ic_launcher_foreground.png",
    [string]$Dest = "C:\Users\viweb\Desktop\PROYECTO\PROVIWEBIOS\PROVIWEBIOS-main\PROVIWEBIOS-main\PROVIWEB\Assets.xcassets\AppIcon.appiconset"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$hq = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$sq = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$po = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$cq = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

# 1) Maestro 1024x1024: fondo blanco + logo centrado y escalado (~78% del lienzo,
#    igual que el ic_launcher de Android).
$master = New-Object System.Drawing.Bitmap 1024, 1024, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($master)
$g.InterpolationMode = $hq; $g.SmoothingMode = $sq; $g.PixelOffsetMode = $po; $g.CompositingQuality = $cq
$g.Clear([System.Drawing.Color]::White)
$src = [System.Drawing.Image]::FromFile($Source)
# El arte ocupa ~58% del canvas de origen; 1.34x lo lleva a ~78% del icono.
$draw = 1374
$off = [int]((1024 - $draw) / 2)
$g.DrawImage($src, (New-Object System.Drawing.Rectangle $off, $off, $draw, $draw))
$g.Dispose()
$src.Dispose()

# 2) Tamaños requeridos (iPhone + iPad + App Store marketing)
$sizes = @(20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024)
foreach ($size in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $gg = [System.Drawing.Graphics]::FromImage($bmp)
    $gg.InterpolationMode = $hq; $gg.SmoothingMode = $sq; $gg.PixelOffsetMode = $po; $gg.CompositingQuality = $cq
    $gg.Clear([System.Drawing.Color]::White)
    $gg.DrawImage($master, (New-Object System.Drawing.Rectangle 0, 0, $size, $size))
    $gg.Dispose()
    $path = Join-Path $Dest ("AppIcon-{0}.png" -f $size)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output ("  + AppIcon-{0}.png ({1}x{1})" -f $size, $size)
}
$master.Dispose()

# 3) Verifica dimensiones y que los PNG no tengan canal alfa
Write-Output "--- Verificacion ---"
Get-ChildItem $Dest -Filter *.png | Sort-Object Name | ForEach-Object {
    $img = [System.Drawing.Image]::FromFile($_.FullName)
    $hasAlpha = ($img.PixelFormat -band [System.Drawing.Imaging.PixelFormat]::Alpha) -ne 0
    Write-Output ("  {0}: {1}x{2} alpha={3}" -f $_.Name, $img.Width, $img.Height, $hasAlpha)
    $img.Dispose()
}
Write-Output "OK: AppIcon generado."
