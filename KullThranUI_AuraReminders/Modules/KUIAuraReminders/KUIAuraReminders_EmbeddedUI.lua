-- KUI presentation for the embedded engine. Runtime and aura option generation remain in the engine.
local _, ns = ...
local KT, E = ns.KT, ns.EmbeddedAuraEngine
if not KT or not E then return end
local M = {}
ns.AuraRemindersEmbeddedUI = M
local ICONS = "Interface\\AddOns\\KullThranUI_AuraReminders\\Modules\\KUIAuraReminders\\Media\\icons\\"
local function L(text) return KT.Options and KT.Options.LText and KT.Options.LText(text) or text end
local function Font() return KT.ResolveFontPath and KT:ResolveFontPath() or "Fonts\\FRIZQT__.TTF" end
local function Accent()
    if KT.GetStyleAccentRGB then return KT:GetStyleAccentRGB() end
    return 1, 0.6, 0.4
end
local function Hide(frame) if frame and frame.Hide then frame:Hide() end end
-- KUI's unlock mode, when the core has it.
local function UnlockMode()
    if type(KT.GetModule) ~= "function" then return nil end
    local ok, um = pcall(KT.GetModule, KT, "UnlockMode", true)
    return ok and um and um.OpenUnlockMode and um or nil
end

local function Button(parent, label, icon, click)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(34)
    KT:AddBackdrop(button, 0.08, 0.10, 0.13, 0.95)
    KT:AddBorder(button, 0.25, 0.25, 0.25, 1)
    local image = button:CreateTexture(nil, "ARTWORK")
    image:SetSize(18, 18)
    image:SetPoint("LEFT", 10, 0)
    image:SetTexture(ICONS .. icon .. ".png")
    image:SetVertexColor(Accent())
    local text = button:CreateFontString(nil, "OVERLAY")
    text:SetFont(Font(), 12, "")
    text:SetPoint("LEFT", image, "RIGHT", 7, 0)
    text:SetPoint("RIGHT", -8, 0)
    text:SetJustifyH("LEFT")
    text:SetText(L(label))
    text:SetTextColor(0.95, 0.95, 0.95, 1)
    button:SetScript("OnClick", click)
    button:SetScript("OnEnter", function() image:SetVertexColor(1, 1, 1, 1) end)
    button:SetScript("OnLeave", function() image:SetVertexColor(Accent()) end)
    button.kuiIcon, button.kuiLabel = image, text
    return button
end

-- Keep AceGUI's own scrolling and callbacks. Only its scrollbar presentation is replaced.
local function PaintScroll(widget)
    local bar, viewport, content = widget.scrollbar, widget.scrollframe, widget.content
    if not bar then return end
    if not bar.kuiTrack then
        for _, region in ipairs({ bar:GetRegions() }) do
            if region.SetAlpha then region:SetAlpha(0) end
        end
        Hide(bar.ScrollUpButton); Hide(bar.ScrollDownButton)
        local name = bar:GetName()
        if name then Hide(_G[name .. "ScrollUpButton"]); Hide(_G[name .. "ScrollDownButton"]) end
        bar.kuiTrack = bar:CreateTexture(nil, "BACKGROUND")
        bar.kuiTrack:SetAllPoints()
        bar.kuiTrack:SetColorTexture(0.04, 0.04, 0.05, 0.85)
        bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    end
    bar:SetWidth(6)
    local thumb = bar:GetThumbTexture()
    if thumb then
        local r,g,b = Accent()
        thumb:SetAlpha(1)
        thumb:SetVertexColor(r,g,b,0.9)
        thumb:SetWidth(4)
        if viewport and content then
            local h = math.max(1, viewport:GetHeight())
            local total = math.max(h, content:GetHeight())
            thumb:SetHeight(math.min(h, math.max(24, bar:GetHeight() * h / total)))
        end
    end
end

