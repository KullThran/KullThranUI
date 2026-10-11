# Perfiles de estilo personalizados de KullThranUI

Fecha: 2026-10-06
Estado: diseño técnico y funcional; implementación pendiente.
Ámbito: Forever y Retail, con datos y presets específicos de cada cliente.

## Problema verificado en el código

El motor ya guarda slots por módulo y tema, pero no son variantes con nombre ni una definición inmutable de los defaults. `ApplyAll` captura únicamente `getOwnedPaths`, restaura el slot destino o ejecuta `seed`, y después ejecuta `ResetComboDefaults`. Esta última función escribe y elimina ajustes fuera de la captura y del rollback. `RequestApply` también la ejecuta al volver a seleccionar el tema activo.

Party Frames solo declara retrato, texturas y color de absorb como rutas del tema. La selección local `partyFrameStyle`, los offsets y otras modificaciones visuales no tienen una representación completa en estos slots. Hay validaciones y migraciones que escriben preferencias; deben distinguirse de las modificaciones manuales.

Retail tiene protecciones adicionales para el slot KUI de Nameplates y para ciertas migraciones. Hay que preservar esas diferencias al introducir el contrato común, no copiar el motor de un cliente sobre el otro.

Puntos de integración:

- `KullThranUI/Modules/VisualThemes/ThemeEngine.lua`: aplicación, slots, resets, rollback e inicialización.
- `KullThranUI/Modules/VisualThemes/ThemeRegistry.lua`: contratos por módulo.
- `KullThranUI/Modules/VisualThemes/ThemeSlots.lua`: persistencia y versión del esquema.
- `KullThranUI/Modules/VisualThemes/Adapters/`: clasificación de rutas y defaults visuales.
- `KullThranUI/Modules/Profiles.lua`: gestión, importación y exportación, reutilizando su separación por cliente.
- `KullThranUI/Options.lua`, `BuildProfilesTab`: panel nuevo bajo CDM Spell Profiles, en el espacio señalado en la captura.
- `KullThranUI_PartyFrames/.../PartyFrames_Styles.lua`: selección de tema local y preferencias de overlay por tema.

## Modelo: base, variante y borrador

Un perfil completo de AceDB continúa siendo el contenedor de la configuración del usuario. Dentro de él se guardan los perfiles de estilo, sin convertir cada variante visual en otro perfil completo de AceDB.

1. **Base**: KUI, Retail, Forever o Classic, generada de defaults canónicos y del preset de su cliente. Es inmutable desde los controles del usuario.
2. **Variante**: tiene ID estable, nombre, tema base, cliente, versión de esquema, revisión y diferencias visuales por módulo.
3. **Borrador**: contiene cambios aún no guardados de la selección activa. Se persiste antes de cualquier transición que pueda reemplazarlos y sobrevive a `/reload`.

Identidad activa: `{baseTheme, variantId}`. `variantId = nil` significa estilo base. `dirty` indica que la configuración efectiva difiere de esa selección; no cambia la identidad del tema renderizado.

Configuración efectiva:

`ajustes compartidos del usuario + preset base + diferencias de la variante + borrador`

Un Classic personalizado puede usar Party Frames KUI, Cast Bar Retail y otros cambios sin renombrar la base ni confundir los renderizadores: el tema global continúa siendo Classic y las selecciones locales forman parte de las diferencias.

Persistencia propuesta dentro de `profile.visualTheme`:

```lua
styleProfiles = {
    schemaVersion = 1,
    active = { baseTheme = "classic", variantId = nil },
    variants = {
        ["variant-id"] = {
            name = "Classic personal",
            baseTheme = "classic",
            clientFlavor = "retail",
            baseRevision = 1,
            revision = 1,
            overrides = { partyframes = { partyFrameStyle = "kui" } },
            baseline = {}, -- solo rutas modificadas; permite migracion de tres vias
        },
    },
    drafts = {}, -- por seleccion, con origen y revision de referencia
}
```

Las diferencias incluyen operaciones explícitas de asignación y eliminación. Un marcador de nil versionado permite distinguir eliminar una clave de no modificarla. Las copias deben ser independientes; ni bases ni variantes comparten tablas mutables con el perfil activo.

## Alcance de las rutas

Cada adaptador declara:

