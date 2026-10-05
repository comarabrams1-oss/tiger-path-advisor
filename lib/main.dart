import 'package:flutter/material.dart';

import 'data/test_student.dart';
import 'screens/course_recommendations_screen.dart';
import 'screens/degree_progress_screen.dart';
import 'screens/schedule_preferences_screen.dart';
import 'screens/transcript_screen.dart';

const benedictPurple = Color(0xFF3A0B5C);
const benedictDarkPurple = Color(0xFF26063E);
const benedictGold = Color(0xFFFFD22E);

enum AppThemeChoice {
  benedict,
  light,
  dark,
}

void main() {
  runApp(const TigerPathAdvisorApp());
}

class TigerPathAdvisorApp extends StatefulWidget {
  const TigerPathAdvisorApp({super.key});

  @override
  State<TigerPathAdvisorApp> createState() =>
      _TigerPathAdvisorAppState();
}

class _TigerPathAdvisorAppState
    extends State<TigerPathAdvisorApp> {
  AppThemeChoice _themeChoice = AppThemeChoice.benedict;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tiger Path Advisor',
      theme: _buildTheme(_themeChoice),
      home: HomeScreen(
        themeChoice: _themeChoice,
        onThemeChanged: (theme) {
          setState(() {
            _themeChoice = theme;
          });
        },
      ),
    );
  }

  ThemeData _buildTheme(AppThemeChoice choice) {
    switch (choice) {
      case AppThemeChoice.benedict:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor:
              const Color(0xFFF7F4FA),
          colorScheme: ColorScheme.fromSeed(
            seedColor: benedictPurple,
            brightness: Brightness.light,
          ).copyWith(
            primary: benedictPurple,
            secondary: benedictGold,
            surface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: benedictPurple,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );

      case AppThemeChoice.light:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor:
              const Color(0xFFF4F5F7),
          colorScheme: ColorScheme.fromSeed(
            seedColor: benedictPurple,
            brightness: Brightness.light,
          ).copyWith(
            primary: benedictPurple,
            secondary: benedictGold,
            surface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: benedictDarkPurple,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );

      case AppThemeChoice.dark:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor:
              const Color(0xFF111014),
          colorScheme: ColorScheme.fromSeed(
            seedColor: benedictPurple,
            brightness: Brightness.dark,
          ).copyWith(
            primary: const Color(0xFFCE9EEC),
            secondary: benedictGold,
            surface: const Color(0xFF1D1A21),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A0926),
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF1D1A21),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
    }
  }
}

class HomeScreen extends StatelessWidget {
  final AppThemeChoice themeChoice;
  final ValueChanged<AppThemeChoice> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.themeChoice,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        (testStudent.earnedCredits / testStudent.requiredCredits)
            .clamp(0.0, 1.0);

    final projectedCredits =
        testStudent.earnedCredits +
        testStudent.inProgressCredits;

