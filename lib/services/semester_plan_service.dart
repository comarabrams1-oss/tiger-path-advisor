import '../models/course.dart';
import '../models/degree_program.dart';
import '../models/student.dart';
import '../models/student_course.dart';
import '../models/course_section.dart';
import '../models/schedule_preferences.dart';
import 'schedule_generation_service.dart';
import 'course_eligibility_service.dart';
import 'course_priority_service.dart';
import 'degree_audit_service.dart';

enum SemesterPlanItemType { course, requirementSlot }

class SemesterPlanItem {
  final SemesterPlanItemType type;
  final String title;
  final String category;
  final double credits;
  final String? courseCode;
  final String reason;
  final bool projectedEligibility;
  final CoursePriorityResult? priority;

  const SemesterPlanItem({
    required this.type,
    required this.title,
    required this.category,
    required this.credits,
    required this.reason,
    this.courseCode,
    this.projectedEligibility = false,
    this.priority,
  });
}

class SemesterPlan {
  final List<SemesterPlanItem> items;
  final double totalCredits;
  final int maxCredits;
  final List<SemesterPlanItem> reviewItems;
  final String? shortfallReason;

  const SemesterPlan({
    required this.items,
    required this.totalCredits,
    required this.maxCredits,
    this.reviewItems = const [],
    this.shortfallReason,
  });

  double get remainingCreditCapacity {
    return maxCredits - totalCredits;
  }
}

