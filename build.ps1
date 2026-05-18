param(
    [ValidateSet("debug", "release")]
    [string] $Configuration = "release",

    [string] $Version = $env:SWITCHERIT_VERSION,

    [switch] $Console
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = "dev"
}

if ($Version -match '^v(.+)$') {
    $Version = $Matches[1]
}

$versionParts = $Version -split '[.-]'
$numericParts = @()
foreach ($part in $versionParts) {
    if ($part -match '^\d+$') {
        $numericParts += [int]$part
    } else {
        break
    }
}
while ($numericParts.Count -lt 4) {
    $numericParts += 0
}
$appVersionQuad = ($numericParts[0..3] -join ".")

if (-not (Get-Command odin -ErrorAction SilentlyContinue)) {
    throw "Odin was not found in PATH. Install Odin and the Windows SDK/MSVC toolchain first."
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$outDir = Join-Path $root "build"
$outExe = Join-Path $outDir "switcherit.exe"
$assetsDir = Join-Path $root "assets"
$iconSvg = Join-Path $assetsDir "switcherit-tray.svg"
$iconIco = Join-Path $assetsDir "switcherit-tray.ico"
$manifestTemplateFile = Join-Path $assetsDir "switcherit.manifest"
$manifestFile = Join-Path $outDir "switcherit.manifest"
$resourceFile = Join-Path $outDir "switcherit.rc"

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if ((-not (Test-Path $iconIco)) -and (Test-Path $iconSvg) -and (Get-Command magick -ErrorAction SilentlyContinue)) {
    magick $iconSvg -background none -define icon:auto-resize=48,32,24,20,16 $iconIco
}

if (-not (Test-Path $iconIco)) {
    throw "Tray icon was not found: $iconIco. Install ImageMagick to generate it from $iconSvg."
}

if (-not (Test-Path $manifestTemplateFile)) {
    throw "Application manifest template was not found: $manifestTemplateFile."
}

$manifestContent = Get-Content -Raw -Path $manifestTemplateFile
$manifestContent = $manifestContent.Replace("__SWITCHERIT_VERSION_QUAD__", $appVersionQuad)
Set-Content -Path $manifestFile -Encoding ASCII -NoNewline -Value $manifestContent

$escapedIconPath = $iconIco.Replace("\", "\\")
$escapedManifestPath = $manifestFile.Replace("\", "\\")
$resourceContent = @(
    "1 ICON `"$escapedIconPath`"",
    "1 24 `"$escapedManifestPath`"",
    "1 VERSIONINFO",
    "FILEVERSION $($appVersionQuad.Replace(".", ","))",
    "PRODUCTVERSION $($appVersionQuad.Replace(".", ","))",
    "FILEFLAGSMASK 0x3fL",
    "FILEFLAGS 0x0L",
    "FILEOS 0x40004L",
    "FILETYPE 0x1L",
    "FILESUBTYPE 0x0L",
    "BEGIN",
    "  BLOCK `"StringFileInfo`"",
    "  BEGIN",
    "    BLOCK `"040904b0`"",
    "    BEGIN",
    "      VALUE `"CompanyName`", `"switcherit\0`"",
    "      VALUE `"FileDescription`", `"switcherit\0`"",
    "      VALUE `"FileVersion`", `"$Version\0`"",
    "      VALUE `"InternalName`", `"switcherit.exe\0`"",
    "      VALUE `"OriginalFilename`", `"switcherit.exe\0`"",
    "      VALUE `"ProductName`", `"switcherit\0`"",
    "      VALUE `"ProductVersion`", `"$Version\0`"",
    "    END",
    "  END",
    "  BLOCK `"VarFileInfo`"",
    "  BEGIN",
    "    VALUE `"Translation`", 0x409, 1200",
    "  END",
    "END"
) -join "`r`n"
Set-Content -Path $resourceFile -Encoding ASCII -NoNewline -Value "$resourceContent`r`n"

$flags = @(
    "build", (Join-Path $root "src"),
    "-out:$outExe",
    "-vet",
    "-resource:$resourceFile",
    "-define:SWITCHERIT_VERSION=$Version"
)

if (-not $Console) {
    $flags += "-subsystem:windows"
}

if ($Configuration -eq "release") {
    $flags += "-o:speed"
} else {
    $flags += "-debug"
}

odin @flags
