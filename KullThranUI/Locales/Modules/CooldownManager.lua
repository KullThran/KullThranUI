-- CooldownManager translations.
-- This module is loaded after the language tables and before Generated.lua.
local _, ns = ...

local locales = ns and ns.Locales
if type(locales) ~= "table" then
    return
end

local function apply(locale, entries)
    if type(locale) ~= "table" then return end
    for key, value in pairs(entries) do
        locale[key] = value
    end
end

local entries = {
    enUS = {
        ["Global Glow Style"] = "Global Glow Style",
        ["Proc Glow (WoW)"] = "Proc Glow (WoW)",
        ["AutoCast Shine"] = "AutoCast Shine",
        ["Pixel Border"] = "Pixel Border",
        ["Cooldown Proc Glow"] = "Cooldown Proc Glow",
        ["Glow Type"] = "Glow Type",
        ["Use Global Glow"] = "Use Global Glow",
        ["Use Global Color"] = "Use Global Color",
        ["Use Global Swipe Color"] = "Use Global Swipe Color",
        ["Class Colored Glow"] = "Class Colored Glow",
        ["Selected CDM Bar:"] = "Selected CDM Bar:",
        ["Selected CDM Skill Glow"] = "Selected CDM Skill Glow",
        ["Selected Spell Glow Color"] = "Selected Spell Glow Color",
        ["Selected Spell Swipe Color"] = "Selected Spell Swipe Color",
        ["No buffs assigned. Right click the selected CDM icon in the preview to assign buffs."] = "No buffs assigned. Right click the selected CDM icon in the preview to assign buffs.",
        ["Trigger Buff Assignments for Action Button %s / %s"] = "Trigger Buff Assignments for Action Button %s / %s",
        ["Tracked Buff:"] = "Tracked Buff:",
        ["Vertical Orientation"] = "Vertical Orientation",
        ["Bar Texture"] = "Bar Texture",
        ["Icon Display"] = "Icon Display",
        ["No Icon"] = "No Icon",
        ["Show Name"] = "Show Name",
        ["Show Timer"] = "Show Timer",
        ["Gradient Fill"] = "Gradient Fill",
        ["Group Spacing"] = "Group Spacing",
        ["Group Grow Direction"] = "Group Grow Direction",
        ["Group with other bars"] = "Group with other bars",
        ["+ Add Buff Bar"] = "+ Add Buff Bar",
        ["Delete Buff Bar"] = "Delete Buff Bar",
        ["Select Buff Bar"] = "Select Buff Bar",
        ["Open Blizzard CDM"] = "Open Blizzard CDM",
        ["Important"] = "Important",
        ["No buff bars created yet. Add one to configure it here."] = "No buff bars created yet. Add one to configure it here.",
        ["Tracked buff progress bars with their own spell, size, texture and colors."] = "Tracked buff progress bars with their own spell, size, texture and colors.",
        ["Requires 2 or more grouped bars"] = "Requires 2 or more grouped bars",
        ["Choose a buff"] = "Choose a buff",
        ["Beautiful"] = "Beautiful",
        ["Plating"] = "Plating",
        ["Atrocity"] = "Atrocity",
        ["Divide"] = "Divide",
        ["Glass"] = "Glass",
        ["Gradient Right"] = "Gradient Right",
        ["Gradient Left"] = "Gradient Left",
        ["Gradient Up"] = "Gradient Up",
        ["Gradient Down"] = "Gradient Down",
        ["Matte"] = "Matte",
        ["Sheer"] = "Sheer",
    },
    esES = {
        ["Global Glow Style"] = "Estilo global de glow",
        ["Proc Glow (WoW)"] = "Glow de proc (WoW)",
        ["AutoCast Shine"] = "Brillo de autocast",
        ["Pixel Border"] = "Borde de píxeles",
        ["Cooldown Proc Glow"] = "Glow de proc de los cooldowns",
        ["Glow Type"] = "Tipo de glow",
        ["Use Global Glow"] = "Usar glow global",
        ["Use Global Color"] = "Usar color global",
        ["Use Global Swipe Color"] = "Usar color de barrido global",
        ["Class Colored Glow"] = "Glow con color de clase",
        ["Selected CDM Bar:"] = "Barra CDM seleccionada:",
        ["Selected CDM Skill Glow"] = "Glow de habilidad CDM seleccionada",
        ["Selected Spell Glow Color"] = "Color del glow del hechizo seleccionado",
        ["Selected Spell Swipe Color"] = "Color de barrido del hechizo seleccionado",
        ["No buffs assigned. Right click the selected CDM icon in the preview to assign buffs."] = "No hay buffs asignados. Haz clic derecho en el icono CDM seleccionado de la vista previa para asignarlos.",
        ["Trigger Buff Assignments for Action Button %s / %s"] = "Asignaciones de buffs activadores para el botón de acción %s / %s",
        ["Tracked Buff:"] = "Buff seguido:",
        ["Vertical Orientation"] = "Orientación vertical",
        ["Bar Texture"] = "Textura de barra",
        ["Icon Display"] = "Mostrar icono",
        ["No Icon"] = "Sin icono",
        ["Show Name"] = "Mostrar nombre",
        ["Show Timer"] = "Mostrar temporizador",
        ["Gradient Fill"] = "Relleno degradado",
        ["Group Spacing"] = "Espaciado del grupo",
        ["Group Grow Direction"] = "Dirección de crecimiento del grupo",
        ["Group with other bars"] = "Agrupar con otras barras",
        ["+ Add Buff Bar"] = "+ Añadir barra de buffs",
        ["Delete Buff Bar"] = "Eliminar barra de buffs",
        ["Select Buff Bar"] = "Seleccionar barra de buffs",
        ["Open Blizzard CDM"] = "Abrir CDM de Blizzard",
        ["Important"] = "Importante",
        ["No buff bars created yet. Add one to configure it here."] = "Aún no hay barras de buffs. Añade una para configurarla aquí.",
        ["Tracked buff progress bars with their own spell, size, texture and colors."] = "Barras de progreso para buffs seguidos, con hechizo, tamaño, textura y colores propios.",
        ["Requires 2 or more grouped bars"] = "Requiere 2 o más barras agrupadas",
        ["Choose a buff"] = "Elegir un buff",
        ["Beautiful"] = "Bonita",
        ["Plating"] = "Placa",
        ["Atrocity"] = "Atrocidad",
        ["Divide"] = "División",
        ["Glass"] = "Cristal",
        ["Gradient Right"] = "Degradado derecha",
        ["Gradient Left"] = "Degradado izquierda",
        ["Gradient Up"] = "Degradado arriba",
        ["Gradient Down"] = "Degradado abajo",
        ["Matte"] = "Mate",
        ["Sheer"] = "Transparente",
    },
    frFR = {
        ["Global Glow Style"] = "Style de lueur globale",
        ["Proc Glow (WoW)"] = "Lueur de proc (WoW)",
        ["AutoCast Shine"] = "Éclat d'autocast",
        ["Pixel Border"] = "Bordure pixelisée",
        ["Cooldown Proc Glow"] = "Lueur de proc des temps de recharge",
        ["Glow Type"] = "Type de lueur",
        ["Use Global Glow"] = "Utiliser la lueur globale",
        ["Use Global Color"] = "Utiliser la couleur globale",
        ["Use Global Swipe Color"] = "Utiliser la couleur de balayage globale",
        ["Class Colored Glow"] = "Lueur colorée par classe",
        ["Selected CDM Bar:"] = "Barre CDM sélectionnée :",
        ["Selected CDM Skill Glow"] = "Lueur de compétence CDM sélectionnée",
        ["Selected Spell Glow Color"] = "Couleur de lueur du sort sélectionné",
        ["Selected Spell Swipe Color"] = "Couleur de balayage du sort sélectionné",
        ["No buffs assigned. Right click the selected CDM icon in the preview to assign buffs."] = "Aucun buff assigné. Faites un clic droit sur l'icône CDM sélectionnée dans l'aperçu pour les assigner.",
        ["Trigger Buff Assignments for Action Button %s / %s"] = "Attributions des buffs déclencheurs pour le bouton d'action %s / %s",
        ["Tracked Buff:"] = "Buff suivi :",
        ["Vertical Orientation"] = "Orientation verticale",
        ["Bar Texture"] = "Texture de barre",
        ["Icon Display"] = "Affichage de l'icône",
        ["No Icon"] = "Aucune icône",
        ["Show Name"] = "Afficher le nom",
        ["Show Timer"] = "Afficher le minuteur",
        ["Gradient Fill"] = "Remplissage dégradé",
        ["Group Spacing"] = "Espacement du groupe",
        ["Group Grow Direction"] = "Direction de croissance du groupe",
        ["Group with other bars"] = "Grouper avec les autres barres",
        ["+ Add Buff Bar"] = "+ Ajouter une barre de buffs",
        ["Delete Buff Bar"] = "Supprimer la barre de buffs",
        ["Select Buff Bar"] = "Sélectionner une barre de buffs",
        ["Open Blizzard CDM"] = "Ouvrir le CDM de Blizzard",
        ["Important"] = "Important",
        ["No buff bars created yet. Add one to configure it here."] = "Aucune barre de buffs créée. Ajoutez-en une pour la configurer ici.",
        ["Tracked buff progress bars with their own spell, size, texture and colors."] = "Barres de progression des buffs suivis avec leur propre sort, taille, texture et couleurs.",
        ["Requires 2 or more grouped bars"] = "Nécessite au moins 2 barres groupées",
        ["Choose a buff"] = "Choisir un buff",
        ["Beautiful"] = "Belle",
        ["Plating"] = "Plaquage",
        ["Atrocity"] = "Atrocité",
        ["Divide"] = "Division",
        ["Glass"] = "Verre",
        ["Gradient Right"] = "Dégradé droite",
        ["Gradient Left"] = "Dégradé gauche",
        ["Gradient Up"] = "Dégradé haut",
        ["Gradient Down"] = "Dégradé bas",
        ["Matte"] = "Mat",
        ["Sheer"] = "Transparent",
    },
}

