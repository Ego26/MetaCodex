# MetaCodex — What the addon does

> As of 23 September 2026. Written for players. If you want to know *how*
> something is built, that is not in this repository. German version:
> `FEATURES.de.md`.

**MetaCodex shows you what the best players of your specialisation
actually run** — talents, gear, enchants, gems, consumables, stat targets —
for Mythic+, raid and every PvP bracket. Not copied from a guide but
measured daily from raider.io, murlok.io and Warcraft Logs. And it
compares that with what *you* wear and carry, so you know what is still
missing.

Open it: **`/mc`** or the button in the minimap's addon compartment.

---

## At a glance

- **Talent builds with import strings** — the most common build and its
  alternatives, per dungeon in M+, per boss in raids, per bracket in PvP.
  Copy, paste, done.
- **Gear with drop sources** — five items per slot, where each one drops,
  and tooltips at the level *your* keystone would give.
- **Enchants & gems against your own gear** — what is still open, what
  you already have, what to buy.
- **Consumables**, grouped by kind, with your stock and a target.
- **Stat targets** measured from the best, with your values next to them.
- **Top players**, clickable — their talent build with import string, their
  full gear, their profile.
- **Reminder** before you go in and at the auction house — and a tab that
  shows what it checks.
- **Guides** linked, never copied.
- **Shopping lists to Auctionator** with quantities; **Shift-click** links
  any item into chat or the auction house search.
- **Every activity, every spec, three platforms** — and nothing shown that
  no platform can answer.
- **English and German**, right on any client.

---

## The tabs

### Knowledge

**Guides & Rotation** — Links to the written guides for your spec: Wowhead
(rotation and BiS), Method, Archon, murlok. A click puts the address up for
copying — an addon cannot open a browser, but it can shorten the way there.

**Stat targets** — Which secondary stats the best carry and how much,
measured as the median from real fights. Two bars per stat: the target and
where you are. Green once you are there; otherwise it says how much is
missing.

**Talents** — The most common build as one row: click, copy the string,
paste it into the talent window's import box. Below it up to six
alternatives, each described as *"talent X instead of talent Y"* so you
see where opinions differ — each with its own string. Then the contested
talents (those between 15 and 85 % of the best take) and, for PvP, the PvP
talents in their own group. In M+ additionally per dungeon, in raids per
boss — grouped by raid when more than one is current.

**Top players** — Who is at the top on this spec right now, per activity.
A click opens the profile *in the window*: their talent string (marked
whether it fits the activity), their complete gear — tooltips show each
piece exactly as worn — and the address of their profile.

### Gear

**Gear** — Per slot the five most worn items with share, item level,
highest key, set and crafted marks and the **source**: which boss in which
instance, which vendor, or honestly "not an instance drop". At the top
right you pick *your* keystone — by upgrade track like KeystoneLoot
(Champion / Hero / Great Vault) — and every tooltip shows the item at
exactly the level you would get, with "Hero 3/8" in the tooltip.

**Enchants & Gems** — What the best wear on which slot, with two
alternatives per slot and the special socket kept separate. Compared with
your gear: enchanted slots are skipped, empty sockets counted, your bags
and bank subtracted. On the right stands what you still need.

**Consumables** — Grouped by kind: flask, food, combat
potion, healing potion, weapon buffs (oils, stones), runes. Per group the
share of players and the highest key it was still used at. Plus your stock
and a target quantity you set with a click.

**Reminder** — What the addon checks before you go in: per consumable kind
the stand against your target (enough / low / none), the enchants and gems
still open on your character, and the settings for it. On entering a
dungeon or raid a chat line tells you what is missing — and once at the
auction house how many items are open.

### About

**Info** — Version, catalog build, when each platform last measured, and
whether Auctionator is present.

---

## Controls

- **Spec** (header, left): your own is the default. Any other class and
  spec can be chosen; under "Also buy for …" further specs join the same
  shopping list.
- **Activity**: M+, raid, PvP — in submenus. Only what has data for the
  current tab is listed.
- **Platform**: one or all. Where a platform has nothing for a tab it is
  not offered; if only one remains there is no button.
- **Dungeon / boss** (talents): all eight dungeons of the season, or every
  boss of every current raid.
