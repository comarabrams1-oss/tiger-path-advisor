import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ai_advisor_service.dart';

class AdvisorConversation {
  final String id;
  final String title;
  final List<AdvisorMessage> messages;
  final Map<String, String> requirementStatuses;
  const AdvisorConversation({
    required this.id,
    required this.title,
    required this.messages,
    this.requirementStatuses = const {},
  });
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toStorageJson()).toList(),
    'requirementStatuses': requirementStatuses,
  };
}

/// Browser/device-local history, isolated to the current demo profile.
/// Replace profileId with an authenticated stable student ID when accounts exist.
class AdvisorHistoryService {
  final String profileId;
  const AdvisorHistoryService({this.profileId = 'demo-cs-2024'});
  String get _key => 'advisor_history_v1_$profileId';
  Future<List<AdvisorConversation>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Invalid chat history');
    return decoded.take(20).map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return AdvisorConversation(
        id: map['id'] as String,
        title: map['title'] as String,
        messages: (map['messages'] as List)
            .map(
              (m) => AdvisorMessage.fromStorageJson(
                Map<String, dynamic>.from(m as Map),
              ),
            )
            .toList(),
        requirementStatuses: Map<String, String>.from(
          map['requirementStatuses'] as Map? ?? {},
        ),
      );
    }).toList();
  }

  Future<void> save(List<AdvisorConversation> conversations) async {
    final ok = await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode(conversations.take(20).map((c) => c.toJson()).toList()),
    );
    if (!ok) throw StateError('Chat history could not be saved');
  }

  Future<void> clear() async {
    final ok = await (await SharedPreferences.getInstance()).remove(_key);
    if (!ok) throw StateError('Chat history could not be cleared');
  }
}