for locale, values in pairs(entries) do
    apply(locales[locale], values)
end

-- The remaining supported locales use the same terminology table. Values are
-- kept explicit below so each locale has a complete CDM vocabulary rather
-- than falling back to English through Generated.lua.
local shared = entries.enUS
for _, locale in ipairs({ "deDE", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }) do
    apply(locales[locale], shared)
end


entries.deDE = {
    ["Global Glow Style"] = "Globaler Leuchtstil", ["Proc Glow (WoW)"] = "Proc-Leuchten (WoW)", ["AutoCast Shine"] = "AutoCast-Glanz", ["Pixel Border"] = "Pixelrand", ["Cooldown Proc Glow"] = "Cooldown-Proc-Leuchten", ["Glow Type"] = "Leuchttyp", ["Use Global Glow"] = "Globales Leuchten verwenden", ["Use Global Color"] = "Globale Farbe verwenden", ["Use Global Swipe Color"] = "Globale Wischfarbe verwenden", ["Class Colored Glow"] = "Klassenfarbiges Leuchten",
    ["Selected CDM Bar:"] = "Ausgewählte CDM-Leiste:", ["Selected CDM Skill Glow"] = "Leuchten der ausgewählten CDM-Fähigkeit", ["Selected Spell Glow Color"] = "Leuchtfarbe des ausgewählten Zaubers", ["Selected Spell Swipe Color"] = "Wischfarbe des ausgewählten Zaubers", ["No buffs assigned. Right click the selected CDM icon in the preview to assign buffs."] = "Keine Buffs zugewiesen. Klicke mit der rechten Maustaste auf das ausgewählte CDM-Symbol in der Vorschau, um Buffs zuzuweisen.", ["Trigger Buff Assignments for Action Button %s / %s"] = "Auslöser-Buff-Zuweisungen für Aktionsbutton %s / %s", ["Tracked Buff:"] = "Verfolgter Buff:",
    ["Vertical Orientation"] = "Vertikale Ausrichtung", ["Bar Texture"] = "Leistentextur", ["Icon Display"] = "Symbolanzeige", ["No Icon"] = "Kein Symbol", ["Show Name"] = "Namen anzeigen", ["Show Timer"] = "Timer anzeigen", ["Gradient Fill"] = "Farbverlauf", ["Group Spacing"] = "Gruppenabstand", ["Group Grow Direction"] = "Wachstumsrichtung der Gruppe", ["Group with other bars"] = "Mit anderen Leisten gruppieren", ["+ Add Buff Bar"] = "+ Buff-Leiste hinzufügen", ["Delete Buff Bar"] = "Buff-Leiste löschen", ["Select Buff Bar"] = "Buff-Leiste auswählen", ["Open Blizzard CDM"] = "Blizzard-CDM öffnen", ["Important"] = "Wichtig",
    ["No buff bars created yet. Add one to configure it here."] = "Noch keine Buff-Leisten erstellt. Füge eine hinzu, um sie hier zu konfigurieren.", ["Tracked buff progress bars with their own spell, size, texture and colors."] = "Fortschrittsleisten für verfolgte Buffs mit eigenem Zauber, eigener Größe, Textur und Farbe.", ["Requires 2 or more grouped bars"] = "Erfordert mindestens 2 gruppierte Leisten", ["Choose a buff"] = "Buff auswählen", ["Beautiful"] = "Schön", ["Plating"] = "Platte", ["Atrocity"] = "Gräuel", ["Divide"] = "Teilung", ["Glass"] = "Glas", ["Gradient Right"] = "Verlauf rechts", ["Gradient Left"] = "Verlauf links", ["Gradient Up"] = "Verlauf oben", ["Gradient Down"] = "Verlauf unten", ["Matte"] = "Matt", ["Sheer"] = "Transparent",
}

