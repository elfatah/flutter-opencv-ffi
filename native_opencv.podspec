#
# native_opencv.podspec — the iOS build glue for the shared FFI source.
#
# This is the iOS analogue of android/app/src/main/cpp/CMakeLists.txt: it tells
# CocoaPods to compile the SAME native/native_opencv.cpp into the app AND to link
# OpenCV, so that dart:ffi's DynamicLibrary.process() can resolve opencv_process /
# opencv_free_buffer and the real cv:: code runs. Wired in as a path-based dev pod
# from ios/Podfile (pod 'native_opencv', :path => '..').
#
# WHY THIS PODSPEC SITS AT THE REPO ROOT (not next to the source in native/):
# CocoaPods only globs vendored paths that live INSIDE the pod root. The shared
# source is in native/ and the OpenCV xcframework is in third_party/opencv-ios/;
# the only directory that contains BOTH without a '..' escape is the repo root.
# A podspec in native/ would need '../third_party/...' for vendored_frameworks,
# which CocoaPods silently drops (no FRAMEWORK_SEARCH_PATHS -> headers not found).
#
# CHECKPOINT 2 — OpenCV is now LINKED (static opencv2.xcframework) and HAVE_OPENCV=1
# selects native_opencv.cpp's real cv:: path instead of the #else deadbeef stub.
#
require 'pathname'

# --- Resolve the OpenCV iOS xcframework (mirror of Android's OPENCV_DIR Option-B) ---
#   (a) OPENCV_IOS_DIR env override, else (b) the in-repo default.
# __dir__ is the repo root (this podspec's location).
opencv_dir = ENV['OPENCV_IOS_DIR'] || File.join(__dir__, 'third_party', 'opencv-ios')
opencv_xcframework = File.expand_path(File.join(opencv_dir, 'opencv2.xcframework'))

# Loud guard: a cloner who hasn't provisioned the artifact gets a real, actionable
# error at `pod install` time — not a cryptic link failure deep into the build.
unless File.directory?(opencv_xcframework)
  raise <<~MSG

    [native_opencv] OpenCV iOS xcframework not found at:
      #{opencv_xcframework}

    Provision it (see README "OpenCV iOS setup"): build opencv2.xcframework from the
    OpenCV 4.12.0 source for arm64 device + arm64 simulator, then place it at
      third_party/opencv-ios/opencv2.xcframework
    or set OPENCV_IOS_DIR to the directory that contains opencv2.xcframework.
  MSG
end

Pod::Spec.new do |s|
  s.name             = 'native_opencv'
  s.version          = '0.0.1'
  s.summary          = 'Shared dart:ffi C++ bridge for flutter_ffi_opencv (OpenCV-linked).'
  s.description      = <<-DESC
