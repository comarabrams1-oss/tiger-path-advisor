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
        score += preferredDayMatches * 3;

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
        score -= avoidedDayMatches * 8;

        reasons.add(
          'Includes ${avoidedDayMatches == 1 ? 'a day' : 'days'} you prefer to avoid',
        );
      }

      if (preferences.avoidEarlyClasses) {
        if (section.hasPrimaryMeetingTime &&
            section.startMinutes < 9 * 60) {
          score -= 6;
          reasons.add(
            'Starts earlier than preferred',
          );
        } else if (section.hasPrimaryMeetingTime) {
          score += 2;
          reasons.add(
            'Avoids an early start',
          );
        }
      }

      if (preferences.avoidLateClasses) {
        if (section.hasPrimaryMeetingTime &&
            section.endMinutes > 17 * 60) {
          score -= 6;
          reasons.add(
            'Ends later than preferred',
          );
        } else if (section.hasPrimaryMeetingTime) {
          score += 2;
          reasons.add(
            'Avoids a late ending',
          );
        }
      }

      if (_isPreferredProfessor(
        section,
        instructor,
        preferences.preferredProfessors,
      )) {
        score += 7;
        reasons.add(
          'Matches a preferred professor',
        );
      }

      if (section.openSeats != null) {
        if (section.openSeats! <= 0) {
          score -= 100;
          reasons.add(
            'No open seats',
          );
        } else {
          score += 3;
          reasons.add(
            'Has open seats',
          );
        }
      }

      final normalizedStatus =
          section.status?.trim().toLowerCase();

      if (normalizedStatus != null &&
          normalizedStatus.isNotEmpty) {
        if (normalizedStatus.contains('closed') ||
            normalizedStatus.contains('cancel') ||
            normalizedStatus.contains('full')) {
          score -= 100;
          reasons.add(
            'Section is not currently open',
          );
        } else if (normalizedStatus.contains('open')) {
          score += 2;
          reasons.add(
            'Section is open',
          );
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

        final aStart = a.section.hasPrimaryMeetingTime
            ? a.section.startMinutes
            : 24 * 60;

        final bStart = b.section.hasPrimaryMeetingTime
            ? b.section.startMinutes
            : 24 * 60;

        return aStart.compareTo(bStart);
      },
    );

    return matches;
  }

  Instructor? _findInstructor(
    String instructorId,
    List<Instructor> instructors,
  ) {
    if (instructorId.trim().isEmpty) {
      return null;
    }

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
    if (!section.hasPrimaryMeetingTime) {
      return 0;
    }

    final start = section.startMinutes;

    switch (preferredTime.toLowerCase()) {
      case 'morning':
        if (start >= 8 * 60 &&
            start < 12 * 60) {
          return 5;
        }

        if (start < 14 * 60) {
          return 2;
        }

        return -2;

      case 'afternoon':
        if (start >= 12 * 60 &&
            start < 17 * 60) {
          return 5;
        }

        if (start >= 10 * 60 &&
            start < 18 * 60) {
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
      if (instructor != null)
        instructor.name,
      ...section.allInstructorNames,
    ];

    if (possibleNames.isEmpty) {
      return false;
    }

    for (final preferred in preferredProfessors) {
      final normalizedPreferred =
          _normalizeName(preferred);

      if (normalizedPreferred.isEmpty) {
        continue;
      }

      for (final name in possibleNames) {
        final normalizedName =
            _normalizeName(name);

        if (normalizedName.isEmpty) {
          continue;
        }

        if (normalizedName ==
                normalizedPreferred ||
            normalizedName.contains(
              normalizedPreferred,
            ) ||
            normalizedPreferred.contains(
              normalizedName,
            )) {
          return true;
        }

        if (_namesMatchByParts(
          normalizedName,
          normalizedPreferred,
        )) {
          return true;
        }
      }
    }

    return false;
  }

  String _normalizeName(
    String value,
  ) {
    return value
        .toLowerCase()
        .replaceAll(',', ' ')
        .replaceAll('.', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _namesMatchByParts(
    String first,
    String second,
  ) {
    final firstParts = first
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toSet();

    final secondParts = second
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toSet();

    if (firstParts.isEmpty ||
        secondParts.isEmpty) {
      return false;
    }

    final shared =
        firstParts.intersection(secondParts);

    if (shared.length >= 2) {
      return true;
    }

    if (shared.length == 1) {
      final part = shared.first;

      return part.length >= 4;
    }

    return false;
  }
}