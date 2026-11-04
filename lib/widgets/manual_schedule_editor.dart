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
  const ManualScheduleEditor({
    super.key,
    required this.schedule,
    required this.sections,
  });
  @override
  State<ManualScheduleEditor> createState() => _ManualScheduleEditorState();
}

class _ManualScheduleEditorState extends State<ManualScheduleEditor> {
  String query = '';
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
                  '${s.courseCode} ${s.instructorDisplay} ${s.scheduleDisplay}'
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
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${s.courseCode} · ${s.sectionNumber}'),
                        subtitle: Text(
                          '${s.instructorDisplay}\n${s.scheduleDisplay}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
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
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${s.courseCode} · ${s.sectionNumber}'),
                      subtitle: Text(
                        '${s.instructorDisplay}\n${s.scheduleDisplay}',
                      ),
                      isThreeLine: true,
                      trailing:
                          selected[s.courseCode]?.sectionNumber ==
                              s.sectionNumber
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
