-- One-time data reset window (Modules/VersionReset.lua), for every supported
-- language. The sign texture has no text: everything on it comes from here.
-- Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Under construction!",
    "Since KullThranUI %s, a fresh start is required",
    "Since KullThranUI %s, a fresh start is recommended",
    "Your settings come from an earlier version: all saved KullThranUI settings and profiles will be deleted, the UI will reload and the installer will open again.",
    "Your settings come from an earlier version. Resetting deletes all saved KullThranUI settings and profiles, reloads the UI and opens the installer again. You will only be asked once.",
    "Sorry for the inconvenience",
    "Reset and reload",
    "Keep my settings",
}

local values = {
    esES = {
        "¡En obras!",
        "Desde KullThranUI %s hay que empezar de cero",
        "Desde KullThranUI %s se recomienda empezar de cero",
        "Tus ajustes vienen de una versión anterior: se borrarán todos los ajustes y perfiles guardados de KullThranUI, la interfaz se recargará y el asistente volverá a abrirse.",
        "Tus ajustes vienen de una versión anterior. Restablecer borra todos los ajustes y perfiles guardados de KullThranUI, recarga la interfaz y vuelve a abrir el asistente. Solo se te preguntará una vez.",
        "Disculpa las molestias",
        "Restablecer y recargar",
        "Conservar mis ajustes",
    },
    deDE = {
        "Baustelle!",
        "Seit KullThranUI %s ist ein Neuanfang nötig",
        "Seit KullThranUI %s wird ein Neuanfang empfohlen",
        "Deine Einstellungen stammen aus einer früheren Version: Alle gespeicherten Einstellungen und Profile von KullThranUI werden gelöscht, die Benutzeroberfläche wird neu geladen und der Installationsassistent öffnet sich erneut.",
        "Deine Einstellungen stammen aus einer früheren Version. Das Zurücksetzen löscht alle gespeicherten Einstellungen und Profile von KullThranUI, lädt die Benutzeroberfläche neu und öffnet den Installationsassistenten erneut. Du wirst nur einmal gefragt.",
        "Entschuldige die Unannehmlichkeiten",
        "Zurücksetzen und neu laden",
        "Einstellungen behalten",
    },
    frFR = {
        "Travaux en cours !",
        "Depuis KullThranUI %s, il faut repartir de zéro",
        "Depuis KullThranUI %s, il est conseillé de repartir de zéro",
        "Tes réglages viennent d’une version antérieure : tous les réglages et profils enregistrés de KullThranUI seront supprimés, l’interface sera rechargée et l’assistant s’ouvrira à nouveau.",
        "Tes réglages viennent d’une version antérieure. La réinitialisation supprime tous les réglages et profils enregistrés de KullThranUI, recharge l’interface et rouvre l’assistant. Cette question ne sera posée qu’une fois.",
        "Désolé pour la gêne occasionnée",
        "Réinitialiser et recharger",
        "Garder mes réglages",
    },
    itIT = {
        "Lavori in corso!",
        "Da KullThranUI %s serve un nuovo inizio",
        "Da KullThranUI %s è consigliato un nuovo inizio",
        "Le tue impostazioni provengono da una versione precedente: tutte le impostazioni e i profili salvati di KullThranUI verranno eliminati, l’interfaccia verrà ricaricata e il programma di installazione si riaprirà.",
        "Le tue impostazioni provengono da una versione precedente. Il ripristino elimina tutte le impostazioni e i profili salvati di KullThranUI, ricarica l’interfaccia e riapre il programma di installazione. Ti verrà chiesto una sola volta.",
        "Scusa per il disagio",
        "Ripristina e ricarica",
        "Mantieni le mie impostazioni",
    },
    ptBR = {
        "Em obras!",
        "Desde o KullThranUI %s é preciso começar do zero",
        "Desde o KullThranUI %s é recomendado começar do zero",
        "Suas configurações vêm de uma versão anterior: todas as configurações e perfis salvos do KullThranUI serão apagados, a interface será recarregada e o instalador abrirá de novo.",
        "Suas configurações vêm de uma versão anterior. Redefinir apaga todas as configurações e perfis salvos do KullThranUI, recarrega a interface e abre o instalador de novo. Você só será perguntado uma vez.",
        "Desculpe o transtorno",
        "Redefinir e recarregar",
        "Manter minhas configurações",
    },
    ruRU = {
        "Идут работы!",
        "Начиная с KullThranUI %s нужно начать с чистого листа",
        "Начиная с KullThranUI %s рекомендуется начать с чистого листа",
        "Ваши настройки остались от более ранней версии: все сохраненные настройки и профили KullThranUI будут удалены, интерфейс перезагрузится, а установщик откроется снова.",
        "Ваши настройки остались от более ранней версии. Сброс удалит все сохраненные настройки и профили KullThranUI, перезагрузит интерфейс и снова откроет установщик. Этот вопрос задается только один раз.",
        "Извините за неудобства",
        "Сбросить и перезагрузить",
        "Оставить мои настройки",
    },
    koKR = {
        "공사 중!",
        "KullThranUI %s부터는 처음부터 다시 시작해야 합니다",
        "KullThranUI %s부터는 처음부터 다시 시작할 것을 권장합니다",
        "이전 버전의 설정이 남아 있습니다. 저장된 모든 KullThranUI 설정과 프로필이 삭제되고 UI가 새로고침되며 설치 프로그램이 다시 열립니다.",
        "이전 버전의 설정이 남아 있습니다. 초기화하면 저장된 모든 KullThranUI 설정과 프로필이 삭제되고 UI가 새로고침되며 설치 프로그램이 다시 열립니다. 이 질문은 한 번만 표시됩니다.",
        "불편을 드려 죄송합니다",
        "초기화 후 새로고침",
        "내 설정 유지",
    },
    zhCN = {
        "施工中！",
        "自 KullThranUI %s 起需要重新开始",
        "自 KullThranUI %s 起建议重新开始",
        "你的设置来自旧版本：所有已保存的 KullThranUI 设置和配置文件都将被删除，界面会重载，安装向导会再次打开。",
        "你的设置来自旧版本。重置会删除所有已保存的 KullThranUI 设置和配置文件，重载界面并再次打开安装向导。此问题只会询问一次。",
        "抱歉给你带来不便",
        "重置并重载",
        "保留我的设置",
    },
    zhTW = {
        "施工中！",
        "自 KullThranUI %s 起需要重新開始",
        "自 KullThranUI %s 起建議重新開始",
        "你的設定來自舊版本：所有已儲存的 KullThranUI 設定與設定檔都將被刪除，介面會重新載入，安裝精靈會再次開啟。",
        "你的設定來自舊版本。重置會刪除所有已儲存的 KullThranUI 設定與設定檔，重新載入介面並再次開啟安裝精靈。此問題只會詢問一次。",
        "抱歉造成不便",
        "重置並重新載入",
        "保留我的設定",
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
