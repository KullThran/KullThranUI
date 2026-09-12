local _, ns = ...

local locales = ns and ns.Locales
if not locales then
    return
end

local function apply(locale, entries)
    if type(locale) ~= "table" then
        return
    end

    for key, value in pairs(entries) do
        locale[key] = value
    end
end

local enUS = {
    ["Estilos"] = "Styles",
    ["Reintentar"] = "Retry",
    ["Modulo cargado. Actualizando pagina..."] = "Module loaded. Refreshing page...",
    ["Módulo cargado. Actualizando página..."] = "Module loaded. Refreshing page...",
    ["Este módulo está configurado como LoadOnDemand y se cargará al abrir esta página."] = "This module is configured as LoadOnDemand and will load when you open this page.",
    ["No se puede cargar este módulo mientras estás en combate. Sal de combate y pulsa Reintentar."] = "This module cannot be loaded while you are in combat. Leave combat and press Retry.",
    ["Este addon esta desactivado en la lista de AddOns. Activarlo y recarga la UI."] = "This addon is disabled in the AddOns list. Enable it and reload the UI.",
    ["No se pudo cargar el addon del módulo ("] = "Could not load the module addon (",
    ["El módulo Installer se carga automáticamente al iniciar sesión."] = "The Installer module loads automatically on login.",
    ["Si no aparece la página completa, revisa que `KullThranUI_Installer` esté activado en la lista de AddOns y recarga la UI."] = "If the full page does not appear, check that `KullThranUI_Installer` is enabled in the AddOns list and reload the UI.",
}

enUS["Módulo cargado. Actualizando página..."] = "Module loaded. Refreshing page..."
enUS["Este módulo está configurado como LoadOnDemand y se cargará al abrir esta página."] = "This module is configured as LoadOnDemand and will load when you open this page."
enUS["No se puede cargar este módulo mientras estás en combate. Sal de combate y pulsa Reintentar."] = "This module cannot be loaded while you are in combat. Leave combat and press Retry."
enUS["No se pudo cargar el addon del módulo ("] = "Could not load the module addon ("
enUS["El módulo Installer se carga automáticamente al iniciar sesión."] = "The Installer module loads automatically on login."
enUS["Si no aparece la página completa, revisa que `KullThranUI_Installer` esté activado en la lista de AddOns y recarga la UI."] = "If the full page does not appear, check that `KullThranUI_Installer` is enabled in the AddOns list and reload the UI."

local esES = {
    ["Blizzard window accent"] = "Acento de ventanas de Blizzard",
    ["Use theme accent"] = "Usar acento del tema",
    ["Classic Blizzard yellow"] = "Amarillo clasico de Blizzard",
    ["Show Blizzard window borders"] = "Mostrar bordes de ventanas de Blizzard",
    ["Window borders: On"] = "Bordes de ventanas: activados",
    ["Window borders: Off"] = "Bordes de ventanas: desactivados",
    ["English"] = "Inglés",
    ["Spanish"] = "Español",
    ["General"] = "General",
    ["Compatibility"] = "Compatibilidad",
    ["Profiles"] = "Perfiles",
    ["Quick Setup"] = "Configuración rápida",
    ["Fonts & Colors"] = "Fuentes y colores",
    ["Disable Modules"] = "Desactivar módulos",
    ["Installer"] = "Instalador",
    ["Unit Frames"] = "Marcos de unidad",
    ["Cast Bar"] = "Barra de casteo",
    ["Resource Bars"] = "Barras de recursos",
    ["Aura Reminders"] = "Recordatorios de auras",
    ["Action Bars"] = "Barras de acción",
    ["Nameplates"] = "Placas de nombre",
    ["Buffs & Debuffs"] = "Buffs y debuffs",
    ["Skins"] = "Apariencia (Skins)",
    ["Minimap"] = "Minimapa",
    ["Tooltip"] = "Tooltip",
    ["Armory"] = "Armería",
    ["Dragon Riding"] = "Jinete de dragones",
    ["Experience Bar"] = "Barra de experiencia",
    ["Chat"] = "Chat",
    ["Bags"] = "Bolsas",
    ["Cursor"] = "Cursor",
    ["Teleport Menu"] = "Menú de teletransporte",
    ["Inspect Armory"] = "Armería de inspección",
    ["Progress Bars"] = "Barras de progreso",
    ["Enhancements"] = "Mejoras",
    ["Changelog"] = "Cambios",
    ["View Changelog"] = "Ver cambios",
    ["Resolution & Scale"] = "Resolución y escala",
    ["Use Blizzard UI Scale"] = "Usar escala de UI de Blizzard",
    ["Resolution Preset"] = "Preajuste de resolución",
    ["Manual UI Scale"] = "Escala manual de UI",
    ["Language"] = "Idioma",
    ["Styles"] = "Estilos",
    ["Estilos"] = "Estilos",
    ["Smart recolor applies a global KullThranUI palette to accents, menu icons, texts, checkboxes and the main background tint."] = "El recolor inteligente aplica una paleta global de KullThranUI a acentos, iconos del menú, textos, casillas y al tinte principal del fondo.",
    ["Preset Styles"] = "Estilos predefinidos",
    ["Choose a preset to recolor the KullThranUI menu and sync the main profile accent values."] = "Elige un preset para recolorear el menú de KullThranUI y sincronizar los valores de acento del perfil principal.",
    ["Manual Colors"] = "Colores manuales",
    ["Fine tune the smart recolor palette manually if you want a custom style."] = "Ajusta manualmente la paleta del recolor inteligente si quieres un estilo personalizado.",
    ["Accent Color"] = "Color de acento",
    ["Custom Accent Color"] = "Color de acento personalizado",
    ["Window Background"] = "Fondo de ventana",
    ["Window Border"] = "Borde de ventana",
    ["Main Text"] = "Texto principal",
    ["Secondary Text"] = "Texto secundario",
    ["Background Tint"] = "Tinte de fondo",
    ["Unlock Mode Color"] = "Color del modo desbloqueo",
    ["Unlock Mode Accent"] = "Acento del modo desbloqueo",
    ["Friend List Color"] = "Color de la lista de amigos",
    ["Friend List Accent"] = "Acento de la lista de amigos",
    ["Bags Color"] = "Color de las bolsas",
    ["Bags Accent"] = "Acento de las bolsas",
    ["Color Theme"] = "Tema de color",
    ["KullThranUI Class Color"] = "Color de clase de KullThranUI",
    ["Interface Style"] = "Estilo de interfaz",
    ["Menu Icons"] = "Iconos del menú",
    ["Sidebar Icon Color"] = "Color de iconos laterales",
    ["Skin Colors"] = "Colores de skins",
    ["If some live module keeps the previous palette, use Reload UI after saving the style."] = "Si algún módulo activo mantiene la paleta anterior, usa Recargar UI después de guardar el estilo.",
    ["Preset selection also updates accent-driven fields like tracker highlights, chat highlight and castbar color."] = "La selección de preset también actualiza campos guiados por el color de acento, como los resaltados del tracker, el resaltado del chat y el color de la barra de casteo.",
    ["Options Menu"] = "Menú de opciones",
    ["Reload UI"] = "Recargar UI",
    ["Reset Profile"] = "Restablecer perfil",
    ["Current Setup"] = "Configuración actual",
    ["Compatibility detector module not available."] = "El módulo detector de compatibilidad no está disponible.",
    ["Detect loaded addons that overlap with KullThranUI modules and manage them from one place."] = "Detecta addons cargados que se solapan con módulos de KullThranUI y gestiónalos desde un solo lugar.",
    ["Auto Scan on Login"] = "Escaneo automático al iniciar sesión",
    ["Show Conflict Popup"] = "Mostrar aviso de conflictos",
    ["Mute Popup Permanently"] = "Silenciar aviso permanentemente",
    ["Rescan Now"] = "Reescanear ahora",
    ["Detected Conflicts"] = "Conflictos detectados",
    ["No active incompatible addons detected right now."] = "No se han detectado addons incompatibles activos en este momento.",
    ["Profiles module not available."] = "El módulo de perfiles no está disponible.",
    ["Export Current Profile"] = "Exportar perfil actual",
    ["Export or import the full active KullThranUI profile from one place."] = "Exporta o importa el perfil activo completo de KullThranUI desde un solo lugar.",
    ["Import Profile"] = "Importar perfil",
    ["Layout Profiles"] = "Perfiles de disposición",
    ["Save Current As"] = "Guardar actual como",
    ["Saved Profiles"] = "Perfiles guardados",
    ["Active Profile: %s"] = "Perfil activo: %s",
    ["Pending Reload Changes: %s"] = "Cambios pendientes de recarga: %s",
    ["Current Spec Assignment: %s"] = "Asignación de especialización actual: %s",
    ["Clear Spec Assign"] = "Borrar asignación de especialización",
    ["Pick the KUI modules you want to export or merge into the current profile."] = "Elige los módulos de KUI que quieres exportar o fusionar con el perfil actual.",
    ["Each card is a specialization. Export only the specs you actually want to move."] = "Cada tarjeta corresponde a una especialización. Exporta solo las especializaciones que realmente quieras mover.",
    ["CDM Presets"] = "Presets de CDM",
    ["The per-spec CDM import/export framework is now in Profiles. Additional presets can be added later once the source data is available."] = "La importación y exportación de CDM por especialización está ahora en Perfiles. Se podrán añadir presets adicionales cuando los datos de origen estén disponibles.",
    ["Current Version: %s"] = "Versión actual: %s",
    ["Published changelog version: %s"] = "Versión del changelog publicado: %s",
    ["Latest archived changelog: %s"] = "Último changelog archivado: %s",
    ["No published Wago changelog was found for version %s."] = "No se encontró un changelog publicado en Wago para la versión %s.",
    ["Secondary Source: CurseForge Files"] = "Fuente secundaria: archivos de CurseForge",
    ["Fallback Source: Discord"] = "Fuente alternativa: Discord",
    ["The Installer module loads automatically on login."] = "El módulo Installer se carga automáticamente al iniciar sesión.",
    ["If the full page does not appear, check that `KullThranUI_Installer` is enabled in the AddOns list and reload the UI."] = "Si no aparece la página completa, revisa que `KullThranUI_Installer` esté activado en la lista de AddOns y recarga la UI.",
    ["This module is configured as LoadOnDemand and will load when you open this page."] = "Este módulo está configurado como LoadOnDemand y se cargará al abrir esta página.",
    ["Module loaded. Refreshing page..."] = "Módulo cargado. Actualizando página...",
    ["This module cannot be loaded while you are in combat. Leave combat and press Retry."] = "No se puede cargar este módulo mientras estás en combate. Sal de combate y pulsa Reintentar.",
    ["This addon is disabled in the AddOns list. Enable it and reload the UI."] = "Este addon está desactivado en la lista de AddOns. Actívalo y recarga la UI.",
    ["Could not load the module addon ("] = "No se pudo cargar el addon del módulo (",
    ["Retry"] = "Reintentar",
    ["Modulo cargado. Actualizando pagina..."] = "Módulo cargado. Actualizando página...",
    ["Módulo cargado. Actualizando página..."] = "Módulo cargado. Actualizando página...",
    ["Este módulo está configurado como LoadOnDemand y se cargará al abrir esta página."] = "Este módulo está configurado como LoadOnDemand y se cargará al abrir esta página.",
    ["No se puede cargar este módulo mientras estás en combate. Sal de combate y pulsa Reintentar."] = "No se puede cargar este módulo mientras estás en combate. Sal de combate y pulsa Reintentar.",
    ["Este addon esta desactivado en la lista de AddOns. Activarlo y recarga la UI."] = "Este addon está desactivado en la lista de AddOns. Actívalo y recarga la UI.",
    ["No se pudo cargar el addon del módulo ("] = "No se pudo cargar el addon del módulo (",
    ["El módulo Installer se carga automáticamente al iniciar sesión."] = "El módulo Installer se carga automáticamente al iniciar sesión.",
    ["Si no aparece la página completa, revisa que `KullThranUI_Installer` esté activado en la lista de AddOns y recarga la UI."] = "Si no aparece la página completa, revisa que `KullThranUI_Installer` esté activado en la lista de AddOns y recarga la UI.",
    ["|cffFF5555Warning:|r These installers overwrite the target profile and reload the UI."] = "|cffFF5555Aviso:|r estos instaladores sobrescriben el perfil de destino y recargan la UI.",
    ["|cffFF00FFDanders (DPS/Tank)|r"] = "|cffFF00FFDanders (DPS/Tank)|r",
    ["|cffFF00FFDanders (Healer)|r"] = "|cffFF00FFDanders (Healer)|r",
    ["%s Layout"] = "Diseño %s",
    ["Detected Addons: %s"] = "Addons detectados: %s",
    ["Enable Module"] = "Habilitar módulo",
    ["Reset Module Defaults"] = "Restablecer valores por defecto del módulo",
    ["Automation and quality-of-life settings for KullThranUI."] = "Automatizaciones y ajustes de calidad de vida para KullThranUI.",
    ["Whisper keyword"] = "Palabra clave para susurros",
    ["Persistent LFG note"] = "Nota persistente de LFG",
    ["Persistent LFG note text"] = "Texto de la nota persistente de LFG",
    ["Mail font size"] = "Tamaño de fuente del correo",
    ["Quest font size"] = "Tamaño de fuente de misiones",
    ["Weather density"] = "Densidad del clima",
    ["Auto loot delay"] = "Retraso del botín automático",
    ["Enable Button Bag"] = "Habilitar bolsa de botones",
    ["Button Size"] = "Tamaño de botón",
    ["Spacing"] = "Espaciado",
    ["Columns"] = "Columnas",
    ["Position"] = "Posición",
    ["Minimap Shape"] = "Forma del minimapa",
    ["Choose the minimap shape you want to start with. This preview updates the real minimap setting immediately."] = "Elige la forma del minimapa con la que quieres empezar. Esta vista previa actualiza el ajuste real del minimapa al instante.",
    ["Show FPS"] = "Mostrar FPS",
    ["Show MS"] = "Mostrar MS",
    ["Show Clock"] = "Mostrar reloj",
    ["Stats Font"] = "Fuente de estadísticas",
    ["Font"] = "Fuente",
    ["Size"] = "Tamaño",
    ["Outline"] = "Contorno",
    ["Appearance"] = "Apariencia",
    ["Colors"] = "Colores",
    ["Background Color"] = "Color de fondo",
    ["Border Color"] = "Color del borde",
    ["Border Size"] = "Tamaño del borde",
    ["Width"] = "Ancho",
    ["Height"] = "Alto",
    ["Icon"] = "Icono",
    ["Icon Size"] = "Tamaño del icono",
    ["Icon X Offset"] = "Desplazamiento X del icono",
    ["Name Font Size"] = "Tamaño de fuente del nombre",
    ["Text Settings"] = "Ajustes de texto",
    ["Independent progress bars for spell-triggered and aura-style tracking."] = "Barras de progreso independientes para seguimiento por hechizos y por auras.",
    ["Live Preview & Drop Zone"] = "Vista previa y zona de arrastre",
    ["Aura Catalog"] = "Catálogo de auras",
    ["Catalog Quick Pick"] = "Selección rápida del catálogo",
    ["Create Bar for Selected"] = "Crear barra para la selección",
    ["No bars configured yet."] = "Aún no hay barras configuradas.",
    ["+ Add New Bar"] = "+ Añadir barra nueva",
    ["+ Add Bar"] = "+ Añadir barra",
    ["Select Bar"] = "Seleccionar barra",
    ["Tracking Configuration"] = "Configuración de seguimiento",
    ["Tracking Mode"] = "Modo de seguimiento",
    ["Unit to Track"] = "Unidad a seguir",
    ["Bar Dimensions"] = "Dimensiones de la barra",
    ["Show Spark"] = "Mostrar destello",
    ["Fill Color"] = "Color de relleno",
    ["Show Icon"] = "Mostrar icono",
    ["Show Buff Name"] = "Mostrar nombre del buff",
    ["Show Duration Timer"] = "Mostrar temporizador de duración",
    ["Manual Timer Duration"] = "Duración manual del temporizador",
    ["Timer Duration (Seconds)"] = "Duración del temporizador (segundos)",
    ["Timer Font Size"] = "Tamaño de fuente del temporizador",
    ["Override Blizzard Duration"] = "Sobrescribir duración de Blizzard",
    ["Selected:|r "] = "Seleccionado:|r ",
    ["— Delete Selected"] = "— Eliminar selección",
    ["|cff888888Your catalog is empty. Drag a spell above to start.|r"] = "|cff888888Tu catálogo está vacío. Arrastra un hechizo arriba para empezar.|r",
    ["KUI Preview"] = "Vista previa de KUI",
    ["Live layout around minimap"] = "Vista previa en vivo alrededor del minimapa",
    ["Global"] = "Global",
    ["Class Colour Accent"] = "Acento con color de clase",
    ["Accent Colour"] = "Color de acento",
    ["Frame Strata"] = "Estrato del marco",
    ["Font Outline"] = "Contorno de la fuente",
    ["Font Shadow"] = "Sombra de la fuente",
    ["Font Shadow Colour"] = "Color de la sombra de la fuente",
    ["Font Shadow X Offset"] = "Desplazamiento X de la sombra",
    ["Font Shadow Y Offset"] = "Desplazamiento Y de la sombra",
    ["Reset Options"] = "Restablecer opciones",
    ["Reset All"] = "Restablecer todo",
    ["Reset: %s"] = "Restablecer: %s",
    ["Select Options to Reset..."] = "Selecciona opciones para restablecer...",
    ["Time"] = "Hora",
    ["System Stats"] = "Estadísticas del sistema",
    ["Location"] = "Ubicación",
    ["Coordinates"] = "Coordenadas",
    ["Instance Difficulty"] = "Dificultad de instancia",
    ["Tooltips"] = "Tooltips",
    ["Sharing"] = "Compartir",
    ["Element Options"] = "Opciones del elemento",
    ["Text Colour"] = "Color del texto",
    ["Time Zone"] = "Zona horaria",
    ["Time Format"] = "Formato de hora",
    ["Layout"] = "Diseño",
    ["Stats Creation"] = "Creación de estadísticas",
    ["Display String"] = "Cadena de texto",
    ["Add Stat"] = "Añadir estadística",
    ["Display Sub Zone"] = "Mostrar subzona",
    ["Colour By"] = "Colorear por",
    ["Abbreviated Difficulty"] = "Dificultad abreviada",
    ["Force Hide Blizzard Banner"] = "Ocultar forzosamente el banner de Blizzard",
    ["Coordinate Format"] = "Formato de coordenadas",
    ["Exporting"] = "Exportación",
    ["Export String..."] = "Cadena de exportación...",
    ["Export Profile"] = "Exportar perfil",
    ["Importing"] = "Importación",
    ["Import String..."] = "Cadena de importación...",
    ["|cFF8080FFTime Frame|r Options"] = "Opciones de |cFF8080FFmarco de hora|r",
    ["Date Options"] = "Opciones de fecha",
    ["Show Date"] = "Mostrar fecha",
    ["Date Format"] = "Formato de fecha",
    ["Show Alternate Time Zone"] = "Mostrar zona horaria alternativa",
    ["Show Instance Lockouts"] = "Mostrar bloqueos de instancia",
    ["|cFF8080FFSystemStats|r Frame Options"] = "Opciones del marco de |cFF8080FFSystemStats|r",
    ["Vault Options"] = "Opciones del cofre",
    ["Vault Display Options"] = "Opciones de visualización del cofre",
    ["Show Vault Information"] = "Mostrar información del cofre",
    ["Anchor From"] = "Anclar desde",
    ["Anchor To"] = "Anclar a",
    ["X Offset"] = "Desplazamiento X",
    ["Y Offset"] = "Desplazamiento Y",
    ["Font Size"] = "Tamaño de fuente",
    ["Top Left"] = "Arriba izquierda",
    ["Top"] = "Arriba",
    ["Top Right"] = "Arriba derecha",
    ["Left"] = "Izquierda",
    ["Center"] = "Centro",
    ["Right"] = "Derecha",
    ["Bottom Left"] = "Abajo izquierda",
    ["Bottom"] = "Abajo",
    ["Bottom Right"] = "Abajo derecha",
    ["Background"] = "Fondo",
    ["Low"] = "Bajo",
    ["Medium"] = "Medio",
    ["High"] = "Alto",
    ["Dialog"] = "Diálogo",
    ["Fullscreen"] = "Pantalla completa",
    ["Fullscreen Dialog"] = "Diálogo a pantalla completa",
    ["None"] = "Ninguno",
    ["Thick Outline"] = "Contorno grueso",
    ["Monochrome"] = "Monocromo",
    ["Local"] = "Local",
    ["Realm"] = "Reino",
    ["12-Hour"] = "12 horas",
    ["24-Hour"] = "24 horas",
    ["Reaction"] = "Reacción",
    ["Custom"] = "Personalizado",
    ["Accent"] = "Acento",
    ["Raid"] = "Banda",
    ["Mythic Plus"] = "Míticas+",
    ["World"] = "Mundo",
    ["Update Interval (Seconds)"] = "Intervalo de actualización (segundos)",
    ["Update Interval (Seconds) - |cFFFF4040High CPU Usage|r"] = "Intervalo de actualización (segundos) - |cFFFF4040alto uso de CPU|r",
    ["Supported Date Tokens:"] = "Tokens de fecha compatibles:",
    ["New Line ('\\n') is also supported!"] = "La nueva línea ('\\n') también es compatible.",
    ["Date (01 Jan 99)"] = "Fecha (01 Ene 99)",
    ["Date (01 January 1999)"] = "Fecha (01 Enero 1999)",
    ["Bandwidth (Down)"] = "Ancho de banda (bajada)",
    ["Bandwidth (Up)"] = "Ancho de banda (subida)",
    ["Abbreviated Week Day (e.g. Mon)"] = "Día abreviado de la semana (p. ej. Lun)",
    ["Full Week Day (e.g. Monday)"] = "Día completo de la semana (p. ej. Lunes)",
    ["Abbreviated Month (e.g. Jan)"] = "Mes abreviado (p. ej. Ene)",
    ["Full Month (e.g. January)"] = "Mes completo (p. ej. Enero)",
    ["Numerical Day (e.g. 01-31)"] = "Día numérico (p. ej. 01-31)",
    ["Numerical Month (e.g. 01-12)"] = "Mes numérico (p. ej. 01-12)",
    ["Two-Digit Year (e.g. 25)"] = "Año de dos dígitos (p. ej. 25)",
    ["Four-Digit Year (e.g. 2024)"] = "Año de cuatro dígitos (p. ej. 2024)",
    ["24-Hour Format (e.g. 00-24)"] = "Formato de 24 horas (p. ej. 00-24)",
    ["12-Hour Format (e.g. 01-12)"] = "Formato de 12 horas (p. ej. 01-12)",
    ["Minute (e.g. 00-59)"] = "Minuto (p. ej. 00-59)",
    ["Day of the Year (e.g. 001-366)"] = "Día del año (p. ej. 001-366)",
    ["Week Number (e.g. 01-52)"] = "Número de semana (p. ej. 01-52)",
    ["Time Zone (e.g. UTC)"] = "Zona horaria (p. ej. UTC)",
    ["This shows you the |cFF8080FFsub zone|r instead of the |cFF8080FFmain zone|r."] = "Esto te muestra la |cFF8080FFsubzona|r en lugar de la |cFF8080FFzona principal|r.",
    ["This will show you the alternate time zone from your selection in the |cFF8080FFTime|r Tab."] = "Esto mostrará la zona horaria alternativa según tu selección en la pestaña |cFF8080FFHora|r.",
}

