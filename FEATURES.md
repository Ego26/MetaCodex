# MetaCodex — What the addon does

> As of 27 October 2026. Written for players. If you want to know *how*
> something is built, that is not in this repository. German version:
> `FEATURES.de.md`.

**MetaCodex shows you what the best players of your specialisation
actually run** — talents, gear, enchants, gems, consumables, stat targets,
races, the groups they play in — for Mythic+, raid and every PvP bracket. Not copied from a guide
but measured daily from raider.io, murlok.io, Warcraft Logs and
Battle.net. And it compares that with what *you* wear and carry, so you
know what is still missing.

Open it four ways: the **minimap button**, the round **MetaCodex** icon on
the character frame, **`/mc`**, or the minimap's addon compartment. Both
buttons are on out of the box, both can be dragged, and both can be
switched off under Settings.

---

## At a glance

- **Talent builds with import strings** — the most common build and its
  alternatives, per dungeon in M+, per boss in raids, per bracket in PvP.
  Copy, paste, done — or load one straight from the talent frame.
- **Where every piece drops** — each current dungeon and each raid boss
  with the full drop list for your spec, and tooltips at the level *your*
  keystone would give.
- **Favourites** — mark the pieces you are after; the addon says where
  most of them drop, and tells you when one drops for someone else.
- **In the item tooltip** — which other specs wear this piece, and whose
  stats it fits. The answer to every warbound drop.
- **Enchants & gems against your own gear** — what is still open, what
  you already have, what to buy.
- **Consumables**, grouped by kind, with your stock and a target.
- **Stat targets** measured from the best, with your values next to them —
  and the diminishing-returns thresholds marked where you are past one.
- **Races** — which race the best of your spec play, and what a race is
  worth in damage.
- **Rotation** (beta) — what to press, in plain sentences: the priority
  SimulationCraft plays, cut to the build the top players run, per hero
  tree. For healers, what top healers actually cast, measured.
- **Groups & specs** — who plays with whom at the top: the most common
  M+ groups, the raid setups, the specs among the best in PvP.
- **Top players**, clickable — their talent build with import string, their
  full gear, their profile.
- **Reminder** before you go in and at the auction house — and a tab that
  shows what it checks.
- **Guides** linked, never copied.
- **A shopping list beside the auction house**: what is still missing,
  with a bar and a count, and a click searches for it.
- **Shopping lists to Auctionator** with quantities; **Shift-click** links
  any item into chat or the auction house search.
- **Every activity, every spec, four platforms** — and nothing shown that
  no platform can answer.
- **English, German and Simplified Chinese**, right on any client.

---

## The tabs

### Overview

**Guides** — Links to the written guides for your spec: Wowhead
(rotation and BiS), Method, Archon, murlok. A click puts the address up for
copying — an addon cannot open a browser, but it can shorten the way there.

**Rotation** (beta) — What to press, in plain sentences: "Use Ascendance
on cooldown", "Cast Lava Burst when Master of the Elements is not
active", and the filler at the end. For damage dealers and tanks it is
the priority SimulationCraft plays, cut to the build the measured top
players of your spec run — talents they skip and spells of a hero tree
they do not play drop out. One rotation per hero tree, with a dropdown
where enough top players play each, per activity and difficulty. Tabs
for **single target**, **AoE** (saying from how many targets it
applies), **before the pull** and **potions & trinkets**; below them
what to use **on the move**, and above an **example opener** measured on
raid pulls. This part is simulated, not measured, and the card says so.
**Healers** get no simulation, because SimulationCraft does not simulate
healing: their card shows what top healers cast on Warcraft Logs —
single-target and group healing as two lists, damage that heals, and the
major cooldowns by whom they protect. Marked as beta: not every line has
been checked by hand yet.

**Stat targets** — Which secondary stats the best carry and how much,
measured as the median from real fights. Two bars per stat: the target and
where you are. Green once you are there; otherwise it says how much is
missing. Logs measure at the pull, when flask and weapon oil are already
active; both are taken out again. A player whose food or other buff
cannot be put in numbers is left out, and so is one who drank a potion
with a stat buff just before the pull, so the target compares with your
character sheet without buffs. The hint under the list says how many
players a target rests on, and warns when it is fewer than five.

Past a certain rating every further point of a stat brings less. Where
your own rating has crossed such a threshold, the part of the bar beyond
it turns red, a tick marks the threshold, and the right column says "past
threshold"; a card below explains what a point still brings there and what
100 more are worth. The numbers are asked of the game itself rather than
written down anywhere, so they stay right if Blizzard moves them. Most
players will never see any of this — the measured targets sit almost
entirely below the first threshold, and a warning that never applies would
soon be ignored.

