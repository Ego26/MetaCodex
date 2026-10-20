// What replaces what - so that a spell and its replacement never stand in
// the rotation side by side.
//
// The game keeps it in three places, and all three count:
//   TraitDefinition.OverridesSpellID   the talent's "Replaces ..." line:
//                                      Voltaic Blaze over Flame Shock
//   SpecializationSpells.OverridesSpellID   a spec's spell over the class's
//   SpellEffect, aura 332             Ancestral Swiftness over Nature's
//                                      Swiftness
//
// An aura replaces only while it holds. Ancestral Swiftness carries it on a
// spell without end; Tempest and Elementalist carry it on a proc of thirty
// seconds, and Lightning Bolt is replaced now and then, not for good. So an
// aura counts only when its carrier lasts forever.
//
// THE LOGS DECIDE where they can (20 October). No table tells a proc that
// lasts "until used" (Coup de Grace over Dispatch, Hammer of Wrath over
// Judgment) from a replacement for good (Ancestral Swiftness): same
// attributes, same endless duration. What the measured players cast does:
// if hardly anyone with this build casts the old spell and many cast the
// new one, it is replaced; if a fair share still casts the old one, it is
// not - whatever a table says. Without a measurement only the talent's own
// "Replaces ..." and the spec's spells count; an aura stays unproven.
//
// Compared by NAME, not by ID: the list's Flame Shock can be another ID of
// the same spell than the one Voltaic Blaze names. A replacement by a spell
// of the same name (a spec's own version) is no replacement.

/**
 * @param {{auras: Array<{carrier:number, old:number, neu:number}>,
 *          traits: Array<{old:number, neu:number}>,
 *          specs: Array<{spec:number, old:number, neu:number}>,
 *          lastsMs: (id:number) => number}} src
 * @returns {Map<number, Array<{neu:number, spec?:number}>>} old -> replacements
 */
function buildReplacements(src) {
  const map = new Map();
  const add = (old, neu, spec, from) => {
    if (!(old > 0 && neu > 0) || old === neu) return;
    if (!map.has(old)) map.set(old, []);
    map.get(old).push({ neu, spec, from });
  };
  for (const a of src.auras) if (!(src.lastsMs(a.carrier) > 0)) add(a.old, a.neu, undefined, 'aura ' + a.carrier);
  for (const t of src.traits) add(t.old, t.neu, undefined, 'trait');
  for (const s of src.specs) add(s.old, s.neu, s.spec, 'spec');
  return map;
}

/**
 * The names this build no longer casts.
 * @param {Map<number, Array<{neu:number, spec?:number}>>} map  from buildReplacements
 * @param {{specID:number, known:(id:number)=>boolean, nameOf:(id:number)=>string,
 *          share?:(name:string)=>number|null}} build  share: the part of the measured
 *          players who cast a spell of that name, or null without a measurement
 * @returns {Set<string>}
 */
function replacedNames(map, build) {
  const out = new Set();
  for (const [old, list] of map) {
    const oldName = build.nameOf(old);
    if (!oldName) continue;
    for (const r of list) {
      // A spec's own spell counts for that spec only; anything else when the
      // build has it.
      const has = r.spec !== undefined ? r.spec === build.specID : build.known(r.neu);
      if (!has || build.nameOf(r.neu) === oldName) continue;
      const alt = build.share ? build.share(oldName) : null;
      const neu = build.share ? build.share(build.nameOf(r.neu)) : null;
      if (alt !== null && neu !== null) {
        // Measured: hardly anyone casts the old one, many the new one.
        if (alt < REPLACED_BELOW && neu >= REPLACING_FROM) out.add(oldName);
        continue;
      }
      // Not measured: an aura proves nothing.
      if (String(r.from || '').startsWith('aura')) continue;
      out.add(oldName);
    }
  }
  return out;
}

// Below this share the old spell counts as gone; from this one the new as used.
const REPLACED_BELOW = 0.05;
const REPLACING_FROM = 0.25;

module.exports = { buildReplacements, replacedNames, REPLACED_BELOW, REPLACING_FROM };
