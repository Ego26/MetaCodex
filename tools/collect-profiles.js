// Die Profile der Spieler, die oben stehen - von raider.io, mit fertiger
// Talentkette und kompletter Ausruestung.
//
//     node tools/collect-profiles.js <Pfad zum Repo>
//
// WARUM. Zwei Luecken hatten dieselbe Ursache: fuer Raid und PvP liefert
// keine Quelle eine fertige Importkette. Warcraft Logs kennt die Talente
// als Knoten, murlok als Heatmap - eine Kette hat keiner. Ein raider.io-
// Profil hat sie, und zwar die vom Client des Spielers geschriebene.
//
// Der Haken: das Profil zeigt den Build, den der Spieler JETZT traegt.
// Fuer einen Raider zwischen zwei Raidabenden ist das sein M+-Build. Also
// wird jede Kette GEPRUEFT, bevor sie als Raid- oder PvP-Build gilt:
//
//   Raid   Die Talente aus dem Profil muessen denen entsprechen, die
//          derselbe Spieler im geloggten Kampf hatte (Warcraft Logs
//          liefert sie Knoten fuer Knoten).
//   PvP    Die Talente muessen die murlok-Heatmap treffen: was dort
//          (fast) alle nehmen, muss im Profil stehen.
//
// Was die Pruefung nicht besteht, wird nicht zum Build - es bleibt nur
// als Profil fuer die Spieleransicht, und dort steht dabei, ob es
// verifiziert ist.
//
// Die Ausruestung kommt mit allen Bonus-IDs. Damit zeigt das Tooltip im
// Spiel genau das Stueck, das der Spieler traegt - Stufe, Pfad, Sockel.

const fs = require('fs');
const path = require('path');
const https = require('https');
const zlib = require('zlib');

const BASE = process.argv[2];
if (!BASE) {
  console.error('Aufruf: node tools/collect-profiles.js <Pfad zum Repo>');
  process.exit(1);
}
const DIR = path.join(BASE, 'tools', 'data');
// Je Spec und Modus so viele Spieler. Zehn stehen im Fenster; fuer die
// Pruefung werden bei Raid mehr angefragt, weil nicht jedes Profil den
// Kampf-Build traegt.
const MAX = Number(process.env.MC_PLAYERS || 10);
const MAX_RAID = Number(process.env.MC_RAID_PLAYERS || 20);
const DELAY = Number(process.env.MC_DELAY || 250);
const DRY = process.env.MC_DRYRUN === '1';
const ONLY = process.env.MC_MODES ? process.env.MC_MODES.split(',') : null;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function get(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, {
      headers: { 'User-Agent': 'MetaCodex-collector', 'Accept-Encoding': 'gzip' },
      timeout: 30000,
    }, (res) => {
      const enc = res.headers['content-encoding'];
      const stream = enc === 'gzip' ? res.pipe(zlib.createGunzip()) : res;
      let body = '';
      stream.on('data', (c) => (body += c));
      stream.on('end', () => {
        if (res.statusCode !== 200) {
          const err = new Error('HTTP ' + res.statusCode);
          err.status = res.statusCode;
          return reject(err);
        }
        try { resolve(JSON.parse(body)); } catch (e) { reject(e); }
      });
      stream.on('error', reject);
    });
    req.on('timeout', () => { req.destroy(); reject(new Error('Zeitueberschreitung')); });
    req.on('error', reject);
  });
}

// "Argent Dawn" -> "argent-dawn", "Kel'Thuzad" -> "kelthuzad". So schreibt
// raider.io seine Realm-Adressen. Ohne Backslash geschrieben, weil ein
// Backslash den Weg in diese Datei nicht sicher uebersteht.
function realmSlug(name) {
  const lower = String(name).toLowerCase().split("'").join('');
  let out = '', dash = false;
  for (const ch of lower) {
    const ok = (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9');
    if (ok) { out += ch; dash = false; } else if (!dash && out) { out += '-'; dash = true; }
  }
  return out.endsWith('-') ? out.slice(0, -1) : out;
}

const cache = new Map();
let requests = 0, failed = 0;

/** Ein Profil, oder null. Zweimal derselbe Spieler kostet nur einmal. */
async function profile(region, realm, name) {
  const key = region + '/' + realm + '/' + name.toLowerCase();
  if (cache.has(key)) return cache.get(key);
  const url = 'https://raider.io/api/v1/characters/profile?region=' + encodeURIComponent(region)
    + '&realm=' + encodeURIComponent(realm) + '&name=' + encodeURIComponent(name)
    + '&fields=talents,gear';
  let data = null;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    requests += 1;
    try {
      data = await get(url);
      break;
    } catch (err) {
      if (err.status === 429) { await sleep(15000); continue; }
      if (err.status === 400 || err.status === 404) break;
      await sleep(2000);
    }
  }
  await sleep(DELAY);
  let out = null;
  if (data && data.talentLoadout) {
    const lo = data.talentLoadout;
    const spells = [];
    for (const node of lo.loadout || []) {
      const entry = node.node && node.node.entries && node.node.entries[node.entryIndex || 0];
      const spell = entry && entry.spell && entry.spell.id;
      if (spell) spells.push({ spell, rank: Number(node.rank) || 1 });
    }
    const gear = {};
    for (const [slot, item] of Object.entries((data.gear && data.gear.items) || {})) {
      if (!item || !item.item_id) continue;
      gear[slot] = {
        id: item.item_id, ilvl: item.item_level || 0,
        bonuses: (item.bonuses || []).map(Number).filter(Boolean),
        enchant: item.enchant || 0,
        gems: (item.gems || []).map(Number).filter(Boolean),
      };
    }
    out = {
      spec: Number(lo.loadout_spec_id) || 0,
      text: lo.loadout_text || null,
      spells, gear,
      ilvl: (data.gear && data.gear.item_level_equipped) || 0,
      url: data.profile_url || null,
    };
  } else {
    failed += 1;
  }
  cache.set(key, out);
  return out;
}

