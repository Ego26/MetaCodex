// Sammelt Raiddaten aus der Warcraft-Logs-API (API v2, GraphQL).
//
//     node tools/collect-wcl.js <Pfad zum AddOn-Ordner> probe
//     node tools/collect-wcl.js <Pfad zum AddOn-Ordner> [Schwierigkeit]
//
// Schwierigkeit: 3 = normal, 4 = heroisch (Vorgabe), 5 = mythisch.
// Umfang ueber MC_ENCOUNTERS (Vorgabe 3) und MC_REPORTS (Vorgabe 120).
//
// ZUGANGSDATEN: tools/wcl-credentials.json ({ clientId, clientSecret }) oder
// die Umgebungsvariablen WCL_CLIENT_ID und WCL_CLIENT_SECRET. Die Datei ist
// per .gitignore ausgeschlossen und darf nie in ein Addon-Release geraten.
//
// WARUM DIESE QUELLE: Archon selbst ist hinter einer Cloudflare-Botpruefung
// nicht erreichbar - aber Archons eigene Hilfeseite "API Documentation"
// beschreibt gar keine Archon-API, sondern diese hier. Archon gehoert zu
// RPGLogs. Wir rechnen also dieselben Zahlen nach, statt sie abzugreifen.
//
// WARUM UEBER DIE BERICHTE: Die Sonde hat gezeigt, dass die Ranglisten kein
// Gear mitliefern - ihre Felder sind name, class, spec, amount, report und
// ein paar Zeiten, mehr nicht. Die Ausruestung steht im Bericht. Das klingt
// teurer und ist billiger: ein Bericht enthaelt ALLE Spieler des Kampfes,
// also rund zwanzig Datensaetze je Abruf statt einem.

const fs = require('fs');
const path = require('path');
const https = require('https');

const BASE = process.argv[2];
if (!BASE) {
  console.error('Aufruf: node tools/collect-wcl.js <Pfad zum AddOn-Ordner> [probe|Schwierigkeit]');
  process.exit(1);
}
// Erster Parameter: was gesammelt wird. 'raid' oder 'mplus'.
// Zweiter: bei Raid die Schwierigkeit (3 normal, 4 heroisch, 5 mythisch).
// 'mplus' liest die Rangliste, 'mplus-keys' die Schluesselstufen.
const WANT = process.argv[3];
const KIND = (WANT === 'mplus' || WANT === 'mplus-keys') ? 'mplus' : 'raid';
const KEY_RANGE = WANT === 'mplus-keys';
const PROBE = process.argv[3] === 'probe' || process.argv[4] === 'probe';
// M+ hat genau eine Schwierigkeit, und sie heisst 10.
const DIFFICULTY = KIND === 'mplus' ? 10 : Number(process.argv[4] || 4);

// Die Schluesselstufen, ueber die 'mplus-keys' laeuft.
//
// characterRankings kennt ein bracket-Argument, und die Zone sagt
// selbst, was es bedeutet: { min: 2, max: 30, type: "Keystone Level" }.
// Nachgemessen: bracket N liefert genau Schluesselstufe N+1.
//
// OHNE bracket ist die Rangliste nach Wertung sortiert und enthaelt
// ueber acht Seiten ausschliesslich +20 und +21 - also genau das, was
// Archon "High Keys" nennt (deren Seite sagt: die besten 5 % der
// letzten 14 Tage). Beides ist richtig, nur eben nicht dasselbe.
const KEY_FROM = Number(process.env.MC_KEY_FROM || 7);
const KEY_TO = Number(process.env.MC_KEY_TO || 21);

// Die Schwierigkeit gehoert in den Modusnamen, sonst ueberschreibt der
// mythische Lauf den heroischen, und niemand sieht es.
const RAID_NAME = { 3: 'raid-normal', 4: 'raid', 5: 'raid-mythic' };
// Je Dungeon eine eigene Auswertung - so wie Archon es anbietet.
// Kostet keine einzige zusaetzliche Abfrage: welcher Kampf zu welchem
// Dungeon gehoert, steht schon fest, wenn die Berichte eingesammelt
// werden. Es kostet Dateigroesse, und die wird gemessen, bevor sie
// ausgeliefert wird.
const PER_DUNGEON = !!process.env.MC_DUNGEONS;
const slug = (name) => String(name).toLowerCase()
  .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

const BASE_MODE = KIND === 'mplus'
  ? (KEY_RANGE ? 'mplus-keys' : 'mplus')
  : (RAID_NAME[DIFFICULTY] || `raid-${DIFFICULTY}`);

// ---------------------------------------------------------- Zugangsdaten

function credentials() {
  if (process.env.WCL_CLIENT_ID && process.env.WCL_CLIENT_SECRET) {
    return { id: process.env.WCL_CLIENT_ID, secret: process.env.WCL_CLIENT_SECRET };
  }
  const file = path.join(BASE, 'tools', 'wcl-credentials.json');
  if (!fs.existsSync(file)) {
    console.error('Keine Zugangsdaten gefunden. Entweder:');
    console.error(`  ${file} anlegen (Vorlage: wcl-credentials.example.json)`);
    console.error('  oder WCL_CLIENT_ID und WCL_CLIENT_SECRET setzen.');
    process.exit(1);
  }
  const json = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!json.clientId || !json.clientSecret) {
    console.error(`${file}: clientId oder clientSecret ist leer.`);
    process.exit(1);
  }
  return { id: json.clientId, secret: json.clientSecret };
}

// ------------------------------------------------------------- Transport

