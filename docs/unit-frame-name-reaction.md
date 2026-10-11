# Retail / Forever unit-frame name reaction strip

Original Blizzard BLP copied unchanged from the installed Retail client (12.1.0.69933).
FileDataID: 4631591. Atlas: 2060, 1024 x 512.
Member: ui-hud-unitframe-target-portraiton-type (16713), 135 x 18.
Pixel bounds: left 195, right 330, top 235, bottom 253.
SHA256: b182cbd822ce62e0e0b52e741e9330d755384ab01d6486ac6d503025a963ca76.

The atlas supplies the vertical alpha gradient. Retail and Forever use its flat
full native width (x 195..330) and visible gradient (y 235..249), excluding transparent padding.
The 135px name plate extends 11px past the 124px health track into the portrait.
Preserve its curved end and add that 11px extent to the configured strip width;
using health width alone or cropping the curved end exposes a grey wedge.

The Player artwork contains a grey name panel. The reaction strip draws over its
interior in ARTWORK -7 with a one-pixel inset on each edge; this retains the frame
rim while preventing the grey panel from suppressing the reaction colour.
UnitSelectionColor supplies the native RGB at full vertex alpha. NPCs whose tap is
denied use Blizzard's 0.5 grey; preview uses friendly green / hostile red. Classic
retains its original texture and geometry, with Vanilla reaction/PvP rules and
full vertex alpha. NPC reaction 3 is orange; unknown NPC reaction is blue.
Player-controlled units use asymmetric attack permissions plus PvP flags.
Tap-denied NPCs use grey, and the historical civilian override uses white.
These rules affect only the name strip: health/resource class colours and
portrait tint are not written by this function.

Focused Lua 5.1 tests cover native colours, tap denial, combat, preview, API fallback,
Classic preservation, inset geometry and packaged pixels. Visual client QA pending.
