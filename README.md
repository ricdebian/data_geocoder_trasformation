# Transformación CartoCiudad para Oracle Geocoder

Este directorio contiene una conversión inicial de GeoPackage de CartoCiudad u
OpenStreetMap/Geofabrik a Shapefile, usando GDAL.

## Uso

```bash
./convert_cartociudad.sh /ruta/provincia.gpkg ./salida ES
```

El resultado se genera en `EPSG:4326`, con codificación UTF-8 y geometrías
promovidas a multipartes cuando es necesario.

## Geofabrik como fuente complementaria

Geofabrik distribuye extractos diarios de OpenStreetMap. Para España ofrece el
PBF nacional y extractos regionales; estos últimos también tienen descarga
`*.gpkg.zip`, por ejemplo:

```text
https://download.geofabrik.de/europe/spain/madrid-latest-free.gpkg.zip
```

Para este proyecto es preferible un extracto regional en GeoPackage frente al
PBF nacional de aproximadamente 1,4 GB:

```bash
unzip madrid-latest-free.gpkg.zip -d madrid
./convert_cartociudad.sh madrid/*.gpkg ./salida OSM_MAD
```

Geofabrik/OSM aporta una cobertura más amplia de viales, edificios, lugares y
otros elementos que CartoCiudad, pero no es equivalente a un callejero oficial:
la presencia de `addr:housenumber`, `addr:street`, `addr:postcode` y sus
relaciones administrativas depende de la zona y de las contribuciones OSM.
Debe utilizarse como complemento o fuente de contraste, no asumir que todos los
portales están cubiertos.

## Relación con el geocoder estándar de Oracle

Oracle Spatial usa, entre otras, estas tablas:

| Tabla Oracle | Contenido necesario | Origen |
|---|---|---|
| `GC_ADDRESS_POINT_ES` | Coordenadas de portales | CartoCiudad `portalpk_publi`; OSM `addr:*` como complemento |
| `GC_ROAD_ES` | Viales normalizados | Geofabrik/OSM `highway` + Redes de Transporte |
| `GC_ROAD_SEGMENT_ES` | Segmentos y rangos de numeración | Redes de Transporte y portales; OSM puede completar geometría |
| `GC_AREA_ES` | Comunidades, provincias, municipios y poblaciones | Tablas auxiliares CartoCiudad; límites OSM como apoyo |
| `GC_POSTAL_CODE_ES` | Códigos postales y geometrías | Fuente oficial/CartoCiudad; OSM como contraste |
| `GC_POI_ES` | Puntos de interés, si se desean | Geofabrik/OSM |

Por tanto, el GeoPackage de CartoCiudad por provincia no permite construir
correctamente todo el conjunto Oracle por sí solo. La capa `manzana` es útil como
referencia catastral espacial, pero no sustituye a `GC_ROAD_SEGMENT_ES`.

### Uso de la documentación Oracle

La documentación de Oracle se utilizará únicamente como referencia funcional
para diseñar la transformación y el mapeo de datos hacia las tablas españolas
`GC_*_ES`. Permitirá identificar el propósito de cada tabla, sus relaciones y
los atributos necesarios para integrar áreas, códigos postales, viales,
segmentos, portales y puntos de interés.

La estructura real del geocoder no se recreará mediante `CREATE TABLE` manuales.
Las tablas, tipos de datos, restricciones, índices espaciales, metadatos de
`SDO_GEOMETRY` y objetos auxiliares deberán crearse posteriormente mediante los
scripts y procedimientos oficiales de Oracle correspondientes a la versión
instalada. El modelo preparado durante esta fase solo sirve para orientar la
transformación y la carga posterior en el esquema oficial.

### Creación de objetos Oracle y perfiles de lenguaje

El procedimiento detallado está documentado en
[`objetos_gc_oracle.md`](objetos_gc_oracle.md).

Antes de ejecutar la carga final:

1. Ejecutar los scripts oficiales de Oracle Geocoder para crear el perfil de
   país, las tablas `GC_*_ES`, sus restricciones, tipos, metadatos e índices.
2. Ejecutar la configuración oficial de los perfiles del parser y asociar el
   idioma español al país `ES`. Deben verificarse las abreviaturas y tipos de
   vía, normalización de acentos, alias y reglas de entrada.
3. Validar que `GC_COUNTRY_PROFILE`, `GC_PARSER_PROFILES`,
   `GC_PARSER_PROFILEAFS` y las tablas españolas existan y estén relacionadas
   según la documentación de la versión instalada.
4. Extraer el DDL real con `DBMS_METADATA.GET_DDL` y adaptar después
   `sql/04_load_gc_es_adapter.sql` a ese esquema.
5. Probar el parser y una geocodificación en español antes de cargar el ETL.

Los nombres de perfiles, códigos de idioma y procedimientos no se fijan en
este repositorio porque dependen de la versión de Oracle Geocoder y del
proveedor de datos. Los scripts oficiales deben incorporarse, si procede, en
`sql/oracle_official/`, sin credenciales ni datos sensibles.

## Siguiente paso técnico

Para generar y validar un cargador exacto para `GC_*_ES` hay que:

1. Un GeoPackage provincial real (`ogrinfo -so -al fichero.gpkg`).
2. Las capas/campos del producto Redes de Transporte.
3. Utilizar la documentación Oracle como referencia durante la transformación.
4. Validar, cuando exista acceso, los nombres, tipos y campos obligatorios
   contra los objetos oficiales creados por los scripts de Oracle.

El Shapefile es un formato intermedio válido para `ogr2ogr`/carga espacial, pero
no conserva algunas capacidades de Oracle (por ejemplo, restricciones,
índices y tipos específicos). La carga final debe crear `SDO_GEOMETRY` e índices
espaciales en Oracle.

## Licencia

Los datos de Geofabrik proceden de OpenStreetMap y están bajo ODbL. La
atribución a OpenStreetMap y el cumplimiento de las obligaciones de ODbL deben
mantenerse también en los datos derivados y en su distribución.
