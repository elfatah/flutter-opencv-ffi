import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/processed_image.dart';
import '../../domain/usecases/image_bytes_params.dart';
import '../../providers/image_processing_providers.dart';

/// Exposes [AsyncValue<ProcessedImage>] to the UI — the IMAGE return shape.
///
/// Same shape as the template's UsersController: [build] is the single source
/// of truth, Riverpod handles loading/error states, and the [Either] from the
/// use case is folded here (Left → throw the Failure → AsyncError; Right →
/// return → AsyncData). The UI calls [AsyncValue.when] without knowing about
/// Either or Failure plumbing.
class GrayscaleController extends AsyncNotifier<ProcessedImage> {
  @override
  Future<ProcessedImage> build() async {
    final bytes =
        (await rootBundle.load('assets/sample.jpg')).buffer.asUint8List();
    final result =
        await ref.read(convertToGrayscaleProvider)(ImageBytesParams(bytes));
    return result.fold(
      (failure) => throw failure,
      (image) => image,
    );
  }
}

final grayscaleControllerProvider =
    AsyncNotifierProvider<GrayscaleController, ProcessedImage>(
  GrayscaleController.new,
);