esES["Módulo cargado. Actualizando página..."] = "Módulo cargado. Actualizando página..."
esES["Este módulo está configurado como LoadOnDemand y se cargará al abrir esta página."] = "Este módulo está configurado como LoadOnDemand y se cargará al abrir esta página."
esES["No se puede cargar este módulo mientras estás en combate. Sal de combate y pulsa Reintentar."] = "No se puede cargar este módulo mientras estás en combate. Sal de combate y pulsa Reintentar."
esES["No se pudo cargar el addon del módulo ("] = "No se pudo cargar el addon del módulo ("
esES["El módulo Installer se carga automáticamente al iniciar sesión."] = "El módulo Installer se carga automáticamente al iniciar sesión."
esES["Si no aparece la página completa, revisa que `KullThranUI_Installer` esté activado en la lista de AddOns y recarga la UI."] = "Si no aparece la página completa, revisa que `KullThranUI_Installer` esté activado en la lista de AddOns y recarga la UI."
esES["Global Font"] = "Fuente global"
esES["Multicolor icons keep their original colors so the built-in backgrounds/details do not break."] = "Los iconos multicolor conservan sus colores originales para que los fondos y detalles integrados no se rompan."
esES["These toggles map to the module's master enable flag when the module supports one. A reload is recommended after changes."] = "Estos interruptores se vinculan a la opción principal de activación del módulo cuando el módulo la soporta. Se recomienda recargar tras los cambios."
esES["— Delete Selected"] = "— Eliminar selección"
esES["Módulo cargado. Actualizando página..."] = "Módulo cargado. Actualizando página..."
esES["Este módulo está configurado como LoadOnDemand y se cargará al abrir esta página."] = "Este módulo está configurado como LoadOnDemand y se cargará al abrir esta página."
esES["No se puede cargar este módulo mientras estás en combate. Sal de combate y pulsa Reintentar."] = "No se puede cargar este módulo mientras estás en combate. Sal de combate y pulsa Reintentar."
esES["No se pudo cargar el addon del módulo ("] = "No se pudo cargar el addon del módulo ("
esES["El módulo Installer se carga automáticamente al iniciar sesión."] = "El módulo Installer se carga automáticamente al iniciar sesión."
esES["Si no aparece la página completa, revisa que `KullThranUI_Installer` esté activado en la lista de AddOns y recarga la UI."] = "Si no aparece la página completa, revisa que `KullThranUI_Installer` esté activado en la lista de AddOns y recarga la UI."
enUS["Módulo cargado. Actualizando página..."] = "Module loaded. Refreshing page..."
enUS["Este módulo está configurado como LoadOnDemand y se cargará al abrir esta página."] = "This module is configured as LoadOnDemand and will load when you open this page."
enUS["No se puede cargar este módulo mientras estás en combate. Sal de combate y pulsa Reintentar."] = "This module cannot be loaded while you are in combat. Leave combat and press Retry."
enUS["No se pudo cargar el addon del módulo ("] = "Could not load the module addon ("
enUS["El módulo Installer se carga automáticamente al iniciar sesión."] = "The Installer module loads automatically on login."
enUS["Si no aparece la página completa, revisa que `KullThranUI_Installer` esté activado en la lista de AddOns y recarga la UI."] = "If the full page does not appear, check that `KullThranUI_Installer` is enabled in the AddOns list and reload the UI."

esES["Automation and quality-of-life settings for KullThranUI."] = "Automatizaciones y ajustes de calidad de vida para KullThranUI."
esES["Combat Res"] = "Combat Res"
esES["Enable Combat Res Timer"] = "Activar temporizador de Combat Res"
esES["Death as Warning"] = "Avisar cuando alguien muere"
esES["Equipment Reminder"] = "Recordatorio de equipamiento"
esES["Enable Equipment Reminder"] = "Activar recordatorio de equipamiento"
esES["Show on instance entry"] = "Mostrar al entrar en instancia"
esES["Show on ready check"] = "Mostrar en ready check"
esES["Enable enchant checker"] = "Activar comprobacion de encantamientos"
esES["Use same enchant rules for all specs"] = "Usar las mismas reglas de encantamientos para todas las especializaciones"
esES["Auto-hide delay"] = "Retraso para ocultarse"
esES["Icon size"] = "Tamano del icono"
esES["Preview Equipment Reminder"] = "Previsualizar recordatorio de equipamiento"
esES["Capture Current Enchants"] = "Capturar encantamientos actuales"
esES["Clear Captured Enchants"] = "Borrar encantamientos guardados"
esES["Equipment set"] = "Set de equipo"
esES["Current Equipped Gear"] = "Equipo equipado actualmente"
esES["Choose which equipment set should be checked and shown in the reminder preview. Leave it on Current Equipped Gear if you only want to inspect what you have equipped now."] = "Elige que set de equipo quieres comprobar y mostrar en la previsualizacion del recordatorio. Dejalo en Equipo equipado actualmente si solo quieres inspeccionar lo que llevas puesto ahora."
esES["Set ready: %s"] = "Set correcto: %s"
esES["%d Gear Issues"] = "%d problemas de equipo"
esES["Target set: %s"] = "Set objetivo: %s"
esES["Currently equipped"] = "Equipado actualmente"
esES["Currently equipped item differs"] = "El objeto equipado actualmente es distinto"
esES["Target set leaves this slot empty"] = "El set objetivo deja este hueco vacio"
esES["Items / Loot"] = "Objetos / Botin"
esES["Faster Auto Loot"] = "Saqueo automatico mas rapido"
esES["Suppress Loot Warnings"] = "Suprimir avisos de botin"
esES["Easy Item Destroy"] = "Destruir objetos facilmente"
esES["Auto Insert Keystone"] = "Insertar piedra angular automaticamente"
esES["AH Current Expansion"] = "Subasta de la expansion actual"
esES["UI Clutter"] = "Limpieza visual de la interfaz"
esES["Hide Alerts"] = "Ocultar alertas"
esES["Hide Talking Head"] = "Ocultar Talking Head"
esES["Hide Event Toasts"] = "Ocultar avisos flotantes de eventos"
esES["Hide Zone Text"] = "Ocultar texto de zona"
esES["Skip Queue Confirmation"] = "Saltar confirmacion de cola"
esES["Hide Minimap Icon"] = "Ocultar icono del minimapa"
esES["Death / Durability / Repair"] = "Muerte / Durabilidad / Reparacion"
esES["Do not release spirit by accident"] = "No soltar espiritu por accidente"
esES["Repair automatically"] = "Reparar automaticamente"
esES["Use guild funds"] = "Usar fondos de hermandad"
esES["Repair summary in chat"] = "Mostrar resumen de reparacion en el chat"
esES["Durability Warning"] = "Aviso de durabilidad"
esES["Warning Threshold"] = "Umbral de aviso"
esES["System Optimizations: Presets"] = "Optimizaciones del sistema: preajustes"
esES["Optimal FPS Settings"] = "Ajustes optimos para FPS"
esES["Revert Settings"] = "Revertir ajustes"
esES["Render & Display"] = "Renderizado y pantalla"
esES["Graphics Quality"] = "Calidad grafica"
esES["View Distance & Detail"] = "Distancia de vision y detalle"
esES["Advanced Settings"] = "Ajustes avanzados"
esES["FPS Limits"] = "Limites de FPS"
esES["Post Processing"] = "Postprocesado"
esES["Spell Queue Window"] = "Ventana de cola de hechizos"
esES["Spell Queue Window (ms)"] = "Ventana de cola de hechizos (ms)"
esES["Recommended: 100-400ms. Lower is more responsive; higher is more tolerant to latency."] = "Recomendado: 100-400 ms. Mas bajo responde antes; mas alto tolera mejor la latencia."
esES["Diagnostics"] = "Diagnostico"
esES["Enable AddOn Profiler"] = "Activar perfilador de AddOns"
esES["Enables script profiling so the real-time monitor can show addon metrics after a reload."] = "Activa el perfilado de scripts para que el monitor en tiempo real muestre metricas del addon tras recargar la UI."
esES["Real-Time Monitor"] = "Monitor en tiempo real"
esES["Warming up..."] = "Calentando..."
esES["Profiler unavailable."] = "Perfilador no disponible."
esES["Average (60 ticks):"] = "Media (60 ticks):"
esES["Last tick:"] = "Ultimo tick:"
esES["Peak:"] = "Pico:"
esES["Encounter average:"] = "Media en encuentro:"
esES["Apply Recommended"] = "Aplicar recomendado"
esES["Revert Setting"] = "Revertir ajuste"
esES["Enabled"] = "Activado"
esES["Disabled"] = "Desactivado"
esES["Level %d"] = "Nivel %d"
esES["%s set to %s."] = "%s establecido en %s."
esES["Could not set %s."] = "No se pudo establecer %s."
esES["%s restored to %s."] = "%s restaurado a %s."
esES["Applied %d recommended system settings."] = "Se aplicaron %d ajustes recomendados del sistema."
esES["Restored %d saved system settings."] = "Se restauraron %d ajustes guardados del sistema."
esES["Some system changes need a UI reload to fully apply."] = "Algunos cambios del sistema requieren recargar la UI para aplicarse por completo."
esES["Addon profiling has been enabled. Reload the UI to start collecting metrics."] = "El perfilado de AddOns se ha activado. Recarga la UI para empezar a recopilar metricas."
esES["Addon profiling is already enabled."] = "El perfilado de AddOns ya esta activado."
esES["Hold Alt %.1f"] = "Manten Alt %.1f"
esES["Durability low: %d%%"] = "Durabilidad baja: %d%%"
esES["Unknown"] = "Desconocido"
esES["died"] = "murio"
esES["Enchants OK"] = "Encantamientos OK"
esES["%d Enchant Issues"] = "%d problemas de encantamiento"
esES["Empty"] = "Vacio"
esES["Render Scale"] = "Escala de renderizado"
esES["VSync"] = "VSync"
esES["Multisampling"] = "Multimuestreo"
esES["Low Latency Mode"] = "Modo de baja latencia"
esES["Anti-Aliasing"] = "Suavizado de bordes"
esES["Shadow Quality"] = "Calidad de sombras"
esES["Liquid Detail"] = "Detalle de liquidos"
esES["Particle Density"] = "Densidad de particulas"
esES["SSAO"] = "SSAO"
esES["Depth Effects"] = "Efectos de profundidad"
esES["Compute Effects"] = "Efectos de calculo"
esES["Outline Mode"] = "Modo de contorno"
esES["Texture Resolution"] = "Resolucion de texturas"
esES["Spell Density"] = "Densidad de hechizos"
esES["Projected Textures"] = "Texturas proyectadas"
esES["View Distance"] = "Distancia de vision"
esES["Environment Detail"] = "Detalle del entorno"
esES["Ground Clutter"] = "Vegetacion del suelo"
esES["Triple Buffering"] = "Triple buffering"
esES["Texture Filtering"] = "Filtrado de texturas"
esES["Ray Traced Shadows"] = "Sombras con trazado de rayos"
esES["Resample Quality"] = "Calidad de remuestreo"
esES["Graphics API"] = "API grafica"
esES["Physics Integration"] = "Integracion de fisicas"
esES["Target FPS"] = "FPS objetivo"
esES["Background FPS Enabled"] = "FPS en segundo plano activados"
esES["Background FPS"] = "FPS en segundo plano"
esES["Resample Sharpness"] = "Nitidez de remuestreo"
esES["Camera Shake"] = "Sacudida de camara"
esES["Accept resurrection"] = "Aceptar resurreccion"
esES["Accept summon"] = "Aceptar invocacion"
esES["Auto loot delay"] = "Retraso del botin automatico"
esES["Automate gossip"] = "Automatizar dialogos"
esES["Automate quests"] = "Automatizar misiones"
esES["Automation"] = "Automatizacion"
esES["Block duels"] = "Bloquear duelos"
esES["Block friend requests"] = "Bloquear solicitudes de amistad"
esES["Block party invites"] = "Bloquear invitaciones de grupo"
esES["Block pet battle duels"] = "Bloquear duelos de mascotas"
esES["Block requested invites"] = "Bloquear invitaciones solicitadas"
esES["Block shared quests"] = "Bloquear misiones compartidas"
esES["Blocks"] = "Bloqueos"
esES["Cancel"] = "Cancelar"
esES["Combat plates"] = "Placas en combate"
esES["Disable screen effects"] = "Desactivar efectos de pantalla"
esES["Disable screen glow"] = "Desactivar brillo de pantalla"
esES["Enable Module"] = "Activar modulo"
esES["Enhanced Friend List"] = "Lista de amigos mejorada"
esES["Enhancements"] = "Mejoras"
esES["Faster movie skip"] = "Saltar cinematicas mas rapido"
esES["Graphics and Sound"] = "Graficos y sonido"
esES["Groups"] = "Grupos"
esES["Invite from whispers"] = "Invitar desde susurros"
esES["Keep audio synced"] = "Mantener el audio sincronizado"
esES["Legacy Game Options"] = "Opciones de juego clasicas"
esES["Mail font size"] = "Tamano de fuente del correo"
esES["Max camera zoom"] = "Zoom maximo de camara"
esES["Party from friends"] = "Grupo desde amigos"
esES["Persistent LFG note"] = "Nota persistente de LFG"
esES["Persistent LFG note text"] = "Texto de la nota persistente de LFG"
esES["Quest font size"] = "Tamano de fuente de las misiones"
esES["Queue from friends"] = "Cola desde amigos"
esES["Release in PvP"] = "Liberar en JcJ"
esES["Reload UI"] = "Recargar UI"
esES["Remove raid restrictions"] = "Quitar restricciones de banda"
esES["Reset all Enhancements settings to defaults?"] = "Restablecer toda la configuracion de Mejoras a sus valores predeterminados?"
esES["Reset Module Defaults"] = "Restablecer valores por defecto del modulo"
esES["Resize mail text"] = "Redimensionar texto del correo"
esES["Resize quest text"] = "Redimensionar texto de misiones"
esES["Set weather density"] = "Configurar densidad del clima"
esES["Social"] = "Social"
esES["Sync from friends"] = "Sincronizar desde amigos"
esES["Text Size"] = "Tamano del texto"
esES["Treat communities as friends"] = "Tratar las comunidades como amigos"
esES["Treat guild as friends"] = "Tratar la hermandad como amigos"
esES["Weather density"] = "Densidad del clima"
esES["Whisper keyword"] = "Palabra clave de susurro"
esES["Whispers only from friends"] = "Susurros solo de amigos"
esES["Views"] = "Vistas"
esES["Choose a focus area to reduce noise and keep related options together."] = "Elige un area para reducir ruido y mantener juntas las opciones relacionadas."
esES["Open one view at a time to keep related options together and make the module easier to navigate."] = "Abre una sola vista cada vez para mantener juntas las opciones relacionadas y hacer que el modulo sea mas facil de navegar."
esES["Dungeon & Raid"] = "Mazmorras y bandas"
esES["Combat timers, gear checks, loot helpers, and repair safeguards for dungeons and raids."] = "Temporizadores de combate, revision de equipo, ayudas de botin y protecciones de reparacion para mazmorras y bandas."
esES["Automation & Social"] = "Automatizacion y social"
esES["Quest automation, invite rules, group tools, and social quality-of-life settings."] = "Automatizacion de misiones, reglas de invitacion, herramientas de grupo y ajustes sociales de calidad de vida."
esES["Interface & Comfort"] = "Interfaz y comodidad"
esES["Visual cleanup, text sizing, and general comfort options for the client UI."] = "Limpieza visual, tamano del texto y opciones generales de comodidad para la interfaz."
esES["System Tuning"] = "Ajustes del sistema"
esES["Performance presets, graphics CVars, spell queue tuning, and live diagnostics."] = "Preajustes de rendimiento, CVars graficos, ajuste de la cola de hechizos y diagnostico en tiempo real."
esES["Use this block for one-click actions before touching individual settings."] = "Usa este bloque para acciones de un clic antes de tocar ajustes individuales."
esES["Backups are stored automatically when you apply the preset, so you can revert afterwards."] = "Las copias de seguridad se guardan automaticamente al aplicar el preajuste, asi que luego puedes revertir."
esES["Keep this section collapsed unless you are actively testing performance."] = "Manten esta seccion cerrada salvo que estes probando rendimiento activamente."
esES["Party Frames"] = "Marcos de grupo"
esES["Dungeons"] = "Mazmorras"
esES["Raid 40"] = "Banda 40"
esES["Manage"] = "Gestionar"
esES["Horizontal"] = "Horizontal"
esES["Vertical"] = "Vertical"
esES["Top Left"] = "Arriba izquierda"
esES["Top Right"] = "Arriba derecha"
esES["Bottom Left"] = "Abajo izquierda"
esES["Bottom Right"] = "Abajo derecha"
esES["Current / Max"] = "Actual / Max"
esES["Percent"] = "Porcentaje"
esES["Deficit"] = "Deficit"
esES["Dungeons"] = "Mazmorras"
esES["DPS / Tank"] = "DPS / Tanque"
esES["Heal"] = "Sanacion"
esES["Party Frames layout change saved. It will be applied after combat."] = "Cambio de disposicion de Marcos de grupo guardado. Se aplicara al salir de combate."
esES["Party Frames profile change saved. It will be applied after combat."] = "Cambio de perfil de Marcos de grupo guardado. Se aplicara al salir de combate."
esES["Party Frames presets cannot be applied during combat."] = "No se pueden aplicar presets de Marcos de grupo durante el combate."
esES["Party Frames aura spell visibility will refresh after combat."] = "La visibilidad de hechizos de aura de Marcos de grupo se actualizara al salir de combate."
esES["Manage discovered aura spells without expanding the whole options page."] = "Gestiona los hechizos de aura descubiertos sin expandir toda la pagina de opciones."
esES["Show All"] = "Mostrar todo"
esES["Clear Search"] = "Limpiar busqueda"
esES["No aura spells have been discovered yet. Enable test frames or join a group to populate this list."] = "Aun no se han descubierto hechizos de aura. Activa los marcos de prueba o entra en un grupo para rellenar esta lista."
esES["Buff"] = "Buff"
esES["Aura"] = "Aura"
esES["Missing"] = "Faltante"
esES["All"] = "Todo"
esES["Buffs"] = "Buffs"
esES["Auras"] = "Auras"
esES["%d shown / %d discovered, %d hidden"] = "%d mostrados / %d descubiertos, %d ocultos"
esES["Spell Visibility"] = "Visibilidad de hechizos"
esES["Enable Auras"] = "Activar auras"
esES["Buff Icons"] = "Iconos de buffs"
esES["Only My Buffs"] = "Solo mis buffs"
esES["Debuff Icons"] = "Iconos de debuffs"
esES["Show All Debuffs"] = "Mostrar todos los debuffs"
esES["Dispel Border"] = "Borde de dispel"
esES["Crowd Control"] = "Control de masas"
esES["Missing Class Buff"] = "Buff de clase faltante"
esES["Show Missing Class Buff"] = "Mostrar buff de clase faltante"
esES["Aura Icon Size"] = "Tamano de icono de aura"
esES["Buff Icon Count"] = "Cantidad de iconos de buffs"
esES["Debuff Icon Count"] = "Cantidad de iconos de debuffs"
esES["Dispel Border Alpha"] = "Alpha del borde de dispel"
esES["Dispel Border Size"] = "Tamano del borde de dispel"
esES["Dispel Gradient Alpha"] = "Alpha del degradado de dispel"
esES["Dispel Gradient Size"] = "Tamano del degradado de dispel"
esES["Missing Buff Size"] = "Tamano de buff faltante"
esES["Icon Position Offsets"] = "Desplazamientos de posicion de iconos"
esES["Buff Icons X"] = "Iconos de buffs X"
esES["Buff Icons Y"] = "Iconos de buffs Y"
esES["Debuff Icons X"] = "Iconos de debuffs X"
esES["Debuff Icons Y"] = "Iconos de debuffs Y"
esES["Aura Icon X"] = "Icono de aura X"
esES["Aura Icon Y"] = "Icono de aura Y"
esES["Missing Buff X"] = "Buff faltante X"
esES["Missing Buff Y"] = "Buff faltante Y"
esES["Track Mark of the Wild"] = "Rastrear Marca de lo salvaje"
esES["Track Fortitude"] = "Rastrear Entereza"
esES["Track Intellect"] = "Rastrear Intelecto"
esES["Track Battle Shout"] = "Rastrear Grito de batalla"
esES["Track Skyfury"] = "Rastrear Furia del cielo"
esES["Track Blessing of the Bronze"] = "Rastrear Bendicion del Bronce"
esES["Arena uses its own Party Frames layout profile."] = "Arena usa su propio perfil de disposicion de Marcos de grupo."
esES["Live changes update the native Party Frames module and apply out of combat."] = "Los cambios en vivo actualizan el modulo nativo de Marcos de grupo y se aplican fuera de combate."
esES["Live changes update the Party Frames addon module and apply out of combat."] = "Los cambios en vivo actualizan el addon de Marcos de grupo y se aplican fuera de combate."
esES["Frame Width"] = "Ancho del marco"
esES["Frame Height"] = "Alto del marco"
esES["Frame Scale"] = "Escala del marco"
esES["Frame Padding"] = "Relleno del marco"
esES["Frame Spacing"] = "Espaciado de marcos"
esES["Growth Direction"] = "Direccion de crecimiento"
esES["Growth Anchor"] = "Ancla de crecimiento"
esES["Show Player"] = "Mostrar jugador"
esES["Color by Class"] = "Color por clase"
esES["Health Texture"] = "Textura de salud"
esES["Absorb Texture"] = "Textura de absorcion"
esES["Show Absorb Bar"] = "Mostrar barra de absorcion"
esES["Show Power Bar"] = "Mostrar barra de recurso"
esES["Power Bar Height"] = "Alto de barra de recurso"
esES["Health Text"] = "Texto de salud"
esES["Role Icon Style"] = "Estilo de icono de rol"
esES["Text Font"] = "Fuente del texto"
esES["Text Outline"] = "Contorno del texto"
esES["Name Text Size"] = "Tamano del nombre"
esES["Health Text Size"] = "Tamano del texto de salud"
esES["Name X Offset"] = "Desplazamiento X del nombre"
esES["Name Y Offset"] = "Desplazamiento Y del nombre"
esES["Health X Offset"] = "Desplazamiento X de salud"
esES["Health Y Offset"] = "Desplazamiento Y de salud"
esES["Abbreviate Health"] = "Abreviar salud"
esES["Show Leader Icon"] = "Mostrar icono de lider"
esES["Show Raid Mark Icons"] = "Mostrar marcas de banda"
esES["Raid Mark Icons"] = "Marcas de banda"
esES["Main aura toggles and icon limits."] = "Toggles principales de auras y limites de iconos."
esES["Aura tracking uses Midnight unit aura slots with raid, important, crowd control and dispel filtering."] = "El rastreo de auras usa ranuras de aura de unidad de Midnight con filtros de banda, importantes, control de masas y dispel."
esES["Aura Basics"] = "Auras basicas"
esES["Icon Positions"] = "Posiciones de iconos"
esES["Missing Buffs"] = "Buffs faltantes"
esES["Quick Actions"] = "Acciones rapidas"
esES["Roster"] = "Lista de grupo"
esES["Dungeon Layout"] = "Disposicion de mazmorra"
esES["Raid Layout"] = "Disposicion de banda"
esES["Raid 40 Layout"] = "Disposicion de banda 40"
esES["Arena Layout"] = "Disposicion de arena"
esES["Appearance"] = "Apariencia"
esES["Text"] = "Texto"
esES["Indicators"] = "Indicadores"
esES["Aura Basics"] = "Auras basicas"
esES["Dispel"] = "Dispel"
esES["Sorting"] = "Ordenacion"
esES["Grouped Raid Headers"] = "Encabezados de grupo de banda"
esES["Raid Test Members"] = "Miembros de prueba de banda"
esES["Raid 40 preview is fixed at 40 members while sharing the Raid layout."] = "La vista previa de Banda 40 esta fija en 40 miembros y comparte la disposicion de Banda."
esES["Group Spacing"] = "Espaciado de grupos"
esES["Groups Per Row"] = "Grupos por fila"
esES["Sorting values are stored by Party Frames and applied only outside combat."] = "Los valores de ordenacion se guardan en Marcos de grupo y solo se aplican fuera de combate."
esES["Enable Sorting"] = "Activar ordenacion"
esES["Sort by Class"] = "Ordenar por clase"
esES["Sort Alphabetically"] = "Ordenar alfabeticamente"
esES["Separate Melee / Ranged"] = "Separar melee / ranged"
esES["Start Party / Dungeon Test"] = "Iniciar prueba de grupo / mazmorra"
esES["Stop Party / Dungeon Test"] = "Detener prueba de grupo / mazmorra"
esES["Start Raid Test"] = "Iniciar prueba de banda"
esES["Stop Raid Test"] = "Detener prueba de banda"
esES["Start Raid 40 Test"] = "Iniciar prueba de banda 40"
esES["Stop Raid 40 Test"] = "Detener prueba de banda 40"
esES["Stop Test Frames"] = "Detener marcos de prueba"
esES["Highlight Visible Party Frames"] = "Resaltar Marcos de grupo visibles"
esES["Test mode uses native Party Frames samples and unlock-mode movers."] = "El modo de prueba usa muestras nativas de Marcos de grupo y movedores del modo desbloqueo."
esES["Test mode uses Party Frames addon samples and unlock-mode movers."] = "El modo de prueba usa muestras del addon Marcos de grupo y movedores del modo desbloqueo."
esES["Apply DPS / Tank Preset"] = "Aplicar preset DPS / Tanque"
esES["Apply Heal Preset"] = "Aplicar preset Sanacion"
esES["Restore Defaults"] = "Restaurar valores por defecto"
esES["Applying a preset or restoring defaults updates Party, Raid, Arena and Unlock Mode positions."] = "Aplicar un preset o restaurar valores actualiza las posiciones de Grupo, Banda, Arena y Modo desbloqueo."
esES["Apply Party Frames DPS / Tank preset?"] = "Aplicar preset DPS / Tanque de Marcos de grupo?"
esES["Apply Party Frames Heal preset?"] = "Aplicar preset Sanacion de Marcos de grupo?"
esES["Restore the current preset to its factory defaults?"] = "Restaurar el preset actual a sus valores de fabrica?"
esES["Auto Profile by Spec"] = "Perfil automatico por especializacion"
esES["Specialization"] = "Especializacion"
esES["Profile for Selected Spec"] = "Perfil para la especializacion seleccionada"
esES["Auto maps tank and DPS specs to DPS / Tank, healers to Heal, and Augmentation to Heal."] = "Auto asigna especializaciones tanque y DPS a DPS / Tanque, sanadores a Sanacion y Aumento a Sanacion."
esES["Current profile: "] = "Perfil actual: "
esES["Current spec assignment: "] = "Asignacion de especializacion actual: "
esES["Current spec assignment: Auto / none"] = "Asignacion de especializacion actual: Auto / ninguna"
esES["Export and import either the full KullThranUI profile or only Party Frames."] = "Exporta e importa el perfil completo de KullThranUI o solo Marcos de grupo."
esES["Export Party Frames"] = "Exportar Marcos de grupo"
esES["Import Party Frames"] = "Importar Marcos de grupo"
esES["|cffff5555This merges imported Party Frames into the active profile.|r"] = "|cffff5555Esto fusiona los Marcos de grupo importados con el perfil activo.|r"
esES["Roster Source"] = "Origen de lista"
esES["Party / Dungeon"] = "Grupo / Mazmorra"
esES["No group members or Party Frames units are visible right now."] = "No hay miembros de grupo ni unidades de Marcos de grupo visibles ahora mismo."
esES["Status: Native KullThranUI module. Protected unit assignments and layout changes are deferred during combat."] = "Estado: modulo nativo de KullThranUI. Las asignaciones protegidas de unidad y los cambios de disposicion se aplazan durante el combate."
esES["Status: External KullThranUI module addon. Protected unit assignments and layout changes are deferred during combat."] = "Estado: addon externo de modulo KullThranUI. Las asignaciones protegidas de unidad y los cambios de disposicion se aplazan durante el combate."
esES["Changing the master Party Frames addon flag requires a UI reload so protected frame ownership is rebuilt cleanly."] = "Cambiar el interruptor maestro del addon Marcos de grupo requiere recargar la UI para reconstruir correctamente la propiedad de marcos protegidos."
esES["Grow Direction"] = "Direccion de crecimiento"
esES["Show Aura Icons"] = "Mostrar iconos de auras"
esES["Show Buff Icons"] = "Mostrar iconos de buffs"
esES["Show Debuff Icons"] = "Mostrar iconos de debuffs"
esES["Show Ready Check Icons"] = "Mostrar iconos de listo"
esES["Show Leader Icons"] = "Mostrar iconos de lider"
esES["Show Player Frame"] = "Mostrar marco del jugador"
esES["Pixel Perfect"] = "Pixel perfect"
esES["Class Colors"] = "Colores de clase"
esES["Absorb Overlay"] = "Superposicion de absorcion"
esES["Power Bar"] = "Barra de recurso"
esES["Name Font Size"] = "Tamano de fuente del nombre"
esES["Health Font Size"] = "Tamano de fuente de salud"
esES["Name Offset X"] = "Desplazamiento X del nombre"
esES["Name Offset Y"] = "Desplazamiento Y del nombre"
esES["Health Offset X"] = "Desplazamiento X de salud"
esES["Health Offset Y"] = "Desplazamiento Y de salud"
esES["Group Text Outline"] = "Contorno de texto de grupo"
esES["Abbreviate Health Text"] = "Abreviar texto de salud"
esES["Ready Check Icons"] = "Iconos de listo"
esES["Leader Icons"] = "Iconos de lider"
esES["Move each icon group without changing the frame layout."] = "Mueve cada grupo de iconos sin cambiar la disposicion del marco."
esES["Delete Selected Profile"] = "Eliminar perfil seleccionado"
esES["Load Selected"] = "Cargar seleccionado"
esES["Assign To Spec"] = "Asignar a especializacion"
esES["...and %d more."] = "...y %d mas."
esES["Party Frames %s preview - %s"] = "Vista previa de Marcos de grupo %s - %s"
esES["party"] = "grupo"
esES["raid"] = "banda"
esES["raid40"] = "banda40"
esES["arena"] = "arena"
esES["grouped raid"] = "banda agrupada"
esES["flat raid"] = "banda plana"
esES["horizontal"] = "horizontal"
esES["vertical"] = "vertical"
esES["Party Test"] = "Prueba de grupo"
esES["Stop Party Test"] = "Detener prueba de grupo"
esES["Raid Test"] = "Prueba de banda"
esES["Stop Raid Test"] = "Detener prueba de banda"
esES["Raid 40 Test"] = "Prueba de banda 40"
esES["Stop Raid 40 Test"] = "Detener prueba de banda 40"
esES["Stop Tests"] = "Detener pruebas"
esES["Scale -"] = "Escala -"
esES["Scale +"] = "Escala +"

