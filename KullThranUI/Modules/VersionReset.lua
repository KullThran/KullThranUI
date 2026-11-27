-- One-time reset of the saved data, introduced with Forever 2.0.0 and
-- Retail 6.1.6.
--
-- An account that already has KullThranUI data from an earlier version gets a
-- window once. On Forever the reset is mandatory: the window has a single
-- button and comes back until it is used. On Retail the player may keep the
-- current settings. A first install has nothing to reset and never sees it.
--
-- The reset deletes every SavedVariable of KullThranUI and its modules
-- (all profiles included), keeps only the account-wide mark that says the
-- reset was done, and reloads the UI, which then starts like a fresh install.
--
-- The window is a wooden "under construction" sign (Libraries/KUITextures/
-- VersionReset/Sign.tga, drawn without text) with the localized text on it, a
-- gnome in a hard hat hammering on its left and a goblin in a mining helmet
-- swinging a pick on its right, both live 3D models in model scenes.
local _, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

local RESET_EPOCH = 1
local MARK_KEY = "kuiDataResetEpoch"
local FRAME_NAME = "KullThranUIVersionResetFrame"

local TEXT_TITLE = "Under construction!"
local TEXT_FORCED = "Since KullThranUI %s, a fresh start is required"
local TEXT_OPTIONAL = "Since KullThranUI %s, a fresh start is recommended"
local TEXT_FORCED_DETAILS = "Your settings come from an earlier version: all saved KullThranUI settings and profiles will be deleted, the UI will reload and the installer will open again."
local TEXT_OPTIONAL_DETAILS = "Your settings come from an earlier version. Resetting deletes all saved KullThranUI settings and profiles, reloads the UI and opens the installer again. You will only be asked once."

-- The version that introduced the reset on each client (the window names it,
-- not the version installed now).
local RESET_VERSION_FOREVER, RESET_VERSION_RETAIL = "2.0.0", "6.1.6"
local TEXT_SORRY = "Sorry for the inconvenience"
local TEXT_RESET = "Reset and reload"
local TEXT_KEEP = "Keep my settings"

-- Every SavedVariable besides KullThranDB declared by KullThranUI and its
-- modules, for both clients. A name the running client does not declare is
-- simply nil.
local MODULE_SAVED_VARIABLES = {
    "KullThranUINameplatesDB", "KullThranUINameplatesDB_Forever",
    "KUIAuraRemindersDB", "KUIAuraRemindersDB_Forever",
    "KUISpellDurationDB", "KUISpellDurationDB_Forever",
    "KUIAR_EngineSaved", "KUIAR_EngineOptionsSaved", "KUIAR_EngineArchive",
}

