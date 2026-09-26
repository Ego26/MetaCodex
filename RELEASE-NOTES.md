## v1.1.0 — what the best players put on their gear

Four new answers in the window, all of them measured the same way as
everything else: counted off the characters that actually ran the keys
and killed the bosses.

### New

- **Tier set** and **Crafted** as sections of their own, sorted by how
  many of the measured players wear each piece. Not "what goes in this
  slot" but "which set piece do they wear at all" and "which crafted
  piece is worth making".
- **Embellishments**, as the pair they are worn as. You may wear two,
  and which two go together is the question - so the share belongs to
  the combination, not to one half of it. Hovering a pair shows both
  tooltips.
- **Crafted gear the way it really looks.** A crafted piece carries its
  quality, its upgrade, its embellishment and its stats in one set of
  bonus IDs, and the tooltip needs all of them - without them it says
  "random stat 1". The link is now built from the very list the piece
  was measured with. Two pickers above the list: the item level (from
  the levels that were actually measured - 288, 305, 318, 331) and the
  stat pair, in case you are planning something other than what the
  measured players took.
- **Stat ranks on every line a tooltip shows.** "Haste #2" now appears
  wherever the stat does, including the comparison tooltip and on gear
  whose stats the item interface cannot name.

### Better

- **The gear list is one row per slot.** Sixteen slots with five
  suggestions each were ninety rows; now each slot shows the piece most
  of them wear and says "+4 more" behind its name. A click opens that
  slot.
- **The origin picker has groups** - dungeons, raids, everything else -
  and a whole group can be chosen at once. Which instance is a dungeon
  and which a raid comes from the data, not from a list to maintain.
- **The talent build and the top players share one card** with the
  artwork of your specialisation; a click copies the import string.
- **Switching the activity while a player profile is open** takes you
  back to the ranking of the new activity instead of leaving the old
  player on screen.
- **One colour per kind of line.** Titles white, everything explaining
  them small and grey - no more grey titles beside white ones.

### Fixed

- Crafted gear was recognised by asking the item, and modern crafted
  armour says nothing on the item: 1188 items were marked as crafted
  and not one of them was a piece anyone wears. The recipes know
  better, so the Crafted section has something in it for all 40
  specialisations.
- The verified talent strings of raid players could vanish: eight
  per-boss files carried the same mode name as the whole raid and
  overwrote each other, and which one survived was decided by the order
  a directory happens to be listed in.
- The rank numbers fell away on crafted gear, exactly where the stats
  matter most.

---
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
- **Free software** under the GNU General Public License v3 or later.
  Use it, change it, share it; a changed version you pass on brings its
  source with it, under the same licence.

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
