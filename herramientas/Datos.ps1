# Exporta e importa los datos guardados de Nexo y sus addons, para llevarlos a otro ordenador.
#
#   .\Datos.ps1 exportar [archivo.zip]    guarda los datos en un .zip (por defecto, en el Escritorio)
#   .\Datos.ps1 importar [archivo.zip]    los pone en el juego (por defecto, el .zip más reciente
#                                         del Escritorio, Descargas o esta carpeta)
#
#   .\Datos.ps1 migrar                    recupera los datos guardados con los nombres antiguos
#                                         (Tesorero, Bitacora...) para los addons Nexo_<nombre>
#
#   -Juego "D:\World of Warcraft"   carpeta del juego, si no la encuentra sola
#   -Version _forever_              versión del juego dentro de esa carpeta
#   -Si                             no preguntar antes de sustituir
#
# Un addon no puede leer ni escribir archivos, así que esto se hace desde fuera, con el juego cerrado.
param(
    [Parameter(Position = 0)][ValidateSet('exportar', 'importar', 'migrar')][string]$Accion,
    [Parameter(Position = 1)][string]$Archivo,
    [string]$Juego,
    [string]$Version = '_forever_',
    [switch]$Si
)
$ErrorActionPreference = 'Stop'

$ADDONS = 'Nexo', 'Nexo_Tesorero', 'Nexo_Bitacora', 'Nexo_Alijo', 'Nexo_Senda', 'Nexo_Oficio', 'Nexo_Lonja', 'Nexo_Vuelo'

# Antes de llamarse Nexo_<nombre>, los addons (y sus archivos de datos) se llamaban solo <nombre>
function Nombre-Antiguo($a) { $a -replace '^Nexo_', '' }
$PREFIJO = 'nexo-datos-'

function Es-Version($ruta) { (Split-Path $ruta -Leaf) -like '_*_' }

