import '../../../core/realtime/realtime_event.dart';
import 'call_model.dart';

/// A live call event from the server, turned into our models.
///
/// | event         | payload (backend `ChatCallController`)           | update         |
/// |---------------|--------------------------------------------------|----------------|
/// | `call.invite` | `ChatCallDto`                                    | [CallInvited]  |
/// | `call.ringing`| `{callId, userId, conversationId}`               | [CallRinging]  |
/// | `call.accept` | `{callId, accepterId, call}`                     | [CallAccepted] |
/// | `call.reject` | `{callId, rejecterId, reason, call}`             | [CallRejected] |
/// | `call.hangup` | `{callId, hangerUpperId, call, reason?}`         | [CallHungUp]   |
///
/// Anything else → null, ignored.
sealed class CallUpdate {
  const CallUpdate(this.callId);

  final String callId;

  static CallUpdate? fromRealtime(RealtimeEvent event) {
    final p = event.payloadMap;
    if (p == null) return null;
    CallModel? call() => p['call'] is Map<String, dynamic>
        ? CallModel.fromJson(p['call'] as Map<String, dynamic>)
        : null;
    try {
      return switch (event.event) {
        'call.invite' => CallInvited(CallModel.fromJson(p)),
        'call.ringing' => CallRinging(
          '${p['callId']}',
          userId: '${p['userId']}',
        ),
        'call.accept' => CallAccepted(
          '${p['callId']}',
          accepterId: '${p['accepterId']}',
          call: call(),
        ),
        'call.reject' => CallRejected(
          '${p['callId']}',
          rejecterId: '${p['rejecterId']}',
          reason: p['reason'] as String?,
          call: call(),
        ),
        'call.hangup' => CallHungUp(
          '${p['callId']}',
          hangerUpperId: '${p['hangerUpperId']}',
          reason: p['reason'] as String?,
          call: call(),
        ),
        _ => null,
      };
    } catch (_) {
      return null; // a payload we can't read must never break a call
    }
  }
}

/// Someone calls (sent to every callee).
final class CallInvited extends CallUpdate {
  CallInvited(this.call) : super(call.id);

  final CallModel call;
}

/// [userId]'s phone shows the call → the caller's "Calling…" → "Ringing…".
final class CallRinging extends CallUpdate {
  const CallRinging(super.callId, {required this.userId});

  final String userId;
}

/// [accepterId] answered.
final class CallAccepted extends CallUpdate {
  const CallAccepted(super.callId, {required this.accepterId, this.call});

  final String accepterId;
  final CallModel? call;
}

/// [rejecterId] declined. [reason] is `"busy"` for an automatic "I'm busy".
/// [call]`.status.isOver` tells if the whole call ended (a 1-to-1 call does).
final class CallRejected extends CallUpdate {
  const CallRejected(
    super.callId, {
    required this.rejecterId,
    this.reason,
    this.call,
  });

  final String rejecterId;
  final String? reason;
  final CallModel? call;
}

/// [hangerUpperId] hung up, or the server gave up ([reason] `"no_answer"`).
final class CallHungUp extends CallUpdate {
  const CallHungUp(
    super.callId, {
    required this.hangerUpperId,
    this.reason,
    this.call,
  });

  final String hangerUpperId;
  final String? reason;
  final CallModel? call;
}
