# Changelog

All notable changes to MetaCodex. German version: `CHANGELOG.de.md`.

## [Unreleased]

## [1.1.10] - 2026-10-01

### Added

- **The builds at the talent frame.** Opening it is the moment of
  choosing a build; until now the way there was open the addon, find the
  build, copy the string, go back, Import, paste. A button at the frame
  opens the list, a click loads the build - through the same method
  Blizzard's own Import dialog uses. In combat it says so, and when it
  fails the string lands in the copy box.
- The button is draggable and remembers where: we cannot know which
  corner of the talent frame is free on someone else's screen.
- The activity picker there is grouped like the window - M+, Raid, PvP,
  then the samples, then dungeons or bosses.
- **"All levels"** in the keystone picker: a state of its own, not the
  absence of a choice. It turns the comparison off, so nothing is dimmed.

### Changed

- **The menu is grouped by the question a section answers**, not by the
  kind of its data: Overview, Talents, Gear, Before you go in, Settings.
  Enchants, consumables and the reminder sat under Gear because they
  involve items - they all answer "am I ready?".
- **"Gear" is now called "Popular"** - that is what it measures: how
  many of the best wear a piece. And "Sources" says where it drops.
- Embellishments moved onto the crafted page. An embellishment is not an
  item of its own but an addition to a crafted one; two menu entries
  meant making the same decision in two places.

### Fixed

- **Every second row looked greyed out.** Rows were 46.8 pixels high -
  a fraction - so every other edge landed on half a screen pixel and the
  client spread the fill across two. It was never a colour, it was an
  edge. Rows now sit on whole screen pixels, at any UI scale.
- **"Enchants" had lost half its name.** Cleaning up duplicate language
  keys on 28 September kept the wrong half of two - it reads "Enchants &
  Gems" again, and two tests now know the text.
- **The stat rows looked like an icon was missing.** The 26 pixels were
  for the rank that used to sit there and has long moved right. There
  are no icons for secondary stats - all 19,643 atlas elements were
  searched.

## [1.1.9] - 2026-10-01

### Added

- Upgrades now compares against what you wear. A piece worn by 43 % of
  the best is worth nothing when twenty item levels more hang in that
  slot already, so it steps back and stops counting - and the row says
  "1 you already beat". It stays visible: a set piece or a piece with an
  equip effect can be worth having a rank lower, and that trade-off is
  the player's.
- Item levels in the keystone picker carry the colour of what they mean
  this season: from Champion, from Hero, from Mythic, and above the
  highest rank a boss still drops, where only upgrading gets you. The
  boundaries are read off the season's own tracks, not written down.

### Fixed

- **The keystone picker put every level on the wrong key** - "311 (+6)"
  where "311 (+10)" is right. The client only answers with the vault
  level this season; the game data agrees, EndOfRunRewardLevel is 0 in
  all thirty rows of the season. Both mappings are now kept here, and
  they map a key to TRACK AND RANK rather than to a number: the same
  level exists in two tracks, and labelling by the number put "+10" in
  two places. The level itself still comes from the client, computed
  from that rank's bonus id.
- **"The way the best play" showed the base item level** - 28 under a
  ring the best wear at 311. The entry is gone; without a choice, what a
  +10 drops applies. The gear list had the same gap: its row said "level
  311" while its tooltip said 28.

## [1.1.8] - 2026-09-30

### Added

- **Upgrades**, a new entry under Gear: one row per instance, one box
  per piece the best of your spec wear, sorted by what is still open for
  you. The gear list answers "what goes on the head"; this one answers
  "where do I go for it".
- Dungeons first, raids below. The raid drops more than all eight
  dungeons together, and a list it always leads is not an answer.
- What drops in no instance gets its own rows - crafted, set pieces,
  PvP, auction house, no known source. A count alone ("8 crafted") is
  true and useless: it does not say which eight.
- Five pickers: slot, highlight, source, order and item level. The order
  is a question, not a verdict - "most still open" and "best single
  piece" are both sensible, so it is the player who picks.
- Highlighting by secondary stats, with a combination mode: crit AND
  mastery. An item the client does not know yet is neither highlighted
  nor dimmed - guessing there is expensive, because the stats are the
  reason for looking.
