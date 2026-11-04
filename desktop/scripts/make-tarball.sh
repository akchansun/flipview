#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(sed -n 's/.*project(Flip VERSION \([0-9.]*\).*/\1/p' CMakeLists.txt | head -n1)"
if [[ -z "${VERSION}" ]]; then
  VERSION="1.0.0"
fi

BUILD_DIR="${ROOT}/build"
if [[ ! -x "${BUILD_DIR}/Flip" ]]; then
  cmake -S "${ROOT}" -B "${BUILD_DIR}" -G Ninja -DCMAKE_BUILD_TYPE=Release
  cmake --build "${BUILD_DIR}"
fi

STAGE="${ROOT}/dist/flip-linux-${VERSION}-amd64"
rm -rf "${STAGE}"
mkdir -p "${STAGE}"
install -m 0755 "${BUILD_DIR}/Flip" "${STAGE}/Flip"
strip --strip-unneeded "${STAGE}/Flip" 2>/dev/null || true
cp "${ROOT}/README.md" "${STAGE}/"
cp "${ROOT}/LICENSE" "${STAGE}/"
cp "${ROOT}/packaging/flip.desktop" "${STAGE}/"
mkdir -p "${STAGE}/icons" "${STAGE}/examples"
cp "${ROOT}/resources/icons/flip.svg" "${STAGE}/icons/"
cp "${ROOT}/examples/"*.png "${STAGE}/examples/" 2>/dev/null || true

ARCHIVE="${ROOT}/dist/flip-linux-${VERSION}-amd64.tar.gz"
tar -C "${ROOT}/dist" -czf "${ARCHIVE}" "flip-linux-${VERSION}-amd64"
echo "Wrote ${ARCHIVE}"
ls -lh "${ARCHIVE}"
