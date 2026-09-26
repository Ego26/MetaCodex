// Baut Data/Recommendations.lua aus allen Zwischenstaenden in tools/data.
//
//     node tools/build-recommendations.js <Pfad zum AddOn-Ordner>
//
// Warum getrennt von den Sammlern: M+ kommt von murlok.io, Raid aus der
// Warcraft-Logs-API. Schriebe jeder Sammler die Lua-Datei direkt, loeschte
// der zweite Lauf die Arbeit des ersten. Jeder schreibt deshalb nur seine
// eigene JSON-Datei, und hier werden sie zusammengelegt.
//
// Ein Modus, zu dem keine Datei existiert, fehlt in der Ausgabe - und das
// Addon zeigt seinen Reiter dann grau. Das ist gewollt: eine leere Liste
// und "keine Daten" sind zwei verschiedene Aussagen.

const fs = require('fs');
const path = require('path');

const BASE = process.argv[2];
if (!BASE) {
  console.error('Aufruf: node tools/build-recommendations.js <Pfad zum AddOn-Ordner>');
  process.exit(1);
}

const dir = path.join(BASE, 'tools', 'data');
if (!fs.existsSync(dir)) {
  console.error(`Kein Ordner ${dir}. Erst einen Sammler laufen lassen.`);
  process.exit(1);
}

function luaString(s) {
  return '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
}

// Modus -> Quelle -> Speccs.
//
// Frueher gewann je Modus die neueste Datei, und die Quelle war nur ein
// Etikett im Kopf. Damit liess sich im Spiel nichts auswaehlen: zwei
// Plattformen, die denselben Modus messen, haetten einander ueberschrieben.
// Jetzt stehen beide nebeneinander, und die Oberflaeche kann fragen.
const byMode = {};
const sources = new Set();
// Welche Dungeon-Varianten es zu einem Modus gibt.
//
// Als eigene Tabelle statt als Namensmuster: die Oberflaeche soll eine
// Liste lesen, nicht Zeichenketten zerlegen. Wer den Trenner aendert,
// zerbricht sonst stillschweigend die Auswahl.
const dungeons = {};
// Je Handwerksstueck: welche Bonus-Listen auf welcher Stufe gemessen
// wurden.
//
// WARUM DIE GANZE LISTE. Ein Handwerksstueck traegt in seinen Bonus-IDs
// alles, was es ausmacht: die Qualitaetsstufe, die Aufwertung, die
// Verzierung und die Werte. Setzt man nur EINE davon in einen Link -
// die Werte zum Beispiel -, zeigt der Client weiter "Zufallswert 1" und
// "Zufallswert 2". Er braucht die Liste, wie sie am Stueck stand.
//
// Und die Stufen: ein Handwerksstueck wird nicht mit einem
// Schluesselstein aufgewertet, sondern beim Herstellen und mit Mistcrests.
// Welche Stufen es ueberhaupt gibt, steht also nicht in der
// Belohnungstabelle der Dungeons - es steht in diesen Listen.
const craftLevels = {};
let newest = 0;
const profileParts = [];
// Fuer das Spieler-Addon: Modus -> Spec -> Spieler mit Ausruestung.
// Welche Bonus-ID welche Werte setzt, und welche eine Verzierung
// anhaengt. Der Katalog schreibt sie heraus.
let bonusMap = { stats: {}, embellish: {} };
try {
  bonusMap = JSON.parse(fs.readFileSync(path.join(dir, 'bonus-map.json'), 'utf8'));
} catch (err) {
  console.log('Keine bonus-map.json - Verzierungen bleiben ungezaehlt.');
}

const profilesOut = {};
// Zwei Quellen koennen denselben Spieler fuehren; er steht dann einmal.
function addProfiles(mode, specID, profiles) {
  const byMode = profilesOut[mode] || (profilesOut[mode] = {});
  const list = byMode[specID] || (byMode[specID] = []);
  for (const pl of profiles) {
    if (!pl.found) continue;
    if (list.some((x) => x.name === pl.name && x.realm === pl.realm)) continue;
    list.push(pl);
  }
}

