-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_EngineOptions", function(...)
if not KUIAR_Runtime.IsLibsOK() then return end

if (GAME_LOCALE or GetLocale()) ~= "itIT" then
  return
end

local L = KUIAR_Runtime.L

-- M33kAuras/Options
	L[" and |cFFFF0000mirrored|r"] = "e |cFFFF0000mirrored|r"
	L["-- Do not remove this comment, it is part of this aura: "] = "-- Non rimuovere questo commento, fa parte di quest'aura:"
	L[" rotated |cFFFF0000%s|r degrees"] = "ruotato |cFFFF0000%s|r gradi"
	--[[Translation missing --]]
	L["% - To show a percent sign"] = "% - To show a percent sign"
	L["% of Progress"] = "% di Progresso"
	L["%d |4aura:auras; added"] = "%d |4aura:auras; aggiunto"
	L["%d |4aura:auras; deleted"] = "%d |4aura:auras; cancellato"
	L["%d |4aura:auras; modified"] = "%d |4aura:auras; modificata"
	L["%d |4aura:auras; with meta data modified"] = "%d |4aura:auras; con dati meta modificati"
	L["%d displays loaded"] = "%d display caricato"
	L["%d displays not loaded"] = "%d display non caricato"
	L["%d displays on standby"] = "%d display in standby"
	L["%i auras selected"] = "%i aure selezionate"
	--[[Translation missing --]]
	L["%i."] = "%i."
	--[[Translation missing --]]
	L["%i. %s"] = "%i. %s"
	L["%s - %i. Trigger"] = "%s - %i. Attivazione "
	L["%s - Alpha Animation"] = "%s - Animazione Alfabeto "
	L["%s - Color Animation"] = "%s - Colore Animazione "
	L["%s - Condition Custom Chat %s"] = "%s - Condizioni Chat Personalizzata %s"
	L["%s - Condition Custom Check %s"] = "%s - Verifica Personalizzata delle Condizioni %s"
	L["%s - Condition Custom Code %s"] = "%s - Condizione Codice Personalizzato %s"
	L["%s - Custom Anchor"] = "%s - Ancoraggio Personalizzato"
	L["%s - Custom Grow"] = "%s - Crescita Personalizzata"
	L["%s - Custom Sort"] = "%s - Ordinamento Personalizzato"
	L["%s - Custom Text"] = "%s - Testo Personalizzato"
	L["%s - Finish"] = "%s - Termina"
	L["%s - Finish Action"] = "%s - Termina l'Azione"
	L["%s - Finish Custom Text"] = "%s - Termina il Testo Personalizzato"
	L["%s - Init Action"] = "%s - Azione di Inizializzazione"
	L["%s - Main"] = "%s - Principale"
	--[[Translation missing --]]
	L["%s - OnLoad"] = "%s - OnLoad"
	--[[Translation missing --]]
	L["%s - OnUnload"] = "%s - OnUnload"
	L["%s - Option #%i has the key %s. Please choose a different option key."] = "%s - L'opzione #%i ha la chiave %s. Scegli una chiave di opzione diversa."
	L["%s - Rotate Animation"] = "%s - Ruota Animazione"
	L["%s - Scale Animation"] = "%s - Scala Animazione"
	L["%s - Start"] = "%s - Avvia"
	L["%s - Start Action"] = "%s - Avvia Azione"
	L["%s - Start Custom Text"] = "%s - Avvia Testo Personalizzato"
	L["%s - Translate Animation"] = "%s - Traduci Animazione"
	L["%s - Trigger Logic"] = "%s - Logica di Attivazione"
	L["%s %s, Lines: %d, Frequency: %0.2f, Length: %d, Thickness: %d"] = "%s %s, Linee: %d, Frequenza: %0.2f, Lunghezza: %d, Spessore: %d"
	L["%s %s, Particles: %d, Frequency: %0.2f, Scale: %0.2f"] = "%s %s, Particelle: %d, Frequenza: %0.2f, Scala: %0.2f"
	L["%s %u. Overlay Function"] = "%s %u. Funzione di Sovrapposizione"
	--[[Translation missing --]]
	L["%s (%s)"] = "%s (%s)"
	L["%s Alpha: %d%%"] = "%s Alfabeto: %d%%"
	L["%s Color"] = "%s Colore"
	L["%s Custom Variables"] = "%s Variabili Personalizzate"
	L["%s Default Alpha, Zoom, Icon Inset, Aspect Ratio"] = "%s Alfabeto Predefinito, Zoom, Icona inserita, Proporzioni"
	L["%s Duration Function"] = "Funzione Durata %s"
	L["%s Icon Function"] = "Funzione Icona %s"
	L["%s Inset: %d%%"] = "%s Inserire: %d%%"
	L["%s is not a valid SubEvent for COMBAT_LOG_EVENT_UNFILTERED"] = "%s non è un evento secondario valido per COMBAT_LOG_EVENT_UNFILTERED"
	L["%s Keep Aspect Ratio"] = "%s Mantieni Proporzioni"
	L["%s Name Function"] = "%s Nome Funzione"
	L["%s Stacks Function"] = "%s Funzione Accumuli"
	L["%s stores around %s KB of data"] = "%s memorizza circa %s KB di dati"
	L["%s Texture"] = "%s Texture"
	L["%s Texture Function"] = "%s Funzione della Texture"
	L["%s total auras"] = "%s aure totali"
	L["%s Trigger Function"] = "Funzione di Attivazione %s"
	L["%s Untrigger Function"] = "%s Annulla Funzione di Attivazione"
	L["%s X offset by %d"] = "%s X deviazione di %d"
	L["%s Y offset by %d"] = "%s Y deviazione di %d"
	L["%s Zoom: %d%%"] = "%s Zoom: %d%%"
	L["%s, Border"] = "%s, Bordo"
	L["%s, Offset: %0.2f;%0.2f"] = "%s, Deviazione: %0.2f;%0.2f"
	L["%s, offset: %0.2f;%0.2f"] = "%s, deviazione: %0.2f;%0.2f"
	L["%s, Start Animation"] = "%s, Avvia l'animazione"
	L["%s|cFFFF0000custom|r texture with |cFFFF0000%s|r blend mode%s%s"] = "%s|cFFFF0000custom|r texture con |cFFFF0000%s|r modalità di fusione%s%s"
	L["(Right click to rename)"] = "(Tasto destro per rinominare)"
	L["|c%02x%02x%02x%02xCustom Color|r"] = "|c%02x%02x%02x%02xColore Personalizzato|r"
	L["|cff999999Triggers tracking multiple units will default to being active even while no affected units are found without a Unit Count or Match Count setting applied.|r"] = "|cff999999Attivazioni che tracciano più unità verranno attivati ​​per impostazione predefinita anche quando non viene trovata alcuna unità interessata senza l'applicazione di un'impostazione Conteggio unità o Conteggio corrispondenze.|r"
	L["|cFFE0E000Note:|r This sets the description only on '%s'"] = "|cFFE0E000Note:|r Imposta la descrizione solo su '%s'"
	L["|cFFE0E000Note:|r This sets the URL on all selected auras"] = "|cFFE0E000Note:|r Imposta l'URL su tutte le aure selezionate"
	L["|cFFE0E000Note:|r This sets the URL on this group and all its members."] = "|cFFE0E000Note:|r Imposta l'URL di questo gruppo e di tutti i suoi membri."
	L["|cFFFF0000Automatic|r length"] = "|cFFFF0000Automatic|r lunghezza"
	--[[Translation missing --]]
	L["|cFFFF0000default|r texture"] = "|cFFFF0000default|r texture"
	--[[Translation missing --]]
	L["|cFFFF0000desaturated|r "] = "|cFFFF0000desaturated|r "
	L["|cFFFF0000Note:|r The unit '%s' is not a trackable unit."] = "|cFFFF0000Note:|r L'unità '%s' non è un'unità tracciabile."
	--[[Translation missing --]]
	L["|cFFFF0000Note:|r The unit '%s' requires soft target cvars to be enabled."] = "|cFFFF0000Note:|r The unit '%s' requires soft target cvars to be enabled."
	L["|cFFffcc00Anchors:|r Anchored |cFFFF0000%s|r to frame's |cFFFF0000%s|r"] = "|cFFffcc00Anchors:|r Ancoraggio |cFFFF0000%s|r ai frame |cFFFF0000%s|r"
	L["|cFFffcc00Anchors:|r Anchored |cFFFF0000%s|r to frame's |cFFFF0000%s|r with offset |cFFFF0000%s/%s|r"] = "|cFFffcc00Anchors:|r Ancoraggio |cFFFF0000%s|r ai frame |cFFFF0000%s|r con deviazione |cFFFF0000%s/%s|r"
	L["|cFFffcc00Anchors:|r Anchored to frame's |cFFFF0000%s|r"] = "|cFFffcc00Anchors:|r Ancoraggio ai frame |cFFFF0000%s|r"
	L["|cFFffcc00Anchors:|r Anchored to frame's |cFFFF0000%s|r with offset |cFFFF0000%s/%s|r"] = "|cFFffcc00Anchors:|r Ancoraggio ai frame |cFFFF0000%s|r con deviazione |cFFFF0000%s/%s|r"
	L["|cFFffcc00Extra Options:|r"] = "|cFFffcc00Opzioni Extra:|r"
	L["|cFFffcc00Extra:|r %s and %s %s"] = "|cFFffcc00Extra:|r %s e %s %s"
	L["|cFFffcc00Font Flags:|r |cFFFF0000%s|r and shadow |c%sColor|r with offset |cFFFF0000%s/%s|r%s%s"] = "|cFFffcc00Font Flags:|r |cFFFF0000%s|r e ombra |c%sColor|r con deviazione |cFFFF0000%s/%s|r%s%s"
	L["|cFFffcc00Font Flags:|r |cFFFF0000%s|r and shadow |c%sColor|r with offset |cFFFF0000%s/%s|r%s%s%s"] = "|cFFffcc00Font Flags:|r |cFFFF0000%s|r e ombra |c%sColor|r con deviazione |cFFFF0000%s/%s|r%s%s%s"
	L["|cffffcc00Format Options|r"] = "|cffffcc00Opzioni Formato|r"
	L[ [=[• |cff00ff00Player|r, |cff00ff00Target|r, |cff00ff00Focus|r, and |cff00ff00Pet|r correspond directly to those individual unitIDs.
• |cff00ff00Specific Unit|r lets you provide a specific valid unitID to watch.
|cffff0000Note|r: The game will not fire events for all valid unitIDs, making some untrackable by this trigger.
• |cffffff00Party|r, |cffffff00Raid|r, |cffffff00Boss|r, |cffffff00Arena|r, and |cffffff00Nameplate|r can match multiple corresponding unitIDs.
• |cffffff00Smart Group|r adjusts to your current group type, matching just the "player" when solo, "party" units (including "player") in a party or "raid" units in a raid.
• |cffffff00Multi-target|r attempts to use the Combat Log events, rather than unitID, to track affected units.
|cffff0000Note|r: Without a direct relationship to actual unitIDs, results may vary.

|cffffff00*|r Yellow Unit settings can match multiple units and will default to being active even while no affected units are found without a Unit Count or Match Count setting.]=] ] = "• |cff00ff00Player|r, |cff00ff00Target|r, |cff00ff00Focus|r e |cff00ff00Pet|r corrispondono direttamente a quei singoli unitID.  • |cff00ff00Unità specifica|r consente di fornire uno specifico ID unità valido da guardare.  |cffff0000Nota|r: il gioco non attiverà eventi per tutti gli unitID validi, rendendone alcuni non tracciabili da questa attivazione.  • |cffffff00Party|r, |cffffff00Raid|r, |cffffff00Boss|r, |cffffff00Arena|r e |cffffff00Nameplate|r possono corrispondere a più ID unità corrispondenti.  • |cffffff00Smart Group|r si adatta al tipo di gruppo corrente, abbinando solo il \"giocatore\" in modalità solista, le unità \"party\" (incluso il \"giocatore\") in un party o le unità \"raid\" in un raid.  • |cffffff00Multi-target|r tenta di utilizzare gli eventi del registro di combattimento, anziché l'ID unità, per tenere traccia delle unità interessate.  |cffff0000Nota|r: senza una relazione diretta con gli ID unità effettivi, i risultati possono variare.  |cffffff00*|r Giallo Le impostazioni delle unità possono corrispondere a più unità e verranno attivate per impostazione predefinita anche quando non viene trovata alcuna unità interessata senza un'impostazione Conteggio unità o Conteggio corrispondenze."
	L["A 20x20 pixels icon"] = "Un' icona 20x20 pixel"
	L["A 32x32 pixels icon"] = "Un'icona 32x32 pixel"
	L["A 40x40 pixels icon"] = "Un'icona 40x40 pixel"
	L["A 48x48 pixels icon"] = "Un'icona 48x48 pixel"
	L["A 64x64 pixels icon"] = "Un'icona 64x64 pixel"
	L["A group that dynamically controls the positioning of its children"] = "Un gruppo che controlla dinamicamente la posizione dei propri figli"
	L[ [=[A timer will automatically be displayed according to default Interface Settings (overridden by some addons).
Enable this setting if you want this timer to be hidden, or when using a KUIAR_Runtime text to display the timer]=] ] = "Un timer verrà automaticamente visualizzato in base alle impostazioni dell'interfaccia predefinite (sostituite da alcuni componenti aggiuntivi). Abilita questa impostazione se vuoi che questo timer sia nascosto o quando usi un testo KUIAR_Runtime per visualizzare il timer"
	L["A Unit ID (e.g., party1)."] = "Un Unit ID (p.es., party1)"
	--[[Translation missing --]]
	L["Ace: Funkeh, Nevcairiel"] = "Ace: Funkeh, Nevcairiel"
	L["Active Aura Filters and Info"] = "Filtri e informazioni sull'aura attiva"
	L["Actual Spec"] = "Attuale Spec"
	L["Add %s"] = "Aggiungi %s"
	L["Add a new display"] = "Aggiungi un nuovo display"
	L["Add Condition"] = "Aggiungi Condizione"
	L["Add Entry"] = "Aggiungi Iscrizione "
	L["Add Extra Elements"] = "Aggiungi Elementi Extra"
	L["Add Option"] = "Aggiungi Opzione"
	L["Add Overlay"] = "Aggiungi Overlay"
	L["Add Property Change"] = "Aggiungi Cambio Caratteristica"
	L["Add Snippet"] = "Aggiungi Frammento "
	L["Add Sub Option"] = "Aggiungi opzione secondaria"
	L["Add to group %s"] = "Aggiungi al gruppo %s"
	L["Add to new Dynamic Group"] = "Aggiungi ad un nuovo Gruppo Dinamico"
	L["Add to new Group"] = "Aggiungi ad un nuoco Gruppo"
	L["Add Trigger"] = "Aggiungi attivazione "
	L["Additional Events"] = "Eventi Addizionali"
	L["Advanced"] = "Avanzate"
	L["Affected Unit Filters and Info"] = "Filtri e informazioni sulle unità interessate"
	L["Align"] = "Allinea"
	L["Alignment"] = "Allineamento"
	--[[Translation missing --]]
	L["All maintainers of the libraries we use, especially:"] = "All maintainers of the libraries we use, especially:"
	L["All of"] = "Tutto di"
	L["Allow Full Rotation"] = "Consenti rotazione completa"
	L["Anchor"] = "Ancora"
	--[[Translation missing --]]
	L["Anchor Mode"] = "Anchor Mode"
	L["Anchor Point"] = "Punto di ancoraggio"
	L["Anchored To"] = "Ancorato a"
	L["And "] = "E"
	L["and"] = "e"
	L["and %s"] = "e %s"
	L["and aligned left"] = "e allineato a sinistra"
	L["and aligned right"] = "e allineato a destra"
	--[[Translation missing --]]
	L["And our Patreons, Discord Regulars and Subscribers, and Friends of the Addon:"] = "And our Patreons, Discord Regulars and Subscribers, and Friends of the Addon:"
	L["and rotated left"] = "e ruotato a sinistra"
	L["and rotated right"] = "e ruotato a destra"
	L["and with width |cFFFF0000%s|r and %s"] = "e con larghezza |cFFFF0000%s|r e %s"
	L["Angle"] = "Angolo"
	L["Angle Between Auras"] = "Angolo tra le aure"
	L["Animate"] = "Animato"
	L["Animated Expand and Collapse"] = "Espansione e Compressione Animata"
	L["Animates progress changes"] = "Anima i cambi di avanzamento"
	L["Animation End"] = "Fine Animazione"
	L["Animation Mode"] = "Modalità Animazione"
	L["Animation relative duration description"] = "Descrizione della durata relativa dell'animazione"
	L["Animation Sequence"] = "Sequenza di Animazione"
	L["Animation Start"] = "Start Animazione "
	L["Any of"] = "Qualsiasi tra"
	L["Apply Template"] = "Applica Template"
	L["Arcane Orb"] = "Globo Arcano"
	--[[Translation missing --]]
	L["Area"] = "Area"
	L["At a position a bit left of Left HUD position."] = "In una posizione un po' a sinistra della posizione dell'HUD sinistro."
	L["At a position a bit left of Right HUD position"] = "In una posizione un po' a sinistra della posizione dell'HUD destro."
	L["At the same position as Blizzard's spell alert"] = "Nella stessa posizione dell'avviso magia della Blizzard"
	--[[Translation missing --]]
	L["Attach to Foreground"] = "Attach to Foreground"
	L[ [=[Aura is
Off Screen]=] ] = "L'aura è fuori dallo schermo"
	L["Aura Name Pattern"] = "Schema del Nome Aura"
	L["Aura Order"] = "Ordine dell'Aura"
	L["Aura received from: %s"] = "Aura ricevuta da: %s"
	--[[Translation missing --]]
	L["Aura: '%s'"] = "Aura: '%s'"
	L["Auto-Clone (Show All Matches)"] = "Auto-Clona (Mostra tutte le corrispondenze)"
	L["Automatic length"] = "Lunghezza automatica"
	L["Backdrop Color"] = "Colore Fondale"
	L["Backdrop in Front"] = "Fondale d'avanti"
	L["Backdrop Style"] = "Stile Fondale"
	L["Background Inner"] = "Sfondo interno"
	L["Background Offset"] = "Deviazione Sfondo"
	L["Background Texture"] = "Texture dello Sfondo"
	L["Bar Alpha"] = "Alfa della Barra"
	L["Bar Color Settings"] = "Impostazioni Colore Barra"
	L["Big Icon"] = "Icone Grandi"
	L["Blend Mode"] = "Modalità di Fusione"
	L["Blue Rune"] = "Runa Blu"
	L["Blue Sparkle Orb"] = "Sfera Luccicante Blu"
	L["Border %s"] = "Bordo %s"
	L["Border Anchor"] = "Ancora Bordo"
	L["Border Color"] = "Colore Bordo"
	L["Border in Front"] = "Bordi davanti"
	L["Border Inset"] = "Offset del Bordo"
	L["Border Offset"] = "Offset del Bordo"
	L["Border Settings"] = "Imbostazioni Bordo"
	L["Border Size"] = "Dimensioni Bordo"
	L["Border Style"] = "Stile Bordo"
	L["Bracket Matching"] = "Corrispondenza Parentesi"
	L["Browse Wago, the largest collection of auras."] = "Sfoglia Wago, la più grande collezione di aure."
	--[[Translation missing --]]
	L["By default this shows the information from the trigger selected via dynamic information. The information from a specific trigger can be shown via e.g. %2.p."] = "By default this shows the information from the trigger selected via dynamic information. The information from a specific trigger can be shown via e.g. %2.p."
	L["Can be a UID (e.g., party1)."] = "Può essere un UID (ad esempio, party1)."
	L["Can set to 0 if Columns * Width equal File Width"] = "Può essere impostato su 0 se Colonne * Larghezza è uguale alla Larghezza file"
	L["Can set to 0 if Rows * Height equal File Height"] = "Può essere impostato su 0 se Righe * Altezza è uguale all'altezza del file"
	--[[Translation missing --]]
	L["Case Insensitive"] = "Case Insensitive"
	L["Cast by a Player Character"] = "Cast da un personaggio giocante"
	L["Categories to Update"] = "Categorie da aggiornare"
	--[[Translation missing --]]
	L["Changelog"] = "Changelog"
	L["Chat with KUIAR_Runtime experts on our Discord server."] = "Chatta con gli esperti KUIAR_Runtime sul nostro server Discord."
	L["Check On..."] = "Controllare..."
	L["Check out our wiki for a large collection of examples and snippets."] = "Controlla la nostra wiki per un'ampia raccolta di esempi e frammenti."
	L["Children:"] = "Bambini:"
	L["Choose"] = "Scegliere"
	--[[Translation missing --]]
	L["Circular Texture %s"] = "Circular Texture %s"
	L["Clear Debug Logs"] = "Cancella registri di debug"
	L["Clear Saved Data"] = "Cancella dati salvati"
	--[[Translation missing --]]
	L["Click to replace the name with %s."] = "Click to replace the name with %s."
	L["Clip Overlays"] = "Sovrapposizioni di clip"
	--[[Translation missing --]]
	L["Clipped by Foreground"] = "Clipped by Foreground"
	L["Close"] = "Chiudi"
	L["Code Editor"] = "Editore di codice"
	L["Collapse"] = "Comprimi"
	L["Collapse all loaded displays"] = "Comprimi tutti i display caricati"
	L["Collapse all non-loaded displays"] = "Comprimi tutti i display non caricati"
	L["Collapse all pending Import"] = "Comprimi tutto in attesa di importazione"
	L["Collapsible Group"] = "Comprimi Gruppo"
	L["color"] = "Colore"
	L["Column Height"] = "Altezza Colonna"
	L["Column Space"] = "Spazio colonna"
	L["Columns"] = "Colonne"
	L["COMBAT_LOG_EVENT_UNFILTERED with no filter can trigger frame drops in raid environment."] = "COMBAT_LOG_EVENT_UNFILTERED senza filtro può attivare cadute di frame nell'ambiente raid."
	L["Combinations"] = "Combinazioni"
	L["Combine Matches Per Unit"] = "Combina partite per unità"
	L["Common Text"] = "Testo Comune"
	L["Compare against the number of units affected."] = "Confrontare con il numero di unità interessate."
	L["Compatibility Options"] = "Opzioni di compatibilità"
	L["Compress"] = "Comprimi"
	L["Configure what options appear on this panel."] = "Configura quali opzioni appaiono in questo pannello."
	L["Constant Factor"] = "Fattore Costante"
	L["Control-click to select multiple displays"] = "Fare clic tenendo premuto il tasto Control per selezionare più display"
	L["Controls the positioning and configuration of multiple displays at the same time"] = "Controlla il posizionamento e la configurazione di più display contemporaneamente"
	L["Convert to..."] = "Converti in..."
	L["Cooldown Numbers might be added by WoW. You can configure these in the game settings."] = "I numeri di Cooldown potrebbero essere aggiunti da WoW. Puoi configurarli nelle impostazioni del gioco."
	L["Copy"] = "Copia"
	L["Copy settings..."] = "Copia impostazioni..."
	L["Copy to all auras"] = "Copia in tutte le aure"
	--[[Translation missing --]]
	L["Could not parse '%s'. Expected a table."] = "Could not parse '%s'. Expected a table."
	L["Counts the number of matches over all units."] = "Conta il numero di corrispondenze su tutte le unità."
	L["Counts the number of matches per unit."] = "Conta il numero di corrispondenze per unità."
	L["Create a Copy"] = "Crea una copia"
	L["Creating buttons: "] = "Crea bottoni:"
	L["Creating options: "] = "Crea opzioni:"
	--[[Translation missing --]]
	L["Custom - Allows you to define a custom Lua function that returns a list of string values. %c1 will be replaced by the first value returned, %c2 by the second, etc."] = "Custom - Allows you to define a custom Lua function that returns a list of string values. %c1 will be replaced by the first value returned, %c2 by the second, etc."
	--[[Translation missing --]]
	L["Custom Code"] = "Custom Code"
	--[[Translation missing --]]
	L["Custom Code Viewer"] = "Custom Code Viewer"
	--[[Translation missing --]]
	L["Custom Frames"] = "Custom Frames"
	--[[Translation missing --]]
	L["Custom Functions"] = "Custom Functions"
	--[[Translation missing --]]
	L["Custom Init"] = "Custom Init"
	--[[Translation missing --]]
	L["Custom Load"] = "Custom Load"
	--[[Translation missing --]]
	L["Custom Options"] = "Custom Options"
	--[[Translation missing --]]
	L["Custom Text Update Throttle"] = "Custom Text Update Throttle"
	--[[Translation missing --]]
	L["Custom Trigger"] = "Custom Trigger"
	--[[Translation missing --]]
	L["Custom trigger event tooltip"] = [=[Choose which events cause the custom trigger to be checked. Multiple events can be specified using commas or spaces.
• "UNIT" events can use colons to define which unitIDs will be registered. In addition to UnitIDs Unit types can be used, they include "nameplate", "group", "raid", "party", "arena", "boss".
• "CLEU" can be used instead of COMBAT_LOG_EVENT_UNFILTERED and colons can be used to separate specific "subEvents" you want to receive.
• The keyword "TRIGGER" can be used, with colons separating trigger numbers, to have the custom trigger get updated when the specified trigger(s) update.

|cFF4444FFFor example:|r
UNIT_POWER_UPDATE:player, UNIT_AURA:nameplate:group PLAYER_TARGET_CHANGED CLEU:SPELL_CAST_SUCCESS TRIGGER:3:1
]=]
	--[[Translation missing --]]
	L["Custom trigger status tooltip"] = [=[Choose which events cause the custom trigger to be checked. Multiple events can be specified using commas or spaces.

• "UNIT" events can use colons to define which unitIDs will be registered. In addition to UnitIDs Unit types can be used, they include "nameplate", "group", "raid", "party", "arena", "boss".
• "CLEU" can be used instead of COMBAT_LOG_EVENT_UNFILTERED and colons can be used to separate specific "subEvents" you want to receive.
• The keyword "TRIGGER" can be used, with colons separating trigger numbers, to have the custom trigger get updated when the specified trigger(s) update.

Since this is a status-type trigger, the specified events may be called by KUIAR_Runtime without the expected arguments.

|cFF4444FFFor example:|r
UNIT_POWER_UPDATE:player, UNIT_AURA:nameplate:group PLAYER_TARGET_CHANGED CLEU:SPELL_CAST_SUCCESS TRIGGER:3:1
]=]
	--[[Translation missing --]]
	L["Custom trigger Update Throttle"] = "Custom trigger Update Throttle"
	--[[Translation missing --]]
	L["Custom Trigger: Ignore Lua Errors on OPTIONS event"] = "Custom Trigger: Ignore Lua Errors on OPTIONS event"
	--[[Translation missing --]]
	L["Custom Trigger: Send fake events instead of STATUS event"] = "Custom Trigger: Send fake events instead of STATUS event"
	--[[Translation missing --]]
	L["Custom Unload"] = "Custom Unload"
	--[[Translation missing --]]
	L["Custom Untrigger"] = "Custom Untrigger"
	--[[Translation missing --]]
	L["Debug Log"] = "Debug Log"
	--[[Translation missing --]]
	L["Debug Log:"] = "Debug Log:"
	--[[Translation missing --]]
	L["Default"] = "Default"
	--[[Translation missing --]]
	L["Default Color"] = "Default Color"
	--[[Translation missing --]]
	L["Delay"] = "Delay"
	--[[Translation missing --]]
	L["Delete"] = "Delete"
	--[[Translation missing --]]
	L["Delete all"] = "Delete all"
	--[[Translation missing --]]
	L["Delete children and group"] = "Delete children and group"
	--[[Translation missing --]]
	L["Delete Entry"] = "Delete Entry"
	--[[Translation missing --]]
	L["Deleting auras: "] = "Deleting auras: "
	--[[Translation missing --]]
	L["Description Text"] = "Description Text"
	--[[Translation missing --]]
	L["Determines how many entries can be in the table."] = "Determines how many entries can be in the table."
	--[[Translation missing --]]
	L["Differences"] = "Differences"
	--[[Translation missing --]]
	L["Disallow Entry Reordering"] = "Disallow Entry Reordering"
	--[[Translation missing --]]
	L["Discord"] = "Discord"
	--[[Translation missing --]]
	L["Display Name"] = "Display Name"
	--[[Translation missing --]]
	L["Display Text"] = "Display Text"
	--[[Translation missing --]]
	L["Displays a text, works best in combination with other displays"] = "Displays a text, works best in combination with other displays"
	--[[Translation missing --]]
	L["Distribute Horizontally"] = "Distribute Horizontally"
	--[[Translation missing --]]
	L["Distribute Vertically"] = "Distribute Vertically"
	--[[Translation missing --]]
	L["Do not group this display"] = "Do not group this display"
	--[[Translation missing --]]
	L["Do you want to enable updates for this aura"] = "Do you want to enable updates for this aura"
	--[[Translation missing --]]
	L["Do you want to ignore updates for this aura"] = "Do you want to ignore updates for this aura"
	--[[Translation missing --]]
	L["Documentation"] = "Documentation"
	--[[Translation missing --]]
	L["Done"] = "Done"
	--[[Translation missing --]]
	L["Drag to move"] = "Drag to move"
	--[[Translation missing --]]
	L["Duplicate"] = "Duplicate"
	--[[Translation missing --]]
	L["Duplicate All"] = "Duplicate All"
	--[[Translation missing --]]
	L["Duration (s)"] = "Duration (s)"
	--[[Translation missing --]]
	L["Duration Info"] = "Duration Info"
	--[[Translation missing --]]
	L["Dynamic Duration"] = "Dynamic Duration"
	--[[Translation missing --]]
	L["Dynamic Group"] = "Dynamic Group"
	--[[Translation missing --]]
	L["Dynamic Group Settings"] = "Dynamic Group Settings"
	--[[Translation missing --]]
	L["Dynamic Information"] = "Dynamic Information"
	--[[Translation missing --]]
	L["Dynamic information from first active trigger"] = "Dynamic information from first active trigger"
	--[[Translation missing --]]
	L["Dynamic information from Trigger %i"] = "Dynamic information from Trigger %i"
	--[[Translation missing --]]
	L["Dynamic Text Replacements"] = "Dynamic Text Replacements"
	--[[Translation missing --]]
	L["Ease Strength"] = "Ease Strength"
	--[[Translation missing --]]
	L["Ease type"] = "Ease type"
	--[[Translation missing --]]
	L["eliding"] = "eliding"
	--[[Translation missing --]]
	L["Else If"] = "Else If"
	--[[Translation missing --]]
	L["Else If %s"] = "Else If %s"
	--[[Translation missing --]]
	L["Empty Base Region"] = "Empty Base Region"
	--[[Translation missing --]]
	L["Enable \"Edge\" part of the overlay"] = "Enable \"Edge\" part of the overlay"
	--[[Translation missing --]]
	L["Enable \"swipe\" part of the overlay"] = "Enable \"swipe\" part of the overlay"
	--[[Translation missing --]]
	L["Enable Debug Log"] = "Enable Debug Log"
	--[[Translation missing --]]
	L["Enable Debug Logging"] = "Enable Debug Logging"
	--[[Translation missing --]]
	L["Enable Gradient"] = "Enable Gradient"
	--[[Translation missing --]]
	L["Enable Swipe"] = "Enable Swipe"
	--[[Translation missing --]]
	L["Enable the \"Swipe\" radial overlay"] = "Enable the \"Swipe\" radial overlay"
	--[[Translation missing --]]
	L["Enabled"] = "Enabled"
	--[[Translation missing --]]
	L["End Angle"] = "End Angle"
	--[[Translation missing --]]
	L["End of %s"] = "End of %s"
	--[[Translation missing --]]
	L["Enemy nameplate(s) found"] = "Enemy nameplate(s) found"
	--[[Translation missing --]]
	L["Enter a Spell ID. You can use the addon idTip to determine spell ids."] = "Enter a Spell ID. You can use the addon idTip to determine spell ids."
	--[[Translation missing --]]
	L["Enter an Aura Name, partial Aura Name, or Spell ID. A Spell ID will match any spells with the same name."] = "Enter an Aura Name, partial Aura Name, or Spell ID. A Spell ID will match any spells with the same name."
	--[[Translation missing --]]
	L["Enter Author Mode"] = "Enter Author Mode"
	--[[Translation missing --]]
	L["Enter in a value for the tick's placement."] = "Enter in a value for the tick's placement."
	--[[Translation missing --]]
	L["Enter static or relative values with %"] = "Enter static or relative values with %"
	--[[Translation missing --]]
	L["Enter User Mode"] = "Enter User Mode"
	--[[Translation missing --]]
	L["Enter user mode."] = "Enter user mode."
	--[[Translation missing --]]
	L["Entry %i"] = "Entry %i"
	--[[Translation missing --]]
	L["Entry limit"] = "Entry limit"
	--[[Translation missing --]]
	L["Entry Name Source"] = "Entry Name Source"
	L["Event Type"] = "Tipo di Evento"
	--[[Translation missing --]]
	L["Everything"] = "Everything"
	--[[Translation missing --]]
	L["Exact Item Match"] = "Exact Item Match"
	--[[Translation missing --]]
	L["Exact Spell Match"] = "Exact Spell Match"
	--[[Translation missing --]]
	L["Expand"] = "Expand"
	--[[Translation missing --]]
	L["Expand all loaded displays"] = "Expand all loaded displays"
	--[[Translation missing --]]
	L["Expand all non-loaded displays"] = "Expand all non-loaded displays"
	--[[Translation missing --]]
	L["Expand all pending Import"] = "Expand all pending Import"
	--[[Translation missing --]]
	L["Expansion is disabled because this group has no children"] = "Expansion is disabled because this group has no children"
	--[[Translation missing --]]
	L["Export debug table..."] = "Export debug table..."
	--[[Translation missing --]]
	L["Export..."] = "Export..."
	--[[Translation missing --]]
	L["Exporting"] = "Exporting"
	--[[Translation missing --]]
	L["External"] = "External"
	--[[Translation missing --]]
	L["Extra Height"] = "Extra Height"
	--[[Translation missing --]]
	L["Extra Width"] = "Extra Width"
	--[[Translation missing --]]
	L["Fade"] = "Fade"
	--[[Translation missing --]]
	L["Fadeout Sound"] = "Fadeout Sound"
	--[[Translation missing --]]
	L["Fadeout Time (seconds)"] = "Fadeout Time (seconds)"
	--[[Translation missing --]]
	L["Fetch Affected/Unaffected Names and Units"] = "Fetch Affected/Unaffected Names and Units"
	--[[Translation missing --]]
	L["Fetch Raid Mark Information"] = "Fetch Raid Mark Information"
	--[[Translation missing --]]
	L["Fetch Role Information"] = "Fetch Role Information"
	--[[Translation missing --]]
	L["Fetch Tooltip Information"] = "Fetch Tooltip Information"
	--[[Translation missing --]]
	L["File Height"] = "File Height"
	--[[Translation missing --]]
	L["File Width"] = "File Width"
	--[[Translation missing --]]
	L["Filter based on the spell Name string."] = "Filter based on the spell Name string."
	--[[Translation missing --]]
	L["Filter by Arena Spec"] = "Filter by Arena Spec"
	--[[Translation missing --]]
	L["Filter by Class"] = "Filter by Class"
	--[[Translation missing --]]
	L["Filter by Group Role"] = "Filter by Group Role"
	--[[Translation missing --]]
	L["Filter by Hostility"] = "Filter by Hostility"
	--[[Translation missing --]]
	L["Filter by Npc ID"] = "Filter by Npc ID"
	--[[Translation missing --]]
	L["Filter by Raid Role"] = "Filter by Raid Role"
	--[[Translation missing --]]
	L["Filter by Specialization"] = "Filter by Specialization"
	--[[Translation missing --]]
	L["Filter by Unit Name"] = "Filter by Unit Name"
	--[[Translation missing --]]
	L[ [=[Filter formats: 'Name', 'Name-Realm', '-Realm'.

Supports multiple entries, separated by commas
Can use \ to escape -.]=] ] = [=[Filter formats: 'Name', 'Name-Realm', '-Realm'.

Supports multiple entries, separated by commas
Can use \ to escape -.]=]
	--[[Translation missing --]]
	L[ [=[Filter to only dispellable de/buffs of the given type(s)
Bleed classification via LibDispel]=] ] = [=[Filter to only dispellable de/buffs of the given type(s)
Bleed classification via LibDispel]=]
	--[[Translation missing --]]
	L["Find Auras"] = "Find Auras"
	--[[Translation missing --]]
	L["Finish"] = "Finish"
	--[[Translation missing --]]
	L["Finishing..."] = "Finishing..."
	--[[Translation missing --]]
	L["Fire Orb"] = "Fire Orb"
	--[[Translation missing --]]
	L["Flat Framelevels"] = "Flat Framelevels"
	--[[Translation missing --]]
	L["Foreground Texture"] = "Foreground Texture"
	--[[Translation missing --]]
	L["Format for %s"] = "Format for %s"
	--[[Translation missing --]]
	L["Found a Bug?"] = "Found a Bug?"
	--[[Translation missing --]]
	L["Frame"] = "Frame"
	--[[Translation missing --]]
	L["Frame Count"] = "Frame Count"
	--[[Translation missing --]]
	L["Frame Height"] = "Frame Height"
	--[[Translation missing --]]
	L["Frame Rate"] = "Frame Rate"
	--[[Translation missing --]]
	L["Frame Strata"] = "Frame Strata"
	--[[Translation missing --]]
	L["Frame Width"] = "Frame Width"
	--[[Translation missing --]]
	L["Full Bar"] = "Full Bar"
	--[[Translation missing --]]
	L["Full Circle"] = "Full Circle"
	--[[Translation missing --]]
	L["Global Conditions"] = "Global Conditions"
	--[[Translation missing --]]
	L["Glow %s"] = "Glow %s"
	--[[Translation missing --]]
	L["Glow Action"] = "Glow Action"
	--[[Translation missing --]]
	L["Glow Anchor"] = "Glow Anchor"
	--[[Translation missing --]]
	L["Glow Color"] = "Glow Color"
	--[[Translation missing --]]
	L["Glow Frame Type"] = "Glow Frame Type"
	--[[Translation missing --]]
	L["Glow Type"] = "Glow Type"
	--[[Translation missing --]]
	L["Green Rune"] = "Green Rune"
	--[[Translation missing --]]
	L["Grid direction"] = "Grid direction"
	--[[Translation missing --]]
	L["Group (verb)"] = "Group"
	--[[Translation missing --]]
	L["Group Alpha"] = "Group Alpha"
	--[[Translation missing --]]
	L[ [=[Group and anchor each auras by frame.

- Nameplates: attach to nameplates per unit.
- Unit Frames: attach to unit frame buttons per unit.
- Custom Frames: choose which frame each region should be anchored to.]=] ] = [=[Group and anchor each auras by frame.

- Nameplates: attach to nameplates per unit.
- Unit Frames: attach to unit frame buttons per unit.
- Custom Frames: choose which frame each region should be anchored to.]=]
	--[[Translation missing --]]
	L["Group aura count description"] = [=[The amount of units of type '%s' which must be affected by one or more of the given auras for the display to trigger.
If the entered number is a whole number (e.g. 5), the number of affected units will be compared with the entered number.
If the entered number is a decimal (e.g. 0.5), fraction (e.g. 1/2), or percentage (e.g. 50%%), then that fraction of the %s must be affected.

|cFF4444FFFor example:|r
|cFF00CC00> 0|r will trigger when any unit of type '%s' is affected
|cFF00CC00= 100%%|r will trigger when every unit of type '%s' is affected
|cFF00CC00!= 2|r will trigger when the number of units of type '%s' affected is not exactly 2
|cFF00CC00<= 0.8|r will trigger when less than 80%% of the units of type '%s' is affected (4 of 5 party members, 8 of 10 or 20 of 25 raid members)
|cFF00CC00> 1/2|r will trigger when more than half of the units of type '%s' is affected
]=]
	--[[Translation missing --]]
	L["Group by Frame"] = "Group by Frame"
	--[[Translation missing --]]
	L["Group Description"] = "Group Description"
	--[[Translation missing --]]
	L["Group Icon"] = "Group Icon"
	--[[Translation missing --]]
	L["Group key"] = "Group key"
	--[[Translation missing --]]
	L["Group Options"] = "Group Options"
	--[[Translation missing --]]
	L["Group player(s) found"] = "Group player(s) found"
	--[[Translation missing --]]
	L["Group Role"] = "Group Role"
	--[[Translation missing --]]
	L["Group Scale"] = "Group Scale"
	--[[Translation missing --]]
	L["Group Settings"] = "Group Settings"
	--[[Translation missing --]]
	L["Hawk"] = "Hawk"
	--[[Translation missing --]]
	L["Help"] = "Help"
	--[[Translation missing --]]
	L["Hide After"] = "Hide After"
	--[[Translation missing --]]
	L["Hide Background"] = "Hide Background"
	--[[Translation missing --]]
	L["Hide Glows applied by this aura"] = "Hide Glows applied by this aura"
	--[[Translation missing --]]
	L["Hide on"] = "Hide on"
	--[[Translation missing --]]
	L["Hide this group's children"] = "Hide this group's children"
	--[[Translation missing --]]
	L["Highlights"] = "Highlights"
	--[[Translation missing --]]
	L["Horizontal Align"] = "Horizontal Align"
	--[[Translation missing --]]
	L["Horizontal Bar"] = "Horizontal Bar"
	--[[Translation missing --]]
	L["Huge Icon"] = "Huge Icon"
	--[[Translation missing --]]
	L["Hybrid Position"] = "Hybrid Position"
	--[[Translation missing --]]
	L["Hybrid Sort Mode"] = "Hybrid Sort Mode"
	--[[Translation missing --]]
	L["Icon - The icon associated with the display"] = "Icon - The icon associated with the display"
	--[[Translation missing --]]
	L["Icon Info"] = "Icon Info"
	--[[Translation missing --]]
	L["Icon Inset"] = "Icon Inset"
	--[[Translation missing --]]
	L["Icon Picker"] = "Icon Picker"
	--[[Translation missing --]]
	L["Icon Position"] = "Icon Position"
	--[[Translation missing --]]
	L["Icon Settings"] = "Icon Settings"
	--[[Translation missing --]]
	L["Icon Source"] = "Icon Source"
	--[[Translation missing --]]
	L["If"] = "If"
	--[[Translation missing --]]
	L["If %s"] = "If %s"
	--[[Translation missing --]]
	L["If checked, then the combo box in the User settings will be sorted."] = "If checked, then the combo box in the User settings will be sorted."
	--[[Translation missing --]]
	L["If checked, then the user will see a multi line edit box. This is useful for inputting large amounts of text."] = "If checked, then the user will see a multi line edit box. This is useful for inputting large amounts of text."
	--[[Translation missing --]]
	L["If checked, then this group will not merge with other group when selecting multiple auras."] = "If checked, then this group will not merge with other group when selecting multiple auras."
	--[[Translation missing --]]
	L["If checked, then this option group can be temporarily collapsed by the user."] = "If checked, then this option group can be temporarily collapsed by the user."
	--[[Translation missing --]]
	L["If checked, then this option group will start collapsed."] = "If checked, then this option group will start collapsed."
	--[[Translation missing --]]
	L["If checked, then this separator will include text. Otherwise, it will be just a horizontal line."] = "If checked, then this separator will include text. Otherwise, it will be just a horizontal line."
	--[[Translation missing --]]
	L["If checked, then this space will span across multiple lines."] = "If checked, then this space will span across multiple lines."
	--[[Translation missing --]]
	L["If unchecked, then a default color will be used (usually yellow)"] = "If unchecked, then a default color will be used (usually yellow)"
	--[[Translation missing --]]
	L["If unchecked, then this space will fill the entire line it is on in User Mode."] = "If unchecked, then this space will fill the entire line it is on in User Mode."
	--[[Translation missing --]]
	L["Ignore out of casting range"] = "Ignore out of casting range"
	--[[Translation missing --]]
	--[[Translation missing --]]
	L["Ignore Wago updates"] = "Ignore Wago updates"
	--[[Translation missing --]]
	L["Ignored"] = "Ignored"
	--[[Translation missing --]]
	L["Ignored Aura Name"] = "Ignored Aura Name"
	--[[Translation missing --]]
	L["Ignored Exact Spell ID(s)"] = "Ignored Exact Spell ID(s)"
	--[[Translation missing --]]
	L["Ignored Name(s)"] = "Ignored Name(s)"
	--[[Translation missing --]]
	L["Ignored Spell ID"] = "Ignored Spell ID"
	--[[Translation missing --]]
	L["Import"] = "Import"
	--[[Translation missing --]]
	L["Import / Export"] = "Import / Export"
	--[[Translation missing --]]
	L["Import a display from an encoded string"] = "Import a display from an encoded string"
	--[[Translation missing --]]
	L["Import as Copy"] = "Import as Copy"
	--[[Translation missing --]]
	L["Import has no UID, cannot be matched to existing auras."] = "Import has no UID, cannot be matched to existing auras."
	--[[Translation missing --]]
	L["Importing"] = "Importing"
	--[[Translation missing --]]
	L["Importing %s"] = "Importing %s"
	--[[Translation missing --]]
	L["Importing a group with %s child auras."] = "Importing a group with %s child auras."
	--[[Translation missing --]]
	L["Importing a stand-alone aura."] = "Importing a stand-alone aura."
	--[[Translation missing --]]
	L["Importing...."] = "Importing...."
	--[[Translation missing --]]
	L["Incompatible changes to group region types detected"] = "Incompatible changes to group region types detected"
	--[[Translation missing --]]
	L["Incompatible changes to group structure detected"] = "Incompatible changes to group structure detected"
	--[[Translation missing --]]
	L["Indent Size"] = "Indent Size"
	--[[Translation missing --]]
	L["Inner"] = "Inner"
	--[[Translation missing --]]
	L["Insert text replacement codes to make text dynamic."] = "Insert text replacement codes to make text dynamic."
	--[[Translation missing --]]
	L["Invalid Item ID"] = "Invalid Item ID"
	--[[Translation missing --]]
	L["Invalid Item Name/ID/Link"] = "Invalid Item Name/ID/Link"
	--[[Translation missing --]]
	L["Invalid Spell ID"] = "Invalid Spell ID"
	--[[Translation missing --]]
	L["Invalid Spell Name/ID/Link"] = "Invalid Spell Name/ID/Link"
	--[[Translation missing --]]
	L["Invalid target aura"] = "Invalid target aura"
	--[[Translation missing --]]
	L["Invalid type for '%s'. Expected 'bool', 'number', 'select', 'string', 'timer' or 'elapsedTimer'."] = "Invalid type for '%s'. Expected 'bool', 'number', 'select', 'string', 'timer' or 'elapsedTimer'."
	--[[Translation missing --]]
	L["Invalid type for property '%s' in '%s'. Expected '%s'"] = "Invalid type for property '%s' in '%s'. Expected '%s'"
	--[[Translation missing --]]
	L["Inverse Slant"] = "Inverse Slant"
	--[[Translation missing --]]
	L["Invert the direction of progress"] = "Invert the direction of progress"
	--[[Translation missing --]]
	L["Is Boss Debuff"] = "Is Boss Debuff"
	--[[Translation missing --]]
	L["Is Stealable"] = "Is Stealable"
	--[[Translation missing --]]
	L["Is Unit"] = "Is Unit"
	--[[Translation missing --]]
	L["Justify"] = "Justify"
	--[[Translation missing --]]
	L["Keep Aspect Ratio"] = "Keep Aspect Ratio"
	--[[Translation missing --]]
	L["Keep your Wago imports up to date with the Companion App."] = "Keep your Wago imports up to date with the Companion App."
	--[[Translation missing --]]
	L["Large Input"] = "Large Input"
	--[[Translation missing --]]
	L["Leaf"] = "Leaf"
	--[[Translation missing --]]
	L["Left 2 HUD position"] = "Left 2 HUD position"
	--[[Translation missing --]]
	L["Left HUD position"] = "Left HUD position"
	--[[Translation missing --]]
	L["Length of |cFFFF0000%s|r"] = "Length of |cFFFF0000%s|r"
	--[[Translation missing --]]
	L["LibCompress: Galmok"] = "LibCompress: Galmok"
	--[[Translation missing --]]
	L["LibCustomGlow: Dooez"] = "LibCustomGlow: Dooez"
	--[[Translation missing --]]
	L["LibDeflate: Yoursafety"] = "LibDeflate: Yoursafety"
	--[[Translation missing --]]
	L["LibDispel: Simpy"] = "LibDispel: Simpy"
	--[[Translation missing --]]
	L["LibSerialize: Sanjo"] = "LibSerialize: Sanjo"
	--[[Translation missing --]]
	L["LibSpecialization: Funkeh"] = "LibSpecialization: Funkeh"
	--[[Translation missing --]]
	L["Limit"] = "Limit"
	--[[Translation missing --]]
	L["Line"] = "Line"
	--[[Translation missing --]]
	L["Linear Texture %s"] = "Linear Texture %s"
	--[[Translation missing --]]
	L["Linked aura: "] = "Linked aura: "
	--[[Translation missing --]]
	L["Linked Auras"] = "Linked Auras"
	--[[Translation missing --]]
	L["Load"] = "Load"
	--[[Translation missing --]]
	L["Loaded"] = "Loaded"
	--[[Translation missing --]]
	L["Loaded/Standby"] = "Loaded/Standby"
	--[[Translation missing --]]
	L["Lock Positions"] = "Lock Positions"
	--[[Translation missing --]]
	L["Low Mana"] = "Low Mana"
	--[[Translation missing --]]
	L["Magnetically Align"] = "Magnetically Align"
	--[[Translation missing --]]
	L["Main"] = "Main"
	--[[Translation missing --]]
	L["Manual with %i/%i"] = "Manual with %i/%i"
	--[[Translation missing --]]
	L["Matches %s spells"] = "Matches %s spells"
	--[[Translation missing --]]
	L["Matches the height setting of a horizontal bar or width for a vertical bar."] = "Matches the height setting of a horizontal bar or width for a vertical bar."
	--[[Translation missing --]]
	L["Max"] = "Max"
	--[[Translation missing --]]
	L["Max Length"] = "Max Length"
	--[[Translation missing --]]
	L["Maximum"] = "Maximum"
	--[[Translation missing --]]
	L["Media Type"] = "Media Type"
	--[[Translation missing --]]
	L["Medium Icon"] = "Medium Icon"
	--[[Translation missing --]]
	L["Min"] = "Min"
	--[[Translation missing --]]
	L["Minimum"] = "Minimum"
	--[[Translation missing --]]
	L["Model %s"] = "Model %s"
	--[[Translation missing --]]
	L["Model Picker"] = "Model Picker"
	--[[Translation missing --]]
	L["Model Settings"] = "Model Settings"
	--[[Translation missing --]]
	L["ModelPaths could not be loaded, the addon is %s"] = "ModelPaths could not be loaded, the addon is %s"
	--[[Translation missing --]]
	L["Move Above Group"] = "Move Above Group"
	--[[Translation missing --]]
	L["Move Below Group"] = "Move Below Group"
	--[[Translation missing --]]
	L["Move Down"] = "Move Down"
	--[[Translation missing --]]
	L["Move Entry Down"] = "Move Entry Down"
	--[[Translation missing --]]
	L["Move Entry Up"] = "Move Entry Up"
	--[[Translation missing --]]
	L["Move Into Above Group"] = "Move Into Above Group"
	--[[Translation missing --]]
	L["Move Into Below Group"] = "Move Into Below Group"
	--[[Translation missing --]]
	L["Move this display down in its group's order"] = "Move this display down in its group's order"
	--[[Translation missing --]]
	L["Move this display up in its group's order"] = "Move this display up in its group's order"
	--[[Translation missing --]]
	L["Move Up"] = "Move Up"
	--[[Translation missing --]]
	L["Moving auras: "] = "Moving auras: "
	--[[Translation missing --]]
	L["Multiple Displays"] = "Multiple Displays"
	--[[Translation missing --]]
	L["Multiselect ignored tooltip"] = [=[|cFFFF0000Ignored|r - |cFF777777Single|r - |cFF777777Multiple|r
This option will not be used to determine when this display should load]=]
	--[[Translation missing --]]
	L["Multiselect multiple tooltip"] = [=[|cFF777777Ignored|r - |cFF777777Single|r - |cFF00FF00Multiple|r
Any number of matching values can be picked]=]
	--[[Translation missing --]]
	L["Multiselect single tooltip"] = [=[|cFF777777Ignored|r - |cFF00FF00Single|r - |cFF777777Multiple|r
Only a single matching value can be picked]=]
	--[[Translation missing --]]
	L["Must be a power of 2"] = "Must be a power of 2"
	--[[Translation missing --]]
	L["Name - The name of the display (usually an aura name), or the display's ID if there is no dynamic name"] = "Name - The name of the display (usually an aura name), or the display's ID if there is no dynamic name"
	--[[Translation missing --]]
	L["Name Info"] = "Name Info"
	--[[Translation missing --]]
	L["Name Pattern Match"] = "Name Pattern Match"
	--[[Translation missing --]]
	L["Name:"] = "Name:"
	--[[Translation missing --]]
	L["Negator"] = "Not"
	--[[Translation missing --]]
	L["New Aura"] = "New Aura"
	--[[Translation missing --]]
	L["New Template"] = "New Template"
	--[[Translation missing --]]
	L["New Value"] = "New Value"
	--[[Translation missing --]]
	L["No Children"] = "No Children"
	--[[Translation missing --]]
	L["No Logs saved."] = "No Logs saved."
	--[[Translation missing --]]
	L["Not a table"] = "Not a table"
	--[[Translation missing --]]
	L["Not all children have the same value for this option"] = "Not all children have the same value for this option"
	--[[Translation missing --]]
	L["Not Loaded"] = "Not Loaded"
	--[[Translation missing --]]
	L["Note: Automated Messages to SAY and YELL are blocked outside of Instances."] = "Note: Automated Messages to SAY and YELL are blocked outside of Instances."
	--[[Translation missing --]]
	L["Note: This progress source does not provide a total value/duration. A total value/duration must be set via \"Set Maximum Progress\""] = "Note: This progress source does not provide a total value/duration. A total value/duration must be set via \"Set Maximum Progress\""
	--[[Translation missing --]]
	L["Number of Entries"] = "Number of Entries"
	--[[Translation missing --]]
	L[ [=[Occurrence of the event, reset when aura is unloaded
Can be a range of values
Can have multiple values separated by a comma or a space

Examples:
2nd 5th and 6th events: 2, 5, 6
2nd to 6th: 2-6
every 2 events: /2
every 3 events starting from 2nd: 2/3
every 3 events starting from 2nd and ending at 11th: 2-11/3]=] ] = [=[Occurrence of the event, reset when aura is unloaded
Can be a range of values
Can have multiple values separated by a comma or a space

Examples:
2nd 5th and 6th events: 2, 5, 6
2nd to 6th: 2-6
every 2 events: /2
every 3 events starting from 2nd: 2/3
every 3 events starting from 2nd and ending at 11th: 2-11/3]=]
	--[[Translation missing --]]
	L["OFF"] = "OFF"
	--[[Translation missing --]]
	L["Offer a guided way to create auras for your character"] = "Offer a guided way to create auras for your character"
	--[[Translation missing --]]
	L["Offset by |cFFFF0000%s|r/|cFFFF0000%s|r"] = "Offset by |cFFFF0000%s|r/|cFFFF0000%s|r"
	--[[Translation missing --]]
	L["Offset by 1px"] = "Offset by 1px"
	--[[Translation missing --]]
	L["Okay"] = "Okay"
	--[[Translation missing --]]
	L["ON"] = "ON"
	--[[Translation missing --]]
	L["On Hide"] = "On Hide"
	--[[Translation missing --]]
	L["On Show"] = "On Show"
	--[[Translation missing --]]
	L["Only Match auras cast by a player (not an npc)"] = "Only Match auras cast by a player (not an npc)"
	--[[Translation missing --]]
	L["Only match auras cast by people other than the player or their pet"] = "Only match auras cast by people other than the player or their pet"
	--[[Translation missing --]]
	L["Only match auras cast by the player or their pet"] = "Only match auras cast by the player or their pet"
	--[[Translation missing --]]
	L["Operator"] = "Operator"
	--[[Translation missing --]]
	L["Option %i"] = "Option %i"
	--[[Translation missing --]]
	L["Option key"] = "Option key"
	--[[Translation missing --]]
	L["Option Type"] = "Option Type"
	--[[Translation missing --]]
	L["Options will open after combat ends."] = "Options will open after combat ends."
	--[[Translation missing --]]
	L["or"] = "or"
	--[[Translation missing --]]
	L["or %s"] = "or %s"
	--[[Translation missing --]]
	L["Orange Rune"] = "Orange Rune"
	--[[Translation missing --]]
	L["Our translators (too many to name)"] = "Our translators (too many to name)"
	--[[Translation missing --]]
	L["Outer"] = "Outer"
	--[[Translation missing --]]
	L["Overflow"] = "Overflow"
	--[[Translation missing --]]
	L["Overlay %s Info"] = "Overlay %s Info"
	--[[Translation missing --]]
	L["Overlays"] = "Overlays"
	--[[Translation missing --]]
	L["Own Only"] = "Own Only"
	--[[Translation missing --]]
	L["Paste Action Settings"] = "Paste Action Settings"
	--[[Translation missing --]]
	L["Paste Animations Settings"] = "Paste Animations Settings"
	--[[Translation missing --]]
	L["Paste Author Options Settings"] = "Paste Author Options Settings"
	--[[Translation missing --]]
	L["Paste Condition Settings"] = "Paste Condition Settings"
	--[[Translation missing --]]
	L["Paste Custom Configuration"] = "Paste Custom Configuration"
	--[[Translation missing --]]
	L["Paste Display Settings"] = "Paste Display Settings"
	--[[Translation missing --]]
	L["Paste Group Settings"] = "Paste Group Settings"
	--[[Translation missing --]]
	L["Paste Load Settings"] = "Paste Load Settings"
	--[[Translation missing --]]
	L["Paste Settings"] = "Paste Settings"
	--[[Translation missing --]]
	L["Paste text below"] = "Paste text below"
	--[[Translation missing --]]
	L["Paste Trigger Settings"] = "Paste Trigger Settings"
	--[[Translation missing --]]
	L["Places a tick on the bar"] = "Places a tick on the bar"
	--[[Translation missing --]]
	L["Play Sound"] = "Play Sound"
	--[[Translation missing --]]
	L["Player Spells found:"] = "Player Spells found:"
	--[[Translation missing --]]
	L["Portrait Zoom"] = "Portrait Zoom"
	--[[Translation missing --]]
	L["Position and Size Settings"] = "Position and Size Settings"
	--[[Translation missing --]]
	L["Preferred Match"] = "Preferred Match"
	--[[Translation missing --]]
	L["Premade Auras"] = "Premade Auras"
	--[[Translation missing --]]
	L["Premade Snippets"] = "Premade Snippets"
	--[[Translation missing --]]
	L["Preparing auras: "] = "Preparing auras: "
	--[[Translation missing --]]
	L["Press Ctrl+C to copy"] = "Press Ctrl+C to copy"
	--[[Translation missing --]]
	L["Press Ctrl+C to copy the URL"] = "Press Ctrl+C to copy the URL"
	--[[Translation missing --]]
	L["Prevent Merging"] = "Prevent Merging"
	--[[Translation missing --]]
	L["Progress - The remaining time of a timer, or a non-timer value"] = "Progress - The remaining time of a timer, or a non-timer value"
	--[[Translation missing --]]
	L["Progress Bar"] = "Progress Bar"
	--[[Translation missing --]]
	L["Progress Bar Settings"] = "Progress Bar Settings"
	--[[Translation missing --]]
	L["Progress Settings"] = "Progress Settings"
	--[[Translation missing --]]
	L["Progress Texture"] = "Progress Texture"
	--[[Translation missing --]]
	L["Progress Texture Settings"] = "Progress Texture Settings"
	--[[Translation missing --]]
	L["Purple Rune"] = "Purple Rune"
	--[[Translation missing --]]
	L["Put this display in a group"] = "Put this display in a group"
	--[[Translation missing --]]
	L["Range in yards"] = "Range in yards"
	--[[Translation missing --]]
	L["Ready for Install"] = "Ready for Install"
	--[[Translation missing --]]
	L["Ready for Update"] = "Ready for Update"
	--[[Translation missing --]]
	L["Re-center X"] = "Re-center X"
	--[[Translation missing --]]
	L["Re-center Y"] = "Re-center Y"
	--[[Translation missing --]]
	L["Reciprocal TRIGGER:# requests will be ignored!"] = "Reciprocal TRIGGER:# requests will be ignored!"
	--[[Translation missing --]]
	L["Redo"] = "Redo"
	--[[Translation missing --]]
	L["Regions of type \"%s\" are not supported."] = "Regions of type \"%s\" are not supported."
	--[[Translation missing --]]
	L["Remove"] = "Remove"
	--[[Translation missing --]]
	L["Remove All Sounds"] = "Remove All Sounds"
	--[[Translation missing --]]
	L["Remove All Text To Speech"] = "Remove All Text To Speech"
	--[[Translation missing --]]
	L["Remove this display from its group"] = "Remove this display from its group"
	--[[Translation missing --]]
	L["Remove this property"] = "Remove this property"
	--[[Translation missing --]]
	L["Rename"] = "Rename"
	--[[Translation missing --]]
	L["Repeat After"] = "Repeat After"
	--[[Translation missing --]]
	L["Repeat every"] = "Repeat every"
	--[[Translation missing --]]
	L["Report bugs on our issue tracker."] = "Report bugs on our issue tracker."
	--[[Translation missing --]]
	L["Require unit from trigger"] = "Require unit from trigger"
	--[[Translation missing --]]
	L["Required for Activation"] = "Required for Activation"
	--[[Translation missing --]]
	L["Requires LibSpecialization, that is e.g. a up-to date KUIAR_Runtime version"] = "Requires LibSpecialization, that is e.g. a up-to date KUIAR_Runtime version"
	--[[Translation missing --]]
	L["Reset all options to their default values."] = "Reset all options to their default values."
	--[[Translation missing --]]
	L["Reset Entry"] = "Reset Entry"
	--[[Translation missing --]]
	L["Reset to Defaults"] = "Reset to Defaults"
	--[[Translation missing --]]
	L["Right 2 HUD position"] = "Right 2 HUD position"
	--[[Translation missing --]]
	L["Right HUD position"] = "Right HUD position"
	--[[Translation missing --]]
	L["Right-click for more options"] = "Right-click for more options"
	--[[Translation missing --]]
	L["Rotate"] = "Rotate"
	--[[Translation missing --]]
	L["Rotate In"] = "Rotate In"
	--[[Translation missing --]]
	L["Rotate Out"] = "Rotate Out"
	--[[Translation missing --]]
	L["Rotate Text"] = "Rotate Text"
	--[[Translation missing --]]
	L["Rotation Mode"] = "Rotation Mode"
	--[[Translation missing --]]
	L["Row Space"] = "Row Space"
	--[[Translation missing --]]
	L["Row Width"] = "Row Width"
	--[[Translation missing --]]
	L["Rows"] = "Rows"
	--[[Translation missing --]]
	L["Run on..."] = "Run on..."
	--[[Translation missing --]]
	L["Same"] = "Same"
	--[[Translation missing --]]
	L["Same texture as Foreground"] = "Same texture as Foreground"
	--[[Translation missing --]]
	L["Saved Data"] = "Saved Data"
	--[[Translation missing --]]
	L["Scale Factor"] = "Scale Factor"
	--[[Translation missing --]]
	L["Search API"] = "Search API"
	--[[Translation missing --]]
	L["Select Talent"] = "Select Talent"
	--[[Translation missing --]]
	L["Select the auras you always want to be listed first"] = "Select the auras you always want to be listed first"
	--[[Translation missing --]]
	L["Selected Frame"] = "Selected Frame"
	--[[Translation missing --]]
	L["Send To"] = "Send To"
	--[[Translation missing --]]
	L["Separator Text"] = "Separator Text"
	--[[Translation missing --]]
	L["Separator text"] = "Separator text"
	--[[Translation missing --]]
	L["Set Maximum Progress"] = "Set Maximum Progress"
	--[[Translation missing --]]
	L["Set Minimum Progress"] = "Set Minimum Progress"
	--[[Translation missing --]]
	L["Set Parent to Anchor"] = "Set Parent to Anchor"
	--[[Translation missing --]]
	L["Set Thumbnail Icon"] = "Set Thumbnail Icon"
	--[[Translation missing --]]
	L["Sets the anchored frame as the aura's parent, causing the aura to inherit attributes such as visibility and scale."] = "Sets the anchored frame as the aura's parent, causing the aura to inherit attributes such as visibility and scale."
	--[[Translation missing --]]
	L["Settings"] = "Settings"
	--[[Translation missing --]]
	L["Shadow Color"] = "Shadow Color"
	--[[Translation missing --]]
	L["Shadow X Offset"] = "Shadow X Offset"
	--[[Translation missing --]]
	L["Shadow Y Offset"] = "Shadow Y Offset"
	--[[Translation missing --]]
	L["Shift-click to create chat link"] = "Shift-click to create a |cFF8800FF[Chat Link]"
	--[[Translation missing --]]
	L["Show \"Edge\""] = "Show \"Edge\""
	--[[Translation missing --]]
	L["Show \"Swipe\""] = "Show \"Swipe\""
	--[[Translation missing --]]
	L["Show and Clone Settings"] = "Show and Clone Settings"
	--[[Translation missing --]]
	L["Show Border"] = "Show Border"
	--[[Translation missing --]]
	L["Show Circular Texture"] = "Show Circular Texture"
	--[[Translation missing --]]
	L["Show Debug Logs"] = "Show Debug Logs"
	--[[Translation missing --]]
	L["Show Glow"] = "Show Glow"
	--[[Translation missing --]]
	L["Show Icon"] = "Show Icon"
	--[[Translation missing --]]
	L["Show If Unit Does Not Exist"] = "Show If Unit Does Not Exist"
	--[[Translation missing --]]
	L["Show Linear Texture"] = "Show Linear Texture"
	--[[Translation missing --]]
	L["Show Matches for"] = "Show Matches for"
	--[[Translation missing --]]
	L["Show Matches for Units"] = "Show Matches for Units"
	--[[Translation missing --]]
	L["Show Model"] = "Show Model"
	--[[Translation missing --]]
	L["Show model of unit "] = "Show model of unit "
	--[[Translation missing --]]
	L["Show Sound Setting"] = "Show Sound Setting"
	--[[Translation missing --]]
	L["Show Spark"] = "Show Spark"
	--[[Translation missing --]]
	L["Show Stop Motion"] = "Show Stop Motion"
	--[[Translation missing --]]
	L["Show Text"] = "Show Text"
	--[[Translation missing --]]
	L["Show Text To Speech Setting"] = "Show Text To Speech Setting"
	--[[Translation missing --]]
	L["Show Texture"] = "Show Texture"
	--[[Translation missing --]]
	L["Show this group's children"] = "Show this group's children"
	--[[Translation missing --]]
	L["Show Tick"] = "Show Tick"
	--[[Translation missing --]]
	L["Shows a 3D model from the game files"] = "Shows a 3D model from the game files"
	--[[Translation missing --]]
	L["Shows a border"] = "Shows a border"
	--[[Translation missing --]]
	L["Shows a Circular Progress Texture"] = "Shows a Circular Progress Texture"
	--[[Translation missing --]]
	L["Shows a custom texture"] = "Shows a custom texture"
	--[[Translation missing --]]
	L["Shows a glow"] = "Shows a glow"
	--[[Translation missing --]]
	L["Shows a Linear Progress Texture"] = "Shows a Linear Progress Texture"
	--[[Translation missing --]]
	L["Shows a model"] = "Shows a model"
	--[[Translation missing --]]
	L["Shows a progress bar with name, timer, and icon"] = "Shows a progress bar with name, timer, and icon"
	--[[Translation missing --]]
	L["Shows a spell icon with an optional cooldown overlay"] = "Shows a spell icon with an optional cooldown overlay"
	--[[Translation missing --]]
	L["Shows a Stop Motion"] = "Shows a Stop Motion"
	--[[Translation missing --]]
	L["Shows a stop motion texture"] = "Shows a stop motion texture"
	--[[Translation missing --]]
	L["Shows a Texture"] = "Shows a Texture"
	--[[Translation missing --]]
	L["Shows a texture that changes based on duration"] = "Shows a texture that changes based on duration"
	--[[Translation missing --]]
	L["Shows nothing, except sub elements"] = "Shows nothing, except sub elements"
	--[[Translation missing --]]
	L["Shows one or more lines of text, which can include dynamic information such as progress or stacks"] = "Shows one or more lines of text, which can include dynamic information such as progress or stacks"
	--[[Translation missing --]]
	L["Size"] = "Size"
	--[[Translation missing --]]
	L["Slant Amount"] = "Slant Amount"
	--[[Translation missing --]]
	L["Slant Mode"] = "Slant Mode"
	--[[Translation missing --]]
	L["Slanted"] = "Slanted"
	--[[Translation missing --]]
	L["Slide"] = "Slide"
	--[[Translation missing --]]
	L["Slide In"] = "Slide In"
	--[[Translation missing --]]
	L["Slide Out"] = "Slide Out"
	--[[Translation missing --]]
	L["Slider Step Size"] = "Slider Step Size"
	--[[Translation missing --]]
	L["Small Icon"] = "Small Icon"
	--[[Translation missing --]]
	L["Smooth Progress"] = "Smooth Progress"
	--[[Translation missing --]]
	L["Snippets"] = "Snippets"
	--[[Translation missing --]]
	L["Soft Max"] = "Soft Max"
	--[[Translation missing --]]
	L["Soft Min"] = "Soft Min"
	--[[Translation missing --]]
	L["Sort"] = "Sort"
	--[[Translation missing --]]
	L["Sound Channel"] = "Sound Channel"
	--[[Translation missing --]]
	L["Sound File Path"] = "Sound File Path"
	--[[Translation missing --]]
	L["Sound Kit ID"] = "Sound Kit ID"
	--[[Translation missing --]]
	L["Space Horizontally"] = "Space Horizontally"
	--[[Translation missing --]]
	L["Space Vertically"] = "Space Vertically"
	--[[Translation missing --]]
	L["Spark Settings"] = "Spark Settings"
	--[[Translation missing --]]
	L["Spark Texture"] = "Spark Texture"
	--[[Translation missing --]]
	L["Specific Currency ID"] = "Specific Currency ID"
	--[[Translation missing --]]
	L["Spell Selection Filters"] = "Spell Selection Filters"
	--[[Translation missing --]]
	L["Spells found:"] = "Spells found:"
	--[[Translation missing --]]
	L["Stack Info"] = "Stack Info"
	--[[Translation missing --]]
	L["Stacks - The number of stacks of an aura (usually)"] = "Stacks - The number of stacks of an aura (usually)"
	--[[Translation missing --]]
	L["Standby"] = "Standby"
	--[[Translation missing --]]
	L["Star"] = "Star"
	--[[Translation missing --]]
	L["Start"] = "Start"
	--[[Translation missing --]]
	L["Start Angle"] = "Start Angle"
	--[[Translation missing --]]
	L["Start Collapsed"] = "Start Collapsed"
	--[[Translation missing --]]
	L["Start of %s"] = "Start of %s"
	--[[Translation missing --]]
	L["Step Size"] = "Step Size"
	--[[Translation missing --]]
	L["Stop Motion %s"] = "Stop Motion %s"
	--[[Translation missing --]]
	L["Stop Motion Settings"] = "Stop Motion Settings"
	--[[Translation missing --]]
	L["Stop Sound"] = "Stop Sound"
	--[[Translation missing --]]
	L["Stretched by Foreground"] = "Stretched by Foreground"
	--[[Translation missing --]]
	L["Sub Elements"] = "Sub Elements"
	--[[Translation missing --]]
	L["Sub Option %i"] = "Sub Option %i"
	--[[Translation missing --]]
	L["Subevent"] = "Subevent"
	--[[Translation missing --]]
	L["Subevent Suffix"] = "Subevent Suffix"
	--[[Translation missing --]]
	L["Swipe Overlay Settings"] = "Swipe Overlay Settings"
	--[[Translation missing --]]
	L["Templates could not be loaded, the addon is %s"] = "Templates could not be loaded, the addon is %s"
	--[[Translation missing --]]
	L["Temporary Group"] = "Temporary Group"
	--[[Translation missing --]]
	L["Text %s"] = "Text %s"
	--[[Translation missing --]]
	L["Text Color"] = "Text Color"
	--[[Translation missing --]]
	L["Text Settings"] = "Text Settings"
	--[[Translation missing --]]
	L["Texture %s"] = "Texture %s"
	--[[Translation missing --]]
	L["Texture Info"] = "Texture Info"
	--[[Translation missing --]]
	L["Texture Selection Mode"] = "Texture Selection Mode"
	--[[Translation missing --]]
	L["Texture Settings"] = "Texture Settings"
	--[[Translation missing --]]
	L["Texture Wrap"] = "Texture Wrap"
	--[[Translation missing --]]
	L["Texture X Offset"] = "Texture X Offset"
	--[[Translation missing --]]
	L["Texture Y Offset"] = "Texture Y Offset"
	--[[Translation missing --]]
	L["Thanks"] = "Thanks"
	--[[Translation missing --]]
	L["The addon ElvUI is enabled. It might add cooldown numbers to the swipe. You can configure these in the ElvUI settings"] = "The addon ElvUI is enabled. It might add cooldown numbers to the swipe. You can configure these in the ElvUI settings"
	--[[Translation missing --]]
	L["The addon OmniCC is enabled. It might add cooldown numbers to the swipe. You can configure these in the OmniCC settings"] = "The addon OmniCC is enabled. It might add cooldown numbers to the swipe. You can configure these in the OmniCC settings"
	--[[Translation missing --]]
	L["The duration of the animation in seconds."] = "The duration of the animation in seconds."
	--[[Translation missing --]]
	L["The duration of the animation in seconds. The finish animation does not start playing until after the display would normally be hidden."] = "The duration of the animation in seconds. The finish animation does not start playing until after the display would normally be hidden."
	--[[Translation missing --]]
	L["The group and all direct children will share the same base frame level."] = "The group and all direct children will share the same base frame level."
	--[[Translation missing --]]
	L["The Multi Target mode is less reliable and not recommended."] = "The Multi Target mode is less reliable and not recommended."
	--[[Translation missing --]]
	L["The Multi Target mode requires a name or spell id filter"] = "The Multi Target mode requires a name or spell id filter"
	--[[Translation missing --]]
	L["The trigger number is optional. When no trigger number is specified, the trigger selected via dynamic information will be used."] = "The trigger number is optional. When no trigger number is specified, the trigger selected via dynamic information will be used."
	--[[Translation missing --]]
	L["The type of trigger"] = "The type of trigger"
	--[[Translation missing --]]
	L["The KUIAR_Runtime Options Addon version %s doesn't match the KUIAR_Runtime version %s. If you updated the addon while the game was running, try restarting World of Warcraft. Otherwise try reinstalling KUIAR_Runtime"] = "The KUIAR_Runtime Options Addon version %s doesn't match the KUIAR_Runtime version %s. If you updated the addon while the game was running, try restarting World of Warcraft. Otherwise try reinstalling KUIAR_Runtime"
	--[[Translation missing --]]
	L["Then "] = "Then "
	--[[Translation missing --]]
	L["There are several special codes available to make this text dynamic. Click to view a list with all dynamic text codes."] = "There are several special codes available to make this text dynamic. Click to view a list with all dynamic text codes."
	--[[Translation missing --]]
	L["This adds %raidMark as text replacements."] = "This adds %raidMark as text replacements."
	--[[Translation missing --]]
	L["This adds %role, %roleIcon as text replacements. Does nothing if the unit is not a group member."] = "This adds %role, %roleIcon as text replacements. Does nothing if the unit is not a group member."
	--[[Translation missing --]]
	L["This adds %tooltip, %tooltip1, %tooltip2, %tooltip3 and %tooltip4 as text replacements and also allows filtering based on the tooltip content/values."] = "This adds %tooltip, %tooltip1, %tooltip2, %tooltip3 and %tooltip4 as text replacements and also allows filtering based on the tooltip content/values."
	--[[Translation missing --]]
	L[ [=[This aura contains custom Lua code.
Make sure you can trust the person who sent it!]=] ] = [=[This aura contains custom Lua code.
Make sure you can trust the person who sent it!]=]
	--[[Translation missing --]]
	L["This aura is marked as an update to an aura '%s', but cannot be used to update that aura. This usually happens if an aura is moved out of a group."] = "This aura is marked as an update to an aura '%s', but cannot be used to update that aura. This usually happens if an aura is moved out of a group."
	--[[Translation missing --]]
	L["This aura is marked as an update to auras '%s', but cannot be used to update them. This usually happens if an aura is moved out of a group."] = "This aura is marked as an update to auras '%s', but cannot be used to update them. This usually happens if an aura is moved out of a group."
	--[[Translation missing --]]
	L[ [=[This aura was created with a different version (%s) of World of Warcraft.
It might not work correctly!]=] ] = [=[This aura was created with a different version (%s) of World of Warcraft.
It might not work correctly!]=]
	--[[Translation missing --]]
	L[ [=[This aura was created with a newer version of KUIAR_Runtime.
Upgrade your version of KUIAR_Runtime or wait for next release before installing this aura.]=] ] = [=[This aura was created with a newer version of KUIAR_Runtime.
Upgrade your version of KUIAR_Runtime or wait for next release before installing this aura.]=]
	--[[Translation missing --]]
	L["This display is currently loaded"] = "This display is currently loaded"
	--[[Translation missing --]]
	L["This display is not currently loaded"] = "This display is not currently loaded"
	--[[Translation missing --]]
	L["This display is on standby, it will be loaded when needed."] = "This display is on standby, it will be loaded when needed."
	--[[Translation missing --]]
	L["This enables the collection of debug logs. Custom code can add debug information to the log through the function DebugPrint."] = "This enables the collection of debug logs. Custom code can add debug information to the log through the function DebugPrint."
	--[[Translation missing --]]
	L["This is a modified version of your aura, |cff9900FF%s.|r"] = "This is a modified version of your aura, |cff9900FF%s.|r"
	--[[Translation missing --]]
	L["This is a modified version of your group: |cff9900FF%s|r"] = "This is a modified version of your group: |cff9900FF%s|r"
	--[[Translation missing --]]
	L["This region of type \"%s\" is not supported."] = "This region of type \"%s\" is not supported."
	--[[Translation missing --]]
	L["This setting controls what widget is generated in user mode."] = "This setting controls what widget is generated in user mode."
	--[[Translation missing --]]
	L["Thumbnail Icon"] = "Thumbnail Icon"
	--[[Translation missing --]]
	L["Tick %s"] = "Tick %s"
	--[[Translation missing --]]
	L["Tick Area %s"] = "Tick Area %s"
	--[[Translation missing --]]
	L["Tick Center %s"] = "Tick Center %s"
	--[[Translation missing --]]
	L["Tick Mode"] = "Tick Mode"
	--[[Translation missing --]]
	L["Tick Placement"] = "Tick Placement"
	--[[Translation missing --]]
	L["Time in"] = "Time in"
	--[[Translation missing --]]
	L["Tiny Icon"] = "Tiny Icon"
	--[[Translation missing --]]
	L["To Frame's"] = "To Frame's"
	--[[Translation missing --]]
	L["To Group's"] = "To Group's"
	--[[Translation missing --]]
	L["To Personal Ressource Display's"] = "To Personal Ressource Display's"
	--[[Translation missing --]]
	L["To Region's"] = "To Region's"
	--[[Translation missing --]]
	L["To Screen's"] = "To Screen's"
	--[[Translation missing --]]
	L["Toggle the visibility of all loaded displays"] = "Toggle the visibility of all loaded displays"
	--[[Translation missing --]]
	L["Toggle the visibility of all non-loaded displays"] = "Toggle the visibility of all non-loaded displays"
	--[[Translation missing --]]
	L["Toggle the visibility of this display"] = "Toggle the visibility of this display"
	--[[Translation missing --]]
	L["Tooltip Content"] = "Tooltip Content"
	--[[Translation missing --]]
	L["Tooltip on Mouseover"] = "Tooltip on Mouseover"
	--[[Translation missing --]]
	L["Tooltip Pattern Match"] = "Tooltip Pattern Match"
	--[[Translation missing --]]
	L["Tooltip Text"] = "Tooltip Text"
	--[[Translation missing --]]
	L["Tooltip Value"] = "Tooltip Value"
	--[[Translation missing --]]
	L["Tooltip Value #"] = "Tooltip Value #"
	--[[Translation missing --]]
	L["Top HUD position"] = "Top HUD position"
	--[[Translation missing --]]
	L["Total"] = "Total"
	--[[Translation missing --]]
	L["Total - The maximum duration of a timer, or a maximum non-timer value"] = "Total - The maximum duration of a timer, or a maximum non-timer value"
	--[[Translation missing --]]
	L["Total Angle"] = "Total Angle"
	--[[Translation missing --]]
	L["Total Time"] = "Total Time"
	--[[Translation missing --]]
	L["Trigger %i: %s"] = "Trigger %i: %s"
	--[[Translation missing --]]
	L["Trigger Combination"] = "Trigger Combination"
	--[[Translation missing --]]
	L["Type 'select' for '%s' requires a values member'"] = "Type 'select' for '%s' requires a values member'"
	--[[Translation missing --]]
	L["Undo"] = "Undo"
	--[[Translation missing --]]
	L["Ungroup"] = "Ungroup"
	--[[Translation missing --]]
	L["Unit %s is not a valid unit for RegisterUnitEvent"] = "Unit %s is not a valid unit for RegisterUnitEvent"
	--[[Translation missing --]]
	L["Unit Count"] = "Unit Count"
	--[[Translation missing --]]
	L["Unknown"] = "Unknown"
	--[[Translation missing --]]
	L["Unknown Encounter's Spell Id"] = "Unknown Encounter's Spell Id"
	--[[Translation missing --]]
	L["Unknown property '%s' found in '%s'"] = "Unknown property '%s' found in '%s'"
	--[[Translation missing --]]
	L["Unknown Spell"] = "Unknown Spell"
	--[[Translation missing --]]
	L["Unlike the start or finish animations, the main animation will loop over and over until the display is hidden."] = "Unlike the start or finish animations, the main animation will loop over and over until the display is hidden."
	--[[Translation missing --]]
	L["Update"] = "Update"
	--[[Translation missing --]]
	L["Update Auras"] = "Update Auras"
	--[[Translation missing --]]
	L["Update Custom Text On..."] = "Update Custom Text On..."
	--[[Translation missing --]]
	L["URL"] = "URL"
	--[[Translation missing --]]
	L["Url: %s"] = "Url: %s"
	--[[Translation missing --]]
	L["Use Display Info Id"] = "Use Display Info Id"
	--[[Translation missing --]]
	L["Use SetTransform"] = "Use SetTransform"
	--[[Translation missing --]]
	L["Used in Auras:"] = "Used in Auras:"
	--[[Translation missing --]]
	L["Used in auras:"] = "Used in auras:"
	--[[Translation missing --]]
	L["Uses Texture Coordinates to rotate the texture."] = "Uses Texture Coordinates to rotate the texture."
	--[[Translation missing --]]
	--[[Translation missing --]]
	L["Value"] = "Value"
	--[[Translation missing --]]
	L["Value %i"] = "Value %i"
	--[[Translation missing --]]
	L["Values are in normalized rgba format."] = "Values are in normalized rgba format."
	--[[Translation missing --]]
	L["Values/Remaining Time above this value are displayed as full progress."] = "Values/Remaining Time above this value are displayed as full progress."
	--[[Translation missing --]]
	L["Values/Remaining Time below this value are displayed as zero progress."] = "Values/Remaining Time below this value are displayed as zero progress."
	--[[Translation missing --]]
	L["Values:"] = "Values:"
	--[[Translation missing --]]
	L["Version: "] = "Version: "
	--[[Translation missing --]]
	L["Version: %s"] = "Version: %s"
	--[[Translation missing --]]
	L["Vertical Align"] = "Vertical Align"
	--[[Translation missing --]]
	L["Vertical Bar"] = "Vertical Bar"
	--[[Translation missing --]]
	L["View"] = "View"
	--[[Translation missing --]]
	L["View custom code"] = "View custom code"
	--[[Translation missing --]]
	L["Voice Settings"] = "Voice Settings"
	--[[Translation missing --]]
	L["We thank"] = "We thank"
	--[[Translation missing --]]
	L["KUIAR_Engine %s on WoW %s"] = "KUIAR_Engine %s on WoW %s"
	--[[Translation missing --]]
	L["KUIAR_Engine recommends using spell ids instead of names. Spell ids are automatically localized."] = "KUIAR_Engine recommends using spell ids instead of names. Spell ids are automatically localized."
	--[[Translation missing --]]
	L["What do you want to do?"] = "What do you want to do?"
	--[[Translation missing --]]
	L["Whole Area"] = "Whole Area"
	--[[Translation missing --]]
	L["wrapping"] = "wrapping"
	--[[Translation missing --]]
	L["X Offset"] = "X Offset"
	--[[Translation missing --]]
	L["X Rotation"] = "X Rotation"
	--[[Translation missing --]]
	L["X Scale"] = "X Scale"
	--[[Translation missing --]]
	L["x-Offset"] = "x-Offset"
	--[[Translation missing --]]
	L["Y Offset"] = "Y Offset"
	--[[Translation missing --]]
	L["Y Rotation"] = "Y Rotation"
	--[[Translation missing --]]
	L["Y Scale"] = "Y Scale"
	--[[Translation missing --]]
	L["Yellow Rune"] = "Yellow Rune"
	--[[Translation missing --]]
	L["y-Offset"] = "y-Offset"
	--[[Translation missing --]]
	L["You already have this group/aura. Importing will create a duplicate."] = "You already have this group/aura. Importing will create a duplicate."
	--[[Translation missing --]]
	L["You are about to delete %d aura(s). |cFFFF0000This cannot be undone!|r Would you like to continue?"] = "You are about to delete %d aura(s). |cFFFF0000This cannot be undone!|r Would you like to continue?"
	--[[Translation missing --]]
	L["You are about to delete a trigger. |cFFFF0000This cannot be undone!|r Would you like to continue?"] = "You are about to delete a trigger. |cFFFF0000This cannot be undone!|r Would you like to continue?"
	--[[Translation missing --]]
	L[ [=[You are about to Import an Aura with custom Lua code on a Hardcore server.

|cFFFF0000There is a risk the custom code could be used to kill your hardcore character!|r

Would you like to continue?]=] ] = [=[You are about to Import an Aura with custom Lua code on a Hardcore server.

|cFFFF0000There is a risk the custom code could be used to kill your hardcore character!|r

Would you like to continue?]=]
	--[[Translation missing --]]
	L[ [=[You can add a comma-separated list of state values here that (when changed) KUIAR_Runtime should also run the Anchor Code on.

KUIAR_Runtime will always run custom anchor code if you include 'changed' in this list, or when a region is added, removed, or re-ordered.]=] ] = [=[You can add a comma-separated list of state values here that (when changed) KUIAR_Runtime should also run the Anchor Code on.

KUIAR_Runtime will always run custom anchor code if you include 'changed' in this list, or when a region is added, removed, or re-ordered.]=]
	--[[Translation missing --]]
	L[ [=[You can add a comma-separated list of state values here that (when changed) KUIAR_Runtime should also run the Grow Code on.

KUIAR_Runtime will always run custom grow code if you include 'changed' in this list, or when a region is added, removed, or re-ordered.]=] ] = [=[You can add a comma-separated list of state values here that (when changed) KUIAR_Runtime should also run the Grow Code on.

KUIAR_Runtime will always run custom grow code if you include 'changed' in this list, or when a region is added, removed, or re-ordered.]=]
	--[[Translation missing --]]
	L["You can add a comma-separated list of state values here that (when changed) KUIAR_Runtime should also run the sort code on.KUIAR_Runtime will always run custom sort code if you include 'changed' in this list, or when a region is added, removed."] = "You can add a comma-separated list of state values here that (when changed) KUIAR_Runtime should also run the sort code on.KUIAR_Runtime will always run custom sort code if you include 'changed' in this list, or when a region is added, removed."
	--[[Translation missing --]]
	L["Your Saved Snippets"] = "Your Saved Snippets"
	--[[Translation missing --]]
	L["Z Offset"] = "Z Offset"
	--[[Translation missing --]]
	L["Z Rotation"] = "Z Rotation"
	--[[Translation missing --]]
	L["Zoom In"] = "Zoom In"
	--[[Translation missing --]]
	L["Zoom Out"] = "Zoom Out"

