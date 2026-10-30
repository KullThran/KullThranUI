local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local keys = {
    "Aura Reminders", "Prepare group buffs, class upkeep and consumables from one KUI workspace.",
    "Control Center", "Group Readiness", "Class Upkeep", "Consumable Loadout", "Talent Reminders", "Custom Auras",
    "LOOK & PLACEMENT", "GROUP COVERAGE", "ASSIGNED & PERSONAL AURAS", "LOADOUT CHECKLIST",
    "ROGUE PREPARATION", "PALADIN PREPARATION", "SHAMAN PREPARATION", "Text Settings", "Display In:",
    "Select a talent...", "Blank Canvas", "Start from scratch", "Tracks a cooldown", "Tracks your buff",
    "Important warning", "Mythic Only", "Heroic and Mythic", "All Instanced Content", "Icon (Default)",
    "Text Only", "Weapon", "Buff", "Debuff", "Inky Black Potion Zone IDs", "a Glow Type other than None",
}

local values = {
 enUS={"Aura Reminders","Prepare group buffs, class upkeep and consumables from one KUI workspace.","Control Center","Group Readiness","Class Upkeep","Consumable Loadout","Talent Reminders","Custom Auras","LOOK & PLACEMENT","GROUP COVERAGE","ASSIGNED & PERSONAL AURAS","LOADOUT CHECKLIST","ROGUE PREPARATION","PALADIN PREPARATION","SHAMAN PREPARATION","Text Settings","Display In:","Select a talent...","Blank Canvas","Start from scratch","Tracks a cooldown","Tracks your buff","Important warning","Mythic Only","Heroic and Mythic","All Instanced Content","Icon (Default)","Text Only","Weapon","Buff","Debuff","Inky Black Potion Zone IDs","a Glow Type other than None"},
 esES={"Recordatorios de auras","Prepara los buffs del grupo, el mantenimiento de clase y los consumibles desde un único espacio de KUI.","Centro de control","Preparación del grupo","Mantenimiento de clase","Equipamiento de consumibles","Recordatorios de talentos","Auras personalizadas","ASPECTO Y POSICIÓN","COBERTURA DEL GRUPO","AURAS ASIGNADAS Y PERSONALES","LISTA DE CONSUMIBLES","PREPARACIÓN DEL PÍCARO","PREPARACIÓN DEL PALADÍN","PREPARACIÓN DEL CHAMÁN","Ajustes de texto","Mostrar en:","Selecciona un talento...","Lienzo en blanco","Empezar desde cero","Rastrea un tiempo de reutilización","Rastrea tu buff","Aviso importante","Solo míticas","Heroicas y míticas","Todo el contenido instanciado","Icono (predeterminado)","Solo texto","Arma","Buff","Debuff","IDs de zona de la poción de tinta negra","un tipo de resplandor distinto de Ninguno"},
 deDE={"Aura-Erinnerungen","Bereite Gruppen-Buffs, Klassenpflege und Verbrauchsgegenstände in einem KUI-Arbeitsbereich vor.","Kontrollzentrum","Gruppenbereitschaft","Klassenpflege","Verbrauchsgegenstände","Talent-Erinnerungen","Benutzerdefinierte Auren","AUSSEHEN & PLATZIERUNG","GRUPPENABDECKUNG","ZUGEWIESENE & PERSÖNLICHE AUREN","VERBRAUCHSGEGENSTÄNDE","SCHURKEN-VORBEREITUNG","PALADIN-VORBEREITUNG","SCHAMANEN-VORBEREITUNG","Texteinstellungen","Anzeigen in:","Talent auswählen ...","Leere Vorlage","Von Grund auf beginnen","Verfolgt eine Abklingzeit","Verfolgt deinen Buff","Wichtiger Hinweis","Nur mythisch","Heroisch und mythisch","Alle Instanzinhalte","Symbol (Standard)","Nur Text","Waffe","Buff","Debuff","Zonen-IDs für Tiefschwarzen Trank","einen anderen Leuchttyp als Keine"},
 frFR={"Rappels d’aura","Préparez les buffs de groupe, l’entretien de classe et les consommables depuis un seul espace KUI.","Centre de contrôle","Préparation du groupe","Entretien de classe","Équipement consommable","Rappels de talents","Auras personnalisées","APPARENCE ET POSITION","COUVERTURE DU GROUPE","AURAS ASSIGNÉES ET PERSONNELLES","LISTE DES CONSOMMABLES","PRÉPARATION DU VOLEUR","PRÉPARATION DU PALADIN","PRÉPARATION DU CHAMAN","Paramètres du texte","Afficher dans :","Sélectionnez un talent...","Toile vierge","Commencer de zéro","Suit un temps de recharge","Suit votre buff","Avertissement important","Mythique uniquement","Héroïque et mythique","Tout le contenu instancié","Icône (par défaut)","Texte uniquement","Arme","Buff","Affaiblissement","IDs de zone de la potion noire d’encre","un type de lueur autre qu’Aucune"},
 itIT={"Promemoria aure","Prepara i buff di gruppo, il mantenimento della classe e i consumabili da un unico spazio KUI.","Centro di controllo","Preparazione del gruppo","Mantenimento della classe","Dotazione consumabili","Promemoria dei talenti","Aure personalizzate","ASPETTO E POSIZIONE","COPERTURA DEL GRUPPO","AURE ASSEGNATE E PERSONALI","ELENCO DEI CONSUMABILI","PREPARAZIONE DEL LADRO","PREPARAZIONE DEL PALADINO","PREPARAZIONE DELLO SCIAMANO","Impostazioni del testo","Mostra in:","Seleziona un talento...","Tela vuota","Inizia da zero","Tiene traccia di un tempo di recupero","Tiene traccia del tuo buff","Avviso importante","Solo mitiche","Eroiche e mitiche","Tutti i contenuti istanziati","Icona (predefinita)","Solo testo","Arma","Buff","Indebolimento","ID zona della Pozione nera d’inchiostro","un tipo di bagliore diverso da Nessuno"},
 ptBR={"Lembretes de auras","Prepare buffs do grupo, manutenção de classe e consumíveis em um único espaço do KUI.","Central de controle","Prontidão do grupo","Manutenção de classe","Conjunto de consumíveis","Lembretes de talentos","Auras personalizadas","APARÊNCIA E POSIÇÃO","COBERTURA DO GRUPO","AURAS ATRIBUÍDAS E PESSOAIS","LISTA DE CONSUMÍVEIS","PREPARAÇÃO DO LADINO","PREPARAÇÃO DO PALADINO","PREPARAÇÃO DO XAMÃ","Configurações de texto","Exibir em:","Selecione um talento...","Tela em branco","Começar do zero","Rastreia um tempo de recarga","Rastreia seu buff","Aviso importante","Somente mítico","Heroico e mítico","Todo o conteúdo de instâncias","Ícone (padrão)","Somente texto","Arma","Buff","Debuff","IDs de zona da Poção Negra de Tinta","um tipo de brilho diferente de Nenhum"},
 ruRU={"Напоминания об аурах","Подготавливайте групповые баффы, поддержку класса и расходники в одном окне KUI.","Центр управления","Готовность группы","Поддержка класса","Набор расходников","Напоминания о талантах","Пользовательские ауры","ВИД И РАСПОЛОЖЕНИЕ","ПОКРЫТИЕ ГРУППЫ","НАЗНАЧЕННЫЕ И ЛИЧНЫЕ АУРЫ","СПИСОК РАСХОДНИКОВ","ПОДГОТОВКА РАЗБОЙНИКА","ПОДГОТОВКА ПАЛАДИНА","ПОДГОТОВКА ШАМАНА","Настройки текста","Показывать в:","Выберите талант...","Чистый холст","Начать с нуля","Отслеживает восстановление","Отслеживает ваш бафф","Важное предупреждение","Только эпохальные","Героические и эпохальные","Все подземелья и рейды","Значок (по умолчанию)","Только текст","Оружие","Бафф","Дебафф","ID зон Чернильно-чёрного зелья","тип свечения, отличный от «Нет»"},
 koKR={"오라 알림","하나의 KUI 공간에서 파티 버프, 직업 유지 효과와 소모품을 준비합니다.","제어 센터","그룹 준비","직업 유지","소모품 구성","특성 알림","사용자 지정 오라","모양 및 배치","그룹 적용 범위","지정 및 개인 오라","소모품 확인 목록","도적 준비","성기사 준비","주술사 준비","텍스트 설정","표시 대상:","특성을 선택하세요...","빈 캔버스","처음부터 시작","재사용 대기시간 추적","내 버프 추적","중요 경고","신화만","영웅 및 신화","모든 인스턴스 콘텐츠","아이콘(기본값)","텍스트만","무기","버프","디버프","칠흑의 잉크 물약 지역 ID","없음이 아닌 반짝임 유형"},
 zhCN={"光环提醒","在 KUI 的同一工作区中准备团队增益、职业维持效果和消耗品。","控制中心","团队准备","职业维护","消耗品配置","天赋提醒","自定义光环","外观与位置","团队覆盖","已分配与个人光环","消耗品清单","潜行者准备","圣骑士准备","萨满准备","文字设置","显示于：","选择一个天赋……","空白模板","从头开始","追踪冷却时间","追踪你的增益","重要警告","仅史诗","英雄和史诗","所有副本内容","图标（默认）","仅文字","武器","增益","减益","墨黑药水区域 ID","非无的发光类型"},
 zhTW={"光環提醒","在 KUI 的同一工作區中準備團隊增益、職業維持效果與消耗品。","控制中心","隊伍準備","職業維護","消耗品配置","天賦提醒","自訂光環","外觀與位置","隊伍涵蓋","已指定與個人光環","消耗品清單","盜賊準備","聖騎士準備","薩滿準備","文字設定","顯示於：","選擇一個天賦……","空白範本","從頭開始","追蹤冷卻時間","追蹤你的增益","重要警告","僅限傳奇","英雄與傳奇","所有副本內容","圖示（預設）","僅文字","武器","增益","減益","墨黑藥水區域 ID","非無的發光類型"},
}

