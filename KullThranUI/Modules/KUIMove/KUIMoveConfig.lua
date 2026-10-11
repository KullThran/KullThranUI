-- up-value the globals
local _G = getfenv(0);
local LibStub = _G.LibStub;
local pairs = _G.pairs;
local GetAddOnMetadata = _G.GetAddOnMetadata or _G.C_AddOns.GetAddOnMetadata;
local ReloadUI = _G.ReloadUI;
local string__match = _G.string.match;
local StaticPopupDialogs = _G.StaticPopupDialogs;
local StaticPopup_Show = _G.StaticPopup_Show;
local IsControlKeyDown = _G.IsControlKeyDown;

local name = "KUIMove";
local OPTIONS_TABLE_NAME = "KullThranUI_KUIMove";
local POPUP_NAME = "KUIMoveURLDialog";
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
---@class KUIMove
local KUIMove = KT:GetModule(name)
if not KUIMove then return; end

local L = LibStub("AceLocale-3.0"):GetLocale(name, true) or LibStub("AceLocale-3.0"):GetLocale("KullThranUI", true);
if not L then L = setmetatable({}, { __index = function(t, k) local locale = KT and KT.GetLocale and KT:GetLocale(); return (locale and locale[k]) or k end }) end

---@type KUIMoveAPI
local KUIMoveAPI = KT.KUIMoveAPI;

---@class KUIMoveConfig
local Config = {};
KUIMove.Config = Config;

Config.version = KT.VERSION or "unknown";

