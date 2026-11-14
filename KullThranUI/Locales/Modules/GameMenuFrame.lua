-- Game Menu frame (Enhancements > Interface) strings for every supported language. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Game Menu",
    "Crest Style",
    "Preview of the Escape menu with these settings. Hover the buttons to try them.",
    "Guardians",
    "Dragons",
    "Angels",
    "Reaper",
    "Show Frame Decoration",
    "KUI Buttons Position",
    "First KUI Button",
    "Show KullThranUI Button",
    "Show KUI Unlock Mode Button",
    "Top",
    "Bottom",
    "After Options",
    "Button Style",
    "Neutral",
    "Carved Stone",
    "Metal Plate",
    "Minimal",
    "Frame Style",
    "Classic",
    "Cathedral",
    "Ironbound",
    "Ossuary",
    "Choose how the Escape menu looks. The preview updates the real menu setting immediately.",
    "Plain",
}

local values = {
    esES = {
        "Menú de juego", "Estilo del emblema",
        "Vista previa del menú Esc con estos ajustes. Pasa el ratón por los botones para probarlos.",
        "Guardianes", "Dragones", "Ángeles", "Segador", "Mostrar decoración del marco",
        "Posición de los botones KUI", "Primer botón KUI", "Mostrar botón KullThranUI",
        "Mostrar botón Modo desbloqueo de KUI", "Arriba", "Abajo", "Tras opciones",
        "Estilo de los botones", "Neutro", "Piedra tallada", "Placa metálica", "Minimalista",
        "Estilo del marco", "Clásico", "Catedral", "Acorazado", "Osario",
        "Elige el aspecto del menú Esc. La vista previa cambia el ajuste real del menú al momento.",
        "Liso",
    },
    deDE = {
        "Spielmenü", "Wappenstil",
        "Vorschau des Esc-Menüs mit diesen Einstellungen. Fahre über die Schaltflächen, um sie zu testen.",
        "Wächter", "Drachen", "Engel", "Schnitter", "Rahmenverzierung anzeigen",
        "Position der KUI-Schaltflächen", "Erste KUI-Schaltfläche", "KullThranUI-Schaltfläche anzeigen",
        "KUI-Entsperrmodus-Schaltfläche anzeigen", "Oben", "Unten", "Nach Optionen",
        "Schaltflächenstil", "Neutral", "Gemeißelter Stein", "Metallplatte", "Minimal",
        "Rahmenstil", "Klassisch", "Kathedrale", "Eisenbeschlagen", "Beinhaus",
        "Wähle das Aussehen des Esc-Menüs. Die Vorschau ändert die echte Menüeinstellung sofort.",
        "Schlicht",
    },
    frFR = {
        "Menu de jeu", "Style du cimier",
        "Aperçu du menu Échap avec ces réglages. Survolez les boutons pour les essayer.",
        "Gardiens", "Dragons", "Anges", "Faucheuse", "Afficher la décoration du cadre",
        "Position des boutons KUI", "Premier bouton KUI", "Afficher le bouton KullThranUI",
        "Afficher le bouton de déverrouillage", "En haut", "En bas", "Après Options",
        "Style des boutons", "Neutre", "Pierre sculptée", "Plaque métallique", "Minimaliste",
        "Style du cadre", "Classique", "Cathédrale", "Bardé de fer", "Ossuaire",
        "Choisissez l'apparence du menu Échap. L'aperçu modifie aussitôt le vrai réglage du menu.",
        "Uni",
    },
    itIT = {
        "Menu di gioco", "Stile del fregio",
        "Anteprima del menu Esc con queste impostazioni. Passa sopra i pulsanti per provarli.",
        "Guardiani", "Draghi", "Angeli", "Mietitore", "Mostra la decorazione della cornice",
        "Posizione dei pulsanti KUI", "Primo pulsante KUI", "Mostra il pulsante KullThranUI",
        "Mostra il pulsante Modalità di sblocco KUI", "In alto", "In basso", "Dopo Opzioni",
        "Stile dei pulsanti", "Neutro", "Pietra scolpita", "Placca metallica", "Minimale",
        "Stile della cornice", "Classico", "Cattedrale", "Legato in ferro", "Ossario",
        "Scegli l'aspetto del menu Esc. L'anteprima cambia subito l'impostazione reale del menu.",
        "Semplice",
    },
    ptBR = {
        "Menu do jogo", "Estilo do brasão",
        "Prévia do menu Esc com estas configurações. Passe o mouse nos botões para testá-los.",
        "Guardiões", "Dragões", "Anjos", "Ceifador", "Mostrar decoração da moldura",
        "Posição dos botões KUI", "Primeiro botão KUI", "Mostrar botão KullThranUI",
        "Mostrar botão de desbloqueio", "Em cima", "Embaixo", "Após opções",
        "Estilo dos botões", "Neutro", "Pedra esculpida", "Placa de metal", "Minimalista",
        "Estilo da moldura", "Clássico", "Catedral", "Couraçado", "Ossuário",
        "Escolha a aparência do menu Esc. A prévia altera na hora a configuração real do menu.",
        "Liso",
    },
    ruRU = {
        "Игровое меню", "Стиль герба",
        "Предпросмотр меню Esc с этими настройками. Наведите курсор на кнопки, чтобы проверить их.",
        "Стражи", "Драконы", "Ангелы", "Жнец", "Показывать украшение рамки",
        "Положение кнопок KUI", "Первая кнопка KUI", "Показывать кнопку KullThranUI",
        "Кнопка режима разблокировки", "Сверху", "Снизу", "После «Настроек»",
        "Стиль кнопок", "Нейтральный", "Резной камень", "Металлическая пластина", "Минимализм",
        "Стиль рамки", "Классика", "Собор", "Окованный", "Оссуарий",
        "Выберите вид меню Esc. Предпросмотр сразу меняет настоящую настройку меню.",
        "Простая",
    },
    koKR = {
        "게임 메뉴", "문장 스타일",
        "이 설정을 적용한 Esc 메뉴 미리보기입니다. 버튼 위에 마우스를 올려 확인하세요.",
        "수호자", "용", "천사", "사신", "테두리 장식 표시",
        "KUI 버튼 위치", "첫 번째 KUI 버튼", "KullThranUI 버튼 표시",
        "KUI 잠금 해제 모드 버튼 표시", "위", "아래", "설정 다음",
        "버튼 스타일", "기본", "조각된 돌", "금속판", "미니멀",
        "테두리 스타일", "클래식", "대성당", "철갑", "납골당",
        "Esc 메뉴의 모양을 선택하세요. 미리보기는 실제 메뉴 설정을 즉시 바꿉니다.",
        "단순",
    },
    zhCN = {
        "主菜单", "顶饰样式",
        "按这些设置预览 Esc 菜单。将鼠标悬停在按钮上即可试用。",
        "守护者", "巨龙", "天使", "死神", "显示边框装饰",
        "KUI 按钮位置", "第一个 KUI 按钮", "显示 KullThranUI 按钮",
        "显示 KUI 解锁模式按钮", "顶部", "底部", "在“选项”之后",
        "按钮样式", "中性", "雕刻石材", "金属板", "极简",
        "边框样式", "经典", "大教堂", "铁甲", "藏骨堂",
        "选择 Esc 菜单的外观。预览会立即修改菜单的实际设置。",
        "纯线条",
    },
    zhTW = {
        "遊戲選單", "頂飾樣式",
        "依這些設定預覽 Esc 選單。將滑鼠移到按鈕上即可試用。",
        "守護者", "巨龍", "天使", "死神", "顯示邊框裝飾",
        "KUI 按鈕位置", "第一個 KUI 按鈕", "顯示 KullThranUI 按鈕",
        "顯示 KUI 解鎖模式按鈕", "頂部", "底部", "在「選項」之後",
        "按鈕樣式", "中性", "雕刻石材", "金屬板", "極簡",
        "邊框樣式", "經典", "大教堂", "鐵甲", "藏骨堂",
        "選擇 Esc 選單的外觀。預覽會立即修改選單的實際設定。",
        "純線條",
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
