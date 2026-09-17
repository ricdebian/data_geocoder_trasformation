-- Modelo lógico de referencia GC_*_ES

CREATE TABLE GC_AREA_ES (
    AREA_ID             NUMBER         NOT NULL,
    PARENT_AREA_ID      NUMBER,
    AREA_TYPE           VARCHAR2(30),
    AREA_CODE           VARCHAR2(30),
    AREA_NAME           VARCHAR2(200),
    COUNTRY_CODE        VARCHAR2(2),
    GEOM                SDO_GEOMETRY,
    CONSTRAINT PK_GC_AREA_ES PRIMARY KEY (AREA_ID)
);

COMMENT ON TABLE GC_AREA_ES IS 'Áreas administrativas utilizadas por el geocoder de España.';
COMMENT ON COLUMN GC_AREA_ES.AREA_ID IS 'Identificador único del área administrativa.';
COMMENT ON COLUMN GC_AREA_ES.PARENT_AREA_ID IS 'Identificador del área administrativa superior.';
COMMENT ON COLUMN GC_AREA_ES.AREA_TYPE IS 'Tipo de área: comunidad autónoma, provincia, municipio o población.';
COMMENT ON COLUMN GC_AREA_ES.AREA_CODE IS 'Código oficial de la división administrativa.';
COMMENT ON COLUMN GC_AREA_ES.AREA_NAME IS 'Nombre normalizado del área administrativa.';
COMMENT ON COLUMN GC_AREA_ES.COUNTRY_CODE IS 'Código ISO del país (ES).';
COMMENT ON COLUMN GC_AREA_ES.GEOM IS 'Geometría del área administrativa.';

CREATE TABLE GC_POSTAL_CODE_ES (
    POSTAL_CODE_ID      NUMBER         NOT NULL,
    POSTAL_CODE         VARCHAR2(5)    NOT NULL,
    AREA_ID             NUMBER,
    GEOM                SDO_GEOMETRY,
    CONSTRAINT PK_GC_POSTAL_CODE_ES PRIMARY KEY (POSTAL_CODE_ID),
    CONSTRAINT FK_GC_POSTAL_AREA FOREIGN KEY (AREA_ID) REFERENCES GC_AREA_ES (AREA_ID)
);

COMMENT ON TABLE GC_POSTAL_CODE_ES IS 'Códigos postales utilizados por el geocoder de España.';
COMMENT ON COLUMN GC_POSTAL_CODE_ES.POSTAL_CODE_ID IS 'Identificador único del código postal.';
COMMENT ON COLUMN GC_POSTAL_CODE_ES.POSTAL_CODE IS 'Código postal de cinco dígitos.';
COMMENT ON COLUMN GC_POSTAL_CODE_ES.AREA_ID IS 'Área administrativa a la que pertenece el código postal.';
COMMENT ON COLUMN GC_POSTAL_CODE_ES.GEOM IS 'Representación espacial del área postal.';

CREATE TABLE GC_ROAD_ES (
    ROAD_ID             NUMBER         NOT NULL,
    AREA_ID             NUMBER,
    ROAD_TYPE           VARCHAR2(50),
    ROAD_NAME           VARCHAR2(250),
    ROAD_FULL_NAME      VARCHAR2(300),
    CONSTRAINT PK_GC_ROAD_ES PRIMARY KEY (ROAD_ID),
    CONSTRAINT FK_GC_ROAD_AREA FOREIGN KEY (AREA_ID) REFERENCES GC_AREA_ES (AREA_ID)
);

COMMENT ON TABLE GC_ROAD_ES IS 'Catálogo de viales utilizados por el geocoder.';
COMMENT ON COLUMN GC_ROAD_ES.ROAD_ID IS 'Identificador único del vial.';
COMMENT ON COLUMN GC_ROAD_ES.AREA_ID IS 'Área administrativa donde se encuentra el vial.';
COMMENT ON COLUMN GC_ROAD_ES.ROAD_TYPE IS 'Tipo de vía normalizado: CALLE, AVENIDA, PLAZA, etc.';
COMMENT ON COLUMN GC_ROAD_ES.ROAD_NAME IS 'Nombre principal del vial sin el tipo de vía.';
COMMENT ON COLUMN GC_ROAD_ES.ROAD_FULL_NAME IS 'Nombre completo normalizado del vial.';