entries.itIT = {
    ["Global Glow Style"] = "Stile bagliore globale", ["Proc Glow (WoW)"] = "Bagliore proc (WoW)", ["AutoCast Shine"] = "Luce AutoCast", ["Pixel Border"] = "Bordo pixel", ["Cooldown Proc Glow"] = "Bagliore proc dei cooldown", ["Glow Type"] = "Tipo di bagliore", ["Use Global Glow"] = "Usa bagliore globale", ["Use Global Color"] = "Usa colore globale", ["Use Global Swipe Color"] = "Usa colore scorrimento globale", ["Class Colored Glow"] = "Bagliore colorato per classe",
    ["Selected CDM Bar:"] = "Barra CDM selezionata:", ["Selected CDM Skill Glow"] = "Bagliore abilità CDM selezionata", ["Selected Spell Glow Color"] = "Colore bagliore incantesimo selezionato", ["Selected Spell Swipe Color"] = "Colore scorrimento incantesimo selezionato", ["No buffs assigned. Right click the selected CDM icon in the preview to assign buffs."] = "Nessun buff assegnato. Fai clic destro sull'icona CDM selezionata nell'anteprima per assegnare i buff.", ["Trigger Buff Assignments for Action Button %s / %s"] = "Assegnazioni dei buff attivatori per il pulsante d'azione %s / %s", ["Tracked Buff:"] = "Buff monitorato:",
    ["Vertical Orientation"] = "Orientamento verticale", ["Bar Texture"] = "Texture barra", ["Icon Display"] = "Visualizzazione icona", ["No Icon"] = "Nessuna icona", ["Show Name"] = "Mostra nome", ["Show Timer"] = "Mostra timer", ["Gradient Fill"] = "Riempimento sfumato", ["Group Spacing"] = "Spaziatura gruppo", ["Group Grow Direction"] = "Direzione crescita gruppo", ["Group with other bars"] = "Raggruppa con le altre barre", ["+ Add Buff Bar"] = "+ Aggiungi barra buff", ["Delete Buff Bar"] = "Elimina barra buff", ["Select Buff Bar"] = "Seleziona barra buff", ["Open Blizzard CDM"] = "Apri CDM Blizzard", ["Important"] = "Importante",
    ["No buff bars created yet. Add one to configure it here."] = "Non è stata ancora creata alcuna barra buff. Aggiungine una per configurarla qui.", ["Tracked buff progress bars with their own spell, size, texture and colors."] = "Barre di avanzamento per buff monitorati con incantesimo, dimensioni, texture e colori propri.", ["Requires 2 or more grouped bars"] = "Richiede almeno 2 barre raggruppate", ["Choose a buff"] = "Scegli un buff", ["Beautiful"] = "Bella", ["Plating"] = "Placcatura", ["Atrocity"] = "Atrocità", ["Divide"] = "Divisione", ["Glass"] = "Vetro", ["Gradient Right"] = "Sfumatura a destra", ["Gradient Left"] = "Sfumatura a sinistra", ["Gradient Up"] = "Sfumatura in alto", ["Gradient Down"] = "Sfumatura in basso", ["Matte"] = "Opaca", ["Sheer"] = "Trasparente",
}

entries.ptBR = {
    ["Global Glow Style"] = "Estilo de brilho global", ["Proc Glow (WoW)"] = "Brilho de proc (WoW)", ["AutoCast Shine"] = "Brilho de AutoCast", ["Pixel Border"] = "Borda de pixels", ["Cooldown Proc Glow"] = "Brilho de proc dos recargas", ["Glow Type"] = "Tipo de brilho", ["Use Global Glow"] = "Usar brilho global", ["Use Global Color"] = "Usar cor global", ["Use Global Swipe Color"] = "Usar cor de varredura global", ["Class Colored Glow"] = "Brilho com cor de classe",
    ["Selected CDM Bar:"] = "Barra de CDM selecionada:", ["Selected CDM Skill Glow"] = "Brilho da habilidade de CDM selecionada", ["Selected Spell Glow Color"] = "Cor do brilho do feitiço selecionado", ["Selected Spell Swipe Color"] = "Cor de varredura do feitiço selecionado", ["No buffs assigned. Right click the selected CDM icon in the preview to assign buffs."] = "Nenhum buff atribuído. Clique com o botão direito no ícone de CDM selecionado na visualização para atribuir buffs.", ["Trigger Buff Assignments for Action Button %s / %s"] = "Atribuições de buffs ativadores para o botão de ação %s / %s", ["Tracked Buff:"] = "Buff rastreado:",
    ["Vertical Orientation"] = "Orientação vertical", ["Bar Texture"] = "Textura da barra", ["Icon Display"] = "Exibição do ícone", ["No Icon"] = "Sem ícone", ["Show Name"] = "Mostrar nome", ["Show Timer"] = "Mostrar cronômetro", ["Gradient Fill"] = "Preenchimento gradiente", ["Group Spacing"] = "Espaçamento do grupo", ["Group Grow Direction"] = "Direção de crescimento do grupo", ["Group with other bars"] = "Agrupar com outras barras", ["+ Add Buff Bar"] = "+ Adicionar barra de buffs", ["Delete Buff Bar"] = "Excluir barra de buffs", ["Select Buff Bar"] = "Selecionar barra de buffs", ["Open Blizzard CDM"] = "Abrir CDM da Blizzard", ["Important"] = "Importante",
    ["No buff bars created yet. Add one to configure it here."] = "Nenhuma barra de buffs foi criada. Adicione uma para configurá-la aqui.", ["Tracked buff progress bars with their own spell, size, texture and colors."] = "Barras de progresso de buffs rastreados com feitiço, tamanho, textura e cores próprias.", ["Requires 2 or more grouped bars"] = "Requer 2 ou mais barras agrupadas", ["Choose a buff"] = "Escolha um buff", ["Beautiful"] = "Bonita", ["Plating"] = "Placa", ["Atrocity"] = "Atrocidade", ["Divide"] = "Divisão", ["Glass"] = "Vidro", ["Gradient Right"] = "Gradiente à direita", ["Gradient Left"] = "Gradiente à esquerda", ["Gradient Up"] = "Gradiente para cima", ["Gradient Down"] = "Gradiente para baixo", ["Matte"] = "Fosca", ["Sheer"] = "Transparente",
}

for _, locale in ipairs({ "deDE", "itIT", "ptBR" }) do
    apply(locales[locale], entries[locale])
end

entries.ruRU = {
    ["Global Glow Style"] = "Стиль глобального свечения", ["Proc Glow (WoW)"] = "Свечение прока (WoW)", ["AutoCast Shine"] = "Сияние AutoCast", ["Pixel Border"] = "Пиксельная рамка", ["Cooldown Proc Glow"] = "Свечение прока восстановления", ["Glow Type"] = "Тип свечения", ["Use Global Glow"] = "Использовать глобальное свечение", ["Use Global Color"] = "Использовать глобальный цвет", ["Use Global Swipe Color"] = "Использовать глобальный цвет смахивания", ["Class Colored Glow"] = "Свечение цвета класса",
    ["Selected CDM Bar:"] = "Выбранная панель CDM:", ["Selected CDM Skill Glow"] = "Свечение выбранного навыка CDM", ["Selected Spell Glow Color"] = "Цвет свечения выбранного заклинания", ["Selected Spell Swipe Color"] = "Цвет смахивания выбранного заклинания", ["No buffs assigned. Right click the selected CDM icon in the preview to assign buffs."] = "Баффы не назначены. Нажмите правой кнопкой по выбранному значку CDM в предпросмотре, чтобы назначить баффы.", ["Trigger Buff Assignments for Action Button %s / %s"] = "Назначение баффов-триггеров для кнопки действия %s / %s", ["Tracked Buff:"] = "Отслеживаемый бафф:",
    ["Vertical Orientation"] = "Вертикальная ориентация", ["Bar Texture"] = "Текстура панели", ["Icon Display"] = "Отображение значка", ["No Icon"] = "Без значка", ["Show Name"] = "Показывать название", ["Show Timer"] = "Показывать таймер", ["Gradient Fill"] = "Градиентная заливка", ["Group Spacing"] = "Интервал группы", ["Group Grow Direction"] = "Направление роста группы", ["Group with other bars"] = "Группировать с другими панелями", ["+ Add Buff Bar"] = "+ Добавить панель баффов", ["Delete Buff Bar"] = "Удалить панель баффов", ["Select Buff Bar"] = "Выбрать панель баффов", ["Open Blizzard CDM"] = "Открыть CDM Blizzard", ["Important"] = "Важно",
    ["No buff bars created yet. Add one to configure it here."] = "Панели баффов ещё не созданы. Добавьте панель, чтобы настроить её здесь.", ["Tracked buff progress bars with their own spell, size, texture and colors."] = "Индикаторы отслеживаемых баффов со своими заклинанием, размером, текстурой и цветами.", ["Requires 2 or more grouped bars"] = "Требуется 2 или более сгруппированных панелей", ["Choose a buff"] = "Выберите бафф", ["Beautiful"] = "Красивый", ["Plating"] = "Пластина", ["Atrocity"] = "Злодеяние", ["Divide"] = "Разделение", ["Glass"] = "Стекло", ["Gradient Right"] = "Градиент вправо", ["Gradient Left"] = "Градиент влево", ["Gradient Up"] = "Градиент вверх", ["Gradient Down"] = "Градиент вниз", ["Matte"] = "Матовый", ["Sheer"] = "Прозрачный",
}

