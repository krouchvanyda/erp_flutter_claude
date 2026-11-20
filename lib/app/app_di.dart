import '../core/di/injection.dart';
import '../core/di/service_locator.dart';
import '../features/auth/auth_di.dart';
import '../features/call/call_di.dart';
import '../features/call/model/call_model.dart';
import '../features/call/model/call_peer.dart';
import 'call_peer_of.dart';
import '../features/chat/chat_di.dart';
import '../features/chat/repository/chat_repository.dart';
import '../features/profile/profile_di.dart';

/// Fills the DI box for the whole app. Called ONCE from `bootstrap()`.
///
/// Lives in `app/` (not `core/`) because it imports every feature, and
/// `core/` must never import `features/`.
///
/// ```
/// configureAppDependencies()
///   ├── configureDependencies()   core: prefs, session, Dio, AppService, tokens
///   ├── registerAuthModule()      Step 3
///   ├── registerProfileModule()   Step 4
///   ├── registerChatModule()      Step 5
///   └── registerCallModule()      Step 6 (+ loadPeer: chat → name / photo)
/// ```
Future<void> configureAppDependencies() async {
  await configureDependencies(); // core first: features depend on it
  registerAuthModule(getIt);
  registerProfileModule(getIt);
  registerChatModule(getIt);
  registerCallModule(getIt, loadPeer: _callPeer);
}

/// An incoming call carries only ids → the chat's conversation gives the
/// name + photo (a person, or the group). Fails → null (the screen shows "…").
Future<CallPeer?> _callPeer(CallModel call) async {
  final chat = getIt<ChatRepository>();
  final (result, myId) = await (
    chat.loadConversation(call.conversationId),
    chat.myUserId(),
  ).wait;
  return result.fold((_) => null, (c) => callPeerOf(c, myId));
}
