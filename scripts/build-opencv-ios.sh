#!/usr/bin/env bash
#
# build-opencv-ios.sh — reproducible recipe for the TRIMMED opencv2.xcframework.
#
# WHAT THIS PRODUCES
#   A size-optimized opencv2.xcframework containing ONLY the three OpenCV
#   modules this app uses — core, imgproc, imgcodecs — built for iOS device
#   (ios-arm64) and iOS simulator (ios-arm64-simulator), arm64-only, no macOS /
#   Catalyst / visionOS slices.
#
#   Measured result vs. a full-module build (OpenCV 4.12.0):
#     device slice    56 MB -> 28 MB   (~50%)
#     simulator slice 22 MB -> 11 MB   (~50%)
#     xcframework     90 MB -> 47 MB   (~48%)
#
#   The reduction comes from two trims, both load-bearing-safe (the integration
#   test — grayscale -> PNG, blur -> Laplacian variance — passes after it):
#     1. --without: drop the ~10 modules outside core/imgproc/imgcodecs's
#        dependency closure (calib3d, features2d, flann, highgui, ml, objdetect,
#        photo, stitching, video, videoio) plus dnn/gapi/objc.
#     2. --disable: drop every image codec except PNG + JPEG (WEBP, OPENEXR,
#        TIFF, JASPER, OPENJPEG, AVIF, JPEGXL, the IMGCODEC_* extras) and
#        PROTOBUF. PNG/JPEG stay ON — grayscale returns PNG, input may be JPEG.
#
# REQUIREMENTS
#   - OpenCV 4.12.0 SOURCE checked out locally (this builds from source — it is
#     NOT the prebuilt OpenCV iOS framework, which has no arm64-simulator slice).
#     Get it from https://github.com/opencv/opencv/releases/tag/4.12.0
#   - Xcode + command line tools, CMake, python3.
#
# USAGE
#   OPENCV_SRC=/path/to/opencv-4.12.0 ./scripts/build-opencv-ios.sh
#   (defaults to ../opencv-4.12.0 relative to this repo if OPENCV_SRC is unset)
#
# OUTPUT
#   Writes <OPENCV_SRC>/build_ios_trimmed/opencv2.xcframework. Copy it to the
#   in-repo default path (the xcframework is gitignored):
#     rm -rf third_party/opencv-ios/opencv2.xcframework
#     cp -R "$OPENCV_SRC/build_ios_trimmed/opencv2.xcframework" third_party/opencv-ios/
#   ...or point OPENCV_IOS_DIR at build_ios_trimmed's parent. Then:
#     (cd ios && pod install)
#     flutter test integration_test/ffi_roundtrip_test.dart   # on an arm64 simulator
#
set -euo pipefail

# Resolve the OpenCV 4.12.0 source tree.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OPENCV_SRC="${OPENCV_SRC:-$(cd "$REPO_ROOT/.." && pwd)/opencv-4.12.0}"

if [[ ! -f "$OPENCV_SRC/platforms/apple/build_xcframework.py" ]]; then
  echo "ERROR: OpenCV 4.12.0 source not found at: $OPENCV_SRC" >&2
  echo "       Set OPENCV_SRC to your opencv-4.12.0 checkout, e.g.:" >&2
  echo "       OPENCV_SRC=/path/to/opencv-4.12.0 $0" >&2
  exit 1
fi

echo "Building trimmed opencv2.xcframework from: $OPENCV_SRC"

# --build_only_specified_archs is REQUIRED: without it, build_xcframework.py
# supplies default macOS + Catalyst archs (x86_64,arm64) and builds those fat
# slices too, ballooning the xcframework. The flag suppresses every platform we
# don't explicitly give archs for, leaving exactly the two iOS slices.
python3 "$OPENCV_SRC/platforms/apple/build_xcframework.py" \
  --out "$OPENCV_SRC/build_ios_trimmed" \
  --build_only_specified_archs \
  --iphoneos_archs arm64 \
  --iphonesimulator_archs arm64 \
  --without calib3d --without features2d --without flann \
  --without highgui --without ml --without objdetect \
  --without photo --without stitching --without video --without videoio \
  --without dnn --without gapi --without objc \
  --disable WEBP --disable OPENEXR --disable TIFF --disable JASPER \
  --disable OPENJPEG --disable AVIF --disable JPEGXL \
  --disable IMGCODEC_HDR --disable IMGCODEC_SUNRASTER \
  --disable IMGCODEC_PXM --disable IMGCODEC_PFM \
  --disable PROTOBUF

echo
echo "Done: $OPENCV_SRC/build_ios_trimmed/opencv2.xcframework"
echo "Next: copy it to third_party/opencv-ios/ (see header), then pod install + integration test."
