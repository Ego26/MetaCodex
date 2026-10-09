// Fuehrt logic_test.lua in einem echten Lua-VM aus (fengari).
//
// Getestet wird nur Logik ohne WoW-API: der Katalogzugriff gegen die
// wirklich erzeugte Data/Catalog.lua. Alles andere - Ausruestung lesen,
// Auctionator, Oberflaeche - braucht den laufenden Client und steht
// deshalb in `/mc probe`.
//
//     node Tests/run.js
//
// fengari wird aus Tests/node_modules genommen. Ist dort nichts
// installiert, greift das Skript auf die Installation von Forever
// Cooldowns zurueck: dieselbe Abhaengigkeit, und ein zweites npm install
// fuer zwei Pakete ist es nicht wert.

const fs = require('fs');
const path = require('path');

const FALLBACK = 'E:/Projekte/WoW/WoWForever/ForeverCooldowns/Tests/node_modules/fengari';

let fengari;
try {
  fengari = require('fengari');
} catch (err) {
  if (!fs.existsSync(FALLBACK)) {
    console.error('fengari nicht gefunden. Entweder:');
    console.error('    cd Tests && npm install');
    console.error('oder Forever Cooldowns mit installierten Tests danebenlegen.');
    process.exit(1);
  }
  fengari = require(FALLBACK);
}

const { lua, lauxlib, lualib, to_luastring } = fengari;

const base = path.resolve(__dirname, '..').replace(/\\/g, '/');
const file = process.argv[2] || path.join(__dirname, 'logic_test.lua');

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

lua.lua_pushstring(L, to_luastring(base));
lua.lua_setglobal(L, to_luastring('BASE'));

// Die TOC wird hier gelesen und als Zeichenkette hereingereicht: fengari
// bringt kein io.lines mit, und der Smoke-Test soll die Ladereihenfolge
// aus der echten TOC nehmen und nicht aus einer zweiten Liste, die
// irgendwann auseinanderlaeuft.
lua.lua_pushstring(L, to_luastring(
  fs.readFileSync(path.join(base, 'MetaCodex.toc'), 'utf8')));
lua.lua_setglobal(L, to_luastring('TOC'));

// Dasselbe fuer das nachladbare Datenaddon. Leer, wenn es (noch) fehlt -
// der Test soll das melden und nicht daran sterben.
const dataToc = path.join(base, 'MetaCodex_Data', 'MetaCodex_Data.toc');
lua.lua_pushstring(L, to_luastring(
  fs.existsSync(dataToc) ? fs.readFileSync(dataToc, 'utf8') : ''));
lua.lua_setglobal(L, to_luastring('DATA_TOC'));

// Und das freiwillige Dungeon-Addon. Fehlt es, laufen die Tests weiter -
// im Spiel faellt dann auch nur die Dungeon-Auswahl weg.
const dungeonToc = path.join(base, 'MetaCodex_Dungeons', 'MetaCodex_Dungeons.toc');
lua.lua_pushstring(L, to_luastring(
  fs.existsSync(dungeonToc) ? fs.readFileSync(dungeonToc, 'utf8') : ''));
lua.lua_setglobal(L, to_luastring('DUNGEON_TOC'));

// Und das Spieler-Addon, ebenso freiwillig.
const playersToc = path.join(base, 'MetaCodex_Players', 'MetaCodex_Players.toc');
lua.lua_pushstring(L, to_luastring(
  fs.existsSync(playersToc) ? fs.readFileSync(playersToc, 'utf8') : ''));
lua.lua_setglobal(L, to_luastring('PLAYERS_TOC'));

// Doppelte Sprachschluessel finden, bevor der Lua-Teil laeuft.
//
// Lua nimmt bei zwei gleichen Schluesseln in einer Tabelle den letzten.
// Ein zweites Mal vergebener Text ueberschreibt darum still einen
// anderen, und geladen ist davon nichts mehr zu sehen - der Reiter
// zeigte "%d von %d", wo "knapp" stehen sollte. Hier, an der Datei, ist
// es noch zu sehen.
const dupes = [];
for (const name of ["enUS", "deDE"]) {
  const localeFile = path.join(base, "Locales", name + ".lua");
  if (!fs.existsSync(localeFile)) continue;
  const seen = new Set();
  const text = fs.readFileSync(localeFile, "utf8");
  for (const line of text.split(String.fromCharCode(10))) {
    // Auch Kleinbuchstaben.
    //
    // Das Muster liess nur Grossbuchstaben zu, und damit fielen genau
    // die Schluessel durch, die einen Abschnitt benennen:
    // SECTION_folio, SECTION_enchants, SECTION_talents. Beide waren
    // doppelt vergeben, seit Monaten, und die Pruefung sah es nicht -
    // im deutschen Fenster stand deshalb "Omnium Folio" statt
    // "Omnium-Foliant".
    const key = /^\s*\["([A-Za-z0-9_]+)"\]\s*=/.exec(line);
    if (!key) continue;
    if (seen.has(key[1])) dupes.push(name + ": " + key[1]);
    seen.add(key[1]);
  }
}
if (dupes.length) {
  console.error("  FAIL kein Sprachschluessel doppelt  -> " + dupes.join(", "));
  process.exit(1);
}
console.log("  ok   kein Sprachschluessel doppelt");

