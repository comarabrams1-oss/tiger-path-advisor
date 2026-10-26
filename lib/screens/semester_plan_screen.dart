import 'package:flutter/material.dart';

import '../data/program_registry.dart';
import '../data/test_student.dart';
import '../services/preferences_service.dart';
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
  late final _offerings = CourseSectionRepository.loadForTerm(
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
      return _buildPlan(context, snapshot.data, snapshot.hasError);
    },
  );

  Widget _buildPlan(
    BuildContext context,
    List<CourseSection>? sections,
    bool failed,
  ) {
    final preferences = PreferencesService.preferences;

    final maxCredits = preferences?.maxCredits ?? 15;

    final plan = SemesterPlanService().generatePlan(
      student: activeStudent,
      program: activeProgram,
      catalog: activeCatalog,
      maxCredits: maxCredits,
      sections: sections,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Semester Plan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${activeStudent.classification} semester plan',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'A draft of specific courses for Spring 2027. Current prerequisites must be completed successfully. Meeting times are checked in the next step.',
          ),
          if (activeStudent.major == 'Computer Engineering')
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(engineeringPreviewNotice),
            ),
          if (failed)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Offerings could not load. This academic draft has not been checked against section availability.',
              ),
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
                    'credits still available',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preferences == null
                        ? 'Using default maximum: 15 credits'
                        : 'Using your saved maximum: '
                              '${preferences.maxCredits} credits',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

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
                  'No courses or requirement slots could '
                  'currently be added to this plan.',
                ),
              ),
            ),

          const SizedBox(height: 20),

          if (plan.items.isNotEmpty)
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GeneratedScheduleScreen(plan: plan),
                  ),
                );
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
                'This is an academic plan, not a final registered '
                'schedule. Generate a class schedule to check imported '
                'Tiger Portal offerings, meeting times, seat snapshots, '
                'and time conflicts. Confirm registration with your advisor.',
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

                  Text(
                    isCourse
                        ? 'Recommended course'
                        : item.courseCode != null
                        ? 'Required course'
                        : 'Requirement slot',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),

                  if (item.projectedEligibility) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Projected eligibility after '
                      'current semester',
                    ),
                  ],

                  const SizedBox(height: 8),

                  Text(
                    item.reason,
                    style: Theme.of(context).textTheme.bodySmall,
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
