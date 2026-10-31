#!/usr/bin/env bash
# Set the Immich album filter (comma-separated UUIDs; blank clears it).
set -euo pipefail
cd "$(dirname "$0")"

[ -f .env ] || cp .env.example .env

echo "Albums visible to the current key (requires album.read):"
curl -s --max-time 15 http://127.0.0.1:8099/albums | python3 -m json.tool 2>/dev/null || true
echo
echo "Tip: the album UUID is in the Immich URL: /albums/<uuid>"
printf 'Album UUID(s), comma-separated (blank to clear): '
read -r ids

umask 077
touch .env
tmp=.env.tmp
grep -v '^IMMICH_ALBUM_IDS=' .env > "$tmp" 2>/dev/null || true
printf 'IMMICH_ALBUM_IDS=%s\n' "$ids" >> "$tmp"
mv "$tmp" .env
chmod 600 .env

docker compose up -d --force-recreate
echo '--- verifying ---'
curl -s --max-time 10 http://127.0.0.1:8099/health || true
echo
curl -s -o /dev/null -w 'photo: http %{http_code}  type %{content_type}  bytes %{size_download}\n' \
  --max-time 25 http://127.0.0.1:8099/photo || true