for (const name of fs.readdirSync(dir).sort()) {
  if (!name.endsWith('.json')) continue;
  const part = JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8'));
  // Profile kommen NACH allen anderen dran: sie ergaenzen, was eine
  // Quelle nicht hat, und dafuer muss die Quelle schon da sein.
  if (part.craftLevels) {
    for (const [id, rows] of Object.entries(part.craftLevels)) {
      const have = craftLevels[id] || (craftLevels[id] = {});
      for (const row of rows) {
        // Die Stufe, die mehr Traeger hat, gewinnt: zwei Quellen
        // koennen dasselbe Stueck verschieden gesehen haben.
        const old = have[row.ilvl];
        if (!old || (row.n || 0) > (old.n || 0)) have[row.ilvl] = row;
      }
    }
  }
  if (part.profiles) { profileParts.push(part); continue; }
  if (!part.mode || !part.specs || !part.source) {
    console.log(`  ? ${name}: kein Modus, keine Quelle oder keine Speccs, uebersprungen`);
    continue;
  }
  // Ein Dungeon bekommt einen eigenen Modusschluessel. Ohne das wuerde
  // die achte Datei die siebte ueberschreiben - gleicher Modus,
  // gleiche Quelle.
  const slug = part.dungeon
    ? String(part.dungeon).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
    : null;
  const key = slug ? `${part.mode}/${slug}` : part.mode;
  if (slug) {
    const list = dungeons[part.mode] || (dungeons[part.mode] = []);
    if (!list.some((d) => d.key === key)) list.push({ key, name: part.dungeon, group: part.raid || null });
  }
  // Schluesselstufen gibt es nur in M+. Was aus einem Raidlauf kommt,
  // traegt dort eine Gegenstandsstufen-Klasse - kein Wert, den jemand
  // als "+333" lesen sollte.
  if (!String(part.mode).startsWith('mplus')) {
    for (const entry of Object.values(part.specs)) {
      for (const row of entry.consumables || []) delete row.maxKey;
      for (const list of Object.values(entry.enchants || {})) {
        for (const row of list) delete row.maxKey;
      }
      for (const row of entry.gems || []) delete row.maxKey;
      for (const list of Object.values(entry.gear || {})) {
        for (const row of list) delete row.maxKey;
      }
    }
  }
  const mode = byMode[key] || (byMode[key] = {});
  // Zwei Dateien derselben Quelle und desselben Modus: die neuere gewinnt.
  const existing = mode[part.source];
  if (existing && (existing.builtOn || 0) > (part.builtOn || 0)) continue;
  mode[part.source] = part;
  sources.add(part.source);
  newest = Math.max(newest, part.builtOn || 0);
  // Eine Quelle, die ihre Spieler samt Ausruestung mitbringt (Battle.net):
  // die Profile gehen in das Spieler-Addon, die Rangliste bleibt hier.
  for (const [specID, entry] of Object.entries(part.specs)) {
    if (!entry.profiles) continue;
    addProfiles(part.mode, specID, entry.profiles);
    delete entry.profiles;
  }
  console.log(`  + ${name}: ${Object.keys(part.specs).length} Speccs -> ${key} / ${part.source}`);
}

for (const part of profileParts) {
  const mode = byMode[part.mode] || (byMode[part.mode] = {});
  const target = mode[part.source] || (mode[part.source] = {
    source: part.source, mode: part.mode, builtOn: part.builtOn, specs: {},
  });
  sources.add(part.source);
  newest = Math.max(newest, part.builtOn || 0);
  let builds = 0, players = 0;
  for (const [specID, entry] of Object.entries(part.specs)) {
    const spec = target.specs[specID] || (target.specs[specID] = {});
    // Ein verifizierter Build zaehlt nur, wo die Quelle keinen hat -
    // die Ketten aus der Laufliste (M+) sind die breitere Stichprobe.
    if (entry.build && !(spec.build && spec.build.text)) {
      spec.build = entry.build;
      if (entry.builds) spec.builds = entry.builds;
      builds += 1;
    }
    // Die Rangliste: nur, wenn keine Quelle in diesem Modus eine fuehrt
    // (Raid). Bei PvP und M+ hat murlok sie schon, mit echtem Rang.
    const anyPlayers = Object.values(mode).some((src) => src.specs && src.specs[specID] && src.specs[specID].players);
    if (!anyPlayers && entry.players && entry.players.length) {
      spec.players = entry.players.slice(0, 10).map((pl) => ({
        rank: pl.rank, name: pl.name, realm: pl.realm, url: pl.url,
      }));
      players += 1;
    }
    // Verzierungen und Wertewahl - aber nur, wo keine Quelle dieses
    // Modus sie schon fuehrt.
    //
    // Bei M+ zaehlt raider.io zwoelfhundert Profile; die zwanzig hier
    // waeren die schlechtere Antwort auf dieselbe Frage. Bei Raid und
    // PvP gibt es sie sonst gar nicht: Warcraft Logs liefert keine
    // Bonus-IDs, und murlok fuehrt keine. Die Profile, die wir fuer die
    // Spieleransicht ohnehin holen, tragen sie mit.
    const anyCraft = Object.values(mode).some((src) => src.specs
      && src.specs[specID] && src.specs[specID].craftStats);
    if (!anyCraft) {
      const craft = {}, emb = {}, perItem = {};
      let counted = 0;
      for (const pl of entry.players || []) {
        const worn = new Set();
        let any = false;
        for (const item of Object.values(pl.gear || {})) {
          // Die ganze Liste je Stufe - dieselbe Frage wie bei M+: ohne
          // sie zeigt das Tooltip eines Handwerksstuecks "Zufallswert 1".
          if (item.ilvl > 0 && (item.bonuses || []).some((x) => bonusMap.stats[x])) {
            const have = craftLevels[item.id] || (craftLevels[item.id] = {});
            const old = have[item.ilvl];
            if (old) { old.n += 1; }
            else { have[item.ilvl] = { ilvl: item.ilvl, n: 1, ids: item.bonuses.slice() }; }
          }
          for (const b of item.bonuses || []) {
            if (bonusMap.stats[b]) {
              craft[b] = (craft[b] || 0) + 1;
              const per = perItem[item.id] || (perItem[item.id] = {});
              per[b] = (per[b] || 0) + 1;
              any = true;
            }
            if (bonusMap.embellish[b]) worn.add(bonusMap.embellish[b]);
          }
        }
        if (worn.size) {
          const key = [...worn].sort((a, b) => a - b).join(',');
          emb[key] = (emb[key] || 0) + 1;
        }
        if (any || worn.size) counted += 1;
      }
      const players = Math.max(1, (entry.players || []).length);
      const statTotal = Object.values(craft).reduce((a, b) => a + b, 0);
      if (statTotal > 0) {
        spec.craftStats = Object.entries(craft)
          .map(([bonus, n]) => ({ bonus: Number(bonus), pct: Math.round((n / statTotal) * 100) }))
          .filter((r) => r.pct > 0)
          .sort((a, b) => b.pct - a.pct);
      }
      const embRows = Object.entries(emb)
        .map(([key, n]) => ({ ids: key.split(',').map(Number), pct: Math.round((n / players) * 100) }))
        .filter((r) => r.pct > 0)
        .sort((a, b) => b.pct - a.pct)
        .slice(0, 8);
      if (embRows.length) spec.embellish = embRows;

      // Und die Wertewahl an die Zeilen des Gegenstands - egal, welche
      // Quelle dieses Modus die Ausruestung fuehrt. Ohne sie zeigt das
      // Tooltip "Zufallswert 1", und die Rangnummern fallen weg.
      for (const src of Object.values(mode)) {
        const other = src.specs && src.specs[specID];
        for (const list of Object.values((other && other.gear) || {})) {
          for (const row of list) {
            const per = perItem[row.id];
            if (!per || row.statBonus) continue;
            const best = Object.entries(per).sort((a, b) => b[1] - a[1])[0];
            const total = Object.values(per).reduce((a, b) => a + b, 0);
            row.statBonus = Number(best[0]);
            row.statPct = Math.round((best[1] / total) * 100);
          }
        }
      }
    }

    // Und die Details fuer die Spieleransicht - alle, verifiziert oder nicht.
    addProfiles(part.mode, specID, (entry.players || []).slice(0, 10));
  }
  console.log(`  + prof-${part.mode}.json: ${builds} Builds ergaenzt, ${players} Ranglisten, ${Object.keys(part.specs).length} Speccs Profile`);
}