entries.koKR = {
    ["Global Glow Style"] = "전체 반짝임 방식", ["Proc Glow (WoW)"] = "발동 반짝임 (WoW)", ["AutoCast Shine"] = "자동 시전 빛남", ["Pixel Border"] = "픽셀 테두리", ["Cooldown Proc Glow"] = "재사용 대기시간 발동 반짝임", ["Glow Type"] = "반짝임 유형", ["Use Global Glow"] = "전체 반짝임 사용", ["Use Global Color"] = "전체 색상 사용", ["Use Global Swipe Color"] = "전체 스와이프 색상 사용", ["Class Colored Glow"] = "직업 색상 반짝임",
    ["Selected CDM Bar:"] = "선택한 CDM 바:", ["Selected CDM Skill Glow"] = "선택한 CDM 기술 반짝임", ["Selected Spell Glow Color"] = "선택한 주문 반짝임 색상", ["Selected Spell Swipe Color"] = "선택한 주문 스와이프 색상", ["No buffs assigned. Right click the selected CDM icon in the preview to assign buffs."] = "지정된 버프가 없습니다. 미리보기에서 선택한 CDM 아이콘을 우클릭하여 버프를 지정하세요.", ["Trigger Buff Assignments for Action Button %s / %s"] = "행동 단축바 %s / %s의 발동 버프 지정", ["Tracked Buff:"] = "추적 버프:",
    ["Vertical Orientation"] = "세로 방향", ["Bar Texture"] = "바 텍스처", ["Icon Display"] = "아이콘 표시", ["No Icon"] = "아이콘 없음", ["Show Name"] = "이름 표시", ["Show Timer"] = "타이머 표시", ["Gradient Fill"] = "그라데이션 채우기", ["Group Spacing"] = "그룹 간격", ["Group Grow Direction"] = "그룹 확장 방향", ["Group with other bars"] = "다른 바와 그룹화", ["+ Add Buff Bar"] = "+ 버프 바 추가", ["Delete Buff Bar"] = "버프 바 삭제", ["Select Buff Bar"] = "버프 바 선택", ["Open Blizzard CDM"] = "블리자드 CDM 열기", ["Important"] = "중요",
    ["No buff bars created yet. Add one to configure it here."] = "아직 버프 바가 없습니다. 여기서 설정하려면 하나 추가하세요.", ["Tracked buff progress bars with their own spell, size, texture and colors."] = "주문, 크기, 텍스처 및 색상을 개별 설정하는 추적 버프 진행 바입니다.", ["Requires 2 or more grouped bars"] = "그룹화된 바가 2개 이상 필요합니다", ["Choose a buff"] = "버프 선택", ["Beautiful"] = "아름다운", ["Plating"] = "도금", ["Atrocity"] = "악행", ["Divide"] = "분할", ["Glass"] = "유리", ["Gradient Right"] = "오른쪽 그라데이션", ["Gradient Left"] = "왼쪽 그라데이션", ["Gradient Up"] = "위쪽 그라데이션", ["Gradient Down"] = "아래쪽 그라데이션", ["Matte"] = "무광", ["Sheer"] = "투명",
}

for _, locale in ipairs({ "ruRU", "koKR" }) do
    apply(locales[locale], entries[locale])
end

entries.zhCN = {
    ["Global Glow Style"] = "全局发光样式", ["Proc Glow (WoW)"] = "触发发光（WoW）", ["AutoCast Shine"] = "自动施法闪光", ["Pixel Border"] = "像素边框", ["Cooldown Proc Glow"] = "冷却触发发光", ["Glow Type"] = "发光类型", ["Use Global Glow"] = "使用全局发光", ["Use Global Color"] = "使用全局颜色", ["Use Global Swipe Color"] = "使用全局扫掠颜色", ["Class Colored Glow"] = "职业颜色发光",
    ["Selected CDM Bar:"] = "选中的 CDM 条：", ["Selected CDM Skill Glow"] = "选中 CDM 技能发光", ["Selected Spell Glow Color"] = "选中法术发光颜色", ["Selected Spell Swipe Color"] = "选中法术扫掠颜色", ["No buffs assigned. Right click the selected CDM icon in the preview to assign buffs."] = "未分配增益。右键点击预览中的 CDM 图标即可分配增益。", ["Trigger Buff Assignments for Action Button %s / %s"] = "动作按钮 %s / %s 的触发增益分配", ["Tracked Buff:"] = "追踪增益：",
    ["Vertical Orientation"] = "垂直方向", ["Bar Texture"] = "条纹理", ["Icon Display"] = "图标显示", ["No Icon"] = "无图标", ["Show Name"] = "显示名称", ["Show Timer"] = "显示计时器", ["Gradient Fill"] = "渐变填充", ["Group Spacing"] = "组间距", ["Group Grow Direction"] = "组增长方向", ["Group with other bars"] = "与其他条组合", ["+ Add Buff Bar"] = "+ 添加增益条", ["Delete Buff Bar"] = "删除增益条", ["Select Buff Bar"] = "选择增益条", ["Open Blizzard CDM"] = "打开暴雪 CDM", ["Important"] = "重要",
    ["No buff bars created yet. Add one to configure it here."] = "尚未创建增益条。添加一个即可在此配置。", ["Tracked buff progress bars with their own spell, size, texture and colors."] = "拥有独立法术、大小、纹理和颜色的追踪增益进度条。", ["Requires 2 or more grouped bars"] = "需要至少 2 个组合条", ["Choose a buff"] = "选择增益", ["Beautiful"] = "漂亮", ["Plating"] = "金属板", ["Atrocity"] = "暴行", ["Divide"] = "分割", ["Glass"] = "玻璃", ["Gradient Right"] = "向右渐变", ["Gradient Left"] = "向左渐变", ["Gradient Up"] = "向上渐变", ["Gradient Down"] = "向下渐变", ["Matte"] = "哑光", ["Sheer"] = "透明",
}

