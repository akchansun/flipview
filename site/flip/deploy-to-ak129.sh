#!/usr/bin/env bash
# Run on the Mac that already has Host ak129-vip in ~/.ssh/config
# (root@106.13.236.120, IdentityFile ~/.ssh/ak129_vps, key loaded in ssh-agent).
# Do not run from a cloud agent: that environment cannot unlock ak129_vps.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
HOST="${AK129_SSH_HOST:-ak129-vip}"
DEST="${AK129_FLIP_DIR:-/var/www/cms/flip}"

for f in index.html version.json; do
  if [[ ! -f "${ROOT}/${f}" ]]; then
    echo "missing ${ROOT}/${f}" >&2
    exit 1
  fi
done

ssh -o BatchMode=yes -o IdentitiesOnly=yes "$HOST" "hostname; whoami; ls -ld /var/www /var/www/cms /var/www/cms/flip /var/www/html/flip 2>/dev/null || true"

if ! ssh -o BatchMode=yes -o IdentitiesOnly=yes "$HOST" "test -d '$DEST'"; then
  echo "remote dir missing: ${DEST}" >&2
  echo "set AK129_FLIP_DIR to the directory that currently has flip/index.html" >&2
  exit 1
fi

# Overlay only these two files. Never rsync --delete (would wipe download.php / stats.php).
scp -o BatchMode=yes -o IdentitiesOnly=yes \
  "${ROOT}/index.html" "${ROOT}/version.json" \
  "${HOST}:${DEST}/"

ssh -o BatchMode=yes -o IdentitiesOnly=yes "$HOST" bash -s -- "$DEST" <<'REMOTE'
set -euo pipefail
dest="$1"
ls -l "$dest/index.html" "$dest/version.json"
grep -o 'macOS 版（0.6.16）' "$dest/index.html"
python3 -c 'import json,sys; p=sys.argv[1]; print(json.load(open(p))["macos"]["version"])' "$dest/version.json"
REMOTE

echo "deployed ${DEST} on ${HOST}"
