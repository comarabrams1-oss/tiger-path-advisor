import 'package:flutter/material.dart';
import '../data/test_student.dart';
import '../models/student_course.dart';

const _purple = Color(0xFF3A0B5C);
const _darkPurple = Color(0xFF26063E);
const _background = Color(0xFFF7F4FA);

class TranscriptScreen extends StatelessWidget {
  const TranscriptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inProgress = testStudent.courses
        .where(
          (course) => course.status == CourseStatus.inProgress,
        )
        .toList();

    final completed = testStudent.courses
        .where(
          (course) => course.status == CourseStatus.completed,
        )
        .toList();

    final completedByTerm = _groupByTerm(completed);

    final sortedTerms = completedByTerm.keys.toList()
      ..sort(
        (a, b) => _termSortValue(b).compareTo(
          _termSortValue(a),
        ),
      );

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Transcript'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(),
          const SizedBox(height: 22),
          _buildAcademicSummary(),
          const SizedBox(height: 28),
          if (inProgress.isNotEmpty) ...[
            _sectionTitle(
              icon: Icons.schedule,
              title: 'Current Semester',
              subtitle:
                  '${inProgress.length} courses currently in progress',
            ),
            const SizedBox(height: 14),
            _buildCurrentSemester(inProgress),
            const SizedBox(height: 30),
          ],
          _sectionTitle(
            icon: Icons.history,
            title: 'Academic History',
            subtitle:
                'Completed coursework organized by semester',
          ),
          const SizedBox(height: 14),
          ...List.generate(
            sortedTerms.length,
            (index) {
              final term = sortedTerms[index];
              final courses = completedByTerm[term] ?? [];

              return Padding(
                padding: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: _buildSemesterCard(
                  term: term,
                  courses: courses,
                  initiallyExpanded: index == 0,
                ),
              );
            },
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Academic Record',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: _darkPurple,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${testStudent.major} • ${testStudent.classification}',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          testStudent.institution,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _darkPurple,
            _purple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;

          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _summaryItem(
                        testStudent.earnedCredits
                            .toInt()
                            .toString(),
                        'Earned Credits',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryItem(
                        testStudent.inProgressCredits
                            .toInt()
                            .toString(),
                        'In Progress',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _summaryItem(
                  testStudent.gpa.toStringAsFixed(2),
                  'Cumulative GPA',
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _summaryItem(
                  testStudent.earnedCredits
                      .toInt()
                      .toString(),
                  'Earned Credits',
                ),
              ),
              _summaryDivider(),
              Expanded(
                child: _summaryItem(
                  testStudent.inProgressCredits
                      .toInt()
                      .toString(),
                  'In Progress',
                ),
              ),
              _summaryDivider(),
              Expanded(
                child: _summaryItem(
                  testStudent.gpa.toStringAsFixed(2),
                  'Cumulative GPA',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryItem(
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 45,
      margin: const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      color: Colors.white.withValues(alpha: 0.18),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: const Color(0xFFF0E8F5),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: _purple,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: _darkPurple,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSemester(
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
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
            color: const Color(0xFFFFF4DD),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: Colors.orange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    term,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _statusBadge(
                  'In Progress',
                  Colors.orange.shade800,
                ),
              ],
            ),
          ),
          ...courses.map(
            (course) => _courseRow(
              course,
              inProgress: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterCard({
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
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 8,
        ),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6EC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.check_circle_outline,
            color: Colors.green.shade700,
          ),
        ),
        title: Text(
          term,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _darkPurple,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${courses.length} completed ${courses.length == 1 ? 'course' : 'courses'}',
          ),
        ),
        children: courses
            .map(
              (course) => _courseRow(course),
            )
            .toList(),
      ),
    );
  }

  Widget _courseRow(
    StudentCourse course, {
    bool inProgress = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: inProgress
                  ? const Color(0xFFFFF4DD)
                  : const Color(0xFFEAF6EC),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              inProgress
                  ? Icons.schedule
                  : Icons.check,
              size: 21,
              color: inProgress
                  ? Colors.orange.shade800
                  : Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  course.courseCode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!inProgress) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (inProgress)
            _statusBadge(
              'Current',
              Colors.orange.shade800,
            )
          else
            _gradeBadge(course.grade),
        ],
      ),
    );
  }

  Widget _gradeBadge(String? grade) {
    if (grade == null || grade.isEmpty) {
      return const SizedBox();
    }

    return Container(
      constraints: const BoxConstraints(
        minWidth: 42,
      ),
      height: 34,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6EC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        grade,
        style: TextStyle(
          color: Colors.green.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _statusBadge(
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
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

  Map<String, List<StudentCourse>> _groupByTerm(
    List<StudentCourse> courses,
  ) {
    final grouped = <String, List<StudentCourse>>{};

    for (final course in courses) {
      grouped
          .putIfAbsent(
            course.term,
            () => [],
          )
          .add(course);
    }

    return grouped;
  }

  int _termSortValue(String term) {
    final match = RegExp(r'(\d{4})').firstMatch(term);

    if (match == null) {
      return 0;
    }

    final year = int.tryParse(
          match.group(1) ?? '',
        ) ??
        0;

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