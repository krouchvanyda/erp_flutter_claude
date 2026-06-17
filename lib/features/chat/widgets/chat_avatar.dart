import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:erp_mobile/core/di/service_locator.dart';

import '../../../core/network/token_storage.dart';
import '../../../core/theme/app_label.dart';
import '../../../core/widgets/app_images.dart' show ensureHttp;
import '../repositories/presence_repository.dart';
import '../models/conversation.dart';

/// Process-level cache of the `Authorization: Bearer <token>` header
/// that the server-side avatar route requires (the employee/avatar
/// static endpoint is auth-gated — `MyProfilePage` loads its own avatar
/// the same way). [ChatAvatar] sends these headers with its
/// [CachedNetworkImage] request so a peer's profile photo actually
/// loads instead of 401ing and falling back to initials.
///
/// The token is read once, lazily, off the build path. [revision] ticks
/// when the header becomes available so any mounted avatars rebuild and
/// re-issue the (now authorized) request. [refresh] re-reads the token
/// after a login / identity rehydrate so a rotated token doesn't leave
/// the header stale.
class AvatarAuthHeaders {
  AvatarAuthHeaders._();

  static Map<String, String>? _headers;
  static bool _loading = false;

  /// Bumps when [_headers] changes so [ChatAvatar] can rebuild.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Map<String, String>? get headers => _headers;

  /// Kick a one-time async load if we don't have headers yet. Safe to
  /// call from `build` — it no-ops once loaded or while a load is in
  /// flight, and never touches storage synchronously.
  static void ensureLoaded() {
    if (_headers != null || _loading) return;
    _load();
  }

  /// Force a re-read (call after login / token refresh).
  static void refresh() => _load();

  static void _load() {
    if (!GetIt.I.isRegistered<TokenStorage>()) return;
    _loading = true;
    GetIt.I<TokenStorage>().read().then((tokens) {
      final at = tokens?.accessToken;
      final next = (at != null && at.isNotEmpty)
          ? <String, String>{'Authorization': 'Bearer $at'}
          : null;
      _loading = false;
      if (next != null && next['Authorization'] != _headers?['Authorization']) {
        _headers = next;
        revision.value++;
      }
    }).catchError((_) {
      _loading = false;
    });
  }
}

