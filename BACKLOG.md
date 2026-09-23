# Backlog

Agrega aquí las tareas que quieres que se trabajen en la sesión automática diaria (7:00 am). Reglas:

1. La sesión diaria toma las tareas de "Pendiente", de arriba hacia abajo.
2. Si no hay ninguna pendiente, se dedica a pulir lo que ya existe (bugs, UI/UX, rendimiento, pruebas) — sin agregar funciones nuevas grandes por su cuenta.
3. Cada tarea completada se mueve a "Completado" con la fecha y el commit correspondiente.
4. Todo cambio se compila y se prueba antes de darse por terminado, y queda guardado en git.
5. Sincronización con GitHub, para que ninguna sesión repita trabajo de otra:
   - Al empezar, antes de tomar una tarea: `git pull origin master` y revisar este archivo ya actualizado (y el código) para confirmar que la tarea no está hecha.
   - Al terminar cada tarea: moverla a "Completado" y subir el commit a `master` (`git push origin master`) de inmediato, no al final de la sesión.
   - Nunca usar `git push --force` sobre `master`: si el push es rechazado, hacer `git pull` (merge), resolver conflictos, volver a compilar/probar y subir de nuevo.
6. Si en algún momento se necesita una base de datos remota/backend, debe ser Firebase (acordado con el usuario el 2026-09-22).

## Pendiente

1. Evitar que dos teléfonos creen el mismo código de prenda: `LocalCatalog.nextId` usa un contador local; si dos teléfonos agregan prendas sin conexión al mismo tiempo, ambos pueden generar el mismo `PRENDA-0000NN` y una prenda pisaría a la otra al sincronizar. Generar el número de forma segura (p. ej. contador en Firestore con transacción, o un prefijo por dispositivo).
2. Imagen del QR al compartir en modo oscuro: el `Card` dentro del `RepaintBoundary` (`lib/screens/qr_screen.dart`) toma los colores del tema, así que en modo oscuro la imagen sale con fondo oscuro y texto claro. Debe salir siempre en fondo blanco con texto oscuro, lista para imprimir.
3. Al escanear un QR registrado como Administrador, abrir la edición rápida de existencia (`QuickStockScreen`) o preguntar qué hacer (ajustar existencia / ver ficha completa), en vez de ir directo al formulario completo (los empleados ya van a la edición rápida).
4. Búsqueda también por código (`PRENDA-000012`), color y talla, no solo por nombre.
5. No gastar un número de código al cancelar una prenda nueva: asignar el id definitivo solo al guardar, para evitar huecos en la numeración.
6. Nombre visible "Tienda de Ropa" también en iOS (`CFBundleDisplayName` dice "Tienda Ropa App") y actualizar `README.md` y la descripción en `pubspec.yaml`, que siguen con el texto por defecto de Flutter.
7. Registro de ventas: botón "Vender" que descuente una pieza y guarde la venta, con historial y total del día.
8. Filtro de "poca existencia" / "agotados" en el catálogo.
9. Mostrar el valor total del inventario (precio × existencia).

## Completado

### 2026-09-22 (10) — pendiente

Décima ronda de pulido de la misma sesión: pruebas de widget para el formulario de prendas.

1. Nuevo `test/item_form_screen_test.dart` (4 pruebas): errores de validación con campos
   vacíos, aviso de combinación color+talla duplicada sin guardar, etiqueta AGOTADO solo
   cuando una fila usada tiene existencia 0, y el botón "Agregar" crea una fila de variante
   nueva.

20/20 pruebas. Verificado con flutter analyze (0 avisos).

### 2026-09-22 (9) — pendiente

Novena ronda de pulido de la misma sesión:

1. La pantalla de carga (splash) en Android usaba blanco puro (`@android:color/white`)
   en vez del crema cálido del tema de la app, así que había un destello blanco antes de
   que se dibujara la UI. Corregido a `#FBF4EF` (mismo color que `scaffoldBackgroundColor`
   en modo claro). El fallback para Android 5+ (`drawable-v21`) ya usaba el color del
   sistema dinámicamente y no necesitó cambios.

Verificado con flutter build apk --debug.

### 2026-09-22 (8) — pendiente

Octava ronda de pulido de la misma sesión:

1. Ícono de la app: seguía siendo el logo genérico de Flutter (nunca se había cambiado).
   Se reemplazó por un ícono propio (playera color crema sobre fondo terracota, la
   paleta real de `buildAppTheme`) generado con un script Python/Pillow
   (`tool/generate_launcher_icon.py`, no forma parte de la app — se ejecuta manualmente
   si se quiere regenerar) ya que no hay una herramienta de generación de imágenes
   disponible en esta sesión. Se regeneraron los 5 tamaños de mipmap.

