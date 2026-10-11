# Loot visibility diagnosis

The temporary observer loads with Enhancements in both workspaces. It is enabled
by default for this investigation and records native loot events without replacing
handlers, changing positions, restoring visibility or choosing Need/Greed/Pass.

## Capture a disappearance

1. Reload the updated addon and run `/ktlootdebug clear` before a pending drop.
2. Let a Need/Greed/Pass window disappear without clicking a roll option.
3. Run `/ktlootdebug dump` immediately. Include the retained hide calls and latest
   events in the report. `/ktlootdebug` also prints current frame/parent visibility.
4. Disable the observer with `/ktlootdebug off` after capturing the issue.

The log includes `START_LOOT_ROLL`, cancellation, native Add/Remove frame calls,
`RollOnLoot`, Hide/OnHide, SetShown, SetAlpha and SetParent. Hide/opacity callers
include their stacks. Snapshots walk the parent chain and record shown/visible,
alpha, effective scale, anchors and remaining roll time. Late-created frames are
observed after native loot updates.

At most 160 entries and 12 retained hide calls are kept in
`KT.db.global.lootVisibilityDebug`, saved with the core addon SavedVariables.
Hide calls are retained separately so timer updates cannot overwrite the cause.
The watcher stops after cancellation or 180 seconds; countdown alone does not
produce visibility-change records. This observer is diagnostic and does not
establish which addon caused the disappearance until a real capture is inspected.

## Relevant existing paths

- Enhancements filters cosmetic alerts and has a pending-roll visibility guard.
- Forever also loads BlizzardFrames with a separate roll visibility watcher.
- Blizzard handles Need/Greed/Pass and legitimate roll completion/cancellation.

The dump must distinguish an explicit choice, timer expiration or cancellation
from a frame/ancestor being hidden while a choice is still pending.

## Validation

`tests/loot_visibility_debug.lua` exercises hide caller stacks, parent opacity,
late frames, choice/cancellation observation, bounded persistence, disabling the
observer and absence of automatic rolls or extra frame visibility writes.
Existing loot filtering/recovery tests remain required. A real in-client capture
is still needed to identify the caller responsible for the reported disappearance.
