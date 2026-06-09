# CMakeLists.txt — builds libnative_opencv.so
#
# This session: STUB ONLY. Builds with zero OpenCV present.
# The OpenCV wiring below is in place but gated behind WITH_OPENCV (default OFF)
# so the build is already correct when the SDK arrives next session — flip it on
# from Gradle with -DWITH_OPENCV=ON -DOPENCV_DIR=<sdk>/sdk/native/jni.

cmake_minimum_required(VERSION 3.18.1)
project(native_opencv LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Size hook #3: dead-strip unreferenced code. Free now, pays off once the
# selected OpenCV static modules are linked. Hooks #1/#2/#4 documented in plan.
add_compile_options(-ffunction-sections -fdata-sections)
add_link_options(-Wl,--gc-sections)

add_library(native_opencv SHARED native_opencv.cpp)
target_include_directories(native_opencv PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# --- OpenCV wiring: present, but OFF until the dedicated SDK-link session. ---
option(WITH_OPENCV "Link OpenCV (static, selected modules)" OFF)

if(WITH_OPENCV)
  # Resolve OPENCV_DIR from -DOPENCV_DIR=... or the OPENCV_DIR env var.
  # NEVER hardcoded to a developer machine, so a fresh clone can build.
  if((NOT DEFINED OPENCV_DIR OR OPENCV_DIR STREQUAL "") AND DEFINED ENV{OPENCV_DIR})
    set(OPENCV_DIR "$ENV{OPENCV_DIR}")
  endif()

  if(NOT OPENCV_DIR OR NOT EXISTS "${OPENCV_DIR}")
    message(FATAL_ERROR
      "WITH_OPENCV=ON but OPENCV_DIR is unset or missing: '${OPENCV_DIR}'.\n"
      "Point it at <opencv-android-sdk>/sdk/native/jni via -DOPENCV_DIR=... "
      "or the OPENCV_DIR environment variable. See README 'OpenCV setup'.")
  endif()

  # Size hook #2: select only the modules we use; OpenCV_LIBS then holds just
  # these. core (Mat), imgproc (cvtColor/Laplacian), imgcodecs (imdecode/encode).
  set(OpenCV_DIR "${OPENCV_DIR}")
  find_package(OpenCV REQUIRED COMPONENTS core imgproc imgcodecs)
  target_link_libraries(native_opencv ${OpenCV_LIBS})
  target_compile_definitions(native_opencv PRIVATE HAVE_OPENCV=1)
endif()
