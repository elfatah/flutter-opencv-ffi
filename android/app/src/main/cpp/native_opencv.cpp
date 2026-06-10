// native_opencv.cpp — FFI implementation.
//
// Allocator contract (permanent): out->data is always malloc'd on the C side
// and freed with free() in opencv_free_buffer. Dart copies the bytes out, then
// calls opencv_free_buffer — whoever allocates frees.
//
// When HAVE_OPENCV is defined, OP_GRAYSCALE runs real cv:: code; the #else
// branch keeps the file compiling (and the probe round-trip working) without
// the SDK by returning the deadbeef stub. OP_BLUR_SCORE stays stubbed (slice 2).
//
// All cv:: calls are wrapped in try/catch: an OpenCV exception becomes
// CV_ERR_NATIVE and never unwinds across the FFI boundary (that would be UB).

#include "native_opencv.h"

#include <cstdlib>  // malloc, free
#include <cstring>  // memcpy

#ifdef HAVE_OPENCV
#include <vector>
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/imgcodecs.hpp>
#endif

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
#ifdef HAVE_OPENCV
      // Real grayscale: encoded bytes in -> decode -> gray -> encode PNG out.
      if (input == nullptr || input_len <= 0) {
        return CV_ERR_INVALID_INPUT;
      }
      try {
        // Wrap the input bytes (no copy) as a 1xN buffer for imdecode.
        const cv::Mat encoded(1, input_len, CV_8UC1,
                              const_cast<uint8_t*>(input));
        const cv::Mat img = cv::imdecode(encoded, cv::IMREAD_COLOR);
        if (img.empty()) {
          return CV_ERR_DECODE;
        }

        cv::Mat gray;
        cv::cvtColor(img, gray, cv::COLOR_BGR2GRAY);

        std::vector<uchar> png;
        if (!cv::imencode(".png", gray, png)) {
          return CV_ERR_ENCODE;
        }

        // Copy encoded bytes into a malloc'd buffer Dart will free (contract).
        const int32_t n = static_cast<int32_t>(png.size());
        auto* buf = static_cast<uint8_t*>(malloc(static_cast<size_t>(n)));
        if (buf == nullptr) {
          return CV_ERR_NATIVE;  // allocation failure
        }
        memcpy(buf, png.data(), static_cast<size_t>(n));
        out->data = buf;
        out->data_len = n;
        return CV_OK;
      } catch (const cv::Exception&) {
        return CV_ERR_NATIVE;  // OpenCV failure -> mapped, never unwinds across FFI
      } catch (...) {
        return CV_ERR_NATIVE;
      }
#else
      // No OpenCV: deadbeef stub so the file compiles/loads without the SDK.
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
#endif
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
