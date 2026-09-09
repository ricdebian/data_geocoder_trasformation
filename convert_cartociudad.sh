#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Uso: $0 <entrada.gpkg> <directorio_salida> [sufijo]"
  echo
  echo "Exporta las capas de CartoCiudad a Shapefile en EPSG:4326."
  echo "Ejemplo: $0 provincia.gpkg ./shp ES"
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage >&2
  exit 2
fi

input=$1
output_dir=$2
suffix=${3:-ES}

[[ -f "$input" ]] || {
  echo "No existe el fichero de entrada: $input" >&2
  exit 1
}

command -v ogrinfo >/dev/null || {
  echo "No se encontró ogrinfo (GDAL)." >&2
  exit 1
}
command -v ogr2ogr >/dev/null || {
  echo "No se encontró ogr2ogr (GDAL)." >&2
  exit 1
}

mkdir -p "$output_dir"

mapfile -t layers < <(
  ogrinfo -ro "$input" 2>/dev/null |
    sed -n 's/^ [0-9]*: \([^ (]*\).*/\1/p'
)

if [[ ${#layers[@]} -eq 0 ]]; then
  echo "No se encontraron capas en $input" >&2
  exit 1
fi

for layer in "${layers[@]}"; do
  target="${output_dir}/${layer}_${suffix}.shp"
  echo "Exportando ${layer} -> ${target}"
  ogr2ogr \
    -f "ESRI Shapefile" \
    "$target" "$input" "$layer" \
    -t_srs EPSG:4326 \
    -nlt PROMOTE_TO_MULTI \
    -lco ENCODING=UTF-8 \
    -overwrite
done

echo
echo "Conversión terminada. Capas generadas:"
find "$output_dir" -maxdepth 1 -type f -name "*_${suffix}.*" -printf "  %f\n" | sort
