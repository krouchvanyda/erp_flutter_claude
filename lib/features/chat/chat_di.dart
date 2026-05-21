import 'dart:async';

import 'package:get_it/get_it.dart';

import 'data/chat_settings.dart';
import 'data/chat_transport.dart';
import 'data/repositories/call_log_repository.dart';
import 'data/repositories/conversations_repository.dart';
import 'data/repositories/messages_repository.dart';

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

  await settings.load();
  messages.attachTransport(transport);

  // Pump every inbound peer event straight into the repo.
  transport.events.listen((event) {
    unawaited(messages.applyInbound(event));
  });

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
