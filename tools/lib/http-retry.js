// Wann eine fehlgeschlagene Abfrage noch einmal gestellt wird.
//
// Der Nachtlauf vom 8. Oktober 2026 ist nach 143 Minuten an einem
// einzigen "504 Gateway Timeout" von wago.tools gestorben. Zwei Stunden
// gesammelte Raiddaten waren da schon geschrieben; raid-normal fiel
// trotzdem weg, weil ein einzelner Abruf des Katalogs die ganze
// Aktivitaet mitgerissen hat.
//
// Die Regel steht hier und nicht im Sammler, weil sie eine Entscheidung
// ist und keine Mechanik - und Entscheidungen gehoeren geprueft.

/**
 * Lohnt sich ein zweiter Versuch?
 *
 * 5xx heisst: beim Gegenueber ist etwas schiefgegangen. Das sagt nichts
 * ueber unsere Anfrage, und sie noch einmal zu stellen ist die richtige
 * Antwort darauf.
 *
 * 4xx heisst: unsere Anfrage war falsch oder unerwuenscht. Die zu
 * wiederholen hiesse, dieselbe falsche Frage lauter zu stellen - und bei
 * 403 oder 429 waere es ausserdem unhoeflich.
 *
 * Ohne Status ist es ein Netzfehler: abgebrochene Verbindung,
 * Namensaufloesung, Zeitueberschreitung. Auch das geht vorbei.
 *
 * @param {Error & { statusCode?: number }} err
 * @returns {boolean}
 */
function worthRetrying(err) {
  if (!err) return false;
  const code = Number(err.statusCode);
  if (!code) return true;
  return code >= 500;
}

// Kurz, laenger, lang. Ein Dienst, der gerade ueberlastet ist, braucht
// mehr als eine Sekunde - und wer sofort nachsetzt, macht es schlimmer.
//
// Die vierte Wartezeit kam am 10. Oktober dazu. wago.tools antwortete
// dreimal mit 504, und nach 85 Sekunden war die Geduld zu Ende - die
// Stoerung war es noch nicht. Vier Minuten warten kostet nichts, wenn
// der Dienst laeuft, und rettet eine Nacht, wenn er kurz haengt.
const WAITS = [5, 20, 60, 180];

/**
 * Wie lange vor dem naechsten Versuch gewartet wird, in Sekunden.
 * @param {number} attempt  0 beim ersten Fehlschlag
 * @returns {number}
 */
function waitSeconds(attempt) {
  return WAITS[attempt] || WAITS[WAITS.length - 1];
}

module.exports = { worthRetrying, waitSeconds, WAITS };
