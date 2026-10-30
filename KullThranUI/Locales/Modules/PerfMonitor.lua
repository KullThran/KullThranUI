-- Perf Monitor (/kperf) strings for every supported language. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Perf Monitor",
    "Modules",
    "vs Snapshot",
    "Module",
    "Now",
    "Avg",
    "Peak",
    "Mem",
    "Delta",
    "Reset",
    "Freeze",
    "Resume",
    "Snapshot",
    "Base",
    "Mem now/base",
    "own",
    "samples",
    "frozen",
    "legacy mode",
    "Counters reset",
    "Snapshot saved: %s",
    "Comparison base: %s",
    "Snapshots: %s",
    "none",
    "Addon profiler: %s",
    "Usage: /kperf [toggle|reset|report|csv|snap <name>|cmp <name>|on|off]",
}

local values = {
    esES = {
        "Monitor de rendimiento", "Módulos", "vs Snapshot", "Módulo", "Ahora", "Media", "Pico", "Mem", "Dif",
        "Reiniciar", "Congelar", "Reanudar", "Snapshot", "Base", "Mem act./base", "propio", "muestras",
        "congelado", "modo heredado", "Contadores reiniciados", "Snapshot guardado: %s",
        "Base de comparación: %s", "Snapshots: %s", "ninguno", "Profiler de addons: %s",
        "Uso: /kperf [toggle|reset|report|csv|snap <nombre>|cmp <nombre>|on|off]",
    },
    deDE = {
        "Leistungsmonitor", "Module", "vs Snapshot", "Modul", "Jetzt", "Ø", "Spitze", "Mem", "Diff",
        "Zurücksetzen", "Einfrieren", "Fortsetzen", "Snapshot", "Basis", "Mem akt./Basis", "eigen", "Messungen",
        "eingefroren", "Legacy-Modus", "Zähler zurückgesetzt", "Snapshot gespeichert: %s",
        "Vergleichsbasis: %s", "Snapshots: %s", "keine", "Addon-Profiler: %s",
        "Verwendung: /kperf [toggle|reset|report|csv|snap <Name>|cmp <Name>|on|off]",
    },
    frFR = {
        "Moniteur de performance", "Modules", "vs Snapshot", "Module", "Actuel", "Moy.", "Pic", "Mém", "Diff",
        "Réinitialiser", "Figer", "Reprendre", "Snapshot", "Base", "Mém act./base", "propre", "échantillons",
        "figé", "mode hérité", "Compteurs réinitialisés", "Snapshot enregistré : %s",
        "Base de comparaison : %s", "Snapshots : %s", "aucun", "Profileur d'addons : %s",
        "Usage : /kperf [toggle|reset|report|csv|snap <nom>|cmp <nom>|on|off]",
    },
    itIT = {
        "Monitor prestazioni", "Moduli", "vs Snapshot", "Modulo", "Ora", "Media", "Picco", "Mem", "Diff",
        "Azzera", "Blocca", "Riprendi", "Snapshot", "Base", "Mem att./base", "proprio", "campioni",
        "bloccato", "modalità legacy", "Contatori azzerati", "Snapshot salvato: %s",
        "Base di confronto: %s", "Snapshot: %s", "nessuno", "Profiler addon: %s",
        "Uso: /kperf [toggle|reset|report|csv|snap <nome>|cmp <nome>|on|off]",
    },
    ptBR = {
        "Monitor de desempenho", "Módulos", "vs Snapshot", "Módulo", "Agora", "Média", "Pico", "Mem", "Dif",
        "Reiniciar", "Congelar", "Retomar", "Snapshot", "Base", "Mem atual/base", "próprio", "amostras",
        "congelado", "modo legado", "Contadores reiniciados", "Snapshot salvo: %s",
        "Base de comparação: %s", "Snapshots: %s", "nenhum", "Profiler de addons: %s",
        "Uso: /kperf [toggle|reset|report|csv|snap <nome>|cmp <nome>|on|off]",
    },
    ruRU = {
        "Монитор производительности", "Модули", "vs снимок", "Модуль", "Сейчас", "Сред.", "Пик", "Пам.", "Разн.",
        "Сбросить", "Заморозить", "Продолжить", "Снимок", "База", "Пам. тек./база", "свой", "замеров",
        "заморожено", "режим совместимости", "Счётчики сброшены", "Снимок сохранён: %s",
        "База сравнения: %s", "Снимки: %s", "нет", "Профайлер аддонов: %s",
        "Использование: /kperf [toggle|reset|report|csv|snap <имя>|cmp <имя>|on|off]",
    },
    koKR = {
        "성능 모니터", "모듈", "스냅샷 비교", "모듈", "현재", "평균", "최대", "메모리", "차이",
        "초기화", "고정", "재개", "스냅샷", "기준", "메모리 현재/기준", "자체", "샘플",
        "고정됨", "레거시 모드", "카운터를 초기화했습니다", "스냅샷 저장됨: %s",
        "비교 기준: %s", "스냅샷: %s", "없음", "애드온 프로파일러: %s",
        "사용법: /kperf [toggle|reset|report|csv|snap <이름>|cmp <이름>|on|off]",
    },
    zhCN = {
        "性能监视器", "模块", "对比快照", "模块", "当前", "平均", "峰值", "内存", "差异",
        "重置", "冻结", "继续", "快照", "基准", "内存 当前/基准", "自身", "样本",
        "已冻结", "兼容模式", "计数器已重置", "快照已保存：%s",
        "对比基准：%s", "快照：%s", "无", "插件分析器：%s",
        "用法：/kperf [toggle|reset|report|csv|snap <名称>|cmp <名称>|on|off]",
    },
    zhTW = {
        "效能監視器", "模組", "對比快照", "模組", "目前", "平均", "峰值", "記憶體", "差異",
        "重置", "凍結", "繼續", "快照", "基準", "記憶體 目前/基準", "自身", "樣本",
        "已凍結", "相容模式", "計數器已重置", "快照已儲存：%s",
        "對比基準：%s", "快照：%s", "無", "插件分析器：%s",
        "用法：/kperf [toggle|reset|report|csv|snap <名稱>|cmp <名稱>|on|off]",
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
