import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import '../themes/app_theme.dart';

class ThemeSettingsScreen extends StatefulWidget {
  final AppThemePreset currentPreset;
  final CustomThemeSettings currentCustomTheme;
  final ValueChanged<ThemeSettings> onThemeChanged;

  const ThemeSettingsScreen({
    super.key,
    required this.currentPreset,
    required this.currentCustomTheme,
    required this.onThemeChanged,
  });

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  late AppThemePreset selectedPreset;
  late CustomThemeSettings customTheme;
  bool _editingCustom = false;

  final List<Color> primaryColors = const [
    benedictPurple,
    Color(0xFF5E35B1),
    Color(0xFF3949AB),
    Color(0xFF1565C0),
    Color(0xFF00897B),
    Color(0xFF2E7D32),
    Color(0xFFC62828),
    Color(0xFF6D4C41),
  ];

  final List<Color> accentColors = const [
    benedictGold,
    Color(0xFFFFB300),
    Color(0xFFFF7043),
    Color(0xFFEC407A),
    Color(0xFFAB47BC),
    Color(0xFF42A5F5),
    Color(0xFF26A69A),
    Color(0xFF66BB6A),
  ];

  @override
  void initState() {
    super.initState();
    selectedPreset = widget.currentPreset;
    customTheme = widget.currentCustomTheme;
  }

  Future<void> _applyPreset(AppThemePreset preset) async {
    setState(() {
      selectedPreset = preset;
      _editingCustom = false;
    });

    await ThemeService.savePreset(preset);

    widget.onThemeChanged(
      ThemeSettings(preset: preset, customTheme: customTheme),
    );
  }

