// Erzeugt Data/Recommendations.lua aus murlok.io.
//
//     node tools/collect-murlok.js <Pfad zum AddOn-Ordner> [Modi]
//
// Modi sind Pfadstuecke von murlok.io, mit Komma getrennt.
// Vorgabe: "m+,2v2,3v3,rbg".
//
// WARUM murlok.io und nicht Archon:
//
//   Archon liefert seine Seiten nur nach einer Cloudflare-Botpruefung aus -
//   geprueft, mit vollem Browser-Kopfsatz, Antwort bleibt "Human
//   Verification". Das ist keine Huerde, die man umgeht; es ist eine
//   Aussage. murlok.io dagegen erlaubt in robots.txt ausdruecklich alles
//   und liefert die Daten im HTML.
//
// WAS HIER NICHT DRIN IST: Raid. murlok.io fuehrt fuer eine Spec die Modi
// m+, 2v2, 3v3, blitz, rbg und solo - Raid ist nicht darunter (/raid gibt
// 404). Raiddaten muessen aus der Warcraft-Logs-API kommen; das ist
// dieselbe Quelle, auf die Archons eigene API-Seite verweist, und sie
// braucht eine Client-ID des Nutzers.
//
// Ausgewertet wird der Name, nicht das Bild: murlok verlinkt
// Verzauberungen mit item=0, aber ihr Klartextname ist derselbe, unter dem
// sie in Data/Catalog.lua steht. Die Item-ID kommt also aus dem Katalog -
// also aus den Spieldaten - und nicht von der Webseite.

const fs = require('fs');
const path = require('path');
const https = require('https');

const BASE = process.argv[2];
if (!BASE) {
  console.error('Aufruf: node tools/collect-murlok.js <Pfad zum AddOn-Ordner> [Modi]');
  process.exit(1);
}

// murlok fuehrt den Modus als Pfadstueck. Der Schluessel daneben ist der,
// unter dem das Addon ihn kennt - "m+" waere in Lua ein unhandlicher
// Tabellenschluessel, und "raid" gibt es hier gar nicht (siehe oben).
// solo = Solo Shuffle, blitz = Gewertetes Schlachtfeld Blitz.
// Nachgeprueft: beide Adressen antworten mit 200 und fuehren Daten;
// "shuffle" und "solo-shuffle" sind 404.
const MODES = (process.argv[3] || 'm+,2v2,3v3,rbg,solo,blitz').split(',').map((slug) => ({
  slug: slug.trim(),
  key: slug.trim() === 'm+' ? 'mplus' : slug.trim(),
}));

const UA = 'MetaCodex-collector (+https://github.com/Ego26/MetaCodex)';

function get(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': UA } }, (res) => {
      if (res.statusCode === 404) { res.resume(); return resolve(null); }
      if (res.statusCode !== 200) {
        res.resume();
        return reject(new Error(url + ' -> HTTP ' + res.statusCode));
      }
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (c) => (body += c));
      res.on('end', () => resolve(body));
    }).on('error', reject);
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ------------------------------------------------------------- Katalog

// Der Katalog ist die Autoritaet fuer Item-IDs. Steht ein Name dort nicht
// drin, wird er verworfen statt geraten - eine erfundene ID waere im Spiel
// ein leerer Eintrag, und niemand wuesste warum.
function readCatalog(file) {
  const lua = fs.readFileSync(file, 'utf8');
  const byName = new Map();
  const byId = new Map();

  for (const m of lua.matchAll(
    /\{ id = (\d+),(?: alt = (\d+),)? stat = "([^"]+)"(?:, power = [\d.]+)?, name = "([^"]+)" \}/g)) {
    const entry = { id: +m[1], alt: m[2] ? +m[2] : null, stat: m[3], name: m[4] };
    byName.set(entry.name.toLowerCase(), entry);
    byId.set(entry.id, entry);
    if (entry.alt) byId.set(entry.alt, entry);
  }
  for (const m of lua.matchAll(
    /\{ id = (\d+), major = "([^"]+)", minor = "([^"]+)", q = (\d+), ilvl = (\d+), name = "([^"]+)" \}/g)) {
    const entry = { id: +m[1], major: m[2], minor: m[3], q: +m[4], ilvl: +m[5], name: m[6] };
    byName.set(entry.name.toLowerCase(), entry);
    byId.set(entry.id, entry);
  }
  const expansion = Number((lua.match(/expansion = (\d+)/) || [])[1]) || 0;
  return { byName, byId, expansion };
}