class SemesterPlanService {
  SemesterPlan generatePlan({
    required Student student,
    required DegreeProgram program,
    required List<Course> catalog,
    required int maxCredits,
    List<CourseSection>? sections,
    SchedulePreferences? preferences,
    Map<String, String> preferredSections = const {},
    List<String> preferredCourses = const [],
  }) {
    final audit = DegreeAuditService().auditProgram(student, program);
    final used = student.courses
        .where(
          (c) =>
              c.status == CourseStatus.completed ||
              c.status == CourseStatus.inProgress,
        )
        .map((c) => c.courseCode)
        .toSet();
    final ranked = CoursePriorityService().rankCourses(
      student,
      program,
      catalog,
    );
    final freshman = student.classification.toLowerCase() == 'freshman';
    final generator = ScheduleGenerationService();
    final effectivePreferences =
        preferences ??
        SchedulePreferences(
          preferredTime: 'No Preference',
          preferredDays: [],
          avoidedDays: [],
          preferredProfessors: [],
          maxCredits: maxCredits,
          avoidEarlyClasses: false,
          avoidLateClasses: false,
          minimizeGaps: true,
        );
    var states = <_PlanChoice>[const _PlanChoice([], {}, 0, 0)];
    for (final result in ranked) {
      final course = result.course;
      if (used.contains(course.code) ||
          ![
            EligibilityStatus.eligible,
            EligibilityStatus.eligibleAfterCurrentTerm,
          ].contains(result.eligibility.status)) {
        continue;
      }
      final level =
          int.tryParse(
            RegExp(r'\d{3}').firstMatch(course.code)?.group(0) ?? '999',
          ) ??
          999;
      if (freshman && level >= 300) continue;
      if (sections != null &&
          !sections.any(
            (s) => s.courseCode == course.code && s.isOpen && s.hasOpenSeats,
          )) {
        continue;
      }
      // An added lab brings any unsatisfied lecture companion with it.
      // Validate the whole bundle before it can consume credits or a slot.
      final expanded = freshman && course.code == 'AA 111'
          ? <_PlanChoice>[]
          : [...states];
      for (final state in states) {
        if (state.items.any((i) => i.courseCode == course.code)) continue;
        final pending = <CoursePriorityResult>[];
        final visiting = <String>{};
        final included = state.items.map((i) => i.courseCode).toSet();
        bool collect(CoursePriorityResult candidate) {
          final code = candidate.course.code;
          if (included.contains(code) ||
              pending.any((r) => r.course.code == code)) {
            return true;
          }
          if (!visiting.add(code) ||
              used.contains(code) ||
              ![
                EligibilityStatus.eligible,
                EligibilityStatus.eligibleAfterCurrentTerm,
              ].contains(candidate.eligibility.status)) {
            return false;
          }
          final candidateLevel =
              int.tryParse(
                RegExp(r'\d{3}').firstMatch(code)?.group(0) ?? '999',
              ) ??
              999;
          if (freshman && candidateLevel >= 300) return false;
          if (sections != null &&
              !sections.any(
                (s) => s.courseCode == code && s.isOpen && s.hasOpenSeats,
              )) {
            return false;
          }
          for (final companion in candidate.eligibility.requiredCompanions) {
            final matches = ranked.where((r) => r.course.code == companion);
            if (matches.isEmpty || !collect(matches.first)) return false;
          }
          pending.add(candidate);
          visiting.remove(code);
          return true;
        }

        if (!collect(result)) continue;
        final items = [...state.items];
        final allocations = {...state.allocations};
        var credits = state.credits;
        var score = state.score;
        var valid = true;
        for (final addition in pending) {
          final matches = audit.where(
            (a) =>
                a.status == RequirementStatus.remaining &&
                a.requirement.courseCodes.contains(addition.course.code),
          );
          if (matches.isEmpty) {
            valid = false;
            break;
          }
          final requirement = matches.first;
          final allocated = allocations[requirement.requirement.id] ?? 0;
          final budget =
              requirement.requirement.creditsRequired -
              requirement.completedCredits -
              requirement.inProgressCredits;
          if (credits + addition.course.credits > maxCredits ||
              allocated + addition.course.credits > budget) {
            valid = false;
            break;
          }
          items.add(
            SemesterPlanItem(
              type: SemesterPlanItemType.course,
              title: addition.course.title,
              category: addition.course.category,
              courseCode: addition.course.code,
              credits: addition.course.credits,
              reason:
                  '${addition.reasons.join('. ')}. Counts toward ${requirement.requirement.title}.',
              projectedEligibility:
                  addition.eligibility.status ==
                  EligibilityStatus.eligibleAfterCurrentTerm,
              priority: addition,
            ),
          );
          credits += addition.course.credits;
          final preferenceIndex = preferredCourses.indexOf(
            addition.course.code,
          );
          score +=
              addition.score +
              (preferenceIndex < 0 ? 0 : 500 - preferenceIndex);
          allocations[requirement.requirement.id] =
              allocated + addition.course.credits;
        }
        if (!valid) continue;
        if (sections != null) {
          final trial = generator.generateSchedule(
            plan: SemesterPlan(
              items: items,
              totalCredits: credits,
              maxCredits: maxCredits,
            ),
            sections: sections,
            instructors: [],
            preferences: effectivePreferences,
            preferredSections: preferredSections,
          );
          if (trial.unscheduled.isNotEmpty) continue;
        }
        expanded.add(_PlanChoice(items, allocations, credits, score));
      }
      if (expanded.isEmpty) expanded.addAll(states);
      expanded.sort(_compare);
      // Keep multiple course/time combinations, including alternatives within
      // the same requirement. This bounded search does not promise optimality.
      states = expanded.take(48).toList();
    }
    states.sort(_compare);
    final best = states.first;
    final reviewItems = <SemesterPlanItem>[];
    for (final item in audit.where(
      (a) =>
          a.status == RequirementStatus.remaining &&
          ![
            RequirementType.totalCredits,
            RequirementType.minimumGpa,
          ].contains(a.requirement.type),
    )) {
      final remaining =
          item.requirement.creditsRequired -
          item.completedCredits -
          item.inProgressCredits -
          (best.allocations[item.requirement.id] ?? 0);
      if (remaining <= 0) continue;
      final explanations = <String>[];
      for (final code in item.requirement.courseCodes.where(
        (code) =>
            !used.contains(code) &&
            !best.items.any((i) => i.courseCode == code),
      )) {
        final matches = ranked.where((r) => r.course.code == code);
        if (matches.isEmpty) continue;
        final result = matches.first;
        if (result.eligibility.missingPrerequisites.isNotEmpty) {
          explanations.add(
            '$code requires ${result.eligibility.missingPrerequisites.join(', ')}',
          );
        } else if (sections != null &&
            !sections.any(
              (s) => s.courseCode == code && s.isOpen && s.hasOpenSeats,
            )) {
          explanations.add('$code has no open imported sections');
        } else {
          explanations.add(
            '$code did not fit this combination within the credit limit and meeting times',
          );
        }
      }
      reviewItems.add(
        SemesterPlanItem(
          type: SemesterPlanItemType.requirementSlot,
          title: item.requirement.title,
          category: item.requirement.category,
          courseCode:
              item.requirement.type == RequirementType.requiredCourse &&
                  item.requirement.courseCodes.isNotEmpty
              ? item.requirement.courseCodes.first
              : null,
          credits: remaining,
          reason:
              '${explanations.take(3).join('. ')}${explanations.isEmpty ? '' : '. '}Still outstanding; not included in this semester. Confirm prerequisites, placement, approved options and availability with your advisor.',
        ),
      );
    }
    final gap = maxCredits - best.credits;
    return SemesterPlan(
      items: best.items,
      totalCredits: best.credits,
      maxCredits: maxCredits,
      reviewItems: reviewItems,
      shortfallReason: gap <= 0
          ? null
          : '${best.credits.toInt()} of $maxCredits credits planned. The search did not find another verified, eligible course combination within the limit${sections == null ? '' : ' and imported meeting times'}. Remaining requirements may need prerequisites, placement, unavailable sections or additional catalog mapping. Ask your advisor to review the ${gap.toInt()}-credit gap; the limit is not a guarantee.',
    );
  }

  static int _compare(_PlanChoice a, _PlanChoice b) {
    final credits = b.credits.compareTo(a.credits);
    if (credits != 0) return credits;
    final priority = b.score.compareTo(a.score);
    return priority != 0
        ? priority
        : a.items
              .map((i) => i.courseCode)
              .join(',')
              .compareTo(b.items.map((i) => i.courseCode).join(','));
  }
}

class _PlanChoice {
  final List<SemesterPlanItem> items;
  final Map<String, double> allocations;
  final double credits;
  final int score;
  const _PlanChoice(this.items, this.allocations, this.credits, this.score);
}
