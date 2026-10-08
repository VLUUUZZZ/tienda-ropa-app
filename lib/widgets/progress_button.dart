import 'package:flutter/material.dart';

/// Where a [ProgressButton]'s action is.
enum ProgressState {
  /// Ready (or disabled, if there's no `onPressed`).
  idle,

  /// Working: shows a spinner and [ProgressButton.busyLabel], ignores taps.
  busy,

  /// Finished: a check and [ProgressButton.doneLabel] for a moment
  /// ([ProgressButton.doneHold]) before the screen moves on.
  done,
}

/// A screen's main action that shows what's happening to it: "Guardar" →
/// "Guardando…" → "✓ Guardado". The check is the confirmation that the
/// action went through, seen right where the person tapped; the screen then
/// closes or returns the button to normal.
///
/// Taps are ignored while busy or done, on top of whatever double-tap
/// protection the screen already has.
class ProgressButton extends StatelessWidget {
  const ProgressButton({
    super.key,
    required this.label,
    required this.icon,
    required this.state,
    required this.onPressed,
    this.busyLabel = 'Guardando…',
    this.doneLabel = 'Guardado',
  });

  /// How long the "done" check stays before the screen moves on: long
  /// enough to be seen, short enough not to feel like waiting.
  static const Duration doneHold = Duration(milliseconds: 450);

  final String label;
  final IconData icon;
  final ProgressState state;

  /// Null shows the button disabled (nothing to do yet).
  final VoidCallback? onPressed;
  final String busyLabel;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Widget content = switch (state) {
      ProgressState.idle => Row(
        key: const ValueKey('idle'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
      ProgressState.busy => Row(
        key: const ValueKey('busy'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              // The default spinner color is the button's own background.
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Text(busyLabel),
        ],
      ),
      ProgressState.done => Row(
        key: const ValueKey('done'),
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: const Icon(Icons.check_circle_rounded),
          ),
          const SizedBox(width: 8),
          Text(doneLabel),
        ],
      ),
    };

    return Semantics(
      liveRegion: state != ProgressState.idle,
      child: IgnorePointer(
        ignoring: state != ProgressState.idle,
        child: FilledButton(
          // Kept enabled-looking while busy/done (taps are ignored above),
          // so the progress reads as the button working, not switched off.
          onPressed: state == ProgressState.idle ? onPressed : () {},
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: content,
          ),
        ),
      ),
    );
  }
}
