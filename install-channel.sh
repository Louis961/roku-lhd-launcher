#!/usr/bin/env bash
# Upload the sideload zip to the Roku dev installer, then optionally launch it.
# The installer password is read hidden and passed to curl via stdin, never argv.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIP="${1:-$SCRIPT_DIR/lhd-launcher.zip}"

if [ -z "${TV_IP:-}" ]; then
  echo "Set TV_IP, e.g. TV_IP=192.168.1.50 $0" >&2
  exit 1
fi
TV="$TV_IP"

if [ ! -f "$ZIP" ]; then
  echo "zip not found: $ZIP (run ./build.sh first)" >&2
  exit 1
fi

printf 'Roku dev installer password for rokudev (hidden): '
IFS= read -rs pass
printf '\n'
if [ -z "$pass" ]; then
  echo "No password entered." >&2
  exit 1
fi

# Escape backslash and double quote for curl's config parser.
escaped=${pass//\\/\\\\}
escaped=${escaped//\"/\\\"}

echo "Uploading $(basename "$ZIP") to $TV ..."
printf 'user = "rokudev:%s"\n' "$escaped" | curl -sS --digest -K - \
  -F 'mysubmit=Install' \
  -F "archive=@$ZIP" \
  -w '\nHTTP %{http_code}\n' \
  "http://$TV/plugin_install" | tee /tmp/roku-install.out

echo
if grep -qi 'install success\|application received\|success' /tmp/roku-install.out; then
  echo 'UPLOAD_OK'
else
  code=$(grep -o 'HTTP [0-9]*' /tmp/roku-install.out | tail -1)
  echo "No success message ($code)."
  if [ "$code" = "HTTP 401" ]; then
    echo "401 = the installer rejected the password. Verify or reset it in the"
    echo "TV's Developer Settings screen (Home x3, Up x2, Right, Left, Right, Left, Right)."
  fi
fi

printf 'Launch the dev channel now? [y/N] '
read -r answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
  curl -s -o /dev/null -w 'launch: http %{http_code}\n' -X POST "http://$TV:8060/launch/dev"
fi
