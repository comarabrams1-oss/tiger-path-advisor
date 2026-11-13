import 'package:flutter/material.dart';

import '../themes/app_theme.dart';

/// Navigation surrounds the navigator, so every tool uses the chosen layout.
class WorkspaceShell extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onNavigate;
  const WorkspaceShell({
    super.key,
    required this.child,
    this.selectedIndex = 0,
    required this.onNavigate,
  });
  static const labels = [
    'Home',
    'Courses',
    'Degree',
    'Plan',
    'Advisor',
    'Style',
  ];
  static const icons = [
    Icons.space_dashboard_outlined,
    Icons.menu_book_outlined,
    Icons.school_outlined,
    Icons.calendar_month_outlined,
    Icons.chat_bubble_outline,
    Icons.tune,
  ];
  static bool usesWideNavigation(AppDesign design, double width) =>
      width >= (design == AppDesign.classic ? 1200 : 1000);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final design = AppDesignTokens.of(context).design;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = usesWideNavigation(design, constraints.maxWidth);
          final navigation = NavigationBar(
            selectedIndex: selectedIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            indicatorColor: colors.secondaryContainer,
            height: 72,
            onDestinationSelected: onNavigate,
            destinations: [
              for (var index = 0; index < labels.length; index++)
                NavigationDestination(
                  icon: Icon(icons[index]),
                  label: labels[index],
                ),
            ],
          );
          if (!wide) {
            return Column(
              children: [
                Expanded(child: child),
                if (MediaQuery.viewInsetsOf(context).bottom > 0)
                  const SizedBox.shrink()
                else if (design == AppDesign.soft)
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(design.radius),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: navigation,
                  )
                else
                  navigation,
              ],
            );
          }
          if (design == AppDesign.classic) {
            return Column(
              children: [
                Material(
                  color: colors.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const _CollegeLogo(),
                        const SizedBox(width: 10),
                        const Text(
                          'Tiger Path Advisor',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        for (var index = 0; index < labels.length; index++)
                          Semantics(
                            selected: index == selectedIndex,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: index == selectedIndex
                                        ? colors.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: index == selectedIndex
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                ),
                                onPressed: () => onNavigate(index),
                                child: Text(labels[index]),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: child),
              ],
            );
          }
          if (design == AppDesign.sharp) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onNavigate,
                  labelType: NavigationRailLabelType.all,
                  scrollable: true,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: const _CollegeLogo(),
                  ),
                  destinations: [
                    for (var index = 0; index < labels.length; index++)
                      NavigationRailDestination(
                        icon: Icon(icons[index]),
                        label: Text(labels[index]),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            );
          }
          return Row(
            children: [
              SizedBox(
                width: 210,
                child: Material(
                  color: colors.surface,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _CollegeLogo(),
                              const SizedBox(height: 12),
                              const Text(
                                'Tiger Path Advisor',
                                style: TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (var index = 0; index < labels.length; index++)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              selected: index == selectedIndex,
                              selectedTileColor: colors.primaryContainer,
                              leading: Icon(
                                icons[index],
                                color: colors.primary,
                              ),
                              title: Text(labels[index]),
                              onTap: () => onNavigate(index),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

class _CollegeLogo extends StatelessWidget {
  const _CollegeLogo();
  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 40,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Image.asset(
      'assets/images/benedict_logo.png',
      fit: BoxFit.contain,
      semanticLabel: 'Benedict College logo',
    ),
  );
}
