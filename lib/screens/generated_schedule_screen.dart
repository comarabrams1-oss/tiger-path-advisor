import 'package:flutter/material.dart';
import '../data/test_course_sections.dart';
import '../data/test_instructors.dart';
import '../models/schedule_preferences.dart';
import '../services/preferences_service.dart';
import '../services/schedule_generation_service.dart';
import '../services/semester_plan_service.dart';

class GeneratedScheduleScreen extends StatelessWidget {
  final SemesterPlan plan;

  const GeneratedScheduleScreen({
    super.key,
    required this.plan,
  });

  @override
  Widget build(BuildContext context) {
    final preferences =
        PreferencesService.preferences ??
        const SchedulePreferences(
          preferredTime: 'No Preference',
          preferredDays: [],
          avoidedDays: [],
          preferredProfessors: [],
          maxCredits: 15,
          avoidEarlyClasses: false,
          avoidLateClasses: false,
          minimizeGaps: true,
        );

    final generatedSchedule =
        ScheduleGenerationService().generateSchedule(
      plan: plan,
      sections: testCourseSections,
      instructors: testInstructors,
      preferences: preferences,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated Schedule'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Your Schedule',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'TigerPath selected the best available test sections '
            'based on your academic plan and schedule preferences.',
          ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Schedule Summary',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${generatedSchedule.scheduled.length} '
                    'courses scheduled',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${generatedSchedule.scheduledCredits.toInt()} '
                    'scheduled credits',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${generatedSchedule.unscheduled.length} '
                    'items still unresolved',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          if (generatedSchedule.scheduled.isNotEmpty) ...[
            const Text(
              'Scheduled Classes',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            ...generatedSchedule.scheduled.map(
              (scheduled) => Card(
                margin: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        scheduled.section.courseCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),

                      Text(
                        scheduled.planItem.title,
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Section ${scheduled.section.sectionNumber}',
                      ),

                      const SizedBox(height: 5),

                      Text(
                        scheduled.section.days.join(' / '),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        '${scheduled.section.startTime} - '
                        '${scheduled.section.endTime}',
                      ),

                      const SizedBox(height: 5),

                      Text(
                        scheduled.instructor?.name ??
                            'Instructor TBD',
                      ),

                      const SizedBox(height: 5),

                      Text(
                        scheduled.section.location,
                      ),

                      const SizedBox(height: 5),

                      Text(
                        scheduled.section.deliveryMethod,
                      ),

                      if (scheduled
                          .matchReasons
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),

                        const Text(
                          'Why this section?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        ...scheduled.matchReasons.map(
                          (reason) => Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 3,
                            ),
                            child: Text(
                              '• $reason',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],

          if (generatedSchedule.unscheduled.isNotEmpty) ...[
            const Text(
              'Still Unscheduled',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),

            const Text(
              'These items need additional course or section data.',
            ),

            const SizedBox(height: 12),

            ...generatedSchedule.unscheduled.map(
              (unscheduled) => Card(
                margin: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_outlined,
                      ),
                      const SizedBox(width: 14),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              unscheduled
                                      .planItem
                                      .courseCode ??
                                  unscheduled
                                      .planItem
                                      .title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            if (unscheduled
                                    .planItem
                                    .courseCode !=
                                null) ...[
                              const SizedBox(height: 3),
                              Text(
                                unscheduled
                                    .planItem
                                    .title,
                              ),
                            ],

                            const SizedBox(height: 8),

                            Text(
                              unscheduled.reason,
                            ),
                          ],
                        ),
                      ),

                      Text(
                        '${unscheduled.planItem.credits.toInt()} cr',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'The section information shown here is currently '
                'test data. Once TigerPath receives real upcoming '
                'Tiger Portal course sections, this same scheduling '
                'system can use the actual professors, times, '
                'locations, and available sections.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}