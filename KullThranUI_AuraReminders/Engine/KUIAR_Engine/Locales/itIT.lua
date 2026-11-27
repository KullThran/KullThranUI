-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_Engine", function(...)
if (GAME_LOCALE or GetLocale()) ~= "itIT" then
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
L["%s Overlay Color"] = "%s Colore Overlay"
L["* Suffix"] = "* Suffisso"
L["/wa help - Show this message"] = "/wa help - Mostra questo messaggio"
L["/wa minimap - Toggle the minimap icon"] = "/wa minimap - Mostra/Nascondi l'icona della minimappa"
L["/wa pprint - Show the results from the most recent profiling"] = "/wa pprint - Mostra i risultati del più recente profiling"
L["/wa pstart - Start profiling. Optionally include a duration in seconds after which profiling automatically stops. To profile the next combat/encounter, pass a \"combat\" or \"encounter\" argument."] = "/wa pstart - Inizia il profiling. Si può includere una durata in secondi dopo la quale il profiling termina automaticamente. Per profilare il prossimo combattimento, passare un argomento ''combat'' o ''encounter''."
L["/wa pstop - Finish profiling"] = "/wa pstop - Termina il profiling"
L["/wa repair - Repair tool"] = "/wa riparazione - Strumento di riparazione"
L["|cffeda55fLeft-Click|r to toggle showing the main window."] = "|cffeda55fClick Sinistro|r per mostrare/nascondere la finestra principale."
L["|cffeda55fMiddle-Click|r to toggle the minimap icon on or off."] = "|cffeda55fClick Centrale|r per mostrare/nascondere l'icona della minimappa."
L["|cffeda55fRight-Click|r to toggle performance profiling window."] = "|cffeda55fFare clic con il pulsante destro del mouse|r per attivare/disattivare la finestra di profilazione delle prestazioni."
L["|cffeda55fShift-Click|r to pause addon execution."] = "|cffeda55fShift Click|r per mettere in pausa l'addon."
--[[Translation missing --]]
L["|cffff0000deprecated|r"] = "|cffff0000deprecated|r"
L["|cFFFF0000Not|r Item Bonus Id Equipped"] = "|cFFFF0000Not|r Bonus Id oggetto equipaggiato"
L["|cFFFF0000Not|r Item Equipped"] = "|cFFFF0000Not|r Oggetto Equipaggiato "
L["|cFFFF0000Not|r Player Name/Realm"] = "|cFFFF0000Not|r Nome Giocatore/Reame"
L["|cFFFF0000Not|r Spell Known"] = "|cFFFF0000Not|r Incantesimo Conosciuto"
--[[Translation missing --]]
L[ [=[|cFFFF0000Support for unfiltered COMBAT_LOG_EVENT_UNFILTERED is deprecated|r
COMBAT_LOG_EVENT_UNFILTERED without a filter are disabled as it’s very performance costly.
Find more information:
https://github.com/m33shoq/M33kAuras/wiki/Custom-Triggers#events]=] ] = [=[|cFFFF0000Support for unfiltered COMBAT_LOG_EVENT_UNFILTERED is deprecated|r
COMBAT_LOG_EVENT_UNFILTERED without a filter are disabled as it’s very performance costly.
Find more information:
https://github.com/m33shoq/M33kAuras/wiki/Custom-Triggers#events]=]
L["|cFFffcc00Extra Options:|r %s"] = "|cFFffcc00Opzioni Extra:|r %s"
L["|cFFffcc00Extra Options:|r None"] = "|cFFffcc00Opzioni Extra:|r Nessuna"
L[ [=[• |cff00ff00Player|r, |cff00ff00Target|r, |cff00ff00Focus|r, and |cff00ff00Pet|r correspond directly to those individual unitIDs.
• |cff00ff00Specific Unit|r lets you provide a specific valid unitID to watch.
|cffff0000Note|r: The game will not fire events for all valid unitIDs, making some untrackable by this trigger.
• |cffffff00Party|r, |cffffff00Raid|r, |cffffff00Boss|r, |cffffff00Arena|r, and |cffffff00Nameplate|r can match multiple corresponding unitIDs.
• |cffffff00Smart Group|r adjusts to your current group type, matching just the "player" when solo, "party" units (including "player") in a party or "raid" units in a raid.

|cffffff00*|r Yellow Unit settings will create clones for each matching unit while this trigger is providing Dynamic Info to the Aura.]=] ] = "• |cff00ff00Player|r, |cff00ff00Target|r, |cff00ff00Focus|r e |cff00ff00Pet|r corrispondono direttamente a quei singoli unitID.  • |cff00ff00Unità specifica|r consente di fornire uno specifico ID unità valido da guardare.  |cffff0000Nota|r: il gioco non attiverà eventi per tutti gli unitID validi, rendendone alcuni non tracciabili da questa attivazione.  • |cffffff00Party|r, |cffffff00Raid|r, |cffffff00Boss|r, |cffffff00Arena|r e |cffffff00Nameplate|r possono corrispondere a più ID unità corrispondenti.  • |cffffff00Smart Group|r si adatta al tipo di gruppo corrente, abbinando solo il \"giocatore\" in modalità solista, le unità \"party\" (incluso il \"giocatore\") in un party o le unità \"raid\" in un raid.  |cffffff00*|r Le impostazioni dell'unità gialla creeranno cloni per ciascuna unità corrispondente mentre questa attivazione fornisce informazioni dinamiche all'aura."
L["1. Profession 1. Accessory"] = "1. Professione 1. Accessorio"
L["1. Profession 2. Accessory"] = "1. Professione 2. Accessorio"
L["1. Professsion Tool"] = "1. Strumento Professione "
L["10 Man Raid"] = "Incursione da 10 giocatori"
L["10 Player Raid"] = "Raid da 10 giocatori"
L["10 Player Raid (Heroic)"] = "Raid da 10 giocatori (Eroico)"
L["10 Player Raid (Normal)"] = "Raid da 10 giocatori (Normale)"
L["2. Profession 1. Accessory"] = "2. Professione 1. Accessorio"
L["2. Profession 2. Accessory"] = "2. Professione 2. Accessorio"
L["2. Professsion Tool"] = "2. Strumento Professione"
L["20 Man Raid"] = "incursione da 20 giocatori"
L["20 Player Raid"] = "Raid da 20 giocatori"
L["25 Man Raid"] = "Incursione da 25 giocatori"
L["25 Player Raid"] = "Raid da 25 giocatori"
L["25 Player Raid (Heroic)"] = "Raid da 25 giocatori (Eroico)"
L["25 Player Raid (Normal)"] = "Raid da 25 giocatori (Normale)"
L["40 Man Raid"] = "incursione da 40 giocatori"
L["40 Player Raid"] = "Raid da 40 giocatori"
L["5 Man Dungeon"] = "Spedizione da 5 giocatori"
--[[Translation missing --]]
L["A trigger in this aura is set up to track a soft target unit, but you don't have the CVars set up for this to work correctly. Consider either changing the unit tracked, or configuring the Soft Target CVars."] = "A trigger in this aura is set up to track a soft target unit, but you don't have the CVars set up for this to work correctly. Consider either changing the unit tracked, or configuring the Soft Target CVars."
L["Abbreviate"] = "Abbreviare"
L["AbbreviateLargeNumbers (Blizzard)"] = "AbbreviareGrandiNumeri (Blizzard)"
L["AbbreviateNumbers (Blizzard)"] = "Abbreviare i numeri (Blizzard)"
L["Absorb"] = "Assorbimento"
--[[Translation missing --]]
L["Absorb and Healing"] = "Absorb and Healing"
L["Absorb Heal Overlay"] = "Assorbe la copertura di guarigione"
--[[Translation missing --]]
L["Absorb Overlay"] = "Absorb Overlay"
L["Absorbed"] = "Assorbito"
L["Action Button Glow"] = "Bagliore Pulsante Azioni"
L["Actions"] = "Azioni"
L["Active"] = "Attivo"
L[ [=[Active boss mod addon: |cFFffcc00BigWigs|r

Note: This trigger will use BigWigs or DBM, in that order if both are installed.]=] ] = "Componente aggiuntivo mod boss attivo: |cFFffcc00BigWigs|r Nota: Questa attivazione utilizzerà BigWigs o DBM, in quest'ordine se entrambi sono installati."
L[ [=[Active boss mod addon: |cFFffcc00DBM|r

Note: This trigger will use BigWigs or DBM, in that order if both are installed.]=] ] = "Componente aggiuntivo mod boss attivo: |cFFffcc00DBM|r Nota: questa attivazione utilizzerà BigWigs o DBM, in quest'ordine se entrambi sono installati."
L["Add"] = "Aggiungi"
L["Add Missing Auras"] = "Aggiungi Aure Mancanti"
L["Advanced Caster's Target Check"] = "Controllo del bersaglio dell'incantatore avanzato"
L["Affected"] = "Affetto"
L["Affected Unit Count"] = "Conta Unità Interessate"
--[[Translation missing --]]
L["Afk"] = "Afk"
L["Aggro"] = "Aggro"
L["Agility"] = "Agilità"
L["Ahn'Qiraj"] = "Ahn'Qiraj"
L["Alert Type"] = "Tipo di Allerta"
L["Alive"] = "Vivo"
L["All"] = "Tutto"
L["All children of this aura will also not be loaded, to minimize the chance of further corruption."] = "Anche tutti i bambini di quest'aura non verranno caricati, per ridurre al minimo la possibilità di ulteriore corruzione."
--[[Translation missing --]]
L["All States table contains a non table at key: '%s'."] = "All States table contains a non table at key: '%s'."
L["All Triggers"] = "Tutte le attivazioni"
L["Alliance"] = "Alleanza"
L["Allow partial matches"] = "Permetti corrispondenze parziali"
L["Alpha"] = "Alfa"
L["Alternate Power"] = "Risorse Speciali"
L["Always"] = "Sempre"
L["Always active trigger"] = "Innesco sempre attivo"
L["Always include realm"] = "Includi sempre il reame"
L["Always True"] = "Sempre Vero"
L["Amount"] = "Quantità"
L["Anchoring"] = "Ancoraggio"
L["And Talent"] = "E Talento "
L["Angle and Radius"] = "Angolo e Raggio"
L["Animations"] = "Animazioni"
L["Anticlockwise"] = "Antiorario"
--[[Translation missing --]]
L["Anub'Rekhan"] = "Anub'Rekhan"
L["Any"] = "Qualsiasi"
L["Any Triggers"] = "Qualsiasi attivazione"
--[[Translation missing --]]
L["AOE"] = "AOE"
L["Arcane Resistance"] = "Resistenza Arcana"
L[ [=[Are you sure you want to run the |cffff0000EXPERIMENTAL|r repair tool?
This will overwrite any changes you have made since the last database upgrade.
Last upgrade: %s]=] ] = "Vuoi eseguire lo strumento di riparazione |cffff0000EXPERIMENTAL|r? Ciò sovrascriverà tutte le modifiche apportate dall'ultimo aggiornamento del database. Ultimo aggiornamento: %s"
L["Arena"] = "Arena"
L["Armor (%)"] = "Armatura (%)"
L["Armor against Target (%)"] = "Armatura contro il bersaglio (%)"
--[[Translation missing --]]
L["Armor Peneration Percent"] = "Armor Peneration Percent"
--[[Translation missing --]]
L["Armor Peneration Rating"] = "Armor Peneration Rating"
L["Armor Rating"] = "Grado di armatura"
--[[Translation missing --]]
L["Array"] = "Array"
L["Ascending"] = "Crescente"
L["Assigned Role"] = "Ruolo assegnato"
L["Assigned Role Icon"] = "Icona del ruolo assegnato"
--[[Translation missing --]]
L["Assist"] = "Assist"
--[[Translation missing --]]
L["Assisted Combat Next Cast"] = "Assisted Combat Next Cast"
L["At Least One Enemy"] = "Almeno un nemico"
L["At missing Value"] = "Al valore mancante"
L["At Percent"] = "In Percentuale"
L["At Value"] = "Al valore"
L["At War"] = "In guerra"
L["Attach to End"] = "Aggiungi alla Fine"
--[[Translation missing --]]
L["Attach to End, backwards"] = "Attach to End, backwards"
--[[Translation missing --]]
L["Attach to Point"] = "Attach to Point"
L["Attach to Start"] = "Aggiungi all'inizio"
L["Attack Power"] = "Potenza d'attacco"
L["Attackable"] = "Attaccabile"
L["Attackable Target"] = "Bersaglio attaccabile"
L["Aura"] = "Aura"
--[[Translation missing --]]
L["Aura '%s': %s"] = "Aura '%s': %s"
L["Aura Applied"] = "Aura applicata"
L["Aura Applied Dose"] = "Parte di aura applicata"
L["Aura Broken"] = "Aura finita"
L["Aura Broken Spell"] = "Aura di magia finita"
L["Aura is using deprecated SetDurationInfo"] = "Aura utilizza SetDurationInfo deprecato"
L["Aura loaded"] = "Aura caricata"
L["Aura Name"] = "Nome Aura"
L["Aura Names"] = "Nomi Aura"
L["Aura Refresh"] = "Aura rinnovata"
L["Aura Removed"] = "Aura rimossa"
L["Aura Removed Dose"] = "Parte di aura rimossa"
L["Aura Stack"] = "Aura Stack"
L["Aura Type"] = "Tipo di aura"
L["Aura Version: %s"] = "Versione dell'aura: %s"
L["Aura(s) Found"] = "Aura(e) Trovata(e)"
L["Aura(s) Missing"] = "Aura(e) Mancante(i)"
L["Aura:"] = "Aura:"
L["Auras"] = "Aure"
L["Auras:"] = "Aure:"
L["Author Options"] = "Opzioni Autore"
--[[Translation missing --]]
L["Auto"] = "Auto"
--[[Translation missing --]]
L["Autocast Shine"] = "Autocast Shine"
L["Automatic"] = "Automatico"
L["Automatic Length"] = "Lunghezza Automatica"
L["Automatic Rotation"] = "Rotazione Automatica"
L["Available features: %s"] = "Funzionalità disponibili: %s"
L["Avoidance (%)"] = "Elusione (%)"
L["Avoidance Rating"] = "Grado di Elusione"
L["Ayamiss the Hunter"] = "Ayamiss il Cacciatore"
--[[Translation missing --]]
L["Azuregos"] = "Azuregos"
L["Back and Forth"] = "Avanti e indietro"
L["Background"] = "Sfondo"
L["Background Color"] = "Colore Sfondo"
--[[Translation missing --]]
L["Balnazzar"] = "Balnazzar"
L["Bar Color/Gradient Start"] = "Inizio Colore/Inclinazione della Barra"
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
L["Baron Geddon"] = "Barone Geddon"
--[[Translation missing --]]
L["Battle for Azeroth"] = "Battle for Azeroth"
L["Battle.net Whisper"] = "Sussurri di Battle.net"
L["Battleground"] = "Campo di battaglia"
L["Battleguard Sartura"] = "Guardia di battaglia Sartura"
--[[Translation missing --]]
L["Beastmaster"] = "Beastmaster"
--[[Translation missing --]]
L["Beatrix"] = "Beatrix"
--[[Translation missing --]]
L["BG>Raid>Party>Say"] = "BG>Raid>Party>Say"
--[[Translation missing --]]
L["BG-System Alliance"] = "BG-System Alliance"
--[[Translation missing --]]
L["BG-System Horde"] = "BG-System Horde"
--[[Translation missing --]]
L["BG-System Neutral"] = "BG-System Neutral"
L["Big Number"] = "Grande Numero"
L["BigWigs Addon"] = "BigWigs Add-on"
L["BigWigs Message"] = "Messaggio di BigWigs"
--[[Translation missing --]]
L["BigWigs Stage"] = "BigWigs Stage"
L["BigWigs Timer"] = "Timer di BigWigs"
L["Black Wing Lair"] = "Sotterranei dell'Ala Nera"
--[[Translation missing --]]
L["Bleed"] = "Bleed"
L["Blizzard Combat Text"] = "Testo di combattimento Blizzard"
L["Blizzard Cooldown Reduction"] = "Riduzione Cooldown Blizzard"
L["Block"] = "Bloccare"
L["Block (%)"] = "Blocco (%)"
L["Block against Target (%)"] = "Blocco rispetto al target (%)"
L["Block Value"] = "Valore di Blocco"
L["Blocked"] = "Bloccato"
L["Blood"] = "Sangue"
L["Blood Rune #1"] = "Runa del sangue n. 1"
L["Blood Rune #2"] = "Runa del sangue n.2"
L["Bloodlord Mandokir"] = "Signore del Sangue Mandokir"
L["Bonus Reputation Gain"] = "Guadagno di reputazione bonus"
L["Border"] = "Bordo"
L["Boss"] = "Boss"
L["Boss Emote"] = "Boss Emote"
--[[Translation missing --]]
L["Boss Mod Announce"] = "Boss Mod Announce"
--[[Translation missing --]]
L["Boss Mod Stage"] = "Boss Mod Stage"
--[[Translation missing --]]
L["Boss Mod Stage (Event)"] = "Boss Mod Stage (Event)"
--[[Translation missing --]]
L["Boss Mod Timer"] = "Boss Mod Timer"
--[[Translation missing --]]
L["Boss Whisper"] = "Boss Whisper"
L["Bottom"] = "Basso"
L["Bottom Left"] = "Basso a sinistra"
L["Bottom Right"] = "Basso a destra"
L["Bottom to Top"] = "Basso verso l'alto"
L["Bounce"] = "Balzo"
L["Bounce with Decay"] = "Bounce with Decay"
--[[Translation missing --]]
L["Break"] = "Break"
--[[Translation missing --]]
L["BreakUpLargeNumbers (Blizzard)"] = "BreakUpLargeNumbers (Blizzard)"
L["Broodlord Lashlayer"] = "Signore della Progenie Lashlayer"
L["Buff"] = "Buff"
--[[Translation missing --]]
L["Buff/Debuff"] = "Buff/Debuff"
L["Buffed/Debuffed"] = "Buffato/Debuffato"
--[[Translation missing --]]
L["Burning Crusade"] = "Burning Crusade"
--[[Translation missing --]]
L["Buru the Gorger"] = "Buru the Gorger"
--[[Translation missing --]]
L["Caldoran"] = "Caldoran"
L["Callback function"] = "Funzione di richiamata"
L["Can be used for e.g. checking if \"boss1target\" is the same as \"player\"."] = "Può essere usato per esempio per controllare se \"boss1target\" sia uguale a \"player\"."
L["Cancel"] = "Cancella"
L[ [=[Cannot change secure frame in combat lockdown. Find more information:
https://github.com/m33shoq/M33kAuras/wiki/Protected-Frames]=] ] = "Non è possibile modificare il frame protetto durante il blocco del combattimento. Trova ulteriori informazioni: https://github.com/m33shoq/M33kAuras/wiki/Protected-Frames"
L["Can't schedule timer with %i, due to a World of Warcraft bug with high computer uptime. (Uptime: %i). Please restart your computer."] = "Impossibile programmare il timer con %i, a causa di un bug di World of Warcraft con tempi di attività elevati del computer.  (Tempo di attività: %i).  Riavvia il computer."
L["Capped"] = "Limitato"
L["Capped at Season Max"] = "Limitato alla stagione massima"
L["Capped at Weekly Max"] = "Limitato al massimo settimanale"
L["Cast"] = "Cast"
L["Cast Bar"] = "Barra del cast"
L["Cast Failed"] = "Cast fallito"
L["Cast Start"] = "Inizio cast"
L["Cast Success"] = "Cast terminato con successo"
L["Cast Type"] = "Tipo di cast"
--[[Translation missing --]]
L["Caster"] = "Caster"
L["Caster Name"] = "Nome del Caster"
L["Caster Realm"] = "Reame del Caster"
L["Caster Unit"] = "Unità del Caster"
L["Casters Name/Realm"] = "Nome/Reame dei Caster"
L["Caster's Target"] = "Bersaglio dei Caster"
--[[Translation missing --]]
L["Cataclysm"] = "Cataclysm"
--[[Translation missing --]]
L["Ceil"] = "Ceil"
L["Center"] = "Centro"
L["Center, then alternating bottom and top"] = "Al centro, poi alternando il basso e l'alto"
L["Center, then alternating left and right"] = "Al centro, poi alternando sinistra e destra"
L["Center, then alternating right and left"] = "Al centro, poi alternando destra e sinistra"
L["Center, then alternating top and bottom"] = "Al centro, poi alternando la parte superiore e quella inferiore"
L["Centered Horizontal"] = "Centrato orizzontalmente"
L["Centered Horizontal, then Centered Vertical"] = "Centrato orizzontalmente, poi centrato verticalmente"
L["Centered Horizontal, then Down"] = "Centrato orizzontalmente, poi in basso"
L["Centered Horizontal, then Up"] = "Centrato orizzontalmente, poi in alto"
L["Centered Vertical"] = "Centrato verticalmente"
L["Centered Vertical, then Centered Horizontal"] = "Centrato verticalmente, poi centrato orizzontalmente "
L["Centered Vertical, then Left"] = "Centrato verticalmente, poi a sinistra"
L["Centered Vertical, then Right"] = "Centrato verticalmente, poi a destra"
L["Changed"] = "Modificato"
L["Channel"] = "Canale"
L["Channel (Spell)"] = "Canale (Magia)"
--[[Translation missing --]]
L["Character GUID"] = "Character GUID"
--[[Translation missing --]]
L["Character Name"] = "Character Name"
L["Character Stats"] = "Statistiche del Personaggio "
--[[Translation missing --]]
L["Character Transferred Quantity"] = "Character Transferred Quantity"
L["Character Type"] = "Tipo di carattere"
L["Charge gained/lost"] = "Carica guadagnata/persa"
--[[Translation missing --]]
L["Charged Combo Points"] = "Charged Combo Points"
L["Charges"] = "Cariche"
L["Charges Changed Event"] = "Evento modificato caricato"
L["Charging"] = "In carica"
L["Chat Frame"] = "Cornice di chat"
L["Chat Message"] = "Messaggio di chat"
L["Check if a single talent match a Rank"] = "Controlla se un singolo talento corrisponde a un grado"
L["Check nameplate's target every 0.2s"] = "Controllare le barre del bersaglio ogni 0,2 s"
--[[Translation missing --]]
L["Chromaggus"] = "Chromaggus"
L["Circle"] = "Cerchio"
--[[Translation missing --]]
L["Circular Texture"] = "Circular Texture"
L["Clamp"] = "Morso"
L["Class"] = "Classe"
L["Class and Specialization"] = "Classe e Specializzazione"
--[[Translation missing --]]
L["Classic"] = "Classic"
L["Classification"] = "Classificazione"
L["Clockwise"] = "Senso Orario"
--[[Translation missing --]]
L["Clone per Character"] = "Clone per Character"
L["Clone per Event"] = "Clona per evento"
L["Clone per Match"] = "Clona per partita"
--[[Translation missing --]]
L["Coin Precision"] = "Coin Precision"
L["Color"] = "Colore"
L["Color Animation"] = "Animazione a colori"
L["Combat Log"] = "Registro di combattimento"
--[[Translation missing --]]
L["Communities"] = "Communities"
--[[Translation missing --]]
L["Condition Custom Test"] = "Condition Custom Test"
L["Conditions"] = "Condizioni"
L["Contains"] = "Contiene"
L["Continuously update Movement Speed"] = "Aggiorna continuamente la velocità di movimento"
--[[Translation missing --]]
L["Cooldown"] = "Cooldown"
L["Cooldown bars show time before an ability is ready to be use, BigWigs prefix them with '~'"] = "Le barre di Cooldown mostrano il tempo trascorso prima che un'abilità sia pronta per essere utilizzata, BigWigs le prefissa con '~'"
--[[Translation missing --]]
L["Cooldown Progress (Item)"] = "Cooldown Progress (Item)"
--[[Translation missing --]]
L["Cooldown Progress (Slot)"] = "Cooldown Progress (Slot)"
L["Cooldown Ready Event"] = "Cooldiwn evento pronto"
L["Cooldown Ready Event (Item)"] = "Cooldown evento pronto (Oggetto)"
L["Cooldown Ready Event (Slot)"] = "Cooldown evento pronto (Slot)"
L["Cooldown Reduction changes the duration of seconds instead of showing the real time seconds."] = "La riduzione del Cooldown modifica la durata dei secondi invece di mostrare i secondi in tempo reale."
L["Cooldown/Charges/Count"] = "Cooldown/Cariche/Conteggio "
--[[Translation missing --]]
L["Copper"] = "Copper"
L["Could not load KUIAR_Runtime Archive, the addon is %s"] = "Impossibile caricare l'archivio KUIAR_Runtime, il componente aggiuntivo è %s"
L["Count"] = "Conteggio "
L["Counter Clockwise"] = "Conteggio Antiorario"
L["Create"] = "Crea"
--[[Translation missing --]]
L["Creature Family"] = "Creature Family"
--[[Translation missing --]]
L["Creature Family Name"] = "Creature Family Name"
--[[Translation missing --]]
L["Creature Type"] = "Creature Type"
--[[Translation missing --]]
L["Creature Type Name"] = "Creature Type Name"
L["Critical"] = "Critico"
L["Critical (%)"] = "Critico (%)"
L["Critical Rating"] = "Grado del Critico"
--[[Translation missing --]]
L["Crop X"] = "Crop X"
--[[Translation missing --]]
L["Crop Y"] = "Crop Y"
--[[Translation missing --]]
L["Crowd Controlled"] = "Crowd Controlled"
L["Crushing"] = "Frantumazione "
--[[Translation missing --]]
L["C'thun"] = "C'thun"
L["Cumulated time used during profiling"] = "Tempo cumulativo utilizzato durante la profilazione"
L["Currency"] = "Corrente"
L["Current Essence"] = "Essenza Attuale"
L["Current Experience"] = "Esperienza Attuale"
L["Current Instance"] = "Spedizione Attuale "
L["Current Movement Speed (%)"] = "Velocità di movimento attuale (%)"
L["Current Stage"] = "Stage Attuale "
L["Current Zone"] = "Zona Attuale "
L["Current Zone Group"] = "Gruppo di Zona Attuale "
L["Curse"] = "Maledizione"
--[[Translation missing --]]
L["Custom"] = "Custom"
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
--[[Translation missing --]]
L["Custom Function"] = "Custom Function"
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
--[[Translation missing --]]
L["Damage"] = "Damage"
--[[Translation missing --]]
L["Damage Shield"] = "Damage Shield"
--[[Translation missing --]]
L["Damage Shield Missed"] = "Damage Shield Missed"
--[[Translation missing --]]
L["Damage Split"] = "Damage Split"
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
L["Death Knight Rune"] = "Rune del cavaliere della morte"
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
L["Description"] = "Descrizione"
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
L["Distance"] = "Distanza"
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
L["Error"] = "Errore"
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
--[[Translation missing --]]
L["Event(s)"] = "Event(s)"
--[[Translation missing --]]
L["Every Frame"] = "Every Frame"
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
--[[Translation missing --]]
L["Extra Amount"] = "Extra Amount"
--[[Translation missing --]]
L["Extra Attacks"] = "Extra Attacks"
--[[Translation missing --]]
L["Extra Spell Id"] = "Extra Spell Id"
--[[Translation missing --]]
L["Extra Spell Name"] = "Extra Spell Name"
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
L["Form"] = "Forma"
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
--[[Translation missing --]]
L["Friendly"] = "Friendly"
--[[Translation missing --]]
L["Friendly Fire"] = "Friendly Fire"
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
--[[Translation missing --]]
L["Group"] = "Group"
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
--[[Translation missing --]]
L["Has Target"] = "Has Target"
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
--[[Translation missing --]]
L["Horde"] = "Horde"
--[[Translation missing --]]
L["Horizontal"] = "Horizontal"
--[[Translation missing --]]
L["Hostile"] = "Hostile"
--[[Translation missing --]]
L["Hostility"] = "Hostility"
--[[Translation missing --]]
L["Humanoid"] = "Humanoid"
--[[Translation missing --]]
L["Hybrid"] = "Hybrid"
--[[Translation missing --]]
L["Icon"] = "Icon"
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
--[[Translation missing --]]
L["Immune"] = "Immune"
--[[Translation missing --]]
L["Important"] = "Important"
--[[Translation missing --]]
L["Importing will start after combat ends."] = "Importing will start after combat ends."
--[[Translation missing --]]
L["In Combat"] = "In Combat"
--[[Translation missing --]]
L["In Encounter"] = "In Encounter"
--[[Translation missing --]]
L["In Group"] = "In Group"
--[[Translation missing --]]
L["In Party"] = "In Party"
--[[Translation missing --]]
L["In Pet Battle"] = "In Pet Battle"
--[[Translation missing --]]
L["In Raid"] = "In Raid"
--[[Translation missing --]]
L["In Range"] = "In Range"
--[[Translation missing --]]
L["In Vehicle"] = "In Vehicle"
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
--[[Translation missing --]]
L["Instance Difficulty"] = "Instance Difficulty"
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
--[[Translation missing --]]
L["Item"] = "Item"
--[[Translation missing --]]
L["Item Bonus Id"] = "Item Bonus Id"
--[[Translation missing --]]
L["Item Bonus Id Equipped"] = "Item Bonus Id Equipped"
--[[Translation missing --]]
L["Item Count"] = "Item Count"
--[[Translation missing --]]
L["Item Equipped"] = "Item Equipped"
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
--[[Translation missing --]]
L["Item Type Equipped"] = "Item Type Equipped"
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
--[[Translation missing --]]
L["Leech"] = "Leech"
--[[Translation missing --]]
L["Leech (%)"] = "Leech (%)"
--[[Translation missing --]]
L["Leech Rating"] = "Leech Rating"
--[[Translation missing --]]
L["Left"] = "Left"
--[[Translation missing --]]
L["Left to Right"] = "Left to Right"
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
--[[Translation missing --]]
L["Lower Than Tank"] = "Lower Than Tank"
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
--[[Translation missing --]]
L["Magic"] = "Magic"
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
--[[Translation missing --]]
L["Master"] = "Master"
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
--[[Translation missing --]]
L["Message"] = "Message"
--[[Translation missing --]]
L["Message Type"] = "Message Type"
--[[Translation missing --]]
L["Message type:"] = "Message type:"
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
--[[Translation missing --]]
L["Miss"] = "Miss"
--[[Translation missing --]]
L["Miss Type"] = "Miss Type"
--[[Translation missing --]]
L["Missed"] = "Missed"
--[[Translation missing --]]
L["Missing"] = "Missing"
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
--[[Translation missing --]]
L["Monster Yell"] = "Monster Yell"
--[[Translation missing --]]
L["Moon"] = "Moon"
--[[Translation missing --]]
L["Most remaining time"] = "Most remaining time"
--[[Translation missing --]]
L["Mounted"] = "Mounted"
--[[Translation missing --]]
L["Mouse Cursor"] = "Mouse Cursor"
--[[Translation missing --]]
L["Movement Speed Rating"] = "Movement Speed Rating"
--[[Translation missing --]]
L["Multi-target"] = "Multi-target"
--[[Translation missing --]]
L["Mythic Keystone"] = "Mythic Keystone"
--[[Translation missing --]]
L["Mythic+ Affix"] = "Mythic+ Affix"
--[[Translation missing --]]
L["Name"] = "Name"
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
--[[Translation missing --]]
L["Neutral"] = "Neutral"
--[[Translation missing --]]
L["Never"] = "Never"
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
--[[Translation missing --]]
L["No Instance"] = "No Instance"
--[[Translation missing --]]
L["No Profiling information saved."] = "No Profiling information saved."
--[[Translation missing --]]
L["No Progress Information available."] = "No Progress Information available."
--[[Translation missing --]]
L["None"] = "None"
--[[Translation missing --]]
L["Non-player Character"] = "Non-player Character"
--[[Translation missing --]]
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
--[[Translation missing --]]
L["Number"] = "Number"
--[[Translation missing --]]
L["Number Affected"] = "Number Affected"
--[[Translation missing --]]
L["Object"] = "Object"
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
--[[Translation missing --]]
L["Officer"] = "Officer"
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
--[[Translation missing --]]
L["Orbit"] = "Orbit"
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
--[[Translation missing --]]
L["Overhealing"] = "Overhealing"
--[[Translation missing --]]
L["Overkill"] = "Overkill"
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
--[[Translation missing --]]
L["Parry"] = "Parry"
--[[Translation missing --]]
L["Parry (%)"] = "Parry (%)"
--[[Translation missing --]]
L["Parry Rating"] = "Parry Rating"
--[[Translation missing --]]
L["Party"] = "Party"
--[[Translation missing --]]
L["Party Kill"] = "Party Kill"
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
--[[Translation missing --]]
L["Paused"] = "Paused"
--[[Translation missing --]]
L["Periodic Spell"] = "Periodic Spell"
--[[Translation missing --]]
L["Personal Resource Display"] = "Personal Resource Display"
--[[Translation missing --]]
L["Pet"] = "Pet"
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
--[[Translation missing --]]
L["Player"] = "Player"
--[[Translation missing --]]
L["Player Character"] = "Player Character"
--[[Translation missing --]]
L["Player Class"] = "Player Class"
--[[Translation missing --]]
L["Player Effective Level"] = "Player Effective Level"
--[[Translation missing --]]
L["Player Experience"] = "Player Experience"
--[[Translation missing --]]
L["Player Faction"] = "Player Faction"
--[[Translation missing --]]
L["Player Level"] = "Player Level"
--[[Translation missing --]]
L["Player Location ID(s)"] = "Player Location ID(s)"
--[[Translation missing --]]
L["Player Money"] = "Player Money"
--[[Translation missing --]]
L["Player Name/Realm"] = "Player Name/Realm"
--[[Translation missing --]]
L["Player Race"] = "Player Race"
--[[Translation missing --]]
L["Player(s) Affected"] = "Player(s) Affected"
--[[Translation missing --]]
L["Player(s) Not Affected"] = "Player(s) Not Affected"
--[[Translation missing --]]
L["Player/Unit Info"] = "Player/Unit Info"
--[[Translation missing --]]
L["Players and Pets"] = "Players and Pets"
--[[Translation missing --]]
L["Poison"] = "Poison"
--[[Translation missing --]]
L["Power"] = "Power"
--[[Translation missing --]]
L["Power (%)"] = "Power (%)"
--[[Translation missing --]]
L["Power Deficit"] = "Power Deficit"
--[[Translation missing --]]
L["Power Type"] = "Power Type"
--[[Translation missing --]]
L["Precision"] = "Precision"
--[[Translation missing --]]
L["Preset"] = "Preset"
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
--[[Translation missing --]]
L["Pulse"] = "Pulse"
--[[Translation missing --]]
L["PvP Flagged"] = "PvP Flagged"
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
--[[Translation missing --]]
L["Radius"] = "Radius"
--[[Translation missing --]]
L["Ragnaros"] = "Ragnaros"
--[[Translation missing --]]
L["Raid"] = "Raid"
--[[Translation missing --]]
L["Raid (Heroic)"] = "Raid (Heroic)"
--[[Translation missing --]]
L["Raid (Mythic)"] = "Raid (Mythic)"
--[[Translation missing --]]
L["Raid (Normal)"] = "Raid (Normal)"
--[[Translation missing --]]
L["Raid (Timewalking)"] = "Raid (Timewalking)"
--[[Translation missing --]]
L["Raid Mark"] = "Raid Mark"
--[[Translation missing --]]
L["Raid Mark Icon"] = "Raid Mark Icon"
--[[Translation missing --]]
L["Raid Role"] = "Raid Role"
--[[Translation missing --]]
L["Raid Warning"] = "Raid Warning"
--[[Translation missing --]]
L["Raids"] = "Raids"
--[[Translation missing --]]
L["Range"] = "Range"
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
--[[Translation missing --]]
L["Reflect"] = "Reflect"
--[[Translation missing --]]
L["Region type %s not supported"] = "Region type %s not supported"
--[[Translation missing --]]
L["Relative"] = "Relative"
--[[Translation missing --]]
L["Relative X-Offset"] = "Relative X-Offset"
--[[Translation missing --]]
L["Relative Y-Offset"] = "Relative Y-Offset"
--[[Translation missing --]]
L["Remaining Duration"] = "Remaining Duration"
--[[Translation missing --]]
L["Remaining Time"] = "Remaining Time"
--[[Translation missing --]]
L["Remove Obsolete Auras"] = "Remove Obsolete Auras"
--[[Translation missing --]]
L["Renown Level"] = "Renown Level"
--[[Translation missing --]]
L["Renown Max Level"] = "Renown Max Level"
--[[Translation missing --]]
L["Renown Reputation"] = "Renown Reputation"
--[[Translation missing --]]
L["Repair"] = "Repair"
--[[Translation missing --]]
L["Repeat"] = "Repeat"
--[[Translation missing --]]
L["Report Summary"] = "Report Summary"
--[[Translation missing --]]
L["Reputation"] = "Reputation"
--[[Translation missing --]]
L["Reputation (%)"] = "Reputation (%)"
--[[Translation missing --]]
L["Requested display does not exist"] = "Requested display does not exist"
--[[Translation missing --]]
L["Requested display not authorized"] = "Requested display not authorized"
--[[Translation missing --]]
L["Requesting display information from %s ..."] = "Requesting display information from %s ..."
--[[Translation missing --]]
L["Require Valid Target"] = "Require Valid Target"
--[[Translation missing --]]
L["Requires syncing the specialization via LibSpecialization."] = "Requires syncing the specialization via LibSpecialization."
--[[Translation missing --]]
L["Resilience (%)"] = "Resilience (%)"
--[[Translation missing --]]
L["Resilience Rating"] = "Resilience Rating"
--[[Translation missing --]]
L["Resist"] = "Resist"
--[[Translation missing --]]
L["Resistances"] = "Resistances"
--[[Translation missing --]]
L["Resisted"] = "Resisted"
--[[Translation missing --]]
L["Rested"] = "Rested"
--[[Translation missing --]]
L["Rested Experience"] = "Rested Experience"
--[[Translation missing --]]
L["Rested Experience (%)"] = "Rested Experience (%)"
--[[Translation missing --]]
L["Resting"] = "Resting"
--[[Translation missing --]]
L["Resurrect"] = "Resurrect"
--[[Translation missing --]]
L["Resurrect Pending"] = "Resurrect Pending"
--[[Translation missing --]]
L["Right"] = "Right"
--[[Translation missing --]]
L["Right to Left"] = "Right to Left"
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
--[[Translation missing --]]
L["Rotate Left"] = "Rotate Left"
--[[Translation missing --]]
L["Rotate Right"] = "Rotate Right"
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
--[[Translation missing --]]
L["Rune"] = "Rune"
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
--[[Translation missing --]]
L["Say"] = "Say"
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
--[[Translation missing --]]
L["Seconds"] = "Seconds"
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
--[[Translation missing --]]
L["Shake"] = "Shake"
--[[Translation missing --]]
L["Shazzrah"] = "Shazzrah"
--[[Translation missing --]]
L["Shift-Click to resume addon execution."] = "Shift-Click to resume addon execution."
--[[Translation missing --]]
L["Show"] = "Show"
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
--[[Translation missing --]]
L["Shrink"] = "Shrink"
--[[Translation missing --]]
L["Silithid Royalty"] = "Silithid Royalty"
--[[Translation missing --]]
L["Silver"] = "Silver"
--[[Translation missing --]]
L["Simple"] = "Simple"
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
--[[Translation missing --]]
L["Slide from Bottom"] = "Slide from Bottom"
--[[Translation missing --]]
L["Slide from Left"] = "Slide from Left"
--[[Translation missing --]]
L["Slide from Right"] = "Slide from Right"
--[[Translation missing --]]
L["Slide from Top"] = "Slide from Top"
--[[Translation missing --]]
L["Slide to Bottom"] = "Slide to Bottom"
--[[Translation missing --]]
L["Slide to Left"] = "Slide to Left"
--[[Translation missing --]]
L["Slide to Right"] = "Slide to Right"
--[[Translation missing --]]
L["Slide to Top"] = "Slide to Top"
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
--[[Translation missing --]]
L["Source Name"] = "Source Name"
--[[Translation missing --]]
L["Source NPC Id"] = "Source NPC Id"
--[[Translation missing --]]
L["Source Object Type"] = "Source Object Type"
--[[Translation missing --]]
L["Source Raid Mark"] = "Source Raid Mark"
--[[Translation missing --]]
L["Source Reaction"] = "Source Reaction"
--[[Translation missing --]]
L["Source Unit"] = "Source Unit"
--[[Translation missing --]]
L["Source Unit Name/Realm"] = "Source Unit Name/Realm"
--[[Translation missing --]]
L["Source unit's raid mark index"] = "Source unit's raid mark index"
--[[Translation missing --]]
L["Source unit's raid mark texture"] = "Source unit's raid mark texture"
--[[Translation missing --]]
L["Space"] = "Space"
--[[Translation missing --]]
L["Spacing"] = "Spacing"
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
--[[Translation missing --]]
L["Specific Unit"] = "Specific Unit"
--[[Translation missing --]]
L["Spell"] = "Spell"
--[[Translation missing --]]
L["Spell (Building)"] = "Spell (Building)"
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
--[[Translation missing --]]
L["Spell Name"] = "Spell Name"
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
--[[Translation missing --]]
L["Spin"] = "Spin"
--[[Translation missing --]]
L["Spiral"] = "Spiral"
--[[Translation missing --]]
L["Spiral In And Out"] = "Spiral In And Out"
--[[Translation missing --]]
L["Spirit"] = "Spirit"
--[[Translation missing --]]
L["Stack Count"] = "Stack Count"
--[[Translation missing --]]
L["Stack trace:"] = "Stack trace:"
--[[Translation missing --]]
L["Stacks"] = "Stacks"
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
--[[Translation missing --]]
L["Stance/Form/Aura"] = "Stance/Form/Aura"
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
--[[Translation missing --]]
L["Status"] = "Status"
--[[Translation missing --]]
L["Status Bar"] = "Status Bar"
--[[Translation missing --]]
L["Stolen"] = "Stolen"
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
--[[Translation missing --]]
L["Summon"] = "Summon"
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
--[[Translation missing --]]
L["Swing"] = "Swing"
--[[Translation missing --]]
L["Swing Timer"] = "Swing Timer"
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
--[[Translation missing --]]
L["Talent"] = "Talent"
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
--[[Translation missing --]]
L["Talent Specialization"] = "Talent Specialization"
--[[Translation missing --]]
L["Tanking And Highest"] = "Tanking And Highest"
--[[Translation missing --]]
L["Tanking But Not Highest"] = "Tanking But Not Highest"
--[[Translation missing --]]
L["Target"] = "Target"
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
--[[Translation missing --]]
L["Text"] = "Text"
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
--[[Translation missing --]]
L["Threat Situation"] = "Threat Situation"
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
--[[Translation missing --]]
L["Timed"] = "Timed"
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
--[[Translation missing --]]
L["Top"] = "Top"
--[[Translation missing --]]
L["Top Left"] = "Top Left"
--[[Translation missing --]]
L["Top Right"] = "Top Right"
--[[Translation missing --]]
L["Top to Bottom"] = "Top to Bottom"
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
--[[Translation missing --]]
L["Totem"] = "Totem"
--[[Translation missing --]]
L["Totem #%i"] = "Totem #%i"
--[[Translation missing --]]
L["Totem Icon"] = "Totem Icon"
--[[Translation missing --]]
L["Totem Name"] = "Totem Name"
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
--[[Translation missing --]]
L["Transmission error"] = "Transmission error"
--[[Translation missing --]]
L["Trigger"] = "Trigger"
--[[Translation missing --]]
L["Trigger %i"] = "Trigger %i"
--[[Translation missing --]]
L["Trigger %s"] = "Trigger %s"
--[[Translation missing --]]
L["Trigger 1"] = "Trigger 1"
--[[Translation missing --]]
L["Trigger State Updater (Advanced)"] = "Trigger State Updater (Advanced)"
--[[Translation missing --]]
L["Trigger Update"] = "Trigger Update"
--[[Translation missing --]]
L["Trigger:"] = "Trigger:"
--[[Translation missing --]]
L["Trivial (Low Level)"] = "Trivial (Low Level)"
--[[Translation missing --]]
L["True"] = "True"
--[[Translation missing --]]
L["Trying to repair broken conditions in %s likely caused by a KUIAR_Runtime bug."] = "Trying to repair broken conditions in %s likely caused by a KUIAR_Runtime bug."
--[[Translation missing --]]
L["Twin Emperors"] = "Twin Emperors"
--[[Translation missing --]]
L["Type"] = "Type"
--[[Translation missing --]]
L["Unable to modernize aura '%s'. This is probably due to corrupt data or a bad migration, please report this to m33shoq."] = "Unable to modernize aura '%s'. This is probably due to corrupt data or a bad migration, please report this to m33shoq."
--[[Translation missing --]]
L["Unaffected"] = "Unaffected"
--[[Translation missing --]]
L["Undefined"] = "Undefined"
--[[Translation missing --]]
L["Unholy"] = "Unholy"
--[[Translation missing --]]
L["Unholy Rune #1"] = "Unholy Rune #1"
--[[Translation missing --]]
L["Unholy Rune #2"] = "Unholy Rune #2"
--[[Translation missing --]]
L["Unit"] = "Unit"
--[[Translation missing --]]
L["Unit Characteristics"] = "Unit Characteristics"
--[[Translation missing --]]
L["Unit Destroyed"] = "Unit Destroyed"
--[[Translation missing --]]
L["Unit Died"] = "Unit Died"
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
--[[Translation missing --]]
L["Up"] = "Up"
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
--[[Translation missing --]]
L["Weapon"] = "Weapon"
--[[Translation missing --]]
L["Weapon Enchant"] = "Weapon Enchant"
--[[Translation missing --]]
L["Weapon Enchant / Fishing Lure"] = "Weapon Enchant / Fishing Lure"
--[[Translation missing --]]
L["Whisper"] = "Whisper"
--[[Translation missing --]]
L["Width"] = "Width"
--[[Translation missing --]]
L["Wobble"] = "Wobble"
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
--[[Translation missing --]]
L["Yell"] = "Yell"
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
--[[Translation missing --]]
L["Zone Name"] = "Zone Name"
--[[Translation missing --]]
L["Zoom"] = "Zoom"
--[[Translation missing --]]
L["Zoom Animation"] = "Zoom Animation"
--[[Translation missing --]]
L["Zul'Gurub"] = "Zul'Gurub"

-- KUI: translations added for strings upstream leaves in English (2026-11-12).
L["If you require additional assistance, please open a ticket on GitHub."] = "Se hai bisogno di ulteriore assistenza, apri una segnalazione su GitHub."
L["Secret circular progress requires equal Crop X and Crop Y. The foreground is hidden until they match."] = "Il progresso circolare segreto richiede Ritaglio X e Ritaglio Y uguali. Il primo piano resta nascosto finché non coincidono."
L["KUIAR_Engine has detected empty settings. If this is unexpected, please report it on GitHub."] = "KUIAR_Engine ha rilevato impostazioni vuote. Se è inatteso, segnalalo su GitHub."
L["This filter has been moved to the Location trigger. Change your aura to use the new Location trigger."] = "Questo filtro è stato spostato nell'innesco Posizione. Modifica la tua aura per usare il nuovo innesco Posizione."
L["A detailed overview of your auras and KUIAR_Runtime systems."] = "Una panoramica dettagliata delle tue aure e dei sistemi di KUIAR_Runtime."
L["Game Mode"] = "Modalità di gioco"
L["RP"] = "PR"
L[" Filter formats: 'Name', 'Name-Realm', '-Realm'.\n\nSupports multiple entries, separated by commas\nCan use \\ to escape -."] = " Formati del filtro: 'Nome', 'Nome-Reame', '-Reame'.\n\nSupporta più voci, separate da virgole\nUsa \\ per l'escape di -."
L["|cffff0000deprecated|r"] = "|cffff0000obsoleto|r"
L["|cFFFF0000Support for unfiltered COMBAT_LOG_EVENT_UNFILTERED is deprecated|r\nCOMBAT_LOG_EVENT_UNFILTERED without a filter are disabled as it’s very performance costly.\nFind more information:\nhttps://github.com/m33shoq/M33kAuras/wiki/Custom-Triggers#events"] = "|cFFFF0000Il supporto per COMBAT_LOG_EVENT_UNFILTERED non filtrato è obsoleto|r\nCOMBAT_LOG_EVENT_UNFILTERED senza filtro è disattivato perché pesa molto sulle prestazioni.\nMaggiori informazioni:\nhttps://github.com/m33shoq/M33kAuras/wiki/Custom-Triggers#events"
L["A trigger in this aura is set up to track a soft target unit, but you don't have the CVars set up for this to work correctly. Consider either changing the unit tracked, or configuring the Soft Target CVars."] = "Un'attivazione di quest'aura è impostata per seguire un'unità bersaglio morbido, ma i CVar necessari non sono configurati correttamente. Cambia l'unità seguita oppure configura i CVar del bersaglio morbido."
L["Absorb and Healing"] = "Assorbimento e cure"
L["Absorb Overlay"] = "Overlay assorbimento"
L["Afk"] = "Assente"
L["All States table contains a non table at key: '%s'."] = "La tabella All States contiene un valore non tabella alla chiave: '%s'."
L["Armor Penetration"] = "Penetrazione armatura"
L["Armor Peneration Percent"] = "Percentuale di penetrazione armatura"
L["Armor Peneration Rating"] = "Valutazione di penetrazione armatura"
L["Armor"] = "Armatura"
L["Assist"] = "Assisti"
L["Assisted Combat Next Cast"] = "Prossimo lancio del combattimento assistito"
L["Attach to End, backwards"] = "Aggancia alla fine, all'indietro"
L["Attach to Point"] = "Aggancia al punto"
L["Aura Stack"] = "Cariche dell'aura"
L["Autocast Shine"] = "Scintilla di lancio automatico"
L["Bar enabled in BigWigs settings"] = "Barra abilitata nelle impostazioni di BigWigs"
L["Bar enabled in Boss Mod addon settings"] = "Barra abilitata nelle impostazioni dell'addon Boss Mod"
L["Bar enabled in DBM settings"] = "Barra abilitata nelle impostazioni di DBM"
L["Bar Texture"] = "Texture barra"
L["Bar Type"] = "Tipo di barra"
L["Beastmaster"] = "Cacciatore - Maestro delle bestie"
L["BG>Raid>Party>Say"] = "CB>Incursione>Gruppo>Dire"
L["BG-System Alliance"] = "Sistema CB Alleanza"
L["BG-System Horde"] = "Sistema CB Orda"
L["BG-System Neutral"] = "Sistema CB Neutrale"
L["BigWigs Stage"] = "Fase di BigWigs"
L["Bleed"] = "Sanguinamento"
L["Boss Emote"] = "Emote del boss"
L["Boss Mod Announce"] = "Annuncio Boss Mod"
L["Boss Mod Stage"] = "Fase Boss Mod"
L["Boss Mod Stage (Event)"] = "Fase Boss Mod (evento)"
L["Boss Mod Timer"] = "Timer Boss Mod"
L["Boss Whisper"] = "Sussurro del boss"
L["Bounce with Decay"] = "Rimbalzo con smorzamento"
L["Break"] = "Pausa"
L["Buff"] = "Beneficio"
L["Buff/Debuff"] = "Beneficio/Malefico"
L["Buru the Gorger"] = "Buru il Divoratore"
L["Cast"] = "Lancio"
L["Caster"] = "Incantatore"
L["Ceil"] = "Arrotonda per eccesso"
L["Character GUID"] = "GUID del personaggio"
L["Character Name"] = "Nome del personaggio"
L["Character Transferred Quantity"] = "Quantità trasferita dal personaggio"
L["Charged Combo Points"] = "Punti combo carichi"
L["Circular Texture"] = "Texture circolare"
L["Classic"] = "Classico"
L["Clone per Character"] = "Clone per personaggio"
L["Coin Precision"] = "Precisione monete"
L["Communities"] = "Comunità"
L["Condition Custom Test"] = "Test personalizzato della condizione"
L["Cooldown"] = "Tempo di recupero"
L["Cooldown Progress (Item)"] = "Avanzamento tempo di recupero (oggetto)"
L["Cooldown Progress (Slot)"] = "Avanzamento tempo di recupero (slot)"
L["Copper"] = "Rame"
L["Creature Family"] = "Famiglia di creature"
L["Creature Family Name"] = "Nome della famiglia di creature"
L["Creature Type"] = "Tipo di creatura"
L["Creature Type Name"] = "Nome del tipo di creatura"
L["Crop X"] = "Ritaglio X"
L["Crop Y"] = "Ritaglio Y"
L["Crowd Controlled"] = "Controllato (CC)"
L["C'thun"] = "C'Thun"
L["Custom"] = "Personalizzato"
L["Custom Action"] = "Azione personalizzata"
L["Custom Anchor"] = "Ancoraggio personalizzato"
L["Custom Check"] = "Controllo personalizzato"
L["Custom Color"] = "Colore personalizzato"
L["Custom Condition Code"] = "Codice condizione personalizzato"
L["Custom Configuration"] = "Configurazione personalizzata"
L["Custom Fade Animation"] = "Animazione di dissolvenza personalizzata"
L["Custom Function"] = "Funzione personalizzata"
L["Custom Grow"] = "Crescita personalizzata"
L["Custom Sort"] = "Ordinamento personalizzato"
L["Custom Text Function"] = "Funzione di testo personalizzata"
L["Custom Trigger Combination"] = "Combinazione di attivazioni personalizzate"
L["Custom Variables"] = "Variabili personalizzate"
L["Damage"] = "Danni"
L["Damage Shield"] = "Scudo danni"
L["Damage Shield Missed"] = "Scudo danni mancato"
L["Damage Split"] = "Divisione danni"
L["DBM Announce"] = "Annuncio DBM"
L["DBM Stage"] = "Fase DBM"
L["DBM Timer"] = "Timer DBM"
L["Dead"] = "Morto"
L["Death"] = "Morte"
L["Debuff"] = "Malefico"
L["Debuff Class"] = "Classe del malefico"
L["Debuff Class Icon"] = "Icona classe del malefico"
L["Debuff Type"] = "Tipo di malefico"
L["Debug Log contains more than 1000 entries"] = "Il registro di debug contiene più di 1000 voci"
L["Debug Logging enabled"] = "Registrazione di debug attiva"
L["Debug Logging enabled for '%s'"] = "Registrazione di debug attiva per '%s'"
L["Defense"] = "Difesa"
L["Defensive Stats"] = "Statistiche difensive"
L["Deflect"] = "Deviazione"
L["Delve"] = "Esplorazione"
L["Desaturate"] = "Desatura"
L["Desaturate Background"] = "Desatura sfondo"
L["Desaturate Foreground"] = "Desatura primo piano"
L["Descending"] = "Decrescente"
L["Dest Raid Mark"] = "Marchio raid della destinazione"
L["Destination Affiliation"] = "Affiliazione della destinazione"
L["Destination GUID"] = "GUID della destinazione"
L["Destination Info"] = "Info sulla destinazione"
L["Destination Name"] = "Nome della destinazione"
L["Destination NPC Id"] = "ID NPC della destinazione"
L["Destination Object Type"] = "Tipo di oggetto della destinazione"
L["Destination Reaction"] = "Reazione della destinazione"
L["Destination Unit"] = "Unità di destinazione"
L["Destination unit's raid mark index"] = "Indice del marchio raid dell'unità di destinazione"
L["Destination unit's raid mark texture"] = "Texture del marchio raid dell'unità di destinazione"
L["Difficulty"] = "Difficoltà"
L["Disable Spell Known Check"] = "Disattiva il controllo dell'incantesimo conosciuto"
L["Disabled"] = "Disattivato"
L["Disabled feature %q"] = "Funzione %q disattivata"
L["Disabled Spell Known Check"] = "Controllo dell'incantesimo conosciuto disattivato"
L["Discovered"] = "Scoperto"
L["Disease"] = "Malattia"
L["Dispel"] = "Dissoluzione"
L["Dispel Failed"] = "Dissoluzione fallita"
L["Display"] = "Visualizzazione"
L["Do Not Disturb"] = "Non disturbare"
L["Dodge"] = "Schivata"
L["Dodge (%)"] = "Schivata (%)"
L["Dodge Rating"] = "Valutazione di schivata"
L["Down"] = "Giù"
L["Down, then Centered Horizontal"] = "Giù, poi centrato orizzontalmente"
L["Down, then Left"] = "Giù, poi a sinistra"
L["Down, then Right"] = "Giù, poi a destra"
L["Drain"] = "Svuota"
L["Dropdown Menu"] = "Menu a discesa"
L["Dumping table"] = "Esportazione della tabella"
L["Dungeon (Celestial)"] = "Spedizione (Celestiale)"
L["Dungeon (Heroic)"] = "Spedizione (Eroica)"
L["Dungeon (Mythic)"] = "Spedizione (Mitica)"
L["Dungeon (Mythic+)"] = "Spedizione (Mitica+)"
L["Dungeon (Normal)"] = "Spedizione (Normale)"
L["Dungeon (Timewalking)"] = "Spedizione (Viaggio nel tempo)"
L["Dungeons"] = "Dungeon"
L["Durability Damage"] = "Danno alla durabilità"
L["Durability Damage All"] = "Danno alla durabilità (tutto)"
L["Duration"] = "Durata"
L["Duration Function"] = "Funzione di durata"
L["Duration Function (fallback state)"] = "Funzione di durata (stato di riserva)"
L["Ease In"] = "Entrata graduale"
L["Ease In and Out"] = "Entrata e uscita graduali"
L["Ease Out"] = "Uscita graduale"
L["Eclipse Direction"] = "Direzione eclissi"
L["Edge"] = "Bordo"
L["Edge of Madness"] = "Bordo della follia"
L["Effective Spell Id"] = "ID incantesimo effettivo"
L["Elide"] = "Tronca"
L["Elite"] = "Élite"
L["Empower Cast End"] = "Fine lancio potenziato"
L["Empower Cast Interrupt"] = "Interruzione lancio potenziato"
L["Empower Cast Start"] = "Inizio lancio potenziato"
L["Empowered"] = "Potenziato"
L["Empowered 1"] = "Potenziato 1"
L["Empowered 2"] = "Potenziato 2"
L["Empowered 3"] = "Potenziato 3"
L["Empowered 4"] = "Potenziato 4"
L["Empowered 5"] = "Potenziato 5"
L["Empowered Cast"] = "Lancio potenziato"
L["Empowered Cast Fully Charged"] = "Lancio potenziato completamente carico"
L["Empowered Fully Charged"] = "Potenziato completamente carico"
L["Empty"] = "Vuoto"
L["Enabled feature %q"] = "Funzione %q attivata"
L["Enables (incorrect) round down of seconds, which was the previous default behavior."] = "Abilita l'arrotondamento per difetto (errato) dei secondi, che era il comportamento predefinito precedente."
L["Enchant Applied"] = "Incantamento applicato"
L["Enchant Found"] = "Incantamento trovato"
L["Enchant ID"] = "ID incantamento"
L["Enchant Missing"] = "Incantamento mancante"
L["Enchant Name or ID"] = "Nome o ID dell'incantamento"
L["Enchant Removed"] = "Incantamento rimosso"
L["Enchanted"] = "Incantato"
L["Encounter ID(s)"] = "ID incontro"
L["Energize"] = "Energizza"
L["Enrage"] = "Furia"
L["Enter a name or a spellId"] = "Inserisci un nome o uno spellId"
L["Entering"] = "Entrata"
L["Entering/Leaving Combat"] = "Entrata/Uscita dal combattimento"
L["Entering/Leaving Encounter"] = "Entrata/Uscita dall'incontro"
L["Entry Order"] = "Ordine delle voci"
L["Environment Type"] = "Tipo di ambiente"
L["Environmental"] = "Ambientale"
L["Equipment"] = "Equipaggiamento"
L["Equipment Set"] = "Set di equipaggiamento"
L["Equipment Set Equipped"] = "Set di equipaggiamento indossato"
L["Equipment Slot"] = "Slot di equipaggiamento"
L["Equipped"] = "Equipaggiato"
L["Error '%s' created a secure clone. We advise deleting the aura. For more information:\nhttps://github.com/m33shoq/M33kAuras/wiki/Protected-Frames"] = "L'errore '%s' ha creato un clone protetto. Si consiglia di eliminare l'aura. Per maggiori informazioni:\nhttps://github.com/m33shoq/M33kAuras/wiki/Protected-Frames"
L["Error decoding."] = "Errore di decodifica."
L["Error decompressing"] = "Errore di decompressione"
L["Error decompressing. This doesn't look like a KUIAR_Runtime import."] = "Errore di decompressione. Non sembra un'importazione di KUIAR_Runtime."
L["Error deserializing"] = "Errore di deserializzazione"
L["Error Frame"] = "Cornice degli errori"
L["ERROR in '%s' unknown or incompatible sub element type '%s'"] = "ERRORE in '%s': tipo di sotto-elemento '%s' sconosciuto o incompatibile"
L["Error in Aura '%s'"] = "Errore nell'aura '%s'"
L["Error not receiving display information from %s"] = "Errore: nessuna informazione di display ricevuta da %s"
L["Essence"] = "Essenza"
L["Essence #1"] = "Essenza #1"
L["Essence #2"] = "Essenza #2"
L["Essence #3"] = "Essenza #3"
L["Essence #4"] = "Essenza #4"
L["Essence #5"] = "Essenza #5"
L["Essence #6"] = "Essenza #6"
L["Evade"] = "Fuga"
L["Event(s)"] = "Evento/i"
L["Every Frame"] = "Ogni frame"
L["Every Frame (High CPU usage)"] = "Ogni frame (alto uso della CPU)"
L["Evoker Essence"] = "Essenza dell'Evocatore"
L["Exact Spell ID(s)"] = "ID incantesimo esatto/i"
L["Execute Conditions"] = "Esegui condizioni"
L["Experience (%)"] = "Esperienza (%)"
L["Expertise (%)"] = "Maestria (%)"
L["Expertise Bonus"] = "Bonus maestria"
L["Expertise Rating"] = "Valutazione di maestria"
L["Extend Outside"] = "Estendi all'esterno"
L["Extra Amount"] = "Quantità extra"
L["Extra Attacks"] = "Attacchi extra"
L["Extra Spell Id"] = "ID incantesimo extra"
L["Extra Spell Name"] = "Nome incantesimo extra"
L["Faction"] = "Fazione"
L["Faction Name"] = "Nome della fazione"
L["Faction Reputation"] = "Reputazione con la fazione"
L["Fade Animation"] = "Animazione di dissolvenza"
L["Fade In"] = "Dissolvenza in entrata"
L["Fade Out"] = "Dissolvenza"
L["Fail Alert"] = "Avviso di fallimento"
L["False"] = "Falso"
L["Fankriss the Unyielding"] = "Fankriss l'Implacabile"
L["Feature %q is already disabled"] = "La funzione %q è già disattivata"
L["Feature %q is already enabled"] = "La funzione %q è già attivata"
L["Fetch Absorb"] = "Recupera assorbimento"
L["Fetch Heal Absorb"] = "Recupera assorbimento cure"
L["Fetch Legendary Power"] = "Recupera potere leggendario"
L["Fetches the name and icon of the Legendary Power that matches this bonus id."] = "Recupera nome e icona del Potere leggendario corrispondente a questo ID bonus."
L["Fill Area"] = "Riempi area"
L["Filter messages with format <message>"] = "Filtra i messaggi con formato <messaggio>"
L["Fire Resistance"] = "Resistenza al fuoco"
L["First"] = "Primo"
L["First Value of Tooltip Text"] = "Primo valore del testo del tooltip"
L["Fixed"] = "Fisso"
L["Fixed Names"] = "Nomi fissi"
L["Fixed Size"] = "Dimensione fissa"
L["Flash"] = "Lampeggio"
L["Flex Raid"] = "Incursione flessibile"
L["Flip"] = "Inverti"
L["Floor"] = "Arrotonda per difetto"
L["Follower Dungeon"] = "Spedizione con seguace"
L["Font"] = "Carattere"
L["Font Size"] = "Dimensione carattere"
L["Forbidden function or table: %s"] = "Funzione o tabella vietata: %s"
L["Foreground"] = "Primo piano"
L["Foreground Color"] = "Colore del primo piano"
L["Format"] = "Formato"
L["Format Gold"] = "Formato oro"
L["Formats |cFFFFCC00%unit|r"] = "Formatta |cFFFFCC00%unit|r"
L["Formats Player's |cFFFFCC00%guid|r"] = "Formatta il |cFFFFCC00%guid|r del giocatore"
L["Forward"] = "Avanti"
L["Forward, Reverse Loop"] = "Avanti, ciclo inverso"
L["Fourth Value of Tooltip Text"] = "Quarto valore del testo del tooltip"
L["Frame Selector"] = "Selettore di cornice"
L["Frequency"] = "Frequenza"
L["Friendly"] = "Amichevole"
L["Friendly Fire"] = "Fuoco amico"
L["Friendship Max Rank"] = "Grado massimo di amicizia"
L["Friendship Rank"] = "Grado di amicizia"
L["Friendship Reputation"] = "Reputazione di amicizia"
L["Frost"] = "Gelo"
L["Frost Resistance"] = "Resistenza al gelo"
L["Frost Rune #1"] = "Runa del gelo #1"
L["Frost Rune #2"] = "Runa del gelo #2"
L["Full"] = "Pieno"
L["Full Region"] = "Regione completa"
L["Full/Empty"] = "Pieno/Vuoto"
L["Gained"] = "Ottenuto"
L["General"] = "Generale"
L["General Rajaxx"] = "Generale Rajaxx"
L["GetNameAndIcon Function (fallback state)"] = "Funzione GetNameAndIcon (stato di riserva)"
L["Glancing"] = "Colpo di striscio"
L["Global Cooldown"] = "Tempo di recupero globale"
L["Glow"] = "Bagliore"
L["Glow External Element"] = "Bagliore su elemento esterno"
L["Glyph"] = "Glifo"
L["Gold"] = "Oro"
L["Golemagg the Incinerator"] = "Golemagg l'Incineratore"
L["Gothik the Harvester"] = "Gothik il Mietitore"
L["Gradient"] = "Gradiente"
L["Gradient Enabled"] = "Gradiente abilitato"
L["Gradient End"] = "Fine del gradiente"
L["Gradient Orientation"] = "Orientamento del gradiente"
L["Gradient Pulse"] = "Pulsazione del gradiente"
L["Grand Widow Faerlina"] = "Gran Vedova Faerlina"
L["Grid"] = "Griglia"
L["Group"] = "Gruppo"
L["Group Arrangement"] = "Disposizione del gruppo"
L["Group Leader/Assist"] = "Capogruppo/Assistente"
L["Group Size"] = "Dimensione del gruppo"
L["Group Type"] = "Tipo di gruppo"
L["Grow"] = "Crescita"
L["GTFO Alert"] = "Avviso GTFO"
L["Guardian"] = "Guardiano"
L["Guild"] = "Gilda"
L["Has Target"] = "Ha un bersaglio"
L["Has Vehicle UI"] = "Ha interfaccia veicolo"
L["Haste (%)"] = "Celerità (%)"
L["Haste Rating"] = "Valutazione di celerità"
L["Heal"] = "Cura"
L["Heal Absorb"] = "Assorbimento cure"
L["Heal Absorbed"] = "Cure assorbite"
L["Health"] = "Salute"
L["Health (%)"] = "Salute (%)"
L["Health Deficit"] = "Deficit di salute"
L["Heigan the Unclean"] = "Heigan l'Impuro"
L["Height"] = "Altezza"
L["Hero Talent"] = "Talento eroe"
L["Heroic Party"] = "Gruppo eroico"
L["Hide"] = "Nascondi"
L["Hide 0 cooldowns"] = "Nascondi tempi di recupero a 0"
L["Hide Timer Text"] = "Nascondi testo del timer"
L["High Damage"] = "Danno elevato"
L["High Priest Thekal"] = "Alto Sacerdote Thekal"
L["High Priest Venoxis"] = "Alto Sacerdote Venoxis"
L["High Priestess Arlokk"] = "Alta Sacerdotessa Arlokk"
L["High Priestess Jeklik"] = "Alta Sacerdotessa Jeklik"
L["High Priestess Mar'li"] = "Alta Sacerdotessa Mar'li"
L["Higher Than Tank"] = "Più alto del tank"
L["Highest Spell Id"] = "ID incantesimo più alto"
L["Hit (%)"] = "Colpo (%)"
L["Hit Rating"] = "Valutazione di colpo"
L["Holy Resistance"] = "Resistenza al sacro"
L["Horde"] = "Orda"
L["Horizontal"] = "Orizzontale"
L["Hostile"] = "Ostile"
L["Hostility"] = "Ostilità"
L["Humanoid"] = "Umanoide"
L["Hybrid"] = "Ibrido"
L["Icon"] = "Icona"
L["Icon Function"] = "Funzione icona"
L["Icon Function (fallback state)"] = "Funzione icona (stato di riserva)"
L["Ignore Dead"] = "Ignora morti"
L["Ignore Disconnected"] = "Ignora disconnessi"
L["Ignore out of checking range"] = "Ignora fuori portata di controllo"
L["Ignore Rune CD"] = "Ignora CD delle rune"
L["Ignore Rune CDs"] = "Ignora CD delle rune"
L["Ignore Self"] = "Ignora te stesso"
L["Ignore Spell Cooldown/Charges"] = "Ignora tempo di recupero/cariche dell'incantesimo"
L["Ignore Spell Override"] = "Ignora sostituzione dell'incantesimo"
L["Important"] = "Importante"
L["Importing will start after combat ends."] = "L'importazione inizierà al termine del combattimento."
L["In Combat"] = "In combattimento"
L["In Encounter"] = "In un incontro"
L["In Group"] = "In gruppo"
L["In Party"] = "In gruppo"
L["In Pet Battle"] = "In scontro tra mascotte"
L["In Raid"] = "In incursione"
L["In Range"] = "In portata"
L["In Vehicle"] = "In veicolo"
L["In War Mode"] = "In modalità guerra"
L["Include Bank"] = "Includi banca"
L["Include Charges"] = "Includi cariche"
L["Include Death Runes"] = "Includi rune della morte"
L["Include Pets"] = "Includi animali"
L["Include War Band Bank"] = "Includi banca della Brigata"
L["Incoming Heal"] = "Cure in arrivo"
L["Increase Precision Below"] = "Aumenta la precisione sotto"
L["Increases by one per stage or intermission."] = "Aumenta di uno per fase o intermezzo."
L["Information"] = "Informazioni"
L["Inherited"] = "Ereditato"
L["Instakill"] = "Morte istantanea"
L["Install the addons BugSack and BugGrabber for detailed error logs."] = "Installa gli addon BugSack e BugGrabber per registri degli errori dettagliati."
L["Instance"] = "Istanza"
L["Instance Difficulty"] = "Difficoltà dell'istanza"
L["Instance Id"] = "Id istanza"
L["Instance ID"] = "ID istanza"
L["Instance Info"] = "Info sull'istanza"
L["Instance Name"] = "Nome dell'istanza"
L["Instance Size Type"] = "Tipo di dimensione dell'istanza"
L["Instance Type"] = "Tipo di istanza"
L["Instructor Razuvious"] = "Istruttore Razuvious"
L["Insufficient Resources"] = "Risorse insufficienti"
L["Intellect"] = "Intelletto"
L["Interrupt"] = "Interruzione"
L["Interrupt School"] = "Scuola interrotta"
L["Interrupted School Text"] = "Testo della scuola interrotta"
L["Interruptible"] = "Interrompibile"
L["Inverse"] = "Inverso"
L["Inverse Pet Behavior"] = "Comportamento inverso dell'animale"
L["Is Away from Keyboard"] = "È assente dalla tastiera"
L["Is Current Specialization"] = "È la specializzazione attuale"
L["Is Death Rune"] = "È una runa della morte"
L["Is Exactly"] = "È esattamente"
L["Is Moving"] = "È in movimento"
L["Is Off Hand"] = "È nella mano secondaria"
L["Is Paragon Reputation"] = "È una reputazione Paragon"
L["Is Paused"] = "È in pausa"
L["is useable"] = "è utilizzabile"
L["Is Weekly Renown Capped"] = "Limite settimanale di Rinomanza raggiunto"
L["Island Expedition (Heroic)"] = "Spedizione sulle isole (Eroica)"
L["Island Expedition (Mythic)"] = "Spedizione sulle isole (Mitica)"
L["Island Expedition (Normal)"] = "Spedizione sulle isole (Normale)"
L["Island Expeditions (PvP)"] = "Spedizioni sulle isole (PvP)"
L["Item"] = "Oggetto"
L["Item Bonus Id"] = "ID bonus oggetto"
L["Item Bonus Id Equipped"] = "ID bonus oggetto equipaggiato"
L["Item Count"] = "Numero di oggetti"
L["Item Equipped"] = "Oggetto equipaggiato"
L["Item Id"] = "ID oggetto"
L["Item in Range"] = "Oggetto a portata"
L["Item Name"] = "Nome dell'oggetto"
L["Item Set Equipped"] = "Set di oggetti equipaggiato"
L["Item Set Id"] = "ID set di oggetti"
L["Item Slot"] = "Slot dell'oggetto"
L["Item Slot String"] = "Stringa dello slot dell'oggetto"
L["Item Type"] = "Tipo di oggetto"
L["Item Type Equipped"] = "Tipo di oggetto equipaggiato"
L["Jin'do the Hexxer"] = "Jin'do l'Orco"
L["Journal Stage"] = "Fase del Diario"
L["Keep Inside"] = "Mantieni all'interno"
L["Large"] = "Grande"
L["Latency"] = "Latenza"
L["Leader"] = "Capo"
L["Least remaining time"] = "Minor tempo rimanente"
L["Leaving"] = "Uscita"
L["Leech"] = "Sanguisuga"
L["Leech (%)"] = "Sottrazione di vita (%)"
L["Leech Rating"] = "Valutazione di sottrazione di vita"
L["Left"] = "A sinistra"
L["Left to Right"] = "Da sinistra a destra"
L["Left, then Centered Vertical"] = "A sinistra, poi centrato verticalmente"
L["Left, then Down"] = "A sinistra, poi giù"
L["Left, then Up"] = "A sinistra, poi su"
L["Legacy Looking for Raid"] = "Ricerca incursione legacy"
L["Legacy RGB Gradient"] = "Gradiente RGB legacy"
L["Legacy RGB Gradient Pulse"] = "Pulsazione del gradiente RGB legacy"
L["Length"] = "Lunghezza"
L["Level"] = "Livello"
L["Limited"] = "Limitato"
L["Linear Texture"] = "Texture lineare"
L["Lines & Particles"] = "Linee e particelle"
L["Load Conditions"] = "Quando caricare"
L["Location"] = "Posizione"
L["Looking for Raid"] = "Ricerca incursione"
L["Loop"] = "Ciclo"
L["Loot"] = "Bottino"
L["Loot Specialization"] = "Specializzazione del bottino"
L["Loot Specialization Id"] = "ID specializzazione del bottino"
L["Loot Specialization Name"] = "Nome specializzazione del bottino"
L["Lord Kazzak"] = "Signore Kazzak"
L["Lost"] = "Perso"
L["Low Damage"] = "Danno basso"
L["Lower Than Tank"] = "Più basso del tank"
L["Lowest Spell Id"] = "ID incantesimo più basso"
L["Lua error"] = "Errore Lua"
L["Lua error in Aura '%s': %s"] = "Errore Lua nell'aura '%s': %s"
L["Magic"] = "Magia"
L["Main Character"] = "Personaggio principale"
L["Main Stat"] = "Statistica principale"
L["Majordomo Executus"] = "Maggiordomo Executus"
L["Malformed KUIAR_Runtime link"] = "Link KUIAR_Runtime malformato"
L["Manual"] = "Manuale"
L["Manual Icon"] = "Icona manuale"
L["Manual Rotation"] = "Rotazione manuale"
L["Marked First"] = "Segnato per primo"
L["Marked Last"] = "Segnato per ultimo"
L["Master"] = "Principale"
L["Mastery (%)"] = "Maestria (%)"
L["Mastery Rating"] = "Valutazione di maestria"
L["Match Count"] = "Numero di corrispondenze"
L["Match Count per Unit"] = "Numero di corrispondenze per unità"
L["Matches (Pattern)"] = "Corrisponde (schema)"
L["Matches stage number of encounter journal.\nIntermissions are .5\nE.g. 1;2;1;2;2.5;3"] = "Corrisponde al numero della fase nel Diario degli incontri.\nGli intermezzi sono .5\nEs. 1;2;1;2;2.5;3"
L["Max Char "] = "Caratteri max "
L["Max Char"] = "Caratteri max"
L["Max Charges"] = "Cariche massime"
L["Max Health"] = "Salute massima"
L["Max Power"] = "Potere massimo"
L["Max Quantity"] = "Quantità massima"
L["Maximum Estimate"] = "Stima massima"
L["Maximum Progress"] = "Avanzamento massimo"
L["Maximum time used on a single frame"] = "Tempo massimo usato in un singolo frame"
L["Medium"] = "Media"
L["Melee"] = "Corpo a corpo"
L["Melee Haste (%)"] = "Celerità in mischia (%)"
L["Message"] = "Messaggio"
L["Message Type"] = "Tipo di messaggio"
L["Message type:"] = "Tipo di messaggio:"
L["Meta Data"] = "Metadati"
L["Mine"] = "Mia"
L["Minimum Estimate"] = "Stima minima"
L["Minimum Progress"] = "Avanzamento minimo"
L["Minus (Small Nameplate)"] = "Meno (targhetta piccola)"
L["Mirror"] = "Specchio"
L["Miscellaneous"] = "Varie"
L["Miss"] = "Mancato"
L["Miss Type"] = "Tipo di mancato"
L["Missed"] = "Mancato"
L["Missing"] = "Mancante"
L["Model"] = "Modello"
L["Modern Blizzard (1h 3m | 3m 7s | 10s | 2.4)"] = "Blizzard moderno (1h 3m | 3m 7s | 10s | 2.4)"
L["Modernize"] = "Modernizza"
L["Molten Core"] = "Nucleo Fuso"
L["Money"] = "Denaro"
L["Monochrome"] = "Monocromatico"
L["Monochrome Outline"] = "Contorno monocromatico"
L["Monochrome Thick Outline"] = "Contorno spesso monocromatico"
L["Monster Emote"] = "Emote del mostro"
L["Monster Party"] = "Gruppo del mostro"
L["Monster Say"] = "Dire del mostro"
L["Monster Whisper"] = "Sussurro del mostro"
L["Monster Yell"] = "Urlo del mostro"
L["Moon"] = "Luna"
L["Most remaining time"] = "Maggior tempo rimanente"
L["Mounted"] = "In sella"
L["Mouse Cursor"] = "Cursore del mouse"
L["Movement Speed Rating"] = "Punteggio velocità di movimento"
L["Multi-target"] = "Bersagli multipli"
L["Mythic Keystone"] = "Chiave del Mitico"
L["Mythic+ Affix"] = "Affisso Mitico+"
L["Name"] = "Nome"
L["Name Function"] = "Funzione nome"
L["Name Function (fallback state)"] = "Funzione nome (stato di riserva)"
L["Name of Caster's Target"] = "Nome del bersaglio del lanciatore"
L["Name of the (sub-)zone currently shown above the minimap."] = "Nome della (sotto)zona mostrata attualmente sopra la minimappa."
L["Name(s)"] = "Nome/i"
L["Name/Realm of Caster's Target"] = "Nome/Reame del bersaglio del lanciatore"
L["Nameplate"] = "Targa nome"
L["Nameplates"] = "Barre delle unità"
L["Names of affected Players"] = "Nomi dei giocatori interessati"
L["Names of unaffected Players"] = "Nomi dei giocatori non interessati"
L["Nature Resistance"] = "Resistenza alla Natura"
L["Neutral"] = "Neutrale"
L["Never"] = "Mai"
L["Next Combat"] = "Prossimo combattimento"
L["Next Encounter"] = "Prossimo incontro"
L["No active boss mod addon detected.\n\nNote: This trigger will use BigWigs or DBM, in that order if both are installed."] = "Nessun addon per boss rilevato attivo.\n\nNota: questo innesco userà BigWigs o DBM, in quest'ordine se sono installati entrambi."
L["No Extend"] = "Nessuna estensione"
L["No Instance"] = "Nessuna istanza"
L["No Profiling information saved."] = "Nessuna informazione di profilazione salvata."
L["No Progress Information available."] = "Nessuna informazione sull'avanzamento disponibile."
L["None"] = "Nessuno"
L["Non-player Character"] = "Personaggio non giocante"
L["Normal"] = "Normale"
L["Normal Party"] = "Gruppo normale"
L["Not in Group"] = "Non in gruppo"
L["Not in Smart Group"] = "Non nel gruppo intelligente"
L["Not on Cooldown"] = "Non in ricarica"
L["Not On Threat Table"] = "Non nella tabella delle minacce"
L["Note: Due to how complicated the swing timer behavior is and the lack of APIs from Blizzard, results are inaccurate in edge cases."] = "Nota: data la complessità del comportamento del timer dei colpi e la mancanza di API da parte di Blizzard, i risultati sono imprecisi in casi limite."
L["Note: 'Hide Alone' is not available in the new aura tracking system. A load option can be used instead."] = "Nota: \"Nascondi se solo\" non è disponibile nel nuovo sistema di tracciamento delle aure. Si può usare invece un'opzione di caricamento."
L["Note: The available text replacements for multi triggers match the normal triggers now."] = "Nota: i testi sostitutivi disponibili per gli inneschi multipli ora corrispondono a quelli degli inneschi normali."
L["Note: This trigger internally stores the shapeshift position, and thus is incompatible with learning stances on the fly, like e.g. the Gladiator Rune."] = "Nota: questo innesco memorizza internamente la posizione di mutaforma, quindi è incompatibile con l'apprendimento di posture al volo, come ad esempio la Runa del Gladiatore."
L["Note: This trigger relies on the WoW API, which returns incorrect information in some cases."] = "Nota: questo innesco si basa sull'API di WoW, che in alcuni casi restituisce informazioni errate."
L["Uses UnitIsVisible() to check if game client has loaded a object for this unit. This distance is around 100 yards. This is polled every second."] = "Usa UnitIsVisible() per verificare se il client di gioco ha caricato un oggetto per questa unità. Questa distanza è di circa 100 metri. Viene controllata ogni secondo."
L["Note: This trigger type estimates the range to the hitbox of a unit. The actual range of friendly players is usually 3 yards more than the estimate. Range checking capabilities depend on your current class and known abilities as well as the type of unit being checked. Some of the ranges may also not work with certain NPCs.|n|n|cFFAAFFAAFriendly Units:|r %s|n|cFFFFAAAAHarmful Units:|r %s|n|cFFAAAAFFMiscellanous Units:|r %s"] = "Nota: questo tipo di innesco stima la distanza dalla hitbox di un'unità. La distanza effettiva dai giocatori amichevoli è di solito 3 metri superiore alla stima. Le capacità di controllo della distanza dipendono dalla tua classe attuale e dalle abilità note, oltre che dal tipo di unità controllata. Alcune distanze potrebbero inoltre non funzionare con certi PNG.|n|n|cFFAAFFAAUnità amichevoli:|r %s|n|cFFFFAAAAUnità ostili:|r %s|n|cFFAAAAFFUnità varie:|r %s"
L["Noth the Plaguebringer"] = "Noth il Pestilente"
L["NPC"] = "PNG"
L["Npc ID"] = "ID PNG"
L["Number"] = "Numero"
L["Number Affected"] = "Numero di interessati"
L["Object"] = "Oggetto"
L["Occurrence of the event\nCan be a range of values\nCan have multiple values separated by a comma or a space\n\nExamples:\n2nd 5th and 6th events: 2, 5, 6\n2nd to 6th: 2-6\nevery 2 events: /2\nevery 3 events starting from 2nd: 2/3\nevery 3 events starting from 2nd and ending at 11th: 2-11/3\n\nWorks only if Boss Mod addon show counter"] = "Occorrenza dell'evento\nPuò essere un intervallo di valori\nPuò avere più valori separati da una virgola o da uno spazio\n\nEsempi:\n2°, 5° e 6° evento: 2, 5, 6\ndal 2° al 6°: 2-6\nogni 2 eventi: /2\nogni 3 eventi a partire dal 2°: 2/3\nogni 3 eventi a partire dal 2° e fino all'11°: 2-11/3\n\nFunziona solo se l'addon per boss mostra il contatore"
L["Occurrence of the event, reset when aura is unloaded\nCan be a range of values\nCan have multiple values separated by a comma or a space\n\nExamples:\n2nd 5th and 6th events: 2, 5, 6\n2nd to 6th: 2-6\nevery 2 events: /2\nevery 3 events starting from 2nd: 2/3\nevery 3 events starting from 2nd and ending at 11th: 2-11/3\n\nOnly if BigWigs shows it on it's bar"] = "Occorrenza dell'evento, azzerata quando l'aura viene scaricata\nPuò essere un intervallo di valori\nPuò avere più valori separati da una virgola o da uno spazio\n\nEsempi:\n2°, 5° e 6° evento: 2, 5, 6\ndal 2° al 6°: 2-6\nogni 2 eventi: /2\nogni 3 eventi a partire dal 2°: 2/3\nogni 3 eventi a partire dal 2° e fino all'11°: 2-11/3\n\nSolo se BigWigs lo mostra sulla sua barra"
L["Occurrence of the event, reset when aura is unloaded\nCan be a range of values\nCan have multiple values separated by a comma or a space\n\nExamples:\n2nd 5th and 6th events: 2, 5, 6\n2nd to 6th: 2-6\nevery 2 events: /2\nevery 3 events starting from 2nd: 2/3\nevery 3 events starting from 2nd and ending at 11th: 2-11/3\n\nOnly if DBM shows it on it's bar"] = "Occorrenza dell'evento, azzerata quando l'aura viene scaricata\nPuò essere un intervallo di valori\nPuò avere più valori separati da una virgola o da uno spazio\n\nEsempi:\n2°, 5° e 6° evento: 2, 5, 6\ndal 2° al 6°: 2-6\nogni 2 eventi: /2\nogni 3 eventi a partire dal 2°: 2/3\nogni 3 eventi a partire dal 2° e fino all'11°: 2-11/3\n\nSolo se DBM lo mostra sulla sua barra"
L["Officer"] = "Ufficiale"
L["Offset from progress"] = "Sfasamento dall'avanzamento"
L["Offset Timer"] = "Sfasamento timer"
L["Old Blizzard (2h | 3m | 10s | 2.4)"] = "Vecchio stile Blizzard (2h | 3m | 10s | 2.4)"
L["On Cooldown"] = "In recupero"
L["On Taxi"] = "In volo"
L["Only if on a different realm"] = "Solo se su un reame diverso"
L["Only if Primary"] = "Solo se primaria"
L["Opaque"] = "Opaco"
L["Option Group"] = "Gruppo di opzioni"
L["Options could not be loaded, the addon is %s"] = "Impossibile caricare le opzioni, l'addon è %s"
L["Options will finish loading after combat ends."] = "Le opzioni termineranno il caricamento al termine del combattimento."
L["Options will open after the login process has completed."] = "Le opzioni si apriranno al termine del processo di accesso."
L["Or Talent"] = "O talento"
L["Orbit"] = "Orbita"
L["Orientation"] = "Orientamento"
L["Ossirian the Unscarred"] = "Ossirian l'Invulnerabile"
L["Other"] = "Altro"
L["Other Addons"] = "Altri addon"
L["Other Events"] = "Altri eventi"
L["Outline"] = "Contorno"
L["Over Energize"] = "Energia in eccesso"
L["Overhealing"] = "Sovracura"
L["Overkill"] = "Danno in eccesso"
L["Overlay %s"] = "Sovrapposizione %s"
L["Overlay Charged Combo Points"] = "Sovrapponi punti combo caricati"
L["Overlay Cost of Casts"] = "Sovrapponi costo dei lanci"
L["Overlay Latency"] = "Sovrapponi latenza"
L["Pad"] = "Riempimento"
L["Pad Mode"] = "Modalità riempimento"
L["Pad to"] = "Riempi fino a"
L["Paragon Reputation"] = "Reputazione Paragon"
L["Paragon Reward Pending"] = "Ricompensa Paragon in attesa"
L["Parent Frame"] = "Riquadro genitore"
L["Parent Zone"] = "Zona genitore"
L["Parry"] = "Parata"
L["Parry (%)"] = "Parata (%)"
L["Parry Rating"] = "Punteggio parata"
L["Party"] = "Gruppo"
L["Party Kill"] = "Uccisione del gruppo"
L["Path of Ascension: Courage"] = "Via dell'Ascensione: Coraggio"
L["Path of Ascension: Humility"] = "Via dell'Ascensione: Umiltà"
L["Path of Ascension: Loyalty"] = "Via dell'Ascensione: Lealtà"
L["Path of Ascension: Wisdom"] = "Via dell'Ascensione: Saggezza"
L["Paused"] = "In pausa"
L["Periodic Spell"] = "Incantesimo periodico"
L["Personal Resource Display"] = "Visualizzazione risorsa personale"
L["Pet"] = "Famiglio"
L["Pet Behavior"] = "Comportamento del famiglio"
L["Pet Specialization"] = "Specializzazione del famiglio"
L["Pet Spell"] = "Incantesimo del famiglio"
L["Pets only"] = "Solo famigli"
L["Phase"] = "Fase"
L["Pixel Glow"] = "Bagliore pixel"
L["Placement"] = "Posizionamento"
L["Placement %i"] = "Posizionamento %i"
L["Placement Mode"] = "Modalità di posizionamento"
L["Play"] = "Riproduci"
L["Player"] = "Giocatore"
L["Player Character"] = "Personaggio giocante"
L["Player Class"] = "Classe del giocatore"
L["Player Effective Level"] = "Livello effettivo del giocatore"
L["Player Experience"] = "Esperienza del giocatore"
L["Player Faction"] = "Fazione del giocatore"
L["Player Level"] = "Livello del giocatore"
L["Player Location ID(s)"] = "ID posizione del giocatore"
L["Player Money"] = "Denaro del giocatore"
L["Player Name/Realm"] = "Nome/Reame del giocatore"
L["Player Race"] = "Razza del giocatore"
L["Player(s) Affected"] = "Giocatore/i interessato/i"
L["Player(s) Not Affected"] = "Giocatore/i non interessato/i"
L["Player/Unit Info"] = "Info giocatore/unità"
L["Players and Pets"] = "Giocatori e famigli"
L["Poison"] = "Veleno"
L["Power"] = "Risorsa"
L["Power (%)"] = "Potere (%)"
L["Power Deficit"] = "Deficit di potere"
L["Power Type"] = "Tipo di risorsa"
L["Precision"] = "Precisione"
L["Preset"] = "Preimpostazione"
L["Primary Stats"] = "Statistiche primarie"
L["Princess Huhuran"] = "Principessa Huhuran"
L["Print Profiling Results"] = "Stampa risultati di profilazione"
L["Proc Glow"] = "Bagliore di proc"
L["Profiling already started."] = "La profilazione è già avviata."
L["Profiling automatically started."] = "Profilazione avviata automaticamente."
L["Profiling not running."] = "La profilazione non è in esecuzione."
L["Profiling started."] = "Profilazione avviata."
L["Profiling started. It will end automatically in %d seconds"] = "Profilazione avviata. Terminerà automaticamente tra %d secondi"
L["Profiling still running, stop before trying to print."] = "La profilazione è ancora in esecuzione, fermala prima di provare a stampare."
L["Profiling stopped."] = "Profilazione interrotta."
L["Progress"] = "Progressi"
L["Progress Source"] = "Fonte di avanzamento"
L["Progress Total"] = "Avanzamento totale"
L["Progress Value"] = "Valore di avanzamento"
L["Pulse"] = "Pulsazione"
L["PvP Flagged"] = "Marcato PvP"
L["PvP Mode Active"] = "Modalità PvP attiva"
L["PvP Talent selected"] = "Talento PvP selezionato"
L["PvP Talent Selected"] = "Talento PvP selezionato"
L["Quality Id"] = "ID qualità"
L["Quantity"] = "Quantità"
L["Quantity earned this week"] = "Quantità ottenuta questa settimana"
L["Quest Party"] = "Gruppo missione"
L["Queued Action"] = "Azione in coda"
L["Radius"] = "Raggio"
L["Raid"] = "Incursione"
L["Raid (Heroic)"] = "Raid (Eroico)"
L["Raid (Mythic)"] = "Raid (Mitico)"
L["Raid (Normal)"] = "Raid (Normale)"
L["Raid (Timewalking)"] = "Raid (Viaggio nel Tempo)"
L["Raid Mark"] = "Contrassegno raid"
L["Raid Mark Icon"] = "Icona contrassegno raid"
L["Raid Role"] = "Ruolo raid"
L["Raid Warning"] = "Avviso raid"
L["Raids"] = "Incursioni"
L["Range"] = "Portata"
L["Range Check"] = "Controllo distanza"
L["Ranged"] = "A distanza"
L["Rank"] = "Grado"
L["Rare"] = "Raro"
L["Rare Elite"] = "Elite raro"
L["Rated Arena"] = "Arena classificata"
L["Rated Battleground"] = "Campo di battaglia classificato"
L["Raw Threat Percent"] = "Percentuale di minaccia grezza"
L["Razorgore the Untamed"] = "Razorgore l'Indomito"
L["Ready Check"] = "Appello"
L["Reagent Quality"] = "Qualità del reagente"
L["Reagent Quality Texture"] = "Texture qualità del reagente"
L["Realm"] = "Reame"
L["Realm Name"] = "Nome del reame"
L["Realm of Caster's Target"] = "Reame del bersaglio del lanciatore"
L["Reborn Council"] = "Consiglio Rinato"
L["Receiving %s Bytes"] = "Ricezione di %s byte"
L["Receiving display information"] = "Ricezione delle informazioni di visualizzazione"
L["Reflect"] = "Riflesso"
L["Region type %s not supported"] = "Tipo di regione %s non supportato"
L["Relative"] = "Relativo"
L["Relative X-Offset"] = "Scostamento X relativo"
L["Relative Y-Offset"] = "Scostamento Y relativo"
L["Remaining Duration"] = "Durata rimanente"
L["Remaining Time"] = "Tempo rimasto"
L["Remove Obsolete Auras"] = "Rimuovi aure obsolete"
L["Renown Level"] = "Livello di fama"
L["Renown Max Level"] = "Livello massimo di fama"
L["Renown Reputation"] = "Reputazione di fama"
L["Repair"] = "Riparazione"
L["Repeat"] = "Ripeti"
L["Report Summary"] = "Riepilogo del rapporto"
L["Reputation"] = "Reputazione"
L["Reputation (%)"] = "Reputazione (%)"
L["Requested display does not exist"] = "La visualizzazione richiesta non esiste"
L["Requested display not authorized"] = "Visualizzazione richiesta non autorizzata"
L["Requesting display information from %s ..."] = "Richiesta delle informazioni di visualizzazione a %s ..."
L["Require Valid Target"] = "Richiedi bersaglio valido"
L["Requires syncing the specialization via LibSpecialization."] = "Richiede la sincronizzazione della specializzazione tramite LibSpecialization."
L["Resilience (%)"] = "Resilienza (%)"
L["Resilience Rating"] = "Punteggio resilienza"
L["Resist"] = "Resistenza"
L["Resistances"] = "Resistenze"
L["Resisted"] = "Resistito"
L["Rested"] = "Riposato"
L["Rested Experience"] = "Esperienza riposata"
L["Rested Experience (%)"] = "Esperienza riposata (%)"
L["Resting"] = "In riposo"
L["Resurrect"] = "Resurrezione"
L["Resurrect Pending"] = "Resurrezione in attesa"
L["Right"] = "Destra"
L["Right to Left"] = "Da destra a sinistra"
L["Right, then Centered Vertical"] = "A destra, poi centrato in verticale"
L["Right, then Down"] = "A destra, poi in basso"
L["Right, then Up"] = "A destra, poi in alto"
L["Role"] = "Ruolo"
L["Rollback snapshot is complete. Thank you for your patience!"] = "Lo snapshot di ripristino è completo. Grazie per la pazienza!"
L["Rotate Animation"] = "Animazione di rotazione"
L["Rotate Left"] = "Ruota a sinistra"
L["Rotate Right"] = "Ruota a destra"
L["Rotation"] = "Rotazione"
L["Round"] = "Rotondo"
L["Round Mode"] = "Modalità di arrotondamento"
L["Ruins of Ahn'Qiraj"] = "Rovine di Ahn'Qiraj"
L["Run Custom Code"] = "Esegui codice personalizzato"
L["Run Speed (%)"] = "Velocità di corsa (%)"
L["Rune"] = "Runa"
L["Rune #1"] = "Runa n. 1"
L["Rune #2"] = "Runa n. 2"
L["Rune #3"] = "Runa n. 3"
L["Rune #4"] = "Runa n. 4"
L["Rune #5"] = "Runa n. 5"
L["Rune #6"] = "Runa n. 6"
L["Rune Count"] = "Numero di rune"
L["Rune Count - Blood"] = "Numero di rune - Sangue"
L["Rune Count - Frost"] = "Numero di rune - Gelo"
L["Rune Count - Unholy"] = "Numero di rune - Empio"
L["Say"] = "Parla"
L["Scale"] = "Scala"
L["Scarlet Enclave"] = "Enclave Scarlatta"
L["Scenario (Heroic)"] = "Scenario (Eroico)"
L["Scenario (Normal)"] = "Scenario (Normale)"
L["Screen"] = "Schermo"
L["Screen/Parent Group"] = "Schermo/Gruppo genitore"
L["Season of Discovery"] = "Stagione della Scoperta"
L["Second"] = "Secondo"
L["Second Value of Tooltip Text"] = "Secondo valore del testo della descrizione"
L["Secondary Stats"] = "Statistiche secondarie"
L["Seconds"] = "Secondi"
L["Secure frame detected. Find more information:\nhttps://github.com/m33shoq/M33kAuras/wiki/Protected-Frames"] = "Riquadro protetto rilevato. Maggiori informazioni:\nhttps://github.com/m33shoq/M33kAuras/wiki/Protected-Frames"
L["Select Frame"] = "Seleziona riquadro"
L["Select the type of timer to filter"] = "Seleziona il tipo di timer da filtrare"
L["Selection Mode"] = "Modalità di selezione"
L["Separator"] = "Separatore"
L["Set IDs can be found on websites such as wowhead.com/cata/item-sets"] = "Gli ID dei set si trovano su siti come wowhead.com/cata/item-sets"
L["Set IDs can be found on websites such as wowhead.com/classic/item-sets"] = "Gli ID dei set si trovano su siti come wowhead.com/classic/item-sets"
L["Set IDs can be found on websites such as wowhead.com/forever/item-sets"] = "Gli ID dei set si trovano su siti come wowhead.com/forever/item-sets"
L["Set IDs can be found on websites such as wowhead.com/item-sets"] = "Gli ID dei set si trovano su siti come wowhead.com/item-sets"
L["Set IDs can be found on websites such as wowhead.com/mop-classic/item-sets"] = "Gli ID dei set si trovano su siti come wowhead.com/mop-classic/item-sets"
L["Shadow Resistance"] = "Resistenza alle Ombre"
L["Shake"] = "Scossa"
L["Shift-Click to resume addon execution."] = "Maiusc+clic per riprendere l'esecuzione dell'addon."
L["Show"] = "Mostra"
L["Show CD of Charge"] = "Mostra recupero della carica"
L["Show charged duration for empowered casts"] = "Mostra durata di carica per i lanci potenziati"
L["Show GCD"] = "Mostra GCD"
L["Show Global Cooldown"] = "Mostra tempo di recupero globale"
L["Show Incoming Heal"] = "Mostra cure in arrivo"
L["Show Loss of Control"] = "Mostra perdita di controllo"
L["Show On"] = "Mostra su"
L["Show Rested Overlay"] = "Mostra sovrapposizione riposo"
L["Shrink"] = "Rimpicciolire"
L["Silithid Royalty"] = "Famiglia reale Silithid"
L["Silver"] = "Argento"
L["Simple"] = "Semplice"
L["Since Active"] = "Da quando è attivo"
L["Since Apply"] = "Da quando applicato"
L["Since Apply/Refresh"] = "Da applicazione/rinnovo"
L["Since Charge Gain"] = "Da guadagno carica"
L["Since Charge Lost"] = "Da perdita carica"
L["Since Ready"] = "Da quando è pronto"
L["Since Stack Gain"] = "Da guadagno cumulo"
L["Since Stack Lost"] = "Da perdita cumulo"
L["Size & Position"] = "Dimensione e posizione"
L["Skyriding"] = "Volo Dinamico"
L["Slide Animation"] = "Animazione di scorrimento"
L["Slide from Bottom"] = "Scorri dal basso"
L["Slide from Left"] = "Scorri da sinistra"
L["Slide from Right"] = "Scorri da destra"
L["Slide from Top"] = "Scorri dall'alto"
L["Slide to Bottom"] = "Scorri verso il basso"
L["Slide to Left"] = "Scorri verso sinistra"
L["Slide to Right"] = "Scorri verso destra"
L["Slide to Top"] = "Scorri verso l'alto"
L["Slider"] = "Cursore di scorrimento"
L["Small"] = "Piccolo"
L["Smart Group"] = "Gruppo intelligente"
L["Soft Enemy"] = "Nemico morbido"
L["Soft Friend"] = "Amico morbido"
L["Sound"] = "Suono"
L["Sound by Kit ID"] = "Suono per ID Sound Kit"
L["Source"] = "Fonte"
L["Source Affiliation"] = "Affiliazione della fonte"
L["Source GUID"] = "GUID della fonte"
L["Source Info"] = "Info fonte"
L["Source Name"] = "Nome della fonte"
L["Source NPC Id"] = "ID PNG della fonte"
L["Source Object Type"] = "Tipo di oggetto della fonte"
L["Source Raid Mark"] = "Contrassegno raid della fonte"
L["Source Reaction"] = "Reazione della fonte"
L["Source Unit"] = "Unità fonte"
L["Source Unit Name/Realm"] = "Nome/Reame dell'unità fonte"
L["Source unit's raid mark index"] = "Indice del contrassegno raid dell'unità fonte"
L["Source unit's raid mark texture"] = "Texture del contrassegno raid dell'unità fonte"
L["Space"] = "Spazio"
L["Spacing"] = "Spaziatura"
L["Spark"] = "Scintilla"
L["Spec Position"] = "Posizione specializzazione"
L["Spec Role"] = "Ruolo specializzazione"
L["Specialization"] = "Specializzazione"
L["Specific Currency"] = "Valuta specifica"
L["Specific Type"] = "Tipo specifico"
L["Specific Unit"] = "Unità specifica"
L["Spell"] = "Incantesimo"
L["Spell (Building)"] = "Incantesimo (in costruzione)"
L["Spell Activation Overlay Glow"] = "Bagliore di attivazione incantesimo"
L["Spell Cast Succeeded"] = "Lancio incantesimo riuscito"
L["Spell Cost"] = "Costo dell'incantesimo"
L["Spell Count"] = "Conteggio incantesimi"
L["Spell ID"] = "ID incantesimo"
L["Spell Id"] = "ID incantesimo"
L["Spell ID:"] = "ID incantesimo:"
L["Spell IDs:"] = "ID incantesimo:"
L["Spell in Range"] = "Incantesimo a portata"
L["Spell Known"] = "Incantesimo noto"
L["Spell Name"] = "Nome dell'incantesimo"
L["Spell Penetration"] = "Penetrazione degli incantesimi"
L["Spell Peneration Percent"] = "Percentuale di penetrazione degli incantesimi"
L["Spell Power"] = "Potere degli incantesimi"
L["Spell School"] = "Scuola di magia"
L["Spell Usable"] = "Incantesimo utilizzabile"
L["Spellname"] = "Nome incantesimo"
L["Spike"] = "Punta"
L["Spin"] = "Giro"
L["Spiral"] = "Spirale"
L["Spiral In And Out"] = "Spirale in entrata e in uscita"
L["Spirit"] = "Spirito"
L["Stack Count"] = "Numero di accumuli"
L["Stack trace:"] = "Traccia dello stack:"
L["Stacks"] = "Accumuli"
L["Stacks Function"] = "Funzione cariche"
L["Stacks Function (fallback state)"] = "Funzione cariche (stato di riserva)"
L["Stage"] = "Fase"
L["Stage Counter"] = "Contatore fase"
L["Stagger"] = "Barcollamento"
L["Stagger (%)"] = "Barcollamento (%)"
L["Stagger against Target (%)"] = "Barcollamento contro il bersaglio (%)"
L["Stagger Scale"] = "Scala barcollamento"
L["Stamina"] = "Tempra"
L["Stance/Form/Aura"] = "Postura/Forma/Aura"
L["Standing"] = "Posizione"
L["Star Shake"] = "Scossa di stelle"
L["Start Animation"] = "Animazione iniziale"
L["Start Now"] = "Inizia ora"
L["Start Profiling"] = "Avvia profilazione"
L["Status"] = "Stato"
L["Status Bar"] = "Barra di stato"
L["Stolen"] = "Rubato"
L["Stop"] = "Ferma"
L["Stop Motion"] = "Stop motion"
L["Story Raid"] = "Raid della storia"
L["Strength"] = "Forza"
L["String"] = "Stringa"
L["Subevent Info"] = "Info sottoevento"
L["Subtract Cast"] = "Sottrai lancio"
L["Subtract Channel"] = "Sottrai canalizzazione"
L["Subtract GCD"] = "Sottrai GCD"
L["Subzone Name"] = "Nome sottozona"
L["Success"] = "Successo"
L["Sulfuron Harbinger"] = "Araldo Sulfuron"
L["Summon"] = "Evocazione"
L["Summon Pending"] = "Evocazione in attesa"
L["Sun"] = "Sole"
L["Supports multiple entries, separated by commas"] = "Supporta più voci, separate da virgole"
L["Supports multiple entries, separated by commas\n"] = "Supporta più voci, separate da virgole\n"
L["Supports multiple entries, separated by commas. Escape ',' with \\. Prefix with '-' for negation."] = "Supporta più voci, separate da virgole. Usa \\ per il carattere ','. Prefisso '-' per negare."
L["Supports multiple entries, separated by commas. Escape with \\. Prefix with '-' for negation."] = "Supporta più voci, separate da virgole. Usa \\ per l'escape. Prefisso '-' per negare."
L["Supports multiple entries, separated by commas. Prefix with '-' for negation."] = "Supporta più voci, separate da virgole. Prefisso '-' per negare."
L["Supports multiple entries, separated by commas. To include child zone ids, prefix with 'c', e.g. 'c2022'.\nGroup Zone IDs must be prefixed with 'g', e.g. 'g277'.\nSupports Area IDs from https://wago.tools/db2/AreaTable prefixed with 'a'.\nSupports Instance IDs prefixed with 'i'.\nEntries can be prefixed with '-' to negate."] = "Supporta più voci, separate da virgole. Per includere gli ID delle zone figlie, usa il prefisso 'c', ad es. 'c2022'.\nGli ID delle zone di gruppo devono avere il prefisso 'g', ad es. 'g277'.\nSupporta gli ID area da https://wago.tools/db2/AreaTable con il prefisso 'a'.\nSupporta gli ID istanza con il prefisso 'i'.\nLe voci possono avere il prefisso '-' per negare."
L["Swing"] = "Colpo"
L["Swing Timer"] = "Timer dei colpi"
L["Swipe"] = "Animazione"
L["Syntax /wa feature <toggle|on|enable|disable|off> <feature>"] = "Sintassi /wa feature <toggle|on|enable|disable|off> <feature>"
L["System"] = "Sistema"
L["Systems"] = "Sistemi"
L["Tab "] = "Scheda"
L["Talent"] = "Talento"
L["Talent |cFFFF0000Not|r Known"] = "Talento |cFFFF0000non|r noto"
L["Talent |cFFFF0000Not|r Selected"] = "Talento |cFFFF0000non|r selezionato"
L["Talent Known"] = "Talento noto"
L["Talent Selected"] = "Talento selezionato"
L["Talent selected"] = "Talento selezionato"
L["Talent Specialization"] = "Specializzazione dei talenti"
L["Tanking And Highest"] = "Tank e più alto"
L["Tanking But Not Highest"] = "Tank ma non il più alto"
L["Target"] = "Bersaglio"
L["Targeted"] = "Bersagliato"
L["Tertiary Stats"] = "Statistiche terziarie"
L["Test if bar is enabled in BigWigs settings"] = "Verifica se la barra è attivata nelle impostazioni di BigWigs"
L["Test if bar is enabled in Boss Mod addon settings"] = "Verifica se la barra è attivata nelle impostazioni dell'addon per boss"
L["Test if bar is enabled in DBM settings"] = "Verifica se la barra è attivata nelle impostazioni di DBM"
L["Text"] = "Testo"
L["Text To Speech"] = "Sintesi vocale"
L["Text-to-speech"] = "Sintesi vocale"
L["Texture Function"] = "Funzione texture"
L["Texture Function (fallback state)"] = "Funzione texture (stato di riserva)"
L["Texture Picker"] = "Selettore texture"
L["Texture Rotation"] = "Rotazione texture"
L["The aura has overwritten the global '%s', this might affect other auras."] = "L'aura ha sovrascritto il globale '%s', questo potrebbe influire su altre aure."
L["The aura tried to overwrite the aura_env global, which is not allowed."] = "L'aura ha tentato di sovrascrivere il globale aura_env, cosa non consentita."
L["The effective level differs from the level in e.g. Time Walking dungeons."] = "Il livello effettivo differisce dal livello ad es. nelle spedizioni del Viaggio nel Tempo."
L["The Four Horsemen"] = "I Quattro Cavalieri"
L["The 'ID' value can be found in the BigWigs options of a specific spell"] = "Il valore 'ID' si trova nelle opzioni di BigWigs di un incantesimo specifico"
L["The Prophet Skeram"] = "Il Profeta Skeram"
L["The total quantity a warband character can transfer after paying the transfer cost"] = "La quantità totale che un personaggio della Brigata può trasferire dopo aver pagato il costo di trasferimento"
L["The total quantity after transferring everything to your current character and paying the transfer cost"] = "La quantità totale dopo aver trasferito tutto al tuo personaggio attuale e pagato il costo di trasferimento"
L["There are %i updates to your auras ready to be installed!"] = "Ci sono %i aggiornamenti alle tue aure pronti per l'installazione!"
L["Thick Outline"] = "Contorno spesso"
L["Thickness"] = "Spessore"
L["Third"] = "Terzo"
L["Third Value of Tooltip Text"] = "Terzo valore del testo della descrizione"
L["This aura calls GetData a lot, which is a slow function."] = "Questa aura chiama spesso GetData, che è una funzione lenta."
L["This aura has caused a Lua error."] = "Questa aura ha causato un errore Lua."
L["This aura is saving %s KB of data"] = "Questa aura sta salvando %s KB di dati"
L["This aura plays a sound via a condition."] = "Questa aura riproduce un suono tramite una condizione."
L["This aura plays a sound via an action."] = "Questa aura riproduce un suono tramite un'azione."
L["This aura plays a Text To Speech via a condition."] = "Questa aura riproduce una sintesi vocale tramite una condizione."
L["This aura plays a Text To Speech via an action."] = "Questa aura riproduce una sintesi vocale tramite un'azione."
L["Threat Percent"] = "Percentuale di minaccia"
L["Threat Situation"] = "Situazione di minaccia"
L["Threat Value"] = "Valore di minaccia"
L["Tick"] = "Tacca"
L["Time"] = "Tempo"
L["Time Format"] = "Formato dell'ora"
L["Time in GCDs"] = "Tempo in GCD"
L["Time since initial application"] = "Tempo dalla prima applicazione"
L["Time since last refresh"] = "Tempo dall'ultimo rinnovo"
L["Time since stack gain"] = "Tempo dal guadagno di cariche"
L["Time since stack lost"] = "Tempo dalla perdita di cariche"
L["Timed"] = "A tempo"
L["Timed Progress"] = "Avanzamento a tempo"
L["Timer Id"] = "ID timer"
L["Toggle"] = "Attiva/disattiva"
L["Toggle List"] = "Attiva/disattiva elenco"
L["Toggle Options Window"] = "Mostra/nascondi finestra delle opzioni"
L["Toggle Performance Profiling Window"] = "Mostra/nascondi finestra di profilazione delle prestazioni"
L["Tooltip"] = "Descrizione"
L["Tooltip 1"] = "Descrizione 1"
L["Tooltip 2"] = "Descrizione 2"
L["Tooltip 3"] = "Descrizione 3"
L["Tooltip Value 1"] = "Valore della descrizione 1"
L["Tooltip Value 2"] = "Valore della descrizione 2"
L["Tooltip Value 3"] = "Valore della descrizione 3"
L["Tooltip Value 4"] = "Valore della descrizione 4"
L["Top"] = "Alto"
L["Top Left"] = "In alto a sinistra"
L["Top Right"] = "In alto a destra"
L["Top to Bottom"] = "Dall'alto in basso"
L["Total Duration"] = "Durata totale"
L["Total Earned in this Season"] = "Totale guadagnato in questa stagione"
L["Total Essence"] = "Essenza totale"
L["Total Experience"] = "Esperienza totale"
L["Total Match Count"] = "Numero totale di corrispondenze"
L["Total Reputation"] = "Reputazione totale"
L["Total Stacks"] = "Cariche totali"
L["Total stacks over all matches"] = "Cariche totali su tutte le corrispondenze"
L["Total Stages"] = "Fasi totali"
L["Total Unit Count"] = "Numero totale di unità"
L["Total Units"] = "Unità totali"
L["Totem #%i"] = "Totem n. %i"
L["Totem Icon"] = "Icona totem"
L["Totem Name"] = "Nome totem"
L["Totem Name Pattern Match"] = "Corrispondenza del modello del nome del totem"
L["Totem Number"] = "Numero totem"
L["Track Cooldowns"] = "Traccia tempi di recupero"
L["Tracking Charge %i"] = "Traccia carica %i"
L["Tracking Charge CDs"] = "Traccia TR delle cariche"
L["Tracking Only Cooldown"] = "Traccia solo tempo di recupero"
L["Transmission error"] = "Errore di trasmissione"
L["Trigger"] = "Attivazione"
L["Trigger %i"] = "Innesco %i"
L["Trigger %s"] = "Innesco %s"
L["Trigger 1"] = "Innesco 1"
L["Trigger State Updater (Advanced)"] = "Aggiornatore di stato dell'innesco (avanzato)"
L["Trigger Update"] = "Aggiornamento innesco"
L["Trigger:"] = "Innesco:"
L["Trivial (Low Level)"] = "Banale (livello basso)"
L["True"] = "Vero"
L["Trying to repair broken conditions in %s likely caused by a KUIAR_Runtime bug."] = "Tentativo di riparare le condizioni danneggiate in %s, probabilmente causate da un bug di KUIAR_Runtime."
L["Twin Emperors"] = "Imperatori Gemelli"
L["Type"] = "Tipo"
L["Unable to modernize aura '%s'. This is probably due to corrupt data or a bad migration, please report this to m33shoq."] = "Impossibile modernizzare l'aura '%s'. Probabilmente per dati danneggiati o una migrazione errata, segnalalo a m33shoq."
L["Unaffected"] = "Non interessato"
L["Undefined"] = "Non definito"
L["Unholy"] = "Empio"
L["Unholy Rune #1"] = "Runa empia n. 1"
L["Unholy Rune #2"] = "Runa empia n. 2"
L["Unit"] = "Unità"
L["Unit Characteristics"] = "Caratteristiche dell'unità"
L["Unit Destroyed"] = "Unità distrutta"
L["Unit Died"] = "Unità morta"
L["Unit Dissipates"] = "Unità dissipata"
L["Unit Frame"] = "Riquadro unità"
L["Unit Frames"] = "Riquadri unità"
L["Unit is Unit"] = "L'unità è l'unità"
L["Unit Name"] = "Nome unità"
L["Unit Name/Realm"] = "Nome/Reame unità"
L["Units Affected"] = "Unità interessate"
L["Units of affected Players in a table format"] = "Unità dei giocatori interessati in formato tabella"
L["Units of unaffected Players in a table format"] = "Unità dei giocatori non interessati in formato tabella"
L["Unknown action %q"] = "Azione sconosciuta %q"
L["Unknown feature %q"] = "Funzione sconosciuta %q"
L["unknown location"] = "posizione sconosciuta"
L["Unlimited"] = "Illimitato"
L["Untrigger %s"] = "Disinnesco %s"
L["Up"] = "Su"
L["Up, then Centered Horizontal"] = "In alto, poi centrato in orizzontale"
L["Up, then Left"] = "In alto, poi a sinistra"
L["Up, then Right"] = "In alto, poi a destra"
L["Update Position"] = "Aggiorna posizione"
L["Usage:"] = "Uso:"
L["Use /wa minimap to show the minimap icon again."] = "Usa /wa minimap per mostrare di nuovo l'icona della minimappa."
L["Use Custom Color"] = "Usa colore personalizzato"
L["Use Legacy floor rounding"] = "Usa arrotondamento per difetto legacy"
L["Use Texture"] = "Usa texture"
L["Use Watched Faction"] = "Usa fazione osservata"
L["Uses UnitInRange() to check if in range. Matches default raid frames out of range behavior, which is between 25 to 40 yards depending on your class and spec."] = "Usa UnitInRange() per verificare se è a portata. Corrisponde al comportamento fuori portata dei riquadri raid predefiniti, tra 25 e 40 metri a seconda di classe e specializzazione."
L["Using KUIAR_Runtime.clones is deprecated. Use KUIAR_Runtime.GetRegion(id, cloneId) instead."] = "L'uso di KUIAR_Runtime.clones è obsoleto. Usa KUIAR_Runtime.GetRegion(id, cloneId)."
L["Using KUIAR_Runtime.regions is deprecated. Use KUIAR_Runtime.GetRegion(id) instead."] = "L'uso di KUIAR_Runtime.regions è obsoleto. Usa KUIAR_Runtime.GetRegion(id)."
L["Vaelastrasz the Corrupt"] = "Vaelastrasz il Corrotto"
L["Versatility (%)"] = "Versatilità (%)"
L["Versatility Rating"] = "Punteggio versatilità"
L["Vertical"] = "Verticale"
L["Visibility"] = "Visibilità"
L["Visions of N'Zoth"] = "Visioni di N'Zoth"
L["Warband Quantity Total"] = "Quantità totale della Brigata"
L["Warband Transfer Percentage"] = "Percentuale di trasferimento della Brigata"
L["Warband Transferred Quantity"] = "Quantità trasferita della Brigata"
L["Warfront (Heroic)"] = "Fronte di guerra (Eroico)"
L["Warfront (Normal)"] = "Fronte di guerra (Normale)"
L["Warning"] = "Avviso"
L["Warning for unknown aura:"] = "Avviso per aura sconosciuta:"
L["Warning: Anchoring in aura '%s' is imposssible, due to an anchoring cycle"] = "Avviso: l'ancoraggio nell'aura '%s' è impossibile a causa di un ciclo di ancoraggio"
L["Warning: Full Scan auras checking for both name and spell id can't be converted."] = "Avviso: le aure di scansione completa che controllano sia il nome sia l'ID incantesimo non possono essere convertite."
L["Warning: Name info is now available via %affected, %unaffected. Number of affected group members via %unitCount. Some options behave differently now. This is not automatically adjusted."] = "Avviso: le informazioni sul nome sono ora disponibili tramite %affected, %unaffected. Il numero di membri del gruppo interessati tramite %unitCount. Alcune opzioni ora si comportano diversamente. Non viene adattato automaticamente."
L["Warning: Tooltip values are now available via %tooltip1, %tooltip2, %tooltip3 instead of %s. This is not automatically adjusted."] = "Avviso: i valori della descrizione sono ora disponibili tramite %tooltip1, %tooltip2, %tooltip3 invece di %s. Non viene adattato automaticamente."
L["KUIAR_Engine Built-In (63:42 | 3:07 | 10 | 2.4)"] = "KUIAR_Engine integrato (63:42 | 3:07 | 10 | 2.4)"
L["KUIAR_Runtime has detected that it has been downgraded.\nYour saved auras may no longer work properly.\nWould you like to run the |cffff0000EXPERIMENTAL|r repair tool? This will overwrite any changes you have made since the last database upgrade.\nLast upgrade: %s\n\n|cffff0000You should BACKUP your WTF folder BEFORE pressing this button.|r"] = "KUIAR_Runtime ha rilevato di essere stato riportato a una versione precedente.\nLe tue aure salvate potrebbero non funzionare più correttamente.\nVuoi eseguire lo strumento di riparazione |cffff0000SPERIMENTALE|r? Sovrascriverà tutte le modifiche fatte dopo l'ultimo aggiornamento del database.\nUltimo aggiornamento: %s\n\n|cffff0000Dovresti fare un BACKUP della cartella WTF PRIMA di premere questo pulsante.|r"
L["KUIAR_Engine is creating a rollback snapshot of your auras. This snapshot will allow you to revert to the current state of your auras if something goes wrong. This process may cause your framerate to drop until it is complete."] = "KUIAR_Engine sta creando uno snapshot di ripristino delle tue aure. Questo snapshot ti permetterà di tornare allo stato attuale delle aure se qualcosa va storto. Il processo può far calare il framerate finché non è completato."
L["KUIAR_Engine Profiling"] = "Profilazione di KUIAR_Engine"
L["KUIAR_Engine Profiling Report"] = "Rapporto di profilazione di KUIAR_Engine"
L["KUIAR_Engine Version: %s"] = "Versione di KUIAR_Engine: %s"
L["Weapon"] = "Arma"
L["Weapon Enchant"] = "Incantamento dell'arma"
L["Weapon Enchant / Fishing Lure"] = "Incantamento dell'arma / Esca da pesca"
L["Whisper"] = "Sussurra"
L["Width"] = "Larghezza"
L["Wobble"] = "Oscillazione"
L["World Boss"] = "Boss mondiale"
L["World Bosses"] = "Boss mondiali"
L["Wrap"] = "A capo"
L["Writing to the KUIAR_Runtime table is not allowed."] = "La scrittura nella tabella KUIAR_Runtime non è consentita."
L["X-Offset"] = "Scostamento X"
L["Yell"] = "Urlare"
L["Y-Offset"] = "Scostamento Y"
L["You have new auras ready to be installed!"] = "Hai nuove aure pronte per l'installazione!"
L["Your next encounter will automatically be profiled."] = "Il tuo prossimo incontro verrà profilato automaticamente."
L["Your next instance of combat will automatically be profiled."] = "Il tuo prossimo combattimento verrà profilato automaticamente."
L["Your scheduled automatic profile has been cancelled."] = "La profilazione automatica programmata è stata annullata."
L["Your threat as a percentage of the tank's current threat."] = "La tua minaccia come percentuale della minaccia attuale del tank."
L["Your threat on the mob as a percentage of the amount required to pull aggro. Will pull aggro at 100."] = "La tua minaccia sul mob come percentuale di quella necessaria per attirare l'aggro. Attirerai l'aggro a 100."
L["Your total threat on the mob."] = "La tua minaccia totale sul mob."
L["Zone Group ID"] = "ID gruppo di zone"
L["Zone ID"] = "ID zona"
L["Zone Name"] = "Nome zona"
L["Zoom Animation"] = "Animazione di zoom"

end)
