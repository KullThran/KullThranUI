local root = arg[1] or "."

local function Region()
    local o = { shown = true, points = {} }
    local mt = {}
    mt.__index = function(_, key)
        -- Unknown widget methods are no-ops; data fields stay nil.
        if type(key) == "string" and key:match("^%u") then return function() end end
    end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:IsShown() return self.shown end
    function o:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function o:ClearAllPoints() self.points = {} end
    function o:SetTexture(path) self.texture = path end
    function o:SetTexCoord(...) self.coords = { ... } end
    function o:SetVertexColor(r, g, b) self.color = { r, g, b } end
    function o:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function o:SetText(text) self.text = text end
    function o:SetTextColor(r, g, b) self.color = { r, g, b } end
    function o:GetFrameLevel() return 1 end
    function o:CreateTexture() return Region() end
    function o:CreateFontString() return Region() end
    function o:SetScript(name, fn) self.scripts = self.scripts or {}; self.scripts[name] = fn end
    function o:RegisterForClicks(...) self.clicks = { ... } end
    return setmetatable(o, mt)
end

local cfg = { session = "current", mode = "damageDone", enabled = true, presetPicked = false }
local calls = {}
local Mod = {}
function Mod:GetDamageMeterStyle() return self.style or "kui" end
function Mod:GetDB() self.db = self.db or {}; return self.db end
function Mod:RefreshDamageMeterStyle() calls.style = (calls.style or 0) + 1 end
function Mod:UpdateDamageMeterData() end
Mod._damageMeterInternals = {
    GetConfig = function() return cfg end,
    GetFrameConfig = function() return cfg end,
    GetAccentColor = function() return 1, 0.5, 0 end,
    GetDamageMeterFont = function() return "font" end,
    GetSessionLabel = function() return "Current" end,
    IsDamageMeterModuleEnabled = function() return true end,
    IsModeSupported = function(key) return key ~= "absorbs" end,
    ShowDropdown = function(owner, _, menu) calls.dropdown = { owner = owner, menu = menu } end,
    BuildModeMenu = function() return "mode-menu" end,
    BuildSessionMenu = function() return "session-menu" end,
    SelectSession = function(_, key) cfg.session = key; calls.selected = key end,
    MODE_LABELS = { damageDone = "Damage Done", healingDone = "Healing Done", interrupts = "Interrupts" },
    MODE_ICONS = {},
}

local opened
local KT = {
    GetModule = function() return Mod end,
    OpenMenu = function(_, page) opened = page end,
    AddBackdrop = function() end,
    AddBorder = function() end,
}
_G.CreateFrame = function() return Region() end
_G.C_Timer = { After = function(_, fn) fn() end }
_G.InCombatLockdown = function() return false end

local chunk = assert(loadfile(root .. "/KullThranUI/Modules/Enhancements/Enhancements_DamageMeterControls.lua"))
chunk("KullThranUI", { KT = KT, Enhancements = Mod })

local frame = Region()
Mod:CreateDamageMeterToolbar(frame)
local buttons = frame.toolbarButtons
assert(buttons.new and buttons.reset and buttons.mode and buttons.segment and buttons.options)

-- Wide window: five buttons, laid out right to left.
assert(Mod:LayoutDamageMeterToolbar(frame, 320) == 5 * 19)
assert(buttons.options.points[1][4] == -6 and buttons.new.shown)
assert(buttons.segment.letter.text == "C")

-- Narrow window keeps reset / segment / options only.
assert(Mod:LayoutDamageMeterToolbar(frame, 180) == 3 * 19)
assert(not buttons.new.shown and not buttons.mode.shown and buttons.reset.shown)

-- Turned off: no width, the session button comes back.
cfg.showToolbar = false
assert(Mod:LayoutDamageMeterToolbar(frame, 320) == 0 and not buttons.options.shown)
cfg.showToolbar = nil

-- Each meter style paints its own button art; KUI is flat.
for style, file in pairs({ retail = "chat_retail", forever = "chat_forever", classic = "UI%-Quickslot2" }) do
    Mod.style = style
    Mod:LayoutDamageMeterToolbar(frame, 320)
    assert(buttons.reset.art.texture:find(file), style .. " uses its own button art")
    assert(buttons.reset.art.shown)
end
Mod.style = "kui"
Mod:LayoutDamageMeterToolbar(frame, 320)
assert(not buttons.reset.art.shown, "KUI buttons are flat")

-- Segment: left click flips Current/Overall, right click opens the history.
buttons.segment.scripts.OnClick(buttons.segment, "LeftButton")
assert(cfg.session == "overall")
buttons.segment.scripts.OnClick(buttons.segment, "LeftButton")
assert(cfg.session == "current")
buttons.segment.scripts.OnClick(buttons.segment, "RightButton")
assert(calls.dropdown.menu == "session-menu")
buttons.mode.scripts.OnClick(buttons.mode, "LeftButton")
assert(calls.dropdown.menu == "mode-menu")

-- Options jumps straight to the Damage Meter view of Enhancements.
buttons.options.scripts.OnClick(buttons.options, "LeftButton")
assert(opened == "enhancements" and Mod.db.ui.activeEnhancementCategory == "damage")

-- First-use preset picker.
assert(Mod:ShouldOfferDamageMeterPreset())
Mod:MaybeShowDamageMeterPresetPicker()
assert(Mod.damageMeterPresetPicker and Mod.damageMeterPresetPicker.shown)
Mod:ApplyDamageMeterPreset("interrupts")
assert(cfg.mode == "interrupts" and cfg.presetPicked == true)
assert(not Mod:ShouldOfferDamageMeterPreset(), "offered only once")
Mod:ApplyDamageMeterPreset("absorbs")
assert(cfg.mode == "interrupts", "unsupported presets keep the current mode")

print("PASS: Damage Meter toolbar per style, segment toggle, options shortcut and first-use preset")
