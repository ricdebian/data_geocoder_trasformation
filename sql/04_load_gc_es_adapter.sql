-- Carga STG_GC_*_ES en los objetos GC_*_ES definidos en
-- complemento_objetos_gc_oracle.sql.
--
-- Este adaptador asume exactamente estas columnas de destino:
--   GC_AREA_ES(AREA_ID, PARENT_AREA_ID, AREA_NAME, ADMIN_LEVEL,
--              SETTLEMENT_TYPE)
--   GC_POSTAL_CODE_ES(POSTAL_CODE_ID, POSTAL_CODE, AREA_ID)
--   GC_ROAD_ES(ROAD_ID, ROAD_NAME, ROAD_PREFIX, ROAD_SUFFIX, ROAD_TYPE)
--   GC_ROAD_SEGMENT_ES(ROAD_SEGMENT_ID, ROAD_ID, POSTAL_CODE_ID, AREA_ID,
--                      LEFT_FROM_NUMBER, LEFT_TO_NUMBER,
--                      RIGHT_FROM_NUMBER, RIGHT_TO_NUMBER, GEOMETRY)
--   GC_ADDRESS_POINT_ES(ADDRESS_POINT_ID, ROAD_SEGMENT_ID, HOUSE_NUMBER,
--                       SIDE, PERCENT, GEOMETRY)
--   GC_POI_ES(POI_ID, POI_NAME, AREA_ID, POSTAL_CODE_ID, GEOMETRY)
--
-- El script no crea ni modifica el DDL de GC_*_ES. Los identificadores se
-- asignan con MAX(ID) + ROW_NUMBER(); ejecutar el script en una ventana de
-- carga exclusiva para evitar colisiones con otra carga concurrente.

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET DEFINE OFF

BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE GLOBAL TEMPORARY TABLE STG_GC_LOAD_AREA_MAP (
      SOURCE_ID VARCHAR2(100) PRIMARY KEY,
      AREA_ID NUMBER NOT NULL
    ) ON COMMIT PRESERVE ROWS]';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -955 THEN RAISE; END IF;
END;
/

BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE GLOBAL TEMPORARY TABLE STG_GC_LOAD_ROAD_MAP (
      SOURCE_ID VARCHAR2(100) PRIMARY KEY,
      ROAD_ID NUMBER NOT NULL
    ) ON COMMIT PRESERVE ROWS]';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -955 THEN RAISE; END IF;
END;
/

BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE GLOBAL TEMPORARY TABLE STG_GC_LOAD_POSTAL_MAP (
      POSTAL_CODE VARCHAR2(16) NOT NULL,
      AREA_ID NUMBER,
      POSTAL_CODE_ID NUMBER NOT NULL,
      CONSTRAINT STG_GC_LOAD_POSTAL_UK UNIQUE (POSTAL_CODE, AREA_ID)
    ) ON COMMIT PRESERVE ROWS]';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -955 THEN RAISE; END IF;
END;
/

BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE GLOBAL TEMPORARY TABLE STG_GC_LOAD_SEGMENT_MAP (
      SOURCE_ID VARCHAR2(100) PRIMARY KEY,
      ROAD_SEGMENT_ID NUMBER NOT NULL
    ) ON COMMIT PRESERVE ROWS]';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -955 THEN RAISE; END IF;
END;
/

TRUNCATE TABLE STG_GC_LOAD_AREA_MAP;
TRUNCATE TABLE STG_GC_LOAD_ROAD_MAP;
TRUNCATE TABLE STG_GC_LOAD_POSTAL_MAP;
TRUNCATE TABLE STG_GC_LOAD_SEGMENT_MAP;







TRUNCATE TABLE GC_POI_ES;
TRUNCATE TABLE GC_ADDRESS_POINT_ES;
TRUNCATE TABLE GC_ROAD_SEGMENT_ES;
TRUNCATE TABLE GC_POSTAL_CODE_ES;
TRUNCATE TABLE GC_ROAD_SEGMENT_ES;
TRUNCATE TABLE GC_ROAD_ES;
TRUNCATE TABLE GC_AREA_ES;