-- Detached module pages: Unit Frames, Cast Bar, Resource Bars, CDM and shared widgets.
esES["LIVE PREVIEW"] = "VISTA PREVIA"
esES["Live Preview"] = "Vista previa"
esES["Live Preview & Drop Zone"] = "Vista previa y zona para soltar"
esES["Enable Module"] = "Activar modulo"
esES["Restore Defaults"] = "Restaurar valores por defecto"
esES["Width"] = "Anchura"
esES["Height"] = "Altura"
esES["Scale"] = "Escala"
esES["Texture"] = "Textura"
esES["Font"] = "Fuente"
esES["Font Size"] = "Tamano de fuente"
esES["Default Font"] = "Fuente predeterminada"
esES["Outline"] = "Contorno"
esES["None"] = "Ninguno"
esES["Left"] = "Izquierda"
esES["Right"] = "Derecha"
esES["Top"] = "Arriba"
esES["Bottom"] = "Abajo"
esES["Up"] = "Arriba"
esES["Down"] = "Abajo"
esES["Center"] = "Centro"
esES["Player"] = "Jugador"
esES["Target"] = "Objetivo"
esES["Focus"] = "Foco"
esES["Pet"] = "Mascota"
esES["Class"] = "Clase"
esES["Custom"] = "Personalizado"
esES["Auto"] = "Automatico"
esES["Background"] = "Fondo"
esES["Low"] = "Bajo"
esES["Medium"] = "Medio"
esES["High"] = "Alto"
esES["Dialog"] = "Dialogo"
esES["Square"] = "Cuadrado"
esES["SQUARE"] = "Cuadrado"
esES["Circle"] = "Circulo"
esES["Shield"] = "Escudo"
esES["Portrait"] = "Retrato"
esES["Thin"] = "Fino"
esES["Thick"] = "Grueso"
esES["Enabled"] = "Activado"
esES["Disable"] = "Desactivar"
esES["Disabled - Reload Required"] = "Desactivado - requiere recarga"
esES["Loaded & Enabled"] = "Cargado y activado"
esES["Loaded This Session"] = "Cargado en esta sesion"

esES["Unit Frames"] = "Marcos de unidad"
esES["Player Frame"] = "Marco del jugador"
esES["Party Frame"] = "Marco de grupo"
esES["Enable Frame"] = "Activar marco"
esES["Frame Width"] = "Anchura del marco"
esES["Frame Strata"] = "Capa del marco"
esES["Health"] = "Salud"
esES["Health Text"] = "Texto de salud"
esES["Health Height"] = "Altura de salud"
esES["Health Fill Color"] = "Color de relleno de salud"
esES["Health Background Color"] = "Color de fondo de salud"
esES["Class Colored Health"] = "Salud con color de clase"
esES["Power"] = "Recurso"
esES["Power Bar"] = "Barra de recurso"
esES["Power Bar Position"] = "Posicion de la barra de recurso"
esES["Power Height"] = "Altura de recurso"
esES["Show Solo"] = "Mostrar en solitario"
esES["Show In Party"] = "Mostrar en grupo"
esES["Show In Raid"] = "Mostrar en banda"
esES["Show Portrait"] = "Mostrar retrato"
esES["Portrait Style"] = "Estilo del retrato"
esES["Portrait Mode"] = "Modo del retrato"
esES["Portrait Facing"] = "Orientacion del retrato"
esES["Show Castbar"] = "Mostrar barra de casteo"
esES["Show Buffs"] = "Mostrar buffs"
esES["Show Debuffs"] = "Mostrar debuffs"
esES["Only Player Debuffs"] = "Solo debuffs del jugador"
esES["Text Size"] = "Tamano del texto"
esES["Name Size"] = "Tamano del nombre"
esES["Dark Theme"] = "Tema oscuro"
esES["Castbar Opacity"] = "Opacidad de la barra de casteo"
esES["Castbar Color"] = "Color de la barra de casteo"
esES["Show Absorb Bar"] = "Mostrar barra de absorcion"
esES["Absorb Texture"] = "Textura de absorcion"
esES["Absorb Color"] = "Color de absorcion"
esES["Show Class Power"] = "Mostrar recurso de clase"
esES["Class Power Style"] = "Estilo del recurso de clase"
esES["Combat Indicator"] = "Indicador de combate"
esES["Use Unlock Mode to drag Unit Frames registered by KullThranUI."] = "Usa el modo desbloqueo para arrastrar los Marcos de unidad registrados por KullThranUI."
esES["Open Unlock Mode"] = "Abrir modo desbloqueo"
esES["Reset Unit Frames Defaults"] = "Restablecer valores de Marcos de unidad"
esES["Boss Spacing"] = "Espaciado de jefes"
esES["Unitframe Tracker Preview"] = "Vista previa del rastreador de marcos"

esES["Cast Bar"] = "Barra de casteo"
esES["Polymorph"] = "Polimorfia"
esES["Restore Cast Bar Defaults"] = "Restablecer barra de casteo"
esES["This module auto-anchors above the top cooldown/resource stack. With Auto Width enabled, the width slider becomes a fallback value instead of the live width."] = "Este modulo se ancla automaticamente encima del bloque superior de cooldowns o recursos. Con Anchura automatica activada, el deslizador de anchura actua como valor de respaldo en lugar de la anchura real."
esES["Control the module state here and restore the original cast bar profile if you want to start clean."] = "Controla aqui el estado del modulo y restaura el perfil original de la barra de casteo si quieres empezar de cero."
esES["These options control how the cast bar anchors itself relative to the top cooldown or resource stack."] = "Estas opciones controlan como se ancla la barra de casteo respecto al bloque superior de cooldowns o recursos."
esES["Auto Position (SnapToTop)"] = "Posicion automatica (ajustar arriba)"
esES["Auto Width"] = "Anchura automatica"
esES["Auto Width is active, so the Width slider acts as a fallback value instead of the live bar width."] = "La anchura automatica esta activa, asi que el deslizador de anchura actua como valor de respaldo en lugar de la anchura real."
esES["Tune the overall footprint of the cast bar. These values are reflected immediately in the live preview."] = "Ajusta el tamano general de la barra de casteo. Estos valores se reflejan al instante en la vista previa."
esES["Choose the texture and base colors for the cast bar body. Class Color overrides the live fill while preserving your saved manual color."] = "Elige la textura y los colores base de la barra de casteo. Color de clase sustituye el relleno visible conservando tu color manual guardado."
esES["Color by Class"] = "Color por clase"
esES["Class Color"] = "Color de clase"
esES["Bar Color"] = "Color de la barra"
esES["Bar Color remains as your fallback color, but the visible bar now uses your player's class color."] = "Color de la barra queda como color de respaldo, pero la barra visible usa ahora el color de clase de tu personaje."
esES["Text Color"] = "Color del texto"
esES["Text styling applies to both the spell name and the cast time shown inside the bar."] = "El estilo del texto se aplica al nombre del hechizo y al tiempo de casteo mostrado dentro de la barra."
esES["Configure the spell icon independently so it can match either a compact or more decorative cast bar layout."] = "Configura el icono del hechizo por separado para adaptarlo a una barra compacta o mas decorativa."
esES["Show Icon"] = "Mostrar icono"
esES["Icon Position"] = "Posicion del icono"
esES["Icon Shape"] = "Forma del icono"
esES["Toggle Icon Side"] = "Cambiar lado del icono"

