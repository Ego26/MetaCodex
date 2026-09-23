// Battle.net: die PvP-Ranglisten von Blizzard und die Profile der Leute
// darauf - Talent-String, PvP-Talente, Held-Baum, Ausruestung.
//
//     node tools/collect-bnet.js <Pfad zum Repo>
//
// WARUM. Fuer PvP gab es bisher nur murlok: eine Rangliste von einer
// Webseite, deren Talente ueber ein raider.io-Profil nachgeladen wurden -
// und das Profil zeigt nur die AKTIVE Spec. Blizzard fuehrt beides selbst:
// die Rangliste jeder Klammer mit Wertung, und je Charakter die Loadouts
// ALLER Speccs samt fertigem Import-String und den PvP-Talenten. Das ist
// die Quelle, aus der die anderen abschreiben.
//
// Was hier herauskommt, ist eine eigene Plattform "Battle.net": Top-
// Spieler mit Wertung, Talente als Heatmap, der haeufigste Build als
// String, Ausruestung je Platz. Nur PvP - fuer M+ und Raid fuehrt
// Blizzard keine Rangliste, die etwas ueber Talente sagt.
//
// Ohne Zugangsdaten (tools/bnet-credentials.json oder BNET_CLIENT_ID /
// BNET_CLIENT_SECRET) tut das Skript nichts und meldet das. Die Action
// laeuft dann ohne diese Plattform weiter.

const fs = require('fs');
const path = require('path');
const bnet = require('./bnet');

const BASE = process.argv[2];
if (!BASE) {
  console.error('Aufruf: node tools/collect-bnet.js <Pfad zum Repo>');
  process.exit(1);
}
const DIR = path.join(BASE, 'tools', 'data');
const REGIONS = (process.env.MC_BNET_REGIONS || 'eu,us').split(',');
// Je Spec und Klammer so viele Spieler - zehn stehen im Fenster.
const MAX = Number(process.env.MC_PLAYERS || 10);
// 2v2, 3v3 und RBG nennen die Spec nicht: so viele Plaetze von oben werden
// gelesen, bis jede Spec ihre zehn hat. Solo Shuffle und Blitz haben eine
// Rangliste je Spec - dort reicht die Spitze.
const SCAN = Number(process.env.MC_BNET_SCAN || 300);
const DELAY = Number(process.env.MC_DELAY || 40);
const ONLY = process.env.MC_MODES ? process.env.MC_MODES.split(',') : null;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Klammer auf Battle.net -> Modus im Addon. Dieselben Schluessel wie
// murlok, damit beide unter einer Aktivitaet stehen.
const MODES = { '2v2': '2v2', '3v3': '3v3', rbg: 'rbg', shuffle: 'solo', blitz: 'blitz' };

// Ausruestungsplaetze: Blizzard nennt sie MAIN_HAND, das Addon (wie
// murlok) "Main Hand". Ringe und Schmuck werden zusammengelegt - zwei
// Plaetze, eine Frage: was tragen sie dort?
const SLOT_LABEL = {
  HEAD: 'Head', NECK: 'Neck', SHOULDER: 'Shoulders', BACK: 'Back', CHEST: 'Chest',
  WRIST: 'Wrist', HANDS: 'Hands', WAIST: 'Waist', LEGS: 'Legs', FEET: 'Feet',
  FINGER_1: 'Rings', FINGER_2: 'Rings', TRINKET_1: 'Trinkets', TRINKET_2: 'Trinkets',
  MAIN_HAND: 'Main Hand', OFF_HAND: 'Off Hand',
};
// Die Schluessel der Profile (raider.io schreibt "finger1", "mainhand").
const SLOT_KEY = {
  HEAD: 'head', NECK: 'neck', SHOULDER: 'shoulder', BACK: 'back', CHEST: 'chest',
  WRIST: 'wrist', HANDS: 'hands', WAIST: 'waist', LEGS: 'legs', FEET: 'feet',
  FINGER_1: 'finger1', FINGER_2: 'finger2', TRINKET_1: 'trinket1', TRINKET_2: 'trinket2',
  MAIN_HAND: 'mainhand', OFF_HAND: 'offhand',
};
// Verzauberungen je Platz, mit murloks Schluesseln - das Addon kennt sie.
const ENCHANT_KEY = {
  HEAD: 'helm', SHOULDER: 'shoulders', CHEST: 'chest', LEGS: 'legs', FEET: 'boots',
  FINGER_1: 'ring', FINGER_2: 'ring', MAIN_HAND: 'weapon', OFF_HAND: 'weapon',
};

