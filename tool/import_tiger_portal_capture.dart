import 'dart:convert';
import 'dart:io';

import 'package:tiger_path/models/course_section.dart';
import 'package:tiger_path/services/tiger_portal_parser.dart';

/// Only parsed section fields are exported; HTML and session data stay private.
void main(List<String> args) {
  try {
    if (args.length != 3) {
      throw const FormatException(
        'Usage: dart run tool/import_tiger_portal_capture.dart '
        '<sanitized-capture.json> <exact-term> <output.json>',
      );
    }
    final capture = jsonDecode(File(args[0]).readAsStringSync());
    if (capture is! Map || capture['pages'] is! List) {
      throw const FormatException('Capture must contain a pages list.');
    }
    final expectedTerm = args[1].trim();
    final sections = <String, CourseSection>{};
    var matchingPages = 0;
    var duplicates = 0;
    for (final page in capture['pages'] as List) {
      if (page is! Map || page['html'] is! String) {
        throw const FormatException('Each page must contain HTML.');
      }
      final html = page['html'] as String;
      if (TigerPortalParser.parseTerm(html) != expectedTerm) continue;
      matchingPages++;
      final parsed = TigerPortalParser.parseCourseSections(html);
      if (parsed.isEmpty) {
        throw const FormatException(
          'A selected page has no parseable sections.',
        );
      }
      for (final section in parsed) {
        validateSection(section, expectedTerm);
        final key = [
          section.courseCode,
          section.sectionNumber,
          section.beginDate,
          section.endDate,
        ].join('|');
        final previous = sections[key];
        if (previous != null) {
          if (jsonEncode(previous.toJson()) != jsonEncode(section.toJson())) {
            throw const FormatException(
              'Conflicting duplicate sections. Recapture the term.',
            );
          }
          duplicates++;
        }
        sections[key] = section;
      }
    }
    if (sections.isEmpty) {
      throw const FormatException('No sections matched the requested term.');
    }
    final sorted = sections.values.toList()
      ..sort(
        (a, b) => '${a.courseCode}|${a.sectionNumber}|${a.beginDate}'.compareTo(
          '${b.courseCode}|${b.sectionNumber}|${b.beginDate}',
        ),
      );
    final output = File(args[2]);
    if (output.existsSync()) {
      throw const FormatException(
        'Output exists. Choose a new file and review before replacing.',
      );
    }
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(sorted.map((s) => s.toJson()).toList())}\n',
    );
    stdout.writeln('Term: $expectedTerm');
    stdout.writeln(
      'Matching pages: $matchingPages; duplicate rows: $duplicates',
    );
    stdout.writeln(
      'Sections: ${sorted.length}; courses: '
      '${sorted.map((s) => s.courseCode).toSet().length}; open sections: '
      '${sorted.where((s) => s.isOpen && s.hasOpenSeats).length}',
    );
    stdout.writeln(
      'TBA sections: ${sorted.where((s) => !s.hasPrimaryMeetingTime).length}',
    );
  } on Object catch (error) {
    // Never echo capture contents, paths containing session URLs, or raw errors.
    stderr.writeln(
      error is FormatException ? error.message : 'Import failed. Check the local input format and output permissions.',
    );
    exitCode = 1;
  }
}

void validateSection(CourseSection section, String term) {
  if (section.term != term ||
      !RegExp(r'^[A-Z]+\s+\d+[A-Z]*$').hasMatch(section.courseCode) ||
      !RegExp(r'^[A-Za-z0-9-]+(?: [A-Za-z0-9-]+)*$')
          .hasMatch(section.sectionNumber) ||
      section.credits == null ||
      section.credits! < 0 ||
      (section.openSeats != null && section.openSeats! < 0) ||
      (section.capacity != null && section.capacity! < 0) ||
      (section.openSeats != null &&
          section.capacity != null &&
          section.openSeats! > section.capacity!)) {
    throw const FormatException(
      'Invalid section identity, term, credits, or seats.',
    );
  }
  for (final meeting in section.meetings) {
    if ((meeting.startMinutes == null) != (meeting.endMinutes == null) ||
        (meeting.startMinutes != null &&
            (meeting.startMinutes! < 0 ||
                meeting.endMinutes! > 1440 ||
                meeting.endMinutes! <= meeting.startMinutes! ||
                meeting.days.isEmpty))) {
      throw const FormatException('Invalid meeting time or days.');
    }
  }
}
