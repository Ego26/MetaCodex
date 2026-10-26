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

check('Feinabstimmung faellt aus der Bedingung, eine Abklingzeit bleibt',
  s([{ s: 1, c: [['down', 5], ['resnotcap', 'maelstrom', 15], ['cdsoon', 7]] }]), [[1, [['down', 5], ['cdsoon', 7]], undefined]]);
// Wut vor Toben, 26. Oktober: "unter 2 Sek. uebrig" ist "laeuft bald aus".
check('kurze Restzeit heisst laeuft bald aus, das Aktiv sagt dann nichts mehr',
  s([{ s: 1, c: [['up', 5], ['remunder', 5, 2]] }]), [[1, [['refresh', 5]], undefined]]);
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
// Kein Oder wird strenger als bei SimC (26. Oktober): ein Und-Zweig bleibt als Gruppe.
check('ein Oder mit Und-Zweig wird zu einem von mehreren',
  s([{ s: 1, c: [['up', 4], ['or', ['up', 5], ['and', ['up', 6], ['ready', 7]]]] }]),
  [[1, [['up', 4]], [[['up', 5]], [['up', 6], ['ready', 7]]]]]);
check('ein Zweig, den niemand pruefen kann, nimmt das ganze Oder mit',
  s([{ s: 1, c: [['up', 4], ['or', ['up', 5], ['cmp', 1, 'gt', 2]]] }]), [[1, [['up', 4]], undefined]]);
check('vom Und-Zweig bleibt, was ein Spieler prueft',
  s([{ s: 1, c: [['or', ['up', 5], ['and', ['up', 6], ['cmp', 1, 'gt', 2]]]] }]), [[1, [['or', ['up', 5], ['up', 6]]], undefined]]);
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
// Tierherrschaft, 25. Oktober: Toetungsbefehl hing an "Heulen bereit oder ...".
check('ein Zauber, den die meisten Top-Spieler wirken, bleibt sobald verfuegbar',
  simplify([{ s: 1 }, { s: 2, more: true }, { s: 4, c: [['up', 5]] }, { s: 3 }],
    { isCooldown: () => false, isPlayed: (id) => id === 2 }).map((l) => [l.s, l.c]),
  [[1, []], [2, []], [4, [['up', 5]]], [3, []]]);
check('die letzte Zeile ist der Fueller, auch wenn ihre Bedingung vage ist',
  simplify([{ s: 1, c: [['up', 5]] }, { s: 2 }, { s: 3, c: [['cmp', ['cd', 9], 'gt', ['gcd']]] }])
    .map((l) => [l.s, l.c]), [[1, [['up', 5]]], [2, []], [3, []]]);
// Feuer, 25. Oktober: "Einaeschern, wenn Einaeschern aktiv oder bereit ist".
check('"wenn X bereit ist" sagt bei X selbst nichts',
  s([{ s: 7, c: [['or', ['up', 7], ['ready', 7]]] }, { s: 2 }]), [[7, [], undefined], [2, [], undefined]]);
check('nicht aktiv und (aktiv oder bereit) ist nicht aktiv und bereit',
  s([{ s: 1, c: [['down', 7], ['or', ['up', 7], ['ready', 7]]] }]), [[1, [['down', 7], ['ready', 7]], undefined]]);
check('A oder (nicht A und B) ist A oder B',
  s([{ s: 1, any: [[['up', 5]], [['down', 5], ['up', 6]]] }]), [[1, [['or', ['up', 5], ['up', 6]]], undefined]]);
check('ein Zweig, den die Zeile ausschliesst, faellt weg',
  s([{ s: 1, c: [['down', 7]], any: [[['up', 7], ['up', 5]], [['up', 6], ['ready', 8]]] }]),
  [[1, [['down', 7], ['up', 6], ['ready', 8]], undefined]]);
