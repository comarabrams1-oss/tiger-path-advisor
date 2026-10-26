import 'package:html/parser.dart' as html_parser;

import '../models/course_section.dart';

class TigerPortalParser {
  static List<CourseSection> parseCourseSections(String html) {
    final document = html_parser.parse(html);

    final table = document.querySelector('#pg0_V_dgCourses');

    if (table == null) {
      return [];
    }

    final term = _parseTerm(document);

    final tbody = table.querySelector('tbody');

    if (tbody == null) {
      return [];
    }

    final sections = <CourseSection>[];

    for (final row in tbody.children) {
      if (row.localName != 'tr') {
        continue;
      }

      if (row.classes.contains('subItem')) {
        continue;
      }

      final cells = row.children
          .where((element) => element.localName == 'td')
          .toList();

      if (cells.length < 11) {
        continue;
      }

      final fullCourseCode = _cleanText(cells[2].text);

      if (fullCourseCode.isEmpty) {
        continue;
      }

      final courseParts = _splitCourseCode(fullCourseCode);

      final courseCode = courseParts.courseCode;
      final sectionNumber = courseParts.sectionNumber;

      final courseName = _cleanText(cells[3].text);

      final instructorNames = cells[4]
          .querySelectorAll('.ju-word-wrap')
          .map((element) => _cleanText(element.text))
          .where((name) => name.isNotEmpty)
          .toList();

      if (instructorNames.isEmpty) {
        final fallbackInstructor = _cleanText(cells[4].text);

        if (fallbackInstructor.isNotEmpty) {
          instructorNames.add(fallbackInstructor);
        }
      }

      final seatInfo = _parseSeats(_cleanText(cells[5].text));

      final status = _cleanText(cells[6].text);

      final scheduleItems = cells[7]
          .querySelectorAll('li')
          .map((element) => _cleanText(element.text))
          .where((text) => text.isNotEmpty)
          .toList();

      if (scheduleItems.isEmpty) {
        final scheduleText = _cleanText(cells[7].text);

        if (scheduleText.isNotEmpty) {
          scheduleItems.add(scheduleText);
        }
      }

      final meetings = scheduleItems.map(_parseMeeting).toList();

      CourseMeeting? primaryMeeting;

      for (final meeting in meetings) {
        if (meeting.hasTime) {
          primaryMeeting = meeting;
          break;
        }
      }

      if (primaryMeeting == null && meetings.isNotEmpty) {
        primaryMeeting = meetings.first;
      }

      final credits = double.tryParse(_cleanText(cells[8].text));

      final beginDate = _nullIfEmpty(_cleanText(cells[9].text));

      final endDate = _nullIfEmpty(_cleanText(cells[10].text));

      final rawSchedule = scheduleItems.isEmpty
          ? null
          : scheduleItems.join(' | ');

      sections.add(
        CourseSection(
          courseCode: courseCode,
          sectionNumber: sectionNumber,
          instructorId: '',
          term: term,
          days: primaryMeeting?.days ?? const [],
          startMinutes: primaryMeeting?.startMinutes ?? 0,
          endMinutes: primaryMeeting?.endMinutes ?? 0,
          location: primaryMeeting?.location ?? 'TBA',
          deliveryMethod: _detectDeliveryMethod(scheduleItems),
          courseName: _nullIfEmpty(courseName),
          instructorName: instructorNames.isNotEmpty
              ? instructorNames.first
              : null,
          instructorNames: instructorNames,
          openSeats: seatInfo.openSeats,
          capacity: seatInfo.capacity,
          status: _nullIfEmpty(status),
          credits: credits,
          beginDate: beginDate,
          endDate: endDate,
          rawSchedule: rawSchedule,
          meetings: meetings,
        ),
      );
    }

    return sections;
  }

  static String parseTerm(String html) {
    final document = html_parser.parse(html);

    return _parseTerm(document);
  }

  static String _parseTerm(dynamic document) {
    final selected = document.querySelector('#pg0_V_ddlTerm option[selected]');

    if (selected != null) {
      return _cleanText(selected.text);
    }

    // Never guess a term from the first option in a saved page.
    return '';
  }

  static _CourseCodeParts _splitCourseCode(String value) {
    final parts = value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length < 2) {
      return _CourseCodeParts(courseCode: value, sectionNumber: '');
    }

