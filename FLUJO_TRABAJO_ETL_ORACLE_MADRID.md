# Flujo de trabajo ETL para Oracle Geocoder - Madrid

Este documento define el flujo de trabajo para transformar los datos de
CartoCiudad, Geofabrik/OpenStreetMap y Redes de Transporte del CNIG hacia las
tablas estándar del Oracle Geocoder (`GC_*_ES`).

## 1. Flujo general

```text
Fuentes originales
   ├── CartoCiudad: portalpk_publi, manzana
   ├── Geofabrik: viales, POI, edificios y áreas
   └── Redes de Transporte: tramos, portales y nodos viarios
             |
             v
      Inventario y control de calidad
             |
             v
      Conversión de todas las capas a Shapefile
             |
             v
      Tablas o ficheros staging
             |
             v
      Normalización y deduplicación
             |
             v
      Integración de fuentes
             |
             v
      Tablas GC_*_ES
             |
             v
      Índices y pruebas de geocodificación
```

## 2. Fase 1: inventario de las fuentes

Descomprimir los paquetes en directorios separados, convertir las capas a
Shapefile mediante `scripts/00_convert_sources_to_shapefile.sh` y registrar:

- Sistema de referencia.
- Número de registros.
- Campos y tipos.
- Valores nulos.
- Identificadores.
- Relaciones entre capas.
- Tipo y validez de las geometrías.
- Fecha de actualización de cada fuente.

Capas prioritarias:

| Fuente | Capas |
|---|---|
| CartoCiudad | `portalpk_publi`, `manzana` |
| Geofabrik | `gis_osm_roads_free`, `gis_osm_adminareas_a_free`, `gis_osm_places_free`, `gis_osm_pois_free` |
| Redes de Transporte | `rt_tramo_vial`, `rt_portalpk_p`, `rt_puntoctra_p`, `rt_nodoctra_p`, `rt_areactra_s` |

Comandos de inspección:

```bash
ogrinfo -ro -so -al datos_espaciales/madrid.gpkg
ogrinfo -ro -so -al datos_espaciales/rt_tramo_vial.shp
```

Para ficheros todavía comprimidos se puede utilizar `/vsizip/` de GDAL o
descomprimirlos en directorios de trabajo.

## 3. Fase 2: usar la referencia Oracle y crear el esquema oficial

La documentación de Oracle sobre las estructuras de geocodificación se utilizará
como referencia funcional para diseñar la transformación y el mapeo hacia las
tablas españolas `GC_*_ES`. Permite identificar el propósito de las tablas, sus
relaciones y los datos necesarios, pero no constituye el DDL de la instalación
objetivo.

La estructura real del geocoder deberá crearse mediante los scripts y
procedimientos oficiales de Oracle correspondientes a la versión instalada. No
se deben sustituir esos objetos por tablas creadas manualmente. Los scripts
oficiales deben establecer las columnas, tipos, restricciones, índices
espaciales, metadatos de `SDO_GEOMETRY`, perfiles del parser y demás objetos
auxiliares.

La documentación y el modelo de staging de este proyecto sirven únicamente
para orientar la transformación. Cuando exista acceso a la base de datos, se
validará el resultado contra los objetos oficiales creados por Oracle:

```text
GC_COUNTRY_PROFILE
GC_AREA_ES
GC_POSTAL_CODE_ES
GC_ROAD_ES
GC_ROAD_SEGMENT_ES
GC_ADDRESS_POINT_ES
GC_POI_ES
GC_PARSER_PROFILES
GC_PARSER_PROFILEAFS
```

Consulta de validación opcional:

```sql
SELECT DBMS_METADATA.GET_DDL('TABLE', table_name, USER)
FROM user_tables
WHERE table_name IN (
  'GC_COUNTRY_PROFILE',
  'GC_AREA_ES',
  'GC_POSTAL_CODE_ES',
  'GC_ROAD_ES',
  'GC_ROAD_SEGMENT_ES',
  'GC_ADDRESS_POINT_ES',
  'GC_POI_ES',
  'GC_PARSER_PROFILES',
  'GC_PARSER_PROFILEAFS'
);
```

También deben documentarse las claves, restricciones, índices y columnas
obligatorias que exponga la instalación oficial. El modelo puede variar según
la versión de Oracle y el proveedor de datos.

### 2.1. Procedimiento para crear los objetos oficiales y los perfiles de idioma

La guía operativa detallada se encuentra en
[`objetos_gc_oracle.md`](objetos_gc_oracle.md).

Los objetos `GC_*_ES` y los perfiles de lenguaje no deben crearse copiando el
modelo de staging ni mediante un `CREATE TABLE` aproximado. Debe seguirse este
orden:

1. Instalar o localizar el paquete oficial de Oracle Spatial/Geocoder que
   corresponda a la versión de la base de datos y al proveedor de datos.
2. Ejecutar los scripts oficiales con el usuario, tablespaces, privilegios y
   esquema indicados por Oracle. No modificar los nombres de objetos ni omitir
   scripts de instalación, índices, tipos, sinónimos o paquetes auxiliares.