# Carpeta de la versión del juego (la que contiene Interface y WTF)
function Buscar-Juego {
    $cand = @()
    if ($Juego) {
        $cand += $Juego
    } else {
        foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft',
                       'HKLM:\SOFTWARE\Blizzard Entertainment\World of Warcraft') {
            try {
                $p = (Get-ItemProperty -Path $k -ErrorAction Stop).InstallPath
                if ($p) { $cand += (Split-Path $p.TrimEnd('\') -Parent) }
            } catch {}
        }
        foreach ($d in [IO.DriveInfo]::GetDrives()) {
            if ($d.DriveType -ne 'Fixed') { continue }
            foreach ($s in 'World of Warcraft', 'Battle\World of Warcraft', 'Battle.net\World of Warcraft',
                           'Program Files (x86)\World of Warcraft', 'Program Files\World of Warcraft',
                           'Games\World of Warcraft', 'Juegos\World of Warcraft') {
                $cand += (Join-Path $d.Name $s)
            }
        }
    }
    foreach ($c in $cand) {
        if (-not (Test-Path -LiteralPath $c)) { continue }
        if (Es-Version $c) { return (Resolve-Path -LiteralPath $c).Path }
        $v = Join-Path $c $Version
        if (Test-Path -LiteralPath $v) { return (Resolve-Path -LiteralPath $v).Path }
    }
    if ($Juego) { throw "No encuentro el juego en '$Juego' (busco la carpeta $Version)." }
    throw "No encuentro la carpeta del juego. Indícala con -Juego `"D:\ruta\World of Warcraft`"."
}

# ¿Está abierto el juego de esa carpeta? (si no se puede saber de dónde es el proceso, cuenta como abierto)
function Juego-Abierto($raiz) {
    $base = $raiz.TrimEnd('\') + '\'
    @(Get-Process | Where-Object {
        $_.ProcessName -like 'Wow*' -and
        (-not $_.Path -or $_.Path.StartsWith($base, [StringComparison]::OrdinalIgnoreCase))
    }).Count -gt 0
}

function Carpeta-Temporal {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('nexo-datos-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $t | Out-Null
    return $t
}

# Archivos de datos que hay en una carpeta Account: { Cuenta, Addon, Ruta }.
# Si de un addon solo está el archivo con el nombre antiguo, vale ese: así sirven los .zip
# exportados antes del cambio de nombre y los datos de quien aún no ha actualizado.
function Listar-Datos($cuentas) {
    $out = @()
    if (-not (Test-Path -LiteralPath $cuentas)) { return $out }
    foreach ($c in Get-ChildItem -LiteralPath $cuentas -Directory) {
        if ($c.Name -eq 'SavedVariables') { continue }
        foreach ($a in $ADDONS) {
            $f = Join-Path $c.FullName "SavedVariables\$a.lua"
            if (-not (Test-Path -LiteralPath $f)) { $f = Join-Path $c.FullName "SavedVariables\$(Nombre-Antiguo $a).lua" }
            if (Test-Path -LiteralPath $f) {
                $out += [pscustomobject]@{ Cuenta = $c.Name; Addon = $a; Ruta = $f }
            }
        }
    }
    return $out
}

# Copia los archivos a carpeta\<cuenta>\SavedVariables y lo comprime todo en zip
function Comprimir($datos, $zip) {
    $tmp = Carpeta-Temporal
    try {
        foreach ($d in $datos) {
            $dest = Join-Path $tmp "$($d.Cuenta)\SavedVariables"
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            Copy-Item -LiteralPath $d.Ruta -Destination (Join-Path $dest "$($d.Addon).lua")   # con el nombre actual
        }
        if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip }
        Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $zip
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force
    }
}

function Linea($d) {
    $i = Get-Item -LiteralPath $d.Ruta
    '  {0,-14} {1,9:N0} KB   {2:dd/MM/yyyy HH:mm}' -f $d.Addon, [math]::Ceiling($i.Length / 1KB), $i.LastWriteTime
}

function Mostrar($datos) {
    foreach ($g in $datos | Group-Object Cuenta) {
        Write-Host "Cuenta $($g.Name)"
        foreach ($d in $g.Group) { Write-Host (Linea $d) }
    }
}

# ---------------------------------------------------------------------------
function Exportar {
    $raiz = Buscar-Juego
    Write-Host "Juego: $raiz"
    $datos = Listar-Datos (Join-Path $raiz 'WTF\Account')
    if (@($datos).Count -eq 0) { throw 'No hay datos guardados de Nexo ni de sus addons en este juego.' }
    if (Juego-Abierto $raiz) {
        Write-Warning 'El juego está abierto: se exporta lo guardado la última vez que saliste o hiciste /reload.'
    }
    if (-not $Archivo) {
        $script:Archivo = Join-Path ([Environment]::GetFolderPath('Desktop')) ($PREFIJO + (Get-Date -Format 'yyyy-MM-dd-HHmm') + '.zip')
    }
    Comprimir $datos $Archivo
    Mostrar $datos
    Write-Host ''
    Write-Host "Exportado en: $Archivo" -ForegroundColor Green
    Write-Host 'Lleva ese archivo al otro ordenador y allí usa "Importar datos".'
}

function Importar {
    if (-not $Archivo) {
        $sitios = [Environment]::GetFolderPath('Desktop'), (Join-Path $env:USERPROFILE 'Downloads'), $PSScriptRoot
        $ultimo = $sitios | Where-Object { $_ -and (Test-Path -LiteralPath $_) } |
            ForEach-Object { Get-ChildItem -LiteralPath $_ -Filter "$PREFIJO*.zip" -File } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $ultimo) { throw "No encuentro ningún $PREFIJO*.zip en el Escritorio, Descargas ni esta carpeta. Indica el archivo." }
        $script:Archivo = $ultimo.FullName
    }
    if (-not (Test-Path -LiteralPath $Archivo)) { throw "No existe el archivo '$Archivo'." }
    $script:Archivo = (Resolve-Path -LiteralPath $Archivo).Path

    $raiz = Buscar-Juego
    Write-Host "Juego:   $raiz"
    Write-Host "Archivo: $Archivo"
    if (Juego-Abierto $raiz) { throw 'Cierra el juego antes de importar: al salir sobrescribiría los datos importados.' }

    $tmp = Carpeta-Temporal
    try {
        Expand-Archive -LiteralPath $Archivo -DestinationPath $tmp
        # Solo se aceptan <cuenta>\SavedVariables\<addon>.lua de los addons conocidos
        $nuevos = Listar-Datos $tmp
        if (@($nuevos).Count -eq 0) { throw 'El archivo no contiene datos de Nexo ni de sus addons.' }

        $cuentas = Join-Path $raiz 'WTF\Account'
        $actuales = @(Listar-Datos $cuentas | Where-Object {
            $a = $_
            @($nuevos | Where-Object { $_.Cuenta -eq $a.Cuenta -and $_.Addon -eq $a.Addon }).Count -gt 0
        })

        Write-Host ''
        Write-Host 'Se va a importar:'
        Mostrar $nuevos
        if ($actuales.Count -gt 0) {
            Write-Host ''
            Write-Host 'Sustituye a lo que hay ahora en este ordenador (no se mezclan):' -ForegroundColor Yellow
            Mostrar $actuales
            if (-not $Si) {
                $r = Read-Host '¿Sustituir? (s/n)'
                if ($r -notmatch '^[sSyY]') { Write-Host 'Cancelado. No se ha cambiado nada.'; return }
            }
            $copia = Join-Path (Split-Path $Archivo -Parent) ('nexo-copia-antes-de-importar-' + (Get-Date -Format 'yyyy-MM-dd-HHmmss') + '.zip')
            Comprimir $actuales $copia
            Write-Host "Copia de lo que había: $copia"
        }

        foreach ($d in $nuevos) {
            $dest = Join-Path $cuentas "$($d.Cuenta)\SavedVariables"
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
            Copy-Item -LiteralPath $d.Ruta -Destination (Join-Path $dest "$($d.Addon).lua") -Force
        }
        Write-Host ''
        Write-Host "Importado: $(@($nuevos).Count) archivos." -ForegroundColor Green
        Write-Host 'Ya puedes abrir el juego. Los addons tienen que estar instalados en Interface\AddOns.'
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force
    }
}

# Los addons se llamaban antes Tesorero, Bitacora... y el juego guarda los datos con el nombre del
# addon. Esto copia los datos antiguos al nombre nuevo, para quien borró las carpetas antiguas
# sin haber entrado antes al juego con las dos versiones instaladas.
function Migrar {
    $raiz = Buscar-Juego
    Write-Host "Juego: $raiz"
    if (Juego-Abierto $raiz) { throw 'Cierra el juego antes: al salir sobrescribiría los datos recuperados.' }
    $cuentas = Join-Path $raiz 'WTF\Account'
    $faltan = @(); $pisan = @()
    if (Test-Path -LiteralPath $cuentas) {
        foreach ($c in Get-ChildItem -LiteralPath $cuentas -Directory) {
            foreach ($a in $ADDONS) {
                $viejo = Join-Path $c.FullName "SavedVariables\$(Nombre-Antiguo $a).lua"
                $nuevo = Join-Path $c.FullName "SavedVariables\$a.lua"
                if ($viejo -eq $nuevo -or -not (Test-Path -LiteralPath $viejo)) { continue }
                $d = [pscustomobject]@{ Cuenta = $c.Name; Addon = $a; Ruta = $viejo; Destino = $nuevo }
                if (Test-Path -LiteralPath $nuevo) { $pisan += $d } else { $faltan += $d }
            }
        }
    }
    if ($faltan.Count + $pisan.Count -eq 0) { Write-Host 'No hay datos con los nombres antiguos. No hay nada que recuperar.'; return }

    if ($pisan.Count -gt 0) {
        $ahora = @($pisan | ForEach-Object { [pscustomobject]@{ Cuenta = $_.Cuenta; Addon = $_.Addon; Ruta = $_.Destino } })
        Write-Host ''
        Write-Host 'Estos addons ya tienen datos con el nombre nuevo:' -ForegroundColor Yellow
        Mostrar $ahora
        Write-Host 'y estos son los guardados con el nombre antiguo:'
        Mostrar $pisan
        Write-Host 'Si el juego ya pasó los datos solo, los nuevos son los buenos: responde n.'
        $r = if ($Si) { 's' } else { Read-Host '¿Sustituir los nuevos por los antiguos? (s/n)' }
        if ($r -match '^[sSyY]') {
            $copia = Join-Path ([Environment]::GetFolderPath('Desktop')) ('nexo-copia-antes-de-recuperar-' + (Get-Date -Format 'yyyy-MM-dd-HHmmss') + '.zip')
            Comprimir $ahora $copia
            Write-Host "Copia de lo que había: $copia"
            $faltan += $pisan
        }
    }
    foreach ($d in $faltan) { Copy-Item -LiteralPath $d.Ruta -Destination $d.Destino -Force }
    Write-Host ''
    if ($faltan.Count -gt 0) {
        Mostrar $faltan
        Write-Host "Recuperado: $($faltan.Count) archivos. Ya puedes abrir el juego." -ForegroundColor Green
    } else {
        Write-Host 'No se ha cambiado nada.'
    }
}

if (-not $Accion) {
    Write-Host 'Uso: .\Datos.ps1 exportar [archivo.zip]   |   .\Datos.ps1 importar [archivo.zip]   |   .\Datos.ps1 migrar'
    exit 1
}
try {
    switch ($Accion) { 'exportar' { Exportar } 'importar' { Importar } 'migrar' { Migrar } }
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
