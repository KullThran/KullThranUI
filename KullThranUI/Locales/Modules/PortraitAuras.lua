-- Portrait Auras option page strings for every supported language. Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Portrait Auras",
    "Shows crowd control, defensives and other important auras on the portrait. One icon is shown, the highest priority one: Crowd Control, Disarm, Big Defensive, External Defensive, Important.",
    "Preview on the portraits",
    "Reverse swipe",
    "Show numbers",
    "Font Scale",
    "Units",
    "Disarms",
    "Big Defensives",
    "External Defensives",
    "Important Spells",
    "Disarms only show on enemies. Categories use the flags the game puts on each aura, so they keep working in instances.",
    "Extra crowd control spell IDs",
    "Spell IDs separated by commas. They only show on enemies.",
    "CC Catalog",
    "Enable all",
    "Disable all",
    "Click to switch this spell off.",
    "Click to switch this spell on.",
    "Stuns",
    "Incapacitates",
    "Fears and Disorients",
    "Roots",
    "Silences",
    "Other",
    "Spell IDs",
    "Search spells",
    "Stun",
    "Incapacitate",
    "Fear / Disorient",
    "Charm",
    "Root",
    "Silence",
    "Disarm",
    "No spells match.",
    "Type of crowd control",
}

local values = {
    esES = { "Auras en el retrato", "Muestra control de masas, defensivos y otras auras importantes en el retrato. Se muestra un solo icono, el de mayor prioridad: control de masas, desarme, defensivo grande, defensivo externo, importante.", "Vista previa en los retratos", "Invertir barrido", "Mostrar números", "Escala de fuente", "Unidades", "Desarmes", "Defensivos grandes", "Defensivos externos", "Hechizos importantes", "Los desarmes solo se muestran en enemigos. Las categorías usan las marcas que el juego pone en cada aura, así que siguen funcionando en instancias.", "ID de hechizos extra de control de masas", "IDs de hechizo separados por comas. Solo se muestran en enemigos.", "Catálogo de CC", "Activar todos", "Desactivar todos", "Clic para desactivar este hechizo.", "Clic para activar este hechizo.", "Aturdimientos", "Incapacitaciones", "Miedos y desorientaciones", "Raíces", "Silencios", "Otros", "IDs de hechizo", "Buscar hechizos", "Aturdimiento", "Incapacitación", "Miedo / Desorientación", "Control mental", "Raíz", "Silencio", "Desarme", "Ningún hechizo coincide.", "Tipo de control de masas" },
    deDE = { "Porträt-Auren", "Zeigt Massenkontrolle, Verteidigungsfähigkeiten und andere wichtige Auren auf dem Porträt. Es wird ein Symbol angezeigt, das mit der höchsten Priorität: Massenkontrolle, Entwaffnung, Große Verteidigung, Externe Verteidigung, Wichtig.", "Vorschau auf den Porträts", "Wischeffekt umkehren", "Zahlen anzeigen", "Schriftskalierung", "Einheiten", "Entwaffnungen", "Große Verteidigungen", "Externe Verteidigungen", "Wichtige Zauber", "Entwaffnungen werden nur bei Feinden angezeigt. Die Kategorien nutzen die Markierungen, die das Spiel jeder Aura gibt, und funktionieren daher auch in Instanzen.", "Zusätzliche Zauber-IDs für Massenkontrolle", "Zauber-IDs durch Kommas getrennt. Sie werden nur bei Feinden angezeigt.", "CC-Katalog", "Alle aktivieren", "Alle deaktivieren", "Klicken, um diesen Zauber auszuschalten.", "Klicken, um diesen Zauber einzuschalten.", "Betäubungen", "Handlungsunfähigkeit", "Furcht und Desorientierung", "Wurzeln", "Stille", "Sonstiges", "Zauber-IDs", "Zauber suchen", "Betäubung", "Handlungsunfähigkeit", "Furcht / Desorientierung", "Gedankenkontrolle", "Wurzel", "Stille", "Entwaffnung", "Keine Zauber gefunden.", "Art der Massenkontrolle" },
    frFR = { "Auras du portrait", "Affiche le contrôle des foules, les défensifs et d'autres auras importantes sur le portrait. Une seule icône est affichée, celle de plus haute priorité : contrôle des foules, désarmement, défensif majeur, défensif externe, important.", "Aperçu sur les portraits", "Inverser le balayage", "Afficher les chiffres", "Échelle de la police", "Unités", "Désarmements", "Défensifs majeurs", "Défensifs externes", "Sorts importants", "Les désarmements ne s'affichent que sur les ennemis. Les catégories utilisent les marqueurs que le jeu place sur chaque aura, elles fonctionnent donc en instance.", "ID de sorts de contrôle supplémentaires", "ID de sorts séparés par des virgules. Ils ne s'affichent que sur les ennemis.", "Catalogue de CC", "Tout activer", "Tout désactiver", "Cliquez pour désactiver ce sort.", "Cliquez pour activer ce sort.", "Étourdissements", "Incapacitations", "Peurs et désorientations", "Immobilisations", "Silences", "Autres", "ID de sort", "Rechercher un sort", "Étourdissement", "Incapacitation", "Peur / Désorientation", "Contrôle mental", "Immobilisation", "Silence", "Désarmement", "Aucun sort ne correspond.", "Type de contrôle des foules" },
    itIT = { "Aure del ritratto", "Mostra controllo di massa, difensivi e altre aure importanti sul ritratto. Viene mostrata una sola icona, quella con la priorità più alta: controllo di massa, disarmo, difensivo maggiore, difensivo esterno, importante.", "Anteprima sui ritratti", "Inverti la rotazione", "Mostra i numeri", "Scala del carattere", "Unità", "Disarmi", "Difensivi maggiori", "Difensivi esterni", "Incantesimi importanti", "I disarmi vengono mostrati solo sui nemici. Le categorie usano i contrassegni che il gioco applica a ogni aura, quindi funzionano anche nelle istanze.", "ID incantesimi di controllo aggiuntivi", "ID incantesimo separati da virgole. Vengono mostrati solo sui nemici.", "Catalogo CC", "Attiva tutti", "Disattiva tutti", "Clicca per disattivare questo incantesimo.", "Clicca per attivare questo incantesimo.", "Stordimenti", "Incapacitazioni", "Paure e disorientamenti", "Radici", "Silenzi", "Altri", "ID incantesimo", "Cerca incantesimi", "Stordimento", "Incapacitazione", "Paura / Disorientamento", "Controllo mentale", "Radice", "Silenzio", "Disarmo", "Nessun incantesimo trovato.", "Tipo di controllo di massa" },
    ptBR = { "Auras do retrato", "Mostra controle de grupo, defensivos e outras auras importantes no retrato. Um único ícone é exibido, o de maior prioridade: controle de grupo, desarme, defensivo grande, defensivo externo, importante.", "Pré-visualização nos retratos", "Inverter varredura", "Mostrar números", "Escala da fonte", "Unidades", "Desarmes", "Defensivos grandes", "Defensivos externos", "Feitiços importantes", "Desarmes só aparecem em inimigos. As categorias usam as marcações que o jogo coloca em cada aura, então continuam funcionando em instâncias.", "IDs de feitiços extras de controle de grupo", "IDs de feitiço separados por vírgulas. Só aparecem em inimigos.", "Catálogo de CC", "Ativar todos", "Desativar todos", "Clique para desativar este feitiço.", "Clique para ativar este feitiço.", "Atordoamentos", "Incapacitações", "Medos e desorientações", "Raízes", "Silêncios", "Outros", "IDs de feitiço", "Buscar feitiços", "Atordoamento", "Incapacitação", "Medo / Desorientação", "Controle mental", "Raiz", "Silêncio", "Desarme", "Nenhum feitiço encontrado.", "Tipo de controle de grupo" },
    ruRU = { "Ауры на портрете", "Показывает на портрете контроль, защитные и другие важные ауры. Отображается один значок с наивысшим приоритетом: контроль, обезоруживание, большая защита, внешняя защита, важное.", "Предпросмотр на портретах", "Обратить анимацию", "Показывать числа", "Масштаб шрифта", "Цели", "Обезоруживания", "Большие защитные", "Внешние защитные", "Важные заклинания", "Обезоруживания показываются только у врагов. Категории используют метки, которые игра ставит на каждую ауру, поэтому работают и в подземельях.", "Дополнительные ID заклинаний контроля", "ID заклинаний через запятую. Они показываются только у врагов.", "Каталог контроля", "Включить все", "Выключить все", "Нажмите, чтобы отключить это заклинание.", "Нажмите, чтобы включить это заклинание.", "Оглушения", "Выведение из строя", "Страх и дезориентация", "Обездвиживание", "Немота", "Прочее", "ID заклинаний", "Поиск заклинаний", "Оглушение", "Выведение из строя", "Страх / Дезориентация", "Контроль разума", "Обездвиживание", "Немота", "Обезоруживание", "Заклинания не найдены.", "Тип контроля" },
    koKR = { "초상화 오라", "초상화에 군중 제어, 방어 효과 및 기타 중요한 오라를 표시합니다. 가장 우선순위가 높은 아이콘 하나만 표시됩니다: 군중 제어, 무장 해제, 큰 방어, 외부 방어, 중요.", "초상화에서 미리 보기", "회전 방향 반전", "숫자 표시", "글꼴 크기 배율", "유닛", "무장 해제", "큰 방어 효과", "외부 방어 효과", "중요한 주문", "무장 해제는 적에게만 표시됩니다. 분류는 게임이 각 오라에 붙이는 표시를 사용하므로 인스턴스에서도 작동합니다.", "추가 군중 제어 주문 ID", "쉼표로 구분된 주문 ID입니다. 적에게만 표시됩니다.", "군중 제어 목록", "모두 켜기", "모두 끄기", "클릭하여 이 주문을 끕니다.", "클릭하여 이 주문을 켭니다.", "기절", "행동 불능", "공포 및 방향 감각 상실", "이동 불가", "침묵", "기타", "주문 ID", "주문 검색", "기절", "행동 불능", "공포 / 방향 감각 상실", "정신 지배", "이동 불가", "침묵", "무장 해제", "일치하는 주문이 없습니다.", "군중 제어 종류" },
    zhCN = { "头像光环", "在头像上显示群体控制、防御和其他重要光环。只显示一个优先级最高的图标：群体控制、缴械、强力防御、外部防御、重要。", "在头像上预览", "反转冷却转圈", "显示数字", "字体缩放", "单位", "缴械", "强力防御", "外部防御", "重要法术", "缴械只在敌人身上显示。分类使用游戏为每个光环设置的标记，因此在副本中也能正常工作。", "额外的群体控制法术 ID", "法术 ID 以逗号分隔。只在敌人身上显示。", "控制目录", "全部启用", "全部禁用", "点击禁用此法术。", "点击启用此法术。", "昏迷", "无法行动", "恐惧与迷惑", "定身", "沉默", "其他", "法术 ID", "搜索法术", "昏迷", "无法行动", "恐惧 / 迷惑", "精神控制", "定身", "沉默", "缴械", "没有匹配的法术。", "控制类型" },
    zhTW = { "頭像光環", "在頭像上顯示群體控制、防禦和其他重要光環。只顯示一個優先順序最高的圖示：群體控制、繳械、強力防禦、外部防禦、重要。", "在頭像上預覽", "反轉冷卻轉圈", "顯示數字", "字型縮放", "單位", "繳械", "強力防禦", "外部防禦", "重要法術", "繳械只會顯示在敵人身上。分類使用遊戲為每個光環設定的標記，因此在副本中也能正常運作。", "額外的群體控制法術 ID", "法術 ID 以逗號分隔。只會顯示在敵人身上。", "控制目錄", "全部啟用", "全部停用", "點擊以停用此法術。", "點擊以啟用此法術。", "昏迷", "無法行動", "恐懼與迷惑", "定身", "沉默", "其他", "法術 ID", "搜尋法術", "昏迷", "無法行動", "恐懼 / 迷惑", "精神控制", "定身", "沉默", "繳械", "沒有符合的法術。", "控制類型" },
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
