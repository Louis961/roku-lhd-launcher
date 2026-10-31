#!/usr/bin/env bash
# Prompt for the Immich API key (hidden), write it to helper/.env, restart.
# The key is never echoed and never put on a command line.
set -euo pipefail
cd "$(dirname "$0")"

[ -f .env ] || cp .env.example .env

printf 'Immich API key (input hidden): '
IFS= read -rs key
printf '\n'
if [ -z "$key" ]; then
  echo "No key entered." >&2
  exit 1
fi

umask 077
touch .env
tmp=.env.tmp
grep -v '^IMMICH_API_KEY=' .env > "$tmp" 2>/dev/null || true
printf 'IMMICH_API_KEY=%s\n' "$key" >> "$tmp"
mv "$tmp" .env
chmod 600 .env

docker compose up -d --force-recreate
echo '--- verifying ---'
curl -s --max-time 8 http://127.0.0.1:8099/health || true
echo
curl -s -o /dev/null -w 'photo: http %{http_code}  type %{content_type}  bytes %{size_download}\n' \
  --max-time 25 http://127.0.0.1:8099/photo || true
