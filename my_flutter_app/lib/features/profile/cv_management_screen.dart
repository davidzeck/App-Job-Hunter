import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

const _maxCvBytes = 5 * 1024 * 1024; // backend max_cv_size_mb = 5
const _maxCvsPerUser = 10; // backend MAX_CVS_PER_USER

/// Full client-side CV hub: upload (PDF), list/delete/download CVs,
/// jump to skills, and open tailored-CV drafts.
class CvManagementScreen extends StatefulWidget {
  const CvManagementScreen({super.key});

  @override
  State<CvManagementScreen> createState() => _CvManagementScreenState();
}

class _CvManagementScreenState extends State<CvManagementScreen> {
  final _api = api;
  List<CVResponse> _cvs = [];
  List<CVDraft> _drafts = [];
  bool _loading = true;
  double? _uploadProgress; // non-null while an upload is in flight
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cvs = await _api.listCvs();
      if (!mounted) return;
      setState(() {
        _cvs = cvs;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
    // Drafts load independently — a failure here shouldn't hide the CV list.
    try {
      final drafts = await _api.listDrafts();
      if (mounted) setState(() => _drafts = drafts);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _snack('Could not read the selected file');
      return;
    }
    if (!file.name.toLowerCase().endsWith('.pdf')) {
      _snack('Only PDF files are accepted');
      return;
    }
    if (bytes.length > _maxCvBytes) {
      _snack('File too large — max 5 MB');
      return;
    }

    setState(() => _uploadProgress = 0);
    try {
      await _api.uploadCv(
        bytes,
        file.name,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
      if (!mounted) return;
      setState(() => _uploadProgress = null);
      _snack('CV uploaded — extracting skills…');
      await _pollProcessing();
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadProgress = null);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Refresh the list while any CV is still processing (skills extraction).
  Future<void> _pollProcessing() async {
    for (var i = 0; i < 10; i++) {
      try {
        final cvs = await _api.listCvs();
        if (!mounted) return;
        setState(() => _cvs = cvs);
        if (!cvs.any((cv) => cv.isProcessing)) return;
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
    }
  }

  Future<void> _download(CVResponse cv) async {
    try {
      final url = await _api.getCvDownloadUrl(cv.id);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _snack('Could not open download link');
      }
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(CVResponse cv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete CV?'),
        content: Text('Delete "${cv.filename}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteCv(cv.id);
      if (mounted) setState(() => _cvs.removeWhere((c) => c.id == cv.id));
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final uploading = _uploadProgress != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage CVs',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline,
                            color: AppColors.destructive),
                        title: Text(
                          _error!.replaceFirst('Exception: ', ''),
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: TextButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ─── My CVs ────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'My CVs (${_cvs.length}/$_maxCvsPerUser)',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: uploading || _cvs.length >= _maxCvsPerUser
                            ? null
                            : _pickAndUpload,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Upload'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PDF only, max 5 MB. Skills are extracted automatically.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.mutedForegroundDark
                          : AppColors.mutedForegroundLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (uploading) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Uploading…',
                                style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: _uploadProgress),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_cvs.isEmpty && !uploading)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 48,
                              color: isDark
                                  ? AppColors.mutedForegroundDark
                                  : AppColors.mutedForegroundLight,
                            ),
                            const SizedBox(height: 12),
                            Text('No CVs yet',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              'Upload your CV to unlock skill matching, '
                              'job recommendations, and AI tailoring.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.mutedForegroundDark
                                    : AppColors.mutedForegroundLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._cvs.map((cv) => _CvTile(
                          cv: cv,
                          isDark: isDark,
                          onDownload: () => _download(cv),
                          onDelete: () => _delete(cv),
                        )),

                  // ─── Skills ────────────────────────────────
                  const SizedBox(height: 24),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.psychology_outlined,
                        color: AppColors.primaryBlue,
                      ),
                      title: Text(
                        'My Skills',
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Review and edit skills extracted from your CV',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.mutedForegroundDark
                              : AppColors.mutedForegroundLight,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                      onTap: () => context.push('/profile/skills'),
                    ),
                  ),

                  // ─── Tailored CVs (drafts) ─────────────────
                  if (_drafts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Tailored CVs',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Job-specific versions generated with AI — review, '
                      'approve, and download as PDF or Word.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.mutedForegroundDark
                            : AppColors.mutedForegroundLight,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._drafts.map((d) => _DraftTile(
                          draft: d,
                          isDark: isDark,
                          onTap: () => context
                              .push('/profile/cvs/drafts/${d.id}')
                              .then((_) => _load()),
                        )),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

// ─── CV Tile ───────────────────────────────────────────────────

class _CvTile extends StatelessWidget {
  final CVResponse cv;
  final bool isDark;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _CvTile({
    required this.cv,
    required this.isDark,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizeKb = ((cv.fileSizeBytes ?? 0) / 1024).round();
    final date = cv.createdAt.toLocal().toString().split(' ').first;

    final Widget statusIcon;
    if (cv.isReady) {
      statusIcon = const Icon(Icons.check_circle,
          color: AppColors.success, size: 22);
    } else if (cv.isProcessing) {
      statusIcon = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (cv.isFailed) {
      statusIcon = const Icon(Icons.error_outline,
          color: AppColors.destructive, size: 22);
    } else {
      statusIcon = const Icon(Icons.hourglass_empty, size: 22);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: statusIcon,
        title: Text(
          cv.filename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$sizeKb KB • ${cv.skillsExtracted} skills • $date',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppColors.mutedForegroundDark
                : AppColors.mutedForegroundLight,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'download') onDownload();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'download',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.download_outlined),
                title: Text('Download'),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading:
                    Icon(Icons.delete_outline, color: AppColors.destructive),
                title: Text('Delete',
                    style: TextStyle(color: AppColors.destructive)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Draft Tile ────────────────────────────────────────────────

class _DraftTile extends StatelessWidget {
  final CVDraft draft;
  final bool isDark;
  final VoidCallback onTap;

  const _DraftTile({
    required this.draft,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = draft.createdAt.toLocal().toString().split(' ').first;
    final (label, color) = switch (draft.status) {
      'generating' => ('Generating', AppColors.primaryBlue),
      'review' => ('Ready to review', AppColors.warning),
      'approved' => ('Rendering', AppColors.primaryBlue),
      'rendered' => ('Ready', AppColors.success),
      'failed' => ('Failed', AppColors.destructive),
      _ => ('Superseded', AppColors.mutedForegroundLight),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.auto_awesome, color: AppColors.primaryBlue),
        title: Text(
          'Tailored CV',
          style:
              theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Created $date',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark
                ? AppColors.mutedForegroundDark
                : AppColors.mutedForegroundLight,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
