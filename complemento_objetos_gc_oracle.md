Sí. En Oracle Spatial 19c, las tablas de datos del geocoder para España deben utilizar el sufijo _ES, por ejemplo GC_ROAD_ES. Sin embargo, Oracle no proporciona una única sentencia CREATE TABLE oficial para instalar los datos de España: las tablas GC_ROAD_ES, GC_ROAD_SEGMENT_ES, GC_AREA_ES, etc. deben cargarse junto con el dataset del geocoder. La documentación oficial define sus columnas y tipos, pero no incluye datos españoles ni un script completo de instalación.
Oracle

Las dos tablas de perfiles sí se crean mediante el paquete de Oracle:

sql


BEGIN
  MDSYS.SDO_GCDR.CREATE_PROFILE_TABLES;
END;
/
Esto crea las tablas:

sql


GC_COUNTRY_PROFILE
GC_PARSER_PROFILES
GC_PARSER_PROFILEAFS
Compruébalo con:

sql


SELECT table_name
FROM user_tables
WHERE table_name IN (
  'GC_COUNTRY_PROFILE',
  'GC_PARSER_PROFILES',
  'GC_PARSER_PROFILEAFS'
)
ORDER BY table_name;
Para España, el código de país debe ser:

text


ES
Puedes comprobar si existen perfiles españoles:

sql


SELECT *
FROM gc_country_profile
WHERE country_code_2 = 'ES';

SELECT *
FROM gc_parser_profiles
WHERE country_code_2 = 'ES';

SELECT *
FROM gc_parser_profileafs
WHERE country_code_2 = 'ES';
Tablas de datos del perfil ES
Los nombres esperados serían:

text


GC_ROAD_ES
GC_ROAD_SEGMENT_ES
GC_AREA_ES
GC_INTERSECTION_ES
GC_POI_ES
GC_POSTAL_CODE_ES
Las sentencias conceptuales son:

sql


CREATE TABLE GC_ROAD_ES (
  ROAD_ID              NUMBER,
  ROAD_NAME            VARCHAR2(64),
  ROAD_TYPE            VARCHAR2(32),
  ROAD_PREFIX          VARCHAR2(32),
  ROAD_SUFFIX          VARCHAR2(32),
  SETTLEMENT_ID        NUMBER,
  MUNICIPALITY_ID      NUMBER,
  POSTAL_CODE          VARCHAR2(16),
  COUNTRY_CODE_2       VARCHAR2(2),
  PARTITION_ID         NUMBER
);
sql


CREATE TABLE GC_ROAD_SEGMENT_ES (
  ROAD_SEGMENT_ID      NUMBER,
  ROAD_ID              NUMBER,
  L_ADDR_FORMAT        VARCHAR2(1),
  R_ADDR_FORMAT        VARCHAR2(1),
  L_ADDR_SCHEME        VARCHAR2(1),
  R_ADDR_SCHEME        VARCHAR2(1),
  START_HN             NUMBER(5),
  END_HN               NUMBER(5),
  L_START_HN           NUMBER(5),
  L_END_HN             NUMBER(5),
  R_START_HN           NUMBER(5),
  R_END_HN             NUMBER(5),
  L_START_HN2          VARCHAR2(10),
  L_END_HN2            VARCHAR2(10),
  R_START_HN2          VARCHAR2(10),
  R_END_HN2            VARCHAR2(10),
  START_LONG           NUMBER,
  START_LAT            NUMBER,
  END_LONG             NUMBER,
  END_LAT              NUMBER,
  COUNTRY_CODE_2       VARCHAR2(2),
  PARTITION_ID         NUMBER
);
sql


CREATE TABLE GC_AREA_ES (
  AREA_ID              NUMBER,
  AREA_NAME            VARCHAR2(64),
  REAL_NAME            VARCHAR2(64),
  AREA_TYPE             VARCHAR2(32),
  PARENT_AREA_ID       NUMBER,
  LEVEL1_AREA_ID       NUMBER,
  LEVEL2_AREA_ID       NUMBER,
  LEVEL3_AREA_ID       NUMBER,
  LEVEL4_AREA_ID       NUMBER,
  LEVEL5_AREA_ID       NUMBER,
  LEVEL6_AREA_ID       NUMBER,
  LEVEL7_AREA_ID       NUMBER,
  CENTER_LONG          NUMBER,
  CENTER_LAT           NUMBER,
  ROAD_SEGMENT_ID      NUMBER(10),
  POSTAL_CODE          VARCHAR2(16),
  COUNTRY_CODE_2       VARCHAR2(2),
  PARTITION_ID         NUMBER
);
sql


