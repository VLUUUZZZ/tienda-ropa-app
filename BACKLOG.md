# Backlog

Agrega aquí las tareas que quieres que se trabajen en la sesión automática diaria (7:00 am). Reglas:

1. La sesión diaria toma las tareas de "Pendiente", de arriba hacia abajo.
2. Si no hay ninguna pendiente, se dedica a pulir lo que ya existe (bugs, UI/UX, rendimiento, pruebas) — sin agregar funciones nuevas grandes por su cuenta.
3. Cada tarea completada se mueve a "Completado" con la fecha y el commit correspondiente.
4. Todo cambio se compila y se prueba antes de darse por terminado, y queda guardado en git (nunca se sube a ningún remoto sin que tú lo pidas).
5. Si en algún momento se necesita una base de datos remota/backend, debe ser Firebase (acordado con el usuario el 2026-09-22).

## Pendiente

(vacío por ahora — agrega tareas aquí, una por línea)

## Completado

### 2026-09-26 — sesión automática diaria de pulido

Sin tareas en "Pendiente", así que se dedicó a pulir detalles reales encontrados
al revisar el código (nada de funciones nuevas):

1. En el formulario de prenda, una fila de talla/color vacía sin usar podía
   bloquear el botón "Guardar" por un valor sospechoso en "Existencia", aunque
   esa fila se descarta igual al guardar. Ya no bloquea.
2. El aviso de "combinación ya registrada" ahora se ve igual (rojo, con ícono)
   que los demás errores de esa pantalla, en vez de un aviso gris distinto.
3. Si la cámara fallaba al escanear por un motivo raro, a veces se mostraba
   texto técnico en inglés debajo del mensaje en español. Ya queda solo en
   español.
4. Al recuperar la contraseña con un correo mal escrito (no vacío), se
   mostraba "escribe tu correo" como si estuviera vacío. Ahora avisa
   correctamente que el formato es incorrecto.
5. El administrador de contraseñas del teléfono no ofrecía guardar ni
   autocompletar en ningún formulario de la app. Ahora sí, en inicio de
   sesión y al crear una tienda nueva; en cambio, al crear la cuenta de un
   empleado se desactivó a propósito (esa contraseña temporal no es la del
   administrador).
6. Pequeños detalles: el botón de limpiar la búsqueda ya tiene su tooltip,
   como los demás botones de la app; la pantalla de editar prenda ya no
   vuelve a leer la base de datos local en cada repintado, solo para saber
   si la prenda ya existía.

Verificado con `flutter analyze` (0 avisos). No se ejecutó `flutter build apk`
porque esta sesión automática no tiene el SDK de Android instalado (se avisa
para que se revise con un build real antes de publicar en la tienda). No se
agregaron pruebas automatizadas porque el propio backlog registra que se
retiraron a pedido del dueño de la app (ver nota de 2026-09-22 más abajo).

### 2026-09-25 — commits `3b2537f`, `ff7572f`, `a0a70a8`, `35b2a6e`, `fc00278`, `429397f`, `0734ed6`, `34ba8e8`

Sesión automática diaria (sin tareas pendientes en el backlog, según regla 2). Se pidió una
auditoría dedicada del código (no solo revisión superficial) buscando bugs reales, y se
corrigieron los que fueron seguros de arreglar sin poder probar contra un proyecto de
Firebase real:

1. Al volver de editar/escanear una prenda o de crear una nueva, la pantalla principal
   podía intentar refrescarse justo después de haberse cerrado (por ejemplo si la sesión
   termina mientras esa pantalla estaba abierta), lo que podía producir un error interno.
   Corregido el orden de las comprobaciones.
2. Si un administrador editaba el rol o el estado de un empleado y algo fallaba de forma
   no habitual, no aparecía ningún aviso. Ahora siempre se muestra un mensaje.
3. La etiqueta "AGOTADO" aparecía con distinto criterio en el formulario completo y en la
   edición rápida de existencia; ahora usan el mismo.
4. Los mensajes de error de inicio de sesión sin traducción específica mostraban el código
   técnico en inglés (por ejemplo "internal-error"); ahora siempre se ve un mensaje en
   español.
