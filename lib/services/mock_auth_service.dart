import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockStudentSession {
  final String email;
  const MockStudentSession(this.email);
  String get profileId => 'email_${base64Url.encode(utf8.encode(email))}';
}

/// Demo identity only: no password, email verification, or server authentication.
class MockAuthService {
  static const _key = 'mock_student_session_v1';
  static String normalize(String email) => email.trim().toLowerCase();
  static bool isStudentEmail(String email) {
    final value = normalize(email);
    if (value.length > 254) return false;
    final parts = value.split('@');
    return parts.length == 2 &&
        parts.last == 'my.benedict.edu' &&
        parts.first.length <= 64 &&
        !parts.first.contains('..') &&
        RegExp(r'^[a-z0-9](?:[a-z0-9._+-]*[a-z0-9])?$').hasMatch(parts.first);
  }

  Future<MockStudentSession?> restore() async {
    final email = (await SharedPreferences.getInstance()).getString(_key);
    return email != null && isStudentEmail(email)
        ? MockStudentSession(normalize(email))
        : null;
  }

  Future<MockStudentSession> signIn(
    String email, {
    required bool remember,
  }) async {
    if (!isStudentEmail(email)) {
      throw const FormatException('Use your @my.benedict.edu student email.');
    }
    final preferences = await SharedPreferences.getInstance();
    final normalized = normalize(email);
    final ok = remember
        ? await preferences.setString(_key, normalized)
        : await preferences.remove(_key);
    if (!ok) throw StateError('Could not save the demo session.');
    return MockStudentSession(normalized);
  }

  Future<void> signOut() async {
    if (!await (await SharedPreferences.getInstance()).remove(_key)) {
      throw StateError('Could not sign out.');
    }
  }
}

class MockSessionScope extends InheritedWidget {
  final MockStudentSession? session;
  final Future<void> Function() onSignOut;
  const MockSessionScope({
    super.key,
    required this.session,
    required this.onSignOut,
    required super.child,
  });
  static MockSessionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MockSessionScope>();
  @override
  bool updateShouldNotify(MockSessionScope oldWidget) =>
      oldWidget.session?.email != session?.email;
}
