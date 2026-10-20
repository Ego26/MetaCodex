// The rotation of every spec, from the SimulationCraft action lists.
//
//     node tools/build-rotation.js <repo> [Recommendations.lua] [--append]
//
// Source: the default APLs of SimulationCraft (GPL-3.0, like this addon),
// https://github.com/simulationcraft/simc/tree/midnight/ActionPriorityLists/default
// They are what the simulator casts, written by the class maintainers.
// What makes them fit a player here is the BUILD: every list is folded
// against the measured top build of the spec (tools/lib/apl.js), so a line
// for a talent nobody takes is gone, and a spell the build replaces
// (Ancestral Swiftness over Nature's Swiftness) never shows twice.
//
// Spell names and the replacements come from the client's own tables via
// wago.tools, the same source as the catalog.
//
// Writes tools/data/rotation.lua - an assignment to
// MetaCodex_Recommendations.rotation. With --append it also goes onto the
// end of Recommendations.lua, which is how the nightly ships it: no new
// file, no change to the TOC.

const fs = require('fs');
const path = require('path');
const https = require('https');
const zlib = require('zlib');
const loadout = require('./loadout');
const apl = require('./lib/apl');
const opener = require('./lib/opener');
const { simcBuffMap } = require('./lib/simc-buffs');
const { simplify, simpleConditions } = require('./lib/simplify');
const { buildReplacements, replacedNames: namesReplaced } = require('./lib/replace');
const { worthRetrying, waitSeconds } = require('./lib/http-retry');

const BASE = path.resolve(process.argv[2] || '.');
const REC = process.argv.slice(3).find((a) => !a.startsWith('--'))
  || path.join(BASE, 'MetaCodex_Data', 'Recommendations.lua');
const APPEND = process.argv.includes('--append');
const APL_URL = 'https://raw.githubusercontent.com/simulationcraft/simc/midnight/ActionPriorityLists/default/';
// The modes a rotation is built for, and where their build comes from.
const MODES = { mplus: ['mplus', 'mplus-keys'], raid: ['raid', 'raid-mythic', 'raid-normal'] };

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function get(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, {
      headers: { 'User-Agent': 'MetaCodex (github.com/Ego26/MetaCodex)', 'Accept-Encoding': 'gzip' },
      timeout: 60000,
    }, (res) => {
      const enc = res.headers['content-encoding'];
      const stream = enc === 'gzip' ? res.pipe(zlib.createGunzip()) : res;
      const chunks = [];
      stream.on('data', (c) => chunks.push(c));
      stream.on('end', () => {
        const body = Buffer.concat(chunks).toString('utf8');
        if (res.statusCode !== 200) {
          const err = new Error('HTTP ' + res.statusCode + ' ' + url);
          err.statusCode = res.statusCode;
          return reject(err);
        }
        resolve(body);
      });
      stream.on('error', reject);
    });
    req.on('timeout', () => req.destroy(new Error('timeout ' + url)));
    req.on('error', reject);
  });
}

async function patient(url) {
  for (let attempt = 0; ; attempt += 1) {
    try {
      return await get(url);
    } catch (err) {
      if (!worthRetrying(err) || attempt >= 3) throw err;
      await sleep(waitSeconds(attempt) * 1000);
    }
  }
}

function parseCSV(text) {
  const rows = [];
  let row = [], cur = '', q = false;
  for (let i = 0; i < text.length; i += 1) {
    const c = text[i];
    if (q) {
      if (c === '"' && text[i + 1] === '"') { cur += '"'; i += 1; } else if (c === '"') q = false; else cur += c;
    } else if (c === '"') q = true;
    else if (c === ',') { row.push(cur); cur = ''; }
    else if (c === '\n') { row.push(cur.replace(/\r$/, '')); rows.push(row); row = []; cur = ''; }
    else cur += c;
  }
  if (cur || row.length) { row.push(cur); rows.push(row); }
  const head = rows.shift() || [];
  return rows.map((r) => Object.fromEntries(head.map((h, i) => [h, r[i]])));
}

// ------------------------------------------------------------------ Lua

/** Reads the table constructor of a generated Lua data file. */
function readLuaTable(text) {
  let i = text.indexOf('{');
  const ws = () => {
    for (;;) {
      while (i < text.length && /\s/.test(text[i])) i += 1;
      if (text.startsWith('--', i)) { while (i < text.length && text[i] !== '\n') i += 1; continue; }
      break;
    }
  };
  function str() {
    const quote = text[i]; i += 1;
    let out = '';
    const bytes = [];
    const flush = () => { if (bytes.length) { out += Buffer.from(bytes).toString('utf8'); bytes.length = 0; } };
    while (text[i] !== quote) {
      if (text[i] === '\\') {
        i += 1;
        const d = text.slice(i).match(/^\d{1,3}/);
        if (d) { bytes.push(Number(d[0])); i += d[0].length; continue; }
        flush();
        const m = { n: '\n', t: '\t' }[text[i]];
        out += m || text[i]; i += 1;
        continue;
      }
      flush();
      out += text[i]; i += 1;
    }
    flush();
    i += 1;
    return out;
  }
  function value() {
    ws();
    const c = text[i];
    if (c === '{') return table();
    if (c === '"' || c === "'") return str();
    const m = text.slice(i, i + 40).match(/^(-?[0-9.]+(?:e[-+]?\d+)?|true|false|nil)/);
    if (!m) throw new Error('Lua at ' + i + ': ' + text.slice(i, i + 30));
    i += m[0].length;
    if (m[0] === 'true') return true;
    if (m[0] === 'false') return false;
    if (m[0] === 'nil') return null;
    return Number(m[0]);
  }
  function table() {
    i += 1;
    const out = {};
    let n = 1;
    for (;;) {
      ws();
      if (text[i] === '}') { i += 1; return out; }
      let key;
      if (text[i] === '[') {
        i += 1; key = value(); ws(); i += 1; ws(); i += 1;
      } else {
        const m = text.slice(i, i + 80).match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)/);
        if (m) { key = m[1]; i += m[0].length; }
      }
      const v = value();
      if (key === undefined) { key = n; n += 1; }
      out[key] = v;
      ws();
      if (text[i] === ',' || text[i] === ';') i += 1;
    }
  }
  return table();
}

const list = (t) => {
  const out = [];
  for (let k = 1; t && t[k] !== undefined; k += 1) out.push(t[k]);
  return out;
};

function luaValue(v, indent) {
  if (Array.isArray(v)) return '{ ' + v.map((x) => luaValue(x, indent)).join(', ') + ' }';
  if (v === null || v === undefined) return 'nil';
  if (typeof v === 'string') return JSON.stringify(v);
  if (typeof v === 'boolean') return String(v);
  // Nie Infinity oder NaN: in Lua waere das ein Name, und "-Infinity" ein
  // Rechenfehler beim Laden - die ganze Datendatei laege brach.
  if (typeof v === 'number') return Number.isFinite(v) ? String(v) : 'nil';
  const parts = Object.entries(v).filter(([, x]) => x !== undefined && x !== null)
    .map(([k, x]) => (/^[A-Za-z_][A-Za-z0-9_]*$/.test(k) ? k : '[' + JSON.stringify(k) + ']') + ' = ' + luaValue(x, indent));
  return '{ ' + parts.join(', ') + ' }';
}

