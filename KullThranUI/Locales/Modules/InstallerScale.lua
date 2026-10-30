-- Installer scale and positions step, the Enhanced Friend List and Cooldown
-- Manager steps, Bulk Buy, and a few strings still left in English.
local _, ns = ...

local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local localeOrder = { "esES", "deDE", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
local translations = {
    ["Interface Scale & Positions"] = { "Escala de la interfaz y posiciones", "Interface-Skalierung und Positionen", "Échelle de l'interface et positions", "Scala dell'interfaccia e posizioni", "Escala da interface e posições", "Масштаб интерфейса и позиции", "인터페이스 크기 및 위치", "界面缩放与位置", "介面縮放與位置" },
    ["Your current scale and your saved frame positions are kept unless you choose otherwise and press Apply."] = {
        "Tu escala actual y las posiciones guardadas de los marcos se mantienen salvo que elijas otra cosa y pulses Aplicar.",
        "Deine aktuelle Skalierung und deine gespeicherten Fensterpositionen bleiben erhalten, außer du wählst etwas anderes und klickst auf Übernehmen.",
        "Votre échelle actuelle et vos positions de cadres enregistrées sont conservées, sauf si vous choisissez autre chose et appuyez sur Appliquer.",
        "La scala attuale e le posizioni salvate dei riquadri restano invariate, a meno che tu non scelga altro e prema Applica.",
        "Sua escala atual e as posições salvas dos quadros são mantidas, a menos que você escolha outra opção e clique em Aplicar.",
        "Текущий масштаб и сохранённые позиции рамок сохраняются, если вы не выберете другое и не нажмёте «Применить».",
        "다른 것을 선택하고 적용을 누르지 않으면 현재 크기와 저장된 프레임 위치가 유지됩니다.",
        "除非你做出其他选择并点击“应用”，否则会保留当前缩放和已保存的框体位置。",
        "除非你做出其他選擇並點擊「套用」，否則會保留目前縮放和已儲存的框架位置。",
    },
    ["Interface scale"] = { "Escala de la interfaz", "Interface-Skalierung", "Échelle de l'interface", "Scala dell'interfaccia", "Escala da interface", "Масштаб интерфейса", "인터페이스 크기", "界面缩放", "介面縮放" },
    ["Current scale: %s"] = { "Escala actual: %s", "Aktuelle Skalierung: %s", "Échelle actuelle : %s", "Scala attuale: %s", "Escala atual: %s", "Текущий масштаб: %s", "현재 크기: %s", "当前缩放：%s", "目前縮放：%s" },
    ["Frame positions"] = { "Posiciones de los marcos", "Fensterpositionen", "Positions des cadres", "Posizioni dei riquadri", "Posições dos quadros", "Позиции рамок", "프레임 위치", "框体位置", "框架位置" },
    ["Keep my saved positions"] = { "Mantener mis posiciones guardadas", "Meine gespeicherten Positionen behalten", "Garder mes positions enregistrées", "Mantieni le mie posizioni salvate", "Manter minhas posições salvas", "Оставить мои сохранённые позиции", "저장한 위치 유지", "保留我保存的位置", "保留我儲存的位置" },
    ["Use KullThranUI default positions"] = { "Usar las posiciones predeterminadas de KullThranUI", "Standardpositionen von KullThranUI verwenden", "Utiliser les positions par défaut de KullThranUI", "Usa le posizioni predefinite di KullThranUI", "Usar as posições padrão do KullThranUI", "Использовать позиции KullThranUI по умолчанию", "KullThranUI 기본 위치 사용", "使用 KullThranUI 默认位置", "使用 KullThranUI 預設位置" },
    ["Apply Positions"] = { "Aplicar posiciones", "Positionen übernehmen", "Appliquer les positions", "Applica posizioni", "Aplicar posições", "Применить позиции", "위치 적용", "应用位置", "套用位置" },
    ["KullThranUI default positions"] = { "Posiciones predeterminadas de KullThranUI", "Standardpositionen von KullThranUI", "Positions par défaut de KullThranUI", "Posizioni predefinite di KullThranUI", "Posições padrão do KullThranUI", "Позиции KullThranUI по умолчанию", "KullThranUI 기본 위치", "KullThranUI 默认位置", "KullThranUI 預設位置" },
    ["NOTE: Using the KullThranUI default positions replaces your Blizzard Edit Mode profile."] = {
        "NOTA: usar las posiciones predeterminadas de KullThranUI reemplaza tu perfil del Modo edición de Blizzard.",
        "HINWEIS: Die Standardpositionen von KullThranUI ersetzen dein Blizzard-Bearbeitungsmodus-Profil.",
        "REMARQUE : utiliser les positions par défaut de KullThranUI remplace votre profil du mode Édition de Blizzard.",
        "NOTA: usare le posizioni predefinite di KullThranUI sostituisce il tuo profilo della Modalità modifica di Blizzard.",
        "OBSERVAÇÃO: usar as posições padrão do KullThranUI substitui seu perfil do Modo de Edição da Blizzard.",
        "ВНИМАНИЕ: позиции KullThranUI по умолчанию заменяют ваш профиль режима редактирования Blizzard.",
        "참고: KullThranUI 기본 위치를 사용하면 블리자드 편집 모드 프로필이 교체됩니다.",
        "注意：使用 KullThranUI 默认位置会替换你的暴雪编辑模式配置。",
        "注意：使用 KullThranUI 預設位置會取代你的暴雪編輯模式設定檔。",
    },
    ["Nameplate style: %s"] = { "Estilo de placas de nombre: %s", "Namensplakettenstil: %s", "Style des barres d'info : %s", "Stile delle targhette: %s", "Estilo das placas de nome: %s", "Стиль индикаторов здоровья: %s", "이름표 스타일: %s", "姓名板样式：%s", "名條樣式：%s" },
    ["Power bar shown with your Cooldown Manager."] = {
        "Barra de recurso mostrada junto a tu Cooldown Manager.",
        "Ressourcenleiste, die mit deinem Cooldown Manager angezeigt wird.",
        "Barre de ressource affichée avec votre Cooldown Manager.",
        "Barra della risorsa mostrata con il tuo Cooldown Manager.",
        "Barra de recurso exibida com seu Cooldown Manager.",
        "Полоса ресурса, показываемая вместе с Cooldown Manager.",
        "쿨다운 매니저와 함께 표시되는 자원 바입니다.",
        "与冷却管理器一起显示的能量条。",
        "與冷卻管理器一起顯示的能量條。",
    },
    ["Disable"] = { "Desactivar", "Deaktivieren", "Désactiver", "Disattiva", "Desativar", "Отключить", "비활성화", "禁用", "停用" },
    ["Available"] = { "Disponible", "Verfügbar", "Disponible", "Disponibile", "Disponível", "Доступен", "대화 가능", "有空", "有空" },
    ["The redesigned social panel: class-coloured contacts, custom groups, notes, search and one-click invites, Who, Raid and Quick Join in the same window."] = {
        "El panel social rediseñado: contactos con el color de su clase, grupos propios, notas, búsqueda e invitación con un clic, Quién, Banda y Unión rápida en la misma ventana.",
        "Das neu gestaltete Sozialfenster: Kontakte in Klassenfarben, eigene Gruppen, Notizen, Suche und Einladungen per Klick, Wer, Schlachtzug und Schnellbeitritt in einem Fenster.",
        "Le panneau social repensé : contacts aux couleurs de classe, groupes personnalisés, notes, recherche et invitations en un clic, Qui, Raid et Rejoindre rapidement dans la même fenêtre.",
        "Il pannello social ridisegnato: contatti con il colore della classe, gruppi personalizzati, note, ricerca e inviti con un clic, Chi, Incursione e Partecipazione rapida nella stessa finestra.",
        "O painel social redesenhado: contatos com a cor da classe, grupos personalizados, notas, busca e convites com um clique, Quem, Raide e Entrada Rápida na mesma janela.",
        "Обновлённая панель общения: контакты в цветах классов, свои группы, заметки, поиск и приглашение в один щелчок, «Кто», «Рейд» и «Быстрое присоединение» в одном окне.",
        "새로 디자인된 소셜 창: 직업 색상 연락처, 사용자 그룹, 메모, 검색과 클릭 한 번으로 초대, 누구, 공격대, 빠른 참가를 한 창에서.",
        "重新设计的社交面板：职业颜色的联系人、自定义分组、备注、搜索和一键邀请，查询、团队和快速加入都在同一个窗口中。",
        "重新設計的社交面板：職業顏色的聯絡人、自訂群組、備註、搜尋和一鍵邀請，查詢、團隊和快速加入都在同一個視窗中。",
    },
    ["The preview is the real window with your accent colour and sample friends."] = {
        "La vista previa es la ventana real con tu color de acento y amigos de ejemplo.",
        "Die Vorschau ist das echte Fenster mit deiner Akzentfarbe und Beispielfreunden.",
        "L'aperçu est la vraie fenêtre, avec votre couleur d'accent et des amis d'exemple.",
        "L'anteprima è la finestra reale con il tuo colore d'accento e amici di esempio.",
        "A prévia é a janela real com sua cor de destaque e amigos de exemplo.",
        "Предпросмотр — это настоящее окно с вашим акцентным цветом и примерами друзей.",
        "미리보기는 강조 색상과 예시 친구가 적용된 실제 창입니다.",
        "预览即真实窗口，使用你的强调色和示例好友。",
        "預覽即真實視窗，使用你的強調色和範例好友。",
    },
    ["Bulk Buy"] = { "Compra en lote", "Massenkauf", "Achat en gros", "Acquisto in blocco", "Compra em lote", "Оптовая покупка", "대량 구매", "批量购买", "批量購買" },
    ["Buy"] = { "Comprar", "Kaufen", "Acheter", "Compra", "Comprar", "Купить", "구매", "购买", "購買" },
    ["Max Stack: "] = { "Pila máx.: ", "Max. Stapel: ", "Pile max. : ", "Pila max: ", "Pilha máx.: ", "Макс. стопка: ", "최대 묶음: ", "最大堆叠：", "最大堆疊：" },
    ["Total: "] = { "Total: ", "Gesamt: ", "Total : ", "Totale: ", "Total: ", "Итого: ", "합계: ", "总计：", "總計：" },
    ["Load Modules"] = { "Cargar módulos", "Module laden", "Charger les modules", "Carica moduli", "Carregar módulos", "Загрузить модули", "모듈 불러오기", "加载模块", "載入模組" },
    ["Pre-Pot"] = { nil, "Vortrank", nil, nil, nil, nil, nil, nil, nil },
    ["Snapshots: %s"] = { "Instantáneas: %s", "Momentaufnahmen: %s", nil, nil, "Capturas: %s", nil, nil, nil, nil },
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

-- Arrows of the profile card pager: the same symbol in every language.
for _, localeName in ipairs(localeOrder) do
    local locale = locales[localeName]
    if locale then
        if rawget(locale, "<") == nil then locale["<"] = "<" end
        if rawget(locale, ">") == nil then locale[">"] = ">" end
    end
end
