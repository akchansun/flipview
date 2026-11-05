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
mkdir -p "${ROOT}/download"

zip_name="Flip-0.6.16-macos-universal.zip"
zip_url="https://github.com/akchansun/flipview/releases/download/v0.6.16/${zip_name}"
zip_local="${ROOT}/download/${zip_name}"
if [[ ! -f "${zip_local}" ]]; then
  curl -fsSL -o "${zip_local}" "${zip_url}"
fi

linux_name="flip-linux-1.3.0-amd64.tar.gz"
linux_url="https://github.com/akchansun/flipview/releases/download/desktop-1.3.0/${linux_name}"
linux_local="${ROOT}/download/${linux_name}"
if [[ ! -f "${linux_local}" ]]; then
  curl -fsSL -o "${linux_local}" "${linux_url}"
fi

win_name="Flip-1.3.0-windows-x64.zip"
win_url="https://github.com/akchansun/flipview/releases/download/desktop-1.3.0/${win_name}"
win_local="${ROOT}/download/${win_name}"
if [[ ! -f "${win_local}" ]]; then
  curl -fsSL -o "${win_local}" "${win_url}"
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
  "${ROOT}/download/index.html" "${zip_local}" "${linux_local}" "${win_local}" \
  "${HOST}:${DEST}/download/"

ssh -o BatchMode=yes -o IdentitiesOnly=yes "$HOST" bash -s -- "$DEST" "$zip_name" "$linux_name" "$win_name" <<'REMOTE'
set -euo pipefail
dest="$1"
zip_name="$2"
linux_name="$3"
win_name="$4"
ls -l "$dest/index.html" "$dest/version.json" "$dest/download.php" \
  "$dest/download/$zip_name" "$dest/download/$linux_name" "$dest/download/$win_name"
grep -o 'macOS 版（0.6.16）' "$dest/index.html"
grep -F 'flip-linux-1.3.0-amd64.tar.gz' "$dest/index.html"
grep -F 'Flip-1.3.0-windows-x64.zip' "$dest/index.html"
python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); print(d["macos"]["version"], d["linux"]["version"], d["windows"]["version"])' "$dest/version.json"
grep -F '0.6.16' "$dest/download.php"
REMOTE

echo "deployed ${DEST} on ${HOST}"