local function PaintWidget(widget)
    if not widget then return end
    if widget.frame and widget.frame.GetFontString then
        local text = widget.frame:GetFontString()
        if text then text:SetFont(Font(),12,""); text:SetTextColor(0.92,0.92,0.92,1) end
    end
    if widget.background and widget.background.SetTexture then
        widget.background:SetTexture("Interface\\Buttons\\WHITE8X8")
        if widget.background.SetBlendMode then widget.background:SetBlendMode("BLEND") end
        widget.background:SetVertexColor(0.08,0.10,0.13,0.95)
    end
    if widget.scrollbar then
        PaintScroll(widget)
        if not widget.kuiScrollHook and widget.FixScroll then
            widget.kuiScrollHook = true
            hooksecurefunc(widget, "FixScroll", function() PaintScroll(widget) end)
        end
    end
    for _, key in ipairs({ "title", "titletext", "label" }) do
        local text = widget[key]
        if text and text.SetFont and text.SetTextColor then
            text:SetFont(Font(), 12, "")
            text:SetTextColor(0.92, 0.92, 0.92, 1)
        end
    end
    if widget.view and widget.view.texture then
        widget.view.texture:SetTexture(ICONS .. (widget.view.visibility == 0 and "ed_off" or "ed_on") .. ".png")
        if widget.view.texture.SetTexCoord then widget.view.texture:SetTexCoord(0,1,0,1) end
        widget.view.texture:SetVertexColor(Accent())
        if not widget.kuiViewHook and widget.UpdateViewTexture then
            widget.kuiViewHook = true
            hooksecurefunc(widget, "UpdateViewTexture", function() PaintWidget(widget) end)
        end
    end
    if widget.icon and widget.OverrideIcon and not widget.kuiOverrideHook then
        widget.kuiOverrideHook = true
        local function OwnFallbackIcon()
            widget.icon:SetTexture(ICONS .. "custom.png")
        end
        hooksecurefunc(widget, "OverrideIcon", OwnFallbackIcon)
        local texture = widget.icon:GetTexture()
        if type(texture) == "string" and texture:lower():find("foreverauras_logo",1,true) then OwnFallbackIcon() end
    end
    for _, child in ipairs(widget.children or {}) do PaintWidget(child) end
end

local function HideChrome(frame)
    for _, key in ipairs({ "TitleContainer", "faTitleBar", "faTitleLogo", "PortraitContainer", "NineSlice",
        "Bg", "CloseButton", "kuiMinimizeButton", "fontButton", "layoutButton", "bottomRightResizer",
        "tipFrame", "toolbarContainer" }) do Hide(frame[key]) end
    Hide(_G.KUIAR_EngineOptionsTitleText)
    Hide(_G.KUIAR_EngineOptionsPortrait)
    if not frame.kuiChromeHidden then
        frame.kuiChromeHidden = true
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.SetAlpha then region:SetAlpha(0) end
        end
        if frame.faSkin then
            Hide(frame.faSkin.bg)
            for _, edge in ipairs(frame.faSkin.edges or {}) do Hide(edge) end
        end
    end
end

-- The engine's own windows (import, update, code editor, pickers) were placed under its old title bar, about 50 px
-- from the top. Here they go under KUI's action rows: their top edges move down by the difference, the rest stays.
local WINDOWS = { "TexturePicker", "IconPicker", "ModelPicker", "ImportExport", "TextEditor", "CodeReview",
    "UpdateFrame", "DebugLog" }
local ENGINE_HEADER = 50

