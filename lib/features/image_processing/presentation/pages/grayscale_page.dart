import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/processed_image.dart';
import '../providers/blur_score_controller.dart';
import '../providers/grayscale_controller.dart';

/// The vertical slice's UI: drives grayscale (image shape) and blur score
/// (scalar shape) through the full clean stack and renders both.
class GrayscalePage extends ConsumerWidget {
  const GrayscalePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grayscale = ref.watch(grayscaleControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('FFI OpenCV — Grayscale')),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Labelled(
                label: 'Before (sample.jpg)',
                child: Image.asset('assets/sample.jpg', fit: BoxFit.contain),
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
