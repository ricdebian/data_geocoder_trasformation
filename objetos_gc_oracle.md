# Objetos oficiales del Oracle Geocoder para España

## Alcance

Este documento describe cómo preparar una instalación de Oracle Spatial
Geocoder 19c para España y cómo obtener la estructura real de sus objetos.
No sustituye los scripts oficiales de Oracle ni el dataset oficial del
Geocoder.

Oracle no proporciona una única sentencia `CREATE TABLE` genérica que instale
los datos españoles. Las tablas de datos `GC_*_ES` deben cargarse con el
script, export o dataset del Geocoder correspondiente a la versión instalada y
al proveedor de datos. Las definiciones conceptuales incluidas más abajo solo
sirven para identificar entidades y relaciones; no deben ejecutarse como DDL
de producción.

## Objetos esperados

El perfil español puede incluir, según la distribución instalada:

```text
GC_COUNTRY_PROFILE
GC_PARSER_PROFILES
GC_PARSER_PROFILEAFS
GC_AREA_ES
GC_ROAD_ES
GC_ROAD_SEGMENT_ES
GC_ADDRESS_POINT_ES
GC_POSTAL_CODE_ES
GC_POI_ES
GC_INTERSECTION_ES
```

La presencia exacta de `GC_ADDRESS_POINT_ES`, `GC_INTERSECTION_ES` u otros
objetos debe comprobarse en el dataset y en la documentación de la versión
instalada. No se deben crear tablas vacías únicamente porque aparezcan en un
modelo de referencia.

La referencia oficial de Oracle 19c es el capítulo **Geocoding Address Data**
de la *Oracle Spatial and Graph Developer's Guide*:

<https://docs.oracle.com/en/database/oracle/oracle-database/19/spatl/>

Oracle documenta `GC_ROAD_SEGMENT_<sufijo>.GEOMETRY` como la geometría espacial
principal y su índice `MDSYS.SPATIAL_INDEX_V2`. Las tablas de áreas, códigos
postales, POI, intersecciones y puntos de dirección usan principalmente
identificadores y coordenadas numéricas en el modelo del proveedor; no se debe
añadir una columna `SDO_GEOMETRY` a todas ellas por analogía con las tablas de
staging.

El script `complemento_objetos_gc_oracle_19c_drop_indices.sql` contiene un DDL
candidato con `DROP`, metadatos e índice espacial para integración controlada.
No sustituye al DDL del proveedor: antes de cargar datos hay que comparar sus
columnas, restricciones, sufijo y SRID con `DBMS_METADATA.GET_DDL`.

## 1. Crear las tablas de perfiles

Ejecutar con el usuario y los privilegios indicados por Oracle:

```sql
BEGIN
  MDSYS.SDO_GCDR.CREATE_PROFILE_TABLES;
END;
/
```

Comprobar el resultado:

```sql
SELECT table_name
FROM user_tables
WHERE table_name IN (
  'GC_COUNTRY_PROFILE',
  'GC_PARSER_PROFILES',
  'GC_PARSER_PROFILEAFS'
)
ORDER BY table_name;
```

El paquete puede crear las tablas de perfiles en el esquema esperado por la
instalación. Si el procedimiento no existe, falla por privilegios o crea los
objetos en otro esquema, hay que seguir el procedimiento de instalación
indicado por Oracle; no se deben recrear manualmente con `CREATE TABLE`.

## 2. Instalar el perfil y los datos de España

El orden recomendado es:

1. Instalar Oracle Spatial/Geocoder y sus objetos auxiliares.
2. Crear las tablas de perfiles mediante `MDSYS.SDO_GCDR.CREATE_PROFILE_TABLES`
   o el script oficial equivalente.
3. Ejecutar el script oficial de configuración del país España, si lo
   proporciona la distribución.
4. Cargar el dataset oficial de España, que debe crear y poblar las tablas
   `GC_*_ES`, sus secuencias, índices, restricciones, metadatos espaciales y
   objetos auxiliares.
5. Confirmar que el código de país utilizado es `ES`.
6. Configurar o asociar el perfil español del parser según la documentación
   de la versión instalada.