esES["Resource Bars"] = "Barras de recursos"
esES["Layout Preview (Stack)"] = "Vista previa de disposicion (bloque)"
esES["Layout Preview - Health"] = "Vista previa - Salud"
esES["Layout Preview - Power"] = "Vista previa - Recurso"
esES["Layout Preview - Class"] = "Vista previa - Clase"
esES["Stack"] = "Bloque"
esES["Anchor: Cooldowns / Fallback"] = "Ancla: Cooldowns / respaldo"
esES["Restore Resource Bars Defaults"] = "Restablecer barras de recursos"
esES["Hide Out of Combat"] = "Ocultar fuera de combate"
esES["Bar Texture"] = "Textura de barra"
esES["Background Alpha"] = "Alfa del fondo"
esES["Stack Strata"] = "Capa del bloque"
esES["Power Type Colors"] = "Colores por tipo de recurso"
esES["These colors apply when Color Source is set to Power Type."] = "Estos colores se aplican cuando Origen del color esta configurado como Tipo de recurso."
esES["Reset Power Colors"] = "Restablecer colores de recursos"
esES["Enable Health Bar"] = "Activar barra de salud"
esES["Resource Text"] = "Texto del recurso"
esES["HP & Percent"] = "Salud y porcentaje"
esES["HP Only (Abbrev)"] = "Solo salud (abreviado)"
esES["HP Only (Full)"] = "Solo salud (completo)"
esES["Power & Percent"] = "Recurso y porcentaje"
esES["Power Only (Abbrev)"] = "Solo recurso (abreviado)"
esES["Power Only (Full)"] = "Solo recurso (completo)"
esES["Percent Only"] = "Solo porcentaje"
esES["Match Cooldowns Width"] = "Igualar anchura de cooldowns"
esES["Manual Stack Width"] = "Anchura manual del bloque"
esES["X Offset (From Anchor)"] = "Desplazamiento X (desde el ancla)"
esES["Y Offset (Gap between bars)"] = "Desplazamiento Y (separacion entre barras)"
esES["Resource 1: Class Specific (Pips)"] = "Recurso 1: especifico de clase (pips)"
esES["Enable Class Resource"] = "Activar recurso de clase"
esES["Pip Spacing"] = "Espaciado de pips"
esES["Current Pip Resource"] = "Recurso actual con pips"
esES["These colors override the selected color source for each pip."] = "Estos colores sustituyen el origen del color seleccionado para cada pip."
esES["No pip-based resource is active for the current spec."] = "No hay ningun recurso con pips activo para la especializacion actual."
esES["Marker Profile Scope"] = "Ambito del perfil de marcadores"
esES["Marker Target"] = "Objetivo de los marcadores"
esES["Enable Custom Markers"] = "Activar marcadores personalizados"
esES["Marker 1"] = "Marcador 1"
esES["Marker 2"] = "Marcador 2"
esES["Marker 3"] = "Marcador 3"
esES["Up to 3 thresholds for class-resource bars like Astral Power or Maelstrom."] = "Hasta 3 umbrales para barras de recurso de clase como Poder astral o Voragine."
esES["Marker Width"] = "Anchura del marcador"
esES["Marker Color"] = "Color del marcador"
esES["Enable Power Bar"] = "Activar barra de recurso"
esES["Hide Mana Bar (Current Spec)"] = "Ocultar barra de mana (especializacion actual)"
esES["Primary Power Bar"] = "Barra principal de recurso"
esES["Class Resource Bar"] = "Barra de recurso de clase"
esES["Per Talent Preset"] = "Por preset de talentos"
esES["Per Spec"] = "Por especializacion"
esES["Per Character"] = "Por personaje"
esES["Power Type"] = "Tipo de recurso"
esES["Color Source"] = "Origen del color"
esES["Current Spec Color"] = "Color de la especializacion actual"
esES["Custom Fill Color"] = "Color de relleno personalizado"
esES["Spec Color"] = "Color de especializacion"
esES["Fill Color Options"] = "Opciones de color de relleno"
esES["Mana"] = "Mana"
esES["Rage"] = "Ira"
esES["Energy"] = "Energia"
esES["Combo Points"] = "Puntos de combo"
esES["Runes"] = "Runas"
esES["Runic Power"] = "Poder runico"
esES["Soul Shards"] = "Fragmentos de alma"
esES["Astral Power"] = "Poder astral"
esES["Holy Power"] = "Poder sagrado"
esES["Maelstrom"] = "Voragine"
esES["Chi"] = "Chi"
esES["Insanity"] = "Demencia"
esES["Arcane Charges"] = "Cargas arcanas"
esES["Fury"] = "Furia"
esES["Pain"] = "Dolor"
esES["Essence"] = "Esencia"

esES["Cooldown Manager"] = "Gestor de cooldowns"
esES["KUICooldownManager"] = "Gestor de cooldowns KUI"
esES["Central hub for Action Bar trackers, ability cooldowns and logic."] = "Centro principal para rastreadores de barras de accion, cooldowns de habilidades y logica."
esES["Move & Unlock"] = "Mover y desbloquear"
esES["Unlock bars to drag and reposition them freely."] = "Desbloquea las barras para arrastrarlas y recolocarlas libremente."
esES["Unlock Bars"] = "Desbloquear barras"
esES["Lock Bars"] = "Bloquear barras"
esES["Bars Unlocked"] = "Barras desbloqueadas"
esES["CDM Bars"] = "Barras CDM"
esES["Live CDM Preview"] = "Vista previa de CDM"
esES["Live Layout Preview"] = "Vista previa de disposicion"
esES["Layout Preview By Block"] = "Vista previa por bloque"
esES["Selected CDM Bar:"] = "Barra CDM seleccionada:"
esES["Selected CDM Skill Glow"] = "Glow de habilidad CDM seleccionada"
esES["Selected Spell Glow Color"] = "Color del glow del hechizo seleccionado"
esES["Selected Spell Swipe Color"] = "Color del barrido del hechizo seleccionado"
esES["Set global defaults and override them from the selected CDM icon, while keeping action bar mappings intact."] = "Define valores globales y sobrescribelos desde el icono CDM seleccionado manteniendo intactas las asignaciones de la barra de accion."
esES["Manage icon groups for cooldowns. Use the interactive preview below to add or remove spells."] = "Gestiona grupos de iconos para cooldowns. Usa la vista previa interactiva de abajo para anadir o quitar hechizos."
esES["Imports the visible order from Blizzard CDM for Cooldowns, Utility and Buffs."] = "Importa el orden visible del CDM de Blizzard para Cooldowns, Utilidad y Buffs."
esES["Action Button Glow"] = "Glow de boton de accion"
esES["Action Bar 1 (Main)"] = "Barra de accion 1 (principal)"
esES["Action Bar 2"] = "Barra de accion 2"
esES["Action Bar 3"] = "Barra de accion 3"
esES["Action Bar 4"] = "Barra de accion 4"
esES["Action Bar 5"] = "Barra de accion 5"
esES["Action Bar 6"] = "Barra de accion 6"
esES["Action Bar 7"] = "Barra de accion 7"
esES["Action Bar 8"] = "Barra de accion 8"
esES["Mapped Action Button:"] = "Boton de accion asignado:"
esES["Bar"] = "Barra"
esES["Button"] = "Boton"
esES["Left click a CDM icon to edit its mapped glow, right click it to assign or update buffs."] = "Clic izquierdo en un icono CDM para editar su glow asignado; clic derecho para asignar o actualizar buffs."
esES["Trigger Buff Assignments for Action Button %s / %s"] = "Asignaciones de buff activador para boton de accion %s / %s"
esES["No buffs assigned. Right click the selected CDM icon in the preview to assign buffs."] = "No hay buffs asignados. Haz clic derecho en el icono CDM seleccionado de la vista previa para asignar buffs."
esES["Trigger Buff"] = "Buff activador"
esES["Glow Type"] = "Tipo de glow"
esES["Use Global Glow"] = "Usar glow global"
esES["Class Colored Glow"] = "Glow con color de clase"
esES["Use Global Color"] = "Usar color global"
esES["Glow Color"] = "Color del glow"
esES["Glow When"] = "Mostrar glow cuando"
esES["Remove This Buff"] = "Eliminar este buff"
esES["Open Blizzard CDM"] = "Abrir CDM de Blizzard"
esES["Buff Bars"] = "Barras de buffs"
esES["Buff Bars settings are unavailable: tracked buff bars module not loaded."] = "Los ajustes de Barras de buffs no estan disponibles: el modulo de barras de buffs rastreadas no esta cargado."
esES["Tracked buff progress bars with their own spell, size, texture and colors."] = "Barras de progreso de buffs rastreados con hechizo, tamano, textura y colores propios."
esES["No buff bars created yet. Add one to configure it here."] = "Todavia no hay barras de buffs creadas. Anade una para configurarla aqui."
esES["Select Buff Bar"] = "Seleccionar barra de buff"
esES["Tracked Buff: "] = "Buff rastreado: "
esES["Delete Buff Bar"] = "Eliminar barra de buff"
esES["Enable action button glows for tracked buffs/debuffs."] = "Activa glows en botones de accion para buffs/debuffs rastreados."
esES["Bar Glows"] = "Glows de barras"
esES["Enable Bar Glows Module"] = "Activar modulo de glows de barra"
esES["Global Glow Style"] = "Estilo global de glow"
esES["Global Class Colored Glow"] = "Glow global con color de clase"
esES["Cooldown Proc Glow"] = "Glow de proc de cooldown"
esES["Global Glow Color"] = "Color global del glow"
esES["Proc Glow (WoW)"] = "Glow de proc (WoW)"
esES["AutoCast Shine"] = "Brillo de autocast"
esES["Auto-Cast Shine"] = "Brillo de autocast"
esES["Pixel Border"] = "Borde pixel"
esES["Pixel Glow"] = "Glow pixel"
esES["Custom Shape Glow"] = "Glow de forma personalizada"
esES["Class Color Glow"] = "Glow con color de clase"
esES["Class Color Border"] = "Borde con color de clase"
esES["Buff Active"] = "Buff activo"
esES["Buff Missing"] = "Buff ausente"
esES["Hide When..."] = "Ocultar cuando..."
esES["Hide Rules"] = "Reglas de ocultacion"
esES["Rules"] = "Reglas"
esES["Match All (hide if all met)"] = "Coincidir todas (ocultar si se cumplen todas)"
esES["Match Any (hide if any condition met)"] = "Coincidir cualquiera (ocultar si se cumple alguna)"
esES["In Combat"] = "En combate"
esES["Out of Combat"] = "Fuera de combate"
esES["Has Target"] = "Tiene objetivo"
esES["No Target"] = "Sin objetivo"
esES["Not Casting"] = "Sin castear"
esES["In Pet Battle"] = "En duelo de mascotas"
esES["Always (Disabled)"] = "Siempre (desactivado)"
esES["Hide When Active"] = "Ocultar cuando este activo"
esES["Hide Buffs When Inactive"] = "Ocultar buffs inactivos"
esES["Hide GCD Swipe"] = "Ocultar barrido del GCD"
esES["Desaturate on Cooldown"] = "Desaturar en cooldown"
esES["Show Tooltip on Hover"] = "Mostrar tooltip al pasar el raton"
esES["Show Keybinds"] = "Mostrar atajos"
esES["Keybind Text"] = "Texto de atajo"
esES["Keybind Font Size"] = "Tamano de fuente de atajo"
esES["Show Duration Text"] = "Mostrar texto de duracion"
esES["Duration Font Size"] = "Tamano de fuente de duracion"
esES["Show Stack Count"] = "Mostrar acumulaciones"
esES["Stack Count Font Size"] = "Tamano de fuente de acumulaciones"
esES["Icon Scale"] = "Escala del icono"
esES["Icon Spacing"] = "Espaciado de iconos"
esES["Global Bar Scale"] = "Escala global de barras"
esES["Anchor Position"] = "Posicion del ancla"
esES["Anchor Offset X"] = "Desplazamiento X del ancla"
esES["Anchor Offset Y"] = "Desplazamiento Y del ancla"
esES["Button Press Highlight"] = "Resaltado al pulsar boton"
esES["Assisted Combat Highlight"] = "Resaltado de combate asistido"

esES["Progress Bars"] = "Barras de progreso"
esES["Independent progress bars for spell-triggered and aura-style tracking."] = "Barras de progreso independientes para seguimiento por hechizos y auras."
esES["Buff Bar Configuration"] = "Configuracion de barra de buff"
esES["Aura Bar Configuration"] = "Configuracion de barra de aura"
esES["Aura Bars"] = "Barras de auras"
esES["Aura Catalog"] = "Catalogo de auras"
esES["Spellbook"] = "Libro de hechizos"
esES["|cff00ff00Drag & Drop|r a Spell or Item from your Spellbook\ninto this area or the book button to track it."] = "|cff00ff00Arrastra y suelta|r un hechizo u objeto desde tu libro de hechizos\nen esta zona o en el boton del libro para rastrearlo."
esES["|cff888888Your catalog is empty. Drag a spell above to start.|r"] = "|cff888888Tu catalogo esta vacio. Arrastra un hechizo arriba para empezar.|r"
esES["Left-Click to select"] = "Clic izquierdo para seleccionar"
esES["Right-Click to remove from catalog"] = "Clic derecho para quitar del catalogo"
esES["Selected:"] = "Seleccionado:"
esES["Create Bar for Selected"] = "Crear barra para la seleccion"
esES["No bars configured yet."] = "Todavia no hay barras configuradas."
esES["+ Add New Bar"] = "+ Anadir nueva barra"
esES["+ Add Bar"] = "+ Anadir barra"
esES["- Delete Selected"] = "- Eliminar seleccionada"
esES["— Delete Selected"] = "- Eliminar seleccionada"
esES["Select Bar"] = "Seleccionar barra"
esES["Active Bars"] = "Barras activas"
esES["Bar Name"] = "Nombre de la barra"
esES["Spell ID (Type & Enter, OR Drag Spell here)"] = "ID de hechizo (escribe y pulsa Enter, o arrastra aqui el hechizo)"
esES["Catalog Quick Pick"] = "Seleccion rapida del catalogo"
esES["Unit to Track"] = "Unidad a rastrear"
esES["Tracking Mode"] = "Modo de seguimiento"
esES["Tracking Configuration"] = "Configuracion de seguimiento"
esES["Duration (Depletes over time)"] = "Duracion (se vacia con el tiempo)"
esES["Stacks (Fills per stack)"] = "Acumulaciones (se llena por acumulacion)"
esES["Manual Timer Duration"] = "Duracion manual del temporizador"
esES["Timer Duration (Seconds)"] = "Duracion del temporizador (segundos)"
esES["Override Blizzard Duration"] = "Sobrescribir duracion de Blizzard"
esES["Bar Dimensions"] = "Dimensiones de la barra"
esES["Appearance"] = "Apariencia"
esES["Show Spark"] = "Mostrar destello"
esES["Show Buff Name"] = "Mostrar nombre del buff"
esES["Show Duration Timer"] = "Mostrar temporizador de duracion"
esES["Fill Color"] = "Color de relleno"
esES["Background Color"] = "Color de fondo"
esES["Border Color"] = "Color del borde"
esES["Border Size"] = "Tamano del borde"
esES["Icon"] = "Icono"
esES["Icon Size"] = "Tamano del icono"
esES["Icon X Offset"] = "Desplazamiento X del icono"
esES["Text Settings"] = "Ajustes de texto"
esES["Name Font Size"] = "Tamano de fuente del nombre"
esES["Timer Font Size"] = "Tamano de fuente del temporizador"
esES["Drag & Drop a spell here"] = "Arrastra y suelta aqui un hechizo"
esES["to assign it to this tracker"] = "para asignarlo a este rastreador"

esES["+ Add Custom Bar"] = "+ Anadir barra personalizada"
esES["2d"] = "2D"
esES["Active & Swipe"] = "Activo y barrido"
esES["Active Animation"] = "Animacion activa"
esES["Active State"] = "Estado activo"
esES["Active Swipe Uses Glow Color"] = "El barrido activo usa el color del glow"
esES["Always"] = "Siempre"
esES["Anchored To"] = "Anclado a"
esES["Auto-detect items in bags"] = "Detectar objetos automaticamente en las bolsas"
esES["Auto-detect spells (by spec)"] = "Detectar hechizos automaticamente segun especializacion"
esES["BACKGROUND"] = "Fondo"
esES["Bar Layout"] = "Disposicion de barras"
esES["Bar Opacity"] = "Opacidad de barra"
esES["Blizzard Default"] = "Blizzard por defecto"
esES["Colors"] = "Colores"
esES["Condition Match Mode"] = "Modo de coincidencia de condiciones"
esES["Configure KullThranUI-specific trackers (Interrupts, Defensives, Trinkets, etc)."] = "Configura rastreadores propios de KullThranUI (cortes, defensivos, abalorios, etc.)."
esES["Cropped"] = "Recortado"
esES["Curved Square"] = "Cuadrado curvado"
esES["Custom Icon Shape"] = "Forma de icono personalizada"
esES["Delete Bar"] = "Eliminar barra"
esES["Diamond"] = "Diamante"
esES["Effects"] = "Efectos"
esES["Enable Tracker"] = "Activar rastreador"
esES["Go to Anchor"] = "Ir al ancla"
esES["Go to Class Resource"] = "Ir al recurso de clase"
esES["Go to Health"] = "Ir a salud"
esES["Go to Power"] = "Ir a recurso"
esES["Hexagon"] = "Hexagono"
esES["Icon Display"] = "Visualizacion del icono"
esES["Icons"] = "Iconos"
esES["Import Blizzard Layout Now"] = "Importar disposicion de Blizzard ahora"
esES["Interrupts"] = "Cortes"
esES["KUI Custom Tracker"] = "Rastreador personalizado KUI"
esES["Keybind Outline"] = "Contorno de atajos"
esES["LEFT"] = "Izquierda"
esES["Layout"] = "Disposicion"
esES["Left-click to open this tracker controls."] = "Clic izquierdo para abrir los controles de este rastreador."
esES["Live %s Preview"] = "Vista previa de %s"
esES["Live layout using your current player frame, tracker size, side and offsets."] = "Disposicion en vivo usando tu marco de jugador actual, tamano del rastreador, lado y desplazamientos."
esES["Lock & Save"] = "Bloquear y guardar"
esES["Manage Bars"] = "Gestionar barras"
esES["Max Icons"] = "Maximo de iconos"
esES["Misc"] = "Varios"
esES["Mouseover"] = "Al pasar el raton"
esES["Never"] = "Nunca"
esES["Number of Rows"] = "Numero de filas"
esES["Potions & Consumables"] = "Pociones y consumibles"
esES["Prompt on Blizzard Changes"] = "Avisar ante cambios de Blizzard"
esES["Racials & Defensives"] = "Raciales y defensivos"
esES["Remove Spell"] = "Eliminar hechizo"
esES["Right-click to remove"] = "Clic derecho para quitar"
esES["Show Background"] = "Mostrar fondo"
esES["Show Text"] = "Mostrar texto"
esES["Swipe"] = "Barrido"
esES["Swipe Alpha"] = "Alfa del barrido"
esES["Swipe Color"] = "Color del barrido"
esES["Text & Keybinds"] = "Texto y atajos"
esES["Texts & Misc"] = "Textos y varios"
esES["Trinkets"] = "Abalorios"
esES["Use Blizzard Layout by Default"] = "Usar disposicion de Blizzard por defecto"
esES["Use Global Swipe Color"] = "Usar color global del barrido"
esES["Visibility"] = "Visibilidad"
esES["X Offset"] = "Desplazamiento X"
esES["Y Offset"] = "Desplazamiento Y"
esES["none"] = "ninguno"
esES["spec"] = "especializacion"

esES["Combat Status Text"] = "Texto de estado de combate"
esES["Enable Combat Status Text"] = "Activar texto de estado de combate"
esES["Show enter combat message"] = "Mostrar mensaje al entrar en combate"
esES["Show leave combat message"] = "Mostrar mensaje al salir de combate"
esES["Show Combat Text Background"] = "Mostrar fondo del texto de combate"
esES["Enter Combat Text"] = "Texto al entrar en combate"
esES["Leave Combat Text"] = "Texto al salir de combate"
esES["Combat Text Animation"] = "Animacion del texto de combate"
esES["No Animation"] = "Sin animacion"
esES["Fade"] = "Desvanecer"
esES["Fade and Scale"] = "Desvanecer y escalar"
esES["Font Outline"] = "Contorno de fuente"
esES["No Outline"] = "Sin contorno"
esES["Outline"] = "Contorno"
esES["Thick Outline"] = "Contorno grueso"
esES["Display Duration"] = "Duracion visible"
esES["Fade In Duration"] = "Duracion de entrada"
esES["Fade Out Duration"] = "Duracion de salida"
esES["Enter Combat Color"] = "Color al entrar en combate"
esES["Leave Combat Color"] = "Color al salir de combate"
esES["Combat Text Background Color"] = "Color del fondo del texto de combate"
esES["Preview Enter Combat"] = "Probar entrada en combate"
esES["Preview Leave Combat"] = "Probar salida de combate"
esES["IN COMBAT"] = "EN COMBATE"
esES["OUT OF COMBAT"] = "FUERA DE COMBATE"

enUS["Reset KUI External Integrations"] = "Reset KUI External Integrations"
enUS["Reset only KUI integration settings for Unhalted Unit Frames and DandersFrames?"] = "Reset only KUI integration settings for Unhalted Unit Frames and DandersFrames?"
enUS["Minimap Button Collectors"] = "Minimap Button Collectors"
enUS["Objective Tracker"] = "Objective Tracker"
enUS["Cursor Effects"] = "Cursor Effects"
enUS["Frame Movers / Edit Mode"] = "Frame Movers / Edit Mode"
esES["Reset KUI External Integrations"] = "Restablecer integraciones externas de KUI"
esES["Reset only KUI integration settings for Unhalted Unit Frames and DandersFrames?"] = "Restablecer solo los ajustes de integracion de KUI para Unhalted Unit Frames y DandersFrames?"
esES["Minimap Button Collectors"] = "Recolectores de botones del minimapa"
esES["Objective Tracker"] = "Rastreador de objetivos"
esES["Cursor Effects"] = "Efectos del cursor"
esES["Frame Movers / Edit Mode"] = "Posicionadores de marcos / Modo Edicion"
esES["KUI Minimap Button Bar"] = "Barra de botones del minimapa de KUI"
esES["KUI Objective Tracker"] = "Rastreador de objetivos de KUI"
esES["KUI Cursor"] = "Cursor de KUI"
esES["KUI Unlock Mode / BlizzMove"] = "Modo desbloqueo de KUI / BlizzMove"
esES["Multiple minimap button collectors can reparent or hide the same buttons, producing missing, duplicated, or inaccessible icons."] = "Varios recolectores pueden reasignar u ocultar los mismos botones del minimapa, provocando iconos ausentes, duplicados o inaccesibles."
esES["Objective tracker replacements can move, rebuild, or hide the same Blizzard tracker styled and positioned by KUI."] = "Los reemplazos del rastreador pueden mover, reconstruir u ocultar el mismo rastreador de Blizzard que KUI posiciona y estiliza."
esES["Running more than one cursor effect creates duplicate rings or trails and unnecessary per-frame updates."] = "Usar mas de un efecto de cursor crea anillos o estelas duplicados y actualizaciones por frame innecesarias."
esES["Multiple frame movers can compete for anchors and protected Blizzard frames, causing position drift or taint after reloads and zone changes."] = "Varios posicionadores pueden competir por anclajes y marcos protegidos de Blizzard, causando desplazamientos o taint tras recargas y cambios de zona."

