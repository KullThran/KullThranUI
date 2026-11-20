-- Embedded adaptation of M33kAuras 5.20.7-rg4-m101; GPL-2.0. See Engine/UPSTREAM.md.
local _, host = ...
host.EmbeddedAuraEngine.Register("KUIAR_EngineOptions", function(...)
if not KUIAR_Runtime.IsLibsOK() then return end

if (GAME_LOCALE or GetLocale()) ~= "deDE" then
  return
end

local L = KUIAR_Runtime.L

-- M33kAuras/Options
	L[" and |cFFFF0000mirrored|r"] = "und |cFFFF0000gespiegelt|r"
	--[[Translation missing --]]
	L["-- Do not remove this comment, it is part of this aura: "] = "-- Do not remove this comment, it is part of this aura: "
	L[" rotated |cFFFF0000%s|r degrees"] = "rotiert um |cFFFF0000%s|r grad"
	L["% - To show a percent sign"] = "% - Um ein Prozent Symbol zu erzeugen."
	L["% of Progress"] = "Fortschritt in %"
	L["%d |4aura:auras; added"] = "%d |4aura:auras; hinzugefügt"
	L["%d |4aura:auras; deleted"] = "%d |4aura:auras; gelöscht"
	L["%d |4aura:auras; modified"] = "%d |4aura:auras; geändert"
	L["%d |4aura:auras; with meta data modified"] = "%d |4aura:auras; in denen meta daten modifiziert wurden"
	L["%d displays loaded"] = "%d Auren geladen"
	L["%d displays not loaded"] = "%d Auren nicht geladen"
	L["%d displays on standby"] = "%d Auren auf standby"
	L["%i auras selected"] = "%i Auren ausgew\\195\\164hlt"
	L["%i."] = "%i."
	L["%i. %s"] = "%i. %s"
	L["%s - %i. Trigger"] = "%s - %i. Trigger"
	L["%s - Alpha Animation"] = "%s - Alpha-Animation"
	L["%s - Color Animation"] = "%s - Farb-Animation"
	L["%s - Condition Custom Chat %s"] = "%s - Bedingung benutzerdefiniert Chat %s"
	L["%s - Condition Custom Check %s"] = "%s - Bedingung Benutzerdefinierter Check %s"
	L["%s - Condition Custom Code %s"] = "%s - Bedingung benutzerdefinierter Code %s"
	L["%s - Custom Anchor"] = "%s - Benutzerdefinierter Anker"
	L["%s - Custom Grow"] = "%s - Benutzerdefiniertes Wachstum"
	L["%s - Custom Sort"] = "%s - Benutzerdefinierte Sortierung"
	L["%s - Custom Text"] = "%s - Benutzerdefinierter Text"
	L["%s - Finish"] = "%s - Ende"
	L["%s - Finish Action"] = "%s - Endaktion"
	L["%s - Finish Custom Text"] = "%s - Benutzerdefinierter Endtext"
	L["%s - Init Action"] = "%s - Initialisierung"
	L["%s - Main"] = "%s - Haupt"
	--[[Translation missing --]]
	L["%s - OnLoad"] = "%s - OnLoad"
	--[[Translation missing --]]
	L["%s - OnUnload"] = "%s - OnUnload"
	L["%s - Option #%i has the key %s. Please choose a different option key."] = "Die %s - Option #%i hat bereits den Schlüssel %s. Bitte wähle einen anderen Optionsschlüssel."
	L["%s - Rotate Animation"] = "%s - Rotierungsanimation"
	L["%s - Scale Animation"] = "%s - Skalierungsanimation"
	L["%s - Start"] = "%s - Start"
	L["%s - Start Action"] = "%s - Startaktion"
	L["%s - Start Custom Text"] = "%s - Benutzerdefiniertet Starttext"
	L["%s - Translate Animation"] = "%s - Übersetzungsanimation"
	L["%s - Trigger Logic"] = "%s - Triggerlogik"
	L["%s %s, Lines: %d, Frequency: %0.2f, Length: %d, Thickness: %d"] = "%s %s, Linien: %d, Frequenz: %0.2f, Länge: %d, Breite: %d"
	L["%s %s, Particles: %d, Frequency: %0.2f, Scale: %0.2f"] = "%s %s, Partikel: %d, Frequenz: %0.2f, Skalierung: %0.2f"
	L["%s %u. Overlay Function"] = "%s %u. Overlay Funkion"
	L["%s (%s)"] = "%s (%s)"
	L["%s Alpha: %d%%"] = "%s Alpha: %d%%"
	L["%s Color"] = "%s Farbe"
	L["%s Custom Variables"] = "%s benutzerdefinierte Variablen"
	L["%s Default Alpha, Zoom, Icon Inset, Aspect Ratio"] = "%s Standard Alpha, Zoom, Bild, Einsatz, Aspekt Ratio"
	L["%s Duration Function"] = "%s Dauerfunktion"
	L["%s Icon Function"] = "%s Bildfunktion"
	L["%s Inset: %d%%"] = "%s Einsatz: %d%%"
	L["%s is not a valid SubEvent for COMBAT_LOG_EVENT_UNFILTERED"] = "%s ist kein valides SubEvent für COMBAT_LOG_EVENT_UNFILTERED"
	L["%s Keep Aspect Ratio"] = "%s Behalte Aspekt Ratio"
	L["%s Name Function"] = "%s Namensfunktion"
	L["%s Stacks Function"] = "%s Stapelfunkion"
	L["%s stores around %s KB of data"] = "%s speichert um die %s KB an Daten"
	L["%s Texture"] = "%s Textur"
	L["%s Texture Function"] = "%s Texturfunktion"
	L["%s total auras"] = "%s gesamte Auren"
	L["%s Trigger Function"] = "%s Auslösefunktion"
	L["%s Untrigger Function"] = "%s Umkehrauslöserfunkion"
	L["%s X offset by %d"] = "%s X versatz um %d"
	L["%s Y offset by %d"] = "%s Y versatz um %d"
	L["%s Zoom: %d%%"] = "%s Zoom: %d%%"
	L["%s, Border"] = "%s, Rahmen"
	L["%s, Offset: %0.2f;%0.2f"] = "%s, Versatz: %0.2f;%0.2f"
	L["%s, offset: %0.2f;%0.2f"] = "%s, Versatz: %0.2f;%0.2f"
	L["%s, Start Animation"] = "%s, Startanimation"
	L["%s|cFFFF0000custom|r texture with |cFFFF0000%s|r blend mode%s%s"] = "%s|cFFFF0000benutzerdefiniert|r Texture mit |cFFFF0000%s|r Mischmodus%s%s"
	L["(Right click to rename)"] = "(Rechtsklick zum Umbenennen)"
	L["|c%02x%02x%02x%02xCustom Color|r"] = "|c%02x%02x%02x%02xbenutzerdefiniert Farbe|r"
	L["|cff999999Triggers tracking multiple units will default to being active even while no affected units are found without a Unit Count or Match Count setting applied.|r"] = "|cff999999Trigger die multiplen Einheiten verfolgen sind standardmäßig aktiv, selbst wenn keine Einheiten gefunden werden, falls sie keinen UnitCount oder MatchCount Einstellung enthalten.|r"
	L["|cFFE0E000Note:|r This sets the description only on '%s'"] = "|cFFE0E000Notiz|r Dies setzt die Beschreibung nur für '%s'"
	L["|cFFE0E000Note:|r This sets the URL on all selected auras"] = "|cFFE0E000Notiz|r Dies setzt die URL für alle ausgewählten Auren"
	L["|cFFE0E000Note:|r This sets the URL on this group and all its members."] = "|cFFE0E000Notiz:|r Dies setzt die URL für die Gruppe und alle Kinder"
	--[[Translation missing --]]
	L["|cFFFF0000Automatic|r length"] = "|cFFFF0000Automatic|r length"
	--[[Translation missing --]]
	L["|cFFFF0000default|r texture"] = "|cFFFF0000default|r texture"
	--[[Translation missing --]]
	L["|cFFFF0000desaturated|r "] = "|cFFFF0000desaturated|r "
	--[[Translation missing --]]
	L["|cFFFF0000Note:|r The unit '%s' is not a trackable unit."] = "|cFFFF0000Note:|r The unit '%s' is not a trackable unit."
	--[[Translation missing --]]
	L["|cFFFF0000Note:|r The unit '%s' requires soft target cvars to be enabled."] = "|cFFFF0000Note:|r The unit '%s' requires soft target cvars to be enabled."
	--[[Translation missing --]]
	L["|cFFffcc00Anchors:|r Anchored |cFFFF0000%s|r to frame's |cFFFF0000%s|r"] = "|cFFffcc00Anchors:|r Anchored |cFFFF0000%s|r to frame's |cFFFF0000%s|r"
	--[[Translation missing --]]
	L["|cFFffcc00Anchors:|r Anchored |cFFFF0000%s|r to frame's |cFFFF0000%s|r with offset |cFFFF0000%s/%s|r"] = "|cFFffcc00Anchors:|r Anchored |cFFFF0000%s|r to frame's |cFFFF0000%s|r with offset |cFFFF0000%s/%s|r"
	--[[Translation missing --]]
	L["|cFFffcc00Anchors:|r Anchored to frame's |cFFFF0000%s|r"] = "|cFFffcc00Anchors:|r Anchored to frame's |cFFFF0000%s|r"
	--[[Translation missing --]]
	L["|cFFffcc00Anchors:|r Anchored to frame's |cFFFF0000%s|r with offset |cFFFF0000%s/%s|r"] = "|cFFffcc00Anchors:|r Anchored to frame's |cFFFF0000%s|r with offset |cFFFF0000%s/%s|r"
	--[[Translation missing --]]
	L["|cFFffcc00Extra Options:|r"] = "|cFFffcc00Extra Options:|r"
	--[[Translation missing --]]
	L["|cFFffcc00Extra:|r %s and %s %s"] = "|cFFffcc00Extra:|r %s and %s %s"
	--[[Translation missing --]]
	L["|cFFffcc00Font Flags:|r |cFFFF0000%s|r and shadow |c%sColor|r with offset |cFFFF0000%s/%s|r%s%s"] = "|cFFffcc00Font Flags:|r |cFFFF0000%s|r and shadow |c%sColor|r with offset |cFFFF0000%s/%s|r%s%s"
	--[[Translation missing --]]
	L["|cFFffcc00Font Flags:|r |cFFFF0000%s|r and shadow |c%sColor|r with offset |cFFFF0000%s/%s|r%s%s%s"] = "|cFFffcc00Font Flags:|r |cFFFF0000%s|r and shadow |c%sColor|r with offset |cFFFF0000%s/%s|r%s%s%s"
	--[[Translation missing --]]
	L["|cffffcc00Format Options|r"] = "|cffffcc00Format Options|r"
	--[[Translation missing --]]
	L[ [=[• |cff00ff00Player|r, |cff00ff00Target|r, |cff00ff00Focus|r, and |cff00ff00Pet|r correspond directly to those individual unitIDs.
• |cff00ff00Specific Unit|r lets you provide a specific valid unitID to watch.
|cffff0000Note|r: The game will not fire events for all valid unitIDs, making some untrackable by this trigger.
• |cffffff00Party|r, |cffffff00Raid|r, |cffffff00Boss|r, |cffffff00Arena|r, and |cffffff00Nameplate|r can match multiple corresponding unitIDs.
• |cffffff00Smart Group|r adjusts to your current group type, matching just the "player" when solo, "party" units (including "player") in a party or "raid" units in a raid.
• |cffffff00Multi-target|r attempts to use the Combat Log events, rather than unitID, to track affected units.
|cffff0000Note|r: Without a direct relationship to actual unitIDs, results may vary.

|cffffff00*|r Yellow Unit settings can match multiple units and will default to being active even while no affected units are found without a Unit Count or Match Count setting.]=] ] = [=[• |cff00ff00Player|r, |cff00ff00Target|r, |cff00ff00Focus|r, and |cff00ff00Pet|r correspond directly to those individual unitIDs.
• |cff00ff00Specific Unit|r lets you provide a specific valid unitID to watch.
|cffff0000Note|r: The game will not fire events for all valid unitIDs, making some untrackable by this trigger.
• |cffffff00Party|r, |cffffff00Raid|r, |cffffff00Boss|r, |cffffff00Arena|r, and |cffffff00Nameplate|r can match multiple corresponding unitIDs.
• |cffffff00Smart Group|r adjusts to your current group type, matching just the "player" when solo, "party" units (including "player") in a party or "raid" units in a raid.
• |cffffff00Multi-target|r attempts to use the Combat Log events, rather than unitID, to track affected units.
|cffff0000Note|r: Without a direct relationship to actual unitIDs, results may vary.

|cffffff00*|r Yellow Unit settings can match multiple units and will default to being active even while no affected units are found without a Unit Count or Match Count setting.]=]
	L["A 20x20 pixels icon"] = "Ein Symbol mit 20x20 Pixeln"
	L["A 32x32 pixels icon"] = "Ein Symbol mit 32x32 Pixeln"
	L["A 40x40 pixels icon"] = "Ein Symbol mit 40x40 Pixeln"
	L["A 48x48 pixels icon"] = "Ein Symbol mit 48x48 Pixeln"
	L["A 64x64 pixels icon"] = "Ein Symbol mit 64x64 Pixeln"
	L["A group that dynamically controls the positioning of its children"] = "Eine Gruppe, die dynamisch die Position ihrer Kinder steuert"
	--[[Translation missing --]]
	L[ [=[A timer will automatically be displayed according to default Interface Settings (overridden by some addons).
Enable this setting if you want this timer to be hidden, or when using a KUIAR_Runtime text to display the timer]=] ] = [=[A timer will automatically be displayed according to default Interface Settings (overridden by some addons).
Enable this setting if you want this timer to be hidden, or when using a KUIAR_Runtime text to display the timer]=]
	--[[Translation missing --]]
	L["A Unit ID (e.g., party1)."] = "A Unit ID (e.g., party1)."
	--[[Translation missing --]]
	L["Ace: Funkeh, Nevcairiel"] = "Ace: Funkeh, Nevcairiel"
	--[[Translation missing --]]
	L["Active Aura Filters and Info"] = "Active Aura Filters and Info"
	--[[Translation missing --]]
	L["Actual Spec"] = "Actual Spec"
	L["Add %s"] = "Füge %s hinzu"
	L["Add a new display"] = "Neue Anzeige hinzufügen"
	L["Add Condition"] = "Neue Bedingung"
	L["Add Entry"] = "Eintrag hinzufügen"
	--[[Translation missing --]]
	L["Add Extra Elements"] = "Add Extra Elements"
	L["Add Option"] = "Option hinzufügen"
	L["Add Overlay"] = "Overlay hinzufügen"
	L["Add Property Change"] = "Weitere Änderung"
	--[[Translation missing --]]
	L["Add Snippet"] = "Add Snippet"
	L["Add Sub Option"] = "Unteroption hinzufügen"
	L["Add to group %s"] = "Zu Gruppe %s hinzufügen"
	L["Add to new Dynamic Group"] = "Neue dynamische Gruppe hinzufügen"
	L["Add to new Group"] = "Neue Gruppe hinzufügen"
	L["Add Trigger"] = "Auslöser hinzufügen"
	--[[Translation missing --]]
	L["Additional Events"] = "Additional Events"
	L["Advanced"] = "Erweitert"
	--[[Translation missing --]]
	L["Affected Unit Filters and Info"] = "Affected Unit Filters and Info"
	L["Align"] = "Ausrichtung"
	L["Alignment"] = "Ausrichtung"
	--[[Translation missing --]]
	L["All maintainers of the libraries we use, especially:"] = "All maintainers of the libraries we use, especially:"
	L["All of"] = "Alles von"
	--[[Translation missing --]]
	L["Allow Full Rotation"] = "Allow Full Rotation"
	L["Anchor"] = "Anker"
	--[[Translation missing --]]
	L["Anchor Mode"] = "Anchor Mode"
	L["Anchor Point"] = "Ankerpunkt"
	L["Anchored To"] = "Angeheftet an"
	L["And "] = "Und"
	L["and"] = "und"
	--[[Translation missing --]]
	L["and %s"] = "and %s"
	L["and aligned left"] = "und links ausgerichtet"
	L["and aligned right"] = "und rechts ausgerichtet"
	--[[Translation missing --]]
	L["And our Patreons, Discord Regulars and Subscribers, and Friends of the Addon:"] = "And our Patreons, Discord Regulars and Subscribers, and Friends of the Addon:"
	L["and rotated left"] = "und nach links gedreht"
	L["and rotated right"] = "und nach rechts gedreht"
	--[[Translation missing --]]
	L["and with width |cFFFF0000%s|r and %s"] = "and with width |cFFFF0000%s|r and %s"
	L["Angle"] = "Winkel"
	--[[Translation missing --]]
	L["Angle Between Auras"] = "Angle Between Auras"
	L["Animate"] = "Animieren"
	L["Animated Expand and Collapse"] = "Erweitern und Verbergen animieren"
	L["Animates progress changes"] = "Animiert Fortschrittsänderungen"
	--[[Translation missing --]]
	L["Animation End"] = "Animation End"
	L["Animation Mode"] = "Animationsmodus"
	L["Animation relative duration description"] = [=[Die Dauer der Animation relativ zur Dauer der Anzeige als Bruchteil (1/2), als Prozent (50%) oder als Dezimal (0.5).
|cFFFF0000Notiz:|r Falls die Anzeige keine Dauer besitzt (zb. Aura ohne Dauer), wird diese Animation nicht ausgeführt.

|cFF4444FFFBeispiel:|r
Falls die Dauer der Animation auf |cFF00CC0010%|r gesetzt wurde und die Dauer der Anzeige 20 Sekunden beträgt (zb. Debuff), dann wird diese Animation über eine Dauer von 2 Sekunden abgespielt.
Falls die Dauer der Animation auf |cFF00CC0010%|r gesetzt wurde und für die Anzeige keine Dauer bekannt ist (Meistens kann diese auch manuell festgelegt werden), wird diese Animation nicht abgespielt.]=]
	L["Animation Sequence"] = "Animationssequenz"
	--[[Translation missing --]]
	L["Animation Start"] = "Animation Start"
	--[[Translation missing --]]
	L["Any of"] = "Any of"
	L["Apply Template"] = "Vorlage übernehmen"
	L["Arcane Orb"] = "Arkane Kugel"
	--[[Translation missing --]]
	L["Area"] = "Area"
	--[[Translation missing --]]
	L["At a position a bit left of Left HUD position."] = "At a position a bit left of Left HUD position."
	--[[Translation missing --]]
	L["At a position a bit left of Right HUD position"] = "At a position a bit left of Right HUD position"
	L["At the same position as Blizzard's spell alert"] = "An der Position von Blizzards Zauberwarnmeldung"
	--[[Translation missing --]]
	L["Attach to Foreground"] = "Attach to Foreground"
	--[[Translation missing --]]
	L[ [=[Aura is
Off Screen]=] ] = [=[Aura is
Off Screen]=]
	L["Aura Name Pattern"] = "Aura Namensmuster"
	--[[Translation missing --]]
	L["Aura Order"] = "Aura Order"
	--[[Translation missing --]]
	L["Aura received from: %s"] = "Aura received from: %s"
	--[[Translation missing --]]
	L["Aura: '%s'"] = "Aura: '%s'"
	--[[Translation missing --]]
	L["Auto-Clone (Show All Matches)"] = "Auto-Clone (Show All Matches)"
	--[[Translation missing --]]
	L["Automatic length"] = "Automatic length"
	L["Backdrop Color"] = "Hintergrundfarbe"
	--[[Translation missing --]]
	L["Backdrop in Front"] = "Backdrop in Front"
	L["Backdrop Style"] = "Hintergrundstil"
	--[[Translation missing --]]
	L["Background Inner"] = "Background Inner"
	L["Background Offset"] = "Hintergrundversatz"
	L["Background Texture"] = "Hintergrundtextur"
	L["Bar Alpha"] = "Balkentransparenz"
	L["Bar Color Settings"] = "Balkenfarbeneinstellungen"
	L["Big Icon"] = "Großes Symbol"
	L["Blend Mode"] = "Mischmodus"
	L["Blue Rune"] = "Blaue Rune"
	L["Blue Sparkle Orb"] = "Blau funkelnde Kugel"
	L["Border %s"] = "Rahmen %s"
	--[[Translation missing --]]
	L["Border Anchor"] = "Border Anchor"
	L["Border Color"] = "Randfarbe"
	--[[Translation missing --]]
	L["Border in Front"] = "Border in Front"
	L["Border Inset"] = "Rahmeneinlassung"
	L["Border Offset"] = "Randversatz"
	L["Border Settings"] = "Rahmeneinstellungen"
	L["Border Size"] = "Rahmengröße"
	L["Border Style"] = "Rahmenstil"
	--[[Translation missing --]]
	L["Bracket Matching"] = "Bracket Matching"
	--[[Translation missing --]]
	L["Browse Wago, the largest collection of auras."] = "Browse Wago, the largest collection of auras."
	--[[Translation missing --]]
	L["By default this shows the information from the trigger selected via dynamic information. The information from a specific trigger can be shown via e.g. %2.p."] = "By default this shows the information from the trigger selected via dynamic information. The information from a specific trigger can be shown via e.g. %2.p."
	--[[Translation missing --]]
	L["Can be a UID (e.g., party1)."] = "Can be a UID (e.g., party1)."
	--[[Translation missing --]]
	L["Can set to 0 if Columns * Width equal File Width"] = "Can set to 0 if Columns * Width equal File Width"
	--[[Translation missing --]]
	L["Can set to 0 if Rows * Height equal File Height"] = "Can set to 0 if Rows * Height equal File Height"
	--[[Translation missing --]]
	L["Case Insensitive"] = "Case Insensitive"
	--[[Translation missing --]]
	L["Cast by a Player Character"] = "Cast by a Player Character"
	--[[Translation missing --]]
	L["Categories to Update"] = "Categories to Update"
	--[[Translation missing --]]
	L["Changelog"] = "Changelog"
	--[[Translation missing --]]
	L["Chat with KUIAR_Runtime experts on our Discord server."] = "Chat with KUIAR_Runtime experts on our Discord server."
	L["Check On..."] = "Prüfen auf..."
	--[[Translation missing --]]
	L["Check out our wiki for a large collection of examples and snippets."] = "Check out our wiki for a large collection of examples and snippets."
	L["Children:"] = "Kinder:"
	L["Choose"] = "Auswählen"
	--[[Translation missing --]]
	L["Circular Texture %s"] = "Circular Texture %s"
	--[[Translation missing --]]
	L["Clear Debug Logs"] = "Clear Debug Logs"
	--[[Translation missing --]]
	L["Clear Saved Data"] = "Clear Saved Data"
	--[[Translation missing --]]
	L["Click to replace the name with %s."] = "Click to replace the name with %s."
	--[[Translation missing --]]
	L["Clip Overlays"] = "Clip Overlays"
	--[[Translation missing --]]
	L["Clipped by Foreground"] = "Clipped by Foreground"
	L["Close"] = "Schließen"
	--[[Translation missing --]]
	L["Code Editor"] = "Code Editor"
	L["Collapse"] = "Minimieren"
	L["Collapse all loaded displays"] = "Alle geladenen Anzeigen minimieren"
	L["Collapse all non-loaded displays"] = "Alle nicht geladenen Anzeigen minimieren"
	--[[Translation missing --]]
	L["Collapse all pending Import"] = "Collapse all pending Import"
	--[[Translation missing --]]
	L["Collapsible Group"] = "Collapsible Group"
	L["color"] = "Farbe"
	L["Column Height"] = "Spaltenhöhe"
	L["Column Space"] = "Spaltenabstand"
	--[[Translation missing --]]
	L["Columns"] = "Columns"
	--[[Translation missing --]]
	L["COMBAT_LOG_EVENT_UNFILTERED with no filter can trigger frame drops in raid environment."] = "COMBAT_LOG_EVENT_UNFILTERED with no filter can trigger frame drops in raid environment."
	L["Combinations"] = "Kombinationen"
	--[[Translation missing --]]
	L["Combine Matches Per Unit"] = "Combine Matches Per Unit"
	--[[Translation missing --]]
	L["Common Text"] = "Common Text"
	--[[Translation missing --]]
	L["Compare against the number of units affected."] = "Compare against the number of units affected."
	--[[Translation missing --]]
	L["Compatibility Options"] = "Compatibility Options"
	L["Compress"] = "Stauchen"
	--[[Translation missing --]]
	L["Configure what options appear on this panel."] = "Configure what options appear on this panel."
	L["Constant Factor"] = "Konstanter Faktor"
	L["Control-click to select multiple displays"] = "Strg-Klick, um mehrere Anzeigen auszuwählen"
	L["Controls the positioning and configuration of multiple displays at the same time"] = "Eine Gruppe, die die Position und Konfiguration ihrer Kinder kontrolliert"
	L["Convert to..."] = "Konvertieren zu..."
	--[[Translation missing --]]
	L["Cooldown Numbers might be added by WoW. You can configure these in the game settings."] = "Cooldown Numbers might be added by WoW. You can configure these in the game settings."
	L["Copy"] = "Kopieren"
	L["Copy settings..."] = "Einstellungen kopieren..."
	L["Copy to all auras"] = "Kopiere zu allen Auren"
	--[[Translation missing --]]
	L["Could not parse '%s'. Expected a table."] = "Could not parse '%s'. Expected a table."
	--[[Translation missing --]]
	L["Counts the number of matches over all units."] = "Counts the number of matches over all units."
	--[[Translation missing --]]
	L["Counts the number of matches per unit."] = "Counts the number of matches per unit."
	--[[Translation missing --]]
	L["Create a Copy"] = "Create a Copy"
	L["Creating buttons: "] = "Erstelle Schaltflächen:"
	L["Creating options: "] = "Erstelle Optionen:"
	--[[Translation missing --]]
	L["Custom - Allows you to define a custom Lua function that returns a list of string values. %c1 will be replaced by the first value returned, %c2 by the second, etc."] = "Custom - Allows you to define a custom Lua function that returns a list of string values. %c1 will be replaced by the first value returned, %c2 by the second, etc."
	L["Custom Code"] = "Benutzerdefinierter Code"
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
	L["Custom Trigger"] = "Benutzerdefinierter Auslöser"
	L["Custom trigger event tooltip"] = [=[Wähle die Ereignisse, die den benutzerdefinierten Auslöser aufrufen sollen.
Mehrere Ereignisse können durch Komma oder Leerzeichen getrennt werden.

|cFF4444FFBeispiel:|r
UNIT_POWER, UNIT_AURA PLAYER_TARGET_CHANGED]=]
	L["Custom trigger status tooltip"] = [=[Wähle die Events, die den benutzerdefinierten Auslöser aufrufen sollen.
Da es sich um einen Zustands-Auslöser handelt, kann es passieren, dass KUIAR_Runtime nicht die in der WoW-API spezifizierten Argumente übergibt.
Mehrere Events können durch Komma oder Leerzeichen getrennt werden.

|cFF4444FFBeispiel:|r
UNIT_POWER, UNIT_AURA PLAYER_TARGET_CHANGED]=]
	--[[Translation missing --]]
	L["Custom trigger Update Throttle"] = "Custom trigger Update Throttle"
	--[[Translation missing --]]
	L["Custom Trigger: Ignore Lua Errors on OPTIONS event"] = "Custom Trigger: Ignore Lua Errors on OPTIONS event"
	--[[Translation missing --]]
	L["Custom Trigger: Send fake events instead of STATUS event"] = "Custom Trigger: Send fake events instead of STATUS event"
	--[[Translation missing --]]
	L["Custom Unload"] = "Custom Unload"
	L["Custom Untrigger"] = "Benutzerdefinierter Umkehrauslöser"
	--[[Translation missing --]]
	L["Debug Log"] = "Debug Log"
	--[[Translation missing --]]
	L["Debug Log:"] = "Debug Log:"
	L["Default"] = "Standard"
	L["Default Color"] = "Standardfarbe"
	L["Delay"] = "Verzögerung"
	L["Delete"] = "Löschen"
	L["Delete all"] = "Alle löschen"
	L["Delete children and group"] = "Kinder und Gruppe löschen"
	L["Delete Entry"] = "Eintrag löschen"
	--[[Translation missing --]]
	L["Deleting auras: "] = "Deleting auras: "
	L["Description Text"] = "Beschreibungstext"
	--[[Translation missing --]]
	L["Determines how many entries can be in the table."] = "Determines how many entries can be in the table."
	L["Differences"] = "Unterschiede"
	--[[Translation missing --]]
	L["Disallow Entry Reordering"] = "Disallow Entry Reordering"
	--[[Translation missing --]]
	L["Discord"] = "Discord"
	L["Display Name"] = "Anzeigename"
	L["Display Text"] = "Anzeigetext"
	L["Displays a text, works best in combination with other displays"] = "Zeigt einen Text an, funktioniert am besten in Kombination mit anderen Anzeigen"
	L["Distribute Horizontally"] = "Horizontal verteilen"
	L["Distribute Vertically"] = "Vertikal verteilen"
	L["Do not group this display"] = "Diese Anzeige nicht kopieren"
	--[[Translation missing --]]
	L["Do you want to enable updates for this aura"] = "Do you want to enable updates for this aura"
	--[[Translation missing --]]
	L["Do you want to ignore updates for this aura"] = "Do you want to ignore updates for this aura"
	L["Documentation"] = "Dokumentation"
	L["Done"] = "Fertig"
	L["Drag to move"] = "Ziehen, um diese Anzeige zu verschieben"
	L["Duplicate"] = "Duplizieren"
	L["Duplicate All"] = "Alle duplizieren"
	L["Duration (s)"] = "Dauer (s)"
	L["Duration Info"] = "Dauerinformationen"
	--[[Translation missing --]]
	L["Dynamic Duration"] = "Dynamic Duration"
	L["Dynamic Group"] = "Dynamische Gruppe"
	--[[Translation missing --]]
	L["Dynamic Group Settings"] = "Dynamic Group Settings"
	L["Dynamic Information"] = "Dynamische Information"
	L["Dynamic information from first active trigger"] = "Dynamische Information vom ersten aktiven Auslöser"
	L["Dynamic information from Trigger %i"] = "Dynamische Information des %i. Auslösers"
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
	L["Enabled"] = "Aktivieren"
	L["End Angle"] = "Endewinkel"
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
	L["Entry %i"] = "Eintrag %i"
	L["Entry limit"] = "Eintragsgrenze"
	L["Entry Name Source"] = "Eintragsnamensquelle"
	L["Event Type"] = "Ereignistyp"
	L["Everything"] = "Alles"
	--[[Translation missing --]]
	L["Exact Item Match"] = "Exact Item Match"
	L["Exact Spell Match"] = "Exakte Zauberübereinstimmung"
	L["Expand"] = "Erweitern"
	L["Expand all loaded displays"] = "Alle geladenen Anzeigen erweitern"
	L["Expand all non-loaded displays"] = "Alle nicht geladenen Anzeigen erweitern"
	--[[Translation missing --]]
	L["Expand all pending Import"] = "Expand all pending Import"
	L["Expansion is disabled because this group has no children"] = "Erweiterung deaktiviert, da diese Gruppe keine Kinder hat"
	--[[Translation missing --]]
	L["Export debug table..."] = "Export debug table..."
	--[[Translation missing --]]
	L["Export..."] = "Export..."
	--[[Translation missing --]]
	L["Exporting"] = "Exporting"
	L["External"] = "Extern"
	--[[Translation missing --]]
	L["Extra Height"] = "Extra Height"
	--[[Translation missing --]]
	L["Extra Width"] = "Extra Width"
	L["Fade"] = "Verblassen"
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
	L["Filter by Class"] = "Nach Klasse filtern"
	L["Filter by Group Role"] = "Nach Gruppenrolle filtern"
	--[[Translation missing --]]
	L["Filter by Hostility"] = "Filter by Hostility"
	--[[Translation missing --]]
	L["Filter by Npc ID"] = "Filter by Npc ID"
	L["Filter by Raid Role"] = "Filter nach Schlachtzugsrollen"
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
	L["Find Auras"] = "Finde Auren"
	L["Finish"] = "Endanimation"
	--[[Translation missing --]]
	L["Finishing..."] = "Finishing..."
	L["Fire Orb"] = "Feuerkugel"
	--[[Translation missing --]]
	L["Flat Framelevels"] = "Flat Framelevels"
	L["Foreground Texture"] = "Vordergrundtextur"
	--[[Translation missing --]]
	L["Format for %s"] = "Format for %s"
	--[[Translation missing --]]
	L["Found a Bug?"] = "Found a Bug?"
	L["Frame"] = "Frame"
	--[[Translation missing --]]
	L["Frame Count"] = "Frame Count"
	--[[Translation missing --]]
	L["Frame Height"] = "Frame Height"
	--[[Translation missing --]]
	L["Frame Rate"] = "Frame Rate"
	L["Frame Strata"] = "Frame-Schicht"
	--[[Translation missing --]]
	L["Frame Width"] = "Frame Width"
	--[[Translation missing --]]
	L["Full Bar"] = "Full Bar"
	--[[Translation missing --]]
	L["Full Circle"] = "Full Circle"
	L["Global Conditions"] = "Globale Bedingungen"
	L["Glow %s"] = "Leuchten %s"
	L["Glow Action"] = "Leuchtaktion"
	--[[Translation missing --]]
	L["Glow Anchor"] = "Glow Anchor"
	L["Glow Color"] = "Leuchtfarbe"
	--[[Translation missing --]]
	L["Glow Frame Type"] = "Glow Frame Type"
	L["Glow Type"] = "Leuchttyp"
	L["Green Rune"] = "Grüne Rune"
	--[[Translation missing --]]
	L["Grid direction"] = "Grid direction"
	L["Group (verb)"] = "Gruppieren"
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
	L["Group aura count description"] = [=[Die Anzahl der %s-Mitglieder, die von einer der Auren betroffen sein müssen, um den Trigger auszulösen.
Falls der eingegebene Wert eine ganze Zahl (z.B. 5) ist, wird die Anzahl der betroffenen Gruppenmitglieder damit verglichen.
Falls die Zahl als Dezimalzahl (z.B. 0.5), Bruch (z.B. 1/2) oder Prozentsatz (z.B. 50%%) eingegeben wird, muss dieser Teil der %s betroffen sein.

|cFF4444FBeispiel:|r
|cFF00CC00> 0|r Löst aus, wenn irgendjemand in der %s betroffen ist.
|cFF00CC00= 100%%|r Löst aus, wenn alle in der %s betroffen sind.
|cFF00CC00!= 2|r Löst aus, wenn weniger oder mehr als 2 Spieler in der %s betroffen sind.
|cFF00CC00<= 0.8|r Löst aus, wenn weniger als 80%% in der %s betroffen sind (4 von 5 Gruppenmitgliedern, 8 von 10 oder 20 von 25 Schlachtzugsmitgliedern).
|cFF00CC00> 1/2|r Löst aus, wenn mehr als die Hälfte der %s betroffen sind.
|cFF00CC00>= 0|r Löst immer aus.]=]
	--[[Translation missing --]]
	L["Group by Frame"] = "Group by Frame"
	--[[Translation missing --]]
	L["Group Description"] = "Group Description"
	L["Group Icon"] = "Gruppensymbol"
	L["Group key"] = "Gruppenschlüssel"
	--[[Translation missing --]]
	L["Group Options"] = "Group Options"
	--[[Translation missing --]]
	L["Group player(s) found"] = "Group player(s) found"
	L["Group Role"] = "Gruppenrolle"
	L["Group Scale"] = "Gruppenskalierung"
	--[[Translation missing --]]
	L["Group Settings"] = "Group Settings"
	L["Hawk"] = "Falke"
	L["Help"] = "Hilfe"
	--[[Translation missing --]]
	L["Hide After"] = "Hide After"
	--[[Translation missing --]]
	L["Hide Background"] = "Hide Background"
	--[[Translation missing --]]
	L["Hide Glows applied by this aura"] = "Hide Glows applied by this aura"
	L["Hide on"] = "Verbergen falls"
	L["Hide this group's children"] = "Die Kinder dieser Gruppe ausblenden"
	--[[Translation missing --]]
	L["Highlights"] = "Highlights"
	L["Horizontal Align"] = "Horizontale Ausrichtung"
	L["Horizontal Bar"] = "Horizontaler Balken"
	L["Huge Icon"] = "Riesiges Symbol"
	--[[Translation missing --]]
	L["Hybrid Position"] = "Hybrid Position"
	--[[Translation missing --]]
	L["Hybrid Sort Mode"] = "Hybrid Sort Mode"
	--[[Translation missing --]]
	L["Icon - The icon associated with the display"] = "Icon - The icon associated with the display"
	L["Icon Info"] = "Symbolinfo"
	L["Icon Inset"] = "Symboleinrückung"
	--[[Translation missing --]]
	L["Icon Picker"] = "Icon Picker"
	--[[Translation missing --]]
	L["Icon Position"] = "Icon Position"
	--[[Translation missing --]]
	L["Icon Settings"] = "Icon Settings"
	--[[Translation missing --]]
	L["Icon Source"] = "Icon Source"
	L["If"] = "Falls"
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
	L["Ignored"] = "Ignoriert"
	--[[Translation missing --]]
	L["Ignored Aura Name"] = "Ignored Aura Name"
	--[[Translation missing --]]
	L["Ignored Exact Spell ID(s)"] = "Ignored Exact Spell ID(s)"
	--[[Translation missing --]]
	L["Ignored Name(s)"] = "Ignored Name(s)"
	--[[Translation missing --]]
	L["Ignored Spell ID"] = "Ignored Spell ID"
	L["Import"] = "Importieren"
	--[[Translation missing --]]
	L["Import / Export"] = "Import / Export"
	L["Import a display from an encoded string"] = "Anzeige von Klartext importieren"
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
	L["Invalid Item Name/ID/Link"] = "Ungültige(r) Gegenstandsname/-ID/-link"
	L["Invalid Spell ID"] = "Ungültige Zauber-ID"
	L["Invalid Spell Name/ID/Link"] = "Ungültige(r) Zaubername/-ID/-link"
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
	L["Is Stealable"] = "Ist stehlbar"
	--[[Translation missing --]]
	L["Is Unit"] = "Is Unit"
	L["Justify"] = "Ausrichten"
	--[[Translation missing --]]
	L["Keep Aspect Ratio"] = "Keep Aspect Ratio"
	--[[Translation missing --]]
	L["Keep your Wago imports up to date with the Companion App."] = "Keep your Wago imports up to date with the Companion App."
	--[[Translation missing --]]
	L["Large Input"] = "Large Input"
	L["Leaf"] = "Blatt"
	--[[Translation missing --]]
	L["Left 2 HUD position"] = "Left 2 HUD position"
	L["Left HUD position"] = "Linke HUD Position"
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
	L["Limit"] = "Limit"
	--[[Translation missing --]]
	L["Line"] = "Line"
	--[[Translation missing --]]
	L["Linear Texture %s"] = "Linear Texture %s"
	--[[Translation missing --]]
	L["Linked aura: "] = "Linked aura: "
	--[[Translation missing --]]
	L["Linked Auras"] = "Linked Auras"
	L["Load"] = "Laden"
	L["Loaded"] = "Geladen"
	--[[Translation missing --]]
	L["Loaded/Standby"] = "Loaded/Standby"
	--[[Translation missing --]]
	L["Lock Positions"] = "Lock Positions"
	L["Low Mana"] = "Niedriges Mana"
	--[[Translation missing --]]
	L["Magnetically Align"] = "Magnetically Align"
	L["Main"] = "Hauptanimation"
	--[[Translation missing --]]
	L["Manual with %i/%i"] = "Manual with %i/%i"
	--[[Translation missing --]]
	L["Matches %s spells"] = "Matches %s spells"
	--[[Translation missing --]]
	L["Matches the height setting of a horizontal bar or width for a vertical bar."] = "Matches the height setting of a horizontal bar or width for a vertical bar."
	L["Max"] = "Max"
	--[[Translation missing --]]
	L["Max Length"] = "Max Length"
	--[[Translation missing --]]
	L["Maximum"] = "Maximum"
	--[[Translation missing --]]
	L["Media Type"] = "Media Type"
	L["Medium Icon"] = "Mittelgroßes Symbol"
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
	L["Move Above Group"] = "Über die Gruppe verschieben"
	L["Move Below Group"] = "Unter die Gruppe verschieben"
	L["Move Down"] = "Nach unten verschieben"
	L["Move Entry Down"] = "Eintrag nach unten verschieben"
	L["Move Entry Up"] = "Eintrag nach oben verschieben"
	--[[Translation missing --]]
	L["Move Into Above Group"] = "Move Into Above Group"
	--[[Translation missing --]]
	L["Move Into Below Group"] = "Move Into Below Group"
	L["Move this display down in its group's order"] = "Verschiebt diese Anzeige in der Reihenfolge seiner Gruppe nach unten"
	L["Move this display up in its group's order"] = "Verschiebt diese Anzeige in der Reihenfolge seiner Gruppe nach oben"
	L["Move Up"] = "Nach oben verschieben"
	--[[Translation missing --]]
	L["Moving auras: "] = "Moving auras: "
	L["Multiple Displays"] = "Mehrere Anzeigen"
	L["Multiselect ignored tooltip"] = [=[
|cFFFF0000Ignoriert|r - |cFF777777Einfach|r - |cFF777777Mehrfach|r
Diese Option wird nicht verwendet, um zu prüfen, wann die Anzeige geladen wird.]=]
	L["Multiselect multiple tooltip"] = [=[
|cFFFF0000Ignoriert|r - |cFF777777Einfach|r - |cFF777777Mehrfach|r
Beliebige Anzahl an Werten zum Vergleichen können ausgewählt werden.]=]
	L["Multiselect single tooltip"] = [=[
|cFFFF0000Ignoriert|r - |cFF777777Einfach|r - |cFF777777Mehrfach|r
Nur ein Wert kann ausgewählt werden.]=]
	--[[Translation missing --]]
	L["Must be a power of 2"] = "Must be a power of 2"
	--[[Translation missing --]]
	L["Name - The name of the display (usually an aura name), or the display's ID if there is no dynamic name"] = "Name - The name of the display (usually an aura name), or the display's ID if there is no dynamic name"
	L["Name Info"] = "Namensinfo"
	--[[Translation missing --]]
	L["Name Pattern Match"] = "Name Pattern Match"
	--[[Translation missing --]]
	L["Name:"] = "Name:"
	L["Negator"] = "Nicht"
	L["New Aura"] = "Neue Aura"
	--[[Translation missing --]]
	L["New Template"] = "New Template"
	L["New Value"] = "Neuer Wert"
	L["No Children"] = "Keine Kinder"
	--[[Translation missing --]]
	L["No Logs saved."] = "No Logs saved."
	--[[Translation missing --]]
	L["Not a table"] = "Not a table"
	L["Not all children have the same value for this option"] = "Nicht alle Kinder besitzen denselben Wert"
	L["Not Loaded"] = "Nicht geladen"
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
	L["Okay"] = "Okey"
	--[[Translation missing --]]
	L["ON"] = "ON"
	L["On Hide"] = "Beim Ausblenden"
	L["On Show"] = "Beim Einblenden"
	--[[Translation missing --]]
	L["Only Match auras cast by a player (not an npc)"] = "Only Match auras cast by a player (not an npc)"
	--[[Translation missing --]]
	L["Only match auras cast by people other than the player or their pet"] = "Only match auras cast by people other than the player or their pet"
	--[[Translation missing --]]
	L["Only match auras cast by the player or their pet"] = "Only match auras cast by the player or their pet"
	L["Operator"] = "Operator"
	--[[Translation missing --]]
	L["Option %i"] = "Option %i"
	--[[Translation missing --]]
	L["Option key"] = "Option key"
	--[[Translation missing --]]
	L["Option Type"] = "Option Type"
	--[[Translation missing --]]
	L["Options will open after combat ends."] = "Options will open after combat ends."
	L["or"] = "oder"
	--[[Translation missing --]]
	L["or %s"] = "or %s"
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
	L["Own Only"] = "Nur eigene"
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
	L["Paste text below"] = "Text unten einfügen"
	--[[Translation missing --]]
	L["Paste Trigger Settings"] = "Paste Trigger Settings"
	--[[Translation missing --]]
	L["Places a tick on the bar"] = "Places a tick on the bar"
	L["Play Sound"] = "Sound abspielen"
	--[[Translation missing --]]
	L["Player Spells found:"] = "Player Spells found:"
	L["Portrait Zoom"] = "Portraitzoom"
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
	L["Press Ctrl+C to copy"] = "Drücke Strg+C zum kopieren"
	--[[Translation missing --]]
	L["Press Ctrl+C to copy the URL"] = "Press Ctrl+C to copy the URL"
	--[[Translation missing --]]
	L["Prevent Merging"] = "Prevent Merging"
	--[[Translation missing --]]
	L["Progress - The remaining time of a timer, or a non-timer value"] = "Progress - The remaining time of a timer, or a non-timer value"
	L["Progress Bar"] = "Fortschrittsbalken"
	--[[Translation missing --]]
	L["Progress Bar Settings"] = "Progress Bar Settings"
	--[[Translation missing --]]
	L["Progress Settings"] = "Progress Settings"
	L["Progress Texture"] = "Fortschrittstextur"
	--[[Translation missing --]]
	L["Progress Texture Settings"] = "Progress Texture Settings"
	L["Purple Rune"] = "Violette Rune"
	L["Put this display in a group"] = "Diese Anzeige in eine Gruppe stecken"
	--[[Translation missing --]]
	L["Range in yards"] = "Range in yards"
	--[[Translation missing --]]
	L["Ready for Install"] = "Ready for Install"
	--[[Translation missing --]]
	L["Ready for Update"] = "Ready for Update"
	L["Re-center X"] = "Zentrum (X)"
	L["Re-center Y"] = "Zentrum (Y)"
	--[[Translation missing --]]
	L["Reciprocal TRIGGER:# requests will be ignored!"] = "Reciprocal TRIGGER:# requests will be ignored!"
	--[[Translation missing --]]
	L["Redo"] = "Redo"
	--[[Translation missing --]]
	L["Regions of type \"%s\" are not supported."] = "Regions of type \"%s\" are not supported."
	L["Remove"] = "Entfernen"
	--[[Translation missing --]]
	L["Remove All Sounds"] = "Remove All Sounds"
	--[[Translation missing --]]
	L["Remove All Text To Speech"] = "Remove All Text To Speech"
	L["Remove this display from its group"] = "Diese Anzeige aus seiner Gruppe entfernen"
	L["Remove this property"] = "Eigenschaft entfernen"
	L["Rename"] = "Umbenennen"
	L["Repeat After"] = "Wiederholen nach"
	L["Repeat every"] = "Wiederhole alle"
	--[[Translation missing --]]
	L["Report bugs on our issue tracker."] = "Report bugs on our issue tracker."
	--[[Translation missing --]]
	L["Require unit from trigger"] = "Require unit from trigger"
	L["Required for Activation"] = "Benötigt zur Aktivierung"
	--[[Translation missing --]]
	L["Requires LibSpecialization, that is e.g. a up-to date KUIAR_Runtime version"] = "Requires LibSpecialization, that is e.g. a up-to date KUIAR_Runtime version"
	--[[Translation missing --]]
	L["Reset all options to their default values."] = "Reset all options to their default values."
	L["Reset Entry"] = "Eintrag zurücksetzen"
	L["Reset to Defaults"] = "Auf Standard zurücksetzen"
	--[[Translation missing --]]
	L["Right 2 HUD position"] = "Right 2 HUD position"
	L["Right HUD position"] = "Rechte HUD Position"
	L["Right-click for more options"] = "|cFF8080FF(Rechtsklick)|r für mehr Optionen"
	L["Rotate"] = "Rotieren"
	L["Rotate In"] = "Nach innen rotieren"
	L["Rotate Out"] = "Nach außen rotieren"
	L["Rotate Text"] = "Text rotieren"
	L["Rotation Mode"] = "Rotationsmodus"
	L["Row Space"] = "Zeilenabstand"
	L["Row Width"] = "Zeilenbreite"
	--[[Translation missing --]]
	L["Rows"] = "Rows"
	--[[Translation missing --]]
	L["Run on..."] = "Run on..."
	L["Same"] = "Gleich"
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
	L["Select the auras you always want to be listed first"] = "Wähle die Auren aus, die immer an oberster Stelle angezeigt werden sollen"
	--[[Translation missing --]]
	L["Selected Frame"] = "Selected Frame"
	L["Send To"] = "Senden an"
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
	L["Settings"] = "Einstellungen"
	L["Shadow Color"] = "Schattenfarbe"
	--[[Translation missing --]]
	L["Shadow X Offset"] = "Shadow X Offset"
	--[[Translation missing --]]
	L["Shadow Y Offset"] = "Shadow Y Offset"
	L["Shift-click to create chat link"] = "Shift-Klick, um einen Chatlink zu erstellen"
	--[[Translation missing --]]
	L["Show \"Edge\""] = "Show \"Edge\""
	--[[Translation missing --]]
	L["Show \"Swipe\""] = "Show \"Swipe\""
	--[[Translation missing --]]
	L["Show and Clone Settings"] = "Show and Clone Settings"
	L["Show Border"] = "Rahmen anzeigen"
	--[[Translation missing --]]
	L["Show Circular Texture"] = "Show Circular Texture"
	--[[Translation missing --]]
	L["Show Debug Logs"] = "Show Debug Logs"
	L["Show Glow"] = "Leuchten anzeigen"
	L["Show Icon"] = "Symbol anzeigen"
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
	L["Show model of unit "] = "Modell der Einheit zeigen"
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
	L["Show this group's children"] = "Die Kinder dieser Gruppe anzeigen"
	--[[Translation missing --]]
	L["Show Tick"] = "Show Tick"
	L["Shows a 3D model from the game files"] = "Zeigt ein 3D-Modell aus den Spieldateien"
	--[[Translation missing --]]
	L["Shows a border"] = "Shows a border"
	--[[Translation missing --]]
	L["Shows a Circular Progress Texture"] = "Shows a Circular Progress Texture"
	L["Shows a custom texture"] = "Zeigt eine benutzerdefinierte Textur"
	--[[Translation missing --]]
	L["Shows a glow"] = "Shows a glow"
	--[[Translation missing --]]
	L["Shows a Linear Progress Texture"] = "Shows a Linear Progress Texture"
	--[[Translation missing --]]
	L["Shows a model"] = "Shows a model"
	L["Shows a progress bar with name, timer, and icon"] = "Zeigt einen Fortschrittsbalken mit Name, Zeitanzeige und Symbol"
	L["Shows a spell icon with an optional cooldown overlay"] = "Zeigt ein Zaubersymbol mit optionaler Abklingzeit-Anzeige."
	--[[Translation missing --]]
	L["Shows a Stop Motion"] = "Shows a Stop Motion"
	--[[Translation missing --]]
	L["Shows a stop motion texture"] = "Shows a stop motion texture"
	--[[Translation missing --]]
	L["Shows a Texture"] = "Shows a Texture"
	L["Shows a texture that changes based on duration"] = "Zeigt eine Textur, die sich über die Zeit verändert"
	--[[Translation missing --]]
	L["Shows nothing, except sub elements"] = "Shows nothing, except sub elements"
	L["Shows one or more lines of text, which can include dynamic information such as progress or stacks"] = "Zeigt ein oder mehrere Zeilen Text an, der dynamische Informationen anzeigen kann, z.B. Fortschritt oder Stapel"
	L["Size"] = "Größe"
	--[[Translation missing --]]
	L["Slant Amount"] = "Slant Amount"
	--[[Translation missing --]]
	L["Slant Mode"] = "Slant Mode"
	--[[Translation missing --]]
	L["Slanted"] = "Slanted"
	L["Slide"] = "Gleiten"
	L["Slide In"] = "Einschieben"
	L["Slide Out"] = "Ausschieben"
	--[[Translation missing --]]
	L["Slider Step Size"] = "Slider Step Size"
	L["Small Icon"] = "Kleines Symbol"
	--[[Translation missing --]]
	L["Smooth Progress"] = "Smooth Progress"
	--[[Translation missing --]]
	L["Snippets"] = "Snippets"
	--[[Translation missing --]]
	L["Soft Max"] = "Soft Max"
	--[[Translation missing --]]
	L["Soft Min"] = "Soft Min"
	L["Sort"] = "Sortieren"
	L["Sound Channel"] = "Soundkanal"
	L["Sound File Path"] = "Sound Dateipfad"
	L["Sound Kit ID"] = "Sound Kit ID"
	L["Space Horizontally"] = "Horizontaler Abstand"
	L["Space Vertically"] = "Vertikaler Abstand"
	L["Spark Settings"] = "Funkeneinstellungen"
	L["Spark Texture"] = "Funkentextur"
	--[[Translation missing --]]
	L["Specific Currency ID"] = "Specific Currency ID"
	--[[Translation missing --]]
	L["Spell Selection Filters"] = "Spell Selection Filters"
	--[[Translation missing --]]
	L["Spells found:"] = "Spells found:"
	L["Stack Info"] = "Stapelinfo"
	--[[Translation missing --]]
	L["Stacks - The number of stacks of an aura (usually)"] = "Stacks - The number of stacks of an aura (usually)"
	--[[Translation missing --]]
	L["Standby"] = "Standby"
	L["Star"] = "Stern"
	L["Start"] = "Start"
	L["Start Angle"] = "Startwinkel"
	--[[Translation missing --]]
	L["Start Collapsed"] = "Start Collapsed"
	--[[Translation missing --]]
	L["Start of %s"] = "Start of %s"
	L["Step Size"] = "Schrittgröße"
	--[[Translation missing --]]
	L["Stop Motion %s"] = "Stop Motion %s"
	--[[Translation missing --]]
	L["Stop Motion Settings"] = "Stop Motion Settings"
	L["Stop Sound"] = "Sound stoppen"
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
	L["Temporary Group"] = "Temporäre Gruppe"
	L["Text %s"] = "Text %s"
	L["Text Color"] = "Textfarbe"
	L["Text Settings"] = "Texteinstellungen"
	--[[Translation missing --]]
	L["Texture %s"] = "Texture %s"
	L["Texture Info"] = "Texturinfo"
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
	L["The duration of the animation in seconds."] = "Die Dauer der Animation in Sekunden."
	L["The duration of the animation in seconds. The finish animation does not start playing until after the display would normally be hidden."] = "Die Dauer der Animation in Sekunden. Die Endanimation erscheint erst zum Zeitpunkt des Ausblendens."
	--[[Translation missing --]]
	L["The group and all direct children will share the same base frame level."] = "The group and all direct children will share the same base frame level."
	--[[Translation missing --]]
	L["The Multi Target mode is less reliable and not recommended."] = "The Multi Target mode is less reliable and not recommended."
	--[[Translation missing --]]
	L["The Multi Target mode requires a name or spell id filter"] = "The Multi Target mode requires a name or spell id filter"
	--[[Translation missing --]]
	L["The trigger number is optional. When no trigger number is specified, the trigger selected via dynamic information will be used."] = "The trigger number is optional. When no trigger number is specified, the trigger selected via dynamic information will be used."
	L["The type of trigger"] = "Auslösertyp"
	--[[Translation missing --]]
	L["The KUIAR_Runtime Options Addon version %s doesn't match the KUIAR_Runtime version %s. If you updated the addon while the game was running, try restarting World of Warcraft. Otherwise try reinstalling KUIAR_Runtime"] = "The KUIAR_Runtime Options Addon version %s doesn't match the KUIAR_Runtime version %s. If you updated the addon while the game was running, try restarting World of Warcraft. Otherwise try reinstalling KUIAR_Runtime"
	L["Then "] = "Dann"
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
	L["This display is currently loaded"] = "Diese Anzeige ist momentan geladen"
	L["This display is not currently loaded"] = "Diese Anzeige ist momentan nicht geladen"
	--[[Translation missing --]]
	L["This display is on standby, it will be loaded when needed."] = "This display is on standby, it will be loaded when needed."
	--[[Translation missing --]]
	L["This enables the collection of debug logs. Custom code can add debug information to the log through the function DebugPrint."] = "This enables the collection of debug logs. Custom code can add debug information to the log through the function DebugPrint."
	--[[Translation missing --]]
	L["This is a modified version of your aura, |cff9900FF%s.|r"] = "This is a modified version of your aura, |cff9900FF%s.|r"
	--[[Translation missing --]]
	L["This is a modified version of your group: |cff9900FF%s|r"] = "This is a modified version of your group: |cff9900FF%s|r"
	L["This region of type \"%s\" is not supported."] = "Diese Region des Typs \"%s\" wird nicht unterstützt."
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
	L["Time in"] = "Zeit in"
	L["Tiny Icon"] = "Winziges Symbol"
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
	L["Toggle the visibility of all loaded displays"] = "Sichtbarkeit aller geladener Anzeigen umschalten"
	L["Toggle the visibility of all non-loaded displays"] = "Sichtbarkeit aller nicht geladener Anzeigen umschalten"
	L["Toggle the visibility of this display"] = "Die Sichtbarkeit dieser Anzeige umschalten"
	L["Tooltip Content"] = "Tooltip Inhalt"
	L["Tooltip on Mouseover"] = "Tooltip bei Mausberührung"
	--[[Translation missing --]]
	L["Tooltip Pattern Match"] = "Tooltip Pattern Match"
	L["Tooltip Text"] = "Tooltip Text"
	L["Tooltip Value"] = "Tooltip Wert"
	L["Tooltip Value #"] = "Tooltip Wert #"
	L["Top HUD position"] = "Höchste HUD Position"
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
	L["Ungroup"] = "Gruppierung aufheben"
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
	L["Unlike the start or finish animations, the main animation will loop over and over until the display is hidden."] = "Anders als die Start- und Endanimation wird die Hauptanimation immer wieder wiederholt, bis die Anzeige in den Endstatus versetzt wird."
	--[[Translation missing --]]
	L["Update"] = "Update"
	--[[Translation missing --]]
	L["Update Auras"] = "Update Auras"
	L["Update Custom Text On..."] = "Aktualisiere benutzerdefinierten Text bei..."
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
	L["Values:"] = "Werte:"
	L["Version: "] = "Version:"
	--[[Translation missing --]]
	L["Version: %s"] = "Version: %s"
	L["Vertical Align"] = "Vertikale Ausrichtung"
	L["Vertical Bar"] = "Vertikaler Balken"
	L["View"] = "Ansicht"
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
	L["X Offset"] = "X-Versatz"
	L["X Rotation"] = "X-Rotation"
	L["X Scale"] = "Skalierung (X)"
	--[[Translation missing --]]
	L["x-Offset"] = "x-Offset"
	L["Y Offset"] = "Y-Versatz"
	L["Y Rotation"] = "Y-Rotation"
	L["Y Scale"] = "Skalierung (Y)"
	L["Yellow Rune"] = "Gelbe Rune"
	--[[Translation missing --]]
	L["y-Offset"] = "y-Offset"
	--[[Translation missing --]]
	L["You already have this group/aura. Importing will create a duplicate."] = "You already have this group/aura. Importing will create a duplicate."
	L["You are about to delete %d aura(s). |cFFFF0000This cannot be undone!|r Would you like to continue?"] = "Du bist im Begriff %d Aura/Auren zu löschen. |cFFFF0000Das Löschen kann nicht rückgängig gemacht werden!|r Willst du fortfahren?"
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
	L["Z Offset"] = "Z-Versatz"
	L["Z Rotation"] = "Z-Rotation"
	L["Zoom In"] = "Einzoomen"
	L["Zoom Out"] = "Auszoomen"

-- KUI: translations added for strings upstream leaves in English (2026-11-12).
L["-- Do not remove this comment, it is part of this aura: "] = "-- Diesen Kommentar nicht entfernen, er gehört zu dieser Aura:"
L["%s - %i. Trigger"] = "%s - %i. Auslöser"
L["%s - OnLoad"] = "%s - Beim Laden"
L["%s - OnUnload"] = "%s - Beim Entladen"
L["|cFFFF0000Automatic|r length"] = "|cFFFF0000Automatische|r Länge"
L["|cFFFF0000default|r texture"] = "|cFFFF0000Standard|r-Textur"
L["|cFFFF0000desaturated|r "] = "|cFFFF0000entsättigt|r "
L["|cFFFF0000Note:|r The unit '%s' is not a trackable unit."] = "|cFFFF0000Hinweis:|r Die Einheit '%s' ist keine verfolgbare Einheit."
L["|cFFFF0000Note:|r The unit '%s' requires soft target cvars to be enabled."] = "|cFFFF0000Hinweis:|r Die Einheit '%s' erfordert aktivierte Soft-Target-CVars."
L["|cFFffcc00Anchors:|r Anchored |cFFFF0000%s|r to frame's |cFFFF0000%s|r"] = "|cFFffcc00Anker:|r |cFFFF0000%s|r am |cFFFF0000%s|r des Rahmens verankert"
L["|cFFffcc00Anchors:|r Anchored |cFFFF0000%s|r to frame's |cFFFF0000%s|r with offset |cFFFF0000%s/%s|r"] = "|cFFffcc00Anker:|r |cFFFF0000%s|r am |cFFFF0000%s|r des Rahmens verankert mit Versatz |cFFFF0000%s/%s|r"
L["|cFFffcc00Anchors:|r Anchored to frame's |cFFFF0000%s|r"] = "|cFFffcc00Anker:|r Verankert am |cFFFF0000%s|r des Rahmens"
L["|cFFffcc00Anchors:|r Anchored to frame's |cFFFF0000%s|r with offset |cFFFF0000%s/%s|r"] = "|cFFffcc00Anker:|r Verankert am |cFFFF0000%s|r des Rahmens mit Versatz |cFFFF0000%s/%s|r"
L["|cFFffcc00Extra Options:|r"] = "|cFFffcc00Zusatzoptionen:|r"
L["|cFFffcc00Extra:|r %s and %s %s"] = "|cFFffcc00Zusatz:|r %s und %s %s"
L["|cFFffcc00Font Flags:|r |cFFFF0000%s|r and shadow |c%sColor|r with offset |cFFFF0000%s/%s|r%s%s"] = "|cFFffcc00Schrift-Flags:|r |cFFFF0000%s|r und Schatten |c%sFarbe|r mit Versatz |cFFFF0000%s/%s|r%s%s"
L["|cFFffcc00Font Flags:|r |cFFFF0000%s|r and shadow |c%sColor|r with offset |cFFFF0000%s/%s|r%s%s%s"] = "|cFFffcc00Schrift-Flags:|r |cFFFF0000%s|r und Schatten |c%sFarbe|r mit Versatz |cFFFF0000%s/%s|r%s%s%s"
L["|cffffcc00Format Options|r"] = "|cffffcc00Formatoptionen|r"
L["• |cff00ff00Player|r, |cff00ff00Target|r, |cff00ff00Focus|r, and |cff00ff00Pet|r correspond directly to those individual unitIDs.\n• |cff00ff00Specific Unit|r lets you provide a specific valid unitID to watch.\n|cffff0000Note|r: The game will not fire events for all valid unitIDs, making some untrackable by this trigger.\n• |cffffff00Party|r, |cffffff00Raid|r, |cffffff00Boss|r, |cffffff00Arena|r, and |cffffff00Nameplate|r can match multiple corresponding unitIDs.\n• |cffffff00Smart Group|r adjusts to your current group type, matching just the \"player\" when solo, \"party\" units (including \"player\") in a party or \"raid\" units in a raid.\n• |cffffff00Multi-target|r attempts to use the Combat Log events, rather than unitID, to track affected units.\n|cffff0000Note|r: Without a direct relationship to actual unitIDs, results may vary.\n\n|cffffff00*|r Yellow Unit settings can match multiple units and will default to being active even while no affected units are found without a Unit Count or Match Count setting."] = "• |cff00ff00Spieler|r, |cff00ff00Ziel|r, |cff00ff00Fokus|r und |cff00ff00Begleiter|r entsprechen direkt diesen einzelnen Einheiten-IDs.\n• |cff00ff00Bestimmte Einheit|r lässt dich eine bestimmte gültige Einheiten-ID zur Beobachtung angeben.\n|cffff0000Hinweis|r: Das Spiel löst nicht für alle gültigen Einheiten-IDs Ereignisse aus, sodass manche von diesem Auslöser nicht verfolgt werden können.\n• |cffffff00Gruppe|r, |cffffff00Schlachtzug|r, |cffffff00Boss|r, |cffffff00Arena|r und |cffffff00Namensplakette|r können mehrere entsprechende Einheiten-IDs treffen.\n• |cffffff00Intelligente Gruppe|r passt sich deinem aktuellen Gruppentyp an: allein nur \"player\", in einer Gruppe die \"party\"-Einheiten (inklusive \"player\"), in einem Schlachtzug die \"raid\"-Einheiten.\n• |cffffff00Mehrfachziel|r versucht, statt der Einheiten-ID die Kampflog-Ereignisse zu nutzen, um betroffene Einheiten zu verfolgen.\n|cffff0000Hinweis|r: Ohne direkten Bezug zu echten Einheiten-IDs können die Ergebnisse variieren.\n\n|cffffff00*|r Gelbe Einheiteneinstellungen können mehrere Einheiten treffen und sind standardmäßig aktiv, auch wenn keine betroffenen Einheiten gefunden werden, solange keine Einheiten- oder Trefferanzahl gesetzt ist."
L["A timer will automatically be displayed according to default Interface Settings (overridden by some addons).\nEnable this setting if you want this timer to be hidden, or when using a KUIAR_Runtime text to display the timer"] = "Ein Timer wird automatisch gemäß den Standard-Interface-Einstellungen angezeigt (von manchen Addons überschrieben).\nAktiviere diese Einstellung, wenn dieser Timer ausgeblendet werden soll oder wenn du einen KUIAR_Runtime-Text zur Anzeige des Timers verwendest"
L["A Unit ID (e.g., party1)."] = "Eine Einheiten-ID (z. B. party1)."
L["Active Aura Filters and Info"] = "Aktive Aurenfilter und Infos"
L["Actual Spec"] = "Aktuelle Spezialisierung"
L["Add Extra Elements"] = "Zusätzliche Elemente hinzufügen"
L["Add Snippet"] = "Snippet hinzufügen"
L["Additional Events"] = "Zusätzliche Ereignisse"
L["Affected Unit Filters and Info"] = "Filter und Infos zur betroffenen Einheit"
L["All maintainers of the libraries we use, especially:"] = "Alle Betreuer der von uns verwendeten Bibliotheken, besonders:"
L["Allow Full Rotation"] = "Volle Drehung erlauben"
L["Anchor Mode"] = "Ankermodus"
L["and %s"] = "und %s"
L["And our Patreons, Discord Regulars and Subscribers, and Friends of the Addon:"] = "Und unsere Patreons, Discord-Stammgäste und Abonnenten sowie Freunde des Addons:"
L["and with width |cFFFF0000%s|r and %s"] = "und mit Breite |cFFFF0000%s|r und %s"
L["Angle Between Auras"] = "Winkel zwischen Auren"
L["Animation End"] = "Animationsende"
L["Animation Start"] = "Animationsbeginn"
L["Any of"] = "Eines von"
L["Area"] = "Bereich"
L["At a position a bit left of Left HUD position."] = "An einer Position etwas links von der Position der linken HUD."
L["At a position a bit left of Right HUD position"] = "An einer Position etwas links von der Position der rechten HUD"
L["Attach to Foreground"] = "Im Vordergrund anheften"
L["Aura is\nOff Screen"] = "Aura ist\nAußerhalb des Bildschirms"
L["Aura Order"] = "Aurenreihenfolge"
L["Aura received from: %s"] = "Aura erhalten von: %s"
L["Auto-Clone (Show All Matches)"] = "Automatisch klonen (alle Treffer anzeigen)"
L["Automatic length"] = "Automatische Länge"
L["Backdrop in Front"] = "Hintergrund vorne"
L["Background Inner"] = "Innerer Hintergrund"
L["Border Anchor"] = "Randanker"
L["Border in Front"] = "Rand vorne"
L["Bracket Matching"] = "Klammerabgleich"
L["Browse Wago, the largest collection of auras."] = "Durchsuche Wago, die größte Sammlung von Auren."
L["By default this shows the information from the trigger selected via dynamic information. The information from a specific trigger can be shown via e.g. %2.p."] = "Standardmäßig zeigt dies die Informationen des über die dynamischen Informationen gewählten Auslösers. Die Informationen eines bestimmten Auslösers lassen sich z. B. mit %2.p anzeigen."
L["Can be a UID (e.g., party1)."] = "Kann eine UID sein (z. B. party1)."
L["Can set to 0 if Columns * Width equal File Width"] = "Kann auf 0 gesetzt werden, wenn Spalten * Breite der Dateibreite entspricht"
L["Can set to 0 if Rows * Height equal File Height"] = "Kann auf 0 gesetzt werden, wenn Zeilen * Höhe der Dateihöhe entspricht"
L["Case Insensitive"] = "Groß-/Kleinschreibung ignorieren"
L["Cast by a Player Character"] = "Von einem Spielercharakter gewirkt"
L["Categories to Update"] = "Zu aktualisierende Kategorien"
L["Changelog"] = "Änderungsprotokoll"
L["Chat with KUIAR_Runtime experts on our Discord server."] = "Chatte mit KUIAR_Runtime-Experten auf unserem Discord-Server."
L["Check out our wiki for a large collection of examples and snippets."] = "Sieh dir unser Wiki mit einer großen Sammlung von Beispielen und Snippets an."
L["Circular Texture %s"] = "Kreisförmige Textur %s"
L["Clear Debug Logs"] = "Debug-Protokolle löschen"
L["Clear Saved Data"] = "Gespeicherte Daten löschen"
L["Click to replace the name with %s."] = "Klicke, um den Namen durch %s zu ersetzen."
L["Clip Overlays"] = "Überlagerungen abschneiden"
L["Clipped by Foreground"] = "Vom Vordergrund abgeschnitten"
L["Code Editor"] = "Code-Editor"
L["Collapse all pending Import"] = "Alle ausstehenden Importe einklappen"
L["Collapsible Group"] = "Einklappbare Gruppe"
L["Columns"] = "Spalten"
L["COMBAT_LOG_EVENT_UNFILTERED with no filter can trigger frame drops in raid environment."] = "COMBAT_LOG_EVENT_UNFILTERED ohne Filter kann in Schlachtzugsumgebungen zu Einbrüchen der Bildrate führen."
L["Combine Matches Per Unit"] = "Treffer pro Einheit zusammenfassen"
L["Common Text"] = "Allgemeiner Text"
L["Compare against the number of units affected."] = "Mit der Anzahl der betroffenen Einheiten vergleichen."
L["Compatibility Options"] = "Kompatibilitätsoptionen"
L["Configure what options appear on this panel."] = "Lege fest, welche Optionen in diesem Bereich erscheinen."
L["Cooldown Numbers might be added by WoW. You can configure these in the game settings."] = "Abklingzeit-Zahlen können von WoW hinzugefügt werden. Du kannst sie in den Spieleinstellungen konfigurieren."
L["Could not parse '%s'. Expected a table."] = "'%s' konnte nicht ausgewertet werden. Eine Tabelle wurde erwartet."
L["Counts the number of matches over all units."] = "Zählt die Anzahl der Treffer über alle Einheiten."
L["Counts the number of matches per unit."] = "Zählt die Anzahl der Treffer pro Einheit."
L["Create a Copy"] = "Kopie erstellen"
L["Custom - Allows you to define a custom Lua function that returns a list of string values. %c1 will be replaced by the first value returned, %c2 by the second, etc."] = "Benutzerdefiniert - Ermöglicht dir, eine eigene Lua-Funktion zu definieren, die eine Liste von Zeichenfolgen zurückgibt. %c1 wird durch den ersten zurückgegebenen Wert ersetzt, %c2 durch den zweiten usw."
L["Custom Code Viewer"] = "Betrachter für benutzerdefinierten Code"
L["Custom Frames"] = "Benutzerdefinierte Rahmen"
L["Custom Functions"] = "Benutzerdefinierte Funktionen"
L["Custom Init"] = "Benutzerdefinierte Initialisierung"
L["Custom Load"] = "Benutzerdefiniertes Laden"
L["Custom Options"] = "Benutzerdefinierte Optionen"
L["Custom Text Update Throttle"] = "Drosselung der benutzerdefinierten Textaktualisierung"
L["Custom trigger Update Throttle"] = "Drosselung der Aktualisierung des benutzerdefinierten Auslösers"
L["Custom Trigger: Ignore Lua Errors on OPTIONS event"] = "Benutzerdefinierter Auslöser: Lua-Fehler beim Ereignis OPTIONS ignorieren"
L["Custom Trigger: Send fake events instead of STATUS event"] = "Benutzerdefinierter Auslöser: Falsche Ereignisse statt des Ereignisses STATUS senden"
L["Custom Unload"] = "Benutzerdefiniertes Entladen"
L["Debug Log"] = "Debug-Protokoll"
L["Debug Log:"] = "Debug-Protokoll:"
L["Deleting auras: "] = "Auren werden gelöscht:"
L["Determines how many entries can be in the table."] = "Legt fest, wie viele Einträge in der Tabelle stehen können."
L["Disallow Entry Reordering"] = "Neuanordnung von Einträgen verbieten"
L["Do you want to enable updates for this aura"] = "Möchtest du Aktualisierungen für diese Aura aktivieren"
L["Do you want to ignore updates for this aura"] = "Möchtest du Aktualisierungen für diese Aura ignorieren"
L["Dynamic Duration"] = "Dynamische Dauer"
L["Dynamic Group Settings"] = "Einstellungen der dynamischen Gruppe"
L["Dynamic Text Replacements"] = "Dynamische Textersetzungen"
L["Ease Strength"] = "Stärke der Sanftheit"
L["Ease type"] = "Art der Sanftheit"
L["eliding"] = "Kürzung"
L["Else If"] = "Sonst wenn"
L["Else If %s"] = "Sonst wenn %s"
L["Empty Base Region"] = "Leere Basisregion"
L["Enable \"Edge\" part of the overlay"] = "Den \"Rand\"-Teil der Überlagerung aktivieren"
L["Enable \"swipe\" part of the overlay"] = "Den \"Wisch\"-Teil der Überlagerung aktivieren"
L["Enable Debug Log"] = "Debug-Protokoll aktivieren"
L["Enable Debug Logging"] = "Debug-Protokollierung aktivieren"
L["Enable Gradient"] = "Farbverlauf aktivieren"
L["Enable Swipe"] = "Wisch aktivieren"
L["Enable the \"Swipe\" radial overlay"] = "Die radiale \"Wisch\"-Überlagerung aktivieren"
L["End of %s"] = "Ende von %s"
L["Enemy nameplate(s) found"] = "Feindliche Namensplakette(n) gefunden"
L["Enter a Spell ID. You can use the addon idTip to determine spell ids."] = "Gib eine Zauber-ID ein. Mit dem Addon idTip kannst du Zauber-IDs ermitteln."
L["Enter an Aura Name, partial Aura Name, or Spell ID. A Spell ID will match any spells with the same name."] = "Gib einen Aura-Namen, einen Teil eines Aura-Namens oder eine Zauber-ID ein. Eine Zauber-ID passt auf alle Zauber mit demselben Namen."
L["Enter Author Mode"] = "Autorenmodus betreten"
L["Enter in a value for the tick's placement."] = "Gib einen Wert für die Platzierung der Markierung ein."
L["Enter static or relative values with %"] = "Gib statische oder relative Werte mit % ein"
L["Enter User Mode"] = "Benutzermodus betreten"
L["Enter user mode."] = "Benutzermodus betreten."
L["Exact Item Match"] = "Exakte Gegenstandsübereinstimmung"
L["Expand all pending Import"] = "Alle ausstehenden Importe ausklappen"
L["Export debug table..."] = "Debug-Tabelle exportieren..."
L["Export..."] = "Exportieren..."
L["Exporting"] = "Exportiere"
L["Extra Height"] = "Zusätzliche Höhe"
L["Extra Width"] = "Zusätzliche Breite"
L["Fadeout Sound"] = "Ausblendsound"
L["Fadeout Time (seconds)"] = "Ausblenddauer (Sekunden)"
L["Fetch Affected/Unaffected Names and Units"] = "Namen und Einheiten der Betroffenen/Nichtbetroffenen abrufen"
L["Fetch Raid Mark Information"] = "Schlachtzugsmarkierungsinfo abrufen"
L["Fetch Role Information"] = "Rolleninfo abrufen"
L["Fetch Tooltip Information"] = "Tooltip-Informationen abrufen"
L["File Height"] = "Dateihöhe"
L["File Width"] = "Dateibreite"
L["Filter based on the spell Name string."] = "Nach der Zeichenfolge des Zaubernamens filtern."
L["Filter by Arena Spec"] = "Nach Arena-Spezialisierung filtern"
L["Filter by Hostility"] = "Nach Feindseligkeit filtern"
L["Filter by Npc ID"] = "Nach NPC-ID filtern"
L["Filter by Specialization"] = "Nach Spezialisierung filtern"
L["Filter by Unit Name"] = "Nach Einheitennamen filtern"
L["Filter formats: 'Name', 'Name-Realm', '-Realm'.\n\nSupports multiple entries, separated by commas\nCan use \\ to escape -."] = "Filterformate: 'Name', 'Name-Realm', '-Realm'.\n\nUnterstützt mehrere Einträge, durch Kommas getrennt\nMit \\ kann - maskiert werden."
L["Filter to only dispellable de/buffs of the given type(s)\nBleed classification via LibDispel"] = "Nur bannbare Stärkungs-/Schwächungszauber des angegebenen Typs filtern\nBlutungsklassifizierung über LibDispel"
L["Finishing..."] = "Abschließen..."
L["Flat Framelevels"] = "Flache Rahmenebenen"
L["Format for %s"] = "Format für %s"
L["Found a Bug?"] = "Einen Fehler gefunden?"
L["Frame"] = "Rahmen"
L["Frame Count"] = "Frame-Anzahl"
L["Frame Height"] = "Fensterhöhe"
L["Frame Rate"] = "Bildrate"
L["Frame Width"] = "Fensterbreite"
L["Full Bar"] = "Volle Leiste"
L["Full Circle"] = "Voller Kreis"
L["Glow Anchor"] = "Leuchten-Anker"
L["Glow Frame Type"] = "Rahmentyp des Leuchtens"
L["Grid direction"] = "Rasterrichtung"
L["Group Alpha"] = "Gruppen-Alpha"
L["Group and anchor each auras by frame.\n\n- Nameplates: attach to nameplates per unit.\n- Unit Frames: attach to unit frame buttons per unit.\n- Custom Frames: choose which frame each region should be anchored to."] = "Gruppiere und verankere jede Aura nach Rahmen.\n\n- Namensplaketten: pro Einheit an Namensplaketten anheften.\n- Einheitenrahmen: pro Einheit an Einheitenrahmen-Buttons anheften.\n- Benutzerdefinierte Rahmen: wähle, an welchen Rahmen jede Region verankert wird."
L["Group by Frame"] = "Nach Rahmen gruppieren"
L["Group Description"] = "Gruppenbeschreibung"
L["Group Options"] = "Gruppenoptionen"
L["Group player(s) found"] = "Gruppenspieler gefunden"
L["Group Settings"] = "Gruppeneinstellungen"
L["Hide After"] = "Ausblenden nach"
L["Hide Background"] = "Hintergrund ausblenden"
L["Hide Glows applied by this aura"] = "Von dieser Aura angewendete Leuchteffekte ausblenden"
L["Highlights"] = "Hervorhebungen"
L["Hybrid Position"] = "Hybrid-Position"
L["Hybrid Sort Mode"] = "Hybrid-Sortiermodus"
L["Icon - The icon associated with the display"] = "Symbol - Das mit der Anzeige verbundene Symbol"
L["Icon Picker"] = "Symbolauswahl"
L["Icon Position"] = "Symbolposition"
L["Icon Settings"] = "Symboleinstellungen"
L["Icon Source"] = "Symbolquelle"
L["If %s"] = "Wenn %s"
L["If checked, then the combo box in the User settings will be sorted."] = "Wenn aktiviert, wird die Auswahlliste in den Benutzereinstellungen sortiert."
L["If checked, then the user will see a multi line edit box. This is useful for inputting large amounts of text."] = "Wenn aktiviert, sieht der Benutzer ein mehrzeiliges Eingabefeld. Das ist nützlich, um große Textmengen einzugeben."
L["If checked, then this group will not merge with other group when selecting multiple auras."] = "Wenn aktiviert, wird diese Gruppe beim Auswählen mehrerer Auren nicht mit anderen Gruppen zusammengeführt."
L["If checked, then this option group can be temporarily collapsed by the user."] = "Wenn aktiviert, kann der Benutzer diese Optionsgruppe vorübergehend einklappen."
L["If checked, then this option group will start collapsed."] = "Wenn aktiviert, beginnt diese Optionsgruppe eingeklappt."
L["If checked, then this separator will include text. Otherwise, it will be just a horizontal line."] = "Wenn aktiviert, enthält dieser Trenner Text. Andernfalls ist er nur eine horizontale Linie."
L["If checked, then this space will span across multiple lines."] = "Wenn aktiviert, erstreckt sich dieser Abstand über mehrere Zeilen."
L["If unchecked, then a default color will be used (usually yellow)"] = "Wenn deaktiviert, wird eine Standardfarbe verwendet (meist gelb)"
L["If unchecked, then this space will fill the entire line it is on in User Mode."] = "Wenn deaktiviert, füllt dieser Abstand im Benutzermodus die gesamte Zeile aus, in der er steht."
L["Ignore out of casting range"] = "Außerhalb der Zauberreichweite ignorieren"
L["Ignore Wago updates"] = "Wago-Aktualisierungen ignorieren"
L["Ignored Aura Name"] = "Ignorierter Aura-Name"
L["Ignored Exact Spell ID(s)"] = "Ignorierte exakte Zauber-ID(s)"
L["Ignored Name(s)"] = "Ignorierte Namen"
L["Ignored Spell ID"] = "Ignorierte Zauber-ID"
L["Import as Copy"] = "Als Kopie importieren"
L["Import has no UID, cannot be matched to existing auras."] = "Der Import hat keine UID und kann nicht mit vorhandenen Auren abgeglichen werden."
L["Importing"] = "Importiere"
L["Importing %s"] = "Importiere %s"
L["Importing a group with %s child auras."] = "Eine Gruppe mit %s untergeordneten Auren wird importiert."
L["Importing a stand-alone aura."] = "Eine eigenständige Aura wird importiert."
L["Importing...."] = "Importiere...."
L["Incompatible changes to group region types detected"] = "Inkompatible Änderungen an den Regionstypen der Gruppe erkannt"
L["Incompatible changes to group structure detected"] = "Inkompatible Änderungen an der Gruppenstruktur erkannt"
L["Indent Size"] = "Einzugsgröße"
L["Inner"] = "Innen"
L["Insert text replacement codes to make text dynamic."] = "Füge Textersetzungscodes ein, um den Text dynamisch zu machen."
L["Invalid Item ID"] = "Ungültige Gegenstands-ID"
L["Invalid target aura"] = "Ungültige Zielaura"
L["Invalid type for '%s'. Expected 'bool', 'number', 'select', 'string', 'timer' or 'elapsedTimer'."] = "Ungültiger Typ für '%s'. Erwartet wurde 'bool', 'number', 'select', 'string', 'timer' oder 'elapsedTimer'."
L["Invalid type for property '%s' in '%s'. Expected '%s'"] = "Ungültiger Typ für die Eigenschaft '%s' in '%s'. Erwartet wurde '%s'"
L["Inverse Slant"] = "Neigung umkehren"
L["Invert the direction of progress"] = "Fortschrittsrichtung umkehren"
L["Is Boss Debuff"] = "Ist Boss-Schwächungszauber"
L["Is Unit"] = "Ist Einheit"
L["Keep Aspect Ratio"] = "Seitenverhältnis beibehalten"
L["Keep your Wago imports up to date with the Companion App."] = "Halte deine Wago-Importe mit der Companion-App aktuell."
L["Large Input"] = "Große Eingabe"
L["Left 2 HUD position"] = "Position der linken HUD 2"
L["Length of |cFFFF0000%s|r"] = "Länge von |cFFFF0000%s|r"
L["Limit"] = "Begrenzen"
L["Line"] = "Linie"
L["Linear Texture %s"] = "Lineare Textur %s"
L["Linked aura: "] = "Verknüpfte Aura:"
L["Linked Auras"] = "Verknüpfte Auren"
L["Loaded/Standby"] = "Geladen/Bereit"
L["Lock Positions"] = "Positionen sperren"
L["Magnetically Align"] = "Magnetisch ausrichten"
L["Manual with %i/%i"] = "Manuell mit %i/%i"
L["Matches %s spells"] = "Passt auf %s Zauber"
L["Matches the height setting of a horizontal bar or width for a vertical bar."] = "Entspricht der Höheneinstellung einer horizontalen Leiste oder der Breite einer vertikalen Leiste."
L["Max Length"] = "Maximale Länge"
L["Media Type"] = "Medientyp"
L["Model %s"] = "Modell %s"
L["Model Picker"] = "Modellauswahl"
L["Model Settings"] = "Modelleinstellungen"
L["ModelPaths could not be loaded, the addon is %s"] = "ModelPaths konnte nicht geladen werden, das Addon ist %s"
L["Move Into Above Group"] = "In obere Gruppe verschieben"
L["Move Into Below Group"] = "In untere Gruppe verschieben"
L["Moving auras: "] = "Auren werden verschoben:"
L["Must be a power of 2"] = "Muss eine Zweierpotenz sein"
L["Name - The name of the display (usually an aura name), or the display's ID if there is no dynamic name"] = "Name - Der Name der Anzeige (meist ein Aura-Name) oder die ID der Anzeige, wenn es keinen dynamischen Namen gibt"
L["Name Pattern Match"] = "Namensmuster-Übereinstimmung"
L["New Template"] = "Neue Vorlage"
L["No Logs saved."] = "Keine Protokolle gespeichert."
L["Not a table"] = "Keine Tabelle"
L["Note: Automated Messages to SAY and YELL are blocked outside of Instances."] = "Hinweis: Automatische Nachrichten an SAGEN und SCHREIEN werden außerhalb von Instanzen blockiert."
L["Note: This progress source does not provide a total value/duration. A total value/duration must be set via \"Set Maximum Progress\""] = "Hinweis: Diese Fortschrittsquelle liefert keinen Gesamtwert bzw. keine Gesamtdauer. Ein Gesamtwert bzw. eine Gesamtdauer muss über \"Maximalen Fortschritt festlegen\" gesetzt werden"
L["Number of Entries"] = "Anzahl der Einträge"
L["Occurrence of the event, reset when aura is unloaded\nCan be a range of values\nCan have multiple values separated by a comma or a space\n\nExamples:\n2nd 5th and 6th events: 2, 5, 6\n2nd to 6th: 2-6\nevery 2 events: /2\nevery 3 events starting from 2nd: 2/3\nevery 3 events starting from 2nd and ending at 11th: 2-11/3"] = "Auftreten des Ereignisses, wird beim Entladen der Aura zurückgesetzt\nKann ein Wertebereich sein\nKann mehrere Werte enthalten, getrennt durch Komma oder Leerzeichen\n\nBeispiele:\n2., 5. und 6. Ereignis: 2, 5, 6\n2. bis 6.: 2-6\njedes 2. Ereignis: /2\njedes 3. Ereignis ab dem 2.: 2/3\njedes 3. Ereignis ab dem 2. bis zum 11.: 2-11/3"
L["OFF"] = "AUS"
L["Offer a guided way to create auras for your character"] = "Bietet eine geführte Möglichkeit, Auren für deinen Charakter zu erstellen"
L["Offset by |cFFFF0000%s|r/|cFFFF0000%s|r"] = "Um |cFFFF0000%s|r/|cFFFF0000%s|r versetzt"
L["Offset by 1px"] = "Um 1 px versetzt"
L["ON"] = "AN"
L["Only Match auras cast by a player (not an npc)"] = "Nur Auren von Spielern (nicht von NPCs) berücksichtigen"
L["Only match auras cast by people other than the player or their pet"] = "Nur Auren berücksichtigen, die von anderen als dem Spieler oder seinem Begleiter gewirkt wurden"
L["Only match auras cast by the player or their pet"] = "Nur Auren berücksichtigen, die vom Spieler oder seinem Begleiter gewirkt wurden"
L["Option key"] = "Optionsschlüssel"
L["Option Type"] = "Optionstyp"
L["Options will open after combat ends."] = "Die Optionen werden nach Ende des Kampfes geöffnet."
L["or %s"] = "oder %s"
L["Our translators (too many to name)"] = "Unsere Übersetzer (zu viele, um sie zu nennen)"
L["Outer"] = "Außen"
L["Overflow"] = "Überlauf"
L["Overlay %s Info"] = "Info zu Überlagerung %s"
L["Overlays"] = "Überlagerungen"
L["Paste Action Settings"] = "Aktionseinstellungen einfügen"
L["Paste Animations Settings"] = "Animationseinstellungen einfügen"
L["Paste Author Options Settings"] = "Einstellungen der Autorenoptionen einfügen"
L["Paste Condition Settings"] = "Bedingungseinstellungen einfügen"
L["Paste Custom Configuration"] = "Eigene Konfiguration einfügen"
L["Paste Display Settings"] = "Anzeigeeinstellungen einfügen"
L["Paste Group Settings"] = "Gruppeneinstellungen einfügen"
L["Paste Load Settings"] = "Ladeeinstellungen einfügen"
L["Paste Settings"] = "Einstellungen einfügen"
L["Paste Trigger Settings"] = "Auslösereinstellungen einfügen"
L["Places a tick on the bar"] = "Setzt eine Markierung auf der Leiste"
L["Player Spells found:"] = "Gefundene Spielerzauber:"
L["Position and Size Settings"] = "Positions- und Größeneinstellungen"
L["Preferred Match"] = "Bevorzugter Treffer"
L["Premade Auras"] = "Vorgefertigte Auren"
L["Premade Snippets"] = "Vorgefertigte Snippets"
L["Preparing auras: "] = "Auren werden vorbereitet: "
L["Press Ctrl+C to copy the URL"] = "Drücke Strg+C, um die URL zu kopieren"
L["Prevent Merging"] = "Zusammenführen verhindern"
L["Progress - The remaining time of a timer, or a non-timer value"] = "Fortschritt – Die verbleibende Zeit eines Timers oder ein Wert ohne Timer"
L["Progress Bar Settings"] = "Fortschrittsbalken-Einstellungen"
L["Progress Settings"] = "Fortschrittseinstellungen"
L["Progress Texture Settings"] = "Fortschrittstextur-Einstellungen"
L["Range in yards"] = "Reichweite in Metern"
L["Ready for Install"] = "Bereit zur Installation"
L["Ready for Update"] = "Bereit zur Aktualisierung"
L["Reciprocal TRIGGER:# requests will be ignored!"] = "Wechselseitige TRIGGER:#-Anfragen werden ignoriert!"
L["Redo"] = "Wiederholen"
L["Regions of type \"%s\" are not supported."] = "Regionen vom Typ „%s“ werden nicht unterstützt."
L["Remove All Sounds"] = "Alle Sounds entfernen"
L["Remove All Text To Speech"] = "Alle Text-zu-Sprache-Einstellungen entfernen"
L["Report bugs on our issue tracker."] = "Melde Fehler in unserem Issue-Tracker."
L["Require unit from trigger"] = "Einheit vom Auslöser erforderlich"
L["Requires LibSpecialization, that is e.g. a up-to date KUIAR_Runtime version"] = "Erfordert LibSpecialization, z. B. eine aktuelle KUIAR_Runtime-Version"
L["Reset all options to their default values."] = "Alle Optionen auf ihre Standardwerte zurücksetzen."
L["Right 2 HUD position"] = "Rechte 2 HUD-Position"
L["Rows"] = "Zeilen"
L["Run on..."] = "Ausführen bei ..."
L["Same texture as Foreground"] = "Gleiche Textur wie Vordergrund"
L["Saved Data"] = "Gespeicherte Daten"
L["Scale Factor"] = "Skalierungsfaktor"
L["Search API"] = "API durchsuchen"
L["Select Talent"] = "Talent auswählen"
L["Selected Frame"] = "Ausgewählter Rahmen"
L["Separator Text"] = "Trenntext"
L["Separator text"] = "Trenntext"
L["Set Maximum Progress"] = "Maximalen Fortschritt festlegen"
L["Set Minimum Progress"] = "Minimalen Fortschritt festlegen"
L["Set Parent to Anchor"] = "Übergeordnetes Element auf Anker setzen"
L["Set Thumbnail Icon"] = "Vorschausymbol festlegen"
L["Sets the anchored frame as the aura's parent, causing the aura to inherit attributes such as visibility and scale."] = "Setzt den verankerten Rahmen als übergeordnetes Element der Aura, sodass die Aura Eigenschaften wie Sichtbarkeit und Skalierung erbt."
L["Shadow X Offset"] = "Schatten-X-Versatz"
L["Shadow Y Offset"] = "Schatten-Y-Versatz"
L["Show \"Edge\""] = "„Kante“ anzeigen"
L["Show \"Swipe\""] = "„Wischeffekt“ anzeigen"
L["Show and Clone Settings"] = "Anzeige- und Klon-Einstellungen"
L["Show Circular Texture"] = "Kreistextur anzeigen"
L["Show Debug Logs"] = "Debug-Protokolle anzeigen"
L["Show If Unit Does Not Exist"] = "Anzeigen, wenn Einheit nicht existiert"
L["Show Linear Texture"] = "Lineare Textur anzeigen"
L["Show Matches for"] = "Treffer anzeigen für"
L["Show Matches for Units"] = "Treffer anzeigen für Einheiten"
L["Show Model"] = "Modell anzeigen"
L["Show Sound Setting"] = "Soundeinstellung anzeigen"
L["Show Spark"] = "Spark anzeigen"
L["Show Stop Motion"] = "Stop-Motion anzeigen"
L["Show Text"] = "Text anzeigen"
L["Show Text To Speech Setting"] = "Text-zu-Sprache-Einstellung anzeigen"
L["Show Texture"] = "Textur anzeigen"
L["Show Tick"] = "Markierung anzeigen"
L["Shows a border"] = "Zeigt einen Rand"
L["Shows a Circular Progress Texture"] = "Zeigt eine kreisförmige Fortschrittstextur"
L["Shows a glow"] = "Zeigt ein Leuchten"
L["Shows a Linear Progress Texture"] = "Zeigt eine lineare Fortschrittstextur"
L["Shows a model"] = "Zeigt ein Modell"
L["Shows a Stop Motion"] = "Zeigt eine Stop-Motion"
L["Shows a stop motion texture"] = "Zeigt eine Stop-Motion-Textur"
L["Shows a Texture"] = "Zeigt eine Textur"
L["Shows nothing, except sub elements"] = "Zeigt nichts, außer Unterelementen"
L["Slant Amount"] = "Neigungsbetrag"
L["Slant Mode"] = "Neigungsmodus"
L["Slanted"] = "Geneigt"
L["Slider Step Size"] = "Schrittweite des Schiebereglers"
L["Smooth Progress"] = "Fortschritt glätten"
L["Soft Max"] = "Weiches Maximum"
L["Soft Min"] = "Weiches Minimum"
L["Sound Kit ID"] = "Sound-Kit-ID"
L["Specific Currency ID"] = "ID der bestimmten Währung"
L["Spell Selection Filters"] = "Filter zur Zauberauswahl"
L["Spells found:"] = "Gefundene Zauber:"
L["Stacks - The number of stacks of an aura (usually)"] = "Stapel – Die Anzahl der Stapel einer Aura (meistens)"
L["Standby"] = "Bereitschaft"
L["Start Collapsed"] = "Eingeklappt starten"
L["Start of %s"] = "Beginn von %s"
L["Stop Motion %s"] = "Stop-Motion %s"
L["Stop Motion Settings"] = "Stop-Motion-Einstellungen"
L["Stretched by Foreground"] = "Vom Vordergrund gestreckt"
L["Sub Elements"] = "Unterelemente"
L["Sub Option %i"] = "Unteroption %i"
L["Subevent"] = "Unterereignis"
L["Subevent Suffix"] = "Unterereignis-Suffix"
L["Swipe Overlay Settings"] = "Einstellungen der Wischeffekt-Überlagerung"
L["Templates could not be loaded, the addon is %s"] = "Vorlagen konnten nicht geladen werden, das Addon ist %s"
L["Texture %s"] = "Textur %s"
L["Texture Selection Mode"] = "Texturauswahlmodus"
L["Texture Settings"] = "Textureinstellungen"
L["Texture Wrap"] = "Texturumbruch"
L["Texture X Offset"] = "Textur-X-Versatz"
L["Texture Y Offset"] = "Textur-Y-Versatz"
L["Thanks"] = "Danke"
L["The addon ElvUI is enabled. It might add cooldown numbers to the swipe. You can configure these in the ElvUI settings"] = "Das Addon ElvUI ist aktiviert. Es kann dem Wischeffekt Abklingzeit-Zahlen hinzufügen. Du kannst diese in den ElvUI-Einstellungen konfigurieren"
L["The addon OmniCC is enabled. It might add cooldown numbers to the swipe. You can configure these in the OmniCC settings"] = "Das Addon OmniCC ist aktiviert. Es kann dem Wischeffekt Abklingzeit-Zahlen hinzufügen. Du kannst diese in den OmniCC-Einstellungen konfigurieren"
L["The group and all direct children will share the same base frame level."] = "Die Gruppe und alle direkten Kinder teilen sich dieselbe Basis-Rahmenstufe."
L["The Multi Target mode is less reliable and not recommended."] = "Der Mehrfachziel-Modus ist weniger zuverlässig und nicht empfohlen."
L["The Multi Target mode requires a name or spell id filter"] = "Der Mehrfachziel-Modus erfordert einen Namens- oder Zauber-ID-Filter"
L["The trigger number is optional. When no trigger number is specified, the trigger selected via dynamic information will be used."] = "Die Auslösernummer ist optional. Ohne Angabe wird der über die dynamischen Informationen gewählte Auslöser verwendet."
L["The KUIAR_Runtime Options Addon version %s doesn't match the KUIAR_Runtime version %s. If you updated the addon while the game was running, try restarting World of Warcraft. Otherwise try reinstalling KUIAR_Runtime"] = "Die Version %s des KUIAR_Runtime-Optionen-Addons passt nicht zur KUIAR_Runtime-Version %s. Wenn du das Addon während des laufenden Spiels aktualisiert hast, starte World of Warcraft neu. Andernfalls installiere KUIAR_Runtime neu"
L["There are several special codes available to make this text dynamic. Click to view a list with all dynamic text codes."] = "Für diesen Text stehen mehrere Sondercodes zur Verfügung, um ihn dynamisch zu machen. Klicke, um eine Liste aller dynamischen Textcodes anzuzeigen."
L["This adds %raidMark as text replacements."] = "Dies fügt %raidMark als Textersetzung hinzu."
L["This adds %role, %roleIcon as text replacements. Does nothing if the unit is not a group member."] = "Dies fügt %role, %roleIcon als Textersetzungen hinzu. Tut nichts, wenn die Einheit kein Gruppenmitglied ist."
L["This adds %tooltip, %tooltip1, %tooltip2, %tooltip3 and %tooltip4 as text replacements and also allows filtering based on the tooltip content/values."] = "Dies fügt %tooltip, %tooltip1, %tooltip2, %tooltip3 und %tooltip4 als Textersetzungen hinzu und erlaubt auch das Filtern nach Tooltip-Inhalt/-Werten."
L["This aura contains custom Lua code.\nMake sure you can trust the person who sent it!"] = "Diese Aura enthält eigenen Lua-Code.\nStelle sicher, dass du der Person vertrauen kannst, die sie gesendet hat!"
L["This aura is marked as an update to an aura '%s', but cannot be used to update that aura. This usually happens if an aura is moved out of a group."] = "Diese Aura ist als Aktualisierung einer Aura '%s' markiert, kann aber nicht zur Aktualisierung dieser Aura verwendet werden. Das passiert meist, wenn eine Aura aus einer Gruppe verschoben wurde."
L["This aura is marked as an update to auras '%s', but cannot be used to update them. This usually happens if an aura is moved out of a group."] = "Diese Aura ist als Aktualisierung der Auren '%s' markiert, kann aber nicht zu deren Aktualisierung verwendet werden. Das passiert meist, wenn eine Aura aus einer Gruppe verschoben wurde."
L["This aura was created with a different version (%s) of World of Warcraft.\nIt might not work correctly!"] = "Diese Aura wurde mit einer anderen Version (%s) von World of Warcraft erstellt.\nSie funktioniert möglicherweise nicht richtig!"
L["This aura was created with a newer version of KUIAR_Runtime.\nUpgrade your version of KUIAR_Runtime or wait for next release before installing this aura."] = "Diese Aura wurde mit einer neueren Version von KUIAR_Runtime erstellt.\nAktualisiere deine Version von KUIAR_Runtime oder warte auf die nächste Veröffentlichung, bevor du diese Aura installierst."
L["This display is on standby, it will be loaded when needed."] = "Diese Anzeige ist in Bereitschaft und wird bei Bedarf geladen."
L["This enables the collection of debug logs. Custom code can add debug information to the log through the function DebugPrint."] = "Dies aktiviert das Sammeln von Debug-Protokollen. Eigener Code kann über die Funktion DebugPrint Debug-Informationen zum Protokoll hinzufügen."
L["This is a modified version of your aura, |cff9900FF%s.|r"] = "Dies ist eine geänderte Version deiner Aura |cff9900FF%s.|r"
L["This is a modified version of your group: |cff9900FF%s|r"] = "Dies ist eine geänderte Version deiner Gruppe: |cff9900FF%s|r"
L["This setting controls what widget is generated in user mode."] = "Diese Einstellung legt fest, welches Widget im Benutzermodus erzeugt wird."
L["Thumbnail Icon"] = "Vorschausymbol"
L["Tick Area %s"] = "Tickbereich %s"
L["Tick Center %s"] = "Tickmitte %s"
L["Tick Mode"] = "Tickmodus"
L["Tick Placement"] = "Tickplatzierung"
L["To Frame's"] = "Zum Rahmen von"
L["To Group's"] = "Zur Gruppe von"
L["To Personal Ressource Display's"] = "Zur persönlichen Ressourcenanzeige von"
L["To Region's"] = "Zur Region von"
L["To Screen's"] = "Zum Bildschirm von"
L["Tooltip Pattern Match"] = "Tooltip-Musterabgleich"
L["Tooltip Text"] = "Tooltip-Text"
L["Total"] = "Gesamt"
L["Total - The maximum duration of a timer, or a maximum non-timer value"] = "Gesamt – Die maximale Dauer eines Timers oder ein maximaler Wert ohne Timer"
L["Total Angle"] = "Gesamtwinkel"
L["Total Time"] = "Gesamtzeit"
L["Trigger %i: %s"] = "Auslöser %i: %s"
L["Trigger Combination"] = "Auslöserkombination"
L["Type 'select' for '%s' requires a values member'"] = "Typ 'select' für '%s' erfordert ein values-Mitglied'"
L["Undo"] = "Rückgängig"
L["Unit %s is not a valid unit for RegisterUnitEvent"] = "Einheit %s ist keine gültige Einheit für RegisterUnitEvent"
L["Unit Count"] = "Einheitenanzahl"
L["Unknown"] = "Unbekannt"
L["Unknown Encounter's Spell Id"] = "Zauber-ID eines unbekannten Begegnungskampfes"
L["Unknown property '%s' found in '%s'"] = "Unbekannte Eigenschaft '%s' in '%s' gefunden"
L["Unknown Spell"] = "Unbekannter Zauber"
L["Update"] = "Aktualisieren"
L["Update Auras"] = "Auren aktualisieren"
L["Url: %s"] = "URL: %s"
L["Use Display Info Id"] = "Anzeigeinfo-ID verwenden"
L["Use SetTransform"] = "SetTransform verwenden"
L["Used in Auras:"] = "Verwendet in Auren:"
L["Used in auras:"] = "Verwendet in Auren:"
L["Uses Texture Coordinates to rotate the texture."] = "Verwendet Texturkoordinaten, um die Textur zu drehen."
L["Value"] = "Wert"
L["Value %i"] = "Wert %i"
L["Values are in normalized rgba format."] = "Die Werte liegen im normalisierten rgba-Format vor."
L["Values/Remaining Time above this value are displayed as full progress."] = "Werte/verbleibende Zeit oberhalb dieses Wertes werden als voller Fortschritt angezeigt."
L["Values/Remaining Time below this value are displayed as zero progress."] = "Werte/verbleibende Zeit unterhalb dieses Wertes werden als null Fortschritt angezeigt."
L["View custom code"] = "Eigenen Code ansehen"
L["Voice Settings"] = "Spracheinstellungen"
L["We thank"] = "Wir danken"
L["KUIAR_Engine %s on WoW %s"] = "KUIAR_Engine %s auf WoW %s"
L["KUIAR_Engine recommends using spell ids instead of names. Spell ids are automatically localized."] = "KUIAR_Engine empfiehlt, Zauber-IDs statt Namen zu verwenden. Zauber-IDs werden automatisch lokalisiert."
L["What do you want to do?"] = "Was möchtest du tun?"
L["Whole Area"] = "Ganzes Gebiet"
L["wrapping"] = "Umbruch"
L["x-Offset"] = "X-Versatz"
L["y-Offset"] = "Y-Versatz"
L["You already have this group/aura. Importing will create a duplicate."] = "Du hast diese Gruppe/Aura bereits. Beim Importieren entsteht ein Duplikat."
L["You are about to delete a trigger. |cFFFF0000This cannot be undone!|r Would you like to continue?"] = "Du bist dabei, einen Auslöser zu löschen. |cFFFF0000Dies kann nicht rückgängig gemacht werden!|r Möchtest du fortfahren?"
L["You are about to Import an Aura with custom Lua code on a Hardcore server.\n\n|cFFFF0000There is a risk the custom code could be used to kill your hardcore character!|r\n\nWould you like to continue?"] = "Du bist dabei, eine Aura mit eigenem Lua-Code auf einem Hardcore-Server zu importieren.\n\n|cFFFF0000Es besteht das Risiko, dass der eigene Code dazu genutzt wird, deinen Hardcore-Charakter zu töten!|r\n\nMöchtest du fortfahren?"
L["You can add a comma-separated list of state values here that (when changed) KUIAR_Runtime should also run the Anchor Code on.\n\nKUIAR_Runtime will always run custom anchor code if you include 'changed' in this list, or when a region is added, removed, or re-ordered."] = "Du kannst hier eine kommagetrennte Liste von Statuswerten angeben, bei deren Änderung KUIAR_Runtime zusätzlich den Ankercode ausführen soll.\n\nKUIAR_Runtime führt eigenen Ankercode immer aus, wenn du 'changed' in diese Liste aufnimmst oder wenn eine Region hinzugefügt, entfernt oder neu angeordnet wird."
L["You can add a comma-separated list of state values here that (when changed) KUIAR_Runtime should also run the Grow Code on.\n\nKUIAR_Runtime will always run custom grow code if you include 'changed' in this list, or when a region is added, removed, or re-ordered."] = "Du kannst hier eine kommagetrennte Liste von Statuswerten angeben, bei deren Änderung KUIAR_Runtime zusätzlich den Wachstumscode ausführen soll.\n\nKUIAR_Runtime führt eigenen Wachstumscode immer aus, wenn du 'changed' in diese Liste aufnimmst oder wenn eine Region hinzugefügt, entfernt oder neu angeordnet wird."
L["You can add a comma-separated list of state values here that (when changed) KUIAR_Runtime should also run the sort code on.KUIAR_Runtime will always run custom sort code if you include 'changed' in this list, or when a region is added, removed."] = "Du kannst hier eine kommagetrennte Liste von Statuswerten angeben, bei deren Änderung KUIAR_Runtime zusätzlich den Sortiercode ausführen soll. KUIAR_Runtime führt eigenen Sortiercode immer aus, wenn du 'changed' in diese Liste aufnimmst oder wenn eine Region hinzugefügt oder entfernt wird."
L["Your Saved Snippets"] = "Deine gespeicherten Snippets"
L["About KUIAR_Runtime"] = "Über KUIAR_Runtime"
L["Read about KUIAR_Runtime development, supported features, and current limitations."] = "Lies über die Entwicklung von KUIAR_Runtime, unterstützte Funktionen und aktuelle Einschränkungen."
L["This aura was saved with a newer engine version. It can be imported; any setting added in that version is kept but has no effect here."] = "Diese Aura wurde mit einer neueren Engine-Version gespeichert. Sie kann importiert werden; in dieser Version hinzugefügte Einstellungen bleiben erhalten, haben hier aber keine Wirkung."

end)