let requests = 0;
async function api(region, apiPath, namespace) {
  requests += 1;
  const out = await bnet.get(BASE, region, apiPath, namespace);
  await sleep(DELAY);
  return out;
}

// --- Speccs -------------------------------------------------------------

/** Spec-ID je "klasse-spec" so, wie die Klammernamen sie schreiben. */
async function readSpecSlugs(region) {
  const index = await api(region, '/data/wow/playable-specialization/index', 'static-' + region);
  const out = new Map();
  const tidy = (t) => String(t).toLowerCase().replace(/[^a-z]/g, '');
  for (const spec of index.character_specializations || []) {
    const detail = await api(region, '/data/wow/playable-specialization/' + spec.id, 'static-' + region);
    if (!detail || !detail.playable_class) continue;
    out.set(tidy(detail.playable_class.name) + '-' + tidy(detail.name), Number(spec.id));
  }
  return out;
}

// --- Profile ------------------------------------------------------------

const specCache = new Map();
const realmCache = new Map();

async function realmName(region, slug) {
  const key = region + '/' + slug;
  if (!realmCache.has(key)) {
    let name = slug;
    try {
      const r = await api(region, '/data/wow/realm/' + encodeURIComponent(slug), 'dynamic-' + region);
      if (r && r.name) name = r.name;
    } catch (e) { /* der Slug tut es auch */ }
    realmCache.set(key, name);
  }
  return realmCache.get(key);
}

/** Die Talente aller Speccs eines Charakters, wie Blizzard sie fuehrt. */
async function specializations(region, realm, name) {
  const key = region + '/' + realm + '/' + name.toLowerCase();
  if (specCache.has(key)) return specCache.get(key);
  let data = null;
  try {
    data = await api(region, '/profile/wow/character/' + encodeURIComponent(realm) + '/'
      + encodeURIComponent(name.toLowerCase()) + '/specializations', 'profile-' + region);
  } catch (e) { data = null; }
  specCache.set(key, data);
  return data;
}

/** Das aktive Loadout einer Spec: String, Talente, Held-Baum, PvP-Talente. */
function loadoutOf(specs, specID) {
  const spec = (specs.specializations || []).find((s) => s.specialization && Number(s.specialization.id) === specID);
  if (!spec) return null;
  const lo = (spec.loadouts || []).find((l) => l.is_active) || (spec.loadouts || [])[0];
  if (!lo) return null;
  const spells = [];
  const seen = new Set();
  for (const list of [lo.selected_class_talents, lo.selected_spec_talents, lo.selected_hero_talents]) {
    for (const t of list || []) {
      const spell = t.tooltip && t.tooltip.spell_tooltip && t.tooltip.spell_tooltip.spell && Number(t.tooltip.spell_tooltip.spell.id);
      if (!spell || seen.has(spell)) continue;
      seen.add(spell);
      spells.push({ spell, rank: Number(t.rank) || 1 });
    }
  }
  const pvp = [];
  for (const slot of spec.pvp_talent_slots || []) {
    const sel = slot.selected;
    const spell = sel && sel.spell_tooltip && sel.spell_tooltip.spell && Number(sel.spell_tooltip.spell.id);
    if (spell) pvp.push(spell);
  }
  return {
    text: lo.talent_loadout_code || null,
    spells, pvp,
    subTree: (lo.selected_hero_talent_tree && Number(lo.selected_hero_talent_tree.id)) || 0,
  };
}

/** Die getragene Ausruestung, je Platz mit allen Bonus-IDs. */
async function equipment(region, realm, name) {
  let data = null;
  try {
    data = await api(region, '/profile/wow/character/' + encodeURIComponent(realm) + '/'
      + encodeURIComponent(name.toLowerCase()) + '/equipment', 'profile-' + region);
  } catch (e) { data = null; }
  if (!data) return null;
  const gear = {};
  const rows = [];
  let sum = 0, n = 0;
  for (const it of data.equipped_items || []) {
    const type = it.slot && it.slot.type;
    const key = SLOT_KEY[type];
    if (!key || !it.item || !it.item.id) continue;
    const enchant = (it.enchantments || []).find((e) => !e.enchantment_slot || e.enchantment_slot.type === 'PERMANENT');
    const ilvl = (it.level && Number(it.level.value)) || 0;
    gear[key] = {
      id: Number(it.item.id), ilvl,
      bonuses: (it.bonus_list || []).map(Number).filter(Boolean),
      enchant: (enchant && Number(enchant.enchantment_id)) || 0,
      gems: (it.sockets || []).map((s) => s.item && Number(s.item.id)).filter(Boolean),
    };
    rows.push({ type, id: Number(it.item.id), name: it.name || '', set: Boolean(it.set) });
    if (ilvl) { sum += ilvl; n += 1; }
  }
  return { gear, rows, ilvl: n ? Math.round((sum / n) * 10) / 10 : 0 };
}

