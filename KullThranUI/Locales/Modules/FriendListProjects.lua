-- Friend list: the WoW game a Battle.net friend is playing, for every
-- supported language. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "TBC Anniversary",
    "Classic Anniversary",
    "Classic Hardcore",
}

local values = {
    esES = { "TBC Aniversario", "Classic Aniversario", "Classic modo Hardcore" },
    deDE = { "TBC Jubiläum", "Classic Jubiläum", "Classic-Hardcore" },
    frFR = { "TBC Anniversaire", "Classic Anniversaire", "Classic mode Hardcore" },
    itIT = { "TBC Anniversario", "Classic Anniversario", "Classic modalità Hardcore" },
    ptBR = { "TBC Aniversário", "Classic Aniversário", "Classic modo Hardcore" },
    ruRU = { "TBC Юбилейный", "Classic Юбилейный", "Classic Хардкор" },
    koKR = { "불타는 성전 기념 서버", "클래식 기념 서버", "클래식 하드코어" },
    zhCN = { "燃烧的远征周年服", "经典周年服", "经典硬核" },
    zhTW = { "燃燒的遠征週年伺服器", "經典週年伺服器", "經典專家模式" },
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
