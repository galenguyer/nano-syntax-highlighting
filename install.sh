#!/bin/bash
set -e

# check for required tools before we continue
if ! command -v unzip &>/dev/null; then
  echo 'unzip is required but was not found. Install unzip first and then run this script again.' >&2
  exit 1
fi
if ! command -v wget &>/dev/null && ! command -v curl &>/dev/null; then
  echo 'Neither wget nor curl is available. Install either wget or curl and then run this script again.' >&2
  exit 1
fi

_fetch_url() {
  local url="$1"
  local output="$2"
  if command -v wget &>/dev/null; then
    wget -O "$output" "$url"
  elif command -v curl &>/dev/null; then
    curl -o "$output" "$url"
  else
    echo 'Neither wget nor curl is available.' >&2
    exit 1
  fi
}

_fetch_sources() {
  local br
  br=$(_find_suitable_branch)
  mkdir -p ~/.nano/
  cd ~/.nano/

  _fetch_url "https://github.com/galenguyer/nano-syntax-highlighting/archive/${br}.zip" "/tmp/nanorc.zip"
  unzip -o "/tmp/nanorc.zip"
  mv "nano-syntax-highlighting-${br}"/* ./
  rm -rf "nano-syntax-highlighting-${br}"
  rm -f "/tmp/nanorc.zip"
}

_update_nanorc() {
  touch "$NANORC_FILE"
  # add all includes from ~/.nano/nanorc if they're not already there
  while read -r inc; do
      if ! grep -qF "$inc" "${NANORC_FILE}"; then
          echo "$inc" >> "$NANORC_FILE"
      fi
  done < ~/.nano/nanorc
}

_update_nanorc_lite() {
  sed -i .bak '/include "\/usr\/share\/nano\/\*\.nanorc"/i include "~\/.nano\/*.nanorc"' "${NANORC_FILE}"
  rm -f "${NANORC_FILE}.bak"
}

_version_str_to_num() {
  if [ -z "$1" ]; then
    return
  fi
  echo -n "$1" | awk -F . '{printf("%d%02d%02d", $1, $2, $3)}'
}

_find_suitable_branch() {
  local verstr ver target br num
  # find the branch that is suitable for local nano
  verstr=$(nano --version 2>/dev/null | awk '/GNU nano/ {print ($3=="version")? $4: substr($5,2)}')
  ver=$(_version_str_to_num "$verstr")
  if [ -z "$ver" ]; then
    echo "Cannot determine nano's version, fallback to master" >&2
    echo "master"
    return
  fi
  local -a branches=(
    pre-6.0
    pre-5.0
    pre-4.5
    pre-2.9.5
    pre-2.6.0
    pre-2.3.3
    pre-2.1.6
  )
  target="master"
  # find smallest branch that is larger than ver
  for br in "${branches[@]}"; do
    num=$(_version_str_to_num "${br#*pre-}")
    if (( ver < num )); then
      target="${br}"
    else
      break
    fi
  done
  echo "$target"
}


NANORC_FILE=~/.nanorc
UPDATE_LITE=

case "$1" in
 -l|--lite)
   UPDATE_LITE=1
 ;;
 --find_suitable_branch)
  _find_suitable_branch
  exit 0
 ;;
 -h|--help)
   echo "Install script for nanorc syntax highlights"
   echo "Call with -l or --lite to update .nanorc with secondary precedence to existing .nanorc includes"
   exit 0
 ;;
esac

_fetch_sources
if [ "$UPDATE_LITE" ]; then
  _update_nanorc_lite
else
  _update_nanorc
fi
