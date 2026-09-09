-- Ejemplo de transformación para GC_POSTAL_CODE_ES.
--
-- Basado en la documentación Oracle 26c:
--   POSTAL_CODE       VARCHAR2(16)  obligatorio
--   SETTLEMENT_NAME   VARCHAR2(64)
--   MUNICIPALITY_NAME VARCHAR2(64)
--   REGION_NAME       VARCHAR2(64)
--   LANG_CODE         VARCHAR2(3)   obligatorio
--   SETTLEMENT_ID     NUMBER(10)
--   MUNICIPALITY_ID   NUMBER(10)
--   REGION_ID         NUMBER(10)
--   CENTER_LONG       NUMBER
--   CENTER_LAT        NUMBER
--   ROAD_SEGMENT_ID   NUMBER(10)    obligatorio y no nulo
--
-- Este script prepara una tabla de revisión. No inserta todavía en
-- GC_POSTAL_CODE_ES porque:
--   1. Los IDs de GC_AREA_ES dependen de la carga de áreas.
--   2. ROAD_SEGMENT_ID depende de la transformación de GC_ROAD_SEGMENT_ES.
--   3. El DDL instalado puede añadir restricciones o columnas.
--
-- Suposiciones de este ejemplo:
--   nivel 1 = país, nivel 2 = región, nivel 3 = municipio,
--   nivel 4 = asentamiento/población.

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE STG_GC_POSTAL_CODE_CANDIDATE PURGE';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
      RAISE;
    END IF;
END;
/

CREATE TABLE STG_GC_POSTAL_CODE_CANDIDATE AS
WITH postal_points AS (
  SELECT
    postal_code,
    SUBSTR(place_name, 1, 64) AS settlement_name,
    SUBSTR(municipality_name, 1, 64) AS municipality_name,
    SUBSTR(region_name, 1, 64) AS region_name,
    AVG(geom.sdo_point.x) AS center_long,
    AVG(geom.sdo_point.y) AS center_lat,
    COUNT(*) AS address_point_count
  FROM STG_GC_ADDRESS_POINT_ES
  WHERE postal_code IS NOT NULL
    AND geom IS NOT NULL
    AND geom.sdo_point IS NOT NULL
    AND geom.sdo_point.x IS NOT NULL
    AND geom.sdo_point.y IS NOT NULL
  GROUP BY
    postal_code,
    SUBSTR(place_name, 1, 64),
    SUBSTR(municipality_name, 1, 64),
    SUBSTR(region_name, 1, 64)
)
SELECT
  p.postal_code,
  p.settlement_name,
  p.municipality_name,
  p.region_name,
  'SPA' AS lang_code,
  settlement.area_id AS settlement_id,
  municipality.area_id AS municipality_id,
  region.area_id AS region_id,
  p.center_long,
  p.center_lat,
  CAST(NULL AS NUMBER(10)) AS road_segment_id,
  p.address_point_count,
  CASE
    WHEN settlement.area_id IS NULL THEN 'MISSING_SETTLEMENT'
    WHEN municipality.area_id IS NULL THEN 'MISSING_MUNICIPALITY'
    WHEN region.area_id IS NULL THEN 'MISSING_REGION'
    ELSE 'READY_FOR_SEGMENT_MATCH'
  END AS mapping_status
FROM postal_points p
LEFT JOIN GC_AREA_ES settlement
  ON settlement.admin_level = 4
 AND UPPER(TRIM(settlement.area_name)) = UPPER(TRIM(p.settlement_name))
LEFT JOIN GC_AREA_ES municipality
  ON municipality.admin_level = 3
 AND UPPER(TRIM(municipality.area_name)) = UPPER(TRIM(p.municipality_name))
LEFT JOIN GC_AREA_ES region
  ON region.admin_level = 2
 AND UPPER(TRIM(region.area_name)) = UPPER(TRIM(p.region_name));

COMMENT ON TABLE STG_GC_POSTAL_CODE_CANDIDATE IS
  'Candidatos GC_POSTAL_CODE_ES derivados de CartoCiudad portalpk_publi';

CREATE INDEX STG_GC_POSTAL_CODE_CAND_UK
  ON STG_GC_POSTAL_CODE_CANDIDATE
     (POSTAL_CODE, MUNICIPALITY_NAME, SETTLEMENT_NAME);

-- Revisión antes de la carga:
SELECT mapping_status, COUNT(*) AS rows_count
FROM STG_GC_POSTAL_CODE_CANDIDATE
GROUP BY mapping_status
ORDER BY mapping_status;

