import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/opencv_ffi_datasource.dart';
import '../data/repositories/image_processing_repository_impl.dart';
import '../domain/repositories/image_processing_repository.dart';
import '../domain/usecases/compute_blur_score.dart';
import '../domain/usecases/convert_to_grayscale.dart';

/// Full DI chain for the image-processing feature.
///
/// Each provider is typed as its ABSTRACT interface where one exists, so the
/// rest of the app depends on the contract, not the implementation. Swapping
/// OpenCvFfiDataSource for a fake only requires changing this file (and is
/// exactly how the unit tests inject a mock).

final openCvDataSourceProvider = Provider<OpenCvDataSource>((ref) {
  return const OpenCvFfiDataSource();
});

final imageProcessingRepositoryProvider = Provider<ImageProcessingRepository>((
  ref,
) {
  return ImageProcessingRepositoryImpl(ref.watch(openCvDataSourceProvider));
});

final convertToGrayscaleProvider = Provider<ConvertToGrayscale>((ref) {
  return ConvertToGrayscale(ref.watch(imageProcessingRepositoryProvider));
});

final computeBlurScoreProvider = Provider<ComputeBlurScore>((ref) {
  return ComputeBlurScore(ref.watch(imageProcessingRepositoryProvider));
});