- Right-click a box to watch it (gold border and a star) or ignore it.
  Ignored stays visible, crossed out, and stops counting; the star never
  changes the order, because a preference must not move a measured
  number.

### Fixed

- **This expansion's crafted gear stood under "no known source".** It
  has no journal entry, no recipe spell and murlok only sometimes marks
  it - but the game data flags it, and 350 pieces carry that flag while
  not one of them appears in the adventure journal.
- **A helmet with an "Equip:" effect showed the effect nowhere.** The
  effect hangs on a bonus list, not on the item, and the link we build
  for the chosen item level dropped it. Nine items have an unambiguous
  effect list and carry it now; where it would need guessing, nothing is
  claimed.
- Rows are reused in this window, and the new view left three things on
  them: its boxes, the tooltip name of its instance, and a narrow text
  column. All three turned up in the gear list afterwards. They are
  cleared in the one place every row passes through.

### Changed

- UI.Refresh went from 54 to 40 upvalues. WoW allows 60, and beyond that
  the file stops loading without an error - the addon is simply gone.

## [1.1.7] - 2026-09-30

### Added

- A shopping list beside the auction house. It opens with the auction
  house and closes with it, lists what is still missing with icon, bar
  and "14 of 20", and a click on a row searches for that item.
  Shift-click puts its link in the chat.
- The list is docked to the outer right edge of the auction house, not
  placed inside it: that edge survives ElvUI and anything else that
  rebuilds the window.
- A switch for the list under Reminder. It hangs off the reminders: who
  turns those off wants quiet, and a window that opens anyway would be
  the opposite.

### Changed

- The chat line at the auction house is gone. It said in one sentence
  what the list beside the window now shows item by item.
- The buttons for Auctionator only appear when Auctionator is installed.
  Greyed out means "not right now" - without Auctionator it is "never",
  and a grey button then looks like a broken one.
- "Search" says in a tooltip why it is grey, and "Create list" is greyed
  out as well while the auction house is closed.
- Creating a list switches to Auctionator's shopping tab first and fills
  it afterwards. Auctionator's own event only reaches a tab that has
  been opened once, so the first click used to look like it did nothing.
- The list follows what you change: ignoring an item, a new target
  quantity or a purchase is visible at once, without walking away from
  the auction house and back.

### Fixed

- Ignored items stayed on the shopping list and were handed to
  Auctionator, although the window had stopped showing them. The rule
  now lives in one place instead of three.
- The list beside the auction house knew only half of what was missing.
  Consumables are counted in one place, enchants and gems in another; it
  asked only the second and could stand empty while the window listed
  five things.
- A death knight was told a rune was already on his weapon when a
  different one was on it. Any rune counted as done; now the recommended
  one does, and any rune only where nothing is recommended.
- A crafting item was shown in the wrong quality tier. Where a name
  appeared twice, the tier read last won instead of the most used one -
  in the current data 3 items against 109.
- A long item name wrapped onto the progress bar below it. Names are cut
  with an ellipsis now and shown in full on hover.
- The tooltip of a greyed-out button stayed invisible in the game though
  it was there in the test: a disabled button receives no mouse events
  at all unless it is told to.

## [1.1.6] - 2026-09-29

### Added

- The Omnium Folio, as a sub-entry under Talents: five rows, thirteen
  runes, per spec, per activity and per dungeon.
- Each row says how many players it was measured on. A rune is found by
  what it does in the fight, so the sample behind a row is smaller than
  the spec's, and hiding that would invite the wrong comparison.
- Row three holds a single rune and stands there without a percentage:
  there is nothing to choose.
- Residual Energy cannot be seen at all, so its number is what the other
  two in row five leave over. The row says "worked out, not seen" and
  never takes the accent colour - the smallest of the three carries the
  uncertainty rather than the largest.
- The weapon buff a class puts on itself is measured and shown, so a
  shaman's Flametongue and a rogue's poison appear where an oil would.
- Anything under "Other" in the reminder carries its own amount. Drums, a
  repair hammer and a Vantus rune are not one decision, and one quantity
  for all three was the wrong shape.
- Items nobody measured can be added to the reminder by ID, with a live
  preview and the game's own tooltip on hover.
