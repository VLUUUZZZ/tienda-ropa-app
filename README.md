# Tienda de Ropa

App de catálogo para una tienda de ropa: control de existencia por color y
talla, código QR para identificar cada prenda, registro de ventas y ajustes
de existencia, con roles de Administrador y Empleado.

- Almacenamiento local con [Hive](https://pub.dev/packages/hive); con
  Firebase configurado (`lib/firebase_options.dart`), cada tienda sincroniza
  su catálogo, ventas y ajustes entre varios teléfonos.
- Sin Firebase configurado, la app funciona solo en este teléfono, sin inicio
  de sesión.
- Ver `BACKLOG.md` para el historial de cambios y las tareas pendientes.

## Para desarrollar

```
flutter pub get
flutter analyze
```