**Races** — Which race the measured top players of your spec play, and
what a race brings. Two numbers per row. **Played** comes from raider.io:
every player of the best M+ runs and the profiles of the top raid and PvP
players, each counted once. Where an activity alone has fewer than fifteen
measured players, its family steps in — all raid difficulties, all PvP
brackets — because race is chosen per character, not per activity, and the
tooltip says when that happened. **Simulated** comes from bloodmallet.com
(SimulationCraft): the DPS lead over the weakest race, at 1, 3 or 5 targets
in M+ and 1 or 3 in raid. Within 0.2 % counts as level, because the sims
carry about that much error. Healers, Augmentation, Devastation, Balance
and Guardian have no race sims there and show only what is played.

One list across both factions, sorted by the simulated lead, narrowable to
Horde or Alliance with the races of both sides under each. The tooltip
lists the racial abilities as character creation describes them.

**Top players** — Who is at the top on this spec right now, per activity.
A click opens the profile *in the window*: their talent string (marked
whether it fits the activity), their complete gear — tooltips show each
piece exactly as worn — and the address of their profile.

**Groups & specs** — Who plays with whom at the top. In **M+** the most
common groups of five and the specs per role, from the high keys
(raider.io) and +7 to +21 (Warcraft Logs), also per dungeon; whether a
group brings Bloodlust and a battle res is noted where it does not. In
**raid**, per difficulty, how many kills a spec is in and how many of it
on average. In **PvP**, which specs stand among the top players of each
bracket. Your own spec is marked. What is played, not proof of what is
strongest — the card says that too.

### Talents

**Talents & builds** — The most common build as one row: click, copy the
string, paste it into the talent window's import box. Below it up to six
alternatives, each described as *"talent X instead of talent Y"* so you
see where opinions differ — each with its own string. Then the contested
talents (those between 15 and 85 % of the best take) and, for PvP, the PvP
talents in their own group. In M+ additionally per dungeon, in raids per
boss — grouped by raid when more than one is current.

**Omnium Folio** — Which rune the best take, row by row, with the number
of players each row rests on. It stands beside the talents rather than
inside them because it comes from its own measurement, and it says what
kind of answer each row is: a row where nobody could be seen choosing is
marked as worked out rather than observed, and a row with a single rune
says so instead of pretending there was a decision.

### Gear

**Popular** — Per slot the five most worn items with share, item level,
highest key, set and crafted marks and the **source**: which boss in which
instance, which vendor, or honestly "not an instance drop". At the top
right you pick *your* keystone — by upgrade track like KeystoneLoot
(Champion / Hero / Great Vault) — and every tooltip shows the item at
exactly the level you would get, with "Hero 3/8" in the tooltip. A piece
you already wear or carry says so — **equipped** or **already in your bags**.

**Sources** — Where to go for it. Every current dungeon and every raid boss
lists all the drops for your spec, straight from the game's Adventure Guide
with its class and spec filter — the same list as its Loot tab, not only
the pieces top players wear. What was measured carries its share of top
players next to it. Dungeons and raids always both show, whatever activity
is picked, and raids are split by boss in journal order. Crafted, set, PvP
and world pieces stand in a card **Elsewhere** at the bottom.

A click marks a piece as a **favourite** — gold frame and star, per
character and spec — and a hint line names the instance where most of your
favourites drop. A green tick sits on everything you already have:
equipped, or anywhere in bags, bank, reagent or warband bank.
**Highlight** marks what you are looking for: favourites gold, the most
worn piece per slot purple (the first two for rings and trinkets), matching
secondary stats turquoise. A legend above the list says which is which; the
frame shows the most important mark, and a dot in the corner a second one.

**Tier set, Crafted & embellishments** — Three questions the gear list alone
does not answer, each counted from the same profiles: which set pieces are
worn and how many of them; which crafted pieces are worn, with the stat
pair their wearers chose and the item levels they were measured at, both
pickable so you can compare; and which **two** embellishments are worn
together — a combination, because that is the decision, and the tooltip
shows both.

### Before you go in

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

**Settings** — Every on and off stands under **Features**: minimap button,
character frame button, the builds button at the talent frame, the tooltip
lines, the window when a favourite drops, the reminder and the shopping
list at the auction house. What a feature fine-tunes — amounts,
thresholds, how it announces itself — stays next to it, in the groups
**Buttons**, **Tooltip**, **Loot** and **Reminders**. Under **Window** sit
text size, language, which activity the window opens on, and a reset for
position and size. Every setting is a menu you pick from, not a value you
click through.

**Info** — Version, catalog build, when each platform last measured, and
whether Auctionator is present.

---

## Outside the window

**Builds at the talent frame** — A button there opens the builds for
your active spec — the tree beside it, whatever the window is showing;
a click loads one, through the same method Blizzard's own
Import dialog uses. Per dungeon and per boss, grouped like the window.
Shift-click copies instead of loading, in combat it says so, and when
it fails the string lands in the copy box. The button is draggable and
the list hangs off it — we cannot know which corner is free on your
screen.

