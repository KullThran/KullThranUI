-- AFK screen (Enhancements > Interface) strings for every supported language. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "AFK Screen",
    "Enable AFK Screen",
    "Camera Spin",
    "Show Character Model",
    "Show Whispers and Guild Chat",
    "Show Logo",
    "Show Faction Icon",
    "Show Guild",
    "Show AFK Time",
    "Class Colored Name",
    "Idle Animation",
    "Logo Size",
    "Logo Opacity",
    "Model Scale",
    "Bottom Bar Height",
    "AFK Font Size",
    "Bottom Bar Color",
    "Preview AFK Screen",
    "Shown when you are flagged AFK. Press any key to leave it; combat, group finder and battleground invites close it too.",
    "No Guild",
    "Dance",
    "Salute",
    "Talk",
    "Shy",
    "Roar",
    "Lean",
    "What you see while away: character model, info bar, accent logo and whispers.",
}

local values = {
    esES = {
        "Pantalla AFK", "Activar pantalla AFK", "Giro de cámara", "Mostrar modelo del personaje",
        "Mostrar susurros y chat de hermandad", "Mostrar logotipo", "Mostrar icono de facción", "Mostrar hermandad",
        "Mostrar tiempo ausente", "Nombre con color de clase", "Animación en reposo", "Tamaño del logotipo",
        "Opacidad del logotipo", "Escala del modelo", "Altura de la barra inferior", "Tamaño de fuente AFK",
        "Color de la barra inferior", "Vista previa de la pantalla AFK",
        "Se muestra cuando estás marcado como ausente. Pulsa cualquier tecla para salir; el combate, el buscador de grupos y las invitaciones a campos de batalla también la cierran.",
        "Sin hermandad", "Bailar", "Saludo militar", "Hablar", "Tímido", "Rugir", "Apoyarse",
        "Lo que ves mientras estás ausente: modelo del personaje, barra de información, logotipo con el color de acento y susurros.",
    },
    deDE = {
        "AFK-Bildschirm", "AFK-Bildschirm aktivieren", "Kameradrehung", "Charaktermodell anzeigen",
        "Flüstern und Gildenchat anzeigen", "Emblem anzeigen", "Fraktionssymbol anzeigen", "Gilde anzeigen",
        "AFK-Zeit anzeigen", "Name in Klassenfarbe", "Leerlaufanimation", "Emblemgröße",
        "Emblem-Deckkraft", "Modellgröße", "Höhe der unteren Leiste", "AFK-Schriftgröße",
        "Farbe der unteren Leiste", "AFK-Bildschirm-Vorschau",
        "Wird angezeigt, wenn du als AFK markiert bist. Drücke eine beliebige Taste, um ihn zu verlassen; Kampf, Gruppensuche und Schlachtfeldeinladungen schließen ihn ebenfalls.",
        "Keine Gilde", "Tanzen", "Salutieren", "Reden", "Schüchtern", "Brüllen", "Anlehnen",
        "Was du siehst, während du abwesend bist: Charaktermodell, Infoleiste, Emblem in Akzentfarbe und Flüstern.",
    },
    frFR = {
        "Écran ABS", "Activer l'écran ABS", "Rotation de la caméra", "Afficher le modèle du personnage",
        "Afficher les chuchotements et le canal de guilde", "Afficher l'emblème", "Afficher l'icône de faction", "Afficher la guilde",
        "Afficher le temps d'absence", "Nom aux couleurs de classe", "Animation d'attente", "Taille de l'emblème",
        "Opacité de l'emblème", "Échelle du modèle", "Hauteur de la barre inférieure", "Taille de police ABS",
        "Couleur de la barre inférieure", "Aperçu de l'écran ABS",
        "S'affiche quand vous êtes marqué absent. Appuyez sur une touche pour le quitter ; le combat, la recherche de groupe et les invitations en champ de bataille le ferment aussi.",
        "Sans guilde", "Danser", "Saluer", "Parler", "Timide", "Rugir", "S'appuyer",
        "Ce que vous voyez pendant votre absence : modèle du personnage, barre d'infos, emblème aux couleurs d'accent et chuchotements.",
    },
    itIT = {
        "Schermata AFK", "Attiva la schermata AFK", "Rotazione della telecamera", "Mostra il modello del personaggio",
        "Mostra sussurri e chat di gilda", "Mostra l'emblema", "Mostra l'icona della fazione", "Mostra la gilda",
        "Mostra il tempo di assenza", "Nome col colore della classe", "Animazione di attesa", "Dimensione dell'emblema",
        "Opacità dell'emblema", "Scala del modello", "Altezza della barra inferiore", "Dimensione carattere AFK",
        "Colore della barra inferiore", "Anteprima schermata AFK",
        "Appare quando sei segnato come assente. Premi un tasto qualsiasi per uscire; il combattimento, la ricerca gruppi e gli inviti ai campi di battaglia la chiudono.",
        "Nessuna gilda", "Ballare", "Salutare", "Parlare", "Timido", "Ruggire", "Appoggiarsi",
        "Ciò che vedi mentre sei assente: modello del personaggio, barra informativa, emblema col colore d'accento e sussurri.",
    },
    ptBR = {
        "Tela de ausência", "Ativar tela de ausência", "Giro da câmera", "Mostrar modelo do personagem",
        "Mostrar sussurros e chat da guilda", "Mostrar emblema", "Mostrar ícone da facção", "Mostrar guilda",
        "Mostrar tempo ausente", "Nome na cor da classe", "Animação ociosa", "Tamanho do emblema",
        "Opacidade do emblema", "Escala do modelo", "Altura da barra inferior", "Tamanho da fonte da tela de ausência",
        "Cor da barra inferior", "Pré-visualizar tela de ausência",
        "Aparece quando você está marcado como ausente. Pressione qualquer tecla para sair; combate, localizador de grupos e convites de campo de batalha também a fecham.",
        "Sem guilda", "Dançar", "Saudar", "Falar", "Tímido", "Rugir", "Encostar",
        "O que você vê enquanto está ausente: modelo do personagem, barra de informações, emblema na cor de destaque e sussurros.",
    },
    ruRU = {
        "Экран АФК", "Включить экран АФК", "Вращение камеры", "Показывать модель персонажа",
        "Показывать шепот и чат гильдии", "Показывать эмблему", "Показывать значок фракции", "Показывать гильдию",
        "Показывать время отсутствия", "Имя цветом класса", "Анимация ожидания", "Размер эмблемы",
        "Непрозрачность эмблемы", "Масштаб модели", "Высота нижней панели", "Размер шрифта АФК",
        "Цвет нижней панели", "Предпросмотр экрана АФК",
        "Появляется, когда вы отмечены как АФК. Нажмите любую клавишу, чтобы выйти; бой, поиск группы и приглашения на поле боя тоже закрывают его.",
        "Без гильдии", "Танец", "Отдать честь", "Разговор", "Смущение", "Рык", "Опереться",
        "Что вы видите, пока отсутствуете: модель персонажа, информационная панель, эмблема акцентного цвета и шепот.",
    },
    koKR = {
        "자리 비움 화면", "자리 비움 화면 사용", "카메라 회전", "캐릭터 모델 표시",
        "귓속말 및 길드 대화 표시", "엠블럼 표시", "진영 아이콘 표시", "길드 표시",
        "자리 비움 시간 표시", "직업 색상 이름", "대기 애니메이션", "엠블럼 크기",
        "엠블럼 불투명도", "모델 크기", "하단 바 높이", "자리 비움 글꼴 크기",
        "하단 바 색상", "자리 비움 화면 미리보기",
        "자리 비움 상태일 때 표시됩니다. 아무 키나 눌러 나갈 수 있으며, 전투, 파티 찾기, 전장 초대 시에도 닫힙니다.",
        "길드 없음", "춤추기", "경례", "대화", "수줍음", "포효", "기대기",
        "자리 비움 중 보이는 화면: 캐릭터 모델, 정보 바, 강조 색상 엠블럼, 귓속말.",
    },
    zhCN = {
        "暂离画面", "启用暂离画面", "镜头旋转", "显示角色模型",
        "显示密语和公会聊天", "显示徽标", "显示阵营图标", "显示公会",
        "显示暂离时间", "职业颜色名字", "待机动作", "徽标大小",
        "徽标不透明度", "模型缩放", "底部栏高度", "暂离字号",
        "底部栏颜色", "预览暂离画面",
        "被标记为暂离时显示。按任意键退出；进入战斗、队伍查找器和战场邀请也会将其关闭。",
        "没有公会", "跳舞", "敬礼", "交谈", "害羞", "咆哮", "倚靠",
        "暂离时显示的内容：角色模型、信息栏、强调色徽标和密语。",
    },
    zhTW = {
        "暫離畫面", "啟用暫離畫面", "鏡頭旋轉", "顯示角色模型",
        "顯示悄悄話和公會聊天", "顯示徽標", "顯示陣營圖示", "顯示公會",
        "顯示暫離時間", "職業顏色名稱", "待機動作", "徽標大小",
        "徽標不透明度", "模型縮放", "底部列高度", "暫離字型大小",
        "底部列顏色", "預覽暫離畫面",
        "被標記為暫離時顯示。按任意鍵離開；進入戰鬥、隊伍搜尋器和戰場邀請也會將其關閉。",
        "沒有公會", "跳舞", "敬禮", "交談", "害羞", "咆哮", "倚靠",
        "暫離時顯示的內容：角色模型、資訊列、強調色徽標和悄悄話。",
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
