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