function Config:GetOptions()
    local leftClick = CreateAtlasMarkup('NPE_LeftClick', 18, 18);
    local rightClick = CreateAtlasMarkup('NPE_RightClick', 18, 18);
    local increment = CreateCounter();

    return {
        type = "group",
        name = "KUIMove",
        childGroups = "tab",
        args = {
            brand = {
                order = increment(),
                type = "description",
                name = string.format("|cff71d5ffKUIMove|r\n|cffc8c8c8%s|r\n\n%s", L["Window control, built the KUI way."], L["Choose a workspace below to move, scale and curate Blizzard windows."]),
            },
            version = {
                order = increment(),
                type = "description",
                name = "|cff777777" .. L["Build %s"]:format(tostring(self.version)) .. "|r"
            },
            mainTab = {
                order = increment(),
                name = L["Control Center"],
                type = "group",
                get = function(info) return Config:GetConfig(info[#info]); end,
                set = function(info, value) return Config:SetConfig(info[#info], value); end,
                args = {
                    description = {
                        order = increment(),
                        type = "description",
                        name =
                            L["KUIMove manages your window layout."] .. "\n"
                            .. "\n"
                            .. L["Drag a window with %s to place it for this session."]:format(leftClick) .. "\n"
                            .. "\n"
                            .. L["CTRL + scroll adjusts the window scale."] .. "\n"
                            .. "\n"
                            .. L["ALT + %s detaches a child window."]:format(leftClick) .. "\n"
                            .. L["Detached windows can be moved independently from their parent."] .. "\n"
                            .. "\n"
                            .. L["Reset actions:"] .. "\n"
                            .. "  " .. L["SHIFT + %s resets the position."]:format(rightClick) .. "\n"
                            .. "  " .. L["CTRL + %s resets the scale."]:format(rightClick) .. "\n"
                            .. "  " .. L["ALT + %s re-attaches a child window."]:format(rightClick) .. "\n"
                            .. "\n"
                            .. L["Custom frames can register through the KUIMoveAPI."],
                    },
                    newline1 = {
                        order = increment(),
                        type = "description",
                        name = " ",
                    },
                    globalConfig = {
                        type = "group",
                        name = L["Movement & Memory"],
                        order = increment(),
                        inline = true,
                        args = {
                            requireMoveModifier = {
                                order = increment(),
                                name = L["Hold SHIFT to move"],
                                desc = L["Adds a deliberate modifier to dragging so windows are not moved by accident."],
                                type = "toggle",
                                width = "full",
                            },
                            newline2 = {
                                order = increment(),
                                type = "description",
                                name = "",
                            },
                            savePosStrategy = {
                                order = increment(),
                                width = 1.5,
                                name = L["Position memory"],
    desc =
        L["Off  •  Positions return when the window is reopened."] .. "\n\n"
        .. L["This session  •  Positions last until /reload."] .. "\n\n"
        .. L["Persistent  •  Positions stay until you clear them."],
                                type = "select",
                                values = {
        off = L["Off"],
        session = L["This session"],
        permanent = L["Persistent"],
                                },
                            },
                            saveScaleStrategy = {
                                order = increment(),
                                width = 1.5,
                                name = L["Scale memory"],
    desc =
        L["This session  •  Scale lasts until /reload."] .. "\n\n"
        .. L["Persistent  •  Scale stays until you clear it."],
                                type = "select",
                                values = {
        session = L["This session"],
        permanent = L["Persistent"],
                                },
                            },
                            newline3 = {
                                order = increment(),
                                type = "description",
                                name = "",
                            },
                            resetPositions = {
                                order = increment(),
                                width = 1.5,
                                name = L["Clear saved positions"],
                                desc = L["Remove all persistent window positions and reload the UI."],
                                type = "execute",
                                func = function() KUIMove:ResetPointStorage(); ReloadUI(); end,
                                confirm = function() return L["Clear every persistent KUIMove position and reload the UI?"] end,
                            },
                            resetScales = {
                                order = increment(),
                                width = 1.5,
                                name = L["Clear saved scales"],
                                desc = L["Remove all persistent window scales and reload the UI."],
                                type = "execute",
                                func = function() KUIMove:ResetScaleStorage(); ReloadUI(); end,
                                confirm = function() return L["Clear every persistent KUIMove scale and reload the UI?"] end,
                            },
                        },
                    },
                    newline4 = {
                        order = increment(),
                        type = "description",
                        name = "\n",
                    },
                },
            },
            fullFramesTab = {
                order = increment(),
                name = L["Frame Library"],
                type = "group",
                childGroups = "tree",
                get = function(info, frameName) return not KUIMoveAPI:IsFrameDisabled(info[#info], frameName); end,
                set = function(info, frameName, enabled) return KUIMoveAPI:SetFrameDisabled(info[#info], frameName, not enabled); end,
                args = self.ListOfFramesTable,
            },
            disabledFramesTab = {
                order = increment(),
                name = L["Safe Defaults"],
                type = "group",
                childGroups = "tree",
                get = function(info, frameName) return not KUIMoveAPI:IsFrameDisabled(info[#info], frameName); end,
                set = function(info, frameName, enabled) return KUIMoveAPI:SetFrameDisabled(info[#info], frameName, not enabled); end,
                args = self.DefaultDisabledFramesTable,
            },
        },
    }
end

function Config:GetFramesTables()
    local listOfFrames = {};
    local defaultDisabledFrames = {};
    local addonOrder = function(info)
        if info[#info] == "KullThranUI" then return 10; end
        if string__match(info[#info], "Blizzard_") then return 30; end
        return 20;
    end;

    local allFrames = {
        ["0"] = {
            name = L["Search windows"],
            type = "input",
            desc = L["Search by window name. Prefix with '-' for disabled or '+' for enabled windows."],
            order = 1,
            get = function() return self.search; end,
            set = function(_, value) self.search = value; end
        },
        ["1"] = {
            name = L["Clear search"],
            type = "execute",
            desc = L["Clear the current window filter."],
            order = 2,
            func = function() self.search = ""; end,
            width = 0.5,
        },
    }
    listOfFrames["0"] = {
        name = L["Window Library"],
        type = "group",
        order = 1,
        args = allFrames,
    };

    for addOnName, _ in pairs(KUIMoveAPI:GetRegisteredAddOns()) do
        listOfFrames[addOnName] = {
            name = addOnName,
            type = "group",
            order = addonOrder,
            args = {
                [addOnName] = {
                    name = L["Frames from %s"]:format(addOnName),
                    type = "multiselect",
                    values = function(info) return KUIMoveAPI:GetRegisteredFrames(info[#info]); end,
                },
            },
        };
        allFrames[addOnName] = {
            name = L["Frames from %s"]:format(addOnName),
            type = "multiselect",
            order = addonOrder,
            values = function(info) return self:GetFilteredFrames(info[#info], self.search); end,
            hidden = function(info) return not next(info.option.values(info)); end,
        }
        for frameName, _ in pairs(KUIMoveAPI:GetRegisteredFrames(addOnName)) do
            if(KUIMoveAPI:IsFrameDefaultDisabled(addOnName, frameName)) then
                defaultDisabledFrames[addOnName] = {
                    name = addOnName,
                    type = "group",
                    order = addonOrder,
                    args = {
                        [addOnName] = {
                            name = L["Frames from %s"]:format(addOnName),
                            type = "multiselect",
                            values = function(info) return self:GetDefaultDisabledFrames(info[#info]); end,
                        },
                    },
                };
                break;
            end
        end
    end

    return listOfFrames, defaultDisabledFrames;
end

function Config:GetFilteredFrames(addOnName, filter)
    local frames = {};
    for frameName, _ in pairs(KUIMoveAPI:GetRegisteredFrames(addOnName)) do
        if
            not filter or filter == ''
            or (filter == '-' and KUIMoveAPI:IsFrameDisabled(addOnName, frameName))
            or (filter == '+' and not KUIMoveAPI:IsFrameDisabled(addOnName, frameName))
            or (string__match(string.lower(frameName), string.lower(filter)))
            or (string__match(string.lower(addOnName), string.lower(filter)))
        then
            frames[frameName] = frameName;
        end
    end
    return frames;
end

function Config:GetDefaultDisabledFrames(addOnName)
    local returnTable = {};

    for frameName, _ in pairs(KUIMoveAPI:GetRegisteredFrames(addOnName)) do
        if(KUIMoveAPI:IsFrameDefaultDisabled(addOnName, frameName)) then
            returnTable[frameName] = frameName;
        end
    end

    return returnTable;
end

function Config:Initialize()
    self.search = "";
    self:RegisterOptions();
    local ACD = LibStub("AceConfigDialog-3.0");
    local success, _, categoryID = pcall(ACD.AddToBlizOptions, ACD, OPTIONS_TABLE_NAME, "KullThranUI KUIMove");
    if success then
        self.categoryID = categoryID;
    else
        self.categoryID = ACD.BlizOptionsIDMap and ACD.BlizOptionsIDMap[OPTIONS_TABLE_NAME];
    end

    StaticPopupDialogs[POPUP_NAME] = {
        text = L["CTRL-C to copy"],
        button1 = CLOSE,
        --- @param dialog StaticPopupTemplate
        --- @param data string
        OnShow = function(dialog, data)
            local function HidePopup()
                dialog:Hide();
            end
            --- @type StaticPopupTemplate_EditBox
            local editBox = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox;
            editBox:SetScript('OnEscapePressed', HidePopup);
            editBox:SetScript('OnEnterPressed', HidePopup);
            editBox:SetScript('OnKeyUp', function(_, key)
                if IsControlKeyDown() and (key == 'C' or key == 'X') then
                    HidePopup();
                end
            end);
            editBox:SetMaxLetters(0);
            editBox:SetText(data);
            editBox:HighlightText();
        end,
        hasEditBox = true,
        editBoxWidth = 240,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    };
end

function Config:OpenConfig()
    if C_SettingsUtil and C_SettingsUtil.OpenSettingsPanel and InCombatLockdown() then
        LibStub("AceConfigDialog-3.0"):Open(OPTIONS_TABLE_NAME);
        return;
    end
    Settings.OpenToCategory(self.categoryID);
end

function Config:RegisterOptions()
    self.ListOfFramesTable, self.DefaultDisabledFramesTable = self:GetFramesTables();
    LibStub("AceConfig-3.0"):RegisterOptionsTable(OPTIONS_TABLE_NAME, self:GetOptions());
end

function Config:GetConfig(property)
    return KUIMove.DB[property];
end

function Config:SetConfig(property, value)
    local oldValue = KUIMove.DB[property] or nil;
    KUIMove.DB[property] = value;
    if property == "savePosStrategy" then
        KUIMove:SavePositionStrategyChanged(oldValue, value);
    end
end

function Config:ShowURLPopup(url)
    StaticPopup_Show(POPUP_NAME, _, _, url);
end
