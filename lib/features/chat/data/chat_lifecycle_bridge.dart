import 'package:flutter/widgets.dart';

import 'chat_settings.dart';
import 'chat_transport.dart';
import 'repositories/presence_repository.dart';

/// Slice 10.2.6 — keeps [ChatTransport] in sync with the app's
/// foreground / background lifecycle.
///
/// **What this fixes:**
/// - Android / iOS routinely suspend long-lived TCP sockets when the
///   app is backgrounded; the OS may keep them alive for a few minutes
///   but typically not longer. When the user returns to the app the
///   socket can be silently dead, so the auto-reconnect needs a kick.
/// - Some manufacturer ROMs throttle networking aggressively in the
///   background, which can drop call invites that arrive during that
///   window. Forcing a reconnect on `resumed` makes sure we catch the
///   missed-call rows the next time the transport syncs.
///
/// **What this CANNOT fix (and the killed-app honesty note):**
/// The WebSocket relay is a local-LAN demo. When the OS terminates
/// the app process (force-stop, low memory kill, swipe-away on some
/// devices) the socket is gone and there is no background service to
/// re-open it. A peer's `call.invite` envelope hits nobody and the
/// log row stays in `noAnswer` / `missed` forever. The production
/// path for this is FCM / APNs push: a backend wakes the device with
/// a high-priority push, which spins up a background isolate that
/// shows the incoming call sheet via `flutter_local_notifications`.
/// None of that is wired here — see CLAUDE.md slice 10.2.6.
class ChatLifecycleBridge with WidgetsBindingObserver {
  ChatLifecycleBridge({
    required this.transport,
    required this.settings,
    required this.presence,
  });

  final ChatTransport transport;
  final ChatSettings settings;
  final PresenceRepository presence;

  void attach() {
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Force the transport to re-check its connection. If the socket
      // is still healthy this is a no-op; if it died while we were
      // backgrounded the reconnect timer kicks in.
      transport.updateConfig(
        url: settings.relayUrl,
        userId: settings.userId,
        userName: settings.userName,
      );
      // Re-hydrate presence: the broker may have advanced while we
      // were backgrounded, and `/topic/presence` only delivers
      // deltas (not the current snapshot) once we reconnect.
      presence.loadAll();
    }
  }
}
