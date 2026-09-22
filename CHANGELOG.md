# Historial de cambios

## 2026-09-22 — `1617dc4`

Cambios respecto a la versión anterior `e7b44ac`:

### Rangos de numeración de segmentos

- Los segmentos de Redes de Transporte se incorporan a staging y sus rangos se
  calculan desde `rt_portalpk_p` por paridad: impares a la izquierda y pares a
  la derecha, siguiendo el sentido creciente del tramo.
- Solo se aceptan números simples con una letra opcional; `S/N` y rangos como
  `3-5` se excluyen por no representar un extremo estable.
- El fallback de segmentos OSM aporta geometría, pero no rangos de numeración.
- `sql/03_validate_staging.sql` informa de segmentos sin rango y de rangos
  parciales.

### Carga del mapa de segmentos

- `sql/04_load_gc_es_adapter.sql` deduplica por `SOURCE_ID` antes de insertar
  en `STG_GC_LOAD_SEGMENT_MAP`, evitando violaciones de su clave primaria cuando
  el staging contiene varias filas para el mismo segmento.
- La inserción en `GC_ROAD_SEGMENT_ES` reutiliza la misma deduplicación para no
  insertar varias veces el mismo `ROAD_SEGMENT_ID` dentro de una sentencia.
- `sql/03_validate_staging.sql` incluye un control específico de identificadores
  de segmento duplicados.

### Flujo de carga directa desde GeoPackage

- Se documentaron los requisitos de entorno para PowerShell y QGIS/GDAL:
  - rutas de `ogr2ogr`, `ogrinfo` y `oci.dll`;
  - `GDAL_DRIVER_PATH`;
  - `GDAL_DATA` y `PROJ_DATA`;
  - `NLS_LANG` para cargas desde ficheros UTF-8 a una base de datos
    configurada con `WE8ISO8859P1`.
- Se añadieron variables de zona horaria para evitar problemas al cargar
  valores temporales (`OGR_FORCE_LOCAL_TIME_ZONE` y `ORA_SDTZ`).
- La carga OCI convierte los campos `DateTime` a texto mediante
  `-mapFieldType DateTime=String`, evitando errores relacionados con la zona
  horaria del timestamp.
- El script de preparación de fuentes PowerShell incorpora la ruta de QGIS y
  actualiza el paquete GeoFabrik utilizado a
  `madrid-260914-free.gpkg.zip`.
- La validación de `ogrinfo` durante la generación del inventario queda
  temporalmente desactivada en el script PowerShell para permitir continuar
  con fuentes cuyo inventario produzca errores no bloqueantes.

### Transformación de staging

- Se ajustaron las consultas de `sql/02_transform_staging.sql` para referirse
  explícitamente a columnas creadas por GDAL/OCI con identificadores
  entrecomillados.
- `fecha_modificacion` se convierte explícitamente a `TIMESTAMP(6)` desde el
  formato ISO con fracciones de segundo.
- Se cualificaron las columnas de POI con el alias de tabla para evitar
  ambigüedades.
- Se mantiene el relleno a cinco dígitos de los códigos postales.

### Metadatos e índices espaciales

- Las inserciones de `USER_SDO_GEOMETRY_METADATA` se separaron en sentencias
  `INSERT` independientes en lugar de usar `INSERT ALL`.
- Se conserva el SRID `4258` y la extensión espacial definida para las tablas
  canónicas de staging.

### Objetos Oracle y reejecución

- `complemento_objetos_gc_oracle.sql` incorpora `DROP TABLE ... CASCADE
  CONSTRAINT` y `DROP INDEX` antes de recrear objetos, facilitando la
  reejecución del script en entornos de desarrollo.
- Se añadieron rutinas equivalentes de limpieza para las tablas de áreas,
  códigos postales, viales, segmentos, portales, intersecciones y POI, además
  de los índices espaciales de segmentos y portales.

### Observaciones de compatibilidad

- La carga PowerShell contiene rutas locales de QGIS e Instant Client
  específicas del entorno de desarrollo. Deben revisarse antes de ejecutarla
  en otro equipo.
- El archivo `sql/gc/gc_es_modelo_logico.sql` presenta cambios de codificación
  en comentarios con caracteres acentuados respecto a la versión anterior.
  Las definiciones SQL no cambian, pero conviene conservar el fichero en UTF-8
  para evitar texto ilegible en futuras ejecuciones o revisiones.
