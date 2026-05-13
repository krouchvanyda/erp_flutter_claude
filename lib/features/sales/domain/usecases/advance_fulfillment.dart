import '../../../../core/error/failure.dart';
import '../entities/sales_order.dart';

/// Pure transition rules for the fulfillment state machine
/// (Slice 6.2.3).
///
/// **Allowed transitions**:
/// ```
/// pending  → packing | cancelled
/// packing  → shipped | cancelled
/// shipped  → delivered
/// delivered → (terminal)
/// cancelled → (terminal)
/// ```
///
/// Throws [`ConflictFailure`] for an illegal hop; throws
/// [`ValidationFailure`] when `next == shipped` is requested without
/// a `trackingReference` (the warehouse staff needs the reference to
/// hand to the courier).
SalesOrder advanceFulfillment(
  SalesOrder current, {
  required SalesOrderStatus to,
  required DateTime now,
  String? trackingReference,
}) {
  if (!_isLegal(current.status, to)) {
    throw Failure.conflict(
      message:
          'Cannot move ${current.status.name} → ${to.name}',
    );
  }
  if (to == SalesOrderStatus.shipped &&
      (trackingReference == null || trackingReference.trim().isEmpty)) {
    throw const Failure.validation(
      fieldErrors: {
        'trackingReference': ['required'],
      },
    );
  }
  return current.copyWith(
    status: to,
    trackingReference: trackingReference?.trim() ?? current.trackingReference,
    shippedAt: to == SalesOrderStatus.shipped ? now : current.shippedAt,
    deliveredAt:
        to == SalesOrderStatus.delivered ? now : current.deliveredAt,
  );
}

bool _isLegal(SalesOrderStatus from, SalesOrderStatus to) {
  switch (from) {
    case SalesOrderStatus.pending:
      return to == SalesOrderStatus.packing ||
          to == SalesOrderStatus.cancelled;
    case SalesOrderStatus.packing:
      return to == SalesOrderStatus.shipped ||
          to == SalesOrderStatus.cancelled;
    case SalesOrderStatus.shipped:
      return to == SalesOrderStatus.delivered;
    case SalesOrderStatus.delivered:
    case SalesOrderStatus.cancelled:
      return false;
  }
}
