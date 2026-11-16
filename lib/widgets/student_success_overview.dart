import 'package:flutter/material.dart';

import '../data/test_student.dart';
import '../models/readiness.dart';
import '../models/student.dart';
import '../screens/graduation_path_screen.dart';
import '../screens/readiness_screen.dart';
import '../services/graduation_path_service.dart';
import '../services/preferences_service.dart';
import '../services/readiness_progress_service.dart';

class StudentSuccessOverview extends StatefulWidget {
  final String profileId;
  final Student student;
  const StudentSuccessOverview({
    super.key,
    required this.profileId,
    required this.student,
  });
  @override
  State<StudentSuccessOverview> createState() => _StudentSuccessOverviewState();
}

class _StudentSuccessOverviewState extends State<StudentSuccessOverview> {
  late Future<GraduationPath> _path;
  late Future<ReadinessProfile> _readiness;
  int get _cap => PreferencesService.preferences?.maxCredits ?? 15;

  @override
  void initState() {
    super.initState();
    _path = GraduationPathService().load(widget.student, maxCredits: _cap);
    _readiness = ReadinessProgressService(widget.profileId).loadProfile();
    ReadinessProgressService.revision.addListener(_refreshReadiness);
    PreferencesService.creditLimitRevision.addListener(_refreshPath);
  }

  @override
  void didUpdateWidget(StudentSuccessOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.student, oldWidget.student)) {
      _path = GraduationPathService().load(widget.student, maxCredits: _cap);
    }
    if (widget.profileId != oldWidget.profileId) {
      _readiness = ReadinessProgressService(widget.profileId).loadProfile();
    }
  }

  void _refreshReadiness() => setState(
    () => _readiness = ReadinessProgressService(widget.profileId).loadProfile(),
  );

  void _refreshPath() => setState(
    () =>
        _path = GraduationPathService().load(widget.student, maxCredits: _cap),
  );

  @override
  void dispose() {
    ReadinessProgressService.revision.removeListener(_refreshReadiness);
    PreferencesService.creditLimitRevision.removeListener(_refreshPath);
    super.dispose();
  }

  void _open({bool review = false}) => Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'GraduationPathScreen'),
      builder: (_) => GraduationPathScreen(
        student: activeStudent,
        profileId: widget.profileId,
        maxCredits: _cap,
        advisorReview: review,
      ),
    ),
  );

  String _percent((int, int) value) =>
      value.$2 == 0 ? '—' : '${(value.$1 / value.$2 * 100).round()}%';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Student progress',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        FutureBuilder<GraduationPath>(
          future: _path,
          builder: (context, snapshot) {
            final path = snapshot.data;
            final alerts =
                (path?.alerts.length ?? 0) + (path?.outstanding.length ?? 0);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.route_outlined),
              title: const Text('Graduation pathway'),
              subtitle: Text(
                path == null
                    ? snapshot.hasError
                          ? 'Estimate unavailable'
                          : 'Calculating pathway…'
                    : [
                        path.status,
                        if (alerts > 0) '$alerts academic alerts or open items',
                        if (path.nextPrerequisites.isNotEmpty)
                          '${path.nextPrerequisites.length} courses with missing prerequisites',
                      ].join(' · '),
              ),
              trailing: const Icon(Icons.arrow_forward),
              onTap: _open,
            );
          },
        ),
        FutureBuilder<ReadinessProfile>(
          future: _readiness,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final target = profile?.targetGpa;
            final meets = target != null && widget.student.hasCalculatedGpa
                ? widget.student.gpa >= target
                : null;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.work_outline),
              title: const Text('Career and graduate school'),
              subtitle: profile == null
                  ? (snapshot.hasError
                        ? const Text('Readiness progress unavailable')
                        : null)
                  : Text(
                      [
                        '${_percent(profile.progress(careerMilestones))} career · '
                            '${_percent(profile.progress(graduateMilestones, meetsTargetGpa: meets))} graduate school',
                        for (final (id, label) in [
                          ('research', 'Research'),
                          ('internship', 'Internship'),
                          ('certification', 'Certifications'),
                          ('portfolio', 'Portfolio'),
                        ])
                          '$label · ${profile.status(careerMilestones.firstWhere((milestone) => milestone.id == id)).label.toLowerCase()}',
                      ].join('\n'),
                    ),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: 'ReadinessScreen'),
                  builder: (_) => ReadinessScreen(profileId: widget.profileId),
                ),
              ),
            );
          },
        ),
        Center(
          child: TextButton.icon(
            onPressed: () => _open(review: true),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Review with advisor'),
          ),
        ),
      ],
    );
  }
}
