-- Die Vorschau im Talentbaum: was dieser Build an DEINEM Baum aendert.
--
-- Ein Alternativbuild als Liste zweier Namen beantwortet nicht die
-- Frage, die man sich vor dem Baum stellt: wo muss ich hinklicken, und
-- was verliere ich dafuer. Also wird es dort gezeigt, wo es passiert -
-- gruen um das, was dazukaeme, rot um das, was wegfiele.
--
-- GEGEN DEINEN BAUM, NICHT GEGEN DEN HAEUFIGSTEN. In den Daten steht je
-- Build die vollstaendige Talentliste (im Mittel 76 Knoten), und der
-- Client sagt, welche Knoten du gekauft hast. Der Unterschied dieser
-- beiden Mengen ist die Antwort. Der Unterschied zum haeufigsten Build
-- waere eine andere Frage - eine, die nur stellt, wer den haeufigsten
-- spielt.
--
-- NICHTS WIRD ANGEFASST. Unsere Rahmen haengen an UIParent und docken
-- nur an die Knoepfe an; gelesen wird aus C_Traits, geschrieben nichts.
-- Blizzards Talentoberflaeche ist geschuetzt, und wer darin etwas setzt,
-- bekommt "Diese Aktion ist gesperrt" - irgendwann spaeter, an einer
-- ganz anderen Stelle.

local _, ns = ...

local Tree = {}
ns.Tree = Tree

local S = ns.Style

---Blizzards Talentbaum, wie er in dieser Fassung heisst.
---@return table|nil
local function tabFrame()
    local f = _G.PlayerSpellsFrame or _G.ClassTalentFrame
    return f and f.TalentsFrame
end

---@return number|nil
local function activeConfig()
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID) then return nil end
    local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
    return ok and id or nil
end

---Die Knoten eines Baumes.
---
---GEMESSEN, NICHT GERATEN: der erste Versuch rief
---GetTreeNodes(configID, treeID) auf und bekam eine leere Liste - keinen
---Fehler, nur nichts, was aussieht wie "gibt es nicht". In diesem Client
---nimmt die Funktion nur den Baum. Beide Formen stehen hier, die
---ergiebige gewinnt; sollte eine kuenftige Fassung es umdrehen, faellt
---das nicht auf uns zurueck.
---@param configID number
---@param treeID number
---@return number[]
local function nodesOf(configID, treeID)
    if not (C_Traits and C_Traits.GetTreeNodes) then return {} end
    local ok, list = pcall(C_Traits.GetTreeNodes, treeID)
    if ok and type(list) == "table" and #list > 0 then return list end
    ok, list = pcall(C_Traits.GetTreeNodes, configID, treeID)
    if ok and type(list) == "table" then return list end
    return {}
end

---Der Zauber hinter einem Eintrag.
---@param configID number
---@param entryID number
---@return number|nil
local function spellOfEntry(configID, entryID)
    if not (C_Traits and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo) then
        return nil
    end
    local ok, entry = pcall(C_Traits.GetEntryInfo, configID, entryID)
    local definitionID = ok and entry and entry.definitionID
    if not definitionID then return nil end
    local ok2, def = pcall(C_Traits.GetDefinitionInfo, definitionID)
    return (ok2 and def and tonumber(def.spellID)) or nil
end

-- Einmal je Konfiguration gebaut. 282 Knoten mit je ein bis drei
-- Eintraegen sind tausend Abfragen; die bei jedem Hovern zu wiederholen,
-- waere verschwendet.
--
-- Die Nummer der Konfiguration ist der Schluessel, und damit braucht es
-- kein Vergessen von aussen: ein Specwechsel bringt eine andere Nummer
-- mit, und was geskillt ist, wird ohnehin bei jeder Vorschau neu
-- gelesen.
local mapConfig, spellToNode

---Zauber-Nummer -> Knoten im Baum.
---@return table<number, number>|nil
function Tree.Map()
    local configID = activeConfig()
    if not configID then return nil end
    if mapConfig == configID and spellToNode then return spellToNode end
    if not (C_Traits and C_Traits.GetConfigInfo and C_Traits.GetNodeInfo) then
        return nil
    end
    local ok, info = pcall(C_Traits.GetConfigInfo, configID)
    if not (ok and info and info.treeIDs) then return nil end

    local out = {}
    for _, treeID in ipairs(info.treeIDs) do
        for _, nodeID in ipairs(nodesOf(configID, treeID)) do
            local ok2, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
            for _, entryID in ipairs((ok2 and node and node.entryIDs) or {}) do
                local spell = spellOfEntry(configID, entryID)
                -- Der erste gewinnt: derselbe Zauber kann an zwei Stellen
                -- haengen, und ein zweiter Treffer wuerde den ersten
                -- ueberschreiben, ohne dass einer der beiden falscher
                -- waere.
                if spell and not out[spell] then out[spell] = nodeID end
            end
        end
    end
    mapConfig, spellToNode = configID, out
    return out
end

