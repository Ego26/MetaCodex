// Gleiche Ware, verschiedene Handwerksstufen, ein Eintrag.
//
// "Thalassian Phoenix Oil" stand zweimal in der Liste, mit 74 % und
// 13 % - das sind zwei Stufen desselben Oels mit verschiedenen IDs.
// Zweimal derselbe Name in einer Liste ist keine Auskunft, sondern eine
// Frage.
//
// Die Anteile werden addiert: wer die eine Stufe benutzt, benutzt nicht
// zugleich die andere. Und die ID der HAEUFIGSTEN Stufe bleibt stehen,
// denn die will man kaufen.
//
// WARUM DAS EINE EIGENE DATEI IST. Genau diese Auswahl war falsch, und
// zwar an einer Zeile:
//
//     if (!known) { byName.set(key, { ...c }); continue; }
//     ...
//     if ((c.pct || 0) > (known.__top || 0)) { known.id = c.id; ... }
//
// Beim ERSTEN Eintrag wurde `__top` nie gesetzt. Beim zweiten war
// `c.pct > 0` damit immer wahr, und die ID wurde durch die zuletzt
// gesehene Stufe ersetzt - egal wie selten sie war. Im Fenster stand
// dann die Silberstufe mit dem Anteil, den in Wahrheit die Goldstufe
// getragen hat.
//
// Eine Auswahlregel, die man nicht nachrechnen kann, faellt genau so
// aus. Jetzt liegt sie hier und hat einen Test.

/**
 * @param {Array<{id:number,name?:string,pct?:number,maxKey?:number}>} rows
 * @returns {Array} zusammengelegt, haeufigste zuerst
 */
function mergeTiers(rows) {
  const byName = new Map();
  for (const c of rows || []) {
    // Zeilen ohne ID sind Reste aus der Zeit, in der ich glaubte, die
    // Speise sei nicht bestimmbar. Sie ist es - ueber die Wirkung. Was
    // keine ID hat, kann man nicht kaufen und gehoert nicht in eine
    // Einkaufsliste.
    if (!c.id) continue;
    const key = c.name || ('#' + c.id);
    const known = byName.get(key);
    if (!known) {
      // Der Anteil DIESER Stufe, damit die naechste sich daran messen
      // kann. Ohne ihn gewinnt immer die letzte.
      byName.set(key, { ...c, top: c.pct || 0 });
      continue;
    }
    known.pct = (known.pct || 0) + (c.pct || 0);
    known.maxKey = Math.max(known.maxKey || 0, c.maxKey || 0);
    if ((c.pct || 0) > known.top) {
      known.id = c.id;
      known.name = c.name || known.name;
      known.top = c.pct || 0;
    }
  }

  return [...byName.values()]
    .map((c) => {
      const out = { ...c };
      // Die Hilfszahl gehoert nicht in die ausgelieferte Datei.
      delete out.top;
      // Ein Netz gegen Doppelzaehlung: ueber hundert Prozent gibt es
      // nicht, und eine solche Zahl im Fenster kostet mehr Vertrauen,
      // als die Zeile wert ist.
      out.pct = Math.min(100, c.pct || 0);
      return out;
    })
    // Unter einem Prozent ist Rauschen. Solche Zeilen standen mit "0 %"
    // in der Liste und sagten nichts.
    .filter((c) => (c.pct || 0) >= 1)
    .sort((a, b) => b.pct - a.pct);
}

module.exports = { mergeTiers };