// Knotenlisten einmal ablegen, dann nur noch darauf zeigen.
//
// Ein Build sind rund fuenfundsiebzig Knoten, und derselbe Build steht
// fuer jeden Boss, jeden Dungeon und jeden Held-Baum noch einmal
// vollstaendig da. Gemessen: in Dungeons.lua 2117 Builds, aber nur 319
// verschiedene - die Haelfte der Datei ist dieselbe Liste, wieder und
// wieder. Im Spiel wurde daraus ein Vielfaches an Speicher, weil Lua
// jede davon als eigene Tabelle anlegt.
//
// Also: jede Liste einmal, und der Build traegt nur noch ihre Nummer.
// Recommend.lua loest sie beim Einhaengen auf, und danach zeigen alle
// Builds mit derselben Wahl auf DIESELBE Tabelle. Fuer das Fenster
// aendert sich nichts, es sieht wie bisher eine Liste von Knoten.
const nodePools = new Map();
function nodeIndex(out, nodes) {
  let pool = nodePools.get(out);
  if (!pool) { pool = { list: [], index: new Map() }; nodePools.set(out, pool); }
  const sig = nodes.map((n) => n.spell + ':' + n.rank).join(',');
  let at = pool.index.get(sig);
  if (!at) {
    pool.list.push(nodes);
    at = pool.list.length;
    pool.index.set(sig, at);
  }
  return at;
}

function emitNodePool(out, target, indent) {
  const pool = nodePools.get(out);
  if (!pool || !pool.list.length) return;
  target.push(indent + 'nodeLists = {');
  for (const nodes of pool.list) {
    target.push(indent + '  { '
      + nodes.map((n) => `{ spell = ${n.spell}, rank = ${n.rank} }`).join(', ') + ' },');
  }
  target.push(indent + '},');
  console.log(`  Knotenlisten: ${pool.list.length} verschiedene statt ${pool.used || '?'} Wiederholungen`);
}

