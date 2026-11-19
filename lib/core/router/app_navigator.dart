import 'package:flutter/widgets.dart';

/// The root [Navigator]'s key.
///
/// Lets code WITHOUT a `BuildContext` under the navigator still navigate:
/// - `AuthGate` closes pushed pages on logout (Step 1.4)
/// - the token interceptor sends you to login on refresh failure (Step 2)
/// - the incoming-call overlay pushes the call page (Step 6 — lesson from
///   the old app: the overlay sits BESIDE the navigator, so
///   `Navigator.of(context)` finds nothing)
abstract final class AppNavigator {
  static final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );
}
