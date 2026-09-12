local _, ns = ...

local locales = ns and ns.Locales
if type(locales) ~= "table" then
    return
end

local KEYS = {
    "Objective Tracker",
    "Objective Tracker Skin settings.",
    "Live Preview",
    "Campaign",
    "The Voidspire",
    "- 0/1 Enter the Voidspire Raid\n  Story Mode (Optional)",
    "Enter the Voidspire Raid",
    "- 0/1 Voidspire Raid completed",
    "Quests",
    "Late Night Training: Week 1 of 3",
    "- 0/2 Battlegrounds won",
    "Slayer's Rise",
    "Ready for turn-in",
    "General",
    "Enable Objective Tracker Skin",
    "Color",
    "Objective Tracker Color",
    "Accent (Default)",
    "Custom Color",
    "Objective Tracker Custom Color",
    "Visibility",
    "Hide in Combat",
    "Hide in Arena",
    "Hide in Dungeon",
    "Hide in Raid",
    "Typography",
    "Quest Title Font",
    "Quest Title Size",
    "Font Outline",
    "None",
    "Outline",
    "Thick Outline",
    "Background & Fade",
    "Solid Background",
    "Opaque black background with an accent-colored top border.",
    "Background Alpha",
    "Fade Delay (Seconds)",
    "Set to 0 to disable fading.",
    "Restore Defaults",
}

local function ApplyValues(localeId, values)
    local locale = locales[localeId]
    if type(locale) ~= "table" or type(values) ~= "table" or #values ~= #KEYS then
        return
    end
    for index, key in ipairs(KEYS) do
        locale[key] = values[index]
    end
end

if type(locales.enUS) == "table" then
    for _, key in ipairs(KEYS) do
        locales.enUS[key] = key
    end
end

ApplyValues("esES", {
    "Seguimiento de objetivos", "Ajustes de apariencia del seguimiento de objetivos.", "Vista previa",
    "Campaña", "La Aguja del Vacío", "- 0/1 Entra en la banda de la Aguja del Vacío\n  Modo historia (opcional)",
    "Entra en la banda de la Aguja del Vacío", "- 0/1 Banda de la Aguja del Vacío completada",
    "Misiones", "Entrenamiento nocturno: semana 1 de 3", "- 0/2 Campos de batalla ganados", "Ascenso del Verdugo", "Lista para entregar",
    "General", "Activar apariencia del seguimiento de objetivos", "Color", "Color del seguimiento de objetivos",
    "Acento (predeterminado)", "Color personalizado", "Color personalizado del seguimiento de objetivos",
    "Visibilidad", "Ocultar en combate", "Ocultar en arena", "Ocultar en mazmorra", "Ocultar en banda",
    "Tipografía", "Fuente del título de misión", "Tamaño del título de misión", "Contorno de fuente",
    "Ninguno", "Contorno", "Contorno grueso", "Fondo y desvanecimiento", "Fondo sólido",
    "Fondo negro opaco con un borde superior del color de acento.", "Opacidad del fondo", "Retardo del desvanecimiento (segundos)",
    "Ponlo en 0 para desactivar el desvanecimiento.", "Restaurar valores predeterminados",
})

ApplyValues("frFR", {
    "Suivi des objectifs", "Réglages d'apparence du suivi des objectifs.", "Aperçu en direct",
    "Campagne", "La Flèche du Vide", "- 0/1 Entrer dans le raid de la Flèche du Vide\n  Mode histoire (facultatif)",
    "Entrer dans le raid de la Flèche du Vide", "- 0/1 Raid de la Flèche du Vide terminé",
    "Quêtes", "Entraînement nocturne : semaine 1 sur 3", "- 0/2 Champs de bataille gagnés", "Ascension du Pourfendeur", "Prêt à rendre",
    "Général", "Activer l'apparence du suivi des objectifs", "Couleur", "Couleur du suivi des objectifs",
    "Accentuation (par défaut)", "Couleur personnalisée", "Couleur personnalisée du suivi des objectifs",
    "Visibilité", "Masquer en combat", "Masquer en arène", "Masquer en donjon", "Masquer en raid",
    "Typographie", "Police du titre de quête", "Taille du titre de quête", "Contour de police",
    "Aucun", "Contour", "Contour épais", "Arrière-plan et fondu", "Arrière-plan uni",
    "Arrière-plan noir opaque avec une bordure supérieure de la couleur d'accentuation.", "Opacité de l'arrière-plan", "Délai du fondu (secondes)",
    "Réglez sur 0 pour désactiver le fondu.", "Rétablir les valeurs par défaut",
})

