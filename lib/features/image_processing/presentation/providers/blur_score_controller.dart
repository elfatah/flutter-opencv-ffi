import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/image_metric.dart';
import '../../domain/usecases/image_bytes_params.dart';
import '../../providers/image_processing_providers.dart';

/// Exposes [AsyncValue<ImageMetric>] to the UI — the SCALAR return shape.
///
/// Identical plumbing to [GrayscaleController], but the use case returns a
/// `double`-backed [ImageMetric] instead of an image. Wiring this through the
/// full stack now (even though the native op is stubbed at 42.0) is what proves
/// the architecture carries both return shapes with no parallel mechanism.
class BlurScoreController extends AsyncNotifier<ImageMetric> {
  @override
  Future<ImageMetric> build() async {
    final bytes =
        (await rootBundle.load('assets/sample.jpg')).buffer.asUint8List();
    final result =
        await ref.read(computeBlurScoreProvider)(ImageBytesParams(bytes));
    return result.fold(
      (failure) => throw failure,
      (metric) => metric,
    );
  }
}

final blurScoreControllerProvider =
    AsyncNotifierProvider<BlurScoreController, ImageMetric>(
  BlurScoreController.new,
);