-- Sign texture and where things sit on it, in texture pixels (860 x 640).
local SIGN_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\VersionReset\\Sign"
local SIGN_W, SIGN_H = 860, 640
local SIGN_SCALE = 0.75
local LAYOUT = {
    title = { x = 430, y = 235, size = 118, width = 600 },
    line1 = { x = 430, y = 340, size = 28, width = 600 },
    details = { x = 430, y = 410, size = 21, width = 580, height = 100 },
    sorry = { x = 430, y = 527, size = 25, width = 320 },
    buttons = { y = 600 },
    -- Feet of each character, in the same pixels (below the sign's bottom edge).
    -- fallback: height in yards to frame when the game gives no bounding box.
    -- room: how much taller than the model the scene frames (a smaller character).
    gnome = { x = 45, y = 742, w = 330, h = 440, fallback = 1.15, room = 1.5 },
    goblin = { x = 815, y = 742, w = 360, h = 440, fallback = 1.35, room = 1.3 },
}

-- Characters. Items exist in both clients' item tables; the player model with a
-- custom race wears them (TryOn).
local RACE_GNOME, RACE_GOBLIN = 7, 9
local GNOME_ITEMS = {
    { "item:10543" },                  -- Goblin Construction Helmet (hard hat)
    { "item:4344" },                   -- Brown Linen Shirt
    { "item:6263" },                   -- Blue Overalls
    { "item:6732" },                   -- Gnomish Mechanic's Gloves
    { "item:9645" },                   -- Gnomish Inventor Boots
    { "item:5956", "MAINHANDSLOT" },   -- Blacksmith Hammer
}
local GOBLIN_ITEMS = {
    { "item:10542" },                  -- Goblin Mining Helmet (with its lamp)
    { "item:2575" },                   -- Red Linen Shirt
    { "item:5327" },                   -- Greasy Tinker's Pants
    { "item:7189" },                   -- Goblin Rocket Boots
    { "item:2901", "MAINHANDSLOT" },   -- Mining Pick
}
-- Work loops by itself: the gnome hammers, the goblin swings its pick.
local ANIM_WORK = 62
local GNOME_YAW, GOBLIN_YAW = 0.85, -0.85
local CAMERA_FOV = math.rad(32)

local function LText(text)
    local L = KT.GetLocale and KT:GetLocale()
    local value = type(L) == "table" and L[text]
    return type(value) == "string" and value ~= "" and value or text
end

function KT:IsVersionDataResetForced()
    return (self.IsForever and self:IsForever()) and true or false
end

function KT:IsVersionDataResetPending()
    return self._ktVersionResetPending == true
end

-- hadSavedData: KullThranDB existed before this session (an earlier version
-- ran on this account). Called once the real SavedVariables are connected.
function KT:CheckVersionDataReset(hadSavedData)
    if self._ktVersionResetChecked then return end
    local global = self.db and self.db.global
    if type(global) ~= "table" then return end
    self._ktVersionResetChecked = true

    if (tonumber(global[MARK_KEY]) or 0) >= RESET_EPOCH then return end
    if not hadSavedData then
        -- First install: nothing to reset.
        global[MARK_KEY] = RESET_EPOCH
        return
    end

    self._ktVersionResetPending = true
    self:ShowVersionDataResetPopup()
end

-- Fonts ---------------------------------------------------------------------------
-- The game's own: Morpheus for the title, Friz Quadrata for the text, in the
-- Cyrillic cut on Russian clients and the client's font in Asian ones.
local function ClientFonts()
    local locale = GetLocale and GetLocale() or "enUS"
    local normal = _G.GameFontNormal and _G.GameFontNormal.GetFont and _G.GameFontNormal:GetFont()
    if locale == "koKR" or locale == "zhCN" or locale == "zhTW" then
        return normal or "Fonts\\FRIZQT__.TTF", normal or "Fonts\\FRIZQT__.TTF"
    elseif locale == "ruRU" then
        return "Fonts\\MORPHEUS_CYR.TTF", "Fonts\\FRIZQT___CYR.TTF"
    end
    return "Fonts\\MORPHEUS.TTF", "Fonts\\FRIZQT__.TTF"
end

local function SetFontSafe(fs, file, size, flags)
    fs:SetFont(file, size, flags or "")
    if fs:GetFont() then return end
    local fallback = _G.GameFontNormal and _G.GameFontNormal.GetFont and _G.GameFontNormal:GetFont()
    if fallback then fs:SetFont(fallback, size, flags or "") end
end

-- Largest size from `size` down that fits: one line within `width`, or wrapped
-- within `width` x `height`.
local function FitText(fs, file, size, flags, width, height)
    local minimum = math.max(8, math.floor(size * 0.5))
    for current = size, minimum, -1 do
        SetFontSafe(fs, file, current, flags)
        if height then
            if (fs:GetStringHeight() or 0) <= height then return current end
        elseif (fs:GetStringWidth() or 0) <= width then
            return current
        end
    end
    return minimum
end

local function SignPoint(frame, region, point, x, y)
    region:SetPoint(point, frame.Sign, "TOPLEFT", x * SIGN_SCALE, -y * SIGN_SCALE)
end

-- Characters ----------------------------------------------------------------------
-- Model scene calls are guarded: a client without one of them still shows the window.
-- Returns true plus the method's results, or false.
local function Call(object, method, ...)
    local fn = object and object[method]
    if type(fn) ~= "function" then return false end
    return pcall(fn, object, ...)
end

local function NewScene(parent, w, h)
    local scene = CreateFrame("ModelScene", nil, parent)
    -- In front of the sign: the characters overlap its edges.
    scene:SetFrameLevel(parent.Content:GetFrameLevel() + 5)
    scene:SetSize(w * SIGN_SCALE, h * SIGN_SCALE)
    Call(scene, "SetCameraFieldOfView", CAMERA_FOV)
    Call(scene, "SetCameraNearClip", 0.05)
    Call(scene, "SetCameraFarClip", 200)
    Call(scene, "SetLightVisible", true)
    Call(scene, "SetLightType", (Enum and Enum.ModelLightType and Enum.ModelLightType.Directional) or 0)
    Call(scene, "SetLightDirection", -0.6, 0.45, -0.65)
    Call(scene, "SetLightAmbientColor", 0.72, 0.68, 0.62)
    Call(scene, "SetLightDiffuseColor", 0.95, 0.9, 0.82)
    return scene
end

-- The actor's bounding box as minX, minY, minZ, maxX, maxY, maxZ, or nil while
-- the game has none (model not ready). Accepts two vectors or six numbers.
local function BoundingBox(actor)
    local result = { Call(actor, "GetActiveBoundingBox") }
    if not result[1] then return nil end
    local a, b = result[2], result[3]
    local box
    if type(a) == "table" and type(b) == "table" then
        box = { a.x, a.y, a.z, b.x, b.y, b.z }
    else
        box = { result[2], result[3], result[4], result[5], result[6], result[7] }
    end
    for i = 1, 6 do
        if type(box[i]) ~= "number" or box[i] ~= box[i] then return nil end
    end
    if box[6] - box[3] < 0.2 then return nil end
    return box
end

-- Frame the camera on the model: feet at the bottom of the scene, whole body in
-- view. extraHeight makes room above the box (a smaller-looking character).
-- Returns true when the game's bounding box was used; with `fallback` (yards)
-- and no box it frames that height instead.
local function FrameCamera(scene, actor, extraHeight, fallback)
    local box = BoundingBox(actor)
    local base, height, width
    if box then
        base = box[3]
        height = (box[6] - box[3]) * (extraHeight or 1)
        width = math.max(box[4] - box[1], box[5] - box[2])
    elseif fallback then
        base, height, width = 0, fallback, fallback * 0.6
    else
        return false
    end
    local aspect = scene:GetWidth() / math.max(1, scene:GetHeight())
    local half = math.tan(CAMERA_FOV / 2)
    local distance = math.max(height * 0.56 / half, width * 0.62 / (half * aspect))
    Call(scene, "SetCameraPosition", distance, 0, base + height * 0.5)
    Call(scene, "SetCameraOrientationByYawPitchRoll", math.pi, 0, 0)
    scene.framedBy = box and "box" or "fallback"
    return box ~= nil
end

-- Items the client has not seen yet may not show on the first try: ask for
-- their data and dress again a moment later.
local function Dress(actor, items)
    for _, entry in ipairs(items) do
        local itemID = tonumber(entry[1]:match("item:(%d+)"))
        if itemID and C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, itemID)
        end
        Call(actor, "TryOn", entry[1], entry[2])
    end
