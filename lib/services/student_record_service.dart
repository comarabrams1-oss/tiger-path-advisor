import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/program_registry.dart';
import '../models/academic_term.dart';
import '../models/student.dart';
import '../models/student_course.dart';

class StudentRecordService {
  static final revision = ValueNotifier(0);

  static String _key(String profile) => 'transcript_v1_$profile';
  static String _targetKey(String profile) => 'graduation_target_v1_$profile';

  Future<AcademicTerm?> loadTarget(String profile) async {
    final storage = await SharedPreferences.getInstance();
    return AcademicTerm.parse(storage.getString(_targetKey(profile)) ?? '');
  }

  Future<void> saveTarget(String profile, AcademicTerm target) async {
    final storage = await SharedPreferences.getInstance();
    if (!await storage.setString(_targetKey(profile), target.label)) {
      throw StateError('Graduation target could not be saved.');
    }
  }

  static AcademicTerm currentTerm(Student student) {
    return student.courses
        .map((course) => AcademicTerm.parse(course.term))
        .whereType<AcademicTerm>()
        .fold(
          AcademicTerm.demoTerm,
          (latest, term) => term.compareTo(latest) > 0 ? term : latest,
        );
  }

  static String classificationFor(double credits) => switch (credits) {
    >= 90 => 'Senior',
    >= 60 => 'Junior',
    >= 30 => 'Sophomore',
    _ => 'Freshman',
  };

  static Map<String, double> creditHoursFor(Student student) => {
    // Legacy attempts outside the current program can carry explicit hours.
    for (final course in catalogFor(student)) course.code: course.credits,
    for (final course in student.courses)
      course.courseCode: ?course.creditHours,
  };

  Future<Student> load(String profile, Student baseline) async {
    final storage = await SharedPreferences.getInstance();
    final raw = storage.getString(_key(profile));
    if (raw == null) return baseline;
    final value = jsonDecode(raw);
    if (value is! List || value.length > 300) {
      throw const FormatException('Invalid saved transcript.');
    }
    return calculate(
      baseline,
      value.map((entry) {
        final map = entry as Map<String, dynamic>;
        return StudentCourse(
          courseCode: map['courseCode'] as String,
          term: map['term'] as String,
          status: CourseStatus.values.byName(map['status'] as String),
          grade: map['grade'] as String?,
          creditHours: (map['creditHours'] as num?)?.toDouble(),
          isTransfer: map['isTransfer'] == true,
          approvedElectiveId: map['approvedElectiveId'] as String?,
        );
      }).toList(),
    );
  }

  Future<Student> save(
    String profile,
    Student baseline,
    List<StudentCourse> attempts,
  ) async {
    if (attempts.length > 300) {
      throw const FormatException(
        'This demo supports up to 300 course attempts.',
      );
    }
    final student = calculate(baseline, attempts);
    final storage = await SharedPreferences.getInstance();
    if (!await storage.setString(_key(profile), jsonEncode(attempts))) {
      throw StateError('Transcript could not be saved.');
    }
    return student;
  }

  Student calculate(Student baseline, List<StudentCourse> attempts) {
    final hours = creditHoursFor(baseline);
    final before = metrics(baseline.courses, hours);
    final after = metrics(attempts, hours);
    final earned = math.max(
      0.0,
      baseline.earnedCredits + after.earned - before.earned,
    );
    // Some demo profiles supply cumulative credits and GPA for a partial
    // transcript. Keep the unlisted starting balance when editing visible rows.
    final unlistedGraded = math.max(
      0.0,
      baseline.earnedCredits - before.earned,
    );
    final gpaHours = after.gpaHours + unlistedGraded;
    final gpa = gpaHours == 0
        ? 0.0
        : (after.points + unlistedGraded * baseline.gpa) / gpaHours;
    return baseline.copyWith(
      courses: List.unmodifiable(attempts),
      earnedCredits: earned,
      inProgressCredits: after.inProgress,
      classification: classificationFor(earned),
      gpa: gpa,
      hasCalculatedGpa: gpaHours > 0,
      hasLocalRecord: true,
    );
  }

  static RecordMetrics metrics(
    Iterable<StudentCourse> courses,
    Map<String, double> hours,
  ) {
    final groups = <String, List<StudentCourse>>{};
    for (final course in courses) {
      (groups[course.courseCode] ??= []).add(course);
    }
    double earned = 0,
        transfer = 0,
        inProgress = 0,
        attempted = 0,
        points = 0,
        gpaHours = 0;
    for (final attempts in groups.values) {
      double credits(StudentCourse attempt) =>
          attempt.creditHours ?? hours[attempt.courseCode] ?? 0;
      final passed = attempts.where(
        (attempt) => attempt.meetsMinimumGrade(null),
      );
      if (passed.isNotEmpty) {
        earned += passed.map(credits).reduce(math.max);
        final acceptedTransfer = passed.where((attempt) => attempt.transfer);
        if (acceptedTransfer.isNotEmpty) {
          transfer += acceptedTransfer.map(credits).reduce(math.max);
        }
      } else {
        final current = attempts.where(
          (attempt) => attempt.status == CourseStatus.inProgress,
        );
        if (current.isNotEmpty) {
          inProgress += current.map(credits).reduce(math.max);
        }
      }
      final finalized = attempts.where(
        (attempt) => attempt.status == CourseStatus.completed,
      );
      attempted += finalized
          .where((a) => a.normalizedGrade != 'AU')
          .fold(0.0, (sum, a) => sum + credits(a));
      final grades = finalized
          .where(
            (a) =>
                !a.transfer &&
                StudentCourse.gradePoints.containsKey(a.normalizedGrade),
          )
          .toList();
      grades.sort(
        (a, b) => (AcademicTerm.parse(a.term) ?? AcademicTerm.demoTerm)
            .compareTo(AcademicTerm.parse(b.term) ?? AcademicTerm.demoTerm),
      );
      final forgiveness = grades.length < 2
          ? -1
          : StudentCourse.gradePoints[grades[0].normalizedGrade]! <=
                StudentCourse.gradePoints[grades[1].normalizedGrade]!
          ? 0
          : 1;
      for (var i = 0; i < grades.length; i++) {
        if (i == forgiveness) continue;
        final grade = grades[i];
        gpaHours += credits(grade);
        points +=
            credits(grade) * StudentCourse.gradePoints[grade.normalizedGrade]!;
      }
    }
    return RecordMetrics(
      earned,
      transfer,
      inProgress,
      attempted,
      points,
      gpaHours,
    );
  }
}

class RecordMetrics {
  final double earned;
  final double transfer;
  final double inProgress;
  final double attempted;
  final double points;
  final double gpaHours;
  const RecordMetrics(
    this.earned,
    this.transfer,
    this.inProgress,
    this.attempted,
    this.points,
    this.gpaHours,
  );

  double? get gpa => gpaHours == 0 ? null : points / gpaHours;
}
