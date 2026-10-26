import 'package:flutter/material.dart';

import '../services/mock_auth_service.dart';
import '../data/test_student.dart';
import '../themes/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final ValueChanged<MockStudentSession> onSignedIn;
  final MockAuthService? auth;
  const LoginScreen({super.key, required this.onSignedIn, this.auth});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _remember = true;
  bool _busy = false;
  String? _error;
  Future<void> _signIn() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await (widget.auth ?? MockAuthService()).signIn(
        _email.text,
        remember: _remember,
      );
      if (mounted) widget.onSignedIn(session);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not open your demo session. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppThemes.build(AppThemePreset.benedict),
    child: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: LayoutBuilder(
                    builder: (context, size) {
                      final wide = size.maxWidth >= 760;
                      final brand = Container(
                        padding: EdgeInsets.all(wide ? 38 : 26),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: wide ? 74 : 52,
                              height: wide ? 74 : 52,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Image.asset(
                                'assets/images/benedict_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            SizedBox(height: wide ? 26 : 16),
                            Text(
                              'TIGER PATH ADVISOR',
                              style: TextStyle(
                                color: colors.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.6,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Student sign-in',
                              style: TextStyle(
                                color: colors.onPrimary,
                                fontSize: wide ? 36 : 28,
                                fontWeight: FontWeight.w800,
                                height: 1.18,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Course planning and degree progress.',
                              style: TextStyle(
                                color: colors.onPrimary.withValues(alpha: 0.8),
                                height: 1.6,
                              ),
                            ),
                            SizedBox(height: wide ? 32 : 18),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: colors.onPrimary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'BENEDICT COLLEGE · STUDENT EXPERIENCE',
                                style: TextStyle(
                                  color: colors.onPrimary,
                                  fontSize: 9,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      final form = Padding(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 44 : 4,
                          wide ? 26 : 30,
                          wide ? 12 : 4,
                          20,
                        ),
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Chip(
                                avatar: Icon(
                                  Icons.science_outlined,
                                  size: 16,
                                  color: colors.primary,
                                ),
                                label: const Text('Demo sign-in'),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Sign in',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Continue with your Benedict student email.',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 30),
                              TextFormField(
                                controller: _email,
                                enabled: !_busy,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                autocorrect: false,
                                enableSuggestions: false,
                                onFieldSubmitted: (_) => _signIn(),
                                decoration: const InputDecoration(
                                  labelText: 'Student email',
                                  hintText: 'your.name@my.benedict.edu',
                                  prefixIcon: Icon(Icons.alternate_email),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) =>
                                    MockAuthService.isStudentEmail(value ?? '')
                                    ? null
                                    : 'Use your @my.benedict.edu student email.',
                              ),
                              const SizedBox(height: 12),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: _remember,
                                onChanged: _busy
                                    ? null
                                    : (value) => setState(
                                        () => _remember = value ?? false,
                                      ),
                                title: const Text(
                                  'Keep me signed in on this browser',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(color: colors.error),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _busy ? null : _signIn,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.all(18),
                                  ),
                                  child: _busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Continue to Tiger Path'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.person_outline),
                                  label: const Text(
                                    'Use fictional test student',
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () {
                                          _email.text = mockStudentEmail;
                                          _signIn();
                                        },
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.engineering_outlined),
                                  label: const Text(
                                    'Use engineering test student',
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () {
                                          _email.text = engineeringStudentEmail;
                                          _signIn();
                                        },
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Alex Morgan · Computer Engineering · Freshman · 16 current credits\nTest email: demo.engineering@my.benedict.edu',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Jordan Taylor · Computer Science · Freshman · 16 current credits\nTest email: demo.student@my.benedict.edu',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 22),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  'This is a mock login, not Tiger Portal. No password is needed, and email ownership is not verified. Each fictional test student has a separate sample academic record. Other student emails open the original sample record. Chats are saved separately for each email on this browser.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.6,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      return wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: brand),
                                Expanded(child: form),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [brand, form],
                            );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
