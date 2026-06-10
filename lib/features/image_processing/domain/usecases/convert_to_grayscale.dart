import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/processed_image.dart';
import '../repositories/image_processing_repository.dart';
import 'image_bytes_params.dart';

/// Converts an image to grayscale via the native OpenCV pipeline.
///
/// Deliberately thin — its value is the type contract and the decoupling:
/// presentation calls a named use case, not the repository directly.
class ConvertToGrayscale implements UseCase<ProcessedImage, ImageBytesParams> {
  const ConvertToGrayscale(this._repository);

  final ImageProcessingRepository _repository;

  @override
  Future<Either<Failure, ProcessedImage>> call(ImageBytesParams params) =>
      _repository.toGrayscale(params.bytes);
}
