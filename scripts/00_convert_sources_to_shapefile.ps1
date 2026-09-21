[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$WorkDir,

    [Parameter(Position = 1)]
    [ValidateSet('--force')]
    [string]$Force
)
$env:Path += ";C:\Program Files\QGIS 3.44.4\bin"
$ErrorActionPreference = 'Stop'
$raw = Join-Path $WorkDir 'raw'
$output = Join-Path $WorkDir 'shapefile'

if (-not (Get-Command ogrinfo -ErrorAction SilentlyContinue)) {
    throw 'Falta ogrinfo (GDAL)'
}
if (-not (Get-Command ogr2ogr -ErrorAction SilentlyContinue)) {
    throw 'Falta ogr2ogr (GDAL)'
}
if (-not (Test-Path $raw -PathType Container)) {
    throw "No existe $raw; ejecute 01_prepare_sources.ps1"
}
if ((Test-Path $output -PathType Container) -and $Force -ne '--force') {
    throw "Ya existe $output; use --force para regenerarlo"
}

if (Test-Path $output) {
    Remove-Item -LiteralPath $output -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $output | Out-Null

function Get-SafeName([string]$Name) {
    return $Name -replace '[^a-zA-Z0-9_.-]', '_'
}

Get-ChildItem -Path $raw -Recurse -File -Filter '*.shp' |
    ForEach-Object {
        $relative = $_.FullName.Substring($raw.Length) -replace '^[\\/]+', ''
        $relativeDir = Split-Path -Parent $relative
        $targetDir = if ([string]::IsNullOrWhiteSpace($relativeDir)) {
            $output
        } else {
            Join-Path $output $relativeDir
        }
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

        $base = [System.IO.Path]::ChangeExtension($_.FullName, $null)
        Get-ChildItem -Path "$base.*" -File |
            Copy-Item -Destination $targetDir -Force
    }

Get-ChildItem -Path $raw -Recurse -File -Filter '*.gpkg' |
    ForEach-Object {
        $relative = $_.FullName.Substring($raw.Length) -replace '^[\\/]+', ''
        $sourceDir = Split-Path -Parent $relative
        $dataset = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        $parentDir = if ([string]::IsNullOrWhiteSpace($sourceDir)) {
            $output
        } else {
            Join-Path $output $sourceDir
        }
        $targetDir = Join-Path $parentDir $dataset
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

        $listing = & ogrinfo -ro $_.FullName 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "ogrinfo falló para $($_.FullName)"
        }
        $layers = @(
            $listing |
                Select-String '^\s*\d+:\s*([^\s(]+)' |
                ForEach-Object { $_.Matches[0].Groups[1].Value }
        )
        if ($layers.Count -eq 0) {
            throw "No se encontraron capas en $($_.FullName)"
        }

        foreach ($layer in $layers) {
            $safeLayer = Get-SafeName $layer
            $target = Join-Path $targetDir "$safeLayer.shp"
            Write-Output "Convirtiendo $($_.FullName):$layer -> $target"

            & ogr2ogr -f 'ESRI Shapefile' $target $_.FullName $layer `
                -t_srs EPSG:4326 -nlt PROMOTE_TO_MULTI `
                -lco ENCODING=UTF-8 -overwrite  
            if ($LASTEXITCODE -ne 0) {
                throw "ogr2ogr falló para $($_.FullName):$layer"
            }
        }
    }

Write-Output "Fuentes unificadas en formato Shapefile: $output"
