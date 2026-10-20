// Reads a SimulationCraft action priority list (APL) and turns it into a
// priority list a player can read.
//
// The APL is code for a simulator: every line is "cast X if Y", and Y
// asks about talents, buffs, cooldowns and resources. What a player needs
// is the same order with the conditions in words. Three steps:
//
//   1. Parse every condition into a tree.
//   2. Fold it against what is KNOWN: the talents of the measured build,
//      the chosen hero tree, the target count of the tab. A line for a
//      talent the build does not take disappears; a condition that is
//      always true disappears from the line. Every value carries a range
//      [lo, hi], so "buff stacks + 1 >= 1" folds too.
//   3. Write what is left as small condition records ({ "up", spell }).
//      The addon puts them into words, in the language of the client.
//
// What cannot be said honestly becomes { "other" } - "under certain
// conditions" - never a guess.

const INF = Infinity;

// ------------------------------------------------------------------ parse

function tokenize(s) {
  const out = [];
  const re = /\s*(>=|<=|!=|>\?|<\?|[()!&|=<>+\-*%/@]|[0-9]+(?:\.[0-9]+)?|[a-zA-Z_][a-zA-Z0-9_.]*)/gy;
  let m;
  while ((m = re.exec(s)) && m[0]) out.push(m[1]);
  return out;
}

/** Parses a SimC expression into a tree of { op, a, b } / { atom } / { num }. */
function parse(s) {
  const t = tokenize(s);
  let i = 0;
  const peek = () => t[i];
  const next = () => t[i++];
  const BIN = [['|'], ['&'], ['=', '!=', '<', '>', '<=', '>='], ['+', '-'], ['*', '%', '/', '>?', '<?']];
  function level(l) {
    if (l === BIN.length) return unary();
    let left = level(l + 1);
    while (BIN[l].includes(peek())) {
      const op = next();
      left = { op, a: left, b: level(l + 1) };
    }
    return left;
  }
  function unary() {
    const tok = peek();
    if (tok === '!') { next(); return { op: '!', a: unary() }; }
    if (tok === '-') { next(); return { op: 'neg', a: unary() }; }
    if (tok === '@') { next(); return { op: 'abs', a: unary() }; }
    if (tok === '(') { next(); const e = level(0); if (peek() === ')') next(); return e; }
    next();
    if (tok === undefined) return { num: 0 };
    if (/^[0-9]/.test(tok)) return { num: Number(tok) };
    return { atom: tok };
  }
  return level(0);
}

/** Splits an APL file into lists of { action, opts }. */
function parseApl(text) {
  const lists = {};
  for (const raw of text.split('\n')) {
    const m = raw.trim().match(/^actions(?:\.([a-zA-Z0-9_]+))?\+?=\/?(.*)$/);
    if (!m) continue;
    const list = m[1] || 'default';
    // Commas inside an expression are not separators, but SimC never
    // writes one there; options are name=value pairs.
    const [action, ...rest] = m[2].split(',');
    const opts = {};
    for (const x of rest) {
      const i = x.indexOf('=');
      if (i > 0) opts[x.slice(0, i)] = x.slice(i + 1);
    }
    (lists[list] = lists[list] || []).push({ action: action.trim(), opts });
  }
  return lists;
}

// ------------------------------------------------------------------ fold

const RESOURCES = new Set(['maelstrom', 'energy', 'rage', 'focus', 'runic_power', 'insanity', 'fury',
  'astral_power', 'lunar_power', 'combo_points', 'holy_power', 'soul_shard', 'soul_shards', 'chi',
  'essence', 'mana', 'rune', 'runes', 'pain']);
const RES_MAX = { combo_points: 7, holy_power: 5, soul_shard: 5, soul_shards: 5, chi: 6, essence: 6, rune: 6, runes: 6 };

