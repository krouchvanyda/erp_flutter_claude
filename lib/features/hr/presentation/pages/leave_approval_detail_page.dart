import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/widgets/dynamic_app_bar.dart';
import '../../../../core/widgets/dynamic_status_bar.dart';
import '../../../../features/auth/entities/permission.dart';
import '../../../../shared/widgets/app_background_gradient.dart';
import '../../../../shared/widgets/permission_guard.dart';
import '../../data/repositories/leave_requests_repository.dart';
import '../../entities/leave_request.dart';

/// Slice 7.2.4 — full-context view for a single pending leave request,
/// shown to managers before they approve or reject. Per the design
/// guide §7.9: employee snapshot, request detail grid, reason card,
/// balance preview (now / if-approved / if-rejected), approval timeline,
/// and a sticky action row with confirmation bottom sheets.
class LeaveApprovalDetailPage extends StatefulWidget {
  const LeaveApprovalDetailPage({
    super.key,
    required this.request,
    this.approverId = 'emp-001',
  });

  final LeaveRequest request;
  final String approverId;

  @override
  State<LeaveApprovalDetailPage> createState() =>
      _LeaveApprovalDetailPageState();
}

class _LeaveApprovalDetailPageState extends State<LeaveApprovalDetailPage> {
  late LeaveRequest _request;
  late Future<List<LeaveBalance>> _balancesFuture;
  bool _actionInFlight = false;

  static final _date = DateFormat('EEE, MMM d, yyyy');
  static final _stamp = DateFormat('MMM d, yyyy • HH:mm');

  @override
  void initState() {
    super.initState();
    _request = widget.request;
    _balancesFuture =
        GetIt.I<LeaveBalancesRepository>().getForEmployee(_request.employeeId);
  }

