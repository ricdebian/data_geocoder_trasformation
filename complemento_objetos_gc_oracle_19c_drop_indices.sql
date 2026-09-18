-- DDL candidato para un conjunto GC de Oracle Geocoder 19c.
--
-- IMPORTANTE:
--   * Oracle no distribuye un CREATE TABLE genérico para los datos nacionales
--     GC_*_<sufijo>. El proveedor de datos determina el sufijo y el DDL real.
--   * Este script es una base de integración para ES, no sustituye al dataset
--     oficial del Geocoder ni a su instalación.
--   * Verificar el DDL instalado con DBMS_METADATA antes de ejecutar cargas.
--
-- Referencia:
--   Oracle Spatial and Graph Developer's Guide 19c,
--   capítulo "Geocoding Address Data", estructuras e índices de Geocoder.
--
-- El script elimina únicamente las tablas del conjunto candidato y sus
-- restricciones. No elimina GC_COUNTRY_PROFILE ni tablas de parser.

WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET DEFINE OFF

-- 1. Eliminar el conjunto anterior, si existe.
BEGIN
  FOR t IN (
    SELECT table_name
    FROM user_tables
    WHERE table_name IN (
      'GC_ADDRESS_POINT_ES',
      'GC_INTERSECTION_ES',
      'GC_POI_ES',
      'GC_ROAD_SEGMENT_ES',
      'GC_ROAD_ES',
      'GC_POSTAL_CODE_ES',
      'GC_AREA_ES'
    )
  ) LOOP
    EXECUTE IMMEDIATE
      'DROP TABLE ' || DBMS_ASSERT.SIMPLE_SQL_NAME(t.table_name) ||
      ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
END;
/

-- Los metadatos se conservan aunque se elimine una tabla en algunas versiones.
DELETE FROM USER_SDO_GEOM_METADATA
WHERE TABLE_NAME = 'GC_ROAD_SEGMENT_ES'
  AND COLUMN_NAME = 'GEOMETRY';
COMMIT;

-- 2. Áreas administrativas. Oracle documenta centros y jerarquía mediante
--    columnas numéricas; no exige una geometría SDO para esta tabla.
CREATE TABLE GC_AREA_ES (
  AREA_ID           NUMBER(10) NOT NULL,
  AREA_NAME         VARCHAR2(256) NOT NULL,
  REAL_NAME         VARCHAR2(256),
  LANG_CODE         VARCHAR2(3),
  ADMIN_LEVEL       NUMBER(2),
  LEVEL1_AREA_ID    NUMBER(10),
  LEVEL2_AREA_ID    NUMBER(10),
  LEVEL3_AREA_ID    NUMBER(10),
  LEVEL4_AREA_ID    NUMBER(10),
  LEVEL5_AREA_ID    NUMBER(10),
  LEVEL6_AREA_ID    NUMBER(10),
  LEVEL7_AREA_ID    NUMBER(10),
  CENTER_LONG       NUMBER,
  CENTER_LAT        NUMBER,
  ROAD_SEGMENT_ID   NUMBER(10),
  POSTAL_CODE       VARCHAR2(16),
  COUNTRY_CODE_2    VARCHAR2(2) DEFAULT 'ES' NOT NULL,
  PARTITION_ID      NUMBER(10),
  IS_ALIAS          VARCHAR2(1),
  CONSTRAINT PK_GC_AREA_ES PRIMARY KEY (AREA_ID)
);

-- 3. Códigos postales. La relación espacial se resuelve por segmento y
--    coordenadas de centro, no mediante una geometría SDO obligatoria.
CREATE TABLE GC_POSTAL_CODE_ES (
  POSTAL_CODE       VARCHAR2(16) NOT NULL,
  AREA_ID           NUMBER(10),
  CENTER_LONG       NUMBER,
  CENTER_LAT        NUMBER,
  ROAD_SEGMENT_ID   NUMBER(10),
  COUNTRY_CODE_2    VARCHAR2(2) DEFAULT 'ES' NOT NULL,
  PARTITION_ID      NUMBER(10),
  CONSTRAINT PK_GC_POSTAL_CODE_ES PRIMARY KEY
    (POSTAL_CODE, COUNTRY_CODE_2, PARTITION_ID)
);

