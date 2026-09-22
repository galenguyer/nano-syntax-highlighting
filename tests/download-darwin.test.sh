#!/bin/bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck disable=SC1091
source "$root/install.sh"

work=$(mktemp -d)
payload="$work/payload"
printf 'nanorc-ok\n' > "$payload"
url="file://${payload}"

set +e
wget -O "$work/red.zip" "$url" >"$work/red.out" 2>"$work/red.err"
red=$?
set -e
if [ "$red" -eq 0 ]; then
  echo "wget unexpectedly succeeded" >&2
  exit 1
fi
if ! grep -q "command not found" "$work/red.err"; then
  echo "expected wget command not found" >&2
  cat "$work/red.err" >&2
  exit 1
fi

_download "$work/green.zip" "$url"
cmp -s "$payload" "$work/green.zip"
echo "download darwin ok (wget exit $red)"
rm -rf "$work"
