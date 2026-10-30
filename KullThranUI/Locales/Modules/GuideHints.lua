-- Info hint guides (Widgets.lua W:InfoHint): the Unlock Mode guide on its
-- sidebar and the "How do I move frames?" hint in the Installer; also the
-- side panel's element filter and the installer step "Opening KullThranUI"
-- and the Ground Effects options of System Tuning (Forever).
local _, ns = ...

local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local localeOrder = { "esES", "deDE", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
local translations = {
    ["Guide"] = { "Guía", "Anleitung", "Guide", "Guida", "Guia", "Справка", "안내", "指南", "指南" },
    ["Unlock Mode"] = { "Modo desbloqueo", "Freischaltmodus", "Mode de déverrouillage", "Modalità di sblocco", "Modo de desbloqueio", "Режим разблокировки", "잠금 해제 모드", "解锁模式", "解鎖模式" },
    ["Move and resize every KullThranUI element. Nothing is kept until you press Save."] = {
        "Mueve y redimensiona cualquier elemento de KullThranUI. Nada se guarda hasta que pulses Guardar.",
        "Verschiebe jedes KullThranUI-Element und ändere seine Größe. Nichts wird übernommen, bis du auf Speichern klickst.",
        "Déplacez et redimensionnez chaque élément de KullThranUI. Rien n'est conservé tant que vous n'appuyez pas sur Enregistrer.",
        "Sposta e ridimensiona ogni elemento di KullThranUI. Nulla viene mantenuto finché non premi Salva.",
        "Mova e redimensione qualquer elemento do KullThranUI. Nada é mantido até você clicar em Salvar.",
        "Перемещайте и меняйте размер любого элемента KullThranUI. Ничего не сохранится, пока вы не нажмёте «Сохранить».",
        "모든 KullThranUI 요소를 옮기고 크기를 바꿀 수 있습니다. 저장을 누르기 전에는 아무것도 적용되지 않습니다.",
        "移动并调整每个 KullThranUI 元素的大小。在点击“保存”之前，任何更改都不会保留。",
        "移動並調整每個 KullThranUI 元素的大小。在點擊「儲存」之前，任何變更都不會保留。",
    },
    ["Drag a frame to move it. Shift+click selects several to move them together."] = {
        "Arrastra un marco para moverlo. Mayús+clic selecciona varios para moverlos juntos.",
        "Ziehe ein Fenster, um es zu verschieben. Umschalt+Klick wählt mehrere aus, um sie gemeinsam zu bewegen.",
        "Faites glisser un cadre pour le déplacer. Maj+clic en sélectionne plusieurs pour les déplacer ensemble.",
        "Trascina un riquadro per spostarlo. Maiusc+clic ne seleziona diversi per spostarli insieme.",
        "Arraste um quadro para movê-lo. Shift+clique seleciona vários para movê-los juntos.",
        "Перетащите рамку, чтобы переместить её. Shift+щелчок выделяет несколько рамок, чтобы двигать их вместе.",
        "프레임을 끌어서 옮깁니다. Shift+클릭으로 여러 개를 선택해 함께 옮길 수 있습니다.",
        "拖动框体即可移动。Shift+点击可选中多个框体一起移动。",
        "拖曳框架即可移動。Shift+點擊可選取多個框架一起移動。",
    },
    ["Click or right-click a frame for its options: anchor, offsets, scale, size and reset."] = {
        "Haz clic o clic derecho en un marco para ver sus opciones: anclaje, desplazamientos, escala, tamaño y restablecer.",
        "Klicke oder rechtsklicke auf ein Fenster für seine Optionen: Anker, Versatz, Skalierung, Größe und Zurücksetzen.",
        "Cliquez ou faites un clic droit sur un cadre pour ses options : ancrage, décalages, échelle, taille et réinitialisation.",
        "Clic o clic destro su un riquadro per le sue opzioni: ancoraggio, offset, scala, dimensione e ripristino.",
        "Clique ou clique com o botão direito em um quadro para ver as opções: âncora, deslocamentos, escala, tamanho e redefinir.",
        "Щелчок или правый щелчок по рамке открывает её настройки: привязку, смещения, масштаб, размер и сброс.",
        "프레임을 클릭하거나 우클릭하면 옵션이 열립니다: 고정점, 오프셋, 배율, 크기, 초기화.",
        "单击或右键单击框体可打开其选项：锚点、偏移、缩放、尺寸和重置。",
        "點擊或右鍵點擊框架可開啟其選項：錨點、偏移、縮放、尺寸與重置。",
    },
    ["Arrow keys move the selected frame 1px, Shift+arrows 10px."] = {
        "Las flechas mueven el marco seleccionado 1 px; Mayús+flechas, 10 px.",
        "Pfeiltasten verschieben das gewählte Fenster um 1 px, Umschalt+Pfeiltasten um 10 px.",
        "Les flèches déplacent le cadre sélectionné de 1 px, Maj+flèches de 10 px.",
        "Le frecce spostano il riquadro selezionato di 1 px, Maiusc+frecce di 10 px.",
        "As setas movem o quadro selecionado 1 px; Shift+setas, 10 px.",
        "Стрелки сдвигают выбранную рамку на 1 пикс., Shift+стрелки — на 10 пикс.",
        "방향키로 선택한 프레임을 1px, Shift+방향키로 10px 이동합니다.",
        "方向键可将选中的框体移动 1 像素，Shift+方向键移动 10 像素。",
        "方向鍵可將選取的框架移動 1 像素，Shift+方向鍵移動 10 像素。",
    },
    ["Grid and Snap help you line frames up, Dark darkens the overlays and Coords shows positions."] = {
        "Cuadrícula y Ajuste te ayudan a alinear los marcos, Oscuro oscurece las capas y Coordenadas muestra las posiciones.",
        "Raster und Einrasten helfen beim Ausrichten, Dunkel verdunkelt die Überlagerungen und Koordinaten zeigt die Positionen.",
        "Grille et Aimantation aident à aligner les cadres, Sombre assombrit les calques et Coordonnées affiche les positions.",
        "Griglia e Aggancio aiutano ad allineare i riquadri, Scuro scurisce le sovrapposizioni e Coordinate mostra le posizioni.",
        "Grade e Encaixe ajudam a alinhar os quadros, Escuro escurece as camadas e Coordenadas mostra as posições.",
        "Сетка и Привязка помогают выравнивать рамки, Затемнение затемняет подложки, а Координаты показывают позиции.",
        "격자와 맞춤으로 프레임을 정렬하고, 어둡게는 오버레이를 어둡게 하며, 좌표는 위치를 표시합니다.",
        "网格和吸附帮助对齐框体，暗色会加深覆盖层，坐标显示位置。",
        "網格與吸附協助對齊框架，暗色會加深覆蓋層，座標顯示位置。",
    },
    ["KUI Elements lists every frame: click one to select it."] = {
        "Elementos KUI lista todos los marcos: haz clic en uno para seleccionarlo.",
        "KUI-Elemente listet alle Fenster auf: Klicke auf eines, um es auszuwählen.",
        "Éléments KUI liste tous les cadres : cliquez sur l'un d'eux pour le sélectionner.",
        "Elementi KUI elenca tutti i riquadri: fai clic su uno per selezionarlo.",
        "Elementos KUI lista todos os quadros: clique em um para selecioná-lo.",
        "В списке «Элементы KUI» есть все рамки: щёлкните по одной, чтобы выбрать её.",
        "KUI 요소 목록에 모든 프레임이 있습니다: 하나를 클릭해 선택하세요.",
        "KUI 元素列表包含所有框体：点击其中一个即可选中。",
        "KUI 元素列表包含所有框架：點擊其中一個即可選取。",
    },
    ["Save keeps your changes and Discard drops them. Esc asks before closing."] = {
        "Guardar conserva los cambios y Descartar los elimina. Esc pregunta antes de cerrar.",
        "Speichern übernimmt deine Änderungen, Verwerfen verwirft sie. Esc fragt vor dem Schließen nach.",
        "Enregistrer conserve vos modifications et Jeter les annule. Échap demande confirmation avant de fermer.",
        "Salva mantiene le modifiche e Scartare le annulla. Esc chiede conferma prima di chiudere.",
        "Salvar mantém as alterações e Descartar as desfaz. Esc pergunta antes de fechar.",
        "«Сохранить» применяет изменения, «Отбросить» отменяет их. Esc спрашивает перед закрытием.",
        "저장은 변경 사항을 유지하고 폐기는 취소합니다. Esc는 닫기 전에 확인합니다.",
        "保存会保留更改，丢弃则放弃更改。按 Esc 关闭前会先询问。",
        "儲存會保留變更，丟棄則放棄變更。按 Esc 關閉前會先詢問。",
    },
    ["Filter elements"] = { "Filtrar elementos", "Elemente filtern", "Filtrer les éléments", "Filtra elementi", "Filtrar elementos", "Фильтр элементов", "요소 필터", "筛选元素", "篩選元素" },
    -- Installer step "Opening KullThranUI".
    ["Opening KullThranUI"] = { "Cómo abrir KullThranUI", "KullThranUI öffnen", "Ouvrir KullThranUI", "Aprire KullThranUI", "Como abrir o KullThranUI", "Как открыть KullThranUI", "KullThranUI 여는 방법", "如何打开 KullThranUI", "如何開啟 KullThranUI" },
    ["Everything you choose here can be changed later. This is how to get back to each part of KullThranUI."] = {
        "Todo lo que elijas aquí se puede cambiar después. Así vuelves a cada parte de KullThranUI.",
        "Alles, was du hier wählst, kannst du später ändern. So gelangst du zurück zu jedem Teil von KullThranUI.",
        "Tout ce que vous choisissez ici pourra être modifié plus tard. Voici comment revenir à chaque partie de KullThranUI.",
        "Tutto ciò che scegli qui si può cambiare in seguito. Ecco come tornare a ogni parte di KullThranUI.",
        "Tudo o que você escolher aqui pode ser alterado depois. Veja como voltar a cada parte do KullThranUI.",
        "Всё, что вы выберете здесь, можно изменить позже. Вот как вернуться к каждой части KullThranUI.",
        "여기서 고른 모든 것은 나중에 바꿀 수 있습니다. KullThranUI의 각 부분으로 돌아가는 방법은 다음과 같습니다.",
        "这里的所有选择之后都可以更改。以下是回到 KullThranUI 各部分的方法。",
        "這裡的所有選擇之後都可以變更。以下是回到 KullThranUI 各部分的方法。",
    },
    ["KUI Options"] = { "Opciones de KUI", "KUI-Optionen", "Options de KUI", "Opzioni di KUI", "Opções do KUI", "Настройки KUI", "KUI 옵션", "KUI 选项", "KUI 選項" },
    ["Every module, style and colour of KullThranUI in one window."] = {
        "Todos los módulos, estilos y colores de KullThranUI en una sola ventana.",
        "Alle Module, Stile und Farben von KullThranUI in einem Fenster.",
        "Tous les modules, styles et couleurs de KullThranUI dans une seule fenêtre.",
        "Tutti i moduli, gli stili e i colori di KullThranUI in un'unica finestra.",
        "Todos os módulos, estilos e cores do KullThranUI em uma única janela.",
        "Все модули, стили и цвета KullThranUI в одном окне.",
        "KullThranUI의 모든 모듈, 스타일, 색상을 한 창에서.",
        "在一个窗口中设置 KullThranUI 的所有模块、样式和颜色。",
        "在一個視窗中設定 KullThranUI 的所有模組、樣式與顏色。",
    },
    ["Move, resize and anchor every KullThranUI frame on screen."] = {
        "Mueve, redimensiona y ancla cada marco de KullThranUI en pantalla.",
        "Verschiebe, skaliere und verankere jedes KullThranUI-Fenster auf dem Bildschirm.",
        "Déplacez, redimensionnez et ancrez chaque cadre de KullThranUI à l'écran.",
        "Sposta, ridimensiona e ancora ogni riquadro di KullThranUI sullo schermo.",
        "Mova, redimensione e ancore cada quadro do KullThranUI na tela.",
        "Перемещайте, масштабируйте и привязывайте любые рамки KullThranUI на экране.",
        "화면의 모든 KullThranUI 프레임을 옮기고, 크기를 바꾸고, 고정합니다.",
        "移动、缩放并锚定屏幕上的每个 KullThranUI 框体。",
        "移動、縮放並錨定畫面上的每個 KullThranUI 框架。",
    },
    ["Run this setup again whenever you want to change your choices."] = {
        "Vuelve a pasar por esta configuración cuando quieras cambiar lo que elegiste.",
        "Starte diese Einrichtung erneut, wann immer du deine Auswahl ändern möchtest.",
        "Relancez cette configuration quand vous voulez modifier vos choix.",
        "Ripeti questa configurazione quando vuoi cambiare le tue scelte.",
        "Execute esta configuração novamente quando quiser mudar suas escolhas.",
        "Запускайте эту настройку снова, когда захотите изменить свой выбор.",
        "선택을 바꾸고 싶을 때 언제든 이 설정을 다시 실행하세요.",
        "想更改选择时，随时可以再次运行此设置。",
        "想變更選擇時，隨時可以再次執行此設定。",
    },
    ["Open it with"] = { "Ábrelo con", "Öffnen mit", "Ouvrir avec", "Aprila con", "Abra com", "Открыть", "여는 방법", "打开方式", "開啟方式" },
    ["Game menu (Esc) > KullThranUI"] = { "Menú del juego (Esc) > KullThranUI", "Spielmenü (Esc) > KullThranUI", "Menu du jeu (Échap) > KullThranUI", "Menu di gioco (Esc) > KullThranUI", "Menu do jogo (Esc) > KullThranUI", "Игровое меню (Esc) > KullThranUI", "게임 메뉴(Esc) > KullThranUI", "游戏菜单（Esc）> KullThranUI", "遊戲選單（Esc）> KullThranUI" },
    ["Right-click the KUI minimap button"] = { "Clic derecho en el botón de KUI del minimapa", "Rechtsklick auf die KUI-Minimap-Schaltfläche", "Clic droit sur le bouton KUI de la minicarte", "Clic destro sul pulsante KUI della minimappa", "Clique com o botão direito no botão do KUI no minimapa", "Правый щелчок по кнопке KUI у миникарты", "미니맵의 KUI 버튼 우클릭", "右键单击小地图上的 KUI 按钮", "右鍵點擊小地圖上的 KUI 按鈕" },
    ["Game menu (Esc) > KUI Unlock Mode"] = { "Menú del juego (Esc) > Modo desbloqueo de KUI", "Spielmenü (Esc) > KUI-Freischaltmodus", "Menu du jeu (Échap) > Mode de déverrouillage KUI", "Menu di gioco (Esc) > Modalità di sblocco KUI", "Menu do jogo (Esc) > Modo de desbloqueio KUI", "Игровое меню (Esc) > Режим разблокировки KUI", "게임 메뉴(Esc) > KUI 잠금 해제 모드", "游戏菜单（Esc）> KUI解锁模式", "遊戲選單（Esc）> KUI解鎖模式" },
    ["The Unlock Mode button in the /kui window"] = { "El botón del modo desbloqueo en la ventana /kui", "Die Freischaltmodus-Schaltfläche im /kui-Fenster", "Le bouton du mode de déverrouillage dans la fenêtre /kui", "Il pulsante della modalità di sblocco nella finestra /kui", "O botão do modo de desbloqueio na janela /kui", "Кнопка режима разблокировки в окне /kui", "/kui 창의 잠금 해제 모드 버튼", "/kui 窗口中的解锁模式按钮", "/kui 視窗中的解鎖模式按鈕" },
    ["Tick Don't show again to stop it opening at login"] = {
        "Marca «No mostrar de nuevo» para que no se abra al entrar",
        "Hake „Nicht mehr anzeigen“ an, damit er sich beim Einloggen nicht mehr öffnet",
        "Cochez « Ne plus montrer » pour qu'il ne s'ouvre plus à la connexion",
        "Spunta «Non mostrare più» perché non si apra all'accesso",
        "Marque “Não mostre novamente” para que ele não abra ao entrar",
        "Отметьте «Больше не показывать», чтобы он не открывался при входе",
        "\"다시 표시하지 않음\"을 선택하면 접속할 때 열리지 않습니다",
        "勾选“不再显示”后，登录时将不再自动打开",
        "勾選「不再顯示」後，登入時將不再自動開啟",
    },
    -- Enhancements > System Tuning > Ground Effects (Forever).
    ["Ground Effects"] = { "Efectos del suelo", "Bodeneffekte", "Effets de sol", "Effetti del terreno", "Efeitos do solo", "Эффекты земли", "지면 효과", "地面效果", "地面效果" },
    ["Apply ground effect settings"] = { "Aplicar ajustes de efectos del suelo", "Bodeneffekt-Einstellungen anwenden", "Appliquer les réglages des effets de sol", "Applica le impostazioni degli effetti del terreno", "Aplicar configurações de efeitos do solo", "Применять настройки эффектов земли", "지면 효과 설정 적용", "应用地面效果设置", "套用地面效果設定" },
    ["Ground effect density"] = { "Densidad de efectos del suelo", "Dichte der Bodeneffekte", "Densité des effets de sol", "Densità degli effetti del terreno", "Densidade dos efeitos do solo", "Плотность эффектов земли", "지면 효과 밀도", "地面效果密度", "地面效果密度" },
    ["Ground effect fade distance"] = { "Distancia de desvanecido de efectos del suelo", "Ausblendentfernung der Bodeneffekte", "Distance de fondu des effets de sol", "Distanza di dissolvenza degli effetti del terreno", "Distância de esmaecimento dos efeitos do solo", "Дистанция затухания эффектов земли", "지면 효과 사라짐 거리", "地面效果淡出距离", "地面效果淡出距離" },
    ["Ground effect draw distance"] = { "Distancia de dibujado de efectos del suelo", "Sichtweite der Bodeneffekte", "Distance d'affichage des effets de sol", "Distanza di visualizzazione degli effetti del terreno", "Distância de exibição dos efeitos do solo", "Дальность прорисовки эффектов земли", "지면 효과 표시 거리", "地面效果绘制距离", "地面效果繪製距離" },
    ["How do I move frames?"] = { "¿Cómo muevo los marcos?", "Wie verschiebe ich Fenster?", "Comment déplacer les cadres ?", "Come sposto i riquadri?", "Como movo os quadros?", "Как перемещать рамки?", "프레임은 어떻게 옮기나요?", "如何移动框体？", "如何移動框架？" },
    ["Moving your frames"] = { "Mover tus marcos", "Fenster verschieben", "Déplacer vos cadres", "Spostare i riquadri", "Mover seus quadros", "Перемещение рамок", "프레임 옮기기", "移动你的框体", "移動你的框架" },
    ["After the installer, open Unlock Mode to place every KullThranUI frame where you want it."] = {
        "Al terminar el instalador, abre el modo desbloqueo para colocar cada marco de KullThranUI donde quieras.",
        "Öffne nach der Installation den Freischaltmodus, um jedes KullThranUI-Fenster dort zu platzieren, wo du es möchtest.",
        "Après l'installation, ouvrez le mode de déverrouillage pour placer chaque cadre de KullThranUI où vous le souhaitez.",
        "Dopo l'installazione, apri la modalità di sblocco per posizionare ogni riquadro di KullThranUI dove vuoi.",
        "Depois do instalador, abra o modo de desbloqueio para posicionar cada quadro do KullThranUI onde quiser.",
        "После установки откройте режим разблокировки, чтобы расставить рамки KullThranUI как вам нужно.",
        "설치가 끝나면 잠금 해제 모드를 열어 KullThranUI 프레임을 원하는 곳에 배치하세요.",
        "安装完成后，打开解锁模式，把每个 KullThranUI 框体放到你想要的位置。",
        "安裝完成後，開啟解鎖模式，把每個 KullThranUI 框架放到你想要的位置。",
    },
    ["Open it with the KUI Unlock Mode button in the game menu (Esc), from the /kui window or with /ktunlock."] = {
        "Ábrelo con el botón Modo desbloqueo de KUI del menú del juego (Esc), desde la ventana /kui o con /ktunlock.",
        "Öffne ihn über die Schaltfläche KUI-Freischaltmodus im Spielmenü (Esc), im /kui-Fenster oder mit /ktunlock.",
        "Ouvrez-le avec le bouton Mode de déverrouillage KUI du menu du jeu (Échap), depuis la fenêtre /kui ou avec /ktunlock.",
        "Aprila con il pulsante Modalità di sblocco KUI nel menu di gioco (Esc), dalla finestra /kui o con /ktunlock.",
        "Abra-o com o botão Modo de desbloqueio KUI no menu do jogo (Esc), pela janela /kui ou com /ktunlock.",
        "Откройте его кнопкой «Режим разблокировки KUI» в игровом меню (Esc), в окне /kui или командой /ktunlock.",
        "게임 메뉴(Esc)의 KUI 잠금 해제 모드 버튼, /kui 창 또는 /ktunlock 명령으로 엽니다.",
        "可通过游戏菜单（Esc）中的“KUI解锁模式”按钮、/kui 窗口或 /ktunlock 命令打开。",
        "可透過遊戲選單（Esc）中的「KUI解鎖模式」按鈕、/kui 視窗或 /ktunlock 指令開啟。",
    },
    ["Drag frames to move them and right-click one for its options."] = {
        "Arrastra los marcos para moverlos y haz clic derecho en uno para ver sus opciones.",
        "Ziehe Fenster, um sie zu verschieben, und rechtsklicke auf eines für seine Optionen.",
        "Faites glisser les cadres pour les déplacer et faites un clic droit sur l'un d'eux pour ses options.",
        "Trascina i riquadri per spostarli e fai clic destro su uno per le sue opzioni.",
        "Arraste os quadros para movê-los e clique com o botão direito em um para ver as opções.",
        "Перетаскивайте рамки, а правый щелчок по рамке открывает её настройки.",
        "프레임을 끌어서 옮기고, 우클릭하면 해당 프레임의 옵션이 열립니다.",
        "拖动框体即可移动，右键单击框体可打开其选项。",
        "拖曳框架即可移動，右鍵點擊框架可開啟其選項。",
    },
    ["Nothing changes until you press Save; Discard leaves everything as it was."] = {
        "Nada cambia hasta que pulses Guardar; Descartar lo deja todo como estaba.",
        "Nichts ändert sich, bis du auf Speichern klickst; Verwerfen lässt alles, wie es war.",
        "Rien ne change tant que vous n'appuyez pas sur Enregistrer ; Jeter laisse tout comme avant.",
        "Nulla cambia finché non premi Salva; Scartare lascia tutto com'era.",
        "Nada muda até você clicar em Salvar; Descartar deixa tudo como estava.",
        "Ничего не изменится, пока вы не нажмёте «Сохранить»; «Отбросить» оставит всё как было.",
        "저장을 누르기 전에는 아무것도 바뀌지 않으며, 폐기를 누르면 모두 그대로 유지됩니다.",
        "在点击“保存”之前不会有任何改变；点击“丢弃”则一切保持原样。",
        "在點擊「儲存」之前不會有任何改變；點擊「丟棄」則一切保持原樣。",
    },
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

-- The guide names the sidebar's "KUI ELEMENTS" list; these replace older
-- machine translations that did not read as KUI.
local fixes = { ruRU = "ЭЛЕМЕНТЫ KUI", koKR = "KUI 요소", zhCN = "KUI 元素", zhTW = "KUI 元素" }
for localeName, value in pairs(fixes) do
    if locales[localeName] then locales[localeName]["KUI ELEMENTS"] = value end
end

-- "Installer" read as a person (plumber / installer worker) in these; the
-- installer is a setup wizard.
local installerName = { deDE = "Installationsassistent", koKR = "설치 마법사", zhCN = "安装向导", zhTW = "安裝精靈" }
for localeName, value in pairs(installerName) do
    if locales[localeName] then locales[localeName]["Installer"] = value end
end
