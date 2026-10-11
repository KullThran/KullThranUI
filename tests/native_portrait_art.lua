local function expect(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function near(actual, expected, label)
    if math.abs(actual - expected) > 0.0001 then
        error(string.format("%s: expected %.4f, got %.4f", label, expected, actual))
    end
end

local function NewRegion(parent)
    local region = {
        parent = parent,
        width = 0,
        height = 0,
        level = 0,
        strata = "LOW",
        shown = true,
        points = {},
        masks = {},
    }

    function region:SetParent(newParent) self.parent = newParent end
    function region:SetClipsChildren(v) self.clipsChildren = v end
    function region:GetParent() return self.parent end
    function region:SetAllPoints(relative) self.allPoints = relative or true end
    function region:ClearAllPoints() self.points = {} end
    function region:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function region:SetSize(width, height) self.width, self.height = width, height end
    function region:SetWidth(width) self.width = width end
    function region:SetHeight(height) self.height = height end
    function region:GetWidth() return self.width end
    function region:GetHeight() return self.height end

    function region:SetFrameStrata(strata) self.strata = strata end
    function region:GetFrameStrata() return self.strata end
    function region:SetFrameLevel(level) self.level = level end
    function region:GetFrameLevel() return self.level end
    function region:EnableMouse(enabled) self.mouseEnabled = enabled end
    function region:Show() self.shown = true end
    function region:Hide() self.shown = false end

    function region:SetAtlas(atlas) self.atlas = atlas end
    function region:SetTexture(texture) self.texture = texture end
    function region:SetBlendMode(mode) self.blendMode = mode end
    function region:SetColorTexture(r, g, b, a) self.colorTexture = { r, g, b, a } end
    function region:SetTexCoord(...) self.texCoord = { ... } end
    function region:SetSnapToPixelGrid(value) self.snap = value end
    function region:SetTexelSnappingBias(value) self.bias = value end
    function region:AddMaskTexture(mask) self.masks[mask] = true end
    function region:RemoveMaskTexture(mask) self.masks[mask] = nil end
    function region:SetJustifyH(value) self.justify = value end
    function region:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
    function region:GetFont() return self.fontPath, self.fontSize, self.fontFlags end
    function region:SetFont(path, size, flags)
        self.fontPath, self.fontSize, self.fontFlags = path, size, flags
    end
    function region:CreateTexture()
        local texture = NewRegion(self)
        self.lastTexture = texture
        return texture
    end
    function region:CreateMaskTexture()
        local mask = NewRegion(self)
        self.lastMask = mask
        return mask
    end
    function region:CreateFontString()
        local fs = NewRegion(self)
        function fs:SetText(text) self.text = text end
        function fs:SetTextColor(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end
        self.lastFontString = fs
        return fs
    end
    function region:GetStatusBarTexture() return self.fill end

    return region
end

_G.InCombatLockdown = function() return false end
_G.CreateFrame = function(_, _, parent) return NewRegion(parent) end
_G.UIParent = NewRegion(nil)
_G.SlashCmdList = {}

_G.C_Texture = {
    GetAtlasInfo = function(atlas)
        if atlas == "UI-HUD-UnitFrame-Target-PortraitOn-Type" then
            return { width = 134, height = 20 }
        end
        if atlas == "UI-HUD-UnitFrame-Player-Portrait-Mask" then
            return {
                width = 64, height = 64, file = "Interface\\Fake\\PlayerPortraitMask",
                leftTexCoord = 0.2, rightTexCoord = 0.8,
                topTexCoord = 0.1, bottomTexCoord = 0.9,
            }
        end
        if atlas == "CircleMask" then
            return {
                width = 64, height = 64, file = "Interface\\Fake\\TargetPortraitMask",
                leftTexCoord = 0.15, rightTexCoord = 0.85,
                topTexCoord = 0.05, bottomTexCoord = 0.95,
            }
        end
        if atlas:find("%-Mask$") then return { width = 132, height = 32 } end
        return {
            width = 198, height = 71, file = "Interface\\Fake\\StockArt",
            leftTexCoord = 0.1, rightTexCoord = 0.9,
            topTexCoord = 0.2, bottomTexCoord = 0.8,
        }
    end,
}

local KT = { VisualThemes = {} }
local mockRenderedTheme = nil
function KT.VisualThemes:GetRenderedTheme() return mockRenderedTheme end
local ace = {}
function ace:GetAddon() return KT end
function _G.LibStub() return ace end

local function LoadAssets()
    local chunk = assert(loadfile("KullThranUI/Modules/VisualThemes/ThemeClientAssets.lua"))
    chunk("KullThranUI", {})
end

local function MakeBar(frame, level)
    local bar = NewRegion(frame)
    bar.level = level
    bar.fill = NewRegion(bar)
    bar.bg = NewRegion(bar)
    return bar
end

local function MakeText(frame)
    local text = NewRegion(frame)
    text:SetFont("font.ttf", 14, "OUTLINE")
    return text
end

local function MakeUnitFrame()
    local frame = NewRegion(nil)
    frame:SetSize(230, 52)
    frame.Health = MakeBar(frame, 2)
    frame.Power = MakeBar(frame, 3)
    frame.Portrait = { backdrop = NewRegion(frame) }
    frame.Portrait.backdrop:SetSize(62, 62)
    frame.Portrait.backdrop._shapeMask = NewRegion(frame.Portrait.backdrop)
    frame.Portrait.backdrop._2d = NewRegion(frame.Portrait.backdrop)

    frame.Portrait.backdrop:SetFrameStrata("MEDIUM")
    frame.Portrait.backdrop:SetFrameLevel(50)
    frame._textOverlay = NewRegion(frame.Health)
    frame.LeftText = MakeText(frame._textOverlay)
    frame.RightText = MakeText(frame._textOverlay)
    frame.CenterText = MakeText(frame._textOverlay)
    local absorb = MakeBar(frame.Health, 3)
    frame.HealthPrediction = { damageAbsorb = absorb }
    frame.Buffs = NewRegion(frame)
    frame.Buffs.spacing = 1
    local castbarBg = NewRegion(frame)
    castbarBg:SetSize(230, 14)
    castbarBg._bgTex = NewRegion(castbarBg)
    castbarBg._ppBorders = { NewRegion(castbarBg), NewRegion(castbarBg), NewRegion(castbarBg), NewRegion(castbarBg) }
    frame.Castbar = NewRegion(castbarBg)
    return frame
end

LoadAssets()

for _, theme in ipairs({"forever", "retail"}) do
    mockRenderedTheme = theme
    for _, unit in ipairs({"player", "target"}) do
        local frame = MakeUnitFrame()
        frame.Portrait.backdrop._3d = NewRegion(frame.Portrait.backdrop)
        frame._ktNativeClassificationKind = "elite"
        frame._ktNativeClassificationHeadReach = 36 * (unit == "player" and .88 or 1)
        frame._ktNativeClassificationScale = unit == "player" and .88 or 1
        frame._ktCircularPortrait = true
        frame._ktHideForeverPortraitArt = true
        local extension = unit == "player" and (30 - math.sqrt(math.max(0, (30*.88)^2 - 27*27))) or 3
        frame._ktRingHugShift = unit == "player" and -extension or extension
        expect(KT.VisualThemes:ApplyForeverUnitFrameArt(frame, frame.Portrait.backdrop, unit), true, "native layout applies")
        expect(frame._ktForeverPortraitArt.shown, false, "native dragon hides base ornament")
        expect(frame._ktForeverPortraitArtFill.shown, false, "native dragon hides base fill")
        expect(frame.Portrait.backdrop._shapeMask.atlas, "CircleMask", "native portrait uses circular opening")
        local dragonScale = frame._ktNativeClassificationScale
        local height = 60 * 230 / 232
        near(frame.Portrait.backdrop._ktStockPortraitMaskExpand, -height * (1-dragonScale)/2, "mask matches reduced opening")
        near(frame.Portrait.backdrop.points[1][5], (unit == "player" and -14 or -19) * 230 / 232,
            "only modern Player portrait rises by 5px")
        near(frame.Portrait.backdrop.points[1][4], (unit == "player" and 27 or -24) * 230 / 232,
            "only modern Player portrait moves right by 3px")
        local model = frame.Portrait.backdrop._3d
        near(model.points[1][4], height * ((1-dragonScale)/2 + 2/58*dragonScale), "native model has minimal rim inset")
        near(model.points[2][4], -height * ((1-dragonScale)/2 + 2/58*dragonScale), "native model retains almost full opening width")
        local textLeft = frame.LeftText.points[1][4]
        local textRight = textLeft + frame.LeftText:GetWidth()
        local scale = frame:GetWidth() / 232
        if unit == "player" then
            expect(textLeft > (54 + 36 * dragonScale * 60 / 58) * scale, true, "name clears actual mirrored atlas head")
        else
            expect(textRight < (178 - 36 * dragonScale * 60 / 58) * scale, true, "name clears actual target atlas head")
        end
        near(frame.Health:GetWidth(), 124 * 230 / 232 + extension, "near-edge extension keeps outer edge")
        if unit == "player" then
            expect(frame.Portrait.backdrop:GetFrameLevel() > frame.Power:GetFrameLevel(), true,
                "native Player portrait covers the extended bars")
        else
            expect(frame.Portrait.backdrop:GetFrameLevel() < frame.Health:GetFrameLevel(), true,
                "native Target layers retain their previous layout")
        end
        frame._ktNativeClassificationKind = nil
        frame._ktCircularPortrait = false
        frame._ktHideForeverPortraitArt = false
        frame._ktRingHugShift = 0
        KT.VisualThemes:ApplyForeverUnitFrameArt(frame, frame.Portrait.backdrop, unit)
        expect(frame._ktForeverPortraitArt.shown, true, "ordinary unit restores base ornament")
        near(frame.Portrait.backdrop._3d.points[1][4], 0, "removing dragon restores model viewport")
        expect(frame.Portrait.backdrop:GetFrameLevel() < frame.Health:GetFrameLevel(), true,
            "leaving modern dragon restores ordinary portrait layering")
        near(frame.Health:GetWidth(), 124 * 230 / 232, "ordinary unit restores bar geometry")
    end
end
mockRenderedTheme = "classic"
local classic = MakeUnitFrame()
classic._ktNativeClassificationKind = "elite"
classic._ktNativeClassificationScale = .88
classic.Portrait.backdrop._3d = NewRegion(classic.Portrait.backdrop)
expect(KT.VisualThemes:ApplyClassicUnitFrameArt(classic, classic.Portrait.backdrop, "player"), true,
    "Classic seats reduced modern Player dragon portrait")
local classicSize = classic.Portrait.backdrop:GetHeight()
near(classic.Portrait.backdrop._ktStockPortraitMaskExpand, -classicSize*.06,
    "Classic mask follows reduced aperture")
near(classic.Portrait.backdrop._3d.points[1][4], classicSize*(.06 + 2/58*.88),
    "Classic model follows reduced aperture")
expect(classic._ktClassicPortraitArt:GetWidth() < 232, true,
    "modern Player dragon removes the portrait-ring portion of Classic sheet")
expect(classic._ktClassicNativeBarClip.clipsChildren, true, "Classic atlas fragment is clipped")
near(classic._ktClassicNativeBarClip.points[1][4], 106, "Classic atlas cannot cross original bar boundary")
expect(classic.Portrait.backdrop:GetFrameLevel() > classic._ktClassicNativeBarClip:GetFrameLevel(), true,
    "portrait draws strictly above Classic atlas fragment")
near(classic.Health.points[1][4] + classic.Health:GetWidth(), 225,
    "Classic native extension retains health outer edge")
near(classic.Power.points[1][4] + classic.Power:GetWidth(), 225,
    "Classic native extension retains power outer edge")
expect(classic.Portrait.backdrop:GetFrameLevel() > classic.Power:GetFrameLevel(), true,
    "Classic photo covers extended bars")
classic._ktNativeClassificationKind = nil
classic._ktNativeClassificationScale = 1
KT.VisualThemes:ApplyClassicUnitFrameArt(classic, classic.Portrait.backdrop, "player")
near(classic._ktClassicPortraitArt:GetWidth(), 232, "leaving dragon restores complete Classic sheet")
near(classic.Power.points[1][4], 106, "leaving dragon restores Classic power anchor")
near(classic.Power:GetWidth(), 119, "leaving dragon restores Classic power width")
expect(classic._ktClassicPortraitArt:GetParent(), classic._ktClassicArtHost,
    "leaving modern dragon restores Classic art parent")
expect(classic._ktClassicNativeBarClip.shown, false, "leaving dragon removes clipping")
print("native_portrait_art: ok")
