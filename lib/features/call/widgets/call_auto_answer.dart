import 'package:flutter/widgets.dart';

import '../viewmodel/call/call_view_model_bloc.dart';

/// "Answer" on the Android ring notification = Accept (Step 7.4).
///
/// Draws nothing. When the state is Incoming with `autoAnswer`, it runs
/// [onAnswer] — the SAME path as the Accept button (mic check → accept) —
/// ONCE per call, after the frame (a dialog needs a laid-out screen).
///
/// Why a widget with its own state, not a `BlocListener`? A listener only
/// sees CHANGES after it's built. The call page is often built for the
/// first time when the state is ALREADY `autoAnswer` (the app was opening),
/// so a listener would miss it — the same trap as the stuck "…" screen.
class CallAutoAnswer extends StatefulWidget {
  const CallAutoAnswer({
    super.key,
    required this.state,
    required this.onAnswer,
  });

  final CallViewModelState state;
  final VoidCallback onAnswer;

  @override
  State<CallAutoAnswer> createState() => _CallAutoAnswerState();
}

class _CallAutoAnswerState extends State<CallAutoAnswer> {
  /// The call we already answered for (never twice for one call).
  String? _answered;

  @override
  void initState() {
    super.initState();
    _maybeAnswer();
  }

  @override
  void didUpdateWidget(CallAutoAnswer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeAnswer();
  }

  void _maybeAnswer() {
    final s = widget.state;
    if (s is! CallIncomingState || !s.autoAnswer || s.accepting) return;
    if (_answered == s.call.id) return;
    _answered = s.call.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onAnswer();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
