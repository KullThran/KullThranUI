# Shared changes synchronized to Retail - 2026-10-09

Transferred the shared fixes from this conversation from the Forever workspace to
C:/Users/Pablo/Documents/KullThranUI-Workspace, preserving its existing edits and
client-specific behavior.

- Resource Bars: swing labels/fonts, per-theme native frame/fill art, separate
  Retail art, truly empty idle/expired fill, live preview and settings.
- Cast Bar: Forever outer ornaments shared by live bars and preview.
- Damage Meter: Forever outer ornaments and native Retail background/header/rows,
  native resize handles, common live/preview skin.
- Minimap: original Retail silver/four-gold-point border with packaged BLP and
  exact aspect ratio. Retail workspace's Forever C60 border remains intentional.
- Unit Frames: native reaction strip artwork and curved name extent, Vanilla
  Classic reaction/PvP/tap rules, independent class health colours, fitted aggro
  and resting name glow, asynchronous 2D portrait facing correction, CJK font family.
- Party Frames: native health/resource textures, stable health text in combat,
  status transitions, PvP AUTO anchor ownership and user override preservation.
- Loot roll: late item data recovery, ordinary alert settings compatibility,
  native queued rolls and preserved viewport/anchor handling.
- KUI Tracker: follow-player versus free positions, unlock restoration, retaining
  Retail UUF integration and Retail spell/item catalogues.

The new Forever social UI is client-specific and was explicitly requested for
Forever only; Retail retains its own friends UI. Retail modern classes, Mythic+
features, migrations, saved size/position defaults and durability anchor are retained.

Validation: 27 focused Lua 5.1 tests passed in the Retail workspace; all 15 touched
production Lua files parse. Shared renderer files are byte-identical where no
client adaptation is required; packaged assets match SHA256. Git whitespace checks
pass. In-game visual QA remains pending; no commit, release or publication performed.
