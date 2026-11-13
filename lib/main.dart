import 'package:flutter/material.dart';

import 'data/test_student.dart';
import 'screens/course_recommendations_screen.dart';
import 'screens/degree_progress_screen.dart';
import 'screens/schedule_preferences_screen.dart';
import 'screens/generated_schedule_screen.dart';
import 'screens/ai_advisor_screen.dart';
import 'screens/readiness_screen.dart';
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
      'ReadinessScreen': 6,
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
    final profile = session?.profileId ?? 'demo-cs-2024';
    PreferencesService.useProfile(profile);
    if (session == null) return;
    await PreferencesService.restore();
    if (mounted && PreferencesService.profileId == profile) {
      await ScheduleDraftService.restore();
    }
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
      6 => ReadinessScreen(profileId: _session?.profileId ?? 'demo-cs-2024'),
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
            6 => 'ReadinessScreen',
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
          : HomeScreen(key: ValueKey(_session!.email)),
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
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = MockSessionScope.maybeOf(context);
    final design = AppDesignTokens.of(context).design;
    final hasWideNavigation = WorkspaceShell.usesWideNavigation(
      design,
      MediaQuery.sizeOf(context).width,
    );
    final showBrand =
        session?.session == null ||
        !hasWideNavigation ||
        design == AppDesign.sharp;
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
                _buildHeader(context, showBrand: showBrand),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final progress = _buildCreditProgress(context);
                    final planning = _buildPlanning(context);
                    if (constraints.maxWidth >= 740) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: planning),
                          const SizedBox(width: 32),
                          Expanded(flex: 5, child: progress),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        planning,
                        const SizedBox(height: 24),
                        progress,
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

  Widget _buildHeader(BuildContext context, {required bool showBrand}) {
    final theme = Theme.of(context);
    final title = showBrand ? 'Tiger Path Advisor' : activeStudent.major;
    final details = showBrand
        ? '${activeStudent.major} ${activeStudent.degreeLabel} · ${activeStudent.classification}'
        : '${activeStudent.degreeLabel} · ${activeStudent.classification}';
    return Column(
      children: [
        if (showBrand) ...[
          Image.asset(
            'assets/images/benedict_logo.png',
            width: 38,
            height: 42,
            fit: BoxFit.contain,
            semanticLabel: 'Benedict College logo',
          ),
          const SizedBox(height: 8),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppThemes.pageTitle(context),
        ),
        const SizedBox(height: 4),
        Text(
          details,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Degree progress',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 9),
        Text.rich(
          TextSpan(
            text: _credits(student.earnedCredits),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
            children: [
              TextSpan(
                text: ' of ${_credits(student.requiredCredits)} credits earned',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        ExcludeSemantics(
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_credits(student.inProgressCredits)} in progress · ${_credits(projectedRemaining)} left if passed',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            TextButton(
              child: const Text('View degree audit'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: 'DegreeProgressScreen'),
                  builder: (_) => const DegreeProgressScreen(),
                ),
              ),
            ),
            TextButton(
              child: const Text('Programs of study'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: 'ProgramLibraryScreen'),
                  builder: (_) => const ProgramLibraryScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanning(BuildContext context) => ValueListenableBuilder(
    valueListenable: ScheduleDraftService.revision,
    builder: (context, _, _) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final draft = ScheduleDraftService.current;
      final unresolved = draft?.schedule.unscheduled.length ?? 0;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.primary, width: 2),
            bottom: BorderSide(color: colors.outlineVariant),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Spring 2027 schedule',
                textAlign: TextAlign.center,
                style: AppThemes.pageTitle(context, size: 25),
              ),
              if (draft != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${draft.schedule.scheduled.length} courses · ${_credits(draft.schedule.scheduledCredits)} of ${draft.preferences.maxCredits} credits'
                  '${unresolved > 0 ? ' · $unresolved unresolved' : ''}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: Text(
                      draft == null ? 'Build schedule' : 'Continue schedule',
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
                      child: const Text('Schedule preferences'),
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
