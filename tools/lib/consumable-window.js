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

module.exports = { countsForThisFight, PER_FIGHT, PRE_PULL };
