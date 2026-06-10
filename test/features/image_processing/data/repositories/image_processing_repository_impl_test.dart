import 'dart:typed_data';

import 'package:flutter_ffi_opencv/core/error/exceptions.dart';
import 'package:flutter_ffi_opencv/core/error/failures.dart';
import 'package:flutter_ffi_opencv/core/native/opencv_status.dart';
import 'package:flutter_ffi_opencv/features/image_processing/data/datasources/opencv_ffi_datasource.dart';
import 'package:flutter_ffi_opencv/features/image_processing/data/repositories/image_processing_repository_impl.dart';
import 'package:flutter_ffi_opencv/features/image_processing/domain/entities/image_metric.dart';
import 'package:flutter_ffi_opencv/features/image_processing/domain/entities/processed_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// THE BOUNDARY'S PAYOFF: this runs under `flutter test` on the Dart VM with NO
/// .so loaded. By mocking the OpenCvDataSource (its abstract interface), the
/// entire status->Failure mapping and Either plumbing is verified device-free.
/// Only the FFI mechanism itself (datasource internals) needs a device.
class MockOpenCvDataSource extends Mock implements OpenCvDataSource {}

void main() {
  late MockOpenCvDataSource dataSource;
  late ImageProcessingRepositoryImpl repository;
  final input = Uint8List.fromList([1, 2, 3]);

  setUp(() {
    dataSource = MockOpenCvDataSource();
    repository = ImageProcessingRepositoryImpl(dataSource);
  });

  group('toGrayscale (image path)', () {
    test('maps datasource bytes -> Right(ProcessedImage)', () async {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
      when(() => dataSource.grayscale(input)).thenAnswer((_) async => png);

      final result = await repository.toGrayscale(input);

      final image = result.fold(
        (failure) => fail('expected Right, got Left($failure)'),
        (image) => image,
      );
      expect(image.bytes, png);
      expect(image.format, ImageFormat.png);
    });

    // Every native code + Dart-side sentinel -> its Failure subtype.
    final mapping = <int, Type>{
      OpenCvStatus.decodeError: DecodeFailure,
      OpenCvStatus.invalidInput: InvalidInputFailure,
      OpenCvStatus.encodeError: EncodeFailure,
      OpenCvStatus.unknownOp: UnsupportedOperationFailure,
      OpenCvStatus.outOfMemory: MemoryFailure,
      OpenCvStatus.nativeError: NativeFailure,
      OpenCvStatus.nullData: NativeFailure, // contract violation -> NativeFailure
    };

    mapping.forEach((status, expectedFailure) {
      test('OpenCvException($status) -> $expectedFailure', () async {
        when(() => dataSource.grayscale(input))
            .thenThrow(OpenCvException(status));

        final result = await repository.toGrayscale(input);

        final failure = result.fold(
          (failure) => failure,
          (image) => fail('expected Left, got Right($image)'),
        );
        expect(failure.runtimeType, expectedFailure);
      });
    });

    test('an unknown status falls back to NativeFailure', () async {
      when(() => dataSource.grayscale(input))
          .thenThrow(const OpenCvException(-12345));

      final result = await repository.toGrayscale(input);

      final failure = result.fold((f) => f, (_) => fail('expected Left'));
      expect(failure, isA<NativeFailure>());
    });
  });

  group('blurScore (scalar path)', () {
    test('maps datasource double -> Right(ImageMetric)', () async {
      when(() => dataSource.blurScore(input)).thenAnswer((_) async => 42.0);

      final result = await repository.blurScore(input);

      final metric = result.fold((f) => fail('expected Right, got $f'), (m) => m);
      expect(metric.value, 42.0);
      expect(metric.type, MetricType.blurScore);
    });

    test('OpenCvException -> Failure on the scalar path too', () async {
      when(() => dataSource.blurScore(input))
          .thenThrow(const OpenCvException(OpenCvStatus.nativeError));

      final result = await repository.blurScore(input);

      final failure = result.fold((f) => f, (_) => fail('expected Left'));
      expect(failure, isA<NativeFailure>());
    });
  });
}
