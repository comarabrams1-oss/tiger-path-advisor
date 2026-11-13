import 'package:flutter/material.dart';

import '../themes/app_theme.dart';
import '../widgets/info_tip.dart';

import '../models/schedule_preferences.dart';
import '../services/preferences_service.dart';
import '../services/schedule_draft_service.dart';
import 'generated_schedule_screen.dart';
import 'semester_plan_screen.dart';
import '../data/test_student.dart';
import '../data/program_registry.dart';

class SchedulePreferencesScreen extends StatefulWidget {
  const SchedulePreferencesScreen({super.key});

  @override
  State<SchedulePreferencesScreen> createState() =>
      _SchedulePreferencesScreenState();
}

class _SchedulePreferencesScreenState extends State<SchedulePreferencesScreen> {
  String preferredTime = 'Afternoon';

  Set<String> preferredDays = <String>{};
  Set<String> avoidedDays = <String>{};
  List<String> preferredProfessors = <String>[];

  int maxCredits = 15;

  bool avoidEarlyClasses = false;
  bool avoidLateClasses = false;
  bool minimizeGaps = true;

  final TextEditingController professorController = TextEditingController();

  final List<String> days = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  @override
  void initState() {
    super.initState();

    final saved = PreferencesService.preferences;
    if (saved != null) _applyPreferences(saved);
  }

  void _applyPreferences(SchedulePreferences saved) {
    preferredTime = saved.preferredTime;
    preferredDays = saved.preferredDays.toSet();
    avoidedDays = saved.avoidedDays.toSet();
    preferredProfessors = List.of(saved.preferredProfessors);
    maxCredits = saved.maxCredits;
    avoidEarlyClasses = saved.avoidEarlyClasses;
    avoidLateClasses = saved.avoidLateClasses;
    minimizeGaps = saved.minimizeGaps;
  }

  @override
  void dispose() {
    professorController.dispose();
    super.dispose();
  }

  SchedulePreferences _buildPreferences() {
    return SchedulePreferences(
      preferredTime: preferredTime,
      preferredDays: preferredDays.toList(),
      avoidedDays: avoidedDays.toList(),
      preferredProfessors: List.of(preferredProfessors),
      maxCredits: maxCredits,
      avoidEarlyClasses: avoidEarlyClasses,
      avoidLateClasses: avoidLateClasses,
      minimizeGaps: minimizeGaps,
    );
  }

