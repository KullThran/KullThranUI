local KT = _G.KT

-- [FALLBACK] Si core/buttonBar.lua no se ha cargado (por error de TOC),
-- restauramos esta clase para evitar el crash "attempt to index field 'Bar' (a nil value)".
if KT.Bar then return end

local Bar = {}
Bar.__index = Bar
KT.Bar = Bar

-- [COMPATIBILIDAD] Añadimos :New para que funcione igual que ButtonBar
function Bar:New(name)
    return self:Create(name, name)
end

function Bar:Create(id, name)
    local self = setmetatable({}, Bar)
    self.id = id
    self.name = name or id
    self.buttons = {}
    
    -- Crear settings por defecto si no existen
    if not KT.db.profile.frames[id] then
        KT.db.profile.frames[id] = {
            point = {"CENTER", "UIParent", "CENTER", 0, 0},
            scale = 1,
            padding = 2,
            spacing = 6,
            cols = 12,
            count = 12,
            alpha = 1,
            fade = false,
            showGrid = true,
            hideMacro = false,
            hideKeybind = false,
            macroSize = 12,
            bindSize = 12,
            fontColor = {r = 1, g = 1, b = 1, a = 1}
        }
    end
    
    self.sets = KT.db.profile.frames[id]
    
    -- Crear header
    self.header = CreateFrame("Frame", "KT_"..id, UIParent, "SecureHandlerStateTemplate")
    self.header:SetMovable(true)
    self.header:SetClampedToScreen(true)
    self.header:SetAttribute("_onstate-page", [[
        self:SetAttribute("actionpage", newstate)
        control:ChildUpdate("actionpage", newstate)
    ]])
    
    self:LoadPosition()
    self.header:SetScale(self.sets.scale or 1)
    self:UpdateAlpha()
    
    -- Crear overlay para arrastre
    self.drag = CreateFrame("Button", nil, self.header, "BackdropTemplate")
    self.drag:SetFrameStrata("DIALOG")
    self.drag:SetAllPoints(self.header)
    self.drag:EnableMouse(true)
    self.drag:RegisterForDrag("LeftButton")
    self.drag:RegisterForClicks("AnyUp")
    
    self.drag:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = {left = 2, right = 2, top = 2, bottom = 2}
    })
    self.drag:SetBackdropColor(1, 0, 0, 0.5)
    self.drag:SetBackdropBorderColor(1, 0, 0, 1)
    self.drag:Hide()
    
    -- Texto del drag
    self.drag.text = self.drag:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.drag.text:SetPoint("CENTER")
    self.drag.text:SetText(self.name)
    
    -- Scripts de arrastre
    self.drag:SetScript("OnDragStart", function()
        self.header:StartMoving()
    end)
    
    self.drag:SetScript("OnDragStop", function()
        self.header:StopMovingOrSizing()
        self:SavePosition()
        
        -- Actualizar NudgeFrame si está abierto
        if KT.NudgeFrame and KT.NudgeFrame.target == self.header then
            KT:ShowNudgeFrame(self.header, function()
                self:SavePosition()
            end)
        end
    end)
    
    -- Click handlers
    self.drag:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            -- Click derecho: Abrir editor
            if KT.ShowBarEditor then
                if KT.ShowBarEditor then
                KT:ShowBarEditor(self)
            end
            end
        elseif button == "LeftButton" then
            -- Click izquierdo: Abrir panel de precisión
            KT:ShowNudgeFrame(self.header, function()
                self:SavePosition()
            end)
        end
    end)
    
    table.insert(KT.bars, self)
    return self
end

function Bar:LoadPosition()
    local point = self.sets.point
    if point then
        local success = pcall(function()
            self.header:SetPoint(unpack(point))
        end)
        if not success then
            self.header:ClearAllPoints()
            self.header:SetPoint("CENTER")
        end
    else
        self.header:SetPoint("CENTER")
    end
end

function Bar:SavePosition()
    local point, relativeTo, relativePoint, x, y = self.header:GetPoint()
    if type(relativeTo) == "table" and relativeTo.GetName then
        relativeTo = relativeTo:GetName()
    else
        relativeTo = "UIParent"
    end
    self.sets.point = {point, relativeTo, relativePoint, x, y}
    
    -- Notificar a AceConfig
    local ACR = LibStub("AceConfigRegistry-3.0", true)
    if ACR then
        ACR:NotifyChange("KullThranUI")
    end
