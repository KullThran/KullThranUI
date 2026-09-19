-- upvalue the globals
local _G = getfenv(0);
local LibStub = _G.LibStub;
local pairs = _G.pairs;
local string_match = _G.string.match;

local name = "KUIMove";
---@type KUIMove
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local KUIMove = KT:GetModule(name)
if not KUIMove then return; end

KT.KUIMoveAPI = KT.KUIMoveAPI or {};
_G.KT_KUIMoveAPI = KT.KUIMoveAPI;
---@class KUIMoveAPI
local KUIMoveAPI = KT.KUIMoveAPI;

--- @return string rawVersion
--- @return number mayor
--- @return number minor
--- @return number patch
--- @return number versionInt
function KUIMoveAPI:GetVersion()
    local rawVersion = KUIMove.Config.version;

    local mayor, minor, patch = string_match(rawVersion, "v(%d*)%.(%d*)%.(%d*)[a-z]?")
    local versionInt = patch and (patch + minor * 100 + mayor * 10000);

    return rawVersion, mayor, minor, patch, versionInt
end

function KUIMoveAPI:ToggleDebugPrints()
    KUIMove.DB.DebugPrints = not KUIMove.DB.DebugPrints;

    KUIMove:Print("Debug prints have been:", (KUIMove.DB.DebugPrints and "Enabled") or "Disabled");
end

--- @param framesTable KUIMoveAPI_FrameTable
function KUIMoveAPI:RegisterFrames(framesTable)
    for frameName, frameData in pairs(framesTable) do
        if not KUIMove:ValidateFrame(frameName, frameData) then
            KUIMove:DebugPrint("Invalid frame data provided for frame: '", frameName, "'.");

            return false;
        end

        KUIMove:RegisterFrame(nil, frameName, frameData, true);
    end

    if KUIMove.initialized then
        KUIMove.Config:RegisterOptions();
    end
end

--- @param addOnFramesTable KUIMoveAPI_AddonFrameTable
function KUIMoveAPI:RegisterAddOnFrames(addOnFramesTable)
    for addOnName, framesTable in pairs(addOnFramesTable) do
        for frameName, frameData in pairs(framesTable) do
            if not KUIMove:ValidateFrame(frameName, frameData) then
                KUIMove:DebugPrint("Invalid frame data provided for frame: '", frameName, "'.");

                return;
            end
            KUIMove:RegisterFrame(addOnName, frameName, frameData, true);
        end
    end

    if KUIMove.initialized then
        KUIMove.Config:RegisterOptions();
    end
end

function KUIMoveAPI:UnregisterFrame(addOnName, frameName, permanent)
    return KUIMove:UnregisterFrame(addOnName, frameName, permanent);
end

--- @return table<string, string> # Returns a table with the addon name as key and value
function KUIMoveAPI:GetRegisteredAddOns()
    return KUIMove:GetRegisteredAddOns();
end

--- @param addOnName ?string # The name of the addon, defaults to KUIMove (i.e. framexml frames)
--- @return table<string, string> # Returns a table with the frame name as key and value
function KUIMoveAPI:GetRegisteredFrames(addOnName)
    return KUIMove:GetRegisteredFrames(addOnName);
end

function KUIMoveAPI:IsFrameDefaultDisabled(addOnName, frameName)
    return KUIMove:IsFrameDefaultDisabled(addOnName, frameName);
end

function KUIMoveAPI:IsFrameDisabled(addOnName, frameName)
    return KUIMove:IsFrameDisabled(addOnName, frameName);
end

function KUIMoveAPI:SetFrameDisabled(addOnName, frameName, disable)
    if disable then
        return KUIMove:DisableFrame(addOnName, frameName);
    else
        return KUIMove:EnableFrame(addOnName, frameName);
    end
end
