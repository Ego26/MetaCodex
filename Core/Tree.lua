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
local mapConfig, spellToNode, nodeSubTree, nameToNode

---Wie der Zauber heisst - in der Sprache dieses Clients.
---@param id number
---@return string|nil
local function spellName(id)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
    local name = info and info.name
    return type(name) == "string" and name ~= "" and name or nil
end

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

    local out, subs, byName = {}, {}, {}
    for _, treeID in ipairs(info.treeIDs) do
        for _, nodeID in ipairs(nodesOf(configID, treeID)) do
            local ok2, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
            node = ok2 and node or nil
            -- ZU WELCHEM HELD-BAUM EIN KNOTEN GEHOERT.
            --
            -- Held-Talente sind keine eigenen Baeume, sondern Knoten mit
            -- einer subTreeID im selben Baum - und es gibt mehrere je
            -- Spec, von denen einer gewaehlt ist. Wer das nicht
            -- mitfuehrt, kann spaeter nur sagen "ein Talent fehlt" statt
            -- "dieser Build will einen anderen Held-Baum".
            local sub = node and tonumber(node.subTreeID)
            if sub then subs[nodeID] = sub end
            for _, entryID in ipairs((node and node.entryIDs) or {}) do
                local spell = spellOfEntry(configID, entryID)
                -- Der erste gewinnt: derselbe Zauber kann an zwei Stellen
                -- haengen, und ein zweiter Treffer wuerde den ersten
                -- ueberschreiben, ohne dass einer der beiden falscher
                -- waere.
                if spell and not out[spell] then out[spell] = nodeID end
                -- UND UNTER SEINEM NAMEN.
                --
                -- Dasselbe Talent kann zwei Nummern haben: der Baum
                -- traegt 443454 "Schnelligkeit der Ahnen", die Messdaten
                -- 448861 - gleicher Name, anderer Zauber, und
                -- GetOverrideSpell verbindet die beiden nicht. Gemessen
                -- im Spiel, nicht vermutet.
                --
                -- Der Name ist die Bruecke, weil ihn beide Seiten aus
                -- DIESEM Client holen: unsere Daten speichern nur
                -- Nummern, der Name kommt immer von GetSpellInfo. Damit
                -- stimmt er auf jedem Sprachclient.
                --
                -- NUR WENN ER EINDEUTIG IST. Tragen zwei Knoten
                -- denselben Namen, wird nichts gewaehlt: ein Rahmen um
                -- den falschen Knoten ist schlimmer als keiner, weil er
                -- aussieht wie eine Auskunft.
                local name = spell and spellName(spell)
                if name then
                    if byName[name] == nil then
                        byName[name] = nodeID
                    elseif byName[name] ~= nodeID then
                        byName[name] = false
                    end
                end
            end
        end
    end
    mapConfig, spellToNode, nodeSubTree, nameToNode = configID, out, subs, byName
    return out
end

---Der Knoten zu einem Zauber - ueber die Nummer, sonst ueber den Namen.
---@param spell number
---@return number|nil nodeID
function Tree.NodeFor(spell)
    local map = Tree.Map()
    if not map then return nil end
    local nodeID = map[spell]
    if nodeID then return nodeID end
    local name = spellName(spell)
    -- false heisst "zweimal vergeben" und faellt hier mit durch.
    local hit = name and nameToNode and nameToNode[name]
    return hit or nil
end

---Der Held-Baum eines Knotens, wenn er zu einem gehoert.
---@param nodeID number
---@return number|nil subTreeID
local function subTreeOf(nodeID)
    return nodeSubTree and nodeSubTree[nodeID] or nil
end

---Name und Zustand eines Held-Baums.
---@param subTreeID number
---@return string|nil name, boolean aktiv
local function subTreeInfo(subTreeID)
    local configID = activeConfig()
    if not (configID and C_Traits and C_Traits.GetSubTreeInfo) then return nil, false end
    local ok, info = pcall(C_Traits.GetSubTreeInfo, configID, subTreeID)
    if not (ok and info) then return nil, false end
    return info.name, info.isActive and true or false
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
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- SO DICK, DASS MAN ES SIEHT.
--
-- Erst waren es zwei Striche von je einem Pixel. Auf einem Talentsymbol,
-- das selbst schon eine goldene Fassung traegt, verschwinden die - auf
-- dem Bildschirm war kaum zu erkennen, welcher Knoten gemeint ist. Drei
-- Pixel und eine leichte Einfaerbung der Flaeche beantworten die Frage
-- aus zwei Metern Abstand, ohne das Symbol zuzudecken.
local RAND = 3
local TOENUNG = 0.22

