// Wie viele Gegenstaende je Platz in die Daten kommen.
//
// Bis zum 18. November schnitten die Sammler nach den fuenf
// meistgetragenen ab. Im Fenster "Beliebt" laesst sich aber nach Fundort
// filtern, und in M+ tragen die Besten vor allem Raid-Schmuck: bei 22 von
// 40 Specs stand unter den fuenf kein einziges Dungeon-Schmuckstueck. Wer
// "Alle Dungeons" waehlte, las dann "Niemand traegt etwas von hier" - und
// das war falsch. Getragen wurden sie, nur eben auf Platz sechs und
// dahinter.
//
// Die Regel seitdem: JEDE Filterstufe hat ihre eigenen fuenf. Alle
// Fundorte, alle Dungeons, ein Dungeon, ein Boss, das Handwerk. Dafuer
// genuegt es, je FEINSTER Quelle die fuenf meistgetragenen zu behalten -
// je Boss bei der Beute, je Art beim Rest - und dazu die fuenf insgesamt.
// Jede groebere Stufe steckt darin: ein Stueck unter den fuenf eines
// Dungeons hat in seinem Dungeon weniger als fuenf vor sich, in seinem
// Boss also erst recht.

'use strict';

const JE_QUELLE = 5;

/**
 * Behaelt die meistgetragenen Stuecke insgesamt und je Quelle.
 *
 * @param {Array<{id:number, pct:number}>} rows  absteigend nach Anteil
 *   oder nicht - sortiert wird hier
 * @param {(row:object) => string} bucketOf  die feinste Quelle eines
 *   Stuecks, z. B. "enc:2650", "craft", "other"
 * @param {number} [n]  wie viele je Quelle
 * @returns {Array} dieselben Zeilen, gekuerzt, absteigend nach Anteil
 */
function trimGear(rows, bucketOf, n = JE_QUELLE) {
  const sorted = (rows || []).slice().sort((a, b) => (b.pct || 0) - (a.pct || 0));
  const perBucket = {};
  return sorted.filter((row, i) => {
    const key = bucketOf(row);
    perBucket[key] = (perBucket[key] || 0) + 1;
    return i < n || perBucket[key] <= n;
  });
}

/**
 * Die feinste Quelle eines Stuecks, so wie das Addon filtert.
 *
 * Beute: der Boss aus dem Journal. Sonst die Art, die die Quelle oder
 * die Handwerksdaten nennen.
 *
 * @param {Record<string, {enc:number, inst:number}>} journal  journal-drops.json
 * @param {Set<number>} crafted  Handwerksstuecke
 */
function bucketBy(journal, crafted) {
  return (row) => {
    const j = journal[row.id];
    if (j) return 'enc:' + j.enc;
    if (row.kind) return row.kind;
    if (crafted.has(Number(row.id))) return 'craft';
    return 'other';
  };
}

module.exports = { trimGear, bucketBy, JE_QUELLE };