- **Keystone** (gear): Champion / Hero / Great Vault, every rank with the
  keys that award it.
- **Category / slot**: lists can be narrowed to one slot or one kind.
- **Window**: resizable from the bottom-right corner; position and size are
  remembered. `/mc scale` additionally scales it for large and small screens.
- **Click on a row**: copies a string, opens a profile, sets a target —
  whatever the row is.
- **Shift-click on a row with an item**: links it — into chat, or straight
  into the search box when the auction house is open. Ctrl-click: dressing
  room.
- **Create shopping list / Search now** (bottom, under Enchants,
  Consumables and Reminder): hands over to **Auctionator** — one list per
  tab, with quantities. "Search now" needs the auction house open and is
  greyed out otherwise. Without Auctionator MetaCodex still shows
  everything; only the handover is missing.

**Slash commands:** `/mc` opens · `/mc scale 0.6–1.6` window size ·
`/mc remind` toggles the reminder · `/mc lang de|en|auto` language ·
`/mc probe` self-test, copyable · `/mc reset` forgets saved choices.

---

## Where the data come from — and why they can be trusted

| Platform | Delivers |
|---|---|
| **raider.io** | M+: gear, enchants, gems, talents with ready-made import strings. The top players' profiles |
| **murlok.io** | All PvP brackets and M+: gear, gems, stat targets, talents, ranked lists of top players |
| **Warcraft Logs** | Raids in full and consumables — what nobody else publishes |

Everything is collected once a day by the GitHub Action `Daily data` and
attached to the release **nightly** as a finished addon package; in the
game nothing is loaded from the internet. Only IDs are stored — names and
icons come from your client in its own language.

**Talent strings are never invented.** Every one comes from a real player's
client. For raid and PvP every string is verified before it counts as a
build: the talents in the profile must match those the same player had in
the logged fight (raid) or what nearly all top players take (PvP). What
fails verification is not offered as a build.

**Nothing is shown that does not exist.** A tab without data for the chosen
activity leaves the sidebar, an activity without data leaves the menu, a
platform without data leaves the picker. Example: there are no consumables
under PvP because no platform measures them — so there is no tab for them.

## By the numbers

| | |
|---|---|
| **10 activities** | M+ (High Keys), M+ (+7 to +21), Raid Normal / Heroic / Mythic, 2v2, 3v3, Solo Shuffle, RBG, RBG Blitz |
| **3 platforms** | raider.io, murlok.io, Warcraft Logs — individually or "All platforms" |
| **All 40 specs** | Including classes you do not play — to look things up, or to shop for an alt |
| **1,401 talent import strings** | Every one from a real player, every one copied with a click |
| **2,472 player profiles** | The top players per spec and activity, with their full gear |
| **Refreshed nightly** | The data are at most a day old |

---

## What is planned

### Extensions

- **Hero talents split.** Builds differ between the two hero-talent trees
  (Stormbringer and Farseer, say); today they are mixed. Planned: numbers
  per tree.
- **Omnium Folio.** Archon shows which folio runes the best use. In the game
  data the runes are visible only as combat effects, not as items or
  talents — once they can be attributed cleanly, a tab follows.
- **Sources for the last items.** 459 pieces (reputation and world loot,
  "Spellbreaker's", "Martyr's" …) have no source in any game table and
  therefore read "not an instance drop". A vendor table would close that.
- **Filter by source.** "What drops here" instead of only "where does this
  drop".

### Improvements

- **First click on a player** loads 4.5 MB of profiles — whether that
  visibly hitches is decided in the game. If so: fewer players per spec or
  leaner profiles.
- **Consumables for every M+ spec.** The log sample missed a few specs; the
  daily run now draws more reports.

### What will not come, and why

- **PvP consumables** — no platform measures them, and Warcraft Logs does
  not log arenas. The addon would rather show nothing than something made
  up.
- **Guide texts inside the addon** — they belong to the sites that write
  them. Hence links instead of copies.

---

## Requirements

- World of Warcraft Retail, current patch (12.1)
- **Auctionator** for the handover to the auction house (optional)
- The three data addons `MetaCodex_Data`, `MetaCodex_Dungeons` and
  `MetaCodex_Players` come with the package and load only when needed — at
  login MetaCodex costs nothing.