local function PlaceWindows(frame, top)
    local options = E.Options and E.Options()
    local windows = {}
    for _, fn in ipairs(WINDOWS) do
        local get = options and options[fn]
        if type(get) == "function" then
            -- true: only an already built window, as the engine itself asks for them.
            local ok, window = pcall(get, frame, true)
            if ok and type(window) == "table" and window.frame then windows[#windows + 1] = window end
        end
    end
    if frame.newView and frame.newView.frame then windows[#windows + 1] = frame.newView end
    local shift = top - ENGINE_HEADER
    for _, window in ipairs(windows) do
        local f = window.frame
        if not f.kuiPoints then
            f.kuiPoints = {}
            for i = 1, f:GetNumPoints() do f.kuiPoints[i] = { f:GetPoint(i) } end
        end
        f:ClearAllPoints()
        for _, p in ipairs(f.kuiPoints) do
            local point, relativeTo, relativePoint, x, y = p[1], p[2], p[3], p[4], p[5]
            if relativeTo == frame and type(point) == "string" and point:upper():find("TOP", 1, true) then
                y = (y or 0) - shift
            end
            f:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
        end
        if ns.AuraRemindersEmbeddedSkin and f:IsShown() then ns.AuraRemindersEmbeddedSkin.SkinWindow(window) end
    end
end

local function Layout(frame)
    if frame.kuiLayingOut then return end
    frame.kuiLayingOut = true
    HideChrome(frame)
    local width, height = frame:GetWidth(), frame:GetHeight()
    local state = frame.kuiPane
    local x,y = 0,0
    for _, button in ipairs(state.buttons) do
        if x > 0 and x + button.kuiWidth > width then x,y = 0,y+40 end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", x,-y)
        button:SetWidth(math.min(button.kuiWidth,width))
        if button.active and button.active() then button.kuiLabel:SetTextColor(Accent())
        else button.kuiLabel:SetTextColor(0.95,0.95,0.95,1) end
        x = x + button.kuiWidth + 8
    end
    if state.move then
        local placing = not KUIAR_EngineOptionsSaved.lockPositions and not UnlockMode()
        state.move.kuiLabel:SetText(L(placing and "Lock Custom Auras" or "Move on Screen"))
    end
    local top = y + 46
    local listWidth = math.min(250, math.max(170, width * 0.27))
    if frame.filterInput then
        frame.filterInput:ClearAllPoints()
        frame.filterInput:SetPoint("TOPLEFT", frame, "TOPLEFT", 8,-top)
        frame.filterInput:SetPoint("TOPRIGHT", frame, "TOPLEFT", listWidth-8,-top)
        frame.filterInput:SetHeight(24)
    end
    if frame.buttonsContainer then
        local left = frame.buttonsContainer.frame
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0,-top-30)
        left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", listWidth,0)
    end
    if frame.container then
        local right = frame.container.frame
        right:ClearAllPoints()
        right:SetPoint("TOPLEFT", frame, "TOPLEFT", listWidth+16,-top)
        right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0,0)
        frame.container.content:ClearAllPoints()
        frame.container.content:SetPoint("TOPLEFT", right, "TOPLEFT", 0,0)
        frame.container.content:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0,0)
    end
    if state.gallery then
        state.gallery:ClearAllPoints()
        state.gallery:SetPoint("TOPLEFT", frame, "TOPLEFT", listWidth+16,-top)
        state.gallery:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10,0)
        state.gallery:SetShown(state.galleryWanted and frame.window == "default")
        if state.galleryWanted and frame.window == "default" then Hide(frame.container and frame.container.frame) end
        if state.layoutGallery then state.layoutGallery(math.max(1,width-listWidth-26)) end
    end
    PaintWidget(frame.buttonsScroll)
    PaintWidget(frame.loadedButton)
    PaintWidget(frame.unloadedButton)
    PaintWidget(frame.container)
    -- Every Ace control of the option forms drawn as a KUI control.
    if ns.AuraRemindersEmbeddedSkin then ns.AuraRemindersEmbeddedSkin.Attach(frame) end
    local ok, err = pcall(PlaceWindows, frame, top)
    if not ok and geterrorhandler then geterrorhandler()(err) end
    frame.kuiLayingOut = nil
end

