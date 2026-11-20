local _, ns = ...

-- Per Visual Style tokens for the Armory. The style comes from
-- KT.VisualThemes:ResolveModuleStyle(AR.db); a style without a token keeps
-- the default look (e.g. no slotFrame = flat quality edges).
local TEX = [[Interface\AddOns\KullThranUI\Libraries\KUITextures\Armory\]]
local FRIZ = [[Fonts\FRIZQT__.TTF]]
local MORPHEUS = [[Fonts\MORPHEUS.TTF]]
local AVANT = [[Interface\AddOns\KullThranUI\Libraries\font\AAA_ITC_Avant_Garde.ttf]]

-- Slot frame drawn at 43px over the 37px slot: the material layer plus a
-- white layer tinted with the item quality from minTintQuality up, at
-- tintStrength unless the profile overrides it for that style.
local function SlotFrame(frame, tint, strength)
    return {
        frame = TEX .. frame,
        tint = TEX .. tint,
        scale = 43 / 37,
        minTintQuality = 0,
        tintStrength = strength,
    }
end

-- Stat icon atlases (<style>_stat_icons, 512x256): 8x4 cells of 64px in this
-- order (tools/photoshop/armory_stat_glyphs.py ORDER).
local GLYPHS = {
    "strength", "agility", "stamina", "intellect", "spirit", "health", "mana", "crit",
    "haste", "mastery", "versatility", "attack_power", "attack_speed", "spell_power", "armor", "dodge",
    "parry", "block", "leech", "avoidance", "speed", "arcane", "fire", "frost",
    "nature", "shadow", "pvp", "tab_stats", "tab_titles", "tab_equipment", "tab_progress", "background",
}
local GLYPH_INDEX = {}
for index, name in ipairs(GLYPHS) do GLYPH_INDEX[name] = index - 1 end

-- Progress page icon atlases (<style>_progress_icons, 512x64): one row of
-- 64px cells in this order (tools/photoshop/armory_progress_glyphs.py ORDER).
local PROGRESS_GLYPHS = { "keystone", "vault", "raid", "world", "clock", "check", "star", "lock" }
local PROGRESS_INDEX = {}
for index, name in ipairs(PROGRESS_GLYPHS) do PROGRESS_INDEX[name] = index - 1 end

-- Plate headers: 128x32 texture, 24px caps drawn at `cap` width.
local function Plate(file, title, font, size)
    return {
        kind = "plate", plate = TEX .. file,
        height = 20, cap = 16, capCoord = 24 / 128, inset = 8,
        title = title, font = font, size = size, flags = "OUTLINE",
    }
end

