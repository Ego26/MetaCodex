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
// A PROC OR FOR GOOD (21 October). A proc that lasts "until used" (Coup de
// Grace over Dispatch, Hammer of Wrath over Judgment) and a replacement for
// good (Ancestral Swiftness) share attributes and the endless duration. Two
// fields tell them apart: a proc is a buff the player sees, with a buff text
// ("Able to perform a Coup de Grace."); and the effect's second value is 2
// for a replacement in the spellbook (Ancestral Swiftness, Wither, Drain
// Soul), 0 for one on the action bar only, which comes and goes (Shadowburn
// over Conflagrate below 20 percent health, Holy Armaments over Divine Toll:
// the lists cast both).
//
// So a talent's "Replaces ...", the spec's own spells and a hidden passive
// that replaces in the spellbook always count. Only a visible buff needs the logs: if hardly anyone casts
// the old spell and many cast the new one, it is replaced; without a
// measurement it is not. The logs never overrule the others - their shares
// are the whole spec's, every hero tree mixed: half the Elementals play
// Stormbringer and cast Nature's Swiftness, the Farseer half never does.
//
// Compared by NAME, not by ID: the list's Flame Shock can be another ID of
// the same spell than the one Voltaic Blaze names. A replacement by a spell
// of the same name (a spec's own version) is no replacement.

/**
 * @param {{auras: Array<{carrier:number, old:number, neu:number, book?:boolean}>,
 *          traits: Array<{old:number, neu:number}>,
 *          specs: Array<{spec:number, old:number, neu:number}>,
 *          lastsMs: (id:number) => number,
 *          buffText?: (id:number) => string}} src
 * @returns {Map<number, Array<{neu:number, spec?:number, from:string, proc?:boolean}>>} old -> replacements
 */
function buildReplacements(src) {
  const map = new Map();
  const add = (old, neu, spec, from, proc) => {
    if (!(old > 0 && neu > 0) || old === neu) return;
    if (!map.has(old)) map.set(old, []);
    map.get(old).push(proc ? { neu, spec, from, proc } : { neu, spec, from });
  };
  const buffText = src.buffText || (() => '');
  for (const a of src.auras) {
    if (src.lastsMs(a.carrier) > 0) continue;
    add(a.old, a.neu, undefined, 'aura ' + a.carrier, Boolean(buffText(a.carrier)) || !a.book);
  }
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
  return new Set(replacementsOf(map, build).keys());
}

/**
 * The same, with what replaces each name: old name -> the new spell's ID.
 * A passive "replacement" replaces no button (Clawing Shadows, now a
 * passive, took Scourge Strike off the Unholy guide - 26 October).
 * @param {{isPassive?:(id:number)=>boolean}} build  besides replacedNames' fields
 * @returns {Map<string, number>}
 */
function replacementsOf(map, build) {
  const out = new Map();
  // Which replacement names the line: the spec's own version, then the
  // talent's (Final Verdict for Templar's Verdict), then an aura's - an
  // aura put Wake of Ashes in Templar's Verdict's place (26 October).
  // A spell the list casts by its own name stands in no other's place: Wake
  // of Ashes is a trait override of Templar's Verdict too, and its own line.
  const eigen = (r) => (build.inList && build.inList(build.nameOf(r.neu)) ? 3 : 0);
  const rang = (r) => eigen(r) + (r.from === 'spec' ? 0 : r.from === 'trait' ? 1 : 2);
  for (const [old, liste] of map) {
    const oldName = build.nameOf(old);
    if (!oldName) continue;
    for (const r of [...liste].sort((a, b) => rang(a) - rang(b))) {
      // A spec's own spell counts for that spec only; anything else when the
      // build has it.
      const has = r.spec !== undefined ? r.spec === build.specID : build.known(r.neu);
      if (!has || build.nameOf(r.neu) === oldName) continue;
      if (build.isPassive && build.isPassive(r.neu)) continue;
      // "Rising Sun Kick has a 20 % chance to become Rushing Wind Kick": a
      // chance replaces nothing - Windwalker lost Rising Sun Kick to it.
      if (build.byChance && build.byChance(old, r.neu)) continue;
      if (!r.proc) {
        if (!out.has(oldName)) out.set(oldName, r.neu);
        continue;
      }
      // A visible buff: the logs decide - hardly anyone casts the old one,
      // many the new one. Not measured: it proves nothing.
      const alt = build.share ? build.share(oldName) : null;
      const neu = build.share ? build.share(build.nameOf(r.neu)) : null;
      if (alt !== null && neu !== null && alt < REPLACED_BELOW && neu >= REPLACING_FROM && !out.has(oldName)) out.set(oldName, r.neu);
    }
  }
  return out;
}

// Below this share the old spell counts as gone; from this one the new as used.
const REPLACED_BELOW = 0.05;
const REPLACING_FROM = 0.25;

module.exports = { buildReplacements, replacedNames, replacementsOf, REPLACED_BELOW, REPLACING_FROM };
