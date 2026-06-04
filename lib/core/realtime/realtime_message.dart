import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Server-pushed message envelope for the dashboard real-time stream
/// (Slice 2.2.4).
///
/// Sealed union — adding a new push kind is a new subclass + a matching
/// JSON discriminator in [fromWire]. The discriminator-keyed `fromWire`
/// is hand-rolled because our wire format (`{"kind": "kpi.update", ...}`)
/// doesn't fit an auto-generated union deserialiser without ceremony.
///
/// **Pure data**: no Flutter, no dio, no fl_chart. Feature blocs fan
/// out incoming messages into their own state without depending on the
/// realtime infrastructure.
sealed class RealtimeMessage extends Equatable {
  const RealtimeMessage();

  /// Updated KPI tile values. The widget layer maps `(id, value, ...)`
  /// onto the dashboard layout via the slot's `id`.
  const factory RealtimeMessage.kpiUpdate({
    required String id,
    required String value,
    required String trend,
    String? trendDelta,
  }) = RealtimeKpiUpdate;

  /// Replacement series payload for a chart slot — the entire newest
  /// snapshot (no incremental deltas yet; that's a later slice).
  const factory RealtimeMessage.chartUpdate({
    required String id,
    required List<RealtimeChartSeriesPayload> series,
  }) = RealtimeChartUpdate;

  /// Heartbeat ack. The service swallows these — they only exist so
  /// the connection can prove it's alive without producing user-visible
  /// state churn.
  const factory RealtimeMessage.pong() = RealtimePong;

  /// Anything we couldn't decode — surfaced (not silently dropped) so
  /// the service can log / count it. Carries the raw payload for
  /// post-mortem.
  const factory RealtimeMessage.unknown({
    required String raw,
    String? reason,
  }) = RealtimeUnknown;

  // ── JSON ────────────────────────────────────────────────────────
  /// Decode a server frame. Never throws — unrecognised / malformed
  /// payloads come back as [RealtimeMessage.unknown] so the caller can
  /// log without a crash loop on a bad server build.
  static RealtimeMessage fromWire(String raw) {
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (e) {
      return RealtimeMessage.unknown(raw: raw, reason: 'invalid JSON: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      return RealtimeMessage.unknown(
        raw: raw,
        reason: 'top level is not an object',
      );
    }
    final kind = decoded['kind'];
    if (kind is! String) {
      return RealtimeMessage.unknown(raw: raw, reason: 'missing kind');
    }
    try {
      return switch (kind) {
        'kpi.update' => RealtimeMessage.kpiUpdate(
            id: decoded['id'] as String,
            value: decoded['value'] as String,
            trend: decoded['trend'] as String,
            trendDelta: decoded['trendDelta'] as String?,
          ),
        'chart.update' => RealtimeMessage.chartUpdate(
            id: decoded['id'] as String,
            series: [
              for (final s in decoded['series'] as List<dynamic>)
                RealtimeChartSeriesPayload.fromJson(
                  s as Map<String, dynamic>,
                ),
            ],
          ),
        'pong' => const RealtimeMessage.pong(),
        _ => RealtimeMessage.unknown(raw: raw, reason: 'unknown kind: $kind'),
      };
    } catch (e) {
      return RealtimeMessage.unknown(raw: raw, reason: 'decode error: $e');
    }
  }
}

/// Updated KPI tile values.
class RealtimeKpiUpdate extends RealtimeMessage {
  const RealtimeKpiUpdate({
    required this.id,
    required this.value,
    required this.trend,
    this.trendDelta,
  });

  final String id;
  final String value;
  final String trend;
  final String? trendDelta;

  @override
  List<Object?> get props => [id, value, trend, trendDelta];
}

/// Replacement series payload for a chart slot.
class RealtimeChartUpdate extends RealtimeMessage {
  const RealtimeChartUpdate({
    required this.id,
    required this.series,
  });

  final String id;
  final List<RealtimeChartSeriesPayload> series;

  @override
  List<Object?> get props => [id, series];
}

/// Heartbeat ack.
class RealtimePong extends RealtimeMessage {
  const RealtimePong();

  @override
  List<Object?> get props => const [];
}

/// Undecodable frame, surfaced for logging.
class RealtimeUnknown extends RealtimeMessage {
  const RealtimeUnknown({
    required this.raw,
    this.reason,
  });

  final String raw;
  final String? reason;

  @override
  List<Object?> get props => [raw, reason];
}

/// One series in a [RealtimeChartUpdate] payload — kept structural
/// (parallel arrays for x / y) so 100-point updates stay compact on
/// the wire.
class RealtimeChartSeriesPayload extends Equatable {
  const RealtimeChartSeriesPayload({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
  });

  factory RealtimeChartSeriesPayload.fromJson(Map<String, dynamic> json) {
    return RealtimeChartSeriesPayload(
      id: json['id'] as String,
      label: json['label'] as String,
      x: (json['x'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      y: (json['y'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
    );
  }

  final String id;
  final String label;
  final List<double> x;
  final List<double> y;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        'x': x,
        'y': y,
      };

  @override
  List<Object?> get props => [id, label, x, y];
}