  Future<void> _saveCustomTheme() async {
    setState(() {
      selectedPreset = AppThemePreset.custom;
      _editingCustom = false;
    });

    await ThemeService.saveCustomTheme(customTheme);

    widget.onThemeChanged(
      ThemeSettings(preset: AppThemePreset.custom, customTheme: customTheme),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Custom theme saved.')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Theme Studio')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            children: [
              Text(
                'Choose Your Look',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a preset theme or create a custom color combination for Tiger Path Advisor.',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.65),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Preset Themes',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              _buildPresetGrid(context),
              const SizedBox(height: 34),
              Text(
                'Create Your Own Theme',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose light or dark mode, then select your primary and accent colors.',
                style: TextStyle(
                  color: colors.onSurface.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 18),
              _buildCustomThemeEditor(context),
              const SizedBox(height: 24),
              _buildCustomPreview(context),
              const SizedBox(height: 22),
              if (_editingCustom || selectedPreset == AppThemePreset.custom)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveCustomTheme,
                    icon: const Icon(Icons.save_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Save & Apply My Theme'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetGrid(BuildContext context) {
    final presets = AppThemePreset.values
        .where((preset) => preset != AppThemePreset.custom)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800
            ? 3
            : constraints.maxWidth >= 520
            ? 2
            : 1;

        final spacing = 14.0;

        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: presets.map((preset) {
            return SizedBox(width: width, child: _presetCard(context, preset));
          }).toList(),
        );
      },
    );
  }

  Widget _presetCard(BuildContext context, AppThemePreset preset) {
    final theme = AppThemes.build(preset);
    final scheme = theme.colorScheme;
    final selected = selectedPreset == preset;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        _applyPreset(preset);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.16),
            width: selected ? 2.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(preset.icon, color: scheme.onPrimary),
                ),
                const Spacer(),
                if (selected) Icon(Icons.check_circle, color: scheme.primary),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              preset.displayName,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _colorDot(scheme.primary),
                const SizedBox(width: 7),
                _colorDot(scheme.secondary),
                const SizedBox(width: 7),
                _colorDot(theme.scaffoldBackgroundColor),
                const SizedBox(width: 7),
                _colorDot(theme.cardTheme.color ?? scheme.surface),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomThemeEditor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dark Mode',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customTheme.darkMode
                            ? 'Dark surfaces and lighter text'
                            : 'Light surfaces and darker text',
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.60),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: customTheme.darkMode,
                  onChanged: (value) {
                    setState(() {
                      _editingCustom = true;
                      customTheme = customTheme.copyWith(darkMode: value);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Primary Color',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildColorPicker(
              colors: primaryColors,
              selected: customTheme.primaryColor,
              onSelected: (color) {
                setState(() {
                  _editingCustom = true;
                  customTheme = customTheme.copyWith(primaryColor: color);
                });
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Accent Color',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildColorPicker(
              colors: accentColors,
              selected: customTheme.accentColor,
              onSelected: (color) {
                setState(() {
                  _editingCustom = true;
                  customTheme = customTheme.copyWith(accentColor: color);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker({
    required List<Color> colors,
    required Color selected,
    required ValueChanged<Color> onSelected,
  }) {
    return Wrap(
      spacing: 11,
      runSpacing: 11,
      children: (colors.contains(selected) ? colors : [selected, ...colors])
          .map((color) {
            final active = color.toARGB32() == selected.toARGB32();

            return InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () {
                onSelected(color);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? color : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                  child: active
                      ? Icon(Icons.check, color: _foregroundFor(color))
                      : null,
                ),
              ),
            );
          })
          .toList(),
    );
  }

  Widget _buildCustomPreview(BuildContext context) {
    final preset = _editingCustom ? AppThemePreset.custom : selectedPreset;
    return ThemeStudioPreview(
      preset: preset,
      custom: customTheme,
      title: _editingCustom
          ? 'Custom preview · not applied'
          : '${preset.displayName} preview',
    );
  }

  Widget _colorDot(Color color) {
    return Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
      ),
    );
  }

  Color _foregroundFor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}

class ThemeStudioPreview extends StatelessWidget {
  final AppThemePreset preset;
  final CustomThemeSettings custom;
  final String title;
  const ThemeStudioPreview({
    super.key,
    required this.preset,
    required this.custom,
    required this.title,
  });
  String _hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  @override
  Widget build(BuildContext context) {
    final theme = AppThemes.build(preset, custom: custom);
    final colors = theme.colorScheme;
    return Theme(
      data: theme,
      child: DefaultTextStyle(
        style: theme.textTheme.bodyMedium!.copyWith(color: colors.onSurface),
        child: Builder(
          builder: (context) => Container(
            key: const ValueKey('theme-preview'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: const ValueKey('preview-appbar'),
                  padding: const EdgeInsets.all(16),
                  color: theme.appBarTheme.backgroundColor,
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        color: theme.appBarTheme.foregroundColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.appBarTheme.foregroundColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        key: const ValueKey('preview-hero'),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tiger Path Advisor',
                              style: TextStyle(
                                color: colors.onPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Academic planning',
                              style: TextStyle(
                                color: colors.onPrimary.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Degree progress',
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Text(
                                    '73 / 120 credits',
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '60.8%',
                                    style: TextStyle(color: colors.onSurface),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: const LinearProgressIndicator(
                                  value: 73 / 120,
                                  minHeight: 9,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  FilledButton(
                                    onPressed: () {},
                                    child: const Text('Primary action'),
                                  ),
                                  FilledButton.tonalIcon(
                                    key: const ValueKey(
                                      'preview-accent-action',
                                    ),
                                    onPressed: () {},
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colors.secondary,
                                      foregroundColor: colors.onSecondary,
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_forward,
                                      size: 17,
                                    ),
                                    label: const Text('Chat action'),
                                  ),
                                  FilterChip(
                                    label: const Text('Selected option'),
                                    selected: true,
                                    onSelected: (_) {},
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'Message Tiger Path',
                          suffixIcon: Padding(
                            padding: const EdgeInsets.all(5),
                            child: IconButton.filled(
                              onPressed: () {},
                              style: IconButton.styleFrom(
                                backgroundColor: colors.secondary,
                                foregroundColor: colors.onSecondary,
                              ),
                              icon: const Icon(Icons.arrow_upward, size: 18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          for (final entry in [
                            ('Primary', colors.primary),
                            ('Accent', colors.secondary),
                          ])
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: entry.$2,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${entry.$1} ${_hex(entry.$2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Display colors include the same contrast adjustments as the app.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