-- 4. Viales lógicos. La geometría pertenece a los segmentos.
CREATE TABLE GC_ROAD_ES (
  ROAD_ID                 NUMBER(10) NOT NULL,
  SETTLEMENT_ID           NUMBER(10),
  MUNICIPALITY_ID         NUMBER(10),
  PARENT_AREA_ID          NUMBER(10),
  LANG_CODE               VARCHAR2(3),
  BASE_NAME               VARCHAR2(256) NOT NULL,
  ROAD_TYPE               VARCHAR2(64),
  ROAD_PREFIX             VARCHAR2(64),
  ROAD_SUFFIX             VARCHAR2(64),
  POSTAL_CODE             VARCHAR2(16),
  START_ROAD_SEGMENT_ID   NUMBER(10),
  CENTER_ROAD_SEGMENT_ID  NUMBER(10),
  END_ROAD_SEGMENT_ID     NUMBER(10),
  COUNTRY_CODE_2          VARCHAR2(2) DEFAULT 'ES' NOT NULL,
  PARTITION_ID            NUMBER(10),
  CONSTRAINT PK_GC_ROAD_ES PRIMARY KEY (ROAD_ID)
);

-- 5. Segmentos viales. Es la única tabla GC del modelo documentado que
--    requiere una columna GEOMETRY SDO_GEOMETRY y un índice espacial.
CREATE TABLE GC_ROAD_SEGMENT_ES (
  ROAD_SEGMENT_ID   NUMBER(10) NOT NULL,
  ROAD_ID           NUMBER(10) NOT NULL,
  L_ADDR_FORMAT     VARCHAR2(32),
  R_ADDR_FORMAT     VARCHAR2(32),
  L_ADDR_SCHEME     VARCHAR2(32),
  R_ADDR_SCHEME     VARCHAR2(32),
  START_HN          VARCHAR2(32),
  END_HN            VARCHAR2(32),
  L_START_HN        VARCHAR2(32),
  L_END_HN          VARCHAR2(32),
  R_START_HN        VARCHAR2(32),
  R_END_HN          VARCHAR2(32),
  L_START_HN2       VARCHAR2(32),
  L_END_HN2         VARCHAR2(32),
  R_START_HN2       VARCHAR2(32),
  R_END_HN2         VARCHAR2(32),
  POSTAL_CODE       VARCHAR2(16),
  GEOMETRY          MDSYS.SDO_GEOMETRY NOT NULL,
  COUNTRY_CODE_2    VARCHAR2(2) DEFAULT 'ES' NOT NULL,
  PARTITION_ID      NUMBER(10),
  CONSTRAINT PK_GC_ROAD_SEGMENT_ES PRIMARY KEY (ROAD_SEGMENT_ID),
  CONSTRAINT FK_GC_SEGMENT_ROAD_ES FOREIGN KEY (ROAD_ID)
    REFERENCES GC_ROAD_ES (ROAD_ID)
);

-- 6. Puntos de dirección. Oracle documenta coordenadas y no una geometría
--    SDO obligatoria en esta tabla.
CREATE TABLE GC_ADDRESS_POINT_ES (
  ADDRESS_POINT_ID  NUMBER(10) NOT NULL,
  ROAD_ID           NUMBER(10),
  ROAD_SEGMENT_ID   NUMBER(10),
  SIDE              VARCHAR2(1),
  HOUSE_NUMBER      VARCHAR2(32),
  PERCENT           NUMBER,
  ADDR_LONG         NUMBER,
  ADDR_LAT          NUMBER,
  COUNTRY_CODE_2    VARCHAR2(2) DEFAULT 'ES' NOT NULL,
  PARTITION_ID      NUMBER(10),
  CONSTRAINT PK_GC_ADDRESS_POINT_ES PRIMARY KEY (ADDRESS_POINT_ID),
  CONSTRAINT FK_GC_ADDR_ROAD_ES FOREIGN KEY (ROAD_ID)
    REFERENCES GC_ROAD_ES (ROAD_ID),
  CONSTRAINT FK_GC_ADDR_SEGMENT_ES FOREIGN KEY (ROAD_SEGMENT_ID)
    REFERENCES GC_ROAD_SEGMENT_ES (ROAD_SEGMENT_ID)
);