// Talente, Build und Alternativen eines Eintrags - einmal geschrieben,
// fuer die Spec und fuer jeden ihrer Held-Baeume benutzt.
function emitTalents(out, entry, indent) {
  if (entry.talents && entry.talents.length) {
    // Nur die UMSTRITTENEN Talente: was 98 % nehmen, steht im Build; was
    // 4 % nehmen, sagt nichts. PvP-Talente ausserhalb des Deckels, es
    // sind hoechstens elf.
    const contested = entry.talents.filter((t) => t.pct >= 15 && t.pct <= 85);
    const worth = contested.filter((t) => !t.pvp).slice(0, 24)
      .concat(contested.filter((t) => t.pvp));
    if (worth.length) {
      out.push(indent + 'talents = { ' + worth
        .map((t) => `{ spell = ${t.spell}, rank = ${t.rank}, pct = ${t.pct}${t.pvp ? ', pvp = true' : ''} }`)
        .join(', ') + ' },');
    }
  }
  if (entry.build && entry.build.nodes && entry.build.nodes.length) {
    const text = entry.build.text ? `text = ${luaString(entry.build.text)}, ` : '';
    const at = nodeIndex(out, entry.build.nodes);
    const pool = nodePools.get(out);
    pool.used = (pool.used || 0) + 1;
    out.push(indent + `build = { pct = ${entry.build.pct}, ${text}nodes = ${at} },`);
  }
  if (entry.builds && entry.builds.length) {
    out.push(indent + 'builds = { ' + entry.builds.map((v) => {
      const parts = ['pct = ' + v.pct];
      if (v.text) parts.push('text = ' + luaString(v.text));
      if (v.added && v.added.length) parts.push('added = { ' + v.added.join(', ') + ' }');
      if (v.removed && v.removed.length) parts.push('removed = { ' + v.removed.join(', ') + ' }');
      return '{ ' + parts.join(', ') + ' }';
    }).join(', ') + ' },');
  }
}

const baseOut = [];
const out = baseOut;
out.push('-- ERZEUGT von tools/build-recommendations.js. Nicht von Hand aendern.');
out.push('--');
out.push('-- Anteile in ganzen Prozent, je Platz ueber die beobachteten Spieler');
out.push('-- gerechnet. Die Item-IDs stammen NICHT von den Quellen, sondern aus');
out.push('-- Data/Catalog.lua - also aus den Spieldaten. Von den Quellen kommt');
out.push('-- nur, WAS benutzt wird.');
out.push('');
out.push('MetaCodex_Recommendations = {');

const SOURCE_ORDER = ['murlok.io', 'raider.io', 'warcraftlogs.com', 'Battle.net'];
const orderedSources = [...sources].sort((a, b) => {
  const ia = SOURCE_ORDER.indexOf(a), ib = SOURCE_ORDER.indexOf(b);
  return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib) || a.localeCompare(b);
});
out.push('  sources = { ' + orderedSources.map(luaString).join(', ') + ' },');
if (Object.keys(dungeons).length) {
  out.push('  -- Welche Dungeons zu einem Modus einzeln vorliegen.');
  // Boss und Instanz beim Journal nachschlagen.
  //
  // Warcraft Logs liefert englische Namen, und genau die standen im
  // deutschen Fenster. Mit der Journal-ID holt das Addon den Namen beim
  // Client. Nebenbei faellt dabei ab, zu welchem Raid ein Boss gehoert:
  // der Sammler haengt den Raidnamen nur an, wenn mehrere Zonen laufen,
  // und deshalb hatte von neun Bossen genau einer eine Gruppe. Das
  // Journal weiss es immer.
  let journalNames = { encounters: {}, instances: {} };
  try {
    journalNames = JSON.parse(fs.readFileSync(path.join(dir, 'journal-names.json'), 'utf8'));
  } catch (e) { console.log('  ? journal-names.json fehlt - Namen bleiben englisch'); }
  const instName = new Map();
  for (const [name, id] of Object.entries(journalNames.instances || {})) {
    if (!instName.has(id)) instName.set(id, name);
  }
  let named = 0, grouped = 0;
  for (const list of Object.values(dungeons)) {
    for (const d of list) {
      const enc = (journalNames.encounters || {})[d.name];
      if (enc) {
        d.enc = enc.enc;
        d.inst = enc.inst || undefined;
        d.order = enc.order || 0;
        named += 1;
        if (!d.group && enc.inst && instName.get(enc.inst)) {
          d.group = instName.get(enc.inst);
          grouped += 1;
        }
      } else {
        const inst = (journalNames.instances || {})[d.name];
        if (inst) { d.inst = inst; named += 1; }
      }
    }
  }
  console.log(`  Journal: ${named} Bosse/Instanzen erkannt, ${grouped} Bosse ihrem Raid zugeordnet`);

  // Die Handwerksstuecke mit ihren gemessenen Stufen.
  {
    const ids = Object.keys(craftLevels).sort((a, b) => a - b);
    let rows = 0;
    out.push('  craftLevels = {');
    for (const id of ids) {
      const levels = Object.values(craftLevels[id]).sort((a, b) => a.ilvl - b.ilvl);
      if (!levels.length) continue;
      rows += levels.length;
      out.push(`    [${id}] = { ` + levels
        .map((r) => `{ ilvl = ${r.ilvl}, n = ${r.n || 0}, ids = { ${r.ids.join(', ')} } }`)
        .join(', ') + ' },');
    }
    out.push('  },');
    console.log('Handwerksstuecke mit gemessenen Stufen:', ids.length, '(' + rows + ' Stufen)');
  }

  out.push('  dungeons = {');
  for (const [mode, list] of Object.entries(dungeons)) {
    // Bosse in der Reihenfolge, in der man sie trifft; Raids nach ihrer
    // Instanz-ID, also in der Reihenfolge, in der sie erschienen sind.
    // Alles Uebrige alphabetisch - bei Dungeons gibt es keine Ordnung,
    // die mehr Sinn ergaebe.
    list.sort((a, b) => {
      if ((a.inst || 0) !== (b.inst || 0)) return (a.inst || 0) - (b.inst || 0);
      if ((a.order || 0) !== (b.order || 0)) return (a.order || 0) - (b.order || 0);
      return a.name.localeCompare(b.name);
    });
    out.push(`    [${luaString(mode)}] = {`);
    for (const d of list) {
      const extra = (d.group ? `, group = ${luaString(d.group)}` : '')
        + (d.enc ? `, enc = ${d.enc}` : '')
        + (d.inst ? `, inst = ${d.inst}` : '');
      out.push(`      { key = ${luaString(d.key)}, name = ${luaString(d.name)}${extra} },`);
    }
    out.push('    },');
  }
  out.push('  },');
}
out.push('  modes = {');

