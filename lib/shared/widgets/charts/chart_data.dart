import 'package:equatable/equatable.dart';

/// One data point in a [ChartSeries] (Slice 2.2.3).
///
/// **Pure data**: no Flutter imports, no `Color`, no fl_chart types.
/// The widget layer maps `ChartSeries` → fl_chart's `LineChartBarData` /
/// `BarChartGroupData` at the boundary so feature blocs can construct
/// chart data without depending on the chart library.
class ChartPoint extends Equatable {
  const ChartPoint({
    required this.x,
    required this.y,
    this.label,
  });

  /// X-axis position. For time-series this is typically a Unix-epoch
  /// millisecond or a day index; the widget layer formats the label.
  final double x;

  /// Y-axis value.
  final double y;

  /// Optional category / X-axis label override (e.g. "Q1", "Mon").
  /// `null` falls back to the widget's default formatter.
  final String? label;

  static const Object _undefined = Object();

  ChartPoint copyWith({
    double? x,
    double? y,
    Object? label = _undefined,
  }) {
    return ChartPoint(
      x: x ?? this.x,
      y: y ?? this.y,
      label: identical(label, _undefined) ? this.label : label as String?,
    );
  }

  @override
  List<Object?> get props => [x, y, label];
}

/// One named series — a labelled set of points with metadata used by
/// the widget layer to drive colour assignment, legend display, and
/// emphasis ("primary" series might render thicker, etc.).
class ChartSeries extends Equatable {
  const ChartSeries({
    required this.id,
    required this.label,
    this.points = const <ChartPoint>[],
  });

  /// Stable id — used for keying widgets, not user-facing.
  final String id;

  /// Translated display label (used in legends / tooltips).
  final String label;

  /// Newest-last data points. Empty list = no series rendered.
  final List<ChartPoint> points;

  ChartSeries copyWith({
    String? id,
    String? label,
    List<ChartPoint>? points,
  }) {
    return ChartSeries(
      id: id ?? this.id,
      label: label ?? this.label,
      points: points ?? this.points,
    );
  }

  @override
  List<Object?> get props => [id, label, points];
}
