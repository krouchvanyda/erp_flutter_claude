/// A call push from OUR backend over FCM (Step 7.2). Data-only messages, sent
/// by `ChatCallController` at HIGH priority:
///
/// | `type`        | fields                                                      |
/// |---------------|-------------------------------------------------------------|
/// | `call.invite` | callId · conversationId · callerId · callerName · callerAvatarUrl · callType (`voice`/`video`) |
/// | `call.cancel` | callId · reason (`accepted_elsewhere` / `rejected` / `hangup` / `timeout` / `disconnect`) |
///
/// Anything else (a chat message push…) → null.
sealed class CallPush {
  const CallPush(this.callId);

  final String callId;

  static CallPush? fromData(Map<String, dynamic> data) {
    final callId = '${data['callId'] ?? ''}';
    if (callId.isEmpty) return null;
    return switch (data['type']) {
      'call.invite' => CallPushInvite(
        callId,
        conversationId: '${data['conversationId'] ?? ''}',
        callerName: (data['callerName'] as String?)?.trim() ?? '',
        callerAvatarUrl: data['callerAvatarUrl'] as String?,
        video: data['callType'] == 'video',
      ),
      'call.cancel' => CallPushCancel(
        callId,
        reason: data['reason'] as String?,
      ),
      _ => null,
    };
  }
}

/// Someone calls me → ring.
final class CallPushInvite extends CallPush {
  const CallPushInvite(
    super.callId, {
    required this.conversationId,
    required this.callerName,
    this.callerAvatarUrl,
    this.video = false,
  });

  final String conversationId;
  final String callerName;
  final String? callerAvatarUrl;
  final bool video;

  @override
  String toString() => 'CallPushInvite($callId)'; // no name: private data
}

/// Stop ringing: answered elsewhere, declined, the caller gave up…
final class CallPushCancel extends CallPush {
  const CallPushCancel(super.callId, {this.reason});

  final String? reason;

  @override
  String toString() => 'CallPushCancel($callId, $reason)';
}
