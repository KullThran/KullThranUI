-- Nameplates: big round class / spec / healer icons over friendly players.
-- Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "FRIENDLY CLASS ICONS",
    "Show Class Icons on Friendly Players",
    "Shows a big round icon over friendly players: the healer cross for healers, otherwise their spec or class icon.",
    "Class Icon Size",
    "Class Icon Height",
}

local values = {
    esES = { "ICONOS DE CLASE ALIADOS", "Mostrar iconos de clase en jugadores aliados", "Muestra un icono redondo grande sobre los jugadores aliados: la cruz de sanador para los sanadores y, si no, el icono de su especialización o clase.", "Tamaño del icono de clase", "Altura del icono de clase" },
    deDE = { "KLASSENSYMBOLE VERBÜNDETER", "Klassensymbole bei verbündeten Spielern anzeigen", "Zeigt ein großes rundes Symbol über verbündeten Spielern: das Heilerkreuz für Heiler, sonst das Symbol ihrer Spezialisierung oder Klasse.", "Größe des Klassensymbols", "Höhe des Klassensymbols" },
    frFR = { "ICÔNES DE CLASSE ALLIÉES", "Afficher les icônes de classe sur les joueurs alliés", "Affiche une grande icône ronde au-dessus des joueurs alliés : la croix de soigneur pour les soigneurs, sinon l'icône de leur spécialisation ou de leur classe.", "Taille de l'icône de classe", "Hauteur de l'icône de classe" },
    itIT = { "ICONE DI CLASSE ALLEATE", "Mostra icone di classe sui giocatori alleati", "Mostra una grande icona rotonda sopra i giocatori alleati: la croce del guaritore per i guaritori, altrimenti l'icona della loro specializzazione o classe.", "Dimensione icona di classe", "Altezza icona di classe" },
    ptBR = { "ÍCONES DE CLASSE ALIADOS", "Mostrar ícones de classe em jogadores aliados", "Mostra um ícone redondo grande sobre os jogadores aliados: a cruz de curador para curadores, senão o ícone da especialização ou da classe.", "Tamanho do ícone de classe", "Altura do ícone de classe" },
    ruRU = { "ЗНАЧКИ КЛАССОВ СОЮЗНИКОВ", "Показывать значки классов над союзными игроками", "Показывает большой круглый значок над союзными игроками: крест лекаря для лекарей, иначе значок их специализации или класса.", "Размер значка класса", "Высота значка класса" },
    koKR = { "아군 직업 아이콘", "아군 플레이어에 직업 아이콘 표시", "아군 플레이어 위에 큰 원형 아이콘을 표시합니다: 치유 담당은 치유 십자가, 그 외에는 전문화 또는 직업 아이콘입니다.", "직업 아이콘 크기", "직업 아이콘 높이" },
    zhCN = { "友方职业图标", "在友方玩家上显示职业图标", "在友方玩家上方显示一个大的圆形图标：治疗者显示治疗十字，否则显示其专精或职业图标。", "职业图标大小", "职业图标高度" },
    zhTW = { "友方職業圖示", "在友方玩家上顯示職業圖示", "在友方玩家上方顯示一個大的圓形圖示：治療者顯示治療十字，否則顯示其專精或職業圖示。", "職業圖示大小", "職業圖示高度" },
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
