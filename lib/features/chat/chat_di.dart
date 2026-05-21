import 'package:get_it/get_it.dart';

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
}