entries.zhTW = {
    ["Global Glow Style"] = "全域發光樣式", ["Proc Glow (WoW)"] = "觸發發光（WoW）", ["AutoCast Shine"] = "自動施法閃光", ["Pixel Border"] = "像素邊框", ["Cooldown Proc Glow"] = "冷卻觸發發光", ["Glow Type"] = "發光類型", ["Use Global Glow"] = "使用全域發光", ["Use Global Color"] = "使用全域顏色", ["Use Global Swipe Color"] = "使用全域掃掠顏色", ["Class Colored Glow"] = "職業顏色發光",
    ["Selected CDM Bar:"] = "選取的 CDM 條：", ["Selected CDM Skill Glow"] = "選取 CDM 技能發光", ["Selected Spell Glow Color"] = "選取法術發光顏色", ["Selected Spell Swipe Color"] = "選取法術掃掠顏色", ["No buffs assigned. Right click the selected CDM icon in the preview to assign buffs."] = "尚未指定增益。右鍵點擊預覽中的 CDM 圖示即可指定增益。", ["Trigger Buff Assignments for Action Button %s / %s"] = "動作按鈕 %s / %s 的觸發增益指定", ["Tracked Buff:"] = "追蹤增益：",
    ["Vertical Orientation"] = "垂直方向", ["Bar Texture"] = "條紋理", ["Icon Display"] = "圖示顯示", ["No Icon"] = "無圖示", ["Show Name"] = "顯示名稱", ["Show Timer"] = "顯示計時器", ["Gradient Fill"] = "漸層填色", ["Group Spacing"] = "群組間距", ["Group Grow Direction"] = "群組增長方向", ["Group with other bars"] = "與其他條組合", ["+ Add Buff Bar"] = "+ 新增增益條", ["Delete Buff Bar"] = "刪除增益條", ["Select Buff Bar"] = "選擇增益條", ["Open Blizzard CDM"] = "開啟暴雪 CDM", ["Important"] = "重要",
    ["No buff bars created yet. Add one to configure it here."] = "尚未建立增益條。新增一個即可在此設定。", ["Tracked buff progress bars with their own spell, size, texture and colors."] = "擁有獨立法術、大小、紋理和顏色的追蹤增益進度條。", ["Requires 2 or more grouped bars"] = "需要至少 2 個組合條", ["Choose a buff"] = "選擇增益", ["Beautiful"] = "漂亮", ["Plating"] = "金屬板", ["Atrocity"] = "暴行", ["Divide"] = "分割", ["Glass"] = "玻璃", ["Gradient Right"] = "向右漸層", ["Gradient Left"] = "向左漸層", ["Gradient Up"] = "向上漸層", ["Gradient Down"] = "向下漸層", ["Matte"] = "霧面", ["Sheer"] = "透明",
}

for _, locale in ipairs({ "zhCN", "zhTW" }) do
    apply(locales[locale], entries[locale])
end
apply(locales.esMX, entries.esES)

local cdmKeybindLocales = {
    enUS = "Show Keybinds",
    esES = "Mostrar atajos",
    deDE = "Tastenbelegungen anzeigen",
    frFR = "Afficher les raccourcis",
    itIT = "Mostra tasti di scelta rapida",
    ptBR = "Mostrar atalhos",
    ruRU = "Показывать клавиши",
    koKR = "키 할당 표시",
    zhCN = "显示快捷键",
    zhTW = "顯示快捷鍵",
}
for locale, translated in pairs(cdmKeybindLocales) do
    if type(locales[locale]) == "table" then locales[locale]["Show Keybinds"] = translated end
end
if type(locales.esMX) == "table" then locales.esMX["Show Keybinds"] = cdmKeybindLocales.esES end

