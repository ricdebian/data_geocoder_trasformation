[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$WorkDir,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$OciConnection,

    [Parameter(Position = 2)]
    [string]$Schema
)
echo $OciConnection
echo "***********"
$env:Path += ";C:\Program Files\QGIS 3.44.4\bin"
$env:Path += ";C:\Users\mamaberi\instantclient_23_26"
$env:OGR_FORCE_LOCAL_TIME_ZONE = ""
$env:ORA_SDTZ = "Europe/Madrid"
$env:NLS_LANG="SPANISH_SPAIN.UTF8"
#$env:TNS_ADMIN = "C:\Users\mamaberi\network\admin"
# Asegura que las variables de GDAL sigan activas
#$env:GDAL_DATA = "C:\OSGeo4W\share\gdal"
#$env:PROJ_LIB = "C:\OSGeo4W\share\proj"

# Fuerza a GDAL a buscar plugins en la carpeta correcta de OSGeo4W
$env:GDAL_DRIVER_PATH = "C:\Program Files\QGIS 3.44.4\apps\gdal\lib\gdalplugins"


#& "C:\Program Files\QGIS 3.44.4\bin\o4w_env.bat"
$env:GDAL_DATA = "C:\Program Files\QGIS 3.44.4\apps\gdal\share\gdal"
$env:PROJ_DATA = "C:\Program Files\QGIS 3.44.4\share\proj"


$ErrorActionPreference = 'Stop'
$raw = Join-Path $WorkDir 'raw'

if (-not (Get-Command ogr2ogr -ErrorAction SilentlyContinue)) {
    throw 'Falta ogr2ogr (GDAL)'
}
if (-not (Test-Path $raw -PathType Container)) {
    throw "No existe $raw; ejecute 01_prepare_sources.ps1"
}

function Get-TargetTable([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Schema)) {
        return $Name
    }
    return "$Schema.$Name"
}

function Find-FirstSource([string]$Path, [string]$Name) {
    $file = Get-ChildItem -Path $Path -Recurse -File -Filter $Name |
        Select-Object -First 1
    if ($null -eq $file) {
        throw "No se localizó $Name bajo $Path"
    }
    return $file.FullName
}

function Load-Layer {
    param(
        [string]$Source,
        [string]$Layer,
        [string]$Target
    )
    echo "Abriendo conexi�n: $OciConnection"
    if (-not (Test-Path $Source -PathType Leaf)) {
        throw "No existe la fuente: $Source"
    }
    Write-Output "Cargando $Layer -> $Target"
    & ogr2ogr -f OCI "OCI:$OciConnection" $Source $Layer `
        -nln $Target -lco GEOMETRY_NAME=GEOMETRY `
        -lco DIM=2 -lco SRID=4258 -overwrite `
        -mapFieldType DateTime=String
    if ($LASTEXITCODE -ne 0) {
        throw "ogr2ogr falló al cargar $Layer"
    }
}

$carto = Find-FirstSource (Join-Path $raw 'cartociudad') 'madrid.gpkg'
$gpkg = Find-FirstSource (Join-Path $raw 'geofabrik') 'madrid.gpkg'
$rt = Find-FirstSource (Join-Path $raw 'redes_transporte') 'rt_tramo_vial.shp'
$rtDir = Split-Path -Parent $rt

Load-Layer $carto 'portalpk_publi' (Get-TargetTable 'STG_CARTO_PORTAL')
Load-Layer $carto 'manzana' (Get-TargetTable 'STG_CARTO_MANZANA')
Load-Layer $gpkg 'gis_osm_roads_free' (Get-TargetTable 'STG_OSM_ROAD')
Load-Layer $gpkg 'gis_osm_pois_free' (Get-TargetTable 'STG_OSM_POI')
Load-Layer $gpkg 'gis_osm_places_free' (Get-TargetTable 'STG_OSM_PLACE')
Load-Layer $gpkg 'gis_osm_adminareas_a_free' (Get-TargetTable 'STG_OSM_AREA')
Load-Layer $rt 'rt_tramo_vial' (Get-TargetTable 'STG_RT_TRAMO_VIAL')
Load-Layer (Join-Path $rtDir 'rt_portalpk_p.shp') 'rt_portalpk_p' (Get-TargetTable 'STG_RT_PORTAL')
Load-Layer (Join-Path $rtDir 'rt_puntoctra_p.shp') 'rt_puntoctra_p' (Get-TargetTable 'STG_RT_PUNTOCTRA')
Load-Layer (Join-Path $rtDir 'rt_nodoctra_p.shp') 'rt_nodoctra_p' (Get-TargetTable 'STG_RT_NODOCTRA')
Load-Layer (Join-Path $rtDir 'rt_areactra_s.shp') 'rt_areactra_s' (Get-TargetTable 'STG_RT_AREACTRA')

