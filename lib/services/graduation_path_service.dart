import 'dart:math' as math;

import '../data/program_registry.dart';
import '../models/academic_term.dart';
import '../models/course.dart';
import '../models/course_section.dart';
import '../models/degree_program.dart';
import '../models/student.dart';
import '../models/student_course.dart';
import 'course_eligibility_service.dart';
import 'course_section_repository.dart';
import 'degree_audit_service.dart';
import 'semester_plan_service.dart';
import 'student_record_service.dart';

class PathwayTerm {
  final AcademicTerm term;
  final List<SemesterPlanItem> courses;
  final double credits;
  final double reviewCredits;
  final bool hasSnapshot;
  const PathwayTerm(
    this.term,
    this.courses,
    this.credits,
    this.reviewCredits,
    this.hasSnapshot,
  );
}

class GraduationPath {
  final AcademicTerm nextTerm;
  final AcademicTerm? estimatedTerm;
  final int minimumTermsByCredit;
  final List<PathwayTerm> terms;
  final List<String> alerts;
  final List<String> outstanding;
  final List<String> nextPrerequisites;
  final bool requirementsMet;
  final bool assumesCurrentGrades;
  final bool needsElectiveApproval;
  const GraduationPath({
    required this.nextTerm,
    required this.estimatedTerm,
    required this.minimumTermsByCredit,
    required this.terms,
    required this.alerts,
    required this.outstanding,
    required this.nextPrerequisites,
    required this.requirementsMet,
    required this.assumesCurrentGrades,
    required this.needsElectiveApproval,
  });

  String get status => requirementsMet
      ? 'Mapped requirements met'
      : estimatedTerm?.label ?? 'Pending advisor review';

  Map<String, Object?> toAdvisorContext() => {
    'nextTerm': nextTerm.label,
    'estimatedTerm': estimatedTerm?.label,
    'projectedSemesters': estimatedTerm == null ? null : terms.length,
    'minimumTermsByCredit': minimumTermsByCredit,
    'requirementsMet': requirementsMet,
    'assumesCurrentGrades': assumesCurrentGrades,
    'needsElectiveApproval': needsElectiveApproval,
    'outstanding': outstanding.take(10).toList(),
    'missingPrerequisites': nextPrerequisites.take(10).toList(),
    'academicAlertCount': alerts.length,
    'nextCourses': [
      for (final course
          in (terms.firstOrNull?.courses ?? const <SemesterPlanItem>[]))
        {
          'code': course.courseCode,
          'title': course.title,
          'reason': course.reason,
        },
    ],
  };
}

class GraduationPathService {
  static const horizon = 8;

  Future<GraduationPath> load(Student student, {int maxCredits = 15}) async {
    final offerings = await Future.wait(
      CourseSectionRepository.availableTerms.map((key) async {
        try {
          final sections = await CourseSectionRepository.loadForTerm(key);
          return MapEntry(key, sections);
        } catch (_) {
          return MapEntry(key, <CourseSection>[]);
        }
      }),
    );
    return project(
      student: student,
      program: programFor(student),
      catalog: catalogFor(student),
      offerings: Map.fromEntries(
        offerings.where((entry) => entry.value.isNotEmpty),
      ),
      maxCredits: maxCredits,
    );
  }

