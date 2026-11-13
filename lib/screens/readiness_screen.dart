import 'package:flutter/material.dart';

import '../services/interview_practice_service.dart';
import '../services/readiness_progress_service.dart';
import '../themes/app_theme.dart';
import '../widgets/info_tip.dart';

class ReadinessScreen extends StatefulWidget {
  final String profileId;
  final InterviewPracticeService? interviewService;

  const ReadinessScreen({
    super.key,
    required this.profileId,
    this.interviewService,
  });

  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends State<ReadinessScreen> {
  static const _milestones = {
    'resume': 'Prepare a résumé',
    'internship': 'Find an internship or job opportunity',
    'research': 'Explore a research opportunity',
    'certification': 'Explore a professional certification',
    'graduate': 'Review graduate program requirements',
  };
  final _answer = TextEditingController();
  late final _interview = widget.interviewService ?? InterviewPracticeService();
  late final _progress = ReadinessProgressService(widget.profileId);
  List<InterviewQuestion> _questions = [];
  Map<String, InterviewFeedback> _feedback = {};
  Set<String> _completed = {};
  final _savingMilestones = <String>{};
  int _questionIndex = 0;
  bool _loading = true;
  bool _reviewing = false;
  bool _loadFailed = false;
  bool _progressFailed = false;
  String? _reviewError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      List<InterviewQuestion> questions = [];
      try {
        questions = await InterviewPracticeService.loadQuestions();
      } catch (_) {
        // A failed question asset still leaves the milestone checklist usable.
      }
      try {
        final feedback = await _progress.loadFeedback(questions);
        final milestones = await _progress.loadMilestones(_milestones.keys);
        if (!mounted) return;
        setState(() {
          _feedback = feedback;
          _completed = milestones;
          _questionIndex = questions.indexWhere(
            (q) => !feedback.containsKey(q.id),
          );
          if (_questionIndex < 0) _questionIndex = 0;
        });
      } catch (_) {
        if (mounted) setState(() => _progressFailed = true);
      }
      if (mounted) {
        setState(() {
          _questions = questions;
          _loadFailed = questions.isEmpty;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rateAnswer() async {
    if (_reviewing || _answer.text.trim().isEmpty) return;
    final question = _questions[_questionIndex];
    final answer = _answer.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _reviewing = true;
      _reviewError = null;
    });
    try {
      final feedback = await _interview.review(question, answer);
      if (!mounted) return;
      setState(() => _feedback[question.id] = feedback);
      if (!_progressFailed) {
        try {
          await _progress.saveFeedback(question.id, feedback);
        } catch (_) {
          if (mounted) {
            setState(
              () =>
                  _reviewError = 'Feedback could not be saved on this device.',
            );
          }
        }
      }
    } on InterviewPracticeException catch (error) {
      if (mounted) setState(() => _reviewError = error.message);
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _setMilestone(String id, bool checked) async {
    setState(() => _savingMilestones.add(id));
    try {
      await _progress.setMilestone(id, checked);
      if (mounted) {
        setState(() => checked ? _completed.add(id) : _completed.remove(id));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this milestone. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingMilestones.remove(id));
    }
  }

  void _showQuestion(int index) {
    _answer.clear();
    setState(() {
      _questionIndex = index;
      _reviewError = null;
    });
  }

  @override
  void dispose() {
    _answer.dispose();
    if (widget.interviewService == null) _interview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Readiness'),
        actions: const [
          InfoTip(
            label: 'About Readiness',
            message:
                'Practice questions come from Kamya’s Interview Prep app. '
                'Only your current answer and question are sent to Gemini when you tap Rate answer. '
                'Leave out personal details. Feedback and checklist progress stay on this device.',
          ),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1090),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                    children: [
                      if (_progressFailed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'Saved progress could not be loaded. Feedback is available for this visit.',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      LayoutBuilder(
                        builder: (context, size) {
                          final practice = _loadFailed
                              ? Column(
                                  children: [
                                    const Text(
                                      'Interview questions could not be loaded.',
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _loading = true;
                                          _loadFailed = false;
                                          _progressFailed = false;
                                        });
                                        _load();
                                      },
                                      child: const Text('Try again'),
                                    ),
                                  ],
                                )
                              : _practice(context);
                          final milestones = _checklist(context);
                          if (size.maxWidth < 760) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                practice,
                                const SizedBox(height: 32),
                                milestones,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: practice),
                              const SizedBox(width: 32),
                              Expanded(flex: 2, child: milestones),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _practice(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final question = _questions[_questionIndex];
    final feedback = _feedback[question.id];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Interview practice',
          textAlign: TextAlign.center,
          style: AppThemes.pageTitle(context, size: 28),
        ),
        const SizedBox(height: 5),
        Text(
          '${_feedback.length} of ${_questions.length} questions reviewed',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: _feedback.length / _questions.length,
          semanticsLabel: 'Interview practice progress',
        ),
        const SizedBox(height: 20),
        Text(
          'Question ${_questionIndex + 1} of ${_questions.length}',
          style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
        ),
        const SizedBox(height: 6),
        Text(question.text, style: theme.textTheme.titleLarge),
        const SizedBox(height: 14),
        TextField(
          controller: _answer,
          enabled: !_reviewing,
          minLines: 4,
          maxLines: 7,
          maxLength: 4000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Your practice answer',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        Text(
          'Gemini reviews the answer you submit. Leave out personal details.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            IconButton(
              tooltip: 'Previous question',
              onPressed: _questionIndex > 0 && !_reviewing
                  ? () => _showQuestion(_questionIndex - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _answer,
              builder: (context, value, _) => FilledButton(
                onPressed: _reviewing || value.text.trim().isEmpty
                    ? null
                    : _rateAnswer,
                child: Text(_reviewing ? 'Rating answer…' : 'Rate answer'),
              ),
            ),
            IconButton(
              tooltip: 'Next question',
              onPressed: _questionIndex + 1 < _questions.length && !_reviewing
                  ? () => _showQuestion(_questionIndex + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (_reviewing) const LinearProgressIndicator(),
        if (_reviewError case final message?)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(message, style: TextStyle(color: colors.error)),
            ),
          ),
        if (feedback != null) ...[
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Semantics(
            liveRegion: true,
            child: Text(
              'Latest AI feedback',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text('Relevance ${feedback.relevance}/5')),
              Chip(label: Text('Specificity ${feedback.specificity}/5')),
              Chip(label: Text('Clarity ${feedback.clarity}/5')),
            ],
          ),
          const SizedBox(height: 10),
          Text('What worked', style: theme.textTheme.titleSmall),
          Text(feedback.strength),
          const SizedBox(height: 8),
          Text('What to try next', style: theme.textTheme.titleSmall),
          Text(feedback.nextStep),
        ],
      ],
    );
  }

  Widget _checklist(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Career and graduate school',
          textAlign: TextAlign.center,
          style: AppThemes.pageTitle(context, size: 24),
        ),
        const SizedBox(height: 5),
        Text(
          '${_completed.length} of ${_milestones.length} milestones complete',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        for (final milestone in _milestones.entries) ...[
          const Divider(height: 1),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(milestone.value),
            value: _completed.contains(milestone.key),
            onChanged:
                _progressFailed || _savingMilestones.contains(milestone.key)
                ? null
                : (value) => _setMilestone(milestone.key, value ?? false),
          ),
        ],
      ],
    );
  }
}
