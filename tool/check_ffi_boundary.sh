#!/usr/bin/env bash
#
# Architectural invariant (README headline): dart:ffi is imported in EXACTLY two
# places — core/native/ and the FFI data source. Domain, repository, and
# presentation NEVER see a Pointer. Uint8List is allowed everywhere (pure
# dart:typed_data, no native lifetime); dart:ffi is confined.
#
# This script fails CI if dart:ffi leaks anywhere else.

set -euo pipefail
cd "$(dirname "$0")/.."

ALLOWED='^lib/core/native/|^lib/features/image_processing/data/datasources/opencv_ffi_datasource\.dart$'

# Match the IMPORT DIRECTIVE, not the bare string — otherwise a comment that
# merely documents this invariant (e.g. "never imports dart:ffi") trips the test.
FFI_IMPORT="import[[:space:]]+['\"]dart:ffi['\"]"

violations="$(grep -rlnE --include='*.dart' "$FFI_IMPORT" lib | grep -vE "$ALLOWED" || true)"

if [[ -n "$violations" ]]; then
  echo "❌ dart:ffi leaked outside the boundary (core/native/ + the FFI data source):"
  echo "$violations" | sed 's/^/   /'
  exit 1
fi

echo "✅ dart:ffi is confined to core/native/ and the FFI data source."
