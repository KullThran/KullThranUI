-- Chat resting fade and Damage Meter window controls / preset picker. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Resting Opacity",
    "Fade Old Messages",
    "Show Window Buttons",
    "Display Mode",
    "Damage Meter Options",
    "Left-click: Current / Overall",
    "Right-click: combat history",
    "Reset all Damage Meter data?",
    "What should the main window show?",
    "Keep Damage Done",
}

local values = {
    esES = {
        "Opacidad en reposo", "Desvanecer mensajes antiguos", "Mostrar botones de la ventana", "Tipo de datos",
        "Opciones del medidor de daño", "Clic izquierdo: actual / total", "Clic derecho: historial de combates",
        "¿Reiniciar todos los datos del medidor de daño?", "¿Qué debe mostrar la ventana principal?",
        "Mantener daño infligido",
    },
    deDE = {
        "Ruhe-Deckkraft", "Alte Nachrichten ausblenden", "Fensterschaltflächen anzeigen", "Anzeigemodus",
        "Schadensmesser-Optionen", "Linksklick: Aktuell / Gesamt", "Rechtsklick: Kampfverlauf",
        "Alle Schadensmesser-Daten zurücksetzen?", "Was soll das Hauptfenster anzeigen?",
        "Verursachten Schaden behalten",
    },
    frFR = {
        "Opacité au repos", "Estomper les anciens messages", "Afficher les boutons de la fenêtre", "Mode d'affichage",
        "Options du compteur de dégâts", "Clic gauche : actuel / total", "Clic droit : historique des combats",
        "Réinitialiser toutes les données du compteur de dégâts ?", "Que doit afficher la fenêtre principale ?",
        "Garder les dégâts infligés",
    },
    itIT = {
        "Opacità a riposo", "Dissolvi i messaggi vecchi", "Mostra i pulsanti della finestra", "Modalità di visualizzazione",
        "Opzioni del misuratore di danni", "Clic sinistro: attuale / totale", "Clic destro: cronologia dei combattimenti",
        "Azzerare tutti i dati del misuratore di danni?", "Cosa deve mostrare la finestra principale?",
        "Mantieni danni inflitti",
    },
    ptBR = {
        "Opacidade em repouso", "Esmaecer mensagens antigas", "Mostrar botões da janela", "Modo de exibição",
        "Opções do medidor de dano", "Clique esquerdo: atual / total", "Clique direito: histórico de combates",
        "Redefinir todos os dados do medidor de dano?", "O que a janela principal deve mostrar?",
        "Manter dano causado",
    },
    ruRU = {
        "Прозрачность в покое", "Скрывать старые сообщения", "Показывать кнопки окна", "Режим отображения",
        "Настройки измерителя урона", "ЛКМ: текущий / общий", "ПКМ: история боёв",
        "Сбросить все данные измерителя урона?", "Что показывать в главном окне?",
        "Оставить нанесённый урон",
    },
    koKR = {
        "대기 시 불투명도", "오래된 메시지 흐리게", "창 버튼 표시", "표시 모드",
        "피해량 측정기 설정", "왼쪽 클릭: 현재 / 전체", "오른쪽 클릭: 전투 기록",
        "피해량 측정기 데이터를 모두 초기화할까요?", "기본 창에 무엇을 표시할까요?",
        "가한 피해 유지",
    },
    zhCN = {
        "静止透明度", "淡出旧消息", "显示窗口按钮", "显示模式",
        "伤害统计设置", "左键：当前 / 总计", "右键：战斗记录",
        "重置所有伤害统计数据？", "主窗口要显示什么？",
        "保留造成伤害",
    },
    zhTW = {
        "靜止透明度", "淡出舊訊息", "顯示視窗按鈕", "顯示模式",
        "傷害統計設定", "左鍵：目前 / 總計", "右鍵：戰鬥記錄",
        "要重置所有傷害統計資料嗎？", "主視窗要顯示什麼？",
        "保留造成傷害",
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