// Die Wertewahl gilt fuer den GEGENSTAND, nicht fuer die Quelle.
//
// Nur raider.io und die Profile liefern Bonus-IDs; murlok und Warcraft
// Logs fuehren keine. Welche Quelle im Fenster die Ausruestung eines
// Modus stellt, entscheidet aber die Reihenfolge der Quellen - und wenn
// das die ohne Bonus-IDs ist, steht im Tooltip wieder "Zufallswert 1",
// obwohl wir es fuer dasselbe Stueck gemessen haben.
//
// Also: je Modus einmal einsammeln, wer es weiss, und den anderen
// Zeilen desselben Stuecks mitgeben. Der Anteil reist nicht mit - er
// gehoert zu der Stichprobe, die ihn gemessen hat.
let filled = 0;
for (const bySource of Object.values(byMode)) {
  const perSpec = {};
  for (const part of Object.values(bySource)) {
    for (const [specID, entry] of Object.entries(part.specs || {})) {
      for (const list of Object.values(entry.gear || {})) {
        for (const row of list) {
          if (!row.statBonus) continue;
          const mine = perSpec[specID] || (perSpec[specID] = {});
          if (!mine[row.id]) mine[row.id] = row.statBonus;
        }
      }
    }
  }
  for (const part of Object.values(bySource)) {
    for (const [specID, entry] of Object.entries(part.specs || {})) {
      const mine = perSpec[specID];
      if (!mine) continue;
      for (const list of Object.values(entry.gear || {})) {
        for (const row of list) {
          if (row.statBonus || !mine[row.id]) continue;
          row.statBonus = mine[row.id];
          filled += 1;
        }
      }
    }
  }
}
console.log('Wertewahl an weitere Zeilen gegeben:', filled);