end

function Bar:UpdateAlpha()
    if self.sets.fade then
        self.header:SetAlpha(0)
    else
        self.header:SetAlpha(self.sets.alpha or 1)
    end
end

function Bar:FadeIn()
    if not self.sets.fade then return end
    UIFrameFadeIn(self.header, 0.1, self.header:GetAlpha(), self.sets.alpha or 1)
end

function Bar:FadeOut()
    if not self.sets.fade then return end
    C_Timer.After(0.1, function()
        if not self:IsMouseOver() then
            UIFrameFadeOut(self.header, 0.2, self.header:GetAlpha(), 0)
        end
    end)
end

function Bar:IsMouseOver()
    if self.drag:IsVisible() and ((_G.MouseIsOver and _G.MouseIsOver(self.drag)) or (self.drag.IsMouseOver and self.drag:IsMouseOver())) then
        return true
    end
    for _, button in ipairs(self.buttons) do
        if button:IsVisible() and ((_G.MouseIsOver and _G.MouseIsOver(button)) or (button.IsMouseOver and button:IsMouseOver())) then
            return true
        end
    end
    return false
end

function Bar:UpdateTextElements()
    local globalFont = KT.db.profile.font or "Fonts\\FRIZQT__.TTF"
    local macroSize = self.sets.macroSize or 12
    local bindSize = self.sets.bindSize or 12
    local color = self.sets.fontColor or {r = 1, g = 1, b = 1, a = 1}
    
    for _, button in ipairs(self.buttons) do
        local name = button:GetName()
        if name then
            local hotkey = _G[name.."HotKey"]
            local macro = _G[name.."Name"]
            
            if hotkey then
                if self.sets.hideKeybind then
                    hotkey:SetAlpha(0)
                else
                    hotkey:SetAlpha(1)
                    hotkey:SetFont(globalFont, bindSize, "OUTLINE")
                    hotkey:SetTextColor(color.r, color.g, color.b, color.a)
                end
            end
            
            if macro then
                if self.sets.hideMacro then
                    macro:SetAlpha(0)
                else
                    macro:SetAlpha(1)
                    macro:SetFont(globalFont, macroSize, "OUTLINE")
                    macro:SetTextColor(color.r, color.g, color.b, color.a)
                end
            end
        end
    end
end

function Bar:UpdateGrid()
    local show = self.sets.showGrid and 1 or 0
    for _, button in ipairs(self.buttons) do
        if button.SetAttribute then
            button:SetAttribute("showgrid", show)
            if show == 1 and button.ShowGrid then
                button:ShowGrid()
            elseif show == 0 and button.HideGrid then
                button:HideGrid()
            end
            if button.UpdateGrid then
                button:UpdateGrid()
            end
        end
    end
end

function Bar:Layout()
    local padding = self.sets.padding or 2
    local spacing = self.sets.spacing or 6
    local cols = self.sets.cols or 12
    local count = self.sets.count or 12
    local buttonSize = (self.buttons[1] and self.buttons[1]:GetWidth()) or 36
    local visible = 0
    
    for i, button in ipairs(self.buttons) do
        if i > count then
            button:Hide()
        else
            button:Show()
            button:ClearAllPoints()
            
            local col = (i - 1) % cols
            local row = math.ceil(i / cols) - 1
            
            button:SetPoint("TOPLEFT", self.header, "TOPLEFT",
                padding + (col * (buttonSize + spacing)),
                -(padding + (row * (buttonSize + spacing)))
            )
            visible = visible + 1
        end
    end
    
    if visible > 0 then
        local totalCols = math.min(visible, cols)
        local totalRows = math.ceil(visible / cols)
        self.header:SetSize(
            (padding * 2) + (totalCols * buttonSize) + ((totalCols - 1) * spacing),
            (padding * 2) + (totalRows * buttonSize) + ((totalRows - 1) * spacing)
        )
    else
        self.header:SetSize(200, 40)
    end
end

