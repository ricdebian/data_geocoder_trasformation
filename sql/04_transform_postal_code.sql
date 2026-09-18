-- Prepara una revisión de códigos postales antes de ejecutar
-- sql/04_load_gc_es_adapter.sql.
--
-- El destino definido en complemento_objetos_gc_oracle.sql solo contiene:
--   GC_POSTAL_CODE_ES(POSTAL_CODE_ID, POSTAL_CODE, AREA_ID)
-- Por eso el centroide y el recuento se conservan únicamente en esta tabla
-- de candidatos y no se intentan insertar en el objeto oficial.

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET DEFINE OFF

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
    a.postal_code,
    municipality.area_id,
    AVG(a.geom.sdo_point.x) AS center_long,
    AVG(a.geom.sdo_point.y) AS center_lat,
    COUNT(*) AS address_point_count
  FROM STG_GC_ADDRESS_POINT_ES a
  LEFT JOIN GC_AREA_ES municipality
    ON municipality.admin_level = 3
   AND UPPER(TRIM(municipality.area_name)) =
       UPPER(TRIM(a.municipality_name))
  WHERE a.postal_code IS NOT NULL
    AND a.geom IS NOT NULL
    AND a.geom.sdo_point IS NOT NULL
    AND a.geom.sdo_point.x IS NOT NULL
    AND a.geom.sdo_point.y IS NOT NULL
  GROUP BY a.postal_code, municipality.area_id
)
SELECT postal_code,
       area_id,
       center_long,
       center_lat,
       address_point_count,
       CASE
         WHEN area_id IS NULL THEN 'MISSING_MUNICIPALITY'
         ELSE 'READY_FOR_LOAD'
       END AS mapping_status
FROM postal_points;

COMMENT ON TABLE STG_GC_POSTAL_CODE_CANDIDATE IS
  'Candidatos GC_POSTAL_CODE_ES derivados de CartoCiudad portalpk_publi';

CREATE INDEX STG_GC_POSTAL_CODE_CAND_UK
  ON STG_GC_POSTAL_CODE_CANDIDATE (POSTAL_CODE, AREA_ID);

SELECT mapping_status, COUNT(*) AS rows_count
FROM STG_GC_POSTAL_CODE_CANDIDATE
GROUP BY mapping_status
ORDER BY mapping_status;
