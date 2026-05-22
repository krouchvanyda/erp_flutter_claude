import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';

import 'data/active_conversation_tracker.dart';
import 'data/call_signaling_service.dart';
import 'data/chat_lifecycle_bridge.dart';
import 'data/chat_seed.dart';
import 'data/chat_settings.dart';
import 'data/chat_transport.dart';
import 'data/repositories/call_log_repository.dart';
import 'data/repositories/conversations_repository.dart';
import 'data/repositories/messages_repository.dart';
import 'entities/chat_message.dart';
import 'entities/conversation.dart';

/// Manual DI registration for Module 10 (Chat & Voice / Video).
///
/// Same pattern as Modules 4–9: avoids re-running build_runner per
/// repo tweak. Call once from `main.dart` after the other module
/// registrations.
void registerChatModule(GetIt getIt) {
  if (!getIt.isRegistered<ConversationsRepository>()) {
    getIt.registerLazySingleton<ConversationsRepository>(
      ConversationsRepository.new,
    );
  }
  if (!getIt.isRegistered<MessagesRepository>()) {
    getIt.registerLazySingleton<MessagesRepository>(
      MessagesRepository.new,
    );
  }
  if (!getIt.isRegistered<CallLogRepository>()) {
    getIt.registerLazySingleton<CallLogRepository>(
      CallLogRepository.new,
    );
  }
  if (!getIt.isRegistered<ChatSettings>()) {
    getIt.registerLazySingleton<ChatSettings>(() => ChatSettings.instance);
  }
  if (!getIt.isRegistered<ChatTransport>()) {
    getIt.registerLazySingleton<ChatTransport>(ChatTransport.new);
  }
  // Slice 10.2.3 — call signalling. Built lazily but pulls the
  // transport / settings / repos through its constructor so the
  // subscription is live the first time something accesses it.
  if (!getIt.isRegistered<CallSignalingService>()) {
    getIt.registerLazySingleton<CallSignalingService>(
      () => CallSignalingService(
        transport: getIt<ChatTransport>(),
        settings: getIt<ChatSettings>(),
        conversations: getIt<ConversationsRepository>(),
        callLog: getIt<CallLogRepository>(),
      ),
    );
  }
}

