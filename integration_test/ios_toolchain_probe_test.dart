// ios_toolchain_probe_test.dart — CHECKPOINT 1 (iOS toolchain proof, NO OpenCV).
//
// The smallest on-device assertion that the iOS native toolchain works end to
// end BEFORE OpenCV is involved: the shared native_opencv.cpp is compiled into
// the app (via native/native_opencv.podspec, with HAVE_OPENCV UNDEFINED), and
// the REAL shipping loader — OpenCvBindings.load(), whose Platform.isIOS branch
// is DynamicLibrary.process() — resolves the FFI symbol on a real iOS image.
//
// With no OpenCV linked, OP_GRAYSCALE takes native_opencv.cpp's #else branch and
// returns the 4-byte 0xDEADBEEF stub, so we assert exactly those bytes. That
// proves three things at once: the C++ compiled & linked into the app, the
// symbol is in the process symbol table, and the full FFI round-trip (call +
// out-pointer payload + free) works — all with zero OpenCV.
//
// It deliberately does NOT use the real-OpenCV oracle in ffi_roundtrip_test.dart
// (valid PNG / positive Laplacian variance): that test stays the Checkpoint 3
// oracle. This isolates "can .process() see the symbol" from "does it survive
// release-strip" (a later checkpoint — debug builds don't run the strip stage).
//
// dart:ffi is imported here on purpose; tool/check_ffi_boundary.sh scopes the
// boundary rule to lib/ only, so integration_test/ is free to touch ffi.

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_ffi_opencv/core/native/opencv_native.dart';
import 'package:flutter_ffi_opencv/core/native/opencv_result.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'iOS toolchain: the real loader resolves opencv_process via '
    'DynamicLibrary.process() and the deadbeef stub round-trips',
    () {
      // Exercises the SHIPPING loader, including its Platform.isIOS ->
      // DynamicLibrary.process() branch. Throws an ArgumentError if the symbol
      // is not in the process symbol table (the negative control).
      final bindings = OpenCvBindings.load();

      final out = calloc<OpenCvResult>();
      final input = calloc<Uint8>(1); // stub ignores input; a valid 1-byte ptr
      try {
        final status = bindings.process(input, 1, OpenCvOp.grayscale, out);

        expect(status, 0, reason: 'opencv_process should return CV_OK (stub)');
        expect(out.ref.dataLen, 4, reason: 'the stub writes exactly 4 bytes');
        expect(out.ref.data, isNot(nullptr));

        final bytes = out.ref.data.asTypedList(out.ref.dataLen);
        expect(
          bytes,
          orderedEquals(<int>[0xDE, 0xAD, 0xBE, 0xEF]),
          reason: 'the deadbeef stub proves the symbol resolved AND the FFI '
              'round-trip works with zero OpenCV',
        );

        // Allocator contract: the C side frees what it malloc'd.
        bindings.freeBuffer(out.ref.data);
      } finally {
        calloc.free(input);
        calloc.free(out);
      }
    },
  );
}
