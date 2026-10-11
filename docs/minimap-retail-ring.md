# Retail minimap ring

The Forever workspace bundles the unmodified Retail `Interface/HUD/UIMinimap.blp`
sheet as `KullThranUI/Libraries/texture/media/minimap/UIMinimap-Retail.blp`.
This bypasses Forever's bronze replacement for `UI-HUD-Minimap-Frame`.

Source: locally installed Retail client 12.1.0.69933, extracted read-only with
CascLib. FileDataID 4618651; UiTextureAtlas ID 1990; sheet dimensions 512x512.
UiTextureAtlasMember ID 14843 (`ui-hud-minimap-frame`) has committed bounds
left=1, right=439, top=36, bottom=496. The original Mainline Minimap.xml renders
this region at 215x226 centered on a 198x198 minimap.

SHA256 of the bundled, unmodified BLP:
`abe7453032f0ff71af5c7712da163425cb1a84a2188ec3312c2a157228d41547`.

The real minimap, ring picker and live preview all use `KT.DrawMinimapRing`.
Retail is neither desaturated nor tinted. Classic retains its separate crop,
square region size and offsets; Forever continues to use its native atlas.

Validation: `tests/minimap_retail_ring.lua`, Lua 5.1 parsing, diff whitespace
check, and visual inspection of the extracted sheet. In-game /reload QA pending.
