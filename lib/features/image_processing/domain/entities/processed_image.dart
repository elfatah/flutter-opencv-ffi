import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Encoding of the bytes the native layer returned.
enum ImageFormat { png }

/// An image the native layer has processed — as the domain understands it:
/// just encoded [bytes] and their [format]. No Pointer, no ffi, no OpenCV.
class ProcessedImage extends Equatable {
  const ProcessedImage({required this.bytes, required this.format});

  /// Encoded image bytes (PNG for grayscale). Pure dart:typed_data — no native
  /// lifetime; safe to hold and pass anywhere.
  final Uint8List bytes;

  final ImageFormat format;

  // Equality keys on (length, format), NOT the raw bytes. Riverpod compares
  // state via ==, and a deep O(N) compare of a ~500KB buffer on every rebuild
  // would be a latent perf bug once image-picking lands. Two byte-identical
  // results comparing equal is acceptable for this domain.
  @override
  List<Object?> get props => [bytes.length, format];
}
