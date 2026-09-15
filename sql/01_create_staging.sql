-- Crea todos los objetos canónicos STG_* del flujo ETL.
-- Ejecutar con el usuario propietario de las tablas de staging.

@@staging/01_create_tables.sql
@@staging/02_create_spatial_metadata.sql
@@staging/03_create_spatial_indexes.sql
