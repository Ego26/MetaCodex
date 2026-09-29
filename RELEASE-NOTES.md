## v1.1.7 — the shopping list at the auction house

### Added

- **A shopping list beside the auction house.** It opens with the auction
  house, lists what is still missing with an icon, a bar and "14 of 20",
  and **a click on a row searches for that item**. Shift-click puts its
  link in the chat.
- It docks to the **outer right edge** of the window rather than sitting
  inside it — that edge survives ElvUI and anything else that rebuilds
  the auction house.
- **A switch for it** under Reminder. Turn the reminders off entirely and
  the list stays away too: whoever wants quiet should get quiet.

### Fixed

- **Ignored meant ignored everywhere except the shopping list.** It still
  got handed to Auctionator.
- **The list beside the auction house knew only half the list.** It could
  stand empty while the window named five missing things.
- **A death knight was told a rune was already on his weapon** when a
  different one was on it.
- **A crafting item was shown in the wrong quality tier.** Where a name
  appears twice, the most-used tier wins now, not the one read last.
- **A long item name wrote itself across the progress bar.** Names are cut
  with an ellipsis and shown in full on hover.
- **A greyed-out button now says why it is grey** — and actually shows it,
  which it did not before.

### Changed

- **The chat line at the auction house is gone.** The list beside the
  window says the same thing, item by item.
- **The Auctionator buttons only appear when Auctionator is installed.**
  Grey means "not right now"; without Auctionator it is "never", and that
  looks like a broken addon.
- **Create list takes you to the list**, in one click. It used to need a
  second one.
- **The list follows what you change** — ignoring something, a new target
  quantity, a purchase — while you stand at the auction house.

## v1.1.6 — the Omnium Folio

### Added

- **The Omnium Folio**, under Talents: five rows, thirteen runes, per spec,
  per activity and per dungeon.
- Each row says **how many players it was measured on**. A rune is found by
  what it does in the fight, so someone who carries one and never triggers
  it is not counted — the row names its own sample rather than hiding it.
- Row three holds a single rune and therefore stands there **without a
  percentage**: there is nothing to choose.
- One rune in row five, **Residual Energy**, cannot be seen at all. Its
  number is what the other two leave over, its row says "worked out, not
  seen", and it never takes the accent colour.
- **Weapon buffs a class puts on itself** are shown: a shaman's Flametongue
  and a rogue's poison stand where an oil would. And a shaman is no longer
  told to buy oil he cannot use.
- **Everything under "Other" in the reminder has its own amount.** Drums, a
  repair hammer and a Vantus rune are not one decision.
- **Anything can be put on the reminder by item id**, with a preview and
  the game's own tooltip while you hover — including what nobody measured.
- **An ignore list.** A row you do not want to hear about again goes away
  through a menu, and comes back the same way.

### Fixed

- **A shaman was told to buy oil** he cannot use.
- **A socket with a gem in it was called empty.** Wearing haste and
  versatility on purpose is a decision, not an omission.
- **Missing enchants and gems are named, not counted.** "Two gems missing"
  does not say which two.
- **A row's percentages add up to a hundred.** They were rounded one at a
  time and came to 99 or 101.
- **The stat rows no longer run through the bar**, and they say which
  percentage they mean: this stat's rating against the sum of the four
  secondary ratings — not the effect your character sheet shows.
- **Raid Mythic and Normal got their boss picker back**, and the raid's
  ninth boss with it.

### Changed

- **The scrollbar is the addon's own now** — slim, in your class colour,
  draggable, and a click on the track jumps there. It shows up only when
  there is something to scroll.
- **The daily data run starts earlier**, so fresh tables reach CurseForge
  before breakfast instead of after lunch.

## v1.1.5 — numbers that say what they mean

Eight reports from the game, and every one of them turned out to be a
number claiming something nobody had measured.

### Fixed

- **Twice the same embellishment was counted as one.** The counting used a
  set, and a set knows no "twice" — so whoever wore two Arcanoweave Linings
  landed in the same drawer as someone with one. That is why the window
  said "one embellishment, 93 %" where in truth most wear two of the same.
  It is now counted as a pair, the row names it once with **x2** and
  carries both tooltips.
- **An embellishment was named after the wrong reagent.** A reagent exists
  once per crafting tier under the same name; the lookup went by name and
  kept the first hit, which is the lowest tier. So the row showed an item
  with the worse quality mark, as if the measured players had crafted with
  it. Which tier they used stands in no bonus id and cannot be seen from
  outside — but of the reagents with that name, the one that fits a
  finished endgame piece is now taken.
- **A share was rounded into a claim.** The rings read 100 %, 1 % and 0 %.
  That is 101 and cannot be: 996 of 1000 rounds to 100, 9 to 1, and 4 to 0.
  Worse than the sum is what the edges assert — a hundred percent means
  "all", and the lines below it prove it was not; zero percent means
  "nobody", standing in a list of what people wear. A hundred now appears
  only when it really is all of them, zero only when it really is none.
- **The highlight followed a threshold the data do not know.** The share
  was coloured from fifty percent up, so a trinket at 48 % looked like the
  3 % row below it. The leader of each group is coloured now, and a tie
  colours both.
