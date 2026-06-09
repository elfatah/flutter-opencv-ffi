// native_opencv.cpp — TOOLCHAIN STUB. No OpenCV linked.
//
// Purpose: prove the build + load + FFI round-trip works end to end BEFORE the
// OpenCV SDK is introduced (the link step most likely to fight the build is
// deliberately isolated to its own session). These implementations return
// hardcoded payloads so the Dart side can confirm:
//   * libnative_opencv.so builds and loads via DynamicLibrary.open
//   * the out-pointer struct is filled and read back correctly
//   * the image path (data buffer) and scalar path both work
//   * opencv_free_buffer frees C-allocated memory without crashing
//
// The allocator contract established here is permanent: `data` is always
// malloc'd on the C side and freed with free() in opencv_free_buffer. The real
// OpenCV impl will memcpy a cv::Mat's bytes into a malloc'd buffer — same free.

#include "native_opencv.h"

#include <cstdlib>  // malloc, free
#include <cstring>  // memcpy

extern "C" {

int32_t opencv_process(const uint8_t* input, int32_t input_len, int32_t op_code,
                       OpenCvResult* out) {
  // Defensive: a null out-pointer is a caller bug, not a recoverable state.
  if (out == nullptr) {
    return CV_ERR_INVALID_INPUT;
  }

  // Initialise to the "scalar/error" shape: no buffer to free unless we set one.
  out->data = nullptr;
  out->data_len = 0;
  out->scalar = 0.0;

  switch (op_code) {
    case OP_GRAYSCALE: {
      // Image op: return a tiny fixed buffer so Dart can exercise the copy-out
      // + free path. Real impl will return encoded grayscale bytes here.
      const uint8_t stub_bytes[] = {0xDE, 0xAD, 0xBE, 0xEF};
      const int32_t n = static_cast<int32_t>(sizeof(stub_bytes));
      auto* buf = static_cast<uint8_t*>(malloc(static_cast<size_t>(n)));
      if (buf == nullptr) {
        return CV_ERR_NATIVE;  // allocation failure
      }
      memcpy(buf, stub_bytes, static_cast<size_t>(n));
      out->data = buf;
      out->data_len = n;
      return CV_OK;
    }

    case OP_BLUR_SCORE: {
      // Scalar op: no buffer, fixed metric. Real impl returns Laplacian variance.
      out->scalar = 42.0;
      return CV_OK;
    }

    default:
      return CV_ERR_UNKNOWN_OP;
  }
}

void opencv_free_buffer(uint8_t* data) {
  free(data);  // matches malloc above; free(nullptr) is a safe no-op
}

}  // extern "C"
