local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

-- Battleground History (Enhancements_BattlegroundHistory*.lua). Map names and
-- objective columns (flags, bases...) come from the game and are never
-- translated here. Words shared with the arena history ("VICTORY", "Damage",
-- "YOUR TEAM"...) live in ArenaHistory.lua.
local order = { "enUS", "esES", "deDE", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
local translations = {
    ["Battleground History"] = { "Battleground History", "Historial de campos de batalla", "Schlachtfeldverlauf", "Historique des champs de bataille", "Cronologia campi di battaglia", "Histórico de campos de batalha", "История полей боя", "전장 기록", "战场记录", "戰場紀錄" },
    ["Record battleground history"] = { "Record battleground history", "Registrar historial de campos de batalla", "Schlachtfeldverlauf aufzeichnen", "Enregistrer l'historique des champs de bataille", "Registra la cronologia dei campi di battaglia", "Registrar histórico de campos de batalha", "Записывать историю полей боя", "전장 기록 저장", "保存战场记录", "記錄戰場紀錄" },
    ["Open history after leaving a battleground"] = { "Open history after leaving a battleground", "Abrir el historial al salir de un campo de batalla", "Verlauf nach Verlassen eines Schlachtfelds öffnen", "Ouvrir l'historique en quittant un champ de bataille", "Apri la cronologia all'uscita da un campo di battaglia", "Abrir o histórico ao sair de um campo de batalha", "Открывать историю после выхода с поля боя", "전장을 나가면 기록 열기", "离开战场后打开记录", "離開戰場後開啟紀錄" },
    ["Open battleground history"] = { "Open battleground history", "Abrir historial de campos de batalla", "Schlachtfeldverlauf öffnen", "Ouvrir l'historique des champs de bataille", "Apri la cronologia dei campi di battaglia", "Abrir histórico de campos de batalha", "Открыть историю полей боя", "전장 기록 열기", "打开战场记录", "開啟戰場紀錄" },
    ["Battleground History will initialize after /reload."] = { "Battleground History will initialize after /reload.", "El historial de campos de batalla se activará tras /reload.", "Der Schlachtfeldverlauf startet nach /reload.", "L'historique des champs de bataille s'activera après /reload.", "La cronologia dei campi di battaglia si attiverà dopo /reload.", "O histórico de campos de batalha será ativado após /reload.", "История полей боя включится после /reload.", "/reload 후 전장 기록이 시작됩니다.", "战场记录将在 /reload 后启用。", "戰場紀錄將在 /reload 後啟用。" },
    ["Stores 100 battlegrounds per character with the result, duration, faction, your score and both teams' totals. Open with /ktbgs."] = { "Stores 100 battlegrounds per character with the result, duration, faction, your score and both teams' totals. Open with /ktbgs.", "Guarda 100 campos de batalla por personaje con el resultado, la duración, la facción, tu puntuación y los totales de los dos equipos. Abre con /ktbgs.", "Speichert 100 Schlachtfelder pro Charakter mit Ergebnis, Dauer, Fraktion, deiner Wertung und den Summen beider Teams. Öffnen mit /ktbgs.", "Conserve 100 champs de bataille par personnage avec le résultat, la durée, la faction, votre score et les totaux des deux équipes. Ouvrir avec /ktbgs.", "Salva 100 campi di battaglia per personaggio con risultato, durata, fazione, il tuo punteggio e i totali di entrambe le squadre. Apri con /ktbgs.", "Guarda 100 campos de batalha por personagem com o resultado, a duração, a facção, sua pontuação e os totais das duas equipes. Abra com /ktbgs.", "Хранит 100 полей боя на персонажа: результат, длительность, фракция, ваш счёт и итоги обеих команд. Открыть: /ktbgs.", "캐릭터당 전장 100개를 결과, 시간, 진영, 내 점수, 양 팀 합계와 함께 저장합니다. /ktbgs로 엽니다.", "每个角色保存 100 场战场，包括结果、时长、阵营、你的得分和双方队伍的总计。用 /ktbgs 打开。", "每個角色保存 100 場戰場，包括結果、時長、陣營、你的得分和雙方隊伍的總計。用 /ktbgs 開啟。" },
    ["Battleground"] = { "Battleground", "Campo de batalla", "Schlachtfeld", "Champ de bataille", "Campo di battaglia", "Campo de batalha", "Поле боя", "전장", "战场", "戰場" },
    ["Rated battleground"] = { "Rated battleground", "Campo de batalla puntuado", "Gewertetes Schlachtfeld", "Champ de bataille coté", "Campo di battaglia classificato", "Campo de batalha ranqueado", "Рейтинговое поле боя", "평점제 전장", "评级战场", "積分戰場" },
    ["Battleground Blitz"] = { "Battleground Blitz", "Campo de batalla relámpago", "Schlachtfeldblitz", "Blitz de champ de bataille", "Campo di battaglia lampo", "Ataque Relâmpago", "Блиц на поле боя", "전장 돌격전", "战场闪电战", "閃電戰場" },
    ["Brawl"] = { "Brawl", "Camorra", "Rauferei", "Choc", "Rissa", "Contenda", "Потасовка", "난투", "乱斗", "亂鬥" },
    ["Rated"] = { "Rated", "Puntuado", "Gewertet", "Coté", "Classificato", "Ranqueado", "Рейтинговые", "평점제", "评级", "積分" },
    ["Unrated"] = { "Unrated", "No puntuado", "Ungewertet", "Non coté", "Non classificato", "Não ranqueado", "Без рейтинга", "일반", "非评级", "非積分" },
    ["All"] = { "All", "Todos", "Alle", "Tous", "Tutti", "Todos", "Все", "전체", "全部", "全部" },
    ["Victories"] = { "Victories", "Victorias", "Siege", "Victoires", "Vittorie", "Vitórias", "Победы", "승리", "胜利", "勝利" },
    ["Defeats"] = { "Defeats", "Derrotas", "Niederlagen", "Défaites", "Sconfitte", "Derrotas", "Поражения", "패배", "失败", "失敗" },
    ["Horde"] = { "Horde", "Horda", "Horde", "Horde", "Orda", "Horda", "Орда", "호드", "部落", "部落" },
    ["Alliance"] = { "Alliance", "Alianza", "Allianz", "Alliance", "Alleanza", "Aliança", "Альянс", "얼라이언스", "联盟", "聯盟" },
    ["Faction"] = { "Faction", "Facción", "Fraktion", "Faction", "Fazione", "Facção", "Фракция", "진영", "阵营", "陣營" },
    ["YOUR SCORE"] = { "YOUR SCORE", "TU PUNTUACIÓN", "DEINE WERTUNG", "VOTRE SCORE", "IL TUO PUNTEGGIO", "SUA PONTUAÇÃO", "ВАШ СЧЁТ", "내 점수", "你的得分", "你的得分" },
    ["Killing Blows"] = { "Killing Blows", "Golpes de gracia", "Todesstöße", "Coups fatals", "Colpi finali", "Golpes fatais", "Смертельные удары", "결정타", "击杀", "最後一擊" },
    ["Honorable Kills"] = { "Honorable Kills", "Muertes con honor", "Ehrenhafte Siege", "Victoires honorables", "Uccisioni onorevoli", "Mortes honrosas", "Почетные победы", "명예 승수", "荣誉击杀", "榮譽擊殺" },
    ["Honor"] = { "Honor", "Honor", "Ehre", "Honneur", "Onore", "Honra", "Честь", "명예", "荣誉", "榮譽" },
    ["Players"] = { "Players", "Jugadores", "Spieler", "Joueurs", "Giocatori", "Jogadores", "Игроки", "플레이어", "玩家", "玩家" },
    ["Matches"] = { "Matches", "Partidas", "Matches", "Matchs", "Incontri", "Partidas", "Матчи", "경기", "比赛", "比賽" },
    ["Win rate"] = { "Win rate", "Porcentaje de victorias", "Siegquote", "Taux de victoire", "Percentuale di vittorie", "Taxa de vitórias", "Доля побед", "승률", "胜率", "勝率" },
    ["Type"] = { "Type", "Tipo", "Typ", "Type", "Tipo", "Tipo", "Тип", "유형", "类型", "類型" },
    ["Result"] = { "Result", "Resultado", "Ergebnis", "Résultat", "Risultato", "Resultado", "Итог", "결과", "结果", "結果" },
    ["Map"] = { "Map", "Mapa", "Karte", "Carte", "Mappa", "Mapa", "Карта", "지도", "地图", "地圖" },
    ["BATTLEGROUNDS  -  click to view the match"] = { "BATTLEGROUNDS  -  click to view the match", "CAMPOS DE BATALLA  -  pulsa para ver la partida", "SCHLACHTFELDER  -  klicken, um das Match zu sehen", "CHAMPS DE BATAILLE  -  cliquez pour voir le match", "CAMPI DI BATTAGLIA  -  clicca per vedere l'incontro", "CAMPOS DE BATALHA  -  clique para ver a partida", "ПОЛЯ БОЯ  -  нажмите, чтобы открыть матч", "전장  -  클릭하여 경기 보기", "战场  -  点击查看比赛", "戰場  -  點擊查看比賽" },
    ["Last 100 battlegrounds per character. Data comes from Blizzard's end-of-match scoreboard; -- = unavailable."] = { "Last 100 battlegrounds per character. Data comes from Blizzard's end-of-match scoreboard; -- = unavailable.", "Últimos 100 campos de batalla por personaje. Los datos salen del marcador final de Blizzard; -- = no disponible.", "Letzte 100 Schlachtfelder pro Charakter. Die Daten stammen aus Blizzards Endergebnis-Tabelle; -- = nicht verfügbar.", "100 derniers champs de bataille par personnage. Les données viennent du tableau de fin de match de Blizzard ; -- = indisponible.", "Ultimi 100 campi di battaglia per personaggio. I dati provengono dal tabellone finale di Blizzard; -- = non disponibile.", "Últimos 100 campos de batalha por personagem. Os dados vêm do placar final da Blizzard; -- = indisponível.", "Последние 100 полей боя на персонажа. Данные из итоговой таблицы Blizzard; -- = нет данных.", "캐릭터당 최근 전장 100개. 블리자드 경기 종료 점수판의 데이터입니다. -- = 정보 없음.", "每个角色最近 100 场战场。数据来自暴雪的赛后计分板；-- = 不可用。", "每個角色最近 100 場戰場。資料來自暴雪的賽後計分板；-- = 無法取得。" },
    ["NO MATCHES FOR THESE FILTERS"] = { "NO MATCHES FOR THESE FILTERS", "NO HAY PARTIDAS CON ESTOS FILTROS", "KEINE MATCHES FÜR DIESE FILTER", "AUCUN MATCH POUR CES FILTRES", "NESSUN INCONTRO CON QUESTI FILTRI", "NENHUMA PARTIDA COM ESTES FILTROS", "НЕТ МАТЧЕЙ ПО ЭТИМ ФИЛЬТРАМ", "이 필터에 맞는 경기 없음", "没有符合筛选条件的比赛", "沒有符合篩選條件的比賽" },
    ["NO BATTLEGROUNDS YET"] = { "NO BATTLEGROUNDS YET", "AÚN NO HAY CAMPOS DE BATALLA", "NOCH KEINE SCHLACHTFELDER", "AUCUN CHAMP DE BATAILLE POUR L'INSTANT", "ANCORA NESSUN CAMPO DI BATTAGLIA", "NENHUM CAMPO DE BATALHA AINDA", "ПОЛЕЙ БОЯ ПОКА НЕТ", "아직 전장 기록 없음", "暂无战场", "尚無戰場" },
    ["Finish a battleground to start"] = { "Finish a battleground to start", "Termina un campo de batalla para empezar", "Beende ein Schlachtfeld, um zu beginnen", "Terminez un champ de bataille pour commencer", "Completa un campo di battaglia per iniziare", "Termine um campo de batalha para começar", "Завершите поле боя, чтобы начать", "전장을 하나 끝내면 시작됩니다", "完成一场战场即可开始", "完成一場戰場即可開始" },
}

-- Common words ("All", "Horde", "Honor"...) may already be translated by other
-- modules: fill only what is missing or still the English placeholder.
for key, values in pairs(translations) do
    for index, code in ipairs(order) do
        local locale = locales[code]
        local value = values[index]
        if type(locale) == "table" and value and (rawget(locale, key) == nil or rawget(locale, key) == key) then
            locale[key] = value
        end
    end
end
