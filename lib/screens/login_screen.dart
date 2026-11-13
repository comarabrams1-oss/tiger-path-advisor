import 'dart:async';

import 'package:flutter/material.dart';

import '../services/mock_auth_service.dart';
import '../data/test_student.dart';
import '../themes/app_theme.dart';

class LoginScreen extends StatefulWidget {
  final FutureOr<void> Function(MockStudentSession) onSignedIn;
  final MockAuthService? auth;
  const LoginScreen({super.key, required this.onSignedIn, this.auth});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
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
        _username.text,
        remember: _remember,
      );
      if (mounted) await widget.onSignedIn(session);
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
    _username.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppThemes.build(AppThemePreset.benedict),
    child: Builder(
      builder: (context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1060),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 800;
                    final form = _buildForm(context);
                    if (!wide) {
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBrand(context, wide: false),
                            const SizedBox(height: 28),
                            form,
                          ],
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _buildBrand(context, wide: true),
                        ),
                        const SizedBox(width: 56),
                        Expanded(flex: 8, child: form),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildBrand(BuildContext context, {required bool wide}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: wide
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/benedict_logo.png',
              width: wide ? 48 : 36,
              height: wide ? 48 : 36,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Benedict College',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Tiger Path Advisor',
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: AppThemes.pageTitle(context, size: wide ? 48 : 34),
        ),
        if (wide) ...[
          const SizedBox(height: 22),
          AspectRatio(
            aspectRatio: 1.5,
            child: Image.asset(
              'assets/images/benedict_campus.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topRight,
              semanticLabel: 'Tiger statue on the Benedict College campus',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Benedict College, Columbia, SC. Photo by 2C2K Photography (CC BY 4.0).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text('Sign in', style: theme.textTheme.headlineSmall)),
          const SizedBox(height: 14),
          TextFormField(
            controller: _username,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            onFieldSubmitted: (_) => _signIn(),
            decoration: InputDecoration(
              labelText: 'Student username',
              hintText: 'first.last',
              suffixIcon: Align(
                widthFactor: 1,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    '@${MockAuthService.studentDomain}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            validator: (value) =>
                MockAuthService.isStudentEmail(
                  MockAuthService.emailForSignIn(value ?? ''),
                )
                ? null
                : 'Enter your Benedict student username.',
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _remember,
            onChanged: _busy
                ? null
                : (value) => setState(() => _remember = value ?? false),
            title: const Text('Keep me signed in on this browser'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: TextStyle(color: colors.error)),
            ),
          Center(
            child: FilledButton(
              onPressed: _busy ? null : _signIn,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Continue to Tiger Path',
                      textAlign: TextAlign.center,
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Demo sign-in uses sample records. Drafts and chats are saved on this device.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Text('Try a demo profile', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final entry in {
            mockStudentEmail: fictionalStudent,
            ...additionalStudentScenarios,
          }.entries) ...[
            const Divider(height: 1),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: colors.onSurface,
                  padding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 2,
                  ),
                  minimumSize: const Size(0, 48),
                  shape: const RoundedRectangleBorder(),
                ),
                onPressed: _busy
                    ? null
                    : () {
                        _username.text = entry.key.split('@').first;
                        _signIn();
                      },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.value.name.replaceFirst(' (Demo)', '')),
                          Text(
                            '${entry.value.classification} · ${entry.value.major}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.arrow_forward, size: 18, color: colors.primary),
                  ],
                ),
              ),
            ),
          ],
          const Divider(height: 1),
        ],
      ),
    );
  }
}
