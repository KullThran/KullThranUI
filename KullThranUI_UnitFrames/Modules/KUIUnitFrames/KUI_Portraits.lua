-- Portraits of the oUF unit frames: box, layers, modes, shape, facing, seating and the event frame.
-- One file for Retail and Forever; ctx.client selects the few per-client rules.
-- Private state lives in _pt* fields on the objects it belongs to. Timer callbacks are built once per
-- box or model, so no update path allocates.

local _, ns = ...

local max, floor = math.max, math.floor
local pcall, type = pcall, type

-- Context, captured by Init. KT's fields and db.profile are read at each use.
local Ctx, KT, IsForever
local UnitToSettingsKey, GetSettingsForUnit, ResolveSafeClassToken, AnchorHealth
local PP_Point, PP_Size, PP_Width, PP_Height, PP_DisablePixelSnap, PP_SetHiddenEdge

local CLASS_SHEET = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CELL_TRIM = 0.09
local DARK_RIM = 0x11 / 255

-- Layers that carry the shape mask, in pass order.
local MASKED_LAYERS = { "_2d", "_class", "_bg" }

-- Shape tables: fill zoom and media paths, built once.
local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\"
local DEFAULT_FILL = 128 / (128 - 2 * 17)
local FILL_ZOOM, MASK_PATH, BORDER_PATH = {}, {}, {}
for shape, inset in pairs({ portrait = 17, circle = 17, square = 17, csquare = 17, hexagon = 17, diamond = 14, shield = 13 }) do
    FILL_ZOOM[shape] = 128 / (128 - 2 * inset)
    MASK_PATH[shape] = MEDIA .. shape .. "_mask.tga"
    BORDER_PATH[shape] = MEDIA .. shape .. "_border.tga"
end

-- Class cells: the client's table, or the stand-in grid when it is absent at load.
local ClassCells = CLASS_ICON_TCOORDS
if not ClassCells then
    local edges = { 0, 0.25, 0.496, 0.742, 0.988 }
    local grid = {
        { "WARRIOR", "MAGE", "ROGUE", "DRUID" },
        { "HUNTER", "SHAMAN", "PRIEST", "WARLOCK" },
        { "PALADIN", "DEATHKNIGHT", "MONK", "DEMONHUNTER" },
        { "EVOKER" },
    }
    ClassCells = {}
    for row, names in ipairs(grid) do
        for col, token in ipairs(names) do
            ClassCells[token] = { edges[col], edges[col + 1], edges[row], edges[row + 1] }
        end
    end
end

local ApplyFacing

---------------------------------------------------------------------------------------------------
-- Modes and class art
---------------------------------------------------------------------------------------------------

-- Class art is for players only: NPCs also report a class (usually WARRIOR).
local function ResolveClassToken(unit)
    if not (unit and UnitIsPlayer(unit)) then return nil end
    return ResolveSafeClassToken(unit) or nil
end

local function ResolveMode(unit, settings)
    local mode = settings and settings.portraitMode
    if not mode then
        local profile = Ctx.db and Ctx.db.profile
        mode = profile and profile.portraitMode or "2d"
    end
    if mode == "class" and not ResolveClassToken(unit) then
        return "2d"
    end
    return mode
end

-- Draws a class cell, trimmed. The trimmed cell stays on the texture for the facing pass.
local function ApplyClassIcon(tex, token, style)
    local cell = ClassCells[token]
    if not cell then return false end
    local l, r, t, b = cell[1], cell[2], cell[3], cell[4]
    local dx, dy = (r - l) * CELL_TRIM, (b - t) * CELL_TRIM
    l, r, t, b = l + dx, r - dx, t + dy, b - dy
    tex:SetTexture(CLASS_SHEET)
    tex:SetTexCoord(l, r, t, b)
    tex._ptCellL, tex._ptCellR, tex._ptCellT, tex._ptCellB = l, r, t, b
    return true
end

-- Refreshes the class art of a box for a unit, when the unit's mode is class.
local function RefreshClassArt(box, unit)
    local classTex = box._class
    if not classTex then return end
    local profile = Ctx.db and Ctx.db.profile
    local settings = profile and profile[UnitToSettingsKey(unit) or unit]
    if ResolveMode(unit, settings) ~= "class" then return end
    local token = ResolveClassToken(unit)
    if not token then
        classTex:Hide()
        return
    end
    ApplyClassIcon(classTex, token, settings and settings.classThemeStyle or "modern")
    ApplyFacing(classTex, unit, settings, true)
    classTex:Show()
end

---------------------------------------------------------------------------------------------------
-- Facing
---------------------------------------------------------------------------------------------------

-- Target-is-player test; a raised error or a secret result counts as no.
local function TargetIsPlayer()
    local isUnit = UnitIsUnit
    if not isUnit then return false end
    local ok, same = pcall(isUnit, "target", "player")
    if not ok then return false end
    local isSecret = issecretvalue
    if isSecret and isSecret(same) then return false end
    return same and true or false
end

-- Forever druid form models whose portrait camera shows them facing right, like the
-- humanoid models (Tauren bear, Night Elf and Tauren moonkin; read from the client's
-- model files). A target wearing one needs the same flip as a humanoid target.
local RIGHT_FACING_FORMS = { [123680] = true, [7581777] = true, [7581785] = true }