- **"Already on it" answered from the wrong place.** For gems it now reads
  the gear you are wearing and follows immediately when you swap a piece.
- **"Pick from my bags" showed the catalog, not the bags.** An older rune
  was missing although it lay right there: the catalog carries only the
  running expansion. The bags are asked directly now — and while fixing it,
  the reason came out: `GetItemInfoInstant` returns seven values, and the
  fifth is the icon, not the class.

### Added

- **The crafting tier is drawn at the icon**, the same mark the bags draw
  and in the same corner: on consumables, on crafted gear and on the
  embellishment reagents. It is read from the game's own quality tables.
  Guessing it from how many tiers of a ware exist was wrong twice over —
  item ids are not issued in tier order, and in this expansion a ware has
  two tiers, not three.
- **The stat targets say what they are.** A median of the measured players,
  one stat at a time, with the middle half of the measured field behind
  each number — and the line above says it plainly: for orientation, not
  BiS values. Four medians side by side are nobody's actual build.
- **Rings and trinkets show two rows**, because two are worn. The second
  best choice there is not an alternative, it is the second ring — it used
  to hide behind "+4 more". The heading says how many slots it stands for.
- German headings no longer keep a lowercase umlaut in the middle of
  capitals: `string.upper` works byte by byte and knows only a to z.

## v1.1.4 — names you can read, a button where it belongs

Four things reported from the game, each fixed at its cause.

### Fixed

- **The minimap button sat inside the map** instead of on its rim, and with
  ElvUI almost in the middle. It was following a number written down once:
  the radius of Blizzard's minimap at its default size. The minimap is now
  asked how big it is, and whoever changed its shape is asked what shape it
  is — round, square, or one of the half shapes. When it is resized
  afterwards, the button follows.
- **Korean and Chinese names showed as empty boxes** in the top players
  list. Nothing was wrong with the data: the client's standard font has no
  Hangul, and the Korean font has no Chinese. Every client carries a font
  for each language, so each line picks the one that can draw it — and
  gives it back when the line is reused for a European name.
- **Headings were drawn in the wrong font** after looking at a Korean
  player's profile: the section heading came back too wide and oddly
  spaced.
- **Tier set showed more than the tier set.** Last season's class set, the
  PvP armour and a ring from a dungeon jewellery set stood next to the real
  thing, because "belongs to a set" is a wider question than "is the tier
  set". A tier piece is restricted to one class, and of the class sets the
  current one is the newest — 13 classes, five pieces each.

## v1.1.3 — with the catalog it was built for

v1.1.2 shipped minutes ago with the previous night's catalog instead of
its own, so two of its three corrections had nothing to read: old content
stayed under Dungeons and Raids, and a raid still listed only the bosses
something in the list came from. Everything in the v1.1.2 notes below is
in this build, and now it works.

### Fixed

- The release builds its own catalog. It died on a missing directory -
  the one the collectors create - and the step shrugged the error off,
  then found the night's catalog in place and called it a day. The
  directory is created now, the step fails loudly, and it checks that the
  table it needs is really in the file before anything is packed.

## v1.1.2 — the origin picker says what it means

Three corrections to what the gear list offers you, all of them found by
looking at the game data rather than guessing.

### Fixed

- **The chosen gear slot vanished.** Pick "Trinkets", see the trinkets,
  click anything - and everything was back. Two pickers kept their choice
  under the same key, and the check that clears a stale category took the
  slot with it. That one line also explains why "+4 more" appeared
  although a slot was chosen: the folding step read the value that had
  just been cleared.
- **Old content sat under Dungeons and Raids.** Firelands ran as
  Timewalking last week, so a piece from it really is worn - the source is
  measured and stays in the list, but under "Other", where old content
  belongs. Which content is current comes from the journal's current
  season: eight dungeons and two raids, exactly as the game shows them.

### New

- **Every boss of a raid** is offered, not only the ones something in the
  list came from. A raid that shows six bosses one day and eight the next
  is not a choice, it is a riddle. Picking a boss nobody wears anything
  from says so in one line instead of showing an empty window.

## v1.1.1 — raids belong under Raids, and they open into their bosses

A small release with one question answered properly.

### Fixed

- **"The Tidebound Grotto" was listed under "Other"** although it is a
  raid. The kind of an instance came from the measurements, and nobody has
  uploaded a report from that raid - so to the addon it was nothing, and
  nothing lands in "Other". The adventure journal does not answer it
  either: its flag carries the same value for Scarlet Halls (a dungeon)
  and Dragon Soul (a raid). The map behind the instance does answer it, so
  the catalog now carries the kind for all 213 instances, 70 of them raids.
- **A group with a single entry lost its heading.** The one current raid
  stood bare between "Dungeons" and "Other" and looked like a third kind
  rather than the one raid there is. A group stays a group now.

### New

- **A raid opens into its bosses.** Eight bosses are eight evenings, and
  "what drops off this one" is the same question as "what drops in this
  dungeon". Listed are only the bosses something in the list actually came
  from - a boss with no loot would be an empty choice.
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
