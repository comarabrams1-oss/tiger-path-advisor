import 'dart:convert';
import 'dart:io';

import 'package:tiger_path/services/tiger_portal_parser.dart';

void main() {
  final inputFile = File(
    'private_data/tiger_portal_results.html',
  );

  if (!inputFile.existsSync()) {
    stderr.writeln(
      'Tiger Portal HTML file not found.',
    );
    exitCode = 1;
    return;
  }

  final html = inputFile.readAsStringSync();

  final sections =
      TigerPortalParser.parseCourseSections(html);

  final outputDirectory = Directory(
    'private_data',
  );

  if (!outputDirectory.existsSync()) {
    outputDirectory.createSync(
      recursive: true,
    );
  }

  final outputFile = File(
    'private_data/course_sections.json',
  );

  final json = const JsonEncoder.withIndent(
    '  ',
  ).convert(
    sections
        .map((section) => section.toJson())
        .toList(),
  );

  outputFile.writeAsStringSync(json);

  stdout.writeln(
    'Exported ${sections.length} sections.',
  );

  stdout.writeln(
    'Saved to: ${outputFile.path}',
  );
}