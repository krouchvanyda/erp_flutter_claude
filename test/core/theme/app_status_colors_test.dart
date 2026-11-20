import 'dart:ui' show Color;

import 'package:erp_mobile/core/theme/app_status_colors.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast ratio: 1:1 (same colour) … 21:1 (black on white).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // Small text needs at least 4.5:1 (WCAG AA). If someone changes a colour
  // and makes the snackbar text hard to read, this test fails.
  for (final (mode, c) in [
    ('light', AppStatusColors.light),
    ('dark', AppStatusColors.dark),
  ]) {
    test('$mode: every status pair is readable (≥ 4.5:1)', () {
      expect(contrast(c.success, c.onSuccess), greaterThanOrEqualTo(4.5));
      expect(contrast(c.warning, c.onWarning), greaterThanOrEqualTo(4.5));
      expect(contrast(c.error, c.onError), greaterThanOrEqualTo(4.5));
    });
  }

  test('lerp halfway mixes the colours (smooth light ↔ dark switch)', () {
    final mid = AppStatusColors.light.lerp(AppStatusColors.dark, 0.5);
    expect(mid.success, isNot(AppStatusColors.light.success));
    expect(mid.success, isNot(AppStatusColors.dark.success));
  });
}
