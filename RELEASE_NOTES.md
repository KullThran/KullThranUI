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