// ------------------------------------------------- Gegenstandsstufen

// --------------------------------------------------------------- Speccs

const SLUG = (s) => s.toLowerCase()
  .replace(/['’`]/g, '')
  .replace(/[^a-z0-9]+/g, '-')
  .replace(/^-|-$/g, '');

function parseCSV(text) {
  const rows = [];
  let row = [], cur = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"') { if (text[i + 1] === '"') { cur += '"'; i++; } else quoted = false; }
      else cur += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(cur); cur = ''; }
    else if (c === '\n') { row.push(cur); cur = ''; rows.push(row); row = []; }
    else if (c !== '\r') cur += c;
  }
  if (cur || row.length) { row.push(cur); rows.push(row); }
  const head = rows.shift();
  return rows.filter((r) => r.length > 1)
    .map((r) => Object.fromEntries(head.map((h, i) => [h, r[i]])));
}

// Die Spezialisierungen kommen aus denselben DB2-Tabellen wie der Katalog.
// Eine von Hand gepflegte Liste der vierzig Speccs waere beim naechsten
// Addon falsch, und niemand wuerde es merken.
async function readSpecs(build) {
  const db2 = async (table) => parseCSV(await get(
    `https://wago.tools/db2/${table}/csv?build=${build}`));
  const [specs, classes] = await Promise.all([
    db2('ChrSpecialization'), db2('ChrClasses'),
  ]);
  const className = new Map(classes.map((c) => [c.ID, c.Name_lang]));

  const out = [];
  for (const spec of specs) {
    const cls = className.get(spec.ClassID);
    // OrderIndex jenseits von 3 ist die Anfaengerspec, die es auf murlok
    // nicht gibt.
    if (!cls || !spec.Name_lang || Number(spec.OrderIndex) > 3) continue;
    out.push({
      id: Number(spec.ID),
      name: spec.Name_lang,
      classID: Number(spec.ClassID),
      className: cls,
      slug: `${SLUG(cls)}/${SLUG(spec.Name_lang)}`,
    });
  }
  return out;
}

// ---------------------------------------------------------------- HTML

const decode = (s) => s
  .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(+n))
  .replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#x27;/g, "'");

/**
 * Liest einen Abschnitt der Seite: <h3> ist der Platz, <h4> der Eintrag,
 * die Zahl hinter dem Personensymbol die Anzahl der Spieler.
 */
function parseSection(html, heading) {
  // Die Ueberschrift kann ein Muster sein: "Best-in-Slot Gear for Mythic+"
  // heisst je Modus anders, "Enchantments" nicht.
  const headingPattern = heading instanceof RegExp
    ? heading : new RegExp(`>${heading}</h2>`, 'i');
  const start = html.search(headingPattern);
  if (start < 0) return null;
  const rest = html.slice(start + 1);
  const end = rest.search(/<h2[^>]*>/);
  const part = end > 0 ? rest.slice(0, end) : rest;

  const slots = {};
  let slot = null, entry = null;
  const pattern =
    // Hinter dem Symbol steht entweder die Spielerzahl ODER ein Merkmal
    // wie "Set" oder "Craft" - beides in derselben Form. Nur Ziffern
    // zuzulassen hiess, die Merkmale zu uebersehen; sie standen die
    // ganze Zeit da.
    /<h3[^>]*>([^<]{1,60})<\/h3>|<h4[^>]*>([^<]{1,120})<\/h4>|wowhead\.com\/item=(\d+)|<\/svg>\s*([^<]{1,24}?)\s*<\/li>/g;

  for (const m of part.matchAll(pattern)) {
    if (m[1]) {
      slot = decode(m[1]).trim();
      slots[slot] = slots[slot] || [];
      entry = null;
    } else if (m[3] !== undefined) {
      // Der Link steht VOR dem Namen, also erst merken.
      entry = { itemID: Number(m[3]) || null };
    } else if (m[2]) {
      if (!slot) continue;
      entry = entry || { itemID: null };
      entry.name = decode(m[2]).trim();
      slots[slot].push(entry);
    } else if (m[4] && entry) {
      const text = m[4].trim();
      if (/^[\d,]+$/.test(text)) {
        // Die Zahl steht immer zuletzt und schliesst den Eintrag ab.
        entry.count = Number(text.replace(/,/g, ''));
        entry = null;
      } else {
        entry.kind = text.toLowerCase();
      }
    }
  }
  return slots;
}

