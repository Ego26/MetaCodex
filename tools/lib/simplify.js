// The rotation as a guide writes it, not as the simulator runs it
// (21 October).
//
// SimulationCraft tunes every tenth of a second: "ready within 2 seconds",
// "Maelstrom does not overcap by 15", "the cast time of X is shorter than
// the remaining time of Y". A guide - Wowhead, Method, Icy Veins - names
// the rules a player applies in the fight: "Cast Between the Eyes at 6 or
// more combo points". This step turns the translated list into that:
//
//   1. Only conditions a player checks during the fight stay: a buff up or
//      down, ready, running out, stacks, charges, a resource threshold, the
//      number of targets, the target's health, an empowered bleed.
//   2. Nothing vague: what SimC computes besides falls away silently; a line
//      with no understandable condition left falls away entirely - unless
//      it is a cooldown the list would lose, which then stays "on cooldown".
//   3. Short: at most three conditions. Of a "one of" the plain parts stay
//      (each of them alone is reason enough to cast), at most three, and two
//      of one kind become one: "below 35 or below 20 percent" is "below 35".
//      A "one of" that always holds ("X ready or X not ready") goes.
//   4. Nothing said twice: a condition of the same name twice, "up" next to
//      a stack count of the same buff, "enough" next to another threshold
//      of the same resource. Two buffs of one name that one line wants up
//      and down (Divine Arbiter has two) read as nonsense: the "down" goes.
//   5. Nothing pointless: a line a line above already covers (the same
//      spell with only some of these conditions), a line right before the
//      same spell without condition.
//   6. At most twelve lines, as a guide lists them. What goes first: lines
//      of a spell that stands further in the list too, the most conditions
//      first. No spell leaves the list.
//
// No line becomes unconditional here except a rescued cooldown or a line
// whose only conditions always held: a line whose conditions all fall away
// goes. So the filler stays where SimulationCraft put it.

// The conditions a player checks - and in which order they matter most:
// the number of targets first, then the spell's own state, then resources.
const RANG = {
  tgtis: 1, tgtmin: 1, tgtmax: 1,
  up: 2, down: 2, refresh: 2, stealthed: 2, notstealthed: 2,
  ready: 3, notready: 3, stackmin: 3, stackunder: 3, stackis: 3, charges: 3, chargesunder: 3,
  resmin: 4, resunder: 4, resfull: 4, resenough: 4, respctmin: 4, respctunder: 4, resis: 4,
  hpunder: 5, hpover: 5, doton: 5, weakdot: 5, strongdot: 5, stronger: 5, notstronger: 5,
  remunder: 6, remover: 6, placed: 6, notplaced: 6, surge: 6, nosurge: 6, prev: 6,
};
const RES = new Set(['resmin', 'resunder', 'resfull', 'resenough', 'respctmin', 'respctunder', 'resis']);
const MAX_LINES = 12;

// Two parts of one "or" with the same kind and subject: the looser bound.
const AT_LEAST = new Set(['tgtmin', 'hpover', 'resmin', 'respctmin', 'stackmin', 'remover', 'charges']);
const BELOW = new Set(['tgtmax', 'hpunder', 'resunder', 'respctunder', 'stackunder', 'remunder', 'chargesunder']);
// Opposites: one of them always holds.
const GEGENTEIL = { ready: 'notready', up: 'down', stealthed: 'notstealthed', placed: 'notplaced' };

const WAHR = ['true'];

// Fine tuning a guide leaves out, even when the kind is a plain one.
function feinabstimmung(c) {
  const [k, , n] = c;
  return (k === 'remunder' || k === 'remover') && typeof n === 'number' && n < 3;
}

const key = (x) => JSON.stringify(x);

/** "One of", merged: duplicates and two bounds of one subject become one. */
function zusammen(teile, wie) {
  const out = [];
  for (const t of teile) {
    const n = t[t.length - 1];
    const art = AT_LEAST.has(t[0]) ? 'min' : BELOW.has(t[0]) ? 'max' : null;
    const i = out.findIndex((o) => wie(o) === wie(t)
      || (art && typeof n === 'number' && o[0] === t[0] && wie(o.slice(0, -1)) === wie(t.slice(0, -1))));
    if (i < 0) { out.push(t); continue; }
    if (!art) continue;
    const alt = out[i][out[i].length - 1];
    out[i] = [...t.slice(0, -1), art === 'min' ? Math.min(alt, n) : Math.max(alt, n)];
  }
  return out;
}

