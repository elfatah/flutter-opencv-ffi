// native_opencv.h — THE FFI CONTRACT.
//
// This header is the single source of truth the Dart bindings (ffigen) and the
// C++ implementation both key off. Written before any implementation.
//
// Design notes (see project plan):
//  * Single entrypoint `opencv_process`, operation selected by `op_code`.
//  * Dual return shape through ONE mechanism: image ops fill `data`/`data_len`;
//    scalar ops fill `scalar` and leave `data == NULL`.
//  * The result crosses by OUT-POINTER, not by value: `opencv_process` returns
//    an int32 status and writes the payload into a caller-owned OpenCvResult.
//    (Returning a mixed int/pointer/double struct by value is the fragile
//    AArch64 ABI corner we deliberately avoid.)
//  * STATUS HAS NO STRUCT FIELD. The int32 return value is the only source of
//    truth for success/failure, so it can never drift from a duplicate field.
//  * Memory: whoever allocates frees. Dart owns the input buffer AND the
//    OpenCvResult struct. C++ owns `data`; Dart copies it out then calls
//    `opencv_free_buffer` so the C++ allocator frees what it allocated.

#ifndef NATIVE_OPENCV_H
#define NATIVE_OPENCV_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Force the symbol into the dynamic table so dlopen/DynamicLibrary can find it,
// even when the linker dead-strips unreferenced code (-Wl,--gc-sections).
#if defined(__GNUC__) || defined(__clang__)
#define FFI_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#else
#define FFI_EXPORT
#endif

// Operation selector. Image ops produce a buffer; scalar ops produce a double.
typedef enum {
  OP_GRAYSCALE = 0,   // image op:  returns bytes in data/data_len
  OP_BLUR_SCORE = 1,  // scalar op: returns Laplacian variance in scalar (slice 2)
} OpenCvOp;

// Payload only — NO status field by design (status is the return value).
typedef struct {
  uint8_t* data;      // C-allocated output bytes; NULL for scalar ops / errors
  int32_t data_len;   // length of `data`; 0 when `data` is NULL
  double scalar;      // scalar metric; valid for scalar ops, else unused
} OpenCvResult;

// Status codes returned by opencv_process. 0 == OK, negatives map to Failures.
typedef enum {
  CV_OK = 0,
  CV_ERR_DECODE = -1,       // imdecode produced an empty Mat   -> DecodeFailure
  CV_ERR_INVALID_INPUT = -2,// empty/oversized input, bad dims  -> InvalidInputFailure
  CV_ERR_ENCODE = -3,       // imencode failed                  -> EncodeFailure
  CV_ERR_UNKNOWN_OP = -4,   // unrecognised op_code             -> UnsupportedOperationFailure
  CV_ERR_NATIVE = -99,      // caught C++/OpenCV exception       -> NativeFailure
} OpenCvStatus;

// Process `input` (encoded image bytes for image ops) under `op_code`.
// Writes the payload into the caller-owned `*out`. Returns an OpenCvStatus.
// On any non-zero status, `out->data` is NULL and nothing needs C-side freeing.
FFI_EXPORT int32_t opencv_process(const uint8_t* input, int32_t input_len,
                                  int32_t op_code, OpenCvResult* out);

// Frees a buffer previously written into out->data by opencv_process.
// Dart calls this (never malloc.free) because the C++ allocator owns `data`.
FFI_EXPORT void opencv_free_buffer(uint8_t* data);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // NATIVE_OPENCV_H
