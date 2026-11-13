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
import 'program_library_screen.dart';
import 'generated_schedule_screen.dart';
import '../services/schedule_draft_service.dart';
import '../services/schedule_assistant_service.dart';

class AiAdvisorScreen extends StatefulWidget {
  final AiAdvisorService? service;
  final ScheduleAssistantService? scheduleAssistant;
  final Student student;
  final AdvisorHistoryService history;
  AiAdvisorScreen({
    super.key,
    this.service,
    this.scheduleAssistant,
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
    if (ScheduleDraftService.current case final draft?) {
      context['schedule'] = draft.explanationContext;
    }
    context['currentTheme'] = theme.preset.name;
    context['themeSettings'] = {
      'design': theme.customTheme.design.name,
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
      final AdvisorReply answer;
      if (ScheduleDraftService.isEditRequest(text)) {
        if (text.length > 1000) {
          answer = const AdvisorReply(
            'Please keep a schedule change request under 1,000 characters.',
            [],
          );
        } else if (ScheduleDraftService.current != null) {
          answer = AdvisorReply(
            'I can apply this to your current draft. Tap below to open the timetable and run this request with prerequisite, availability and conflict checks.',
            [AdvisorAction('reviseSchedule', 'currentSchedule', request: text)],
          );
        } else {
          answer = const AdvisorReply(
            'Open the builder and generate a schedule first. Then I can apply changes to that draft.',
            [AdvisorAction('navigate', 'scheduleBuilder')],
          );
        }
      } else {
        answer = await _service.respond(recent, fresh);
      }
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
    if (action.type == 'reviseSchedule') return 'Update current schedule';
    if (action.type == 'customTheme') return 'Apply custom colors';
    if (action.type == 'changeDesign') return 'Apply ${action.target} layout';
    if (action.type == 'changeTheme') {
      return 'Apply ${AppThemePreset.values.firstWhere((p) => p.name == action.target).displayName}';
    }
    return switch (action.target) {
      'transcript' => 'Open Transcript',
      'degreeProgress' => 'View Degree Progress',
      'recommendations' => 'View Needed Classes',
      'scheduleBuilder' => 'Open Schedule Builder',
      'programLibrary' => 'Open Programs of Study',
      _ => 'Open Theme Studio',
    };
  }

  Future<void> _perform(AdvisorAction action) async {
    try {
      if (action.type == 'reviseSchedule') {
        final draft = ScheduleDraftService.current;
        if (draft == null) throw StateError('Generate a current draft first.');
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'GeneratedScheduleScreen'),
            builder: (_) => GeneratedScheduleScreen(
              plan: draft.plan,
              draft: draft,
              initialRequest: action.request,
              assistant: widget.scheduleAssistant,
            ),
          ),
        );
        if (mounted) await _refreshContext();
        return;
      }
      if (action.type == 'changeTheme' ||
          action.type == 'customTheme' ||
          action.type == 'changeDesign') {
        final scope = AdvisorAppActions.maybeOf(context);
        if (scope == null) {
          setState(
            () => _error = 'Theme changes are available when opened from Home.',
          );
          return;
        }
        final current = await ThemeService.load();
        final preset = action.type == 'changeDesign'
            ? current.preset
            : action.type == 'customTheme'
            ? AppThemePreset.custom
            : AppThemePreset.values.firstWhere((p) => p.name == action.target);
        final custom = action.type == 'changeDesign'
            ? current.customTheme.copyWith(
                design: AppDesign.values.firstWhere(
                  (d) => d.name == action.target,
                ),
              )
            : action.type == 'customTheme'
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
          SnackBar(
            content: Text(
              action.type == 'changeDesign'
                  ? '${action.target} layout applied'
                  : '${preset.displayName} applied',
            ),
          ),
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
          case 'programLibrary':
            page = const ProgramLibraryScreen();
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
                'programLibrary' => 'ProgramLibraryScreen',
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
                  if (size.maxHeight >= 420 && _saved)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 3),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Conversation saved on this browser',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                    ),
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
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '${_changes.length} requirements changed since this chat.',
                              style: TextStyle(color: colors.onSurfaceVariant),
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
                  if (wide && size.maxHeight >= 420)
                    SizedBox(width: 250, child: _progressPanel(colors)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _welcome(ColorScheme colors) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.student.classification} · ${widget.student.major}',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        for (final question in [
          'What should I take in Spring 2027?',
          'What classes do I still need?',
        ])
          TextButton.icon(
            onPressed: _context == null || _busy ? null : () => _send(question),
            icon: const Icon(Icons.arrow_forward, size: 17),
            iconAlignment: IconAlignment.end,
            label: Text(question, textAlign: TextAlign.left),
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
        padding: EdgeInsets.fromLTRB(user ? 14 : 0, 12, 14, 12),
        decoration: user
            ? BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user ? 'You' : 'Tiger Path',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: user ? colors.onPrimaryContainer : colors.primary,
              ),
            ),
            const SizedBox(height: 6),
            if (user)
              SelectableText(
                message.text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: colors.onPrimaryContainer,
                ),
              )
            else
              AdvisorResponse(text: message.text),
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
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
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
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                    ),
                    onPressed: _busy || _context == null ? null : () => _send(),
                    icon: const Icon(Icons.arrow_upward, size: 20),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                foregroundColor: colors.onSurfaceVariant,
              ),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialog) => AlertDialog(
                  title: const Text('Chat privacy'),
                  content: const Text(
                    'Questions, class year, and planning results go to Google Gemini. Tiger Path excludes your name, grades, GPA, and full transcript. Avoid including private details in your messages.\n\nChats are stored on this browser. Use Saved chats to clear them on a shared device.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              child: const Text('Chat privacy'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _progressPanel(ColorScheme colors) {
    final student = widget.student;
    final theme = Theme.of(context);
    final progress = student.requiredCredits > 0
        ? (student.earnedCredits / student.requiredCredits).clamp(0.0, 1.0)
        : 0.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.outlineVariant)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Degree progress', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              '${student.earnedCredits.toInt()} / ${student.requiredCredits.toInt()} credits',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 9),
            LinearProgressIndicator(value: progress, minHeight: 4),
            const SizedBox(height: 9),
            Text(
              '${student.inProgressCredits.toInt()} credits in progress',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  _perform(const AdvisorAction('navigate', 'degreeProgress')),
              child: const Text('View progress'),
            ),
          ],
        ),
      ),
    );
  }
}
