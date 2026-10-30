-- Kick Tracker (Enhancements), for every supported language.
-- Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Kick Tracker",
    "Kicks",
    "Ready",
    "My kick: %s",
    "Kick Tracker debug:",
    "Kick Tracker test: target an enemy with a nameplate to see the icons.",
    "Your group's interrupts on the enemy nameplates: who kicked what and who is ready next. Runs in Mythic and Mythic+ dungeons and in arenas. Only you need KUI.",
    "Enable Kick Tracker",
    "Show Nameplate Icons",
    "Icon Side",
    "Icon X Offset",
    "Icon Y Offset",
    "Show Kick Bars",
    "Bars Scale",
    "Focus Marker",
    "Announce Focus Marker in Party Chat",
    "On a ready check your marker is sent to the group: when it lands on an enemy, your kick shows there before you use it. Move the bars in Unlock Mode.",
    "Test Kick Tracker",
    "Dungeon & Raid Tools",
    "Combat res, gear checks, loot and repair.",
    "Interrupt Tracker",
    "Your group's kicks on the enemy nameplates.",
    "Nameplate Icons",
    "Text & Media",
    "Icon Text Size (0 = auto)",
    "Icon Border Size",
    "Lock Bars (off: drag them with the mouse)",
    "Show Background",
    "Background Opacity",
    "Show Title",
    "Show Spell Icon",
    "Class Colored Bars",
    "Bar Spacing",
    "Bars Font",
    "Name Text Size",
    "Timer Text Size",
    "Title Text Size",
    "Open Unlock Mode",
    "Bars",
    "Enemy Caster",
    "Interrupted",
}

