import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/leave_request.dart';
import '../../domain/repositories/leave_requests_repository.dart';
import '../../domain/usecases/compute_leave_balance.dart';

/// Slice 7.2.2 — leave balance widget.
///
/// Layered: pulls baselines from [LeaveBalancesRepository], requests
/// from [LeaveRequestsRepository], and recombines via
/// [computeEffectiveBalances] so newly-approved requests in the demo
/// session immediately decrement the displayed remainder.
class LeaveBalancePage extends StatelessWidget {
  const LeaveBalancePage({this.employeeId = 'emp-001'});
  final String employeeId;

  @override
  Widget build(BuildContext context) {
    final balanceRepo = GetIt.I<LeaveBalancesRepository>();
    final reqRepo = GetIt.I<LeaveRequestsRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Balance')),
      body: StreamBuilder<List<LeaveBalance>>(
        stream: balanceRepo.watchForEmployee(employeeId),
        builder: (context, balanceSnap) {
          if (balanceSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final baselines = balanceSnap.data ?? const <LeaveBalance>[];
          if (baselines.isEmpty) {
            return const Center(
              child: Text('No leave entitlements on file.'),
            );
          }
          return StreamBuilder<List<LeaveRequest>>(
            stream: reqRepo.watchAll(),
            builder: (context, reqSnap) {
              final requests = reqSnap.data ?? const <LeaveRequest>[];
              final effective = computeEffectiveBalances(
                baselines: baselines,
                requests: requests,
                employeeId: employeeId,
              );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: effective
                    .map((b) => _BalanceCard(balance: b))
                    .toList(),
              );
            },
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final LeaveBalance balance;

  @override
  Widget build(BuildContext context) {
    final remaining = balance.remainingDays;
    final pctUsed = balance.totalDays == 0
        ? 0.0
        : (balance.usedDays / balance.totalDays).clamp(0.0, 1.0);
    final color = remaining == 0
        ? Colors.red.shade400
        : remaining <= 2
            ? Colors.orange.shade400
            : Colors.green.shade400;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    balance.type.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$remaining / ${balance.totalDays} days',
                  style: TextStyle(color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pctUsed,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${balance.usedDays} used',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
