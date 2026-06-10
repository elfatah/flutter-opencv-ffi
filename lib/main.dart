// TOOLCHAIN + GRAYSCALE PROBE — TEMPORARY. Delete once real architecture lands.
//
// This file deliberately uses dart:ffi directly and does NOT follow the
// "dart:ffi in exactly two files" rule. It proves the native boundary works
// end to end before the real architecture is built:
//   * libnative_opencv.so builds and loads (DynamicLibrary.open)
//   * the out-pointer struct is filled by C++ and read back in Dart
//   * OP_GRAYSCALE round-trips a REAL image: assets/sample.jpg -> OpenCV
//     decode/cvtColor/encode -> PNG bytes -> displayed below
//   * the scalar path (OP_BLUR_SCORE) and error path round-trip
//   * opencv_free_buffer frees C-allocated memory without crashing
//
// Run on a connected arm64 device/emulator:  flutter run
// Expect GREEN "ALL CHECKS PASSED" plus a grayscale image rendered from the
// bytes OpenCV returned. Requires a real photo at assets/sample.jpg.

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart'; // malloc
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

// --- Dart mirror of the C contract (native_opencv.h) ---------------------

// Mirrors: typedef struct { uint8_t* data; int32_t data_len; double scalar; }
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

// A real encoded image is far larger than the old 4-byte stub. The 1x1
// placeholder produces a ~70-byte PNG and will (correctly) fail this — supply a
// real photo at assets/sample.jpg.
const int minRealImageBytes = 100;

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

/// One line per check plus the grayscale bytes (for rendering).
class ProbeReport {
  final List<String> lines = [];
  bool ok = true;
  Uint8List? grayscaleResult; // PNG bytes returned by OpenCV, for display

  void check(String label, bool passed, [String detail = '']) {
    ok = ok && passed;
    lines.add('${passed ? "✅" : "❌"} $label${detail.isEmpty ? "" : " — $detail"}');
  }
}

ProbeReport runProbe(Uint8List sampleBytes) {
  final r = ProbeReport();

  final _Native native;
  try {
    native = _Native.open();
    r.check('DynamicLibrary.open(libnative_opencv.so)', true);
  } catch (e) {
    r.check('DynamicLibrary.open(libnative_opencv.so)', false, '$e');
    return r;
  }

  // --- Image path: OP_GRAYSCALE on the real sample image ---
  {
    // Dart owns the input buffer AND the result struct; both freed in finally.
    final input = malloc<Uint8>(sampleBytes.length);
    input.asTypedList(sampleBytes.length).setAll(0, sampleBytes);
    final out = malloc<OpenCvResult>();
    try {
      final status = native.process(
          input, sampleBytes.length, opGrayscale, out);
      r.check('grayscale status == CV_OK(0)', status == 0, 'got $status');

      final dataPtr = out.ref.data;
      final len = out.ref.dataLen;
      r.check('grayscale data non-null', dataPtr != nullptr);
      r.check('grayscale data_len is image-sized (> $minRealImageBytes)',
          len > minRealImageBytes, 'got $len bytes');

      if (dataPtr != nullptr && len > 0) {
        // Copy out into Dart-owned memory, THEN free the C buffer.
        final bytes = Uint8List.fromList(dataPtr.asTypedList(len));
        native.freeBuffer(dataPtr);

        // PNG magic number: 89 50 4E 47 — proves a real encoded image, not a stub.
        final isPng = bytes.length >= 4 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47;
        r.check('grayscale bytes are a valid PNG (magic 89 50 4E 47)', isPng);
        if (isPng) r.grayscaleResult = bytes;
      }
    } finally {
      malloc.free(input);
      malloc.free(out);
    }
  }

  // --- Scalar path: OP_BLUR_SCORE returns scalar 42.0 (still stubbed) ---
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sample = await rootBundle.load('assets/sample.jpg');
  final sampleBytes = sample.buffer.asUint8List();
  runApp(ProbeApp(sampleBytes: sampleBytes));
}

class ProbeApp extends StatelessWidget {
  const ProbeApp({super.key, required this.sampleBytes});

  final Uint8List sampleBytes;

  @override
  Widget build(BuildContext context) {
    final report = runProbe(sampleBytes);
    return MaterialApp(
      title: 'FFI Grayscale Probe',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FFI Grayscale Probe'),
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
              const SizedBox(height: 12),
              // Before / after: original JPEG vs OpenCV grayscale PNG.
              Row(
                children: [
                  _labelled('Before (sample.jpg)', Image.memory(sampleBytes)),
                  const SizedBox(width: 12),
                  _labelled(
                    'After (OpenCV gray)',
                    report.grayscaleResult != null
                        ? Image.memory(report.grayscaleResult!)
                        : const SizedBox(
                            height: 120,
                            child: Center(child: Text('—')),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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

  Widget _labelled(String label, Widget child) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          SizedBox(height: 120, child: child),
        ],
      ),
    );
  }
}
