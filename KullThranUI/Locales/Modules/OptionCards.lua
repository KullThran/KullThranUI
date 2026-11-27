-- Options pages with cards (KullThranUI/OptionCards.lua): card and block titles of
-- the Unit Frames and Party Frames pages. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Name & Level",
    "Player Frame Extras",
    "Castbar",
    "Names",
    "Level",
    "Rare / Elite",
    "Castbar & Auras",
    "Dispel & Missing Buffs",
    "Level & PvP Icon",
    "Allied Arena Layout",
    "Enemy Arena Layout",
}

local values = {
    esES = { "Nombre y nivel", "Extras del marco del jugador", "Barra de lanzamiento", "Nombres", "Nivel", "Raro / Élite", "Barra de lanzamiento y auras", "Disipación y beneficios ausentes", "Nivel e icono JcJ", "Disposición de arena aliada", "Disposición de arena enemiga" },
    deDE = { "Name & Stufe", "Spielerrahmen-Extras", "Zauberleiste", "Namen", "Stufe", "Selten / Elite", "Zauberleiste & Auren", "Bannen & fehlende Buffs", "Stufe & PvP-Symbol", "Arena-Layout (Verbündete)", "Arena-Layout (Gegner)" },
    frFR = { "Nom et niveau", "Extras du cadre du joueur", "Barre d'incantation", "Noms", "Niveau", "Rare / Élite", "Barre d'incantation et auras", "Dissipation et améliorations manquantes", "Niveau et icône JcJ", "Disposition d'arène alliée", "Disposition d'arène ennemie" },
    itIT = { "Nome e livello", "Extra della cornice del giocatore", "Barra incantesimi", "Nomi", "Livello", "Raro / Elite", "Barra incantesimi e aure", "Dissoluzione e buff mancanti", "Livello e icona PvP", "Layout arena alleata", "Layout arena nemica" },
    ptBR = { "Nome e nível", "Extras do quadro do jogador", "Barra de lançamento", "Nomes", "Nível", "Raro / Elite", "Barra de lançamento e auras", "Dissipar e bônus ausentes", "Nível e ícone JxJ", "Layout de arena aliada", "Layout de arena inimiga" },
    ruRU = { "Имя и уровень", "Дополнения рамки игрока", "Полоса заклинаний", "Имена", "Уровень", "Редкий / Элитный", "Полоса заклинаний и ауры", "Рассеивание и отсутствующие баффы", "Уровень и значок PvP", "Раскладка арены (союзники)", "Раскладка арены (противники)" },
    koKR = { "이름 및 레벨", "플레이어 프레임 추가 요소", "시전 바", "이름", "레벨", "희귀 / 정예", "시전 바 및 오라", "해제 및 누락 버프", "레벨 및 PvP 아이콘", "아군 투기장 배치", "적 투기장 배치" },
    zhCN = { "名称与等级", "玩家框体附加项", "施法条", "名称", "等级", "稀有 / 精英", "施法条与光环", "驱散与缺失的增益效果", "等级与 PvP 图标", "友方竞技场布局", "敌方竞技场布局" },
    zhTW = { "名稱與等級", "玩家框架附加項目", "施法條", "名稱", "等級", "稀有 / 精英", "施法條與光環", "驅散與缺少的增益效果", "等級與 PvP 圖示", "友方競技場版面配置", "敵方競技場版面配置" },
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
