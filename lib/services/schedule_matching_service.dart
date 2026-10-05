import '../models/course_section.dart';
import '../models/instructor.dart';
import '../models/schedule_preferences.dart';

class SectionMatch {
  final CourseSection section;
  final Instructor? instructor;
  final int score;
  final List<String> reasons;

  const SectionMatch({
    required this.section,
    required this.instructor,
    required this.score,
    required this.reasons,
  });
}

class ScheduleMatchingService {
  List<SectionMatch> rankSections({
    required List<CourseSection> sections,
    required List<Instructor> instructors,
    required SchedulePreferences preferences,
  }) {
    final matches = sections.map((section) {
      final instructor = _findInstructor(
        section.instructorId,
        instructors,
      );

      var score = 0;
      final reasons = <String>[];

      final timeScore = _scorePreferredTime(
        section,
        preferences.preferredTime,
      );

      score += timeScore;

      if (timeScore > 0) {
        reasons.add(
          'Matches preferred ${preferences.preferredTime.toLowerCase()} time',
        );
      }

      final preferredDayMatches = section.days
          .where(
            preferences.preferredDays.contains,
          )
          .length;

      if (preferredDayMatches > 0) {
        final points = preferredDayMatches * 3;
        score += points;

        reasons.add(
          'Matches $preferredDayMatches preferred ${preferredDayMatches == 1 ? 'day' : 'days'}',
        );
      }

      final avoidedDayMatches = section.days
          .where(
            preferences.avoidedDays.contains,
          )
          .length;

      if (avoidedDayMatches > 0) {
        final penalty = avoidedDayMatches * 8;
        score -= penalty;

        reasons.add(
          'Includes ${avoidedDayMatches == 1 ? 'a day' : 'days'} you prefer to avoid',
        );
      }

      if (preferences.avoidEarlyClasses) {
        if (section.startMinutes < 9 * 60) {
          score -= 6;
          reasons.add('Starts earlier than preferred');
        } else {
          score += 2;
          reasons.add('Avoids an early start');
        }
      }

      if (preferences.avoidLateClasses) {
        if (section.endMinutes > 17 * 60) {
          score -= 6;
          reasons.add('Ends later than preferred');
        } else {
          score += 2;
          reasons.add('Avoids a late ending');
        }
      }

      if (_isPreferredProfessor(
        section,
        instructor,
        preferences.preferredProfessors,
      )) {
        score += 7;
        reasons.add('Matches a preferred professor');
      }

      final openSeats = section.toJson()['openSeats'];
      if (openSeats != null) {
        if (openSeats <= 0) {
          score -= 100;
          reasons.add('No open seats');
        } else {
          score += 3;
          reasons.add('Has open seats');
        }
      }

      final normalizedStatus =
          _getStatusText(section)?.trim().toLowerCase();

      if (normalizedStatus != null &&
          normalizedStatus.isNotEmpty) {
        if (normalizedStatus.contains('closed') ||
            normalizedStatus.contains('cancel')) {
          score -= 100;
          reasons.add('Section is not currently open');
        } else if (normalizedStatus.contains('open')) {
          score += 2;
          reasons.add('Section is open');
        }
      }

      return SectionMatch(
        section: section,
        instructor: instructor,
        score: score,
        reasons: reasons,
      );
    }).toList();

    matches.sort(
      (a, b) {
        final scoreComparison =
            b.score.compareTo(a.score);

        if (scoreComparison != 0) {
          return scoreComparison;
        }

        return a.section.startMinutes.compareTo(
          b.section.startMinutes,
        );
      },
    );

    return matches;
  }

  Instructor? _findInstructor(
    String instructorId,
    List<Instructor> instructors,
  ) {
    for (final instructor in instructors) {
      if (instructor.id == instructorId) {
        return instructor;
      }
    }

    return null;
  }

  int _scorePreferredTime(
    CourseSection section,
    String preferredTime,
  ) {
    final start = section.startMinutes;

    switch (preferredTime.toLowerCase()) {
      case 'morning':
        if (start >= 8 * 60 && start < 12 * 60) {
          return 5;
        }

        if (start < 14 * 60) {
          return 2;
        }

        return -2;

      case 'afternoon':
        if (start >= 12 * 60 && start < 17 * 60) {
          return 5;
        }

        if (start >= 10 * 60 && start < 18 * 60) {
          return 2;
        }

        return -2;

      case 'evening':
        if (start >= 17 * 60) {
          return 5;
        }

        if (start >= 15 * 60) {
          return 2;
        }

        return -2;

      default:
        return 0;
    }
  }

  bool _isPreferredProfessor(
    CourseSection section,
    Instructor? instructor,
    List<String> preferredProfessors,
  ) {
    if (preferredProfessors.isEmpty) {
      return false;
    }

    final possibleNames = <String>[
      if (instructor != null) instructor.name,
    ];

    for (final preferred in preferredProfessors) {
      final normalizedPreferred =
          preferred.trim().toLowerCase();

      for (final name in possibleNames) {
        final normalizedName =
            name.trim().toLowerCase();

        if (normalizedName == normalizedPreferred ||
            normalizedName.contains(
              normalizedPreferred,
            ) ||
            normalizedPreferred.contains(
              normalizedName,
            )) {
          return true;
        }
      }
    }

    return false;
  }

  String? _getStatusText(CourseSection section) {
    final sectionJson = section.toJson();
    final statusValue = sectionJson['status'];
    if (statusValue is String) {
      final status = statusValue.trim();
      if (status.isNotEmpty) {
        return status;
      }
    }

    final openSeats = sectionJson['openSeats'];
    if (openSeats == null) {
      return null;
    }

    if (openSeats <= 0) {
      return 'Closed';
    }

    return 'Open';
  }
}