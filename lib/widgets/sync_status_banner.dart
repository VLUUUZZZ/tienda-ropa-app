import 'dart:async';

import 'package:flutter/material.dart';

/// Tells the person, without them asking, whether what they did on this
/// phone already reached the other phones of the store.
///
/// Nothing shows while everything is in sync. Changes that stay unconfirmed
/// for a few seconds (no connection) show a notice that they're safe on
/// this phone and will go up by themselves; when they finally do, a short
/// "all synced" replaces it. The delay keeps the notice from flashing on
/// every save while online, when changes are confirmed almost at once.
class SyncStatusBanner extends StatefulWidget {
  const SyncStatusBanner({
    super.key,
    required this.changes,
    required this.pending,
  });

  /// Fires whenever [pending] may have changed.
  final Listenable changes;

  /// How many changes made here the server hasn't confirmed yet.
  final int Function() pending;

  @override
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

enum _Shown { nothing, pending, synced }

class _SyncStatusBannerState extends State<SyncStatusBanner> {
  static const _showAfter = Duration(seconds: 4);
  static const _syncedFor = Duration(seconds: 3);

  _Shown _shown = _Shown.nothing;
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.changes.addListener(_update);
    _update();
  }

  @override
  void didUpdateWidget(SyncStatusBanner old) {
    super.didUpdateWidget(old);
    if (old.changes != widget.changes) {
      old.changes.removeListener(_update);
      widget.changes.addListener(_update);
    }
  }

  @override
  void dispose() {
    widget.changes.removeListener(_update);
    _timer?.cancel();
    super.dispose();
  }

  void _update() {
    if (!mounted) return;
    final count = widget.pending();
    if (count > 0) {
      if (_shown == _Shown.pending) {
        setState(() => _count = count);
      } else if (_timer == null || _shown == _Shown.synced) {
        _timer?.cancel();
        _timer = Timer(_showAfter, () {
          _timer = null;
          if (!mounted) return;
          final still = widget.pending();
          if (still > 0) {
            setState(() {
              _shown = _Shown.pending;
              _count = still;
            });
          }
        });
      }
      return;
    }
    // Everything confirmed: a pending notice turns into "all synced" for a
    // moment; otherwise there's nothing to announce.
    _timer?.cancel();
    _timer = null;
    if (_shown == _Shown.nothing) return;
    if (_shown == _Shown.pending) setState(() => _shown = _Shown.synced);
    _timer = Timer(_syncedFor, () {
      _timer = null;
      if (mounted) setState(() => _shown = _Shown.nothing);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final Widget content = switch (_shown) {
      _Shown.nothing => const SizedBox(width: double.infinity),
      _Shown.pending => _Notice(
        key: const ValueKey('pending'),
        icon: Icons.cloud_off_rounded,
        background: colorScheme.surfaceContainerHigh,
        foreground: colorScheme.onSurface,
        title: _count == 1
            ? '1 cambio guardado solo en este teléfono'
            : '$_count cambios guardados solo en este teléfono',
        message:
            'Puedes seguir trabajando. Se enviarán solos a los demás '
            'teléfonos cuando vuelva la conexión.',
        textTheme: textTheme,
      ),
      _Shown.synced => _Notice(
        key: const ValueKey('synced'),
        icon: Icons.cloud_done_rounded,
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
        title: 'Todo sincronizado',
        message: 'Tus cambios ya están en todos los teléfonos de la tienda.',
        textTheme: textTheme,
      ),
    };

    return Semantics(
      liveRegion: true,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: content,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.title,
    required this.message,
    required this.textTheme,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String title;
  final String message;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleSmall?.copyWith(color: foreground),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: textTheme.bodySmall?.copyWith(
                      color: foreground.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