local values = {
    esES = { "Rastreador de cortes", "Cortes", "Listo", "Mi corte: %s", "Depuración del rastreador de cortes:", "Prueba del rastreador de cortes: marca como objetivo a un enemigo con placa para ver los iconos.", "Los cortes de tu grupo sobre las placas enemigas: quién cortó qué y quién está listo para el siguiente. Funciona en mazmorras Míticas y Míticas+ y en arenas. Solo tú necesitas KUI.", "Activar rastreador de cortes", "Mostrar iconos en las placas", "Lado de los iconos", "Desplazamiento X de los iconos", "Desplazamiento Y de los iconos", "Mostrar barras de cortes", "Escala de las barras", "Marcador de foco", "Anunciar el marcador de foco en el chat de grupo", "En una comprobación de banda tu marcador se envía al grupo: cuando aparece sobre un enemigo, tu corte se muestra allí antes de usarlo. Mueve las barras en el modo de desbloqueo.", "Probar rastreador de cortes", "Herramientas de mazmorra y banda", "Res en combate, equipo, botín y reparación.", "Rastreador de interrupciones", "Los cortes de tu grupo sobre las placas enemigas.", "Iconos en las placas", "Texto y medios", "Tamaño del texto del icono (0 = auto)", "Grosor del borde del icono", "Bloquear barras (desactivado: arrástralas con el ratón)", "Mostrar fondo", "Opacidad del fondo", "Mostrar título", "Mostrar icono del hechizo", "Barras con color de clase", "Separación entre barras", "Fuente de las barras", "Tamaño del nombre", "Tamaño del temporizador", "Tamaño del título", "Abrir modo de desbloqueo", "Barras", "Lanzador enemigo", "Interrumpido" },
    deDE = { "Unterbrechungstracker", "Unterbrechungen", "Bereit", "Mein Kick: %s", "Debug des Unterbrechungstrackers:", "Test des Unterbrechungstrackers: Visiere einen Gegner mit Namensplakette an, um die Symbole zu sehen.", "Die Unterbrechungen deiner Gruppe auf den feindlichen Namensplaketten: wer was unterbrochen hat und wer als Nächstes bereit ist. Läuft in mythischen und Mythisch+-Dungeons und in Arenen. Nur du brauchst KUI.", "Unterbrechungstracker aktivieren", "Symbole an Namensplaketten zeigen", "Seite der Symbole", "X-Versatz der Symbole", "Y-Versatz der Symbole", "Unterbrechungsleisten zeigen", "Skalierung der Leisten", "Fokusmarkierung", "Fokusmarkierung im Gruppenchat ankündigen", "Bei einem Bereitschaftscheck wird deine Markierung an die Gruppe gesendet: Landet sie auf einem Gegner, erscheint dein Kick dort, bevor du ihn nutzt. Verschiebe die Leisten im Entsperrmodus.", "Unterbrechungstracker testen", "Dungeon- & Schlachtzugswerkzeuge", "Kampfwiederbelebung, Ausrüstung, Beute und Reparatur.", "Unterbrechungstracker", "Die Kicks deiner Gruppe auf den feindlichen Namensplaketten.", "Symbole an Namensplaketten", "Text & Medien", "Symboltextgröße (0 = auto)", "Symbolrahmenstärke", "Leisten sperren (aus: mit der Maus ziehen)", "Hintergrund zeigen", "Hintergrunddeckkraft", "Titel zeigen", "Zaubersymbol zeigen", "Leisten in Klassenfarbe", "Leistenabstand", "Schriftart der Leisten", "Namensgröße", "Timergröße", "Titelgröße", "Entsperrmodus öffnen", "Leisten", "Feindlicher Zauberwirker", "Unterbrochen" },
    frFR = { "Suivi des interruptions", "Interruptions", "Prêt", "Mon interruption : %s", "Débogage du suivi des interruptions :", "Test du suivi des interruptions : ciblez un ennemi avec une barre d’info pour voir les icônes.", "Les interruptions de votre groupe sur les barres d’info ennemies : qui a interrompu quoi et qui est prêt ensuite. Fonctionne en donjon mythique et Mythique+ et en arène. Vous seul avez besoin de KUI.", "Activer le suivi des interruptions", "Icônes sur les barres d’info", "Côté des icônes", "Décalage X des icônes", "Décalage Y des icônes", "Afficher les barres d’interruptions", "Échelle des barres", "Marqueur de focus", "Annoncer le marqueur de focus dans le groupe", "Lors d’un appel prêt, votre marqueur est envoyé au groupe : quand il est posé sur un ennemi, votre interruption s’y affiche avant usage. Déplacez les barres en mode déverrouillage.", "Tester le suivi des interruptions", "Outils de donjon et de raid", "Rez en combat, équipement, butin et réparation.", "Suivi des interruptions", "Les interruptions de votre groupe sur les barres d’info ennemies.", "Icônes sur les barres d’info", "Texte et médias", "Taille du texte de l’icône (0 = auto)", "Épaisseur de la bordure", "Verrouiller les barres (désactivé : les déplacer à la souris)", "Afficher le fond", "Opacité du fond", "Afficher le titre", "Afficher l’icône du sort", "Barres aux couleurs de classe", "Espacement des barres", "Police des barres", "Taille du nom", "Taille du minuteur", "Taille du titre", "Ouvrir le mode déverrouillage", "Barres", "Lanceur ennemi", "Interrompu" },
    itIT = { "Tracciamento interruzioni", "Interruzioni", "Pronto", "La mia interruzione: %s", "Debug del tracciamento interruzioni:", "Test del tracciamento interruzioni: bersaglia un nemico con la barra del nome per vedere le icone.", "Le interruzioni del gruppo sulle barre dei nemici: chi ha interrotto cosa e chi è pronto per il prossimo. Funziona nelle spedizioni mitiche e Mitiche+ e nelle arene. Solo tu hai bisogno di KUI.", "Attiva tracciamento interruzioni", "Mostra icone sulle barre del nome", "Lato delle icone", "Spostamento X delle icone", "Spostamento Y delle icone", "Mostra barre interruzioni", "Scala delle barre", "Segno di focus", "Annuncia il segno di focus nella chat di gruppo", "Durante un controllo di prontezza il tuo segno viene inviato al gruppo: quando compare su un nemico, la tua interruzione appare lì prima di usarla. Sposta le barre in modalità sblocco.", "Prova tracciamento interruzioni", "Strumenti per spedizioni e incursioni", "Res in combattimento, equipaggiamento, bottino e riparazione.", "Tracciamento interruzioni", "Le interruzioni del gruppo sulle barre dei nemici.", "Icone sulle barre del nome", "Testo e media", "Dimensione testo icona (0 = auto)", "Spessore bordo icona", "Blocca barre (disattivato: trascinale con il mouse)", "Mostra sfondo", "Opacità sfondo", "Mostra titolo", "Mostra icona dell’incantesimo", "Barre col colore di classe", "Spaziatura barre", "Carattere delle barre", "Dimensione nome", "Dimensione timer", "Dimensione titolo", "Apri modalità sblocco", "Barre", "Incantatore nemico", "Interrotto" },
    ptBR = { "Rastreador de interrupções", "Interrupções", "Pronto", "Minha interrupção: %s", "Depuração do rastreador de interrupções:", "Teste do rastreador de interrupções: selecione um inimigo com placa de nome para ver os ícones.", "As interrupções do seu grupo nas placas dos inimigos: quem interrompeu o quê e quem está pronto a seguir. Funciona em masmorras Míticas e Míticas+ e em arenas. Só você precisa do KUI.", "Ativar rastreador de interrupções", "Mostrar ícones nas placas", "Lado dos ícones", "Deslocamento X dos ícones", "Deslocamento Y dos ícones", "Mostrar barras de interrupções", "Escala das barras", "Marcador de foco", "Anunciar o marcador de foco no chat do grupo", "Numa verificação de prontidão seu marcador é enviado ao grupo: quando ele aparece num inimigo, sua interrupção é mostrada ali antes do uso. Mova as barras no modo de desbloqueio.", "Testar rastreador de interrupções", "Ferramentas de masmorra e raide", "Ress em combate, equipamento, saque e reparo.", "Rastreador de interrupções", "As interrupções do seu grupo nas placas dos inimigos.", "Ícones nas placas", "Texto e mídia", "Tamanho do texto do ícone (0 = auto)", "Espessura da borda do ícone", "Travar barras (desligado: arraste com o mouse)", "Mostrar fundo", "Opacidade do fundo", "Mostrar título", "Mostrar ícone do feitiço", "Barras na cor da classe", "Espaço entre barras", "Fonte das barras", "Tamanho do nome", "Tamanho do temporizador", "Tamanho do título", "Abrir modo de desbloqueio", "Barras", "Conjurador inimigo", "Interrompido" },
    ruRU = { "Отслеживание прерываний", "Прерывания", "Готово", "Моё прерывание: %s", "Отладка отслеживания прерываний:", "Тест отслеживания прерываний: выберите целью врага с индикатором здоровья, чтобы увидеть значки.", "Прерывания вашей группы на индикаторах врагов: кто что прервал и кто готов следующим. Работает в эпохальных и эпохальных+ подземельях и на аренах. KUI нужен только вам.", "Включить отслеживание прерываний", "Значки на индикаторах", "Сторона значков", "Смещение значков по X", "Смещение значков по Y", "Показывать полосы прерываний", "Масштаб полос", "Метка фокуса", "Объявлять метку фокуса в чате группы", "При проверке готовности ваша метка отправляется группе: когда она появляется на враге, ваше прерывание отображается там заранее. Перемещайте полосы в режиме разблокировки.", "Тест отслеживания прерываний", "Инструменты подземелий и рейдов", "Боевое воскрешение, снаряжение, добыча и ремонт.", "Отслеживание прерываний", "Прерывания вашей группы на индикаторах врагов.", "Значки на индикаторах", "Текст и медиа", "Размер текста значка (0 = авто)", "Толщина рамки значка", "Закрепить полосы (выкл.: перетаскивать мышью)", "Показывать фон", "Прозрачность фона", "Показывать заголовок", "Показывать значок заклинания", "Полосы цвета класса", "Расстояние между полосами", "Шрифт полос", "Размер имени", "Размер таймера", "Размер заголовка", "Открыть режим разблокировки", "Полосы", "Вражеский заклинатель", "Прервано" },
    koKR = { "차단 추적기", "차단", "준비", "내 차단: %s", "차단 추적기 디버그:", "차단 추적기 테스트: 이름표가 있는 적을 대상으로 지정하면 아이콘이 보입니다.", "적 이름표 위에 표시되는 파티의 차단: 누가 무엇을 차단했고 다음에 누가 준비되었는지. 신화 및 쐐기 던전과 투기장에서 작동합니다. KUI는 본인만 있으면 됩니다.", "차단 추적기 사용", "이름표 아이콘 표시", "아이콘 방향", "아이콘 X 오프셋", "아이콘 Y 오프셋", "차단 바 표시", "바 크기 비율", "주시 징표", "파티 채팅에 주시 징표 알리기", "전투 준비 확인 시 징표가 파티에 전송됩니다. 그 징표가 적에게 붙으면 사용 전에 차단 아이콘이 표시됩니다. 바는 잠금 해제 모드에서 이동하세요.", "차단 추적기 테스트", "던전 및 공격대 도구", "전투 부활, 장비 점검, 전리품, 수리.", "차단 추적기", "적 이름표 위의 파티 차단.", "이름표 아이콘", "텍스트 및 미디어", "아이콘 텍스트 크기 (0 = 자동)", "아이콘 테두리 두께", "바 잠금 (끄면 마우스로 끌어서 이동)", "배경 표시", "배경 불투명도", "제목 표시", "주문 아이콘 표시", "직업 색상 바", "바 간격", "바 글꼴", "이름 크기", "타이머 크기", "제목 크기", "잠금 해제 모드 열기", "바", "적 시전자", "차단됨" },
    zhCN = { "打断追踪", "打断", "就绪", "我的打断：%s", "打断追踪调试：", "打断追踪测试：选中一个带姓名板的敌人即可看到图标。", "在敌方姓名板上显示队伍的打断：谁打断了什么、下一个谁就绪。在史诗和史诗钥石地下城以及竞技场中生效。只有你需要 KUI。", "启用打断追踪", "在姓名板上显示图标", "图标方向", "图标 X 偏移", "图标 Y 偏移", "显示打断条", "打断条缩放", "焦点标记", "在队伍频道通报焦点标记", "就位确认时会把你的标记发给队伍：当该标记出现在敌人身上时，你的打断会提前显示在那里。在解锁模式中移动打断条。", "测试打断追踪", "地下城与团队工具", "战复、装备检查、拾取与修理。", "打断追踪", "敌方姓名板上的队伍打断。", "姓名板图标", "文字与材质", "图标文字大小（0 = 自动）", "图标边框粗细", "锁定打断条（关闭时可用鼠标拖动）", "显示背景", "背景不透明度", "显示标题", "显示法术图标", "职业颜色打断条", "打断条间距", "打断条字体", "名字大小", "计时大小", "标题大小", "打开解锁模式", "打断条", "敌方施法者", "已打断" },
    zhTW = { "打斷追蹤", "打斷", "就緒", "我的打斷：%s", "打斷追蹤除錯：", "打斷追蹤測試：選取一個帶名條的敵人即可看到圖示。", "在敵方名條上顯示隊伍的打斷：誰打斷了什麼、下一個誰就緒。在傳奇與傳奇鑰石地城以及競技場中生效。只有你需要 KUI。", "啟用打斷追蹤", "在名條上顯示圖示", "圖示方向", "圖示 X 偏移", "圖示 Y 偏移", "顯示打斷條", "打斷條縮放", "焦點標記", "在隊伍頻道通報焦點標記", "準備確認時會把你的標記傳給隊伍：當該標記出現在敵人身上時，你的打斷會預先顯示在那裡。在解鎖模式中移動打斷條。", "測試打斷追蹤", "地城與團隊工具", "戰復、裝備檢查、拾取與修理。", "打斷追蹤", "敵方名條上的隊伍打斷。", "名條圖示", "文字與材質", "圖示文字大小（0 = 自動）", "圖示邊框粗細", "鎖定打斷條（關閉時可用滑鼠拖動）", "顯示背景", "背景不透明度", "顯示標題", "顯示法術圖示", "職業顏色打斷條", "打斷條間距", "打斷條字型", "名字大小", "計時大小", "標題大小", "開啟解鎖模式", "打斷條", "敵方施法者", "已打斷" },
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
