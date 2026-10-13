// Die Regeln hinter "auch gut fuer".
//
// Sie entscheiden, was im Tooltip eines Gegenstands als Empfehlung fuer
// eine fremde Spec steht. Eine Zeile, die auf zwei Spielern beruht,
// sieht genauso aus wie eine, die auf achthundert beruht - also muss
// hier stimmen, was ueberhaupt hineindarf.
const { wornBy, MIN_SAMPLE, WORN_AB } = require('../lib/worn-by');

let failed = 0;
function check(what, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`
    + (ok ? '' : `\n          bekommen: ${JSON.stringify(got)}`
      + `\n          erwartet: ${JSON.stringify(want)}`));
}

// Ein Stueck, zwei Specs, eine davon mit zu kleiner Stichprobe.
const daten = {
  raid: {
    'warcraftlogs.com': {
      specs: {
        62: { sample: 114, gear: { Head: [{ id: 100, pct: 83 }, { id: 101, pct: 9 }] } },
        105: { sample: 67, gear: { Head: [{ id: 100, pct: 41 }] } },
      },
    },
  },
  mplus: {
    'warcraftlogs.com': {
      specs: {
        62: { sample: 90, gear: { Head: [{ id: 100, pct: 92 }] } },
      },
    },
  },
  '2v2': {
    'Battle.net': {
      specs: {
        // Zwei Spieler, einer trug es: 50 %. Keine Grundlage fuer eine
        // Zeile im Tooltip.
        70: { sample: 2, gear: { Head: [{ id: 100, pct: 50 }] } },
      },
    },
  },
  'mplus/altar-of-fangs': {
    'warcraftlogs.com': {
      specs: { 71: { sample: 40, gear: { Head: [{ id: 100, pct: 95 }] } } },
    },
  },
  solo: {
    'murlok.io': {
      // Quelle ohne Stichprobe - ihre Prozente beziehen sich auf die
      // Liste, nicht auf Spieler.
      specs: { 72: { gear: { Head: [{ id: 100, pct: 88 }] } } },
    },
  },
};

const index = wornBy(daten);
const wer = index.get(100);

console.log('Was in den Index darf');

check('zwei Specs bleiben uebrig', wer.map((e) => e.spec), [62, 105]);
check('je Spec der staerkste Anteil, mit seiner Aktivitaet',
  wer[0], { spec: 62, pct: 92, mode: 'mplus', sample: 90 });
check('nach Anteil sortiert', wer.map((e) => e.pct), [92, 41]);
check('zwei Spieler ergeben keine Zeile',
  wer.some((e) => e.spec === 70), false);
check('eine Quelle ohne Stichprobe auch nicht',
  wer.some((e) => e.spec === 72), false);
check('ein einzelner Dungeon zaehlt nicht doppelt',
  wer.some((e) => e.spec === 71), false);
check('was fast niemand traegt, steht nirgends', index.has(101), false);

console.log('Die Schwellen selbst');

check('ohne Stichprobe keine Aussage', MIN_SAMPLE >= 15, true);
// Der Median aller gemessenen Anteile liegt bei 14 %. Die Schwelle muss
// darueber liegen, sonst ist die Haelfte aller Messungen ein "gut fuer".
check('die Schwelle liegt ueber dem Median des Feldes', WORN_AB > 14, true);

// Bei Gleichstand entscheidet die Spec-Nummer, damit die Reihenfolge
// zwischen zwei Naechten stehenbleibt.
{
  const gleich = wornBy({
    raid: {
      'warcraftlogs.com': {
        specs: {
          105: { sample: 50, gear: { Neck: [{ id: 7, pct: 60 }] } },
          62: { sample: 50, gear: { Neck: [{ id: 7, pct: 60 }] } },
        },
      },
    },
  });
  check('Gleichstand hat eine feste Reihenfolge',
    gleich.get(7).map((e) => e.spec), [62, 105]);
}

check('ohne Daten ein leerer Index', wornBy({}).size, 0);
check('und mit nichts in der Hand auch', wornBy(null).size, 0);

console.log('');
if (failed) {
  console.error(`${failed} Fehler`);
  process.exit(1);
}
console.log('alles gruen');