**The preview in the tree** — Hover a build and it is drawn on the tree
itself: green around what you would gain, red around what you would
lose. Against **your** tree, not against the most common build: the data
carry the complete talent list per build, the client says which nodes
you have — the free ones the game grants included, which no build can
take away — and the difference between those two sets is the answer. A pin on each row holds the preview, so you can take the mouse
off the list and read what a marked talent does — at every talent stands
Blizzard's own tooltip. What gets no frame is named with its reason, and
the most useful of them is *this build plays a different hero tree than
you*, which the tree cannot show you because the other one is not drawn
at all.

**In the item tooltip** — Two lines, and only where they can be earned.
*Also worn by* names the other specs that wear this piece, with their
share and the activity it was measured in — the question behind every
warbound drop: is this good for one of my other characters? Two lines by
default, all of them while Shift is held. *Stats fit* answers for pieces
no measurement covers, a delve drop or a world drop: whose two highest
measured stats are exactly the ones on it, with armour type and main stat
deciding who could wear it at all.

Both appear only where the piece can still reach another character —
warbound, bind on equip, unbound, or still inside the trade window of a
dungeon or raid drop. And both stay silent where the answer would be a
guess: a source without a known sample of at least fifteen players
contributes nothing, under twenty percent is not "worn by", and a trinket
is its effect rather than its stats, which nobody here measures.
**`/mc fit`** prints, for the item under your mouse, why each line does or
does not stand there.

**When a favourite drops** — A piece you marked, in any spec of the
character, dropping for someone else: a small window opens after the boss
or at the end of the dungeon and says what it was and who got it, as
name-realm in their class colour. One click whispers them and asks to
trade — always in English, because it goes to players from any realm.
During a keystone or boss fight the game blocks whispers from addons; then
the button says "Waiting…" and the whisper goes out on its own as soon as
that is over. Switchable under Settings → Loot.

**In combat** — MetaCodex does not open while *you* fight, and closes when
a fight starts: the game keeps your combat ratings secret there, and the
stat targets would be built on nothing. In a running keystone the game
keeps them secret the whole way, between pulls too — so the window opens
while the group pulls without you, and shows the ratings it remembered
before the run, marked as such. They do not change there; the gear is the
same.

---

## Controls

- **Spec** (header, left): your own is the default. Any other class and
  spec can be chosen.
- **Activity**: M+, raid, PvP — in submenus. Only what has data for the
  current tab is listed.
- **Platform**: one or all. Where a platform has nothing for a tab it is
  not offered; if only one remains there is no button.
- **Dungeon / boss** (talents): all eight dungeons of the season, or every
  boss of every current raid.
- **Hero talents** (talents): all trees, or one — the talents and builds of
  that tree alone, with its share of the best.
- **Faction** (races): both, or Horde or Alliance alone.
- **Keystone** (gear): Champion / Hero / Great Vault, every rank with the
  keys that award it.
- **Category / slot**: lists can be narrowed to one slot or one kind.
- **Window**: resizable from the bottom-right corner; position and size are
  remembered. `/mc scale` additionally scales it for large and small screens.
- **Click on a row**: copies a string, opens a profile, sets a target,
  marks a favourite — whatever the row is.
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
`/mc remind` toggles the reminder · `/mc lang de|en|zh|auto` language ·
`/mc fit` why a tooltip line is or is not there · `/mc probe` self-test,
copyable · `/mc reset` forgets saved choices.

---

## Where the data come from — and why they can be trusted

| Platform | Delivers |
|---|---|
| **raider.io** | M+: gear, enchants, gems, talents with ready-made import strings. The top players' profiles, the race each one plays, and the groups of the high keys |
| **murlok.io** | All PvP brackets and M+: gear, gems, stat targets, talents, ranked lists of top players |
| **Warcraft Logs** | Raids in full and consumables — what nobody else publishes. The groups of +7 to +21 and the raid setups, what top healers cast, and the openers on raid pulls |
| **Battle.net** | The official PvP leaderboards with rating: every bracket, EU and US. Each top player's import string for the rated spec, PvP talents, hero tree, gear, enchants and gems — straight from Blizzard's character profile — and which specs stand at the top |
| **SimulationCraft** | The rotation priority for damage dealers and tanks — simulated rather than measured, and the card says so |
| **bloodmallet.com** | The race simulations, also from SimulationCraft and also marked as simulated |

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
| **4 platforms** | raider.io, murlok.io, Warcraft Logs, Battle.net — individually or "All platforms". SimulationCraft adds the rotation, bloodmallet.com the race simulations |
| **All 40 specs** | Including classes you do not play — to look things up, or to shop for an alt |
| **3,008 talent import strings** | Every one from a real player, every one copied with a click |
| **3,058 player profiles** | The top players per spec and activity, with their full gear |
| **Refreshed nightly** | The data are at most a day old |

---

## What is planned

- **A source for every item** — vendors and world sources for the pieces
  that still read "not an instance drop".

---

## Requirements

- World of Warcraft Retail, current patch (12.1.5)
- **Auctionator** for the handover to the auction house (optional)
- The three data addons `MetaCodex_Data`, `MetaCodex_Dungeons` and
  `MetaCodex_Players` come with the package and load only when needed — at
  login MetaCodex costs nothing.
