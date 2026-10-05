import 'package:flutter/material.dart';

import '../data/test_course_sections.dart';
import '../data/test_instructors.dart';
import '../models/schedule_preferences.dart';
import '../services/preferences_service.dart';
import '../services/schedule_generation_service.dart';
import '../services/semester_plan_service.dart';

enum ScheduleView {
  weekly,
  list,
}

class GeneratedScheduleScreen extends StatefulWidget {
  final SemesterPlan plan;

  const GeneratedScheduleScreen({
    super.key,
    required this.plan,
  });

  @override
  State<GeneratedScheduleScreen> createState() =>
      _GeneratedScheduleScreenState();
}

class _GeneratedScheduleScreenState
    extends State<GeneratedScheduleScreen> {
  ScheduleView selectedView = ScheduleView.weekly;

  final List<String> days = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

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
      plan: widget.plan,
      sections: testCourseSections,
      instructors: testInstructors,
      preferences: preferences,
    );

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated Schedule'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1200,
          ),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Your Semester Schedule',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tiger Path Advisor selected the best available sections based on your semester plan and schedule preferences.',
                style: TextStyle(
                  fontSize: 15,
                  color: colors.onSurface.withValues(
                    alpha: 0.65,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildSummary(
                context,
                generatedSchedule,
                preferences,
              ),

              const SizedBox(height: 22),

              _buildViewToggle(context),

              const SizedBox(height: 20),

              if (selectedView ==
                  ScheduleView.weekly)
                _buildWeeklyView(
                  context,
                  generatedSchedule,
                )
              else
                _buildListView(
                  context,
                  generatedSchedule,
                ),

              if (generatedSchedule
                  .unscheduled.isNotEmpty) ...[
                const SizedBox(height: 30),
                _buildUnscheduledSection(
                  context,
                  generatedSchedule,
                ),
              ],

              const SizedBox(height: 24),

              _buildDataNotice(context),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    GeneratedSchedule schedule,
    SchedulePreferences preferences,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 650;

          final items = [
            _summaryItem(
              context,
              Icons.school_outlined,
              '${schedule.scheduled.length}',
              'Courses',
            ),
            _summaryItem(
              context,
              Icons.menu_book_outlined,
              '${schedule.scheduledCredits.toInt()}',
              'Credits',
            ),
            _summaryItem(
              context,
              Icons.schedule_outlined,
              preferences.preferredTime,
              'Preferred Time',
            ),
            _summaryItem(
              context,
              Icons.warning_amber_outlined,
              '${schedule.unscheduled.length}',
              'Unresolved',
            ),
          ];

          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: items[0],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: items[1],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: items[2],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: items[3],
                    ),
                  ],
                ),
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
              const SizedBox(width: 10),
              Expanded(child: items[3]),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 15,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFFFFD22E),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.75,
              ),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(
    BuildContext context,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.primary.withValues(
            alpha: 0.08,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _viewButton(
              context,
              view: ScheduleView.weekly,
              icon: Icons.calendar_view_week_outlined,
              label: 'Weekly View',
            ),
            _viewButton(
              context,
              view: ScheduleView.list,
              icon: Icons.view_agenda_outlined,
              label: 'List View',
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewButton(
    BuildContext context, {
    required ScheduleView view,
    required IconData icon,
    required String label,
  }) {
    final colors = Theme.of(context).colorScheme;

    final selected =
        selectedView == view;

    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () {
        setState(() {
          selectedView = view;
        });
      },
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? colors.onPrimary
                  : colors.primary,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected
                    ? colors.onPrimary
                    : colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyView(
    BuildContext context,
    GeneratedSchedule schedule,
  ) {
    final colors = Theme.of(context).colorScheme;

    if (schedule.scheduled.isEmpty) {
      return _emptyState(
        context,
        'No classes have been scheduled yet.',
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Schedule',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Scroll horizontally on smaller screens.',
          style: TextStyle(
            color: colors.onSurface.withValues(
              alpha: 0.55,
            ),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (context, constraints) {
            final width =
                constraints.maxWidth < 1000
                    ? 1000.0
                    : constraints.maxWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: days.map(
                    (day) {
                      return Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.only(
                            right: 10,
                          ),
                          child: _buildDayColumn(
                            context,
                            day,
                            schedule,
                          ),
                        ),
                      );
                    },
                  ).toList(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    String day,
    GeneratedSchedule schedule,
  ) {
    final colors = Theme.of(context).colorScheme;

    final classes = schedule.scheduled
        .where(
          (item) =>
              item.section.days.contains(day),
        )
        .toList()
      ..sort(
        (a, b) =>
            a.section.startMinutes.compareTo(
          b.section.startMinutes,
        ),
      );

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.onSurface.withValues(
            alpha: 0.10,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius:
                  const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
            ),
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          if (classes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'No classes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.onSurface
                      .withValues(alpha: 0.45),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: classes.map(
                  (scheduled) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 10,
                      ),
                      child: _weeklyClassBlock(
                        context,
                        scheduled,
                      ),
                    );
                  },
                ).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _weeklyClassBlock(
    BuildContext context,
    ScheduledCourseSection scheduled,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(
          alpha: 0.09,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: colors.primary.withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            scheduled.section.courseCode,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: colors.primary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${scheduled.section.startTime} - ${scheduled.section.endTime}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            scheduled.instructor?.name ??
                'Instructor TBD',
            style: TextStyle(
              color: colors.onSurface.withValues(
                alpha: 0.68,
              ),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            scheduled.section.location,
            style: TextStyle(
              color: colors.onSurface.withValues(
                alpha: 0.55,
              ),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    GeneratedSchedule schedule,
  ) {
    final colors = Theme.of(context).colorScheme;

    if (schedule.scheduled.isEmpty) {
      return _emptyState(
        context,
        'No classes have been scheduled yet.',
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Scheduled Classes',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 14),

        ...schedule.scheduled.map(
          (scheduled) {
            return Card(
              margin: const EdgeInsets.only(
                bottom: 12,
              ),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape:
                    const Border(),
                tilePadding:
                    const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                childrenPadding:
                    const EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  18,
                ),
                leading: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: colors.primary
                        .withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.menu_book_outlined,
                    color: colors.primary,
                  ),
                ),
                title: Text(
                  scheduled.section.courseCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${scheduled.section.days.join(' / ')} • ${scheduled.section.startTime} - ${scheduled.section.endTime}',
                ),
                children: [
                  _detailRow(
                    context,
                    'Course',
                    scheduled.planItem.title,
                  ),
                  _detailRow(
                    context,
                    'Section',
                    scheduled.section.sectionNumber,
                  ),
                  _detailRow(
                    context,
                    'Professor',
                    scheduled.instructor?.name ??
                        'Instructor TBD',
                  ),
                  _detailRow(
                    context,
                    'Location',
                    scheduled.section.location,
                  ),
                  _detailRow(
                    context,
                    'Delivery',
                    scheduled
                        .section.deliveryMethod,
                  ),

                  if (scheduled.section.openSeats !=
                      null)
                    _detailRow(
                      context,
                      'Open Seats',
                      scheduled.section.capacity ==
                              null
                          ? '${scheduled.section.openSeats}'
                          : '${scheduled.section.openSeats} / ${scheduled.section.capacity}',
                    ),

                  if (scheduled
                      .matchReasons.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Align(
                      alignment:
                          Alignment.centerLeft,
                      child: Text(
                        'Why this section?',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),

                    ...scheduled.matchReasons.map(
                      (reason) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(
                            bottom: 5,
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color:
                                    colors.primary,
                              ),
                              const SizedBox(
                                width: 7,
                              ),
                              Expanded(
                                child:
                                    Text(reason),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colors.onSurface
                    .withValues(alpha: 0.60),
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildUnscheduledSection(
    BuildContext context,
    GeneratedSchedule schedule,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Still Unscheduled',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'These requirements could not be placed into the current schedule.',
          style: TextStyle(
            color: colors.onSurface.withValues(
              alpha: 0.60,
            ),
          ),
        ),
        const SizedBox(height: 14),

        ...schedule.unscheduled.map(
          (unscheduled) {
            return Card(
              margin: const EdgeInsets.only(
                bottom: 12,
              ),
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.error
                            .withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.warning_amber_outlined,
                        color: colors.error,
                      ),
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
                            style: TextStyle(
                              color: colors.onSurface
                                  .withValues(
                                alpha: 0.68,
                              ),
                            ),
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
            );
          },
        ),
      ],
    );
  }

  Widget _buildDataNotice(
    BuildContext context,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.primary.withValues(
          alpha: 0.07,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: colors.primary,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'The section information shown here currently uses demonstration data. Once current Tiger Portal course sections are imported, the same scheduling system can use actual professors, times, locations, seat availability, and section status.',
              style: TextStyle(
                color: colors.onSurface.withValues(
                  alpha: 0.72,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(
    BuildContext context,
    String message,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.onSurface.withValues(
            alpha: 0.10,
          ),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 38,
            color: colors.primary,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}