import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_font_size.dart';
import '../../../core/theme/app_label.dart';

/// "00:12" — talking time, counted from [since].
///
/// The ticking lives HERE (a UI clock), not in the bloc: a state per second
/// would rebuild the whole call screen for nothing. The bloc only knows
/// WHEN the call connected.
class CallTimerText extends StatefulWidget {
  const CallTimerText({super.key, required this.since, this.color});

  final DateTime since;
  final Color? color;

  /// 75 s → "01:15", 3725 s → "1:02:05".
  static String format(Duration d) {
    final s = d.isNegative ? Duration.zero : d;
    String two(int n) => n.toString().padLeft(2, '0');
    final mm = two(s.inMinutes.remainder(60));
    final ss = two(s.inSeconds.remainder(60));
    return s.inHours > 0 ? '${s.inHours}:$mm:$ss' : '$mm:$ss';
  }

  @override
  State<CallTimerText> createState() => _CallTimerTextState();
}

class _CallTimerTextState extends State<CallTimerText> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppLabel(
    text: CallTimerText.format(DateTime.now().difference(widget.since)),
    fontSize: AppFontSize.value16,
    fontWeight: FontWeight.w500,
    color: widget.color,
  );
}
