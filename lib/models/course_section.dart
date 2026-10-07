class CourseMeeting {
  final List<String> days;
  final int? startMinutes;
  final int? endMinutes;
  final String? location;
  final String? rawText;

  const CourseMeeting({
    this.days = const [],
    this.startMinutes,
    this.endMinutes,
    this.location,
    this.rawText,
  });

  bool get hasTime {
    return startMinutes != null &&
        endMinutes != null &&
        endMinutes! > startMinutes!;
  }

  String get startTime {
    if (!hasTime) {
      return 'TBA';
    }

    return _formatTime(startMinutes!);
  }

  String get endTime {
    if (!hasTime) {
      return 'TBA';
    }

    return _formatTime(endMinutes!);
  }

  String get displayText {
    if (rawText != null && rawText!.trim().isNotEmpty) {
      return rawText!.trim();
    }

    final parts = <String>[];

    if (days.isNotEmpty) {
      parts.add(days.join(''));
    }

    if (hasTime) {
      parts.add('$startTime - $endTime');
    } else {
      parts.add('TBA');
    }

    if (location != null && location!.trim().isNotEmpty) {
      parts.add(location!.trim());
    }

    return parts.join(' • ');
  }

  Map<String, dynamic> toJson() {
    return {
      'days': days,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'location': location,
      'rawText': rawText,
    };
  }

  factory CourseMeeting.fromJson(
    Map<String, dynamic> json,
  ) {
    return CourseMeeting(
      days: List<String>.from(
        json['days'] as List? ?? const [],
      ),
      startMinutes:
          (json['startMinutes'] as num?)?.toInt(),
      endMinutes:
          (json['endMinutes'] as num?)?.toInt(),
      location: json['location'] as String?,
      rawText: json['rawText'] as String?,
    );
  }

  static String _formatTime(int minutes) {
    final hour24 = minutes ~/ 60;
    final minute = minutes % 60;

    final period = hour24 >= 12 ? 'PM' : 'AM';

    var hour12 = hour24 % 12;

    if (hour12 == 0) {
      hour12 = 12;
    }

    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }
}

class CourseSection {
  final String courseCode;
  final String sectionNumber;
  final String instructorId;
  final String term;
  final List<String> days;
  final int startMinutes;
  final int endMinutes;
  final String location;
  final String deliveryMethod;

  final String? courseName;
  final String? instructorName;
  final List<String> instructorNames;
  final int? openSeats;
  final int? capacity;
  final String? status;
  final double? credits;
  final String? beginDate;
  final String? endDate;
  final String? rawSchedule;
  final List<CourseMeeting> meetings;

  const CourseSection({
    required this.courseCode,
    required this.sectionNumber,
    required this.instructorId,
    required this.term,
    required this.days,
    required this.startMinutes,
    required this.endMinutes,
    required this.location,
    required this.deliveryMethod,
    this.courseName,
    this.instructorName,
    this.instructorNames = const [],
    this.openSeats,
    this.capacity,
    this.status,
    this.credits,
    this.beginDate,
    this.endDate,
    this.rawSchedule,
    this.meetings = const [],
  });

  String get fullCourseCode {
    if (sectionNumber.trim().isEmpty) {
      return courseCode;
    }

    return '$courseCode $sectionNumber';
  }

  bool get hasPrimaryMeetingTime {
    return startMinutes >= 0 && endMinutes > startMinutes;
  }

  String get startTime {
    if (!hasPrimaryMeetingTime) {
      return 'TBA';
    }

    return _formatTime(startMinutes);
  }

  String get endTime {
    if (!hasPrimaryMeetingTime) {
      return 'TBA';
    }

    return _formatTime(endMinutes);
  }

  List<String> get allInstructorNames {
    final names = <String>[];

    if (instructorName != null &&
        instructorName!.trim().isNotEmpty) {
      names.add(instructorName!.trim());
    }

    for (final name in instructorNames) {
      final cleaned = name.trim();

      if (cleaned.isNotEmpty && !names.contains(cleaned)) {
        names.add(cleaned);
      }
    }

    return names;
  }