// ------------------------------------------------------------------ run

const slug = (s) => String(s || '').toLowerCase().replace(/'/g, '').replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
// SimC drops hyphens where the slug writes an underscore (shadopan,
// Shado-Pan): compared without them.
const bare = (s) => String(s || '').replace(/_/g, '');

(async () => {
  const map = loadout.load(BASE);
  const build = map.build;
  console.log('Build:', build);
  const db2 = async (table, extra) => parseCSV(await patient(`https://wago.tools/db2/${table}/csv?build=${build}${extra || ''}`));
  const [spellNames, specSpells, skillLines, chrSpecs, overrides, traitDefs, spellMisc, durations,
    spellTexts, classOptions, chrClasses, spellCooldowns, auraOptions, spellPower, itemRows,
    spellCategories, spellCategory] = await Promise.all([
    db2('SpellName'), db2('SpecializationSpells'), db2('SkillLineAbility'), db2('ChrSpecialization'),
    db2('SpellEffect', '&filter%5BEffectAura%5D=332'),
    db2('TraitDefinition'), db2('SpellMisc'), db2('SpellDuration'),
    db2('Spell'), db2('SpellClassOptions'), db2('ChrClasses'), db2('SpellCooldowns'), db2('SpellAuraOptions'),
    db2('SpellPower'), db2('Item'), db2('SpellCategories'), db2('SpellCategory'),
  ]);
  const nameEN = new Map(spellNames.map((r) => [Number(r.ID), r.Name_lang]));
  // A talent's spell is often its passive; the one on the bar is the trait's
  // VisibleSpellID (Ancestral Swiftness: passive 448861, cast 443454 with its
  // cooldown).
  const visibleOf = new Map();
  for (const r of traitDefs) {
    const id = Number(r.SpellID);
    const vis = Number(r.VisibleSpellID) || 0;
    if (vis && vis !== id && nameEN.get(vis) === nameEN.get(id)) visibleOf.set(id, vis);
  }

  // Replacements: the spell in EffectMiscValue_0 is replaced by the one in
  // EffectBasePoints while the aura holds.
  // What replaces what - the rules and why are in tools/lib/replace.js.
  const durationMs = new Map(durations.map((r) => [Number(r.ID), Number(r.Duration)]));
  const lastsMs = new Map();
  for (const r of spellMisc) {
    const id = Number(r.SpellID);
    if (lastsMs.has(id) && Number(r.DifficultyID) !== 0) continue;
    lastsMs.set(id, durationMs.get(Number(r.DurationIndex)) || 0);
  }
  const auraTextOf = new Map(spellTexts.map((r) => [Number(r.ID), r.AuraDescription_lang || '']));
  const replacements = buildReplacements({
    auras: overrides.map((r) => ({ carrier: Number(r.SpellID), old: Number(r.EffectMiscValue_0) || 0,
      neu: Math.round(Number(r.EffectBasePointsF) || 0), book: Number(r.EffectMiscValue_1) === 2 })),
    traits: traitDefs.map((r) => ({ old: Number(r.OverridesSpellID) || 0, neu: Number(r.SpellID) || 0 })),
    specs: specSpells.map((r) => ({ spec: Number(r.SpecID), old: Number(r.OverridesSpellID) || 0, neu: Number(r.SpellID) || 0 })),
    lastsMs: (id) => lastsMs.get(id) || 0,
    buffText: (id) => auraTextOf.get(id) || '',
  });

  const rec = readLuaTable(fs.readFileSync(REC, 'utf8'));
  const specs = Object.entries(chrSpecs).length ? chrSpecs : [];
  const catalog = fs.readFileSync(path.join(BASE, 'MetaCodex_Data', 'Catalog.lua'), 'utf8');
  const re = /\[(\d+)\] = \{ cls = "([^"]+)", spec = "([^"]+)", stat = "[^"]*", role = "([^"]+)"/g;
  const catSpecs = [];
  let m;
  while ((m = re.exec(catalog))) catSpecs.push({ id: Number(m[1]), cls: m[2], spec: m[3], role: m[4] });
  // Which items are tier-set pieces: the catalog knows (kinds), the
  // measured gear often does not say.
  const setItems = new Set();
  const kindsAt = catalog.indexOf('  kinds = {');
  if (kindsAt >= 0) {
    const block = catalog.slice(kindsAt, catalog.indexOf('\n  },', kindsAt));
    for (const k of block.matchAll(/\[(\d+)\] = "set"/g)) setItems.add(Number(k[1]));
  }
  const classOf = new Map(specs.map((r) => [Number(r.ID), Number(r.ClassID)]));

  // WHICH OF MANY SPELLS OF ONE NAME (20 October). "Devour" has 145 IDs,
  // "Metamorphosis" 83; the first hit was an internal one without a word of
  // tooltip. Every candidate of a name is scored instead:
  //   cast by the measured players (the logs)            +16
  //   the spec's, a talent's or the class line's spell     +8
  //   the class's spell family (SpellClassOptions)         +4
  //   a description of its own (not "$@spelldesc...")      +2, a borrowed one +1
  //   for a buff: a buff text                              +2
  //   an icon                                              +1
  //   no text at all                                       -10
  // Ties: among the class's own spells the lower ID (the base spell), among
  // the rest the newer one.
  const idsByBare = new Map();
  for (const [id, n] of nameEN) {
    const k = slug(n).replace(/_/g, '');
    if (!k) continue;
    if (!idsByBare.has(k)) idsByBare.set(k, []);
    idsByBare.get(k).push(id);
  }
  const textOf = new Map(spellTexts.map((r) => [Number(r.ID), { d: r.Description_lang || '', a: r.AuraDescription_lang || '' }]));
  const familyOfSpell = new Map(classOptions.map((r) => [Number(r.SpellID), Number(r.SpellClassSet)]));
  const familyOfClass = new Map(chrClasses.map((r) => [Number(r.ID), Number(r.SpellClassSet)]));
  const iconOf = new Map();
  for (const r of spellMisc) if (!iconOf.has(Number(r.SpellID))) iconOf.set(Number(r.SpellID), Number(r.SpellIconFileDataID) || 0);
  // A spell's cooldown (seconds) and a buff's most stacks, from the game data:
  // "cooldown.X.duration" and "buff.X.max_stack" in the lists are numbers.
  const cdSeconds = new Map();
  for (const r of spellCooldowns) {
    const ms = Math.max(Number(r.RecoveryTime) || 0, Number(r.CategoryRecoveryTime) || 0);
    if (ms > 0 && !cdSeconds.has(Number(r.SpellID))) cdSeconds.set(Number(r.SpellID), ms / 1000);
  }
  // A spell with charges keeps its cooldown in the charge category
  // (Celestial Alignment: one second above, 180 here).
  const rechargeOfCategory = new Map(spellCategory.map((r) => [Number(r.ID), Number(r.ChargeRecoveryTime) || 0]));
  const rechargeSeconds = new Map();
  for (const r of spellCategories) {
    const ms = rechargeOfCategory.get(Number(r.ChargeCategory)) || 0;
    if (ms > 0 && !rechargeSeconds.has(Number(r.SpellID))) rechargeSeconds.set(Number(r.SpellID), ms / 1000);
  }
  // A spell's cost: rage, runic power, astral power, insanity, fury and pain
  // are stored times ten (Starsurge: 400 for 40).
  const ZEHNTEL = new Set([1, 6, 8, 13, 17, 18]);
  const costs = new Map();
  for (const r of spellPower) {
    const id = Number(r.SpellID);
    const c = Number(r.ManaCost) || 0;
    if (c > 0 && !costs.has(id)) costs.set(id, ZEHNTEL.has(Number(r.PowerType)) ? c / 10 : c);
  }
  // An item's kind: weapons are class 2, a dagger subclass 15.
  const itemKind = new Map(itemRows.map((r) => [Number(r.ID), { cls: Number(r.ClassID), sub: Number(r.SubclassID) }]));
  const maxStacks = new Map();
  for (const r of auraOptions) {
    const n = Number(r.CumulativeAura) || 0;
    if (n > 0 && !maxStacks.has(Number(r.SpellID))) maxStacks.set(Number(r.SpellID), n);
  }
  const scoreOf = (id, use, own, family, cast) => {
    let p = 0;
    if (cast && cast.has(id)) p += 16;
    if (own.has(id)) p += 8;
    if (family && familyOfSpell.get(id) === family) p += 4;
    const t = textOf.get(id) || { d: '', a: '' };
    if (t.d && !t.d.startsWith('$@')) p += 2;
    else if (t.d) p += 1;
    if (use === 'aura' && t.a) p += 2;
    // No text at all: no use for a tooltip (Arcane Charge 190427, five of
    // the six Surging Totems). Only when nothing else is there.
    if (!t.d && !t.a) p -= 10;
    if (iconOf.get(id)) p += 1;
    return p;
  };

  // The openers measured around raid pulls (tools/collect-wcl.js), from the
  // base files only - the per-boss files hold the same pulls again.
  const openersBySpec = new Map();
  for (const name of ['wcl-raid.json', 'wcl-raid-mythic.json', 'wcl-raid-normal.json']) {
    const file = path.join(BASE, 'tools', 'data', name);
    if (!fs.existsSync(file)) continue;
    const j = JSON.parse(fs.readFileSync(file, 'utf8'));
    for (const [id, e] of Object.entries(j.specs || {})) {
      if (!Array.isArray(e.openers)) continue;
      if (!openersBySpec.has(Number(id))) openersBySpec.set(Number(id), []);
      openersBySpec.get(Number(id)).push(...e.openers);
    }
  }

  // WHAT THE TOP PLAYERS CAST, per spec and activity (tools/collect-wcl.js):
  // players, minutes, and per spell [id, casts, players who cast it]. The
  // base files only - the per-dungeon and per-boss files repeat the pulls.
  const castFiles = { mplus: ['wcl-mplus.json'], raid: ['wcl-raid.json', 'wcl-raid-mythic.json', 'wcl-raid-normal.json'] };
  const castsBy = {};
  for (const [mode, files] of Object.entries(castFiles)) {
    castsBy[mode] = new Map();
    for (const name of files) {
      const file = path.join(BASE, 'tools', 'data', name);
      if (!fs.existsSync(file)) continue;
      const j = JSON.parse(fs.readFileSync(file, 'utf8'));
      for (const [id, e] of Object.entries(j.specs || {})) {
        if (!e.casts || !e.casts.players) continue;
        const acc = castsBy[mode].get(Number(id)) || { players: 0, minutes: 0, by: new Map() };
        acc.players += e.casts.players;
        acc.minutes += e.casts.minutes;
        for (const [g, n, wer] of e.casts.by) {
          const b = acc.by.get(g) || [0, 0];
          b[0] += n;
          b[1] += wer;
          acc.by.set(g, b);
        }
        castsBy[mode].set(Number(id), acc);
      }
    }
  }
  // Below this many measured players a share says too little.
  const MIN_MEASURED = 20;
  // A line whose spell fewer than this part of the measured players cast is
  // not played - whatever the simulation says.
  const PLAYED_FROM = 0.03;

  const out = {};
  const report = [];
  // MC_VAGUE=1: which conditions stayed vague, most frequent first.
  const vague = process.env.MC_VAGUE ? new Map() : null;
  apl.logVague(vague);
  // Heiler nicht: ihre Listen sind reine Schadenslisten, und wer heilt,
  // spielt nicht nach ihnen.
  const fileOf = (s) => `${s.cls.replace(/-/g, '')}_${s.spec.replace(/-/g, '_')}.simc`;
  const texts = new Map();
  for (const s of catSpecs.filter((x) => x.role !== 'healer')) {
    try {
      texts.set(s.id, await patient(APL_URL + fileOf(s)));
    } catch (err) {
      report.push(`${s.id} ${fileOf(s)}: no list (${err.statusCode || err.message})`);
    }
    await sleep(150);
  }
  // The current tier set: the newest season ANY list asks about. One list
  // still asking for last season's set must not count today's set as it.
  const ORDER = ['df', 'tww', 'mid'];
  const seasons = [];
  for (const t of texts.values()) {
    for (const x of t.matchAll(/set_bonus\.([a-z]+)(\d+)_\dpc/g)) seasons.push([x[1], Number(x[2])]);
  }
  seasons.sort((a, b) => (ORDER.indexOf(b[0]) - ORDER.indexOf(a[0])) || (b[1] - a[1]));
  const current = seasons.length ? seasons[0][0] + seasons[0][1] : null;
  console.log('Tier-Set der Saison:', current);

  // SIMC'S OWN BUFF NAMES (20 October). A list asks for buffs by SimC's name
  // ("hammer_of_light_free", "voidfall_spending"); the game knows no spell of
  // that name. Which spell it is stands in SimC's class modules:
  //   make_buff( this, "hammer_of_light_free", find_spell( 433732 ) )
  //   hero_spec.voidfall_spending_buff = talent_spell_lookup( ..., 1256302 );
  //   ... "voidfall_spending", p->hero_spec.voidfall_spending_buff )
  // One API call lists the files; without it the night goes on without them.
  const simcBuffs = {};
  try {
    const treeJson = JSON.parse(await patient('https://api.github.com/repos/simulationcraft/simc/git/trees/midnight?recursive=1'));
    const files = (treeJson.tree || []).map((x) => x.path)
      .filter((p) => /^engine\/class_modules\/(?!apl\/).*\.(cpp|hpp)$/.test(p));
    const CLASSES = ['death_knight', 'demon_hunter', 'druid', 'evoker', 'hunter', 'mage', 'monk',
      'paladin', 'priest', 'rogue', 'shaman', 'warlock', 'warrior'];
    for (const cls of CLASSES) {
      const mine = files.filter((p) => p.includes('/' + cls + '/') || p.endsWith('sc_' + cls + '.cpp'));
      if (!mine.length) continue;
      let text = '';
      for (const p of mine) text += await patient('https://raw.githubusercontent.com/simulationcraft/simc/midnight/' + p) + '\n';
      simcBuffs[cls] = simcBuffMap(text);
    }
    console.log('SimC-Buffs:', Object.entries(simcBuffs).map(([c, m]) => c + ' ' + m.size).join(', '));
  } catch (err) {
    console.log('SimC-Buffs nicht gelesen:', String(err.message).slice(0, 120));
  }

  // One spec that fails costs that spec, not the night.
  for (const s of catSpecs.filter((x) => texts.has(x.id))) {
   try {
    const file = fileOf(s);
    // MC_VAGUE=<specID>: only this spec's vague conditions.
    if (vague) apl.logVague(process.env.MC_VAGUE === '1' || process.env.MC_VAGUE === String(s.id) ? vague : null);
    const text = texts.get(s.id);
    const lists = apl.parseApl(text);
    const treeId = map.treeBySpec[s.id];
    const tree = treeId && map.trees[treeId];
    if (!tree) { report.push(`${s.id}: no tree`); continue; }

    // Candidates for a SimC name, in order: the spec's spells, the talent
    // tree, the class's spells, then any spell of that name.
    const classBit = 1 << ((classOf.get(s.id) || 1) - 1);
    const byName = new Map();
    const add = (id) => {
      const k = slug(nameEN.get(id));
      if (!k) return;
      if (!byName.has(k)) byName.set(k, []);
      if (!byName.get(k).includes(id)) byName.get(k).push(id);
    };
    for (const r of specSpells) if (Number(r.SpecID) === s.id) add(Number(r.SpellID));
    const treeSpells = new Set();
    const nodeSub = new Map();
    for (const n of tree.nodes) {
      nodeSub.set(n.id, n.subTree);
      for (const e of n.entries) if (e.spell) { add(e.spell); treeSpells.add(bare(slug(nameEN.get(e.spell)))); }
    }
    // The class's skill lines: those whose rows name only this class.
    // Flame Shock sits in one of them without a class mask of its own.
    const classLines = new Set(skillLines.filter((r) => Number(r.ClassMask) === classBit).map((r) => r.SkillLine));
    // Two spells of one name in the class lines (Lightning Bolt 188196 and
    // 318044): the older one is the one on the bar.
    skillLines.filter((r) => classLines.has(r.SkillLine)).map((r) => Number(r.Spell))
      .sort((a, b) => a - b).forEach(add);
    // The best ID of a name for this spec (see scoreOf above).
    const own = new Set([...byName.values()].flat());
    const family = familyOfClass.get(classOf.get(s.id) || 0) || 0;
    const pick = (k, use, cast) => {
      const cands = idsByBare.get(String(k || '').replace(/_/g, '')) || [];
      let best = null;
      for (const id of cands) {
        const p = scoreOf(id, use, own, family, cast);
        // A tie among the class's own spells goes to the lower ID (the base
        // spell); among the rest to the newer one - old IDs stay in the game
        // data long after their spell is gone (Devour 272793 of an earlier
        // expansion against the Devourer's 1217610).
        const better = !best || p > best.p
          || (p === best.p && (own.has(id) && own.has(best.id) ? id < best.id : id > best.id));
        if (better) best = { id, p };
      }
      if (best && use === 'action' && visibleOf.has(best.id)) return visibleOf.get(best.id);
      return best ? best.id : null;
    };
    const simcKlasse = simcBuffs[s.cls.replace(/-/g, '_')] || new Map();
    // All IDs of a name, the class's family first (for values like a
    // cooldown's length, which only some of them carry).
    const kandidaten = (k) => {
      const ids = idsByBare.get(String(k || '').replace(/_/g, '')) || [];
      return [...ids].sort((x, y) => (familyOfSpell.get(y) === family) - (familyOfSpell.get(x) === family));
    };
    const spell = (k) => {
      const sid = simcKlasse.get(k);
      if (sid && nameEN.has(sid)) return sid;
      return pick(k, 'aura') || pick(k.replace(/_(tier|buff|debuff|proc)$/, ''), 'aura');
    };
    // SimC's own names for a form-bound or merged action.
    const ALIAS = { any_dnd: 'death_and_decay' };
    // Racials: the rows of the class lines' table that carry a race mask.
    const racialIds = (k) => [...new Set(skillLines
      .filter((r) => Number(r.RaceMasks_0 || 0) !== 0 && slug(nameEN.get(Number(r.Spell))) === k
        && (Number(r.ClassMask || 0) === 0 || (Number(r.ClassMask) & classBit)))
      .map((r) => Number(r.Spell)))].sort((x, y) => x - y);
    const actionSpellFor = (k, cast) => {
      const name = ALIAS[k] || k;
      const plain = name.replace(/_(cat|bear)$/, '');
      return pick(name, 'action', cast) || pick(plain, 'action', cast);
    };
    const actionSpell = (k) => actionSpellFor(k, null);

    // VARIABLES, inlined where their value is certain.
    //
    // A list sets a variable once, or the same way in several places, or
    // under a condition (op=setif: value if the condition holds, else
    // value_else). Definitions whose own condition folds to false for this
    // build drop out first - one per hero tree is common. What is left must
    // be one value; anything that adds up over the fight (op=add, max, ...)
    // stays unknown.
    const defs = new Map();
    for (const l of Object.values(lists)) {
      for (const { action, opts } of l) {
        if (action !== 'variable' || !opts.name) continue;
        if (!defs.has(opts.name)) defs.set(opts.name, []);
        const d = defs.get(opts.name);
        const key = JSON.stringify(opts);
        if (!d.some((x) => JSON.stringify(x) === key)) d.push(opts);
      }
    }
    // STATES A LIST KEEPS OVER THE FIGHT (20 October): a variable set to 1 or
    // 0 under conditions, with a start value before the fight. "opener" is
    // 1 before the pull and 0 once Celestial Alignment is up - that is "it
    // has not yet happened this fight that Celestial Alignment is up".
    const varDefs = new Map();
    for (const [ln, arr] of Object.entries(lists)) {
      for (const { action, opts } of arr) {
        if (action !== 'variable' || !opts.name) continue;
        if (!varDefs.has(opts.name)) varDefs.set(opts.name, []);
        varDefs.get(opts.name).push({ list: ln, ...opts });
      }
    }
    // Variables SimC keeps per target (cycling_variable): the one used is the
    // longest time to die of the pull - in our long fight, the fight's length.
    const cyclingTtd = new Set();
    for (const arr of Object.values(lists)) {
      for (const { action, opts } of arr) {
        if (action === 'cycling_variable' && opts.name && /time_to_die/.test(opts.value || '')) cyclingTtd.add(opts.name);
      }
    }
    const latchShape = (name) => {
      const d = varDefs.get(name);
      if (!d || d.length < 2) return null;
      let init = 0;
      const ons = [];
      const offs = [];
      for (const o of d) {
        const op = o.op || 'set';
        const val = op === 'reset' ? (o.default || '0') : o.value;
        if ((op !== 'set' && op !== 'reset') || (val !== '0' && val !== '1')) return null;
        if (o.list === 'precombat' && !o.if) { init = Number(val); continue; }
        // Set on every pass, not on an event: no state.
        if (!o.if) return null;
        (val === '1' ? ons : offs).push(o.if);
      }
      if (!ons.length && !offs.length) return null;
      return { init, ons, offs };
    };
    const latchOf = (name, c, sp) => {
      const shape = latchShape(name);
      if (!shape) return null;
      const satz = (conds) => {
        let acc = null;
        for (const text of conds) {
          const r = apl.fold(apl.parse(apl.simcNames(text)), c);
          if (r.lo === 0 && r.hi === 0) continue;
          const rec = apl.vereinfacht(apl.records(r, sp));
          if (apl.isOther(rec) || rec[0] === 'true' || rec[0] === 'false') return undefined;
          acc = acc ? ['or', acc, rec] : rec;
        }
        return acc;
      };
      const an = satz(shape.ons);
      const aus = satz(shape.offs);
      if (an === undefined || aus === undefined) return null;
      if (shape.init === 1 && !an && aus) return ['notyet', aus];
      if (shape.init === 0 && an && !aus) return ['already', an];
      if (an && aus) return ['since', aus, an];
      return null;
    };
    const resolving = new Set();
    const variableIn = (name, c) => {
      if (cyclingTtd.has(name) && !defs.has(name)) return { num: 3600 };
      const d = defs.get(name);
      if (!d || resolving.has(name)) return null;
      resolving.add(name);
      try {
        const folds = (text) => apl.fold(apl.parse(apl.simcNames(text)), c);
        const live = d.filter((o) => {
          if (!o.if) return true;
          const r = folds(o.if);
          return !(r.lo === 0 && r.hi === 0);
        });
        if (!live.length) return { num: 0 };
        // Only ever reset to its default: that value, always (Retribution's
        // pre_es_wake).
        if (live.every((o) => o.op === 'reset')) return apl.parse(apl.simcNames(String(live[live.length - 1].default || 0)));
        const valueOf = (o) => {
          if (o.if) {
            const r = folds(o.if);
            if (!(r.lo > 0 || r.hi < 0)) return null;
          }
          const op = o.op || 'set';
          if (op === 'set' && o.value !== undefined) return o.value;
          if (op === 'setif' && o.condition !== undefined) {
            return `?:${o.condition}\u0000${o.value || 0}\u0000${o.value_else || 0}`;
          }
          return null;
        };
        // Which definitions apply HERE: one whose condition surely holds wins
        // (Shadow's dots_up: one for under three targets, one for more);
        // otherwise those without a condition; otherwise all that may.
        const sicher = live.filter((o) => o.if && (() => { const r = folds(o.if); return r.lo > 0 || r.hi < 0; })());
        const ohne = live.filter((o) => !o.if);
        const gelten = sicher.length ? sicher : (ohne.length && ohne.length === live.length ? ohne : live);
        // A value, then overwritten under conditions, in one list (Outlaw's
        // finish_condition): an if-then-else chain, in the list's order.
        const ordnung = (varDefs.get(name) || []).filter((o) => (o.op || 'set') === 'set' && o.value !== undefined);
        if (ordnung.length >= 2 && !ordnung[0].if && ordnung.slice(1).every((o) => o.if && o.list === ordnung[0].list)) {
          let t = apl.parse(apl.simcNames(ordnung[0].value));
          for (const o of ordnung.slice(1)) {
            t = { op: '?:', c: apl.parse(apl.simcNames(o.if)), a: apl.parse(apl.simcNames(o.value)), b: t };
          }
          return t;
        }
        const values = gelten.map((o) => valueOf({ ...o, if: undefined }));
        if (values.some((v) => v === null) || new Set(values).size !== 1) return null;
        const v = values[0];
        if (v.startsWith('?:')) {
          const [cond, yes, no] = v.slice(2).split('\u0000');
          return { op: '?:', c: apl.parse(apl.simcNames(cond)), a: apl.parse(apl.simcNames(yes)), b: apl.parse(apl.simcNames(no)) };
        }
        return apl.parse(apl.simcNames(v));
      } finally {
        resolving.delete(name);
      }
    };

    // What the spec gets for free: the granted nodes of any string of it.
    const granted = new Set();
    let grantedDone = false;
    const grantedOf = () => {
      if (grantedDone) return granted;
      grantedDone = true;
      for (const bySource of Object.values(rec.modes || {})) {
        for (const entry of Object.values(bySource || {})) {
          const e = entry && entry.specs && entry.specs[s.id];
          if (!e || !e.build || !e.build.text) continue;
          const d = loadout.decode(BASE, e.build.text, treeId);
          if (!d || d.spec !== s.id) continue;
          for (const n of d.nodes) if (n.granted && !nodeSub.get(n.node)) granted.add(n.spell);
          if (granted.size) return granted;
        }
      }
      return granted;
    };

    for (const [mode, chain] of Object.entries(MODES)) {
      // The build: the source with the most measured players that carries
      // the string, in the first mode of the chain that has one.
      let best = null;
      // Two forms: an import string (raider.io) or a list of taken talents
      // (Warcraft Logs, in nodeLists). The list usually stands on far more
      // players - in the raid it is the only one with a count at all; the
      // string from raider.io there had none, and the hint said "0 players".
      for (const key of chain) {
        const bySource = rec.modes && rec.modes[key];
        if (!bySource) continue;
        for (const [source, entry] of Object.entries(bySource)) {
          const e = entry && entry.specs && entry.specs[s.id];
          if (!e || !e.build) continue;
          const nodes = typeof e.build.nodes === 'number' && rec.nodeLists ? list(rec.nodeLists[e.build.nodes]) : null;
          if (!e.build.text && !(nodes && nodes.length)) continue;
          const sample = e.sample || 0;
          if (!best || sample > best.sample) best = { text: e.build.text, nodes, sample, source, entry: e };
        }
        if (best) break;
      }
      if (!best) continue;
      // ONE ROTATION PER HERO TREE (20 October), like Wowhead's switch: each
      // with the build of the players who take that tree. The most played
      // comes first and is the default.
      const variants = [];
      for (const [hid, h] of Object.entries(best.entry.hero || {})) {
        const b = h && h.build;
        if (!b) continue;
        const nodes = typeof b.nodes === 'number' && rec.nodeLists ? list(rec.nodeLists[b.nodes]) : null;
        if (!b.text && !(nodes && nodes.length)) continue;
        variants.push({ hero: Number(hid), text: b.text, nodes, players: h.players || 0, pct: h.pct || 0 });
      }
      variants.sort((x, y) => y.players - x.players);
      // A tree almost nobody plays measures nothing.
      const tragend = variants.filter((v) => v.players >= 10 || v === variants[0]);
      if (!tragend.length) tragend.push({ hero: null, text: best.text, nodes: best.nodes, players: best.sample, pct: 100 });
      const ergebnisse = [];
      for (const v of tragend) {
      let takenIds, subTree;
      if (v.text) {
        const dec = loadout.decode(BASE, v.text, treeId);
        if (!dec) continue;
        subTree = dec.subTree || v.hero;
        // Only the chosen hero tree: the string marks the other keystone as
        // granted too.
        takenIds = new Set(dec.nodes.filter((n) => !nodeSub.get(n.node) || nodeSub.get(n.node) === subTree)
          .map((n) => n.spell));
      } else {
        // The list names what was picked, not what the spec gets for free
        // (Lava Burst for Elemental). Those come from any string of the spec.
        takenIds = new Set([...v.nodes.map((n) => n.spell), ...grantedOf(s.id)]);
        subTree = v.hero;
      }
      const taken = new Set([...takenIds].map((id) => bare(slug(nameEN.get(id)))));
      const heroName = subTree && map.subTrees[subTree] ? slug(map.subTrees[subTree].en) : '';
      const dec = { subTree };
      // APEX (SimC engine/player/player.cpp): the tiers of the spec's tiered
      // talent; apex.N is on when the build reaches tier N.
      let apexTop = -1;
      for (const node of tree.nodes) {
        if (node.type !== 1 || node.subTree) continue;
        node.entries.forEach((e, i) => { if (e.spell && takenIds.has(e.spell)) apexTop = Math.max(apexTop, i); });
      }
      const apex = (k) => k - 1 <= apexTop;
      if (process.env.MC_DEBUG === String(s.id)) {
        console.log(`[${s.id} ${mode}] ${best.source} n=${best.sample} hero=${dec.subTree} ${heroName}`);
        console.log('  taken:', [...taken].join(' '));
      }
      // Set bonus measured: four or more slots whose top item is a set piece.
      let setPieces = 0;
      // Armour slots only: the trinkets of a raid carry "set" too, and
      // counted, the four-piece bonus was assumed too easily (21 October).
      const SET_SLOTS = new Set(['Head', 'Shoulders', 'Chest', 'Hands', 'Legs', 'Back', 'Wrist', 'Waist', 'Feet']);
      for (const [slot, items] of Object.entries(best.entry.gear || {})) {
        if (!SET_SLOTS.has(slot)) continue;
        const first = list(items)[0];
        if (first && (first.kind === 'set' || setItems.has(first.id))) setPieces += 1;
      }
      // The weapon most measured players carry, by kind (SimC: main_hand.dagger).
      const waffe = (slot) => {
        const key = slot === 'main_hand' ? 'Main Hand' : 'Off Hand';
        const first = list((best.entry.gear || {})[key])[0];
        return first ? itemKind.get(first.id) : undefined;
      };
      const setBonus = (name) => {
        const mm = name.match(/^([a-z]+\d+)_(\d)pc$/);
        if (!mm || mm[1] !== current) return false;
        return setPieces >= Number(mm[2]);
      };
      const known = (id) => takenIds.has(id) || taken.has(bare(slug(nameEN.get(id))));
      // The measurement of this spec and activity, by spell NAME: the part of
      // the players who cast it at all, and how often per minute.
      const gemessen = castsBy[mode] && castsBy[mode].get(s.id);
      const proName = new Map();
      if (gemessen && gemessen.players >= MIN_MEASURED) {
        for (const [g, [n, wer]] of gemessen.by) {
          const k = slug(nameEN.get(g));
          if (!k) continue;
          const a = proName.get(k) || { share: 0, cpm: 0 };
          // Two IDs of one spell: the larger share, the casts added up.
          a.share = Math.max(a.share, Math.min(1, wer / gemessen.players));
          a.cpm += n / Math.max(1, gemessen.minutes);
          proName.set(k, a);
        }
      }
      const share = proName.size ? (name) => (proName.get(name) || { share: 0 }).share : null;
      const replacedNames = namesReplaced(replacements, {
        specID: s.id, known, nameOf: (id) => slug(nameEN.get(id)), share,
      });
      if (process.env.MC_DEBUG === String(s.id)) console.log('  ersetzt:', [...replacedNames].join(' '));
      // MC_REPLACED=1: which of the list's own actions a replacement removes.
      if (process.env.MC_REPLACED) {
        const acts = new Set(Object.values(lists).flat().map((x) => x.action));
        const weg = [...replacedNames].filter((n) => acts.has(n));
        for (const [old, list] of replacements) {
          const n = slug(nameEN.get(old));
          if (!weg.includes(n)) continue;
          for (const r of list) {
            const has = r.spec !== undefined ? r.spec === s.id : known(r.neu);
            if (has && slug(nameEN.get(r.neu)) !== n) console.log(`  ${s.id} ${mode}: ${n} (${old}) <- ${slug(nameEN.get(r.neu))} (${r.neu}) [${r.from}]`);
          }
        }
      }
      // SimC's short names for "whichever of the two the build takes".
      const ALIAS = {
        bs_inc: ['incarnation_avatar_of_ashamane', 'berserk'],
        ca_inc: ['incarnation_chosen_of_elune', 'celestial_alignment'],
      };
      // The spec's own version of a spell is what its list means by the name:
      // the Devourer's Metamorphosis is Void Metamorphosis.
      const specVersion = new Map();
      for (const [old, list] of replacements) {
        for (const r of list) if (r.spec === s.id) specVersion.set(slug(nameEN.get(old)), r.neu);
      }
      const spellM = (k) => {
        const alias = ALIAS[k];
        if (alias) return spell(alias.find((x) => taken.has(bare(x))) || alias[alias.length - 1]);
        const plain = k.replace(/_(self|buff|debuff|dot)$/, '');
        if (specVersion.has(k)) return specVersion.get(k);
        if (specVersion.has(plain)) return specVersion.get(plain);
        return spell(k) || spell(plain) || spell(plain.replace(/_(cat|bear)$/, '')) || spell(plain.replace(/s$/, ''));
      };
      // The IDs the measured players actually cast win for actions.
      const castIds = new Set(gemessen ? [...gemessen.by.keys()] : []);
      const resolve = {
        spell: spellM, actionSpell: (k) => actionSpellFor(k, castIds),
        isTalentSpell: (k) => treeSpells.has(bare(k)),
        talent: (k) => taken.has(bare(k)),
        // By NAME: the list's Flame Shock may be another ID of the same spell
        // than the one Voltaic Blaze names. A replacement by a spell of the
        // same name (a spec's own version) is no replacement.
        replaced: (id) => replacedNames.has(slug(nameEN.get(id))),
        latch: latchOf,
      };
      const ctx = (targets, trinket) => {
        const c = {
          trinket,
          talent: (k) => taken.has(bare(k)),
          isTalentSpell: (k) => treeSpells.has(bare(k)),
          hero: (k) => bare(k) === bare(heroName),
          // SimC's names: a dungeon pull for M+, a boss for the raid.
          fightStyle: mode === 'mplus' ? 'dungeonslice' : 'patchwerk',
          setBonus, targets, apex,
          cpMax: 5 + ['deeper_stratagem', 'sanguine_stratagem', 'devious_stratagem', 'secret_stratagem']
            .filter((t) => taken.has(bare(t))).length,
          cdOf: (k) => {
            for (const id of [actionSpellFor(k, castIds), spellM(k), ...racialIds(k), ...kandidaten(k)]) {
              if (id && cdSeconds.get(id)) return cdSeconds.get(id);
            }
            return undefined;
          },
          stacksOf: (k) => { const id = spellM(k); return id ? maxStacks.get(id) : undefined; },
          durOf: (k) => {
            for (const id of [spellM(k), ...kandidaten(k)]) {
              const ms = id ? lastsMs.get(id) : 0;
              if (ms > 0) return ms / 1000;
            }
            return undefined;
          },
          costOf: (k) => {
            for (const id of [actionSpellFor(k, castIds), ...kandidaten(k)]) if (id && costs.has(id)) return costs.get(id);
            return undefined;
          },
          weapon: (slot, kind) => {
            const w = waffe(slot);
            if (!w) return null;
            return kind === 'dagger' ? w.sub === 15 : null;
          },
          isLatch: (name) => latchShape(name) !== null,
        };
        c.variable = (name) => variableIn(name, c);
        return c;
      };
      const start = lists.default ? 'default' : Object.keys(lists)[0];
      const st = apl.buildTab(lists, start, ctx([1, 1]), resolve);
      const aoe = apl.buildTab(lists, start, ctx([3, 8]), resolve);
      const pre = apl.buildTab(lists, 'precombat', ctx([1, 1]), resolve);
      // TRAENKE & SCHMUCK. Der Trank: welcher gemessen wird und wann die Liste
      // ihn trinkt. Der Schmuck: zweimal gerechnet, mit einem gedachten
      // Buff-Schmuck und einem Schadens-Schmuck im ersten Platz - welcher es
      // ist, entscheidet die Ausruestung. Volksfaehigkeiten je Rasse; das
      // Addon zeigt nur die eigene.
      const mitBuff = apl.buildTab(lists, start, ctx([1, 1], { buff: true, cd: 120 }), resolve);
      const mitSchaden = apl.buildTab(lists, start, ctx([1, 1], { buff: false, cd: 90 }), resolve);
      const erste = (r, kind) => r.items.find((x) => x.kind === kind);
      const trank = list(best.entry.consumables).find((x) => x && x.kind === 'potion');
      const trankZeile = erste(st, 'potion');
      const items = {};
      if (trankZeile || erste(pre, 'potion')) {
        items.potion = {
          item: trank ? trank.id : undefined,
          pct: trank ? trank.pct : undefined,
          pre: erste(pre, 'potion') ? true : undefined,
          c: trankZeile && trankZeile.c.length ? trankZeile.c : undefined,
          at: trankZeile ? undefined : 'pre',
        };
      }
      const buffZeile = erste(mitBuff, 'trinket');
      if (buffZeile) items.buff = { c: buffZeile.c.length ? buffZeile.c : undefined };
      const schadenZeile = erste(mitSchaden, 'trinket');
      if (schadenZeile) items.dmg = { c: schadenZeile.c.length ? schadenZeile.c : undefined };
      const volk = st.items.filter((x) => x.kind === 'racial')
        // Every variant of the racial for this class (Blood Fury has three);
        // the addon shows the one the character knows.
        .map((x) => ({ s: racialIds(x.action), c: x.c.length ? x.c : undefined }))
        .filter((x) => x.s.length);
      if (volk.length) items.racial = volk;
      // Nichts uebrig: der Build passt nicht zur Liste (beim Braumeister liest
      // sich der String noch nicht sauber). Dann lieber keine Rotation.
      if (st.lines.length === 0 && aoe.lines.length === 0) {
        report.push(`${s.id} ${file} ${mode} hero ${subTree}: empty, skipped`);
        continue;
      }
      // EVERY LINE AGAINST THE LOGS: a spell hardly any measured player
      // casts is not played, and its line goes - whatever the simulation
      // says. Before the pull and while moving are not checked: the first
      // happens before the fight, the second rarely.
      const ungespielt = [];
      if (share) {
        for (const tab of [st, aoe]) {
          tab.lines = tab.lines.filter((l) => {
            const k = slug(nameEN.get(l.s));
            if (share(k) >= PLAYED_FROM) return true;
            ungespielt.push(k);
            return false;
          });
        }
      }
      // AS A GUIDE WRITES IT (tools/lib/simplify.js): only what a player checks,
      // nothing vague, at most three conditions, nothing pointless.
      // MC_RAW=1 keeps the full translation, to compare.
      if (!process.env.MC_RAW) {
        // Trinkets, potion, racials: the same plain words.
        const klar = (x) => { if (x && x.c) x.c = simpleConditions(x.c, { nameOf: (id) => nameEN.get(id) || String(id) }); };
        klar(items.potion);
        klar(items.buff);
        klar(items.dmg);
        (items.racial || []).forEach(klar);
        const cdOf = ctx([1, 1]).cdOf;
        const einfach = {
          // A cooldown of 20 seconds or more stays "on cooldown" rather than vanish.
          isCooldown: (id) => {
            const k = slug(nameEN.get(id));
            const recharge = Math.max(0, ...[id, ...kandidaten(k)].map((x) => rechargeSeconds.get(x) || 0));
            return Math.max(cdOf(k) || 0, recharge) >= 20;
          },
          nameOf: (id) => nameEN.get(id) || String(id),
        };
        st.lines = simplify(st.lines, einfach);
        aoe.lines = simplify(aoe.lines, einfach);
      }
      const miss = new Set([...st.miss, ...aoe.miss, ...pre.miss]);
      const keep = [...new Set([...st.keep, ...aoe.keep, ...pre.keep])];
      const preLines = pre.lines.filter((l) => !keep.includes(l.s));
      // Each line carries its measurement: percent of players, casts per minute.
      const messung = (id) => {
        const m = proName.get(slug(nameEN.get(id)));
        return m ? [Math.round(m.share * 100), Math.round(m.cpm * 10) / 10] : undefined;
      };
      const pack = (lines) => lines.map((l) => ({ s: l.s, c: l.c.length ? l.c : undefined, any: l.any,
        t: l.t || undefined, m: messung(l.s), more: l.more || undefined }));
      // The typical opener: the logs' spells mapped onto this class's own
      // (potions, trinkets and racials fall out - they are not its spells),
      // then the order most players follow. Raid only: see lib/opener.js.
      let measured;
      // The openers are not split by hero tree: they belong to the most played.
      const seqs = mode === 'raid' && v === tragend[0] ? (openersBySpec.get(s.id) || []) : [];
      if (seqs.length) {
        const own = (id) => {
          const k = slug(nameEN.get(Number(id)));
          return k && byName.has(k) && !apl.NOISE.has(k) ? byName.get(k)[0] : null;
        };
        // What the list casts before combat: a cast of it at the pull is
        // the precast (see lib/opener.js).
        const beforeCombat = new Set([...keep, ...preLines.map((l) => l.s)]);
        const mapped = seqs.map((q) => opener.placePull({
          pre: q.pre.map(own).filter(Boolean),
          pull: (q.pull || []).map(own).filter(Boolean),
          post: q.post.map(own).filter(Boolean),
        }, beforeCombat));
        const post = opener.typical(mapped.map((q) => q.post), { max: opener.MAX_POST });
        const preSeq = opener.typical(mapped.map((q) => q.pre), { fromEnd: true, max: opener.MAX_PRE });
        if (post.length >= 2) measured = { n: seqs.length, pre: preSeq, post };
      }
      ergebnisse.push({
        opener: measured,
        hero: dec.subTree || undefined,
        pct: v.pct || undefined,
        set: setPieces >= 4 && current && text.includes('set_bonus.' + current) ? current : undefined,
        n: v.players || best.sample || undefined,
        src: best.source,
        pre: pack(preLines),
        keep: keep.length ? keep : undefined,
        st: pack(st.lines),
        aoe: pack(aoe.lines),
        mv: [...new Set([...st.moving, ...aoe.moving])],
        items: Object.keys(items).length ? items : undefined,
        cast: gemessen && gemessen.players >= MIN_MEASURED ? gemessen.players : undefined,
      });
      const others = [...st.lines, ...aoe.lines].filter((l) => l.more || l.c.some(apl.isOther)).length;
      report.push(`${s.id} ${file} ${mode} hero ${dec.subTree}: st ${st.lines.length}, aoe ${aoe.lines.length}, pre ${preLines.length}`
        + `, vague ${others}${measured ? `, opener ${measured.pre.length}|${measured.post.length} of ${measured.n}` : ''}`
        + `${miss.size ? ', unknown: ' + [...miss].join(' ') : ''}`
        + `${gemessen ? `, measured ${gemessen.players}` : ', not measured'}`
        + `${ungespielt.length ? ', not played: ' + [...new Set(ungespielt)].join(' ') : ''}`);
      }
      if (!ergebnisse.length) continue;
      // The most played on top (as before), every tree in heroes.
      (out[s.id] = out[s.id] || {})[mode] = {
        ...ergebnisse[0],
        heroes: ergebnisse.length > 1 ? ergebnisse.map((r) => ({ ...r, src: undefined, cast: undefined })) : undefined,
      };
    }
   } catch (err) {
    delete out[s.id];
    report.push(`${s.id}: FAILED, left out - ${String(err && err.stack || err).split('\n').slice(0, 2).join(' ')}`);
   }
  }
  console.log(report.join('\n'));
  if (vague) {
    console.log('\nVage Bedingungen (je Ausdruck, ueber alle Speccs):');
    for (const [k, n] of [...vague].sort((x, y) => y[1] - x[1]).slice(0, 80)) console.log(String(n).padStart(5), k);
  }

  const stamp = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  const lines = [
    '',
    '-- ERZEUGT von tools/build-rotation.js. Nicht von Hand aendern.',
    '-- Die Rotation: SimulationCraft (GPL-3.0), gefaltet mit dem gemessenen Build.',
    'MetaCodex_Recommendations = MetaCodex_Recommendations or {}',
    'MetaCodex_Recommendations.rotation = {',
    `  builtOn = ${stamp},`,
    '  specs = {',
  ];
  for (const id of Object.keys(out).sort((a, b) => a - b)) {
    lines.push(`    [${id}] = {`);
    for (const [mode, v] of Object.entries(out[id])) lines.push(`      [${JSON.stringify(mode)}] = ${luaValue(v)},`);
    lines.push('    },');
  }
  lines.push('  },', '}', '');
  const fragment = lines.join('\n');
  const target = path.join(BASE, 'tools', 'data', 'rotation.lua');
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, fragment, 'utf8');
  console.log('Geschrieben:', target, `(${Object.keys(out).length} Speccs, ${Math.round(fragment.length / 1024)} KB)`);
  // EVERY KIND OF CONDITION the addon can put into words (Core/UI.lua, and
  // Tests/smoke_test.lua checks each of them). A kind not in this list would
  // read "under certain conditions" in the game - so it is left out here.
  const KINDS = new Set(['and', 'or', 'up', 'down', 'refresh', 'ready', 'notready', 'cdsoon', 'prev', 'notprev',
    'casting', 'notcasting', 'flying', 'notflying', 'stronger', 'notstronger', 'weakdot', 'strongdot', 'placed',
    'notplaced', 'stealthed', 'notstealthed', 'cdunder', 'cdover', 'stackmin', 'stackunder', 'stackis', 'remunder',
    'remover', 'chargesunder', 'chargesfull', 'doton', 'charges', 'tgtis', 'tgtmin', 'tgtmax', 'hpunder', 'hpover',
    'timeunder', 'timeover', 'resnotcap', 'resfull', 'resenough', 'resmin', 'resunder', 'resis', 'respctmin',
    'respctunder', 'ago', 'castleft', 'castdone', 'myhpunder', 'myhpover', 'surge', 'nosurge', 'notyet', 'already',
    'since', 'notsince', 'cmp', 'multunder', 'charged', 'notcharged']);
  const fremd = new Set();
  const pruefe = (c) => {
    if (!Array.isArray(c)) return;
    if (!KINDS.has(c[0])) fremd.add(c[0]);
    if (c[0] === 'and' || c[0] === 'or' || c[0] === 'notyet' || c[0] === 'already') c.slice(1).forEach(pruefe);
    if (c[0] === 'since' || c[0] === 'notsince') c.slice(1).forEach(pruefe);
  };
  for (const modes of Object.values(out)) {
    for (const r of Object.values(modes)) {
      for (const v of [r, ...(r.heroes || [])]) {
        for (const tab of ['st', 'aoe', 'pre']) {
          for (const l of v[tab] || []) { (l.c || []).forEach(pruefe); (l.any || []).flat().forEach(pruefe); }
        }
      }
    }
  }
  if (fremd.size) console.log('WARNUNG: Satzarten ohne Vorlage im Addon:', [...fremd].join(', '));
  // A spell and its sure replacement in one list: never (lib/replace.js).
  const nebeneinander = new Set();
  for (const [specId, modes] of Object.entries(out)) {
    for (const [mode, r] of Object.entries(modes)) {
      for (const v of r.heroes || [r]) {
        const da = new Set(['st', 'aoe', 'pre'].flatMap((tab) => (v[tab] || []).map((l) => slug(nameEN.get(l.s)))));
        for (const id of v.keep || []) da.add(slug(nameEN.get(id)));
        for (const [old, list] of replacements) {
          const alt = slug(nameEN.get(old));
          if (!alt || !da.has(alt)) continue;
          for (const x of list) {
            const neu = slug(nameEN.get(x.neu));
            if (x.proc || neu === alt || !da.has(neu) || (x.spec !== undefined && x.spec !== Number(specId))) continue;
            nebeneinander.add(`${specId} ${mode} ${v.hero || ''}: ${alt} + ${neu}`);
          }
        }
      }
    }
  }
  if (nebeneinander.size) console.log('WARNUNG: Zauber neben seinem Ersatz:', [...nebeneinander].join('; '));

  // SELF-CHECK before it touches the game data: the fragment must read back
  // as the table it was written from. If not, nothing is appended - the
  // night ships without a rotation rather than with a broken data file.
  const body = fragment.slice(fragment.indexOf('MetaCodex_Recommendations.rotation = {'));
  const back = readLuaTable(body);
  const ids = Object.keys((back && back.specs) || {});
  if (ids.length !== Object.keys(out).length || /\b(Infinity|NaN|undefined)\b/.test(fragment)) {
    console.error(`Selbstpruefung fehlgeschlagen: ${ids.length} von ${Object.keys(out).length} Speccs gelesen - nichts angehaengt`);
    process.exit(1);
  }
  if (APPEND) {
    fs.appendFileSync(REC, fragment, 'utf8');
    console.log('Angehaengt an', REC);
  }
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
