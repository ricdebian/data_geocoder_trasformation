[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$WorkDir,

    [Parameter(Position = 1)]
    [ValidateSet('--force')]
    [string]$Force
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path $root 'datos_espaciales'
$raw = Join-Path $WorkDir 'raw'
$inventory = Join-Path $WorkDir 'inventory'

if (-not (Get-Command ogrinfo -ErrorAction SilentlyContinue)) {
    throw 'Falta ogrinfo (GDAL)'
}

New-Item -ItemType Directory -Force -Path $raw, $inventory | Out-Null

function Expand-SourceZip {
    param(
        [string]$Archive,
        [string]$Target
    )

    if (-not (Test-Path $Archive -PathType Leaf)) {
        throw "No existe el archivo de entrada: $Archive"
    }

    if ((Test-Path $Target -PathType Container) -and $Force -ne '--force') {
        return
    }

    New-Item -ItemType Directory -Force -Path $Target | Out-Null
    Expand-Archive -LiteralPath $Archive -DestinationPath $Target -Force
}

Expand-SourceZip (Join-Path $data 'CARTOCIUDAD_CALLEJERO_MADRID.zip') (Join-Path $raw 'cartociudad')
Expand-SourceZip (Join-Path $data 'madrid-260831-free.gpkg.zip') (Join-Path $raw 'geofabrik')
Expand-SourceZip (Join-Path $data 'RT_MADRID_shp.zip') (Join-Path $raw 'redes_transporte')

Get-ChildItem -Path $raw -Recurse -File |
    Where-Object { $_.Extension -in '.gpkg', '.shp' } |
    ForEach-Object {
        $safe = $_.Name -replace '[^a-zA-Z0-9_.-]', '_'
        $output = Join-Path $inventory "$safe.txt"
        & ogrinfo -ro -so -al $_.FullName *> $output
        if ($LASTEXITCODE -ne 0) {
            throw "ogrinfo falló para $($_.FullName)"
        }
    }

Write-Output "Fuentes preparadas en $raw"
Write-Output "Inventario en $inventory"
