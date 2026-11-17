import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import '../../../core/di/injection.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/config_router.dart';
import '../repositories/active_conversation_tracker.dart';
import '../repositories/conversations_repository.dart';
import '../views/chat_conversation_page.dart';

/// Routes chat-message push notifications (sibling of
/// `CallNotificationRouter`, which owns `call.*` pushes).
///
/// Two jobs:
/// 1. **Tap → open that conversation.** Works for every tap source:
///    the OS-rendered notification (minimised / killed app, via
///    `FirebaseMessaging.onMessageOpenedApp` / `getInitialMessage`) and
///    our own local notification (`flutter_local_notifications` tap /
///    launch details).
/// 2. **Foreground de-dup.** [isViewing] tells the push listener to skip
///    the banner when the user is already looking at that conversation
///    (the message is arriving live over STOMP anyway).
///
/// **Cold start:** the router goes splash → (auth) → chat inbox. A page
/// pushed before the inbox exists would be wiped by that navigation, so
/// a tap that arrives early is parked in [_pendingConversationId] and
/// opened once [ChatInboxPage] reports itself ready ([inboxReady]). The
/// inbox only mounts for a signed-in user, so this also waits for login.
///
/// Expected payload (backend FCM `data`):
/// `{ "type": "chat", "conversationId": "123", "title": …, "body": … }`.
class ChatNotificationRouter {
  ChatNotificationRouter._();

  static String? _pendingConversationId;
  static bool _inboxReady = false;

  /// The conversation a chat push points at, or `null` when the push is
  /// not a chat message (calls, Stream Video, or no conversation id).
  static String? conversationIdOf(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    if (type.startsWith('call.') || data['sender'] == 'stream.video') {
      return null;
    }
    final id =
        (data['conversationId'] ?? data['conversation_id'])?.toString() ?? '';
    return id.isEmpty ? null : id;
  }

  /// True when the user is currently on the conversation this push is
  /// about — the foreground listener uses it to skip a redundant banner.
  static bool isViewing(Map<String, dynamic> data) {
    final id = conversationIdOf(data);
    return id != null && ActiveConversationTracker.instance.isActive(id);
  }

  /// Opens the conversation a tapped chat notification points at.
  /// Returns `false` (and does nothing) for non-chat payloads.
  static bool open(Map<String, dynamic> data) {
    final id = conversationIdOf(data);
    if (id == null) return false;
    if (kDebugMode) log('💬 [chat push] TAP → open conversation $id');
    if (ActiveConversationTracker.instance.isActive(id)) return true;
    _pendingConversationId = id;
    if (_inboxReady) _flush();
    return true;
  }

  /// Called by `ChatInboxPage` after its first frame: the router has
  /// settled on the signed-in shell, so a parked tap can be opened now.
  static void inboxReady() {
    _inboxReady = true;
    _flush();
  }

  /// Called by `ChatInboxPage.dispose` (e.g. sign-out) so a later tap is
  /// parked again instead of being pushed over the login screen.
  static void inboxDisposed() {
    _inboxReady = false;
  }

  static void _flush() {
    final id = _pendingConversationId;
    final context = AppRouter.rootNavigatorKey.currentContext;
    if (id == null || context == null) return;
    _pendingConversationId = null;
    // Best effort: a push can be for a conversation the inbox cache
    // hasn't loaded yet (brand-new chat). The page loads its own
    // messages; this fills in the header (name, avatar, members).
    if (getIt.isRegistered<ConversationsRepository>()) {
      unawaited(getIt<ConversationsRepository>().refreshOne(id));
    }
    unawaited(ConfigRouter.pushPageAnimation(
      context,
      ChatConversationPage(conversationId: id),
    ));
  }

  /// Test seam — resets the static state between tests.
  @visibleForTesting
  static void reset() {
    _pendingConversationId = null;
    _inboxReady = false;
  }

  /// Test seam — the conversation id waiting for the inbox, if any.
  @visibleForTesting
  static String? get pendingConversationId => _pendingConversationId;
}
