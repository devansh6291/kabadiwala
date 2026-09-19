import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Displays a lot's photo, working correctly on both web (where
/// Image.file is unsupported — image_picker gives back a blob: URL
/// instead of a real filesystem path) and mobile/desktop (where the
/// photo is a real file on disk).
class LotPhotoImage extends StatelessWidget {
  final String? path;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const LotPhotoImage({
    super.key,
    required this.path,
    required this.width,
    required this.height,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (path == null || path!.isEmpty) {
      return _placeholder();
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: kIsWeb
          ? Image.network(
              path!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _placeholder(),
            )
          : _fileImage(),
    );
  }

  Widget _fileImage() {
    final file = File(path!);
    if (!file.existsSync()) return _placeholder();
    return Image.file(
      file,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.background,
      child: const Icon(Icons.inventory_2, color: AppColors.primaryGreen),
    );
  }
}
