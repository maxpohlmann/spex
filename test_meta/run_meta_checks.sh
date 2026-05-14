#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
INITIAL_DIR="$SCRIPT_DIR/impl_models/initial"
LIVE_DIR="$SCRIPT_DIR/impl_models/live"
EXPECTED_DIR="$SCRIPT_DIR/impl_models/expected"
EXPECTED_SPEX_OUTPUT='[Spex] 2 out of 4 ImplModels are not bisimilar to their specifications.'

# Reset the live fixtures to the known starting state before running meta tests.
find "$LIVE_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -R "$INITIAL_DIR"/. "$LIVE_DIR"/

pushd "$REPO_ROOT" >/dev/null

# Capture test output so successful runs stay quiet, but failures remain debuggable.
set +e
MIX_TEST_OUTPUT="$(META_TESTS=true mix test 2>&1)"
MIX_TEST_EXIT_CODE=$?
set -e

if [[ $MIX_TEST_EXIT_CODE -ne 0 ]]; then
  echo "Error: META_TESTS=true mix test exited with code $MIX_TEST_EXIT_CODE." >&2
  printf '%s\n' "$MIX_TEST_OUTPUT" >&2
  popd >/dev/null
  exit 1
fi

if ! diff -r "$EXPECTED_DIR" "$LIVE_DIR" >/dev/null; then
  echo "Error: test_meta/impl_models/live does not match test_meta/impl_models/expected after META_TESTS=true mix test." >&2
  popd >/dev/null
  exit 1
fi

# mix spex is expected to fail here, so inspect both its exit code and emitted summary.
set +e
SPEX_OUTPUT="$(META_TESTS=true mix spex 2>&1)"
SPEX_EXIT_CODE=$?
set -e

# Strip ANSI/control bytes so the summary check is stable across colored terminal output.
SANITIZED_SPEX_OUTPUT="$(printf '%s' "$SPEX_OUTPUT" | perl -pe 's/\e\[[0-9;?]*[ -\/]*[@-~]//g; s/\r//g')"

if [[ $SPEX_EXIT_CODE -ne 1 ]]; then
  echo "Error: META_TESTS=true mix spex exited with code $SPEX_EXIT_CODE, expected 1." >&2
  printf '%s\n' "$SPEX_OUTPUT" >&2
  popd >/dev/null
  exit 1
fi

if ! printf '%s' "$SANITIZED_SPEX_OUTPUT" | grep -Fq "$EXPECTED_SPEX_OUTPUT"; then
  echo "Error: META_TESTS=true mix spex output did not contain the expected summary." >&2
  printf '%s\n' "$SPEX_OUTPUT" >&2
  popd >/dev/null
  exit 1
fi

popd >/dev/null

echo "Success: meta tests and spex checks behaved as expected."
exit 0