local function marker(i)
    if markers[i] then return markers[i] end
    local m = CreateFrame("Frame", nil, UIParent)
    -- UEBER DEM BAUM, ABER UNTER UNSEREN EIGENEN FENSTERN.
    --
    -- Auf DIALOG lagen die Rahmen ueber allem - auch ueber der
    -- Buildliste. Knoten, die hinter ihr liegen, bekamen dann ein
    -- gruenes Kaestchen auf das Fenster gemalt, waehrend ihr Symbol
    -- darunter verborgen blieb: es sah aus, als schwebten Kaestchen im
    -- Leeren. Sie gehoeren zum Knopf, also knapp ueber ihn - und die
    -- Liste darueber.
    m:SetFrameStrata("HIGH")

    -- Die Flaeche zuerst, damit die Striche darueber liegen.
    m.tint = m:CreateTexture(nil, "BACKGROUND")
    m.tint:SetTexture(WHITE)
    m.tint:SetAllPoints(m)

    m.lines = {}
    local dicke = S:Pixel(RAND)
    local function strich(p1, p2, waagrecht)
        local t = m:CreateTexture(nil, "OVERLAY")
        t:SetTexture(WHITE)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if waagrecht then t:SetHeight(dicke) else t:SetWidth(dicke) end
        m.lines[#m.lines + 1] = t
        return t
    end
    strich("TOPLEFT", "TOPRIGHT", true)
    strich("BOTTOMLEFT", "BOTTOMRIGHT", true)
    strich("TOPLEFT", "BOTTOMLEFT", false)
    strich("TOPRIGHT", "BOTTOMRIGHT", false)

    m:Hide()
    markers[i] = m
    return m
end

---@param m table
---@param token string
local function recolor(m, token)
    local r, g, b = S:Color(token)
    for _, texture in ipairs(m.lines) do texture:SetVertexColor(r, g, b, 1) end
    m.tint:SetVertexColor(r, g, b, TOENUNG)
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
---@return table fehlt   { { spell, why, hero } } - was keinen Rahmen bekam
---  why ist "node" (gar nicht in diesem Baum), "hero" (gehoert zu einem
---  anderen Held-Baum, dessen Name dann in hero steht) oder "hidden"
---  (Knoten da, aber nicht gezeichnet).
function Tree.Show(spells)
    Tree.Hide()
    local fehlt = {}
    if type(spells) ~= "table" or #spells == 0 then return 0, 0, fehlt end
    local map = Tree.Map()
    local tab = tabFrame()
    if not (map and tab and tab.GetTalentButtonByNodeID) then return 0, 0, fehlt end

    local worn = Tree.Worn()
    local wanted = {}
    for _, spell in ipairs(spells) do
        local id = tonumber(spell) or tonumber(spell and spell.spell)
        if id then wanted[id] = true end
    end

    local plus, minus = 0, 0

    ---Warum dieses Talent keinen Rahmen bekommt.
    ---
    ---DREI GRUENDE, UND SIE BEDEUTEN VERSCHIEDENES. "Gar nicht in diesem
    ---Baum" heisst meist ein PvP-Talent. "Gehoert zu einem anderen
    ---Held-Baum" ist die wichtigste Auskunft von allen: dieser Build
    ---spielt nicht den, den du gewaehlt hast - das sieht man dem Baum
    ---nicht an, weil der andere gar nicht gezeichnet wird. "Knoten da,
    ---nicht gezeichnet" bleibt als ehrliches Uebrig.
    ---@param spell number
    ---@param nodeID number|nil
    local function warum(spell, nodeID)
        if not nodeID then
            fehlt[#fehlt + 1] = { spell = spell, why = "node" }
            return
        end
        local sub = subTreeOf(nodeID)
        if sub then
            local name, aktiv = subTreeInfo(sub)
            if not aktiv then
                fehlt[#fehlt + 1] = { spell = spell, why = "hero", hero = name }
                return
            end
        end
        fehlt[#fehlt + 1] = { spell = spell, why = "hidden" }
    end

    ---@param spell number
    ---@param token string
    local function mark(spell, token)
        local nodeID = Tree.NodeFor(spell)
        local button = nodeID and select(2, pcall(tab.GetTalentButtonByNodeID, tab, nodeID))
        -- EIN NICHT GEFUNDENES TALENT WIRD GEZAEHLT, NICHT VERSCHWIEGEN.
        -- Von 282 Knoten tragen nur die des gewaehlten Held-Baums und
        -- der eigenen Spec einen gezeichneten Rahmen. Eine Vorschau, die
        -- stillschweigend drei Talente auslaesst, ist schlimmer als
        -- eine, die sagt, dass sie es tut.
        --
        -- UND SICHTBAR MUSS ER SEIN, nicht nur vorhanden. Es gibt den
        -- Knopf auch fuer die nicht gewaehlten Held-Baeume: er
        -- existiert, hat eine Position und ist versteckt. Nur auf
        -- GetLeft geprueft, standen gruene und rote Kaestchen im leeren
        -- Raum, alle auf derselben Hoehe - die Knoepfe, die nie
        -- platziert wurden. IsVisible zaehlt auch die Eltern mit, und
        -- genau daran haengt es: der Knopf ist gezeigt, seine Leiste
        -- nicht.
        if not (button and button.IsVisible and button:IsVisible()
            and button.GetLeft and tonumber(button:GetLeft())) then
            warum(spell, nodeID)
            return false
        end
        used = used + 1
        local m = marker(used)
        m:ClearAllPoints()
        m:SetPoint("TOPLEFT", button, "TOPLEFT", -RAND, RAND)
        m:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", RAND, -RAND)
        -- Knapp ueber dem Knopf, zu dem er gehoert. Eine feste Zahl waere
        -- geraten; die des Knopfes plus zwei ist gemessen.
        local ebene = tonumber(button.GetFrameLevel and button:GetFrameLevel())
        if ebene then m:SetFrameLevel(ebene + 2) end
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
