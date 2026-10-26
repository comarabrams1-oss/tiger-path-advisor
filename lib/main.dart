import 'package:flutter/material.dart';

import 'data/test_student.dart';
import 'screens/course_recommendations_screen.dart';
import 'screens/degree_progress_screen.dart';
import 'screens/schedule_preferences_screen.dart';
import 'screens/ai_advisor_screen.dart';
import 'screens/theme_settings_screen.dart';
import 'services/theme_service.dart';
import 'services/advisor_app_actions.dart';
import 'services/mock_auth_service.dart';
import 'services/advisor_history_service.dart';
import 'screens/login_screen.dart';
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
      selectDemoStudent(session?.email);

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

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    selectDemoStudent(null);
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
        settings: RouteSettings(name: screen.runtimeType.toString()),
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
              onSignedIn: (session) {
                selectDemoStudent(session.email);
                setState(() => _session = session);
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
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            children: [
              if (MockSessionScope.maybeOf(context)?.session != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle_outlined, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          MockSessionScope.maybeOf(context)!.session!.email,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            await MockSessionScope.maybeOf(context)!
                                .onSignOut();
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not sign out. Please retry.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              if (AppDesignTokens.of(context).design == AppDesign.sharp)
                _compactHeader(context)
              else
                _buildHero(context),
              const SizedBox(height: 22),
              _compactSummary(context),
              const SizedBox(height: 28),
              const AcademicWorkspace(),
              const SizedBox(height: 24),
              Text(
                'Planning draft · verify registration and approvals with your academic advisor.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final design = AppDesignTokens.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;
    final heading = Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  design.design == AppDesign.sharp ? 4 : 12,
                ),
              ),
              child: Image.asset(
                'assets/images/benedict_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'BENEDICT COLLEGE',
                style: TextStyle(
                  color: colors.onPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Open Theme Studio',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'ThemeSettingsScreen'),
                  builder: (_) => ThemeSettingsScreen(
                    currentPreset: currentPreset,
                    currentCustomTheme: currentCustomTheme,
                    onThemeChanged: onThemeChanged,
                  ),
                ),
              ),
              icon: Icon(Icons.tune, color: colors.onPrimary),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Tiger Path Advisor',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: colors.onPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Fall 2026 overview · Spring 2027 planning',
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: colors.onPrimary.withValues(alpha: .8),
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          alignment: compact ? WrapAlignment.center : WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          children: [
            _heroBadge(
              context,
              Icons.school_outlined,
              '${activeStudent.major} B.S.',
            ),
            _heroBadge(
              context,
              Icons.badge_outlined,
              activeStudent.classification,
            ),
            _heroBadge(
              context,
              Icons.menu_book_outlined,
              'Catalog ${activeStudent.catalogYear}',
            ),
          ],
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colors.secondary,
            foregroundColor: colors.onSecondary,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'SchedulePreferencesScreen'),
              builder: (_) => const SchedulePreferencesScreen(),
            ),
          ),
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: const Text('Plan Spring 2027'),
        ),
      ],
    );
    return Container(
      padding: EdgeInsets.all(design.design == AppDesign.soft ? 32 : 26),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(design.radius + 8),
        border: design.design == AppDesign.sharp
            ? Border.all(color: colors.onSurface, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: .15),
            blurRadius: design.design == AppDesign.sharp ? 0 : 28,
            offset: Offset(
              design.design == AppDesign.sharp ? 5 : 0,
              design.design == AppDesign.sharp ? 5 : 10,
            ),
          ),
        ],
      ),
      child: heading,
    );
  }

  Widget _heroBadge(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onPrimary),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactHeader(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Image.asset(
          'assets/images/benedict_logo.png',
          fit: BoxFit.contain,
          semanticLabel: 'Benedict College logo',
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiger Path Advisor',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              '${activeStudent.major} · ${activeStudent.classification} · Catalog ${activeStudent.catalogYear}',
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Open Theme Studio',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'ThemeSettingsScreen'),
            builder: (_) => ThemeSettingsScreen(
              currentPreset: currentPreset,
              currentCustomTheme: currentCustomTheme,
              onThemeChanged: onThemeChanged,
            ),
          ),
        ),
        icon: const Icon(Icons.tune),
      ),
    ],
  );

  Widget _compactSummary(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final remaining =
        (activeStudent.requiredCredits -
                activeStudent.earnedCredits -
                activeStudent.inProgressCredits)
            .clamp(0, activeStudent.requiredCredits)
            .toInt();
    final values = [
      ('${activeStudent.earnedCredits.toInt()}', 'Credits earned'),
      ('${activeStudent.inProgressCredits.toInt()}', 'In progress'),
      ('$remaining', 'Left after this term'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Row(
          children: [
            for (var index = 0; index < values.length; index++) ...[
              if (index > 0)
                Container(width: 1, height: 42, color: colors.outlineVariant),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      values[index].$1,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        color: index == 1 ? colors.secondary : colors.primary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      values[index].$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
