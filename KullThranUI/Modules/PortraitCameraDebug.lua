local KT = _G.KullThranUI
local Debug = { enabled = false, log = {}, build = "unitframes-debug-20261004-v22" }
KT.Portrait3DDebug = Debug

function Debug.Value(value)
    if issecretvalue and issecretvalue(value) then return "<restricted>" end
    return tostring(value)
end

function Debug.Call(object, method, ...)
    local fn = object and object[method]
    if type(fn) ~= "function" then return "n/a" end
    local result = { pcall(fn, object, ...) }
    if not result[1] then return "ERROR:" .. Debug.Value(result[2]) end
    local values = {}
    for i = 2, #result do values[#values + 1] = Debug.Value(result[i]) end
    return #values > 0 and table.concat(values, ",") or "nil"
end

function Debug.API(fn, ...)
    if type(fn) ~= "function" then return "n/a" end
    local ok, value = pcall(fn, ...)
    return ok and Debug.Value(value) or ("ERROR:" .. Debug.Value(value))
end

function Debug.Model(model)
    if not model then return "model=missing" end
    return "model=" .. Debug.Call(model, "GetObjectType")
        .. " shown=" .. Debug.Call(model, "IsShown")
        .. " visible=" .. Debug.Call(model, "IsVisible")
        .. " file=" .. Debug.Call(model, "GetModelFileID")
        .. " facing=" .. Debug.Call(model, "GetFacing")
        .. " rotation=" .. Debug.Call(model, "GetRotation")
        .. " view=" .. Debug.Call(model, "GetViewTranslation")
        .. " camera=" .. Debug.Call(model, "GetCamera")
        .. " cameraPosition=" .. Debug.Call(model, "GetCameraPosition")
        .. " cameraTarget=" .. Debug.Call(model, "GetCameraTarget")
        .. " animalCamera=" .. Debug.Value(model._ktPortraitAnimalCamera)
        .. " animalYawDegrees=" .. Debug.Value(model._ktPortraitAnimalYaw and math.deg(model._ktPortraitAnimalYaw))
        .. " headAxisDegrees=" .. Debug.Value(model._ktPortraitHeadAxis and math.deg(model._ktPortraitHeadAxis))
        .. " druidProbeDegrees=" .. Debug.Value(model._ktDruidDebugAngle)
        .. " modelScale=" .. Debug.Call(model, "GetModelScale")
        .. " distance=" .. Debug.Call(model, "GetCamDistanceScale")
        .. " position=" .. Debug.Call(model, "GetPosition")
        .. " size=" .. Debug.Call(model, "GetSize")
        .. " level=" .. Debug.Call(model, "GetFrameLevel")
        .. " strata=" .. Debug.Call(model, "GetFrameStrata")
end

