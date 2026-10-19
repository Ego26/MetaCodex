// Die Regeln hinter dem Abschnitt "Rassen" (19. Oktober).
//
// Zwei Fragen, zwei Quellen, und sie werden nicht vermischt:
//
//   GESPIELT - was die gemessenen Spieler einer Spec spielen. Aus den
//   raider.io-Profilen, die ohnehin abgerufen werden. Ein Spieler, der
//   bei raider.io UND bei murlok steht, zaehlt einmal: erkannt an seiner
//   Profiladresse.
//
//   SIMULIERT - was eine Rasse an Schaden bringt. Von bloodmallet.com,
//   SimulationCraft. Gezeigt als Abstand zur schwaechsten Rasse, denn
//   die absoluten Zahlen liegen so dicht beieinander, dass jede Grafik
//   gleich lange Balken zeigt.

const { share } = require('./share');

// Unter so vielen Spielern ist ein Anteil eine Behauptung ueber wenige.
// Dieselbe Grenze wie bei "auch getragen von".
const MIN_SAMPLE = 15;

// Die Kampfarten von bloodmallet und wie das Addon sie nennt: Ziele.
const FIGHTS = { castingpatchwerk: 1, castingpatchwerk3: 3, castingpatchwerk5: 5 };

/**
 * Wer welche Rasse spielt, ohne Doppelte.
 *
 * @param {Array<{key: string, race: string}>} players  key = Profiladresse
 * @returns {Map<string, number>}  Rassenname -> Spieler
 */
function tallyRaces(players) {
  const seen = new Map();
  for (const p of players || []) {
    if (!p || !p.key || !p.race) continue;
    // "https://raider.io/characters/eu/x/y" und "/characters/eu/x/y" sind
    // dieselbe Person: die Adresse ohne Seite ist der Schluessel.
    const key = String(p.key).toLowerCase().replace(/^https?:\/\/[^/]+/, '');
    if (!seen.has(key)) seen.set(key, p.race);
  }
  const counts = new Map();
  for (const race of seen.values()) counts.set(race, (counts.get(race) || 0) + 1);
  return counts;
}

/**
 * Anteile je Rasse - oder nichts, wenn die Stichprobe zu klein ist.
 *
 * @param {Map<string, number>} counts
 * @param {Object<string, {id: number}>} index  englischer Name -> Rasse
 * @returns {{n: number, list: Array<{id: number, pct: number}>} | null}
 */
function raceShares(counts, index) {
  let n = 0;
  for (const c of counts.values()) n += c;
  if (n < MIN_SAMPLE) return null;
  const perId = new Map();
  for (const [name, c] of counts) {
    const hit = index[name];
    if (!hit) continue;
    perId.set(hit.id, (perId.get(hit.id) || 0) + c);
  }
  const list = [...perId.entries()]
    .map(([id, c]) => ({ id, pct: share(c, n) }))
    .filter((r) => r.pct > 0)
    .sort((a, b) => b.pct - a.pct || a.id - b.id);
  return list.length ? { n, list } : null;
}

/**
 * Ein Rassenname von bloodmallet, zerlegt: die Zandalari gibt es je Loa.
 *
 * @returns {{id: number, loa: string|null} | null}
 */
function simRace(name, index) {
  if (index[name]) return { id: index[name].id, loa: null };
  for (const base of Object.keys(index)) {
    if (name.startsWith(base + ' ')) return { id: index[base].id, loa: name.slice(base.length + 1) };
  }
  return null;
}

/**
 * Die Simulation einer Spec: je Kampfart der Abstand zur schwaechsten
 * Rasse in Prozent, auf ein Zehntel. Genauer ist sie nicht - bloodmallet
 * rechnet mit 0,1 % Zielfehler.
 *
 * @param {Object} fights  bloodmallet-races.json -> specs[spec]
 * @param {Object} index
 * @returns {{ts: string|null, byTargets: Object<number, Array<{id, loa, rel}>>} | null}
 */
function raceSims(fights, index) {
  const byTargets = {};
  let ts = null;
  for (const [fight, targets] of Object.entries(FIGHTS)) {
    const sim = fights && fights[fight];
    if (!sim || !sim.data) continue;
    const rows = [];
    for (const [name, dps] of Object.entries(sim.data)) {
      const race = simRace(name, index);
      if (race && Number(dps) > 0) rows.push({ ...race, dps: Number(dps) });
    }
    if (!rows.length) continue;
    const low = Math.min(...rows.map((r) => r.dps));
    byTargets[targets] = rows
      .map((r) => ({ id: r.id, loa: r.loa, rel: Math.round((r.dps / low - 1) * 1000) / 10 }))
      .sort((a, b) => b.rel - a.rel || a.id - b.id);
    if (!ts || (sim.ts && sim.ts > ts)) ts = sim.ts || ts;
  }
  return Object.keys(byTargets).length ? { ts, byTargets } : null;
}

// Die Toepfe: welche Aktivitaeten fuer die Rassenfrage zusammengehoeren.
// M+ braucht keinen - die Laufliste bringt tausende Spieler mit.
const POOLS = {
  '@raid': (mode) => /^raid/.test(mode) && !mode.includes('/'),
  '@pvp': (mode) => ['2v2', '3v3', 'rbg', 'solo', 'blitz'].includes(mode),
};

/**
 * Die Spieler je Topf: alle Aktivitaeten einer Familie, zusammengelegt.
 * Doppelte faellt tallyRaces heraus.
 *
 * @param {Object<string, Object<string, Array>>} byMode  Modus -> Spec -> Spieler
 * @returns {Object<string, Object<string, Array>>}  Topf -> Spec -> Spieler
 */
function pooled(byMode) {
  const out = {};
  for (const [pool, belongs] of Object.entries(POOLS)) {
    for (const [mode, specs] of Object.entries(byMode || {})) {
      if (!belongs(mode)) continue;
      for (const [spec, players] of Object.entries(specs)) {
        const bySpec = out[pool] || (out[pool] = {});
        (bySpec[spec] = bySpec[spec] || []).push(...players);
      }
    }
  }
  return out;
}

module.exports = { tallyRaces, raceShares, raceSims, simRace, pooled, MIN_SAMPLE, FIGHTS, POOLS };
