import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/theme/app_theme.dart';

/// Capture a win in the user's own words.
///
/// Deliberately one field and one date: the whole interaction has to be under
/// a minute or the weekly habit dies. Everything else — the role it attaches
/// to, the skills, the CV bullet — is derived server-side afterwards.
///
/// Returns the new achievement's id, or null if the user backed out.
Future<String?> showLogAchievementSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _LogAchievementSheet(),
  );
}

class _LogAchievementSheet extends StatefulWidget {
  const _LogAchievementSheet();

  @override
  State<_LogAchievementSheet> createState() => _LogAchievementSheetState();
}

class _LogAchievementSheetState extends State<_LogAchievementSheet> {
  final _controller = TextEditingController();
  DateTime _occurredAt = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      // When it happened, not when it was logged — so the past is open and
      // the future is not.
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _occurredAt = picked);
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.length < 3) {
      setState(() => _error = 'Tell me a little more than that.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final started = await api.logAchievement(text, occurredAt: _occurredAt);
      if (mounted) Navigator.pop(context, started.achievementId);
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
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;
    final isToday = DateUtils.isSameDay(_occurredAt, DateTime.now());

    return Padding(
      // Sit above the keyboard rather than behind it.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log a win',
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'What did you ship, fix, lead or learn? Your words, not a CV bullet '
            '— we handle that part.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 5,
            minLines: 3,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            enabled: !_saving,
            decoration: const InputDecoration(
              hintText:
                  'e.g. Cut our checkout latency from 800ms to 480ms by '
                  'batching the payment provider calls.',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.event_outlined, size: 16),
                label: Text(
                  isToday
                      ? 'Today'
                      : DateFormat('d MMM yyyy').format(_occurredAt),
                ),
                onPressed: _saving ? null : _pickDate,
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
    );
  }
}

/// The "add a number" nudge — the same discipline as the interview coach's
/// metrics_injection drill, taught in two places.
///
/// Fires only after structuring has run and found no concrete figure, so an
/// unanalysed entry is never nagged. Returns true if the entry was updated.
Future<bool> showAddMetricSheet(
  BuildContext context,
  Achievement achievement,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddMetricSheet(achievement: achievement),
  );
  return result ?? false;
}

class _AddMetricSheet extends StatefulWidget {
  final Achievement achievement;

  const _AddMetricSheet({required this.achievement});

  @override
  State<_AddMetricSheet> createState() => _AddMetricSheetState();
}

class _AddMetricSheetState extends State<_AddMetricSheet> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final addition = _controller.text.trim();
    if (addition.isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Append rather than replace: raw_text is the permanent record, and the
      // number is something the user is adding to their own account of it.
      await api.updateAchievement(
        widget.achievement.id,
        rawText: '${widget.achievement.rawText.trimRight()} $addition',
      );
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
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: AppColors.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Can you add a number?',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Saved — but there is no figure in it yet. A number is what makes '
            'this land in an interview or on a CV. How much, how many, how '
            'much faster?',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.achievement.rawText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 2,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            enabled: !_saving,
            decoration: const InputDecoration(
              hintText: 'e.g. Both were shipping independently within 3 weeks.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed:
                    _saving ? null : () => Navigator.pop(context, false),
                child: const Text('Not now'),
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
                    : const Text('Add it'),
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
    );
  }
}
