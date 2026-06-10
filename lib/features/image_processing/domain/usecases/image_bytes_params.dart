import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Input for the image-processing use cases: the encoded image [bytes].
///
/// Shared by [ConvertToGrayscale] and [ComputeBlurScore] — both take an image
/// in and differ only in their return shape. Cousin of the template's NoParams.
final class ImageBytesParams extends Equatable {
  const ImageBytesParams(this.bytes);

  final Uint8List bytes;

  // Constructed fresh per call (not held as long-lived state), so a deep
  // bytes compare here is cold — fine to key equality on the bytes themselves.
  @override
  List<Object?> get props => [bytes];
}