-- KUI: translations added for strings upstream leaves in English (2026-11-12).
L["% - To show a percent sign"] = "% - Per mostrare il simbolo di percentuale"
L["%s - OnLoad"] = "%s - Al caricamento"
L["%s - OnUnload"] = "%s - Allo scaricamento"
L["%s Texture"] = "Texture %s"
L["%s Zoom: %d%%"] = "Zoom %s: %d%%"
L["|cFFFF0000default|r texture"] = "texture |cFFFF0000predefinita|r"
L["|cFFFF0000desaturated|r "] = "|cFFFF0000desaturato|r"
L["|cFFFF0000Note:|r The unit '%s' requires soft target cvars to be enabled."] = "|cFFFF0000Nota:|r l'unità '%s' richiede l'attivazione delle cvar del bersaglio morbido."
L["All maintainers of the libraries we use, especially:"] = "Tutti i manutentori delle librerie che usiamo, in particolare:"
L["Anchor Mode"] = "Modalità di ancoraggio"
L["And our Patreons, Discord Regulars and Subscribers, and Friends of the Addon:"] = "E i nostri Patreon, i frequentatori e gli iscritti di Discord, e gli amici dell'addon:"
L["Attach to Foreground"] = "Aggancia al primo piano"
L["By default this shows the information from the trigger selected via dynamic information. The information from a specific trigger can be shown via e.g. %2.p."] = "Per impostazione predefinita mostra le informazioni dell'attivazione selezionata tramite le informazioni dinamiche. Le informazioni di una specifica attivazione si possono mostrare con es. %2.p."
L["Case Insensitive"] = "Senza distinzione tra maiuscole e minuscole"
L["Changelog"] = "Registro delle modifiche"
L["Circular Texture %s"] = "Texture circolare %s"
L["Click to replace the name with %s."] = "Clic per sostituire il nome con %s."
L["Clipped by Foreground"] = "Ritagliato dal primo piano"
L["Could not parse '%s'. Expected a table."] = "Impossibile analizzare '%s'. Era attesa una tabella."
L["Custom - Allows you to define a custom Lua function that returns a list of string values. %c1 will be replaced by the first value returned, %c2 by the second, etc."] = "Personalizzato - Permette di definire una funzione Lua personalizzata che restituisce un elenco di stringhe. %c1 sarà sostituito dal primo valore restituito, %c2 dal secondo, ecc."
L["Custom Code"] = "Codice personalizzato"
L["Custom Code Viewer"] = "Visualizzatore del codice personalizzato"
L["Custom Frames"] = "Cornici personalizzate"
L["Custom Functions"] = "Funzioni personalizzate"
L["Custom Init"] = "Inizializzazione personalizzata"
L["Custom Load"] = "Caricamento personalizzato"
L["Custom Options"] = "Opzioni personalizzate"
L["Custom Text Update Throttle"] = "Limite di aggiornamento del testo personalizzato"
L["Custom Trigger"] = "Attivazione personalizzata"
L["Custom trigger event tooltip"] = "Scegli quali eventi causano il controllo dell'attivazione personalizzata. Si possono specificare più eventi separati da virgole o spazi.\n• Gli eventi \"UNIT\" possono usare i due punti per definire quali unitID registrare. Oltre agli UnitID si possono usare i tipi di unità, tra cui \"nameplate\", \"group\", \"raid\", \"party\", \"arena\", \"boss\".\n• \"CLEU\" può essere usato al posto di COMBAT_LOG_EVENT_UNFILTERED e i due punti possono separare i \"subEvents\" specifici che vuoi ricevere.\n• La parola chiave \"TRIGGER\" può essere usata, con i due punti a separare i numeri delle attivazioni, per aggiornare l'attivazione personalizzata quando si aggiornano le attivazioni indicate.\n\n|cFF4444FFPer esempio:|r\nUNIT_POWER_UPDATE:player, UNIT_AURA:nameplate:group PLAYER_TARGET_CHANGED CLEU:SPELL_CAST_SUCCESS TRIGGER:3:1\n"
L["Custom trigger status tooltip"] = "Scegli quali eventi causano il controllo dell'attivazione personalizzata. Si possono specificare più eventi separati da virgole o spazi.\n\n• Gli eventi \"UNIT\" possono usare i due punti per definire quali unitID registrare. Oltre agli UnitID si possono usare i tipi di unità, tra cui \"nameplate\", \"group\", \"raid\", \"party\", \"arena\", \"boss\".\n• \"CLEU\" può essere usato al posto di COMBAT_LOG_EVENT_UNFILTERED e i due punti possono separare i \"subEvents\" specifici che vuoi ricevere.\n• La parola chiave \"TRIGGER\" può essere usata, con i due punti a separare i numeri delle attivazioni, per aggiornare l'attivazione personalizzata quando si aggiornano le attivazioni indicate.\n\nPoiché questa è un'attivazione di tipo stato, gli eventi specificati possono essere chiamati da KUIAR_Runtime senza gli argomenti previsti.\n\n|cFF4444FFPer esempio:|r\nUNIT_POWER_UPDATE:player, UNIT_AURA:nameplate:group PLAYER_TARGET_CHANGED CLEU:SPELL_CAST_SUCCESS TRIGGER:3:1\n"
L["Custom trigger Update Throttle"] = "Limite di aggiornamento dell'attivazione personalizzata"
L["Custom Trigger: Ignore Lua Errors on OPTIONS event"] = "Attivazione personalizzata: ignora errori Lua all'evento OPTIONS"
L["Custom Trigger: Send fake events instead of STATUS event"] = "Attivazione personalizzata: invia eventi fittizi invece dell'evento STATUS"
L["Custom Unload"] = "Scaricamento personalizzato"
L["Custom Untrigger"] = "Disattivazione personalizzata"
L["Debug Log"] = "Registro di debug"
L["Debug Log:"] = "Registro di debug:"
L["Default"] = "Predefinito"
L["Default Color"] = "Colore predefinito"
L["Delay"] = "Ritardo"
L["Delete"] = "Elimina"
L["Delete all"] = "Elimina tutto"
L["Delete children and group"] = "Elimina figli e gruppo"
L["Delete Entry"] = "Elimina voce"
L["Deleting auras: "] = "Eliminazione delle aure: "
L["Description Text"] = "Testo della descrizione"
L["Determines how many entries can be in the table."] = "Determina quante voci può contenere la tabella."
L["Differences"] = "Differenze"
L["Disallow Entry Reordering"] = "Non consentire il riordino delle voci"
L["Display Name"] = "Nome del display"
L["Display Text"] = "Testo del display"
L["Displays a text, works best in combination with other displays"] = "Mostra un testo, funziona meglio in combinazione con altri display"
L["Distribute Horizontally"] = "Distribuisci orizzontalmente"
L["Distribute Vertically"] = "Distribuisci verticalmente"
L["Do not group this display"] = "Non raggruppare questo display"
L["Do you want to enable updates for this aura"] = "Vuoi abilitare gli aggiornamenti per questa aura"
L["Do you want to ignore updates for this aura"] = "Vuoi ignorare gli aggiornamenti per questa aura"
L["Documentation"] = "Documentazione"
L["Done"] = "Fatto"
L["Drag to move"] = "Trascina per spostare"
L["Duplicate"] = "Duplica"
L["Duplicate All"] = "Duplica tutto"
L["Duration (s)"] = "Durata (s)"
L["Duration Info"] = "Info sulla durata"
L["Dynamic Duration"] = "Durata dinamica"
L["Dynamic Group"] = "Gruppo dinamico"
L["Dynamic Group Settings"] = "Impostazioni del Gruppo dinamico"
L["Dynamic Information"] = "Informazioni dinamiche"
L["Dynamic information from first active trigger"] = "Informazioni dinamiche dalla prima attivazione attiva"
L["Dynamic information from Trigger %i"] = "Informazioni dinamiche dall'attivazione %i"
L["Dynamic Text Replacements"] = "Sostituzioni di testo dinamiche"
L["Ease Strength"] = "Intensità della gradualità"
L["Ease type"] = "Tipo di gradualità"
L["eliding"] = "elisione"
L["Else If"] = "Altrimenti Se"
L["Else If %s"] = "Altrimenti Se %s"
L["Empty Base Region"] = "Regione di base vuota"
L["Enable \"Edge\" part of the overlay"] = "Abilita la parte \"Bordo\" della sovrapposizione"
L["Enable \"swipe\" part of the overlay"] = "Abilita la parte \"spazzata\" della sovrapposizione"
L["Enable Debug Log"] = "Abilita registro di debug"
L["Enable Debug Logging"] = "Abilita registrazione di debug"
L["Enable Gradient"] = "Abilita gradiente"
L["Enable Swipe"] = "Abilita spazzata"
L["Enable the \"Swipe\" radial overlay"] = "Abilita la sovrapposizione radiale \"Spazzata\""
L["Enabled"] = "Attivato"
L["End Angle"] = "Angolo finale"
L["End of %s"] = "Fine di %s"
L["Enemy nameplate(s) found"] = "Targhetta/e nemica/che trovata/e"
L["Enter a Spell ID. You can use the addon idTip to determine spell ids."] = "Inserisci un ID incantesimo. Puoi usare l'addon idTip per ricavare gli ID incantesimo."
L["Enter an Aura Name, partial Aura Name, or Spell ID. A Spell ID will match any spells with the same name."] = "Inserisci il nome di un'aura, un nome parziale o un ID incantesimo. Un ID incantesimo corrisponde a tutti gli incantesimi con lo stesso nome."
L["Enter Author Mode"] = "Entra in modalità autore"
L["Enter in a value for the tick's placement."] = "Inserisci un valore per la posizione della tacca."
L["Enter static or relative values with %"] = "Inserisci valori fissi o relativi con %"
L["Enter User Mode"] = "Entra in modalità utente"
L["Enter user mode."] = "Entra in modalità utente."
L["Entry %i"] = "Voce %i"
L["Entry limit"] = "Limite di voci"
L["Entry Name Source"] = "Origine del nome della voce"
L["Everything"] = "Tutto"
L["Exact Item Match"] = "Corrispondenza esatta dell'oggetto"
L["Exact Spell Match"] = "Corrispondenza esatta dell'incantesimo"
L["Expand"] = "Espandi"
L["Expand all loaded displays"] = "Espandi tutti i display caricati"
L["Expand all non-loaded displays"] = "Espandi tutti i display non caricati"
L["Expand all pending Import"] = "Espandi tutte le importazioni in sospeso"
L["Expansion is disabled because this group has no children"] = "L'espansione è disattivata perché questo gruppo non ha figli"
L["Export debug table..."] = "Esporta tabella di debug..."
L["Export..."] = "Esporta..."
L["Exporting"] = "Esportazione"
L["External"] = "Esterno"
L["Extra Height"] = "Altezza extra"
L["Extra Width"] = "Larghezza aggiuntiva"
L["Fade"] = "Dissolvi"
L["Fadeout Sound"] = "Suono di dissolvenza in uscita"
L["Fadeout Time (seconds)"] = "Durata della dissolvenza in uscita (secondi)"
L["Fetch Affected/Unaffected Names and Units"] = "Recupera nomi e unità interessati/non interessati"
L["Fetch Raid Mark Information"] = "Recupera informazioni sul marchio raid"
L["Fetch Role Information"] = "Recupera informazioni sul ruolo"
L["Fetch Tooltip Information"] = "Recupera informazioni dal tooltip"
L["File Height"] = "Altezza del file"
L["File Width"] = "Larghezza del file"
L["Filter based on the spell Name string."] = "Filtra in base alla stringa del nome dell'incantesimo."
L["Filter by Arena Spec"] = "Filtra per specializzazione in arena"
L["Filter by Class"] = "Filtra per classe"
L["Filter by Group Role"] = "Filtra per ruolo nel gruppo"
L["Filter by Hostility"] = "Filtra per ostilità"
L["Filter by Npc ID"] = "Filtra per ID PNG"
L["Filter by Raid Role"] = "Filtra per ruolo nell'incursione"
L["Filter by Specialization"] = "Filtra per specializzazione"
L["Filter by Unit Name"] = "Filtra per nome dell'unità"
L["Filter formats: 'Name', 'Name-Realm', '-Realm'.\n\nSupports multiple entries, separated by commas\nCan use \\ to escape -."] = "Formati del filtro: 'Nome', 'Nome-Reame', '-Reame'.\n\nSupporta più voci, separate da virgole\nUsa \\ per l'escape di -."
L["Filter to only dispellable de/buffs of the given type(s)\nBleed classification via LibDispel"] = "Filtra solo benefici/malefici dissolvibili del/i tipo/i indicato/i\nClassificazione dei sanguinamenti tramite LibDispel"
L["Find Auras"] = "Trova aure"
L["Finish"] = "Termina"
L["Finishing..."] = "Completamento..."
L["Fire Orb"] = "Sfera di fuoco"
L["Flat Framelevels"] = "Livelli di cornice piatti"
L["Foreground Texture"] = "Texture del primo piano"
L["Format for %s"] = "Formato per %s"
L["Found a Bug?"] = "Hai trovato un bug?"
L["Frame"] = "Riquadro"
L["Frame Count"] = "Numero di frame"
L["Frame Height"] = "Altezza riquadro"
L["Frame Rate"] = "Frequenza fotogrammi"
L["Frame Strata"] = "Livello del riquadro"
L["Frame Width"] = "Larghezza del riquadro"
L["Full Bar"] = "Barra piena"
L["Full Circle"] = "Cerchio completo"
L["Global Conditions"] = "Condizioni globali"
L["Glow %s"] = "Bagliore %s"
L["Glow Action"] = "Azione del bagliore"
L["Glow Anchor"] = "Ancoraggio del bagliore"
L["Glow Color"] = "Colore bagliore"
L["Glow Frame Type"] = "Tipo di cornice del bagliore"
L["Glow Type"] = "Tipo di bagliore"
L["Green Rune"] = "Runa verde"
L["Grid direction"] = "Direzione della griglia"
L["Group (verb)"] = "Gruppo"
L["Group Alpha"] = "Opacità del gruppo"
L["Group and anchor each auras by frame.\n\n- Nameplates: attach to nameplates per unit.\n- Unit Frames: attach to unit frame buttons per unit.\n- Custom Frames: choose which frame each region should be anchored to."] = "Raggruppa e ancora ogni aura per cornice.\n\n- Targhette: aggancia alle targhette per unità.\n- Cornici unità: aggancia ai pulsanti delle cornici unità per unità.\n- Cornici personalizzate: scegli a quale cornice ancorare ogni regione."
L["Group aura count description"] = "Il numero di unità di tipo '%s' che devono essere interessate da una o più delle aure indicate affinché la visualizzazione si inneschi.\nSe il numero inserito è intero (ad es. 5), il numero di unità interessate verrà confrontato con il numero inserito.\nSe il numero inserito è decimale (ad es. 0.5), frazione (ad es. 1/2) o percentuale (ad es. 50%%), allora deve essere interessata quella frazione di %s.\n\n|cFF4444FFPer esempio:|r\n|cFF00CC00> 0|r si innescherà quando una qualsiasi unità di tipo '%s' è interessata\n|cFF00CC00= 100%%|r si innescherà quando ogni unità di tipo '%s' è interessata\n|cFF00CC00!= 2|r si innescherà quando il numero di unità di tipo '%s' interessate non è esattamente 2\n|cFF00CC00<= 0.8|r si innescherà quando meno dell'80%% delle unità di tipo '%s' è interessato (4 membri del gruppo su 5, 8 su 10 o 20 su 25 membri del raid)\n|cFF00CC00> 1/2|r si innescherà quando più della metà delle unità di tipo '%s' è interessata\n"
L["Group by Frame"] = "Raggruppa per cornice"
L["Group Description"] = "Descrizione del gruppo"
L["Group Icon"] = "Icona del gruppo"
L["Group key"] = "Chiave del gruppo"
L["Group Options"] = "Opzioni del gruppo"
L["Group player(s) found"] = "Giocatore/i del gruppo trovato/i"
L["Group Role"] = "Ruolo nel gruppo"
L["Group Scale"] = "Scala del gruppo"
L["Group Settings"] = "Impostazioni del gruppo"
L["Hawk"] = "Falco"
L["Help"] = "Aiuto"
L["Hide After"] = "Nascondi dopo"
L["Hide Background"] = "Nascondi sfondo"
L["Hide Glows applied by this aura"] = "Nascondi i Bagliori applicati da questa aura"
L["Hide on"] = "Nascondi quando"
L["Hide this group's children"] = "Nascondi i figli di questo gruppo"
L["Highlights"] = "Evidenziazioni"
L["Horizontal Align"] = "Allineamento orizzontale"
L["Horizontal Bar"] = "Barra orizzontale"
L["Huge Icon"] = "Icona enorme"
L["Hybrid Position"] = "Posizione ibrida"
L["Hybrid Sort Mode"] = "Modalità di ordinamento ibrida"
L["Icon - The icon associated with the display"] = "Icona - L'icona associata al display"
L["Icon Info"] = "Info sull'icona"
L["Icon Inset"] = "Rientro dell'icona"
L["Icon Picker"] = "Selettore di icone"
L["Icon Position"] = "Posizione dell'icona"
L["Icon Settings"] = "Impostazioni dell'icona"
L["Icon Source"] = "Origine dell'icona"
L["If"] = "Se"
L["If %s"] = "Se %s"
L["If checked, then the combo box in the User settings will be sorted."] = "Se selezionato, la casella combinata nelle impostazioni utente sarà ordinata."
L["If checked, then the user will see a multi line edit box. This is useful for inputting large amounts of text."] = "Se selezionato, l'utente vedrà una casella di modifica a più righe. Utile per inserire grandi quantità di testo."
L["If checked, then this group will not merge with other group when selecting multiple auras."] = "Se selezionato, questo gruppo non verrà unito ad altri gruppi quando si selezionano più aure."
L["If checked, then this option group can be temporarily collapsed by the user."] = "Se selezionato, questo gruppo di opzioni può essere temporaneamente compresso dall'utente."
L["If checked, then this option group will start collapsed."] = "Se selezionato, questo gruppo di opzioni inizierà compresso."
L["If checked, then this separator will include text. Otherwise, it will be just a horizontal line."] = "Se selezionato, questo separatore includerà del testo. Altrimenti sarà solo una linea orizzontale."
L["If checked, then this space will span across multiple lines."] = "Se selezionato, questo spazio si estenderà su più righe."
L["If unchecked, then a default color will be used (usually yellow)"] = "Se deselezionato, verrà usato un colore predefinito (di solito giallo)"
L["If unchecked, then this space will fill the entire line it is on in User Mode."] = "Se deselezionato, questo spazio riempirà l'intera riga in cui si trova in Modalità utente."
L["Ignore out of casting range"] = "Ignora fuori portata di lancio"
L["Ignore Wago updates"] = "Ignora aggiornamenti di Wago"
L["Ignored"] = "Ignorato"
L["Ignored Aura Name"] = "Nome aura ignorato"
L["Ignored Exact Spell ID(s)"] = "ID incantesimo esatto/i ignorato/i"
L["Ignored Name(s)"] = "Nome/i ignorato/i"
L["Ignored Spell ID"] = "ID incantesimo ignorato"
L["Import"] = "Importa"
L["Import / Export"] = "Importa / Esporta"
L["Import a display from an encoded string"] = "Importa un elemento da una stringa codificata"
L["Import as Copy"] = "Importa come copia"
L["Import has no UID, cannot be matched to existing auras."] = "L'importazione non ha UID, impossibile associarla alle aure esistenti."
L["Importing"] = "Importazione"
L["Importing %s"] = "Importazione di %s"
L["Importing a group with %s child auras."] = "Importazione di un gruppo con %s aure figlie."
L["Importing a stand-alone aura."] = "Importazione di un'aura singola."
L["Importing...."] = "Importazione...."
L["Incompatible changes to group region types detected"] = "Rilevate modifiche incompatibili ai tipi di regione del gruppo"
L["Incompatible changes to group structure detected"] = "Rilevate modifiche incompatibili alla struttura del gruppo"
L["Indent Size"] = "Dimensione del rientro"
L["Inner"] = "Interno"
L["Insert text replacement codes to make text dynamic."] = "Inserisci i codici di sostituzione del testo per rendere dinamico il testo."
L["Invalid Item ID"] = "ID oggetto non valido"
L["Invalid Item Name/ID/Link"] = "Nome/ID/Link oggetto non valido"
L["Invalid Spell ID"] = "ID incantesimo non valido"
L["Invalid Spell Name/ID/Link"] = "Nome/ID/Link incantesimo non valido"
L["Invalid target aura"] = "Aura bersaglio non valida"
L["Invalid type for '%s'. Expected 'bool', 'number', 'select', 'string', 'timer' or 'elapsedTimer'."] = "Tipo non valido per '%s'. Atteso 'bool', 'number', 'select', 'string', 'timer' o 'elapsedTimer'."
L["Invalid type for property '%s' in '%s'. Expected '%s'"] = "Tipo non valido per la proprietà '%s' in '%s'. Atteso '%s'"
L["Inverse Slant"] = "Inclinazione inversa"
L["Invert the direction of progress"] = "Inverti la direzione dell'avanzamento"
L["Is Boss Debuff"] = "È un malefico del boss"
L["Is Stealable"] = "È rubabile"
L["Is Unit"] = "È l'unità"
L["Justify"] = "Giustifica"
L["Keep Aspect Ratio"] = "Mantieni proporzioni"
L["Keep your Wago imports up to date with the Companion App."] = "Mantieni aggiornate le tue importazioni di Wago con la Companion App."
L["Large Input"] = "Input grande"
L["Leaf"] = "Foglia"
L["Left 2 HUD position"] = "Posizione HUD sinistra 2"
L["Left HUD position"] = "Posizione HUD sinistra"
L["Length of |cFFFF0000%s|r"] = "Lunghezza di |cFFFF0000%s|r"
L["Limit"] = "Limite"
L["Line"] = "Linea"
L["Linear Texture %s"] = "Texture lineare %s"
L["Linked aura: "] = "Aura collegata: "
L["Linked Auras"] = "Aure collegate"
L["Load"] = "Carica"
L["Loaded"] = "Caricato"
L["Loaded/Standby"] = "Caricato/In attesa"
L["Lock Positions"] = "Blocca le posizioni"
L["Low Mana"] = "Mana basso"
L["Magnetically Align"] = "Allineamento magnetico"
L["Main"] = "Principale"
L["Manual with %i/%i"] = "Manuale con %i/%i"
L["Matches %s spells"] = "Corrisponde a %s incantesimi"
L["Matches the height setting of a horizontal bar or width for a vertical bar."] = "Corrisponde all'impostazione dell'altezza di una barra orizzontale o della larghezza di una barra verticale."
L["Max Length"] = "Lunghezza massima"
L["Maximum"] = "Massimo"
L["Media Type"] = "Tipo di media"
L["Medium Icon"] = "Icona media"
L["Minimum"] = "Minimo"
L["Model %s"] = "Modello %s"
L["Model Picker"] = "Selettore di modelli"
L["Model Settings"] = "Impostazioni del modello"
L["ModelPaths could not be loaded, the addon is %s"] = "Impossibile caricare ModelPaths, l'addon è %s"
L["Move Above Group"] = "Sposta sopra il gruppo"
L["Move Below Group"] = "Sposta sotto il gruppo"
L["Move Down"] = "Sposta giù"
L["Move Entry Down"] = "Sposta voce giù"
L["Move Entry Up"] = "Sposta voce su"
L["Move Into Above Group"] = "Sposta dentro il gruppo sopra"
L["Move Into Below Group"] = "Sposta nel gruppo sottostante"
L["Move this display down in its group's order"] = "Sposta questa visualizzazione più in basso nell'ordine del gruppo"
L["Move this display up in its group's order"] = "Sposta questa visualizzazione più in alto nell'ordine del gruppo"
L["Move Up"] = "Su"
L["Moving auras: "] = "Aure in movimento:"
L["Multiple Displays"] = "Visualizzazioni multiple"
L["Multiselect ignored tooltip"] = "|cFFFF0000Ignorato|r - |cFF777777Singolo|r - |cFF777777Multiplo|r\nQuesta opzione non verrà usata per determinare quando caricare questa visualizzazione"
L["Multiselect multiple tooltip"] = "|cFF777777Ignorato|r - |cFF777777Singolo|r - |cFF00FF00Multiplo|r\nPuò essere scelto un numero qualsiasi di valori corrispondenti"
L["Multiselect single tooltip"] = "|cFF777777Ignorato|r - |cFF00FF00Singolo|r - |cFF777777Multiplo|r\nPuò essere scelto un solo valore corrispondente"
L["Must be a power of 2"] = "Deve essere una potenza di 2"
L["Name - The name of the display (usually an aura name), or the display's ID if there is no dynamic name"] = "Nome - Il nome della visualizzazione (di solito il nome di un'aura), o l'ID della visualizzazione se non c'è un nome dinamico"
L["Name Info"] = "Info nome"
L["Name Pattern Match"] = "Corrispondenza del modello del nome"
L["Name:"] = "Nome:"
L["Negator"] = "Non"
L["New Aura"] = "Nuova aura"
L["New Template"] = "Nuovo modello"
L["New Value"] = "Nuovo valore"
L["No Children"] = "Nessun figlio"
L["No Logs saved."] = "Nessun registro salvato."
L["Not a table"] = "Non è una tabella"
L["Not all children have the same value for this option"] = "Non tutti i figli hanno lo stesso valore per questa opzione"
L["Not Loaded"] = "Non caricato"
L["Note: Automated Messages to SAY and YELL are blocked outside of Instances."] = "Nota: i messaggi automatici in DIRE e URLARE sono bloccati fuori dalle istanze."
L["Note: This progress source does not provide a total value/duration. A total value/duration must be set via \"Set Maximum Progress\""] = "Nota: questa fonte di avanzamento non fornisce un valore/durata totale. Impostare un valore/durata totale tramite \"Imposta avanzamento massimo\""
L["Number of Entries"] = "Numero di voci"
L["Occurrence of the event, reset when aura is unloaded\nCan be a range of values\nCan have multiple values separated by a comma or a space\n\nExamples:\n2nd 5th and 6th events: 2, 5, 6\n2nd to 6th: 2-6\nevery 2 events: /2\nevery 3 events starting from 2nd: 2/3\nevery 3 events starting from 2nd and ending at 11th: 2-11/3"] = "Occorrenza dell'evento, azzerata quando l'aura viene scaricata\nPuò essere un intervallo di valori\nPuò avere più valori separati da una virgola o da uno spazio\n\nEsempi:\n2°, 5° e 6° evento: 2, 5, 6\ndal 2° al 6°: 2-6\nogni 2 eventi: /2\nogni 3 eventi a partire dal 2°: 2/3\nogni 3 eventi a partire dal 2° e fino all'11°: 2-11/3"
L["OFF"] = "DISATTIVO"
L["Offer a guided way to create auras for your character"] = "Offre un modo guidato per creare aure per il tuo personaggio"
L["Offset by |cFFFF0000%s|r/|cFFFF0000%s|r"] = "Sfasato di |cFFFF0000%s|r/|cFFFF0000%s|r"
L["Offset by 1px"] = "Sfasato di 1 px"
L["Okay"] = "Va bene"
L["ON"] = "ATTIVO"
L["On Hide"] = "Alla scomparsa"
L["On Show"] = "Alla comparsa"
L["Only Match auras cast by a player (not an npc)"] = "Corrisponde solo alle aure lanciate da un giocatore (non da un PNG)"
L["Only match auras cast by people other than the player or their pet"] = "Corrisponde solo alle aure lanciate da persone diverse dal giocatore o dal suo famiglio"
L["Only match auras cast by the player or their pet"] = "Corrisponde solo alle aure lanciate dal giocatore o dal suo famiglio"
L["Operator"] = "Operatore"
L["Option %i"] = "Opzione %i"
L["Option key"] = "Chiave opzione"
L["Option Type"] = "Tipo di opzione"
L["Options will open after combat ends."] = "Le opzioni si apriranno al termine del combattimento."
L["or"] = "o"
L["or %s"] = "o %s"
L["Orange Rune"] = "Runa arancione"
L["Our translators (too many to name)"] = "I nostri traduttori (troppi per citarli tutti)"
L["Outer"] = "Esterno"
L["Overflow"] = "Eccesso"
L["Overlay %s Info"] = "Info sovrapposizione %s"
L["Overlays"] = "Sovrapposizioni"
L["Own Only"] = "Solo propri"
L["Paste Action Settings"] = "Incolla impostazioni azione"
L["Paste Animations Settings"] = "Incolla impostazioni animazioni"
L["Paste Author Options Settings"] = "Incolla impostazioni opzioni autore"
L["Paste Condition Settings"] = "Incolla impostazioni condizione"
L["Paste Custom Configuration"] = "Incolla configurazione personalizzata"
L["Paste Display Settings"] = "Incolla impostazioni visualizzazione"
L["Paste Group Settings"] = "Incolla impostazioni gruppo"
L["Paste Load Settings"] = "Incolla impostazioni caricamento"
L["Paste Settings"] = "Incolla impostazioni"
L["Paste text below"] = "Incolla il testo qui sotto"
L["Paste Trigger Settings"] = "Incolla impostazioni innesco"
L["Places a tick on the bar"] = "Inserisce un segno sulla barra"
L["Play Sound"] = "Riproduci suono"
L["Player Spells found:"] = "Incantesimi del giocatore trovati:"
L["Portrait Zoom"] = "Zoom ritratto"
L["Position and Size Settings"] = "Impostazioni di posizione e dimensione"
L["Preferred Match"] = "Corrispondenza preferita"
L["Premade Auras"] = "Aure predefinite"
L["Premade Snippets"] = "Frammenti predefiniti"
L["Preparing auras: "] = "Preparazione aure:"
L["Press Ctrl+C to copy"] = "Premi Ctrl+C per copiare"
L["Press Ctrl+C to copy the URL"] = "Premi Ctrl+C per copiare l'URL"
L["Prevent Merging"] = "Impedisci unione"
L["Progress - The remaining time of a timer, or a non-timer value"] = "Avanzamento - Il tempo rimanente di un timer, o un valore non temporale"
L["Progress Bar"] = "Barra di avanzamento"
L["Progress Bar Settings"] = "Impostazioni barra di avanzamento"
L["Progress Settings"] = "Impostazioni avanzamento"
L["Progress Texture"] = "Texture di avanzamento"
L["Progress Texture Settings"] = "Impostazioni texture di avanzamento"
L["Purple Rune"] = "Runa viola"
L["Put this display in a group"] = "Metti questa visualizzazione in un gruppo"
L["Range in yards"] = "Distanza in metri"
L["Ready for Install"] = "Pronto per l'installazione"
L["Ready for Update"] = "Pronto per l'aggiornamento"
L["Re-center X"] = "Ricentra X"
L["Re-center Y"] = "Ricentra Y"
L["Reciprocal TRIGGER:# requests will be ignored!"] = "Le richieste TRIGGER:# reciproche verranno ignorate!"
L["Redo"] = "Ripeti"
L["Regions of type \"%s\" are not supported."] = "Le regioni di tipo \"%s\" non sono supportate."
L["Remove"] = "Rimuovi"
L["Remove All Sounds"] = "Rimuovi tutti i suoni"
L["Remove All Text To Speech"] = "Rimuovi tutto il testo in voce"
L["Remove this display from its group"] = "Rimuovi questa visualizzazione dal suo gruppo"
L["Remove this property"] = "Rimuovi questa proprietà"
L["Rename"] = "Rinomina"
L["Repeat After"] = "Ripeti dopo"
L["Repeat every"] = "Ripeti ogni"
L["Report bugs on our issue tracker."] = "Segnala i bug sul nostro tracker delle segnalazioni."
L["Require unit from trigger"] = "Richiedi unità dall'innesco"
L["Required for Activation"] = "Necessario per l'attivazione"
L["Requires LibSpecialization, that is e.g. a up-to date KUIAR_Runtime version"] = "Richiede LibSpecialization, cioè ad es. una versione aggiornata di KUIAR_Runtime"
L["Reset all options to their default values."] = "Reimposta tutte le opzioni ai valori predefiniti."
L["Reset Entry"] = "Reimposta voce"
L["Reset to Defaults"] = "Ripristina le impostazioni predefinite"
L["Right 2 HUD position"] = "Posizione HUD destra 2"
L["Right HUD position"] = "Posizione HUD destra"
L["Right-click for more options"] = "Clic destro per altre opzioni"
L["Rotate"] = "Ruota"
L["Rotate In"] = "Rotazione in entrata"
L["Rotate Out"] = "Rotazione in uscita"
L["Rotate Text"] = "Ruota testo"
L["Rotation Mode"] = "Modalità di rotazione"
L["Row Space"] = "Spazio tra le righe"
L["Row Width"] = "Larghezza riga"
L["Rows"] = "Righe"
L["Run on..."] = "Esegui su..."
L["Same"] = "Uguale"
L["Same texture as Foreground"] = "Stessa texture del primo piano"
L["Saved Data"] = "Dati salvati"
L["Scale Factor"] = "Fattore di scala"
L["Search API"] = "API di ricerca"
L["Select Talent"] = "Seleziona talento"
L["Select the auras you always want to be listed first"] = "Seleziona le aure che vuoi sempre in cima all'elenco"
L["Selected Frame"] = "Riquadro selezionato"
L["Send To"] = "Invia a"
L["Separator Text"] = "Testo separatore"
L["Separator text"] = "Testo separatore"
L["Set Maximum Progress"] = "Imposta avanzamento massimo"
L["Set Minimum Progress"] = "Imposta avanzamento minimo"
L["Set Parent to Anchor"] = "Imposta genitore sull'ancora"
L["Set Thumbnail Icon"] = "Imposta icona miniatura"
L["Sets the anchored frame as the aura's parent, causing the aura to inherit attributes such as visibility and scale."] = "Imposta il riquadro ancorato come genitore dell'aura, facendole ereditare attributi come visibilità e scala."
L["Settings"] = "Impostazioni"
L["Shadow Color"] = "Colore ombra"
L["Shadow X Offset"] = "Scostamento X ombra"
L["Shadow Y Offset"] = "Scostamento Y ombra"
L["Shift-click to create chat link"] = "Maiusc+clic per creare un |cFF8800FF[collegamento in chat]"
L["Show \"Edge\""] = "Mostra \"Bordo\""
L["Show \"Swipe\""] = "Mostra \"Sweep\""
L["Show and Clone Settings"] = "Impostazioni di visualizzazione e cloni"
L["Show Border"] = "Mostra bordo"
L["Show Circular Texture"] = "Mostra texture circolare"
L["Show Debug Logs"] = "Mostra registri di debug"
L["Show Glow"] = "Mostra bagliore"
L["Show Icon"] = "Mostra icona"
L["Show If Unit Does Not Exist"] = "Mostra se l'unità non esiste"
L["Show Linear Texture"] = "Mostra texture lineare"
L["Show Matches for"] = "Mostra corrispondenze per"
L["Show Matches for Units"] = "Mostra corrispondenze per unità"
L["Show Model"] = "Mostra modello"
L["Show model of unit "] = "Mostra modello dell'unità"
L["Show Sound Setting"] = "Mostra impostazione suono"
L["Show Spark"] = "Mostra scintilla"
L["Show Stop Motion"] = "Mostra stop motion"
L["Show Text"] = "Mostra testo"
L["Show Text To Speech Setting"] = "Mostra impostazione sintesi vocale"
L["Show Texture"] = "Mostra texture"
L["Show this group's children"] = "Mostra i figli di questo gruppo"
L["Show Tick"] = "Mostra tacca"
L["Shows a 3D model from the game files"] = "Mostra un modello 3D dai file di gioco"
L["Shows a border"] = "Mostra un bordo"
L["Shows a Circular Progress Texture"] = "Mostra una texture di avanzamento circolare"
L["Shows a custom texture"] = "Mostra una texture personalizzata"
L["Shows a glow"] = "Mostra un bagliore"
L["Shows a Linear Progress Texture"] = "Mostra una texture di avanzamento lineare"
L["Shows a model"] = "Mostra un modello"
L["Shows a progress bar with name, timer, and icon"] = "Mostra una barra di avanzamento con nome, timer e icona"
L["Shows a spell icon with an optional cooldown overlay"] = "Mostra un'icona di incantesimo con una sovrapposizione opzionale del tempo di recupero"
L["Shows a Stop Motion"] = "Mostra uno stop motion"
L["Shows a stop motion texture"] = "Mostra una texture stop motion"
L["Shows a Texture"] = "Mostra una texture"
L["Shows a texture that changes based on duration"] = "Mostra una texture che cambia in base alla durata"
L["Shows nothing, except sub elements"] = "Non mostra nulla, tranne i sotto-elementi"
L["Shows one or more lines of text, which can include dynamic information such as progress or stacks"] = "Mostra una o più righe di testo, che possono includere informazioni dinamiche come avanzamento o cariche"
L["Size"] = "Dimensioni"
L["Slant Amount"] = "Entità inclinazione"
L["Slant Mode"] = "Modalità inclinazione"
L["Slanted"] = "Inclinato"
L["Slide"] = "Scorrimento"
L["Slide In"] = "Scorrimento in entrata"
L["Slide Out"] = "Scorrimento in uscita"
L["Slider Step Size"] = "Passo del cursore"
L["Small Icon"] = "Icona piccola"
L["Smooth Progress"] = "Avanzamento fluido"
L["Snippets"] = "Frammenti"
L["Soft Max"] = "Massimo morbido"
L["Soft Min"] = "Minimo morbido"
L["Sort"] = "Ordinamento"
L["Sound Channel"] = "Canale audio"
L["Sound File Path"] = "Percorso del file audio"
L["Sound Kit ID"] = "ID Sound Kit"
L["Space Horizontally"] = "Spaziatura orizzontale"
L["Space Vertically"] = "Spaziatura verticale"
L["Spark Settings"] = "Impostazioni scintilla"
L["Spark Texture"] = "Texture scintilla"
L["Specific Currency ID"] = "ID valuta specifica"
L["Spell Selection Filters"] = "Filtri di selezione incantesimi"
L["Spells found:"] = "Incantesimi trovati:"
L["Stack Info"] = "Info cariche"
L["Stacks - The number of stacks of an aura (usually)"] = "Cariche - Il numero di cariche di un'aura (di solito)"
L["Standby"] = "In attesa"
L["Star"] = "Stella"
L["Start"] = "Inizio"
L["Start Angle"] = "Angolo iniziale"
L["Start Collapsed"] = "Inizia compresso"
L["Start of %s"] = "Inizio di %s"
L["Step Size"] = "Dimensione del passo"
L["Stop Motion %s"] = "Stop motion %s"
L["Stop Motion Settings"] = "Impostazioni stop motion"
L["Stop Sound"] = "Interrompi suono"
L["Stretched by Foreground"] = "Allungato dal primo piano"
L["Sub Elements"] = "Sotto-elementi"
L["Sub Option %i"] = "Sotto-opzione %i"
L["Subevent"] = "Sottoevento"
L["Subevent Suffix"] = "Suffisso sottoevento"
L["Swipe Overlay Settings"] = "Impostazioni sovrapposizione sweep"
L["Templates could not be loaded, the addon is %s"] = "Impossibile caricare i modelli, l'addon è %s"
L["Temporary Group"] = "Gruppo temporaneo"
L["Text %s"] = "Testo %s"
L["Text Color"] = "Colore del testo"
L["Text Settings"] = "Impostazioni del testo"
L["Texture Info"] = "Info texture"
L["Texture Selection Mode"] = "Modalità di selezione texture"
L["Texture Settings"] = "Impostazioni texture"
L["Texture Wrap"] = "Avvolgimento texture"
L["Texture X Offset"] = "Scostamento X texture"
L["Texture Y Offset"] = "Scostamento Y texture"
L["Thanks"] = "Grazie"
L["The addon ElvUI is enabled. It might add cooldown numbers to the swipe. You can configure these in the ElvUI settings"] = "L'addon ElvUI è attivo. Potrebbe aggiungere numeri di recupero allo sweep. Puoi configurarli nelle impostazioni di ElvUI"
L["The addon OmniCC is enabled. It might add cooldown numbers to the swipe. You can configure these in the OmniCC settings"] = "L'addon OmniCC è attivo. Potrebbe aggiungere numeri di recupero allo sweep. Puoi configurarli nelle impostazioni di OmniCC"
L["The duration of the animation in seconds."] = "La durata dell'animazione in secondi."
L["The duration of the animation in seconds. The finish animation does not start playing until after the display would normally be hidden."] = "La durata dell'animazione in secondi. L'animazione finale inizia solo dopo il momento in cui la visualizzazione verrebbe normalmente nascosta."
L["The group and all direct children will share the same base frame level."] = "Il gruppo e tutti i figli diretti condivideranno lo stesso livello di riquadro di base."
L["The Multi Target mode is less reliable and not recommended."] = "La modalità Bersagli multipli è meno affidabile e non è consigliata."
L["The Multi Target mode requires a name or spell id filter"] = "La modalità Bersagli multipli richiede un filtro per nome o ID incantesimo"
L["The trigger number is optional. When no trigger number is specified, the trigger selected via dynamic information will be used."] = "Il numero dell'innesco è facoltativo. Se non viene indicato, verrà usato l'innesco selezionato tramite le informazioni dinamiche."
L["The type of trigger"] = "Il tipo di innesco"
L["The KUIAR_Runtime Options Addon version %s doesn't match the KUIAR_Runtime version %s. If you updated the addon while the game was running, try restarting World of Warcraft. Otherwise try reinstalling KUIAR_Runtime"] = "La versione %s dell'addon Opzioni di KUIAR_Runtime non corrisponde alla versione %s di KUIAR_Runtime. Se hai aggiornato l'addon mentre il gioco era in esecuzione, prova a riavviare World of Warcraft. Altrimenti prova a reinstallare KUIAR_Runtime"
L["Then "] = "Poi"
L["There are several special codes available to make this text dynamic. Click to view a list with all dynamic text codes."] = "Sono disponibili diversi codici speciali per rendere dinamico questo testo. Clicca per vedere l'elenco di tutti i codici di testo dinamico."
L["This adds %raidMark as text replacements."] = "Aggiunge %raidMark come testo sostitutivo."
L["This adds %role, %roleIcon as text replacements. Does nothing if the unit is not a group member."] = "Aggiunge %role, %roleIcon come testi sostitutivi. Non fa nulla se l'unità non è un membro del gruppo."
L["This adds %tooltip, %tooltip1, %tooltip2, %tooltip3 and %tooltip4 as text replacements and also allows filtering based on the tooltip content/values."] = "Aggiunge %tooltip, %tooltip1, %tooltip2, %tooltip3 e %tooltip4 come testi sostitutivi e consente anche di filtrare in base al contenuto/ai valori della descrizione."
L["This aura contains custom Lua code.\nMake sure you can trust the person who sent it!"] = "Questa aura contiene codice Lua personalizzato.\nAssicurati di poterti fidare di chi l'ha inviata!"
L["This aura is marked as an update to an aura '%s', but cannot be used to update that aura. This usually happens if an aura is moved out of a group."] = "Questa aura è contrassegnata come aggiornamento di un'aura '%s', ma non può essere usata per aggiornarla. Di solito succede se un'aura viene spostata fuori da un gruppo."
L["This aura is marked as an update to auras '%s', but cannot be used to update them. This usually happens if an aura is moved out of a group."] = "Questa aura è contrassegnata come aggiornamento delle aure '%s', ma non può essere usata per aggiornarle. Di solito succede se un'aura viene spostata fuori da un gruppo."
L["This aura was created with a different version (%s) of World of Warcraft.\nIt might not work correctly!"] = "Questa aura è stata creata con una versione diversa (%s) di World of Warcraft.\nPotrebbe non funzionare correttamente!"
L["This aura was created with a newer version of KUIAR_Runtime.\nUpgrade your version of KUIAR_Runtime or wait for next release before installing this aura."] = "Questa aura è stata creata con una versione più recente di KUIAR_Runtime.\nAggiorna KUIAR_Runtime o attendi il prossimo rilascio prima di installare questa aura."
L["This display is currently loaded"] = "Questa visualizzazione è attualmente caricata"
L["This display is not currently loaded"] = "Questa visualizzazione non è attualmente caricata"
L["This display is on standby, it will be loaded when needed."] = "Questa visualizzazione è in attesa, verrà caricata quando necessario."
L["This enables the collection of debug logs. Custom code can add debug information to the log through the function DebugPrint."] = "Attiva la raccolta dei registri di debug. Il codice personalizzato può aggiungere informazioni di debug al registro tramite la funzione DebugPrint."
L["This is a modified version of your aura, |cff9900FF%s.|r"] = "Questa è una versione modificata della tua aura, |cff9900FF%s.|r"
L["This is a modified version of your group: |cff9900FF%s|r"] = "Questa è una versione modificata del tuo gruppo: |cff9900FF%s|r"
L["This region of type \"%s\" is not supported."] = "Questa regione di tipo \"%s\" non è supportata."
L["This setting controls what widget is generated in user mode."] = "Questa impostazione controlla quale widget viene generato in modalità utente."
L["Thumbnail Icon"] = "Icona miniatura"
L["Tick %s"] = "Tacca %s"
L["Tick Area %s"] = "Area tacca %s"
L["Tick Center %s"] = "Centro tacca %s"
L["Tick Mode"] = "Modalità tacca"
L["Tick Placement"] = "Posizionamento tacca"
L["Time in"] = "Tempo in"
L["Tiny Icon"] = "Icona minuscola"
L["To Frame's"] = "Al riquadro di"
L["To Group's"] = "Al gruppo di"
L["To Personal Ressource Display's"] = "Alla visualizzazione risorsa personale di"
L["To Region's"] = "Alla regione di"
L["To Screen's"] = "Allo schermo di"
L["Toggle the visibility of all loaded displays"] = "Mostra/nascondi tutte le visualizzazioni caricate"
L["Toggle the visibility of all non-loaded displays"] = "Mostra/nascondi tutte le visualizzazioni non caricate"
L["Toggle the visibility of this display"] = "Mostra/nascondi questa visualizzazione"
L["Tooltip Content"] = "Contenuto della descrizione"
L["Tooltip on Mouseover"] = "Descrizione al passaggio del mouse"
L["Tooltip Pattern Match"] = "Corrispondenza del modello della descrizione"
L["Tooltip Text"] = "Testo del tooltip"
L["Tooltip Value"] = "Valore della descrizione"
L["Tooltip Value #"] = "Valore della descrizione n."
L["Top HUD position"] = "Posizione HUD in alto"
L["Total"] = "Totale"
L["Total - The maximum duration of a timer, or a maximum non-timer value"] = "Totale - La durata massima di un timer, o un valore massimo non temporale"
L["Total Angle"] = "Angolo totale"
L["Total Time"] = "Tempo totale"
L["Trigger %i: %s"] = "Innesco %i: %s"
L["Trigger Combination"] = "Combinazione di inneschi"
L["Type 'select' for '%s' requires a values member'"] = "Il tipo 'select' per '%s' richiede un membro values'"
L["Undo"] = "Annulla"
L["Ungroup"] = "Separa dal gruppo"
L["Unit %s is not a valid unit for RegisterUnitEvent"] = "L'unità %s non è un'unità valida per RegisterUnitEvent"
L["Unit Count"] = "Numero di unità"
L["Unknown"] = "Sconosciuto"
L["Unknown Encounter's Spell Id"] = "ID incantesimo dell'incontro sconosciuto"
L["Unknown property '%s' found in '%s'"] = "Proprietà sconosciuta '%s' trovata in '%s'"
L["Unknown Spell"] = "Incantesimo sconosciuto"
L["Unlike the start or finish animations, the main animation will loop over and over until the display is hidden."] = "A differenza delle animazioni iniziale e finale, l'animazione principale si ripete in continuazione finché la visualizzazione non viene nascosta."
L["Update"] = "Aggiorna"
L["Update Auras"] = "Aggiorna aure"
L["Update Custom Text On..."] = "Aggiorna testo personalizzato su..."
L["Use Display Info Id"] = "Usa ID info visualizzazione"
L["Use SetTransform"] = "Usa SetTransform"
L["Used in Auras:"] = "Usato nelle aure:"
L["Used in auras:"] = "Usato nelle aure:"
L["Uses Texture Coordinates to rotate the texture."] = "Usa le coordinate della texture per ruotarla."
L["Value"] = "Valore"
L["Value %i"] = "Valore %i"
L["Values are in normalized rgba format."] = "I valori sono in formato rgba normalizzato."
L["Values/Remaining Time above this value are displayed as full progress."] = "I valori/Tempo rimanente superiori a questo valore vengono mostrati come avanzamento completo."
L["Values/Remaining Time below this value are displayed as zero progress."] = "I valori/Tempo rimanente inferiori a questo valore vengono mostrati come avanzamento zero."
L["Values:"] = "Valori:"
L["Version: "] = "Versione:"
L["Version: %s"] = "Versione: %s"
L["Vertical Align"] = "Allineamento verticale"
L["Vertical Bar"] = "Barra verticale"
L["View"] = "Vista"
L["View custom code"] = "Visualizza codice personalizzato"
L["Voice Settings"] = "Impostazioni voce"
L["We thank"] = "Ringraziamo"
L["KUIAR_Engine %s on WoW %s"] = "KUIAR_Engine %s su WoW %s"
L["KUIAR_Engine recommends using spell ids instead of names. Spell ids are automatically localized."] = "KUIAR_Engine consiglia di usare gli ID incantesimo invece dei nomi. Gli ID incantesimo sono localizzati automaticamente."
L["What do you want to do?"] = "Cosa vuoi fare?"
L["Whole Area"] = "Intera area"
L["wrapping"] = "a capo"
L["X Offset"] = "Scostamento X"
L["X Rotation"] = "Rotazione X"
L["X Scale"] = "Scala X"
L["x-Offset"] = "Scostamento x"
L["Y Offset"] = "Scostamento Y"
L["Y Rotation"] = "Rotazione Y"
L["Y Scale"] = "Scala Y"
L["Yellow Rune"] = "Runa gialla"
L["y-Offset"] = "Scostamento y"
L["You already have this group/aura. Importing will create a duplicate."] = "Hai già questo gruppo/aura. L'importazione creerà un duplicato."
L["You are about to delete %d aura(s). |cFFFF0000This cannot be undone!|r Would you like to continue?"] = "Stai per eliminare %d aure. |cFFFF0000Non si può annullare!|r Vuoi continuare?"
L["You are about to delete a trigger. |cFFFF0000This cannot be undone!|r Would you like to continue?"] = "Stai per eliminare un innesco. |cFFFF0000Non si può annullare!|r Vuoi continuare?"
L["You are about to Import an Aura with custom Lua code on a Hardcore server.\n\n|cFFFF0000There is a risk the custom code could be used to kill your hardcore character!|r\n\nWould you like to continue?"] = "Stai per importare un'aura con codice Lua personalizzato su un server Hardcore.\n\n|cFFFF0000C'è il rischio che il codice personalizzato venga usato per uccidere il tuo personaggio hardcore!|r\n\nVuoi continuare?"
L["You can add a comma-separated list of state values here that (when changed) KUIAR_Runtime should also run the Anchor Code on.\n\nKUIAR_Runtime will always run custom anchor code if you include 'changed' in this list, or when a region is added, removed, or re-ordered."] = "Puoi aggiungere qui un elenco, separato da virgole, di valori di stato per cui (quando cambiano) KUIAR_Runtime deve eseguire anche il codice di ancoraggio.\n\nKUIAR_Runtime eseguirà sempre il codice di ancoraggio personalizzato se includi 'changed' in questo elenco, o quando una regione viene aggiunta, rimossa o riordinata."
L["You can add a comma-separated list of state values here that (when changed) KUIAR_Runtime should also run the Grow Code on.\n\nKUIAR_Runtime will always run custom grow code if you include 'changed' in this list, or when a region is added, removed, or re-ordered."] = "Puoi aggiungere qui un elenco, separato da virgole, di valori di stato per cui (quando cambiano) KUIAR_Runtime deve eseguire anche il codice di crescita.\n\nKUIAR_Runtime eseguirà sempre il codice di crescita personalizzato se includi 'changed' in questo elenco, o quando una regione viene aggiunta, rimossa o riordinata."
L["You can add a comma-separated list of state values here that (when changed) KUIAR_Runtime should also run the sort code on.KUIAR_Runtime will always run custom sort code if you include 'changed' in this list, or when a region is added, removed."] = "Puoi aggiungere qui un elenco, separato da virgole, di valori di stato per cui (quando cambiano) KUIAR_Runtime deve eseguire anche il codice di ordinamento. KUIAR_Runtime eseguirà sempre il codice di ordinamento personalizzato se includi 'changed' in questo elenco, o quando una regione viene aggiunta o rimossa."
L["Your Saved Snippets"] = "I tuoi frammenti salvati"
L["Z Offset"] = "Scostamento Z"
L["Z Rotation"] = "Rotazione Z"
L["Zoom In"] = "Ingrandimento"
L["Zoom Out"] = "Zoom indietro"
L["About KUIAR_Runtime"] = "Informazioni su KUIAR_Runtime"
L["Read about KUIAR_Runtime development, supported features, and current limitations."] = "Leggi dello sviluppo di KUIAR_Runtime, delle funzioni supportate e dei limiti attuali."
L["This aura was saved with a newer engine version. It can be imported; any setting added in that version is kept but has no effect here."] = "Quest’aura è stata salvata con una versione più recente del motore. Può essere importata; le impostazioni aggiunte in quella versione vengono mantenute ma qui non hanno effetto."

end)