-- True when the player is a druid in a form that flips the portrait.
local function DruidFormFlips()
    local getForm = GetShapeshiftForm
    if not getForm then return false end
    local okClass, _, token = pcall(UnitClass, "player")
    if not okClass or token ~= "DRUID" then return false end
    local okForm, form = pcall(getForm)
    if not okForm or type(form) ~= "number" or form <= 0 then return false end
    local getId = GetShapeshiftFormID
    if getId then
        local okId, id = pcall(getId)
        local isSecret = issecretvalue
        if okId and not (isSecret and isSecret(id)) and type(id) == "number" then
            -- Moonkin portraits already face inward.
            if id == 31 then return false end
            if id == 5 or id == 8 then
                -- Forever's bear differs by race: the portrait camera of the Tauren bear
                -- model shows it facing right (inward), the Night Elf bear's facing left.
                -- Read from the client's model files; Retail's bear faces inward.
                local themes = KT.VisualThemes
                if themes and themes:GetClientFlavor() == "forever" then
                    local okRace, _, race = pcall(UnitRace, "player")
                    return okRace and race == "NightElf" or false
                end
                return false
            end
        end
    end
    return true
end

local function GetFacing(unit, settings)
    local mode = settings and settings.portraitFacingMode
    if mode == "normal" or mode == "flipped" then return mode end

    local profile = Ctx.db and Ctx.db.profile
    local themes = KT.VisualThemes
    local theme = themes and themes:GetRenderedTheme()
    local stock = theme == "classic" or theme == "forever" or theme == "retail" or theme == "kui"
        or (profile and profile.frameArtKit == "classic")

    if stock then
        if unit == "target" then
            if TargetIsPlayer() then
                if GetFacing("player", GetSettingsForUnit("player")) == "flipped" then return "normal" end
            end
            return "flipped"
        elseif unit == "player" then
            return DruidFormFlips() and "flipped" or "normal"
        end
    end

    local saved = settings and settings.portraitFacing
    if unit == "player" and not saved then
        return DruidFormFlips() and "flipped" or "normal"
    end
    return saved or (unit == "player" and "flipped" or "normal")
end

-- The probe model reported a load: refresh the 2D capture if it is still the same unit.
local function ProbeOnModelLoaded(self)
    if self._ptLoading then return end
    local unit = self._ptUnit
    local ok, guid = pcall(UnitGUID, unit)
    if not ok then return end
    local isSecret = issecretvalue
    if isSecret and isSecret(guid) then return end
    local tex = self._ptTex
    if guid ~= tex._ptGuid then return end
    local capture = SetPortraitTexture
    if capture then capture(tex, unit) end
    ApplyFacing(tex, unit, GetSettingsForUnit(unit))
end

-- Builds the hidden probe of a texture. Runs once per texture.
local function BuildProbe(tex, unit)
    local probe = CreateFrame("PlayerModel", nil, UIParent)
    probe:SetSize(32, 32)
    if probe.SetKeepModelOnHide then probe:SetKeepModelOnHide(true) end
    probe:Hide()
    probe._ptTex, probe._ptUnit = tex, unit
    probe:SetScript("OnModelLoaded", ProbeOnModelLoaded)
    tex._ptProbe = probe
    return probe
end

ApplyFacing = function(tex, unit, settings, fullTexture)
    if not tex then return end
    local mode = settings and settings.portraitFacingMode

    -- Class cell: facing comes from the explicit mode, else from the side.
    if fullTexture and tex._ptCellL then
        local flipped
        if mode == "normal" or mode == "flipped" then
            flipped = mode == "flipped"
        else
            local side = settings and settings.portraitSide
            if side == "left" or side == "right" then
                flipped = side == "right"
            else
                flipped = unit == "target" or unit == "focus" or unit == "targettarget"
            end
        end
        if flipped then
            tex:SetTexCoord(tex._ptCellR, tex._ptCellL, tex._ptCellT, tex._ptCellB)
        else
            tex:SetTexCoord(tex._ptCellL, tex._ptCellR, tex._ptCellT, tex._ptCellB)
        end
        return
    end

    local facing = GetFacing(unit, settings)

    -- Model probe: the target's model file may decide the facing.
    if unit == "target" and not fullTexture and mode ~= "normal" and mode ~= "flipped" and not TargetIsPlayer() then
        local isMirror, getGuid = KT.IsPortraitMirrorModel, UnitGUID
        if isMirror and CreateFrame and getGuid then
            local ok, guid = pcall(getGuid, unit)
            local isSecret = issecretvalue
            if ok and not (isSecret and isSecret(guid)) and guid then
                local probe = tex._ptProbe or BuildProbe(tex, unit)
                if guid ~= tex._ptGuid then
                    tex._ptGuid = guid
                    probe._ptLoading = true
                    probe:ClearModel()
                    probe:SetUnit(unit)
                    probe._ptLoading = false
                end
                local okId, id = pcall(probe.GetModelFileID, probe)
                if okId and not (isSecret and isSecret(id)) and type(id) == "number" and id > 0 then
                    facing = (isMirror(id) or RIGHT_FACING_FORMS[id]) and "flipped" or "normal"
                end
            end
        end
    end

    local profile = Ctx.db and Ctx.db.profile
    if fullTexture or (profile and profile.portraitStyle == "circular") then
        if facing == "flipped" then tex:SetTexCoord(1, 0, 0, 1) else tex:SetTexCoord(0, 1, 0, 1) end
    elseif facing == "flipped" then
        tex:SetTexCoord(0.85, 0.15, 0.15, 0.85)
    else
        tex:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    end
