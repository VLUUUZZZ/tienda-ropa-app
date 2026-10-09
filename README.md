# Tienda de Ropa

App móvil para llevar el catálogo, el inventario y las ventas de una tienda de ropa.
Cada prenda tiene una etiqueta con código QR para consultarla o ajustar su existencia al
escanearla. Varias personas pueden usarla a la vez desde su teléfono y funciona sin internet.

## Funciones

- Catálogo con búsqueda por nombre, código, color o talla, y filtros por existencia.
- Prendas con tallas, colores y piezas por combinación; foto y código de barras del proveedor.
- Etiquetas QR para imprimir o compartir; escáner de QR y código de barras.
- Ajuste de existencias, registro de ventas e historial de ajustes.
- Exportar el catálogo a CSV.
- Roles: **Administrador** (todo) y **Empleado** (consultar, escanear, vender y ajustar existencias).
- Varias tiendas, cada una aislada; tema claro y oscuro.

## Tecnología

- Flutter (Android e iOS) con Material 3.
- Hive para los datos en el teléfono y Firebase (Auth y Firestore) para sincronizar.

## Instalación

```bash
flutter pub get
flutter run
```

Las reglas de seguridad de Firestore están en `firestore.rules` y se publican con:

```bash
firebase deploy --only firestore:rules
```

## Estructura

| Carpeta | Contenido |
|---|---|
| `lib/models/` | Modelos de datos. |
| `lib/data/` | Almacenamiento local y sincronización. |
| `lib/auth/` | Sesión, usuarios y roles. |
| `lib/screens/` | Pantallas. |
| `lib/widgets/` | Componentes compartidos. |
| `lib/utils/` | Formatos de precio, fecha y texto. |
