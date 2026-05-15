import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/projects_repository.dart';
import '../../domain/repositories/timesheets_repository.dart';
import '../../domain/usecases/submit_timesheet.dart';

/// Slice 8.2.1 — daily timesheet entry form.
class TimesheetFormPage extends StatefulWidget {
  const TimesheetFormPage({
    this.employeeId = 'emp-001',
    this.employeeName = 'Demo Approver',
  });

  final String employeeId;
  final String employeeName;

  @override
  State<TimesheetFormPage> createState() => _TimesheetFormPageState();
}

class _TimesheetFormPageState extends State<TimesheetFormPage> {
  Project? _project;
  DateTime? _date;
  final _hoursCtrl = TextEditingController(text: '8.0');
  final _descCtrl = TextEditingController();
  bool _submitImmediately = false;
  bool _isSubmitting = false;
  Map<String, List<String>> _fieldErrors = const {};
  String? _topError;

  late Future<List<Project>> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _projectsFuture = GetIt.I<ProjectsRepository>().getAll();
    _date = DateTime.now();
  }

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String? _errFor(String key) {
    final list = _fieldErrors[key];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _topError = null;
      _fieldErrors = const {};
    });
    try {
      final hours = num.tryParse(_hoursCtrl.text.trim()) ?? -1;
      final draft = validateTimesheetEntry(
        employeeId: widget.employeeId,
        employeeName: widget.employeeName,
        projectId: _project?.id ?? '',
        projectName: _project?.name ?? '',
        date: _date ?? DateTime.fromMillisecondsSinceEpoch(0),
        hours: hours,
        description: _descCtrl.text,
        now: DateTime.now(),
      );
      final stamped =
          _submitImmediately ? submitTimesheetEntry(draft) : draft;
      await GetIt.I<TimesheetsRepository>().create(stamped);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _submitImmediately
                ? 'Timesheet submitted for approval.'
                : 'Timesheet draft saved.',
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Time')),
      body: FutureBuilder<List<Project>>(
        future: _projectsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final projects = snap.data ?? const <Project>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<Project>(
                initialValue: _project,
                decoration: InputDecoration(
                  labelText: 'Project',
                  border: const OutlineInputBorder(),
                  errorText: _errFor('projectId'),
                ),
                items: projects
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text('${p.code} — ${p.name}'),
                        ))
                    .toList(),
                onChanged: (p) => setState(() => _project = p),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date',
                  border: const OutlineInputBorder(),
                  errorText: _errFor('date'),
                ),
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date ?? DateTime.now(),
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 90)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _date == null
                          ? 'Select date'
                          : _date!.toIso8601String().split('T').first,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _hoursCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                decoration: InputDecoration(
                  labelText: 'Hours (decimal)',
                  helperText: '0.25 = 15 min',
                  border: const OutlineInputBorder(),
                  errorText: _errFor('hours'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'What did you work on?',
                  border: const OutlineInputBorder(),
                  errorText: _errFor('description'),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Submit for approval immediately'),
                subtitle: const Text(
                    'Otherwise it lands as a draft you can edit.'),
                value: _submitImmediately,
                onChanged: (v) => setState(() => _submitImmediately = v),
              ),
              if (_topError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.shade100,
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
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
