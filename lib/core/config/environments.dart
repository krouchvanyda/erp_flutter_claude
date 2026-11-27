/// Every backend URL in one place.
///
/// Change a host here, and every flavor that uses it follows.
///
/// `*ApiBaseUrl` is the server ROOT (no `/api/v1`): `/health` lives outside
/// `/api/v1`, so the version prefix is part of each endpoint in
/// `ApiEndPoint`.
///
/// `*RealtimeUrl` is the live door: the backend's plain WebSocket `/realtime`
/// (Track B, R5). The old STOMP door `/ws` (Step 5.3) still exists on the
/// backend for old builds.
class Environments {
  Environments._(); // no instances — only static constants

  // ── Local dev ── (your laptop's LAN IP; Android emulator → 10.0.2.2)
  static const String localApiBaseUrl = 'http://172.26.17.118:8080';
  static const String localRealtimeUrl = 'ws://172.26.17.118:8080/realtime';

  // ── Staging (UAT) ──
  static const String stagingApiBaseUrl = 'http://172.26.17.118:8080';
  static const String stagingRealtimeUrl = 'ws://172.26.17.118:8080/realtime';

  // ── Production ──
  static const String prodApiBaseUrl = 'http://172.26.17.118:8080';
  static const String prodRealtimeUrl = 'ws://172.26.17.118:8080/realtime';
}
