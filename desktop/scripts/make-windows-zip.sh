#!/usr/bin/env bash
# Stage Flip.exe with Qt runtime libraries (windeployqt) and zip them.
# Intended for Git Bash / MSYS on windows-latest after a Release build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(sed -n 's/.*project(Flip VERSION \([0-9.]*\).*/\1/p' CMakeLists.txt | head -n1)"
if [[ -z "${VERSION}" ]]; then
  VERSION="1.0.0"
fi

EXE=""
for candidate in build/Release/Flip.exe build/Flip.exe; do
  if [[ -f "${candidate}" ]]; then
    EXE="${candidate}"
    break
  fi
done
if [[ -z "${EXE}" ]]; then
  echo "Flip.exe not found under ${ROOT}/build (looked for Release/Flip.exe and Flip.exe)" >&2
  exit 1
fi

if ! command -v windeployqt >/dev/null 2>&1; then
  echo "windeployqt is not on PATH" >&2
  exit 1
fi

to_win() {
  local path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$path"
  else
    printf '%s\n' "$path"
  fi
}

to_unix() {
  local path="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$path"
  else
    printf '%s\n' "$path"
  fi
}

STAGE="${ROOT}/dist/Flip-${VERSION}-windows-x64"
rm -rf "${STAGE}"
mkdir -p "${STAGE}"
cp "${EXE}" "${STAGE}/Flip.exe"
cp "${ROOT}/README.md" "${STAGE}/"
cp "${ROOT}/LICENSE" "${STAGE}/"
mkdir -p "${STAGE}/examples"
cp "${ROOT}/examples/"*.png "${STAGE}/examples/" 2>/dev/null || true

# Git Bash rewrites arguments that look like Unix paths. windeployqt is a Win32 tool.
export MSYS_NO_PATHCONV=1
windeployqt --release --compiler-runtime "$(to_win "${STAGE}/Flip.exe")"

# windeployqt skips the MSVC CRT when VCINSTALLDIR is unset on the runner
# ("Cannot find Visual Studio installation directory"). Copy it explicitly.
copy_msvc_runtime() {
  local vswhere="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
  if [[ ! -f "${vswhere}" ]]; then
    echo "vswhere not found; cannot copy the MSVC runtime" >&2
    return 1
  fi
  local dll crt
  dll="$("${vswhere}" -latest -products '*' \
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
    -find 'VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT/vcruntime140.dll' \
    | tr -d '\r' | sort -V | tail -n1)"
  if [[ -z "${dll}" ]]; then
    echo "vcruntime140.dll not found in the Visual Studio redist" >&2
    return 1
  fi
  crt="$(dirname "$(to_unix "${dll}")")"
  echo "Copying MSVC CRT from ${crt}"
  cp -a "${crt}/"*.dll "${STAGE}/"
}
copy_msvc_runtime

# Image plugins (WebP/TIFF) are loaded by name, so windeployqt may skip them
# unless the Qt imageformats module was scanned. Copy the release plugins we have.
if command -v qmake >/dev/null 2>&1; then
  plugins="$(qmake -query QT_INSTALL_PLUGINS | tr -d '\r')"
  plugins="$(to_unix "${plugins}")"
  if [[ -d "${plugins}/imageformats" ]]; then
    mkdir -p "${STAGE}/imageformats"
    shopt -s nullglob
    for plugin in "${plugins}/imageformats/"*.dll; do
      base="$(basename "${plugin}")"
      if [[ "${base}" == *d.dll ]]; then
        release="${base%d.dll}.dll"
        [[ -f "${plugins}/imageformats/${release}" ]] && continue
      fi
      cp -a "${plugin}" "${STAGE}/imageformats/"
    done
    shopt -u nullglob
  fi
fi

for required in Flip.exe Qt6Core.dll Qt6Gui.dll Qt6Widgets.dll platforms/qwindows.dll \
  imageformats/qjpeg.dll imageformats/qwebp.dll vcruntime140.dll msvcp140.dll; do
  if [[ ! -f "${STAGE}/${required}" ]]; then
    echo "windows bundle missing ${required}" >&2
    find "${STAGE}" -type f | sort >&2 || true
    exit 1
  fi
done

ARCHIVE="${ROOT}/dist/Flip-${VERSION}-windows-x64.zip"
rm -f "${ARCHIVE}"
# Git Bash tar -a writes a POSIX tar even when the name ends in .zip. Use a real zip.
stage_win="$(to_win "${STAGE}")"
archive_win="$(to_win "${ARCHIVE}")"
powershell.exe -NoProfile -Command "Compress-Archive -LiteralPath '${stage_win}' -DestinationPath '${archive_win}' -Force"
magic="$(od -An -tx1 -N2 "${ARCHIVE}" | tr -d ' \n')"
if [[ "${magic}" != "504b" ]]; then
  echo "archive is not a zip (magic ${magic})" >&2
  exit 1
fi
echo "Wrote ${ARCHIVE}"
ls -lh "${ARCHIVE}"
