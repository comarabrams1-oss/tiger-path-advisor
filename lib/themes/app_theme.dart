import 'package:flutter/material.dart';

const benedictPurple = Color(0xFF3A0B5C);
const benedictDarkPurple = Color(0xFF26063E);
const benedictGold = Color(0xFFFFD22E);

enum AppThemePreset {
  benedict,
  light,
  dark,
  midnightPurple,
  goldBlack,
  highContrast,
  custom,
}

extension AppThemePresetInfo on AppThemePreset {
  String get displayName {
    switch (this) {
      case AppThemePreset.benedict:
        return 'Benedict';
      case AppThemePreset.light:
        return 'Light';
      case AppThemePreset.dark:
        return 'Dark';
      case AppThemePreset.midnightPurple:
        return 'Midnight Purple';
      case AppThemePreset.goldBlack:
        return 'Gold & Black';
      case AppThemePreset.highContrast:
        return 'High Contrast';
      case AppThemePreset.custom:
        return 'My Theme';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemePreset.benedict:
        return Icons.school_outlined;
      case AppThemePreset.light:
        return Icons.light_mode_outlined;
      case AppThemePreset.dark:
        return Icons.dark_mode_outlined;
      case AppThemePreset.midnightPurple:
        return Icons.nights_stay_outlined;
      case AppThemePreset.goldBlack:
        return Icons.workspace_premium_outlined;
      case AppThemePreset.highContrast:
        return Icons.contrast_outlined;
      case AppThemePreset.custom:
        return Icons.palette_outlined;
    }
  }
}

enum AppDesign { classic, soft, sharp }

extension AppDesignInfo on AppDesign {
  String get label => switch (this) {
    AppDesign.classic => 'Classic',
    AppDesign.soft => 'Soft',
    AppDesign.sharp => 'Sharp',
  };
  String get description => switch (this) {
    AppDesign.classic => 'Top navigation and a side-by-side overview',
    AppDesign.soft => 'Sidebar navigation and a planning-first workspace',
    AppDesign.sharp => 'Navigation rail and a compact, tabbed workspace',
  };
  double get radius => switch (this) {
    AppDesign.classic => 8,
    AppDesign.soft => 16,
    AppDesign.sharp => 4,
  };
}

class AppDesignTokens extends ThemeExtension<AppDesignTokens> {
  final AppDesign design;
  const AppDesignTokens(this.design);
  double get radius => design.radius;
  static AppDesignTokens of(BuildContext context) =>
      Theme.of(context).extension<AppDesignTokens>() ??
      const AppDesignTokens(AppDesign.classic);
  @override
  AppDesignTokens copyWith({AppDesign? design}) =>
      AppDesignTokens(design ?? this.design);
  @override
  AppDesignTokens lerp(covariant AppDesignTokens? other, double t) =>
      t < .5 ? this : other ?? this;
}

class CustomThemeSettings {
  final bool darkMode;
  final AppDesign design;
  final Color primaryColor;
  final Color accentColor;

  const CustomThemeSettings({
    this.darkMode = false,
    this.design = AppDesign.classic,
    this.primaryColor = benedictPurple,
    this.accentColor = benedictGold,
  });

