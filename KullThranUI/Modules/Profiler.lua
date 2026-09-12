local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
local Profiler = KT:NewModule("Profiler")

local _G = _G
local CreateFrame = _G.CreateFrame
local UpdateAddOnMemoryUsage = _G.UpdateAddOnMemoryUsage
local GetAddOnMemoryUsage = _G.GetAddOnMemoryUsage
local GetNumAddOns = _G.C_AddOns and _G.C_AddOns.GetNumAddOns or _G.GetNumAddOns
local GetAddOnInfo = _G.C_AddOns and _G.C_AddOns.GetAddOnInfo or _G.GetAddOnInfo
local UIParent = _G.UIParent
local C_Timer = _G.C_Timer

local debugFrame
local memoryFontString
local isWindowVisible = false
local combatRecordEnabled = false
local combatStartMemory = {}
local eventFrame = CreateFrame("Frame")

local function FormatMemory(mem)
    local isNegative = mem < 0
    local absMem = math.abs(mem)
    local sign = isNegative and "-" or ""
    
    if absMem > 1024 then
        return string.format("%s%.2f MB", sign, absMem / 1024)
    else
        return string.format("%s%.1f KB", sign, absMem)
    end
end

local function GetKullThranUIMemory()
    UpdateAddOnMemoryUsage()
    local data = {}
    local total = 0
    local numAddons = GetNumAddOns()
    for i = 1, numAddons do
        local name = GetAddOnInfo(i)
        if name and string.match(name, "^KullThranUI") then
            local mem = GetAddOnMemoryUsage(name)
            total = total + mem
            data[name] = mem
        end
    end
    return data, total
end

local function UpdateMemoryInfo()
    if not isWindowVisible or not debugFrame then return end
    
    local data, totalKUMemory = GetKullThranUIMemory()
    local text = "|cff00FF88KullThranUI Memory Profiler|r\n\n"
    
    local addons = {}
    for name, mem in pairs(data) do
        table.insert(addons, {name = name, mem = mem})
    end
    
    -- Sort by memory usage descending
    table.sort(addons, function(a, b) return a.mem > b.mem end)
    
    for i = 1, #addons do
        text = text .. addons[i].name .. ": " .. FormatMemory(addons[i].mem) .. "\n"
    end
    
    text = text .. "\n|cffFFAA00Total: " .. FormatMemory(totalKUMemory) .. "|r"
    
    memoryFontString:SetText(text)
end

local function ToggleDebugWindow()
    if not debugFrame then
        debugFrame = CreateFrame("Frame", "KullThranUIDebugProfiler", UIParent, "BackdropTemplate")
        debugFrame:SetSize(320, 450)
        debugFrame:SetPoint("CENTER")
        debugFrame:SetFrameStrata("DIALOG")
        debugFrame:SetMovable(true)
        debugFrame:EnableMouse(true)
        debugFrame:RegisterForDrag("LeftButton")
        debugFrame:SetScript("OnDragStart", debugFrame.StartMoving)
        debugFrame:SetScript("OnDragStop", debugFrame.StopMovingOrSizing)
        
        if debugFrame.SetBackdrop then
            debugFrame:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 8, right = 8, top = 8, bottom = 8 }
            })
        end
        
        local closeBtn = CreateFrame("Button", nil, debugFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", -4, -4)
        closeBtn:SetScript("OnClick", function() debugFrame:Hide() end)
        
        local refreshBtn = CreateFrame("Button", nil, debugFrame, "UIPanelButtonTemplate")
        refreshBtn:SetSize(80, 22)
        refreshBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -4, -4)
        refreshBtn:SetText(LText("Refresh"))
        refreshBtn:SetScript("OnClick", UpdateMemoryInfo)
        
        local scrollFrame = CreateFrame("ScrollFrame", nil, debugFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 16, -16)
        scrollFrame:SetPoint("BOTTOMRIGHT", -32, 16)
        
        local content = CreateFrame("Frame", nil, scrollFrame)
        content:SetSize(270, 800)
        scrollFrame:SetScrollChild(content)
        
        memoryFontString = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        memoryFontString:SetPoint("TOPLEFT", 0, 0)
        memoryFontString:SetJustifyH("LEFT")
        memoryFontString:SetJustifyV("TOP")
        
        debugFrame:SetScript("OnShow", function()
            isWindowVisible = true
            UpdateMemoryInfo()
        end)
        
        debugFrame:SetScript("OnHide", function()
            isWindowVisible = false
        end)
    end
    
    if debugFrame:IsShown() then
        debugFrame:Hide()
    else
        debugFrame:Show()
    end
end

