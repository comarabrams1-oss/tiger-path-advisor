import 'package:flutter/material.dart';

import '../services/schedule_generation_service.dart';
import 'info_tip.dart';

/// Courses without a weekly slot remain visible, without inventing class times.
class NonTimetabledCourses extends StatelessWidget {
  final List<ScheduledCourseSection> courses;
  const NonTimetabledCourses({super.key, required this.courses});

  @override
  Widget build(BuildContext context) {
    final flexible = courses.where((i) => !i.section.hasWeeklyMeeting).toList();
    if (flexible.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Outside the weekly grid',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const InfoTip(
                label: 'About courses without weekly times',
                message: 'These courses are included in your course and credit totals. Asynchronous courses have no fixed weekly slot; check Canvas for deadlines and any appointments. Unknown meeting times still need verification.',
              ),
            ],
          ),
          for (final item in flexible)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          item.section.courseCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        Chip(
                          avatar: Icon(
                            item.section.isAsynchronous
                                ? Icons.laptop_chromebook
                                : Icons.schedule,
                            size: 16,
                          ),
                          label: Text(
                            item.section.isAsynchronous
                                ? 'Asynchronous'
                                : 'Meeting time to confirm',
                          ),
                        ),
                      ],
                    ),
                    Text(item.planItem.title),
                    const SizedBox(height: 6),
                    Text(
                      '${item.planItem.credits.toInt()} credits · Section ${item.section.sectionNumber}',
                    ),
                    Text(
                      item.instructor?.name ?? item.section.instructorDisplay,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.section.isAsynchronous
                          ? 'No fixed meeting time · Check Canvas for deadlines.'
                          : 'Meeting days or times are missing. Confirm with your advisor before registration.',
                      style: TextStyle(
                        color: item.section.isAsynchronous
                            ? colors.onSurfaceVariant
                            : colors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
