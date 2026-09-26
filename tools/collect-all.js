// Der taegliche Lauf: alle Quellen in der richtigen Reihenfolge.
//
//     node tools/collect-all.js <Pfad zum Repo> [nur=<quelle>]
//
// WARUM ES DIESE DATEI GIBT. Die Aufteilung der Quellen ist eine
// Entscheidung, und eine Entscheidung, die nur in einem Dokument steht,
// wird beim naechsten Mal anders getroffen. Hier steht sie als Ablauf:
//
//   raider.io       M+: Ausruestung, Verzauberungen, Steine, Talente.
//                   Offene API, kein Stundenkontingent.
//
//   murlok.io       Fertige Prozentwerte und alle PvP-Klammern.
//                   Abrufbar, aggregiert, kein Kontingent.
//
//   Warcraft Logs   NUR was sonst niemand veroeffentlicht:
//                   Verbrauchsgueter und Raid.
//
// Die letzte Zeile ist der Punkt. Warcraft Logs rechnet in Punkten je
// Stunde, und ein voller Durchgang ueber M+ UND Raid hat sie an einem
// Abend verbrannt - drei Sammlungen danach starben an HTTP 429 und
// schrieben nichts. Seit M+ von raider.io kommt, bleibt bei Warcraft Logs
// nur der Rest, und der passt.
//
// Der Katalog laeuft zuerst: die Sammler brauchen die Verzauberungskarte,
// und eine veraltete Karte laesst Verzauberungen still verschwinden.

const path = require('path');
const { spawn } = require('child_process');

const BASE = process.argv[2];
if (!BASE) {
  console.error('Aufruf: node tools/collect-all.js <Pfad zum Repo> [nur=<quelle>]');
  process.exit(1);
}
// Eine Liste, nicht ein einzelner Schritt.
//
// Warcraft Logs rechnet in Punkten JE STUNDE, und der ganze Tageslauf
// braucht mehr, als eine Stunde hergibt: er wartet auf die naechste.
// Bei GitHub stirbt ein Job nach sechs Stunden - am 25.09. brauchte er
// fuenfeinhalb. Darum laeuft der Lauf dort in mehreren Jobs,
// nacheinander, jeder mit seiner eigenen Frist, und jeder sagt mit
// nur=a,b,c, welche Schritte ihm gehoeren.
const ONLY = (process.argv.find((a) => a.startsWith('nur=')) || '').slice(4)
  .split(',').map((s) => s.trim()).filter((s) => s !== '');
const wanted = (key) => ONLY.length === 0 || ONLY.indexOf(key) >= 0;

