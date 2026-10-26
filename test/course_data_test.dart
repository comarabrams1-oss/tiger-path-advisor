import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/services/course_section_repository.dart';
import 'package:tiger_path/services/tiger_portal_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Fall asset loads with canonical and legacy term names', () async {
    final sections = await CourseSectionRepository.loadFall2026();
    expect(sections, hasLength(529));
    expect(sections.map((s) => s.courseCode).toSet(), hasLength(356));
    expect(
      sections.every((s) => s.term == CourseSectionRepository.fall2026Term),
      isTrue,
    );
    expect(
      sections
          .where((s) => s.courseCode == 'AR 130')
          .any((s) => s.sectionNumber == '99 B1'),
      isTrue,
    );
    expect(
      await CourseSectionRepository.loadForTerm(
        '2026-2027 - Fall - Full Semester',
      ),
      hasLength(529),
    );
    expect(await CourseSectionRepository.loadForTerm('unavailable'), isEmpty);
  });
  test('Spring asset contains only validated 2027 sections', () async {
    final sections = await CourseSectionRepository.loadForTerm(
      CourseSectionRepository.spring2027Term,
    );
    expect(sections, hasLength(484));
    expect(sections.map((s) => s.courseCode).toSet(), hasLength(362));
    expect(
      sections.every((s) => s.term == CourseSectionRepository.spring2027Term),
      isTrue,
    );
    expect(sections.where((s) => s.isOpen && s.hasOpenSeats), hasLength(478));
    expect(sections.where((s) => s.courseCode == 'CSC 434'), isNotEmpty);
  });
  test('Parser preserves compound section identifiers and all meetings', () {
    final sections = TigerPortalParser.parseCourseSections('''
<select id="pg0_V_ddlTerm"><option selected>2026-2027 - Spring</option></select>
<table id="pg0_V_dgCourses"><tbody><tr>
<td></td><td></td><td>CSC 334 01 B2</td><td>Algorithms</td>
<td>Staff</td><td>12 / 20</td><td>Open</td>
<td><ul><li>MW 09:00 AM - 09:50 AM; Room 1</li><li>R 01:00 PM - 02:00 PM; Lab</li></ul></td>
<td>3</td><td>01/11/2027</td><td>05/01/2027</td>
</tr></tbody></table>''');
    final section = sections.single;
    expect(section.courseCode, 'CSC 334');
    expect(section.sectionNumber, '01 B2');
    expect(section.term, CourseSectionRepository.spring2027Term);
    expect(section.meetings, hasLength(2));
    expect(section.meetings.last.days, ['Thursday']);
    expect(section.meetings.last.startMinutes, 780);
  });
}
