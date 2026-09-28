// Ein Anteil in ganzen Prozent - ohne die beiden Luegen der Rundung.
//
// In den Ringen stand: Platz 1 mit 100 %, Platz 2 mit 1 %, Platz 3 mit
// 0 %. Das ergibt 101 und kann nicht sein. Es kam so zustande:
//
//   996 von 1000 Ringen       = 99,6 %  ->  gerundet 100
//     9 von 1000 Ringen       =  0,9 %  ->  gerundet   1
//     4 von 1000 Ringen       =  0,4 %  ->  gerundet   0
//
// Jede Zeile fuer sich richtig gerundet, zusammen unmoeglich. Schlimmer
// als die Summe ist aber, was die beiden Randwerte BEHAUPTEN:
//
//   100 % heisst "alle". Es waren nicht alle - die Zeilen darunter
//   beweisen es selbst.
//
//   0 % heisst "niemand". Das steht dann mitten in einer Liste dessen,
//   was die Gemessenen tragen, und ein Gegenstand, den niemand traegt,
//   haette dort nichts zu suchen.
//
// Also: 100 nur, wenn es wirklich alle sind. 0 nur, wenn es wirklich
// keiner ist. Alles dazwischen bleibt zwischen 1 und 99. Der Preis ist
// eine Ungenauigkeit von hoechstens einem Prozentpunkt an den beiden
// Enden; der Gewinn ist, dass keine Zahl etwas behauptet, was nicht
// gemessen wurde.
//
// Ganze Prozent und nicht eine Nachkommastelle: die Liste ist eng, und
// "99,6 %" sagt niemandem mehr als "99 %". Wichtig ist der Unterschied
// zwischen "fast alle" und "alle", und genau den macht das hier.
//
// @param {number} n     wie viele
// @param {number} total wie viele insgesamt
// @returns {number} 0 bis 100
function share(n, total) {
  const oben = Number(total) || 0;
  const wie_viele = Number(n) || 0;
  if (oben <= 0 || wie_viele <= 0) return 0;
  if (wie_viele >= oben) return 100;
  const pct = Math.round((wie_viele / oben) * 100);
  if (pct >= 100) return 99;
  if (pct <= 0) return 1;
  return pct;
}

module.exports = { share };
