import 'package:flutter/foundation.dart';

/// Which button the user pressed on the iOS CallKit screen (Step 7.3).
enum CallKitButton { accept, decline, end }

/// A CallKit button press, turned into OUR call id.
///
/// Stream's VoIP push carries the Stream call id (`default:erp-call-12`);
/// our backend makes it from our id (`StreamTokenService.cidForCall`), so
/// `12` comes back out with no request.
@immutable
class CallKitAction {
  const CallKitAction(this.button, this.callId);

  final CallKitButton button;
  final String callId;

  static const _prefix = 'erp-call-';

  /// `default:erp-call-12` → `12`. Not one of our calls → null.
  static String? callIdOf(String? cid) {
    if (cid == null) return null;
    final id = cid.substring(cid.indexOf(':') + 1);
    if (!id.startsWith(_prefix)) return null;
    final callId = id.substring(_prefix.length);
    return callId.isEmpty ? null : callId;
  }

  /// Our call id → the Stream call id (to end its CallKit screen).
  static String cidOf(String callId) => 'default:$_prefix$callId';

  @override
  bool operator ==(Object other) =>
      other is CallKitAction &&
      other.button == button &&
      other.callId == callId;

  @override
  int get hashCode => Object.hash(button, callId);

  @override
  String toString() => 'CallKitAction(${button.name}, $callId)';
}
