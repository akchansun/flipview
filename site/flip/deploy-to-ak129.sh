#!/usr/bin/env bash
# Run on the Mac that already has Host ak129-vip in ~/.ssh/config
# (root@106.13.236.120, IdentityFile ~/.ssh/ak129_vps, key loaded in ssh-agent).
# Do not run from a cloud agent: that environment cannot unlock ak129_vps.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
HOST="${AK129_SSH_HOST:-ak129-vip}"
DEST="${AK129_FLIP_DIR:-/var/www/static-home/flip}"

for f in index.html version.json download.php download/index.html; do
  if [[ ! -f "${ROOT}/${f}" ]]; then
    echo "missing ${ROOT}/${f}" >&2
    exit 1
  fi
done

ssh -o BatchMode=yes -o IdentitiesOnly=yes "$HOST" "hostname; whoami; ls -ld /var/www/static-home/flip /var/www/cms/flip /var/www/html/flip 2>/dev/null || true"

if ! ssh -o BatchMode=yes -o IdentitiesOnly=yes "$HOST" "test -d '$DEST'"; then
  echo "remote dir missing: ${DEST}" >&2
  echo "set AK129_FLIP_DIR to the directory that currently has flip/index.html" >&2
  exit 1
fi

stamp="$(date +%Y%m%d%H%M%S)"
zip_name="Flip-0.6.16-macos-universal.zip"
zip_url="https://github.com/akchansun/flipview/releases/download/v0.6.16/${zip_name}"
zip_local="${ROOT}/download/${zip_name}"
if [[ ! -f "${zip_local}" ]]; then
  mkdir -p "${ROOT}/download"
  curl -fsSL -o "${zip_local}" "${zip_url}"
fi

ssh -o BatchMode=yes -o IdentitiesOnly=yes "$HOST" "mkdir -p '${DEST}/download'"
ssh -o BatchMode=yes -o IdentitiesOnly=yes "$HOST" bash -s -- "$DEST" "$stamp" <<'REMOTE'
set -euo pipefail
dest="$1"
stamp="$2"
cp -a "${dest}/index.html" "${dest}/index.html.bak.${stamp}" 2>/dev/null || true
cp -a "${dest}/version.json" "${dest}/version.json.bak.${stamp}" 2>/dev/null || true
cp -a "${dest}/download.php" "${dest}/download.php.bak.${stamp}" 2>/dev/null || true
cp -a "${dest}/download/index.html" "${dest}/download/index.html.bak.${stamp}" 2>/dev/null || true
REMOTE

# Overlay HTML/JSON/PHP. Never rsync --delete (would wipe stats.php and old zips).
scp -o BatchMode=yes -o IdentitiesOnly=yes \
  "${ROOT}/index.html" "${ROOT}/version.json" "${ROOT}/download.php" \
  "${HOST}:${DEST}/"
scp -o BatchMode=yes -o IdentitiesOnly=yes \
  "${ROOT}/download/index.html" "${zip_local}" \
  "${HOST}:${DEST}/download/"

ssh -o BatchMode=yes -o IdentitiesOnly=yes "$HOST" bash -s -- "$DEST" "$zip_name" <<'REMOTE'
set -euo pipefail
dest="$1"
zip_name="$2"
ls -l "$dest/index.html" "$dest/version.json" "$dest/download.php" "$dest/download/$zip_name"
grep -o 'macOS 版（0.6.16）' "$dest/index.html"
python3 -c 'import json,sys; p=sys.argv[1]; print(json.load(open(p))["macos"]["version"])' "$dest/version.json"
grep -F '0.6.16' "$dest/download.php"
REMOTE

echo "deployed ${DEST} on ${HOST}"
