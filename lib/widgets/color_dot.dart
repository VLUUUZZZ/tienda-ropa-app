// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

import 'package:flutter/material.dart';

import '../utils/texto.dart';

/// Colors are typed freely ("Azul marino", "vino"), so this maps the common
/// Spanish names to a swatch. The first name contained in the color wins,
/// so specific names come first: "Azul marino" is navy, "Verde oliva" is
/// olive, not plain blue or green.
const List<(String, Color)> _swatches = [
  // Compound or specific names first...
  ('marino', Color(0xFF1F2A44)),
  ('mezclilla', Color(0xFF4A6A8F)),
  ('celeste', Color(0xFF8EC9EE)),
  ('turquesa', Color(0xFF30B3B0)),
  ('oliva', Color(0xFF6F7440)),
  ('militar', Color(0xFF4B5320)),
  ('vino', Color(0xFF7A1F2B)),
  ('mostaza', Color(0xFFD4A017)),
  ('beige', Color(0xFFE3D3B6)),
  ('crema', Color(0xFFF3E9D2)),
  ('hueso', Color(0xFFF1EBDD)),
  ('caqui', Color(0xFFB3A57A)),
  ('kaki', Color(0xFFB3A57A)),
  ('camel', Color(0xFFB98A55)),
  ('chocolate', Color(0xFF5A3825)),
  ('lila', Color(0xFFC3A6DB)),
  ('fucsia', Color(0xFFD1307A)),
  ('coral', Color(0xFFF27D6B)),
  ('dorado', Color(0xFFC9A43B)),
  ('plateado', Color(0xFFBFC3C8)),
  ('plata', Color(0xFFBFC3C8)),
  // ...then the plain colors they contain.
  ('morado', Color(0xFF6E3FA3)),
  ('violeta', Color(0xFF7F4FC9)),
  ('rosa', Color(0xFFEE8FB3)),
  ('naranja', Color(0xFFF08A24)),
  ('amarillo', Color(0xFFF2CF3B)),
  ('verde', Color(0xFF3E8E5A)),
  ('azul', Color(0xFF2F63C4)),
  ('rojo', Color(0xFFD23B34)),
  ('cafe', Color(0xFF6D4A31)),
  ('marron', Color(0xFF6D4A31)),
  ('gris', Color(0xFF8C8F94)),
  ('negro', Color(0xFF1B1B1D)),
  ('blanco', Color(0xFFFFFFFF)),
];

/// The swatch for a color name, or null when the name isn't recognized.
Color? swatchFor(String nombre) {
  final n = normalizar(nombre);
  for (final (clave, color) in _swatches) {
    if (n.contains(clave)) return color;
  }
  return null;
}

/// A small round swatch next to a color's name. Unknown names get a neutral
/// ring so the row stays aligned; the name is always shown alongside, since
/// the swatch alone isn't accessible.
class ColorDot extends StatelessWidget {
  const ColorDot({super.key, required this.nombre, this.size = 12});

  final String nombre;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final swatch = swatchFor(nombre);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: swatch ?? Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.outline, width: 1),
        ),
      ),
    );
  }
}
