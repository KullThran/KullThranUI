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
    "Skull When DoTs Will Kill",
    "Shows a skull next to the nameplate when your bleeds and DoTs will deal more damage than the health it has left.",
}

local values = {
    esES = { "DAÑO DE DOTS", "Mostrar daño pendiente de DoTs", "Pinta sobre la barra de vida de los enemigos la vida que tus sangrados y DoTs todavía van a quitar antes de expirar.", "Color del daño de DoTs", "Calavera si los DoTs lo van a matar", "Muestra una calavera junto a la placa cuando tus sangrados y DoTs van a hacer más daño que la vida que le queda." },
    deDE = { "DOT-SCHADEN", "Ausstehenden DoT-Schaden anzeigen", "Zeigt auf der Gesundheitsleiste von Gegnern die Gesundheit, die deine Blutungen und DoTs bis zu ihrem Ablauf noch abziehen.", "Farbe des DoT-Schadens", "Totenkopf, wenn DoTs töten", "Zeigt einen Totenkopf neben der Namensplakette, wenn deine Blutungen und DoTs mehr Schaden verursachen, als Gesundheit übrig ist." },
    frFR = { "DÉGÂTS DES DOTS", "Afficher les dégâts en attente des DoTs", "Peint sur la barre de vie des ennemis la vie que vos saignements et DoTs vont encore retirer avant d'expirer.", "Couleur des dégâts des DoTs", "Crâne si les DoTs vont tuer", "Affiche un crâne à côté de la barre de nom quand vos saignements et DoTs vont infliger plus de dégâts que la vie restante." },
    itIT = { "DANNI DEI DOT", "Mostra i danni in sospeso dei DoT", "Dipinge sulla barra della salute dei nemici la salute che i tuoi sanguinamenti e DoT toglieranno ancora prima di scadere.", "Colore dei danni dei DoT", "Teschio se i DoT uccideranno", "Mostra un teschio accanto alla targhetta quando i tuoi sanguinamenti e DoT infliggeranno più danni della salute rimasta." },
    ptBR = { "DANO DE DOTS", "Mostrar dano pendente de DoTs", "Pinta sobre a barra de vida dos inimigos a vida que seus sangramentos e DoTs ainda vão tirar antes de expirar.", "Cor do dano de DoTs", "Caveira se os DoTs vão matar", "Mostra uma caveira ao lado da placa quando seus sangramentos e DoTs vão causar mais dano do que a vida restante." },
    ruRU = { "УРОН DOT", "Показывать ожидаемый урон DoT", "Закрашивает на полосе здоровья врагов здоровье, которое ваши кровотечения и DoT ещё отнимут до окончания.", "Цвет урона DoT", "Череп, если DoT убьют", "Показывает череп рядом с индикатором, когда ваши кровотечения и DoT нанесут больше урона, чем осталось здоровья." },
    koKR = { "지속 피해", "남은 지속 피해 표시", "적 생명력 바 위에 내 출혈과 지속 피해가 끝나기 전까지 깎을 생명력을 표시합니다.", "지속 피해 색상", "지속 피해로 죽으면 해골 표시", "내 출혈과 지속 피해가 남은 생명력보다 많은 피해를 줄 때 이름표 옆에 해골을 표시합니다." },
    zhCN = { "持续伤害", "显示待生效的持续伤害", "在敌人的生命条上标出你的流血和持续伤害在结束前还会造成的生命值。", "持续伤害颜色", "持续伤害致命时显示骷髅", "当你的流血和持续伤害将造成的伤害超过剩余生命值时，在姓名板旁显示骷髅。" },
    zhTW = { "持續傷害", "顯示待生效的持續傷害", "在敵人的生命條上標出你的流血和持續傷害在結束前還會造成的生命值。", "持續傷害顏色", "持續傷害致命時顯示骷髏", "當你的流血和持續傷害將造成的傷害超過剩餘生命值時，在名條旁顯示骷髏。" },
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
