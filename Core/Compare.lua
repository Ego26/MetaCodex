-- Dein Build gegen den der Besten.
--
-- Bisher bot das Fenster eine fertige Kette zum Kopieren an, und das ist
-- alles oder nichts: entweder man uebernimmt fremde Talente vollstaendig
-- oder man laesst es. Die interessantere Auskunft ist die dazwischen -
-- WORIN unterscheidest du dich? Drei Talente anders ist eine Antwort,
-- mit der man etwas anfangen kann; eine Kette zum Einfuegen ist es
-- nicht.
--
-- Gerechnet wird gegen das, was der Client ueber deine aktuelle Wahl
-- sagt. Kann er nichts sagen - alter Client, Ladezeitpunkt, was auch
-- immer -, steht hier nichts. Eine erfundene Abweichung waere schlimmer
-- als keine.

local _, ns = ...

local Compare = {}
ns.Compare = Compare

---Was dieser Charakter gerade gewaehlt hat.
---
---Der Weg dorthin ist laenger, als er sein muesste: vom Knoten zum
---Eintrag, vom Eintrag zur Definition, und erst dort steht der Zauber.
---@return table|nil spell -> rank
function Compare.Mine()
    if not C_ClassTalents or not C_ClassTalents.GetActiveConfigID then return nil end
    if not C_Traits then return nil end
    local ok, configID = pcall(C_ClassTalents.GetActiveConfigID)
    if not ok or not configID then return nil end
    local okInfo, info = pcall(C_Traits.GetConfigInfo, configID)
    if not okInfo or type(info) ~= "table" or type(info.treeIDs) ~= "table" then return nil end

    local mine, any = {}, false
    for _, treeID in ipairs(info.treeIDs) do
        local okNodes, nodes = pcall(C_Traits.GetTreeNodes, treeID)
        if okNodes and type(nodes) == "table" then
            for _, nodeID in ipairs(nodes) do
                local okNode, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                if okNode and type(node) == "table" and node.activeEntry
                    and node.activeEntry.entryID then
                    local okEntry, entry = pcall(C_Traits.GetEntryInfo, configID,
                        node.activeEntry.entryID)
                    local defID = okEntry and type(entry) == "table" and entry.definitionID
                    if defID then
                        local okDef, def = pcall(C_Traits.GetDefinitionInfo, defID)
                        local spell = okDef and type(def) == "table" and def.spellID
                        if spell then
                            local rank = tonumber(node.activeEntry.rank) or 1
                            if (mine[spell] or 0) < rank then mine[spell] = rank end
                            any = true
                        end
                    end
                end
            end
        end
    end
    return any and mine or nil
end

---Worin unterscheidet sich eine Wahl von einem Build?
---
---Eine reine Rechnung, ohne Client: so laesst sie sich pruefen.
---
---"Fehlt" heisst, der Build hat das Talent und du nicht - oder du hast
---es auf einem niedrigeren Rang. "Zusaetzlich" heisst das Gegenteil.
---Beide Listen zusammen sind die Antwort auf "worin genau".
---@param mine table|nil spell -> rank
---@param build table|nil { nodes = { { spell = , rank = } } }
---@return table|nil { same = n, missing = { spellIDs }, extra = { spellIDs } }
function Compare.Diff(mine, build)
    if type(mine) ~= "table" or type(build) ~= "table" or type(build.nodes) ~= "table" then
        return nil
    end
    local want = {}
    for _, node in ipairs(build.nodes) do
        if node.spell then
            local rank = tonumber(node.rank) or 1
            if (want[node.spell] or 0) < rank then want[node.spell] = rank end
        end
    end

    local same, missing, extra = 0, {}, {}
    for spell, rank in pairs(want) do
        local have = mine[spell] or 0
        if have >= rank then same = same + 1 else missing[#missing + 1] = spell end
    end
    for spell in pairs(mine) do
        if not want[spell] then extra[#extra + 1] = spell end
    end
    table.sort(missing)
    table.sort(extra)
    return { same = same, missing = missing, extra = extra }
end

---Und dasselbe fuer den Charakter, auf dem man steht.
---@param build table|nil
---@return table|nil
function Compare.DiffTo(build)
    return Compare.Diff(Compare.Mine(), build)
end