function request(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let text = '';
      res.setEncoding('utf8');
      res.on('data', (c) => (text += c));
      res.on('end', () => {
        if (res.statusCode !== 200) {
          const err = new Error(`HTTP ${res.statusCode}: ${text.slice(0, 300)}`);
          err.status = res.statusCode;
          return reject(err);
        }
        try { resolve(JSON.parse(text)); } catch (err) { reject(err); }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

// Diagnose: mit MC_AURAS=1 meldet der Lauf, welche Auren er nicht
// zuordnen konnte. So wurde sichtbar, unter welchem Zauber Speisen
// tatsaechlich auftauchen.
const SHOW_AURAS = !!process.env.MC_AURAS;
// Mit MC_DRYRUN=1 wird nichts geschrieben. Ein kurzer Diagnoselauf soll
// einen vollstaendigen Datensatz nicht durch dreissig Spieler ersetzen -
// genau das ist einmal passiert.
const DRY = !!process.env.MC_DRYRUN;
const missedAuras = new Map();

let token = null;

async function getToken() {
  const { id, secret } = credentials();
  const body = 'grant_type=client_credentials';
  const json = await request({
    method: 'POST',
    hostname: 'www.warcraftlogs.com',
    path: '/oauth/token',
    headers: {
      'Authorization': 'Basic ' + Buffer.from(`${id}:${secret}`).toString('base64'),
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(body),
    },
  }, body);
  if (!json.access_token) throw new Error('Kein access_token in der Antwort.');
  return json.access_token;
}

// Wie viele Punkte noch uebrig sind.
//
// Warcraft Logs rechnet in Punkten je Stunde, nicht in Anfragen. Ein
// Lauf mit zwei Abfragen je Bericht kostet doppelt - und genau daran
// ist ein Durchgang gestorben: der erste Lauf verbrauchte das
// Kontingent, die drei folgenden brachen mit 429 ab und schrieben
// nichts. Deshalb wird jetzt gefragt statt gehofft.
async function quota() {
  try {
    const d = await gqlRaw('{ rateLimitData { limitPerHour pointsSpentThisHour pointsResetIn } }');
    return d.rateLimitData;
  } catch (err) {
    return null;
  }
}

async function gqlRaw(query, variables) {
  const body = JSON.stringify({ query, variables: variables || {} });
  const json = await request({
    method: 'POST',
    hostname: 'www.warcraftlogs.com',
    path: '/api/v2/client',
    headers: {
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
    },
  }, body);
  if (json.errors) throw new Error(json.errors.map((e) => e.message).join('; '));
  return json.data;
}

// Dieselbe Abfrage, aber sie gibt bei 429 nicht auf.
//
// Ein erschoepftes Kontingent ist kein Fehler, sondern eine Pause. Wer
// daran abbricht, wirft eine halbe Stunde Arbeit weg - und genau das
// ist passiert.
async function gql(query, variables) {
  for (let tries = 0; ; tries++) {
    try {
      return await gqlRaw(query, variables);
    } catch (err) {
      // Sechs Versuche, nicht drei.
      //
      // Ein M+-Lauf starb an einem 429 in der ERSTEN Abfrage, weil der
      // Raidlauf davor die Stunde aufgebraucht hatte. Das Kontingent
      // kommt zurueck; was fehlte, war Geduld.
      if (err.status !== 429 || tries >= 6) throw err;
      const info = await quota();
      const wait = info && info.pointsResetIn
        ? Math.min(3600, Number(info.pointsResetIn) + 5) : 60;
      console.log(`
  Kontingent erschoepft, warte ${wait}s `
        + `(${info ? info.pointsSpentThisHour + '/' + info.limitPerHour : '?'})`);
      await sleep(wait * 1000);
    }
  }
}

function fetchText(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'MetaCodex-collector' } }, (res) => {
      if (res.statusCode !== 200) {
        res.resume();
        return reject(new Error(url + ' -> ' + res.statusCode));
      }
      let body = '';
      res.setEncoding('utf8');
      res.on('data', (c) => (body += c));
      res.on('end', () => resolve(body));
    }).on('error', reject);
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// --------------------------------------------------------------- Katalog

// Dieselbe Regel wie beim murlok-Sammler: Item-IDs kommen aus dem Katalog,
// nicht aus der Quelle. Die Logs liefern Verzauberungs-IDs; nur die Steine
// sind schon Gegenstaende.
function readCatalog(file) {
  const lua = fs.readFileSync(file, 'utf8');
  const gemIDs = new Set();
  const enchantByName = new Map();

  for (const m of lua.matchAll(
    /\{ id = (\d+),(?: alt = (\d+),)? stat = "([^"]+)"(?:, power = [\d.]+)?, name = "([^"]+)" \}/g)) {
    enchantByName.set(m[4].toLowerCase(), { id: +m[1], alt: m[2] ? +m[2] : null, name: m[4] });
  }
  for (const m of lua.matchAll(/\{ id = (\d+), major = "([^"]+)"/g)) gemIDs.add(+m[1]);
  const expansion = Number((lua.match(/expansion = (\d+)/) || [])[1]) || 0;
  return { gemIDs, enchantByName, expansion };
}

/** "Enchant Helm - Rune of Avoidance" -> "Rune of Avoidance" */
const stripSlot = (name) => name.replace(/^Enchant\s+[^-]+-\s*/i, '').trim();

// Die Ausruestungsplaetze fuer die Anzeige. Dieselben Namen wie bei
// murlok, damit beide Quellen in derselben Liste nebeneinander stehen
// koennen und die Oberflaeche nur eine Reihenfolge kennen muss.
const GEAR_SLOT = {
  0: 'Head', 1: 'Neck', 2: 'Shoulders', 4: 'Chest', 5: 'Waist',
  6: 'Legs', 7: 'Feet', 8: 'Wrist', 9: 'Hands', 10: 'Rings', 11: 'Rings',
  12: 'Trinkets', 13: 'Trinkets', 14: 'Back', 15: 'Main Hand', 16: 'Off Hand',
};

// Die Plaetze, an denen verzaubert wird - eigene Schluessel, weil der
// Katalog sie so fuehrt.
const SLOT_BY_INDEX = {
  0: 'helm', 2: 'shoulders', 4: 'chest', 6: 'legs', 7: 'boots',
  10: 'ring', 11: 'ring', 15: 'weapon',
};

// -------------------------------------------------- Verbrauchsgueter

/**
 * Zauber-ID -> kaufbarer Gegenstand.
 *
 * Die Logs melden Verbrauchsgueter als AUREN, also als Zauber. Gekauft
 * wird aber ein Gegenstand, und zwischen beiden liegen zwei DB2-Tabellen:
 * ItemEffect kennt den Zauber, ItemXItemEffect den Gegenstand dazu.
 *
 * Dieselbe Regel wie ueberall: die ID kommt aus den Spieldaten, nicht aus
 * der Quelle. Von Warcraft Logs kommt nur, WAS benutzt wurde.
 */
async function readConsumableItems(build, expansion) {
  const [effects, links, items, spellEffects, itemClasses, spellNames] = await Promise.all([
    fetchText(`https://wago.tools/db2/ItemEffect/csv?build=${build}`).then(parseCSV),
    fetchText(`https://wago.tools/db2/ItemXItemEffect/csv?build=${build}`).then(parseCSV),
    fetchText(`https://wago.tools/db2/ItemSparse/csv?build=${build}`
      + `&filter%5BExpansionID%5D=${expansion}`).then(parseCSV),
    fetchText(`https://wago.tools/db2/SpellEffect/csv?build=${build}`).then(parseCSV),
    fetchText(`https://wago.tools/db2/Item/csv?build=${build}`).then(parseCSV),
    fetchText(`https://wago.tools/db2/SpellName/csv?build=${build}`).then(parseCSV),
  ]);

  // Nur Gegenstaende der laufenden Erweiterung: ein Zauber wie
  // "Well Fed" haengt an Dutzenden Speisen aus zwoelf Jahren, und die
  // aelteste zuerst zu treffen waere reine Willkuer.
  const current = new Map();
  for (const row of items) {
    current.set(Number(row.ID), { name: row.Display_lang, ilvl: Number(row.ItemLevel) || 0 });
  }

  const itemByEffect = new Map();
  for (const row of links) {
    const itemID = Number(row.ItemID);
    if (current.has(itemID)) itemByEffect.set(row.ItemEffectID, itemID);
  }

  const bySpell = new Map();
  for (const row of effects) {
    const spellID = Number(row.SpellID);
    const itemID = itemByEffect.get(row.ID);
    if (!spellID || !itemID) continue;
    // Mehrere Gegenstaende koennen denselben Zauber ausloesen. Der mit der
    // hoechsten Gegenstandsstufe ist der aktuelle Rang.
    const known = bySpell.get(spellID);
    if (!known || current.get(itemID).ilvl > current.get(known).ilvl) {
      bySpell.set(spellID, itemID);
    }
  }

  // Speisen melden sich nicht unter dem Zauber, den der Gegenstand
  // ausloest. Wer isst, wirkt "Food"; sichtbar wird aber erst der
  // Buff, den dieser Zauber NACHZIEHT, und der heisst "Hearty Well
  // Fed". In den Logs steht nur der zweite. Der Weg dorthin steht in
  // SpellEffect als EffectTriggerSpell - also folgen wir ihm und
  // lassen den nachgezogenen Zauber auf denselben Gegenstand zeigen.
  const triggers = new Map();
  for (const row of spellEffects) {
    const from = Number(row.SpellID);
    const to = Number(row.EffectTriggerSpell);
    if (!from || !to || from === to) continue;
    if (!triggers.has(from)) triggers.set(from, []);
    triggers.get(from).push(to);
  }

  // Zwei Spruenge, nicht mehr: Zauber koennen einander im Kreis
  // ausloesen, und eine unbegrenzte Suche wuerde am Ende jedes
  // Verbrauchsgut mit jedem anderen verbinden.
  let frontier = [...bySpell.keys()];
  for (let hop = 0; hop < 2; hop++) {
    const next = [];
    for (const spellID of frontier) {
      const itemID = bySpell.get(spellID);
      for (const to of triggers.get(spellID) || []) {
        // Eine direkte Zuordnung ist die bessere und bleibt stehen.
        if (bySpell.has(to)) continue;
        bySpell.set(to, itemID);
        next.push(to);
      }
    }
    frontier = next;
  }

  // Die Art eines Verbrauchsguts steht in der Item-Tabelle, nicht im
  // Namen: Klasse 0 ist "Verbrauchsgut", die Unterklasse sagt welches.
  const SUBCLASS = { 1: 'potion', 3: 'flask', 5: 'food', 8: 'other', 9: 'vantus' };
  const kindOf = new Map();
  for (const row of itemClasses) {
    if (Number(row.ClassID) !== 0) continue;
    kindOf.set(Number(row.ID), SUBCLASS[Number(row.SubclassID)] || 'other');
  }

  // Heiltrank oder Kampftrank?
  //
  // Die Unterklasse kennt den Unterschied nicht, beide sind "Trank".
  // Archon trennt sie, und zu Recht: der eine gehoert in die Rotation,
  // der andere in den Notfall. Die Wirkung trennt sie sauber - Effekt 10
  // ist SPELL_EFFECT_HEAL, und genau acht der 59 Traenke tragen ihn.
  //
  // Ueber die Wirkung, nicht ueber den Namen: "Refreshing Serum" heisst
  // nicht Heiltrank und ist einer.
  const HEAL_EFFECT = '10';
  const healSpells = new Set();
  for (const row of spellEffects) {
    if (row.Effect === HEAL_EFFECT) healSpells.add(Number(row.SpellID));
  }
  for (const row of effects) {
    const itemID = itemByEffect.get(row.ID);
    if (!itemID || kindOf.get(itemID) !== 'potion') continue;
    if (healSpells.has(Number(row.SpellID))) kindOf.set(itemID, 'heal');
  }

  // Speisen sind der eine Fall, in dem der Name gebraucht wird - und
  // zwar der des ZAUBERS, nicht der des Gegenstands. Grund: jede Speise
  // dieser Stufe loest denselben Buff aus ("Hearty Well Fed"), und
  // dieser Buff haengt an keinem Gegenstand. Es gibt keinen Weg durch
  // die Spieldaten von ihm zurueck - nachgeprueft ueber acht Spruenge
  // durch EffectTriggerSpell, ohne einen einzigen Treffer. Aus den Logs
  // ist daher nur zu erfahren, DASS jemand gegessen hat. Was kaufbar
  // ist, steht im Katalog.
  const fedSpells = new Set();
  for (const row of spellNames) {
    if (/well fed/i.test(row.Name_lang || '')) fedSpells.add(Number(row.ID));
  }

  // Die Zauber, die ein Verbrauchsgut WIRKT - fuer den Serverfilter.
  //
  // Hier liegt die Antwort auf die Speisenfrage, an der ich zweimal
  // vorbeigelaufen bin. Die Aura sagt nur "Hearty Well Fed"; die
  // WIRKUNG dagegen nennt den Gegenstand. Sie steht nicht im Kampf -
  // gegessen wird davor -, deshalb muss ueber den ganzen Bericht
  // gesucht werden. Das waeren 56 000 Ereignisse auf sieben Seiten;
  // mit diesem Filter sind es 231 auf einer.
  const castSpells = [];
  for (const row of effects) {
    const itemID = itemByEffect.get(row.ID);
    if (!itemID || !current.has(itemID)) continue;
    if (!kindOf.has(itemID)) continue;
    castSpells.push(Number(row.SpellID));
  }

  return {
    bySpell, names: current, kindOf, fedSpells,
    castFilter: 'ability.id in (' + [...new Set(castSpells)].join(', ') + ')',
  };
}

/**
 * Talenteintrag -> Zauber.
 *
 * Die Logs melden je Spieler eine Liste aus { id, rank, nodeID }. Die `id`
 * ist ein TraitNodeEntry, und der fuehrt ueber TraitDefinition zum Zauber.
 *
 * Warum nicht gleich der Name: derselbe Grund wie ueberall. Es reist eine
 * ID, und der Client setzt den Namen ein - damit stimmt er auf einem
 * deutschen Client genauso wie auf einem koreanischen.
 */
async function readTalentSpells(build) {
  const [entries, defs] = await Promise.all([
    fetchText(`https://wago.tools/db2/TraitNodeEntry/csv?build=${build}`).then(parseCSV),
    fetchText(`https://wago.tools/db2/TraitDefinition/csv?build=${build}`).then(parseCSV),
  ]);
  const spellByDef = new Map();
  for (const row of defs) {
    const spellID = Number(row.SpellID) || Number(row.VisibleSpellID) || 0;
    if (spellID) spellByDef.set(Number(row.ID), spellID);
  }
  const byEntry = new Map();
  for (const row of entries) {
    const spellID = spellByDef.get(Number(row.TraitDefinitionID));
    // Knoten ohne Definition sind Untertbaum-Wahlen (Heldentalente).
    // Sie tragen keinen Zauber und werden uebersprungen statt geraten.
    if (spellID) byEntry.set(Number(row.ID), spellID);
  }
  return byEntry;
}

// --------------------------------------------------------------- Speccs

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

// Die Logs nennen Klasse und Spec im Klartext ("Warlock", "Demonology");
// die ID dazu steht im Spiel. Eine Tabelle von Hand waere beim naechsten
// Addon falsch.
//
// Geschrieben wird beides aber unterschiedlich: die Logs sagen
// "DeathKnight", die Spieldaten "Death Knight". Deshalb wird beim
// Nachschlagen alles ausser Buchstaben und Ziffern entfernt - sonst fallen
// genau die mehrteiligen Klassennamen durch, und zwar stillschweigend.
const specKey = (cls, spec) =>
  `${cls || ''}${spec || ''}`.toLowerCase().replace(/[^a-z0-9]/g, '');

/**
 * Klassen- und Specname je Spec-ID, so geschrieben, wie die Warcraft-Logs-
 * Abfrage sie will: ohne Leerzeichen ("DeathKnight", "BeastMastery").
 */
async function readSpecNames() {
  const builds = JSON.parse(await fetchText('https://wago.tools/api/builds'));
  const build = builds.wow[0].version;
  const [specs, classes] = await Promise.all([
    fetchText(`https://wago.tools/db2/ChrSpecialization/csv?build=${build}`).then(parseCSV),
    fetchText(`https://wago.tools/db2/ChrClasses/csv?build=${build}`).then(parseCSV),
  ]);
  const className = new Map(classes.map((c) => [c.ID, c.Name_lang]));
  const out = new Map();
  for (const spec of specs) {
    const cls = className.get(spec.ClassID);
    if (!cls || !spec.Name_lang || Number(spec.OrderIndex) > 3) continue;
    const tidy = (t) => String(t).replace(/[^A-Za-z]/g, '');
    out.set(Number(spec.ID), { cls: tidy(cls), spec: tidy(spec.Name_lang), healer: Number(spec.Role) === 1 });
  }
  return out;
}

async function readSpecIndex() {
  const builds = JSON.parse(await fetchText('https://wago.tools/api/builds'));
  const build = builds.wow[0].version;
  const [specs, classes] = await Promise.all([
    fetchText(`https://wago.tools/db2/ChrSpecialization/csv?build=${build}`).then(parseCSV),
    fetchText(`https://wago.tools/db2/ChrClasses/csv?build=${build}`).then(parseCSV),
  ]);
  const className = new Map(classes.map((c) => [c.ID, c.Name_lang]));
  const index = new Map();
  for (const spec of specs) {
    const cls = className.get(spec.ClassID);
    if (!cls || !spec.Name_lang || Number(spec.OrderIndex) > 3) continue;
    index.set(specKey(cls, spec.Name_lang), Number(spec.ID));
  }
  return index;
}

/**
 * Die aktuelle Raidzone. Neueste zuerst.
 *
 * Die hoechste Zonennummer zu nehmen reicht nicht: darueber liegen
 * Mythic+-Saisons, PTR-Staende und ein "Dummy Dome". Der erste Versuch
 * landete deshalb bei Throne of Thunder aus Mists of Pandaria.
 */
function raidZones(expansions) {
  const out = [];
  for (const exp of expansions) {
    for (const zone of exp.zones || []) {
      // Ein Boss reicht: es gibt Raids mit genau einem. Die alte
      // Schwelle von dreien warf die "Grotte" weg, ohne es zu sagen.
      if (!zone.encounters || !zone.encounters.length) continue;
      // Eingefroren heisst bei Warcraft Logs: abgelaufenes Tier. Das
      // ist die Auskunft, die vorher aus der Zonennummer geraten wurde.
      if (zone.frozen) continue;
      // "Complete Raid" ist keine Zone mit Bossen, sondern die
      // Gesamtwertung ueber den ganzen Raid. Ihr Kampf traegt die
      // Nummer 10000 und keine Spielerdaten - abgerufen wird er
      // trotzdem, und das kostet Kontingent fuer nichts.
      if (/mythic\+|ptr|beta|dummy|complete raid/i.test(zone.name)) continue;
      out.push({ ...zone, expansion: exp.name });
    }
  }
  return out.sort((a, b) => b.id - a.id);
}

/**
 * Die Mythic+-Saison. Neueste zuerst.
 *
 * Dieselbe Falle wie beim Raid: ueber der laufenden Saison liegt schon
 * ein PTR-Eintrag, und der hat keine einzige Wertung.
 */
function mythicZones(expansions) {
  const out = [];
  for (const exp of expansions) {
    for (const zone of exp.zones || []) {
      if (!/mythic\+/i.test(zone.name)) continue;
      if (/ptr|beta/i.test(zone.name)) continue;
      if (!zone.encounters || !zone.encounters.length) continue;
      out.push({ ...zone, expansion: exp.name });
    }
  }
  return out.sort((a, b) => b.id - a.id);
}

// ------------------------------------------------------------------ Lauf

(async () => {
  console.log('Anmelden ...');
  // Auch der Token wartet, statt aufzugeben: ein erschoepftes Kontingent
  // trifft ihn genauso wie eine Abfrage, und ohne ihn laeuft gar nichts.
  for (let tries = 0; ; tries++) {
    try { token = await getToken(); break; } catch (err) {
      if (err.status !== 429 || tries >= 6) throw err;
      console.log('  Kontingent erschoepft beim Anmelden, warte 120s');
      await sleep(120000);
    }
  }
  console.log('  Token erhalten.');

  // Warnung, keine Sperre.
  //
  // Warcraft Logs rechnet in Punkten je Stunde. Ein voller M+-Durchgang
  // ueber Ausruestung, Verzauberungen und Talente hat sie an einem Abend
  // verbrannt; die drei folgenden Sammlungen starben an HTTP 429 und
  // schrieben nichts.
  //
  // Dieselben Daten liegen bei raider.io ohne Kontingent. Was HIER geholt
  // werden muss, sind Verbrauchsgueter und Raid - die fuehrt kein
  // Aggregator. Wer trotzdem den vollen M+-Lauf will, bekommt ihn; er
  // soll nur wissen, was er ausgibt.
  if (KIND === 'mplus' && !process.env.MC_QUIET) {
    console.log('  Hinweis: Ausruestung, Verzauberungen, Steine und Talente');
    console.log('  fuer M+ kommen guenstiger von raider.io - hier zaehlt vor');
    console.log('  allem der Verbrauchsgueter-Teil. Siehe tools/collect-all.js.');
  }
  const room = await quota();
  if (room) {
    console.log(`  Kontingent: ${room.pointsSpentThisHour} von `
      + `${room.limitPerHour} verbraucht, Ruecksetzung in ${room.pointsResetIn}s`);
  }

  const world = await gql(`
    query {
      worldData {
        expansions { id name zones { id name frozen encounters { id name } } }
      }
    }`);
  const zones = KIND === 'mplus'
    ? mythicZones(world.worldData.expansions)
    : raidZones(world.worldData.expansions);
  if (!zones.length) throw new Error('Keine Zone gefunden.');

  // Die hoechste Zonennummer ist nicht zwangslaeufig die gespielte: ueber
  // dem laufenden Raid liegt oft schon ein Eintrag fuer den naechsten, der
  // noch keine einzige Wertung hat. Deshalb wird nicht geraten, sondern
  // gefragt - die erste Zone mit Ranglistenplaetzen gewinnt.
  // ALLE laufenden Zonen, nicht die erste mit Wertungen. Zwei Raids
  // nebeneinander sind seit Jahren der Normalfall, und wer nur den
  // ersten nimmt, nennt das Ergebnis trotzdem "Raid".
  //
  // Bei M+ ist es weiterhin eine Zone: die Saison.
  const wanted = Number(process.env.MC_ZONE || 0);
  const chosen = [];
  if (wanted) {
    const z = zones.find((z) => z.id === wanted);
    if (z) chosen.push(z);
  } else {
    for (const candidate of zones.slice(0, 6)) {
      const probe = await gql(`
        query ($e: Int!, $d: Int!) {
          worldData { encounter(id: $e) {
            characterRankings(difficulty: $d, metric: dps, page: 1)
          } }
        }`, { e: candidate.encounters[0].id, d: DIFFICULTY });
      const found = ((probe.worldData.encounter.characterRankings || {}).rankings || []).length;
      console.log(`  Zone ${candidate.id} ${candidate.name}: ${found} Wertungen`);
      if (found > 0) {
        chosen.push(candidate);
        if (KIND === 'mplus') break;
      }
      await sleep(250);
    }
  }
  if (!chosen.length) throw new Error('Keine Zone mit Wertungen. Andere Schwierigkeit versuchen.');
  const zone = chosen[0];
  for (const z of chosen) {
    console.log(`Zone: ${z.name} (id ${z.id}, ${z.encounters.length} Begegnungen, ${z.expansion})`);
  }

  // --- Berichte einsammeln --------------------------------------------
  const reports = new Map();
  // Jede Begegnung kennt ihren Raid: so heisst die Auswahl im Fenster
  // spaeter "Giftige Abgruende: Nek'zali" und nicht nur "Nek'zali".
  // MC_ENCOUNTERS begrenzt nur noch, wenn es gesetzt ist - alle Bosse
  // sind die Vorgabe, denn vier von neun sind kein Raid.
  let encounters = [];
  for (const z of chosen) {
    for (const enc of z.encounters) encounters.push({ ...enc, raid: chosen.length > 1 ? z.name : null });
  }
  const cap = Number(process.env.MC_ENCOUNTERS || 0);
  if (cap > 0) encounters = encounters.slice(0, cap);
  // Mehr als eine Seite, und zwar aus zwei Gruenden.
  //
  // Erstens die Abdeckung: Seite 1 sind hundert Spitzenparses, und die
  // verteilen sich nicht gleichmaessig auf vierzig Speccs - ein Lauf
  // ueber nur eine Seite liess regelmaessig ein Drittel aus.
  //
  // Zweitens die Schluesselstufe: ganz oben in der Rangliste steht
  // ausschliesslich Hohes. Solange nur Seite 1 gelesen wird, sind
  // "alle Keys" und "hohe Keys" dieselbe Menge, und der Filter waere
  // eine Behauptung ohne Unterschied.
  const PAGES = Number(process.env.MC_PAGES || 3);
  // Entweder mehrere Seiten derselben Rangliste, oder je eine Seite je
  // Schluesselstufe. Beides ist eine Schleife mit derselben Form,
  // deshalb eine Liste statt zweier Zweige.
  const slices = KEY_RANGE
    ? Array.from({ length: KEY_TO - KEY_FROM + 1 },
      (_, i) => ({ bracket: KEY_FROM + i - 1, label: `+${KEY_FROM + i}` }))
    : Array.from({ length: PAGES }, (_, i) => ({ page: i + 1, label: `S.${i + 1}` }));
  for (const enc of encounters) {
    for (const metric of ['dps', 'hps']) {
      for (const slice of slices) {
      const page = slice.page || 1;
      let data;
      try {
        data = await gql(`
          query ($encounter: Int!, $difficulty: Int!, $metric: CharacterRankingMetricType!, $page: Int!, $bracket: Int) {
            worldData { encounter(id: $encounter) {
              characterRankings(difficulty: $difficulty, metric: $metric, page: $page, bracket: $bracket)
            } }
          }`, { encounter: enc.id, difficulty: DIFFICULTY, metric, page,
            bracket: slice.bracket !== undefined ? slice.bracket : null });
      } catch (err) {
        console.log(`  ! ${enc.name}/${metric} ${slice.label}: ${err.message}`);
        continue;
      }
      const list = (data.worldData.encounter.characterRankings || {}).rankings || [];
      for (const rank of list) {
        const report = rank.report;
        if (report && report.code && !reports.has(report.code)) {
          // bracketData ist bei M+ die Schluesselstufe. Beim Raid ist
          // sie bedeutungslos und bleibt ungenutzt.
          reports.set(report.code, {
            fightID: report.fightID,
            key: Number(rank.bracketData) || 0,
            dungeon: enc.name,
            raid: enc.raid || null,
          });
        }
      }
      console.log(`  ${enc.name} / ${metric} ${slice.label}: ${list.length} Plaetze, ${reports.size} Berichte`);
      await sleep(250);
      // Eine leere Seite heisst: die Rangliste ist zu Ende. Bei den
      // Schluesselstufen heisst sie nur, dass DIESE Stufe leer ist -
      // die naechste kann voll sein.
      if (!list.length && !KEY_RANGE) break;
      }
    }
  }

  // Welche Schluesselstufen ueberhaupt in der Stichprobe liegen.
  //
  // Das Ergebnis war eine Ueberraschung und hat den Plan geaendert:
  // characterRankings ist nach Wertung sortiert, und darin stehen
  // ausschliesslich die hoechsten Keys - ueber acht Seiten hinweg nur
  // +20 und +21. Ein Filter "nur hohe Keys" haette hier nichts zu
  // filtern. Statt einen Schalter ohne Wirkung anzubieten, reist die
  // beobachtete Spanne mit den Daten und wird angezeigt.
  let keyRange = null;
  if (KIND === 'mplus') {
    const keys = [...reports.values()].map((r) => r.key).filter((k) => k > 0);
    if (keys.length) {
      keyRange = [Math.min(...keys), Math.max(...keys)];
      console.log(`
Schluesselstufen: +${keyRange[0]} bis +${keyRange[1]}`
        + ` aus ${keys.length} Laeufen`);
    }
  }

  if (PROBE) {
    console.log('\nSonde: ein Bericht, und dann wird hingeschaut.');
    const [code, info] = [...reports.entries()][0] || [];
    const fightID = info && info.fightID;
    if (!code) throw new Error('Keine Berichte in den Ranglisten.');
    const data = await gql(`
      query ($code: String!, $fight: Int!) {
        reportData { report(code: $code) { table(dataType: Summary, fightIDs: [$fight]) } }
      }`, { code, fight: fightID });
    const details = data.reportData.report.table.data.playerDetails;
    console.log(`  Gruppen: ${Object.keys(details).join(', ')}`);
    const first = (details.dps || details.healers || details.tanks || [])[0];
    if (first) {
      console.log(`  Felder je Spieler: ${Object.keys(first).join(', ')}`);
      console.log(`  type/icon: ${first.type} / ${first.icon}`);
      const gear = first.combatantInfo && first.combatantInfo.gear;
      console.log(`  Gear dabei: ${gear ? 'JA, ' + gear.length + ' Teile' : 'nein'}`);
      if (gear) console.log('  Beispiel:', JSON.stringify(gear.slice(0, 2)));
    }
    console.log('\nSonde fertig. Es wurde nichts geschrieben.');
    return;
  }

  const limit = Number(process.env.MC_REPORTS || 120);

  // Reihum statt der Reihe nach.
  //
  // Die Berichte kommen Dungeon fuer Dungeon und Stufe fuer Stufe
  // herein. Wer davon die ersten vierhundert nimmt, liest zweitausend
  // Spieler aus EINEM Dungeon bei EINER Schluesselstufe und nennt das
  // Ergebnis "M+". Also wird abwechselnd gezogen, bis die Grenze steht.
  const buckets = new Map();
  for (const entry of reports.entries()) {
    const info = entry[1];
    const key = (info.dungeon || '-') + '|' + (info.key || 0);
    if (!buckets.has(key)) buckets.set(key, []);
    buckets.get(key).push(entry);
  }
  const lists = [...buckets.values()];
  const codes = [];
  for (let round = 0; codes.length < limit; round++) {
    let took = 0;
    for (const list of lists) {
      if (round >= list.length) continue;
      codes.push(list[round]);
      took++;
      if (codes.length >= limit) break;
    }
    if (!took) break;
  }
  console.log(`
Berichte abrufen: ${codes.length} aus ${reports.size}, `
    + `verteilt auf ${lists.length} Gruppen (Dungeon x Stufe)`);

  const catalog = readCatalog(path.join(BASE, 'MetaCodex_Data', 'Catalog.lua'));
  const builds = JSON.parse(await fetchText('https://wago.tools/api/builds'));
  const gameBuild = builds.wow[0].version;

  // Die Logs melden Verzauberungen und Verbrauchsgueter als IDs. Beide
  // Uebersetzungen kommen aus den Spieldaten, nicht aus den Logs -
  // dieselbe Regel wie ueberall in diesem Projekt.
  const enchantMap = JSON.parse(fs.readFileSync(
    path.join(BASE, 'tools', 'data', 'enchant-map.json'), 'utf8'));
  // Und die Runen, die keinen Gegenstand haben.
  let runeforgeMap = {};
  try {
    runeforgeMap = JSON.parse(fs.readFileSync(
      path.join(BASE, 'tools', 'data', 'runeforge-map.json'), 'utf8'));
  } catch (e) { /* ohne Karte zaehlt nur, was gekauft wird */ }
  const consumables = await readConsumableItems(gameBuild, catalog.expansion);
  const talentSpells = await readTalentSpells(gameBuild);
  // Held-Baum je Talenteintrag und die Folio-Runen - aus der Baumkarte,
  // die build-catalog.js aus den Spieldaten schreibt.
  const entrySubTree = new Map();
  const folioAura = new Map();   // Auren-ID -> Runen-Zauber
  let folioFilter = '';          // fuer die Abfrage: nur diese Auren
  try {
    const tm = JSON.parse(fs.readFileSync(path.join(BASE, 'tools', 'data', 'trait-map.json'), 'utf8'));
    for (const tree of Object.values(tm.trees || {})) {
      // Der Held-Baum steht am Knoten; ein Eintrag traegt ihn nur selten selbst.
      for (const node of tree.nodes) for (const e of node.entries) { const sub = node.subTree || e.subTree; if (sub) entrySubTree.set(e.id, sub); }
    }
    for (const row of tm.folio || []) for (const r of row) for (const a of r.auras || []) folioAura.set(a, r.spell);
    if (folioAura.size) {
      folioFilter = 'ability.id in (' + [...folioAura.keys()].join(', ') + ')';
    }
    console.log('Baumkarte: ' + entrySubTree.size + ' Held-Eintraege, ' + folioAura.size + ' Folio-Auren');
  } catch (e) { console.log('  ! keine trait-map.json - ohne Held-Baeume und Folio'); }

  console.log(`Katalog: ${catalog.enchantByName.size} Verzauberungen, ${catalog.gemIDs.size} Steine`);
  console.log(`Verzauberungs-IDs: ${Object.keys(enchantMap).length}, `
    + `Verbrauchsgueter: ${consumables.bySpell.size}, `
    + `Talente: ${talentSpells.size}`);
  console.log('');

  // Ein Zaehlwerk je Modus. Bei M+ faellt aus DEMSELBEN Durchlauf
  // zusaetzlich die Auswertung der hohen Keys ab - dieselben Kaempfe,
  // nur enger gefiltert. Ein zweiter Durchlauf waere doppelt so viele
  // Abfragen fuer Daten, die schon da sind.
  // Was zu welchem Zaehlwerk gehoert. Der Name ist nur ein Schluessel;
  // was er bedeutet, steht hier - nicht in einer Zeichenkette, die
  // spaeter jemand auseinandernehmen muss.
  const meta = { [BASE_MODE]: { mode: BASE_MODE } };
  const bonusByItem = new Map();   // itemID -> { ilvl, list }
  const tallies = {};
  const tallyFor = (mode) => tallies[mode] || (tallies[mode] = {});
  const entryFor = (mode, specID) => {
    const t = tallyFor(mode);
    return t[specID] || (t[specID] = {
      enchants: {}, gems: {}, consumables: {}, gear: {},
      talents: {}, builds: {}, ratings: [], maxKey: {}, players: 0,
      names: [],
      hero: {}, folio: {},
    });
  };
  // Welche Zaehlwerke der gerade gelesene Kampf fuettert.
  let active = [BASE_MODE];
  // Bei welcher Schluesselstufe ein Gegenstand zuletzt gesehen wurde.
  // Archon zeigt diese Spalte, und sie beantwortet etwas, das ein
  // Prozentwert nicht kann: ob etwas auch oben noch getragen wird.
  let currentKey = 0;
  const bump = (specID, bucket, id) => {
    for (const mode of active) {
      const spec = entryFor(mode, specID);
      if (currentKey > (spec.maxKey[id] || 0)) spec.maxKey[id] = currentKey;
      if (bucket === 'gems' || bucket === 'consumables') {
        spec[bucket][id] = (spec[bucket][id] || 0) + 1;
      } else {
        const slot = spec.enchants[bucket] || (spec.enchants[bucket] = {});
        slot[id] = (slot[id] || 0) + 1;
      }
    }
  };

  // Was nicht zugeordnet werden konnte, wird benannt statt verschwiegen -
  // genau daran haette man den enchantID-Fehler sofort gesehen.
  const missedEnchants = new Set();
  let players = 0, unknownSpec = 0;
  // Ein Abruf je Kampf, und darin steht alles.
  //
  // Die Summary-Tabelle davor lieferte Ausruestung, aber keine Auren -
  // Verbrauchsgueter waren damit nicht erreichbar. CombatantInfo liefert
  // je Spieler die Spec-ID direkt (kein Namensabgleich mehr), die
  // Ausruestung, die Auren beim Pull und die Talente. Gleicher Preis,
  // dreifacher Ertrag.
  const readReports = async (codes) => {
  for (const [code, info] of codes) {
    const fightID = info.fightID;
    // Ein hoher Key zaehlt in beide Auswertungen: er ist ein M+-Lauf
    // und ausserdem ein hoher.
    active = [BASE_MODE];
    // NUR bei M+ ist bracketData die Schluesselstufe. Im Raid ist es
    // die Gegenstandsstufen-Klasse, und die stand als "bis +333" im
    // Fenster - eine Zahl, die es im Spiel nicht gibt.
    currentKey = (KIND === 'mplus') ? (info.key || 0) : 0;
    // Je Dungeon bei M+, je BOSS im Raid. Dieselbe Mechanik, und im Raid
    // ist sie sogar wichtiger: Talente unterscheiden sich zwischen zwei
    // Bossen staerker als zwischen zwei Dungeons.
    if (PER_DUNGEON && info.dungeon) {
      const name = `${BASE_MODE}/${slug(info.dungeon)}`;
      active.push(name);
      meta[name] = { mode: BASE_MODE, dungeon: info.dungeon, raid: info.raid || null };
    }
    let data;
    try {
      // Die Folio-Runen stehen NICHT im CombatantInfo.
      //
      // Nachgesehen statt geraten: das Ereignis fuehrt Ausruestung,
      // Auren beim Pull, Talente und drei leere "customPower"-Felder -
      // keine Rune. Sie erscheinen als Buff WAEHREND des Kampfes. Also
      // werden sie hier mitgeholt, in derselben Anfrage und auf die
      // Runen gefiltert; ein zweiter Rundgang waere teurer.
      data = await gql(`
        query ($code: String!, $fight: Int!) {
          reportData { report(code: $code) {
            events(dataType: CombatantInfo, fightIDs: [$fight], limit: 60) { data }
            ${folioFilter ? `folio: events(dataType: Buffs, fightIDs: [$fight], limit: 400, filterExpression: "${folioFilter}") { data }` : ''}
            masterData { actors(type: "Player") { id name server } }
            region { slug }
          } }
        }`, { code, fight: fightID });
    } catch (err) {
      process.stdout.write('!');
      await sleep(250);
      continue;
    }

    const report = data.reportData.report;
    const events = (report && report.events && report.events.data) || [];
    // Wer die Spieler SIND. Die Kampfdaten tragen nur eine Nummer;
    // Name und Realm stehen im Stammblatt des Berichts. Gebraucht wird
    // das fuer genau eines: das raider.io-Profil desselben Spielers zu
    // finden, das die Talentkette fertig mitbringt.
    const actorByID = new Map();
    for (const actor of (report && report.masterData && report.masterData.actors) || []) {
      actorByID.set(Number(actor.id), { name: actor.name, server: actor.server });
    }
    const region = (report && report.region && report.region.slug) || null;
    if (!events.length) { process.stdout.write('-'); await sleep(250); continue; }

    // Welcher Spieler welche Spec hat. Die Wirkungen weiter unten
    // tragen nur eine sourceID; ohne diese Karte liessen sie sich
    // keiner Spec zuordnen.
    const specBySource = new Map();
    // Was schon aus den Auren gezaehlt wurde.
    //
    // Eine Verstaerkungsrune steht BEIDES: als Aura beim Pull und als
    // Wirkung davor. Ohne diese Liste wurde sie zweimal gezaehlt, und im
    // Fenster stand "135 %" - eine Zahl, die es nicht geben kann.
    const fromAura = new Map();

    for (const event of events) {
      const specID = Number(event.specID);
      if (!specID || !Array.isArray(event.gear)) { unknownSpec++; continue; }
      players++;
      if (event.sourceID !== undefined) specBySource.set(Number(event.sourceID), specID);
      const seenAll = active.map((mode) => entryFor(mode, specID));
      for (const seen of seenAll) {
        seen.players = seen.players + 1;
        // Der Merker gilt fuer DIESEN Spieler, nicht fuer die Spec.
        seen.fed = false;
      }
      const seen = seenAll[0];

      const oiled = new Set();
      event.gear.forEach((piece, index) => {
        if (!piece || !piece.id) return;
        // Das Waffenoel: eine ZEITWEILIGE Verzauberung, und deshalb
        // ein eigenes Feld. Es stand die ganze Zeit da; nur kannte
        // die Karte seine IDs nicht, weil sie aus Effekt 53 gebaut
        // war und ein Oel Effekt 54 traegt.
        if (piece.temporaryEnchant) {
          const oilID = enchantMap[piece.temporaryEnchant];
          // Einmal je Spieler, auch bei zwei Waffen. Sonst stand "200 %".
          if (oilID && !oiled.has(oilID)) { oiled.add(oilID); bump(specID, 'consumables', oilID); }
        }
        const slot = SLOT_BY_INDEX[index];
        if (slot && piece.permanentEnchant) {
          const itemID = enchantMap[piece.permanentEnchant];
          if (itemID) bump(specID, slot, itemID);
          else if (runeforgeMap[piece.permanentEnchant]) {
            // Eine Runenschmiede. Kein Gegenstand, aber sehr wohl das,
            // was auf der Waffe sitzt - und fuer den Todesritter die
            // einzige Antwort auf "was gehoert auf die Waffe".
            bump(specID, 'runeforge', Number(piece.permanentEnchant));
          } else missedEnchants.add(String(piece.permanentEnchant));
        }
        for (const gem of piece.gems || []) {
          if (gem && gem.id && catalog.gemIDs.has(gem.id)) bump(specID, 'gems', gem.id);
        }

        // Die Ausruestung selbst, mit der Stufe, die der Spieler
        // WIRKLICH getragen hat. Das ist der Punkt, an dem diese
        // Quelle murlok schlaegt: dort steht die Stufe nirgends.
        // Dieselbe Tabelle wie beim anderen Sammler, aus demselben
        // Grund: ohne Bonus-IDs zeigt das Tooltip die Grundstufe.
        const pieceLevel = Number(piece.itemLevel) || 0;
        const knownBonus = bonusByItem.get(piece.id);
        if ((!knownBonus || pieceLevel > knownBonus.ilvl)
            && Array.isArray(piece.bonusIDs)) {
          bonusByItem.set(piece.id, { ilvl: pieceLevel, list: piece.bonusIDs });
        }

        const display = GEAR_SLOT[index];
        if (display) {
          for (const spec of seenAll) {
            const slot = spec.gear[display] || (spec.gear[display] = {});
            const row = slot[piece.id] || (slot[piece.id] = { n: 0, ilvl: 0 });
            row.n = row.n + 1;
            row.ilvl = Math.max(row.ilvl, Number(piece.itemLevel) || 0);
          }
        }
      });

      // Die Kennwerte, die der Spieler beim Pull wirklich hatte.
      //
      // Damit werden Zielwerte messbar statt geschaetzt: nicht "Tempo vor
      // Meisterschaft", sondern eine Zahl, gegen die man das eigene
      // Zeichenblatt halten kann.
      //
      // Gesammelt werden alle Werte einzeln, nicht als laufende Summe -
      // gebraucht wird der MEDIAN. Ein Durchschnitt kippt schon durch
      // einen einzigen Ausreisser, und in Ranglisten stehen Ausreisser.
      const rating = {
        crit: Math.round(Number(event.critMelee) || Number(event.critSpell) || 0),
        haste: Math.round(Number(event.hasteMelee) || Number(event.hasteSpell) || 0),
        mastery: Math.round(Number(event.mastery) || 0),
        vers: Math.round(Number(event.versatilityDamageDone) || 0),
      };
      if (rating.crit + rating.haste + rating.mastery + rating.vers > 0) {
        for (const spec of seenAll) spec.ratings.push(rating);
      }

      // Talente. Zwei Fragen, zwei Zaehlungen:
      //
      // Wie oft wird ein einzelnes Talent genommen - das beantwortet
      // "lohnt sich das?". Und welcher VOLLSTAENDIGE Build kommt am
      // haeufigsten vor - das beantwortet "was soll ich einstellen?".
      // Die zweite ist nicht aus der ersten ableitbar: die haeufigsten
      // Einzeltalente ergeben zusammen oft einen Build, den so niemand
      // spielt, weil sie einander ausschliessen.
      const picked = [];
      // Der Held-Baum dieses Spielers: der Baum, dem seine Eintraege
      // angehoeren. Ein Spieler hat genau einen.
      let heroTree = 0;
      for (const node of event.talentTree || []) {
        const sub = entrySubTree.get(Number(node.id));
        if (sub) { heroTree = sub; break; }
      }
      const heroTallies = heroTree ? seenAll.map((spec) => spec.hero[heroTree] || (spec.hero[heroTree] = {
        talents: {}, builds: {}, players: 0,
      })) : [];
      for (const h of heroTallies) h.players += 1;
      for (const node of event.talentTree || []) {
        const spellID = talentSpells.get(Number(node.id));
        if (!spellID) continue;
        const rank = Number(node.rank) || 1;
        picked.push(spellID + ':' + rank);
        const key = spellID + '|' + rank;
        for (const spec of seenAll) {
          spec.talents[key] = (spec.talents[key] || 0) + 1;
        }
        for (const h of heroTallies) h.talents[key] = (h.talents[key] || 0) + 1;
      }
      if (picked.length) {
        picked.sort();
        const signature = picked.join(',');
        for (const spec of seenAll) {
          spec.builds[signature] = (spec.builds[signature] || 0) + 1;
        }
        for (const h of heroTallies) h.builds[signature] = (h.builds[signature] || 0) + 1;
        // Name, Realm und die Talente DIESES Kampfes. Damit laesst sich
        // spaeter pruefen, ob die Kette aus dem Profil wirklich der
        // Build ist, der hier gespielt wurde - und nicht der M+-Build
        // vom Tag danach.
        const actor = actorByID.get(Number(event.sourceID));
        if (actor && actor.name && actor.server && region && seen.names.length < 40) {
          seen.names.push({ name: actor.name, server: actor.server, region, spells: picked });
        }
      }

      // Auren beim Pull: Flaeschchen, Essen, Runen. Was sich keinem
      // kaufbaren Gegenstand der laufenden Erweiterung zuordnen laesst,
      // faellt weg - Klassenbuffs und Bosseffekte gehoeren nicht auf
      // einen Einkaufszettel.
      for (const aura of event.auras || []) {
        const spellID = Number(aura.ability);
        // Eine Folio-Rune? Dann zaehlt sie hier - und sonst nirgends: sie
        // ist kein Gegenstand und kein Talent, nur eine Aura beim Pull.
        const rune = folioAura.get(spellID);
        if (rune) { for (const spec of seenAll) spec.folio[rune] = (spec.folio[rune] || 0) + 1; }
        const itemID = consumables.bySpell.get(spellID);
        if (itemID) {
          bump(specID, 'consumables', itemID);
          const source = Number(event.sourceID);
          if (!fromAura.has(source)) fromAura.set(source, new Set());
          fromAura.get(source).add(itemID);
        } else if (consumables.fedSpells.has(spellID)) {
          // Kein Gegenstand, nur die Tatsache. Je Spieler einmal.
          for (const spec of seenAll) {
            if (!spec.fed) { spec.fed = true; spec.fedCount = (spec.fedCount || 0) + 1; }
          }
        } else if (SHOW_AURAS) {
          missedAuras.set(spellID, (missedAuras.get(spellID) || 0) + 1);
        }
      }
    }

    // Die Runen des Folio, je Spieler. Der Buff kann im Kampf hundertmal
    // kommen - gezaehlt wird er einmal, sonst zaehlt man Ausloesungen
    // statt Spielern.
    const folioEvents = (report && report.folio && report.folio.data) || [];
    if (folioEvents.length) {
      const seenRune = new Set();
      for (const ev of folioEvents) {
        const rune = folioAura.get(Number(ev.abilityGameID));
        if (!rune) continue;
        const who = Number(ev.targetID);
        const spec = specBySource.get(who);
        if (!spec) continue;
        const key = who + ':' + rune;
        if (seenRune.has(key)) continue;
        seenRune.add(key);
        for (const mode of active) {
          const entry = entryFor(mode, spec);
          entry.folio[rune] = (entry.folio[rune] || 0) + 1;
        }
      }
    }

    // --- Was gewirkt wurde ------------------------------------------
    //
    // Speisen, Traenke und Heiltraenke stehen NICHT in den Auren beim
    // Pull: gegessen und getrunken wird davor oder mittendrin. Sie
    // stehen in den Wirkungen, und dort mit dem Gegenstand, den man
    // kauft - anders als die Aura, die bei jeder Speise gleich heisst.
    //
    // Gezaehlt wird je Spieler einmal, nicht je Schluck: gefragt ist,
    // wie viele es benutzen, nicht wie oft.
    try {
      const used = await gql(`
        query ($code: String!, $expr: String!) {
          reportData { report(code: $code) {
            events(dataType: Casts, limit: 10000, startTime: 0, endTime: 99999999,
                   filterExpression: $expr) { data }
          } }
        }`, { code, expr: consumables.castFilter });
      const seenPerPlayer = new Map();
      for (const cast of (used.reportData.report.events.data || [])) {
        const specID = specBySource.get(Number(cast.sourceID));
        if (!specID) continue;
        const itemID = consumables.bySpell.get(Number(cast.abilityGameID));
        if (!itemID) continue;
        const key = cast.sourceID + ':' + itemID;
        if (seenPerPlayer.has(key)) continue;
        // Und nicht noch einmal, was schon als Aura gezaehlt wurde.
        const already = fromAura.get(Number(cast.sourceID));
        if (already && already.has(itemID)) continue;
        seenPerPlayer.set(key, true);
        bump(specID, 'consumables', itemID);
      }
    } catch (err) {
      process.stdout.write('?');
    }

    process.stdout.write('.');
    await sleep(250);
  }
  };
  await readReports(codes);

  // --- Nachlese ----------------------------------------------------------
  //
  // Die Ranglistenspitze ist nicht die Spielerschaft: neun Speccs kamen
  // in 400 Berichten kein einziges Mal vor - kein Wiederherstellungs-
  // Druide unter den besten Laeufen heisst nicht, dass keiner spielt.
  // Also wird fuer jede Spec mit zu wenig Spielern gezielt gefragt:
  // dieselbe Rangliste, nach Klasse und Spec gefiltert, und ein paar
  // Berichte daraus nachgelesen. Nur fuer die Luecken - die kosten wenig.
  const MIN_PLAYERS = Number(process.env.MC_MIN_PLAYERS || 15);
  const specNames = await readSpecNames();
  const baseTally = tallyFor(BASE_MODE);
  const thin = [...specNames.keys()].filter((id) => ((baseTally[id] || {}).players || 0) < MIN_PLAYERS);
  if (thin.length) {
    console.log(`\nNachlese fuer ${thin.length} Speccs mit unter ${MIN_PLAYERS} Spielern`);
    const extra = new Map();
    for (const specID of thin) {
      const names = specNames.get(specID);
      const metric = names.healer ? 'hps' : 'dps';
      let found = 0;
      for (const enc of encounters.slice(0, 4)) {
        let data;
        try {
          data = await gql(`
            query ($encounter: Int!, $difficulty: Int!, $metric: CharacterRankingMetricType!, $cls: String!, $spec: String!) {
              worldData { encounter(id: $encounter) {
                characterRankings(difficulty: $difficulty, metric: $metric, page: 1, className: $cls, specName: $spec)
              } }
            }`, { encounter: enc.id, difficulty: DIFFICULTY, metric, cls: names.cls, spec: names.spec });
        } catch (err) {
          console.log(`  ! ${names.cls}/${names.spec}: ${err.message}`);
          break;
        }
        const list = (data.worldData.encounter.characterRankings || {}).rankings || [];
        for (const rank of list.slice(0, 3)) {
          const report = rank.report;
          if (report && report.code && !reports.has(report.code) && !extra.has(report.code)) {
            extra.set(report.code, { fightID: report.fightID, key: Number(rank.bracketData) || 0, dungeon: enc.name, raid: enc.raid || null });
            found += 1;
          }
        }
        await sleep(250);
      }
      process.stdout.write(`  ${names.cls}/${names.spec}: ${found} Berichte\n`);
    }
    if (extra.size) {
      for (const [code, info] of extra) reports.set(code, info);
      await readReports([...extra.entries()]);
    }
  }

  console.log(`\n\nSpieler ausgewertet: ${players}`
    + (unknownSpec ? `, ${unknownSpec} ohne erkennbare Spec` : ''));
  // Und wie viele Folio-Runen dabei herausgekommen sind. Die Zahl stand
  // nirgends, und deshalb fiel monatelang nicht auf, dass sie null war.
  {
    let runen = 0, speccs = 0;
    for (const mode of Object.keys(tallies)) {
      for (const entry of Object.values(tallyFor(mode))) {
        const n = Object.keys(entry.folio || {}).length;
        if (n) { runen += n; speccs += 1; }
      }
    }
    console.log(`Folio-Runen gezaehlt: ${runen} in ${speccs} Speccs`);
  }
  if (missedEnchants.size) {
    console.log(`Nicht zugeordnete Verzauberungen: ${missedEnchants.size}`);
    for (const name of [...missedEnchants].slice(0, 8)) console.log(`  ? ${name}`);
  }
  // Mit MC_AURAS=1: die haeufigsten Auren, die zu keinem kaufbaren
  // Gegenstand fuehren. Die Liste ist voller Klassenbuffs - gesucht
  // wird darin nach dem, was doch eines haette sein muessen.
  if (SHOW_AURAS && missedAuras.size) {
    const top = [...missedAuras.entries()].sort((a, b) => b[1] - a[1]).slice(0, 30);
    console.log(`
Haeufigste nicht zugeordnete Auren (${missedAuras.size} verschiedene):`);
    for (const [id, n] of top) console.log(`  ${String(n).padStart(5)}x  ${id}`);
  }
  if (!players) throw new Error('Keine Ausruestungsdaten gefunden.');

  // --- Zaehlungen in Anteile ------------------------------------------
  //
  // Je Zaehlwerk eine Datei. Bei M+ sind das zwei: alle Keys und die
  // hohen. Beide stammen aus denselben Kaempfen, nur anders gefiltert -
  // deshalb steht der Rechenteil hier einmal und laeuft zweimal.
  const now = new Date();
  const stamp = now.getFullYear() * 10000 + (now.getMonth() + 1) * 100 + now.getDate();
  const dir = path.join(BASE, 'tools', 'data');
  fs.mkdirSync(dir, { recursive: true });

  for (const [mode, tally] of Object.entries(tallies)) {
    const specs = {};
    for (const [specID, entry] of Object.entries(tally)) {
      const out = { enchants: {}, gems: [], consumables: [], gear: {} };
      for (const [slot, counts] of Object.entries(entry.enchants)) {
        const total = Object.values(counts).reduce((a, b) => a + b, 0);
        out.enchants[slot] = Object.entries(counts)
          .map(([id, n]) => ({ id: Number(id), pct: Math.round((n / total) * 100),
            maxKey: entry.maxKey[id] || 0 }))
          .sort((a, b) => b.pct - a.pct);
      }
      // Ausruestung: Anteil an den Spielern DIESER Spec, hoechste zuerst.
      // Fuenf je Platz, damit neben dem Set-Teil auch die Alternativen
      // stehen.
      for (const [slot, items] of Object.entries(entry.gear || {})) {
        const rows = Object.entries(items)
          .map(([id, row]) => ({
            id: Number(id), ilvl: row.ilvl,
            pct: Math.round((row.n / Math.max(1, entry.players)) * 100),
            maxKey: entry.maxKey[id] || 0,
            name: (consumables.names.get(Number(id)) || {}).name || null,
          }))
          .sort((a, b) => b.pct - a.pct)
          .slice(0, 5);
        if (rows.length) out.gear[slot] = rows;
      }

      const conTotal = Object.values(entry.consumables || {}).reduce((a, b) => a + b, 0);
      if (conTotal) {
        out.consumables = Object.entries(entry.consumables)
          .map(([id, n]) => ({ id: Number(id), pct: Math.round((n / Math.max(1, entry.players)) * 100),
            kind: consumables.kindOf.get(Number(id)) || 'other',
            maxKey: entry.maxKey[id] || 0,
            name: (consumables.names.get(Number(id)) || {}).name || null }))
          .sort((a, b) => b.pct - a.pct);
      }
      // Hier stand eine Zeile "so viele haben ueberhaupt gegessen", ohne
      // Gegenstand. Sie war ein Notbehelf, solange ich glaubte, die Logs
      // koennten die Speise nicht nennen. Sie koennen es - nur nicht ueber
      // die Aura, sondern ueber die Wirkung. Der Notbehelf faellt weg.

      // Zielwerte: der Median je Kennwert, und die Rangfolge daraus.
      //
      // Der Median und nicht der Durchschnitt: eine Spec, in der die
      // Haelfte auf Tempo und die Haelfte auf Meisterschaft spielt,
      // haette im Durchschnitt von beidem die Haelfte - einen Wert, den
      // niemand traegt. Der Median nennt wenigstens einen echten.
      if (entry.ratings && entry.ratings.length >= 5) {
        const middle = (key) => {
          const values = entry.ratings.map((r) => r[key]).sort((a, b) => a - b);
          return values[Math.floor(values.length / 2)];
        };
        const values = {};
        for (const key of ['crit', 'haste', 'mastery', 'vers']) {
          values[key] = { rating: middle(key) };
        }
        const total = Object.values(values).reduce((a, b) => a + b.rating, 0) || 1;
        for (const key of Object.keys(values)) {
          values[key].pct = Math.round((values[key].rating / total) * 100);
        }
        out.stats = {
          priority: Object.keys(values).sort((a, b) => values[b].rating - values[a].rating),
          values,
          players: entry.ratings.length,
        };
      }

      // Talente: einzeln mit Anteil, und der haeufigste ganze Build.
      const talentRows = Object.entries(entry.talents || {})
        .map(([key, n]) => {
          const parts = key.split('|');
          return {
            spell: Number(parts[0]), rank: Number(parts[1]),
            pct: Math.round((n / Math.max(1, entry.players)) * 100),
          };
        })
        .filter((row) => row.pct > 0)
        .sort((a, b) => b.pct - a.pct);
      if (talentRows.length) out.talents = talentRows;
      // Nur fuer den Profil-Sammler; das Addon bekommt das nie zu sehen.
      if (entry.names && entry.names.length) out.lookup = entry.names;

      // Je Held-Baum: Anteil der Spieler, Talente, haeufigster Build.
      if (entry.hero && Object.keys(entry.hero).length) {
        out.hero = {};
        for (const [sub, h] of Object.entries(entry.hero)) {
          const denom = Math.max(1, h.players);
          const ho = { players: h.players, pct: Math.round((h.players / Math.max(1, entry.players)) * 100) };
          const rows = Object.entries(h.talents).map(([key, n]) => {
            const parts = key.split('|');
            return { spell: Number(parts[0]), rank: Number(parts[1]), pct: Math.round((n / denom) * 100) };
          }).filter((r) => r.pct > 0).sort((a, b) => b.pct - a.pct);
          if (rows.length) ho.talents = rows;
          const hb = Object.entries(h.builds).sort((a, b) => b[1] - a[1]);
          if (hb.length) {
            ho.build = {
              pct: Math.round((hb[0][1] / denom) * 100),
              nodes: hb[0][0].split(',').map((part) => { const b = part.split(':'); return { spell: Number(b[0]), rank: Number(b[1]) }; }),
            };
          }
          out.hero[sub] = ho;
        }
      }
      // Der Omnium Folio: je Rune der Anteil der Spieler, die sie trugen.
      if (entry.folio && Object.keys(entry.folio).length) {
        out.folio = Object.entries(entry.folio)
          .map(([spell, n]) => ({ spell: Number(spell), pct: Math.round((n / Math.max(1, entry.players)) * 100) }))
          .filter((r) => r.pct > 0)
          .sort((a, b) => b.pct - a.pct);
      }

      const builds = Object.entries(entry.builds || {}).sort((a, b) => b[1] - a[1]);
      if (builds.length) {
        out.build = {
          pct: Math.round((builds[0][1] / Math.max(1, entry.players)) * 100),
          nodes: builds[0][0].split(',').map((part) => {
            const bits = part.split(':');
            return { spell: Number(bits[0]), rank: Number(bits[1]) };
          }),
        };
      }

      const gemTotal = Object.values(entry.gems).reduce((a, b) => a + b, 0);
      if (gemTotal) {
        out.gems = Object.entries(entry.gems)
          .map(([id, n]) => ({ id: Number(id), pct: Math.round((n / gemTotal) * 100),
            maxKey: entry.maxKey[id] || 0 }))
          .sort((a, b) => b.pct - a.pct);
      }
      specs[specID] = out;
    }

    const info = meta[mode] || { mode };
    const file = path.join(dir, `wcl-${mode.replace('/', '--')}.json`);
    const payload = {
      source: 'warcraftlogs.com', mode: info.mode, builtOn: stamp, specs,
    };
    const usedItems = new Set();
    for (const entry of Object.values(specs)) {
      for (const list of Object.values(entry.gear || {})) {
        for (const row of list) usedItems.add(row.id);
      }
    }
    const bonusOut = {};
    for (const id of usedItems) {
      const hit = bonusByItem.get(id);
      if (hit && hit.list.length) bonusOut[id] = hit.list;
    }
    if (Object.keys(bonusOut).length) payload.bonuses = bonusOut;
    if (info.dungeon) payload.dungeon = info.dungeon;
    if (info.raid) payload.raid = info.raid;
    // Die Spanne reist mit den Daten. Sonst behauptet die Oberflaeche
    // irgendwann "hohe Keys" und meint eine Zahl, die niemand kennt.
    if (keyRange) payload.keyRange = keyRange;

    if (DRY) {
      // Ein Probelauf, der nichts zeigt, ist kein Probelauf.
      const [id, one] = Object.entries(specs)[0] || [];
      console.log(`
Probelauf ${mode}, ${Object.keys(specs).length} Speccs, Spec ${id}:`);
      for (const c of (one || {}).consumables || []) {
        console.log(`  ${String(c.pct).padStart(3)}%  ${c.kind.padEnd(7)} ${c.name || '(ohne Gegenstand)'}`);
      }
      const st = (one || {}).stats;
      if (st) {
        console.log('  Zielwerte (Median aus ' + st.players + '): '
          + st.priority.map((k) => k + ' ' + st.values[k].rating).join(', '));
      }
      const picks = (one || {}).talents || [];
      const build = (one || {}).build;
      console.log(`  Talente: ${picks.length} einzeln`
        + (build ? `, haeufigster Build ${build.nodes.length} Knoten bei ${build.pct}%` : ', kein Build'));
      console.log(`  ${file} bleibt unberuehrt.`);
      continue;
    }

    fs.writeFileSync(file, JSON.stringify(payload, null, 1), 'utf8');
    console.log(`geschrieben: ${file}`);
    console.log(`  ${Object.keys(specs).length} Speccs`);
  }

  console.log(`
Spieler insgesamt: ${players}`);
  console.log('Jetzt zusammenbauen: node tools/build-recommendations.js .');
})();

