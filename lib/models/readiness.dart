enum ReadinessStatus {
  notStarted('Not started'),
  inProgress('In progress'),
  complete('Complete'),
  notApplicable('Not applicable');

  final String label;
  const ReadinessStatus(this.label);
}

class ReadinessMilestone {
  final String id;
  final String title;
  final bool optional;
  const ReadinessMilestone(this.id, this.title, {this.optional = false});
}

class ReadinessEntry {
  final ReadinessStatus status;
  final String evidence;
  final String due;
  const ReadinessEntry({
    this.status = ReadinessStatus.notStarted,
    this.evidence = '',
    this.due = '',
  });

  factory ReadinessEntry.fromJson(Map<String, dynamic> json) => ReadinessEntry(
    status: ReadinessStatus.values.byName(json['status'] as String),
    evidence: json['evidence'] as String? ?? '',
    due: json['due'] as String? ?? '',
  );

  Map<String, String> toJson() => {
    'status': status.name,
    'evidence': evidence,
    'due': due,
  };
}

const careerMilestones = [
  ReadinessMilestone('resume', 'Prepare a résumé'),
  ReadinessMilestone('portfolio', 'Build a portfolio'),
  ReadinessMilestone('languages', 'Programming languages'),
  ReadinessMilestone('projects', 'Technical projects'),
  ReadinessMilestone('robotics', 'Robotics participation', optional: true),
  ReadinessMilestone('internship', 'Internship or work experience'),
  ReadinessMilestone('cooperative', 'Cooperative education', optional: true),
  ReadinessMilestone(
    'certification',
    'Professional certifications',
    optional: true,
  ),
  ReadinessMilestone('research', 'Research experience'),
  ReadinessMilestone('interview', 'Interview preparation'),
];

const graduateMilestones = [
  ReadinessMilestone('graduate', 'Graduate program prerequisites'),
  ReadinessMilestone('research', 'Research experience'),
  ReadinessMilestone('mentorship', 'Faculty mentorship'),
  ReadinessMilestone('letters', 'Recommendation letters'),
  ReadinessMilestone('presentations', 'Research presentations', optional: true),
  ReadinessMilestone('publications', 'Publications', optional: true),
  ReadinessMilestone('gre', 'GRE preparation', optional: true),
  ReadinessMilestone('applications', 'Graduate-school applications'),
];

class ReadinessProfile {
  final Map<String, ReadinessEntry> entries;
  final double? targetGpa;
  final int interviewQuestionsReviewed;
  final int interviewQuestionCount;
  const ReadinessProfile({
    this.entries = const {},
    this.targetGpa,
    this.interviewQuestionsReviewed = 0,
    this.interviewQuestionCount = 0,
  });

  ReadinessEntry entry(ReadinessMilestone milestone) =>
      entries[milestone.id] ??
      ReadinessEntry(
        status: milestone.optional
            ? ReadinessStatus.notApplicable
            : ReadinessStatus.notStarted,
      );

  ReadinessStatus status(ReadinessMilestone milestone) {
    final manual = entry(milestone).status;
    if (milestone.id != 'interview' || manual == ReadinessStatus.complete) {
      return manual;
    }
    if (interviewQuestionsReviewed == 0) return manual;
    return interviewQuestionsReviewed == interviewQuestionCount
        ? ReadinessStatus.complete
        : ReadinessStatus.inProgress;
  }

  (int completed, int applicable) progress(
    List<ReadinessMilestone> milestones, {
    bool? meetsTargetGpa,
  }) {
    final statuses = milestones.map(status).toList();
    return (
      statuses.where((status) => status == ReadinessStatus.complete).length +
          (meetsTargetGpa == true ? 1 : 0),
      statuses
              .where((status) => status != ReadinessStatus.notApplicable)
              .length +
          (targetGpa != null && identical(milestones, graduateMilestones)
              ? 1
              : 0),
    );
  }

  Map<String, Object?> toAdvisorContext(bool? meetsTargetGpa) => {
    'career': [
      for (final item in careerMilestones)
        {'item': item.title, 'status': status(item).label},
    ],
    'graduateSchool': [
      for (final item in graduateMilestones)
        {'item': item.title, 'status': status(item).label},
    ],
    'graduateGpaTargetStatus': targetGpa == null
        ? 'No target recorded'
        : meetsTargetGpa == null
        ? 'GPA not available'
        : meetsTargetGpa
        ? 'Meets target'
        : 'Below target',
  };
}
