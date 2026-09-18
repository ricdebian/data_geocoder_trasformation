# Flujo directo desde GeoPackage

Este directorio conserva el flujo que carga las capas directamente desde
GeoPackage mediante `ogr2ogr`, sin generar previamente Shapefiles.

```bash
./scripts/flujo-directo-gpkg/01_prepare_sources.sh ./work
./scripts/flujo-directo-gpkg/02_load_staging.sh ./work usuario/password@servicio GEOCODER
```

Las tablas canónicas se crean y transforman con los mismos scripts SQL del
repositorio (`sql/01_create_staging.sql`, `sql/02_transform_staging.sql`, etc.).
