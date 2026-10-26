import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/models/schedule_preferences.dart';
import 'package:tiger_path/services/schedule_matching_service.dart';

void main() {
  test('early and late preferences use their own cutoffs and all meetings', () {
    CourseSection section(
      String id,
      int start,
      int end, {
      List<CourseMeeting> meetings = const [],
    }) => CourseSection(
      courseCode: 'CSC 237',
      sectionNumber: id,
      instructorId: '',
      term: 'test',
      days: const ['Monday'],
      startMinutes: start,
      endMinutes: end,
      location: '',
      deliveryMethod: '',
      meetings: meetings,
    );
    final sections = [
      section('early', 8 * 60, 9 * 60),
      section('day', 10 * 60, 17 * 60),
      section('late', 16 * 60, 18 * 60),
      section(
        'lab',
        10 * 60,
        11 * 60,
        meetings: const [
          CourseMeeting(
            days: ['Tuesday'],
            startMinutes: 18 * 60,
            endMinutes: 19 * 60,
          ),
        ],
      ),
    ];
    List<String> reasons(bool early, bool late, String id) =>
        ScheduleMatchingService()
            .rankSections(
              sections: sections,
              instructors: [],
              preferences: SchedulePreferences(
                preferredTime: 'No Preference',
                preferredDays: [],
                avoidedDays: [],
                preferredProfessors: [],
                maxCredits: 15,
                avoidEarlyClasses: early,
                avoidLateClasses: late,
                minimizeGaps: false,
              ),
            )
            .firstWhere((match) => match.section.sectionNumber == id)
            .reasons;
    expect(
      reasons(true, false, 'early'),
      contains('Starts earlier than preferred'),
    );
    expect(reasons(true, false, 'day'), contains('Avoids an early start'));
    expect(reasons(false, true, 'late'), contains('Ends later than preferred'));
    expect(reasons(false, true, 'lab'), contains('Ends later than preferred'));
    expect(reasons(false, true, 'day'), contains('Avoids a late ending'));
    expect(
      reasons(false, true, 'early'),
      isNot(contains('Starts earlier than preferred')),
    );
    expect(
      reasons(true, false, 'late'),
      isNot(contains('Ends later than preferred')),
    );
  });
}
