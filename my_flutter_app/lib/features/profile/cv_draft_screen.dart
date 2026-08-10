import 'package:flutter/material.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Status-driven review screen for a curated CV draft.
///
/// generating → spinner + poll
/// review     → full editor (original shown muted above editable tailored)
/// approved   → "Generating documents…" + poll
/// rendered   → Download PDF / DOCX
/// failed / superseded → terminal notices
class CvDraftScreen extends StatefulWidget {
  final String draftId;

  const CvDraftScreen({super.key, required this.draftId});

  @override
  State<CvDraftScreen> createState() => _CvDraftScreenState();
}

class _CvDraftScreenState extends State<CvDraftScreen> {
  final _api = api;
  CVDraft? _draft;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // ── Editor controllers (built once when the draft enters review) ──
  bool _controllersBuilt = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _linksCtrl;
  late TextEditingController _summaryCtrl;
  final List<TextEditingController> _skillCategoryCtrls = [];
  final List<TextEditingController> _skillItemsCtrls = [];
  final List<List<TextEditingController>> _expFieldCtrls = []; // 4 per entry
  final List<TextEditingController> _expBulletsCtrls = [];
  final List<List<TextEditingController>> _eduFieldCtrls = []; // 3 per entry
  late TextEditingController _certsCtrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    if (_controllersBuilt) {
      for (final c in [
        _nameCtrl, _emailCtrl, _phoneCtrl, _locationCtrl, _linksCtrl,
        _summaryCtrl, _certsCtrl,
        ..._skillCategoryCtrls, ..._skillItemsCtrls,
        ..._expFieldCtrls.expand((e) => e), ..._expBulletsCtrls,
        ..._eduFieldCtrls.expand((e) => e),
      ]) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final draft = await _api.getDraft(widget.draftId);
      if (!mounted) return;
      _onDraft(draft);
      if (draft.isPolling) await _poll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Await-based polling through the transient states (generating/approved).
  Future<void> _poll() async {
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final draft = await _api.getDraft(widget.draftId);
        if (!mounted) return;
        _onDraft(draft);
        if (!draft.isPolling) return;
      } catch (_) {
        // Transient poll errors are swallowed — next tick retries.
      }
    }
    if (mounted) {
      setState(() =>
          _error = 'This is taking longer than expected. Pull to retry.');
    }
  }

  void _onDraft(CVDraft draft) {
    setState(() {
      _draft = draft;
      _loading = false;
    });
    if (draft.isReview && !_controllersBuilt && draft.content != null) {
      _buildControllers(draft.content!.tailored);
    }
  }

  void _buildControllers(CVStructure t) {
    _nameCtrl = TextEditingController(text: t.contact.name);
    _emailCtrl = TextEditingController(text: t.contact.email);
    _phoneCtrl = TextEditingController(text: t.contact.phone);
    _locationCtrl = TextEditingController(text: t.contact.location);
    _linksCtrl = TextEditingController(text: t.contact.links.join('\n'));
    _summaryCtrl = TextEditingController(text: t.summary);
    for (final g in t.skills) {
      _skillCategoryCtrls.add(TextEditingController(text: g.category));
      _skillItemsCtrls.add(TextEditingController(text: g.items.join(', ')));
    }
    for (final e in t.experience) {
      _expFieldCtrls.add([
        TextEditingController(text: e.title),
        TextEditingController(text: e.company),
        TextEditingController(text: e.start),
        TextEditingController(text: e.end),
      ]);
      _expBulletsCtrls.add(TextEditingController(text: e.bullets.join('\n')));
    }
    for (final e in t.education) {
      _eduFieldCtrls.add([
        TextEditingController(text: e.degree),
        TextEditingController(text: e.institution),
        TextEditingController(text: e.year),
      ]);
    }
    _certsCtrl = TextEditingController(text: t.certifications.join('\n'));
    _controllersBuilt = true;
  }

  List<String> _lines(String raw) => raw
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  CVStructure _assemble() {
    final tailored = _draft!.content!.tailored;
    return CVStructure(
      contact: CVContact(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        links: _lines(_linksCtrl.text),
      ),
      summary: _summaryCtrl.text.trim(),
      skills: [
        for (var i = 0; i < _skillCategoryCtrls.length; i++)
          CVSkillGroup(
            category: _skillCategoryCtrls[i].text.trim(),
            items: _skillItemsCtrls[i]
                .text
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList(),
          ),
      ],
      experience: [
        for (var i = 0; i < _expFieldCtrls.length; i++)
          CVExperience(
            title: _expFieldCtrls[i][0].text.trim(),
            company: _expFieldCtrls[i][1].text.trim(),
            location: i < tailored.experience.length
                ? tailored.experience[i].location
                : '',
            start: _expFieldCtrls[i][2].text.trim(),
            end: _expFieldCtrls[i][3].text.trim(),
            bullets: _lines(_expBulletsCtrls[i].text),
          ),
      ],
      education: [
        for (var i = 0; i < _eduFieldCtrls.length; i++)
          CVEducation(
            degree: _eduFieldCtrls[i][0].text.trim(),
            institution: _eduFieldCtrls[i][1].text.trim(),
            year: _eduFieldCtrls[i][2].text.trim(),
          ),
      ],
      certifications: _lines(_certsCtrl.text),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final draft = await _api.updateDraft(widget.draftId, _assemble());
      if (!mounted) return;
      setState(() => _draft = draft);
      _snack('Changes saved');
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _saving = true);
    try {
      await _api.updateDraft(widget.draftId, _assemble());
      await _api.approveDraft(widget.draftId);
      if (!mounted) return;
      // Refetch immediately so the UI flips to the rendering state, then poll.
      final draft = await _api.getDraft(widget.draftId);
      if (!mounted) return;
      _onDraft(draft);
      if (draft.isPolling) await _poll();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _download(String format) async {
    try {
      final url = await _api.getDraftDownloadUrl(widget.draftId, format);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _snack('Could not open download link');
      }
    } catch (_) {
      _snack('Still rendering — try again in a moment');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = _draft;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tailored CV',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: _buildBody(theme, draft),
      bottomNavigationBar: (draft?.isReview ?? false) ? _reviewBar(theme) : null,
    );
  }

  Widget _buildBody(ThemeData theme, CVDraft? draft) {
    if (_loading && draft == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && draft == null) {
      return _CenteredNotice(
        icon: Icons.error_outline,
        iconColor: AppColors.destructive,
        title: 'Could not load draft',
        message: _error!,
        action: TextButton(onPressed: _load, child: const Text('Retry')),
      );
    }
    if (draft == null) return const SizedBox.shrink();

    if (draft.isGenerating) {
      return _CenteredNotice(
        spinner: true,
        title: 'Curating your CV…',
        message:
            'AI is tailoring your full CV for this job. Usually under a minute.',
        action: _error != null
            ? TextButton(onPressed: _load, child: const Text('Retry'))
            : null,
      );
    }
    if (draft.isApproved) {
      return const _CenteredNotice(
        spinner: true,
        title: 'Generating documents…',
        message: 'Rendering your approved CV as PDF and Word.',
      );
    }
    if (draft.isRendered) {
      return _renderedView(theme, draft);
    }
    if (draft.isFailed) {
      return _CenteredNotice(
        icon: Icons.error_outline,
        iconColor: AppColors.destructive,
        title: 'Curation failed',
        message: draft.error ??
            'Something went wrong. Start a new curation from the job page.',
      );
    }
    if (draft.isSuperseded) {
      return const _CenteredNotice(
        icon: Icons.history,
        title: 'Draft superseded',
        message:
            'A newer draft exists for this CV and job. Check Manage CVs for your latest drafts.',
      );
    }
    // review
    return _editor(theme, draft);
  }

  // ─── Rendered (downloads) ────────────────────────────────────

  Widget _renderedView(ThemeData theme, CVDraft draft) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 64),
            const SizedBox(height: 16),
            Text('Your tailored CV is ready',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Download it in the format the employer prefers.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: draft.pdfReady ? () => _download('pdf') : null,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Download PDF'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: draft.docxReady ? () => _download('docx') : null,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Download Word (DOCX)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Review editor ───────────────────────────────────────────

  Widget _reviewBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.cardDark
            : AppColors.cardLight,
        border: Border(
          top: BorderSide(
            color: theme.brightness == Brightness.dark
                ? AppColors.borderDark
                : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _saving ? null : _approve,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Approve & generate'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editor(ThemeData theme, CVDraft draft) {
    if (!_controllersBuilt) {
      return const Center(child: CircularProgressIndicator());
    }
    final isDark = theme.brightness == Brightness.dark;
    final original = draft.content!.original;
    final keywords = draft.content!.keywordsInjected;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Injected keywords banner
        if (keywords.isNotEmpty) ...[
          Text(
            'Keywords added by AI — review for accuracy. You are responsible '
            'for your CV.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.mutedForegroundDark
                  : AppColors.mutedForegroundLight,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: keywords
                .map((k) => Chip(
                      label: Text(k),
                      labelStyle: theme.textTheme.labelSmall
                          ?.copyWith(color: AppColors.primaryBlue),
                      backgroundColor:
                          AppColors.primaryBlue.withValues(alpha: 0.1),
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Contact
        _sectionCard(theme, 'Contact', [
          _field(_nameCtrl, 'Name'),
          _field(_emailCtrl, 'Email'),
          _field(_phoneCtrl, 'Phone'),
          _field(_locationCtrl, 'Location'),
          _field(_linksCtrl, 'Links (one per line)', maxLines: 2),
        ]),

        // Summary
        _sectionCard(theme, 'Summary', [
          _originalBlock(theme, isDark, original.summary),
          _field(_summaryCtrl, 'Tailored summary', maxLines: 5),
        ]),

        // Skills
        _sectionCard(theme, 'Skills', [
          for (var i = 0; i < _skillCategoryCtrls.length; i++) ...[
            _field(_skillCategoryCtrls[i], 'Category'),
            _field(_skillItemsCtrls[i], 'Skills (comma-separated)',
                maxLines: 2),
            if (i < _skillCategoryCtrls.length - 1)
              const Divider(height: 24),
          ],
        ]),

        // Experience
        _sectionCard(theme, 'Work Experience', [
          for (var i = 0; i < _expFieldCtrls.length; i++) ...[
            Row(
              children: [
                Expanded(child: _field(_expFieldCtrls[i][0], 'Title')),
                const SizedBox(width: 8),
                Expanded(child: _field(_expFieldCtrls[i][1], 'Company')),
              ],
            ),
            Row(
              children: [
                Expanded(child: _field(_expFieldCtrls[i][2], 'Start')),
                const SizedBox(width: 8),
                Expanded(child: _field(_expFieldCtrls[i][3], 'End')),
              ],
            ),
            _originalBlock(
              theme,
              isDark,
              i < original.experience.length
                  ? original.experience[i].bullets.join('\n')
                  : '(no matching original entry)',
            ),
            _field(_expBulletsCtrls[i], 'Bullets (one per line)', maxLines: 6),
            if (i < _expFieldCtrls.length - 1) const Divider(height: 24),
          ],
        ]),

        // Education
        _sectionCard(theme, 'Education', [
          for (var i = 0; i < _eduFieldCtrls.length; i++) ...[
            _field(_eduFieldCtrls[i][0], 'Degree'),
            Row(
              children: [
                Expanded(child: _field(_eduFieldCtrls[i][1], 'Institution')),
                const SizedBox(width: 8),
                SizedBox(width: 90, child: _field(_eduFieldCtrls[i][2], 'Year')),
              ],
            ),
            if (i < _eduFieldCtrls.length - 1) const Divider(height: 24),
          ],
        ]),

        // Certifications
        _sectionCard(theme, 'Certifications', [
          _field(_certsCtrl, 'One per line', maxLines: 3),
        ]),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _sectionCard(ThemeData theme, String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Muted, read-only rendering of the original section for comparison.
  Widget _originalBlock(ThemeData theme, bool isDark, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ORIGINAL',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark
                  ? AppColors.mutedForegroundDark
                  : AppColors.mutedForegroundLight,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(text, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }
}

// ─── Centered notice (spinner / terminal states) ───────────────

class _CenteredNotice extends StatelessWidget {
  final bool spinner;
  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String message;
  final Widget? action;

  const _CenteredNotice({
    this.spinner = false,
    this.icon,
    this.iconColor,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner)
              const CircularProgressIndicator()
            else if (icon != null)
              Icon(icon, size: 56, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
