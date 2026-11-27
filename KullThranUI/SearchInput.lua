local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

-- Rounded black search surface, accent halos, hover sheen.
function KT:StyleOptionsSearch(box, accentColor)
    local skin = { hover = 0, shineTime = 0.5, layers = {} }
    local media = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
    local uv = {0, 0.25, 0.75, 1}
    local function Layer(parent)
        local parts = {}
        for row=1,3 do
            for col=1,3 do
                local texture=parent:CreateTexture(nil,"BACKGROUND",nil,#skin.layers)
                texture:SetTexture(media.."ProfileButtonShape.tga")
                texture:SetTexCoord(uv[col],uv[col+1],uv[row],uv[row+1])
                parts[#parts+1]=texture
            end
        end
        skin.layers[#skin.layers+1]=parts
        return parts
    end
    local function Glow(parent)
        local tex=parent:CreateTexture(nil,"BACKGROUND",nil,-7)
        tex:SetTexture(media.."PortalRadial.tga")
        return tex
    end
    skin.leftGlow,skin.rightGlow=Glow(box),Glow(box)
    skin.border,skin.fill=Layer(box),Layer(box)
    skin.clip=CreateFrame("Frame",nil,box)
    skin.clip:SetPoint("TOPLEFT",box,"TOPLEFT",12,-1)
    skin.clip:SetPoint("BOTTOMRIGHT",box,"BOTTOMRIGHT",-12,1)
    skin.clip:SetClipsChildren(true)
    skin.clip:EnableMouse(false)
    skin.shine=skin.clip:CreateTexture(nil,"BACKGROUND")
    skin.shine:SetTexture(media.."NavButtonShine.tga")
    local function Paint(parts,parent,width,height,radius,inset,r,g,b,alpha)
        width,height=math.max(1,width-inset*2),math.max(1,height-inset*2)
        radius=math.min(radius,width/2,height/2)
        local xs,ys={inset,inset+radius,inset+width-radius},{inset,inset+radius,inset+height-radius}
        local ws,hs={radius,width-radius*2,radius},{radius,height-radius*2,radius}
        for row=1,3 do
            for col=1,3 do
                local texture=parts[(row-1)*3+col]
                texture:ClearAllPoints()
                texture:SetPoint("TOPLEFT",parent,"TOPLEFT",xs[col],-ys[row])
                texture:SetSize(math.max(0.01,ws[col]),math.max(0.01,hs[row]))
                texture:SetVertexColor(r,g,b,alpha)
            end
        end
    end
    local function Render()
        local w,h=box:GetWidth(),box:GetHeight()
        local r,g,b=accentColor()
        local p=skin.hover
        Paint(skin.border,box,w,h,12,0,r,g,b,0.25+p*0.35)
        Paint(skin.fill,box,w,h,11,1,0.015,0.015,0.02,0.96)
        for i,glow in ipairs({skin.leftGlow,skin.rightGlow}) do
            glow:ClearAllPoints()
            glow:SetSize(120+40*p,40+10*p)
            glow:SetPoint(i==1 and "LEFT" or "RIGHT",box,i==1 and "LEFT" or "RIGHT",0,i==1 and 7 or -7)
            glow:SetVertexColor(r,g,b,0.16+p*0.1)
        end
        local t=math.min(1,skin.shineTime/0.5)
        skin.shine:ClearAllPoints()
        skin.shine:SetPoint("TOPLEFT",skin.clip,"TOPLEFT",-160+(w+160)*t*t,0)
        skin.shine:SetSize(150,math.max(1,h-2))
        skin.shine:SetVertexColor(1,1,1,t<1 and 0.18 or 0)
        if skin.icon then skin.icon:SetVertexColor(r,g,b,0.85) end
        if skin.hint then skin.hint:SetShown(box:GetText()=="" and not box:HasFocus()) end
    end
    local function Approach(value,target,step)
        if value<target then return math.min(target,value+step) end
        return math.max(target,value-step)
    end
    local function Animate()
        box:SetScript("OnUpdate",function(self,dt)
            local target=(skin.boxHovered or box:HasFocus()) and 1 or 0
            skin.hover=Approach(skin.hover,target,dt/0.3)
            skin.shineTime=math.min(0.5,skin.shineTime+dt)
            Render()
            if skin.hover==target and skin.shineTime==0.5 then self:SetScript("OnUpdate",nil) end
        end)
    end
    local function Enter()
        if not skin.boxHovered then skin.shineTime=0 end
        skin.boxHovered=true;Animate()
    end
    box.RefreshSearchSkin=function()
        box:SetFont(KT.ResolveFontPath and KT:ResolveFontPath() or KT.FONT_PATH,12,"OUTLINE")
        Render()
    end
    box.BindSearchParts=function(_,hint,icon) skin.hint,skin.icon=hint,icon;Render() end
    box:HookScript("OnEnter",Enter)
    box:HookScript("OnLeave",function()skin.boxHovered=nil;Animate()end)
    box:HookScript("OnEditFocusGained",function()Render();Animate()end)
    box:HookScript("OnEditFocusLost",function()Render();Animate()end)
    box:HookScript("OnSizeChanged",Render)
    box:HookScript("OnHide",function()
        box:SetScript("OnUpdate",nil)
        skin.hover,skin.boxHovered,skin.shineTime=0,nil,0.5
        Render()
    end)
    box:HookScript("OnShow",function()box:RefreshSearchSkin()end)
    box:RefreshSearchSkin()
    box._searchSkin=skin
end
