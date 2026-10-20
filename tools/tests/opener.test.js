// Die Regeln hinter dem Beispiel-Ablauf (tools/lib/opener.js).
const { sequenceOf, typical, placePull } = require('../lib/opener');

let failed = 0;
function check(what, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`
    + (ok ? '' : `\n          bekommen: ${JSON.stringify(got)}`
      + `\n          erwartet: ${JSON.stringify(want)}`));
}

const PULL = 100000;
const ev = (dt, id, type = 'cast') => ({ timestamp: PULL + dt, abilityGameID: id, type });

// Vor, am und nach dem Pull getrennt.
check('vor, am und nach dem Pull', sequenceOf([ev(-5000, 1), ev(-1000, 2), ev(300, 5), ev(900, 3), ev(2000, 4)], PULL),
  { pre: [1, 2], pull: [5], post: [3, 4] });
// Ein Precast: begonnen vor dem Pull, gelandet kurz danach - gehoert davor.
check('Precast zaehlt vor den Pull', sequenceOf([ev(-2000, 9, 'begincast'), ev(200, 9), ev(1500, 3)], PULL),
  { pre: [9], pull: [], post: [3] });
// Begonnen NACH dem Pull: ein normaler Zauber danach.
check('nach dem Pull begonnen bleibt danach', sequenceOf([ev(600, 9, 'begincast'), ev(1800, 9)], PULL),
  { pre: [], pull: [], post: [9] });
// Ausserhalb des Fensters: nicht dabei.
check('ausserhalb des Fensters nicht', sequenceOf([ev(-60000, 1), ev(60000, 2), ev(900, 3)], PULL),
  { pre: [], pull: [], post: [3] });
// Wie im echten Log (20. Oktober): Sturmhueter landet 77 ms nach dem Start,
// ohne Beginn davor. Steht er in der Vorkampfliste, ist er der Precast.
const echt = sequenceOf([ev(77, 191634), ev(742, 443454), ev(742, 114050), ev(1574, 51505)], PULL);
check('am Pull: der Vorkampf-Zauber wird Precast',
  placePull(echt, new Set([191634])), { pre: [191634], post: [443454, 114050, 51505] });
check('am Pull: ein anderer Zauber eroeffnet den Kampf',
  placePull(echt, new Set([999])), { pre: [], post: [191634, 443454, 114050, 51505] });
// Reihenfolge nach Zeit, auch wenn die Ereignisse anders kommen.
check('nach Zeit geordnet', sequenceOf([ev(2000, 4), ev(900, 3)], PULL).post, [3, 4]);

// Die Reihenfolge der meisten.
const viele = [];
for (let i = 0; i < 8; i += 1) viele.push([10, 20, 30, 40]);
for (let i = 0; i < 3; i += 1) viele.push([10, 30, 20]);
check('die Reihenfolge der meisten', typical(viele), [10, 20, 30, 40]);
// Zu wenige: lieber nichts.
check('zu wenige Spieler: nichts', typical([[1, 2], [1, 2], [1, 2]]), []);
// Wo sich die Wege trennen und keiner ueberwiegt, hoert es auf.
const geteilt = [];
for (let i = 0; i < 6; i += 1) geteilt.push([1, 2, 3]);
for (let i = 0; i < 6; i += 1) geteilt.push([1, 4, 5]);
for (let i = 0; i < 6; i += 1) geteilt.push([1, 6, 7]);
for (let i = 0; i < 6; i += 1) geteilt.push([1, 8, 9]);
check('ohne Mehrheit endet der Ablauf', typical(geteilt, { minShare: 0.3 }), [1]);
// Vor dem Pull von der Marke her gelesen: der letzte Zauber zuerst.
const vor = [];
for (let i = 0; i < 4; i += 1) vor.push([7, 8, 9]);
for (let i = 0; i < 6; i += 1) vor.push([8, 9]);
check('vor dem Pull von der Marke aus', typical(vor, { fromEnd: true }), [8, 9]);

console.log(failed === 0 ? '\nalles gruen' : `\n${failed} Fehler`);
process.exit(failed === 0 ? 0 : 1);