-- 1. Áreas: los niveles 1-4 se derivan del tipo de área disponible en OSM.
PROMPT INSERTANDO EN STG_GC_LOAD_AREA_MAP
INSERT INTO STG_GC_LOAD_AREA_MAP (SOURCE_ID, AREA_ID)
WITH source_areas AS (
  SELECT source_id, area_type, name, parent_source_id,
         CASE
           WHEN UPPER(area_type) LIKE '%COUNTRY%' THEN 1
           WHEN UPPER(area_type) LIKE '%STATE%'
             OR UPPER(area_type) LIKE '%REGION%' THEN 2
           WHEN UPPER(area_type) LIKE '%COUNTY%'
             OR UPPER(area_type) LIKE '%PROVINCE%' THEN 3
           WHEN UPPER(area_type) LIKE '%ADMIN_LEVEL8%' THEN 3
           ELSE 4
         END AS admin_level,
         ROW_NUMBER() OVER (ORDER BY source_id) AS source_rn
  FROM (
    SELECT DISTINCT source_id, area_type, name, parent_source_id
    FROM STG_GC_AREA_ES
    WHERE source_id IS NOT NULL
      AND name IS NOT NULL
  )
),
numbered AS (
  SELECT source_id,
         NVL((SELECT MAX(area_id) FROM GC_AREA_ES), 0) + source_rn AS new_area_id,
         name,
         admin_level
  FROM source_areas
)
SELECT s.source_id,
       NVL(existing.area_id, n.new_area_id)
FROM source_areas s
JOIN numbered n ON n.source_id = s.source_id
LEFT JOIN GC_AREA_ES existing
  ON existing.admin_level = s.admin_level
 AND UPPER(TRIM(existing.area_name)) = UPPER(TRIM(s.name));
COMMIT;


PROMPT INSERTANDO EN GC_AREA_ES
INSERT INTO GC_AREA_ES (AREA_ID, PARENT_AREA_ID, AREA_NAME, ADMIN_LEVEL, SETTLEMENT_TYPE)
SELECT m.area_id,
       parent_map.area_id,
       SUBSTR(s.name, 1, 128),
       CASE
         WHEN UPPER(s.area_type) LIKE '%COUNTRY%' THEN 1
         WHEN UPPER(s.area_type) LIKE '%STATE%'
           OR UPPER(s.area_type) LIKE '%REGION%' THEN 2
         WHEN UPPER(s.area_type) LIKE '%COUNTY%'
           OR UPPER(s.area_type) LIKE '%PROVINCE%' THEN 3
         WHEN UPPER(s.area_type) LIKE '%ADMIN_LEVEL8%' THEN 3
         ELSE 4
       END,
       CASE
         WHEN UPPER(s.area_type) LIKE '%CITY%'
           OR UPPER(s.area_type) LIKE '%TOWN%'
           OR UPPER(s.area_type) LIKE '%VILLAGE%' THEN SUBSTR(s.area_type, 1, 32)
         ELSE NULL
       END
FROM STG_GC_AREA_ES s
JOIN STG_GC_LOAD_AREA_MAP m ON m.source_id = s.source_id
LEFT JOIN STG_GC_LOAD_AREA_MAP parent_map
  ON parent_map.source_id = s.parent_source_id
WHERE s.source_id IS NOT NULL
  AND s.name IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM GC_AREA_ES existing
    WHERE existing.area_id = m.area_id
  );
COMMIT;
-- 2. Viales.
PROMPT INSERTANDO EN STG_GC_LOAD_ROAD_MAP
INSERT INTO STG_GC_LOAD_ROAD_MAP (SOURCE_ID, ROAD_ID)
WITH source_roads AS (
  SELECT source_id, name, ref, class_name,
         ROW_NUMBER() OVER (ORDER BY source_id) AS source_rn
  FROM (
    SELECT DISTINCT source_id, name, ref, class_name
    FROM STG_GC_ROAD_ES
    WHERE source_id IS NOT NULL
      AND name IS NOT NULL
  )
),
numbered AS (
  SELECT source_id,
         NVL((SELECT MAX(road_id) FROM GC_ROAD_ES), 0) + source_rn AS new_road_id
  FROM source_roads
)
SELECT s.source_id,
       NVL(existing.road_id, n.new_road_id)
FROM source_roads s
JOIN numbered n ON n.source_id = s.source_id
LEFT JOIN GC_ROAD_ES existing
  ON UPPER(TRIM(existing.road_name)) = UPPER(TRIM(s.name))
 AND NVL(UPPER(TRIM(existing.road_type)), '#') =
     NVL(UPPER(TRIM(s.class_name)), '#');
COMMIT;

