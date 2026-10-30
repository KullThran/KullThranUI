local _, ns = ...

local locales = ns and ns.Locales
if type(locales) ~= "table" then
    return
end

local function apply(locale, entries)
    if type(locale) ~= "table" then
        return
    end

    for key, value in pairs(entries) do
        locale[key] = value
    end
end

local entries = {
    -- Module names
    ["Unit Frames"] = "Einheitenfenster",
    ["Party Frames"] = "Gruppenfenster",
    ["Cast Bar"] = "Zauberleiste",
    ["Resource Bars"] = "Ressourcenleisten",
    ["Cooldown Manager"] = "Abklingzeit-Manager",
    ["KUICooldownManager"] = "KUI Abklingzeit-Manager",
    ["Progress Bars"] = "Fortschrittsleisten",

    -- Dropdown keys and shared values
    ["accent"] = "Akzent",
    ["custom"] = "Benutzerdefiniert",
    ["white"] = "Weiß",
    ["none"] = "Kein",
    ["spec"] = "Spezialisierung",
    ["loadout"] = "Talent-Voreinstellung",
    ["character"] = "Charakter",
    ["auto"] = "Auto",
    ["primary"] = "Primär",
    ["secondary"] = "Sekundär",
    ["player"] = "Spieler",
    ["target"] = "Ziel",
    ["focus"] = "Fokus",
    ["pet"] = "Begleiter",
    ["left"] = "Links",
    ["right"] = "Rechts",
    ["top"] = "Oben",
    ["bottom"] = "Unten",
    ["center"] = "Mitte",
    ["LEFT"] = "Links",
    ["RIGHT"] = "Rechts",
    ["TOP"] = "Oben",
    ["BOTTOM"] = "Unten",
    ["CENTER"] = "Mitte",
    ["BACKGROUND"] = "Hintergrund",
    ["LOW"] = "Niedrig",
    ["MEDIUM"] = "Mittel",
    ["HIGH"] = "Hoch",
    ["DIALOG"] = "Dialog",
    ["KULLTHRAN"] = "KullThran",
    ["CLASS"] = "Klassenfarbe",
    ["CUSTOM"] = "Benutzerdefinierte Farbe",
    ["duration"] = "Dauer",
    ["stacks"] = "Stapel",
    ["power"] = "Ressource",

    -- General dropdown labels
    ["Accent"] = "Akzent",
    ["Custom"] = "Benutzerdefiniert",
    ["White"] = "Weiß",
    ["None"] = "Kein",
    ["Auto"] = "Auto",
    ["Class Color"] = "Klassenfarbe",
    ["Custom Color"] = "Benutzerdefinierte Farbe",
    ["KullThran (Default)"] = "KullThran (Standard)",
    ["Power Type"] = "Ressourcenart",
    ["Per Spec"] = "Pro Spezialisierung",
    ["Per Character"] = "Pro Charakter",
    ["Per Talent Preset"] = "Pro Talent-Voreinstellung",
    ["Primary Power Bar"] = "Primäre Ressourcenleiste",
    ["Class Resource Bar"] = "Klassenressourcenleiste",
    ["HP & Percent"] = "HP & Prozent",
    ["HP Only (Abbrev)"] = "Nur HP (Abk.)",
    ["HP Only (Full)"] = "Nur HP (Vollst.)",
    ["Power & Percent"] = "Ressource & Prozent",
    ["Power Only (Abbrev)"] = "Nur Ressource (Abk.)",
    ["Power Only (Full)"] = "Nur Ressource (Vollst.)",
    ["Percent Only"] = "Nur Prozent",
    ["Disable KUI Module"] = "KUI-Modul deaktivieren",
    ["Disable Addon"] = "Addon deaktivieren",

    -- Core / Welcome
    ["Welcome to"] = "Willkommen bei",
    ["Skip Install"] = "Installation überspringen",
    ["Next Step"] = "Nächster Schritt",
    ["Next"] = "Weiter",

    -- Installers
    ["Welcome to KullThranUI"] = "Willkommen bei KullThranUI",
    ["Below a list of highly recommended addons will open to embed them into the interface and avoid errors."] = "Unten öffnet sich eine Liste dringend empfohlener Addons, um sie in die Benutzeroberfläche einzubetten und Fehler zu vermeiden.",
    ["You can open the options menu anytime with /kui"] = "Sie können das Optionsmenü jederzeit mit /kui öffnen",
    ["Download"] = "Herunterladen",
    ["Installed"] = "Installiert",
    ["Apply Profile"] = "Profil anwenden",
    ["Previous"] = "Zurück",
    ["Disabled"] = "Deaktiviert",
    ["Don't show again"] = "Nicht mehr anzeigen",
    ["Recommended Addons"] = "Empfohlene Addons",
    ["Select Resolution Profile"] = "Auflösungsprofil auswählen",
    ["Compatibility Check"] = "Kompatibilitätsprüfung",
    ["Detected addons that may interfere with KullThranUI modules. Loaded or enabled addons are highlighted below. Disable them if you want KullThranUI to control those features."] = "Erkannte Addons, die KullThranUI-Module stören könnten. Geladene oder aktivierte Addons sind unten markiert. Deaktivieren Sie sie, wenn KullThranUI diese Funktionen steuern soll.",
    ["Loaded"] = "Geladen",
    ["Enabled"] = "Aktiviert",
    ["Ignore & Continue"] = "Ignorieren & Weiter",
    ["This guided setup will help you choose language, fonts, visual style, and recommended addons."] = "Dieses geführte Setup hilft Ihnen bei der Auswahl von Sprache, Schriftarten, visuellem Stil und empfohlenen Addons.",
    ["Choose the language for KullThranUI.\nChanging it will reload the UI and reopen the installer on this step."] = "Wählen Sie die Sprache für KullThranUI.\nEine Änderung lädt die Benutzeroberfläche neu und öffnet den Assistenten bei diesem Schritt erneut.",
    ["English"] = "Englisch",
    ["Spanish"] = "Spanisch",
    ["French"] = "Französisch",
    ["German"] = "Deutsch",
    ["You can change this later from /kui."] = "Sie können dies später über /kui ändern.",
    ["Select the main font for the entire UI.\nChanges apply immediately to most elements."] = "Wählen Sie die Hauptschriftart für die gesamte Benutzeroberfläche.\nÄnderungen werden sofort für die meisten Elemente übernommen.",
    ["Choose your preferred visual style.\nKUI Skins applies a dark, minimalist theme to all Blizzard windows."] = "Wählen Sie Ihren bevorzugten visuellen Stil.\nKUI Skins wendet ein dunkles, minimalistisches Design auf alle Blizzard-Fenster an.",
    ["Enable KUI Skins"] = "KUI Skins aktivieren",
    ["Blizzard Default"] = "Blizzard-Standard",
    ["Visual Style"] = "Visueller Stil",
    ["Healer"] = "Heiler",
    ["DPS"] = "DPS",
    ["Reload UI"] = "UI neu laden",
    ["Accent (Default)"] = "Accent (Default)",
    ["Objective Tracker Custom Color"] = "Objective Tracker Custom Color",
    ["Objective Tracker Color"] = "Objective Tracker Color",
    ["Preset selection also updates accent-driven fields like tracker highlights, chat highlight and castbar color."] = "Preset selection also updates accent-driven fields like tracker highlights, chat highlight and castbar color.",
    ["Manual Colors"] = "Manual Colors",
    ["Fine tune the smart recolor palette manually if you want a custom style."] = "Fine tune the smart recolor palette manually if you want a custom style.",
    ["Campaign"] = "Campaign",
    ["The Voidspire"] = "The Voidspire",
    ["- 0/1 Enter the Voidspire Raid\n  Story Mode (Optional)"] = "- 0/1 Enter the Voidspire Raid\n  Story Mode (Optional)",
    ["Enter the Voidspire Raid"] = "Enter the Voidspire Raid",
    ["- 0/1 Voidspire Raid completed"] = "- 0/1 Voidspire Raid completed",
    ["Quests"] = "Quests",
    ["Late Night Training: Week 1 of 3"] = "Late Night Training: Week 1 of 3",
    ["- 0/2 Battlegrounds won"] = "- 0/2 Battlegrounds won",
    ["Slayer's Rise"] = "Slayer's Rise",
    ["Ready for turn-in"] = "Ready for turn-in",
    ["Window Background"] = "Window Background",
    ["Main Text"] = "Main Text",
    ["Secondary Text"] = "Secondary Text",
    ["Background Tint"] = "Background Tint",
}

apply(locales.deDE, entries)
