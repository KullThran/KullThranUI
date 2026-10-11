# Debug de posiciones de Unit Frames — 2026-10-07

Revisado en Retail y Forever: defaults y migraciones, BindDatabase/Refresh,
restauración de Core, los callbacks de Unlock Mode, cambios de estilo y escala,
y las posiciones de Unit Frames presentes en SavedVariables del cliente Retail.
La inspección de SavedVariables fue de solo lectura.

## Fallos confirmados y correcciones

1. `savePosition` recibía las coordenadas a restaurar, pero después `SavePoint`
   las reemplazaba por el punto del frame todavía sin restaurar. Esto podía
   dejar `unitFrames.positions` y `editMode.frames` con valores distintos.
   Ahora guarda exactamente los argumentos recibidos en ambos almacenes.
2. La animación de escala escribía `pos.x` y `pos.y` durante cada tick.
   Ahora calcula el punto visible a partir del anclaje y escala de captura,
   sin modificar las coordenadas persistidas. Cambiar de estilo y volver
   a restaurar el perfil ya no mezcla posiciones de distintas escalas.
3. El registro de movers llamaba a `ApplyFrameScale`, una función local de
   InitializeFrames que no estaba en su ámbito. Se conecta al escalador real;
   el cambio explícito de escala también actualiza el setting del módulo.
4. Se descartaba `relativePoint`. Ahora se conserva al guardar, cargar y aplicar.
5. Refresh y las reaplicaciones de posición podían pisar un arrastre pendiente.
   Ahora respetan los movimientos pendientes de Unlock Mode.
6. La posición guardada de Unlock Mode tiene prioridad al renderizar, no solo
   al abrir Unlock Mode. El margen automático del target se limita a posiciones
   sin escala de captura ni override de Unlock Mode.

## Pruebas

`tests/unit_frame_positions.lua` ejecuta las funciones y callbacks reales
extraídos del addon: restauración con frame antiguo, anclajes relativos distintos,
escalas sucesivas, animación interrumpida, arrastre pendiente, reset y cambio de
perfil. La prueba falla en HEAD de ambos repositorios al verificar el guardado;
pasa con las correcciones en ambos. También pasan las pruebas de recursos nativos,
actualización de buffs y persistencia del combat timer. Ambos archivos principales
pasan Lua 5.1 `luac -p` y su diff pasa `git diff --check`.

## Diagnóstico en el cliente

`/ktufpos` imprime el perfil activo, escala de UIParent, coordenadas nativas,
coordenadas de Unlock Mode y anclajes/escala visibles de cada unidad. Es de solo
lectura. `/ktumdiag` sigue disponible para el diagnóstico general de Unlock Mode.

Comprobar fuera de combate: mover y guardar Player/Target; ejecutar `/ktufpos`;
hacer `/reload`; comparar; cambiar entre estilos y volver al inicial; comparar;
cambiar de perfil y regresar. Probar también pet, focus y sus targets.

## Límites y datos existentes

Hay varios perfiles con coordenadas diferentes de los defaults. La inspección
no identifica por sí sola cuál estaba activo en la captura ni cuál era la última
posición deseada. No se borran perfiles ni se resetean posiciones existentes.
Las posiciones antiguas sin escala registrada conservan su interpretación actual.
Los valores ya sobrescritos no se pueden reconstruir con certeza sin una copia
anterior o sin que el usuario indique su posición deseada. El diagnóstico del
cliente permite distinguir esos datos antiguos de un nuevo fallo de restauración.
La validación visual en juego sigue pendiente; no se ha controlado el cliente.
