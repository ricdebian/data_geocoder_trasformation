# Flujo directo desde GeoPackage
# Tiene que estar el directorio de la instalación ogr en PATH
$env:Path += ";C:\Program Files\QGIS 3.44.4\bin"

# Tiene que estar el directorio de la libreria oci.dll en la variable de entorno PATH.
$env:Path += ";C:\Users\mamaberi\instantclient_23_26"

# Hay que forzar a GDAL a buscar plugins en la carpeta correcta de OSGeo4W
$env:GDAL_DRIVER_PATH = "C:\Program Files\QGIS 3.44.4\apps\gdal\lib\gdalplugins"

#Al comando ogr2ogr ha habido que añadir el parametro
-mapFieldType DateTime=String
#para que las fechas las pase a texto porque al cargar en base de datos da error la zona horaria del timestamp.

la base de datos está en WE8ISO8859P1 y los fichero espaciales en UTF-8
Hay que añadir en la ejecución $env:NLS_LANG="SPANISH_SPAIN.UTF8" antes de la carga con ogr2ogr, 
para que caracteres fuera de rango como acentos áéíóú y Ñ se se carguen bien. 

Es importante que las variables siguientes estén creadas:
$env:GDAL_DATA = "C:\Program Files\QGIS 3.44.4\apps\gdal\share\gdal"
$env:PROJ_DATA = "C:\Program Files\QGIS 3.44.4\share\proj"



Este directorio conserva el flujo que carga las capas directamente desde
GeoPackage mediante `ogr2ogr`, sin generar previamente Shapefiles.

```bash
./scripts/flujo-directo-gpkg/01_prepare_sources.sh ./work
./scripts/flujo-directo-gpkg/02_load_staging.sh ./work usuario/password@servicio GEOCODER
```

En PowerShell:

```powershell
.\scripts\flujo-directo-gpkg\01_prepare_sources.ps1 .\work
.\scripts\flujo-directo-gpkg\02_load_staging.ps1 .\work usuario/password@servicio GEOCODER
```

Las tablas canÃ³nicas se crean y transforman con los mismos scripts SQL del
repositorio (`sql/01_create_staging.sql`, `sql/02_transform_staging.sql`, etc.).