end

local function DressSoon(actor, items)
    Dress(actor, items)
    if C_Timer and C_Timer.After then
        C_Timer.After(1.5, function() Dress(actor, items) end)
    end
end

-- Model scene actors have no scripts of their own (no OnModelLoaded through
-- SetScript): the scene checks every frame until all its actors report their
-- model loaded, then runs `setup` once. Then it keeps trying `frame` until the
-- camera could use a real bounding box (models can report loaded before they
-- have one). Gives up after a few seconds and keeps the fallback framing.
local LOAD_TIMEOUT = 5
local function WhenLoaded(scene, actors, setup, frame)
    local waited, ready = 0, false
    scene:SetScript("OnUpdate", function(self, elapsed)
        waited = waited + (elapsed or 0)
        if not ready then
            local loaded = true
            for _, actor in ipairs(actors) do
                local ok, isLoaded = Call(actor, "IsLoaded")
                if ok and not isLoaded then loaded = false end
            end
            if not loaded and waited < LOAD_TIMEOUT then return end
            ready = true
            setup()
            frame(true)
        end
        if frame(false) or waited >= LOAD_TIMEOUT * 2 then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local function BuildGnome(frame)
    local spot = LAYOUT.gnome
    local scene = NewScene(frame, spot.w, spot.h)
    SignPoint(frame, scene, "BOTTOM", spot.x, spot.y)
    local actor = scene:CreateActor()
    Call(actor, "SetYaw", GNOME_YAW)
    Call(actor, "SetModelByUnit", "player", false, false, false, true, false, RACE_GNOME)
    WhenLoaded(scene, { actor }, function()
        DressSoon(actor, GNOME_ITEMS)
        Call(actor, "SetAnimation", ANIM_WORK)
    end, function(useFallback)
        return FrameCamera(scene, actor, spot.room, useFallback and spot.fallback)
    end)
    frame.GnomeScene, frame.Gnome = scene, actor
end

local function BuildGoblin(frame)
    local spot = LAYOUT.goblin
    local scene = NewScene(frame, spot.w, spot.h)
    SignPoint(frame, scene, "BOTTOM", spot.x, spot.y)
    local actor = scene:CreateActor()
    Call(actor, "SetYaw", GOBLIN_YAW)
    Call(actor, "SetModelByUnit", "player", false, false, false, true, false, RACE_GOBLIN)
    WhenLoaded(scene, { actor }, function()
        DressSoon(actor, GOBLIN_ITEMS)
        Call(actor, "SetAnimation", ANIM_WORK)
    end, function(useFallback)
        return FrameCamera(scene, actor, spot.room, useFallback and spot.fallback)
    end)
    frame.GoblinScene, frame.Goblin = scene, actor
end

-- Window --------------------------------------------------------------------------
local function NewText(frame, layer)
    local fs = frame.Content:CreateFontString(nil, layer or "OVERLAY")
    -- A font before any SetText (the game refuses text on a fontless string);
    -- Refresh sets the real one.
    fs:SetFontObject(_G.GameFontHighlight or _G.GameFontNormal)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    return fs
end

local function BuildFrame()
    local frame = CreateFrame("Frame", FRAME_NAME, UIParent)
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:Hide()

    local dim = frame:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints(frame)
    dim:SetColorTexture(0, 0, 0, 0.6)
    frame.Dim = dim

    local content = CreateFrame("Frame", nil, frame)
    content:SetSize(SIGN_W * SIGN_SCALE, SIGN_H * SIGN_SCALE)
    content:SetPoint("CENTER", frame, "CENTER", 0, 50)
    frame.Content = content

    local sign = content:CreateTexture(nil, "ARTWORK")
    sign:SetTexture(SIGN_TEXTURE)
    sign:SetAllPoints(content)
    frame.Sign = sign

    frame.Title = NewText(frame)
    SignPoint(frame, frame.Title, "CENTER", LAYOUT.title.x, LAYOUT.title.y)
    frame.Title:SetTextColor(1, 0.82, 0)

    frame.Line1 = NewText(frame)
    SignPoint(frame, frame.Line1, "CENTER", LAYOUT.line1.x, LAYOUT.line1.y)
    frame.Line1:SetTextColor(1, 0.82, 0)

    frame.Details = NewText(frame)
    SignPoint(frame, frame.Details, "CENTER", LAYOUT.details.x, LAYOUT.details.y)
    frame.Details:SetWidth(LAYOUT.details.width * SIGN_SCALE)
    frame.Details:SetTextColor(1, 1, 1)

    frame.Sorry = NewText(frame)
    SignPoint(frame, frame.Sorry, "CENTER", LAYOUT.sorry.x, LAYOUT.sorry.y)
    frame.Sorry:SetTextColor(1, 1, 1)

    local reset = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    reset:SetSize(210, 28)
    reset:SetScript("OnClick", function() KT:OnVersionResetButton("reset") end)
    frame.ResetButton = reset

    local keep = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    keep:SetSize(210, 28)
    keep:SetScript("OnClick", function() KT:OnVersionResetButton("keep") end)
    frame.KeepButton = keep

    -- Test view only (/kuiresettest): a close button and Escape. The real
    -- window has neither.
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    SignPoint(frame, close, "CENTER", 812, 112)
    close:SetFrameLevel(content:GetFrameLevel() + 10)
    close:SetScript("OnClick", function() frame:Hide() end)
    close:Hide()
    frame.CloseButton = close
    frame:SetScript("OnKeyDown", function(self, key)
        local closes = key == "ESCAPE" and KT._ktVersionResetPreview
        pcall(self.SetPropagateKeyboardInput, self, not closes)
        if closes then self:Hide() end
    end)

    BuildGnome(frame)
    BuildGoblin(frame)

    frame:SetScript("OnHide", function()
        if KT._ktVersionResetPending and not KT._ktVersionResetRunning and not KT._ktVersionResetPreview then
            -- Hidden by something else while unanswered: show it again.
            C_Timer.After(0.5, function()
                if KT._ktVersionResetPending and not KT._ktVersionResetRunning then
                    KT:ShowVersionDataResetPopup()
                end
            end)
        end
        KT._ktVersionResetPreview = nil
    end)
    return frame
end

-- Black drop shadow, set after the font (a new font can bring its own).
local function Shadow(fs, offset)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(offset, -offset)
end

local function Refresh(frame, forced)
    local titleFont, bodyFont = ClientFonts()
    local version = forced and RESET_VERSION_FOREVER or RESET_VERSION_RETAIL

    frame.Title:SetText(LText(TEXT_TITLE))
    FitText(frame.Title, titleFont, LAYOUT.title.size * SIGN_SCALE, "OUTLINE", LAYOUT.title.width * SIGN_SCALE)
    Shadow(frame.Title, 3)

    frame.Line1:SetText(LText(forced and TEXT_FORCED or TEXT_OPTIONAL):format(version))
    FitText(frame.Line1, bodyFont, LAYOUT.line1.size * SIGN_SCALE, "", LAYOUT.line1.width * SIGN_SCALE)
    Shadow(frame.Line1, 2)

    frame.Details:SetText(LText(forced and TEXT_FORCED_DETAILS or TEXT_OPTIONAL_DETAILS))
    FitText(frame.Details, bodyFont, LAYOUT.details.size * SIGN_SCALE, "", nil, LAYOUT.details.height * SIGN_SCALE)
    Shadow(frame.Details, 2)

    frame.Sorry:SetText(LText(TEXT_SORRY))
    FitText(frame.Sorry, bodyFont, LAYOUT.sorry.size * SIGN_SCALE, "", LAYOUT.sorry.width * SIGN_SCALE)
    Shadow(frame.Sorry, 2)

    frame.ResetButton:SetText(LText(TEXT_RESET))
    frame.KeepButton:SetText(LText(TEXT_KEEP))
    frame.ResetButton:ClearAllPoints()
    frame.KeepButton:ClearAllPoints()
    local buttonY = LAYOUT.buttons.y
    if forced then
        frame.KeepButton:Hide()
        SignPoint(frame, frame.ResetButton, "TOP", SIGN_W / 2, buttonY)
    else
        frame.KeepButton:Show()
        SignPoint(frame, frame.ResetButton, "TOPRIGHT", SIGN_W / 2 - 8, buttonY)
        SignPoint(frame, frame.KeepButton, "TOPLEFT", SIGN_W / 2 + 8, buttonY)
    end
end

-- preview: nil for the real window, or "forever" / "retail" for the test view
-- with that client's buttons.
function KT:ShowVersionDataResetPopup(preview)
    if not preview and (not self._ktVersionResetPending or self._ktVersionResetRunning) then return end

    if not (IsLoggedIn and IsLoggedIn()) then
        if not self._ktVersionResetWaiter then
            local waiter = CreateFrame("Frame")
            waiter:RegisterEvent("PLAYER_ENTERING_WORLD")
            waiter:SetScript("OnEvent", function(frame)
                frame:UnregisterAllEvents()
                C_Timer.After(1, function() KT:ShowVersionDataResetPopup() end)
            end)
            self._ktVersionResetWaiter = waiter
        end
        return
    end

    local frame = self.VersionResetFrame or BuildFrame()
    self.VersionResetFrame = frame
    self._ktVersionResetPreview = preview and true or nil
    local forced = self:IsVersionDataResetForced()
    if preview == "forever" then forced = true elseif preview == "retail" then forced = false end
    Refresh(frame, forced)
    if preview then frame.CloseButton:Show() else frame.CloseButton:Hide() end
    pcall(frame.EnableKeyboard, frame, preview and true or false)
    if not frame:IsShown() then frame:Show() end
end

-- Test view: the window without touching any data. Its buttons, the close
-- button and Escape only close it. mode: "forever" or "retail" (this client's
-- by default). While the real window is pending, that one is shown instead.
function KT:PreviewVersionDataResetPopup(mode)
    if self._ktVersionResetPending then
        return self:ShowVersionDataResetPopup()
    end
    if mode ~= "forever" and mode ~= "retail" then
        mode = self:IsVersionDataResetForced() and "forever" or "retail"
    end
    local frame = self.VersionResetFrame
    if frame and frame:IsShown() and self._ktVersionResetPreview and self._ktVersionResetPreviewMode == mode then
        frame:Hide()
        return
    end
    self._ktVersionResetPreviewMode = mode
    self:ShowVersionDataResetPopup(mode)
end

-- Prints what the game reports for the 3D characters, to tune the framing.
function KT:DebugVersionResetModels()
    local frame = self.VersionResetFrame
    if not frame then
        print("KullThranUI reset test: open it first with /kuiresettest")
        return
    end
    local function Describe(label, actor, scene)
        local okLoaded, loaded = Call(actor, "IsLoaded")
        local box = BoundingBox(actor)
        local raw = { Call(actor, "GetActiveBoundingBox") }
        local rawText = {}
        for i = 1, #raw do
            local v = raw[i]
            rawText[#rawText + 1] = type(v) == "table" and ("{%s,%s,%s}"):format(tostring(v.x), tostring(v.y), tostring(v.z)) or tostring(v)
        end
        print(("KUI %s: IsLoaded=%s/%s box=%s raw=%s framed=%s"):format(label, tostring(okLoaded), tostring(loaded),
            box and ("%.2f,%.2f,%.2f .. %.2f,%.2f,%.2f"):format(unpack(box)) or "none",
            table.concat(rawText, " "), tostring(scene and scene.framedBy)))
    end
    Describe("gnome", frame.Gnome, frame.GnomeScene)
    Describe("goblin", frame.Goblin, frame.GoblinScene)
end

-- /kuiresettest [forever|retail|debug]: opens or closes the test view, or
-- prints the characters' model data.
SLASH_KULLTHRANUIRESETTEST1 = "/kuiresettest"
SlashCmdList.KULLTHRANUIRESETTEST = function(msg)
    local mode = type(msg) == "string" and msg:lower():match("^%s*(%a+)") or nil
    if mode == "debug" then return KT:DebugVersionResetModels() end
    KT:PreviewVersionDataResetPopup(mode)
end

function KT:OnVersionResetButton(which)
    local frame = self.VersionResetFrame
    if self._ktVersionResetPreview then
        if frame then frame:Hide() end
        return
    end
    if which == "reset" then
        self:PerformVersionDataReset()
    elseif which == "keep" and not self:IsVersionDataResetForced() then
        self:KeepDataAfterVersionReset()
        if frame then frame:Hide() end
    end
end

function KT:KeepDataAfterVersionReset()
    if not self._ktVersionResetPending or self:IsVersionDataResetForced() then return end
    self._ktVersionResetPending = false
    if self.db and self.db.global then
        self.db.global[MARK_KEY] = RESET_EPOCH
    end
    -- The installer and the other login popups waited for this answer.
    if self.MaybeAutoOpenInstaller then
        self:MaybeAutoOpenInstaller()
    end
end

function KT:PerformVersionDataReset()
    if self._ktVersionResetRunning then return end
    self._ktVersionResetRunning = true
    self._ktVersionResetPending = false

    local db = self.db
    if db then
        -- Pin AceDB's section caches to the current tables: anything written
        -- while logging out lands in tables that are no longer saved.
        if type(db.keys) == "table" then
            for section in pairs(db.keys) do
                pcall(function() local _ = db[section] end)
            end
        end
        pcall(function() local _ = db.profiles end)
    end

    -- The player's own friendly aura CVars, held by Nameplates while KUI keeps
    -- them at 0: not a setting, and the game could not give them back without it.
    local friendlyAuraCVars
    for _, name in ipairs({ "KullThranUINameplatesDB_Forever", "KullThranUINameplatesDB" }) do
        local saved = _G[name]
        if type(saved) == "table" and saved._friendlyAuraCVarOriginal ~= nil then
            friendlyAuraCVars = saved._friendlyAuraCVarOriginal
            break
        end
    end

    for _, name in ipairs(MODULE_SAVED_VARIABLES) do
        _G[name] = nil
    end
    if friendlyAuraCVars ~= nil then
        local name = self:IsVersionDataResetForced() and "KullThranUINameplatesDB_Forever" or "KullThranUINameplatesDB"
        _G[name] = { _friendlyAuraCVarOriginal = friendlyAuraCVars }
    end
    _G.KT_RAW_NAMEPLATES_DB = nil
    _G.KUI_BOOT_SNAPSHOT = nil

    local fresh = { global = { [MARK_KEY] = RESET_EPOCH } }
    if db then
        rawset(db, "sv", fresh)
    end
    _G.KullThranDB = fresh

    ReloadUI()
end

ns.VersionDataReset = {
    RESET_EPOCH = RESET_EPOCH,
    MARK_KEY = MARK_KEY,
    FRAME_NAME = FRAME_NAME,
    TEXTS = {
        TEXT_TITLE, TEXT_FORCED, TEXT_OPTIONAL, TEXT_FORCED_DETAILS, TEXT_OPTIONAL_DETAILS,
        TEXT_SORRY, TEXT_RESET, TEXT_KEEP,
    },
}
