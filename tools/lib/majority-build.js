// Der Build, der am besten zeigt, was die meisten spielen.
//
// Gezaehlt wurde bisher der haeufigste EXAKTE Build. Das klingt nach der
// richtigen Frage und ist es nicht: ein einziges anderes Talent macht einen
// neuen Build. Der Elementar-Schamane hatte im November 473 Spieler, und ihr
// "haeufigster Build" trug 5 % - mit Talenten, die die Mehrheit nicht nimmt.
//
// Mittelwerte gehen aber auch nicht: die Mehrheit je Knoten ergibt einen
// Baum, den vielleicht niemand spielt, vielleicht sogar einen, den das Spiel
// nicht zulaesst. Und einen String dazu haette er auch nicht.
//
// Also bleibt es beim Build eines echten Spielers, nur anders ausgesucht: der,
// dessen Talente insgesamt am haeufigsten gewaehlt werden. Sein String stammt
// vom Spiel, und niemand muss ihn nachbauen.

/**
 * Die Kandidaten aus einer Zaehlung von Signaturen ("spell:rang,spell:rang").
 * @param {Object<string, number>} builds Signatur -> Spieler
 * @returns {Array<{key: string, count: number, talents: string[]}>}
 */
function fromSignatures(builds) {
  return Object.entries(builds || {}).map(([key, count]) => ({
    key, count, talents: key.split(',').map((part) => part.replace(':', '|')),
  }));
}

/**
 * @param {Array<{key: string, count: number, talents: string[]}>} candidates
 * @param {Object<string, number>} popularity "spell|rang" -> Spieler
 * @param {number} denom wie viele Spieler gezaehlt wurden
 * @returns {{key: string, count: number, fit: number}|null} fit: wie viel
 *   Prozent seiner Talente die Mehrheit ebenfalls nimmt
 */
function pickMajority(candidates, popularity, denom) {
  if (!candidates || !candidates.length) return null;
  const total = Math.max(1, denom || 0);
  let best = null;
  for (const c of candidates) {
    let score = 0;
    let withMajority = 0;
    for (const talent of c.talents) {
      const share = (popularity[talent] || 0) / total;
      score += share;
      if (share >= 0.5) withMajority += 1;
    }
    // Gleichstand: der haeufigere, dann fest nach Schluessel - zwei Laeufe
    // auf denselben Daten sollen denselben Build nennen.
    const better = !best || score > best.score
      || (score === best.score && (c.count > best.count
        || (c.count === best.count && c.key < best.key)));
    if (better) {
      best = {
        key: c.key, count: c.count, score,
        fit: c.talents.length ? Math.round((withMajority / c.talents.length) * 100) : 0,
      };
    }
  }
  return { key: best.key, count: best.count, fit: best.fit };
}

/**
 * Die Alternativen: die haeufigsten anderen, wie gespielt.
 * @returns {Array} dieselben Kandidaten, haeufigste zuerst, ohne den gewaehlten
 */
function othersThan(candidates, key) {
  return (candidates || []).filter((c) => c.key !== key)
    .sort((a, b) => b.count - a.count || (a.key < b.key ? -1 : 1));
}

module.exports = { fromSignatures, pickMajority, othersThan };
