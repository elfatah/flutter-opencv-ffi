#
# native_opencv.podspec — the iOS build glue for the shared FFI source.
#
# This is the iOS analogue of android/app/src/main/cpp/CMakeLists.txt: it tells
# CocoaPods to compile the SAME native/native_opencv.cpp into the app so that
# dart:ffi's DynamicLibrary.process() can resolve opencv_process /
# opencv_free_buffer at runtime. It is wired in as a path-based development pod
# from ios/Podfile (pod 'native_opencv', :path => '../native').
#
# CHECKPOINT 1 (toolchain proof) — OpenCV is intentionally NOT linked here:
#   * no vendored_frameworks,
#   * HAVE_OPENCV left UNDEFINED,
# so native_opencv.cpp compiles its #else "deadbeef" stub path and the FFI round
# trip is proven with zero OpenCV, zero stripping, zero signing. The OpenCV
# xcframework (vendored_frameworks) and HAVE_OPENCV=1 arrive in a later checkpoint.
#
Pod::Spec.new do |s|
  s.name             = 'native_opencv'
  s.version          = '0.0.1'
  s.summary          = 'Shared dart:ffi C++ bridge for flutter_ffi_opencv.'
  s.description      = <<-DESC
Compiles the platform-neutral native/native_opencv.cpp into the iOS app so that
dart:ffi DynamicLibrary.process() can resolve the FFI symbols. Checkpoint 1 keeps
OpenCV out (HAVE_OPENCV undefined -> deadbeef stub) to prove the toolchain alone.
                       DESC
  s.homepage         = 'https://github.com/elfatah/flutter_ffi_opencv'
  s.license          = { :type => 'MIT' }
  s.author           = { 'elfatah' => 'hilmannfatah@gmail.com' }
  s.source           = { :path => '.' }

  # The shared source sits next to this podspec in native/ — the very same files
  # the Android CMake build compiles. One source of truth, two build systems.
  s.source_files        = 'native_opencv.{h,cpp}'
  s.public_header_files  = 'native_opencv.h'

  s.platform         = :ios, '13.0'

  # FFI_EXPORT in native_opencv.h already carries
  #   __attribute__((visibility("default"))) __attribute__((used))
  # so the two exported symbols survive compile-time dead-strip. Nothing
  # OpenCV-related and NO Strip Style setting here — release-strip survival is a
  # later checkpoint (debug builds, which this checkpoint uses, don't strip).
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'DEFINES_MODULE' => 'YES',
  }
end
