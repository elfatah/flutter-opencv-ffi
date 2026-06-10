import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_ffi_opencv/core/error/failures.dart';
import 'package:flutter_ffi_opencv/features/image_processing/data/datasources/opencv_ffi_datasource.dart';
import 'package:flutter_ffi_opencv/features/image_processing/data/repositories/image_processing_repository_impl.dart';
import 'package:flutter_ffi_opencv/features/image_processing/domain/entities/image_metric.dart';
import 'package:flutter_ffi_opencv/features/image_processing/domain/entities/processed_image.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE BOUNDARY'S MECHANISM: the counterpart to the device-free unit test.
///
/// The unit test mocks [OpenCvDataSource] and proves everything ABOVE the FFI
/// boundary on the Dart VM with no .so. THIS test wires the REAL
/// [OpenCvFfiDataSource] — so it can only run on a device, where the actual
/// `libnative_opencv.so` is loaded and real malloc/copy/free + a real OpenCV
/// round-trip happen across `dart:ffi`. Nothing here is mocked; that is the
/// entire point.
///
/// Run (with an arm64 device/emulator attached):
///   flutter test integration_test/ffi_roundtrip_test.dart
/// NOT plain `flutter test` — that runs on the VM with no native lib and fails.
void main() {
  // Must be the INTEGRATION binding, not TestWidgetsFlutterBinding: this is
  // what runs the test on-device with real plugins, assets, and native libs.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Real data source -> real FFI; real repository -> real status->Failure map.
  final repository = ImageProcessingRepositoryImpl(const OpenCvFfiDataSource());

  // PNG signature: every grayscale result is an encoded PNG.
  const pngMagic = [0x89, 0x50, 0x4E, 0x47];

  late Uint8List sample;

  setUpAll(() async {
    // rootBundle works because the integration binding bundles app assets.
    final data = await rootBundle.load('assets/sample.jpg');
    sample = data.buffer.asUint8List();
    expect(sample, isNotEmpty, reason: 'sample.jpg should load from assets');
  });

  group('real FFI round-trip (device only)', () {
    test('grayscale: returns a valid, image-sized PNG across FFI', () async {
      final result = await repository.toGrayscale(sample);

      final image = result.fold(
        (failure) => fail('expected Right(ProcessedImage), got Left($failure)'),
        (image) => image,
      );

      // Non-empty, PNG magic bytes, and image-sized (not a stub of a few bytes).
      expect(image.bytes, isNotEmpty);
      expect(image.bytes.length, greaterThan(1000),
          reason: 'a real encoded PNG is image-sized, not a handful of bytes');
      expect(image.bytes.sublist(0, 4), pngMagic,
          reason: 'output must begin with the PNG signature');
      expect(image.format, ImageFormat.png);
    });

    test('blur score: returns a finite, positive Laplacian variance', () async {
      final result = await repository.blurScore(sample);

      final metric = result.fold(
        (failure) => fail('expected Right(ImageMetric), got Left($failure)'),
        (metric) => metric,
      );

      // A real Laplacian variance on a real photo is finite and > 0. We assert
      // plausibility only — NOT a specific value (the stub-era 42.0 is gone).
      expect(metric.type, MetricType.blurScore);
      expect(metric.value.isFinite, isTrue,
          reason: 'a real variance is a finite double');
      expect(metric.value, greaterThan(0),
          reason: 'Laplacian variance on a real image is positive');
    });

    test('invalid input surfaces DecodeFailure end-to-end through FFI',
        () async {
      // Bytes that are not a decodable image: cv::imdecode -> empty Mat ->
      // CV_ERR_DECODE in C++ -> OpenCvException -> DecodeFailure. This proves
      // the real error mapping across the boundary, not just in the mock.
      final garbage = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01]);

      final result = await repository.toGrayscale(garbage);

      final failure = result.fold(
        (failure) => failure,
        (image) => fail('expected Left(DecodeFailure), got Right($image)'),
      );
      expect(failure, isA<DecodeFailure>());
    });
  });
}
