#!/usr/bin/env bash

# Re-run the exact CTest names recorded by the failed invocation.
#
# CTest's --rerun-failed replays numeric positions from LastTestsFailed.log.
# If the first invocation used -L/-LE/-R/-E and the diagnostic invocation does
# not repeat exactly those filters, a position can name a different test.  The
# workflow therefore reads the recorded names and constructs anchored -R
# expressions instead.

set -euo pipefail

mode=rerun
if [[ "${1:-}" == "--print-regex" ]]; then
  mode=print-regex
  shift
fi

failures_file="${1:-Testing/Temporary/LastTestsFailed.log}"
if [[ ! -s "$failures_file" ]]; then
  echo "::error::CTest failure list is missing or empty: $failures_file" >&2
  exit 1
fi

failed_tests=()
while IFS= read -r test_name; do
  [[ -n "$test_name" ]] && failed_tests+=("$test_name")
done < <(sed -nE 's/^[[:space:]]*[0-9]+:(.+)$/\1/p' "$failures_file" | LC_ALL=C sort -u)

if (( ${#failed_tests[@]} == 0 )); then
  echo "::error::No CTest names could be parsed from $failures_file" >&2
  exit 1
fi

escape_ere() {
  local escaped="$1"
  local char
  for char in '\' '.' '^' '$' '*' '+' '?' '(' ')' '[' ']' '{' '}' '|'; do
    escaped="${escaped//"$char"/\\$char}"
  done
  printf '%s' "$escaped"
}

escaped_tests=()
for test_name in "${failed_tests[@]}"; do
  escaped_tests+=("$(escape_ere "$test_name")")
done

joined=""
for escaped_test in "${escaped_tests[@]}"; do
  [[ -n "$joined" ]] && joined+="|"
  joined+="$escaped_test"
done
exact_regex="^(${joined})$"

echo "Recorded failed tests (${#failed_tests[@]}): ${failed_tests[*]}"
echo "Exact rerun regex: $exact_regex"

if [[ "$mode" == "print-regex" ]]; then
  printf '%s\n' "$exact_regex"
  exit 0
fi

for test_name in "${failed_tests[@]}"; do
  base_test="$(printf '%s' "$test_name" | sed -E 's/_np[0-9]+$//')"
  if [[ -d "fem/tests/$base_test" ]]; then
    test_root="fem/tests/$base_test"
  elif [[ -d "elmerice/Tests/$base_test" ]]; then
    test_root="elmerice/Tests/$base_test"
  else
    echo "::warning::No build-tree test directory for $test_name"
    continue
  fi

  echo "::group::Content of $test_root"
  ls -Rl "$test_root"
  for log in "$test_root"/test-stderr*.log "$test_root"/test-stdout*.log; do
    [[ -f "$log" ]] || continue
    echo "---- Content of $log ----"
    cat "$log"
  done
  echo "::endgroup::"
done

echo "::group::Re-run exact failed test names"
ctest -R "$exact_regex" --output-on-failure --timeout "${CTEST_RERUN_TIMEOUT:-180}" || true
echo "::endgroup::"

echo "::group::Log from these tests"
[[ ! -f Testing/Temporary/LastTest.log ]] || cat Testing/Temporary/LastTest.log
echo "::endgroup::"
