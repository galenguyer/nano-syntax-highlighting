#!/usr/bin/env bash
# Exercise install.sh in an isolated $HOME with a minimal $PATH so we can
# verify the wget/curl detection logic (and the unzip guard) without
# touching the real ~/.nanorc or ~/.nano.
#
# Use bash, not zsh: this is a bash script and should be invoked as
#   ./tool/test-install.sh
# (the shebang picks the right interpreter). Pasting the body into an
# interactive zsh session will break on `#` comments and `(...)` tokens
# because zsh treats those as glob qualifiers unless `interactive_comments`
# is set.
#
# Usage:
#   tool/test-install.sh [-l|--lite] [--keep] [--quiet]
#     -l, --lite   pass -l through to install.sh
#     --keep       keep the temp $HOME and $PATH dirs for post-mortem
#     --quiet      suppress install.sh stdout/stderr (still shows exit code
#                  and resulting .nanorc)

set -u

INSTALL_ARGS=()
KEEP=0
QUIET=0
for arg in "$@"; do
  case "$arg" in
    -l|--lite) INSTALL_ARGS+=("-l") ;;
    --keep)    KEEP=1 ;;
    --quiet)   QUIET=1 ;;
    -h|--help)
      sed -n '2,19p' "$0"
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

BASE="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$BASE/install.sh"

if [[ ! -x "$INSTALL" ]]; then
  echo "cannot find executable install.sh at $INSTALL" >&2
  exit 1
fi

# Build a minimal bin dir with everything install.sh needs EXCEPT wget/curl.
# We toggle wget/curl in and out per scenario by adding/removing symlinks.
TESTBIN=$(mktemp -d -t nanorc-testbin.XXXXXX)
for t in bash sh awk grep sed unzip mkdir mv rm rmdir touch cp ln cat echo \
         dirname basename nano tr cut head tail env mktemp printf chmod; do
  src=$(command -v "$t" 2>/dev/null) || continue
  ln -sf "$src" "$TESTBIN/$t"
done

HOMES=()

cleanup() {
  if (( KEEP )); then
    echo
    echo "KEEP: leaving TESTBIN=$TESTBIN"
    for h in "${HOMES[@]}"; do echo "KEEP: leaving HOME=$h"; done
  else
    rm -rf "$TESTBIN"
    for h in "${HOMES[@]}"; do rm -rf "$h"; done
  fi
}
trap cleanup EXIT

FAIL=0

run_scenario() {
  local label="$1" expect="$2"
  local home
  home=$(mktemp -d -t nanorc-home.XXXXXX)
  HOMES+=("$home")

  echo
  echo "=============================================================="
  echo "  $label   (expect exit $expect)"
  echo "=============================================================="

  local rc
  if (( QUIET )); then
    HOME="$home" PATH="$TESTBIN" bash "$INSTALL" "${INSTALL_ARGS[@]}" \
      >/dev/null 2>&1
    rc=$?
  else
    HOME="$home" PATH="$TESTBIN" bash "$INSTALL" "${INSTALL_ARGS[@]}"
    rc=$?
  fi

  echo "--- exit=$rc ---"
  if [[ -f "$home/.nanorc" ]]; then
    echo "--- resulting \$HOME/.nanorc has $(wc -l <"$home/.nanorc" | tr -d ' ') lines ---"
  else
    echo "--- no \$HOME/.nanorc written ---"
  fi

  if [[ "$rc" -ne "$expect" ]]; then
    echo "FAIL: $label expected exit $expect, got $rc" >&2
    FAIL=1
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# 1. Missing unzip (early guard at the top of install.sh).
rm -f "$TESTBIN/unzip"
run_scenario "no unzip" 1
have unzip && ln -sf "$(command -v unzip)" "$TESTBIN/unzip"

# 2. Neither wget nor curl.
rm -f "$TESTBIN/wget" "$TESTBIN/curl"
run_scenario "no wget, no curl" 1

# 3. curl only.
if have curl; then
  ln -sf "$(command -v curl)" "$TESTBIN/curl"
  run_scenario "curl only" 0
else
  echo "SKIP: curl not installed on this host"
fi

# 4. wget only.
rm -f "$TESTBIN/curl"
if have wget; then
  ln -sf "$(command -v wget)" "$TESTBIN/wget"
  run_scenario "wget only" 0
else
  echo "SKIP: wget not installed on this host; can't exercise wget-only path"
fi

# 5. Both present. install.sh prefers wget.
have curl && ln -sf "$(command -v curl)" "$TESTBIN/curl"
have wget && ln -sf "$(command -v wget)" "$TESTBIN/wget"
if have wget && have curl; then
  run_scenario "both (wget preferred)" 0
else
  echo "SKIP: need both wget and curl for the 'both' scenario"
fi

echo
if (( FAIL )); then
  echo "RESULT: at least one scenario failed"
  exit 1
fi
echo "RESULT: all scenarios passed"
