/// Someone I can start a chat with (backend `UserDto` from `GET /users`).
///
/// Only the fields the picker needs. `UserDto` also has `roles` /
/// `permissions`; we don't read them (CLAUDE.md: no permission checks here).
class ContactModel {
  const ContactModel({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.enabled = true,
  });

  final String id; // a number on the wire → String
  final String email;
  final String? fullName;
  final String? avatarUrl; // "/uploads/..." or null
  final bool enabled; // disabled accounts are hidden in the picker

  String get displayName {
    final name = fullName?.trim() ?? '';
    return name.isEmpty ? email : name;
  }

  /// Phone-side search (the server ignores `search`): name OR email,
  /// any case. "dara" finds "Dara Sok" and "dara.sok@company.com".
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return displayName.toLowerCase().contains(q) ||
        email.toLowerCase().contains(q);
  }

  factory ContactModel.fromJson(Map<String, dynamic> json) => ContactModel(
    id: '${json['id'] ?? ''}',
    email: json['email'] as String? ?? '',
    fullName: json['fullName'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    enabled: json['enabled'] as bool? ?? true,
  );

  @override
  bool operator ==(Object other) =>
      other is ContactModel &&
      other.id == id &&
      other.email == email &&
      other.fullName == fullName &&
      other.avatarUrl == avatarUrl &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(id, email, fullName, avatarUrl, enabled);

  @override
  String toString() => 'ContactModel($id)'; // no email / name in logs
}