// --- Pruefung -----------------------------------------------------------

/** murloks Heatmap derselben Klammer, wenn sie da ist. */
function heatmaps(mode) {
  const file = path.join(DIR, 'murlok-' + mode + '.json');
  if (!fs.existsSync(file)) return {};
  const j = JSON.parse(fs.readFileSync(file, 'utf8'));
  const out = {};
  for (const [id, entry] of Object.entries(j.specs || {})) out[id] = entry.talents || [];
  return out;
}

/** Was auf murlok (fast) alle nehmen, muss drinstehen - sonst ist es
 *  der PvE-Build, der gerade aktiv war. Ohne Heatmap zaehlt die Spec. */
function matchesHeatmap(spells, talents) {
  const core = new Set((talents || []).filter((t) => !t.pvp && t.pct >= 90).map((t) => t.spell));
  if (!core.size) return true;
  const have = new Set(spells.map((s) => s.spell));
  let hit = 0;
  for (const x of core) if (have.has(x)) hit += 1;
  return hit / core.size >= 0.9;
}

// --- Zusammenfassen -----------------------------------------------------

function pctRows(counter, denom) {
  return Object.entries(counter)
    .map(([k, n]) => ({ key: k, pct: Math.round((n / Math.max(1, denom)) * 100) }))
    .filter((r) => r.pct > 0)
    .sort((a, b) => b.pct - a.pct);
}

function buildsFrom(players) {
  const verified = players.filter((p) => p.verified && p.text);
  if (!verified.length) return {};
  const byText = new Map();
  for (const p of verified) {
    const cur = byText.get(p.text) || { n: 0, spells: p.spells };
    cur.n += 1;
    byText.set(p.text, cur);
  }
  const sorted = [...byText.entries()].sort((a, b) => b[1].n - a[1].n);
  const top = sorted[0];
  const build = {
    pct: Math.round((top[1].n / verified.length) * 100),
    text: top[0], nodes: top[1].spells, players: verified.length,
  };
  const topSet = new Set(top[1].spells.map((s) => s.spell));
  const builds = [];
  for (const [text, info] of sorted.slice(1)) {
    const set = new Set(info.spells.map((s) => s.spell));
    const added = info.spells.filter((s) => !topSet.has(s.spell)).map((s) => s.spell);
    const removed = top[1].spells.filter((s) => !set.has(s.spell)).map((s) => s.spell);
    if (!added.length && !removed.length) continue;
    builds.push({ pct: Math.round((info.n / verified.length) * 100), text, added, removed });
    if (builds.length >= 6) break;
  }
  return { build, builds };
}

