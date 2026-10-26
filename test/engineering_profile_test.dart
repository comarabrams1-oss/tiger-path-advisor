import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/data/program_registry.dart';
import 'package:tiger_path/data/engineering_program.dart';
import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/models/degree_program.dart';
import 'package:tiger_path/models/schedule_preferences.dart';
import 'package:tiger_path/services/mock_auth_service.dart';
import 'package:tiger_path/services/semester_plan_service.dart';
import 'package:tiger_path/services/schedule_generation_service.dart';
import 'package:tiger_path/services/advisor_context_service.dart';

void main() {
  final sections =
      (jsonDecode(
            File('assets/data/course_sections_spring_2027.json')
                .readAsStringSync(),
          ) as List)
          .map((j) => CourseSection.fromJson(Map<String, dynamic>.from(j)))
          .toList();
  tearDown(() => selectDemoStudent(null));
  test(
    'engineering login restores and chooses a separate 125-credit program',
    () async {
      SharedPreferences.setMockInitialValues({});
      final auth = MockAuthService();
      final session = await auth.signIn(
        engineeringStudentEmail,
        remember: true,
      );
      selectDemoStudent((await auth.restore())!.email);
      expect(activeStudent, same(engineeringStudent));
      expect(activeProgram.name, 'Computer Engineering');
      expect(activeProgram.totalCreditsRequired, 125);
      expect(
        session.profileId,
        isNot(MockStudentSession(mockStudentEmail).profileId),
      );
      final academic = activeProgram.requirements.where(
        (r) => ![
          RequirementType.totalCredits,
          RequirementType.minimumGpa,
        ].contains(r.type),
      );
      expect(
        academic.fold<double>(0, (sum, r) => sum + r.creditsRequired),
        125,
      );
      expect(activeProgram.requirements.any((r) => r.id == 'ENGR 130'), isTrue);
      expect(activeProgram.requirements.any((r) => r.id == 'CSC 139'), isFalse);
      selectDemoStudent(mockStudentEmail);
      expect(activeProgram.totalCreditsRequired, 120);
      expect(activeProgram.name, 'Computer Science');
    },
  );
  test(
    'engineering plan uses real major-specific offerings, not the CS-only plan',
    () {
      final plan = SemesterPlanService().generatePlan(
        student: engineeringStudent,
        program: computerEngineeringProgram,
        catalog: catalogFor(engineeringStudent),
        maxCredits: 15,
        sections: sections,
      );
      final codes = plan.items.map((i) => i.courseCode).toSet();
      expect(codes, contains('ENGR 130'));
      expect(codes, isNot(contains('CSC 139')));
      expect(codes, isNot(contains('CSC 133')));
      expect(
        plan.items.any((i) => i.type == SemesterPlanItemType.requirementSlot),
        isFalse,
      );
      expect(plan.reviewItems.any((i) => i.courseCode == 'CE 211L'), isTrue);
      final schedule = ScheduleGenerationService().generateSchedule(
        plan: plan,
        sections: sections,
        instructors: [],
        preferences: const SchedulePreferences(
          preferredTime: 'Afternoon',
          preferredDays: [],
          avoidedDays: [],
          preferredProfessors: [],
          maxCredits: 15,
          avoidEarlyClasses: false,
          avoidLateClasses: false,
          minimizeGaps: true,
        ),
      );
      expect(schedule.scheduledCredits, greaterThanOrEqualTo(12));
      expect(schedule.scheduledCredits, lessThanOrEqualTo(15));
      final context = AdvisorContextService().build(
        student: engineeringStudent,
        program: computerEngineeringProgram,
        catalog: catalogFor(engineeringStudent),
        sections: sections,
        term: '2026-2027 - Spring',
      );
      expect(context['program'], 'Computer Engineering');
      expect(context['dataNotice'].toString(), contains('Labs, corequisite'));
      expect(utf8.encode(jsonEncode(context)).length, lessThan(55000));
    },
  );
}