local cdmExtraKeys = {
    "Icon Display","Active State","Active Animation","Blizzard Default","None","Hide When Active","Pixel Glow","Custom Shape Glow","Action Button Glow","Auto-Cast Shine","Class Color Glow","Glow Color","Swipe","Active Swipe Uses Glow Color","Swipe Alpha","Swipe Color","Texts & Misc","Show Duration Text","Show Charges","Duration Font Size","Charge Count Font Size","Keybind Text","Show Keybinds","Keybind Font Size","Keybind Outline","Misc","Assisted Combat Highlight","Button Press Highlight","Desaturate on Cooldown","Show Tooltip on Hover","Hide GCD Swipe","Hide Buffs When Inactive","Custom Icon Shape","Cropped","Square","Circle","Curved Square","Diamond","Hexagon","Portrait","Shield","Border Size","Thin","Medium","Thick","Border Color","Class Color Border","Text & Keybinds","Active & Swipe","Icon Scale","Icon Spacing",
}
local cdmExtra = {
 enUS={"Icon Display","Active State","Active Animation","Blizzard Default","None","Hide When Active","Pixel Glow","Custom Shape Glow","Action Button Glow","Auto-Cast Shine","Class Color Glow","Glow Color","Swipe","Active Swipe Uses Glow Color","Swipe Alpha","Swipe Color","Texts & Misc","Show Duration Text","Show Charges","Duration Font Size","Charge Count Font Size","Keybind Text","Show Keybinds","Keybind Font Size","Keybind Outline","Misc","Assisted Combat Highlight","Button Press Highlight","Desaturate on Cooldown","Show Tooltip on Hover","Hide GCD Swipe","Hide Buffs When Inactive","Custom Icon Shape","Cropped","Square","Circle","Curved Square","Diamond","Hexagon","Portrait","Shield","Border Size","Thin","Medium","Thick","Border Color","Class Color Border","Text & Keybinds","Active & Swipe","Icon Scale","Icon Spacing"},
 esES={"Mostrar iconos","Estado activo","Animación activa","Predeterminado de Blizzard","Ninguno","Ocultar al estar activo","Resplandor de píxeles","Resplandor de forma personalizada","Resplandor del botón de acción","Brillo de autocast","Resplandor del color de clase","Color del resplandor","Barrido","El barrido activo usa el color del resplandor","Opacidad del barrido","Color del barrido","Texto y varios","Mostrar texto de duración","Mostrar cargas","Tamaño de fuente de duración","Tamaño de fuente de cargas","Texto de atajos","Mostrar atajos","Tamaño de fuente de atajos","Contorno de atajos","Varios","Resaltado de combate asistido","Resaltado al pulsar el botón","Desaturar en tiempo de reutilización","Mostrar tooltip al pasar el ratón","Ocultar barrido del GCD","Ocultar buffs inactivos","Forma de icono personalizada","Recortado","Cuadrado","Círculo","Cuadrado curvado","Diamante","Hexágono","Retrato","Escudo","Tamaño del borde","Fino","Medio","Grueso","Color del borde","Borde con color de clase","Texto y atajos","Activo y barrido","Escala del icono","Espaciado de iconos"},
 deDE={"Symbolanzeige","Aktiver Status","Aktive Animation","Blizzard-Standard","Keine","Bei Aktivität ausblenden","Pixel-Leuchten","Leuchten für benutzerdefinierte Form","Aktionsbutton-Leuchten","AutoCast-Glanz","Klassenfarben-Leuchten","Leuchtfarbe","Wischen","Aktives Wischen verwendet Leuchtfarbe","Wischtransparenz","Wischfarbe","Text & Sonstiges","Dauertext anzeigen","Aufladungen anzeigen","Schriftgröße der Dauer","Schriftgröße der Aufladungen","Tastenbelegungstext","Tastenbelegungen anzeigen","Schriftgröße der Tastenbelegung","Umrandung der Tastenbelegung","Sonstiges","Hervorhebung des unterstützten Kampfes","Hervorhebung beim Tastendruck","Bei Abklingzeit entsättigen","Tooltip beim Darüberfahren anzeigen","GCD-Wischen ausblenden","Inaktive Buffs ausblenden","Benutzerdefinierte Symbolform","Zugeschnitten","Quadrat","Kreis","Abgerundetes Quadrat","Diamant","Sechseck","Porträt","Schild","Rahmengröße","Dünn","Mittel","Dick","Rahmenfarbe","Klassenfarbiger Rahmen","Text & Tastenbelegungen","Aktiv & Wischen","Symbolskalierung","Symbolabstand"},
 frFR={"Affichage des icônes","État actif","Animation active","Défaut Blizzard","Aucune","Masquer quand actif","Lueur pixelisée","Lueur de forme personnalisée","Lueur de bouton d’action","Éclat d’autocast","Lueur de couleur de classe","Couleur de lueur","Balayage","Le balayage actif utilise la couleur de lueur","Opacité du balayage","Couleur du balayage","Texte et divers","Afficher le texte de durée","Afficher les charges","Taille du texte de durée","Taille du texte des charges","Texte des raccourcis","Afficher les raccourcis","Taille du texte des raccourcis","Contour des raccourcis","Divers","Surlignage du combat assisté","Surlignage de pression du bouton","Désaturer pendant la recharge","Afficher l’infobulle au survol","Masquer le balayage du GCD","Masquer les buffs inactifs","Forme d’icône personnalisée","Rogner","Carré","Cercle","Carré arrondi","Losange","Hexagone","Portrait","Bouclier","Taille de bordure","Fine","Moyenne","Épaisse","Couleur de bordure","Bordure aux couleurs de classe","Texte et raccourcis","Actif et balayage","Échelle de l’icône","Espacement des icônes"},
 itIT={"Visualizzazione icone","Stato attivo","Animazione attiva","Predefinito Blizzard","Nessuno","Nascondi quando attivo","Bagliore pixel","Bagliore forma personalizzata","Bagliore del pulsante d’azione","Luce AutoCast","Bagliore colore classe","Colore bagliore","Scorrimento","Lo scorrimento attivo usa il colore del bagliore","Alfa scorrimento","Colore scorrimento","Testo e varie","Mostra testo durata","Mostra cariche","Dimensione testo durata","Dimensione testo cariche","Testo tasti di scelta rapida","Mostra tasti di scelta rapida","Dimensione testo tasti","Contorno tasti","Varie","Evidenziazione combattimento assistito","Evidenziazione pressione pulsante","Desatura durante il recupero","Mostra tooltip al passaggio","Nascondi scorrimento GCD","Nascondi buff inattivi","Forma icona personalizzata","Ritagliata","Quadrato","Cerchio","Quadrato curvo","Rombo","Esagono","Ritratto","Scudo","Dimensione bordo","Sottile","Media","Spessa","Colore bordo","Bordo colore classe","Testo e tasti","Attivo e scorrimento","Scala icona","Spaziatura icone"},
 ptBR={"Exibição de ícones","Estado ativo","Animação ativa","Padrão da Blizzard","Nenhum","Ocultar quando ativo","Brilho de pixels","Brilho de forma personalizada","Brilho do botão de ação","Brilho de lançamento automático","Brilho da cor de classe","Cor do brilho","Varredura","A varredura ativa usa a cor do brilho","Alfa da varredura","Cor da varredura","Texto e diversos","Mostrar texto de duração","Mostrar cargas","Tamanho do texto de duração","Tamanho do texto de cargas","Texto de atalhos","Mostrar atalhos","Tamanho do texto de atalhos","Contorno dos atalhos","Diversos","Destaque de combate assistido","Destaque ao pressionar botão","Desaturar durante recarga","Mostrar tooltip ao passar o mouse","Ocultar varredura do GCD","Ocultar buffs inativos","Forma de ícone personalizada","Recortado","Quadrado","Círculo","Quadrado curvo","Losango","Hexágono","Retrato","Escudo","Tamanho da borda","Fina","Média","Grossa","Cor da borda","Borda com cor de classe","Texto e atalhos","Ativo e varredura","Escala do ícone","Espaçamento dos ícones"},
 ruRU={"Отображение значков","Активное состояние","Активная анимация","По умолчанию Blizzard","Нет","Скрывать при активности","Пиксельное свечение","Свечение пользовательской формы","Свечение кнопки действия","Сияние автоприменения","Свечение цвета класса","Цвет свечения","Смахивание","Активное смахивание использует цвет свечения","Прозрачность смахивания","Цвет смахивания","Текст и прочее","Показывать текст длительности","Показывать заряды","Размер текста длительности","Размер текста зарядов","Текст клавиш","Показывать клавиши","Размер текста клавиш","Контур клавиш","Прочее","Подсветка вспомогательного боя","Подсветка нажатия кнопки","Обесцвечивать во время восстановления","Показывать подсказку при наведении","Скрывать смахивание ГКД","Скрывать неактивные баффы","Пользовательская форма значка","Обрезанный","Квадрат","Круг","Скруглённый квадрат","Ромб","Шестиугольник","Портрет","Щит","Размер рамки","Тонкая","Средняя","Толстая","Цвет рамки","Рамка цвета класса","Текст и клавиши","Активное и смахивание","Масштаб значка","Интервал значков"},
 koKR={"아이콘 표시","활성 상태","활성 애니메이션","블리자드 기본값","없음","활성화 시 숨김","픽셀 반짝임","사용자 지정 모양 반짝임","행동 단추 반짝임","자동 시전 빛남","직업 색상 반짝임","반짝임 색상","스와이프","활성 스와이프에 반짝임 색상 사용","스와이프 알파","스와이프 색상","텍스트 및 기타","지속시간 텍스트 표시","충전 횟수 표시","지속시간 글자 크기","충전 횟수 글자 크기","키 할당 텍스트","키 할당 표시","키 할당 글자 크기","키 할당 테두리","기타","지원 전투 강조","단추 누름 강조","재사용 대기시간 중 탈채색","마우스 오버 시 툴팁 표시","GCD 스와이프 숨김","비활성 버프 숨김","사용자 지정 아이콘 모양","자르기","정사각형","원","곡선 사각형","마름모","육각형","초상화","방패","테두리 크기","얇게","중간","굵게","테두리 색상","직업 색상 테두리","텍스트 및 키 할당","활성 및 스와이프","아이콘 크기","아이콘 간격"},
 zhCN={"图标显示","激活状态","激活动画","暴雪默认","无","激活时隐藏","像素发光","自定义形状发光","动作按钮发光","自动施法闪光","职业颜色发光","发光颜色","扫掠","激活扫掠使用发光颜色","扫掠透明度","扫掠颜色","文字与杂项","显示持续时间文字","显示充能","持续时间字体大小","充能字体大小","快捷键文字","显示快捷键","快捷键字体大小","快捷键描边","杂项","辅助战斗高亮","按钮按下高亮","冷却时降低饱和度","鼠标悬停时显示提示","隐藏 GCD 扫掠","隐藏非激活增益","自定义图标形状","裁剪","正方形","圆形","弧形方框","菱形","六边形","头像","盾牌","边框大小","细","中","粗","边框颜色","职业颜色边框","文字与快捷键","激活与扫掠","图标缩放","图标间距"},
 zhTW={"圖示顯示","啟用狀態","啟用動畫","暴雪預設","無","啟用時隱藏","像素發光","自訂形狀發光","動作按鈕發光","自動施法閃光","職業顏色發光","發光顏色","掃掠","啟用掃掠使用發光顏色","掃掠透明度","掃掠顏色","文字與其他","顯示持續時間文字","顯示充能","持續時間文字大小","充能文字大小","快捷鍵文字","顯示快捷鍵","快捷鍵文字大小","快捷鍵外框","其他","輔助戰鬥強調","按鈕按下強調","冷卻時降低飽和度","滑鼠停留時顯示提示","隱藏 GCD 掃掠","隱藏未啟用增益","自訂圖示形狀","裁切","正方形","圓形","弧形方框","菱形","六邊形","頭像","盾牌","邊框大小","細","中","粗","邊框顏色","職業顏色邊框","文字與快捷鍵","啟用與掃掠","圖示縮放","圖示間距"},
}
for locale, translated in pairs(cdmExtra) do
    local target = locales[locale]
    if type(target) == "table" then
        for index, key in ipairs(cdmExtraKeys) do target[key] = translated[index] end
    end