Compiles the platform-neutral native/native_opencv.cpp into the iOS app and links
OpenCV (static opencv2.xcframework) so dart:ffi DynamicLibrary.process() resolves
the FFI symbols and the real cv:: grayscale/blur code runs on device & simulator.
                       DESC
  s.homepage         = 'https://github.com/elfatah/flutter_ffi_opencv'
  s.license          = { :type => 'MIT' }
  s.author           = { 'elfatah' => 'hilmannfatah@gmail.com' }
  s.source           = { :path => '.' }

  # The shared source lives in native/ — the very same files the Android CMake
  # build compiles. One source of truth, two build systems. Paths are relative to
  # this podspec's dir (the repo root).
  s.source_files        = 'native/native_opencv.{h,cpp}'
  s.public_header_files  = 'native/native_opencv.h'

  s.platform         = :ios, '13.0'

  # Link OpenCV (static xcframework). vendored_frameworks also adds the resolved
  # slice to FRAMEWORK_SEARCH_PATHS, which is what makes #include <opencv2/core.hpp>
  # resolve: the framework is named "opencv2", so <opencv2/X> maps to its flat
  # Headers/X. Path kept relative to the pod root (repo root) so CocoaPods globs it.
  s.vendored_frameworks =
    Pathname.new(opencv_xcframework).relative_path_from(Pathname.new(__dir__)).to_s

  # OpenCV's static modules pull in these system deps on iOS: zlib (libpng in
  # imgcodecs) and the Accelerate framework (core's Apple HAL). libc++ for the
  # C++ runtime. If the linker reports a different missing symbol, add precisely
  # the framework/lib it names — do not over-add speculatively.
  s.libraries  = 'z', 'c++'
  s.frameworks = 'Accelerate'

  # HAVE_OPENCV=1 is the iOS analogue of Android's
  #   target_compile_definitions(native_opencv PRIVATE HAVE_OPENCV=1)
  # — it makes native_opencv.cpp compile the real cv:: path, not the #else stub.
  # $(inherited) preserves CocoaPods' own defines (COCOAPODS, DEBUG, ...).
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'gnu++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'DEFINES_MODULE' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) HAVE_OPENCV=1',

    # HEADER-RACE FIX. vendored_frameworks resolves the xcframework slice into
    # PODS_XCFRAMEWORKS_BUILD_DIR via a "[CP] Copy XCFrameworks" phase, but the
    # parallel build system does not make this pod's OWN compile wait for that
    # copy, so native_opencv.cpp can compile before opencv2.framework lands ->
    # "'opencv2/core.hpp' file not found". Point -F directly at the VERIFIED
    # slice inside the source xcframework (which exists before the build starts),
    # per-SDK so the arch is always correct (no wrong-arch link). #include
    # <opencv2/core.hpp> then resolves via the 'opencv2' framework's flat Headers.
    'FRAMEWORK_SEARCH_PATHS[sdk=iphonesimulator*]' =>
      "$(inherited) \"#{opencv_xcframework}/ios-arm64-simulator\"",
    'FRAMEWORK_SEARCH_PATHS[sdk=iphoneos*]' =>
      "$(inherited) \"#{opencv_xcframework}/ios-arm64\"",

    # LINK FIX. This pod is built as a DYNAMIC framework (-dynamiclib), so its own
    # link is where native_opencv.cpp's cv:: references resolve. opencv2's binary
    # is a STATIC ar archive; plain `-framework opencv2` does not reliably pull the
    # referenced members into the dylib. -force_load the verified slice's archive
    # so all referenced OpenCV code links into native_opencv.framework, making it
    # self-contained (DynamicLibrary.process() then finds everything at runtime).
    # Per-SDK path = always the correct arch. A [sdk=*] key overrides the base
    # OTHER_LDFLAGS, so OpenCV's zlib/Accelerate/libc++ deps are repeated here.
    # AVFoundation + CoreMedia + CoreVideo: force_load pulls in OpenCV's videoio
    # module (cap_avfoundation, the iOS camera backend) which we never use but
    # which references these frameworks. The symbols ld names are AVFoundation
    # (AVCaptureSession*, AVAsset*) and CoreMedia (CMSampleBuffer*, CMTime*);
    # CoreVideo is the inseparable third of that capture stack. (A future rebuild
    # with --without videoio --without highgui would drop these and shrink the
    # binary — a roadmap "trim" item, not needed for this checkpoint.)
    'OTHER_LDFLAGS[sdk=iphonesimulator*]' =>
      "$(inherited) -lc++ -lz -framework Accelerate " \
      "-framework AVFoundation -framework CoreMedia -framework CoreVideo " \
      "-force_load \"#{opencv_xcframework}/ios-arm64-simulator/opencv2.framework/opencv2\"",
    'OTHER_LDFLAGS[sdk=iphoneos*]' =>
      "$(inherited) -lc++ -lz -framework Accelerate " \
      "-framework AVFoundation -framework CoreMedia -framework CoreVideo " \
      "-force_load \"#{opencv_xcframework}/ios-arm64/opencv2.framework/opencv2\"",
  }
end
