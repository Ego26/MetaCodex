// Sammelt M+ Daten von raider.io.
//
//     node tools/collect-raiderio.js <Pfad zum Repo> [Seiten]
//
// WARUM DIESE QUELLE. Warcraft Logs rechnet in Punkten je Stunde, und ein
// vollstaendiger Lauf verbrannte sie an einem Abend - drei Sammlungen
// starben danach an HTTP 429 und schrieben nichts. raider.io hat eine
// offene, dokumentierte API ohne dieses Kontingent.
//
// Sie gibt sogar mehr: die Talent-Importkette liegt FERTIG vor, und jeder
// Knoten traegt `grantedNode`. Genau dieses Bit hatte meinem eigenen
// Kodierer gefehlt - die Quelle hat den Fehler bestaetigt, bevor ich ihn
// ganz verstanden hatte.
//
// Was hier NICHT herkommt: Verbrauchsgueter und Raid. Die fuehrt kein
// Aggregator fertig. Dafuer bleibt Warcraft Logs, und weil nur noch
// dieser Rest dort geholt wird, reicht das Kontingent wieder.

const fs = require('fs');
const path = require('path');
const https = require('https');
const zlib = require('zlib');
const Loadout = require('./loadout');

const BASE = process.argv[2];
if (!BASE) {
  console.error('Aufruf: node tools/collect-raiderio.js <Pfad zum Repo> [Seiten]');
  process.exit(1);
}
const PAGES = Number(process.argv[3] || process.env.MC_PAGES || 12);
const PER_DUNGEON = !!process.env.MC_DUNGEONS;
const DRY = !!process.env.MC_DRYRUN;

// Wie viele Profile hoechstens abgerufen werden. Jedes ist eine Anfrage;
// die Laufliste selbst kostet nur eine je zwanzig Laeufe.
const PROFILE_LIMIT = Number(process.env.MC_PROFILES || 900);

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
          const err = new Error('HTTP ' + res.statusCode + ': ' + body.slice(0, 200));
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

// Geduldig, aus demselben Grund wie beim anderen Sammler: eine Sperre ist
// eine Pause, kein Abbruch. Wer daran stirbt, wirft die Sammlung weg.
async function patient(url, tries) {
  tries = tries || 0;
  try {
    return await get(url);
  } catch (err) {
    if (tries >= 3) throw err;
    await sleep(2000 * (tries + 1));
    return patient(url, tries + 1);
  }
}

// --- Plaetze ---------------------------------------------------------
//
// raider.io benennt sie anders als der Katalog und anders als murlok.
// Zwei Tabellen, weil es zwei Fragen sind: wo wird verzaubert, und wie
// heisst der Platz in der Anzeige.
const ENCHANT_SLOT = {
  head: 'helm', shoulder: 'shoulders', chest: 'chest', legs: 'legs',
  feet: 'boots', finger1: 'ring', finger2: 'ring', mainhand: 'weapon',
};
const GEAR_SLOT = {
  head: 'Head', neck: 'Neck', shoulder: 'Shoulders', back: 'Back',
  chest: 'Chest', waist: 'Waist', wrist: 'Wrist', hands: 'Hands',
  legs: 'Legs', feet: 'Feet', finger1: 'Rings', finger2: 'Rings',
  trinket1: 'Trinkets', trinket2: 'Trinkets',
  mainhand: 'Main Hand', offhand: 'Off Hand',
};

const slug = (text) => String(text).toLowerCase()
  .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