-- La carga oficial debe ejecutarse solo después de poblar ROAD_SEGMENT_ID
-- mediante la relación portal -> segmento resuelta en el bloque
-- GC_ROAD_SEGMENT_ES de este script.
--
-- Ejemplo de carga final, una vez validado el DDL y completada la relación:
--
-- INSERT INTO GC_POSTAL_CODE_ES (
--   POSTAL_CODE, SETTLEMENT_NAME, MUNICIPALITY_NAME, REGION_NAME,
--   LANG_CODE, SETTLEMENT_ID, MUNICIPALITY_ID, REGION_ID,
--   CENTER_LONG, CENTER_LAT, ROAD_SEGMENT_ID
-- )
-- SELECT POSTAL_CODE, SETTLEMENT_NAME, MUNICIPALITY_NAME, REGION_NAME,
--        LANG_CODE, SETTLEMENT_ID, MUNICIPALITY_ID, REGION_ID,
--        CENTER_LONG, CENTER_LAT, ROAD_SEGMENT_ID
-- FROM STG_GC_POSTAL_CODE_CANDIDATE
-- WHERE ROAD_SEGMENT_ID IS NOT NULL
--   AND mapping_status = 'READY_FOR_SEGMENT_MATCH';
--
-- COMMIT;

-- ============================================================================
-- Ejemplos de carga para el resto de tablas oficiales GC_*_ES
-- ============================================================================
--
-- Estos bloques son intencionadamente comentarios: las tablas oficiales las
-- crea Oracle y sus columnas pueden variar entre versiones/proveedores.
-- Antes de ejecutarlos:
--   1. comparar las columnas con DBMS_METADATA.GET_DDL;
--   2. completar los identificadores generados por Oracle;
--   3. resolver las relaciones entre áreas, viales, segmentos y portales;
--   4. ejecutar la carga en el orden AREA -> ROAD -> ROAD_SEGMENT ->
--      ADDRESS_POINT -> POSTAL_CODE -> POI.
--
-- Las consultas usan únicamente las tablas canónicas STG_GC_*_ES creadas por
-- 01_create_staging.sql. No sustituyen los procedimientos oficiales de
-- mantenimiento, indexación o actualización del geocoder.

-- ----------------------------------------------------------------------------
-- GC_AREA_ES
-- ----------------------------------------------------------------------------
-- Las áreas se cargan antes que códigos postales y portales para poder
-- resolver sus identificadores administrativos.
--
-- INSERT INTO GC_AREA_ES (
--   AREA_NAME, ADMIN_LEVEL, PARENT_AREA_ID, LANG_CODE, GEOM
-- )
-- SELECT
--   SUBSTR(NAME, 1, 64),
--   CASE
--     WHEN UPPER(AREA_TYPE) LIKE '%COUNTRY%' THEN 1
--     WHEN UPPER(AREA_TYPE) LIKE '%STATE%'
--       OR UPPER(AREA_TYPE) LIKE '%REGION%' THEN 2
--     WHEN UPPER(AREA_TYPE) LIKE '%COUNTY%'
--       OR UPPER(AREA_TYPE) LIKE '%PROVINCE%' THEN 3
--     ELSE 4
--   END,
--   CAST(NULL AS NUMBER(10)),
--   'SPA',
--   GEOM
-- FROM STG_GC_AREA_ES
-- WHERE SOURCE_ID IS NOT NULL
--   AND NAME IS NOT NULL
--   AND GEOM IS NOT NULL;

-- ----------------------------------------------------------------------------
-- GC_ROAD_ES
-- ----------------------------------------------------------------------------
-- La deduplicación debe adaptarse a la clave natural definida por la
-- instalación. SOURCE_ID se conserva como referencia de la fuente.
--
-- INSERT INTO GC_ROAD_ES (
--   ROAD_NAME, STREET_TYPE, REF, CLASS_NAME, LANG_CODE
-- )
-- SELECT
--   SUBSTR(NAME, 1, 64),
--   SUBSTR(STREET_TYPE, 1, 32),
--   SUBSTR(REF, 1, 32),
--   SUBSTR(CLASS_NAME, 1, 32),
--   'SPA'
-- FROM STG_GC_ROAD_ES
-- WHERE SOURCE_ID IS NOT NULL
--   AND NAME IS NOT NULL;

