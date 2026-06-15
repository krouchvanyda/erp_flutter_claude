import 'dart:convert';

import 'package:collection/collection.dart';

/// Server-pushed message envelope for the dashboard real-time stream
/// (Slice 2.2.4).
///
/// Plain Dart 3 `sealed class` (was `freezed`; the codegen was removed).
/// The discriminator-keyed [fromWire] is hand-rolled; factory redirects
/// preserve `RealtimeMessage.kpiUpdate(...)` etc.
sealed class RealtimeMessage {
  const RealtimeMessage();

  const factory RealtimeMessage.kpiUpdate({
    required String id,
    required String value,
    required String trend,
    String? trendDelta,
  }) = RealtimeKpiUpdate;

  const factory RealtimeMessage.chartUpdate({
    required String id,
    required List<RealtimeChartSeriesPayload> series,
  }) = RealtimeChartUpdate;

  const factory RealtimeMessage.pong() = RealtimePong;

  const factory RealtimeMessage.unknown({
    required String raw,
    String? reason,
  }) = RealtimeUnknown;

  // ── JSON ────────────────────────────────────────────────────────
  /// Decode a server frame. Never throws — unrecognised / malformed
  /// payloads come back as [RealtimeMessage.unknown].
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
  bool operator ==(Object other) =>
      other is RealtimeKpiUpdate &&
      other.id == id &&
      other.value == value &&
      other.trend == trend &&
      other.trendDelta == trendDelta;
  @override
  int get hashCode => Object.hash(id, value, trend, trendDelta);
}

class RealtimeChartUpdate extends RealtimeMessage {
  const RealtimeChartUpdate({required this.id, required this.series});
  final String id;
  final List<RealtimeChartSeriesPayload> series;

  @override
  bool operator ==(Object other) =>
      other is RealtimeChartUpdate &&
      other.id == id &&
      const ListEquality<RealtimeChartSeriesPayload>()
          .equals(other.series, series);
  @override
  int get hashCode => Object.hash(
        id,
        const ListEquality<RealtimeChartSeriesPayload>().hash(series),
      );
}

class RealtimePong extends RealtimeMessage {
  const RealtimePong();
  @override
  bool operator ==(Object other) => other is RealtimePong;
  @override
  int get hashCode => (RealtimePong).hashCode;
}

class RealtimeUnknown extends RealtimeMessage {
  const RealtimeUnknown({required this.raw, this.reason});
  final String raw;
  final String? reason;
  @override
  bool operator ==(Object other) =>
      other is RealtimeUnknown && other.raw == raw && other.reason == reason;
  @override
  int get hashCode => Object.hash(raw, reason);
}

/// One series in a [RealtimeChartUpdate] payload — parallel x / y arrays
/// so large updates stay compact on the wire. Plain class with a
/// hand-written `fromJson` (was freezed + json_serializable).
class RealtimeChartSeriesPayload {
  const RealtimeChartSeriesPayload({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
  });

  factory RealtimeChartSeriesPayload.fromJson(Map<String, dynamic> json) =>
      RealtimeChartSeriesPayload(
        id: json['id'] as String,
        label: json['label'] as String,
        x: (json['x'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
        y: (json['y'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
      );

  final String id;
  final String label;
  final List<double> x;
  final List<double> y;

  @override
  bool operator ==(Object other) =>
      other is RealtimeChartSeriesPayload &&
      other.id == id &&
      other.label == label &&
      const ListEquality<double>().equals(other.x, x) &&
      const ListEquality<double>().equals(other.y, y);
  @override
  int get hashCode => Object.hash(
        id,
        label,
        const ListEquality<double>().hash(x),
        const ListEquality<double>().hash(y),
      );
}
