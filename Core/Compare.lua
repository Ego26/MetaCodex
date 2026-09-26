-- Dein Build gegen den der Besten.
--
-- Bisher bot das Fenster eine fertige Kette zum Kopieren an, und das ist
-- alles oder nichts: entweder man uebernimmt fremde Talente vollstaendig
-- oder man laesst es. Die interessantere Auskunft ist die dazwischen -
-- WORIN unterscheidest du dich? Drei Talente anders ist eine Antwort,
-- mit der man etwas anfangen kann; eine Kette zum Einfuegen ist es
-- nicht.
--
-- Verglichen wird ueber KNOTEN, nicht ueber Zauber-IDs.
--
-- Der erste Anlauf tat das anders und log prompt: ein Spieler fuegte
-- genau den angezeigten Build ein, und danach stand da "du spielst 3
-- Talente anders - dir fehlt Hand von Gul'dan, du hast zusaetzlich Hand
-- von Gul'dan". Dasselbe Talent auf beiden Seiten, weil ein Talent
-- mehrere Zauber-IDs hat: die Definition traegt eine, der ersetzte
-- Zauber eine zweite, und die Quellen nennen mal die eine, mal die
-- andere. Der Baum des Clients kennt dagegen beide und weiss, dass sie
-- an demselben Knoten haengen. Also wird jede ID erst auf ihren Knoten
-- und ihren Eintrag gebracht, und dort verglichen.
--
-- Kann der Client nichts sagen - alter Client, falscher Zeitpunkt -,
-- steht hier nichts. Eine erfundene Abweichung waere schlimmer als
-- keine.

local _, ns = ...

local Compare = {}
ns.Compare = Compare

---Der Baum, wie der Client ihn kennt.
---
---Zurueck kommt zweierlei: welcher Knoten mit welchem Eintrag und
---welchem Rang gewaehlt ist, und unter welchen Zauber-IDs jeder Eintrag
---ueberhaupt auffindbar ist.
---@return table|nil { nodes = { [nodeID] = { entry = , rank = } },
---                    bySpell = { [spellID] = { node = , entry = } } }
function Compare.Mine()
    if not C_ClassTalents or not C_ClassTalents.GetActiveConfigID then return nil end
    if not C_Traits then return nil end
    local ok, configID = pcall(C_ClassTalents.GetActiveConfigID)
    if not ok or not configID then return nil end
    local okInfo, info = pcall(C_Traits.GetConfigInfo, configID)
    if not okInfo or type(info) ~= "table" or type(info.treeIDs) ~= "table" then return nil end

    -- Eine Obergrenze, und zwar aus Vorsicht.
    --
    -- ipairs ueber etwas, das bei jedem Index wieder etwas zurueckgibt,
    -- laeuft ewig - und hier haengt das Ergebnis an einer fremden
    -- Schnittstelle. Ein Baum hat gut hundert Knoten; bei tausend ist
    -- etwas anderes kaputt, und dann soll das Spiel weiterlaufen.
    local MAX_TREES, MAX_NODES = 10, 1000
    local nodes, bySpell, any = {}, {}, false
    local trees = 0
    for _, treeID in ipairs(info.treeIDs) do
        trees = trees + 1
        if trees > MAX_TREES then break end
        local okNodes, list = pcall(C_Traits.GetTreeNodes, treeID)
        if okNodes and type(list) == "table" then
            local seen = 0
            for _, nodeID in ipairs(list) do
                seen = seen + 1
                if seen > MAX_NODES then break end
                local okNode, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                if okNode and type(node) == "table" then
                    -- Alle Eintraege des Knotens, nicht nur der gewaehlte:
                    -- nur so laesst sich die ID einer fremden Wahl
                    -- ueberhaupt zuordnen.
                    for _, entryID in ipairs(node.entryIDs or {}) do
                        local okEntry, entry = pcall(C_Traits.GetEntryInfo, configID, entryID)
                        local defID = okEntry and type(entry) == "table" and entry.definitionID
                        if defID then
                            local okDef, def = pcall(C_Traits.GetDefinitionInfo, defID)
                            if okDef and type(def) == "table" then
                                local where = { node = nodeID, entry = entryID }
                                if def.spellID then bySpell[def.spellID] = where end
                                if def.overriddenSpellID then
                                    bySpell[def.overriddenSpellID] = where
                                end
                                any = true
                            end
                        end
                    end
                    -- Geschenkte Knoten zaehlen nicht als eigene Wahl.
                    --
                    -- Manche Talente bekommt man mit der Spec, ohne einen
                    -- Punkt dafuer auszugeben. Wer sie mitzaehlt, liest
                    -- hinterher "du hast zusaetzlich ..." ueber etwas,
                    -- das jeder hat und niemand gewaehlt hat.
                    local bought = node.ranksPurchased
                    if node.activeEntry and node.activeEntry.entryID
                        and (bought == nil or bought > 0) then
                        nodes[nodeID] = {
                            entry = node.activeEntry.entryID,
                            rank = tonumber(node.activeEntry.rank) or 1,
                        }
                    end
                end
            end
        end
    end
    if not any then return nil end
    return { nodes = nodes, bySpell = bySpell }
