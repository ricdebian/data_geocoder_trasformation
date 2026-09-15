# Scripts ETL espacial hacia Oracle Geocoder

El flujo no crea manualmente las tablas oficiales `GC_*_ES`. Oracle debe crear
esas tablas y sus índices mediante sus scripts y procedimientos propios. Estos
scripts preparan los datos y dejan una zona staging estable para el adaptador de
carga de cada instalación.

## Flujo

```bash
./scripts/01_prepare_sources.sh ./work
./scripts/00_convert_sources_to_shapefile.sh ./work
sqlplus usuario/password@servicio @sql/01_create_staging.sql
./scripts/02_load_staging.sh ./work usuario/password@servicio GEOCODER
sqlplus usuario/password@servicio @sql/02_transform_staging.sql
sqlplus usuario/password@servicio @sql/03_validate_staging.sql
sqlplus usuario/password@servicio @sql/04_transform_postal_code.sql
```

`01_prepare_sources.sh` descomprime los tres paquetes y genera un inventario
GDAL. `00_convert_sources_to_shapefile.sh` convierte todas las capas de
GeoPackage y conserva las capas que ya son Shapefile en un directorio común,
reproyectándolas a EPSG:4326. `02_load_staging.sh` carga desde ese directorio
unificado CartoCiudad, Geofabrik y las capas prioritarias de Redes de Transporte
mediante el driver OCI de GDAL.

`sql/01_create_staging.sql` es el script maestro de creación de los objetos
canónicos y ejecuta estos scripts:

- `sql/staging/01_create_tables.sql`: tablas `STG_GC_*_ES`.
- `sql/staging/02_create_spatial_metadata.sql`: metadatos de `SDO_GEOMETRY`.
- `sql/staging/03_create_spatial_indexes.sql`: índices espaciales.

Las tablas de origen `STG_CARTO_*`, `STG_OSM_*` y `STG_RT_*` se siguen creando
con `ogr2ogr` durante `02_load_staging.sh`, porque sus columnas dependen de la
edición concreta de los paquetes CartoCiudad, Geofabrik y Redes de Transporte.

## Creación del Oracle Geocoder y perfiles de idioma

La guía completa, incluidas las consultas para inspeccionar el DDL, está en
[`../objetos_gc_oracle.md`](../objetos_gc_oracle.md).

Antes de cargar datos en las tablas oficiales, la instalación objetivo debe
tener ejecutados los scripts oficiales de Oracle para:

1. Crear el perfil de país y los objetos del geocoder para España.
2. Crear las tablas `GC_AREA_ES`, `GC_POSTAL_CODE_ES`, `GC_ROAD_ES`,
   `GC_ROAD_SEGMENT_ES`, `GC_ADDRESS_POINT_ES` y `GC_POI_ES`, junto con sus
   tipos, restricciones, metadatos e índices.
3. Crear y configurar los objetos de perfiles del parser, incluidos
   `GC_PARSER_PROFILES` y `GC_PARSER_PROFILEAFS` cuando existan en la versión
   instalada.
4. Asociar el idioma español y el país `ES` al perfil usado por el servicio,
   incluyendo abreviaturas, tipos de vía, acentos y reglas de normalización.
5. Validar una dirección española antes de iniciar la carga ETL.

Estos pasos deben ejecutarse con la documentación y los scripts oficiales de
la versión concreta de Oracle Geocoder. Los nombres de procedimientos,
columnas, códigos de idioma y perfiles pueden variar; no deben sustituirse por
DDL aproximado. Una vez creados los objetos, obtener su definición con
`DBMS_METADATA.GET_DDL` y revisar las columnas reales antes de completar
`sql/04_load_gc_es_adapter.sql`.

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
