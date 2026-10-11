local root = arg[1] or "."
local sourceFile = assert(io.open(root .. "/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUIUnitFrames.lua"))
local source = sourceFile:read("*a")
sourceFile:close()
local first = assert(source:find("ns.NATIVE_PLAYER_DRAGON_SCALE =", 1, true))
local last = assert(source:find("-- One time per profile:", first, true))
local ns = {}
local function Region()
    local r = { shown = true }
    function r:SetAllPoints() end
    function r:EnableMouse() end
    function r:SetFrameStrata(v) self.strata = v end
    function r:SetFrameLevel(v) self.level = v end
    function r:SetTexture(v) self.texture = v end
    function r:SetTexCoord(...) self.coords = { ... } end
    function r:SetSize(w, h) self.w, self.h = w, h end
    function r:ClearAllPoints() end
    function r:SetPoint(...) self.point = { ... } end
    function r:Hide() self.shown = false end
    function r:Show() self.shown = true end
    function r:GetWidth() return self.w end
    function r:GetHeight() return self.h end
    function r:CreateTexture() return Region() end
    return r
end
_G.CreateFrame = Region
local atlasWidth = 94
_G.C_Texture = { GetAtlasInfo = function(atlas)
    return { width = atlasWidth, height = 82, file = 123,
        leftTexCoord = 0.2, rightTexCoord = 0.4, topTexCoord = 0.3, bottomTexCoord = 0.5 }
end }
local run = assert(loadstring(source:sub(first, last-1)))
setfenv(run, setmetatable({ ns = ns }, { __index = _G }))
run()
local function near(a, b, why) assert(math.abs(a-b) < 0.0001, why) end
for _, height in ipairs({44, 60, 96}) do
    local scale = height / 60
    local extension = ns.NativePlayerBarExtension(height)
    local barNearEdge = 85 * scale - extension
    local openingBottomEdge = (57 + math.sqrt(math.max(0, (30*.88)^2 - 27*27))) * scale
    near(openingBottomEdge - barNearEdge, 2 * scale, "bar reaches lower arc with 2px overlap")
    local backdrop = Region()
    backdrop:SetSize(height, height)
    backdrop._3d = Region()
    backdrop._ktNativeClassificationScale = .88
    ns.SeatNativePortraitModel(backdrop)
    near(backdrop._3d.point[4], -height * (.06 + 2/58*.88),
        "model matches reduced aperture at every visual-style portrait size")
    backdrop._shapeMask = Region()
    function backdrop._shapeMask:SetAtlas(v) self.atlas = v end
    backdrop._shapeBorderTex = Region()
    backdrop._sqBorderTexs = {Region(), Region()}
    ns.SeatNativePlayerPortrait(backdrop)
    assert(backdrop._shapeMask.atlas == "CircleMask", "late shape refresh retains native circle")
    near(backdrop._shapeMask.point[4], -height*.06, "late shape refresh retains reduced aperture")
    assert(not backdrop._shapeBorderTex.shown and not backdrop._sqBorderTexs[1].shown,
        "late shape refresh cannot resurrect KUI border under modern dragon")
end
-- Reference measured from the extracted 2x atlas's inner circular arc:
-- aperture centre (72,80), diameter 116; vary transparent padding independently.
-- The former width-minus-44 anchor fails for padded 94px and 100px boxes.
for _, reach in ipairs({0.5, 54 / 128, 0.52}) do
for _, boxWidth in ipairs({80, 94, 100}) do
 atlasWidth = boxWidth
 for _, size in ipairs({ 44, 58, 60, 64, 96 }) do
    for _, mirror in ipairs({ false, true }) do
        for _, kind in ipairs({ "rare", "elite", "worldboss" }) do
            local frame, portrait = Region(), Region()
            frame._ktClassRingReach = reach
            portrait:SetSize(size, size)
            assert(ns.ShowNativeClassificationRing(frame, portrait, kind, mirror))
            local tex = frame._kuiNativeClassRing
            local k = size * reach / 29
            near(tex.w, boxWidth * k, "aperture sits on the style border's outer edge")
            near(tex.h, 82 * k, "dragon height scales uniformly")
            assert(tex.point[1] == "CENTER", "anchor aperture to portrait centre")
            local openingX = 36 * k
            local apertureX = mirror and (tex.w - openingX) or openingX
            near(tex.point[4] + apertureX - tex.w / 2, 0, "aperture centre matches portrait horizontally")
            near(tex.point[5] + tex.h / 2 - ns.NATIVE_APERTURE_Y * k, 0, "aperture centre matches portrait vertically")
            near(tex.w / tex.h, boxWidth / 82, "native art aspect ratio preserved")
            near(tex.coords[1], mirror and 0.4 or 0.2, "mirror uses backing sheet coordinates")
            assert(not ns.ShowNativeClassificationRing(frame, portrait, nil, mirror))
            assert(not tex.shown, "ordinary unit hides previous native overlay")
        end
    end
end
end
end
-- Player and Target share one placement: no player-only offsets, and the
-- portrait rectangle is never touched.
for _, kind in ipairs({"elite", "rare"}) do
    local frame, portrait = Region(), Region()
    frame.unit = "player"
    frame._ktClassRingReach = 0.52
    portrait:SetSize(60,60)
    ns.ShowNativeClassificationRing(frame, portrait, kind, true)
    local tex = frame._kuiNativeClassRing
    local k = 60 * 0.52 / 29
    near(tex.w, atlasWidth*k, "Player dragon uses the shared scale")
    near(tex.point[4] + tex.w/2 - 36*k, 0, "Player dragon centred horizontally")
    near(tex.point[5] + tex.h/2 - ns.NATIVE_APERTURE_Y*k, 0, "Player dragon centred vertically")
    near(portrait:GetWidth(),60,"portrait width preserved")
    near(portrait:GetHeight(),60,"portrait height preserved")
end
print("native_classification: ok")