- An ignore list: a row you do not want to hear about again goes away
  through a menu, and comes back the same way.
- A daily run can be started as a sample - one page per ranking, two
  encounters. Fifteen minutes instead of five and a half hours, for
  checking a change to the collector. Such a run publishes nothing: its
  numbers rest on dozens of players, not thousands.

### Changed

- The daily run starts at 00:05 UTC instead of 04:30, so the fresh tables
  are on CurseForge before breakfast rather than after lunch. The old time
  waited for a daily leaderboard reset that nothing here depends on.
- Missing enchants and gems are named, not counted. "Two gems missing"
  does not say which two.
- A socket holding a gem is no longer called empty. Wearing haste and
  versatility on purpose is a decision, not an omission.

### Fixed

- A shaman was told to buy oil. The line meant to suppress it could never
  work: in Lua `cond and nil or x` always yields `x`, so the branch that
  looked right did nothing.
- The share next to a talent build said whose fifty percent it is.
- Percentages that divide one sample add up to a hundred. In each folio
  row every player picks exactly one rune, so the numbers share a sample;
  rounded one at a time they came to 99 or 101. Across 790 rows of live
  data every one now lands on exactly 100.
- The stat rows no longer overlap the bar: a text without a width runs as
  far as its text is long, and the bar sits vertically straight across it.
- The stat rows say which percentage they mean - this stat's rating
  against the sum of the four secondary ratings, which is not the effect
  the character sheet shows.
- The raid difficulties got their boss picker back, and the raid's ninth
  boss with it.

### Changed (interface)

- The scrollbar belongs to this window: a slim rail in the class accent,
  draggable, and a click on the track jumps there. It appears only when
  there is something to scroll - Blizzard's arrows used to sit on short
  pages looking like there was more to find.
- The folio rows no longer repeat their own percentage in words, and a
  row without a second line centres its name.

## [1.1.5] - 2026-09-28

### Added

- The crafting tier is drawn at the icon - the mark the bags draw, in the
  same corner: on consumables, on crafted gear and on the embellishment
  reagents. It is read from the game's own quality tables, not guessed
  from how many tiers of the same ware exist.
- Stat targets say what they are: the median of the measured players, one
  stat at a time, with the middle half of the measured field behind each
  number. Explicitly not a BiS list.
- Rings and trinkets show two rows, because two are worn, and the heading
  says how many slots it stands for.

### Fixed

- Two of the same embellishment were counted as one. They are a choice of
  their own, and for many specs the most common one. The row names it once
  with "x2" and carries both tooltips.
- An embellishment was named after the lowest crafting tier of its
  reagent: the reagent was looked up by name, and the first hit won.
- Shares no longer round into a claim. A hundred percent appears only when
  it really is all of them, zero only when it really is none - the rings
  read 100, 1 and 0 percent, which is 101 and cannot be.
- The top pick is highlighted by rank, not from fifty percent up. A
  trinket worn by 48 percent is the most worn one just as much as one worn
  by 51.
- "Already on it" for gems is answered by the gems in the gear you are
  wearing, and follows when you swap a piece.
- "Pick from my bags" offers what is in the bags instead of what is in the
  catalog: an older rune was missing from the list although it lay right
  there. GetItemInfoInstant returns seven values, and the fifth is the
  icon, not the class.
- German headings kept a lowercase umlaut in the middle of capitals -
  string.upper knows only a to z - and the slot count read "1 slot(s)".

## [1.1.4] - 2026-09-28

### Fixed

- The minimap button sits on the rim of the minimap again, whatever size
  and shape it has - it was following a hardcoded radius.
- Korean and Chinese names are drawn with a font that can draw them, and
  the font is given back when a line or heading is reused.
- Tier set lists only this season's class set: not last season's, not the
  PvP armour, not a ring from a jewellery set.

## [1.1.3] - 2026-09-27

### Fixed

- v1.1.2 was packed with the catalog of the night instead of its own:
  the build died on a missing directory and the step swallowed the error.

## [1.1.2] - 2026-09-27

### Added

- The origin picker shows **every boss** of a raid, not only the ones
  something in the current list came from. Picking one nobody wears
  anything from says so in one line instead of showing an empty window.

### Fixed

