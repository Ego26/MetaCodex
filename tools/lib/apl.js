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
  const re = /\s*(>=|<=|!=|>\?|<\?|%%|[()!&|=<>+\-*%/@]|[0-9]+(?:\.[0-9]+)?|[a-zA-Z_][a-zA-Z0-9_.]*)/gy;
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
  const BIN = [['|'], ['&'], ['=', '!=', '<', '>', '<=', '>='], ['+', '-'], ['*', '%', '%%', '/', '>?', '<?']];
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
    // floor(x), ceil(x): the only functions the lists use.
    if ((tok === 'floor' || tok === 'ceil') && peek() === '(') {
      next();
      const e = level(0);
      if (peek() === ')') next();
      return { op: tok, a: e };
    }
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
  'essence', 'mana', 'rune', 'runes', 'pain', 'soul_fragments']);
const RES_MAX = { soul_fragments: 6, combo_points: 7, holy_power: 5, soul_shard: 5, soul_shards: 5, chi: 6, essence: 6, rune: 6, runes: 6 };

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
  // SCHMUCK UND TRANK: gerechnet ohne Schmuck mit Benutzen-Effekt. Ob einer
  // bereit ist, haengt an der Ausruestung, nicht an der Rotation - und die
  // Zeilen dazu stellten mehr als die Haelfte aller vagen Bedingungen.
  if (ctx.trinket && (head === 'trinket' || head === 'this_trinket')) {
    // Der gedachte Schmuck: im ersten Platz einer mit Buff oder einer mit
    // Schaden, im zweiten keiner mit Benutzen-Effekt.
    const slot = head === 'this_trinket' ? '1' : p[1];
    const rest = head === 'this_trinket' ? p.slice(1).join('.') : p.slice(2).join('.');
    if (slot !== '1') return [0, 0];
    const t = ctx.trinket;
    if (rest === 'has_use_buff') return t.buff ? [1, 1] : [0, 0];
    if (rest === 'has_use_damage') return t.buff ? [0, 0] : [1, 1];
    if (rest === 'has_cooldown' || rest === 'cooldown.ready' || rest === 'cooldown.up') return [1, 1];
    if (rest === 'cooldown.duration') return [t.cd, t.cd];
    if (rest === 'cooldown.remains') return [0, 0];
    if (rest === 'proc.any_dps.duration' || rest === 'buff_duration') return t.buff ? [20, 20] : [0, 0];
    if (/^has_buff\./.test(rest)) return t.buff ? [1, 1] : [0, 0];
    return [0, 0];
  }
  if (head === 'trinket' || head === 'this_trinket' || head === 'equipped' || head === 'potion') return [0, 0];
  // Der Kampfstil ist je Aktivitaet bekannt: M+ ist ein Dungeon, Raid nicht.
  if (head === 'fight_style') return p[1] === ctx.fightStyle ? [1, 1] : [0, 0];
  // Unterbrechen und Laufwege stehen in keiner Prioritaet.
  // Laufen: nur fuer die Zeilen, die fuers Laufen da sind (moving=1) - dort
  // wird gelaufen, und zwar weiter als ein paar Schritte. Sonst steht man.
  if (head === 'movement' || a === 'moving') {
    if (!ctx.moving) return [0, 0];
    if (a === 'moving') return [1, 1];
    if (p[1] === 'distance') return [10, 40];
    return [0, INF];
  }
  if (a === 'target.debuff.casting.react') return [0, 0];
  // Feuer: Versengen in der Hinrichtungsphase - das Ziel unter 30 % Leben.
  if (a === 'scorch_execute.active') return [0, 1];
  // Die Rotation gilt im Kampf; ein Bosskampf ist der Raid.
  if (a === 'in_combat') return [1, 1];
  if (a === 'in_boss_encounter') return ctx.fightStyle === 'patchwerk' ? [1, 1] : [0, 0];
  // Entschieden wird am Ende des globalen Cooldowns, nicht mittendrin.
  if (a === 'gcd.remains') return [0, 0];
  if (a === 'gcd' || a === 'gcd.max') return [0.75, 1.5];
  if (head === 'talent') return ctx.talent(p[1]) ? [1, 1] : [0, 0];
  if (head === 'hero_tree') return ctx.hero(p[1]) ? [1, 1] : [0, 0];
  if (head === 'set_bonus') return ctx.setBonus(p.slice(1).join('.')) ? [1, 1] : [0, 0];
  // The end of a fight, the time to die: a long fight. Not "infinite" -
  // the lists compute with it ("fight_remains % cooldown"), and infinity
  // left those sums undefined (20 October). An hour is long enough that no
  // "fight is about to end" line ever applies.
  if (a === 'fight_remains' || a === 'target.time_to_die' || a === 'time_to_die' || a === 'target.fight_remains'
    || a === 'expected_combat_length') return [3600, 3600];
  // APEX: the N-th tier of the spec's tiered apex talent (SimC
  // engine/player/player.cpp). Known from the measured build.
  if (head === 'apex') {
    const on = ctx.apex ? ctx.apex(Number(p[1])) : null;
    if (on === null) return [0, 1];
    return on ? [1, 1] : [0, 0];
  }
  // A cooldown's length and a buff's most stacks: game data.
  if (head === 'cooldown' && p[2] === 'duration' && ctx.cdOf) {
    const sec = ctx.cdOf(p[1]);
    if (sec) return [sec, sec];
  }
  if ((head === 'buff' || head === 'debuff') && p[2] === 'max_stack' && ctx.stacksOf) {
    const n = ctx.stacksOf(p[1]);
    if (n) return [n, n];
  }
  if (a === 'target.time_to_die.remains') return [3600, 3600];
  // Consumables are not part of the priority.
  if (head === 'consumable') return [0, 0];
  if (head === 'stealthed') return [0, 1];
  // Demon Hunter: a Demonsurge ready for this ability - only with the talent.
  if (head === 'action' && p[2] === 'demonsurge_available') return ctx.talent('demonsurge') ? [0, 1] : [0, 0];
  if (head === 'action' && p[2] === 'placed') return [0, 1];
  if (head === 'stat') return [0, INF];
  if (a === 'health.pct') return [0, 100];
  if (head === 'action' && p[2] === 'cost' && ctx.costOf) {
    const c = ctx.costOf(p[1]);
    if (c !== undefined) return [c, c];
  }
  // The weapon the measured players carry (Rogue: daggers).
  if ((head === 'main_hand' || head === 'off_hand') && ctx.weapon) {
    const w = ctx.weapon(head, p[1]);
    if (w !== null && w !== undefined) return w ? [1, 1] : [0, 0];
  }
  // In melee range: the lists ask the distance only to Charge or Harpoon in.
  if (a === 'target.distance') return [5, 5];
  // A cast time is a few seconds at most.
  if (head === 'action' && (p[2] === 'cast_time' || p[2] === 'execute_time')) return [0, 10];
  if ((head === 'buff' || head === 'debuff' || head === 'dot') && p[2] === 'duration' && ctx.durOf) {
    const sec = ctx.durOf(p[1]);
    if (sec) return [sec, sec];
  }
  if (a === 'rtb_buffs') return [0, 7];
  // The most combo points a finisher spends (SimC: 5 plus the stratagems).
  if (a === 'cp_max_spend' && ctx.cpMax) return [ctx.cpMax, ctx.cpMax];
  // The potion is not part of the priority: its cooldown never holds a line.
  if (head === 'cooldown' && p[1] === 'potion') {
    if (p[2] === 'remains') return [0, 0];
    if (p[2] === 'duration') return [300, 300];
    return [1, 1];
  }
  // Trinket and potion variables: without an on-use trinket they are off.
  if (head === 'variable' && !ctx.trinket && /trinket|potion/.test(p[1] || '')) return [0, 0];
  // A state the list keeps over the fight (see latchOf): on or off.
  if (head === 'variable' && ctx.isLatch && ctx.isLatch(p[1])) return [0, 1];
  // Spells in flight (Fireball on its way to the target).
  if (/_in_flight$/.test(a) || (head === 'action' && p[2] === 'in_flight')) return [0, 5];
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
  if (e.op === 'floor' || e.op === 'ceil') {
    const a = fold(e.a, ctx, depth + 1);
    const fn = e.op === 'floor' ? Math.floor : Math.ceil;
    if (a.lo === a.hi) return known(fn(a.lo));
    return { op: e.op, a, lo: Number.isFinite(a.lo) ? Math.floor(a.lo) : a.lo, hi: Number.isFinite(a.hi) ? Math.ceil(a.hi) : a.hi };
  }
  // Ein bedingter Wert (variable,op=setif): Bedingung bekannt, Zweig bekannt.
  if (e.op === '?:') {
    const c = fold(e.c, ctx, depth + 1);
    if (isTrue(c)) return fold(e.a, ctx, depth + 1);
    if (isFalse(c)) return fold(e.b, ctx, depth + 1);
    const a = fold(e.a, ctx, depth + 1);
    const b = fold(e.b, ctx, depth + 1);
    return { op: '?:', c, a, b, lo: Math.min(a.lo, b.lo), hi: Math.max(a.hi, b.hi) };
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
      case '%%': return y ? x % y : 0;
      case '>?': return Math.max(x, y);
      case '<?': return Math.min(x, y);
      default: return 0;
    }
  };
  if (a.lo === a.hi && b.lo === b.hi) return known(clean(calc(a.lo, b.lo), 0));
  let lo, hi;
  if (e.op === '-') { lo = a.lo - b.hi; hi = a.hi - b.lo; }
  else if (e.op === '/' || e.op === '%') { lo = -INF; hi = INF; if (b.lo > 0 && a.lo >= 0) { lo = 0; } }
  else if (e.op === '%%') { lo = a.lo >= 0 ? 0 : -INF; hi = Number.isFinite(b.hi) ? Math.abs(b.hi) : INF; }
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
/** A folded expression back as text - for the report of what stayed vague. */
function show(e) {
  if (!e) return '?';
  if (e.num !== undefined) return String(round(e.num));
  if (e.atom) return e.atom;
  if (e.op === '!') return '!' + show(e.a);
  if (e.op === 'neg') return '-' + show(e.a);
  if (e.op === 'abs') return '@' + show(e.a);
  return '(' + show(e.a) + e.op + show(e.b) + ')';
}