CREATE TABLE GC_ROAD_SEGMENT_ES (
    ROAD_SEGMENT_ID     NUMBER         NOT NULL,
    ROAD_ID             NUMBER         NOT NULL,
    LEFT_FROM_NUMBER    NUMBER,
    LEFT_TO_NUMBER      NUMBER,
    RIGHT_FROM_NUMBER   NUMBER,
    RIGHT_TO_NUMBER     NUMBER,
    DIRECTION_CODE      VARCHAR2(10),
    GEOM                SDO_GEOMETRY,
    CONSTRAINT PK_GC_ROAD_SEGMENT_ES PRIMARY KEY (ROAD_SEGMENT_ID),
    CONSTRAINT FK_GC_SEGMENT_ROAD FOREIGN KEY (ROAD_ID) REFERENCES GC_ROAD_ES (ROAD_ID)
);

COMMENT ON TABLE GC_ROAD_SEGMENT_ES IS 'Segmentos de vial utilizados en los procesos de geocodificación.';
COMMENT ON COLUMN GC_ROAD_SEGMENT_ES.ROAD_SEGMENT_ID IS 'Identificador único del segmento.';
COMMENT ON COLUMN GC_ROAD_SEGMENT_ES.ROAD_ID IS 'Identificador del vial al que pertenece el segmento.';
COMMENT ON COLUMN GC_ROAD_SEGMENT_ES.LEFT_FROM_NUMBER IS 'Número inicial de portal en el lado izquierdo del segmento.';
COMMENT ON COLUMN GC_ROAD_SEGMENT_ES.LEFT_TO_NUMBER IS 'Número final de portal en el lado izquierdo del segmento.';
COMMENT ON COLUMN GC_ROAD_SEGMENT_ES.RIGHT_FROM_NUMBER IS 'Número inicial de portal en el lado derecho del segmento.';
COMMENT ON COLUMN GC_ROAD_SEGMENT_ES.RIGHT_TO_NUMBER IS 'Número final de portal en el lado derecho del segmento.';
COMMENT ON COLUMN GC_ROAD_SEGMENT_ES.DIRECTION_CODE IS 'Código de dirección o sentido de circulación asociado al segmento.';
COMMENT ON COLUMN GC_ROAD_SEGMENT_ES.GEOM IS 'Geometría lineal del segmento de vial.';

CREATE TABLE GC_ADDRESS_POINT_ES (
    ADDRESS_POINT_ID    NUMBER         NOT NULL,
    ROAD_ID             NUMBER         NOT NULL,
    ROAD_SEGMENT_ID     NUMBER,
    AREA_ID             NUMBER,
    POSTAL_CODE_ID      NUMBER,
    HOUSE_NUMBER        VARCHAR2(20),
    HOUSE_EXTENSION     VARCHAR2(20),
    SIDE_CODE           VARCHAR2(1),
    GEOM                SDO_GEOMETRY,
    CONSTRAINT PK_GC_ADDRESS_POINT_ES PRIMARY KEY (ADDRESS_POINT_ID),
    CONSTRAINT FK_GC_ADDR_ROAD FOREIGN KEY (ROAD_ID) REFERENCES GC_ROAD_ES (ROAD_ID),
    CONSTRAINT FK_GC_ADDR_SEGMENT FOREIGN KEY (ROAD_SEGMENT_ID) REFERENCES GC_ROAD_SEGMENT_ES (ROAD_SEGMENT_ID),
    CONSTRAINT FK_GC_ADDR_AREA FOREIGN KEY (AREA_ID) REFERENCES GC_AREA_ES (AREA_ID),
    CONSTRAINT FK_GC_ADDR_POSTAL FOREIGN KEY (POSTAL_CODE_ID) REFERENCES GC_POSTAL_CODE_ES (POSTAL_CODE_ID)
);

