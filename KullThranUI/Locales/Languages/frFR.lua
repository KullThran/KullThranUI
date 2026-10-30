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
    ["Unit Frames"] = "Cadres d'unité",
    ["Party Frames"] = "Cadres de groupe",
    ["Cast Bar"] = "Barre d'incantation",
    ["Resource Bars"] = "Barres de ressources",
    ["Cooldown Manager"] = "Gestionnaire de recharges",
    ["KUICooldownManager"] = "Gestionnaire de recharges KUI",
    ["Progress Bars"] = "Barres de progression",

    -- Dropdown keys and shared values
    ["accent"] = "Accent",
    ["custom"] = "Personnalisé",
    ["white"] = "Blanc",
    ["none"] = "Aucun",
    ["spec"] = "Spécialisation",
    ["loadout"] = "Préréglage de talents",
    ["character"] = "Personnage",
    ["auto"] = "Auto",
    ["primary"] = "Primaire",
    ["secondary"] = "Secondaire",
    ["player"] = "Joueur",
    ["target"] = "Cible",
    ["focus"] = "Focalisation",
    ["pet"] = "Familier",
    ["left"] = "Gauche",
    ["right"] = "Droite",
    ["top"] = "Haut",
    ["bottom"] = "Bas",
    ["center"] = "Centre",
    ["LEFT"] = "Gauche",
    ["RIGHT"] = "Droite",
    ["TOP"] = "Haut",
    ["BOTTOM"] = "Bas",
    ["CENTER"] = "Centre",
    ["BACKGROUND"] = "Arrière-plan",
    ["LOW"] = "Bas",
    ["MEDIUM"] = "Moyen",
    ["HIGH"] = "Haut",
    ["DIALOG"] = "Dialogue",
    ["KULLTHRAN"] = "KullThran",
    ["CLASS"] = "Couleur de classe",
    ["CUSTOM"] = "Couleur personnalisée",
    ["duration"] = "Durée",
    ["stacks"] = "Cumuls",
    ["power"] = "Ressource",

    -- General dropdown labels
    ["Accent"] = "Accent",
    ["Custom"] = "Personnalisé",
    ["White"] = "Blanc",
    ["None"] = "Aucun",
    ["Auto"] = "Auto",
    ["Class Color"] = "Couleur de classe",
    ["Custom Color"] = "Couleur personnalisée",
    ["KullThran (Default)"] = "KullThran (par défaut)",
    ["Power Type"] = "Type de ressource",
    ["Per Spec"] = "Par spécialisation",
    ["Per Character"] = "Par personnage",
    ["Per Talent Preset"] = "Par préréglage de talents",
    ["Primary Power Bar"] = "Barre principale de ressource",
    ["Class Resource Bar"] = "Barre de ressource de classe",
    ["HP & Percent"] = "Vie et pourcentage",
    ["HP Only (Abbrev)"] = "Vie uniquement (abrégé)",
    ["HP Only (Full)"] = "Vie uniquement (complet)",
    ["Power & Percent"] = "Ressource et pourcentage",
    ["Power Only (Abbrev)"] = "Ressource uniquement (abrégé)",
    ["Power Only (Full)"] = "Ressource uniquement (complet)",
    ["Percent Only"] = "Pourcentage uniquement",
    ["Disable KUI Module"] = "Désactiver le module KUI",
    ["Disable Addon"] = "Désactiver l'addon",

    -- Core / Welcome
    ["Welcome to"] = "Bienvenue sur",
    ["Skip Install"] = "Passer l'installation",
    ["Next Step"] = "Étape suivante",
    ["Next"] = "Suivant",

    -- Installers
    ["Welcome to KullThranUI"] = "Bienvenue sur KullThranUI",
    ["Below a list of highly recommended addons will open to embed them into the interface and avoid errors."] = "Ci-dessous, une liste d'addons fortement recommandés s'ouvrira pour les intégrer à l'interface et éviter les erreurs.",
    ["You can open the options menu anytime with /kui"] = "Vous pouvez ouvrir le menu d'options à tout moment avec /kui",
    ["Download"] = "Télécharger",
    ["Installed"] = "Installé",
    ["Apply Profile"] = "Appliquer le profil",
    ["Previous"] = "Précédent",
    ["Disabled"] = "Désactivé",
    ["Don't show again"] = "Ne plus afficher",
    ["Recommended Addons"] = "Addons recommandés",
    ["Select Resolution Profile"] = "Sélectionnez le profil de résolution",
    ["Compatibility Check"] = "Vérification de compatibilité",
    ["Detected addons that may interfere with KullThranUI modules. Loaded or enabled addons are highlighted below. Disable them if you want KullThranUI to control those features."] = "Addons détectés qui peuvent interférer avec les modules de KullThranUI. Les addons chargés ou activés sont mis en évidence ci-dessous. Désactivez-les si vous souhaitez que KullThranUI contrôle ces fonctionnalités.",
    ["Loaded"] = "Chargé",
    ["Enabled"] = "Activé",
    ["Ignore & Continue"] = "Ignorer et continuer",
    ["This guided setup will help you choose language, fonts, visual style, and recommended addons."] = "Cette configuration guidée vous aidera à choisir la langue, les polices, le style visuel et les addons recommandés.",
    ["Choose the language for KullThranUI.\nChanging it will reload the UI and reopen the installer on this step."] = "Choisissez la langue pour KullThranUI.\nLe changement rechargera l'interface et rouvrira l'assistant à cette étape.",
    ["English"] = "Anglais",
    ["Spanish"] = "Espagnol",
    ["French"] = "Français",
    ["German"] = "Allemand",
    ["You can change this later from /kui."] = "Vous pourrez changer cela plus tard depuis /kui.",
    ["Select the main font for the entire UI.\nChanges apply immediately to most elements."] = "Sélectionnez la police principale pour toute l'interface.\nLes modifications s'appliquent immédiatement à la plupart des éléments.",
    ["Choose your preferred visual style.\nKUI Skins applies a dark, minimalist theme to all Blizzard windows."] = "Choisissez votre style visuel préféré.\nKUI Skins applique un thème sombre et minimaliste à toutes les fenêtres de Blizzard.",
    ["Enable KUI Skins"] = "Activer KUI Skins",
    ["Blizzard Default"] = "Blizzard par défaut",
    ["Visual Style"] = "Style visuel",
    ["Healer"] = "Soigneur",
    ["DPS"] = "DPS",
    ["Reload UI"] = "Recharger l'interface",
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

apply(locales.frFR, entries)
