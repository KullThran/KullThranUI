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
    local _, y, h = nil, 0, 0
    local db = KT.db.profile.skin
    local Opt = KT.Options or Opt

    -- Two cards side by side, like the other pages: the skin itself and the
    -- Blizzard-wide options; the per-window toggles follow in one card.
    local cols = Opt.BeginOptionBlocks(sc, y)
    Opt.AddOptionBlock(cols, "left", "Window Style", function(container)
        local by = 0
        _, h = W:Toggle(container, "Enable Skins", -by, function() return db.enable end, function(v) db.enable = v; Reload() end); by = by + h
        _, h = W:ColorSwatch(container, "Window Background", -by,
            function()
                local c = db.blizzard.windowBackgroundColor or { r=0.05, g=0.05, b=0.05, a=0.98 }
                return c.r,c.g,c.b,c.a
            end,
            function(r,g,b,a)
                db.blizzard.windowBackgroundColor = { r=r, g=g, b=b, a=a or 0.98 }
                if S and S.RefreshBlizzardWindowBackgrounds then
                    S:RefreshBlizzardWindowBackgrounds()
                end
            end, true); by = by + h
        return by
    end)
    Opt.AddOptionBlock(cols, "right", "Blizzard Modules", function(container)
        local by = 0
        _, h = W:Toggle(container, "Style Blizzard Frames", -by, function() return db.blizzard.enable end, function(v) db.blizzard.enable = v; Reload() end); by = by + h
        _, h = W:Toggle(container, "Show Blizzard window borders", -by,
            function() return db.blizzard.showWindowBorders ~= false end,
            function(v)
                db.blizzard.showWindowBorders = v and true or false
                if S and S.RefreshBlizzardWindowBorders then S:RefreshBlizzardWindowBorders() end
            end); by = by + h
        _, h = W:Toggle(container, "Classic yellow for Blizzard frames", -by,
            function() return db.blizzard.classicYellowAccent == true end,
            function(v)
                db.blizzard.classicYellowAccent = v and true or false
                if S and S.RefreshBlizzardTheme then S:RefreshBlizzardTheme() end
            end); by = by + h
        return by
    end)
    y = Opt.EndOptionBlocks(cols)

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

    -- Every skinned window in one full-width card, two per row; the page
    -- itself scrolls, so the list needs no scroll frame of its own.
    local listFrame, list = Opt.CreateOptionBlock(sc, "Skinned Windows", 10, -y, sc:GetWidth() - 22)
    local function ToggleData(t)
        if not t then return nil end
        local k = t.key
        return {
            type = "toggle",
            text = t.label,
            getValue = function() return db.blizzard[k] end,
            setValue = function(v) db.blizzard[k] = v; Reload() end,
        }
    end
    local iy = 0
    for i = 1, #blizzToggles, 2 do
        _, h = W:DualRow(list, -iy, ToggleData(blizzToggles[i]), ToggleData(blizzToggles[i + 1]))
        iy = iy + h
    end
    y = y + Opt.FinalizeOptionBlock(listFrame, list, iy) + 10

    return y
end)