// murlok benennt die Plaetze wie das Spiel, der Katalog benutzt eigene
// Schluessel. Ein Platz, der hier fehlt, wird uebergangen - stillschweigend
// etwas zuzuordnen waere schlimmer.
const SLOT_KEY = {
  Head: 'helm', Shoulders: 'shoulders', Chest: 'chest', Legs: 'legs',
  Feet: 'boots', Rings: 'ring', Ring: 'ring',
  'Main Hand': 'weapon', Weapon: 'weapon', 'Off Hand': 'weapon',
};

/** "Enchant Helm - Rune of Avoidance" -> "Rune of Avoidance" */
const stripSlot = (name) => name.replace(/^Enchant\s+[^-]+-\s*/i, '').trim();

// Die Kennwerte heissen auf der Seite aus, im Katalog kurz.
const STAT_KEY = {
  'critical strike': 'crit', 'haste': 'haste',
  'mastery': 'mastery', 'versatility': 'vers',
};

/**
 * Wertepriorität und Zielwerte.
 *
 * Die Seite fuehrt beides getrennt: ein Balkendiagramm mit Prozent und
 * Ratingwert je Kennwert, darunter eine nummerierte Rangfolge. Beides ist
 * brauchbar und beides wird uebernommen - die Rangfolge sagt, was wichtiger
 * ist, die Zahlen sagen, wo man steht.
 */
/**
 * Die Spieler, die murlok oben in dieser Klammer fuehrt.
 *
 * Sie stehen auf derselben Seite, die wir ohnehin holen - kostet also
 * keine einzige Anfrage mehr. Und sie beantworten eine Frage, die keine
 * Prozentzahl beantwortet: WER spielt das eigentlich so, und wie sieht
 * sein ganzer Charakter aus.
 *
 * Gespeichert wird nur, was zur Adresse gehoert - Name, Realm, Region.
 * Die Seite selbst holt sich der Spieler im Browser.
 */
function parsePlayers(html) {
  const out = [];
  const seen = new Set();
  // Die Eintraege stehen als Links auf /character/<region>/<realm>/<name>,
  // gefolgt vom Rang und dem angezeigten Namen.
  // Als Zeichenkette gebaut, nicht als Literal: dieser Ausdruck ist
  // voller Schraegstriche und Backslashes, und in einem Literal
  // ueberlebt er kein Werkzeug, das ihn unterwegs anfasst.
  const re = new RegExp(
    'href="\\/character\\/([a-z]{2})\\/([^/"]+)\\/([^/"]+)\\/[a-z+]+"'
    + '[\\s\\S]{0,400}?class="h3">(\\d+)<\\/div>'
    + '[\\s\\S]{0,240}?class="h3">([^<]{1,32})<\\/div>'
    + '\\s*<div>([^<]{1,60})<\\/div>', 'g');
  let m;
  while ((m = re.exec(html)) !== null) {
    const key = m[1] + '/' + m[2] + '/' + m[3];
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({
      rank: Number(m[4]),
      name: m[5].trim(),
      realm: m[6].trim(),
      region: m[1],
      slug: m[2],
      character: m[3],
    });
    if (out.length >= 20) break;
  }
  return out.length ? out : null;
}

