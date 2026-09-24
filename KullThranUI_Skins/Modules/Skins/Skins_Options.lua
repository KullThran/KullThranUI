-- Modules/Skins/Skins_Options.lua
-- Registers the "Skins" page in KullThranUI's custom Options menu.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local S = KT:GetModule("Skins", true)

KT:RegisterPage("skins", "Skins", 20, function(sc, W)
    local y, h = 0, 0
    local db = KT.db.profile.skin

    _, h = W:SectionHeader(sc, "Window Style", -y); y = y + h
    _, h = W:Toggle(sc, "Enable Skins",       -y, function() return db.enable end,          function(v) db.enable = v; Reload() end); y = y + h

    _, h = W:SectionHeader(sc, "Colors", -y); y = y + h
    _, h = W:ColorSwatch(sc, "Window Background", -y,
        function()
            local c = db.blizzard.windowBackgroundColor or { r=0.05, g=0.05, b=0.05, a=0.98 }
            return c.r,c.g,c.b,c.a
        end,
        function(r,g,b,a)
            db.blizzard.windowBackgroundColor = { r=r, g=g, b=b, a=a or 0.98 }
            if S and S.RefreshBlizzardWindowBackgrounds then
                S:RefreshBlizzardWindowBackgrounds()
            end
        end, true); y = y + h
    _, h = W:SectionHeader(sc, "Blizzard Modules", -y); y = y + h
    _, h = W:Toggle(sc, "Style Blizzard Frames", -y, function() return db.blizzard.enable end, function(v) db.blizzard.enable = v; Reload() end); y = y + h
    _, h = W:Toggle(sc, "Show Blizzard window borders", -y,
        function() return db.blizzard.showWindowBorders ~= false end,
        function(v)
            db.blizzard.showWindowBorders = v and true or false
            if S and S.RefreshBlizzardWindowBorders then S:RefreshBlizzardWindowBorders() end
        end); y = y + h
    _, h = W:Toggle(sc, "Classic yellow for Blizzard frames", -y,
        function() return db.blizzard.classicYellowAccent == true end,
        function(v)
            db.blizzard.classicYellowAccent = v and true or false
            if S and S.RefreshBlizzardTheme then S:RefreshBlizzardTheme() end
        end); y = y + h

    local blizzToggles = {
        { key='trade', label='Trade Frame' },
        { key="auctionhouse",    label="Auction House"      },
        { key="addonManager",    label="Addon Manager"      },
        { key="friends",         label="Friends Frame"      },
        { key="armory",          label="Armory Frame"       },
        { key="bank",            label="Bank / Warband Bank" },
        { key="inspect",         label="Inspect Frame"      },
        { key="gamemenu",        label="Game Menu (Esc)"    },
        { key="settings",        label="Blizzard Options"   },
        { key="housing",         label="Housing"           },
        { key="spellbook",       label="Spellbook & Talents" },
        { key="alerts",          label="Alerts (Toasts)"    },
        { key="lfg",             label="LFG / Dungeon Finder" },
        { key="guild",           label="Guild & Guild Bank" },
        { key="collections",     label="Collections"        },
        { key="encounterjournal",label="Encounter Journal"  },
        { key="quest",           label="Quest Frames"       },
        { key="gossip",          label="Gossip (NPCs)"      },
        { key="merchant",        label="Merchant Frame"     },
        { key="mail",            label="Mail Frame"         },
        { key="worldmap",        label="World Map"          },
        { key="achievement",     label="Achievements"       },
        { key="professions",     label="Professions"        },
        { key="battlenet",       label="Battle.net"         },
        { key="popups",         label="Popups / Dialogs"   },
        { key="timers",        label="Timers / Countdown Bars" },
        { key="cooldownmanager", label="Cooldown Manager"        },
    }

    blizzToggles[#blizzToggles + 1] = { key='weeklyrewards', label=LText('Great Vault') }

    local MAX_VISIBLE = 13
    local ITEM_H = 38
    local scrollH = MAX_VISIBLE * ITEM_H

    local sf = CreateFrame("ScrollFrame", "KT_Skins_BlizzScroll", sc)
    sf:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, -y)
    sf:SetPoint("RIGHT", sc, "RIGHT", -30, 0)
    sf:SetHeight(scrollH)
    sf:EnableMouseWheel(true)

    local sb = CreateFrame("Slider", nil, sf)
    sb:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
    sb:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 0, 0)
    sb:SetWidth(8)
    sb:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    sb:SetOrientation("VERTICAL")
    sb:SetMinMaxValues(0, 1)
    local th = sb:GetThumbTexture()
    local palette = (KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE
    local themeAccent = palette and palette.accent
    local accent = {
        (themeAccent and themeAccent.r) or KT.C_R or 1,
        (themeAccent and themeAccent.g) or KT.C_G or 0,
        (themeAccent and themeAccent.b) or KT.C_B or 0.333,
        1,
    }
    th:SetVertexColor(accent[1], accent[2], accent[3], 1); th:SetHeight(20)
    if S and S.RegisterBlizzardAccentRefresh then
        S:RegisterBlizzardAccentRefresh(th, function(texture, color)
            texture:SetVertexColor(color[1], color[2], color[3], 1)
        end)
    end

    sf:SetScript("OnScrollRangeChanged", function(self, xrange, yrange)
        if not yrange then yrange = 0 end
        if issecretvalue and issecretvalue(yrange) then yrange = 0 end
        sb:SetMinMaxValues(0, math.max(1, yrange))
        local sfH = sf:GetHeight()
        if sfH and sfH > 0 and yrange > 0 then
            local ratio = sfH / (sfH + yrange)
            th:SetHeight(math.max(16, math.floor(sfH * ratio)))
        else
            th:SetHeight(math.max(16, (sfH or 20) - 4))
        end
    end)
    sf:SetScript("OnVerticalScroll", function(self, offset) sb:SetValue(offset) end)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local cur = sb:GetValue()
        local min, max = sb:GetMinMaxValues()
        if delta > 0 then sb:SetValue(math.max(min, cur - 20))
        else sb:SetValue(math.min(max, cur + 20)) end
    end)
    sb:SetScript("OnValueChanged", function(self, value) sf:SetVerticalScroll(value) end)

    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(sc:GetWidth() - 30)
    child:SetHeight(1)
    sf:SetScrollChild(child)

    local iy = 0
    for _, t in ipairs(blizzToggles) do
        local k = t.key
        _, h = W:Toggle(child, t.label, -iy,
            function() return db.blizzard[k] end,
            function(v) db.blizzard[k] = v; Reload() end
        )
        iy = iy + h
    end
    child:SetHeight(iy)

    C_Timer.After(0, function()
        local sfH  = sf:GetHeight()
        local contH = child:GetHeight()
        local range = math.max(0, contH - sfH)
        sb:SetMinMaxValues(0, math.max(1, range))
        if sfH and sfH > 0 and range > 0 then
            local ratio = sfH / (sfH + range)
            th:SetHeight(math.max(16, math.floor(sfH * ratio)))
        else
            th:SetHeight(math.max(16, (sfH or 20) - 4))
        end
    end)

    y = y + scrollH + 10

    return y
end)