3. Ejecutar los scripts oficiales de carga o configuración del país España.
   Deben quedar creados y relacionados, como mínimo, el perfil de país
   (`GC_COUNTRY_PROFILE`), las tablas geocoder `GC_*_ES` y los objetos de
   perfiles del parser (`GC_PARSER_PROFILES` y `GC_PARSER_PROFILEAFS`) que
   incluya la distribución instalada.
4. Configurar el idioma español usando los valores y procedimientos del
   paquete oficial. La configuración debe cubrir el código de idioma, el país
   `ES`, las reglas de normalización de nombres y tipos de vía, los
   separadores, abreviaturas y alias que utilice el parser. No asumir que
   `SPA`, `ES` o un nombre de perfil son válidos sin comprobarlos en la
   instalación.
5. Activar o asociar el perfil español al perfil de país y al servicio de
   geocodificación conforme a la documentación de la versión instalada.
   Confirmar especialmente el perfil por defecto, el idioma de entrada y las
   reglas de transliteración/acentos.
6. Obtener el DDL y los metadatos resultantes para documentar la instalación:

   ```sql
   SELECT DBMS_METADATA.GET_DDL('TABLE', table_name, USER)
   FROM user_tables
   WHERE table_name IN (
     'GC_COUNTRY_PROFILE', 'GC_AREA_ES', 'GC_POSTAL_CODE_ES',
     'GC_ROAD_ES', 'GC_ROAD_SEGMENT_ES', 'GC_ADDRESS_POINT_ES',
     'GC_POI_ES', 'GC_PARSER_PROFILES', 'GC_PARSER_PROFILEAFS'
   );
   ```

   También deben revisarse `USER_TAB_COLUMNS`, `USER_CONSTRAINTS`,
   `USER_INDEXES`, `USER_SDO_GEOM_METADATA` y los objetos `PACKAGE`,
   `FUNCTION` y `PROCEDURE` instalados por Oracle.
7. Ejecutar una prueba mínima de parseo y geocodificación en español con
   direcciones que contengan tipos de vía, acentos, números y códigos postales.
   Registrar el perfil utilizado y verificar que las tablas españolas y sus
   índices espaciales participan en la consulta.
8. Solo después de esa validación, adaptar
   `sql/04_load_gc_es_adapter.sql` a las columnas reales y cargar los datos
   desde `STG_GC_*_ES`.

Los scripts oficiales incorporados por la instalación deben conservarse
separados de los scripts de este repositorio, por ejemplo bajo
`sql/oracle_official/`. No se deben versionar credenciales, contraseñas ni
salidas que contengan información sensible de la base de datos.

## 4. Fase 3: crear un modelo staging

No se recomienda cargar directamente desde Shapefile o GeoPackage a las
tablas `GC_*_ES`. Se debe utilizar una zona staging, preferiblemente en Oracle:

```text
STG_CARTO_PORTAL
STG_CARTO_MANZANA
STG_OSM_ROAD
STG_OSM_POI
STG_OSM_AREA
STG_RT_TRAMO_VIAL
STG_RT_PORTAL
STG_AREA
STG_ROAD
STG_ROAD_SEGMENT
STG_ADDRESS_POINT
```

Las tablas staging deben conservar los identificadores originales, la fuente,
la fecha de actualización y el método de emparejamiento.

Campos de trazabilidad recomendados:

```text
SOURCE_DATA
SOURCE_ID
SOURCE_DATE
MATCH_METHOD
MATCH_SCORE
```

## 5. Fase 4: normalización

Aplicar las mismas reglas a todas las fuentes:

- Convertir nombres a mayúsculas.
- Eliminar espacios duplicados.
- Normalizar acentos según la configuración del parser Oracle.
- Normalizar guiones.
- Homogeneizar tipos de vía.
- Separar número y extensión.
- Conservar los códigos postales como texto de cinco caracteres.
- Validar municipios, provincias y poblaciones.
- Normalizar geometrías y sistemas de referencia.

Ejemplos de tipos de vía:

```text
CL  -> CALLE
AV  -> AVENIDA
PZ  -> PLAZA
```

Los datos pueden conservarse en EPSG:4258 o EPSG:4326 para intercambio. Para
operaciones de distancia y emparejamiento espacial conviene utilizar
temporalmente ETRS89 / UTM 30N (EPSG:25830).

## 6. Fase 5: transformación a tablas GC

### 6.1. `GC_AREA_ES`

Construir las áreas administrativas y poblaciones:

- Comunidad autónoma.
- Provincia.
- Municipio.
- Población.

La fuente principal será CartoCiudad. Los límites administrativos de OSM se
pueden utilizar como apoyo, pero no deben sustituir sin control a la fuente
oficial.

### 6.2. `GC_POSTAL_CODE_ES`

Construir los códigos postales y sus relaciones con municipios y áreas.
CartoCiudad aporta el código postal en `portalpk_publi`; será necesario agrupar
los portales y generar la representación requerida por Oracle. La geometría de
los polígonos postales, si se conserva, pertenece al staging o a una tabla GIS
auxiliar; no debe asumirse como una columna `SDO_GEOMETRY` del objeto oficial.