/**
 * Die Namenskarte der Talente und die Zauber, die jede Spec wirklich
 * spielt.
 *
 * murlok nennt Talente beim englischen Namen; das Addon braucht die
 * Zauber-ID, weil der Client daraus Name und Symbol in SEINER Sprache
 * holt. Die Karte kommt aus dem Katalog (talent-map.json). Gleiche Namen
 * ueber Klassen hinweg - "Improved X" gibt es oft - loest die zweite
 * Haelfte auf: die Zauber, die raider.io und die Logs fuer diese Spec
 * schon gesehen haben, plus ihre PvP-Talente.
 */
function loadTalentMap(base) {
  const dir = path.join(base, 'tools', 'data');
  let map;
  try {
    map = JSON.parse(fs.readFileSync(path.join(dir, 'talent-map.json'), 'utf8'));
  } catch (err) {
    console.log('  ! keine talent-map.json - Talente werden nicht aufgeloest');
    return null;
  }
  const lower = new Map();
  for (const [id, name] of Object.entries(map.names)) {
    const key = name.toLowerCase();
    if (!lower.has(key)) lower.set(key, []);
    lower.get(key).push(Number(id));
  }
  // Was jede Spec spielt: aus allen Dateien, die Talente fuehren.
  const seen = {};
  for (const file of fs.readdirSync(dir)) {
    if (!/^(rio|wcl)-.*.json$/.test(file)) continue;
    let data;
    try { data = JSON.parse(fs.readFileSync(path.join(dir, file), 'utf8')); } catch (e) { continue; }
    for (const [specID, entry] of Object.entries(data.specs || {})) {
      const set = seen[specID] || (seen[specID] = new Set());
      for (const t of entry.talents || []) set.add(t.spell);
      for (const n of (entry.build && entry.build.nodes) || []) set.add(n.spell);
    }
  }
  return { lower, seen, pvp: map.pvp || {} };
}

/**
 * Die Talente einer Seite, als Anteil je Talent.
 *
 * Vier Gruppen: Klasse, Spec, Helden, PvP. Der Nenner ist die hoechste
 * Zahl in Klasse und Spec - dort gibt es immer ein Talent, das alle
 * nehmen, und seine Zahl ist die Stichprobe. Die Zahl selbst schreibt
 * murlok nirgends hin.
 */
function parseTalents(html, specID, tmap) {
  if (!tmap) return null;
  const groups = ['talents-class', 'talents-specialization', 'talents-hero', 'talents-pvp'];
  // Ohne einen einzigen Backslash: [^] ist in JavaScript 'irgendein
  // Zeichen, auch Zeilenumbruch', und [0-9] braucht kein d. Warum das
  // wichtig ist: Backslashes ueberleben den Weg in diese Datei nicht
  // zuverlaessig, und ein Ausdruck, der still nichts findet, sieht von
  // aussen aus wie eine Seite ohne Talente.
  const cellRe = new RegExp(
    'alt="([^"]+)"[^]{0,300}?guide-talent-count">([0-9]+)<', 'g');
  const found = [];
  let sample = 0;
  for (const id of groups) {
    const i = html.indexOf('id="' + id + '"');
    if (i < 0) continue;
    let j = html.indexOf('id="talents-', i + 10);
    if (j < 0) j = i + 120000;
    const part = html.slice(i, j);
    for (const m of part.matchAll(cellRe)) {
      const count = Number(m[2]);
      found.push({ name: m[1].trim(), count, group: id.slice(8) });
      if (id !== 'talents-hero' && id !== 'talents-pvp') sample = Math.max(sample, count);
    }
  }
  if (!found.length || !sample) return null;

  const own = tmap.seen[specID] || new Set();
  const pvp = new Set(tmap.pvp[specID] || []);
  const out = [];
  let unresolved = 0;
  for (const t of found) {
    const ids = tmap.lower.get(t.name.toLowerCase()) || [];
    // Erst, was die Spec nachweislich spielt; dann die PvP-Talente der
    // Spec; dann ein Name, der ueberhaupt nur einmal vorkommt.
    let hit = ids.filter((id) => own.has(id));
    if (hit.length !== 1) hit = ids.filter((id) => pvp.has(id));
    if (hit.length !== 1 && ids.length === 1) hit = ids;
    if (hit.length !== 1) { unresolved += 1; continue; }
    out.push({
      spell: hit[0], rank: 1,
      pct: Math.round((t.count / sample) * 100),
      pvp: t.group === 'pvp' || undefined,
    });
  }
  out.sort((a, b) => b.pct - a.pct);
  return out.length ? { talents: out, sample, unresolved } : null;
}

