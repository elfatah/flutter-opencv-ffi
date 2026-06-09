// TOOLCHAIN PROBE — TEMPORARY. Delete once real architecture lands.
//
// This file deliberately uses dart:ffi directly and does NOT follow the
// "dart:ffi in exactly two files" rule. It exists only to prove the native
// boundary works end to end before any OpenCV or real Dart logic is written:
//   * libnative_opencv.so builds and loads (DynamicLibrary.open)
//   * the out-pointer struct is filled by C++ and read back in Dart
//   * the image-buffer path and the scalar path both round-trip
//   * opencv_free_buffer frees C-allocated memory without crashing
//
// Run on a connected arm64 device/emulator:  flutter run
// Expect the screen to show ALL CHECKS PASSED with the stub values.

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart'; // malloc
import 'package:flutter/material.dart';

// --- Dart mirror of the C contract (native_opencv.h) ---------------------

// Mirrors: typedef struct { uint8_t* data; int32_t data_len; double scalar; }
// Field order matches C; Dart computes ABI padding (the double lands at the
// 8-aligned offset 16 after the int32 + 4 bytes padding) automatically.
final class OpenCvResult extends Struct {
  external Pointer<Uint8> data;

  @Int32()
  external int dataLen;

  @Double()
  external double scalar;
}

// int32_t opencv_process(const uint8_t*, int32_t, int32_t, OpenCvResult*)
typedef _ProcessNative =
    Int32 Function(Pointer<Uint8>, Int32, Int32, Pointer<OpenCvResult>);
typedef _ProcessDart =
    int Function(Pointer<Uint8>, int, int, Pointer<OpenCvResult>);

// void opencv_free_buffer(uint8_t*)
typedef _FreeNative = Void Function(Pointer<Uint8>);
typedef _FreeDart = void Function(Pointer<Uint8>);

const int opGrayscale = 0;
const int opBlurScore = 1;

class _Native {
  _Native._(this.process, this.freeBuffer);

  final _ProcessDart process;
  final _FreeDart freeBuffer;

  static _Native open() {
    final lib = DynamicLibrary.open('libnative_opencv.so');
    return _Native._(
      lib.lookupFunction<_ProcessNative, _ProcessDart>('opencv_process'),
      lib.lookupFunction<_FreeNative, _FreeDart>('opencv_free_buffer'),
    );
  }
}

// --- Probe logic ---------------------------------------------------------

/// One line per check, with pass/fail, accumulated into the report.
class ProbeReport {
  final List<String> lines = [];
  bool ok = true;

  void check(String label, bool passed, [String detail = '']) {
    ok = ok && passed;
    lines.add('${passed ? "✅" : "❌"} $label${detail.isEmpty ? "" : " — $detail"}');
  }
}

ProbeReport runProbe() {
  final r = ProbeReport();

  final _Native native;
  try {
    native = _Native.open();
    r.check('DynamicLibrary.open(libnative_opencv.so)', true);
  } catch (e) {
    r.check('DynamicLibrary.open(libnative_opencv.so)', false, '$e');
    return r; // nothing else can run without the library
  }

  // --- Image-buffer path: OP_GRAYSCALE returns {0xDE,0xAD,0xBE,0xEF} ---
  {
    // Dart owns the input buffer AND the result struct; both freed in finally.
    final input = malloc<Uint8>(1)..value = 0;
    final out = malloc<OpenCvResult>();
    try {
      final status = native.process(input, 1, opGrayscale, out);
      r.check('grayscale status == CV_OK(0)', status == 0, 'got $status');

      final dataPtr = out.ref.data;
      final len = out.ref.dataLen;
      r.check('grayscale data non-null', dataPtr != nullptr);
      r.check('grayscale data_len == 4', len == 4, 'got $len');

      if (dataPtr != nullptr && len > 0) {
        // Copy out into Dart-owned memory, THEN free the C buffer.
        final bytes = Uint8List.fromList(dataPtr.asTypedList(len));
        native.freeBuffer(dataPtr); // C allocator frees what it allocated
        final hex = bytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        r.check('grayscale bytes == deadbeef', hex == 'deadbeef', '0x$hex');
      }
    } finally {
      malloc.free(input); // Dart frees Dart-allocated input
      malloc.free(out); //   Dart frees Dart-allocated result struct
    }
  }

  // --- Scalar path: OP_BLUR_SCORE returns scalar 42.0, data == NULL ---
  {
    final out = malloc<OpenCvResult>();
    try {
      final status = native.process(nullptr, 0, opBlurScore, out);
      r.check('blur_score status == CV_OK(0)', status == 0, 'got $status');
      r.check('blur_score data == null', out.ref.data == nullptr);
      r.check('blur_score scalar == 42.0', out.ref.scalar == 42.0,
          'got ${out.ref.scalar}');
    } finally {
      malloc.free(out);
    }
  }

  // --- Error path: unknown op returns CV_ERR_UNKNOWN_OP(-4) ---
  {
    final out = malloc<OpenCvResult>();
    try {
      final status = native.process(nullptr, 0, 99, out);
      r.check('unknown op status == -4', status == -4, 'got $status');
    } finally {
      malloc.free(out);
    }
  }

  return r;
}

// --- UI ------------------------------------------------------------------

void main() => runApp(const ProbeApp());

class ProbeApp extends StatelessWidget {
  const ProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final report = runProbe();
    return MaterialApp(
      title: 'FFI Toolchain Probe',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FFI Toolchain Probe'),
          backgroundColor: report.ok ? Colors.green : Colors.red,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.ok ? 'ALL CHECKS PASSED' : 'CHECKS FAILED',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: report.ok ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: report.lines
                      .map((l) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(l,
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 14)),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
