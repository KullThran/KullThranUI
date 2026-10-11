-- Minimap side icon strings for every supported language. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Side Icons",
    "Show Teleport Menu Icon",
    "Show Friends Icon",
    "Show Guild Icon",
    "Show KUI Options Icon",
}

local values = {
    esES = { "Iconos laterales", "Mostrar icono del menú de teletransporte", "Mostrar icono de amigos", "Mostrar icono de hermandad", "Mostrar icono de opciones de KUI" },
    deDE = { "Seitensymbole", "Teleportmenü-Symbol anzeigen", "Freunde-Symbol anzeigen", "Gilden-Symbol anzeigen", "KUI-Optionen-Symbol anzeigen" },
    frFR = { "Icônes latérales", "Afficher l'icône du menu de téléportation", "Afficher l'icône des amis", "Afficher l'icône de guilde", "Afficher l'icône des options KUI" },
    itIT = { "Icone laterali", "Mostra l'icona del menu di teletrasporto", "Mostra l'icona degli amici", "Mostra l'icona della gilda", "Mostra l'icona delle opzioni KUI" },
    ptBR = { "Ícones laterais", "Mostrar ícone do menu de teletransporte", "Mostrar ícone de amigos", "Mostrar ícone da guilda", "Mostrar ícone de opções do KUI" },
    ruRU = { "Боковые значки", "Показывать значок меню телепортации", "Показывать значок друзей", "Показывать значок гильдии", "Показывать значок настроек KUI" },
    koKR = { "측면 아이콘", "순간이동 메뉴 아이콘 표시", "친구 아이콘 표시", "길드 아이콘 표시", "KUI 옵션 아이콘 표시" },
    zhCN = { "侧边图标", "显示传送菜单图标", "显示好友图标", "显示公会图标", "显示 KUI 选项图标" },
    zhTW = { "側邊圖示", "顯示傳送選單圖示", "顯示好友圖示", "顯示公會圖示", "顯示 KUI 選項圖示" },
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
