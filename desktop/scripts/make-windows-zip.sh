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

for required in Flip.exe Qt6Core.dll Qt6Gui.dll Qt6Widgets.dll platforms/qwindows.dll; do
  if [[ ! -f "${STAGE}/${required}" ]]; then
    echo "windows bundle missing ${required}" >&2
    find "${STAGE}" -type f | sort >&2 || true
    exit 1
  fi
done

ARCHIVE="${ROOT}/dist/Flip-${VERSION}-windows-x64.zip"
rm -f "${ARCHIVE}"
tar -a -cf "${ARCHIVE}" -C "${ROOT}/dist" "Flip-${VERSION}-windows-x64"
echo "Wrote ${ARCHIVE}"
ls -lh "${ARCHIVE}"
