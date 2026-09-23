## What this version brings

First release.

### New

- **Talent builds with import strings.** The most common build for your
  spec and the alternatives, every string from a real player's client. For
  raid and PvP verified against the ranked fight. Hero trees kept apart.
- **Gear with its source.** Five pieces per slot with share and item level,
  plus which boss in which instance or which PvP vendor. Keystone picker by
  upgrade track, tooltips at your level. What you wear or carry is marked.
- **Enchants and gems against your gear.** The check asks whether THE
  recommended enchant is on the slot, not whether any is. Empty sockets
  counted, crafting tiers respected, bags and bank subtracted.
- **Consumables,** grouped by kind, with share, target and stock. One click
  says which item you use yourself.
- **Top players** per spec and activity, clickable: string, address and the
  full gear with enchants and gems.
- **A reminder before the pull** the way you choose: chat line with item
  links, its own window, a raid warning, a sound.
- **Handover to Auctionator.** One button writes the shopping list, the
  other searches at once. The **quantity** travels with it. Only lists with
  the `MetaCodex:` prefix are touched.
- **Ten activities, four platforms:** raider.io, murlok.io, Warcraft Logs
  and Battle.net, one at a time or together.
- **Catalog from the game data.** Every gem, every enchant, every drop
  source comes from the client's own DB2 tables. Nothing is guessed.
- **English and German,** and thanks to ids throughout, correct names on
  any language client. `/mc lang de|en|auto`.
- **`/mc probe`** shows what this client and this Auctionator really offer.
### What it deliberately does not do

- **It does not guess.** Where no platform measured anything, nothing is
  shown: no tab, no number, no invented default. Where a number is shown,
  it says which platform it came from and when.
- **It downloads nothing.** The data ship with the addon and are collected
  once a night; in the game nothing goes to the internet.

### Known limits

- Auctionator is optional. Without it the list still shows, only the
  buttons are greyed out.
- The warband bank only counts when the client knows its contents. When in
  doubt the list has one item too many rather than one too few.
