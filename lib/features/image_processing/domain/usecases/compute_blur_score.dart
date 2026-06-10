import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/image_metric.dart';
import '../repositories/image_processing_repository.dart';
import 'image_bytes_params.dart';

/// Computes a blur score (Laplacian variance) for an image — the SCALAR return
/// path through the FFI boundary.
///
/// Defined and fully wired now even though the native op returns a stubbed 42.0:
/// it proves the architecture handles a `double` result, not just an image
/// buffer, with no parallel mechanism. Slice two swaps in the real C++ math
/// behind the same contract.
class ComputeBlurScore implements UseCase<ImageMetric, ImageBytesParams> {
  const ComputeBlurScore(this._repository);

  final ImageProcessingRepository _repository;

  @override
  Future<Either<Failure, ImageMetric>> call(ImageBytesParams params) =>
      _repository.blurScore(params.bytes);
}
