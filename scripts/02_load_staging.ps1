[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$WorkDir,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$OciConnection,

    [Parameter(Position = 2)]
    [string]$Schema
)

$ErrorActionPreference = 'Stop'
$shp = Join-Path $WorkDir 'shapefile'

if (-not (Get-Command ogr2ogr -ErrorAction SilentlyContinue)) {
    throw 'Falta ogr2ogr (GDAL)'
}
if (-not (Test-Path $shp -PathType Container)) {
    throw "No existe $shp; ejecute 01_prepare_sources.ps1 y 00_convert_sources_to_shapefile.ps1"
}

function Get-TargetTable([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Schema)) {
        return $Name
    }
    return "$Schema.$Name"
}

function Load-Layer {
    param(
        [string]$Source,
        [string]$Layer,
        [string]$Target
    )

    if (-not (Test-Path $Source -PathType Leaf)) {
        throw "No existe la fuente: $Source"
    }
    Write-Output "Cargando $Layer -> $Target"
    & ogr2ogr -f OCI "OCI:$OciConnection" $Source $Layer `
        -nln $Target -lco GEOMETRY_NAME=GEOM `
        -lco DIM=2 -lco SRID=4258 -overwrite
    if ($LASTEXITCODE -ne 0) {
        throw "ogr2ogr falló al cargar $Layer"
    }
}

function Find-FirstSource([string]$Path, [string]$Name) {
    $file = Get-ChildItem -Path $Path -Recurse -File -Filter $Name |
        Select-Object -First 1
    if ($null -eq $file) {
        throw "No se localizó $Name bajo $Path"
    }
    return $file.FullName
}

$carto = Find-FirstSource (Join-Path $shp 'cartociudad') 'portalpk_publi.shp'
$gpkg = Find-FirstSource (Join-Path $shp 'geofabrik') 'gis_osm_roads_free.shp'
$rt = Find-FirstSource (Join-Path $shp 'redes_transporte') 'rt_tramo_vial.shp'

$cartoDir = Split-Path -Parent $carto
$gpkgDir = Split-Path -Parent $gpkg
$rtDir = Split-Path -Parent $rt

Load-Layer $carto 'portalpk_publi' (Get-TargetTable 'STG_CARTO_PORTAL')
Load-Layer (Join-Path $cartoDir 'manzana.shp') 'manzana' (Get-TargetTable 'STG_CARTO_MANZANA')
Load-Layer $gpkg 'gis_osm_roads_free' (Get-TargetTable 'STG_OSM_ROAD')
Load-Layer (Join-Path $gpkgDir 'gis_osm_pois_free.shp') 'gis_osm_pois_free' (Get-TargetTable 'STG_OSM_POI')
Load-Layer (Join-Path $gpkgDir 'gis_osm_places_free.shp') 'gis_osm_places_free' (Get-TargetTable 'STG_OSM_PLACE')
Load-Layer (Join-Path $gpkgDir 'gis_osm_adminareas_a_free.shp') 'gis_osm_adminareas_a_free' (Get-TargetTable 'STG_OSM_AREA')
Load-Layer $rt 'rt_tramo_vial' (Get-TargetTable 'STG_RT_TRAMO_VIAL')
Load-Layer (Join-Path $rtDir 'rt_portalpk_p.shp') 'rt_portalpk_p' (Get-TargetTable 'STG_RT_PORTAL')
Load-Layer (Join-Path $rtDir 'rt_puntoctra_p.shp') 'rt_puntoctra_p' (Get-TargetTable 'STG_RT_PUNTOCTRA')
Load-Layer (Join-Path $rtDir 'rt_nodoctra_p.shp') 'rt_nodoctra_p' (Get-TargetTable 'STG_RT_NODOCTRA')
Load-Layer (Join-Path $rtDir 'rt_areactra_s.shp') 'rt_areactra_s' (Get-TargetTable 'STG_RT_AREACTRA')
