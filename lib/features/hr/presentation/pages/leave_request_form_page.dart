import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/leave_request.dart';
import '../../domain/repositories/leave_requests_repository.dart';
import '../../domain/usecases/submit_leave_request.dart';

/// Slice 7.2.1 — leave request form with calendar pickers.
///
/// **Submit path**: validate via [validateLeaveRequest] (pure-Dart) →
/// hand off to the repo. Field errors come back as
/// [`ValidationFailure.fieldErrors`] so we can attach them per-input
/// rather than dumping a single banner.
class LeaveRequestFormPage extends StatefulWidget {
  const LeaveRequestFormPage({
    this.employeeId = 'emp-001',
    this.employeeName = 'Demo Approver',
  });

  final String employeeId;
  final String employeeName;

  @override
  State<LeaveRequestFormPage> createState() => _LeaveRequestFormPageState();
}

class _LeaveRequestFormPageState extends State<LeaveRequestFormPage> {
  LeaveType _type = LeaveType.annual;
  DateTime? _from;
  DateTime? _to;
  final _reasonCtrl = TextEditingController();
  bool _isSubmitting = false;
  Map<String, List<String>> _fieldErrors = const {};
  String? _topError;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_from ?? DateTime.now())
        : (_to ?? _from ?? DateTime.now());
    final first = isFrom ? DateTime.now() : (_from ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: first.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
          if (_to != null && _to!.isBefore(picked)) _to = picked;
        } else {
          _to = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _topError = null;
      _fieldErrors = const {};
    });
    try {
      final draft = validateLeaveRequest(
        employeeId: widget.employeeId,
        employeeName: widget.employeeName,
        type: _type,
        fromDate: _from ?? DateTime.fromMillisecondsSinceEpoch(0),
        toDate: _to ?? DateTime.fromMillisecondsSinceEpoch(0),
        reason: _reasonCtrl.text,
        now: DateTime.now(),
      );
      await GetIt.I<LeaveRequestsRepository>().create(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request submitted.')),
      );
      Navigator.of(context).pop();
    } on ValidationFailure catch (f) {
      setState(() => _fieldErrors = f.fieldErrors);
    } catch (e) {
      setState(() => _topError = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _errFor(String key) {
    final list = _fieldErrors[key];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  @override
  Widget build(BuildContext context) {
    String fmt(DateTime? d) =>
        d == null ? 'Select date' : d.toIso8601String().split('T').first;
    return Scaffold(
      appBar: AppBar(title: const Text('Request Leave')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<LeaveType>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Leave type',
              border: OutlineInputBorder(),
            ),
            items: LeaveType.values
                .map((t) =>
                    DropdownMenuItem(value: t, child: Text(t.name)))
                .toList(),
            onChanged: (v) =>
                setState(() => _type = v ?? LeaveType.annual),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'From',
              border: const OutlineInputBorder(),
              errorText: _errFor('fromDate'),
            ),
            child: InkWell(
              onTap: () => _pickDate(isFrom: true),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(fmt(_from)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'To',
              border: const OutlineInputBorder(),
              errorText: _errFor('toDate'),
            ),
            child: InkWell(
              onTap: () => _pickDate(isFrom: false),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(fmt(_to)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reason',
              border: const OutlineInputBorder(),
              errorText: _errFor('reason'),
            ),
          ),
          if (_topError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _topError!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
}
