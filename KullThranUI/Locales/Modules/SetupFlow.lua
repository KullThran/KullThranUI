-- Installer single-reload flow and the Compatibility "disable all" action,
-- for every supported language. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Disable All & Reload",
    "Disable All Incompatible (%s)",
    "Disable every incompatible addon listed below and reload the UI now?",
    "%d change(s) pending: applied with one reload when you finish.",
    "Setup complete. Reload now to apply your changes?",
    "Some of your installer choices need a reload to take effect. Reload now?",
    "Keep my current scale",
    "Pending changes",
    "Character Sheet",
    "Friend list replacements rebuild the same Blizzard friends frame that KUI restyles and groups.",
    "Teleport menus add a second set of dungeon and hearthstone buttons next to the KUI Teleport Menu.",
    "Character sheet replacements resize and rebuild the character frame and its stat panel, which KUI Armory owns.",
}

local values = {
    esES = {
        "Desactivar todo y recargar",
        "Desactivar incompatibles (%s)",
        "¿Desactivar todos los addons incompatibles de la lista y recargar la interfaz ahora?",
        "%d cambio(s) pendiente(s): se aplicarán con una sola recarga al terminar.",
        "Configuración completada. ¿Recargar ahora para aplicar los cambios?",
        "Algunas opciones del instalador necesitan recargar para aplicarse. ¿Recargar ahora?",
        "Mantener mi escala actual",
        "Cambios pendientes",
        "Hoja de personaje",
        "Los reemplazos de la lista de amigos reconstruyen el mismo marco de amigos de Blizzard que KUI reestiliza y agrupa.",
        "Los menús de teletransporte añaden un segundo juego de botones de mazmorras y piedra de hogar junto al Menú de teletransporte de KUI.",
        "Los reemplazos de la hoja de personaje redimensionan y reconstruyen el marco del personaje y su panel de estadísticas, que gestiona KUI Armory.",
    },
    deDE = {
        "Alle deaktivieren & neu laden",
        "Inkompatible deaktivieren (%s)",
        "Alle unten aufgeführten inkompatiblen Addons deaktivieren und die Oberfläche jetzt neu laden?",
        "%d Änderung(en) ausstehend: werden am Ende mit einem einzigen Neuladen übernommen.",
        "Einrichtung abgeschlossen. Jetzt neu laden, um die Änderungen zu übernehmen?",
        "Einige Auswahlen im Installer erfordern ein Neuladen. Jetzt neu laden?",
        "Aktuelle Skalierung behalten",
        "Ausstehende Änderungen",
        "Charakterbogen",
        "Freundeslisten-Ersatz baut dasselbe Blizzard-Freundesfenster neu auf, das KUI umgestaltet und gruppiert.",
        "Teleport-Menüs fügen neben dem KUI-Teleport-Menü eine zweite Reihe von Dungeon- und Ruhestein-Knöpfen hinzu.",
        "Charakterbogen-Ersatz ändert Größe und Aufbau des Charakterfensters samt Werteleiste, die KUI Armory verwaltet.",
    },
    frFR = {
        "Tout désactiver et recharger",
        "Désactiver les incompatibles (%s)",
        "Désactiver tous les addons incompatibles listés ci-dessous et recharger l’interface maintenant ?",
        "%d modification(s) en attente : appliquée(s) avec un seul rechargement à la fin.",
        "Configuration terminée. Recharger maintenant pour appliquer vos changements ?",
        "Certains choix de l’installateur nécessitent un rechargement. Recharger maintenant ?",
        "Garder mon échelle actuelle",
        "Modifications en attente",
        "Fiche de personnage",
        "Les remplaçants de la liste d’amis reconstruisent la même fenêtre d’amis Blizzard que KUI restyle et regroupe.",
        "Les menus de téléportation ajoutent une seconde série de boutons de donjons et de pierre de foyer à côté du menu de téléportation KUI.",
        "Les remplaçants de la fiche de personnage redimensionnent et reconstruisent la fenêtre du personnage et son panneau de statistiques, gérés par KUI Armory.",
    },
    itIT = {
        "Disattiva tutto e ricarica",
        "Disattiva incompatibili (%s)",
        "Disattivare tutti gli addon incompatibili elencati qui sotto e ricaricare l’interfaccia ora?",
        "%d modifica/e in sospeso: applicate con un solo ricaricamento alla fine.",
        "Configurazione completata. Ricaricare ora per applicare le modifiche?",
        "Alcune scelte dell’installer richiedono un ricaricamento. Ricaricare ora?",
        "Mantieni la scala attuale",
        "Modifiche in sospeso",
        "Scheda del personaggio",
        "I sostituti della lista amici ricostruiscono la stessa finestra amici di Blizzard che KUI restyla e raggruppa.",
        "I menu di teletrasporto aggiungono una seconda serie di pulsanti per spedizioni e pietra del ritorno accanto al menu teletrasporto di KUI.",
        "I sostituti della scheda personaggio ridimensionano e ricostruiscono la finestra del personaggio e il pannello statistiche, gestiti da KUI Armory.",
    },
    ptBR = {
        "Desativar tudo e recarregar",
        "Desativar incompatíveis (%s)",
        "Desativar todos os addons incompatíveis listados abaixo e recarregar a interface agora?",
        "%d alteração(ões) pendente(s): aplicadas com um único recarregamento ao concluir.",
        "Configuração concluída. Recarregar agora para aplicar as alterações?",
        "Algumas escolhas do instalador precisam de recarregamento. Recarregar agora?",
        "Manter minha escala atual",
        "Alterações pendentes",
        "Ficha do personagem",
        "Substitutos da lista de amigos reconstroem a mesma janela de amigos da Blizzard que o KUI reestiliza e agrupa.",
        "Menus de teleporte adicionam um segundo conjunto de botões de masmorras e pedra de regresso ao lado do Menu de Teleporte do KUI.",
        "Substitutos da ficha do personagem redimensionam e reconstroem a janela do personagem e o painel de atributos, gerenciados pelo KUI Armory.",
    },
    ruRU = {
        "Отключить все и перезагрузить",
        "Отключить несовместимые (%s)",
        "Отключить все несовместимые аддоны из списка ниже и перезагрузить интерфейс сейчас?",
        "Ожидающих изменений: %d — применятся одной перезагрузкой в конце.",
        "Настройка завершена. Перезагрузить сейчас, чтобы применить изменения?",
        "Некоторые параметры из установщика требуют перезагрузки. Перезагрузить сейчас?",
        "Оставить текущий масштаб",
        "Ожидающие изменения",
        "Окно персонажа",
        "Замены списка друзей перестраивают то же окно друзей Blizzard, которое KUI оформляет и группирует.",
        "Меню телепортов добавляют второй набор кнопок подземелий и камня возвращения рядом с меню телепортов KUI.",
        "Замены окна персонажа меняют размер и перестраивают окно персонажа и панель характеристик, которыми управляет KUI Armory.",
    },
    koKR = {
        "모두 끄고 다시 불러오기",
        "비호환 애드온 모두 끄기 (%s)",
        "아래 목록의 비호환 애드온을 모두 끄고 지금 UI를 다시 불러올까요?",
        "대기 중인 변경 %d개: 완료 시 한 번의 재시작으로 적용됩니다.",
        "설정 완료. 변경 사항을 적용하려면 지금 다시 불러올까요?",
        "설치 도우미의 일부 설정은 다시 불러와야 적용됩니다. 지금 다시 불러올까요?",
        "현재 배율 유지",
        "대기 중인 변경",
        "캐릭터 정보창",
        "친구 목록 대체 애드온은 KUI가 꾸미고 묶는 블리자드 친구 창을 다시 만듭니다.",
        "순간이동 메뉴 애드온은 KUI 순간이동 메뉴 옆에 던전·귀환석 버튼을 하나 더 추가합니다.",
        "캐릭터 정보창 대체 애드온은 KUI Armory가 관리하는 캐릭터 창과 능력치 패널의 크기와 구성을 바꿉니다.",
    },
    zhCN = {
        "全部禁用并重载",
        "禁用所有不兼容插件 (%s)",
        "禁用下方列出的所有不兼容插件并立即重载界面？",
        "%d 项更改待应用：完成时一次重载即可生效。",
        "设置完成。立即重载以应用更改？",
        "安装向导中的部分选择需要重载才能生效。立即重载？",
        "保持当前缩放",
        "待应用的更改",
        "角色面板",
        "好友列表替代插件会重建 KUI 美化并分组的同一个暴雪好友框体。",
        "传送菜单插件会在 KUI 传送菜单旁再加一组地下城和炉石按钮。",
        "角色面板替代插件会调整并重建由 KUI Armory 管理的角色框体及属性面板。",
    },
    zhTW = {
        "全部停用並重新載入",
        "停用所有不相容插件 (%s)",
        "停用下方列出的所有不相容插件並立即重新載入介面？",
        "%d 項變更待套用：完成時一次重新載入即可生效。",
        "設定完成。立即重新載入以套用變更？",
        "安裝精靈中的部分選擇需要重新載入才能生效。立即重新載入？",
        "保持目前縮放",
        "待套用的變更",
        "角色面板",
        "好友名單替代插件會重建 KUI 美化並分組的同一個暴雪好友框架。",
        "傳送選單插件會在 KUI 傳送選單旁再加一組地城與爐石按鈕。",
        "角色面板替代插件會調整並重建由 KUI Armory 管理的角色框架與屬性面板。",
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
