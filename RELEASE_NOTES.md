## 6.1.10 (2026-11-27)

- Action Bars: both end caps of the main bar always show, in every visual style. The right one no longer goes missing when the bags bar is moved, hidden or on another row.
- Resource Bars: class resources use their own pieces, as on the nameplates: Soul Shards, Holy Power, Chi, Essence, Arcane Charges and runes (each spec its own rune). Destruction shows the shard that is filling.
- Resource Bars: new Pip Style option under Resource 1: follow the visual style, flat pips, KUI points, Retail or Forever. Combo points draw with their own socket and gem.
- Resource Bars: a resource that is not unlocked yet no longer shows a row of empty pips, and a new maximum (a level or a talent) rebuilds the pips at once.
- Resource Bars and Unit Frames: health, power and mana numbers count to their new value together with the bar instead of jumping in steps. The Smooth option turns it off.
- Aura Reminders: a class buff (Battle Shout, Fortitude, Mark of the Wild, Arcane Intellect...) that runs out or is removed during combat is reminded again right away, not only after combat.
- World Map: the window portrait (such as an addon's icon) draws above the KUI window border instead of under it.

## 6.1.9 (2026-11-25)

- Tooltip: new Card Style for item and spell tooltips (icon, item level, chips, weapon summary or spell grid and sell price). Turn it on in Tooltip > Card Style or in the new installer step; other tooltips keep the usual style.
- Experience Bar: rests in Blizzard's status bar slot until you move it in Unlock Mode; resetting it in Unlock Mode puts it back there.
- Cast Bar: stays on the KUI Cooldowns row on a slow login instead of falling back to Blizzard's viewer spot (and taking Buffs with it).
- Party Frames: the Enable switch turns the frames on and off at once. In combat they fade out and hide when combat ends; turning them on waits for the end of combat.
- Cooldown Manager: icons, gaps and borders stay on whole pixels after a UI scale or resolution change; docked bars keep the same gap as their icons; a disabled bar in a stack no longer leaves a hole.
- Cooldown Manager: Unlock Mode's Reset and Reset All put bars back where a new profile places them; bars docked to the party frames follow the group and wait for the frames after login.
- Cooldown Manager: spells lost and learned with talents go back to their old spot, and a partial list at login is no longer saved as the bar's list.
- Unit Frames: health, power and alternate mana bars glide to their new values in every visual style. Changing resource (a druid form) jumps at once instead of sliding from the old one.
- Bags: rarity frames are easier to read. Blue, purple and the other coloured qualities use their full colour with a soft glow, and grey items get a darker frame so they no longer look like white ones.
- Bags: items an active quest asks for get a turquoise border of their own; yellow stays for quest items and items that start a quest. Quest borders update when you accept or finish a quest. Only items the game ties to one of your quests are marked, as in the default bags, and items that start a quest show the game's ! mark. Quest items no quest needs any more leave the Quest category. Common (white) items now take a white tint too.
- Bags: white crafting reagents get a coral frame. Bags > Item Slots > Highlight Reagents turns it off.
- Bank and Warband Bank: item slots show the same rarity frames as the bags and follow the same options.
- Gold input popups (such as the guild bank deposit): the amount you type no longer sits under the coin icon.
- Chat: whispers play the game's whisper sound, like the default chat. Chat > Whisper Sound turns it off.
- Gossip: dialogue options no longer overlap; their rows are measured with the same font they are drawn with.
- Guild and Communities: the close and minimize buttons are KUI boxes inside the header instead of floating on the border.
- Armory: with an enchant or another item waiting for a target, the slot frames, quality tint and item level fade with the slots it cannot go on.
- Aura Reminders: missing group buffs show again in combat for the buffs the game lets addons read in combat, and clear when the buff is cast.
- Profiles: switching profile (also from a layout import) keeps the specialization assignment and the nameplate and Aura Reminders settings in step, so a reload no longer brings the old profile back. Teleport Menu, Cursor, Buffs, Flight Master and Party Frames follow a profile switch or reset at once.
- Profiles: importing a profile into another addon only switches this character, not characters with the same name on other realms. The full KUI reset from the options runs again, and resets and imports keep the character's identity data.
- Translations: the Enhancements card title is no longer in capitals in German, French, Italian, Portuguese and Russian; several wrong or broken texts were fixed and about 35 texts that showed in English are translated.

## 6.1.8 (2026-11-23)

- Armory: the stats follow your specialization. The panel shows its primary stat, Stagger for Brewmasters and mana regeneration for healers.
- Inspect Armory: the header icons keep one order: background, specialization, class.
- Skins: in the loot rolls window each item is as tall as its list of rolls, and the window no longer rebuilds itself on every frame while it is open. Hovering an item no longer causes errors.
- External Addons: BugSack's window can now be closed in combat.
- Minimap: on the square map the zone name sits in a title bar joined to the map's frame, in the look of your Visual Style; a name too long for the bar is cut at its ends. The Forever style wears the bronze frame of that client's windows, and the buttons around the map move out to clear it. The options preview and the installer show the same.
- Bags: hover your gold to see the gold of every character, the one you play first and then the richest, and the gold of your Warband bank, with the total. Gold waiting in their mailboxes is listed apart, and gold you mail to one of your own characters counts there at once. Log in to each character once to add it.
- Bags: the search box has a button to clear the search.
- Bags: slot borders no longer lose an edge at some window scales; the grid lines up with the pixels of your screen.
- Chat: the whisper buttons are squares with the name of the person on their bubble, pink for whispers and blue for Battle.net, in the art of your chat style. They sit in a column right beside the chat, with a second column when the first one is full, and the close button of each shows while the mouse is over it.
- Chat: whisper conversations keep their place instead of jumping to the front; a new one goes last, or takes the place of the one unused for longest when there is no room.
- Unit Frames: new Portrait Mode card in the options to set 2D, 3D or class portraits, with the zoom, rotation and offsets of 3D, for every frame at once or one by one.
- Unit Frames: a unit whose level is hidden because it is far above yours shows Blizzard's skull in place of a red "??", as on Blizzard's target frame. In combat the combat icon takes that spot, as before.
- Unit Frames: the PvP badge sits on the outer side of the portrait, whichever side the portrait is on, instead of over the name.
- Unit Frames: Aura Spacing only changes the gap between icons; it no longer moves the auras away from the frame. Turning the player's buffs on or off or changing how many show applies at once, and their icons match the target's.
- Unit Frames: aura icons no longer overlap or move when the icon size or frame layout changes in combat; the change applies when the combat ends. Stack and time texts are drawn above the icon border.
- Party Frames: leaving a raid or battleground back into your party no longer leaves a player from that raid drawn on a party member's frame.
- Party Frames: some raid sizes no longer leave a member's frame undrawn, or showing the previous player, when the group fills.
- Resource Bars: a bar or the stack being moved in Unlock Mode stays where you put it when the bars are rebuilt (a shapeshift, for example), and the movers follow the bars. The stack keeps its bottom edge where you drop it, so showing, hiding or detaching a bar no longer moves the others. Reset puts the stack back over the Cooldown Manager.
- Settings: the one-time reset window has a goblin miner on the right of its sign in place of the mechanostrider rider.

## 6.1.7 (2026-11-19)

- Mythic+ Timer: each boss has a small round portrait next to its name, taken from the Adventure Guide and greyed once the boss is dead. The test run and the installer preview show the portraits too.
- Party Frames: the missing-buff reminder hides in combat and comes back after it. It now also shows on members out of spell range, members too far away to be seen keep their last known state, and dead or offline members never get it.
- Party Frames: power bars take the colour of each member's resource (red for rage, yellow for energy and so on) instead of always mana blue; mana keeps KUI's blue.
- Unit Frames: the options page is laid out as cards on the left: General, Name & Level, Portrait, one card per frame (Player, Pet, Target, Focus, Target of Target, Boss) and Portrait Auras. A frame's card has its size, bars and text on the left and its portrait, castbar and auras on the right. Search results, Unlock Mode's Open Configuration and clicks on the preview open the right card.
- Party Frames: the options page is laid out as cards on the left: General, Layout, Appearance, Indicators, Auras, Dispel & Missing Buffs, Spell Visibility, Portrait Auras and Profiles. The group cards edit the group picked in the bar above them, the level and PvP icon settings are under Indicators, and search results open the right card.
- Bags: a more compact window. The header, toolbar and footer are thinner, the gaps and item spacing are smaller, and the footer fits on one line, with the selected item's name cut before the gold and currencies. The Options, Compact and Close buttons and the toolbar buttons are now small icon buttons with KUI's own icons and tooltips; the compact view button is lit while that view is on.
- Bags: the watched items button shows an eye and how many items you watch. Click it to show only the watched items and again to show everything; its tooltip reminds you that Alt-click watches an item.
- Bags: newly looted items get a pink border. The bag slot icons are smaller by default (the old default size moves to the new one, a size you chose is kept) and can go down to 16; the toolbar grows when you set them larger.
- Bags: opening a vendor, bank or mailbox with the bags already open no longer closes them, and closing that window only closes the bags if it was the one that opened them.
- Unlock Mode: dragging a unit frame moves only that frame. The frames laid out around it (Pet, Focus, Target of Target, Focus Target, Combat Timer and Combat Res) stay where they are; hold Ctrl while dragging or nudging with the arrow keys to bring them along. Typing coordinates or centring a frame also leaves them in place, and the help panel explains it.
- Unlock Mode: opening Blizzard's Edit Mode pauses Unlock Mode and keeps your unsaved changes, and closing Edit Mode brings it back, instead of closing Unlock Mode.
- Unlock Mode: the Focus mover sits on the Focus frame in its default place under the Player frame, instead of in the middle of the screen, when you have no focus.
- Cooldown Manager: a character with no specialization yet, and the Buffs bar, follow Blizzard's Cooldown Manager as it is, so spells learned later and buffs not active at the time of the import are no longer left out. Spell lists saved for another specialization (a profile shared with another class or spec) no longer filter this character's bars.
- Cooldown Manager: turning the bars on (installer, options or a profile change) also turns on Blizzard's Cooldown Manager, which fills them. Importing the Blizzard layout can read it before Blizzard's bars have been shown, says why when Blizzard's Cooldown Manager is not available yet (a level requirement, for example), and the installer's button only says Layout Imported when something was imported.
- Aura Reminders: group buff reminders (such as Arcane Intellect, Power Word: Fortitude or Battle Shout) hide when combat starts and come back when it ends.
- Cast Bar: applying a different style asks for a reload, as on the Experience Bar page; applying the style you already use does not.
- Settings: the one-time reset window is now an Under construction! sign, with a gnome in a hard hat hammering on one side and a goblin on a mechanostrider on the other. It says a fresh start is recommended since 6.1.6; Reset and reload and Keep my settings work as before.
- Options: the section cards beside the Unit Frames, Party Frames and Nameplates options scroll the page with the mouse wheel, and shrink to fit the window when it is short.
- Party Frames: the Spell Visibility list scrolls with the mouse wheel again.
- Loot Rolls: while a roll is up, left and right clicks on the world above the rolls work again; the empty space the game keeps for the rolls no longer catches them.
- Resource Bars: each bar (class resource, power, extra mana, health and the autoattack bars) can be detached from the stack in its options and moved on its own in Unlock Mode. Until you move it, it keeps its place in the stack.
- Resource Bars: the autoattack bars have style cards (KUI Style, Forever, Retail, Classic), like the Cast Bar.

## 6.1.6 (2026-11-19)

- Settings: a one-time window offers a clean start. Reset and Reload deletes all saved KullThranUI settings and profiles, reloads the UI and opens the installer; Keep my settings carries on as before. The question is not asked again, and a new install does not see it.
- Bags: new Category List options. Hide the whole category list (the arrow beside the size button narrows the window to the item grid, and the arrow left of the grid title brings it back), turn the category icons off, or switch between KUI's own category icons and the game's item icons.
- Bags: new Item Slots options. Rarity Frame gives each slot the Armory slot frame of your Visual Style tinted by quality, a coloured edge or nothing; Rarity Colour From sets the lowest quality that gets a colour. Grey Out Junk, Highlight New Items and Highlight Quest Items join the item level options here.
- Bags: new Accessibility options. Text Size enlarges the category list, category titles, item counts and item levels; Window Scale sizes the whole window (the same value as the scale in Unlock Mode) and is kept after a reload.
- Bags: smart search. Type a name, a type (weapon, enchant, gem, potion), a slot (ring, head), a quality (epic) or an item level (ilvl>200, 200-250). Words combine, || means or and ! means not; English and Spanish words work in any client language. The empty search box shows what it understands.
- Bags: new Equipped Bags options to show your bag slots and set their icon size. The toolbar button for them has its own icon and is lit while they are shown.
- Compatibility: the addon list has tabs for Conflicts, Installed/Disabled, Ignored and Recognized Addons (every addon KUI knows, installed ones in green), and a search by addon name, category or KUI module.
- Compatibility: new Ignore button. An ignored addon keeps running and is left out of the login warning and of Disable All; Stop Ignoring All clears the list.
- Compatibility: new Warn At Login For setting: all conflicts, medium and high risk, or high risk only. The installer's conflict page follows it.
- Compatibility: each category shows whether it is a conflict or an overlap, its risk and the KUI modules it affects, and each addon shows its own description.
- Compatibility: many more addons are recognised, among them AzeriteUI, RealUI, LUI, KkthnxUI, DuffedUI, ShestakUI, LiteBag, DJBags, Bagshui, Skada, Recount, TinyDPS, XPerl, Luna Unit Frames, TinyTooltip, TipTop, Narcissus, MythicPlusTimer and IceHUD, with new categories for Resource Bars, Buffs & Debuffs and Experience Bar.
- Inspect Armory: new Inspect Style picker with the slot frames, class icon frame and glyphs of each Visual Style, and new Slot Borders options: Show Slot Borders, Tint Border by Quality and Tint Strength.
- Unit Frames: new Player / Target Name Y Offset slider under Global.
- Unit Frames: the Player and Target PvP badges can be moved in Unlock Mode and keep following their frame.
- Cast Bar: new Show Text Plate option for the Retail and Forever styles. Without the plate, the spell name shows inside the bar.
- Options: search ranks results with modules first, then their sections, then options, and shows where each result lives (Module > Section). Accents and spaces do not matter ("castbar" finds Cast Bar), every Enhancements category, Nameplates card and Aura Reminders page is searched, and a result opens the right tab. Profile and frame lists filter the same way.
- Unlock Mode: Open Configuration (right-click or the cog) opens the element's own options at the right tab or section: unit frame, party frame mode, Cooldown Manager bar, tracker or buff bar, Damage Meter, Aura Reminders and more. The button is hidden when an element has no options.
- Unlock Mode: a click that only selects an element no longer moves it, so docks and anchors stay and no unsaved-changes prompt appears.
- Unlock Mode: elements attached to a moved frame (a PvP badge, a docked window, a bar anchored to another element) keep their movers on them while you drag, nudge or center.
- Unlock Mode: empty Cooldown Manager trackers show their placeholder slots as soon as Unlock Mode opens, so they can be moved at their real size.
- Escape Menu: with the Game Menu skin or Style Blizzard Frames turned off, the menu keeps Blizzard's own layout, and the KullThranUI buttons take Blizzard's button style at the position you chose.
- Installer: the addon conflict page shows each category with its risk, the modules it affects and each addon's icon. The login conflict popup no longer opens on top of it.
- Aura Reminders: the pet reminder only shows when you can summon a pet.
- Aura Reminders: reminders update when buffs change on group members and when you change stance or form. Group members out of range or in another phase no longer count as missing a buff.
- Aura Reminders: a buff you place on an ally during combat, such as Source of Magic or Blistering Scales, clears its reminder.
- Cast Bar: turning Auto Width off brings back the width you had before, and a width you set by hand is kept.
- Cast Bar: the fill glides smoothly again on computers that have been running for days.
- Cast Bar: the options preview fits the bar, icon and text plate inside the preview area.
- Nameplates: the nameplate distance is set again when another addon or a settings reset changes it.
- Inspect Armory: new header. The class and spec icons and the background selector sit beside View in Dressing Room, the average item level is on the right of the header instead of covering the upgrade and enchant texts by the trinkets, and a smaller Raider.IO button sits at the end of the level line. Item level and enchant texts sit above the slot border.
- Inspect Armory: the Talents button moves under the window, after the tabs, so it no longer covers the off-hand upgrade and enchant texts.
- Damage Meter: discarding a drag in Unlock Mode keeps the window in its dock.
- Unlock Mode: Revert also puts back elements that were hidden when Unlock Mode opened and moved afterwards, and restoring defaults no longer saves the screen centre as the position of elements without one. During a group drag, frames no longer snap to the frames being dragged with them.
- Unit Frames: Shift+left-click on a unit frame no longer opens the KUI options.
- Aura Reminders: middle-clicking an icon to dismiss it no longer also casts the spell or uses the item.
- Aura Reminders: the reminder icons hide when combat starts instead of staying as invisible buttons that catch clicks, and the pet menu closes at the pull without an error.
- Compatibility: addons that cannot load (a missing dependency, out of date) no longer count as conflicts, and old "reload required" marks clear after a reload.
- Skins: status bars such as achievement progress no longer draw empty, and close buttons fit their box.
- Skins: popups keep their alert icon, progress bar, spinner, dropdown and item button, and a popup reused for another dialog is styled again. Windows with their own skin, such as the guild invite, pet battle queue and wardrobe set editor, are no longer restyled as popups, and the role check icon no longer floats over the role buttons.
- Skins: book and letter text keeps its scrollbar track.
- Skins: quest objectives are coloured on the right line when a quest has a waypoint, and the title reward icon shows.
- Skins: World Map breadcrumbs fit in the bar, and quest text keeps its meaningful colours (green objectives, red money) while dark text is lightened.
- Skins: guild bank tabs dim correctly while searching, the guild invite shows the reputation warning, the guild bank log scrollbars sit in place, Guild Control has a proper close button and the Communities member list scrollbar is styled.
- Skins: the mail inbox tells read and unread mail apart correctly.
- Skins: group finder class bars no longer show through windows dragged over them, and the role poll and keystone windows have proper close buttons.
- Skins: the Great Vault keeps its KUI style when it refreshes.
- Skins: the profession recipe checkboxes (Track Recipe, Allocate Best Quality) are styled.
- Skins: Collections side tab icons no longer stretch when clicked.
- Skins: the Settings tabs keep the KUI font centred and highlight the right tab after a search.
- Skins: Encounter Journal loot rows no longer run the slot and armour text into the item name.
- Skins: the AddOn list's dropdown, search box and performance controls show above its header.

## 6.1.5 (2026-11-17)

- Skins: new Loot History skin. The loot rolls window takes the KUI style, and each item lists the rolls under it: every Need, Greed and Transmog roll with its number, then who passed and who is still deciding.
- Nameplates: names of friendly players in name-only mode sit above the head again instead of on the character's chest. Name Only Distance now defaults to 0, and profiles still on the old -20 move to 0. Friendly NPCs and their quest markers are unchanged.
- Cooldown Manager: Player and Target dock right beside the cooldown bar, level with it. With the Forever and Classic styles they no longer keep a wide gap from the bar.

## 6.1.4 (2026-11-16)

- Profiles: loading or importing the Cooldown Manager from another profile keeps the spells of every specialization in your current profile.
- Profiles: Nameplate and Aura Reminder settings no longer carry over to a character that uses a different profile.
- Profiles: Save As no longer overwrites a profile that already exists.
- Profiles: a profile assigned to your specialization is applied when you change spec, log in or reload, not on every loading screen. Switching profiles by hand updates the assignment of your current spec.
- Profiles: imported or copied settings get their default values right away. A full import keeps your own Progress Bars, Danders integration and interrupt slots, and exports no longer carry the installer state.
- Profiles: a failed import keeps the import window open with the error, and a string with no usable module data says so.
- Profiles: Import Modules refuses a full profile, Import Party Frames applies only the Party Frames settings, and a failed import from the Party Frames page or Unlock Mode keeps the window open with the error.
- Profiles: loading modules from another profile also resets the settings that profile keeps at their defaults, and asks for a reload like an import.
- Profiles: the Cooldown Manager's tracked buff bars and their positions are saved with each specialization and travel with CDM exports.
- Fonts & Colors: colours you pick by hand (tooltip text, chat panel, Armory separator and the rest) are no longer replaced by the style after a refresh or reload. Applying a style preset sets them again.
- Unlock Mode: Reset All also restores the Damage Meter, Aura Reminders and the other elements that keep their own position. Closing Unlock Mode waits until combat ends.
- Minimap button bag: with the bag turned off, hovering the minimap no longer hides addon buttons, and released buttons get their size and position back.
- Options: Resolution Preset applies the preset you choose, and search finds every General sub-tab and opens the right one.
- Visual Style: applying a style keeps your health colour choice (Health or Class) for its unit frames.
- Manage Modules: turning Resource Bars back on no longer turns on the health bar.
- Resource Bars: fixed an error on every power update with custom markers. Hide Out of Combat shows the bars as soon as combat starts, and turning the module off and on keeps the choice of each bar.
- Resource Bars: new Extra Mana Bar option. It shows your mana on its own bar above the power bar while your resource is another one, such as Energy or Rage in a druid form.
- Experience Bar: new second bar for reputation or honor, above or below the main bar, with room kept for it next to the action bars.
- Buffs and Debuffs: the options preview shows the style, shape, fonts and offsets. Switching to a profile with the module on or off applies without a reload, and the Shape menu follows the Style.
- Aura Reminders: custom auras follow Enable Module, a preferred consumable that no longer exists falls back to Last Used, and the Source of Magic reminder keeps the setting you saved.
- Action Bars: the key press highlight respects Shift, Ctrl and Alt and follows new key bindings, and Hide Hotkeys keeps the hotkeys hidden.
- Unit Frames: the KUI style shows the group leader crown on your own frame.
- Party Frames: Boss mode frames show in encounters that start in combat. Raid movers in Unlock Mode follow the module and mode switches, and buff reminders recognise the spell names of every language.
- Armory: hovering a stat in combat no longer causes a Lua error.
- Inspect: quality highlights, upgrade hints and enchants update on every slot, and the enchant text hides when Show Enchants is off. Background Type lists the real backgrounds, and four options that had no effect are gone.
- Armory and Inspect: each enchant shows once, beside its slot, without a second copy inside the slot.
- Installer: a Visual Style picked in the installer is applied with every Reload UI button.
- Installer: the question to use an existing profile shows again until you answer it, closing the installer keeps your own profile, and each profile in the list shows the characters that use it.
- Tooltip: hovering players no longer disturbs an open Inspect window.
- Tooltip: the item or spell icon no longer covers text on the right, such as a spell's range, when the tooltip first opens.
- Teleport Menu: Hide Minimap Button hides the button.
- Bags: the toolbar shows the reagent bag slot, and every bag slot swaps bags as on the bag bar.
- Skins: role check and ready popups show the right role icon, without a duplicate. Turning Enable Skins off also stops the Bank, Trade and timer bar skins, and the Loot Roll switch shows its real state.
- Skins: the Report and Battle.net windows are skinned, Armory and Inspect slots keep their gem and flyout art, the World Map no longer draws a flat line over the gradient border, and the guild bank icon picker is skinned.
- Skins: the accent colour updates at once in Collections, Transmog and the Adventure Guide.
- Friend List: Battle.net group assignments are no longer lost when Battle.net is offline, Battle.net notes stay with the right friend, the raid panel is not moved in combat, and a disabled list no longer shows tabs Blizzard had hidden.
- Spell History no longer grows while it is hidden, and Damage Meter Reset All stops a history capture in progress.
- External Addons and Compatibility: addons that are enabled but not loaded yet are detected.
- Translations: corrected texts in several languages, among them Fade on Mouseover in Spanish, Portuguese and Russian, which said the opposite.
- Combat Res: the death warning uses its own frame instead of the raid warning frame, which could break raid warnings.
- Combat Timer: turning it off in combat keeps it hidden.
- Teleport Menu: cooldowns no longer cause errors in combat, and an item to re-equip waits until combat ends.
- Tooltip: Raid Progress waits for the other player's achievement data and is hidden while no raid is tracked.
- Chat: player name colouring is safe in combat, and the combat log buttons keep their translated text.
- Dragonriding: no error when the module is off.
- Mythic+ Timer: enemy forces with Mythic Dungeon Tools are safe in combat.
- Skins: the guild invite emblem shows correctly, money icons show in popups, the Mythic+ teleport buttons cast through a secure button and show their cooldown, and invalid Armory slots are shaded again when you pick an enchant target.
- Bags: equippable quest items go to Quest.
- Party Frames: Show Dispel Overlay applies to aura icons, levels update when a member levels up, and the raid marker sits on the portrait.
- Objective Tracker: its options page no longer overlaps the profile tools.

## 6.1.3 (2026-11-15)

- Nameplates: Blizzard reuses its plate frames from one unit to the next. A frame KUI had turned into an enemy plate now gets its health bar, cast bar, name, auras and widgets back when that plate goes away, so the next friendly or NPC plate that receives it no longer misses parts or shows widgets in the wrong place.
- Nameplates: the level number of a friendly player stays on that player's plate instead of turning up beside another unit once plates are reused.
- Nameplates: the soft-target interact icon shows above the name on name-only friendly plates.
- Nameplates: when KUI stops hiding friendly buffs and debuffs, you get your own setting back even in a later session.
- Nameplates: a buff, debuff or crowd control slot switched on or off in the options applies to the plates on screen right away.
- Nameplates: the DoT damage marker no longer flashes on a plate reused for another mob.
- Nameplates: class icons pick up a respec within 30 seconds instead of keeping the old spec until the next loading screen.
- Nameplates: plate colours and aura filters no longer rely on unit values the game can hide (level, classification, reaction), and one failing plate no longer stops the refresh of the others.
- Nameplates: when a friendly plate leaves the screen, KUI no longer shows again the Blizzard plate frame it had hidden. Blizzard reuses those frames, so a released one could stay drawn until a reload. A new /knpdebug stray command lists any frame still drawn without its unit.
- Nameplates: a plate that appears for your current target or focus now gets the target or focus look, and the glow and arrows leave it when you pick someone else. The class resource pips on the target are no longer hidden every time the target is refreshed.
- Nameplates: Restore Defaults really resets the nameplate settings instead of bringing back the ones saved at login.
- Nameplates: enemies near you keep their plates after a loading screen, the mouseover highlight no longer stays on a plate after it is rebuilt (at the start of a duel, for example), and the cast bar interrupt colour updates when your interrupt becomes available during a cast (a pet summoned mid-fight).
- Nameplates: the DoT tracker no longer forgets a resist or dodge on a mob when you or your group take a hit, and DoTs no longer show on another mob that reuses the plate after the overlay was turned off.
- Nameplates: with the module off, or with another nameplate addon such as Plater in charge, KUI leaves friendly plates alone. The raid marker on friendly bars shows in the Bottom position.
- Unit Frames: Target of Target and Focus Target follow a target switch at once (name, health, level, status) instead of up to half a second later, and their heal prediction follows too.
- Unit Frames: health and power bars jump to the new unit's values when the frame shows someone else instead of sliding from the previous unit's, and a hit number shown on the previous target or focus is cleared.
- Unit Frames: class and power colours of the text bar and the power value text follow the unit when the target changes or a druid changes form.
- Unit Frames: a text slot set to none or covered by a centre text no longer shows an old value, and the AFK, Dead or Offline icon no longer brings back a text the layout had hidden.
- Unit Frames: a reload no longer flashes the previous unit on Target, Focus or Boss frames, and a frame switched off no longer comes back with the next target. Leader, assistant, resurrect, summon and raid marker icons come back when a group frame is shown again, and roster changes made in combat are applied when it ends.
- Unit Frames: the class resource row is rebuilt for the new spec after a spec change (after combat if it happens in a fight), and the Tip of the Spear pips go out when the stacks end.
- Unit Frames: in a vehicle the Player frame no longer keeps your dispel border, and after a scale change the cast bar fill and spell text no longer run under the spell icon.
- Unit Frames: scaling the Boss mover in Unlock Mode scales all five boss frames and uses the boss settings, scaling the cast bar or class power mover no longer changes the Player frame's scale, and the boss frames keep their position and spacing after a refresh.
- Unit Frames: Player and Target docked beside the Cooldown Manager bar stay level when the bar changes height.
- Experience Bar: the reputation bar reads the watched faction like Blizzard's bar: its standing, paragon, renown and friendship progress, a full bar with the name for a faction at its last step, and Reputation: None when no faction is watched. In Auto mode at the level cap, honor and the watched reputation come first.
- Experience Bar: XP per hour counts from login or reload instead of starting again at every loading screen. The Disable At Max Level box shows its real state, the Mode list shows Reputation when it is chosen, the width goes up to 1200 and the rested colour updates the preview.

## 6.1.2 (2026-11-14)

- Skins: group loot rolls (Need, Greed, Pass) get a KUI skin: a compact dark panel, the item icon in a border of its quality colour, the roll buttons in a row and a thin timer bar underneath. It has its own switch under Skins > Skinned Windows.
- Group loot rolls: the roll frames stay at Blizzard's spot above the action bars instead of jumping when an alert or another frame at the bottom of the screen appears, and a roll you have already answered no longer flashes back. The spot can be moved in unlock mode (Group Loot Rolls).
- KUI Move: a new Reset All Positions button in the side panel puts every element and every moved window back in its default place and scale, saves the change and reloads the interface.
- Aura Reminders: Custom Auras work again in the downloaded addon. Packaging broke one of the aura engine's library files, which kept the whole engine off and showed a Profiling.xml warning.
- Tooltip: the item or spell icon sits inside the tooltip's top-right corner instead of above it, and the lines beside it keep clear of it. The options preview shows it the same way.
- Tooltip: the panels of the options preview show their border on every side again.
- Skins: opening the Collections window in combat, from a chat link for example, no longer causes a blocked action error. The summon buttons are moved into place once combat ends.
- Buffs and Debuffs: a second row of buffs or debuffs leaves room for the duration text of the row above instead of covering it.
- Buffs and Debuffs: buffs longer than an hour show hours and minutes (1h26m, 1d3h) instead of a rounded-down hour. Weapon enchants too.
- Cooldown Manager: tracked buff bars show their icon on the left by default. Bars still on the old default without an icon get it once.
- Cooldown Manager: a buff bar empties when its buff ends instead of keeping its last fill and timer, and a buff that Blizzard's Cooldown Manager does not track follows its own duration.
- Cooldown Manager: the buff bar options show a live preview of the selected bar, and the Group Grow Direction list shows its choices again.
- Cooldown Manager: a deleted buff bar, or one added to the group, no longer keeps its own entry in unlock mode.

## 6.1.1 (2026-11-13)

- Skins: the loss of control alert gets a KUI skin: a dark band with thin lines above and below in the colour of the effect (red for stuns, purple for fears, blue for silences, green for roots, amber for disarms, or the colour of the locked spell school), the spell's own icon in a KUI border and the KUI font. It has its own switch under Skins > Skinned Windows.
- Party Frames: health and power bars now ease into each new value instead of jumping. A new Smooth Health/Power Bars option, on by default, turns it off per layout.
- Resource Bars: drops in your resource, when you spend it or take damage, now ease too, not only gains.
- Resource Bars: the swing timer moves smoothly at any frame rate.
- Cooldown Manager: the spell lists of each specialisation are no longer lost when you log out.
- Aura Reminders: pasting a string of the full aura editor (!WA or !FA) into Import Auras now switches to the Full Aura Editor and imports it there. The button of the editor you are in is highlighted.
- KUI Move: moving a window no longer causes a Lua error when the game hides the state of the SHIFT or ALT key.

## 6.1.0 (2026-11-11)

- Aura Reminders: auras from Wago saved with a newer version of the aura engine can now be imported. The import window shows a warning instead of refusing them; any setting added in that version is kept but has no effect.
- Aura Reminders: imported auras that use textures, sounds or fonts from the standalone ForeverAuras, WeakAuras or M33kAuras folders now use the copies bundled with KUI, so they no longer stay invisible or silent. Auras that use media from other addons (SharedMedia packs, Details and so on) still need those addons installed.
- Buffs and Debuffs: weapon enchants and poisons now appear right next to your buffs, on their left side, whichever way the buffs grow, so they no longer run off the right edge of the screen. They follow your buffs as these come and go, also in combat, and the main hand is the one next to them.
- Armory: hovering a stat now shows the game's own stat tooltip, as on Blizzard's character panel, with the total and what the stat gives you.
- Aura Reminders: the full aura editor is now based on M33kAuras 5.20.7 (based on WeakAuras, GPL v2), the Retail addon ForeverAuras was forked from, instead of ForeverAuras 1.3.8. Your auras and settings are kept. M33kAuras' automatic copy of a WeakAuras install's settings and its settings wipe command are left out.
- Aura Reminders: displays anchored to another display find it again. Anchors saved by the first 6.1.0 build are converted once.
- Aura Reminders: the aura engine now loads its own copies of the libraries it uses, so other addons' copies of them can no longer break the editor. If the engine still fails to start, a chat message says so and Custom Auras stay off.
- Aura Reminders: the aura editor texts that were still in English are now translated into every language KUI supports.
- Tooltip: new optional lines, each with its own switch and off by default. Items: icon ID, item level, required level, quality, equip slot, binding, vendor price, item count, use effect spell, item set ID, expansion, crafting reagent, and enchant and bonus IDs. Spells: icon ID, rank, range, cooldown, cost, charges, known and passive. Buff and debuff tooltips can show the aura's spell ID and who cast it.
- Tooltip: the options preview now shows the player tooltip, one of your equipped items and one of your spells side by side, and follows every switch on the page. Click it for another item and spell.

## 6.0.10 (2026-11-11)

- Aura Reminders: Custom Auras now includes the complete ForeverAuras 1.3.8 aura engine (derived from WeakAuras, GPL v2), so its full aura editor opens inside the KUI options and you don't need a separate addon. Press Full Aura Editor to open it. The editor is available out of combat only, its controls use KUI's style, and new auras start from KUI's creation gallery.
- Aura Reminders: auras made in the full editor that are anchored to the screen are moved in KUI's Unlock Mode along with every other element. They also count towards the Custom Auras status on the module card.
- Aura Reminders: the full editor keeps its own saved data. Auras from a standalone ForeverAuras or WeakAuras install are not brought in automatically, so move them with the editor's import and export. Your existing KUI auras keep working and still open in their original editor through Existing KUI Auras.
- Aura Reminders: the KUI custom aura editor gets new trigger types: Spell Charges, Spell Usable (optionally only in range of the target), Item (ready, on cooldown or number owned), Health, Power, Casting and Player State (in combat, in a group or raid, solo, resting, mounted, stealthed, flying, has a target, target can be attacked). An aura can now have up to four triggers, with All or Any to decide how they combine, and aura triggers can be limited to your own casts.
- Aura Reminders: KUI custom auras can show text with values (name, stacks, time left, value, maximum, percent, count) where you choose, fill bars by remaining time, stacks or value, show a cooldown swipe, stay on screen greyed out or faded while the trigger is off, and use a different icon spell.
- Aura Reminders: new Rules section for KUI custom auras. Each rule changes the colour, glow, greying or opacity while a condition holds (remaining time, stacks, value, percentage, count, or a trigger being active).
- Aura Reminders: new Animations tab for KUI custom auras. Choose how an aura appears (Fade In, Zoom In), how it behaves while shown (Pulse, Flash, Shake) and how it goes (Fade Out, Shrink).
- Aura Reminders: KUI custom auras can be anchored to another frame by name with their own points and offsets. Groups can wrap onto new lines and sort by remaining time.
- Aura Reminders: KUI custom auras can be loaded by class, specialisation, role, group type and minimum level, and hidden while mounted.
- Aura Reminders: new templates: Cooldown Tracker, Low Health, Resource Bar and Enemy Cast.
- Aura Reminders: the preferred flask and potion dropdowns show your saved choice correctly instead of a blank box. The potion zone dialog, reminder captions, talent tooltips and the "Disabled: requires" notes are now translated.
- Unit Frames: new bar textures drawn for KUI replace the old ones: KUI Satin, Brushed, Rough, Split, Glass, Fade Right, Fade Left, Fade Up, Fade Down, Matte and Sheer. Several old choices were missing their art and showed a flat bar. The new textures are also offered in every status bar texture picker.
- Cooldown Manager: buff bars use the new KUI bar textures, and the Bar Texture dropdown now previews each texture. The glow preview button has new eye icons, which were missing before.
- Unit Frames: when you change target in combat, the target's level number takes the new target's difficulty colour instead of keeping the previous one.
- Unit Frames: the Active Stance bar is no longer pulled away from the player frame after a loading screen.
- Unit Frames: the alternate mana bar now sits inside its frame, with the frame's rim drawn over the fill.
- Buffs and Debuffs: weapon enchant icons now sit outside the buff row, so your buffs no longer shift when an enchant appears or runs out.
- Nameplates: friendly and enemy player nameplates now show out to the same 60-yard distance as other nameplates.
- Nameplates: the range number now sits just past the right end of the health bar, so it no longer covers the name.
- Nameplates: the pending DoT damage marker is more reliable. It puts casts made through focus, mouseover and soft targeting on the right mob, handles misses and immunities better, learns tick sizes more accurately and no longer shows on a mob that has just died.
- Loot rolls: roll frames no longer jump between two positions while rolls are added or removed, and a roll no longer appears outside the stack on top of another roll.
- Armory: the close and settings corner buttons keep their glyph when Skins is enabled, drawn above the button art.
- Spell History: the icon frame styles (backdrop, frame art and shaped borders) now show their art.
- Skins: profession entries now get their dark backdrop and border.
- Options: the Window Scale slider stops at the largest size that fits your screen, so every step changes something. The window now scales around the slider, the thin slider is easier to grab, and closing the window mid-drag no longer leaves the slider stuck.
- Options: slider values are saved rounded to their step, and the Default text only appears when the setting has a real default. Opening a page or a bar editor no longer saves its values back.
- Options: texture dropdowns show their previews in every language, and background dropdowns preview backgrounds.
- Profiles: the module grid shows an icon for every module.
- Translations: many previously English-only texts are now translated, including Nameplates section headers and markers, Unit Frames, Armory, Profiles and Compatibility labels, Cast Bar, Chat, Minimap and Cooldown Manager texts, and Enhanced Friend List messages. Its search icon, which was missing, is back.
- Translations: Portuguese (Portugal) and Mexican Spanish no longer fall back to English in Aura Reminders and the installer.

Configuration changes after updating: Unit Frames and Cooldown Manager buff bars that used an old bar texture switch to its new KUI version automatically, including profiles you switch to, copy or import and saved Visual Style slots. Auras made in the full aura editor are stored separately from your existing KUI custom auras, which are left as they were.

## 6.0.9 (2026-11-09)

- Aura Reminders: Custom Auras is now a full aura creator. Its editor has Trigger, Display, Conditions, Load and Sound tabs, a live preview that draws the aura as in game, and a badge on each section that tells you whether it works in combat, only out of combat or not on this client.
- Aura Reminders: new stack options for custom auras. Show the aura only at, above or below a number of stacks, fill a bar by stacks up to a maximum you choose, and change its colour and glow from a set number of stacks. New Stacking Buff template.
- Aura Reminders: custom auras and their groups can be moved in Unlock Mode, and the Move on Screen button opens it straight away.
- Aura Reminders: the Custom Auras page is easier to use, with a New Aura, Import and Move on Screen bar, large rows with on/off and delete buttons, a search by name, group or spell ID, Undo Delete, and a template gallery that includes major cooldowns of your class.
- Aura Reminders: new icons for the section cards and the Custom Auras templates, tinted in your accent colour. Class Upkeep and Consumable Loadout no longer show question marks.
- Aura Reminders: sliders in the custom aura options can be dragged smoothly instead of stopping after each step.
- Experience Bar: new style cards for KUI, Forever, Retail and Classic, each with its own art, and the bar follows your Visual Style. Changing the style asks for a reload.
- Experience Bar: new Text Position option (above, below or inside the bar) and Bar Animation switch. Rested experience shows in purple in the Forever and Retail styles.
- Experience Bar: by default it sits just above Action Bars 2 and 3, and it can still be moved in Unlock Mode.
- Nameplates: the distance text is a larger number above the right end of the bar, in the Russo One font. Pick another font with the new Distance Font option. By default the distance shows up to 100 yards.
- Nameplates: in the Forever and Retail styles, the target highlight on plates that just appeared shows the style's own frame glow instead of a blue border.
- Nameplates: in the Forever and Retail styles, the edge of the frame is no longer covered by the health fill at some interface scales.
- Bags: the search works in combat. Items that do not match are dimmed until combat ends, and then the bag is filtered.
- Bags: the loot window, the stack splitter and confirmation dialogs open on top of the bags instead of behind them, so items you right-click open as expected.
- Bags: new items keep their highlight until you hover them or close the bags, the Recent category shows only the new stack, and quest starters are sorted with quest items.
- Bags: Alt+click pins an item again, the keyring and the bag slot buttons open their bags, and a locked item is greyed out without redrawing the bag.
- Bags: the bag keeps updating in combat when you loot, and dropping an item on the empty space always goes to the first free slot.
- Damage Meter: it no longer covers the bags. While Blizzard's bags or the KUI bags are open, the meters sit below them.
- Group loot: the Need, Greed and Pass window no longer blinks or briefly vanishes when another roll or alert appears.
- Armory: the settings and close buttons in the top-right corner use new KUI icons and sit inside the window.
- Damage Meter: the Forever style is darker.
- Unit Frames: the class portrait is used only for players. NPCs keep their normal portrait.
- Options: live previews sit on the dark background instead of a greyish one.
- Fixed: an error when opening the Custom Auras page.

Configuration changes after updating: the Experience Bar text moves above the bar once. Other saved settings are kept.

## 6.0.8 (2026-11-08)

- Nameplates: the Forever, Retail and Classic styles use Blizzard's own nameplate art from the game. Forever has its metal frame, the level box on the right and the yellow target glow around both. Retail has its frame and selection glow. Classic has its gold border with the level in the pill on the right.
- Nameplates: the frames stretch the way the game's do, so the metal edge, rounded corners and glow keep their shape at any bar width or height.
- Nameplates: in the Forever and Retail styles, plates that are not your target are darkened, as in the game.
- Nameplates: the Forever, Retail and Classic styles show Blizzard's gold elite dragon on the left of the bar. KUI Style keeps its own dragon.
- Nameplates: the Retail style uses the game's own bar colours, and the empty part of the bar shows the dark inside of the frame instead of a red-brown fill. The white level stays at the start of the bar.
- Nameplates: in the Classic style the level is centred in the border's pill.
- Nameplates: Combo Point Shape has four choices: Retail, Forever, KUI and Pips. Retail and Forever use the game's own combo points (silver socket or bronze socket with a red gem), and KUI has a new look whose gem takes your combo point colour. The Forever and Retail styles use their own by default, and KUI Style keeps Pips.
- Nameplates and Unit Frames: the level of enemies takes its difficulty colour (grey, green, yellow, orange or red) in every Visual Style, and it is on by default. Friendly units keep the style's level colour. Turn it off with Color Enemy Level by Difficulty, now in the nameplate level options too. The Unit Frames option is no longer limited to KUI Style.
- Unit Frames: the combo points under the player frame offer Retail and Forever as separate choices, next to Classic, using the game's own sockets. The Retail style now shows them under the player frame by default, as Forever and Classic already did, and the Resource Bars stop showing combo points while they are there.
- Skins: purchase dialogs with a price, such as buying a bank slot, show the amount with its gold, silver and copper coins instead of an empty box.

Settings: the default bar sizes of each style are unchanged. If you picked combo points under the player frame yourself, that choice is kept.

## 6.0.7 (2026-11-07)

- Nameplates: new Color Enemies by Level option in the Colors card. Enemies you can attack take the colour of their level compared to yours, like the level on the unit frames: grey far below you, then green, yellow, orange and red. It is off by default.
- Armory: the Stamina label lines up with the other stats instead of sitting in the middle.
- Auction House: the Buy, Buyout, Bid and Post buttons and the purchase dialog buttons show their full skin instead of only their text.
- Unit Frames: the raid marker stays on top of the portrait rings, combo points and aggro glow.
- Unit Frames: in KUI Style the level number of enemies takes its difficulty colour (grey, green, yellow, orange or red), as on the Blizzard frames. Turn it off with Color Enemy Level by Difficulty in the Unit Frames options.
- Translations: texts that showed in the wrong language are fixed, such as Chinese text in German, Spanish and English options, Portuguese text in the Cooldown Manager buff bar options and Health shown in Chinese. Bag sections, Hide offline and Macros are now translated.

## 6.0.6 (2026-11-07)

- Stance Bar: new optional bar on the player frame, turned on in Unit Frames. Each stance, form or aura is a button: click it to switch, also in combat. The active one is lit in your accent colour and cooldowns show on the buttons. Choose its size, spacing and position or move it in Unlock Mode; the Active Stance Only style shows just the current one.
- Friend List: new look in the Skins material, with a class colour bar, the class icon with your friend's status, flat cards and a sunken tab bar.
- Friend List: new Hide offline checkbox next to the search box.
- Friend List: the close button works in combat, and opening the list in combat no longer fails.
- Friend List: friends playing WoW Forever show the Forever icon.
- Skins: every skinned window shares the same darkness. Spellbook, Professions, Achievements, Adventure Guide and Group Finder are no longer lighter than the rest, and skinned windows are darker overall.
- Options window: keeps its intended darkness when the game's Gamma setting is raised.
- Nameplates: the raid marker sits centred above the name, and debuffs move up to make room for it.
- Nameplates: raid markers show on allied NPCs, and on friendly players shown by name only they sit just above the name.
- Nameplates: in a group, the quest sign shows again on mobs you need for your own quests.
- Nameplates: plates show at the farthest distance the game allows.
- Cooldown Manager: the Buffs bar no longer gets wide gaps between icons after taking the Blizzard layout.
- Target frame: the rare and elite ring follows a target change in combat, and the raid marker is drawn above it.
- Mail: attachment borders show each item's own quality instead of colours left over from other mails.

Configuration changes after updating:

- Nameplates: a raid marker set to the top-right corner moves to the centre above the name once.
- Cooldown Manager: icon gaps wider than half an icon that came from the Blizzard layout go back to 2 px once.

## 6.0.5 (2026-11-06)

- Raid Check: new look, with a status badge, icon columns that show each consumable's own icon, and flat report buttons.
- Cooldown Manager: Utility no longer leaves a gap under Cooldowns when it shows a single spell.
- Target frame: in KUI Style the cast bar sits right under the frame and the debuffs under the cast bar, so a cast no longer covers them.
- Nameplates: friendly plates that show only the name now show raid markers, and the quest sign over friendly NPCs sits above their name.
- Nameplates: in the Forever and Classic styles, side auras sit beside the level box instead of under it.
- Party Frames: party members show their mana bar by default, and their resources also show in restricted content.
- Portraits: druid form portraits face inward on the player and target frames.
- Unit Frames: the druid mana bar shown in forms fits the frame straight away instead of after a reload.
- Merchant: the page arrows show again.
- Guild window: the chat input box no longer covers the member list.
- World Map: the close and maximize buttons sit inside the window.
- Fixed: an error on the target of target portrait when shapeshifting.
- Fixed: an error when targeting some enemy NPCs.

Configuration changes after updating:

- Party Frames: the party mana bar is turned on once for every profile.

## 6.0.4 (2026-11-04)

- Kick Tracker: a new way to tell who interrupted. It reads the game's own damage meter and only marks a kick when it is sure who made it, and crowd control on a whole pack no longer counts as a kick. Its text is larger by default.
- Translations: button and option labels fit in every language. Long labels shrink slightly or are shortened with the full text in the tooltip, switch labels can use two lines, and buttons widen for longer languages.
- Translations: Korean, Chinese and Russian nameplates use a font that can draw their script, and Chat, Teleport Menu, Party Frames group headers, new custom Aura Reminders and chat messages are now translated.
- Chat: changing an option no longer reloads the history and drops unsaved lines, and the General tab no longer keeps a whisper or guild target.
- Chat: whispers from your own realm are matched correctly, repeated messages are no longer hidden as duplicates, the window keeps its position at any scale, and with fading off it stays fully visible. Closing a tab keeps the right tab selected.
- Cooldown Manager: on a new profile, Utility docks under Cooldowns and Buffs above the cast bar. The installer's Import button puts every bar back in its layout position, and the spell search works with any character.
- Installer: the Cooldown Manager preview shows sample spells for low-level characters, and its cast bar fill shows correctly.
- Objective Tracker: in Edit Mode its selection box fits the visible tracker instead of its full height.
- Minimap: in its default corner it moves down just enough to keep the zone name on screen.
- Skins: tabs get a new border lit in your accent colour, and bottom tabs are no longer cut by the window border.
- Skins: Spellbook, Professions and Adventure Guide pages are darker with readable text, empty scrollbars in the Adventure Guide are hidden, Group Finder categories lose their blue halo and the group leader keeps a single icon.
- Layout: new default Buffs and Debuffs positions at 1080p, 1440p and 4K.
- Fixed: the character title no longer shows again over the Armory.
- Fixed: class resource bars no longer cause errors in the buff frame.
- Fixed: changing the Armory colour updates its style straight away.

Configuration changes after updating:

- Kick Tracker: text sizes saved in your profile are raised by 2 once, to match the new default.

## 6.0.3 (2026-11-02)

- Large restructuring and refactor: Unit Frames, Nameplates, Aura Reminders, Cooldown Manager, Skins, Profiles and the shared aura code were reorganised and rewritten module by module, with cleaner code and many old leftovers removed.
- Nameplates options: new layout. Visual cards with their own icons replace the tabs, the live preview sits above every section at a larger size, and each card shows only its own options, with the duplicates gone.
- Nameplates: the preview and the plates show each class resource with the game's own art, centred under the plate. Pips default to the colour of each resource.
- Nameplates: in the Friendly card the preview dims the health bar when it is off or set to show names only.
- Aura Reminders options: new layout with section cards, a preview column and a settings column, plus a new zone dialog and error flash.
- Resource Bars: the anchor block was redesigned, and a resource the unit frame already draws is no longer repeated.
- Resource Bars: Soul Fragments for Vengeance, Dark Heart for Devourer, Tip of the Spear for Survival and Whirlwind for Fury. Runes and Essence now refill pip by pip.
- Skins: new surface material across windows, and buttons no longer keep their default red look in the Group Finder, AddOn List, Auction House and other windows.
- Game Menu: new frame styles, crests and button styles, with position, order and visibility options for the KUI buttons and a live preview.
- Enhancements: new Battleground History, recording each battleground with filters and a summary.
- Layout: Focus, Pet, Target of Target and the combat timers follow their unit frames, and frames around Player and Target keep their gaps when the scale changes. Default positions now depend on client and resolution.
- Art: new portrait, nameplate, bar, cursor and category icons, plus lighter packaging with unused fonts and textures removed.
- Fixed: Enhancement Shaman nameplates no longer raise an error, and Maelstrom Weapon shows its stacks.
- Fixed: the Experience Bar appears in Unlock Mode and can be moved.
- Fixed: a damaged profile string can no longer freeze the game on import. It now shows a clear message.
- Fixed: nameplates follow a specialization change without a reload, and the resource of the previous spec no longer stays.
- Fixed: nameplate settings for Friendly text now show the real values instead of blanks.
- Fixed: Blizzard plates come back correctly when a unit stops being hostile.
- Fixed: pips reappear when a resource returns to its higher maximum, and the Stagger bar handles missing values.
- Fixed: Aura Reminders no longer hides your reminder because of the same buff from another player, repeated talents now give feedback, and dragging icons during a refresh no longer breaks their order.
- Fixed: debug messages in chat are gone, and the Group Finder leader role icon shows again.
- Translations: new option labels and messages translated into every language, and garbled characters in the changelog window repaired.

Configuration changes after updating:

- Aura Reminders: a preferred flask saved by an older version returns to Last Used. Choose it again if you want a fixed one.
- Cooldown Manager: a bar anchored with an older saved value returns to its saved position.

If you update from 6.0.2 or lower, restoring defaults from the installer is recommended.

## 6.0.2 (2026-10-28)

- Action Bars: new Glows tab. Pick the style, colour and opacity of proc glows, of spells that glow while usable (such as Execute or Overpower) and of spells coming off cooldown, and give any spell its own look.
- Teleport Menu: new Atlas look, a map table in your accent colour with every teleport as a waypoint.
- Enhancements: new Arena History. It records every finished arena (rated, Solo Shuffle and skirmish) with both teams, damage, healing and rating changes. Open it with /ktarenas.
- Objective Tracker: a small arrow above the tracker hides or shows it entirely, background included.
- Profiles: right-click a profile card for a menu (load, assign to spec, change icon, export, save as, delete), and the new profile card creates a clean profile with the KUI defaults.
- Installer: the Unit Frames, Party Frames and Damage Meter previews show the Visual Style you pick and always fit their box. Party Frames gets the same style row as Unit Frames.
- Test buttons: new animated look in your accent colour, the same in every language.
- Options: section cards no longer touch or overlap, and the pinned live preview no longer shows the options scrolling behind it.
- Cooldown Manager: the KUI Tracker docks to the player frame as it is drawn, keeping room for the cast bar, the druid mana bar and combo points. Bars docked together keep their anchor when dragged in Unlock Mode.
- Translations: installer texts reviewed in every language, more option labels translated, and line breaks show correctly.
