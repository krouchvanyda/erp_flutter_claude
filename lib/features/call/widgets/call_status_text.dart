import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';
import '../viewmodel/call/call_view_model_bloc.dart';
import 'call_timer_text.dart';

/// The status line under the name, from the state:
///
/// | state                          | shows                 |
/// |--------------------------------|-----------------------|
/// | Outgoing (not ringing yet)     | Calling…              |
/// | Outgoing, their phone shows it | Ringing…              |
/// | Incoming                       | Incoming call         |
/// | Incoming, a group              | Dara is calling…      |
/// | Incoming, Accept tapped        | Connecting…           |
/// | InCall, media not up yet       | Connecting…           |
/// | InCall, MY network dropped     | Reconnecting…         |
/// | InCall, THEY dropped           | Jane is reconnecting… |
/// | InCall, a group, all dropped   | Waiting for others…   |
/// | InCall                         | 00:12 (the timer)     |
/// | Ended                          | Call declined / Busy… |
class CallStatusText extends StatelessWidget {
  const CallStatusText({super.key, required this.state});

  final CallViewModelState state;

  /// The words for every state but InCall (which shows the timer).
  static String textFor(CallViewModelState state) => switch (state) {
    CallOutgoingState(:final peerRinging) =>
      peerRinging ? 'Ringing…' : 'Calling…',
    CallIncomingState(:final accepting, :final autoAnswer)
        when accepting || autoAnswer =>
      'Connecting…',
    // a group: WHO is calling (the title is the group's name) (6.3c)
    CallIncomingState(:final peer, :final call)
        when peer.isGroup && peer.members.containsKey(call.callerId) =>
      '${peer.member(call.callerId).firstName} is calling…',
    CallIncomingState() => 'Incoming call',
    CallEndedState() => state.text,
    // until the other person is really in the media call (#8)
    CallInCallState(:final reconnecting) when reconnecting => 'Reconnecting…',
    CallInCallState(:final peerAway, :final peer) when peerAway =>
      peer.isGroup
          ? 'Waiting for others…'
          : '${_first(peer.name)} is reconnecting…',
    CallInCallState(:final isConnecting) => isConnecting ? 'Connecting…' : '',
    CallIdleState() => '',
  };

  /// "Jane Doe" → "Jane"; no name yet → "They".
  static String _first(String name) {
    final first = name.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'They' : first;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final s = state;
    if (s is CallInCallState &&
        s.connectedAt != null &&
        !s.reconnecting &&
        !s.peerAway) {
      return CallTimerText(
        key: const ValueKey('timer'),
        since: s.connectedAt!,
        color: colors.primary,
      );
    }
    final text = textFor(s);
    return AppLabel(
      key: ValueKey(text), // a new text fades in (AnimatedSwitcher above)
      text: text,
      fontSize: AppFontSize.value16,
      fontWeight: FontWeight.w500,
      color: s is CallEndedState ? colors.error : colors.onSurfaceVariant,
    );
  }
}
