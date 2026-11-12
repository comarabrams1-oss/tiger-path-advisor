import 'package:flutter/material.dart';

import 'data/test_student.dart';
import 'screens/course_recommendations_screen.dart';
import 'screens/degree_progress_screen.dart';
import 'screens/schedule_preferences_screen.dart';
import 'screens/generated_schedule_screen.dart';
import 'screens/ai_advisor_screen.dart';
import 'screens/theme_settings_screen.dart';
import 'services/theme_service.dart';
import 'services/preferences_service.dart';
import 'services/schedule_draft_service.dart';
import 'services/advisor_app_actions.dart';
import 'services/mock_auth_service.dart';
import 'services/advisor_history_service.dart';
import 'screens/login_screen.dart';
import 'screens/program_library_screen.dart';
import 'themes/app_theme.dart';
import 'widgets/academic_workspace.dart';
import 'widgets/workspace_shell.dart';

void main() {
  runApp(const TigerPathAdvisorApp());
}

class TigerPathAdvisorApp extends StatefulWidget {
  const TigerPathAdvisorApp({super.key});
  @override
  State<TigerPathAdvisorApp> createState() => _TigerPathAdvisorAppState();
}

class _TigerPathAdvisorAppState extends State<TigerPathAdvisorApp> {
  AppThemePreset _themePreset = AppThemePreset.benedict;
  CustomThemeSettings _customTheme = const CustomThemeSettings();
  bool _loadingTheme = true;
  final _auth = MockAuthService();
  final _navigatorKey = GlobalKey<NavigatorState>();
  MockStudentSession? _session;
  int _navIndex = 0;
  late final _routeObserver = _WorkspaceRouteObserver((route) {
    const names = {
      'CourseRecommendationsScreen': 1,
      'TranscriptScreen': 1,
      'DegreeProgressScreen': 2,
      'SchedulePreferencesScreen': 3,
      'GeneratedScheduleScreen': 3,
      'SemesterPlanScreen': 3,
      'AiAdvisorScreen': 4,
      'ThemeSettingsScreen': 5,
    };
    final index =
        names[route?.settings.name] ?? (route?.isFirst == true ? 0 : null);
    if (index != null && index != _navIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _navIndex = index);
      });
    }
  });

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final settings = await ThemeService.load();
      final session = await _auth.restore();
      if (!mounted) return;
      await _loadProfile(session);

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _themePreset = settings.preset;
        _customTheme = settings.customTheme;
        _loadingTheme = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingTheme = false;
      });
    }
  }

  Future<void> _loadProfile(MockStudentSession? session) async {
    selectDemoStudent(session?.email);
    PreferencesService.useProfile(session?.profileId ?? 'demo-cs-2024');
    if (session != null) await ScheduleDraftService.restore();
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    selectDemoStudent(null);
    PreferencesService.useProfile('demo-cs-2024');
    setState(() => _session = null);
  }

  void _applyTheme(ThemeSettings settings) {
    setState(() {
      _themePreset = settings.preset;
      _customTheme = settings.customTheme;
    });
  }

  void _navigate(int index) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    if (index == 0) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }
    final Widget screen = switch (index) {
      1 => const CourseRecommendationsScreen(),
      2 => const DegreeProgressScreen(),
      3 => const SchedulePreferencesScreen(),
      4 => AiAdvisorScreen(
        history: AdvisorHistoryService(
          profileId: _session?.profileId ?? 'demo-cs-2024',
        ),
      ),
      _ => ThemeSettingsScreen(
        currentPreset: _themePreset,
        currentCustomTheme: _customTheme,
        onThemeChanged: _applyTheme,
      ),
    };
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    navigator.pushAndRemoveUntil(
      PageRouteBuilder(
        settings: RouteSettings(
          name: switch (index) {
            1 => 'CourseRecommendationsScreen',
            2 => 'DegreeProgressScreen',
            3 => 'SchedulePreferencesScreen',
            4 => 'AiAdvisorScreen',
            _ => 'ThemeSettingsScreen',
          },
        ),
        transitionDuration: Duration(milliseconds: reduceMotion ? 0 : 260),
        reverseTransitionDuration: Duration(
          milliseconds: reduceMotion ? 0 : 180,
        ),
        pageBuilder: (_, animation, secondaryAnimation) => screen,
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              child: child,
            ),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemes.build(_themePreset, custom: _customTheme);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tiger Path Advisor',
      navigatorKey: _navigatorKey,
      navigatorObservers: [_routeObserver],
      builder: (context, child) => MockSessionScope(
        session: _session,
        onSignOut: _signOut,
        child: AdvisorAppActions(
          onThemeChanged: _applyTheme,
          child: Overlay.wrap(
            child: _session == null
                ? child!
                : WorkspaceShell(
                    onNavigate: _navigate,
                    selectedIndex: _navIndex,
                    child: child!,
                  ),
          ),
        ),
      ),
      theme: theme,
      home: _loadingTheme
          ? const _ThemeLoadingScreen()
          : _session == null
          ? LoginScreen(
              onSignedIn: (session) async {
                await _loadProfile(session);
                if (mounted) setState(() => _session = session);
              },
            )
          : HomeScreen(
              key: ValueKey(_session!.email),
              currentPreset: _themePreset,
              currentCustomTheme: _customTheme,
              onThemeChanged: _applyTheme,
            ),
    );
  }
}

