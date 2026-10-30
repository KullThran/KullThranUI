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
    "Armory Style",
    "Tint Border by Quality",
    "Tint Strength",
    "World",
    "Best +%d",
    "%d/%d timed",
    "This week: %d runs",
    "Resets in %s",
    "No Mythic+ runs this season",
    "No raid lockouts this week",
    "Mythic+ Rating",
    "Minimap Style",
    "Cast Bar Style",
    "Click a profile to load it. It stays selected for the buttons below.",
    "Click to load this profile.",
    "Load profile %s?",
    "New Profile",
    "KUI defaults",
    "Name of the new profile (KUI defaults):",
    "A profile named '%s' already exists.",
    "Created profile '%s' with the KUI defaults.",
    "Right-click to delete.",
    "You cannot delete the active profile.",
}

local values = {
    esES = { "Haz clic en una tarjeta para seleccionarla y doble clic para cargarla.", "Asignado a %s", "Perfil activo", "Perfil guardado", "Activo", "Clic para seleccionar. Doble clic para cargar.", "Seleccionado: %s", "¿Borrar el perfil %s?", "Haz clic para elegir el icono de este perfil.", "PERFIL ACTUAL", "Elige un icono", "Icono por defecto", "Estilo de las bolsas", "Tiempo visible de los mensajes", "Resplandor de forma", "Relleno sólido", "Estilo del Armory", "Recolorear borde por rareza", "Intensidad del tinte", "Mundo", "Mejor +%d", "%d/%d a tiempo", "Esta semana: %d partidas", "Se reinicia en %s", "Sin partidas de Míticas+ esta temporada", "Sin bandas guardadas esta semana", "Puntuación de Míticas+", "Estilo del minimapa", "Estilo de la barra de lanzamiento", "Haz clic en un perfil para cargarlo. Queda seleccionado para los botones de abajo.", "Clic para cargar este perfil.", "¿Cargar el perfil %s?", "Nuevo perfil", "Valores de KUI", "Nombre del nuevo perfil (valores de KUI):", "Ya existe un perfil llamado '%s'.", "Perfil '%s' creado con los valores de KUI.", "Clic derecho para borrarlo.", "No puedes borrar el perfil activo." },
    deDE = { "Klicke auf eine Karte, um sie auszuwählen, Doppelklick lädt sie.", "Zugewiesen an %s", "Aktives Profil", "Gespeichertes Profil", "Aktiv", "Klicken zum Auswählen. Doppelklick zum Laden.", "Ausgewählt: %s", "Profil %s löschen?", "Klicken, um das Symbol dieses Profils zu wählen.", "AKTUELLES PROFIL", "Symbol wählen", "Standardsymbol", "Taschenstil", "Sichtbarkeitsdauer der Nachrichten", "Form-Leuchten", "Vollfüllung", "Arsenal-Stil", "Rahmen nach Qualität einfärben", "Färbungsstärke", "Welt", "Beste +%d", "%d/%d in der Zeit", "Diese Woche: %d Läufe", "Zurücksetzung in %s", "Keine Mythisch+-Läufe in dieser Saison", "Keine Schlachtzugssperren diese Woche", "Mythisch+-Wertung", "Minikartenstil", "Zauberleistenstil", "Klicke auf ein Profil, um es zu laden. Es bleibt für die Schaltflächen unten ausgewählt.", "Klicken, um dieses Profil zu laden.", "Profil %s laden?", "Neues Profil", "KUI-Standardwerte", "Name des neuen Profils (KUI-Standardwerte):", "Ein Profil namens '%s' existiert bereits.", "Profil '%s' mit den KUI-Standardwerten erstellt.", "Rechtsklick zum Löschen.", "Das aktive Profil kann nicht gelöscht werden." },
    frFR = { "Cliquez sur une carte pour la sélectionner, double-cliquez pour la charger.", "Attribué à %s", "Profil actif", "Profil enregistré", "Actif", "Clic pour sélectionner. Double-clic pour charger.", "Sélectionné : %s", "Supprimer le profil %s ?", "Cliquez pour choisir l’icône de ce profil.", "PROFIL ACTUEL", "Choisir une icône", "Icône par défaut", "Style des sacs", "Durée d’affichage des messages", "Lueur de forme", "Remplissage plein", "Style de l’Armurerie", "Teinter la bordure selon la qualité", "Intensité de la teinte", "Monde", "Meilleure +%d", "%d/%d dans les temps", "Cette semaine : %d donjons", "Réinitialisation dans %s", "Aucune clé Mythique+ cette saison", "Aucun raid verrouillé cette semaine", "Score Mythique+", "Style de la minicarte", "Style de la barre d’incantation", "Cliquez sur un profil pour le charger. Il reste sélectionné pour les boutons ci-dessous.", "Cliquez pour charger ce profil.", "Charger le profil %s ?", "Nouveau profil", "Valeurs KUI par défaut", "Nom du nouveau profil (valeurs KUI par défaut) :", "Un profil nommé '%s' existe déjà.", "Profil '%s' créé avec les valeurs KUI par défaut.", "Clic droit pour supprimer.", "Vous ne pouvez pas supprimer le profil actif." },
    itIT = { "Clicca su una scheda per selezionarla, doppio clic per caricarla.", "Assegnato a %s", "Profilo attivo", "Profilo salvato", "Attivo", "Clic per selezionare. Doppio clic per caricare.", "Selezionato: %s", "Eliminare il profilo %s?", "Clicca per scegliere l’icona di questo profilo.", "PROFILO ATTUALE", "Scegli un’icona", "Icona predefinita", "Stile delle borse", "Durata visibile dei messaggi", "Bagliore della forma", "Riempimento pieno", "Stile dell’Armeria", "Colora il bordo in base alla qualità", "Intensità della tinta", "Mondo", "Migliore +%d", "%d/%d in tempo", "Questa settimana: %d spedizioni", "Azzeramento tra %s", "Nessuna spedizione Mitica+ in questa stagione", "Nessuna incursione salvata questa settimana", "Punteggio Mitiche+", "Stile della minimappa", "Stile della barra di lancio", "Clicca su un profilo per caricarlo. Resta selezionato per i pulsanti sotto.", "Clicca per caricare questo profilo.", "Caricare il profilo %s?", "Nuovo profilo", "Valori predefiniti KUI", "Nome del nuovo profilo (valori predefiniti KUI):", "Esiste già un profilo chiamato '%s'.", "Profilo '%s' creato con i valori predefiniti KUI.", "Clic destro per eliminare.", "Non puoi eliminare il profilo attivo." },
    ptBR = { "Clique em um cartão para selecioná-lo e clique duas vezes para carregá-lo.", "Atribuído a %s", "Perfil ativo", "Perfil salvo", "Ativo", "Clique para selecionar. Clique duas vezes para carregar.", "Selecionado: %s", "Excluir o perfil %s?", "Clique para escolher o ícone deste perfil.", "PERFIL ATUAL", "Escolha um ícone", "Ícone padrão", "Estilo das bolsas", "Tempo visível das mensagens", "Brilho da forma", "Preenchimento sólido", "Estilo do Arsenal", "Tingir borda pela qualidade", "Intensidade do tingimento", "Mundo", "Melhor +%d", "%d/%d no tempo", "Esta semana: %d corridas", "Reinicia em %s", "Nenhuma corrida Mítica+ nesta temporada", "Nenhuma raide salva nesta semana", "Pontuação Mítica+", "Estilo do minimapa", "Estilo da barra de lançamento", "Clique em um perfil para carregá-lo. Ele fica selecionado para os botões abaixo.", "Clique para carregar este perfil.", "Carregar o perfil %s?", "Novo perfil", "Padrões do KUI", "Nome do novo perfil (padrões do KUI):", "Já existe um perfil chamado '%s'.", "Perfil '%s' criado com os padrões do KUI.", "Clique com o botão direito para excluir.", "Você não pode excluir o perfil ativo." },
    ruRU = { "Нажмите на карточку, чтобы выбрать её, двойной щелчок загружает её.", "Назначен: %s", "Активный профиль", "Сохранённый профиль", "Активен", "Щелчок — выбрать. Двойной щелчок — загрузить.", "Выбран: %s", "Удалить профиль %s?", "Нажмите, чтобы выбрать значок этого профиля.", "ТЕКУЩИЙ ПРОФИЛЬ", "Выберите значок", "Значок по умолчанию", "Стиль сумок", "Время показа сообщений", "Свечение по форме", "Сплошная заливка", "Стиль арсенала", "Окрашивать рамку по качеству", "Сила окраски", "Мир", "Лучший +%d", "%d/%d вовремя", "На этой неделе: %d забегов", "Сброс через %s", "Нет забегов М+ в этом сезоне", "Нет сохранённых рейдов на этой неделе", "Рейтинг М+", "Стиль миникарты", "Стиль полосы заклинаний", "Нажмите на профиль, чтобы загрузить его. Он остаётся выбранным для кнопок ниже.", "Нажмите, чтобы загрузить этот профиль.", "Загрузить профиль %s?", "Новый профиль", "Настройки KUI по умолчанию", "Имя нового профиля (настройки KUI по умолчанию):", "Профиль с именем '%s' уже существует.", "Профиль '%s' создан с настройками KUI по умолчанию.", "Правый щелчок — удалить.", "Нельзя удалить активный профиль." },
    koKR = { "카드를 클릭하면 선택하고, 두 번 클릭하면 불러옵니다.", "%s에 할당됨", "사용 중인 프로필", "저장된 프로필", "사용 중", "클릭하여 선택. 두 번 클릭하여 불러오기.", "선택됨: %s", "%s 프로필을 삭제하시겠습니까?", "클릭하여 이 프로필의 아이콘을 선택합니다.", "현재 프로필", "아이콘 선택", "기본 아이콘", "가방 스타일", "메시지 표시 시간", "모양 강조 효과", "단색 채우기", "무기고 스타일", "품질에 따라 테두리 색상 적용", "색조 강도", "월드", "최고 +%d", "%d/%d 시간 내", "이번 주: %d회", "%s 후 초기화", "이번 시즌 쐐기돌 기록 없음", "이번 주 귀속된 공격대 없음", "쐐기돌 평점", "미니맵 스타일", "시전바 스타일", "프로필을 클릭하면 불러옵니다. 아래 버튼을 위해 선택된 상태로 유지됩니다.", "클릭하여 이 프로필을 불러옵니다.", "%s 프로필을 불러오시겠습니까?", "새 프로필", "KUI 기본값", "새 프로필 이름 (KUI 기본값):", "'%s' 이름의 프로필이 이미 있습니다.", "KUI 기본값으로 '%s' 프로필을 만들었습니다.", "오른쪽 클릭으로 삭제합니다.", "사용 중인 프로필은 삭제할 수 없습니다." },
    zhCN = { "单击卡片以选择，双击以加载。", "已分配给 %s", "当前配置文件", "已保存的配置文件", "使用中", "单击选择，双击加载。", "已选择：%s", "删除配置文件 %s？", "点击以选择此配置文件的图标。", "当前配置文件", "选择图标", "默认图标", "背包样式", "消息显示时间", "形状发光", "纯色填充", "军械库样式", "按品质为边框着色", "着色强度", "世界", "最佳 +%d", "%d/%d 限时", "本周：%d 次", "%s 后重置", "本赛季没有史诗钥石记录", "本周没有团队副本进度", "史诗钥石评分", "小地图样式", "施法条样式", "单击配置文件即可加载。它会保持选中状态，供下方按钮使用。", "单击以加载此配置文件。", "加载配置文件 %s？", "新建配置文件", "KUI 默认设置", "新配置文件名称（KUI 默认设置）：", "名为“%s”的配置文件已存在。", "已使用 KUI 默认设置创建配置文件“%s”。", "右键单击以删除。", "无法删除当前配置文件。" },
    zhTW = { "點擊卡片以選取，雙擊以載入。", "已指派給 %s", "目前設定檔", "已儲存的設定檔", "使用中", "點擊選取，雙擊載入。", "已選取：%s", "刪除設定檔 %s？", "點擊以選擇此設定檔的圖示。", "目前設定檔", "選擇圖示", "預設圖示", "背包樣式", "訊息顯示時間", "形狀發光", "純色填滿", "軍械庫樣式", "依品質為邊框著色", "著色強度", "世界", "最佳 +%d", "%d/%d 限時", "本週：%d 次", "%s 後重置", "本賽季沒有傳奇鑰石紀錄", "本週沒有團隊副本進度", "傳奇鑰石評分", "小地圖樣式", "施法條樣式", "點擊設定檔即可載入。它會保持選取狀態，供下方按鈕使用。", "點擊以載入此設定檔。", "載入設定檔 %s？", "新增設定檔", "KUI 預設設定", "新設定檔名稱（KUI 預設設定）：", "名為「%s」的設定檔已存在。", "已使用 KUI 預設設定建立設定檔「%s」。", "右鍵點擊以刪除。", "無法刪除目前設定檔。" },
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
