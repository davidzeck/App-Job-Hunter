import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:job_scout/core/models/models.dart';
import 'package:job_scout/core/services/service_locator.dart';
import 'package:job_scout/core/theme/app_theme.dart';

/// Answer a question out loud, then send it for analysis.
///
/// Two rules this screen exists to honour:
///   • **The mic is never live without a visible indicator.** The recording
///     dot and the running clock are on screen for the entire duration.
///   • **The recording does not survive.** It is uploaded, transcribed and
///     deleted server-side; the local temp file is deleted here.
class RecordAnswerScreen extends StatefulWidget {
  final String questionId;

  /// Passed through by the practice list so the common path needs no extra
  /// fetch. Null on a deep link, which falls back to looking it up.
  final PracticeQuestion? question;

  const RecordAnswerScreen({
    super.key,
    required this.questionId,
    this.question,
  });

  @override
  State<RecordAnswerScreen> createState() => _RecordAnswerScreenState();
}

enum _Stage { loading, ready, recording, uploading, analyzing, failed }

class _RecordAnswerScreenState extends State<RecordAnswerScreen> {
  final _api = api;
  final _recorder = AudioRecorder();

  // A practice answer must be long enough to score and short enough to stay
  // interview-realistic. The backend accepts far more; this is a UX cap.
  static const _maxRecordingSeconds = 300; // 5 min
  static const _minRecordingSeconds = 5;

  _Stage _stage = _Stage.loading;
  PracticeQuestion? _question;
  List<AchievementEvidence> _evidence = [];
  String? _sessionId;
  String? _error;

  Timer? _ticker;
  int _elapsed = 0;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Never leave the mic open behind a closed screen.
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      var question = widget.question;
      if (question == null) {
        // Deep-linked in. The bank has no by-id endpoint, so scan the page —
        // fine as a fallback, wasteful as the normal path.
        final questions = await _api.getPracticeQuestions(limit: 100);
        final match = questions.where((q) => q.id == widget.questionId);
        if (match.isEmpty) throw Exception('Question not found');
        question = match.first;
      }

      final session = await _api.startPracticeSession();

      if (!mounted) return;
      setState(() {
        _question = question;
        _sessionId = session.id;
        _stage = _Stage.ready;
      });