// Zwei Puffer, zwei Addons.
//
// Die Dungeon-Auswertungen sind gemessen echt: bei 18 % der Plaetze
// steht ein anderes Item oben als in der Gesamtsicht. Sie wiegen aber
// auch mehr als alles uebrige zusammen. Wer nie einen Dungeon waehlt,
// soll dafuer nicht zahlen - also eigenes nachladbares Addon.
const dungeonOut = [];
for (const [mode, bySource] of Object.entries(byMode)) {
  const out = mode.includes('/') ? dungeonOut : baseOut;
  out.push(`    [${luaString(mode)}] = {`);
  for (const [source, part] of Object.entries(bySource)) {
    out.push(`      [${luaString(source)}] = {`);
    out.push(`        builtOn = ${part.builtOn || 0},`);
    // Aus welchen Schluesseln die Stichprobe stammt. "Hohe Keys" heisst
    // bei uns die Bestenliste (+20 bis +22), bei anderen Seiten etwas
    // Breiteres - wer die Zahlen vergleicht, soll sehen, worueber.
    if (Array.isArray(part.keyRange) && part.keyRange.length === 2) {
      out.push(`        keys = { ${part.keyRange[0]}, ${part.keyRange[1]} },`);
    }
    out.push('        specs = {');
    for (const [specID, entry] of Object.entries(part.specs)) {
      out.push(`          [${specID}] = {`);
      if (entry.sample) out.push(`            sample = ${entry.sample},`);

      // Zielwerte: Rangfolge und die beobachteten Werte. Der Name des
      // Gegenstands steht bei der Ausruestung mit dabei, weil sie - anders
      // als Steine und Verzauberungen - nicht im Katalog steht.
      // Der Anteil wird IMMER hier gerechnet, nie uebernommen.
      //
      // Jede Quelle meint mit "pct" etwas anderes: bei murlok stand dort
      // die Wertung selbst, und im Fenster wurde daraus "756 % des
      // Gesamtwerts". Der einzige Anteil, der ueber Quellen hinweg
      // dasselbe bedeutet, ist der an der Summe der vier Zweitwerte -
      // also wird er aus den Wertungen gerechnet.
      if (entry.stats && entry.stats.values) {
        const total = Object.values(entry.stats.values)
          .reduce((sum, v) => sum + (Number(v.rating) || 0), 0);
        for (const value of Object.values(entry.stats.values)) {
          value.pct = total > 0
            ? Math.round(((Number(value.rating) || 0) / total) * 100) : 0;
        }
      }

      if (entry.stats) {
        const priority = (entry.stats.priority || []).map(luaString).join(', ');
        // Der Stichprobenumfang entscheidet bei "alle Plattformen",
        // welche Quelle gewinnt: wer misst, schlaegt wer ordnet. Ohne
        // ihn gewann schlicht die erste, und das war murlok.
        const players = entry.stats.players
          ? `players = ${entry.stats.players}, ` : '';
        out.push(`            stats = { ${players}priority = { ${priority} }, values = {`);
        for (const [key, value] of Object.entries(entry.stats.values || {})) {
          out.push(`              ${key} = { pct = ${value.pct}, rating = ${value.rating} },`);
        }
        out.push('            } },');
      }
      // Gleiche Ware, verschiedene Handwerksstufen, ein Eintrag.
      //
      // "Thalassian Phoenix Oil" stand zweimal da, mit 74 % und 13 % - das
      // sind zwei Stufen desselben Oels mit verschiedenen IDs. Zweimal
      // derselbe Name in einer Liste ist keine Auskunft, sondern eine
      // Frage.
      //
      // Die Anteile werden addiert: wer die eine Stufe benutzt, benutzt
      // nicht zugleich die andere. Die ID der haeufigsten Stufe bleibt
      // stehen, denn die will man kaufen.
      if (entry.consumables && entry.consumables.length) {
        const byName = new Map();
        for (const c of entry.consumables) {
          // Zeilen ohne ID sind Reste aus der Zeit, in der ich glaubte,
          // die Speise sei nicht bestimmbar. Sie ist es - ueber die
          // Wirkung. Was keine ID hat, kann man nicht kaufen und gehoert
          // nicht in eine Einkaufsliste.
          if (!c.id) continue;
          const key = c.name || ('#' + c.id);
          const known = byName.get(key);
          if (!known) { byName.set(key, { ...c }); continue; }
          known.pct = Math.min(100, (known.pct || 0) + (c.pct || 0));
          known.maxKey = Math.max(known.maxKey || 0, c.maxKey || 0);
          // Die haeufigere Stufe gibt die ID vor.
          if ((c.pct || 0) > (known.__top || 0)) { known.id = c.id; known.__top = c.pct; }
        }
        // Unter einem Prozent ist Rauschen. Solche Zeilen standen mit
        // "0 %" in der Liste und sagten nichts.
        entry.consumables = [...byName.values()]
          // Ein Netz gegen Doppelzaehlung: ueber hundert Prozent gibt
          // es nicht, und eine solche Zahl im Fenster kostet mehr
          // Vertrauen, als die Zeile wert ist.
          .map((c) => ({ ...c, pct: Math.min(100, c.pct || 0) }))
          .filter((c) => (c.pct || 0) >= 1)
          .sort((a, b) => b.pct - a.pct);
      }

      if (entry.consumables && entry.consumables.length) {
        // Die Speisenzeile hat keine ID: alle Speisen melden denselben
        // Buff, aus dem kein Gegenstand faellt. Sie traegt nur die Art
        // und den Anteil - was kaufbar ist, steht im Katalog.
        out.push('            consumables = { ' + entry.consumables
          .map((c) => {
            const parts = [];
            if (c.id) parts.push(`id = ${c.id}`);
            parts.push(`pct = ${c.pct}`);
            parts.push(`kind = ${luaString(c.kind || 'other')}`);
            if (c.maxKey) parts.push(`maxKey = ${c.maxKey}`);
            return '{ ' + parts.join(', ') + ' }';
          })
          .join(', ') + ' },');
      }
      // Talente, Build, Alternativen - und dasselbe je Held-Baum.
      //
      // Ein Build ist nicht "Verstaerkung", er ist "Verstaerkung mit
      // Sturmbringer". Gemischt stand er als 22 % da, wo es zwei Builds
      // zu je 45 % waren.
      emitTalents(out, entry, "            ");
      if (entry.hero && Object.keys(entry.hero).length) {
        out.push("            hero = {");
        for (const [subTree, h] of Object.entries(entry.hero)) {
          // Ein Baum, den einer von siebenhundert traegt, rundet auf 0 % -
          // und "0 %" ist eine Aussage, die niemand gemessen hat. Er
          // bleibt draussen, statt als Wahl im Knopf zu stehen.
          if (!(h.pct > 0)) continue;
          out.push(`              [${subTree}] = { players = ${h.players || 0}, pct = ${h.pct || 0},`);
          emitTalents(out, h, "                ");
          out.push("              },");
        }
        out.push("            },");
      }
      // Die Spieler, die die Quelle oben fuehrt.
      //
      // Nur Name, Realm und Region - genug fuer die Adresse. Die Seite
      // selbst holt sich der Spieler im Browser; wir speichern keine
      // fremden Profile.
      if (entry.players && entry.players.length) {
        out.push('            players = { ' + entry.players.slice(0, 10)
          .map((p) => '{ rank = ' + p.rank
            + (p.rating ? ', rating = ' + p.rating : '')
            + ', name = ' + luaString(p.name)
            + ', realm = ' + luaString(p.realm)
            + ', url = ' + luaString(p.url || ('https://murlok.io/character/'
              + p.region + '/' + p.slug + '/' + p.character)) + ' }')
          .join(', ') + ' },');
      }
      if (entry.gear && Object.keys(entry.gear).length) {
        out.push('            gear = {');
        for (const [slot, list] of Object.entries(entry.gear)) {
          out.push(`              [${luaString(slot)}] = { ` + list
            .map((g) => {
            // Beide Quellen liefern Verschiedenes: murlok kennt Set und
            // Handwerk, Warcraft Logs die echte Stufe. Geschrieben wird,
            // was da ist - nicht was fehlt.
            // KEIN Name.
            //
            // Er stand einmal hier, weil diese Gegenstaende nicht im
            // Katalog stehen und die Zeile sonst leer blieb. Das kostete
            // 1124 von 1692 KB - zwei Drittel der Datei fuer etwas, das
            // der Client aus der ID selbst hat, und zwar in SEINER
            // Sprache statt in Englisch. Wer die Zeile sieht, bevor der
            // Client geantwortet hat, sieht sie eine halbe Sekunde ohne
            // Namen; GET_ITEM_INFO_RECEIVED traegt ihn nach.
            const parts = [`id = ${g.id}`, `pct = ${g.pct}`];
            if (g.maxKey) parts.push(`maxKey = ${g.maxKey}`);
            if (g.ilvl) parts.push(`ilvl = ${g.ilvl}`);
            if (g.kind) parts.push(`kind = ${luaString(g.kind)}`);
            // Die haeufigste Wertewahl dieses Handwerksstuecks: die
            // Bonus-ID fuer den Link, ihr Anteil fuer die Zeile. Welche
            // Werte das sind, steht im Katalog - hier steht nur, welche
            // gemessen wurde.
            if (g.statBonus) parts.push(`sb = ${g.statBonus}`);
            if (g.statPct) parts.push(`sbPct = ${g.statPct}`);
            return `{ ${parts.join(", ")} }`;
          })
            .join(', ') + ' },');
        }
        out.push('            },');
      }
      // Welche Werte auf Handwerksstuecken ueberhaupt gewaehlt werden,
      // und welche Verzierungen zusammen getragen werden. Beides zaehlt
      // der Sammler aus den Bonus-IDs der gemessenen Spieler.
      if (entry.craftStats && entry.craftStats.length) {
        out.push('            craftStats = { ' + entry.craftStats
          .map((r) => `{ bonus = ${r.bonus}, pct = ${r.pct} }`).join(', ') + ' },');
      }
      if (entry.embellish && entry.embellish.length) {
        out.push('            embellish = { ' + entry.embellish
          .map((r) => `{ ids = { ${r.ids.join(', ')} }, pct = ${r.pct} }`).join(', ') + ' },');
      }
      if (entry.gems && entry.gems.length) {
        out.push('            gems = { ' + entry.gems
          .map((g) => `{ id = ${g.id}, pct = ${g.pct}${g.maxKey ? `, maxKey = ${g.maxKey}` : ""} }`).join(', ') + ' },');
      }
      if (entry.enchants && Object.keys(entry.enchants).length) {
        out.push('            enchants = {');
        for (const [slot, rows] of Object.entries(entry.enchants)) {
          out.push(`              ${slot} = { ` + rows
            .map((r) => `{ id = ${r.id}, pct = ${r.pct}${r.maxKey ? `, maxKey = ${r.maxKey}` : ""} }`).join(', ') + ' },');
        }
        out.push('            },');
      }
      out.push('          },');
    }
    out.push('        },');
    out.push('      },');
  }
  out.push('    },');
}