class _ThemeLoadingScreen extends StatelessWidget {
  const _ThemeLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class HomeScreen extends StatelessWidget {
  final AppThemePreset currentPreset;
  final CustomThemeSettings currentCustomTheme;
  final ValueChanged<ThemeSettings> onThemeChanged;

  const HomeScreen({
    super.key,
    required this.currentPreset,
    required this.currentCustomTheme,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final session = MockSessionScope.maybeOf(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1140),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                if (session?.session case final account?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            account.email,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await session!.onSignOut();
                            } catch (_) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not sign out. Please retry.',
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Sign out'),
                        ),
                      ],
                    ),
                  ),
                _buildHeader(context),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final progress = _buildCreditProgress(context);
                    final planning = _buildPlanningCard(context);
                    if (constraints.maxWidth >= 740) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: progress),
                          const SizedBox(width: 16),
                          Expanded(flex: 5, child: planning),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        progress,
                        const SizedBox(height: 12),
                        planning,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                const AcademicWorkspace(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.primary.withValues(alpha: .08),
          colors.surface,
        ),
        borderRadius: BorderRadius.circular(AppDesignTokens.of(context).radius),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              'assets/images/benedict_logo.png',
              fit: BoxFit.contain,
              semanticLabel: 'Benedict College logo',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Benedict College', style: theme.textTheme.labelMedium),
                const SizedBox(height: 3),
                Text(
                  'Tiger Path Advisor',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${activeStudent.major} ${activeStudent.degreeLabel} · ${activeStudent.classification}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open Theme Studio',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'ThemeSettingsScreen'),
                builder: (_) => ThemeSettingsScreen(
                  currentPreset: currentPreset,
                  currentCustomTheme: currentCustomTheme,
                  onThemeChanged: onThemeChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditProgress(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final student = activeStudent;
    final progress = student.requiredCredits > 0
        ? (student.earnedCredits / student.requiredCredits).clamp(0.0, 1.0)
        : 0.0;
    final projectedRemaining =
        (student.remainingCredits - student.inProgressCredits)
            .clamp(0.0, student.requiredCredits)
            .toDouble();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Credit progress',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_credits(student.earnedCredits)} of ${_credits(student.requiredCredits)} credits earned',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                _creditMetric(
                  context,
                  student.inProgressCredits,
                  'In progress',
                ),
                _creditMetric(
                  context,
                  projectedRemaining,
                  'Remaining if current courses are passed',
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.school_outlined, size: 18),
                  label: const Text('View degree audit'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(
                        name: 'DegreeProgressScreen',
                      ),
                      builder: (_) => const DegreeProgressScreen(),
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Programs of study'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(
                        name: 'ProgramLibraryScreen',
                      ),
                      builder: (_) => const ProgramLibraryScreen(),
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

  Widget _creditMetric(BuildContext context, double credits, String label) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_credits(credits), style: theme.textTheme.titleLarge),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildPlanningCard(BuildContext context) => ValueListenableBuilder(
    valueListenable: ScheduleDraftService.revision,
    builder: (context, _, _) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final draft = ScheduleDraftService.current;
      final unresolved = draft?.schedule.unscheduled.length ?? 0;
      return Card(
        margin: EdgeInsets.zero,
        color: Color.alphaBlend(
          colors.primary.withValues(alpha: .08),
          colors.surface,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Spring 2027 schedule',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                draft == null
                    ? 'Choose your preferences and build a draft from available sections.'
                    : '${draft.schedule.scheduled.length} courses · ${_credits(draft.schedule.scheduledCredits)} credits'
                          '${unresolved > 0 ? ' · $unresolved unresolved' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    icon: Icon(
                      draft == null
                          ? Icons.calendar_month_outlined
                          : Icons.arrow_forward,
                    ),
                    label: Text(
                      draft == null ? 'Plan Spring 2027' : 'Continue schedule',
                    ),
                    onPressed: () {
                      if (draft == null) {
                        _openPlanner(context);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            settings: const RouteSettings(
                              name: 'GeneratedScheduleScreen',
                            ),
                            builder: (_) => GeneratedScheduleScreen(
                              plan: draft.plan,
                              draft: draft,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  if (draft != null)
                    TextButton(
                      onPressed: () => _openPlanner(context),
                      child: const Text('New plan'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  void _openPlanner(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'SchedulePreferencesScreen'),
      builder: (_) => const SchedulePreferencesScreen(),
    ),
  );

  String _credits(double value) => value == value.roundToDouble()
      ? '${value.toInt()}'
      : value.toStringAsFixed(1);
}

class _WorkspaceRouteObserver extends NavigatorObserver {
  final ValueChanged<Route<dynamic>?> onChanged;
  _WorkspaceRouteObserver(this.onChanged);
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onChanged(newRoute);
}
