-- Metadatos espaciales para las tablas canónicas de staging.

BEGIN
  FOR r IN (
    SELECT table_name, column_name
    FROM user_sdo_geom_metadata
    WHERE table_name IN (
      'STG_GC_ADDRESS_POINT_ES', 'STG_GC_ROAD_ES',
      'STG_GC_ROAD_SEGMENT_ES', 'STG_GC_AREA_ES', 'STG_GC_POI_ES'
    )
  ) LOOP
    DELETE FROM user_sdo_geom_metadata
    WHERE table_name = r.table_name AND column_name = r.column_name;
  END LOOP;
END;
/

INSERT 
  INTO user_sdo_geom_metadata VALUES
    ('STG_GC_ADDRESS_POINT_ES', 'GEOM',
     MDSYS.SDO_DIM_ARRAY(MDSYS.SDO_DIM_ELEMENT('X', -180, 180, 0.000001),
                         MDSYS.SDO_DIM_ELEMENT('Y', -90, 90, 0.000001)), 4258);
insert                         
  INTO user_sdo_geom_metadata VALUES
    ('STG_GC_ROAD_ES', 'GEOM',
     MDSYS.SDO_DIM_ARRAY(MDSYS.SDO_DIM_ELEMENT('X', -180, 180, 0.000001),
                         MDSYS.SDO_DIM_ELEMENT('Y', -90, 90, 0.000001)), 4258);
insert                         
  INTO user_sdo_geom_metadata VALUES
    ('STG_GC_ROAD_SEGMENT_ES', 'GEOM',
     MDSYS.SDO_DIM_ARRAY(MDSYS.SDO_DIM_ELEMENT('X', -180, 180, 0.000001),
                         MDSYS.SDO_DIM_ELEMENT('Y', -90, 90, 0.000001)), 4258);
insert INTO user_sdo_geom_metadata VALUES
    ('STG_GC_AREA_ES', 'GEOM',
     MDSYS.SDO_DIM_ARRAY(MDSYS.SDO_DIM_ELEMENT('X', -180, 180, 0.000001),
                         MDSYS.SDO_DIM_ELEMENT('Y', -90, 90, 0.000001)), 4258);
 insert INTO user_sdo_geom_metadata VALUES
    ('STG_GC_POI_ES', 'GEOM',
     MDSYS.SDO_DIM_ARRAY(MDSYS.SDO_DIM_ELEMENT('X', -180, 180, 0.000001),
                         MDSYS.SDO_DIM_ELEMENT('Y', -90, 90, 0.000001)), 4258);
--SELECT 1 FROM dual;
