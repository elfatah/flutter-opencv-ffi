import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/image_metric.dart';
import '../entities/processed_image.dart';

/// Contract the data layer must satisfy.
///
/// Declared in domain so use cases depend on an abstraction, not on the FFI
/// implementation. This file never imports anything from data — and never
/// imports dart:ffi. [Uint8List] in, domain entities out, wrapped in [Either].
abstract interface class ImageProcessingRepository {
  /// Converts [imageBytes] to grayscale, returning the encoded result image.
  Future<Either<Failure, ProcessedImage>> toGrayscale(Uint8List imageBytes);

  /// Computes a blur score for [imageBytes] (scalar return shape; the native
  /// op is still stubbed at 42.0 — slice two implements the real Laplacian).
  Future<Either<Failure, ImageMetric>> blurScore(Uint8List imageBytes);
}
