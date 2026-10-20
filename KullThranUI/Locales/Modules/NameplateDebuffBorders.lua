-- Nameplates: debuff type borders (your bleeds, DoTs... framed by type). The per-type color
-- labels reuse the Party Frames strings. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "DEBUFF TYPE BORDERS",
    "Color Debuff Borders by Type",
    "Frames your debuffs on enemy nameplates with the color of their type: bleed, magic, poison, curse or disease.",
    "Debuff Border Thickness",
    "Other Debuffs Color",
}

local values = {
    esES = { "BORDES POR TIPO DE PERJUICIO", "Colorear bordes de perjuicios por tipo", "Enmarca tus perjuicios en las placas de enemigos con el color de su tipo: sangrado, magia, veneno, maldición o enfermedad.", "Grosor del borde de perjuicios", "Color de otros perjuicios" },
    deDE = { "SCHWÄCHUNGSRAHMEN NACH TYP", "Schwächungsrahmen nach Typ färben", "Rahmt deine Schwächungen auf gegnerischen Namensplaketten in der Farbe ihres Typs ein: Blutung, Magie, Gift, Fluch oder Krankheit.", "Dicke des Schwächungsrahmens", "Farbe anderer Schwächungen" },
    frFR = { "BORDURES PAR TYPE D'AFFAIBLISSEMENT", "Colorer les bordures des affaiblissements par type", "Encadre vos affaiblissements sur les barres de nom ennemies avec la couleur de leur type : saignement, magie, poison, malédiction ou maladie.", "Épaisseur de la bordure des affaiblissements", "Couleur des autres affaiblissements" },
    itIT = { "BORDI PER TIPO DI PENALITÀ", "Colora i bordi delle penalità per tipo", "Incornicia le tue penalità sulle targhette nemiche con il colore del loro tipo: sanguinamento, magia, veleno, maledizione o malattia.", "Spessore del bordo delle penalità", "Colore delle altre penalità" },
    ptBR = { "BORDAS POR TIPO DE PENALIDADE", "Colorir bordas das penalidades por tipo", "Emoldura suas penalidades nas placas de inimigos com a cor do tipo: sangramento, magia, veneno, maldição ou doença.", "Espessura da borda das penalidades", "Cor das outras penalidades" },
    ruRU = { "РАМКИ ПО ТИПУ ОТРИЦАТЕЛЬНЫХ ЭФФЕКТОВ", "Окрашивать рамки эффектов по типу", "Обводит ваши отрицательные эффекты на индикаторах врагов цветом их типа: кровотечение, магия, яд, проклятие или болезнь.", "Толщина рамки эффектов", "Цвет прочих эффектов" },
    koKR = { "약화 효과 유형별 테두리", "약화 효과 테두리를 유형별로 색칠", "적 이름표에 있는 내 약화 효과를 유형 색상으로 테두리 표시합니다: 출혈, 마법, 독, 저주, 질병.", "약화 효과 테두리 두께", "기타 약화 효과 색상" },
    zhCN = { "按类型的减益边框", "按类型为减益边框着色", "用类型颜色为敌方姓名板上你的减益效果加框：流血、魔法、中毒、诅咒或疾病。", "减益边框粗细", "其他减益颜色" },
    zhTW = { "依類型的減益邊框", "依類型為減益邊框著色", "以類型顏色為敵方名條上你的減益效果加框：流血、魔法、中毒、詛咒或疾病。", "減益邊框粗細", "其他減益顏色" },
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
