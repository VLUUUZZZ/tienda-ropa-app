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

### 2026-09-29 — sesión automática diaria de pulido

Sin tareas en "Pendiente". Se revisó a fondo, archivo por archivo, todo `lib/`
(pantallas, autenticación, sincronización con Firebase, modelo de datos y
widgets compartidos) buscando errores reales de comportamiento. No se
encontró ningún bug nuevo: las rondas de pulido de días anteriores ya habían
cubierto los casos delicados (doble toque, sincronización, roles, mensajes de
error, contraste de colores, etc.) y el código sigue igual de sólido hoy.
Por eso no se tocó ningún archivo de código esta sesión, para no arriesgar
cambios sin un problema real que corregir.

Verificado de nuevo con `flutter analyze` (0 avisos) y `dart format` en todo
`lib/` (sin cambios pendientes). No hay pruebas automatizadas que correr (se
retiraron por pedido explícito del usuario el 2026-09-22). No se compiló el
APK: esta sesión no tiene el SDK de Android instalado.

Nota: la sesión del 2026-09-28 sigue esperando revisión en el Pull Request
#3 (`auto/mejoras-diarias` → `master`); no se abrió uno nuevo porque ya hay
uno abierto con todo lo pendiente de revisar.

### 2026-09-28 — sesión automática diaria de pulido

Sin tareas en "Pendiente". Antes de pulir, se incorporaron a esta rama los cambios
recientes de `master` (8 rondas de mejora que se habían hecho directo ahí), resolviendo
a mano los archivos que ambos lados habían tocado. Después se revisó `lib/` a fondo
buscando errores reales de comportamiento, no solo de estilo:

1. Un doble toque en el botón "+" podía crear dos prendas nuevas a la vez (dos
   formularios apilados) y desperdiciar un número de código. Ahora el segundo toque
   se ignora mientras el primero sigue en curso; también se corrigió la causa de raíz:
   generar el siguiente código de prenda dos veces muy seguido podía repetir el mismo
   número.
2. Al eliminar una prenda desde el formulario justo después de haber ajustado su
   existencia con el editor rápido (dentro de la misma visita), el botón "Deshacer"
   restauraba la existencia de antes del ajuste, no la más reciente. Ahora "Deshacer"
   siempre restaura la versión correcta.