7. Validar el parser y la geocodificación antes de cargar los datos propios.

Los perfiles de lenguaje deben cubrir, como mínimo, el idioma español, los
tipos y abreviaturas de vía, la normalización de acentos, alias, separadores y
las reglas de entrada del parser. No asumir que `SPA`, `ES` o un nombre
concreto de perfil son valores válidos: deben comprobarse en la instalación.

Consultas de comprobación:

```sql
SELECT *
FROM gc_country_profile
WHERE country_code_2 = 'ES';

SELECT *
FROM gc_parser_profiles
WHERE country_code_2 = 'ES';

SELECT *
FROM gc_parser_profileafs
WHERE country_code_2 = 'ES';
```

## 3. Tablas de datos españolas

Las tablas de datos normalmente representan estas entidades:

| Objeto | Contenido |
|---|---|
| `GC_AREA_ES` | Áreas administrativas y poblaciones |
| `GC_ROAD_ES` | Viales normalizados |
| `GC_ROAD_SEGMENT_ES` | Segmentos, geometrías y rangos de numeración |
| `GC_ADDRESS_POINT_ES` | Portales o puntos de dirección, si el dataset los incluye |
| `GC_POSTAL_CODE_ES` | Códigos postales y sus relaciones |
| `GC_POI_ES` | Puntos de interés |
| `GC_INTERSECTION_ES` | Intersecciones, si el dataset las incluye |

El flujo de carga de este repositorio utiliza esas entidades como destino,
pero no debe asumir que sus columnas coinciden con las tablas canónicas
`STG_GC_*_ES`. La correspondencia se debe definir en
`sql/04_load_gc_es_adapter.sql` después de inspeccionar el DDL real.

## 4. Modelo conceptual no ejecutable

Las siguientes columnas son únicamente orientativas y pueden variar en
nombre, longitud, tipo, nulabilidad, claves e índices:

```text
GC_ROAD_ES:
  ROAD_ID, ROAD_NAME, ROAD_TYPE, ROAD_PREFIX, ROAD_SUFFIX,
  SETTLEMENT_ID, MUNICIPALITY_ID, POSTAL_CODE,
  COUNTRY_CODE_2, PARTITION_ID

GC_ROAD_SEGMENT_ES:
  ROAD_SEGMENT_ID, ROAD_ID, L_ADDR_FORMAT, R_ADDR_FORMAT,
  L_ADDR_SCHEME, R_ADDR_SCHEME, START_HN, END_HN,
  L_START_HN, L_END_HN, R_START_HN, R_END_HN,
  START_LONG, START_LAT, END_LONG, END_LAT,
  COUNTRY_CODE_2, PARTITION_ID

GC_AREA_ES:
  AREA_ID, AREA_NAME, REAL_NAME, AREA_TYPE, PARENT_AREA_ID,
  LEVEL1_AREA_ID ... LEVEL7_AREA_ID, CENTER_LONG, CENTER_LAT,
  ROAD_SEGMENT_ID, POSTAL_CODE, COUNTRY_CODE_2, PARTITION_ID

GC_INTERSECTION_ES:
  INTERSECTION_ID, ROAD_ID_1, ROAD_SEGMENT_ID_1,
  ROAD_ID_2, ROAD_SEGMENT_ID_2, INTS_LONG, INTS_LAT,
  HOUSE_NUMBER, HOUSE_NUMBER_2, SIDE,
  COUNTRY_CODE_2, PARTITION_ID

GC_POI_ES:
  POI_ID, POI_NAME, POI_TYPE, ADDRESS, AREA_ID, ROAD_ID,
  ROAD_SEGMENT_ID, HOUSE_NUMBER, POSTAL_CODE,
  LONGITUDE, LATITUDE, COUNTRY_CODE_2, PARTITION_ID

GC_POSTAL_CODE_ES:
  POSTAL_CODE, AREA_ID, ROAD_SEGMENT_ID, CENTER_LONG, CENTER_LAT,
  COUNTRY_CODE_2, PARTITION_ID
```

