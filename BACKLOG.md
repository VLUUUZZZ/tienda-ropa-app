# Backlog

Agrega aquí las tareas que quieres que se trabajen en la sesión automática diaria (7:00 am). Reglas:

1. La sesión diaria toma las tareas de "Pendiente", de arriba hacia abajo.
2. Si no hay ninguna pendiente, se dedica a pulir lo que ya existe (bugs, UI/UX, rendimiento, pruebas) — sin agregar funciones nuevas grandes por su cuenta.
3. Cada tarea completada se mueve a "Completado" con la fecha y el commit correspondiente.
4. Todo cambio se compila y se prueba antes de darse por terminado (`flutter analyze` sin avisos).
5. **Ramas — solo existen dos:**
   - `develop` = **preproducción**: donde se trabaja y se prueba. Toda sesión (diaria o manual) empieza con `git pull origin develop`, revisa este archivo y el código para confirmar que la tarea no está hecha, y sube cada tarea terminada a `develop` de inmediato.
   - `master` = **producción**: lo que se despliega. Nadie escribe en `master` directamente; solo recibe `develop` mediante un pull request `develop → master`, después de que el dueño lo pruebe.
   - No crear otras ramas. Nunca usar `git push --force` ni reescribir historia: si el push es rechazado, `git pull` (merge), resolver, volver a verificar y subir.
6. Commits sin firmas de IA (sin `Co-Authored-By` ni menciones a Claude): el dueño quiere solo su nombre en el historial.
7. Si en algún momento se necesita una base de datos remota/backend, debe ser Firebase (acordado con el usuario el 2026-09-22).

## Pendiente

1. Categorías o tipos de prenda (solo si el catálogo crece mucho).
2. Sincronizar las fotos de las prendas entre teléfonos (hoy son solo locales; requiere habilitar Firebase Storage en el proyecto — pedir al dueño que lo active en la consola de Firebase antes de implementarlo).
3. Revisar con más calma, junto al dueño, el caso (raro) de dos teléfonos sin internet creando prendas distintas que puedan terminar compartiendo código — ver nota técnica en la ronda (2) del 2026-10-02.
4. [encontrado el 2026-10-07, bajo riesgo] Las reglas de Firestore (`firestore.rules`, regla de
   `update` de `prendas` para empleados) solo verifican que la cantidad de combinaciones
   color/talla no cambie, no que sigan siendo las mismas combinaciones. En teoría, alguien
   con una cuenta de Empleado podría usar la API de Firestore directamente (no la app) para
   renombrar un color o talla existente sin pasar por el formulario de administrador. No es
   algo que se pueda hacer desde la app normal, solo manipulando la base de datos a mano.
   Corregirlo bien requeriría cambiar cómo se guardan las variantes en Firestore (de lista a
   algo indexable por color+talla), un cambio de estructura de datos más grande que conviene
   pensar con calma y probar contra el Firebase real, no intentarlo a ciegas.
5. [encontrado el 2026-10-07, bajo riesgo] El código de barras de proveedor de una prenda
   (`codigoProveedor`) solo se revisa como "ya usado por otra prenda" contra lo que hay
   guardado en el teléfono en ese momento, no contra el servidor. Dos administradores en
   teléfonos distintos (o uno mismo trabajando sin conexión) podrían, en teoría, asignar el
   mismo código a dos prendas distintas sin que ninguno de los dos se entere; al escanear
   ese código luego, solo encuentra la primera. Corregirlo de verdad requiere una estructura
   nueva en Firestore para reservar códigos de forma atómica — se deja pendiente por el mismo
   motivo que el punto 4.
6. [encontrado el 2026-10-07, menor] En una venta, si dos teléfonos venden la última pieza de
   la misma combinación color/talla casi al mismo tiempo, el número real de existencia en el
   servidor queda correcto (nunca baja de 0, gracias a la corrección de hoy), pero el
   historial de esa venta en particular podría registrar más piezas de las que realmente
   había disponibles en ese instante preciso. Es una ventana de coincidencia muy angosta y de
   bajo impacto (el dinero cobrado sigue siendo el correcto); se deja documentado en vez de
   corregido por ahora.

## Completado

### 2026-10-08 — auditoría de usabilidad de todas las pantallas

Meta: que un empleado nuevo pueda usar la app sin que nadie le explique. Sin funciones nuevas
grandes; solo se hicieron más claras las que ya existían.
- **Catálogo:** cada tarjeta muestra botones con texto, *Vender* y *Existencia*, en lugar de
  iconos sueltos. El botón *Ventas* lleva texto. *Agregar* es un botón con nombre. El tema
  claro/oscuro se movió al menú de la cuenta, y cada opción del menú dice para qué sirve. Si no
  hay resultados o un filtro deja la lista vacía, aparece un botón para quitar la búsqueda o
  el filtro.
- **Sin conexión:** un aviso dice cuántos cambios están guardados solo en este teléfono y que
  se enviarán solos al volver internet. Cuando se envían, aparece "Todo sincronizado".
- **Escanear:** el teléfono vibra al leer. Si la etiqueta no se lee, se puede escribir el código.
  Al encontrar la prenda se ofrece *Vender*, *Ajustar existencia*, *Editar ficha* (solo
  administradores) o *Escanear otra*; esto aplica también a los empleados, que antes solo
  podían ajustar. Un código desconocido se explica, y un administrador puede agregar la prenda
  con el código del proveedor ya puesto.
- **Ajustar existencia y vender:** cada fila dice "Talla M", muestra "Había 6 → ahora 7" y
  avisa con icono y texto "Quedan pocas" o "Agotado". El botón de guardar dice lo que va a
  pasar ("Guardar: salen 2 piezas"). Para lectores de pantalla, cada botón nombra el color y
  la talla. Vender se ve igual que ajustar, con foto, precio por pieza y total.
- **Formularios:** los campos obligatorios llevan *. Cada error dice cómo corregirlo (por
  ejemplo, "El precio debe ser mayor a $0" o "Falta la talla"). Si falta algo, un aviso pide
  revisar los campos en rojo. En una prenda sin cambios, el botón dice "Sin cambios por
  guardar". Hay una explicación de tallas y colores y un botón para agregar otra fila al
  final. La foto aclara que se guarda solo en este teléfono.
