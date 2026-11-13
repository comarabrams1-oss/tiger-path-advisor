import 'package:flutter/material.dart';

import '../data/test_student.dart';
import '../models/student_course.dart';
import '../themes/app_theme.dart';

class TranscriptScreen extends StatelessWidget {
  const TranscriptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inProgress = activeStudent.courses
        .where((course) => course.status == CourseStatus.inProgress)
        .toList();

    final completed = activeStudent.courses
        .where((course) => course.status == CourseStatus.completed)
        .toList();

    final completedByTerm = _groupByTerm(completed);

    final sortedTerms = completedByTerm.keys.toList()
      ..sort((a, b) => _termSortValue(b).compareTo(_termSortValue(a)));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Transcript')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(context),
          const SizedBox(height: 22),
          _buildAcademicSummary(context),
          const SizedBox(height: 28),
          if (inProgress.isNotEmpty) ...[
            Text(
              'Current semester',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            _buildCurrentSemester(context, inProgress),
            const SizedBox(height: 30),
          ],
          Text(
            'Academic history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          ...List.generate(sortedTerms.length, (index) {
            final term = sortedTerms[index];
            final courses = completedByTerm[term] ?? [];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSemesterCard(
                context,
                term: term,
                courses: courses,
                initiallyExpanded: false,
              ),
            );
          }),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(activeStudent.major, style: AppThemes.pageTitle(context)),
      const SizedBox(height: 4),
      Text(activeStudent.classification),
    ],
  );

  Widget _buildAcademicSummary(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppDesignTokens.of(context).radius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            for (final (label, value) in [
              (
                'Earned credits',
                activeStudent.earnedCredits.toInt().toString(),
              ),
              (
                'In progress',
                activeStudent.inProgressCredits.toInt().toString(),
              ),
              ('Cumulative GPA', activeStudent.gpa.toStringAsFixed(2)),
            ])
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: theme.textTheme.titleLarge),
                  Text(label, style: theme.textTheme.bodySmall),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSemester(
    BuildContext context,
    List<StudentCourse> courses,
  ) {
    final term = courses.first.term;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    term,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                _statusBadge(
                  context,
                  'In Progress',
                  Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ],
            ),
          ),
          ...courses.map(
            (course) => _courseRow(context, course, inProgress: true),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterCard(
    BuildContext context, {
    required String term,
    required List<StudentCourse> courses,
    required bool initiallyExpanded,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          term,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${courses.length} completed ${courses.length == 1 ? 'course' : 'courses'}',
          ),
        ),
        children: courses.map((course) => _courseRow(context, course)).toList(),
      ),
    );
  }

  Widget _courseRow(
    BuildContext context,
    StudentCourse course, {
    bool inProgress = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: inProgress
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              inProgress ? Icons.schedule : Icons.check,
              size: 21,
              color: inProgress
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.courseCode,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (!inProgress) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Completed',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (inProgress)
            _statusBadge(
              context,
              'Current',
              Theme.of(context).colorScheme.onSecondaryContainer,
            )
          else
            _gradeBadge(context, course.grade),
        ],
      ),
    );
  }

  Widget _gradeBadge(BuildContext context, String? grade) {
    if (grade == null || grade.isEmpty) {
      return const SizedBox();
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 42),
      height: 34,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        grade,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Map<String, List<StudentCourse>> _groupByTerm(List<StudentCourse> courses) {
    final grouped = <String, List<StudentCourse>>{};

    for (final course in courses) {
      grouped.putIfAbsent(course.term, () => []).add(course);
    }

    return grouped;
  }

  int _termSortValue(String term) {
    final match = RegExp(r'(\d{4})').firstMatch(term);

    if (match == null) {
      return 0;
    }

    final year = int.tryParse(match.group(1) ?? '') ?? 0;

    var semester = 0;

    final lower = term.toLowerCase();

    if (lower.contains('spring')) {
      semester = 1;
    } else if (lower.contains('summer')) {
      semester = 2;
    } else if (lower.contains('fall')) {
      semester = 3;
    }

    return (year * 10) + semester;
  }
}