/// Boot the chat wire stack. Loads persisted settings, attaches the
/// transport to the MessagesRepository, opens the WebSocket if a URL
/// is configured, and keeps both wired together as settings change.
///
/// Idempotent — safe to call once from `main` after
/// `registerChatModule`.
Future<void> bootChatTransport(GetIt getIt) async {
  final settings = getIt<ChatSettings>();
  final transport = getIt<ChatTransport>();
  final messages = getIt<MessagesRepository>();
  final conversations = getIt<ConversationsRepository>();

  await settings.load();
  messages.attachTransport(transport);

  // Pump every inbound peer event straight into the repo. For
  // received messages (Slice 10.1.6), also push the conversation's
  // last-message preview + unread counter so the inbox tile updates
  // in real time. Skip the unread bump when the user is sitting on
  // that conversation's page (tracked by ActiveConversationTracker).
  transport.events.listen((event) async {
    if (event is MessageReceivedEvent) {
      // Slice 10.1.8 — drop messages that weren't addressed to us
      // before touching any local state. Empty targetIds = legacy
      // broadcast for back-compat with pre-10.1.8 clients on the wire.
      if (event.targetIds.isNotEmpty &&
          !event.targetIds.contains(settings.userId)) {
        return;
      }
      // Slice 10.1.8 — redirect inbound DIRECT messages onto the
      // receiver's local conv with the sender. The seed reuses ids
      // like conv-005 ("Pisey direct" on every device), so Vibol's
      // outgoing message tagged conv-005 would otherwise land in
      // Pisey's own self-direct slot instead of her chat-with-Vibol.
      // Group messages keep the wire conv id verbatim — group
      // creation broadcasts a shared id (Slice 10.1.7).
      ChatMessage m = event.message;
      final isDirectToMe = event.targetIds.length == 1 &&
          event.targetIds.first == settings.userId;
      if (isDirectToMe) {
        final localConv =
            await conversations.findDirectWith(m.senderId);
        if (localConv != null && localConv.id != m.conversationId) {
          m = m.copyWith(conversationId: localConv.id);
        }
      }
      unawaited(messages
          .applyInbound(MessageReceivedEvent(m, targetIds: event.targetIds)));
      final preview = _previewFor(m);
      unawaited(
        conversations
            .updateLastMessage(
              id: m.conversationId,
              body: preview,
              senderId: m.senderId,
              senderName: m.senderName,
              type: m.type.name,
              at: m.sentAt,
            )
            // Conversation may not exist locally yet (peer started a
            // fresh conv we don't have seeded) — swallow.
            .catchError((_) async => throw StateError('conv missing')),
      );
      if (!ActiveConversationTracker.instance.isActive(m.conversationId)) {
        unawaited(conversations.bumpUnread(m.conversationId).catchError(
          (_) async => throw StateError('conv missing'),
        ));
      }
    } else {
      unawaited(messages.applyInbound(event));
      if (event is ConversationCreatedEvent) {
        unawaited(_applyInboundGroup(event, conversations, settings));
      } else if (event is ConversationUpdatedEvent) {
        unawaited(_applyInboundConversationUpdate(
          event,
          conversations,
          settings,
        ));
      } else if (event is ProfileUpdatedEvent) {
        unawaited(_applyInboundProfileUpdate(event, conversations));
      } else if (event is ConversationAvatarUpdatedEvent) {
        unawaited(_applyInboundAvatarUpdate(
          event,
          conversations,
          settings,
        ));
      }
    }
  });

  // Eagerly resolve the call signalling service so its transport
  // listener is wired before any peer can place a call. Without this,
  // the first incoming invite would arrive before anyone reads the
  // lazy singleton.
  getIt<CallSignalingService>();

  // Slice 10.2.6 — re-kick the WebSocket whenever the app returns to
  // the foreground, in case the OS dropped it while we were
  // backgrounded. No-op when the socket is still alive.
  ChatLifecycleBridge(transport: transport, settings: settings).attach();

  // Open the socket with the current settings, and re-open whenever
  // the user changes the URL or identity.
  Future<void> apply() => transport.updateConfig(
        url: settings.relayUrl,
        userId: settings.userId,
        userName: settings.userName,
      );

  await apply();
  settings.watch().listen((_) => unawaited(apply()));
}

/// Slice 10.1.7 — hydrate a peer-created group on this device.
///
/// Filters out:
///   * non-group conversations (direct convs are created implicitly
///     on first message, no envelope needed)
///   * envelopes that don't list us in `participantIds` (relay is
///     broadcast-only, so every connected client sees every envelope)
///   * duplicates — `findById` short-circuits if we already have the
///     conversation locally, so peers re-broadcasting the same id is
///     a no-op
Future<void> _applyInboundGroup(
  ConversationCreatedEvent event,
  ConversationsRepository conversations,
  ChatSettings settings,
) async {
  if (!event.isGroup) return;
  final me = settings.userId;
  if (!event.participantIds.contains(me)) return;
  final existing = await conversations.findById(event.conversationId);
  if (existing != null) return;

  // Build participantPreviews from the directory, excluding self.
  // Unknown ids (e.g. a peer running a forked seed) get a placeholder
  // entry so they still render in the AppBar member count.
  final previews = <ChatParticipantPreview>[];
  for (final id in event.participantIds) {
    if (id == me) continue;
    previews.add(ChatSeed.personById(id));
  }
  final online = previews
      .where((p) => p.presence == PresenceStatus.online)
      .length;

  await conversations.create(ChatConversation(
    id: event.conversationId,
    name: event.name,
    isGroup: true,
    isMuted: false,
    unreadCount: 0,
    createdAt: event.createdAt,
    updatedAt: event.createdAt,
    participantPreviews: previews,
    totalMembers: event.participantIds.length,
    onlineCount: online,
  ));
}

