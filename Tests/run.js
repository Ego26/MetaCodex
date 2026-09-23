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
    const key = /^\s*\["([A-Z0-9_]+)"\]\s*=/.exec(line);
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

const code = fs.readFileSync(file, 'utf8');
if (lauxlib.luaL_dostring(L, to_luastring(code)) !== lua.LUA_OK) {
  console.error('LUA-FEHLER: ' + lua.lua_tojsstring(L, -1));
  process.exit(1);
}
