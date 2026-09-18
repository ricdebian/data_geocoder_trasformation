#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Uso: $0 <directorio_trabajo> <conexion_oci> [esquema]" >&2
  echo "Ejemplo: $0 ./work usuario/password@servicio GEOCODER" >&2
  exit 2
}

[[ $# -ge 2 && $# -le 3 ]] || usage
WORKDIR=$1
OCI_CONN=$2
SCHEMA=${3:-}
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SHP="$WORKDIR/shapefile"

command -v ogr2ogr >/dev/null || { echo "Falta ogr2ogr (GDAL)" >&2; exit 1; }
[[ -d "$SHP" ]] || {
  echo "No existe $SHP; ejecute 01_prepare_sources.sh y 00_convert_sources_to_shapefile.sh" >&2
  exit 1
}

target_table() {
  local name=$1
  if [[ -n "$SCHEMA" ]]; then
    printf '%s.%s' "$SCHEMA" "$name"
  else
    printf '%s' "$name"
  fi
}

load_layer() {
  local source=$1 layer=$2 target=$3
  [[ -f "$source" ]] || { echo "No existe la fuente: $source" >&2; exit 1; }
  echo "Cargando $layer -> $target"
  ogr2ogr -f OCI "OCI:$OCI_CONN" "$source" "$layer" \
    -nln "$target" -lco GEOMETRY_NAME=GEOM \
    -lco DIM=2 -lco SRID=4258 -overwrite
}

CARTO=$(find "$SHP/cartociudad" -type f -name portalpk_publi.shp | head -n 1)
GPKG=$(find "$SHP/geofabrik" -type f -name gis_osm_roads_free.shp | head -n 1)
RT=$(find "$SHP/redes_transporte" -type f -name rt_tramo_vial.shp | head -n 1)
[[ -n "$CARTO" && -n "$GPKG" && -n "$RT" ]] || {
  echo "No se localizaron todos los ficheros fuente requeridos" >&2
  exit 1
}

load_layer "$CARTO" portalpk_publi "$(target_table STG_CARTO_PORTAL)"
load_layer "$(dirname "$CARTO")/manzana.shp" manzana "$(target_table STG_CARTO_MANZANA)"
load_layer "$GPKG" gis_osm_roads_free "$(target_table STG_OSM_ROAD)"
load_layer "$(dirname "$GPKG")/gis_osm_pois_free.shp" gis_osm_pois_free "$(target_table STG_OSM_POI)"
load_layer "$(dirname "$GPKG")/gis_osm_places_free.shp" gis_osm_places_free "$(target_table STG_OSM_PLACE)"
load_layer "$(dirname "$GPKG")/gis_osm_adminareas_a_free.shp" gis_osm_adminareas_a_free "$(target_table STG_OSM_AREA)"
load_layer "$RT" rt_tramo_vial "$(target_table STG_RT_TRAMO_VIAL)"
load_layer "$(dirname "$RT")/rt_portalpk_p.shp" rt_portalpk_p "$(target_table STG_RT_PORTAL)"
load_layer "$(dirname "$RT")/rt_puntoctra_p.shp" rt_puntoctra_p "$(target_table STG_RT_PUNTOCTRA)"
load_layer "$(dirname "$RT")/rt_nodoctra_p.shp" rt_nodoctra_p "$(target_table STG_RT_NODOCTRA)"
load_layer "$(dirname "$RT")/rt_areactra_s.shp" rt_areactra_s "$(target_table STG_RT_AREACTRA)"