out.push('  },');

// Fundorte, die der Katalog nicht hat: Beute alter Dungeons. Nur fuer
// Gegenstaende, die oben wirklich vorkommen - das ganze Journal waere
// zwanzigtausend Zeilen fuer drei alte Dungeons.
let journalAll = {};
try { journalAll = JSON.parse(fs.readFileSync(path.join(dir, 'journal-drops.json'), 'utf8')); } catch (e) { /* ohne Katalog-Lauf */ }
// Aus den DATEN, nicht aus dem Text: die Dungeon-Puffer gibt es hier
// noch nicht, und ein Textsuchlauf ueber Lua-Zeilen war ohnehin die
// falsche Idee.
const mentioned = new Set();
for (const bySource of Object.values(byMode)) {
  for (const part of Object.values(bySource)) {
    for (const entry of Object.values(part.specs || {})) {
      for (const list of Object.values(entry.gear || {})) {
        for (const row of list) if (row && row.id) mentioned.add(Number(row.id));
      }
    }
  }
}
const extraDrops = [...mentioned].filter((id) => journalAll[id]).sort((a, b) => a - b);
out.push('  -- Fundorte aus dem Journal fuer Beute, die der Katalog nicht fuehrt.');
out.push('  drops = {');
for (const id of extraDrops) out.push(`    [${id}] = { enc = ${journalAll[id].enc}, inst = ${journalAll[id].inst} },`);
out.push('  },');
console.log('Fundorte aus dem Journal ergaenzt:', extraDrops.length);
emitNodePool(baseOut, out, '  ');
out.push('}');
out.push('');

const file = path.join(BASE, 'MetaCodex_Data', 'Recommendations.lua');
fs.writeFileSync(file, baseOut.join('\n'), 'utf8');