  bool get _canAct =>
      _request.status == LeaveRequestStatus.pending && !_actionInFlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: DynamicAppBar(
        title: 'Leave Request',
        centerTitle: true,
      ),
      body: DynamicStatusBar(
        child: Stack(
          children: [
            const AppBackgroundGradient(),
            FutureBuilder<List<LeaveBalance>>(
              future: _balancesFuture,
              builder: (context, snap) {
                final balances = snap.data ?? const <LeaveBalance>[];
                LeaveBalance? typedBalance;
                for (final b in balances) {
                  if (b.type == _request.type) {
                    typedBalance = b;
                    break;
                  }
                }
                return ListView(
                  padding: EdgeInsets.only(
                    top: context.dynamicAppBarPadding + 16,
                    left: 16,
                    right: 16,
                    bottom: _canAct ? 120 : 32,
                  ),
                  children: [
                    _EmployeeContextCard(
                      request: _request,
                      typedBalance: typedBalance,
                      isLoadingBalance:
                          snap.connectionState == ConnectionState.waiting,
                    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.04, end: 0),
                    const SizedBox(height: 16),
                    _RequestDetailCard(
                      request: _request,
                      dateFormat: _date,
                      stampFormat: _stamp,
                    ).animate().fadeIn(delay: 80.ms, duration: 320.ms).slideY(begin: 0.04, end: 0),
                    const SizedBox(height: 16),
                    if (_request.reason.trim().isNotEmpty) ...[
                      _SectionLabel('Reason'),
                      const SizedBox(height: 8),
                      _ReasonCard(reason: _request.reason)
                          .animate()
                          .fadeIn(delay: 160.ms, duration: 320.ms),
                      const SizedBox(height: 16),
                    ],
                    if (_request.status == LeaveRequestStatus.pending &&
                        typedBalance != null) ...[
                      _SectionLabel('Balance After Decision'),
                      const SizedBox(height: 8),
                      _BalancePreviewCard(
                        request: _request,
                        balance: typedBalance,
                      ).animate().fadeIn(delay: 240.ms, duration: 320.ms),
                      const SizedBox(height: 16),
                    ],
                    if (_request.status != LeaveRequestStatus.pending) ...[
                      _SectionLabel('Decision'),
                      const SizedBox(height: 8),
                      _ApprovalTimelineCard(
                        request: _request,
                        stampFormat: _stamp,
                      ).animate().fadeIn(delay: 240.ms, duration: 320.ms),
                    ],
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
            if (_canAct)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ActionBar(
                  onReject: _onReject,
                  onApprove: _onApprove,
                  primary: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onApprove() async {
    final note = await _showApproveSheet();
    if (note == null) return; // user dismissed
    await _runAction(() async {
      final repo = GetIt.I<LeaveRequestsRepository>();
      final updated = repo.approve(
        request: _request,
        approverId: widget.approverId,
        now: DateTime.now(),
        note: note.isEmpty ? null : note,
      );
      await repo.update(updated);
      if (!mounted) return;
      setState(() => _request = updated);
      _toast('Leave request approved.');
      if (Navigator.canPop(context)) Navigator.pop(context);
    });
  }

  Future<void> _onReject() async {
    final reason = await _showRejectSheet();
    if (reason == null) return;
    if (reason.trim().isEmpty) {
      _toast('A rejection reason is required.');
      return;
    }
    await _runAction(() async {
      final repo = GetIt.I<LeaveRequestsRepository>();
      try {
        final updated = repo.reject(
          request: _request,
          approverId: widget.approverId,
          now: DateTime.now(),
          reason: reason,
        );
        await repo.update(updated);
        if (!mounted) return;
        setState(() => _request = updated);
        _toast('Leave request rejected.');
        if (Navigator.canPop(context)) Navigator.pop(context);
      } on ValidationFailure {
        _toast('A rejection reason is required.');
      } on ConflictFailure catch (f) {
        _toast(f.message ?? 'Cannot reject this request.');
      }
    });
  }

  Future<void> _runAction(Future<void> Function() body) async {
    setState(() => _actionInFlight = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<String?> _showRejectSheet() async {
    final theme = Theme.of(context);
    final ctrl = TextEditingController();
    final maxLen = 240;
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.xl),
        ),
      ),
      builder: (sheetCtx) {
        final viewInsets = MediaQuery.of(sheetCtx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + viewInsets),
          child: StatefulBuilder(
            builder: (sb, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reason for rejection',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Explain briefly so ${_request.employeeName.split(' ').first} understands the decision.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    maxLines: 4,
                    maxLength: maxLen,
                    onChanged: (_) => setSheet(() {}),
                    decoration: InputDecoration(
                      hintText: 'e.g. Team coverage already booked for those dates',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        borderSide: BorderSide(
                          color: theme.colorScheme.error,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: ctrl.text.trim().isEmpty
                              ? null
                              : () => Navigator.pop(sheetCtx, ctrl.text.trim()),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Confirm Rejection'),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<String?> _showApproveSheet() async {
    final theme = Theme.of(context);
    final ctrl = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.xl),
        ),
      ),
      builder: (sheetCtx) {
        final viewInsets = MediaQuery.of(sheetCtx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + viewInsets),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Approve this leave request?',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  children: [
                    Icon(_leaveIcon(_request.type),
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_leaveTypeLabel(_request.type)} • ${_request.days} day${_request.days == 1 ? '' : 's'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${_date.format(_request.fromDate)}  →  ${_date.format(_request.toDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Add a note (optional)',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetCtx, ctrl.text.trim()),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _EmployeeContextCard extends StatelessWidget {
  const _EmployeeContextCard({
    required this.request,
    required this.typedBalance,
    required this.isLoadingBalance,
  });

  final LeaveRequest request;
  final LeaveBalance? typedBalance;
  final bool isLoadingBalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _initials(request.employeeName);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
            theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              initials,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.employeeName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(_leaveIcon(request.type),
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      _leaveTypeLabel(request.type),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isLoadingBalance)
                  SizedBox(
                    height: 12,
                    width: 140,
                    child: LinearProgressIndicator(
                      backgroundColor: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                      color: theme.colorScheme.primary,
                      minHeight: 4,
                    ),
                  )
                else if (typedBalance != null)
                  Text(
                    '${typedBalance!.remainingDays} of ${typedBalance!.totalDays} days remaining',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    'No yearly balance configured',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          _StatusChip(status: request.status),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _RequestDetailCard extends StatelessWidget {
  const _RequestDetailCard({
    required this.request,
    required this.dateFormat,
    required this.stampFormat,
  });

  final LeaveRequest request;
  final DateFormat dateFormat;
  final DateFormat stampFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _InfoCell(
                label: 'From',
                value: dateFormat.format(request.fromDate),
                icon: Icons.calendar_today_rounded,
              ),
              const SizedBox(width: 16),
              _InfoCell(
                label: 'To',
                value: dateFormat.format(request.toDate),
                icon: Icons.event_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timelapse_rounded,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '${request.days} day${request.days == 1 ? '' : 's'} requested',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Submitted ${stampFormat.format(request.requestedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({required this.reason});
  final String reason;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: SelectableText(
        reason,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
      ),
    );
  }
}

class _BalancePreviewCard extends StatelessWidget {
  const _BalancePreviewCard({
    required this.request,
    required this.balance,
  });
  final LeaveRequest request;
  final LeaveBalance balance;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = balance.remainingDays;
    final ifApproved = (remaining - request.days).clamp(0, balance.totalDays);
    final ifRejected = remaining;
    final fillFraction = balance.totalDays == 0
        ? 0.0
        : (balance.usedDays / balance.totalDays).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: fillFraction,
              minHeight: 10,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${balance.usedDays} of ${balance.totalDays} days used this year',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BalanceCell(
                  label: 'If Approved',
                  value: '$ifApproved days',
                  color: Colors.green.shade700,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BalanceCell(
                  label: 'If Rejected',
                  value: '$ifRejected days',
                  color: theme.colorScheme.onSurfaceVariant,
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceCell extends StatelessWidget {
  const _BalanceCell({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalTimelineCard extends StatelessWidget {
  const _ApprovalTimelineCard({
    required this.request,
    required this.stampFormat,
  });
  final LeaveRequest request;
  final DateFormat stampFormat;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isApproved = request.status == LeaveRequestStatus.approved;
    final isRejected = request.status == LeaveRequestStatus.rejected;
    final isCancelled = request.status == LeaveRequestStatus.cancelled;
    final color = isApproved
        ? Colors.green
        : isRejected
            ? theme.colorScheme.error
            : theme.colorScheme.outline;
    final label = isApproved
        ? 'Approved'
        : isRejected
            ? 'Rejected'
            : isCancelled
                ? 'Cancelled by employee'
                : 'Pending';
    final icon = isApproved
        ? Icons.check_circle_rounded
        : isRejected
            ? Icons.cancel_rounded
            : isCancelled
                ? Icons.remove_circle_rounded
                : Icons.hourglass_top_rounded;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (request.actionedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    stampFormat.format(request.actionedAt!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if ((request.decisionNote ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    request.decisionNote!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.onReject,
    required this.onApprove,
    required this.primary,
  });
  final VoidCallback onReject;
  final VoidCallback onApprove;
  final Color primary;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                      color: theme.colorScheme.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Approve'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 1.0, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final LeaveRequestStatus status;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (status) {
      LeaveRequestStatus.pending => ('Pending', Colors.orange),
      LeaveRequestStatus.approved => ('Approved', Colors.green),
      LeaveRequestStatus.rejected => ('Rejected', theme.colorScheme.error),
      LeaveRequestStatus.cancelled => ('Cancelled', theme.colorScheme.outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  helpers
// ─────────────────────────────────────────────────────────────────────────────

String _leaveTypeLabel(LeaveType t) {
  switch (t) {
    case LeaveType.annual:
      return 'Annual leave';
    case LeaveType.sick:
      return 'Sick leave';
    case LeaveType.personal:
      return 'Personal leave';
    case LeaveType.unpaid:
      return 'Unpaid leave';
    case LeaveType.maternity:
      return 'Maternity leave';
  }
}

IconData _leaveIcon(LeaveType t) {
  switch (t) {
    case LeaveType.annual:
      return Icons.beach_access_rounded;
    case LeaveType.sick:
      return Icons.medical_information_rounded;
    case LeaveType.personal:
      return Icons.person_rounded;
    case LeaveType.unpaid:
      return Icons.money_off_rounded;
    case LeaveType.maternity:
      return Icons.child_friendly_rounded;
  }
}