/// Circular avatar with initials fallback. Used for direct chats and
/// participant rows. Group rows use [GroupAvatarCluster] instead.
///
/// When [avatarFilePath] points to a readable local file, the avatar
/// renders the photo (filled by [DecorationImage.cover]) instead of
/// the initials gradient. Slice 10.3.3 uses this for group photos
/// picked via `image_picker`.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    required this.size,
    this.avatarUrl,
    this.avatarFilePath,
    this.presence,
    this.showStatus = true,
    this.userId,
  });

  final String name;
  final double size;
  final String? avatarUrl;
  final String? avatarFilePath;
  final PresenceStatus? presence;
  final bool showStatus;

  /// When set, the dot is driven live from [PresenceRepository] for
  /// this user — overrides the static [presence] field and rebuilds
  /// on every `presence.update` STOMP frame. Leave null for legacy
  /// call sites that pass an explicit [presence] (seed data, etc.).
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _initialsFor(name);
    final hue = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final colors = _gradientFor(hue);
    final dotSize = (size * 0.28).clamp(8.0, 18.0);
    // A locally-picked file takes priority over the server URL so a
    // freshly-picked image shows immediately (before any upload). When
    // neither is set we fall back to the initials gradient.
    final hasLocalPhoto = avatarFilePath != null && avatarFilePath!.isNotEmpty;
    final hasNetworkPhoto = !hasLocalPhoto &&
        avatarUrl != null &&
        avatarUrl!.trim().isNotEmpty;
    final presenceRepo = (userId != null &&
            GetIt.I.isRegistered<PresenceRepository>())
        ? GetIt.I<PresenceRepository>()
        : null;

    // Gradient + initials disc — both the no-photo state AND the
    // placeholder/error fallback while a network avatar loads or 404s.
    Widget initialsCircle() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          alignment: Alignment.center,
          child: AppLabel(
            text: initials,
            fontSize: size * 0.38,
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        );

    Widget avatarFace;
    if (hasLocalPhoto) {
      avatarFace = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface,
          image: DecorationImage(
            image: FileImage(File(avatarFilePath!)),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (hasNetworkPhoto) {
      // The avatar route is auth-gated — attach the cached Bearer header
      // (loaded lazily off the build path) and rebuild when it arrives
      // so the request is authorized. Without this the image 401s and
      // shows initials, never the peer's real photo.
      AvatarAuthHeaders.ensureLoaded();
      avatarFace = ClipOval(
        child: AnimatedBuilder(
          animation: AvatarAuthHeaders.revision,
          builder: (_, __) => CachedNetworkImage(
            // Cache key stays the URL across header changes so a token
            // refresh doesn't orphan an already-downloaded image.
            cacheKey: ensureHttp(avatarUrl!),
            imageUrl: ensureHttp(avatarUrl!),
            httpHeaders: AvatarAuthHeaders.headers,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => initialsCircle(),
            errorWidget: (_, __, ___) => initialsCircle(),
          ),
        ),
      );
    } else {
      avatarFace = initialsCircle();
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatarFace,
          if (showStatus)
            Positioned(
              right: -1,
              bottom: -1,
              child: presenceRepo != null
                  ? AnimatedBuilder(
                      animation: presenceRepo.revision,
                      builder: (_, __) {
                        // `effectiveStatus` maps a fresh-OFFLINE
                        // (last-seen < 5 min) to AWAY so dots stay
                        // amber when the peer just minimised, instead
                        // of disappearing instantly.
                        final live =
                            presenceRepo.statusOf(userId!).effectiveStatus;
                        if (live == PresenceStatus.offline) {
                          return const SizedBox.shrink();
                        }
                        return OnlineStatusDot(
                          presence: live,
                          size: dotSize,
                          borderColor: theme.colorScheme.surface,
                        );
                      },
                    )
                  : (presence != null
                      ? OnlineStatusDot(
                          presence: presence!,
                          size: dotSize,
                          borderColor: theme.colorScheme.surface,
                        )
                      : const SizedBox.shrink()),
            ),
        ],
      ),
    );
  }

  static String _initialsFor(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static List<Color> _gradientFor(int hue) {
    final palettes = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)], // indigo→violet
      [const Color(0xFF06B6D4), const Color(0xFF3B82F6)], // cyan→blue
      [const Color(0xFF10B981), const Color(0xFF059669)], // emerald
      [const Color(0xFFF59E0B), const Color(0xFFEF4444)], // amber→red
      [const Color(0xFFEC4899), const Color(0xFF8B5CF6)], // pink→violet
      [const Color(0xFF14B8A6), const Color(0xFF22D3EE)], // teal→sky
    ];
    return palettes[hue.abs() % palettes.length];
  }
}

/// Small dot used on the bottom-right of avatars to indicate presence.
class OnlineStatusDot extends StatelessWidget {
  const OnlineStatusDot({
    super.key,
    required this.presence,
    required this.size,
    required this.borderColor,
  });

  final PresenceStatus presence;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final color = switch (presence) {
      PresenceStatus.online => const Color(0xFF31A24C), // facebook-green
      PresenceStatus.busy => const Color(0xFFE2A03F),   // amber — in a call
      PresenceStatus.away => Colors.orange.shade500,
      PresenceStatus.offline => Colors.grey.shade400,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
    );
  }
}

/// 3-avatar cluster used by group conversations in the inbox.
class GroupAvatarCluster extends StatelessWidget {
  const GroupAvatarCluster({
    super.key,
    required this.previews,
    this.size = 52,
  });

  final List<ChatParticipantPreview> previews;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (previews.isEmpty) {
      return ChatAvatar(name: 'Group', size: size, showStatus: false);
    }
    final theme = Theme.of(context);
    final frontSize = size * 0.78;
    final backSize = size * 0.55;
    final visible = previews.take(3).toList();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          if (visible.length >= 3)
            Positioned(
              right: 0,
              top: 0,
              child: _Ringed(
                color: theme.colorScheme.surface,
                child: ChatAvatar(
                  name: visible[2].name,
                  size: backSize,
                  avatarUrl: visible[2].avatarUrl,
                  showStatus: false,
                ),
              ),
            ),
          if (visible.length >= 2)
            Positioned(
              right: size * 0.32,
              top: 0,
              child: _Ringed(
                color: theme.colorScheme.surface,
                child: ChatAvatar(
                  name: visible[1].name,
                  size: backSize,
                  avatarUrl: visible[1].avatarUrl,
                  showStatus: false,
                ),
              ),
            ),
          Positioned(
            left: 0,
            bottom: 0,
            child: _Ringed(
              color: theme.colorScheme.surface,
              child: ChatAvatar(
                name: visible.first.name,
                size: frontSize,
                avatarUrl: visible.first.avatarUrl,
                showStatus: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ringed extends StatelessWidget {
  const _Ringed({required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: child,
    );
  }
}
