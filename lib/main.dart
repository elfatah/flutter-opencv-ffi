import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/image_processing/presentation/pages/grayscale_page.dart';

void main() => runApp(const ProviderScope(child: OpenCvFfiApp()));

class OpenCvFfiApp extends StatelessWidget {
  const OpenCvFfiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter FFI OpenCV',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const GrayscalePage(),
    );
  }
}
