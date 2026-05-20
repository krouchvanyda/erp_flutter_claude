import 'dart:async';

import '../../../../core/error/failure.dart';
import '../../entities/my_profile.dart';

/// Slice 9.1.4 — in-memory profile state for the signed-in user.
///
/// Demo-grade: in production this composes `CachedUserDao` (drift) for
/// id/email/displayName with the HR Employee record for the rest. For
/// the design demo we seed a single record and let the page mutate it
/// via [update]. Returning a stream keeps the page contract identical
/// to what the real drift-backed implementation will expose.
///
/// Re-auth events (change password / PIN / biometric) round-trip through
/// the auth feature — this repo only tracks the profile bits.
class MyProfileRepository {
  MyProfileRepository();

  static MyProfile _state = MyProfile(
    id: 'user-demo',
    name: 'Demo Approver',
    email: 'demo@erp.example',
    phone: '+855 12 345 678',
    employeeId: 'EMP-001',
    role: 'Administrator',
    department: 'Operations',
    hiredAt: DateTime.utc(2024, 4, 1),
    birthdate: DateTime.utc(1990, 3, 12),
    address: '#42, Street 240, Phnom Penh, Cambodia',
    emergencyContactName: 'Sophea Approver',
    emergencyContactPhone: '+855 12 999 000',
    lastLoginAt: DateTime.utc(2026, 5, 15, 9, 0),
    lastLoginDevice: 'Pixel 7 Pro · Phnom Penh',
    avatarTone: 0,
  );

  final StreamController<MyProfile> _changes =
      StreamController<MyProfile>.broadcast();

  Future<MyProfile> get() async => _state;

  Stream<MyProfile> watch() async* {
    yield _state;
    yield* _changes.stream;
  }

  /// Persist a fully-validated edit. Sensitive-field changes (email,
  /// phone) trigger a verification flow in real life; here we just
  /// persist and let the page surface the "Requires verification" hint.
  Future<MyProfile> update(MyProfile next) async {
    final errors = <String, List<String>>{};
    if (next.name.trim().isEmpty) {
      errors.putIfAbsent('name', () => []).add('Required');
    }
    if (!_emailLooksValid(next.email)) {
      errors.putIfAbsent('email', () => []).add('Looks invalid');
    }
    if (next.phone.trim().isEmpty) {
      errors.putIfAbsent('phone', () => []).add('Required');
    }
    if (errors.isNotEmpty) {
      throw ValidationFailure(fieldErrors: errors);
    }
    _state = next;
    if (!_changes.isClosed) _changes.add(_state);
    return _state;
  }

  /// Rotates the gradient tone shown when no photo is picked. Used by
  /// the "Cycle preset tone" sheet option as a quick palette switch.
  Future<MyProfile> setAvatarTone(int tone) async {
    final clamped = tone % 4;
    _state = _state.copyWith(avatarTone: clamped);
    if (!_changes.isClosed) _changes.add(_state);
    return _state;
  }

  /// Persist the path returned by `ImagePicker` (camera or gallery).
  /// In production this would also upload to the server; the demo
  /// just keeps the local file path so the hero card can render it.
  Future<MyProfile> setAvatarPath(String path) async {
    _state = _state.copyWith(avatarFilePath: path);
    if (!_changes.isClosed) _changes.add(_state);
    return _state;
  }

  /// "Remove photo" — drops the uploaded image and falls back to
  /// initials over the current gradient tone.
  Future<MyProfile> clearAvatar() async {
    _state = _state.copyWith(clearAvatarFilePath: true);
    if (!_changes.isClosed) _changes.add(_state);
    return _state;
  }
}

bool _emailLooksValid(String email) {
  final trimmed = email.trim();
  if (trimmed.isEmpty) return false;
  final at = trimmed.indexOf('@');
  if (at <= 0 || at == trimmed.length - 1) return false;
  if (trimmed.contains(' ')) return false;
  if (!trimmed.substring(at).contains('.')) return false;
  return true;
}
