-- Nameplates: pending DoT damage (health your bleeds and DoTs will still take).
-- Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "DOT DAMAGE",
    "Show Pending DoT Damage",
    "Draws a marker on every enemy nameplate with your DoTs on it, for the damage they still have to deal. If the health ends inside the marker, the DoTs will kill it.",
    "Wait for First Tick",
    "DoT Colors",
    "Fill Style",
    "Fill Color",
    "Fill Opacity",
    "Outline",
    "Dash Length",
    "Outline Thickness",
    "Outline Color",
    "Outline Opacity",
    "Forget Learned Tick Sizes",
    "Show Kill Icon",
    "Shows an icon next to the nameplate when your DoTs will kill it.",
    "Kill Icon",
    "Kill Icon Size",
    "Kill Icon Position",
    "Icon Horizontal Offset",
    "Icon Vertical Offset",
    "Raid skull",
    "Red X",
    "Green checkmark",
    "Boss skull",
    "Sunglasses",
    "None",
    "Flat",
    "Health bar texture",
    "Raid bar texture",
    "Diagonal stripes",
    "Dashed",
    "Solid",
    "Fine dots (1px)",
    "Dots (2px)",
    "Short dashes (4px)",
    "Dashes (8px)",
    "Long dashes (16px)",
    "Right of the health bar",
    "Left of the health bar",
    "Above the health bar",
    "One color (fill color)",
    "By spell school",
    "Different color per DoT",
    "Never (estimate straight away)",
    "When unsure",
    "Always (real ticks only)",
}