- The chosen gear slot was deleted by the generic category check, which
  kept its pick under the same key. Picking Trinkets showed the
  trinkets once; the next click showed everything again.
- Old content stays out of Dungeons and Raids: Firelands ran as
  Timewalking last week and someone still wears a piece from it, so the
  source is real - but it belongs under Other, not under Raids.

## [1.1.1] - 2026-09-26

### Fixed

- A raid that nobody has uploaded a report from was sorted into "Other":
  the kind of an instance came from the measurements. It comes from the
  catalog now, for all 213 instances, read off the map behind them.
- A group with a single entry lost its heading, so the one current raid
  stood bare between "Dungeons" and "Other".

### Added

- A raid opens into its bosses in the origin picker - only those
  something in the list actually came from.

## [1.1.0] - 2026-09-26

### Added

- **Tier set**, **Crafted** and **Embellishments** as sections of their
  own, counted from the profiles already fetched: which set pieces are
  worn and how many, which crafted pieces with the stat pair their wearers
  chose, and which two embellishments are worn together.
- Item level and stat pickers for crafted gear, both built from the levels
  and choices actually measured - a crafted piece is not upgraded with a
  keystone, so the dungeon reward table says nothing about it.
- Stat rankings on every item, everywhere, including crafted pieces and
  the comparison tooltip.

### Changed

- The gear list folds to one line per slot; a click opens the
  alternatives. Ninety lines were a sausage, not a list.
- The source picker is grouped into dungeons, raids and other, and a whole
  group can be chosen at once.
- One place decides text size and colour (`Style.role`), so titles no
  longer differ between sections.

### Fixed

- Crafted items showed "random stat 1 / 2" instead of their stats: the
  link is now built from the full measured bonus list, per item level.
- A row with two embellishments shows both tooltips.
- The player view closes when the activity or the spec changes.
- Verified raid talent strings were overwritten by M+ ones, because eight
  per-boss files all claimed the mode "raid".

## [1.0.0] - 2026-09-24

### Added

- **Talents** for every activity: the most common build with a ready-made
  import string, up to six alternatives shown as *which talent instead of
  which*, the contested talents, PvP talents in their own group. Per
  dungeon in M+, per boss in raids. Every string comes from a real player's
  client; raid and PvP strings are verified against the logged fight or the
  murlok heatmap before they count as a build.
- **Gear** per slot with share, item level, highest key, set/crafted marks
  and drop source (boss and instance, PvP vendor, or "not an instance
  drop"). Keystone picker by upgrade track (Champion / Hero / Great Vault)
  like KeystoneLoot; tooltips show the item on the chosen track.
- **Stat targets** as measured medians from real fights, with your own
  values as a second bar.
- **Top players** per spec and activity, clickable: profile with talent
  string, address and full gear in a third load-on-demand addon.
- **Consumables**, grouped by kind — flask, food, combat potion, healing
  potion, weapon buffs, runes — with share, highest key, stock and target.
- **Reminder** tab: stand per consumable kind, open enchants and gems, the
  settings (on entering, at the auction house, threshold). The chat line on
  entering now also counts open enchants.
- **Ten activities, three platforms:** M+ high keys and +7–21, raid on three
  difficulties, 2v2, 3v3, Solo Shuffle, RBG, Blitz; raider.io, murlok.io,
  Warcraft Logs, individually or combined.
- **One rule for the window:** nothing is shown that does not exist —
  sections, activities and platforms without data are hidden.
- **Shift-click** links an item into chat or the auction house search;
  Ctrl-click opens the dressing room.
- Window is resizable and scalable (`/mc scale`); position and size are
  remembered.
- Shopping lists per section (enchants, consumables, reminder), with
  quantities, handed to Auctionator. Only lists prefixed `MetaCodex:` are
  ever touched.
- Catalog from the client's DB2 tables via wago.tools: enchants, gems,
  consumable kinds, upgrade tracks, drop sources, PvP vendor origins,
  talent names.
- Daily data run as a GitHub Action; the finished package is attached to
  the release `nightly`. Locally `tools/schedule.ps1` registers the same
  run as a Windows task.
- Interface in English and German, switchable via `/mc lang`; correct on
  any client language because only IDs are stored.
- `/mc probe` self-test with a copyable report.