-- 7. Puntos de interés e intersecciones: coordenadas numéricas según el
--    modelo documentado por Oracle.
CREATE TABLE GC_POI_ES (
  POI_ID            NUMBER(10) NOT NULL,
  NAME              VARCHAR2(512) NOT NULL,
  ROAD_SEGMENT_ID   NUMBER(10),
  SIDE              VARCHAR2(1),
  PERCENT           NUMBER,
  LOC_LONG          NUMBER,
  LOC_LAT           NUMBER,
  AREA_ID           NUMBER(10),
  POSTAL_CODE       VARCHAR2(16),
  COUNTRY_CODE_2    VARCHAR2(2) DEFAULT 'ES' NOT NULL,
  PARTITION_ID      NUMBER(10),
  CONSTRAINT PK_GC_POI_ES PRIMARY KEY (POI_ID)
);

CREATE TABLE GC_INTERSECTION_ES (
  INTERSECTION_ID   NUMBER(10) NOT NULL,
  ROAD_ID_1         NUMBER(10),
  ROAD_SEGMENT_ID_1 NUMBER(10),
  ROAD_ID_2         NUMBER(10),
  ROAD_SEGMENT_ID_2 NUMBER(10),
  INTS_LONG         NUMBER,
  INTS_LAT          NUMBER,
  COUNTRY_CODE_2    VARCHAR2(2) DEFAULT 'ES' NOT NULL,
  PARTITION_ID      NUMBER(10),
  CONSTRAINT PK_GC_INTERSECTION_ES PRIMARY KEY (INTERSECTION_ID)
);

-- 8. Metadatos e índice espacial para el segmento vial.
--    SRID 4258 sigue la convención del staging de este repositorio. Ajustarlo
--    al SRID de la instalación/proveedor antes de cargar datos.
INSERT INTO USER_SDO_GEOM_METADATA (
  TABLE_NAME, COLUMN_NAME, DIMINFO, SRID
) VALUES (
  'GC_ROAD_SEGMENT_ES',
  'GEOMETRY',
  MDSYS.SDO_DIM_ARRAY(
    MDSYS.SDO_DIM_ELEMENT('LONGITUDE', -180, 180, 0.000001),
    MDSYS.SDO_DIM_ELEMENT('LATITUDE', -90, 90, 0.000001)
  ),
  4258
);

CREATE INDEX SX_GC_ROAD_SEGMENT_ES_GEOM
  ON GC_ROAD_SEGMENT_ES (GEOMETRY)
  INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;

-- 9. Índices B-tree usados por las búsquedas del geocoder.
CREATE INDEX IX_GC_ROAD_SEGMENT_ES_ROAD
  ON GC_ROAD_SEGMENT_ES (ROAD_ID, START_HN, END_HN);
CREATE INDEX IX_GC_ROAD_ES_ID
  ON GC_ROAD_ES (ROAD_ID);
CREATE INDEX IX_GC_AREA_ES_NAME
  ON GC_AREA_ES (COUNTRY_CODE_2, AREA_NAME, ADMIN_LEVEL);
CREATE INDEX IX_GC_POSTAL_CODE_ES_CODE
  ON GC_POSTAL_CODE_ES (COUNTRY_CODE_2, POSTAL_CODE);
CREATE INDEX IX_GC_ADDRESS_POINT_ES_ADDR
  ON GC_ADDRESS_POINT_ES
     (ROAD_SEGMENT_ID, ROAD_ID, HOUSE_NUMBER, SIDE);
CREATE INDEX IX_GC_POI_ES_NAME
  ON GC_POI_ES (COUNTRY_CODE_2, NAME);

COMMIT;
