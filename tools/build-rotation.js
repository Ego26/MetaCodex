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
  if (typeof v === 'boolean' || typeof v === 'number') return String(v);
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
  const [spellNames, specSpells, skillLines, chrSpecs, overrides] = await Promise.all([
    db2('SpellName'), db2('SpecializationSpells'), db2('SkillLineAbility'), db2('ChrSpecialization'),
    db2('SpellEffect', '&filter%5BEffectAura%5D=332'),
  ]);
  const nameEN = new Map(spellNames.map((r) => [Number(r.ID), r.Name_lang]));
  const globalByName = new Map();
  for (const [id, n] of nameEN) {
    const k = slug(n);
    if (!globalByName.has(k) || globalByName.get(k) < id) globalByName.set(k, id);
  }
  // SimC drops the hyphen ("dance_of_chiji"), the slug keeps it as an
  // underscore ("dance_of_chi_ji"): a second index without either.
  const globalByBare = new Map();
  for (const [id, n] of nameEN) {
    const k = slug(n).replace(/_/g, '');
    if (k && (!globalByBare.has(k) || globalByBare.get(k) < id)) globalByBare.set(k, id);
  }
  // Replacements: the spell in EffectMiscValue_0 is replaced by the one in
  // EffectBasePoints while the aura holds.
  const replacedBy = new Map();
  for (const r of overrides) {
    const neu = Math.round(Number(r.EffectBasePointsF) || 0);
    const alt = Number(r.EffectMiscValue_0) || 0;
    if (neu > 0 && alt > 0) {
      if (!replacedBy.has(alt)) replacedBy.set(alt, new Set());
      replacedBy.get(alt).add(neu);
    }
  }

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

  for (const s of catSpecs.filter((x) => texts.has(x.id))) {
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
    const byBare = new Map();
    for (const [k, ids] of byName) if (!byBare.has(k.replace(/_/g, ''))) byBare.set(k.replace(/_/g, ''), ids[0]);
    const spell = (k) => (byName.get(k) || [])[0] || byBare.get(k.replace(/_/g, ''))
      || globalByName.get(k) || globalByName.get(k.replace(/_(tier|buff|debuff|proc)$/, ''))
      || globalByBare.get(k.replace(/_/g, '')) || null;
    // SimC's own names for a form-bound or merged action.
    const ALIAS = { any_dnd: 'death_and_decay' };
    // Racials: the rows of the class lines' table that carry a race mask.
    const racialIds = (k) => [...new Set(skillLines
      .filter((r) => Number(r.RaceMasks_0 || 0) !== 0 && slug(nameEN.get(Number(r.Spell))) === k
        && (Number(r.ClassMask || 0) === 0 || (Number(r.ClassMask) & classBit)))
      .map((r) => Number(r.Spell)))].sort((x, y) => x - y);
    const actionSpell = (k) => {
      const name = ALIAS[k] || k;
      const plain = name.replace(/_(cat|bear)$/, '');
      return (byName.get(name) || byName.get(plain) || [])[0] || globalByName.get(name) || globalByName.get(plain) || null;
    };

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
    const resolving = new Set();
    const variableIn = (name, c) => {
      const d = defs.get(name);
      if (!d || resolving.has(name)) return null;
      resolving.add(name);
      try {
        const folds = (text) => apl.fold(apl.parse(text), c);
        const live = d.filter((o) => {
          if (!o.if) return true;
          const r = folds(o.if);
          return !(r.lo === 0 && r.hi === 0);
        });
        if (!live.length) return { num: 0 };
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
        const values = live.map(valueOf);
        if (values.some((v) => v === null) || new Set(values).size !== 1) return null;
        const v = values[0];
        if (v.startsWith('?:')) {
          const [cond, yes, no] = v.slice(2).split('\u0000');
          return { op: '?:', c: apl.parse(cond), a: apl.parse(yes), b: apl.parse(no) };
        }
        return apl.parse(v);
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
      let takenIds, subTree;
      if (best.text) {
        const dec = loadout.decode(BASE, best.text, treeId);
        if (!dec) continue;
        subTree = dec.subTree;
        // Only the chosen hero tree: the string marks the other keystone as
        // granted too.
        takenIds = new Set(dec.nodes.filter((n) => !nodeSub.get(n.node) || nodeSub.get(n.node) === dec.subTree)
          .map((n) => n.spell));
      } else {
        // The list names what was picked, not what the spec gets for free
        // (Lava Burst for Elemental). Those come from any string of the spec.
        takenIds = new Set([...best.nodes.map((n) => n.spell), ...grantedOf(s.id)]);
        // The hero tree: the one most of these players take.
        let top = null;
        for (const [id, h] of Object.entries(best.entry.hero || {})) {
          if (!top || (h.players || 0) > top.players) top = { id: Number(id), players: h.players || 0 };
        }
        subTree = top ? top.id : null;
      }
      const taken = new Set([...takenIds].map((id) => bare(slug(nameEN.get(id)))));
      const heroName = subTree && map.subTrees[subTree] ? slug(map.subTrees[subTree].en) : '';
      const dec = { subTree };
      if (process.env.MC_DEBUG === String(s.id)) {
        console.log(`[${s.id} ${mode}] ${best.source} n=${best.sample} hero=${dec.subTree} ${heroName}`);
        console.log('  taken:', [...taken].join(' '));
      }
      // Set bonus measured: four or more slots whose top item is a set piece.
      let setPieces = 0;
      for (const items of Object.values(best.entry.gear || {})) {
        const first = list(items)[0];
        if (first && (first.kind === 'set' || setItems.has(first.id))) setPieces += 1;
      }
      const setBonus = (name) => {
        const mm = name.match(/^([a-z]+\d+)_(\d)pc$/);
        if (!mm || mm[1] !== current) return false;
        return setPieces >= Number(mm[2]);
      };
      const known = (id) => takenIds.has(id) || taken.has(bare(slug(nameEN.get(id))));
      // SimC's short names for "whichever of the two the build takes".
      const ALIAS = {
        bs_inc: ['incarnation_avatar_of_ashamane', 'berserk'],
        ca_inc: ['incarnation_chosen_of_elune', 'celestial_alignment'],
      };
      const spellM = (k) => {
        const alias = ALIAS[k];
        if (alias) return spell(alias.find((x) => taken.has(bare(x))) || alias[alias.length - 1]);
        return spell(k) || spell(k.replace(/_(self|buff|debuff|dot)$/, ''));
      };
      const resolve = {
        spell: spellM, actionSpell,
        isTalentSpell: (k) => treeSpells.has(bare(k)),
        talent: (k) => taken.has(bare(k)),
        replaced: (id) => [...(replacedBy.get(id) || [])].some(known),
      };
      const ctx = (targets, trinket) => {
        const c = {
          trinket,
          talent: (k) => taken.has(bare(k)),
          isTalentSpell: (k) => treeSpells.has(bare(k)),
          hero: (k) => bare(k) === bare(heroName),
          // SimC's names: a dungeon pull for M+, a boss for the raid.
          fightStyle: mode === 'mplus' ? 'dungeonslice' : 'patchwerk',
          setBonus, targets,
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
        report.push(`${s.id} ${file} ${mode}: empty, skipped`);
        continue;
      }
      const miss = new Set([...st.miss, ...aoe.miss, ...pre.miss]);
      const keep = [...new Set([...st.keep, ...aoe.keep, ...pre.keep])];
      const preLines = pre.lines.filter((l) => !keep.includes(l.s));
      const pack = (lines) => lines.map((l) => ({ s: l.s, c: l.c.length ? l.c : undefined, any: l.any, t: l.t || undefined }));
      // The typical opener: the logs' spells mapped onto this class's own
      // (potions, trinkets and racials fall out - they are not its spells),
      // then the order most players follow. Raid only: see lib/opener.js.
      let measured;
      const seqs = mode === 'raid' ? (openersBySpec.get(s.id) || []) : [];
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
      (out[s.id] = out[s.id] || {})[mode] = {
        opener: measured,
        hero: dec.subTree || undefined,
        set: setPieces >= 4 && current && text.includes('set_bonus.' + current) ? current : undefined,
        n: best.sample || undefined,
        src: best.source,
        pre: pack(preLines),
        keep: keep.length ? keep : undefined,
        st: pack(st.lines),
        aoe: pack(aoe.lines),
        mv: [...new Set([...st.moving, ...aoe.moving])],
        items: Object.keys(items).length ? items : undefined,
      };
      const others = [...st.lines, ...aoe.lines].filter((l) => l.c.some(apl.isOther)).length;
      report.push(`${s.id} ${file} ${mode}: st ${st.lines.length}, aoe ${aoe.lines.length}, pre ${preLines.length}`
        + `, vague ${others}${measured ? `, opener ${measured.pre.length}|${measured.post.length} of ${measured.n}` : ''}`
        + `${miss.size ? ', unknown: ' + [...miss].join(' ') : ''}`);
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
  if (APPEND) {
    fs.appendFileSync(REC, fragment, 'utf8');
    console.log('Angehaengt an', REC);
  }
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
