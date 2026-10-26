import 'package:flutter/widgets.dart';

import 'theme_service.dart';

class AdvisorAppActions extends InheritedWidget {
  final ValueChanged<ThemeSettings> onThemeChanged;
  const AdvisorAppActions({
    super.key,
    required this.onThemeChanged,
    required super.child,
  });
  static AdvisorAppActions? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdvisorAppActions>();
  @override
  bool updateShouldNotify(AdvisorAppActions oldWidget) =>
      onThemeChanged != oldWidget.onThemeChanged;
}
