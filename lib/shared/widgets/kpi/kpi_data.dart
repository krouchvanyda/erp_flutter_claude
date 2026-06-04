import 'package:equatable/equatable.dart';

/// Direction of change for a KPI relative to the prior period.
///
/// Kept as a tiny enum (not `+/0/-` integers) so the renderer can map
/// directly to colour and icon without branching on numeric thresholds.
enum KpiTrend {
  /// Strictly larger than the prior reference value.
  up,

  /// Strictly smaller than the prior reference value.
  down,

  /// Within [KpiTrend.flatEpsilon] of the prior value — treat as no change.
  flat;

  /// Treat any change smaller than this as `flat`. Avoids "0.001 % up"
  /// jitter dominating the chip when the underlying number is essentially
  /// stable. Tunable in one place.
  static const double flatEpsilon = 0.0001;

  /// Pure derivation of a trend from a numeric delta (current − prior,
  /// or `currentRatio − 1`, whichever is more natural at the call site).
  ///
  /// Lives here, not on the widget, so the rule set is unit-testable
  /// without Flutter and identical wherever it's applied.
  static KpiTrend fromDelta(num delta) {
    if (delta.abs() <= flatEpsilon) return KpiTrend.flat;
    return delta > 0 ? KpiTrend.up : KpiTrend.down;
  }
}

/// One KPI tile's worth of data — kept presentation-format-agnostic
/// (the caller pre-formats [value] / [trendDelta] with the right
/// currency, units, locale) so the widget stays a dumb renderer.
///
/// **Why explicit `trend` AND `trendDelta`**: trend drives the icon /
/// colour (an enum is the cleanest input to a `switch`), while
/// `trendDelta` is the human-readable label sat beside it. Splitting
/// them keeps the widget free of formatting code.
class KpiData extends Equatable {
  const KpiData({
    required this.label,
    required this.value,
    required this.trend,
    this.trendDelta,
    this.sparkline = const <double>[],
  });

  /// Short label (e.g. "Revenue", "AR aging > 30d").
  final String label;

  /// Pre-formatted primary value (e.g. "$12,400", "82 %").
  final String value;

  /// Direction marker — drives icon + colour. Use [KpiTrend.fromDelta]
  /// at the data source if you only have a numeric change.
  final KpiTrend trend;

  /// Pre-formatted change label (e.g. "+12.4 %", "-3 d"). `null`
  /// suppresses the chip; use this for KPIs without comparison data.
  final String? trendDelta;

  /// Newest-last numeric series for the sparkline. Empty list = no
  /// sparkline drawn. Single point is allowed and rendered as a dot.
  final List<double> sparkline;

  static const Object _undefined = Object();

  KpiData copyWith({
    String? label,
    String? value,
    KpiTrend? trend,
    Object? trendDelta = _undefined,
    List<double>? sparkline,
  }) {
    return KpiData(
      label: label ?? this.label,
      value: value ?? this.value,
      trend: trend ?? this.trend,
      trendDelta: identical(trendDelta, _undefined)
          ? this.trendDelta
          : trendDelta as String?,
      sparkline: sparkline ?? this.sparkline,
    );
  }

  @override
  List<Object?> get props => [label, value, trend, trendDelta, sparkline];
}
