#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
helper="$script_dir/rerun-failed-tests.sh"
tmp_dir="$script_dir/rerun-test.$$"
mkdir "$tmp_dir"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "$tmp_dir/LastTestsFailed.log" <<'EOF'
781:freesurf
784:freesurf_ltd_np4
815:linearsolvers_cmplx
963:staged_sim
42:test+special
781:freesurf
EOF

actual="$(bash "$helper" --print-regex "$tmp_dir/LastTestsFailed.log" | tail -n 1)"
expected='^(freesurf|freesurf_ltd_np4|linearsolvers_cmplx|staged_sim|test\+special)$'

if [[ "$actual" != "$expected" ]]; then
  echo "expected: $expected" >&2
  echo "actual:   $actual" >&2
  exit 1
fi

# Negative control for the original defect: the same numeric position mapped
# to fluxsolver2 in the unfiltered list. Name-based replay must never select it.
if [[ "$actual" == *fluxsolver2* ]]; then
  echo "numeric-position replay leaked fluxsolver2 into the exact-name regex" >&2
  exit 1
fi

printf 'not-a-ctest-failure-line\n' > "$tmp_dir/malformed.log"
if bash "$helper" --print-regex "$tmp_dir/malformed.log" >/dev/null 2>&1; then
  echo "malformed failure list was accepted" >&2
  exit 1
fi

echo "PASS: exact names retained, duplicates removed, regex escaped, malformed input rejected"