/**
 * A condition a player checks, WAHR when it always holds, or null when it
 * is fine tuning.
 * @param {Array} c
 * @param {(c:Array)=>string} [wie]  what a player reads - two buffs of one name are one
 */
function einfach(c, wie = key) {
  if (!Array.isArray(c)) return null;
  if (c[0] === 'or') {
    const teile = [];
    const sammle = (x) => {
      if (Array.isArray(x) && x[0] === 'or') { sammle(x[1]); sammle(x[2]); } else teile.push(x);
    };
    sammle(c);
    // Each part alone is reason enough to cast: the plain ones stay.
    const roh = teile.map((t) => einfach(t, wie));
    if (roh.some((x) => x === WAHR)) return WAHR;
    const ok = zusammen(roh.filter((x) => x && x[0] !== 'or' && x[0] !== 'and'), wie);
    // "X ready or X not ready": always.
    for (const x of ok) {
      const gegen = GEGENTEIL[x[0]];
      if (gegen && ok.some((y) => y[0] === gegen && wie(['', y[1]]) === wie(['', x[1]]))) return WAHR;
    }
    if (!ok.length || ok.length > 3) return null;
    return ok.reduce((acc, x) => (acc ? ['or', acc, x] : x), null);
  }
  if (c[0] === 'and') return null;
  // A dot on none or one target reads as the dot down or up.
  if (c[0] === 'doton' && c[2] === 0) return ['down', c[1]];
  if (c[0] === 'doton' && c[2] === 1) return ['up', c[1]];
  // "Fewer than 1 missing" is full.
  if (c[0] === 'resfull' && typeof c[2] === 'number' && c[2] <= 1) return ['resfull', c[1]];
  if (!(c[0] in RANG) || feinabstimmung(c)) return null;
  return c;
}

/** Of one line's conditions what says something: nothing twice. */
function ohneDoppel(bekannt, wie) {
  let out = [];
  for (const c of bekannt) if (!out.some((d) => wie(d) === wie(c))) out.push(c);
  const name = (id) => wie(['', id]);
  // Up and down of one name in one line: a player cannot tell them apart.
  const an = new Set(out.filter((c) => c[0] === 'up').map((c) => name(c[1])));
  out = out.filter((c) => c[0] !== 'down' || !an.has(name(c[1])));
  // "Up and at 3 stacks": the stacks say it.
  const gestapelt = new Set(out.filter((c) => (c[0] === 'stackmin' || c[0] === 'stackis') && c[2] >= 1).map((c) => name(c[1])));
  out = out.filter((c) => c[0] !== 'up' || !gestapelt.has(name(c[1])));
  // "Enough runic power and nearly full": the threshold says it.
  out = out.filter((c) => c[0] !== 'resenough' || !out.some((d) => d !== c && RES.has(d[0]) && d[1] === c[1]));
  return out;
}

/** At most MAX_LINES: refinements of a spell that stands further down go first. */
function kuerzen(out, max) {
  const lines = out.slice();
  while (lines.length > max) {
    let weg = -1;
    for (let i = 0; i < lines.length; i += 1) {
      const l = lines[i];
      if (!lines.some((o, j) => j !== i && o.s === l.s)) continue;
      const gewicht = l.c.length + (l.any ? l.any.length : 0);
      const best = weg < 0 ? -1 : lines[weg].c.length + (lines[weg].any ? lines[weg].any.length : 0);
      if (gewicht >= best) weg = i;
    }
    if (weg < 0) break;
    lines.splice(weg, 1);
  }
  return lines;
}

/** What a player reads: spells by name. */
const leser = (nameOf) => (c) => key(c.map((x, i) => (i === 1 && typeof x === 'number' ? nameOf(x) : x)));

/**
 * One set of conditions as a guide says it - for a trinket or a potion.
 * @param {Array} cs
 * @param {{maxConds?:number, nameOf?:(id:number)=>string}} [opts]
 * @returns {Array|undefined} undefined when nothing understandable is left
 */
