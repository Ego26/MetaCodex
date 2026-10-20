// Die Regeln hinter "ersetzt" (tools/lib/replace.js): ein Zauber und sein
// Ersatz stehen nie nebeneinander in der Rotation - und ein Zauber, der nur
// zeitweise ersetzt wird, faellt nicht heraus.
const { buildReplacements, replacedNames } = require('../lib/replace');

let failed = 0;
function check(what, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`
    + (ok ? '' : `\n          bekommen: ${JSON.stringify(got)}`
      + `\n          erwartet: ${JSON.stringify(want)}`));
}

// Die echten IDs (12.1.5): Namen wie im Spiel.
const NAMES = {
  470411: 'flame_shock', 188389: 'flame_shock', 470057: 'voltaic_blaze',
  378081: 'natures_swiftness', 443454: 'ancestral_swiftness', 448866: 'ancestral_swiftness',
  188196: 'lightning_bolt', 452201: 'tempest', 454015: 'tempest', 117014: 'elemental_blast', 1260667: 'elementalist',
  51505: 'lava_burst', 999001: 'lava_burst',
};
const LASTS = { 448866: -1, 454015: 30000, 1260667: 30000 };
const map = buildReplacements({
  auras: [
    { carrier: 448866, old: 378081, neu: 443454 },   // dauerhaft
    { carrier: 454015, old: 188196, neu: 452201 },   // Proc, 30 Sek.
    { carrier: 1260667, old: 188196, neu: 117014 },  // Proc, 30 Sek.
  ],
  traits: [{ old: 470411, neu: 470057 }],
  specs: [{ spec: 262, old: 51505, neu: 999001 }],    // gleicher Name
  lastsMs: (id) => (LASTS[id] === undefined ? 0 : LASTS[id]),
});
const build = (taken) => ({ specID: 262, known: (id) => taken.includes(NAMES[id]), nameOf: (id) => NAMES[id] });

const alles = replacedNames(map, build(['voltaic_blaze', 'ancestral_swiftness', 'tempest', 'elemental_blast']));
check('Voltaiklohe ersetzt Flammenschock (Talent)', alles.has('flame_shock'), true);
// Eine Aura allein beweist nichts - sie kann ein Proc "bis verbraucht" sein.
// Ob Schnelligkeit der Natur ersetzt ist, sagen erst die Logs (unten).
check('ohne Messung: auch die Aura der Ahnen ist noch kein Beweis', alles.has('natures_swiftness'), false);
check('Blitzschlag bleibt - Sturmgewitter und Elementarschlag ersetzen ihn nur im Proc', alles.has('lightning_bolt'), false);
check('eine Spec-Version mit gleichem Namen ersetzt nichts', alles.has('lava_burst'), false);
const ohne = replacedNames(map, build([]));
check('ohne Voltaiklohe bleibt Flammenschock', ohne.has('flame_shock'), false);
check('ohne Schnelligkeit der Ahnen bleibt Schnelligkeit der Natur', ohne.has('natures_swiftness'), false);

// MIT MESSUNG entscheiden die Logs.
const gemessen = (anteile) => ({ ...build(['voltaic_blaze', 'ancestral_swiftness', 'tempest', 'elemental_blast']),
  share: (n) => (anteile[n] === undefined ? 0 : anteile[n]) });
// Niemand wirkt Schnelligkeit der Natur, alle Schnelligkeit der Ahnen: ersetzt.
check('gemessen: keiner wirkt den alten, viele den neuen - ersetzt',
  replacedNames(map, gemessen({ ancestral_swiftness: 0.9, natures_swiftness: 0 })).has('natures_swiftness'), true);
// Ein Viertel wirkt Flammenschock noch: dann ist er nicht ersetzt, egal was die Tabelle sagt.
check('gemessen: viele wirken den alten noch - nicht ersetzt',
  replacedNames(map, gemessen({ voltaic_blaze: 0.8, flame_shock: 0.25 })).has('flame_shock'), false);
// Ohne Messung beweist eine Aura nichts (Coup de Grace, Hammer des Zorns).
const ohneMessung = buildReplacements({
  auras: [{ carrier: 462127, old: 2098, neu: 441776 }], traits: [], specs: [], lastsMs: () => -1,
});
const n2 = { 2098: 'dispatch', 441776: 'coup_de_grace' };
check('ohne Messung: eine Aura ersetzt nichts',
  replacedNames(ohneMessung, { specID: 260, known: () => true, nameOf: (id) => n2[id] }).has('dispatch'), false);
check('gemessen: Coup de Grace als Proc - Erledigen bleibt',
  replacedNames(ohneMessung, { specID: 260, known: () => true, nameOf: (id) => n2[id],
    share: (n) => ({ dispatch: 1, coup_de_grace: 0.95 })[n] }).has('dispatch'), false);

console.log(failed === 0 ? '\nalles gruen' : `\n${failed} Fehler`);
process.exit(failed === 0 ? 0 : 1);