local values = {
    esES = { "DAÑO DE DOTS", "Mostrar daño pendiente de DoTs", "Dibuja una marca en cada placa enemiga con tus DoTs, con el daño que todavía van a hacer. Si la vida termina dentro de la marca, los DoTs lo van a matar.", "Esperar al primer tick", "Colores de DoTs", "Estilo de relleno", "Color de relleno", "Opacidad del relleno", "Contorno", "Longitud del trazo", "Grosor del contorno", "Color del contorno", "Opacidad del contorno", "Olvidar ticks aprendidos", "Mostrar icono de muerte", "Muestra un icono junto a la placa cuando tus DoTs lo van a matar.", "Icono de muerte", "Tamaño del icono de muerte", "Posición del icono de muerte", "Desplazamiento horizontal del icono", "Desplazamiento vertical del icono", "Calavera de banda", "X roja", "Marca verde", "Calavera de jefe", "Gafas de sol", "Ninguno", "Plano", "Textura de barra de vida", "Textura de barra de banda", "Rayas diagonales", "Discontinuo", "Continuo", "Puntos finos (1px)", "Puntos (2px)", "Trazos cortos (4px)", "Trazos (8px)", "Trazos largos (16px)", "A la derecha de la barra de vida", "A la izquierda de la barra de vida", "Encima de la barra de vida", "Un color (color de relleno)", "Por escuela de hechizo", "Un color distinto por DoT", "Nunca (estimar al momento)", "Si no es seguro", "Siempre (solo ticks reales)" },
    deDE = { "DOT-SCHADEN", "Ausstehenden DoT-Schaden anzeigen", "Zeichnet auf jeder gegnerischen Namensplakette mit deinen DoTs eine Markierung für den Schaden, den sie noch verursachen. Endet die Gesundheit innerhalb der Markierung, töten die DoTs das Ziel.", "Auf ersten Tick warten", "DoT-Farben", "Füllstil", "Füllfarbe", "Fülldeckkraft", "Umriss", "Strichlänge", "Umrissdicke", "Umrissfarbe", "Umrissdeckkraft", "Gelernte Tick-Größen vergessen", "Tötungssymbol anzeigen", "Zeigt ein Symbol neben der Namensplakette, wenn deine DoTs das Ziel töten.", "Tötungssymbol", "Größe des Tötungssymbols", "Position des Tötungssymbols", "Horizontaler Symbolversatz", "Vertikaler Symbolversatz", "Schlachtzug-Totenkopf", "Rotes X", "Grüner Haken", "Boss-Totenkopf", "Sonnenbrille", "Keine", "Flach", "Gesundheitsleisten-Textur", "Schlachtzugsleisten-Textur", "Diagonale Streifen", "Gestrichelt", "Durchgehend", "Feine Punkte (1px)", "Punkte (2px)", "Kurze Striche (4px)", "Striche (8px)", "Lange Striche (16px)", "Rechts der Gesundheitsleiste", "Links der Gesundheitsleiste", "Über der Gesundheitsleiste", "Eine Farbe (Füllfarbe)", "Nach Zauberschule", "Andere Farbe je DoT", "Nie (sofort schätzen)", "Wenn unsicher", "Immer (nur echte Ticks)" },
    frFR = { "DÉGÂTS DES DOTS", "Afficher les dégâts en attente des DoTs", "Dessine un marqueur sur chaque barre de nom ennemie portant vos DoTs, pour les dégâts qu'ils doivent encore infliger. Si la vie se termine dans le marqueur, les DoTs vont le tuer.", "Attendre le premier tick", "Couleurs des DoTs", "Style de remplissage", "Couleur de remplissage", "Opacité du remplissage", "Contour", "Longueur des tirets", "Épaisseur du contour", "Couleur du contour", "Opacité du contour", "Oublier les ticks appris", "Afficher l'icône de mort", "Affiche une icône à côté de la barre de nom quand vos DoTs vont le tuer.", "Icône de mort", "Taille de l'icône de mort", "Position de l'icône de mort", "Décalage horizontal de l'icône", "Décalage vertical de l'icône", "Crâne de raid", "X rouge", "Coche verte", "Crâne de boss", "Lunettes de soleil", "Aucun", "Uni", "Texture de barre de vie", "Texture de barre de raid", "Rayures diagonales", "Pointillés", "Plein", "Points fins (1px)", "Points (2px)", "Tirets courts (4px)", "Tirets (8px)", "Tirets longs (16px)", "À droite de la barre de vie", "À gauche de la barre de vie", "Au-dessus de la barre de vie", "Une couleur (couleur de remplissage)", "Par école de sort", "Couleur différente par DoT", "Jamais (estimer immédiatement)", "En cas de doute", "Toujours (ticks réels uniquement)" },
    itIT = { "DANNI DEI DOT", "Mostra i danni in sospeso dei DoT", "Disegna un indicatore su ogni targhetta nemica con i tuoi DoT, per i danni che devono ancora infliggere. Se la salute finisce dentro l'indicatore, i DoT lo uccideranno.", "Attendi il primo tick", "Colori dei DoT", "Stile di riempimento", "Colore di riempimento", "Opacità del riempimento", "Contorno", "Lunghezza del tratteggio", "Spessore del contorno", "Colore del contorno", "Opacità del contorno", "Dimentica i tick appresi", "Mostra icona di uccisione", "Mostra un'icona accanto alla targhetta quando i tuoi DoT lo uccideranno.", "Icona di uccisione", "Dimensione icona di uccisione", "Posizione icona di uccisione", "Spostamento orizzontale icona", "Spostamento verticale icona", "Teschio d'incursione", "X rossa", "Spunta verde", "Teschio del boss", "Occhiali da sole", "Nessuno", "Piatto", "Texture barra della salute", "Texture barra d'incursione", "Strisce diagonali", "Tratteggiato", "Continuo", "Punti sottili (1px)", "Punti (2px)", "Trattini corti (4px)", "Trattini (8px)", "Trattini lunghi (16px)", "A destra della barra della salute", "A sinistra della barra della salute", "Sopra la barra della salute", "Un colore (colore di riempimento)", "Per scuola di magia", "Colore diverso per DoT", "Mai (stima subito)", "Se incerto", "Sempre (solo tick reali)" },
    ptBR = { "DANO DE DOTS", "Mostrar dano pendente de DoTs", "Desenha um marcador em cada placa inimiga com seus DoTs, para o dano que eles ainda vão causar. Se a vida terminar dentro do marcador, os DoTs vão matá-lo.", "Esperar o primeiro tick", "Cores dos DoTs", "Estilo de preenchimento", "Cor de preenchimento", "Opacidade do preenchimento", "Contorno", "Comprimento do traço", "Espessura do contorno", "Cor do contorno", "Opacidade do contorno", "Esquecer ticks aprendidos", "Mostrar ícone de morte", "Mostra um ícone ao lado da placa quando seus DoTs vão matá-lo.", "Ícone de morte", "Tamanho do ícone de morte", "Posição do ícone de morte", "Deslocamento horizontal do ícone", "Deslocamento vertical do ícone", "Caveira de raide", "X vermelho", "Marca verde", "Caveira de chefe", "Óculos de sol", "Nenhum", "Plano", "Textura da barra de vida", "Textura da barra de raide", "Listras diagonais", "Tracejado", "Sólido", "Pontos finos (1px)", "Pontos (2px)", "Traços curtos (4px)", "Traços (8px)", "Traços longos (16px)", "À direita da barra de vida", "À esquerda da barra de vida", "Acima da barra de vida", "Uma cor (cor de preenchimento)", "Por escola de magia", "Cor diferente por DoT", "Nunca (estimar na hora)", "Quando incerto", "Sempre (apenas ticks reais)" },
    ruRU = { "УРОН DOT", "Показывать ожидаемый урон DoT", "Рисует метку на каждом вражеском индикаторе с вашими DoT, показывая урон, который они ещё нанесут. Если здоровье заканчивается внутри метки, DoT убьют цель.", "Ждать первого тика", "Цвета DoT", "Стиль заливки", "Цвет заливки", "Непрозрачность заливки", "Контур", "Длина штриха", "Толщина контура", "Цвет контура", "Непрозрачность контура", "Забыть изученные тики", "Показывать значок убийства", "Показывает значок рядом с индикатором, когда ваши DoT убьют цель.", "Значок убийства", "Размер значка убийства", "Положение значка убийства", "Смещение значка по горизонтали", "Смещение значка по вертикали", "Рейдовый череп", "Красный крест", "Зелёная галочка", "Череп босса", "Солнечные очки", "Нет", "Сплошная", "Текстура полосы здоровья", "Текстура рейдовой полосы", "Диагональные полосы", "Пунктир", "Сплошной", "Мелкие точки (1px)", "Точки (2px)", "Короткие штрихи (4px)", "Штрихи (8px)", "Длинные штрихи (16px)", "Справа от полосы здоровья", "Слева от полосы здоровья", "Над полосой здоровья", "Один цвет (цвет заливки)", "По школе магии", "Свой цвет для каждого DoT", "Никогда (оценивать сразу)", "Если не уверен", "Всегда (только реальные тики)" },
    koKR = { "지속 피해", "남은 지속 피해 표시", "내 지속 피해가 걸린 모든 적 이름표에 앞으로 줄 피해를 표시합니다. 생명력이 표시 안에서 끝나면 지속 피해로 죽습니다.", "첫 틱 대기", "지속 피해 색상", "채우기 스타일", "채우기 색상", "채우기 불투명도", "외곽선", "점선 길이", "외곽선 두께", "외곽선 색상", "외곽선 불투명도", "학습한 틱 크기 초기화", "처치 아이콘 표시", "지속 피해로 죽을 때 이름표 옆에 아이콘을 표시합니다.", "처치 아이콘", "처치 아이콘 크기", "처치 아이콘 위치", "아이콘 가로 오프셋", "아이콘 세로 오프셋", "공격대 해골", "빨간 X", "초록 체크", "우두머리 해골", "선글라스", "없음", "단색", "생명력 바 텍스처", "공격대 바 텍스처", "대각선 줄무늬", "점선", "실선", "가는 점 (1px)", "점 (2px)", "짧은 선 (4px)", "선 (8px)", "긴 선 (16px)", "생명력 바 오른쪽", "생명력 바 왼쪽", "생명력 바 위", "단일 색상 (채우기 색상)", "주문 계열별", "지속 피해마다 다른 색상", "안 함 (즉시 추정)", "불확실할 때", "항상 (실제 틱만)" },
    zhCN = { "持续伤害", "显示待生效的持续伤害", "在每个带有你持续伤害的敌方姓名板上标出它们还将造成的伤害。如果生命值在标记内结束，持续伤害将杀死目标。", "等待首次跳伤", "持续伤害颜色", "填充样式", "填充颜色", "填充不透明度", "轮廓", "虚线长度", "轮廓粗细", "轮廓颜色", "轮廓不透明度", "清除已学习的跳伤", "显示击杀图标", "当你的持续伤害将杀死目标时，在姓名板旁显示图标。", "击杀图标", "击杀图标大小", "击杀图标位置", "图标水平偏移", "图标垂直偏移", "团队骷髅", "红色叉号", "绿色对勾", "首领骷髅", "墨镜", "无", "纯色", "生命条材质", "团队条材质", "斜条纹", "虚线", "实线", "细点 (1px)", "点 (2px)", "短划线 (4px)", "划线 (8px)", "长划线 (16px)", "生命条右侧", "生命条左侧", "生命条上方", "单一颜色（填充颜色）", "按法术类型", "每个持续伤害不同颜色", "从不（立即估算）", "不确定时", "总是（仅实际跳伤）" },
    zhTW = { "持續傷害", "顯示待生效的持續傷害", "在每個帶有你持續傷害的敵方名條上標出它們還將造成的傷害。如果生命值在標記內結束，持續傷害將殺死目標。", "等待首次跳傷", "持續傷害顏色", "填充樣式", "填充顏色", "填充不透明度", "輪廓", "虛線長度", "輪廓粗細", "輪廓顏色", "輪廓不透明度", "清除已學習的跳傷", "顯示擊殺圖示", "當你的持續傷害將殺死目標時，在名條旁顯示圖示。", "擊殺圖示", "擊殺圖示大小", "擊殺圖示位置", "圖示水平偏移", "圖示垂直偏移", "團隊骷髏", "紅色叉號", "綠色勾號", "首領骷髏", "墨鏡", "無", "純色", "生命條材質", "團隊條材質", "斜條紋", "虛線", "實線", "細點 (1px)", "點 (2px)", "短劃線 (4px)", "劃線 (8px)", "長劃線 (16px)", "生命條右側", "生命條左側", "生命條上方", "單一顏色（填充顏色）", "按法術類型", "每個持續傷害不同顏色", "從不（立即估算）", "不確定時", "總是（僅實際跳傷）" },
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
