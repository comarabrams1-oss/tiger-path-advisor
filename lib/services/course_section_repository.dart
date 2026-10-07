import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/course_section.dart';

class CourseSectionRepository {
  static const String fall2026Term =
      '2026-2027 - Fall - Full Semester';

  static const Map<String, String> _termAssets = {
    fall2026Term:
        'assets/data/course_sections_fall_2026.json',
  };

  static List<String> get availableTerms {
    return _termAssets.keys.toList();
  }

  static bool hasTerm(String term) {
    return _termAssets.containsKey(term);
  }

  static Future<List<CourseSection>> loadForTerm(
    String term,
  ) async {
    final assetPath = _termAssets[term];

    if (assetPath == null) {
      return [];
    }

    final rawJson = await rootBundle.loadString(
      assetPath,
    );

    final decoded = jsonDecode(rawJson);

    if (decoded is! List) {
      throw const FormatException(
        'Course section data must be a JSON list.',
      );
    }

    final sections = <CourseSection>[];

    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }

      final json =
          Map<String, dynamic>.from(item);

      final section =
          CourseSection.fromJson(json);

      if (section.courseCode.trim().isEmpty) {
        continue;
      }

      if (section.sectionNumber.trim().isEmpty) {
        continue;
      }

      sections.add(section);
    }

    return sections;
  }

  static Future<List<CourseSection>>
      loadFall2026() {
    return loadForTerm(fall2026Term);
  }

  static Future<List<CourseSection>>
      loadCourse(
    String term,
    String courseCode,
  ) async {
    final sections =
        await loadForTerm(term);

    return sections
        .where(
          (section) =>
              section.courseCode
                  .trim()
                  .toUpperCase() ==
              courseCode.trim().toUpperCase(),
        )
        .toList();
  }

  static Future<List<CourseSection>>
      loadOpenSections(
    String term,
  ) async {
    final sections =
        await loadForTerm(term);

    return sections
        .where(
          (section) =>
              section.isOpen &&
              section.hasOpenSeats,
        )
        .toList();
  }
}