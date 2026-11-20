import 'package:flutter/material.dart';

import '../models/academic_term.dart';
import '../models/degree_program.dart';
import '../models/student_course.dart';

String transcriptCourseCode(String input) {
  final value = input.toUpperCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  return value.replaceFirstMapped(
    RegExp(r'^([A-Z]{2,6})[ -]?(\d{3}[A-Z]{0,3})$'),
    (match) => '${match[1]} ${match[2]}',
  );
}

class TranscriptEntryDialog extends StatefulWidget {
  final StudentCourse? attempt;
  final String? initialCourseCode;
  final String currentTerm;
  final Map<String, double> knownHours;
  final List<StudentCourse> otherAttempts;
  final List<DegreeRequirement> requirements;
  const TranscriptEntryDialog({
    super.key,
    this.attempt,
    this.initialCourseCode,
    required this.currentTerm,
    required this.knownHours,
    required this.otherAttempts,
    required this.requirements,
  });

  @override
  State<TranscriptEntryDialog> createState() => _TranscriptEntryDialogState();
}

class _TranscriptEntryDialogState extends State<TranscriptEntryDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(
    text: widget.attempt?.courseCode ?? widget.initialCourseCode,
  );
  late final _term = TextEditingController(
    text:
        AcademicTerm.parse(widget.attempt?.term ?? '')?.label ??
        widget.currentTerm,
  );
  late final _hours = TextEditingController(
    text:
        (widget.attempt?.creditHours ??
                widget.knownHours[widget.attempt?.courseCode ??
                    widget.initialCourseCode])
            ?.toString(),
  );
  late bool _transfer = widget.attempt?.transfer ?? false;
  late String _grade =
      widget.attempt?.normalizedGrade ??
      (widget.attempt?.status == CourseStatus.completed ? 'CR' : '');
  late String _elective = widget.attempt?.approvedElectiveId ?? '';
  String? _error;

  List<DegreeRequirement> get _electives =>
      widget.requirements.any(
        (r) => r.courseCodes.contains(transcriptCourseCode(_code.text)),
      )
      ? const []
      : widget.requirements
            .where((r) => r.type == RequirementType.elective)
            .toList();

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final code = transcriptCourseCode(_code.text);
    final term = AcademicTerm.parse(_term.text)!;
    if (widget.otherAttempts.any(
      (other) =>
          other.courseCode == code && AcademicTerm.parse(other.term) == term,
    )) {
      setState(
        () => _error =
            'That course already has an entry for ${term.label}. Edit that entry instead.',
      );
      return;
    }
    if (_elective.isNotEmpty &&
        widget.otherAttempts.any(
          (a) =>
              a.courseCode == code &&
              a.approvedElectiveId != null &&
              a.approvedElectiveId != _elective,
        )) {
      setState(
        () => _error =
            'That course is already applied to another elective requirement.',
      );
      return;
    }
    Navigator.of(context).pop(
      StudentCourse(
        courseCode: code,
        term:
            widget.attempt != null &&
                AcademicTerm.parse(widget.attempt!.term) == term &&
                widget.attempt!.transfer == _transfer
            ? widget.attempt!.term
            : term.label,
        status: _grade.isEmpty
            ? CourseStatus.inProgress
            : CourseStatus.completed,
        grade: _grade.isEmpty ? null : _grade,
        creditHours: double.parse(_hours.text.trim()),
        isTransfer: _transfer,
        approvedElectiveId: _elective.isEmpty ? null : _elective,
      ),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    _term.dispose();
    _hours.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final known = widget.knownHours[transcriptCourseCode(_code.text)];
    return AlertDialog(
      title: Text(
        widget.attempt == null
            ? 'Add course'
            : 'Edit ${widget.attempt!.courseCode}',
      ),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Course code',
                  hintText: 'CSC 233',
                ),
                onChanged: (value) => setState(() {
                  final credits =
                      widget.knownHours[transcriptCourseCode(value)];
                  if (credits != null) _hours.text = credits.toString();
                  _elective = '';
                }),
                validator: (value) =>
                    RegExp(r'^[A-Z]{2,8} \d{3}[A-Z0-9-]{0,4}$')
                        .hasMatch(transcriptCourseCode(value ?? ''))
                    ? null
                    : 'Enter a course code such as CSC 233.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _term,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Term',
                  hintText: 'Spring 2027',
                ),
                validator: (value) =>
                    RegExp(
                      r'^(Spring|Summer|Fall) 20\d{2}$',
                      caseSensitive: false,
                    ).hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter a term such as Fall 2026.',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hours,
                readOnly: known != null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Credit hours'),
                validator: (value) {
                  final hours = double.tryParse(value?.trim() ?? '');
                  return hours == null ||
                          !hours.isFinite ||
                          hours < 0 ||
                          hours > 18
                      ? 'Enter credit hours from 0 to 18.'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _grade,
                decoration: const InputDecoration(labelText: 'Grade'),
                isExpanded: true,
                items: [
                  if (!_transfer)
                    const DropdownMenuItem(
                      value: '',
                      child: Text('In progress'),
                    ),
                  for (final value in {
                    ...StudentCourse.recordGrades,
                    if (_grade.isNotEmpty) _grade,
                  })
                    DropdownMenuItem(
                      value: value,
                      child: Text(value == 'CR' ? 'CR · Credit' : value),
                    ),
                ],
                onChanged: (value) => setState(() => _grade = value ?? ''),
                validator: (value) =>
                    _transfer && !const {'A', 'B', 'C', 'CR'}.contains(value)
                    ? 'Accepted transfer credit requires A, B, C, or CR.'
                    : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _transfer,
                title: const Text('Accepted transfer credit'),
                subtitle: _transfer
                    ? const Text(
                        'Use the approved Benedict equivalent or an unassigned transfer code.',
                      )
                    : null,
                onChanged: (checked) => setState(() {
                  _transfer = checked ?? false;
                  if (_transfer && _grade.isEmpty) _grade = 'CR';
                }),
              ),
              if (_electives.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _elective,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Advisor-approved elective',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('No approved elective'),
                    ),
                    for (final requirement in _electives)
                      DropdownMenuItem(
                        value: requirement.id,
                        child: Text(requirement.title),
                      ),
                  ],
                  onChanged: (value) => setState(() => _elective = value ?? ''),
                ),
              if (_error case final error?)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save course')),
      ],
    );
  }
}

class SemesterGradesDialog extends StatefulWidget {
  final String term;
  final List<StudentCourse> courses;
  const SemesterGradesDialog({
    super.key,
    required this.term,
    required this.courses,
  });

  @override
  State<SemesterGradesDialog> createState() => _SemesterGradesDialogState();
}

class _SemesterGradesDialogState extends State<SemesterGradesDialog> {
  final _grades = <StudentCourse, String>{};

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Final grades for ${widget.term}'),
    scrollable: true,
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final course in widget.courses)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _grades[course] ?? '',
                isExpanded: true,
                decoration: InputDecoration(labelText: course.courseCode),
                items: [
                  const DropdownMenuItem(value: '', child: Text('In progress')),
                  for (final grade in StudentCourse.recordGrades)
                    DropdownMenuItem(value: grade, child: Text(grade)),
                ],
                onChanged: (value) => setState(() {
                  if (value == null || value.isEmpty) {
                    _grades.remove(course);
                  } else {
                    _grades[course] = value;
                  }
                }),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _grades.isEmpty
            ? null
            : () => Navigator.of(context).pop(_grades),
        child: const Text('Save grades'),
      ),
    ],
  );
}
