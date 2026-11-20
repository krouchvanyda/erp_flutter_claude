import 'dart:convert';

import 'package:erp_mobile/core/realtime/realtime_event.dart';
import 'package:erp_mobile/core/realtime/realtime_service.dart';
import 'package:erp_mobile/core/realtime/stomp_connection.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake STOMP connection: remembers subscriptions, lets the test push frames.
class _FakeConnection implements StompConnection {
  _FakeConnection(this.token, this.onLost);

  final String token;
  final void Function() onLost;
  final Map<String, void Function(String?)> subs = {};
  bool closed = false;

  void push(String destination, String event, Object? payload) =>
      subs[destination]?.call(jsonEncode({'event': event, 'payload': payload}));

  @override
  void Function() subscribe(String d, void Function(String?) onMessage) {
    subs[d] = onMessage;
    return () => subs.remove(d);
  }

  @override
  void close() => closed = true;
}

void main() {
  late List<_FakeConnection> connections;
  late bool serverUp;
  late int tokenCalls;
  late RealtimeService realtime;

  setUp(() {
    connections = [];
    serverUp = true;
    tokenCalls = 0;
    realtime = RealtimeService(
      url: 'ws://test/ws',
      accessToken: () async => 'token-${++tokenCalls}',
      backoff: (_) => const Duration(milliseconds: 10),
      connector: ({required url, required token, required onLost}) async {
        if (!serverUp) throw StateError('down');
        final c = _FakeConnection(token, onLost);
        connections.add(c);
        return c;
      },
    );
  });

  tearDown(() => realtime.stop());

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  test('start → connects with a token → connected', () async {
    realtime.start();
    await settle();

    expect(realtime.status.value, RealtimeStatus.connected);
    expect(connections.single.token, 'token-1');
  });

  test('subscribe → typed events; unknown frames are ignored', () async {
    final got = <RealtimeEvent>[];
    final sub = realtime.subscribe('/user/queue/inbox').listen(got.add);
    realtime.start(); // subscribing BEFORE connect is fine
    await settle();

    connections.single
      ..push('/user/queue/inbox', 'message.send', {'id': 1})
      ..subs['/user/queue/inbox']!('not json');
    await settle();

    expect(got.single.event, 'message.send');
    expect(got.single.payloadMap, {'id': 1});
    await sub.cancel();
    expect(connections.single.subs, isEmpty); // last listener → unsubscribed
  });

  test(
    'drop → retry with a FRESH token → re-subscribed → reconnected',
    () async {
      final got = <RealtimeEvent>[];
      realtime.subscribe('/topic/conversations/5').listen(got.add);
      var reconnects = 0;
      realtime.reconnected.listen((_) => reconnects++);
      realtime.start();
      await settle();

      connections.first.onLost(); // the socket died
      expect(realtime.status.value, RealtimeStatus.connecting);
      await settle();

      expect(connections, hasLength(2));
      expect(connections.last.token, 'token-2');
      expect(connections.last.subs.keys, ['/topic/conversations/5']);
      expect(reconnects, 1); // catch-up signal (not on the FIRST connect)
      connections.last.push('/topic/conversations/5', 'message.read', {});
      await settle();
      expect(got, hasLength(1));
    },
  );

  test('server down → keeps trying with backoff until it is back', () async {
    serverUp = false;
    realtime.start();
    await settle();
    expect(realtime.status.value, RealtimeStatus.connecting);
    expect(tokenCalls, greaterThan(1)); // tried again (fresh token each time)

    serverUp = true;
    await settle();
    expect(realtime.status.value, RealtimeStatus.connected);
  });

  test('stop (logout) → closed, stopped, no more tries', () async {
    realtime.start();
    await settle();
    realtime.stop();
    await settle();

    expect(connections.single.closed, isTrue);
    expect(realtime.status.value, RealtimeStatus.stopped);
    expect(connections, hasLength(1));
  });

  test('reconnectNow skips the backoff wait', () async {
    realtime = RealtimeService(
      url: 'ws://test/ws',
      accessToken: () async => 't',
      backoff: (_) => const Duration(hours: 1), // would wait forever
      connector: ({required url, required token, required onLost}) async {
        if (!serverUp) throw StateError('down');
        final c = _FakeConnection(token, onLost);
        connections.add(c);
        return c;
      },
    );
    serverUp = false;
    realtime.start();
    await settle();
    serverUp = true;

    realtime.reconnectNow(); // app resumed / network back
    await settle();

    expect(realtime.status.value, RealtimeStatus.connected);
  });
}
