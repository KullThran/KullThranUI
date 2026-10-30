local _, ns = ...
local locales = ns and ns.Locales
if type(locales) ~= "table" then return end

-- Arena History (Enhancements_ArenaHistory*.lua). Addon names and arena map
-- names come from the game and are never translated here.
local order = { "enUS", "esES", "deDE", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
local translations = {
    ["Arena History"] = { "Arena History", "Historial de arenas", "Arenaverlauf", "Historique d'arène", "Cronologia arene", "Histórico de arenas", "История арен", "투기장 기록", "竞技场记录", "競技場紀錄" },
    ["Record arena history"] = { "Record arena history", "Registrar historial de arenas", "Arenaverlauf aufzeichnen", "Enregistrer l'historique d'arène", "Registra la cronologia arene", "Registrar histórico de arenas", "Записывать историю арен", "투기장 기록 저장", "记录竞技场历史", "記錄競技場歷史" },
    ["Open history after leaving an arena"] = { "Open history after leaving an arena", "Abrir el historial al salir de una arena", "Verlauf nach Verlassen einer Arena öffnen", "Ouvrir l'historique en quittant une arène", "Apri la cronologia all'uscita da un'arena", "Abrir o histórico ao sair de uma arena", "Открывать историю после выхода с арены", "투기장을 나가면 기록 열기", "离开竞技场后打开记录", "離開競技場後開啟紀錄" },
    ["Open arena history"] = { "Open arena history", "Abrir historial de arenas", "Arenaverlauf öffnen", "Ouvrir l'historique d'arène", "Apri la cronologia arene", "Abrir histórico de arenas", "Открыть историю арен", "투기장 기록 열기", "打开竞技场记录", "開啟競技場紀錄" },
    ["Arena History will initialize after /reload."] = { "Arena History will initialize after /reload.", "El historial de arenas se activará tras /reload.", "Der Arenaverlauf startet nach /reload.", "L'historique d'arène s'activera après /reload.", "La cronologia arene si attiverà dopo /reload.", "O histórico de arenas será ativado após /reload.", "История арен включится после /reload.", "/reload 후 투기장 기록이 시작됩니다.", "竞技场记录将在 /reload 后启用。", "競技場紀錄將在 /reload 後啟用。" },
    ["Stores 100 arenas per character with both teams, damage, healing and rating changes. Open with /ktarenas."] = { "Stores 100 arenas per character with both teams, damage, healing and rating changes. Open with /ktarenas.", "Guarda 100 arenas por personaje con los dos equipos, daño, sanación y cambios de índice. Abre con /ktarenas.", "Speichert 100 Arenen pro Charakter mit beiden Teams, Schaden, Heilung und Wertungsänderungen. Öffnen mit /ktarenas.", "Conserve 100 arènes par personnage avec les deux équipes, les dégâts, les soins et les variations de cote. Ouvrir avec /ktarenas.", "Salva 100 arene per personaggio con entrambe le squadre, danni, cure e variazioni di punteggio. Apri con /ktarenas.", "Guarda 100 arenas por personagem com as duas equipes, dano, cura e mudanças de pontuação. Abra com /ktarenas.", "Хранит 100 арен на персонажа: обе команды, урон, исцеление и изменения рейтинга. Открыть: /ktarenas.", "캐릭터당 투기장 100개를 양 팀, 피해량, 치유량, 평점 변화와 함께 저장합니다. /ktarenas로 엽니다.", "每个角色保存 100 场竞技场，包括双方队伍、伤害、治疗和评级变化。用 /ktarenas 打开。", "每個角色保存 100 場競技場，包括雙方隊伍、傷害、治療和評分變化。用 /ktarenas 開啟。" },
    ["Arenas are not available on the WoW Forever client, so Arena History is disabled there."] = { "Arenas are not available on the WoW Forever client, so Arena History is disabled there.", "El cliente de WoW Forever no tiene arenas, así que el historial de arenas está desactivado ahí.", "Der WoW-Forever-Client hat keine Arenen, daher ist der Arenaverlauf dort deaktiviert.", "Le client WoW Forever n'a pas d'arènes : l'historique d'arène y est désactivé.", "Il client WoW Forever non ha arene, quindi la cronologia arene è disattivata.", "O cliente WoW Forever não tem arenas, então o histórico de arenas fica desativado nele.", "В клиенте WoW Forever нет арен, поэтому история арен там отключена.", "WoW Forever 클라이언트에는 투기장이 없어 투기장 기록이 비활성화됩니다.", "WoW Forever 客户端没有竞技场，因此竞技场记录在此禁用。", "WoW Forever 用戶端沒有競技場，因此競技場紀錄在此停用。" },
    ["NO ARENAS YET"] = { "NO ARENAS YET", "AÚN NO HAY ARENAS", "NOCH KEINE ARENEN", "AUCUNE ARÈNE POUR L'INSTANT", "NESSUNA ARENA ANCORA", "NENHUMA ARENA AINDA", "АРЕН ПОКА НЕТ", "아직 투기장 기록 없음", "暂无竞技场", "尚無競技場" },
    ["Finish an arena to start"] = { "Finish an arena to start", "Termina una arena para empezar", "Beende eine Arena, um zu beginnen", "Terminez une arène pour commencer", "Completa un'arena per iniziare", "Termine uma arena para começar", "Завершите арену, чтобы начать", "투기장을 하나 끝내면 시작됩니다", "完成一场竞技场即可开始", "完成一場競技場即可開始" },
    ["LATEST MATCH"] = { "LATEST MATCH", "ÚLTIMA PARTIDA", "LETZTES MATCH", "DERNIER MATCH", "ULTIMO INCONTRO", "ÚLTIMA PARTIDA", "ПОСЛЕДНИЙ МАТЧ", "최근 경기", "最近一场", "最近一場" },
    ["SELECTED MATCH"] = { "SELECTED MATCH", "PARTIDA SELECCIONADA", "AUSGEWÄHLTES MATCH", "MATCH SÉLECTIONNÉ", "INCONTRO SELEZIONATO", "PARTIDA SELECIONADA", "ВЫБРАННЫЙ МАТЧ", "선택한 경기", "所选比赛", "所選比賽" },
    ["VICTORY"] = { "VICTORY", "VICTORIA", "SIEG", "VICTOIRE", "VITTORIA", "VITÓRIA", "ПОБЕДА", "승리", "胜利", "勝利" },
    ["DEFEAT"] = { "DEFEAT", "DERROTA", "NIEDERLAGE", "DÉFAITE", "SCONFITTA", "DERROTA", "ПОРАЖЕНИЕ", "패배", "失败", "失敗" },
    ["DRAW"] = { "DRAW", "EMPATE", "UNENTSCHIEDEN", "MATCH NUL", "PAREGGIO", "EMPATE", "НИЧЬЯ", "무승부", "平局", "平手" },
    ["EVEN"] = { "EVEN", "IGUALADO", "AUSGEGLICHEN", "ÉGALITÉ", "IN PARITÀ", "EMPATADO", "РАВНЫЙ СЧЁТ", "동률", "持平", "持平" },
    ["Solo Shuffle"] = { "Solo Shuffle", "Solo Shuffle", "Solo-Shuffle", "Solo Shuffle", "Solo Shuffle", "Solo Shuffle", "Соло-арена", "1인 투기장", "单人竞技场", "單人競技場" },
    ["Skirmish"] = { "Skirmish", "Escaramuza", "Übungsgefecht", "Escarmouche", "Schermaglia", "Escaramuça", "Стычка", "연습 전투", "练习赛", "練習賽" },
    ["Arena"] = { "Arena", "Arena", "Arena", "Arène", "Arena", "Arena", "Арена", "투기장", "竞技场", "競技場" },
    ["Rated %dv%d"] = { "Rated %dv%d", "Puntuada %dv%d", "Gewertet %dv%d", "Cotée %dv%d", "Classificata %dv%d", "Ranqueada %dv%d", "Рейтинговая %dv%d", "평점 %dv%d", "评级 %dv%d", "積分 %dv%d" },
    ["Duration"] = { "Duration", "Duración", "Dauer", "Durée", "Durata", "Duração", "Длительность", "시간", "时长", "時長" },
    ["Rounds won"] = { "Rounds won", "Rondas ganadas", "Gewonnene Runden", "Manches gagnées", "Round vinti", "Rodadas vencidas", "Выиграно раундов", "승리한 라운드", "获胜回合", "獲勝回合" },
    ["Rating"] = { "Rating", "Índice", "Wertung", "Cote", "Punteggio", "Pontuação", "Рейтинг", "평점", "评级", "積分" },
    ["MMR"] = { "MMR", "MMR", "MMR", "MMR", "MMR", "MMR", "MMR", "MMR", "MMR", "MMR" },
    ["Damage"] = { "Damage", "Daño", "Schaden", "Dégâts", "Danni", "Dano", "Урон", "피해", "伤害", "傷害" },
    ["Healing"] = { "Healing", "Sanación", "Heilung", "Soins", "Cure", "Cura", "Исцеление", "치유", "治疗", "治療" },
    ["KB"] = { "KB", "GM", "TS", "CF", "CF", "GF", "СУ", "결정타", "击杀", "擊殺" },
    ["Deaths"] = { "Deaths", "Muertes", "Tode", "Morts", "Morti", "Mortes", "Смерти", "죽음", "死亡", "死亡" },
    ["YOUR TEAM"] = { "YOUR TEAM", "TU EQUIPO", "DEIN TEAM", "VOTRE ÉQUIPE", "LA TUA SQUADRA", "SUA EQUIPE", "ВАША КОМАНДА", "내 팀", "我方队伍", "我方隊伍" },
    ["ENEMY TEAM"] = { "ENEMY TEAM", "EQUIPO ENEMIGO", "GEGNERTEAM", "ÉQUIPE ADVERSE", "SQUADRA NEMICA", "EQUIPE INIMIGA", "КОМАНДА ПРОТИВНИКА", "상대 팀", "敌方队伍", "敵方隊伍" },
    ["LOBBY"] = { "LOBBY", "SALA", "LOBBY", "SALON", "LOBBY", "SALA", "ЛОББИ", "대기실", "大厅", "大廳" },
    ["PREVIOUS ARENAS  -  click to view the match"] = { "PREVIOUS ARENAS  -  click to view the match", "ARENAS ANTERIORES  -  pulsa para ver la partida", "FRÜHERE ARENEN  -  klicken, um das Match zu sehen", "ARÈNES PRÉCÉDENTES  -  cliquez pour voir le match", "ARENE PRECEDENTI  -  clicca per vedere l'incontro", "ARENAS ANTERIORES  -  clique para ver a partida", "ПРЕДЫДУЩИЕ АРЕНЫ  -  нажмите, чтобы открыть матч", "이전 투기장  -  클릭하여 경기 보기", "之前的竞技场  -  点击查看比赛", "之前的競技場  -  點擊查看比賽" },
    ["Latest match"] = { "Latest match", "Última partida", "Letztes Match", "Dernier match", "Ultimo incontro", "Última partida", "Последний матч", "최근 경기", "最近一场", "最近一場" },
    ["Last 100 arenas per character. Data comes from Blizzard's end-of-match scoreboard; -- = unavailable."] = { "Last 100 arenas per character. Data comes from Blizzard's end-of-match scoreboard; -- = unavailable.", "Últimas 100 arenas por personaje. Los datos salen del marcador final de Blizzard; -- = no disponible.", "Letzte 100 Arenen pro Charakter. Die Daten stammen aus Blizzards Endergebnis-Tabelle; -- = nicht verfügbar.", "100 dernières arènes par personnage. Les données viennent du tableau de fin de match de Blizzard ; -- = indisponible.", "Ultime 100 arene per personaggio. I dati provengono dal tabellone finale di Blizzard; -- = non disponibile.", "Últimas 100 arenas por personagem. Os dados vêm do placar final da Blizzard; -- = indisponível.", "Последние 100 арен на персонажа. Данные из итоговой таблицы Blizzard; -- = нет данных.", "캐릭터당 최근 투기장 100개. 블리자드 경기 종료 점수판의 데이터입니다. -- = 정보 없음.", "每个角色最近 100 场竞技场。数据来自暴雪的赛后计分板；-- = 不可用。", "每個角色最近 100 場競技場。資料來自暴雪的賽後計分板；-- = 無法取得。" },
}

-- Common words ("Arena", "Damage", "Rating"...) may already be translated by other
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
