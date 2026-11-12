import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/info_tip.dart';
import '../widgets/manual_schedule_editor.dart';
import '../widgets/non_timetabled_courses.dart';
import '../services/schedule_change_history_service.dart';

import '../services/schedule_assistant_service.dart';
import '../services/schedule_draft_service.dart';
import '../services/schedule_edit_context_service.dart';
import '../services/course_priority_service.dart';
import '../services/course_eligibility_service.dart';
import '../services/schedule_recovery_service.dart';
import '../data/test_student.dart';
import '../data/program_registry.dart';

import '../data/test_course_sections.dart';
import '../data/test_instructors.dart';
import '../models/course_section.dart';
import '../models/schedule_preferences.dart';
import '../services/course_section_repository.dart';
import '../services/preferences_service.dart';
import '../services/schedule_generation_service.dart';
import '../services/semester_plan_service.dart';

enum ScheduleView { weekly, list }

class GeneratedScheduleScreen extends StatefulWidget {
  final ScheduleDraft? draft;
  final String? initialRequest;
  final SemesterPlan plan;
  final ScheduleAssistantService? assistant;

  const GeneratedScheduleScreen({
    super.key,
    required this.plan,
    this.assistant,
    this.draft,
    this.initialRequest,
  });

  @override
  State<GeneratedScheduleScreen> createState() =>
      _GeneratedScheduleScreenState();
}

class _GeneratedScheduleScreenState extends State<GeneratedScheduleScreen> {
  static const String _plannedTerm = CourseSectionRepository.spring2027Term;

  final _request = TextEditingController();
  late final _assistant = widget.assistant ?? ScheduleAssistantService();
  SemesterPlan? _updatedPlan;
  late SchedulePreferences _preferences;
  Map<String, String> _preferredSections = {};
  List<String> _excludedCourses = [];
  List<String> _excludedSections = [];
  bool _initialRequestSent = false;
  List<CourseSection> _permittedSections({
    List<String>? courses,
    List<String>? excludedSections,
    Map<String, String>? selections,
  }) {
    return ScheduleDraftService.permittedSections(
      _sections,
      excludedCourses: courses ?? _excludedCourses,
      excludedSections: excludedSections ?? _excludedSections,
      sectionPreferences: selections ?? _preferredSections,
    );
  }

  String? _assistantStatus;
  late final String _profile;
  late final _history = ScheduleChangeHistoryService(_profile);
  GeneratedSchedule? _schedule;
  bool _draftSaveFailed = false;
  List<ScheduleChangeEntry> _changes = [];
  ScheduleChangeEntry? _latestChange;
  String? _historyError;
  bool _historyLoading = true;

