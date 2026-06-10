import 'dart:typed_data';

import '../../domain/entities/processed_image.dart';

/// Data-layer view of a processed image: the encoded bytes the native layer
/// produced. Maps to the domain [ProcessedImage].
///
/// Thin by design — the FFI data source returns raw [Uint8List]; this names
/// those bytes and assigns the [ImageFormat], keeping that knowledge out of the
/// repository (which just calls [toEntity]). Mirrors the template's
/// model -> entity split. There is no equivalent model for the scalar (blur)
/// path: a bare `double` needs no data-layer representation.
class ProcessedImageModel {
  const ProcessedImageModel(this.bytes, {this.format = ImageFormat.png});

  final Uint8List bytes;
  final ImageFormat format;

  ProcessedImage toEntity() => ProcessedImage(bytes: bytes, format: format);
}
