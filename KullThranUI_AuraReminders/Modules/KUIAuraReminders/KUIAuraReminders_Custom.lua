local ADDON_NAME, ns = ...
local KT = (ns and ns.KT) or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

-- Global exposed tables
_G.KUIAuraReminders_Custom = _G.KUIAuraReminders_Custom or {}
local CustomSys = _G.KUIAuraReminders_Custom

local customFrames = {}
local activeAuras = {}
local dbProfile = nil

-------------------------------------------------------------------------------
--  Helpers
-------------------------------------------------------------------------------
local function GetAuraData(unit, spellID, filter)
    if not (unit and spellID and C_UnitAuras) then return nil, false end

    local directFn
    if unit == "player" and filter == "HELPFUL" then
        directFn = C_UnitAuras.GetPlayerAuraBySpellID
    elseif C_UnitAuras.GetUnitAuraBySpellID then
        directFn = C_UnitAuras.GetUnitAuraBySpellID
    end
    if directFn then
        local ok, data
        if directFn == C_UnitAuras.GetPlayerAuraBySpellID then
            ok, data = pcall(directFn, spellID)
        else
            ok, data = pcall(directFn, unit, spellID)
        end
        if ok then return data, true end
    end

    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    if not (issecretvalue and issecretvalue(name)) and name and C_UnitAuras.GetAuraDataBySpellName then
        local ok, data = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, filter)
        if ok then return data, true end
    end

    return nil, false
end

local function SafeGlowCall(method, wrapper, ...)
    local fn = KT.Glows and KT.Glows[method]
    if type(fn) == "function" then
        return fn(wrapper, ...)
    end
end

local function StartButtonGlow(wrapper, sz, cr, cg, cb, scale)
    SafeGlowCall("StartButtonGlow", wrapper, sz, cr, cg, cb, scale)
end
local function StopButtonGlow(wrapper) 
    SafeGlowCall("StopButtonGlow", wrapper) 
end

-------------------------------------------------------------------------------
--  Frame Management
-------------------------------------------------------------------------------
local function CreateCustomAuraFrame(uid)
    local f = CreateFrame("Frame", "KUICustomAura_"..uid, UIParent, "BackdropTemplate")
    f:SetSize(40, 40)
    f:SetPoint("CENTER", 0, 0)
    f:Hide()
    f:SetMovable(true)
    f:SetClampedToScreen(true)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetAllPoints()
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    f.border = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.border:SetPoint("TOPLEFT", -2, 2)
    f.border:SetPoint("BOTTOMRIGHT", 2, -2)
    KT:AddBackdrop(f.border, 0, 0, 0, 0)
    KT:AddBorder(f.border, 0, 0, 0, 1)

    local font = KT and KT.ResolveFontPath and KT:ResolveFontPath() or "Fonts\\FRIZQT__.TTF"
    f.valueText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.valueText:SetPoint("CENTER", 0, 0)
    f.valueText:SetFont(font, 18, "OUTLINE")

    f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.nameText:SetPoint("BOTTOM", 0, -15)
    f.nameText:SetFont(font, 10, "OUTLINE")

    f.glow = CreateFrame("Frame", nil, f)
    f.glow:SetAllPoints()

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) if CustomSys.UnlockMode then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self) 
        self:StopMovingOrSizing() 
        local conf = dbProfile.customAuras[self.uid]
        if conf then
            local p, _, rp, x, y = self:GetPoint()
            conf.point = p
            conf.relativePoint = rp
            conf.xOffset = x
            conf.yOffset = y
        end
    end)

    f:SetScript("OnUpdate", function(self)
        if self.mode == "DURATION" and self.expirationTime and self.expirationTime > 0 then
            local remain = self.expirationTime - GetTime()
            if remain > 0 then
                if remain >= 3600 then
                    self.valueText:SetText(string.format("%dh", math.ceil(remain / 3600)))
                elseif remain >= 60 then
                    self.valueText:SetText(string.format("%dm", math.ceil(remain / 60)))
                elseif remain > 5 then
                    self.valueText:SetText(tostring(math.floor(remain)))
                elseif remain > 0 then
                    self.valueText:SetText(string.format("%.1f", remain))
                end
            else
                self.valueText:SetText("")
            end
        end
    end)

    return f
