// Die Zaehlregel fuer Verbrauchsgueter, nachgerechnet.
//
// Sie entscheidet, welche Prozentzahl im Fenster steht, und sie ist an
// einem Abend im September 2026 als falsch aufgefallen. Was einmal
// falsch war, bekommt einen Test.
const { countsForThisFight, PRE_PULL } = require('../lib/consumable-window');

let failed = 0;
function check(what, got, want) {
  const ok = got === want;
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`);
}

const START = 1000000;
const END = 1600000;

console.log('Verbrauchsgueter: zaehlt es fuer diesen Lauf?');

// Der Trank im Lauf.
check('Kampftrank mittendrin zaehlt',
  countsForThisFight('potion', START + 60000, START, END), true);
check('Heiltrank mittendrin zaehlt',
  countsForThisFight('heal', START + 60000, START, END), true);

// Der Praetrank - der Grund fuer den Vorlauf.
check('Praetrank fuenf Sekunden vor dem Pull zaehlt',
  countsForThisFight('potion', START - 5000, START, END), true);
check('Praetrank genau am Rand des Vorlaufs zaehlt',
  countsForThisFight('potion', START - PRE_PULL, START, END), true);

// Und der Trank aus einem anderen Lauf desselben Berichts. Genau das
// war der Fehler.
check('Trank eine Minute vor dem Vorlauf zaehlt nicht',
  countsForThisFight('potion', START - PRE_PULL - 60000, START, END), false);
check('Trank nach dem Lauf zaehlt nicht',
  countsForThisFight('potion', END + 1000, START, END), false);

// Was vorher genommen wird und haelt.
check('Speise vor dem Lauf zaehlt',
  countsForThisFight('food', START - 600000, START, END), true);
check('Flaeschchen vor dem Lauf zaehlt',
  countsForThisFight('flask', START - 600000, START, END), true);
check('Rune vor dem Lauf zaehlt',
  countsForThisFight('other', START - 600000, START, END), true);
check('Oel vor dem Lauf zaehlt',
  countsForThisFight('oil', START - 600000, START, END), true);

// Im Zweifel zaehlen: Unwissen darf keine Messung wegwerfen.
check('ohne Zeit des Laufs wird nicht gefiltert',
  countsForThisFight('potion', START - 999999, null, null), true);
check('ohne Zeitstempel wird nicht gefiltert',
  countsForThisFight('potion', undefined, START, END), true);
check('unbekannte Art zaehlt',
  countsForThisFight(undefined, START - 600000, START, END), true);

if (failed) {
  console.log(``);
  console.log(failed + ' Fehler');
  process.exit(1);
}
console.log('');
console.log('alles gruen');
