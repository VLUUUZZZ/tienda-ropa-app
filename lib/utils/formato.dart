/// Money as shown everywhere in the app: "$1,250.00".
///
/// Written by hand rather than pulling in `intl` for one format.
String formatoPrecio(double valor) {
  final negativo = valor < 0;
  final centavos = (valor.abs() * 100).round();
  final enteros = (centavos ~/ 100).toString();
  final decimales = (centavos % 100).toString().padLeft(2, '0');

  final buffer = StringBuffer();
  for (var i = 0; i < enteros.length; i++) {
    if (i > 0 && (enteros.length - i) % 3 == 0) buffer.write(',');
    buffer.write(enteros[i]);
  }
  return '${negativo ? '-' : ''}\$$buffer.$decimales';
}

/// "1 pieza" / "3 piezas".
String formatoPiezas(int n) => n == 1 ? '1 pieza' : '$n piezas';

/// Reads a price as people type it: "1250", "1,250.50", "1.250,50",
/// "$ 300", "99,9". Returns null if it isn't a valid amount.
///
/// The last separator followed by one or two digits is the decimal point;
/// any other "," or "." is a thousands separator.
double? leerPrecio(String input) {
  var text = input.replaceAll(RegExp(r'[\s$]'), '');
  if (text.isEmpty || !RegExp(r'^[0-9.,]+$').hasMatch(text)) return null;

  final decimal = RegExp(r'[.,](\d{1,2})$').firstMatch(text);
  String entero = text;
  String fraccion = '';
  if (decimal != null) {
    entero = text.substring(0, decimal.start);
    fraccion = decimal.group(1)!;
  }
  // What's left may only use separators between groups of three digits.
  if (entero.contains(RegExp(r'[.,]'))) {
    if (!RegExp(r'^\d{1,3}([.,]\d{3})+$').hasMatch(entero)) return null;
    entero = entero.replaceAll(RegExp(r'[.,]'), '');
  }
  if (entero.isEmpty) entero = '0';
  final value = double.tryParse(
    fraccion.isEmpty ? entero : '$entero.$fraccion',
  );
  return (value == null || !value.isFinite) ? null : value;
}
