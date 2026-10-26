import 'dart:convert';
import 'dart:io';

import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/services/tiger_portal_parser.dart';

void main() {
  final inputDirectory = Directory(
    'private_data/pages',
  );

  if (!inputDirectory.existsSync()) {
    stderr.writeln(
      'Folder not found: private_data/pages',
    );
    exitCode = 1;
    return;
  }

  final htmlFiles = inputDirectory
      .listSync()
      .whereType<File>()
      .where(
        (file) =>
            file.path.toLowerCase().endsWith('.html'),
      )
      .toList()
    ..sort(
      (a, b) => a.path.compareTo(b.path),
    );

  if (htmlFiles.isEmpty) {
    stderr.writeln(
      'No HTML files found in private_data/pages.',
    );
    exitCode = 1;
    return;
  }

  final sections = <CourseSection>[];
  final seen = <String>{};

  for (final file in htmlFiles) {
    final html = file.readAsStringSync();

    final parsed =
        TigerPortalParser.parseCourseSections(html);

    stdout.writeln(
      '${file.path}: ${parsed.length} sections',
    );

    for (final section in parsed) {
      final key = [
        section.term,
        section.courseCode,
        section.sectionNumber,
        section.beginDate ?? '',
        section.endDate ?? '',
      ].join('|');

      if (seen.add(key)) {
        sections.add(section);
      }
    }
  }

  sections.sort((a, b) {
    final courseComparison =
        a.courseCode.compareTo(b.courseCode);

    if (courseComparison != 0) {
      return courseComparison;
    }

    return a.sectionNumber.compareTo(
      b.sectionNumber,
    );
  });

  final outputFile = File(
    'private_data/course_sections_all.json',
  );

  final json = const JsonEncoder.withIndent(
    '  ',
  ).convert(
    sections
        .map((section) => section.toJson())
        .toList(),
  );

  outputFile.writeAsStringSync(json);

  stdout.writeln('');
  stdout.writeln(
    'Unique sections exported: ${sections.length}',
  );
  stdout.writeln(
    'Saved to: ${outputFile.path}',
  );
}