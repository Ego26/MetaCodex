# Changelog

All notable changes to MetaCodex. German version: `CHANGELOG.de.md`.

## [Unreleased]

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