  GraduationPath project({
    required Student student,
    required DegreeProgram program,
    required List<Course> catalog,
    Map<String, List<CourseSection>> offerings = const {},
    int maxCredits = 15,
  }) {
    final limit = maxCredits.clamp(12, 18);
    final auditService = DegreeAuditService();
    final currentTerm = StudentRecordService.currentTerm(student);
    final nextTerm = currentTerm.next;
    final currentAudit = auditService.auditProgram(student, program);
    final passingCurrent = student.courses
        .where((c) => c.status == CourseStatus.inProgress)
        .toList();
    final hours = {for (final course in catalog) course.code: course.credits};
    final byCode = {for (final course in catalog) course.code: course};
    final knownCourseCodes = {
      for (final section in offerings.values.expand((list) => list))
        section.courseCode,
    };
    final referenceTerm = {
      AcademicSeason.spring: AcademicTerm.firstPlanningTerm.portalKey,
      AcademicSeason.fall: AcademicTerm.demoTerm.portalKey,
    };

    var projected = _passCourses(student, passingCurrent, hours);
    final eligibility = CourseEligibilityService();
    final nextPrerequisites = eligibility
        .checkProgramCourses(projected, program, catalog)
        .where((result) => result.missingPrerequisites.isNotEmpty)
        .map(
          (result) =>
              '${result.course.code} needs ${result.missingPrerequisites.join(', ')}',
        )
        .toList();
    final minimumTerms = (projected.remainingCredits / limit).ceil();
    var audit = auditService.auditProgram(projected, program);
    final requirementsMet = currentAudit.every(
      (a) => a.status == RequirementStatus.completed,
    );
    AcademicTerm? finish =
        !requirementsMet &&
            audit.every((a) => a.status == RequirementStatus.completed)
        ? currentTerm
        : null;
    var needsElectiveApproval = false;
    var idle = 0;
    final terms = <PathwayTerm>[];
    final planner = SemesterPlanService();
    for (
      var term = nextTerm;
      terms.length < horizon && idle < 2 && finish == null && !requirementsMet;
      term = term.next
    ) {
      final sections = offerings[term.portalKey];
      final historical = offerings[referenceTerm[term.season]];
      final seasonal = historical?.map((section) => section.courseCode).toSet();
      final expected = seasonal == null || offerings.length < 2
          ? null
          : {
              ...seasonal,
              ...byCode.keys.where((code) => !knownCourseCodes.contains(code)),
            };
      final planningProgram = _includePreparation(
        projected,
        program,
        byCode,
        audit,
      );
      final plan = planner.generatePlan(
        student: projected,
        program: planningProgram,
        catalog: catalog,
        maxCredits: limit,
        sections: sections,
        expectedCourseCodes: sections == null ? expected : null,
      );
      projected = _passCourses(projected, [
        for (final item in plan.items)
          StudentCourse(
            courseCode: item.courseCode!,
            term: term.label,
            status: CourseStatus.inProgress,
            creditHours: item.credits,
          ),
      ], hours);
      audit = auditService.auditProgram(projected, program);

      // Reserve a credit block without inventing an approved elective or a section.
      var reserved = 0.0;
      if (sections == null && limit > plan.totalCredits) {
        final slotCredits = {...projected.confirmedRequirementCredits};
        for (final item in audit.where(
          (a) =>
              a.requirement.type == RequirementType.elective &&
              a.status != RequirementStatus.completed,
        )) {
          final credits = math.min(
            item.requirement.creditsRequired - item.completedCredits,
            limit - plan.totalCredits - reserved,
          );
          if (credits <= 0) break;
          slotCredits.update(
            item.requirement.id,
            (value) => value + credits,
            ifAbsent: () => credits,
          );
          reserved += credits;
        }
        final onlyGraduationLeft = audit.every(
          (a) =>
              a.status == RequirementStatus.completed ||
              a.requirement.type == RequirementType.totalCredits ||
              a.requirement.type == RequirementType.minimumGpa ||
              a.requirement.type == RequirementType.elective,
        );
        if (onlyGraduationLeft) {
          final creditGap = math.max(
            0.0,
            program.totalCreditsRequired - projected.earnedCredits - reserved,
          );
          reserved += math.min(creditGap, limit - plan.totalCredits - reserved);
        }
        if (reserved > 0) {
          needsElectiveApproval = true;
          final earned = projected.earnedCredits + reserved;
          projected = projected.copyWith(
            earnedCredits: earned,
            confirmedRequirementCredits: slotCredits,
            classification: StudentRecordService.classificationFor(earned),
          );
          audit = auditService.auditProgram(projected, program);
        }
      }
      final credits = plan.totalCredits + reserved;
      terms.add(
        PathwayTerm(term, plan.items, credits, reserved, sections != null),
      );
      idle = credits == 0 ? idle + 1 : 0;
      if (audit.every((a) => a.status == RequirementStatus.completed)) {
        finish = term;
      }
    }

    final alerts = _recordAlerts(student, catalog);
    if (student.hasCalculatedGpa) {
      final credit = student.earnedCredits;
      final benchmark = credit <= 15
          ? 1.75
          : credit < 30
          ? 1.8
          : credit <= 45
          ? 1.9
          : 2.0;
      if (student.gpa < benchmark) {
        alerts.add(
          'Recorded GPA is below the ${benchmark.toStringAsFixed(2)} academic-progress benchmark.',
        );
      }
    }
    final needReview = <String>[];
    for (final item in audit.where(
      (item) => item.status != RequirementStatus.completed,
    )) {
      final requirement = item.requirement;
      final details = <String>{};
      for (final code in requirement.courseCodes) {
        if (!item.needsCourse(projected, code)) continue;
        final course = byCode[code];
        if (course == null) continue;
        final check = eligibility.checkCourse(projected, course);
        if (check.missingPrerequisites.isNotEmpty) {
          details.add('$code needs ${check.missingPrerequisites.join(', ')}');
        } else if (check.status == EligibilityStatus.requiresPermission ||
            check.status == EligibilityStatus.blocked) {
          details.add('$code · ${check.reason}');
        }
      }
      final detail = details.take(3).join(' · ');
      needReview.add(
        detail.isEmpty ? requirement.title : '${requirement.title} · $detail',
      );
    }
    return GraduationPath(
      nextTerm: nextTerm,
      estimatedTerm: finish,
      minimumTermsByCredit: minimumTerms,
      terms: terms,
      alerts: alerts,
      outstanding: needReview,
      nextPrerequisites: nextPrerequisites,
      requirementsMet: requirementsMet,
      needsElectiveApproval: needsElectiveApproval,
      assumesCurrentGrades: passingCurrent.isNotEmpty,
    );
  }