local STARTUP_LATEST = [[Welcome to KullThranUI version %s, you have the latest version installed!]]
local STARTUP_UPDATE = [[Welcome to KullThranUI version %s, an update is available.]]
local STARTUP_DISCORD = [[To keep up with the latest KUI news, join our Discord: %s.]]

local startupMessages = {
    enUS = {
        [STARTUP_LATEST] = STARTUP_LATEST,
        [STARTUP_UPDATE] = STARTUP_UPDATE,
        [STARTUP_DISCORD] = STARTUP_DISCORD,
    },
    esES = {
        [STARTUP_LATEST] = [[Bienvenido a KullThranUI versión %s, tienes la última versión instalada!]],
        [STARTUP_UPDATE] = [[Bienvenido a KullThranUI versión %s, hay una actualización disponible.]],
        [STARTUP_DISCORD] = [[Para estar al día de las novedades de KUI únete a nuestro Discord: %s.]],
    },
    frFR = {
        [STARTUP_LATEST] = [[Bienvenue sur KullThranUI version %s, vous avez installé la dernière version !]],
        [STARTUP_UPDATE] = [[Bienvenue sur KullThranUI version %s, une mise à jour est disponible.]],
        [STARTUP_DISCORD] = [[Pour suivre les actualités de KUI, rejoignez notre Discord : %s.]],
    },
    deDE = {
        [STARTUP_LATEST] = [[Willkommen bei KullThranUI Version %s, du hast die neueste Version installiert!]],
        [STARTUP_UPDATE] = [[Willkommen bei KullThranUI Version %s, ein Update ist verfügbar.]],
        [STARTUP_DISCORD] = [[Bleibe über KUI-Neuigkeiten informiert und tritt unserem Discord bei: %s.]],
    },
    itIT = {
        [STARTUP_LATEST] = [[Benvenuto in KullThranUI versione %s, hai installato la versione più recente!]],
        [STARTUP_UPDATE] = [[Benvenuto in KullThranUI versione %s, è disponibile un aggiornamento.]],
        [STARTUP_DISCORD] = [[Per restare aggiornato sulle novità di KUI, unisciti al nostro Discord: %s.]],
    },
    ptBR = {
        [STARTUP_LATEST] = [[Bem-vindo ao KullThranUI versão %s, você tem a versão mais recente instalada!]],
        [STARTUP_UPDATE] = [[Bem-vindo ao KullThranUI versão %s, há uma atualização disponível.]],
        [STARTUP_DISCORD] = [[Para acompanhar as novidades do KUI, entre no nosso Discord: %s.]],
    },
    ruRU = {
        [STARTUP_LATEST] = [[Добро пожаловать в KullThranUI версии %s, у вас установлена последняя версия!]],
        [STARTUP_UPDATE] = [[Добро пожаловать в KullThranUI версии %s, доступно обновление.]],
        [STARTUP_DISCORD] = [[Чтобы быть в курсе новостей KUI, присоединяйтесь к нашему Discord: %s.]],
    },
    koKR = {
        [STARTUP_LATEST] = [[KullThranUI 버전 %s에 오신 것을 환영합니다. 최신 버전이 설치되어 있습니다!]],
        [STARTUP_UPDATE] = [[KullThranUI 버전 %s에 오신 것을 환영합니다. 업데이트가 있습니다.]],
        [STARTUP_DISCORD] = [[KUI의 최신 소식을 확인하려면 Discord에 참여하세요: %s.]],
    },
    zhCN = {
        [STARTUP_LATEST] = [[欢迎使用 KullThranUI %s 版本，你已安装最新版本！]],
        [STARTUP_UPDATE] = [[欢迎使用 KullThranUI %s 版本，有可用更新。]],
        [STARTUP_DISCORD] = [[要了解 KUI 的最新消息，请加入我们的 Discord：%s。]],
    },
    zhTW = {
        [STARTUP_LATEST] = [[歡迎使用 KullThranUI %s 版本，你已安裝最新版本！]],
        [STARTUP_UPDATE] = [[歡迎使用 KullThranUI %s 版本，有可用更新。]],
        [STARTUP_DISCORD] = [[若要掌握 KUI 的最新消息，請加入我們的 Discord：%s。]],
    },
}

for localeKey, entries in pairs(startupMessages) do
    apply(locales[localeKey], entries)
end
apply(locales.esMX, startupMessages.esES)
apply(locales.ptPT, startupMessages.ptBR)

local frFR_overrides = {
    ["Reset KUI External Integrations"] = "Réinitialiser les intégrations externes KUI",
    ["Reset only KUI integration settings for Unhalted Unit Frames and DandersFrames?"] = "Réinitialiser uniquement les paramètres d'intégration KUI pour les cadres d'unité ininterrompus et DandersFrames?",
    ["Minimap Button Collectors"] = "Collecteurs de boutons de mini-carte",
    ["Objective Tracker"] = "Suivi des objectifs",
    ["Cursor Effects"] = "Effets du curseur",
    ["Frame Movers / Edit Mode"] = "Déplaçants de cadre / Mode édition",
    ["KUI Minimap Button Bar"] = "Barre de boutons mini-carte KUI",
    ["KUI Objective Tracker"] = "Suivi des objectifs KUI",
    ["KUI Cursor"] = "Curseur KUI",
    ["KUI Unlock Mode / BlizzMove"] = "Mode de déverrouillage KUI / BlizzMove",
    ["Multiple minimap button collectors can reparent or hide the same buttons, producing missing, duplicated, or inaccessible icons."] = "Plusieurs collecteurs peuvent réassigner ou masquer les mêmes boutons, produisant des icônes manquantes, dupliquées ou inaccessibles.",
    ["Objective tracker replacements can move, rebuild, or hide the same Blizzard tracker styled and positioned by KUI."] = "Les remplacements de suivi peuvent déplacer, reconstruire ou masquer le même suivi Blizzard stylisé et positionné par KUI.",
    ["Running more than one cursor effect creates duplicate rings or trails and unnecessary per-frame updates."] = "L'exécution de plus d'un effet de curseur crée des anneaux ou des traînées dupliqués et des mises à jour inutiles par image.",
    ["Multiple frame movers can compete for anchors and protected Blizzard frames, causing position drift or taint after reloads and zone changes."] = "Plusieurs déplaçants peuvent rivaliser pour les ancres et les cadres protégés Blizzard, causant une dérive de position ou une contamination après les rechargements et changements de zone.",
}

local ptBR_overrides = {
    ["Reset KUI External Integrations"] = "Redefinir integrações externas KUI",
    ["Reset only KUI integration settings for Unhalted Unit Frames and DandersFrames?"] = "Redefinir apenas as configurações de integração KUI para Unhalted Unit Frames e DandersFrames?",
    ["Minimap Button Collectors"] = "Coletores de botões de mini-mapa",
    ["Objective Tracker"] = "Rastreador de objetivos",
    ["Cursor Effects"] = "Efeitos do cursor",
    ["Frame Movers / Edit Mode"] = "Movimentadores de quadro / Modo de edição",
    ["KUI Minimap Button Bar"] = "Barra de botões mini-mapa KUI",
    ["KUI Objective Tracker"] = "Rastreador de objetivos KUI",
    ["KUI Cursor"] = "Cursor KUI",
    ["KUI Unlock Mode / BlizzMove"] = "Modo de desbloqueio KUI / BlizzMove",
}

local itIT_overrides = {
    ["Reset KUI External Integrations"] = "Ripristina integrazioni esterne KUI",
    ["Reset only KUI integration settings for Unhalted Unit Frames and DandersFrames?"] = "Ripristinare solo le impostazioni di integrazione KUI per i frame di unità ininterrotti e DandersFrames?",
    ["Minimap Button Collectors"] = "Collezionisti di pulsanti mini-mappa",
    ["Objective Tracker"] = "Tracciatore obiettivi",
    ["Cursor Effects"] = "Effetti del cursore",
    ["Frame Movers / Edit Mode"] = "Spostatori di frame / Modalità modifica",
    ["KUI Minimap Button Bar"] = "Barra pulsanti mini-mappa KUI",
    ["KUI Objective Tracker"] = "Tracciatore obiettivi KUI",
    ["KUI Cursor"] = "Cursore KUI",
    ["KUI Unlock Mode / BlizzMove"] = "Modalità sblocco KUI / BlizzMove",
}

local ruRU_overrides = {
    ["Reset KUI External Integrations"] = "Сбросить внешние интеграции KUI",
    ["Reset only KUI integration settings for Unhalted Unit Frames and DandersFrames?"] = "Сбросить только параметры интеграции KUI для единичных фреймов и DandersFrames?",
    ["Minimap Button Collectors"] = "Коллекторы кнопок мини-карты",
    ["Objective Tracker"] = "Отслеживатель целей",
    ["Cursor Effects"] = "Эффекты курсора",
    ["Frame Movers / Edit Mode"] = "Движители фреймов / Режим редактирования",
    ["KUI Minimap Button Bar"] = "Панель кнопок мини-карты KUI",
    ["KUI Objective Tracker"] = "Отслеживатель целей KUI",
    ["KUI Cursor"] = "Курсор KUI",
    ["KUI Unlock Mode / BlizzMove"] = "Режим разблокировки KUI / BlizzMove",
}

local koKR_overrides = {
    ["Reset KUI External Integrations"] = "KUI 외부 통합 재설정",
    ["Reset only KUI integration settings for Unhalted Unit Frames and DandersFrames?"] = "중단되지 않은 단위 프레임 및 DandersFrames에 대한 KUI 통합 설정만 재설정하시겠습니까?",
    ["Minimap Button Collectors"] = "미니맵 버튼 수집기",
    ["Objective Tracker"] = "목표 추적기",
    ["Cursor Effects"] = "커서 효과",
    ["Frame Movers / Edit Mode"] = "프레임 이동자 / 편집 모드",
    ["KUI Minimap Button Bar"] = "KUI 미니맵 버튼 바",
    ["KUI Objective Tracker"] = "KUI 목표 추적기",
    ["KUI Cursor"] = "KUI 커서",
    ["KUI Unlock Mode / BlizzMove"] = "KUI 잠금 해제 모드 / BlizzMove",
}

local zhCN_overrides = {
    ["Reset KUI External Integrations"] = "重置 KUI 外部集成",
    ["Reset only KUI integration settings for Unhalted Unit Frames and DandersFrames?"] = "仅重置 Unhalted Unit Frames 和 DandersFrames 的 KUI 集成设置？",
    ["Minimap Button Collectors"] = "小地图按钮收集器",
    ["Objective Tracker"] = "目标追踪器",
    ["Cursor Effects"] = "光标效果",
    ["Frame Movers / Edit Mode"] = "框架移动者 / 编辑模式",
    ["KUI Minimap Button Bar"] = "KUI 小地图按钮栏",
    ["KUI Objective Tracker"] = "KUI 目标追踪器",
    ["KUI Cursor"] = "KUI 光标",
    ["KUI Unlock Mode / BlizzMove"] = "KUI 解锁模式 / BlizzMove",
}

local zhTW_overrides = {
    ["Reset KUI External Integrations"] = "重設 KUI 外部整合",
    ["Reset only KUI integration settings for Unhalted Unit Frames and DandersFrames?"] = "僅重設 Unhalted Unit Frames 和 DandersFrames 的 KUI 整合設定？",
    ["Minimap Button Collectors"] = "小地圖按鈕收集器",
    ["Objective Tracker"] = "目標追蹤器",
    ["Cursor Effects"] = "游標效果",
    ["Frame Movers / Edit Mode"] = "框架移動者 / 編輯模式",
    ["KUI Minimap Button Bar"] = "KUI 小地圖按鈕欄",
    ["KUI Objective Tracker"] = "KUI 目標追蹤器",
    ["KUI Cursor"] = "KUI 游標",
    ["KUI Unlock Mode / BlizzMove"] = "KUI 解鎖模式 / BlizzMove",
}

apply(locales.enUS, enUS)
apply(locales.esES, esES)
apply(locales.frFR, frFR_overrides)
apply(locales.ptBR, ptBR_overrides)
apply(locales.itIT, itIT_overrides)
apply(locales.ruRU, ruRU_overrides)
apply(locales.koKR, koKR_overrides)
apply(locales.zhCN, zhCN_overrides)
apply(locales.zhTW, zhTW_overrides)
if locales.esMX ~= locales.esES then
    apply(locales.esMX, esES)
end


-- Forced overrides for module names
local ruRU = locales.ruRU or {}
ruRU["Unit Frames"] = "Единичные рамы"
ruRU["Party Frames"] = "Рамки для вечеринок"
ruRU["Cast Bar"] = "Литой бар"
ruRU["Resource Bars"] = "Ресурсные батончики"
ruRU["Cooldown Manager"] = "Менеджер перезарядки"
apply(locales.ruRU, ruRU)

local deDE = locales.deDE or {}
deDE["Unit Frames"] = "Einheitenrahmen"
deDE["Party Frames"] = "Gruppenrahmen"
deDE["Cast Bar"] = "Zauberleiste"
deDE["Resource Bars"] = "Ressourcenleisten"
deDE["Cooldown Manager"] = "Abklingzeit-Manager"
apply(locales.deDE, deDE)

local frFR = locales.frFR or {}
frFR["Unit Frames"] = "Cadres d'unité"
frFR["Party Frames"] = "Cadres de groupe"
frFR["Cast Bar"] = "Barre de lancement"
frFR["Resource Bars"] = "Barres de ressources"
frFR["Cooldown Manager"] = "Gestionnaire de temps de recharge"
apply(locales.frFR, frFR)

local itIT = locales.itIT or {}
itIT["Unit Frames"] = "Cornici unità"
itIT["Party Frames"] = "Cornici del gruppo"
itIT["Cast Bar"] = "Barra di lancio"
itIT["Resource Bars"] = "Barre delle risorse"
itIT["Cooldown Manager"] = "Gestore tempo di recupero"
apply(locales.itIT, itIT)

local ptBR = locales.ptBR or {}
ptBR["Unit Frames"] = "Quadros de Unidade"
ptBR["Party Frames"] = "Quadros de Grupo"
ptBR["Cast Bar"] = "Barra de Lançamento"
ptBR["Resource Bars"] = "Barras de Recursos"
ptBR["Cooldown Manager"] = "Gerenciador de Recarga"
apply(locales.ptBR, ptBR)
apply(locales.ptPT, ptBR)

local koKR = locales.koKR or {}
koKR["Unit Frames"] = "단위 프레임"
koKR["Party Frames"] = "파티 프레임"
koKR["Cast Bar"] = "시전 바"
koKR["Resource Bars"] = "자원 바"
koKR["Cooldown Manager"] = "재사용 대기시간 관리자"
apply(locales.koKR, koKR)

local zhCN = locales.zhCN or {}
zhCN["Unit Frames"] = "单元框架"
zhCN["Party Frames"] = "队伍框架"
zhCN["Cast Bar"] = "施法条"
zhCN["Resource Bars"] = "资源条"
zhCN["Cooldown Manager"] = "冷却管理器"
apply(locales.zhCN, zhCN)

local zhTW = locales.zhTW or {}
zhTW["Unit Frames"] = "單元框架"
zhTW["Party Frames"] = "隊伍框架"
zhTW["Cast Bar"] = "施法條"
zhTW["Resource Bars"] = "資源條"
zhTW["Cooldown Manager"] = "冷卻管理器"
apply(locales.zhTW, zhTW)

-- Integration strings used directly by current modules.  Keeping the complete
-- enUS contract here makes missing locale calls auditable; untranslated
-- catalogs continue to use their normal English fallback.
local integrationEN = {
    ["|cff00c8ffEnhancements|r: Repaired for %s."] = "|cff00c8ffEnhancements|r: Repaired for %s.",
    ["|cff00c8ffEnhancements|r: Sold %d junk items for %s."] = "|cff00c8ffEnhancements|r: Sold %d junk items for %s.",
    ["↑ Drag & Drop Spell Here ↑"] = "↑ Drag & Drop Spell Here ↑",
    ["Addon"] = "Addon",
    ["Addon Change - Reload Required"] = "Addon Change - Reload Required",
    ["Battle.net Friend"] = "Battle.net Friend",
    ["Default"] = "Default",
    ["Friend"] = "Friend",
    ["Left Click: Open Addon Buttons Menu"] = "Left Click: Open Addon Buttons Menu",
    ["Move it from KUI Unlock Mode under Enhancements."] = "Move it from KUI Unlock Mode under Enhancements.",
    ["No addon buttons found"] = "No addon buttons found",
    ["OFF"] = "OFF",
    ["ON"] = "ON",
    ["Open Configuration"] = "Open Configuration",
    ["Preview Combat Timer"] = "Preview Combat Timer",
    ["Right Click: Open Minimap Settings"] = "Right Click: Open Minimap Settings",
    ["Use Addon"] = "Use Addon",
    ["X"] = "X",
}

local integrationES = {
    ["|cff00c8ffEnhancements|r: Repaired for %s."] = "|cff00c8ffMejoras|r: Reparado por %s.",
    ["|cff00c8ffEnhancements|r: Sold %d junk items for %s."] = "|cff00c8ffMejoras|r: Se vendieron %d objetos basura por %s.",
    ["↑ Drag & Drop Spell Here ↑"] = "↑ Arrastra y suelta aquí el hechizo ↑",
    ["Addon"] = "Addon",
    ["Addon Change - Reload Required"] = "Cambio de addon - Se requiere recargar",
    ["Battle.net Friend"] = "Amigo de Battle.net",
    ["Default"] = "Predeterminado",
    ["Friend"] = "Amigo",
    ["Left Click: Open Addon Buttons Menu"] = "Clic izquierdo: abrir menú de botones de addons",
    ["Move it from KUI Unlock Mode under Enhancements."] = "Muévelo desde el modo de desbloqueo de KUI, en Mejoras.",
    ["No addon buttons found"] = "No se encontraron botones de addons",
    ["OFF"] = "DESACTIVADO",
    ["ON"] = "ACTIVADO",
    ["Open Configuration"] = "Abrir configuración",
    ["Preview Combat Timer"] = "Previsualizar temporizador de combate",
    ["Right Click: Open Minimap Settings"] = "Clic derecho: abrir ajustes del minimapa",
    ["Use Addon"] = "Usar addon",
    ["X"] = "X",
}

apply(locales.enUS, integrationEN)
apply(locales.esES, integrationES)
apply(locales.esMX, integrationES)


-- Final locale fallback and legacy placeholder cleanup.
-- Missing translations use the enUS catalog instead of exposing internal keys.
local LEGACY_FALLBACK_KEYS = {
    "RELOAD_TEXT", "RELOAD_BTN1", "RELOAD_BTN2", "RESET_CONFIRM_TEXT",
    "BAGS_TITLE", "BAGS_BACKPACK", "BAGS_BACKPACK_MATCHES",
    "BAGS_BACKPACK_CATEGORIES", "BAGS_BACKPACK_ITEMS", "BAGS_BACKPACK_SLOTS_VIEW",
    "BAGS_SLOTS", "BAGS_FREE", "BAGS_CATEGORIZED", "BAGS_COMPACT",
    "BAGS_MODE_COMPACT", "BAGS_MODE_SECTIONS", "BAGS_NO_ITEM_SELECTED",
    "BAGS_WATCH", "BAGS_WATCH_LABEL", "BAGS_SEARCH", "BAGS_CLEANUP",
    "BAGS_SORT", "BAGS_REFRESH", "BAGS_STYLE", "BAGS_STYLE_TIP",
}

local function IsLegacyPlaceholder(key, value)
    if type(value) ~= "string" then
        return false
    end
    if value == key then
        return true
    end
    if key == "RESET_CONFIRM_TEXT" then
        return value:find("_", 1, true) ~= nil
    end
    if key:sub(1, 7) == "RELOAD_" then
        return value:find("_", 1, true) ~= nil
    end
    if key:sub(1, 5) == "BAGS_" then
        return value:find("_", 1, true) ~= nil or value:match("^[A-Z0-9_ %%+%-]+$") ~= nil
    end
    return false
end

