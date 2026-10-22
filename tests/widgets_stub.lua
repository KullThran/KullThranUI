-- Shared stub UI for tests that load MenuSkins.lua + Widgets.lua.
-- Frames and textures record what the widgets paint; unknown capitalised
-- methods are no-ops. Usage: local W, MS, KT = dofile("tests/widgets_stub.lua")(root)
return function(root)
    local function region(kind, parent)
        local r = { kind = kind, parent = parent, w = 0, h = 0, points = {}, scripts = {}, shown = true }
        function r:SetSize(w, h) self.w, self.h = w, h end
        function r:SetWidth(w) self.w = w end
        function r:SetHeight(h) self.h = h end
        function r:GetWidth() return self.w end
        function r:GetHeight() return self.h end
        function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
        function r:ClearAllPoints() self.points = {} end
        function r:GetPoint(i) local p = self.points[i or 1]; if p then return unpack(p) end end
        function r:SetScript(e, fn) self.scripts[e] = fn end
        function r:HookScript(e, fn) self.scripts[e] = fn end
        function r:GetScript(e) return self.scripts[e] end
        function r:Show() self.shown = true end
        function r:Hide() self.shown = false end
        function r:SetShown(v) self.shown = v and true or false end
        function r:IsShown() return self.shown end
        function r:SetAlpha(a) self.alpha = a end
        function r:SetColorTexture(cr, cg, cb, ca) self.color = { cr, cg, cb, ca } end
        function r:SetVertexColor(cr, cg, cb, ca) self.vertex = { cr, cg, cb, ca } end
        function r:SetTexture(path) self.texture = path end
        function r:SetGradient(orient, a, b) self.gradient = { orient, a, b } end
        function r:SetTextColor(cr, cg, cb, ca) self.textColor = { cr, cg, cb, ca } end
        function r:SetText(t) self.text = t end
        function r:GetText() return self.text end
        function r:SetWordWrap(v) self.wrap = v end
        function r:SetMaxLines(n) self.maxLines = n end
        function r:GetStringHeight() return 12 end
        function r:GetStringWidth() return #(self.text or "") * 6 end
        function r:SetMinMaxValues(lo, hi) self.min, self.max = lo, hi end
        function r:GetMinMaxValues() return self.min, self.max end
        function r:SetValue(v) self.value = v; if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end end
        function r:GetValue() return self.value end
        function r:HasFocus() return false end
        function r:GetThumbTexture() self.thumb = self.thumb or region("Texture", self); return self.thumb end
        function r:GetNumRegions() return 0 end
        function r:CreateTexture() return region("Texture", self) end
        function r:CreateFontString() return region("FontString", self) end
        return setmetatable(r, { __index = function(_, k)
            if type(k) == "string" and k:match("^%u") then return function() end end
        end })
    end

    local KT = { FONT_PATH = "font" }
    function KT:GetStylePalette()
        return { accent = { r = 0.8, g = 0.2, b = 0.4 }, text = { r = 1, g = 1, b = 1 }, muted = { r = 0.74, g = 0.74, b = 0.78 } }
    end
    function KT:AddBackdrop(f, r, g, b, a) f.backdropKT = { r, g, b, a } end
    function KT:AddBorder(f, r, g, b, a) f.borderColorKT = { r, g, b, a } end
    local env = setmetatable({
        CreateFrame = function(kind, name, parent) return region(kind, parent) end,
        UIParent = region("Frame"), GameTooltip = region("Frame"), unpack = unpack,
        CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end,
    }, { __index = _G })
    local function load(path)
        local fn = assert(loadfile(root .. "/" .. path))
        setfenv(fn, env)
        fn("KullThranUI", { KT = KT })
    end
    load("KullThranUI/MenuSkins.lua")
    load("KullThranUI/Widgets.lua")
    return KT.Widgets, KT.MenuSkins, KT, region, env
end
