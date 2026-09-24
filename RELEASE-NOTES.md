## v1.0.0 — the first release

MetaCodex shows what the best players of your specialisation actually
play, measured from real runs and real fights, and holds it against the
character you are looking at. Nothing here is copied from a guide.

### What it does

- **Talent builds with import strings.** The most common build for your
  spec and up to six alternatives, read as *this talent instead of that
  one*. One click copies the string into the talent window. Every string
  was written by a real player's client; for raid and PvP it is verified
  against the fight it was measured in. Hero trees are kept apart, and
  the view per dungeon or per boss carries a string as well.
- **Gear with its source.** Five pieces per slot with share and item
  level, plus which boss in which instance, or which PvP vendor. The
  keystone picker follows the upgrade track, tooltips show the item at
  the level you picked, and what you already wear or carry is marked.
- **Enchants and gems against your own gear.** The check asks whether
  *the* recommended enchant is on the slot, not whether any is. Empty
  sockets are counted, crafting tiers respected, bags and bank
  subtracted.
- **Consumables,** grouped by kind, with share, target and what you have
  in your bags. One click says which item you take instead.
- **A reminder before the pull,** on the ways you choose: a chat line
  with item links, its own window, a raid warning, a sound. It waits
  until the client can actually answer, so it never claims your bags are
  empty while they are not.
- **Top players** per spec and activity, clickable: import string,
  profile address, and the full gear with its enchants and gems.
- **Handover to Auctionator.** One button writes the shopping list, the
  other searches straight away, and the **quantity** travels with it.
  Only lists carrying the `MetaCodex:` prefix are ever touched.
- **Ten activities, four platforms.** Mythic+ as a whole and per key
  range, three raid difficulties, five PvP brackets; from raider.io,
  murlok.io, Warcraft Logs and Battle.net, one at a time or together.
- **Everything from the game's own tables.** Every item, gem, enchant,
  drop source, boss and instance comes from the client's data. Names are
  asked of your client, so a German or French game shows its own names.
- **English and German,** switchable with `/mc lang de|en|auto`.
- **`/mc probe`** reports what this client and this Auctionator really
  offer, down to the memory the addon holds.

### What it deliberately does not do

- **It does not guess.** Where no platform measured anything, nothing is
  shown: no section, no number, no invented default. Where a number is
  shown, the line under it says which platform it came from, when, how
  many measurements it rests on and from which key range.
- **It downloads nothing while you play.** The data ship with the addon
  and are collected once a night, outside the game.

### Known limits

- Auctionator is optional. Without it the lists still show, only the two
  handover buttons stay grey.
- Consumables are not shown for PvP brackets, because no platform
  measures them there.
- A few specs have no data in a bracket nobody plays them in, for
  instance a Blood Death Knight in 3v3. Those sections stay hidden
  rather than showing an empty page.
- The warband bank counts only when the client knows its contents. In
  doubt the list holds one item too many rather than one too few.
