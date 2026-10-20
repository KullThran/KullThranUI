-- Nameplates: pending DoT damage (health your bleeds and DoTs will still take).
-- Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "DOT DAMAGE",
    "Show Pending DoT Damage",
    "Paints over the health bar of enemies the health your bleeds and DoTs will still take before they expire.",
    "DoT Damage Color",
}

local values = {
    esES = { "DAÑO DE DOTS", "Mostrar daño pendiente de DoTs", "Pinta sobre la barra de vida de los enemigos la vida que tus sangrados y DoTs todavía van a quitar antes de expirar.", "Color del daño de DoTs" },
    deDE = { "DOT-SCHADEN", "Ausstehenden DoT-Schaden anzeigen", "Zeigt auf der Gesundheitsleiste von Gegnern die Gesundheit, die deine Blutungen und DoTs bis zu ihrem Ablauf noch abziehen.", "Farbe des DoT-Schadens" },
    frFR = { "DÉGÂTS DES DOTS", "Afficher les dégâts en attente des DoTs", "Peint sur la barre de vie des ennemis la vie que vos saignements et DoTs vont encore retirer avant d'expirer.", "Couleur des dégâts des DoTs" },
    itIT = { "DANNI DEI DOT", "Mostra i danni in sospeso dei DoT", "Dipinge sulla barra della salute dei nemici la salute che i tuoi sanguinamenti e DoT toglieranno ancora prima di scadere.", "Colore dei danni dei DoT" },
    ptBR = { "DANO DE DOTS", "Mostrar dano pendente de DoTs", "Pinta sobre a barra de vida dos inimigos a vida que seus sangramentos e DoTs ainda vão tirar antes de expirar.", "Cor do dano de DoTs" },
    ruRU = { "УРОН DOT", "Показывать ожидаемый урон DoT", "Закрашивает на полосе здоровья врагов здоровье, которое ваши кровотечения и DoT ещё отнимут до окончания.", "Цвет урона DoT" },
    koKR = { "지속 피해", "남은 지속 피해 표시", "적 생명력 바 위에 내 출혈과 지속 피해가 끝나기 전까지 깎을 생명력을 표시합니다.", "지속 피해 색상" },
    zhCN = { "持续伤害", "显示待生效的持续伤害", "在敌人的生命条上标出你的流血和持续伤害在结束前还会造成的生命值。", "持续伤害颜色" },
    zhTW = { "持續傷害", "顯示待生效的持續傷害", "在敵人的生命條上標出你的流血和持續傷害在結束前還會造成的生命值。", "持續傷害顏色" },
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
