# Flujo con conversión previa a Shapefile

Este directorio conserva el flujo que prepara las fuentes, convierte las capas
a Shapefile y después las carga mediante `ogr2ogr`.

```bash
./scripts/flujo-shapefile/01_prepare_sources.sh ./work
./scripts/flujo-shapefile/00_convert_sources_to_shapefile.sh ./work
./scripts/flujo-shapefile/02_load_staging.sh ./work usuario/password@servicio GEOCODER
```

Las tablas canónicas se crean y transforman con los mismos scripts SQL del
repositorio (`sql/01_create_staging.sql`, `sql/02_transform_staging.sql`, etc.).
