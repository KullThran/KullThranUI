local ADDON_NAME, ns = ...

ns.CDM_RebuildKeybindCache_Impl = function()
    local wipe = _G.wipe
    local type = _G.type
    local tonumber = _G.tonumber
    local ipairs = _G.ipairs
    local pairs = _G.pairs
    local pcall = _G.pcall
    local rawget = _G.rawget
    local select = _G.select
    local strtrim = _G.strtrim
    local strlower = _G.strlower
    local GetTime = _G.GetTime
    local GetBinding = _G.GetBinding
    local GetNumBindings = _G.GetNumBindings
    local GetBindingKey = _G.GetBindingKey
    local GetMacroIndexByName = _G.GetMacroIndexByName
    local GetMacroInfo = _G.GetMacroInfo
    local GetMacroSpell = _G.GetMacroSpell
    local GetMacroItem = _G.GetMacroItem
    local GetActionInfo = _G.GetActionInfo
    local GetInventoryItemID = _G.GetInventoryItemID

    wipe(ns.CDMKeybindCache)
    wipe(ns._cdmTrinketSlotKeybindCache)
    wipe(ns._cdmActionSlotCache)
    wipe(ns._cdmTrinketMacroDebug.entries)
    ns._cdmTrinketMacroDebug.rebuildCount = (ns._cdmTrinketMacroDebug.rebuildCount or 0) + 1
    ns._cdmTrinketMacroDebug.lastUpdated = GetTime and GetTime() or 0
    -- Helper: registra spellID -> keybind (solo primero encontrado)
    local function Register(spellID, formattedKey, actionSlot)
        if not spellID then return end
        if formattedKey and formattedKey ~= "" and not ns.CDMKeybindCache[spellID] then
            ns.CDMKeybindCache[spellID] = formattedKey
        end
        if type(actionSlot) == "number" and actionSlot > 0 and not ns._cdmActionSlotCache[spellID] then
            ns._cdmActionSlotCache[spellID] = actionSlot
        end
        if type(spellID) ~= "number" or spellID <= 0 then return end
        -- Also cache spell names to resolve macro tokens
        local name = C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
        if name and formattedKey and formattedKey ~= "" and not ns.CDMKeybindCache[name] then
            ns.CDMKeybindCache[name] = formattedKey
        end
        if name and type(actionSlot) == "number" and actionSlot > 0 and not ns._cdmActionSlotCache[name] then
            ns._cdmActionSlotCache[name] = actionSlot
        end
        if name then
            local lowerName = strlower(name)
            if lowerName ~= "" and formattedKey and formattedKey ~= "" and not ns.CDMKeybindCache[lowerName] then
                ns.CDMKeybindCache[lowerName] = formattedKey
            end
            if lowerName ~= "" and type(actionSlot) == "number" and actionSlot > 0 and not ns._cdmActionSlotCache[lowerName] then
                ns._cdmActionSlotCache[lowerName] = actionSlot
            end
        end
        -- Override spell
        local over = C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(spellID)
        if over and over ~= spellID then
            if formattedKey and formattedKey ~= "" and not ns.CDMKeybindCache[over] then
                ns.CDMKeybindCache[over] = formattedKey
            end
            if type(actionSlot) == "number" and actionSlot > 0 and not ns._cdmActionSlotCache[over] then
                ns._cdmActionSlotCache[over] = actionSlot
            end
        end
    end

    local function ResolveSpellIDFromSpellToken(token)
        token = type(token) == "string" and strtrim(token) or nil
        if not token or token == "" then return nil end

        local numericSpellID = tonumber(token)
            or tonumber(token:match("^spell:(%d+)$"))
            or tonumber(token:match("|Hspell:(%d+)"))
        if numericSpellID then
            local spellInfoByID = rawget(_G, "GetSpellInfo") and { rawget(_G, "GetSpellInfo")(numericSpellID) } or nil
            local resolvedByID = spellInfoByID and spellInfoByID[7]
            if resolvedByID then
                return resolvedByID
            end

            if C_Spell and C_Spell.GetSpellInfo then
                local ok, info = pcall(C_Spell.GetSpellInfo, numericSpellID)
                if ok and type(info) == "table" and info.spellID then
                    return info.spellID
                end
            end
        end

        local spellInfo = rawget(_G, "GetSpellInfo") and { rawget(_G, "GetSpellInfo")(token) } or nil
        local spellID = spellInfo and spellInfo[7]
        if spellID then
            return spellID
        end

        if C_Spell and C_Spell.GetSpellInfo then
            local ok, info = pcall(C_Spell.GetSpellInfo, token)
            if ok and type(info) == "table" and info.spellID then
                return info.spellID
            end
        end

        return nil
    end
    ns.ResolveSpellIDFromSpellToken = ResolveSpellIDFromSpellToken

    local function ResolveInventorySlotFromToken(token)
        token = type(token) == "string" and strtrim(token) or nil
        if not token or token == "" then
            return nil
        end

        local lowerToken = strlower(token)
        local slot = tonumber(token)
        if not slot then
            if lowerToken == "trinket1" or lowerToken == "trinket 1" then
                slot = TRINKET_SLOT_1
            elseif lowerToken == "trinket2" or lowerToken == "trinket 2" then
                slot = TRINKET_SLOT_2
            end
        end

        if slot == TRINKET_SLOT_1 or slot == TRINKET_SLOT_2 then
            return slot
        end

        return nil
    end

    local function ResolveInventorySlotIdentifier(token)
        local slot = ResolveInventorySlotFromToken(token)
        if not slot then
            return nil
        end

        local itemID = GetInventoryItemID("player", slot)
        if not itemID then
            return nil
        end

        if C_Item and C_Item.GetItemSpell then
            local _, itemSpellID = C_Item.GetItemSpell(itemID)
            if itemSpellID then
                return itemSpellID
            end
        end

        return ns.EncodeItemID(itemID)
    end
    local function ResolveSpellIDFromMacroBody(body)
        if type(body) ~= "string" or body == "" then
            return nil
        end

        for rawLine in body:gmatch("[^\r\n]+") do
            local line = strtrim(rawLine)
            if line ~= "" then
                line = line:gsub("^#showtooltip%s*", "")
                line = line:gsub("^/castsequence%s+", "")
                line = line:gsub("^/cast%s+", "")
                line = line:gsub("^/use%s+", "")
                line = line:gsub("^/spell%s+", "")
                line = line:gsub("^reset=[^ ]+%s+", "")
                line = line:gsub("%b[]", "")
                line = line:gsub("^!+", "")
                line = strtrim((line:match("^[^,;]+") or line))

                local identifier = ResolveInventorySlotIdentifier(line)
                if identifier then
                    return identifier
                end

                local spellID = ResolveSpellIDFromSpellToken(line)
                if spellID then
                    return spellID
                end
            end
        end

        return nil
    end

    local function ResolveIdentifierFromToken(token)
        token = type(token) == "string" and strtrim(token) or nil
        if not token or token == "" then
            return nil
        end

        local inventoryIdentifier = ResolveInventorySlotIdentifier(token)
        if inventoryIdentifier then
            return inventoryIdentifier
        end

        local spellID = ResolveSpellIDFromSpellToken(token)
        if spellID then
            return spellID
        end

        local itemID = ns.NormalizeItemID(token)
        if itemID then
            if C_Item and C_Item.GetItemSpell then
                local _, itemSpellID = C_Item.GetItemSpell(itemID)
                if itemSpellID then
                    return itemSpellID
                end
            end
            return ns.EncodeItemID(itemID)
        end

        return nil
    end

    local function RegisterMacroIdentifiers(macroID, button, formattedKey, actionSlot)
        local resolvedMacroID = macroID
        if not resolvedMacroID and button and button.GetAttribute then
            local macroToken = button:GetAttribute("macro")
                or button:GetAttribute("macro1")
                or button:GetAttribute("macroName")
                or button:GetAttribute("macroName1")
            if type(macroToken) == "number" and macroToken > 0 then
                resolvedMacroID = macroToken
            elseif type(macroToken) == "string" then
                macroToken = strtrim(macroToken)
                if macroToken ~= "" then
                    resolvedMacroID = tonumber(macroToken)
                    if (not resolvedMacroID or resolvedMacroID <= 0) and GetMacroIndexByName then
                        resolvedMacroID = GetMacroIndexByName(macroToken)
                    end
                    if resolvedMacroID and resolvedMacroID <= 0 then
                        resolvedMacroID = nil
                    end
                end
            end
        end

        local identifiers = {}
        local macroName = (resolvedMacroID and GetMacroInfo and select(1, GetMacroInfo(resolvedMacroID))) or nil

        local function AddIdentifier(identifier)
            if identifier then
                identifiers[identifier] = true
            end
        end

        local function TrackTrinketSegment(segment, inventorySlot, sourceLine)
            local entries = ns._cdmTrinketMacroDebug.entries
            if type(entries) ~= "table" then
                entries = {}
                ns._cdmTrinketMacroDebug.entries = entries
            end
            entries[#entries + 1] = {
                macroID = resolvedMacroID,
                macroName = macroName,
                actionSlot = actionSlot,
                formattedKey = formattedKey,
                segment = segment,
                slot = inventorySlot,
                sourceLine = sourceLine,
            }
            ns._cdmTrinketMacroDebug.lastUpdated = GetTime and GetTime() or 0
        end

        local function CollectFromBody(body)
            if type(body) ~= "string" or body == "" then
                return
            end

            for rawLine in body:gmatch("[^\r\n]+") do
                local line = strtrim(rawLine)
                if line ~= "" then
                    line = line:gsub("^#showtooltip%s*", "")
                    line = line:gsub("^/castsequence%s+", "")
                    line = line:gsub("^/cast%s+", "")
                    line = line:gsub("^/use%s+", "")
                    line = line:gsub("^/spell%s+", "")
                    line = line:gsub("^/click%s+", "")
                    line = line:gsub("^reset=[^ ]+%s+", "")
                    line = line:gsub("%b[]", "")
                    line = line:gsub("^!+", "")

                    for segment in line:gmatch("[^,;]+") do
                        local trimmedSegment = strtrim(segment)
                        local inventorySlot = ResolveInventorySlotFromToken(trimmedSegment)
                        if inventorySlot then
                            TrackTrinketSegment(trimmedSegment, inventorySlot, rawLine)
                            if formattedKey and formattedKey ~= "" and not ns.ns._cdmTrinketSlotKeybindCache[inventorySlot] then
                                ns.ns._cdmTrinketSlotKeybindCache[inventorySlot] = formattedKey
                            end
                        end
                        AddIdentifier(ResolveIdentifierFromToken(trimmedSegment))
                    end
                end
            end
        end

        if resolvedMacroID and GetMacroSpell then
            local macroSpell = GetMacroSpell(resolvedMacroID)
            if type(macroSpell) == "number" then
                AddIdentifier(macroSpell)
            elseif type(macroSpell) == "string" then
                AddIdentifier(ResolveIdentifierFromToken(macroSpell))
            end
        end

        if type(resolvedMacroID) == "number" and resolvedMacroID > 0 then
            AddIdentifier(ResolveIdentifierFromToken(resolvedMacroID))
        end

        if resolvedMacroID and GetMacroItem then
            local _, itemID = GetMacroItem(resolvedMacroID)
            AddIdentifier(ResolveIdentifierFromToken(itemID))
        end

        if button and button.GetAttribute then
            CollectFromBody(button:GetAttribute("macrotext") or button:GetAttribute("macrotext1"))
        end

        if resolvedMacroID and GetMacroInfo then
            local _, _, body = GetMacroInfo(resolvedMacroID)
            CollectFromBody(body)
        end

        local found = false
        for identifier in pairs(identifiers) do
            Register(identifier, formattedKey, actionSlot)
            found = true
        end

        return found
    end

    local function ResolveMacroSpellID(macroID, button)
        if not macroID and not button then
            return nil
        end

        local resolvedMacroID = macroID
        if not resolvedMacroID and button and button.GetAttribute then
            local macroToken = button:GetAttribute("macro")
                or button:GetAttribute("macro1")
                or button:GetAttribute("macroName")
                or button:GetAttribute("macroName1")
            if type(macroToken) == "number" and macroToken > 0 then
                resolvedMacroID = macroToken
            elseif type(macroToken) == "string" then
                macroToken = strtrim(macroToken)
                if macroToken ~= "" then
                    resolvedMacroID = tonumber(macroToken)
                    if (not resolvedMacroID or resolvedMacroID <= 0) and GetMacroIndexByName then
                        resolvedMacroID = GetMacroIndexByName(macroToken)
                    end
                    if resolvedMacroID and resolvedMacroID <= 0 then
                        resolvedMacroID = nil
                    end
                end
            end
        end

        if resolvedMacroID and GetMacroSpell then
            local macroSpell = GetMacroSpell(resolvedMacroID)
            if type(macroSpell) == "number" then
                return macroSpell
            elseif type(macroSpell) == "string" then
                local spellID = ResolveSpellIDFromSpellToken(macroSpell)
                if spellID then
                    return spellID
                end
            end
        end

        if resolvedMacroID and GetMacroItem and C_Item and C_Item.GetItemSpell then
            local _, itemID = GetMacroItem(resolvedMacroID)
            if itemID then
                local normalizedItemID = ns.NormalizeItemID(itemID)
                local _, spellID = C_Item.GetItemSpell(normalizedItemID or itemID)
                if spellID then
                    return spellID
                end
                return ns.EncodeItemID(normalizedItemID or itemID)
            end
        end

        if button and button.GetAttribute then
            local macroText = button:GetAttribute("macrotext") or button:GetAttribute("macrotext1")
            local spellID = ResolveSpellIDFromMacroBody(macroText)
            if spellID then
                return spellID
            end
        end

        if resolvedMacroID and GetMacroInfo then
            local _, _, body = GetMacroInfo(resolvedMacroID)
            local spellID = ResolveSpellIDFromMacroBody(body)
            if spellID then
                return spellID
            end
        end

        if type(resolvedMacroID) == "number" and resolvedMacroID > 0 then
            local directSpellID = ResolveSpellIDFromSpellToken(resolvedMacroID)
            if directSpellID then
                return directSpellID
            end
        end

        return nil
    end

    local function GetSpellIDFromActionSlot(slot, button)
        local actionType, id, subType = GetActionInfo(slot)
        if actionType == "spell" then
            return id
        end
        if actionType == "macro" and subType == "spell" and type(id) == "number" and id > 0 then
            return id
        end
        if actionType == "macro" and id then
            return ResolveMacroSpellID(id, button)
        end
        if actionType == "item" and id then
            if C_Item.GetItemSpell then
                local _n, sid = C_Item.GetItemSpell(id)
                return sid or ns.EncodeItemID(id)
            end
            return ns.EncodeItemID(id)
        end
        return nil
    end

    local function RegisterActionSlotBinding(slot, button, formattedKey)
        local actionType, actionID, subType = GetActionInfo(slot)
        if actionType == "macro" and subType == "spell" and type(actionID) == "number" and actionID > 0 then
            Register(actionID, formattedKey, slot)
            return true
        end
        if actionType == "macro" and actionID and RegisterMacroIdentifiers(actionID, button, formattedKey, slot) then
            return true
        end

        local spellID = GetSpellIDFromActionSlot(slot, button)
        if spellID then
            Register(spellID, formattedKey, slot)
            return true
        end

        return false
    end

    local function ProcessButton(button)
        if not button then return end
        local slot = button.action or button._state_action or (button.GetAttribute and button:GetAttribute("action"))

        local rawKey
        if button.HotKey then
            rawKey = button.HotKey:GetText()
        end

        local commandName = nil
        if not rawKey and button.commandName then
            commandName = button.commandName
            rawKey = GetBindingKey(commandName)
        end
        if not rawKey and button.config and button.config.keyBoundTarget then
            commandName = button.config.keyBoundTarget
            rawKey = GetBindingKey(commandName)
        end
        if not rawKey then
            commandName = ns.GetBindingCommandForButton and ns.GetBindingCommandForButton(button) or nil
            if commandName then
                rawKey = GetBindingKey(commandName)
            end
        end
        if not rawKey and ns.GetClickBindingForButton then
            local clickCommand, clickKey = ns.GetClickBindingForButton(button)
            if clickKey then
                commandName = clickCommand
                rawKey = clickKey
            end
        end

        if not rawKey or rawKey == "" then return end
        local formatted = ns.NormalizeBindingLabel(rawKey)
        if not formatted then return end

        if type(slot) == "number" and slot > 0 then
            RegisterActionSlotBinding(slot, button, formatted)
            return
        end

        local registered = false
        for _, candidateSlot in ipairs(ns.GetCandidateSlotsForBindingCommand(commandName) or {}) do
            if RegisterActionSlotBinding(candidateSlot, button, formatted) then
                registered = true
            end
        end
        if registered then
            return
        end

        if button.GetAttribute and (button:GetAttribute("macrotext") ~= nil or button:GetAttribute("macrotext1") ~= nil
            or button:GetAttribute("macro") ~= nil or button:GetAttribute("macro1") ~= nil
            or button:GetAttribute("macroName") ~= nil or button:GetAttribute("macroName1") ~= nil
            or button:GetAttribute("type") == "macro" or button:GetAttribute("type1") == "macro") then
            RegisterMacroIdentifiers(nil, button, formatted)
        end
    end

    local seenButtons = {}
    local function ProcessUniqueButton(button)
        if not button or seenButtons[button] then
            return
        end
        seenButtons[button] = true
        ProcessButton(button)
    end

    for _, def in ipairs(ns._barBindingDefs) do
        for offset = 0, 11 do
            local slot = def.startSlot + offset
            local commandName = def.prefix .. (offset + 1)
            local rawKey = GetBindingKey(commandName)
            if rawKey and rawKey ~= "" then
                local formatted = ns.NormalizeBindingLabel(rawKey)
                if formatted then
                    local button = _G[(def.prefix == "ACTIONBUTTON" and "ActionButton" or
                        def.prefix == "MULTIACTIONBAR1BUTTON" and "MultiBarBottomLeftButton" or
                        def.prefix == "MULTIACTIONBAR2BUTTON" and "MultiBarBottomRightButton" or
                        def.prefix == "MULTIACTIONBAR3BUTTON" and "MultiBarRightButton" or
                        def.prefix == "MULTIACTIONBAR4BUTTON" and "MultiBarLeftButton" or
                        def.prefix == "MULTIACTIONBAR5BUTTON" and "MultiBar5Button" or
                        def.prefix == "MULTIACTIONBAR6BUTTON" and "MultiBar6Button" or
                        "MultiBar7Button") .. (offset + 1)]
                    local candidateSlots = ns.GetCandidateSlotsForBindingCommand(commandName, slot)
                    for _, candidateSlot in ipairs(candidateSlots or {}) do
                        RegisterActionSlotBinding(candidateSlot, button, formatted)
                    end
                end
            end
        end
    end

    -- Escanear Blizzard action bars (ActionButton1..12, MultiBarXButtonY...)
    local blizzBars = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarRightButton", "MultiBarLeftButton",
        "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
    }
    for _, prefix in ipairs(blizzBars) do
        for i = 1, 12 do
            local gName = prefix .. i
            if _G[gName] then ProcessUniqueButton(_G[gName]) end
        end
    end

    -- Dominos
    if _G["DominosActionButton1"] then
        for i = 1, 180 do
            ProcessUniqueButton(_G["DominosActionButton" .. i])
        end
    end

    -- BT4
    if _G["BT4Button1"] then
        for i = 1, 180 do
            ProcessUniqueButton(_G["BT4Button" .. i])
        end
    end

    -- External layout button set
    if _G["ElvUI_Bar1Button1"] then
        for barIdx = 1, 15 do
            for btnIdx = 1, 12 do
                ProcessUniqueButton(_G["ElvUI_Bar" .. barIdx .. "Button" .. btnIdx])
            end
        end
    end

    -- Direct bindings that target a macro or spell without going through an action bar button.
    if GetNumBindings and GetBinding then
        for bindingIndex = 1, GetNumBindings() do
            local command, key1, key2 = GetBinding(bindingIndex)
            if type(command) == "string" and (key1 or key2) then
                local macroName = command:match("^MACRO%s+(.+)$")
                local spellToken = command:match("^SPELL%s+(.+)$")
                if macroName and GetMacroIndexByName then
                    local macroID = GetMacroIndexByName(macroName)
                    if macroID and macroID > 0 then
                        if key1 then RegisterMacroIdentifiers(macroID, nil, ns.NormalizeBindingLabel(key1)) end
                        if key2 then RegisterMacroIdentifiers(macroID, nil, ns.NormalizeBindingLabel(key2)) end
                    end
                elseif spellToken then
                    local spellID = ResolveSpellIDFromSpellToken(spellToken)
                    if spellID then
                        if key1 then Register(spellID, ns.NormalizeBindingLabel(key1)) end
                        if key2 then Register(spellID, ns.NormalizeBindingLabel(key2)) end
                    end
                end
            end
        end
    end

    -- Fallback: scan explicit CLICK bindings that may target addon bar buttons/wrappers.
    if GetNumBindings and GetBinding then
        for bindingIndex = 1, GetNumBindings() do
            local command, key1, key2 = GetBinding(bindingIndex)
            if type(command) == "string" and command:find("^CLICK ") then
                local bindingTarget = command:match("^CLICK%s+(.+)$")
                local buttonName = bindingTarget
                local targetButton = bindingTarget and _G[bindingTarget] or nil
                if not targetButton and type(bindingTarget) == "string" then
                    local candidateName = bindingTarget
                    while candidateName and candidateName ~= "" do
                        candidateName = candidateName:match("^(.*):[^:]+$")
                        if candidateName and candidateName ~= "" then
                            targetButton = _G[candidateName]
                            if targetButton then
                                buttonName = candidateName
                                break
                            end
                        end
                    end
                end
                if targetButton then
                    ProcessUniqueButton(targetButton)

                    local slot = targetButton.action or targetButton._state_action or (targetButton.GetAttribute and targetButton:GetAttribute("action"))
                    local rawKey = key1 or key2
                    local formatted = ns.NormalizeBindingLabel(rawKey)
                    if formatted and slot then
                        RegisterActionSlotBinding(slot, targetButton, formatted)
                    elseif formatted and targetButton.GetAttribute and (
                        targetButton:GetAttribute("macrotext") ~= nil
                        or targetButton:GetAttribute("macrotext1") ~= nil
                        or targetButton:GetAttribute("macro") ~= nil
                        or targetButton:GetAttribute("macro1") ~= nil
                        or targetButton:GetAttribute("macroName") ~= nil
                        or targetButton:GetAttribute("macroName1") ~= nil
                        or targetButton:GetAttribute("type") == "macro"
                        or targetButton:GetAttribute("type1") == "macro"
                    ) then
                        RegisterMacroIdentifiers(nil, targetButton, formatted)
                    end
                end
            end
        end
    end

    -- Do not fall back to EnumerateFrames(). It walks every frame created by
    -- every addon, is extremely expensive during rebuilds and can touch
    -- forbidden objects. Standard action slots, registered addon buttons,
    -- macros and explicit CLICK bindings have already been handled above.
end