// --- Pruefungen --------------------------------------------------------

/** Wie viel von A auch in B steht, 0..1. */
function coverage(a, b) {
  if (!a.size) return 1;
  let hit = 0;
  for (const x of a) if (b.has(x)) hit += 1;
  return hit / a.size;
}

/** Raid: das Profil muss den Kampf treffen - beide Richtungen. */
function matchesFight(prof, fightSpells) {
  const p = new Set(prof.spells.map((s) => s.spell));
  const f = new Set(fightSpells.map((s) => Number(String(s).split(':')[0])).filter(Boolean));
  if (!f.size || !p.size) return false;
  return coverage(f, p) >= 0.9 && coverage(p, f) >= 0.9;
}

/** PvP: was auf murlok (fast) alle nehmen, muss drinstehen. */
function matchesHeatmap(prof, talents) {
  const core = new Set((talents || []).filter((t) => !t.pvp && t.pct >= 90).map((t) => t.spell));
  if (!core.size) return false;
  const p = new Set(prof.spells.map((s) => s.spell));
  return coverage(core, p) >= 0.9;
}

// --- Builds aus verifizierten Profilen ---------------------------------

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
    text: top[0],
    nodes: top[1].spells,
    players: verified.length,
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

// --- Lauf ---------------------------------------------------------------

(async () => {
  const today = new Date().toISOString().slice(0, 10);
  const stamp = Number(today.split('-').join(''));
  const modes = [];

  // murlok: M+ und die fuenf PvP-Klammern. Spieler mit Rang.
  for (const file of fs.readdirSync(DIR)) {
    if (!file.startsWith('murlok-') || !file.endsWith('.json')) continue;
    const data = JSON.parse(fs.readFileSync(path.join(DIR, file), 'utf8'));
    modes.push({ mode: data.mode || file.slice(7, -5), kind: 'murlok', specs: data.specs });
  }
  // Warcraft Logs: die Raidmodi. Spieler ohne Rang, mit Kampftalenten.
  for (const file of fs.readdirSync(DIR)) {
    if (!file.startsWith('wcl-raid') || !file.endsWith('.json')) continue;
    const data = JSON.parse(fs.readFileSync(path.join(DIR, file), 'utf8'));
    modes.push({ mode: data.mode || file.slice(4, -5), kind: 'wcl', specs: data.specs });
  }

  for (const job of modes) {
    if (ONLY && !ONLY.includes(job.mode)) continue;
    const out = {};
    let withBuild = 0;
    process.stdout.write('\n--- ' + job.mode + ' ');
    for (const [specID, entry] of Object.entries(job.specs || {})) {
      const players = [];
      if (job.kind === 'murlok') {
        for (const p of (entry.players || []).slice(0, MAX)) {
          const prof = await profile(p.region, p.slug, p.character);
          players.push({
            rank: p.rank, name: p.name, realm: p.realm, region: p.region,
            url: 'https://murlok.io/character/' + p.region + '/' + p.slug + '/' + p.character,
            found: prof !== null,
            verified: prof !== null && prof.spec === Number(specID) && matchesHeatmap(prof, entry.talents),
            text: prof && prof.spec === Number(specID) ? prof.text : null,
            spells: prof ? prof.spells : [],
            gear: prof ? prof.gear : {},
            ilvl: prof ? prof.ilvl : 0,
          });
        }
      } else {
        let rank = 0;
        for (const p of (entry.lookup || []).slice(0, MAX_RAID)) {
          // Die Logs schreiben die Region gross ("TW"), raider.io will sie klein.
          const region = String(p.region).toLowerCase();
          const prof = await profile(region, realmSlug(p.server), p.name);
          rank += 1;
          players.push({
            rank, name: p.name, realm: p.server + ' (' + String(p.region).toUpperCase() + ')',
            region,
            url: 'https://raider.io/characters/' + region + '/' + realmSlug(p.server) + '/' + encodeURIComponent(p.name),
            found: prof !== null,
            verified: prof !== null && prof.spec === Number(specID) && matchesFight(prof, p.spells),
            text: prof && prof.spec === Number(specID) ? prof.text : null,
            spells: prof ? prof.spells : [],
            gear: prof ? prof.gear : {},
            ilvl: prof ? prof.ilvl : 0,
          });
          if (players.filter((x) => x.verified).length >= MAX) break;
        }
      }
      if (!players.length) continue;
      const derived = buildsFrom(players);
      if (derived.build) withBuild += 1;
      out[specID] = { players: players.slice(0, MAX_RAID), ...derived };
      process.stdout.write(derived.build ? '+' : '.');
    }
    console.log('\n  ' + Object.keys(out).length + ' Speccs, ' + withBuild + ' mit verifiziertem Build');
    if (DRY) continue;
    const file = path.join(DIR, 'prof-' + job.mode + '.json');
    fs.writeFileSync(file, JSON.stringify({
      source: 'raider.io', mode: job.mode, builtOn: stamp, profiles: true, specs: out,
    }, null, 1), 'utf8');
    console.log('geschrieben: ' + path.relative(BASE, file));
  }
  console.log('\nAnfragen: ' + requests + ', ohne Profil: ' + failed);
  console.log('Jetzt zusammenbauen: node tools/build-recommendations.js .');
})();
