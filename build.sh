#!/usr/bin/env bash
# Cross-compile switcherit for Windows from Linux.
# On Windows, use build.ps1 instead. This script needs the Cloud Agent
# toolchain: Odin, lld-link, llvm-rc, and a Windows SDK in winsysroot layout.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$root"

configuration=release
console=0

usage() {
  echo "usage: ./build.sh [-Configuration debug|release] [-Console]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Configuration)
      configuration="${2:?-Configuration requires debug or release}"
      shift 2
      ;;
    -Console)
      console=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

case "$configuration" in
  debug|release) ;;
  *)
    echo "configuration must be debug or release, got: $configuration" >&2
    exit 2
    ;;
esac

version="${SWITCHERIT_VERSION:-dev}"
if [[ "$version" =~ ^v(.+)$ ]]; then
  version="${BASH_REMATCH[1]}"
fi

numeric=()
IFS='.-' read -ra version_parts <<< "$version"
for part in "${version_parts[@]}"; do
  if [[ "$part" =~ ^[0-9]+$ ]]; then
    numeric+=("$part")
  else
    break
  fi
done
while ((${#numeric[@]} < 4)); do
  numeric+=(0)
done
version_quad="${numeric[0]}.${numeric[1]}.${numeric[2]}.${numeric[3]}"
version_comma="${numeric[0]},${numeric[1]},${numeric[2]},${numeric[3]}"

sdk="${SWITCHERIT_WINDOWS_SDK:-/opt/windows-sdk}"

for tool in odin lld-link llvm-rc; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool was not found in PATH." >&2
    exit 1
  fi
done

if [[ ! -d "$sdk/Windows Kits/10/Lib" || ! -d "$sdk/VC/Tools/MSVC" ]]; then
  echo "Windows SDK was not found at $sdk." >&2
  exit 1
fi

icon="$root/assets/switcherit-tray.ico"
manifest_template="$root/assets/switcherit.manifest"
if [[ ! -f "$icon" ]]; then
  echo "Tray icon was not found: $icon" >&2
  exit 1
fi
if [[ ! -f "$manifest_template" ]]; then
  echo "Application manifest template was not found: $manifest_template" >&2
  exit 1
fi

out_dir="$root/build"
mkdir -p "$out_dir"
manifest="$out_dir/switcherit.manifest"
rc="$out_dir/switcherit.rc"
res="$out_dir/switcherit.res"
out_exe="$out_dir/switcherit.exe"

sed "s/__SWITCHERIT_VERSION_QUAD__/${version_quad}/g" "$manifest_template" > "$manifest"

cat > "$rc" <<EOF
1 ICON "${icon}"
1 24 "${manifest}"
1 VERSIONINFO
FILEVERSION ${version_comma}
PRODUCTVERSION ${version_comma}
FILEFLAGSMASK 0x3fL
FILEFLAGS 0x0L
FILEOS 0x40004L
FILETYPE 0x1L
FILESUBTYPE 0x0L
BEGIN
  BLOCK "StringFileInfo"
  BEGIN
    BLOCK "040904b0"
    BEGIN
      VALUE "CompanyName", "switcherit\\0"
      VALUE "FileDescription", "switcherit\\0"
      VALUE "FileVersion", "${version}\\0"
      VALUE "InternalName", "switcherit.exe\\0"
      VALUE "OriginalFilename", "switcherit.exe\\0"
      VALUE "ProductName", "switcherit\\0"
      VALUE "ProductVersion", "${version}\\0"
    END
  END
  BLOCK "VarFileInfo"
  BEGIN
    VALUE "Translation", 0x409, 1200
  END
END
EOF

llvm-rc /nologo /fo "$res" "$rc"

linker_flags="/ignore:4099 ${res}"
if [[ "$console" -eq 0 ]]; then
  linker_flags="/subsystem:WINDOWS ${linker_flags}"
fi

odin_flags=(
  build "$root/src"
  "-out:${out_exe}"
  -target:windows_amd64
  -linker:lld
  "-windows-sdk-root:${sdk}"
  -vet
  "-define:SWITCHERIT_VERSION=${version}"
  "-extra-linker-flags:${linker_flags}"
)

if [[ "$configuration" == release ]]; then
  odin_flags+=(-o:speed)
else
  odin_flags+=(-debug)
fi

odin "${odin_flags[@]}"
echo "Built ${out_exe}"
