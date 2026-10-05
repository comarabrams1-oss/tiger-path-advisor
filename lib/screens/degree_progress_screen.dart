import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../data/cs_program.dart';
import '../data/test_student.dart';
import '../models/degree_program.dart';
import '../services/degree_audit_service.dart';

const _benedictPurple = Color(0xFF3A0B5C);
const _benedictDarkPurple = Color(0xFF26063E);
const _benedictGold = Color(0xFFFFD22E);
const _pageBackground = Color(0xFFF7F4FA);

class DegreeProgressScreen extends StatefulWidget {
  const DegreeProgressScreen({super.key});

  @override
  State<DegreeProgressScreen> createState() =>
      _DegreeProgressScreenState();
}

class _DegreeProgressScreenState
    extends State<DegreeProgressScreen> {
  RequirementStatus? _selectedStatus;

  void _toggleStatusFilter(RequirementStatus status) {
    setState(() {
      _selectedStatus = _selectedStatus == status ? null : status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auditService = DegreeAuditService();

    final audit = auditService.auditProgram(
      testStudent,
      benedictComputerScience2024,
    );

    final completedCredits = testStudent.earnedCredits;
    final inProgressCredits = testStudent.inProgressCredits;
    final requiredCredits = testStudent.requiredCredits;

    final projectedCredits = math.min(
  requiredCredits,
  completedCredits + inProgressCredits,
).toDouble();

    final completedProgress =
        (completedCredits / requiredCredits).clamp(0.0, 1.0);

    final projectedProgress =
        (projectedCredits / requiredCredits).clamp(0.0, 1.0);

    final projectedRemaining = math.max(
  0,
  requiredCredits - projectedCredits,
).toDouble();

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const Text('Degree Progress'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(),
          const SizedBox(height: 22),
          _buildOverallProgress(
            completedCredits: completedCredits,
            inProgressCredits: inProgressCredits,
            requiredCredits: requiredCredits,
            projectedCredits: projectedCredits,
            projectedRemaining: projectedRemaining,
            completedProgress: completedProgress,
            projectedProgress: projectedProgress,
          ),
          const SizedBox(height: 26),
          _buildStatusLegend(),
          const SizedBox(height: 24),
          _buildCategory(
            context,
            title: 'General Education',
            icon: Icons.menu_book_outlined,
            items: _itemsForCategory(
              audit,
              'General Education',
            ),
          ),
          const SizedBox(height: 14),
          _buildCategory(
            context,
            title: 'Major',
            icon: Icons.computer_outlined,
            items: _itemsForCategory(
              audit,
              'Major',
            ),
            initiallyExpanded: true,
          ),
          const SizedBox(height: 14),
          _buildCategory(
            context,
            title: 'Support',
            icon: Icons.calculate_outlined,
            items: _itemsForCategory(
              audit,
              'Support',
            ),
          ),
          const SizedBox(height: 14),
          _buildCategory(
            context,
            title: 'Electives',
            icon: Icons.explore_outlined,
            items: _itemsForCategory(
              audit,
              'Electives',
            ),
          ),
          const SizedBox(height: 14),
          _buildCategory(
            context,
            title: 'Graduation',
            icon: Icons.workspace_premium_outlined,
            items: _itemsForCategory(
              audit,
              'Graduation',
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Computer Science - B.S.',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: _benedictDarkPurple,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '${testStudent.institution} • Catalog ${testStudent.catalogYear}',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildOverallProgress({
    required double completedCredits,
    required double inProgressCredits,
    required double requiredCredits,
    required double projectedCredits,
    required double projectedRemaining,
    required double completedProgress,
    required double projectedProgress,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _benedictDarkPurple,
            _benedictPurple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _benedictPurple.withValues(
              alpha: 0.18,
            ),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall Graduation Progress',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _summaryBox(
                  value:
                      '${completedCredits.toInt()} / ${requiredCredits.toInt()}',
                  label: 'Credits Completed',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryBox(
                  value: testStudent.gpa.toStringAsFixed(2),
                  label: 'Cumulative GPA',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryBox(
                  value: inProgressCredits.toInt().toString(),
                  label: 'In Progress',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _progressLabel(
            label: 'Completed',
            value:
                '${(completedProgress * 100).toStringAsFixed(1)}%',
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: completedProgress,
              minHeight: 11,
              backgroundColor:
                  Colors.white.withValues(alpha: 0.18),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(
                _benedictGold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _progressLabel(
            label: 'Projected after current semester',
            value:
                '${projectedCredits.toInt()} / ${requiredCredits.toInt()}',
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: projectedProgress,
              minHeight: 11,
              backgroundColor:
                  Colors.white.withValues(alpha: 0.18),
              valueColor:
                  AlwaysStoppedAnimation<Color>(
                _benedictGold.withValues(alpha: 0.72),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(projectedProgress * 100).toStringAsFixed(1)}% projected • '
            '${projectedRemaining.toInt()} credits remaining after current semester',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox({
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressLabel({
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusLegend() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _selectedStatus == null
            ? 'Tap a status to filter requirements'
            : 'Showing ${_statusText(_selectedStatus!)} requirements',
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _legendChip(
            status: RequirementStatus.completed,
            icon: Icons.check_circle,
            text: 'Completed',
            color: Colors.green.shade700,
          ),
          _legendChip(
            status: RequirementStatus.inProgress,
            icon: Icons.schedule,
            text: 'In Progress',
            color: Colors.orange.shade800,
          ),
          _legendChip(
            status: RequirementStatus.remaining,
            icon: Icons.radio_button_unchecked,
            text: 'Remaining',
            color: Colors.grey.shade700,
          ),
        ],
      ),
    ],
  );
}

  Widget _legendChip({
  required RequirementStatus status,
  required IconData icon,
  required String text,
  required Color color,
}) {
  final selected = _selectedStatus == status;

  return InkWell(
    borderRadius: BorderRadius.circular(30),
    onTap: () => _toggleStatusFilter(status),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.12)
            : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: selected
              ? color
              : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 19,
            color: color,
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? color : null,
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 7),
            Icon(
              Icons.close,
              size: 16,
              color: color,
            ),
          ],
        ],
      ),
    ),
  );
}

  List<DegreeAuditItem> _itemsForCategory(
    List<DegreeAuditItem> audit,
    String category,
  ) {
    return audit
        .where(
          (item) =>
              item.requirement.category == category,
        )
        .toList();
  }

  Widget _buildCategory(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<DegreeAuditItem> items,
    bool initiallyExpanded = false,
  }) {
    final completed = items
        .where(
          (item) =>
              item.status ==
              RequirementStatus.completed,
        )
        .length;

    final inProgress = items
        .where(
          (item) =>
              item.status ==
              RequirementStatus.inProgress,
        )
        .length;

    final remaining = items
        .where(
          (item) =>
              item.status ==
              RequirementStatus.remaining,
        )
        .length;

    final progress =
        items.isEmpty ? 0.0 : completed / items.length;
    final visibleItems = _selectedStatus == null
    ? items
    : items
        .where(
          (item) =>
              item.status == _selectedStatus,
        )
        .toList();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16,
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF2EAF7),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: _benedictPurple,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _benedictDarkPurple,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                _sectionSummary(
                  completed,
                  inProgress,
                  remaining,
                ),
                style: TextStyle(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor:
                      const Color(0xFFEADDF1),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(
                    _benedictPurple,
                  ),
                ),
              ),
            ],
          ),
        ),
       children: visibleItems.isEmpty
    ? [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No ${_selectedStatus == null ? '' : _statusText(_selectedStatus!).toLowerCase()} requirements in this section.',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ]
    : visibleItems
        .map(
          (item) => _buildRequirementCard(
            context,
            item,
          ),
        )
        .toList(),
      ),
    );
  }

  String _sectionSummary(
    int completed,
    int inProgress,
    int remaining,
  ) {
    final parts = <String>[];

    if (completed > 0) {
      parts.add('$completed completed');
    }

    if (inProgress > 0) {
      parts.add('$inProgress in progress');
    }

    if (remaining > 0) {
      parts.add('$remaining remaining');
    }

    if (parts.isEmpty) {
      return 'No requirements';
    }

    return parts.join(' • ');
  }

  Widget _buildRequirementCard(
    BuildContext context,
    DegreeAuditItem item,
  ) {
    final requirement = item.requirement;

    final statusColor = _statusColor(item.status);
    final statusIcon = _statusIcon(item.status);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 23,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        requirement.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (requirement.creditsRequired > 0)
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 10),
                        child: Text(
                          _creditLabel(item),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                _statusBadge(
                  _statusText(item.status),
                  statusColor,
                ),
                const SizedBox(height: 10),
                Text(
                  _requirementProgressText(item),
                  style: TextStyle(
                    color: Colors.grey.shade800,
                  ),
                ),
                if (requirement.courseCodes
                    .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    requirement.courseCodes.join(' / '),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (requirement.minimumGrade != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    'Minimum grade: ${requirement.minimumGrade}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
                if (requirement.type ==
                    RequirementType.minimumGpa) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Current GPA: ${testStudent.gpa.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Required GPA: ${(requirement.minimumGpa ?? 0).toStringAsFixed(2)}',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _creditLabel(
    DegreeAuditItem item,
  ) {
    final requirement = item.requirement;

    if (requirement.type ==
        RequirementType.creditHours) {
      final remaining = math.max(
        0,
        requirement.creditsRequired -
            item.completedCredits -
            item.inProgressCredits,
      );

      if (item.status ==
          RequirementStatus.remaining) {
        return '${remaining.toInt()} cr left';
      }
    }

    return '${requirement.creditsRequired.toInt()} cr';
  }

  String _requirementProgressText(
    DegreeAuditItem item,
  ) {
    final requirement = item.requirement;

    if (requirement.title ==
        'Global & Intercultural Learning') {
      final remaining = math.max(
        0,
        requirement.creditsRequired -
            item.completedCredits -
            item.inProgressCredits,
      );

      return '${item.completedCredits.toInt()} of '
          '${requirement.creditsRequired.toInt()} credits completed • '
          '${remaining.toInt()} additional approved credits required';
    }

    if (requirement.title == 'Free Electives') {
      return 'Requirement met according to your degree audit.';
    }

    if (requirement.type ==
        RequirementType.totalCredits) {
      final projected =
          testStudent.earnedCredits +
              testStudent.inProgressCredits;

      final remaining = math.max(
        0,
        testStudent.requiredCredits - projected,
      );

      return '${testStudent.earnedCredits.toInt()} completed • '
          '${testStudent.inProgressCredits.toInt()} in progress\n'
          'Projected: ${projected.toInt()} / '
          '${testStudent.requiredCredits.toInt()} • '
          '${remaining.toInt()} credits remaining';
    }

    if (requirement.type ==
        RequirementType.minimumGpa) {
      return testStudent.gpa >=
              (requirement.minimumGpa ?? 0)
          ? 'GPA requirement met'
          : 'GPA requirement not yet met';
    }

    if (requirement.type ==
        RequirementType.creditHours) {
      if (item.inProgressCredits > 0) {
        return '${item.completedCredits.toInt()} of '
            '${requirement.creditsRequired.toInt()} completed • '
            '${item.inProgressCredits.toInt()} in progress';
      }

      return '${item.completedCredits.toInt()} of '
          '${requirement.creditsRequired.toInt()} credits completed';
    }

    if (requirement.type ==
        RequirementType.elective) {
      return item.status ==
              RequirementStatus.completed
          ? 'Requirement completed'
          : 'Approved elective credit is still required';
    }

    switch (item.status) {
      case RequirementStatus.completed:
        return 'Requirement completed';

      case RequirementStatus.inProgress:
        return 'Currently in progress';

      case RequirementStatus.remaining:
        return 'Still required for your degree';
    }
  }

  Widget _statusBadge(
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _statusColor(
    RequirementStatus status,
  ) {
    switch (status) {
      case RequirementStatus.completed:
        return Colors.green.shade700;

      case RequirementStatus.inProgress:
        return Colors.orange.shade800;

      case RequirementStatus.remaining:
        return Colors.grey.shade700;
    }
  }

  IconData _statusIcon(
    RequirementStatus status,
  ) {
    switch (status) {
      case RequirementStatus.completed:
        return Icons.check_circle;

      case RequirementStatus.inProgress:
        return Icons.schedule;

      case RequirementStatus.remaining:
        return Icons.radio_button_unchecked;
    }
  }

  String _statusText(
    RequirementStatus status,
  ) {
    switch (status) {
      case RequirementStatus.completed:
        return 'Completed';

      case RequirementStatus.inProgress:
        return 'In Progress';

      case RequirementStatus.remaining:
        return 'Remaining';
    }
  }
}