import 'package:flutter/material.dart';

import '../services/academic_advisor_context.dart';
import '../services/gemini_advisor_service.dart';

class AcademicAdvisorScreen extends StatefulWidget {
  final AcademicAdvisorContext academicContext;
  final AcademicAdvisor? advisor;

  const AcademicAdvisorScreen({
    super.key,
    required this.academicContext,
    this.advisor,
  });

  @override
  State<AcademicAdvisorScreen> createState() => _AcademicAdvisorScreenState();
}

class _AcademicAdvisorScreenState extends State<AcademicAdvisorScreen> {
  final _question = TextEditingController(
    text: 'Which classes do I still need?',
  );
  late final AcademicAdvisor _advisor;
  bool _consent = false;
  bool _busy = false;
  String? _answer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _advisor = widget.advisor ?? GeminiAdvisorService();
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    if (_busy || !_consent) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _answer = null;
    });
    try {
      final answer = await _advisor.answer(
        widget.academicContext,
        _question.text,
      );
      if (mounted) setState(() => _answer = answer);
    } on AdvisorException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = 'The AI advisor is unavailable. Please try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needed = widget.academicContext.requirements
        .where((item) => item.status == 'remaining')
        .toList();
    final inProgress = widget.academicContext.requirements
        .where((item) => item.status == 'inProgress')
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('AI Academic Advisor')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Know what comes next',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your classes below come from TigerPath’s degree audit. '
            'Gemini can explain them and help you prepare questions for your academic advisor.',
          ),
          const SizedBox(height: 16),
          Card(
            child: ExpansionTile(
              title: Text('Still needed: ${needed.length} requirements'),
              initiallyExpanded: true,
              children: needed.isEmpty
                  ? [
                      const ListTile(
                        title: Text(
                          'No remaining requirements in the current audit.',
                        ),
                      ),
                    ]
                  : needed.map(_requirementTile).toList(),
            ),
          ),
          if (inProgress.isNotEmpty)
            Card(
              child: ExpansionTile(
                title: Text('In progress: ${inProgress.length} requirements'),
                children: inProgress.map(_requirementTile).toList(),
              ),
            ),
          Card(
            child: ExpansionTile(
              title: const Text('Which courses can I take?'),
              children: [
                for (final course in widget.academicContext.courses)
                  ListTile(
                    title: Text('${course['code']} · ${course['title']}'),
                    subtitle: Text(
                      _eligibilityLabel(course['eligibility'] as String),
                    ),
                  ),
                const ListTile(
                  subtitle: Text(
                    'Some support and general education courses have not had eligibility checked. '
                    'Course availability and seats must also be verified.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Ask Gemini', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final question in [
                'Which classes do I still need?',
                'Which classes can I take next?',
                'Why are these courses in my plan?',
              ])
                ActionChip(
                  label: Text(question),
                  onPressed: _busy ? null : () => _question.text = question,
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _question,
            enabled: !_busy,
            maxLength: 1000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Your question',
              border: OutlineInputBorder(),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _consent,
            onChanged: _busy
                ? null
                : (value) => setState(() => _consent = value ?? false),
            title: const Text('Share this planning information with Gemini'),
            subtitle: const Text(
              'Sends your question, remaining requirements, course eligibility, and semester plan '
              'to Google. Your name, GPA, and individual grades are not included automatically.',
            ),
          ),
          FilledButton.icon(
            onPressed: _consent && !_busy ? _ask : null,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_busy ? 'Thinking…' : 'Ask Gemini'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_answer != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(_answer!),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'AI guidance can be mistaken. Confirm requirements and registration with an academic advisor. '
            'TigerPath currently uses a sample student record and an incomplete course catalog.',
          ),
        ],
      ),
    );
  }

  Widget _requirementTile(AdvisorRequirement item) {
    final codes = item.courseCodes.join(', ');
    final description = item.type == 'requiredCourse'
        ? codes
        : codes.isEmpty
        ? 'Approved course selection needed'
        : 'Approved options: $codes';
    return ListTile(
      title: Text(item.title),
      subtitle: Text(
        '${item.category} · $description\n'
        '${item.status == 'inProgress' ? 'In progress, pending successful completion' : '${item.remainingCredits.toStringAsFixed(0)} credits still to plan'}'
        '${item.note == null ? '' : '\n${item.note}'}',
      ),
      isThreeLine: true,
    );
  }

  String _eligibilityLabel(String status) => switch (status) {
    'eligible' => 'Academically eligible now; offering must be checked',
    'eligibleAfterCurrentTerm' =>
      'Conditional on passing current prerequisites',
    'requiresPermission' => 'Instructor permission required',
    _ => 'Blocked or needs academic review',
  };
}
