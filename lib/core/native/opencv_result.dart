import 'dart:ffi';

/// Dart mirror of the C `OpenCvResult` struct (native_opencv.h).
///
/// Payload only — there is intentionally NO `status` field: status is the
/// function's return value, the single source of truth, so it can never drift
/// from a duplicate struct member. Image ops fill [data]/[dataLen]; scalar ops
/// fill [scalar] and leave [data] null.
///
/// Field order matches C; Dart computes the ABI padding (the [Double] lands at
/// the 8-aligned offset after the [Int32] + 4 bytes padding) automatically.
final class OpenCvResult extends Struct {
  external Pointer<Uint8> data;

  @Int32()
  external int dataLen;

  @Double()
  external double scalar;
}
