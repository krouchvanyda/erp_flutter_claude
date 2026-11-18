import 'package:stream_video_flutter/stream_video_flutter.dart'
    show SfuConnectionQuality;

/// Scenario 8 (bad network) — ported from flutter-chat
/// (`docs/guides/this-project/CALL_CODE_TRACE.md`, "Scenario 8").

/// How long Stream keeps trying to reconnect a call before it gives up
/// (`ReconnectionFailed` → the call ends: "Couldn't connect the call").
/// Stream's defaults are "forever" / 5 min — far too long for a phone call.
const Duration callReconnectTimeout = Duration(seconds: 30);

/// Custom Stream event sent to the other phone when this phone's call is
/// back from "Reconnecting…", so it drops my old "poor" rating at once.
const String reconnectedEventKind = 'reconnected';

/// What the call screen shows about the network.
enum CallNetwork {
  /// Fine (or not known yet) — the timer shows.
  good,

  /// My connection is poor — "Your network is weak".
  weak,

  /// The other person's connection is poor — "@name's network is weak".
  peerWeak,

  /// My network dropped; Stream is reconnecting — "Reconnecting…".
  reconnecting,
}

/// Stream's connection-quality ratings → the "network is weak" note.
///
/// Stream only sends a new rating when it changes, so after a reconnect the
/// "poor" rating from the outage would stay on screen until the next one.
/// So: when the call comes back from "Reconnecting…", the ratings at that
/// moment are ignored (shown as good) until one of them changes; a really
/// weak network then shows again with Stream's next rating.
class NetworkRatings {
  bool _reconnecting = false;

  /// After a reconnect: my rating / how many others were rated poor at that
  /// moment, ignored until they change.
  bool _meStale = false, _othersStale = false;
  SfuConnectionQuality? _staleMe;
  int _staleOthersPoor = 0, _lastOthersPoor = 0;
  bool _backFromReconnect = false;

  /// True once, right after this phone's call came back from
  /// "Reconnecting…" (then tell the other side).
  bool takeBackFromReconnect() {
    final back = _backFromReconnect;
    _backFromReconnect = false;
    return back;
  }

  /// The other side said its call is back from "Reconnecting…": its current
  /// rating is left over from the outage.
  void othersReconnected() {
    _othersStale = true;
    _staleOthersPoor = _lastOthersPoor;
  }

  CallNetwork update({
    required bool reconnecting,
    required SfuConnectionQuality? me,
    required List<SfuConnectionQuality?> others,
  }) {
    final othersPoor =
        others.where((q) => q == SfuConnectionQuality.poor).length;
    _lastOthersPoor = othersPoor;
    if (reconnecting) {
      _reconnecting = true;
    } else if (_reconnecting) {
      // Back from "Reconnecting…": the current ratings are left over from
      // the outage.
      _reconnecting = false;
      _backFromReconnect = true;
      _meStale = _othersStale = true;
      _staleMe = me;
      _staleOthersPoor = othersPoor;
    }
    if (_meStale && me != _staleMe) _meStale = false;
    // The other person may be missing for a moment right after a reconnect:
    // that is not a new rating.
    if (_othersStale && others.isNotEmpty && othersPoor != _staleOthersPoor) {
      _othersStale = false;
    }
    if (!_meStale && me == SfuConnectionQuality.poor) return CallNetwork.weak;
    if (!_othersStale && othersPoor > 0) return CallNetwork.peerWeak;
    return CallNetwork.good;
  }
}