/** Ein Spec-Eintrag im Format der anderen Quellen. */
function summarise(players) {
  const verified = players.filter((p) => p.verified);
  const out = {
    players: players.map((p) => ({ rank: p.rank, rating: p.rating, name: p.name, realm: p.realm, url: p.url })),
    profiles: players.map((p) => ({
      rank: p.rank, name: p.name, realm: p.realm, region: p.region, url: p.url,
      found: true, verified: p.verified, text: p.verified ? p.text : null,
      spells: p.spells, gear: p.gear, ilvl: p.ilvl, subTree: p.subTree,
    })),
  };
  if (!verified.length) return out;

  // Talente als Heatmap - Klassen-, Spec-, Held- und PvP-Talente.
  const tally = {};
  const pvpTally = {};
  for (const p of verified) {
    for (const s of p.spells) { const k = s.spell + '|' + s.rank; tally[k] = (tally[k] || 0) + 1; }
    for (const s of p.pvp) pvpTally[s] = (pvpTally[s] || 0) + 1;
  }
  const talents = pctRows(tally, verified.length).map((r) => {
    const [spell, rank] = r.key.split('|');
    return { spell: Number(spell), rank: Number(rank), pct: r.pct };
  });
  for (const r of pctRows(pvpTally, verified.length)) talents.push({ spell: Number(r.key), rank: 1, pct: r.pct, pvp: true });
  out.talents = talents;
  out.talentSample = verified.length;
  Object.assign(out, buildsFrom(verified));

  // Je Held-Baum: Anteil, Talente und Build nur dieses Baums.
  const hero = {};
  for (const sub of new Set(verified.map((p) => p.subTree).filter(Boolean))) {
    const mine = verified.filter((p) => p.subTree === sub);
    const t = {};
    for (const p of mine) for (const s of p.spells) { const k = s.spell + '|' + s.rank; t[k] = (t[k] || 0) + 1; }
    hero[sub] = {
      players: mine.length, pct: Math.round((mine.length / verified.length) * 100),
      talents: pctRows(t, mine.length).map((r) => { const [spell, rank] = r.key.split('|'); return { spell: Number(spell), rank: Number(rank), pct: r.pct }; }),
      ...buildsFrom(mine),
    };
  }
  if (Object.keys(hero).length) out.hero = hero;

  // Ausruestung je Platz, Verzauberungen je Platz, Steine.
  const gearTally = {};
  const names = {};
  const enchTally = {};
  const enchSlots = {};
  const gemTally = {};
  let gemCount = 0;
  const slotPlayers = {};
  for (const p of verified) {
    for (const row of p.rows) {
      const label = SLOT_LABEL[row.type];
      if (!label) continue;
      const g = gearTally[label] || (gearTally[label] = {});
      g[row.id] = (g[row.id] || 0) + 1;
      names[row.id] = { name: row.name, kind: row.set ? 'set' : null };
      slotPlayers[label] = (slotPlayers[label] || 0) + 1;
    }
    for (const [type, key] of Object.entries(ENCHANT_KEY)) {
      const it = p.gear[SLOT_KEY[type]];
      if (!it) continue;
      // Ring und Waffe haben zwei Plaetze: der Anteil gilt je Platz, nicht
      // je Spieler, sonst stuende 200 % an einem Ring.
      enchSlots[key] = (enchSlots[key] || 0) + 1;
      if (!it.enchant) continue;
      const e = enchTally[key] || (enchTally[key] = {});
      e[it.enchant] = (e[it.enchant] || 0) + 1;
    }
    for (const it of Object.values(p.gear)) for (const gem of it.gems) { gemTally[gem] = (gemTally[gem] || 0) + 1; gemCount += 1; }
  }
  const gear = {};
  for (const [label, counter] of Object.entries(gearTally)) {
    gear[label] = pctRows(counter, slotPlayers[label]).slice(0, 8)
      .map((r) => ({ id: Number(r.key), pct: r.pct, name: names[r.key].name, kind: names[r.key].kind }));
  }
  if (Object.keys(gear).length) out.gear = gear;
  const enchants = {};
  for (const [key, counter] of Object.entries(enchTally)) {
    enchants[key] = pctRows(counter, enchSlots[key]).slice(0, 5).map((r) => ({ id: Number(r.key), pct: r.pct }));
  }
  if (Object.keys(enchants).length) out.enchants = enchants;
  // Anteil an allen gesockelten Steinen, wie murlok ihn zeigt.
  const gems = pctRows(gemTally, gemCount).slice(0, 8).map((r) => ({ id: Number(r.key), pct: r.pct }));
  if (gems.length) out.gems = gems;
  return out;
}

// --- Lauf ---------------------------------------------------------------

