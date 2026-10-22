// What each player cast in one fight, from the fight's cast events
// (23 October).
//
// The Casts TABLE of Warcraft Logs looked like the cheap way: one query,
// every player with "abilities". But that list is the summary's - the five
// most cast, nothing else. A top Elemental showed Lightning Bolt, Lava
// Burst, Chain Lightning, Elemental Blast and Flame Shock; Stormkeeper,
// Ascendance and Ancestral Swiftness were not there, and the nightly took
// them for "not played". The events of the fight hold every cast and cost
// the same: about two points for a raid boss with twenty players.

/**
 * @param {Array<{type:string, sourceID:number, abilityGameID:number}>} events
 * @param {Map<number, number>} specBySource  player actor -> spec ID
 * @returns {Map<number, {spec:number, by:Map<number, number>}>} actor -> casts per spell
 */
function castsBySource(events, specBySource) {
  const out = new Map();
  for (const ev of events || []) {
    if (ev.type !== 'cast') continue;
    const src = Number(ev.sourceID);
    const spec = specBySource.get(src);
    const g = Number(ev.abilityGameID);
    if (!spec || !g) continue;
    if (!out.has(src)) out.set(src, { spec, by: new Map() });
    const by = out.get(src).by;
    by.set(g, (by.get(g) || 0) + 1);
  }
  return out;
}

// A measurement in which fewer spells than this are cast by most players of
// a spec is a summary, not a measurement: no spell may fall out of a list
// for it (tools/build-rotation.js).
const MIN_SPELLS = 8;

module.exports = { castsBySource, MIN_SPELLS };
