import 'package:collection/collection.dart';

/// One person's name + photo, for group calls (Stream only knows user ids).
class CallMember {
  const CallMember({required this.name, this.avatarUrl});

  final String name;

  /// A full URL (already through `ApiEndPoint.fileUrl`), or null → initials.
  final String? avatarUrl;

  /// "Jane Doe" → "Jane".
  String get firstName {
    final first = name.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? name : first;
  }

  @override
  bool operator ==(Object other) =>
      other is CallMember && other.name == name && other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(name, avatarUrl);

  @override
  String toString() => 'CallMember()'; // no name: private data
}

/// Who is on the other side, for the call screen: a name and a photo.
///
/// The call feature knows only ids. The chat feature knows names (the
/// conversation's members), so `app/` turns one into the other — the call
/// feature never imports chat.
class CallPeer {
  const CallPeer({
    required this.name,
    this.avatarUrl,
    this.isGroup = false,
    this.members = const {},
  });

  /// Shown until the name is loaded (an incoming call carries only ids).
  static const unknown = CallPeer(name: '');

  /// A person's name, or the group's name.
  final String name;

  /// A full URL (already through `ApiEndPoint.fileUrl`), or null → initials.
  final String? avatarUrl;
  final bool isGroup;

  /// userId → name + photo of everyone in the conversation (6.3c): who is
  /// calling, who is in the call, the names on the video tiles.
  final Map<String, CallMember> members;

  /// A member, or a "?" placeholder for an id we don't know (yet).
  CallMember member(String userId) =>
      members[userId] ?? const CallMember(name: '');

  static const _map = MapEquality<String, CallMember>();

  @override
  bool operator ==(Object other) =>
      other is CallPeer &&
      other.name == name &&
      other.avatarUrl == avatarUrl &&
      other.isGroup == isGroup &&
      _map.equals(other.members, members);

  @override
  int get hashCode => Object.hash(name, avatarUrl, isGroup, _map.hash(members));

  @override
  String toString() => 'CallPeer(group: $isGroup)'; // no name: private data
}
