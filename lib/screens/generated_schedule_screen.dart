import 'dart:convert';

import 'package:flutter/material.dart';

import '../themes/app_theme.dart';
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

import '../data/test_instructors.dart';
import '../models/course_section.dart';
import '../models/schedule_preferences.dart';
import '../services/course_section_repository.dart';
import '../services/preferences_service.dart';
import '../services/schedule_generation_service.dart';
import '../services/schedule_matching_service.dart';
import '../services/semester_plan_service.dart';

enum ScheduleView { weekly, list }

class GeneratedScheduleScreen extends StatefulWidget {
  final ScheduleDraft? draft;
  final ScheduleDraft? previousDraft;
  final String? initialRequest;
  final SemesterPlan plan;
  final ScheduleAssistantService? assistant;

  const GeneratedScheduleScreen({
    super.key,
    required this.plan,
    this.assistant,
    this.draft,
    this.previousDraft,
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
  late final Future<void> _historyReady;
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

  Future<void> _saveHistory() async {
    if (_historyError != null) return;
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

  ScheduleChangeEntry _changeEntry(
    String request,
    GeneratedSchedule schedule,
    SchedulePreferences preferences,
    List<String> changes,
  ) => ScheduleChangeEntry(
    time: DateTime.now(),
    term: _plannedTerm,
    request: request,
    changes: changes,
    result:
        '${schedule.scheduled.length} courses · ${schedule.scheduledCredits.toInt()} of ${preferences.maxCredits} credits · ${schedule.unscheduled.length} unresolved',
  );

  void _rememberChange(ScheduleChangeEntry change) {
    _latestChange = change;
    _changes = [change, ..._changes].take(20).toList();
  }

  List<SemesterPlanItem> _deferred = [];
  bool _advisorReview = false;

  List<SemesterPlanItem> _remainingDeferred(
    SemesterPlan plan,
    Iterable<SemesterPlanItem> candidates,
  ) {
    bool stillOutstanding(SemesterPlanItem previous) {
      if (previous.courseCode != null &&
          plan.items.any((item) => item.courseCode == previous.courseCode)) {
        return false;
      }
      final requirement = previous.priority?.requirementId;
      final budget = previous.priority?.requirementCreditsRemaining;
      return requirement == null ||
          budget == null ||
          plan.items
                  .where((item) => item.priority?.requirementId == requirement)
                  .fold<double>(0, (sum, item) => sum + item.credits) <
              budget;
    }

    return {
      for (final item in candidates) (item.courseCode ?? item.title): item,
    }.values.where(stillOutstanding).toList();
  }

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

  ScheduleView? _selectedView;
  List<CourseSection> _sections = const [];
  bool _sectionLoadFailed = false;
  (DateTime, DateTime)? _termDates;

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
    _updatedPlan = widget.draft?.plan;
    if ((widget.draft ?? widget.previousDraft) case final draft?) {
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
    _historyReady = _loadHistory();
    _loadSections();
  }

  Future<void> _loadSections() async {
    var sections = <CourseSection>[];
    try {
      sections = await CourseSectionRepository.loadForTerm(_plannedTerm);
    } catch (_) {
      // Keep the existing draft available while the student retries.
    }
    await _historyReady;
    if (!mounted || _profile != PreferencesService.profileId) return;
    if (sections.isEmpty) {
      setState(() => _sectionLoadFailed = true);
      return;
    }
    DateTime? firstDate;
    DateTime? lastDate;
    for (final section in sections) {
      final start = section.beginsOn;
      final end = section.endsOn;
      if (start == null || end == null || start.isAfter(end)) continue;
      if (firstDate == null || start.isBefore(firstDate)) firstDate = start;
      if (lastDate == null || end.isAfter(lastDate)) lastDate = end;
    }
    _sections = sections;
    final schedule = ScheduleGenerationService().generateSchedule(
      plan: _plan,
      sections: _permittedSections(),
      instructors: testInstructors,
      preferences: _preferences,
      preferredSections: _preferredSections,
    );
    final previous = widget.previousDraft;
    final changes = previous == null
        ? const <String>[]
        : ScheduleChangeEntry.compare(
            previous.schedule,
            schedule,
            previous.preferences,
            _preferences,
          );
    setState(() {
      if (firstDate != null && lastDate != null) {
        _termDates = (firstDate, lastDate);
      }
      _schedule = schedule;
      if (previous != null) {
        _deferred = _remainingDeferred(_plan, [
          ..._deferred,
          ...previous.plan.items,
        ]);
        _advisorReview = _advisorReview || _deferred.isNotEmpty;
      }
      if (changes.isNotEmpty) {
        _rememberChange(
          _changeEntry(
            'Rebuilt from schedule preferences',
            schedule,
            _preferences,
            changes,
          ),
        );
      }
    });
    await _saveDraft();
    if (changes.isNotEmpty) await _saveHistory();
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
        body: _sectionLoadFailed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Spring 2027 sections could not load.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          setState(() => _sectionLoadFailed = false);
                          _loadSections();
                        },
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Generated Schedule')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (context, size) {
              final view =
                  _selectedView ??
                  (size.maxWidth < 720
                      ? ScheduleView.list
                      : ScheduleView.weekly);
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Spring 2027 schedule',
                    textAlign: TextAlign.center,
                    style: AppThemes.pageTitle(context),
                  ),
                  const SizedBox(height: 6),
                  const Text('Planning draft', textAlign: TextAlign.center),
                  if (_draftSaveFailed)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'This draft could only be kept for this session.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 14),
                  _buildSummary(context, generatedSchedule, preferences),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _updating || _historyLoading
                          ? null
                          : () => _editClasses(generatedSchedule, preferences),
                      icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                      label: const Text('Add or edit classes'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildAssistant(context, generatedSchedule, preferences),
                  if (_advisorReview ||
                      _deferred.isNotEmpty ||
                      generatedSchedule.scheduled.any(
                        (item) =>
                            item.planItem.projectedEligibility ||
                            item.section.needsMeetingConfirmation,
                      ))
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Advisor review needed before registration.',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (_deferred.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Deferred requirements\n${_deferred.map((item) => item.courseCode ?? item.title).toSet().join(', ')}',
                                ),
                              ),
                            for (final item
                                in generatedSchedule.scheduled.where(
                                  (i) => i.planItem.projectedEligibility,
                                ))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${item.planItem.courseCode}: ${item.planItem.priority?.eligibility.reason ?? 'Current prerequisites must be passed first.'}',
                                ),
                              ),
                            for (final item
                                in generatedSchedule.scheduled.where(
                                  (i) => i.section.needsMeetingConfirmation,
                                ))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${item.section.courseCode} needs missing meeting days or times confirmed.',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 22),
                  _buildViewToggle(view),
                  const SizedBox(height: 20),
                  if (view == ScheduleView.weekly)
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
              );
            },
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
      manualSelection: choice.remove ? null : s,
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
    CourseSection? manualSelection,
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
        publishedSections: _sections,
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
      if (manualSelection != null) {
        final requested = {
          for (final item in schedule.scheduled)
            if (_preferredSections[item.section.courseCode] ==
                item.section.sectionNumber)
              item.section.courseCode: item.section.sectionNumber,
          manualSelection.courseCode: manualSelection.sectionNumber,
        };
        final applied = {
          for (final item in rebuilt.scheduled)
            item.section.courseCode: item.section.sectionNumber,
        };
        if (requested.entries.any(
          (choice) => applied[choice.key] != choice.value,
        )) {
          setState(
            () => _assistantStatus =
                'Could not fit ${manualSelection.fullCourseCode} with your saved sections, course requirements and credit limit. Your draft is unchanged.',
          );
          return;
        }
      }
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
      final matchingService = ScheduleMatchingService();
      for (final professor in update.preferences.preferredProfessors) {
        final matched = rebuilt.scheduled.any(
          (item) => matchingService.matchesPreferredProfessor(
            item.section,
            item.instructor,
            [professor],
          ),
        );
        if (!matched) {
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
      final change = _changeEntry(text, rebuilt, update.preferences, [
        ...ScheduleChangeEntry.compare(
          schedule,
          rebuilt,
          preferences,
          update.preferences,
        ),
        ...constraintChanges,
      ]);
      setState(() {
        _rememberChange(change);
        _deferred = _remainingDeferred(plan, [
          ..._deferred,
          ...recovery.deferred,
          ..._plan.items,
        ]);
        _advisorReview =
            update.advisorReview ||
            _deferred.isNotEmpty ||
            plan.items.any(
              (item) =>
                  item.projectedEligibility ||
                  item.type == SemesterPlanItemType.requirementSlot,
            ) ||
            rebuilt.scheduled.any(
              (item) => item.section.needsMeetingConfirmation,
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
      await _saveHistory();
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

  Future<void> _resolveSchedule(
    GeneratedSchedule schedule,
    SchedulePreferences preferences, {
    String? courseCode,
  }) => _updateSchedule(
    schedule,
    preferences,
    manualRequest: courseCode == null
        ? 'Recheck conflicts and fill this schedule'
        : 'Find a section for $courseCode',
    manualUpdate: ScheduleUpdate(
      'Rechecked available sections',
      preferences,
      _preferredSections,
      [?courseCode],
      _advisorReview,
      excludedCourses: _excludedCourses,
      excludedSections: _excludedSections,
    ),
  );

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
              Expanded(
                child: Text(
                  'Schedule changes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const InfoTip(
                label: 'How schedule updates work',
                message: 'Updates use open sections, prerequisites, lab pairings and meeting times. Confirm your draft with your advisor before registration.',
              ),
            ],
          ),
          TextField(
            controller: _request,
            enabled: !_updating && !_historyLoading,
            maxLength: 1000,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _updateSchedule(schedule, preferences),
            decoration: const InputDecoration(
              labelText: 'Change my schedule',
              hintText: 'For example, try mornings or avoid Friday',
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
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
                    : const Icon(Icons.arrow_forward, size: 18),
                label: Text(_updating ? 'Updating…' : 'Update schedule'),
              ),
              OutlinedButton(
                onPressed: _updating || _historyLoading
                    ? null
                    : () => _resolveSchedule(schedule, preferences),
                child: const Text('Resolve issues and fill schedule'),
              ),
            ],
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
    final theme = Theme.of(context);
    final credits = schedule.scheduledCredits.toInt();
    final limit = preferences.maxCredits;
    final courseCount = schedule.scheduled.length;
    final unresolved = schedule.unscheduled.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$credits / $limit credits',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      '$courseCount ${courseCount == 1 ? 'course' : 'courses'}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (unresolved > 0)
                      Text(
                        '$unresolved unresolved',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
              if (credits < limit)
                InfoTip(
                  label: 'About the credit gap',
                  message:
                      _plan.shortfallReason ??
                      'Ask your advisor about the ${limit - credits}-credit gap. No additional eligible sections fit this draft.',
                ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildViewToggle(ScheduleView view) => Align(
    alignment: Alignment.centerLeft,
    child: SegmentedButton<ScheduleView>(
      segments: const [
        ButtonSegment(value: ScheduleView.weekly, label: Text('Weekly View')),
        ButtonSegment(value: ScheduleView.list, label: Text('List View')),
      ],
      selected: {view},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onSelectionChanged: (value) =>
          setState(() => _selectedView = value.single),
    ),
  );

  Widget _buildWeeklyView(BuildContext context, GeneratedSchedule schedule) {
    if (schedule.scheduled.isEmpty) {
      return _emptyState(context, 'No classes have been scheduled yet.');
    }

    final meetings = <String, List<(ScheduledCourseSection, CourseMeeting)>>{};
    final displayed = <(String, String, int?, int?)>{};
    for (final item in schedule.scheduled) {
      for (final meeting in item.section.weeklyMeetings) {
        for (final day in meeting.days) {
          if (displayed.add((
            item.section.courseCode,
            day,
            meeting.startMinutes,
            meeting.endMinutes,
          ))) {
            (meetings[day] ??= []).add((item, meeting));
          }
        }
      }
    }
    final visibleDays = [
      ...days,
      for (final day in const ['Saturday', 'Sunday'])
        if (meetings.containsKey(day)) day,
    ];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NonTimetabledCourses(courses: schedule.scheduled),
        if (meetings.isNotEmpty) ...[
          Text('Weekly Schedule', style: theme.textTheme.titleLarge),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final minimumWidth = 200.0 * visibleDays.length;
              final width = constraints.maxWidth < minimumWidth
                  ? minimumWidth
                  : constraints.maxWidth;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (constraints.maxWidth < minimumWidth)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('Scroll across for more days.'),
                    ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final day in visibleDays)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: _buildDayColumn(
                                  context,
                                  day,
                                  meetings[day] ?? const [],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  String? _blockDates(CourseSection section) {
    final start = section.beginsOn;
    final end = section.endsOn;
    final term = _termDates;
    if (start == null ||
        end == null ||
        start.isAfter(end) ||
        term == null ||
        (start == term.$1 && end == term.$2)) {
      return null;
    }
    return '${start.month}/${start.day} to ${end.month}/${end.day}';
  }

  Widget _buildDayColumn(
    BuildContext context,
    String day,
    List<(ScheduledCourseSection, CourseMeeting)> meetings,
  ) {
    final colors = Theme.of(context).colorScheme;
    final classes = [...meetings]
      ..sort((a, b) => a.$2.startMinutes!.compareTo(b.$2.startMinutes!));

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            color: colors.surfaceContainerLow,
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface,
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
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  for (final (scheduled, meeting) in classes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _weeklyClassBlock(context, scheduled, meeting),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _weeklyClassBlock(
    BuildContext context,
    ScheduledCourseSection scheduled,
    CourseMeeting meeting,
  ) {
    final colors = Theme.of(context).colorScheme;
    final dates = _blockDates(scheduled.section);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
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
            '${meeting.startTime} - ${meeting.endTime}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          if (dates != null)
            Text(dates, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 5),
          Text(
            _professorName(scheduled),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            meeting.location ?? scheduled.section.location,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context, GeneratedSchedule schedule) {
    if (schedule.scheduled.isEmpty) {
      return _emptyState(context, 'No classes have been scheduled yet.');
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Scheduled Classes', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        const Divider(height: 1),
        for (final scheduled in schedule.scheduled) ...[
          _scheduleRow(context, scheduled, colors),
          const Divider(height: 1),
        ],
      ],
    );
  }

  Widget _scheduleRow(
    BuildContext context,
    ScheduledCourseSection scheduled,
    ColorScheme colors,
  ) {
    final section = scheduled.section;
    final dates = _blockDates(section);
    final meetingText = section.isAsynchronous
        ? 'Asynchronous · ${scheduled.planItem.credits.toInt()} credits'
        : section.scheduleDisplay;
    final notes = scheduled.matchReasons
        .where(
          (reason) => reason != 'Has open seats' && reason != 'Section is open',
        )
        .toList();

    return ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
      title: Text(
        scheduled.planItem.title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        [
          '${section.fullCourseCode} · ${_professorName(scheduled)}',
          meetingText,
          ?dates,
        ].join('\n'),
      ),
      children: [
        if (section.deliveryMethod.trim().isNotEmpty)
          _detailRow(context, 'Delivery', section.deliveryMethod),
        if (section.openSeats != null)
          _detailRow(
            context,
            'Open Seats',
            section.capacity == null
                ? '${section.openSeats}'
                : '${section.openSeats} / ${section.capacity}',
          ),
        if (section.location.trim().isNotEmpty &&
            !meetingText.contains(section.location))
          _detailRow(context, 'Location', section.location),
        if (notes.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                notes.join('. '),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ),
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
                            icon: const Icon(
                              Icons.event_repeat_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'Try resolving schedule conflicts',
                            ),
                            onPressed: _updating || _historyLoading
                                ? null
                                : () => _resolveSchedule(
                                    schedule,
                                    _preferences,
                                    courseCode: unscheduled.planItem.courseCode,
                                  ),
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
          'Imported Spring 2027 snapshot · verify current seats in Tiger Portal.',
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