// Das Dungeon-Addon: dieselbe Form, eigener Name, eigener Ordner.
const dungeonFile = path.join(BASE, 'MetaCodex_Dungeons', 'Dungeons.lua');
fs.mkdirSync(path.dirname(dungeonFile), { recursive: true });
const dOut = [];
dOut.push('-- ERZEUGT von tools/build-recommendations.js. Nicht von Hand aendern.');
dOut.push('--');
dOut.push('-- Dasselbe wie Recommendations.lua, nur je Dungeon. Getrennt, weil');
dOut.push('-- es mehr wiegt als alles uebrige zusammen und die meisten nie danach');
dOut.push('-- fragen. Recommend.lua haengt die Modi ein, sobald das Addon geladen');
dOut.push('-- ist - danach sind es ganz gewoehnliche Modi.');
dOut.push('');
dOut.push('MetaCodex_Dungeons = {');
dOut.push(`  builtOn = ${newest},`);
dOut.push('  modes = {');
for (const line of dungeonOut) dOut.push(line);
dOut.push('  },');
emitNodePool(dungeonOut, dOut, '  ');
dOut.push('}');
dOut.push('');
fs.writeFileSync(dungeonFile, dOut.join('\n'), 'utf8');

// Das Spieler-Addon: Profile mit Ausruestung und Kette, je Modus und Spec.
const playersFile = path.join(BASE, 'MetaCodex_Players', 'Players.lua');
const pOut = [];
pOut.push('-- ERZEUGT von tools/build-recommendations.js. Nicht von Hand aendern.');
pOut.push('-- Die Profile der Top-Spieler von raider.io: Ausruestung mit allen');
// Eine Verzauberung meldet sich als SpellItemEnchantment-ID. Der Client
// kennt unter dieser Nummer keinen Gegenstand - und ohne Gegenstand gibt
// es weder Namen noch Symbol noch Tooltip. Die Uebersetzung steht in der
// Karte, die der Katalog beim Bauen anlegt, und sie passiert HIER, einmal,
// statt im Addon bei jedem Blick auf ein Profil.
let enchantItem = {};
try {
  enchantItem = JSON.parse(fs.readFileSync(path.join(BASE, 'tools', 'data', 'enchant-map.json'), 'utf8'));
} catch (e) {
  console.log('  ! keine enchant-map.json - Profile ohne Verzauberungsnamen');
}

pOut.push('-- Bonus-IDs, damit das Tooltip das getragene Stueck zeigt, und die');
pOut.push('-- Talentkette. verified heisst: die Talente passen zu Kampf bzw. Heatmap.');
pOut.push('MetaCodex_Players = {');
pOut.push('  modes = {');
let profileCount = 0;
for (const [mode, bySpec] of Object.entries(profilesOut)) {
  pOut.push(`    [${luaString(mode)}] = {`);
  for (const [specID, players] of Object.entries(bySpec)) {
    pOut.push(`      [${specID}] = {`);
    for (const pl of players) {
      profileCount += 1;
      const gear = Object.entries(pl.gear || {}).map(([slot, it]) => {
        const parts = [`slot = ${luaString(slot)}`, `id = ${it.id}`, `ilvl = ${it.ilvl}`];
        if (it.bonuses && it.bonuses.length) parts.push(`b = { ${it.bonuses.join(', ')} }`);
        if (it.enchant) {
          parts.push(`enchant = ${it.enchant}`);
          // Die Nummer des Gegenstands, wenn die Karte ihn kennt.
          const asItem = enchantItem[String(it.enchant)];
          if (asItem) parts.push(`ench = ${asItem}`);
        }
        if (it.gems && it.gems.length) parts.push(`gems = { ${it.gems.join(', ')} }`);
        return `{ ${parts.join(', ')} }`;
      });
      const fields = [`name = ${luaString(pl.name)}`, `realm = ${luaString(pl.realm)}`, `url = ${luaString(pl.url)}`,
        `ilvl = ${pl.ilvl || 0}`, `verified = ${pl.verified ? 'true' : 'false'}`];
      if (pl.text) fields.push(`text = ${luaString(pl.text)}`);
      pOut.push(`        { ${fields.join(', ')},`);
      pOut.push(`          gear = { ${gear.join(', ')} } },`);
    }
    pOut.push('      },');
  }
  pOut.push('    },');
}
pOut.push('  },');
pOut.push('}');
pOut.push('');
fs.writeFileSync(playersFile, pOut.join(String.fromCharCode(10)), 'utf8');
console.log(`geschrieben: ${path.relative(BASE, playersFile)} (${Math.round(pOut.join(String.fromCharCode(10)).length / 1024)} KB, ${profileCount} Profile)`);

const kb = (f) => Math.round(fs.statSync(f).size / 1024);
const baseModes = Object.keys(byMode).filter((m) => !m.includes('/'));
const dungeonModes = Object.keys(byMode).filter((m) => m.includes('/'));
console.log(`\ngeschrieben: ${file} (${kb(file)} KB)`);
console.log(`  Modi: ${baseModes.join(', ') || 'keine'}`);
console.log(`geschrieben: ${dungeonFile} (${kb(dungeonFile)} KB)`);
console.log(`  Dungeons: ${dungeonModes.length}`);
console.log(`  Quellen: ${[...sources].join(', ') || 'keine'}`);