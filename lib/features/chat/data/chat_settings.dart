import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_seed.dart';
import 'chat_transport.dart';

/// Persistent demo settings for the chat module — current user identity
/// and the WebSocket relay URL the [ChatTransport] connects to.
///
/// Backed by `shared_preferences` so the user's identity choice and
/// relay URL survive app restarts. The defaults match a single-device
/// demo (the seeded `user-demo` identity, no relay URL).
class ChatSettings {
  ChatSettings._();
  static final ChatSettings instance = ChatSettings._();

  static const _kUserId = 'chat.currentUserId';
  static const _kUserName = 'chat.currentUserName';
  static const _kRelayUrl = 'chat.relayUrl';

  String _userId = ChatSeed.currentUserId;
  String _userName = ChatSeed.currentUserName;
  String _relayUrl = '';

  final StreamController<ChatSettings> _changes =
      StreamController<ChatSettings>.broadcast();

  String get userId => _userId;
  String get userName => _userName;

  /// Empty string = transport stays offline. Examples:
  ///   real phone, same Wi-Fi:  ws://192.168.1.42:7777
  ///   Android emulator:        ws://10.0.2.2:7777
  String get relayUrl => _relayUrl;

  /// Reactive view of the settings record — emits the same singleton
  /// every time one of the fields changes so listeners can rebuild.
  Stream<ChatSettings> watch() async* {
    yield this;
    yield* _changes.stream;
  }

  /// Load persisted settings. Idempotent — safe to call from `main`.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_kUserId) ?? ChatSeed.currentUserId;
    _userName = prefs.getString(_kUserName) ?? ChatSeed.currentUserName;
    _relayUrl = prefs.getString(_kRelayUrl) ?? '';
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

  Future<void> setRelayUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed == _relayUrl) return;
    _relayUrl = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRelayUrl, trimmed);
    _emit();
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(this);
  }
}
