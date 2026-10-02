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

Open it four ways: the **minimap button**, the round **MetaCodex** icon on
the character frame, **`/mc`**, or the minimap's addon compartment. Both
buttons are on out of the box, both can be dragged, and both can be
switched off under Settings.

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
- **Sources**: where the pieces you are still missing drop, per
  instance, sorted by what is open for you.
- **A shopping list beside the auction house**: what is still missing,
  with a bar and a count, and a click searches for it.
- **Shopping lists to Auctionator** with quantities; **Shift-click** links
  any item into chat or the auction house search.
- **Every activity, every spec, four platforms** — and nothing shown that
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
exactly the level you would get, with "Hero 3/8" in the tooltip. A piece
you already wear or carry says so — **equipped** or **already in your bags**.

**Tier set, Crafted, Embellishments** — Three questions the gear list alone
does not answer, each counted from the same profiles: which set pieces are
worn and how many of them; which crafted pieces are worn, with the stat
pair their wearers chose and the item levels they were measured at, both
pickable so you can compare; and which **two** embellishments are worn
together — a combination, because that is the decision, and the tooltip
shows both.

**Enchants & Gems** — What the best wear on which slot, with two
alternatives per slot and the special socket kept separate. Compared with
your gear, and compared properly: a slot counts as done when **the
recommended enchant** is on it, not when any enchant is. A different one
says so by name and stays on the list. Empty sockets are counted, the
special socket by the gem that sits in it, and your bags and bank are
subtracted. Quality tiers count: a higher tier in your bags covers the
need, a lower one is shown but does not. On the right stands what you
still need. A dungeon picker narrows all of it to one dungeon; the default
is all of them.

**Consumables** — Click a row to say **which one you use**: your pick from
your own bags moves to the top, its stock is counted, and the shopping list
and the reminder buy that one instead. A cheaper food nobody measures is
still your food. Grouped by kind: flask, food, combat
potion, healing potion, weapon buffs (oils, stones), runes. Per group the
share of players and the highest key it was still used at. Plus your stock
— in every quality tier — and a target quantity you set with a click.

**Sources** — The same pieces as the gear list, on the other axis: one
row per instance, one box per piece, sorted by what is still open for
you. Dungeons first, raids below. What drops in no instance gets its own
rows - crafted, set pieces, PvP, auction house, no known source - because
"8 crafted" does not say which eight. Highlight by secondary stats, with
a combination mode; right-click a box to watch it (gold border and a
star) or ignore it. Ignored stays visible and stops counting; the star
never changes the order, because a preference must not move a measured
number. You choose the question: most still open, or best single piece. What
you already beat in that slot steps back and stops counting, but stays
visible - a set piece can be worth having a rank lower.

**Builds at the talent frame** — A button there opens the builds for
your spec; a click loads one, through the same method Blizzard's own
Import dialog uses. Per dungeon and per boss, grouped like the window.
Shift-click copies instead of loading, in combat it says so, and when
it fails the string lands in the copy box. The button is draggable and
the list hangs off it — we cannot know which corner is free on your
screen.

**The preview in the tree** — Hover a build and it is drawn on the tree
itself: green around what you would gain, red around what you would
lose. Against **your** tree, not against the most common build: the data
carry the complete talent list per build, the client says which nodes
you have purchased, and the difference between those two sets is the
answer. A pin on each row holds the preview, so you can take the mouse
off the list and read what a marked talent does — at every talent stands
Blizzard's own tooltip. What gets no frame is named with its reason, and
the most useful of them is *this build plays a different hero tree than
you*, which the tree cannot show you because the other one is not drawn
at all.

**Reminder** — What the addon checks before you go in: per consumable kind
the stand against your target (enough / low / none), the enchants and gems
still open on your character, and the settings for it. On entering a
dungeon or raid it tells you what is missing. At the auction house a
narrow **shopping list** opens beside the window: every missing item with
icon, bar and "14 of 20", a click searches for it, Shift-click links it.
It follows what you change while you stand there, and it can be switched
off. **How** the reminder itself tells you is yours to pick:
chat line, its own movable window, a raid warning across the screen, a
sound, any combination. The chat line carries real item links you can
hover and shift-click, and a link that opens the addon on your list. The
window lists the items with icons and carries the same two buttons as the
big one. A preview shows exactly what would appear.

### About

**Settings** — Minimap button and character frame button on or off, window
size, language, which activity the window opens on, and a reset for window
position and size. Every setting is a menu you pick from, not a value you
click through. The reminder keeps its own settings, next to what they
control: the chat line on entering and the shopping list at the auction
house are separate switches.

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
- **Hero talents** (talents): all trees, or one — the talents and builds of
  that tree alone, with its share of the best.
- **Source** (gear): one instance, PvP vendor, crafted — "what drops here".
- **Keystone** (gear): Champion / Hero / Great Vault, every rank with the
  keys that award it.
- **Category / slot**: lists can be narrowed to one slot or one kind.
- **Window**: resizable from the bottom-right corner; position and size are
  remembered. `/mc scale` additionally scales it for large and small screens.
- **Click on a row**: copies a string, opens a profile, sets a target —
  whatever the row is.
- **Right-click a box under Upgrades**: watch the piece (gold border and
  a star) or ignore it. Ignored stays visible, crossed out, and stops
  counting; the star never changes the order.
- **Shift-click on a row with an item**: links it — into chat, or straight
  into the search box when the auction house is open. Ctrl-click: dressing
  room.
- **Create shopping list / Search now** (bottom, under Enchants,
  Consumables and Reminder): hands over to **Auctionator** — one list per
  tab, with quantities. Both need the auction house open and say in a
  tooltip why they are grey when it is not. Without Auctionator the
  buttons are not there at all — MetaCodex still shows everything, only
  the handover is missing.

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
| **Battle.net** | The official PvP leaderboards with rating: every bracket, EU and US. Each top player's import string for the rated spec, PvP talents, hero tree, gear, enchants and gems — straight from Blizzard's character profile |

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
| **4 platforms** | raider.io, murlok.io, Warcraft Logs, Battle.net — individually or "All platforms" |
| **All 40 specs** | Including classes you do not play — to look things up, or to shop for an alt |
| **3,122 talent import strings** | Every one from a real player, every one copied with a click |
| **3,058 player profiles** | The top players per spec and activity, with their full gear |
| **Refreshed nightly** | The data are at most a day old |

---

## What is planned

- **A source for every item** — vendors and world sources for the pieces
  that still read "not an instance drop".

---

## Requirements

- World of Warcraft Retail, current patch (12.1)
- **Auctionator** for the handover to the auction house (optional)
- The three data addons `MetaCodex_Data`, `MetaCodex_Dungeons` and
  `MetaCodex_Players` come with the package and load only when needed — at
  login MetaCodex costs nothing.
