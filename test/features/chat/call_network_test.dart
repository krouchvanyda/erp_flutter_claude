import 'package:erp_mobile/features/chat/repositories/call_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart'
    show SfuConnectionQuality;

/// Scenario 8 — ported from flutter-chat
/// `test/features/call/repository/stream_call_service_test.dart`.
void main() {
  const poor = SfuConnectionQuality.poor, good = SfuConnectionQuality.good;

  test('Stream gives up reconnecting after 30 s', () {
    expect(callReconnectTimeout, const Duration(seconds: 30));
  });

  group('network note after a reconnect', () {
    test('normal: my poor rating → weak; theirs → peer weak', () {
      final r = NetworkRatings();
      expect(r.update(reconnecting: false, me: poor, others: [good]),
          CallNetwork.weak);
      expect(r.update(reconnecting: false, me: good, others: [poor]),
          CallNetwork.peerWeak);
      expect(r.update(reconnecting: false, me: good, others: [good]),
          CallNetwork.good);
    });

    test('back from "Reconnecting…": the old poor rating is ignored at once',
        () {
      final r = NetworkRatings();
      r.update(reconnecting: false, me: poor, others: [good]);
      r.update(reconnecting: true, me: poor, others: [good]);
      expect(r.update(reconnecting: false, me: poor, others: [good]),
          CallNetwork.good);
      expect(r.update(reconnecting: false, me: poor, others: []),
          CallNetwork.good,
          reason: 'other side missing a moment');
    });

    test('a NEW rating after the reconnect counts again', () {
      final r = NetworkRatings();
      r.update(reconnecting: true, me: poor, others: [good]);
      r.update(reconnecting: false, me: poor, others: [good]);
      expect(r.update(reconnecting: false, me: good, others: [good]),
          CallNetwork.good);
      expect(r.update(reconnecting: false, me: poor, others: [good]),
          CallNetwork.weak);
    });

    test('back from "Reconnecting…" → tell the other side, once', () {
      final r = NetworkRatings();
      r.update(reconnecting: true, me: poor, others: [good]);
      expect(r.takeBackFromReconnect(), isFalse, reason: 'still reconnecting');
      r.update(reconnecting: false, me: poor, others: [good]);
      expect(r.takeBackFromReconnect(), isTrue);
      expect(r.takeBackFromReconnect(), isFalse);
    });

    test('the other side says "reconnected" → their old poor rating clears',
        () {
      final r = NetworkRatings();
      expect(r.update(reconnecting: false, me: good, others: [poor]),
          CallNetwork.peerWeak);
      r.othersReconnected();
      expect(r.update(reconnecting: false, me: good, others: [poor]),
          CallNetwork.good);
      r.update(reconnecting: false, me: good, others: [good]); // new rating
      expect(r.update(reconnecting: false, me: good, others: [poor]),
          CallNetwork.peerWeak);
    });

    test("the other side's old poor rating is ignored too, until it changes",
        () {
      final r = NetworkRatings();
      r.update(reconnecting: true, me: good, others: [poor]);
      expect(r.update(reconnecting: false, me: good, others: [poor]),
          CallNetwork.good);
      r.update(reconnecting: false, me: good, others: [good]);
      expect(r.update(reconnecting: false, me: good, others: [poor]),
          CallNetwork.peerWeak);
    });
  });
}
