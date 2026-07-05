#!/bin/bash
# Generate the content of nanorc

set -Eeuo pipefail

base="$(dirname "$0")/../"

if ! ls "$base"/*.nanorc &>/dev/null; then
    echo "No .nanorc files"
    exit 1
fi
rm -f "$base/nanorc"
for n in "$base"/*.nanorc; do
    printf 'include "~/.nano/%s"\n' "$(basename "$n")" >> "$base/nanorc"
done
