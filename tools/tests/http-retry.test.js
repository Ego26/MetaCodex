// Wann noch einmal gefragt wird, nachgerechnet.
//
// Der Nachtlauf vom 8. Oktober 2026 ist an einem einzigen 504 von
// wago.tools gestorben, nach 143 Minuten und mit zwei Stunden fertig
// gesammelter Raiddaten auf der Platte. Was einmal falsch war, bekommt
// einen Test.
const { worthRetrying, waitSeconds, WAITS } = require('../lib/http-retry');

let failed = 0;
function check(what, got, want) {
  const ok = got === want;
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}` + (ok ? '' : `  -> ${got}, erwartet ${want}`));
}

function fehler(statusCode) {
  const e = new Error('x');
  if (statusCode) e.statusCode = statusCode;
  return e;
}

console.log('Wiederholen: lohnt sich ein zweiter Versuch?');

// Das, woran der Lauf gestorben ist.
check('504 Gateway Timeout', worthRetrying(fehler(504)), true);
check('500 Internal Server Error', worthRetrying(fehler(500)), true);
check('502 Bad Gateway', worthRetrying(fehler(502)), true);
check('503 Service Unavailable', worthRetrying(fehler(503)), true);

// Unsere Schuld oder ihre Entscheidung - dieselbe Frage lauter zu
// stellen hilft nicht.
check('404 bleibt 404', worthRetrying(fehler(404)), false);
check('403 wird nicht wiederholt', worthRetrying(fehler(403)), false);
check('429 wird nicht wiederholt', worthRetrying(fehler(429)), false);
check('400 wird nicht wiederholt', worthRetrying(fehler(400)), false);

// Ohne Status ist es das Netz: abgebrochen, zeitueberschritten, nicht
// aufgeloest. Auch das geht vorbei.
check('Netzfehler ohne Status', worthRetrying(fehler(null)), true);
check('gar kein Fehler', worthRetrying(null), false);

console.log('Wiederholen: wie lange gewartet wird');

// Kurz, laenger, lang - und dann nicht weiter wachsend.
check('erster Fehlschlag', waitSeconds(0), WAITS[0]);
check('zweiter', waitSeconds(1), WAITS[1]);
check('dritter', waitSeconds(2), WAITS[2]);
check('darueber hinaus bleibt es beim letzten', waitSeconds(9), WAITS[WAITS.length - 1]);

// WIE LANGE WIR INSGESAMT WARTEN, IST DIE EIGENTLICHE ENTSCHEIDUNG.
//
// Am 10. Oktober war wago.tools laenger als anderthalb Minuten nicht
// zu sprechen. Die Geduld reichte 85 Sekunden weit, und zehn Minuten
// gesammelte Messung gingen verloren. Eine Stoerung, die ein paar
// Minuten dauert, muss ueberlebbar sein - und dass das so bleibt,
// steht hier und nicht nur in einem Kommentar.
const geduld = WAITS.reduce((a, b) => a + b, 0);
check('wir halten eine Stoerung von Minuten aus (' + geduld + 's)', geduld >= 240, true);

// Und sie werden laenger, nicht kuerzer: wer sofort nachsetzt, macht
// einen ueberlasteten Dienst noch langsamer.
let steigend = true;
for (let i = 1; i < WAITS.length; i += 1) {
  if (WAITS[i] <= WAITS[i - 1]) steigend = false;
}
check('die Pausen werden laenger', steigend, true);

// WER WIEDERHOLT, NIMMT DIESE REGEL.
//
// In der Nacht zum 13. Oktober gab der Katalog nach einer Minute auf,
// waehrend die gemeinsame Geduld 4,4 Minuten betraegt: er hatte seine
// eigene Wiederholung, vier Versuche mit 10, 20 und 30 Sekunden. Zwei
// Geduldsproben fuer dasselbe Problem sind eine zu viel - und die
// zweite merkt niemand, bis eine Nacht daran stirbt.
const fs = require('fs');
const path = require('path');
const toolDir = path.join(__dirname, '..');
const ohneRegel = [];
for (const name of fs.readdirSync(toolDir)) {
  if (!name.endsWith('.js')) continue;
  const text = fs.readFileSync(path.join(toolDir, name), 'utf8');
  // "Noch einmal" steht in jeder unserer Wiederholungen.
  if (!text.includes('Noch einmal')) continue;
  if (!text.includes("require('./lib/http-retry')")) ohneRegel.push(name);
}
check('wer wiederholt, nimmt die gemeinsame Regel', ohneRegel.join(', '), '');

console.log('');
if (failed) {
  console.error(`${failed} Fehler`);
  process.exit(1);
}
console.log('alles gruen');
