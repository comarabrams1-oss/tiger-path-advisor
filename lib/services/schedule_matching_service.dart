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
    final results = sections.map((section) {
      final instructor = _findInstructor(
        instructors,
        section.instructorId,
      );

      var score = 0;
      final reasons = <String>[];

      if (_matchesPreferredTime(
        section,
        preferences.preferredTime,
      )) {
        score += 3;
        reasons.add(
          'Matches preferred class time',
        );
      }

      if (preferences.preferredDays.isNotEmpty &&
          section.days.any(
            preferences.preferredDays.contains,
          )) {
        score += 2;
        reasons.add(
          'Includes preferred class days',
        );
      }

      if (section.days.any(
        preferences.avoidedDays.contains,
      )) {
        score -= 5;
        reasons.add(
          'Uses a day you prefer to avoid',
        );
      }

      if (preferences.avoidEarlyClasses &&
          section.startMinutes < 540) {
        score -= 4;
        reasons.add(
          'Starts before 9:00 AM',
        );
      }

      if (preferences.avoidLateClasses &&
          section.endMinutes > 1020) {
        score -= 4;
        reasons.add(
          'Ends after 5:00 PM',
        );
      }

      if (instructor != null &&
          preferences.preferredProfessors.any(
            (name) =>
                name.toLowerCase() ==
                instructor.name.toLowerCase(),
          )) {
        score += 4;
        reasons.add(
          'Matches preferred professor',
        );
      }

      return SectionMatch(
        section: section,
        instructor: instructor,
        score: score,
        reasons: reasons,
      );
    }).toList();

    results.sort(
      (a, b) => b.score.compareTo(a.score),
    );

    return results;
  }

  Instructor? _findInstructor(
    List<Instructor> instructors,
    String instructorId,
  ) {
    for (final instructor in instructors) {
      if (instructor.id == instructorId) {
        return instructor;
      }
    }

    return null;
  }

  bool _matchesPreferredTime(
    CourseSection section,
    String preferredTime,
  ) {
    if (preferredTime == 'No Preference') {
      return true;
    }

    if (preferredTime == 'Morning') {
      return section.startMinutes < 720;
    }

    if (preferredTime == 'Afternoon') {
      return section.startMinutes >= 720 &&
          section.startMinutes < 1020;
    }

    if (preferredTime == 'Evening') {
      return section.startMinutes >= 1020;
    }

    return false;
  }
}