for locale, translated in pairs(values) do
    local target = locales[locale]
    if type(target) == "table" then
        for index, key in ipairs(keys) do target[key] = translated[index] end
    end
end
if type(locales.esMX) == "table" then
    for index, key in ipairs(keys) do locales.esMX[key] = values.esES[index] end
end

local extra = {
    enUS = {
        ["None"]="None", ["Action Button Glow"]="Action Button Glow", ["Pixel Glow"]="Pixel Glow", ["Auto-Cast Shine"]="Auto-Cast Shine", ["GCD"]="GCD", ["Modern WoW Glow"]="Modern WoW Glow", ["Classic WoW Glow"]="Classic WoW Glow",
        ["Last Used"]="Last Used", ["Preferred Click to Buff"]="Preferred Click to Buff", ["Flask"]="Flask", ["Food"]="Food", ["Weapon Enhancement"]="Weapon Enhancement", ["Augment Rune"]="Augment Rune", ["Inky Black Potion"]="Inky Black Potion", ["Mark"]="Mark", ["Weapon"]="Weapon", ["Pet"]="Pet", ["Poison"]="Poison", ["Shield"]="Shield",
        ["Flask of the Blood Knights"]="Flask of the Blood Knights", ["Flask of the Magisters"]="Flask of the Magisters", ["Flask of the Shattered Sun"]="Flask of the Shattered Sun", ["Flask of Thalassian Resistance"]="Flask of Thalassian Resistance", ["Vicious Thalassian Flask of Honor"]="Vicious Thalassian Flask of Honor",
    },
    esES = {
        ["None"]="Ninguno", ["Action Button Glow"]="Resplandor del botón de acción", ["Pixel Glow"]="Resplandor de píxeles", ["Auto-Cast Shine"]="Brillo de autocast", ["GCD"]="GCD", ["Modern WoW Glow"]="Resplandor de WoW moderno", ["Classic WoW Glow"]="Resplandor de WoW clásico",
        ["Last Used"]="Último usado", ["Preferred Click to Buff"]="Preferido para buffear con clic", ["Flask"]="Frasco", ["Food"]="Comida", ["Weapon Enhancement"]="Mejora de arma", ["Augment Rune"]="Runa de aumento", ["Inky Black Potion"]="Poción de tinta negra", ["Mark"]="Marca", ["Weapon"]="Arma", ["Pet"]="Mascota", ["Poison"]="Veneno", ["Shield"]="Escudo",
        ["Flask of the Blood Knights"]="Frasco de los Caballeros de sangre", ["Flask of the Magisters"]="Frasco de los magos", ["Flask of the Shattered Sun"]="Frasco del Sol Devastado", ["Flask of Thalassian Resistance"]="Frasco de resistencia thalassiana", ["Vicious Thalassian Flask of Honor"]="Frasco de honor thalassiano feroz",
    },
    deDE = {
        ["None"]="Keine", ["Action Button Glow"]="Aktionsbutton-Leuchten", ["Pixel Glow"]="Pixel-Leuchten", ["Auto-Cast Shine"]="AutoCast-Glanz", ["GCD"]="GCD", ["Modern WoW Glow"]="Modernes WoW-Leuchten", ["Classic WoW Glow"]="Klassisches WoW-Leuchten",
        ["Last Used"]="Zuletzt verwendet", ["Preferred Click to Buff"]="Bevorzugt zum Buffen per Klick", ["Flask"]="Fläschchen", ["Food"]="Essen", ["Weapon Enhancement"]="Waffenverbesserung", ["Augment Rune"]="Verstärkungsrune", ["Inky Black Potion"]="Tiefschwarzer Trank", ["Mark"]="Mal", ["Weapon"]="Waffe", ["Pet"]="Begleiter", ["Poison"]="Gift", ["Shield"]="Schild",
        ["Flask of the Blood Knights"]="Fläschchen der Blutritter", ["Flask of the Magisters"]="Fläschchen der Magister", ["Flask of the Shattered Sun"]="Fläschchen der Zerschmetterten Sonne", ["Flask of Thalassian Resistance"]="Fläschchen des thalassischen Widerstands", ["Vicious Thalassian Flask of Honor"]="Tückisches thalassisches Ehrenfläschchen",
    },
    frFR = {
        ["None"]="Aucune", ["Action Button Glow"]="Lueur de bouton d’action", ["Pixel Glow"]="Lueur pixelisée", ["Auto-Cast Shine"]="Éclat d’autocast", ["GCD"]="GCD", ["Modern WoW Glow"]="Lueur WoW moderne", ["Classic WoW Glow"]="Lueur WoW classique",
        ["Last Used"]="Dernier utilisé", ["Preferred Click to Buff"]="Buff préféré au clic", ["Flask"]="Flacon", ["Food"]="Nourriture", ["Weapon Enhancement"]="Amélioration d’arme", ["Augment Rune"]="Rune d’augmentation", ["Inky Black Potion"]="Potion noir d’encre", ["Mark"]="Marque", ["Weapon"]="Arme", ["Pet"]="Familier", ["Poison"]="Poison", ["Shield"]="Bouclier",
        ["Flask of the Blood Knights"]="Flacon des chevaliers de sang", ["Flask of the Magisters"]="Flacon des magistères", ["Flask of the Shattered Sun"]="Flacon du Soleil brisé", ["Flask of Thalassian Resistance"]="Flacon de résistance thalassienne", ["Vicious Thalassian Flask of Honor"]="Flacon d’honneur thalassien vicieux",
    },
    itIT = {
        ["None"]="Nessuno", ["Action Button Glow"]="Bagliore del pulsante d’azione", ["Pixel Glow"]="Bagliore pixel", ["Auto-Cast Shine"]="Luce AutoCast", ["GCD"]="GCD", ["Modern WoW Glow"]="Bagliore WoW moderno", ["Classic WoW Glow"]="Bagliore WoW classico",
        ["Last Used"]="Ultimo usato", ["Preferred Click to Buff"]="Preferito per buff con clic", ["Flask"]="Fiaschetta", ["Food"]="Cibo", ["Weapon Enhancement"]="Potenziamento arma", ["Augment Rune"]="Runa d’incremento", ["Inky Black Potion"]="Pozione nera d’inchiostro", ["Mark"]="Marchio", ["Weapon"]="Arma", ["Pet"]="Famiglio", ["Poison"]="Veleno", ["Shield"]="Scudo",
        ["Flask of the Blood Knights"]="Fiaschetta dei Cavalieri del Sangue", ["Flask of the Magisters"]="Fiaschetta dei Magister", ["Flask of the Shattered Sun"]="Fiaschetta del Sole Infranto", ["Flask of Thalassian Resistance"]="Fiaschetta della resistenza dei Thalassiani", ["Vicious Thalassian Flask of Honor"]="Fiaschetta d’onore dei Thalassiani selvaggia",
    },
    ptBR = {
        ["None"]="Nenhum", ["Action Button Glow"]="Brilho do botão de ação", ["Pixel Glow"]="Brilho de pixels", ["Auto-Cast Shine"]="Brilho de lançamento automático", ["GCD"]="GCD", ["Modern WoW Glow"]="Brilho de WoW moderno", ["Classic WoW Glow"]="Brilho de WoW clássico",
        ["Last Used"]="Último usado", ["Preferred Click to Buff"]="Preferido para fortalecer com clique", ["Flask"]="Frasco", ["Food"]="Comida", ["Weapon Enhancement"]="Aprimoramento de arma", ["Augment Rune"]="Runa de aprimoramento", ["Inky Black Potion"]="Poção Negra de Tinta", ["Mark"]="Marca", ["Weapon"]="Arma", ["Pet"]="Mascote", ["Poison"]="Veneno", ["Shield"]="Escudo",
        ["Flask of the Blood Knights"]="Frasco dos Cavaleiros Sangrentos", ["Flask of the Magisters"]="Frasco dos Magísteres", ["Flask of the Shattered Sun"]="Frasco do Sol Partido", ["Flask of Thalassian Resistance"]="Frasco de resistência thalassiana", ["Vicious Thalassian Flask of Honor"]="Frasco de Honra Thalassiana Viciosa",
    },
    ruRU = {
        ["None"]="Нет", ["Action Button Glow"]="Свечение кнопки действия", ["Pixel Glow"]="Пиксельное свечение", ["Auto-Cast Shine"]="Сияние автоприменения", ["GCD"]="ГКД", ["Modern WoW Glow"]="Свечение современного WoW", ["Classic WoW Glow"]="Свечение классического WoW",
        ["Last Used"]="Последний использованный", ["Preferred Click to Buff"]="Предпочтительный бафф по нажатию", ["Flask"]="Флакон", ["Food"]="Еда", ["Weapon Enhancement"]="Усиление оружия", ["Augment Rune"]="Руна усиления", ["Inky Black Potion"]="Чернильно-чёрное зелье", ["Mark"]="Метка", ["Weapon"]="Оружие", ["Pet"]="Питомец", ["Poison"]="Яд", ["Shield"]="Щит",
        ["Flask of the Blood Knights"]="Флакон кровавых рыцарей", ["Flask of the Magisters"]="Флакон магистров", ["Flask of the Shattered Sun"]="Флакон Расколотого Солнца", ["Flask of Thalassian Resistance"]="Флакон талассийской устойчивости", ["Vicious Thalassian Flask of Honor"]="Свирепый талассийский флакон чести",
    },
    koKR = {
        ["None"]="없음", ["Action Button Glow"]="행동 단추 반짝임", ["Pixel Glow"]="픽셀 반짝임", ["Auto-Cast Shine"]="자동 시전 빛남", ["GCD"]="GCD", ["Modern WoW Glow"]="현대 WoW 반짝임", ["Classic WoW Glow"]="클래식 WoW 반짝임",
        ["Last Used"]="최근 사용", ["Preferred Click to Buff"]="클릭으로 사용할 버프", ["Flask"]="영약", ["Food"]="음식", ["Weapon Enhancement"]="무기 강화", ["Augment Rune"]="증강 룬", ["Inky Black Potion"]="칠흑의 잉크 물약", ["Mark"]="징표", ["Weapon"]="무기", ["Pet"]="소환수", ["Poison"]="독", ["Shield"]="방패",
        ["Flask of the Blood Knights"]="붉은 기사단의 영약", ["Flask of the Magisters"]="마법학자의 영약", ["Flask of the Shattered Sun"]="부서진 태양의 영약", ["Flask of Thalassian Resistance"]="탈라시안 저항의 영약", ["Vicious Thalassian Flask of Honor"]="흉포한 탈라시안 명예 영약",
    },
    zhCN = {
        ["None"]="无", ["Action Button Glow"]="动作按钮发光", ["Pixel Glow"]="像素发光", ["Auto-Cast Shine"]="自动施法闪光", ["GCD"]="GCD", ["Modern WoW Glow"]="现代 WoW 发光", ["Classic WoW Glow"]="经典 WoW 发光",
        ["Last Used"]="上次使用", ["Preferred Click to Buff"]="首选点击增益", ["Flask"]="合剂", ["Food"]="食物", ["Weapon Enhancement"]="武器强化", ["Augment Rune"]="增幅符文", ["Inky Black Potion"]="墨黑药水", ["Mark"]="印记", ["Weapon"]="武器", ["Pet"]="宠物", ["Poison"]="毒药", ["Shield"]="盾牌",
        ["Flask of the Blood Knights"]="血骑士合剂", ["Flask of the Magisters"]="魔导师合剂", ["Flask of the Shattered Sun"]="破碎太阳合剂", ["Flask of Thalassian Resistance"]="萨拉斯抗性合剂", ["Vicious Thalassian Flask of Honor"]="凶猛萨拉斯荣誉合剂",
    },
    zhTW = {
        ["None"]="無", ["Action Button Glow"]="動作按鈕發光", ["Pixel Glow"]="像素發光", ["Auto-Cast Shine"]="自動施法閃光", ["GCD"]="GCD", ["Modern WoW Glow"]="現代 WoW 發光", ["Classic WoW Glow"]="經典 WoW 發光",
        ["Last Used"]="上次使用", ["Preferred Click to Buff"]="偏好的點擊增益", ["Flask"]="精煉藥劑", ["Food"]="食物", ["Weapon Enhancement"]="武器強化", ["Augment Rune"]="增幅符文", ["Inky Black Potion"]="墨黑藥水", ["Mark"]="印記", ["Weapon"]="武器", ["Pet"]="寵物", ["Poison"]="毒藥", ["Shield"]="盾牌",
        ["Flask of the Blood Knights"]="血騎士精煉藥劑", ["Flask of the Magisters"]="魔導師精煉藥劑", ["Flask of the Shattered Sun"]="破碎之日精煉藥劑", ["Flask of Thalassian Resistance"]="薩拉斯抗性精煉藥劑", ["Vicious Thalassian Flask of Honor"]="凶猛薩拉斯榮譽精煉藥劑",
    },
}
for locale, translated in pairs(extra) do
    local target = locales[locale]
    if type(target) == "table" then
        for key, value in pairs(translated) do target[key] = value end
    end
end
if type(locales.esMX) == "table" then
    for key, value in pairs(extra.esES) do locales.esMX[key] = value end
end