local english = locales.enUS
if type(english) == "table" then
    for _, locale in pairs(locales) do
        if type(locale) == "table" then
            if locale ~= english then
                for _, key in ipairs(LEGACY_FALLBACK_KEYS) do
                    local value = rawget(locale, key)
                    if IsLegacyPlaceholder(key, value) then
                        rawset(locale, key, nil)
                    end
                end
            end
            setmetatable(locale, {
                __index = function(_, key)
                    local value = rawget(english, key)
                    return value ~= nil and value or key
                end,
            })
        end
    end
end

-- Final Enhancements runtime strings for all supported locales.
local enhancementsRuntime = {
 enUS={["Mythic+ Timer"]="Mythic+ Timer",["Automation & Social"]="Automation & Social",["Interface & Comfort"]="Interface & Comfort",["No Recorded Player Deaths"]="No Recorded Player Deaths",["Player Deaths"]="Player Deaths",["Deaths"]="Deaths",["Forces"]="Forces",["LIVE PREVIEW"]="LIVE PREVIEW"},
 esES={["Mythic+ Timer"]="Temporizador de Míticas+",["Automation & Social"]="Automatización y social",["Interface & Comfort"]="Interfaz y comodidad",["No Recorded Player Deaths"]="No hay muertes de jugadores registradas",["Player Deaths"]="Muertes de jugadores",["Deaths"]="Muertes",["Forces"]="Fuerzas",["LIVE PREVIEW"]="VISTA PREVIA"},
 deDE={["Mythic+ Timer"]="Mythisch+-Timer",["Automation & Social"]="Automatisierung & Soziales",["Interface & Comfort"]="Interface & Komfort",["No Recorded Player Deaths"]="Keine Spielertode aufgezeichnet",["Player Deaths"]="Spielertode",["Deaths"]="Tode",["Forces"]="Streitkräfte",["LIVE PREVIEW"]="LIVE-VORSCHAU"},
 frFR={["Mythic+ Timer"]="Minuteur Mythique+",["Automation & Social"]="Automatisation et social",["Interface & Comfort"]="Interface et confort",["No Recorded Player Deaths"]="Aucun décès de joueur enregistré",["Player Deaths"]="Morts des joueurs",["Deaths"]="Morts",["Forces"]="Forces",["LIVE PREVIEW"]="APERÇU EN DIRECT"},
 itIT={["Mythic+ Timer"]="Timer Mitiche+",["Automation & Social"]="Automazione e social",["Interface & Comfort"]="Interfaccia e comfort",["No Recorded Player Deaths"]="Nessuna morte dei giocatori registrata",["Player Deaths"]="Morti dei giocatori",["Deaths"]="Morti",["Forces"]="Forze",["LIVE PREVIEW"]="ANTEPRIMA LIVE"},
 ptBR={["Mythic+ Timer"]="Cronômetro de Míticas+",["Automation & Social"]="Automação e social",["Interface & Comfort"]="Interface e conforto",["No Recorded Player Deaths"]="Nenhuma morte de jogador registrada",["Player Deaths"]="Mortes de jogadores",["Deaths"]="Mortes",["Forces"]="Forças",["LIVE PREVIEW"]="PRÉVIA AO VIVO"},
 ruRU={["Mythic+ Timer"]="Таймер эпохальных+",["Automation & Social"]="Автоматизация и общение",["Interface & Comfort"]="Интерфейс и удобство",["No Recorded Player Deaths"]="Зарегистрированных смертей игроков нет",["Player Deaths"]="Смерти игроков",["Deaths"]="Смерти",["Forces"]="Силы",["LIVE PREVIEW"]="ПРЕДПРОСМОТР"},
 koKR={["Mythic+ Timer"]="쐐기돌 타이머",["Automation & Social"]="자동화 및 소셜",["Interface & Comfort"]="인터페이스 및 편의",["No Recorded Player Deaths"]="기록된 플레이어 사망 없음",["Player Deaths"]="플레이어 사망",["Deaths"]="사망",["Forces"]="병력",["LIVE PREVIEW"]="실시간 미리보기"},
 zhCN={["Mythic+ Timer"]="史诗钥石计时器",["Automation & Social"]="自动化与社交",["Interface & Comfort"]="界面与便利",["No Recorded Player Deaths"]="没有记录到玩家死亡",["Player Deaths"]="玩家死亡",["Deaths"]="死亡",["Forces"]="敌方进度",["LIVE PREVIEW"]="实时预览"},
 zhTW={["Mythic+ Timer"]="傳奇鑰石計時器",["Automation & Social"]="自動化與社交",["Interface & Comfort"]="介面與便利",["No Recorded Player Deaths"]="沒有記錄到玩家死亡",["Player Deaths"]="玩家死亡",["Deaths"]="死亡",["Forces"]="敵方進度",["LIVE PREVIEW"]="即時預覽"},
}
for localeKey, entries in pairs(enhancementsRuntime) do
    apply(locales[localeKey], entries)
end
apply(locales.esMX, enhancementsRuntime.esES)
apply(locales.ptPT, enhancementsRuntime.ptBR)
-- Enhancements category descriptions coverage.
local enhancementsDescriptions = {
 enUS={["Combat res, gear checks, loot helpers, and repair safeguards for dungeons and raids."]="Combat res, gear checks, loot helpers, and repair safeguards for dungeons and raids.",["Per-pull combat timing, live preview, colors, typography, and warnings."]="Per-pull combat timing, live preview, colors, typography, and warnings.",["Mythic+ Keystones Tracker"]="Mythic+ Keystones Tracker"},
 esES={["Combat res, gear checks, loot helpers, and repair safeguards for dungeons and raids."]="Resurrección de combate, comprobación de equipo, ayudas de botín y protección de reparación para mazmorras y bandas.",["Per-pull combat timing, live preview, colors, typography, and warnings."]="Temporización de cada pull, vista previa en directo, colores, tipografía y avisos.",["Mythic+ Keystones Tracker"]="Rastreador de piedras angulares de Míticas+"},
 deDE={["Combat res, gear checks, loot helpers, and repair safeguards for dungeons and raids."]="Kampf-Wiederbelebung, Ausrüstungsprüfung, Beutehilfen und Reparaturschutz für Dungeons und Schlachtzüge.",["Per-pull combat timing, live preview, colors, typography, and warnings."]="Kampfzeit pro Pull, Live-Vorschau, Farben, Typografie und Warnungen.",["Mythic+ Keystones Tracker"]="Mythisch+-Schlüsselstein-Tracker"},
 frFR={["Combat res, gear checks, loot helpers, and repair safeguards for dungeons and raids."]="Résurrection de combat, vérification de l’équipement, aides au butin et protection contre les réparations.",["Per-pull combat timing, live preview, colors, typography, and warnings."]="Chronométrage de chaque pack, aperçu en direct, couleurs, typographie et alertes.",["Mythic+ Keystones Tracker"]="Suivi des clés Mythique+"},
 itIT={["Combat res, gear checks, loot helpers, and repair safeguards for dungeons and raids."]="Resurrezione in combattimento, controlli dell'equipaggiamento, aiuti al bottino e protezione dalle riparazioni.",["Per-pull combat timing, live preview, colors, typography, and warnings."]="Timer per ogni pull, anteprima live, colori, tipografia e avvisi.",["Mythic+ Keystones Tracker"]="Tracciatore delle chiavi Mitiche+"},
 ptBR={["Combat res, gear checks, loot helpers, and repair safeguards for dungeons and raids."]="Ressurreição em combate, verificação de equipamento, ajuda de saque e proteção contra reparos.",["Per-pull combat timing, live preview, colors, typography, and warnings."]="Cronometragem de cada pull, prévia ao vivo, cores, tipografia e avisos.",["Mythic+ Keystones Tracker"]="Rastreador de chaves Míticas+"},
 ruRU={["Combat res, gear checks, loot helpers, and repair safeguards for dungeons and raids."]="Боевые воскрешения, проверка экипировки, помощь с добычей и защита от ремонта.",["Per-pull combat timing, live preview, colors, typography, and warnings."]="Тайминг каждого пака, предпросмотр, цвета, типографика и предупреждения.",["Mythic+ Keystones Tracker"]="Отслеживание ключей эпохальных+"},
 koKR={["Combat res, gear checks, loot helpers, and repair safeguards for dungeons and raids."]="전투 부활, 장비 확인, 전리품 도움말 및 수리 보호 기능입니다.",["Per-pull combat timing, live preview, colors, typography, and warnings."]="풀별 전투 시간, 실시간 미리보기, 색상, 글꼴 및 경고입니다.",["Mythic+ Keystones Tracker"]="쐐기돌 추적기"},
 zhCN={["Combat res, gear checks, loot helpers, and repair safeguards for dungeons and raids."]="战斗复活、装备检查、拾取辅助以及地下城和团队副本修理保护。",["Per-pull combat timing, live preview, colors, typography, and warnings."]="每波战斗计时、实时预览、颜色、文字样式和警告。",["Mythic+ Keystones Tracker"]="史诗钥石追踪器"},
 zhTW={["Combat res, gear checks, loot helpers, and repair safeguards for dungeons and raids."]="戰鬥復活、裝備檢查、拾取輔助以及地城與團隊副本修理保護。",["Per-pull combat timing, live preview, colors, typography, and warnings."]="每波戰鬥計時、即時預覽、顏色、文字樣式和警告。",["Mythic+ Keystones Tracker"]="傳奇鑰石追蹤器"},
}
for localeKey, entries in pairs(enhancementsDescriptions) do
    apply(locales[localeKey], entries)
end
apply(locales.esMX, enhancementsDescriptions.esES)
apply(locales.ptPT, enhancementsDescriptions.ptBR)
-- Damage Meter icon display options.
local damageMeterIconLocales = {
    enUS = { ["Player Icon"] = "Player Icon", ["Specialization Icon"] = "Specialization Icon", ["Class Icon"] = "Class Icon", ["No Icon"] = "No Icon", ["Square Icons"] = "Square Icons", ["Round Icons"] = "Round Icons" },
    esES = { ["Player Icon"] = "Icono del jugador", ["Specialization Icon"] = "Icono de especialización", ["Class Icon"] = "Icono de clase", ["No Icon"] = "Sin icono", ["Square Icons"] = "Iconos cuadrados", ["Round Icons"] = "Iconos redondos" },
    deDE = { ["Player Icon"] = "Spieler-Icon", ["Specialization Icon"] = "Spezialisierungs-Icon", ["Class Icon"] = "Klassen-Icon", ["No Icon"] = "Kein Icon", ["Square Icons"] = "Quadratische Symbole", ["Round Icons"] = "Runde Symbole" },
    frFR = { ["Player Icon"] = "Icône du joueur", ["Specialization Icon"] = "Icône de spécialisation", ["Class Icon"] = "Icône de classe", ["No Icon"] = "Aucune icône", ["Square Icons"] = "Icônes carrées", ["Round Icons"] = "Icônes rondes" },
    itIT = { ["Player Icon"] = "Icona del giocatore", ["Specialization Icon"] = "Icona della specializzazione", ["Class Icon"] = "Icona della classe", ["No Icon"] = "Nessuna icona", ["Square Icons"] = "Icone quadrate", ["Round Icons"] = "Icone rotonde" },
    ptBR = { ["Player Icon"] = "Ícone do jogador", ["Specialization Icon"] = "Ícone de especialização", ["Class Icon"] = "Ícone de classe", ["No Icon"] = "Sem ícone", ["Square Icons"] = "Ícones quadrados", ["Round Icons"] = "Ícones redondos" },
    ruRU = { ["Player Icon"] = "Иконка игрока", ["Specialization Icon"] = "Иконка специализации", ["Class Icon"] = "Иконка класса", ["No Icon"] = "Без иконки", ["Square Icons"] = "Квадратные значки", ["Round Icons"] = "Круглые значки" },
    koKR = { ["Player Icon"] = "플레이어 아이콘", ["Specialization Icon"] = "전문화 아이콘", ["Class Icon"] = "직업 아이콘", ["No Icon"] = "아이콘 없음", ["Square Icons"] = "사각형 아이콘", ["Round Icons"] = "원형 아이콘" },
    zhCN = { ["Player Icon"] = "玩家图标", ["Specialization Icon"] = "专精图标", ["Class Icon"] = "职业图标", ["No Icon"] = "无图标", ["Square Icons"] = "方形图标", ["Round Icons"] = "圆形图标" },
    zhTW = { ["Player Icon"] = "玩家圖示", ["Specialization Icon"] = "專精圖示", ["Class Icon"] = "職業圖示", ["No Icon"] = "無圖示", ["Square Icons"] = "方形圖示", ["Round Icons"] = "圓形圖示" },
}
for localeKey, entries in pairs(damageMeterIconLocales) do
    apply(locales[localeKey], entries)
end
apply(locales.esMX, damageMeterIconLocales.esES)
apply(locales.ptPT, damageMeterIconLocales.ptBR)
local damageMeterAutoHeightLocales = {
    enUS = "Auto-fit Window Height",
    esES = "Ajustar automáticamente la altura",
    deDE = "Fensterhöhe automatisch anpassen",
    frFR = "Ajuster automatiquement la hauteur",
    itIT = "Adatta automaticamente l'altezza",
    ptBR = "Ajustar altura automaticamente",
    ruRU = "Автоподбор высоты окна",
    koKR = "창 높이 자동 맞춤",
    zhCN = "自动适应窗口高度",
    zhTW = "自動調整視窗高度",
}
for localeKey, label in pairs(damageMeterAutoHeightLocales) do
    apply(locales[localeKey], { ["Auto-fit Window Height"] = label })
end
apply(locales.esMX, { ["Auto-fit Window Height"] = damageMeterAutoHeightLocales.esES })
apply(locales.ptPT, { ["Auto-fit Window Height"] = damageMeterAutoHeightLocales.ptBR })
-- Damage Meter typography and bar texture options.
local damageMeterMediaLocales = {
    enUS = {
        ["Damage Meter Font"] = "Damage Meter Font", ["Bar Texture"] = "Bar Texture",
        ["Avant Garde"] = "Avant Garde", ["Fira Sans"] = "Fira Sans", ["Ubuntu"] = "Ubuntu",
        ["Poppins"] = "Poppins", ["Tempesta Seven"] = "Tempesta Seven",
        ["Melli"] = "Melli", ["Melli Dark"] = "Melli Dark", ["Statusbar Clean"] = "Statusbar Clean",
        ["Statusbar Stripes Thin"] = "Statusbar Stripes Thin", ["Statusbar Stripes"] = "Statusbar Stripes",
        ["Stripe Bar"] = "Stripe Bar",
    },
    esES = {
        ["Damage Meter Font"] = "Fuente del medidor de daño", ["Bar Texture"] = "Textura de barra",
        ["Avant Garde"] = "Avant Garde", ["Fira Sans"] = "Fira Sans", ["Ubuntu"] = "Ubuntu",
        ["Poppins"] = "Poppins", ["Tempesta Seven"] = "Tempesta Seven",
        ["Melli"] = "Melli", ["Melli Dark"] = "Melli oscuro", ["Statusbar Clean"] = "Barra limpia",
        ["Statusbar Stripes Thin"] = "Barra de rayas fina", ["Statusbar Stripes"] = "Barra de rayas",
        ["Stripe Bar"] = "Barra rayada",
    },
    deDE = {
        ["Damage Meter Font"] = "Schadensmeter-Schriftart", ["Bar Texture"] = "Leistentextur",
        ["Avant Garde"] = "Avant Garde", ["Fira Sans"] = "Fira Sans", ["Ubuntu"] = "Ubuntu",
        ["Poppins"] = "Poppins", ["Tempesta Seven"] = "Tempesta Seven",
        ["Melli"] = "Melli", ["Melli Dark"] = "Melli dunkel", ["Statusbar Clean"] = "Statusleiste sauber",
        ["Statusbar Stripes Thin"] = "Statusleiste feine Streifen", ["Statusbar Stripes"] = "Statusleistenstreifen",
        ["Stripe Bar"] = "Streifenleiste",
    },
    frFR = {
        ["Damage Meter Font"] = "Police du compteur de dégâts", ["Bar Texture"] = "Texture de barre",
        ["Avant Garde"] = "Avant Garde", ["Fira Sans"] = "Fira Sans", ["Ubuntu"] = "Ubuntu",
        ["Poppins"] = "Poppins", ["Tempesta Seven"] = "Tempesta Seven",
        ["Melli"] = "Melli", ["Melli Dark"] = "Melli sombre", ["Statusbar Clean"] = "Barre propre",
        ["Statusbar Stripes Thin"] = "Barre à fines rayures", ["Statusbar Stripes"] = "Barre rayée",
        ["Stripe Bar"] = "Barre rayée",
    },
    itIT = {
        ["Damage Meter Font"] = "Carattere del misuratore danni", ["Bar Texture"] = "Texture barra",
        ["Avant Garde"] = "Avant Garde", ["Fira Sans"] = "Fira Sans", ["Ubuntu"] = "Ubuntu",
        ["Poppins"] = "Poppins", ["Tempesta Seven"] = "Tempesta Seven",
        ["Melli"] = "Melli", ["Melli Dark"] = "Melli scuro", ["Statusbar Clean"] = "Barra pulita",
        ["Statusbar Stripes Thin"] = "Barra a strisce sottili", ["Statusbar Stripes"] = "Barra a strisce",
        ["Stripe Bar"] = "Barra a strisce",
    },
    ptBR = {
        ["Damage Meter Font"] = "Fonte do medidor de dano", ["Bar Texture"] = "Textura da barra",
        ["Avant Garde"] = "Avant Garde", ["Fira Sans"] = "Fira Sans", ["Ubuntu"] = "Ubuntu",
        ["Poppins"] = "Poppins", ["Tempesta Seven"] = "Tempesta Seven",
        ["Melli"] = "Melli", ["Melli Dark"] = "Melli escuro", ["Statusbar Clean"] = "Barra limpa",
        ["Statusbar Stripes Thin"] = "Barra de listras fina", ["Statusbar Stripes"] = "Barra de listras",
        ["Stripe Bar"] = "Barra listrada",
    },
    ruRU = {
        ["Damage Meter Font"] = "Шрифт измерителя урона", ["Bar Texture"] = "Текстура полосы",
        ["Avant Garde"] = "Avant Garde", ["Fira Sans"] = "Fira Sans", ["Ubuntu"] = "Ubuntu",
        ["Poppins"] = "Poppins", ["Tempesta Seven"] = "Tempesta Seven",
        ["Melli"] = "Melli", ["Melli Dark"] = "Тёмный Melli", ["Statusbar Clean"] = "Чистая полоса",
        ["Statusbar Stripes Thin"] = "Полоса с тонкими полосами", ["Statusbar Stripes"] = "Полоса с полосами",
        ["Stripe Bar"] = "Полоса с узором",
    },
    koKR = {
        ["Damage Meter Font"] = "피해 미터 글꼴", ["Bar Texture"] = "바 텍스처",
        ["Avant Garde"] = "Avant Garde", ["Fira Sans"] = "Fira Sans", ["Ubuntu"] = "Ubuntu",
        ["Poppins"] = "Poppins", ["Tempesta Seven"] = "Tempesta Seven",
        ["Melli"] = "Melli", ["Melli Dark"] = "어두운 Melli", ["Statusbar Clean"] = "깔끔한 상태 표시줄",
        ["Statusbar Stripes Thin"] = "얇은 줄무늬 상태 표시줄", ["Statusbar Stripes"] = "줄무늬 상태 표시줄",
        ["Stripe Bar"] = "줄무늬 바",
    },
    zhCN = {
        ["Damage Meter Font"] = "伤害统计字体", ["Bar Texture"] = "条纹理",
        ["Avant Garde"] = "Avant Garde", ["Fira Sans"] = "Fira Sans", ["Ubuntu"] = "Ubuntu",
        ["Poppins"] = "Poppins", ["Tempesta Seven"] = "Tempesta Seven",
        ["Melli"] = "Melli", ["Melli Dark"] = "深色 Melli", ["Statusbar Clean"] = "干净状态条",
        ["Statusbar Stripes Thin"] = "细条纹状态条", ["Statusbar Stripes"] = "条纹状态条",
        ["Stripe Bar"] = "条纹条",
    },
    zhTW = {
        ["Damage Meter Font"] = "傷害統計字型", ["Bar Texture"] = "條紋理",
        ["Avant Garde"] = "Avant Garde", ["Fira Sans"] = "Fira Sans", ["Ubuntu"] = "Ubuntu",
        ["Poppins"] = "Poppins", ["Tempesta Seven"] = "Tempesta Seven",
        ["Melli"] = "Melli", ["Melli Dark"] = "深色 Melli", ["Statusbar Clean"] = "乾淨狀態列",
        ["Statusbar Stripes Thin"] = "細條紋狀態列", ["Statusbar Stripes"] = "條紋狀態列",
        ["Stripe Bar"] = "條紋條",
    },
}
for localeKey, entries in pairs(damageMeterMediaLocales) do
    apply(locales[localeKey], entries)
