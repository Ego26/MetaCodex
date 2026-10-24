// Der Heiler-Guide aus den Messungen (tools/lib/healing.js).
const { guide } = require('../lib/healing');

let failed = 0;
function check(what, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`
    + (ok ? '' : `\n          bekommen: ${JSON.stringify(got)}`
      + `\n          erwartet: ${JSON.stringify(want)}`));
}

// Ein kleiner Restoschamane: 10 Spieler, je 5 Minuten.
const NAMES = { 1: 'chain_heal', 2: 'riptide', 3: 'ascendance', 4: 'spirit_link_totem', 5: 'flame_shock', 6: 'flame_shock',
  7: 'astral_shift', 8: 'trinket', 9: 'ghost_wolf', 10: 'lava_burst' };
const CD = { 2: 6, 3: 180, 4: 180, 7: 120, 8: 120, 5: 6, 6: 6, 10: 8 };
const game = {
  cd: (id) => CD[id] || 0, isItem: (id) => id === 8, isDamage: (id) => [5, 6, 10].includes(id), nameOf: (id) => NAMES[id],
};
const casts = {
  players: 10, minutes: 50,
  by: [
    [1, 1000, 10],   // 20/min, alle
    [2, 600, 10],
    [3, 20, 10],     // 2 je Kampf bei 3 Min.: moeglich 2 -> 100 %
    [4, 12, 9],      // 1,2 von 2 -> 60 %
    [7, 4, 5],       // 0,4 von 3 -> 13 %
    [8, 28, 10],     // Schmuck: 2,8 von 3 -> 93 %
    [5, 60, 8], [6, 60, 8],   // zwei IDs, ein Zauber, doppelt geloggt: 1,2/min
    [9, 25, 9],      // Geisterwolf: unter einmal je Minute, kein Cooldown
    [10, 30, 3],     // nur 30 % - kein Grundgeruest
  ],
};
const g = guide({ casts }, game);
check('Grundgeruest: haeufig und von den meisten, nach Haeufigkeit', g.core.map((r) => r.s), [1, 2]);
check('je Minute und Anteil', [g.core[0].cpm, g.core[0].pct], [20, 100]);
check('Schaden getrennt, zwei IDs als ein Zauber', g.dmg.map((r) => [r.s, r.cpm]), [[5, 1.2]]);
check('Cooldowns nach Auslastung', g.cds.map((r) => [r.s, r.use]), [[3, 100], [4, 60], [7, 13]]);
check('Gegenstaende fuer sich', g.items.map((r) => [r.s, r.use]), [[8, 93]]);
check('Geisterwolf ist weder Kern noch Cooldown', [...g.core, ...g.cds].some((r) => r.s === 9), false);

// Zeitpunkte je Boss: der n-te Einsatz im Median, wo die meisten so oft zogen.
const boss = { name: 'Nekzali', dur: 284000, casts: [
  [[3, 71000], [3, 252000], [4, 223000]],
  [[3, 70000], [3, 250000], [4, 224000]],
  [[3, 72000], [4, 220000]],
  [[3, 69000], [3, 255000]],
] };
// Aszendenz (100 %) laeuft auf Cooldown und steht nicht im Plan; ein
// doppelt geloggter Einsatz zaehlt einmal.
boss.casts[0].push([4, 223500]);
const mitBoss = guide({ casts, bosses: [boss] }, game);
check('nur gezielte Cooldowns im Plan, Doppelte einmal', mitBoss.bosses[0].cds.map((x) => [x.s, x.t]), [[4, [223]]]);
check('ohne Messung kein Guide', guide({ casts: { players: 0, minutes: 0, by: [] } }, game), null);

// Der Pull: nur Zauber dieses Guides, in der Reihenfolge der meisten.
const openers = [];
for (let i = 0; i < 6; i += 1) openers.push({ pre: [], pull: [], post: [1, 9, 2, 2, 3] });
check('Pull: ohne Geisterwolf', guide({ casts, openers }, game).opener.post, [1, 2, 3]);

console.log(failed === 0 ? '\nalles gruen' : `\n${failed} Fehler`);
process.exit(failed === 0 ? 0 : 1);