5. Al crear una tienda nueva, si algo fallaba y además fallaba el intento de deshacer esa
   creación, el usuario veía un error confuso en vez del mensaje claro esperado.
6. Al dar de alta un empleado, si se creaba su acceso pero fallaba guardar su ficha (nombre,
   tienda, rol), quedaba una cuenta fantasma que nadie podía usar y que dejaba ese correo
   inutilizable para siempre. Ahora esa cuenta se deshace automáticamente.
7. Una tienda recién creada y todavía vacía podía no terminar de confirmar con el servidor
   que ya no había nada pendiente por subir del teléfono, dejando ese primer catálogo sin
   sincronizar en algunos casos.
8. Si algo impedía preparar el almacenamiento del teléfono al abrir la app (por ejemplo,
   sin espacio libre), la app se quedaba en una pantalla en blanco sin remedio. Ahora
   muestra un aviso con botón para reintentar.

No se agregaron pruebas automatizadas nuevas (el usuario pidió antes retirarlas de
`test/` y no se quiso ir en contra de eso). Se detectaron además dos problemas más
delicados que se decidió NO tocar hoy, por prudencia, ya que tocan la sincronización con
Firebase y no hay forma de probarlos contra un proyecto real en esta sesión automática:
si la misma prenda se edita dos veces muy seguido, el orden en que esos dos cambios
llegan al servidor no está garantizado del todo; y la numeración de una prenda nueva
(PRENDA-000024, etc.) no tiene protección si se presionara "Agregar" dos veces muy
rápido. Ninguno de los dos es un problema con el uso normal de la app.

Verificado con flutter analyze (0 avisos) y dart format. No se pudo compilar el APK
(flutter build apk) porque esta sesión automática no tiene el SDK de Android instalado;
tampoco se ejecutó flutter test porque el proyecto no tiene carpeta test/ (se retiró a
propósito antes).

### 2026-09-24 — commits `a18433e`, `c6145b5`, `558d2e3`, `bf2f68c`

Sesión automática diaria (sin tareas pendientes en el backlog, según regla 2). Revisión
completa de las pantallas de catálogo, escáner, QR y sobre todo del login/cuentas
(lo más nuevo del proyecto, agregado el 2026-09-22), buscando errores reales, no solo
estilo:

1. Si un inicio de sesión, registro de tienda o alta de empleado fallaba por algo que
   no fuera un error conocido de Firebase (por ejemplo un problema de red raro), la
   pantalla simplemente dejaba de mostrar el círculo de "cargando" sin decir nada —
   la persona no sabía si funcionó o no. Ahora siempre aparece un mensaje de error.
2. El formulario para dar de alta un nuevo usuario no enviaba el formulario al
   presionar "Listo" en el teclado después de escribir la contraseña temporal, a
   diferencia de los demás formularios de la app (inicio de sesión, nueva tienda).
   Ahora es consistente.
3. El texto del aviso flotante de error (por ejemplo "No se pudo guardar") no fijaba
   su color, así que podía verse con poco contraste sobre el fondo rojo según el
   tema. Ahora usa el mismo color que su ícono.
4. Se actualizó `pubspec.lock` con la versión estable actual de Flutter (algunas
   dependencias internas subieron de versión menor) y se excluyeron las carpetas de
   cada plataforma (android, ios, web, etc.) del analizador de código, para que no
   las revise sin necesidad.

No se tocó el código de sincronización con Firebase (`lib/data/catalog_sync.dart` y
relacionados): es lógica delicada que ya funciona bien y maneja el catálogo real de la
tienda, así que se prefirió no arriesgar cambios ahí sin que el dueño lo pida
explícitamente.

Nota: como se pidió el 2026-09-22 retirar todas las pruebas automatizadas del
proyecto, esta sesión no agregó pruebas nuevas (para no contradecir esa decisión).

Verificado con `flutter analyze` (0 avisos). No se pudo correr `flutter build apk`
porque este entorno no tiene el SDK de Android instalado (solo se instaló Flutter);
el resto de los cambios son de bajo riesgo (mensajes y consistencia visual, sin tocar
lógica de guardado ni de sincronización).

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
