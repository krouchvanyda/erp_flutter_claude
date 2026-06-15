import 'dart:async';

import 'package:erp_mobile/core/di/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_transport.dart';

/// Persistent settings for the chat module — current user identity and
/// the backend API base URL the [ChatTransport] connects to.
///
/// Backed by `shared_preferences` so the user's identity and backend URL
/// survive app restarts. Identity defaults to empty — `bootChatTransport`
/// fills it from `/users/me` at app start.
class ChatSettings {
  ChatSettings._();
  static final ChatSettings instance = ChatSettings._();

  static const _kUserId = 'chat.currentUserId';
  static const _kUserName = 'chat.currentUserName';
  static const _kApiBaseUrl = 'chat.apiBaseUrl';

  // Default to empty — `bootChatTransport` calls `/users/me` at app
  // start and writes the real backend user id/name via [setIdentity].
  // No demo defaults — authentication is real and the backend is
  // the single source of truth for identity.
  String _userId = '';
  String _userName = '';
  String _apiBaseUrl = '';

  final StreamController<ChatSettings> _changes =
      StreamController<ChatSettings>.broadcast();

  String get userId => _userId;
  String get userName => _userName;

  /// REST + STOMP base URL for the real ERP backend. Set via the
  /// **Settings → API Config** screen or the chat ⋮ menu. Empty
  /// string means "fall back to the legacy relay" so existing
  /// demos still work mid-migration.
  ///
  /// Format: `http(s)://host[:port]` (no trailing slash, no `/api/v1`).
  /// STOMP path `/ws` and REST prefix `/api/v1` are appended by the
  /// transport + data source — they're not part of this value.
  ///
  /// Examples:
  ///   real phone, same Wi-Fi:  http://192.168.1.42:8080
  ///   Android emulator:        http://10.0.2.2:8080
  ///   iOS simulator:           http://127.0.0.1:8080
  String get apiBaseUrl => _apiBaseUrl;

  /// Reactive view of the settings record — emits the same singleton
  /// every time one of the fields changes so listeners can rebuild.
  Stream<ChatSettings> watch() async* {
    yield this;
    yield* _changes.stream;
  }

  /// Load persisted settings. Idempotent — safe to call from `main`.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_kUserId) ?? '';
    _userName = prefs.getString(_kUserName) ?? '';
    _apiBaseUrl = prefs.getString(_kApiBaseUrl) ?? '';
    _emit();
  }

  Future<void> setApiBaseUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed == _apiBaseUrl) return;
    _apiBaseUrl = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiBaseUrl, trimmed);
    _emit();
  }

  Future<void> setIdentity({required String userId, required String userName}) async {
    if (userId == _userId && userName == _userName) return;
    final nameChanged = userId == _userId && userName != _userName;
    _userId = userId;
    _userName = userName;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kUserName, userName);
    _emit();
    // Slice 10.3.4 — when the same user keeps their id but updates
    // their display name, broadcast so every peer renames its local
    // direct conv with us. Identity SWITCHES (different userId)
    // don't fire this — the transport reconnects with the new
    // identity anyway, and we don't want to clobber the original
    // user's name on peers.
    if (nameChanged && GetIt.I.isRegistered<ChatTransport>()) {
      GetIt.I<ChatTransport>().sendProfileUpdate(
        userId: userId,
        newName: userName,
      );
    }
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(this);
  }
}
