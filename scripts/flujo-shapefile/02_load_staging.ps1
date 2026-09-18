[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$WorkDir,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$OciConnection,

    [Parameter(Position = 2)]
    [string]$Schema
)

$ErrorActionPreference = 'Stop'
$arguments = @($WorkDir, $OciConnection)
if (-not [string]::IsNullOrWhiteSpace($Schema)) {
    $arguments += $Schema
}
& (Join-Path $PSScriptRoot '..\02_load_staging.ps1') @arguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
