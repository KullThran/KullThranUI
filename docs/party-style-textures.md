# Party Frames style audit

Scope: Forever workspace, Party Frames only. Retail here means the visual style.

| Style | Health | Resource |
| --- | --- | --- |
| KUI | Configured SharedMedia/file texture | Configured texture, existing colour behavior |
| Classic | Interface\\TargetingFrame\\UI-StatusBar | Same native Classic texture, PowerBarColor for resource type |
| Retail | UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status | Native Party Mana/Rage/Energy/Focus/RunicPower atlas |
| Forever | Same native neutral health atlas | Same native resource atlases |

The neutral Health-Status atlas supports the existing class/custom health colours.
Coloured resource atlases use white vertex colour so their original pixels are retained.
Other resource types use Mana-Status with PowerBarColor. Atlas names are installed with
StatusBar:SetStatusBarTexture, which keeps progress clipping and atlas UVs under StatusBar ownership.
Classic alone resets full-file UVs; KUI's configured texture is not replaced.

Compared installed Retail 12.1.0.69933 and Forever 1.60.1.70291 DB2 atlas members and
extracted FileDataID 4681512 from both. Byte-identical SHA256:
31730ecae4dffc4e46bd6a16a0894610bc59189f5e34bd35657330c76ff4c35d.
Health-Status bounds: 73..143, 167..177 in the 256x256 sheet; Mana-Status:
77..151, 191..198. Native masks and frame geometry remain unchanged.

PvP AUTO used to have two conflicting anchor writers: PF_Portrait.PlaceBadges put
it beside the portrait, while the native style put it at BOTTOMLEFT. Both routes
now respect the native layout. Combat suppresses generic relocation and leaves
secure anchors installed. Explicit user anchors and KUI layout retain their own behavior.

Validation: seven focused Lua 5.1 tests cover all styles, native resource variants,
class colours, UV ownership, combat, theme switching, preview, status states,
PvP automatic/custom anchors and secure geometry. Syntax and whitespace checks pass.
In-game screenshot validation remains pending.

Primary native definition:
https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_UnitFrame/Mainline/PartyFrameTemplates.xml
