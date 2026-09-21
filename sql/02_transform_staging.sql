-- Transformación a un modelo canónico de referencia *_ES.
-- STG_CARTO_* y STG_OSM_* son tablas cargadas por 02_load_staging.sh.
-- Las columnas de STG_RT_* pueden variar por edición del producto CNIG y se
-- conservan para el adaptador específico de Redes de Transporte.

TRUNCATE TABLE STG_GC_ADDRESS_POINT_ES;
TRUNCATE TABLE STG_GC_ROAD_ES;
TRUNCATE TABLE STG_GC_ROAD_SEGMENT_ES;
TRUNCATE TABLE STG_GC_AREA_ES;
TRUNCATE TABLE STG_GC_POSTAL_CODE_ES;
TRUNCATE TABLE STG_GC_POI_ES;


INSERT INTO STG_GC_ADDRESS_POINT_ES (
  SOURCE_ID, SOURCE_NAME, STREET_TYPE, STREET_NAME, HOUSE_NUMBER, UNIT,
  PLACE_ID, PLACE_NAME, POSTAL_CODE, MUNICIPALITY_CODE, MUNICIPALITY_NAME,
  PROVINCE_NAME, REGION_NAME, SOURCE_DATE, GEOM
)
SELECT "id_porpk", 'CARTOCIUDAD', "tipo_vial", "nombre_via", "numero", "extension",
       "id_pob", "poblacion", LPAD("cod_postal", 5, '0'), "ine_mun", "municipio",
       "provincia", "comunidad_autonoma", cast(to_timestamp("fecha_modificacion",'YYYY-MM-DD"T"HH24:MI:SS.FF') as timestamp(6)),geom
FROM STG_CARTO_PORTAL
WHERE "id_porpk" IS NOT NULL AND geom IS NOT NULL;

INSERT INTO STG_GC_ROAD_ES (
  SOURCE_ID, SOURCE_NAME, NAME, REF, ONE_WAY, CLASS_NAME, GEOM
)
SELECT "osm_id", 'OSM', "name", "ref", "oneway", "fclass", geom
FROM STG_OSM_ROAD
WHERE "osm_id" IS NOT NULL AND geom IS NOT NULL;

-- Fallback de segmento: cuando Redes de Transporte no se ha normalizado
-- todavía, cada geometría lineal OSM se utiliza como segmento sin rangos.
-- Si existe una transformación específica de STG_RT_*, debe sustituir este
-- bloque para aportar los rangos izquierdo/derecho reales.
INSERT INTO STG_GC_ROAD_SEGMENT_ES (
  SOURCE_ID, SOURCE_NAME, ROAD_SOURCE_ID,
  LEFT_FROM, LEFT_TO, RIGHT_FROM, RIGHT_TO, GEOM
)
SELECT SOURCE_ID, SOURCE_NAME, SOURCE_ID,
       NULL, NULL, NULL, NULL, GEOM
FROM STG_GC_ROAD_ES
WHERE SOURCE_ID IS NOT NULL
  AND GEOM IS NOT NULL;

INSERT INTO STG_GC_POI_ES (SOURCE_ID, SOURCE_NAME, NAME, CLASS_NAME, GEOM)
SELECT "osm_id" "osm_id", 'OSM', p."name", p."fclass",p.geom
FROM STG_OSM_POI p
WHERE p."osm_id" IS NOT NULL AND p.geom IS NOT NULL;

INSERT INTO STG_GC_AREA_ES (SOURCE_ID, SOURCE_NAME, AREA_TYPE, NAME, GEOM)
SELECT "osm_id", 'OSM', "fclass", "name", geom
FROM STG_OSM_AREA
WHERE "osm_id" IS NOT NULL AND geom IS NOT NULL;

INSERT INTO STG_GC_POSTAL_CODE_ES (
  POSTAL_CODE, MUNICIPALITY_CODE, MUNICIPALITY_NAME, SOURCE_NAME
)
SELECT DISTINCT postal_code, municipality_code, municipality_name, 'CARTOCIUDAD'
FROM STG_GC_ADDRESS_POINT_ES
WHERE postal_code IS NOT NULL;

COMMIT;