end
apply(locales.esMX, damageMeterMediaLocales.esES)
apply(locales.ptPT, damageMeterMediaLocales.ptBR)
-- Mythic+ completed objective colour.
local mythicPlusObjectiveColorLocales = {
    enUS = "Completed Objectives Color",
    esES = "Color de objetivos completados",
    deDE = "Farbe abgeschlossener Ziele",
    frFR = "Couleur des objectifs terminés",
    itIT = "Colore degli obiettivi completati",
    ptBR = "Cor dos objetivos concluídos",
    ruRU = "Цвет выполненных целей",
    koKR = "완료된 목표 색상",
    zhCN = "已完成目标颜色",
    zhTW = "已完成目標顏色",
}
for localeKey, label in pairs(mythicPlusObjectiveColorLocales) do
    apply(locales[localeKey], { ["Completed Objectives Color"] = label })
end
apply(locales.esMX, { ["Completed Objectives Color"] = mythicPlusObjectiveColorLocales.esES })
apply(locales.ptPT, { ["Completed Objectives Color"] = mythicPlusObjectiveColorLocales.ptBR })
-- Mythic+ Timer display labels.
local mythicPlusDisplayLocales = {
    enUS = { ["Tracker Font"] = "Tracker Font", ["Bar Width"] = "Bar Width" },
    esES = { ["Tracker Font"] = "Fuente del tracker", ["Bar Width"] = "Ancho de las barras" },
    deDE = { ["Tracker Font"] = "Tracker-Schriftart", ["Bar Width"] = "Leistenbreite" },
    frFR = { ["Tracker Font"] = "Police du suivi", ["Bar Width"] = "Largeur des barres" },
    itIT = { ["Tracker Font"] = "Carattere del tracker", ["Bar Width"] = "Larghezza delle barre" },
    ptBR = { ["Tracker Font"] = "Fonte do rastreador", ["Bar Width"] = "Largura das barras" },
    ruRU = { ["Tracker Font"] = "Шрифт трекера", ["Bar Width"] = "Ширина полос" },
    koKR = { ["Tracker Font"] = "추적기 글꼴", ["Bar Width"] = "바 너비" },
    zhCN = { ["Tracker Font"] = "追踪器字体", ["Bar Width"] = "条宽度" },
    zhTW = { ["Tracker Font"] = "追蹤器字型", ["Bar Width"] = "條寬度" },
}
for localeKey, entries in pairs(mythicPlusDisplayLocales) do
    apply(locales[localeKey], entries)
end
apply(locales.esMX, mythicPlusDisplayLocales.esES)
apply(locales.ptPT, mythicPlusDisplayLocales.ptBR)
-- Mythic+ Timer individual bar font options.
local mythicPlusBarFontLocales = {
    enUS = {
        ["Tracker Media"] = "Tracker Media", ["Chest +3 Font"] = "Chest +3 Font",
        ["Chest +2 Font"] = "Chest +2 Font", ["Chest +1 Font"] = "Chest +1 Font", ["Mobs Font"] = "Mobs Font",
    },
    esES = {
        ["Tracker Media"] = "Medios del tracker", ["Chest +3 Font"] = "Fuente cofre +3",
        ["Chest +2 Font"] = "Fuente cofre +2", ["Chest +1 Font"] = "Fuente cofre +1", ["Mobs Font"] = "Fuente de mobs",
    },
    deDE = {
        ["Tracker Media"] = "Tracker-Medien", ["Chest +3 Font"] = "Schriftart Truhe +3",
        ["Chest +2 Font"] = "Schriftart Truhe +2", ["Chest +1 Font"] = "Schriftart Truhe +1", ["Mobs Font"] = "Schriftart Gegner",
    },
    frFR = {
        ["Tracker Media"] = "Médias du suivi", ["Chest +3 Font"] = "Police coffre +3",
        ["Chest +2 Font"] = "Police coffre +2", ["Chest +1 Font"] = "Police coffre +1", ["Mobs Font"] = "Police des créatures",
    },
    itIT = {
        ["Tracker Media"] = "Elementi grafici del tracker", ["Chest +3 Font"] = "Carattere forziere +3",
        ["Chest +2 Font"] = "Carattere forziere +2", ["Chest +1 Font"] = "Carattere forziere +1", ["Mobs Font"] = "Carattere mob",
    },
    ptBR = {
        ["Tracker Media"] = "Mídia do rastreador", ["Chest +3 Font"] = "Fonte do baú +3",
        ["Chest +2 Font"] = "Fonte do baú +2", ["Chest +1 Font"] = "Fonte do baú +1", ["Mobs Font"] = "Fonte dos mobs",
    },
    ruRU = {
        ["Tracker Media"] = "Медиа трекера", ["Chest +3 Font"] = "Шрифт сундука +3",
        ["Chest +2 Font"] = "Шрифт сундука +2", ["Chest +1 Font"] = "Шрифт сундука +1", ["Mobs Font"] = "Шрифт противников",
    },
    koKR = {
        ["Tracker Media"] = "추적기 미디어", ["Chest +3 Font"] = "상자 +3 글꼴",
        ["Chest +2 Font"] = "상자 +2 글꼴", ["Chest +1 Font"] = "상자 +1 글꼴", ["Mobs Font"] = "몹 글꼴",
    },
    zhCN = {
        ["Tracker Media"] = "追踪器媒体", ["Chest +3 Font"] = "宝箱 +3 字体",
        ["Chest +2 Font"] = "宝箱 +2 字体", ["Chest +1 Font"] = "宝箱 +1 字体", ["Mobs Font"] = "小怪字体",
    },
    zhTW = {
        ["Tracker Media"] = "追蹤器媒體", ["Chest +3 Font"] = "寶箱 +3 字型",
        ["Chest +2 Font"] = "寶箱 +2 字型", ["Chest +1 Font"] = "寶箱 +1 字型", ["Mobs Font"] = "小怪字型",
    },
}
for localeKey, entries in pairs(mythicPlusBarFontLocales) do
    apply(locales[localeKey], entries)
end
apply(locales.esMX, mythicPlusBarFontLocales.esES)
apply(locales.ptPT, mythicPlusBarFontLocales.ptBR)
-- Mythic+ Timer remaining-time display option.
local mythicPlusRemainingTimeLocales = {
    enUS = { ["Show Remaining Time Only"] = "Show Remaining Time Only" },
    esES = { ["Show Remaining Time Only"] = "Mostrar solo el tiempo restante" },
    deDE = { ["Show Remaining Time Only"] = "Nur verbleibende Zeit anzeigen" },
    frFR = { ["Show Remaining Time Only"] = "Afficher uniquement le temps restant" },
    itIT = { ["Show Remaining Time Only"] = "Mostra solo il tempo rimanente" },
    ptBR = { ["Show Remaining Time Only"] = "Mostrar apenas o tempo restante" },
    ruRU = { ["Show Remaining Time Only"] = "Показывать только оставшееся время" },
    koKR = { ["Show Remaining Time Only"] = "남은 시간만 표시" },
    zhCN = { ["Show Remaining Time Only"] = "仅显示剩余时间" },
    zhTW = { ["Show Remaining Time Only"] = "只顯示剩餘時間" },
}
for localeKey, entries in pairs(mythicPlusRemainingTimeLocales) do
    apply(locales[localeKey], entries)
end
apply(locales.esMX, mythicPlusRemainingTimeLocales.esES)
apply(locales.ptPT, mythicPlusRemainingTimeLocales.ptBR)
-- Mythic+ Timer module label.
local mythicPlusTimerLabelLocales = {
    enUS = "Mythic+ Timer",
    esES = "Temporizador de Míticas+",
    deDE = "Mythisch+-Timer",
    frFR = "Chronomètre Mythique+",
    itIT = "Timer Mitiche+",
    ptBR = "Temporizador de Míticas+",
    ruRU = "Таймер эпохальных+",
    koKR = "쐐기돌 타이머",
    zhCN = "史诗钥石计时器",
    zhTW = "傳奇鑰石計時器",
}
for localeKey, label in pairs(mythicPlusTimerLabelLocales) do
    apply(locales[localeKey], { ["Mythic+ Timer"] = label })
end
apply(locales.esMX, { ["Mythic+ Timer"] = mythicPlusTimerLabelLocales.esES })
apply(locales.ptPT, { ["Mythic+ Timer"] = mythicPlusTimerLabelLocales.ptBR })

-- Shared dialogs and status messages that were previously hardcoded in Spanish.
local sharedDialogLocales = {
    enUS = {
        ["Select"] = "Select",
        ["Paste a profile string before importing."] = "Paste a profile string before importing.",
        ["The profile could not be imported."] = "The profile could not be imported.",
        ["Text selected. Press Ctrl+C to copy it."] = "Text selected. Press Ctrl+C to copy it.",
        ["Reloading the interface is recommended to apply the profile change.\n\n%s"] = "Reloading the interface is recommended to apply the profile change.\n\n%s",
        ["The profile contains no data for those modules."] = "The profile contains no data for those modules.",
        ["KullThranUI: Reload the UI to apply the changes."] = "KullThranUI: Reload the UI to apply the changes.",
        ["|cffFF4444Warning:|r This will restore all KullThranUI settings to their defaults and reload the UI."] = "|cffFF4444Warning:|r This will restore all KullThranUI settings to their defaults and reload the UI.",
        ["Continue"] = "Continue",
        ["|cffFF2222Final confirmation:|r Your KullThranUI profile will be fully reset, the installer will reopen, and the UI will reload. This action cannot be undone."] = "|cffFF2222Final confirmation:|r Your KullThranUI profile will be fully reset, the installer will reopen, and the UI will reload. This action cannot be undone.",
        ["Reset Now"] = "Reset Now",
        ["Modules refreshed"] = "Modules refreshed",
        ["|cffFF0000ERROR:|r SetupOptions was not found."] = "|cffFF0000ERROR:|r SetupOptions was not found.",
    },
    esES = {
        ["Select"] = "Seleccionar",
        ["Paste a profile string before importing."] = "Pega una cadena de perfil antes de importar.",
        ["The profile could not be imported."] = "No se pudo importar el perfil.",
        ["Text selected. Press Ctrl+C to copy it."] = "Texto seleccionado. Pulsa Ctrl+C para copiarlo.",
        ["Reloading the interface is recommended to apply the profile change.\n\n%s"] = "Se recomienda recargar la interfaz para aplicar el cambio de perfil.\n\n%s",
        ["The profile contains no data for those modules."] = "El perfil no contiene datos para esos módulos.",
        ["KullThranUI: Reload the UI to apply the changes."] = "KullThranUI: Recarga la interfaz para aplicar los cambios.",
        ["|cffFF4444Warning:|r This will restore all KullThranUI settings to their defaults and reload the UI."] = "|cffFF4444Atención:|r Esto restaurará todos los ajustes de KullThranUI a sus valores predeterminados y recargará la interfaz.",
        ["Continue"] = "Continuar",
        ["|cffFF2222Final confirmation:|r Your KullThranUI profile will be fully reset, the installer will reopen, and the UI will reload. This action cannot be undone."] = "|cffFF2222Confirmación final:|r Tu perfil de KullThranUI se restablecerá por completo, el asistente volverá a abrirse y la interfaz se recargará. Esta acción no se puede deshacer.",
        ["Reset Now"] = "Restablecer ahora",
        ["Modules refreshed"] = "Módulos actualizados",
        ["|cffFF0000ERROR:|r SetupOptions was not found."] = "|cffFF0000ERROR:|r No se encontró SetupOptions.",
    },
    frFR = {
        ["Select"] = "Sélectionner",
        ["Paste a profile string before importing."] = "Collez une chaîne de profil avant l’importation.",
        ["The profile could not be imported."] = "Le profil n’a pas pu être importé.",
        ["Text selected. Press Ctrl+C to copy it."] = "Texte sélectionné. Appuyez sur Ctrl+C pour le copier.",
        ["Reloading the interface is recommended to apply the profile change.\n\n%s"] = "Il est recommandé de recharger l’interface pour appliquer le changement de profil.\n\n%s",
        ["The profile contains no data for those modules."] = "Le profil ne contient aucune donnée pour ces modules.",
        ["KullThranUI: Reload the UI to apply the changes."] = "KullThranUI : rechargez l’interface pour appliquer les modifications.",
        ["|cffFF4444Warning:|r This will restore all KullThranUI settings to their defaults and reload the UI."] = "|cffFF4444Attention :|r tous les réglages de KullThranUI seront réinitialisés et l’interface sera rechargée.",
        ["Continue"] = "Continuer",
        ["|cffFF2222Final confirmation:|r Your KullThranUI profile will be fully reset, the installer will reopen, and the UI will reload. This action cannot be undone."] = "|cffFF2222Confirmation finale :|r votre profil KullThranUI sera entièrement réinitialisé, l’assistant rouvrira et l’interface sera rechargée. Cette action est irréversible.",
        ["Reset Now"] = "Réinitialiser maintenant",
        ["Modules refreshed"] = "Modules actualisés",
        ["|cffFF0000ERROR:|r SetupOptions was not found."] = "|cffFF0000ERREUR :|r SetupOptions est introuvable.",
    },
    deDE = {
        ["Select"] = "Auswählen",
        ["Paste a profile string before importing."] = "Füge vor dem Import eine Profilzeichenfolge ein.",
        ["The profile could not be imported."] = "Das Profil konnte nicht importiert werden.",
        ["Text selected. Press Ctrl+C to copy it."] = "Text ausgewählt. Drücke Strg+C zum Kopieren.",
        ["Reloading the interface is recommended to apply the profile change.\n\n%s"] = "Es wird empfohlen, die Benutzeroberfläche neu zu laden, um den Profilwechsel anzuwenden.\n\n%s",
        ["The profile contains no data for those modules."] = "Das Profil enthält keine Daten für diese Module.",
        ["KullThranUI: Reload the UI to apply the changes."] = "KullThranUI: Lade die Benutzeroberfläche neu, um die Änderungen anzuwenden.",
        ["|cffFF4444Warning:|r This will restore all KullThranUI settings to their defaults and reload the UI."] = "|cffFF4444Warnung:|r Alle KullThranUI-Einstellungen werden zurückgesetzt und die Benutzeroberfläche wird neu geladen.",
        ["Continue"] = "Fortfahren",
        ["|cffFF2222Final confirmation:|r Your KullThranUI profile will be fully reset, the installer will reopen, and the UI will reload. This action cannot be undone."] = "|cffFF2222Letzte Bestätigung:|r Dein KullThranUI-Profil wird vollständig zurückgesetzt, der Installer wird erneut geöffnet und die Benutzeroberfläche neu geladen. Dies kann nicht rückgängig gemacht werden.",
        ["Reset Now"] = "Jetzt zurücksetzen",
        ["Modules refreshed"] = "Module aktualisiert",
        ["|cffFF0000ERROR:|r SetupOptions was not found."] = "|cffFF0000FEHLER:|r SetupOptions wurde nicht gefunden.",
    },
    itIT = {
        ["Select"] = "Seleziona",
        ["Paste a profile string before importing."] = "Incolla una stringa del profilo prima di importare.",
        ["The profile could not be imported."] = "Impossibile importare il profilo.",
        ["Text selected. Press Ctrl+C to copy it."] = "Testo selezionato. Premi Ctrl+C per copiarlo.",
        ["Reloading the interface is recommended to apply the profile change.\n\n%s"] = "Si consiglia di ricaricare l’interfaccia per applicare il cambio di profilo.\n\n%s",
        ["The profile contains no data for those modules."] = "Il profilo non contiene dati per questi moduli.",
        ["KullThranUI: Reload the UI to apply the changes."] = "KullThranUI: ricarica l’interfaccia per applicare le modifiche.",
        ["|cffFF4444Warning:|r This will restore all KullThranUI settings to their defaults and reload the UI."] = "|cffFF4444Attenzione:|r tutte le impostazioni di KullThranUI verranno ripristinate e l’interfaccia sarà ricaricata.",
        ["Continue"] = "Continua",
        ["|cffFF2222Final confirmation:|r Your KullThranUI profile will be fully reset, the installer will reopen, and the UI will reload. This action cannot be undone."] = "|cffFF2222Conferma finale:|r il profilo KullThranUI verrà ripristinato completamente, il programma di installazione verrà riaperto e l’interfaccia ricaricata. Questa azione non può essere annullata.",
        ["Reset Now"] = "Ripristina ora",
        ["Modules refreshed"] = "Moduli aggiornati",
        ["|cffFF0000ERROR:|r SetupOptions was not found."] = "|cffFF0000ERRORE:|r SetupOptions non è stato trovato.",
    },
    ptBR = {
        ["Select"] = "Selecionar",
        ["Paste a profile string before importing."] = "Cole uma sequência de perfil antes de importar.",
        ["The profile could not be imported."] = "Não foi possível importar o perfil.",
        ["Text selected. Press Ctrl+C to copy it."] = "Texto selecionado. Pressione Ctrl+C para copiá-lo.",
        ["Reloading the interface is recommended to apply the profile change.\n\n%s"] = "Recomenda-se recarregar a interface para aplicar a mudança de perfil.\n\n%s",
        ["The profile contains no data for those modules."] = "O perfil não contém dados para esses módulos.",
        ["KullThranUI: Reload the UI to apply the changes."] = "KullThranUI: recarregue a interface para aplicar as alterações.",
        ["|cffFF4444Warning:|r This will restore all KullThranUI settings to their defaults and reload the UI."] = "|cffFF4444Aviso:|r todas as configurações do KullThranUI serão restauradas e a interface será recarregada.",
        ["Continue"] = "Continuar",
        ["|cffFF2222Final confirmation:|r Your KullThranUI profile will be fully reset, the installer will reopen, and the UI will reload. This action cannot be undone."] = "|cffFF2222Confirmação final:|r seu perfil do KullThranUI será totalmente redefinido, o instalador será reaberto e a interface será recarregada. Esta ação não pode ser desfeita.",
        ["Reset Now"] = "Redefinir agora",
        ["Modules refreshed"] = "Módulos atualizados",
        ["|cffFF0000ERROR:|r SetupOptions was not found."] = "|cffFF0000ERRO:|r SetupOptions não foi encontrado.",
    },
    ruRU = {
        ["Select"] = "Выбрать",
        ["Paste a profile string before importing."] = "Вставьте строку профиля перед импортом.",
        ["The profile could not be imported."] = "Не удалось импортировать профиль.",
        ["Text selected. Press Ctrl+C to copy it."] = "Текст выделен. Нажмите Ctrl+C, чтобы скопировать его.",
        ["Reloading the interface is recommended to apply the profile change.\n\n%s"] = "Для применения смены профиля рекомендуется перезагрузить интерфейс.\n\n%s",
        ["The profile contains no data for those modules."] = "Профиль не содержит данных для этих модулей.",
        ["KullThranUI: Reload the UI to apply the changes."] = "KullThranUI: перезагрузите интерфейс, чтобы применить изменения.",
        ["|cffFF4444Warning:|r This will restore all KullThranUI settings to their defaults and reload the UI."] = "|cffFF4444Внимание:|r все настройки KullThranUI будут сброшены, а интерфейс перезагружен.",
        ["Continue"] = "Продолжить",
        ["|cffFF2222Final confirmation:|r Your KullThranUI profile will be fully reset, the installer will reopen, and the UI will reload. This action cannot be undone."] = "|cffFF2222Последнее подтверждение:|r профиль KullThranUI будет полностью сброшен, установщик откроется снова, а интерфейс перезагрузится. Это действие нельзя отменить.",
        ["Reset Now"] = "Сбросить сейчас",
        ["Modules refreshed"] = "Модули обновлены",
        ["|cffFF0000ERROR:|r SetupOptions was not found."] = "|cffFF0000ОШИБКА:|r SetupOptions не найден.",
    },
    koKR = {
        ["Select"] = "선택",
        ["Paste a profile string before importing."] = "가져오기 전에 프로필 문자열을 붙여넣으세요.",
        ["The profile could not be imported."] = "프로필을 가져올 수 없습니다.",
        ["Text selected. Press Ctrl+C to copy it."] = "텍스트가 선택되었습니다. Ctrl+C를 눌러 복사하세요.",
        ["Reloading the interface is recommended to apply the profile change.\n\n%s"] = "프로필 변경을 적용하려면 인터페이스를 다시 불러오는 것이 좋습니다.\n\n%s",
        ["The profile contains no data for those modules."] = "프로필에 해당 모듈의 데이터가 없습니다.",
        ["KullThranUI: Reload the UI to apply the changes."] = "KullThranUI: 변경 사항을 적용하려면 인터페이스를 다시 불러오세요.",
        ["|cffFF4444Warning:|r This will restore all KullThranUI settings to their defaults and reload the UI."] = "|cffFF4444경고:|r 모든 KullThranUI 설정을 기본값으로 복원하고 인터페이스를 다시 불러옵니다.",
        ["Continue"] = "계속",
        ["|cffFF2222Final confirmation:|r Your KullThranUI profile will be fully reset, the installer will reopen, and the UI will reload. This action cannot be undone."] = "|cffFF2222최종 확인:|r KullThranUI 프로필이 완전히 초기화되고 설치 도우미가 다시 열리며 인터페이스가 다시 불러와집니다. 이 작업은 되돌릴 수 없습니다.",
        ["Reset Now"] = "지금 초기화",
        ["Modules refreshed"] = "모듈 새로 고침 완료",
        ["|cffFF0000ERROR:|r SetupOptions was not found."] = "|cffFF0000오류:|r SetupOptions를 찾을 수 없습니다.",
    },
    zhCN = {
        ["Select"] = "选择",
        ["Paste a profile string before importing."] = "请先粘贴配置字符串再导入。",
        ["The profile could not be imported."] = "无法导入配置。",
        ["Text selected. Press Ctrl+C to copy it."] = "文本已选中。按 Ctrl+C 复制。",
        ["Reloading the interface is recommended to apply the profile change.\n\n%s"] = "建议重新加载界面以应用配置更改。\n\n%s",
        ["The profile contains no data for those modules."] = "配置中没有这些模块的数据。",
        ["KullThranUI: Reload the UI to apply the changes."] = "KullThranUI：重新加载界面以应用更改。",
        ["|cffFF4444Warning:|r This will restore all KullThranUI settings to their defaults and reload the UI."] = "|cffFF4444警告：|r这会将所有 KullThranUI 设置恢复为默认值并重新加载界面。",
        ["Continue"] = "继续",
        ["|cffFF2222Final confirmation:|r Your KullThranUI profile will be fully reset, the installer will reopen, and the UI will reload. This action cannot be undone."] = "|cffFF2222最终确认：|rKullThranUI 配置将被完全重置，安装助手会重新打开，界面也会重新加载。此操作无法撤销。",
        ["Reset Now"] = "立即重置",
        ["Modules refreshed"] = "模块已刷新",
        ["|cffFF0000ERROR:|r SetupOptions was not found."] = "|cffFF0000错误：|r未找到 SetupOptions。",
    },
    zhTW = {
        ["Select"] = "選擇",
        ["Paste a profile string before importing."] = "請先貼上設定檔字串再匯入。",
        ["The profile could not be imported."] = "無法匯入設定檔。",
        ["Text selected. Press Ctrl+C to copy it."] = "文字已選取。按 Ctrl+C 複製。",
        ["Reloading the interface is recommended to apply the profile change.\n\n%s"] = "建議重新載入介面以套用設定檔變更。\n\n%s",
        ["The profile contains no data for those modules."] = "設定檔中沒有這些模組的資料。",
        ["KullThranUI: Reload the UI to apply the changes."] = "KullThranUI：重新載入介面以套用變更。",
        ["|cffFF4444Warning:|r This will restore all KullThranUI settings to their defaults and reload the UI."] = "|cffFF4444警告：|r這會將所有 KullThranUI 設定還原為預設值並重新載入介面。",
        ["Continue"] = "繼續",
        ["|cffFF2222Final confirmation:|r Your KullThranUI profile will be fully reset, the installer will reopen, and the UI will reload. This action cannot be undone."] = "|cffFF2222最終確認：|rKullThranUI 設定檔將被完全重設，安裝助手會重新開啟，介面也會重新載入。此操作無法復原。",
        ["Reset Now"] = "立即重設",
        ["Modules refreshed"] = "模組已重新整理",
        ["|cffFF0000ERROR:|r SetupOptions was not found."] = "|cffFF0000錯誤：|r找不到 SetupOptions。",
    },
}
for localeKey, entries in pairs(sharedDialogLocales) do
    apply(locales[localeKey], entries)
