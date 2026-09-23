# Tienda de Ropa

App móvil (Flutter) para llevar el catálogo y el inventario de una tienda de ropa.

## Qué hace

- **Catálogo** con búsqueda por nombre, código (`PRENDA-000012`), color o talla, sin
  importar mayúsculas ni acentos.
- **Existencias por talla y color**, con ajuste rápido (+/−) y avisos de *poca
  existencia* y *agotado*. Filtros y un resumen con el total de prendas, piezas y el
  valor del inventario.
- **Etiquetas QR**: cada prenda tiene un código legible que se imprime y se pega en
  ella; al escanearlo se abre la prenda.
- **Varias tiendas y roles**: cada tienda tiene su propio catálogo. El Administrador
  gestiona prendas y usuarios; el Empleado consulta, escanea y ajusta existencias.
- **Funciona sin conexión**: los datos viven en el teléfono (Hive) y se sincronizan
  con Firebase (Firestore) cuando hay red.
- Tema claro y oscuro.

## Estructura

| Carpeta | Contenido |
|---|---|
| `lib/models/` | Prenda y sus variantes (talla, color, existencia). |
| `lib/data/` | Catálogo local, sincronización con Firestore y ajustes. |
| `lib/auth/` | Usuarios, roles e inicio de sesión (Firebase Auth). |
| `lib/screens/` | Pantallas de la app. |
| `lib/widgets/` | Piezas de interfaz compartidas. |
| `lib/app_theme.dart` | Paleta, tipografía y estilos de toda la app. |
| `firestore.rules` | Permisos aplicados en el servidor. |

## Desarrollo

```bash
flutter pub get
flutter analyze
flutter run
```

Las tareas pendientes y el historial de cambios están en [`BACKLOG.md`](BACKLOG.md).
