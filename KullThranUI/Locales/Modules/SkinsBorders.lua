-- Skins: gradient window borders option, for every supported language.
-- Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = { "Gradient window borders" }

local values = {
    esES = { "Bordes de ventana degradados" },
    deDE = { "Fensterrahmen mit Verlauf" },
    frFR = { "Bordures de fenêtre en dégradé" },
    itIT = { "Bordi delle finestre sfumati" },
    ptBR = { "Bordas de janela em degradê" },
    ruRU = { "Градиентные рамки окон" },
    koKR = { "그라데이션 창 테두리" },
    zhCN = { "渐变窗口边框" },
    zhTW = { "漸層視窗邊框" },
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