  Future<void> _loadHistory() async {
    try {
      final entries = await _history.load();
      if (mounted) setState(() => _changes = entries);
    } catch (_) {
      if (mounted) {
        setState(
          () => _historyError = 'Saved change history could not load. New updates will not overwrite it.',
        );
      }
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  List<SemesterPlanItem> _deferred = [];
  bool _advisorReview = false;
  List<CoursePriorityResult> get _alternatives {
    final offeredCodes = {
      for (final section in _sections)
        if (section.isOpen && section.hasOpenSeats) section.courseCode,
    };
    final freshman = activeStudent.classification.toLowerCase() == 'freshman';
    return CoursePriorityService()
        .rankCourses(activeStudent, activeProgram, activeCatalog)
        .where((item) {
          final code = item.course.code;
          final status = item.eligibility.status;
          final level =
              int.tryParse(
                RegExp(r'\d{3}').firstMatch(code)?.group(0) ?? '999',
              ) ??
              999;
          return offeredCodes.contains(code) &&
              (!freshman || level < 300) &&
              (status == EligibilityStatus.eligible ||
                  status == EligibilityStatus.eligibleAfterCurrentTerm);
        })
        .toList();
  }

  bool _updating = false;
  SemesterPlan get _plan => _updatedPlan ?? widget.plan;

  @override
  void dispose() {
    _request.dispose();
    if (widget.assistant == null) _assistant.dispose();
    super.dispose();
  }

  ScheduleView selectedView = ScheduleView.weekly;
  List<CourseSection> _sections = testCourseSections;
  bool _usingRealData = false;

  final List<String> days = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  @override
  void initState() {
    super.initState();
    // Bind async work to the profile that opened this screen.
    _profile = PreferencesService.profileId;
    if (widget.draft case final draft?) {
      _updatedPlan = draft.plan;
      _preferredSections = Map.of(draft.sectionPreferences);
      _excludedCourses = List.of(draft.excludedCourses);
      _excludedSections = List.of(draft.excludedSections);
      _deferred = List.of(draft.deferred);
      _advisorReview = draft.advisorReview;
    }
    _preferences =
        widget.draft?.preferences ??
        PreferencesService.preferences ??
        const SchedulePreferences(
          preferredTime: 'No Preference',
          preferredDays: [],
          avoidedDays: [],
          preferredProfessors: [],
          maxCredits: 15,
          avoidEarlyClasses: false,
          avoidLateClasses: false,
          minimizeGaps: true,
        );
    _loadHistory();
    _loadSections();
  }

  Future<void> _loadSections() async {
    var sections = <CourseSection>[];
    try {
      sections = await CourseSectionRepository.loadForTerm(_plannedTerm);
    } catch (_) {
      // Retain the demo fallback when imported sections are unavailable.
    }
    if (!mounted || _profile != PreferencesService.profileId) return;
    setState(() {
      _usingRealData = sections.isNotEmpty;
      _sections = _usingRealData ? sections : testCourseSections;
      _schedule = ScheduleGenerationService().generateSchedule(
        plan: _plan,
        sections: _permittedSections(),
        instructors: testInstructors,
        preferences: _preferences,
        preferredSections: _preferredSections,
      );
    });
    await _saveDraft();
  }

  Future<void> _saveDraft() async {
    if (_profile != PreferencesService.profileId) return;
    final failed = !await ScheduleDraftService.save(
      ScheduleDraft(
        plan: _plan,
        schedule: _schedule!,
        preferences: _preferences,
        sectionPreferences: Map.of(_preferredSections),
        excludedCourses: List.of(_excludedCourses),
        excludedSections: List.of(_excludedSections),
        deferred: List.of(_deferred),
        advisorReview: _advisorReview,
      ),
    );
    if (mounted && _draftSaveFailed != failed) {
      setState(() => _draftSaveFailed = failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final generatedSchedule = _schedule;
    if (generatedSchedule == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Generated Schedule')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final preferences = _preferences;
    if (!_initialRequestSent &&
        !_historyLoading &&
        widget.initialRequest != null) {
      _initialRequestSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _request.text = widget.initialRequest!;
        _updateSchedule(generatedSchedule, preferences);
      });
    }
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Generated Schedule')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                textAlign: TextAlign.center,
                'Your Semester Schedule',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                textAlign: TextAlign.center,
                'Spring 2027 · Planning draft for advisor review',
                style: TextStyle(
                  fontSize: 15,
                  color: colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
              if (_draftSaveFailed)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'This draft could only be kept for this session.',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              _buildSummary(context, generatedSchedule, preferences),
              if (generatedSchedule.scheduledCredits < preferences.maxCredits)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${generatedSchedule.scheduledCredits.toInt()} of ${preferences.maxCredits} credits scheduled · advisor review needed',
                        ),
                      ),
                      InfoTip(
                        label: 'About the credit gap',
                        message: _plan.shortfallReason ?? 'No verified combination filled the remaining credits under the current constraints.',
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _updating || _historyLoading
                    ? null
                    : () => _editClasses(generatedSchedule, preferences),
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('Add or edit classes'),
              ),
              _buildAssistant(context, generatedSchedule, preferences),
              if (_deferred.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Deferred from this term: ${_deferred.map((item) => item.courseCode ?? item.title).toSet().join(", ")}. Still required for your degree.',
                    ),
                  ),
                ),
              if (_advisorReview ||
                  generatedSchedule.scheduled.any(
                    (item) =>
                        item.planItem.projectedEligibility ||
                        !item.section.hasPrimaryMeetingTime,
                  ))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Advisor review needed before registration.',
                        ),
                        for (final item in generatedSchedule.scheduled.where(
                          (i) => i.planItem.projectedEligibility,
                        ))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${item.planItem.courseCode}: ${item.planItem.priority?.eligibility.reason ?? 'Current prerequisites must be passed first.'}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 22),
              _buildViewToggle(context),
              const SizedBox(height: 20),
              if (selectedView == ScheduleView.weekly)
                _buildWeeklyView(context, generatedSchedule)
              else
                _buildListView(context, generatedSchedule),
              if (generatedSchedule.unscheduled.isNotEmpty) ...[
                const SizedBox(height: 30),
                _buildUnscheduledSection(context, generatedSchedule),
              ],
              const SizedBox(height: 24),
              _buildDataNotice(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editClasses(
    GeneratedSchedule schedule,
    SchedulePreferences preferences,
  ) async {
    final eligible = _alternatives.map((a) => a.course.code).toSet();
    final choice = await showModalBottomSheet<ManualScheduleChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: ManualScheduleEditor(
          courseNames: {
            for (final course in activeCatalog) course.code: course.title,
          },
          schedule: schedule,
          sections: _sections
              .where(
                (s) =>
                    eligible.contains(s.courseCode) &&
                    s.isOpen &&
                    s.hasOpenSeats,
              )
              .toList(),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final s = choice.section;
    final pins = Map<String, String>.of(_preferredSections)
      ..remove(s.courseCode);
    final excluded = Set<String>.of(_excludedCourses);
    if (choice.remove) {
      excluded.add(s.courseCode);
    } else {
      excluded.remove(s.courseCode);
      pins[s.courseCode] = s.sectionNumber;
    }
    await _updateSchedule(
      schedule,
      preferences,
      manualRequest: choice.remove
          ? 'Manual: remove ${s.courseCode}'
          : 'Manual: select ${s.courseCode} section ${s.sectionNumber}',
      manualUpdate: ScheduleUpdate(
        'Manual class edit',
        preferences,
        pins,
        choice.remove ? [] : [s.courseCode],
        true,
        excludedCourses: excluded.toList(),
        excludedSections: _excludedSections
            .where((key) => key != '${s.courseCode}|${s.sectionNumber}')
            .toList(),
      ),
    );
  }

  Future<void> _updateSchedule(
    GeneratedSchedule schedule,
    SchedulePreferences preferences, {
    ScheduleUpdate? manualUpdate,
    String? manualRequest,
  }) async {
    final text = manualRequest ?? _request.text.trim();
    if (_updating || _historyLoading || text.isEmpty) return;
    try {
      ScheduleAssistantService.explicitCreditTarget(text);
    } on FormatException catch (error) {
      setState(
        () => _assistantStatus = '${error.message} Your schedule is unchanged.',
      );
      return;
    }
    setState(() {
      _updating = true;
      _assistantStatus = 'Updating your schedule…';
    });
    try {
      final alternatives = _alternatives;
      final eligibleCourses = {
        ...alternatives.map((item) => item.course.code),
        ..._plan.items.map((item) => item.courseCode).whereType<String>(),
      };
      final available = _sections
          .where((section) => eligibleCourses.contains(section.courseCode))
          .toList();
      final update =
          manualUpdate ??
          await _assistant.update(
            text,
            ScheduleEditContextService.build(
              program: activeProgram.name,
              classification: activeStudent.classification,
              term: _plannedTerm,
              schedule: schedule,
              preferences: preferences,
              candidates: alternatives,
              available: available,
              question: text,
              excludedCourses: _excludedCourses,
              excludedSections: _excludedSections,
              sectionPreferences: _preferredSections,
            ),
            preferences,
            available,
            eligibleCourses: eligibleCourses.toList(),
          );
      if (update.needsClarification) {
        if (mounted) {
          setState(
            () => _assistantStatus =
                '${update.summary} Your schedule is unchanged.',
          );
        }
        return;
      }
      final choices = Map<String, String>.from(update.sectionChoices);
      final workingSections = _permittedSections(
        courses: update.excludedCourses,
        excludedSections: update.excludedSections,
        selections: choices,
      );
      final targets = {...update.courseChoices, ...choices.keys}.toList();
      var plan = SemesterPlanService().generatePlan(
        student: activeStudent,
        program: activeProgram,
        catalog: activeCatalog,
        maxCredits: update.preferences.maxCredits,
        sections: workingSections,
        preferences: update.preferences,
        preferredSections: choices,
        preferredCourses: [
          ...targets,
          ...schedule.scheduled.map((s) => s.section.courseCode),
        ],
        priorityCourseCodes: targets,
      );

      final recovery = ScheduleRecoveryService().recover(
        plan: plan,
        candidates: alternatives,
        requestedCourses: update.courseChoices,
        sections: workingSections,
        instructors: testInstructors,
        preferences: update.preferences,
        preferredSections: choices,
      );
      plan = recovery.plan;
      final rebuilt = ScheduleGenerationService().generateSchedule(
        plan: plan,
        sections: workingSections,
        instructors: testInstructors,
        preferences: update.preferences,
        preferredSections: choices,
      );
      if (!mounted || _profile != PreferencesService.profileId) return;
      final actualNotes = <String>[];
      for (final choice in choices.entries) {
        final matching = available.where(
          (s) => s.courseCode == choice.key && s.sectionNumber == choice.value,
        );
        final teacher = matching.isEmpty
            ? ''
            : matching.first.instructorDisplay;
        final applied = rebuilt.scheduled.any(
          (i) =>
              i.section.courseCode == choice.key &&
              i.section.sectionNumber == choice.value,
        );
        actualNotes.add(
          applied
              ? '${choice.key} section ${choice.value} selected${teacher.isEmpty ? '' : ' with $teacher'}.'
              : 'Could not fit ${choice.key} section ${choice.value}${teacher.isEmpty ? '' : ' with $teacher'} into a verified timetable under these constraints. Advisor review recommended.',
        );
      }
      for (final professor in update.preferences.preferredProfessors) {
        final matching = rebuilt.scheduled
            .where((s) => s.section.allInstructorNames.contains(professor))
            .toList();
        if (matching.isEmpty) {
          actualNotes.add(
            'No selected class matches $professor. That instructor request was not fulfilled in this draft; ask for another section or advisor review.',
          );
        }
      }
      for (final code in update.excludedCourses) {
        actualNotes.add(
          '$code left out of this draft; its degree requirement remains outstanding.',
        );
      }
      final constraintChanges = <String>[];
      if (jsonEncode(_excludedCourses) != jsonEncode(update.excludedCourses)) {
        constraintChanges.add(
          'Courses to avoid: ${_excludedCourses.isEmpty ? 'None' : _excludedCourses.join(', ')} → ${update.excludedCourses.isEmpty ? 'None' : update.excludedCourses.join(', ')}.',
        );
      }
      if (jsonEncode(_excludedSections) !=
          jsonEncode(update.excludedSections)) {
        constraintChanges.add(
          'Sections to avoid: ${_excludedSections.isEmpty ? 'None' : _excludedSections.join(', ')} → ${update.excludedSections.isEmpty ? 'None' : update.excludedSections.join(', ')}.',
        );
      }
      final change = ScheduleChangeEntry(
        time: DateTime.now(),
        term: _plannedTerm,
        request: text,
        changes: [
          ...ScheduleChangeEntry.compare(
            schedule,
            rebuilt,
            preferences,
            update.preferences,
          ),
          ...constraintChanges,
        ],
        result:
            '${rebuilt.scheduled.length} courses · ${rebuilt.scheduledCredits.toInt()} of ${update.preferences.maxCredits} credits · ${rebuilt.unscheduled.length} unresolved',
      );
      setState(() {
        _latestChange = change;
        _changes = [change, ..._changes].take(20).toList();
        bool stillOutstanding(SemesterPlanItem previous) {
          if (plan.items.any(
            (item) =>
                item.courseCode == previous.courseCode &&
                previous.courseCode != null,
          )) {
            return false;
          }
          final requirement = previous.priority?.requirementId;
          final budget = previous.priority?.requirementCreditsRemaining;
          if (requirement != null &&
              budget != null &&
              plan.items
                      .where((i) => i.priority?.requirementId == requirement)
                      .fold<double>(0, (sum, i) => sum + i.credits) >=
                  budget) {
            return false;
          }
          return true;
        }

        _deferred = {
          for (final item in [
            ..._deferred,
            ...recovery.deferred,
            ..._plan.items.where(stillOutstanding),
          ])
            (item.courseCode ?? item.title): item,
        }.values.where(stillOutstanding).toList();
        _advisorReview =
            update.advisorReview ||
            _deferred.isNotEmpty ||
            plan.items.any(
              (item) =>
                  item.projectedEligibility ||
                  item.type == SemesterPlanItemType.requirementSlot,
            ) ||
            rebuilt.scheduled.any(
              (item) => !item.section.hasPrimaryMeetingTime,
            );
        _updatedPlan = plan;
        _preferences = update.preferences;
        _schedule = rebuilt;
        _preferredSections = choices;
        _excludedCourses = update.excludedCourses;
        _excludedSections = update.excludedSections;
        _assistantStatus =
            'Draft rebuilt: ${rebuilt.scheduled.length} courses, ${rebuilt.scheduledCredits.toInt()} of ${update.preferences.maxCredits} credits, ${rebuilt.unscheduled.length} unresolved. Review before registration.'
            '${actualNotes.isEmpty ? '' : ' ${actualNotes.join(' ')}'}';
        _request.clear();
      });
      PreferencesService.savePreferences(update.preferences);
      await _saveDraft();
      if (_historyError == null) {
        try {
          await _history.save(_changes);
        } catch (_) {
          if (mounted) {
            setState(
              () => _historyError = 'Your schedule changed, but its change log could not be saved on this device.',
            );
          }
        }
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _assistantStatus = error is StateError
              ? '${error.message} Your schedule is unchanged.'
              : error is FormatException
              ? 'Gemini suggested an unverified schedule option. Your schedule is unchanged. Please retry.'
              : 'Could not apply this request. Your schedule is unchanged. Please retry or use the preference controls.',
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Widget _buildAssistant(
    BuildContext context,
    GeneratedSchedule schedule,
    SchedulePreferences preferences,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              const Expanded(
                child: Text(
                  'Build with Tiger Path',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ),
              const InfoTip(
                label: 'How schedule updates work',
                message: 'Tiger Path checks prerequisites, lab pairings, availability and time conflicts. Preferences are flexible. Updates change this draft only; registration and required approvals still need review.',
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            textAlign: TextAlign.center,
            'Ask for a credit goal, different times, or another section.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _request,
            enabled: !_updating && !_historyLoading,
            maxLength: 1000,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _updateSchedule(schedule, preferences),
            decoration: const InputDecoration(
              labelText: 'Change my schedule',
              hintText: 'Get me to 16 credits, try mornings, or avoid Friday…',
              border: OutlineInputBorder(),
            ),
          ),
          FilledButton.icon(
            onPressed: _updating || _historyLoading
                ? null
                : () => _updateSchedule(schedule, preferences),
            icon: _updating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_updating ? 'Updating…' : 'Update schedule'),
          ),
          OutlinedButton.icon(
            onPressed: _updating || _historyLoading
                ? null
                : () {
                    _request.text = 'Resolve time conflicts and missing offerings using other eligible remaining degree courses. Aim to fill my credit limit. Keep deferred requirements for advisor review.';
                    _updateSchedule(schedule, preferences);
                  },
            icon: const Icon(Icons.build_circle_outlined),
            label: const Text('Resolve issues and fill schedule'),
          ),
          if (_assistantStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _assistantStatus!.startsWith('Draft rebuilt:')
                  ? ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      initiallyExpanded: false,
                      title: Text(_assistantStatus!.split('. Review').first),
                      subtitle: const Text('View section results'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_assistantStatus!),
                        ),
                      ],
                    )
                  : Text(_assistantStatus!),
            ),
          const SizedBox(height: 8),
          if (_latestChange != null) ...[
            const SizedBox(height: 12),
            Text(
              _latestChange!.changes.isEmpty
                  ? 'No schedule or preference changes were made.'
                  : 'What changed',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final line in _latestChange!.highlights.take(4))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $line'),
              ),
          ],
          if (_historyError != null)
            Text(
              _historyError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          ExpansionTile(
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            title: Text('Change log (${_changes.length})'),
            subtitle: const Text('Saved on this device · latest 20 updates'),
            children: [
              if (_changes.isEmpty)
                const ListTile(title: Text('No schedule updates yet.')),
              for (final entry in _changes)
                ExpansionTile(
                  initiallyExpanded: false,
                  title: Text(entry.result),
                  subtitle: Text('${_changeTime(entry.time)} · ${entry.term}'),
                  children: [
                    ListTile(title: Text('Request: ${entry.request}')),
                    for (final line
                        in entry.changes.isEmpty
                            ? ['No schedule or preference changes were made.']
                            : entry.changes)
                      ListTile(dense: true, title: Text(line)),
                  ],
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildSummary(
    BuildContext context,
    GeneratedSchedule schedule,
    SchedulePreferences preferences,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          final items = [
            _summaryItem(
              context,
              Icons.school_outlined,
              '${schedule.scheduled.length}',
              'Courses',
            ),
            _summaryItem(
              context,
              Icons.menu_book_outlined,
              '${schedule.scheduledCredits.toInt()}',
              'Credits',
            ),
            _summaryItem(
              context,
              Icons.schedule_outlined,
              preferences.preferredTime,
              'Preferred Time',
            ),
            _summaryItem(
              context,
              Icons.warning_amber_outlined,
              '${schedule.unscheduled.length}',
              'Unresolved',
            ),
          ];

          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: items[0]),
                    const SizedBox(width: 10),
                    Expanded(child: items[1]),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: items[2]),
                    const SizedBox(width: 10),
                    Expanded(child: items[3]),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: items[0]),
              const SizedBox(width: 10),
              Expanded(child: items[1]),
              const SizedBox(width: 10),
              Expanded(child: items[2]),
              const SizedBox(width: 10),
              Expanded(child: items[3]),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
          const SizedBox(height: 7),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary
                  .withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Wrap(
          children: [
            _viewButton(
              context,
              view: ScheduleView.weekly,
              icon: Icons.calendar_view_week_outlined,
              label: 'Weekly View',
            ),
            _viewButton(
              context,
              view: ScheduleView.list,
              icon: Icons.view_agenda_outlined,
              label: 'List View',
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewButton(
    BuildContext context, {
    required ScheduleView view,
    required IconData icon,
    required String label,
  }) {
    final colors = Theme.of(context).colorScheme;
    final selected = selectedView == view;

    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () {
        setState(() {
          selectedView = view;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? colors.onPrimary : colors.primary,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? colors.onPrimary : colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyView(BuildContext context, GeneratedSchedule schedule) {
    final colors = Theme.of(context).colorScheme;

    if (schedule.scheduled.isEmpty) {
      return _emptyState(context, 'No classes have been scheduled yet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NonTimetabledCourses(courses: schedule.scheduled),
        Text(
          'Weekly Schedule',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Scroll horizontally on smaller screens.',
          style: TextStyle(
            color: colors.onSurface.withValues(alpha: 0.55),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 1000
                ? 1000.0
                : constraints.maxWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: days.map((day) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _buildDayColumn(context, day, schedule),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    String day,
    GeneratedSchedule schedule,
  ) {
    final colors = Theme.of(context).colorScheme;

    final classes =
        schedule.scheduled
            .where((item) => item.section.days.contains(day))
            .toList()
          ..sort(
            (a, b) => a.section.startMinutes.compareTo(b.section.startMinutes),
          );

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
            ),
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (classes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'No classes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.45),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: classes.map((scheduled) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _weeklyClassBlock(context, scheduled),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _weeklyClassBlock(
    BuildContext context,
    ScheduledCourseSection scheduled,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scheduled.section.courseCode,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colors.primary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            scheduled.planItem.title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            '${scheduled.section.startTime} - ${scheduled.section.endTime}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            _professorName(scheduled),
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.68),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            scheduled.section.location,
            style: TextStyle(
              color: colors.onSurface.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context, GeneratedSchedule schedule) {
    final colors = Theme.of(context).colorScheme;

    if (schedule.scheduled.isEmpty) {
      return _emptyState(context, 'No classes have been scheduled yet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scheduled Classes',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        ...schedule.scheduled.map((scheduled) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              leading: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_book_outlined, color: colors.primary),
              ),
              title: Text(
                '${scheduled.planItem.title} (${scheduled.section.courseCode})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                scheduled.section.isAsynchronous
                    ? 'Asynchronous · ${scheduled.planItem.credits.toInt()} credits · No fixed meeting time'
                    : scheduled.section.scheduleDisplay,
              ),
              children: [
                _detailRow(context, 'Course', scheduled.planItem.title),
                _detailRow(context, 'Section', scheduled.section.sectionNumber),
                _detailRow(context, 'Professor', _professorName(scheduled)),
                _detailRow(context, 'Location', scheduled.section.location),
                _detailRow(
                  context,
                  'Delivery',
                  scheduled.section.deliveryMethod,
                ),
                if (scheduled.section.openSeats != null)
                  _detailRow(
                    context,
                    'Open Seats',
                    scheduled.section.capacity == null
                        ? '${scheduled.section.openSeats}'
                        : '${scheduled.section.openSeats} / ${scheduled.section.capacity}',
                  ),
                if (scheduled.section.status != null &&
                    scheduled.section.status!.trim().isNotEmpty)
                  _detailRow(context, 'Status', scheduled.section.status!),
                if (scheduled.matchReasons.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Why this section?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 7),
                  ...scheduled.matchReasons.map((reason) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 7),
                          Expanded(child: Text(reason)),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.onSurface.withValues(alpha: 0.60),
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildUnscheduledSection(
    BuildContext context,
    GeneratedSchedule schedule,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Still Unscheduled',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'These requirements could not be placed into the current schedule.',
          style: TextStyle(color: colors.onSurface.withValues(alpha: 0.60)),
        ),
        const SizedBox(height: 14),
        ...schedule.unscheduled.map((unscheduled) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.warning_amber_outlined,
                      color: colors.error,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unscheduled.planItem.courseCode ??
                              unscheduled.planItem.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (unscheduled.planItem.courseCode != null) ...[
                          const SizedBox(height: 3),
                          Text(unscheduled.planItem.title),
                        ],
                        if (unscheduled.reason.contains('conflict'))
                          TextButton.icon(
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: const Text(
                              'Try resolving schedule conflicts',
                            ),
                            onPressed: _updating || _historyLoading
                                ? null
                                : () {
                                    _request.text =
                                        'Try to resolve time conflicts for ${unscheduled.planItem.courseCode ?? unscheduled.planItem.title} using available sections. Keep my other preferences.';
                                    _updateSchedule(schedule, _preferences);
                                  },
                          ),
                        const SizedBox(height: 8),
                        Text(
                          unscheduled.reason,
                          style: TextStyle(
                            color: colors.onSurface.withValues(alpha: 0.68),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${unscheduled.planItem.credits.toInt()} cr',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  String _changeTime(DateTime time) {
    final t = time.toLocal();
    return '${t.month}/${t.day}/${t.year} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDataNotice(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          _usingRealData
              ? 'Imported Spring 2027 snapshot · verify current seats in Tiger Portal.'
              : 'Demo sections in use. Imported offerings could not load.',
        ),
      ),
      const InfoTip(
        label: 'About section data',
        message: 'Times, instructors, locations, seats and status come from an imported snapshot, not a live registration feed. Confirm current availability in Tiger Portal before registering.',
      ),
    ],
  );

  Widget _emptyState(BuildContext context, String message) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_month_outlined, size: 38, color: colors.primary),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _professorName(ScheduledCourseSection scheduled) {
    final linkedInstructor = scheduled.instructor?.name.trim();

    if (linkedInstructor != null && linkedInstructor.isNotEmpty) {
      return linkedInstructor;
    }

    final portalName = scheduled.section.instructorDisplay.trim();

    if (portalName.isNotEmpty) {
      return portalName;
    }

    return 'Instructor TBD';
  }
}