const known = (v) => ({ num: v, lo: v, hi: v });
const isTrue = (x) => x.lo > 0 || x.hi < 0;
const isFalse = (x) => x.lo === 0 && x.hi === 0;
const clean = (v, d) => (Number.isNaN(v) ? d : v);

/**
 * ctx: {
 *   talent(slug) -> bool, hero(slug) -> bool, setBonus(name) -> bool,
 *   targets: [lo, hi], variable(name) -> tree|null, spellKnown(slug) -> bool
 * }
 */
function atomRange(a, ctx) {
  const p = a.split('.');
  const head = p[0];
  if (head === 'talent') return ctx.talent(p[1]) ? [1, 1] : [0, 0];
  if (head === 'hero_tree') return ctx.hero(p[1]) ? [1, 1] : [0, 0];
  if (head === 'set_bonus') return ctx.setBonus(p.slice(1).join('.')) ? [1, 1] : [0, 0];
  // The end of a fight, the time to die, raid events: none in the tab.
  if (a === 'fight_remains' || a === 'target.time_to_die' || a === 'time_to_die' || a === 'target.fight_remains'
    || a === 'expected_combat_length') return [INF, INF];
  if (head === 'raid_event') {
    if (/\.in$|\.cooldown$/.test(a)) return [INF, INF];
    return [0, 0];
  }
  if (a === 'active_enemies' || head === 'spell_targets' || a === 'desired_targets') return ctx.targets;
  if (head === 'active_dot') return [0, ctx.targets[1]];
  if (head === 'buff' || head === 'debuff' || head === 'dot') {
    // The buff of a talent not taken never comes up.
    if (ctx.isTalentSpell(p[1]) && !ctx.talent(p[1])) return [0, 0];
    if (p[2] === 'react') return [0, INF];
    if (['up', 'down', 'refreshable', 'ticking'].includes(p[2])) return [0, 1];
    return [0, INF];
  }
  if (head === 'cooldown') {
    if (ctx.isTalentSpell(p[1]) && !ctx.talent(p[1])) {
      if (p[2] === 'ready' || p[2] === 'up') return [0, 0];
    }
    if (p[2] === 'ready' || p[2] === 'up') return [0, 1];
    return [0, INF];
  }
  if (head === 'variable') {
    const tree = ctx.variable(p[1]);
    if (tree) return null; // inlined by fold
    return [-INF, INF];
  }
  if (RESOURCES.has(head)) {
    if (p[1] === 'pct') return [0, 100];
    const max = RES_MAX[head] || 150;
    return [0, max];
  }
  if (a === 'gcd' || a === 'gcd.max' || a === 'gcd.remains') return [0, 2];
  if (a === 'time') return [0, INF];
  if (head === 'target' && p[1] === 'health') return [0, 100];
  return [0, INF];
}

