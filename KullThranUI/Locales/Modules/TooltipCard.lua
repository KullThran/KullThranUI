-- Tooltip card style (Tooltip module), for every supported language.
-- Existing translations win.
local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Card Style",
    "Item and spell cards",
    "Draws item and spell tooltips as cards: icon, item level, chips, weapon summary or spell grid and sell price. Other tooltips keep the usual style. Needs the Tooltip module enabled.",
    "Item level",
    "Cost",
    "Cast",
    "Cooldown",
    "Range",
    "Gale Edge",
    "Axe",
    "Equip: Grants 1 extra attack on your next swing.",
    "Earth Shock",
    "Instantly shocks the target with concussive force, causing 129 to 138 Nature damage. Interrupts spellcasting for 2 sec.",
    "Causes a high amount of threat.",
    "KullThranUI Tooltip Cards",
    "Do you want item and spell tooltips drawn as cards?",
    "You can change it later in Tooltip > Card Style.",
    "Use Tooltip Cards",
    "Keep KullThranUI Tooltips",
}

local values = {
    esES = { "Estilo tarjeta", "Tarjetas de objetos y hechizos", "Muestra los tooltips de objetos y hechizos como tarjetas: icono, nivel de objeto, etiquetas, resumen del arma o rejilla del hechizo y precio de venta. Los demás tooltips mantienen el estilo habitual. Requiere el módulo Tooltip activado.", "Nivel de objeto", "Coste", "Lanzamiento", "Reutilización", "Alcance", "Filo del Vendaval", "Hacha", "Equipar: otorga 1 ataque adicional en tu siguiente golpe.", "Choque de tierra", "Golpea al instante al objetivo con una fuerza contundente e inflige de 129 a 138 de daño de Naturaleza. Interrumpe el lanzamiento de hechizos durante 2 s.", "Genera mucha amenaza.", "Tarjetas de tooltip de KullThranUI", "¿Quieres que los tooltips de objetos y hechizos se muestren como tarjetas?", "Puedes cambiarlo más tarde en Tooltip > Estilo tarjeta.", "Usar tarjetas de tooltip", "Mantener los tooltips de KullThranUI" },
    deDE = { "Kartenstil", "Karten für Gegenstände und Zauber", "Zeigt Gegenstands- und Zaubertooltips als Karten: Symbol, Gegenstandsstufe, Kennzeichen, Waffenübersicht oder Zauberraster und Verkaufspreis. Andere Tooltips behalten den gewohnten Stil. Benötigt das aktivierte Tooltip-Modul.", "Gegenstandsstufe", "Kosten", "Zauberzeit", "Abklingzeit", "Reichweite", "Sturmschneide", "Axt", "Anlegen: Gewährt 1 zusätzlichen Angriff bei Eurem nächsten Schlag.", "Erdschock", "Erschüttert das Ziel sofort und verursacht 129 bis 138 Naturschaden. Unterbricht das Zauberwirken für 2 Sek.", "Erzeugt viel Bedrohung.", "KullThranUI-Tooltipkarten", "Sollen Gegenstands- und Zaubertooltips als Karten angezeigt werden?", "Du kannst es später unter Tooltip > Kartenstil ändern.", "Tooltipkarten verwenden", "KullThranUI-Tooltips beibehalten" },
    frFR = { "Style carte", "Cartes pour objets et sorts", "Affiche les infobulles d'objets et de sorts sous forme de cartes : icône, niveau d'objet, étiquettes, résumé de l'arme ou grille du sort et prix de vente. Les autres infobulles gardent le style habituel. Nécessite le module Infobulle activé.", "Niveau d'objet", "Coût", "Incantation", "Temps de recharge", "Portée", "Lame de la bourrasque", "Hache", "Équipé : confère 1 attaque supplémentaire lors de votre prochain coup.", "Horion de terre", "Frappe instantanément la cible avec force et inflige 129 à 138 points de dégâts de Nature. Interrompt l'incantation pendant 2 s.", "Génère beaucoup de menace.", "Cartes d'infobulle KullThranUI", "Voulez-vous afficher les infobulles d'objets et de sorts sous forme de cartes ?", "Vous pourrez le modifier plus tard dans Infobulle > Style carte.", "Utiliser les cartes d'infobulle", "Garder les infobulles KullThranUI" },
    itIT = { "Stile scheda", "Schede per oggetti e incantesimi", "Mostra i tooltip di oggetti e incantesimi come schede: icona, livello oggetto, etichette, riepilogo dell'arma o griglia dell'incantesimo e prezzo di vendita. Gli altri tooltip mantengono lo stile abituale. Richiede il modulo Tooltip attivo.", "Livello oggetto", "Costo", "Lancio", "Tempo di recupero", "Gittata", "Filo della Burrasca", "Ascia", "Equipaggiato: conferisce 1 attacco aggiuntivo al prossimo colpo.", "Shock di Terra", "Colpisce all'istante il bersaglio con forza, infliggendo da 129 a 138 danni da Natura. Interrompe il lancio di incantesimi per 2 s.", "Genera molta minaccia.", "Schede tooltip di KullThranUI", "Vuoi che i tooltip di oggetti e incantesimi siano mostrati come schede?", "Puoi cambiarlo più tardi in Tooltip > Stile scheda.", "Usa le schede tooltip", "Mantieni i tooltip di KullThranUI" },
    ptBR = { "Estilo cartão", "Cartões de itens e feitiços", "Mostra as dicas de itens e feitiços como cartões: ícone, nível do item, etiquetas, resumo da arma ou grade do feitiço e preço de venda. As outras dicas mantêm o estilo habitual. Requer o módulo Tooltip ativado.", "Nível do item", "Custo", "Conjuração", "Tempo de recarga", "Alcance", "Gume da Ventania", "Machado", "Equipado: concede 1 ataque extra no seu próximo golpe.", "Choque Terreo", "Atinge o alvo instantaneamente com força concussiva, causando de 129 a 138 de dano de Natureza. Interrompe a conjuração por 2 s.", "Gera muita ameaça.", "Cartões de dica do KullThranUI", "Quer que as dicas de itens e feitiços sejam mostradas como cartões?", "Você pode mudar isso depois em Tooltip > Estilo cartão.", "Usar cartões de dica", "Manter as dicas do KullThranUI" },
    ruRU = { "Стиль карточки", "Карточки предметов и заклинаний", "Показывает подсказки предметов и заклинаний в виде карточек: значок, уровень предмета, метки, сводка оружия или сетка заклинания и цена продажи. Остальные подсказки сохраняют обычный стиль. Требуется включённый модуль подсказок.", "Уровень предмета", "Стоимость", "Применение", "Восстановление", "Дальность", "Клинок бури", "Топор", "Если на персонаже: дает 1 дополнительную атаку при следующем ударе.", "Земной шок", "Мгновенно поражает цель ударной силой, нанося от 129 до 138 ед. урона от сил природы. Прерывает произнесение заклинаний на 2 сек.", "Вызывает высокий уровень угрозы.", "Карточки подсказок KullThranUI", "Показывать подсказки предметов и заклинаний в виде карточек?", "Это можно изменить позже в разделе «Подсказки > Стиль карточки».", "Использовать карточки", "Оставить подсказки KullThranUI" },
    koKR = { "카드 스타일", "아이템 및 주문 카드", "아이템과 주문 툴팁을 카드로 표시합니다: 아이콘, 아이템 레벨, 태그, 무기 요약 또는 주문 격자, 판매 가격. 다른 툴팁은 기존 스타일을 유지합니다. 툴팁 모듈이 켜져 있어야 합니다.", "아이템 레벨", "비용", "시전", "재사용 대기시간", "사거리", "강풍의 칼날", "도끼", "착용 효과: 다음 공격 시 추가 공격을 1회 합니다.", "대지 충격", "대상에게 즉시 충격을 가해 129~138의 자연 피해를 입힙니다. 2초 동안 주문 시전을 방해합니다.", "높은 위협 수준을 유발합니다.", "KullThranUI 툴팁 카드", "아이템과 주문 툴팁을 카드로 표시할까요?", "나중에 툴팁 > 카드 스타일에서 바꿀 수 있습니다.", "툴팁 카드 사용", "KullThranUI 툴팁 유지" },
    zhCN = { "卡片样式", "物品和法术卡片", "将物品和法术提示显示为卡片：图标、物品等级、标签、武器概要或法术网格以及出售价格。其他提示保持原有样式。需要启用提示模块。", "物品等级", "消耗", "施法", "冷却时间", "射程", "狂风之刃", "斧", "装备：你的下一次攻击获得1次额外攻击。", "大地震击", "以震荡之力立即冲击目标，造成129到138点自然伤害，并打断施法2秒。", "造成大量威胁。", "KullThranUI 提示卡片", "要将物品和法术提示显示为卡片吗？", "之后可以在 提示 > 卡片样式 中更改。", "使用提示卡片", "保留 KullThranUI 提示" },
    zhTW = { "卡片樣式", "物品和法術卡片", "將物品和法術提示顯示為卡片：圖示、物品等級、標籤、武器概要或法術格線以及售價。其他提示維持原本樣式。需要啟用提示模組。", "物品等級", "消耗", "施法", "冷卻時間", "射程", "狂風之刃", "斧", "裝備：你的下一次攻擊獲得1次額外攻擊。", "地震術", "以震盪之力立即衝擊目標，造成129到138點自然傷害，並打斷施法2秒。", "造成大量威脅。", "KullThranUI 提示卡片", "要將物品和法術提示顯示為卡片嗎？", "之後可以在 提示 > 卡片樣式 中更改。", "使用提示卡片", "保留 KullThranUI 提示" },
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