ApplyValues("deDE", {
    "Zielverfolgung", "Darstellungseinstellungen der Zielverfolgung.", "Live-Vorschau",
    "Kampagne", "Der Leerenturm", "- 0/1 Betritt den Schlachtzug im Leerenturm\n  Storymodus (optional)",
    "Betritt den Schlachtzug im Leerenturm", "- 0/1 Schlachtzug im Leerenturm abgeschlossen",
    "Quests", "Spätes Training: Woche 1 von 3", "- 0/2 Schlachtfelder gewonnen", "Aufstieg des Bezwingers", "Bereit zur Abgabe",
    "Allgemein", "Darstellung der Zielverfolgung aktivieren", "Farbe", "Farbe der Zielverfolgung",
    "Akzent (Standard)", "Benutzerdefinierte Farbe", "Benutzerdefinierte Farbe der Zielverfolgung",
    "Sichtbarkeit", "Im Kampf ausblenden", "In der Arena ausblenden", "Im Dungeon ausblenden", "Im Schlachtzug ausblenden",
    "Typografie", "Schriftart des Questtitels", "Größe des Questtitels", "Schriftkontur",
    "Keine", "Kontur", "Dicke Kontur", "Hintergrund & Ausblenden", "Einfarbiger Hintergrund",
    "Undurchsichtiger schwarzer Hintergrund mit einer oberen Umrandung in Akzentfarbe.", "Hintergrunddeckkraft", "Ausblendverzögerung (Sekunden)",
    "Auf 0 setzen, um das Ausblenden zu deaktivieren.", "Standardeinstellungen wiederherstellen",
})

ApplyValues("itIT", {
    "Tracciamento obiettivi", "Impostazioni dell'aspetto del tracciamento obiettivi.", "Anteprima dal vivo",
    "Campagna", "La Guglia del Vuoto", "- 0/1 Entra nell'incursione della Guglia del Vuoto\n  Modalità storia (facoltativa)",
    "Entra nell'incursione della Guglia del Vuoto", "- 0/1 Incursione della Guglia del Vuoto completata",
    "Missioni", "Allenamento notturno: settimana 1 di 3", "- 0/2 Campi di battaglia vinti", "Ascesa dell'Uccisore", "Pronto per la consegna",
    "Generale", "Attiva l'aspetto del tracciamento obiettivi", "Colore", "Colore del tracciamento obiettivi",
    "Risalto (predefinito)", "Colore personalizzato", "Colore personalizzato del tracciamento obiettivi",
    "Visibilità", "Nascondi in combattimento", "Nascondi in arena", "Nascondi nelle spedizioni", "Nascondi nelle incursioni",
    "Tipografia", "Carattere del titolo missione", "Dimensione del titolo missione", "Contorno del carattere",
    "Nessuno", "Contorno", "Contorno spesso", "Sfondo e dissolvenza", "Sfondo pieno",
    "Sfondo nero opaco con bordo superiore del colore in risalto.", "Opacità dello sfondo", "Ritardo dissolvenza (secondi)",
    "Imposta su 0 per disattivare la dissolvenza.", "Ripristina valori predefiniti",
})

ApplyValues("ptBR", {
    "Rastreador de objetivos", "Configurações de aparência do rastreador de objetivos.", "Prévia em tempo real",
    "Campanha", "A Torre do Caos", "- 0/1 Entre na raide da Torre do Caos\n  Modo história (opcional)",
    "Entre na raide da Torre do Caos", "- 0/1 Raide da Torre do Caos concluída",
    "Missões", "Treinamento noturno: semana 1 de 3", "- 0/2 Campos de batalha vencidos", "Ascensão do Matador", "Pronto para entregar",
    "Geral", "Ativar aparência do rastreador de objetivos", "Cor", "Cor do rastreador de objetivos",
    "Destaque (padrão)", "Cor personalizada", "Cor personalizada do rastreador de objetivos",
    "Visibilidade", "Ocultar em combate", "Ocultar na arena", "Ocultar em masmorra", "Ocultar em raide",
    "Tipografia", "Fonte do título da missão", "Tamanho do título da missão", "Contorno da fonte",
    "Nenhum", "Contorno", "Contorno grosso", "Fundo e desvanecimento", "Fundo sólido",
    "Fundo preto opaco com uma borda superior na cor de destaque.", "Opacidade do fundo", "Atraso do desvanecimento (segundos)",
    "Defina como 0 para desativar o desvanecimento.", "Restaurar padrões",
})

