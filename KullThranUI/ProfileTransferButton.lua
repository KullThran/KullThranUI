-- Module-footer Export / Import buttons: accent border revealed by two dark masks.
local _, ns = ...
local KT = ns.KT
local PB = {}
local buttons = setmetatable({}, {__mode="k"})
KT.ProfileTransferButton = PB
local WHITE = "Interface\\Buttons\\WHITE8x8"
local function Texture(owner, layer)
    local t=owner:CreateTexture(nil,layer)
    t:SetTexture(WHITE)
    return t
end
local function Ease(t)
    t=math.max(0,math.min(1,t))
    return 1-(1-t)^3
end
local function Apply(button)
    local v=button._ktProfileTransfer
    local w,h=button:GetWidth(),button:GetHeight()
    local font=KT.ResolveFontPath and KT:ResolveFontPath() or KT.FONT_PATH
    v.text:SetFont(font,v.fontSize,"")
    v.text:SetTextColor(1,1,1,1)
    local r,g,b = KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333333
    if KT.GetStyleAccentRGB then r,g,b = KT:GetStyleAccentRGB() end
    for _,edge in ipairs(v.edges) do edge:SetVertexColor(r,g,b,1) end
    local time=v.progress*0.45
    v.beforeProgress=Ease(time/0.3)
    v.afterProgress=Ease((time-0.15)/0.3)
    v.before:ClearAllPoints()
    v.before:SetPoint("TOPLEFT",v.clip,"TOPLEFT",-2,2+25*v.beforeProgress)
    v.before:SetSize(w+6,math.max(0.01,(h+2)*(1-v.beforeProgress)))
    v.before:SetVertexColor(0.13,0.13,0.13,v.beforeProgress<1 and 1 or 0)
    v.after:ClearAllPoints()
    v.after:SetPoint("CENTER",v.clip,"CENTER")
    v.after:SetSize(math.max(0.01,(w+4)*(1-v.afterProgress)),math.max(1,h*0.35))
    v.after:SetVertexColor(0.13,0.13,0.13,v.afterProgress<1 and 1 or 0)
end
local function Update(button,elapsed)
    local v=button._ktProfileTransfer
    local step=elapsed/0.45
    if v.progress<v.target then v.progress=math.min(v.target,v.progress+step)
    else v.progress=math.max(v.target,v.progress-step) end
    Apply(button)
    if v.progress==v.target then button:SetScript("OnUpdate",nil) end
end
function PB.Style(button,opts)
    opts=opts or {}
    local v=button._ktProfileTransfer
    if not v then
        v={progress=0,target=0,fontSize=12};button._ktProfileTransfer=v
        if button.SetHighlightTexture then button:SetHighlightTexture("") end
        v.edges={}
        for i,p in ipairs({{"TOPLEFT","TOPRIGHT",true},{"BOTTOMLEFT","BOTTOMRIGHT",true},{"TOPLEFT","BOTTOMLEFT",false},{"TOPRIGHT","BOTTOMRIGHT",false}}) do
            local edge=Texture(button,"BACKGROUND")
            edge:SetPoint(p[1],button,p[1]);edge:SetPoint(p[2],button,p[2])
            if p[3] then edge:SetHeight(2) else edge:SetWidth(2) end
            edge:SetVertexColor(1,1,1,1);v.edges[i]=edge
        end
        v.clip=CreateFrame("Frame",nil,button)
        v.clip:SetAllPoints(button);v.clip:SetClipsChildren(true);v.clip:EnableMouse(false)
        v.clip:SetFrameLevel(button:GetFrameLevel()+1)
        v.before=Texture(v.clip,"BACKGROUND")
        v.after=Texture(v.clip,"ARTWORK")
        v.content=CreateFrame("Frame",nil,button)
        v.content:SetAllPoints(button);v.content:EnableMouse(false)
        v.content:SetFrameLevel(button:GetFrameLevel()+2)
        v.text=v.content:CreateFontString(nil,"OVERLAY")
        v.text:SetPoint("LEFT",12,0);v.text:SetPoint("RIGHT",-12,0)
        v.text:SetJustifyH("CENTER");v.text:SetWordWrap(false)
        v.text:SetShadowOffset(0,0)
        button:HookScript("OnEnter",function(self)
            if self.IsEnabled and not self:IsEnabled() then return end
            v.target=1;self:SetScript("OnUpdate",Update)
        end)
        button:HookScript("OnLeave",function(self)v.target=0;self:SetScript("OnUpdate",Update)end)
        button:HookScript("OnHide",function(self)
            self:SetScript("OnUpdate",nil);v.progress,v.target=0,0;Apply(self)
        end)
        button:HookScript("OnShow",Apply)
        button:HookScript("OnSizeChanged",Apply)
    end
    v.fontSize=opts.fontSize or v.fontSize
    buttons[button]=true
    Apply(button)
    local label=tostring(opts.label or "")
    v.text:SetText(KT.NavTabs and KT.NavTabs.Upper and KT.NavTabs.Upper(label) or label:upper())
    return button
end

function PB.RefreshAll()
    for button in pairs(buttons) do Apply(button) end
end
