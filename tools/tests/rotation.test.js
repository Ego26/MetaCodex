// Die Zaehlregeln der Rotation, nachgerechnet.
//
// Sie entscheiden, was im Fenster als "78 % oeffnen mit X" steht. Eine
// Zahl, die eine Rotation behauptet, muss stimmen - sonst drueckt jemand
// auf unser Wort hin das Falsche.
const { opener, rate, spread, MULTI_AB, anteil, median } = require('../lib/rotation');

let failed = 0;
function check(what, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`
    + (ok ? '' : `\n          bekommen: ${JSON.stringify(got)}`
      + `\n          erwartet: ${JSON.stringify(want)}`));
}

console.log('Opener: was an welcher Stelle gedrueckt wird');

// Drei Spieler, zwei oeffnen gleich.
{
  const p = [
    [{ spell: 1, t: 0 }, { spell: 2, t: 1000 }, { spell: 3, t: 2000 }],
    [{ spell: 1, t: 500 }, { spell: 2, t: 1500 }, { spell: 9, t: 2500 }],
    [{ spell: 7, t: 0 }, { spell: 2, t: 900 }],
  ];
  const o = opener(p, { stellen: 3 });
  check('erste Stelle: zwei von drei mit Zauber 1',
    o[0].zauber[0], { spell: 1, n: 2, pct: 67 });
  check('zweite Stelle: alle drei einig',
    o[1].zauber, [{ spell: 2, n: 3, pct: 100 }]);
  check('dritte Stelle: nur zwei Spieler kamen so weit', o[2].spieler, 2);
}

// WER NACH ZWANZIG SEKUNDEN DRUECKT, IST NICHT MEHR IM OPENER.
{
  const p = [[{ spell: 1, t: 0 }, { spell: 2, t: 100 }, { spell: 3, t: 60000 }]];
  const o = opener(p, { stellen: 5, fenster: 15000 });
  check('spaete Wuerfe zaehlen nicht mehr', o.length, 2);
}

// Ein Spieler ohne Wuerfe sprengt nichts.
check('leere Liste ergibt nichts', opener([[], null]), []);

console.log('Verteilung: Wuerfe je Minute');

// Zwei Spieler, verschieden lange Kaempfe: der Median, nicht der
// Mittelwert. Ein Kampf von drei Minuten darf einen von einer nicht
// ueberstimmen.
{
  const p = [
    { dauer: 60000, wuerfe: [{ spell: 1, t: 0 }, { spell: 1, t: 1 }, { spell: 2, t: 2 }] },
    { dauer: 120000, wuerfe: [{ spell: 1, t: 0 }, { spell: 1, t: 1 }, { spell: 1, t: 2 }, { spell: 1, t: 3 }] },
  ];
  const r = rate(p);
  // Spieler A: 2/min, Spieler B: 2/min -> Median 2
  check('Zauber 1 liegt bei zwei je Minute', r[0], { spell: 1, proMinute: 2, spieler: 2, pct: 67 });
  check('Zauber 2 bei einem', r[1], { spell: 2, proMinute: 1, spieler: 1, pct: 33 });
}

// Ohne Dauer wird nichts gerechnet statt durch null geteilt.
check('ohne Dauer kein Wert', rate([{ dauer: 0, wuerfe: [{ spell: 1, t: 0 }] }]), []);

console.log('Mehrere Ziele: gemessen, nicht behauptet');

// Die echten Zahlen aus dem Spiel, am 9. Oktober 2026 gemessen.
check('Sszorak ist reines Einzelziel',
  spread([{ name: 'Sszorak', total: 1000 }]).multi, false);
check('The Lost Explorers sind Multi',
  spread([{ name: 'First Mate Nama', total: 360 },
    { name: 'Zwei', total: 340 }, { name: 'Drei', total: 300 }]).multi, true);
check('The Twin Fangs auch',
  spread([{ name: 'Ithraz', total: 460 }, { name: 'Zweiter', total: 540 }]).multi, true);
check('Nymrissa nicht',
  spread([{ name: 'Nymrissa', total: 720 }, { name: 'Add', total: 280 }]).multi, false);
check('die Grenze liegt in der Luecke des Feldes', MULTI_AB > 0.40 && MULTI_AB < 0.54, true);
// Ohne Schaden wird NICHTS behauptet - auch nicht "Einzelziel".
check('ohne Messung keine Aussage', spread([]).multi, null);

console.log('Runden: nie zu einer Behauptung');

check('996 von 1000 sind 99, nicht 100', anteil(996, 1000), 99);
check('4 von 1000 sind 1, nicht 0', anteil(4, 1000), 1);
check('alle sind 100', anteil(7, 7), 100);
check('keiner ist 0', anteil(0, 7), 0);

check('Median bei ungerader Zahl', median([3, 1, 2]), 2);
check('Median bei gerader Zahl', median([1, 2, 3, 4]), 2.5);

console.log('');
if (failed) {
  console.error(`${failed} Fehler`);
  process.exit(1);
}
console.log('alles gruen');