function Bar:AddButton(button)
    if not button then return end
    
    button:SetParent(self.header)
    button:HookScript("OnEnter", function()
        self:FadeIn()
    end)
    button:HookScript("OnLeave", function()
        self:FadeOut()
    end)
    
    table.insert(self.buttons, button)
    
    -- Configurar fuente de hotkey
    local name = button:GetName()
    if name then
        local hotkey = _G[name.."HotKey"]
        if hotkey then
            hotkey:SetFontObject("NumberFontNormal")
        end
    end
    
    -- Configurar grilla
    local show = self.sets.showGrid and 1 or 0
    if button.SetAttribute then
        button:SetAttribute("showgrid", show)
        if show == 1 and button.ShowGrid then
            button:ShowGrid()
        end
    end
    
    self:Layout()
    self:UpdateTextElements()
end

function Bar:Sticky()
    local range = 15
    for _, other in ipairs(KT.bars) do
        if other ~= self and other.header:IsVisible() then
            local _, relativeTo = other.header:GetPoint()
            local isChild = (relativeTo == self.header)
            if not isChild then
                local myL, myR, myT, myB = self.header:GetLeft(), self.header:GetRight(), 
                                          self.header:GetTop(), self.header:GetBottom()
                local oL, oR, oT, oB = other.header:GetLeft(), other.header:GetRight(), 
                                       other.header:GetTop(), other.header:GetBottom()
                if myL and oL then
                    -- Snap inferior
                    if math.abs(myT - oB) <= range and 
                       ((myL >= oL - range and myL <= oR + range) or 
                        (myR >= oL - range and myR <= oR + range)) then
                        self.header:ClearAllPoints()
                        if math.abs(myL - oL) <= range then
                            self.header:SetPoint("TOPLEFT", other.header, "BOTTOMLEFT", 0, -2)
                        else
                            self.header:SetPoint("TOPLEFT", other.header, "BOTTOMLEFT", myL - oL, -2)
                        end
                        return
                    end
                    -- Snap superior
                    if math.abs(myB - oT) <= range and 
                       ((myL >= oL - range and myL <= oR + range) or 
                        (myR >= oL - range and myR <= oR + range)) then
                        self.header:ClearAllPoints()
                        if math.abs(myL - oL) <= range then
                            self.header:SetPoint("BOTTOMLEFT", other.header, "TOPLEFT", 0, 2)
                        else
                            self.header:SetPoint("BOTTOMLEFT", other.header, "TOPLEFT", myL - oL, 2)
                        end
                        return
                    end
                    -- Snap derecha
                    if math.abs(myL - oR) <= range and 
                       ((myT >= oB - range and myT <= oT + range) or 
                        (myB >= oB - range and myB <= oT + range)) then
                        self.header:ClearAllPoints()
                        if math.abs(myT - oT) <= range then
                            self.header:SetPoint("TOPLEFT", other.header, "TOPRIGHT", 2, 0)
                        else
                            self.header:SetPoint("TOPLEFT", other.header, "TOPRIGHT", 2, myT - oT)
                        end
                        return
                    end
                    -- Snap izquierda
                    if math.abs(myR - oL) <= range and 
                       ((myT >= oB - range and myT <= oT + range) or 
                        (myB >= oB - range and myB <= oT + range)) then
                        self.header:ClearAllPoints()
                        if math.abs(myT - oT) <= range then
                            self.header:SetPoint("TOPRIGHT", other.header, "TOPLEFT", -2, 0)
                        else
                            self.header:SetPoint("TOPRIGHT", other.header, "TOPLEFT", -2, myT - oT)
                        end
                        return
                    end
                end
            end
        end
    end
end

function Bar:SetStateDriver(macro)
    if macro then
        RegisterStateDriver(self.header, "page", macro)
    end
end

function Bar:Lock()
    self.drag:Hide()
    self:UpdateAlpha()
    for _, button in ipairs(self.buttons) do
        if button.EnableMouse then
            button:EnableMouse(true)
        end
    end
end

function Bar:Unlock()
    self.drag:Show()
    self.header:SetAlpha(1)
    for _, button in ipairs(self.buttons) do
        if button.EnableMouse then
            button:EnableMouse(false)
        end
    end
end