// Jeder Schritt nennt, WAS er holt und WARUM von dort. Wer hier etwas
// verschiebt, soll die Begruendung mitverschieben muessen.
const STEPS = [
  {
    key: 'catalog',
    what: 'Katalog aus den Spieldaten',
    why: 'Die Verzauberungskarte muss stimmen, bevor jemand sie benutzt.',
    script: 'build-catalog.js',
    args: [],
    env: {},
  },
  {
    key: 'raiderio',
    what: 'M+: Ausruestung, Verzauberungen, Steine, Talente',
    why: 'Offene API ohne Kontingent, und die Talentketten liegen fertig vor.',
    script: 'collect-raiderio.js',
    args: [],
    env: { MC_DUNGEONS: '1', MC_PAGES: '30', MC_PROFILES: '1200' },
  },
  {
    key: 'murlok',
    what: 'Fertige Anteile und die PvP-Klammern',
    why: 'Aggregiert man nicht nach, was schon aggregiert vorliegt.',
    script: 'collect-murlok.js',
    args: ['m+,2v2,3v3,rbg,solo,blitz'],
    env: {},
  },
  {
    key: 'raid',
    what: 'Raid, heroisch',
    why: 'Kein Aggregator veroeffentlicht Raiddaten in dieser Tiefe.',
    script: 'collect-wcl.js',
    args: ['raid', '4'],
    // Alle Bosse aller laufenden Raids; 300 Berichte reihum verteilt.
    env: { MC_DUNGEONS: '1', MC_REPORTS: '300' },
  },
  {
    key: 'raid-mythic',
    what: 'Raid, mythisch',
    why: 'Andere Schwierigkeit, andere Ausruestung.',
    script: 'collect-wcl.js',
    args: ['raid', '5'],
    env: { MC_DUNGEONS: '1', MC_REPORTS: '240' },
  },
  {
    key: 'raid-normal',
    what: 'Raid, normal',
    why: 'Die Aktivitaet steht im Fenster und hatte keine Daten. Der Lauf sammelte Heroisch und Mythisch, "Raid (Normal)" fiel dabei still weg - und was keine Daten hat, zeigt das Addon gar nicht erst an.',
    script: 'collect-wcl.js',
    args: ['raid', '3'],
    // Kleiner als die anderen beiden: wer normal raidet, findet hier
    // dieselben Bosse, nur mit weniger Auswahl an Berichten.
    env: { MC_DUNGEONS: '1', MC_REPORTS: '120' },
  },
  {
    key: 'consumables',
    what: 'M+: Verbrauchsgueter',
    why: 'Speisen, Traenke und Oele fuehrt kein Aggregator - nur die Logs.',
    script: 'collect-wcl.js',
    args: ['mplus'],
    // Alles, was die Rangliste hergibt, statt einer Auswahl daraus.
    //
    // Die Rangliste der hohen Schluessel umfasst rund tausend Laeufe.
    // Vierhundert davon ergaben fuer Daemonologie 61 Messungen, und auf
    // 61 Messungen eine Meta zu behaupten ist duenn - bei einer Spec,
    // die oben selten ist, entscheidet dann eine Handvoll Gruppen. Die
    // Grenze liegt jetzt ueber dem, was die Liste ueberhaupt enthaelt:
    // gezaehlt wird die ganze Spitze, nicht eine Stichprobe daraus.
    env: { MC_ENCOUNTERS: '8', MC_REPORTS: '1000' },
  },
  {
    key: 'keys',
    what: 'M+ je Schluesselstufe: Verbrauchsgueter und Talente',
    why: 'Die Aktivitaet "M+ (+7 bis +21)" hat ihre eigenen Zahlen - andere Stufen, andere Mischung. Sie lief bisher nur von Hand, und ihre Daten wurden still alt.',
    script: 'collect-wcl.js',
    args: ['mplus-keys'],
    // Doppelt so viele wie bisher. Hier gibt die Rangliste ueber
    // fuenftausend Laeufe her, eine Stichprobe bleibt es also - aber
    // eine, die je Spec ueber hundert Messungen traegt.
    env: { MC_DUNGEONS: '1', MC_REPORTS: '400' },
  },
  {
    key: 'bnet',
    what: 'Battle.net: PvP-Ranglisten und die Profile der Spitze',
    why: 'Blizzard fuehrt Wertung, Import-String und PvP-Talente selbst - die Quelle, aus der die anderen abschreiben. Ohne Zugangsdaten wird der Schritt uebersprungen.',
    script: 'collect-bnet.js',
    args: [],
    env: {},
  },
  {
    key: 'profiles',
    what: 'Profile der Top-Spieler: Ketten fuer Raid und PvP, Ausruestung',
    why: 'Die einzige Quelle einer fertigen Kette ist der Client des Spielers - und das Profil zeigt sie. Geprueft gegen Kampf und Heatmap.',
    script: 'collect-profiles.js',
    args: [],
    env: {},
  },
  {
    key: 'build',
    what: 'Alles zu den Addon-Tabellen zusammenbauen',
    why: '',
    script: 'build-recommendations.js',
    args: [],
    env: {},
  },
];

function run(step) {
  return new Promise((resolve) => {
    const file = path.join(BASE, 'tools', step.script);
    const child = spawn(process.execPath, [file, BASE, ...step.args], {
      env: { ...process.env, ...step.env },
      stdio: 'inherit',
    });
    child.on('exit', (code) => resolve(code === 0));
    child.on('error', () => resolve(false));
  });
}

(async () => {
  for (const key of ONLY) {
    if (!STEPS.some((s) => s.key === key)) {
      console.error('Unbekannter Schritt: ' + key);
      console.error('Bekannt sind: ' + STEPS.map((s) => s.key).join(', '));
      process.exit(2);
    }
  }
  const started = Date.now();
  const failed = [];

  for (const step of STEPS) {
    if (!wanted(step.key)) continue;
    console.log('\n' + '='.repeat(64));
    console.log(step.key + ': ' + step.what);
    if (step.why) console.log('  ' + step.why);
    console.log('='.repeat(64));

    const stepStarted = Date.now();
    const ok = await run(step);
    console.log('  ' + step.key + ': '
      + Math.round((Date.now() - stepStarted) / 60000) + ' Minuten');
    if (!ok) {
      failed.push(step.key);
      // Weitermachen statt abbrechen. Jeder Schritt schreibt seine eigene
      // Datei; ein gescheiterter macht die anderen nicht wertlos, und der
      // Zusammenbau nimmt, was da ist.
      console.log('\n  ! ' + step.key + ' fehlgeschlagen - der Rest laeuft weiter.');
    }
  }

  const minutes = Math.round((Date.now() - started) / 60000);
  console.log('\n' + '='.repeat(64));
  console.log('Fertig nach ' + minutes + ' Minuten.');
  if (failed.length) {
    console.log('Fehlgeschlagen: ' + failed.join(', '));
    console.log('Einzeln nachholen: node tools/collect-all.js . nur=' + failed[0]);
    process.exit(1);
  }
  console.log('Jetzt ins Spiel: tools/sync.ps1');
})();
