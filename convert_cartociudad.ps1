[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputPath,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$OutputDir,

    [Parameter(Position = 2)]
    [string]$Suffix = 'ES'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $InputPath -PathType Leaf)) {
    throw "No existe el fichero de entrada: $InputPath"
}
if (-not (Get-Command ogrinfo -ErrorAction SilentlyContinue)) {
    throw 'No se encontró ogrinfo (GDAL).'
}
if (-not (Get-Command ogr2ogr -ErrorAction SilentlyContinue)) {
    throw 'No se encontró ogr2ogr (GDAL).'
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$listing = & ogrinfo -ro $InputPath 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "ogrinfo falló para $InputPath"
}
$layers = @(
    $listing |
        Select-String '^\s*\d+:\s*([^\s(]+)' |
        ForEach-Object { $_.Matches[0].Groups[1].Value }
)
if ($layers.Count -eq 0) {
    throw "No se encontraron capas en $Input"
}

foreach ($layer in $layers) {
    $target = Join-Path $OutputDir "${layer}_${Suffix}.shp"
    Write-Output "Exportando $layer -> $target"
    & ogr2ogr -f 'ESRI Shapefile' $target $InputPath $layer `
        -t_srs EPSG:4326 -nlt PROMOTE_TO_MULTI `
        -lco ENCODING=UTF-8 -overwrite
    if ($LASTEXITCODE -ne 0) {
        throw "ogr2ogr falló para $layer"
    }
}

Write-Output ''
Write-Output 'Conversión terminada. Capas generadas:'
Get-ChildItem -Path $OutputDir -File |
    Where-Object { $_.Name -like "*_$Suffix.*" } |
    Sort-Object Name |
    ForEach-Object { Write-Output "  $($_.Name)" }
