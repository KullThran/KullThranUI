# Visual style portability and Damage Meter windows

The shared source copied on October 9 still relied on Forever-only swing
atlases. Retail therefore used fallback cast art and omitted the native
swing decorations on autoattack bars and Damage Meter windows.

The core style resolver now retains native atlases when present and falls
back to the bundled original UISwingTimerBar-Forever.blp sheet when absent.
Cast bars, swing bars and live/preview Damage Meter skins share this resolver.
The sheet was extracted read-only from the installed Forever client
1.60.1.70338, FileDataID 8344036, dimensions 512x256. Atlas rectangles come
from ForeverAtlasMember.db2, atlas 4237. Pixels are unmodified.

SHA256: `7edc04fa4ff1fd5f80d6dadb5de40f13c4e6e24e886d539bbd06929e4b804fc6`.

Each additional Damage Meter window now changes its theme-owned bar texture
and background when the global Visual Theme changes. It saves those fields
per theme, including its prior KUI appearance, while retaining its mode,
session, position, dimensions and dock. This also runs when an existing or
new secondary window is first accessed after loading the profile. The
existing refresh entry point repaints the primary and all secondary windows.

Validation: nine focused Lua tests passed in each workspace using Lua 5.1
(lupa.lua51); all four modified production files compile under Lua 5.1.
Focused git diff --check passed. Tests include absent host atlases, live and
preview rendering, theme cleanup, ongoing cast progress and all five
additional Damage Meter windows. The full workspace diff has pre-existing
whitespace findings outside these files. The extracted artwork was visually
inspected; in-game /reload validation remains pending.
