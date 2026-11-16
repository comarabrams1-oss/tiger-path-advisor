import 'package:flutter/material.dart';

import '../data/course_descriptions.dart';
import '../data/program_registry.dart';
import '../data/test_student.dart';
import '../models/academic_term.dart';
import '../models/student.dart';
import '../models/student_course.dart';
import '../services/mock_auth_service.dart';
import '../services/preferences_service.dart';
import '../services/student_record_service.dart';
import '../themes/app_theme.dart';
import '../widgets/transcript_entry_dialog.dart';

class TranscriptScreen extends StatefulWidget {
  const TranscriptScreen({super.key});
  @override
  State<TranscriptScreen> createState() => _TranscriptScreenState();
}

class _TranscriptScreenState extends State<TranscriptScreen> {
  bool _saving = false;

  Future<void> _save(
    Student before,
    MockStudentSession session,
    List<StudentCourse> courses,
  ) async {
    if (_saving ||
        PreferencesService.profileId != session.profileId ||
        !identical(activeStudent, before)) {
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await StudentRecordService().save(
        session.profileId,
        demoStudentFor(session.email),
        courses,
      );
      if (PreferencesService.profileId == session.profileId &&
          identical(activeStudent, before)) {
        activeStudent = result;
        StudentRecordService.revision.value++;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Saved. Degree progress and course plans were recalculated.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the transcript. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit(
    MockStudentSession session, [
    StudentCourse? course,
  ]) async {
    final student = activeStudent;
    final remaining = [
      for (final entry in student.courses)
        if (!identical(entry, course)) entry,
    ];
    final edited = await showDialog<StudentCourse>(
      context: context,
      builder: (context) => TranscriptEntryDialog(
        attempt: course,
        currentTerm: StudentRecordService.currentTerm(student).label,
        knownHours: {
          for (final course in catalogFor(student)) course.code: course.credits,
        },
        otherAttempts: remaining,
        requirements: programFor(student).requirements,
      ),
    );
    if (!mounted || edited == null) return;
    await _save(student, session, [edited, ...remaining]);
  }

  Future<void> _grades(
    MockStudentSession session,
    String term,
    List<StudentCourse> courses,
  ) async {
    final student = activeStudent;
    final grades = await showDialog<Map<StudentCourse, String>>(
      context: context,
      builder: (context) => SemesterGradesDialog(term: term, courses: courses),
    );
    if (!mounted || grades == null) return;
    await _save(student, session, [
      for (final course in student.courses)
        if (grades[course] case final grade?)
          StudentCourse(
            courseCode: course.courseCode,
            term: course.term,
            status: CourseStatus.completed,
            grade: grade,
            creditHours: course.creditHours,
            isTransfer: course.isTransfer,
            approvedElectiveId: course.approvedElectiveId,
          )
        else
          course,
    ]);
  }

  Future<void> _remove(MockStudentSession session, StudentCourse course) async {
    final student = activeStudent;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${course.courseCode}?'),
        content: Text(
          'Remove the ${course.term} attempt from this planning record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove attempt'),
          ),
        ],
      ),
    );
    if (!mounted || remove != true) return;
    await _save(
      student,
      session,
      student.courses.where((a) => !identical(a, course)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = activeStudent;
    final session = MockSessionScope.maybeOf(context)?.session;
    final theme = Theme.of(context);
    final hours = StudentRecordService.creditHoursFor(student);
    final titles = {
      for (final item in courseDescriptions.entries) item.key: item.value.$1,
      for (final course in catalogFor(student)) course.code: course.title,
    };
    final attempts = <String, int>{};
    final current = <String, List<StudentCourse>>{};
    final history = <String, List<StudentCourse>>{};
    for (final course in student.courses) {
      attempts.update(
        course.courseCode,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
      final group = course.status == CourseStatus.inProgress
          ? current
          : history;
      (group[course.term] ??= []).add(course);
    }
    final metrics = StudentRecordService.metrics(student.courses, hours);
    final majorCodes = programFor(student).requirements
        .where((item) => item.category == 'Major')
        .expand((item) => item.courseCodes)
        .toSet();
    final majorGpa = StudentRecordService.metrics(
      student.courses.where((course) => majorCodes.contains(course.courseCode)),
      hours,
    ).gpa;
    List<String> sortedTerms(Map<String, List<StudentCourse>> terms) =>
        terms.keys.toList()..sort(
          (a, b) => (AcademicTerm.parse(b) ?? AcademicTerm.demoTerm).compareTo(
            AcademicTerm.parse(a) ?? AcademicTerm.demoTerm,
          ),
        );

    Widget row(StudentCourse course) {
      final inProgress = course.status == CourseStatus.inProgress;
      final passed = course.meetsMinimumGrade(null);
      final credit = course.creditHours ?? hours[course.courseCode];
      final title = titles[course.courseCode];
      return ListTile(
        leading: Icon(
          inProgress
              ? Icons.schedule
              : passed
              ? Icons.check_circle_outline
              : Icons.error_outline,
        ),
        title: Text(title ?? course.courseCode),
        subtitle: Text(
          [
            if (title != null) course.courseCode,
            if (credit != null) '${_credits(credit)} credits',
            if (course.transfer) 'Transfer',
            if (attempts[course.courseCode]! > 1) 'Repeat',
            if (course.approvedElectiveId != null) 'Approved elective',
            if (!inProgress && !passed) 'No credit earned',
            if (!inProgress && course.normalizedGrade != null)
              'Grade ${course.normalizedGrade}',
          ].join(' · '),
        ),
        trailing: session == null
            ? null
            : PopupMenuButton<String>(
                tooltip: 'Edit ${course.courseCode} attempt',
                enabled: !_saving,
                onSelected: (action) => action == 'edit'
                    ? _edit(session, course)
                    : _remove(session, course),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit attempt')),
                  PopupMenuItem(value: 'remove', child: Text('Remove attempt')),
                ],
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Transcript')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                student.major,
                textAlign: TextAlign.center,
                style: AppThemes.pageTitle(context),
              ),
              Text(student.classification, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,
                runSpacing: 14,
                children: [
                  for (final (label, value) in [
                    ('Earned credits', _credits(student.earnedCredits)),
                    ('In progress', _credits(student.inProgressCredits)),
                    ('Recorded transfer', _credits(metrics.transfer)),
                    ('Recorded attempts', '${student.courses.length}'),
                    (
                      'Cumulative GPA',
                      student.hasCalculatedGpa
                          ? student.gpa.toStringAsFixed(2)
                          : '—',
                    ),
                    ('Major GPA', majorGpa?.toStringAsFixed(2) ?? '—'),
                  ])
                    Column(
                      children: [
                        Text(value, style: theme.textTheme.titleLarge),
                        Text(label, style: theme.textTheme.bodySmall),
                      ],
                    ),
                ],
              ),
              if (session != null) ...[
                const SizedBox(height: 14),
                Center(
                  child: FilledButton.tonalIcon(
                    onPressed: _saving ? null : () => _edit(session),
                    icon: const Icon(Icons.add),
                    label: const Text('Add course'),
                  ),
                ),
                if (_saving) const LinearProgressIndicator(),
              ],
              const SizedBox(height: 22),
              if (current.isNotEmpty) ...[
                Text('In-progress courses', style: theme.textTheme.titleLarge),
                for (final term in sortedTerms(current)) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(term),
                    trailing: session == null
                        ? null
                        : TextButton(
                            onPressed: _saving
                                ? null
                                : () => _grades(session, term, current[term]!),
                            child: const Text('Enter final grades'),
                          ),
                  ),
                  for (final course in current[term]!) row(course),
                ],
                const SizedBox(height: 20),
              ],
              Text('Academic history', style: theme.textTheme.titleLarge),
              if (history.isEmpty) const Text('No finalized course attempts.'),
              for (final term in sortedTerms(history))
                ExpansionTile(
                  key: PageStorageKey(term),
                  tilePadding: EdgeInsets.zero,
                  title: Text(term),
                  subtitle: Text('${history[term]!.length} course attempts'),
                  children: [for (final course in history[term]!) row(course)],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _credits(double value) => value == value.roundToDouble()
      ? '${value.toInt()}'
      : value.toStringAsFixed(1);
}