end
apply(locales.esMX, sharedDialogLocales.esES)
apply(locales.ptPT, sharedDialogLocales.ptBR)

-- Repair legacy bag-watch labels, placeholders and malformed color resets.
local bagWatchLocales = {
    enUS = { ["BAGS_WATCH"] = "Watch %d", ["BAGS_WATCH_LABEL"] = "Watch" },
    esES = { ["BAGS_WATCH"] = "Vigilar %d", ["BAGS_WATCH_LABEL"] = "Vigilar" },
    frFR = { ["BAGS_WATCH"] = "Suivre %d", ["BAGS_WATCH_LABEL"] = "Suivre" },
    deDE = { ["BAGS_WATCH"] = "%d beobachten", ["BAGS_WATCH_LABEL"] = "Beobachten" },
    itIT = { ["BAGS_WATCH"] = "Monitora %d", ["BAGS_WATCH_LABEL"] = "Monitora" },
    ptBR = { ["BAGS_WATCH"] = "Acompanhar %d", ["BAGS_WATCH_LABEL"] = "Acompanhar" },
    ruRU = { ["BAGS_WATCH"] = "Отслеживать: %d", ["BAGS_WATCH_LABEL"] = "Отслеживать" },
    koKR = { ["BAGS_WATCH"] = "%d개 추적", ["BAGS_WATCH_LABEL"] = "추적" },
    zhCN = { ["BAGS_WATCH"] = "追踪 %d", ["BAGS_WATCH_LABEL"] = "追踪" },
    zhTW = { ["BAGS_WATCH"] = "追蹤 %d", ["BAGS_WATCH_LABEL"] = "追蹤" },
}
for localeKey, entries in pairs(bagWatchLocales) do
    apply(locales[localeKey], entries)
end
apply(locales.esMX, bagWatchLocales.esES)
apply(locales.ptPT, bagWatchLocales.ptBR)

local dragDropHelpKey = "|cff00ff00Drag & Drop|r a Spell or Item from your Spellbook\ninto this area or the book button to track it."
apply(locales.ptBR, {
    [dragDropHelpKey] = "|cff00ff00Arraste e solte|r um feitiço ou item do seu livro de feitiços\nnesta área ou no botão do livro para rastreá-lo.",
})
apply(locales.ptPT, { [dragDropHelpKey] = locales.ptBR[dragDropHelpKey] })
apply(locales.ruRU, {
    [dragDropHelpKey] = "|cff00ff00Перетащите|r заклинание или предмет из книги заклинаний\nв эту область или на кнопку книги, чтобы начать отслеживание.",
})
apply(locales.zhCN, {
    [dragDropHelpKey] = "|cff00ff00拖放|r法术或物品到此区域，或拖到书本按钮上以开始追踪。",
})
apply(locales.zhTW, {
    [dragDropHelpKey] = "|cff00ff00拖放|r法術或物品到此區域，或拖到書本按鈕上以開始追蹤。",
})
apply(locales.koKR, {
    ["↑ Drag & Drop Spell Here ↑"] = "↑ 여기에 주문을 끌어다 놓으세요 ↑",
})

apply(locales.frFR, {
    ["Backdrop Transparency %"] = "Transparence de l’arrière-plan (%)",
})
apply(locales.ptBR, {
    ["Backdrop Transparency %"] = "Transparência do fundo (%)",
})
apply(locales.ptPT, {
    ["Backdrop Transparency %"] = "Transparência do fundo (%)",
})

-- Missing dropdown/label keys now resolved through widget LText paths.
apply(locales.esES, {
    -- CDM: Hide-When conditions
    ["While Casting"] = "Mientras lanzas",
    ["Boss Encounter"] = "Encuentro de jefe",
    ["In Instance"] = "En mazmorra",
    ["In Vehicle / Taxi"] = "En vehículo / Taxi",
    ["Mounted"] = "Montado",
    ["Flying"] = "Volando",
    ["Skyriding"] = "Vuelo libre",
    ["Swimming"] = "Nadando",
    ["Resting (City/Inn)"] = "Descansando (ciudad/posada)",
    ["Dead / Ghost"] = "Muerto / Fantasma",
    ["In Group"] = "En grupo",
    ["Solo (Not in Group)"] = "Solo (sin grupo)",
    ["In Raid"] = "En banda",
    ["PvP Flagged"] = "Marcado para PvP",
    ["Stealthed"] = "Sigilo",
    -- CDM: sub-tabs
    ["Manage & Layout"] = "Gestión y diseño",
    ["Icon & Effects"] = "Iconos y efectos",
    ["Text & Misc"] = "Texto y varios",
    ["Visibility Rules"] = "Reglas de visibilidad",
    -- CDM: group bar page
    ["Requires 2 or more grouped bars"] = "Requiere 2 o más barras agrupadas",
    ["Group Grow Direction"] = "Dirección de crecimiento del grupo",
    ["Vertical Orientation"] = "Orientación vertical",
    ["Show Name"] = "Mostrar nombre",
    ["Show Timer"] = "Mostrar temporizador",
    ["Timer Size"] = "Tamaño del temporizador",
    ["Gradient Fill"] = "Relleno degradado",
    ["Icon Display"] = "Mostrar icono",
    ["Icon Size"] = "Tamaño del icono",
    ["Name Size"] = "Tamaño del nombre",
    ["Bar Texture"] = "Textura de la barra",
    ["Starting Icon"] = "Icono inicial",
    ["Padding"] = "Relleno",
    ["Anchor"] = "Ancla",
    ["Rows"] = "Filas",
    ["Icons Per Row"] = "Iconos por fila",
    ["Aura Bar Size"] = "Tamaño de la barra de aura",
    ["Cooldown Only"] = "Solo enfriamiento",
    ["Show Stack"] = "Mostrar acumulaciones",
    ["Tooltip Anchor"] = "Ancla del tooltip",
    ["Total Auras"] = "Auras totales",
    ["Nothing"] = "Nada",
    ["All Bars"] = "Todas las barras",
    ["Player Only"] = "Solo el jugador",
    ["Restore all Cooldown Manager settings to defaults?\n\nThis resets CDM Bars, Bar Glows, Buff Bars, and KUI Tracker, then reloads the UI."] = "¿Restablecer todos los ajustes del Cooldown Manager a los valores predeterminados?\n\nEsto reinicia barras del CDM, brillos de barra, barras de buff y KUI Tracker, y luego recarga la interfaz.",
    -- Skins: blizzard frame toggles
    ["Trade Frame"] = "Marco de comercio",
    ["Blizzard Options"] = "Opciones de Blizzard",
    ["Housing"] = "Vivienda",
    ["Collections"] = "Colecciones",
    ["Mail Frame"] = "Marco de correo",
    ["Achievements"] = "Logros",
    ["Professions"] = "Profesiones",
    ["Great Vault"] = "Gran Cámara",
    ["Classic yellow for Blizzard frames"] = "Amarillo clásico para los marcos de Blizzard",
    -- PartyFrames
    ["Arena Enemies"] = "Enemigos de la arena",
    ["Boss"] = "Jefe",
    -- Enhancements
    ["Enable Combat Timer"] = "Activar temporizador de combate",
    ["Show Combat Timer Background"] = "Mostrar fondo del temporizador de combate",
    ["Tank"] = "Tanque",
    ["LFG Automation"] = "Automatización de LFG",
    ["Combat Timer"] = "Temporizador de combate",
    -- Armory stat labels
    ["Strength Label"] = "Etiqueta de fuerza",
    ["Agility Label"] = "Etiqueta de agilidad",
    ["Intellect Label"] = "Etiqueta de intelecto",
    ["Stamina Label"] = "Etiqueta de aguante",
    ["Armor Label"] = "Etiqueta de armadura",
    ["Crit Label"] = "Etiqueta de crítico",
    ["Haste Label"] = "Etiqueta de celeridad",
    ["Mastery Label"] = "Etiqueta de maestría",
    ["Versatility Label"] = "Etiqueta de versatilidad",
    ["Leech Label"] = "Etiqueta de robo de vida",
    ["Avoidance Label"] = "Etiqueta de evasión",
    ["Speed Label"] = "Etiqueta de velocidad",
    ["Dodge Label"] = "Etiqueta de esquiva",
    ["Parry Label"] = "Etiqueta de parada",
    ["Block Label"] = "Etiqueta de bloqueo",
    -- AuraReminders
    ["New Aura"] = "Nueva aura",
    ["Defensive CD"] = "CD defensivo",
    ["Offensive Buff"] = "Buff ofensivo",
    ["Important Debuff"] = "Debuff importante",
    ["Aura Readiness"] = "Preparación de auras",
    ["Preferred Click to Buff"] = "Preferido para buffear con clic",
    ["Pet Reminder"] = "Recordatorio de mascota",
    ["Weapon Enhancement"] = "Mejora de arma",
    ["Augment Rune"] = "Runa de aumento",
    ["Inky Black Potion"] = "Poción de tinta negra",
    ["Inky Black Potion Zone IDs"] = "IDs de zona de la poción de tinta negra",
    ["Add Current Zone"] = "Añadir zona actual",
    ["Attach Important Buffs to Cursor"] = "Adjuntar buffs importantes al cursor",
    ["Show Others Missing"] = "Mostrar los que faltan a otros",
    ["Show Buffs Outside Instances"] = "Mostrar buffs fuera de las mazmorras",
    ["Show Auras Outside Instances"] = "Mostrar auras fuera de las mazmorras",
    ["Show Specials Outside Instances"] = "Mostrar especiales fuera de las mazmorras",
    ["Layout Settings"] = "Ajustes de diseño",
    ["Flask"] = "Frasco",
    ["Food"] = "Comida",
    -- CastBar
    ["Player Cast Bar"] = "Barra de lanzamiento del jugador",
    -- Options.lua
    ["Large"] = "Grande",
    ["Import CDM Spell Profiles"] = "Importar perfiles de hechizos del CDM",
    ["Window Size: "] = "Tamaño de ventana: ",
    -- UnlockMode prefixes (already wrapped with LText in code)
    ["Grid: "] = "Cuadrícula: ",
    ["Snap: "] = "Ajuste: ",
    ["Dark: "] = "Oscuro: ",
    ["Coords: "] = "Coordenadas: ",
    -- Nameplates
    ["Grow"] = "Crecimiento",
    ["Target Glow Style"] = "Estilo de brillo del objetivo",
    ["Vibrant"] = "Vibrante",
    ["Arrows"] = "Flechas",
    ["Show Spell Icon"] = "Mostrar icono del hechizo",
})
apply(locales.esMX, {
    ["While Casting"] = locales.esES["While Casting"],
    ["Boss Encounter"] = locales.esES["Boss Encounter"],
    ["In Instance"] = locales.esES["In Instance"],
    ["In Vehicle / Taxi"] = locales.esES["In Vehicle / Taxi"],
    ["Mounted"] = locales.esES["Mounted"],
    ["Flying"] = locales.esES["Flying"],
    ["Skyriding"] = locales.esES["Skyriding"],
    ["Swimming"] = locales.esES["Swimming"],
    ["Resting (City/Inn)"] = locales.esES["Resting (City/Inn)"],
    ["Dead / Ghost"] = locales.esES["Dead / Ghost"],
    ["In Group"] = locales.esES["In Group"],
    ["Solo (Not in Group)"] = locales.esES["Solo (Not in Group)"],
    ["In Raid"] = locales.esES["In Raid"],
    ["PvP Flagged"] = locales.esES["PvP Flagged"],
    ["Stealthed"] = locales.esES["Stealthed"],
    ["Manage & Layout"] = locales.esES["Manage & Layout"],
    ["Icon & Effects"] = locales.esES["Icon & Effects"],
    ["Text & Misc"] = locales.esES["Text & Misc"],
    ["Visibility Rules"] = locales.esES["Visibility Rules"],
    ["Requires 2 or more grouped bars"] = locales.esES["Requires 2 or more grouped bars"],
    ["Group Grow Direction"] = locales.esES["Group Grow Direction"],
    ["Vertical Orientation"] = locales.esES["Vertical Orientation"],
    ["Show Name"] = locales.esES["Show Name"],
    ["Show Timer"] = locales.esES["Show Timer"],
    ["Timer Size"] = locales.esES["Timer Size"],
    ["Gradient Fill"] = locales.esES["Gradient Fill"],
    ["Icon Display"] = locales.esES["Icon Display"],
    ["Icon Size"] = locales.esES["Icon Size"],
    ["Name Size"] = locales.esES["Name Size"],
    ["Bar Texture"] = locales.esES["Bar Texture"],
    ["Starting Icon"] = locales.esES["Starting Icon"],
    ["Padding"] = locales.esES["Padding"],
    ["Anchor"] = locales.esES["Anchor"],
    ["Rows"] = locales.esES["Rows"],
    ["Icons Per Row"] = locales.esES["Icons Per Row"],
    ["Aura Bar Size"] = locales.esES["Aura Bar Size"],
    ["Cooldown Only"] = locales.esES["Cooldown Only"],
    ["Show Stack"] = locales.esES["Show Stack"],
    ["Tooltip Anchor"] = locales.esES["Tooltip Anchor"],
    ["Total Auras"] = locales.esES["Total Auras"],
    ["Nothing"] = locales.esES["Nothing"],
    ["All Bars"] = locales.esES["All Bars"],
    ["Player Only"] = locales.esES["Player Only"],
    ["Restore all Cooldown Manager settings to defaults?\n\nThis resets CDM Bars, Bar Glows, Buff Bars, and KUI Tracker, then reloads the UI."] = locales.esES["Restore all Cooldown Manager settings to defaults?\n\nThis resets CDM Bars, Bar Glows, Buff Bars, and KUI Tracker, then reloads the UI."],
    ["Trade Frame"] = locales.esES["Trade Frame"],
    ["Blizzard Options"] = locales.esES["Blizzard Options"],
    ["Housing"] = locales.esES["Housing"],
    ["Collections"] = locales.esES["Collections"],
    ["Mail Frame"] = locales.esES["Mail Frame"],
    ["Achievements"] = locales.esES["Achievements"],
    ["Professions"] = locales.esES["Professions"],
    ["Great Vault"] = locales.esES["Great Vault"],
    ["Classic yellow for Blizzard frames"] = locales.esES["Classic yellow for Blizzard frames"],
    ["Arena Enemies"] = locales.esES["Arena Enemies"],
    ["Boss"] = locales.esES["Boss"],
    ["Enable Combat Timer"] = locales.esES["Enable Combat Timer"],
    ["Show Combat Timer Background"] = locales.esES["Show Combat Timer Background"],
    ["Tank"] = locales.esES["Tank"],
    ["LFG Automation"] = locales.esES["LFG Automation"],
    ["Combat Timer"] = locales.esES["Combat Timer"],
    ["Strength Label"] = locales.esES["Strength Label"],
    ["Agility Label"] = locales.esES["Agility Label"],
    ["Intellect Label"] = locales.esES["Intellect Label"],
    ["Stamina Label"] = locales.esES["Stamina Label"],
    ["Armor Label"] = locales.esES["Armor Label"],
    ["Crit Label"] = locales.esES["Crit Label"],
    ["Haste Label"] = locales.esES["Haste Label"],
    ["Mastery Label"] = locales.esES["Mastery Label"],
    ["Versatility Label"] = locales.esES["Versatility Label"],
    ["Leech Label"] = locales.esES["Leech Label"],
    ["Avoidance Label"] = locales.esES["Avoidance Label"],
    ["Speed Label"] = locales.esES["Speed Label"],
    ["Dodge Label"] = locales.esES["Dodge Label"],
    ["Parry Label"] = locales.esES["Parry Label"],
    ["Block Label"] = locales.esES["Block Label"],
    ["New Aura"] = locales.esES["New Aura"],
    ["Defensive CD"] = locales.esES["Defensive CD"],
    ["Offensive Buff"] = locales.esES["Offensive Buff"],
    ["Important Debuff"] = locales.esES["Important Debuff"],
    ["Aura Readiness"] = locales.esES["Aura Readiness"],
    ["Preferred Click to Buff"] = locales.esES["Preferred Click to Buff"],
    ["Pet Reminder"] = locales.esES["Pet Reminder"],
    ["Weapon Enhancement"] = locales.esES["Weapon Enhancement"],
    ["Augment Rune"] = locales.esES["Augment Rune"],
    ["Inky Black Potion"] = locales.esES["Inky Black Potion"],
    ["Inky Black Potion Zone IDs"] = locales.esES["Inky Black Potion Zone IDs"],
    ["Add Current Zone"] = locales.esES["Add Current Zone"],
    ["Attach Important Buffs to Cursor"] = locales.esES["Attach Important Buffs to Cursor"],
    ["Show Others Missing"] = locales.esES["Show Others Missing"],
    ["Show Buffs Outside Instances"] = locales.esES["Show Buffs Outside Instances"],
    ["Show Auras Outside Instances"] = locales.esES["Show Auras Outside Instances"],
    ["Show Specials Outside Instances"] = locales.esES["Show Specials Outside Instances"],
    ["Layout Settings"] = locales.esES["Layout Settings"],
    ["Flask"] = locales.esES["Flask"],
    ["Food"] = locales.esES["Food"],
    ["Player Cast Bar"] = locales.esES["Player Cast Bar"],
    ["Large"] = locales.esES["Large"],
    ["Import CDM Spell Profiles"] = locales.esES["Import CDM Spell Profiles"],
    ["Window Size: "] = locales.esES["Window Size: "],
    ["Grid: "] = locales.esES["Grid: "],
    ["Snap: "] = locales.esES["Snap: "],
    ["Dark: "] = locales.esES["Dark: "],
    ["Coords: "] = locales.esES["Coords: "],
    ["Grow"] = locales.esES["Grow"],
    ["Target Glow Style"] = locales.esES["Target Glow Style"],
    ["Vibrant"] = locales.esES["Vibrant"],
    ["Arrows"] = locales.esES["Arrows"],
    ["Show Spell Icon"] = locales.esES["Show Spell Icon"],
})