(async () => {
  console.log('raider.io');

  // Die Saison wird gefragt, nicht geraten: beim naechsten Wechsel waere
  // eine feste Angabe still falsch.
  const stat = await patient('https://raider.io/api/v1/mythic-plus/static-data?expansion_id=11');
  const seasons = (stat.seasons || [])
    .map((s) => s.slug)
    .filter((s) => /^season-mn-\d+$/.test(s))
    .sort();
  const season = seasons[seasons.length - 1];
  if (!season) throw new Error('Keine Saison gefunden.');
  console.log('  Saison: ' + season);

  const enchantMap = JSON.parse(fs.readFileSync(
    path.join(BASE, 'tools', 'data', 'enchant-map.json'), 'utf8'));
  console.log('  Verzauberungs-IDs: ' + Object.keys(enchantMap).length);

  // Welche Bonus-ID welche Werte setzt, und welche eine Verzierung
  // anhaengt. Beides steht in den Spieldaten und wird vom Katalog
  // herausgeschrieben; ohne die Karte zaehlen wir es eben nicht mit.
  let bonusMap = { stats: {}, embellish: {} };
  try {
    bonusMap = JSON.parse(fs.readFileSync(
      path.join(BASE, 'tools', 'data', 'bonus-map.json'), 'utf8'));
    console.log('  Werte-Bonuslisten: ' + Object.keys(bonusMap.stats).length
      + ', Verzierungen: ' + Object.keys(bonusMap.embellish).length);
  } catch (err) {
    console.log('  Keine bonus-map.json - Werte und Verzierungen bleiben ungezaehlt.');
  }

  // --- Laeufe einsammeln ---------------------------------------------
  const members = [];
  // Builds aus der LAUFLISTE, nicht aus den Profilen.
  //
  // Die Laufliste traegt die Importkette je Spieler schon mit - 84 von
  // 100 Eintraegen haben eine, und eine Seite kostet EINE Anfrage fuer
  // zwanzig Laeufe. Ueber die Profile waeren es neunhundert Anfragen
  // fuer neunhundert Spieler; so sind es dreissig fuer dreitausend.
  //
  // Das ist der Unterschied zwischen "elf von siebenundzwanzig Speccs
  // haben einen Dungeon-Build" und einer brauchbaren Stichprobe.
  //
  // Jeder String wird ENTSCHLUESSELT (tools/loadout.js, geprueft gegen
  // 60 Profile mit String und Knoten nebeneinander). Damit liefert die
  // Laufliste nicht nur die Kette, sondern die Talente selbst - und den
  // Held-Baum, der aus einem Build zwei macht.
  const runBuilds = {};   // mode -> specID -> text -> Anzahl
  const decodedRuns = [];  // { mode, specID, text, decoded }
  const noteBuild = (mode, specID, text) => {
    if (!text) return;
    const byMode = runBuilds[mode] || (runBuilds[mode] = {});
    const bySpec = byMode[specID] || (byMode[specID] = {});
    bySpec[text] = (bySpec[text] || 0) + 1;
    const treeId = Loadout.treeOfSpec(BASE, specID);
    let decoded = null;
    try { decoded = treeId && Loadout.decode(BASE, text, treeId); } catch (e) { decoded = null; }
    if (decoded && decoded.spec === Number(specID)) decodedRuns.push({ mode, specID, text, decoded });
  };
  for (let page = 0; page < PAGES; page++) {
    const url = 'https://raider.io/api/v1/mythic-plus/runs?season=' + season
      + '&region=world&affixes=all&page=' + page;
    let data;
    try {
      data = await patient(url);
    } catch (err) {
      console.log('  ! Seite ' + page + ': ' + err.message);
      break;
    }
    const list = data.rankings || [];
    if (!list.length) break;
    for (const rank of list) {
      const run = rank.run || {};
      for (const entry of run.roster || []) {
        const ch = entry.character || {};
        if (!ch.spec || !ch.spec.id) continue;
        members.push({
          specID: Number(ch.spec.id),
          // Die fertige Importkette, direkt aus der Laufliste.
          loadout: entry.loadout || null,
          name: ch.name,
          realm: ch.realm && ch.realm.slug,
          region: ch.region && ch.region.slug,
          key: Number(run.mythic_level) || 0,
          dungeon: run.dungeon && run.dungeon.name,
        });
      }
    }
    // Und gleich zaehlen, solange die Zuordnung zum Dungeon da ist.
    for (const m of members.slice(-100)) {
      noteBuild('mplus', m.specID, m.loadout);
      if (PER_DUNGEON && m.dungeon) {
        noteBuild('mplus/' + slug(m.dungeon), m.specID, m.loadout);
      }
    }
    process.stdout.write('.');
    await sleep(250);
  }
  console.log('\n  Spieler in den Laeufen: ' + members.length);
  {
    let ketten = 0;
    for (const bySpec of Object.values(runBuilds['mplus'] || {})) {
      for (const n of Object.values(bySpec)) ketten += n;
    }
    console.log('  davon mit Talentkette: ' + ketten);
  }
  if (!members.length) throw new Error('Keine Laeufe gefunden.');

  // --- Reihum ziehen --------------------------------------------------
  //
  // Dieselbe Falle wie beim anderen Sammler: die Laeufe kommen nach
  // Wertung sortiert, und die ersten neunhundert waeren fast alle vom
  // selben Dungeon und von denselben zwei Speccs.
  const buckets = new Map();
  for (const m of members) {
    const key = m.specID + '|' + (m.dungeon || '-');
    if (!buckets.has(key)) buckets.set(key, []);
    buckets.get(key).push(m);
  }
  const lists = [...buckets.values()];
  const chosen = [];
  for (let round = 0; chosen.length < PROFILE_LIMIT; round++) {
    let took = 0;
    for (const list of lists) {
      if (round >= list.length) continue;
      chosen.push(list[round]);
      took++;
      if (chosen.length >= PROFILE_LIMIT) break;
    }
    if (!took) break;
  }
  console.log('  Profile abrufen: ' + chosen.length
    + ', verteilt auf ' + lists.length + ' Gruppen (Spec x Dungeon)');

  // --- Zaehlwerk -------------------------------------------------------
  const tallies = {};
  const meta = {};
  // Bonus-IDs je Gegenstand, EINMAL statt je Zeile.
  //
  // Ohne sie zeigt das Tooltip im Spiel die Grundstufe - "Gegenstands-
  // stufe 28" unter einer Zeile, die 334 sagt. Sie gehoeren zum
  // Gegenstand und nicht zur Beobachtung, also stehen sie einmal in
  // einer eigenen Tabelle: knapp vierzig Kilobyte statt eines
  // Megabyte, wenn jede Zeile sie mitschleppte.
  const bonuses = new Map();   // itemID -> { ilvl, list }
  // Und dieselben Listen je STUFE.
  //
  // Ein Handwerksstueck traegt in seinen Bonus-IDs alles, was es
  // ausmacht: Qualitaet, Aufwertung, Verzierung, Werte. Eine einzelne
  // davon in einen Link zu setzen reicht dem Client nicht - dann steht
  // dort weiter "Zufallswert 1". Und die Stufen eines Handwerksstuecks
  // kommen nicht aus der Schluesselbelohnung, sondern aus genau diesen
  // Listen. Wer vergleichen will, was ein Stueck auf 311 und auf 318
  // kann, braucht beide Listen - also heben wir sie auf, je Stufe die
  // haeufigste.
  const byLevel = new Map();   // itemID -> Map(ilvl -> Map(listKey -> n))
  const entryFor = (mode, specID) => {
    const t = tallies[mode] || (tallies[mode] = {});
    return t[specID] || (t[specID] = {
      enchants: {}, gems: {}, gear: {}, talents: {}, builds: {},
      // Die fertige Importkette je Build.
      //
      // Sie liegt hier vor - vom Spiel erzeugt, nicht nachgebaut. Ich
      // hatte einen eigenen Kodierer dafuer geschrieben und zwei Bits
      // darin falsch; diese Zeichenkette hat das Problem nie.
      buildText: {},
      maxKey: {}, players: 0,
      // Was auf den Handwerksstuecken steht.
      //
      // Zweimal, weil es zwei Fragen sind: "welche Werte nimmt man auf
      // DIESEM Stueck" beantwortet itemStats (und daraus wird der Link
      // gebaut, damit das Tooltip nicht "Zufallswert 1" zeigt), "welche
      // Werte nimmt man ueberhaupt" beantwortet craftStats.
      itemStats: {}, craftStats: {}, embellish: {},
      // Talente zaehlen eigene Spieler: die Laufliste, nicht die Profile.
      talentPlayers: 0,
      // Je Held-Baum dasselbe Zaehlwerk noch einmal.
      hero: {},
    });
  };

  // Die entschluesselten Strings der Laufliste - in beide Zaehlwerke,
  // das der Spec und das ihres Held-Baums.
  const tallyLoadout = (target, decoded, text) => {
    target.talentPlayers = (target.talentPlayers || 0) + 1;
    const picked = [];
    for (const n of decoded.nodes) {
      if (!n.spell) continue;
      picked.push(n.spell + ':' + n.rank);
      const key = n.spell + '|' + n.rank;
      target.talents[key] = (target.talents[key] || 0) + 1;
    }
    if (!picked.length) return;
    picked.sort();
    const signature = picked.join(',');
    target.builds[signature] = (target.builds[signature] || 0) + 1;
    if (text && !target.buildText[signature]) target.buildText[signature] = text;
  };
  let decodedCount = 0, heroSplit = 0;
  for (const run of decodedRuns) {
    const e = entryFor(run.mode, run.specID);
    tallyLoadout(e, run.decoded, run.text);
    decodedCount += 1;
    if (run.decoded.subTree) {
      const h = e.hero[run.decoded.subTree] || (e.hero[run.decoded.subTree] = {
        talents: {}, builds: {}, buildText: {}, talentPlayers: 0,
      });
      tallyLoadout(h, run.decoded, run.text);
      heroSplit += 1;
    }
  }
  console.log('  Strings entschluesselt: ' + decodedCount + ', davon mit Held-Baum: ' + heroSplit);

  let read = 0;
  let failed = 0;
  for (const m of chosen) {
    if (!m.name || !m.realm || !m.region) { failed++; continue; }
    const url = 'https://raider.io/api/v1/characters/profile'
      + '?region=' + m.region + '&realm=' + encodeURIComponent(m.realm)
      + '&name=' + encodeURIComponent(m.name) + '&fields=gear,talents';
    let prof;
    try {
      prof = await patient(url);
    } catch (err) {
      failed++;
      process.stdout.write('!');
      await sleep(200);
      continue;
    }

    const modes = ['mplus'];
    if (PER_DUNGEON && m.dungeon) {
      const name = 'mplus/' + slug(m.dungeon);
      modes.push(name);
      meta[name] = { mode: 'mplus', dungeon: m.dungeon };
    }
    const specs = modes.map((mode) => entryFor(mode, m.specID));
    for (const spec of specs) spec.players++;

    const bump = (bucket, id, slotKey) => {
      for (const spec of specs) {
        if (m.key > (spec.maxKey[id] || 0)) spec.maxKey[id] = m.key;
        if (slotKey) {
          const group = spec[bucket][slotKey] || (spec[bucket][slotKey] = {});
          group[id] = (group[id] || 0) + 1;
        } else {
          spec[bucket][id] = (spec[bucket][id] || 0) + 1;
        }
      }
    };

    // Zwei darf man tragen, und welche zwei zusammen - das ist die
    // Frage. Also erst sammeln, dann als Paar zaehlen.
    const embellished = new Set();
    for (const [slot, item] of Object.entries((prof.gear && prof.gear.items) || {})) {
      if (!item || !item.item_id) continue;

      // Der Satz zur HOECHSTEN Stufe: die Zeile nennt die hoechste, und
      // ein Tooltip zu einer anderen waere wieder falsch.
      const ilvl = Number(item.item_level) || 0;
      const known = bonuses.get(item.item_id);
      if ((!known || ilvl > known.ilvl) && Array.isArray(item.bonuses)) {
        bonuses.set(item.item_id, { ilvl, list: item.bonuses });
      }
      if (ilvl > 0 && Array.isArray(item.bonuses) && item.bonuses.length) {
        const levels = byLevel.get(item.item_id) || byLevel.set(item.item_id, new Map()).get(item.item_id);
        const lists = levels.get(ilvl) || levels.set(ilvl, new Map()).get(ilvl);
        const key = item.bonuses.slice().sort((a, b) => a - b).join(',');
        lists.set(key, (lists.get(key) || 0) + 1);
      }

      const display = GEAR_SLOT[slot];
      if (display) {
        for (const spec of specs) {
          if (m.key > (spec.maxKey[item.item_id] || 0)) spec.maxKey[item.item_id] = m.key;
          const group = spec.gear[display] || (spec.gear[display] = {});
          const row = group[item.item_id] || (group[item.item_id] = { n: 0, ilvl: 0 });
          row.n++;
          row.ilvl = Math.max(row.ilvl, Number(item.item_level) || 0);
        }
      }

      // Werte und Verzierung stehen in den Bonus-IDs, nicht am
      // Gegenstand: ein Handwerksstueck traegt am Gegenstand
      // "Zufallswert 1" und "Zufallswert 2".
      for (const b of item.bonuses || []) {
        if (bonusMap.stats[b]) {
          for (const spec of specs) {
            const per = spec.itemStats[item.item_id] || (spec.itemStats[item.item_id] = {});
            per[b] = (per[b] || 0) + 1;
            spec.craftStats[b] = (spec.craftStats[b] || 0) + 1;
          }
        }
        const reagent = bonusMap.embellish[b];
        if (reagent) embellished.add(reagent);
      }

      const enchantSlot = ENCHANT_SLOT[slot];
      if (enchantSlot && item.enchant) {
        const itemID = enchantMap[item.enchant];
        if (itemID) bump('enchants', itemID, enchantSlot);
      }
      for (const gem of item.gems || []) {
        if (gem) bump('gems', gem);
      }
    }

    // Zwei Verzierungen darf man tragen, und welche zwei ZUSAMMEN, das
    // ist die Frage - einzeln gezaehlt stuenden zwei Haelften einer
    // Entscheidung untereinander, als waeren es zwei.
    if (embellished.size) {
      const key = [...embellished].sort((a, b) => a - b).join(',');
      for (const spec of specs) spec.embellish[key] = (spec.embellish[key] || 0) + 1;
    }

    // Talente kommen aus der Laufliste (siehe oben), nicht aus dem Profil:
    // derselbe Spieler steht dort schon, und zweimal zaehlen verzerrt.
    read++;
    if (read % 25 === 0) process.stdout.write('.');
    await sleep(120);
  }
  console.log('\n  Profile gelesen: ' + read
    + (failed ? ', ' + failed + ' fehlgeschlagen' : ''));

  // --- In Anteile ------------------------------------------------------
  const now = new Date();
  const stamp = now.getFullYear() * 10000 + (now.getMonth() + 1) * 100 + now.getDate();
  const dir = path.join(BASE, 'tools', 'data');
  fs.mkdirSync(dir, { recursive: true });

  for (const [mode, tally] of Object.entries(tallies)) {
    const specs = {};
    for (const [specID, entry] of Object.entries(tally)) {
      const players = Math.max(1, entry.players);
      const out = { enchants: {}, gems: [], gear: {} };

      for (const [slotKey, counts] of Object.entries(entry.enchants)) {
        const total = Object.values(counts).reduce((a, b) => a + b, 0);
        out.enchants[slotKey] = Object.entries(counts)
          .map(([id, n]) => ({
            id: Number(id), pct: Math.round((n / total) * 100),
            maxKey: entry.maxKey[id] || 0,
          }))
          .sort((a, b) => b.pct - a.pct);
      }

      const gemTotal = Object.values(entry.gems).reduce((a, b) => a + b, 0);
      if (gemTotal) {
        out.gems = Object.entries(entry.gems)
          .map(([id, n]) => ({
            id: Number(id), pct: Math.round((n / gemTotal) * 100),
            maxKey: entry.maxKey[id] || 0,
          }))
          .sort((a, b) => b.pct - a.pct);
      }

      for (const [slotKey, items] of Object.entries(entry.gear)) {
        const rows = Object.entries(items)
          .map(([id, row]) => {
            const out = {
              id: Number(id), ilvl: row.ilvl,
              pct: Math.round((row.n / players) * 100),
              maxKey: entry.maxKey[id] || 0,
            };
            // Die haeufigste Wertewahl DIESES Stuecks. Ohne sie zeigt
            // das Tooltip im Spiel "Zufallswert 1" und "Zufallswert 2",
            // und die Rangnummern der Zweitwerte fallen weg - es gibt
            // ja keine Werte, an die man sie haengen koennte.
            const per = entry.itemStats[out.id];
            if (per) {
              const best = Object.entries(per).sort((a, b) => b[1] - a[1])[0];
              const total = Object.values(per).reduce((a, b) => a + b, 0);
              out.statBonus = Number(best[0]);
              out.stats = bonusMap.stats[best[0]];
              out.statPct = Math.round((best[1] / total) * 100);
            }
            return out;
          })
          .sort((a, b) => b.pct - a.pct)
          .slice(0, 5);
        if (rows.length) out.gear[slotKey] = rows;
      }

      // Welche Werte auf Handwerksstuecken ueberhaupt gewaehlt werden.
      // Gezaehlt werden STUECKE, nicht Spieler: ein Spieler traegt
      // mehrere, und jedes ist eine eigene Entscheidung.
      const statTotal = Object.values(entry.craftStats).reduce((a, b) => a + b, 0);
      if (statTotal > 0) {
        out.craftStats = Object.entries(entry.craftStats)
          .map(([bonus, n]) => ({
            bonus: Number(bonus), stats: bonusMap.stats[bonus],
            pct: Math.round((n / statTotal) * 100),
          }))
          .filter((r) => r.stats && r.pct > 0)
          .sort((a, b) => b.pct - a.pct);
      }

      // Und die Verzierungen, als Paar. Der Nenner sind die gemessenen
      // Spieler - wer keine traegt, ist Teil der Antwort.
      const embRows = Object.entries(entry.embellish)
        .map(([key, n]) => ({
          ids: key.split(',').map(Number),
          pct: Math.round((n / players) * 100),
        }))
        .filter((r) => r.pct > 0)
        .sort((a, b) => b.pct - a.pct)
        .slice(0, 8);
      if (embRows.length) out.embellish = embRows;

      // Talente, Build, Alternativen - fuer die Spec, und dann je Held-Baum.
      // Der Nenner sind die entschluesselten Strings, nicht die Profile.
      const talentOut = (src) => {
        const denom = Math.max(1, src.talentPlayers || 0);
        const res = {};
        const rows = Object.entries(src.talents || {})
          .map(([key, n]) => {
            const parts = key.split('|');
            return { spell: Number(parts[0]), rank: Number(parts[1]), pct: Math.round((n / denom) * 100) };
          })
          .filter((r) => r.pct > 0)
          .sort((a, b) => b.pct - a.pct);
        if (rows.length) res.talents = rows;
        const builds = Object.entries(src.builds || {}).sort((a, b) => b[1] - a[1]);
        const asNodes = (signature) => signature.split(',').map((part) => {
          const bits = part.split(':');
          return { spell: Number(bits[0]), rank: Number(bits[1]) };
        });
        if (builds.length) {
          const topNodes = asNodes(builds[0][0]);
          res.build = {
            pct: Math.round((builds[0][1] / denom) * 100),
            text: src.buildText[builds[0][0]] || null,
            nodes: topNodes,
          };
          const topSet = new Set(topNodes.map((n) => n.spell));
          const others = [];
          for (const [signature, count] of builds.slice(1, 12)) {
            const nodes = asNodes(signature);
            const set = new Set(nodes.map((n) => n.spell));
            const added = nodes.filter((n) => !topSet.has(n.spell)).map((n) => n.spell);
            const removed = topNodes.filter((n) => !set.has(n.spell)).map((n) => n.spell);
            if (!added.length && !removed.length) continue;
            if (others.length >= 6) break;
            others.push({ pct: Math.round((count / denom) * 100), text: src.buildText[signature] || null, added, removed });
          }
          if (others.length) res.builds = others;
        }
        return res;
      };
      Object.assign(out, talentOut(entry));
      if (entry.hero && Object.keys(entry.hero).length) {
        const total = Math.max(1, entry.talentPlayers || 0);
        out.hero = {};
        for (const [sub, h] of Object.entries(entry.hero)) {
          out.hero[sub] = { players: h.talentPlayers || 0, pct: Math.round(((h.talentPlayers || 0) / total) * 100), ...talentOut(h) };
        }
      }
      specs[specID] = out;
    }

    const info = meta[mode] || { mode };
    const file = path.join(dir, 'rio-' + mode.replace('/', '--') + '.json');
    const payload = { source: 'raider.io', mode: info.mode, builtOn: stamp, specs };
    // Nur die Gegenstaende, die in diesem Modus vorkommen.
    const used = new Set();
    for (const entry of Object.values(specs)) {
      for (const list of Object.values(entry.gear || {})) {
        for (const row of list) used.add(row.id);
      }
    }
    const out = {};
    for (const id of used) {
      const hit = bonuses.get(id);
      if (hit && hit.list.length) out[id] = hit.list;
    }
    if (Object.keys(out).length) payload.bonuses = out;

    // Und je Stufe die haeufigste Liste - aber nur fuer die Stuecke, bei
    // denen es einen Unterschied macht: Handwerk. Fuer alles andere
    // genuegt die Stufendifferenz, die der Katalog fuehrt.
    const perLevel = {};
    for (const id of used) {
      const levels = byLevel.get(id);
      if (!levels) continue;
      const rows = [];
      for (const [ilvl, lists] of levels) {
        const best = [...lists.entries()].sort((a, b) => b[1] - a[1])[0];
        const ids = best[0].split(',').map(Number);
        // Nur wo eine Wertewahl drinsteckt: das sind die Stuecke, deren
        // Tooltip ohne die volle Liste "Zufallswert 1" zeigt.
        if (!ids.some((b) => bonusMap.stats[b])) continue;
        rows.push({ ilvl, n: best[1], ids });
      }
      if (rows.length) {
        rows.sort((a, b) => a.ilvl - b.ilvl);
        perLevel[id] = rows;
      }
    }
    if (Object.keys(perLevel).length) payload.craftLevels = perLevel;
    if (info.dungeon) payload.dungeon = info.dungeon;

    if (DRY) {
      const pair = Object.entries(specs)[0] || [];
      console.log('\nProbelauf ' + mode + ': ' + Object.keys(specs).length
        + ' Speccs, Spec ' + pair[0]);
      const one = pair[1];
      if (one) {
        console.log('  Plaetze mit Verzauberung: ' + Object.keys(one.enchants).join(', '));
        console.log('  Werte auf Handwerk: ' + ((one.craftStats || [])
          .map((r) => r.stats.join('+') + ' ' + r.pct + '%').join(', ') || 'keine'));
        console.log('  Verzierungen: ' + ((one.embellish || [])
          .map((r) => r.ids.join('+') + ' ' + r.pct + '%').join(', ') || 'keine'));
        for (const [slot, list] of Object.entries(one.gear || {})) {
          const hit = (list || []).find((r) => r.statBonus);
          if (hit) {
            console.log('  Beispiel ' + slot + ': ' + hit.id + ' -> '
              + hit.stats.join('+') + ' (' + hit.statPct + '% der Traeger)');
            break;
          }
        }
        console.log('  Steine: ' + (one.gems || []).length
          + ', Ausruestungsplaetze: ' + Object.keys(one.gear).length
          + ', Talente: ' + (one.talents || []).length
          + ', Build: ' + (one.build ? one.build.nodes.length + ' Knoten' : 'keiner'));
      }
      console.log('  ' + file + ' bleibt unberuehrt.');
      continue;
    }

    fs.writeFileSync(file, JSON.stringify(payload, null, 1), 'utf8');
    console.log('geschrieben: ' + file + ' (' + Object.keys(specs).length + ' Speccs)');
  }

  console.log('\nJetzt zusammenbauen: node tools/build-recommendations.js .');
})().catch((err) => {
  console.error('\nFEHLER: ' + err.message);
  process.exit(1);
});
