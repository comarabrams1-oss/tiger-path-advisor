import 'package:flutter/material.dart';

import '../models/schedule_preferences.dart';
import '../services/preferences_service.dart';
import 'semester_plan_screen.dart';

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

    if (saved != null) {
      preferredTime = saved.preferredTime;
      preferredDays.addAll(saved.preferredDays);
      avoidedDays.addAll(saved.avoidedDays);
      preferredProfessors.addAll(saved.preferredProfessors);
      maxCredits = saved.maxCredits;
      avoidEarlyClasses = saved.avoidEarlyClasses;
      avoidLateClasses = saved.avoidLateClasses;
      minimizeGaps = saved.minimizeGaps;
    }
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
      preferredProfessors: preferredProfessors,
      maxCredits: maxCredits,
      avoidEarlyClasses: avoidEarlyClasses,
      avoidLateClasses: avoidLateClasses,
      minimizeGaps: minimizeGaps,
    );
  }

  void _savePreferences() {
    PreferencesService.savePreferences(_buildPreferences());

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Schedule preferences saved')));
  }

  void _generatePlan() {
    PreferencesService.savePreferences(_buildPreferences());

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SemesterPlanScreen()),
    );
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
              Text(
                'Build Your Preferences',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tell Tiger Path Advisor what your ideal semester looks like.',
                style: TextStyle(
                  fontSize: 15,
                  color: colors.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 24),

              _buildOverviewCard(context),

              const SizedBox(height: 20),

              _buildSection(
                context,
                icon: Icons.schedule_outlined,
                title: 'Preferred Class Time',
                subtitle: 'Choose the part of the day you prefer.',
                child: DropdownButtonFormField<String>(
                  initialValue: preferredTime,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
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
                icon: Icons.calendar_today_outlined,
                title: 'Preferred Days',
                subtitle: 'Select days you would like to have classes.',
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
                icon: Icons.event_busy_outlined,
                title: 'Days to Avoid',
                subtitle: 'Tiger Path Advisor will try not to schedule classes on these days.',
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
                icon: Icons.school_outlined,
                title: 'Preferred Professors',
                subtitle: 'Add professors you would prefer when multiple sections are available.',
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
                              hintText: 'Professor name',
                              border: OutlineInputBorder(),
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
                icon: Icons.menu_book_outlined,
                title: 'Maximum Credits',
                subtitle:
                    'Set the maximum number of credits for your semester.',
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
                icon: Icons.tune_outlined,
                title: 'Schedule Priorities',
                subtitle:
                    'Choose additional preferences for the generated schedule.',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Avoid early classes'),
                      subtitle: const Text(
                        'Prefer classes starting at 9:00 AM or later.',
                      ),
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
                      title: const Text('Avoid late classes'),
                      subtitle: const Text(
                        'Prefer classes ending before the evening.',
                      ),
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
                      title: const Text('Minimize gaps'),
                      subtitle: const Text(
                        'Try to keep classes closer together during the day.',
                      ),
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

              const SizedBox(height: 26),

              FilledButton.icon(
                onPressed: _generatePlan,
                icon: const Icon(Icons.auto_awesome),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Generate Semester Plan'),
                ),
              ),

              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: _savePreferences,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Preferences'),
              ),

              const SizedBox(height: 20),

              Text(
                'Course availability and section information will be considered when current course-section data is available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.55),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 550;

          final items = [
            _overviewItem(
              context,
              Icons.schedule,
              preferredTime,
              'Preferred Time',
            ),
            _overviewItem(
              context,
              Icons.menu_book,
              '$maxCredits',
              'Max Credits',
            ),
            _overviewItem(
              context,
              Icons.calendar_month,
              preferredDays.isEmpty ? 'Any' : '${preferredDays.length}',
              'Preferred Days',
            ),
          ];

          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: items[0]),
                    const SizedBox(width: 10),
                    Expanded(child: items[1]),
                  ],
                ),
                const SizedBox(height: 10),
                items[2],
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: items[0]),
              const SizedBox(width: 10),
              Expanded(child: items[1]),
              const SizedBox(width: 10),
              Expanded(child: items[2]),
            ],
          );
        },
      ),
    );
  }

  Widget _overviewItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
          const SizedBox(height: 7),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary
                  .withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: colors.primary),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.60),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
