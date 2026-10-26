import 'package:flutter/material.dart';

/// Supporting copy available on hover, keyboard focus, or tap on a phone.
class InfoTip extends StatelessWidget {
  final String label;
  final String message;
  const InfoTip({super.key, required this.label, required this.message});

  @override
  Widget build(BuildContext context) {
    final tip = GlobalKey<TooltipState>();
    return Tooltip(
      key: tip,
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 12),
      constraints: const BoxConstraints(maxWidth: 320),
      child: IconButton(
        tooltip: null,
        onPressed: () => tip.currentState?.ensureTooltipVisible(),
        iconSize: 18,
        icon: Icon(Icons.info_outline, semanticLabel: label),
        disabledColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
