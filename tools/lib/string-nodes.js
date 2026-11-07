// Die Talente eines Builds, wie sein String sie nennt.
//
// Warcraft Logs fuehrt einen Knoten mit mehreren Stufen als mehrere Zeilen, je
// Stufe mit eigener Nummer: 1270061 Rang 1, 1270062 Rang 2, 1270064 Rang 1. Das
// Spiel und der String kennen nur die letzte Stufe und zaehlen zusammen: 1270064
// Rang 4. Wer die Zeilen der Logs in die Vorschau gibt, bekommt die beiden
// anderen Nummern als "fehlt dir" und einen gruenen Rahmen auf einem Talent, das
// man laengst hat (7. November, jeder Build mit einem Apex-Talent).
//
// Der String ist die bessere Auskunft: vom Spiel geschrieben und in derselben
// Form wie bei raider.io. Gezaehlt wird weiter nach den Logs, nur was im Fenster
// steht, kommt von hier.

/**
 * @param {function(string): Array|null} decode String -> Knoten des Decoders
 * @param {string} text
 * @returns {Array<{spell: number, rank: number}>|null}
 */
function nodesOf(decode, text) {
  const nodes = text ? decode(text) : null;
  if (!nodes) return null;
  // Knoten ohne Zauber waehlen nur den Held-Baum aus.
  const out = nodes.filter((n) => n.spell).map((n) => ({ spell: n.spell, rank: n.rank }));
  return out.length ? out : null;
}

/**
 * Stellt einen Build und seine Alternativen auf die Knoten ihrer Strings um.
 * Was sich nicht lesen laesst, bleibt, wie es ist.
 * @param {{build?: object, builds?: Array}} view
 * @param {function(string): Array|null} decode
 */
function useStringNodes(view, decode) {
  if (!view || !view.build) return;
  const nodes = nodesOf(decode, view.build.text);
  if (!nodes) return;
  view.build.nodes = nodes;
  if (!view.builds) return;
  const top = new Set(nodes.map((n) => n.spell));
  const others = [];
  for (const other of view.builds) {
    const theirs = nodesOf(decode, other.text);
    if (!theirs) {
      others.push(other);
      continue;
    }
    const set = new Set(theirs.map((n) => n.spell));
    other.added = theirs.filter((n) => !top.has(n.spell)).map((n) => n.spell);
    other.removed = nodes.filter((n) => !set.has(n.spell)).map((n) => n.spell);
    // Nur die Stufe war anders: dann ist es kein anderer Build, den man nennen kann.
    if (other.added.length || other.removed.length) others.push(other);
  }
  view.builds = others;
}

module.exports = { nodesOf, useStringNodes };
