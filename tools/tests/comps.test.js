// The rules behind the section "Groups in top runs".
//
// A group is one tank, one healer and three damage dealers from the same
// run; the shares are shares of runs.
const {
  groupOf, groupFromSpecs, tallyGroups, compsByMode, roleOf,
  raidCounts, addRaidCounts, raidShares, specShares, MIN_RUNS, TOP_GROUPS,
} = require('../lib/comps');

let failed = 0;
function check(what, got, want) {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) failed += 1;
  console.log(`  ${ok ? 'ok  ' : 'FAIL'}  ${what}`
    + (ok ? '' : `\n          got:      ${JSON.stringify(got)}`
      + `\n          expected: ${JSON.stringify(want)}`));
}

const member = (spec, role) => ({ role, character: { spec: { id: spec } } });
const run = (specs, key, dungeon) => ({
  mythic_level: key,
  dungeon: { name: dungeon || 'Altar of Fangs' },
  roster: [
    member(specs[2], 'dps'), member(specs[1], 'healer'), member(specs[3], 'dps'),
    member(specs[0], 'tank'), member(specs[4], 'dps'),
  ],
});

// A group reads the same however the roster was ordered.
check('tank, healer, then damage by spec id',
  groupOf(run([581, 256, 1473, 63, 259], 24)).specs, [581, 256, 63, 259, 1473]);
check('the key level comes along', groupOf(run([581, 256, 1473, 63, 259], 24)).key, 24);
check('the dungeon comes along', groupOf(run([581, 256, 1473, 63, 259], 24)).dungeon, 'Altar of Fangs');

// Rosters that are not a group of five are dropped, not guessed.
check('four players are no group', groupOf({ roster: run([581, 256, 1473, 63, 259], 20).roster.slice(0, 4) }), null);
const twoTanks = run([581, 256, 1473, 63, 259], 20);
twoTanks.roster[0].role = 'tank';
check('two tanks are no group', groupOf(twoTanks), null);
const noSpec = run([581, 256, 1473, 63, 259], 20);
noSpec.roster[2].character.spec = null;
check('a player without spec drops the run', groupOf(noSpec), null);
check('nothing in, nothing out', tallyGroups([]), null);
check('a depleted run is no top run', groupOf({ ...run([581, 256, 1473, 63, 259], 25), num_chests: 0 }), null);
check('a timed run counts', groupOf({ ...run([581, 256, 1473, 63, 259], 25), num_chests: 2 }).key, 25);

// Shares are shares of runs.
const groups = [
  groupOf(run([581, 256, 1473, 63, 259], 24)),
  groupOf(run([581, 256, 1473, 63, 259], 23)),
  groupOf(run([66, 256, 63, 63, 259], 22)),
  groupOf(run([581, 1468, 1473, 62, 259], 22)),
];
const t = tallyGroups(groups);
check('all runs counted', t.runs, 4);
check('key range', [t.minKey, t.maxKey], [22, 24]);
check('distinct groups', t.distinct, 3);
check('tanks, most played first, highest key along',
  t.tank, [{ spec: 581, n: 3, pct: 75, maxKey: 24 }, { spec: 66, n: 1, pct: 25, maxKey: 22 }]);
// The double fire mage is one run with a fire mage, not two.
const fire = t.dps.find((r) => r.spec === 63);
check('a spec twice in one run counts once', fire.n, 3);
check('rogues in every run', t.dps.find((r) => r.spec === 259).pct, 100);
// Seen once is an anecdote: only the group seen twice stays.
check('only groups seen at least twice',
  t.groups, [{ specs: [581, 256, 63, 259, 1473], n: 2, pct: 50, maxKey: 24 }]);

// Many different groups: only the top ones go out.
const many = [];
for (let i = 0; i < TOP_GROUPS + 5; i++) {
  for (let k = 0; k < 2; k++) many.push(groupOf(run([581, 256, 1473, 63, 100 + i], 20)));
}
check('at most TOP_GROUPS groups', tallyGroups(many).groups.length, TOP_GROUPS);

// Per dungeon, under the mode keys of the addon - and only with a sample.
const spread = [];
for (let i = 0; i < MIN_RUNS; i++) spread.push(groupOf(run([581, 256, 1473, 63, 259], 22, "Kings' Rest")));
for (let i = 0; i < MIN_RUNS - 1; i++) spread.push(groupOf(run([581, 256, 1473, 63, 259], 22, 'Murder Row')));
const modes = compsByMode(spread);
check('all runs and the dungeons with enough runs', Object.keys(modes), ['mplus', 'mplus/kings-rest']);
check('the dungeon keeps its name', modes['mplus/kings-rest'].dungeon, "Kings' Rest");
check('all runs include the small dungeon too', modes.mplus.runs, MIN_RUNS * 2 - 1);

// Warcraft Logs: specs without roles, under their own mode key.
check('roles from the spec', [roleOf(250), roleOf(65), roleOf(1480)], ['tank', 'healer', 'dps']);
check('a group from spec ids alone',
  groupFromSpecs([262, 71, 65, 261, 250], 15, 'Murder Row').specs, [250, 65, 71, 261, 262]);
check('two healers are no group from spec ids either', groupFromSpecs([65, 264, 71, 261, 250], 15), null);
const keys = [];
for (let i = 0; i < MIN_RUNS; i++) keys.push(groupFromSpecs([250, 65, 71, 261, 262], 12, 'Murder Row'));
check('the +7 to +21 groups stand under their own key',
  Object.keys(compsByMode(keys, 'mplus-keys')), ['mplus-keys', 'mplus-keys/murder-row']);

// Raid: per spec, in how many kills and how many of it.
const heroic = raidCounts([
  [250, 104, 65, 65, 264, 262, 262, 71],
  [250, 581, 65, 264, 264, 262, 71, 71],
]);
const mythic = raidCounts([[250, 104, 65, 65, 264, 262, 63, 71]]);
const raid = raidShares(addRaidCounts(heroic, mythic));
check('all kills of all difficulties', raid.kills, 3);
check('size and setup per kill', [raid.size, raid.setup], [8, { tank: 2, healer: 3, dps: 3 }]);
check('a spec in every kill, with its average count',
  raid.healer.find((r) => r.spec === 65), { spec: 65, n: 3, pct: 100, avg: 1.7 });
check('a spec in one kill of three', raid.dps.find((r) => r.spec === 63), { spec: 63, n: 1, pct: 33, avg: 1 });
check('no kills, no shares', raidShares(raidCounts([])), null);

// PvP: which specs stand at the top, per role.
const pvp = specShares([65, 65, 262, 71, 71, 71, 250]);
check('top players counted', pvp.players, 7);
check('damage, most first', pvp.dps.map((r) => [r.spec, r.pct]), [[71, 43], [262, 14]]);
check('healers and tanks apart', [pvp.healer[0].spec, pvp.tank[0].spec], [65, 250]);
check('nobody, nothing', specShares([]), null);

console.log(failed ? `\n${failed} FAILED` : '\nall ok');
process.exit(failed ? 1 : 0);
