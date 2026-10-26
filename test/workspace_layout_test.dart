import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiger_path/themes/app_theme.dart';
import 'package:tiger_path/widgets/workspace_shell.dart';
import 'package:tiger_path/widgets/academic_workspace.dart';

void main() {
  for (final design in AppDesign.values) {
    testWidgets(
      '${design.name} changes navigation layout and supports phones',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        int? destination;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppThemes.build(
              AppThemePreset.benedict,
              custom: CustomThemeSettings(design: design),
            ),
            home: WorkspaceShell(
              onNavigate: (index) => destination = index,
              child: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: AcademicWorkspace(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (design == AppDesign.sharp) {
          expect(find.byType(NavigationRail), findsOneWidget);
          expect(find.byType(SegmentedButton<int>), findsOneWidget);
          expect(find.text('What could come next'), findsNothing);
          await tester.tap(find.text('Next term'));
          await tester.pumpAndSettle();
          expect(find.text('What could come next'), findsOneWidget);
          expect(find.text('Your current semester'), findsNothing);
        } else if (design == AppDesign.soft) {
          expect(find.byType(ListTile), findsNWidgets(6));
        } else {
          expect(find.byType(NavigationRail), findsNothing);
          expect(find.text('Your current semester'), findsOneWidget);
          expect(find.text('What could come next'), findsOneWidget);
        }
        await tester.tap(find.text('Plan'));
        expect(destination, 3);
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
