import 'package:equatable/equatable.dart';

import 'failure_codes.dart';

/// Domain-level failure types returned via [Either<Failure, T>].
///
/// Identical shape to the Clean Architecture template: a [sealed] [Equatable]
/// base with a human [message] and an optional machine-readable [code]. Sealed
/// means exhaustive `switch` handling with no default branch, and — importantly
/// — every subtype MUST live in this same library, which is why the FFI
/// failures below are declared here rather than in the data layer.
sealed class Failure extends Equatable {
  const Failure({this.message = '', this.code});

  final String message;

  /// Optional machine-readable code for domain branching logic.
  /// Use constants from [FailureCode] — never compare against raw string literals.
  final String? code;

  @override
  List<Object?> get props => [message, code];
}

// --- FFI / OpenCV failures. One per native_opencv.h status code, plus the two
// Dart-side conditions (allocation failure, contract violation). The repository
// maps OpenCvException.status -> one of these. ---

/// Native imdecode produced an empty Mat. Maps from CV_ERR_DECODE (-1).
class DecodeFailure extends Failure {
  const DecodeFailure({
    super.message = 'Failed to decode the input image.',
    super.code = FailureCode.decodeFailed,
  });
}

/// Input bytes empty or dimensions invalid. Maps from CV_ERR_INVALID_INPUT (-2).
class InvalidInputFailure extends Failure {
  const InvalidInputFailure({
    super.message = 'The input image was empty or invalid.',
    super.code = FailureCode.invalidInput,
  });
}

/// Native imencode failed. Maps from CV_ERR_ENCODE (-3).
class EncodeFailure extends Failure {
  const EncodeFailure({
    super.message = 'Failed to encode the processed image.',
    super.code = FailureCode.encodeFailed,
  });
}

/// Unrecognised op_code. Maps from CV_ERR_UNKNOWN_OP (-4).
class UnsupportedOperationFailure extends Failure {
  const UnsupportedOperationFailure({
    super.message = 'The requested operation is not supported.',
    super.code = FailureCode.unsupportedOp,
  });
}

/// Caught native/OpenCV exception, or a contract violation (status OK but no
/// data). Maps from CV_ERR_NATIVE (-99) and the Dart-side null-data sentinel.
class NativeFailure extends Failure {
  const NativeFailure({
    super.message = 'A native processing error occurred.',
    super.code = FailureCode.nativeError,
  });
}

/// Dart-side allocation for native interop failed. Maps from the malloc sentinel.
class MemoryFailure extends Failure {
  const MemoryFailure({
    super.message = 'Failed to allocate memory for image processing.',
    super.code = FailureCode.outOfMemory,
  });
}
