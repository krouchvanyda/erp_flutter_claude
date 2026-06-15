import 'package:collection/collection.dart';

/// One data point in a [ChartSeries] (Slice 2.2.3).
///
/// **Pure data**: no Flutter imports, no fl_chart types. Plain immutable
/// class (was `freezed`; the codegen was removed).
class ChartPoint {
  const ChartPoint({
    required this.x,
    required this.y,
    this.label,
  });

  /// X-axis position.
  final double x;

  /// Y-axis value.
  final double y;

  /// Optional category / X-axis label override.
  final String? label;

  ChartPoint copyWith({double? x, double? y, String? label}) => ChartPoint(
        x: x ?? this.x,
        y: y ?? this.y,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChartPoint &&
          other.x == x &&
          other.y == y &&
          other.label == label);

  @override
  int get hashCode => Object.hash(x, y, label);
}

/// One named series — a labelled set of points with metadata.
class ChartSeries {
  const ChartSeries({
    required this.id,
    required this.label,
    this.points = const <ChartPoint>[],
  });

  /// Stable id — used for keying widgets, not user-facing.
  final String id;

  /// Translated display label (used in legends / tooltips).
  final String label;

  /// Newest-last data points.
  final List<ChartPoint> points;

  ChartSeries copyWith({String? id, String? label, List<ChartPoint>? points}) =>
      ChartSeries(
        id: id ?? this.id,
        label: label ?? this.label,
        points: points ?? this.points,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChartSeries &&
          other.id == id &&
          other.label == label &&
          const ListEquality<ChartPoint>().equals(other.points, points));

  @override
  int get hashCode =>
      Object.hash(id, label, const ListEquality<ChartPoint>().hash(points));
}
