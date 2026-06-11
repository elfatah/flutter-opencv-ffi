# CMakeLists.txt — builds libnative_opencv.so
#
# Links OpenCV statically (core, imgproc, imgcodecs) into the single .so when
# WITH_OPENCV=ON, which android/app/build.gradle.kts passes via -DWITH_OPENCV=ON.
# OPENCV_DIR is resolved below: -DOPENCV_DIR, else the OPENCV_DIR env var, else
# the in-repo third_party/ SDK.
#
# WITH_OPENCV defaults OFF, and the library still builds in that mode:
# native_opencv.cpp falls back to its no-OpenCV path (guarded by HAVE_OPENCV),
# which lets the FFI toolchain be validated without the SDK present.

cmake_minimum_required(VERSION 3.18.1)
project(native_opencv LANGUAGES CXX)

# Make option() honor a -DWITH_OPENCV=ON cache override unambiguously.
# (At min-version 3.18 this is already the default, but set it explicitly so a
# -D override is never silently dropped by an option()/cache-var interaction.)
cmake_policy(SET CMP0077 NEW)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Size hook #3: dead-strip unreferenced code. Free now, pays off once the
# selected OpenCV static modules are linked. Hooks #1/#2/#4 documented in plan.
add_compile_options(-ffunction-sections -fdata-sections)
add_link_options(-Wl,--gc-sections)

# Shared FFI source lives in the platform-neutral native/ dir at the repo root,
# so the SAME native_opencv.cpp/.h feed both this Android CMake build and the iOS
# podspec. This CMakeLists is at android/app/src/main/cpp, so native/ is FIVE
# levels up (cpp -> main -> src -> app -> android -> repo-root), then down.
set(_native_src_dir "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../native")
get_filename_component(_native_src_dir "${_native_src_dir}" ABSOLUTE)

add_library(native_opencv SHARED "${_native_src_dir}/native_opencv.cpp")
target_include_directories(native_opencv PRIVATE ${_native_src_dir})

# --- OpenCV wiring: present, but OFF until the dedicated SDK-link session. ---
option(WITH_OPENCV "Link OpenCV (static, selected modules)" OFF)

# Permanent quiet diagnostic. NOTE: message(STATUS) goes to CMake stdout, which
# Gradle/Flutter swallow at normal verbosity. To see it, read the persisted log:
#   build/app/intermediates/cxx/debug/*/logs/<abi>/configure_stdout.txt
# (Use message(WARNING ...) -> stderr if you ever need it in the flutter console.)
message(STATUS "FFI build: WITH_OPENCV='${WITH_OPENCV}'")

# CMake treats ON/TRUE/1/YES as true; the diagnostic above shows the literal value.
if(WITH_OPENCV)

  # --- Resolve OPENCV_DIR (Option B): (a) -DOPENCV_DIR, (b) env, (c) in-repo default ---
  # In-repo default. This CMakeLists is at android/app/src/main/cpp, so the repo
  # root is FIVE levels up (cpp -> main -> src -> app -> android -> repo-root),
  # then down into the gitignored SDK. NEVER a developer-machine absolute path.
  set(_opencv_default
      "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../third_party/opencv-android-sdk/sdk/native/jni")

  if(DEFINED OPENCV_DIR AND NOT OPENCV_DIR STREQUAL "")
    set(_opencv_dir "${OPENCV_DIR}")            # (a) explicit -DOPENCV_DIR override
  elseif(DEFINED ENV{OPENCV_DIR} AND NOT "$ENV{OPENCV_DIR}" STREQUAL "")
    set(_opencv_dir "$ENV{OPENCV_DIR}")         # (b) OPENCV_DIR env var
  else()
    set(_opencv_dir "${_opencv_default}")       # (c) in-repo default
  endif()

  # Normalise to an absolute, '..'-collapsed path so diagnostics show a real path.
  get_filename_component(_opencv_dir "${_opencv_dir}" ABSOLUTE)
  message(STATUS "OpenCV: OPENCV_DIR = ${_opencv_dir}")

  # Fail loudly WITH the path tried, not via a generic find_package error.
  if(NOT EXISTS "${_opencv_dir}/OpenCVConfig.cmake")
    message(FATAL_ERROR
      "OpenCV not found: no OpenCVConfig.cmake at\n"
      "  ${_opencv_dir}/OpenCVConfig.cmake\n"
      "Unpack the OpenCV Android SDK to third_party/opencv-android-sdk/ (see "
      "README 'OpenCV setup'), or pass -DOPENCV_DIR=<sdk>/sdk/native/jni.")
  endif()

  # Force STATIC linking against the SDK's staticlibs (not libopencv_java4.so),
  # so only the modules we reference end up in libnative_opencv.so.
  set(OpenCV_STATIC ON)

  # Size hook #2: select only the modules slice 1+2 need. OpenCV_LIBS then holds
  # just these: core (Mat), imgproc (cvtColor/Laplacian), imgcodecs (imdecode/encode).
  set(OpenCV_DIR "${_opencv_dir}")  # config-mode find_package reads OpenCV_DIR
  find_package(OpenCV REQUIRED COMPONENTS core imgproc imgcodecs)
  message(STATUS "OpenCV: version ${OpenCV_VERSION}; linking ${OpenCV_LIBS}")

  target_include_directories(native_opencv PRIVATE ${OpenCV_INCLUDE_DIRS})
  target_link_libraries(native_opencv ${OpenCV_LIBS})
  target_compile_definitions(native_opencv PRIVATE HAVE_OPENCV=1)
endif()
