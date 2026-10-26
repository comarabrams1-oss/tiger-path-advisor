import '../widgets/advisor_response.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/program_registry.dart';
import '../data/test_student.dart';
import '../models/student.dart';
import '../services/advisor_context_service.dart';
import '../services/advisor_app_actions.dart';
import '../services/advisor_history_service.dart';
import '../services/ai_advisor_service.dart';
import '../services/course_section_repository.dart';
import '../services/theme_service.dart';
import '../themes/app_theme.dart';
import 'transcript_screen.dart';
import 'degree_progress_screen.dart';
import 'course_recommendations_screen.dart';
import 'schedule_preferences_screen.dart';
import 'theme_settings_screen.dart';

class AiAdvisorScreen extends StatefulWidget {
  final AiAdvisorService? service;
  final Student student;
  final AdvisorHistoryService history;
  AiAdvisorScreen({
    super.key,
    this.service,
    Student? student,
    this.history = const AdvisorHistoryService(),
  }) : student = student ?? activeStudent;
  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <AdvisorMessage>[];
  final _conversations = <AdvisorConversation>[];
  late final _service = widget.service ?? AiAdvisorService();
  String _conversationId = DateTime.now().microsecondsSinceEpoch.toString();
  Map<String, Object?>? _context;
  Map<String, String> _lastStatuses = {};
  List<Map<String, String>> _changes = [];
  String? _error;
  String? _storageError;
  bool _busy = false;
  bool _loading = true;
  bool _saved = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AiAdvisorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.student != widget.student) {
      _refreshContext();
    }
  }

  Future<Map<String, Object?>> _buildContext([String question = '']) async {
    final term = RegExp(r'fall\s*2026', caseSensitive: false).hasMatch(question)
        ? CourseSectionRepository.fall2026Term
        : CourseSectionRepository.spring2027Term;
    final sections = await CourseSectionRepository.loadForTerm(term);
    final context = AdvisorContextService().build(
      student: widget.student,
      program: programFor(widget.student),
      catalog: catalogFor(widget.student),
      sections: sections,
      term: term,
      question: question,
    );
    final theme = await ThemeService.load();
    context['currentTheme'] = theme.preset.name;
    context['themeSettings'] = {
      'darkMode': theme.preset == AppThemePreset.custom
          ? theme.customTheme.darkMode
          : [
              AppThemePreset.dark,
              AppThemePreset.midnightPurple,
              AppThemePreset.goldBlack,
              AppThemePreset.highContrast,
            ].contains(theme.preset),
      'primaryHex':
          '#${theme.customTheme.primaryColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      'accentHex':
          '#${theme.customTheme.accentColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
    };
    final current = _statuses(context);
    _changes = [
      for (final item in (context['requirements'] as List))
        if (_lastStatuses.containsKey(item['id']) &&
            _lastStatuses[item['id']] != current[item['id']])
          {
            'requirement': item['title'] as String,
            'previous': _lastStatuses[item['id']]!,
            'current': current[item['id']]!,
          },
    ];
    context['progressChanges'] = _changes;
    return context;
  }

  Map<String, String> _statuses(Map<String, Object?> context) => {
    for (final item in context['requirements'] as List)
      item['id'] as String: item['status'] as String,
  };
  Future<void> _load() async {
    try {
      final history = await widget.history.load();
      if (!mounted) return;
      _conversations.addAll(history);
      if (history.isNotEmpty) {
        _conversationId = history.first.id;
        _messages.addAll(history.first.messages);
        _lastStatuses = history.first.requirementStatuses;
        _saved = true;
      }
    } catch (_) {
      _storageError = 'Saved chats could not be read. New messages will not replace them until you clear saved chats.';
    }
    await _refreshContext();
  }

  Future<void> _refreshContext() async {
    try {
      final context = await _buildContext();
      if (mounted) {
        setState(() {
          _context = context;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not refresh course data. Please reopen the advisor.';
        });
      }
    }
  }

  Future<void> _persist() async {
    if (_context == null || _storageError != null) return;
    final title = _messages
        .firstWhere(
          (m) => m.role == 'user',
          orElse: () => const AdvisorMessage('user', 'New chat'),
        )
        .text;
    final conversation = AdvisorConversation(
      id: _conversationId,
      title: title.length > 55 ? '${title.substring(0, 55)}…' : title,
      messages: List.of(_messages),
      requirementStatuses: _statuses(_context!),
    );
    final updated = [
      conversation,
      ..._conversations.where((c) => c.id != _conversationId),
    ].take(20).toList();
    try {
      await widget.history.save(updated);
      if (mounted) {
        setState(() {
          _conversations
            ..clear()
            ..addAll(updated);
          _saved = true;
          _lastStatuses = conversation.requirementStatuses;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saved = false;
          _storageError =
              'Chat could not be saved on this browser. Keep this page open.';
        });
      }
    }
  }

  Future<void> _send([String? prompt]) async {
    final text = (prompt ?? _input.text).trim();
    if (_busy || _context == null || text.isEmpty) return;
    if (text.length > 4000) {
      setState(() => _error = 'Keep your question under 4,000 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _saved = false;
    });
    try {
      // Recompute on every turn. Saved messages never become academic truth.
      final fresh = await _buildContext(text);
      if (!mounted) return;
      setState(() {
        _context = fresh;
        _messages.add(AdvisorMessage('user', text));
      });
      _input.clear();
      final recent = _messages
          .skip(_messages.length > 11 ? _messages.length - 11 : 0)
          .map(
            (m) => AdvisorMessage(
              m.role,
              m.text.length > 4000 ? m.text.substring(0, 4000) : m.text,
            ),
          )
          .toList();
      final answer = await _service.respond(recent, fresh);
      if (!mounted) return;
      setState(() {
        _messages.add(AdvisorMessage('assistant', answer.text, answer.actions));
        if (_messages.length > 80) _messages.removeRange(0, 2);
      });
      await _persist();
    } catch (error) {
      if (mounted) {
        setState(() {
          if (_messages.isNotEmpty && _messages.last.role == 'user') {
            _messages.removeLast();
          }
          _input.text = text;
          _error = error is AdvisorException
              ? error.message
              : 'Could not refresh your plan. Please retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _toBottom();
      }
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });
  void _newChat() => setState(() {
    _conversationId = DateTime.now().microsecondsSinceEpoch.toString();
    _messages.clear();
    _input.clear();
    _error = null;
    _saved = false;
    _changes = [];
    _lastStatuses = _context == null ? {} : _statuses(_context!);
  });
  Future<void> _showHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Your conversations',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Saved on this browser · up to 20 chats'),
            ),
            if (_conversations.isEmpty)
              const ListTile(title: Text('No saved conversations.')),
            for (final chat in _conversations)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(
                  chat.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${chat.messages.length ~/ 2} exchanges'),
                onTap: () async {
                  Navigator.pop(sheet);
                  setState(() {
                    _conversationId = chat.id;
                    _messages
                      ..clear()
                      ..addAll(chat.messages);
                    _lastStatuses = chat.requirementStatuses;
                    _saved = true;
                    _error = null;
                    _input.clear();
                  });
                  await _refreshContext();
                  _toBottom();
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Clear saved chats'),
              onTap: () async {
                Navigator.pop(sheet);
                final clear = await showDialog<bool>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: const Text('Clear saved conversations?'),
                    content: const Text(
                      'This removes chat history from this browser. Your academic record is unchanged.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const Text('Clear chats'),
                      ),
                    ],
                  ),
                );
                if (clear != true || !mounted) return;
                try {
                  await widget.history.clear();
                  if (mounted) {
                    setState(() {
                      _conversations.clear();
                      _storageError = null;
                    });
                    _newChat();
                  }
                } catch (_) {
                  if (mounted) {
                    setState(
                      () =>
                          _error = 'Could not clear saved chats. Please retry.',
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _actionLabel(AdvisorAction action) {
    if (action.type == 'customTheme') return 'Apply custom colors';
    if (action.type == 'changeTheme') {
      return 'Apply ${AppThemePreset.values.firstWhere((p) => p.name == action.target).displayName}';
    }
    return switch (action.target) {
      'transcript' => 'Open Transcript',
      'degreeProgress' => 'View Degree Progress',
      'recommendations' => 'View Needed Classes',
      'scheduleBuilder' => 'Open Schedule Builder',
      _ => 'Open Theme Studio',
    };
  }

  Future<void> _perform(AdvisorAction action) async {
    try {
      if (action.type == 'changeTheme' || action.type == 'customTheme') {
        final scope = AdvisorAppActions.maybeOf(context);
        if (scope == null) {
          setState(
            () => _error = 'Theme changes are available when opened from Home.',
          );
          return;
        }
        final current = await ThemeService.load();
        final preset = action.type == 'customTheme'
            ? AppThemePreset.custom
            : AppThemePreset.values.firstWhere((p) => p.name == action.target);
        final custom = action.type == 'customTheme'
            ? current.customTheme.copyWith(
                primaryColor: Color(
                  int.parse('FF${action.primaryHex!.substring(1)}', radix: 16),
                ),
                accentColor: Color(
                  int.parse('FF${action.accentHex!.substring(1)}', radix: 16),
                ),
                darkMode: action.darkMode!,
              )
            : current.customTheme;
        await ThemeService.save(preset: preset, customTheme: custom);
        if (!mounted) return;
        scope.onThemeChanged(
          ThemeSettings(preset: preset, customTheme: custom),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${preset.displayName} applied')),
        );
        await _refreshContext();
      } else {
        Widget page;
        switch (action.target) {
          case 'transcript':
            page = const TranscriptScreen();
          case 'degreeProgress':
            page = const DegreeProgressScreen();
          case 'recommendations':
            page = const CourseRecommendationsScreen();
          case 'scheduleBuilder':
            page = const SchedulePreferencesScreen();
          default:
            final settings = await ThemeService.load();
            if (!mounted) return;
            final scope = AdvisorAppActions.maybeOf(context);
            page = ThemeSettingsScreen(
              currentPreset: settings.preset,
              currentCustomTheme: settings.customTheme,
              onThemeChanged: (settings) => scope?.onThemeChanged(settings),
            );
        }
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            settings: RouteSettings(
              name: switch (action.target) {
                'transcript' => 'TranscriptScreen',
                'degreeProgress' => 'DegreeProgressScreen',
                'recommendations' => 'CourseRecommendationsScreen',
                'scheduleBuilder' => 'SchedulePreferencesScreen',
                _ => 'ThemeSettingsScreen',
              },
            ),
            builder: (_) => page,
          ),
        );
        if (mounted) await _refreshContext();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'That action could not be completed. Please try again.',
        );
      }
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask Tiger Path'),
        actions: [
          IconButton(
            tooltip: 'Saved chats',
            onPressed: _busy ? null : _showHistory,
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'New chat',
            onPressed: _busy ? null : _newChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, size) {
              final wide = size.maxWidth >= 1000;
              final chat = Column(
                children: [
                  if (size.maxHeight >= 420) _header(colors),
                  if (_loading) const LinearProgressIndicator(),
                  if (_storageError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _storageError!,
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        if (_changes.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: colors.tertiaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_changes.length} requirement updates since this chat. Ask “What changed in my progress?”',
                              style: TextStyle(
                                color: colors.onTertiaryContainer,
                              ),
                            ),
                          ),
                        if (_messages.isEmpty && !_loading) _welcome(colors),
                        for (final message in _messages)
                          _bubble(message, colors),
                        if (_busy)
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text('Preparing response…'),
                              ],
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _error!,
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _composer(colors),
                ],
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: chat),
                  if (wide) SizedBox(width: 280, child: _progressPanel(colors)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _header(ColorScheme colors) => Container(
    margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          colors.primaryContainer,
          Color.lerp(colors.primaryContainer, colors.primary, 0.10)!,
        ],
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.auto_awesome, color: colors.primary, size: 25),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                textAlign: TextAlign.center,
                'Academic advisor',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                textAlign: TextAlign.center,
                '${widget.student.classification} · ${widget.student.major} · Spring 2027',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                textAlign: TextAlign.center,
                _busy
                    ? 'Thinking with your latest plan'
                    : _saved
                    ? 'Conversation saved on this browser'
                    : 'Ask about courses, progress, or settings',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _welcome(ColorScheme colors) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          textAlign: TextAlign.center,
          'Ask Tiger Path',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          textAlign: TextAlign.center,
          'Get course recommendations, review degree requirements, or change app settings.',
          style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
        ),
        const SizedBox(height: 22),
        for (final item in [
          (
            Icons.route_outlined,
            'Plan my next semester',
            'What should I take in Spring 2027?',
          ),
          (
            Icons.school_outlined,
            'See what’s left',
            'What classes do I still need?',
          ),
          (Icons.palette_outlined, 'Change theme', 'I want to change my theme'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _context == null || _busy ? null : () => _send(item.$3),
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: Row(
                    children: [
                      Icon(item.$1, color: colors.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.$2,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
  Widget _bubble(AdvisorMessage message, ColorScheme colors) {
    final user = message.role == 'user';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.only(bottom: 18, left: 0, right: 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: user ? colors.primaryContainer : colors.surfaceContainerLow,
          border: Border.all(
            color: user
                ? colors.primaryContainer
                : colors.outlineVariant.withValues(alpha: 0.6),
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(user ? 22 : 5),
            bottomRight: Radius.circular(user ? 5 : 22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  user ? Icons.person_outline : Icons.auto_awesome,
                  size: 15,
                  color: user ? colors.onPrimaryContainer : colors.secondary,
                ),
                const SizedBox(width: 7),
                Text(
                  user ? 'YOU' : 'TIGER PATH',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: user ? colors.onPrimaryContainer : colors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            if (!user)
              AdvisorResponse(text: message.text)
            else
              SelectableText(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: user ? colors.onPrimaryContainer : colors.onSurface,
                ),
              ),
            for (final action in message.actions.where(
              (a) => a.type == 'customTheme',
            ))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    for (final hex in [action.primaryHex!, action.accentHex!])
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor: Color(
                            int.parse('FF${hex.substring(1)}', radix: 16),
                          ),
                        ),
                        label: Text(hex),
                      ),
                    Chip(
                      label: Text(
                        action.darkMode!
                            ? 'Dark background'
                            : 'Light background',
                      ),
                    ),
                  ],
                ),
              ),
            if (message.actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final action in message.actions)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.secondary,
                          foregroundColor: colors.onSecondary,
                        ),
                        onPressed: _busy ? null : () => _perform(action),
                        icon: Icon(
                          action.type != 'navigate'
                              ? Icons.palette_outlined
                              : Icons.arrow_forward,
                          size: 17,
                        ),
                        label: Text(_actionLabel(action)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _composer(ColorScheme colors) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      final enter =
                          event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter;
                      if (!enter ||
                          (_input.value.composing.isValid &&
                              !_input.value.composing.isCollapsed)) {
                        return KeyEventResult.ignored;
                      }
                      if (event is KeyDownEvent) {
                        if (HardwareKeyboard.instance.isShiftPressed) {
                          final value = _input.value;
                          final selection = value.selection;
                          final start = selection.isValid
                              ? selection.start
                              : value.text.length;
                          final end = selection.isValid
                              ? selection.end
                              : value.text.length;
                          if (value.text.length - (end - start) < 4000) {
                            _input.value = TextEditingValue(
                              text: value.text.replaceRange(start, end, '\n'),
                              selection: TextSelection.collapsed(
                                offset: start + 1,
                              ),
                            );
                          }
                        } else {
                          _send();
                        }
                      }
                      return KeyEventResult.handled;
                    },
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      enabled: !_busy && _context != null,
                      maxLength: 4000,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Ask about classes, progress, or the app…',
                        labelText: 'Message Tiger Path',
                        counterText: '',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: IconButton.filled(
                    tooltip: 'Send question',
                    style: IconButton.styleFrom(
                      backgroundColor: colors.secondary,
                      foregroundColor: colors.onSecondary,
                    ),
                    onPressed: _busy || _context == null ? null : () => _send(),
                    icon: const Icon(Icons.arrow_upward, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 11,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Saved here · AI guidance · confirm with your advisor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: const Text('Your chat & privacy'),
                    content: const Text(
                      'Chats are saved on this browser, including on shared devices. Use Saved chats to clear them. Questions, classification, and computed planning results are sent to Google Gemini. Your name, grades, GPA, and full transcript are excluded. Avoid entering private information.\n\nThe current profile is the app’s demo student. Progress refreshes from the app’s academic record; chat cannot change it. Confirm final plans with your academic advisor.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                ),
                child: Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _progressPanel(ColorScheme colors) {
    final student = widget.student;
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 12, 20, 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.school_outlined, color: colors.primary, size: 30),
          const SizedBox(height: 20),
          const Text(
            'Degree progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${student.classification} · ${student.degreeLabel} ${student.major}',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          Text(
            '${student.earnedCredits.toInt()} / ${student.requiredCredits.toInt()}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: colors.primary,
            ),
          ),
          const Text('credits earned', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (student.earnedCredits / student.requiredCredits).clamp(
                0,
                1,
              ),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${student.inProgressCredits.toInt()} credits in progress',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 26),
          const Divider(),
          const SizedBox(height: 10),
          Text(
            'CURRENT SOURCE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Spring 2027 offerings',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Degree checks refresh with every question. Seat availability is an imported snapshot.',
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () =>
                _perform(const AdvisorAction('navigate', 'degreeProgress')),
            icon: const Icon(Icons.trending_up, size: 18),
            label: const Text('View progress'),
          ),
        ],
      ),
    );
  }
}