function parseStats(html) {
  const start = html.search(/>Stat Priority</i);
  if (start < 0) return null;
  const part = html.slice(start, start + 6000);

  const values = {};
  for (const m of part.matchAll(
    /guide-stats-chart-item[^>]*>\s*<span>([\d.]+)%\s+([^<]+)<\/span>\s*<span[^>]*>\+?([\d,]+)</g)) {
    const key = STAT_KEY[m[2].trim().toLowerCase()];
    if (key) values[key] = { pct: Number(m[1]), rating: Number(m[3].replace(/,/g, '')) };
  }

  const priority = [];
  const listStart = part.search(/<h4[^>]*>\s*Stat priority\s*<\/h4>/i);
  if (listStart >= 0) {
    for (const m of part.slice(listStart, listStart + 1200).matchAll(/<li[^>]*>([^<]{3,30})<\/li>/g)) {
      const key = STAT_KEY[m[1].trim().toLowerCase()];
      if (key && !priority.includes(key)) priority.push(key);
    }
  }

  if (!priority.length && !Object.keys(values).length) return null;
  return { priority, values };
}

function shares(list) {
  const total = list.reduce((sum, e) => sum + (e.count || 0), 0);
  if (!total) return list.map(() => 0);
  return list.map((e) => Math.round(((e.count || 0) / total) * 100));
}

function luaString(s) {
  return '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
}

// ------------------------------------------------------------------ Lauf

