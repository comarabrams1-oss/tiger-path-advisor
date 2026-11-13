import 'package:flutter/material.dart';

import '../data/test_student.dart';
import '../data/program_registry.dart';
import '../models/student_course.dart';
import '../models/course_section.dart';
import '../services/course_section_repository.dart';
import '../services/course_priority_service.dart';
import '../services/course_eligibility_service.dart';
import '../screens/transcript_screen.dart';
import '../screens/course_recommendations_screen.dart';
import '../themes/app_theme.dart';

class AcademicWorkspace extends StatefulWidget {
  const AcademicWorkspace({super.key});
  @override
  State<AcademicWorkspace> createState() => _AcademicWorkspaceState();
}

class _AcademicWorkspaceState extends State<AcademicWorkspace> {
  int _tab = 0;
  List<CourseSection>? _sections;
  bool _sectionError = false;
  @override
  void initState() {
    super.initState();
    CourseSectionRepository.loadForTerm(CourseSectionRepository.spring2027Term)
        .then((sections) {
          if (mounted) setState(() => _sections = sections);
        })
        .catchError((Object _) {
          if (mounted) setState(() => _sectionError = true);
        });
  }

  Map<String, int>? get _openSections {
    final sections = _sections;
    if (sections == null) return null;
    final counts = <String, int>{};
    for (final section in sections.where((s) => s.isOpen && s.hasOpenSeats)) {
      counts.update(
        section.courseCode,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return counts;
  }

  void _open(BuildContext context, Widget screen) => Navigator.push(
    context,
    MaterialPageRoute(
      settings: RouteSettings(
        name: screen is TranscriptScreen
            ? 'TranscriptScreen'
            : 'CourseRecommendationsScreen',
      ),
      builder: (_) => screen,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final student = activeStudent;
    final catalog = catalogFor(student);
    final current = student.courses
        .where((course) => course.status == CourseStatus.inProgress)
        .toList();
    final titles = {for (final course in catalog) course.code: course.title};
    final openSections = _openSections;
    final recommended = CoursePriorityService()
        .rankCourses(student, programFor(student), catalog)
        .where(
          (item) => [
            EligibilityStatus.eligible,
            EligibilityStatus.eligibleAfterCurrentTerm,
          ].contains(item.eligibility.status),
        )
        .where(
          (item) =>
              openSections == null ||
              openSections.containsKey(item.course.code),
        )
        .take(3)
        .toList();

    final panels = [
      _panel(
        context,
        title: 'Fall 2026 courses',
        action: 'View transcript',
        onTap: () => _open(context, const TranscriptScreen()),
        children: [
          if (current.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No courses in progress.'),
            ),
          for (final course in current)
            _courseRow(
              context,
              title: titles[course.courseCode] ?? course.courseCode,
              detail: titles.containsKey(course.courseCode)
                  ? course.courseCode
                  : null,
            ),
        ],
      ),
      _panel(
        context,
        title: 'Spring 2027 recommendations',
        action: 'View recommendations',
        onTap: () => _open(context, const CourseRecommendationsScreen()),
        children: [
          if (openSections == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _sectionError
                    ? 'Section availability unavailable.'
                    : 'Checking section availability…',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          if (recommended.isEmpty && openSections != null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No eligible courses have open sections in this snapshot.',
              ),
            ),
          for (final item in recommended)
            _courseRow(
              context,
              title: item.course.title,
              detail: _offeringLabel(item.course.code, openSections),
              credits: item.course.credits,
              note:
                  item.eligibility.status ==
                      EligibilityStatus.eligibleAfterCurrentTerm
                  ? item.eligibility.reason ??
                        'After current prerequisites are completed.'
                  : null,
            ),
        ],
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (AppDesignTokens.of(context).design == AppDesign.sharp) ...[
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Current semester'),
                icon: Icon(Icons.today_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Next term'),
                icon: Icon(Icons.route_outlined),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (value) => setState(() => _tab = value.first),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
            ),
            child: KeyedSubtree(key: ValueKey(_tab), child: panels[_tab]),
          ),
        ] else
          LayoutBuilder(
            builder: (context, constraints) {
              final soft = AppDesignTokens.of(context).design == AppDesign.soft;
              if (constraints.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: soft ? 3 : 1, child: panels[soft ? 1 : 0]),
                    SizedBox(width: soft ? 24 : 18),
                    Expanded(flex: soft ? 2 : 1, child: panels[soft ? 0 : 1]),
                  ],
                );
              }
              return Column(
                children: [
                  panels[soft ? 1 : 0],
                  const SizedBox(height: 18),
                  panels[soft ? 0 : 1],
                ],
              );
            },
          ),
      ],
    );
  }

  String _offeringLabel(String code, Map<String, int>? sections) {
    final count = sections?[code];
    if (count == null) return code;
    return '$code · $count open ${count == 1 ? 'section' : 'sections'}';
  }

  Widget _panel(
    BuildContext context, {
    required String title,
    required String action,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppThemes.pageTitle(context, size: 23)),
        const SizedBox(height: 10),
        const Divider(height: 1),
        ...children,
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onTap,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(action, style: theme.textTheme.labelLarge),
          ),
        ),
      ],
    );
  }

  Widget _courseRow(
    BuildContext context, {
    required String title,
    String? detail,
    double? credits,
    String? note,
  }) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (detail != null) Text(detail, style: muted),
                    if (note != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(note, style: muted),
                      ),
                  ],
                ),
              ),
              if (credits != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2),
                  child: Text('${credits.toInt()} cr', style: muted),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
      ],
    );
  }
}
