// Erzeugt Data/Catalog.lua aus den DB2-Tabellen des laufenden Spielstands.
//
//     node tools/build-catalog.js <Pfad zum AddOn-Ordner> [Build]
//
// Quelle ist wago.tools: dieselben Tabellen, die der Client selbst benutzt,
// als CSV und ohne Anmeldung. Damit stehen im Katalog echte Item-IDs des
// aktuellen Patches - kein Abschreiben aus einem Guide, kein Raten.
//
// Ausdruecklich NICHT hier drin: welche Spezialisierung was nehmen soll.
// Der Katalog sagt, was es gibt und was es tut. Was davon gut ist, ist eine
// andere Frage und kommt aus einer anderen Quelle (siehe docs/01).

const fs = require('fs');
const path = require('path');
const https = require('https');

const BASE = process.argv[2];
if (!BASE) {
  console.error('Aufruf: node tools/build-catalog.js <Pfad zum AddOn-Ordner> [Build]');
  process.exit(1);
}

// ----------------------------------------------------------------- Abruf

function get(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'MetaCodex-build-catalog' } }, (res) => {
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

// Ein CSV-Leser statt einer Abhaengigkeit: die Dateien sind gut erzogen,
// gebraucht wird nur Anfuehrungszeichen und verdoppeltes Anfuehrungszeichen.
function parseCSV(text) {
  const rows = [];
  let row = [], cur = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"') {
        if (text[i + 1] === '"') { cur += '"'; i++; } else quoted = false;
      } else cur += c;
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

// ------------------------------------------------------------- Kennwerte

// ITEM_MOD_*, so wie SpellItemEnchantment.EffectArg sie fuehrt. Nur die,
// die auf einem Einkaufszettel vorkommen koennen.
const MOD = {
  3: 'agi', 4: 'str', 5: 'int', 7: 'sta',
  32: 'crit', 36: 'haste', 40: 'vers', 49: 'mastery',
  61: 'speed', 62: 'leech', 63: 'avoid',
  71: 'primary', 72: 'primary', 73: 'primary', 74: 'primary',
};

const EFFECT_STAT = '5';   // ITEM_ENCHANTMENT_TYPE_STAT
const EFFECT_SPELL = '3';  // ITEM_ENCHANTMENT_TYPE_EQUIP_SPELL

// Die Handwerksstufe steckt im Namen als Symbol-Markup. Sie gehoert nicht
// in den Katalog, aber sie sagt, welche Zeile die staerkste ist.
const stripTier = (s) => s.replace(/\s*\|A:[^|]*\|a/g, '').trim();
const tierOf = (s) => { const m = s.match(/Tier(\d)/); return m ? Number(m[1]) : 0; };

function describe(ench) {
  if (!ench) return { stat: 'unknown', power: 0 };
  for (let i = 0; i < 3; i++) {
    if (ench['Effect_' + i] === EFFECT_STAT) {
      const stat = MOD[ench['EffectArg_' + i]];
      if (stat && stat !== 'sta') {
        return { stat, power: Number(ench['EffectScalingPoints_' + i]) || 0 };
      }
    }
  }
  for (let i = 0; i < 3; i++) {
    if (ench['Effect_' + i] === EFFECT_SPELL) return { stat: 'proc', power: 0 };
  }
  return { stat: 'unknown', power: 0 };
}

// --------------------------------------------------------------- Ausgabe

function luaString(s) {
  return '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
}

function emitEnchants(groups) {
  const lines = [];
  for (const slot of Object.keys(groups)) {
    const list = groups[slot];
    if (!list.length) continue;
    lines.push(`    ${slot} = {`);
    for (const e of list) {
      const alt = e.alt ? `, alt = ${e.alt}` : '';
      const power = e.power ? `, power = ${e.power.toFixed(3)}` : '';
      lines.push(`      { id = ${e.id}${alt}, stat = ${luaString(e.stat)}${power}, name = ${luaString(e.name)} },`);
    }
    lines.push('    },');
  }
  return lines.join('\n');
}

// ------------------------------------------------------------------ Lauf

(async () => {
  let build = process.argv[3];
  if (!build) {
    const builds = JSON.parse(await get('https://wago.tools/api/builds'));
    build = builds.wow[0].version;
  }
  console.log('Build:', build);

  const db2 = async (table, filter, extra) => {
    let url = `https://wago.tools/db2/${table}/csv?build=${build}`;
    if (filter) {
      for (const [k, v] of Object.entries(filter)) {
        url += `&filter%5B${encodeURIComponent(k)}%5D=${encodeURIComponent(v)}`;
      }
    }
    if (extra) url += '&' + extra;
    return parseCSV(await get(url));
  };

  // Die aktuelle Erweiterung ist die hoechste, die in ItemSparse vorkommt.
  // Fest verdrahtet waere sie beim naechsten Addon falsch.
  const probe = await db2('ItemSparse', { Display_lang: 'Enchant Ring' });
  const expansion = Math.max(...probe.map((r) => Number(r.ExpansionID) || 0));
  console.log('Erweiterung:', expansion);

  const [items, gemProps, sieRows, itemEffects, itemLinks, spellEffects, itemClasses,
    chrSpecs, chrClasses, journalItems, journalEncounters, journalInstances, itemSets,
    craftQualities, craftingData, levelDeltas,
    trackRows, statBonusRows, effectBonusRows, traitDefs, pvpTalents, spellNames,
    traitNodes, traitNodeXEntry, traitEntries, traitLoadouts, subTreesEN, subTreesDE]
    = await Promise.all([
      db2('ItemSparse', { ExpansionID: String(expansion) }),
      db2('GemProperties'),
      db2('SpellItemEnchantment'),
      db2('ItemEffect'),
      db2('ItemXItemEffect'),
      db2('SpellEffect'),
      db2('Item'),
      db2('ChrSpecialization'),
      db2('ChrClasses'),
      db2('JournalEncounterItem'),
      db2('JournalEncounter'),
      db2('JournalInstance'),
      db2('ItemSet'),
      // Was Berufe herstellen. NICHT ueber den Gegenstand selbst:
      // ItemSparse fuehrt fuer ein Handwerksstueck weder eine
      // Qualitaetsstufe noch einen Beruf - beides kommt erst beim
      // Herstellen ueber Bonus-IDs dazu. Wer am Gegenstand fragt,
      // bekommt 1188 Treffer, von denen KEIN EINZIGER in den
      // Ausruestungsdaten vorkommt; genau so stand der Abschnitt
      // "Handwerk" leer da, obwohl die Besten Handwerk tragen.
      db2('CraftingDataItemQuality'),
      db2('CraftingData'),
      db2('ItemBonusListLevelDelta'),
      // Typ 34 ist der Aufwertungspfad: Value_0 der Pfad, Value_1 sein
      // Name als SharedString. Die Liste, an der die Zeile haengt, ist
      // die Bonus-ID, die man an einen Link haengt.
      db2('ItemBonus', { Type: '34' }),
      // Typ 25 ist die Wertevergabe: je Zeile ein Wert, Value_0 seine
      // Nummer. Ein Handwerksstueck traegt seine Zweitwerte NUR so -
      // am Gegenstand selbst stehen "Zufallswert 1" und "Zufallswert 2".
      db2('ItemBonus', { Type: '25' }),
      // Typ 23 haengt eine Wirkung an: Value_0 ist die ItemEffect-ID.
      // Darunter sind die Verzierungen, aber nicht nur sie.
      db2('ItemBonus', { Type: '23' }),
      // Fuer die Namenskarte der Talente: murlok nennt Talente beim
      // englischen Namen, das Addon braucht die Zauber-ID. SpellName ist
      // gross, aber einmal am Tag ist das egal.
      db2('TraitDefinition'),
      db2('PvpTalent'),
      db2('SpellName'),
      // Die Talentbaeume selbst: fuer den Decoder der Importstrings und
      // fuer die Held-Baeume. Einmal englisch, einmal deutsch - der
      // Client kann einen fremden Held-Baum nicht benennen.
      db2('TraitNode'),
      db2('TraitNodeXTraitNodeEntry'),
      db2('TraitNodeEntry'),
      db2('TraitTreeLoadout'),
      db2('TraitSubTree'),
      db2('TraitSubTree', null, 'locale=deDE'),
    ]);
  console.log('Gegenstaende:', items.length);

  // --- Vom Gegenstand zur Verzauberung -------------------------------
  //
  // Der Weg ueber den Namen ("Enchant Ring - ...") deckt nur Rollen ab.
  // Beinverstaerkungen heissen "Sunfire Silk Spellthread" und fallen
  // durch - genau deshalb fehlte die Beinverzauberung in den Raiddaten.
  //
  // Dieser Weg geht ueber die Wirkung statt ueber den Namen: Gegenstand ->
  // ItemEffect -> Zauber -> SpellEffect mit Effekt 53 (ENCHANT_ITEM) ->
  // die Verzauberung. Der haengt an keiner Benennung und deckt alles ab,
  // was ueberhaupt verzaubert.
  // 53 ist die dauerhafte Verzauberung, 54 die zeitweilige.
  //
  // 54 fehlte, und damit fehlten die Waffenoele: Warcraft Logs meldet sie
  // als `temporaryEnchant` am Ausruestungsteil, und ihre IDs standen in
  // keiner Karte. Auf Archon steht genau dort "Weapon Buff".
  const ENCHANT_ITEM = '53';
  const ENCHANT_TEMPORARY = '54';
  const enchantBySpell = new Map();
  for (const row of spellEffects) {
    if (row.Effect !== ENCHANT_ITEM && row.Effect !== ENCHANT_TEMPORARY) continue;
    const enchID = Number(row.EffectMiscValue_0);
    if (enchID) enchantBySpell.set(Number(row.SpellID), enchID);
  }
  const spellByEffect = new Map(itemEffects.map((r) => [r.ID, Number(r.SpellID)]));
  const enchantsByItem = new Map();
  for (const link of itemLinks) {
    const spellID = spellByEffect.get(link.ItemEffectID);
    const enchID = spellID && enchantBySpell.get(spellID);
    if (!enchID) continue;
    const itemID = Number(link.ItemID);
    const list = enchantsByItem.get(itemID) || [];
    list.push(enchID);
    enchantsByItem.set(itemID, list);
  }
  console.log('Gegenstaende mit Verzauberungswirkung:', enchantsByItem.size);

  // Verzauberungen nach Namen, immer die staerkste Handwerksstufe.
  const enchByName = new Map();
  // Und daneben ALLE Stufen je Name.
  //
  // Die Logs melden eine Verzauberung als ID, und zwar die der Stufe, die
  // der Spieler wirklich drauf hat. Nur die staerkste zu kennen hiesse,
  // jeden zweiten Datensatz zu verlieren.
  const tiersByName = new Map();
  for (const e of sieRows) {
    const name = stripTier(e.Name_lang);
    const tier = tierOf(e.Name_lang);
    const old = enchByName.get(name);
    if (!old || old.__tier < tier) { e.__tier = tier; enchByName.set(name, e); }

    const list = tiersByName.get(name) || [];
    list.push(Number(e.ID));
    tiersByName.set(name, list);
  }

  // --- Verzauberungsrollen -------------------------------------------
  //
  // Der Gegenstandsname traegt den Slot: "Enchant Ring - Thalassian Haste".
  // Von jedem Namen gibt es zwei Gegenstandsstufen; die hoehere ist die
  // gekaufte, die niedrigere bleibt als guenstige Alternative stehen.
  const SLOT = {
    Weapon: 'weapon', Ring: 'ring', Chest: 'chest', Boots: 'boots',
    Helm: 'helm', Shoulders: 'shoulders', Tool: 'tool',
  };
  const byKey = new Map();
  for (const it of items) {
    const m = it.Display_lang.match(/^Enchant ([^-]+) - (.+)$/);
    if (!m) continue;
    const slot = SLOT[m[1].trim()];
    if (!slot) continue;
    const key = slot + '|' + m[2].trim();
    const entry = byKey.get(key) || { slot, name: m[2].trim(), full: it.Display_lang, ranks: [] };
    entry.ranks.push({ id: Number(it.ID), ilvl: Number(it.ItemLevel) });
    byKey.set(key, entry);
  }

  // Die Runenschmiede des Todesritters.
  //
  // Sie sind Verzauberungen wie jede andere - nur kauft man sie nicht,
  // man schmiedet sie an die Waffe. Es gibt also keinen Gegenstand, und
  // genau deshalb fielen sie bisher aus jeder Karte heraus: der Blut-DK
  // bekam unter "Waffe" die Frage, welche Verzauberung er wolle, und
  // keine Antwort, die er haette geben koennen.
  //
  // Gespeichert wird die Zauber-ID, nicht der Name: den Namen holt der
  // Client, und damit steht er auf jedem Client in seiner Sprache.
  const runeforges = {};
  for (const e of sieRows) {
    if (!/^Rune of /.test(String(e.Name_lang || ''))) continue;
    const spell = Number(e.EffectArg_0) || 0;
    if (spell > 0) runeforges[Number(e.ID)] = spell;
  }
  console.log('Runenschmiede:', Object.keys(runeforges).length);

  // Verzauberungs-ID -> kaufbare Rolle. Nicht fuer das Addon, sondern
  // fuer die Sammler: die Logs melden IDs, gekauft wird ein Gegenstand.
  const enchantMap = {};
  const enchants = {};
  for (const entry of byKey.values()) {
    entry.ranks.sort((a, b) => b.ilvl - a.ilvl);
    // Nachgeschlagen wird mit dem NAMEN DER VERZAUBERUNG, nicht mit dem
    // des Gegenstands: die Tabelle ist nach "Rite of the Hash'ey"
    // geschluesselt, der Gegenstand heisst "Enchant Weapon - Rite of the
    // Hash'ey". Mit dem langen Namen traf der Griff nie, und die Stufen
    // kamen nur ueber den zweiten Weg herein - wo der schweigt, fehlten
    // sie ganz.
    const { stat, power } = describe(enchByName.get(entry.name) || enchByName.get(entry.full));
    for (const enchID of tiersByName.get(entry.name) || tiersByName.get(entry.full) || []) {
      enchantMap[enchID] = entry.ranks[0].id;
    }
    // Zweiter Weg als Ergaenzung: was der Name nicht hergibt, gibt
    // die Wirkung her.
    for (const rank of entry.ranks) {
      for (const enchID of enchantsByItem.get(rank.id) || []) {
        enchantMap[enchID] = entry.ranks[0].id;
      }
    }
    (enchants[entry.slot] ||= []).push({
      id: entry.ranks[0].id,
      alt: entry.ranks[1] ? entry.ranks[1].id : null,
      stat, power, name: entry.name,
    });
  }
  // Innerhalb eines Slots die staerkste Zeile je Kennwert zuerst: die
  // Oberflaeche kann dann "stark" und "guenstig" ohne eigene Logik trennen.
  for (const list of Object.values(enchants)) {
    list.sort((a, b) => a.stat.localeCompare(b.stat) || b.power - a.power);
  }

  // --- Beinverstaerkung ----------------------------------------------
  //
  // Kein "Enchant"-Name, deshalb eigener Griff. Welcher Ruestungsklasse
  // was gehoert, sagt der Katalog NICHT - das weiss der Client besser,
  // und geraten waere es falsch (siehe docs/01, offene Punkte).
  const legs = new Map();
  for (const it of items) {
    if (!/Spellthread|Armor Kit/.test(it.Display_lang)) continue;
    if (/^(Pattern|Formula|Plans|Recipe):/.test(it.Display_lang)) continue;
    const entry = legs.get(it.Display_lang) || { name: it.Display_lang, ranks: [] };
    entry.ranks.push({ id: Number(it.ID), ilvl: Number(it.ItemLevel), q: Number(it.OverallQualityID) });
    legs.set(it.Display_lang, entry);
  }
  enchants.legs = [...legs.values()].map((e) => {
    e.ranks.sort((a, b) => b.ilvl - a.ilvl);
    // Auch die Beinverstaerkung gehoert in die Karte. Ihre
    // Verzauberungs-IDs kommen ueber die Wirkung, nicht ueber den
    // Namen - sie heisst ja nicht "Enchant Legs - ...".
    for (const rank of e.ranks) {
      for (const enchID of enchantsByItem.get(rank.id) || []) {
        enchantMap[enchID] = e.ranks[0].id;
      }
    }
    return { id: e.ranks[0].id, alt: e.ranks[1] ? e.ranks[1].id : null, stat: 'legs', power: 0, name: e.name };
  }).sort((a, b) => a.name.localeCompare(b.name));

  // --- Sockelsteine ---------------------------------------------------
  //
  // Der Stein selbst traegt keine Werte; sie haengen an der Verzauberung,
  // auf die GemProperties zeigt. Zwei Werte heisst Haupt- und Nebenwert,
  // ein Wert heisst reiner Stein.
  const gpById = new Map(gemProps.map((r) => [r.ID, r]));
  const sieById = new Map(sieRows.map((r) => [r.ID, r]));
  const gems = [];
  for (const it of items) {
    if (!it.Gem_properties || it.Gem_properties === '0') continue;
    const gp = gpById.get(it.Gem_properties);
    if (!gp) continue;
    const ench = sieById.get(gp.Enchant_ID);
    if (!ench) continue;
    const stats = [];
    for (let i = 0; i < 3; i++) {
      if (ench['Effect_' + i] === EFFECT_STAT) {
        const s = MOD[ench['EffectArg_' + i]];
        if (s) stats.push({ stat: s, scale: Number(ench['EffectScalingPoints_' + i]) || 0 });
      }
    }
    if (!stats.length) continue;
    // Nach Groesse sortieren, nicht nach Reihenfolge in der Tabelle.
    //
    // Heute steht der groessere Wert zufaellig vorn - und der ist, anders
    // als der Name vermuten laesst, der der FARBE (Peridot = Tempo), nicht
    // der des Praefix. Wer sich auf die Reihenfolge verliesse, bekaeme beim
    // naechsten Patch stillschweigend vertauschte Steine.
    stats.sort((a, b) => b.scale - a.scale);
    gems.push({
      id: Number(it.ID),
      major: stats[0].stat,
      minor: (stats[1] || stats[0]).stat,
      q: Number(it.OverallQualityID),
      ilvl: Number(it.ItemLevel),
      name: it.Display_lang,
    });
  }
  gems.sort((a, b) => a.major.localeCompare(b.major) || a.minor.localeCompare(b.minor)
    || b.q - a.q || b.ilvl - a.ilvl);

  // --- Speccs -----------------------------------------------------------
  //
  // Die ENGLISCHEN Namen, kleingeschrieben und mit Bindestrichen. Sie
  // sind der Schluessel zu jeder Guide-Seite da draussen - Wowhead und
  // Method bauen ihre Adressen genauso.
  //
  // Warum sie hier stehen und nicht zur Laufzeit gebaut werden: der
  // Client nennt die Spec in SEINER Sprache. "Gleichgewicht/balance"
  // ergaebe auf einem deutschen Client eine Adresse, die es nicht gibt.
  const SLUG = (text) => String(text).toLowerCase()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  const classByID = new Map(chrClasses.map((c) => [String(c.ID), c.Name_lang]));
  const specs = [];
  for (const spec of chrSpecs) {
    const cls = classByID.get(String(spec.ClassID));
    // OrderIndex ueber 3 ist die Anfaengerspec - die fuehrt niemand.
    if (!cls || !spec.Name_lang || Number(spec.OrderIndex) > 3) continue;
    // Das Hauptattribut steht in PrimaryStatPriority.
    //
    // Die Zahl ist keine Stat-ID, sondern der Index einer Rangfolge der
    // drei Attribute: 0 und 1 fuehren mit Intelligenz, 2 und 3 mit
    // Beweglichkeit, 4 und 5 mit Staerke. Gegengerechnet an allen
    // vierzig Speccs - neunzehn Intelligenz, dreizehn Beweglichkeit,
    // acht Staerke, und jede einzelne stimmt.
    //
    // Gebraucht wird das, weil der Client es seit 12.1 nicht mehr
    // herausgibt: GetSpecializationInfoByID liefert die Stelle leer, und
    // im Fenster stand "Hauptattribut" statt "Intelligenz".
    const PRIMARY = ['int', 'int', 'agi', 'agi', 'str', 'str'];
    specs.push({
      id: Number(spec.ID),
      slug: `${SLUG(cls)}/${SLUG(spec.Name_lang)}`,
      cls: SLUG(cls),
      spec: SLUG(spec.Name_lang),
      stat: PRIMARY[Number(spec.PrimaryStatPriority)] || null,
    });
  }
  specs.sort((a, b) => a.id - b.id);
  console.log('Speccs:', specs.length);

  // --- Gegenstandsstufe verschieben -------------------------------------
  //
  // Die eine Tabelle, mit der sich ein Gegenstand auf einer ANDEREN
  // Stufe zeigen laesst. Eine Bonus-ID je Stufendifferenz; haengt man
  // sie an den Gegenstandslink, rechnet der Client Stufe und Werte
  // selbst aus - genau wie bei KeystoneLoot.
  //
  // Die Grundstufe muss NICHT mitgespeichert werden: die kennt der
  // Client ohnehin, und genau sie stand bisher im Tooltip ("Stufe 28").
  // Gebraucht wird nur der Weg von dort zum Ziel.
  const levelDelta = {};
  for (const row of levelDeltas) {
    const delta = Number(row.ItemLevelDelta);
    const id = Number(row.ID);
    if (!id || !Number.isFinite(delta)) continue;
    // Mehrere Listen koennen dieselbe Differenz tragen; die kleinste
    // ID ist die aelteste und stabilste.
    if (!levelDelta[delta] || id < levelDelta[delta]) levelDelta[delta] = id;
  }
  console.log('Stufendifferenzen:', Object.keys(levelDelta).length);

  // --- Aufwertungspfade ----------------------------------------------
  //
  // Je Pfad die Bonus-IDs in Rangfolge. Die Stufe je Rang steht hier
  // NICHT: die rechnet der Client, und er rechnet sie fuer jede Saison
  // richtig. Hier steht nur, welche IDs es gibt und wie sie heissen.
  //
  // ALLE Pfade, nicht nur der hoechste je Name. Der erste Versuch nahm
  // den hoechsten und bekam die NAECHSTE Saison - sie liegt in den
  // Spieldaten schon bereit. Welche Saison laeuft, weiss nur der Client:
  // es ist die, deren Stufen die Schluesselbelohnungen treffen. Also
  // entscheidet er, siehe Compat.SeasonTracks.
  const byPath = new Map();
  for (const row of trackRows) {
    const path = Number(row.Value_0), name = Number(row.Value_1);
    const list = Number(row.ParentItemBonusListID);
    if (!path || !name || !list) continue;
    if (!byPath.has(path)) byPath.set(path, { path, name, lists: [] });
    byPath.get(path).lists.push(list);
  }
  const tracks = [...byPath.values()].sort((a, b) => a.path - b.path);
  for (const t of tracks) t.lists.sort((a, b) => a - b);
  console.log('Aufwertungspfade:', tracks.length, 'Pfade,',
    new Set(tracks.map((t) => t.name)).size, 'Namen');

  // --- Die Talentbaeume, fuer den Decoder --------------------------------
  //
  // Je Baum die Knoten in aufsteigender ID - so laeuft Blizzards Export
  // durch den Baum -, je Knoten seine Eintraege in ihrer Reihenfolge, je
  // Eintrag Rangzahl, Held-Baum und Zauber. Dazu, welcher Baum zu welcher
  // Spec gehoert. Geprueft gegen 60 raider.io-Profile: jeder Knoten stimmt.
  const defSpell = new Map();
  for (const row of traitDefs) {
    const id = Number(row.SpellID) || Number(row.VisibleSpellID) || 0;
    if (id) defSpell.set(Number(row.ID), id);
  }
  const entryInfo = new Map();
  for (const row of traitEntries) {
    entryInfo.set(Number(row.ID), {
      id: Number(row.ID), maxRanks: Number(row.MaxRanks) || 1,
      subTree: Number(row.TraitSubTreeID) || 0, spell: defSpell.get(Number(row.TraitDefinitionID)) || 0,
    });
  }
  const entriesOfNode = new Map();
  for (const row of traitNodeXEntry) {
    const list = entriesOfNode.get(Number(row.TraitNodeID)) || [];
    list.push({ index: Number(row._Index) || 0, entry: Number(row.TraitNodeEntryID) });
    entriesOfNode.set(Number(row.TraitNodeID), list);
  }
  const treesOut = {};
  for (const row of traitNodes) {
    const treeID = Number(row.TraitTreeID);
    if (!treeID) continue;
    const tree = treesOut[treeID] || (treesOut[treeID] = { nodes: [] });
    const entries = (entriesOfNode.get(Number(row.ID)) || []).sort((a, b) => a.index - b.index)
      .map((e) => entryInfo.get(e.entry)).filter(Boolean)
      .map((e) => ({ id: e.id, maxRanks: e.maxRanks, subTree: e.subTree, spell: e.spell }));
    tree.nodes.push({ id: Number(row.ID), type: Number(row.Type) || 0, subTree: Number(row.TraitSubTreeID) || 0, entries });
  }
  for (const tree of Object.values(treesOut)) tree.nodes.sort((a, b) => a.id - b.id);
  const treeBySpec = {};
  for (const row of traitLoadouts) {
    const spec = Number(row.ChrSpecializationID), tree = Number(row.TraitTreeID);
    if (spec && tree && treesOut[tree]) treeBySpec[spec] = tree;
  }
  const subTrees = {};
  const deName = new Map(subTreesDE.map((r) => [Number(r.ID), r.Name_lang]));
  for (const row of subTreesEN) {
    const id = Number(row.ID);
    if (!id || /DNT/.test(row.Name_lang || '')) continue;
    subTrees[id] = { en: row.Name_lang, de: deName.get(id) || row.Name_lang, tree: Number(row.TraitTreeID) || 0 };
  }
  // Nur Baeume, die eine Spec spielt - die Tabelle kennt auch Testbaeume.
  const used = new Set(Object.values(treeBySpec));
  for (const id of Object.keys(treesOut)) if (!used.has(Number(id))) delete treesOut[id];



  // --- Set-Teil oder Handwerksstueck ------------------------------------
  //
  // Das ist eine Eigenschaft des GEGENSTANDS, nicht der Beobachtung -
  // genau wie der Fundort. Deshalb steht es hier und nicht beim
  // Sammler: eine Auskunft aus zwei Quellen waere eine zuviel, und
  // beim naechsten Mal widersprechen sie einander.
  //
  // Strukturell, nicht ueber Namen: ItemSet fuehrt seine Mitglieder in
  // ItemID_0..N, und ein Handwerksstueck traegt eine CraftingQualityID.
  // Die IDs dieser Erweiterung. Beide folgenden Bloecke fragen danach:
  // was nicht mehr aktuell ist, gehoert in keinen von beiden.
  const current = new Set(items.map((r) => Number(r.ID)));

  const kinds = new Map();
  for (const row of itemClasses) {
    const id = Number(row.ID);
    if (current.has(id) && Number(row.CraftingQualityID) > 0) kinds.set(id, 'craft');
  }
  // Ein Beruf als Voraussetzung ist auch Handwerk - die PvP-Stuecke
  // tragen keine Qualitaetsstufe, aber einen RequiredSkill.
  for (const row of items) {
    const id = Number(row.ID);
    if (!kinds.has(id) && Number(row.RequiredSkill) > 0) kinds.set(id, 'craft');
  }
  // Und das, was die Berufe dieser Erweiterung wirklich herstellen.
  //
  // Die beiden Regeln darueber fragen den GEGENSTAND, und moderne
  // Handwerksruestung sagt am Gegenstand nichts: die Qualitaet haengt
  // an Bonus-IDs, die erst beim Herstellen dazukommen. Gefragt werden
  // muss das Rezept, und das steht in CraftingData.
  let fromRecipes = 0;
  const craftedIDs = new Set();
  for (const row of craftQualities) {
    const id = Number(row.ItemID);
    if (id) craftedIDs.add(id);
  }
  for (const row of craftingData) {
    const id = Number(row.CraftedItemID);
    if (id) craftedIDs.add(id);
  }
  for (const id of craftedIDs) {
    if (current.has(id) && !kinds.has(id)) { kinds.set(id, 'craft'); fromRecipes += 1; }
  }
  console.log('Handwerk aus Rezepten:', fromRecipes, 'von', craftedIDs.size);

  // --- Welche Bonus-ID setzt welche Werte? -------------------------------
  //
  // Ein Handwerksstueck bekommt seine Zweitwerte beim Herstellen, ueber
  // eine Bonus-ID. Am Gegenstand steht "Zufallswert 1" und "Zufallswert
  // 2" - und genau das zeigte unser Tooltip, mit Stufe und allem, aber
  // ohne einen Wert, den man in eine Rangfolge bringen koennte.
  //
  // Typ 25 fuehrt je Zeile einen Wert. Zwei Zeilen an derselben Liste
  // sind die beiden Zweitwerte: 8790 ist Krit und Tempo, 8791 Krit und
  // Meisterschaft, und so weiter.
  const STAT_BY_ID = { [32]: 'crit', [36]: 'haste', [40]: 'vers', [49]: 'mastery' };
  const statBonus = new Map();
  for (const row of statBonusRows) {
    const key = STAT_BY_ID[Number(row.Value_0)];
    if (!key) continue;
    const list = Number(row.ParentItemBonusListID);
    if (!list) continue;
    const have = statBonus.get(list) || [];
    if (!have.includes(key)) have.push(key);
    statBonus.set(list, have);
  }
  // Nur die Paare. Eine Liste mit einem einzigen Wert waere keine Wahl
  // zwischen Werten, sondern etwas anderes - und wir wuessten nicht was.
  for (const [list, keys] of statBonus) if (keys.length !== 2) statBonus.delete(list);
  console.log('Werte-Bonuslisten:', statBonus.size);

  // --- Und welche haengt eine Verzierung an? -----------------------------
  //
  // Typ 23 haengt eine Wirkung an den Gegenstand, und darunter ist
  // allerlei: Gift, "Masterful", Proc-Effekte aus Dungeons. Die
  // Verzierungen erkennt man daran, dass es ihre Wirkung auch als
  // GEGENSTAND gibt - als das Reagenz, das der Handwerker einsetzt.
  // "Arcanoweave Lining" ist ein Zauber und ein Gegenstand;
  // "Venomcursed Haste" ist nur ein Zauber.
  //
  // Gespeichert wird die Gegenstands-ID, nicht der Name: der Client
  // kennt sie in seiner Sprache, und ein Symbol hat er auch.
  const effectSpell = new Map(itemEffects.map((r) => [r.ID, Number(r.SpellID)]));
  const spellNameOf = new Map(spellNames.map((r) => [Number(r.ID), r.Name_lang]));
  const itemByName = new Map();
  for (const row of items) {
    const name = row.Display_lang;
    if (name && !itemByName.has(name)) itemByName.set(name, Number(row.ID));
  }
  const embellish = new Map();
  for (const row of effectBonusRows) {
    const spell = effectSpell.get(row.Value_0);
    const name = spell && spellNameOf.get(spell);
    const reagent = name && itemByName.get(name);
    if (!reagent) continue;
    embellish.set(Number(row.ParentItemBonusListID), reagent);
  }
  console.log('Verzierungen:', embellish.size);

  // Fuer den Sammler: er liest die Bonus-IDs der Spieler und braucht
  // beide Karten. Fuer das Addon stehen sie weiter unten im Katalog.
  fs.writeFileSync(path.join(BASE, 'tools', 'data', 'bonus-map.json'), JSON.stringify({
    stats: Object.fromEntries([...statBonus].map(([k, v]) => [k, v])),
    embellish: Object.fromEntries([...embellish]),
  }, null, 1), 'utf8');
  // Das Set gewinnt: ein Tier-Teil bleibt ein Tier-Teil, auch wenn es
  // nebenbei eine Handwerksstufe traegt.
  for (const row of itemSets) {
    for (const [column, value] of Object.entries(row)) {
      if (!column.startsWith('ItemID_')) continue;
      const id = Number(value);
      if (id && current.has(id)) kinds.set(id, 'set');
    }
  }
  console.log('Set-/Handwerksteile:',
    [...kinds.values()].filter((k) => k === 'set').length, 'Set,',
    [...kinds.values()].filter((k) => k === 'craft').length, 'Handwerk');

  // --- Woher ein Gegenstand kommt ---------------------------------------
  //
  // Das Abenteuerjournal fuehrt je Gegenstand die Begegnung, und die
  // Begegnung ihre Instanz. Beides sind IDs, und beide loest der Client
  // auf - EJ_GetEncounterInfo und EJ_GetInstanceInfo. Also stehen hier
  // nur Zahlen, und im Fenster steht dann "Sszorak, Die Giftige Tiefe"
  // auf deutsch und "Sszorak, The Venomous Abyss" auf englisch.
  //
  // Nur Gegenstaende dieser Erweiterung: die Tabelle fuehrt 23977 Zeilen
  // bis zurueck zu den Todesminen, und die will niemand mitladen.
  const encByID = new Map(journalEncounters.map((r) => [Number(r.ID), r]));
  const drops = new Map();
  for (const row of journalItems) {
    const itemID = Number(row.ItemID);
    if (!current.has(itemID) || drops.has(itemID)) continue;
    const enc = encByID.get(Number(row.JournalEncounterID));
    if (!enc) continue;
    drops.set(itemID, {
      enc: Number(enc.ID),
      inst: Number(enc.JournalInstanceID) || 0,
    });
  }
  console.log('Gegenstaende mit Fundort:', drops.size);

  // Das GANZE Journal, fuer den Zusammenbau. Der Katalog fuehrt nur die
  // laufende Erweiterung - aber drei der acht Saisondungeons sind alt,
  // und ihre Beute stand mit "gesehen in Mythisch+" da, obwohl das
  // Journal den Boss kennt. Der Zusammenbau nimmt daraus, was die
  // Empfehlungen wirklich nennen; alles waere zu gross.
  const journalAll = {};
  for (const row of journalItems) {
    const itemID = Number(row.ItemID);
    if (journalAll[itemID]) continue;
    const enc = encByID.get(Number(row.JournalEncounterID));
    if (!enc) continue;
    journalAll[itemID] = { enc: Number(enc.ID), inst: Number(enc.JournalInstanceID) || 0 };
  }

  // PvP-Ware am Namen. Die Spieldaten fuehren keinen Haendler, aber
  // Blizzard benennt die Stufen seit Jahren gleich: "Gladiator's" ist
  // Eroberung, "Combatant's"/"Aspirant's" ist Ehre, "Competitor's"
  // ist das Handwerksstueck dazu. Gepruft wird der ENGLISCHE Name hier,
  // nicht im Client - dort hiesse es "Gladiator" nur auf einem Client.
  const origins = new Map();
  for (const row of items) {
    const id = Number(row.ID), name = row.Display_lang || '';
    if (name.includes("Gladiator's")) origins.set(id, 'conquest');
    else if (name.includes("Combatant's") || name.includes("Aspirant's")) origins.set(id, 'honor');
    else if (name.includes("Competitor's")) origins.set(id, 'pvpcraft');
  }
  console.log('PvP-Herkunft am Namen:', origins.size);

  // --- Verbrauchsgueter ------------------------------------------------
  //
  // Die Einteilung kommt aus der Item-Tabelle, nicht aus dem Namen:
  // Klasse 0 ist "Verbrauchsgut", die Unterklasse sagt welches.
  //
  // Warum Speisen ueberhaupt in den Katalog muessen, Flaeschchen aber
  // nicht: die Logs melden ein Flaeschchen als seinen eigenen Zauber,
  // und daraus faellt die Gegenstands-ID heraus. Speisen melden sich
  // alle unter DEMSELBEN Buff ("Hearty Well Fed"), der an keinem
  // Gegenstand haengt - kein Weg durch die Spieldaten fuehrt von ihm
  // zurueck. Aus den Logs ist also nur zu erfahren, DASS jemand
  // gegessen hat. Was kaufbar ist, muss von hier kommen.
  // 8 ist die Sammelklasse: Waffenoele, Runen, Schleifsteine.
  const SUBCLASS = { 1: 'potion', 3: 'flask', 5: 'food', 8: 'other', 9: 'vantus' };
  const classOf = new Map();
  for (const row of itemClasses) {
    if (Number(row.ClassID) !== 0) continue;
    const kind = SUBCLASS[Number(row.SubclassID)];
    if (kind) classOf.set(Number(row.ID), kind);
  }
  // Gegenstand je Wirkungszeile - gebraucht, um die Heilwirkung
  // zurueck auf den Trank zu fuehren.
  const itemByEffectID = new Map();
  for (const link of itemLinks) {
    itemByEffectID.set(link.ItemEffectID, Number(link.ItemID));
  }
  const consumables = { potion: [], flask: [], food: [], other: [], vantus: [] };
  for (const it of items) {
    const kind = classOf.get(Number(it.ID));
    if (!kind) continue;
    const name = it.Display_lang;
    // Baupläne und Rezepte sind keine Verbrauchsgueter, sie stehen nur
    // in derselben Klasse.
    if (/^(Recipe|Technique|Plans|Formula|Pattern|Schematic|Design):/i.test(name)) continue;
    consumables[kind].push({
      id: Number(it.ID), name,
      ilvl: Number(it.ItemLevel) || 0,
      q: Number(it.OverallQualityID) || 0,
      // "Hearty" ist der hoehere Rang - die Aura heisst genauso.
      rank: /^Hearty /i.test(name) ? 2 : 1,
    });
  }
  // Heiltrank oder Kampftrank?
  //
  // Die Unterklasse kennt den Unterschied nicht, beide heissen "Trank".
  // Die Wirkung trennt sie: Effekt 10 ist SPELL_EFFECT_HEAL. Ueber die
  // Wirkung und nicht ueber den Namen, denn "Refreshing Serum" heisst
  // nicht Heiltrank und ist einer.
  const HEAL_EFFECT = '10';
  const healSpells = new Set();
  for (const row of spellEffects) {
    if (row.Effect === HEAL_EFFECT) healSpells.add(Number(row.SpellID));
  }
  const healItems = new Set();
  for (const row of itemEffects) {
    if (healSpells.has(Number(row.SpellID))) {
      const itemID = itemByEffectID.get(row.ID);
      if (itemID) healItems.add(itemID);
    }
  }
  consumables.heal = [];
  consumables.potion = consumables.potion.filter((c) => {
    if (!healItems.has(c.id)) return true;
    consumables.heal.push(c);
    return false;
  });

  // Waffenoel oder Rune? Beide sitzen in Unterklasse 8 ("Sonstiges").
  // Ein Oel verzaubert die Waffe zeitweilig - Effekt 54 - und genau
  // daran erkennt man es. Archon fuehrt "Weapon Buff" als eigene
  // Tabelle; hier stand ein Oel mit 1 % unter einer Rune mit 100 %
  // und fiel aus dem Fenster.
  const oilSpells = new Set();
  for (const row of spellEffects) {
    if (row.Effect === ENCHANT_TEMPORARY) oilSpells.add(Number(row.SpellID));
  }
  const oilItems = new Set();
  for (const row of itemEffects) {
    if (oilSpells.has(Number(row.SpellID))) {
      const itemID = itemByEffectID.get(row.ID);
      if (itemID) oilItems.add(itemID);
    }
  }
  consumables.oil = [];
  consumables.other = consumables.other.filter((c) => {
    if (!oilItems.has(c.id)) return true;
    consumables.oil.push(c);
    return false;
  });
  console.log('Waffenoele:', consumables.oil.length, '| Sonstiges:', consumables.other.length);

  for (const list of Object.values(consumables)) {
    list.sort((a, b) => b.rank - a.rank || b.ilvl - a.ilvl || a.name.localeCompare(b.name));
  }
  console.log('Verbrauchsgueter: '
    + Object.entries(consumables).map(([k, v]) => `${v.length} ${k}`).join(', '));

  // --- Datei ----------------------------------------------------------
  const now = new Date();
  const stamp = now.getFullYear() * 10000 + (now.getMonth() + 1) * 100 + now.getDate();

  const out = [];
  out.push('-- ERZEUGT von tools/build-catalog.js. Nicht von Hand aendern.');
  out.push('--');
  out.push('-- Quelle sind die DB2-Tabellen des Clients ueber wago.tools. Was hier');
  out.push('-- steht, ist nachpruefbar: jede ID kommt aus ItemSparse, jeder Kennwert');
  out.push('-- aus der Verzauberung, auf die der Gegenstand zeigt.');
  out.push('--');
  out.push('-- `id` ist die hoechste Handwerksstufe, `alt` die guenstigere darunter.');
  out.push('-- `power` ist der Skalierungswert: zwei Zeilen mit demselben Kennwert');
  out.push('-- unterscheiden sich genau darin, und nur deshalb kann die Oberflaeche');
  out.push('-- "stark" von "guenstig" trennen, ohne es zu raten.');
  out.push('');
  out.push('MetaCodex_Catalog = {');
  out.push(`  build = ${luaString(build)},`);
  out.push(`  expansion = ${expansion},`);
  out.push(`  builtOn = ${stamp},`);
  out.push('');
  out.push('  enchants = {');
  out.push(emitEnchants(enchants));
  out.push('  },');
  out.push('');
  out.push('  gems = {');
  for (const g of gems) {
    out.push(`    { id = ${g.id}, major = ${luaString(g.major)}, minor = ${luaString(g.minor)}, q = ${g.q}, ilvl = ${g.ilvl}, name = ${luaString(g.name)} },`);
  }
  out.push('  },');
  out.push('');
  out.push('  -- Was man kaufen kann. Die Anteile stehen NICHT hier, sondern in');
  out.push('  -- den Empfehlungen: dies ist der Bestand, jene die Beobachtung.');
  out.push('  -- Die englischen Bezeichner je Spec. Grundlage jeder Guide-Adresse;');
  out.push('  -- der Client nennt die Spec in seiner Sprache und taugt dafuer nicht.');
  out.push('  -- Woher ein Gegenstand kommt: Begegnung und Instanz, als IDs.');
  out.push('  -- Den Namen holt der Client, damit er in seiner Sprache steht.');
  out.push('  -- Set-Teil oder Handwerksstueck. Eigenschaft des Gegenstands,');
  out.push('  -- nicht der Beobachtung - deshalb hier und nicht bei den Anteilen.');
  out.push('  -- Bonus-ID je Stufendifferenz. Damit laesst sich ein Gegenstand');
  out.push('  -- auf einer anderen Stufe zeigen, mit richtigen Werten.');
  out.push('  levelDelta = {');
  for (const delta of Object.keys(levelDelta).map(Number).sort((a, b) => a - b)) {
    out.push(`    [${delta}] = ${levelDelta[delta]},`);
  }
  out.push('  },');
  out.push('');
  out.push('  -- Aufwertungspfade der laufenden Saison: Bonus-IDs in Rangfolge.');
  out.push('  -- Der Client rechnet daraus Stufe UND schreibt den Pfad ins Tooltip.');
  out.push('  -- PvP-Ware, am englischen Namen erkannt: Eroberung, Ehre, Handwerk.');
  out.push('  origins = {');
  for (const [id, kind] of [...origins.entries()].sort((a, b) => a[0] - b[0])) {
    out.push(`    [${id}] = ${luaString(kind)},`);
  }
  out.push('  },');
  out.push('');
  out.push('  -- Die Held-Baeume, in beiden Sprachen: der Client kann einen fremden');
  out.push('  -- Held-Baum nicht benennen, und der eigene ist nicht der einzige.');
  out.push('  subtrees = {');
  for (const [id, st] of Object.entries(subTrees).sort((a, b) => a[0] - b[0])) {
    out.push(`    [${id}] = { en = ${luaString(st.en)}, de = ${luaString(st.de)} },`);
  }
  out.push('  },');
  out.push('');
  out.push('  tracks = {');
  for (const t of tracks) {
    out.push(`    { path = ${t.path}, name = ${t.name}, lists = { ${t.lists.join(', ')} } },`);
  }
  out.push('  },');
  out.push('');
  // Welche Bonus-ID welche Zweitwerte setzt.
  //
  // Sechs Zeilen - mehr Paare gibt es aus vier Zweitwerten nicht. Das
  // Addon braucht sie zweimal: um zu sagen, WELCHE Werte auf einem
  // Handwerksstueck stehen, und um den Link zu bauen, mit dem das
  // Tooltip sie auch zeigt.
  out.push('  craftStats = {');
  for (const [list, keys] of [...statBonus.entries()].sort((a, b) => a[0] - b[0])) {
    out.push(`    [${list}] = { ${keys.map(luaString).join(', ')} },`);
  }
  out.push('  },');
  out.push('');
  out.push('  kinds = {');
  for (const [id, kind] of [...kinds.entries()].sort((a, b) => a[0] - b[0])) {
    out.push(`    [${id}] = ${luaString(kind)},`);
  }
  out.push('  },');
  out.push('');
  out.push('  drops = {');
  for (const [itemID, where] of [...drops.entries()].sort((a, b) => a[0] - b[0])) {
    out.push(`    [${itemID}] = { enc = ${where.enc}, inst = ${where.inst} },`);
  }
  out.push('  },');
  out.push('');
  out.push('  specs = {');
  for (const sp of specs) {
    const stat = sp.stat ? `, stat = ${luaString(sp.stat)}` : '';
    out.push(`    [${sp.id}] = { cls = ${luaString(sp.cls)}, spec = ${luaString(sp.spec)}${stat} },`);
  }
  out.push('  },');
  out.push('');
  // Welche Verzauberung zu welchem Gegenstand gehoert.
  //
  // Im Link steht die SpellItemEnchantment-ID, im Katalog stehen
  // Gegenstaende. Ohne die Uebersetzung kann das Addon nur sagen, DASS
  // etwas drauf ist - nicht, ob es das Richtige ist. Genau das hat
  // gefehlt: auf der Hose sass eine andere Verzauberung, und die Zeile
  // sagte "bereits drauf".
  out.push('  runeforge = {');
  for (const [enchID, spellID] of Object.entries(runeforges)) {
    out.push(`    [${enchID}] = ${spellID},`);
  }
  out.push('  },');
  out.push('');

  out.push('  enchantItem = {');
  for (const [enchID, itemID] of Object.entries(enchantMap)) {
    out.push(`    [${enchID}] = ${itemID},`);
  }
  out.push('  },');
  out.push('');

  out.push('  consumables = {');
  for (const [kind, list] of Object.entries(consumables)) {
    if (!list.length) continue;
    out.push(`    ${kind} = {`);
    for (const c of list) {
      out.push(`      { id = ${c.id}, rank = ${c.rank}, q = ${c.q}, name = ${luaString(c.name)} },`);
    }
    out.push('    },');
  }
  out.push('  },');
  out.push('}');
  out.push('');

  const file = path.join(BASE, 'MetaCodex_Data', 'Catalog.lua');
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, out.join('\n'), 'utf8');

  // Und zuletzt alles uebrige, was ueberhaupt verzaubert.
  //
  // Die Karte wurde bis hierher nur aus den Platz-Gruppen gefuellt -
  // Kopf, Schultern, Brust und so fort. Ein Waffenoel gehoert in keine
  // davon, und genau deshalb fehlte "Weapon Buff", das Archon zeigt:
  // seine Verzauberungs-ID stand in keiner Karte, obwohl die Logs sie
  // meldeten.
  //
  // Die Gruppen gewinnen, wo sie etwas wissen: sie kennen den hoechsten
  // Handwerksrang, dieser Durchgang nur den Gegenstand selbst.
  let extra = 0;
  for (const [itemID, enchIDs] of enchantsByItem) {
    for (const enchID of enchIDs) {
      if (enchantMap[enchID]) continue;
      enchantMap[enchID] = itemID;
      extra++;
    }
  }
  console.log('Verzauberungs-IDs zusaetzlich ueber die Wirkung:', extra);

  const mapDir = path.join(BASE, 'tools', 'data');
  fs.mkdirSync(mapDir, { recursive: true });
  // --- Namenskarte der Talente, fuer die Sammler ---------------------
  //
  // Nur Talentzauber, nicht alle 400 000: TraitDefinition (Talentbaum)
  // und PvpTalent. Gleiche Namen ueber Klassen hinweg loest der Sammler
  // auf - er weiss, welche Zauber die Spec wirklich spielt.
  const nameOf = new Map(spellNames.map((r) => [Number(r.ID), r.Name_lang]));
  const talentNames = {};
  for (const row of traitDefs) {
    const id = Number(row.SpellID);
    if (!id) continue;
    const name = (row.OverrideName_lang || '').trim() || nameOf.get(id);
    if (name) talentNames[id] = name;
  }
  const pvpBySpec = {};
  for (const row of pvpTalents) {
    const id = Number(row.SpellID), spec = Number(row.SpecID);
    if (!id || !spec) continue;
    const name = nameOf.get(id);
    if (name) talentNames[id] = name;
    (pvpBySpec[spec] = pvpBySpec[spec] || []).push(id);
  }
  fs.writeFileSync(path.join(mapDir, 'trait-map.json'), JSON.stringify({
    build, trees: treesOut, treeBySpec, subTrees,
  }), 'utf8');
  console.log('Talentbaeume:', Object.keys(treesOut).length, '| Speccs mit Baum:', Object.keys(treeBySpec).length, '| Held-Baeume:', Object.keys(subTrees).length);
  fs.writeFileSync(path.join(mapDir, 'journal-drops.json'), JSON.stringify(journalAll), 'utf8');

  // Bosse und Instanzen unter ihrem englischen Namen.
  //
  // Warcraft Logs nennt Zone und Begegnung englisch, und so standen sie
  // auch im deutschen Fenster: "Nek'zali the Soulcoiler" statt des
  // Namens, den der Spieler im Spiel liest. Mit der Journal-ID holt das
  // Addon den Namen beim Client - dieselbe Regel wie ueberall hier:
  // IDs wandern, Namen kommen von dort, wo sie hingehoeren.
  //
  // Die Karte traegt nebenbei die Instanz je Boss, und damit weiss der
  // Zusammenbau auch ohne den Sammler, welcher Boss zu welchem Raid
  // gehoert.
  const journalNames = { encounters: {}, instances: {} };
  for (const row of journalInstances) {
    const name = row.Name_lang;
    if (name) journalNames.instances[name] = Number(row.ID);
  }
  for (const row of journalEncounters) {
    const name = row.Name_lang;
    if (!name) continue;
    journalNames.encounters[name] = {
      enc: Number(row.ID), inst: Number(row.JournalInstanceID) || 0,
      // Die Reihenfolge im Raid. Alphabetisch waere sie sonst, und zwar
      // alphabetisch nach dem ENGLISCHEN Namen - eine Liste, die weder
      // der Reihenfolge im Spiel noch dem deutschen Alphabet folgt.
      order: Number(row.OrderIndex) || 0,
    };
  }
  fs.writeFileSync(path.join(mapDir, 'journal-names.json'),
    JSON.stringify(journalNames), 'utf8');
  console.log(`  Journalnamen: ${Object.keys(journalNames.encounters).length} Begegnungen, `
    + `${Object.keys(journalNames.instances).length} Instanzen`);
  console.log('Journal gesamt:', Object.keys(journalAll).length, 'Gegenstaende');
  fs.writeFileSync(path.join(mapDir, 'talent-map.json'), JSON.stringify({
    build, names: talentNames, pvp: pvpBySpec,
  }, null, 1), 'utf8');
  console.log('Talentnamen:', Object.keys(talentNames).length,
    '| PvP-Talente je Spec:', Object.keys(pvpBySpec).length, 'Speccs');

  const mapFile = path.join(mapDir, 'enchant-map.json');
  fs.writeFileSync(mapFile, JSON.stringify(enchantMap, null, 1), 'utf8');
  // Auch fuer die Sammler: was keine Rolle ist, aber trotzdem auf der
  // Waffe sitzt.
  fs.writeFileSync(path.join(mapDir, 'runeforge-map.json'),
    JSON.stringify(runeforges, null, 1), 'utf8');
  console.log('geschrieben: ' + mapFile + ' (' + Object.keys(enchantMap).length + ' IDs)');

  const count = Object.values(enchants).reduce((n, l) => n + l.length, 0);
  console.log(`geschrieben: ${file}`);
  console.log(`  ${count} Verzauberungen, ${gems.length} Steine`);
})().catch((err) => {
  console.error('Fehlgeschlagen:', err.message);
  process.exit(1);
});