// What stayed vague, counted - set by the caller that wants the report.
let vagueLog = null;
function logVague(map) { vagueLog = map; }

function records(e, spell) {
  const r = recordsOf(e, spell);
  if (vagueLog && r[0] === 'other') {
    // Variables and atoms by their kind, numbers out: "buff.X.remains>cooldown.Y.remains".
    const key = show(e).replace(/\b\d+(\.\d+)?\b/g, 'N');
    vagueLog.set(key, (vagueLog.get(key) || 0) + 1);
  }
  return r;
}

function recordsOf(e, spell) {
  // IF-THEN-ELSE (a variable set, then overwritten under a condition): "C and
  // A, or not C and B" - with A and B known, that is a plain condition.
  if (e.op === '?:' && spell.fold) {
    const fall = spell.fold({ op: '|', a: { op: '&', a: e.c, b: e.a }, b: { op: '&', a: { op: '!', a: e.c }, b: e.b } });
    if (fall.op !== '?:') return recordsOf(fall, spell);
  }
  // A known value inside a condition: always or never.
  if (e.num !== undefined) return e.num ? ['true'] : ['false'];
  // CASES (20 October): a threshold that depends on one or two yes/no values
  // ("fewer fragments than 4 with Fiery Brand up, else 5 minus Metamorphosis")
  // is said case by case - each case a condition of its own.
  if (['<', '>', '<=', '>=', '=', '!='].includes(e.op) && spell.fold) {
    const direkt = compare(e, spell);
    if (direkt[0] !== 'other') return direkt;
    const ja = [...new Set(boolAtoms(e))];
    if (ja.length >= 1 && ja.length <= 2) {
      let acc = null;
      for (let mask = 0; mask < (1 << ja.length); mask += 1) {
        const fest = new Map(ja.map((a, i) => [a, (mask >> i) & 1]));
        const r = spell.fold(setze(e, fest));
        if (r.lo === 0 && r.hi === 0) continue;
        const teil = (r.lo > 0 || r.hi < 0) ? null : recordsOf(r, spell);
        if (teil && isOther(teil)) return ['other'];
        let fall = null;
        for (const [a, v] of fest) {
          const atom = recordsOf({ atom: a, lo: 0, hi: 1 }, spell);
          if (isOther(atom)) return ['other'];
          const c = v ? atom : recordsOf({ op: '!', a: { atom: a, lo: 0, hi: 1 }, lo: 0, hi: 1 }, spell);
          fall = fall ? ['and', fall, c] : c;
        }
        if (teil) fall = ['and', fall, teil];
        acc = acc ? ['or', acc, fall] : fall;
      }
      if (acc) return acc;
    }
    return direkt;
  }
  if (e.atom === 'scorch_execute.active') return ['hpunder', 30];
  if (e.op === '!' && e.a && e.a.atom === 'scorch_execute.active') return ['hpover', 30];
  const other = ['other'];
  const sp = (slug) => spell(slug);
  if (e.op === '&') return ['and', records(e.a, spell), records(e.b, spell)];
  if (e.op === '|') return ['or', records(e.a, spell), records(e.b, spell)];
  if (e.op === '!') {
    const inner = e.a;
    // Nach innen gezogen: "nicht (A oder B)" ist "nicht A und nicht B".
    if (inner.op === '!') return records(inner.a, spell);
    if (inner.op === '|') return ['and', records({ op: '!', a: inner.a }, spell), records({ op: '!', a: inner.b }, spell)];
    if (inner.op === '&') return ['or', records({ op: '!', a: inner.a }, spell), records({ op: '!', a: inner.b }, spell)];
    const NEG = { '<': '>=', '>': '<=', '<=': '>', '>=': '<', '=': '!=', '!=': '=' };
    if (NEG[inner.op]) return records({ op: NEG[inner.op], a: inner.a, b: inner.b }, spell);
    if (inner.atom) {
      const q = inner.atom.split('.');
      if (q[0] === 'pet' && (q[2] === 'active' || q[2] === 'remains') && petSpell(q[1], spell)) return ['down', petSpell(q[1], spell)];
      if (q[0] === 'cooldown' && q[2] === 'remains' && sp(q[1])) return ['ready', sp(q[1])];
      if ((q[0] === 'buff' || q[0] === 'debuff' || q[0] === 'dot') && q[2] === 'remains' && sp(q[1])) return ['down', sp(q[1])];
      if (q[0] === 'action' && q[2] === 'executing' && sp(q[1])) return ['notcasting', sp(q[1])];
      if (q[0] === 'action' && q[2] === 'in_flight' && sp(q[1])) return ['notflying', sp(q[1])];
      if (q[0] === 'stealthed') return ['notstealthed'];
      { const sc = inner.atom.match(/^buff\.supercharge_(\d)\.up$/); if (sc) return ['notcharged', Number(sc[1])]; }
      if (q[0] === 'action' && q[2] === 'demonsurge_available' && sp(q[1]) && sp('demonsurge')) return ['nosurge', sp('demonsurge'), sp(q[1])];
      if (q[0] === 'action' && q[2] === 'placed' && sp(q[1])) return ['notplaced', sp(q[1])];
      if (q[0] === 'variable' && spell.latch) {
        const l = spell.latch(q[1]);
        if (l) {
          if (l[0] === 'notyet') return ['already', l[1]];
          if (l[0] === 'already') return ['notyet', l[1]];
          if (l[0] === 'since') return ['notsince', l[1], l[2]];
        }
      }
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
    // Supercharger: supercharge_N is up while at least N combo points are
    // charged. Before the general "buff up": SimC's source names a spell for
    // each, and "Supercharger active" would not say which.
    { const sc = e.atom.match(/^buff\.supercharge_(\d)\.up$/); if (sc) return ['charged', Number(sc[1])]; }
    if ((p[0] === 'buff' || p[0] === 'debuff') && (p[2] === 'up' || p[2] === 'react') && sp(p[1])) return ['up', sp(p[1])];
    if ((p[0] === 'buff' || p[0] === 'debuff') && p[2] === 'down' && sp(p[1])) return ['down', sp(p[1])];
    if ((p[0] === 'dot' || p[0] === 'debuff') && p[2] === 'ticking' && sp(p[1])) return ['up', sp(p[1])];
    if ((p[0] === 'dot' || p[0] === 'debuff' || p[0] === 'buff') && p[2] === 'refreshable' && sp(p[1])) return ['refresh', sp(p[1])];
    if (p[0] === 'cooldown' && (p[2] === 'ready' || p[2] === 'up') && sp(p[1])) return ['ready', sp(p[1])];
    if ((p[0] === 'prev_gcd' || p[0] === 'prev') && sp(p[p.length - 1])) return ['prev', sp(p[p.length - 1])];
    if (p[0] === 'pet' && (p[2] === 'active' || p[2] === 'remains') && petSpell(p[1], spell)) return ['up', petSpell(p[1], spell)];
    // "cooldown.X.remains" allein: X hat noch Abklingzeit; "buff.X.remains": X laeuft.
    if (p[0] === 'cooldown' && p[2] === 'remains' && sp(p[1])) return ['notready', sp(p[1])];
    if ((p[0] === 'buff' || p[0] === 'debuff' || p[0] === 'dot') && p[2] === 'remains' && sp(p[1])) return ['up', sp(p[1])];
    if (p[0] === 'action' && p[2] === 'executing' && sp(p[1])) return ['casting', sp(p[1])];
    if (p[0] === 'action' && p[2] === 'in_flight' && sp(p[1])) return ['flying', sp(p[1])];
    if (p[0] === 'stealthed') return ['stealthed'];
    if (RESOURCES.has(p[0]) && p.length === 1) return ['resmin', p[0], 1];
    if (p[0] === 'action' && p[2] === 'demonsurge_available' && sp(p[1]) && sp('demonsurge')) return ['surge', sp('demonsurge'), sp(p[1])];
    if (p[0] === 'action' && p[2] === 'placed' && sp(p[1])) return ['placed', sp(p[1])];
    // A state the list keeps over the fight.
    if (p[0] === 'variable' && spell.latch) {
      const l = spell.latch(p[1]);
      if (l) return l;
    }
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
  // What no special case can say goes to the general comparison: "the
  // remaining time of X is greater than the cooldown of Y".
  const generic = () => {
    const na = noun(a, spell);
    const nb = noun(b, spell);
    const CMP = { '>': 'gt', '>=': 'ge', '<': 'lt', '<=': 'le', '=': 'eq', '!=': 'ne' };
    if (na && nb && !(na[0] === 'n' && nb[0] === 'n')) return ['cmp', na, CMP[op], nb];
    return ['other'];
  };
  const big = op === '>' || op === '>=';
  // a > n means at least n + 1 for whole counts.
  const atLeast = (x) => (op === '>' ? x + 1 : x);
  const below = (x) => (op === '<=' ? x + 1 : x);

  const lt = op === '<' || op === '<=';
  // How long ago a spell was cast: "cooldown.X.duration - cooldown.X.remains"
  // and "time - action.X.last_used" (20 October).
  if (a.op === '-' && a.a && a.b && n !== null) {
    const x = (a.a.atom || '').split('.');
    const y = (a.b.atom || '').split('.');
    const seit = (x[0] === 'cooldown' && x[2] === 'duration' && y[0] === 'cooldown' && y[2] === 'remains' && x[1] === y[1])
      ? y[1]
      : (a.a.atom === 'time' && y[0] === 'action' && y[2] === 'last_used') ? y[1] : null;
    if (seit && spell(seit)) return ['ago', spell(seit), lt ? 'lt' : 'gt', n];
  }
  if (p[0] === 'action' && p[2] === 'execute_remains' && n !== null && spell(p[1])) {
    return lt ? ['castdone', spell(p[1]), n] : ['castleft', spell(p[1]), n];
  }
  // A bleed that is (not) empowered: "dot.garrote.pmultiplier<=1".
  if ((p[0] === 'dot' || p[0] === 'action') && p[2] === 'pmultiplier' && n !== null && spell(p[1])) {
    if (lt && n <= 1) return ['weakdot', spell(p[1])];
    if (!lt && n >= 1) return ['strongdot', spell(p[1])];
    if (lt) return ['multunder', spell(p[1]), n];
  }
  // A bleed's strength (Feral): the new one would be stronger than the running one.
  if (at === 'persistent_multiplier' || (b.atom || '') === 'persistent_multiplier') {
    const other2 = at === 'persistent_multiplier' ? b : a;
    const q = (other2.atom || '').split('.');
    if ((q[0] === 'dot' || q[0] === 'action') && q[2] === 'pmultiplier' && spell(q[1])) {
      const neuGroesser = at === 'persistent_multiplier' ? (op === '>' || op === '>=') : (op === '<' || op === '<=');
      return [neuGroesser ? 'stronger' : 'notstronger', spell(q[1])];
    }
  }
  if (at === 'active_enemies' || p[0] === 'spell_targets' || at === 'desired_targets') {
    if (n === null) return generic();
    if (op === '=') return ['tgtis', n];
    if (big) return ['tgtmin', atLeast(n)];
    if (op === '<' || op === '<=') return ['tgtmax', op === '<' ? n - 1 : n];
    return generic();
  }
  if (RESOURCES.has(p[0])) {
    const res = p[0];
    if (p[1] === 'deficit') return big ? ['resnotcap', res, n] : ['resfull', res, n];
    if (p[1] === 'pct') return n === null ? generic() : (big ? ['respctmin', res, atLeast(n)] : ['respctunder', res, below(n)]);
    if (p[1] === 'time_to_max') return big ? ['resnotcap', res, null] : ['resfull', res, null];
    if (p.length === 1 || p[1] === 'current' || p[1] === 'total' || p[1] === 'active') {
      if (n === null) return big ? ['resenough', res] : generic();
      if (op === '=') return ['resis', res, n];
      return big ? ['resmin', res, atLeast(n)] : ['resunder', res, below(n)];
    }
    return generic();
  }
  if ((p[0] === 'buff' || p[0] === 'debuff' || p[0] === 'dot') && (p[2] === 'stack' || p[2] === 'react') && n !== null && spell(p[1])) {
    const id = spell(p[1]);
    if (big) return atLeast(n) <= 1 ? ['up', id] : ['stackmin', id, atLeast(n)];
    if (op === '<' || op === '<=') return below(n) <= 1 ? ['down', id] : ['stackunder', id, below(n)];
    if (op === '=') return n === 0 ? ['down', id] : ['stackis', id, n];
    return generic();
  }
  if ((p[0] === 'buff' || p[0] === 'debuff' || p[0] === 'dot') && p[2] === 'remains' && spell(p[1])) {
    const id = spell(p[1]);
    if (n === null) return generic();
    if (op === '<' || op === '<=') return ['remunder', id, n];
    if (big) return n === 0 ? ['up', id] : ['remover', id, n];
    return generic();
  }
  if (p[0] === 'cooldown' && spell(p[1])) {
    const id = spell(p[1]);
    if (p[2] === 'remains') {
      if (hasAtom(b, (x) => x.startsWith('gcd'))) return (op === '<' || op === '<=') ? ['cdsoon', id] : generic();
      if (n === null) return generic();
      if (op === '<' || op === '<=') return n <= 0 ? ['ready', id] : ['cdunder', id, n];
      if (big) return n <= 0 && op === '>' ? ['notready', id] : ['cdover', id, n];
      return generic();
    }
    if ((p[2] === 'charges' || p[2] === 'charges_fractional') && n !== null) {
      if (big) return ['charges', id, p[2] === 'charges' ? atLeast(n) : Math.round(n * 10) / 10];
      if (op === '<' || op === '<=') return ['chargesunder', id, below(Math.ceil(n))];
      return generic();
    }
    if (p[2] === 'full_recharge_time' && n !== null && (op === '<' || op === '<=')) return ['chargesfull', id, n];
    return generic();
  }
  if (p[0] === 'active_dot' && n !== null && spell(p[1])) {
    if (op === '=' || big) return ['doton', spell(p[1]), big ? atLeast(n) : n];
    return generic();
  }
  if (at === 'health.pct' && n !== null) return lt ? ['myhpunder', n] : ['myhpover', n];
  if (p[0] === 'target' && p[1] === 'health' && p[2] === 'pct' && n !== null) {
    return (op === '<' || op === '<=') ? ['hpunder', n] : ['hpover', n];
  }
  // "time=0" is the pull (Protection's Charge), not "0 seconds into the
  // fight" - 25 October.
  if (at === 'time' && n === 0 && (op === '=' || op === '==')) return ['timeunder', 1];
  if (at === 'time' && n !== null) return (op === '<' || op === '<=') ? ['timeunder', n] : ['timeover', n];
  return generic();
}

/** The spell behind a pet: its own name, or what summons it. */
const PET_SPELL = { army_ghoul: 'army_of_the_dead', apoc_ghoul: 'apocalypse', ghoul: 'raise_dead' };
function petSpell(name, spell) {
  if (PET_SPELL[name] && spell(PET_SPELL[name])) return spell(PET_SPELL[name]);
  return spell(name) || spell('summon_' + name) || spell('raise_' + name) || null;
}

/** The yes/no atoms inside an expression (buff up, DoT ticking, ...). */
function boolAtoms(e) {
  if (!e) return [];
  if (e.atom) {
    const p = e.atom.split('.');
    const ja = (['buff', 'debuff'].includes(p[0]) && ['up', 'down', 'react'].includes(p[2]) && p[2] !== 'react')
      || (p[0] === 'dot' && ['ticking', 'up'].includes(p[2]))
      || (p[0] === 'cooldown' && ['up', 'ready'].includes(p[2]));
    return ja ? [e.atom] : [];
  }
  return [...boolAtoms(e.a), ...boolAtoms(e.b), ...boolAtoms(e.c)];
}

/** The expression with these atoms set to fixed values. */
function setze(e, fest) {
  if (!e) return e;
  if (e.atom && fest.has(e.atom)) return { num: fest.get(e.atom) };
  if (e.num !== undefined || e.atom) return e;
  return { ...e, a: setze(e.a, fest), b: setze(e.b, fest), c: setze(e.c, fest) };
}

/** A value as a noun ("the cooldown of X"), or null. */
function noun(e, spell) {
  if (!e) return null;
  if (e.lo === e.hi && Number.isFinite(e.lo)) return ['n', round(e.lo)];
  if (e.atom) {
    const p = e.atom.split('.');
    if ((p[0] === 'buff' || p[0] === 'debuff' || p[0] === 'dot') && p[2] === 'remains' && spell(p[1])) return ['rem', spell(p[1])];
    if ((p[0] === 'buff' || p[0] === 'debuff') && (p[2] === 'stack' || p[2] === 'react') && spell(p[1])) return ['stk', spell(p[1])];
    if (p[0] === 'cooldown' && p[2] === 'remains' && spell(p[1])) return ['cd', spell(p[1])];
    if (p[0] === 'cooldown' && (p[2] === 'charges' || p[2] === 'charges_fractional') && spell(p[1])) return ['chg', spell(p[1])];
    if (p[0] === 'pet' && p[2] === 'remains' && petSpell(p[1], spell)) return ['rem', petSpell(p[1], spell)];
    if (RESOURCES.has(p[0]) && (p.length === 1 || p[1] === 'total' || p[1] === 'active')) return ['res', p[0]];
    if (RESOURCES.has(p[0]) && p[1] === 'deficit') return ['def', p[0]];
    if (e.atom === 'gcd' || e.atom === 'gcd.max') return ['gcd'];
    if (p[0] === 'active_dot' && spell(p[1])) return ['dots', spell(p[1])];
    if (/_in_flight$/.test(e.atom)) return ['inflight'];
    if (e.atom === 'rtb_buffs') return ['rtb'];
    if (p[0] === 'stat' && /_rating$/.test(p[1] || '')) return ['stat', p[1].replace(/_rating$/, '')];
    if (p[0] === 'cooldown' && p[2] === 'full_recharge_time' && spell(p[1])) return ['full', spell(p[1])];
    if (e.atom === 'active_enemies' || p[0] === 'spell_targets') return ['tgt'];
    if (p[0] === 'action' && p[2] === 'usable_in' && spell(p[1])) return ['usable', spell(p[1])];
    if (p[0] === 'action' && (p[2] === 'execute_time' || p[2] === 'cast_time') && spell(p[1])) return ['casttime', spell(p[1])];
    if (p[0] === 'action' && p[2] === 'in_flight_remains' && spell(p[1])) return ['flyleft', spell(p[1])];
    if (RESOURCES.has(p[0]) && p[1] === 'regen') return ['regen', p[0]];
    return null;
  }
  if ((e.op === '<?' || e.op === '>?') && e.a && e.b) {
    const x = noun(e.a, spell);
    const y = noun(e.b, spell);
    if (!x || !y) return null;
    return [e.op === '<?' ? 'min' : 'max', x, y];
  }
  if ((e.op === '*' || e.op === '+' || e.op === '-') && e.a && e.b) {
    const x = noun(e.a, spell);
    const y = noun(e.b, spell);
    if (!x || !y) return null;
    const kind = e.op === '*' ? 'mul' : (e.op === '+' ? 'plus' : 'minus');
    return [kind, x, y];
  }
  return null;
}

/** Flattens a top-level AND into its parts. */
function conjuncts(rec) {
  if (rec[0] === 'and') return [...conjuncts(rec[1]), ...conjuncts(rec[2])];
  return [rec];
}

// "UNTER BESTIMMTEN BEDINGUNGEN" HOECHSTENS EINMAL JE SATZ (20. Oktober).
//
// Beim Tierherrschafts-Jaeger stand es viermal in einem Satz. Eine
// Oder-Gruppe mit einem unbekannten Zweig ist als Ganzes unbekannt (der
// Zweig kann immer greifen); eine Und-Kette behaelt, was sie weiss. Was
// am Ende einer Zeile unbekannt bleibt, wird ein Merker (more) statt einer
// Bedingung - und im Satz einmal "und weitere Bedingungen erfuellt sind".
const OTHER = ['other'];
function vereinfacht(r) {
  if (r[0] === 'or' || r[0] === 'and') {
    const a = vereinfacht(r[1]);
    const b = vereinfacht(r[2]);
    if (r[0] === 'or') {
      if (a[0] === 'true' || b[0] === 'true') return ['true'];
      if (a[0] === 'false') return b;
      if (b[0] === 'false') return a;
    } else {
      if (a[0] === 'false' || b[0] === 'false') return ['false'];
      if (a[0] === 'true') return b;
      if (b[0] === 'true') return a;
    }
    if (a[0] === 'other' || b[0] === 'other') return OTHER;
    return [r[0], a, b];
  }
  return r;
}
function vageEinmal(l) {
  const c = l.c.map(vereinfacht).filter((x) => x[0] !== 'true');
  if (c.some((x) => x[0] === 'false')) l.never = true;
  let more = c.some((x) => x[0] === 'other');
  l.c = c.filter((x) => x[0] !== 'other');
  if (l.any) {
    const any = l.any.map((g) => g.map(vereinfacht));
    // "eins davon" ist ein Oder: ein unbekannter Zweig macht es unbekannt.
    if (any.some((g) => g.some((x) => x[0] === 'other'))) {
      delete l.any;
      more = true;
    } else {
      l.any = any;
    }
  }
  if (more) l.more = true;
  else delete l.more;
}

const isOther = (r) => r[0] === 'other' || ((r[0] === 'and' || r[0] === 'or') && r.slice(1).some(isOther));
const keyOf = (r) => JSON.stringify(r);

// ------------------------------------------------------------------ lists

// Trank, Schmuck, Volksfaehigkeiten: nicht in der Prioritaet, aber mit ihrer
// Bedingung gesammelt - fuer den eigenen Reiter "Traenke & Schmuck".
const RACIALS = new Set(['blood_fury', 'berserking', 'fireblood', 'ancestral_call', 'arcane_torrent',
  'lights_judgment', 'bag_of_tricks', 'arcane_pulse', 'haymaker', 'rocket_barrage', 'azerite_surge']);
function itemKind(action, opts) {
  if (action === 'potion') return 'potion';
  if (action === 'use_items') return 'trinket';
  // Nur der Platz, nicht ein bestimmter Schmuck: den traegt nicht jeder.
  if (action === 'use_item' && /^trinket1$/.test(opts.slot || '')) return 'trinket';
  if (RACIALS.has(action)) return 'racial';
  return null;
}

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
/**
 * SimC's other spellings of the same thing, written the one way the
 * translator reads. Used on every condition AND on every variable's value
 * (21 October: "active_dots.moonfire" stood in a variable and stayed vague).
 */
function simcNames(text) {
  return String(text)
    // SimC's other spellings of the same thing.
    .replace(/\.remains_expected\b/g, '.remains')
    // What Reap would consume: the soul fragments there are (SimC: the lower
    // of the fragments and the most it takes).
    .replace(/\baction\.[a-z0-9_]+\.souls_consumed\b/g, 'soul_fragments')
    // More of SimC's spellings: a typo kept in the lists, the Paladin's
    // ground effect, a talent asked as an action.
    .replace(/\bactive_dots\./g, 'active_dot.')
    .replace(/\baction\.([a-z0-9_]+)\.(charges_fractional|charges|full_recharge_time)\b/g, 'cooldown.$1.$2')
    .replace(/(^|[^\w.])demonic_art\b/g, '$1buff.demonic_art.up')
    // Firestarter: the talent, against a target above 90 % health.
    .replace(/\bfirestarter\.active\b/g, '(talent.firestarter&target.health.pct>90)')
    .replace(/\.base_deficit\b/g, '.deficit')
    // Feral's Moonfire is Moonfire; a racial's cooldown and its buff's length.
    .replace(/\bmoonfire_cat\b/g, 'moonfire')
    .replace(/\baction\.([a-z0-9_]+)\.cooldown\b/g, 'cooldown.$1.duration')
    .replace(/\baction\.([a-z0-9_]+)\.duration\b/g, 'buff.$1.duration')
    .replace(/\baction\.([a-z0-9_]+)\.ready\b/g, 'cooldown.$1.ready')
    .replace(/\baction\.([a-z0-9_]+)\.channeling\b/g, 'action.$1.executing')
    // SimC's settings, at their defaults (engine/class_modules): the Death
    // Knight's first Anti-Magic Shell at 20 seconds; no pause; in melee range.
    .replace(/\bdeath_knight\.first_ams_cast\b/g, '20')
    .replace(/\btarget\.cooldown\.pause_action\.remains\b/g, '0')
    .replace(/(^|[^\w.])priority_rotation\b/g, '$10')
    .replace(/\btarget\.has_absorb\b/g, '0')
    .replace(/\bpriest\.force_devour_matter\b/g, '0')
    .replace(/\.regen_combined\b/g, '.regen')
    .replace(/\bbuff\.twist_of_fate_can_trigger_on_ally_heal\.up\b/g, '0')
    // "chi<chi.max": not full.
    .replace(/\b([a-z_]+)<\1\.max\b/g, '$1.deficit>0')
    .replace(/\bcooldown\.invoke_power_infusion_0\./g, 'cooldown.power_infusion.')
    .replace(/(^|[^\w.])consecration\.up\b/g, '$1buff.consecration.up')
    .replace(/\baction\.([a-z0-9_]+)\.enabled\b/g, 'talent.$1')
    // A buff's last trigger and a spell's last cast: the same "how long ago".
    .replace(/\btime-buff\.([a-z0-9_]+)\.last_trigger\b/g, 'time-action.$1.last_used')
    .replace(/\bdot\.([a-z0-9_]+)\.active_dots\b/g, 'active_dot.$1')
    .replace(/\bbuff\.([a-z0-9_]+)\.at_max_stacks\b/g, '(buff.$1.stack>=buff.$1.max_stack)')
;
}

function buildTab(lists, start, ctx, resolve) {
  const lines = [];
  const moving = [];
  const keep = [];
  const items = [];
  const miss = new Set();
  const visiting = new Set();

  // Was eine Zeile ueber ihren eigenen Zauber sagt, ohne ihn zu nennen.
  const BARE = {
    combo_strike: (a) => `!prev_gcd.1.${a}`,
    cooldown_react: () => '1',
    refreshable: (a) => `dot.${a}.refreshable`,
    ticking: (a) => `dot.${a}.ticking`,
    remains: (a) => `dot.${a}.remains`,
    charges_fractional: (a) => `cooldown.${a}.charges_fractional`,
    charges: (a) => `cooldown.${a}.charges`,
    full_recharge_time: (a) => `cooldown.${a}.full_recharge_time`,
    executing: (a) => `action.${a}.executing`,
    pmultiplier: (a) => `dot.${a}.pmultiplier`,
    in_flight: (a) => `action.${a}.in_flight`,
    cast_time: (a) => `action.${a}.cast_time`,
    execute_time: (a) => `action.${a}.cast_time`,
    duration: (a) => `buff.${a}.duration`,
  };
  const own = (text, action) => simcNames(text)
    .replace(
    /(^|[^\w.])(combo_strike|cooldown_react|refreshable|ticking|remains|charges_fractional|charges|full_recharge_time|executing|pmultiplier|in_flight|cast_time|execute_time|duration)(?![\w.])/g,
    (m, pre, name) => pre + '(' + BARE[name](action) + ')');

  // The resolver, and through it the states a list keeps over the fight.
  const sp = (k) => resolve.spell(k);
  sp.latch = (name) => (resolve.latch ? resolve.latch(name, ctx, sp) : null);
  sp.fold = (e) => fold(e, ctx);

  function walk(listName, outer) {
    if (visiting.has(listName)) return false;
    visiting.add(listName);
    for (const { action, opts } of lists[listName] || []) {
      const laufen = opts.moving === '1' || opts.moving === 'true';
      const cx = laufen ? { ...ctx, moving: true } : ctx;
      // target_if without min:/max:/first: is a condition too: SimC casts on
      // the first target it holds for, and not at all without one
      // ("sunfire,target_if=refreshable").
      const tiCond = opts.target_if && !/^(min|max|first):/.test(opts.target_if) ? opts.target_if : '';
      const ifText = [opts.if, tiCond].filter(Boolean).map((x) => `(${x})`).join('&');
      let cond = ifText ? fold(parse(own(ifText, action)), cx) : known(1);
      if (isFalse(cond)) continue;
      const conds = isTrue(cond) ? [] : conjuncts(records(cond, sp));
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
      const kind = itemKind(action, opts);
      if (kind) {
        // Die erste Zeile je Art (und je Volksfaehigkeit) gilt - wie in der
        // Prioritaet: was darunter steht, kommt nur, wenn sie nicht greift.
        const key = kind === 'racial' ? action : kind;
        if (!items.some((x) => x.key === key)) items.push({ key, kind, action, c: all });
        continue;
      }
      if (NOISE.has(action)) continue;
      // SimC's name for what the build presses instead: "berserk" is the
      // taken Incarnation (26 October).
      const act = resolve.alias ? resolve.alias(action) : action;
      if (resolve.isTalentSpell(act) && !resolve.talent(act)) continue;
      let id = resolve.actionSpell(act);
      if (!id) { miss.add(action); continue; }
      // A replaced spell's line is its replacement's (Final Verdict for
      // Templar's Verdict); without one known, it goes.
      if (resolve.replaced(id)) {
        const neu = resolve.replacement ? resolve.replacement(id) : null;
        if (!neu) continue;
        id = neu;
      }
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
    vageEinmal(l);
  }
  return { lines: merged.filter((l) => !l.never), moving, keep, items, miss };
}

module.exports = { parse, parseApl, fold, records, buildTab, tokenize, NOISE, RACIALS, isOther, show, logVague, vereinfacht, simcNames };
