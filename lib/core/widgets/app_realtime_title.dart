import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../realtime/realtime_service.dart';
import '../theme/app_font_size.dart';
import '../theme/app_label.dart';
import '../theme/app_spacing.dart';

/// An app bar title that says when the live connection is down
/// (Telegram style):
///
/// ```
/// connected / stopped:   Chats
/// connecting:            ⟳ Connecting…
/// ```
///
/// Silent when all is fine; the user only sees it when updates may be late.
class AppRealtimeTitle extends StatelessWidget {
  const AppRealtimeTitle({
    super.key,
    required this.title,
    required this.status,
  });

  final String title;
  final ValueListenable<RealtimeStatus> status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<RealtimeStatus>(
      valueListenable: status,
      builder: (context, value, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        layoutBuilder: (current, previous) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [...previous, ?current],
        ),
        child: value == RealtimeStatus.connecting
            ? Row(
                key: const ValueKey('connecting'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  AppLabel(
                    text: 'Connecting…',
                    fontSize: AppFontSize.value18,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              )
            : AppLabel(
                key: const ValueKey('title'),
                text: title,
                fontSize: AppFontSize.value24,
                fontWeight: FontWeight.w700,
              ),
      ),
    );
  }
}