PROMPT INSERTANDO EN GC_ROAD_ES
INSERT INTO GC_ROAD_ES (ROAD_ID, ROAD_NAME, ROAD_PREFIX, ROAD_SUFFIX, ROAD_TYPE)
SELECT m.road_id,
       SUBSTR(s.name, 1, 128),
       SUBSTR(s.street_type, 1, 32),
       NULL,
       SUBSTR(s.class_name, 1, 32)
FROM STG_GC_ROAD_ES s
JOIN STG_GC_LOAD_ROAD_MAP m ON m.source_id = s.source_id
WHERE s.source_id IS NOT NULL
  AND s.name IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM GC_ROAD_ES existing
    WHERE existing.road_id = m.road_id
  );
COMMIT;
-- 3. Códigos postales asociados al municipio cuando existe coincidencia.
PROMPT INSERTANDO EN STG_GC_LOAD_POSTAL_MAP

INSERT INTO STG_GC_LOAD_POSTAL_MAP (POSTAL_CODE, AREA_ID, POSTAL_CODE_ID)
WITH source_postals AS (
  SELECT DISTINCT
         a.postal_code,
         area.area_id
  FROM STG_GC_ADDRESS_POINT_ES a
  LEFT JOIN GC_AREA_ES area
    ON area.admin_level = 3
   AND UPPER(TRIM(area.area_name)) = UPPER(TRIM(a.municipality_name))
  WHERE a.postal_code IS NOT NULL
),
numbered AS (
  SELECT postal_code, area_id,
         ROW_NUMBER() OVER (ORDER BY postal_code, area_id) AS source_rn
  FROM source_postals
)
SELECT s.postal_code,
       s.area_id,
       NVL(existing.postal_code_id,
           NVL((SELECT MAX(postal_code_id) FROM GC_POSTAL_CODE_ES), 0)
           + n.source_rn)
FROM source_postals s
JOIN numbered n
  ON n.postal_code = s.postal_code
 AND NVL(n.area_id, -1) = NVL(s.area_id, -1)
LEFT JOIN GC_POSTAL_CODE_ES existing
  ON existing.postal_code = s.postal_code
 AND NVL(existing.area_id, -1) = NVL(s.area_id, -1);
COMMIT;
 
PROMPT INSERTANDO EN GC_POSTAL_CODE_ES

INSERT INTO GC_POSTAL_CODE_ES (POSTAL_CODE_ID, POSTAL_CODE, AREA_ID)
SELECT m.postal_code_id, m.postal_code, m.area_id
FROM STG_GC_LOAD_POSTAL_MAP m
WHERE NOT EXISTS (
  SELECT 1
  FROM GC_POSTAL_CODE_ES existing
  WHERE existing.postal_code_id = m.postal_code_id
);
COMMIT;
-- 4. Segmentos. Si la fuente de segmentos no se ha cargado, no se generan
-- filas: GC_ADDRESS_POINT_ES exige una relación válida con un segmento.
PROMPT INSERTANDO EN STG_GC_LOAD_SEGMENT_MAP

INSERT INTO STG_GC_LOAD_SEGMENT_MAP (SOURCE_ID, ROAD_SEGMENT_ID)
WITH ranked_source_segments AS (
  SELECT source_id, road_source_id, left_from, left_to, right_from, right_to,
         geom,
         ROW_NUMBER() OVER (
           PARTITION BY source_id
           ORDER BY road_source_id, left_from, left_to,
                    right_from, right_to
         ) AS duplicate_rn
  FROM STG_GC_ROAD_SEGMENT_ES
  WHERE source_id IS NOT NULL
    AND geom IS NOT NULL
),
source_segments AS (
  SELECT source_id, road_source_id, left_from, left_to, right_from, right_to,
         geom,
         ROW_NUMBER() OVER (ORDER BY source_id) AS source_rn
  FROM ranked_source_segments
  WHERE duplicate_rn = 1
),
numbered AS (
  SELECT matched.source_id,
         CASE
           WHEN matched.existing_road_segment_id IS NOT NULL
            AND matched.existing_rn = 1
           THEN matched.existing_road_segment_id
           ELSE NVL((SELECT MAX(road_segment_id) FROM GC_ROAD_SEGMENT_ES), 0)
                + matched.source_rn
         END AS new_segment_id
  FROM (
    SELECT s.source_id,
           ROW_NUMBER() OVER (ORDER BY s.source_id) AS source_rn,
           existing.road_segment_id AS existing_road_segment_id,
           ROW_NUMBER() OVER (
             PARTITION BY existing.road_segment_id
             ORDER BY s.source_id
           ) AS existing_rn
    FROM source_segments s
    JOIN STG_GC_LOAD_ROAD_MAP road_map
      ON road_map.source_id = s.road_source_id
    LEFT JOIN GC_ROAD_SEGMENT_ES existing
      ON existing.road_id = road_map.road_id
     AND NVL(existing.left_from_number, '#') = NVL(s.left_from, '#')
     AND NVL(existing.left_to_number, '#') = NVL(s.left_to, '#')
     AND NVL(existing.right_from_number, '#') = NVL(s.right_from, '#')
     AND NVL(existing.right_to_number, '#') = NVL(s.right_to, '#')
     AND SDO_EQUAL(existing.geometry, s.geom) = 'TRUE'
  ) matched
)
SELECT s.source_id,
       n.new_segment_id
