# check-integrity.ps1 — verificación estática del proyecto PROVIWEB iOS
# Uso: powershell -ExecutionPolicy Bypass -File check-integrity.ps1 -Root "C:\...\PROVIWEBIOS-main"
param(
    [Parameter(Mandatory = $true)][string]$Root
)

$ErrorActionPreference = "Stop"
$sw = Get-ChildItem -Path $Root -Recurse -Filter *.swift | Where-Object { $_.FullName -notmatch "\\build\\" }
$issues = @()

function Add-Issue($Severity, $File, $Line, $Msg) {
    $relative = if (Test-Path $File) { (Resolve-Path -Relative $File).Replace('.\', '') } else { $File }
    $script:issues += [PSCustomObject]@{
        Severity = $Severity
        File     = $relative
        Line     = $Line
        Message  = $Msg
    }
}

Write-Host "=== PROVIWEB iOS - verificacion estatica ==="
Write-Host "Ficheros Swift: $($sw.Count)"
Write-Host ""

# ---------------------------------------------------------------
# 1) Balance de delimitadores (llaves, parentesis, corchetes)
#    ignorando cadenas y comentarios de linea/bloque.
# ---------------------------------------------------------------
function Remove-StringsAndComments([string]$text) {
    $sb = New-Object System.Text.StringBuilder
    $i = 0; $n = $text.Length
    while ($i -lt $n) {
        $c = $text[$i]
        if ($c -eq '/' -and ($i + 1) -lt $n -and $text[$i + 1] -eq '/') {
            while ($i -lt $n -and $text[$i] -ne "`n") { $i++ }
            continue
        }
        if ($c -eq '/' -and ($i + 1) -lt $n -and $text[$i + 1] -eq '*') {
            $depth = 1; $i += 2
            while ($i -lt $n -and $depth -gt 0) {
                if ($i -lt ($n - 1) -and $text[$i] -eq '/' -and $text[$i + 1] -eq '*') { $depth++; $i += 2; continue }
                if ($i -lt ($n - 1) -and $text[$i] -eq '*' -and $text[$i + 1] -eq '/') { $depth--; $i += 2; continue }
                $i++
            }
            continue
        }
        if ($c -eq '"') {
            if ($i -ge 3 -and $text.Substring($i, 3) -eq '"""') {
                $i += 3
                while ($i -lt $n) {
                    if ($i -lt ($n - 2) -and $text.Substring($i, 3) -eq '"""') { $i += 3; break }
                    if ($text[$i] -eq '\' ) { $i += 2; continue }
                    $i++
                }
                continue
            }
            $i++
            while ($i -lt $n) {
                if ($text[$i] -eq '\') { $i += 2; continue }
                if ($text[$i] -eq '"') { $i++; break }
                $i++
            }
            continue
        }
        [void]$sb.Append($c)
        $i++
    }
    return $sb.ToString()
}

$balanceProblems = 0
foreach ($f in $sw) {
    $raw = [System.IO.File]::ReadAllText($f.FullName)
    $clean = Remove-StringsAndComments $raw
    foreach ($pair in @(@('{', '}'), @('(', ')'), @('[', ']'))) {
        $open  = ([regex]::Matches($clean, [regex]::Escape($pair[0]))).Count
        $close = ([regex]::Matches($clean, [regex]::Escape($pair[1]))).Count
        if ($open -ne $close) {
            Add-Issue "BLOCKER" $f.FullName 0 "Delimitador desbalanceado '$($pair[0])' vs '$($pair[1])': $open / $close"
            $balanceProblems++
        }
    }
    $ifs  = ([regex]::Matches($clean, '(?m)^\s*#if\b')).Count
    $ends = ([regex]::Matches($clean, '(?m)^\s*#endif\b')).Count
    if ($ifs -ne $ends) {
        Add-Issue "BLOCKER" $f.FullName 0 "#if / #endif desbalanceados: $ifs / $ends"
        $balanceProblems++
    }
}
Write-Host "[1] Balance de delimitadores / #if: $(if ($balanceProblems -eq 0) {'OK'} else {"$balanceProblems problemas"})"

# ---------------------------------------------------------------
# 2) Vistas 'public struct X: View' sin init() usadas en otro fichero
#    (memberwise init privado -> error 'initializer is inaccessible')
# ---------------------------------------------------------------
$structs = @()
foreach ($f in $sw) {
    $raw = [System.IO.File]::ReadAllText($f.FullName)
    foreach ($m in [regex]::Matches($raw, '(?m)^\s*public struct (\w+)\s*:\s*View\b')) {
        $structs += [PSCustomObject]@{ Name = $m.Groups[1].Value; File = $f.FullName; HasInit = ($raw -match '(?m)^\s*(public |private |internal )?init\s*\(') }
    }
}
$missing = @()
foreach ($s in $structs) {
    if ($s.HasInit) { continue }
    $other = $sw | Where-Object { $_.FullName -ne $s.File }
    $used = $false
    foreach ($o in $other) {
        $raw = [System.IO.File]::ReadAllText($o.FullName)
        if ($raw -match ('(?<![\w.])' + [regex]::Escape($s.Name) + '\s*\(')) { $used = $true; break }
    }
    if ($used) { $missing += $s }
}
foreach ($m in $missing) {
    Add-Issue "BLOCKER" $m.File 0 "Vista '$($m.Name)' sin init() publico pero instanciada en otro fichero"
}
Write-Host "[2] Vistas sin init() usadas en otro fichero: $(if ($missing.Count -eq 0) {'OK'} else {"$($missing.Count) bloqueos -> $($missing.Name -join ', ')"})"

# ---------------------------------------------------------------
# 3) Cadenas huerfanas / llamadas a simbolos inexistentes (basico)
# ---------------------------------------------------------------
$todoPattern = '(?m)^\s*//(.*)(TODO|FIXME|HACK|XXX|BROKEN)(.*)$'
foreach ($f in $sw) {
    $lines = [System.IO.File]::ReadAllLines($f.FullName)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $todoPattern) { Add-Issue "WARN" $f.FullName ($i + 1) "Marcador pendiente: $($lines[$i].Trim())" }
    }
}
$todoCount = ($issues | Where-Object { $_.Message -like 'Marcador pendiente*' }).Count
Write-Host "[3] Marcadores TODO/FIXME: $(if ($todoCount -eq 0) {'0'} else {$todoCount})"

# ---------------------------------------------------------------
# 4) Recursos del proyecto en disco vs project.pbxproj
# ---------------------------------------------------------------
$pbxPath = Join-Path $Root "PROVIWEB.xcodeproj\project.pbxproj"
if (Test-Path $pbxPath) {
    $pbx = [System.IO.File]::ReadAllText($pbxPath)
    # Ficheros .swift en disco dentro de PROVIWEB/ que no aparecen en el pbxproj
    $orphans = @()
    foreach ($f in $sw) {
        if ($f.FullName -notmatch '\\PROVIWEB\\') { continue }
        if ($pbx -notmatch ([regex]::Escape($f.Name))) { $orphans += $f }
    }
    foreach ($o in $orphans) { Add-Issue "BLOCKER" $o.FullName 0 "Fichero Swift en disco ausente de project.pbxproj (no se compila)" }
    Write-Host "[4] Swift en disco ausentes del pbxproj: $(if ($orphans.Count -eq 0) {'OK'} else {"$($orphans.Count)"})"
} else {
    Add-Issue "WARN" $pbxPath 0 "No se encontró project.pbxproj"
    Write-Host "[4] project.pbxproj: NO ENCONTRADO"
}

# ---------------------------------------------------------------
# 5) Assets / iconos / esquema compartido
# ---------------------------------------------------------------
$iconSet = Join-Path $Root "PROVIWEB\Assets.xcassets\AppIcon.appiconset"
if (Test-Path $iconSet) {
    $pngs = Get-ChildItem $iconSet -Filter *.png -ErrorAction SilentlyContinue
    if ($pngs.Count -eq 0) {
        Add-Issue "BLOCKER" $iconSet 0 "AppIcon.appiconset sin PNGs (App Store rechaza builds sin iconos)"
    }
    Write-Host "[5] AppIcon PNGs: $($pngs.Count)"
} else {
    Add-Issue "BLOCKER" $iconSet 0 "Falta AppIcon.appiconset"
}

$scheme = Join-Path $Root "PROVIWEB.xcodeproj\xcshareddata\xcschemes\PROVIWEB.xcscheme"
if (-not (Test-Path $scheme)) {
    Add-Issue "BLOCKER" $scheme 0 "Falta el scheme compartido (lo exige el workflow de CI)"
    Write-Host "[6] Scheme compartido: FALTA"
} else {
    Write-Host "[6] Scheme compartido: OK"
}

# ---------------------------------------------------------------
# Resultado
# ---------------------------------------------------------------
Write-Host ""
$blockers = @($issues | Where-Object { $_.Severity -eq 'BLOCKER' })
$warns    = @($issues | Where-Object { $_.Severity -eq 'WARN' })
if ($issues.Count -eq 0) {
    Write-Host "RESULTADO: SIN PROBLEMAS"
} else {
    Write-Host "RESULTADO: $($blockers.Count) BLOCKER / $($warns.Count) WARN"
    $issues | Sort-Object Severity, File, Line | Format-Table -AutoSize | Out-String -Width 220 | Write-Host
}
exit $(if ($blockers.Count -gt 0) { 1 } else { 0 })
