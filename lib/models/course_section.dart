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
  final int? openSeats;
  final int? capacity;
  final String? status;
  final double? credits;
  final String? beginDate;
  final String? endDate;

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
    this.openSeats,
    this.capacity,
    this.status,
    this.credits,
    this.beginDate,
    this.endDate,
  });

  String get startTime => _formatTime(startMinutes);

  String get endTime => _formatTime(endMinutes);

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
    if (openSeats == null || capacity == null) {
      return 'Seats unavailable';
    }

    return '$openSeats / $capacity open';
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
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'deliveryMethod': deliveryMethod,
      'courseName': courseName,
      'instructorName': instructorName,
      'openSeats': openSeats,
      'capacity': capacity,
      'status': status,
      'credits': credits,
      'beginDate': beginDate,
      'endDate': endDate,
    };
  }

  factory CourseSection.fromJson(
    Map<String, dynamic> json,
  ) {
    return CourseSection(
      courseCode: json['courseCode'] as String,
      sectionNumber: json['sectionNumber'] as String,
      instructorId: json['instructorId'] as String,
      term: json['term'] as String,
      days: List<String>.from(
        json['days'] as List,
      ),
      startMinutes: json['startMinutes'] as int,
      endMinutes: json['endMinutes'] as int,
      location: json['location'] as String,
      deliveryMethod:
          json['deliveryMethod'] as String,
      courseName: json['courseName'] as String?,
      instructorName:
          json['instructorName'] as String?,
      openSeats: json['openSeats'] as int?,
      capacity: json['capacity'] as int?,
      status: json['status'] as String?,
      credits:
          (json['credits'] as num?)?.toDouble(),
      beginDate: json['beginDate'] as String?,
      endDate: json['endDate'] as String?,
    );
  }
}