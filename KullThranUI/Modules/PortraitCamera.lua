local KT = _G.KullThranUI
KT.PortraitMirrorModels = {
    [118355] = true, [118135] = true, [1838560] = true, [1838562] = true, [878772] = true, [950080] = true, [116921] = true, [1100258] = true, [1839709] = true, [117170] = true, [1100087] = true, [1853408] = true, [1890763] = true, [1892825] = true, [1890765] = true, [1892543] = true, [117437] = true, [1022598] = true, [1822372] = true, [117721] = true, [1005887] = true, [1839253] = true, [119063] = true, [940356] = true, [1838564] = true, [119159] = true, [900914] = true, [1838566] = true, [119369] = true, [1838568] = true, [119376] = true, [1838570] = true, [1630402] = true, [1859379] = true, [1630218] = true, [1858265] = true, [119563] = true, [1000764] = true, [1838572] = true, [1842700] = true, [119940] = true, [1011653] = true, [1838385] = true, [1886724] = true, [1721003] = true, [1593999] = true, [1825438] = true, [1620605] = true, [1839042] = true, [2564806] = true, [2622502] = true, [1810676] = true, [1858099] = true, [1814471] = true, [1857801] = true, [120590] = true, [921844] = true, [1838574] = true, [120791] = true, [974343] = true, [1838576] = true, [121087] = true, [949470] = true, [1838580] = true, [121287] = true, [917116] = true, [1838578] = true, [1968587] = true, [1968838] = true, [1087591] = true, [1088030] = true, [589715] = true, [1853610] = true, [535052] = true, [1853956] = true, [121608] = true, [997378] = true, [1838582] = true, [121768] = true, [959310] = true, [1838584] = true, [121961] = true, [986648] = true, [1839008] = true, [122055] = true, [968705] = true, [1838586] = true, [122414] = true, [1018060] = true, [1838588] = true, [122560] = true, [1022938] = true, [1838590] = true, [1733758] = true, [1859345] = true, [1734034] = true, [1858367] = true, [1890759] = true, [1890761] = true, [307453] = true, [1838201] = true, [307454] = true, [1838592] = true, [1662187] = true, [1894572] = true, [1630447] = true, [1900779] = true, [4395382] = true, [4207724] = true, [4220448] = true, [7478494] = true, [7478487] = true
}

function KT.Portrait3DYaw(unit, side, facingMode, invert, rotation, model)
    local lookRight
    if facingMode == "normal" then
        lookRight = true
    elseif facingMode == "flipped" then
        lookRight = false
    elseif unit == "player" then
        lookRight = true
    elseif unit == "target" then
        lookRight = false
    else
        side = side or ((unit == "pet") and "left" or "right")
        lookRight = side ~= "right"
        if invert then lookRight = not lookRight end
    end
    local yaw = lookRight and 0 or math.rad(291)
    local viewShift = lookRight and 0 or 15
    local animal
    local okClass, _, class = pcall(KT.SafeUnitClass or UnitClass, unit)
    if okClass and not (issecretvalue and issecretvalue(class)) and class == "DRUID" then
        local ownUnit = unit == "player"
        if not ownUnit and UnitIsUnit then
            local ok, same = pcall(UnitIsUnit, unit, "player")
            ownUnit = ok and not (issecretvalue and issecretvalue(same)) and same
        end
        if ownUnit and GetShapeshiftFormID then
            local ok, form = pcall(GetShapeshiftFormID)
            if ok and not (issecretvalue and issecretvalue(form)) then
                if form == (DRUID_CAT_FORM or 1) then animal = "cat"
                elseif form == (DRUID_BEAR_FORM or 5) or form == (DRUID_DIREBEAR_FORM or 8) then animal = "bear"
                elseif form == (DRUID_AQUATIC_FORM or 4) then animal = "aquatic" end
            end
        elseif UnitPowerType then
            local ok, _, token = pcall(UnitPowerType, unit)
            if ok and not (issecretvalue and issecretvalue(token)) then
                if token == "ENERGY" then animal = "cat"
                elseif token == "RAGE" then animal = "bear" end
            end
        end
    end
    if model then
        model._ktPortraitAnimalMirror = animal and lookRight or false
        model._ktPortraitAnimalUnit = animal and unit or nil
    end
    if animal then
        yaw, viewShift = 0, 0
    elseif model and model.GetModelFileID then
        local ok, id = pcall(model.GetModelFileID, model)
        if not ok or (issecretvalue and issecretvalue(id)) or not KT.PortraitMirrorModels[id] then
            yaw, viewShift = 0, 0
        end
    end
    return yaw + math.rad(tonumber(rotation) or 0), (unit == "player" or unit == "target") and 1.288 or 1, 0, viewShift
