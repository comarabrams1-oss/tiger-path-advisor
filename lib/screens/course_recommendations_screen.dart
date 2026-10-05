import 'package:flutter/material.dart';
import '../data/cs_course_catalog.dart';
import '../data/cs_program.dart';
import '../data/test_student.dart';
import '../models/degree_program.dart';
import '../services/course_eligibility_service.dart';
import '../services/course_priority_service.dart';
import '../services/degree_audit_service.dart';

const _purple = Color(0xFF3A0B5C);
const _darkPurple = Color(0xFF26063E);
const _gold = Color(0xFFFFD22E);
const _background = Color(0xFFF7F4FA);

enum RecommendationView {
  recommended,
  needed,
  eligible,
  later,
}

class CourseRecommendationsScreen extends StatefulWidget {
  const CourseRecommendationsScreen({super.key});

  @override
  State<CourseRecommendationsScreen> createState() =>
      _CourseRecommendationsScreenState();
}

class _CourseRecommendationsScreenState
    extends State<CourseRecommendationsScreen> {
  RecommendationView _selectedView =
      RecommendationView.recommended;

  @override
  Widget build(BuildContext context) {
    final eligibilityService = CourseEligibilityService();
    final priorityService = CoursePriorityService();
    final auditService = DegreeAuditService();

    final eligibilityResults =
        eligibilityService.checkProgramCourses(
      testStudent,
      benedictComputerScience2024,
      computerScienceCourseCatalog,
    );

    final priorityResults = priorityService.rankCourses(
      testStudent,
      benedictComputerScience2024,
      computerScienceCourseCatalog,
    );

    final audit = auditService.auditProgram(
      testStudent,
      benedictComputerScience2024,
    );

    final remainingRequirements = audit
        .where(
          (item) =>
              item.status == RequirementStatus.remaining &&
              item.requirement.category != 'Graduation',
        )
        .toList();

    final readyNow = eligibilityResults
        .where(
          (result) =>
              result.status == EligibilityStatus.eligible,
        )
        .toList();

    final later = eligibilityResults
        .where(
          (result) =>
              result.status != EligibilityStatus.eligible,
        )
        .toList();

    final recommendedNext = priorityResults
        .where(
          (result) =>
              result.eligibility.status ==
                  EligibilityStatus.eligible ||
              result.eligibility.status ==
                  EligibilityStatus.eligibleAfterCurrentTerm,
        )
        .take(5)
        .toList();

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Course Recommendations'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(),
          const SizedBox(height: 22),

          _buildOverview(
            remainingRequirements.length,
            readyNow.length,
            recommendedNext.length,
          ),

          const SizedBox(height: 22),

          _buildNavigation(
            recommendedCount: recommendedNext.length,
            neededCount: remainingRequirements.length,
            eligibleCount: readyNow.length,
            laterCount: later.length,
          ),

          const SizedBox(height: 24),

          _buildSelectedContent(
            context,
            recommendedNext: recommendedNext,
            remainingRequirements: remainingRequirements,
            readyNow: readyNow,
            later: later,
          ),

          const SizedBox(height: 20),

          _buildDisclaimer(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Academic Advice',
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.bold,
            color: _darkPurple,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Recommendations based on your degree requirements, '
          'completed courses, current enrollment, and prerequisites.',
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(
    int remaining,
    int eligible,
    int recommended,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _darkPurple,
            _purple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _overviewItem(
              value: '$recommended',
              label: 'Top Picks',
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _overviewItem(
              value: '$eligible',
              label: 'Eligible Now',
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _overviewItem(
              value: '$remaining',
              label: 'Requirements Left',
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewItem({
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 42,
      color: Colors.white.withValues(alpha: 0.18),
    );
  }

  Widget _buildNavigation({
    required int recommendedCount,
    required int neededCount,
    required int eligibleCount,
    required int laterCount,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _filterChip(
          view: RecommendationView.recommended,
          icon: Icons.auto_awesome,
          label: 'Recommended',
          count: recommendedCount,
        ),
        _filterChip(
          view: RecommendationView.needed,
          icon: Icons.assignment_outlined,
          label: 'Need',
          count: neededCount,
        ),
        _filterChip(
          view: RecommendationView.eligible,
          icon: Icons.check_circle_outline,
          label: 'Eligible Now',
          count: eligibleCount,
        ),
        _filterChip(
          view: RecommendationView.later,
          icon: Icons.schedule,
          label: 'Later',
          count: laterCount,
        ),
      ],
    );
  }

  Widget _filterChip({
    required RecommendationView view,
    required IconData icon,
    required String label,
    required int count,
  }) {
    final selected = _selectedView == view;

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () {
        setState(() {
          _selectedView = view;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected ? _purple : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? _purple
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? _gold
                  : _purple,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : _darkPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              constraints: const BoxConstraints(
                minWidth: 24,
              ),
              height: 24,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.16)
                    : const Color(0xFFF0E8F5),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : _purple,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedContent(
    BuildContext context, {
    required List<CoursePriorityResult> recommendedNext,
    required List<DegreeAuditItem> remainingRequirements,
    required List<CourseEligibilityResult> readyNow,
    required List<CourseEligibilityResult> later,
  }) {
    switch (_selectedView) {
      case RecommendationView.recommended:
        return _buildRecommended(
          context,
          recommendedNext,
        );

      case RecommendationView.needed:
        return _buildNeeded(
          context,
          remainingRequirements,
        );

      case RecommendationView.eligible:
        return _buildEligible(
          context,
          readyNow,
        );

      case RecommendationView.later:
        return _buildLater(
          context,
          later,
        );
    }
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8F5),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: _purple,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: _darkPurple,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommended(
    BuildContext context,
    List<CoursePriorityResult> results,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.auto_awesome,
          title: 'Recommended Next',
          subtitle:
              'Strong choices based on degree progress and prerequisite sequencing.',
        ),
        if (results.isEmpty)
          _emptyState(
            'No course recommendations are available.',
          ),
        ...List.generate(
          results.length,
          (index) {
            final result = results[index];

            final eligibleNow =
                result.eligibility.status ==
                    EligibilityStatus.eligible;

            return _courseCard(
              leading: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _purple,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              code: result.course.code,
              title: result.course.title,
              credits: result.course.credits,
              badge: eligibleNow
                  ? 'Eligible Now'
                  : 'After Current Term',
              badgeColor: eligibleNow
                  ? Colors.green.shade700
                  : Colors.orange.shade800,
              body: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Why recommended',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...result.reasons.map(
                    (reason) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(
                            child: Text(reason),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNeeded(
    BuildContext context,
    List<DegreeAuditItem> requirements,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.assignment_outlined,
          title: 'Still Needed',
          subtitle:
              'Official requirements that are not yet complete.',
        ),
        if (requirements.isEmpty)
          _emptyState(
            'No remaining degree requirements.',
          ),
        ...requirements.map(
          (item) {
            final requirement = item.requirement;

            return _requirementCard(
              item,
              title: requirement.title,
              category: requirement.category,
              message: _requirementMessage(item),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEligible(
    BuildContext context,
    List<CourseEligibilityResult> results,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.check_circle_outline,
          title: 'Eligible Now',
          subtitle:
              'Courses whose prerequisites are already satisfied.',
        ),
        if (results.isEmpty)
          _emptyState(
            'No courses are currently eligible.',
          ),
        ...results.map(
          (result) => _courseCard(
            leading: _statusIcon(
              Icons.check,
              Colors.green.shade700,
            ),
            code: result.course.code,
            title: result.course.title,
            credits: result.course.credits,
            badge: 'Eligible Now',
            badgeColor: Colors.green.shade700,
            body: result.reason == null
                ? null
                : Text(result.reason!),
          ),
        ),
      ],
    );
  }

  Widget _buildLater(
    BuildContext context,
    List<CourseEligibilityResult> results,
  ) {
    final afterCurrentTerm = results
        .where(
          (result) =>
              result.status ==
              EligibilityStatus.eligibleAfterCurrentTerm,
        )
        .toList();

    final permission = results
        .where(
          (result) =>
              result.status ==
              EligibilityStatus.requiresPermission,
        )
        .toList();

    final blocked = results
        .where(
          (result) =>
              result.status ==
              EligibilityStatus.blocked,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          icon: Icons.schedule,
          title: 'Later',
          subtitle:
              'Courses that require current coursework, permission, or additional prerequisites.',
        ),

        if (afterCurrentTerm.isNotEmpty) ...[
          _subheading(
            'After Current Semester',
          ),
          ...afterCurrentTerm.map(
            (result) => _laterCard(
              result,
              badge: 'After Current Term',
              color: Colors.orange.shade800,
              icon: Icons.schedule,
            ),
          ),
          const SizedBox(height: 18),
        ],

        if (permission.isNotEmpty) ...[
          _subheading(
            'Instructor Permission',
          ),
          ...permission.map(
            (result) => _laterCard(
              result,
              badge: 'Permission Required',
              color: Colors.blue.shade700,
              icon: Icons.person_outline,
            ),
          ),
          const SizedBox(height: 18),
        ],

        if (blocked.isNotEmpty) ...[
          _subheading(
            'Not Yet Eligible',
          ),
          ...blocked.map(
            (result) => _laterCard(
              result,
              badge: 'Prerequisites Needed',
              color: Colors.grey.shade700,
              icon: Icons.lock_outline,
            ),
          ),
        ],

        if (results.isEmpty)
          _emptyState(
            'No later courses to display.',
          ),
      ],
    );
  }

  Widget _laterCard(
    CourseEligibilityResult result, {
    required String badge,
    required Color color,
    required IconData icon,
  }) {
    String? extraText;

    if (result.missingPrerequisites.isNotEmpty) {
      extraText =
          'Missing: ${result.missingPrerequisites.join(', ')}';
    } else if (result.reason != null) {
      extraText = result.reason;
    }

    return _courseCard(
      leading: _statusIcon(
        icon,
        color,
      ),
      code: result.course.code,
      title: result.course.title,
      credits: result.course.credits,
      badge: badge,
      badgeColor: color,
      body:
          extraText == null ? null : Text(extraText),
    );
  }

  Widget _courseCard({
    required Widget leading,
    required String code,
    required String title,
    required double credits,
    required String badge,
    required Color badgeColor,
    Widget? body,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            leading,
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
                          code,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${credits.toInt()} cr',
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(title),
                  const SizedBox(height: 9),
                  _badge(
                    badge,
                    badgeColor,
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 12),
                    body,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requirementCard(
    DegreeAuditItem item, {
    required String title,
    required String category,
    required String message,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _statusIcon(
              Icons.priority_high,
              Colors.orange.shade800,
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
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        _requirementCreditLabel(
                          item,
                        ),
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(message),
                  if (item.requirement.courseCodes
                      .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      item.requirement.courseCodes
                          .join(' / '),
                      style: const TextStyle(
                        color: _purple,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _requirementCreditLabel(
    DegreeAuditItem item,
  ) {
    final requirement = item.requirement;

    if (requirement.type ==
        RequirementType.creditHours) {
      final remaining =
          requirement.creditsRequired -
              item.completedCredits -
              item.inProgressCredits;

      return '${remaining.clamp(0, requirement.creditsRequired).toInt()} cr left';
    }

    return '${requirement.creditsRequired.toInt()} cr';
  }

  String _requirementMessage(
    DegreeAuditItem item,
  ) {
    final requirement = item.requirement;

    switch (requirement.type) {
      case RequirementType.requiredCourse:
        return 'Required course still needs to be completed.';

      case RequirementType.oneOfCourses:
        return 'Complete one approved course for this requirement.';

      case RequirementType.creditHours:
        final remaining =
            requirement.creditsRequired -
                item.completedCredits -
                item.inProgressCredits;

        return '${remaining.clamp(0, requirement.creditsRequired).toInt()} additional approved credits required.';

      case RequirementType.elective:
        return 'Approved elective credit is still required.';

      case RequirementType.totalCredits:
        return 'Additional credits are required for graduation.';

      case RequirementType.minimumGpa:
        return 'Minimum GPA requirement has not yet been met.';
    }
  }

  Widget _badge(
    String text,
    Color color,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
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
      ),
    );
  }

  Widget _statusIcon(
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: color,
      ),
    );
  }

  Widget _subheading(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: _darkPurple,
        ),
      ),
    );
  }

  Widget _emptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0E8F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: _purple,
          ),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Actual enrollment also depends on course availability, '
              'section times, open seats, and official advising requirements.',
            ),
          ),
        ],
      ),
    );
  }
}