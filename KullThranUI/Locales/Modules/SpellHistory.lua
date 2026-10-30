-- Spell History (Enhancements), for every supported language.
-- Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Spell History",
    "The spells you press, in order, as a row of icons.",
    "UI clutter, text size, combat text and timers.",
    "The spells you press, in order: each new one enters at the front and pushes the others along. A cast you stop gets a red cross. Your own spells only.",
    "Enable Spell History",
    "Show",
    "Always",
    "In Combat",
    "In Dungeons and Raids",
    "Layout",
    "Direction",
    "Number of Icons",
    "Icon Spacing",
    "Enlarge the Newest Icon",
    "Newest Icon Scale",
    "Fading",
    "Fade After (seconds, 0 = never)",
    "Fade Duration",
    "Mark Stopped Casts",
    "Style",
    "Border Color",
    "Class Color",
    "Black",
    "Border Size",
    "Ignored Spells",
    "Spell IDs or names, comma separated",
    "Auto attacks and the second hit of two-hand strikes are never shown.",
    "Icon Style",
    "Icon Shape",
    "Shapes work with Modern KUI and Simplicity, as on the action bars.",
}

local values = {
    esES = { "Historial de hechizos", "Los hechizos que pulsas, en orden, como una fila de iconos.", "Elementos de la interfaz, tamaño de texto, texto de combate y temporizadores.", "Los hechizos que pulsas, en orden: cada uno nuevo entra delante y empuja a los demás. Un lanzamiento que detienes lleva una cruz roja. Solo tus hechizos.", "Activar historial de hechizos", "Mostrar", "Siempre", "En combate", "En mazmorras y bandas", "Disposición", "Dirección", "Número de iconos", "Separación de iconos", "Agrandar el icono más reciente", "Escala del icono más reciente", "Desvanecido", "Desvanecer tras (segundos, 0 = nunca)", "Duración del desvanecido", "Marcar lanzamientos detenidos", "Estilo", "Color del borde", "Color de clase", "Negro", "Tamaño del borde", "Hechizos ignorados", "IDs o nombres de hechizos, separados por comas", "Los ataques automáticos y el segundo golpe de los ataques a dos manos nunca se muestran.", "Estilo de icono", "Forma del icono", "Las formas funcionan con Modern KUI y Simplicity, como en las barras de acción." },
    deDE = { "Zauberverlauf", "Die Zauber, die du drückst, der Reihe nach als Symbolleiste.", "Oberflächenelemente, Textgröße, Kampftext und Timer.", "Die Zauber, die du drückst, der Reihe nach: jeder neue kommt nach vorn und schiebt die anderen weiter. Ein abgebrochener Zauber bekommt ein rotes Kreuz. Nur deine eigenen Zauber.", "Zauberverlauf aktivieren", "Anzeigen", "Immer", "Im Kampf", "In Dungeons und Schlachtzügen", "Anordnung", "Richtung", "Anzahl der Symbole", "Symbolabstand", "Neuestes Symbol vergrößern", "Skalierung des neuesten Symbols", "Ausblenden", "Ausblenden nach (Sekunden, 0 = nie)", "Ausblenddauer", "Abgebrochene Zauber markieren", "Stil", "Rahmenfarbe", "Klassenfarbe", "Schwarz", "Rahmenstärke", "Ignorierte Zauber", "Zauber-IDs oder -Namen, durch Kommas getrennt", "Automatische Angriffe und der zweite Schlag von Zweihandangriffen werden nie angezeigt.", "Symbolstil", "Symbolform", "Formen funktionieren mit Modern KUI und Simplicity, wie bei den Aktionsleisten." },
    frFR = { "Historique des sorts", "Les sorts que vous lancez, dans l’ordre, en rangée d’icônes.", "Éléments d’interface, taille du texte, texte de combat et minuteurs.", "Les sorts que vous lancez, dans l’ordre : chaque nouveau entre devant et pousse les autres. Un sort interrompu reçoit une croix rouge. Vos sorts uniquement.", "Activer l’historique des sorts", "Afficher", "Toujours", "En combat", "En donjon et en raid", "Disposition", "Direction", "Nombre d’icônes", "Espacement des icônes", "Agrandir l’icône la plus récente", "Échelle de l’icône la plus récente", "Fondu", "Fondu après (secondes, 0 = jamais)", "Durée du fondu", "Marquer les sorts interrompus", "Style", "Couleur de la bordure", "Couleur de classe", "Noir", "Taille de la bordure", "Sorts ignorés", "ID ou noms de sorts, séparés par des virgules", "Les attaques automatiques et le second coup des attaques à deux mains ne sont jamais affichés.", "Style d’icône", "Forme d’icône", "Les formes fonctionnent avec Modern KUI et Simplicity, comme sur les barres d’action." },
    itIT = { "Cronologia incantesimi", "Gli incantesimi che premi, in ordine, come una fila di icone.", "Elementi dell’interfaccia, dimensione del testo, testo di combattimento e timer.", "Gli incantesimi che premi, in ordine: ogni nuovo entra davanti e spinge gli altri. Un lancio interrotto riceve una croce rossa. Solo i tuoi incantesimi.", "Attiva cronologia incantesimi", "Mostra", "Sempre", "In combattimento", "In spedizioni e incursioni", "Disposizione", "Direzione", "Numero di icone", "Spaziatura icone", "Ingrandisci l’icona più recente", "Scala dell’icona più recente", "Dissolvenza", "Dissolvenza dopo (secondi, 0 = mai)", "Durata della dissolvenza", "Segna i lanci interrotti", "Stile", "Colore del bordo", "Colore di classe", "Nero", "Spessore del bordo", "Incantesimi ignorati", "ID o nomi degli incantesimi, separati da virgole", "Gli attacchi automatici e il secondo colpo degli attacchi a due mani non vengono mai mostrati.", "Stile icona", "Forma icona", "Le forme funzionano con Modern KUI e Simplicity, come sulle barre delle azioni." },
    ptBR = { "Histórico de feitiços", "Os feitiços que você usa, em ordem, como uma fileira de ícones.", "Elementos da interface, tamanho do texto, texto de combate e temporizadores.", "Os feitiços que você usa, em ordem: cada novo entra na frente e empurra os outros. Um lançamento interrompido ganha um X vermelho. Apenas seus feitiços.", "Ativar histórico de feitiços", "Mostrar", "Sempre", "Em combate", "Em masmorras e raides", "Disposição", "Direção", "Número de ícones", "Espaço entre ícones", "Aumentar o ícone mais recente", "Escala do ícone mais recente", "Esmaecer", "Esmaecer após (segundos, 0 = nunca)", "Duração do esmaecimento", "Marcar lançamentos interrompidos", "Estilo", "Cor da borda", "Cor da classe", "Preto", "Espessura da borda", "Feitiços ignorados", "IDs ou nomes de feitiços, separados por vírgulas", "Ataques automáticos e o segundo golpe de ataques com duas mãos nunca são mostrados.", "Estilo do ícone", "Formato do ícone", "Os formatos funcionam com Modern KUI e Simplicity, como nas barras de ação." },
    ruRU = { "История заклинаний", "Нажимаемые заклинания по порядку в виде ряда значков.", "Элементы интерфейса, размер текста, боевой текст и таймеры.", "Нажимаемые заклинания по порядку: каждое новое встаёт впереди и сдвигает остальные. Прерванное заклинание помечается красным крестом. Только ваши заклинания.", "Включить историю заклинаний", "Показывать", "Всегда", "В бою", "В подземельях и рейдах", "Расположение", "Направление", "Количество значков", "Расстояние между значками", "Увеличивать последний значок", "Масштаб последнего значка", "Исчезание", "Исчезать через (секунды, 0 = никогда)", "Длительность исчезания", "Отмечать прерванные заклинания", "Стиль", "Цвет рамки", "Цвет класса", "Чёрный", "Толщина рамки", "Игнорируемые заклинания", "ID или названия заклинаний через запятую", "Автоатака и второй удар двуручных атак никогда не показываются.", "Стиль значков", "Форма значков", "Формы работают со стилями Modern KUI и Simplicity, как на панелях команд." },
    koKR = { "주문 기록", "사용한 주문을 순서대로 아이콘 줄로 표시합니다.", "UI 요소, 글자 크기, 전투 문자, 타이머.", "사용한 주문을 순서대로 표시합니다. 새 주문은 맨 앞에 들어오고 나머지를 밀어냅니다. 중단한 시전에는 빨간 X가 표시됩니다. 내 주문만 표시합니다.", "주문 기록 사용", "표시", "항상", "전투 중", "던전 및 공격대에서", "배치", "방향", "아이콘 개수", "아이콘 간격", "최신 아이콘 확대", "최신 아이콘 크기 비율", "사라짐", "사라지기까지 (초, 0 = 사라지지 않음)", "사라지는 시간", "중단한 시전 표시", "스타일", "테두리 색상", "직업 색상", "검은색", "테두리 두께", "무시할 주문", "주문 ID 또는 이름 (쉼표로 구분)", "자동 공격과 양손 공격의 두 번째 타격은 표시되지 않습니다.", "아이콘 스타일", "아이콘 모양", "모양은 행동 단축바처럼 Modern KUI 및 Simplicity에서 작동합니다." },
    zhCN = { "法术历史", "按顺序以一排图标显示你施放的法术。", "界面元素、文字大小、战斗文字和计时器。", "按顺序显示你施放的法术：新法术从最前方进入并推动其他图标。被你停止的施法会标上红叉。仅显示你自己的法术。", "启用法术历史", "显示", "总是", "战斗中", "在地下城和团队副本中", "布局", "方向", "图标数量", "图标间距", "放大最新图标", "最新图标缩放", "渐隐", "渐隐延迟（秒，0 = 从不）", "渐隐时长", "标记已停止的施法", "样式", "边框颜色", "职业颜色", "黑色", "边框粗细", "忽略的法术", "法术ID或名称，用逗号分隔", "自动攻击和双手攻击的第二击永远不会显示。", "图标样式", "图标形状", "形状适用于 Modern KUI 和 Simplicity，与动作条相同。" },
    zhTW = { "法術歷史", "依序以一排圖示顯示你施放的法術。", "介面元素、文字大小、戰鬥文字和計時器。", "依序顯示你施放的法術：新法術從最前方進入並推動其他圖示。被你停止的施法會標上紅叉。僅顯示你自己的法術。", "啟用法術歷史", "顯示", "總是", "戰鬥中", "在地城和團隊副本中", "版面", "方向", "圖示數量", "圖示間距", "放大最新圖示", "最新圖示縮放", "漸隱", "漸隱延遲（秒，0 = 從不）", "漸隱時長", "標記已停止的施法", "樣式", "邊框顏色", "職業顏色", "黑色", "邊框粗細", "忽略的法術", "法術ID或名稱，以逗號分隔", "自動攻擊與雙手攻擊的第二擊永遠不會顯示。", "圖示樣式", "圖示形狀", "形狀適用於 Modern KUI 與 Simplicity，與快捷列相同。" },
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
