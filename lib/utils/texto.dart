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
