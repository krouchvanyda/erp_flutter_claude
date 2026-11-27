import 'dart:async';
import 'dart:convert';

import 'package:erp_mobile/core/realtime/realtime_event.dart';
import 'package:erp_mobile/core/realtime/ws_connection.dart';
import 'package:flutter_test/flutter_test.dart';

/// R5: [WsLine] — our JSON letters, with a StreamController as the server.
void main() {
  late StreamController<dynamic> server; // what the server sends
  late List<Map<String, dynamic>> sent; // what the app wrote
  late bool closed;
  late int lost;

  setUp(() {
    server = StreamController<dynamic>();
    sent = [];
    closed = false;
    lost = 0;
  });

  tearDown(() => server.close());

  Future<WsLine> open({
    Duration pingEvery = const Duration(seconds: 10),
    Duration deadAfter = const Duration(seconds: 25),
    Duration readyTimeout = const Duration(seconds: 10),
  }) => WsLine.open(
    incoming: server.stream,
    sendRaw: (t) => sent.add(jsonDecode(t) as Map<String, dynamic>),
    closeRaw: () async => closed = true,
    token: 'tok',
    onLost: () => lost++,
    pingEvery: pingEvery,
    deadAfter: deadAfter,
    readyTimeout: readyTimeout,
  );

  void say(Map<String, Object?> letter) => server.add(jsonEncode(letter));

  test('sends auth first; ready → connected', () async {
    final opening = open();
    await Future<void>.delayed(Duration.zero);
    expect(sent.single, {'type': 'auth', 'token': 'tok'});

    say({'type': 'ready'});
    final line = await opening;
    expect(line, isA<WsLine>());
    expect(lost, 0);
  });

  test(
    'error before ready (bad token) → the Future fails, never "lost"',
    () async {
      final opening = open();
      say({'type': 'error', 'message': 'Invalid or expired token'});

      await expectLater(opening, throwsA(isA<StateError>()));
      expect(closed, isTrue);
      expect(lost, 0);
    },
  );

  test('closed before ready → fails', () async {
    final opening = open();
    await server.close();

    await expectLater(opening, throwsA(isA<StateError>()));
  });

  test('no ready in time → fails', () async {
    await expectLater(
      open(readyTimeout: const Duration(milliseconds: 30)),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'subscribe → letters for THAT address reach the listener, parsable as RealtimeEvent',
    () async {
      final opening = open();
      say({'type': 'ready'});
      final line = await opening;

      final got = <RealtimeEvent>[];
      line.subscribe('/topic/conversations/1', (body) {
        final e = RealtimeEvent.tryParse(body);
        if (e != null) got.add(e);
      });
      expect(sent.last, {
        'type': 'subscribe',
        'destination': '/topic/conversations/1',
      });

      say({
        'type': 'message',
        'destination': '/topic/conversations/1',
        'event': 'message.send',
        'payload': {'id': 264, 'body': 'Hello'},
      });
      say({
        'type': 'message',
        'destination': '/topic/conversations/2',
        'event': 'x',
        'payload': {},
      });
      await Future<void>.delayed(Duration.zero);

      expect(got.single.event, 'message.send');
      expect(got.single.payloadMap, {'id': 264, 'body': 'Hello'});
    },
  );

  test('stop → unsubscribe letter, no more letters', () async {
    final opening = open();
    say({'type': 'ready'});
    final line = await opening;
    var count = 0;
    final stop = line.subscribe('/user/queue/inbox', (_) => count++);

    stop();
    expect(sent.last, {
      'type': 'unsubscribe',
      'destination': '/user/queue/inbox',
    });
    say({
      'type': 'message',
      'destination': '/user/queue/inbox',
      'event': 'e',
      'payload': {},
    });
    await Future<void>.delayed(Duration.zero);
    expect(count, 0);
  });

  test('send → a "send" letter with the body as JSON (typing)', () async {
    final opening = open();
    say({'type': 'ready'});
    final line = await opening;

    line.send('/app/conversations/5/typing', jsonEncode({'typing': true}));

    expect(sent.last, {
      'type': 'send',
      'destination': '/app/conversations/5/typing',
      'body': {'typing': true},
    });
  });

  test('pings while connected; the server dropping → lost ONCE', () async {
    final opening = open(pingEvery: const Duration(milliseconds: 20));
    say({'type': 'ready'});
    await opening;
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(sent.where((l) => l['type'] == 'ping'), isNotEmpty);

    await server.close(); // the socket ended
    await Future<void>.delayed(Duration.zero);
    expect(lost, 1);
  });

  test('server silent too long → lost (a dead line)', () async {
    final opening = open(deadAfter: const Duration(milliseconds: 40));
    say({'type': 'ready'});
    await opening;

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(lost, 1);
    expect(closed, isTrue);
  });

  test('pongs keep it alive', () async {
    final opening = open(deadAfter: const Duration(milliseconds: 40));
    say({'type': 'ready'});
    await opening;

    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      say({'type': 'pong'});
    }
    expect(lost, 0);
  });

  test(
    'close() on purpose → never reported as lost, no more letters',
    () async {
      final opening = open(pingEvery: const Duration(milliseconds: 10));
      say({'type': 'ready'});
      final line = await opening;

      line.close();
      final before = sent.length;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(closed, isTrue);
      expect(lost, 0);
      expect(sent.length, before); // no pings after close
    },
  );
}
