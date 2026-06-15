/// PKCE proof material — RFC 7636.
///
/// `verifier` is the high-entropy secret; `challenge` is the value the
/// auth server stores during the authorization request and verifies
/// later by re-deriving SHA-256(verifier).
///
/// **Memory-only** (per CLAUDE.md Slice 1.2.2). Plain immutable value type
/// (was `freezed`; the codegen was removed).
class PkceChallenge {
  const PkceChallenge({
    required this.verifier,
    required this.challenge,
    this.method = 'S256',
  });

  /// 43-128 char unreserved-character string (`[A-Z][a-z][0-9]-._~`).
  final String verifier;

  /// `BASE64URL(SHA-256(verifier))` with `=` padding stripped.
  final String challenge;

  /// Always `'S256'` for new flows.
  final String method;

  PkceChallenge copyWith({String? verifier, String? challenge, String? method}) =>
      PkceChallenge(
        verifier: verifier ?? this.verifier,
        challenge: challenge ?? this.challenge,
        method: method ?? this.method,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PkceChallenge &&
          other.verifier == verifier &&
          other.challenge == challenge &&
          other.method == method);

  @override
  int get hashCode => Object.hash(verifier, challenge, method);
}
