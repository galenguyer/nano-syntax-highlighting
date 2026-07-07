#! /usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "$0")/../"

verstr=$(nano --version 2>/dev/null | awk '/GNU nano/ {print ($3=="version")? $4: substr($5,2)}')
branch=$(./install.sh --find_suitable_branch)

echo "Current nano version: ${verstr}"
echo "Switching to ${branch}"
git checkout "${branch}"
