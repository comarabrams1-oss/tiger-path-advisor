import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/readiness.dart';
import 'interview_practice_service.dart';

/// Demo progress is stored on this device under the active profile.
class ReadinessProgressService {
  final String profileId;
  const ReadinessProgressService(this.profileId);
  static final revision = ValueNotifier(0);

  String _key(String type, String id) =>
      'readiness_v1_${profileId}_${type}_$id';

  Future<Map<String, InterviewFeedback>> loadFeedback(
    Iterable<InterviewQuestion> questions,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    return {
      for (final question in questions)
        if (preferences.getString(_key('review', question.id)) case final raw?)
          question.id: InterviewFeedback.fromJson(jsonDecode(raw)),
    };
  }

  Future<ReadinessProfile> loadProfile({
    List<InterviewQuestion>? questions,
  }) async {
    final bank =
        questions ??
        await InterviewPracticeService.loadQuestions().catchError(
          (Object _) => <InterviewQuestion>[],
        );
    final storage = await SharedPreferences.getInstance();
    final entries = <String, ReadinessEntry>{};
    final reviewed = bank
        .where(
          (question) => storage.getString(_key('review', question.id)) != null,
        )
        .length;
    for (final id in [
      ...careerMilestones,
      ...graduateMilestones,
    ].map((m) => m.id).toSet()) {
      final raw = storage.getString(_key('entry', id));
      if (raw != null) {
        entries[id] = ReadinessEntry.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } else if (storage.getBool(_key('milestone', id)) == true) {
        // Keep progress from the original Readiness checklist.
        entries[id] = const ReadinessEntry(status: ReadinessStatus.complete);
      }
    }
    return ReadinessProfile(
      entries: Map.unmodifiable(entries),
      targetGpa: storage.getDouble(_key('target', 'gpa')),
      interviewQuestionsReviewed: reviewed,
      interviewQuestionCount: bank.length,
    );
  }

  Future<void> saveFeedback(
    String questionId,
    InterviewFeedback feedback,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(
      _key('review', questionId),
      jsonEncode(feedback.toJson()),
    )) {
      throw StateError('Could not save practice feedback');
    }
    revision.value++;
  }

  Future<void> setEntry(String id, ReadinessEntry entry) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(
      _key('entry', id),
      jsonEncode(entry.toJson()),
    )) {
      throw StateError('Could not save readiness milestone');
    }
    revision.value++;
  }

  Future<void> setTargetGpa(double? target) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _key('target', 'gpa');
    final saved = target == null
        ? await preferences.remove(key)
        : await preferences.setDouble(key, target);
    if (!saved) throw StateError('Could not save GPA target');
    revision.value++;
  }
}