Verificado con flutter build apk --debug e inspección visual de los PNG generados.

### 2026-09-22 (7) — pendiente

Séptima ronda de pulido de la misma sesión:

1. El nombre de la app en el launcher de Android mostraba "tienda_ropa_app" (el nombre de la
   carpeta del proyecto) en vez de "Tienda de Ropa". Corregido en `AndroidManifest.xml`.

Verificado con flutter build apk --debug.

### 2026-09-22 (6) — pendiente

Sexta ronda de pulido de la misma sesión: primeras pruebas de widget del proyecto.

1. Nuevo `test/home_screen_test.dart` (3 pruebas): catálogo vacío, listado de una prenda ya
   guardada, y filtrado por texto de búsqueda.
2. Al escribirlas se detectó un cuelgue real: `repo.save(...)` (E/S real de Hive) llamado
   directamente dentro del cuerpo de un `testWidgets` se queda colgado para siempre, porque
   `testWidgets` corre en una zona "fake async" que no deja avanzar la E/S real. Se corrigió
   envolviendo esas llamadas en `tester.runAsync(...)`, como indica la documentación de Flutter.

16/16 pruebas (9s). Verificado con flutter analyze (0 avisos) y flutter build apk --debug.

### 2026-09-22 (5) — pendiente

Quinta ronda de pulido de la misma sesión:

1. Al eliminar una prenda desde `ItemFormScreen`, ahora aparece un snackbar con botón
   "Deshacer" en la pantalla principal (4 segundos) en vez de eliminarla sin posibilidad
   de recuperarla. `ItemFormScreen` distingue "guardado" de "eliminado" al cerrar
   (`ItemFormResult`) para que `HomeScreen` sepa qué snackbar mostrar.

Verificado con flutter analyze (0 avisos), flutter test (13/13) y flutter build apk --debug.

### 2026-09-22 (4) — pendiente

Cuarta ronda de pulido de la misma sesión:

1. `ScannerScreen`: mensaje de error claro cuando la cámara falla (permiso denegado, dispositivo
   sin cámara compatible, u otro error), en vez de la pantalla negra genérica del paquete. Incluye
   botón "Reintentar" cuando aplica.

Verificado con flutter analyze (0 avisos), flutter test (13/13) y flutter build apk --debug.

### 2026-09-22 (3) — pendiente

Tercera ronda de pulido de la misma sesión (el usuario pidió seguir puliendo sin parar):

1. Persistencia del tema claro/oscuro entre reinicios de la app, vía `SettingsRepository`
   (nueva caja Hive `app_settings`) en vez de reiniciar siempre en modo claro.
2. Nuevas pruebas: round-trip de `toMap`/`fromMap` en `ClothingItem`, valores por defecto seguros
   cuando faltan campos opcionales, y `SettingsRepository` (persistencia del tema).

13/13 pruebas. Verificado con flutter analyze (0 avisos), flutter test y flutter build apk --debug.

### 2026-09-22 (2) — pendiente

Segunda ronda de pulido de la misma sesión:

1. `dart format` aplicado a todo `lib/` y `test/` (6 archivos no seguían el estilo estándar).
2. `HomeScreen`: mensaje de estado vacío distingue "catálogo realmente vacío" (invita a escanear
   o agregar) de "sin resultados para esta búsqueda".
3. `QrScreen`: si compartir/guardar la imagen del QR falla, ahora se muestra un snackbar de error
   en vez de fallar en silencio.

Verificado con flutter analyze (0 avisos), flutter test (9/9) y flutter build apk --debug.

### 2026-09-22 — commits `736e97e`, `4bf8e16`, pendiente

Sesión de pulido (sin tareas pendientes en el backlog, según regla 2):

1. `ItemFormScreen` y `QuickStockScreen`: detección de cambios sin guardar con confirmación
   al salir (interceptando el botón de retroceso vía `PopScope`).
2. Corregidos los 5 avisos que dejaba `flutter analyze` (llaves faltantes en `if`, y dos casos
   de `BuildContext` cruzando un `await` ya protegidos por `mounted` pero no reconocidos por el
   analizador — silenciados puntualmente tras confirmar que el patrón es seguro).
3. `ScannerScreen`: botón de linterna (flash) en la barra superior, útil para escanear en lugares
   con poca luz; se deshabilita solo si el dispositivo no tiene flash.

