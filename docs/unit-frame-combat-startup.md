# Unit Frames: reload during combat

The startup previously spawned protected frames before PLAYER_ENTERING_WORLD, applied position and scale immediately, and dropped ReloadFrames requests in combat. A late profile/persistence restore could therefore leave geometry from the startup profile visible until another refresh.

Startup now waits for IsLoggedIn and for combat lockdown to end. It binds the current profile when resuming. Position, scale, border sizing and full layout refreshes requested during combat queue one restore after PLAYER_REGEN_ENABLED. Saved native and Unlock Mode coordinates are never rewritten by this deferral. Disable cancels pending work.

`/ktufpos` reports startup/layout pending state, combat state, and native, Unlock Mode and live coordinates. The persistence debug log records deferred startup and post-combat restoration when enabled.

QA: enable a saved non-default layout, enter combat and reload. KUI creation waits until combat ends; then confirm all units restore their saved anchors and scale. Repeat while switching profile during combat and confirm the latest profile wins. Re-enter combat during a scale animation and check that protected geometry stops updating until combat ends.

Retail client with KUI Style hides unit-frame and nameplate levels, including previews and friendly nameplate paths. Other themes and the Forever client retain their level behavior.

Automated checks: unit_frame_combat_startup.lua, unit_frame_positions.lua, target_level_badge.lua, protected_visual_updates.lua. These cover control flow and geometry writes; in-client visual QA remains necessary.
