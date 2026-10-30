local _, ns = ...
local locales = ns and ns.Locales
if not locales then return end
local translations = {
    ["Stores 50 keys per character and imports available Blizzard history. Imported keys have no historical gear or party data. Open with /ktkeys."] =
        "Guarda 50 keys por personaje e importa el historial disponible de Blizzard. Las importadas no incluyen equipo ni grupo historico. Abre con /ktkeys.",
    ["Mythic+ History"] = "Historial de miticas+",
    ["Record Mythic+ history"] = "Registrar historial de miticas+",
    ["Open history after completing a key"] = "Abrir el historial al completar una key",
    ["Open Mythic+ history"] = "Abrir historial de miticas+",
    ["Preview history (not saved)"] = "Vista previa del historial (no se guarda)",
    ["Stores the last 50 keys per character. Missing inspection data is shown as --. Use /ktkeys to open."] =
        "Guarda las ultimas 50 keys por personaje. Los datos no disponibles aparecen como --. Abre con /ktkeys.",
}
for _, key in ipairs({"esES", "esMX"}) do
    if locales[key] then
        for source, translated in pairs(translations) do locales[key][source] = translated end
    end
end
