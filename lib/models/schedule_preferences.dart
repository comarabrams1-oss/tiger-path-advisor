class SchedulePreferences {
  final String preferredTime;
  final List<String> preferredDays;
  final List<String> avoidedDays;
  final List<String> preferredProfessors;
  final int maxCredits;
  final bool avoidEarlyClasses;
  final bool avoidLateClasses;
  final bool minimizeGaps;

  const SchedulePreferences({
    required this.preferredTime,
    required this.preferredDays,
    required this.avoidedDays,
    required this.preferredProfessors,
    required this.maxCredits,
    required this.avoidEarlyClasses,
    required this.avoidLateClasses,
    required this.minimizeGaps,
  });

  factory SchedulePreferences.fromJson(Map<String, dynamic> json) =>
      SchedulePreferences(
        preferredTime: json['preferredTime'] as String,
        preferredDays: List<String>.from(json['preferredDays'] as List),
        avoidedDays: List<String>.from(json['avoidedDays'] as List),
        preferredProfessors: List<String>.from(
          json['preferredProfessors'] as List,
        ),
        maxCredits: json['maxCredits'] as int,
        avoidEarlyClasses: json['avoidEarlyClasses'] as bool,
        avoidLateClasses: json['avoidLateClasses'] as bool,
        minimizeGaps: json['minimizeGaps'] as bool,
      );

  Map<String, dynamic> toJson() {
    return {
      'preferredTime': preferredTime,
      'preferredDays': preferredDays,
      'avoidedDays': avoidedDays,
      'preferredProfessors': preferredProfessors,
      'maxCredits': maxCredits,
      'avoidEarlyClasses': avoidEarlyClasses,
      'avoidLateClasses': avoidLateClasses,
      'minimizeGaps': minimizeGaps,
    };
  }
}