ApplyValues("ruRU", {
    "Отслеживание целей", "Настройки оформления отслеживания целей.", "Предпросмотр",
    "Кампания", "Шпиль Бездны", "- 0/1 Войдите в рейд Шпиля Бездны\n  Сюжетный режим (необязательно)",
    "Войдите в рейд Шпиля Бездны", "- 0/1 Рейд Шпиля Бездны завершён",
    "Задания", "Поздняя тренировка: неделя 1 из 3", "- 0/2 Поля боя выиграны", "Восхождение Истребителя", "Можно сдать",
    "Общие", "Включить оформление отслеживания целей", "Цвет", "Цвет отслеживания целей",
    "Акцент (по умолчанию)", "Пользовательский цвет", "Пользовательский цвет отслеживания целей",
    "Видимость", "Скрывать в бою", "Скрывать на арене", "Скрывать в подземелье", "Скрывать в рейде",
    "Типографика", "Шрифт названия задания", "Размер названия задания", "Контур шрифта",
    "Нет", "Контур", "Толстый контур", "Фон и затухание", "Сплошной фон",
    "Непрозрачный чёрный фон с верхней границей акцентного цвета.", "Прозрачность фона", "Задержка затухания (секунды)",
    "Установите 0, чтобы отключить затухание.", "Восстановить настройки по умолчанию",
})

ApplyValues("koKR", {
    "목표 추적기", "목표 추적기 외형 설정입니다.", "실시간 미리보기",
    "대장정", "공허의 첨탑", "- 0/1 공허의 첨탑 공격대 입장\n  이야기 모드 (선택 사항)",
    "공허의 첨탑 공격대 입장", "- 0/1 공허의 첨탑 공격대 완료",
    "퀘스트", "심야 훈련: 3주 중 1주", "- 0/2 전장 승리", "학살자의 오름길", "완료 가능",
    "일반", "목표 추적기 외형 활성화", "색상", "목표 추적기 색상",
    "강조 (기본값)", "사용자 지정 색상", "목표 추적기 사용자 지정 색상",
    "표시 여부", "전투 중 숨기기", "투기장에서 숨기기", "던전에서 숨기기", "공격대에서 숨기기",
    "글꼴 설정", "퀘스트 제목 글꼴", "퀘스트 제목 크기", "글꼴 외곽선",
    "없음", "외곽선", "두꺼운 외곽선", "배경 및 페이드", "단색 배경",
    "강조 색상의 위쪽 테두리가 있는 불투명 검은색 배경입니다.", "배경 투명도", "페이드 지연 시간 (초)",
    "페이드를 비활성화하려면 0으로 설정하세요.", "기본값 복원",
})

ApplyValues("zhCN", {
    "任务追踪", "任务追踪外观设置。", "实时预览",
    "战役", "虚空尖塔", "- 0/1 进入虚空尖塔团队副本\n  剧情模式（可选）",
    "进入虚空尖塔团队副本", "- 0/1 已完成虚空尖塔团队副本",
    "任务", "深夜训练：第1周，共3周", "- 0/2 赢得战场", "屠戮者高地", "可以交付",
    "常规", "启用任务追踪外观", "颜色", "任务追踪颜色",
    "强调色（默认）", "自定义颜色", "任务追踪自定义颜色",
    "可见性", "战斗中隐藏", "竞技场中隐藏", "地下城中隐藏", "团队副本中隐藏",
    "字体排版", "任务标题字体", "任务标题大小", "字体描边",
    "无", "描边", "粗描边", "背景与淡出", "纯色背景",
    "带强调色顶部边框的不透明黑色背景。", "背景透明度", "淡出延迟（秒）",
    "设为0可禁用淡出。", "恢复默认值",
})

ApplyValues("zhTW", {
    "任務追蹤", "任務追蹤外觀設定。", "即時預覽",
    "戰役", "虛空尖塔", "- 0/1 進入虛空尖塔團隊副本\n  劇情模式（選用）",
    "進入虛空尖塔團隊副本", "- 0/1 已完成虛空尖塔團隊副本",
    "任務", "深夜訓練：第1週，共3週", "- 0/2 贏得戰場", "屠戮者高地", "可以交付",
    "一般", "啟用任務追蹤外觀", "顏色", "任務追蹤顏色",
    "強調色（預設）", "自訂顏色", "任務追蹤自訂顏色",
    "可見性", "戰鬥中隱藏", "競技場中隱藏", "地城中隱藏", "團隊副本中隱藏",
    "字型排版", "任務標題字型", "任務標題大小", "字型外框",
    "無", "外框", "粗外框", "背景與淡出", "純色背景",
    "帶有強調色頂部邊框的不透明黑色背景。", "背景透明度", "淡出延遲（秒）",
    "設為0可停用淡出。", "恢復預設值",
})
