# Copilot instructions for this repository

## Repository purpose

This repository prepares spatial source data for an Oracle Geocoder workflow. The project is not a typical app with a build pipeline; it is an ETL/data transformation pipeline that converts vector source data into Oracle-friendly staging tables and then maps them to the `GC_*_ES` model used by Oracle Spatial/Geocoder.

The main references are:

- `README.md`: describes the overall ETL flow and the Oracle Geocoder mapping.
- `FLUJO_TRABAJO_ETL_ORACLE_MADRID.md`: detailed ETL design for the Madrid dataset.
- `scripts/README.md`: operational script flow for raw downloads, conversion and Oracle staging loads.

## Build, test, and validation commands

There is no app build, package manager, lint runner, or unit test suite in this repository.

The repository validates work through GDAL/Oracle ETL scripts and SQL checks:

```bash
# 1) Prepare source archives and inventory them
./scripts/01_prepare_sources.sh ./work

# 2) Convert all supported source layers to Shapefile in EPSG:4326
./scripts/00_convert_sources_to_shapefile.sh ./work

# 3) Create Oracle staging tables and metadata
sqlplus usuario/password@servicio @sql/01_create_staging.sql

# 4) Load prepared shapefiles into Oracle staging tables
./scripts/02_load_staging.sh ./work usuario/password@servicio GEOCODER

# 5) Transform raw staging data into canonical STG_GC_*_ES tables
sqlplus usuario/password@servicio @sql/02_transform_staging.sql

# 6) Validate counts and basic consistency before final Oracle load
sqlplus usuario/password@servicio @sql/03_validate_staging.sql

# 7) Postal-code transformation and examples of final GC_*_ES inserts
sqlplus usuario/password@servicio @sql/04_transform_postal_code.sql
```

For a single validation step, prefer the smallest relevant Oracle script. The closest thing to a focused check is:

```bash
sqlplus usuario/password@servicio @sql/03_validate_staging.sql
```

The repo also expects `ogrinfo`, `ogr2ogr`, `unzip`, and an Oracle OCI connection (`sqlplus`) to be present. The scripts fail fast with clear messages when those dependencies are missing.

## High-level architecture

### 1) Inputs and raw source files

The project operates on spatial source packages under `datos_espaciales/` and uses script-driven extraction/inspection:

- `scripts/01_prepare_sources.sh` unpacks the source ZIPs and inventories each dataset using `ogrinfo`.
- It expects a work directory containing raw sources and an inventory folder.

### 2) Shapefile conversion layer

The conversion step is intentionally a compatibility bridge for the Oracle ETL:

- `scripts/00_convert_sources_to_shapefile.sh` finds all `.gpkg` sources, inspects layer names, and converts them to Shapefile.
- Shapefiles are retained when already available and are also reprojected to `EPSG:4326`.
- GeoPackage layers are converted with `-nlt PROMOTE_TO_MULTI`, UTF-8 encoding, and `-t_srs EPSG:4326`.

This layer is an intermediate representation, not the final Oracle target schema.

### 3) Oracle staging tables

`sql/01_create_staging.sql` is the master DDL script for the canonical staging
schema. It includes:

- `sql/staging/01_create_tables.sql` for the canonical tables.
- `sql/staging/02_create_spatial_metadata.sql` for `SDO_GEOMETRY` metadata.
- `sql/staging/03_create_spatial_indexes.sql` for spatial indexes.

The important canonical staging tables are:

- `STG_GC_ADDRESS_POINT_ES`
- `STG_GC_ROAD_ES`
- `STG_GC_ROAD_SEGMENT_ES`
- `STG_GC_AREA_ES`
- `STG_GC_POSTAL_CODE_ES`
- `STG_GC_POI_ES`

Those tables include `SDO_GEOMETRY` columns, spatial metadata entries in `USER_SDO_GEOMETRY_METADATA`, and spatial indexes using `MDSYS.SPATIAL_INDEX`.

### 4) Staging load from shapefiles

`scripts/02_load_staging.sh` loads several source layers into Oracle via
`ogr2ogr -f OCI` and creates source staging tables with names like:

- `STG_CARTO_PORTAL`
- `STG_CARTO_MANZANA`
- `STG_OSM_ROAD`
- `STG_OSM_POI`
- `STG_OSM_AREA`
- `STG_RT_TRAMO_VIAL`
- `STG_RT_PORTAL`
- `STG_RT_PUNTOCTRA`
- `STG_RT_NODOCTRA`

This is the bridge between source data and the canonical geocoder transformation tables.

The source staging tables are intentionally not hard-coded in the SQL DDL: their
columns depend on the concrete CartoCiudad, Geofabrik, and CNIG Networks of
Transport packages. `ogr2ogr` creates them from the source layer schema. The
canonical `STG_GC_*_ES` objects, their spatial metadata, and their indexes are
defined explicitly in `sql/staging/`.

### 5) Transformation and validation

The SQL scripts do the actual ETL logic:

- `sql/02_transform_staging.sql`: cleans and normalizes source data into the canonical `STG_GC_*_ES` tables.
- `sql/03_validate_staging.sql`: checks the staging data for counts, nullability, and structural assumptions before moving to final Oracle tables.
- `sql/04_transform_postal_code.sql`: creates postal-code candidate tables and includes commented examples for the final `GC_*_ES` loading pattern.
- `sql/04_load_gc_es_adapter.sql`: intentionally does not create or alter official Oracle geocoder tables; it is an adapter pattern only and must be aligned with the real Oracle schema installed in the target environment.

## Key conventions in this repository

- Do not treat `GC_*_ES` as a schema that should be recreated manually. The repo explicitly warns against creating the official geocoder tables by hand; use the Oracle installation scripts and procedures for the actual target schema.
- Prefer staging tables and keep the original source IDs (`SOURCE_ID`, `SOURCE_NAME`, `SOURCE_DATE`) throughout the transformation pipeline.
- Maintain spatial metadata (`SDO_GEOMETRY`, SRID `4258`) and spatial indexes when creating Oracle spatial tables.
- Use the project’s source hierarchy: raw downloads -> inventory -> shapefile conversion -> staging load -> canonical `STG_GC_*_ES` transform -> validation -> final geocoder mapping.
- When editing transformations, keep the Oracle Geocoder model in mind, especially these high-value entities:
  - `GC_AREA_ES` (administrative areas)
  - `GC_POSTAL_CODE_ES` (postal code geometry and relations)
  - `GC_ROAD_ES` (normalized roads)
  - `GC_ROAD_SEGMENT_ES` (road segments and address ranges)
  - `GC_ADDRESS_POINT_ES` (address points)
  - `GC_POI_ES` (points of interest)
- Use `EPSG:4326` for shapefile conversion and `EPSG:4258` for the Oracle SRID metadata in the staging tables; this is a specific repo convention, not a generic one.
- The transformation rules are source-specific and often require normalizing street names, types, administrative names, postal codes, and geometry attributes before final Oracle mapping.

## Files to read first when changing ETL behavior

If you need to understand the intent before editing a transformation, read in this order:

1. `README.md`
2. `FLUJO_TRABAJO_ETL_ORACLE_MADRID.md`
3. `scripts/README.md`
4. the relevant script under `scripts/`
5. the matching Oracle SQL script under `sql/`

This is the shortest path to the repository’s actual design and avoids making assumptions about Oracle geocoder schema details.
