#!/usr/bin/env bash
# Build the sideloadable Roku channel zip from channel/.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
mkdir -p channel/source
(
  cd channel
  rm -f ../lhd-launcher.zip
  zip -qr ../lhd-launcher.zip . -x '.*' -x '*/.*'
)
echo "built $(pwd)/lhd-launcher.zip ($(du -h lhd-launcher.zip | cut -f1))"
