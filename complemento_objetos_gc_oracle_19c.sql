CREATE TABLE GC_AREA_ES (
    AREA_ID            NUMBER(10) NOT NULL,
    PARENT_AREA_ID     NUMBER(10),
    AREA_LEVEL         NUMBER(2) NOT NULL,
    NAME               VARCHAR2(256) NOT NULL, -- Ampliado en 19c para soportar nombres largos/co-oficiales
    REAL_NAME          VARCHAR2(256),
    LANG_CODE          VARCHAR2(3) DEFAULT 'SPA',
    GEOMETRY           MDSYS.SDO_GEOMETRY,
    CENTER_GEOMETRY    MDSYS.SDO_GEOMETRY,
    CONSTRAINT PK_GC_AREA_ES PRIMARY KEY (AREA_ID)
);
--Usa el código con precaución.2. Códigos Postales (GC_POSTAL_CODE_ES)sqlCREATE TABLE GC_POSTAL_CODE_ES (
CREATE TABLE GC_POSTAL_CODE_ES (
    POSTAL_CODE_ID     NUMBER(10) NOT NULL,
    POSTAL_CODE        VARCHAR2(10) NOT NULL, -- En España son 5 dígitos, pero se mantiene la compatibilidad con prefijos
    AREA_ID            NUMBER(10) NOT NULL,
    CONSTRAINT PK_GC_POSTAL_CODE_ES PRIMARY KEY (POSTAL_CODE_ID),
    CONSTRAINT FK_GC_POSTAL_AREA FOREIGN KEY (AREA_ID) REFERENCES GC_AREA_ES(AREA_ID)
);
--Usa el código con precaución.3. Nombres de Vías (GC_ROAD_ES)sqlCREATE TABLE GC_ROAD_ES (
CREATE TABLE GC_ROAD_ES (
    ROAD_ID            NUMBER(10) NOT NULL,
    NAME               VARCHAR2(256) NOT NULL, -- Ej: 'CONDE DE PEÑALVER'
    BASE_NAME          VARCHAR2(256) NOT NULL, -- Nombre limpio para el motor de búsqueda
    ST_TYPE            VARCHAR2(50),           -- Ej: 'CALLE', 'AVENIDA', 'PASEO'
    ST_PREFIX          VARCHAR2(50),           -- Ej: 'DE LA', 'SAN'
    ST_SUFFIX          VARCHAR2(50),
    LANG_CODE          VARCHAR2(3) DEFAULT 'SPA',
    CONSTRAINT PK_GC_ROAD_ES PRIMARY KEY (ROAD_ID)
);
--Usa el código con precaución.4. Segmentos de Calle y Rangos Numéricos (GC_ROAD_SEGMENT_ES)Esta tabla requiere indexación espacial obligatoria. En 19c se recomienda almacenar rangos numéricos como texto (VARCHAR2) para soportar números de portal con letras (ej: "28B", "S/N", "3-5").sqlCREATE TABLE GC_ROAD_SEGMENT_ES (
CREATE TABLE GC_ROAD_SEGMENT_ES (
    ROAD_SEGMENT_ID    NUMBER(10) NOT NULL,
    ROAD_ID            NUMBER(10) NOT NULL,
    L_REF_ADDR         VARCHAR2(20),  -- Número de inicio lado izquierdo
    L_NREF_ADDR        VARCHAR2(20),  -- Número de fin lado izquierdo
    R_REF_ADDR         VARCHAR2(20),  -- Número de inicio lado derecho
    R_NREF_ADDR        VARCHAR2(20),  -- Número de fin lado derecho
    L_POSTAL_CODE_ID   NUMBER(10),
    R_POSTAL_CODE_ID   NUMBER(10),
    L_AREA_ID          NUMBER(10) NOT NULL,
    R_AREA_ID          NUMBER(10) NOT NULL,
    GEOMETRY           MDSYS.SDO_GEOMETRY NOT NULL, -- Línea o arco de la calle
    CONSTRAINT PK_GC_ROAD_SEG_ES PRIMARY KEY (ROAD_SEGMENT_ID),
    CONSTRAINT FK_GC_SEG_ROAD FOREIGN KEY (ROAD_ID) REFERENCES GC_ROAD_ES(ROAD_ID)
);

CREATE TABLE GC_ADDRESS_POINT_ES (
    ADDRESS_POINT_ID   NUMBER(10) NOT NULL,
    ROAD_ID            NUMBER(10) NOT NULL,    -- Relación directa con la calle en GC_ROAD_ES
    ST_NUM             VARCHAR2(20) NOT NULL,  -- Número de portal (ej: '14', '28B', 'S/N')
    POSTAL_CODE_ID     NUMBER(10) NOT NULL,    -- Relación con GC_POSTAL_CODE_ES
    AREA_ID            NUMBER(10) NOT NULL,    -- Relación con el municipio en GC_AREA_ES
    GEOMETRY           MDSYS.SDO_GEOMETRY NOT NULL, -- Coordenada exacta de la entrada/portal (Punto)
    CONSTRAINT PK_GC_ADDRESS_PT_ES PRIMARY KEY (ADDRESS_POINT_ID),
    CONSTRAINT FK_GC_ADDR_PT_ROAD FOREIGN KEY (ROAD_ID) REFERENCES GC_ROAD_ES(ROAD_ID),
    CONSTRAINT FK_GC_ADDR_PT_AREA FOREIGN KEY (AREA_ID) REFERENCES GC_AREA_ES(AREA_ID)
);


--Usa el código con precaución.5. Intersecciones (GC_INTERSECTION_ES)sqlCREATE TABLE GC_INTERSECTION_ES (
CREATE TABLE GC_INTERSECTION_ES (
    INTERSECTION_ID    NUMBER(10) NOT NULL,
    ROAD_ID_1          NUMBER(10) NOT NULL,
    ROAD_ID_2          NUMBER(10) NOT NULL,
    GEOMETRY           MDSYS.SDO_GEOMETRY NOT NULL, -- Punto de cruce
    CONSTRAINT PK_GC_INTER_ES PRIMARY KEY (INTERSECTION_ID)
);

CREATE TABLE GC_POI_ES (
    POI_ID             NUMBER(10) NOT NULL,
    NAME               VARCHAR2(512) NOT NULL, -- Ampliado en 19c para nombres comerciales u oficiales largos
    REAL_NAME          VARCHAR2(512),
    ST_NUM             VARCHAR2(20),           -- Número de gobierno/portal asignado al POI (ej: '28')
    ROAD_ID            NUMBER(10),             -- (Opcional) Relación directa con la calle de la tabla GC_ROAD_ES
    POSTAL_CODE_ID     NUMBER(10),             -- Relación con GC_POSTAL_CODE_ES
    AREA_ID            NUMBER(10) NOT NULL,    -- Relación con el municipio en GC_AREA_ES
    LANG_CODE          VARCHAR2(3) DEFAULT 'SPA',
    GEOMETRY           MDSYS.SDO_GEOMETRY NOT NULL, -- Punto exacto de la ubicación espacial
    CONSTRAINT PK_GC_POI_ES PRIMARY KEY (POI_ID),
    CONSTRAINT FK_GC_POI_AREA FOREIGN KEY (AREA_ID) REFERENCES GC_AREA_ES(AREA_ID)
);
-- 1. Insertar Metadatos Espaciales (Obligatorio antes de crear el índice)
INSERT INTO user_sdo_geom_metadata (table_name, column_name, diminfo, srid)
VALUES (
  'GC_ROAD_SEGMENT_ES',
  'GEOMETRY',
  MDSYS.SDO_DIM_ARRAY(
    MDSYS.SDO_DIM_ELEMENT('LONGITUDE', -180, 180, 0.05), -- Tolerancia de 5cm en 19c
    MDSYS.SDO_DIM_ELEMENT('LATITUDE', -90, 90, 0.05)
  ),
  4326
);

-- 2. Crear el Índice Espacial en 19c
CREATE INDEX S_IDX_GC_ROAD_SEG_ES ON GC_ROAD_SEGMENT_ES(GEOMETRY) 
INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2; -- Se recomienda SPATIAL_INDEX_V2 en Oracle 19c