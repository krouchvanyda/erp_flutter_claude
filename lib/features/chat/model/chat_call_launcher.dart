import 'package:flutter/foundation.dart';

import 'conversation_model.dart';

/// How a chat starts a call (Step 6.1) — WITHOUT importing the call feature.
///
/// `app/` builds it from the call bloc and gives it to the inbox, which
/// passes it to each chat. Same idea as `InboxPage(onOpenProfile:)`.
///
/// ```
/// chat 📞 ──start(conversation, myId, video: false)──► app/ ──► CallViewModelBloc
/// chat 📞 greyed ◄── inCall (true while a call is on screen)
/// ```
class ChatCallLauncher {
  const ChatCallLauncher({required this.start, required this.inCall});

  final void Function(
    ConversationModel conversation, {
    required String? myId,
    required bool video,
  })
  start;

  /// A call is on → the buttons are greyed (one call at a time).
  final ValueListenable<bool> inCall;
}
