import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'interview_practice_service.dart';

/// Demo progress is stored on this device under the active profile.
class ReadinessProgressService {
  final String profileId;
  const ReadinessProgressService(this.profileId);

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

  Future<Set<String>> loadMilestones(Iterable<String> ids) async {
    final preferences = await SharedPreferences.getInstance();
    return {
      for (final id in ids)
        if (preferences.getBool(_key('milestone', id)) == true) id,
    };
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
  }

  Future<void> setMilestone(String id, bool completed) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(_key('milestone', id), completed)) {
      throw StateError('Could not save readiness milestone');
    }
  }
}