end
if type(locales.esMX) == "table" then
    for index, key in ipairs(cdmExtraKeys) do locales.esMX[key] = cdmExtra.esES[index] end
end

local cdmLayoutKeys = {"CDM Bars","Live Layout Preview","Bar Layout","Anchored To","Anchor Position","Global Bar Scale","Frame Strata","Hide When...","Condition Match Mode","Background","Low","Medium (Default)","High","Dialog","Tooltip","Bar Glows"}
local cdmLayout = {
 enUS={"CDM Bars","Live Layout Preview","Bar Layout","Anchored To","Anchor Position","Global Bar Scale","Frame Strata","Hide When...","Condition Match Mode","Background","Low","Medium (Default)","High","Dialog","Tooltip","Bar Glows"},
 esES={"Barras CDM","Vista previa del diseño en vivo","Diseño de barra","Anclado a","Posición del ancla","Escala global de barra","Capa del marco","Ocultar cuando...","Modo de coincidencia de condiciones","Fondo","Bajo","Medio (predeterminado)","Alto","Diálogo","Tooltip","Resplandores de barra"},
 deDE={"CDM-Leisten","Live-Layout-Vorschau","Leistenlayout","Verankert an","Ankerposition","Globale Leistenskalierung","Rahmenebene","Ausblenden wenn ...","Bedingungsübereinstimmung","Hintergrund","Niedrig","Mittel (Standard)","Hoch","Dialog","Tooltip","Leuchten der Leiste"},
 frFR={"Barres CDM","Aperçu de la disposition en direct","Disposition de barre","Ancré à","Position de l’ancre","Échelle globale des barres","Couche du cadre","Masquer quand...","Mode de correspondance des conditions","Arrière-plan","Bas","Moyen (par défaut)","Haut","Dialogue","Infobulle","Lueurs de barre"},
 itIT={"Barre CDM","Anteprima layout dal vivo","Layout barra","Ancorato a","Posizione ancora","Scala globale barra","Livello cornice","Nascondi quando...","Modalità corrispondenza condizioni","Sfondo","Basso","Medio (predefinito)","Alto","Dialogo","Tooltip","Bagliori barra"},
 ptBR={"Barras de CDM","Visualização do layout ao vivo","Layout da barra","Ancorado a","Posição da âncora","Escala global da barra","Camada do quadro","Ocultar quando...","Modo de correspondência de condições","Fundo","Baixo","Médio (padrão)","Alto","Diálogo","Tooltip","Brilhos da barra"},
 ruRU={"Панели CDM","Предпросмотр макета в реальном времени","Макет панели","Привязано к","Положение привязки","Общий масштаб панели","Слой рамки","Скрывать при...","Режим соответствия условий","Фон","Низкий","Средний (по умолчанию)","Высокий","Диалог","Подсказка","Свечение панели"},
 koKR={"CDM 바","실시간 배치 미리보기","바 배치","고정 대상","고정 위치","전체 바 배율","프레임 계층","다음 조건에서 숨김...","조건 일치 방식","배경","낮음","중간(기본값)","높음","대화상자","툴팁","바 반짝임"},
 zhCN={"CDM 条","实时布局预览","条布局","锚定到","锚点位置","全局条缩放","框架层级","隐藏条件...","条件匹配模式","背景","低","中（默认）","高","对话框","提示","条发光"},
 zhTW={"CDM 條","即時版面預覽","條列版面","錨定至","錨點位置","全域條列縮放","框架圖層","隱藏條件...","條件符合模式","背景","低","中（預設）","高","對話框","提示","條列發光"},
}
for locale, translated in pairs(cdmLayout) do
    local target = locales[locale]
    if type(target) == "table" then for index, key in ipairs(cdmLayoutKeys) do target[key] = translated[index] end end
end
if type(locales.esMX) == "table" then for index, key in ipairs(cdmLayoutKeys) do locales.esMX[key] = cdmLayout.esES[index] end end