end

local function GetCustomAuraFrame(uid)
    if not customFrames[uid] then
        customFrames[uid] = CreateCustomAuraFrame(uid)
        customFrames[uid].uid = uid
    end
    return customFrames[uid]
end

-------------------------------------------------------------------------------
--  Condition Evaluation
-------------------------------------------------------------------------------
local function CheckLoadConditions(conf)
    if not conf.enabled then return false end
    
    -- Combat
    local inCombat = InCombatLockdown()
    if conf.loadCombat == "IN_COMBAT" and not inCombat then return false end
    if conf.loadCombat == "OUT_COMBAT" and inCombat then return false end

    -- Talent
    if conf.loadTalent and conf.loadTalent > 0 then
        local known = IsPlayerSpell(conf.loadTalent)
        if not known then return false end
    end
    
    -- Instance
    if conf.loadInstance and conf.loadInstance ~= "ANY" then
        local _, instanceType = IsInInstance()
        if conf.loadInstance == "RAID" and instanceType ~= "raid" then return false end
        if conf.loadInstance == "PARTY" and instanceType ~= "party" then return false end
        if conf.loadInstance == "ARENA" and instanceType ~= "arena" then return false end
        if conf.loadInstance == "PVP" and instanceType ~= "pvp" then return false end
        if conf.loadInstance == "NONE" and instanceType ~= "none" then return false end
    end

    -- Zone Map ID
    if conf.loadZoneID and conf.loadZoneID > 0 then
        local currentMap = C_Map.GetBestMapForUnit("player")
        if currentMap ~= conf.loadZoneID then return false end
    end

    return true
end

local function CheckTrigger(conf)
    if conf.triggerType == "AURA" then
        local unit = conf.triggerUnit or "player"
        -- The options store Blizzard aura filter values (HELPFUL/HARMFUL).
        -- Keep accepting DEBUFF as a legacy value for existing profiles.
        local isDebuff = conf.triggerAuraType == "HARMFUL" or conf.triggerAuraType == "DEBUFF"
        local filter = isDebuff and "HARMFUL" or "HELPFUL"
        local data, readable = GetAuraData(unit, conf.triggerSpellID, filter)
        if not readable then return false, nil end
        if conf.triggerAuraMissing then
            return data == nil, nil
        else
            return data ~= nil, data
        end
    elseif conf.triggerType == "COOLDOWN" then
        local cooldownInfo = C_Spell.GetSpellCooldown(conf.triggerSpellID)
        local start = cooldownInfo and cooldownInfo.startTime or 0
        local duration = cooldownInfo and cooldownInfo.duration or 0
        local onCooldown = (start and start > 0 and duration > 1.5)
        if conf.triggerCooldownReady then
            return not onCooldown, nil
        else
            return onCooldown, {expirationTime = start + duration, duration = duration, applications = 0}
        end
    end
    return false, nil
end

