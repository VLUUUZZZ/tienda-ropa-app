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

## Configuración de Firebase

Por seguridad, la clave de API de Firebase **no se guarda en el repositorio**: se
inyecta al compilar y los archivos con datos de Firebase están en `.gitignore`.

1. Copia la plantilla y pon tu clave:

   ```bash
   cp dart_define.example.json dart_define.json
   # edita dart_define.json y coloca tu FIREBASE_API_KEY
   ```

2. Para Android, coloca tu `google-services.json` (descargado de la consola de
   Firebase) en `android/app/`. Hay una plantilla en
   `android/app/google-services.json.example`.

3. Compila o ejecuta pasando el archivo de claves:

   ```bash
   flutter run        --dart-define-from-file=dart_define.json
   flutter build apk  --dart-define-from-file=dart_define.json
   ```

`dart_define.json` y `google-services.json` nunca se suben al repositorio.

## Instalación

```bash
flutter pub get
flutter run --dart-define-from-file=dart_define.json
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

## Licencia

© 2026 Victor Uzziel Gonzalez. Todos los derechos reservados. Software propietario:
prohibida su copia, modificación o distribución sin autorización escrita del autor.
Ver [`LICENSE`](LICENSE).
