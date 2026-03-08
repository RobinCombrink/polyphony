[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProductVersion,
    [string]$OutputPath = "build/polyphony-installer-local.msi"
)

$ErrorActionPreference = "Stop"

$sourceDir = (Resolve-Path "build/windows/x64/runner/Release").Path
$installerDir = (Resolve-Path "windows/installer").Path

if ($ProductVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
    throw "ProductVersion '$ProductVersion' is invalid. Expected semantic version like 1.2.3"
}

$outputPathResolved = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath
} else {
    Join-Path -Path (Get-Location).Path -ChildPath $OutputPath
}

$outputDir = Split-Path -Path $outputPathResolved -Parent
if (-not (Test-Path -Path $outputDir)) {
    New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
}

heat.exe dir "$sourceDir" -cg AppFiles -dr INSTALLFOLDER -gg -scom -sreg -sfrag -srd -var var.SourceDir -out "$installerDir/Files.wxs"
candle.exe -nologo -arch x64 -out "$installerDir/Product.wixobj" -dSourceDir="$sourceDir" -dProjectDir="$PWD" -dProductVersion="$ProductVersion" "$installerDir/Product.wxs"
candle.exe -nologo -arch x64 -out "$installerDir/Files.wixobj" -dSourceDir="$sourceDir" -dProjectDir="$PWD" -dProductVersion="$ProductVersion" "$installerDir/Files.wxs"
light.exe -nologo -sice:ICE60 -ext WixUIExtension "$installerDir/Product.wixobj" "$installerDir/Files.wixobj" -o "$outputPathResolved"

Write-Host "MSI package created at: $outputPathResolved"