check('eine gerettete Zeile behaelt ihren Ablauf und die Combopunkte',
  simplify([{ s: 2, c: [['or', ['and', ['refresh', 2], ['resmin', 'combo_points', 6], ['cmp', 1, 'gt', 2]], ['cmp', 3, 'gt', 4]]] }, { s: 4 }],
    { isPlayed: () => true }).map((l) => [l.s, l.c]), [[2, [['refresh', 2], ['resmin', 'combo_points', 6]]], [4, []]]);
check('Schattenschlag: verstohlen sagt mehr als die Energie',
  simplify([{ s: 2, c: [['or', ['and', ['stealthed'], ['resmin', 'energy', 61], ['cmp', 1, 'gt', 2]], ['cmp', 3, 'gt', 4]]] }, { s: 4 }],
    { isPlayed: () => true }).map((l) => [l.s, l.c]), [[2, [['stealthed']]], [4, []]]);
check('vier einfache Gruende: die ersten drei bleiben',
  simplify([{ s: 2, c: [['or', ['or', ['or', ['up', 5], ['up', 6]], ['up', 7]], ['resmin', 'energy', 61]]] }, { s: 4 }],
    { isPlayed: () => true }).map((l) => [l.s, l.c]), [[2, [['or', ['or', ['up', 5], ['up', 6]], ['up', 7]]]], [4, []]]);
check('Verwuestung "oder in den ersten 5 Sekunden" ist kein Opener',
  simplify([{ s: 2, c: [['or', ['cmp', 1, 'gt', 2], ['timeunder', 5]]] }, { s: 4 }], { isPlayed: () => true }).map((l) => l.s), [2, 4]);
check('weniger als 5,2 Seelensplitter gilt immer',
  s([{ s: 1, c: [['resunder', 'soul_shard', 5.2], ['down', 5]] }]), [[1, [['down', 5]], undefined]]);
check('ein Zweig, der immer gilt, macht das Oder wahr',
  s([{ s: 1, c: [['up', 6]], any: [[['charges', 1, 2]], [['resunder', 'soul_shard', 5.4]]] }]), [[1, [['up', 6]], undefined]]);

// Trinkets und Traenke: dieselben Regeln.
check('Bedingungen eines Gegenstands: einfach, nichts doppelt',
  simpleConditions([['down', 5], ['down', 5], ['resunder', 'rage', 80], ['cmp', 1, 'gt', 2], ['up', 6], ['ready', 7]]),
  [['down', 5], ['up', 6], ['ready', 7]]);
// Was ein anderer Zweig schon sagt, faellt weg (26. Oktober).
check('"laeuft aus und staerker, oder laeuft aus" ist "laeuft aus"',
  s([{ s: 1, c: [['or', ['and', ['refresh', 5], ['stronger', 5]], ['refresh', 5]]] }]), [[1, [['refresh', 5]], undefined]]);
check('"gleich bereit, aktiv oder bereit" ist "aktiv oder gleich bereit"',
  s([{ s: 1, c: [['or', ['or', ['cdsoon', 7], ['up', 7]], ['ready', 7]]] }]), [[1, [['or', ['cdsoon', 7], ['up', 7]]], undefined]]);
check('aktiv und laeuft in 12 Sek. aus: das Auslaufen sagt es',
  s([{ s: 1, c: [['up', 5], ['remunder', 5, 12]] }]), [[1, [['remunder', 5, 12]], undefined]]);
check('nicht aktiv und laeuft in 3 Sek. aus: nicht aktiv',
  s([{ s: 1, c: [['down', 5], ['remunder', 5, 3]] }]), [[1, [['down', 5]], undefined]]);
check('eine Abklingzeit jenseits jedes Kampfes ist keine Pruefung',
  s([{ s: 1, c: [['up', 4], ['or', ['up', 5], ['cdover', 5, 3590]]] }]), [[1, [['up', 4]], undefined]]);
check('nichts Verstaendliches: keine Bedingung',
  simpleConditions([['cmp', 1, 'gt', 2]]), undefined);

console.log(failed === 0 ? '\nalles gruen' : `\n${failed} Fehler`);
process.exit(failed === 0 ? 0 : 1);
