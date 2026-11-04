import 'package:flutter/material.dart';

import '../models/course_section.dart';
import '../services/schedule_generation_service.dart';

class ManualScheduleChoice {
  final CourseSection section;
  final bool remove;
  const ManualScheduleChoice(this.section, {this.remove = false});
}

/// A searchable, mobile-friendly picker. Choices use imported section records.
class ManualScheduleEditor extends StatefulWidget {
  final GeneratedSchedule schedule;
  final List<CourseSection> sections;
  final Map<String, String> courseNames;
  const ManualScheduleEditor({
    super.key,
    required this.schedule,
    required this.sections,
    this.courseNames = const {},
  });
  @override
  State<ManualScheduleEditor> createState() => _ManualScheduleEditorState();
}

class _ManualScheduleEditorState extends State<ManualScheduleEditor> {
  String query = '';
  String _name(CourseSection section) {
    final name = widget.courseNames[section.courseCode] ?? section.courseName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    for (final item in widget.schedule.scheduled) {
      if (item.section.courseCode == section.courseCode) {
        return item.planItem.title;
      }
    }
    return 'Course name unavailable';
  }

  Widget _courseTile(CourseSection section, Widget action) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name(section),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${section.courseCode} · ${section.sectionNumber}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(section.instructorDisplay),
              Text(section.scheduleDisplay),
            ],
          ),
        ),
        const SizedBox(width: 8),
        action,
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final selected = {
      for (final item in widget.schedule.scheduled)
        item.section.courseCode: item.section,
    };
    final choices =
        widget.sections
            .where(
              (s) =>
                  '${_name(s)} ${s.courseCode} ${s.instructorDisplay} ${s.scheduleDisplay}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => a.courseCode.compareTo(b.courseCode));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit classes',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close class editor',
                ),
              ],
            ),
            const Text(
              'Choose a section or remove a class. The builder checks and rebuilds your draft; review all changes afterward.',
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: false,
              decoration: const InputDecoration(
                labelText: 'Search course, instructor, or time',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  if (query.isEmpty && selected.isNotEmpty) ...[
                    const Text(
                      'Current classes',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final s in selected.values)
                      _courseTile(
                        s,
                        IconButton(
                          tooltip: 'Remove ${s.courseCode}',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => Navigator.pop(
                            context,
                            ManualScheduleChoice(s, remove: true),
                          ),
                        ),
                      ),
                    const Divider(),
                  ],
                  const Text(
                    'Eligible degree sections',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (choices.isEmpty)
                    const ListTile(
                      title: Text('No eligible open sections match.'),
                    ),
                  for (final s in choices)
                    _courseTile(
                      s,
                      selected[s.courseCode]?.sectionNumber == s.sectionNumber
                          ? const Icon(
                              Icons.check_circle_outline,
                              semanticLabel: 'Selected section',
                            )
                          : TextButton(
                              onPressed: () => Navigator.pop(
                                context,
                                ManualScheduleChoice(s),
                              ),
                              child: Text(
                                selected.containsKey(s.courseCode)
                                    ? 'Switch'
                                    : 'Add',
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
