import 'dart:ffi';
import 'dart:io' show Platform;

import 'opencv_result.dart';

/// Operation selector mirroring the `OpenCvOp` enum in native_opencv.h.
abstract final class OpenCvOp {
  static const int grayscale = 0; // image op  -> data/dataLen
  static const int blurScore = 1; // scalar op -> scalar (C++ stubbed at 42.0)
}

// --- C signatures (hand-written; the contract is 2 symbols + 1 struct, so
//     ffigen + a libclang toolchain would be pure overhead here) ---

// int32_t opencv_process(const uint8_t*, int32_t, int32_t, OpenCvResult*)
// Native typedef is private (used only as a lookupFunction type argument); the
// Dart-callable typedef is public because it's the type of an exposed field.
typedef _ProcessNative =
    Int32 Function(Pointer<Uint8>, Int32, Int32, Pointer<OpenCvResult>);
typedef OpenCvProcessFn =
    int Function(Pointer<Uint8>, int, int, Pointer<OpenCvResult>);

// void opencv_free_buffer(uint8_t*)
typedef _FreeNative = Void Function(Pointer<Uint8>);
typedef OpenCvFreeBufferFn = void Function(Pointer<Uint8>);

/// Resolved FFI symbols for `libnative_opencv`.
///
/// Created via [OpenCvBindings.load] INSIDE a worker isolate by the FFI data
/// source. The [DynamicLibrary] handle and the looked-up function references
/// are isolate-bound — they are never returned across an isolate boundary.
class OpenCvBindings {
  OpenCvBindings._(this.process, this.freeBuffer);

  final OpenCvProcessFn process;
  final OpenCvFreeBufferFn freeBuffer;

  /// Opens the library on the CURRENT isolate and resolves both symbols.
  /// Call this from within the worker isolate, never on the main isolate.
  static OpenCvBindings load() {
    final lib = _open();
    return OpenCvBindings._(
      lib.lookupFunction<_ProcessNative, OpenCvProcessFn>('opencv_process'),
      lib.lookupFunction<_FreeNative, OpenCvFreeBufferFn>('opencv_free_buffer'),
    );
  }

  /// Dual-platform loader. Only Android is wired today; the iOS branch is
  /// forward-design so iOS becomes a build-only change, not a code change.
  static DynamicLibrary _open() {
    if (Platform.isAndroid) {
      // Android ships the symbols in a standalone .so loaded by name.
      return DynamicLibrary.open('libnative_opencv.so');
    }
    if (Platform.isIOS) {
      // iOS STATICALLY links the FFI symbols into the app executable — there is
      // no standalone .so to open, and iOS forbids dlopen of arbitrary paths.
      // .process() resolves against the running process's global symbol table
      // (executable + statically-linked libs), which is where the symbols live.
      return DynamicLibrary.process();
    }
    throw UnsupportedError(
      'OpenCV FFI is not supported on this platform (${Platform.operatingSystem}).',
    );
  }
}
