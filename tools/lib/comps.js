// Group compositions: M+ groups from raider.io (high keys) and Warcraft
// Logs (+7 to +21), raid setups from Warcraft Logs, and for PvP the specs
// at the top of the Battle.net ladders.
//
// Every run in the list carries its full roster: five players, each with
// spec and role. The collector used to take them apart into single
// players for builds and races; here they stay together as the group
// that timed the key.
//
// What the numbers mean - and what they do not. They count what the top
// groups PLAY, not what is proven strongest. Popular specs pull in more
// players, and those players then show up in the top runs. That is why
// the window calls the section "groups in top runs", not "best comps".
//
// Three answers, because a whole group alone fragments: with forty specs
// the most common group of five often holds only a few percent. So the
// specs per role come first (who tanks, who heals, who deals damage),
// and the full groups after that.

const { share } = require('./share');

// Fewer than this many runs in a dungeon is not a sample worth showing.
const MIN_RUNS = 30;
// A group seen once is an anecdote, not a pattern.
const MIN_GROUP = 2;
// How many full groups go into the data.
const TOP_GROUPS = 10;

const slug = (text) => String(text).toLowerCase()
  .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

// The role of a spec, for sources that do not say it (Warcraft Logs,
// Battle.net). raider.io names the role per player and does not need it.
// Everything that is neither tank nor healer deals damage.
const TANKS = new Set([66, 73, 104, 250, 268, 581]);
const HEALERS = new Set([65, 105, 256, 257, 264, 270, 1468]);
const roleOf = (spec) => (TANKS.has(Number(spec)) ? 'tank'
  : HEALERS.has(Number(spec)) ? 'healer' : 'dps');

/**
 * One run from the list as a group: one tank, one healer, three damage
 * dealers, damage sorted by spec id so the same group always reads the
 * same. Anything else (a missing spec, a roster of four) is dropped
 * rather than guessed.
 *
 * @param {object} run  `rankings[].run` from /mythic-plus/runs
 * @returns {{dungeon: string|null, key: number, specs: number[]}|null}
 */
function groupOf(run) {
  if (!run || !Array.isArray(run.roster) || run.roster.length !== 5) return null;
  // Only timed runs: the window says "timed top runs". A run without
  // chests went over time; one without the field is taken as it is.
  if (run.num_chests !== undefined && !(Number(run.num_chests) > 0)) return null;
  const byRole = { tank: [], healer: [], dps: [] };
  for (const entry of run.roster) {
    const spec = entry && entry.character && entry.character.spec;
    const id = spec && Number(spec.id);
    const list = byRole[entry && entry.role];
    if (!id || !list) return null;
    list.push(id);
  }
  if (byRole.tank.length !== 1 || byRole.healer.length !== 1 || byRole.dps.length !== 3) return null;
  byRole.dps.sort((a, b) => a - b);
  return {
    dungeon: (run.dungeon && run.dungeon.name) || null,
    key: Number(run.mythic_level) || 0,
    specs: [byRole.tank[0], byRole.healer[0], ...byRole.dps],
  };
}

/**
 * The same group from a list of spec ids, where the source knows the
 * specs but not the roles (a Warcraft Logs fight).
 *
 * @param {number[]} specs
 * @param {number} key
 * @param {string|null} dungeon
 */
function groupFromSpecs(specs, key, dungeon) {
  const roster = (specs || []).map((id) => ({ role: roleOf(id), character: { spec: { id } } }));
  return groupOf({ roster, mythic_level: key, dungeon: dungeon ? { name: dungeon } : null });
}

/**
 * Shares over a set of groups.
 *
 * A spec's share is the share of RUNS it plays in, not of slots: "a mage
 * in 41 % of the runs" is the question, and a double mage group is still
 * one run with a mage. So the damage shares add up to more than 100.
 *
 * @param {Array} groups  results of groupOf()
 * @returns {object|null}
 */
function tallyGroups(groups) {
  const list = (groups || []).filter(Boolean);
  if (!list.length) return null;
  const total = list.length;
  const roles = { tank: new Map(), healer: new Map(), dps: new Map() };
  const full = new Map();
  let minKey = Infinity, maxKey = 0;

  const bump = (map, spec, key) => {
    const row = map.get(spec) || map.set(spec, { n: 0, maxKey: 0 }).get(spec);
    row.n += 1;
    if (key > row.maxKey) row.maxKey = key;
  };
  for (const g of list) {
    if (g.key < minKey) minKey = g.key;
    if (g.key > maxKey) maxKey = g.key;
    bump(roles.tank, g.specs[0], g.key);
    bump(roles.healer, g.specs[1], g.key);
    for (const spec of new Set(g.specs.slice(2))) bump(roles.dps, spec, g.key);
    const sig = g.specs.join(',');
    const row = full.get(sig) || full.set(sig, { specs: g.specs, n: 0, maxKey: 0 }).get(sig);
    row.n += 1;
    if (g.key > row.maxKey) row.maxKey = g.key;
  }

  const rows = (map) => [...map.entries()]
    .map(([spec, r]) => ({ spec, n: r.n, pct: share(r.n, total), maxKey: r.maxKey }))
    .sort((a, b) => b.n - a.n || b.maxKey - a.maxKey || a.spec - b.spec);
  const groupsOut = [...full.values()]
    .filter((r) => r.n >= MIN_GROUP)
    .sort((a, b) => b.n - a.n || b.maxKey - a.maxKey || a.specs.join(',').localeCompare(b.specs.join(',')))
    .slice(0, TOP_GROUPS)
    .map((r) => ({ specs: r.specs, n: r.n, pct: share(r.n, total), maxKey: r.maxKey }));

  return {
    runs: total,
    minKey: minKey === Infinity ? 0 : minKey,
    maxKey,
    // How many different groups there were at all. It says how spread
    // the field is: 1900 different groups in 2000 runs is a free choice,
    // 300 is a meta.
    distinct: full.size,
    tank: rows(roles.tank),
    healer: rows(roles.healer),
    dps: rows(roles.dps),
    groups: groupsOut,
  };
}