-- ----------------------------------------------------------------------------
-- GC_ROAD_SEGMENT_ES
-- ----------------------------------------------------------------------------
-- LEFT/RIGHT_* son rangos de numeración; si el DDL usa otros nombres,
-- sustituirlos por las columnas equivalentes. ROAD_ID debe resolverse contra
-- el identificador generado al cargar GC_ROAD_ES.
--
-- INSERT INTO GC_ROAD_SEGMENT_ES (
--   ROAD_ID, SEGMENT_GEOMETRY, LEFT_FROM, LEFT_TO,
--   RIGHT_FROM, RIGHT_TO, LANG_CODE
-- )
-- SELECT
--   road.road_id,
--   segment.GEOM,
--   segment.LEFT_FROM,
--   segment.LEFT_TO,
--   segment.RIGHT_FROM,
--   segment.RIGHT_TO,
--   'SPA'
-- FROM STG_GC_ROAD_SEGMENT_ES segment
-- JOIN GC_ROAD_ES road
--   ON road.ROAD_NAME = (
--        SELECT SUBSTR(r.NAME, 1, 64)
--        FROM STG_GC_ROAD_ES r
--        WHERE r.SOURCE_ID = segment.ROAD_SOURCE_ID
--      )
-- WHERE segment.SOURCE_ID IS NOT NULL
--   AND segment.GEOM IS NOT NULL;

-- ----------------------------------------------------------------------------
-- GC_ADDRESS_POINT_ES
-- ----------------------------------------------------------------------------
-- ROAD_ID, ROAD_SEGMENT_ID y los IDs de área deben corresponder a las filas
-- creadas por las cargas anteriores. La condición de emparejamiento de vial
-- debe reforzarse con el identificador de fuente cuando esté disponible.
--
-- INSERT INTO GC_ADDRESS_POINT_ES (
--   SOURCE_ID, ROAD_ID, ROAD_SEGMENT_ID, HOUSE_NUMBER, UNIT,
--   POSTAL_CODE, SETTLEMENT_ID, MUNICIPALITY_ID, REGION_ID,
--   LANG_CODE, GEOM
-- )
-- SELECT
--   address.SOURCE_ID,
--   road.ROAD_ID,
--   segment.ROAD_SEGMENT_ID,
--   address.HOUSE_NUMBER,
--   address.UNIT,
--   address.POSTAL_CODE,
--   settlement.AREA_ID,
--   municipality.AREA_ID,
--   region.AREA_ID,
--   'SPA',
--   address.GEOM
-- FROM STG_GC_ADDRESS_POINT_ES address
-- LEFT JOIN STG_GC_ROAD_ES source_road
--   ON UPPER(TRIM(source_road.NAME)) = UPPER(TRIM(address.STREET_NAME))
-- LEFT JOIN GC_ROAD_ES road
--   ON UPPER(TRIM(road.ROAD_NAME)) = UPPER(TRIM(source_road.NAME))
-- LEFT JOIN GC_ROAD_SEGMENT_ES segment
--   ON segment.SOURCE_ID = address.SOURCE_ID
-- LEFT JOIN GC_AREA_ES settlement
--   ON settlement.ADMIN_LEVEL = 4
--  AND UPPER(TRIM(settlement.AREA_NAME)) =
--      UPPER(TRIM(address.PLACE_NAME))
-- LEFT JOIN GC_AREA_ES municipality
--   ON municipality.ADMIN_LEVEL = 3
--  AND UPPER(TRIM(municipality.AREA_NAME)) =
--      UPPER(TRIM(address.MUNICIPALITY_NAME))
-- LEFT JOIN GC_AREA_ES region
--   ON region.ADMIN_LEVEL = 2
--  AND UPPER(TRIM(region.AREA_NAME)) =
--      UPPER(TRIM(address.REGION_NAME))
-- WHERE address.SOURCE_ID IS NOT NULL
--   AND address.GEOM IS NOT NULL;

-- ----------------------------------------------------------------------------
-- GC_POI_ES
-- ----------------------------------------------------------------------------
-- Los POI son opcionales y se cargan después de validar direcciones y áreas.
--
-- INSERT INTO GC_POI_ES (
--   SOURCE_ID, POI_NAME, CLASS_NAME, LANG_CODE, GEOM
-- )
-- SELECT
--   SOURCE_ID,
--   SUBSTR(NAME, 1, 64),
--   SUBSTR(CLASS_NAME, 1, 32),
--   'SPA',
--   GEOM
-- FROM STG_GC_POI_ES
-- WHERE SOURCE_ID IS NOT NULL
--   AND NAME IS NOT NULL
--   AND GEOM IS NOT NULL;

-- COMMIT;
