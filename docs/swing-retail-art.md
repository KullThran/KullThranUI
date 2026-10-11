# Retail swing bar appearance

Retail uses a plain dark empty background and the original thin Retail casting
bar border. Forever keeps its native swing background and bronze ornaments.
Both real bars and options previews use `ns.StyleSwingBar`.

The unmodified `UICastingBar-Retail.blp` sheet was extracted read-only from the
installed Retail client 12.1.0.69933. FileDataID 4505182, UiTextureAtlas ID 1942,
dimensions 512x256. Border member 14235 (`ui-castingbar-frame`) has bounds
left=1, right=215, top=31, bottom=47. Bundling this sheet bypasses the Forever
client's replacement of the frame atlas without tinting its original pixels.

SHA256: `96c4779261efb57e93294498680b95ed98549977855f3ac31707182270856423`.

The old casting background atlas contains drawn grey stripes and is omitted
from Retail swing bars so an idle timer visibly remains empty. The timer fill,
values and expiry logic are unchanged. Native artwork was inspected visually;
client screenshot validation after /reload remains pending.
