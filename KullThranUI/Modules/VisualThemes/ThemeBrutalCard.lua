-- Native package-card effect. Existing theme colours are retained.
local _, ns = ...
local KT = ns.KT
local BC = KT.BrutalCard or {}
KT.BrutalCard = BC
local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
local uv = {0, 0.25, 0.75, 1}
local function Shape(owner, sub)
    local parts={}
    for row=1,3 do for col=1,3 do
        local t=owner:CreateTexture(nil,"BACKGROUND",nil,sub)
        t:SetTexture(MEDIA.."ProfileButtonShape.tga")
        t:SetTexCoord(uv[col],uv[col+1],uv[row],uv[row+1])
        parts[#parts+1]=t
    end end
    return parts
end
local function Paint(parts,owner,w,h,r,color,gradient)
    r=math.min(r,w/2,h/2)
    local xs,ys={0,r,w-r},{0,r,h-r}
    local ws,hs={r,w-2*r,r},{r,h-2*r,r}
    for row=1,3 do for col=1,3 do
        local t=parts[(row-1)*3+col]
        t:ClearAllPoints();t:SetPoint("TOPLEFT",owner,"TOPLEFT",xs[col],-ys[row])
        t:SetSize(math.max(0.01,ws[col]),math.max(0.01,hs[row]))
        if gradient then
            local top=1-0.55*(0.8*ys[row]/h+0.2*(xs[col]+ws[col]/2)/w)
            local bottom=top-0.55*0.8*hs[row]/h
            t:SetVertexColor(1,1,1,1)
            if t.SetGradient and CreateColor then
                t:SetGradient("VERTICAL",CreateColor(color[1]*bottom,color[2]*bottom,color[3]*bottom,1),CreateColor(color[1]*top,color[2]*top,color[3]*top,1))
            elseif t.SetGradientAlpha then
                t:SetGradientAlpha("VERTICAL",color[1]*bottom,color[2]*bottom,color[3]*bottom,1,color[1]*top,color[2]*top,color[3]*top,1)
            else t:SetVertexColor(color[1]*top,color[2]*top,color[3]*top,1) end
        else t:SetVertexColor(color[1],color[2],color[3],1) end
    end end
end
local function Apply(card)
    local v=card._ktBrutal
    local w,h=card:GetWidth(),card:GetHeight()
    if w<=0 or h<=0 then return end
    -- CSS cubic-bezier(0,0,0,1): x=t^3, y=3t^2-2t^3.
    local t=v.hoverP^(1/3)
    local p=3*t*t-2*t*t*t
    v.body:SetSize(w-2,h-2)
    v.body:SetScale(1-0.02*p)
    -- Match the outer 20px curve at rest; the inset is 1px.
    v.radius=19-p
    Paint(v.edge,card,w,h,20,v.accent,true)
    Paint(v.fill,v.body,w-2,h-2,v.radius,{0.055,0.065,0.080})
    v.glow:ClearAllPoints();v.glow:SetPoint("CENTER",card,"CENTER")
    v.glow:SetSize(w+60,h+60)
    v.glow:SetVertexColor(v.accent[1],v.accent[2],v.accent[3],0.3*p)
end
local function Update(card,elapsed)
    local v=card._ktBrutal
    local step=elapsed/0.25
    if v.hoverP<v.hoverTarget then v.hoverP=math.min(v.hoverTarget,v.hoverP+step)
    else v.hoverP=math.max(v.hoverTarget,v.hoverP-step) end
    Apply(card)
    if v.hoverP==v.hoverTarget then card:SetScript("OnUpdate",nil) end
end
function BC.SetHover(card,on)
    local v=card and card._ktBrutal
    if not v then return end
    local target=on and 1 or 0
    if v.hoverTarget==target then return end
    v.hoverTarget=target;card:SetScript("OnUpdate",Update)
end
function BC.SetInUse(card,on)
    local v=card and card._ktBrutal
    if v then v.inUse=on and true or false end
end
function BC.Style(card,opts)
    opts=opts or {}
    local v=card._ktBrutal
    if not v then
        v={hoverP=0,hoverTarget=0};card._ktBrutal=v
        v.glow=card:CreateTexture(nil,"BACKGROUND",nil,-8)
        v.glow:SetTexture(MEDIA.."PortalRadial.tga")
        v.edge=Shape(card,-7)
        v.body=CreateFrame("Frame",nil,card)
        v.body:SetPoint("CENTER",card,"CENTER")
        v.body:EnableMouse(false)
        v.fill=Shape(v.body,-7)
        card:HookScript("OnSizeChanged",Apply)
        card:HookScript("OnShow",Apply)
        card:HookScript("OnHide",function(self)
            self:SetScript("OnUpdate",nil);v.hoverP,v.hoverTarget=0,0;Apply(self)
        end)
    end
    v.accent=opts.accent or {1,1,1};v.inUse=opts.inUse==true
    Apply(card)
    return v
end
