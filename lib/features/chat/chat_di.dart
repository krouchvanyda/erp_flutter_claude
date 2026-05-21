import 'dart:async';

import 'package:get_it/get_it.dart';

import 'data/active_conversation_tracker.dart';
import 'data/call_signaling_service.dart';
import 'data/chat_lifecycle_bridge.dart';
import 'data/chat_settings.dart';
import 'data/chat_transport.dart';
import 'data/repositories/call_log_repository.dart';
import 'data/repositories/conversations_repository.dart';
import 'data/repositories/messages_repository.dart';
import 'entities/chat_message.dart';

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
  transport.events.listen((event) {
    unawaited(messages.applyInbound(event));
    if (event is MessageReceivedEvent) {
      final m = event.message;
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
