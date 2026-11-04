import '../data/program_registry.dart';
import '../models/degree_program.dart';

class ProgramCheck {
  final String major;
  final List<String> errors;
  final List<String> review;
  const ProgramCheck(this.major, this.errors, this.review);
}

/// Checks every registered program automatically; reference pages are not rules.
class ProgramCheckService {
  static List<ProgramCheck> checkAll() => [
    for (final major in programMappings.keys) check(major),
  ];
  static ProgramCheck check(String major) {
    final program = programMappings[major]!, catalog = catalogMappings[major]!;
    final errors = <String>[], review = <String>[];
    final codes = catalog.map((c) => c.code).toSet();
    if (codes.length != catalog.length) {
      errors.add('Duplicate course codes in the catalog.');
    }
    final ids = program.requirements.map((r) => r.id).toSet();
    if (ids.length != program.requirements.length) {
      errors.add('Duplicate requirement identifiers.');
    }
    final credits = program.requirements
        .where((r) => r.category != 'Graduation')
        .fold<double>(0, (sum, r) => sum + r.creditsRequired);
    if (credits != program.totalCreditsRequired) {
      errors.add(
        'Mapped requirements total $credits credits; catalog total is ${program.totalCreditsRequired}.',
      );
    }
    for (final r in program.requirements.where(
      (r) => r.courseCodes.isNotEmpty,
    )) {
      final missing = r.courseCodes.where((c) => !codes.contains(c)).toList();
      if (missing.isNotEmpty) {
        if (r.type == RequirementType.requiredCourse ||
            missing.length == r.courseCodes.length) {
          errors.add('${r.title}: no mapped course for ${missing.join(', ')}.');
        } else {
          review.add(
            '${r.title}: some catalog alternatives still need course rules (${missing.join(', ')}).',
          );
        }
      }
    }
    final dependencies = {
      for (final c in catalog.where(
        (c) => program.requirements.any((r) => r.courseCodes.contains(c.code)),
      ))
        ...[
          ...c.prerequisiteGroups.expand((g) => g),
          ...c.corequisiteCodes,
        ].where((d) => !codes.contains(d)),
    };
    if (dependencies.isNotEmpty) {
      review.add(
        'Prerequisite or placement verification: ${dependencies.join(', ')}. Do not assume equivalencies.',
      );
    }
    if (major == 'Electrical Engineering') {
      review.add(
        'The printed EE 333 prerequisite is PHYS 244. Confirm it with an advisor; PHYS 234 is not substituted automatically.',
      );
    }
    if (major == 'Physics') {
      review.add(
        'Free electives need explicit audit approval; service-learning completion is not inferred.',
      );
    }
    return ProgramCheck(major, errors, review);
  }
}
