// Wer traegt dieses Stueck sonst noch?
//
// Die Messung liegt in einer Richtung vor: Spec -> Platz -> Stuecke. Die
// Frage im Tooltip geht andersherum - "fuer welche Klasse ist dieser
// Drop gut?" -, und sie ueber vierzig Speccs mal zehn Aktivitaeten bei
// jedem Ueberfahren einer Tasche zu beantworten, waere Verschwendung.
// Also wird die Umkehrung EINMAL beim Bauen gerechnet.
//
// Zwei Regeln entscheiden, was ueberhaupt hineinkommt, und beide sind
// gemessen und nicht geschaetzt:
//
//   MIN_SAMPLE - ohne bekannte Stichprobe keine Zeile. Am 13. Oktober
//   standen hinter "50 %" bei 2v2 genau zwei Spieler: einer von beiden
//   trug das Stueck. Daraus im Tooltip "auch gut fuer Elementar" zu
//   machen, waere eine Behauptung mit einer Zahl davor. Quellen, die
//   ihre Stichprobe nicht nennen, tragen deshalb nichts bei - lieber
//   eine Zeile weniger als eine erfundene.
//
//   WORN_AB - unter zwanzig Prozent ist es kein "gut fuer". Vier von
//   fuenf Spielern dieser Spec haben sich dann fuer etwas anderes
//   entschieden; das Stueck hatte jemand an, mehr sagt die Messung
//   nicht. Die Anteile reichen von 3 % bis 100 %, der Median liegt bei
//   14 - die Schwelle schneidet also die untere Haelfte weg, und was
//   bleibt, ist eine Aussage.

const MIN_SAMPLE = 15;
const WORN_AB = 20;

/**
 * Baut den Index Gegenstand -> wer traegt ihn.
 *
 * Je Spec bleibt der STAERKSTE Anteil ueber alle Aktivitaeten stehen,
 * mitsamt der Aktivitaet, in der er gemessen wurde. Zwei Zeilen fuer
 * dieselbe Spec ("62 % im Schlachtzug, 48 % in M+") beantworten keine
 * Frage, die im Tooltip eines Gegenstands gestellt wird - und die
 * Aktivitaet muss dabeistehen, sonst steht ein PvP-Anteil neben einem
 * Raid-Anteil und niemand sieht den Unterschied.
 *
 * @param {Object} byMode  Modusschluessel -> Quelle -> { specs: { id: entry } }
 * @returns {Map<number, {spec:number, pct:number, mode:string, sample:number}[]>}
 *   je Gegenstand, nach Anteil absteigend
 */
function wornBy(byMode) {
  // Gegenstand -> Spec -> bester Eintrag
  const index = new Map();

  for (const [mode, bySource] of Object.entries(byMode || {})) {
    // Ein Dungeon ist derselbe Modus, nur enger gefragt. Fuer "wer
    // traegt das" zaehlt die Gesamtmessung; sonst stuende dasselbe
    // Stueck achtmal da, einmal je Dungeon.
    if (mode.includes('/')) continue;
    for (const part of Object.values(bySource || {})) {
      for (const [specID, entry] of Object.entries((part && part.specs) || {})) {
        const sample = Number(entry.sample);
        if (!Number.isFinite(sample) || sample < MIN_SAMPLE) continue;
        const spec = Number(specID);
        for (const liste of Object.values(entry.gear || {})) {
          for (const row of liste || []) {
            if (!row || !row.id || !(row.pct >= WORN_AB)) continue;
            if (!index.has(row.id)) index.set(row.id, new Map());
            const proSpec = index.get(row.id);
            const alt = proSpec.get(spec);
            if (!alt || row.pct > alt.pct) {
              proSpec.set(spec, { spec, pct: row.pct, mode, sample });
            }
          }
        }
      }
    }
  }

  const out = new Map();
  for (const [itemID, proSpec] of index) {
    const liste = [...proSpec.values()]
      // Nach Anteil, bei Gleichstand nach Spec-Nummer: eine
      // Reihenfolge, die sich zwischen zwei Naechten nicht dreht, nur
      // weil zwei Zahlen gleich sind.
      .sort((a, b) => b.pct - a.pct || a.spec - b.spec);
    out.set(itemID, liste);
  }
  return out;
}

module.exports = { wornBy, MIN_SAMPLE, WORN_AB };