function fold(e, ctx, depth = 0) {
  if (depth > 40) return { atom: '?', lo: -INF, hi: INF };
  if (e.num !== undefined) return known(e.num);
  if (e.atom) {
    if (e.atom.startsWith('variable.')) {
      const tree = ctx.variable(e.atom.slice(9));
      if (tree) return fold(tree, ctx, depth + 1);
    }
    const r = atomRange(e.atom, ctx) || [-INF, INF];
    if (r[0] === r[1]) return known(r[0]);
    return { atom: e.atom, lo: r[0], hi: r[1] };
  }
  if (e.op === '!') {
    const a = fold(e.a, ctx, depth + 1);
    if (isFalse(a)) return known(1);
    if (isTrue(a)) return known(0);
    return { op: '!', a, lo: 0, hi: 1 };
  }
  if (e.op === 'neg') {
    const a = fold(e.a, ctx, depth + 1);
    if (a.lo === a.hi) return known(-a.lo);
    return { op: 'neg', a, lo: -a.hi, hi: -a.lo };
  }
  if (e.op === 'abs') {
    const a = fold(e.a, ctx, depth + 1);
    if (a.lo === a.hi) return known(Math.abs(a.lo));
    return { op: 'abs', a, lo: 0, hi: Math.max(Math.abs(a.lo), Math.abs(a.hi)) };
  }
  const a = fold(e.a, ctx, depth + 1);
  const b = fold(e.b, ctx, depth + 1);
  if (e.op === '&') {
    if (isFalse(a) || isFalse(b)) return known(0);
    if (isTrue(a) && isTrue(b)) return known(1);
    if (isTrue(a)) return b;
    if (isTrue(b)) return a;
    return { op: '&', a, b, lo: 0, hi: 1 };
  }
  if (e.op === '|') {
    if (isTrue(a) || isTrue(b)) return known(1);
    if (isFalse(a) && isFalse(b)) return known(0);
    if (isFalse(a)) return b;
    if (isFalse(b)) return a;
    return { op: '|', a, b, lo: 0, hi: 1 };
  }
  if (['=', '!=', '<', '>', '<=', '>='].includes(e.op)) {
    let yes = false, no = false;
    switch (e.op) {
      case '<': yes = a.hi < b.lo; no = a.lo >= b.hi; break;
      case '>': yes = a.lo > b.hi; no = a.hi <= b.lo; break;
      case '<=': yes = a.hi <= b.lo; no = a.lo > b.hi; break;
      case '>=': yes = a.lo >= b.hi; no = a.hi < b.lo; break;
      case '=': yes = a.lo === a.hi && b.lo === b.hi && a.lo === b.lo; no = a.hi < b.lo || a.lo > b.hi; break;
      case '!=': no = a.lo === a.hi && b.lo === b.hi && a.lo === b.lo; yes = a.hi < b.lo || a.lo > b.hi; break;
      default: break;
    }
    if (yes) return known(1);
    if (no) return known(0);
    return { op: e.op, a, b, lo: 0, hi: 1 };
  }
  const calc = (x, y) => {
    switch (e.op) {
      case '+': return x + y;
      case '-': return x - y;
      case '*': return (x === 0 || y === 0) ? 0 : x * y;
      case '%': case '/': return y ? x / y : 0;
      case '>?': return Math.max(x, y);
      case '<?': return Math.min(x, y);
      default: return 0;
    }
  };
  if (a.lo === a.hi && b.lo === b.hi) return known(clean(calc(a.lo, b.lo), 0));
  let lo, hi;
  if (e.op === '-') { lo = a.lo - b.hi; hi = a.hi - b.lo; }
  else if (e.op === '/' || e.op === '%') { lo = -INF; hi = INF; if (b.lo > 0 && a.lo >= 0) { lo = 0; } }
  else {
    const c = [calc(a.lo, b.lo), calc(a.lo, b.hi), calc(a.hi, b.lo), calc(a.hi, b.hi)].map((x) => clean(x, 0));
    lo = Math.min(...c); hi = Math.max(...c);
  }
  return { op: e.op, a, b, lo: clean(lo, -INF), hi: clean(hi, INF) };
}

// ------------------------------------------------------------------ write

const round = (n) => Math.round(n * 10) / 10;
const numOf = (e) => (e && e.lo === e.hi && Number.isFinite(e.lo) ? round(e.lo) : null);
const hasAtom = (e, pred) => !!e && ((e.atom && pred(e.atom)) || hasAtom(e.a, pred) || hasAtom(e.b, pred));

/**
 * Turns a folded condition into records. spell(slug) -> id|null.
 * Records: [kind, ...args]; "or"/"and" nest.
 */
