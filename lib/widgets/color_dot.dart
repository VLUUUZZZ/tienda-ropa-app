import 'package:flutter/material.dart';

import '../utils/texto.dart';

/// Colors are typed freely ("Azul marino", "vino"), so this maps the common
/// Spanish names to a swatch. More specific names come first so "azul
/// marino" is navy rather than plain blue.
const List<(String, Color)> _swatches = [
  ('marino', Color(0xFF1F2A44)),
  ('celeste', Color(0xFF8EC9EE)),
  ('turquesa', Color(0xFF30B3B0)),
  ('vino', Color(0xFF7A1F2B)),
  ('mostaza', Color(0xFFD4A017)),
  ('beige', Color(0xFFE3D3B6)),
  ('crema', Color(0xFFF3E9D2)),
  ('hueso', Color(0xFFF1EBDD)),
  ('caqui', Color(0xFFB3A57A)),
  ('kaki', Color(0xFFB3A57A)),
  ('lila', Color(0xFFC3A6DB)),
  ('morado', Color(0xFF6E3FA3)),
  ('violeta', Color(0xFF7F4FC9)),
  ('rosa', Color(0xFFEE8FB3)),
  ('fucsia', Color(0xFFD1307A)),
  ('naranja', Color(0xFFF08A24)),
  ('coral', Color(0xFFF27D6B)),
  ('amarillo', Color(0xFFF2CF3B)),
  ('dorado', Color(0xFFC9A43B)),
  ('plata', Color(0xFFBFC3C8)),
  ('plateado', Color(0xFFBFC3C8)),
  ('verde', Color(0xFF3E8E5A)),
  ('oliva', Color(0xFF6F7440)),
  ('azul', Color(0xFF2F63C4)),
  ('rojo', Color(0xFFD23B34)),
  ('cafe', Color(0xFF6D4A31)),
  ('marron', Color(0xFF6D4A31)),
  ('chocolate', Color(0xFF5A3825)),
  ('camel', Color(0xFFB98A55)),
  ('gris', Color(0xFF8C8F94)),
  ('negro', Color(0xFF1B1B1D)),
  ('blanco', Color(0xFFFFFFFF)),
  ('mezclilla', Color(0xFF4A6A8F)),
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