/**
 * All runs, and each dungeon on its own, under the mode keys the addon
 * already uses: "mplus" and "mplus/<dungeon slug>". A dungeon with too
 * few runs is left out instead of shown on a handful.
 *
 * @param {Array} groups  results of groupOf()
 * @param {string} [prefix]  the mode: "mplus" (raider.io) or "mplus-keys" (Warcraft Logs)
 * @returns {Object<string, object>}
 */
function compsByMode(groups, prefix) {
  const base = prefix || 'mplus';
  const list = (groups || []).filter(Boolean);
  const out = {};
  const all = tallyGroups(list);
  if (!all) return out;
  out[base] = all;
  const byDungeon = new Map();
  for (const g of list) {
    if (!g.dungeon) continue;
    const key = base + '/' + slug(g.dungeon);
    if (!byDungeon.has(key)) byDungeon.set(key, { name: g.dungeon, list: [] });
    byDungeon.get(key).list.push(g);
  }
  for (const [key, d] of [...byDungeon.entries()].sort()) {
    if (d.list.length < MIN_RUNS) continue;
    out[key] = { dungeon: d.name, ...tallyGroups(d.list) };
  }
  return out;
}

// --- Raid ---------------------------------------------------------------
//
// Twenty players have no "most common group". The question there is per
// spec: in how many kills is it there at all, and how many of it.

/**
 * Raw counts over boss kills, so several difficulties can be added up
 * before the shares are taken ("Raid (all)").
 *
 * @param {number[][]} kills  per kill the spec ids of its players
 * @returns {{kills: number, players: number, specs: Object<string, {kills: number, total: number}>}}
 */
function raidCounts(kills) {
  const out = { kills: 0, players: 0, specs: {} };
  for (const specs of kills || []) {
    if (!Array.isArray(specs) || !specs.length) continue;
    out.kills += 1;
    out.players += specs.length;
    const here = new Map();
    for (const id of specs) here.set(Number(id), (here.get(Number(id)) || 0) + 1);
    for (const [id, n] of here) {
      const row = out.specs[id] || (out.specs[id] = { kills: 0, total: 0 });
      row.kills += 1;
      row.total += n;
    }
  }
  return out;
}

/** Two sets of raw counts as one. */
function addRaidCounts(a, b) {
  const out = { kills: (a.kills || 0) + (b.kills || 0), players: (a.players || 0) + (b.players || 0), specs: {} };
  for (const src of [a.specs || {}, b.specs || {}]) {
    for (const [id, r] of Object.entries(src)) {
      const row = out.specs[id] || (out.specs[id] = { kills: 0, total: 0 });
      row.kills += r.kills;
      row.total += r.total;
    }
  }
  return out;
}

/**
 * Shares per role: in how many kills a spec is there (pct), and how many
 * of it a kill has on average where it is there (avg, one decimal).
 * Plus the average setup of a kill: tanks, healers, damage.
 */
function raidShares(counts) {
  if (!counts || !counts.kills) return null;
  const roles = { tank: [], healer: [], dps: [] };
  const perRole = { tank: 0, healer: 0, dps: 0 };
  for (const [id, r] of Object.entries(counts.specs)) {
    const role = roleOf(id);
    perRole[role] += r.total;
    roles[role].push({
      spec: Number(id), n: r.kills, pct: share(r.kills, counts.kills),
      avg: Math.round((r.total / r.kills) * 10) / 10,
    });
  }
  for (const list of Object.values(roles)) list.sort((a, b) => b.n - a.n || a.spec - b.spec);
  const setup = {};
  for (const role of Object.keys(perRole)) setup[role] = Math.round((perRole[role] / counts.kills) * 10) / 10;
  return { kills: counts.kills, size: Math.round((counts.players / counts.kills) * 10) / 10, setup, ...roles };
}

// --- PvP ----------------------------------------------------------------
//
// The ladders list characters, not teams: who played with whom is not
// known anywhere. What is known is which specs stand at the top.

/**
 * Spec shares among the top players of one bracket, per role.
 *
 * @param {number[]} specs  one spec id per top player
 */
function specShares(specs) {
  const list = (specs || []).map(Number).filter(Boolean);
  if (!list.length) return null;
  const n = new Map();
  for (const id of list) n.set(id, (n.get(id) || 0) + 1);
  const roles = { tank: [], healer: [], dps: [] };
  for (const [spec, count] of n) {
    roles[roleOf(spec)].push({ spec, n: count, pct: share(count, list.length) });
  }
  for (const rows of Object.values(roles)) rows.sort((a, b) => b.n - a.n || a.spec - b.spec);
  return { players: list.length, ...roles };
}

module.exports = {
  groupOf, groupFromSpecs, tallyGroups, compsByMode, roleOf,
  raidCounts, addRaidCounts, raidShares, specShares,
  MIN_RUNS, MIN_GROUP, TOP_GROUPS,
};
