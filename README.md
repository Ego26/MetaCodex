![MetaCodex](assets/banner-1696-en.png)

# MetaCodex

**From real fights, not from guides.** Talent builds with import strings,
gear with drop sources, enchants, gems, consumables, stat targets and the
top players per spec — for Mythic+, raid and every PvP bracket. Measured
daily from raider.io, murlok.io and Warcraft Logs, never copied from a
guide. Reads your gear and hands the missing pieces to Auctionator.

    /mc

*[Deutsche Fassung](README.de.md) · [Features](FEATURES.md) ·
[Changelog](CHANGELOG.md)*

---

## Install

Download the latest package from the release
[**nightly**](https://github.com/Ego26/MetaCodex/releases/tag/nightly) and
unpack it into `Interface/AddOns`. It is four folders: `MetaCodex` and the
three data addons `MetaCodex_Data`, `MetaCodex_Dungeons`,
`MetaCodex_Players`, which load only when needed.
[Auctionator](https://www.curseforge.com/wow/addons/auctionator) is
optional — without it the lists still show, only the handover is missing.

## What it shows

| Tab | |
|---|---|
| **Guides & Rotation** | Links to the written guides for the spec |
| **Stat targets** | Measured medians of the best, with your own values as a second bar |
| **Talents** | The most common build with import string, alternatives as *X instead of Y*, contested talents — per dungeon in M+, per boss in raids |
| **Top players** | Who is at the top, clickable: talent build with import string and full gear |
| **Gear** | Five per slot with drop source; tooltips on the keystone level you pick |
| **Enchants & Gems** | Against your equipped gear: what is still open |
| **Consumables** | Grouped by kind, with share, highest key, stock and target |
| **Reminder** | What is checked before you go in, and the settings for it |

Ten activities, four platforms, all forty specs. Nothing is shown that no
platform can answer: sections, activities and platforms without data are
hidden. [FEATURES.md](FEATURES.md) has the whole picture.

## Language

**English is the default, German is the addition.** The interface has
`enUS` as its base locale and `deDE` as an override, so a German client
gets German without being asked and `/mc lang de|en|auto` overrides even
that. The same order applies to everything around the addon: this readme,
the changelog and the feature page are English first with a `.de`
counterpart. Only item, spell and encounter IDs are stored, so names and
icons are right on any client language.

## Layout

```
Core/Init.lua          namespace, constants, activities and their groups
Core/Locale.lua        L[...] with enUS as the base
Core/Style.lua         colours, spacing, fonts - the one visual language
Core/Compat.lua        every call to the outside, guarded once
Core/Data.lua          loads the data addons on demand
Core/Catalog.lua       access to the catalog - the only file knowing its format
Core/Recommend.lua     access to the recommendations: modes, sources, merging
Core/Profile.lua       SavedVariables: choices, window, targets
Core/Gear.lua          equipped gear: empty sockets, missing enchants
Core/List.lua          wanted minus owned, for one spec or several
Core/Auctionator.lua   the adapter - the ONLY file that knows Auctionator
Core/Guides.lua        the guide links
Core/UI.lua            the window
Core/Remind.lua        reminders on entering and at the auction house
Core/Probe.lua         /mc probe
Core/Slash.lua         /mc
Core/Boot.lua          events

Locales/               enUS.lua, deDE.lua
Tests/                 smoke and logic tests in a real Lua VM (fengari)

tools/build-catalog.js         game tables -> MetaCodex_Data/Catalog.lua
tools/collect-raiderio.js      M+: gear, enchants, gems, talent strings
tools/collect-murlok.js        PvP and M+: shares, talents, top players
tools/collect-wcl.js           Warcraft Logs: raids and consumables
tools/collect-profiles.js      raider.io profiles of the top players, verified
tools/collect-bnet.js          Battle.net: PvP leaderboards, loadouts, PvP talents, gear
tools/build-recommendations.js everything -> the three data addons
tools/collect-all.js           the daily run, in order
tools/package.sh               the zip for a release
tools/sync.ps1                 repo -> AddOns folder
tools/schedule.ps1             the daily run as a Windows task
```

## Data

The data are **not in git**. They are 60 MB that change every night; a
year of that would be gigabytes of history for nothing. Instead the
GitHub Action `Daily data` runs every night, collects from raider.io,
murlok.io and Warcraft Logs, runs the tests, packs the four addon folders
and attaches the zip to the rolling release
[**nightly**](https://github.com/Ego26/MetaCodex/releases/tag/nightly).

To build the data yourself:

```bash
node tools/collect-all.js .        # everything, in the right order (~1-2 h)
node tools/build-catalog.js .      # only the catalog from the game tables
```

Warcraft Logs needs credentials: `tools/wcl-credentials.json` (see the
`.example`) or the environment variables `WCL_CLIENT_ID` and
`WCL_CLIENT_SECRET`. The Action reads them from the repository secrets.
Battle.net likewise: `tools/bnet-credentials.json` or `BNET_CLIENT_ID` and
`BNET_CLIENT_SECRET`; without them that step is skipped.
On Windows, `.\tools\schedule.ps1` registers the same run as a daily task.

The catalog reads `ItemSparse`, `ItemBonus`, `JournalEncounterItem`,
`TraitDefinition` and friends through [wago.tools](https://wago.tools) -
the same tables the client itself uses. No ID in this project was copied
from a website. Every one comes from the game's data and can be verified.

Talent strings are never generated: every one was written by a real
player's client. Raid and PvP strings are verified against the logged
fight or the murlok heatmap before they count as a build.

Releases: push a tag `v1.2.3` and the `Release` workflow packs the code of
that tag with the latest nightly data.

## Tests

```bash
cd Tests && npm install
node run.js smoke_test.lua   # loads the addon through its TOC and operates it
node run.js                  # catalog logic only
```

See [Tests/README.md](Tests/README.md).

## Getting it into the game while developing

```powershell
.\tools\sync.ps1                # once
.\tools\sync.ps1 -Watch         # on every change
```

## Three rules that are not negotiable

1. **Only IDs travel through the source, never names.** The client
   resolves the name - that is the only way the window is correct on a
   German client and an English one alike.
2. **MetaCodex only ever writes to lists prefixed `MetaCodex:`.** Auctionator's
   `CreateShoppingList` replaces a list wholesale; hitting someone else's
   list name would delete it.
3. **Nothing is shown that does not exist.** No invented defaults, no
   guessed sources, no talent strings that no client wrote.

## Licence

MIT, see [LICENSE](LICENSE).