- **Inicio de sesión:** aclara que un empleado no crea tienda, sino que pide su cuenta al
  administrador. La pantalla de carga dice qué está pasando. Los errores de conexión explican
  qué hacer.
- **Ventas, historial y usuarios:** se usan los mismos estados vacíos, precios con formato
  ($1,250.00) y fechas tipo "Hoy, 14:05". El historial indica con flecha y palabra si las
  piezas entraron o salieron. Los empleados ya no ven el valor del inventario en Ventas, igual
  que en el catálogo. En Usuarios, tu propia cuenta explica por qué no se puede editar.

### 2026-10-08 — todo junto en `develop`; solo quedan `develop` y `master`

A pedido del dueño, se juntó todo el trabajo en una sola rama de preproducción, `develop`:
la rama diaria `auto/mejoras-diarias` (PR #3: ventas, fotos, exportar CSV, código de
proveedor, historial de ajustes, códigos sin conexión y sus correcciones) y la rama
`claude/como-ves-la-app-g73nn7` (PR #1: interfaz moderna, robustez, revisión de errores,
mensajes/confirmaciones/pantallas de éxito). En los 19 archivos con conflicto se conservaron
las funciones de ambos lados; donde las dos resolvieron lo mismo quedó una sola versión (por
ejemplo, la generación de códigos y la cola de envíos de la rama diaria; el diseño y los
componentes de feedback de la otra). Ventas y ajustes que no se aplican completos ahora se
anuncian en el catálogo en vez de retrasar 3 s la salida. Se eliminaron las ramas viejas.
`master` (producción) no se tocó: recibe `develop` por pull request cuando el dueño lo pruebe.

### 2026-10-08 — mensajes, confirmaciones y pantallas de éxito (rama `claude/como-ves-la-app-g73nn7`)

Pedido del usuario: componentes de feedback y confirmación, y una descripción completa de la
app (sin generar APK). Verificado con `flutter analyze`, `flutter build web`, 50 pruebas
(incluye componentes de feedback) y 28 de reglas, en copia aparte; revisión de código del
cambio con sus 10 hallazgos corregidos.

