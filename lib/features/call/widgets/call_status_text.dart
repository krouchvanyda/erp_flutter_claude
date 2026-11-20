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
/// | Incoming, Accept tapped        | Connecting…           |
/// | InCall                         | 00:12 (the timer)     |
/// | Ended                          | Call declined / Busy… |
class CallStatusText extends StatelessWidget {
  const CallStatusText({super.key, required this.state});

  final CallViewModelState state;

  /// The words for every state but InCall (which shows the timer).
  static String textFor(CallViewModelState state) => switch (state) {
    CallOutgoingState(:final peerRinging) =>
      peerRinging ? 'Ringing…' : 'Calling…',
    CallIncomingState(:final accepting) =>
      accepting ? 'Connecting…' : 'Incoming call',
    CallEndedState() => state.text,
    CallInCallState() || CallIdleState() => '',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final s = state;
    if (s is CallInCallState) {
      return CallTimerText(
        key: const ValueKey('timer'),
        since: s.connectedAt,
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
