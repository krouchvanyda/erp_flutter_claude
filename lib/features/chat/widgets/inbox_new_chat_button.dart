import 'package:flutter/material.dart';

/// The ✎ button at the bottom right of the inbox → the new-chat picker.
class InboxNewChatButton extends StatelessWidget {
  const InboxNewChatButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      tooltip: 'New chat',
      onPressed: onPressed,
      child: const Icon(Icons.edit_square),
    );
  }
}