end

function KT.ReadNativePortraitCamera(reference, zoom, source)
    if not (reference and reference.GetCameraPosition and reference.GetCameraTarget) then return end
    local ok, cx, cy, cz = pcall(reference.GetCameraPosition, reference)
    local ready, tx, ty, tz = pcall(reference.GetCameraTarget, reference)
    if not (ok and ready and cx and cy and cz and tx and ty and tz) then return end
    for _, value in ipairs({cx, cy, cz, tx, ty, tz}) do
        if (issecretvalue and issecretvalue(value)) or type(value) ~= "number" then return end
    end
    if cx == tx and cy == ty and cz == tz then return end
    if tx == 0 and ty == 0 and tz == 0 then return end
    return {cx=cx,cy=cy,cz=cz,tx=tx,ty=ty,tz=tz,zoom=zoom or 1,source=source}
end

function KT.GetNativeDruidPortraitCamera(model)
    local unit = model._ktPortraitAnimalUnit or model._camUnit or model._previewUnit or "player"
    local targetFrame = _G.KullThranUI_UF_Target
    local targetModel = targetFrame and targetFrame.Portrait and targetFrame.Portrait.backdrop
        and targetFrame.Portrait.backdrop._3d
    if targetModel and targetModel ~= model and UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, unit, "target")
        local applied = targetModel._ktPortraitCameraApplied
        if ok and not (issecretvalue and issecretvalue(same)) and same and applied and applied.yaw == 0
            and not targetModel._ktPortraitAnimalMirror then
            local a, id = pcall(model.GetModelFileID, model)
            local b, targetID = pcall(targetModel.GetModelFileID, targetModel)
            if a and b and not (issecretvalue and (issecretvalue(id) or issecretvalue(targetID)))
                and id and id == targetID then
                local camera = KT.ReadNativePortraitCamera(targetModel, applied.zoom, "target")
                if camera then return camera end
            end
        end
    end
    local reference = model._ktNativePortraitReference
    if not reference then
        reference = CreateFrame("PlayerModel", nil, UIParent)
        reference:SetSize(64, 64)
        if reference.SetKeepModelOnHide then reference:SetKeepModelOnHide(true) end
        reference:Hide()
        model._ktNativePortraitReference = reference
        reference:SetScript("OnModelLoaded", function(self)
            self:SetPortraitZoom(1); self:SetCamDistanceScale(1)
            self:SetPosition(0, 0, 0)
            if self.SetViewTranslation then self:SetViewTranslation(0, 0) end
            if self.SetRotation then self:SetRotation(0, false) end
            local applied = model._ktPortraitCameraApplied
            if applied and model._ktPortraitAnimalMirror and not self._ktLoadingReference then
                KT.ApplyPortrait3DCamera(model, applied.yaw, applied.zoom, applied.x, applied.y, applied.viewShift)
            end
        end)
    end
    local ok, id = pcall(model.GetModelFileID, model)
    if not ok or (issecretvalue and issecretvalue(id)) or not id then return end
    if reference._ktReferenceUnit ~= unit or reference._ktReferenceFile ~= id then
        reference._ktReferenceUnit, reference._ktReferenceFile = unit, id
        reference._ktLoadingReference = true
        reference:ClearModel(); reference:SetUnit(unit)
        reference:SetPortraitZoom(1); reference:SetCamDistanceScale(1)
        reference:SetPosition(0, 0, 0)
        if reference.SetViewTranslation then reference:SetViewTranslation(0, 0) end
        if reference.SetRotation then reference:SetRotation(0, false) end
        reference._ktLoadingReference = nil
    end
    local loaded, referenceID = pcall(reference.GetModelFileID, reference)
    if not loaded or (issecretvalue and issecretvalue(referenceID)) or referenceID ~= id then return end
    return KT.ReadNativePortraitCamera(reference, 1, "native-target-reference")