local cdmBarRuleKeys = {
    "New Custom Bar Category", "Bar Opacity", "Visibility", "Always", "In Combat", "Mouseover", "Never",
    "Cooldowns", "Utility", "Buffs", "Hide Rules", "Visibility Rules",
    "Match Any (hide if any condition met)", "Match All (hide if all met)",
    "Always (Disabled)", "While Casting", "Not Casting", "Out of Combat", "Boss Encounter",
    "In Instance", "In Vehicle / Taxi", "Mounted", "Flying", "Skyriding", "Swimming",
    "Resting (City/Inn)", "Dead / Ghost", "Has Target", "No Target", "In Group",
    "Solo (Not in Group)", "In Raid", "PvP Flagged", "Stealthed", "In Pet Battle",
}
local cdmBarRuleLocales = {
    enUS = {
        "New Custom Bar Category", "Bar Opacity", "Visibility", "Always", "In Combat", "Mouseover", "Never",
        "Cooldowns", "Utility", "Buffs", "Hide Rules", "Visibility Rules",
        "Match Any (hide if any condition met)", "Match All (hide if all met)",
        "Always (Disabled)", "While Casting", "Not Casting", "Out of Combat", "Boss Encounter",
        "In Instance", "In Vehicle / Taxi", "Mounted", "Flying", "Skyriding", "Swimming",
        "Resting (City/Inn)", "Dead / Ghost", "Has Target", "No Target", "In Group",
        "Solo (Not in Group)", "In Raid", "PvP Flagged", "Stealthed", "In Pet Battle",
    },
    esES = {
        "Nueva categoría de barra personalizada", "Opacidad de barra", "Visibilidad", "Siempre", "En combate", "Al pasar el ratón", "Nunca",
        "Enfriamientos", "Utilidad", "Beneficios", "Reglas de ocultación", "Reglas de visibilidad",
        "Coincidir con cualquiera (ocultar si se cumple alguna condición)", "Coincidir con todas (ocultar si se cumplen todas las condiciones)",
        "Siempre (desactivado)", "Mientras lanzas", "No lanzando", "Fuera de combate", "Encuentro con jefe",
        "En instancia", "En vehículo / taxi", "Montado", "Volando", "Vuelo dinámico", "Nadando",
        "Descansando (ciudad/posada)", "Muerto / fantasma", "Tiene objetivo", "Sin objetivo", "En grupo",
        "Solo (sin grupo)", "En banda", "Marcado para JcJ", "En sigilo", "En batalla de mascotas",
    },
    deDE = {
        "Neue benutzerdefinierte Leistenkategorie", "Leistentransparenz", "Sichtbarkeit", "Immer", "Im Kampf", "Mouseover", "Nie",
        "Abklingzeiten", "Hilfsmittel", "Stärkungen", "Ausblendregeln", "Sichtbarkeitsregeln",
        "Beliebige Übereinstimmung (ausblenden, wenn eine Bedingung erfüllt ist)", "Alle Übereinstimmungen (ausblenden, wenn alle erfüllt sind)",
        "Immer (deaktiviert)", "Während des Wirkens", "Wirkt nicht", "Außerhalb des Kampfes", "Bossbegegnung",
        "In Instanz", "Im Fahrzeug / Taxi", "Beritten", "Fliegend", "Himmelsreiten", "Schwimmend",
        "Ruhend (Stadt/Gasthaus)", "Tot / Geist", "Ziel vorhanden", "Kein Ziel", "In Gruppe",
        "Solo (nicht in Gruppe)", "Im Schlachtzug", "PvP-markiert", "Verstohlen", "Im Haustierkampf",
    },
    frFR = {
        "Nouvelle catégorie de barre personnalisée", "Opacité de la barre", "Visibilité", "Toujours", "En combat", "Survol", "Jamais",
        "Temps de recharge", "Utilitaire", "Améliorations", "Règles de masquage", "Règles de visibilité",
        "Correspondance quelconque (masquer si une condition est remplie)", "Correspondance complète (masquer si toutes les conditions sont remplies)",
        "Toujours (désactivé)", "Pendant l’incantation", "Pas d’incantation", "Hors combat", "Combat de boss",
        "En instance", "En véhicule / taxi", "À monture", "En vol", "Vol dynamique", "À la nage",
        "Au repos (ville/auberge)", "Mort / fantôme", "A une cible", "Aucune cible", "En groupe",
        "Solo (sans groupe)", "En raid", "Marqué JcJ", "Camouflé", "En combat de mascottes",
    },
    itIT = {
        "Nuova categoria barra personalizzata", "Opacità barra", "Visibilità", "Sempre", "In combattimento", "Mouseover", "Mai",
        "Recuperi", "Utilità", "Benefici", "Regole di occultamento", "Regole di visibilità",
        "Corrispondenza qualsiasi (nascondi se una condizione è soddisfatta)", "Corrispondenza completa (nascondi se tutte le condizioni sono soddisfatte)",
        "Sempre (disattivato)", "Durante il lancio", "Non sta lanciando", "Fuori dal combattimento", "Incontro con il boss",
        "In istanza", "Su veicolo / taxi", "In sella", "In volo", "Volo dinamico", "Nuotando",
        "A riposo (città/locanda)", "Morto / fantasma", "Ha un bersaglio", "Nessun bersaglio", "In gruppo",
        "Solo (senza gruppo)", "In incursione", "Marcato PvP", "In furtività", "In combattimento tra mascotte",
    },
    ptBR = {
        "Nova categoria de barra personalizada", "Opacidade da barra", "Visibilidade", "Sempre", "Em combate", "Mouseover", "Nunca",
        "Recargas", "Utilidade", "Bônus", "Regras de ocultação", "Regras de visibilidade",
        "Correspondência qualquer (ocultar se qualquer condição for atendida)", "Correspondência total (ocultar se todas as condições forem atendidas)",
        "Sempre (desativado)", "Durante o lançamento", "Não lançando", "Fora de combate", "Encontro com chefe",
        "Em instância", "Em veículo / táxi", "Montado", "Voando", "Skyriding", "Nadando",
        "Descansando (cidade/estalagem)", "Morto / fantasma", "Tem alvo", "Sem alvo", "Em grupo",
        "Solo (sem grupo)", "Em raide", "Marcado para JxJ", "Furtivo", "Em batalha de mascotes",
    },
    ruRU = {
        "Новая категория панели", "Прозрачность панели", "Видимость", "Всегда", "В бою", "При наведении", "Никогда",
        "Восстановление", "Дополнительно", "Баффы", "Правила скрытия", "Правила видимости",
        "Любое совпадение (скрывать при выполнении любого условия)", "Все совпадения (скрывать при выполнении всех условий)",
        "Всегда (отключено)", "Во время применения", "Не применяет заклинание", "Вне боя", "Сражение с боссом",
        "В подземелье", "В транспорте / такси", "Верхом", "В полёте", "Небесная езда", "Плывёт",
        "Отдыхает (город/таверна)", "Мёртв / призрак", "Есть цель", "Нет цели", "В группе",
        "Один (не в группе)", "В рейде", "Отмечен для PvP", "В незаметности", "В бою питомцев",
    },
    koKR = {
        "새 사용자 지정 바 범주", "바 불투명도", "표시 상태", "항상", "전투 중", "마우스 오버", "사용 안 함",
        "재사용 대기시간", "유틸리티", "버프", "숨김 규칙", "표시 규칙",
        "하나라도 일치 (조건 하나라도 충족되면 숨김)", "모두 일치 (모든 조건이 충족되면 숨김)",
        "항상 (비활성화)", "시전 중", "시전하지 않음", "전투 중 아님", "우두머리 전투",
        "인스턴스 내", "탈것 / 택시 이용 중", "탈것 탑승", "비행 중", "하늘비행", "수영 중",
        "휴식 중 (도시/여관)", "죽음 / 유령", "대상 있음", "대상 없음", "파티 중",
        "혼자 (파티 없음)", "공격대 중", "PvP 상태", "은신 중", "애완동물 대전 중",
    },
    zhCN = {
        "新建自定义条类别", "条透明度", "可见性", "始终", "战斗中", "鼠标悬停", "从不",
        "冷却", "实用", "增益", "隐藏规则", "可见性规则",
        "匹配任意（满足任意条件时隐藏）", "匹配全部（满足所有条件时隐藏）",
        "始终（已禁用）", "施法中", "未施法", "脱离战斗", "首领战斗",
        "在副本中", "在载具 / 出租车中", "骑乘中", "飞行中", "空中飞行", "游泳中",
        "休息中（城市/旅店）", "死亡 / 鬼魂", "有目标", "无目标", "在队伍中",
        "单人（不在队伍中）", "在团队中", "PvP 标记", "潜行中", "宠物对战中",
    },
    zhTW = {
        "新增自訂條類別", "條透明度", "可見性", "一律", "戰鬥中", "滑鼠懸停", "永不",
        "冷卻", "實用", "增益", "隱藏規則", "可見性規則",
        "符合任一項（符合任一條件時隱藏）", "符合全部（符合所有條件時隱藏）",
        "一律（已停用）", "施法中", "未施法", "脫離戰鬥", "首領戰鬥",
        "在副本中", "在載具 / 計程車中", "騎乘中", "飛行中", "天空騎乘", "游泳中",
        "休息中（城市/旅店）", "死亡 / 鬼魂", "有目標", "無目標", "在隊伍中",
        "單人（不在隊伍中）", "在團隊中", "PvP 標記", "潛行中", "寵物對戰中",
    },
}
for locale, translated in pairs(cdmBarRuleLocales) do
    local target = locales[locale]
    if type(target) == "table" then
        for index, key in ipairs(cdmBarRuleKeys) do
            target[key] = translated[index]
        end
    end
end
if type(locales.esMX) == "table" then
    for index, key in ipairs(cdmBarRuleKeys) do
        locales.esMX[key] = cdmBarRuleLocales.esES[index]
    end
end
