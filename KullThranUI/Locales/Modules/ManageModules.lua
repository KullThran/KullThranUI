-- Manage Modules (General) and the module buttons in the minimap's drawer, for
-- every supported language. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Manage Modules",
    "Minimap Icon",
    "Turn each module on or off, and give it a button in the minimap's button drawer that opens its options. A reload is recommended after turning a module on or off.",
    "Click to open its options.",
    "ON",
    "OFF",
    "A button in the minimap's button drawer that opens this module's options.",
}

local values = {
    esES = { "Gestionar módulos", "Icono en el minimapa", "Activa o desactiva cada módulo y dale un botón en el desplegable de botones del minimapa que abre sus opciones. Se recomienda recargar tras activar o desactivar un módulo.", "Clic para abrir sus opciones.", "SÍ", "NO", "Un botón en el desplegable de botones del minimapa que abre las opciones de este módulo." },
    deDE = { "Module verwalten", "Minikartensymbol", "Schalte jedes Modul ein oder aus und gib ihm eine Schaltfläche in der Schaltflächenleiste der Minikarte, die seine Optionen öffnet. Nach dem Ein- oder Ausschalten eines Moduls wird ein Neuladen empfohlen.", "Klicken, um seine Optionen zu öffnen.", "AN", "AUS", "Eine Schaltfläche in der Schaltflächenleiste der Minikarte, die die Optionen dieses Moduls öffnet." },
    frFR = { "Gérer les modules", "Icône de la minicarte", "Activez ou désactivez chaque module et donnez-lui un bouton dans le tiroir de boutons de la minicarte qui ouvre ses options. Un rechargement est conseillé après avoir activé ou désactivé un module.", "Cliquez pour ouvrir ses options.", "OUI", "NON", "Un bouton dans le tiroir de boutons de la minicarte qui ouvre les options de ce module." },
    itIT = { "Gestisci moduli", "Icona della minimappa", "Attiva o disattiva ogni modulo e dagli un pulsante nel cassetto dei pulsanti della minimappa che apre le sue opzioni. Dopo aver attivato o disattivato un modulo è consigliato ricaricare.", "Clicca per aprire le sue opzioni.", "SÌ", "NO", "Un pulsante nel cassetto dei pulsanti della minimappa che apre le opzioni di questo modulo." },
    ptBR = { "Gerenciar módulos", "Ícone no minimapa", "Ative ou desative cada módulo e dê a ele um botão na gaveta de botões do minimapa que abre suas opções. Recomenda-se recarregar após ativar ou desativar um módulo.", "Clique para abrir suas opções.", "SIM", "NÃO", "Um botão na gaveta de botões do minimapa que abre as opções deste módulo." },
    ruRU = { "Управление модулями", "Значок у миникарты", "Включайте и выключайте модули и добавляйте им кнопку в выдвижную панель кнопок миникарты, открывающую их настройки. После включения или выключения модуля рекомендуется перезагрузка.", "Нажмите, чтобы открыть его настройки.", "ВКЛ", "ВЫКЛ", "Кнопка в выдвижной панели кнопок миникарты, открывающая настройки этого модуля." },
    koKR = { "모듈 관리", "미니맵 아이콘", "각 모듈을 켜거나 끄고, 미니맵 버튼 서랍에 해당 옵션을 여는 버튼을 추가합니다. 모듈을 켜거나 끈 후에는 UI 재시작을 권장합니다.", "클릭하여 옵션을 엽니다.", "켬", "끔", "미니맵 버튼 서랍에서 이 모듈의 옵션을 여는 버튼입니다." },
    zhCN = { "管理模块", "小地图图标", "开启或关闭各个模块，并在小地图按钮抽屉中为其添加一个打开其设置的按钮。开启或关闭模块后建议重载界面。", "点击打开其设置。", "开", "关", "小地图按钮抽屉中打开此模块设置的按钮。" },
    zhTW = { "管理模組", "小地圖圖示", "開啟或關閉各個模組，並在小地圖按鈕抽屜中為其加入一個開啟其設定的按鈕。開啟或關閉模組後建議重新載入介面。", "點擊開啟其設定。", "開", "關", "小地圖按鈕抽屜中開啟此模組設定的按鈕。" },
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