    if (parts.length == 2) {
      return _CourseCodeParts(courseCode: value, sectionNumber: '');
    }

    return _CourseCodeParts(
      courseCode: parts.take(2).join(' '),
      sectionNumber: parts.skip(2).join(' '),
    );
  }

  static _SeatInfo _parseSeats(String value) {
    final match = RegExp(r'(\d+)\s*/\s*(\d+)').firstMatch(value);

    if (match == null) {
      return const _SeatInfo();
    }

    return _SeatInfo(
      openSeats: int.tryParse(match.group(1) ?? ''),
      capacity: int.tryParse(match.group(2) ?? ''),
    );
  }

  static CourseMeeting _parseMeeting(String value) {
    final cleaned = _cleanText(value);

    final pieces = cleaned
        .split(';')
        .map((piece) => piece.trim())
        .where((piece) => piece.isNotEmpty)
        .toList();

    final meetingPart = pieces.isNotEmpty ? pieces.first : cleaned;

    final location = pieces.length > 1 ? pieces.sublist(1).join('; ') : null;

    final timeMatch = RegExp(
      r'^([A-Za-z]+)\s+'
      r'(\d{1,2}):(\d{2})\s*(AM|PM)'
      r'\s*-\s*'
      r'(\d{1,2}):(\d{2})\s*(AM|PM)',
      caseSensitive: false,
    ).firstMatch(meetingPart);

    if (timeMatch == null) {
      return CourseMeeting(location: _nullIfEmpty(location), rawText: cleaned);
    }

    final rawDays = timeMatch.group(1) ?? '';

    final startMinutes = _timeToMinutes(
      int.tryParse(timeMatch.group(2) ?? ''),
      int.tryParse(timeMatch.group(3) ?? ''),
      timeMatch.group(4),
    );

    final endMinutes = _timeToMinutes(
      int.tryParse(timeMatch.group(5) ?? ''),
      int.tryParse(timeMatch.group(6) ?? ''),
      timeMatch.group(7),
    );

    return CourseMeeting(
      days: _parseDays(rawDays),
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      location: _nullIfEmpty(location),
      rawText: cleaned,
    );
  }

  static List<String> _parseDays(String value) {
    final days = <String>[];

    for (final character in value.toUpperCase().split('')) {
      final day = switch (character) {
        'M' => 'Monday',
        'T' => 'Tuesday',
        'W' => 'Wednesday',
        'R' => 'Thursday',
        'F' => 'Friday',
        'S' => 'Saturday',
        'U' => 'Sunday',
        _ => null,
      };

      if (day != null && !days.contains(day)) {
        days.add(day);
      }
    }

    return days;
  }

  static int? _timeToMinutes(int? hour, int? minute, String? period) {
    if (hour == null || minute == null || period == null) {
      return null;
    }

    var normalizedHour = hour;

    final normalizedPeriod = period.toUpperCase();

    if (normalizedPeriod == 'AM') {
      if (normalizedHour == 12) {
        normalizedHour = 0;
      }
    } else if (normalizedPeriod == 'PM') {
      if (normalizedHour != 12) {
        normalizedHour += 12;
      }
    }

    return normalizedHour * 60 + minute;
  }

  static String _detectDeliveryMethod(List<String> schedules) {
    final combined = schedules.join(' ').toLowerCase();

    if (combined.contains('online') || combined.contains('web')) {
      return 'Online';
    }

    if (combined.contains('hybrid')) {
      return 'Hybrid';
    }

    if (combined.contains('tba') || schedules.isEmpty) {
      return 'Unknown';
    }

    return 'In Person';
  }

  static String _cleanText(String value) {
    return value
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String? _nullIfEmpty(String? value) {
    if (value == null) {
      return null;
    }

    final cleaned = value.trim();

    return cleaned.isEmpty ? null : cleaned;
  }
}

class _CourseCodeParts {
  final String courseCode;
  final String sectionNumber;

  const _CourseCodeParts({
    required this.courseCode,
    required this.sectionNumber,
  });
}

class _SeatInfo {
  final int? openSeats;
  final int? capacity;

  const _SeatInfo({this.openSeats, this.capacity});
}
