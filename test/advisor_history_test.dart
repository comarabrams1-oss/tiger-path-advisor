import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiger_path/services/advisor_history_service.dart';
import 'package:tiger_path/services/ai_advisor_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('history saves messages, actions and progress by profile', () async {
    const storage = AdvisorHistoryService(profileId: 'student-a');
    await storage.save([
      const AdvisorConversation(
        id: '1',
        title: 'My plan',
        messages: [
          AdvisorMessage('user', 'Change my theme'),
          AdvisorMessage('assistant', 'Tap to apply', [
            AdvisorAction('changeTheme', 'goldBlack'),
          ]),
        ],
        requirementStatuses: {'cs237': 'remaining'},
      ),
    ]);
    final saved = (await storage.load()).single;
    expect(saved.messages.last.actions.single.target, 'goldBlack');
    expect(saved.requirementStatuses['cs237'], 'remaining');
    expect(
      await const AdvisorHistoryService(profileId: 'student-b').load(),
      isEmpty,
    );
    await storage.clear();
    expect(await storage.load(), isEmpty);
  });
  test('history retains the latest 20 conversations', () async {
    const storage = AdvisorHistoryService();
    await storage.save(
      List.generate(
        25,
        (i) => AdvisorConversation(id: '$i', title: 'Chat $i', messages: []),
      ),
    );
    expect(await storage.load(), hasLength(20));
  });
  test('custom colors are validated before an action is accepted', () {
    expect(
      AdvisorAction.parse({
        'type': 'customTheme',
        'target': 'custom',
        'primaryHex': '#FF000000',
        'accentHex': 'red',
        'darkMode': true,
      }),
      isNull,
    );
    expect(
      AdvisorAction.parse({
        'type': 'customTheme',
        'target': 'custom',
        'primaryHex': '#008080',
        'accentHex': '#FF8800',
        'darkMode': 'yes',
      }),
      isNull,
    );
    expect(
      AdvisorAction.parse({
        'type': 'customTheme',
        'target': 'custom',
        'primaryHex': '#008080',
        'accentHex': '#FF8800',
        'darkMode': false,
      })?.primaryHex,
      '#008080',
    );
  });
  test('unknown app actions are rejected', () {
    expect(
      AdvisorAction.parse({'type': 'navigate', 'target': 'admin'}),
      isNull,
    );
    expect(
      AdvisorAction.parse({'type': 'changeTheme', 'target': 'url'}),
      isNull,
    );
    expect(
      AdvisorAction.parse({'type': 'execute', 'target': 'anything'}),
      isNull,
    );
  });
}