COMMENT ON TABLE GC_ADDRESS_POINT_ES IS 'Portales o puntos de dirección del geocoder de España.';
COMMENT ON COLUMN GC_ADDRESS_POINT_ES.ADDRESS_POINT_ID IS 'Identificador único del portal.';
COMMENT ON COLUMN GC_ADDRESS_POINT_ES.ROAD_ID IS 'Vial asociado al portal.';
COMMENT ON COLUMN GC_ADDRESS_POINT_ES.ROAD_SEGMENT_ID IS 'Segmento de vial asociado al portal.';
COMMENT ON COLUMN GC_ADDRESS_POINT_ES.AREA_ID IS 'Área administrativa asociada al portal.';
COMMENT ON COLUMN GC_ADDRESS_POINT_ES.POSTAL_CODE_ID IS 'Código postal asociado al portal.';
COMMENT ON COLUMN GC_ADDRESS_POINT_ES.HOUSE_NUMBER IS 'Número principal del portal.';
COMMENT ON COLUMN GC_ADDRESS_POINT_ES.HOUSE_EXTENSION IS 'Complemento, letra o extensión del número de portal.';
COMMENT ON COLUMN GC_ADDRESS_POINT_ES.SIDE_CODE IS 'Indicador del lado de la vía en el que se encuentra el portal.';
COMMENT ON COLUMN GC_ADDRESS_POINT_ES.GEOM IS 'Geometría puntual del portal.';

CREATE TABLE GC_POI_ES (
    POI_ID              NUMBER         NOT NULL,
    POI_NAME            VARCHAR2(300),
    CATEGORY            VARCHAR2(100),
    ROAD_ID             NUMBER,
    ADDRESS_POINT_ID    NUMBER,
    GEOM                SDO_GEOMETRY,
    CONSTRAINT PK_GC_POI_ES PRIMARY KEY (POI_ID),
    CONSTRAINT FK_GC_POI_ROAD FOREIGN KEY (ROAD_ID) REFERENCES GC_ROAD_ES (ROAD_ID),
    CONSTRAINT FK_GC_POI_ADDRESS FOREIGN KEY (ADDRESS_POINT_ID) REFERENCES GC_ADDRESS_POINT_ES (ADDRESS_POINT_ID)
);

COMMENT ON TABLE GC_POI_ES IS 'Puntos de interés utilizados por el geocoder.';
COMMENT ON COLUMN GC_POI_ES.POI_ID IS 'Identificador único del punto de interés.';
COMMENT ON COLUMN GC_POI_ES.POI_NAME IS 'Nombre normalizado del punto de interés.';
COMMENT ON COLUMN GC_POI_ES.CATEGORY IS 'Categoría funcional del punto de interés.';
COMMENT ON COLUMN GC_POI_ES.ROAD_ID IS 'Vial asociado al punto de interés.';
COMMENT ON COLUMN GC_POI_ES.ADDRESS_POINT_ID IS 'Portal asociado al punto de interés cuando exista.';
COMMENT ON COLUMN GC_POI_ES.GEOM IS 'Geometría puntual del punto de interés.';

CREATE INDEX IX_GC_AREA_ES_GEOM ON GC_AREA_ES (GEOM) INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;
CREATE INDEX IX_GC_POSTAL_CODE_ES_GEOM ON GC_POSTAL_CODE_ES (GEOM) INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;
CREATE INDEX IX_GC_ROAD_SEGMENT_ES_GEOM ON GC_ROAD_SEGMENT_ES (GEOM) INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;
CREATE INDEX IX_GC_ADDRESS_POINT_ES_GEOM ON GC_ADDRESS_POINT_ES (GEOM) INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;
CREATE INDEX IX_GC_POI_ES_GEOM ON GC_POI_ES (GEOM) INDEXTYPE IS MDSYS.SPATIAL_INDEX_V2;
