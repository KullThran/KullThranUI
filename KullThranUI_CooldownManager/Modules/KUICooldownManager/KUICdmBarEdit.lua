-- Adds custom Cooldown Manager bars to the profile, with their default settings, and removes them.

local _, ns = ...

local Edit = {}
ns.CdmBarEdit = Edit

-- Bars that cannot be removed and do not count against the limit.
local MAIN_BARS = { cooldowns = true, utility = true, buffs = true }

-- Default bar names by type. They are saved as plain text, with the number appended.
local NAME_PREFIXES = {
    cooldowns = "Custom Cooldowns Bar ",
    utility = "Custom Utility Bar ",
    buffs = "Custom Buffs Bar ",
    trinkets = "Miscellaneous ",
}
local NAME_PREFIX_OTHER = "Custom Cooldowns Bar "

-- A new saved bar. Field names and values are saved data.
local function NewBar(key, name, barType, numRows)
    return {
        key = key,
        name = name,
        barType = barType,
        numRows = numRows,
        customSpells = {},

        enabled = true,
        barScale = 1.0,
        iconSize = 36,
        spacing = 2,

        borderSize = 1,
        borderA = 1,
        borderR = 0,
        borderG = 0,
        borderB = 0,
        borderClassColor = false,
        borderThickness = "thin",

        bgA = 0.6,
        bgR = 0.08,
        bgG = 0.08,
        bgB = 0.08,

        iconZoom = 0.08,
        iconShape = "none",

        growDirection = "RIGHT",
        verticalOrientation = false,

        barBgEnabled = false,
        barBgAlpha = 1.0,
        barBgR = 0,
        barBgG = 0,
        barBgB = 0,

        showCooldownText = true,
        cooldownFontSize = 12,
        showCharges = true,
        chargeFontSize = 11,

        desaturateOnCD = false,
        hideGCDSwipe = false,
        swipeAlpha = 0.7,
        swipeR = 0,
        swipeG = 0,
        swipeB = 0,
        activeSwipeUsesGlowColor = true,
        activeStateAnim = "blizzard",

        anchorTo = "utility",
        anchorPosition = "bottom",
        anchorOffsetX = 0,
        anchorOffsetY = -2,

        barVisibility = "always",
        housingHideEnabled = true,
        hideBuffsWhenInactive = true,

        stackCountSize = 12,
        stackCountX = 0,
        stackCountY = 0,
        stackCountR = 1,
        stackCountG = 1,
        stackCountB = 1,
    }
end

-- Publishes the two public functions. Profile, list and context fields are read when they run.
function Edit.Install(ctx)
    ns.AddCDMBar = function(barType, name, numRows)
        local bars = ctx.GetProfile().cdmBars.bars

        -- Everything that is not a main bar counts against the limit.
        local used = 0
        for _, bar in ipairs(bars) do
            if not MAIN_BARS[bar.key] then used = used + 1 end
        end
        if used >= ns.MAX_CUSTOM_BARS then return nil end

        barType = barType or "cooldowns"

        if not name then
            local sameType = 0
            for _, bar in ipairs(bars) do
                if bar.barType == barType then sameType = sameType + 1 end
            end
            name = (NAME_PREFIXES[barType] or NAME_PREFIX_OTHER) .. (sameType + 1)
        end

        local position = #bars + 1
        local key = ("custom_" .. position .. "_" .. GetTime()):gsub("%.", "_")

        bars[position] = NewBar(key, name, barType, numRows or 1)

        ctx.BuildAll()
        ctx.UpdateIcons(key)
        ctx.LayoutBar(key)
        ctx.RegisterUnlock()
        return key
    end

    ns.RemoveCDMBar = function(key)
        if MAIN_BARS[key] then return false end

        local profile = ctx.GetProfile()
        local bars = profile.cdmBars.bars
        local index
        for i, bar in ipairs(bars) do
            if bar.key == key then
                index = i
                break
            end
        end
        if not index then return false end

        local frame = ctx.barFrames[key]
        if frame then frame:Hide() end
        ctx.barFrames[key] = nil
        ctx.barIcons[key] = nil
        profile.cdmBarPositions[key] = nil
        table.remove(bars, index)

        local addon = ctx.KT
        if addon and addon.UnregisterUnlockElement then
            addon:UnregisterUnlockElement("CDM_" .. key)
        end
        ctx.RegisterUnlock()
        return true
    end
end
