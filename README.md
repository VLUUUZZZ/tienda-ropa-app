# Tienda de Ropa

App móvil para llevar el **catálogo y el inventario de una tienda de ropa** desde el
teléfono: qué prendas hay, en qué tallas y colores, cuántas piezas quedan de cada una y
cuánto vale lo que hay en tienda. Cada prenda lleva una **etiqueta con código QR**: al
escanearla, la app abre esa prenda para consultarla o ajustar su existencia en segundos.

Está pensada para tiendas pequeñas o medianas donde varias personas atienden con su
propio teléfono: todos ven el mismo catálogo, los cambios de uno aparecen en los demás, y
la app **sigue funcionando sin internet**.

---

## Para quién es

| Rol | Qué puede hacer |
|---|---|
| **Administrador** (dueño o encargado) | Todo: crear, editar y eliminar prendas, fijar precios, imprimir etiquetas QR, ajustar existencias y dar de alta, cambiar de rol o desactivar al personal. |
| **Empleado** (vendedor) | Consultar el catálogo, escanear etiquetas y ajustar existencias (sumar o restar piezas). No ve el valor del inventario ni puede cambiar nombres, precios o tallas. |

Los permisos no son solo visuales: el servidor (reglas de Firestore) rechaza cualquier
cambio que el rol no permita.

## Cómo se usa

1. **Abrir la tienda.** El dueño toca *Iniciar nueva tienda*, escribe su nombre, correo y
   contraseña, y queda como administrador de su tienda. Cada tienda está aislada: su
   catálogo y su personal solo los ven sus miembros.
2. **Registrar prendas.** Con el botón **+** se crea una prenda: nombre, precio y sus
   combinaciones de talla y color con las piezas de cada una. Al guardar, la app asigna un
   código legible (`PRENDA-000012`) y muestra una pantalla de éxito para **imprimir su
   etiqueta QR** o agregar la siguiente.
3. **Etiquetar.** La etiqueta (nombre, QR y código, siempre en negro sobre blanco) se
   guarda o comparte como imagen para imprimirla y pegarla en la prenda.
4. **Atender.** Al vender o recibir mercancía, se escanea la etiqueta (o se busca la
   prenda) y se ajusta la existencia con los botones **− / +** de cada talla y color.
5. **Dar de alta al personal.** Desde *Cuenta → Usuarios* el administrador crea las
   cuentas de sus empleados y puede cambiar su rol o desactivarlos.

## Pantallas

- **Inicio (catálogo).** Saludo y tienda; buscador por nombre, código, color o talla (sin
  importar mayúsculas ni acentos); tarjeta resumen con el **valor del inventario** (solo
  administradores), número de prendas, piezas y agotadas; filtros *Todas / Poca existencia
  / Agotadas*; y la lista de prendas con precio, código, colores y estado de existencia.
- **Ajuste rápido de existencia.** Las tallas agrupadas por color con un control
  **− número +**, el total y lo que falta por guardar.
- **Ficha de prenda.** Información (nombre y precio) y la lista de tallas y colores; desde
  el menú se ajusta la existencia o se elimina la prenda.
- **Escáner.** Cámara con marco de enfoque y linterna. Si el código no es de una prenda
  de la tienda, lo dice y explica qué hacer.
- **Código QR.** Etiqueta lista para imprimir o compartir.
- **Usuarios.** Personal de la tienda con su rol y estado; alta de cuentas nuevas.
- **Inicio de sesión / tienda nueva**, con recuperación de contraseña por correo.

## Mensajes y confirmaciones

La app siempre dice qué pasó, con el mismo lenguaje en todas las pantallas
(`lib/widgets/feedback/`):

- **Avisos rápidos (Snackbars)** para resultados de acciones cortas: *éxito* (verde,
  "Cambios guardados"), *error* (rojo, qué falló y qué hacer), *información* y *deshacer*
  (por ejemplo, al eliminar una prenda se puede deshacer durante unos segundos). Cada aviso
  lleva ícono, no solo color, y una vibración suave; uno nuevo reemplaza al anterior.
- **Diálogos de confirmación (AlertDialog)** antes de acciones importantes, explicando la
  consecuencia: eliminar una prenda, quitar una talla que aún tiene piezas, descartar
  cambios sin guardar, cerrar sesión, desactivar a alguien o cambiar su rol. Las acciones
  irreversibles se marcan en rojo y cancelar es siempre la opción segura.
- **Pantallas de éxito** al completar un proceso completo, con el siguiente paso a la
  mano: prenda creada (*Imprimir etiqueta QR* / *Agregar otra*), tienda creada
  (*Empezar*) y cuenta de empleado creada (*Listo* / *Crear otra cuenta*).

## Cómo funciona por dentro

- **Flutter** (Android e iOS; también compila para web), Material 3 con tema propio
  terracota en modo claro y oscuro, y la tipografía **Plus Jakarta Sans** incluida en la
  app (licencia SIL OFL, `assets/fonts/OFL.txt`).
- **Primero en el teléfono:** el catálogo vive en el dispositivo (**Hive**), así que la app
  abre al instante y funciona sin conexión. Cada cambio queda marcado como pendiente y se
  sube a **Firebase (Firestore)** cuando hay red; los cambios de otros teléfonos llegan en
  vivo.
- **Sin pisar el trabajo de otros:** los ajustes de existencia se guardan como "+2 / −1"
  sobre la versión más reciente, no como cantidades fijas, así dos personas vendiendo al
  mismo tiempo no se borran entre sí. Lo mismo al guardar la ficha completa.
- **Tolerante a datos malos:** un registro dañado o editado a mano en la consola no tumba
  la pantalla ni detiene la sincronización, y nunca se interpreta como "borrado".
- **Inicio de sesión** con Firebase Auth (correo y contraseña). El perfil de cada persona
  (`usuarios/{uid}`) dice su tienda, rol y si está activa; un cambio de rol o una
  desactivación se aplican al momento.

### Datos en Firestore

| Ruta | Contenido |
|---|---|
| `usuarios/{uid}` | Nombre, correo, rol (`admin` / `empleado`), activo, tienda. |
| `tiendas/{tiendaId}` | Nombre de la tienda y su dueño. |
| `tiendas/{tiendaId}/prendas/{PRENDA-000001}` | Nombre, precio y variantes (talla, color, existencia). El id del documento es el del QR. |

Los permisos y la forma válida de cada prenda están en `firestore.rules`. **Hay que
publicarlas** para que apliquen: `firebase deploy --only firestore:rules`.

## Estructura del código

| Carpeta | Contenido |
|---|---|
| `lib/models/` | Prenda y variantes, niveles de existencia y límites de datos. |
| `lib/data/` | Catálogo local (Hive), sincronización con Firestore, estado pendiente, preferencias. |
| `lib/auth/` | Usuarios, roles, sesión (Firebase Auth) y alta de personal. |
| `lib/screens/` | Pantallas: inicio (`home/`), ficha (`item_form/`), ajuste rápido, QR, escáner, sesión y usuarios. |
| `lib/widgets/` | Piezas compartidas; `feedback/` reúne avisos, confirmaciones y pantallas de éxito. |
| `lib/utils/` | Formato de precios y textos. |
| `lib/app_theme.dart` | Paleta, tipografía, radios y estilos de toda la app. |

## Desarrollo

```bash
flutter pub get
flutter analyze
flutter run
```

Las tareas pendientes y el historial de cambios están en [`BACKLOG.md`](BACKLOG.md).