-------------------------------------------------------------------------------
--  Core Loop
-------------------------------------------------------------------------------
local function UpdateCustomAuras()
    if not dbProfile or not dbProfile.customAuras then return end

    local GetTex = function(id) return _G._KUIAR_Tex and _G._KUIAR_Tex(id) or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 134400 end

    for uid, conf in pairs(dbProfile.customAuras) do
        local f = GetCustomAuraFrame(uid)
        if CustomSys.UnlockMode then
            f:Show()
            f:SetAlpha(1)
            f:EnableMouse(true)
            f.icon:SetTexture(GetTex(conf.triggerSpellID or 1))
            f.nameText:SetText(conf.name or "Custom Aura")
            f.nameText:SetShown(conf.showNameLabel == true)
            f.valueText:SetText(conf.customTextValue or "")
            if conf.displayStyle == "TEXT" then
                f.icon:Hide()
                f.border:Hide()
                f.glow:Hide()
            else
                f.icon:Show()
                f.border:Show()
                f.glow:Show()
            end
            if conf.point then
                f:ClearAllPoints()
                f:SetPoint(conf.point, UIParent, conf.relativePoint, conf.xOffset, conf.yOffset)
            end
            f:SetSize(conf.size or 40, conf.size or 40)
            f.mode = "NONE"
        else
            f:EnableMouse(false)
            if CheckLoadConditions(conf) then
                local active, data = CheckTrigger(conf)
                if active then
                    f:Show()
                    f:SetAlpha(conf.opacity or 1.0)
                    f.icon:SetTexture(GetTex(conf.triggerSpellID or 1))
                    
                    if conf.point then
                        f:ClearAllPoints()
                        f:SetPoint(conf.point, UIParent, conf.relativePoint, conf.xOffset, conf.yOffset)
                    end
                    f:SetSize(conf.size or 40, conf.size or 40)

                    if conf.displayStyle == "TEXT" then
                        f.icon:Hide()
                        f.border:Hide()
                        f.glow:Hide()
                    else
                        f.icon:Show()
                        f.border:Show()
                        f.glow:Show()
                    end

                    if conf.showNameLabel ~= false then
                        f.nameText:SetText(conf.name or "")
                        f.nameText:Show()
                    else
                        f.nameText:Hide()
                    end

                    if conf.displayStyle ~= "TEXT" and conf.showGlow then
                        StartButtonGlow(f.glow, conf.size or 40, 1, 0.8, 0.2, 1.2)
                    else
                        StopButtonGlow(f.glow)
                    end

                    -- Value Text
                    if conf.customTextType == "STATIC" then
                        f.mode = "STATIC"
                        f.valueText:SetText(conf.customTextValue or "")
                    elseif conf.customTextType == "STACKS" then
                        f.mode = "STACKS"
                        local stacks = data and data.applications
                        if stacks and issecretvalue and issecretvalue(stacks) then stacks = nil end
                        f.valueText:SetText((stacks and stacks > 1) and tostring(stacks) or "")
                    elseif conf.customTextType == "DURATION" then
                        f.mode = "DURATION"
                        local expiration = data and data.expirationTime
                        local duration = data and data.duration
                        if expiration and issecretvalue and issecretvalue(expiration) then expiration = nil end
                        if duration and issecretvalue and issecretvalue(duration) then duration = nil end
                        if expiration and expiration > 0 then
                            f.expirationTime = expiration
                            f.duration = duration
                        else
                            f.expirationTime = nil
                            f.valueText:SetText("")
                        end
                    else
                        f.mode = "NONE"
                        f.valueText:SetText("")
                    end

                else
                    f:Hide()
                    StopButtonGlow(f.glow)
                    f.mode = "NONE"
                end
            else
                f:Hide()
                StopButtonGlow(f.glow)
                f.mode = "NONE"
            end
        end
    end
end

-------------------------------------------------------------------------------
--  Event Engine
-------------------------------------------------------------------------------
local engine = CreateFrame("Frame")
engine:RegisterEvent("UNIT_AURA")
engine:RegisterEvent("PLAYER_REGEN_DISABLED")
engine:RegisterEvent("PLAYER_REGEN_ENABLED")
engine:RegisterEvent("SPELL_UPDATE_COOLDOWN")
engine:RegisterEvent("PLAYER_ENTERING_WORLD")

engine:SetScript("OnEvent", function()
    UpdateCustomAuras()
end)

function CustomSys:Init(db)
    dbProfile = db.profile
    -- Ensure customAuras exists
    if type(dbProfile.customAuras) ~= "table" then
        dbProfile.customAuras = {}
    end
    UpdateCustomAuras()
end

function CustomSys:SetUnlockMode(state)
    self.UnlockMode = state
    UpdateCustomAuras()
end

function CustomSys:ForceUpdate()
    UpdateCustomAuras()
end
