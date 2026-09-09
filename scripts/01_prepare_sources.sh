#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Uso: $0 <directorio_trabajo> [--force]" >&2
  exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage
WORKDIR=$1
FORCE=${2:-}
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DATA="$ROOT/datos_espaciales"
mkdir -p "$WORKDIR/raw" "$WORKDIR/inventory"

command -v unzip >/dev/null || { echo "Falta unzip" >&2; exit 1; }
command -v ogrinfo >/dev/null || { echo "Falta ogrinfo (GDAL)" >&2; exit 1; }

extract_zip() {
  local archive=$1
  local target=$2
  if [[ -d "$target" && "$FORCE" != "--force" ]]; then
    return
  fi
  mkdir -p "$target"
  unzip -q -o "$archive" -d "$target"
}

extract_zip "$DATA/CARTOCIUDAD_CALLEJERO_MADRID.zip" "$WORKDIR/raw/cartociudad"
extract_zip "$DATA/madrid-260831-free.gpkg.zip" "$WORKDIR/raw/geofabrik"
extract_zip "$DATA/RT_MADRID_shp.zip" "$WORKDIR/raw/redes_transporte"

find "$WORKDIR/raw" -type f \( -name '*.gpkg' -o -name '*.shp' \) -print0 |
  while IFS= read -r -d '' file; do
    name=$(basename "$file")
    safe=${name//[^[:alnum:]_.-]/_}
    ogrinfo -ro -so -al "$file" > "$WORKDIR/inventory/${safe}.txt"
  done

printf 'Fuentes preparadas en %s\nInventario en %s\n' "$WORKDIR/raw" "$WORKDIR/inventory"