function records(e, spell) {
  const other = ['other'];
  const sp = (slug) => spell(slug);
  if (e.op === '&') return ['and', records(e.a, spell), records(e.b, spell)];
  if (e.op === '|') return ['or', records(e.a, spell), records(e.b, spell)];
  if (e.op === '!') {
    const inner = e.a;
    if (inner.atom) {
      const p = inner.atom.split('.');
      if ((p[0] === 'buff' || p[0] === 'debuff') && (p[2] === 'up' || p[2] === 'react') && sp(p[1])) return ['down', sp(p[1])];
      if ((p[0] === 'buff' || p[0] === 'debuff' || p[0] === 'dot') && p[2] === 'ticking' && sp(p[1])) return ['down', sp(p[1])];
      if (p[0] === 'cooldown' && (p[2] === 'ready' || p[2] === 'up') && sp(p[1])) return ['notready', sp(p[1])];
      if ((p[0] === 'prev_gcd' || p[0] === 'prev') && sp(p[p.length - 1])) return ['notprev', sp(p[p.length - 1])];
    }
    return other;
  }
  if (e.atom) {
    const p = e.atom.split('.');
    if ((p[0] === 'buff' || p[0] === 'debuff') && (p[2] === 'up' || p[2] === 'react') && sp(p[1])) return ['up', sp(p[1])];
    if ((p[0] === 'buff' || p[0] === 'debuff') && p[2] === 'down' && sp(p[1])) return ['down', sp(p[1])];
    if ((p[0] === 'dot' || p[0] === 'debuff') && p[2] === 'ticking' && sp(p[1])) return ['up', sp(p[1])];
    if ((p[0] === 'dot' || p[0] === 'debuff' || p[0] === 'buff') && p[2] === 'refreshable' && sp(p[1])) return ['refresh', sp(p[1])];
    if (p[0] === 'cooldown' && (p[2] === 'ready' || p[2] === 'up') && sp(p[1])) return ['ready', sp(p[1])];
    if ((p[0] === 'prev_gcd' || p[0] === 'prev') && sp(p[p.length - 1])) return ['prev', sp(p[p.length - 1])];
    return other;
  }
  if (['<', '>', '<=', '>=', '=', '!='].includes(e.op)) return compare(e, spell);
  return other;
}

function compare(e, spell) {
  let { a, b, op } = e;
  if (numOf(a) !== null && numOf(b) === null) {
    const flip = { '<': '>', '>': '<', '<=': '>=', '>=': '<=', '=': '=', '!=': '!=' };
    [a, b, op] = [b, a, flip[op]];
  }
  const n = numOf(b);
  const at = a.atom || '';
  const p = at.split('.');
  const other = ['other'];
  const big = op === '>' || op === '>=';
  // a > n means at least n + 1 for whole counts.
  const atLeast = (x) => (op === '>' ? x + 1 : x);
  const below = (x) => (op === '<=' ? x + 1 : x);

  if (at === 'active_enemies' || p[0] === 'spell_targets' || at === 'desired_targets') {
    if (n === null) return other;
    if (op === '=') return ['tgtis', n];
    if (big) return ['tgtmin', atLeast(n)];
    if (op === '<' || op === '<=') return ['tgtmax', op === '<' ? n - 1 : n];
    return other;
  }
  if (RESOURCES.has(p[0])) {
    const res = p[0];
    if (p[1] === 'deficit') return big ? ['resnotcap', res, n] : ['resfull', res, n];
    if (p[1] === 'pct') return n === null ? other : (big ? ['respctmin', res, atLeast(n)] : ['respctunder', res, below(n)]);
    if (p[1] === 'time_to_max') return big ? ['resnotcap', res, null] : ['resfull', res, null];
    if (p.length === 1 || p[1] === 'current') {
      if (n === null) return big ? ['resenough', res] : other;
      if (op === '=') return ['resis', res, n];
      return big ? ['resmin', res, atLeast(n)] : ['resunder', res, below(n)];
    }
    return other;
  }
  if ((p[0] === 'buff' || p[0] === 'debuff') && (p[2] === 'stack' || p[2] === 'react') && n !== null && spell(p[1])) {
    const id = spell(p[1]);
    if (big) return ['stackmin', id, atLeast(n)];
    if (op === '<' || op === '<=') return below(n) <= 1 ? ['down', id] : ['stackunder', id, below(n)];
    if (op === '=') return n === 0 ? ['down', id] : ['stackis', id, n];
    return other;
  }
  if ((p[0] === 'buff' || p[0] === 'debuff' || p[0] === 'dot') && p[2] === 'remains' && spell(p[1])) {
    const id = spell(p[1]);
    if (n === null) return other;
    if (op === '<' || op === '<=') return ['remunder', id, n];
    if (big) return n === 0 ? ['up', id] : ['remover', id, n];
    return other;
  }
  if (p[0] === 'cooldown' && spell(p[1])) {
    const id = spell(p[1]);
    if (p[2] === 'remains') {
      if (hasAtom(b, (x) => x.startsWith('gcd'))) return (op === '<' || op === '<=') ? ['cdsoon', id] : other;
      if (n === null) return other;
      if (op === '<' || op === '<=') return n <= 0 ? ['ready', id] : ['cdunder', id, n];
      if (big) return n <= 0 && op === '>' ? ['notready', id] : ['cdover', id, n];
      return other;
    }
    if ((p[2] === 'charges' || p[2] === 'charges_fractional') && n !== null) {
      if (big) return ['charges', id, p[2] === 'charges' ? atLeast(n) : Math.round(n * 10) / 10];
      if (op === '<' || op === '<=') return ['chargesunder', id, below(Math.ceil(n))];
      return other;
    }
    if (p[2] === 'full_recharge_time' && n !== null && (op === '<' || op === '<=')) return ['chargesfull', id, n];
    return other;
  }
  if (p[0] === 'active_dot' && n !== null && spell(p[1])) {
    if (op === '=' || big) return ['doton', spell(p[1]), big ? atLeast(n) : n];
    return other;
  }
  if (p[0] === 'target' && p[1] === 'health' && p[2] === 'pct' && n !== null) {
    return (op === '<' || op === '<=') ? ['hpunder', n] : ['hpover', n];
  }
  if (at === 'time' && n !== null) return (op === '<' || op === '<=') ? ['timeunder', n] : ['timeover', n];
  return other;
}

