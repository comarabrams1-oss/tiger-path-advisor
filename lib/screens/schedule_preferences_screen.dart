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

class _SchedulePreferencesScreenState
    extends State<SchedulePreferencesScreen> {
  String preferredTime = 'No Preference';

  final Set<String> preferredDays = {};
  final Set<String> avoidedDays = {};

  final List<String> preferredProfessors = [];

  int maxCredits = 15;

  bool avoidEarlyClasses = false;
  bool avoidLateClasses = false;
  bool minimizeGaps = true;

  final TextEditingController professorController =
      TextEditingController();

  final List<String> days = [
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
      preferredProfessors.addAll(
        saved.preferredProfessors,
      );
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

  void addProfessor() {
    final name = professorController.text.trim();

    if (name.isEmpty) {
      return;
    }

    if (preferredProfessors.any(
      (professor) =>
          professor.toLowerCase() == name.toLowerCase(),
    )) {
      professorController.clear();
      return;
    }

    setState(() {
      preferredProfessors.add(name);
      professorController.clear();
    });
  }

  void savePreferences() {
    final preferences = SchedulePreferences(
      preferredTime: preferredTime,
      preferredDays: preferredDays.toList(),
      avoidedDays: avoidedDays.toList(),
      preferredProfessors:
          List<String>.from(preferredProfessors),
      maxCredits: maxCredits,
      avoidEarlyClasses: avoidEarlyClasses,
      avoidLateClasses: avoidLateClasses,
      minimizeGaps: minimizeGaps,
    );

    PreferencesService.savePreferences(preferences);
  }

  void generatePlan() {
    savePreferences();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const SemesterPlanScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Preferences'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Build Your Schedule',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Tell TigerPath what kind of schedule '
            'you prefer.',
          ),

          const SizedBox(height: 30),

          const Text(
            'Preferred Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            initialValue: preferredTime,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'No Preference',
                child: Text('No Preference'),
              ),
              DropdownMenuItem(
                value: 'Morning',
                child: Text('Morning'),
              ),
              DropdownMenuItem(
                value: 'Afternoon',
                child: Text('Afternoon'),
              ),
              DropdownMenuItem(
                value: 'Evening',
                child: Text('Evening'),
              ),
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

          const SizedBox(height: 30),

          const Text(
            'Preferred Days',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: days.map((day) {
              return FilterChip(
                label: Text(day),
                selected: preferredDays.contains(day),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      preferredDays.add(day);
                      avoidedDays.remove(day);
                    } else {
                      preferredDays.remove(day);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 30),

          const Text(
            'Days to Avoid',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: days.map((day) {
              return FilterChip(
                label: Text(day),
                selected: avoidedDays.contains(day),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      avoidedDays.add(day);
                      preferredDays.remove(day);
                    } else {
                      avoidedDays.remove(day);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 30),

          const Text(
            'Preferred Professors',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: professorController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Professor name',
                  ),
                  onSubmitted: (_) {
                    addProfessor();
                  },
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: addProfessor,
                icon: const Icon(Icons.add),
              ),
            ],
          ),

          if (preferredProfessors.isNotEmpty) ...[
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  preferredProfessors.map((professor) {
                return InputChip(
                  label: Text(professor),
                  onDeleted: () {
                    setState(() {
                      preferredProfessors.remove(
                        professor,
                      );
                    });
                  },
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 30),

          const Text(
            'Maximum Credits',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          DropdownButtonFormField<int>(
            initialValue: maxCredits,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 12,
                child: Text('12 credits'),
              ),
              DropdownMenuItem(
                value: 13,
                child: Text('13 credits'),
              ),
              DropdownMenuItem(
                value: 14,
                child: Text('14 credits'),
              ),
              DropdownMenuItem(
                value: 15,
                child: Text('15 credits'),
              ),
              DropdownMenuItem(
                value: 16,
                child: Text('16 credits'),
              ),
              DropdownMenuItem(
                value: 17,
                child: Text('17 credits'),
              ),
              DropdownMenuItem(
                value: 18,
                child: Text('18 credits'),
              ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                maxCredits = value;
              });
            },
          ),

          const SizedBox(height: 20),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Avoid early classes',
            ),
            subtitle: const Text(
              'Prefer classes starting at 9:00 AM or later',
            ),
            value: avoidEarlyClasses,
            onChanged: (value) {
              setState(() {
                avoidEarlyClasses = value;
              });
            },
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Avoid late classes',
            ),
            subtitle: const Text(
              'Prefer classes ending by 5:00 PM',
            ),
            value: avoidLateClasses,
            onChanged: (value) {
              setState(() {
                avoidLateClasses = value;
              });
            },
          ),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Minimize schedule gaps',
            ),
            subtitle: const Text(
              'Prefer classes closer together',
            ),
            value: minimizeGaps,
            onChanged: (value) {
              setState(() {
                minimizeGaps = value;
              });
            },
          ),

          const SizedBox(height: 30),

          FilledButton.icon(
            onPressed: generatePlan,
            icon: const Icon(
              Icons.auto_awesome,
            ),
            label: const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 14,
              ),
              child: Text(
                'Generate Semester Plan',
              ),
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton(
            onPressed: () {
              savePreferences();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Schedule preferences saved',
                  ),
                ),
              );
            },
            child: const Text(
              'Save Preferences',
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}