local function ShowDumpWindow(titleStr, text)
    if not KT.ProfilerDumpFrame then
        local frame = CreateFrame("Frame", "KTProfilerDumpFrame", UIParent, "BackdropTemplate")
        frame:SetSize(500, 400)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        
        if frame.SetBackdrop then
            frame:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true, tileSize = 32, edgeSize = 32,
                insets = { left = 8, right = 8, top = 8, bottom = 8 }
            })
        end
        
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function() frame:Hide() end)
        
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -12)
        frame.title = title
        
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -36)
        scroll:SetPoint("BOTTOMRIGHT", -32, 16)
        
        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(true)
        editBox:SetFontObject("ChatFontNormal")
        editBox:SetWidth(440)
        editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
        scroll:SetScrollChild(editBox)
        
        frame.editBox = editBox
        KT.ProfilerDumpFrame = frame
    end
    
    KT.ProfilerDumpFrame.title:SetText(titleStr)
    KT.ProfilerDumpFrame.editBox:SetText(text)
    KT.ProfilerDumpFrame.editBox:HighlightText()
    KT.ProfilerDumpFrame:Show()
end

local function DumpMemoryInfo()
    local data, total = GetKullThranUIMemory()
    local text = "KullThranUI Manual Memory Dump (" .. date("%Y-%m-%d %H:%M:%S") .. ")\n\n"
    
    local list = {}
    for name, mem in pairs(data) do
        table.insert(list, {name = name, mem = mem})
    end
    table.sort(list, function(a, b) return a.mem > b.mem end)
    
    for i = 1, #list do
        text = text .. list[i].name .. ": " .. FormatMemory(list[i].mem) .. "\n"
    end
    text = text .. "\nTotal: " .. FormatMemory(total)
    
    ShowDumpWindow("KullThranUI Detailed Memory Dump", text)
end

local lastCombatText = ""

local function ProcessCombatEnd()
    local endData, endTotal = GetKullThranUIMemory()
    local text = "KullThranUI Combat Memory Dump (" .. date("%Y-%m-%d %H:%M:%S") .. ")\n\n"
    
    local list = {}
    local totalDiff = 0
    for name, endMem in pairs(endData) do
        local startMem = combatStartMemory[name] or endMem
        local diff = endMem - startMem
        totalDiff = totalDiff + diff
        table.insert(list, {name = name, diff = diff, endMem = endMem})
    end
    table.sort(list, function(a, b) return a.diff > b.diff end)
    
    for i = 1, #list do
        if list[i].diff > 0.1 or list[i].diff < -0.1 then
            local diffSign = list[i].diff > 0 and "+" or ""
            text = text .. list[i].name .. ": " .. diffSign .. FormatMemory(list[i].diff) .. " (End: " .. FormatMemory(list[i].endMem) .. ")\n"
        end
    end
    
    local totalSign = totalDiff > 0 and "+" or ""
    text = text .. "\nTotal Combat Growth: " .. totalSign .. FormatMemory(totalDiff)
    
    lastCombatText = text
    ShowDumpWindow("KullThranUI Combat Memory Dump", text)
end

eventFrame:SetScript("OnEvent", function(self, event)
    if not combatRecordEnabled then return end
    if event == "PLAYER_REGEN_DISABLED" then
        combatStartMemory, _ = GetKullThranUIMemory()
        print("|cff00FF88[KT Profiler]|r Combat started, memory snapshot taken.")
    elseif event == "PLAYER_REGEN_ENABLED" then
        print("|cff00FF88[KT Profiler]|r Combat ended, calculating difference...")
        local ok, err = pcall(ProcessCombatEnd)
        if not ok then
            print("|cffFF0000[KT Profiler Error]|r " .. tostring(err))
        end
    end
end)

SLASH_KUIDEBUG1 = "/kuidebug"
SLASH_KUIDEBUG2 = "/kuiprofiler"
SlashCmdList["KUIDEBUG"] = function(msg)
    if msg and string.lower(msg) == "dump" then
        DumpMemoryInfo()
    elseif msg and string.lower(msg) == "lastcombat" then
        if lastCombatText and lastCombatText ~= "" then
            ShowDumpWindow("KullThranUI Combat Memory Dump", lastCombatText)
        else
            print("|cffFFAA00[KT Profiler]|r No hay registros de combate guardados.")
        end
    elseif msg and string.lower(msg) == "combat" then
        combatRecordEnabled = not combatRecordEnabled
        if combatRecordEnabled then
            eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
            eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            print("|cff00FF88[KT Profiler]|r Modo Combate Automático: |cff00FF00ACTIVADO|r")
        else
            eventFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
            eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
            print("|cff00FF88[KT Profiler]|r Modo Combate Automático: |cffFF0000DESACTIVADO|r")
        end
    else
        ToggleDebugWindow()
    end
end
 
