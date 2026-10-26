// The healer guide: what top healers cast, measured - not a priority list
// (24 October).
//
// SimulationCraft cannot simulate healing the way it simulates damage, so
// there is no list to translate. A healer guide says something else, and
// the logs say it: what runs all the time, which cooldowns are used as soon
// as they are ready and which are held, what opens the fight, and in the
// raid, at which minute of each boss the big cooldowns go out. Nothing is
// written that the measurement does not show.
//
//   prio    the priority, as a guide lists it, from what most (60 %) cast
//           with a cooldown under a minute (24 October):
//             proc   a spell a visible buff puts on the bar in place of
//                    another (Stormstream Totem for Healing Stream Totem)
//             oncd   used on 70 % of the possible casts or more
//             emp    the same, but it empowers your next spell
//                    (Thunder Focus Tea) - it is used, not kept up
//             keep   the same, a totem or summon lasting about its
//                    cooldown: kept up (Surging Totem)
//             spend  costs a secondary resource (Holy Power, Essence, Chi)
//             mana   restores mana (Mana Tea) - no heal at all
//             reg    a cooldown used less often: regularly
//             fill   no cooldown: what fills the time - with what it is
//                    (several targets or one, dearer or cheaper)
//             dmg    damage, apart
//             dmgheal  damage that heals through a talent of the build
//                    (Atonement), with that talent as "via"
//             sit    neither heal nor damage (Totemic Projection moves the
//                    totems): last, as a tool for the moment
//           WHAT THE SPELL DOES decides, from the game's own text (24
//           October). A cast in the log that no player presses - the effect
//           of a passive talent (Reclamation, Twin Flame) - has no line.
//           Raid against M+: a filler cast 1.6 times as often or more (or
//           that much less) than in the other activity says so.
//   cds     a cooldown of a minute or more, cast by 40 %. How much of what
//           was possible got used says how: 85 % and more "as soon as
//           ready", 50 % "aimed", below "when needed". A tool (no heal, no
//           protection) is marked k = "tool" and stands last; one for
//           damage k = "dmg" (used when there is little to heal), one for
//           mana k = "mana", the healer's own defensive k = "self", one
//           for a single ally k = "ext"
//   items   item uses (trinkets, potions, healthstone), the same way
//   opener  the raid pull, as for the damage specs (lib/opener.js)
//   bosses  the raid: per boss, the n-th use of each AIMED cooldown at the
//           median minute, kept where most of the players used it that
//           often - one used as soon as ready says nothing there
//
// TWO IDS, ONE CAST. Power Infusion with its twin, Flame Shock: the log
// holds two casts of one name at the same moment. A name counts the larger
// of its IDs, not their sum, and casts of one name within 1.5 seconds are
// one use.

const opener = require('./opener');

const CORE_SHARE = 0.6;
const CORE_CPM = 1;
const PROC_CPM = 0.3;
const ON_CD_USE = 70;
const KEEP_RATIO = 0.6;
const MAX_FILL = 3;
const VS_RATIO = 1.6;
const CD_FROM = 60;
const CD_SHARE = 0.4;
const ITEM_SHARE = 0.3;
const MAX_CORE = 10;
const MAX_DMG = 4;
const ON_COOLDOWN = 85;
const AIMED = 50;

const SAME_CAST_MS = 1500;
const MAX_BOSS_CDS = 4;

const median = (a) => { const b = [...a].sort((x, y) => x - y); return b[Math.floor(b.length / 2)]; };

