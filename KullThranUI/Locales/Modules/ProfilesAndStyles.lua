-- Profiles page, profile icon picker, style pickers, chat message fade and the
-- newer Cooldown Manager glow styles, for every supported language.
-- Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Click a card to select it, double-click to load it.",
    "Assigned to %s",
    "Active profile",
    "Saved profile",
    "Active",
    "Click to select. Double-click to load.",
    "Selected: %s",
    "Delete profile %s?",
    "Click to choose this profile's icon.",
    "CURRENT PROFILE",
    "Choose an icon",
    "Default Icon",
    "Bags Style",
    "Message Visible Time",
    "Shape Glow",
    "Blackout",
}

local values = {
    esES = { "Haz clic en una tarjeta para seleccionarla y doble clic para cargarla.", "Asignado a %s", "Perfil activo", "Perfil guardado", "Activo", "Clic para seleccionar. Doble clic para cargar.", "Seleccionado: %s", "¿Borrar el perfil %s?", "Haz clic para elegir el icono de este perfil.", "PERFIL ACTUAL", "Elige un icono", "Icono por defecto", "Estilo de las bolsas", "Tiempo visible de los mensajes", "Resplandor de forma", "Relleno sólido" },
    deDE = { "Klicke auf eine Karte, um sie auszuwählen, Doppelklick lädt sie.", "Zugewiesen an %s", "Aktives Profil", "Gespeichertes Profil", "Aktiv", "Klicken zum Auswählen. Doppelklick zum Laden.", "Ausgewählt: %s", "Profil %s löschen?", "Klicken, um das Symbol dieses Profils zu wählen.", "AKTUELLES PROFIL", "Symbol wählen", "Standardsymbol", "Taschenstil", "Sichtbarkeitsdauer der Nachrichten", "Form-Leuchten", "Vollfüllung" },
    frFR = { "Cliquez sur une carte pour la sélectionner, double-cliquez pour la charger.", "Attribué à %s", "Profil actif", "Profil enregistré", "Actif", "Clic pour sélectionner. Double-clic pour charger.", "Sélectionné : %s", "Supprimer le profil %s ?", "Cliquez pour choisir l’icône de ce profil.", "PROFIL ACTUEL", "Choisir une icône", "Icône par défaut", "Style des sacs", "Durée d’affichage des messages", "Lueur de forme", "Remplissage plein" },
    itIT = { "Clicca su una scheda per selezionarla, doppio clic per caricarla.", "Assegnato a %s", "Profilo attivo", "Profilo salvato", "Attivo", "Clic per selezionare. Doppio clic per caricare.", "Selezionato: %s", "Eliminare il profilo %s?", "Clicca per scegliere l’icona di questo profilo.", "PROFILO ATTUALE", "Scegli un’icona", "Icona predefinita", "Stile delle borse", "Durata visibile dei messaggi", "Bagliore della forma", "Riempimento pieno" },
    ptBR = { "Clique em um cartão para selecioná-lo e clique duas vezes para carregá-lo.", "Atribuído a %s", "Perfil ativo", "Perfil salvo", "Ativo", "Clique para selecionar. Clique duas vezes para carregar.", "Selecionado: %s", "Excluir o perfil %s?", "Clique para escolher o ícone deste perfil.", "PERFIL ATUAL", "Escolha um ícone", "Ícone padrão", "Estilo das bolsas", "Tempo visível das mensagens", "Brilho da forma", "Preenchimento sólido" },
    ruRU = { "Нажмите на карточку, чтобы выбрать её, двойной щелчок загружает её.", "Назначен: %s", "Активный профиль", "Сохранённый профиль", "Активен", "Щелчок — выбрать. Двойной щелчок — загрузить.", "Выбран: %s", "Удалить профиль %s?", "Нажмите, чтобы выбрать значок этого профиля.", "ТЕКУЩИЙ ПРОФИЛЬ", "Выберите значок", "Значок по умолчанию", "Стиль сумок", "Время показа сообщений", "Свечение по форме", "Сплошная заливка" },
    koKR = { "카드를 클릭하면 선택하고, 두 번 클릭하면 불러옵니다.", "%s에 할당됨", "사용 중인 프로필", "저장된 프로필", "사용 중", "클릭하여 선택. 두 번 클릭하여 불러오기.", "선택됨: %s", "%s 프로필을 삭제하시겠습니까?", "클릭하여 이 프로필의 아이콘을 선택합니다.", "현재 프로필", "아이콘 선택", "기본 아이콘", "가방 스타일", "메시지 표시 시간", "모양 강조 효과", "단색 채우기" },
    zhCN = { "单击卡片以选择，双击以加载。", "已分配给 %s", "当前配置文件", "已保存的配置文件", "使用中", "单击选择，双击加载。", "已选择：%s", "删除配置文件 %s？", "点击以选择此配置文件的图标。", "当前配置文件", "选择图标", "默认图标", "背包样式", "消息显示时间", "形状发光", "纯色填充" },
    zhTW = { "點擊卡片以選取，雙擊以載入。", "已指派給 %s", "目前設定檔", "已儲存的設定檔", "使用中", "點擊選取，雙擊載入。", "已選取：%s", "刪除設定檔 %s？", "點擊以選擇此設定檔的圖示。", "目前設定檔", "選擇圖示", "預設圖示", "背包樣式", "訊息顯示時間", "形狀發光", "純色填滿" },
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
