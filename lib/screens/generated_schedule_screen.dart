import 'package:flutter/material.dart';

import '../services/schedule_assistant_service.dart';
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
  final SemesterPlan plan;
  final ScheduleAssistantService? assistant;

  const GeneratedScheduleScreen({
    super.key,
    required this.plan,
    this.assistant,
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
  SchedulePreferences? _updatedPreferences;
  Map<String, String> _preferredSections = {};
  String? _assistantStatus;
  List<SemesterPlanItem> _deferred = [];
  bool _advisorReview = false;
  List<CoursePriorityResult> get _alternatives => CoursePriorityService()
      .rankCourses(activeStudent, activeProgram, activeCatalog)
      .where(
        (item) =>
            (activeStudent.classification.toLowerCase() != 'freshman' ||
                (int.tryParse(
                          RegExp(r'\d{3}')
                                  .firstMatch(item.course.code)
                                  ?.group(0) ??
                              '999',
                        ) ??
                        999) <
                    300) &&
            [
              EligibilityStatus.eligible,
              EligibilityStatus.eligibleAfterCurrentTerm,
            ].contains(item.eligibility.status) &&
            _sections.any(
              (section) =>
                  section.courseCode == item.course.code &&
                  section.isOpen &&
                  section.hasOpenSeats,
            ),
      )
      .toList();
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
  bool _loadingSections = true;

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

    if (CourseSectionRepository.hasTerm(_plannedTerm)) {
      _loadSections();
    } else {
      _loadingSections = false;
    }
  }

  Future<void> _loadSections() async {
    try {
      final sections = await CourseSectionRepository.loadForTerm(_plannedTerm);

      if (!mounted) {
        return;
      }

      setState(() {
        if (sections.isEmpty) {
          _sections = testCourseSections;
          _usingRealData = false;
        } else {
          _sections = sections;
          _usingRealData = true;
        }

        _loadingSections = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _sections = testCourseSections;
        _usingRealData = false;
        _loadingSections = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingSections) {
      return Scaffold(
        appBar: AppBar(title: const Text('Generated Schedule')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final preferences =
        _updatedPreferences ??
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

    final generatedSchedule = ScheduleGenerationService().generateSchedule(
      plan: _plan,
      sections: _sections,
      instructors: testInstructors,
      preferences: preferences,
      preferredSections: _preferredSections,
    );

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
                'Tiger Path Advisor selected the best available sections based on your semester plan and schedule preferences.',
                style: TextStyle(
                  fontSize: 15,
                  color: colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 24),
              _buildSummary(context, generatedSchedule, preferences),
              if (generatedSchedule.scheduledCredits < preferences.maxCredits)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _plan.shortfallReason ??
                        '${generatedSchedule.scheduledCredits.toInt()} of ${preferences.maxCredits} credits scheduled. The remaining space may require different eligible courses, sections, or advisor verification; the credit limit is not a guaranteed course load.',
                  ),
                ),
              const SizedBox(height: 12),
              _buildAssistant(context, generatedSchedule, preferences),
              if (_deferred.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Deferred from this term: ${_deferred.map((item) => item.courseCode ?? item.title).toSet().join(", ")}. These requirements remain outstanding; alternative courses do not replace them in your degree.',
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
                          'Advisor review recommended: check deferred requirements, conditional prerequisites, and the proposed course changes before registration.',
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

  Map<String, Object?> _scheduleContext(
    GeneratedSchedule schedule,
    SchedulePreferences preferences,
  ) => {
    'program': activeProgram.name,
    'classification': activeStudent.classification,
    'term': _plannedTerm,
    'source': _usingRealData ? 'Imported snapshot' : 'Demo sections',
    'scheduledCredits': schedule.scheduledCredits,
    'creditGap': preferences.maxCredits - schedule.scheduledCredits,
    'preferences': preferences.toJson()..remove('preferredProfessors'),
    'selected': [
      for (final item in schedule.scheduled)
        {
          'courseCode': item.section.courseCode,
          'section': item.section.sectionNumber,
        },
    ],
    'alternatives': [
      for (final item in _alternatives)
        {
          'courseCode': item.course.code,
          'credits': item.course.credits,
          'eligibility': item.eligibility.status.name,
          'reason': item.reasons,
          'requiredCompanions': item.eligibility.requiredCompanions,
        },
    ],
    'unresolved': [
      for (final item in schedule.unscheduled)
        {
          'courseCode': item.planItem.courseCode,
          'requirement': item.planItem.title,
          'reason': item.reason,
        },
    ],
    'choices': [
      for (final section
          in _sections
              .where(
                (section) =>
                    _plan.items.any(
                      (item) => item.courseCode == section.courseCode,
                    ) ||
                    _alternatives.any(
                      (item) => item.course.code == section.courseCode,
                    ),
              )
              .take(100))
        {
          'courseCode': section.courseCode,
          'section': section.sectionNumber,
          'instructors': section.allInstructorNames,
          'location': section.location,
          'delivery': section.deliveryMethod,
          'openSeats': section.openSeats,
          'days': section.days,
          'start': section.startTime,
          'end': section.endTime,
          'meetings': [
            for (final meeting in section.meetings) meeting.displayText,
          ],
          'open': section.isOpen && section.hasOpenSeats,
        },
    ],
  };

  Future<void> _updateSchedule(
    GeneratedSchedule schedule,
    SchedulePreferences preferences,
  ) async {
    final text = _request.text.trim();
    if (_updating || text.isEmpty) return;
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
      final available = _sections
          .where(
            (section) =>
                _plan.items.any(
                  (item) => item.courseCode == section.courseCode,
                ) ||
                _alternatives.any(
                  (item) => item.course.code == section.courseCode,
                ),
          )
          .toList();
      final update = await _assistant.update(
        text,
        _scheduleContext(schedule, preferences),
        preferences,
        available,
        eligibleCourses: {
          ..._alternatives.map((item) => item.course.code),
          ..._plan.items.map((item) => item.courseCode).whereType<String>(),
        }.toList(),
      );
      // Gemini proposes a target/preferences/candidate order; the same planner
      // validates and searches all academic options again in this tab.
      final choices = Map<String, String>.from(_preferredSections)
        ..addAll(update.sectionChoices);
      var plan = SemesterPlanService().generatePlan(
        student: activeStudent,
        program: activeProgram,
        catalog: activeCatalog,
        maxCredits: update.preferences.maxCredits,
        sections: _sections,
        preferences: update.preferences,
        preferredSections: choices,
        preferredCourses: update.courseChoices,
      );

      final recovery = ScheduleRecoveryService().recover(
        plan: plan,
        candidates: _alternatives,
        requestedCourses: update.courseChoices,
        sections: _sections,
        instructors: testInstructors,
        preferences: update.preferences,
        preferredSections: choices,
      );
      plan = recovery.plan;
      choices.removeWhere(
        (course, _) => !plan.items.any((item) => item.courseCode == course),
      );
      final rebuilt = ScheduleGenerationService().generateSchedule(
        plan: plan,
        sections: _sections,
        instructors: testInstructors,
        preferences: update.preferences,
        preferredSections: choices,
      );
      if (!mounted) return;
      setState(() {
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
        _updatedPreferences = update.preferences;
        _preferredSections = choices;
        final remaining = rebuilt.unscheduled.length;
        final missed = choices.entries
            .where(
              (choice) => !rebuilt.scheduled.any(
                (item) =>
                    item.section.courseCode == choice.key &&
                    item.section.sectionNumber == choice.value,
              ),
            )
            .length;
        _assistantStatus =
            'Draft rebuilt: ${rebuilt.scheduled.length} courses, ${rebuilt.scheduledCredits.toInt()} of ${update.preferences.maxCredits} credits, $remaining unresolved. Review before registration.'
            '${missed > 0 ? " Some requested sections could not fit without conflicts." : ""}';
        _request.clear();
      });
      PreferencesService.savePreferences(update.preferences);
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
          const Text(
            textAlign: TextAlign.center,
            'Build with Tiger Path',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            textAlign: TextAlign.center,
            'Set a credit goal or ask for a change. Tiger Path rebuilds the timetable here and checks courses, labs, availability and conflicts.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _request,
            enabled: !_updating,
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
            onPressed: _updating
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
            onPressed: _updating
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
              child: Text(_assistantStatus!),
            ),
          const SizedBox(height: 8),
          Text(
            'Current preferences: ${preferences.preferredTime}; max ${preferences.maxCredits} credits'
            '${preferences.avoidEarlyClasses ? "; favor starts from 10 AM" : ""}'
            '${preferences.avoidLateClasses ? "; favor finishes by 5 PM" : ""}'
            '${preferences.avoidedDays.isNotEmpty ? "; prefer to avoid ${preferences.avoidedDays.join(", ")}" : ""}.',
          ),
          const Text(
            'Preferences are flexible. Missing offerings and required approvals can remain unresolved.',
            style: TextStyle(fontSize: 12),
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
                scheduled.section.courseCode,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(scheduled.section.scheduleDisplay),
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
                            onPressed: _updating
                                ? null
                                : () {
                                    _request.text =
                                        'Try to resolve time conflicts for ${unscheduled.planItem.courseCode ?? unscheduled.planItem.title} using available sections. Keep my other preferences.';
                                    _updateSchedule(
                                      schedule,
                                      _updatedPreferences ??
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
                                          ),
                                    );
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

  Widget _buildDataNotice(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final message = _usingRealData
        ? 'Using real Tiger Portal section data for $_plannedTerm. '
              'Times, professors, locations, seats, and section status '
              'come from the imported Tiger Portal dataset.'
        : 'Imported Spring 2027 sections could not be loaded. '
              'This schedule currently uses demonstration Spring 2027 sections. '
              'When Spring 2027 data is imported, Tiger Path will automatically '
              'switch to the real sections.';

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.72)),
            ),
          ),
        ],
      ),
    );
  }

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
