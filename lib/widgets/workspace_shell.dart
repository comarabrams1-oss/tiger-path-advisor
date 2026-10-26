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
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final design = AppDesignTokens.of(context).design;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
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
          if (MediaQuery.viewInsetsOf(context).bottom > 0) return child;
          return Column(
            children: [
              Expanded(child: child),
              if (design == AppDesign.soft)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
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
                      Icon(Icons.school_outlined, color: colors.primary),
                      const SizedBox(width: 10),
                      const Text(
                        'Tiger Path',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      for (var index = 0; index < labels.length; index++)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: index == selectedIndex
                                ? colors.primaryContainer
                                : null,
                            foregroundColor: index == selectedIndex
                                ? colors.onPrimaryContainer
                                : colors.primary,
                          ),
                          onPressed: () => onNavigate(index),
                          icon: Icon(icons[index], size: 18),
                          label: Text(labels[index]),
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
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Icon(Icons.school, color: colors.primary),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            color: colors.primary,
                            size: 30,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tiger Path',
                            style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Student workspace',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
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
                            borderRadius: BorderRadius.circular(18),
                          ),
                          selected: index == selectedIndex,
                          selectedTileColor: colors.primaryContainer,
                          leading: Icon(icons[index], color: colors.primary),
                          title: Text(labels[index]),
                          onTap: () => onNavigate(index),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