  CustomThemeSettings copyWith({
    bool? darkMode,
    AppDesign? design,
    Color? primaryColor,
    Color? accentColor,
  }) {
    return CustomThemeSettings(
      darkMode: darkMode ?? this.darkMode,
      design: design ?? this.design,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}

class AppThemes {
  static TextStyle pageTitle(BuildContext context, {double size = 32}) =>
      Theme.of(context).textTheme.headlineMedium!.copyWith(
        fontFamily: 'Spectral',
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.12,
        letterSpacing: -.5,
      );

  static ThemeData build(
    AppThemePreset preset, {
    CustomThemeSettings custom = const CustomThemeSettings(),
  }) {
    final base = _palette(preset, custom);
    final design = custom.design;
    final radius = BorderRadius.circular(design.radius);
    final sharp = design == AppDesign.sharp;
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: BorderSide(color: base.colorScheme.outlineVariant),
    );
    final controlShape = WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(sharp ? 4 : 8),
      ),
    );
    return base.copyWith(
      extensions: [AppDesignTokens(design)],
      cardTheme: base.cardTheme.copyWith(
        shape: shape,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      textTheme: base.textTheme.copyWith(
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          letterSpacing: 0,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          fontSize: 13,
          letterSpacing: 0,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style!.copyWith(
          shape: controlShape,
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style!.copyWith(
          shape: controlShape,
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          side: WidgetStatePropertyAll(
            BorderSide(color: base.colorScheme.outlineVariant),
          ),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: base.colorScheme.outline.withValues(alpha: .5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: base.colorScheme.primary, width: 2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(sharp ? 4 : 8),
        ),
      ),
      dividerTheme: base.dividerTheme.copyWith(thickness: 1),
    );
  }

  static ThemeData _palette(AppThemePreset preset, CustomThemeSettings custom) {
    switch (preset) {
      case AppThemePreset.benedict:
        return _benedictTheme();

      case AppThemePreset.light:
        return _lightTheme();

      case AppThemePreset.dark:
        return _darkTheme();

      case AppThemePreset.midnightPurple:
        return _midnightPurpleTheme();

      case AppThemePreset.goldBlack:
        return _goldBlackTheme();

      case AppThemePreset.highContrast:
        return _highContrastTheme();

      case AppThemePreset.custom:
        return _customTheme(custom);
    }
  }

  static ThemeData _benedictTheme() {
    const background = Color(0xFFF7F5F0);
    const surface = Color(0xFFFFFDFA);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: benedictPurple,
          brightness: Brightness.light,
        ).copyWith(
          primary: benedictPurple,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFEDE5F1),
          onPrimaryContainer: benedictDarkPurple,
          secondary: benedictGold,
          onSecondary: Colors.black,
          secondaryContainer: const Color(0xFFF4E8C8),
          onSecondaryContainer: const Color(0xFF4F3910),
          surface: surface,
          surfaceContainerLow: const Color(0xFFF0ECE6),
          surfaceContainerHighest: const Color(0xFFE8E1D7),
          onSurface: const Color(0xFF252127),
          onSurfaceVariant: const Color(0xFF605762),
          outline: const Color(0xFF877D85),
          outlineVariant: const Color(0xFFDAD2C9),
        );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: background,
      cardColor: surface,
      appBarColor: background,
      appBarForeground: benedictPurple,
      navigationColor: surface,
      dividerColor: scheme.outlineVariant,
    );
  }

  static ThemeData _lightTheme() {
    const background = Color(0xFFF4F5F7);
    const surface = Colors.white;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: benedictPurple,
          brightness: Brightness.light,
        ).copyWith(
          primary: benedictPurple,
          onPrimary: Colors.white,
          secondary: benedictGold,
          onSecondary: Colors.black,
          surface: surface,
          onSurface: const Color(0xFF1C1B1F),
        );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: background,
      cardColor: surface,
      appBarColor: surface,
      appBarForeground: benedictDarkPurple,
      navigationColor: surface,
    );
  }

  static ThemeData _darkTheme() {
    const background = Color(0xFF100D13);
    const surface = Color(0xFF1B1720);
    const card = Color(0xFF211A28);
    const primary = Color(0xFFD4A6F0);
    const primaryContainer = Color(0xFF4D2265);
    const mutedSurface = Color(0xFF2A2230);

    const scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: Color(0xFF2B073E),
      primaryContainer: primaryContainer,
      onPrimaryContainer: Color(0xFFF5DFFF),
      secondary: benedictGold,
      onSecondary: Colors.black,
      surface: surface,
      onSurface: Color(0xFFF5EFF7),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
    );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: background,
      cardColor: card,
      appBarColor: const Color(0xFF17111B),
      appBarForeground: const Color(0xFFF8F3FA),
      navigationColor: surface,
      dividerColor: const Color(0xFF403647),
      inputFillColor: mutedSurface,
    );
  }

  static ThemeData _midnightPurpleTheme() {
    const background = Color(0xFF151218);
    const surface = Color(0xFF201B24);
    const card = Color(0xFF251F29);
    const primary = Color(0xFFD0B6E1);
    const accent = Color(0xFFE7C87C);

    const scheme = ColorScheme.dark(
      primary: primary,
      onPrimary: Color(0xFF240037),
      primaryContainer: Color(0xFF3B2D45),
      onPrimaryContainer: Color(0xFFF2E6F8),
      secondary: accent,
      onSecondary: Color(0xFF302203),
      secondaryContainer: Color(0xFF443920),
      onSecondaryContainer: Color(0xFFF3DEA8),
      surface: surface,
      surfaceContainerLow: Color(0xFF261F2A),
      onSurface: Color(0xFFF7EEFC),
      onSurfaceVariant: Color(0xFFCCC0D0),
      outlineVariant: Color(0xFF483E4C),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
    );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: background,
      cardColor: card,
      appBarColor: background,
      appBarForeground: Colors.white,
      navigationColor: surface,
      dividerColor: const Color(0xFF3E304A),
      inputFillColor: const Color(0xFF2E2733),
    );
  }

  static ThemeData _goldBlackTheme() {
    const background = Color(0xFF0B0B0B);
    const surface = Color(0xFF171717);
    const card = Color(0xFF202020);

    const scheme = ColorScheme.dark(
      primary: benedictGold,
      onPrimary: Colors.black,
      primaryContainer: Color(0xFF4C3C00),
      onPrimaryContainer: Color(0xFFFFE996),
      secondary: Color(0xFFFFE082),
      onSecondary: Colors.black,
      surface: surface,
      onSurface: Color(0xFFF7F3E8),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
    );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: background,
      cardColor: card,
      appBarColor: const Color(0xFF111111),
      appBarForeground: benedictGold,
      navigationColor: surface,
      dividerColor: const Color(0xFF3D3D3D),
      inputFillColor: const Color(0xFF282828),
    );
  }

  static ThemeData _highContrastTheme() {
    const scheme = ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      primaryContainer: Color(0xFF333333),
      onPrimaryContainer: Colors.white,
      secondary: Color(0xFFFFFF00),
      onSecondary: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
      error: Color(0xFFFF6B6B),
      onError: Colors.black,
    );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: Colors.black,
      cardColor: const Color(0xFF111111),
      appBarColor: Colors.black,
      appBarForeground: Colors.white,
      navigationColor: Colors.black,
      dividerColor: Colors.white,
      inputFillColor: const Color(0xFF191919),
      highContrast: true,
    );
  }

  // Keep requested hues readable for links, icons and text on the active surface.
  static Color _readableColor(Color color, Color surface) {
    final target = surface.computeLuminance() < 0.5
        ? Colors.white
        : Colors.black;
    for (var step = 0; step <= 20; step++) {
      final candidate = Color.lerp(color, target, step / 20)!;
      final a = candidate.computeLuminance();
      final b = surface.computeLuminance();
      final ratio = ((a > b ? a : b) + 0.05) / ((a < b ? a : b) + 0.05);
      if (ratio >= 4.5) return candidate;
    }
    return target;
  }

  static ThemeData _customTheme(CustomThemeSettings settings) {
    final brightness = settings.darkMode ? Brightness.dark : Brightness.light;

    final dark = settings.darkMode;

    final background = dark ? const Color(0xFF101014) : const Color(0xFFF6F6F8);

    final surface = dark ? const Color(0xFF1B1B20) : Colors.white;

    final card = dark ? const Color(0xFF232329) : Colors.white;

    final primary = _readableColor(settings.primaryColor, surface);
    final accent = _readableColor(settings.accentColor, surface);
    final accentPalette = ColorScheme.fromSeed(
      seedColor: settings.accentColor,
      brightness: brightness,
    );
    final scheme =
        ColorScheme.fromSeed(
          seedColor: settings.primaryColor,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: _foregroundFor(primary),
          secondary: accent,
          secondaryContainer: accentPalette.primaryContainer,
          onSecondaryContainer: accentPalette.onPrimaryContainer,
          surface: surface,
          onSecondary:
              ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
              ? Colors.white
              : Colors.black,
        );

    return _baseTheme(
      scheme: scheme,
      scaffoldBackground: background,
      cardColor: card,
      appBarColor: dark ? const Color(0xFF17171C) : settings.primaryColor,
      appBarForeground: dark
          ? Colors.white
          : _foregroundFor(settings.primaryColor),
      navigationColor: surface,
      dividerColor: dark ? const Color(0xFF404047) : const Color(0xFFE0E0E5),
      inputFillColor: dark ? const Color(0xFF29292F) : const Color(0xFFF0F0F3),
    );
  }

  static ThemeData _baseTheme({
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color appBarColor,
    required Color appBarForeground,
    required Color navigationColor,
    Color? dividerColor,
    Color? inputFillColor,
    bool highContrast = false,
  }) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Source Sans 3',
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      dividerColor: dividerColor,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarColor,
        foregroundColor: appBarForeground,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: highContrast
              ? const BorderSide(color: Colors.white, width: 1.5)
              : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            inputFillColor ??
            scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: highContrast
              ? const BorderSide(color: Colors.white)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
        linearTrackColor: scheme.secondary.withValues(alpha: 0.16),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.secondary,
        thumbColor: scheme.secondary,
        inactiveTrackColor: scheme.secondary.withValues(alpha: 0.18),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? null
              : states.contains(WidgetState.selected)
              ? scheme.secondary
              : null,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.primary.withValues(alpha: 0.08),
        selectedColor: scheme.secondaryContainer,
        checkmarkColor: scheme.onSecondaryContainer,
        secondaryLabelStyle: TextStyle(color: scheme.onSecondaryContainer),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.25)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navigationColor,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
    );
  }

  static Color _foregroundFor(Color background) {
    return background.computeLuminance() > 0.179 ? Colors.black : Colors.white;
  }
}
