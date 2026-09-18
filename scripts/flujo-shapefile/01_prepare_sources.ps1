[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$WorkDir,

    [Parameter(Position = 1)]
    [ValidateSet('--force')]
    [string]$Force
)

$ErrorActionPreference = 'Stop'
$arguments = @($WorkDir)
if (-not [string]::IsNullOrWhiteSpace($Force)) {
    $arguments += $Force
}
& (Join-Path $PSScriptRoot '..\01_prepare_sources.ps1') @arguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
