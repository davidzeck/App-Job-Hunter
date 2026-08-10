import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/theme/app_theme.dart';

/// Where you have worked. Wins attach to the role you held when they happened,
/// which is what turns a flat list into a career history.
class EmploymentsScreen extends StatefulWidget {
  const EmploymentsScreen({super.key});

  @override
  State<EmploymentsScreen> createState() => _EmploymentsScreenState();
}

class _EmploymentsScreenState extends State<EmploymentsScreen> {
  final _api = api;
  List<Employment> _employments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final employments = await _api.listEmployments();
      if (!mounted) return;
      setState(() {
        _employments = employments;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit([Employment? existing]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EmploymentSheet(existing: existing),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _delete(Employment employment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this role?'),
        content: Text(
          '${employment.roleTitle} at ${employment.employerName}. '
          'Wins logged against it stay in your log.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteEmployment(employment.id);
      await _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Roles',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add role'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  if (_error != null) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline,
                            color: AppColors.destructive),
                        title:
                            Text(_error!, style: theme.textTheme.bodySmall),
                        trailing: TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_employments.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.badge_outlined, size: 48, color: muted),
                            const SizedBox(height: 12),
                            Text('No roles yet',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(
                              'Add where you work now, and your logged wins '
                              'attach to it automatically.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: muted),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._employments.map(
                      (e) => _EmploymentTile(
                        employment: e,
                        isDark: isDark,
                        onEdit: () => _edit(e),
                        onDelete: () => _delete(e),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _EmploymentTile extends StatelessWidget {
  final Employment employment;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EmploymentTile({
    required this.employment,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('MMM yyyy');
    final period = '${fmt.format(employment.startDate)} — '
        '${employment.isCurrent ? 'Present' : employment.endDate != null ? fmt.format(employment.endDate!) : '?'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          employment.isCurrent ? Icons.work : Icons.work_outline,
          color: employment.isCurrent
              ? AppColors.primaryBlue
              : (isDark
                  ? AppColors.mutedForegroundDark
                  : AppColors.mutedForegroundLight),
        ),
        title: Text(
          employment.roleTitle,
          style:
              theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${employment.employerName} • $period',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppColors.mutedForegroundDark
                : AppColors.mutedForegroundLight,
          ),
        ),
        onTap: onEdit,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit'),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading:
                    Icon(Icons.delete_outline, color: AppColors.destructive),
                title: Text('Remove',
                    style: TextStyle(color: AppColors.destructive)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add / edit sheet ──────────────────────────────────────────

class _EmploymentSheet extends StatefulWidget {
  final Employment? existing;

  const _EmploymentSheet({this.existing});

  @override
  State<_EmploymentSheet> createState() => _EmploymentSheetState();
}

class _EmploymentSheetState extends State<_EmploymentSheet> {
  late final TextEditingController _employer =
      TextEditingController(text: widget.existing?.employerName ?? '');
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.roleTitle ?? '');
  late DateTime _start = widget.existing?.startDate ?? DateTime.now();
  late DateTime? _end = widget.existing?.endDate;
  late bool _isCurrent = widget.existing?.isCurrent ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _employer.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : (_end ?? now),
      firstDate: DateTime(now.year - 50),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    final employer = _employer.text.trim();
    final title = _title.text.trim();
    if (employer.isEmpty || title.isEmpty) {
      setState(() => _error = 'Employer and role title are both needed.');
      return;
    }
    // Mirror the backend validators so the user sees the problem before the
    // round trip, not as a 422 afterwards.
    if (!_isCurrent && _end != null && _end!.isBefore(_start)) {
      setState(() => _error = 'The end date is before the start date.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final end = _isCurrent ? null : _end;
      if (widget.existing == null) {
        await api.createEmployment(
          employerName: employer,
          roleTitle: title,
          startDate: _start,
          endDate: end,
          isCurrent: _isCurrent,
        );
      } else {
        await api.updateEmployment(
          widget.existing!.id,
          employerName: employer,
          roleTitle: title,
          startDate: _start,
          endDate: end,
          isCurrent: _isCurrent,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('MMM yyyy');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Add a role' : 'Edit role',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Role title',
                hintText: 'Software Engineer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _employer,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Employer',
                hintText: 'Safaricom',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.play_arrow_outlined, size: 16),
                  label: Text('From ${fmt.format(_start)}'),
                  onPressed: _saving ? null : () => _pickDate(isStart: true),
                ),
                const SizedBox(width: 8),
                if (!_isCurrent)
                  ActionChip(
                    avatar: const Icon(Icons.stop_outlined, size: 16),
                    label: Text(
                        _end == null ? 'To…' : 'To ${fmt.format(_end!)}'),
                    onPressed: _saving ? null : () => _pickDate(isStart: false),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isCurrent,
              // At most one current role — the backend demotes the previous
              // one rather than rejecting the write.
              subtitle: const Text('New wins attach here automatically'),
              title: const Text('This is my current role'),
              onChanged:
                  _saving ? null : (v) => setState(() => _isCurrent = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.destructive),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
