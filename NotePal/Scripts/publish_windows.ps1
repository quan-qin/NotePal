param(
    [string] $Runtime = "win-x64",
    [string] $Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptRoot
$projectPath = Join-Path $projectRoot "Windows\NotePal.Windows\NotePal.Windows.csproj"
$publishDir = Join-Path $projectRoot "build\windows\NotePal-$Runtime"

if (Test-Path $publishDir) {
    Remove-Item $publishDir -Recurse -Force
}

dotnet publish $projectPath `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    -o $publishDir `
    /p:PublishSingleFile=true `
    /p:IncludeNativeLibrariesForSelfExtract=true `
    /p:EnableCompressionInSingleFile=true

$exePath = Join-Path $publishDir "NotePal.exe"
if (-not (Test-Path $exePath)) {
    throw "Publish finished but NotePal.exe was not found at $exePath"
}

Write-Host "Published $exePath"
