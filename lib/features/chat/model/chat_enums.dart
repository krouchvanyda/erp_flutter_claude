// Chat enums — the same names as the backend (API_LIST_BACKEND.md "Enums").
//
// `fromJson` never crashes: an unknown value (the backend adds a new type one
// day) falls back to a safe default instead of breaking the inbox.

/// `DIRECT` (2 people) or `GROUP`.
enum ConversationType {
  direct,
  group;

  static ConversationType fromJson(Object? value) =>
      value == 'GROUP' ? group : direct;
}

/// `TEXT`, `IMAGE`, `VOICE`, `FILE`, `CALL` (6.3d: a call line the SERVER
/// writes when a call ends — the app never sends one).
enum MessageType {
  text,
  image,
  voice,
  file,
  call;

  static MessageType fromJson(Object? value) => switch (value) {
    'IMAGE' => image,
    'VOICE' => voice,
    'FILE' => file,
    'CALL' => call,
    _ => text,
  };

  /// For requests: `MessageType.image` → `"IMAGE"`.
  String toJson() => name.toUpperCase();
}

/// A member's role in a group: `ADMIN` can rename / add / remove.
enum MemberRole {
  admin,
  member;

  static MemberRole fromJson(Object? value) =>
      value == 'ADMIN' ? admin : member;
}
