/// Dart mirror of the native status codes in native_opencv.h, plus two
/// Dart-side sentinels for conditions that never reach C.
///
/// PURE DART — deliberately no `dart:ffi` import — so the repository (above the
/// boundary) can map on these codes without importing the FFI layer. The data
/// source throws [OpenCvException] carrying one of these; the repository's
/// switch turns it into a [Failure].
abstract final class OpenCvStatus {
  static const int ok = 0;

  // --- Native codes (from native_opencv.h) ---
  static const int decodeError = -1; // CV_ERR_DECODE
  static const int invalidInput = -2; // CV_ERR_INVALID_INPUT
  static const int encodeError = -3; // CV_ERR_ENCODE
  static const int unknownOp = -4; // CV_ERR_UNKNOWN_OP
  static const int nativeError = -99; // CV_ERR_NATIVE

  // --- Dart-side sentinels (never returned by C) ---
  /// A Dart-side malloc for native interop failed.
  static const int outOfMemory = -100;

  /// Native returned OK but data == null when a buffer was expected.
  static const int nullData = -101;
}
