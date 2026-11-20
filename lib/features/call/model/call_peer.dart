/// Who is on the other side, for the call screen: a name and a photo.
///
/// The call feature knows only ids. The chat feature knows names (the
/// conversation's members), so `app/` turns one into the other — the call
/// feature never imports chat.
class CallPeer {
  const CallPeer({required this.name, this.avatarUrl, this.isGroup = false});

  /// Shown until the name is loaded (an incoming call carries only ids).
  static const unknown = CallPeer(name: '');

  /// A person's name, or the group's name.
  final String name;

  /// A full URL (already through `ApiEndPoint.fileUrl`), or null → initials.
  final String? avatarUrl;
  final bool isGroup;

  @override
  bool operator ==(Object other) =>
      other is CallPeer &&
      other.name == name &&
      other.avatarUrl == avatarUrl &&
      other.isGroup == isGroup;

  @override
  int get hashCode => Object.hash(name, avatarUrl, isGroup);

  @override
  String toString() => 'CallPeer(group: $isGroup)'; // no name: private data
}