// Und ein Schluessel, den der Code BENUTZT, den es aber nicht gibt.
//
// L[] gibt dann nil zurueck, und die naechste Zeile ruft :format()
// darauf: "attempt to index a nil value" - mitten im Aufbau des
// Fensters, und das Fenster bleibt leer. Hier kostet derselbe
// Tippfehler eine Zeile Ausgabe.
//
// Nur woertliche Schluessel, keine zusammengesetzten: L["SECTION_" ..
// key] laesst sich von aussen nicht pruefen, und ein Fehler darin
// faellt im Spiel sofort auf, weil der ganze Reiter fehlt.
const defined = new Set();
for (const line of fs.readFileSync(path.join(base, "Locales", "enUS.lua"), "utf8")
    .split(String.fromCharCode(10))) {
  // Nicht am Zeilenanfang verankert: ein Schluessel darf einzeilig
  // stehen - ns.RegisterLocale("enUS", { ["ILVL"] = "..." }) -, und
  // verankert fiel genau der durch. Die Pruefung meldete ihn als
  // fehlend, obwohl er seit Monaten im Fenster steht.
  for (const m of line.matchAll(/\["([A-Za-z0-9_]+)"\]\s*=/g)) defined.add(m[1]);
}
const unknown = new Set();
for (const dir of ["Core", "Locales"]) {
  for (const name of fs.readdirSync(path.join(base, dir))) {
    if (!name.endsWith(".lua")) continue;
    const text = fs.readFileSync(path.join(base, dir, name), "utf8");
    for (const line of text.split(String.fromCharCode(10))) {
      // Kommentarzeilen nicht: dort steht L["Schluessel"] als Beispiel.
      if (/^\s*--/.test(line)) continue;
      for (const m of line.matchAll(/\bL\["([A-Za-z0-9_]+)"\]/g)) {
        if (!defined.has(m[1])) unknown.add(name + ": " + m[1]);
      }
    }
  }
}
if (unknown.size) {
  console.error("  FAIL jeder benutzte Sprachschluessel ist definiert  -> "
    + [...unknown].join(", "));
  process.exit(1);
}
console.log("  ok   jeder benutzte Sprachschluessel ist definiert");

// Sprachstand pruefen: das Spiel laeuft auf Lua 5.1.
//
// Fengari kann 5.3, und genau daran ist es gescheitert: ein "goto
// continue" lief hier gruen durch und liess im Spiel die ganze Datei
// nicht laden - das Addon war still tot, ohne eine Fehlermeldung, die
// jemand gesucht haette. Was 5.1 nicht kennt, faellt hier auf.
const VERBOTEN = [
  // Nur das, was wirklich bricht und sich nicht mit Zeichenketten
  // verwechseln laesst. Eine Adresse enthaelt zwei Schraegstriche, und
  // ein Pruefer, der darueber klagt, wird nach dem dritten Mal
  // abgeschaltet - dann prueft er gar nichts mehr.
  { name: "goto", re: /(^|[^\w])goto\s+[A-Za-z_]/, hinweis: "gibt es erst ab Lua 5.2" },
  { name: "Sprungmarke", re: /::[A-Za-z_][A-Za-z0-9_]*::/, hinweis: "gibt es erst ab Lua 5.2" },
];
{
  const dirs = ['Core', 'Locales', 'MetaCodex_Data', 'MetaCodex_Dungeons', 'MetaCodex_Players'];
  const klagen = [];
  for (const dir of dirs) {
    const voll = path.join(base, dir);
    if (!fs.existsSync(voll)) continue;
    for (const name of fs.readdirSync(voll)) {
      if (!name.endsWith('.lua')) continue;
      const text = fs.readFileSync(path.join(voll, name), 'utf8');
      const zeilen = text.split(String.fromCharCode(10));
      for (let i = 0; i < zeilen.length; i += 1) {
        const zeile = zeilen[i];
        // Kommentare zaehlen nicht: dort darf stehen, warum etwas fehlt.
        const ohneKommentar = zeile.replace(/--.*$/, '');
        for (const v of VERBOTEN) {
          if (v.re.test(ohneKommentar)) {
            klagen.push(dir + '/' + name + ':' + (i + 1) + ' ' + v.name + ' - ' + v.hinweis);
          }
        }
      }
    }
  }
  if (klagen.length) {
    console.error('  FAIL nur Lua 5.1, wie im Spiel');
    for (const k of klagen.slice(0, 10)) console.error('       ' + k);
    process.exit(1);
  }
  console.log('  ok   nur Lua 5.1, wie im Spiel');
}

