import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The SHARED source image both ops process.
///
/// This is the single owner of "the bytes currently being processed". Both
/// [GrayscaleController] and [BlurScoreController] watch it, so:
///   - the bundled sample.jpg is loaded exactly ONCE here (not once per
///     controller — that was the old double-load), and
///   - picking a new image (see [setImage]) re-runs both controllers, so
///     grayscale and blur recompute together off the same source.
///
/// It is an [AsyncNotifier] because the default value is loaded asynchronously
/// from the asset bundle: the first frame is genuinely "loading the default
/// image", which mirrors the app's original launch behaviour.
class SourceImageController extends AsyncNotifier<Uint8List> {
  @override
  Future<Uint8List> build() async {
    // The ONE place the source asset is read. rootBundle is a presentation/
    // platform concern (like the picker) — it never touches dart:ffi.
    return (await rootBundle.load('assets/sample.jpg')).buffer.asUint8List();
  }

  /// Swaps the source to a newly picked image. Called from the presentation
  /// layer after [ImagePicker] returns bytes; watchers recompute automatically.
  void setImage(Uint8List bytes) => state = AsyncData(bytes);
}

final sourceImageControllerProvider =
    AsyncNotifierProvider<SourceImageController, Uint8List>(
  SourceImageController.new,
);
