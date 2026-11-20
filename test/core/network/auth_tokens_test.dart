import 'dart:convert';

import 'package:erp_mobile/core/network/auth_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake JWT: header.payload.signature (signature not checked by the app).
String jwt(Map<String, dynamic> payload) {
  String part(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(payload)}.signature';
}

void main() {
  test('userId = the JWT "sub" claim (no padding needed)', () {
    final tokens = AuthTokens(
      accessToken: jwt({'sub': '42', 'email': 'v@x.com'}),
      refreshToken: 'r',
    );
    expect(tokens.userId, '42');
  });

  test('not a JWT → null, never a crash', () {
    expect(
      const AuthTokens(accessToken: 'abc', refreshToken: 'r').userId,
      isNull,
    );
    expect(
      const AuthTokens(accessToken: 'a.!!!.c', refreshToken: 'r').userId,
      isNull,
    );
  });
}