// 200 LOKALE VARIABLEN JE FUNKTION - und die Hauptebene einer Datei
// ist eine.
//
// Dieselbe Art Klippe wie die 60 Upvalues: beim Ueberschreiten laedt
// die Datei im Spiel gar nicht, ohne Fehlermeldung, die jemand suchen
// wuerde - das Addon ist still weg. Fengari ist Lua 5.3 und laesst
// 200 Upvalues wie 200 Locals grosszuegiger durch, merkt es also nie.
//
// Gezaehlt wird nur, was auf Spaltennull steht: tiefer eingerueckte
// Locals gehoeren einer inneren Funktion und zaehlen dort.
{
  const warnAb = 185;
  const grenze = 200;
  const klagen = [];
  for (const dir of ['Core', 'Locales']) {
    const voll = path.join(base, dir);
    if (!fs.existsSync(voll)) continue;
    for (const name of fs.readdirSync(voll)) {
      if (!name.endsWith('.lua')) continue;
      const text = fs.readFileSync(path.join(voll, name), 'utf8');
      let n = 0;
      for (const zeile of text.split(String.fromCharCode(10))) {
        if (!/^local[\s]/.test(zeile)) continue;
        if (/^local function/.test(zeile)) { n += 1; continue; }
        // 'local a, b, c = ...' sind drei.
        const namen = zeile.replace(/^local[\s]+/, '').split('=')[0];
        n += namen.split(',').length;
      }
      if (n >= warnAb) klagen.push(dir + '/' + name + ': ' + n + ' von ' + grenze);
    }
  }
  if (klagen.length) {
    console.error('  FAIL unter der 200-Locals-Grenze von Lua 5.1');
    for (const k of klagen) console.error('       ' + k);
    process.exit(1);
  }
  console.log('  ok   unter der 200-Locals-Grenze von Lua 5.1');
}

// select(n, X and Y()) HOLT NICHTS AB.
//
// Ein Funktionsaufruf wird nur dann auf alle seine Rueckgaben
// ausgepackt, wenn er allein am Ende der Argumentliste steht. Schreibt
// jemand "select(3, UnitClass and UnitClass('player'))", schneidet das
// and auf einen Wert - und select findet kein drittes. Kein Fehler,
// kein Absturz: die Zeile tut einfach nichts.
//
// Dreimal passiert, dreimal erst im Spiel aufgefallen. Geprueft wird
// nur das Innere der Klammern von select, damit "select(...) and x" -
// was richtig ist - nicht mitgefangen wird.
{
  const klagen = [];
  for (const dir of ['Core', 'Tests']) {
    const voll = path.join(base, dir);
    if (!fs.existsSync(voll)) continue;
    for (const name of fs.readdirSync(voll)) {
      if (!name.endsWith('.lua')) continue;
      const text = fs.readFileSync(path.join(voll, name), 'utf8');
      const zeilen = text.split(String.fromCharCode(10));
      for (let i = 0; i < zeilen.length; i += 1) {
        const zeile = zeilen[i].replace(/--.*$/, '');
        let at = zeile.indexOf('select(');
        while (at >= 0) {
          // Bis zur passenden schliessenden Klammer.
          let tiefe = 0, ende = -1;
          for (let k = at + 'select'.length; k < zeile.length; k += 1) {
            if (zeile[k] === '(') tiefe += 1;
            else if (zeile[k] === ')') { tiefe -= 1; if (tiefe === 0) { ende = k; break; } }
          }
          if (ende < 0) break;
          const drin = zeile.slice(at + 'select('.length, ende);
          if (drin.indexOf(' and ') >= 0) {
            klagen.push(dir + '/' + name + ':' + (i + 1) + '  ' + zeile.trim());
          }
          at = zeile.indexOf('select(', ende);
        }
      }
    }
  }
  if (klagen.length) {
    console.error('  FAIL select(n, X and Y()) holt nichts ab');
    for (const k of klagen) console.error('       ' + k);
    process.exit(1);
  }
  console.log('  ok   kein select ueber einem abgeschnittenen Aufruf');
}

const code = fs.readFileSync(file, 'utf8');
if (lauxlib.luaL_dostring(L, to_luastring(code)) !== lua.LUA_OK) {
  console.error('LUA-FEHLER: ' + lua.lua_tojsstring(L, -1));
  process.exit(1);
}