end

function KT.ApplyAnimalPortraitCamera(model, zoom, x, y)
    model._ktPortraitAnimalCamera = "native"
    if not (model.SetCamera and model.SetRotation and model.SetPosition
        and model.MakeCurrentCameraCustom and model.SetCameraPosition and model.SetCameraTarget) then return end
    local ok, failure = pcall(function()
        local native = KT.GetNativeDruidPortraitCamera(model)
        if not native then error("native portrait reference loading") end
        local dx, dy = native.cx - native.tx, native.cy - native.ty
        if dx == 0 and dy == 0 then error("native portrait has no horizontal direction") end
        if native.tx == 0 and native.ty == 0 then error("native head axis unavailable") end
        local headAxis = math.atan2(native.ty, native.tx)
        -- Models face +X, so their symmetry plane is Y = 0. Mirroring the
        -- native camera and its focus across that plane gives the exact
        -- mirror image of the target view.
        local scale = native.zoom / (zoom or 1)
        local tx, ty, tz = native.tx, -native.ty, native.tz
        local px, py, pz = tx + dx * scale, ty - dy * scale, tz + (native.cz - native.tz) * scale
        local mirrored = math.atan2(-dy, dx)
        if model._ktPortraitAnimalUnit == "player" and model._ktDruidDebugAngle then
            mirrored = math.rad(model._ktDruidDebugAngle)
            local len = math.sqrt(dx * dx + dy * dy)
            tx, ty = native.tx, native.ty
            px, py = tx + math.cos(mirrored) * len * scale, ty + math.sin(mirrored) * len * scale
        end
        model:SetCamera(0)
        if model.SetPortraitZoom then model:SetPortraitZoom(1) end
        if model.SetCamDistanceScale then model:SetCamDistanceScale(1 / (zoom or 1)) end
        model:SetPosition(0, x or 0, y or 0)
        model:SetRotation(0, false)
        model:MakeCurrentCameraCustom()
        model:SetCameraTarget(tx, ty, tz)
        model:SetCameraPosition(px, py, pz)
        model._ktPortraitHeadAxis = headAxis
        model._ktPortraitAnimalYaw = mirrored
        model._ktPortraitAnimalCamera = "plane-mirror-from-" .. native.source
    end)
    if not ok then
        pcall(model.SetCamera, model, 0)
        local debug = KT.Portrait3DDebug
        model._ktPortraitAnimalCamera = "native fallback: " .. (debug and debug.Value(failure) or "camera unavailable")
    end
end

function KT.ApplyPortrait3DCamera(model, yaw, zoom, x, y, viewShift)
    local probe = model._ktPortraitDebugLook
    if probe then yaw, viewShift = probe.yaw, probe.viewShift end
    if model._ktPortraitAnimalCamera and not model._ktPortraitAnimalMirror and model.SetCamera then
        model:SetCamera(0)
    end
    if model.SetPortraitZoom then model:SetPortraitZoom(1) end
    if model.SetCamDistanceScale then model:SetCamDistanceScale(1 / zoom) end
    if model.SetPosition then model:SetPosition(0, x, y) end
    if model.SetViewTranslation then model:SetViewTranslation(viewShift or (yaw ~= 0 and 15 or 0), 0) end
    if model.SetRotation then model:SetRotation(yaw, false)
    elseif model.SetFacing then model:SetFacing(yaw) end
    if model._ktPortraitAnimalMirror and not probe then
        KT.ApplyAnimalPortraitCamera(model, zoom, x, y)
        if model.SetViewTranslation then model:SetViewTranslation(viewShift or 0, 0) end
    else model._ktPortraitAnimalCamera = nil end
    model._ktPortraitCameraApplied = { yaw = yaw, zoom = zoom, x = x, y = y, viewShift = viewShift }
    if KT.Portrait3DDebug then
        KT.Portrait3DDebug.Record(model, "camera-applied", model._camUnit or model._previewUnit,
            "requested yaw=" .. KT.Portrait3DDebug.Value(yaw)
            .. " zoom=" .. KT.Portrait3DDebug.Value(zoom)
            .. " x=" .. KT.Portrait3DDebug.Value(x) .. " y=" .. KT.Portrait3DDebug.Value(y))
    end
end