  Future<void> _savePreferences() async {
    final saved = await PreferencesService.savePreferences(_buildPreferences());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Schedule preferences saved'
              : 'Preferences could only be kept for this session.',
        ),
      ),
    );
  }

  Future<void> _generatePlan() {
    PreferencesService.savePreferences(_buildPreferences());
    return _openScheduleRoute(
      'SemesterPlanScreen',
      (_) => const SemesterPlanScreen(),
    );
  }

  Future<void> _openScheduleRoute(String name, WidgetBuilder builder) async {
    final profile = PreferencesService.profileId;
    final before = PreferencesService.preferences;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: builder,
      ),
    );
    final saved = PreferencesService.preferences;
    if (mounted &&
        profile == PreferencesService.profileId &&
        saved != null &&
        !identical(saved, before)) {
      setState(() => _applyPreferences(saved));
    }
  }

  void _togglePreferredDay(String day, bool selected) {
    setState(() {
      if (selected) {
        preferredDays.add(day);
        avoidedDays.remove(day);
      } else {
        preferredDays.remove(day);
      }
    });
  }

  void _toggleAvoidedDay(String day, bool selected) {
    setState(() {
      if (selected) {
        avoidedDays.add(day);
        preferredDays.remove(day);
      } else {
        avoidedDays.remove(day);
      }
    });
  }

  void _addProfessor() {
    final name = professorController.text.trim();

    if (name.isEmpty) {
      return;
    }

    if (!preferredProfessors.contains(name)) {
      setState(() {
        preferredProfessors.add(name);
      });
    }

    professorController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule Builder')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ValueListenableBuilder<int>(
                valueListenable: ScheduleDraftService.revision,
                builder: (context, _, _) {
                  final draft = ScheduleDraftService.current;
                  if (draft == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: colors.secondaryContainer,
                      child: ListTile(
                        title: const Text('Continue schedule'),
                        subtitle: const Text('Spring 2027 draft'),
                        leading: const Icon(Icons.calendar_month_outlined),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () => _openScheduleRoute(
                          'GeneratedScheduleScreen',
                          (_) => GeneratedScheduleScreen(
                            plan: draft.plan,
                            draft: draft,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Text(
                'Spring 2027',
                textAlign: TextAlign.center,
                style: AppThemes.pageTitle(context),
              ),
              if (activeStudent.classification.toLowerCase() == 'freshman')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'First-year courses and prerequisites',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              if (activeStudent.major == 'Computer Engineering')
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(engineeringPreviewNotice),
                ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                title: 'Preferred Class Time',
                child: DropdownButtonFormField<String>(
                  key: ValueKey(preferredTime),
                  initialValue: preferredTime,
                  decoration: const InputDecoration(),
                  items: const [
                    DropdownMenuItem(
                      value: 'No Preference',
                      child: Text('Any time'),
                    ),
                    DropdownMenuItem(value: 'Morning', child: Text('Morning')),
                    DropdownMenuItem(
                      value: 'Afternoon',
                      child: Text('Afternoon'),
                    ),
                    DropdownMenuItem(value: 'Evening', child: Text('Evening')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      preferredTime = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: 16),

              _buildSection(
                context,
                title: 'Preferred Days',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: days.map((day) {
                    final selected = preferredDays.contains(day);

                    return FilterChip(
                      label: Text(day),
                      selected: selected,
                      onSelected: (value) => _togglePreferredDay(day, value),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              _buildSection(
                context,
                title: 'Days to Avoid',
                help: 'Classes may still meet on these days if another section doesn’t fit.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: days.map((day) {
                    final selected = avoidedDays.contains(day);

                    return FilterChip(
                      label: Text(day),
                      selected: selected,
                      onSelected: (value) => _toggleAvoidedDay(day, value),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 16),

              _buildSection(
                context,
                title: 'Preferred Professors',
                help: 'Use a first or last name. An instructor preference can yield to course requirements or a time conflict.',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: professorController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _addProfessor(),
                            decoration: const InputDecoration(
                              labelText: 'Professor name',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _addProfessor,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    if (preferredProfessors.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: preferredProfessors.map((professor) {
                            return InputChip(
                              label: Text(professor),
                              onDeleted: () {
                                setState(() {
                                  preferredProfessors.remove(professor);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _buildSection(
                context,
                title: 'Maximum Credits',
                help: 'The builder schedules up to this limit using eligible, open sections.',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          '$maxCredits credits',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: maxCredits.toDouble(),
                      min: 12,
                      max: 18,
                      divisions: 6,
                      label: '$maxCredits',
                      onChanged: (value) {
                        setState(() {
                          maxCredits = value.round();
                        });
                      },
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('12'), Text('15'), Text('18')],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _buildSection(
                context,
                title: 'Schedule Priorities',
                help: 'Time and gap preferences are flexible when sections are limited.',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Prefer starts at 10:00 AM or later'),
                      value: avoidEarlyClasses,
                      onChanged: (value) {
                        setState(() {
                          avoidEarlyClasses = value;
                        });
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Prefer finishes by 5:00 PM'),
                      value: avoidLateClasses,
                      onChanged: (value) {
                        setState(() {
                          avoidLateClasses = value;
                        });
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Minimize gaps between classes'),
                      value: minimizeGaps,
                      onChanged: (value) {
                        setState(() {
                          minimizeGaps = value;
                        });
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _generatePlan,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Find courses for my semester'),
                    ),
                    OutlinedButton(
                      onPressed: _savePreferences,
                      child: const Text('Save Preferences'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    String? help,
    required Widget child,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(height: 1),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (help != null) InfoTip(label: 'About $title', message: help),
        ],
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}
