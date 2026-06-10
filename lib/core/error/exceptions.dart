/// Raw exception thrown by the FFI data source.
///
/// Implementation-level concern — never crosses into the domain layer. The
/// repository catches it and maps [status] to a [Failure] subtype before
/// returning an [Either] (same flow as the template's ServerException).
///
/// Holds a single [int] status so the object stays ISOLATE-SENDABLE: the data
/// source throws this inside `Isolate.run`, and a thrown object must be
/// transferable to be re-thrown on the calling isolate. A richer exception
/// (carrying closures, pointers, etc.) could fail to cross the boundary.
class OpenCvException implements Exception {
  const OpenCvException(this.status, [this.message = '']);

  /// A value from [OpenCvStatus]: a native code from native_opencv.h, or a
  /// Dart-side sentinel (allocation failure / null-data contract violation).
  final int status;

  final String message;

  @override
  String toString() =>
      'OpenCvException(status: $status${message.isEmpty ? '' : ', $message'})';
}
