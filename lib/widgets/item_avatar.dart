import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../utils/texto.dart';

/// A garment's initials on a soft tonal tile, its picture in the catalog.
class ItemAvatar extends StatelessWidget {
  const ItemAvatar({super.key, required this.nombre, this.size = 56});

  final String nombre;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = iniciales(nombre);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md + 2),
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