/** Flattens a top-level AND into its parts. */
function conjuncts(rec) {
  if (rec[0] === 'and') return [...conjuncts(rec[1]), ...conjuncts(rec[2])];
  return [rec];
}

const isOther = (r) => r[0] === 'other' || ((r[0] === 'and' || r[0] === 'or') && r.slice(1).some(isOther));
const keyOf = (r) => JSON.stringify(r);

// ------------------------------------------------------------------ lists

const NOISE = new Set(['snapshot_stats', 'variable', 'use_item', 'use_items', 'potion', 'invoke_external_buff',
  'blood_fury', 'berserking', 'fireblood', 'ancestral_call', 'arcane_torrent', 'lights_judgment',
  'bag_of_tricks', 'arcane_pulse', 'haymaker', 'rocket_barrage', 'azerite_surge', 'bloodlust', 'heroism',
  'time_warp', 'primal_rage', 'fury_of_the_aspects', 'auto_attack', 'auto_shot', 'wind_shear', 'counterspell',
  'kick', 'pummel', 'mind_freeze', 'rebuke', 'skull_bash', 'solar_beam', 'counter_shot', 'muzzle',
  'spear_hand_strike', 'disrupt', 'silence', 'quell', 'spell_lock', 'pool_resource', 'wait', 'cancel_buff',
  'cancel_action', 'retarget_auto_attack', 'summon_pet', 'flask', 'food', 'augmentation', 'antumbra',
  'trinket', 'sequence', 'strict_sequence', 'pause_action', 'interrupt', 'manifesting_trinket',
  'stop_moving', 'start_moving', 'swap_action_list', 'retarget', 'any_blink', 'pick_up_fragment',
  'cycling_variable', 'apply_poison', 'shadowmeld']);

