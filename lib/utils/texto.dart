// Copyright (c) 2026 Victor Uzziel Gonzalez. Todos los derechos reservados.
// Software propietario: prohibida su copia o distribución sin autorización.

/// Lowercases and strips common Spanish accents so "pantalon" also finds
/// "Pantalón" — the tolerant matching searches and color names need.
String normalizar(String input) {
  const accented = 'áàäâéèëêíìïîóòöôúùüûñ';
  const plain = 'aaaaeeeeiiiioooouuuun';
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final idx = accented.indexOf(ch);
    buffer.write(idx == -1 ? ch : plain[idx]);
  }
  return buffer.toString();
}

/// Up to two capital letters from a name, e.g. "Playera Básica" → "PB",
/// for avatars. Empty when the name has no letters to take.
String iniciales(String nombre) => nombre
    .trim()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .take(2)
    .map((w) => String.fromCharCode(w.runes.first).toUpperCase())
    .join();
