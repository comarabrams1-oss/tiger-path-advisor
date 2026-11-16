import 'package:flutter/material.dart';

import '../models/readiness.dart';
import '../models/student.dart';

class ReadinessChecklist extends StatelessWidget {
  final ReadinessProfile profile;
  final Student student;
  final Future<void> Function(String, ReadinessEntry)? saveEntry;
  final Future<void> Function(double?)? saveGpa;
  const ReadinessChecklist({
    super.key,
    required this.profile,
    required this.student,
    this.saveEntry,
    this.saveGpa,
  });

  bool? get meetsTarget =>
      profile.targetGpa == null || !student.hasCalculatedGpa
      ? null
      : student.gpa >= profile.targetGpa!;

  Future<void> _edit(BuildContext context, ReadinessMilestone milestone) async {
    final value = await showDialog<ReadinessEntry>(
      context: context,
      builder: (_) => _MilestoneDialog(
        milestone: milestone,
        entry: profile.entry(milestone),
      ),
    );
    if (value == null || !context.mounted) return;
    try {
      await saveEntry!(milestone.id, value);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this milestone.')),
        );
      }
    }
  }

  Future<void> _editGpa(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _GpaDialog(profile.targetGpa),
    );
    if (result == null || !context.mounted) return;
    try {
      await saveGpa!(double.tryParse(result));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the GPA target.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _group(context, 'Career readiness', careerMilestones),
      const SizedBox(height: 12),
      _group(
        context,
        'Graduate-school readiness',
        graduateMilestones,
        graduate: true,
      ),
    ],
  );

  Widget _group(
    BuildContext context,
    String title,
    List<ReadinessMilestone> milestones, {
    bool graduate = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final (done, total) = profile.progress(
      milestones,
      meetsTargetGpa: graduate ? meetsTarget : null,
    );
    final percent = total == 0 ? 0 : (done / total * 100).round();
    final target = profile.targetGpa;
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey(title),
        shape: const Border(),
        title: Text(title),
        subtitle: Text('$done of $total milestones complete · $percent%'),
        children: [
          if (graduate)
            ListTile(
              title: const Text('Target GPA'),
              subtitle: Text(
                target == null
                    ? 'Set a target from your graduate program.'
                    : '${target.toStringAsFixed(2)} target · ${meetsTarget == null
                          ? 'GPA unavailable'
                          : meetsTarget!
                          ? 'Meets target'
                          : 'Below target'}',
              ),
              trailing: saveGpa == null
                  ? null
                  : const Icon(Icons.edit_outlined),
              onTap: saveGpa == null ? null : () => _editGpa(context),
            ),
          for (final milestone in milestones)
            ListTile(
              title: Text(milestone.title),
              subtitle: Text(
                [
                  profile.status(milestone).label,
                  if (profile.entry(milestone).due.isNotEmpty)
                    'Due ${profile.entry(milestone).due}',
                  if (profile.entry(milestone).evidence.isNotEmpty)
                    profile.entry(milestone).evidence,
                ].join(' · '),
              ),
              leading: Icon(
                profile.status(milestone) == ReadinessStatus.complete
                    ? Icons.check_circle_outline
                    : Icons.circle_outlined,
                color: profile.status(milestone) == ReadinessStatus.complete
                    ? colors.primary
                    : colors.onSurfaceVariant,
              ),
              trailing: saveEntry == null
                  ? null
                  : const Icon(Icons.edit_outlined, size: 18),
              onTap: saveEntry == null ? null : () => _edit(context, milestone),
            ),
        ],
      ),
    );
  }
}

class _MilestoneDialog extends StatefulWidget {
  final ReadinessMilestone milestone;
  final ReadinessEntry entry;
  const _MilestoneDialog({required this.milestone, required this.entry});

  @override
  State<_MilestoneDialog> createState() => _MilestoneDialogState();
}

class _MilestoneDialogState extends State<_MilestoneDialog> {
  late var _status = widget.entry.status;
  late var _due = widget.entry.due;
  late final _evidence = TextEditingController(text: widget.entry.evidence);

  @override
  void dispose() {
    _evidence.dispose();
    super.dispose();
  }

  Future<void> _date() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099, 12, 31),
      initialDate: DateTime.tryParse(_due) ?? DateTime.now(),
    );
    if (date != null && mounted) {
      setState(() => _due = date.toIso8601String().split('T').first);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.milestone.title),
    scrollable: true,
    content: SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<ReadinessStatus>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              for (final status in ReadinessStatus.values)
                if (status != ReadinessStatus.notApplicable ||
                    widget.milestone.optional)
                  DropdownMenuItem(value: status, child: Text(status.label)),
            ],
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _evidence,
            minLines: 2,
            maxLines: 4,
            maxLength: 280,
            decoration: const InputDecoration(labelText: 'Notes or evidence'),
          ),
          Wrap(
            children: [
              TextButton.icon(
                onPressed: _date,
                icon: const Icon(Icons.event_outlined),
                label: Text(_due.isEmpty ? 'Set due date' : _due),
              ),
              if (_due.isNotEmpty)
                IconButton(
                  onPressed: () => setState(() => _due = ''),
                  tooltip: 'Clear due date',
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          ReadinessEntry(
            status: _status,
            evidence: _evidence.text.trim(),
            due: _due,
          ),
        ),
        child: const Text('Save milestone'),
      ),
    ],
  );
}

class _GpaDialog extends StatefulWidget {
  final double? initial;
  const _GpaDialog(this.initial);
  @override
  State<_GpaDialog> createState() => _GpaDialogState();
}

class _GpaDialogState extends State<_GpaDialog> {
  final _form = GlobalKey<FormState>();
  late final _input = TextEditingController(
    text: widget.initial?.toStringAsFixed(2),
  );
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Graduate program GPA target'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _input,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Target GPA',
          hintText: '3.00',
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return null;
          final target = double.tryParse(value.trim());
          return target == null || !target.isFinite || target <= 0 || target > 4
              ? 'Enter a GPA above 0 and up to 4.00.'
              : null;
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _input.text.trim());
          }
        },
        child: const Text('Save target'),
      ),
    ],
  );
}
