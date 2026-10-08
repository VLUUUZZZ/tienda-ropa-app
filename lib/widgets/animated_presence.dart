import 'package:flutter/material.dart';

/// Shows a list entry arriving or leaving instead of popping in and out:
/// a short fade + slide + resize, so the rest of the list makes room (or
/// closes the gap) smoothly and the eye follows what changed.
///
/// [animateIn] plays the entrance once, when first built. [leaving] plays
/// the exit and then calls [onGone]; turning it back off (e.g. "Deshacer")
/// brings the entry back. With the system's "remove animations" setting on,
/// everything happens at once.
class AnimatedPresence extends StatefulWidget {
  const AnimatedPresence({
    super.key,
    required this.child,
    this.animateIn = false,
    this.leaving = false,
    this.onGone,
  });

  final Widget child;
  final bool animateIn;
  final bool leaving;
  final VoidCallback? onGone;

  @override
  State<AnimatedPresence> createState() => _AnimatedPresenceState();
}

class _AnimatedPresenceState extends State<AnimatedPresence>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 260);

  /// Leaving usually starts while the screen that deleted the entry is
  /// still closing; waiting this long lets the exit be seen.
  static const _exitDelay = Duration(milliseconds: 220);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: widget.animateIn || widget.leaving ? null : 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.leaving) {
      _controller.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _leave());
    } else if (widget.animateIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_reduceMotion) {
          _controller.value = 1;
        } else {
          _controller.forward();
        }
      });
    }
  }

  @override
  void didUpdateWidget(AnimatedPresence old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) {
      _leave();
    } else if (!widget.leaving && old.leaving) {
      _controller.forward();
    }
  }

  Future<void> _leave() async {
    if (!mounted) return;
    if (!_reduceMotion) {
      await Future<void>.delayed(_exitDelay);
      if (!mounted || !widget.leaving) return;
      await _controller.reverse().orCancel.catchError((_) {});
    }
    if (mounted && widget.leaving) widget.onGone?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: widget.leaving,
      child: SizeTransition(
        sizeFactor: _curve,
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: _curve,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(_curve),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
