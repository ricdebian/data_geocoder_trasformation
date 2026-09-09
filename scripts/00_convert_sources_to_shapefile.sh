#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Uso: $0 <directorio_trabajo> [--force]" >&2
  echo "Convierte las fuentes vectoriales preparadas a Shapefile." >&2
  exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage
WORKDIR=$1
FORCE=${2:-}
RAW="$WORKDIR/raw"
OUTPUT="$WORKDIR/shapefile"

command -v ogrinfo >/dev/null || { echo "Falta ogrinfo (GDAL)" >&2; exit 1; }
command -v ogr2ogr >/dev/null || { echo "Falta ogr2ogr (GDAL)" >&2; exit 1; }
[[ -d "$RAW" ]] || { echo "No existe $RAW; ejecute 01_prepare_sources.sh" >&2; exit 1; }

if [[ -d "$OUTPUT" && "$FORCE" != "--force" ]]; then
  echo "Ya existe $OUTPUT; use --force para regenerarlo" >&2
  exit 1
fi

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"

copy_shapefiles() {
  while IFS= read -r -d '' shp; do
    local base=${shp%.shp}
    local relative_dir=${shp#"$RAW"/}
    relative_dir=${relative_dir%/*}
    local target_dir="$OUTPUT/$relative_dir"
    mkdir -p "$target_dir"
    cp "$base".* "$target_dir/"
  done < <(find "$RAW" -type f -name '*.shp' -print0)
}

convert_geopackages() {
  while IFS= read -r -d '' source; do
    local relative=${source#"$RAW"/}
    local source_dir=${relative%/*}
    local source_name=${relative##*/}
    local dataset=${source_name%.gpkg}
    local target_dir="$OUTPUT/$source_dir/$dataset"
    mkdir -p "$target_dir"

    mapfile -t layers < <(
      ogrinfo -ro "$source" 2>/dev/null |
        sed -n 's/^ [0-9]*: \([^ (]*\).*/\1/p'
    )

    [[ ${#layers[@]} -gt 0 ]] || {
      echo "No se encontraron capas en $source" >&2
      exit 1
    }

    for layer in "${layers[@]}"; do
      safe_layer=${layer//[^[:alnum:]_.-]/_}
      target="$target_dir/${safe_layer}.shp"
      echo "Convirtiendo $source:$layer -> $target"
      ogr2ogr \
        -f "ESRI Shapefile" \
        "$target" "$source" "$layer" \
        -t_srs EPSG:4326 \
        -nlt PROMOTE_TO_MULTI \
        -lco ENCODING=UTF-8 \
        -overwrite
    done
  done < <(find "$RAW" -type f -name '*.gpkg' -print0)
}

copy_shapefiles "$RAW"
convert_geopackages

printf 'Fuentes unificadas en formato Shapefile: %s\n' "$OUTPUT"
