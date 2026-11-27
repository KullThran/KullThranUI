-- KullThranUI :: Aura Reminders settings (pages hosted by the main KUI panel)
local ADDON_NAME, ns = ...
local KT = (ns and ns.KT) or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

-- The pages live in their own files. This one only wires them at login, and
-- holds the one thing that differs per repo: the client name.
local CLIENT = "retail"

local loginWatcher = CreateFrame("Frame")
loginWatcher:RegisterEvent("PLAYER_LOGIN")
loginWatcher:SetScript("OnEvent", function(watcher)
    watcher:UnregisterAllEvents()

    local Widgets = ns.AuraRemindersWidgets
    local Preview = ns.AuraRemindersPreview
    local Reminders = ns.AuraRemindersPageReminders
    local Talents = ns.AuraRemindersPageTalents
    local Custom = ns.AuraRemindersPageCustom
    local Cards = ns.AuraRemindersCards

    Preview.Setup({ client = CLIENT, Widgets = Widgets })
    Reminders.Setup({ client = CLIENT, Widgets = Widgets, Preview = Preview })
    Talents.Setup({ client = CLIENT, Widgets = Widgets, Preview = Preview, Reminders = Reminders })
    Cards.Setup({ client = CLIENT, Widgets = Widgets, Preview = Preview })
    Custom.Setup({ client = CLIENT, Widgets = Widgets, Preview = Preview, Reminders = Reminders, Talents = Talents, Cards = Cards })
    Custom.Register()
end)
