#!/usr/bin/env bash
# Reusable for Codespaces and CI. A Godot exit code alone does not catch script errors.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
mkdir -p build/verification
# Never import generated exports, diagnostic scripts or screenshots into the game.
touch build/.gdignore

checked_run() {
  local log="$1"
  shift
  "$@" 2>&1 | tee "$log"
  if grep -E 'SCRIPT ERROR|Parse Error|Compile Error|ERROR:' "$log"; then
    echo "Godot reported an error; see $log" >&2
    return 1
  fi
}

checked_run build/verification/import.log timeout 180 "$GODOT" --headless --editor --path . --import
for script in tests/test_*.gd; do
  log="build/verification/$(basename "$script" .gd).log"
  checked_run "$log" timeout 120 "$GODOT" --headless --path . --script "$script"
  grep -Eq 'ALMARAKAH.*TESTS: [0-9]+ checks, 0 failures$' "$log"
done
printf '\nAll Almarakah test suites passed without logged engine errors.\n'
