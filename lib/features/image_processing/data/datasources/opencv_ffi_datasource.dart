import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart'; // malloc / free

import '../../../../core/error/exceptions.dart';
import '../../../../core/native/opencv_native.dart';
import '../../../../core/native/opencv_result.dart';
import '../../../../core/native/opencv_status.dart';

/// The ONLY consumer of `dart:ffi` outside `core/native/`.
///
/// Owns the entire native-memory lifetime and the isolate hop. Throws
/// [OpenCvException]; the repository maps it to a [Failure]. By construction, no
/// Pointer and no DynamicLibrary handle ever escapes a worker isolate — only
/// Uint8List / int / double cross the boundary.
abstract interface class OpenCvDataSource {
  /// Returns the encoded PNG bytes of the grayscale image.
  /// Throws [OpenCvException] on any native or Dart-side failure.
  Future<Uint8List> grayscale(Uint8List imageBytes);

  /// Returns a scalar metric (currently the stubbed 42.0 blur score).
  /// Throws [OpenCvException] on any native or Dart-side failure.
  Future<double> blurScore(Uint8List imageBytes);
}

class OpenCvFfiDataSource implements OpenCvDataSource {
  const OpenCvFfiDataSource();

  // Each call hops to a fresh isolate via Isolate.run. The closure captures
  // ONLY `imageBytes` (a Uint8List, copied onto the worker isolate) and a const
  // op code — never `this`, so the data source instance does not cross either.
  //
  // Per-call spawn + dlopen + symbol resolution is accepted because these ops
  // are user-initiated and infrequent (NOT because dlopen is cheap). The seam
  // for a persistent worker is this method signature; swapping it changes only
  // this file.

  @override
  Future<Uint8List> grayscale(Uint8List imageBytes) =>
      Isolate.run(() => _runImageOp(imageBytes, OpenCvOp.grayscale));

  @override
  Future<double> blurScore(Uint8List imageBytes) =>
      Isolate.run(() => _runScalarOp(imageBytes, OpenCvOp.blurScore));
}

// --- Worker-isolate functions. Top-level (not instance methods) so nothing but
//     their plain arguments is captured. Everything native is allocated, used,
//     and freed ENTIRELY within these functions, on the worker isolate. ---

/// Image op: encoded bytes in -> native -> encoded bytes out.
/// Returns a plain Uint8List; throws [OpenCvException] on failure.
Uint8List _runImageOp(Uint8List input, int opCode) {
  // Open the library on THIS (worker) isolate. The handle and function refs are
  // isolate-bound and die here — they are never returned to the caller.
  final bindings = OpenCvBindings.load();

  Pointer<Uint8> inPtr = nullptr;
  Pointer<OpenCvResult> outPtr = nullptr;
  try {
    // Dart owns the input buffer AND the result struct. malloc throws on OOM;
    // the dedicated inner try maps ONLY that to the memory sentinel so an
    // unrelated error can never be mislabelled.
    try {
      inPtr = malloc<Uint8>(input.length);
      outPtr = malloc<OpenCvResult>();
    } catch (_) {
      throw const OpenCvException(OpenCvStatus.outOfMemory);
    }

    inPtr.asTypedList(input.length).setAll(0, input);

    final status = bindings.process(inPtr, input.length, opCode, outPtr);
    if (status != OpenCvStatus.ok) {
      throw OpenCvException(status); // frees still run in the finally below
    }

    final dataPtr = outPtr.ref.data;
    final len = outPtr.ref.dataLen;
    if (dataPtr == nullptr || len <= 0) {
      // Contract violation: OK status but no buffer. Nothing C-side to free.
      throw const OpenCvException(OpenCvStatus.nullData);
    }

    // Copy native bytes into Dart-owned memory, THEN free the C buffer. The
    // returned Uint8List is independent of any native allocation.
    final bytes = Uint8List.fromList(dataPtr.asTypedList(len));
    bindings.freeBuffer(dataPtr); // C frees what C allocated
    return bytes;
  } finally {
    // Dart frees Dart-allocated memory on EVERY path (success, bad status,
    // null-data, OOM-after-first-alloc). free(nullptr) never runs: guarded.
    if (inPtr != nullptr) malloc.free(inPtr);
    if (outPtr != nullptr) malloc.free(outPtr);
  }
}

/// Scalar op: encoded bytes in -> native -> double out. No output buffer is
/// allocated by C (data is null by contract), so there is nothing to free()
/// on the C side. Returns a plain double; throws [OpenCvException] on failure.
double _runScalarOp(Uint8List input, int opCode) {
  final bindings = OpenCvBindings.load();

  Pointer<Uint8> inPtr = nullptr;
  Pointer<OpenCvResult> outPtr = nullptr;
  try {
    try {
      inPtr = malloc<Uint8>(input.length);
      outPtr = malloc<OpenCvResult>();
    } catch (_) {
      throw const OpenCvException(OpenCvStatus.outOfMemory);
    }

    inPtr.asTypedList(input.length).setAll(0, input);

    final status = bindings.process(inPtr, input.length, opCode, outPtr);
    if (status != OpenCvStatus.ok) {
      throw OpenCvException(status);
    }

    return outPtr.ref.scalar;
  } finally {
    if (inPtr != nullptr) malloc.free(inPtr);
    if (outPtr != nullptr) malloc.free(outPtr);
  }
}
