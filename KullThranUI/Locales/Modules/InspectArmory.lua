-- Inspect Armory: style picker and slot border options, for every supported
-- language. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = { "Inspect Style", "Slot Borders", "Show Slot Borders" }

local values = {
    esES = { "Estilo de la inspección", "Bordes de las ranuras", "Mostrar bordes de las ranuras" },
    deDE = { "Betrachtungsstil", "Platzrahmen", "Platzrahmen anzeigen" },
    frFR = { "Style de l’inspection", "Bordures des emplacements", "Afficher les bordures des emplacements" },
    itIT = { "Stile dell’ispezione", "Bordi degli slot", "Mostra i bordi degli slot" },
    ptBR = { "Estilo da inspeção", "Bordas dos espaços", "Mostrar bordas dos espaços" },
    ruRU = { "Стиль осмотра", "Рамки ячеек", "Показывать рамки ячеек" },
    koKR = { "살펴보기 스타일", "슬롯 테두리", "슬롯 테두리 표시" },
    zhCN = { "观察样式", "栏位边框", "显示栏位边框" },
    zhTW = { "觀察樣式", "欄位邊框", "顯示欄位邊框" },
}

local function Apply(target, locale)
    if type(target) ~= "table" then return end
    local translated = values[locale]
    for index, key in ipairs(keys) do
        if target[key] == nil or target[key] == key then
            target[key] = translated and translated[index] or key
        end
    end
end

for _, locale in ipairs({ "enUS", "esES", "deDE", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }) do
    Apply(locales[locale], locale)
end
if locales.esMX and locales.esMX ~= locales.esES then Apply(locales.esMX, "esES") end
if locales.ptPT and locales.ptPT ~= locales.ptBR then Apply(locales.ptPT, "ptBR") end
