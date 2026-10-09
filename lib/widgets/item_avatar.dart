// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../utils/texto.dart';

/// A garment's picture in the catalog: its photo when this phone has one,
/// otherwise its initials on a soft tonal tile. A photo that fails to load
/// (deleted, moved to a new phone without it) falls back to the initials.
class ItemAvatar extends StatefulWidget {
  const ItemAvatar({
    super.key,
    required this.nombre,
    this.photoPath,
    this.size = 56,
  });

  final String nombre;

  /// This phone's local photo file for the garment (never synced).
  final String? photoPath;
  final double size;

  @override
  State<ItemAvatar> createState() => _ItemAvatarState();
}

class _ItemAvatarState extends State<ItemAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(ItemAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photoPath != oldWidget.photoPath) _failed = false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = widget.size;
    final radius = BorderRadius.circular(Radii.md + 2);
    final path = widget.photoPath;

    if (path != null && !_failed) {
      return ExcludeSemantics(
        child: ClipRRect(
          borderRadius: radius,
          child: Image.file(
            File(path),
            width: size,
            height: size,
            fit: BoxFit.cover,
            // Decoded at display size, not the photo's full resolution.
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            errorBuilder: (context, error, stackTrace) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _failed = true);
              });
              return SizedBox(width: size, height: size);
            },
          ),
        ),
      );
    }

    final initials = iniciales(widget.nombre);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              Color.lerp(
                colorScheme.primaryContainer,
                colorScheme.primary,
                0.3,
              )!,
            ],
          ),
        ),
        child: initials.isEmpty
            ? Icon(
                Icons.checkroom_rounded,
                color: colorScheme.onPrimaryContainer,
                size: size * 0.45,
              )
            : Text(
                initials,
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.32,
                  letterSpacing: -0.5,
                ),
              ),
      ),
    );
  }
}