- `getStylePaths`: opciones visuales personalizables, incluida la selección local de estilo, geometría, fuente, bordes, iconos y offsets pertinentes.
- `getPresetWritePaths`: todas las rutas que la base modifica o elimina. Debe ser un subconjunto de `getStylePaths`.
- `buildBase(theme, client, defaults)`: genera el preset en una copia de defaults canónicos, sin leer cambios del perfil activo.
- `normalize`: normalización estable para comparación.
- `validate`: validación de compatibilidad, sin restablecer elecciones del usuario que sean válidas.
- `apply` y `refresh`: escritura y actualización del módulo.

La lista debe cubrir también los antiguos efectos de `ResetComboDefaults`; no basta con conservar los actuales `getOwnedPaths`. Los resets dejan de ejecutarse después de restaurar una variante: se convierten en parte declarativa de la base.

No se incluyen cachés, estados de combate, datos de preview, migraciones, historial, bindings ni datos de otros addons. Escala de pantalla y preferencias ajenas al estilo permanecen compartidas. Posiciones visuales del módulo se incluyen donde formen parte de la personalización; al variar escalas se conserva el anclaje en pantalla mediante el mecanismo existente de Unit Frames.

La fuente global permanece como preferencia compartida, salvo que el usuario elija explícitamente una fuente para un módulo. Las tarjetas y los textos descriptivos heredan `KT:ResolveFontPath()`; Avant Garde es el default y los nombres usan blanco y outline.

## Detección eficiente

Usar una combinación de eventos explícitos y comparación selectiva:

1. Los setters de configuración notifican `NotifyManualChange(moduleKey, path)` tras confirmar un cambio real. Integrar setters normales, selección local de estilo, controles de color y guardado de movers.
2. Marcar solo ese módulo y agrupar modificaciones de sliders/color durante aproximadamente 400 ms, o confirmar al soltar el control.
3. Comparar sus rutas visuales normalizadas con la configuración efectiva de la selección activa. Si el usuario revierte el cambio, desaparece `dirty`.
4. Comparación completa de las rutas registradas al cambiar de selección, guardar o exportar. Cubre rutas antiguas que todavía no notifican, con coste acotado a acciones del usuario.
5. Etiquetar la procedencia de escrituras: `user`, `theme`, `variant`, `migration`, `import`, `restore`. Un contador de transacción impide que aplicar defaults genere falsos cambios manuales.

No escanear tablas por frame ni interceptar todas las asignaciones con metatables. Los flags aceleran la detección; el diff decide qué guardar. Importar un estilo crea o actualiza una variante mediante una operación explícita; no genera prompts recursivos.

## UX del aviso

Después de un cambio confirmado, mostrar una pregunta discreta en la página del módulo:

**«Has personalizado Classic. ¿Quieres guardar estos cambios como una variante?»**

Acciones: **Guardar variante** y **Más tarde**. Los cambios permanecen aplicados al posponer y se muestran como «Classic · cambios sin guardar». No abrir un modal por cada slider, no interrumpir combate y no repetir el aviso para el mismo borrador sin modificaciones nuevas relevantes.

Al solicitar un cambio de estilo con cambios pendientes, presentar un único diálogo de transición con el tema destino, los módulos modificados y las acciones: guardar y continuar, conservar borrador y continuar, o cancelar. Cerrar el diálogo equivale a cancelar; nunca a descartar. Descartar es una acción separada y explícita.

La ausencia de respuesta no autoriza una reescritura: los cambios actuales siguen activos.

## Guardar y volver a la base: requisito 4

El diálogo de guardado muestra nombre, base y módulos afectados. Acción principal: **Guardar variante y aplicar base**. Acción alternativa: **Guardar y seguir usando la variante**. Ambas describen su resultado antes de aceptarlas.

Si la variante ya está seleccionada, se ofrece **Actualizar variante** o **Guardar como nueva**. Actualizar crea una revisión recuperable del contenido anterior; no reemplaza a ciegas una variante distinta que solo comparta el nombre.

Para «guardar y aplicar base», el orden es obligatorio:

1. Capturar los ajustes actuales y calcular las diferencias.
2. Guardar la nueva variante o revisión, verificando identidad, esquema y copia independiente.
3. Preparar el estado base en memoria y validar todos los módulos.
4. Aplicar la base y seleccionar `{baseTheme, variantId=nil}`.
5. Mostrar «Variante guardada» con acceso **Usar mi variante** y ambas opciones visibles en el selector.

