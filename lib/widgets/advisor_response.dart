import 'package:flutter/material.dart';

/// A small, selectable text renderer for advisor headings and lists.
/// Treats links/HTML as text and never executes content returned by the model.
class AdvisorResponse extends StatelessWidget {
  final String text;
  const AdvisorResponse({super.key, required this.text});

  List<InlineSpan> _spans(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in RegExp(r'\*\*(.+?)\*\*').allMatches(text)) {
      spans.add(
        TextSpan(text: text.substring(offset, match.start), style: style),
      );
      spans.add(
        TextSpan(
          text: match[1],
          style: style.copyWith(fontWeight: FontWeight.w700),
        ),
      );
      offset = match.end;
    }
    spans.add(TextSpan(text: text.substring(offset), style: style));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Older saved answers sometimes place numbered sections on one line.
    final normalized = text.replaceAllMapped(
      RegExp(r'([.:])\s+(?=\d+\.\s)'),
      (m) => '${m[1]}\n',
    );
    final lines = normalized.split('\n');
    final base = TextStyle(fontSize: 14, height: 1.55, color: colors.onSurface);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines)
          if (line.trim().isNotEmpty) _line(line.trim(), base, colors),
      ],
    );
  }

  Widget _line(String line, TextStyle base, ColorScheme colors) {
    final heading = RegExp(r'^#{1,3}\s+(.+)$').firstMatch(line);
    if (heading != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: SelectableText.rich(
          TextSpan(
            children: _spans(
              heading[1]!,
              base.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    }
    final bullet = RegExp(r'^(?:[-*•]\s+|(\d+)[.)]\s+)(.*)$').firstMatch(line);
    if (bullet != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 26,
              child: Text(
                bullet[1] == null ? '•' : '${bullet[1]}.',
                style: base.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: SelectableText.rich(
                TextSpan(children: _spans(bullet[2]!, base)),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SelectableText.rich(TextSpan(children: _spans(line, base))),
    );
  }
}