(async () => {
  const builds = JSON.parse(await get('https://wago.tools/api/builds'));
  const build = builds.wow[0].version;

  const catalog = readCatalog(path.join(BASE, 'MetaCodex_Data', 'Catalog.lua'));
  console.log(`Katalog: ${catalog.byId.size} IDs`);
  const tmap = loadTalentMap(BASE);
  let unresolvedTotal = 0;


  let specs = await readSpecs(build);
  // Zum Ausprobieren: MC_LIMIT=3 holt nur die ersten drei Speccs.
  if (process.env.MC_LIMIT) specs = specs.slice(0, Number(process.env.MC_LIMIT));
  console.log(`Speccs: ${specs.length}, Modi: ${MODES.map((m) => m.slug).join(', ')}`);

  /** Wertet eine Seite aus. null, wenn nichts Brauchbares drinsteht. */
  function harvest(html, spec) {
    const enchants = parseSection(html, 'Enchantments') || {};
    const gems = parseSection(html, 'Gems') || {};
    const entry = { enchants: {}, gems: [] };

    for (const [slotName, list] of Object.entries(enchants)) {
      const key = SLOT_KEY[slotName];
      if (!key || !list.length) continue;
      const pct = shares(list);
      const rows = [];
      list.forEach((item, i) => {
        // Zuerst ueber die ID, sonst ueber den Namen. Beides scheitert
        // lieber, als etwas Falsches einzutragen.
        const found = (item.itemID && catalog.byId.get(item.itemID))
          || catalog.byName.get(stripSlot(item.name || '').toLowerCase());
        if (found) rows.push({ id: found.id, pct: pct[i] });
      });
      if (rows.length) entry.enchants[key] = rows;
    }

    const gemList = Object.values(gems).flat();
    const gemPct = shares(gemList);
    gemList.forEach((item, i) => {
      const found = (item.itemID && catalog.byId.get(item.itemID))
        || catalog.byName.get((item.name || '').toLowerCase());
      if (found && found.major) entry.gems.push({ id: found.id, pct: gemPct[i] });
    });

    // --- BiS-Ausruestung ---------------------------------------------
    //
    // Hier kommt die Item-ID ausnahmsweise von der Seite: Ausruestung
    // steht nicht im Katalog, weil man sie nicht kauft. Geprueft wird
    // trotzdem - ohne ID und ohne Namen wird nichts uebernommen.
    const gearSection = parseSection(html, />Best-in-Slot Gear[^<]*<\/h2>/i) || {};
    entry.gear = {};
    for (const [slotName, list] of Object.entries(gearSection)) {
      const rows = [];
      const pct = shares(list);
      list.forEach((item, i) => {
        if (item.itemID && item.name) {
          rows.push({
            id: item.itemID, pct: pct[i], name: item.name,
            kind: item.kind || null,
          });
        }
      });
      if (rows.length) entry.gear[slotName] = rows;
    }

    entry.stats = parseStats(html);
    entry.players = parsePlayers(html);
    // Talente mit Anteil je Talent - auch fuer PvP, wo sonst niemand
    // sie fuehrt. Eine fertige Importkette gibt es hier nicht.
    const talents = spec && parseTalents(html, spec.id, tmap);
    if (talents) {
      entry.talents = talents.talents;
      entry.talentSample = talents.sample;
      unresolvedTotal += talents.unresolved;
    }

    if (!Object.keys(entry.enchants).length && !entry.gems.length
      && !Object.keys(entry.gear).length && !entry.stats && !entry.talents) return null;
    return entry;
  }

  const byMode = {};
  for (const mode of MODES) {
    const result = {};
    let missed = 0;
    process.stdout.write(`\n--- ${mode.slug} `);
    for (const spec of specs) {
      const url = `https://murlok.io/${spec.slug}/${encodeURIComponent(mode.slug)}`;
      let html;
      try {
        html = await get(url);
      } catch (err) {
        console.log(`\n  ! ${spec.slug}: ${err.message}`);
        continue;
      }
      const entry = html && harvest(html, spec);
      if (entry) {
        result[spec.id] = entry;
        process.stdout.write('.');
      } else {
        missed++;
        process.stdout.write('-');
      }

      // Ein Aufruf alle 600 ms. Die Daten aendern sich woechentlich; es
      // gibt keinen Grund, jemandes Server zu treten.
      await sleep(600);
    }
    byMode[mode.key] = result;
    console.log(`\n  ${Object.keys(result).length} Speccs, ${missed} ohne Daten`);
  }

  const now = new Date();
  const stamp = now.getFullYear() * 10000 + (now.getMonth() + 1) * 100 + now.getDate();

  // Jeder Sammler schreibt nur seinen eigenen Zwischenstand; zusammengebaut
  // wird in tools/build-recommendations.js. Schriebe jeder direkt die
  // Lua-Datei, loeschte der zweite Lauf die Arbeit des ersten - und Raid
  // kommt aus einer anderen Quelle als M+.
  const dir = path.join(BASE, 'tools', 'data');
  fs.mkdirSync(dir, { recursive: true });
  for (const [key, specsFound] of Object.entries(byMode)) {
    const file = path.join(dir, `murlok-${key.replace(/[^\w-]/g, '_')}.json`);
    fs.writeFileSync(file, JSON.stringify({
      source: 'murlok.io', mode: key, builtOn: stamp, specs: specsFound,
    }, null, 1), 'utf8');
    console.log(`geschrieben: ${file}`);
  }
  console.log('\nJetzt zusammenbauen: node tools/build-recommendations.js .');
  if (unresolvedTotal) console.log(`Talente ohne Zauber-ID: ${unresolvedTotal} (Namen, die keinem bekannten Zauber der Spec entsprechen)`);
})().catch((err) => {
  console.error('Fehlgeschlagen:', err.message);
  process.exit(1);
});