---Was du gerade geskillt hast, als Menge von Zauber-Nummern.
---
---NUR DER GEWAEHLTE EINTRAG. Ein Wahlknoten bietet zwei Talente an und
---du hast eines; beide zu zaehlen hiesse, dir etwas anzudichten, das du
---nicht hast.
---@return table<number, boolean>
function Tree.Worn()
    local configID = activeConfig()
    local out = {}
    if not (configID and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetNodeInfo) then
        return out
    end
    local ok, info = pcall(C_Traits.GetConfigInfo, configID)
    if not (ok and info and info.treeIDs) then return out end

    for _, treeID in ipairs(info.treeIDs) do
        for _, nodeID in ipairs(nodesOf(configID, treeID)) do
            local ok2, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
            node = ok2 and node or nil
            local raenge = tonumber(node and node.ranksPurchased) or 0
            if node and raenge > 0 then
                local gewaehlt = node.activeEntry and node.activeEntry.entryID
                if gewaehlt then
                    local spell = spellOfEntry(configID, gewaehlt)
                    if spell then out[spell] = true end
                else
                    for _, entryID in ipairs(node.entryIDs or {}) do
                        local spell = spellOfEntry(configID, entryID)
                        if spell then out[spell] = true end
                    end
                end
            end
        end
    end
    return out
end

-- ---------------------------------------------------- Die Rahmen

local markers, used = {}, 0

---Ein Rahmen aus dem Vorrat.
---
---Sie haengen an UIParent und werden wiederverwendet. Einer je Knoten,
---der sich aendert - und das sind selten mehr als ein Dutzend.
---@param i number
---@return table
local function marker(i)
    if markers[i] then return markers[i] end
    local m = CreateFrame("Frame", nil, UIParent)
    -- Ueber dem Talentfenster. Darunter waere er zwar da, aber unter dem
    -- Symbol, auf das er zeigt.
    m:SetFrameStrata("DIALOG")
    m.lines = S:Border(m, "success")
    -- Zweiter Rahmen, einen Pixel weiter innen: ein einzelner Strich auf
    -- einem Symbol mit eigener Umrandung verschwindet.
    local innen = CreateFrame("Frame", nil, m)
    innen:SetPoint("TOPLEFT", 1, -1)
    innen:SetPoint("BOTTOMRIGHT", -1, 1)
    m.innerLines = S:Border(innen, "success")
    m.inner = innen
    m:Hide()
    markers[i] = m
    return m
end

---@param m table
---@param token string
local function recolor(m, token)
    for _, lines in ipairs({ m.lines, m.innerLines }) do
        for _, texture in pairs(lines or {}) do
            texture:SetVertexColor(S:Color(token))
        end
    end
end

---Alle Rahmen weg.
function Tree.Hide()
    for i = 1, used do
        if markers[i] then markers[i]:Hide() end
    end
    used = 0
end

---Zeigt, was dieser Build an deinem Baum aendern wuerde.
---
---@param spells number[]|nil  die vollstaendige Talentliste des Builds
---@return number plus   wie viele dazukaemen
---@return number minus  wie viele wegfielen
---@return number fehlt  wie viele davon im Baum nicht zu finden waren
function Tree.Show(spells)
    Tree.Hide()
    if type(spells) ~= "table" or #spells == 0 then return 0, 0, 0 end
    local map = Tree.Map()
    local tab = tabFrame()
    if not (map and tab and tab.GetTalentButtonByNodeID) then return 0, 0, 0 end

    local worn = Tree.Worn()
    local wanted = {}
    for _, spell in ipairs(spells) do
        local id = tonumber(spell) or tonumber(spell and spell.spell)
        if id then wanted[id] = true end
    end

    local plus, minus, fehlt = 0, 0, 0

    ---@param spell number
    ---@param token string
    local function mark(spell, token)
        local nodeID = map[spell]
        local button = nodeID and select(2, pcall(tab.GetTalentButtonByNodeID, tab, nodeID))
        -- EIN NICHT GEFUNDENES TALENT WIRD GEZAEHLT, NICHT VERSCHWIEGEN.
        -- Von 282 Knoten tragen 121 einen sichtbaren Rahmen; was im
        -- Held-Baum sitzt oder gerade nicht gezeichnet wird, hat keinen.
        -- Eine Vorschau, die stillschweigend drei Talente auslaesst, ist
        -- schlimmer als eine, die sagt, dass sie es tut.
        if not (button and button.GetLeft and tonumber(button:GetLeft())) then
            fehlt = fehlt + 1
            return false
        end
        used = used + 1
        local m = marker(used)
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
        m:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
        recolor(m, token)
        m:Show()
        return true
    end

    for spell in pairs(wanted) do
        if not worn[spell] then
            if mark(spell, "success") then plus = plus + 1 end
        end
    end
    for spell in pairs(worn) do
        if not wanted[spell] then
            if mark(spell, "danger") then minus = minus + 1 end
        end
    end
    return plus, minus, fehlt
end
