// Zaehlt diese Wirkung fuer DIESEN Lauf?
//
// Die Frage sieht klein aus und hat einen Abend gekostet. Warcraft Logs
// gibt die Wirkungen eines ganzen BERICHTS zurueck, und eine Gruppe, die
// fuenf Dungeons am Stueck loggt, hat sie alle in einem Bericht. Wer
// nicht nach der Zeit fragt, schreibt den Trank aus Lauf drei auch den
// Laeufen eins, zwei, vier und fuenf gut - und ein Trank, den einer
// einmal nimmt, steht am Ende so hoch wie einer, den er immer nimmt.
// Bei Daemonologie in hohen Keys ergab das "Fluessiger Ruhm 57 %", wo
// eine breitere Stichprobe 21 % misst.
//
// Unterschieden wird nach der Art, weil die Sachen zu verschiedenen
// Zeiten benutzt werden:
//
//   Kampf- und Heiltraenke gehoeren in den Lauf. Sie zaehlen nur, wenn
//   sie in seinem Zeitfenster getrunken wurden - mit einer halben
//   Minute Vorlauf, denn der Praetrank kommt Sekunden VOR dem Pull und
//   ist gerade deshalb einer.
//
//   Speise, Fläschchen, Runen und Oele nimmt man davor, oft lange davor
//   und einmal fuer den ganzen Abend. Sie zaehlen aus dem ganzen
//   Bericht - sonst sieht jeder zweite Lauf ungespeist aus, waehrend
//   die Wirkung sichtbar dasteht.
//
// Im Zweifel wird gezaehlt: fehlt der Zeitstempel oder die Zeit des
// Laufs, ist "nicht wissen" kein Grund, eine echte Messung wegzuwerfen.

/** Arten, die in den Lauf gehoeren und nicht davor. */
const PER_FIGHT = new Set(['potion', 'heal']);

/** Vorlauf fuer den Praetrank, in Millisekunden. */
const PRE_PULL = 30000;

/**
 * @param {string|undefined} kind Art des Verbrauchsguts aus dem Katalog
 * @param {number} when Zeitstempel der Wirkung
 * @param {number|null} fightStart Beginn des Laufs, null wenn unbekannt
 * @param {number|null} fightEnd Ende des Laufs
 * @returns {boolean}
 */
function countsForThisFight(kind, when, fightStart, fightEnd) {
  if (!PER_FIGHT.has(kind)) return true;
  if (fightStart === null || fightStart === undefined) return true;
  if (fightEnd === null || fightEnd === undefined) return true;
  if (!Number.isFinite(Number(when))) return true;
  return Number(when) >= Number(fightStart) - PRE_PULL
    && Number(when) <= Number(fightEnd);
}

// Wirkte beim Pull ein Trank, der Zweitwerte gibt?
//
// Eine zweite Frage, fuer die Zielwerte. Liquid Luster und Potion of
// Recklessness geben Zweitwerte, und wer sie vor dem Pull trinkt, hat sie
// in den Werten beim Pull - aber nicht in der Liste der Auren, die das
// Log dazu schickt. Am 31. Oktober stand so bei rund jedem Dritten in M+
// 420 Vielseitigkeit mehr als in seinem Arsenal, bei gleicher
// Ausruestung bis aufs letzte Teil.
//
// Gefragt wird der BUFF, nicht der Schluck. In M+ beginnt der Kampf mit
// dem Schluesselstein, getrunken wird davor, und den Schluck fand das Log
// unter dieser Nummer nicht - in zwei Laeufen, in denen jeder Spieler den
// Buff beim Pull trug, kein einziger. Der Buff dagegen steht da: sein
// erstes Ereignis im Kampf verraet, ob er schon vorher lief.
//
//   Ablaufen, Erneuern, ein Stapel mehr oder weniger als ERSTES
//   Ereignis: dann lief er beim Pull schon.
//   Ein frisches Auflegen: nur, wenn es spaetestens eine Sekunde nach
//   dem Pull kommt - Pull und Schluck stehen oft im selben Augenblick.
//
// Ist der Beginn des Kampfes unbekannt, laesst sich ein Vortrank nicht
// ausschliessen - dann zaehlt jeder, der den Buff ueberhaupt hatte.
const AT_PULL = 1000;
const FRESH = new Set(['applybuff', 'applydebuff']);

/**
 * @param {Array<{type: string, timestamp: number, targetID: number}>} events
 *   Buff-Ereignisse der Trank-Auren im Kampf, zeitlich geordnet
 * @param {number|null} fightStart Beginn des Kampfes, null wenn unbekannt
 * @returns {Set<number>} wer den Buff beim Pull trug
 */
function activeAtPull(events, fightStart) {
  const first = new Map();
  for (const e of events || []) {
    const who = Number(e.targetID);
    if (!first.has(who)) first.set(who, e);
  }
  const out = new Set();
  for (const [who, e] of first) {
    if (fightStart === null || fightStart === undefined) { out.add(who); continue; }
    if (!FRESH.has(e.type) || Number(e.timestamp) <= Number(fightStart) + AT_PULL) out.add(who);
  }
  return out;
}

module.exports = { countsForThisFight, PER_FIGHT, PRE_PULL, activeAtPull, AT_PULL };