CREATE TABLE GC_INTERSECTION_ES (
  INTERSECTION_ID      NUMBER,
  ROAD_ID_1            NUMBER,
  ROAD_SEGMENT_ID_1    NUMBER,
  ROAD_ID_2            NUMBER,
  ROAD_SEGMENT_ID_2    NUMBER,
  INTS_LONG            NUMBER,
  INTS_LAT             NUMBER,
  HOUSE_NUMBER         NUMBER,
  HOUSE_NUMBER_2       VARCHAR2(10),
  SIDE                 VARCHAR2(1),
  COUNTRY_CODE_2       VARCHAR2(2),
  PARTITION_ID         NUMBER
);
sql


CREATE TABLE GC_POI_ES (
  POI_ID               NUMBER,
  POI_NAME             VARCHAR2(128),
  POI_TYPE             VARCHAR2(64),
  ADDRESS              VARCHAR2(256),
  AREA_ID              NUMBER,
  ROAD_ID              NUMBER,
  ROAD_SEGMENT_ID      NUMBER,
  HOUSE_NUMBER         NUMBER,
  POSTAL_CODE          VARCHAR2(16),
  LONGITUDE            NUMBER,
  LATITUDE             NUMBER,
  COUNTRY_CODE_2       VARCHAR2(2),
  PARTITION_ID         NUMBER
);
sql


CREATE TABLE GC_POSTAL_CODE_ES (
  POSTAL_CODE          VARCHAR2(16),
  AREA_ID              NUMBER,
  ROAD_SEGMENT_ID      NUMBER,
  CENTER_LONG          NUMBER,
  CENTER_LAT           NUMBER,
  COUNTRY_CODE_2       VARCHAR2(2),
  PARTITION_ID         NUMBER
);
Pero estas sentencias no deben utilizarse como script final de instalación. Los nombres de columnas y sus longitudes exactas dependen de la versión del dataset y del proveedor. Por ejemplo, GC_ROAD_SEGMENT_<suffix> contiene información de rangos de numeración, esquemas pares/impares y segmentos de calle; Oracle exige que esos atributos sean coherentes con las tablas relacionadas.
Oracle

Obtener el DDL exacto de una instalación existente
Si tienes una base de datos donde ya existe el perfil, la forma correcta de obtener el DDL exacto es:

bash


expdp system/"password" \
  schemas=GEOCODER \
  include=TABLE \
  include=INDEX \
  include=SEQUENCE \
  directory=DATA_PUMP_DIR \
  dumpfile=geocoder_es.dmp \
  logfile=geocoder_es_exp.log
Después puedes generar el SQL con:

bash


impdp system/"password" \
  directory=DATA_PUMP_DIR \
  dumpfile=geocoder_es.dmp \
  sqlfile=geocoder_es.sql \
  logfile=geocoder_es_sql.log
También puedes consultar las columnas directamente:

sql


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
    'GC_POI_ES',
    'GC_POSTAL_CODE_ES',
    'GC_COUNTRY_PROFILE',
    'GC_PARSER_PROFILES',
    'GC_PARSER_PROFILEAFS'
  )
ORDER BY table_name, column_id;
Y generar un DDL aproximado mediante DBMS_METADATA:

sql


SET LONG 1000000
SET PAGESIZE 0
SET LINESIZE 300

SELECT DBMS_METADATA.GET_DDL(
         'TABLE',
         table_name,
         owner
       )
FROM all_tables
WHERE owner = 'GEOCODER'
  AND table_name IN (
    'GC_ROAD_ES',
    'GC_ROAD_SEGMENT_ES',
    'GC_AREA_ES',
    'GC_INTERSECTION_ES',
    'GC_POI_ES',
    'GC_POSTAL_CODE_ES',
    'GC_COUNTRY_PROFILE',
    'GC_PARSER_PROFILES',
    'GC_PARSER_PROFILEAFS'
  );
Sustituye GEOCODER por el propietario real. La creación de GC_COUNTRY_PROFILE, GC_PARSER_PROFILES y GC_PARSER_PROFILEAFS debe hacerse mediante MDSYS.SDO_GCDR.CREATE_PROFILE_TABLES; para las tablas _ES, necesitas el script o el dump del dataset del geocoder de España.