  Student _passCourses(
    Student student,
    List<StudentCourse> additions,
    Map<String, double> hours,
  ) {
    final attempts = [
      ...student.courses.where((course) => !additions.contains(course)),
      for (final entry in additions)
        StudentCourse(
          courseCode: entry.courseCode,
          term: entry.term,
          status: CourseStatus.completed,
          grade: 'A',
          creditHours: entry.creditHours ?? hours[entry.courseCode],
          approvedElectiveId: entry.approvedElectiveId,
        ),
    ];
    final delta =
        StudentRecordService.metrics(attempts, hours).earned -
        StudentRecordService.metrics(student.courses, hours).earned;
    final earned = student.earnedCredits + delta;
    return student.copyWith(
      courses: attempts,
      earnedCredits: earned,
      inProgressCredits: 0,
      classification: StudentRecordService.classificationFor(earned),
    );
  }

  // Some required courses have a preparatory prerequisite outside the
  // degree audit (for example, elementary language before intermediate).
  DegreeProgram _includePreparation(
    Student student,
    DegreeProgram program,
    Map<String, Course> catalog,
    List<DegreeAuditItem> audit,
  ) {
    final occupied = program.requirements.expand((r) => r.courseCodes).toSet();
    final prep = <DegreeRequirement>[];
    final eligibility = CourseEligibilityService();
    for (final item in audit.where(
      (item) => item.status == RequirementStatus.remaining,
    )) {
      final options = <Course>{};
      for (final code in item.requirement.courseCodes) {
        final course = catalog[code];
        if (course == null || !item.needsCourse(student, code)) continue;
        final result = eligibility.checkCourse(student, course);
        if (result.status == EligibilityStatus.eligible) {
          options.clear();
          break;
        }
        for (final missing in result.missingPrerequisites) {
          for (final candidate in missing.split(' OR ')) {
            if (catalog[candidate] case final option?
                when !occupied.contains(candidate)) {
              options.add(option);
            }
          }
        }
      }
      if (options.isEmpty) continue;
      final credit = options.first.credits;
      final choice = options
          .where((course) => course.credits == credit)
          .map((course) => course.code)
          .toList();
      occupied.addAll(choice);
      prep.add(
        DegreeRequirement(
          id: 'PREP_${item.requirement.id}',
          title: 'Preparation for ${item.requirement.title}',
          category: 'Preparation',
          type: RequirementType.oneOfCourses,
          courseCodes: choice,
          creditsRequired: credit,
        ),
      );
    }
    if (prep.isEmpty) return program;
    return DegreeProgram(
      institution: program.institution,
      name: program.name,
      degreeType: program.degreeType,
      catalogYear: program.catalogYear,
      totalCreditsRequired: program.totalCreditsRequired,
      majorCreditsRequired: program.majorCreditsRequired,
      requirements: [...program.requirements, ...prep],
    );
  }

  List<String> _recordAlerts(Student student, List<Course> catalog) {
    final courses = {for (final course in catalog) course.code: course};
    final alerts = <String>{};
    for (final attempt in student.courses.where(
      (attempt) => !attempt.transfer,
    )) {
      if (attempt.status == CourseStatus.completed &&
          !attempt.meetsMinimumGrade(null)) {
        alerts.add(
          '${attempt.courseCode} · ${attempt.term} · ${attempt.normalizedGrade ?? 'No grade'} earned no credit.',
        );
      }
      final term = AcademicTerm.parse(attempt.term);
      final course = courses[attempt.courseCode];
      if (course == null || term == null || course.prerequisiteGroups.isEmpty) {
        continue;
      }
      if (course.allowsPlacementExemption &&
          student.verifiedPlacementCourses.contains(course.code)) {
        continue;
      }
      final previous = student.courses.where((previous) {
        final taken = AcademicTerm.parse(previous.term);
        return taken != null && taken.compareTo(term) < 0;
      });
      final missing = course.prerequisiteGroups.where(
        (group) => !group.any(
          (code) => previous.any(
            (attempt) =>
                attempt.courseCode == code &&
                attempt.meetsMinimumGrade(
                  course.minimumPrerequisiteGrades[code],
                ),
          ),
        ),
      );
      if (missing.isNotEmpty) {
        alerts.add(
          '${attempt.courseCode} · ${term.label} · Review course order. Prior credit for ${missing.map((group) => group.join(' or ')).join(', ')} is missing from this record.',
        );
      }
    }
    return alerts.toList();
  }
}
