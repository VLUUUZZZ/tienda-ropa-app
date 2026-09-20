# Backlog

Agrega aquí las tareas que quieres que se trabajen en la sesión automática diaria (7:00 am). Reglas:

1. La sesión diaria toma las tareas de "Pendiente", de arriba hacia abajo.
2. Si no hay ninguna pendiente, se dedica a pulir lo que ya existe (bugs, UI/UX, rendimiento, pruebas) — sin agregar funciones nuevas grandes por su cuenta.
3. Cada tarea completada se mueve a "Completado" con la fecha y el commit correspondiente.
4. Todo cambio se compila y se prueba antes de darse por terminado, y queda guardado en git (nunca se sube a ningún remoto sin que tú lo pidas).

## Pendiente

(Lista de pulido acordada con el usuario el 2026-09-20. Ya cumplido, sin cambios: búsqueda por
substring insensible a mayúsculas, orden alfabético por defecto, y el escáner ya cierra solo al
detectar un código. Se está trabajando en el resto en la sesión interactiva de hoy; lo que quede
sin terminar ahí, la sesión automática lo sigue de arriba hacia abajo.)

1. Tarjetas de producto: mostrar colores disponibles además de precio y existencia total.
2. Edición rápida de existencia por color/talla con botones +/-, sin pasar por el formulario completo.
3. Marcar "AGOTADO" cuando una talla llega a 0, sin eliminar el registro.
4. Evitar variantes duplicadas (misma combinación color + talla) dentro de una prenda.
5. Validaciones: precio y existencia no negativos, nombre/color/talla no vacíos.
6. QR con código legible tipo PRENDA-000024 (en vez de UUID) y opción de compartir/guardar como imagen.
7. Al escanear un QR que no corresponde a ninguna prenda registrada, mostrar "QR no reconocido" en
   vez de crear una prenda automáticamente.
8. Confirmación visual ("✓ Cambios guardados") al guardar cambios.

## Completado
