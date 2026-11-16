import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/program_registry.dart';
import '../models/academic_term.dart';
import '../models/readiness.dart';
import '../models/student.dart';
import '../services/degree_audit_service.dart';
import '../services/graduation_path_service.dart';
import '../services/readiness_progress_service.dart';
import '../services/student_record_service.dart';
import '../themes/app_theme.dart';
import '../widgets/info_tip.dart';
import '../widgets/readiness_checklist.dart';

class GraduationPathScreen extends StatefulWidget {
  final Student student;
  final String profileId;
  final int maxCredits;
  final bool advisorReview;
  const GraduationPathScreen({
    super.key,
    required this.student,
    required this.profileId,
    required this.maxCredits,
    this.advisorReview = false,
  });

  @override
  State<GraduationPathScreen> createState() => _GraduationPathScreenState();
}

class _GraduationPathScreenState extends State<GraduationPathScreen> {
  late final _path = GraduationPathService().load(
    widget.student,
    maxCredits: widget.maxCredits,
  );
  late final _readiness = widget.advisorReview
      ? ReadinessProgressService(widget.profileId).loadProfile()
      : null;
  AcademicTerm? _target;

  @override
  void initState() {
    super.initState();
    if (!widget.advisorReview) _loadTarget();
  }

  Future<void> _loadTarget() async {
    try {
      final target = await StudentRecordService().loadTarget(widget.profileId);
      if (mounted && _target == null) setState(() => _target = target);
    } catch (_) {
      // A target can still be compared during this visit.
    }
  }

