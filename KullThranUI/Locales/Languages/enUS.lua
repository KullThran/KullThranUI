local _, ns = ...

local locales = ns and ns.Locales
if type(locales) ~= "table" then
    return
end

local L = locales.enUS
if type(L) ~= "table" then
    return
end

-- Make enUS explicit for every key already known by the base locale layer.
-- English source strings are the keys throughout KullThranUI.
if type(locales.esES) == "table" then
    for key in pairs(locales.esES) do
        if L[key] == nil then
            L[key] = key
        end
    end
end

local entries = {
    -- General landing page
    ["KULLTHRANUI CONFIGURATION"] = "KULLTHRANUI CONFIGURATION",
    ["Interface Control Center"] = "Interface Control Center",
    ["Configure the foundation of KUI here. Module-specific behavior remains in the sections on the left."] = "Configure the foundation of KUI here. Module-specific behavior remains in the sections on the left.",
    ["PROFILE  %s"] = "PROFILE  %s",
    ["VERSION  %s"] = "VERSION  %s",
    ["SPEC ASSIGNMENT  %s"] = "SPEC ASSIGNMENT  %s",
    ["Interface Scale"] = "Interface Scale",
    ["Match KUI to your display first. This controls the scale used by every module."] = "Match KUI to your display first. This controls the scale used by every module.",
    ["Appearance & Language"] = "Appearance & Language",
    ["Define the global accent behavior and the language used throughout the configuration."] = "Define the global accent behavior and the language used throughout the configuration.",
    ["Updates & Release Notes"] = "Updates & Release Notes",
    ["Installed Version: %s"] = "Installed Version: %s",
    ["Release notes are available for version %s."] = "Release notes are available for version %s.",
    ["Latest archived release notes: %s"] = "Latest archived release notes: %s",
    ["The current release has not been published to the Wago archive yet. CurseForge and Discord sources remain available inside the changelog."] = "The current release has not been published to the Wago archive yet. CurseForge and Discord sources remain available inside the changelog.",
    ["Open Changelog"] = "Open Changelog",
    ["Advanced Style System"] = "Advanced Style System",
    ["Build a complete visual preset for KUI or fine tune the palette manually. These settings affect the entire addon."] = "Build a complete visual preset for KUI or fine tune the palette manually. These settings affect the entire addon.",
    -- Module names
    ["Unit Frames"] = "Unit Frames",
    ["Party Frames"] = "Party Frames",
    ["Cast Bar"] = "Cast Bar",
    ["Resource Bars"] = "Resource Bars",
    ["Cooldown Manager"] = "Cooldown Manager",
    ["KUICooldownManager"] = "KUI Cooldown Manager",
    ["Progress Bars"] = "Progress Bars",

    -- Dropdown keys and shared values
    ["accent"] = "Accent",
    ["custom"] = "Custom",
    ["white"] = "White",
    ["none"] = "None",
    ["spec"] = "Spec",
    ["loadout"] = "Talent Preset",
    ["character"] = "Character",
    ["auto"] = "Auto",
    ["primary"] = "Primary",
    ["secondary"] = "Secondary",
    ["player"] = "Player",
    ["target"] = "Target",
    ["focus"] = "Focus",
    ["pet"] = "Pet",
    ["left"] = "Left",
    ["right"] = "Right",
    ["top"] = "Top",
    ["bottom"] = "Bottom",
    ["center"] = "Center",
    ["LEFT"] = "Left",
    ["RIGHT"] = "Right",
    ["TOP"] = "Top",
    ["BOTTOM"] = "Bottom",
    ["CENTER"] = "Center",
    ["BACKGROUND"] = "Background",
    ["LOW"] = "Low",
    ["MEDIUM"] = "Medium",
    ["HIGH"] = "High",
    ["DIALOG"] = "Dialog",
    ["KULLTHRAN"] = "KullThran",
    ["CLASS"] = "Class Color",
    ["CUSTOM"] = "Custom Color",
    ["duration"] = "Duration",
    ["stacks"] = "Stacks",
    ["power"] = "Power",

    -- Common dropdown labels
    ["Accent"] = "Accent",
    ["Custom"] = "Custom",
    ["White"] = "White",
    ["None"] = "None",
    ["Auto"] = "Auto",
    ["Class Color"] = "Class Color",
    ["Custom Color"] = "Custom Color",
    ["KullThran (Default)"] = "KullThran (Default)",
    ["Power Type"] = "Power Type",
    ["Per Spec"] = "Per Spec",
    ["Per Character"] = "Per Character",
    ["Per Talent Preset"] = "Per Talent Preset",
    ["Primary Power Bar"] = "Primary Power Bar",
    ["Class Resource Bar"] = "Class Resource Bar",
    ["HP & Percent"] = "HP & Percent",
    ["HP Only (Abbrev)"] = "HP Only (Abbrev)",
    ["HP Only (Full)"] = "HP Only (Full)",
    ["Power & Percent"] = "Power & Percent",
    ["Power Only (Abbrev)"] = "Power Only (Abbrev)",
    ["Power Only (Full)"] = "Power Only (Full)",
    ["Percent Only"] = "Percent Only",
    ["Disable KUI Module"] = "Disable KUI Module",
    ["Disable Addon"] = "Disable Addon",

    -- Objective Tracker
    ["Objective Tracker"] = "Objective Tracker",
    ["Objective Tracker Skin settings."] = "Objective Tracker Skin settings.",
    ["Enable Objective Tracker Skin"] = "Enable Objective Tracker Skin",
    ["Restore Defaults"] = "Restore Defaults",
    ["Typography"] = "Typography",
    ["Quest Title Font"] = "Quest Title Font",
    ["Quest Title Size"] = "Quest Title Size",
    ["Font Outline"] = "Font Outline",
    ["Thick Outline"] = "Thick Outline",
    ["Color"] = "Color",
    ["Objective Tracker Custom Color"] = "Objective Tracker Custom Color",
    ["Requires /reload to fully apply this change."] = "Requires /reload to fully apply this change.",
    ["Visibility"] = "Visibility",
    ["Hide in Combat"] = "Hide in Combat",
    ["Hide in Arena"] = "Hide in Arena",
    ["Hide in Dungeon"] = "Hide in Dungeon",
    ["Hide in Raid"] = "Hide in Raid",
    ["Fade Delay"] = "Fade Delay",
    ["Color Theme"] = "Color Theme",
    ["Pick the main color behavior for the entire interface."] = "Pick the main color behavior for the entire interface.",
    ["Global Class Color is active. Tracker color is overridden."] = "Global Class Color is active. Tracker color is overridden.",
    ["Background & Fade"] = "Background & Fade",
    ["Background Alpha"] = "Background Alpha",
    ["Fade Delay (Seconds)"] = "Fade Delay (Seconds)",
    ["Set to 0 to disable fading."] = "Set to 0 to disable fading.",
    ["Accent (Default)"] = "Accent (Default)",
    ["Custom Color"] = "Custom Color",
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
    ["RESET_CONFIRM_TEXT"] = "Are you sure you want to reset the profile?",
    ["RESET_CONFIRM_TEXT_2"] = "ARE YOU ABSOLUTELY SURE? This action cannot be undone.",
    ["Next"] = "Next",
}

for key, value in pairs(entries) do
    L[key] = value
end