end

---------------------------------------------------------------------------------------------------
-- Rim colour
---------------------------------------------------------------------------------------------------

local function ClassColour(unit)
    local token = ResolveSafeClassToken(unit)
    if not token then return nil end
    local custom, raid = CUSTOM_CLASS_COLORS, RAID_CLASS_COLORS
    return (custom and custom[token]) or (raid and raid[token]) or nil
end

local function CircularColour(frame, S, unit, profile)
    if profile then
        if profile.circularPortraitBorderUseCustomColor == true then
            local c = profile.circularPortraitBorderColor
            if type(c) == "table" then return c.r or 1, c.g or 1, c.b or 1 end
        end
        if profile.darkTheme then return DARK_RIM, DARK_RIM, DARK_RIM end
    end
    if S then
        if S.healthClassColored == false then
            local c = S.customFillColor
            if c then return c.r or 1, c.g or 1, c.b or 1 end
        else
            local c
            if unit == "pet" then
                c = ClassColour("player")
                if c then return c.r, c.g, c.b end
            end
            if unit and UnitExists(unit) then
                if UnitIsPlayer(unit) then
                    c = ClassColour(unit)
                    if c then return c.r, c.g, c.b end
                else
                    local tapDenied = UnitIsTapDenied
                    if tapDenied and tapDenied(unit) then return 0.6, 0.6, 0.6 end
                    c = FACTION_BAR_COLORS[UnitReaction(unit, "player")]
                    if c then return c.r, c.g, c.b end
                end
            end
        end
    end
    local health = frame.Health
    if health then
        local bar = health:GetStatusBarTexture()
        if bar then
            local r, g, b = bar:GetVertexColor()
            if r then return r, g, b end
        end
        return health:GetStatusBarColor()
    end
    return 1, 1, 1
end

local function DetachedColour(S, unit, profile)
    local custom = S and S.detachedPortraitBorderColor
    local c
    if S and S.detachedPortraitClassColor then
        if profile and profile.darkTheme then
            c = ClassColour("player")
            if c then return c.r, c.g, c.b end
        end
        if unit and UnitExists(unit) then
            if UnitIsPlayer(unit) then
                c = ClassColour(unit)
                if c then return c.r, c.g, c.b end
            else
                local tapDenied = UnitIsTapDenied
                if tapDenied and tapDenied(unit) then return 0.6, 0.6, 0.6 end
                c = FACTION_BAR_COLORS[UnitReaction(unit, "player")]
                if c then return c.r, c.g, c.b end
            end
        end
        c = ClassColour("player")
        if c then return c.r, c.g, c.b end
    end
    if custom then return custom.r or 0, custom.g or 0, custom.b or 0 end
    return 0, 0, 0
end

---------------------------------------------------------------------------------------------------
-- Shape
---------------------------------------------------------------------------------------------------

-- Seats the mask for a stock renderer and refreshes its membership on the layers.
local function StockMaskFit(box)
    local mask = box._shapeMask
    if not mask then return end
    local e = box._ktStockPortraitMaskExpand or 0
    mask:ClearAllPoints()
    mask:SetPoint("TOPLEFT", box, "TOPLEFT", -e, e)
    mask:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", e, -e)
    mask:Show()
    for i = 1, 3 do
        local layer = box[MASKED_LAYERS[i]]
        if layer and layer.AddMaskTexture then
            local remove = layer.RemoveMaskTexture
            if remove then pcall(remove, layer, mask) end
            pcall(layer.AddMaskTexture, layer, mask)
        end
    end
end

-- Anchors a circular box beside the health bar and sets the levels and the hidden border edge.
local function CircularAnchor(box, S, unit)
    local frame = box:GetParent()
    if not frame or box._ktStockPortraitAnchor then return end
    local health = frame.Health
    if not health then return end

    local side = S and S.portraitSide or box._ptSide
    if not side then
        side = (unit == "player" or unit == "pet") and "left" or "right"
    end
    local overlap = max(0, box:GetWidth() / 2)
    local X, Y = S and S.portraitX or 0, S and S.portraitY or 0

    box:ClearAllPoints()
    if side == "top" then
        box:SetPoint("BOTTOM", health, "TOP", X, Y)
    elseif side == "left" then
        box:SetPoint("RIGHT", health, "LEFT", overlap + X, Y)
    else
        box:SetPoint("LEFT", health, "RIGHT", -overlap + X, Y)
    end

    local frameLevel = frame:GetFrameLevel()
    local level = max(50, frameLevel + 20, (health:GetFrameLevel() or frameLevel + 2) + 1)
    box:SetFrameLevel(level)
    local model, rimFrame, power = box._3d, box._ptRimFrame, frame.Power
    if model then model:SetFrameLevel(level + 1) end
    if rimFrame then rimFrame:SetFrameLevel(level + 3) end
    if power then power:SetFrameLevel(frameLevel + 1) end

    local edge
    if side == "left" then edge = 3 elseif side == "right" then edge = 4 end
    PP_SetHiddenEdge(frame.unifiedBorder, edge)
end