  Future<void> _saveTarget(AcademicTerm? target) async {
    if (target == null) return;
    setState(() => _target = target);
    try {
      await StudentRecordService().saveTarget(widget.profileId, target);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The graduation target could only be kept for this visit.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.advisorReview ? 'Advisor review' : 'Graduation pathway',
      ),
      actions: const [
        InfoTip(
          label: 'About projections',
          message: 'The pathway assumes courses are passed with the required grades and uses published sections where available. Later terms are estimates. Confirm graduation clearance and expected offerings with your advisor.',
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: FutureBuilder<GraduationPath>(
          future: _path,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Could not calculate a graduation pathway.'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _report(context, snapshot.data!);
          },
        ),
      ),
    ),
  );

  Widget _report(BuildContext context, GraduationPath path) {
    final theme = Theme.of(context);
    final student = widget.student;
    final program = programFor(student);
    final audit = DegreeAuditService().auditProgram(student, program);
    final completed = audit.where(
      (a) => a.status == RequirementStatus.completed,
    );
    final majorCodes = program.requirements
        .where((r) => r.category == 'Major')
        .expand((r) => r.courseCodes)
        .toSet();
    final majorGpa = StudentRecordService.metrics(
      student.courses.where((course) => majorCodes.contains(course.courseCode)),
      StudentRecordService.creditHoursFor(student),
    ).gpa;
    final reviews = <String>[...path.alerts, ...path.outstanding];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text(
          path.status,
          textAlign: TextAlign.center,
          style: AppThemes.pageTitle(context),
        ),
        const SizedBox(height: 6),
        Text(
          path.requirementsMet
              ? 'Confirm graduation clearance with your advisor.'
              : path.estimatedTerm != null
              ? 'Estimated completion · ${path.terms.length} more ${path.terms.length == 1 ? 'semester' : 'semesters'}'
              : 'At least ${path.minimumTermsByCredit} more ${path.minimumTermsByCredit == 1 ? 'semester' : 'semesters'} by credits alone',
          textAlign: TextAlign.center,
        ),
        if (path.assumesCurrentGrades || path.needsElectiveApproval)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              [
                if (path.assumesCurrentGrades) 'Assumes current courses are passed with the required grades.',
                if (path.needsElectiveApproval)
                  'Elective and credit blocks need advisor approval.',
              ].join(' '),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 14),
        Text(
          '${student.classification} · ${student.major}\n'
          '${student.earnedCredits.toStringAsFixed(0)} of ${student.requiredCredits.toStringAsFixed(0)} credits · '
          '${student.progressPercentage.clamp(0, 100).round()}% · ${completed.length} of ${audit.length} mapped requirements met',
          textAlign: TextAlign.center,
        ),
        if (widget.advisorReview) ...[
          Text(
            'Cumulative GPA ${student.hasCalculatedGpa ? student.gpa.toStringAsFixed(2) : '—'} · Major GPA ${majorGpa?.toStringAsFixed(2) ?? '—'}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          for (final status in RequirementStatus.values)
            ExpansionTile(
              title: Text(switch (status) {
                RequirementStatus.completed => 'Completed requirements',
                RequirementStatus.inProgress => 'Requirements in progress',
                RequirementStatus.remaining => 'Remaining requirements',
              }),
              children: [
                for (final item in audit.where((a) => a.status == status))
                  ListTile(
                    title: Text(item.requirement.title),
                    subtitle: Text(item.requirement.category),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          FutureBuilder<ReadinessProfile>(
            future: _readiness,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Readiness progress could not be loaded.');
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ReadinessChecklist(profile: snapshot.data!, student: student),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy advisor summary'),
                      onPressed: () =>
                          _copySummary(path, snapshot.data!, audit, majorGpa),
                    ),
                  ),
                ],
              );
            },
          ),
        ] else if (!path.requirementsMet) ...[
          const SizedBox(height: 12),
          _targetComparison(path),
        ],
        if (reviews.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Academic alerts and advisor review',
            style: theme.textTheme.titleLarge,
          ),
          for (final alert in reviews)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.info_outline, size: 20),
              title: Text(alert),
            ),
        ],
        if (path.nextPrerequisites.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Missing prerequisites for ${path.nextTerm.label}'),
            subtitle: Text(
              '${path.nextPrerequisites.length} courses to review',
            ),
            children: [
              for (final requirement in path.nextPrerequisites)
                ListTile(title: Text(requirement), dense: true),
            ],
          ),
        if (path.terms.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Semester recommendations', style: theme.textTheme.titleLarge),
          for (final term in path.terms) _termTile(term),
        ],
      ],
    );
  }

  Widget _targetComparison(GraduationPath path) {
    final terms = [StudentRecordService.currentTerm(widget.student)];
    for (var i = 0; i < GraduationPathService.horizon; i++) {
      terms.add(terms.last.next);
    }
    final target = _target;
    if (target != null && !terms.contains(target)) {
      terms.add(target);
      terms.sort();
    }
    var termsBeforeTarget = 0;
    if (target != null) {
      for (
        var term = path.nextTerm;
        term.compareTo(target) <= 0;
        term = term.next
      ) {
        termsBeforeTarget++;
      }
    }
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Compare a graduation target'),
      subtitle: target == null ? null : Text(target.label),
      children: [
        DropdownButtonFormField<AcademicTerm>(
          initialValue: target,
          decoration: const InputDecoration(labelText: 'Target term'),
          items: [
            for (final term in terms)
              DropdownMenuItem(value: term, child: Text(term.label)),
          ],
          onChanged: _saveTarget,
        ),
        if (target != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              target.compareTo(
                        StudentRecordService.currentTerm(widget.student),
                      ) <
                      0
                  ? 'This target term has passed. Choose a new term to compare.'
                  : termsBeforeTarget < path.minimumTermsByCredit
                  ? 'The remaining credits exceed the available semesters at ${widget.maxCredits} credits per term.'
                  : path.estimatedTerm == null
                  ? 'The credit total may fit. Resolve the open requirements and prerequisites below before relying on this date.'
                  : path.estimatedTerm!.compareTo(target) > 0
                  ? 'The recommended sequence completes in ${path.estimatedTerm!.label}, after your target.'
                  : 'The current projection fits this target if the planned courses are available and passed.',
            ),
          ),
      ],
    );
  }

  Widget _termTile(PathwayTerm term) => ExpansionTile(
    key: PageStorageKey(term.term.label),
    tilePadding: EdgeInsets.zero,
    title: Text(term.term.label),
    subtitle: Text(
      '${term.credits.toStringAsFixed(0)} projected credits · ${term.hasSnapshot ? 'Imported sections' : 'Confirm future availability'}',
    ),
    children: [
      if (term.courses.isEmpty && term.reviewCredits == 0)
        const ListTile(title: Text('No eligible courses fit this term.')),
      for (final course in term.courses)
        ListTile(
          title: Text('${course.courseCode} · ${course.title}'),
          subtitle: Text(course.reason),
        ),
      if (term.reviewCredits > 0)
        ListTile(
          title: Text(
            '${term.reviewCredits.toStringAsFixed(0)} credits to confirm with your advisor',
          ),
          subtitle: const Text(
            'Choose courses that count toward the remaining credit requirements.',
          ),
        ),
    ],
  );

  Future<void> _copySummary(
    GraduationPath path,
    ReadinessProfile readiness,
    List<DegreeAuditItem> audit,
    double? majorGpa,
  ) async {
    final student = widget.student;
    final report = [
      'Tiger Path Advisor planning summary',
      '${student.major} · ${student.classification}',
      '${student.earnedCredits} of ${student.requiredCredits} credits earned',
      'Cumulative GPA ${student.hasCalculatedGpa ? student.gpa.toStringAsFixed(2) : 'unavailable'} · Major GPA ${majorGpa?.toStringAsFixed(2) ?? 'unavailable'}',
      'Graduation pathway · ${path.status}',
      if (path.assumesCurrentGrades)
        'Assumes current courses are passed with the required grades.',
      if (path.needsElectiveApproval)
        'Elective and credit blocks need advisor approval.',
      '',
      for (final item in audit)
        '${item.requirement.title} · ${item.status.name}',
      '',
      'Next semester · ${path.nextTerm.label}',
      for (final item in path.terms.firstOrNull?.courses ?? [])
        '${item.courseCode} · ${item.title}',
      '',
      'Advisor review',
      ...path.alerts,
      ...path.outstanding,
      '',
      'Career readiness',
      for (final milestone in careerMilestones)
        '${milestone.title} · ${readiness.status(milestone).label}',
      '',
      'Graduate-school readiness',
      for (final milestone in graduateMilestones)
        '${milestone.title} · ${readiness.status(milestone).label}'
            '${readiness.entry(milestone).due.isEmpty ? '' : ' · Due ${readiness.entry(milestone).due}'}',
    ].join('\n');
    try {
      await Clipboard.setData(ClipboardData(text: report));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Advisor summary copied.')),
        );
      }
    } catch (_) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Advisor summary'),
            content: SingleChildScrollView(child: SelectableText(report)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }
}
