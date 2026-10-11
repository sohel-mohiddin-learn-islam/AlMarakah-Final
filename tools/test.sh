#!/usr/bin/env bash
# Reusable for Codespaces and CI. Report exact failures even when Godot exits nonzero.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p build/verification
# Never import generated exports, diagnostic scripts or screenshots into the game.
touch build/.gdignore

checked_run() {
  local log="$1"
  shift
  local status=0

  if "$@" 2>&1 | tee "$log"; then
    status=0
  else
    status=$?
  fi

  if grep -E 'SCRIPT ERROR|Parse Error|Compile Error|ERROR:' "$log"; then
    echo "Godot reported an error; see $log" >&2
    status=1
  fi

  if [ "$status" -ne 0 ]; then
    echo "=== FAILURE DIAGNOSTICS: $log ===" >&2
    grep -n -E 'FAIL:|SCRIPT ERROR|Parse Error|Compile Error|ERROR:|TESTS:' "$log" || true
    return "$status"
  fi
}

checked_run build/verification/import.log timeout 180 "$GODOT" --headless --editor --path . --import
for script in tests/test_*.gd; do
  log="build/verification/$(basename "$script" .gd).log"
  if checked_run "$log" timeout 120 "$GODOT" --headless --path . --script "$script"; then
    if ! grep -Eq 'ALMARAKAH.*TESTS: [0-9]+ checks, 0 failures$' "$log"; then
      echo "=== TEST SUMMARY FAILURE: $script ===" >&2
      grep -n -E 'FAIL:|SCRIPT ERROR|Parse Error|Compile Error|ERROR:|TESTS:' "$log" || true
      exit 1
    fi
  else
    exit $?
  fi
done
printf '\nAll Almarakah test suites passed without logged engine errors.\n'