  String get instructorDisplay {
    final names = allInstructorNames;

    if (names.isEmpty) {
      return 'Staff';
    }

    return names.join(', ');
  }

  bool get hasOpenSeats {
    if (openSeats == null) {
      return true;
    }

    return openSeats! > 0;
  }

  bool get isOpen {
    if (status == null || status!.trim().isEmpty) {
      return true;
    }

    final normalized = status!.trim().toLowerCase();

    return !normalized.contains('closed') &&
        !normalized.contains('cancel') &&
        !normalized.contains('full');
  }

  String get seatDisplay {
    if (openSeats != null && capacity != null) {
      return '$openSeats / $capacity open';
    }

    if (openSeats != null) {
      return '$openSeats open';
    }

    if (capacity != null) {
      return 'Capacity $capacity';
    }

    return 'Seats unavailable';
  }

  String get scheduleDisplay {
    if (meetings.isNotEmpty) {
      return meetings
          .map((meeting) => meeting.displayText)
          .join(' | ');
    }

    if (rawSchedule != null &&
        rawSchedule!.trim().isNotEmpty) {
      return rawSchedule!.trim();
    }

    final parts = <String>[];

    if (days.isNotEmpty) {
      parts.add(days.join(''));
    }

    if (hasPrimaryMeetingTime) {
      parts.add('$startTime - $endTime');
    } else {
      parts.add('TBA');
    }

    if (location.trim().isNotEmpty) {
      parts.add(location);
    }

    return parts.join(' • ');
  }

  String _formatTime(int minutes) {
    final hour24 = minutes ~/ 60;
    final minute = minutes % 60;

    final period = hour24 >= 12 ? 'PM' : 'AM';

    var hour12 = hour24 % 12;

    if (hour12 == 0) {
      hour12 = 12;
    }

    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  Map<String, dynamic> toJson() {
    return {
      'courseCode': courseCode,
      'sectionNumber': sectionNumber,
      'instructorId': instructorId,
      'term': term,
      'days': days,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'location': location,
      'deliveryMethod': deliveryMethod,
      'courseName': courseName,
      'instructorName': instructorName,
      'instructorNames': instructorNames,
      'openSeats': openSeats,
      'capacity': capacity,
      'status': status,
      'credits': credits,
      'beginDate': beginDate,
      'endDate': endDate,
      'rawSchedule': rawSchedule,
      'meetings':
          meetings.map((meeting) => meeting.toJson()).toList(),
    };
  }

  factory CourseSection.fromJson(
    Map<String, dynamic> json,
  ) {
    return CourseSection(
      courseCode: json['courseCode'] as String? ?? '',
      sectionNumber:
          json['sectionNumber'] as String? ?? '',
      instructorId:
          json['instructorId'] as String? ?? '',
      term: json['term'] as String? ?? '',
      days: List<String>.from(
        json['days'] as List? ?? const [],
      ),
      startMinutes:
          (json['startMinutes'] as num?)?.toInt() ?? 0,
      endMinutes:
          (json['endMinutes'] as num?)?.toInt() ?? 0,
      location: json['location'] as String? ?? '',
      deliveryMethod:
          json['deliveryMethod'] as String? ?? 'Unknown',
      courseName: json['courseName'] as String?,
      instructorName:
          json['instructorName'] as String?,
      instructorNames: List<String>.from(
        json['instructorNames'] as List? ?? const [],
      ),
      openSeats:
          (json['openSeats'] as num?)?.toInt(),
      capacity:
          (json['capacity'] as num?)?.toInt(),
      status: json['status'] as String?,
      credits:
          (json['credits'] as num?)?.toDouble(),
      beginDate: json['beginDate'] as String?,
      endDate: json['endDate'] as String?,
      rawSchedule: json['rawSchedule'] as String?,
      meetings:
          (json['meetings'] as List? ?? const [])
              .map(
                (meeting) => CourseMeeting.fromJson(
                  Map<String, dynamic>.from(
                    meeting as Map,
                  ),
                ),
              )
              .toList(),
    );
  }
}