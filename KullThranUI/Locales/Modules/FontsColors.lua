-- Complete coverage for the consolidated Fonts & Colors page.
local _, ns = ...

local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

local localeOrder = { "esES", "deDE", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
local translations = {
    ["Text Scale"] = { "Escala de texto", "Textskalierung", "Échelle du texte", "Scala del testo", "Escala do texto", "Масштаб текста", "텍스트 배율", "文字缩放", "文字縮放" },
    ["Name Background Start"] = { "Inicio del fondo del nombre", "Anfang des Namenshintergrunds", "Début du fond du nom", "Inizio sfondo del nome", "Início do fundo do nome", "Начало фона имени", "이름 배경 시작", "名称背景起始色", "名稱背景起始色" },
    ["Name Background End"] = { "Final del fondo del nombre", "Ende des Namenshintergrunds", "Fin du fond du nom", "Fine sfondo del nome", "Fim do fundo do nome", "Конец фона имени", "이름 배경 끝", "名称背景结束色", "名稱背景結束色" },
    ["Gold"] = { "Oro", "Gold", "Or", "Oro", "Ouro", "Золото", "금색", "金色", "金色" },
    ["Silver"] = { "Plata", "Silber", "Argent", "Argento", "Prata", "Серебро", "은색", "银色", "銀色" },
    ["Bronze"] = { "Bronce", "Bronze", "Bronze", "Bronzo", "Bronze", "Бронза", "동색", "铜色", "銅色" },
    ["Mythic+ Timer Typography"] = { "Tipografía del temporizador de Míticas+", "Typografie des Mythisch+-Timers", "Typographie du minuteur Mythique+", "Tipografia del timer Mitiche+", "Tipografia do cronômetro de Míticas+", "Шрифт таймера эпохальных+", "신화+ 타이머 글꼴", "史诗钥石计时器字体", "傳奇鑰石計時器字型" },
    ["Timer Font"] = { "Fuente del temporizador", "Timer-Schriftart", "Police du minuteur", "Carattere del timer", "Fonte do cronômetro", "Шрифт таймера", "타이머 글꼴", "计时器字体", "計時器字型" },
    ["Timer Size"] = { "Tamaño del temporizador", "Timer-Größe", "Taille du minuteur", "Dimensione del timer", "Tamanho do cronômetro", "Размер таймера", "타이머 크기", "计时器大小", "計時器大小" },
    ["Timer Outline"] = { "Contorno del temporizador", "Timer-Kontur", "Contour du minuteur", "Contorno del timer", "Contorno do cronômetro", "Контур таймера", "타이머 외곽선", "计时器描边", "計時器描邊" },
    ["Key Font"] = { "Fuente de la clave", "Schlüssel-Schriftart", "Police de la clé", "Carattere della chiave", "Fonte da chave", "Шрифт ключа", "쐐기돌 글꼴", "钥石字体", "鑰石字型" },
    ["Key Size"] = { "Tamaño de la clave", "Schlüssel-Größe", "Taille de la clé", "Dimensione della chiave", "Tamanho da chave", "Размер ключа", "쐐기돌 크기", "钥石大小", "鑰石大小" },
    ["Key Outline"] = { "Contorno de la clave", "Schlüssel-Kontur", "Contour de la clé", "Contorno della chiave", "Contorno da chave", "Контур ключа", "쐐기돌 외곽선", "钥石描边", "鑰石描邊" },
    ["Key Details Font"] = { "Fuente de los detalles de la clave", "Schriftart der Schlüsseldetails", "Police des détails de la clé", "Carattere dei dettagli della chiave", "Fonte dos detalhes da chave", "Шрифт сведений о ключе", "쐐기돌 세부 정보 글꼴", "钥石详情字体", "鑰石詳情字型" },
    ["Key Details Size"] = { "Tamaño de los detalles de la clave", "Größe der Schlüsseldetails", "Taille des détails de la clé", "Dimensione dei dettagli della chiave", "Tamanho dos detalhes da chave", "Размер сведений о ключе", "쐐기돌 세부 정보 크기", "钥石详情大小", "鑰石詳情大小" },
    ["Key Details Outline"] = { "Contorno de los detalles de la clave", "Kontur der Schlüsseldetails", "Contour des détails de la clé", "Contorno dei dettagli della chiave", "Contorno dos detalhes da chave", "Контур сведений о ключе", "쐐기돌 세부 정보 외곽선", "钥石详情描边", "鑰石詳情描邊" },
    ["Forces Font"] = { "Fuente de fuerzas", "Streitkräfte-Schriftart", "Police des forces ennemies", "Carattere delle forze nemiche", "Fonte das forças inimigas", "Шрифт сил противника", "적 병력 글꼴", "敌方部队字体", "敵方部隊字型" },
    ["Forces Size"] = { "Tamaño de fuerzas", "Streitkräfte-Größe", "Taille des forces ennemies", "Dimensione delle forze nemiche", "Tamanho das forças inimigas", "Размер сил противника", "적 병력 크기", "敌方部队大小", "敵方部隊大小" },
    ["Forces Outline"] = { "Contorno de fuerzas", "Streitkräfte-Kontur", "Contour des forces ennemies", "Contorno delle forze nemiche", "Contorno das forças inimigas", "Контур сил противника", "적 병력 외곽선", "敌方部队描边", "敵方部隊描邊" },
    ["Deaths Font"] = { "Fuente de muertes", "Tode-Schriftart", "Police des morts", "Carattere delle morti", "Fonte das mortes", "Шрифт смертей", "죽음 글꼴", "死亡次数字体", "死亡次數字型" },
    ["Deaths Size"] = { "Tamaño de muertes", "Tode-Größe", "Taille des morts", "Dimensione delle morti", "Tamanho das mortes", "Размер смертей", "죽음 크기", "死亡次数大小", "死亡次數大小" },
    ["Deaths Outline"] = { "Contorno de muertes", "Tode-Kontur", "Contour des morts", "Contorno delle morti", "Contorno das mortes", "Контур смертей", "죽음 외곽선", "死亡次数描边", "死亡次數描邊" },
    ["Objectives Font"] = { "Fuente de objetivos", "Ziel-Schriftart", "Police des objectifs", "Carattere degli obiettivi", "Fonte dos objetivos", "Шрифт целей", "목표 글꼴", "目标字体", "目標字型" },
    ["Objectives Size"] = { "Tamaño de objetivos", "Ziel-Größe", "Taille des objectifs", "Dimensione degli obiettivi", "Tamanho dos objetivos", "Размер целей", "목표 크기", "目标大小", "目標大小" },
    ["Objectives Outline"] = { "Contorno de objetivos", "Ziel-Kontur", "Contour des objectifs", "Contorno degli obiettivi", "Contorno dos objetivos", "Контур целей", "목표 외곽선", "目标描边", "目標描邊" },
    ["Mythic+ Timer Colors"] = { "Colores del temporizador de Míticas+", "Farben des Mythisch+-Timers", "Couleurs du minuteur Mythique+", "Colori del timer Mitiche+", "Cores do cronômetro de Míticas+", "Цвета таймера эпохальных+", "신화+ 타이머 색상", "史诗钥石计时器颜色", "傳奇鑰石計時器顏色" },
    ["Key Level"] = { "Nivel de la clave", "Schlüsselstufe", "Niveau de la clé", "Livello della chiave", "Nível da chave", "Уровень ключа", "쐐기돌 레벨", "钥石等级", "鑰石等級" },
    ["Key Details"] = { "Detalles de la clave", "Schlüsseldetails", "Détails de la clé", "Dettagli della chiave", "Detalhes da chave", "Сведения о ключе", "쐐기돌 세부 정보", "钥石详情", "鑰石詳情" },
    ["Timer Running"] = { "Temporizador en curso", "Timer läuft", "Minuteur en cours", "Timer in corso", "Cronômetro em andamento", "Таймер запущен", "타이머 진행 중", "计时器进行中", "計時器進行中" },
    ["Timer Success"] = { "Temporizador superado", "Timer erfolgreich", "Minuteur réussi", "Timer riuscito", "Cronômetro concluído", "Таймер успешно завершён", "타이머 성공", "计时器成功", "計時器成功" },
    ["Timer Expired"] = { "Temporizador agotado", "Timer abgelaufen", "Minuteur expiré", "Timer scaduto", "Cronômetro expirado", "Таймер истёк", "타이머 만료", "计时器超时", "計時器超時" },
    ["Forces Text"] = { "Texto de fuerzas", "Streitkräfte-Text", "Texte des forces ennemies", "Testo delle forze nemiche", "Texto das forças inimigas", "Текст сил противника", "적 병력 텍스트", "敌方部队文字", "敵方部隊文字" },
    ["Forces Bar"] = { "Barra de fuerzas", "Streitkräfte-Leiste", "Barre des forces ennemies", "Barra delle forze nemiche", "Barra das forças inimigas", "Полоса сил противника", "적 병력 바", "敌方部队进度条", "敵方部隊進度條" },
    ["Forces Glow"] = { "Resplandor de fuerzas", "Streitkräfte-Leuchten", "Lueur des forces ennemies", "Bagliore delle forze nemiche", "Brilho das forças inimigas", "Свечение сил противника", "적 병력 발광", "敌方部队辉光", "敵方部隊輝光" },
    ["Chest +3"] = { "Cofre +3", "Truhe +3", "Coffre +3", "Forziere +3", "Baú +3", "Сундук +3", "+3 상자", "+3 宝箱", "+3 寶箱" },
    ["Chest +2"] = { "Cofre +2", "Truhe +2", "Coffre +2", "Forziere +2", "Baú +2", "Сундук +2", "+2 상자", "+2 宝箱", "+2 寶箱" },
    ["Chest +1"] = { "Cofre +1", "Truhe +1", "Coffre +1", "Forziere +1", "Baú +1", "Сундук +1", "+1 상자", "+1 宝箱", "+1 寶箱" },
    ["Objectives"] = { "Objetivos", "Ziele", "Objectifs", "Obiettivi", "Objetivos", "Цели", "목표", "目标", "目標" },
    ["Completed Objectives"] = { "Objetivos completados", "Abgeschlossene Ziele", "Objectifs terminés", "Obiettivi completati", "Objetivos concluídos", "Выполненные цели", "완료한 목표", "已完成目标", "已完成目標" },
    ["Row Font Size"] = { "Tamaño de fuente de las filas", "Schriftgröße der Zeilen", "Taille de police des lignes", "Dimensione carattere delle righe", "Tamanho da fonte das linhas", "Размер шрифта строк", "행 글꼴 크기", "行字体大小", "列字型大小" },
    ["Damage Meter - %s"] = { "Medidor de daño - %s", "Schadensanzeige - %s", "Compteur de dégâts - %s", "Misuratore danni - %s", "Medidor de dano - %s", "Счётчик урона — %s", "피해량 측정기 - %s", "伤害统计 - %s", "傷害統計 - %s" },
    ["Enter Combat"] = { "Entrar en combate", "Kampfbeginn", "Entrée en combat", "Entrata in combattimento", "Entrar em combate", "Вход в бой", "전투 시작", "进入战斗", "進入戰鬥" },
    ["Leave Combat"] = { "Salir de combate", "Kampfende", "Sortie de combat", "Uscita dal combattimento", "Sair de combate", "Выход из боя", "전투 종료", "离开战斗", "離開戰鬥" },
    ["%s Typography"] = { "Tipografía de %s", "Typografie: %s", "Typographie : %s", "Tipografia: %s", "Tipografia: %s", "Шрифт: %s", "%s 글꼴", "%s字体", "%s字型" },
    ["Friend List"] = { "Lista de amigos", "Freundesliste", "Liste d'amis", "Lista amici", "Lista de amigos", "Список друзей", "친구 목록", "好友列表", "好友名單" },
    ["Teleport Menu Typography"] = { "Tipografía del menú de teletransporte", "Typografie des Teleportmenüs", "Typographie du menu de téléportation", "Tipografia del menu di teletrasporto", "Tipografia do menu de teleporte", "Шрифт меню телепортации", "순간이동 메뉴 글꼴", "传送菜单字体", "傳送選單字型" },
    ["Unit Frames - %s"] = { "Marcos de unidad - %s", "Einheitenfenster - %s", "Cadres d'unité - %s", "Riquadri unità - %s", "Quadros de unidade - %s", "Рамки бойцов — %s", "개체창 - %s", "单位框体 - %s", "單位框架 - %s" },
    ["Player"] = { "Jugador", "Spieler", "Joueur", "Giocatore", "Jogador", "Игрок", "플레이어", "玩家", "玩家" },
    ["Target"] = { "Objetivo", "Ziel", "Cible", "Bersaglio", "Alvo", "Цель", "대상", "目标", "目標" },
    ["Target of Target"] = { "Objetivo del objetivo", "Ziel des Ziels", "Cible de la cible", "Bersaglio del bersaglio", "Alvo do alvo", "Цель цели", "대상의 대상", "目标的目标", "目標的目標" },
    ["Focus"] = { "Foco", "Fokus", "Focalisation", "Focus", "Foco", "Фокус", "주시 대상", "焦点", "專注目標" },
    ["Pet"] = { "Mascota", "Begleiter", "Familier", "Famiglio", "Ajudante", "Питомец", "소환수", "宠物", "寵物" },
    ["Boss"] = { "Jefe", "Boss", "Boss", "Boss", "Chefe", "Босс", "우두머리", "首领", "首領" },
    ["Health Fill"] = { "Relleno de salud", "Gesundheitsfüllung", "Remplissage de santé", "Riempimento salute", "Preenchimento de vida", "Заполнение здоровья", "생명력 채우기", "生命值填充", "生命值填滿" },
    ["Health Background"] = { "Fondo de salud", "Gesundheitshintergrund", "Arrière-plan de santé", "Sfondo salute", "Fundo de vida", "Фон здоровья", "생명력 배경", "生命值背景", "生命值背景" },
    ["Party Frames - %s"] = { "Marcos de grupo - %s", "Gruppenfenster - %s", "Cadres de groupe - %s", "Riquadri gruppo - %s", "Quadros de grupo - %s", "Рамки группы — %s", "파티 프레임 - %s", "队伍框体 - %s", "隊伍框架 - %s" },
    ["Party"] = { "Grupo", "Gruppe", "Groupe", "Gruppo", "Grupo", "Группа", "파티", "队伍", "隊伍" },
    ["Raid"] = { "Banda", "Schlachtzug", "Raid", "Incursione", "Raide", "Рейд", "공격대", "团队", "團隊" },
    ["Raid 40"] = { "Banda de 40", "40er-Schlachtzug", "Raid à 40", "Incursione da 40", "Raide de 40", "Рейд на 40", "40인 공격대", "40人团队", "40人團隊" },
    ["Arena"] = { "Arena", "Arena", "Arène", "Arena", "Arena", "Арена", "투기장", "竞技场", "競技場" },
    ["Health Size"] = { "Tamaño de salud", "Größe des Gesundheitstexts", "Taille du texte de santé", "Dimensione testo salute", "Tamanho do texto de vida", "Размер текста здоровья", "생명력 글자 크기", "生命值文字大小", "生命值文字大小" },
    ["Nameplates Typography"] = { "Tipografía de placas de nombre", "Typografie der Namensplaketten", "Typographie des barres d'unités", "Tipografia delle barre dei nomi", "Tipografia das placas de nome", "Шрифт индикаторов здоровья", "이름표 글꼴", "姓名板字体", "名條字型" },
    ["Top Text Size"] = { "Tamaño del texto superior", "Größe des oberen Texts", "Taille du texte supérieur", "Dimensione testo superiore", "Tamanho do texto superior", "Размер верхнего текста", "상단 텍스트 크기", "顶部文字大小", "頂部文字大小" },
    ["Top Text Color"] = { "Color del texto superior", "Farbe des oberen Texts", "Couleur du texte supérieur", "Colore testo superiore", "Cor do texto superior", "Цвет верхнего текста", "상단 텍스트 색상", "顶部文字颜色", "頂部文字顏色" },
    ["Left Text Color"] = { "Color del texto izquierdo", "Farbe des linken Texts", "Couleur du texte gauche", "Colore testo sinistro", "Cor do texto esquerdo", "Цвет левого текста", "왼쪽 텍스트 색상", "左侧文字颜色", "左側文字顏色" },
    ["Right Text Color"] = { "Color del texto derecho", "Farbe des rechten Texts", "Couleur du texte droit", "Colore testo destro", "Cor do texto direito", "Цвет правого текста", "오른쪽 텍스트 색상", "右侧文字颜色", "右側文字顏色" },
    ["Center Text Color"] = { "Color del texto central", "Farbe des mittleren Texts", "Couleur du texte central", "Colore testo centrale", "Cor do texto central", "Цвет центрального текста", "중앙 텍스트 색상", "中央文字颜色", "中央文字顏色" },
    ["Resource Bars - %s"] = { "Barras de recursos - %s", "Ressourcenleisten - %s", "Barres de ressources - %s", "Barre risorse - %s", "Barras de recursos - %s", "Полосы ресурсов — %s", "자원 바 - %s", "资源条 - %s", "資源條 - %s" },
    ["Health"] = { "Salud", "Gesundheit", "Santé", "Salute", "Vida", "Здоровье", "생명력", "生命值", "生命值" },
    ["Primary"] = { "Principal", "Primär", "Principale", "Primaria", "Primário", "Основной ресурс", "주 자원", "主要资源", "主要資源" },
    ["Secondary"] = { "Secundario", "Sekundär", "Secondaire", "Secondaria", "Secundário", "Дополнительный ресурс", "보조 자원", "次要资源", "次要資源" },
    ["%s Text"] = { "Texto de %s", "Text: %s", "Texte : %s", "Testo: %s", "Texto: %s", "Текст: %s", "%s 텍스트", "%s文字", "%s文字" },
    ["Minimap Zone"] = { "Zona del minimapa", "Minikarten-Zone", "Zone de la minicarte", "Zona della minimappa", "Zona do minimapa", "Зона мини-карты", "미니맵 지역", "小地图区域", "小地圖區域" },
    ["Minimap Statistics"] = { "Estadísticas del minimapa", "Minikarten-Statistiken", "Statistiques de la minicarte", "Statistiche della minimappa", "Estatísticas do minimapa", "Статистика мини-карты", "미니맵 통계", "小地图统计", "小地圖統計" },
    ["Tooltip"] = { "Descripción emergente", "Kurzinfo", "Infobulle", "Descrizione comando", "Dica de interface", "Подсказка", "툴팁", "鼠标提示", "滑鼠提示" },
    ["Chat"] = { "Chat", "Chat", "Discussion", "Chat", "Bate-papo", "Чат", "대화", "聊天", "聊天" },
    ["Action Count"] = { "Cantidad de acción", "Aktionsanzahl", "Nombre d'actions", "Conteggio azione", "Contagem da ação", "Количество действий", "행동 횟수", "动作计数", "動作計數" },
    ["Action Hotkeys"] = { "Atajos de acción", "Aktions-Tastenkürzel", "Raccourcis d'action", "Tasti rapidi azione", "Atalhos da ação", "Клавиши действий", "행동 단축키", "动作快捷键", "動作快捷鍵" },
    ["Action Macro Text"] = { "Texto de macro de acción", "Aktions-Makrotext", "Texte de macro d'action", "Testo macro azione", "Texto da macro de ação", "Текст макроса действия", "행동 매크로 텍스트", "动作宏文字", "動作巨集文字" },
    ["Buff Duration"] = { "Duración de beneficios", "Stärkungszauber-Dauer", "Durée des améliorations", "Durata benefici", "Duração dos bônus", "Длительность усилений", "강화 효과 지속시간", "增益持续时间", "增益持續時間" },
    ["Buff Count"] = { "Acumulaciones de beneficios", "Stärkungszauber-Stapel", "Charges des améliorations", "Accumuli benefici", "Acúmulos dos bônus", "Стаки усилений", "강화 효과 중첩", "增益层数", "增益層數" },
    ["Armory Item Level"] = { "Nivel de objeto del arsenal", "Gegenstandsstufe des Arsenals", "Niveau d'objet de l'armurerie", "Livello oggetto dell'armeria", "Nível de item do arsenal", "Уровень предметов арсенала", "전투정보실 아이템 레벨", "角色装备物品等级", "角色裝備物品等級" },
    ["Armory Average Level"] = { "Nivel medio del arsenal", "Durchschnittsstufe des Arsenals", "Niveau moyen de l'armurerie", "Livello medio dell'armeria", "Nível médio do arsenal", "Средний уровень арсенала", "전투정보실 평균 레벨", "角色装备平均等级", "角色裝備平均等級" },
    ["Armory Name"] = { "Nombre del arsenal", "Name im Arsenal", "Nom de l'armurerie", "Nome nell'armeria", "Nome no arsenal", "Имя в арсенале", "전투정보실 이름", "角色装备名称", "角色裝備名稱" },
    ["Armory Level"] = { "Nivel del arsenal", "Stufe im Arsenal", "Niveau de l'armurerie", "Livello nell'armeria", "Nível no arsenal", "Уровень в арсенале", "전투정보실 레벨", "角色装备等级", "角色裝備等級" },
    ["Armory Score"] = { "Puntuación del arsenal", "Wertung im Arsenal", "Score de l'armurerie", "Punteggio nell'armeria", "Pontuação no arsenal", "Рейтинг в арсенале", "전투정보실 점수", "角色装备评分", "角色裝備評分" },
    ["Inspect Item Level"] = { "Nivel de objeto de inspección", "Gegenstandsstufe beim Untersuchen", "Niveau d'objet inspecté", "Livello oggetto ispezionato", "Nível de item da inspeção", "Уровень предметов при осмотре", "살펴보기 아이템 레벨", "观察物品等级", "觀察物品等級" },
    ["Inspect Average Level"] = { "Nivel medio de inspección", "Durchschnittsstufe beim Untersuchen", "Niveau moyen inspecté", "Livello medio ispezionato", "Nível médio da inspeção", "Средний уровень при осмотре", "살펴보기 평균 레벨", "观察平均等级", "觀察平均等級" },
    ["Armory Additional Text"] = { "Texto adicional del arsenal", "Zusätzlicher Arsenaltext", "Texte supplémentaire de l'armurerie", "Testo aggiuntivo dell'armeria", "Texto adicional do arsenal", "Дополнительный текст арсенала", "전투정보실 추가 텍스트", "角色装备额外文字", "角色裝備額外文字" },
    ["Inspect Additional Text"] = { "Texto adicional de inspección", "Zusätzlicher Untersuchungstext", "Texte supplémentaire d'inspection", "Testo aggiuntivo dell'ispezione", "Texto adicional da inspeção", "Дополнительный текст осмотра", "살펴보기 추가 텍스트", "观察额外文字", "觀察額外文字" },
    ["Statistics Size"] = { "Tamaño de estadísticas", "Größe der Statistiken", "Taille des statistiques", "Dimensione statistiche", "Tamanho das estatísticas", "Размер статистики", "능력치 크기", "属性大小", "屬性大小" },
    ["Average Level Label Size"] = { "Tamaño de la etiqueta de nivel medio", "Größe der Durchschnittsstufen-Beschriftung", "Taille du libellé de niveau moyen", "Dimensione etichetta livello medio", "Tamanho do rótulo de nível médio", "Размер подписи среднего уровня", "평균 레벨 라벨 크기", "平均等级标签大小", "平均等級標籤大小" },
    ["Average Level Label Outline"] = { "Contorno de la etiqueta de nivel medio", "Kontur der Durchschnittsstufen-Beschriftung", "Contour du libellé de niveau moyen", "Contorno etichetta livello medio", "Contorno do rótulo de nível médio", "Контур подписи среднего уровня", "평균 레벨 라벨 외곽선", "平均等级标签描边", "平均等級標籤描邊" },
}

for key, values in pairs(translations) do
    for index, localeName in ipairs(localeOrder) do
        local locale = locales[localeName]
        local value = values[index]
        if locale and value then
            local current = rawget(locale, key)
            local englishValue = locales.enUS and rawget(locales.enUS, key)
            if current == nil or current == key or current == englishValue then
                locale[key] = value
            end
        end
    end
end
