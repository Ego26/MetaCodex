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
//      it is a cooldown or a spell most top players cast that the list
//      would lose, which then stays "on cooldown", or the list's filler.
//      A condition that can never hold beside the others goes too.
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
// No line becomes unconditional here except a rescued spell, the last line
// or a line whose only conditions always held: a line whose conditions all
// fall away goes. So the filler stays where SimulationCraft put it.

// The conditions a player checks - and in which order they matter most:
// the number of targets first, then the spell's own state, then resources.
const RANG = {
  tgtis: 1, tgtmin: 1, tgtmax: 1,
  up: 2, down: 2, refresh: 2, stealthed: 2, notstealthed: 2,
  ready: 3, notready: 3, stackmin: 3, stackunder: 3, stackis: 3, charges: 3, chargesunder: 3,
  // A cooldown a player sees on the bar (26 October: "Metamorphosis when Eye
  // Beam has more than 8 sec left", "Dark Transformation unless Army is
  // ready within 30 sec" fell away as fine tuning).
  cdsoon: 3, cdunder: 3, cdover: 3, chargesfull: 3,
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
// The most a resource holds, where it never changes.
const OBEN = { soul_shard: 5, soul_shards: 5, holy_power: 5 };

// Fine tuning a guide leaves out, even when the kind is a plain one. "Under
// 2 sec left" is no fine tuning but "about to expire" (Enrage before
// Rampage) - see einfach.
function feinabstimmung(c) {
  const [k, , n] = c;
  return k === 'remover' && typeof n === 'number' && n < 3;
}

const key = (x) => JSON.stringify(x);
/** The parts of an "or", flat. */
function sammleOder(c) {
  return Array.isArray(c) && c[0] === 'or' ? [...sammleOder(c[1]), ...sammleOder(c[2])] : [c];
}

/** Whether condition a holds whenever b does ("ready" is "ready within 3 sec"). */
function folgt(b, a, wie) {
  if (wie(a) === wie(b)) return true;
  if (wie(['', a[1]]) !== wie(['', b[1]])) return false;
  if (b[0] === 'ready' && (a[0] === 'cdsoon' || a[0] === 'cdunder')) return true;
  const n = a[a.length - 1], m = b[b.length - 1];
  if (a[0] !== b[0] || typeof n !== 'number' || typeof m !== 'number' || wie(a.slice(0, -1)) !== wie(b.slice(0, -1))) return false;
  return AT_LEAST.has(a[0]) ? m >= n : BELOW.has(a[0]) ? m <= n : false;
}

/**
 * The parts of one "or", each a group of conditions that hold together,
 * without what another part already says (26 October): "about to expire and
 * stronger, or about to expire" is "about to expire"; "ready soon, active or
 * ready" is "active or ready soon".
 */
function bereinige(gruppen, wie) {
  const g = gruppen.map((x) => ohneDoppel(x, wie));
  // A part that holds only when another holds as well adds nothing.
  const enthalten = (gross, klein) => klein.every((k) => gross.some((x) => folgt(x, k, wie)));
  return g.filter((x, i) => !g.some((y, j) => j !== i && enthalten(x, y) && (!enthalten(y, x) || j < i)));
}

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
function einfach(c, wie = key, selbst = null) {
  if (!Array.isArray(c)) return null;
  if (c[0] === 'or') {
    const teile = [];
    const sammle = (x) => {
      if (Array.isArray(x) && x[0] === 'or') { sammle(x[1]); sammle(x[2]); } else teile.push(x);
    };
    sammle(c);
    // NO "OR" GETS STRICTER THAN SIMC (26 October). Keeping only the plain
    // parts left Envenom for Deathmark, Hand of Gul'dan for 5 shards and
    // Rip for Tiger's Fury. Now: a part nobody can check makes the whole
    // "or" unknown - the line gets looser, not stricter; a part of several
    // conditions ("A and B") keeps the ones a player checks, as a group.
    let gruppen = [];
    for (const t of teile) {
      if (Array.isArray(t) && t[0] === 'and') {
        const blaetter = [];
        const und = (x) => { if (Array.isArray(x) && x[0] === 'and') { und(x[1]); und(x[2]); } else blaetter.push(x); };
        und(t);
        const e = blaetter.map((x) => einfach(x, wie, selbst));
        if (e.every((x) => x === WAHR)) return WAHR;
        const klar = ohneDoppel(e.filter((x) => x && x !== WAHR && x[0] !== 'or' && !x.any), wie);
        if (!klar.length) return null;
        gruppen.push(klar.sort((x, y) => (RANG[x[0]] || 9) - (RANG[y[0]] || 9)).slice(0, 2));
        continue;
      }
      const e = einfach(t, wie, selbst);
      if (e === WAHR) return WAHR;
      if (!e || e.any) return null;
      if (e[0] === 'or') { sammleOder(e).forEach((x) => gruppen.push([x])); continue; }
      gruppen.push([e]);
    }
    gruppen = bereinige(gruppen, wie);
    if (gruppen.every((g) => g.length === 1)) {
      const ok = zusammen(gruppen.map((g) => g[0]), wie);
      // "X ready or X not ready": always.
      for (const x of ok) {
        const gegen = GEGENTEIL[x[0]];
        if (gegen && ok.some((y) => y[0] === gegen && wie(['', y[1]]) === wie(['', x[1]]))) return WAHR;
      }
      if (!ok.length || ok.length > 3) return null;
      return ok.reduce((acc, x) => (acc ? ['or', acc, x] : x), null);
    }
    if (gruppen.length > 3) return null;
    if (gruppen.length === 1) return gruppen[0].length === 1 ? gruppen[0][0] : { any: gruppen };
    return { any: gruppen };
  }
  if (c[0] === 'and') return null;
  // "Death Mark active or more than 3590 sec left": a bound beyond any fight
  // is no check (the fight's length stood for it).
  if ((c[0] === 'cdover') && c[2] > 300) return null;
  if ((c[0] === 'cdsoon' || c[0] === 'cdunder') && c[2] > 300) return WAHR;
  // "Under 2 sec left": about to expire (Enrage before Rampage).
  if (c[0] === 'remunder' && typeof c[2] === 'number' && c[2] < 3) return ['refresh', c[1]];
  // "Cast Combustion when Combustion is ready": a spell is cast when it is
  // ready (25 October, Fire's "Combustion active or ready").
  if (c[0] === 'ready' && selbst && wie(['', c[1]]) === selbst) return WAHR;
  // "Fewer than 5.2 soul shards": there are never more than five.
  if (c[0] === 'resunder' && OBEN[c[1]] !== undefined && c[2] > OBEN[c[1]]) return WAHR;
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
  // "Up and about to expire": about to expire says it.
  const laeuftAus = new Set(out.filter((c) => c[0] === 'refresh').map((c) => name(c[1])));
  out = out.filter((c) => c[0] !== 'up' || !laeuftAus.has(name(c[1])));
  // "Up and expiring within 12 sec" reads "expiring within 12 sec"; "down
  // and expiring within 3 sec" is down (26 October, Festering Scythe).
  const restzeit = new Set(out.filter((c) => c[0] === 'remunder').map((c) => name(c[1])));
  const aus = new Set(out.filter((c) => c[0] === 'down').map((c) => name(c[1])));
  out = out.filter((c) => !(c[0] === 'up' && restzeit.has(name(c[1]))) && !(c[0] === 'remunder' && aus.has(name(c[1]))));
  // "Up and at 3 stacks": the stacks say it.
  const gestapelt = new Set(out.filter((c) => (c[0] === 'stackmin' || c[0] === 'stackis') && c[2] >= 1).map((c) => name(c[1])));
  out = out.filter((c) => c[0] !== 'up' || !gestapelt.has(name(c[1])));
  // "Enough runic power and nearly full": the threshold says it.
  out = out.filter((c) => c[0] !== 'resenough' || !out.some((d) => d !== c && RES.has(d[0]) && d[1] === c[1]));
  return out;
}

/**
 * What can never hold, out of a line (25 October). The merged lists of Fire
 * read "Combustion not active and (Combustion active or ready)" and
 * "Heat Shimmer active or (Heat Shimmer not active and Pyroclasm active)":
 * a part that the line's own conditions rule out goes, and of "A or (not A
 * and B)" stays "A or B".
 */
function ohneWiderspruch(bekannt, any, wie) {
  const name = (id) => wie(['', id]);
  const gegen = (c) => (c[0] === 'up' ? 'down' : c[0] === 'down' ? 'up' : null);
  const fest = new Set(bekannt.filter((c) => c[0] === 'up' || c[0] === 'down').map((c) => c[0] + name(c[1])));
  const unmoeglich = (c) => gegen(c) && fest.has(gegen(c) + name(c[1]));
  const c = bekannt.map((x) => {
    if (x[0] !== 'or') return x;
    const teile = [];
    const sammle = (y) => { if (y[0] === 'or') { sammle(y[1]); sammle(y[2]); } else teile.push(y); };
    sammle(x);
    const bleibt = teile.filter((t) => !unmoeglich(t));
    if (!bleibt.length || bleibt.length === teile.length) return x;
    return bleibt.reduce((acc, y) => (acc ? ['or', acc, y] : y), null);
  });
  if (!any) return { c, any };
  let zweige = any.filter((g) => !g.some(unmoeglich));
  if (!zweige.length) return { c, any };
  zweige = bereinige(zweige, wie);
  // "A or (not A and B)": when A does not hold, not A does.
  const allein = new Set(zweige.filter((g) => g.length === 1 && gegen(g[0])).map((g) => g[0][0] + name(g[0][1])));
  zweige = bereinige(zweige.map((g) => (g.length > 1 ? g.filter((x) => !(gegen(x) && allein.has(gegen(x) + name(x[1])))) : g)), wie);
  if (zweige.length === 1) return { c: [...c, ...zweige[0]], any: undefined };
  if (zweige.every((g) => g.length === 1)) {
    const oder = zusammen(zweige.map((g) => g[0]), wie).reduce((acc, y) => (acc ? ['or', acc, y] : y), null);
    return { c: [...c, oder], any: undefined };
  }
  return { c, any: zweige };
}

/**
 * What a rescued line still says plainly, from anywhere in its conditions
 * (25 October): its own effect running out and a resource threshold -
 * "Garrote when Garrote is about to run out", "Dispatch at 6 or more combo
 * points" - rather than a bare "on cooldown".
 */
const EIGEN = ['refresh', 'down', 'remunder'];
function rettung(l, wie, selbst) {
  // One "or" of plain parts, only too many of them: the first three, as
  // SimC orders them - Shadowstrike "in Shadow Dance, Stealth or Vanish".
  if ((l.c || []).length === 1 && l.c[0][0] === 'or' && !l.any) {
    const teile = [];
    const flach = (x) => { if (x[0] === 'or') { flach(x[1]); flach(x[2]); } else teile.push(x); };
    flach(l.c[0]);
    const klar = teile.map((t) => einfach(t, wie, selbst));
    if (klar.length > 3 && klar.every((x) => x && x !== WAHR && !x.any && x[0] !== 'or')) {
      return [zusammen(klar, wie).slice(0, 3).reduce((acc, y) => (acc ? ['or', acc, y] : y), null)];
    }
  }
  const blaetter = [];
  const sammle = (x) => {
    if (!Array.isArray(x)) return;
    if (x[0] === 'or' || x[0] === 'and') { sammle(x[1]); sammle(x[2]); return; }
    const e = einfach(x, wie, selbst);
    if (e && e !== WAHR && !e.any) blaetter.push(e);
  };
  (l.c || []).forEach(sammle);
  (l.any || []).forEach((g) => g.forEach(sammle));
  const eigen = EIGEN.map((k) => blaetter.find((e) => e[0] === k && wie(['', e[1]]) === selbst)).find(Boolean);
  // Shadowstrike only from stealth: that says more than an energy count.
  const verstohlen = blaetter.find((e) => e[0] === 'stealthed');
  const res = blaetter.find((e) => e[0] === 'resmin' || e[0] === 'resfull');
  return [eigen, verstohlen || res].filter(Boolean);
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
    if (e && e !== WAHR && !e.any) bekannt.push(e);
  }
  const c = ohneDoppel(bekannt, wie).sort((x, y) => (RANG[x[0]] || 9) - (RANG[y[0]] || 9)).slice(0, opts.maxConds || 3);
  return c.length ? c : undefined;
}

