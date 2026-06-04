import 'package:equatable/equatable.dart';

/// PKCE proof material — RFC 7636.
///
/// `verifier` is the high-entropy secret; `challenge` is the value the
/// auth server stores during the authorization request and verifies
/// later by re-deriving SHA-256(verifier).
///
/// **Memory-only** (per CLAUDE.md Slice 1.2.2): both fields live in the
/// in-flight `OAuthFlowSession`. Neither is ever written to drift,
/// `flutter_secure_storage`, or `shared_preferences` — they're transient
/// proof material with no value once the flow completes.
class PkceChallenge extends Equatable {
  const PkceChallenge({
    required this.verifier,
    required this.challenge,
    this.method = 'S256',
  });

  /// 43-128 char unreserved-character string (`[A-Z][a-z][0-9]-._~`).
  final String verifier;

  /// `BASE64URL(SHA-256(verifier))` with `=` padding stripped, per
  /// RFC 7636 §4.2 when `method == 'S256'`.
  final String challenge;

  /// Always `'S256'` for new flows; the spec also allows `'plain'`
  /// for legacy clients but we never emit that.
  final String method;

  PkceChallenge copyWith({
    String? verifier,
    String? challenge,
    String? method,
  }) {
    return PkceChallenge(
      verifier: verifier ?? this.verifier,
      challenge: challenge ?? this.challenge,
      method: method ?? this.method,
    );
  }

  @override
  List<Object?> get props => [verifier, challenge, method];
}
