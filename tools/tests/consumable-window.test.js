// Die Zaehlregel fuer Verbrauchsgueter, nachgerechnet.
//
// Sie entscheidet, welche Prozentzahl im Fenster steht, und sie ist an
// einem Abend im September 2026 als falsch aufgefallen. Was einmal
// falsch war, bekommt einen Test.
const {
  countsForThisFight, PRE_PULL, activeAtPull, AT_PULL,
} = require('../lib/consumable-window');

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

// Vortrank fuer die Zielwerte (31. Oktober): Liquid Luster vor dem Pull
// steckte als +420 Vielseitigkeit in den Werten, ohne Aura dazu. Erkannt
// wird er am ersten Ereignis seines Buffs im Kampf.
console.log('Zielwerte: trug er beim Pull einen Trank mit Wertungs-Buff?');
const ev = (type, when, who) => ({ type, timestamp: when, targetID: who });
const beimPull = (events) => [...activeAtPull(events, START)].sort().join(',');
check('lief schon: erstes Ereignis ist das Ablaufen',
  beimPull([ev('removebuff', START + 27000, 1)]), '1');
check('lief schon: erstes Ereignis ist ein Erneuern',
  beimPull([ev('refreshbuff', START + 25000, 2)]), '2');
check('lief schon: erstes Ereignis ist ein weiterer Stapel',
  beimPull([ev('applybuffstack', START + 3000, 3)]), '3');
check('Schluck im selben Augenblick wie der Pull zaehlt',
  beimPull([ev('applybuff', START + AT_PULL, 4)]), '4');
check('Schluck mitten im Kampf aendert die Werte beim Pull nicht',
  beimPull([ev('applybuff', START + 60000, 5), ev('removebuff', START + 90000, 5)]), '');
check('je Spieler zaehlt nur sein erstes Ereignis',
  beimPull([ev('applybuff', START + 60000, 6), ev('removebuff', START + 27000, 7)]), '7');
check('ohne Beginn des Kampfes: nicht auszuschliessen',
  [...activeAtPull([ev('applybuff', START + 60000, 8)], null)].join(','), '8');
check('keine Ereignisse, kein Vortrank', beimPull([]), '');

if (failed) {
  console.log(``);
  console.log(failed + ' Fehler');
  process.exit(1);
}
console.log('');
console.log('alles gruen');
