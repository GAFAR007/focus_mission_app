/**
 * WHAT:
 * AvatarBadge renders either a seeded avatar image or a fallback icon badge.
 * WHY:
 * Profile identity should stay playful and visually obvious across student,
 * teacher, and mentor screens.
 * HOW:
 * Normalize the image URL, then draw either the network image or the supplied
 * icon inside a circular gradient badge.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'package:flutter/material.dart';

class AvatarBadge extends StatelessWidget {
  const AvatarBadge({
    super.key,
    this.icon = Icons.person_rounded,
    required this.colors,
    this.size = 58,
    this.imageUrl,
  });

  final IconData icon;
  final List<Color> colors;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = _normaliseAvatarUrl(imageUrl);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: resolvedImageUrl == null
            ? Icon(icon, color: Colors.white, size: size / 2.3)
            : Image.network(
                resolvedImageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(icon, color: Colors.white, size: size / 2.3),
              ),
      ),
    );
  }
}

String? _normaliseAvatarUrl(String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return null;
  }

  if (!imageUrl.contains('api.dicebear.com')) {
    return imageUrl;
  }

  if (imageUrl.contains('/svg?')) {
    final pngUrl = imageUrl.replaceFirst('/svg?', '/png?');
    return pngUrl.contains('size=') ? pngUrl : '$pngUrl&size=128';
  }

  if (imageUrl.contains('/png?') && !imageUrl.contains('size=')) {
    return '$imageUrl&size=128';
  }

  return imageUrl;
}
