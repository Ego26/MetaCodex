# Changelog

All notable changes to MetaCodex. German version: `CHANGELOG.de.md`.

## [Unreleased]

### Added

- **Priorities** as the first section under Gear: what is missing on this
  character - consumables against the bags, enchants and gems against the
  equipment - in one list, ordered by the measured share of the best
  players who wear it. Deliberately not a damage estimate; the hint above
  the list says what the number counts. The reminder before the pull takes
  its order from the same ranking.

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
