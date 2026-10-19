// Die Regeln hinter dem Abschnitt "Rassen".
//
// Gespielt und simuliert sind zwei verschiedene Auskuenfte; hier steht,
// was jeweils hineindarf.
const { tallyRaces, raceShares, raceSims, simRace, MIN_SAMPLE } = require('../lib/races');

let failed = 0;
function check(what, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`
    + (ok ? '' : `\n          bekommen: ${JSON.stringify(got)}`
      + `\n          erwartet: ${JSON.stringify(want)}`));
}

const index = {
  Tauren: { id: 6, side: 'horde' },
  Human: { id: 1, side: 'alliance' },
  'Zandalari Troll': { id: 31, side: 'horde' },
};

// Ein Spieler, zwei Quellen: er zaehlt einmal - auch in anderer Schreibung.
const doppelt = tallyRaces([
  { key: 'https://raider.io/characters/eu/blackhand/Zack', race: 'Tauren' },
  { key: 'https://raider.io/characters/eu/blackhand/zack', race: 'Tauren' },
  { key: 'https://raider.io/characters/eu/blackhand/Anna', race: 'Human' },
]);
check('ein Spieler aus zwei Quellen zaehlt einmal', [...doppelt.entries()], [['Tauren', 1], ['Human', 1]]);
check('ohne Adresse oder Rasse zaehlt niemand',
  [...tallyRaces([{ key: null, race: 'Tauren' }, { key: 'x', race: null }]).entries()], []);

// Zu wenige Spieler: keine Anteile.
const wenige = new Map([['Tauren', MIN_SAMPLE - 1]]);
check('unter der Mindestzahl kein Anteil', raceShares(wenige, index), null);

// Genug: Anteile, die groessten zuerst; Unbekanntes faellt heraus,
// zaehlt aber in die Stichprobe (es ist ein gemessener Spieler).
const genug = new Map([['Tauren', 12], ['Human', 6], ['Mondmensch', 2]]);
const anteile = raceShares(genug, index);
check('Stichprobe zaehlt alle Gemessenen', anteile.n, 20);
check('die groessten zuerst, mit Anteil', anteile.list, [{ id: 6, pct: 60 }, { id: 1, pct: 30 }]);

// Die Simulation: Abstand zur schwaechsten Rasse, je Kampfart in Zielen.
const sims = raceSims({
  castingpatchwerk: { ts: '2026-10-14 02:38', data: { Tauren: 101600, Human: 100000, 'Zandalari Troll Paku': 100500 } },
  castingpatchwerk5: { ts: '2026-10-13 01:00', data: { Tauren: 200000, Human: 202000 } },
  hecticaddcleave: { data: { Tauren: 1 } },
}, index);
check('1 Ziel: Abstand zur schwaechsten in Prozent', sims.byTargets[1],
  [{ id: 6, loa: null, rel: 1.6 }, { id: 31, loa: 'Paku', rel: 0.5 }, { id: 1, loa: null, rel: 0 }]);
check('5 Ziele haben ihre eigene Reihenfolge', sims.byTargets[5].map((r) => r.id), [1, 6]);
check('nur die bekannten Kampfarten', Object.keys(sims.byTargets), ['1', '5']);
check('der neueste Stand gilt', sims.ts, '2026-10-14 02:38');
check('ohne Daten keine Simulation', raceSims({}, index), null);
check('Zandalari werden je Loa erkannt', simRace('Zandalari Troll Kimbul', index), { id: 31, loa: 'Kimbul' });
check('Unbekanntes wird nicht geraten', simRace('Mondmensch', index), null);

if (failed) {
  console.error(`\n${failed} Fehler`);
  process.exit(1);
}
console.log('\nalles gruen');
