// The opener: what the measured players cast around the pull.
//
// Two halves, and both are measured, not written:
//
//   sequenceOf()  one player in one fight - the casts from twenty seconds
//                 before the pull to fifteen after. A cast that BEGAN
//                 before the pull and landed just after it is a precast
//                 (Lava Burst, Frostbolt): it belongs before the pull,
//                 directly at the mark.
//   typical()     many players - the order most of them follow. Position
//                 by position, among those who followed it so far; it
//                 stops where too few are left to say anything.
//
// Measured in raid fights only: there the fight starts with the pull. In a
// Mythic+ log the "fight" starts with the key, not with the first pack.
//
// WHAT THE LOG CANNOT SAY (checked on a real report, 20 October): Warcraft
// Logs returns nothing before the fight starts, and the fight starts with
// the first combat action. A precast therefore lands a few milliseconds
// AFTER the start - Stormkeeper at +77 ms - and its begincast is missing.
// So the casts of the first half second come apart as "at the pull";
// tools/build-rotation.js puts those that the SimulationCraft list casts
// before combat in front of the mark.

const PRE_MS = 20000;
const POST_MS = 15000;
// A cast that began before the pull counts as a precast when it lands
// within this time after it.
const PRECAST_MS = 3000;
// Casts landing this early after the start are "at the pull".
const PULL_MS = 500;
const MAX_PRE = 5;
const MAX_POST = 8;

/**
 * One player's casts around the pull.
 * @param {Array<{timestamp:number,type:string,abilityGameID:number}>} events  his events, any order
 * @param {number} start  the fight's start time
 * @returns {{pre:number[], pull:number[], post:number[]}}
 */
function sequenceOf(events, start) {
  const sorted = [...events].sort((a, b) => a.timestamp - b.timestamp);
  const pre = [];
  const pull = [];
  const post = [];
  const begun = new Map();
  for (const ev of sorted) {
    const t = ev.timestamp - start;
    const id = Number(ev.abilityGameID);
    if (!id || t < -PRE_MS || t > POST_MS) continue;
    if (ev.type === 'begincast') { begun.set(id, t); continue; }
    if (ev.type !== 'cast') continue;
    const began = begun.get(id);
    begun.delete(id);
    if (t < 0 || (began !== undefined && began < 0 && t <= PRECAST_MS)) pre.push(id);
    else if (t <= PULL_MS) pull.push(id);
    else post.push(id);
  }
  return { pre: pre.slice(-MAX_PRE), pull, post: post.slice(0, MAX_POST) };
}

/**
 * The order most players follow.
 * @param {number[][]} seqs  one list per player, already mapped and filtered
 * @param {{fromEnd?:boolean, max?:number, minCount?:number, minShare?:number}} opts
 *   fromEnd: build backwards from the last element (the casts before the pull,
 *   read from the mark outwards)
 * @returns {number[]}
 */
function typical(seqs, opts = {}) {
  const max = opts.max || MAX_POST;
  const minCount = opts.minCount || 5;
  const minShare = opts.minShare || 0.25;
  const total = seqs.length;
  let pool = seqs.map((s) => (opts.fromEnd ? [...s].reverse() : s));
  const out = [];
  for (let k = 0; k < max; k += 1) {
    const counts = new Map();
    for (const s of pool) if (s[k] !== undefined) counts.set(s[k], (counts.get(s[k]) || 0) + 1);
    let best = null;
    for (const [id, n] of counts) if (!best || n > best.n || (n === best.n && id < best.id)) best = { id, n };
    if (!best || best.n < minCount || best.n < total * minShare) break;
    out.push(best.id);
    pool = pool.filter((s) => s[k] === best.id);
  }
  return opts.fromEnd ? out.reverse() : out;
}

/**
 * Splits the casts at the pull: those the list casts before combat are
 * precasts, the rest open the fight.
 * @param {{pre:number[], pull?:number[], post:number[]}} seq  already mapped
 * @param {Set<number>} beforeCombat  spells the list casts before the pull
 */
function placePull(seq, beforeCombat) {
  const pre = [...seq.pre];
  const post = [];
  for (const id of seq.pull || []) (beforeCombat.has(id) ? pre : post).push(id);
  return { pre: pre.slice(-MAX_PRE), post: [...post, ...seq.post].slice(0, MAX_POST) };
}

module.exports = { sequenceOf, typical, placePull, PRE_MS, POST_MS, PRECAST_MS, PULL_MS, MAX_PRE, MAX_POST };
