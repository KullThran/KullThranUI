-- Visual Styles section (Advanced Style System): theme cards, health/class
-- buttons, tooltips, theme names/descriptions, the Visual Theme block texts
-- and the preset color names. Same merge rule as OptionsGaps.lua: only fills
-- a locale when it has no real translation for the key yet.
local _, ns = ...

local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local localeOrder = { "esES", "deDE", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
local translations = {
    ["Visual Theme"] = { "Tema visual", "Visuelles Thema", "Thème visuel", "Tema visivo", "Tema visual", "Визуальная тема", "시각 테마", "视觉主题", "視覺主題" },
    ["Select the visual theme. This sets the geometry and assets for Unit Frames. The addon's own accent color below stays yours to customize regardless of which style you pick."] = { "Selecciona el tema visual. Define la geometría y los recursos de los marcos de unidad. El color de acento propio del addon, más abajo, sigue siendo tuyo para personalizar, elijas el estilo que elijas.", "Wähle das visuelle Thema. Es legt Geometrie und Grafiken der Einheitenfenster fest. Die addoneigene Akzentfarbe weiter unten kannst du unabhängig vom gewählten Stil weiterhin selbst anpassen.", "Choisissez le thème visuel. Il définit la géométrie et les ressources des cadres d'unité. La couleur d'accent propre à l'addon, plus bas, reste personnalisable quel que soit le style choisi.", "Seleziona il tema visivo. Definisce geometria e risorse dei riquadri unità. Il colore d'accento dell'addon, più sotto, resta personalizzabile qualunque stile tu scelga.", "Selecione o tema visual. Ele define a geometria e os recursos dos quadros de unidade. A cor de destaque do próprio addon, abaixo, continua personalizável, qualquer que seja o estilo escolhido.", "Выберите визуальную тему. Она задаёт геометрию и ресурсы рамок бойцов. Собственный акцентный цвет аддона ниже по-прежнему настраивается независимо от выбранного стиля.", "시각 테마를 선택하세요. 개체창의 형태와 리소스가 결정됩니다. 아래의 애드온 고유 강조 색상은 어떤 스타일을 선택하든 계속 직접 설정할 수 있습니다.", "选择视觉主题。它决定单位框体的几何形状和素材。下方插件自身的强调色不受所选样式影响，仍可自行定制。", "選擇視覺主題。它決定單位框架的幾何形狀與素材。下方插件自身的強調色不受所選樣式影響，仍可自行自訂。" },
    ["Visual Style & Color"] = { "Estilo visual y color", "Visueller Stil & Farbe", "Style visuel et couleur", "Stile visivo e colore", "Estilo visual e cor", "Визуальный стиль и цвет", "시각 스타일 및 색상", "视觉风格与颜色", "視覺風格與顏色" },
    ["Pick the look of your interface and its accent color."] = { "Elige el aspecto de tu interfaz y su color de acento.", "Wähle das Aussehen deiner Oberfläche und ihre Akzentfarbe.", "Choisissez l'apparence de votre interface et sa couleur d'accent.", "Scegli l'aspetto della tua interfaccia e il suo colore d'accento.", "Escolha a aparência da sua interface e a cor de destaque.", "Выберите внешний вид интерфейса и акцентный цвет.", "인터페이스의 외형과 강조 색상을 선택하세요.", "选择界面的外观和强调色。", "選擇介面的外觀和強調色。" },
    ["Visual Style"] = { "Estilo visual", "Visueller Stil", "Style visuel", "Stile visivo", "Estilo visual", "Визуальный стиль", "시각 스타일", "视觉风格", "視覺風格" },
    ["Accent Color"] = { "Color de acento", "Akzentfarbe", "Couleur d'accent", "Colore d'accento", "Cor de destaque", "Акцентный цвет", "강조 색상", "强调色", "強調色" },
    ["Player Rare / Elite Border"] = { "Borde Raro / Élite del jugador", "Selten-/Elite-Rahmen des Spielers", "Bordure Rare / Élite du joueur", "Bordo Raro / Élite del giocatore", "Borda Raro / Elite do jogador", "Рамка редкого / элитного для игрока", "플레이어 희귀 / 엘리트 테두리", "玩家稀有/精英边框", "玩家稀有/精英邊框" },
    ["Default"] = { "Predeterminado", "Standard", "Par défaut", "Predefinito", "Padrão", "По умолчанию", "기본값", "默认", "預設" },
    ["Theme portrait"] = { "Retrato del tema", "Themen-Porträt", "Portrait du thème", "Ritratto del tema", "Retrato do tema", "Портрет темы", "테마 초상화", "主题头像", "主題頭像" },
    ["Rare"] = { "Raro", "Selten", "Rare", "Raro", "Raro", "Редкий", "희귀", "稀有", "稀有" },
    ["Elite"] = { "Élite", "Elite", "Élite", "Élite", "Elite", "Элитный", "엘리트", "精英", "精英" },
    ["Preset Colors"] = { "Colores predefinidos", "Farbvorgaben", "Couleurs prédéfinies", "Colori predefiniti", "Cores predefinidas", "Цветовые пресеты", "색상 프리셋", "预设颜色", "預設顏色" },
    ["APPLY TO ALL"] = { "APLICAR A TODO", "AUF ALLES ANWENDEN", "APPLIQUER PARTOUT", "APPLICA A TUTTO", "APLICAR A TUDO", "ПРИМЕНИТЬ КО ВСЕМУ", "모두 적용", "应用到全部", "套用到全部" },
    ["IN USE"] = { "EN USO", "AKTIV", "ACTIF", "IN USO", "EM USO", "ВЫБРАНО", "사용 중", "使用中", "使用中" },
    ["HEALTH"] = { "SALUD", "LEBEN", "VIE", "SALUTE", "VIDA", "ЗДОРОВЬЕ", "생명력", "生命值", "生命值" },
    ["CLASS"] = { "CLASE", "KLASSE", "CLASSE", "CLASSE", "CLASSE", "КЛАСС", "직업", "职业", "職業" },
    ["Currently in use."] = { "En uso actualmente.", "Derzeit in Verwendung.", "Actuellement utilisé.", "Attualmente in uso.", "Em uso no momento.", "Используется сейчас.", "현재 사용 중입니다.", "当前正在使用。", "目前正在使用。" },
    ["Class Color"] = { "Color de clase", "Klassenfarbe", "Couleur de classe", "Colore di classe", "Cor da classe", "Цвет класса", "직업 색상", "职业颜色", "職業顏色" },
    ["Use your class color for health."] = { "Usa el color de tu clase para la salud.", "Verwendet deine Klassenfarbe für die Gesundheit.", "Utilise la couleur de votre classe pour la vie.", "Usa il colore della tua classe per la salute.", "Usa a cor da sua classe para a vida.", "Использовать цвет вашего класса для здоровья.", "생명력에 직업 색상을 사용합니다.", "生命值使用你的职业颜色。", "生命值使用你的職業顏色。" },
    ["Health Color"] = { "Color de salud", "Lebensfarbe", "Couleur de vie", "Colore della salute", "Cor da vida", "Цвет здоровья", "생명력 색상", "生命值颜色", "生命值顏色" },
    ["Click to pick any color."] = { "Haz clic para elegir cualquier color.", "Klicken, um eine beliebige Farbe zu wählen.", "Cliquez pour choisir n'importe quelle couleur.", "Fai clic per scegliere qualsiasi colore.", "Clique para escolher qualquer cor.", "Нажмите, чтобы выбрать любой цвет.", "클릭하여 원하는 색상을 선택합니다.", "点击选择任意颜色。", "點擊選擇任意顏色。" },
    ["KULLTHRANUI STYLE"] = { "ESTILO KULLTHRANUI", "KULLTHRANUI-STIL", "STYLE KULLTHRANUI", "STILE KULLTHRANUI", "ESTILO KULLTHRANUI", "СТИЛЬ KULLTHRANUI", "KULLTHRANUI 스타일", "KULLTHRANUI 样式", "KULLTHRANUI 樣式" },
    ["FOREVER ART"] = { "ARTE FOREVER", "FOREVER-STIL", "STYLE FOREVER", "ARTE FOREVER", "ARTE FOREVER", "СТИЛЬ FOREVER", "FOREVER 아트", "FOREVER 美术", "FOREVER 美術" },
    ["BLIZZARD MODERN"] = { "BLIZZARD MODERNO", "BLIZZARD MODERN", "BLIZZARD MODERNE", "BLIZZARD MODERNO", "BLIZZARD MODERNO", "СОВРЕМЕННЫЙ BLIZZARD", "블리자드 모던", "暴雪现代风", "暴雪現代風" },
    ["VANILLA ART"] = { "ARTE CLÁSICO", "VANILLA-STIL", "STYLE VANILLA", "ARTE VANILLA", "ARTE VANILLA", "СТИЛЬ VANILLA", "바닐라 아트", "怀旧美术", "經典美術" },
    ["Flat KullThranUI frames, textures and colors."] = { "Marcos, texturas y colores planos de KullThranUI.", "Flache KullThranUI-Fenster, Texturen und Farben.", "Cadres, textures et couleurs plats de KullThranUI.", "Riquadri, texture e colori piatti di KullThranUI.", "Quadros, texturas e cores planos do KullThranUI.", "Плоские рамки, текстуры и цвета KullThranUI.", "플랫한 KullThranUI 창, 텍스처 및 색상.", "扁平化的 KullThranUI 框体、材质和颜色。", "扁平化的 KullThranUI 框架、材質與顏色。" },
    ["Bronze accents, round portraits and shaped icons."] = { "Acentos de bronce, retratos redondos e iconos con forma.", "Bronzeakzente, runde Porträts und geformte Symbole.", "Accents bronze, portraits ronds et icônes à forme.", "Accenti bronzo, ritratti rotondi e icone sagomate.", "Detalhes em bronze, retratos redondos e ícones com forma.", "Бронзовые акценты, круглые портреты и фигурные значки.", "청동 강조색, 원형 초상화, 모양이 있는 아이콘.", "青铜点缀、圆形头像和异形图标。", "青銅點綴、圓形頭像與異形圖示。" },
    ["Modern Blizzard bars, clean borders and square icons."] = { "Barras modernas de Blizzard, bordes limpios e iconos cuadrados.", "Moderne Blizzard-Leisten, saubere Ränder und quadratische Symbole.", "Barres Blizzard modernes, bordures nettes et icônes carrées.", "Barre Blizzard moderne, bordi puliti e icone quadrate.", "Barras modernas da Blizzard, bordas limpas e ícones quadrados.", "Современные полосы Blizzard, аккуратные рамки и квадратные значки.", "현대적인 블리자드 바, 깔끔한 테두리, 사각 아이콘.", "现代暴雪血条、简洁边框和方形图标。", "現代暴雪血條、簡潔邊框與方形圖示。" },
    ["Classic textures, attached portraits and square slots."] = { "Texturas clásicas, retratos acoplados y casillas cuadradas.", "Klassische Texturen, angedockte Porträts und quadratische Felder.", "Textures classiques, portraits attachés et emplacements carrés.", "Texture classiche, ritratti agganciati e slot quadrati.", "Texturas clássicas, retratos acoplados e espaços quadrados.", "Классические текстуры, прикреплённые портреты и квадратные ячейки.", "클래식 텍스처, 부착형 초상화, 사각 슬롯.", "经典材质、贴附式头像和方形栏位。", "經典材質、貼附式頭像與方形欄位。" },
    ["KUI Crimson"] = { "KUI Carmesí", "KUI Karmesin", "KUI Cramoisi", "KUI Cremisi", "KUI Carmesim", "KUI Багровый", "KUI 진홍", "KUI 绯红", "KUI 緋紅" },
    ["Frost Blue"] = { "Azul escarcha", "Frostblau", "Bleu givre", "Blu gelo", "Azul gelo", "Морозный синий", "서리 파랑", "霜蓝", "霜藍" },
    ["Emerald Night"] = { "Noche esmeralda", "Smaragdnacht", "Nuit émeraude", "Notte smeraldo", "Noite esmeralda", "Изумрудная ночь", "에메랄드 밤", "翡翠之夜", "翡翠之夜" },
    ["Royal Violet"] = { "Violeta real", "Königsviolett", "Violet royal", "Viola reale", "Violeta real", "Королевский фиолетовый", "로열 바이올렛", "皇家紫", "皇家紫" },
    ["Ember Gold"] = { "Oro ascua", "Glutgold", "Or de braise", "Oro brace", "Ouro brasa", "Тлеющее золото", "불씨 황금", "余烬金", "餘燼金" },
    ["Obsidian Teal"] = { "Turquesa obsidiana", "Obsidian-Türkis", "Sarcelle obsidienne", "Verde acqua ossidiana", "Verde-azulado obsidiana", "Обсидиановая бирюза", "흑요석 청록", "黑曜石青", "黑曜石青" },
    ["Blood Moon"] = { "Luna de sangre", "Blutmond", "Lune de sang", "Luna di sangue", "Lua de sangue", "Кровавая луна", "블러드 문", "血月", "血月" },
    ["Sunforge"] = { "Forja solar", "Sonnenschmiede", "Forge-soleil", "Forgiasole", "Forja solar", "Солнечная кузня", "태양 대장간", "日炼", "日煉" },
    ["Arcwine"] = { "Vino arcano", "Arkanwein", "Vin arcanique", "Vino arcano", "Vinho arcano", "Тайное вино", "비전 와인", "奥术酒红", "奧術酒紅" },
    ["Stormsteel"] = { "Acero tormenta", "Sturmstahl", "Acier-tempête", "Acciaio tempesta", "Aço tempestade", "Штормовая сталь", "폭풍 강철", "风暴钢", "風暴鋼" },
    ["Plague Green"] = { "Verde plaga", "Seuchengrün", "Vert peste", "Verde peste", "Verde praga", "Чумной зелёный", "역병 녹색", "瘟疫绿", "瘟疫綠" },
    ["Sakura Fall"] = { "Caída de sakura", "Sakura-Fall", "Chute de sakura", "Caduta di sakura", "Queda de sakura", "Падение сакуры", "벚꽃 낙화", "樱花飘落", "櫻花飄落" },
    ["Classic Rare"] = { "Raro clásico", "Klassisch Selten", "Rare classique", "Raro classico", "Raro clássico", "Классический редкий", "클래식 희귀", "经典稀有", "經典稀有" },
    ["Classic Elite"] = { "Élite clásico", "Klassisch Elite", "Élite classique", "Élite classico", "Elite clássico", "Классический элитный", "클래식 엘리트", "经典精英", "經典精英" },
    ["Combo Point Shape"] = { "Forma de los puntos de combo", "Form der Combopunkte", "Forme des points de combo", "Forma dei punti combo", "Forma dos pontos de combo", "Форма приёмов в серии", "연계 점수 모양", "连击点形状", "連擊點形狀" },
    ["Circles"] = { "Círculos", "Kreise", "Cercles", "Cerchi", "Círculos", "Круги", "원형", "圆形", "圓形" },
    ["Pips"] = { "Segmentos", "Segmente", "Segments", "Segmenti", "Segmentos", "Сегменты", "막대", "条形", "條形" },
    ["Smooth Health/Power Bars"] = { "Barras de salud/poder suaves", "Sanfte Leben-/Ressourcenleisten", "Barres de vie/ressource fluides", "Barre salute/risorsa fluide", "Barras de vida/recurso suaves", "Плавные полосы здоровья/ресурса", "부드러운 생명력/자원 바", "平滑生命/能量条", "平滑生命/能量條" },
    ["Show Elite / Rare Indicator"] = { "Mostrar indicador Élite / Raro", "Elite-/Selten-Anzeige anzeigen", "Afficher l'indicateur Élite / Rare", "Mostra indicatore Élite / Raro", "Mostrar indicador Elite / Raro", "Показывать значок элитного / редкого", "엘리트 / 희귀 표시 보기", "显示精英/稀有标记", "顯示精英/稀有標記" },
    ["Show PvP Icon Backdrop Circle"] = { "Mostrar círculo de fondo del icono PvP", "Hintergrundkreis des PvP-Symbols anzeigen", "Afficher le cercle de fond de l'icône JcJ", "Mostra cerchio di sfondo dell'icona PvP", "Mostrar círculo de fundo do ícone JxJ", "Показывать круг под значком PvP", "PvP 아이콘 배경 원 표시", "显示PvP图标背景圆", "顯示PvP圖示背景圓" },
    ["Show Character Level"] = { "Mostrar nivel del personaje", "Charakterstufe anzeigen", "Afficher le niveau du personnage", "Mostra livello del personaggio", "Mostrar nível do personagem", "Показывать уровень персонажа", "캐릭터 레벨 표시", "显示角色等级", "顯示角色等級" },
    ["Level Font Size"] = { "Tamaño de fuente del nivel", "Schriftgröße der Stufe", "Taille de police du niveau", "Dimensione carattere del livello", "Tamanho da fonte do nível", "Размер шрифта уровня", "레벨 글꼴 크기", "等级字体大小", "等級字型大小" },
    ["Level Text Color"] = { "Color del texto del nivel", "Textfarbe der Stufe", "Couleur du texte du niveau", "Colore del testo del livello", "Cor do texto do nível", "Цвет текста уровня", "레벨 텍스트 색상", "等级文字颜色", "等級文字顏色" },
    ["Level Text Outline"] = { "Contorno del texto del nivel", "Textumriss der Stufe", "Contour du texte du niveau", "Contorno del testo del livello", "Contorno do texto do nível", "Контур текста уровня", "레벨 텍스트 외곽선", "等级文字描边", "等級文字描邊" },
    ["Level X Offset"] = { "Desplazamiento X del nivel", "X-Versatz der Stufe", "Décalage X du niveau", "Offset X del livello", "Deslocamento X do nível", "Смещение уровня по X", "레벨 X 오프셋", "等级 X 偏移", "等級 X 偏移" },
    ["Level Y Offset"] = { "Desplazamiento Y del nivel", "Y-Versatz der Stufe", "Décalage Y du niveau", "Offset Y del livello", "Deslocamento Y do nível", "Смещение уровня по Y", "레벨 Y 오프셋", "等级 Y 偏移", "等級 Y 偏移" },
    ["Frame Size"] = { "Tamaño del marco", "Fenstergröße", "Taille du cadre", "Dimensione riquadro", "Tamanho do quadro", "Размер рамки", "프레임 크기", "框体大小", "框架大小" },
}

for key, values in pairs(translations) do
    for index, localeName in ipairs(localeOrder) do
        local locale = locales[localeName]
        local value = values[index]
        if locale and value then
            local current = rawget(locale, key)
            local englishValue = locales.enUS and rawget(locales.enUS, key)
            if current == nil or current == key or current == englishValue then locale[key] = value end
        end
    end
end
