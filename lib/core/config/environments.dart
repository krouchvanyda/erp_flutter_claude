/// Every backend URL in one place.
///
/// Change a host here, and every flavor that uses it follows.
///
/// `*ApiBaseUrl` is the server ROOT (no `/api/v1`): `/health` lives outside
/// `/api/v1`, so the version prefix is part of each endpoint in
/// `ApiEndPoint`.
///
/// `*RealtimeUrl` is the STOMP endpoint: the backend's `/ws` (Step 5.3).
class Environments {
  Environments._(); // no instances — only static constants

  // ── Local dev ── (your laptop's LAN IP; Android emulator → 10.0.2.2)
  static const String localApiBaseUrl = 'http://172.26.17.118:8080';
  static const String localRealtimeUrl = 'ws://172.26.17.118:8080/ws';

  // ── Staging (UAT) ──
  static const String stagingApiBaseUrl = 'http://172.26.17.118:8080';
  static const String stagingRealtimeUrl = 'ws://172.26.17.118:8080/ws';

  // ── Production ──
  static const String prodApiBaseUrl = 'http://172.26.17.118:8080';
  static const String prodRealtimeUrl = 'ws://172.26.17.118:8080/ws';
}