/**
 * @param {{casts:{players:number, minutes:number, by:Array<[number,number,number]>},
 *          openers?:Array<{pre:number[], pull?:number[], post:number[]}>,
 *          bosses?:Array<{name:string, dur:number, casts:Array<Array<[number,number]>>}>}} input
 *   bosses: per boss the fight length (ms) and per player his casts [spell, ms after the pull]
 *   other: the casts of the other activity, to compare the fillers
 * @param {{cd:(id:number)=>number, isItem:(id:number)=>boolean,
 *          isDamage:(id:number)=>boolean, nameOf:(id:number)=>string,
 *          procFrom?:(id:number)=>number|null, lasts?:(id:number)=>number,
 *          isMulti?:(id:number)=>boolean, manaPct?:(id:number)=>number,
 *          isUtility?:(id:number)=>boolean, isEffect?:(id:number)=>boolean,
 *          isMana?:(id:number)=>boolean, isEmpower?:(id:number)=>boolean,
 *          isSummon?:(id:number)=>boolean, spends?:(id:number)=>string|null,
 *          isForeign?:(id:number)=>boolean, healsVia?:(id:number)=>number|null,
 *          notInBuild?:(id:number)=>boolean, isTool?:(id:number)=>boolean,
 *          isPersonal?:(id:number)=>boolean, isExternal?:(id:number)=>boolean}} game
 *   notInBuild: a talent the measured build does not take;
 *   isTool: movement or a dispel; isPersonal: protects only the healer;
 *   isExternal: protects or saves one ally;
 *   healsVia: the talent through which this damage spell heals, or null;
 *   isEffect: a cast no player presses (a passive talent's effect);
 *   isForeign: not the class's own (a racial like Shadowmeld) - no line;
 *   spends: the secondary resource it costs ("holy_power"), or null
 *   procFrom: the spell a visible buff replaces with this one, -1 when the
 *   game names none; lasts: seconds
 * @returns {object|null} the guide, or null without a measurement
 */