      // The payoff of the achievement log, surfaced exactly where it helps:
      // behavioural questions are the ones your own history can answer.
      if (question.isBehavioral) {
        try {
          final evidence = await _api.getQuestionEvidence(question.id);
          if (mounted) setState(() => _evidence = evidence);
        } catch (_) {
          // Evidence is a bonus — never block practice on it.
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _stage = _Stage.failed;
      });
    }
  }

  Future<void> _start() async {
    final granted = await Permission.microphone.request();
    if (!granted.isGranted) {
      if (!mounted) return;
      final permanentlyDenied = granted.isPermanentlyDenied;
      _snack(
        permanentlyDenied
            ? 'Microphone access is off. Enable it in Settings to practise.'
            : 'Practice needs the microphone to hear your answer.',
        action: permanentlyDenied
            ? SnackBarAction(label: 'Settings', onPressed: openAppSettings)
            : null,
      );
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/answer_${DateTime.now().millisecondsSinceEpoch}.m4a';
      // AAC in an .m4a container → audio/mp4, which the backend accepts and
      // Gemini transcribes directly. 64 kbps mono is plenty for speech and
      // keeps a 5-minute answer around 2.4 MB.
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _elapsed = 0;
        _stage = _Stage.recording;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed++);
        if (_elapsed >= _maxRecordingSeconds) _stop();
      });
    } catch (e) {
      _snack('Could not start recording: $e');
    }
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    final tooShort = _elapsed < _minRecordingSeconds;
    try {
      final path = await _recorder.stop();
      if (!mounted) return;

      if (tooShort) {
        if (path != null) _deleteLocal(path);
        setState(() {
          _stage = _Stage.ready;
          _elapsed = 0;
        });
        _snack('That was very short — give it a few more seconds.');
        return;
      }
      if (path == null) {
        setState(() => _stage = _Stage.ready);
        _snack('Nothing was recorded.');
        return;
      }
      await _upload(path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _stage = _Stage.ready);
      _snack('Could not stop cleanly: $e');
    }
  }

  Future<void> _cancelRecording() async {
    _ticker?.cancel();
    try {
      final path = await _recorder.stop();
      if (path != null) _deleteLocal(path);
    } catch (_) {
      // Best-effort — the temp file is disposable either way.
    }
    if (!mounted) return;
    setState(() {
      _stage = _Stage.ready;
      _elapsed = 0;
    });
  }

  Future<void> _upload(String path) async {
    setState(() {
      _stage = _Stage.uploading;
      _uploadProgress = 0;
    });
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();

      final started = await _api.uploadAnswer(
        sessionId: _sessionId!,
        bytes: bytes,
        filename: path.split('/').last,
        contentType: 'audio/mp4',
        questionId: widget.questionId,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      // The upload succeeded, so the local copy has done its job.
      _deleteLocal(path);
      if (!mounted) return;
      setState(() => _stage = _Stage.analyzing);
      await _awaitAnalysis(started.answerId);
    } catch (e) {
      _deleteLocal(path);
      if (!mounted) return;
      setState(() {
        _stage = _Stage.failed;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Transcription + scoring is real work — allow generously for it, and say
  /// so on screen rather than spinning silently.
  Future<void> _awaitAnalysis(String answerId) async {
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      try {
        final answer = await _api.getPracticeAnswer(answerId);
        if (answer.isAnalyzing || answer.isAwaitingAudio) continue;
        if (!mounted) return;
        if (answer.isFailed) {
          setState(() {
            _stage = _Stage.failed;
            _error = answer.error ??
                'We could not analyse that recording. Nothing was kept.';
          });
          return;
        }
        // End the sitting — one answer, one sitting, for standalone practice.
        try {
          await _api.updatePracticeSession(_sessionId!, ended: true);
        } catch (_) {}
        if (mounted) context.pushReplacement('/practice/debrief/$answerId');
        return;
      } catch (_) {
        // A dropped poll is not fatal; the next tick retries.
      }
    }
    if (!mounted) return;
    setState(() {
      _stage = _Stage.failed;
      _error = 'Analysis is taking longer than expected. '
          'Check your practice history in a moment.';
    });
  }

  void _deleteLocal(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      // The OS clears the temp directory anyway.
    }
  }

  void _snack(String message, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), action: action),
    );
  }

  String get _clock {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;
    final recording = _stage == _Stage.recording;

    return PopScope(
      // Leaving mid-recording must stop the mic, not orphan it.
      canPop: !recording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && recording) _cancelRecording();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Practice',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        body: _stage == _Stage.loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_question != null) ...[
                                Text(
                                  _question!.category.toUpperCase(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _question!.question,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                              if (_evidence.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                _EvidenceCard(
                                  evidence: _evidence,
                                  isDark: isDark,
                                ),
                              ],
                              if (_stage == _Stage.failed &&
                                  _error != null) ...[
                                const SizedBox(height: 20),
                                Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.error_outline,
                                        color: AppColors.destructive),
                                    title: Text(_error!,
                                        style: theme.textTheme.bodySmall),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // ─── The recorder ─────────────────────
                      if (_stage == _Stage.uploading)
                        _Busy(
                          label: 'Uploading your answer…',
                          progress: _uploadProgress,
                        )
                      else if (_stage == _Stage.analyzing)
                        const _Busy(
                          label: 'Listening back and scoring it…\n'
                              'This takes up to a minute.',
                        )
                      else ...[
                        if (recording)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // The always-on "you are being recorded" signal.
                              const _RecordingDot(),
                              const SizedBox(width: 10),
                              Text(
                                _clock,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [],
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Answer out loud, as you would in the room. '
                            'Aim for 60–120 seconds.',
                            textAlign: TextAlign.center,
                            style:
                                theme.textTheme.bodySmall?.copyWith(color: muted),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor:
                                  recording ? AppColors.destructive : null,
                            ),
                            onPressed: _stage == _Stage.failed
                                ? () => setState(() {
                                      _stage = _Stage.ready;
                                      _error = null;
                                    })
                                : (recording ? _stop : _start),
                            icon: Icon(
                              _stage == _Stage.failed
                                  ? Icons.refresh
                                  : (recording ? Icons.stop : Icons.mic),
                            ),
                            label: Text(
                              _stage == _Stage.failed
                                  ? 'Try again'
                                  : (recording
                                      ? 'Stop and analyse'
                                      : 'Start recording'),
                            ),
                          ),
                        ),
                        if (recording)
                          Center(
                            child: TextButton(
                              onPressed: _cancelRecording,
                              child: const Text('Discard'),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              'Your recording is transcribed, then deleted. '
                              'Only the transcript and your scores are kept.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: muted),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ─── Pieces ────────────────────────────────────────────────────

/// A pulsing red dot. Deliberately not subtle.
class _RecordingDot extends StatefulWidget {
  const _RecordingDot();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.3).animate(_controller),
      child: Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          color: AppColors.destructive,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  final String label;
  final double? progress;

  const _Busy({required this.label, this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (progress != null)
          LinearProgressIndicator(value: progress)
        else
          const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(label, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// "You have real examples for this" — the moment the achievement log pays
/// back into the interview wedge.
class _EvidenceCard extends StatelessWidget {
  final List<AchievementEvidence> evidence;
  final bool isDark;

  const _EvidenceCard({required this.evidence, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = isDark
        ? AppColors.mutedForegroundDark
        : AppColors.mutedForegroundLight;
    final n = evidence.length;

    return Card(
      color: AppColors.primaryBlue.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined,
                    size: 18, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    n == 1
                        ? 'You have 1 real example for this'
                        : 'You have $n real examples for this',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'From your own log — use one of these rather than inventing '
              'something on the spot.',
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 12),
            ...evidence.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.headline ?? e.cvBullet ?? '',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (e.metric != null)
                      Text(
                        e.metric!,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.success),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
