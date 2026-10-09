// Was sich aus einer Zauberfolge wirklich ablesen laesst.
//
// Eine Rotation ist eine Prioritaetenliste, und die steht in keinem Log:
// sie ist die Deutung eines Menschen. Was im Log steht, sind Zeitpunkte
// und Zauber-IDs. Daraus lassen sich zwei Dinge zaehlen, und nur diese
// zwei behauptet das Addon:
//
//   DER OPENER - was in den ersten Sekunden gedrueckt wird, Stelle fuer
//   Stelle. "Der erste Zauber war bei 78 % X."
//
//   DIE VERTEILUNG - wie oft eine Faehigkeit im Kampf faellt, als Wuerfe
//   je Minute. Das sagt, was die Rotation traegt, ohne zu behaupten, in
//   welcher Reihenfolge man es drueckt.
//
// Je Stelle gezaehlt, nicht als ganze Folge: sechs Zauber ergeben
// hunderte verschiedener Folgen, und am Ende traegt die haeufigste drei
// Prozent. Eine Zahl, die niemandem hilft. Je Stelle bleibt die
// Stichprobe ganz, und wo die Besten sich uneinig sind, sieht man es an
// der Zahl statt an ihrem Fehlen.

/**
 * Eine Zauberfolge eines Spielers.
 * @typedef {{ spell: number, t: number }} Wurf  t in Millisekunden
 */

/**
 * Die ersten Wuerfe je Stelle, ueber alle Spieler gezaehlt.
 *
 * @param {Wurf[][]} proSpieler  je Spieler seine Wuerfe, aufsteigend nach t
 * @param {{ stellen?: number, fenster?: number }} [opt]
 *   stellen: wie viele Stellen gezaehlt werden (Vorgabe 5)
 *   fenster: nur Wuerfe bis zu dieser Millisekunde nach dem ersten des
 *            Spielers zaehlen (Vorgabe 15000). Wer nach zwanzig Sekunden
 *            noch etwas drueckt, ist nicht mehr im Opener.
 * @returns {{ stelle: number, spieler: number, zauber: { spell: number, n: number, pct: number }[] }[]}
 */
function opener(proSpieler, opt) {
  const stellen = (opt && opt.stellen) || 5;
  const fenster = (opt && opt.fenster !== undefined) ? opt.fenster : 15000;

  const zaehler = [];
  for (let i = 0; i < stellen; i += 1) zaehler.push(new Map());
  const spielerJeStelle = new Array(stellen).fill(0);

  for (const wuerfe of proSpieler) {
    if (!wuerfe || wuerfe.length === 0) continue;
    const start = wuerfe[0].t;
    let stelle = 0;
    for (const w of wuerfe) {
      if (stelle >= stellen) break;
      if (fenster > 0 && w.t - start > fenster) break;
      zaehler[stelle].set(w.spell, (zaehler[stelle].get(w.spell) || 0) + 1);
      spielerJeStelle[stelle] += 1;
      stelle += 1;
    }
  }

  const out = [];
  for (let i = 0; i < stellen; i += 1) {
    const n = spielerJeStelle[i];
    if (n === 0) continue;
    const zauber = [...zaehler[i].entries()]
      .map(([spell, k]) => ({ spell, n: k, pct: anteil(k, n) }))
      .sort((a, b) => b.n - a.n || a.spell - b.spell);
    out.push({ stelle: i + 1, spieler: n, zauber });
  }
  return out;
}

/**
 * Wuerfe je Minute, je Faehigkeit.
 *
 * Der MEDIAN ueber die Spieler, nicht der Mittelwert: ein einzelner
 * Kampf, der dreimal so lang lief wie die anderen, zoege den Schnitt
 * sonst mit sich. Dieselbe Entscheidung wie bei den Zielwerten.
 *
 * @param {{ wuerfe: Wurf[], dauer: number }[]} proSpieler  dauer in ms
 * @returns {{ spell: number, proMinute: number, spieler: number, pct: number }[]}
 */
function rate(proSpieler) {
  // Je Spieler und Faehigkeit: wie oft je Minute.
  const werte = new Map();   // spell -> number[]
  let gesamtWuerfe = 0;
  for (const s of proSpieler) {
    if (!s || !s.wuerfe || !s.dauer || s.dauer <= 0) continue;
    const minuten = s.dauer / 60000;
    const je = new Map();
    for (const w of s.wuerfe) {
      je.set(w.spell, (je.get(w.spell) || 0) + 1);
      gesamtWuerfe += 1;
    }
    for (const [spell, n] of je) {
      if (!werte.has(spell)) werte.set(spell, []);
      werte.get(spell).push(n / minuten);
    }
  }

  const out = [];
  for (const [spell, liste] of werte) {
    out.push({
      spell,
      proMinute: Math.round(median(liste) * 10) / 10,
      spieler: liste.length,
      pct: 0,
    });
  }
  // Der Anteil an allen Wuerfen - damit man sieht, was die Rotation
  // traegt und was Beiwerk ist.
  const summe = out.reduce((a, e) => a + e.proMinute, 0);
  for (const e of out) e.pct = summe > 0 ? anteil(e.proMinute, summe) : 0;
  out.sort((a, b) => b.proMinute - a.proMinute || a.spell - b.spell);
  return out;
}

/**
 * Ist das ein Kampf mit mehreren Zielen?
 *
 * Gemessen am Schaden, der NICHT auf das groesste Ziel geht. Bei
 * Sszorak sind das 0 %, bei den Lost Explorers 64 % - das Feld trennt
 * sich also von selbst, und die Grenze muss nicht geraten werden.
 *
 * Die 45 % liegen in der Luecke zwischen beiden Gruppen: darunter liegen
 * 0, 28, 35, 40, 40 - darueber 54, 55, 64, 73. Verschiebt eine Saison
 * das Feld, verschiebt sich die Grenze mit, denn sie wird aus den
 * gemessenen Zahlen neu bestimmt und steht nicht fest im Addon.
 *
 * @param {{ name: string, total: number }[]} ziele  Schaden je Ziel
 * @returns {{ anteilNeben: number, multi: boolean|null }}
 *   multi ist null, wenn gar kein Schaden gemessen wurde - dann wird
 *   nichts behauptet.
 */
const MULTI_AB = 0.45;

function spread(ziele) {
  let gesamt = 0, groesstes = 0;
  for (const z of ziele || []) {
    const w = Number(z.total) || 0;
    gesamt += w;
    if (w > groesstes) groesstes = w;
  }
  if (gesamt <= 0) return { anteilNeben: 0, multi: null };
  const neben = 1 - groesstes / gesamt;
  return { anteilNeben: Math.round(neben * 1000) / 1000, multi: neben >= MULTI_AB };
}

// --- Kleinkram ------------------------------------------------------

/**
 * Prozent, ohne zu einer Behauptung zu runden.
 *
 * Dieselbe Regel wie ueberall im Projekt: 100 steht nur da, wenn es
 * wirklich alle sind, 0 nur, wenn es wirklich keiner ist.
 */
function anteil(teil, ganzes) {
  if (!ganzes) return 0;
  const p = (100 * teil) / ganzes;
  if (p >= 100) return teil >= ganzes ? 100 : 99;
  if (p <= 0) return teil > 0 ? 1 : 0;
  const gerundet = Math.round(p);
  if (gerundet >= 100) return 99;
  if (gerundet <= 0) return 1;
  return gerundet;
}

function median(liste) {
  const s = [...liste].sort((a, b) => a - b);
  if (s.length === 0) return 0;
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

module.exports = { opener, rate, spread, MULTI_AB, anteil, median };
