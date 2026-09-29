// Welche Handwerksstufe im Fenster steht, nachgerechnet.
//
// Im Spiel stand "Thalassisches Phoenixoel" in der Silberstufe mit
// 100 % - obwohl die Goldstufe die haeufigere war. Die Auswahlregel
// verglich gegen eine Zahl, die beim ersten Eintrag nie gesetzt wurde,
// und nahm deshalb immer die ZULETZT gesehene Stufe.
//
// Was einmal falsch war, bekommt einen Test.
const { mergeTiers } = require('../lib/merge-tiers');

let failed = 0;
function check(what, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`
    + (ok ? '' : `  -> ${JSON.stringify(got)} statt ${JSON.stringify(want)}`));
}

console.log('Handwerksstufen zusammenlegen');

// Der Fall aus dem Spiel: Gold zuerst gesehen, Silber danach.
const oel = mergeTiers([
  { id: 243734, name: 'Thalassian Phoenix Oil', pct: 74, kind: 'other' },
  { id: 243733, name: 'Thalassian Phoenix Oil', pct: 13, kind: 'other' },
]);
check('eine Zeile statt zweier', oel.length, 1);
check('die Anteile werden addiert', oel[0].pct, 87);
check('und die HAEUFIGERE Stufe gibt die ID vor', oel[0].id, 243734);

// Und andersherum, damit nicht die Reihenfolge gewinnt.
const umgekehrt = mergeTiers([
  { id: 243733, name: 'Thalassian Phoenix Oil', pct: 13 },
  { id: 243734, name: 'Thalassian Phoenix Oil', pct: 74 },
]);
check('die Reihenfolge aendert nichts', umgekehrt[0].id, 243734);
check('auch nicht am Anteil', umgekehrt[0].pct, 87);

// Drei Stufen, die mittlere ist die haeufigste.
const drei = mergeTiers([
  { id: 1, name: 'Ware', pct: 10 },
  { id: 2, name: 'Ware', pct: 60 },
  { id: 3, name: 'Ware', pct: 20 },
]);
check('von dreien gewinnt die mittlere', drei[0].id, 2);
check('und alle drei zaehlen', drei[0].pct, 90);

// Die Hilfszahl darf nicht in der Datei landen.
check('keine Hilfszahl in der Ausgabe', drei[0].top, undefined);

// Ueber hundert gibt es nicht.
const viel = mergeTiers([
  { id: 1, name: 'Ware', pct: 70 },
  { id: 2, name: 'Ware', pct: 60 },
]);
check('hoechstens hundert Prozent', viel[0].pct, 100);
check('und immer noch die haeufigere ID', viel[0].id, 1);

// Rauschen faellt weg, Zeilen ohne ID auch.
check('unter einem Prozent faellt weg',
  mergeTiers([{ id: 9, name: 'Ware', pct: 0 }]).length, 0);
check('ohne ID keine Zeile',
  mergeTiers([{ name: 'Ware', pct: 50 }]).length, 0);

// Verschiedene Waren bleiben verschieden.
const zwei = mergeTiers([
  { id: 1, name: 'Oel', pct: 40 },
  { id: 2, name: 'Stein', pct: 30 },
]);
check('zwei Waren bleiben zwei Zeilen', zwei.length, 2);
check('und die groessere steht oben', zwei[0].id, 1);

console.log('');
console.log(failed === 0 ? 'alles gruen' : failed + ' Fehler');
process.exit(failed === 0 ? 0 : 1);
