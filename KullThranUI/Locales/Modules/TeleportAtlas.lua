-- Teleport Menu, Atlas look (waypoint status, header and footer), for every
-- supported language. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Ready",
    "Cooldown",
    "Spell",
    "Item",
    "Toy",
    "House",
    "%d destinations",
    "Click a waypoint to travel",
    "Not learned yet",
    "Not in your bags",
}

local values = {
    esES = {
        "Listo", "En reutilización", "Hechizo", "Objeto", "Juguete", "Casa", "%d destinos",
        "Haz clic en un destino para viajar", "Aún no aprendido", "No está en tus bolsas",
    },
    deDE = {
        "Bereit", "Abklingzeit", "Zauber", "Gegenstand", "Spielzeug", "Haus", "%d Ziele",
        "Klicke auf einen Wegpunkt, um zu reisen", "Noch nicht erlernt", "Nicht in deinen Taschen",
    },
    frFR = {
        "Prêt", "Recharge", "Sort", "Objet", "Jouet", "Maison", "%d destinations",
        "Cliquez sur un point de passage pour voyager", "Pas encore appris", "Pas dans vos sacs",
    },
    itIT = {
        "Pronto", "In ricarica", "Incantesimo", "Oggetto", "Giocattolo", "Casa", "%d destinazioni",
        "Fai clic su una tappa per viaggiare", "Non ancora appreso", "Non nelle tue borse",
    },
    ptBR = {
        "Pronto", "Em recarga", "Feitiço", "Item", "Brinquedo", "Casa", "%d destinos",
        "Clique em um destino para viajar", "Ainda não aprendido", "Não está nas suas bolsas",
    },
    ruRU = {
        "Готово", "Восстановление", "Заклинание", "Предмет", "Игрушка", "Дом", "Пунктов: %d",
        "Нажмите на точку, чтобы отправиться", "Ещё не изучено", "Нет в сумках",
    },
    koKR = {
        "준비됨", "재사용 대기 중", "주문", "아이템", "장난감", "집", "목적지 %d곳",
        "경유지를 클릭하여 이동", "아직 배우지 않음", "가방에 없음",
    },
    zhCN = {
        "就绪", "冷却中", "法术", "物品", "玩具", "住宅", "%d 个目的地",
        "点击路点进行传送", "尚未学会", "背包中没有",
    },
    zhTW = {
        "就緒", "冷卻中", "法術", "物品", "玩具", "住宅", "%d 個目的地",
        "點擊路點進行傳送", "尚未學會", "背包中沒有",
    },
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
