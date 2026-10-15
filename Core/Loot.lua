local _, ns = ...

---Die ganze Beute einer Instanz fuer eine Spec - aus dem Abenteuerjournal.
---
---Die Fundorte zeigten nur, was die Besten tragen. Gewuenscht am 15.
---Oktober: wie Keystone Loot JEDEN Drop eines Dungeons fuer die eigene
---Spec, damit man sich selbst aussuchen kann, was man haben will. Die
---Liste muss niemand sammeln - das Journal fuehrt sie und filtert sie
---nach Klasse und Spec genau so, wie es im Spiel im Reiter "Beute"
---steht.
---
---DAS JOURNAL IST GETEILT. Instanz, Schwierigkeit und Filter, die hier
---gesetzt werden, sind dieselben, die Blizzards Fenster benutzt. Darum:
---nicht fragen, solange das Journal offen ist, und hinterher alles
---zuruecksetzen, was sich zuruecksetzen laesst.
---
---UND ES ANTWORTET NICHT SOFORT. Gegenstaende, die der Client noch
---nicht kennt, kommen ohne Namen und spaeter mit dem Ereignis
---EJ_LOOT_DATA_RECIEVED (so geschrieben). Unvollstaendiges wird darum
---nicht behalten, sondern beim naechsten Ereignis neu gefragt - aber
---nicht endlos.
local Loot = {}
ns.Loot = Loot

-- [specID][inst] = { items = { {id, enc, filter}, ... }, complete = bool }
local cache = {}
local versuche = {}
local VERSUCHE = 3
local wache

-- Die Liste ist auf allen Schwierigkeiten dieselbe; gefragt wird die,
-- die es fuer die Instanz gibt, die hoechste zuerst. 8 ist der
-- Schluesselstein, 23 mythisch, 16/15/14 die Schlachtzugsstufen.
local STUFEN = {
    dungeon = { 8, 23, 2, 1 },
    raid = { 16, 15, 14, 17 },
}

local function api()
    local C = _G.C_EncounterJournal
    return type(_G.EJ_SelectInstance) == "function"
        and type(_G.EJ_SetLootFilter) == "function"
        and type(_G.EJ_GetNumLoot) == "function"
        and type(C) == "table" and type(C.GetLootInfoByIndex) == "function"
end

-- rawget: die Attrappe der Tests gibt auf jedes Feld ein Kind zurueck.
local function journalOffen()
    local ej = rawget(_G, "EncounterJournal")
    return type(ej) == "table" and type(ej.IsShown) == "function" and ej:IsShown() and true or false
end

---Kommt nachgeliefert, was fehlte, wird es neu gefragt.
local function wachen()
    if wache or type(CreateFrame) ~= "function" then return end
    wache = CreateFrame("Frame")
    wache:RegisterEvent("EJ_LOOT_DATA_RECIEVED")
    wache:SetScript("OnEvent", function()
        if wache.__bald then return end
        wache.__bald = true
        local function los()
            wache.__bald = false
            local weg = false
            for _, jeSpec in pairs(cache) do
                for inst, eintrag in pairs(jeSpec) do
                    if not eintrag.complete then jeSpec[inst] = nil; weg = true end
                end
            end
            if weg and ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        end
        -- Die Ereignisse kommen in Schueben; einmal danach genuegt.
        if C_Timer and C_Timer.After then C_Timer.After(0.5, los) else los() end
    end)
end

local function frage(inst, art, classID, specID)
    local C = C_EncounterJournal
    local alteKlasse, alteSpec
    if type(EJ_GetLootFilter) == "function" then alteKlasse, alteSpec = EJ_GetLootFilter() end
    local alterPlatz = type(C.GetSlotFilter) == "function" and C.GetSlotFilter() or nil
    local alteStufe = type(EJ_GetDifficulty) == "function" and EJ_GetDifficulty() or nil

    local items, vollstaendig = {}, true
    local ok = pcall(function()
        EJ_SelectInstance(inst)
        for _, stufe in ipairs(STUFEN[art] or STUFEN.dungeon) do
            if type(EJ_IsValidInstanceDifficulty) ~= "function" or EJ_IsValidInstanceDifficulty(stufe) then
                if type(EJ_SetDifficulty) == "function" then EJ_SetDifficulty(stufe) end
                break
            end
        end
        EJ_SetLootFilter(classID, specID)
        local alle = Enum and Enum.ItemSlotFilterType and Enum.ItemSlotFilterType.NoFilter
        if alle and type(C.SetSlotFilter) == "function" then C.SetSlotFilter(alle) end
        for i = 1, tonumber(EJ_GetNumLoot()) or 0 do
            local info = C.GetLootInfoByIndex(i)
            if type(info) == "table" and tonumber(info.itemID) then
                items[#items + 1] = {
                    id = tonumber(info.itemID),
                    enc = tonumber(info.encounterID),
                    filter = info.filterType,
                }
                if not info.name then vollstaendig = false end
            else
                vollstaendig = false
            end
        end
    end)
    -- Zuruecklegen, was Blizzards Fenster gehoert.
    pcall(function()
        if alteKlasse then EJ_SetLootFilter(alteKlasse, alteSpec or 0) end
        if alterPlatz and type(C.SetSlotFilter) == "function" then C.SetSlotFilter(alterPlatz) end
        if alteStufe and type(EJ_SetDifficulty) == "function" then EJ_SetDifficulty(alteStufe) end
    end)
    if not ok then return nil end
    return items, vollstaendig
end

---Alle Drops einer Instanz fuer eine Spec.
---@param inst number Journal-Instanz
---@param specID number
---@return table[]|nil items  { id, enc, filter } - nil, wenn das Journal nicht antwortet
---@return boolean|nil complete
function Loot.Items(inst, specID)
    if not inst or not specID or not api() then return nil end
    local jeSpec = cache[specID]
    if not jeSpec then jeSpec = {}; cache[specID] = jeSpec end
    local da = jeSpec[inst]
    if da then return da.items, da.complete end
    if journalOffen() then return nil end
    local classID = ns.Compat.ClassOfSpec and ns.Compat.ClassOfSpec(specID)
    if type(classID) ~= "number" then return nil end
    local art = ns.Catalog.InstanceKind(inst) or "dungeon"
    wachen()
    local items, vollstaendig = frage(inst, art, classID, specID)
    if not items then return nil end
    local schluessel = specID .. ":" .. inst
    versuche[schluessel] = (versuche[schluessel] or 0) + 1
    da = { items = items, complete = vollstaendig or versuche[schluessel] >= VERSUCHE }
    jeSpec[inst] = da
    return items, da.complete
end

---Vergisst alles - fuer die Pruefung und nach einem Patch.
function Loot.Reset()
    cache, versuche = {}, {}
end