/// Slice 10.3.4 — peer admin renamed a group on their device. Apply
/// the new name locally so every member's inbox tile + AppBar stays
/// in sync. Filters on participantIds the same way Slice 10.1.7 does
/// — we only care if we're a member.
Future<void> _applyInboundConversationUpdate(
  ConversationUpdatedEvent event,
  ConversationsRepository conversations,
  ChatSettings settings,
) async {
  if (event.participantIds.isNotEmpty &&
      !event.participantIds.contains(settings.userId)) {
    return;
  }
  final existing = await conversations.findById(event.conversationId);
  if (existing == null || existing.name == event.name) return;
  try {
    await conversations.rename(event.conversationId, event.name);
  } catch (_) {
    // Conv vanished between findById and rename — nothing to do.
  }
}

/// Slice 10.3.4 — peer changed their display name. Rename our local
/// direct conversation with them so the AppBar + inbox tile pick up
/// the new label without us having to restart the app.
Future<void> _applyInboundProfileUpdate(
  ProfileUpdatedEvent event,
  ConversationsRepository conversations,
) async {
  final localConv = await conversations.findDirectWith(event.userId);
  if (localConv == null || localConv.name == event.newName) return;
  try {
    await conversations.rename(localConv.id, event.newName);
  } catch (_) {}
}

/// Slice 10.3.6 — admin set or cleared a group's avatar on their
/// device. We decode the base64 bytes, write them to our app cache
/// dir under a deterministic name keyed by conversationId (so the
/// next sync overwrites the same file rather than leaking copies),
/// and point our local conv at that path. A null `avatarBase64`
/// means "remove the photo" — we delete the cache file and clear
/// the path.
///
/// Filters on participantIds like every other group envelope so a
/// peer that's not in the group is a silent no-op.
Future<void> _applyInboundAvatarUpdate(
  ConversationAvatarUpdatedEvent event,
  ConversationsRepository conversations,
  ChatSettings settings,
) async {
  if (event.participantIds.isNotEmpty &&
      !event.participantIds.contains(settings.userId)) {
    return;
  }
  final existing = await conversations.findById(event.conversationId);
  if (existing == null) return;
  // Remove path branch — null bytes means the admin cleared the photo.
  if (event.avatarBase64 == null) {
    try {
      await conversations.setAvatarPath(event.conversationId, null);
    } catch (_) {}
    return;
  }
  try {
    final bytes = base64Decode(event.avatarBase64!);
    final ext = (event.fileExtension == null || event.fileExtension!.isEmpty)
        ? '.jpg'
        : (event.fileExtension!.startsWith('.')
            ? event.fileExtension!
            : '.${event.fileExtension!}');
    final dir = await getApplicationCacheDirectory();
    final file = File('${dir.path}/chat_avatar_${event.conversationId}$ext');
    await file.writeAsBytes(bytes, flush: true);
    await conversations.setAvatarPath(event.conversationId, file.path);
  } catch (_) {
    // Corrupt payload or filesystem issue — leave the existing
    // avatar alone rather than crashing the listener.
  }
}

/// Slice 10.1.6 — short preview text for the inbox tile, matching
/// what we already do for outgoing messages on the conversation page
/// (file → 📎 filename, voice → 🎤 …, image → 📷 Photo, text → body).
String _previewFor(ChatMessage m) {
  switch (m.type) {
    case ChatMessageType.text:
      return m.body ?? '';
    case ChatMessageType.voice:
      final d = m.voiceDurationSeconds ?? 0;
      final mm = (d ~/ 60).toString().padLeft(1, '0');
      final ss = (d % 60).toString().padLeft(2, '0');
      return '🎤 Voice message · $mm:$ss';
    case ChatMessageType.image:
      return '📷 Photo';
    case ChatMessageType.file:
      return '📎 ${m.fileName ?? 'File'}';
    case ChatMessageType.system:
      return m.body ?? '';
  }
}
