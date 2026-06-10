import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/native/opencv_status.dart';
import '../../domain/entities/image_metric.dart';
import '../../domain/entities/processed_image.dart';
import '../../domain/repositories/image_processing_repository.dart';
import '../datasources/opencv_ffi_datasource.dart';
import '../models/processed_image_model.dart';

/// Maps the FFI data source's typed exceptions to domain [Failure]s.
///
/// Note the imports: dart:typed_data (allowed everywhere), the pure-Dart
/// [OpenCvStatus] codes, and the data source's ABSTRACT interface — but NEVER
/// dart:ffi. This file sits above the boundary; it never sees a Pointer.
class ImageProcessingRepositoryImpl implements ImageProcessingRepository {
  const ImageProcessingRepositoryImpl(this._dataSource);

  final OpenCvDataSource _dataSource;

  @override
  Future<Either<Failure, ProcessedImage>> toGrayscale(
    Uint8List imageBytes,
  ) async {
    try {
      final png = await _dataSource.grayscale(imageBytes);
      return Right(ProcessedImageModel(png).toEntity());
    } on OpenCvException catch (e) {
      return Left(_failureFromStatus(e.status));
    }
  }

  @override
  Future<Either<Failure, ImageMetric>> blurScore(Uint8List imageBytes) async {
    try {
      final value = await _dataSource.blurScore(imageBytes);
      return Right(ImageMetric(value: value, type: MetricType.blurScore));
    } on OpenCvException catch (e) {
      return Left(_failureFromStatus(e.status));
    }
  }

  /// One switch, native codes + Dart-side sentinels -> Failure. Same shape as
  /// the template's `_codeFromStatus`, returning a Failure instead of a code.
  static Failure _failureFromStatus(int status) => switch (status) {
        OpenCvStatus.decodeError => const DecodeFailure(),
        OpenCvStatus.invalidInput => const InvalidInputFailure(),
        OpenCvStatus.encodeError => const EncodeFailure(),
        OpenCvStatus.unknownOp => const UnsupportedOperationFailure(),
        OpenCvStatus.outOfMemory => const MemoryFailure(),
        OpenCvStatus.nativeError => const NativeFailure(),
        OpenCvStatus.nullData => const NativeFailure(),
        _ => const NativeFailure(),
      };
}
