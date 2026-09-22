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
       "provincia", "comunidad_autonoma",to_timestamp("fecha_modificacion",'YYYY-MM-DD"T"HH24:MI:SS.FF') ,geom
FROM STG_CARTO_PORTAL
WHERE "id_porpk" IS NOT NULL AND geom IS NOT NULL;

INSERT INTO STG_GC_ROAD_ES (
  SOURCE_ID, SOURCE_NAME, NAME, REF, ONE_WAY, CLASS_NAME, GEOM
)
SELECT "osm_id", 'OSM', "name", "ref", "oneway", "fclass", geom
FROM STG_OSM_ROAD
WHERE "osm_id" IS NOT NULL AND geom IS NOT NULL;

-- Redes de Transporte aporta la geometría de los tramos y relaciona los
-- portales mediante id_tramo. Se usan identificadores prefijados para evitar
-- colisiones con los identificadores de OSM.
INSERT INTO STG_GC_ROAD_ES (
  SOURCE_ID, SOURCE_NAME, NAME, CLASS_NAME
)
SELECT 'RT:VIAL:' || TO_CHAR("id_vial"), 'REDES_TRANSPORTE',
       MAX("nombre"), MAX("tipo_viald")
FROM STG_RT_TRAMO_VIAL
WHERE "id_vial" IS NOT NULL
GROUP BY "id_vial";

-- En la convención de este ETL, los números impares se sitúan a la izquierda
-- y los pares a la derecha siguiendo el sentido creciente del tramo. Solo se
-- consideran números simples (con una letra opcional); valores como S/N o
-- 3-5 no permiten establecer un rango estable y se excluyen.
INSERT INTO STG_GC_ROAD_SEGMENT_ES (
  SOURCE_ID, SOURCE_NAME, ROAD_SOURCE_ID,
  LEFT_FROM, LEFT_TO, RIGHT_FROM, RIGHT_TO, GEOM
)
WITH portal_numbers AS (
  SELECT "id_vial" AS vial_id,
         "id_tramo" AS tramo_id,
         TO_NUMBER(REGEXP_SUBSTR(TRIM("numero"), '^[0-9]+')) AS house_number
  FROM STG_RT_PORTAL
  WHERE "id_vial" IS NOT NULL
    AND "id_tramo" IS NOT NULL
    AND REGEXP_LIKE(TRIM("numero"), '^[0-9]+[[:alpha:]]?$')
),
number_ranges AS (
  SELECT vial_id, tramo_id,
         MIN(CASE WHEN MOD(house_number, 2) = 1 THEN house_number END) AS odd_from,
         MAX(CASE WHEN MOD(house_number, 2) = 1 THEN house_number END) AS odd_to,
         MIN(CASE WHEN MOD(house_number, 2) = 0 THEN house_number END) AS even_from,
         MAX(CASE WHEN MOD(house_number, 2) = 0 THEN house_number END) AS even_to
  FROM portal_numbers
  GROUP BY vial_id, tramo_id
)
SELECT 'RT:TRAMO:' || TO_CHAR(t."id_vial") || ':' || TO_CHAR(t."id_tramo"),
       'REDES_TRANSPORTE',
       'RT:VIAL:' || TO_CHAR(t."id_vial"),
       TO_CHAR(r.odd_from), TO_CHAR(r.odd_to),
       TO_CHAR(r.even_from), TO_CHAR(r.even_to),
       t.geom
FROM STG_RT_TRAMO_VIAL t
LEFT JOIN number_ranges r
  ON r.vial_id = t."id_vial"
 AND r.tramo_id = t."id_tramo"
WHERE t."id_tramo" IS NOT NULL
  AND t.geom IS NOT NULL;

-- Fallback de segmento: cuando Redes de Transporte no se ha normalizado
-- todavía, cada geometría lineal OSM se utiliza como segmento sin rangos.
-- Los rangos izquierdo/derecho no se deben inferir asignando todos los
-- portales de un vial a cada segmento. Si existe una transformación específica
-- de STG_RT_*, debe cargar los rangos reales y sustituir este bloque.
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