/**
 * @param {Array<{s:number, c?:Array, any?:Array, t?:Array, more?:boolean}>} lines
 * @param {{maxConds?:number, maxLines?:number, isCooldown?:(id:number)=>boolean,
 *          isPlayed?:(id:number)=>boolean, nameOf?:(id:number)=>string}} [opts]
 *   isCooldown: a spell worth keeping "on cooldown" when its conditions fall away
 *   isPlayed: the same for a spell most measured top players cast
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
  lines.forEach((l, nr) => {
    if (ohneBedingung.has(l.s)) return;
    // THE PULL IS NO PRIORITY (26 October): a line bound to the first
    // seconds of the fight ("time<2", the opener list) stood as line 2 of
    // Windwalker's priority ("Tiger Palm at less than 4 Chi").
    if ((l.c || []).some((c) => c[0] === 'timeunder')) return;
    const selbst = wie(['', l.s]);
    let bekannt = [];
    let fehlt = Boolean(l.more);
    // An "or" of whole groups ("A and B, or C") is a "one of".
    let orGruppen;
    for (const c of l.c || []) {
      const e = einfach(c, wie, selbst);
      if (e === WAHR) continue;
      if (e && e.any) {
        if (orGruppen || l.any) fehlt = true; else orGruppen = e.any;
        continue;
      }
      if (e) bekannt.push(e); else fehlt = true;
    }
    // "One of" from merged lines: single conditions become one "or".
    let any = orGruppen;
    if (l.any) {
      if (l.any.every((g) => g.length === 1)) {
        const e = einfach(l.any.map((g) => g[0]).reduce((acc, x) => (acc ? ['or', acc, x] : x), null), wie, selbst);
        if (e && e !== WAHR && !e.any) bekannt.push(e); else if (!e || e.any) fehlt = true;
      } else {
        // A part that always holds says nothing; a branch of nothing else
        // makes the whole "one of" hold.
        const zweige = l.any.map((g) => g.map((x) => { const e = einfach(x, wie, selbst); return e && e.any ? null : e; })
          .filter((x) => x !== WAHR));
        if (zweige.some((g) => !g.length)) any = undefined;
        else if (zweige.length <= 3 && zweige.every((g) => g.every(Boolean) && g.length <= 2)) any = zweige;
        else fehlt = true;
      }
    }
    ({ c: bekannt, any } = ohneWiderspruch(bekannt, any, wie));
    bekannt = ohneDoppel(bekannt, wie);
    // Nothing understandable left of a line that had conditions: it goes.
    if (!bekannt.length && !any && fehlt) {
      // Bound to the pull (Charge "in the first half second"): the opener,
      // not "on cooldown". "After 18 seconds" is no opener: Fire lost
      // Combustion to it (25 October).
      // Only when the pull is a must: Havoc "or within the first 5 seconds"
      // is no opener either.
      if ((l.c || []).some((c) => c[0] === 'timeunder')) return;
      // The list's last line is its filler, whatever SimC computes for it:
      // Beast Mastery's Cobra Shot "when Bestial Wrath's cooldown is longer
      // than a global cooldown" fell away and Barbed Shot read as the filler
      // (25 October).
      if (nr === lines.length - 1 && !out.some((o) => o.s === l.s && !o.c.length && !o.any)) {
        out.push({ s: l.s, c: [], any: undefined, t: l.t });
        return;
      }
      verloren.push({ s: l.s, at: out.length, t: l.t, c: rettung(l, wie, selbst) });
      return;
    }
    bekannt.sort((x, y) => (RANG[x[0]] || 9) - (RANG[y[0]] || 9));
    const c = bekannt.slice(0, max);
    const neu = { s: l.s, c, any, t: l.t };
    // A line above already says it: the same spell, with only some of these
    // conditions - whenever this line holds, that one held first.
    const teil = (o) => !o.any && o.c.every((x) => c.some((y) => wie(y) === wie(x)));
    if (out.some((o) => o.s === neu.s && key(o.t) === key(neu.t) && (teil(o) || key(o.c) === key(neu.c) && key(o.any) === key(neu.any)))) return;
    out.push(neu);
    if (!c.length && !any) ohneBedingung.add(l.s);
  });
  // A spell the list would lose stays, where it first stood, "on cooldown":
  // a cooldown, or a spell most measured top players cast - Kill Command,
  // Beast Mastery's main button, fell away with SimC's "Howl ready or ..."
  // (25 October).
  const rein = [];
  for (const v of verloren) {
    const behalten = (opts.isCooldown && opts.isCooldown(v.s)) || (opts.isPlayed && opts.isPlayed(v.s));
    if (!behalten) continue;
    if (out.some((o) => o.s === v.s) || rein.some((r) => r.s === v.s)) continue;
    rein.push(v);
  }
  for (const v of rein.reverse()) out.splice(v.at, 0, { s: v.s, c: v.c || [], any: undefined, t: v.t });
  // A line right before the same spell without condition says nothing more.
  const knapp = out.filter((o, i) => {
    const n = out[i + 1];
    return !(n && n.s === o.s && !n.c.length && !n.any && (o.c.length || o.any));
  });
  return kuerzen(knapp, opts.maxLines || MAX_LINES);
}

module.exports = { simplify, simpleConditions, einfach, RANG, MAX_LINES };
