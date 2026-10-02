import '../models/clothing_item.dart';

/// The catalog as a CSV table, one row per color/talla variant (or one bare
/// row for a garment with none), so it opens straight into Excel/Sheets as a
/// backup or to hand to someone outside the app.
String catalogToCsv(List<ClothingItem> items) {
  final rows = StringBuffer('Id,Nombre,Precio,Color,Talla,Existencia\n');
  for (final item in items) {
    if (item.variantes.isEmpty) {
      rows.writeln(
        _row([item.id, item.nombre, _price(item.precio), '', '', '']),
      );
      continue;
    }
    for (final v in item.variantes) {
      rows.writeln(
        _row([
          item.id,
          item.nombre,
          _price(item.precio),
          v.color,
          v.talla,
          '${v.existencia}',
        ]),
      );
    }
  }
  return rows.toString();
}

String _price(double precio) => precio.toStringAsFixed(2);

String _row(List<String> fields) => fields.map(_csvField).join(',');

/// Quotes a field only if it needs it (has a comma, quote or newline),
/// doubling any inner quotes — the standard CSV escaping Excel expects.
String _csvField(String value) {
  final needsQuoting = value.contains(RegExp(r'[,"\r\n]'));
  if (!needsQuoting) return value;
  return '"${value.replaceAll('"', '""')}"';
}
