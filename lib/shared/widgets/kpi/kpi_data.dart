/// Direction of change for a KPI relative to the prior period.
enum KpiTrend {
  /// Strictly larger than the prior reference value.
  up,

  /// Strictly smaller than the prior reference value.
  down,

  /// Within [KpiTrend.flatEpsilon] of the prior value — treat as no change.
  flat;

  /// Treat any change smaller than this as `flat`.
  static const double flatEpsilon = 0.0001;

  /// Pure derivation of a trend from a numeric delta.
  static KpiTrend fromDelta(num delta) {
    if (delta.abs() <= flatEpsilon) return KpiTrend.flat;
    return delta > 0 ? KpiTrend.up : KpiTrend.down;
  }
}

/// One KPI tile's worth of data — presentation-format-agnostic so the
/// widget stays a dumb renderer. Plain immutable value type (was
/// `freezed`; the codegen was removed).
class KpiData {
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

  /// Direction marker — drives icon + colour.
  final KpiTrend trend;

  /// Pre-formatted change label (e.g. "+12.4 %", "-3 d"). `null`
  /// suppresses the chip.
  final String? trendDelta;

  /// Newest-last numeric series for the sparkline.
  final List<double> sparkline;

  KpiData copyWith({
    String? label,
    String? value,
    KpiTrend? trend,
    String? trendDelta,
    List<double>? sparkline,
  }) =>
      KpiData(
        label: label ?? this.label,
        value: value ?? this.value,
        trend: trend ?? this.trend,
        trendDelta: trendDelta ?? this.trendDelta,
        sparkline: sparkline ?? this.sparkline,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! KpiData) return false;
    if (other.label != label ||
        other.value != value ||
        other.trend != trend ||
        other.trendDelta != trendDelta ||
        other.sparkline.length != sparkline.length) {
      return false;
    }
    for (var i = 0; i < sparkline.length; i++) {
      if (other.sparkline[i] != sparkline[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        label,
        value,
        trend,
        trendDelta,
        Object.hashAll(sparkline),
      );
}
