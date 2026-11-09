// Welcher Build oben steht, nachgerechnet.
//
// Ueberleben bekam in den High Keys den Build eines einzigen Spielers, und
// Elementar einen 5-%-Build mit Talenten gegen die Mehrheit. Was einmal falsch
// war, bekommt einen Test.
const { fromSignatures, pickMajority, othersThan, buildsFromPlayers } = require('../lib/majority-build');
const { share } = require('../lib/share');

let failed = 0;
function check(what, got, want) {
  const ok = got === want;
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}${ok ? '' : ` -> ${got}, erwartet ${want}`}`);
}

console.log('Der Mehrheits-Build');

// Zehn Spieler. Talent 1 und 2 nehmen fast alle, 3 und 4 die Minderheit. Der
// haeufigste exakte Build (3 Spieler) traegt 3 und 4 - gegen die Mehrheit.
const builds = {
  '3:1,4:1': 3,
  '1:1,3:1': 2,
  '2:1,4:1': 2,
  '1:1,2:1': 1,
  '1:1,5:1': 1,
  '2:1,5:1': 1,
};
const talents = { '1|1': 4, '2|1': 4, '3|1': 5, '4|1': 5, '5|1': 2 };
const fall = { '1|1': 8, '2|1': 8, '3|1': 2, '4|1': 2 };
const cands = fromSignatures({ '3:1,4:1': 2, '1:1,2:1': 1, '1:1,3:1': 1 });
const pick = pickMajority(cands, fall, 10);
check('nicht der haeufigste, sondern der mit den gefragtesten Talenten', pick.key, '1:1,2:1');
check('  er nennt, wie viele ihn exakt spielen', pick.count, 1);
check('  und wie weit er mit der Mehrheit geht', pick.fit, 100);

const gegen = pickMajority(fromSignatures({ '3:1,4:1': 2 }), fall, 10);
check('ein Build gegen die Mehrheit traegt das in seiner Zahl', gegen.fit, 0);

const ganz = pickMajority(fromSignatures(builds), talents, 10);
check('alle Kandidaten werden geprueft, nicht nur die haeufigen', ganz.key, '3:1,4:1');

const rang = pickMajority(fromSignatures({ '1:2': 1, '1:1': 1 }), { '1|2': 8, '1|1': 2 }, 10);
check('der Rang gehoert zum Talent', rang.key, '1:2');

const gleich = pickMajority(fromSignatures({ '1:1': 1, '2:1': 3 }), { '1|1': 5, '2|1': 5 }, 10);
check('bei Gleichstand der haeufigere', gleich.key, '2:1');
const fest = pickMajority(fromSignatures({ '2:1': 1, '1:1': 1 }), { '1|1': 5, '2|1': 5 }, 10);
check('und dann immer derselbe', fest.key, '1:1');

check('ein einziger Spieler ist sein eigener Mehrheits-Build',
  pickMajority(fromSignatures({ '1:1': 1 }), { '1|1': 1 }, 1).fit, 100);
check('nichts gezaehlt, nichts gewaehlt', pickMajority([], {}, 0), null);

const andere = othersThan(fromSignatures({ 'a:1': 1, 'b:1': 5, 'c:1': 2 }), 'b:1');
check('die Alternativen ohne den gewaehlten, haeufigste zuerst',
  andere.map((c) => c.key).join(' '), 'c:1 a:1');

// Aus Profilen, wie Profilpruefung und Battle.net sie liefern (8. November:
// Battle.net brach hier mit "reading 'spells'" ab).
console.log('Builds aus geprueften Profilen');
const sp = (...ids) => ids.map((id) => ({ spell: id, rank: 1 }));
const spieler = [
  { verified: true, text: 'MEHRHEIT', spells: sp(1, 2) },
  { verified: true, text: 'AUSREISSER', spells: sp(3, 4) },
  { verified: true, text: 'AUSREISSER', spells: sp(3, 4) },
  { verified: true, text: 'NAH', spells: sp(1, 3) },
  { verified: true, text: 'NAH2', spells: sp(2, 5) },
  { verified: true, text: 'MEHRHEIT', spells: sp(1, 2) },
  { verified: false, text: 'UNGEPRUEFT', spells: sp(9) },
  { verified: true, text: null, spells: sp(8) },
];
const aus = buildsFromPlayers(spieler, share);
check('der Mehrheits-Build aus den Profilen', aus.build && aus.build.text, 'MEHRHEIT');
check('  auf allen geprueften mit String', aus.build && aus.build.players, 6);
check('  mit seinen Knoten', aus.build && aus.build.nodes.map((n) => n.spell).join(), '1,2');
check('  und wie weit er mit der Mehrheit geht', aus.build && aus.build.fit, 100);
check('die Alternativen rechnen gegen ihn', aus.builds && aus.builds[0].text, 'AUSREISSER');
check('  mit dem, was dazukommt', aus.builds && aus.builds[0].added.join(), '3,4');
check('  und dem, was wegfaellt', aus.builds && aus.builds[0].removed.join(), '1,2');
check('Ungeprueftes und Strings ohne Text zaehlen nicht',
  aus.builds.some((b) => b.text === 'UNGEPRUEFT' || b.text === null), false);
check('ohne gepruefte Spieler kein Build', JSON.stringify(buildsFromPlayers([], share)), '{}');
check('  auch ohne Liste', JSON.stringify(buildsFromPlayers(undefined, share)), '{}');

if (failed) {
  console.log('');
  console.log(failed + ' Fehler');
  process.exit(1);
}
console.log('');
console.log('alles gruen');
