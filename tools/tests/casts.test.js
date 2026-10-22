// Was jeder Spieler in einem Kampf wirkte (tools/lib/casts.js).
const { castsBySource } = require('../lib/casts');

let failed = 0;
function check(what, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`
    + (ok ? '' : `\n          bekommen: ${JSON.stringify(got)}`
      + `\n          erwartet: ${JSON.stringify(want)}`));
}

const specs = new Map([[1, 262], [2, 263]]);
const ev = [
  { type: 'begincast', sourceID: 1, abilityGameID: 191634 },
  { type: 'cast', sourceID: 1, abilityGameID: 191634 },     // Sturmhueter
  { type: 'cast', sourceID: 1, abilityGameID: 188196 },
  { type: 'cast', sourceID: 1, abilityGameID: 188196 },
  { type: 'cast', sourceID: 2, abilityGameID: 17364 },
  { type: 'cast', sourceID: 9, abilityGameID: 1 },          // kein Spieler einer bekannten Spec
];
const m = castsBySource(ev, specs);
check('je Spieler seine Spec', [...m].map(([s, x]) => [s, x.spec]), [[1, 262], [2, 263]]);
check('jeder Zauber gezaehlt, auch der seltene', [...m.get(1).by], [[191634, 1], [188196, 2]]);
check('ein begonnener Zauber zaehlt nicht doppelt', m.get(1).by.get(191634), 1);
check('Unbekannte fallen weg', m.has(9), false);

console.log(failed === 0 ? '\nalles gruen' : `\n${failed} Fehler`);
process.exit(failed === 0 ? 0 : 1);
