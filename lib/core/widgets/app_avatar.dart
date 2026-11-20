import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_label.dart';

/// A round avatar: the photo, or the person's initials when there is no
/// photo (or it fails to load). Used by profile now, chat and call later.
///
/// ```dart
/// AppAvatar(name: 'Jane Doe', imageUrl: ApiEndPoint.fileUrl(user.avatarUrl))
/// ```
///
/// - [imageUrl] must be a FULL url (`ApiEndPoint.fileUrl` turns
///   `/uploads/...` into one).
/// - Photos are cached on disk (`cached_network_image`), so a chat list with
///   50 avatars doesn't download them again on every scroll.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
  });

  final String name;
  final String? imageUrl;
  final double size;

  /// "Jane Doe" → "JD", "vanyda" → "V", "" → "?".
  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    // .characters = real letters (safe for emoji / Khmer), not UTF-16 units.
    return words.take(2).map((w) => w.characters.first).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _Initials(text: initialsOf(name), size: size);
    final url = imageUrl;

    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: url == null
            ? initials
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => initials, // while loading
                errorWidget: (_, _, _) => initials, // 404, offline…
              ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.text, required this.size});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.primary,
      child: Center(
        child: AppLabel(
          text: text,
          fontSize: size * 0.38, // scales with the avatar
          fontWeight: FontWeight.w600,
          color: colors.onPrimary,
        ),
      ),
    );
  }
}
