-- Nameplates: execute range (health bar painted under a health percent, mark and skull).
-- Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "EXECUTE RANGE",
    "Show Execute Range",
    "Paints the health bar of enemies in the execute color when their health drops under the chosen percent.",
    "Execute Threshold",
    "Execute Color",
    "Execute Mark",
    "Draws a mark on the health bar at the execute percent.",
    "Execute Skull",
    "Shows a skull next to the nameplate while the enemy is in execute range.",
}

local values = {
    esES = { "RANGO DE EJECUCIÓN", "Mostrar rango de ejecución", "Pinta la barra de vida de los enemigos con el color de ejecución cuando su vida baja del porcentaje elegido.", "Umbral de ejecución", "Color de ejecución", "Marca de ejecución", "Dibuja una marca en la barra de vida en el porcentaje de ejecución.", "Calavera de ejecución", "Muestra una calavera junto a la placa mientras el enemigo está en rango de ejecución." },
    deDE = { "HINRICHTUNGSBEREICH", "Hinrichtungsbereich anzeigen", "Färbt die Gesundheitsleiste von Gegnern in der Hinrichtungsfarbe, wenn ihre Gesundheit unter den gewählten Prozentwert fällt.", "Hinrichtungsschwelle", "Hinrichtungsfarbe", "Hinrichtungsmarkierung", "Zeichnet beim Hinrichtungsprozentwert eine Markierung auf die Gesundheitsleiste.", "Hinrichtungs-Totenkopf", "Zeigt einen Totenkopf neben der Namensplakette, solange der Gegner im Hinrichtungsbereich ist." },
    frFR = { "ZONE D'EXÉCUTION", "Afficher la zone d'exécution", "Colore la barre de vie des ennemis avec la couleur d'exécution quand leur vie passe sous le pourcentage choisi.", "Seuil d'exécution", "Couleur d'exécution", "Repère d'exécution", "Dessine un repère sur la barre de vie au pourcentage d'exécution.", "Crâne d'exécution", "Affiche un crâne à côté de la barre de nom tant que l'ennemi est en zone d'exécution." },
    itIT = { "SOGLIA DI ESECUZIONE", "Mostra soglia di esecuzione", "Colora la barra della salute dei nemici con il colore di esecuzione quando la loro salute scende sotto la percentuale scelta.", "Soglia di esecuzione", "Colore di esecuzione", "Segno di esecuzione", "Disegna un segno sulla barra della salute alla percentuale di esecuzione.", "Teschio di esecuzione", "Mostra un teschio accanto alla targhetta mentre il nemico è nella soglia di esecuzione." },
    ptBR = { "FAIXA DE EXECUÇÃO", "Mostrar faixa de execução", "Pinta a barra de vida dos inimigos com a cor de execução quando a vida deles fica abaixo da porcentagem escolhida.", "Limite de execução", "Cor de execução", "Marca de execução", "Desenha uma marca na barra de vida na porcentagem de execução.", "Caveira de execução", "Mostra uma caveira ao lado da placa enquanto o inimigo está na faixa de execução." },
    ruRU = { "ЗОНА ДОБИВАНИЯ", "Показывать зону добивания", "Окрашивает полосу здоровья врагов в цвет добивания, когда их здоровье опускается ниже выбранного процента.", "Порог добивания", "Цвет добивания", "Метка добивания", "Рисует метку на полосе здоровья в точке процента добивания.", "Череп добивания", "Показывает череп рядом с индикатором, пока враг в зоне добивания." },
    koKR = { "처형 구간", "처형 구간 표시", "적의 생명력이 선택한 비율 아래로 떨어지면 생명력 바를 처형 색상으로 칠합니다.", "처형 기준", "처형 색상", "처형 표시선", "생명력 바의 처형 비율 위치에 표시선을 그립니다.", "처형 해골", "적이 처형 구간에 있는 동안 이름표 옆에 해골을 표시합니다." },
    zhCN = { "斩杀范围", "显示斩杀范围", "当敌人的生命值低于所选百分比时，用斩杀颜色绘制其生命条。", "斩杀阈值", "斩杀颜色", "斩杀标记", "在生命条的斩杀百分比处绘制一条标记。", "斩杀骷髅", "敌人处于斩杀范围时，在姓名板旁显示骷髅。" },
    zhTW = { "斬殺範圍", "顯示斬殺範圍", "當敵人的生命值低於所選百分比時，以斬殺顏色繪製其生命條。", "斬殺閾值", "斬殺顏色", "斬殺標記", "在生命條的斬殺百分比處繪製一條標記。", "斬殺骷髏", "敵人處於斬殺範圍時，在名條旁顯示骷髏。" },
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
