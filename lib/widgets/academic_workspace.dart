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

  int? _openSections(String code) => _sections
      ?.where(
        (section) =>
            section.courseCode == code &&
            section.isOpen &&
            section.hasOpenSeats,
      )
      .length;
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
    final current = activeStudent.courses
        .where((course) => course.status == CourseStatus.inProgress)
        .toList();
    final recommended = CoursePriorityService()
        .rankCourses(activeStudent, activeProgram, activeCatalog)
        .where(
          (item) => [
            EligibilityStatus.eligible,
            EligibilityStatus.eligibleAfterCurrentTerm,
          ].contains(item.eligibility.status),
        )
        .where(
          (item) =>
              _sections == null || (_openSections(item.course.code) ?? 0) > 0,
        )
        .take(3)
        .toList();

    final panels = [
      _panel(
        context,
        icon: Icons.today_outlined,
        eyebrow: 'FALL 2026',
        title: 'Your current semester',
        description: '${current.length} courses currently in progress',
        action: 'View transcript',
        onTap: () => _open(context, const TranscriptScreen()),
        children: [
          for (final course in current)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      course.courseCode,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    'In progress',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      _panel(
        context,
        icon: Icons.route_outlined,
        eyebrow: 'SPRING 2027',
        title: 'What could come next',
        description: _sections == null
            ? 'A shortlist based on your remaining degree requirements.'
            : 'Eligible degree courses with open Spring section snapshots.',
        action: 'Explore recommendations',
        onTap: () => _open(context, const CourseRecommendationsScreen()),
        children: [
          for (final item in recommended)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.eligibility.status == EligibilityStatus.eligible
                        ? Icons.check_circle_outline
                        : Icons.pending_outlined,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.course.code,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          item.course.title,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (_openSections(item.course.code) != null)
                          Text(
                            '${_openSections(item.course.code)} open ${_openSections(item.course.code) == 1 ? 'section' : 'sections'} in snapshot',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        if (item.eligibility.status ==
                            EligibilityStatus.eligibleAfterCurrentTerm)
                          const Text(
                            'After current prerequisites are completed',
                            style: TextStyle(fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.course.credits.toInt()} cr',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          Text(
            _sections != null
                ? 'Imported offerings · confirm seats and registration in Tiger Portal.'
                : _sectionError
                ? 'Section data unavailable · verify offerings in the builder.'
                : 'Checking imported Spring offerings…',
            style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your academic workspace',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.space_dashboard_outlined, color: colors.primary),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Current coursework, next steps, and the requirements behind your plan.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
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

  Widget _panel(
    BuildContext context, {
    required IconData icon,
    required String eyebrow,
    required String title,
    required String description,
    required String action,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(
          AppDesignTokens.of(context).design == AppDesign.soft ? 26 : 22,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  eyebrow,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 22),
            ...children,
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward, size: 17),
              label: Text(action),
            ),
          ],
        ),
      ),
    );
  }
}