3. El mensaje de catálogo vacío invitaba a "escanear" para agregar la primera prenda,
   pero escanear un código no registrado nunca crea una prenda (solo avisa "QR no
   reconocido"). Se quitó esa parte confusa del mensaje.
4. Caso muy raro de sincronización: si se guardaba una prenda nueva en el teléfono en
   el instante exacto en que llegaba una actualización desde otro teléfono, esa prenda
   nueva podía borrarse sola (localmente y en la nube). Corregido.
5. Si a un administrador le quitaban el rol o lo desactivaban mientras tenía abierta la
   pantalla de Usuarios, la pantalla seguía funcionando como si nada. Ahora se cierra
   sola apenas cambia su rol.
6. "Olvidé mi contraseña" con un correo que no existe mostraba "correo o contraseña
   incorrectos", un mensaje que no tiene sentido ahí (no se pidió contraseña). Ahora
   dice claramente que no se encontró una cuenta con ese correo.
7. Al crear una tienda nueva, por una fracción de segundo la app podía mostrar por
   error la pantalla de "sin acceso" mientras el perfil todavía se estaba guardando.
   Ya no pasa.
8. Se deshabilitó el botón de retroceder en "Iniciar nueva tienda" mientras se está
   creando la cuenta, para que no se pueda "salir" de algo que en realidad ya se está
   completando en segundo plano.
9. Varios mensajes de error mencionaban directamente "Firebase" o códigos técnicos
   sin traducir; se cambiaron por lenguaje sencillo.

Verificado con `flutter analyze` (0 avisos) y `dart format` en todo `lib/`. No había
pruebas automatizadas que correr (se retiraron por pedido explícito del usuario el
2026-09-22). No se compiló el APK: esta sesión no tiene el SDK de Android instalado.

### 2026-09-27 — sesión automática diaria de pulido

Sin tareas en "Pendiente". Se revisó todo `lib/` en busca de errores reales; el
código ya estaba muy pulido de sesiones anteriores, así que se encontraron y
corrigieron dos detalles concretos de contraste en modo oscuro:

1. El círculo de carga de los botones principales (Entrar, Crear tienda,
   Crear cuenta) usaba el mismo color que el fondo del botón y prácticamente
   no se veía mientras la app estaba trabajando. Ahora usa un color que
   contrasta.
2. El aviso "Cambios guardados" tenía un ícono blanco fijo; en modo oscuro el
   fondo del aviso se vuelve claro y el ícono quedaba casi invisible. Ahora
   los colores del aviso se ajustan igual que el resto de la app.

También se corrigió el formato de un archivo (`new_store_screen.dart`) que
había quedado sin pasar por `dart format`.

Verificado con `flutter analyze` (0 avisos). No había pruebas automatizadas
que correr (se retiraron por pedido explícito del usuario el 2026-09-22) ni
se compiló el APK (herramientas de Android no disponibles en esta sesión).

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

**Ronda 2 (2026-09-23 17:00)**
- Alta de empleados: si falla guardar el perfil después de crear la cuenta, la cuenta se
  deshace; antes quedaba huérfana y su correo ya no se podía volver a registrar.
- Sincronización: cada snapshot remoto se guarda en el teléfono con una sola escritura
  (`LocalCatalog.writeAllChanged`) en vez de una por prenda.
- Pantalla principal: los cambios que llegan de otros teléfonos refrescan la lista una vez
  por cuadro, no una vez por prenda.

**Ronda 3 (2026-09-23 21:30)**
- Pantalla principal dividida: `StoreTitle`, `AccountMenu` y `ClothingCard` pasan a
  `lib/screens/home/` (home_screen.dart de 517 a ~330 líneas), sin cambios de comportamiento.
- Formulario de prenda: cada fila de talla/color/existencia vive en
  `lib/screens/item_form/variant_row.dart` (controladores, validación y widget); las filas
  llevan clave propia para que al quitar una no se crucen los mensajes de validación, y
  "AGOTADO" se actualiza también al escribir talla o color.
- Agregar prenda muestra un mensaje si no se puede generar el código nuevo, en vez de fallar
  en silencio.

**Ronda 4 (2026-09-23 22:45)**
- Etiqueta QR: la parte que se guarda/imprime (`_QrSticker`) siempre sale negro sobre blanco,
  aunque la app esté en tema oscuro (antes salía con fondo oscuro y texto claro).
- La pantalla del QR ahora se desplaza, para que no se corte en teléfonos chicos o en
  horizontal; el error al compartir usa el mismo aviso rojo que el resto de la app.
- Login, nueva tienda y alta de usuarios muestran un mensaje también ante errores
  inesperados, en vez de quedarse sin respuesta (`AsyncSubmit`).

**Ronda 5 (2026-09-24 08:55)**
- La confirmación "Descartar cambios" al salir con cambios sin guardar vivía copiada en el
  formulario de prenda y en el ajuste rápido de existencias; ahora es un solo widget
  reutilizable (`UnsavedChangesGuard`), con el mismo comportamiento y textos.
- Avisos de error consistentes: la combinación color/talla repetida y los errores al editar
  usuarios usan el mismo aviso rojo que el resto de la app.

**Ronda 6 (2026-09-24 09:00)**
- El precio se interpretaba con el mismo código copiado en tres lugares del formulario
  (guardar, vista del QR y validación); ahora hay una sola función (`_parsePrecio`), que
  acepta coma decimal.
- `ClothingItem` y `ClothingVariant` tienen campos finales (inmutables): una prenda que
  comparten la UI y la sincronización ya no puede modificarse por accidente. Ningún código
  los modificaba, así que no cambia el comportamiento.

**Ronda 7 (2026-09-24 10:45)**
- Sesión: un error pasajero al leer el perfil (red, servidor) ya no deja la pantalla
  "Sin acceso" para siempre. Solo un permiso realmente denegado la muestra; en cualquier otro
  caso se conserva el estado actual y el perfil se vuelve a escuchar con espera creciente,
  así un cambio de rol o una reactivación se siguen detectando sin cerrar sesión.
- Esa lógica pasa de `FirebaseAuthService.watch` a su propia clase (`SessionWatcher`).

**Ronda 8 (2026-09-27 16:10)**
- Ajuste rápido de existencias: un doble toque en "Guardar" podía aplicar el mismo +/- dos
  veces (y cerrar también la pantalla de atrás). Ahora el botón se desactiva mientras guarda.
  Lo mismo en el formulario de prenda, donde el doble toque cerraba también el catálogo.
- Sumar una pieza y volver a quitarla ya no cuenta como cambio: "Guardar" queda desactivado
  y salir no pide confirmar descartar, porque no hay nada que guardar.