    final projectedProgress =
        (projectedCredits / testStudent.requiredCredits)
            .clamp(0.0, 1.0);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1100,
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              28,
              20,
              24,
            ),
            children: [
              _buildHero(context),
              const SizedBox(height: 22),

              _buildAcademicSnapshot(
                context,
                progress: progress,
                projectedProgress: projectedProgress,
                projectedCredits: projectedCredits,
              ),

              const SizedBox(height: 32),

              Text(
                'Academic Tools',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                'Review your academic record, track degree progress, '
                'and plan what comes next.',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.68),
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 18),

              _buildToolGrid(context),

              const SizedBox(height: 36),

              Center(
                child: Column(
                  children: [
                    Container(
                      width: 45,
                      height: 4,
                      decoration: BoxDecoration(
                        color: benedictGold,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Benedict College',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Academic Planning • Computer Science',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 26,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            benedictDarkPurple,
            benedictPurple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color:
                benedictPurple.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(24),
                  ),
                  child: Image.asset(
                    'assets/images/benedict_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Tiger Path Advisor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Your academic path, all in one place.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.78,
                    ),
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 20),

                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  alignment: WrapAlignment.center,
                  children: [
                    _heroBadge(
                      Icons.school_outlined,
                      '${testStudent.major} B.S.',
                    ),
                    _heroBadge(
                      Icons.badge_outlined,
                      testStudent.classification,
                    ),
                    _heroBadge(
                      Icons.menu_book_outlined,
                      'Catalog ${testStudent.catalogYear}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          Positioned(
            top: 0,
            right: 0,
            child: PopupMenuButton<AppThemeChoice>(
              initialValue: themeChoice,
              tooltip: 'Change theme',
              onSelected: onThemeChanged,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: AppThemeChoice.benedict,
                  child: Row(
                    children: [
                      Icon(Icons.school_outlined),
                      SizedBox(width: 10),
                      Text('Benedict'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: AppThemeChoice.light,
                  child: Row(
                    children: [
                      Icon(Icons.light_mode_outlined),
                      SizedBox(width: 10),
                      Text('Light'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: AppThemeChoice.dark,
                  child: Row(
                    children: [
                      Icon(Icons.dark_mode_outlined),
                      SizedBox(width: 10),
                      Text('Dark'),
                    ],
                  ),
                ),
              ],
              child: Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.13,
                  ),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.palette_outlined,
                  color: benedictGold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(
    IconData icon,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: benedictGold,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicSnapshot(
    BuildContext context, {
    required double progress,
    required double projectedProgress,
    required double projectedCredits,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights_outlined,
                  color: colors.primary,
                ),
                const SizedBox(width: 9),
                Text(
                  'Academic Snapshot',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth < 620;

                if (compact) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _snapshotItem(
                              context,
                              '${testStudent.earnedCredits.toInt()}',
                              'Earned Credits',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _snapshotItem(
                              context,
                              testStudent.gpa
                                  .toStringAsFixed(2),
                              'GPA',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _snapshotItem(
                              context,
                              '${testStudent.inProgressCredits.toInt()}',
                              'In Progress',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _snapshotItem(
                              context,
                              '${(progress * 100).toStringAsFixed(1)}%',
                              'Degree Complete',
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _snapshotItem(
                        context,
                        '${testStudent.earnedCredits.toInt()}',
                        'Earned Credits',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _snapshotItem(
                        context,
                        '${testStudent.inProgressCredits.toInt()}',
                        'In Progress',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _snapshotItem(
                        context,
                        testStudent.gpa
                            .toStringAsFixed(2),
                        'Cumulative GPA',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _snapshotItem(
                        context,
                        '${(progress * 100).toStringAsFixed(1)}%',
                        'Degree Complete',
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 22),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Graduation Progress',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${testStudent.earnedCredits.toInt()} / '
                  '${testStudent.requiredCredits.toInt()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor:
                    colors.primary.withValues(
                  alpha: 0.12,
                ),
                valueColor:
                    AlwaysStoppedAnimation<Color>(
                  colors.primary,
                ),
              ),
            ),

            const SizedBox(height: 13),

            Row(
              children: [
                Icon(
                  Icons.trending_up,
                  size: 18,
                  color: colors.primary,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Projected after current semester: '
                    '${projectedCredits.toInt()} / '
                    '${testStudent.requiredCredits.toInt()} '
                    '(${(projectedProgress * 100).toStringAsFixed(1)}%)',
                    style: TextStyle(
                      color: colors.onSurface
                          .withValues(alpha: 0.65),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _snapshotItem(
    BuildContext context,
    String value,
    String label,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: colors.primary.withValues(
          alpha: 0.07,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: colors.primary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface.withValues(
                alpha: 0.65,
              ),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolGrid(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns =
            constraints.maxWidth >= 720;

        final width = twoColumns
            ? (constraints.maxWidth - 16) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: width,
              child: AdvisorToolCard(
                icon: Icons.description_outlined,
                title: 'Transcript',
                subtitle:
                    'Review your academic history and current coursework.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const TranscriptScreen(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: width,
              child: AdvisorToolCard(
                icon: Icons.school_outlined,
                title: 'Degree Progress',
                subtitle:
                    'Track completed, in-progress, and remaining requirements.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const DegreeProgressScreen(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: width,
              child: AdvisorToolCard(
                icon: Icons.auto_awesome,
                title: 'Course Recommendations',
                subtitle:
                    'See what you need, what you can take, and what is recommended next.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const CourseRecommendationsScreen(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: width,
              child: AdvisorToolCard(
                icon: Icons.calendar_month_outlined,
                title: 'Schedule Builder',
                subtitle:
                    'Build a semester plan around your academic preferences.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const SchedulePreferencesScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class AdvisorToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const AdvisorToolCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 130,
          ),
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.onSurface.withValues(
                alpha: 0.10,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: colors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.onSurface
                            .withValues(alpha: 0.65),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color:
                      Theme.of(context).brightness ==
                              Brightness.dark
                          ? Colors.black
                          : benedictGold,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}