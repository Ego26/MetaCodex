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
let newest = 0;
const profileParts = [];
// Fuer das Spieler-Addon: Modus -> Spec -> Spieler mit Ausruestung.
const profilesOut = {};

for (const name of fs.readdirSync(dir).sort()) {
  if (!name.endsWith('.json')) continue;
  const part = JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8'));
  // Profile kommen NACH allen anderen dran: sie ergaenzen, was eine
  // Quelle nicht hat, und dafuer muss die Quelle schon da sein.
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
    // Und die Details fuer die Spieleransicht - alle, verifiziert oder nicht.
    const list = (profilesOut[part.mode] = profilesOut[part.mode] || {});
    list[specID] = (entry.players || []).filter((pl) => pl.found).slice(0, 10);
  }
  console.log(`  + prof-${part.mode}.json: ${builds} Builds ergaenzt, ${players} Ranglisten, ${Object.keys(part.specs).length} Speccs Profile`);
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
out.push(`  builtOn = ${newest},`);
out.push('  sources = { ' + [...sources].map(luaString).join(', ') + ' },');
if (Object.keys(dungeons).length) {
  out.push('  -- Welche Dungeons zu einem Modus einzeln vorliegen.');
  out.push('  dungeons = {');
  for (const [mode, list] of Object.entries(dungeons)) {
    list.sort((a, b) => a.name.localeCompare(b.name));
    out.push(`    [${luaString(mode)}] = {`);
    for (const d of list) {
      out.push(`      { key = ${luaString(d.key)}, name = ${luaString(d.name)}${d.group ? `, group = ${luaString(d.group)}` : ''} },`);
    }
    out.push('    },');
  }
  out.push('  },');
}
out.push('  modes = {');

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
    out.push('        specs = {');
    for (const [specID, entry] of Object.entries(part.specs)) {
      out.push(`          [${specID}] = {`);

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
      // Talente. Der Zauber steht als ID da, nicht als Name - der
      // Client setzt ihn ein und trifft damit jede Clientsprache.
      //
      // Nur die UMSTRITTENEN Talente.
      //
      // Ein Talent, das 98 % nehmen, sagt nichts - es steht im Build und
      // damit ist die Sache erledigt. Eines, das 4 % nehmen, sagt auch
      // nichts. Interessant ist der Bereich dazwischen: dort gibt es
      // wirklich etwas zu entscheiden, und genau dort hilft zu wissen,
      // wie die Besten sich entscheiden.
      //
      // Das halbiert nebenbei die Datenmenge: von neunzig Zeilen je Spec
      // bleiben ein bis zwei Dutzend, und die sind die, die zaehlen.
      if (entry.talents && entry.talents.length) {
        // PvP-Talente ausserhalb des Deckels: es sind hoechstens elf,
        // sie sitzen in einem anderen Fenster, und hinter vierundzwanzig
        // Klassentalenten fielen sie sonst komplett heraus - bei Resto
        // Schamane 2v2 standen null in der Tabelle.
        const contested = entry.talents.filter((t) => t.pct >= 15 && t.pct <= 85);
        const worth = contested.filter((t) => !t.pvp).slice(0, 24)
          .concat(contested.filter((t) => t.pvp));
        if (worth.length) {
          out.push('            talents = { ' + worth
            .map((t) => `{ spell = ${t.spell}, rank = ${t.rank}, pct = ${t.pct}${t.pvp ? ', pvp = true' : ''} }`)
            .join(', ') + ' },');
        }
      }
      // Der haeufigste vollstaendige Build - die Antwort auf "was stelle
      // ich ein", die aus den Einzelanteilen NICHT hervorgeht.
      if (entry.build && entry.build.nodes && entry.build.nodes.length) {
        // Die fertige Importkette, wenn die Quelle eine liefert.
        //
        // raider.io tut es: vom Spiel erzeugt, nicht nachgebaut. Der
        // eigene Kodierer bleibt als Rueckfall fuer Quellen ohne sie.
        const text = entry.build.text
          ? `text = ${luaString(entry.build.text)}, ` : '';
        out.push(`            build = { pct = ${entry.build.pct}, ${text}nodes = { `
          + entry.build.nodes
            .map((n) => `{ spell = ${n.spell}, rank = ${n.rank} }`)
            .join(', ') + ' } },');
      }
      // Die Spieler, die die Quelle oben fuehrt.
      //
      // Nur Name, Realm und Region - genug fuer die Adresse. Die Seite
      // selbst holt sich der Spieler im Browser; wir speichern keine
      // fremden Profile.
      if (entry.players && entry.players.length) {
        out.push('            players = { ' + entry.players.slice(0, 10)
          .map((p) => '{ rank = ' + p.rank
            + ', name = ' + luaString(p.name)
            + ', realm = ' + luaString(p.realm)
            + ', url = ' + luaString('https://murlok.io/character/'
              + p.region + '/' + p.slug + '/' + p.character) + ' }')
          .join(', ') + ' },');
      }
      // Die naechsthaeufigsten Builds, je als Unterschied zum ersten.
      if (entry.builds && entry.builds.length) {
        out.push('            builds = { ' + entry.builds.map((v) => {
          const parts = ['pct = ' + v.pct];
          if (v.text) parts.push('text = ' + luaString(v.text));
          if (v.added && v.added.length) parts.push('added = { ' + v.added.join(', ') + ' }');
          if (v.removed && v.removed.length) parts.push('removed = { ' + v.removed.join(', ') + ' }');
          return '{ ' + parts.join(', ') + ' }';
        }).join(', ') + ' },');
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
            return `{ ${parts.join(", ")} }`;
          })
            .join(', ') + ' },');
        }
        out.push('            },');
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
dOut.push('}');
dOut.push('');
fs.writeFileSync(dungeonFile, dOut.join('\n'), 'utf8');

// Das Spieler-Addon: Profile mit Ausruestung und Kette, je Modus und Spec.
const playersFile = path.join(BASE, 'MetaCodex_Players', 'Players.lua');
const pOut = [];
pOut.push('-- ERZEUGT von tools/build-recommendations.js. Nicht von Hand aendern.');
pOut.push('-- Die Profile der Top-Spieler von raider.io: Ausruestung mit allen');
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
        if (it.enchant) parts.push(`enchant = ${it.enchant}`);
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