### 6.3. `GC_ROAD_ES`

Utilizar principalmente `rt_tramo_vial`, complementándolo con:

- `portalpk_publi.nombre_via`.
- `gis_osm_roads_free`.
- `rt_puntoctra_p`.

Se deben deduplicar los viales, normalizar sus nombres y asignar identificadores
estables.

### 6.4. `GC_ROAD_SEGMENT_ES`

Es la parte más compleja del proceso. Hay que:

- Agrupar los tramos pertenecientes al mismo vial.
- Mantener la geometría lineal de cada segmento en
  `GC_ROAD_SEGMENT_ES.GEOMETRY`; es la geometría espacial principal que utiliza
  el Geocoder.
- Relacionar cada segmento con su vial.
- Determinar rangos de numeración izquierda y derecha a partir de los portales
  de Redes de Transporte: impares a la izquierda y pares a la derecha,
  siguiendo el sentido creciente del tramo.
- Asociar portales a segmentos.
- Conservar la dirección o sentido geométrico del segmento cuando el modelo lo
  requiera.

No se debe generar esta tabla copiando únicamente las calles de OSM.
`sql/02_transform_staging.sql` calcula los mínimos y máximos de cada paridad
desde `STG_RT_PORTAL` y los asigna a `STG_GC_ROAD_SEGMENT_ES`. Solo se aceptan
números simples con una letra opcional; valores como `S/N` o `3-5` quedan fuera
del cálculo. El fallback OSM crea geometría, pero deja los cuatro campos de
rango a `NULL`. `sql/03_validate_staging.sql` informa de segmentos sin rango y
de rangos parciales.

En el modelo estándar, los segmentos son la única geometría espacial
imprescindible para la resolución de direcciones. Las geometrías de portales,
POI, áreas o códigos postales pueden conservarse en staging para controles,
emparejamientos y cálculo de coordenadas, pero el destino oficial puede
requerir referencias y coordenadas numéricas en lugar de columnas
`SDO_GEOMETRY`. La decisión final debe basarse en el DDL instalado.

### 6.5. `GC_ADDRESS_POINT_ES`

La fuente principal será `portalpk_publi`.

Cada portal debe relacionarse, según el DDL, con:

- Identificador del portal.
- Vial.
- Segmento.
- Número y extensión.
- Código postal.
- Área administrativa.
- Coordenadas.
- Lado del vial, si es obligatorio.

Los portales de `rt_portalpk_p` se utilizarán para contrastar o completar
portales y puntos kilométricos.

### 6.6. `GC_POI_ES`

Se puede abordar después de validar las direcciones. La fuente principal será
`gis_osm_pois_free` y, si procede, otras capas de puntos de Geofabrik.

## 7. Fase 6: prioridad y conflictos entre fuentes

Cuando varias fuentes describan el mismo elemento, aplicar esta prioridad
inicial:

```text
1. CartoCiudad
2. Redes de Transporte del CNIG
3. Geofabrik/OpenStreetMap
```

OSM puede completar elementos que no existan en las fuentes oficiales, pero no
debe reemplazar silenciosamente un dato oficial.

El proceso debe registrar los conflictos, duplicados y elementos sin
correspondencia para poder revisarlos.

## 8. Fase 7: carga reproducible en Oracle

La carga puede organizarse en scripts independientes:

```text
01_create_staging.sql
02_load_staging.sql
03_transform_area.sql
04_transform_postal_code.sql
05_transform_road.sql
06_transform_road_segment.sql
07_transform_address_point.sql
08_transform_poi.sql
09_create_indexes.sql
10_validate_geocoder.sql
```

Para grandes volúmenes conviene utilizar cargas masivas, `INSERT /*+ APPEND */`,
`MERGE` y crear los índices después de insertar los datos.

Las geometrías finales deben almacenarse como `SDO_GEOMETRY`, con los
metadatos y los índices espaciales que requiera Oracle.

## 9. Fase 8: validación

Comprobaciones mínimas:

- Portales sin vial.
- Portales sin municipio.
- Portales sin código postal.
- Segmentos sin geometría.
- Viales sin segmentos.
- Geometrías inválidas.
- Coordenadas fuera de Madrid.
- Duplicados por dirección.
- Números no convertibles.
- Portales alejados de su vial.
- Viales que no tienen ningún portal asociado.

Finalmente se deben ejecutar consultas reales mediante `SDO_GCDR` y comprobar
direcciones conocidas de Madrid.

## 10. Próximos entregables

El orden recomendado de implementación es:

1. Informe de inventario completo de las tres fuentes.
2. Scripts oficiales de creación y catálogo de objetos de las tablas Oracle.
3. Modelo y tablas staging.
4. Mapeo de campos fuente-destino.
5. Transformación de `GC_AREA_ES`.
6. Transformación de `GC_ADDRESS_POINT_ES`.
7. Transformación de `GC_ROAD_ES`.
8. Transformación de `GC_ROAD_SEGMENT_ES`.
9. Transformación opcional de `GC_POSTAL_CODE_ES` y `GC_POI_ES`.
10. Carga, índices y pruebas de geocodificación.
