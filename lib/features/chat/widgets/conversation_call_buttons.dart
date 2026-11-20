import 'package:flutter/material.dart';

import '../model/chat_call_launcher.dart';
import '../model/conversation_model.dart';

/// 📞 🎥 in the chat's app bar (Step 6.1). Greyed while a call is on.
class ConversationCallButtons extends StatelessWidget {
  const ConversationCallButtons({
    super.key,
    required this.calls,
    required this.conversation,
    required this.myId,
  });

  final ChatCallLauncher calls;
  final ConversationModel conversation;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: calls.inCall,
      builder: (context, busy, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Voice call',
            onPressed: busy
                ? null
                : () => calls.start(conversation, myId: myId, video: false),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: busy
                ? null
                : () => calls.start(conversation, myId: myId, video: true),
            icon: const Icon(Icons.videocam_outlined),
          ),
        ],
      ),
    );
  }
}
