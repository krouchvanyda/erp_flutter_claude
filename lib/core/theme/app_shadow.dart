import 'package:flutter/painting.dart';

/// Elevation shadows.
abstract final class AppShadow {
  static const BoxShadow card = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static const BoxShadow modal = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );
}
