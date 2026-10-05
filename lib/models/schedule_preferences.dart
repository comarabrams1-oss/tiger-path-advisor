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