// Reads a talent import string - reads, never writes.
//
// Why a decoder is fine where an encoder was not: a wrong encoder hands the
// player a string the game rejects. A wrong decoder only misfiles a build,
// and it can be checked. It was: against 60 raider.io profiles that carry
// the string and the decoded nodes side by side, every node of every
// profile matched. The one node the decoder finds that raider.io does not
// list is the granted keystone of the chosen hero tree.
//
// Format (Blizzard's ImportLoadout, serialization version 2):
//   version 8 bits, spec 16 bits, tree hash 128 bits, then per node of the
//   tree in ascending node id: selected(1); if selected: purchased(1); if
//   purchased: partial(1), [ranks 6], choice(1), [entry index 2].
//   A granted node writes selected=1, purchased=0 and nothing else.
//   Tiered nodes (type 1) chain their entries; their ranks add up.
//
// The tree tables come from tools/data/trait-map.json, written by
// build-catalog.js from the game's own DB2 tables.

const fs = require('fs');
const path = require('path');

const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

let map = null;

/** Loads the trait map once. */
function load(base) {
  if (map) return map;
  const file = path.join(base, 'tools', 'data', 'trait-map.json');
  map = JSON.parse(fs.readFileSync(file, 'utf8'));
  return map;
}

function bits(text) {
  const out = [];
  for (const ch of text) {
    let v = B64.indexOf(ch);
    if (v < 0) throw new Error('not a loadout string');
    for (let i = 0; i < 6; i += 1) { out.push(v & 1); v >>= 1; }
  }
  return out;
}

/**
 * Decodes a string.
 * @returns {{ spec: number, subTree: number|null, nodes: Array<{node, entry, spell, rank, granted, subTree}> }|null}
 */
function decode(base, text, treeId) {
  const m = load(base);
  const tree = m.trees[treeId];
  if (!tree) return null;
  const b = bits(text);
  let pos = 0;
  const read = (n) => { let v = 0; for (let i = 0; i < n; i += 1) v |= (b[pos++] || 0) << i; return v; };
  const version = read(8);
  const spec = read(16);
  read(128);
  if (version !== 2) return null;

  const out = [];
  let subTree = null;
  for (const node of tree.nodes) {
    if (!read(1)) continue;
    const granted = read(1) === 0;
    let rank = 1, choice = 0;
    if (!granted) {
      const partial = read(1);
      const ranks = partial ? read(6) : null;
      if (read(1)) choice = read(2);
      if (node.type === 1) {
        const maxes = node.entries.map((e) => e.maxRanks || 1);
        const total = maxes.reduce((x, y) => x + y, 0);
        rank = ranks !== null ? ranks : total;
        let acc = 0; choice = 0;
        for (let i = 0; i < maxes.length; i += 1) { acc += maxes[i]; choice = i; if (acc >= rank) break; }
      } else {
        const chosen = node.entries[choice];
        rank = ranks !== null ? ranks : (chosen ? chosen.maxRanks || 1 : 1);
      }
    }
    const entry = node.entries[choice];
    if (!entry) continue;
    // The hero tree: the sub-tree selection node names it; the granted
    // keystone of that tree confirms it.
    if (node.type === 3 && entry.subTree) subTree = entry.subTree;
    if (entry.subTree && !subTree && granted) subTree = entry.subTree;
    out.push({ node: node.id, entry: entry.id, spell: entry.spell || null, rank, granted, subTree: entry.subTree || null });
  }
  return { spec, subTree, nodes: out };
}

/** The tree of a spec, or null. */
function treeOfSpec(base, specID) {
  const m = load(base);
  return m.treeBySpec[specID] || null;
}

module.exports = { load, decode, treeOfSpec };