function simpleConditions(cs, opts = {}) {
  const wie = leser(opts.nameOf || String);
  const bekannt = [];
  for (const c of cs || []) {
    const e = einfach(c, wie);
    if (e && e !== WAHR) bekannt.push(e);
  }
  const c = ohneDoppel(bekannt, wie).sort((x, y) => (RANG[x[0]] || 9) - (RANG[y[0]] || 9)).slice(0, opts.maxConds || 3);
  return c.length ? c : undefined;
}

/**
 * @param {Array<{s:number, c?:Array, any?:Array, t?:Array, more?:boolean}>} lines
 * @param {{maxConds?:number, maxLines?:number, isCooldown?:(id:number)=>boolean,
 *          nameOf?:(id:number)=>string}} [opts]
 *   isCooldown: a spell worth keeping "on cooldown" when its conditions fall away
 *   nameOf: the name a player reads - two buffs of one name are one to him
 * @returns {Array}
 */
function simplify(lines, opts = {}) {
  const max = opts.maxConds || 3;
  const nameOf = opts.nameOf || String;
  const wie = leser(nameOf);
  const out = [];
  const ohneBedingung = new Set();
  const verloren = [];
  for (const l of lines) {
    if (ohneBedingung.has(l.s)) continue;
    let bekannt = [];
    let fehlt = Boolean(l.more);
    for (const c of l.c || []) {
      const e = einfach(c, wie);
      if (e === WAHR) continue;
      if (e) bekannt.push(e); else fehlt = true;
    }
    // "One of" from merged lines: single conditions become one "or".
    let any;
    if (l.any) {
      if (l.any.every((g) => g.length === 1)) {
        const e = einfach(l.any.map((g) => g[0]).reduce((acc, x) => (acc ? ['or', acc, x] : x), null), wie);
        if (e && e !== WAHR) bekannt.push(e); else if (!e) fehlt = true;
      } else {
        const zweige = l.any.map((g) => g.map((x) => einfach(x, wie)));
        if (zweige.length <= 3 && zweige.every((g) => g.length && g.every((x) => x && x !== WAHR) && g.length <= 2)) any = zweige;
        else fehlt = true;
      }
    }
    bekannt = ohneDoppel(bekannt, wie);
    // Nothing understandable left of a line that had conditions: it goes.
    if (!bekannt.length && !any && fehlt) {
      // Bound to the fight's clock (Charge "at the pull"): the opener, not
      // "on cooldown".
      if (!/"time(under|over)"/.test(key(l.c || []))) verloren.push({ s: l.s, at: out.length, t: l.t });
      continue;
    }
    bekannt.sort((x, y) => (RANG[x[0]] || 9) - (RANG[y[0]] || 9));
    const c = bekannt.slice(0, max);
    const neu = { s: l.s, c, any, t: l.t };
    // A line above already says it: the same spell, with only some of these
    // conditions - whenever this line holds, that one held first.
    const teil = (o) => !o.any && o.c.every((x) => c.some((y) => wie(y) === wie(x)));
    if (out.some((o) => o.s === neu.s && key(o.t) === key(neu.t) && (teil(o) || key(o.c) === key(neu.c) && key(o.any) === key(neu.any)))) continue;
    out.push(neu);
    if (!c.length && !any) ohneBedingung.add(l.s);
  }
  // A cooldown the list would lose stays, where it first stood: on cooldown.
  const rein = [];
  for (const v of verloren) {
    if (!opts.isCooldown || !opts.isCooldown(v.s)) continue;
    if (out.some((o) => o.s === v.s) || rein.some((r) => r.s === v.s)) continue;
    rein.push(v);
  }
  for (const v of rein.reverse()) out.splice(v.at, 0, { s: v.s, c: [], any: undefined, t: v.t });
  // A line right before the same spell without condition says nothing more.
  const knapp = out.filter((o, i) => {
    const n = out[i + 1];
    return !(n && n.s === o.s && !n.c.length && !n.any && (o.c.length || o.any));
  });
  return kuerzen(knapp, opts.maxLines || MAX_LINES);
}

module.exports = { simplify, simpleConditions, einfach, RANG, MAX_LINES };