Si guardar o validar falla, mantener los ajustes activos. Si aplicar falla, restaurar la configuración y la identidad anteriores; conservar la variante ya guardada y ofrecer reintentar. No ejecutar resets después de aplicar sus diferencias.

## Página Profiles y selector global

Añadir un bloque **Style Profiles** en el hueco derecho marcado en rojo, debajo de CDM Spell Profiles. Sus pestañas internas:

- **Estilos base**: las cuatro bases, con preview y acción «Aplicar base».
- **Mis variantes**: guardar, seleccionar, actualizar, duplicar, renombrar, eliminar y exportar/importar; cada entrada muestra su base, cliente y módulos modificados.

El bloque muestra siempre la selección activa y los cambios pendientes. La lista puede desplazarse dentro del panel para adaptarse al ancho disponible. No se añaden controles dentro de las previews.

El selector global de Visual Styles también ofrece la base y las variantes asociadas. Seleccionar una base ya activa es idempotente; la operación de restaurar defaults se hace con una acción explícita y protección del borrador. Esto corrige el reset actual al volver a hacer click en el mismo tema.

## Aplicación segura y módulos tardíos

Preparar una transacción con la unión de todas las rutas que se van a escribir o eliminar, incluidas las del destino. Capturar rollback de configuración, identidad activa, borrador y metadatos pertinentes. Validar en copias, escribir en orden estable y refrescar al terminar. Una excepción revierte el conjunto completo.

Guardar no requiere modificar frames protegidos. Aplicar estilos en combate se aplaza conservando el ID y la revisión del destino; la interfaz muestra la selección realmente aplicada hasta completar el cambio fuera de combate. El usuario puede cancelar el cambio pendiente.

Un módulo no cargado mantiene sus diferencias pendientes. Cuando se carga, recibe base más variante más borrador una sola vez. Ni validaciones repetidas ni `EnsureDB` pueden borrar diferencias válidas. La actualización de un addon usa comparación de tres vías: base antigua, cambios del usuario y base nueva. Conflictos conservan la elección del usuario y se listan para revisión.

## Migración y límites entre clientes

Migración aditiva, versionada e idempotente. Capturar primero el estado visual actual y los slots existentes como variantes recuperadas. Mantener la selección efectiva y el aspecto inicial. No aplicar silenciosamente una nueva base ni repetir la reparación antigua que borra slots.

Los datos de cada variante incluyen `clientFlavor`. Exportación/importación valida módulos, clases y opciones disponibles; las incompatibilidades se muestran antes de aplicar. No cambiar opciones de otro cliente ni importar datos arbitrarios fuera de las rutas permitidas.

## Comprobaciones de aceptación para la implementación

1. Classic base → Party Frames KUI → aviso discreto → guardar → Classic puro y variante seleccionables; volver a la variante recupera tema local, offsets, overlay y fuente personalizada.
2. Modificar una variante activa y aceptar guardar/aplicar base conserva la nueva revisión y ofrece volver a usarla.
3. Cancelar o posponer no cambia configuración; `/reload` conserva el borrador.
4. Sliders y selectores de color generan un aviso agrupado; las aplicaciones internas, migraciones y previews no generan avisos.
5. Revertir cambios elimina el estado pendiente; seleccionar de nuevo la base activa no borra nada.
6. Tras aplicar una variante, ningún reset o validate altera sus valores válidos.
7. Simular fallos en guardado, validación y aplicación comprueba restauración completa, también para rutas que solo escribe el destino.
8. Combate, módulos tardíos, cambios de perfil AceDB y recarga conservan identidad, borrador y selecciones independientes.
9. Migrar perfiles y slots de ambos clientes mantiene sus valores y pasa dos veces sin efectos adicionales.
10. Actualización de defaults e importación incompatible conservan las elecciones del usuario y presentan conflictos comprensibles.
11. Comprobar panel, tabs, fuente global y alternancia visual dentro de Retail y Forever; las pruebas Lua y de tablas no prueban el resultado visual.

## Orden de implementación

1. Inventario y clasificación de escrituras de presets, resets y setters; completar contratos de adaptadores.
2. Bases canónicas, persistencia de variantes/borradores, diff y migración con pruebas Lua de conservación.
3. Transacciones de aplicación y supresión de notificaciones internas, incluido combate y módulos tardíos.
4. Avisos, panel de Profiles y selector de variantes, con pruebas de interacción.
5. QA dentro de ambos clientes, import/export y compatibilidad con cambios de perfil completos.
