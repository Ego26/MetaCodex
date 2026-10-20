// Die Regeln hinter dem Abschnitt "Rotation" (tools/lib/apl.js).
//
// Was der Build sicher weiss, faellt aus der Bedingung heraus; was nicht,
// bleibt stehen oder wird ehrlich zu "unter bestimmten Bedingungen".
const apl = require('../lib/apl');

let failed = 0;
function check(what, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`
    + (ok ? '' : `\n          bekommen: ${JSON.stringify(got)}`
      + `\n          erwartet: ${JSON.stringify(want)}`));
}

const IDS = { lava_burst: 1, master_of_the_elements: 2, tempest: 3, lightning_bolt: 4, lightning_shield: 5,
  stormkeeper: 6, earthquake: 7, chain_lightning: 8, flame_shock: 9, ascendance: 10 };
const TAKEN = new Set(['master_of_the_elements', 'lava_burst', 'stormkeeper', 'earthquake']);
const TREE = new Set(['master_of_the_elements', 'tempest', 'lava_burst', 'stormkeeper', 'earthquake']);
const ctx = (targets) => ({
  talent: (k) => TAKEN.has(k), isTalentSpell: (k) => TREE.has(k), hero: (k) => k === 'farseer',
  setBonus: () => false, targets, variable: () => null,
});
const resolve = {
  spell: (k) => IDS[k] || null, actionSpell: (k) => IDS[k] || null,
  isTalentSpell: (k) => TREE.has(k), talent: (k) => TAKEN.has(k), replaced: (id) => id === 99,
};
const tab = (text, targets, start = 'default') => apl.buildTab(apl.parseApl(text), start, ctx(targets), resolve).lines;

// Ein Talent, das der Build nicht nimmt: die Zeile gibt es nicht.
check('Zeile fuer ein fehlendes Talent faellt weg',
  tab('actions=tempest\nactions+=/lightning_bolt', [1, 1]).map((l) => l.s), [4]);
// Ein genommenes Talent in der Bedingung ist wahr und verschwindet.
check('genommenes Talent faellt aus der Bedingung',
  tab('actions=lava_burst,if=talent.master_of_the_elements&buff.master_of_the_elements.down', [1, 1])[0].c,
  [['down', 2]]);
// Der Buff eines fehlenden Talents kommt nie: "wenn Tempest aktiv" ist falsch.
check('Buff eines fehlenden Talents ist nie aktiv',
  tab('actions=lightning_bolt,if=buff.tempest.up\nactions+=/chain_lightning', [1, 1]).map((l) => l.s), [8]);
// Mit Bereichen: (0 oder 1) + 1 >= 1 gilt immer.
check('Bereiche falten auch Summen',
  tab('actions=lava_burst,if=buff.stormkeeper.up+talent.earthquake>=1', [1, 1])[0].c, []);
// Zielzahl: im Einzelziel falsch, in der Flaeche offen und vorn.
check('Flaechenzeile fehlt im Einzelziel',
  tab('actions=earthquake,if=spell_targets.chain_lightning>=5\nactions+=/lightning_bolt', [1, 1]).map((l) => l.s), [4]);
check('in der Flaeche steht die Zielzahl vorn',
  tab('actions=earthquake,if=buff.stormkeeper.up&spell_targets.chain_lightning>=5', [3, 8])[0].c,
  [['tgtmin', 5], ['up', 6]]);
// run_action_list mit erfuellter Bedingung: der Rest der Liste laeuft nie.
const zweiListen = 'actions=run_action_list,name=aoe,if=active_enemies>=3\n'
  + 'actions+=/run_action_list,name=st\nactions.aoe=chain_lightning\nactions.st=lightning_bolt';
check('Einzelziel springt in die st-Liste', tab(zweiListen, [1, 1]).map((l) => l.s), [4]);
check('Flaeche springt in die aoe-Liste und hoert dort auf', tab(zweiListen, [3, 8]).map((l) => l.s), [8]);
// Ein eigener Schild "wenn nicht aktiv" gehoert vor den Kampf.
const schild = apl.buildTab(apl.parseApl('actions=lightning_shield,if=buff.lightning_shield.down\nactions+=/lightning_bolt'),
  'default', ctx([1, 1]), resolve);
check('Schild aufrechterhalten wandert nach vorn', [schild.keep, schild.lines.map((l) => l.s)], [[5], [4]]);
// Ein Cooldown "wenn sein Buff fehlt" in einer Unterliste bleibt eine Zeile.
const sk = apl.buildTab(apl.parseApl('actions=run_action_list,name=st\nactions.st=stormkeeper,if=!buff.stormkeeper.up\nactions.st+=/lightning_bolt'),
  'default', ctx([1, 1]), resolve);
check('Cooldown in der Unterliste wird nicht "aktiv halten"', [sk.keep, sk.lines.map((l) => l.s)], [[], [6, 4]]);
// Dieselbe Aktion zweimal hintereinander: gemeinsamer Teil + eins davon.
const zwei = tab('actions=lava_burst,if=buff.master_of_the_elements.down&maelstrom.deficit>15&cooldown.lava_burst.charges_fractional>1.8\n'
  + 'actions+=/lava_burst,if=buff.master_of_the_elements.down&maelstrom.deficit>15&maelstrom>83', [1, 1]);
check('zwei Zeilen werden eine', zwei.length, 1);
check('gemeinsamer Teil', zwei[0].c, [['down', 2], ['resnotcap', 'maelstrom', 15]]);
check('und eins davon', zwei[0].any, [[['charges', 1, 1.8]], [['resmin', 'maelstrom', 84]]]);
// Dieselbe Zeile weiter unten greift nie anders.
check('Wiederholung weiter unten faellt weg',
  tab('actions=chain_lightning,if=buff.stormkeeper.up\nactions+=/lightning_bolt\nactions+=/chain_lightning,if=buff.stormkeeper.up', [1, 1])
    .map((l) => l.s), [8, 4]);
// Was sich nicht sagen laesst, wird nicht geraten.
// Zwei benennbare Werte: ein Vergleich als Satz.
check('zwei Werte werden ein Vergleich',
  tab('actions=lightning_bolt,if=buff.stormkeeper.remains>cooldown.ascendance.remains', [1, 1])[0].c,
  [['cmp', ['rem', 6], 'gt', ['cd', 10]]]);
check('auch gegen den globalen Cooldown',
  tab('actions=lightning_bolt,if=cooldown.ascendance.remains>gcd.max*2', [1, 1])[0].c,
  [['cmp', ['cd', 10], 'gt', ['mul', ['gcd'], ['n', 2]]]]);
// Was sich nicht benennen laesst, wird nicht geraten.
check('Unbekanntes wird ein Merker, keine Bedingung',
  (() => { const l = tab('actions=lightning_bolt,if=evoker.shifting_buffs=1', [1, 1])[0]; return [l.c, l.more]; })(),
  [[], true]);
// Hoechstens einmal je Satz: Bekanntes bleibt, Unbekanntes wird EIN Merker,
// und ein Oder mit unbekanntem Zweig ist als Ganzes unbekannt.
check('Bekanntes bleibt, Unbekanntes einmal',
  (() => {
    const l = tab('actions=lightning_bolt,if=buff.stormkeeper.up&evoker.shifting_buffs=1'
      + '&(foo.bar|buff.ascendance.up)&(baz.qux=2)', [1, 1])[0];
    return [l.c, l.more];
  })(),
  [[['up', 6]], true]);
// Art 1: wie lange her, noch wirken, im Flug, Zahl der Ziele, Spitzentalent.
check('vor weniger als N Sek. gewirkt (Abklingzeit)',
  tab('actions=lightning_bolt,if=(cooldown.ascendance.duration-cooldown.ascendance.remains)<10', [1, 1])[0].c,
  [['ago', 10, 'lt', 10]]);
check('vor mehr als N Sek. gewirkt (letzte Nutzung)',
  tab('actions=lightning_bolt,if=(time-action.ascendance.last_used)>5', [1, 1])[0].c,
  [['ago', 10, 'gt', 5]]);
check('wirkt noch ueber N Sek.',
  tab('actions=lightning_bolt,if=action.lava_burst.execute_remains>0.5', [1, 1])[0].c, [['castleft', 1, 0.5]]);
check('im Flug',
  tab('actions=lightning_bolt,if=!action.lava_burst.in_flight', [1, 1])[0].c, [['notflying', 1]]);
check('Zauber im Flug als Wert',
  tab('actions=lightning_bolt,if=hot_streak_spells_in_flight+buff.stormkeeper.react=0', [1, 1])[0].c,
  [['cmp', ['plus', ['inflight'], ['stk', 6]], 'eq', ['n', 0]]]);
check('Spitzentalent aus dem Build',
  apl.buildTab(apl.parseApl('actions=lightning_bolt,if=apex.2\nactions+=/chain_lightning,if=!apex.3'), 'default',
    { ...ctx([1, 1]), apex: (k) => k <= 2 }, resolve).lines.map((l) => [l.s, l.c]), [[4, []], [8, []]]);
// Art 2: ein Zustand ueber den Kampf ("opener"), aus seinen Definitionen.
check('Zustand: noch nicht eingetreten',
  apl.buildTab(apl.parseApl('actions=lightning_bolt,if=variable.opener'), 'default',
    { ...ctx([1, 1]), isLatch: (n) => n === 'opener' },
    { ...resolve, latch: (n) => (n === 'opener' ? ['notyet', ['up', 10]] : null) }).lines[0].c,
  [['notyet', ['up', 10]]]);
check('Zustand verneint: schon eingetreten',
  apl.buildTab(apl.parseApl('actions=lightning_bolt,if=!variable.opener'), 'default',
    { ...ctx([1, 1]), isLatch: (n) => n === 'opener' },
    { ...resolve, latch: (n) => (n === 'opener' ? ['notyet', ['up', 10]] : null) }).lines[0].c,
  [['already', ['up', 10]]]);
// Art 3: Schmuck-Variablen ohne Schmuck aus.
check('Schmuck-Variable ohne Schmuck ist aus',
  tab('actions=lightning_bolt,if=variable.trinket_sync_slot=1|buff.stormkeeper.up', [1, 1])[0].c, [['up', 6]]);
// Zweite Runde: Spieldaten und SimC-Kurznamen.
check('Abklingzeit-Dauer aus den Spieldaten',
  apl.buildTab(apl.parseApl('actions=lightning_bolt,if=cooldown.ascendance.duration>100'), 'default',
    { ...ctx([1, 1]), cdOf: () => 180 }, resolve).lines[0].c, []);
check('maximale Stapel aus den Spieldaten',
  apl.buildTab(apl.parseApl('actions=lightning_bolt,if=buff.stormkeeper.at_max_stacks'), 'default',
    { ...ctx([1, 1]), stacksOf: () => 2 }, resolve).lines[0].c, [['stackmin', 6, 2]]);
check('nicht verstaerkte Blutung',
  tab('actions=flame_shock,if=pmultiplier<=1', [1, 1])[0].c, [['weakdot', 9]]);
check('Verstohlenheit',
  tab('actions=lightning_bolt,if=!stealthed.rogue', [1, 1])[0].c, [['notstealthed']]);
check('remains_expected ist die Restzeit',
  tab('actions=lightning_bolt,if=cooldown.ascendance.remains_expected>5', [1, 1])[0].c, [['cdover', 10, 5]]);
// Faelle durchrechnen: eine Schwelle, die an einem Buff haengt.
check('Schwelle je Fall',
  tab('actions=lightning_bolt,if=maelstrom<(buff.stormkeeper.up*50+(!buff.stormkeeper.up)*80)', [1, 1])[0].c,
  [['or', ['and', ['down', 6], ['resunder', 'maelstrom', 80]], ['and', ['up', 6], ['resunder', 'maelstrom', 50]]]]);
check('eine Zeile, die nie greift, faellt weg',
  tab('actions=lightning_bolt,if=buff.stormkeeper.up&0\nactions+=/chain_lightning', [1, 1]).map((l) => l.s), [8]);
check('Aufladungen einer Aktion sind die der Abklingzeit',
  tab('actions=lightning_bolt,if=action.lava_burst.charges>=2', [1, 1])[0].c, [['charges', 1, 2]]);
check('Wirkzeit als Wert',
  tab('actions=lightning_bolt,if=buff.stormkeeper.remains<action.lava_burst.cast_time', [1, 1])[0].c,
  [['cmp', ['rem', 6], 'lt', ['casttime', 1]]]);
check('Min/Max als Vergleich',
  tab('actions=lightning_bolt,if=(cooldown.ascendance.remains<?cooldown.stormkeeper.remains)>5', [1, 1])[0].c,
  [['cmp', ['min', ['cd', 10], ['cd', 6]], 'gt', ['n', 5]]]);
check('Waffe aus der gemessenen Ausruestung',
  apl.buildTab(apl.parseApl('actions=lightning_bolt,if=!main_hand.dagger\nactions+=/chain_lightning'), 'default',
    { ...ctx([1, 1]), weapon: () => true }, resolve).lines.map((l) => l.s), [8]);
check('Kosten aus den Spieldaten',
  apl.buildTab(apl.parseApl('actions=lightning_bolt,if=action.earthquake.cost>50'), 'default',
    { ...ctx([1, 1]), costOf: () => 60 }, resolve).lines[0].c, []);
// Schmuck ist ausgenommen: die Rotation gilt ohne Benutzen-Effekt.
check('Schmuck-Bedingungen fallen aus der Rotation',
  tab('actions=ascendance,if=trinket.1.cooldown.remains>20|buff.stormkeeper.up', [1, 1])[0].c, [['up', 6]]);
// Variablen mit Bedingung (setif) werden aufgeloest.
check('bedingte Variable wird aufgeloest',
  apl.buildTab(apl.parseApl('actions=lightning_bolt,if=variable.x'), 'default',
    { ...ctx([1, 1]), variable: (n) => (n === 'x' ? { op: '?:', c: apl.parse('talent.tempest'), a: apl.parse('0'), b: apl.parse('1') } : null) },
    resolve).lines[0].c, []);
// Verneinte Oder-Kette: nicht A und nicht B.
check('nicht (A oder B) ist nicht A und nicht B',
  tab('actions=lightning_bolt,if=!(buff.stormkeeper.up|buff.ascendance.up)', [1, 1])[0].c, [['down', 6], ['down', 10]]);
// Laufen: eine Zeile fuers Laufen gilt beim Laufen (Gunst des Geistwandlers
// fehlte, weil "movement.distance>6" im Stehen falsch ist), sonst nicht.
const lauf = apl.buildTab(apl.parseApl('actions=lightning_shield,moving=1,if=movement.distance>6\n'
  + 'actions+=/lightning_bolt,if=movement.distance>6\nactions+=/flame_shock,moving=1'), 'default', ctx([1, 1]), resolve);
check('Zeilen fuers Laufen gelten beim Laufen', lauf.moving, [5, 9]);
check('und nur dort', lauf.lines.map((l) => l.s), []);
// Kurzform auf der eigenen Zeile.
check('refreshable meint den eigenen DoT',
  tab('actions=flame_shock,if=refreshable', [1, 1])[0].c, [['refresh', 9]]);
// Ein ersetzter Zauber steht nie da.
check('ersetzter Zauber faellt weg',
  apl.buildTab(apl.parseApl('actions=natures_swiftness\nactions+=/lightning_bolt'), 'default', ctx([1, 1]),
    { ...resolve, actionSpell: (k) => (k === 'natures_swiftness' ? 99 : IDS[k]) }).lines.map((l) => l.s), [4]);
// Rauschen: Schmuck, Traenke, Unterbrechen.
check('Schmuck, Trank und Unterbrechen fallen weg',
  tab('actions=use_item,slot=trinket1\nactions+=/potion\nactions+=/wind_shear\nactions+=/lightning_bolt', [1, 1]).map((l) => l.s), [4]);
// Heldenbaum.
check('Liste des anderen Heldenbaums faellt weg',
  tab('actions=run_action_list,name=sb,if=hero_tree.stormbringer\nactions+=/lightning_bolt\nactions.sb=chain_lightning', [1, 1])
    .map((l) => l.s), [4]);

console.log(failed === 0 ? '\nalles gruen' : `\n${failed} Fehler`);
process.exit(failed === 0 ? 0 : 1);
