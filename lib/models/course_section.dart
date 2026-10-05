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
  });

  String get startTime => _formatTime(startMinutes);

  String get endTime => _formatTime(endMinutes);

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
    };
  }
}