Este bloque no incluye `CREATE TABLE` deliberadamente. Ejecutarlo sin
contrastar el dataset oficial puede producir un esquema incompatible con el
parser, las relaciones o los procedimientos del Geocoder.

## 5. Obtener el DDL de una instalación existente

### 5.1. Consultar columnas y tipos

Sustituir `GEOCODER` por el propietario real:

```sql
SELECT table_name,
       column_id,
       column_name,
       data_type,
       data_length,
       data_precision,
       data_scale,
       nullable
FROM all_tab_columns
WHERE owner = 'GEOCODER'
  AND table_name IN (
    'GC_ROAD_ES',
    'GC_ROAD_SEGMENT_ES',
    'GC_AREA_ES',
    'GC_INTERSECTION_ES',
    'GC_ADDRESS_POINT_ES',
    'GC_POI_ES',
    'GC_POSTAL_CODE_ES',
    'GC_COUNTRY_PROFILE',
    'GC_PARSER_PROFILES',
    'GC_PARSER_PROFILEAFS'
  )
ORDER BY table_name, column_id;
```

### 5.2. Extraer DDL con `DBMS_METADATA`

```sql
SET LONG 1000000
SET PAGESIZE 0
SET LINESIZE 300

SELECT DBMS_METADATA.GET_DDL('TABLE', table_name, owner)
FROM all_tables
WHERE owner = 'GEOCODER'
  AND table_name IN (
    'GC_ROAD_ES',
    'GC_ROAD_SEGMENT_ES',
    'GC_AREA_ES',
    'GC_INTERSECTION_ES',
    'GC_ADDRESS_POINT_ES',
    'GC_POI_ES',
    'GC_POSTAL_CODE_ES',
    'GC_COUNTRY_PROFILE',
    'GC_PARSER_PROFILES',
    'GC_PARSER_PROFILEAFS'
  );
```

También revisar:

```sql
SELECT * FROM all_constraints
WHERE owner = 'GEOCODER'
  AND table_name LIKE 'GC%';

SELECT * FROM all_indexes
WHERE owner = 'GEOCODER'
  AND table_name LIKE 'GC%';
```

Para objetos espaciales, revisar además `ALL_SDO_GEOM_METADATA` y los índices
espaciales instalados.

### 5.3. Exportar un esquema existente

Si se dispone de acceso al servidor Oracle, se puede exportar el esquema y
generar un archivo SQL sin datos:

```bash
expdp system/"password" \
  schemas=GEOCODER \
  include=TABLE \
  include=INDEX \
  include=SEQUENCE \
  directory=DATA_PUMP_DIR \
  dumpfile=geocoder_es.dmp \
  logfile=geocoder_es_exp.log

impdp system/"password" \
  directory=DATA_PUMP_DIR \
  dumpfile=geocoder_es.dmp \
  sqlfile=geocoder_es.sql \
  logfile=geocoder_es_sql.log
```

No guardar contraseñas, credenciales, dumps ni logs sensibles en el
repositorio. El DDL oficial incorporado al proyecto debe conservarse, si se
autoriza su distribución, bajo `sql/oracle_official/`.

## 6. Integración con este ETL

Después de crear y validar el perfil español:

1. Ejecutar `sql/01_create_staging.sql`.
2. Preparar y convertir las fuentes con los scripts de `scripts/`.
3. Cargar las fuentes de origen con `scripts/02_load_staging.sh`.
4. Ejecutar `sql/02_transform_staging.sql`.
5. Ejecutar `sql/03_validate_staging.sql`.
6. Comparar las columnas reales de `GC_*_ES` con las tablas `STG_GC_*_ES`.
7. Completar `sql/04_load_gc_es_adapter.sql` con el mapeo explícito.
8. Cargar en el orden requerido por las claves y relaciones del dataset:
   áreas, viales, segmentos, portales, códigos postales y POI.
9. Ejecutar los procedimientos oficiales de mantenimiento e indexación.
10. Probar consultas de geocodificación en español y documentar el perfil
    utilizado.

Las tablas `STG_GC_*_ES` de este repositorio son staging y no sustituyen a las
tablas oficiales del Geocoder.
