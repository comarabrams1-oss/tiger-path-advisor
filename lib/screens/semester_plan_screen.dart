import 'package:flutter/material.dart';

import '../widgets/info_tip.dart';

import '../data/program_registry.dart';
import '../data/test_student.dart';
import '../services/preferences_service.dart';
import '../services/schedule_draft_service.dart';
import '../services/semester_plan_service.dart';
import 'generated_schedule_screen.dart';
import '../models/course_section.dart';
import '../services/course_section_repository.dart';

class SemesterPlanScreen extends StatefulWidget {
  const SemesterPlanScreen({super.key});
  @override
  State<SemesterPlanScreen> createState() => _SemesterPlanScreenState();
}

class _SemesterPlanScreenState extends State<SemesterPlanScreen> {
  late var _offerings = _loadOfferings();

  Future<List<CourseSection>> _loadOfferings() =>
      CourseSectionRepository.loadForTerm(
        CourseSectionRepository.spring2027Term,
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<CourseSection>>(
    future: _offerings,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Scaffold(
          appBar: AppBar(title: const Text('Semester Plan')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      final sections = snapshot.data;
      if (sections == null || sections.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: const Text('Semester Plan')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Spring 2027 sections could not load.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    final offerings = _loadOfferings();
                    setState(() {
                      _offerings = offerings;
                    });
                  },
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      }
      return _buildPlan(context, sections);
    },
  );

  Widget _buildPlan(BuildContext context, List<CourseSection> sections) {
    final preferences = PreferencesService.preferences;
    final maxCredits = preferences?.maxCredits ?? 15;
    final previousDraft = ScheduleDraftService.current;
    final pins = previousDraft?.sectionPreferences ?? const <String, String>{};
    final previouslyScheduled = previousDraft?.schedule.scheduled ?? const [];
    final pinnedCourses = [
      for (final item in previouslyScheduled)
        if (pins[item.section.courseCode] == item.section.sectionNumber)
          item.section.courseCode,
    ];

    final plan = SemesterPlanService().generatePlan(
      student: activeStudent,
      program: activeProgram,
      catalog: activeCatalog,
      maxCredits: maxCredits,
      sections: previousDraft == null
          ? sections
          : ScheduleDraftService.permittedSections(
              sections,
              excludedCourses: previousDraft.excludedCourses,
              excludedSections: previousDraft.excludedSections,
              sectionPreferences: pins,
            ),
      publishedSections: sections,
      preferences: preferences,
      preferredSections: pins,
      preferredCourses: [
        for (final item in previouslyScheduled) item.section.courseCode,
      ],
      priorityCourseCodes: pinnedCourses,
    );
    final plannedCodes = plan.items.map((item) => item.courseCode).toSet();
    final omittedPins = pinnedCourses.where(
      (code) => !plannedCodes.contains(code),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Semester Plan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            textAlign: TextAlign.center,
            '${activeStudent.classification} semester plan',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            textAlign: TextAlign.center,
            'Spring 2027 · Check meeting times in the next step.',
          ),
          if (activeStudent.major == 'Computer Engineering')
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(engineeringPreviewNotice),
            ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Plan Summary',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${plan.totalCredits.toInt()} course credits · ${plan.maxCredits}-credit limit',
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: plan.maxCredits == 0
                        ? 0
                        : (plan.totalCredits / plan.maxCredits).clamp(0.0, 1.0),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${plan.remainingCreditCapacity.toInt()} '
                    'credits below the limit',
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          if (plan.shortfallReason != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(plan.shortfallReason!),
            ),
          if (omittedPins.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Saved sections that did not fit: ${omittedPins.join(', ')}.',
              ),
            ),
          ...plan.items.map((item) => buildPlanItem(context, item)),

          if (plan.reviewItems.isNotEmpty)
            Card(
              child: ExpansionTile(
                initiallyExpanded: false,
                title: const Text('Future requirements & advisor review'),
                subtitle: const Text(
                  'Outstanding requirements outside this semester. These do not count toward planned credits.',
                ),
                children: [
                  for (final item in plan.reviewItems)
                    buildPlanItem(context, item),
                ],
              ),
            ),

          if (plan.items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No eligible Spring 2027 sections fit this plan. Check Future requirements & advisor review for the remaining courses and their availability.',
                ),
              ),
            ),

          const SizedBox(height: 20),

          if (plan.items.isNotEmpty)
            FilledButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    settings: const RouteSettings(
                      name: 'GeneratedScheduleScreen',
                    ),
                    builder: (_) => GeneratedScheduleScreen(
                      plan: plan,
                      previousDraft: previousDraft,
                    ),
                  ),
                );
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.calendar_month),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Generate Class Schedule'),
              ),
            ),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Planning draft · confirm registration with your advisor.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPlanItem(BuildContext context, SemesterPlanItem item) {
    final isCourse = item.type == SemesterPlanItemType.course;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isCourse ? Icons.menu_book_outlined : Icons.extension_outlined,
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.courseCode != null) ...[
                    Text(
                      item.courseCode!,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],

                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: item.courseCode == null ? 17 : 15,
                      fontWeight: item.courseCode == null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(item.category),

                  const SizedBox(height: 8),

                  if (item.projectedEligibility) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.priority?.eligibility.reason ??
                          'Only after current prerequisites are passed',
                    ),
                  ],

                  const SizedBox(height: 8),

                  InfoTip(
                    label: 'Why ${item.courseCode ?? item.title} is suggested',
                    message: item.reason,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Text(
              '${item.credits.toInt()} cr',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