function guide(input, game) {
  const c = input && input.casts;
  if (!c || !(c.players > 0) || !(c.minutes > 0)) return null;
  // One spell, one entry: two IDs of Flame Shock are one spell to a player.
  // The presses of a cooldown are those of the ID that carries it: the log
  // writes Divine Hymn's and Tranquility's every tick under another ID of
  // the same name (26 October).
  const byName = new Map();
  for (const [id, n, wer] of c.by) {
    const k = game.nameOf(id) || String(id);
    const e = byName.get(k) || { id, n: 0, wer: 0, nCd: 0 };
    e.wer = Math.max(e.wer, wer);
    if (n > e.n) { e.n = n; e.id = id; }
    if (game.ownCd && game.ownCd(id) > 0) e.nCd = Math.max(e.nCd, n);
    byName.set(k, e);
  }
  const avgSec = (c.minutes * 60) / c.players;
  const rows = [...byName.values()].map((e) => {
    const cd = game.cd(e.id) || 0;
    const possible = cd > 0 ? c.players * (Math.floor(avgSec / cd) + 1) : 0;
    const presses = e.nCd || e.n;
    return {
      s: e.id, cd, share: e.wer / c.players, cpm: e.n / c.minutes, per: presses / c.players,
      use: possible ? Math.min(100, Math.round((100 * presses) / possible)) : undefined,
      // Pressed how many times more often than the cooldown allows.
      ueber: possible ? presses / possible : 0,
    };
  });
  const pct = (r) => Math.round(r.share * 100);
  const round1 = (x) => Math.round(x * 10) / 10;
  const items = rows.filter((r) => game.isItem(r.s) && r.share >= ITEM_SHARE)
    .sort((a, b) => b.share - a.share)
    .map((r) => ({ s: r.s, pct: pct(r), per: round1(r.per), use: r.use }));
  // A talent the build does not take - the other half of a choice node
  // (Revival against Restoral) - is no button of this guide, unless nearly
  // every top healer casts it all the same (26 October).
  const fremd = (r) => (game.isForeign && game.isForeign(r.s)) || (game.notInBuild && game.notInBuild(r.s) && r.share < 0.75);
  const spells = rows.filter((r) => !game.isItem(r.s) && !fremd(r));
  // THE PRIORITY.
  const procFrom = game.procFrom || (() => null);
  const lasts = game.lasts || (() => 0);
  // A proc of this spec: the spell it stands in for is one these players
  // cast themselves (not an aura of another class), and not itself.
  const echterProc = (r) => {
    const pf = procFrom(r.s);
    if (!pf) return false;
    if (pf < 0) return true;
    return game.nameOf(pf) !== game.nameOf(r.s) && byName.has(game.nameOf(pf));
  };
  // FASTER THAN ITS COOLDOWN (26 October): Holy Word: Serenity has a minute
  // and goes out eight times a minute - other spells cut it down. Pressed
  // two and a half times as often as its cooldown allows, it is part of the
  // play, no big cooldown.
  const kurz = (r) => r.cd < CD_FROM || r.ueber >= 2.5;
  const procs = spells.filter((r) => kurz(r) && r.share >= CORE_SHARE && r.cpm >= PROC_CPM && echterProc(r)
    && !game.isDamage(r.s)).map((r) => ({ k: 'proc', s: r.s, from: procFrom(r.s) > 0 ? procFrom(r.s) : undefined, pct: pct(r), cpm: round1(r.cpm) }));
  const istProc = new Set(procs.map((p) => p.s));
  const ist = (f, id) => Boolean(game[f] && game[f](id));
  const alleKern = spells.filter((r) => kurz(r) && r.share >= CORE_SHARE && r.cpm >= CORE_CPM && !istProc.has(r.s)
    && !ist('isEffect', r.s));
  const werkzeug = (r) => Boolean(game.isUtility && game.isUtility(r.s));
  const kern = alleKern.filter((r) => !werkzeug(r));
  const sit = alleKern.filter(werkzeug).sort((a, b) => b.cpm - a.cpm)
    .map((r) => ({ k: 'sit', s: r.s, pct: pct(r), cpm: round1(r.cpm) }));
  const manaRows = kern.filter((r) => ist('isMana', r.s)).map((r) => ({ k: 'mana', s: r.s, pct: pct(r), cpm: round1(r.cpm) }));
  // A secondary resource is the spec's own when two or more of its measured
  // spells spend it: Holy Power, Essence. Rising Sun Kick costing Chi for the
  // Windwalker makes no Mistweaver a Chi spender.
  const resZahl = new Map();
  for (const r of spells) { const x = game.spends && game.spends(r.s); if (x) resZahl.set(x, (resZahl.get(x) || 0) + 1); }
  const eigeneRes = (id) => { const x = game.spends && game.spends(id); return x && resZahl.get(x) >= 2 ? x : null; };
  const spendRows = kern.filter((r) => !ist('isMana', r.s) && !game.isDamage(r.s) && eigeneRes(r.s))
    .sort((a, b) => b.cpm - a.cpm)
    .map((r) => ({ k: 'spend', s: r.s, res: eigeneRes(r.s), pct: pct(r), cpm: round1(r.cpm) }));
  const istSonder = new Set([...manaRows, ...spendRows].map((x) => x.s));
  const heilt = kern.filter((r) => !game.isDamage(r.s) && !istSonder.has(r.s));
  const mitCd = heilt.filter((r) => r.cd >= 4).sort((a, b) => (b.use || 0) - (a.use || 0)).map((r) => {
    // Kept up: a totem or summon that lasts about as long as its cooldown
    // (Surging Totem 24 of 25 seconds). A HoT lasting three cooldowns
    // (Riptide) or a beacon of a few seconds is one to use on cooldown.
    const quote = r.cd > 0 ? lasts(r.s) / r.cd : 0;
    const oft = (r.use || 0) >= ON_CD_USE;
    const keep = oft && ist('isSummon', r.s) && quote >= KEEP_RATIO && quote <= 1.5;
    const k = keep ? 'keep' : oft && ist('isEmpower', r.s) ? 'emp' : oft ? 'oncd' : 'reg';
    return { k, s: r.s, pct: pct(r), cpm: round1(r.cpm), use: r.use };
  });
  // Raid against M+, by name.
  const andere = new Map();
  const o = input.other;
  if (o && o.players > 0 && o.minutes > 0) {
    for (const [id, n] of o.by) {
      const k = game.nameOf(id);
      andere.set(k, Math.max(andere.get(k) || 0, n / o.minutes));
    }
  }
  const vergleich = (r) => {
    const x = andere.get(game.nameOf(r.s));
    if (!x) return undefined;
    if (r.cpm >= VS_RATIO * x) return 'more';
    if (r.cpm * VS_RATIO <= x) return 'less';
    return undefined;
  };
  // Without a cooldown, cast about once per its own duration: kept up on
  // one target (Lifebloom, 15 seconds, every 15 seconds) - no filler.
  // Only a HoT that may run on ONE target at a time (Lifebloom) is kept up:
  // Enveloping Mist goes on whoever needs it (26 October).
  const einmalJeDauer = (r) => {
    const q = (r.cpm * lasts(r.s)) / 60;
    return lasts(r.s) > 0 && q >= 0.6 && q <= 1.5 && (!game.isHot || game.isHot(r.s))
      && (!game.isOneAtATime || game.isOneAtATime(r.s));
  };
  const halten = heilt.filter((r) => r.cd < 4 && einmalJeDauer(r))
    .map((r) => ({ k: 'keep', s: r.s, pct: pct(r), cpm: round1(r.cpm) }));
  const istHalten = new Set(halten.map((x) => x.s));
  const fueller = heilt.filter((r) => r.cd < 4 && !istHalten.has(r.s)).sort((a, b) => b.cpm - a.cpm).slice(0, MAX_FILL);
  const mana = (id) => (game.manaPct ? game.manaPct(id) : 0) || 0;
  const fill = fueller.map((r, i) => {
    // Dearer or cheaper than the other fillers - only where it is clear.
    const anderer = fueller.filter((x) => x !== r).map((x) => mana(x.s)).filter((m) => m > 0);
    const m = mana(r.s);
    let cost;
    if (m > 0 && anderer.length) {
      if (anderer.every((a) => m >= 1.5 * a)) cost = 'high';
      else if (anderer.every((a) => m * 1.5 <= a)) cost = 'low';
    }
    // A HoT is spread, not "filled with" (Rejuvenation).
    const multi = game.isMulti ? Boolean(game.isMulti(r.s)) : undefined;
    const hot = !multi && game.isHot && game.isHot(r.s) ? true : undefined;
    return { k: 'fill', s: r.s, pct: pct(r), cpm: round1(r.cpm), first: i === 0 || undefined,
      multi, hot, cost, vs: vergleich(r) };
  });
  // Damage pressed on cooldown is part of the play (the Mistweaver's Rising
  // Sun Kick): "on cooldown", with the heals. The rest is damage in between.
  const schadenAufCd = (r) => r.cd >= 4 && (r.use || 0) >= ON_COOLDOWN;
  // Damage that heals through a talent (Atonement, Way of the Crane) says
  // so, with the talent: "Through Atonement your damage heals as well".
  const heiltMit = (id) => (game.healsVia ? game.healsVia(id) : null) || undefined;
  const dmgCd = kern.filter((r) => game.isDamage(r.s) && schadenAufCd(r))
    .map((r) => ({ k: 'oncd', s: r.s, via: heiltMit(r.s), pct: pct(r), cpm: round1(r.cpm), use: r.use }));
  const dmg = kern.filter((r) => game.isDamage(r.s) && !schadenAufCd(r)).sort((a, b) => b.cpm - a.cpm).slice(0, MAX_DMG)
    .map((r) => ({ k: heiltMit(r.s) ? 'dmgheal' : 'dmg', via: heiltMit(r.s), s: r.s, pct: pct(r), cpm: round1(r.cpm) }))
    .sort((a, b) => (a.k === 'dmgheal' ? 0 : 1) - (b.k === 'dmgheal' ? 0 : 1));
  const prio = [...procs, ...mitCd.filter((x) => x.k !== 'reg'), ...dmgCd, ...halten, ...spendRows, ...mitCd.filter((x) => x.k === 'reg'),
    ...fill, ...manaRows, ...dmg, ...sit].slice(0, MAX_CORE + MAX_DMG + 2);
  // A cooldown that neither heals nor protects - Dash, Ursol's Vortex,
  // Shadowmeld, Mass Dispel, Heroism - is a tool, no healing cooldown: it
  // goes last, in one line, and has no minute in the boss plan (26 October).
  // What top healers press on cooldown is part of the play, whatever its
  // text says (Power Infusion, Holy Bulwark).
  const cdRows = spells.filter((r) => !kurz(r) && r.share >= CD_SHARE)
    .sort((a, b) => (b.use || 0) - (a.use || 0));
  // Moving while casting and removing a debuff are tools, however often
  // they are pressed (Spiritwalker's Grace, Cauterizing Flame).
  const toolCd = (r) => ist('isTool', r.s) || (werkzeug(r) && (r.use || 0) < ON_COOLDOWN);
  // WHOM IT PROTECTS (26 October): the healer's own defensives (Barkskin,
  // Divine Protection, Fortifying Brew) are no healing cooldowns - one line
  // "to protect yourself"; one for a single ally (Life Cocoon, Pain
  // Suppression, Lay on Hands) is held for an ally in trouble, however
  // often the top healers find one.
  const art = (r) => (toolCd(r) ? 'tool' : ist('isPersonal', r.s) ? 'self' : ist('isExternal', r.s) ? 'ext'
    : game.isDamage(r.s) && !heiltMit(r.s) ? 'dmg' : ist('isMana', r.s) ? 'mana' : undefined);
  const RANG_CD = { ext: 1, self: 2, tool: 3 };
  const cds = cdRows.map((r) => ({ r, k: art(r) }))
    .sort((a, b) => (RANG_CD[a.k] || 0) - (RANG_CD[b.k] || 0))
    .map(({ r, k }) => ({ s: r.s, pct: pct(r), per: round1(r.per), use: r.use, k,
      via: game.isDamage(r.s) ? heiltMit(r.s) : undefined }));
  const ohnePlan = new Set(cds.filter((x) => x.k === 'tool' || x.k === 'self').map((x) => x.s));

  // The pull: only the spells of this guide, in the order most follow.
  let open;
  const known = new Set([...prio, ...cds].map((r) => r.s));
  const sameAs = new Map([...byName.values()].map((e) => [game.nameOf(e.id), e.id]));
  const eigen = (id) => sameAs.get(game.nameOf(id));
  const einmal = (list) => list.filter((id, i) => id !== list[i - 1]);
  const seqs = (input.openers || []).map((q) => ({
    pre: einmal((q.pre || []).map(eigen).filter((id) => known.has(id))),
    post: einmal([...(q.pull || []), ...(q.post || [])].map(eigen).filter((id) => known.has(id))),
  }));
  if (seqs.length >= 5) {
    const post = opener.typical(seqs.map((q) => q.post), { max: 6 });
    const pre = opener.typical(seqs.map((q) => q.pre), { fromEnd: true, max: opener.MAX_PRE });
    if (post.length >= 2) open = { n: seqs.length, pre, post };
  }

  // The bosses: when the cooldowns go out.
  const bosses = [];
  for (const b of input.bosses || []) {
    const players = b.casts.length;
    if (players < 3) continue;
    const plan = [];
    for (const r of cdRows.filter((x) => (x.use || 0) < ON_COOLDOWN && !ohnePlan.has(x.s))) {
      if (plan.length >= MAX_BOSS_CDS) break;
      const k = game.nameOf(r.s);
      // Each player's uses: casts of this name, one within 1.5 seconds.
      const uses = b.casts.map((pc) => {
        const ms = pc.filter(([id]) => game.nameOf(id) === k).map(([, t]) => t).sort((x, y) => x - y);
        return ms.filter((t, i) => i === 0 || t - ms[i - 1] > SAME_CAST_MS);
      });
      const times = [];
      for (let i = 0; i < 6; i += 1) {
        const t = uses.map((u) => u[i]).filter((x) => x !== undefined);
        if (t.length < Math.ceil(players / 2)) break;
        times.push(Math.round(median(t) / 1000));
      }
      if (times.length) plan.push({ s: r.s, t: times.sort((x, y) => x - y) });
    }
    if (plan.length) bosses.push({ name: b.name, dur: Math.round(b.dur / 1000), n: players, cds: plan });
  }

  return {
    heal: true,
    n: c.players,
    prio, cds,
    items: items.length ? items : undefined,
    opener: open,
    bosses: bosses.length ? bosses : undefined,
  };
}

module.exports = { guide, ON_COOLDOWN, AIMED };
