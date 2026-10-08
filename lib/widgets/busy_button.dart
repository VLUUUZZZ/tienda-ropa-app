import 'package:flutter/material.dart';

/// Primary button that shows a spinner and ignores taps while [busy].
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
    this.busyLabel,
  });

  final String label;

  /// What's happening while busy ("Entrando…"), next to the spinner.
  final String? busyLabel;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: busy
            ? Row(
                key: const ValueKey('busy'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      // The default spinner color matches FilledButton's own
                      // background (colorScheme.primary), so it's invisible
                      // unless set explicitly to the button's foreground.
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                  if (busyLabel != null) ...[
                    const SizedBox(width: 10),
                    Text(busyLabel!),
                  ],
                ],
              )
            : Text(label, key: const ValueKey('idle')),
      ),
    );
  }
}
