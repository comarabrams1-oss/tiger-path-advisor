import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/widgets/advisor_response.dart';

void main() {
  testWidgets(
    'advisor separates headings, numbered sections, bullets and legacy lists',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: AdvisorResponse(
                text: '## Available sections\n\n1. **CSC 135 — Section 01**\n- Instructor: Test Teacher\n- Time: MWF 10:00–10:50 AM\n\n## Next step\nConfirm the snapshot in Tiger Portal. Options: 1. First option. 2. Second option.',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final rendered = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((w) => w.data ?? w.textSpan!.toPlainText())
          .toList();
      expect(
        rendered,
        containsAll([
          'Available sections',
          'CSC 135 — Section 01',
          'Instructor: Test Teacher',
          'Time: MWF 10:00–10:50 AM',
          'Next step',
          'First option.',
          'Second option.',
        ]),
      );
      expect(rendered.join(), isNot(contains('**')));
      expect(tester.takeException(), isNull);
    },
  );
}
