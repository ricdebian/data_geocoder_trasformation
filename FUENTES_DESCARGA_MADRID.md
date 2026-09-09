# Fuentes de descarga - piloto Madrid

Este documento registra las fuentes necesarias para preparar la transformación
de datos hacia las tablas del Oracle Geocoder (`GC_*_ES`).

## 1. CartoCiudad - CNIG

**Portal de descarga:**

<https://centrodedescargas.cnig.es/CentroDescargas/cartociudad>

Descargar:

- GeoPackage de la provincia de Madrid.
- Contenido auxiliar y documentación de CartoCiudad.
- Especificaciones técnicas y diccionario de atributos.

Capas de interés:

- `portalpk_publi`: portales y puntos kilométricos.
- `manzana`: manzanas catastrales.
- Tablas auxiliares de comunidades autónomas, provincias, municipios y
  entidades de población.

El contenido de CartoCiudad debe utilizarse como fuente principal para las
direcciones oficiales y la identificación administrativa.

## 2. Geofabrik - OpenStreetMap

**Portal general:**

<https://download.geofabrik.de/>

**Extracto regional de Madrid:**

<https://download.geofabrik.de/europe/spain/madrid.html>

**Descarga GeoPackage:**

<https://download.geofabrik.de/europe/spain/madrid-latest-free.gpkg.zip>

Descargar el GeoPackage regional de Madrid. Este extracto puede aportar:

- Viales y carreteras.
- Nombres de calles.
- Direcciones OSM (`addr:*`), cuando estén disponibles.
- Lugares y puntos de interés.
- Edificios.
- Elementos administrativos y de referencia.

Geofabrik distribuye extractos diarios de OpenStreetMap. Los datos proceden de
OpenStreetMap y están sujetos a la licencia ODbL. Debe conservarse la
atribución a OpenStreetMap y cumplirse dicha licencia al distribuir datos
derivados.

**Documentación técnica de Geofabrik:**

<https://download.geofabrik.de/technical.html>

**Licencia y atribución de OpenStreetMap:**

<https://www.openstreetmap.org/copyright>

## 3. Redes de Transporte - CNIG

**Portal de descarga:**

<https://centrodedescargas.cnig.es/CentroDescargas/redes-transporte>

Descargar la cobertura correspondiente a Madrid, preferiblemente en GeoPackage
u otro formato vectorial con geometrías y atributos completos.

Esta fuente se utilizará principalmente para:

- `GC_ROAD_ES`.
- `GC_ROAD_SEGMENT_ES`.
- Contrastar y completar la geometría de los viales de OSM.

Es especialmente importante para los segmentos de vial y los rangos de
numeración, que no están garantizados en OpenStreetMap.

## 4. Documentación de Oracle Geocoder

**Estructuras de datos para geocodificación:**

<https://docs.oracle.com/en/database/oracle/oracle-database/26/spatl/data-structures-geocoding.html>

**Geocodificación de direcciones:**

<https://docs.oracle.com/en/database/oracle/oracle-database/26/spatl/geocoding-address-data.html>

Oracle utiliza, entre otras, las siguientes tablas:

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

La estructura exacta debe obtenerse de la instalación Oracle que se vaya a
utilizar, ya que puede variar según la versión y el proveedor de datos.

## 5. Organización local recomendada

```text
datos_espaciales/
├── CARTOCIUDAD_CALLEJERO_MADRID.zip
├── madrid-260831-free.gpkg.zip
└── RT_MADRID_shp.zip
```

### Estado de los ficheros disponibles

#### Geofabrik

`datos_espaciales/madrid-260831-free.gpkg.zip` contiene `madrid.gpkg`, con
datos de OpenStreetMap actualizados hasta `2026-08-31T20:21:20Z`. El GeoPackage
incluye, entre otras, estas capas:

```text
gis_osm_roads_free
gis_osm_buildings_a_free
gis_osm_adminareas_a_free
gis_osm_places_free
gis_osm_places_a_free
gis_osm_pois_free
gis_osm_pois_a_free
gis_osm_transport_free
gis_osm_railways_free
```

#### Redes de Transporte del CNIG

`datos_espaciales/RT_MADRID_shp.zip` contiene las capas de Redes de Transporte
en Shapefile. Las más relevantes para el ETL son:

```text
rt_tramo_vial
rt_portalpk_p
rt_puntoctra_p
rt_nodoctra_p
rt_areactra_s
```

El propio fichero `leeme_RT_Prov_shp.txt` indica que los datos están en ETRS89
geográfico (EPSG:4258) y que `rt_tramo_vial` relaciona la geometría del tramo
con la información alfanumérica del vial.

#### CartoCiudad

`datos_espaciales/CARTOCIUDAD_CALLEJERO_MADRID.zip` contiene
`CARTOCIUDAD_CALLEJERO_MADRID/madrid.gpkg`, en ETRS89 geográfico (EPSG:4258).
Las capas disponibles son:

```text
portalpk_publi  (930532 puntos)
manzana         (73751 polígonos)
```

La capa `portalpk_publi` contiene, entre otros, los campos `id_porpk`,
`tipo_vial`, `nombre_via`, `numero`, `extension`, `id_pob`, `poblacion`,
`cod_postal`, `ine_mun`, `municipio`, `provincia`, `comunidad_autonoma`,
`fuente_datos` y `fecha_modificacion`. Es la fuente principal para construir
`GC_ADDRESS_POINT_ES` y relacionar los portales con viales, áreas y códigos
postales.

La capa `manzana` contiene `id_manz`, `alta_db` e `ine_mun`, y puede utilizarse
como información catastral auxiliar.

## 6. Comprobación de las descargas

Después de descargar los ficheros, comprobar las capas y los campos con GDAL:

```bash
ogrinfo -ro -so -al datos_espaciales/madrid.gpkg
ogrinfo -ro -so -al datos_espaciales/rt_tramo_vial.shp
```

Para inspeccionar los GeoPackage y Shapefile directamente dentro de los ZIP,
GDAL permite usar `/vsizip/`. También se pueden descomprimir en directorios
separados antes de ejecutar el ETL.

Para obtener el DDL de las tablas Oracle:

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

No es necesario descargar inicialmente el PBF nacional de España. Para el
prototipo de Madrid, el GeoPackage regional de Geofabrik es suficiente.
