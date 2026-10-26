import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/data/cs_course_catalog.dart';
import 'package:tiger_path/data/cs_program.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/models/student.dart';
import 'package:tiger_path/models/student_course.dart';
import 'package:tiger_path/models/schedule_preferences.dart';
import 'package:tiger_path/services/course_eligibility_service.dart';
import 'package:tiger_path/services/schedule_generation_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';
import 'package:tiger_path/services/course_priority_service.dart';
import 'package:tiger_path/services/schedule_recovery_service.dart';
import 'package:tiger_path/services/preferences_service.dart';
import 'package:tiger_path/services/degree_audit_service.dart';

Student studentWith(List<StudentCourse> courses) => Student(
  name: 'Fictional first-year student',
  institution: fictionalStudent.institution,
  major: fictionalStudent.major,
  catalogYear: fictionalStudent.catalogYear,
  classification: 'Freshman',
  gpa: 3,
  earnedCredits: 0,
  inProgressCredits: 0,
  requiredCredits: 120,
  courses: courses,
);

void main() {
  final sections =
      (jsonDecode(
            File('assets/data/course_sections_spring_2027.json')
                .readAsStringSync(),
          ) as List)
          .map(
            (json) => CourseSection.fromJson(Map<String, dynamic>.from(json)),
          )
          .toList();
  const preferences = SchedulePreferences(
    preferredTime: 'Afternoon',
    preferredDays: [],
    avoidedDays: [],
    preferredProfessors: [],
    maxCredits: 15,
    avoidEarlyClasses: false,
    avoidLateClasses: false,
    minimizeGaps: true,
  );
  for (final student in [fictionalStudent, studentWith([]), testStudent]) {
    test(
      '${student.name}: concrete draft uses eligible courses and real open offerings',
      () {
        final plan = SemesterPlanService().generatePlan(
          student: student,
          program: benedictComputerScience2024,
          catalog: computerScienceCourseCatalog,
          maxCredits: 15,
          sections: sections,
        );
        final codes = plan.items.map((i) => i.courseCode).toSet();
        expect(codes.length, plan.items.length);
        expect(plan.totalCredits, lessThanOrEqualTo(15));
        expect(
          plan.totalCredits,
          plan.items.fold<double>(0, (sum, i) => sum + i.credits),
        );
        expect(
          plan.items.every(
            (i) =>
                i.type == SemesterPlanItemType.course && i.courseCode != null,
          ),
          isTrue,
        );
        expect(
          plan.items.any(
            (i) => student.courses.any((c) => c.courseCode == i.courseCode),
          ),
          isFalse,
        );
        expect(
          plan.items.every(
            (i) => sections.any(
              (s) => s.courseCode == i.courseCode && s.isOpen && s.hasOpenSeats,
            ),
          ),
          isTrue,
        );
        if (student.classification == 'Freshman') {
          expect(
            codes,
            contains(
              student.courses.any((c) => c.courseCode == 'AA 111')
                  ? 'AA 211'
                  : 'AA 111',
            ),
          );
          expect(codes.any((c) => c!.startsWith('ENG ')), isTrue);
          expect(
            codes.any((c) => c!.startsWith('CSC 3') || c.startsWith('CSC 4')),
            isFalse,
          );
          if (!student.courses.any((c) => c.courseCode == 'AR 130')) {
            expect(
              codes.contains('AR 233') ||
                  codes.contains('FS 233') ||
                  codes.contains('SP 233'),
              isFalse,
            );
          } else if (codes.contains('AR 233')) {
            expect(
              plan.items
                  .firstWhere((i) => i.courseCode == 'AR 233')
                  .projectedEligibility,
              isTrue,
            );
          }
          expect(
            codes.contains('ART 130') && codes.contains('MUS 130'),
            isFalse,
          );
          final schedule = ScheduleGenerationService().generateSchedule(
            plan: plan,
            sections: sections,
            instructors: [],
            preferences: preferences,
          );
          expect(schedule.scheduledCredits, greaterThanOrEqualTo(12));
        }
        for (final item in plan.items) {
          expect([
            EligibilityStatus.eligible,
            EligibilityStatus.eligibleAfterCurrentTerm,
          ], contains(item.priority!.eligibility.status));
        }
      },
    );
  }
  test('English C prerequisite and language placement are not bypassed', () {
    final service = CourseEligibilityService();
    final english = computerScienceCourseCatalog.firstWhere(
      (c) => c.code == 'ENG 132',
    );
    expect(
      service
          .checkCourse(
            studentWith([
              const StudentCourse(
                courseCode: 'ENG 131',
                grade: 'D',
                term: 'Fall 2026',
                status: CourseStatus.completed,
              ),
            ]),
            english,
          )
          .status,
      EligibilityStatus.blocked,
    );
    expect(
      service
          .checkCourse(
            studentWith([
              const StudentCourse(
                courseCode: 'ENG 131',
                grade: 'C',
                term: 'Fall 2026',
                status: CourseStatus.completed,
              ),
            ]),
            english,
          )
          .status,
      EligibilityStatus.eligible,
    );
    final plan = SemesterPlanService().generatePlan(
      student: studentWith([]),
      program: benedictComputerScience2024,
      catalog: computerScienceCourseCatalog,
      maxCredits: 15,
      sections: sections,
    );
    expect(
      plan.reviewItems.any((i) => i.title.contains('Foreign Language')),
      isTrue,
    );
    expect(plan.items.any((i) => i.courseCode == 'MATH 143'), isFalse);
  });
  test(
    'recovery cannot add a second option to an already covered elective block',
    () {
      final ranked = CoursePriorityService().rankCourses(
        fictionalStudent,
        benedictComputerScience2024,
        computerScienceCourseCatalog,
      );
      final art = ranked.firstWhere((c) => c.course.code == 'ART 130');
      final item = SemesterPlanItem(
        type: SemesterPlanItemType.course,
        title: art.course.title,
        category: art.course.category,
        credits: 3,
        courseCode: art.course.code,
        reason: '',
        priority: art,
      );
      CourseSection section(String code, int start) => CourseSection(
        courseCode: code,
        sectionNumber: '01',
        instructorId: '',
        term: 'test',
        days: ['Monday'],
        startMinutes: start,
        endMinutes: start + 50,
        location: '',
        deliveryMethod: '',
        openSeats: 10,
      );
      final result = ScheduleRecoveryService().recover(
        plan: SemesterPlan(items: [item], totalCredits: 3, maxCredits: 15),
        candidates: ranked,
        requestedCourses: ['MUS 130'],
        sections: [section('ART 130', 540), section('MUS 130', 660)],
        instructors: [],
        preferences: preferences,
      );
      expect(result.plan.items.map((i) => i.courseCode), ['ART 130']);
    },
  );
  test('mock profiles keep scheduling preferences separate', () {
    PreferencesService.useProfile('test-original');
    PreferencesService.savePreferences(preferences);
    PreferencesService.useProfile('test-freshman');
    expect(PreferencesService.preferences, isNull);
    PreferencesService.useProfile('test-original');
    expect(PreferencesService.preferences, same(preferences));
    PreferencesService.useProfile('demo-cs-2024');
  });
  test(
    'freshman audit does not inherit another student’s confirmed electives',
    () {
      final audit = DegreeAuditService();
      final original = audit
          .auditProgram(testStudent, benedictComputerScience2024)
          .firstWhere((a) => a.requirement.id == 'FREE_ELECTIVES');
      final freshman = audit
          .auditProgram(fictionalStudent, benedictComputerScience2024)
          .firstWhere((a) => a.requirement.id == 'FREE_ELECTIVES');
      expect(original.status, RequirementStatus.completed);
      expect(original.completedCredits, 6);
      expect(freshman.status, RequirementStatus.remaining);
      expect(freshman.completedCredits, 0);
    },
  );
}