end

---Worin unterscheidet sich eine Wahl von einem Build?
---
---Eine reine Rechnung, ohne Client: so laesst sie sich pruefen.
---
---"Fehlt" heisst: der Build hat an diesem Knoten etwas, das du nicht
---hast - gar nicht, auf einem niedrigeren Rang, oder als anderer
---Eintrag eines Wahlknotens. "Zusaetzlich" heisst das Gegenteil: ein
---Knoten, an dem du etwas gewaehlt hast und der Build nicht.
---@param mine table|nil aus Compare.Mine
---@param build table|nil { nodes = { { spell = , rank = } } }
---@return table|nil { same = n, missing = { spellIDs }, extra = { nodeIDs } }
function Compare.Diff(mine, build)
    if type(mine) ~= "table" or type(build) ~= "table" or type(build.nodes) ~= "table" then
        return nil
    end
    local index = mine.bySpell
    local chosen = mine.nodes
    if type(index) ~= "table" or type(chosen) ~= "table" then return nil end

    local same, missing = 0, {}
    local wanted = {}
    for _, node in ipairs(build.nodes) do
        local spell = node.spell
        local at = spell and index[spell]
        if at then
            local rank = tonumber(node.rank) or 1
            local have = chosen[at.node]
            wanted[at.node] = true
            if have and have.entry == at.entry and have.rank >= rank then
                same = same + 1
            else
                missing[#missing + 1] = spell
            end
        end
        -- Eine ID, die der Baum dieses Clients nicht kennt, wird
        -- uebergangen. Sie gehoert zu einer anderen Klasse oder zu einem
        -- Stand, den dieser Client nicht hat - daraus eine Abweichung zu
        -- machen waere geraten.
    end

    local extra = {}
    for nodeID in pairs(chosen) do
        if not wanted[nodeID] then extra[#extra + 1] = nodeID end
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

---Der Name eines Knotens, wie der Client ihn nennt.
---
---Fuer die Zeile "du hast zusaetzlich ...": dort steht ein Knoten, kein
---Zauber, und den Namen kennt nur der Client.
---@param nodeID number
---@return string|nil
function Compare.NodeName(nodeID)
    if not C_ClassTalents or not C_Traits or not nodeID then return nil end
    local ok, configID = pcall(C_ClassTalents.GetActiveConfigID)
    if not ok or not configID then return nil end
    local okNode, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
    if not okNode or type(node) ~= "table" or not node.activeEntry then return nil end
    local okEntry, entry = pcall(C_Traits.GetEntryInfo, configID, node.activeEntry.entryID)
    local defID = okEntry and type(entry) == "table" and entry.definitionID
    if not defID then return nil end
    local okDef, def = pcall(C_Traits.GetDefinitionInfo, defID)
    local spell = okDef and type(def) == "table" and def.spellID
    if not spell then return nil end
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spell)
    return info and info.name or nil
end
