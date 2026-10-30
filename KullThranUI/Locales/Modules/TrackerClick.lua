-- KUI Tracker (Cooldown Manager): clickable icons option, for every supported
-- language. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Click to Cast or Use",
    "Click a tracker icon to cast the spell or use the trinket, potion or item. A reload applies the change.",
}

local values = {
    esES = { "Clic para lanzar o usar", "Haz clic en un icono del tracker para lanzar el hechizo o usar el abalorio, la poción o el objeto. El cambio se aplica al recargar." },
    deDE = { "Klicken zum Wirken oder Benutzen", "Klicke auf ein Tracker-Symbol, um den Zauber zu wirken oder das Schmuckstück, den Trank oder den Gegenstand zu benutzen. Die Änderung gilt nach einem Neuladen." },
    frFR = { "Cliquer pour lancer ou utiliser", "Cliquez sur une icône du suivi pour lancer le sort ou utiliser le bijou, la potion ou l’objet. Le changement s’applique après un rechargement." },
    itIT = { "Clic per lanciare o usare", "Fai clic su un’icona del tracker per lanciare l’incantesimo o usare il monile, la pozione o l’oggetto. La modifica si applica dopo il ricaricamento." },
    ptBR = { "Clique para lançar ou usar", "Clique num ícone do rastreador para lançar o feitiço ou usar o berloque, a poção ou o item. A mudança vale após recarregar." },
    ruRU = { "Щелчок — применить", "Щелкните по значку трекера, чтобы применить заклинание или использовать аксессуар, зелье или предмет. Изменение вступит в силу после перезагрузки." },
    koKR = { "클릭하여 시전 또는 사용", "추적기 아이콘을 클릭하면 주문을 시전하거나 장신구, 물약, 아이템을 사용합니다. 변경 사항은 UI 재시작 후 적용됩니다." },
    zhCN = { "点击施放或使用", "点击追踪图标即可施放法术或使用饰品、药水或物品。重载后生效。" },
    zhTW = { "點擊施放或使用", "點擊追蹤圖示即可施放法術或使用飾品、藥水或物品。重新載入後生效。" },
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
