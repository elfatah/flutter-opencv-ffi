import 'package:equatable/equatable.dart';

/// The kind of scalar metric a native scalar-op produced.
enum MetricType { blurScore }

/// A scalar metric returned by a native operation — the second return shape the
/// FFI boundary supports (the first being [ProcessedImage]). Defined now so the
/// architecture demonstrably carries both shapes; the blur-score C++ is still
/// stubbed at 42.0, but it flows through every layer as a real `double`.
class ImageMetric extends Equatable {
  const ImageMetric({required this.value, required this.type});

  final double value;
  final MetricType type;

  @override
  List<Object?> get props => [value, type];
}
