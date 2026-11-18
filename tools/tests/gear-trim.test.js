// Jede Filterstufe hat ihre eigenen fuenf.
//
// Am 18. November meldete ein Spieler: "M+ Dungeons" zeigt keinen
// einzigen Schmuck. Die Sammler hatten nach den fuenf meistgetragenen
// abgeschnitten, und das waren alles Raid-Stuecke.
const { trimGear, bucketBy } = require('../lib/gear-trim');

let failed = 0;
function check(what, got, want) {
  const ok = got === want;
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}${ok ? '' : ` -> ${got}, erwartet ${want}`}`);
}

console.log('Ausruestung je Fundort');

// Sechs Raid-Stuecke vom selben Boss vorne, dahinter zwei aus Dungeons,
// ein Handwerksstueck und Unbekanntes.
const journal = {
  1: { enc: 900, inst: 90 }, 2: { enc: 900, inst: 90 }, 3: { enc: 900, inst: 90 },
  4: { enc: 900, inst: 90 }, 5: { enc: 900, inst: 90 }, 6: { enc: 900, inst: 90 },
  7: { enc: 10, inst: 1 }, 8: { enc: 20, inst: 2 },
};
const crafted = new Set([9]);
const rows = [
  { id: 8, pct: 2 }, { id: 1, pct: 40 }, { id: 2, pct: 30 }, { id: 3, pct: 20 },
  { id: 4, pct: 10 }, { id: 5, pct: 9 }, { id: 6, pct: 8 }, { id: 7, pct: 3 },
  { id: 9, pct: 1 }, { id: 11, pct: 1 }, { id: 12, pct: 1, kind: 'set' },
];
const out = trimGear(rows, bucketBy(journal, crafted));
const ids = out.map((r) => r.id).join(',');

check('absteigend nach Anteil', out[0].id, 1);
check('die fuenf insgesamt bleiben', ids.startsWith('1,2,3,4,5'), true);
check('der sechste vom selben Boss faellt weg', out.some((r) => r.id === 6), false);
check('die Dungeon-Stuecke bleiben, auch hinten', out.some((r) => r.id === 7) && out.some((r) => r.id === 8), true);
check('Handwerk bleibt', out.some((r) => r.id === 9), true);
check('Unbekanntes bleibt', out.some((r) => r.id === 11), true);
check('die Art der Quelle zaehlt', bucketBy(journal, crafted)(rows[10]), 'set');
check('die Eingabe bleibt unberuehrt', rows[0].id, 8);

// Sechs Dungeon-Stuecke vom selben Boss, keins unter den fuenf insgesamt:
// fuenf davon bleiben, damit "dieser Dungeon" fuenf zeigen kann.
const viele = [{ id: 100, pct: 50 }, { id: 101, pct: 50 }, { id: 102, pct: 50 },
  { id: 103, pct: 50 }, { id: 104, pct: 50 }];
for (let i = 0; i < 6; i += 1) viele.push({ id: 200 + i, pct: 6 - i });
const bossOf = (r) => (r.id >= 200 ? 'enc:1' : 'other');
const kurz = trimGear(viele, bossOf);
check('je Boss fuenf, auch ausserhalb der fuenf insgesamt', kurz.filter((r) => r.id >= 200).length, 5);
check('leer bleibt leer', trimGear(undefined, bossOf).length, 0);

if (failed) { console.log(`\n${failed} fehlgeschlagen`); process.exit(1); }
console.log('\nalles gruen');
