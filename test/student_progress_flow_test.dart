import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/data/program_registry.dart';
import 'package:tiger_path/data/test_student.dart';
import 'package:tiger_path/main.dart';
import 'package:tiger_path/models/academic_term.dart';
import 'package:tiger_path/models/course.dart';
import 'package:tiger_path/models/degree_program.dart';
import 'package:tiger_path/models/readiness.dart';
import 'package:tiger_path/models/student_course.dart';
import 'package:tiger_path/services/course_eligibility_service.dart';
import 'package:tiger_path/services/degree_audit_service.dart';
import 'package:tiger_path/services/graduation_path_service.dart';
import 'package:tiger_path/services/mock_auth_service.dart';
import 'package:tiger_path/services/readiness_progress_service.dart';
import 'package:tiger_path/services/student_record_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recording grades updates earned credits and mapped prerequisite eligibility by profile', () async {
    SharedPreferences.setMockInitialValues({});
    final records = StudentRecordService();
    final student = testStudent;
    final course = catalogFor(student)
        .firstWhere((course) => course.code == 'PHYS 234');
    expect(
      CourseEligibilityService().checkCourse(student, course).status,
      EligibilityStatus.eligibleAfterCurrentTerm,
    );
    final attempts = [
      for (final attempt in student.courses)
        if (attempt.courseCode == 'PHYS 233')
          const StudentCourse(
            courseCode: 'PHYS 233',
            term: 'Fall 2026',
            status: CourseStatus.completed,
            grade: 'A',
          )
        else
          attempt,
    ];
    final saved = await records.save('one', student, attempts);
    expect(saved.earnedCredits, student.earnedCredits + 3);
    expect(
      CourseEligibilityService().checkCourse(saved, course).status,
      EligibilityStatus.eligible,
    );
    final restored = await records.load('one', student);
    expect(restored.earnedCredits, saved.earnedCredits);
    expect(restored.gpa, saved.gpa);
    expect(await records.load('two', student), same(student));
    expect(
      DegreeAuditService()
          .auditProgram(saved, programFor(student))
          .firstWhere((a) => a.requirement.id == 'GENED_SCIENCE')
          .completedCredits,
      3,
    );
  });

  test('transfer and repeats update credits and GPA without duplicate graduation credit', () {
    const attempts = [
      StudentCourse(
        courseCode: 'CSC 135',
        term: 'Fall 2025',
        status: CourseStatus.completed,
        grade: 'F',
      ),
      StudentCourse(
        courseCode: 'CSC 135',
        term: 'Spring 2026',
        status: CourseStatus.completed,
        grade: 'B',
      ),
      StudentCourse(
        courseCode: 'CSC 135',
        term: 'Fall 2026',
        status: CourseStatus.completed,
        grade: 'C',
      ),
      StudentCourse(
        courseCode: 'CSC 135',
        term: 'Spring 2027',
        status: CourseStatus.inProgress,
      ),
      StudentCourse(
        courseCode: 'ENG 131',
        term: 'Fall 2025',
        status: CourseStatus.completed,
        grade: 'CR',
        isTransfer: true,
        creditHours: 3,
      ),
      StudentCourse(
        courseCode: 'MATH 143',
        term: 'Fall 2025',
        status: CourseStatus.completed,
        grade: 'WC',
      ),
    ];
    final result = StudentRecordService.metrics(attempts, {
      'CSC 135': 3,
      'MATH 143': 4,
    });
    expect(result.earned, 6);
    expect(result.transfer, 3);
    expect(result.attempted, 16);
    expect(result.inProgress, 0);
    expect(result.gpa, 2.5);
    expect(attempts[4].meetsMinimumGrade('C'), isTrue);
    expect(attempts[5].meetsMinimumGrade(null), isFalse);
  });

  test('graduation pathway orders prerequisites in different terms and dates full completion', () {
    const courses = [
      Course(
        code: 'TST 101',
        title: 'First course',
        credits: 3,
        category: 'Major',
      ),
      Course(
        code: 'TST 102',
        title: 'Second course',
        credits: 3,
        category: 'Major',
        prerequisiteGroups: [
          ['TST 101'],
        ],
      ),
      Course(
        code: 'TST 103',
        title: 'Third course',
        credits: 3,
        category: 'Major',
        prerequisiteGroups: [
          ['TST 102'],
        ],
      ),
    ];
    final program = DegreeProgram(
      institution: 'Benedict',
      name: 'Sequencing test',
      degreeType: 'B.S.',
      catalogYear: '2026',
      totalCreditsRequired: 9,
      majorCreditsRequired: 9,
      requirements: [
        for (final course in courses)
          DegreeRequirement(
            id: course.code,
            title: course.title,
            category: 'Major',
            type: RequirementType.requiredCourse,
            courseCodes: [course.code],
            creditsRequired: 3,
          ),
      ],
    );
    final student = fictionalStudent.copyWith(
      courses: const [],
      earnedCredits: 0,
      inProgressCredits: 0,
    );
    final path = GraduationPathService().project(
      student: student,
      program: program,
      catalog: courses,
    );
    expect(path.terms.map((term) => term.courses.single.courseCode), [
      'TST 101',
      'TST 102',
      'TST 103',
    ]);
    expect(path.estimatedTerm, const AcademicTerm(AcademicSeason.spring, 2028));
    expect(path.nextPrerequisites, [
      'TST 102 needs TST 101',
      'TST 103 needs TST 102',
    ]);
    expect(path.outstanding, isEmpty);
    expect(student.courses, isEmpty);
  });

  test('readiness status, evidence, and dates persist with shared research and a separate GPA target', () async {
    SharedPreferences.setMockInitialValues({
      'readiness_v1_student_milestone_resume': true,
    });
    const readiness = ReadinessProgressService('student');
    await readiness.setEntry(
      'research',
      const ReadinessEntry(
        status: ReadinessStatus.complete,
        evidence: 'Presented a campus project',
        due: '2027-03-12',
      ),
    );
    await readiness.setTargetGpa(3.5);
    final profile = await readiness.loadProfile();
    expect(profile.progress(careerMilestones), (2, 7));
    expect(profile.progress(graduateMilestones, meetsTargetGpa: true), (2, 6));
    expect(profile.entries['research']?.due, '2027-03-12');
    expect(
      profile.toAdvisorContext(true).toString(),
      isNot(contains('Presented a campus project')),
    );
    expect(
      (await const ReadinessProgressService('other').loadProfile()).entries,
      isEmpty,
    );
  });

  testWidgets(
    'a student can enter a final grade and see the updated dashboard and advisor review',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'mock_student_session_v1': mockStudentEmail,
      });
      rootBundle.clear();
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async {
          final path = const StringCodec().decodeMessage(message)!;
          return ByteData.sublistView(
            File('build/unit_test_assets/$path').readAsBytesSync(),
          );
        },
      );
      addTearDown(() {
        rootBundle.clear();
        selectDemoStudent(null);
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          null,
        );
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 850);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      Future<void> settle() async {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> visible(Finder item) async {
        await tester.scrollUntilVisible(
          item,
          360,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.ensureVisible(item);
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(const TigerPathAdvisorApp());
      await settle();
      await visible(find.text('View transcript'));
      await tester.tap(find.text('View transcript'));
      await settle();
      await visible(find.text('Enter final grades'));
      await tester.tap(find.text('Enter final grades'));
      await settle();
      final firstGrade = find.byType(DropdownButton<String>).first;
      await tester.tap(firstGrade);
      await settle();
      await tester.tap(find.text('A').last);
      await settle();
      await tester.tap(find.text('Save grades'));
      await settle();
      expect(activeStudent.earnedCredits, 9);
      const session = MockStudentSession(mockStudentEmail);
      expect(
        (await StudentRecordService().load(
          session.profileId,
          fictionalStudent,
        )).earnedCredits,
        9,
      );
      await tester.pageBack();
      await settle();
      await tester.pump(const Duration(seconds: 5));
      await settle();
      await visible(find.text('Review with advisor'));
      await tester.tap(find.text('Review with advisor'));
      await settle();
      expect(find.text('Advisor review'), findsOneWidget);
      expect(find.textContaining('9 of 120 credits'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
