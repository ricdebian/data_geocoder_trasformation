# Scripts ETL espacial hacia Oracle Geocoder

El flujo no crea manualmente las tablas oficiales `GC_*_ES`. Oracle debe crear
esas tablas y sus índices mediante sus scripts y procedimientos propios. Estos
scripts preparan los datos y dejan una zona staging estable para el adaptador de
carga de cada instalación.

## Flujo

```bash
./scripts/01_prepare_sources.sh ./work
sqlplus usuario/password@servicio @sql/01_create_staging.sql
./scripts/02_load_staging.sh ./work usuario/password@servicio GEOCODER
sqlplus usuario/password@servicio @sql/02_transform_staging.sql
sqlplus usuario/password@servicio @sql/03_validate_staging.sql
sqlplus usuario/password@servicio @sql/04_transform_postal_code.sql
```

`01_prepare_sources.sh` descomprime los tres paquetes y genera un inventario
GDAL. `02_load_staging.sh` carga CartoCiudad, Geofabrik y las capas prioritarias
de Redes de Transporte mediante el driver OCI de GDAL.

`02_transform_staging.sql` normaliza los campos conocidos de CartoCiudad y OSM
en tablas canónicas `STG_GC_*_ES`. Las capas de Redes de Transporte se cargan
completas en tablas `STG_RT_*` para adaptar sus campos al esquema oficial una
vez revisado el diccionario de atributos.

El fichero `04_load_gc_es_adapter.sql` es deliberadamente un adaptador vacío:
la carga final debe mapear explícitamente las columnas reales creadas por Oracle
y ejecutar los procedimientos oficiales de mantenimiento. No debe convertirse
en un DDL alternativo del geocoder.

`04_transform_postal_code.sql` genera candidatos para
`GC_POSTAL_CODE_ES` a partir de los portales de CartoCiudad, calcula el centro
medio del código postal y resuelve los IDs de `GC_AREA_ES`. Al final incluye
ejemplos comentados de carga para todas las tablas de datos
`GC_AREA_ES`, `GC_ROAD_ES`, `GC_ROAD_SEGMENT_ES`, `GC_ADDRESS_POINT_ES`,
`GC_POSTAL_CODE_ES` y `GC_POI_ES`. La inserción postal queda bloqueada hasta
disponer de `ROAD_SEGMENT_ID`, obligatorio en el modelo Oracle; todos los
bloques deben contrastarse con el DDL oficial de la instalación.
