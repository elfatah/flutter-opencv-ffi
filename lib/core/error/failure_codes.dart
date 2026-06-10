/// Single source of truth for machine-readable domain error codes.
///
/// Always compare [Failure.code] against these constants — never against raw
/// string literals. This makes refactoring safe and keeps branching logic
/// greppable across the codebase. (Same pattern as the Clean Architecture
/// template; the codes here are the FFI/OpenCV domain instead of HTTP.)
abstract final class FailureCode {
  /// Native imdecode produced an empty Mat (corrupt/unsupported image).
  static const String decodeFailed = 'DECODE_FAILED';

  /// Input bytes were empty or had invalid dimensions.
  static const String invalidInput = 'INVALID_INPUT';

  /// Native imencode failed to produce output bytes.
  static const String encodeFailed = 'ENCODE_FAILED';

  /// The requested op_code is not recognised by the native layer.
  static const String unsupportedOp = 'UNSUPPORTED_OP';

  /// A native/OpenCV exception was caught at the boundary.
  static const String nativeError = 'NATIVE_ERROR';

  /// A Dart-side allocation for native interop failed.
  static const String outOfMemory = 'OUT_OF_MEMORY';

  /// Catch-all for errors that don't map to a specific code.
  static const String unknown = 'UNKNOWN';
}