local function Gallery(frame)
    local state = frame.kuiPane
    if state.gallery then state.gallery:Hide() end
    state.galleryWanted = true
    -- Release the engine's template gallery; KUI owns the creation surface.
    if frame.container then frame.container:ReleaseChildren(); frame.container.frame:Hide() end
    local gallery = state.gallery
    if not gallery then
        gallery = CreateFrame("Frame", nil, frame)
        state.gallery = gallery
        gallery.scroll, gallery.content = KT.Widgets:ScrollFrame(gallery,
            { contentWidth = 400, wheelStep = 45, scrollBarWidth = 6, thumbWidth = 4, autoHide = true })
        gallery.scroll:SetPoint("TOPLEFT", 0,0)
        gallery.scroll:SetPoint("BOTTOMRIGHT", -8,0)
    end
    for _, card in ipairs(state.cards or {}) do card:Hide() end
    state.cards = state.cards or {}
    local options, core, api = E.Options(), E.Core(), E.API()
    local target = frame:GetTargetAura()
    local targetData = target and api.GetData(target)
    local dynamic = targetData and targetData.regionType == "dynamicgroup"
    if targetData and targetData.parent then
        local parent = api.GetData(targetData.parent)
        dynamic = dynamic or (parent and parent.regionType == "dynamicgroup")
    end
    local entries = {}
    local function Add(title, description, icon, click)
        entries[#entries+1] = { title=title, description=description, icon=icon, click=click }
    end
    -- Aura (Modern) displays and their growing groups come with the Forever engine only.
    if not dynamic and core.BlizzardAuraDisplay then
        Add("Modern Aura Group", "A group whose Aura (Modern) displays grow together, also in combat", "group", function()
            api.NewAura({ blizzardFlow=true, blizzardFlowGrowth="RIGHT", blizzardFlowSpacing=2,
                blizzardFlowOrigin="group" }, "group", frame:GetTargetAura())
        end)
    end
    local types = {}
    for kind in pairs(core.regionOptions) do types[#types+1] = kind end
    table.sort(types, function(a,b)
        local rank = { group=1, dynamicgroup=2 }
        if (rank[a] or 3) ~= (rank[b] or 3) then return (rank[a] or 3) < (rank[b] or 3) end
        return core.regionOptions[a].displayName < core.regionOptions[b].displayName
    end)
    local icons = { group="group", dynamicgroup="group", empty="blank", icon="custom", model="tab_display",
        aurabar="tab_stacks", progresstexture="tab_display", stopmotion="tab_anim", text="ed_copy", texture="tab_display" }
    for _, kind in ipairs(types) do
        if not (dynamic and (kind=="group" or kind=="dynamicgroup")) then
            local region = core.regionOptions[kind]
            local regionType = kind
            Add(region.displayName, region.description, icons[kind] or "custom", function()
                api.NewAura(nil, regionType, frame:GetTargetAura())
            end)
        end
    end
    if options.OpenTriggerTemplate then
        Add("Premade Auras", "Offer a guided way to create auras for your character", "talents", function()
            options.OpenTriggerTemplate(nil, frame:GetTargetAura())
        end)
    end
    Add("Import Auras", "Import a display from an encoded string", "ed_import", options.ImportFromString)
    for i, entry in ipairs(entries) do
        local card = state.cards[i]
        if not card then
            card = Button(gallery.content, "", "custom", nil)
            card.image = card.kuiIcon
            card.image:ClearAllPoints()
            card.image:SetSize(26,26)
            card.image:SetPoint("LEFT",12,0)
            card.title = card.kuiLabel
            card.title:ClearAllPoints()
            card.title:SetFont(Font(),13,"")
            card.title:SetPoint("TOPLEFT",52,-12)
            card.title:SetPoint("TOPRIGHT",-10,-12)
            card.title:SetJustifyH("LEFT")
            card.description = card:CreateFontString(nil,"OVERLAY")
            card.description:SetFont(Font(),11,"")
            card.description:SetTextColor(0.7,0.7,0.74,1)
            card.description:SetPoint("TOPLEFT",card.title,"BOTTOMLEFT",0,-5)
            card.description:SetPoint("BOTTOMRIGHT",card,"BOTTOMRIGHT",-10,8)
            card.description:SetJustifyH("LEFT")
            state.cards[i] = card
        end
        card.image:SetTexture(ICONS..entry.icon..".png")
        card.image:SetVertexColor(Accent())
        card.title:SetText(api.L[entry.title] or L(entry.title))
        card.title:SetTextColor(0.95,0.95,0.95,1)
        card.description:SetText(api.L[entry.description] or L(entry.description))
        card:SetScript("OnClick",entry.click)
        card:Show()
    end
    state.layoutGallery = function(width)
        local columns = width >= 550 and 2 or 1
        local w = (width - 8 - (columns-1)*10)/columns
        gallery.content:SetWidth(width-8)
        for i=1,#entries do
            local card = state.cards[i]
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT",gallery.content,"TOPLEFT",((i-1)%columns)*(w+10),-math.floor((i-1)/columns)*82)
            card:SetSize(w,72)
        end
        gallery.content:SetHeight(math.ceil(#entries/columns)*82)
        if gallery.scroll.UpdateScrollBar then gallery.scroll:UpdateScrollBar(true) end
    end
    if gallery.scroll.UpdateScrollBar then gallery.scroll:UpdateScrollBar(false) end
    Layout(frame)
end

function M.Attach(frame)
    if not frame.kuiPane then
        local state = { buttons={} }
        frame.kuiPane = state
        local options, core = E.Options(), E.Core()
        local function Action(text, icon, width, fn)
            local b = Button(frame,text,icon,function() fn(); Layout(frame) end)
            b.kuiWidth = width
            state.buttons[#state.buttons+1] = b
            return b
        end
        Action("New Aura","ed_new",160,function() frame:NewAura() end)
        Action("Import Auras","ed_import",150,options.ImportFromString)
        -- KUI's unlock mode places the engine's auras with every other element; without it, the engine's own movers.
        state.move = Action("Move on Screen","ed_move",180,function()
            local movers = ns.AuraRemindersEmbeddedMovers
            if movers and UnlockMode() and movers.Open() then return end
            KUIAR_EngineOptionsSaved.lockPositions = not KUIAR_EngineOptionsSaved.lockPositions
        end)
        state.move.active = function() return not UnlockMode() and not KUIAR_EngineOptionsSaved.lockPositions end
        if core.TimeMachine and core.Features and core.Features:Enabled("undo") then
            Action("Undo","ed_undo",90,function() core.TimeMachine:StepBackward(); frame:FillOptions() end)
            Action("Redo","ed_copy",90,function() core.TimeMachine:StepForward(); frame:FillOptions() end)
        end
        local align = Action("Magnetically Align","group",170,function()
            KUIAR_EngineOptionsSaved.magnetAlign = not KUIAR_EngineOptionsSaved.magnetAlign
        end)
        align.active = function() return KUIAR_EngineOptionsSaved.magnetAlign end
        -- The Cooldown Manager tools are part of the Forever engine only.
        if C_CooldownViewer and core.ApplyCDMBackground then
            local hideCDM = Action("Hide Blizzard's CDM","cdm",180,function()
                core.db.cdmHideBlizzard = not core.db.cdmHideBlizzard
                core.ApplyCDMBackground()
            end)
            hideCDM.active = function() return core.db.cdmHideBlizzard end
            Action("Set Up CDM","tab_conditions",140,function() StaticPopup_Show("FOREVERAURAS_CDM_SETUP_CONFIRM") end)
        end
        hooksecurefunc(frame,"NewAura",function() Gallery(frame) end)
        hooksecurefunc(frame,"FillOptions",function()
            state.galleryWanted = false
            Hide(state.gallery)
            frame.container.frame:Show()
            Layout(frame)
        end)
        hooksecurefunc(frame,"UpdateFrameVisible",function() Layout(frame) end)
        -- With KUI's unlock mode placing the auras, the engine's own mover box is not drawn over the editor.
        local sizer = frame.moversizer
        if sizer and sizer.HookScript then
            sizer:HookScript("OnShow", function(self)
                if not UnlockMode() then return end
                self:Hide()
                if frame.mover and frame.mover.Hide then frame.mover:Hide() end
            end)
            if sizer:IsShown() and UnlockMode() then sizer:Hide() end
        end
        if options.SortDisplayButtons then hooksecurefunc(options,"SortDisplayButtons",function() Layout(frame) end) end
        if not frame.pickedDisplay then Gallery(frame) end
    end
    Layout(frame)
end