FROM source_segments s
JOIN numbered n ON n.source_id = s.source_id
;
COMMIT;
--select * from STG_GC_LOAD_SEGMENT_MAP r
--where r.geom.sdo_srid  <> 4258 4326
PROMPT INSERTANDO EN GC_ROAD_SEGMENT_ES

INSERT INTO GC_ROAD_SEGMENT_ES (
  ROAD_SEGMENT_ID, ROAD_ID, POSTAL_CODE_ID, AREA_ID,
  LEFT_FROM_NUMBER, LEFT_TO_NUMBER, RIGHT_FROM_NUMBER, RIGHT_TO_NUMBER, GEOMETRY
)
WITH ranked_source_segments AS (
  SELECT s.*,
         ROW_NUMBER() OVER (
           PARTITION BY s.source_id
           ORDER BY s.road_source_id, s.left_from, s.left_to,
                    s.right_from, s.right_to
         ) AS duplicate_rn
  FROM STG_GC_ROAD_SEGMENT_ES s
  WHERE s.source_id IS NOT NULL
    AND s.geom IS NOT NULL
),
source_segments AS (
  SELECT *
  FROM ranked_source_segments
  WHERE duplicate_rn = 1
),
segment_addresses AS (
  SELECT s.source_id AS segment_source_id,
         a.postal_code,
         a.municipality_name,
         ROW_NUMBER() OVER (
           PARTITION BY s.source_id
           ORDER BY SDO_DISTANCE(s.geom, a.geom)
         ) AS address_rn
  FROM source_segments s
  JOIN STG_GC_ROAD_ES source_road
    ON source_road.source_id = s.road_source_id
  JOIN STG_GC_ADDRESS_POINT_ES a
    ON UPPER(TRIM(source_road.name)) = UPPER(TRIM(a.street_name))
   AND a.geom IS NOT NULL
  WHERE a.postal_code IS NOT NULL
    AND a.municipality_name IS NOT NULL
),
segment_context AS (
  SELECT sa.segment_source_id,
         postal.postal_code_id,
         area.area_id
  FROM segment_addresses sa
  LEFT JOIN GC_AREA_ES area
    ON area.admin_level = 3
   AND UPPER(TRIM(area.area_name)) = UPPER(TRIM(sa.municipality_name))
  LEFT JOIN GC_POSTAL_CODE_ES postal
    ON postal.postal_code = sa.postal_code
   AND NVL(postal.area_id, -1) = NVL(area.area_id, -1)
  WHERE sa.address_rn = 1
)
SELECT m.road_segment_id,
       road_map.road_id,
       context.postal_code_id,
       context.area_id,
       SUBSTR(s.left_from, 1, 16),
       SUBSTR(s.left_to, 1, 16),
       SUBSTR(s.right_from, 1, 16),
       SUBSTR(s.right_to, 1, 16),
       SDO_CS.TRANSFORM(s.geom, 4326) geom
FROM source_segments s
JOIN STG_GC_LOAD_SEGMENT_MAP m ON m.source_id = s.source_id
JOIN STG_GC_LOAD_ROAD_MAP road_map ON road_map.source_id = s.road_source_id
LEFT JOIN segment_context context
  ON context.segment_source_id = s.source_id
WHERE NOT EXISTS (
    SELECT 1
    FROM GC_ROAD_SEGMENT_ES existing
    WHERE existing.road_segment_id = m.road_segment_id
  );
COMMIT;
-- 5. Portales. Solo se cargan los que pueden asociarse a un segmento.
PROMPT INSERTANDO EN GC_ADDRESS_POINT_ES

