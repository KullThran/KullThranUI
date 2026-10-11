# Revisión de texturas — 2026-10-08

Revisión del código y los cambios pendientes respecto a HEAD en los workspaces Forever y Retail. No es una validación visual dentro del cliente.

| Módulo | Resultado |
| --- | --- |
| Damage Meter | El adaptador ya asignaba UI-StatusBar a Classic, Retail y Forever, y Melli a KUI. No fue una sustitución reciente. Había una incoherencia previa: el selector y el preview admitían rutas externas de SharedMedia, pero las filas reales solo admitían siete rutas fijas. Corregido en ambos workspaces; preview y filas usan ahora el mismo resolver. |
| Nameplates | Las correcciones anteriores sí sustituyeron indebidamente rellenos de Retail/Forever por Classic. El código actual vuelve a los atlas previstos para ambos: UI-HUD-CoolDownManager-Bar y UI-CastingBar-Full-Standard. Classic usa UI-StatusBar; KUI recupera su textura propia o personalizada y elimina fondos nativos residuales. La configuración de un perfil reemplazado se consulta en la tabla actual. Se detectó y corrigió otra causa: ResetComboDefaults borraba campos cuyo prefijo coincidía con healthBar/castBar/classPower y después resembraba el tema, sobrescribiendo el slot recién restaurado. Ahora preserva los campos propiedad del adaptador y no vuelve a sembrar el tema completo. |
| Party Frames | La corrección anterior de barras oscuras sustituyó los rellenos de los tres estilos nativos por UI-StatusBar. El marco, recortes y máscaras siguen siendo propios de cada estilo. Es una simplificación real de textura: evita multiplicar los píxeles verdes/azules del atlas por colores de clase o recurso. Esta revisión no añade otra sustitución; restaurar los atlas coloreados sin resolver esa multiplicación volvería a oscurecer las barras. |
| Unit Frames | Los cambios pendientes en ThemeClientAssets añaden el fondo nativo del nombre para el color de reacción, con alpha 0.45 y BLEND. No reemplazan los rellenos principales de vida/recurso. El cambio pendiente de darkTheme en Forever evita imponer negro sobre el color configurado. |
| Recursos de clase | Se añadieron texturas para recursos nativos y clases. Son recursos nuevos; no sustituyen los archivos gráficos originales del addon. |
| Cast Bar, Resource Bars, CDM y Skins | No aparecen cambios pendientes de asignación de textura en sus adaptadores de estilos. Sus presets pueden elegir texturas distintas: no todos los módulos usan el mismo relleno por tener el mismo estilo. |
| Minimap | Los cambios pendientes revisados afectan protección en combate y aplicación de máscaras; no sustituyen los recursos gráficos del mapa. |
| Archivos gráficos | Git no muestra modificaciones ni borrados de archivos gráficos ya versionados en ninguno de los dos workspaces. Hay nuevos recursos de clase. |

## Comprobaciones

- Resolver real de Damage Meter: rutas propias y externas, nombres registrados en SharedMedia, biblioteca ausente, valores inválidos y semillas de los cuatro temas.
- Nameplates: transiciones entre los cuatro estilos, limpieza de fondos nativos, restauración de texturas personalizadas, cambio de perfil y brillo.
- Party Frames: color exacto de clase/recurso, opacidad y orden de capas.
- Reset de slots de VisualThemes y reacción de nombre de Unit Frames. La suite completa antigua de Forever tiene un fallo restante en ActionBars (forma esperada CIRCLE, obtiene NONE), ajeno al resolver de texturas; no se declara toda la suite aprobada.
- Lua 5.1 y revisión de espacios de los archivos modificados en esta revisión.

## Validación pendiente dentro del juego

Elegir una textura externa en Damage Meter y comprobar filas reales y preview. Alternar Classic → Retail → Forever → KUI con nameplates visibles, entrar/salir de combate y cambiar de perfil. Party Frames mantiene actualmente el relleno neutro descrito arriba, no sus antiguos rellenos coloreados. Las pruebas de código no confirman el resultado visual de esos casos.
