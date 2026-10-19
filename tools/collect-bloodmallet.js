#!/usr/bin/env node
// Rassen-Simulationen von bloodmallet.com.
//
// Fuer den Abschnitt "Rassen" (19. Oktober): was eine Rasse an Schaden
// bringt, laesst sich nicht aus den Ranglisten ablesen - dort sind die
// Unterschiede zwischen den Spielern viel groesser als zwischen den
// Rassen. Ehrlich beantwortet das nur eine Simulation: derselbe
// Charakter, nur eine andere Rasse. bloodmallet rechnet genau das mit
// SimulationCraft (60.000 Durchlaeufe) und gibt es frei heraus - "All
// data is free to use for everyone", mit der Bitte um einen Verweis.
// Der steht im Addon an jeder Zahl.
//
// Simuliert werden Schadens-Speccs und Tanks; Heiler und Verstaerkung
// nicht - fuer sie antwortet die Seite "No standard chart", und dann
// steht im Addon eben keine Zahl.
//
// Aufruf:  node tools/collect-bloodmallet.js .
// Schreibt: tools/data/bloodmallet-races.json

'use strict';
const fs = require('fs');
const path = require('path');
const https = require('https');
const zlib = require('zlib');
const { worthRetrying, waitSeconds } = require('./lib/http-retry');

const BASE = path.resolve(process.argv[2] || '.');
const OUT = path.join(BASE, 'tools', 'data', 'bloodmallet-races.json');

// Die Kampfarten. M+ nimmt alle vier, der Raid die ersten beiden - das
// entscheidet das Addon; hier wird geholt, was es gibt.
const FIGHTS = ['castingpatchwerk', 'castingpatchwerk3', 'castingpatchwerk5', 'hecticaddcleave'];
const DELAY = 400;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function get(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, {
      headers: {
        'User-Agent': 'MetaCodex (github.com/Ego26/MetaCodex)',
        'Accept-Encoding': 'gzip',
      },
      timeout: 30000,
    }, (res) => {
      const enc = res.headers['content-encoding'];
      const stream = enc === 'gzip' ? res.pipe(zlib.createGunzip()) : res;
      let body = '';
      stream.on('data', (c) => (body += c));
      stream.on('end', () => {
        if (res.statusCode !== 200) {
          const err = new Error('HTTP ' + res.statusCode + ': ' + body.slice(0, 120));
          err.statusCode = res.statusCode;
          return reject(err);
        }
        try { resolve(JSON.parse(body)); } catch (e) { reject(e); }
      });
      stream.on('error', reject);
    });
    req.on('timeout', () => req.destroy(new Error('Zeitueberschreitung')));
    req.on('error', reject);
  });
}

/** Mit der gemeinsamen Geduld: 5xx und Netzfehler noch einmal, 4xx nie. */
async function patient(url) {
  for (let attempt = 0; ; attempt += 1) {
    try {
      return await get(url);
    } catch (err) {
      if (!worthRetrying(err) || attempt >= 3) throw err;
      await sleep(waitSeconds(attempt) * 1000);
    }
  }
}

/** Die Speccs aus dem Katalog: Nummer, Klasse, Spec, Rolle. */
function readSpecs() {
  const file = path.join(BASE, 'MetaCodex_Data', 'Catalog.lua');
  const text = fs.readFileSync(file, 'utf8');
  const out = [];
  const re = /\[(\d+)\] = \{ cls = "([^"]+)", spec = "([^"]+)", stat = "[^"]*", role = "([^"]+)"/g;
  let m;
  while ((m = re.exec(text))) {
    out.push({ id: Number(m[1]), cls: m[2], spec: m[3], role: m[4] });
  }
  return out;
}

(async () => {
  const specs = readSpecs().filter((s) => s.role !== 'healer');
  console.log('Speccs ohne Heiler: ' + specs.length);
  const out = {};
  let ok = 0, none = 0, failed = 0;
  for (const s of specs) {
    // bloodmallet schreibt mit Unterstrich: death_knight, beast_mastery.
    const cls = s.cls.replace(/-/g, '_');
    const spec = s.spec.replace(/-/g, '_');
    for (const fight of FIGHTS) {
      const url = `https://bloodmallet.com/chart/get/races/${fight}/${cls}/${spec}`;
      let data;
      try {
        data = await patient(url);
      } catch (err) {
        failed += 1;
        process.stdout.write('!');
        await sleep(DELAY);
        continue;
      }
      await sleep(DELAY);
      if (!data || data.status === 'error' || !data.data) {
        none += 1;
        process.stdout.write('-');
        continue;
      }
      const meta = data.metadata || {};
      (out[s.id] = out[s.id] || {})[fight] = {
        ts: data.timestamp || meta.timestamp || null,
        simc: meta.SimulationCraft || (data.simc_settings && data.simc_settings.simc_hash) || null,
        data: data.data,
      };
      ok += 1;
      process.stdout.write('+');
    }
  }
  console.log(`\nSims: ${ok}, ohne Chart: ${none}, Fehler: ${failed}`);
  // Ohne eine einzige Simulation wird nichts geschrieben - aber die Nacht
  // laeuft weiter: die Rassen stehen dann eben ohne Simulation da, und
  // eine Stoerung bei bloodmallet darf keine Raiddaten kosten.
  if (!ok) {
    console.log('Keine einzige Simulation - nichts geschrieben, die Nacht laeuft weiter.');
    return;
  }
  const stamp = Number(new Date().toISOString().slice(0, 10).split('-').join(''));
  fs.writeFileSync(OUT, JSON.stringify({ source: 'bloodmallet.com', builtOn: stamp, specs: out }, null, 1), 'utf8');
  console.log('geschrieben: ' + path.relative(BASE, OUT));
})();
