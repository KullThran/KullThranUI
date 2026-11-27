-- The screen positions these elements had as defaults on 2026-10-30, before
-- they were anchored to the Player, Target and Focus frames. Profiles still
-- on one move to the anchored default once. Do not edit.
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

KT.DefaultLayoutPrevious = {
    retail = {
        ["1080p"] = {
            focus = { point = "TOPLEFT", relativePoint = "CENTER", x = -415.6, y = -214.2 },
            focustarget = { point = "TOPLEFT", relativePoint = "CENTER", x = -415.6, y = -261.2 },
            pet = { point = "TOPLEFT", relativePoint = "CENTER", x = -413.6, y = -48.4 },
            targettarget = { point = "TOPLEFT", relativePoint = "CENTER", x = 295.9, y = -59.9 },
            combatTimer = { point = "CENTER", relativePoint = "CENTER", x = -354, y = -99 },
            combatRes = { point = "CENTER", relativePoint = "CENTER", x = -343, y = -26 },
        },
        ["1440p"] = {
            focus = { point = "TOPLEFT", relativePoint = "CENTER", x = -417.2, y = -215.5 },
            focustarget = { point = "TOPLEFT", relativePoint = "CENTER", x = -417.3, y = -262.6 },
            pet = { point = "TOPLEFT", relativePoint = "CENTER", x = -413.2, y = -32.7 },
            targettarget = { point = "TOPLEFT", relativePoint = "CENTER", x = 296.3, y = -42.2 },
            combatTimer = { point = "CENTER", relativePoint = "CENTER", x = -353, y = -92 },
            combatRes = { point = "CENTER", relativePoint = "CENTER", x = -343, y = -5 },
        },
        ["2160p"] = {
            focus = { point = "TOPLEFT", relativePoint = "CENTER", x = -417.6, y = -226.9 },
            focustarget = { point = "TOPLEFT", relativePoint = "CENTER", x = -419.7, y = -293 },
            pet = { point = "TOPLEFT", relativePoint = "CENTER", x = -414.6, y = -13.1 },
            targettarget = { point = "TOPLEFT", relativePoint = "CENTER", x = 292.9, y = -73.6 },
            combatTimer = { point = "CENTER", relativePoint = "CENTER", x = -353, y = -81 },
            combatRes = { point = "CENTER", relativePoint = "CENTER", x = -343, y = 23 },
        },
    },
    forever = {
        ["1080p"] = {
            focus = { point = "TOPLEFT", relativePoint = "CENTER", x = -419.6, y = -207.2 },
            focustarget = { point = "TOPLEFT", relativePoint = "CENTER", x = -419.6, y = -254.2 },
            pet = { point = "TOPLEFT", relativePoint = "CENTER", x = -412.6, y = -43.4 },
            targettarget = { point = "TOPLEFT", relativePoint = "CENTER", x = 295.9, y = -63.9 },
            combatTimer = { point = "CENTER", relativePoint = "CENTER", x = -354, y = -96 },
            combatRes = { point = "CENTER", relativePoint = "CENTER", x = -342, y = -22 },
        },
        ["1440p"] = {
            focus = { point = "TOPLEFT", relativePoint = "CENTER", x = -415.2, y = -212.5 },
            focustarget = { point = "TOPLEFT", relativePoint = "CENTER", x = -415.3, y = -266.6 },
            pet = { point = "TOPLEFT", relativePoint = "CENTER", x = -414.2, y = -38.7 },
            targettarget = { point = "TOPLEFT", relativePoint = "CENTER", x = 298.3, y = -41.2 },
            combatTimer = { point = "CENTER", relativePoint = "CENTER", x = -355, y = -95 },
            combatRes = { point = "CENTER", relativePoint = "CENTER", x = -343, y = -10 },
        },
        ["2160p"] = {
            focus = { point = "TOPLEFT", relativePoint = "CENTER", x = -417.6, y = -221.9 },
            focustarget = { point = "TOPLEFT", relativePoint = "CENTER", x = -419.7, y = -280 },
            pet = { point = "TOPLEFT", relativePoint = "CENTER", x = -416.6, y = -25.1 },
            targettarget = { point = "TOPLEFT", relativePoint = "CENTER", x = 296.9, y = -67.6 },
            combatTimer = { point = "CENTER", relativePoint = "CENTER", x = -353, y = -87 },
            combatRes = { point = "CENTER", relativePoint = "CENTER", x = -345, y = 12 },
        },
    },
}

-- Anchored defaults that were replaced later (2026-10-30: the Combat Timer
-- followed the Player by its centre; now by its left edge). Profiles still
-- on one take the current default (KT:RepairLayoutPosition). Do not edit.
KT.DefaultLayoutPreviousAnchored = {
    retail = {
        ["1080p"] = {
            combatTimer = { point = "CENTER", relativeTo = "KullThranUI_UF_Player", relativePoint = "TOP", x = -54, y = 20 },
        },
        ["1440p"] = {
            combatTimer = { point = "CENTER", relativeTo = "KullThranUI_UF_Player", relativePoint = "TOP", x = -53, y = 27 },
        },
        ["2160p"] = {
            combatTimer = { point = "CENTER", relativeTo = "KullThranUI_UF_Player", relativePoint = "TOP", x = -53, y = 38 },
        },
    },
    forever = {
        ["1080p"] = {
            combatTimer = { point = "CENTER", relativeTo = "KullThranUI_UF_Player", relativePoint = "TOP", x = -54, y = 23 },
        },
        ["1440p"] = {
            combatTimer = { point = "CENTER", relativeTo = "KullThranUI_UF_Player", relativePoint = "TOP", x = -55, y = 24 },
        },
        ["2160p"] = {
            combatTimer = { point = "CENTER", relativeTo = "KullThranUI_UF_Player", relativePoint = "TOP", x = -53, y = 32 },
        },
    },
}
