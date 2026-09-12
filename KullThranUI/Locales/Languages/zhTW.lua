local _, ns = ...

local locales = ns and ns.Locales
if type(locales) ~= "table" then
    return
end

local L = locales.zhTW
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
}

for key, value in pairs(entries) do
    L[key] = value
end

-- Translated Overrides
L["Language"] = "語言"
L["This guided setup will help you choose language, fonts, visual style, and recommended addons."] = "此引導設置將幫助您選擇語言，字體，視覺樣式和推薦的插件。"
L["Choose the language for KullThranUI.\nChanging it will reload the UI and reopen the installer on this step."] = "選擇KullThranUI的語言。\n更改它將重新加載UI並在此步驟重新打開安裝程序。"
