// SimC's own buff names, mapped to the game's spell IDs - read from SimC's
// class modules (engine/class_modules, GPL-3.0 like this addon).
//
// A list asks for buffs by SimC's name ("hammer_of_light_free",
// "lesser_ghoul_ready"); the game knows no spell by that name. Which spell
// it is stands in the source, in one of these forms:
//
//   make_buff( this, "hammer_of_light_free", find_spell( 433732 ) )
//   spell.lesser_ghoul_buff = conditional_spell_lookup( ..., 1254252 );
//   ... make_fallback( ..., "lesser_ghoul_ready", spell.lesser_ghoul_buff )
//   talents.nightfall_buff = find_spell( 264571 );   (another file)
//   ... make_buff( this, "nightfall", talents.nightfall_buff )
//
// So: first every member that is assigned a spell ID (the last number of
// four to eight digits on the right side), then every quoted buff name and
// the spell next to it - a find_spell( N ) directly, or a member.

/**
 * @param {string} text  the class module source, all files of the class
 * @returns {Map<string, number>} SimC buff name -> spell ID
 */
function simcBuffMap(text) {
  const members = new Map();
  const memberRe = /([A-Za-z_][\w.>-]*)\s*=\s*([^;=]*?)\s*;/g;
  let m;
  while ((m = memberRe.exec(text))) {
    const rhs = m[2];
    if (!/\(/.test(rhs)) continue;
    const nums = rhs.match(/\b\d{4,8}\b/g);
    if (!nums) continue;
    const key = m[1].replace(/->/g, '.').split('.').slice(-2).join('.');
    members.set(key, Number(nums[nums.length - 1]));
  }
  const out = new Map();
  // The rest stops at the next quote: a line without ";" would otherwise run
  // into the next buff and swallow its name.
  const buffRe = /"([a-z0-9_]+)"\s*,\s*([^;"]{0,260})/g;
  while ((m = buffRe.exec(text))) {
    const name = m[1];
    if (out.has(name)) continue;
    const rest = m[2];
    const direct = rest.match(/^[^"]*?find_spell\s*\(\s*(\d{3,8})\s*\)/);
    if (direct) { out.set(name, Number(direct[1])); continue; }
    const head = rest.split('"')[0];
    const paths = head.match(/[A-Za-z_]+(?:(?:\.|->)[A-Za-z_]+)+/g) || [];
    for (const p of paths) {
      const key = p.replace(/->/g, '.').split('.').slice(-2).join('.');
      if (members.has(key)) { out.set(name, members.get(key)); break; }
    }
  }
  return out;
}

module.exports = { simcBuffMap };
