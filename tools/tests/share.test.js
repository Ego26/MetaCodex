// Anteile, die sich auf hundert summieren - nachgerechnet.
//
// Zweimal in einer Woche stand im Fenster eine Reihe, deren Zahlen
// zusammen 101 ergaben: erst die Ringe (100, 1, 0), dann Reihe 5 des
// Folianten (97, 4). Beide Male war jede Zahl fuer sich richtig
// gerundet und die Summe trotzdem unmoeglich.
//
// Was zweimal falsch war, bekommt einen Test.
const { share, shares } = require('../lib/share');

let failed = 0;
function check(what, got, want) {
  const ok = got === want;
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`
    + (ok ? '' : `  -> ${JSON.stringify(got)} statt ${JSON.stringify(want)}`));
}

console.log('share(): die beiden Raender');
check('alle sind alle', share(10, 10), 100);
check('fast alle sind nicht alle', share(996, 1000), 99);
check('keiner ist keiner', share(0, 10), 0);
check('fast keiner ist nicht keiner', share(4, 1000), 1);
check('ohne Grundlage keine Zahl', share(3, 0), 0);

console.log('');
console.log('shares(): zusammen genau hundert');

const summe = (xs) => xs.reduce((a, b) => a + b, 0);

// Der Fall, der das Ganze ausgeloest hat.
check('die Ringe ergeben 100', summe(shares([996, 9, 4], 1009)), 100);
check('und behaupten kein "alle"', shares([996, 9, 4], 1009)[0] <= 99, true);
check('und kein "niemand"', shares([996, 9, 4], 1009).every((x) => x >= 1), true);

// Reihe 5, wie sie wirklich gemessen wurde.
check('Elementar ergibt 100', summe(shares([101, 4, 1], 106)), 100);
check('Blutritter ergibt 100', summe(shares([98, 5, 3], 106)), 100);

// Eine einzige Rune, von allen genommen: hier IST hundert richtig.
check('eine Rune, alle Spieler', shares([106], 106)[0], 100);

// Drei genau gleiche: einer muss den Rundungspunkt bekommen.
check('drei gleiche ergeben 100', summe(shares([1, 1, 1], 3)), 100);

// Und wenn die Zaehlungen die Menge NICHT ausschoepfen, darf nicht auf
// hundert aufgefuellt werden - das waere eine Behauptung ueber Spieler,
// die niemand zugeordnet hat.
const luecke = shares([50, 25], 100);
check('eine Luecke bleibt eine Luecke', summe(luecke), 75);

// Nichts gemessen, nichts behauptet.
check('ohne Grundlage alles null', summe(shares([1, 2], 0)), 0);

console.log('');
console.log(failed === 0 ? 'alles gruen' : failed + ' Fehler');
process.exit(failed === 0 ? 0 : 1);