function Debug.Record(model, reason, unit, detail)
    if not Debug.enabled then return end
    local line = Debug.API(GetTime) .. " " .. reason .. " unit=" .. Debug.Value(unit)
        .. " " .. Debug.Model(model) .. " " .. (detail or "")
    Debug.log[#Debug.log + 1] = line
    if #Debug.log > 80 then table.remove(Debug.log, 1) end
end

function KT.DebugDruidPortraitDirection(angle)
    local frame = _G.KullThranUI_UF_Player
    local model = frame and frame.Portrait and frame.Portrait.backdrop and frame.Portrait.backdrop._3d
    if not model or model._ktPortraitAnimalUnit ~= "player" then
        print("[KTUF] Select Player Portrait 3D and enter cat/bear/aquatic form first.")
        return
    end
    local applied = model._ktPortraitCameraApplied
    if not applied then return end
    if angle == "reset" then
        model._ktDruidDebugAngle, model._ktDruidDebugStep = nil, nil
    elseif tonumber(angle) then
        model._ktDruidDebugAngle = tonumber(angle) % 360
    else
        model._ktDruidDebugStep = ((model._ktDruidDebugStep or -1) + 1) % 4
        model._ktDruidDebugAngle = model._ktDruidDebugStep * 90
    end
    model._ktPortraitDebugLook = nil
    model._ktDruidProbeGeneration = (model._ktDruidProbeGeneration or 0) + 1
    local generation = model._ktDruidProbeGeneration
    print("[KTUF] DRUID Player requested degrees=" .. Debug.Value(model._ktDruidDebugAngle)
        .. " (temporary; /ktufdebug druid reset restores defaults)")
    print("[KTUF] DRUID before " .. Debug.Model(model))
    KT.ApplyPortrait3DCamera(model, applied.yaw, applied.zoom, applied.x, applied.y, applied.viewShift)
    print("[KTUF] DRUID immediate " .. Debug.Model(model))
    if C_Timer and C_Timer.After then
        for _, delay in ipairs({0.2, 1}) do
            local seconds = delay
            C_Timer.After(seconds, function()
                if model._ktDruidProbeGeneration == generation then
                    print("[KTUF] DRUID after " .. seconds .. "s " .. Debug.Model(model))
                end
            end)
        end
    end
end

function Debug.Dump()
    print("[KTPORTRAIT] " .. Debug.build .. " client=" .. Debug.API(GetBuildInfo))
    print("[KTPORTRAIT] form=" .. Debug.API(GetShapeshiftForm)
        .. " formID=" .. Debug.API(GetShapeshiftFormID))
    for _, unit in ipairs({"player", "target"}) do
        print("[KTPORTRAIT] " .. unit
            .. " exists=" .. Debug.API(UnitExists, unit)
            .. " connected=" .. Debug.API(UnitIsConnected, unit)
            .. " visible=" .. Debug.API(UnitIsVisible, unit)
            .. " isPlayerAlias=" .. Debug.API(UnitIsUnit, unit, "player"))
        if KT.DebugPortrait3DState then
            local ok, lines = pcall(KT.DebugPortrait3DState, unit)
            if ok then
                for _, line in ipairs(lines) do print("[KTPORTRAIT] " .. line) end
            else print("[KTPORTRAIT] snapshot ERROR:" .. Debug.Value(lines)) end
        else print("[KTPORTRAIT] UnitFrames debug provider missing") end
        if KT.DebugUnitFrameGlowState then
            local ok, lines = pcall(KT.DebugUnitFrameGlowState, unit)
            if ok then for _, line in ipairs(lines) do print("[KTUF] " .. unit .. " " .. line) end
            else print("[KTUF] glow snapshot ERROR:" .. Debug.Value(lines)) end
        end
    end
    print("[KTPORTRAIT] trace enabled=" .. tostring(Debug.enabled) .. " entries=" .. #Debug.log)
    for _, line in ipairs(Debug.log) do print("[KTPORTRAIT] " .. line) end
end

_G.SLASH_KTPORTRAITDEBUG1 = "/ktportraitdebug"
_G.SLASH_KTPORTRAITDEBUG2 = "/ktufdebug"
SlashCmdList.KTPORTRAITDEBUG = function(message)
    local command = (message or ""):lower():match("^%s*(%S+)") or "dump"
    if command == "glow" then
        if KT.DebugProbeRestedGlow then KT.DebugProbeRestedGlow() end
        print("[KTUF] Golden glow probe: 20 seconds, out of combat only.")
        Debug.Dump()
    elseif command == "druid" then
        local angle = message:lower():match("^%s*%S+%s+(%S+)")
        if angle and angle ~= "reset" and not tonumber(angle) then
            print("[KTUF] /ktufdebug druid [degrees|reset]; no argument cycles 0/90/180/270.")
        else KT.DebugDruidPortraitDirection(angle) end
    elseif command == "camera" then
        local unit, angle, shift = message:match("^%s*%S+%s+(%S+)%s*([%-%.%d]*)%s*([%-%.%d]*)")
        if unit == "reset" then
            if KT.DebugSetPortraitCamera then
                KT.DebugSetPortraitCamera("player"); KT.DebugSetPortraitCamera("target")
            end
        elseif (unit == "player" or unit == "target") and tonumber(angle) and KT.DebugSetPortraitCamera then
            KT.DebugSetPortraitCamera(unit, tonumber(angle), tonumber(shift) or 0)
        else print("[KTUF] /ktufdebug camera player <degrees> <shift>, or camera reset") end
        Debug.Dump()
    elseif command == "on" then
        Debug.enabled = true
        Debug.log = {}
        print("[KTPORTRAIT] Recording enabled. Change forms/target, then /ktportraitdebug dump.")
    elseif command == "off" then
        Debug.enabled = false
        print("[KTPORTRAIT] Recording disabled.")
    elseif command == "clear" then
        Debug.log = {}
        print("[KTPORTRAIT] Trace cleared.")
    else
        Debug.Dump()
    end
end