-- Builds a box's next-frame callback. Runs once per box; it uses the latest pass's values.
local function BuildAnchorTimer(box)
    local function fire()
        local profile = Ctx.db and Ctx.db.profile
        if profile and profile.portraitStyle == "circular" then
            CircularAnchor(box, box._ptAnchorS, box._ptAnchorUnit)
        end
    end
    box._ptAnchorTimer = fire
    return fire
end

local function ApplyShape(box, S, unitToken)
    local rim = box._shapeBorderTex
    local mask = box._shapeMask
    local model = box._3d
    local square = box._sqBorderTexs

    -- Native classification seat.
    if unitToken == "player" and box._ktNativeClassificationActive then
        local s = box._ktNativeClassificationScale or 1
        local H = box:GetHeight()
        if not mask then
            mask = box:CreateMaskTexture()
            box._shapeMask = mask
        end
        local i = H * (1 - s) / 2
        mask:SetAtlas("CircleMask", false)
        mask:SetTexCoord(0, 1, 0, 1)
        mask:ClearAllPoints()
        mask:SetPoint("TOPLEFT", box, "TOPLEFT", i, -i)
        mask:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -i, i)
        mask:Show()
        box._ktStockPortraitMaskExpand = -i
        for n = 1, 3 do
            local layer = box[MASKED_LAYERS[n]]
            if layer then
                layer:RemoveMaskTexture(mask)
                layer:AddMaskTexture(mask)
            end
        end
        if rim then rim:Hide() end
        if square then for n = 1, #square do square[n]:Hide() end end
        if model then
            local j = H * ((1 - s) / 2 + 2 * s / 58)
            model:ClearAllPoints()
            model:SetPoint("TOPLEFT", box, "TOPLEFT", j, -j)
            model:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -j, j)
        end
        return
    end

    -- A stock renderer owns anchor and rim.
    if box._ktStockPortraitAnchor then
        StockMaskFit(box)
        if rim then rim:Hide() end
        if square then for n = 1, #square do square[n]:Hide() end end
        return
    end

    local profile = Ctx.db and Ctx.db.profile
    local style = profile and profile.portraitStyle or "attached"
    local tex2d, classTex = box._2d, box._class
    local circular = style == "circular"

    -- Plain pass.
    if not circular and style ~= "detached" then
        if mask then
            for n = 1, 3 do
                local layer = box[MASKED_LAYERS[n]]
                if layer then layer:RemoveMaskTexture(mask) end
            end
            mask:Hide()
        end
        if rim then rim:Hide() end
        if square then for n = 1, #square do square[n]:Hide() end end
        local h = box:GetHeight()
        if h < 1 then h = 46 end
        local pad = floor(0.08 * h)
        if tex2d then
            tex2d:ClearAllPoints()
            PP_Point(tex2d, "TOPLEFT", box, "TOPLEFT", 0, 0)
            PP_Point(tex2d, "BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
        end
        if model then
            model:ClearAllPoints()
            PP_Point(model, "TOPLEFT", box, "TOPLEFT", 0, 0)
            PP_Point(model, "BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
        end
        if classTex then
            classTex:ClearAllPoints()
            PP_Point(classTex, "TOPLEFT", box, "TOPLEFT", pad, -pad)
            PP_Point(classTex, "BOTTOMRIGHT", box, "BOTTOMRIGHT", -pad, pad)
        end
        return
    end

    -- Shaped pass, in the required order: colour, mask, square borders, rim, fit, circular anchor.
    local shape = circular and "circle" or (S and S.detachedPortraitShape) or "portrait"
    local opacity = (S and S.detachedPortraitBorderOpacity or 100) / 100
    local raw = S and S.detachedPortraitBorderSize or 7
    local grow = 7 - raw
    local showBorder = circular or not (S and S.detachedPortraitBorder == false)

    local parent = box:GetParent()
    local r, g, b
    if circular and parent and parent.Health then
        r, g, b = CircularColour(parent, S, unitToken, profile)
    else
        r, g, b = DetachedColour(S, unitToken, profile)
    end

    local maskPath = MASK_PATH[shape]
    if maskPath then
        if not mask then
            mask = box:CreateMaskTexture()
            box._shapeMask = mask
        end
        mask:ClearAllPoints()
        if raw >= 1 then
            PP_Point(mask, "TOPLEFT", box, "TOPLEFT", 1, -1)
            PP_Point(mask, "BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
        else
            mask:SetAllPoints(box)
        end
        mask:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:Show()
        for n = 1, 3 do
            local layer = box[MASKED_LAYERS[n]]
            if layer then layer:AddMaskTexture(mask) end
        end
    end

    if square then for n = 1, #square do square[n]:Hide() end end

    if not rim then
        local rimFrame = CreateFrame("Frame", nil, box)
        rimFrame:SetAllPoints(box)
        rim = rimFrame:CreateTexture(nil, "OVERLAY")
        box._ptRimFrame = rimFrame
        box._shapeBorderTex = rim
    end
    rim:ClearAllPoints()
    PP_Point(rim, "TOPLEFT", box, "TOPLEFT", -grow, grow)
    PP_Point(rim, "BOTTOMRIGHT", box, "BOTTOMRIGHT", grow, -grow)
    if mask then pcall(rim.RemoveMaskTexture, rim, mask) end
    if showBorder and maskPath then
        rim:SetTexture(BORDER_PATH[shape])
        rim:SetVertexColor(r, g, b, opacity)
        rim:Show()
    else
        rim:Hide()
    end

    local w, h = box:GetWidth(), box:GetHeight()
    if w < 1 then w = 46 end
    if h < 1 then h = 46 end
    local zoom = (circular and 1 or FILL_ZOOM[shape] or DEFAULT_FILL) * ((S and S.portraitArtScale or 100) / 100)
    local sx, sy = (zoom - 1) / 2 * w, (zoom - 1) / 2 * h
    if tex2d then
        tex2d:ClearAllPoints()
        PP_Point(tex2d, "TOPLEFT", box, "TOPLEFT", -sx, sy)
        PP_Point(tex2d, "BOTTOMRIGHT", box, "BOTTOMRIGHT", sx, -sy)
    end
    if classTex then
        local pad = floor(0.08 * h)
        classTex:ClearAllPoints()
        PP_Point(classTex, "TOPLEFT", box, "TOPLEFT", pad - sx, sy - pad)
        PP_Point(classTex, "BOTTOMRIGHT", box, "BOTTOMRIGHT", sx - pad, pad - sy)
    end
    if model then
        local inset = 0
        if box._ktNativeClassificationActive then
            local s = box._ktNativeClassificationScale or 1
            inset = h * ((1 - s) / 2 + 2 * s / 58)
        elseif circular then
            inset = max(0, floor(h / 2 - 0.30 * (h + 2 * grow) + 0.5))
        end
        model:ClearAllPoints()
        PP_Point(model, "TOPLEFT", box, "TOPLEFT", inset, -inset)
        PP_Point(model, "BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
        local level = box:GetFrameLevel()
        model:SetFrameLevel(level + 1)
        box._ptRimFrame:SetFrameLevel(level + 3)
    end

    if circular then
        CircularAnchor(box, S, unitToken)
        box._ptAnchorS, box._ptAnchorUnit = S, unitToken
        C_Timer.After(0, box._ptAnchorTimer or BuildAnchorTimer(box))
    end
end

-- Repaints the rim of a circular portrait. Runs on every health update.
local function UpdateCircularBorder(frame)
    if not frame or not frame.Health then return end
    local portrait = frame.Portrait
    local box = portrait and portrait.backdrop
    if not box then return end
    local profile = Ctx.db and Ctx.db.profile
    if not profile or profile.portraitStyle ~= "circular" then return end

    local rim = box._shapeBorderTex
    if box._ktStockPortraitAnchor then
        StockMaskFit(box)
        if rim then rim:Hide() end
        return
    end
    if not rim then return end
    local indicator = frame._kuiClassificationIndicator
    if indicator and indicator:IsShown() then
        rim:Hide()
        return
    end

    local unit = frame.unit
    local S = profile[UnitToSettingsKey(unit)]
    local r, g, b = CircularColour(frame, S, unit, profile)
    rim:SetVertexColor(r, g, b, (S and S.detachedPortraitBorderOpacity or 100) / 100)
    rim:Show()
end

---------------------------------------------------------------------------------------------------
-- The model
---------------------------------------------------------------------------------------------------

-- Applies the camera look for a unit, with settings read fresh.
local function ApplyLook(model, unit)
    if not (UnitIsConnected(unit) and UnitIsVisible(unit)) then return end
    local getYaw, applyCamera = KT.Portrait3DYaw, KT.ApplyPortrait3DCamera
    if not (getYaw and applyCamera) then return end
    local profile = Ctx.db and Ctx.db.profile
    local s = profile and profile[UnitToSettingsKey(unit)]
    local zoom = max(0.25, (s and s.portrait3DZoom or 125) / 100)
    local side = s and s.portraitSide or model._ptBox._ptSide
    local yaw, formZoom, formShift, viewShift = getYaw(unit, side, s and s.portraitFacingMode, false, s and s.portrait3DRotation, model)
    applyCamera(model, yaw, zoom * formZoom, (s and s.portrait3DX or 0) / 100 + formShift, (s and s.portrait3DY or 0) / 100, viewShift)
end

-- Builds one delayed-look callback. Timers of one delay fire in the order they started, so only the
-- one that empties its pending count belongs to the latest PostUpdate.
local function BuildLookTimer(model, pendingKey)
    return function()
        local left = model[pendingKey] - 1
        model[pendingKey] = left
        if left == 0 and model._camUnit == model._ptLookUnit then
            ApplyLook(model, model._ptLookUnit)
        end
    end
end

local function ModelPostUpdate(self)
    local box = self._ptBox
    local unit = box._ptFrame.unit or box._ptUnit
    self._camUnit = unit
    self._ptLookUnit = unit
    local debugger = KT.Portrait3DDebug
    if debugger then debugger.Record(self, "PostUpdate", unit) end
    ApplyLook(self, unit)
    self._ptPendingA = self._ptPendingA + 1
    self._ptPendingB = self._ptPendingB + 1
    self._ptPendingC = self._ptPendingC + 1
    local after = C_Timer.After
    after(0.1, self._ptTimerA)
    after(0.35, self._ptTimerB)
    after(1.0, self._ptTimerC)
end

local function ModelOnModelLoaded(self)
    local unit = self._camUnit
    local debugger = KT.Portrait3DDebug
    if debugger then debugger.Record(self, "OnModelLoaded", unit) end
    if unit then ApplyLook(self, unit) end
end

local function ModelOnShow(self)
    local owner = self.__owner
    if owner and owner.Portrait == self and self.ForceUpdate then
        self:ForceUpdate()
    end
end

-- Returns the box's model, building it on first need.
local function EnsureModel(box)
    local model = box._3d
    if model then return model end
    model = CreateFrame("PlayerModel", nil, box)
    PP_Point(model, "TOPLEFT", box, "TOPLEFT", 0, 0)
    PP_Point(model, "BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    model:SetCamera(0)
    if model.SetKeepModelOnHide then model:SetKeepModelOnHide(true) end
    model:Hide()
    model._ptBox = box
    model._ptPendingA, model._ptPendingB, model._ptPendingC = 0, 0, 0
    model._ptTimerA = BuildLookTimer(model, "_ptPendingA")
    model._ptTimerB = BuildLookTimer(model, "_ptPendingB")
    model._ptTimerC = BuildLookTimer(model, "_ptPendingC")
    model.PostUpdate = ModelPostUpdate
    model:SetScript("OnModelLoaded", ModelOnModelLoaded)
    model:SetScript("OnShow", ModelOnShow)
    box._3d = model
    return model
end

---------------------------------------------------------------------------------------------------
-- The 2D post-update
---------------------------------------------------------------------------------------------------

-- Runs after oUF's SetPortraitTexture. Facing uses the unit and settings from Create; the anchors
-- use fresh settings.
local function TexturePostUpdate(self, _, hasStateChanged)
    local box = self._ptBox
    local unit = box._ptUnit
    PP_DisablePixelSnap(self)
    if IsForever and hasStateChanged then
        self._ptGuid = false
    end
    ApplyFacing(self, unit, box._ptSettings)
    if self.isClass then
        RefreshClassArt(box, unit)
    end

    local profile = Ctx.db and Ctx.db.profile
    local style = profile and profile.portraitStyle or "attached"
    self:ClearAllPoints()
    if style == "detached" or style == "circular" then
        local settings = profile and profile[UnitToSettingsKey(unit)]
        local w, h = box:GetWidth(), box:GetHeight()
        if w < 1 then w = 46 end
        if h < 1 then h = 46 end
        local zoom = 1
        if style == "detached" then
            zoom = FILL_ZOOM[settings and settings.detachedPortraitShape or "portrait"] or DEFAULT_FILL
        end
        zoom = zoom * (settings and settings.portraitArtScale or 100) / 100
        local e = (zoom - 1) / 2
        PP_Point(self, "TOPLEFT", box, "TOPLEFT", -(e * w), e * h)
        PP_Point(self, "BOTTOMRIGHT", box, "BOTTOMRIGHT", e * w, -(e * h))
    else
        PP_Point(self, "TOPLEFT", box, "TOPLEFT", 0, 0)
        PP_Point(self, "BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    end

    if box._ktStockPortraitAnchor then
        StockMaskFit(box)
        if not box._ptFrame._kuiClassificationPortraitActive then
            box:SetClipsChildren(true)
        end
    end
end

---------------------------------------------------------------------------------------------------
-- Creation and swap
---------------------------------------------------------------------------------------------------

local function Create(frame, side, frameHeight, unit)
    local profile = Ctx.db and Ctx.db.profile
    local style = profile and profile.portraitStyle or "attached"
    if style == "none" then return nil end

    local S = profile and profile[UnitToSettingsKey(unit)]
    local H = frameHeight or 46
    local shaped = style == "detached" or style == "circular"

    local box = CreateFrame("Frame", nil, frame)
    box._isPortraitBackdrop = true
    box._ptFrame, box._ptSide, box._ptUnit, box._ptSettings = frame, side, unit, S
    box:SetFrameStrata("LOW")
    box:SetFrameLevel(max(50, frame:GetFrameLevel() + 20))
    box:EnableMouse(false)
    box:SetClipsChildren(true)

    local edge = max(8, H + (S and S.portraitSize or 0) + (shaped and 10 or 0))
    PP_Size(box, edge, edge)

    if style == "detached" then
        local rel = frame.Health or frame
        local X, Y = S and S.portraitX or 0, S and S.portraitY or 0
        if side == "top" then
            box:SetPoint("BOTTOM", rel, "TOP", X, ns.FrameLayout.DetachedGap + Y + 5)
        elseif side == "left" then
            box:SetPoint("TOPRIGHT", rel, "TOPLEFT", -ns.FrameLayout.DetachedGap + X, Y + 5)
        else
            box:SetPoint("TOPLEFT", rel, "TOPRIGHT", ns.FrameLayout.DetachedGap + X, Y + 5)
        end
    elseif style ~= "circular" then
        local corner = (side == "left" or (side == "top" and unit == "player")) and "TOPLEFT" or "TOPRIGHT"
        PP_Point(box, corner, frame, corner, 0, 0)
    end

    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(0.1, 0.1, 0.1, 1)
    PP_Point(bg, "TOPLEFT", box, "TOPLEFT", 0, 0)
    PP_Point(bg, "BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    box._bg = bg

    local tex2d = box:CreateTexture(nil, "ARTWORK")
    tex2d._ptBox = box
    tex2d.PostUpdate = TexturePostUpdate
    box._2d = tex2d

    local classTex = box:CreateTexture(nil, "ARTWORK")
    classTex:SetAlpha(0.8)
    box._class = classTex
    ApplyClassIcon(classTex, ResolveSafeClassToken(unit) or "WARRIOR", S and S.classThemeStyle or "modern")

    ApplyFacing(tex2d, unit, S)
    ApplyFacing(classTex, unit, S, true)

    local mode = ResolveMode(unit, S)
    if mode == "none" then
        tex2d:Hide()
        classTex:Hide()
        box:Hide()
        return nil
    end

    local element
    if mode == "3d" then
        element = EnsureModel(box)
        element.is2D = false
        tex2d:Hide()
        classTex:Hide()
        element:Show()
    elseif mode == "class" then
        element = tex2d
        element.is2D = true
        element.isClass = true
        tex2d:Hide()
        classTex:Show()
    else
        element = tex2d
        element.is2D = true
        tex2d:Show()
        classTex:Hide()
    end
    element.backdrop = box

    ApplyShape(box, S, unit)

    local health = frame.Health
    if health then
        health.PostUpdate = function(self)
            UpdateCircularBorder(self.__owner or frame)
        end
        UpdateCircularBorder(frame)
    end
    return element
end

local function SwapMode(frame)
    local current = frame.Portrait
    local box = current and current.backdrop
    local tex2d = box and box._2d
    if not tex2d then return end

    local unit = frame.unit or frame:GetAttribute("unit")
    local profile = Ctx.db and Ctx.db.profile
    local S = profile and profile[UnitToSettingsKey(unit)]
    local wanted = ResolveMode(unit, S)
    local mode = current.isClass and "class" or (current.is2D and "2d" or "3d")
    if wanted == mode then return end

    if frame:IsElementEnabled("Portrait") then
        frame:DisableElement("Portrait")
    end
    local model = box._3d
    if model then
        model:ClearModel()
        model:Hide()
    end
    tex2d:Hide()
    local classTex = box._class
    classTex:Hide()

    if wanted == "class" then
        local token = ResolveClassToken(unit)
        if token then
            ApplyClassIcon(classTex, token, S and S.classThemeStyle or "modern")
            ApplyFacing(classTex, unit, S, true)
            classTex:Show()
            tex2d.backdrop = box
            tex2d.is2D = true
            tex2d.isClass = true
            frame.Portrait = tex2d
            return
        end
    elseif wanted == "3d" then
        model = EnsureModel(box)
        model:Show()
        model.backdrop = box
        model.is2D = false
        model.isClass = nil
        frame.Portrait = model
        frame:EnableElement("Portrait")
        model:ForceUpdate()
        return
    end

    tex2d:Show()
    tex2d.backdrop = box
    tex2d.is2D = true
    tex2d.isClass = nil
    frame.Portrait = tex2d
    frame:EnableElement("Portrait")
    tex2d:ForceUpdate()
end

---------------------------------------------------------------------------------------------------
-- Event frame
---------------------------------------------------------------------------------------------------

local function UpdaterOnEvent(self, event, arg1)
    local first, second
    if event == "UNIT_TARGET" then
        if arg1 == "target" then
            first = "targettarget"
        elseif arg1 == "focus" then
            first = "focustarget"
        else
            return
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        first, second = "target", "targettarget"
    elseif event == "PLAYER_FOCUS_CHANGED" then
        first, second = "focus", "focustarget"
    elseif event == "UPDATE_SHAPESHIFT_FORM" then
        first = "player"
    elseif event == "UNIT_PET" and arg1 == "player" then
        first = "pet"
    else
        return
    end

    local frames = self._ptFrames
    local key = first
    while key do
        local frame = frames[key]
        local portrait = frame and frame.Portrait
        local box = portrait and portrait.backdrop
        if box then
            local profile = Ctx.db and Ctx.db.profile
            local S = profile and profile[UnitToSettingsKey(key) or key]
            if (profile and profile.portraitStyle == "circular") or (S and S.detachedPortraitClassColor) then
                ApplyShape(box, S, key)
            end
            SwapMode(frame)
            RefreshClassArt(box, key)
            portrait = frame.Portrait
            if frame:IsElementEnabled("Portrait") and portrait.ForceUpdate then
                portrait:ForceUpdate()
            end
        end
        if key == second then
            key = nil
        else
            key = second
        end
    end
end

local function RegisterBorderUpdater(frames)
    local updater = frames._portraitBorderUpdater
    if not updater then
        updater = CreateFrame("Frame")
        frames._portraitBorderUpdater = updater
        updater:RegisterEvent("PLAYER_TARGET_CHANGED")
        updater:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        updater:RegisterEvent("PLAYER_FOCUS_CHANGED")
        updater:RegisterEvent("UNIT_TARGET")
        updater:RegisterEvent("UNIT_PET")
    end
    updater._ptFrames = frames
    updater:SetScript("OnEvent", UpdaterOnEvent)
end

---------------------------------------------------------------------------------------------------
-- Seating
---------------------------------------------------------------------------------------------------

local function PortraitState(settings)
    local profile = Ctx.db and Ctx.db.profile
    local style = profile and profile.portraitStyle or "attached"
    return style ~= "none" and (settings and settings.showPortrait) ~= false, style == "attached"
end

local function PortraitFit(settings, shown, attached, barH, defaultSide)
    local fit = ns.FrameLayout.Portrait(settings, shown, attached, barH, defaultSide)
    return fit.side, fit.edge, fit.width, fit.left, fit.right
end

local function DockShift(shown, attached, side, edge)
    if shown and attached and side == "left" then return -edge end
    return 0
end

local function AttachPortrait(frame, side, height, unit, shown)
    local element = Create(frame, side, height, unit)
    frame.Portrait = element
    frame._portraitSide = side
    if element and not shown then
        element.backdrop:Hide()
    end
end

local function CanSeat(frame, shown, attached)
    local portrait = frame.Portrait
    return portrait and portrait.backdrop and shown and attached and frame.Health
        and not frame._ktForeverLayoutActive and not frame._ktClassicLayoutActive
end

local function SnapInsets(frame, shown, attached, side, left, right)
    local portrait = frame.Portrait
    local box = portrait and portrait.backdrop
    if shown and attached and box then
        local w = box:GetWidth()
        return (side == "left") and w or 0, (side == "right") and w or 0
    end
    return left, right
end

local function SeatHealth(frame, settings, side, top)
    local portrait = frame.Portrait
    local box = portrait and portrait.backdrop
    local w = box and box:GetWidth() or 0
    frame.Health:ClearAllPoints()
    AnchorHealth(frame, settings, (side == "left") and w or 0, (side == "right") and w or 0, top)
end

local function SeatPortrait(frame, settings, side, attached, edge, topRise, offX, offY, trim, dockOnly)
    local portrait = frame.Portrait
    local box = portrait and portrait.backdrop
    if not box then return end

    PP_Size(box, edge, edge)
    if trim then
        local frameW, frameH = frame:GetWidth(), frame:GetHeight()
        if box:GetWidth() + settings.frameWidth > frameW + 0.01 then
            PP_Width(box, frameW - settings.frameWidth)
        end
        if box:GetHeight() > frameH + 0.01 then
            PP_Height(box, frameH)
        end
    end

    box:ClearAllPoints()
    if attached then
        local corner = (side == "left") and "TOPLEFT" or "TOPRIGHT"
        PP_Point(box, corner, frame, corner, 0, -(topRise or 0))
    elseif not dockOnly then
        local rel = frame.Health or frame
        local X, Y = offX or 0, offY or 0
        if side == "top" then
            box:SetPoint("BOTTOM", rel, "TOP", X, ns.FrameLayout.DetachedGap + Y)
        elseif side == "left" then
            box:SetPoint("TOPRIGHT", rel, "TOPLEFT", -ns.FrameLayout.DetachedGap + X, Y)
        else
            box:SetPoint("TOPLEFT", rel, "TOPRIGHT", ns.FrameLayout.DetachedGap + X, Y)
        end
    end

    if box._2d then PP_DisablePixelSnap(box._2d) end
    portrait = frame.Portrait
    if frame:IsElementEnabled("Portrait") and portrait.ForceUpdate then
        portrait:ForceUpdate()
    end
end

local function PortraitContext(unit)
    local profile = Ctx.db and Ctx.db.profile
    local s = profile and profile[UnitToSettingsKey(unit) or unit]
    return s, ResolveMode(unit, s) == "class"
end

---------------------------------------------------------------------------------------------------
-- Interface
---------------------------------------------------------------------------------------------------

local Portraits = {}

function Portraits.Init(ctx)
    Ctx = ctx
    KT = ctx.KT
    IsForever = ctx.client == "forever"
    UnitToSettingsKey = ctx.UnitToSettingsKey
    GetSettingsForUnit = ctx.GetSettingsForUnit
    ResolveSafeClassToken = ctx.ResolveSafeClassToken
    AnchorHealth = ctx.AnchorHealth
    local PP = ctx.PP
    PP_Point, PP_Size, PP_Width, PP_Height = PP.Point, PP.Size, PP.Width, PP.Height
    PP_DisablePixelSnap, PP_SetHiddenEdge = PP.DisablePixelSnap, PP.SetHiddenEdge
end

function Portraits.InstallKit(kit)
    kit.PortraitState = PortraitState
    kit.PortraitFit = PortraitFit
    kit.DockShift = DockShift
    kit.AttachPortrait = AttachPortrait
    kit.CanSeat = CanSeat
    kit.SnapInsets = SnapInsets
    kit.SeatHealth = SeatHealth
    kit.SeatPortrait = SeatPortrait
    kit.PortraitContext = PortraitContext
end

Portraits.Create = Create
Portraits.SwapMode = SwapMode
Portraits.ApplyShape = ApplyShape
Portraits.UpdateCircularBorder = UpdateCircularBorder
Portraits.RegisterBorderUpdater = RegisterBorderUpdater
Portraits.ResolveMode = ResolveMode
Portraits.ResolveClassToken = ResolveClassToken
Portraits.ApplyClassIcon = ApplyClassIcon
Portraits.GetFacing = GetFacing
Portraits.ApplyFacing = ApplyFacing
Portraits.PortraitState = PortraitState
Portraits.PortraitFit = PortraitFit
Portraits.DockShift = DockShift
Portraits.AttachPortrait = AttachPortrait
Portraits.CanSeat = CanSeat
Portraits.SnapInsets = SnapInsets
Portraits.SeatHealth = SeatHealth
Portraits.SeatPortrait = SeatPortrait
Portraits.PortraitContext = PortraitContext

ns.Portraits = Portraits
