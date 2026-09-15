
--Usa el código con precaución.Nota: Este comando genera en segundo plano la estructura exacta para las siguientes tres entidades:
-- GC_COUNTRY_PROFILEGC_PARSER_PROFILESPosteriormente, la documentación indica que debes poblar las reglas gramaticales cargando el script oficial del servidor: 
--		[1]$ORACLE_HOME/md/admin/sdogcprs.sql

-- 4. GC_AREA_ES Table

CREATE TABLE GC_AREA_ES (
    AREA_ID               NUMBER PRIMARY KEY,
    PARENT_AREA_ID        NUMBER,
    AREA_NAME             VARCHAR2(128),
    ADMIN_LEVEL           NUMBER, -- Nivel administrativo (Comunidad, Provincia, Municipio)
    SETTLEMENT_TYPE       VARCHAR2(32)
);
CREATE INDEX IDX_GC_AREA_NAME_ES ON GC_AREA_ES(AREA_NAME);

-- 5. GC_POSTAL_CODE_ES Table
CREATE TABLE GC_POSTAL_CODE_ES (
    POSTAL_CODE_ID        NUMBER PRIMARY KEY,
    POSTAL_CODE           VARCHAR2(16), -- Código postal (ej: '28046')
    AREA_ID               NUMBER,
    CONSTRAINT FK_GC_POSTAL_AREA_ES FOREIGN KEY (AREA_ID) REFERENCES GC_AREA_ES(AREA_ID)
);
CREATE INDEX IDX_GC_PCODE_VAL_ES ON GC_POSTAL_CODE_ES(POSTAL_CODE);

-- 6. GC_ROAD_ES Table
CREATE TABLE GC_ROAD_ES (
    ROAD_ID               NUMBER PRIMARY KEY,
    ROAD_NAME             VARCHAR2(128), -- Nombre de la vía (ej: 'CASTELLANA')
    ROAD_PREFIX           VARCHAR2(32),  -- Tipo de vía (ej: 'PASEO DE LA')
    ROAD_SUFFIX           VARCHAR2(32),
    ROAD_TYPE             VARCHAR2(32)
);
CREATE INDEX IDX_GC_ROAD_NAME_ES ON GC_ROAD_ES(ROAD_NAME);

-- 7. GC_ROAD_SEGMENT_ES Table
CREATE TABLE GC_ROAD_SEGMENT_ES (
    ROAD_SEGMENT_ID       NUMBER PRIMARY KEY, -- Id de tramo coincidente con motores de ruteo
    ROAD_ID               NUMBER NOT NULL,
    POSTAL_CODE_ID        NUMBER,
    AREA_ID               NUMBER,
    LEFT_FROM_NUMBER      VARCHAR2(16), -- Rango inicial de números (lado izquierdo)
    LEFT_TO_NUMBER        VARCHAR2(16),   
    RIGHT_FROM_NUMBER     VARCHAR2(16), -- Rango inicial de números (lado derecho)
    RIGHT_TO_NUMBER       VARCHAR2(16),  
    GEOMETRY              MDSYS.SDO_GEOMETRY, -- Segmento lineal espacial (vía física)
    CONSTRAINT FK_GC_SEG_ROAD_ES FOREIGN KEY (ROAD_ID) REFERENCES GC_ROAD_ES(ROAD_ID),
    CONSTRAINT FK_GC_SEG_AREA_ES FOREIGN KEY (AREA_ID) REFERENCES GC_AREA_ES(AREA_ID)
);

-- 8. GC_ADDRESS_POINT_ES Table and Index
CREATE TABLE GC_ADDRESS_POINT_ES (
    ADDRESS_POINT_ID      NUMBER PRIMARY KEY,
    ROAD_SEGMENT_ID       NUMBER NOT NULL,
    HOUSE_NUMBER          VARCHAR2(32), -- Número de portal exacto (ej: '45B')
    SIDE                  VARCHAR2(1),  -- 'L' (Izquierda) o 'R' (Derecha)
    PERCENT               NUMBER,       -- Distancia porcentual interpolada en el eje
    GEOMETRY              MDSYS.SDO_GEOMETRY, -- Coordenada puntual exacta (Punto de parcela)
    CONSTRAINT FK_GC_ADDR_SEG_ES FOREIGN KEY (ROAD_SEGMENT_ID) REFERENCES GC_ROAD_SEGMENT_ES(ROAD_SEGMENT_ID)
);

-- 9. GC_INTERSECTION_ES Table
CREATE TABLE GC_INTERSECTION_ES (
    INTERSECTION_ID       NUMBER PRIMARY KEY,
    ROAD_SEGMENT_ID_1     NUMBER NOT NULL,
    ROAD_SEGMENT_ID_2     NUMBER NOT NULL,
    GEOMETRY              MDSYS.SDO_GEOMETRY -- Punto exacto de cruce entre calles
);

-- 10. GC_POI_ES Table
CREATE TABLE GC_POI_ES (
    POI_ID                NUMBER PRIMARY KEY,
    POI_NAME              VARCHAR2(256), -- Puntos de Interés (ej: 'Hospital La Paz')
    AREA_ID               NUMBER,
    POSTAL_CODE_ID        NUMBER,
    GEOMETRY              MDSYS.SDO_GEOMETRY
);


-- Registrar las columnas geométricas en el diccionario de metadatos espaciales
INSERT INTO user_sdo_geom_metadata (table_name, column_name, diminfo, srid) VALUES (
    'GC_ROAD_SEGMENT_ES', 'GEOMETRY', 
    MDSYS.SDO_DIM_ARRAY(MDSYS.SDO_DIM_ELEMENT('X', -180, 180, 0.05), MDSYS.SDO_DIM_ELEMENT('Y', -90, 90, 0.05)), 
    4326 -- Sistema de coordenadas global WGS84 habitual
);

INSERT INTO user_sdo_geom_metadata (table_name, column_name, diminfo, srid) VALUES (
    'GC_ADDRESS_POINT_ES', 'GEOMETRY', 
    MDSYS.SDO_DIM_ARRAY(MDSYS.SDO_DIM_ELEMENT('X', -180, 180, 0.05), MDSYS.SDO_DIM_ELEMENT('Y', -90, 90, 0.05)), 
    4326
);

-- Crear los índices espaciales obligatorios
CREATE INDEX SX_GC_ROAD_SEG_ES ON GC_ROAD_SEGMENT_ES(GEOMETRY) INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;
CREATE INDEX SX_GC_ADDR_PT_ES ON GC_ADDRESS_POINT_ES(GEOMETRY) INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;