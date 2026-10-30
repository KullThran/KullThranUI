-- Party Frames portrait auras: strings that only the Party Frames page uses. The rest of the page
-- reuses the Unit Frames strings (Locales/Modules/PortraitAuras.lua). Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Shown over the portrait of each frame. Test frames show a sample icon.",
    "Needs Show Portrait to be turned on.",
}

local values = {
    esES = { "Se muestra sobre el retrato de cada marco. Los marcos de prueba muestran un icono de ejemplo.", "Requiere tener activado Mostrar retrato." },
    deDE = { "Wird über dem Porträt jedes Rahmens angezeigt. Testrahmen zeigen ein Beispielsymbol.", "Erfordert, dass „Porträt anzeigen“ aktiviert ist." },
    frFR = { "S'affiche sur le portrait de chaque cadre. Les cadres de test affichent une icône d'exemple.", "Nécessite que « Afficher le portrait » soit activé." },
    itIT = { "Mostrato sul ritratto di ogni riquadro. I riquadri di prova mostrano un'icona di esempio.", "Richiede che «Mostra ritratto» sia attivo." },
    ptBR = { "Mostrado sobre o retrato de cada quadro. Os quadros de teste mostram um ícone de exemplo.", "Requer que «Mostrar retrato» esteja ativado." },
    ruRU = { "Отображается поверх портрета каждой рамки. Тестовые рамки показывают пример значка.", "Требуется включить «Показывать портрет»." },
    koKR = { "각 프레임의 초상화 위에 표시됩니다. 테스트 프레임에는 예시 아이콘이 표시됩니다.", "'초상화 표시'가 켜져 있어야 합니다." },
    zhCN = { "显示在每个框体的头像上。测试框体会显示一个示例图标。", "需要开启“显示头像”。" },
    zhTW = { "顯示在每個框架的頭像上。測試框架會顯示一個範例圖示。", "需要開啟「顯示頭像」。" },
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
