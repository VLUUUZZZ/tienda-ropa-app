import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_theme.dart';

/// One way forward from a [SuccessScreen].
class SuccessAction<T> {
  const SuccessAction({required this.label, required this.value, this.icon});

  final String label;
  final IconData? icon;

  /// What the screen closes with when this is chosen.
  final T value;
}

/// Shows that a whole process finished (a garment created, a store opened,
/// an account made) and offers what to do next. Resolves to the chosen
/// action's value, or null if the person just went back.
Future<T?> showSuccess<T>(
  BuildContext context, {
  required String title,
  required String message,
  Widget? detail,
  required SuccessAction<T> primary,
  SuccessAction<T>? secondary,
}) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SuccessScreen<T>(
        title: title,
        message: message,
        detail: detail,
        primary: primary,
        secondary: secondary,
      ),
    ),
  );
}

class SuccessScreen<T> extends StatefulWidget {
  const SuccessScreen({
    super.key,
    required this.title,
    required this.message,
    this.detail,
    required this.primary,
    this.secondary,
  });

  final String title;
  final String message;

  /// A summary of what was just created, shown on a card.
  final Widget? detail;
  final SuccessAction<T> primary;
  final SuccessAction<T>? secondary;

  @override
  State<SuccessScreen<T>> createState() => _SuccessScreenState<T>();
}

class _SuccessScreenState<T> extends State<SuccessScreen<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respects the system's "reduce motion": the check is simply there.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final pop = Navigator.of(context).pop<T>;

    final badge = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.7, curve: Curves.elasticOut),
    );
    final content = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1, curve: Curves.easeOutCubic),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cerrar',
            onPressed: () => pop(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: badge,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primaryContainer,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 60,
                        color: colorScheme.onPrimaryContainer,
                        semanticLabel: 'Listo',
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: content,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(content),
                      child: Column(
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (widget.detail != null) ...[
                            const SizedBox(height: 24),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(Radii.md),
                                child: widget.detail,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () => pop(widget.primary.value),
              icon: Icon(widget.primary.icon ?? Icons.arrow_forward_rounded),
              label: Text(widget.primary.label),
            ),
            if (widget.secondary case final secondary?) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => pop(secondary.value),
                icon: Icon(secondary.icon ?? Icons.arrow_forward_rounded),
                label: Text(secondary.label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