/**
 * Builds one tab.
 * resolve: { spell(slug) -> id|null, actionSpell(slug) -> id|null, replaced(id) -> bool,
 *            isTalentSpell(slug), talent(slug) }
 * Returns { lines: [{ s, c: [records...], any: [[records...]...], t }], moving: [ids], keep: [ids], miss: Set }
 */
function buildTab(lists, start, ctx, resolve) {
  const lines = [];
  const moving = [];
  const keep = [];
  const miss = new Set();
  const visiting = new Set();

  function walk(listName, outer) {
    if (visiting.has(listName)) return false;
    visiting.add(listName);
    for (const { action, opts } of lists[listName] || []) {
      let cond = opts.if ? fold(parse(opts.if), ctx) : known(1);
      if (isFalse(cond)) continue;
      const conds = isTrue(cond) ? [] : conjuncts(records(cond, resolve.spell));
      const all = [...outer, ...conds];
      if (action === 'call_action_list' || action === 'run_action_list') {
        const name = opts.name;
        if (!name) continue;
        const stop = walk(name, all);
        // run_action_list: what comes after only runs when its condition
        // fails. With a condition that always holds, the tab ends here.
        if (action === 'run_action_list' && isTrue(cond) && outer.length === 0) { visiting.delete(listName); return true; }
        if (stop && isTrue(cond) && outer.length === 0) { visiting.delete(listName); return true; }
        continue;
      }
      if (NOISE.has(action)) continue;
      if (resolve.isTalentSpell(action) && !resolve.talent(action)) continue;
      const id = resolve.actionSpell(action);
      if (!id) { miss.add(action); continue; }
      if (resolve.replaced(id)) continue;
      if (opts.moving === '1' || opts.moving === 'true') { if (!moving.includes(id)) moving.push(id); continue; }
      // Keeping a buff of its own up ("lightning_shield if it is down")
      // belongs before the fight, as "keep it up".
      // Only in the main list: Stormkeeper "when its buff is down" in the
      // single-target list is a cooldown, not a buff to keep up.
      if (listName === start && conds.length === 1 && outer.length === 0 && conds[0][0] === 'down' && conds[0][1] === id) {
        if (!keep.includes(id)) keep.push(id);
        continue;
      }
      let t = null;
      const ti = opts.target_if || '';
      const tm = ti.match(/^(min|max):(?:dot|debuff)\.([a-z0-9_]+)\.remains/);
      if (tm && resolve.spell(tm[2])) t = [tm[1] === 'min' ? 'shortest' : 'longest', resolve.spell(tm[2])];
      lines.push({ s: id, c: all, t });
    }
    visiting.delete(listName);
    return false;
  }
  walk(start, []);

  // Lead with the target count; drop lines repeated further down.
  for (const l of lines) l.c.sort((x, y) => (y[0].startsWith('tgt') ? 1 : 0) - (x[0].startsWith('tgt') ? 1 : 0));
  const seen = new Set();
  const uniq = lines.filter((l) => {
    const k = l.s + '|' + keyOf(l.t) + '|' + l.c.map(keyOf).join('&');
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
  // The same action twice in a row: shared part + "one of these".
  const merged = [];
  for (const l of uniq) {
    const last = merged[merged.length - 1];
    if (last && last.s === l.s && keyOf(last.t) === keyOf(l.t) && last.c.length && l.c.length) {
      if (!last.any) last.any = [last.c];
      last.any.push(l.c);
      const keys = new Set(l.c.map(keyOf));
      last.c = last.c.filter((x) => keys.has(keyOf(x)));
      continue;
    }
    merged.push({ ...l });
  }
  for (const l of merged) {
    if (l.any) {
      const shared = new Set(l.c.map(keyOf));
      l.any = l.any.map((g) => g.filter((x) => !shared.has(keyOf(x))));
      if (l.any.some((g) => g.length === 0)) delete l.any; // one branch always holds
    }
  }
  return { lines: merged, moving, keep, miss };
}

module.exports = { parse, parseApl, fold, records, buildTab, tokenize, NOISE, isOther };
