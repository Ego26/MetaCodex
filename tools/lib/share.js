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

// Mehrere Anteile, die zusammen genau hundert ergeben.
//
// share() rundet jede Zahl fuer sich, und das reicht, solange die Zeilen
// nichts miteinander zu tun haben. Beim Folianten haben sie: jeder
// Spieler waehlt in einer Reihe GENAU EINE Rune, die Anteile teilen also
// dieselbe Menge auf. Dann darf ihre Summe nicht 99 oder 101 sein -
// gemessen an 22 Speccs kam beides vor.
//
// Verteilt wird nach dem groessten Rest: erst alle abrunden, dann die
// fehlenden Punkte an die Zeilen mit dem groessten abgeschnittenen Rest.
// Das ist das uebliche Verfahren fuer Sitzverteilungen und hat die
// Eigenschaft, die hier zaehlt - es erfindet nichts, es entscheidet nur,
// wer den Rundungspunkt bekommt.
//
// Die beiden Regeln von share() gelten weiter: 100 nur, wenn es wirklich
// alle sind, 0 nur, wenn es wirklich keiner ist. Wo das Verfahren
// dagegen stossen wuerde, wird der Punkt eine Zeile weitergereicht.
//
// @param {number[]} zahlen die Zaehlungen, zusammen hoechstens `total`
// @param {number} total    die Menge, die sie aufteilen
// @returns {number[]} ganze Prozent in derselben Reihenfolge
function shares(zahlen, total) {
  const oben = Number(total) || 0;
  const roh = zahlen.map((x) => Number(x) || 0);
  if (oben <= 0) return roh.map(() => 0);

  const genau = roh.map((n) => (n / oben) * 100);
  const unten = genau.map((x) => Math.floor(x));
  // Nur verteilen, wenn die Zaehlungen die Menge wirklich ausschoepfen.
  // Tun sie es nicht - etwa weil eine Rune fehlt -, waere ein Auffuellen
  // auf hundert eine Behauptung.
  const gezaehlt = roh.reduce((a, b) => a + b, 0);
  const ziel = gezaehlt >= oben ? 100 : Math.round((gezaehlt / oben) * 100);
  let fehlt = ziel - unten.reduce((a, b) => a + b, 0);

  // Wer bekommt die uebrigen Punkte: groesster Rest zuerst.
  const reihenfolge = genau
    .map((x, i) => ({ i, rest: x - Math.floor(x) }))
    .sort((a, b) => b.rest - a.rest);

  const ergebnis = unten.slice();
  for (const { i } of reihenfolge) {
    if (fehlt <= 0) break;
    // Nicht auf 100 heben, wenn es nicht wirklich alle sind.
    if (ergebnis[i] + 1 >= 100 && roh[i] < oben) continue;
    ergebnis[i] += 1;
    fehlt -= 1;
  }

  // Und die Untergrenze: was gemessen wurde, steht nie auf null.
  for (let i = 0; i < ergebnis.length; i++) {
    if (roh[i] > 0 && ergebnis[i] === 0) {
      // Den Punkt beim Groessten holen, sonst waere die Summe wieder falsch.
      let groesster = -1;
      for (let j = 0; j < ergebnis.length; j++) {
        if (ergebnis[j] > 1 && (groesster < 0 || ergebnis[j] > ergebnis[groesster])) groesster = j;
      }
      if (groesster >= 0) { ergebnis[groesster] -= 1; ergebnis[i] = 1; }
    }
  }
  return ergebnis;
}

module.exports = { share, shares };
