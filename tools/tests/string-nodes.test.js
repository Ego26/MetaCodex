// Die Knoten aus dem String, nachgerechnet.
//
// Am 7. November stand ein gruener Rahmen auf dem Apex-Talent jedes Builds aus
// den Logs: drei Log-Zeilen fuer einen Knoten, und das Spiel kennt nur die
// letzte. Was einmal falsch war, bekommt einen Test.
const { useStringNodes } = require('../lib/string-nodes');

let failed = 0;
function check(what, got, want) {
  const ok = got === want;
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}${ok ? '' : ` -> ${got}, erwartet ${want}`}`);
}

console.log('Knoten aus dem String');

const STRINGS = {
  HAUPT: [
    { spell: 10, rank: 1 }, { spell: 64, rank: 4 }, { spell: null, rank: 1 },
  ],
  ANDERS: [{ spell: 11, rank: 1 }, { spell: 64, rank: 4 }],
  STUFE: [{ spell: 10, rank: 1 }, { spell: 64, rank: 3 }],
};
const decode = (text) => STRINGS[text] || null;
const zeige = (nodes) => nodes.map((n) => n.spell + ':' + n.rank).join(' ');

const logs = () => ({
  build: {
    text: 'HAUPT',
    nodes: [{ spell: 10, rank: 1 }, { spell: 61, rank: 1 }, { spell: 62, rank: 2 }, { spell: 64, rank: 1 }],
  },
  builds: [
    { text: 'ANDERS', added: [11, 99], removed: [10, 98] },
    { text: 'STUFE', added: [63], removed: [62] },
    { text: 'KAPUTT', added: [5], removed: [6] },
  ],
});

const v = logs();
useStringNodes(v, decode);
check('drei Log-Zeilen werden ein Knoten mit Rang 4', zeige(v.build.nodes), '10:1 64:4');
check('die Alternative rechnet gegen dieselben Knoten', v.builds[0].added.join(), '11');
check('  in beide Richtungen', v.builds[0].removed.join(), '10');
check('nur die Stufe anders ist keine Alternative', v.builds.some((b) => b.text === 'STUFE'), false);
check('was sich nicht lesen laesst, bleibt stehen', v.builds.find((b) => b.text === 'KAPUTT').added.join(), '5');

const ohne = { build: { nodes: [{ spell: 1, rank: 1 }] } };
useStringNodes(ohne, decode);
check('ohne String bleiben die Knoten', zeige(ohne.build.nodes), '1:1');
const falsch = { build: { text: 'KAPUTT', nodes: [{ spell: 1, rank: 1 }] } };
useStringNodes(falsch, decode);
check('ein unlesbarer String aendert nichts', zeige(falsch.build.nodes), '1:1');
useStringNodes(null, decode);
useStringNodes({}, decode);
check('nichts da, nichts passiert', true, true);

if (failed) {
  console.log('');
  console.log(failed + ' Fehler');
  process.exit(1);
}
console.log('');
console.log('alles gruen');
