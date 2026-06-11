import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/processed_image.dart';
import '../providers/blur_score_controller.dart';
import '../providers/grayscale_controller.dart';
import '../providers/source_image_controller.dart';

/// The vertical slice's UI: drives grayscale (image shape) and blur score
/// (scalar shape) through the full clean stack and renders both.
class GrayscalePage extends ConsumerWidget {
  const GrayscalePage({super.key});

  /// Picks a photo and feeds its bytes into the SHARED source provider, which
  /// recomputes both grayscale and blur. This is the only platform/plugin touch
  /// point — pure presentation. image_picker yields a plain Uint8List, so it
  /// never crosses the dart:ffi boundary (same role rootBundle plays for the
  /// default asset).
  ///
  /// NOTE (iOS simulator): the simulator's PHPicker cannot return HEIC images —
  /// pick a JPEG/PNG when testing on the simulator. HEIC works on a real device.
  Future<void> _pick(WidgetRef ref, ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return; // user cancelled — leave the current source as-is.
    final bytes = await file.readAsBytes();
    ref.read(sourceImageControllerProvider.notifier).setImage(bytes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grayscale = ref.watch(grayscaleControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('FFI OpenCV — Grayscale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: 'Pick from gallery',
            onPressed: () => _pick(ref, ImageSource.gallery),
          ),
          IconButton(
            icon: const Icon(Icons.photo_camera),
            tooltip: 'Take a photo',
            onPressed: () => _pick(ref, ImageSource.camera),
          ),
        ],
      ),
      body: grayscale.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error is Failure ? error.message : 'Unexpected error: $error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (image) => _ResultView(image: image),
      ),
    );
  }
}

class _ResultView extends ConsumerWidget {
  const _ResultView({required this.image});

  final ProcessedImage image;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blur = ref.watch(blurScoreControllerProvider);
    // The "before" image is whatever the shared source currently holds (sample
    // or a picked photo) — rendered from bytes so it stays honest after a pick.
    // We reach this branch only once grayscale has data, so the source has
    // already resolved; value (nullable) is non-null in practice here.
    final source = ref.watch(sourceImageControllerProvider).value;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Labelled(
                label: 'Before (source)',
                child: source == null
                    ? const SizedBox.shrink()
                    : Image.memory(source, fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              _Labelled(
                label: 'After (OpenCV gray)',
                child: Image.memory(image.bytes, fit: BoxFit.contain),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Grayscale PNG: ${image.bytes.length} bytes (${image.format.name})',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          // Scalar path, end to end through the same clean stack.
          blur.when(
            loading: () => const Text('Blur score: computing…'),
            error: (error, _) => Text(
              'Blur score error: '
              '${error is Failure ? error.message : error}',
              style: const TextStyle(color: Colors.red),
            ),
            data: (metric) => Text(
              'Blur score (${metric.type.name}): ${metric.value}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          SizedBox(height: 180, child: child),
        ],
      ),
    );
  }
}
