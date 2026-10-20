// Die Rotation, wie ein Guide sie schreibt (tools/lib/simplify.js).
const { simplify, simpleConditions } = require('../lib/simplify');

let failed = 0;
function check(what, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`
    + (ok ? '' : `\n          bekommen: ${JSON.stringify(got)}`
      + `\n          erwartet: ${JSON.stringify(want)}`));
}
const s = (lines) => simplify(lines).map((l) => [l.s, l.c, l.any]);

check('Feinabstimmung faellt aus der Bedingung',
  s([{ s: 1, c: [['down', 5], ['resnotcap', 'maelstrom', 15], ['cdsoon', 7]] }]), [[1, [['down', 5]], undefined]]);
check('kurze Restzeiten sind Feinabstimmung',
  s([{ s: 1, c: [['up', 5], ['remunder', 5, 2]] }]), [[1, [['up', 5]], undefined]]);
check('eine Zeile ohne verstaendliche Bedingung faellt weg',
  s([{ s: 1, c: [['cmp', ['rem', 1], 'gt', ['cd', 2]]] }, { s: 2 }]), [[2, [], undefined]]);
check('nur vage faellt weg',
  s([{ s: 1, more: true }, { s: 2 }]), [[2, [], undefined]]);
check('hoechstens drei Bedingungen, die Zielzahl zuerst',
  s([{ s: 1, c: [['resmin', 'x', 50], ['up', 5], ['ready', 6], ['tgtmin', 3], ['stackmin', 7, 2]] }]),
  [[1, [['tgtmin', 3], ['up', 5], ['ready', 6]], undefined]]);
check('ein einfaches Oder bleibt',
  s([{ s: 1, c: [['or', ['up', 5], ['ready', 6]]] }]), [[1, [['or', ['up', 5], ['ready', 6]]], undefined]]);
// Jeder Teil eines Oders reicht allein: die einfachen bleiben.
check('vom Oder bleiben die einfachen Teile',
  s([{ s: 1, c: [['up', 4], ['or', ['up', 5], ['and', ['up', 6], ['ready', 7]]]] }]), [[1, [['up', 4], ['up', 5]], undefined]]);
check('ein Oder nur aus Kompliziertem faellt aus der Bedingung',
  s([{ s: 1, c: [['up', 4], ['or', ['cmp', 1, 'gt', 2], ['and', ['up', 6], ['ready', 7]]]] }]), [[1, [['up', 4]], undefined]]);
check('unter 35 oder unter 20 Prozent ist unter 35',
  s([{ s: 1, c: [['or', ['hpunder', 35], ['hpunder', 20]]] }]), [[1, [['hpunder', 35]], undefined]]);
check('mindestens 8 oder mindestens 5 Stapel ist mindestens 5',
  s([{ s: 1, c: [['or', ['stackmin', 7, 8], ['stackmin', 7, 5]]] }]), [[1, [['stackmin', 7, 5]], undefined]]);
check('ein Dot auf keinem Ziel ist ein fehlender Dot',
  s([{ s: 1, c: [['doton', 9, 0]] }]), [[1, [['down', 9]], undefined]]);
check('zwei Buffs eines Namens, einer an, einer aus: das Aus faellt',
  simplify([{ s: 1, c: [['up', 5], ['down', 6], ['down', 8]] }],
    { nameOf: (id) => ({ 5: 'Divine Arbiter', 6: 'Empyrean Legacy', 8: 'Divine Arbiter' })[id] })
    .map((l) => l.c), [[['up', 5], ['down', 6]]]);
const namen = { nameOf: (id) => ({ 5: 'Herz', 6: 'Herz', 7: 'Emporstossen', 8: 'Leerenfall' })[id] || String(id) };
check('dieselbe Bedingung zweimal (zwei Buffs eines Namens): einmal',
  simplify([{ s: 1, c: [['down', 5], ['down', 6], ['up', 9]] }], namen).map((l) => l.c), [[['down', 5], ['up', 9]]]);
check('bereit oder nicht bereit gilt immer: die Zeile hat keine Bedingung',
  simplify([{ s: 1, c: [['up', 9], ['or', ['ready', 7], ['notready', 7]]] }], namen).map((l) => l.c), [[['up', 9]]]);
check('aktiv neben genau 3 Stapeln: die Stapel sagen es',
  simplify([{ s: 1, c: [['up', 8], ['stackis', 8, 3]] }], namen).map((l) => l.c), [[['stackis', 8, 3]]]);
check('genug neben einer Schwelle derselben Ressource: die Schwelle sagt es',
  s([{ s: 1, c: [['resenough', 'runic_power'], ['resfull', 'runic_power', 30]] }]), [[1, [['resfull', 'runic_power', 30]], undefined]]);
check('unter 1 frei ist voll',
  s([{ s: 1, c: [['resfull', 'combo_points', 1]] }]), [[1, [['resfull', 'combo_points']], undefined]]);
check('ein Oder aus zusammengelegten Zeilen wird zusammengefasst',
  s([{ s: 1, c: [], any: [[['stackmin', 3, 8]], [['stackmin', 3, 5]]] }]), [[1, [['stackmin', 3, 5]], undefined]]);
// Hoechstens zwoelf Zeilen: zuerst fallen Zeilen eines Zaubers, der weiter
// unten noch steht, die mit den meisten Bedingungen zuerst.
const lang = [];
for (let i = 0; i < 10; i += 1) lang.push({ s: 100 + i, c: [['up', 1]] });
lang.push({ s: 100, c: [['up', 2], ['up', 3]] }, { s: 101, c: [['up', 4]] }, { s: 102, c: [['up', 5], ['up', 6]] }, { s: 50 });
check('hoechstens zwoelf Zeilen, kein Zauber verschwindet',
  s(lang).map((l) => l[0]), [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 101, 50]);
check('weiter unten mit mehr Bedingungen als oben: faellt weg',
  s([{ s: 1, c: [['refresh', 1]] }, { s: 2 }, { s: 1, c: [['refresh', 1], ['down', 5]] }]),
  [[1, [['refresh', 1]], undefined], [2, [], undefined]]);
check('weiter unten mit anderen Bedingungen: bleibt',
  s([{ s: 1, c: [['refresh', 1]] }, { s: 2 }, { s: 1, c: [['up', 5]] }]),
  [[1, [['refresh', 1]], undefined], [2, [], undefined], [1, [['up', 5]], undefined]]);
check('direkt vor demselben Zauber ohne Bedingung faellt die Zeile',
  s([{ s: 1, c: [['up', 5]] }, { s: 1 }, { s: 2 }]), [[1, [], undefined], [2, [], undefined]]);
// Himmlische Ausrichtung steht nur mit "vor der ersten Inkarnation" in der
// Liste: ohne die Bedingung bleibt sie - an ihrem Platz, sobald verfuegbar.
check('ein Cooldown, der sonst verschwaende, bleibt sobald verfuegbar',
  simplify([{ s: 1, c: [['up', 5]] }, { s: 2, c: [['notyet', ['up', 3]]] }, { s: 4 }], { isCooldown: (id) => id === 2 })
    .map((l) => [l.s, l.c]), [[1, [['up', 5]]], [2, []], [4, []]]);
check('Sturmangriff nur am Pull wird nicht gerettet',
  simplify([{ s: 2, c: [['timeunder', 0.5]] }, { s: 4 }], { isCooldown: () => true }).map((l) => l.s), [4]);
check('ein Zauber ohne Abklingzeit verschwindet dagegen',
  simplify([{ s: 2, c: [['notyet', ['up', 3]]] }, { s: 4 }], { isCooldown: () => false }).map((l) => l.s), [4]);
check('dieselbe Zeile weiter unten faellt weg',
  s([{ s: 1, c: [['up', 5]] }, { s: 2 }, { s: 1, c: [['up', 5], ['cdsoon', 3]] }]), [[1, [['up', 5]], undefined], [2, [], undefined]]);
// Schnelligkeit der Ahnen ohne Bedingung ist kein Fueller: nach ihr geht es
// weiter, solange sie abklingt.
check('nach einer Zeile ohne Bedingung geht es weiter',
  s([{ s: 1 }, { s: 2, c: [['up', 6]] }, { s: 3 }]), [[1, [], undefined], [2, [['up', 6]], undefined], [3, [], undefined]]);
check('ohne Bedingung schon oben: spaetere Zeilen des Zaubers fallen weg',
  s([{ s: 1 }, { s: 2, c: [['up', 6]] }, { s: 1, c: [['up', 5]] }]), [[1, [], undefined], [2, [['up', 6]], undefined]]);

// Trinkets und Traenke: dieselben Regeln.
check('Bedingungen eines Gegenstands: einfach, nichts doppelt',
  simpleConditions([['down', 5], ['down', 5], ['resunder', 'rage', 80], ['cmp', 1, 'gt', 2], ['up', 6], ['ready', 7]]),
  [['down', 5], ['up', 6], ['ready', 7]]);
check('nichts Verstaendliches: keine Bedingung',
  simpleConditions([['cmp', 1, 'gt', 2]]), undefined);

console.log(failed === 0 ? '\nalles gruen' : `\n${failed} Fehler`);
process.exit(failed === 0 ? 0 : 1);