- `lib/widgets/feedback/`:
  - `AppSnackBar`: éxito, error, información y deshacer, con ícono, color y vibración. Un
    aviso nuevo reemplaza al anterior, salvo un "Deshacer" pendiente, que nunca se corta.
    Si la pantalla ya se cerró, el aviso sale igual (con el tema de la app).
  - `confirmAction` / `showNotice`: diálogos estándar; acciones irreversibles en rojo.
  - `showSuccess` / `SuccessScreen`: pantalla de éxito con animación (respeta "reducir
    movimiento"), resumen de lo creado y siguientes pasos.
- Confirmaciones: eliminar prenda (nombrándola), quitar una talla guardada que aún tiene
  piezas, descartar cambios, ajustar existencia con cambios sin guardar (ahora ofrece
  descartarlos en vez de mostrar un error), cerrar sesión, desactivar/reactivar o cambiar
  el rol de alguien (explicando cada consecuencia).
- Pantallas de éxito: prenda creada (imprimir etiqueta QR / agregar otra), tienda creada
  (bienvenida), cuenta de empleado creada (listo / crear otra).
- Todos los avisos y diálogos sueltos se pasaron a estos componentes (se eliminó
  `widgets/snackbars.dart`).
- `README.md` reescrito con la descripción completa de la app: para quién es, cómo se usa,
  pantallas, mensajes, cómo funciona por dentro, datos y estructura del código.

### 2026-10-08 — revisión completa y corrección de errores (rama `claude/como-ves-la-app-g73nn7`)

Dos revisiones de código a fondo (cambios de la rama, y sesión/usuarios/sincronización).
Verificado con `flutter analyze` (0 avisos), `flutter build web`, 44 pruebas de
lógica/sincronización/formulario/capturas y 28 de reglas en el emulador (copia aparte).
No se pudo generar APK: la red del entorno bloquea las descargas del SDK de Android.

Errores corregidos:
1. **Ajustes de empleados que se perdían**: al leer una prenda se "limpiaban" nombre y
   precio (espacios, redondeo); al guardar existencia el documento cambiaba también esos
   campos, el servidor lo rechazaba y el ajuste se descartaba. Ahora los valores válidos se
   leen y se escriben tal cual.
2. **QR de prenda nueva antes de guardar**: podía imprimirse con un código que cambiaba al
   guardar. Ahora el QR se ofrece después de guardar ("Ver QR" en el aviso de creada).
3. **Variantes con y sin acento** ("Café"/"Cafe") se mezclaban en el ajuste de existencia.
   Vuelven a ser variantes distintas, como antes.
4. **Códigos con espacios** dejaban de verse; ahora se aceptan (solo se rechaza lo que
   Hive no puede guardar: acentos o más de 255 caracteres).
5. **Nombres/colores largos ya guardados** se recortaban al editarlos. Ya no se recortan;
   el límite solo impide que crezcan.
6. Un número guardado como "NaN"/"Infinity" hacía desaparecer la prenda.
7. Sincronización: cada guardado provocaba releer y comparar todo el catálogo dos veces;
   ahora solo se procesan avisos con cambios reales.
8. Sincronización: un cambio pendiente podía enviarse varias veces a la vez (al iniciar,
   al primer contacto y al reconectar). Ahora se envía una sola vez.
9. Cerrar sesión con un envío en curso podía dejar un error sin controlar.
10. Sesión: un perfil inexistente ya guardado en caché dejaba la app cargando para
    siempre; ahora muestra "Sin acceso".
11. Si cambia el rol del usuario con pantallas abiertas, se cierran (ya no queda abierto
    un formulario de admin para alguien que pasó a empleado).
12. Abrir la tienda dos veces seguidas (salir y entrar rápido) podía dejar dos
    sincronizaciones sobre el mismo almacenamiento.
13. Formularios de sesión/usuarios: Enter dos veces enviaba dos veces (dos cuentas o dos
    tiendas); y un error podía perderse si la pantalla se cerraba antes.
14. Desactivar a un usuario sin nombre fallaba con "No tienes permiso"; ahora se guarda.
15. Muestras de color: "Verde oliva" y "Azul mezclilla" mostraban verde y azul genéricos.
16. Detalles: aviso de error del QR con el estilo de error de la app, mensaje de
    contraseña débil tomado de la misma constante que el formulario, búsqueda de código
    existente sin recorrer todo el catálogo.

Pulido: pantalla de usuarios con avatar de iniciales y etiqueta "Desactivado";
"Guardar cambios" de la hoja de usuario solo se activa si hay cambios.

### 2026-10-08 — interfaz modernizada (rama `claude/como-ves-la-app-g73nn7`)

Pedido del usuario: modernizar la UI. Verificado con `flutter analyze`, `flutter build web`,
41 pruebas (lógica, sincronización, formulario y capturas en claro/oscuro, en copia aparte).

- Tipografía **Plus Jakarta Sans** incluida en la app (`assets/fonts/`, licencia SIL OFL 1.1
  en `assets/fonts/OFL.txt`, registrada en la página de licencias); no depende de internet.
- Tema: esquinas más amplias (`Radii`), botones en píldora, campos con borde fino, barra de
  búsqueda M3, avisos y menús redondeados, transiciones de pantalla modernas (Android:
  fade-forwards; iOS: deslizamiento nativo).
- Pantalla principal: saludo + nombre de la tienda + avatar con iniciales (menú de
  cuenta); buscador en píldora; tarjeta destacada con el valor del inventario y una fila
  de prendas/piezas/agotadas; filtros en píldora con conteo; tarjetas con avatar de
  iniciales, precio destacado, código, insignia de existencia y colores superpuestos;
  estado vacío con explicación y botón "Agregar prenda".
- Ajuste rápido: encabezado con la prenda y el total (marca lo que está sin guardar),
  control "− número +" en píldora con vibración al tocar y número animado, botón
  "Guardar cambios" fijo abajo.
- Ficha de prenda: código como chip (abre el QR), secciones "Información" y "Tallas y
  colores", muestra del color dentro del campo, "Agotado" por fila, opciones de
  ajustar/eliminar en el menú ⋮, botón de guardar fijo abajo.
- Escáner: marco de enfoque con esquinas y la indicación "Apunta al código QR de la
  etiqueta" (la detección sigue usando toda la imagen, que es más confiable).
- Inicio de sesión y tienda nueva: marca de la app en mosaico terracota y títulos grandes.

### 2026-10-08 — integración de `master` (Rondas 2–8)

Las Rondas 2–8 se subieron a `master` mientras el PR #1 seguía abierto, así que ambos lados
resolvieron cosas iguales por separado (doble toque en Guardar, etiqueta QR imprimible,
cuentas huérfanas, precio con coma). Se integró `master` en la rama del PR #1 tomando la
estructura de `master` (modelo inmutable, `SessionWatcher`, `UnsavedChangesGuard`,
pantallas divididas en `screens/home/` y `screens/item_form/`) y conservando lo de la rama
(lectura tolerante y límites, no pisar ventas de otros teléfonos, precio flexible, resumen
y filtros, sincronización tolerante a datos malos con escritura en lote). Verificado con
`flutter analyze`, `flutter build web` y 27 pruebas (en copia aparte).

### 2026-10-08 (1) — sesión de pulido diaria

No había tareas pendientes, así que la sesión revisó a fondo el código ya existente
(incluyendo con ayuda de una revisión automática enfocada en la capa de sincronización) en
busca de errores reales, no de funciones nuevas.

1. Al resolver dos prendas creadas con el mismo código por dos teléfonos sin internet (caso
   descrito en el punto 3 de "Pendiente"), la prenda que pasaba a un código nuevo perdía su
   foto: quedaba guardada bajo el código viejo, que ya no existía en el catálogo, y la
   limpieza automática de fotos huérfanas la borraba la próxima vez que se abría la app.
   Ahora la foto se mueve junto con la prenda a su nuevo código.
2. Si la lista de "Usuarios" fallaba al cargar (por ejemplo, justo después de iniciar
   sesión, antes de que el servidor reconociera el permiso), se quedaba mostrando "No se
   pudo cargar la lista." para siempre, sin forma de reintentar salvo salir y volver a
   entrar a la pantalla. Ahora tiene un botón "Reintentar".
3. Ajuste rápido de existencia: si otra persona vendía o ajustaba la misma combinación
   color/talla justo antes de guardar, el servidor nunca deja bajar la existencia de cero,
   pero el historial de ajustes seguía registrando el número que se había tocado en pantalla,
   no el que realmente se aplicó. Ahora el historial registra el cambio real, y se avisa en
   pantalla cuando el número aplicado terminó siendo menor al pedido.
4. [el más importante de hoy] Al guardar el formulario completo de una prenda (por ejemplo
   para corregir el precio o el nombre), la existencia de cada talla/color se guardaba tal
   como se veía en pantalla cuando se abrió el formulario. Si alguien vendía esa prenda o le
   ajustaba la existencia en otro teléfono mientras el formulario seguía abierto en el
   primero, "Guardar" deshacía ese cambio en silencio, sin aviso ni rastro — la venta seguía
   registrada, pero la existencia volvía al número de antes. Ahora, la talla/color que no se
   tocó en el formulario conserva la existencia más reciente en vez de la que se veía al
   abrir; la que sí se editó a mano sigue aplicando exactamente ese cambio, pero sobre el
   número más reciente.

Verificado con flutter analyze (0 avisos).

### 2026-10-07 (4), a pedido del dueño — "Robustece el código" (continuación)

Cuarta ronda de la misma tarea, revisando el arranque de la app, el guardado local y las
pantallas de edición:

1. **Corregido un caso real de pérdida de datos al crear una prenda:** si justo después de
   crear una prenda nueva se le hacía un segundo cambio muy rápido (por ejemplo, corregir
   el nombre a los pocos segundos, antes de que el primer guardado terminara de subirse),
   los dos guardados podían chocar entre sí al sincronizar y el segundo cambio podía
   perderse, quedando la prenda con un código distinto y solo la versión vieja. Ahora los
   guardados de una misma prenda siempre se suben de a uno, en orden, así que esto ya no
   puede pasar.
2. Al editar una prenda o hacer un ajuste rápido de existencia, salir con el botón de
   regresar mientras se está guardando ya no ofrece "Descartar cambios" (lo cual sería
   engañoso, porque el guardado sigue en curso de todas formas); ahora avisa que hay que
   esperar, igual que ya pasaba en Registrar venta.
3. Si fallaba borrar la foto de una prenda eliminada (por ejemplo, el teléfono estaba
   ocupado en ese instante), antes la app daba por hecho que ya se había borrado y nunca
   lo volvía a intentar, dejando el archivo ocupando espacio para siempre. Ahora se
   reintenta en el siguiente inicio si la primera vez no se pudo.
4. Si el contador interno usado para generar los códigos de las prendas nuevas
   (PRENDA-000001, etc.) se corrompía por algún motivo raro, antes la app dejaba de poder
   crear prendas nuevas por completo. Ahora, en ese caso, simplemente empieza a contar de
   nuevo en vez de fallar.
5. Si falla guardar la preferencia de tema claro/oscuro (muy raro), ahora queda un rastro
   en el registro técnico en vez de fallar en silencio sin ninguna pista.

Verificado con `flutter analyze` (0 avisos) y `dart format`.

### 2026-10-07 (3), a pedido del dueño — "Robustece el código" (continuación)

Más robustez encontrada revisando el código a fondo, en la misma sesión que el punto (2):

1. **Corregido un error en la corrección de hoy mismo:** si la venta se aplicaba bien en el
   servidor pero fallaba al guardarse en el teléfono justo después (por ejemplo, el teléfono
   se quedó sin espacio en ese instante), antes se volvía a aplicar el descuento de
   existencia por segunda vez y se subía de nuevo al servidor, duplicando el descuento. Ahora
   ese caso (muy raro) ya no duplica nada: si el servidor ya confirmó el cambio, se usa ese
   resultado tal cual, y si guardarlo localmente falla, se reintentará solo guardarlo (no
   recalcular) la próxima vez que llegue una actualización.
2. **Ventas y ajustes de existencia rechazados por el servidor ya no se pierden en
   silencio.** Antes, si el servidor rechazaba subir una venta o un ajuste (por ejemplo justo
   después de iniciar sesión, antes de que el servidor reconozca los permisos), ese registro
   se descartaba para siempre sin ningún aviso: quedaba solo en ese teléfono, nunca en el
   respaldo. Ahora se reintenta en vez de descartarse — no hay forma de "recuperar" ese
   registro desde el servidor como sí la hay para una prenda, así que perderlo en silencio
   era peor que seguir intentando.
3. El historial de ajustes de existencia (quién cambió qué) ahora exige, también del lado del
   servidor, que el nombre registrado sea el de quien realmente inició sesión — antes solo se
   verificaba en la app, así que alguien manipulando la base de datos directamente podría en
   teoría haber firmado un ajuste con el nombre de otra persona.
4. En editar prenda, el botón "Guardar" también se desactiva mientras se está eliminando la
   prenda (antes solo se desactivaba mientras se estaba guardando), para que no puedan correr
   los dos a la vez.
5. Las fotos de prenda se guardan en una resolución más chica (antes se guardaba la foto a la
   resolución completa de la cámara, aunque en la app nunca se muestra más grande que una
   miniatura); ahorra espacio en el teléfono y hace que la lista cargue más rápido en
   teléfonos de gama baja.

Verificado con `flutter analyze` (0 avisos) y `dart format`. No había pruebas automatizadas
que correr. No se pudo probar el cambio de reglas de Firestore ni el de ventas/ajustes
rechazados contra un proyecto de Firebase real desde esta sesión.

### 2026-10-07 (2), a pedido del dueño — "Robustece el código"

Se corrigió el problema [IMPORTANTE] que había quedado documentado en "Pendiente" tras
la ronda anterior del mismo día: si dos empleados vendían piezas de la misma prenda casi
al mismo tiempo desde dos teléfonos distintos, una de las rebajas de existencia podía
perderse (la venta quedaba bien registrada, pero el conteo de piezas disponibles podía
quedar más alto de lo real).

Se corrigió de la forma recomendada: ahora, cuando el teléfono tiene conexión, una venta
o un ajuste rápido de existencia se aplica directamente en el servidor como una
operación atómica ("réstale X a lo que haya en este momento"), en vez de que cada
teléfono calcule el nuevo número por su cuenta y lo sobrescriba. Así, si dos ventas
llegan casi juntas, las dos rebajas se aplican correctamente sobre el valor real, en vez
de que la segunda borre el efecto de la primera. Si el teléfono está sin conexión, el
cambio se guarda localmente y se sincroniza después, como ya funcionaba antes (ese caso
sin conexión simultánea en dos teléfonos sigue siendo una posibilidad remota, igual que
otros casos ya documentados en "Pendiente").

No se tocaron las reglas de Firestore (`firestore.rules`): ya permitían este tipo de
cambio parcial para empleados, sin necesitar ningún ajuste.

Verificado con `flutter analyze` (0 avisos) y revisión manual del flujo (sin acceso a un
proyecto de Firebase real desde esta sesión para probarlo en vivo contra el servidor;
revísalo con una venta de prueba desde dos teléfonos cuando puedas).

### 2026-10-07 — sesión automática diaria de pulido

Las tareas de "Pendiente" seguían bloqueadas (necesitan algo del dueño primero o son
condicionales), así que la sesión se dedicó a revisar a fondo el código en busca de
errores reales. Se encontraron y corrigieron 15 problemas; el más serio de los
encontrados (ventas simultáneas desde dos teléfonos, ver punto 1 de "Pendiente" arriba)
quedó documentado ahí en vez de corregirse a ciegas, por su riesgo y por no poder
probarse contra el Firebase real desde esta sesión.

1. Un empleado ya no puede exportar el catálogo completo (precios y códigos de
   proveedor) desde el menú de Cuenta: esa opción solo aparecía para Administradores en
   la intención original, pero por un descuido estaba visible y funcionando para
   cualquier cuenta.
2. En editar prenda, los botones de ajuste rápido, código QR y eliminar se desactivan
   mientras se está guardando o eliminando, para que no puedan correr al mismo tiempo y
   dejar la prenda en un estado contradictorio.
3. Un doble toque rápido en "Eliminar" (pantalla de prenda) ya no abre dos diálogos de
   confirmación a la vez.
4. Si se quita una combinación de color/talla que tenía existencia (en vez de solo
   poner su existencia en 0 y dejarla), ahora queda registrada en el historial de
   ajustes como una salida de esas piezas, en vez de desaparecer sin dejar rastro.
5. Si falla quitar una foto guardada en el teléfono, ya no se muestra "sin foto" de
   todas formas: se avisa del error y la foto se mantiene hasta poder intentarlo de
   nuevo.
6. En la lista principal, si el archivo de la foto de una prenda ya no se puede abrir
   (se movió de teléfono, se dañó), se muestra el ícono genérico de ropa en vez de un
   círculo vacío sin explicación.
7. Corregido un caso donde guardar o eliminar una prenda, justo cuando llega al mismo
   tiempo una actualización desde otro teléfono, podía perder el cambio recién hecho sin
   ningún aviso.
8. Al registrar una venta: ya no se puede salir de la pantalla a medio camino creyendo
   que se "descartó" cuando en realidad ya se estaba guardando; ahora se avisa que hay
   que esperar a que termine.
9. El botón "Registrar venta" muestra un círculo de carga mientras se guarda, igual que
   los demás botones de guardar en la app.
10. Si falla registrar una venta justo después de descontar la existencia, reintentar
    ya no descuenta la existencia dos veces ni duplica las ventas ya registradas
    correctamente en el primer intento.
11. Vender varias tallas/colores con el mismo nombre normalizado en una sola venta ya
    no pierde ni duplica por error la rebaja de existencia de alguna de ellas.
12. "Más vendidos" (en los reportes de ventas) ahora desempata siempre por la venta más
    reciente de forma consistente, como ya decía que hacía.
13. Dar de alta dos cuentas de empleado casi al mismo tiempo ya no puede chocar entre
    sí con un error interno confuso.
14. La descripción del rol "Empleado" al crear un usuario ahora menciona que también
    puede registrar ventas (antes solo decía "consultar, escanear y ajustar
    existencias", lo cual podía confundir al dueño sobre qué puede hacer esa cuenta).
15. Limpieza menor: una prenda nueva que se empieza a crear pero nunca se guarda ya no
    deja un registro interno "pendiente" abandonado para siempre.

Verificado con `flutter analyze` (0 avisos) y `dart format` (sin cambios pendientes). No
hay pruebas automatizadas que correr (se retiraron por pedido explícito del dueño el
2026-09-22) ni se compiló el APK (sin SDK de Android en este entorno).

### 2026-10-06 — sesión automática diaria de pulido

Las 3 tareas de "Pendiente" siguen bloqueadas (necesitan algo del dueño primero o son
condicionales). Se revisó a fondo el código en busca de errores reales, inconsistencias
de UI/UX y manejo de errores; se encontraron y corrigieron 4 detalles pequeños:

1. La etiqueta roja "AGOTADO" en la tarjeta de la lista principal tenía el texto con el
   color gris por defecto (poco legible sobre el fondo rojo claro) en vez del color
   correcto; ahora usa el mismo color que el aviso de "pocas piezas" junto a ella.
2. En el menú de Cuenta, un nombre o correo muy largo ya no se corta a la mitad ni se
   envuelve mal en pantallas angostas.
3. Si en Firestore el campo de rol de un usuario llega con un valor que la app no
   reconoce (por ejemplo editado a mano), antes se degradaba a Empleado en silencio;
   ahora además queda un registro para poder detectarlo.
4. Corregido un caso raro donde, si se cerraba sesión justo cuando se descartaba un
   cambio de existencia rechazado por el servidor, podía generarse un error interno sin
   capturar (no visible para quien usa la app, pero quedaba ruido en los registros).

Verificado con `flutter analyze` (0 avisos) y `dart format` (sin cambios pendientes). No
hay pruebas automatizadas que correr (se retiraron por pedido explícito del dueño el
2026-09-22) ni se compiló el APK (sin SDK de Android en este entorno).

### 2026-10-05 — sesión automática diaria de pulido

Las 3 tareas de "Pendiente" siguen bloqueadas (necesitan algo del dueño primero o son
condicionales). Se revisó a fondo el código (pantallas, capa de datos, modelo de
autenticación) y se encontraron 2 errores reales, pequeños y ya corregidos:

1. Si una prenda llegaba del servidor con una existencia inválida (negativa, por un dato
   corrupto o editado a mano), se mostraba un número en negativo en vez de 0 — ahora se
   corrige al leerla, igual que en el resto de la app.
2. Al escanear un código QR o de proveedor, si la pantalla del escáner se cerraba justo en el
   instante de leer el código, podía aparecer un error técnico en pantalla; ahora esa lectura
   simplemente se ignora.

**Ronda 2 (a pedido del dueño, "corrige y pule el código"):** revisión más profunda de la
sincronización, la foto por prenda, las ventas y el código de proveedor. 4 errores reales
corregidos:

3. Al eliminar una prenda con foto, la foto se quedaba guardada en el teléfono para siempre
   (un desperdicio de espacio que solo crece). Ahora se borran las fotos de prendas eliminadas
   cada vez que se abre el catálogo (no de inmediato, para no perderla si se usa "Deshacer").
4. Al cambiar la foto de una prenda, la miniatura en la lista y en el formulario seguían
   mostrando la foto anterior hasta reiniciar la app. Ahora se actualiza al instante.
5. Al registrar una venta, si la existencia había cambiado en otro teléfono justo antes de
   confirmar, se vendían menos piezas de las pedidas sin avisarlo — solo decía "Venta
   registrada" igual. Ahora avisa cuántas piezas se registraron realmente si fueron menos.
6. Dos prendas distintas podían terminar con el mismo código de proveedor escaneado (por
   error), y entonces escanear ese código desde la pantalla principal siempre encontraba la
   primera, ocultando la segunda. Ahora se avisa al guardar si el código ya está en otra
   prenda.

Verificado con `flutter analyze` (0 avisos) y `dart format` en todo `lib/` (sin cambios
pendientes). No hay pruebas automatizadas que correr (se retiraron por pedido explícito del
usuario el 2026-09-22). No se compiló el APK: esta sesión no tiene el SDK de Android
instalado, solo Flutter.

### 2026-10-04 — sesión automática diaria de pulido

Las 3 tareas de "Pendiente" siguen bloqueadas (necesitan algo del dueño primero o son
condicionales), igual que ayer, así que se revisó a fondo el código en busca de errores
reales: pantallas (catálogo, formulario de prenda, ajuste rápido, ventas, historial de
ajustes, QR, escáner, usuarios, login), la capa de datos (sincronización de catálogo,
ventas y ajustes, almacenamiento local, fotos) y el modelo de autenticación. No se encontró
ningún bug nuevo: las rondas anteriores ya cubrieron los casos delicados (doble toque,
sincronización entre teléfonos, roles, mensajes de error, setState tras cerrar sesión,
contraste de colores) y el código sigue igual de sólido hoy. Por eso no se tocó ningún
archivo de código esta sesión, para no arriesgar cambios sin un problema real que corregir.

Verificado con `flutter analyze` (0 avisos) y `dart format` en todo `lib/` (sin cambios
pendientes). No hay pruebas automatizadas que correr (se retiraron por pedido explícito del
usuario el 2026-09-22). No se compiló el APK: esta sesión no tiene el SDK de Android
instalado, solo Flutter.

Nota: el Pull Request #3 (`auto/mejoras-diarias` → `master`) sigue abierto y acumulando las
sesiones diarias desde el 2026-09-28; no se abrió uno nuevo. Para que las ventas y el
historial de ajustes sincronicen en producción, falta desplegar las reglas de Firestore
actualizadas (`firebase deploy --only firestore:rules`) una vez que el dueño revise y
mergee el PR.

### 2026-10-03 — sesión automática diaria, 4 tareas de "Pendiente"

Se tomaron 4 de las 7 tareas que había en "Pendiente", de arriba hacia abajo.
Las otras 3 quedan arriba porque necesitan algo del dueño primero (activar
Firebase Storage, o revisar con calma un caso delicado de sincronización) o
son condicionales ("solo si el catálogo crece mucho").

1. **Filtro rápido de existencia**: chips "Todos / Agotado / Stock bajo"
   arriba del catálogo, junto a la búsqueda por nombre, usando los mismos
   indicadores que ya mostraba cada tarjeta.
2. **Historial de ajustes**: nueva sección "Historial de ajustes" (solo
   para administradores, en Cuenta) que registra quién cambió cuánta
   existencia de qué prenda y cuándo — tanto desde el ajuste rápido como
   desde el formulario completo. Se guarda igual que las ventas (en el
   teléfono y sincronizado entre teléfonos), nunca se edita ni se borra.
3. **Código de barras de proveedor**: cada prenda puede guardar el código
   de barras que el proveedor ya le puso (opcional, con botón para
   escanearlo en el formulario). Al escanear desde la pantalla principal,
   si el código no es el QR propio de la app, ahora también se busca entre
   esos códigos de proveedor antes de avisar "Código no reconocido".
4. **Reportes más completos**: la pantalla de Ventas ahora también muestra
   el total vendido en la semana y en el mes en curso, lo más vendido (top
   5 prendas) y el valor actual de todo el inventario (precio x existencia).

Verificado con `flutter analyze` (0 avisos) y `dart format` en todo `lib/`.
No hay carpeta `test/` (se retiraron por pedido explícito del usuario el
2026-09-22). No se compiló el APK: esta sesión automática no tiene el SDK
de Android instalado, solo Flutter.

Importante: el historial de ajustes agrega una colección nueva en
Firestore (`tiendas/{id}/ajustes`) y `firestore.rules` se actualizó para
permitirla. Hace falta desplegar las reglas nuevas
(`firebase deploy --only firestore:rules`, o pegarlas en la consola de
Firebase) para que esa parte funcione en los teléfonos reales — el resto
de lo hecho hoy no depende de eso.

### 2026-10-02 (2) — a pedido del dueño: bugs críticos e funciones nuevas

El dueño pidió una lista priorizada de bugs y mejoras, y que se trabajara de
una vez lo crítico y lo importante (lo demás quedó arriba, en "Pendiente").
Se hizo todo en la misma sesión:

1. **Bug crítico de sincronización**: dos empleados sin señal podían crear
   cada uno una prenda nueva y, por mala suerte, que ambas calcularan el
   mismo código (ej. ambas "PRENDA-000011"). Al volver a tener señal, una de
   las dos se sobrescribía en silencio y desaparecía del catálogo sin ningún
   aviso. Ahora, al subir una prenda nueva por primera vez, la app verifica
   que nadie más haya tomado ya ese código; si alguien más lo tomó mientras
   ambas estaban sin señal, esta prenda recibe un código distinto en vez de
   perderse. Las ediciones normales a prendas que ya existían no cambiaron
   en nada.
2. **Registro de ventas**: ahora cada prenda tiene un botón para "Registrar
   venta" (cuánto se vendió de cada color/talla), que descuenta la
   existencia solo y guarda el registro. Un ícono "Ventas" en la pantalla
   principal muestra el historial completo y el total vendido en el día.
   Las ventas se sincronizan entre teléfonos igual que el catálogo.
3. **Exportar catálogo a CSV**: nueva opción en el menú de la cuenta para
   sacar el catálogo completo como un archivo que se abre en Excel/Sheets —
   sirve de respaldo y para compartir el inventario con alguien fuera de
   la app (por ejemplo, el contador).
4. **Aviso de "pocas unidades"**: antes solo se avisaba "AGOTADO" al llegar
   a 0. Ahora, con 3 piezas o menos de un color/talla, se avisa antes de
   que se agote del todo, para reabastecer a tiempo.
5. **Foto por prenda**: se puede tomar o elegir una foto para cada prenda
   desde el formulario; aparece como miniatura en la tarjeta del catálogo.
   Ojo: la foto se guarda solo en ese teléfono, no se comparte todavía con
   los demás (ver punto 6 de "Pendiente").

Verificado con `flutter analyze` (0 avisos) y `dart format` en todo `lib/`.
No hay carpeta `test/` (se retiraron por pedido explícito del usuario el
2026-09-22). No se compiló el APK: sigue sin SDK de Android en esta sesión,
solo Flutter — la función de foto (cámara/galería) no se pudo probar
visualmente en un teléfono real por la misma razón, aunque sigue el mismo
patrón de permisos que ya usa el escaneo de QR.

### 2026-10-02 (1) — sesión automática diaria de pulido

Sin tareas en "Pendiente". Se revisó a fondo todo `lib/` (en dos partes: datos/sincronización/autenticación por un lado, pantallas/widgets por otro) buscando errores reales de comportamiento. Se encontraron y corrigieron 5 problemas reales:

1. Si el registro guardado en el teléfono de una prenda estaba dañado (muy raro, pero puede pasar), esa prenda se quedaba intentando subirse para siempre sin lograrlo, y de paso dejaba de recibir correcciones que llegaran desde otro teléfono. Ahora ese caso se resuelve igual que los demás errores de sincronización.
2. En un caso muy puntual (una cuenta de empleado que quedó a medias por un error anterior), la pantalla de "cargando" podía quedarse así para siempre sin pasar a ningún mensaje, dejando a esa persona sin poder entrar ni ver por qué. Corregido.
3. Al editar el rol o acceso de un empleado desde Cuenta → Usuarios, ahora aparece un mensaje de "Usuario actualizado", igual que al crear una prenda o un usuario (antes no avisaba nada y parecía que no había guardado).
4. Si se estaba editando una prenda y, sin guardar todavía, se abría el botón de "ajuste rápido de existencia" desde esa misma pantalla, al volver se perdían en silencio los cambios de tallas/colores que se tenían a medio escribir. Ahora la app avisa que hay que guardar o descartar esos cambios antes de usar el ajuste rápido.
5. Se podía generar e imprimir/compartir el código QR de una prenda nueva antes de guardarla por primera vez, produciendo una etiqueta con un código que el catálogo todavía no reconoce. Ahora se pide guardar la prenda primero.

Verificado con `flutter analyze` (0 avisos) y `dart format` en todo `lib/`. No hay carpeta `test/` (las pruebas automatizadas se retiraron por pedido explícito del usuario el 2026-09-22), así que no aplica `flutter test`. No se compiló el APK: esta sesión automática no tiene el SDK de Android instalado, solo Flutter.

Nota para revisar con calma (no corregido hoy, por prudencia): se detectó que si dos teléfonos están sin conexión a internet al mismo tiempo y cada uno crea una prenda nueva, en un caso de muy mala suerte ambas podrían terminar con el mismo código, y al reconectarse una sobrescribiría a la otra sin aviso. Arreglarlo bien requiere cambiar cómo se fusionan los cambios al sincronizar, que es un cambio más delicado de lo que una sesión automática debe hacer sin que el dueño lo revise primero.

Nota: la sesión del 2026-09-28 sigue esperando revisión en el Pull Request #3 (`auto/mejoras-diarias` → `master`); se sigue usando ese mismo PR.

### 2026-10-01 — sesión automática diaria de pulido

Sin tareas en "Pendiente". Se revisó a fondo, archivo por archivo, todo `lib/`
(pantallas, autenticación, sincronización, modelo de datos, widgets) y
`firestore.rules`, buscando errores reales de comportamiento. Se encontró y
corrigió un detalle real:

1. `SessionWatcher` (quién puede entrar y con qué rol) solo volvía a escuchar
   el perfil del usuario cuando esa escucha fallaba con un error. Si
   Firestore la cerraba sin avisar con un error (algo que ya se contempla en
   la sincronización del catálogo, `CatalogSync`), la app dejaba de detectar
   cambios de rol o de activación para el resto de esa sesión, hasta volver
   a iniciar sesión. Ahora también se reintenta en ese caso.

Verificado con `flutter analyze` (0 avisos) y `dart format` en todo `lib/`
(sin cambios pendientes). No hay carpeta `test/` (las pruebas automatizadas
se retiraron por pedido explícito del usuario el 2026-09-22), así que no
aplica `flutter test`. No se compiló el APK: esta sesión no tiene el SDK de
Android instalado.

Nota: la sesión del 2026-09-28 sigue esperando revisión en el Pull Request
#3 (`auto/mejoras-diarias` → `master`); se sigue usando ese mismo PR.

### 2026-09-30 — sesión automática diaria de pulido

Sin tareas en "Pendiente". Se revisó a fondo, archivo por archivo, todo `lib/`
(pantallas, autenticación, sincronización, modelo de datos, widgets) y también
`firestore.rules` y la configuración de Android, buscando errores reales de
comportamiento. El código sigue muy sólido gracias a las rondas anteriores;
se encontró y corrigió un solo detalle real:

1. Al dar de alta un empleado desde Cuenta → Usuarios, si el administrador
   salía de la pantalla (botón de retroceso) justo mientras la cuenta se
   estaba creando, la cuenta se seguía creando de todas formas en segundo
   plano, pero el administrador no veía ninguna confirmación y podía pensar
   que no funcionó. Ahora esa pantalla espera a que termine, igual que ya
   pasaba en "Iniciar nueva tienda".

Verificado con `flutter analyze` (0 avisos) y `dart format`. No había
pruebas automatizadas que correr (se retiraron por pedido explícito del
usuario el 2026-09-22). No se compiló el APK (`flutter build apk`): esta
sesión automática no tiene el SDK de Android instalado, solo Flutter.

Nota: la sesión del 2026-09-28 sigue esperando revisión en el Pull Request
#3 (`auto/mejoras-diarias` → `master`); se sigue usando ese mismo PR.

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

### 2026-09-27 — integración de ramas

La rama `auto/mejoras-diarias` (PR #2, sesiones diarias del 24 al 27) y la rama
`claude/como-ves-la-app-g73nn7` (PR #1) se hicieron en paralelo sin ver una el trabajo de
la otra, porque ninguna estaba en `master`. Se integró el PR #2 dentro del PR #1; en los 10
archivos con conflicto se conservó lo mejor de cada lado (p. ej. el arranque con reintento
y el alta de usuarios que borra la cuenta sin perfil existían en ambas; quedó una sola
versión). Verificado con `flutter analyze`, `flutter build web` y las 27 pruebas de
lógica/sincronización/formulario (en copia aparte).

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

### 2026-09-23 — robustez (rama `claude/como-ves-la-app-g73nn7`)

El usuario pidió priorizar la robustez sobre lo estético. Verificado con `flutter analyze`
(0 avisos), `flutter build web`, 27 pruebas de lógica/sincronización/formulario y 28 pruebas
de reglas en el emulador de Firestore, todo en una copia aparte (el repo sigue sin `test/`).
Se comprobó que las pruebas nuevas fallan con el código anterior.

Errores reales corregidos:
1. **Se perdían ventas**: si un empleado vendía mientras el admin tenía abierta la ficha,
   al guardar la ficha se sobrescribía la existencia. Ahora se guarda solo lo que cambió en
   el formulario, sobre la versión más reciente (como el ajuste rápido).
2. **Doble toque en Guardar** del formulario cerraba dos pantallas (podía sacar de la
   principal). En la pantalla principal, un doble toque abría dos pantallas iguales.
3. **Un documento mal formado en Firestore borraba la prenda** de los teléfonos (se leía
   como "eliminada"). Ahora solo cuenta como borrada si el documento ya no existe.
4. **Un id con acentos, espacios o muy largo** (p. ej. creado a mano en la consola) hacía
   fallar el guardado en Hive y detenía toda la sincronización. Ahora se ignora ese
   documento y el resto sigue.
5. **Un cambio rechazado por permisos** podía quedarse en el teléfono. Ahora se trae la
   versión del servidor en cuanto se rechaza.
6. **Crear un usuario** dejaba una cuenta sin perfil (y el correo ocupado) si fallaba
   guardar el perfil. Ahora esa cuenta se borra.

Refuerzos:
- Lectura tolerante de prendas y perfiles: tipos equivocados, valores negativos, NaN o
  enormes se corrigen en vez de ocultar la prenda o dejar fuera al usuario.
- Límites (`Limites` en `clothing_item.dart`): nombre 80, talla 15, color 30, precio hasta
  $1,000,000, existencia hasta 99,999 por talla, 100 tallas/colores por prenda. Campos
  numéricos solo aceptan dígitos.
- Precio acepta "1,250.50", "1.250,50", "$ 300"; se guarda redondeado a centavos.
- "Café" y "cafe" (o "M" y "m ") cuentan como la misma variante.
- Formularios de sesión/usuarios: cualquier error inesperado muestra un mensaje.
- Arranque: si no abre el almacenamiento o Firebase, pantalla con "Reintentar" en vez de
  quedarse en blanco; errores no controlados se registran sin cerrar la app. Si fallan
  las preferencias, se usa el tema por defecto.
- `firestore.rules`: las prendas deben tener la forma que escribe la app (campos
  permitidos, id igual al documento, precio numérico 0–1,000,000, hasta 100 variantes).
  **Hay que publicarlas** para que apliquen: `firebase deploy --only firestore:rules`.

### 2026-09-23 — diseño visual y refuerzos (rama `claude/como-ves-la-app-g73nn7`)

Pulido y refuerzo pedido por el usuario, más 7 tareas de Pendiente. Verificado con
`flutter analyze` (0 avisos), `flutter build web`, pruebas de lógica y capturas de
pantalla en claro/oscuro hechas en una copia aparte (el repo sigue sin `test/`, como
pidió el usuario). No hay SDK de Android en esa sesión, así que no se generó APK.

Diseño visual:
- Tema en su propio archivo (`lib/app_theme.dart`): terracota fiel a la marca, escala
  tipográfica única, tarjetas con borde fino, botones de 52 px de alto, avisos
  flotantes, hojas inferiores y diálogos redondeados. Colores de existencia
  (`StockColors`) para claro y oscuro.
- Pantalla principal: resumen (prendas, piezas y valor del inventario; los empleados
  ven "Agotadas" en vez del valor), filtros Todas / Poca existencia / Agotadas con
  conteo, tarjetas con iniciales, precio con separador de miles (`$1,250.00`), código
  de la prenda, puntos de color y una insignia de existencia con ícono + texto.
- Ajuste rápido: encabezado por color con su muestra y total, botones táctiles de 48 px,
  el cambio pendiente de cada talla ("+1 sin guardar") y lectura para lector de pantalla.
- Eliminar prenda: botón rojo en la confirmación. Tooltips en botones de solo ícono.

Tareas de Pendiente resueltas:
1. Imagen del QR: etiqueta propia siempre negro sobre blanco, también en modo oscuro;
   la pantalla ahora hace scroll si no cabe.
2. Al escanear como Administrador se ofrece "Ajustar existencia" o "Ver ficha completa".
3. Búsqueda por nombre, código, color y talla (la talla debe escribirse completa).
4. Los códigos nuevos ya no se gastan al cancelar: se reservan al guardar.
5. Con conexión, si otro teléfono usó el mismo código mientras se llenaba el formulario,
   la prenda nueva toma el siguiente libre; además el contador avanza con cada prenda
   que llega sincronizada.
6. Nombre "Tienda de Ropa" en iOS y web; `README.md` y `pubspec.yaml` con texto real.
7. Filtro de poca existencia/agotadas y valor total del inventario.

Refuerzo:
- Ajuste rápido: tocar "Guardar" dos veces aplicaba los +/- dos veces; ahora se ignora el
  segundo toque y el botón solo se activa si hay cambios.

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
