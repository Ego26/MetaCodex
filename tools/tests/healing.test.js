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
  7: 'astral_shift', 8: 'trinket', 9: 'ghost_wolf', 10: 'lava_burst', 11: 'healing_wave', 12: 'surging_totem',
  13: 'stormstream_totem', 14: 'healing_stream_totem', 15: 'totemic_projection',
  16: 'reclamation', 17: 'mana_tea', 18: 'thunder_focus_tea', 19: 'word_of_glory', 20: 'light_of_dawn',
  21: 'rising_sun_kick', 22: 'lifebloom' };
const CD = { 2: 6, 3: 180, 4: 180, 7: 120, 8: 120, 5: 6, 6: 6, 10: 8, 12: 25, 13: 30, 14: 30, 15: 10, 18: 30 };
const game = {
  cd: (id) => CD[id] || 0, isItem: (id) => id === 8, isDamage: (id) => [5, 6, 10, 21].includes(id), nameOf: (id) => NAMES[id],
  procFrom: (id) => (id === 13 ? 14 : null), lasts: (id) => ({ 2: 18, 12: 24, 14: 15, 22: 15 })[id] || 0,
  isMulti: (id) => id === 1, manaPct: (id) => ({ 1: 4.28, 11: 2.38 })[id] || 0, isUtility: (id) => id === 15,
  isSummon: (id) => [12, 14].includes(id), isEffect: (id) => id === 16, isMana: (id) => id === 17,
  isEmpower: (id) => id === 18, spends: (id) => ([19, 20].includes(id) ? 'holy_power' : id === 21 ? 'chi' : null),
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
    [11, 150, 10],   // Welle der Heilung: zweiter Fueller, 3/min
    [12, 110, 10],   // Wogendes Totem: 24 von 25 Sek. - aufrecht halten
    [13, 40, 9],     // Totem der Sturmflut: nur aus dem Proc
    [14, 90, 10],    // Totem des heilenden Flusses: 90 von 100 moeglichen
    [15, 65, 10],    // Totemische Projektion: weder Heilung noch Schaden
    [16, 300, 10],   // Rueckgewinnung: die Wirkung eines passiven Talents, kein Knopf
    [17, 60, 10],    // Manatee: stellt Mana her, heilt nicht
    [18, 105, 10],   // Donnerfokustee: verstaerkt den naechsten Zauber
    [19, 150, 10],   // Wort der Herrlichkeit: gibt Heilige Kraft aus
    [20, 5, 3],      // Licht der Morgendaemmerung: die zweite Ausgabe - Heilige Kraft ist eigen
    [21, 50, 10],    // Tritt der aufgehenden Sonne kostet Chi - aber nur er: kein Verbraucher
    [22, 200, 10],   // Bluehendes Leben: 4/min bei 15 Sek. - auf einem Ziel aufrecht
  ],
};
const g = guide({ casts }, game);
check('Prioritaet: Proc, Abklingzeit, aufrecht, Fueller, Schaden', g.prio.map((r) => [r.k, r.s]),
  [['proc', 13], ['oncd', 2], ['emp', 18], ['keep', 12], ['oncd', 14], ['keep', 22], ['spend', 19], ['fill', 1], ['fill', 11], ['mana', 17], ['dmg', 5], ['dmg', 21], ['sit', 15]]);
check('ein passives Talent hat keine Zeile', g.prio.some((r) => r.s === 16), false);
check('der Verbraucher nennt die Ressource', g.prio.find((r) => r.k === 'spend').res, 'holy_power');
check('der Proc nennt, was er ersetzt', g.prio[0].from, 14);
check('Springflut haelt drei Abklingzeiten: auf Abklingzeit, nicht aufrecht', g.prio[1].k, 'oncd');
check('Fueller: mehrere Ziele und teurer gegen ein Ziel und guenstiger',
  g.prio.filter((r) => r.k === 'fill').map((r) => [r.s, r.multi, r.cost]), [[1, true, 'high'], [11, false, 'low']]);
check('je Minute und Anteil', [g.prio.find((r) => r.s === 1).cpm, g.prio.find((r) => r.s === 1).pct], [20, 100]);
check('Schaden getrennt, zwei IDs als ein Zauber', g.prio.filter((r) => r.k === 'dmg').map((r) => [r.s, r.cpm]), [[5, 1.2], [21, 1]]);
// Kein Raid gegen M+ (26. Oktober): ein Fueller traegt keinen Vergleich.
check('kein Vergleich mit der anderen Aktivitaet', g.prio.some((r) => 'vs' in r), false);
check('Cooldowns nach Auslastung', g.cds.map((r) => [r.s, r.use]), [[3, 100], [4, 60], [7, 13]]);
check('Gegenstaende fuer sich', g.items.map((r) => [r.s, r.use]), [[8, 93]]);
check('Geisterwolf ist weder Prioritaet noch Cooldown', [...g.prio, ...g.cds].some((r) => r.s === 9), false);

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

// WERKZEUGE UND FREMDES (26. Oktober): Spurt ist kein Heil-Cooldown, Seele
// der Macht auf Abklingzeit schon, Schattenmimik ist die Rasse.
const NAMES2 = { ...NAMES, 30: 'dash', 31: 'shadowmeld', 32: 'power_infusion' };
const game2 = { ...game, nameOf: (id) => NAMES2[id], cd: (id) => ({ 30: 120, 31: 120, 32: 120 })[id] || game.cd(id),
  isUtility: (id) => [15, 30, 32].includes(id), isForeign: (id) => id === 31 };