-- Stats panel looks (progress: the Progress page icon atlas). Colours are {r, g, b[, a]} or "accent" (the style's
-- accent colour at runtime). Text: font + flags (OUTLINE) or a soft shadow.
-- tabs: the Stats/Titles/Equipment/Progress bar (ArmoryProgressBridge) as
-- icon buttons: square (dark plate, accent edge and underline), medallion or
-- tile (the atlas icon is the button, glowing when active).
local ArmoryStyles = {
    kui = {
        slotFrame = SlotFrame("kui_slot_frame", "kui_slot_tint", 0.90),
        stats = {
            header = { kind = "tab", title = "accent", font = AVANT, size = 10, flags = "", caps = true, inset = 17 },
            font = AVANT, flags = "", shadow = true,
            label = { 0.84, 0.84, 0.84 }, value = { 1, 1, 1 }, muted = { 0.55, 0.55, 0.55 },
            band = { 1, 1, 1, 0.035 }, bandHeight = 18, bandInset = 8,
            icons = { atlas = TEX .. "kui_stat_icons", tint = "accent" },
            progress = { atlas = TEX .. "kui_progress_icons", tint = "accent" },
            ilvl = { title = "accent", font = AVANT, size = 9, flags = "", caps = true },
            pvp = { 0, 0.78, 1 },
            tabs = { kind = "square", accent = "accent", size = 24 },
        },
    },
    forever = {
        slotFrame = SlotFrame("forever_slot_bronze", "forever_slot_tint", 0.55),
        stats = {
            header = Plate("forever_header_plate", { 0.93, 0.77, 0.55 }, FRIZ, 13),
            font = FRIZ, flags = "OUTLINE",
            label = { 0.886, 0.839, 0.745 }, value = { 1, 1, 1 }, muted = { 0.63, 0.57, 0.49 },
            band = { 1, 0.92, 0.78, 0.045 }, bandHeight = 18, bandInset = 8,
            icons = { atlas = TEX .. "forever_stat_icons" },
            progress = { atlas = TEX .. "forever_progress_icons" },
            ilvl = { title = { 0.93, 0.77, 0.55 }, font = FRIZ, size = 9, flags = "OUTLINE", caps = true },
            pvp = { 0.925, 0.588, 0.408 },
            tabs = { kind = "medallion", accent = { 0.93, 0.77, 0.55 }, size = 24 },
        },
    },
    retail = {
        slotFrame = SlotFrame("retail_slot_frame", "retail_slot_tint", 0.80),
        stats = {
            header = { kind = "fade", title = { 0.925, 0.95, 1 }, line = { 0.47, 0.69, 1 }, font = FRIZ, size = 13, flags = "" },
            font = FRIZ, flags = "", shadow = true,
            label = { 0.847, 0.871, 0.91 }, value = { 1, 1, 1 }, muted = { 0.57, 0.61, 0.67 },
            band = { 0.78, 0.86, 1, 0.04 }, bandHeight = 18, bandInset = 8,
            icons = { atlas = TEX .. "retail_stat_icons" },
            progress = { atlas = TEX .. "retail_progress_icons" },
            ilvl = { title = { 0.78, 0.84, 0.925 }, font = FRIZ, size = 9, flags = "", caps = true },
            pvp = { 0.31, 0.65, 1 },
            tabs = { kind = "square", accent = { 0.31, 0.65, 1 }, size = 24 },
        },
    },
    classic = {
        slotFrame = SlotFrame("classic_slot_frame", "classic_slot_tint", 0.60),
        stats = {
            header = Plate("classic_header_plate", { 1, 0.82, 0.35 }, MORPHEUS, 15),
            font = FRIZ, flags = "OUTLINE",
            label = { 0.94, 0.88, 0.71 }, value = { 1, 1, 1 }, muted = { 0.67, 0.59, 0.43 },
            band = { 1, 0.9, 0.63, 0.045 }, bandHeight = 18, bandInset = 8,
            icons = { atlas = TEX .. "classic_stat_icons" },
            progress = { atlas = TEX .. "classic_progress_icons" },
            ilvl = { title = { 1, 0.82, 0.35 }, font = MORPHEUS, size = 12, flags = "OUTLINE" },
            pvp = { 0.91, 0.30, 0.23 },
            tabs = { kind = "tile", accent = { 1, 0.82, 0.35 }, size = 24 },
        },
    },
}

function ArmoryStyles:Get(key)
    local style = rawget(self, key)
    return type(style) == "table" and style.slotFrame and style or {}
end

-- Texcoords (left, right, top, bottom) of a stat glyph in a style atlas.
function ArmoryStyles:GlyphCoords(name)
    local index = GLYPH_INDEX[name]
    if not index then return nil end
    local col, row = index % 8, math.floor(index / 8)
    -- Half a texel inside the cell so filtering never picks up the neighbour.
    local hx, hy = 0.5 / 512, 0.5 / 256
    return col / 8 + hx, (col + 1) / 8 - hx, row / 4 + hy, (row + 1) / 4 - hy
end

-- Texcoords of a Progress page glyph in a style's progress atlas.
function ArmoryStyles:ProgressCoords(name)
    local index = PROGRESS_INDEX[name]
    if not index then return nil end
    local hx, hy = 0.5 / 512, 0.5 / 64
    return index / 8 + hx, (index + 1) / 8 - hx, hy, 1 - hy
end
ArmoryStyles.PROGRESS_GLYPHS = PROGRESS_GLYPHS

ns.ArmoryStyles = ArmoryStyles
