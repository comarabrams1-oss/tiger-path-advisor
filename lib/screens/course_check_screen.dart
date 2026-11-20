import 'package:flutter/material.dart';

import '../data/program_registry.dart';
import '../data/test_student.dart';
import '../models/course.dart';
import '../models/student_course.dart';
import '../services/course_eligibility_service.dart';
import '../services/mock_auth_service.dart';
import '../services/student_record_service.dart';
import '../widgets/info_tip.dart';
import 'transcript_screen.dart';

class CourseCheckScreen extends StatefulWidget {
  final String? initialCourseCode;
  const CourseCheckScreen({super.key, this.initialCourseCode});

  @override
  State<CourseCheckScreen> createState() => _CourseCheckScreenState();
}

class _CourseCheckScreenState extends State<CourseCheckScreen> {
  late String? _selectedCode = widget.initialCourseCode;
  final _search = TextEditingController();

  bool _matchesCourse(DropdownMenuEntry<String> entry, String filter) {
    final query = filter.trim().toLowerCase();
    return entry.label.toLowerCase().contains(query) ||
        entry.value
            .replaceAll(' ', '')
            .toLowerCase()
            .contains(query.replaceAll(' ', ''));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check prerequisites'),
        actions: const [
          InfoTip(
            label: 'About prerequisite checks',
            message:
                'Uses your saved planning record and mapped program rules. '
                'Placement and permissions need college confirmation. '
                'Check section availability in Schedule Builder.',
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: StudentRecordService.revision,
        builder: (context, _) {
          final catalog = catalogFor(activeStudent).toList()
            ..sort((a, b) => a.code.compareTo(b.code));
          final selected = catalog
              .where((course) => course.code == _selectedCode)
              .firstOrNull;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '${activeStudent.major} · Catalog ${activeStudent.catalogYear}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) => DropdownMenu<String>(
                      width: constraints.maxWidth,
                      expandedInsets: EdgeInsets.zero,
                      controller: _search,
                      initialSelection: selected?.code,
                      label: const Text('Course'),
                      hintText: 'Search by course code or name',
                      textInputAction: TextInputAction.search,
                      // Extra caret padding scrolls the list and closes the menu.
                      scrollPadding: EdgeInsets.zero,
                      enableFilter: true,
                      requestFocusOnTap: true,
                      menuHeight: 280,
                      filterCallback: (entries, filter) {
                        return entries
                            .where((entry) => _matchesCourse(entry, filter))
                            .toList();
                      },
                      searchCallback: (entries, query) {
                        if (query.trim().isEmpty) return null;
                        final index = entries.indexWhere(
                          (entry) => _matchesCourse(entry, query),
                        );
                        return index < 0 ? null : index;
                      },
                      dropdownMenuEntries: [
                        for (final course in catalog)
                          DropdownMenuEntry(
                            value: course.code,
                            label: '${course.code} · ${course.title}',
                          ),
                      ],
                      onSelected: (code) {
                        setState(() => _selectedCode = code);
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (selected == null)
                    const Text(
                      'Choose a course to check it against your record.',
                      textAlign: TextAlign.center,
                    )
                  else
                    ..._courseDetails(context, selected, catalog),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _courseDetails(
    BuildContext context,
    Course course,
    List<Course> catalog,
  ) {
    final theme = Theme.of(context);
    final result = CourseEligibilityService().checkCourse(
      activeStudent,
      course,
    );
    final (label, icon) = switch (result.status) {
      EligibilityStatus.eligible => (
        'Prerequisites met',
        Icons.check_circle_outline,
      ),
      EligibilityStatus.eligibleAfterCurrentTerm => (
        'Pass current courses first',
        Icons.schedule,
      ),
      EligibilityStatus.requiresPermission => (
        'Permission required',
        Icons.assignment_ind_outlined,
      ),
      EligibilityStatus.blocked => ('Not eligible yet', Icons.lock_outline),
    };
    String courseLabel(String code) {
      final title = catalog
          .where((item) => item.code == code)
          .firstOrNull
          ?.title;
      return title == null ? code : '$code · $title';
    }

    String prerequisiteLabel(String code) {
      final minimum = course.minimumPrerequisiteGrades[code];
      return '${courseLabel(code)}${minimum == null ? '' : ' (minimum $minimum)'}';
    }

    final attempts = activeStudent.courses
        .where((attempt) => attempt.courseCode == course.code)
        .toList();
    final session = MockSessionScope.maybeOf(context)?.session;
    return [
      Text(
        course.code,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium,
      ),
      Text(
        course.title,
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall,
      ),
      const SizedBox(height: 6),
      Text(
        '${course.credits.toStringAsFixed(course.credits % 1 == 0 ? 0 : 1)} credits · ${course.category}',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                result.status == EligibilityStatus.eligible &&
                        course.prerequisiteGroups.isEmpty
                    ? 'No prerequisite courses are listed in this program mapping.'
                    : result.reason ?? 'Check the course requirements below.',
              ),
              if (result.missingPrerequisites.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Still needed', style: theme.textTheme.titleSmall),
                for (final group in result.missingPrerequisites)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      group.split(' OR ').map(prerequisiteLabel).join('\nOR '),
                    ),
                  ),
              ],
              if (result.requiredCompanions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Take together', style: theme.textTheme.titleSmall),
                for (final code in result.requiredCompanions)
                  Text(courseLabel(code)),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          key: ValueKey(course.code),
          title: const Text('Course requirements'),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (course.prerequisiteGroups.isEmpty)
              const Text('No prerequisite courses listed.'),
            for (final group in course.prerequisiteGroups)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(group.map(prerequisiteLabel).join('\nOR ')),
              ),
            if (course.requiresPassingPrerequisites)
              const Text('A passing prerequisite grade is required.'),
            if (course.minimumClassStanding != null)
              Text('Requires ${course.minimumClassStanding} standing.'),
            for (final code in course.corequisiteCodes)
              Text('Companion course: ${courseLabel(code)}'),
            if (course.allowsPlacementExemption)
              Text(
                activeStudent.verifiedPlacementCourses.contains(course.code)
                    ? 'Verified placement exemption recorded.'
                    : 'College placement exemption may apply; none is recorded.',
              ),
            if (course.allowsInstructorPermission)
              const Text('Instructor permission may be allowed.'),
            if (course.requiresAdvisorApproval)
              const Text('Advisor clearance must be verified.'),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text(
        'Your record',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      if (attempts.isEmpty)
        const Text('No attempt recorded.', textAlign: TextAlign.center),
      for (final attempt in attempts)
        Text(
          '${attempt.term} · ${attempt.status == CourseStatus.inProgress ? 'In progress' : 'Grade ${attempt.grade ?? 'not recorded'}'}${attempt.transfer ? ' · Transfer' : ''}',
          textAlign: TextAlign.center,
        ),
      const SizedBox(height: 12),
      Center(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text('Record or edit result'),
          onPressed: session == null
              ? null
              : () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(name: 'TranscriptScreen'),
                    builder: (_) =>
                        TranscriptScreen(initialCourseCode: course.code),
                  ),
                ),
        ),
      ),
    ];
  }
}
