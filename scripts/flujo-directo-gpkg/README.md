# Flujo directo desde GeoPackage

Este flujo carga las capas directamente desde GeoPackage mediante `ogr2ogr`,
sin generar previamente Shapefiles.

## Requisitos de PowerShell

Los scripts PowerShell incluyen rutas del entorno de desarrollo como ejemplo.
Hay que adaptarlas antes de ejecutar el flujo en otro equipo:

```powershell
$env:Path += ";C:\Program Files\QGIS 3.44.4\bin"
$env:Path += ";C:\Users\mamaberi\instantclient_23_26"
$env:GDAL_DRIVER_PATH = "C:\Program Files\QGIS 3.44.4\apps\gdal\lib\gdalplugins"
$env:GDAL_DATA = "C:\Program Files\QGIS 3.44.4\apps\gdal\share\gdal"
$env:PROJ_DATA = "C:\Program Files\QGIS 3.44.4\share\proj"
```

También deben estar disponibles `ogrinfo`, `ogr2ogr` y la biblioteca
`oci.dll` de Oracle Instant Client.

La base de datos de destino utiliza `WE8ISO8859P1` y las fuentes espaciales
están en UTF-8. Antes de cargar con `ogr2ogr`, establecer:

```powershell
$env:NLS_LANG = "SPANISH_SPAIN.UTF8"
```

El script de carga define además estas variables para resolver los valores
temporales y la zona horaria:

```powershell
$env:OGR_FORCE_LOCAL_TIME_ZONE = ""
$env:ORA_SDTZ = "Europe/Madrid"
```

## Ejecución

En Bash:

```bash
./scripts/flujo-directo-gpkg/01_prepare_sources.sh ./work
./scripts/flujo-directo-gpkg/02_load_staging.sh ./work usuario/password@servicio GEOCODER
```

En PowerShell:

```powershell
.\scripts\flujo-directo-gpkg\01_prepare_sources.ps1 .\work
.\scripts\flujo-directo-gpkg\02_load_staging.ps1 .\work usuario/password@servicio GEOCODER
```

Durante la carga OCI se utiliza:

```text
-mapFieldType DateTime=String
```

Esto evita errores de zona horaria al crear las tablas de staging. Las capas se
cargan con geometría `GEOM`, dimensión 2 y SRID `4258`.

Las tablas canónicas se crean y transforman con los mismos scripts SQL del
repositorio (`sql/01_create_staging.sql`, `sql/02_transform_staging.sql`, etc.).
Este flujo no crea ni modifica por sí mismo las tablas oficiales `GC_*_ES`.