(async () => {
  if (!bnet.available(BASE)) {
    console.log('Battle.net: keine Zugangsdaten (tools/bnet-credentials.json oder BNET_CLIENT_ID/BNET_CLIENT_SECRET) - uebersprungen.');
    return;
  }
  const today = new Date().toISOString().slice(0, 10);
  const stamp = Number(today.split('-').join(''));

  const specSlugs = await readSpecSlugs(REGIONS[0]);
  console.log('Speccs: ' + specSlugs.size);

  // Je Modus und Spec die Kandidaten aus allen Regionen, nach Wertung.
  const candidates = {};   // mode -> specID -> [{ name, realm, region, rating }]
  const unspecced = {};    // mode -> [{ name, realm, region, rating }]  (Spec noch unbekannt)
  for (const region of REGIONS) {
    const seasons = await api(region, '/data/wow/pvp-season/index', 'dynamic-' + region);
    const season = seasons && seasons.current_season && seasons.current_season.id;
    if (!season) { console.log(region + ': keine laufende PvP-Saison'); continue; }
    const index = await api(region, '/data/wow/pvp-season/' + season + '/pvp-leaderboard/index', 'dynamic-' + region);
    const boards = (index && index.leaderboards) || [];
    console.log(region.toUpperCase() + ': Saison ' + season + ', ' + boards.length + ' Ranglisten');
    for (const board of boards) {
      const name = String(board.name || '');
      const kind = name.split('-')[0];
      const mode = MODES[kind];
      if (!mode || (ONLY && !ONLY.includes(mode))) continue;
      let specID = 0;
      if (kind === 'shuffle' || kind === 'blitz') {
        // "shuffle-overall" und "blitz-overall" sind die Gesamtlisten - sie
        // sagen nicht, welche Spec einer spielt, und bleiben still liegen.
        if (name.endsWith('-overall')) continue;
        specID = specSlugs.get(name.slice(kind.length + 1)) || 0;
        if (!specID) { console.log('  ? ' + name + ': keine Spec dazu'); continue; }
      }
      let data = null;
      try {
        data = await api(region, '/data/wow/pvp-season/' + season + '/pvp-leaderboard/' + encodeURIComponent(name), 'dynamic-' + region);
      } catch (e) { console.log('  ! ' + name + ': ' + e.message); continue; }
      const entries = ((data && data.entries) || []).slice(0, specID ? MAX * 2 : SCAN);
      for (const e of entries) {
        if (!e.character || !e.character.name || !e.character.realm) continue;
        const row = {
          name: e.character.name, slug: e.character.realm.slug, region,
          rating: Number(e.rating) || 0,
        };
        if (specID) {
          const bySpec = candidates[mode] || (candidates[mode] = {});
          (bySpec[specID] || (bySpec[specID] = [])).push(row);
        } else {
          (unspecced[mode] || (unspecced[mode] = [])).push(row);
        }
      }
      process.stdout.write('.');
    }
    console.log('');
  }

  // 2v2, 3v3, RBG: die Spec steht nicht in der Rangliste - sie steht im
  // Profil. Von oben nach unten, bis jede Spec ihre Plaetze hat.
  for (const [mode, list] of Object.entries(unspecced)) {
    list.sort((a, b) => b.rating - a.rating);
    const bySpec = candidates[mode] || (candidates[mode] = {});
    let looked = 0;
    for (const row of list) {
      const specs = await specializations(row.region, row.slug, row.name);
      looked += 1;
      const active = specs && specs.active_specialization && Number(specs.active_specialization.id);
      if (!active) continue;
      const bucket = bySpec[active] || (bySpec[active] = []);
      if (bucket.length < MAX * 2) bucket.push(row);
    }
    console.log(mode + ': ' + looked + ' Profile gelesen, ' + Object.keys(bySpec).length + ' Speccs');
  }

  // Je Modus: die Profile lesen, pruefen, zusammenfassen.
  for (const [mode, bySpec] of Object.entries(candidates)) {
    const maps = heatmaps(mode);
    const out = {};
    let withBuild = 0;
    process.stdout.write('\n--- ' + mode + ' ');
    for (const [specKey, rows] of Object.entries(bySpec)) {
      const specID = Number(specKey);
      rows.sort((a, b) => b.rating - a.rating);
      const players = [];
      const seen = new Set();
      for (const row of rows) {
        const id = row.region + '/' + row.slug + '/' + row.name.toLowerCase();
        if (seen.has(id)) continue;
        seen.add(id);
        const specs = await specializations(row.region, row.slug, row.name);
        if (!specs) continue;
        const lo = loadoutOf(specs, specID);
        if (!lo) continue;
        const eq = await equipment(row.region, row.slug, row.name);
        if (!eq) continue;
        const active = specs.active_specialization && Number(specs.active_specialization.id) === specID;
        const realm = await realmName(row.region, row.slug);
        players.push({
          rank: players.length + 1, rating: row.rating,
          name: row.name, realm: realm + ' (' + row.region.toUpperCase() + ')', region: row.region,
          url: 'https://worldofwarcraft.blizzard.com/en-gb/character/' + row.region + '/' + row.slug + '/' + encodeURIComponent(row.name.toLowerCase()),
          verified: active && matchesHeatmap(lo.spells, maps[specKey]),
          text: lo.text, spells: lo.spells, pvp: lo.pvp, subTree: lo.subTree,
          gear: eq.gear, rows: eq.rows, ilvl: eq.ilvl,
        });
        if (players.length >= MAX) break;
      }
      if (!players.length) continue;
      const entry = summarise(players);
      if (entry.build) withBuild += 1;
      out[specID] = entry;
      process.stdout.write(entry.build ? '+' : '.');
    }
    console.log('\n  ' + Object.keys(out).length + ' Speccs, ' + withBuild + ' mit Build');
    if (!Object.keys(out).length) continue;
    const file = path.join(DIR, 'bnet-' + mode + '.json');
    fs.writeFileSync(file, JSON.stringify({ source: 'Battle.net', mode, builtOn: stamp, specs: out }, null, 1), 'utf8');
    console.log('geschrieben: ' + path.relative(BASE, file));
  }
  console.log('\nAnfragen: ' + requests);
  console.log('Jetzt zusammenbauen: node tools/build-recommendations.js .');
})().catch((err) => {
  console.error('Battle.net: ' + err.message);
  process.exit(1);
});
