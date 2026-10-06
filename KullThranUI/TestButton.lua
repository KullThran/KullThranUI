-- Transparent test button: white outline and text with a 100ms
-- lift on hover. Pressing brings the top flush with the base.
local _, ns = ...
local KT = ns.KT

local TB = KT.TestButton or {}
KT.TestButton = TB

local floor, max, min = math.floor, math.max, math.min

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
local HOVER_TIME = 0.1

local function Px(region) return KT.NavTabs.PixelSize(region) end
local function ToPx(value, px) return floor(value / px + 0.5) * px end

local function FontPath()
    if type(KT.FONT_PATH) == "string" and KT.FONT_PATH ~= "" then return KT.FONT_PATH end
    if KT.ResolveFontPath then return KT:ResolveFontPath() end
    return "Fonts\\FRIZQT__.TTF"
end

local UV = {0,0.25,0.75,1}
local function NewShape(owner, sub)
    local parts = {}
    for row=1,3 do for col=1,3 do
        local t=owner:CreateTexture(nil,"BACKGROUND",nil,sub)
        t:SetTexture(MEDIA.."TestButtonOutline.tga")
        t:SetTexCoord(UV[col],UV[col+1],UV[row],UV[row+1])
        parts[#parts+1]=t
    end end
    return parts
end
local function ShapePlace(parts, owner, x, y, w, h, radius, px, r, g, b, a)
    radius=math.min(radius,w/2,h/2)
    local xs,ys={x,x+radius,x+w-radius},{y,y+radius,y+h-radius}
    local ws,hs={radius,w-2*radius,radius},{radius,h-2*radius,radius}
    for row=1,3 do for col=1,3 do
        local t=parts[(row-1)*3+col]
        t:ClearAllPoints();t:SetPoint("TOPLEFT",owner,"TOPLEFT",xs[col],-ys[row])
        t:SetSize(math.max(0.01,ws[col]),math.max(0.01,hs[row]));t:SetVertexColor(r,g,b,a)
    end end
end

-- The font must exist before any SetText (also before the first layout).
local function EnsureFont(v)
    local flags = v.text.GetFont and select(3, v.text:GetFont())
    if v.fontSet ~= v.fontSize or v.fontPath ~= FontPath() or (flags and flags ~= "") then
        v.fontSet, v.fontPath = v.fontSize, FontPath()
        v.text:SetFont(v.fontPath, v.fontSize, "")
    end
end

local function Apply(btn)
    local v = btn._ktTest
    if not v then return end
    EnsureFont(v)
    local w, h = btn:GetWidth(), btn:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then return end
    local px = Px(btn)
    local rad = ToPx(v.fontSize * 0.75, px)
    local lift = v.fontSize * (0.2 + 0.13 * v.hoverP) * (1 - v.pressP)
    v.lift = ToPx(lift, px)
    ShapePlace(v.border, v.vis, 0, 0, w, h, rad, px, 1, 1, 1, 0.2)
    v.top:ClearAllPoints()
    v.top:SetPoint("TOPLEFT", v.vis, "TOPLEFT", 0, v.lift)
    v.top:SetSize(w, h)
    ShapePlace(v.topEdge, v.top, 0, 0, w, h, rad, px, 1, 1, 1, 1)
    v.text:SetTextColor(1, 1, 1, 1)
    v.text:ClearAllPoints()
    v.text:SetPoint("CENTER", v.top, "CENTER", 0, 0)
end

local function Approach(cur, target, step)
    if cur < target then return min(target, cur + step) end
    if cur > target then return max(target, cur - step) end
    return cur
end

local function OnUpdate(btn, elapsed)
    local v = btn._ktTest
    v.hoverP = Approach(v.hoverP, v.hoverTarget, elapsed / HOVER_TIME)
    v.pressP = Approach(v.pressP, v.pressTarget, elapsed / HOVER_TIME)
    Apply(btn)
    if v.hoverP == v.hoverTarget and v.pressP == v.pressTarget then btn:SetScript("OnUpdate", nil) end
end

local function Build(btn, extText)
    local v = { hoverP = 0, hoverTarget = 0, pressP = 0, pressTarget = 0, fontSize = 13 }
    btn._ktTest = v
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end

    v.vis = CreateFrame("Frame", nil, btn)
    v.vis:SetAllPoints(btn)
    v.border = NewShape(v.vis, -6)

    v.top = CreateFrame("Frame", nil, v.vis)
    v.topEdge = NewShape(v.top, -6)
    v.content = CreateFrame("Frame", nil, v.top)
    v.content:SetAllPoints(v.top)
    v.content:SetFrameLevel(v.top:GetFrameLevel() + 2)
    if extText then
        -- Reuses a label owned by the caller.
        v.text = extText
        extText:SetParent(v.content)
    else
        v.text = v.content:CreateFontString(nil, "OVERLAY")
    end
    v.text:SetTextColor(1, 1, 1, 1)
    v.text:SetDrawLayer("OVERLAY", 7)
    v.text:SetWordWrap(false)
    v.text:SetJustifyH("CENTER")
    v.text:SetJustifyV("MIDDLE")
    v.text:SetShadowOffset(0, 0)

    btn:HookScript("OnEnter", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        v.hoverTarget = 1; self:SetScript("OnUpdate", OnUpdate)
    end)
    btn:HookScript("OnLeave", function(self)
        v.hoverTarget, v.pressTarget = 0, 0; self:SetScript("OnUpdate", OnUpdate)
    end)
    btn:HookScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or (self.IsEnabled and not self:IsEnabled()) then return end
        v.pressTarget = 1; self:SetScript("OnUpdate", OnUpdate)
    end)
    btn:HookScript("OnMouseUp", function(self)
        v.pressTarget = 0; self:SetScript("OnUpdate", OnUpdate)
    end)
    btn:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        v.hoverP, v.hoverTarget, v.pressP, v.pressTarget = 0, 0, 0, 0
        Apply(self)
    end)
    btn:HookScript("OnShow", function(self) Apply(self) end)
    btn:HookScript("OnSizeChanged", function(self) Apply(self) end)
    return v
end

function TB.SetLabel(btn, text, fontSize)
    local v = btn and btn._ktTest
    if not v then return end
    if fontSize then v.fontSize = fontSize end
    EnsureFont(v)
    local s = tostring(text or "")
    local up = KT.NavTabs and KT.NavTabs.Upper
    v.text:SetText(up and up(s) or s:upper())
    Apply(btn)
end

function TB.Refresh(btn)
    if btn and btn._ktTest then Apply(btn) end
end

-- opts: label, fontSize, text (existing FontString to reuse)
function TB.Style(btn, opts)
    if not btn then return end
    opts = opts or {}
    local v = btn._ktTest or Build(btn, opts.text)
    if opts.fontSize then v.fontSize = opts.fontSize end
    EnsureFont(v)
    if opts.label ~= nil then
        TB.SetLabel(btn, opts.label, opts.fontSize)
    else
        Apply(btn)
    end
    return btn
end
