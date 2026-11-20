-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_Engine", function(...)
if (GAME_LOCALE or GetLocale()) ~= "ptBR" then
  return
end

local L = KUIAR_Runtime.L

-- M33kAuras
--[[Translation missing --]]
L[ [=[ Filter formats: 'Name', 'Name-Realm', '-Realm'.

Supports multiple entries, separated by commas
Can use \ to escape -.]=] ] = [=[ Filter formats: 'Name', 'Name-Realm', '-Realm'.

Supports multiple entries, separated by commas
Can use \ to escape -.]=]
L["%s Overlay Color"] = "%s Cor de Sobreposição"
L["* Suffix"] = "* Sufixo"
L["/wa help - Show this message"] = "/wa help - Mostrar essa mensagem"
L["/wa minimap - Toggle the minimap icon"] = "/wa minimap - Mostrar/esconder o ícone de minimapa"
L["/wa pprint - Show the results from the most recent profiling"] = "/wa pprint - Mostra os resultados da criação de perfil mais recente"
L["/wa pstart - Start profiling. Optionally include a duration in seconds after which profiling automatically stops. To profile the next combat/encounter, pass a \"combat\" or \"encounter\" argument."] = "/wa pstart - Inicia a criação de perfil. Opcionalmente inclui uma duração em segundos em que a criação de perfis automaticamente para. Para traçar o perfil do próximo combate/encontro, passe um argumento de \"combate\" ou \"encontro\"."
L["/wa pstop - Finish profiling"] = "/wa pstop - Concluir criação de perfil"
L["/wa repair - Repair tool"] = "/wa repair - Ferramenta de reparo"
L["|cffeda55fLeft-Click|r to toggle showing the main window."] = "|cffeda55fLeft-Click|r para alternar a exibição da janela principal."
L["|cffeda55fMiddle-Click|r to toggle the minimap icon on or off."] = "|cffeda55fMiddle-Click|r para esconder ou mostrar o ícone do minimapa."
L["|cffeda55fRight-Click|r to toggle performance profiling window."] = "|cffeda55fRight-Click|r mostrar/esconder a janela de perfil de desempenho."
L["|cffeda55fShift-Click|r to pause addon execution."] = "|cffeda55fShift-Click|r para pausar a execução do addon."
--[[Translation missing --]]
L["|cffff0000deprecated|r"] = "|cffff0000deprecated|r"
--[[Translation missing --]]
L["|cFFFF0000Not|r Item Bonus Id Equipped"] = "|cFFFF0000Not|r Item Bonus Id Equipped"
--[[Translation missing --]]
L["|cFFFF0000Not|r Item Equipped"] = "|cFFFF0000Not|r Item Equipped"
--[[Translation missing --]]
L["|cFFFF0000Not|r Player Name/Realm"] = "|cFFFF0000Not|r Player Name/Realm"
--[[Translation missing --]]
L["|cFFFF0000Not|r Spell Known"] = "|cFFFF0000Not|r Spell Known"
--[[Translation missing --]]
L[ [=[|cFFFF0000Support for unfiltered COMBAT_LOG_EVENT_UNFILTERED is deprecated|r
COMBAT_LOG_EVENT_UNFILTERED without a filter are disabled as it’s very performance costly.
Find more information:
https://github.com/m33shoq/M33kAuras/wiki/Custom-Triggers#events]=] ] = [=[|cFFFF0000Support for unfiltered COMBAT_LOG_EVENT_UNFILTERED is deprecated|r
COMBAT_LOG_EVENT_UNFILTERED without a filter are disabled as it’s very performance costly.
Find more information:
https://github.com/m33shoq/M33kAuras/wiki/Custom-Triggers#events]=]
L["|cFFffcc00Extra Options:|r %s"] = [=[|cFFffcc00Opções Extra:|r %s

]=]
L["|cFFffcc00Extra Options:|r None"] = "|cFFffcc00Opções Extra:|r Nenhuma"
--[[Translation missing --]]
L[ [=[• |cff00ff00Player|r, |cff00ff00Target|r, |cff00ff00Focus|r, and |cff00ff00Pet|r correspond directly to those individual unitIDs.
• |cff00ff00Specific Unit|r lets you provide a specific valid unitID to watch.
|cffff0000Note|r: The game will not fire events for all valid unitIDs, making some untrackable by this trigger.
• |cffffff00Party|r, |cffffff00Raid|r, |cffffff00Boss|r, |cffffff00Arena|r, and |cffffff00Nameplate|r can match multiple corresponding unitIDs.
• |cffffff00Smart Group|r adjusts to your current group type, matching just the "player" when solo, "party" units (including "player") in a party or "raid" units in a raid.

|cffffff00*|r Yellow Unit settings will create clones for each matching unit while this trigger is providing Dynamic Info to the Aura.]=] ] = [=[• |cff00ff00Player|r, |cff00ff00Target|r, |cff00ff00Focus|r, and |cff00ff00Pet|r correspond directly to those individual unitIDs.
• |cff00ff00Specific Unit|r lets you provide a specific valid unitID to watch.
|cffff0000Note|r: The game will not fire events for all valid unitIDs, making some untrackable by this trigger.
• |cffffff00Party|r, |cffffff00Raid|r, |cffffff00Boss|r, |cffffff00Arena|r, and |cffffff00Nameplate|r can match multiple corresponding unitIDs.
• |cffffff00Smart Group|r adjusts to your current group type, matching just the "player" when solo, "party" units (including "player") in a party or "raid" units in a raid.

|cffffff00*|r Yellow Unit settings will create clones for each matching unit while this trigger is providing Dynamic Info to the Aura.]=]
--[[Translation missing --]]
L["1. Profession 1. Accessory"] = "1. Profession 1. Accessory"
--[[Translation missing --]]
L["1. Profession 2. Accessory"] = "1. Profession 2. Accessory"
--[[Translation missing --]]
L["1. Professsion Tool"] = "1. Professsion Tool"
L["10 Man Raid"] = "Raide de 10 jogadores"
--[[Translation missing --]]
L["10 Player Raid"] = "10 Player Raid"
--[[Translation missing --]]
L["10 Player Raid (Heroic)"] = "10 Player Raid (Heroic)"
--[[Translation missing --]]
L["10 Player Raid (Normal)"] = "10 Player Raid (Normal)"
--[[Translation missing --]]
L["2. Profession 1. Accessory"] = "2. Profession 1. Accessory"
--[[Translation missing --]]
L["2. Profession 2. Accessory"] = "2. Profession 2. Accessory"
--[[Translation missing --]]
L["2. Professsion Tool"] = "2. Professsion Tool"
L["20 Man Raid"] = "Raide de 20 jogadores"
--[[Translation missing --]]
L["20 Player Raid"] = "20 Player Raid"
L["25 Man Raid"] = "Raide de 25 jogadores"
--[[Translation missing --]]
L["25 Player Raid"] = "25 Player Raid"
--[[Translation missing --]]
L["25 Player Raid (Heroic)"] = "25 Player Raid (Heroic)"
--[[Translation missing --]]
L["25 Player Raid (Normal)"] = "25 Player Raid (Normal)"
L["40 Man Raid"] = "Raide de 40 jogadores"
--[[Translation missing --]]
L["40 Player Raid"] = "40 Player Raid"
L["5 Man Dungeon"] = "Masmorra de 5 jogadores"
--[[Translation missing --]]
--[[Translation missing --]]
L["A trigger in this aura is set up to track a soft target unit, but you don't have the CVars set up for this to work correctly. Consider either changing the unit tracked, or configuring the Soft Target CVars."] = "A trigger in this aura is set up to track a soft target unit, but you don't have the CVars set up for this to work correctly. Consider either changing the unit tracked, or configuring the Soft Target CVars."
L["Abbreviate"] = "Abreviar"
L["AbbreviateLargeNumbers (Blizzard)"] = "AbreviarNúmerosGrandes (Blizzard)"
L["AbbreviateNumbers (Blizzard)"] = "AbreviarNúmeros (Blizzard)"
L["Absorb"] = "Absorver"
--[[Translation missing --]]
L["Absorb and Healing"] = "Absorb and Healing"
--[[Translation missing --]]
L["Absorb Heal Overlay"] = "Absorb Heal Overlay"
--[[Translation missing --]]
L["Absorb Overlay"] = "Absorb Overlay"
L["Absorbed"] = "Absorvido"
L["Action Button Glow"] = "Brilho do botão de ação"
L["Actions"] = "Ações"
L["Active"] = "Ativo"
--[[Translation missing --]]
L[ [=[Active boss mod addon: |cFFffcc00BigWigs|r

Note: This trigger will use BigWigs or DBM, in that order if both are installed.]=] ] = [=[Active boss mod addon: |cFFffcc00BigWigs|r

Note: This trigger will use BigWigs or DBM, in that order if both are installed.]=]
--[[Translation missing --]]
L[ [=[Active boss mod addon: |cFFffcc00DBM|r

Note: This trigger will use BigWigs or DBM, in that order if both are installed.]=] ] = [=[Active boss mod addon: |cFFffcc00DBM|r

Note: This trigger will use BigWigs or DBM, in that order if both are installed.]=]
L["Add"] = "Adicionar"
L["Add Missing Auras"] = "Adicionar auras faltantes"
--[[Translation missing --]]
L["Advanced Caster's Target Check"] = "Advanced Caster's Target Check"
L["Affected"] = "Afetado"
L["Affected Unit Count"] = "Contagem de unidades afetadas"
--[[Translation missing --]]
L["Afk"] = "Afk"
L["Aggro"] = "Aggro"
L["Agility"] = "Agilidade"
L["Ahn'Qiraj"] = "Ahn'Qiraj"
L["Alert Type"] = "Tipo de alerta"
L["Alive"] = "Vivo"
L["All"] = "Todos"
--[[Translation missing --]]
L["All children of this aura will also not be loaded, to minimize the chance of further corruption."] = "All children of this aura will also not be loaded, to minimize the chance of further corruption."
--[[Translation missing --]]
L["All States table contains a non table at key: '%s'."] = "All States table contains a non table at key: '%s'."
L["All Triggers"] = "Todos os Gatilhos"
L["Alliance"] = "Aliança"
L["Allow partial matches"] = "Permitir combinações parciais"
L["Alpha"] = "Transparência"
L["Alternate Power"] = "Alternar Poder"
L["Always"] = "Sempre"
L["Always active trigger"] = "Gatilho sempre ativo"
L["Always include realm"] = "Sempre incluir reino"
L["Always True"] = "Sempre Verdadeiro"
L["Amount"] = "Quantidade"
--[[Translation missing --]]
L["Anchoring"] = "Anchoring"
L["And Talent"] = "E Também o Talento"
--[[Translation missing --]]
L["Angle and Radius"] = "Angle and Radius"
L["Animations"] = "Animações"
L["Anticlockwise"] = "Anti-horário"
L["Anub'Rekhan"] = "Anub'Rekhan"
L["Any"] = "Qualquer"
L["Any Triggers"] = "Quaisquer gatilhos"
L["AOE"] = "AOE"
L["Arcane Resistance"] = "Resistência Arcana"
--[[Translation missing --]]
L[ [=[Are you sure you want to run the |cffff0000EXPERIMENTAL|r repair tool?
This will overwrite any changes you have made since the last database upgrade.
Last upgrade: %s]=] ] = [=[Are you sure you want to run the |cffff0000EXPERIMENTAL|r repair tool?
This will overwrite any changes you have made since the last database upgrade.
Last upgrade: %s]=]
L["Arena"] = "Arena"
L["Armor (%)"] = "Armadura (%)"
L["Armor against Target (%)"] = "Armadura contra o Alvo (%)"
--[[Translation missing --]]
L["Armor Peneration Percent"] = "Armor Peneration Percent"
--[[Translation missing --]]
L["Armor Peneration Rating"] = "Armor Peneration Rating"
L["Armor Rating"] = "Classificação de armadura"
L["Array"] = "Arranjo"
L["Ascending"] = "Ascendente"
L["Assigned Role"] = "Função Atribuída"
--[[Translation missing --]]
L["Assigned Role Icon"] = "Assigned Role Icon"
--[[Translation missing --]]
L["Assist"] = "Assist"
--[[Translation missing --]]
L["Assisted Combat Next Cast"] = "Assisted Combat Next Cast"
L["At Least One Enemy"] = "Pelo Menos Um Inimigo"
L["At missing Value"] = "No valor ausente"
L["At Percent"] = "Na porcentagem"
L["At Value"] = "Em valor"
--[[Translation missing --]]
L["At War"] = "At War"
L["Attach to End"] = "Anexar ao final"
--[[Translation missing --]]
L["Attach to End, backwards"] = "Attach to End, backwards"
--[[Translation missing --]]
L["Attach to Point"] = "Attach to Point"
L["Attach to Start"] = "Anexar ao inicio"
L["Attack Power"] = "Poder de ataque"
L["Attackable"] = "Atacável"
L["Attackable Target"] = "Alvo atacável "
L["Aura"] = "Aura"
L["Aura '%s': %s"] = "Aura '%s': %s"
L["Aura Applied"] = "Aura Aplicada"
L["Aura Applied Dose"] = "Dose de Aura Aplicada"
L["Aura Broken"] = "Aura violada"
L["Aura Broken Spell"] = "Feitiço violar de aura"
--[[Translation missing --]]
L["Aura is using deprecated SetDurationInfo"] = "Aura is using deprecated SetDurationInfo"
--[[Translation missing --]]
L["Aura loaded"] = "Aura loaded"
L["Aura Name"] = "Nome da Aura"
L["Aura Names"] = "Nomes das Auras"
L["Aura Refresh"] = "Aura Restaurada"
L["Aura Removed"] = "Aura Removida"
L["Aura Removed Dose"] = "Dose de Aura Removida"
L["Aura Stack"] = "Monte da Aura"
L["Aura Type"] = "Tipo de Aura"
--[[Translation missing --]]
L["Aura Version: %s"] = "Aura Version: %s"
L["Aura(s) Found"] = "Aura(s) Encontrada(s)"
L["Aura(s) Missing"] = "Aura(s) Faltando"
L["Aura:"] = "Aura:"
--[[Translation missing --]]
L["Auras"] = "Auras"
L["Auras:"] = "Auras:"
L["Author Options"] = "Opções de Autor"
L["Auto"] = "Auto"
--[[Translation missing --]]
L["Autocast Shine"] = "Autocast Shine"
L["Automatic"] = "Automático"
L["Automatic Length"] = "Comprimento Automático"
L["Automatic Rotation"] = "Rotação Automática"
--[[Translation missing --]]
L["Available features: %s"] = "Available features: %s"
--[[Translation missing --]]
L["Avoidance (%)"] = "Avoidance (%)"
--[[Translation missing --]]
L["Avoidance Rating"] = "Avoidance Rating"
L["Ayamiss the Hunter"] = "Ayamiss, o Caçador"
--[[Translation missing --]]
L["Azuregos"] = "Azuregos"
L["Back and Forth"] = "Vai e volta"
L["Background"] = "Plano de fundo"
L["Background Color"] = "Cor do Plano de Fundo"
--[[Translation missing --]]
L["Balnazzar"] = "Balnazzar"
--[[Translation missing --]]
L["Bar Color/Gradient Start"] = "Bar Color/Gradient Start"
--[[Translation missing --]]
L["Bar enabled in BigWigs settings"] = "Bar enabled in BigWigs settings"
--[[Translation missing --]]
L["Bar enabled in Boss Mod addon settings"] = "Bar enabled in Boss Mod addon settings"
--[[Translation missing --]]
L["Bar enabled in DBM settings"] = "Bar enabled in DBM settings"
--[[Translation missing --]]
L["Bar Texture"] = "Bar Texture"
--[[Translation missing --]]
L["Bar Type"] = "Bar Type"
L["Baron Geddon"] = "Barão Geddon"
--[[Translation missing --]]
L["Battle for Azeroth"] = "Battle for Azeroth"
L["Battle.net Whisper"] = "Battle.net Sussuro"
L["Battleground"] = "Campo de Batalha"
L["Battleguard Sartura"] = "Guarda de Batalha Sartura"
--[[Translation missing --]]
L["Beastmaster"] = "Beastmaster"
--[[Translation missing --]]
L["Beatrix"] = "Beatrix"
L["BG>Raid>Party>Say"] = "CB>Raide>Grupo>Dizer"
L["BG-System Alliance"] = "CB-Sistema da Aliança"
L["BG-System Horde"] = "CB-Sistema da Horda"
L["BG-System Neutral"] = "CB-Sistema Neutro"
L["Big Number"] = "Número Grande"
L["BigWigs Addon"] = "Addon BigWigs"
L["BigWigs Message"] = "Mensagem do BigWigs"
--[[Translation missing --]]
L["BigWigs Stage"] = "BigWigs Stage"
L["BigWigs Timer"] = "Cronômetro do BigWigs"
L["Black Wing Lair"] = "Covil Asa Negra"
--[[Translation missing --]]
L["Bleed"] = "Bleed"
L["Blizzard Combat Text"] = "Texto de Combate da Blizzard"
--[[Translation missing --]]
L["Blizzard Cooldown Reduction"] = "Blizzard Cooldown Reduction"
L["Block"] = "Bloquear"
L["Block (%)"] = "Bloqueio (%)"
L["Block against Target (%)"] = "Bloqueio contra o Alvo (%)"
--[[Translation missing --]]
L["Block Value"] = "Block Value"
L["Blocked"] = "Bloqueado"
--[[Translation missing --]]
L["Blood"] = "Blood"
--[[Translation missing --]]
L["Blood Rune #1"] = "Blood Rune #1"
--[[Translation missing --]]
L["Blood Rune #2"] = "Blood Rune #2"
L["Bloodlord Mandokir"] = "Sangrelorde Mandokir"
--[[Translation missing --]]
L["Bonus Reputation Gain"] = "Bonus Reputation Gain"
L["Border"] = "Borda"
L["Boss"] = "Chefe"
L["Boss Emote"] = "Emote do Chefe"
--[[Translation missing --]]
L["Boss Mod Announce"] = "Boss Mod Announce"
--[[Translation missing --]]
L["Boss Mod Stage"] = "Boss Mod Stage"
--[[Translation missing --]]
L["Boss Mod Stage (Event)"] = "Boss Mod Stage (Event)"
--[[Translation missing --]]
L["Boss Mod Timer"] = "Boss Mod Timer"
L["Boss Whisper"] = "Sussurro do Chefe"
L["Bottom"] = "Embaixo"
L["Bottom Left"] = "Embaixo à esquerda"
L["Bottom Right"] = "Embaixo à direita"
L["Bottom to Top"] = "De baixo para cima"
L["Bounce"] = "Salto"
L["Bounce with Decay"] = "Salto com declínio"
--[[Translation missing --]]
L["Break"] = "Break"
--[[Translation missing --]]
L["BreakUpLargeNumbers (Blizzard)"] = "BreakUpLargeNumbers (Blizzard)"
L["Broodlord Lashlayer"] = "Prolemestre Flagelador"
L["Buff"] = "Buff"
--[[Translation missing --]]
L["Buff/Debuff"] = "Buff/Debuff"
L["Buffed/Debuffed"] = "Buffado/Debuffado"
--[[Translation missing --]]
L["Burning Crusade"] = "Burning Crusade"
L["Buru the Gorger"] = "Buru, o Banqueteador"
--[[Translation missing --]]
L["Caldoran"] = "Caldoran"
--[[Translation missing --]]
L["Callback function"] = "Callback function"
L["Can be used for e.g. checking if \"boss1target\" is the same as \"player\"."] = "Pode ser usado, por exemplo, para checar se \"chefe1alvo\" é o mesmo que \"jogador\"."
L["Cancel"] = "Cancelar"
--[[Translation missing --]]
L[ [=[Cannot change secure frame in combat lockdown. Find more information:
https://github.com/m33shoq/M33kAuras/wiki/Protected-Frames]=] ] = [=[Cannot change secure frame in combat lockdown. Find more information:
https://github.com/m33shoq/M33kAuras/wiki/Protected-Frames]=]
L["Can't schedule timer with %i, due to a World of Warcraft bug with high computer uptime. (Uptime: %i). Please restart your computer."] = "Não é possível agendar o cronômetro com %i, devido a um bug do World of Warcraft com alto tempo de atividade do computador. (Tempo de atividade: %i). Por favor, reinicie o seu computador."
--[[Translation missing --]]
L["Capped"] = "Capped"
--[[Translation missing --]]
L["Capped at Season Max"] = "Capped at Season Max"
--[[Translation missing --]]
L["Capped at Weekly Max"] = "Capped at Weekly Max"
L["Cast"] = "Lançar"
L["Cast Bar"] = "Barra de Lançamento"
L["Cast Failed"] = "Lançamento falho"
L["Cast Start"] = "Começar lançamento"
L["Cast Success"] = "Sucesso no lançamento"
L["Cast Type"] = "Tipo de lançamento"
L["Caster"] = "Lançador"
L["Caster Name"] = "Nome do Lançador"
L["Caster Realm"] = "Reino do Lançador"
L["Caster Unit"] = "Unidade de Lançador"
--[[Translation missing --]]
L["Casters Name/Realm"] = "Casters Name/Realm"
L["Caster's Target"] = "Alvo do Lançador"
--[[Translation missing --]]
L["Cataclysm"] = "Cataclysm"
L["Ceil"] = "Teto"
L["Center"] = "Centro"
--[[Translation missing --]]
L["Center, then alternating bottom and top"] = "Center, then alternating bottom and top"
--[[Translation missing --]]
L["Center, then alternating left and right"] = "Center, then alternating left and right"
--[[Translation missing --]]
L["Center, then alternating right and left"] = "Center, then alternating right and left"
--[[Translation missing --]]
L["Center, then alternating top and bottom"] = "Center, then alternating top and bottom"
L["Centered Horizontal"] = "Centralizado Horizontalmente"
--[[Translation missing --]]
L["Centered Horizontal, then Centered Vertical"] = "Centered Horizontal, then Centered Vertical"
--[[Translation missing --]]
L["Centered Horizontal, then Down"] = "Centered Horizontal, then Down"
--[[Translation missing --]]
L["Centered Horizontal, then Up"] = "Centered Horizontal, then Up"
L["Centered Vertical"] = "Centralizado Verticalmente"
--[[Translation missing --]]
L["Centered Vertical, then Centered Horizontal"] = "Centered Vertical, then Centered Horizontal"
--[[Translation missing --]]
L["Centered Vertical, then Left"] = "Centered Vertical, then Left"
--[[Translation missing --]]
L["Centered Vertical, then Right"] = "Centered Vertical, then Right"
L["Changed"] = "Mudou"
L["Channel"] = "Canal"
L["Channel (Spell)"] = "Canal (Feitiço)"
--[[Translation missing --]]
L["Character GUID"] = "Character GUID"
--[[Translation missing --]]
L["Character Name"] = "Character Name"
L["Character Stats"] = "Atributos do Personagem"
--[[Translation missing --]]
L["Character Transferred Quantity"] = "Character Transferred Quantity"
L["Character Type"] = "Tipo de personagem"
L["Charge gained/lost"] = "Carga ganha/perdida"
--[[Translation missing --]]
L["Charged Combo Points"] = "Charged Combo Points"
L["Charges"] = "Cargas"
--[[Translation missing --]]
L["Charges Changed Event"] = "Charges Changed Event"
--[[Translation missing --]]
L["Charging"] = "Charging"
L["Chat Frame"] = "Quadro do bate-papo"
L["Chat Message"] = "Mensagem de bate-papo"
--[[Translation missing --]]
L["Check if a single talent match a Rank"] = "Check if a single talent match a Rank"
--[[Translation missing --]]
L["Check nameplate's target every 0.2s"] = "Check nameplate's target every 0.2s"
L["Chromaggus"] = "Chromaggus"
L["Circle"] = "Círculo"
--[[Translation missing --]]
L["Circular Texture"] = "Circular Texture"
--[[Translation missing --]]
L["Clamp"] = "Clamp"
L["Class"] = "Classe"
L["Class and Specialization"] = "Classe e Especialização"
--[[Translation missing --]]
L["Classic"] = "Classic"
L["Classification"] = "Classificação"
L["Clockwise"] = "Sentido Horário"
--[[Translation missing --]]
L["Clone per Character"] = "Clone per Character"
--[[Translation missing --]]
L["Clone per Event"] = "Clone per Event"
--[[Translation missing --]]
L["Clone per Match"] = "Clone per Match"
--[[Translation missing --]]
L["Coin Precision"] = "Coin Precision"
L["Color"] = "Cor"
--[[Translation missing --]]
L["Color Animation"] = "Color Animation"
L["Combat Log"] = "Registro de combate"
--[[Translation missing --]]
L["Communities"] = "Communities"
--[[Translation missing --]]
L["Condition Custom Test"] = "Condition Custom Test"
L["Conditions"] = "Condições"
L["Contains"] = "Contém"
--[[Translation missing --]]
L["Continuously update Movement Speed"] = "Continuously update Movement Speed"
L["Cooldown"] = "Tempo de Recarga"
--[[Translation missing --]]
L["Cooldown bars show time before an ability is ready to be use, BigWigs prefix them with '~'"] = "Cooldown bars show time before an ability is ready to be use, BigWigs prefix them with '~'"
L["Cooldown Progress (Item)"] = "Curso do tempo de recarga (Item)"
--[[Translation missing --]]
L["Cooldown Progress (Slot)"] = "Cooldown Progress (Slot)"
--[[Translation missing --]]
L["Cooldown Ready Event"] = "Cooldown Ready Event"
--[[Translation missing --]]
L["Cooldown Ready Event (Item)"] = "Cooldown Ready Event (Item)"
--[[Translation missing --]]
L["Cooldown Ready Event (Slot)"] = "Cooldown Ready Event (Slot)"
--[[Translation missing --]]
L["Cooldown Reduction changes the duration of seconds instead of showing the real time seconds."] = "Cooldown Reduction changes the duration of seconds instead of showing the real time seconds."
--[[Translation missing --]]
L["Cooldown/Charges/Count"] = "Cooldown/Charges/Count"
--[[Translation missing --]]
L["Copper"] = "Copper"
--[[Translation missing --]]
L["Could not load KUIAR_Runtime Archive, the addon is %s"] = "Could not load KUIAR_Runtime Archive, the addon is %s"
--[[Translation missing --]]
L["Count"] = "Count"
--[[Translation missing --]]
L["Counter Clockwise"] = "Counter Clockwise"
L["Create"] = "Criar"
--[[Translation missing --]]
L["Creature Family"] = "Creature Family"
--[[Translation missing --]]
L["Creature Family Name"] = "Creature Family Name"
--[[Translation missing --]]
L["Creature Type"] = "Creature Type"
--[[Translation missing --]]
L["Creature Type Name"] = "Creature Type Name"
L["Critical"] = "Crítico"
--[[Translation missing --]]
L["Critical (%)"] = "Critical (%)"
--[[Translation missing --]]
L["Critical Rating"] = "Critical Rating"
--[[Translation missing --]]
L["Crop X"] = "Crop X"
--[[Translation missing --]]
L["Crop Y"] = "Crop Y"
L["Crowd Controlled"] = "Sob efeito de C/C"
L["Crushing"] = "Esmagador"
--[[Translation missing --]]
L["C'thun"] = "C'thun"
--[[Translation missing --]]
L["Cumulated time used during profiling"] = "Cumulated time used during profiling"
--[[Translation missing --]]
L["Currency"] = "Currency"
--[[Translation missing --]]
L["Current Essence"] = "Current Essence"
--[[Translation missing --]]
L["Current Experience"] = "Current Experience"
--[[Translation missing --]]
L["Current Instance"] = "Current Instance"
--[[Translation missing --]]
L["Current Movement Speed (%)"] = "Current Movement Speed (%)"
--[[Translation missing --]]
L["Current Stage"] = "Current Stage"
--[[Translation missing --]]
L["Current Zone"] = "Current Zone"
--[[Translation missing --]]
L["Current Zone Group"] = "Current Zone Group"
L["Curse"] = "Maldição"
L["Custom"] = "Personalizado"
--[[Translation missing --]]
L["Custom Action"] = "Custom Action"
--[[Translation missing --]]
L["Custom Anchor"] = "Custom Anchor"
--[[Translation missing --]]
L["Custom Check"] = "Custom Check"
--[[Translation missing --]]
L["Custom Color"] = "Custom Color"
--[[Translation missing --]]
L["Custom Condition Code"] = "Custom Condition Code"
--[[Translation missing --]]
L["Custom Configuration"] = "Custom Configuration"
--[[Translation missing --]]
L["Custom Fade Animation"] = "Custom Fade Animation"
L["Custom Function"] = "Função personalizada"
--[[Translation missing --]]
L["Custom Grow"] = "Custom Grow"
--[[Translation missing --]]
L["Custom Sort"] = "Custom Sort"
--[[Translation missing --]]
L["Custom Text Function"] = "Custom Text Function"
--[[Translation missing --]]
L["Custom Trigger Combination"] = "Custom Trigger Combination"
--[[Translation missing --]]
L["Custom Variables"] = "Custom Variables"
L["Damage"] = "Dano"
L["Damage Shield"] = "Escudo de Dano"
L["Damage Shield Missed"] = "Escudo de dano falho"
L["Damage Split"] = "Dano dividido"
--[[Translation missing --]]
L["DBM Announce"] = "DBM Announce"
--[[Translation missing --]]
L["DBM Stage"] = "DBM Stage"
--[[Translation missing --]]
L["DBM Timer"] = "DBM Timer"
--[[Translation missing --]]
L["Dead"] = "Dead"
--[[Translation missing --]]
L["Death"] = "Death"
L["Death Knight Rune"] = "Runa de Cavaleiro da Morte"
--[[Translation missing --]]
L["Debuff"] = "Debuff"
--[[Translation missing --]]
L["Debuff Class"] = "Debuff Class"
--[[Translation missing --]]
L["Debuff Class Icon"] = "Debuff Class Icon"
--[[Translation missing --]]
L["Debuff Type"] = "Debuff Type"
--[[Translation missing --]]
L["Debug Log contains more than 1000 entries"] = "Debug Log contains more than 1000 entries"
--[[Translation missing --]]
L["Debug Logging enabled"] = "Debug Logging enabled"
--[[Translation missing --]]
L["Debug Logging enabled for '%s'"] = "Debug Logging enabled for '%s'"
--[[Translation missing --]]
L["Defense"] = "Defense"
--[[Translation missing --]]
L["Defensive Stats"] = "Defensive Stats"
--[[Translation missing --]]
L["Deflect"] = "Deflect"
--[[Translation missing --]]
L["Delve"] = "Delve"
--[[Translation missing --]]
L["Desaturate"] = "Desaturate"
--[[Translation missing --]]
L["Desaturate Background"] = "Desaturate Background"
--[[Translation missing --]]
L["Desaturate Foreground"] = "Desaturate Foreground"
--[[Translation missing --]]
L["Descending"] = "Descending"
L["Description"] = "Descrição"
--[[Translation missing --]]
L["Dest Raid Mark"] = "Dest Raid Mark"
--[[Translation missing --]]
L["Destination Affiliation"] = "Destination Affiliation"
--[[Translation missing --]]
L["Destination GUID"] = "Destination GUID"
--[[Translation missing --]]
L["Destination Info"] = "Destination Info"
--[[Translation missing --]]
L["Destination Name"] = "Destination Name"
--[[Translation missing --]]
L["Destination NPC Id"] = "Destination NPC Id"
--[[Translation missing --]]
L["Destination Object Type"] = "Destination Object Type"
--[[Translation missing --]]
L["Destination Reaction"] = "Destination Reaction"
--[[Translation missing --]]
L["Destination Unit"] = "Destination Unit"
--[[Translation missing --]]
L["Destination unit's raid mark index"] = "Destination unit's raid mark index"
--[[Translation missing --]]
L["Destination unit's raid mark texture"] = "Destination unit's raid mark texture"
--[[Translation missing --]]
L["Difficulty"] = "Difficulty"
--[[Translation missing --]]
L["Disable Spell Known Check"] = "Disable Spell Known Check"
--[[Translation missing --]]
L["Disabled"] = "Disabled"
--[[Translation missing --]]
L["Disabled feature %q"] = "Disabled feature %q"
--[[Translation missing --]]
L["Disabled Spell Known Check"] = "Disabled Spell Known Check"
--[[Translation missing --]]
L["Discovered"] = "Discovered"
--[[Translation missing --]]
L["Disease"] = "Disease"
--[[Translation missing --]]
L["Dispel"] = "Dispel"
--[[Translation missing --]]
L["Dispel Failed"] = "Dispel Failed"
--[[Translation missing --]]
L["Display"] = "Display"
L["Distance"] = "Distância"
--[[Translation missing --]]
L["Do Not Disturb"] = "Do Not Disturb"
--[[Translation missing --]]
L["Dodge"] = "Dodge"
--[[Translation missing --]]
L["Dodge (%)"] = "Dodge (%)"
--[[Translation missing --]]
L["Dodge Rating"] = "Dodge Rating"
--[[Translation missing --]]
L["Down"] = "Down"
--[[Translation missing --]]
L["Down, then Centered Horizontal"] = "Down, then Centered Horizontal"
--[[Translation missing --]]
L["Down, then Left"] = "Down, then Left"
--[[Translation missing --]]
L["Down, then Right"] = "Down, then Right"
--[[Translation missing --]]
L["Dragonflight"] = "Dragonflight"
--[[Translation missing --]]
L["Drain"] = "Drain"
--[[Translation missing --]]
L["Dropdown Menu"] = "Dropdown Menu"
--[[Translation missing --]]
L["Dumping table"] = "Dumping table"
--[[Translation missing --]]
L["Dungeon (Celestial)"] = "Dungeon (Celestial)"
--[[Translation missing --]]
L["Dungeon (Heroic)"] = "Dungeon (Heroic)"
--[[Translation missing --]]
L["Dungeon (Mythic)"] = "Dungeon (Mythic)"
--[[Translation missing --]]
L["Dungeon (Mythic+)"] = "Dungeon (Mythic+)"
--[[Translation missing --]]
L["Dungeon (Normal)"] = "Dungeon (Normal)"
--[[Translation missing --]]
L["Dungeon (Timewalking)"] = "Dungeon (Timewalking)"
--[[Translation missing --]]
L["Dungeons"] = "Dungeons"
--[[Translation missing --]]
L["Durability Damage"] = "Durability Damage"
--[[Translation missing --]]
L["Durability Damage All"] = "Durability Damage All"
--[[Translation missing --]]
L["Duration"] = "Duration"
--[[Translation missing --]]
L["Duration Function"] = "Duration Function"
--[[Translation missing --]]
L["Duration Function (fallback state)"] = "Duration Function (fallback state)"
--[[Translation missing --]]
L["Ease In"] = "Ease In"
--[[Translation missing --]]
L["Ease In and Out"] = "Ease In and Out"
--[[Translation missing --]]
L["Ease Out"] = "Ease Out"
--[[Translation missing --]]
L["Ebonroc"] = "Ebonroc"
--[[Translation missing --]]
L["Eclipse Direction"] = "Eclipse Direction"
--[[Translation missing --]]
L["Edge"] = "Edge"
--[[Translation missing --]]
L["Edge of Madness"] = "Edge of Madness"
--[[Translation missing --]]
L["Effective Spell Id"] = "Effective Spell Id"
--[[Translation missing --]]
L["Elide"] = "Elide"
--[[Translation missing --]]
L["Elite"] = "Elite"
--[[Translation missing --]]
L["Emote"] = "Emote"
--[[Translation missing --]]
L["Empower Cast End"] = "Empower Cast End"
--[[Translation missing --]]
L["Empower Cast Interrupt"] = "Empower Cast Interrupt"
--[[Translation missing --]]
L["Empower Cast Start"] = "Empower Cast Start"
--[[Translation missing --]]
L["Empowered"] = "Empowered"
--[[Translation missing --]]
L["Empowered 1"] = "Empowered 1"
--[[Translation missing --]]
L["Empowered 2"] = "Empowered 2"
--[[Translation missing --]]
L["Empowered 3"] = "Empowered 3"
--[[Translation missing --]]
L["Empowered 4"] = "Empowered 4"
--[[Translation missing --]]
L["Empowered 5"] = "Empowered 5"
--[[Translation missing --]]
L["Empowered Cast"] = "Empowered Cast"
--[[Translation missing --]]
L["Empowered Cast Fully Charged"] = "Empowered Cast Fully Charged"
--[[Translation missing --]]
L["Empowered Fully Charged"] = "Empowered Fully Charged"
--[[Translation missing --]]
L["Empty"] = "Empty"
--[[Translation missing --]]
L["Enabled feature %q"] = "Enabled feature %q"
--[[Translation missing --]]
L["Enables (incorrect) round down of seconds, which was the previous default behavior."] = "Enables (incorrect) round down of seconds, which was the previous default behavior."
--[[Translation missing --]]
L["Enchant Applied"] = "Enchant Applied"
--[[Translation missing --]]
L["Enchant Found"] = "Enchant Found"
--[[Translation missing --]]
L["Enchant ID"] = "Enchant ID"
--[[Translation missing --]]
L["Enchant Missing"] = "Enchant Missing"
--[[Translation missing --]]
L["Enchant Name or ID"] = "Enchant Name or ID"
--[[Translation missing --]]
L["Enchant Removed"] = "Enchant Removed"
--[[Translation missing --]]
L["Enchanted"] = "Enchanted"
--[[Translation missing --]]
L["Encounter ID(s)"] = "Encounter ID(s)"
--[[Translation missing --]]
L["Energize"] = "Energize"
--[[Translation missing --]]
L["Enrage"] = "Enrage"
--[[Translation missing --]]
L["Enter a name or a spellId"] = "Enter a name or a spellId"
--[[Translation missing --]]
L["Entering"] = "Entering"
--[[Translation missing --]]
L["Entering/Leaving Combat"] = "Entering/Leaving Combat"
--[[Translation missing --]]
L["Entering/Leaving Encounter"] = "Entering/Leaving Encounter"
--[[Translation missing --]]
L["Entry Order"] = "Entry Order"
--[[Translation missing --]]
L["Environment Type"] = "Environment Type"
--[[Translation missing --]]
L["Environmental"] = "Environmental"
--[[Translation missing --]]
L["Equipment"] = "Equipment"
--[[Translation missing --]]
L["Equipment Set"] = "Equipment Set"
--[[Translation missing --]]
L["Equipment Set Equipped"] = "Equipment Set Equipped"
--[[Translation missing --]]
L["Equipment Slot"] = "Equipment Slot"
--[[Translation missing --]]
L["Equipped"] = "Equipped"
--[[Translation missing --]]
L["Error"] = "Error"
--[[Translation missing --]]
L[ [=[Error '%s' created a secure clone. We advise deleting the aura. For more information:
https://github.com/m33shoq/M33kAuras/wiki/Protected-Frames]=] ] = [=[Error '%s' created a secure clone. We advise deleting the aura. For more information:
https://github.com/m33shoq/M33kAuras/wiki/Protected-Frames]=]
--[[Translation missing --]]
L["Error decoding."] = "Error decoding."
--[[Translation missing --]]
L["Error decompressing"] = "Error decompressing"
--[[Translation missing --]]
L["Error decompressing. This doesn't look like a KUIAR_Runtime import."] = "Error decompressing. This doesn't look like a KUIAR_Runtime import."
--[[Translation missing --]]
L["Error deserializing"] = "Error deserializing"
--[[Translation missing --]]
L["Error Frame"] = "Error Frame"
--[[Translation missing --]]
L["ERROR in '%s' unknown or incompatible sub element type '%s'"] = "ERROR in '%s' unknown or incompatible sub element type '%s'"
--[[Translation missing --]]
L["Error in Aura '%s'"] = "Error in Aura '%s'"
--[[Translation missing --]]
L["Error not receiving display information from %s"] = "Error not receiving display information from %s"
--[[Translation missing --]]
L["Essence"] = "Essence"
--[[Translation missing --]]
L["Essence #1"] = "Essence #1"
--[[Translation missing --]]
L["Essence #2"] = "Essence #2"
--[[Translation missing --]]
L["Essence #3"] = "Essence #3"
--[[Translation missing --]]
L["Essence #4"] = "Essence #4"
--[[Translation missing --]]
L["Essence #5"] = "Essence #5"
--[[Translation missing --]]
L["Essence #6"] = "Essence #6"
--[[Translation missing --]]
L["Evade"] = "Evade"
L["Event"] = "Evento"
L["Event(s)"] = "Evento(s)"
L["Every Frame"] = "Todo Frame"
--[[Translation missing --]]
L["Every Frame (High CPU usage)"] = "Every Frame (High CPU usage)"
--[[Translation missing --]]
L["Evoker Essence"] = "Evoker Essence"
--[[Translation missing --]]
L["Exact Spell ID(s)"] = "Exact Spell ID(s)"
--[[Translation missing --]]
L["Execute Conditions"] = "Execute Conditions"
--[[Translation missing --]]
L["Experience (%)"] = "Experience (%)"
--[[Translation missing --]]
L["Expertise Bonus"] = "Expertise Bonus"
--[[Translation missing --]]
L["Expertise Rating"] = "Expertise Rating"
--[[Translation missing --]]
L["Extend Outside"] = "Extend Outside"
L["Extra Amount"] = "Quantidade Extra"
L["Extra Attacks"] = "Ataques Extras"
--[[Translation missing --]]
L["Extra Spell Id"] = "Extra Spell Id"
L["Extra Spell Name"] = "Nome da Magia Extra"
--[[Translation missing --]]
L["Faction"] = "Faction"
--[[Translation missing --]]
L["Faction Name"] = "Faction Name"
--[[Translation missing --]]
L["Faction Reputation"] = "Faction Reputation"
--[[Translation missing --]]
L["Fade Animation"] = "Fade Animation"
--[[Translation missing --]]
L["Fade In"] = "Fade In"
--[[Translation missing --]]
L["Fade Out"] = "Fade Out"
--[[Translation missing --]]
L["Fail Alert"] = "Fail Alert"
--[[Translation missing --]]
L["False"] = "False"
--[[Translation missing --]]
L["Fankriss the Unyielding"] = "Fankriss the Unyielding"
--[[Translation missing --]]
L["Feature %q is already disabled"] = "Feature %q is already disabled"
--[[Translation missing --]]
L["Feature %q is already enabled"] = "Feature %q is already enabled"
--[[Translation missing --]]
L["Fetch Absorb"] = "Fetch Absorb"
--[[Translation missing --]]
L["Fetch Heal Absorb"] = "Fetch Heal Absorb"
--[[Translation missing --]]
L["Fetch Legendary Power"] = "Fetch Legendary Power"
--[[Translation missing --]]
L["Fetches the name and icon of the Legendary Power that matches this bonus id."] = "Fetches the name and icon of the Legendary Power that matches this bonus id."
--[[Translation missing --]]
L["Fill Area"] = "Fill Area"
--[[Translation missing --]]
L["Filter messages with format <message>"] = "Filter messages with format <message>"
--[[Translation missing --]]
L["Fire Resistance"] = "Fire Resistance"
--[[Translation missing --]]
L["Firemaw"] = "Firemaw"
--[[Translation missing --]]
L["First"] = "First"
--[[Translation missing --]]
L["First Value of Tooltip Text"] = "First Value of Tooltip Text"
--[[Translation missing --]]
L["Fixed"] = "Fixed"
--[[Translation missing --]]
L["Fixed Names"] = "Fixed Names"
--[[Translation missing --]]
L["Fixed Size"] = "Fixed Size"
--[[Translation missing --]]
L["Flamegor"] = "Flamegor"
--[[Translation missing --]]
L["Flash"] = "Flash"
--[[Translation missing --]]
L["Flex Raid"] = "Flex Raid"
--[[Translation missing --]]
L["Flip"] = "Flip"
--[[Translation missing --]]
L["Floor"] = "Floor"
--[[Translation missing --]]
L["Focus"] = "Focus"
--[[Translation missing --]]
L["Follower Dungeon"] = "Follower Dungeon"
--[[Translation missing --]]
L["Font"] = "Font"
--[[Translation missing --]]
L["Font Size"] = "Font Size"
--[[Translation missing --]]
L["Forbidden function or table: %s"] = "Forbidden function or table: %s"
--[[Translation missing --]]
L["Foreground"] = "Foreground"
--[[Translation missing --]]
L["Foreground Color"] = "Foreground Color"
--[[Translation missing --]]
L["Form"] = "Form"
--[[Translation missing --]]
L["Format"] = "Format"
--[[Translation missing --]]
L["Format Gold"] = "Format Gold"
--[[Translation missing --]]
L["Formats |cFFFFCC00%unit|r"] = "Formats |cFFFFCC00%unit|r"
--[[Translation missing --]]
L["Formats Player's |cFFFFCC00%guid|r"] = "Formats Player's |cFFFFCC00%guid|r"
--[[Translation missing --]]
L["Forward"] = "Forward"
--[[Translation missing --]]
L["Forward, Reverse Loop"] = "Forward, Reverse Loop"
--[[Translation missing --]]
L["Fourth Value of Tooltip Text"] = "Fourth Value of Tooltip Text"
--[[Translation missing --]]
L["Frame Selector"] = "Frame Selector"
--[[Translation missing --]]
L["Frequency"] = "Frequency"
L["Friendly"] = "Amigável"
L["Friendly Fire"] = "Fogo Amigo"
--[[Translation missing --]]
L["Friendship Max Rank"] = "Friendship Max Rank"
--[[Translation missing --]]
L["Friendship Rank"] = "Friendship Rank"
--[[Translation missing --]]
L["Friendship Reputation"] = "Friendship Reputation"
--[[Translation missing --]]
L["Frost"] = "Frost"
--[[Translation missing --]]
L["Frost Resistance"] = "Frost Resistance"
--[[Translation missing --]]
L["Frost Rune #1"] = "Frost Rune #1"
--[[Translation missing --]]
L["Frost Rune #2"] = "Frost Rune #2"
--[[Translation missing --]]
L["Full"] = "Full"
--[[Translation missing --]]
L["Full Region"] = "Full Region"
--[[Translation missing --]]
L["Full/Empty"] = "Full/Empty"
--[[Translation missing --]]
L["Gahz'ranka"] = "Gahz'ranka"
--[[Translation missing --]]
L["Gained"] = "Gained"
--[[Translation missing --]]
L["Garr"] = "Garr"
--[[Translation missing --]]
L["Gehennas"] = "Gehennas"
--[[Translation missing --]]
L["General"] = "General"
--[[Translation missing --]]
L["General Rajaxx"] = "General Rajaxx"
--[[Translation missing --]]
L["GetNameAndIcon Function (fallback state)"] = "GetNameAndIcon Function (fallback state)"
--[[Translation missing --]]
L["Glancing"] = "Glancing"
--[[Translation missing --]]
L["Global Cooldown"] = "Global Cooldown"
--[[Translation missing --]]
L["Glow"] = "Glow"
--[[Translation missing --]]
L["Glow External Element"] = "Glow External Element"
--[[Translation missing --]]
L["Gluth"] = "Gluth"
--[[Translation missing --]]
L["Glyph"] = "Glyph"
--[[Translation missing --]]
L["Gold"] = "Gold"
--[[Translation missing --]]
L["Golemagg the Incinerator"] = "Golemagg the Incinerator"
--[[Translation missing --]]
L["Gothik the Harvester"] = "Gothik the Harvester"
--[[Translation missing --]]
L["Gradient"] = "Gradient"
--[[Translation missing --]]
L["Gradient Enabled"] = "Gradient Enabled"
--[[Translation missing --]]
L["Gradient End"] = "Gradient End"
--[[Translation missing --]]
L["Gradient Orientation"] = "Gradient Orientation"
--[[Translation missing --]]
L["Gradient Pulse"] = "Gradient Pulse"
--[[Translation missing --]]
L["Grand Widow Faerlina"] = "Grand Widow Faerlina"
--[[Translation missing --]]
L["Grid"] = "Grid"
--[[Translation missing --]]
L["Grobbulus"] = "Grobbulus"
L["Group"] = "Grupo"
--[[Translation missing --]]
L["Group Arrangement"] = "Group Arrangement"
--[[Translation missing --]]
L["Group Leader/Assist"] = "Group Leader/Assist"
--[[Translation missing --]]
L["Group Size"] = "Group Size"
--[[Translation missing --]]
L["Group Type"] = "Group Type"
--[[Translation missing --]]
L["Grow"] = "Grow"
--[[Translation missing --]]
L["GTFO Alert"] = "GTFO Alert"
--[[Translation missing --]]
L["Guardian"] = "Guardian"
--[[Translation missing --]]
L["Guild"] = "Guild"
--[[Translation missing --]]
L["Hakkar"] = "Hakkar"
--[[Translation missing --]]
L["Hardcore"] = "Hardcore"
L["Has Target"] = "Tem Alvo"
--[[Translation missing --]]
L["Has Vehicle UI"] = "Has Vehicle UI"
--[[Translation missing --]]
L["HasPet"] = "HasPet"
--[[Translation missing --]]
L["Haste (%)"] = "Haste (%)"
--[[Translation missing --]]
L["Haste Rating"] = "Haste Rating"
--[[Translation missing --]]
L["Heal"] = "Heal"
--[[Translation missing --]]
L["Heal Absorb"] = "Heal Absorb"
--[[Translation missing --]]
L["Heal Absorbed"] = "Heal Absorbed"
--[[Translation missing --]]
L["Health"] = "Health"
--[[Translation missing --]]
L["Health (%)"] = "Health (%)"
--[[Translation missing --]]
L["Health Deficit"] = "Health Deficit"
--[[Translation missing --]]
L["Heigan the Unclean"] = "Heigan the Unclean"
--[[Translation missing --]]
L["Height"] = "Height"
--[[Translation missing --]]
L["Hero Talent"] = "Hero Talent"
--[[Translation missing --]]
L["Heroic Party"] = "Heroic Party"
--[[Translation missing --]]
L["Hide"] = "Hide"
--[[Translation missing --]]
L["Hide 0 cooldowns"] = "Hide 0 cooldowns"
--[[Translation missing --]]
L["Hide Timer Text"] = "Hide Timer Text"
--[[Translation missing --]]
L["High Damage"] = "High Damage"
--[[Translation missing --]]
L["High Priest Thekal"] = "High Priest Thekal"
--[[Translation missing --]]
L["High Priest Venoxis"] = "High Priest Venoxis"
--[[Translation missing --]]
L["High Priestess Arlokk"] = "High Priestess Arlokk"
--[[Translation missing --]]
L["High Priestess Jeklik"] = "High Priestess Jeklik"
--[[Translation missing --]]
L["High Priestess Mar'li"] = "High Priestess Mar'li"
--[[Translation missing --]]
L["Higher Than Tank"] = "Higher Than Tank"
--[[Translation missing --]]
L["Highest Spell Id"] = "Highest Spell Id"
--[[Translation missing --]]
L["Hit (%)"] = "Hit (%)"
--[[Translation missing --]]
L["Hit Rating"] = "Hit Rating"
--[[Translation missing --]]
L["Holy Resistance"] = "Holy Resistance"
L["Horde"] = "Horda"
--[[Translation missing --]]
L["Horizontal"] = "Horizontal"
--[[Translation missing --]]
L["Hostile"] = "Hostile"
--[[Translation missing --]]
L["Hostility"] = "Hostility"
L["Humanoid"] = "Humanoide"
--[[Translation missing --]]
L["Hybrid"] = "Hybrid"
L["Icon"] = "Ícone"
--[[Translation missing --]]
L["Icon Function"] = "Icon Function"
--[[Translation missing --]]
L["Icon Function (fallback state)"] = "Icon Function (fallback state)"
--[[Translation missing --]]
L["Id"] = "Id"
--[[Translation missing --]]
L["ID"] = "ID"
--[[Translation missing --]]
--[[Translation missing --]]
L["Ignore Dead"] = "Ignore Dead"
--[[Translation missing --]]
L["Ignore Disconnected"] = "Ignore Disconnected"
--[[Translation missing --]]
L["Ignore out of checking range"] = "Ignore out of checking range"
--[[Translation missing --]]
L["Ignore Rune CD"] = "Ignore Rune CD"
--[[Translation missing --]]
L["Ignore Rune CDs"] = "Ignore Rune CDs"
--[[Translation missing --]]
L["Ignore Self"] = "Ignore Self"
--[[Translation missing --]]
L["Ignore Spell Cooldown/Charges"] = "Ignore Spell Cooldown/Charges"
--[[Translation missing --]]
L["Ignore Spell Override"] = "Ignore Spell Override"
L["Immune"] = "Imune"
L["Important"] = "Importante"
--[[Translation missing --]]
L["Importing will start after combat ends."] = "Importing will start after combat ends."
L["In Combat"] = "Em Combate"
L["In Encounter"] = "Em Encontro"
L["In Group"] = "Em Grupo"
--[[Translation missing --]]
L["In Party"] = "In Party"
--[[Translation missing --]]
L["In Pet Battle"] = "In Pet Battle"
L["In Raid"] = "Em Raide"
--[[Translation missing --]]
L["In Range"] = "In Range"
L["In Vehicle"] = "Em Veículo"
--[[Translation missing --]]
L["In War Mode"] = "In War Mode"
--[[Translation missing --]]
L["Include Bank"] = "Include Bank"
--[[Translation missing --]]
L["Include Charges"] = "Include Charges"
--[[Translation missing --]]
L["Include Death Runes"] = "Include Death Runes"
--[[Translation missing --]]
L["Include Pets"] = "Include Pets"
--[[Translation missing --]]
L["Include War Band Bank"] = "Include War Band Bank"
--[[Translation missing --]]
L["Incoming Heal"] = "Incoming Heal"
--[[Translation missing --]]
L["Increase Precision Below"] = "Increase Precision Below"
--[[Translation missing --]]
L["Increases by one per stage or intermission."] = "Increases by one per stage or intermission."
--[[Translation missing --]]
L["Information"] = "Information"
--[[Translation missing --]]
L["Inherited"] = "Inherited"
--[[Translation missing --]]
L["Instakill"] = "Instakill"
--[[Translation missing --]]
L["Install the addons BugSack and BugGrabber for detailed error logs."] = "Install the addons BugSack and BugGrabber for detailed error logs."
--[[Translation missing --]]
L["Instance"] = "Instance"
L["Instance Difficulty"] = "Dificuldade da Instância"
--[[Translation missing --]]
L["Instance Id"] = "Instance Id"
--[[Translation missing --]]
L["Instance ID"] = "Instance ID"
--[[Translation missing --]]
L["Instance Info"] = "Instance Info"
--[[Translation missing --]]
L["Instance Name"] = "Instance Name"
--[[Translation missing --]]
L["Instance Size Type"] = "Instance Size Type"
--[[Translation missing --]]
L["Instance Type"] = "Instance Type"
--[[Translation missing --]]
L["Instructor Razuvious"] = "Instructor Razuvious"
--[[Translation missing --]]
L["Insufficient Resources"] = "Insufficient Resources"
--[[Translation missing --]]
L["Intellect"] = "Intellect"
--[[Translation missing --]]
L["Interrupt"] = "Interrupt"
--[[Translation missing --]]
L["Interrupt School"] = "Interrupt School"
--[[Translation missing --]]
L["Interrupted School Text"] = "Interrupted School Text"
--[[Translation missing --]]
L["Interruptible"] = "Interruptible"
--[[Translation missing --]]
L["Inverse"] = "Inverse"
--[[Translation missing --]]
L["Inverse Pet Behavior"] = "Inverse Pet Behavior"
--[[Translation missing --]]
L["Is Away from Keyboard"] = "Is Away from Keyboard"
--[[Translation missing --]]
L["Is Current Specialization"] = "Is Current Specialization"
--[[Translation missing --]]
L["Is Death Rune"] = "Is Death Rune"
--[[Translation missing --]]
L["Is Exactly"] = "Is Exactly"
--[[Translation missing --]]
L["Is Moving"] = "Is Moving"
--[[Translation missing --]]
L["Is Off Hand"] = "Is Off Hand"
--[[Translation missing --]]
L["Is Paragon Reputation"] = "Is Paragon Reputation"
--[[Translation missing --]]
L["Is Paused"] = "Is Paused"
--[[Translation missing --]]
L["is useable"] = "is useable"
--[[Translation missing --]]
L["Is Weekly Renown Capped"] = "Is Weekly Renown Capped"
--[[Translation missing --]]
L["Island Expedition (Heroic)"] = "Island Expedition (Heroic)"
--[[Translation missing --]]
L["Island Expedition (Mythic)"] = "Island Expedition (Mythic)"
--[[Translation missing --]]
L["Island Expedition (Normal)"] = "Island Expedition (Normal)"
--[[Translation missing --]]
L["Island Expeditions (PvP)"] = "Island Expeditions (PvP)"
L["Item"] = "Item"
--[[Translation missing --]]
L["Item Bonus Id"] = "Item Bonus Id"
--[[Translation missing --]]
L["Item Bonus Id Equipped"] = "Item Bonus Id Equipped"
L["Item Count"] = "Contagem de Item"
L["Item Equipped"] = "Item Equipado"
--[[Translation missing --]]
L["Item Id"] = "Item Id"
--[[Translation missing --]]
L["Item in Range"] = "Item in Range"
--[[Translation missing --]]
L["Item Name"] = "Item Name"
--[[Translation missing --]]
L["Item Set Equipped"] = "Item Set Equipped"
--[[Translation missing --]]
L["Item Set Id"] = "Item Set Id"
--[[Translation missing --]]
L["Item Slot"] = "Item Slot"
--[[Translation missing --]]
L["Item Slot String"] = "Item Slot String"
--[[Translation missing --]]
L["Item Type"] = "Item Type"
L["Item Type Equipped"] = "Tipo de Item Equipado"
--[[Translation missing --]]
L["ItemId"] = "ItemId"
--[[Translation missing --]]
L["Jin'do the Hexxer"] = "Jin'do the Hexxer"
--[[Translation missing --]]
L["Journal Stage"] = "Journal Stage"
--[[Translation missing --]]
L["Kazzak"] = "Kazzak"
--[[Translation missing --]]
L["Keep Inside"] = "Keep Inside"
--[[Translation missing --]]
L["Kel'Thuzad"] = "Kel'Thuzad"
--[[Translation missing --]]
L["Kurinnaxx"] = "Kurinnaxx"
--[[Translation missing --]]
L["Large"] = "Large"
--[[Translation missing --]]
L["Latency"] = "Latency"
--[[Translation missing --]]
L["Leader"] = "Leader"
--[[Translation missing --]]
L["Least remaining time"] = "Least remaining time"
--[[Translation missing --]]
L["Leaving"] = "Leaving"
L["Leech"] = "Sugar"
--[[Translation missing --]]
L["Leech (%)"] = "Leech (%)"
--[[Translation missing --]]
L["Leech Rating"] = "Leech Rating"
L["Left"] = "Esquerda"
L["Left to Right"] = "Da esquerda para direita"
--[[Translation missing --]]
L["Left, then Centered Vertical"] = "Left, then Centered Vertical"
--[[Translation missing --]]
L["Left, then Down"] = "Left, then Down"
--[[Translation missing --]]
L["Left, then Up"] = "Left, then Up"
--[[Translation missing --]]
L["Legacy Looking for Raid"] = "Legacy Looking for Raid"
--[[Translation missing --]]
L["Legacy RGB Gradient"] = "Legacy RGB Gradient"
--[[Translation missing --]]
L["Legacy RGB Gradient Pulse"] = "Legacy RGB Gradient Pulse"
--[[Translation missing --]]
L["Legion"] = "Legion"
--[[Translation missing --]]
L["Length"] = "Length"
--[[Translation missing --]]
L["Level"] = "Level"
--[[Translation missing --]]
L["LibSharedMedia"] = "LibSharedMedia"
--[[Translation missing --]]
L["Lillian Voss"] = "Lillian Voss"
--[[Translation missing --]]
L["Limited"] = "Limited"
--[[Translation missing --]]
L["Linear Texture"] = "Linear Texture"
--[[Translation missing --]]
L["Lines & Particles"] = "Lines & Particles"
--[[Translation missing --]]
L["Load Conditions"] = "Load Conditions"
--[[Translation missing --]]
L["Loatheb"] = "Loatheb"
--[[Translation missing --]]
L["Location"] = "Location"
--[[Translation missing --]]
L["Looking for Raid"] = "Looking for Raid"
--[[Translation missing --]]
L["Loop"] = "Loop"
--[[Translation missing --]]
L["Loot"] = "Loot"
--[[Translation missing --]]
L["Loot Specialization"] = "Loot Specialization"
--[[Translation missing --]]
L["Loot Specialization Id"] = "Loot Specialization Id"
--[[Translation missing --]]
L["Loot Specialization Name"] = "Loot Specialization Name"
--[[Translation missing --]]
L["Lord Kazzak"] = "Lord Kazzak"
--[[Translation missing --]]
L["Lorewalking"] = "Lorewalking"
--[[Translation missing --]]
L["Lost"] = "Lost"
--[[Translation missing --]]
L["Low Damage"] = "Low Damage"
L["Lower Than Tank"] = "Menor que o tanque"
--[[Translation missing --]]
L["Lowest Spell Id"] = "Lowest Spell Id"
--[[Translation missing --]]
L["Lua error"] = "Lua error"
--[[Translation missing --]]
L["Lua error in Aura '%s': %s"] = "Lua error in Aura '%s': %s"
--[[Translation missing --]]
L["Lucifron"] = "Lucifron"
--[[Translation missing --]]
L["Maexxna"] = "Maexxna"
L["Magic"] = "Mágico"
--[[Translation missing --]]
L["Magmadar"] = "Magmadar"
--[[Translation missing --]]
L["Main Character"] = "Main Character"
--[[Translation missing --]]
L["Main Stat"] = "Main Stat"
--[[Translation missing --]]
L["Majordomo Executus"] = "Majordomo Executus"
--[[Translation missing --]]
L["Malformed KUIAR_Runtime link"] = "Malformed KUIAR_Runtime link"
--[[Translation missing --]]
L["Manual"] = "Manual"
--[[Translation missing --]]
L["Manual Icon"] = "Manual Icon"
--[[Translation missing --]]
L["Manual Rotation"] = "Manual Rotation"
--[[Translation missing --]]
L["Marked First"] = "Marked First"
--[[Translation missing --]]
L["Marked Last"] = "Marked Last"
--[[Translation missing --]]
L["Mason"] = "Mason"
L["Master"] = "Mestre"
--[[Translation missing --]]
L["Mastery (%)"] = "Mastery (%)"
--[[Translation missing --]]
L["Mastery Rating"] = "Mastery Rating"
--[[Translation missing --]]
L["Match Count"] = "Match Count"
--[[Translation missing --]]
L["Match Count per Unit"] = "Match Count per Unit"
--[[Translation missing --]]
L["Matches (Pattern)"] = "Matches (Pattern)"
--[[Translation missing --]]
L[ [=[Matches stage number of encounter journal.
Intermissions are .5
E.g. 1;2;1;2;2.5;3]=] ] = [=[Matches stage number of encounter journal.
Intermissions are .5
E.g. 1;2;1;2;2.5;3]=]
--[[Translation missing --]]
L["Max Char "] = "Max Char "
--[[Translation missing --]]
L["Max Char"] = "Max Char"
--[[Translation missing --]]
L["Max Charges"] = "Max Charges"
--[[Translation missing --]]
L["Max Health"] = "Max Health"
--[[Translation missing --]]
L["Max Power"] = "Max Power"
--[[Translation missing --]]
L["Max Quantity"] = "Max Quantity"
--[[Translation missing --]]
L["Maximum Estimate"] = "Maximum Estimate"
--[[Translation missing --]]
L["Maximum Progress"] = "Maximum Progress"
--[[Translation missing --]]
L["Maximum time used on a single frame"] = "Maximum time used on a single frame"
--[[Translation missing --]]
L["Media"] = "Media"
--[[Translation missing --]]
L["Medium"] = "Medium"
--[[Translation missing --]]
L["Melee"] = "Melee"
--[[Translation missing --]]
L["Melee Haste (%)"] = "Melee Haste (%)"
L["Message"] = "Mensagem"
L["Message Type"] = "Tipo de mensagem"
L["Message type:"] = "Tipo de mensagem:"
--[[Translation missing --]]
L["Meta Data"] = "Meta Data"
--[[Translation missing --]]
L["Mine"] = "Mine"
--[[Translation missing --]]
L["Minimum Estimate"] = "Minimum Estimate"
--[[Translation missing --]]
L["Minimum Progress"] = "Minimum Progress"
--[[Translation missing --]]
L["Minus (Small Nameplate)"] = "Minus (Small Nameplate)"
--[[Translation missing --]]
L["Mirror"] = "Mirror"
--[[Translation missing --]]
L["Miscellaneous"] = "Miscellaneous"
L["Miss"] = "Falha"
L["Miss Type"] = "Tipo de falha"
L["Missed"] = "Falho"
L["Missing"] = "Faltando"
--[[Translation missing --]]
L["Mists of Pandaria"] = "Mists of Pandaria"
--[[Translation missing --]]
L["Moam"] = "Moam"
--[[Translation missing --]]
L["Model"] = "Model"
--[[Translation missing --]]
L["Modern Blizzard (1h 3m | 3m 7s | 10s | 2.4)"] = "Modern Blizzard (1h 3m | 3m 7s | 10s | 2.4)"
--[[Translation missing --]]
L["Modernize"] = "Modernize"
--[[Translation missing --]]
L["Molten Core"] = "Molten Core"
--[[Translation missing --]]
L["Money"] = "Money"
--[[Translation missing --]]
L["Monochrome"] = "Monochrome"
--[[Translation missing --]]
L["Monochrome Outline"] = "Monochrome Outline"
--[[Translation missing --]]
L["Monochrome Thick Outline"] = "Monochrome Thick Outline"
--[[Translation missing --]]
L["Monster Emote"] = "Monster Emote"
--[[Translation missing --]]
L["Monster Party"] = "Monster Party"
--[[Translation missing --]]
L["Monster Say"] = "Monster Say"
--[[Translation missing --]]
L["Monster Whisper"] = "Monster Whisper"
L["Monster Yell"] = "Grito do monstro"
--[[Translation missing --]]
L["Moon"] = "Moon"
--[[Translation missing --]]
L["Most remaining time"] = "Most remaining time"
L["Mounted"] = "Montado"
--[[Translation missing --]]
L["Mouse Cursor"] = "Mouse Cursor"
--[[Translation missing --]]
L["Movement Speed Rating"] = "Movement Speed Rating"
L["Multi-target"] = "Multi-alvo"
--[[Translation missing --]]
L["Mythic Keystone"] = "Mythic Keystone"
--[[Translation missing --]]
L["Mythic+ Affix"] = "Mythic+ Affix"
L["Name"] = "Nome"
--[[Translation missing --]]
L["Name Function"] = "Name Function"
--[[Translation missing --]]
L["Name Function (fallback state)"] = "Name Function (fallback state)"
--[[Translation missing --]]
L["Name of Caster's Target"] = "Name of Caster's Target"
--[[Translation missing --]]
L["Name of the (sub-)zone currently shown above the minimap."] = "Name of the (sub-)zone currently shown above the minimap."
--[[Translation missing --]]
L["Name(s)"] = "Name(s)"
--[[Translation missing --]]
L["Name/Realm of Caster's Target"] = "Name/Realm of Caster's Target"
--[[Translation missing --]]
L["Nameplate"] = "Nameplate"
--[[Translation missing --]]
L["Nameplates"] = "Nameplates"
--[[Translation missing --]]
L["Names of affected Players"] = "Names of affected Players"
--[[Translation missing --]]
L["Names of unaffected Players"] = "Names of unaffected Players"
--[[Translation missing --]]
L["Nature Resistance"] = "Nature Resistance"
--[[Translation missing --]]
L["Naxxramas"] = "Naxxramas"
--[[Translation missing --]]
L["Nefarian"] = "Nefarian"
L["Neutral"] = "Neutro"
L["Never"] = "Nunca"
--[[Translation missing --]]
L["Next Combat"] = "Next Combat"
--[[Translation missing --]]
L["Next Encounter"] = "Next Encounter"
--[[Translation missing --]]
L[ [=[No active boss mod addon detected.

Note: This trigger will use BigWigs or DBM, in that order if both are installed.]=] ] = [=[No active boss mod addon detected.

Note: This trigger will use BigWigs or DBM, in that order if both are installed.]=]
--[[Translation missing --]]
L["No Extend"] = "No Extend"
L["No Instance"] = "Fora da instância"
--[[Translation missing --]]
L["No Profiling information saved."] = "No Profiling information saved."
--[[Translation missing --]]
L["No Progress Information available."] = "No Progress Information available."
L["None"] = "Nenhum"
--[[Translation missing --]]
L["Non-player Character"] = "Non-player Character"
L["Normal"] = "Normal"
--[[Translation missing --]]
L["Normal Party"] = "Normal Party"
--[[Translation missing --]]
L["Not in Group"] = "Not in Group"
--[[Translation missing --]]
L["Not in Smart Group"] = "Not in Smart Group"
--[[Translation missing --]]
L["Not on Cooldown"] = "Not on Cooldown"
--[[Translation missing --]]
L["Not On Threat Table"] = "Not On Threat Table"
--[[Translation missing --]]
L["Note: Due to how complicated the swing timer behavior is and the lack of APIs from Blizzard, results are inaccurate in edge cases."] = "Note: Due to how complicated the swing timer behavior is and the lack of APIs from Blizzard, results are inaccurate in edge cases."
--[[Translation missing --]]
L["Note: 'Hide Alone' is not available in the new aura tracking system. A load option can be used instead."] = "Note: 'Hide Alone' is not available in the new aura tracking system. A load option can be used instead."
--[[Translation missing --]]
L["Note: The available text replacements for multi triggers match the normal triggers now."] = "Note: The available text replacements for multi triggers match the normal triggers now."
--[[Translation missing --]]
L["Note: This trigger internally stores the shapeshift position, and thus is incompatible with learning stances on the fly, like e.g. the Gladiator Rune."] = "Note: This trigger internally stores the shapeshift position, and thus is incompatible with learning stances on the fly, like e.g. the Gladiator Rune."
--[[Translation missing --]]
L["Note: This trigger relies on the WoW API, which returns incorrect information in some cases."] = "Note: This trigger relies on the WoW API, which returns incorrect information in some cases."
L["Uses UnitIsVisible() to check if game client has loaded a object for this unit. This distance is around 100 yards. This is polled every second."] = "Uses UnitIsVisible() to check if game client has loaded a object for this unit. This distance is around 100 yards. This is polled every second."
--[[Translation missing --]]
L["Note: This trigger type estimates the range to the hitbox of a unit. The actual range of friendly players is usually 3 yards more than the estimate. Range checking capabilities depend on your current class and known abilities as well as the type of unit being checked. Some of the ranges may also not work with certain NPCs.|n|n|cFFAAFFAAFriendly Units:|r %s|n|cFFFFAAAAHarmful Units:|r %s|n|cFFAAAAFFMiscellanous Units:|r %s"] = "Note: This trigger type estimates the range to the hitbox of a unit. The actual range of friendly players is usually 3 yards more than the estimate. Range checking capabilities depend on your current class and known abilities as well as the type of unit being checked. Some of the ranges may also not work with certain NPCs.|n|n|cFFAAFFAAFriendly Units:|r %s|n|cFFFFAAAAHarmful Units:|r %s|n|cFFAAAAFFMiscellanous Units:|r %s"
--[[Translation missing --]]
L["Noth the Plaguebringer"] = "Noth the Plaguebringer"
--[[Translation missing --]]
L["NPC"] = "NPC"
--[[Translation missing --]]
L["Npc ID"] = "Npc ID"
L["Number"] = "Número"
L["Number Affected"] = "Número Afetado"
L["Object"] = "Objeto"
--[[Translation missing --]]
L[ [=[Occurrence of the event
Can be a range of values
Can have multiple values separated by a comma or a space

Examples:
2nd 5th and 6th events: 2, 5, 6
2nd to 6th: 2-6
every 2 events: /2
every 3 events starting from 2nd: 2/3
every 3 events starting from 2nd and ending at 11th: 2-11/3

Works only if Boss Mod addon show counter]=] ] = [=[Occurrence of the event
Can be a range of values
Can have multiple values separated by a comma or a space

Examples:
2nd 5th and 6th events: 2, 5, 6
2nd to 6th: 2-6
every 2 events: /2
every 3 events starting from 2nd: 2/3
every 3 events starting from 2nd and ending at 11th: 2-11/3

Works only if Boss Mod addon show counter]=]
--[[Translation missing --]]
L[ [=[Occurrence of the event, reset when aura is unloaded
Can be a range of values
Can have multiple values separated by a comma or a space

Examples:
2nd 5th and 6th events: 2, 5, 6
2nd to 6th: 2-6
every 2 events: /2
every 3 events starting from 2nd: 2/3
every 3 events starting from 2nd and ending at 11th: 2-11/3

Only if BigWigs shows it on it's bar]=] ] = [=[Occurrence of the event, reset when aura is unloaded
Can be a range of values
Can have multiple values separated by a comma or a space

Examples:
2nd 5th and 6th events: 2, 5, 6
2nd to 6th: 2-6
every 2 events: /2
every 3 events starting from 2nd: 2/3
every 3 events starting from 2nd and ending at 11th: 2-11/3

Only if BigWigs shows it on it's bar]=]
--[[Translation missing --]]
L[ [=[Occurrence of the event, reset when aura is unloaded
Can be a range of values
Can have multiple values separated by a comma or a space

Examples:
2nd 5th and 6th events: 2, 5, 6
2nd to 6th: 2-6
every 2 events: /2
every 3 events starting from 2nd: 2/3
every 3 events starting from 2nd and ending at 11th: 2-11/3

Only if DBM shows it on it's bar]=] ] = [=[Occurrence of the event, reset when aura is unloaded
Can be a range of values
Can have multiple values separated by a comma or a space

Examples:
2nd 5th and 6th events: 2, 5, 6
2nd to 6th: 2-6
every 2 events: /2
every 3 events starting from 2nd: 2/3
every 3 events starting from 2nd and ending at 11th: 2-11/3

Only if DBM shows it on it's bar]=]
L["Officer"] = "Oficial"
--[[Translation missing --]]
L["Offset from progress"] = "Offset from progress"
--[[Translation missing --]]
L["Offset Timer"] = "Offset Timer"
--[[Translation missing --]]
L["Old Blizzard (2h | 3m | 10s | 2.4)"] = "Old Blizzard (2h | 3m | 10s | 2.4)"
--[[Translation missing --]]
L["On Cooldown"] = "On Cooldown"
--[[Translation missing --]]
L["On Taxi"] = "On Taxi"
--[[Translation missing --]]
L["Only if on a different realm"] = "Only if on a different realm"
--[[Translation missing --]]
L["Only if Primary"] = "Only if Primary"
--[[Translation missing --]]
L["Onyxia"] = "Onyxia"
--[[Translation missing --]]
L["Opaque"] = "Opaque"
--[[Translation missing --]]
L["Option Group"] = "Option Group"
--[[Translation missing --]]
L["Options could not be loaded, the addon is %s"] = "Options could not be loaded, the addon is %s"
--[[Translation missing --]]
L["Options will finish loading after combat ends."] = "Options will finish loading after combat ends."
--[[Translation missing --]]
L["Options will open after the login process has completed."] = "Options will open after the login process has completed."
--[[Translation missing --]]
L["Or Talent"] = "Or Talent"
L["Orbit"] = "Órbita"
--[[Translation missing --]]
L["Orientation"] = "Orientation"
--[[Translation missing --]]
L["Ossirian the Unscarred"] = "Ossirian the Unscarred"
--[[Translation missing --]]
L["Other"] = "Other"
--[[Translation missing --]]
L["Other Addons"] = "Other Addons"
--[[Translation missing --]]
L["Other Events"] = "Other Events"
--[[Translation missing --]]
L["Ouro"] = "Ouro"
--[[Translation missing --]]
L["Outline"] = "Outline"
--[[Translation missing --]]
L["Over Energize"] = "Over Energize"
L["Overhealing"] = "Sobrecura"
L["Overkill"] = "Sobreassassinato"
--[[Translation missing --]]
L["Overlay %s"] = "Overlay %s"
--[[Translation missing --]]
L["Overlay Charged Combo Points"] = "Overlay Charged Combo Points"
--[[Translation missing --]]
L["Overlay Cost of Casts"] = "Overlay Cost of Casts"
--[[Translation missing --]]
L["Overlay Latency"] = "Overlay Latency"
--[[Translation missing --]]
L["Pad"] = "Pad"
--[[Translation missing --]]
L["Pad Mode"] = "Pad Mode"
--[[Translation missing --]]
L["Pad to"] = "Pad to"
--[[Translation missing --]]
L["Paragon Reputation"] = "Paragon Reputation"
--[[Translation missing --]]
L["Paragon Reward Pending"] = "Paragon Reward Pending"
--[[Translation missing --]]
L["Parent Frame"] = "Parent Frame"
--[[Translation missing --]]
L["Parent Zone"] = "Parent Zone"
L["Parry"] = "Aparar"
--[[Translation missing --]]
L["Parry (%)"] = "Parry (%)"
--[[Translation missing --]]
L["Parry Rating"] = "Parry Rating"
L["Party"] = "Grupo"
L["Party Kill"] = "Assassinato do grupo"
--[[Translation missing --]]
L["Patchwerk"] = "Patchwerk"
--[[Translation missing --]]
L["Path of Ascension: Courage"] = "Path of Ascension: Courage"
--[[Translation missing --]]
L["Path of Ascension: Humility"] = "Path of Ascension: Humility"
--[[Translation missing --]]
L["Path of Ascension: Loyalty"] = "Path of Ascension: Loyalty"
--[[Translation missing --]]
L["Path of Ascension: Wisdom"] = "Path of Ascension: Wisdom"
L["Paused"] = "Pausado"
L["Periodic Spell"] = "Feitiço periódico"
--[[Translation missing --]]
L["Personal Resource Display"] = "Personal Resource Display"
L["Pet"] = "Assistente"
--[[Translation missing --]]
L["Pet Behavior"] = "Pet Behavior"
--[[Translation missing --]]
L["Pet Specialization"] = "Pet Specialization"
--[[Translation missing --]]
L["Pet Spell"] = "Pet Spell"
--[[Translation missing --]]
L["Pets only"] = "Pets only"
--[[Translation missing --]]
L["Phase"] = "Phase"
--[[Translation missing --]]
L["Pixel Glow"] = "Pixel Glow"
--[[Translation missing --]]
L["Placement"] = "Placement"
--[[Translation missing --]]
L["Placement %i"] = "Placement %i"
--[[Translation missing --]]
L["Placement Mode"] = "Placement Mode"
--[[Translation missing --]]
L["Play"] = "Play"
L["Player"] = "Jogador"
L["Player Character"] = "Personagem do Jogador"
L["Player Class"] = "Classe do Jogador"
--[[Translation missing --]]
L["Player Effective Level"] = "Player Effective Level"
--[[Translation missing --]]
L["Player Experience"] = "Player Experience"
--[[Translation missing --]]
L["Player Faction"] = "Player Faction"
L["Player Level"] = "Nível do Jogador"
--[[Translation missing --]]
L["Player Location ID(s)"] = "Player Location ID(s)"
--[[Translation missing --]]
L["Player Money"] = "Player Money"
L["Player Name/Realm"] = "Nome do Jogador/Reino"
--[[Translation missing --]]
L["Player Race"] = "Player Race"
L["Player(s) Affected"] = "Jogado(res) afetados"
L["Player(s) Not Affected"] = "Jogado(res) não afetados"
--[[Translation missing --]]
L["Player/Unit Info"] = "Player/Unit Info"
--[[Translation missing --]]
L["Players and Pets"] = "Players and Pets"
L["Poison"] = "Veneno"
L["Power"] = "Poder"
L["Power (%)"] = "Poder (%)"
--[[Translation missing --]]
L["Power Deficit"] = "Power Deficit"
L["Power Type"] = "Tipo de Poder"
--[[Translation missing --]]
L["Precision"] = "Precision"
L["Preset"] = "Predefinido"
--[[Translation missing --]]
L["Primary Stats"] = "Primary Stats"
--[[Translation missing --]]
L["Princess Huhuran"] = "Princess Huhuran"
--[[Translation missing --]]
L["Print Profiling Results"] = "Print Profiling Results"
--[[Translation missing --]]
L["Proc Glow"] = "Proc Glow"
--[[Translation missing --]]
L["Profiling already started."] = "Profiling already started."
--[[Translation missing --]]
L["Profiling automatically started."] = "Profiling automatically started."
--[[Translation missing --]]
L["Profiling not running."] = "Profiling not running."
--[[Translation missing --]]
L["Profiling started."] = "Profiling started."
--[[Translation missing --]]
L["Profiling started. It will end automatically in %d seconds"] = "Profiling started. It will end automatically in %d seconds"
--[[Translation missing --]]
L["Profiling still running, stop before trying to print."] = "Profiling still running, stop before trying to print."
--[[Translation missing --]]
L["Profiling stopped."] = "Profiling stopped."
--[[Translation missing --]]
L["Progress"] = "Progress"
--[[Translation missing --]]
L["Progress Source"] = "Progress Source"
--[[Translation missing --]]
L["Progress Total"] = "Progress Total"
--[[Translation missing --]]
L["Progress Value"] = "Progress Value"
--[[Translation missing --]]
L["Pull"] = "Pull"
L["Pulse"] = "Pulsar"
L["PvP Flagged"] = "Marcado para JxJ"
--[[Translation missing --]]
L["PvP Mode Active"] = "PvP Mode Active"
--[[Translation missing --]]
L["PvP Talent selected"] = "PvP Talent selected"
--[[Translation missing --]]
L["PvP Talent Selected"] = "PvP Talent Selected"
--[[Translation missing --]]
L["Quality Id"] = "Quality Id"
--[[Translation missing --]]
L["Quantity"] = "Quantity"
--[[Translation missing --]]
L["Quantity earned this week"] = "Quantity earned this week"
--[[Translation missing --]]
L["Quest Party"] = "Quest Party"
--[[Translation missing --]]
L["Queued Action"] = "Queued Action"
L["Radius"] = "Raio"
--[[Translation missing --]]
L["Ragnaros"] = "Ragnaros"
L["Raid"] = "Raide"
L["Raid (Heroic)"] = "Raide (Heroica)"
L["Raid (Mythic)"] = "Raide (Mítica)"
L["Raid (Normal)"] = "Raide (Normal)"
L["Raid (Timewalking)"] = "Raide (Caminhada Temporal)"
--[[Translation missing --]]
L["Raid Mark"] = "Raid Mark"
--[[Translation missing --]]
L["Raid Mark Icon"] = "Raid Mark Icon"
--[[Translation missing --]]
L["Raid Role"] = "Raid Role"
L["Raid Warning"] = "Aviso de raide"
--[[Translation missing --]]
L["Raids"] = "Raids"
L["Range"] = "Alcance"
--[[Translation missing --]]
L["Range Check"] = "Range Check"
--[[Translation missing --]]
L["Ranged"] = "Ranged"
--[[Translation missing --]]
L["Rank"] = "Rank"
--[[Translation missing --]]
L["Rare"] = "Rare"
--[[Translation missing --]]
L["Rare Elite"] = "Rare Elite"
--[[Translation missing --]]
L["Rated Arena"] = "Rated Arena"
--[[Translation missing --]]
L["Rated Battleground"] = "Rated Battleground"
--[[Translation missing --]]
L["Raw Threat Percent"] = "Raw Threat Percent"
--[[Translation missing --]]
L["Razorgore the Untamed"] = "Razorgore the Untamed"
--[[Translation missing --]]
L["Ready Check"] = "Ready Check"
--[[Translation missing --]]
L["Reagent Quality"] = "Reagent Quality"
--[[Translation missing --]]
L["Reagent Quality Texture"] = "Reagent Quality Texture"
--[[Translation missing --]]
L["Realm"] = "Realm"
--[[Translation missing --]]
L["Realm Name"] = "Realm Name"
--[[Translation missing --]]
L["Realm of Caster's Target"] = "Realm of Caster's Target"
--[[Translation missing --]]
L["Reborn Council"] = "Reborn Council"
--[[Translation missing --]]
L["Receiving %s Bytes"] = "Receiving %s Bytes"
--[[Translation missing --]]
L["Receiving display information"] = "Receiving display information"
L["Reflect"] = "Refletir"
--[[Translation missing --]]
L["Region type %s not supported"] = "Region type %s not supported"
L["Relative"] = "Relativo"
--[[Translation missing --]]
L["Relative X-Offset"] = "Relative X-Offset"
--[[Translation missing --]]
L["Relative Y-Offset"] = "Relative Y-Offset"
--[[Translation missing --]]
L["Remaining Duration"] = "Remaining Duration"
L["Remaining Time"] = "Tempo restante"
--[[Translation missing --]]
L["Remove Obsolete Auras"] = "Remove Obsolete Auras"
--[[Translation missing --]]
L["Renown Level"] = "Renown Level"
--[[Translation missing --]]
L["Renown Max Level"] = "Renown Max Level"
--[[Translation missing --]]
L["Renown Reputation"] = "Renown Reputation"
L["Repair"] = "Reparar"
--[[Translation missing --]]
L["Repeat"] = "Repeat"
--[[Translation missing --]]
L["Report Summary"] = "Report Summary"
--[[Translation missing --]]
L["Reputation"] = "Reputation"
--[[Translation missing --]]
L["Reputation (%)"] = "Reputation (%)"
L["Requested display does not exist"] = "Exibição requerida não existe"
L["Requested display not authorized"] = "Exibição requerida não autorizada"
--[[Translation missing --]]
L["Requesting display information from %s ..."] = "Requesting display information from %s ..."
L["Require Valid Target"] = "Requer um alvo válido"
--[[Translation missing --]]
L["Requires syncing the specialization via LibSpecialization."] = "Requires syncing the specialization via LibSpecialization."
--[[Translation missing --]]
L["Resilience (%)"] = "Resilience (%)"
--[[Translation missing --]]
L["Resilience Rating"] = "Resilience Rating"
L["Resist"] = "Resistir"
--[[Translation missing --]]
L["Resistances"] = "Resistances"
L["Resisted"] = "Resistido"
--[[Translation missing --]]
L["Rested"] = "Rested"
--[[Translation missing --]]
L["Rested Experience"] = "Rested Experience"
--[[Translation missing --]]
L["Rested Experience (%)"] = "Rested Experience (%)"
L["Resting"] = "Descansando"
L["Resurrect"] = "Reviver"
--[[Translation missing --]]
L["Resurrect Pending"] = "Resurrect Pending"
L["Right"] = "Direita"
L["Right to Left"] = "Da direita à esquerda"
--[[Translation missing --]]
L["Right, then Centered Vertical"] = "Right, then Centered Vertical"
--[[Translation missing --]]
L["Right, then Down"] = "Right, then Down"
--[[Translation missing --]]
L["Right, then Up"] = "Right, then Up"
--[[Translation missing --]]
L["Role"] = "Role"
--[[Translation missing --]]
L["Rollback snapshot is complete. Thank you for your patience!"] = "Rollback snapshot is complete. Thank you for your patience!"
--[[Translation missing --]]
L["Rotate Animation"] = "Rotate Animation"
L["Rotate Left"] = "Girar à esquerda"
L["Rotate Right"] = "Girar à direita"
--[[Translation missing --]]
L["Rotation"] = "Rotation"
--[[Translation missing --]]
L["Round"] = "Round"
--[[Translation missing --]]
L["Round Mode"] = "Round Mode"
--[[Translation missing --]]
L["Ruins of Ahn'Qiraj"] = "Ruins of Ahn'Qiraj"
--[[Translation missing --]]
L["Run Custom Code"] = "Run Custom Code"
--[[Translation missing --]]
L["Run Speed (%)"] = "Run Speed (%)"
L["Rune"] = "Runa"
--[[Translation missing --]]
L["Rune #1"] = "Rune #1"
--[[Translation missing --]]
L["Rune #2"] = "Rune #2"
--[[Translation missing --]]
L["Rune #3"] = "Rune #3"
--[[Translation missing --]]
L["Rune #4"] = "Rune #4"
--[[Translation missing --]]
L["Rune #5"] = "Rune #5"
--[[Translation missing --]]
L["Rune #6"] = "Rune #6"
--[[Translation missing --]]
L["Rune Count"] = "Rune Count"
--[[Translation missing --]]
L["Rune Count - Blood"] = "Rune Count - Blood"
--[[Translation missing --]]
L["Rune Count - Frost"] = "Rune Count - Frost"
--[[Translation missing --]]
L["Rune Count - Unholy"] = "Rune Count - Unholy"
--[[Translation missing --]]
L["Sapphiron"] = "Sapphiron"
L["Say"] = "falar"
--[[Translation missing --]]
L["Scale"] = "Scale"
--[[Translation missing --]]
L["Scarlet Enclave"] = "Scarlet Enclave"
--[[Translation missing --]]
L["Scenario"] = "Scenario"
--[[Translation missing --]]
L["Scenario (Heroic)"] = "Scenario (Heroic)"
--[[Translation missing --]]
L["Scenario (Normal)"] = "Scenario (Normal)"
--[[Translation missing --]]
L["Screen"] = "Screen"
--[[Translation missing --]]
L["Screen/Parent Group"] = "Screen/Parent Group"
--[[Translation missing --]]
L["Season of Discovery"] = "Season of Discovery"
--[[Translation missing --]]
L["Second"] = "Second"
--[[Translation missing --]]
L["Second Value of Tooltip Text"] = "Second Value of Tooltip Text"
--[[Translation missing --]]
L["Secondary Stats"] = "Secondary Stats"
L["Seconds"] = "Segundos"
--[[Translation missing --]]
L[ [=[Secure frame detected. Find more information:
https://github.com/m33shoq/M33kAuras/wiki/Protected-Frames]=] ] = [=[Secure frame detected. Find more information:
https://github.com/m33shoq/M33kAuras/wiki/Protected-Frames]=]
--[[Translation missing --]]
L["Select Frame"] = "Select Frame"
--[[Translation missing --]]
L["Select the type of timer to filter"] = "Select the type of timer to filter"
--[[Translation missing --]]
L["Selection Mode"] = "Selection Mode"
--[[Translation missing --]]
L["Separator"] = "Separator"
--[[Translation missing --]]
L["Set IDs can be found on websites such as wowhead.com/cata/item-sets"] = "Set IDs can be found on websites such as wowhead.com/cata/item-sets"
--[[Translation missing --]]
L["Set IDs can be found on websites such as wowhead.com/classic/item-sets"] = "Set IDs can be found on websites such as wowhead.com/classic/item-sets"
--[[Translation missing --]]
L["Set IDs can be found on websites such as wowhead.com/item-sets"] = "Set IDs can be found on websites such as wowhead.com/item-sets"
--[[Translation missing --]]
L["Set IDs can be found on websites such as wowhead.com/mop-classic/item-sets"] = "Set IDs can be found on websites such as wowhead.com/mop-classic/item-sets"
--[[Translation missing --]]
L["Shadow Resistance"] = "Shadow Resistance"
--[[Translation missing --]]
L["Shadowlands"] = "Shadowlands"
L["Shake"] = "Sacudir"
--[[Translation missing --]]
L["Shazzrah"] = "Shazzrah"
--[[Translation missing --]]
L["Shift-Click to resume addon execution."] = "Shift-Click to resume addon execution."
L["Show"] = "Mostrar"
--[[Translation missing --]]
L["Show CD of Charge"] = "Show CD of Charge"
--[[Translation missing --]]
L["Show charged duration for empowered casts"] = "Show charged duration for empowered casts"
--[[Translation missing --]]
L["Show GCD"] = "Show GCD"
--[[Translation missing --]]
L["Show Global Cooldown"] = "Show Global Cooldown"
--[[Translation missing --]]
L["Show Incoming Heal"] = "Show Incoming Heal"
--[[Translation missing --]]
L["Show Loss of Control"] = "Show Loss of Control"
--[[Translation missing --]]
L["Show On"] = "Show On"
--[[Translation missing --]]
L["Show Rested Overlay"] = "Show Rested Overlay"
L["Shrink"] = "Encolher"
--[[Translation missing --]]
L["Silithid Royalty"] = "Silithid Royalty"
--[[Translation missing --]]
L["Silver"] = "Silver"
L["Simple"] = "Simples"
--[[Translation missing --]]
L["Since Active"] = "Since Active"
--[[Translation missing --]]
L["Since Apply"] = "Since Apply"
--[[Translation missing --]]
L["Since Apply/Refresh"] = "Since Apply/Refresh"
--[[Translation missing --]]
L["Since Charge Gain"] = "Since Charge Gain"
--[[Translation missing --]]
L["Since Charge Lost"] = "Since Charge Lost"
--[[Translation missing --]]
L["Since Ready"] = "Since Ready"
--[[Translation missing --]]
L["Since Stack Gain"] = "Since Stack Gain"
--[[Translation missing --]]
L["Since Stack Lost"] = "Since Stack Lost"
--[[Translation missing --]]
L["Size & Position"] = "Size & Position"
--[[Translation missing --]]
L["Skyriding"] = "Skyriding"
--[[Translation missing --]]
L["Slide Animation"] = "Slide Animation"
L["Slide from Bottom"] = "Deslizar de baixo"
L["Slide from Left"] = "Deslizar da esquerda"
L["Slide from Right"] = "Deslizar da direita"
L["Slide from Top"] = "Deslizar de cima"
L["Slide to Bottom"] = "Deslizar para baixo"
L["Slide to Left"] = "Deslizar para esquerda"
L["Slide to Right"] = "Deslizar para direita"
L["Slide to Top"] = "Deslizar para cima"
--[[Translation missing --]]
L["Slider"] = "Slider"
--[[Translation missing --]]
L["Small"] = "Small"
--[[Translation missing --]]
L["Smart Group"] = "Smart Group"
--[[Translation missing --]]
L["Soft Enemy"] = "Soft Enemy"
--[[Translation missing --]]
L["Soft Friend"] = "Soft Friend"
--[[Translation missing --]]
L["Solistrasza"] = "Solistrasza"
--[[Translation missing --]]
L["Sound"] = "Sound"
--[[Translation missing --]]
L["Sound by Kit ID"] = "Sound by Kit ID"
--[[Translation missing --]]
L["Source"] = "Source"
--[[Translation missing --]]
L["Source Affiliation"] = "Source Affiliation"
--[[Translation missing --]]
L["Source GUID"] = "Source GUID"
--[[Translation missing --]]
L["Source Info"] = "Source Info"
L["Source Name"] = "Origem do nome"
--[[Translation missing --]]
L["Source NPC Id"] = "Source NPC Id"
--[[Translation missing --]]
L["Source Object Type"] = "Source Object Type"
--[[Translation missing --]]
L["Source Raid Mark"] = "Source Raid Mark"
--[[Translation missing --]]
L["Source Reaction"] = "Source Reaction"
L["Source Unit"] = "Origem da unidade"
--[[Translation missing --]]
L["Source Unit Name/Realm"] = "Source Unit Name/Realm"
--[[Translation missing --]]
L["Source unit's raid mark index"] = "Source unit's raid mark index"
--[[Translation missing --]]
L["Source unit's raid mark texture"] = "Source unit's raid mark texture"
--[[Translation missing --]]
L["Space"] = "Space"
L["Spacing"] = "Espaçamento"
--[[Translation missing --]]
L["Spark"] = "Spark"
--[[Translation missing --]]
L["Spec Position"] = "Spec Position"
--[[Translation missing --]]
L["Spec Role"] = "Spec Role"
--[[Translation missing --]]
L["Specialization"] = "Specialization"
--[[Translation missing --]]
L["Specific Currency"] = "Specific Currency"
--[[Translation missing --]]
L["Specific Type"] = "Specific Type"
L["Specific Unit"] = "Unidade específica"
L["Spell"] = "Feitiço"
L["Spell (Building)"] = "Feitiço (Construção)"
--[[Translation missing --]]
L["Spell Activation Overlay Glow"] = "Spell Activation Overlay Glow"
--[[Translation missing --]]
L["Spell Cast Succeeded"] = "Spell Cast Succeeded"
--[[Translation missing --]]
L["Spell Cost"] = "Spell Cost"
--[[Translation missing --]]
L["Spell Count"] = "Spell Count"
--[[Translation missing --]]
L["Spell ID"] = "Spell ID"
--[[Translation missing --]]
L["Spell Id"] = "Spell Id"
--[[Translation missing --]]
L["Spell ID:"] = "Spell ID:"
--[[Translation missing --]]
L["Spell IDs:"] = "Spell IDs:"
--[[Translation missing --]]
L["Spell in Range"] = "Spell in Range"
--[[Translation missing --]]
L["Spell Known"] = "Spell Known"
L["Spell Name"] = "Nome do feitiço"
--[[Translation missing --]]
L["Spell Peneration Percent"] = "Spell Peneration Percent"
--[[Translation missing --]]
L["Spell Power"] = "Spell Power"
--[[Translation missing --]]
L["Spell School"] = "Spell School"
--[[Translation missing --]]
L["Spell Usable"] = "Spell Usable"
--[[Translation missing --]]
L["Spellname"] = "Spellname"
--[[Translation missing --]]
L["Spike"] = "Spike"
L["Spin"] = "Girar"
L["Spiral"] = "Espiral"
L["Spiral In And Out"] = "Espiral dentro e fora"
--[[Translation missing --]]
L["Spirit"] = "Spirit"
--[[Translation missing --]]
L["Stack Count"] = "Stack Count"
--[[Translation missing --]]
L["Stack trace:"] = "Stack trace:"
L["Stacks"] = "Pilhas"
--[[Translation missing --]]
L["Stacks Function"] = "Stacks Function"
--[[Translation missing --]]
L["Stacks Function (fallback state)"] = "Stacks Function (fallback state)"
--[[Translation missing --]]
L["Stage"] = "Stage"
--[[Translation missing --]]
L["Stage Counter"] = "Stage Counter"
--[[Translation missing --]]
L["Stagger"] = "Stagger"
--[[Translation missing --]]
L["Stagger (%)"] = "Stagger (%)"
--[[Translation missing --]]
L["Stagger against Target (%)"] = "Stagger against Target (%)"
--[[Translation missing --]]
L["Stagger Scale"] = "Stagger Scale"
--[[Translation missing --]]
L["Stamina"] = "Stamina"
L["Stance/Form/Aura"] = "Postura/Forma/Aura"
--[[Translation missing --]]
L["Standing"] = "Standing"
--[[Translation missing --]]
L["Star Shake"] = "Star Shake"
--[[Translation missing --]]
L["Start Animation"] = "Start Animation"
--[[Translation missing --]]
L["Start Now"] = "Start Now"
--[[Translation missing --]]
L["Start Profiling"] = "Start Profiling"
L["Status"] = "Estado"
--[[Translation missing --]]
L["Status Bar"] = "Status Bar"
L["Stolen"] = "Roubado"
--[[Translation missing --]]
L["Stop"] = "Stop"
--[[Translation missing --]]
L["Stop Motion"] = "Stop Motion"
--[[Translation missing --]]
L["Story Raid"] = "Story Raid"
--[[Translation missing --]]
L["Strength"] = "Strength"
--[[Translation missing --]]
L["String"] = "String"
--[[Translation missing --]]
L["Subevent Info"] = "Subevent Info"
--[[Translation missing --]]
L["Subtract Cast"] = "Subtract Cast"
--[[Translation missing --]]
L["Subtract Channel"] = "Subtract Channel"
--[[Translation missing --]]
L["Subtract GCD"] = "Subtract GCD"
--[[Translation missing --]]
L["Subzone Name"] = "Subzone Name"
--[[Translation missing --]]
L["Success"] = "Success"
--[[Translation missing --]]
L["Sulfuron Harbinger"] = "Sulfuron Harbinger"
L["Summon"] = "Invocar"
--[[Translation missing --]]
L["Summon Pending"] = "Summon Pending"
--[[Translation missing --]]
L["Sun"] = "Sun"
--[[Translation missing --]]
L["Supports multiple entries, separated by commas"] = "Supports multiple entries, separated by commas"
--[[Translation missing --]]
L[ [=[Supports multiple entries, separated by commas
]=] ] = [=[Supports multiple entries, separated by commas
]=]
--[[Translation missing --]]
L["Supports multiple entries, separated by commas. Escape ',' with \\. Prefix with '-' for negation."] = "Supports multiple entries, separated by commas. Escape ',' with \\. Prefix with '-' for negation."
--[[Translation missing --]]
L["Supports multiple entries, separated by commas. Escape with \\. Prefix with '-' for negation."] = "Supports multiple entries, separated by commas. Escape with \\. Prefix with '-' for negation."
--[[Translation missing --]]
L["Supports multiple entries, separated by commas. Prefix with '-' for negation."] = "Supports multiple entries, separated by commas. Prefix with '-' for negation."
--[[Translation missing --]]
L[ [=[Supports multiple entries, separated by commas. To include child zone ids, prefix with 'c', e.g. 'c2022'.
Group Zone IDs must be prefixed with 'g', e.g. 'g277'.
Supports Area IDs from https://wago.tools/db2/AreaTable prefixed with 'a'.
Supports Instance IDs prefixed with 'i'.
Entries can be prefixed with '-' to negate.]=] ] = [=[Supports multiple entries, separated by commas. To include child zone ids, prefix with 'c', e.g. 'c2022'.
Group Zone IDs must be prefixed with 'g', e.g. 'g277'.
Supports Area IDs from https://wago.tools/db2/AreaTable prefixed with 'a'.
Supports Instance IDs prefixed with 'i'.
Entries can be prefixed with '-' to negate.]=]
L["Swing"] = "Balançar"
L["Swing Timer"] = "Tempo de balanço"
--[[Translation missing --]]
L["Swipe"] = "Swipe"
--[[Translation missing --]]
L["Syntax /wa feature <toggle|on|enable|disable|off> <feature>"] = "Syntax /wa feature <toggle|on|enable|disable|off> <feature>"
--[[Translation missing --]]
L["System"] = "System"
--[[Translation missing --]]
L["Systems"] = "Systems"
--[[Translation missing --]]
L["Tab "] = "Tab "
L["Talent"] = "Talento"
--[[Translation missing --]]
L["Talent |cFFFF0000Not|r Known"] = "Talent |cFFFF0000Not|r Known"
--[[Translation missing --]]
L["Talent |cFFFF0000Not|r Selected"] = "Talent |cFFFF0000Not|r Selected"
--[[Translation missing --]]
L["Talent Known"] = "Talent Known"
--[[Translation missing --]]
L["Talent Selected"] = "Talent Selected"
--[[Translation missing --]]
L["Talent selected"] = "Talent selected"
L["Talent Specialization"] = "Especialização de talentos"
--[[Translation missing --]]
L["Tanking And Highest"] = "Tanking And Highest"
--[[Translation missing --]]
L["Tanking But Not Highest"] = "Tanking But Not Highest"
L["Target"] = "Alvo"
--[[Translation missing --]]
L["Targeted"] = "Targeted"
--[[Translation missing --]]
L["Tertiary Stats"] = "Tertiary Stats"
--[[Translation missing --]]
L["Test if bar is enabled in BigWigs settings"] = "Test if bar is enabled in BigWigs settings"
--[[Translation missing --]]
L["Test if bar is enabled in Boss Mod addon settings"] = "Test if bar is enabled in Boss Mod addon settings"
--[[Translation missing --]]
L["Test if bar is enabled in DBM settings"] = "Test if bar is enabled in DBM settings"
L["Text"] = "Texto"
--[[Translation missing --]]
L["Text To Speech"] = "Text To Speech"
--[[Translation missing --]]
L["Text-to-speech"] = "Text-to-speech"
--[[Translation missing --]]
L["Texture"] = "Texture"
--[[Translation missing --]]
L["Texture Function"] = "Texture Function"
--[[Translation missing --]]
L["Texture Function (fallback state)"] = "Texture Function (fallback state)"
--[[Translation missing --]]
L["Texture Picker"] = "Texture Picker"
--[[Translation missing --]]
L["Texture Rotation"] = "Texture Rotation"
--[[Translation missing --]]
L["Thaddius"] = "Thaddius"
--[[Translation missing --]]
L["The aura has overwritten the global '%s', this might affect other auras."] = "The aura has overwritten the global '%s', this might affect other auras."
--[[Translation missing --]]
L["The aura tried to overwrite the aura_env global, which is not allowed."] = "The aura tried to overwrite the aura_env global, which is not allowed."
--[[Translation missing --]]
L["The effective level differs from the level in e.g. Time Walking dungeons."] = "The effective level differs from the level in e.g. Time Walking dungeons."
--[[Translation missing --]]
L["The Four Horsemen"] = "The Four Horsemen"
--[[Translation missing --]]
L["The 'ID' value can be found in the BigWigs options of a specific spell"] = "The 'ID' value can be found in the BigWigs options of a specific spell"
--[[Translation missing --]]
L["The Prophet Skeram"] = "The Prophet Skeram"
--[[Translation missing --]]
L["The total quantity a warband character can transfer after paying the transfer cost"] = "The total quantity a warband character can transfer after paying the transfer cost"
--[[Translation missing --]]
L["The total quantity after transferring everything to your current character and paying the transfer cost"] = "The total quantity after transferring everything to your current character and paying the transfer cost"
--[[Translation missing --]]
L["The War Within"] = "The War Within"
--[[Translation missing --]]
L["There are %i updates to your auras ready to be installed!"] = "There are %i updates to your auras ready to be installed!"
--[[Translation missing --]]
L["Thick Outline"] = "Thick Outline"
--[[Translation missing --]]
L["Thickness"] = "Thickness"
--[[Translation missing --]]
L["Third"] = "Third"
--[[Translation missing --]]
L["Third Value of Tooltip Text"] = "Third Value of Tooltip Text"
--[[Translation missing --]]
L["This aura calls GetData a lot, which is a slow function."] = "This aura calls GetData a lot, which is a slow function."
--[[Translation missing --]]
L["This aura has caused a Lua error."] = "This aura has caused a Lua error."
--[[Translation missing --]]
L["This aura is saving %s KB of data"] = "This aura is saving %s KB of data"
--[[Translation missing --]]
L["This aura plays a sound via a condition."] = "This aura plays a sound via a condition."
--[[Translation missing --]]
L["This aura plays a sound via an action."] = "This aura plays a sound via an action."
--[[Translation missing --]]
L["This aura plays a Text To Speech via a condition."] = "This aura plays a Text To Speech via a condition."
--[[Translation missing --]]
L["This aura plays a Text To Speech via an action."] = "This aura plays a Text To Speech via an action."
--[[Translation missing --]]
--[[Translation missing --]]
L["Threat Percent"] = "Threat Percent"
L["Threat Situation"] = "Situação de ameaça"
--[[Translation missing --]]
L["Threat Value"] = "Threat Value"
--[[Translation missing --]]
L["Tick"] = "Tick"
--[[Translation missing --]]
L["Time"] = "Time"
--[[Translation missing --]]
L["Time Format"] = "Time Format"
--[[Translation missing --]]
L["Time in GCDs"] = "Time in GCDs"
--[[Translation missing --]]
L["Time since initial application"] = "Time since initial application"
--[[Translation missing --]]
L["Time since last refresh"] = "Time since last refresh"
--[[Translation missing --]]
L["Time since stack gain"] = "Time since stack gain"
--[[Translation missing --]]
L["Time since stack lost"] = "Time since stack lost"
L["Timed"] = "Temporizado"
--[[Translation missing --]]
L["Timed Progress"] = "Timed Progress"
--[[Translation missing --]]
L["Timer"] = "Timer"
--[[Translation missing --]]
L["Timer Id"] = "Timer Id"
--[[Translation missing --]]
L["Toggle"] = "Toggle"
--[[Translation missing --]]
L["Toggle List"] = "Toggle List"
--[[Translation missing --]]
L["Toggle Options Window"] = "Toggle Options Window"
--[[Translation missing --]]
L["Toggle Performance Profiling Window"] = "Toggle Performance Profiling Window"
--[[Translation missing --]]
L["Tooltip"] = "Tooltip"
--[[Translation missing --]]
L["Tooltip 1"] = "Tooltip 1"
--[[Translation missing --]]
L["Tooltip 2"] = "Tooltip 2"
--[[Translation missing --]]
L["Tooltip 3"] = "Tooltip 3"
--[[Translation missing --]]
L["Tooltip Value 1"] = "Tooltip Value 1"
--[[Translation missing --]]
L["Tooltip Value 2"] = "Tooltip Value 2"
--[[Translation missing --]]
L["Tooltip Value 3"] = "Tooltip Value 3"
--[[Translation missing --]]
L["Tooltip Value 4"] = "Tooltip Value 4"
L["Top"] = "Topo"
L["Top Left"] = "Topo à esquerda"
L["Top Right"] = "Topo à direita"
L["Top to Bottom"] = "Do topo para base"
--[[Translation missing --]]
L["Torghast"] = "Torghast"
--[[Translation missing --]]
L["Total Duration"] = "Total Duration"
--[[Translation missing --]]
L["Total Earned in this Season"] = "Total Earned in this Season"
--[[Translation missing --]]
L["Total Essence"] = "Total Essence"
--[[Translation missing --]]
L["Total Experience"] = "Total Experience"
--[[Translation missing --]]
L["Total Match Count"] = "Total Match Count"
--[[Translation missing --]]
L["Total Reputation"] = "Total Reputation"
--[[Translation missing --]]
L["Total Stacks"] = "Total Stacks"
--[[Translation missing --]]
L["Total stacks over all matches"] = "Total stacks over all matches"
--[[Translation missing --]]
L["Total Stages"] = "Total Stages"
--[[Translation missing --]]
L["Total Unit Count"] = "Total Unit Count"
--[[Translation missing --]]
L["Total Units"] = "Total Units"
L["Totem"] = "Totem"
--[[Translation missing --]]
L["Totem #%i"] = "Totem #%i"
--[[Translation missing --]]
L["Totem Icon"] = "Totem Icon"
L["Totem Name"] = "Nome do totem"
--[[Translation missing --]]
L["Totem Name Pattern Match"] = "Totem Name Pattern Match"
--[[Translation missing --]]
L["Totem Number"] = "Totem Number"
--[[Translation missing --]]
L["Track Cooldowns"] = "Track Cooldowns"
--[[Translation missing --]]
L["Tracking Charge %i"] = "Tracking Charge %i"
--[[Translation missing --]]
L["Tracking Charge CDs"] = "Tracking Charge CDs"
--[[Translation missing --]]
L["Tracking Only Cooldown"] = "Tracking Only Cooldown"
L["Transmission error"] = "Erro de transmissão"
L["Trigger"] = "Gatilho"
L["Trigger %i"] = "Gatilho %i"
--[[Translation missing --]]
L["Trigger %s"] = "Trigger %s"
L["Trigger 1"] = "Gatilho 1"
--[[Translation missing --]]
L["Trigger State Updater (Advanced)"] = "Trigger State Updater (Advanced)"
L["Trigger Update"] = "Atualização do gatilho"
L["Trigger:"] = "Gatilho:"
--[[Translation missing --]]
L["Trivial (Low Level)"] = "Trivial (Low Level)"
--[[Translation missing --]]
L["True"] = "True"
--[[Translation missing --]]
L["Trying to repair broken conditions in %s likely caused by a KUIAR_Runtime bug."] = "Trying to repair broken conditions in %s likely caused by a KUIAR_Runtime bug."
--[[Translation missing --]]
L["Twin Emperors"] = "Twin Emperors"
L["Type"] = "Tipo"
--[[Translation missing --]]
L["Unable to modernize aura '%s'. This is probably due to corrupt data or a bad migration, please report this to m33shoq."] = "Unable to modernize aura '%s'. This is probably due to corrupt data or a bad migration, please report this to m33shoq."
--[[Translation missing --]]
L["Unaffected"] = "Unaffected"
L["Undefined"] = "Indefinido"
--[[Translation missing --]]
L["Unholy"] = "Unholy"
--[[Translation missing --]]
L["Unholy Rune #1"] = "Unholy Rune #1"
--[[Translation missing --]]
L["Unholy Rune #2"] = "Unholy Rune #2"
L["Unit"] = "Unidade"
L["Unit Characteristics"] = "Características da unidade"
L["Unit Destroyed"] = "Unidade destruída"
L["Unit Died"] = "Unidade morte"
--[[Translation missing --]]
L["Unit Dissipates"] = "Unit Dissipates"
--[[Translation missing --]]
L["Unit Frame"] = "Unit Frame"
--[[Translation missing --]]
L["Unit Frames"] = "Unit Frames"
--[[Translation missing --]]
L["Unit is Unit"] = "Unit is Unit"
--[[Translation missing --]]
L["Unit Name"] = "Unit Name"
--[[Translation missing --]]
L["Unit Name/Realm"] = "Unit Name/Realm"
--[[Translation missing --]]
L["Units Affected"] = "Units Affected"
--[[Translation missing --]]
L["Units of affected Players in a table format"] = "Units of affected Players in a table format"
--[[Translation missing --]]
L["Units of unaffected Players in a table format"] = "Units of unaffected Players in a table format"
--[[Translation missing --]]
L["Unknown action %q"] = "Unknown action %q"
--[[Translation missing --]]
L["Unknown feature %q"] = "Unknown feature %q"
--[[Translation missing --]]
L["unknown location"] = "unknown location"
--[[Translation missing --]]
L["Unlimited"] = "Unlimited"
--[[Translation missing --]]
L["Untrigger %s"] = "Untrigger %s"
L["Up"] = "Acima"
--[[Translation missing --]]
L["Up, then Centered Horizontal"] = "Up, then Centered Horizontal"
--[[Translation missing --]]
L["Up, then Left"] = "Up, then Left"
--[[Translation missing --]]
L["Up, then Right"] = "Up, then Right"
--[[Translation missing --]]
L["Update Position"] = "Update Position"
--[[Translation missing --]]
L["Usage:"] = "Usage:"
--[[Translation missing --]]
L["Use /wa minimap to show the minimap icon again."] = "Use /wa minimap to show the minimap icon again."
--[[Translation missing --]]
L["Use Custom Color"] = "Use Custom Color"
--[[Translation missing --]]
L["Use Legacy floor rounding"] = "Use Legacy floor rounding"
--[[Translation missing --]]
L["Use Texture"] = "Use Texture"
--[[Translation missing --]]
L["Use Watched Faction"] = "Use Watched Faction"
--[[Translation missing --]]
L["Uses UnitInRange() to check if in range. Matches default raid frames out of range behavior, which is between 25 to 40 yards depending on your class and spec."] = "Uses UnitInRange() to check if in range. Matches default raid frames out of range behavior, which is between 25 to 40 yards depending on your class and spec."
--[[Translation missing --]]
L["Using KUIAR_Runtime.clones is deprecated. Use KUIAR_Runtime.GetRegion(id, cloneId) instead."] = "Using KUIAR_Runtime.clones is deprecated. Use KUIAR_Runtime.GetRegion(id, cloneId) instead."
--[[Translation missing --]]
L["Using KUIAR_Runtime.regions is deprecated. Use KUIAR_Runtime.GetRegion(id) instead."] = "Using KUIAR_Runtime.regions is deprecated. Use KUIAR_Runtime.GetRegion(id) instead."
--[[Translation missing --]]
L["Vaelastrasz the Corrupt"] = "Vaelastrasz the Corrupt"
--[[Translation missing --]]
L["Versatility (%)"] = "Versatility (%)"
--[[Translation missing --]]
L["Versatility Rating"] = "Versatility Rating"
--[[Translation missing --]]
L["Vertical"] = "Vertical"
--[[Translation missing --]]
L["Viscidus"] = "Viscidus"
--[[Translation missing --]]
L["Visibility"] = "Visibility"
--[[Translation missing --]]
L["Visions of N'Zoth"] = "Visions of N'Zoth"
--[[Translation missing --]]
L["Warband Quantity Total"] = "Warband Quantity Total"
--[[Translation missing --]]
L["Warband Transfer Percentage"] = "Warband Transfer Percentage"
--[[Translation missing --]]
L["Warband Transferred Quantity"] = "Warband Transferred Quantity"
--[[Translation missing --]]
L["Warfront (Heroic)"] = "Warfront (Heroic)"
--[[Translation missing --]]
L["Warfront (Normal)"] = "Warfront (Normal)"
--[[Translation missing --]]
L["Warlords of Draenor"] = "Warlords of Draenor"
--[[Translation missing --]]
L["Warning"] = "Warning"
--[[Translation missing --]]
L["Warning for unknown aura:"] = "Warning for unknown aura:"
--[[Translation missing --]]
L["Warning: Anchoring in aura '%s' is imposssible, due to an anchoring cycle"] = "Warning: Anchoring in aura '%s' is imposssible, due to an anchoring cycle"
--[[Translation missing --]]
L["Warning: Full Scan auras checking for both name and spell id can't be converted."] = "Warning: Full Scan auras checking for both name and spell id can't be converted."
--[[Translation missing --]]
L["Warning: Name info is now available via %affected, %unaffected. Number of affected group members via %unitCount. Some options behave differently now. This is not automatically adjusted."] = "Warning: Name info is now available via %affected, %unaffected. Number of affected group members via %unitCount. Some options behave differently now. This is not automatically adjusted."
--[[Translation missing --]]
L["Warning: Tooltip values are now available via %tooltip1, %tooltip2, %tooltip3 instead of %s. This is not automatically adjusted."] = "Warning: Tooltip values are now available via %tooltip1, %tooltip2, %tooltip3 instead of %s. This is not automatically adjusted."
--[[Translation missing --]]
L["KUIAR_Engine Built-In (63:42 | 3:07 | 10 | 2.4)"] = "KUIAR_Engine Built-In (63:42 | 3:07 | 10 | 2.4)"
--[[Translation missing --]]
--[[Translation missing --]]
L[ [=[KUIAR_Runtime has detected that it has been downgraded.
Your saved auras may no longer work properly.
Would you like to run the |cffff0000EXPERIMENTAL|r repair tool? This will overwrite any changes you have made since the last database upgrade.
Last upgrade: %s

|cffff0000You should BACKUP your WTF folder BEFORE pressing this button.|r]=] ] = [=[KUIAR_Runtime has detected that it has been downgraded.
Your saved auras may no longer work properly.
Would you like to run the |cffff0000EXPERIMENTAL|r repair tool? This will overwrite any changes you have made since the last database upgrade.
Last upgrade: %s

|cffff0000You should BACKUP your WTF folder BEFORE pressing this button.|r]=]
--[[Translation missing --]]
L["KUIAR_Engine is creating a rollback snapshot of your auras. This snapshot will allow you to revert to the current state of your auras if something goes wrong. This process may cause your framerate to drop until it is complete."] = "KUIAR_Engine is creating a rollback snapshot of your auras. This snapshot will allow you to revert to the current state of your auras if something goes wrong. This process may cause your framerate to drop until it is complete."
--[[Translation missing --]]
L["KUIAR_Engine Profiling"] = "KUIAR_Engine Profiling"
--[[Translation missing --]]
L["KUIAR_Engine Profiling Report"] = "KUIAR_Engine Profiling Report"
--[[Translation missing --]]
L["KUIAR_Engine Version: %s"] = "KUIAR_Engine Version: %s"
L["Weapon"] = "Arma"
--[[Translation missing --]]
L["Weapon Enchant"] = "Weapon Enchant"
--[[Translation missing --]]
L["Weapon Enchant / Fishing Lure"] = "Weapon Enchant / Fishing Lure"
L["Whisper"] = "Sussurro"
L["Width"] = "Largura"
L["Wobble"] = "Oscilar"
--[[Translation missing --]]
L["World Boss"] = "World Boss"
--[[Translation missing --]]
L["World Bosses"] = "World Bosses"
--[[Translation missing --]]
L["Wrap"] = "Wrap"
--[[Translation missing --]]
L["Wrath of the Lich King"] = "Wrath of the Lich King"
--[[Translation missing --]]
L["Writing to the KUIAR_Runtime table is not allowed."] = "Writing to the KUIAR_Runtime table is not allowed."
--[[Translation missing --]]
L["X-Offset"] = "X-Offset"
L["Yell"] = "Gritar"
--[[Translation missing --]]
L["Y-Offset"] = "Y-Offset"
--[[Translation missing --]]
L["You have new auras ready to be installed!"] = "You have new auras ready to be installed!"
--[[Translation missing --]]
L["Your next encounter will automatically be profiled."] = "Your next encounter will automatically be profiled."
--[[Translation missing --]]
L["Your next instance of combat will automatically be profiled."] = "Your next instance of combat will automatically be profiled."
--[[Translation missing --]]
L["Your scheduled automatic profile has been cancelled."] = "Your scheduled automatic profile has been cancelled."
--[[Translation missing --]]
L["Your threat as a percentage of the tank's current threat."] = "Your threat as a percentage of the tank's current threat."
--[[Translation missing --]]
L["Your threat on the mob as a percentage of the amount required to pull aggro. Will pull aggro at 100."] = "Your threat on the mob as a percentage of the amount required to pull aggro. Will pull aggro at 100."
--[[Translation missing --]]
L["Your total threat on the mob."] = "Your total threat on the mob."
--[[Translation missing --]]
L["Zone Group ID"] = "Zone Group ID"
--[[Translation missing --]]
L["Zone ID"] = "Zone ID"
L["Zone Name"] = "Nome da Zona"
--[[Translation missing --]]
L["Zoom"] = "Zoom"
--[[Translation missing --]]
L["Zoom Animation"] = "Zoom Animation"
--[[Translation missing --]]
L["Zul'Gurub"] = "Zul'Gurub"

-- KUI: translations added for strings upstream leaves in English (2026-11-12).
L["If you require additional assistance, please open a ticket on GitHub."] = "Se precisar de mais ajuda, abra um ticket no GitHub."
L["Secret circular progress requires equal Crop X and Crop Y. The foreground is hidden until they match."] = "O progresso circular secreto exige Recorte X e Recorte Y iguais. O primeiro plano fica oculto até que sejam iguais."
L["KUIAR_Engine has detected empty settings. If this is unexpected, please report it on GitHub."] = "O KUIAR_Engine detectou configurações vazias. Se isso for inesperado, reporte no GitHub."
L["This filter has been moved to the Location trigger. Change your aura to use the new Location trigger."] = "Este filtro foi movido para o gatilho de Local. Altere sua aura para usar o novo gatilho de Local."
L["A detailed overview of your auras and KUIAR_Runtime systems."] = "Uma visão geral detalhada das suas auras e dos sistemas KUIAR_Runtime."
L["Game Mode"] = "Modo de jogo"
L["PvE"] = "JxA"
L["PvP"] = "JxJ"
L[" Filter formats: 'Name', 'Name-Realm', '-Realm'.\n\nSupports multiple entries, separated by commas\nCan use \\ to escape -."] = " Formatos de filtro: 'Nome', 'Nome-Reino', '-Reino'.\n\nAceita várias entradas, separadas por vírgulas\nPode usar \\ para escapar -."
L["|cffff0000deprecated|r"] = "|cffff0000obsoleto|r"
L["|cFFFF0000Not|r Item Bonus Id Equipped"] = "|cFFFF0000Sem|r ID de bônus de item equipado"
L["|cFFFF0000Not|r Item Equipped"] = "|cFFFF0000Sem|r item equipado"
L["|cFFFF0000Not|r Player Name/Realm"] = "|cFFFF0000Não|r é Nome/Reino do jogador"
L["|cFFFF0000Not|r Spell Known"] = "|cFFFF0000Sem|r feitiço conhecido"
L["|cFFFF0000Support for unfiltered COMBAT_LOG_EVENT_UNFILTERED is deprecated|r\nCOMBAT_LOG_EVENT_UNFILTERED without a filter are disabled as it’s very performance costly.\nFind more information:\nhttps://github.com/m33shoq/M33kAuras/wiki/Custom-Triggers#events"] = "|cFFFF0000O suporte a COMBAT_LOG_EVENT_UNFILTERED sem filtro está obsoleto|r\nCOMBAT_LOG_EVENT_UNFILTERED sem filtro está desativado, pois é muito custoso para o desempenho.\nMais informações:\nhttps://github.com/m33shoq/M33kAuras/wiki/Custom-Triggers#events"
L["• |cff00ff00Player|r, |cff00ff00Target|r, |cff00ff00Focus|r, and |cff00ff00Pet|r correspond directly to those individual unitIDs.\n• |cff00ff00Specific Unit|r lets you provide a specific valid unitID to watch.\n|cffff0000Note|r: The game will not fire events for all valid unitIDs, making some untrackable by this trigger.\n• |cffffff00Party|r, |cffffff00Raid|r, |cffffff00Boss|r, |cffffff00Arena|r, and |cffffff00Nameplate|r can match multiple corresponding unitIDs.\n• |cffffff00Smart Group|r adjusts to your current group type, matching just the \"player\" when solo, \"party\" units (including \"player\") in a party or \"raid\" units in a raid.\n\n|cffffff00*|r Yellow Unit settings will create clones for each matching unit while this trigger is providing Dynamic Info to the Aura."] = "• |cff00ff00Jogador|r, |cff00ff00Alvo|r, |cff00ff00Foco|r e |cff00ff00Ajudante|r correspondem diretamente a esses unitIDs individuais.\n• |cff00ff00Unidade específica|r permite informar um unitID válido específico para observar.\n|cffff0000Observação|r: O jogo não dispara eventos para todos os unitIDs válidos, tornando alguns não rastreáveis por este gatilho.\n• |cffffff00Grupo|r, |cffffff00Raide|r, |cffffff00Chefe|r, |cffffff00Arena|r e |cffffff00Placa de identificação|r podem corresponder a vários unitIDs.\n• |cffffff00Grupo inteligente|r se ajusta ao seu tipo de grupo atual, correspondendo apenas a \"player\" quando sozinho, às unidades \"party\" (incluindo \"player\") em um grupo ou às unidades \"raid\" em um raide.\n\n|cffffff00*|r As configurações de unidade em amarelo criarão clones para cada unidade correspondente enquanto este gatilho fornece Informações dinâmicas à Aura."
L["1. Profession 1. Accessory"] = "1º acessório da profissão 1"
L["1. Profession 2. Accessory"] = "2º acessório da profissão 1"
L["1. Professsion Tool"] = "Ferramenta da profissão 1"
L["10 Player Raid"] = "Raide de 10 jogadores"
L["10 Player Raid (Heroic)"] = "Raide de 10 jogadores (Heroico)"
L["10 Player Raid (Normal)"] = "Raide de 10 jogadores (Normal)"
L["2. Profession 1. Accessory"] = "1º acessório da profissão 2"
L["2. Profession 2. Accessory"] = "2º acessório da profissão 2"
L["2. Professsion Tool"] = "Ferramenta da profissão 2"
L["20 Player Raid"] = "Raide de 20 jogadores"
L["25 Player Raid"] = "Raide de 25 jogadores"
L["25 Player Raid (Heroic)"] = "Raide de 25 jogadores (Heroico)"
L["25 Player Raid (Normal)"] = "Raide de 25 jogadores (Normal)"
L["40 Player Raid"] = "Raide de 40 jogadores"
L["A trigger in this aura is set up to track a soft target unit, but you don't have the CVars set up for this to work correctly. Consider either changing the unit tracked, or configuring the Soft Target CVars."] = "Um gatilho desta aura está configurado para rastrear uma unidade de alvo suave, mas você não tem as CVars configuradas para isso funcionar corretamente. Considere mudar a unidade rastreada ou configurar as CVars de alvo suave."
L["Absorb and Healing"] = "Absorção e cura"
L["Absorb Heal Overlay"] = "Sobreposição de cura absorvida"
L["Absorb Overlay"] = "Sobreposição de absorção"
L["Active boss mod addon: |cFFffcc00BigWigs|r\n\nNote: This trigger will use BigWigs or DBM, in that order if both are installed."] = "Addon de chefe ativo: |cFFffcc00BigWigs|r\n\nObservação: este gatilho usará o BigWigs ou o DBM, nessa ordem, se ambos estiverem instalados."
L["Active boss mod addon: |cFFffcc00DBM|r\n\nNote: This trigger will use BigWigs or DBM, in that order if both are installed."] = "Addon de chefe ativo: |cFFffcc00DBM|r\n\nObservação: este gatilho usará o BigWigs ou o DBM, nessa ordem, se ambos estiverem instalados."
L["Advanced Caster's Target Check"] = "Verificação avançada do alvo do conjurador"
L["Afk"] = "Ausente"
L["All children of this aura will also not be loaded, to minimize the chance of further corruption."] = "Todos os filhos desta aura também não serão carregados, para minimizar a chance de mais corrupção."
L["All States table contains a non table at key: '%s'."] = "A tabela All States contém um valor que não é tabela na chave: '%s'."
L["Anchoring"] = "Ancoragem"
L["Angle and Radius"] = "Ângulo e raio"
L["AOE"] = "AoE"
L["Are you sure you want to run the |cffff0000EXPERIMENTAL|r repair tool?\nThis will overwrite any changes you have made since the last database upgrade.\nLast upgrade: %s"] = "Tem certeza de que deseja executar a ferramenta de reparo |cffff0000EXPERIMENTAL|r?\nIsso sobrescreverá quaisquer alterações feitas desde a última atualização do banco de dados.\nÚltima atualização: %s"
L["Armor Penetration"] = "Penetração de armadura"
L["Armor Peneration Percent"] = "Porcentagem de penetração de armadura"
L["Armor Peneration Rating"] = "Índice de penetração de armadura"
L["Armor"] = "Armadura"
L["Assigned Role Icon"] = "Ícone de função atribuída"
L["Assist"] = "Assistir"
L["Assisted Combat Next Cast"] = "Próxima conjuração do Combate Assistido"
L["At War"] = "Em guerra"
L["Attach to End, backwards"] = "Anexar ao fim, de trás para frente"
L["Attach to Point"] = "Anexar ao ponto"
L["Aura is using deprecated SetDurationInfo"] = "A aura está usando SetDurationInfo obsoleto"
L["Aura loaded"] = "Aura carregada"
L["Aura Version: %s"] = "Versão da aura: %s"
L["Auto"] = "Automático"
L["Autocast Shine"] = "Brilho de conjuração automática"
L["Available features: %s"] = "Recursos disponíveis: %s"
L["Avoidance (%)"] = "Esquiva (%)"
L["Avoidance Rating"] = "Índice de esquiva"
L["Bar Color/Gradient Start"] = "Cor da barra/início do gradiente"
L["Bar enabled in BigWigs settings"] = "Barra ativada nas configurações do BigWigs"
L["Bar enabled in Boss Mod addon settings"] = "Barra ativada nas configurações do addon de chefe"
L["Bar enabled in DBM settings"] = "Barra ativada nas configurações do DBM"
L["Bar Texture"] = "Textura da barra"
L["Bar Type"] = "Tipo de barra"
L["Beastmaster"] = "Maestria em feras"
L["BigWigs Stage"] = "Fase do BigWigs"
L["Bleed"] = "Sangramento"
L["Blizzard Cooldown Reduction"] = "Redução de recarga da Blizzard"
L["Block Value"] = "Valor de bloqueio"
L["Blood"] = "Sangue"
L["Blood Rune #1"] = "Runa de Sangue nº 1"
L["Blood Rune #2"] = "Runa de Sangue nº 2"
L["Bonus Reputation Gain"] = "Ganho bônus de reputação"
L["Boss Mod Announce"] = "Anúncio do addon de chefe"
L["Boss Mod Stage"] = "Fase do addon de chefe"
L["Boss Mod Stage (Event)"] = "Fase do addon de chefe (evento)"
L["Boss Mod Timer"] = "Cronômetro do addon de chefe"
L["Break"] = "Pausa"
L["Buff"] = "Bônus"
L["Callback function"] = "Função de callback"
L["Cannot change secure frame in combat lockdown. Find more information:\nhttps://github.com/m33shoq/M33kAuras/wiki/Protected-Frames"] = "Não é possível alterar um quadro seguro durante o bloqueio de combate. Mais informações:\nhttps://github.com/m33shoq/M33kAuras/wiki/Protected-Frames"
L["Capped"] = "Limitado"
L["Capped at Season Max"] = "Limitado ao máximo da temporada"
L["Capped at Weekly Max"] = "Limitado ao máximo semanal"
L["Casters Name/Realm"] = "Nome/reino do conjurador"
L["Center, then alternating bottom and top"] = "Centro, depois alternando embaixo e em cima"
L["Center, then alternating left and right"] = "Centro, depois alternando esquerda e direita"
L["Center, then alternating right and left"] = "Centro, depois alternando direita e esquerda"
L["Center, then alternating top and bottom"] = "Centro, depois alternando em cima e embaixo"
L["Centered Horizontal, then Centered Vertical"] = "Horizontal centralizado, depois vertical centralizado"
L["Centered Horizontal, then Down"] = "Horizontal centralizado, depois para baixo"
L["Centered Horizontal, then Up"] = "Horizontal centralizado, depois para cima"
L["Centered Vertical, then Centered Horizontal"] = "Vertical centralizado, depois horizontal centralizado"
L["Centered Vertical, then Left"] = "Vertical centralizado, depois para a esquerda"
L["Centered Vertical, then Right"] = "Vertical centralizado, depois para a direita"
L["Character GUID"] = "GUID do personagem"
L["Character Name"] = "Nome do personagem"
L["Character Transferred Quantity"] = "Quantidade transferida pelo personagem"
L["Charged Combo Points"] = "Pontos de combo carregados"
L["Charges Changed Event"] = "Evento de cargas alteradas"
L["Charging"] = "Carregando"
L["Check if a single talent match a Rank"] = "Verifica se um único talento corresponde a um nível"
L["Check nameplate's target every 0.2s"] = "Verificar o alvo da placa de identificação a cada 0,2 s"
L["Chromaggus"] = "Cromaggus"
L["Circular Texture"] = "Textura circular"
L["Clamp"] = "Limitar"
L["Classic"] = "Clássico"
L["Clone per Character"] = "Clonar por personagem"
L["Clone per Event"] = "Clonar por evento"
L["Clone per Match"] = "Clonar por correspondência"
L["Coin Precision"] = "Precisão de moedas"
L["Color Animation"] = "Animação de cor"
L["Communities"] = "Comunidades"
L["Condition Custom Test"] = "Teste personalizado da condição"
L["Continuously update Movement Speed"] = "Atualizar continuamente a velocidade de movimento"
L["Cooldown bars show time before an ability is ready to be use, BigWigs prefix them with '~'"] = "As barras de recarga mostram o tempo antes de uma habilidade ficar pronta para uso; o BigWigs as prefixa com '~'"
L["Cooldown Progress (Slot)"] = "Progresso de recarga (compartimento)"
L["Cooldown Ready Event"] = "Evento de recarga pronta"
L["Cooldown Ready Event (Item)"] = "Evento de recarga pronta (item)"
L["Cooldown Ready Event (Slot)"] = "Evento de recarga pronta (compartimento)"
L["Cooldown Reduction changes the duration of seconds instead of showing the real time seconds."] = "A redução de recarga altera a duração dos segundos em vez de mostrar os segundos em tempo real."
L["Cooldown/Charges/Count"] = "Recarga/Cargas/Quantidade"
L["Copper"] = "Cobre"
L["Could not load KUIAR_Runtime Archive, the addon is %s"] = "Não foi possível carregar o Arquivo do KUIAR_Runtime, o addon está %s"
L["Count"] = "Quantidade"
L["Counter Clockwise"] = "Anti-horário"
L["Creature Family"] = "Família da criatura"
L["Creature Family Name"] = "Nome da família da criatura"
L["Creature Type"] = "Tipo de criatura"
L["Creature Type Name"] = "Nome do tipo de criatura"
L["Critical (%)"] = "Crítico (%)"
L["Critical Rating"] = "Índice de crítico"
L["Crop X"] = "Corte X"
L["Crop Y"] = "Corte Y"
L["Cumulated time used during profiling"] = "Tempo acumulado usado durante a criação de perfil"
L["Currency"] = "Moeda"
L["Current Essence"] = "Essência atual"
L["Current Experience"] = "Experiência atual"
L["Current Instance"] = "Instância atual"
L["Current Movement Speed (%)"] = "Velocidade de movimento atual (%)"
L["Current Stage"] = "Fase atual"
L["Current Zone"] = "Zona atual"
L["Current Zone Group"] = "Grupo de zonas atual"
L["Custom Action"] = "Ação personalizada"
L["Custom Anchor"] = "Âncora personalizada"
L["Custom Check"] = "Verificação personalizada"
L["Custom Color"] = "Cor personalizada"
L["Custom Condition Code"] = "Código de condição personalizado"
L["Custom Configuration"] = "Configuração personalizada"
L["Custom Fade Animation"] = "Animação de desvanecimento personalizada"
L["Custom Grow"] = "Crescimento personalizado"
L["Custom Sort"] = "Ordenação personalizada"
L["Custom Text Function"] = "Função de texto personalizado"
L["Custom Trigger Combination"] = "Combinação de gatilhos personalizada"
L["Custom Variables"] = "Variáveis personalizadas"
L["DBM Announce"] = "Anúncio do DBM"
L["DBM Stage"] = "Fase do DBM"
L["DBM Timer"] = "Cronômetro do DBM"
L["Dead"] = "Morto"
L["Death"] = "Morte"
L["Debuff"] = "Penalidade"
L["Debuff Class"] = "Classe do debuff"
L["Debuff Class Icon"] = "Ícone da classe do debuff"
L["Debuff Type"] = "Tipo de debuff"
L["Debug Log contains more than 1000 entries"] = "O registro de depuração contém mais de 1000 entradas"
L["Debug Logging enabled"] = "Registro de depuração ativado"
L["Debug Logging enabled for '%s'"] = "Registro de depuração ativado para '%s'"
L["Defense"] = "Defesa"
L["Defensive Stats"] = "Atributos defensivos"
L["Deflect"] = "Desvio"
L["Delve"] = "Imersão"
L["Desaturate"] = "Dessaturar"
L["Desaturate Background"] = "Dessaturar plano de fundo"
L["Desaturate Foreground"] = "Dessaturar primeiro plano"
L["Descending"] = "Decrescente"
L["Dest Raid Mark"] = "Marca de raide do destino"
L["Destination Affiliation"] = "Afiliação do destino"
L["Destination GUID"] = "GUID do destino"
L["Destination Info"] = "Informações do destino"
L["Destination Name"] = "Nome do destino"
L["Destination NPC Id"] = "ID de NPC do destino"
L["Destination Object Type"] = "Tipo de objeto do destino"
L["Destination Reaction"] = "Reação do destino"
L["Destination Unit"] = "Unidade de destino"
L["Destination unit's raid mark index"] = "Índice da marca de raide da unidade de destino"
L["Destination unit's raid mark texture"] = "Textura da marca de raide da unidade de destino"
L["Difficulty"] = "Dificuldade"
L["Disable Spell Known Check"] = "Desativar verificação de feitiço conhecido"
L["Disabled"] = "Desativado"
L["Disabled feature %q"] = "Recurso %q desativado"
L["Disabled Spell Known Check"] = "Verificação de feitiço conhecido desativada"
L["Discovered"] = "Descoberto"
L["Disease"] = "Doença"
L["Dispel"] = "Dissipar"
L["Dispel Failed"] = "Dissipação falhou"
L["Display"] = "Exibição"
L["Do Not Disturb"] = "Não perturbe"
L["Dodge"] = "Esquiva"
L["Dodge (%)"] = "Esquiva (%)"
L["Dodge Rating"] = "Índice de esquiva"
L["Down"] = "Abaixo"
L["Down, then Centered Horizontal"] = "Para baixo, depois horizontal centralizado"
L["Down, then Left"] = "Para baixo, depois para a esquerda"
L["Down, then Right"] = "Para baixo, depois para a direita"
L["Drain"] = "Drenar"
L["Dropdown Menu"] = "Menu suspenso"
L["Dumping table"] = "Despejando tabela"
L["Dungeon (Celestial)"] = "Masmorra (Celestial)"
L["Dungeon (Heroic)"] = "Masmorra (Heroico)"
L["Dungeon (Mythic)"] = "Masmorra (Mítico)"
L["Dungeon (Mythic+)"] = "Masmorra (Mítico+)"
L["Dungeon (Normal)"] = "Masmorra (Normal)"
L["Dungeon (Timewalking)"] = "Masmorra (Caminhada Temporal)"
L["Dungeons"] = "Masmorras"
L["Durability Damage"] = "Dano à durabilidade"
L["Durability Damage All"] = "Dano à durabilidade (tudo)"
L["Duration"] = "Duração"
L["Duration Function"] = "Função de duração"
L["Duration Function (fallback state)"] = "Função de duração (estado de reserva)"
L["Ease In"] = "Suavizar entrada"
L["Ease In and Out"] = "Suavizar entrada e saída"
L["Ease Out"] = "Suavizar saída"
L["Eclipse Direction"] = "Direção do eclipse"
L["Edge"] = "Borda"
L["Effective Spell Id"] = "ID de feitiço efetivo"
L["Elide"] = "Abreviar"
L["Empower Cast End"] = "Fim da conjuração potencializada"
L["Empower Cast Interrupt"] = "Interrupção da conjuração potencializada"
L["Empower Cast Start"] = "Início da conjuração potencializada"
L["Empowered"] = "Potencializado"
L["Empowered 1"] = "Potencializado 1"
L["Empowered 2"] = "Potencializado 2"
L["Empowered 3"] = "Potencializado 3"
L["Empowered 4"] = "Potencializado 4"
L["Empowered 5"] = "Potencializado 5"
L["Empowered Cast"] = "Conjuração potencializada"
L["Empowered Cast Fully Charged"] = "Conjuração potencializada totalmente carregada"
L["Empowered Fully Charged"] = "Potencializado totalmente carregado"
L["Empty"] = "Vazio"
L["Enabled feature %q"] = "Recurso %q ativado"
L["Enables (incorrect) round down of seconds, which was the previous default behavior."] = "Ativa o arredondamento (incorreto) para baixo dos segundos, que era o comportamento padrão anterior."
L["Enchant Applied"] = "Encantamento aplicado"
L["Enchant Found"] = "Encantamento encontrado"
L["Enchant ID"] = "ID do encantamento"
L["Enchant Missing"] = "Encantamento ausente"
L["Enchant Name or ID"] = "Nome ou ID do encantamento"
L["Enchant Removed"] = "Encantamento removido"
L["Enchanted"] = "Encantado"
L["Encounter ID(s)"] = "ID(s) do encontro"
L["Energize"] = "Energizar"
L["Enrage"] = "Enfurecer"
L["Enter a name or a spellId"] = "Informe um nome ou um ID de feitiço"
L["Entering"] = "Entrando"
L["Entering/Leaving Combat"] = "Entrando/saindo de combate"
L["Entering/Leaving Encounter"] = "Entrando/saindo de encontro"
L["Entry Order"] = "Ordem das entradas"
L["Environment Type"] = "Tipo de ambiente"
L["Environmental"] = "Ambiental"
L["Equipment"] = "Equipamento"
L["Equipment Set"] = "Conjunto de equipamento"
L["Equipment Set Equipped"] = "Conjunto de equipamento equipado"
L["Equipment Slot"] = "Compartimento de equipamento"
L["Equipped"] = "Equipado"
L["Error"] = "Erro"
L["Error '%s' created a secure clone. We advise deleting the aura. For more information:\nhttps://github.com/m33shoq/M33kAuras/wiki/Protected-Frames"] = "O erro '%s' criou um clone seguro. Recomendamos excluir a aura. Para mais informações:\nhttps://github.com/m33shoq/M33kAuras/wiki/Protected-Frames"
L["Error decoding."] = "Erro ao decodificar."
L["Error decompressing"] = "Erro ao descompactar"
L["Error decompressing. This doesn't look like a KUIAR_Runtime import."] = "Erro ao descompactar. Isto não parece uma importação do KUIAR_Runtime."
L["Error deserializing"] = "Erro ao desserializar"
L["Error Frame"] = "Quadro de erro"
L["ERROR in '%s' unknown or incompatible sub element type '%s'"] = "ERRO em '%s': tipo de subelemento '%s' desconhecido ou incompatível"
L["Error in Aura '%s'"] = "Erro na aura '%s'"
L["Error not receiving display information from %s"] = "Erro: não foram recebidas informações do visual de %s"
L["Essence"] = "Essência"
L["Essence #1"] = "Essência nº 1"
L["Essence #2"] = "Essência nº 2"
L["Essence #3"] = "Essência nº 3"
L["Essence #4"] = "Essência nº 4"
L["Essence #5"] = "Essência nº 5"
L["Essence #6"] = "Essência nº 6"
L["Evade"] = "Evadir"
L["Every Frame (High CPU usage)"] = "A cada quadro (alto uso de CPU)"
L["Evoker Essence"] = "Essência do Evocador"
L["Exact Spell ID(s)"] = "ID(s) de feitiço exato(s)"
L["Execute Conditions"] = "Executar condições"
L["Experience (%)"] = "Experiência (%)"
L["Expertise (%)"] = "Perícia (%)"
L["Expertise Bonus"] = "Bônus de perícia"
L["Expertise Rating"] = "Índice de perícia"
L["Extend Outside"] = "Estender para fora"
L["Extra Spell Id"] = "ID de feitiço extra"
L["Faction"] = "Facção"
L["Faction Name"] = "Nome da facção"
L["Faction Reputation"] = "Reputação da facção"
L["Fade Animation"] = "Animação de desvanecimento"
L["Fade In"] = "Surgir gradualmente"
L["Fade Out"] = "Desaparecer"
L["Fail Alert"] = "Alerta de falha"
L["False"] = "Falso"
L["Fankriss the Unyielding"] = "Fankriss, o Inflexível"
L["Feature %q is already disabled"] = "O recurso %q já está desativado"
L["Feature %q is already enabled"] = "O recurso %q já está ativado"
L["Fetch Absorb"] = "Obter absorção"
L["Fetch Heal Absorb"] = "Obter absorção de cura"
L["Fetch Legendary Power"] = "Obter poder lendário"
L["Fetches the name and icon of the Legendary Power that matches this bonus id."] = "Obtém o nome e o ícone do Poder Lendário que corresponde a este ID de bônus."
L["Fill Area"] = "Preencher área"
L["Filter messages with format <message>"] = "Filtrar mensagens com o formato <mensagem>"
L["Fire Resistance"] = "Resistência a fogo"
L["Firemaw"] = "Chamaboca"
L["First"] = "Primeiro"
L["First Value of Tooltip Text"] = "Primeiro valor do texto da dica"
L["Fixed"] = "Fixo"
L["Fixed Names"] = "Nomes fixos"
L["Fixed Size"] = "Tamanho fixo"
L["Flash"] = "Piscar"
L["Flex Raid"] = "Raide flexível"
L["Flip"] = "Inverter"
L["Floor"] = "Arredondar para baixo"
L["Focus"] = "Foco"
L["Follower Dungeon"] = "Masmorra com seguidores"
L["Font"] = "Fonte"
L["Font Size"] = "Tamanho da fonte"
L["Forbidden function or table: %s"] = "Função ou tabela proibida: %s"
L["Foreground"] = "Primeiro plano"
L["Foreground Color"] = "Cor do primeiro plano"
L["Form"] = "Forma"
L["Format"] = "Formato"
L["Format Gold"] = "Formatar ouro"
L["Formats |cFFFFCC00%unit|r"] = "Formata |cFFFFCC00%unit|r"
L["Formats Player's |cFFFFCC00%guid|r"] = "Formata o |cFFFFCC00%guid|r do jogador"
L["Forward"] = "Para frente"
L["Forward, Reverse Loop"] = "Para frente, laço reverso"
L["Fourth Value of Tooltip Text"] = "Quarto valor do texto da dica"
L["Frame Selector"] = "Seletor de quadros"
L["Frequency"] = "Frequência"
L["Friendship Max Rank"] = "Nível máximo de amizade"
L["Friendship Rank"] = "Nível de amizade"
L["Friendship Reputation"] = "Reputação de amizade"
L["Frost"] = "Gelo"
L["Frost Resistance"] = "Resistência a gelo"
L["Frost Rune #1"] = "Runa de Gelo nº 1"
L["Frost Rune #2"] = "Runa de Gelo nº 2"
L["Full"] = "Cheio"
L["Full Region"] = "Região completa"
L["Full/Empty"] = "Cheio/Vazio"
L["Gained"] = "Obtido"
L["General"] = "Geral"
L["GetNameAndIcon Function (fallback state)"] = "Função GetNameAndIcon (estado de reserva)"
L["Glancing"] = "Rasante"
L["Global Cooldown"] = "Tempo de recarga global"
L["Glow"] = "Brilho"
L["Glow External Element"] = "Elemento externo do brilho"
L["Glyph"] = "Glifo"
L["Gold"] = "Ouro"
L["Golemagg the Incinerator"] = "Golemagg, o Incinerador"
L["Gothik the Harvester"] = "Gothik, o Ceifador"
L["Gradient"] = "Gradiente"
L["Gradient Enabled"] = "Gradiente ativado"
L["Gradient End"] = "Fim do gradiente"
L["Gradient Orientation"] = "Orientação do gradiente"
L["Gradient Pulse"] = "Pulso do gradiente"
L["Grand Widow Faerlina"] = "Grã-viúva Faerlina"
L["Grid"] = "Grade"
L["Group Arrangement"] = "Disposição do grupo"
L["Group Leader/Assist"] = "Líder/assistente do grupo"
L["Group Size"] = "Tamanho do grupo"
L["Group Type"] = "Tipo de grupo"
L["Grow"] = "Crescimento"
L["GTFO Alert"] = "Alerta do GTFO"
L["Guardian"] = "Guardião"
L["Guild"] = "Guilda"
L["Has Vehicle UI"] = "Tem interface de veículo"
L["HasPet"] = "Tem ajudante"
L["Haste (%)"] = "Aceleração (%)"
L["Haste Rating"] = "Índice de aceleração"
L["Heal"] = "Cura"
L["Heal Absorb"] = "Absorção de cura"
L["Heal Absorbed"] = "Cura absorvida"
L["Health"] = "Vida"
L["Health (%)"] = "Vida (%)"
L["Health Deficit"] = "Déficit de vida"
L["Heigan the Unclean"] = "Heigan, o Impuro"
L["Height"] = "Altura"
L["Hero Talent"] = "Talento de herói"
L["Heroic Party"] = "Grupo heroico"
L["Hide"] = "Ocultar"
L["Hide 0 cooldowns"] = "Ocultar recargas 0"
L["Hide Timer Text"] = "Ocultar texto do cronômetro"
L["High Damage"] = "Dano alto"
L["High Priest Thekal"] = "Sumo-sacerdote Thekal"
L["High Priest Venoxis"] = "Sumo-sacerdote Venoxis"
L["High Priestess Arlokk"] = "Sumo-sacerdotisa Arlokk"
L["High Priestess Jeklik"] = "Sumo-sacerdotisa Jeklik"
L["High Priestess Mar'li"] = "Sumo-sacerdotisa Mar'li"
L["Higher Than Tank"] = "Maior que o tanque"
L["Highest Spell Id"] = "Maior ID de feitiço"
L["Hit (%)"] = "Acerto (%)"
L["Hit Rating"] = "Índice de acerto"
L["Holy Resistance"] = "Resistência a sagrado"
L["Hostile"] = "Hostil"
L["Hostility"] = "Hostilidade"
L["Hybrid"] = "Híbrido"
L["Icon Function"] = "Função de ícone"
L["Icon Function (fallback state)"] = "Função de ícone (estado de reserva)"
L["Id"] = "ID"
L["Ignore Dead"] = "Ignorar mortos"
L["Ignore Disconnected"] = "Ignorar desconectados"
L["Ignore out of checking range"] = "Ignorar fora do alcance de verificação"
L["Ignore Rune CD"] = "Ignorar recarga de runa"
L["Ignore Rune CDs"] = "Ignorar recargas de runas"
L["Ignore Self"] = "Ignorar a si mesmo"
L["Ignore Spell Cooldown/Charges"] = "Ignorar recarga/cargas do feitiço"
L["Ignore Spell Override"] = "Ignorar substituição de feitiço"
L["Importing will start after combat ends."] = "A importação começará quando o combate terminar."
L["In Party"] = "No grupo"
L["In Pet Battle"] = "Em batalha de mascotes"
L["In Range"] = "Ao alcance"
L["In War Mode"] = "No modo de guerra"
L["Include Bank"] = "Incluir banco"
L["Include Charges"] = "Incluir cargas"
L["Include Death Runes"] = "Incluir runas da morte"
L["Include Pets"] = "Incluir ajudantes"
L["Include War Band Bank"] = "Incluir banco do bando de guerra"
L["Incoming Heal"] = "Cura recebida"
L["Increase Precision Below"] = "Aumentar precisão abaixo de"
L["Increases by one per stage or intermission."] = "Aumenta em um por fase ou intervalo."
L["Information"] = "Informação"
L["Inherited"] = "Herdado"
L["Instakill"] = "Morte instantânea"
L["Install the addons BugSack and BugGrabber for detailed error logs."] = "Instale os addons BugSack e BugGrabber para obter registros de erros detalhados."
L["Instance"] = "Instância"
L["Instance Id"] = "ID da instância"
L["Instance ID"] = "ID da instância"
L["Instance Info"] = "Informações da instância"
L["Instance Name"] = "Nome da instância"
L["Instance Size Type"] = "Tipo de tamanho da instância"
L["Instance Type"] = "Tipo de instância"
L["Instructor Razuvious"] = "Instrutor Razuvious"
L["Insufficient Resources"] = "Recursos insuficientes"
L["Intellect"] = "Intelecto"
L["Interrupt"] = "Interromper"
L["Interrupt School"] = "Escola interrompida"
L["Interrupted School Text"] = "Texto da escola interrompida"
L["Interruptible"] = "Interrompível"
L["Inverse"] = "Inverso"
L["Inverse Pet Behavior"] = "Inverter comportamento do ajudante"
L["Is Away from Keyboard"] = "Está ausente do teclado"
L["Is Current Specialization"] = "É a especialização atual"
L["Is Death Rune"] = "É runa da morte"
L["Is Exactly"] = "É exatamente"
L["Is Moving"] = "Está em movimento"
L["Is Off Hand"] = "É da mão secundária"
L["Is Paragon Reputation"] = "É reputação paragon"
L["Is Paused"] = "Está pausado"
L["is useable"] = "é utilizável"
L["Is Weekly Renown Capped"] = "Renome semanal no limite"
L["Island Expedition (Heroic)"] = "Expedição às Ilhas (Heroico)"
L["Island Expedition (Mythic)"] = "Expedição às Ilhas (Mítico)"
L["Island Expedition (Normal)"] = "Expedição às Ilhas (Normal)"
L["Island Expeditions (PvP)"] = "Expedições às Ilhas (JxJ)"
L["Item Bonus Id"] = "ID de bônus do item"
L["Item Bonus Id Equipped"] = "ID de bônus do item equipado"
L["Item Id"] = "ID do item"
L["Item in Range"] = "Item ao alcance"
L["Item Name"] = "Nome do item"
L["Item Set Equipped"] = "Conjunto de itens equipado"
L["Item Set Id"] = "ID do conjunto de itens"
L["Item Slot"] = "Compartimento do item"
L["Item Slot String"] = "Texto do compartimento do item"
L["Item Type"] = "Tipo de item"
L["Jin'do the Hexxer"] = "Jin'do, o Bruxo"
L["Journal Stage"] = "Fase do diário"
L["Keep Inside"] = "Manter dentro"
L["Large"] = "Grande"
L["Latency"] = "Latência"
L["Leader"] = "Líder"
L["Least remaining time"] = "Menor tempo restante"
L["Leaving"] = "Saindo"
L["Leech (%)"] = "Sanguessuga (%)"
L["Leech Rating"] = "Índice de sanguessuga"
L["Left, then Centered Vertical"] = "Esquerda, depois vertical centralizado"
L["Left, then Down"] = "Esquerda, depois para baixo"
L["Left, then Up"] = "Esquerda, depois para cima"
L["Legacy Looking for Raid"] = "Procurar raide legado"
L["Legacy RGB Gradient"] = "Gradiente RGB legado"
L["Legacy RGB Gradient Pulse"] = "Pulso do gradiente RGB legado"
L["Length"] = "Comprimento"
L["Level"] = "Nível"
L["Limited"] = "Limitado"
L["Linear Texture"] = "Textura linear"
L["Lines & Particles"] = "Linhas e partículas"
L["Load Conditions"] = "Condições de carga"
L["Location"] = "Localização"
L["Looking for Raid"] = "Procurar raide"
L["Loop"] = "Repetir"
L["Loot"] = "Saque"
L["Loot Specialization"] = "Especialização de saque"
L["Loot Specialization Id"] = "ID da especialização de saque"
L["Loot Specialization Name"] = "Nome da especialização de saque"
L["Lord Kazzak"] = "Lorde Kazzak"
L["Lorewalking"] = "Andarilho do Conhecimento"
L["Lost"] = "Perdido"
L["Low Damage"] = "Dano baixo"
L["Lowest Spell Id"] = "Menor ID de feitiço"
L["Lua error"] = "Erro de Lua"
L["Lua error in Aura '%s': %s"] = "Erro de Lua na aura '%s': %s"
L["Main Character"] = "Personagem principal"
L["Main Stat"] = "Atributo principal"
L["Majordomo Executus"] = "Executus, o Major-domo"
L["Malformed KUIAR_Runtime link"] = "Link KUIAR_Runtime malformado"
L["Manual Icon"] = "Ícone manual"
L["Manual Rotation"] = "Rotação manual"
L["Marked First"] = "Marcado primeiro"
L["Marked Last"] = "Marcado por último"
L["Mason"] = "Pedreiro"
L["Mastery (%)"] = "Maestria (%)"
L["Mastery Rating"] = "Índice de maestria"
L["Match Count"] = "Número de correspondências"
L["Match Count per Unit"] = "Correspondências por unidade"
L["Matches (Pattern)"] = "Correspondências (padrão)"
L["Matches stage number of encounter journal.\nIntermissions are .5\nE.g. 1;2;1;2;2.5;3"] = "Corresponde ao número da fase do Diário de Encontros.\nIntervalos são .5\nEx.: 1;2;1;2;2.5;3"
L["Max Char "] = "Máx. de caracteres "
L["Max Char"] = "Máx. de caracteres"
L["Max Charges"] = "Cargas máximas"
L["Max Health"] = "Vida máxima"
L["Max Power"] = "Poder máximo"
L["Max Quantity"] = "Quantidade máxima"
L["Maximum Estimate"] = "Estimativa máxima"
L["Maximum Progress"] = "Progresso máximo"
L["Maximum time used on a single frame"] = "Tempo máximo usado em um único quadro"
L["Media"] = "Mídia"
L["Medium"] = "Média"
L["Melee"] = "Corpo a corpo"
L["Melee Haste (%)"] = "Aceleração corpo a corpo (%)"
L["Meta Data"] = "Metadados"
L["Mine"] = "Meus"
L["Minimum Estimate"] = "Estimativa mínima"
L["Minimum Progress"] = "Progresso mínimo"
L["Minus (Small Nameplate)"] = "Menos (placa de identificação pequena)"
L["Mirror"] = "Espelhar"
L["Miscellaneous"] = "Diversos"
L["Model"] = "Modelo"
L["Modern Blizzard (1h 3m | 3m 7s | 10s | 2.4)"] = "Blizzard moderno (1h 3m | 3m 7s | 10s | 2.4)"
L["Modernize"] = "Modernizar"
L["Molten Core"] = "Núcleo Derretido"
L["Money"] = "Dinheiro"
L["Monochrome"] = "Monocromático"
L["Monochrome Outline"] = "Contorno monocromático"
L["Monochrome Thick Outline"] = "Contorno grosso monocromático"
L["Monster Emote"] = "Emote de monstro"
L["Monster Party"] = "Grupo de monstros"
L["Monster Say"] = "Fala de monstro"
L["Monster Whisper"] = "Sussurro de monstro"
L["Moon"] = "Lua"
L["Most remaining time"] = "Maior tempo restante"
L["Mouse Cursor"] = "Cursor do mouse"
L["Movement Speed Rating"] = "Índice de velocidade de movimento"
L["Mythic Keystone"] = "Pedra Angular Mítica"
L["Mythic+ Affix"] = "Afixo de Mítica+"
L["Name Function"] = "Função de nome"
L["Name Function (fallback state)"] = "Função de nome (estado alternativo)"
L["Name of Caster's Target"] = "Nome do alvo do conjurador"
L["Name of the (sub-)zone currently shown above the minimap."] = "Nome da (sub)zona exibida atualmente acima do minimapa."
L["Name(s)"] = "Nome(s)"
L["Name/Realm of Caster's Target"] = "Nome/Reino do alvo do conjurador"
L["Nameplate"] = "Placa de identificação"
L["Nameplates"] = "Placas de identificação"
L["Names of affected Players"] = "Nomes dos jogadores afetados"
L["Names of unaffected Players"] = "Nomes dos jogadores não afetados"
L["Nature Resistance"] = "Resistência à natureza"
L["Next Combat"] = "Próximo combate"
L["Next Encounter"] = "Próximo encontro"
L["No active boss mod addon detected.\n\nNote: This trigger will use BigWigs or DBM, in that order if both are installed."] = "Nenhum addon de boss mod ativo detectado.\n\nObservação: este gatilho usará BigWigs ou DBM, nessa ordem, se ambos estiverem instalados."
L["No Extend"] = "Sem extensão"
L["No Profiling information saved."] = "Nenhuma informação de perfil salva."
L["No Progress Information available."] = "Nenhuma informação de progresso disponível."
L["Non-player Character"] = "Personagem não jogador"
L["Normal Party"] = "Grupo normal"
L["Not in Group"] = "Fora de grupo"
L["Not in Smart Group"] = "Fora de grupo inteligente"
L["Not on Cooldown"] = "Fora de recarga"
L["Not On Threat Table"] = "Fora da tabela de ameaça"
L["Note: Due to how complicated the swing timer behavior is and the lack of APIs from Blizzard, results are inaccurate in edge cases."] = "Observação: devido à complexidade do comportamento do temporizador de golpes e à falta de APIs da Blizzard, os resultados são imprecisos em casos extremos."
L["Note: 'Hide Alone' is not available in the new aura tracking system. A load option can be used instead."] = "Observação: 'Ocultar quando sozinho' não está disponível no novo sistema de rastreamento de auras. Use uma opção de carregamento."
L["Note: The available text replacements for multi triggers match the normal triggers now."] = "Observação: os textos de substituição disponíveis para gatilhos múltiplos agora correspondem aos dos gatilhos normais."
L["Note: This trigger internally stores the shapeshift position, and thus is incompatible with learning stances on the fly, like e.g. the Gladiator Rune."] = "Observação: este gatilho armazena internamente a posição de forma, sendo incompatível com o aprendizado de posturas na hora, como a Runa de Gladiador."
L["Note: This trigger relies on the WoW API, which returns incorrect information in some cases."] = "Observação: este gatilho depende da API do WoW, que retorna informações incorretas em alguns casos."
L["Uses UnitIsVisible() to check if game client has loaded a object for this unit. This distance is around 100 yards. This is polled every second."] = "Usa UnitIsVisible() para verificar se o cliente do jogo carregou um objeto para esta unidade. Essa distância é de cerca de 100 jardas. É consultado a cada segundo."
L["Note: This trigger type estimates the range to the hitbox of a unit. The actual range of friendly players is usually 3 yards more than the estimate. Range checking capabilities depend on your current class and known abilities as well as the type of unit being checked. Some of the ranges may also not work with certain NPCs.|n|n|cFFAAFFAAFriendly Units:|r %s|n|cFFFFAAAAHarmful Units:|r %s|n|cFFAAAAFFMiscellanous Units:|r %s"] = "Observação: este tipo de gatilho estima o alcance até a caixa de colisão de uma unidade. O alcance real de jogadores amigáveis costuma ser 3 metros maior que a estimativa. A verificação de alcance depende da sua classe atual, das habilidades conhecidas e do tipo de unidade verificada. Alguns alcances também podem não funcionar com certos PNJs.|n|n|cFFAAFFAAUnidades amigáveis:|r %s|n|cFFFFAAAAUnidades hostis:|r %s|n|cFFAAAAFFUnidades diversas:|r %s"
L["Noth the Plaguebringer"] = "Noth, o Pestífero"
L["NPC"] = "PNJ"
L["Npc ID"] = "ID de PNJ"
L["Occurrence of the event\nCan be a range of values\nCan have multiple values separated by a comma or a space\n\nExamples:\n2nd 5th and 6th events: 2, 5, 6\n2nd to 6th: 2-6\nevery 2 events: /2\nevery 3 events starting from 2nd: 2/3\nevery 3 events starting from 2nd and ending at 11th: 2-11/3\n\nWorks only if Boss Mod addon show counter"] = "Ocorrência do evento\nPode ser um intervalo de valores\nPode ter vários valores separados por vírgula ou espaço\n\nExemplos:\n2º, 5º e 6º eventos: 2, 5, 6\n2º ao 6º: 2-6\na cada 2 eventos: /2\na cada 3 eventos a partir do 2º: 2/3\na cada 3 eventos a partir do 2º até o 11º: 2-11/3\n\nFunciona apenas se o addon de boss mod mostrar o contador"
L["Occurrence of the event, reset when aura is unloaded\nCan be a range of values\nCan have multiple values separated by a comma or a space\n\nExamples:\n2nd 5th and 6th events: 2, 5, 6\n2nd to 6th: 2-6\nevery 2 events: /2\nevery 3 events starting from 2nd: 2/3\nevery 3 events starting from 2nd and ending at 11th: 2-11/3\n\nOnly if BigWigs shows it on it's bar"] = "Ocorrência do evento, reiniciada quando a aura é descarregada\nPode ser um intervalo de valores\nPode ter vários valores separados por vírgula ou espaço\n\nExemplos:\n2º, 5º e 6º eventos: 2, 5, 6\n2º ao 6º: 2-6\na cada 2 eventos: /2\na cada 3 eventos a partir do 2º: 2/3\na cada 3 eventos a partir do 2º até o 11º: 2-11/3\n\nSomente se o BigWigs mostrar na barra dele"
L["Occurrence of the event, reset when aura is unloaded\nCan be a range of values\nCan have multiple values separated by a comma or a space\n\nExamples:\n2nd 5th and 6th events: 2, 5, 6\n2nd to 6th: 2-6\nevery 2 events: /2\nevery 3 events starting from 2nd: 2/3\nevery 3 events starting from 2nd and ending at 11th: 2-11/3\n\nOnly if DBM shows it on it's bar"] = "Ocorrência do evento, reiniciada quando a aura é descarregada\nPode ser um intervalo de valores\nPode ter vários valores separados por vírgula ou espaço\n\nExemplos:\n2º, 5º e 6º eventos: 2, 5, 6\n2º ao 6º: 2-6\na cada 2 eventos: /2\na cada 3 eventos a partir do 2º: 2/3\na cada 3 eventos a partir do 2º até o 11º: 2-11/3\n\nSomente se o DBM mostrar na barra dele"
L["Offset from progress"] = "Deslocamento a partir do progresso"
L["Offset Timer"] = "Deslocar temporizador"
L["Old Blizzard (2h | 3m | 10s | 2.4)"] = "Blizzard antigo (2h | 3m | 10s | 2.4)"
L["On Cooldown"] = "Em recarga"
L["On Taxi"] = "Em rota de voo"
L["Only if on a different realm"] = "Somente se estiver em outro reino"
L["Only if Primary"] = "Somente se for primário"
L["Opaque"] = "Opaco"
L["Option Group"] = "Grupo de opções"
L["Options could not be loaded, the addon is %s"] = "Não foi possível carregar as opções, o addon está %s"
L["Options will finish loading after combat ends."] = "As opções terminarão de carregar após o fim do combate."
L["Options will open after the login process has completed."] = "As opções abrirão após a conclusão do login."
L["Or Talent"] = "Ou talento"
L["Orientation"] = "Orientação"
L["Ossirian the Unscarred"] = "Ossirian, o Intocado"
L["Other"] = "Outros"
L["Other Addons"] = "Outros addons"
L["Other Events"] = "Outros eventos"
L["Outline"] = "Contorno"
L["Over Energize"] = "Excesso de energia"
L["Overlay %s"] = "Sobreposição %s"
L["Overlay Charged Combo Points"] = "Sobrepor pontos de combo carregados"
L["Overlay Cost of Casts"] = "Sobrepor custo dos lançamentos"
L["Overlay Latency"] = "Sobrepor latência"
L["Pad"] = "Preencher"
L["Pad Mode"] = "Modo de preenchimento"
L["Pad to"] = "Preencher até"
L["Paragon Reputation"] = "Reputação paragon"
L["Paragon Reward Pending"] = "Recompensa paragon pendente"
L["Parent Frame"] = "Quadro pai"
L["Parent Zone"] = "Zona pai"
L["Parry (%)"] = "Aparar (%)"
L["Parry Rating"] = "Índice de aparar"
L["Path of Ascension: Courage"] = "Caminho da Ascensão: Coragem"
L["Path of Ascension: Humility"] = "Caminho da Ascensão: Humildade"
L["Path of Ascension: Loyalty"] = "Caminho da Ascensão: Lealdade"
L["Path of Ascension: Wisdom"] = "Caminho da Ascensão: Sabedoria"
L["Personal Resource Display"] = "Exibição de recurso pessoal"
L["Pet Behavior"] = "Comportamento do ajudante"
L["Pet Specialization"] = "Especialização do ajudante"
L["Pet Spell"] = "Feitiço do ajudante"
L["Pets only"] = "Somente ajudantes"
L["Phase"] = "Fase"
L["Pixel Glow"] = "Brilho de pixels"
L["Placement"] = "Posicionamento"
L["Placement %i"] = "Posicionamento %i"
L["Placement Mode"] = "Modo de posicionamento"
L["Play"] = "Tocar"
L["Player Effective Level"] = "Nível efetivo do jogador"
L["Player Experience"] = "Experiência do jogador"
L["Player Faction"] = "Facção do jogador"
L["Player Location ID(s)"] = "ID(s) de local do jogador"
L["Player Money"] = "Dinheiro do jogador"
L["Player Race"] = "Raça do jogador"
L["Player/Unit Info"] = "Informações do jogador/unidade"
L["Players and Pets"] = "Jogadores e ajudantes"
L["Power Deficit"] = "Déficit de poder"
L["Precision"] = "Precisão"
L["Primary Stats"] = "Atributos primários"
L["Princess Huhuran"] = "Princesa Huhuran"
L["Print Profiling Results"] = "Imprimir resultados do perfil"
L["Proc Glow"] = "Brilho de proc"
L["Profiling already started."] = "A criação de perfil já foi iniciada."
L["Profiling automatically started."] = "A criação de perfil foi iniciada automaticamente."
L["Profiling not running."] = "A criação de perfil não está em execução."
L["Profiling started."] = "Criação de perfil iniciada."
L["Profiling started. It will end automatically in %d seconds"] = "Criação de perfil iniciada. Terminará automaticamente em %d segundos"
L["Profiling still running, stop before trying to print."] = "A criação de perfil ainda está em execução, pare antes de tentar imprimir."
L["Profiling stopped."] = "Criação de perfil interrompida."
L["Progress"] = "Progresso"
L["Progress Source"] = "Fonte de progresso"
L["Progress Total"] = "Progresso total"
L["Progress Value"] = "Valor de progresso"
L["Pull"] = "Puxar"
L["PvP Mode Active"] = "Modo JxJ ativo"
L["PvP Talent selected"] = "Talento JxJ selecionado"
L["PvP Talent Selected"] = "Talento JxJ selecionado"
L["Quality Id"] = "ID de qualidade"
L["Quantity"] = "Quantidade"
L["Quantity earned this week"] = "Quantidade obtida nesta semana"
L["Quest Party"] = "Grupo de missão"
L["Queued Action"] = "Ação na fila"
L["Raid Mark"] = "Marca de raide"
L["Raid Mark Icon"] = "Ícone de marca de raide"
L["Raid Role"] = "Função no raide"
L["Raids"] = "Raides"
L["Range Check"] = "Verificação de alcance"
L["Ranged"] = "À distância"
L["Rank"] = "Grau"
L["Rare"] = "Raro"
L["Rare Elite"] = "Elite raro"
L["Rated Arena"] = "Arena ranqueada"
L["Rated Battleground"] = "Campo de batalha ranqueado"
L["Raw Threat Percent"] = "Porcentagem de ameaça bruta"
L["Razorgore the Untamed"] = "Gume Cruel, o Indomado"
L["Ready Check"] = "Verificação de prontidão"
L["Reagent Quality"] = "Qualidade do reagente"
L["Reagent Quality Texture"] = "Textura de qualidade do reagente"
L["Realm"] = "Reino"
L["Realm Name"] = "Nome do reino"
L["Realm of Caster's Target"] = "Reino do alvo do conjurador"
L["Reborn Council"] = "Conselho Renascido"
L["Receiving %s Bytes"] = "Recebendo %s bytes"
L["Receiving display information"] = "Recebendo informações de exibição"
L["Region type %s not supported"] = "Tipo de região %s não suportado"
L["Relative X-Offset"] = "Deslocamento X relativo"
L["Relative Y-Offset"] = "Deslocamento Y relativo"
L["Remaining Duration"] = "Duração restante"
L["Remove Obsolete Auras"] = "Remover auras obsoletas"
L["Renown Level"] = "Nível de renome"
L["Renown Max Level"] = "Nível máximo de renome"
L["Renown Reputation"] = "Reputação de renome"
L["Repeat"] = "Repetir"
L["Report Summary"] = "Resumo do relatório"
L["Reputation"] = "Reputação"
L["Reputation (%)"] = "Reputação (%)"
L["Requesting display information from %s ..."] = "Solicitando informações de exibição de %s ..."
L["Requires syncing the specialization via LibSpecialization."] = "Requer sincronizar a especialização via LibSpecialization."
L["Resilience (%)"] = "Resiliência (%)"
L["Resilience Rating"] = "Índice de resiliência"
L["Resistances"] = "Resistências"
L["Rested"] = "Descansado"
L["Rested Experience"] = "Experiência de descanso"
L["Rested Experience (%)"] = "Experiência de descanso (%)"
L["Resurrect Pending"] = "Ressurreição pendente"
L["Right, then Centered Vertical"] = "Direita, depois centralizado na vertical"
L["Right, then Down"] = "Direita, depois para baixo"
L["Right, then Up"] = "Direita, depois para cima"
L["Role"] = "Função"
L["Rollback snapshot is complete. Thank you for your patience!"] = "O snapshot de reversão está completo. Obrigado pela paciência!"
L["Rotate Animation"] = "Animação de rotação"
L["Rotation"] = "Rotação"
L["Round"] = "Redondo"
L["Round Mode"] = "Modo de arredondamento"
L["Ruins of Ahn'Qiraj"] = "Ruínas de Ahn'Qiraj"
L["Run Custom Code"] = "Executar código personalizado"
L["Run Speed (%)"] = "Velocidade de corrida (%)"
L["Rune #1"] = "Runa nº 1"
L["Rune #2"] = "Runa nº 2"
L["Rune #3"] = "Runa nº 3"
L["Rune #4"] = "Runa nº 4"
L["Rune #5"] = "Runa nº 5"
L["Rune #6"] = "Runa nº 6"
L["Rune Count"] = "Quantidade de runas"
L["Rune Count - Blood"] = "Quantidade de runas - Sangue"
L["Rune Count - Frost"] = "Quantidade de runas - Gelo"
L["Rune Count - Unholy"] = "Quantidade de runas - Profano"
L["Sapphiron"] = "Safira"
L["Scale"] = "Escala"
L["Scarlet Enclave"] = "Enclave Escarlate"
L["Scenario"] = "Cenário"
L["Scenario (Heroic)"] = "Cenário (Heroico)"
L["Scenario (Normal)"] = "Cenário (Normal)"
L["Screen"] = "Tela"
L["Screen/Parent Group"] = "Tela/Grupo pai"
L["Season of Discovery"] = "Temporada da Descoberta"
L["Second"] = "Segundo"
L["Second Value of Tooltip Text"] = "Segundo valor do texto da dica"
L["Secondary Stats"] = "Estatísticas secundárias"
L["Secure frame detected. Find more information:\nhttps://github.com/m33shoq/M33kAuras/wiki/Protected-Frames"] = "Quadro seguro detectado. Mais informações:\nhttps://github.com/m33shoq/M33kAuras/wiki/Protected-Frames"
L["Select Frame"] = "Selecionar quadro"
L["Select the type of timer to filter"] = "Selecione o tipo de temporizador a filtrar"
L["Selection Mode"] = "Modo de seleção"
L["Separator"] = "Separador"
L["Set IDs can be found on websites such as wowhead.com/cata/item-sets"] = "Os IDs de conjunto podem ser encontrados em sites como wowhead.com/cata/item-sets"
L["Set IDs can be found on websites such as wowhead.com/classic/item-sets"] = "Os IDs de conjunto podem ser encontrados em sites como wowhead.com/classic/item-sets"
L["Set IDs can be found on websites such as wowhead.com/forever/item-sets"] = "Os IDs de conjunto podem ser encontrados em sites como wowhead.com/forever/item-sets"
L["Set IDs can be found on websites such as wowhead.com/item-sets"] = "Os IDs de conjunto podem ser encontrados em sites como wowhead.com/item-sets"
L["Set IDs can be found on websites such as wowhead.com/mop-classic/item-sets"] = "Os IDs de conjunto podem ser encontrados em sites como wowhead.com/mop-classic/item-sets"
L["Shadow Resistance"] = "Resistência à sombra"
L["Shift-Click to resume addon execution."] = "Shift+clique para retomar a execução do addon."
L["Show CD of Charge"] = "Mostrar recarga da carga"
L["Show charged duration for empowered casts"] = "Mostrar duração carregada para lançamentos potencializados"
L["Show GCD"] = "Mostrar GCD"
L["Show Global Cooldown"] = "Mostrar tempo de recarga global"
L["Show Incoming Heal"] = "Mostrar cura recebida"
L["Show Loss of Control"] = "Mostrar perda de controle"
L["Show On"] = "Mostrar em"
L["Show Rested Overlay"] = "Mostrar sobreposição de descanso"
L["Silithid Royalty"] = "Realeza Silithid"
L["Silver"] = "Prata"
L["Since Active"] = "Desde que ativo"
L["Since Apply"] = "Desde a aplicação"
L["Since Apply/Refresh"] = "Desde a aplicação/renovação"
L["Since Charge Gain"] = "Desde o ganho de carga"
L["Since Charge Lost"] = "Desde a perda de carga"
L["Since Ready"] = "Desde que pronto"
L["Since Stack Gain"] = "Desde o ganho de acúmulo"
L["Since Stack Lost"] = "Desde a perda de acúmulo"
L["Size & Position"] = "Tamanho e posição"
L["Skyriding"] = "Pilotagem Aérea"
L["Slide Animation"] = "Animação de deslizamento"
L["Slider"] = "Controle deslizante"
L["Small"] = "Pequeno"
L["Smart Group"] = "Grupo inteligente"
L["Soft Enemy"] = "Inimigo suave"
L["Soft Friend"] = "Amigo suave"
L["Sound"] = "Som"
L["Sound by Kit ID"] = "Som por ID de Kit"
L["Source"] = "Origem"
L["Source Affiliation"] = "Afiliação da origem"
L["Source GUID"] = "GUID da origem"
L["Source Info"] = "Informações da origem"
L["Source NPC Id"] = "ID de PNJ da origem"
L["Source Object Type"] = "Tipo de objeto da origem"
L["Source Raid Mark"] = "Marca de raide da origem"
L["Source Reaction"] = "Reação da origem"
L["Source Unit Name/Realm"] = "Nome/Reino da unidade de origem"
L["Source unit's raid mark index"] = "Índice da marca de raide da unidade de origem"
L["Source unit's raid mark texture"] = "Textura da marca de raide da unidade de origem"
L["Space"] = "Espaço"
L["Spark"] = "Faísca"
L["Spec Position"] = "Posição da especialização"
L["Spec Role"] = "Função da especialização"
L["Specialization"] = "Especialização"
L["Specific Currency"] = "Moeda específica"
L["Specific Type"] = "Tipo específico"
L["Spell Activation Overlay Glow"] = "Brilho de sobreposição de ativação de feitiço"
L["Spell Cast Succeeded"] = "Lançamento de feitiço bem-sucedido"
L["Spell Cost"] = "Custo do feitiço"
L["Spell Count"] = "Contagem de feitiços"
L["Spell ID"] = "ID do feitiço"
L["Spell Id"] = "ID de feitiço"
L["Spell ID:"] = "ID de feitiço:"
L["Spell IDs:"] = "IDs de feitiço:"
L["Spell in Range"] = "Feitiço ao alcance"
L["Spell Known"] = "Feitiço conhecido"
L["Spell Penetration"] = "Penetração de feitiço"
L["Spell Peneration Percent"] = "Porcentagem de penetração de feitiço"
L["Spell Power"] = "Poder de feitiço"
L["Spell School"] = "Escola do feitiço"
L["Spell Usable"] = "Feitiço utilizável"
L["Spellname"] = "Nome do feitiço"
L["Spike"] = "Espeto"
L["Spirit"] = "Espírito"
L["Stack Count"] = "Número de acúmulos"
L["Stack trace:"] = "Rastreamento da pilha:"
L["Stacks Function"] = "Função de acúmulos"
L["Stacks Function (fallback state)"] = "Função de acúmulos (estado alternativo)"
L["Stage"] = "Fase"
L["Stage Counter"] = "Contador de fases"
L["Stagger"] = "Cambalear"
L["Stagger (%)"] = "Cambalear (%)"
L["Stagger against Target (%)"] = "Cambalear contra o alvo (%)"
L["Stagger Scale"] = "Escala de cambalear"
L["Stamina"] = "Vigor"
L["Standing"] = "Reputação"
L["Star Shake"] = "Tremor de estrela"
L["Start Animation"] = "Animação de início"
L["Start Now"] = "Iniciar agora"
L["Start Profiling"] = "Iniciar criação de perfil"
L["Status Bar"] = "Barra de status"
L["Stop"] = "Parar"
L["Stop Motion"] = "Stop motion"
L["Story Raid"] = "Raide de história"
L["Strength"] = "Força"
L["String"] = "Texto"
L["Subevent Info"] = "Informações do subevento"
L["Subtract Cast"] = "Subtrair lançamento"
L["Subtract Channel"] = "Subtrair canalização"
L["Subtract GCD"] = "Subtrair GCD"
L["Subzone Name"] = "Nome da subzona"
L["Success"] = "Sucesso"
L["Sulfuron Harbinger"] = "Arauto Sulfuron"
L["Summon Pending"] = "Invocação pendente"
L["Sun"] = "Sol"
L["Supports multiple entries, separated by commas"] = "Aceita várias entradas, separadas por vírgulas"
L["Supports multiple entries, separated by commas\n"] = "Aceita várias entradas, separadas por vírgulas\n"
L["Supports multiple entries, separated by commas. Escape ',' with \\. Prefix with '-' for negation."] = "Aceita várias entradas, separadas por vírgulas. Use \\ para escapar ','. Prefixe com '-' para negação."
L["Supports multiple entries, separated by commas. Escape with \\. Prefix with '-' for negation."] = "Aceita várias entradas, separadas por vírgulas. Use \\ para escapar. Prefixe com '-' para negação."
L["Supports multiple entries, separated by commas. Prefix with '-' for negation."] = "Aceita várias entradas, separadas por vírgulas. Prefixe com '-' para negação."
L["Supports multiple entries, separated by commas. To include child zone ids, prefix with 'c', e.g. 'c2022'.\nGroup Zone IDs must be prefixed with 'g', e.g. 'g277'.\nSupports Area IDs from https://wago.tools/db2/AreaTable prefixed with 'a'.\nSupports Instance IDs prefixed with 'i'.\nEntries can be prefixed with '-' to negate."] = "Aceita várias entradas, separadas por vírgulas. Para incluir IDs de zonas filhas, prefixe com 'c', ex.: 'c2022'.\nIDs de zonas de grupo devem ser prefixados com 'g', ex.: 'g277'.\nAceita IDs de área de https://wago.tools/db2/AreaTable prefixados com 'a'.\nAceita IDs de instância prefixados com 'i'.\nAs entradas podem ser prefixadas com '-' para negar."
L["Swipe"] = "Varredura"
L["Syntax /wa feature <toggle|on|enable|disable|off> <feature>"] = "Sintaxe /wa feature <toggle|on|enable|disable|off> <feature>"
L["System"] = "Sistema"
L["Systems"] = "Sistemas"
L["Tab "] = "Aba "
L["Talent |cFFFF0000Not|r Known"] = "Talento |cFFFF0000não|r conhecido"
L["Talent |cFFFF0000Not|r Selected"] = "Talento |cFFFF0000não|r selecionado"
L["Talent Known"] = "Talento conhecido"
L["Talent Selected"] = "Talento selecionado"
L["Talent selected"] = "Talento selecionado"
L["Tanking And Highest"] = "Tanque e maior"
L["Tanking But Not Highest"] = "Tanque, mas não o maior"
L["Targeted"] = "Alvejado"
L["Tertiary Stats"] = "Atributos terciários"
L["Test if bar is enabled in BigWigs settings"] = "Testar se a barra está ativada nas configurações do BigWigs"
L["Test if bar is enabled in Boss Mod addon settings"] = "Testar se a barra está ativada nas configurações do addon de boss mod"
L["Test if bar is enabled in DBM settings"] = "Testar se a barra está ativada nas configurações do DBM"
L["Text To Speech"] = "Texto para fala"
L["Text-to-speech"] = "Texto para fala"
L["Texture"] = "Textura"
L["Texture Function"] = "Função de textura"
L["Texture Function (fallback state)"] = "Função de textura (estado alternativo)"
L["Texture Picker"] = "Seletor de textura"
L["Texture Rotation"] = "Rotação da textura"
L["The aura has overwritten the global '%s', this might affect other auras."] = "A aura sobrescreveu o global '%s'; isso pode afetar outras auras."
L["The aura tried to overwrite the aura_env global, which is not allowed."] = "A aura tentou sobrescrever o global aura_env, o que não é permitido."
L["The effective level differs from the level in e.g. Time Walking dungeons."] = "O nível efetivo difere do nível em masmorras como as de Caminhada no Tempo."
L["The Four Horsemen"] = "Os Quatro Cavaleiros"
L["The 'ID' value can be found in the BigWigs options of a specific spell"] = "O valor de 'ID' pode ser encontrado nas opções do BigWigs de um feitiço específico"
L["The Prophet Skeram"] = "O Profeta Skeram"
L["The total quantity a warband character can transfer after paying the transfer cost"] = "A quantidade total que um personagem do bando de guerra pode transferir após pagar o custo de transferência"
L["The total quantity after transferring everything to your current character and paying the transfer cost"] = "A quantidade total após transferir tudo para o seu personagem atual e pagar o custo de transferência"
L["There are %i updates to your auras ready to be installed!"] = "Há %i atualizações das suas auras prontas para instalar!"
L["Thick Outline"] = "Contorno grosso"
L["Thickness"] = "Espessura"
L["Third"] = "Terceiro"
L["Third Value of Tooltip Text"] = "Terceiro valor do texto da dica"
L["This aura calls GetData a lot, which is a slow function."] = "Esta aura chama GetData muitas vezes, uma função lenta."
L["This aura has caused a Lua error."] = "Esta aura causou um erro de Lua."
L["This aura is saving %s KB of data"] = "Esta aura está salvando %s KB de dados"
L["This aura plays a sound via a condition."] = "Esta aura toca um som por meio de uma condição."
L["This aura plays a sound via an action."] = "Esta aura toca um som por meio de uma ação."
L["This aura plays a Text To Speech via a condition."] = "Esta aura reproduz um texto para fala por meio de uma condição."
L["This aura plays a Text To Speech via an action."] = "Esta aura reproduz um texto para fala por meio de uma ação."
L["Threat Percent"] = "Porcentagem de ameaça"
L["Threat Value"] = "Valor de ameaça"
L["Tick"] = "Marca"
L["Time"] = "Tempo"
L["Time Format"] = "Formato de tempo"
L["Time in GCDs"] = "Tempo em GCDs"
L["Time since initial application"] = "Tempo desde a aplicação inicial"
L["Time since last refresh"] = "Tempo desde a última renovação"
L["Time since stack gain"] = "Tempo desde o ganho de acúmulo"
L["Time since stack lost"] = "Tempo desde a perda de acúmulo"
L["Timed Progress"] = "Progresso cronometrado"
L["Timer"] = "Cronômetro"
L["Timer Id"] = "ID do temporizador"
L["Toggle"] = "Alternar"
L["Toggle List"] = "Alternar lista"
L["Toggle Options Window"] = "Alternar janela de opções"
L["Toggle Performance Profiling Window"] = "Alternar janela de criação de perfil de desempenho"
L["Tooltip"] = "Dica"
L["Tooltip 1"] = "Dica 1"
L["Tooltip 2"] = "Dica 2"
L["Tooltip 3"] = "Dica 3"
L["Tooltip Value 1"] = "Valor da dica 1"
L["Tooltip Value 2"] = "Valor da dica 2"
L["Tooltip Value 3"] = "Valor da dica 3"
L["Tooltip Value 4"] = "Valor da dica 4"
L["Total Duration"] = "Duração total"
L["Total Earned in this Season"] = "Total obtido nesta temporada"
L["Total Essence"] = "Essência total"
L["Total Experience"] = "Experiência total"
L["Total Match Count"] = "Total de correspondências"
L["Total Reputation"] = "Reputação total"
L["Total Stacks"] = "Total de acúmulos"
L["Total stacks over all matches"] = "Total de acúmulos em todas as correspondências"
L["Total Stages"] = "Total de fases"
L["Total Unit Count"] = "Total de unidades"
L["Total Units"] = "Total de unidades"
L["Totem #%i"] = "Totem nº %i"
L["Totem Icon"] = "Ícone do totem"
L["Totem Name Pattern Match"] = "Correspondência de padrão do nome do totem"
L["Totem Number"] = "Número do totem"
L["Track Cooldowns"] = "Rastrear tempos de recarga"
L["Tracking Charge %i"] = "Rastreando carga %i"
L["Tracking Charge CDs"] = "Rastreando recarga das cargas"
L["Tracking Only Cooldown"] = "Rastreando somente tempo de recarga"
L["Trigger %s"] = "Gatilho %s"
L["Trigger State Updater (Advanced)"] = "Atualizador de estado do gatilho (avançado)"
L["Trivial (Low Level)"] = "Trivial (nível baixo)"
L["True"] = "Verdadeiro"
L["Trying to repair broken conditions in %s likely caused by a KUIAR_Runtime bug."] = "Tentando reparar condições quebradas em %s, provavelmente causadas por um bug do KUIAR_Runtime."
L["Twin Emperors"] = "Imperadores Gêmeos"
L["Unable to modernize aura '%s'. This is probably due to corrupt data or a bad migration, please report this to m33shoq."] = "Não foi possível modernizar a aura '%s'. Provavelmente por dados corrompidos ou uma migração ruim; informe isso a m33shoq."
L["Unaffected"] = "Não afetado"
L["Unholy"] = "Profano"
L["Unholy Rune #1"] = "Runa profana nº 1"
L["Unholy Rune #2"] = "Runa profana nº 2"
L["Unit Dissipates"] = "A unidade se dissipa"
L["Unit Frame"] = "Quadro de unidade"
L["Unit Frames"] = "Quadros de unidade"
L["Unit is Unit"] = "Unidade é Unidade"
L["Unit Name"] = "Nome da unidade"
L["Unit Name/Realm"] = "Nome/Reino da unidade"
L["Units Affected"] = "Unidades afetadas"
L["Units of affected Players in a table format"] = "Unidades dos jogadores afetados em formato de tabela"
L["Units of unaffected Players in a table format"] = "Unidades dos jogadores não afetados em formato de tabela"
L["Unknown action %q"] = "Ação desconhecida %q"
L["Unknown feature %q"] = "Recurso desconhecido %q"
L["unknown location"] = "local desconhecido"
L["Unlimited"] = "Ilimitado"
L["Untrigger %s"] = "Desacionar %s"
L["Up, then Centered Horizontal"] = "Para cima, depois centralizado na horizontal"
L["Up, then Left"] = "Para cima, depois à esquerda"
L["Up, then Right"] = "Para cima, depois à direita"
L["Update Position"] = "Atualizar posição"
L["Usage:"] = "Uso:"
L["Use /wa minimap to show the minimap icon again."] = "Use /wa minimap para mostrar o ícone do minimapa novamente."
L["Use Custom Color"] = "Usar cor personalizada"
L["Use Legacy floor rounding"] = "Usar arredondamento para baixo legado"
L["Use Texture"] = "Usar textura"
L["Use Watched Faction"] = "Usar facção acompanhada"
L["Uses UnitInRange() to check if in range. Matches default raid frames out of range behavior, which is between 25 to 40 yards depending on your class and spec."] = "Usa UnitInRange() para verificar se está ao alcance. Corresponde ao comportamento padrão dos quadros de raide fora de alcance, que fica entre 25 e 40 jardas dependendo da sua classe e especialização."
L["Using KUIAR_Runtime.clones is deprecated. Use KUIAR_Runtime.GetRegion(id, cloneId) instead."] = "Usar KUIAR_Runtime.clones está obsoleto. Use KUIAR_Runtime.GetRegion(id, cloneId)."
L["Using KUIAR_Runtime.regions is deprecated. Use KUIAR_Runtime.GetRegion(id) instead."] = "Usar KUIAR_Runtime.regions está obsoleto. Use KUIAR_Runtime.GetRegion(id)."
L["Vaelastrasz the Corrupt"] = "Vaelastrasz, o Corrupto"
L["Versatility (%)"] = "Versatilidade (%)"
L["Versatility Rating"] = "Índice de versatilidade"
L["Visibility"] = "Visibilidade"
L["Visions of N'Zoth"] = "Visões de N'Zoth"
L["Warband Quantity Total"] = "Quantidade total do bando de guerra"
L["Warband Transfer Percentage"] = "Porcentagem de transferência do bando de guerra"
L["Warband Transferred Quantity"] = "Quantidade transferida do bando de guerra"
L["Warfront (Heroic)"] = "Frente de guerra (Heroico)"
L["Warfront (Normal)"] = "Frente de guerra (Normal)"
L["Warning"] = "Aviso"
L["Warning for unknown aura:"] = "Aviso de aura desconhecida:"
L["Warning: Anchoring in aura '%s' is imposssible, due to an anchoring cycle"] = "Aviso: a ancoragem na aura '%s' é impossível devido a um ciclo de ancoragem"
L["Warning: Full Scan auras checking for both name and spell id can't be converted."] = "Aviso: auras de Varredura completa que verificam nome e ID de feitiço ao mesmo tempo não podem ser convertidas."
L["Warning: Name info is now available via %affected, %unaffected. Number of affected group members via %unitCount. Some options behave differently now. This is not automatically adjusted."] = "Aviso: as informações de nome agora estão disponíveis via %affected, %unaffected. O número de membros do grupo afetados via %unitCount. Algumas opções agora se comportam de forma diferente. Isso não é ajustado automaticamente."
L["Warning: Tooltip values are now available via %tooltip1, %tooltip2, %tooltip3 instead of %s. This is not automatically adjusted."] = "Aviso: os valores da dica agora estão disponíveis via %tooltip1, %tooltip2, %tooltip3 em vez de %s. Isso não é ajustado automaticamente."
L["KUIAR_Engine Built-In (63:42 | 3:07 | 10 | 2.4)"] = "KUIAR_Engine integrado (63:42 | 3:07 | 10 | 2.4)"
L["KUIAR_Runtime has detected that it has been downgraded.\nYour saved auras may no longer work properly.\nWould you like to run the |cffff0000EXPERIMENTAL|r repair tool? This will overwrite any changes you have made since the last database upgrade.\nLast upgrade: %s\n\n|cffff0000You should BACKUP your WTF folder BEFORE pressing this button.|r"] = "O KUIAR_Runtime detectou que foi revertido para uma versão anterior.\nSuas auras salvas podem não funcionar mais corretamente.\nDeseja executar a ferramenta de reparo |cffff0000EXPERIMENTAL|r? Isso sobrescreverá quaisquer alterações feitas desde a última atualização do banco de dados.\nÚltima atualização: %s\n\n|cffff0000Faça BACKUP da sua pasta WTF ANTES de pressionar este botão.|r"
L["KUIAR_Engine is creating a rollback snapshot of your auras. This snapshot will allow you to revert to the current state of your auras if something goes wrong. This process may cause your framerate to drop until it is complete."] = "O KUIAR_Engine está criando um instantâneo de reversão das suas auras. Esse instantâneo permitirá voltar ao estado atual das auras se algo der errado. Esse processo pode reduzir sua taxa de quadros até terminar."
L["KUIAR_Engine Profiling"] = "Criação de perfil do KUIAR_Engine"
L["KUIAR_Engine Profiling Report"] = "Relatório de criação de perfil do KUIAR_Engine"
L["KUIAR_Engine Version: %s"] = "Versão do KUIAR_Engine: %s"
L["Weapon Enchant"] = "Encantamento de arma"
L["Weapon Enchant / Fishing Lure"] = "Encantamento de arma / Isca de pesca"
L["World Boss"] = "Chefe mundial"
L["World Bosses"] = "Chefes mundiais"
L["Wrap"] = "Quebra"
L["Writing to the KUIAR_Runtime table is not allowed."] = "Gravar na tabela KUIAR_Runtime não é permitido."
L["X-Offset"] = "Deslocamento X"
L["Y-Offset"] = "Deslocamento Y"
L["You have new auras ready to be installed!"] = "Há novas auras prontas para instalar!"
L["Your next encounter will automatically be profiled."] = "Seu próximo encontro terá o perfil criado automaticamente."
L["Your next instance of combat will automatically be profiled."] = "Seu próximo combate terá o perfil criado automaticamente."
L["Your scheduled automatic profile has been cancelled."] = "Seu perfil automático agendado foi cancelado."
L["Your threat as a percentage of the tank's current threat."] = "Sua ameaça como porcentagem da ameaça atual do tanque."
L["Your threat on the mob as a percentage of the amount required to pull aggro. Will pull aggro at 100."] = "Sua ameaça no monstro como porcentagem da quantidade necessária para puxar a atenção. Puxará a atenção com 100."
L["Your total threat on the mob."] = "Sua ameaça total no monstro."
L["Zone Group ID"] = "ID do grupo de zonas"
L["Zone ID"] = "ID da zona"
L["Zoom Animation"] = "Animação de zoom"

end)
