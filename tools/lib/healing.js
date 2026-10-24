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
//   core    cast by most (60 %) at least once a minute, cooldown under a
//           minute - the frame of the rotation; damage spells apart
//   cds     a cooldown of a minute or more, cast by 40 %. How much of what
//           was possible got used says how: 85 % and more "as soon as
//           ready", 50 % "aimed", below "when needed"
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
 * @param {{cd:(id:number)=>number, isItem:(id:number)=>boolean,
 *          isDamage:(id:number)=>boolean, nameOf:(id:number)=>string}} game
 * @returns {object|null} the guide, or null without a measurement
 */
function guide(input, game) {
  const c = input && input.casts;
  if (!c || !(c.players > 0) || !(c.minutes > 0)) return null;
  // One spell, one entry: two IDs of Flame Shock are one spell to a player.
  const byName = new Map();
  for (const [id, n, wer] of c.by) {
    const k = game.nameOf(id) || String(id);
    const e = byName.get(k) || { id, n: 0, wer: 0 };
    e.wer = Math.max(e.wer, wer);
    if (n > e.n) { e.n = n; e.id = id; }
    byName.set(k, e);
  }
  const avgSec = (c.minutes * 60) / c.players;
  const rows = [...byName.values()].map((e) => {
    const cd = game.cd(e.id) || 0;
    const possible = cd > 0 ? c.players * (Math.floor(avgSec / cd) + 1) : 0;
    return {
      s: e.id, cd, share: e.wer / c.players, cpm: e.n / c.minutes, per: e.n / c.players,
      use: possible ? Math.min(100, Math.round((100 * e.n) / possible)) : undefined,
    };
  });
  const pct = (r) => Math.round(r.share * 100);
  const round1 = (x) => Math.round(x * 10) / 10;
  const items = rows.filter((r) => game.isItem(r.s) && r.share >= ITEM_SHARE)
    .sort((a, b) => b.share - a.share)
    .map((r) => ({ s: r.s, pct: pct(r), per: round1(r.per), use: r.use }));
  const spells = rows.filter((r) => !game.isItem(r.s));
  const kern = spells.filter((r) => r.cd < CD_FROM && r.share >= CORE_SHARE && r.cpm >= CORE_CPM)
    .sort((a, b) => b.cpm - a.cpm);
  const core = kern.filter((r) => !game.isDamage(r.s)).slice(0, MAX_CORE)
    .map((r) => ({ s: r.s, pct: pct(r), cpm: round1(r.cpm) }));
  const dmg = kern.filter((r) => game.isDamage(r.s)).slice(0, MAX_DMG)
    .map((r) => ({ s: r.s, pct: pct(r), cpm: round1(r.cpm) }));
  const cdRows = spells.filter((r) => r.cd >= CD_FROM && r.share >= CD_SHARE)
    .sort((a, b) => (b.use || 0) - (a.use || 0));
  const cds = cdRows.map((r) => ({ s: r.s, pct: pct(r), per: round1(r.per), use: r.use }));

  // The pull: only the spells of this guide, in the order most follow.
  let open;
  const known = new Set([...core, ...dmg, ...cds].map((r) => r.s));
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
    for (const r of cdRows.filter((x) => (x.use || 0) < ON_COOLDOWN)) {
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
    core, dmg: dmg.length ? dmg : undefined, cds,
    items: items.length ? items : undefined,
    opener: open,
    bosses: bosses.length ? bosses : undefined,
  };
}

module.exports = { guide, ON_COOLDOWN, AIMED };