Verificado con flutter analyze (0 avisos), flutter test (9/9) y flutter build apk --debug.

### 2026-09-20 — commit `022ea4c`

Lista de pulido acordada con el usuario (búsqueda tolerante, tarjetas, edición rápida de
existencia, QR listo para imprimir, validaciones). Ya cumplido antes de esta sesión, sin cambios:
búsqueda por substring insensible a mayúsculas, orden alfabético por defecto, y el escáner ya
cerraba solo al detectar un código.

Implementado y verificado (flutter analyze, flutter test, flutter build apk --debug, todo real:
Hive local, cámara real vía mobile_scanner, share sheet nativo vía share_plus — nada simulado):

1. Tarjetas de producto muestran colores disponibles además de precio y existencia total.
2. Edición rápida de existencia por color/talla con botones +/-, sin pasar por el formulario completo.
3. Tallas en 0 se marcan como "AGOTADO" sin eliminar el registro.
4. Se evitan variantes duplicadas (misma combinación color + talla) dentro de una prenda.
5. Validaciones: precio y existencia no negativos, nombre/color/talla no vacíos.
6. QR con código legible tipo PRENDA-000001 (en vez de UUID) y opción de compartir/guardar como imagen.
7. Al escanear un QR que no corresponde a ninguna prenda registrada, se muestra "QR no reconocido"
   en vez de crear una prenda automáticamente.
8. Confirmación visual ("Cambios guardados") al guardar cambios desde la pantalla principal.
9. Búsqueda ahora también ignora acentos.

También se instaló el skill de diseño `ui-ux-pro-max` en `.claude/skills/` (repo
github.com/nextlevelbuilder/ui-ux-pro-max-skill) para consultarlo en trabajo de UI/UX futuro del
proyecto (paletas, tipografía, guías de accesibilidad, guías específicas de Flutter).

### 2026-09-22 — Login con roles

- Inicio de sesión con correo y contraseña (Firebase Auth), recuperación de contraseña.
- Roles en Firestore (`usuarios/{uid}`): **Administrador** (todo, incluida la gestión de
  usuarios) y **Empleado** (consultar, escanear y ajustar existencias).
- El admin crea las cuentas desde la app (Cuenta → Usuarios); puede cambiar el rol o
  desactivar a otros, nunca a sí mismo.
- Primer administrador: en un proyecto sin admin, el login ofrece "Configurar administrador"
  una sola vez.
- Los permisos se aplican en el servidor (`firestore.rules`), no solo ocultando botones; un
  cambio rechazado por permisos se descarta y vuelve la versión del servidor.
- A pedido del usuario se retiraron todas las pruebas automatizadas (`test/`) y el código que
  existía solo para ellas.

### 2026-09-22 — Varias tiendas, cada una con su propio espacio

- El login ofrece **Iniciar nueva tienda**: pide nombre, correo y contraseña, y deja a esa
  persona como Administrador de una tienda nueva ("Tienda de <nombre>"). Después entra solo
  con correo y contraseña.
- Cada tienda está aislada: su catálogo (`tiendas/{id}/prendas`) y su personal solo los ven
  sus miembros; en el teléfono cada tienda guarda sus datos por separado.
- El admin registra a sus empleados desde Cuenta → Usuarios; la barra superior muestra la
  tienda, el nombre del usuario y su rol.
- Se retira "Configurar administrador" (ya no hay un único admin global).

### Noche 2026-09-22/23

**Ronda 1 (23:30)**
- Ajuste rápido de existencias: al guardar se aplican solo los +/- hechos en la pantalla sobre
  la versión más reciente de la prenda (`ClothingItem.withStockChanges`), para no pisar
  ajustes hechos mientras tanto en otro teléfono. Si la prenda fue eliminada, se avisa.
- Guardar, eliminar y deshacer muestran un mensaje claro si falla el almacenamiento, en vez
  de quedarse colgados (`showErrorSnackBar`).
- `getById` ya no truena con un registro corrupto; el formulario ya no usa `!` al refrescar
  tras el ajuste rápido (la prenda pudo borrarse) y reconstruye las filas en un solo método.
- El escáner recorta espacios/saltos de línea alrededor del código leído.
- Al cerrar sesión, el catálogo se cierra después de que se van sus pantallas; si no se
  puede abrir el catálogo de la tienda se muestra "Reintentar" en vez de cargar sin fin.
- La lista de usuarios se suscribe a Firestore una sola vez, no en cada redibujo.
