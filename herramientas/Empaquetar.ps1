# Genera el .zip que se sube a CurseForge: Nexo y todos los addons Nexo_<nombre>,
# cada carpeta en la raíz del .zip, listo para descomprimir en Interface\AddOns.
#
#   .\Empaquetar.ps1                  deja dist\Nexo-<versión>.zip (la versión es la de Nexo.toc)
#   .\Empaquetar.ps1 -Version 1.6.0   usa esa versión en el nombre del .zip
#   .\Empaquetar.ps1 -Salida C:\tmp   deja el .zip en otra carpeta
#
# Lo usa también el flujo de GitHub (.github\workflows\publicar.yml), así que el .zip
# hecho a mano y el publicado son iguales.
param(
    [string]$Version,
    [string]$Salida
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$raiz = Split-Path $PSScriptRoot -Parent
if (-not $Salida) { $Salida = Join-Path $raiz 'dist' }

# Los addons son las carpetas de la raíz que tienen un .toc con su mismo nombre
$addons = @(Get-ChildItem -LiteralPath $raiz -Directory |
    Where-Object { $_.Name -match '^Nexo(_|$)' -and (Test-Path (Join-Path $_.FullName "$($_.Name).toc")) } |
    Sort-Object Name)
if (-not $addons -or $addons.Name -notcontains 'Nexo') { throw "No encuentro la carpeta Nexo en $raiz" }

function Version-Toc($carpeta) {
    $toc = Join-Path $carpeta.FullName "$($carpeta.Name).toc"
    $linea = Get-Content -LiteralPath $toc -Encoding UTF8 | Where-Object { $_ -match '^##\s*Version:\s*(.+?)\s*$' } | Select-Object -First 1
    if (-not $linea) { throw "$toc no tiene línea ## Version" }
    $linea -replace '^##\s*Version:\s*', '' -replace '\s+$', ''
}

if (-not $Version) { $Version = Version-Toc ($addons | Where-Object Name -eq 'Nexo') }

New-Item -ItemType Directory -Force -Path $Salida | Out-Null
$zip = Join-Path $Salida "Nexo-$Version.zip"
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip }

# Se escribe entrada a entrada para que las rutas lleven siempre "/" (Compress-Archive
# de Windows PowerShell pone "\" y esos .zip fallan fuera de Windows)
$archivo = [System.IO.Compression.ZipFile]::Open($zip, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    function Meter($origen, $nombre) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archivo, $origen, $nombre, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
    foreach ($addon in $addons) {
        $base = $addon.FullName.TrimEnd('\', '/').Length + 1
        foreach ($f in Get-ChildItem -LiteralPath $addon.FullName -Recurse -File | Sort-Object FullName) {
            $relativa = $f.FullName.Substring($base) -replace '\\', '/'
            Meter $f.FullName "$($addon.Name)/$relativa"
        }
        Write-Host ("  {0,-16} {1}" -f $addon.Name, (Version-Toc $addon))
    }
    # La licencia viaja dentro del núcleo
    $licencia = Join-Path $raiz 'LICENSE'
    if (Test-Path -LiteralPath $licencia) { Meter $licencia 'Nexo/LICENSE' }
}
finally {
    $archivo.Dispose()
}

$kb = [math]::Round((Get-Item -LiteralPath $zip).Length / 1KB)
Write-Host ""
Write-Host "Listo: $zip ($kb KB, $($addons.Count) addons)"