INSERT INTO GC_ADDRESS_POINT_ES (
  ADDRESS_POINT_ID, ROAD_SEGMENT_ID, HOUSE_NUMBER, SIDE, PERCENT, GEOMETRY
)
WITH candidate_addresses AS (
  SELECT a.source_id,
         segment_map.road_segment_id,
         a.house_number,
         SDO_CS.TRANSFORM(a.geom, 4326) geom,
         ROW_NUMBER() OVER (
           PARTITION BY a.source_id
           ORDER BY segment_map.road_segment_id
         ) AS match_rn
  FROM STG_GC_ADDRESS_POINT_ES a
  JOIN STG_GC_ROAD_ES source_road
    ON UPPER(TRIM(source_road.name)) = UPPER(TRIM(a.street_name))
  JOIN STG_GC_ROAD_SEGMENT_ES source_segment
    ON source_segment.road_source_id = source_road.source_id
  JOIN STG_GC_LOAD_SEGMENT_MAP segment_map
    ON segment_map.source_id = source_segment.source_id
  WHERE a.source_id IS NOT NULL
    AND a.house_number IS NOT NULL
    AND a.geom IS NOT NULL
),
new_addresses AS (
  SELECT c.*,
         ROW_NUMBER() OVER (ORDER BY c.source_id) AS source_rn
  FROM candidate_addresses c
  WHERE c.match_rn = 1
    AND NOT EXISTS (
      SELECT 1
      FROM GC_ADDRESS_POINT_ES existing
      WHERE existing.road_segment_id = c.road_segment_id
        AND NVL(existing.house_number, '#') = NVL(c.house_number, '#')
    )
)
SELECT NVL((SELECT MAX(address_point_id) FROM GC_ADDRESS_POINT_ES), 0)
       + source_rn,
       road_segment_id,
       SUBSTR(house_number, 1, 32),
       NULL,
       NULL,
        SDO_CS.TRANSFORM(geom, 4326) geom
FROM new_addresses;
COMMIT;
-- 6. Puntos de interés. Se asignan las relaciones administrativas mediante
-- el portal CartoCiudad más próximo con código postal y municipio.
PROMPT INSERTANDO EN GC_POI_ES

INSERT INTO GC_POI_ES (POI_ID, POI_NAME, AREA_ID, POSTAL_CODE_ID, GEOMETRY)
WITH source_pois AS (
  SELECT p.source_id, p.name, p.geom,
         ROW_NUMBER() OVER (ORDER BY p.source_id) AS source_rn
  FROM STG_GC_POI_ES p
  WHERE p.source_id IS NOT NULL
    AND p.name IS NOT NULL
    AND p.geom IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM GC_POI_ES existing
      WHERE UPPER(TRIM(existing.poi_name)) = UPPER(TRIM(p.name))
    )
),
poi_addresses AS (
  SELECT p.source_id AS poi_source_id,
         a.postal_code,
         a.municipality_name,
         ROW_NUMBER() OVER (
           PARTITION BY p.source_id
           ORDER BY SDO_DISTANCE(p.geom, a.geom)
         ) AS address_rn
  FROM source_pois p
  JOIN STG_GC_ADDRESS_POINT_ES a
    ON a.geom IS NOT NULL
   AND a.postal_code IS NOT NULL
   AND a.municipality_name IS NOT NULL
),
poi_context AS (
  SELECT pa.poi_source_id,
         area.area_id,
         postal.postal_code_id
  FROM poi_addresses pa
  LEFT JOIN GC_AREA_ES area
    ON area.admin_level = 3
   AND UPPER(TRIM(area.area_name)) = UPPER(TRIM(pa.municipality_name))
  LEFT JOIN GC_POSTAL_CODE_ES postal
    ON postal.postal_code = pa.postal_code
   AND NVL(postal.area_id, -1) = NVL(area.area_id, -1)
  WHERE pa.address_rn = 1
)
SELECT NVL((SELECT MAX(poi_id) FROM GC_POI_ES), 0) + source_rn,
       SUBSTR(name, 1, 256),
       context.area_id,
       context.postal_code_id,
       SDO_CS.TRANSFORM(p.geom, 4326) geom
FROM source_pois p
LEFT JOIN poi_context context
  ON context.poi_source_id = p.source_id;
COMMIT;
COMMIT;

--TRUNCATE TABLE STG_GC_LOAD_AREA_MAP;
--TRUNCATE TABLE STG_GC_LOAD_ROAD_MAP;
--TRUNCATE TABLE STG_GC_LOAD_POSTAL_MAP;
--TRUNCATE TABLE STG_GC_LOAD_SEGMENT_MAP;