const casts2 = { ...casts, by: [...casts.by, [30, 6, 6], [31, 6, 6], [32, 30, 10]] };
const g2 = guide({ casts: casts2, bosses: [boss] }, game2);
check('ein Werkzeug steht als solches am Ende der Cooldowns', g2.cds.slice(-1).map((r) => [r.s, r.k]), [[30, 'tool']]);
check('auf Abklingzeit gedrueckt ist kein Werkzeug', g2.cds.find((r) => r.s === 32).k, undefined);
check('die Rasse hat keine Zeile', [...g2.prio, ...g2.cds].some((r) => r.s === 31), false);
check('ein Werkzeug hat keine Minute im Boss-Plan', g2.bosses[0].cds.some((x) => x.s === 30), false);
// Berührung des Todes ist Schaden, Anregen ist Mana.
const game3 = { ...game2, nameOf: (id) => ({ ...NAMES2, 33: 'touch_of_death', 34: 'innervate' })[id],
  cd: (id) => ({ 33: 90, 34: 180 })[id] || game2.cd(id), isDamage: (id) => id === 33 || game.isDamage(id),
  isMana: (id) => id === 34 || game.isMana(id) };
const g3 = guide({ casts: { ...casts, by: [...casts.by, [33, 8, 8], [34, 8, 8]] } }, game3);
check('Cooldowns mit Art: Schaden und Mana', [g3.cds.find((r) => r.s === 33).k, g3.cds.find((r) => r.s === 34).k], ['dmg', 'mana']);
// Sühne: Schaden heilt - mit dem Talent als Grund, und kein "wenig zu heilen".
const g4 = guide({ casts: { ...casts, by: [...casts.by, [33, 8, 8]] } }, { ...game3, healsVia: (id) => ([5, 6, 33].includes(id) ? 81749 : null) });
check('Schaden, der heilt, nennt sein Talent', g4.prio.filter((r) => r.k === 'dmgheal').map((r) => [r.s, r.via]), [[5, 81749]]);
check('ein Schadens-Cooldown, der heilt, ist kein "wenig zu heilen"', g4.cds.find((r) => r.s === 33).k, undefined);
check('ein Schadens-Cooldown, der heilt, nennt sein Talent', g4.cds.find((r) => r.s === 33).via, 81749);

// WEN ES SCHUETZT (26. Oktober): der eigene Schutz und der fuer einen
// Einzelnen, wie oft auch gedrueckt; Bewegung ist ein Werkzeug; die andere
// Haelfte eines Wahlknotens hat keine Zeile.
const NAMES5 = { ...NAMES2, 40: 'barkskin', 41: 'ironbark', 42: 'spiritwalkers_grace', 43: 'restoral' };
const game5 = { ...game2, nameOf: (id) => NAMES5[id], cd: (id) => ({ 40: 60, 41: 90, 42: 120, 43: 180 })[id] || game2.cd(id),
  isPersonal: (id) => id === 40, isExternal: (id) => id === 41, isTool: (id) => id === 42, notInBuild: (id) => id === 43 };
const g5 = guide({ casts: { ...casts, by: [...casts.by, [40, 60, 10], [41, 60, 10], [42, 60, 10], [43, 6, 6]] }, bosses: [boss] }, game5);
check('eigener Schutz, Einzelner und Bewegung, in dieser Reihenfolge',
  g5.cds.filter((r) => [40, 41, 42].includes(r.s)).map((r) => [r.s, r.k]), [[41, 'ext'], [40, 'self'], [42, 'tool']]);
check('was der Build nicht nimmt, hat keine Zeile', g5.cds.some((r) => r.s === 43), false);
// Segenswort: Epiphanie: eine Minute Abklingzeit, achtmal pro Minute
// gewirkt - Kern, kein grosser Cooldown. Die Ticks einer Kanalisierung
// (Gotteshymne) zaehlen nicht als Druecken.
const NAMES6 = { ...NAMES5, 44: 'holy_word_serenity', 45: 'divine_hymn', 46: 'divine_hymn' };
const game6 = { ...game5, nameOf: (id) => NAMES6[id], cd: (id) => ({ 44: 60, 45: 180, 46: 180 })[id] || game5.cd(id),
  ownCd: (id) => ({ 44: 60, 45: 180 })[id] || 0 };
const g6 = guide({ casts: { ...casts, by: [...casts.by, [44, 400, 10], [45, 20, 10], [46, 300, 10]] } }, game6);
check('schneller als die Abklingzeit: Kern', [g6.prio.some((r) => r.s === 44), g6.cds.some((r) => r.s === 44)], [true, false]);
check('die Ticks einer Kanalisierung machen keinen Kern', g6.cds.some((r) => r.s === 46 || r.s === 45), true);
check('der eigene Schutz hat keine Minute im Boss-Plan', (g5.bosses || [{ cds: [] }])[0].cds.some((x) => x.s === 40), false);

console.log(failed === 0 ? '\nalles gruen' : `\n${failed} Fehler`);
process.exit(failed === 0 ? 0 : 1);
