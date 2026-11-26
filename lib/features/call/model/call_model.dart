import 'package:collection/collection.dart';

import 'call_enums.dart';

/// One person in a call (backend `CallParticipantDto`).
class CallParticipantModel {
  const CallParticipantModel({required this.userId, required this.status});

  final String userId;
  final ParticipantStatus status;

  factory CallParticipantModel.fromJson(Map<String, dynamic> json) =>
      CallParticipantModel(
        userId: '${json['userId'] ?? ''}',
        status: ParticipantStatus.fromJson(json['status']),
      );

  @override
  bool operator ==(Object other) =>
      other is CallParticipantModel &&
      other.userId == userId &&
      other.status == status;

  @override
  int get hashCode => Object.hash(userId, status);

  @override
  String toString() => 'CallParticipantModel($userId, ${status.name})';
}

/// A call (backend `ChatCallDto`). Only the fields the app uses.
///
/// `streamCallCid` is the Stream Video call to join for the sound and
/// picture (Step 6.2). Everything else (who rings, who accepted, who hung
/// up) is OUR server's job.
class CallModel {
  const CallModel({
    required this.id,
    required this.conversationId,
    required this.callerId,
    required this.type,
    required this.status,
    this.startedAt,
    this.answeredAt,
    this.endReason,
    this.streamCallCid,
    this.callerAvatarUrl,
    this.callerName,
    this.participants = const [],
  });

  final String id;
  final String conversationId;
  final String callerId;
  final CallType type;
  final CallStatus status;
  final DateTime? startedAt;
  final DateTime? answeredAt;

  /// Why it ended: `"no_answer"`, `"caller_left"`, `"busy"`, … (free text).
  final String? endReason;
  final String? streamCallCid;
  final String? callerAvatarUrl;

  /// WHO is calling, sent by the backend in the call itself (with
  /// [callerAvatarUrl]): the ringing screen shows it at once, no chat
  /// lookup. Null from an old backend.
  final String? callerName;
  final List<CallParticipantModel> participants;

  bool get isVideo => type == CallType.video;

  factory CallModel.fromJson(Map<String, dynamic> json) => CallModel(
    id: '${json['id'] ?? ''}',
    conversationId: '${json['conversationId'] ?? ''}',
    callerId: '${json['callerId'] ?? ''}',
    type: CallType.fromJson(json['type']),
    status: CallStatus.fromJson(json['status']),
    startedAt: _date(json['startedAt']),
    answeredAt: _date(json['answeredAt']),
    endReason: json['endReason'] as String?,
    streamCallCid: json['streamCallCid'] as String?,
    callerAvatarUrl: json['callerAvatarUrl'] as String?,
    callerName: json['callerName'] as String?,
    participants: [
      for (final p in json['participants'] as List? ?? const [])
        CallParticipantModel.fromJson(p as Map<String, dynamic>),
    ],
  );

  static DateTime? _date(Object? value) =>
      DateTime.tryParse(value as String? ?? '')?.toLocal();

  CallModel copyWith({CallStatus? status, String? endReason}) => CallModel(
    id: id,
    conversationId: conversationId,
    callerId: callerId,
    type: type,
    status: status ?? this.status,
    startedAt: startedAt,
    answeredAt: answeredAt,
    endReason: endReason ?? this.endReason,
    streamCallCid: streamCallCid,
    callerAvatarUrl: callerAvatarUrl,
    callerName: callerName,
    participants: participants,
  );

  static const _list = ListEquality<CallParticipantModel>();

  @override
  bool operator ==(Object other) =>
      other is CallModel &&
      other.id == id &&
      other.conversationId == conversationId &&
      other.callerId == callerId &&
      other.type == type &&
      other.status == status &&
      other.startedAt == startedAt &&
      other.answeredAt == answeredAt &&
      other.endReason == endReason &&
      other.streamCallCid == streamCallCid &&
      other.callerAvatarUrl == callerAvatarUrl &&
      other.callerName == callerName &&
      _list.equals(other.participants, participants);

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    callerId,
    type,
    status,
    startedAt,
    answeredAt,
    endReason,
    streamCallCid,
    callerAvatarUrl,
    callerName,
    _list.hash(participants),
  );

  @override
  String toString() => 'CallModel($id, ${type.name}, ${status.name})';
}
