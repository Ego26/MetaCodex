-- Aufrufe, die je nach Client anders heissen oder fehlen duerfen.
--
-- Jeder Griff nach aussen steht hier einmal und wird einmal abgesichert.
-- Im uebrigen Quelltext soll kein `or` stehen, das eine API-Umbenennung
-- abfaengt - sonst sucht man sie beim naechsten Patch an neun Stellen.

local _, ns = ...

local Compat = {}
ns.Compat = Compat

---Die aktive Spezialisierung als ID, oder nil ausserhalb jeder Spec.
---@return number|nil specID
---@return string|nil name
function Compat.CurrentSpec()
    local index
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        index = C_SpecializationInfo.GetSpecialization()
    elseif GetSpecialization then
        index = GetSpecialization()
    end
    if not index then return nil, nil end

    local info = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
    local id, name
    if info then
        id, name = info(index)
    elseif GetSpecializationInfo then
        id, name = GetSpecializationInfo(index)
    end
    return id, name
end

-- LE_UNIT_STAT_*, wie GetSpecializationInfo das Hauptattribut als letzten
-- Rueckgabewert fuehrt. Stamina steht mit drin, weil die Aufzaehlung sie
-- enthaelt - als Hauptattribut kommt sie nicht vor.
local STAT_BY_INDEX = { [1] = "str", [2] = "agi", [4] = "int" }

---Das Hauptattribut einer Spezialisierung.
---
---HIER STAND EINMAL `UnitStat`, und das war ein Fehler: seit 12.1 liefert
---der Aufruf "secret numbers". Wer sie vergleicht, faengt sich einen
---Laufzeitfehler ein -
---
---    attempt to compare local 'str' (a secret number value,
---    while execution tainted by 'MetaCodex')
---
---und das Fenster geht gar nicht mehr auf. Blizzards Taint-Schutz
---verhindert, dass Addons aus Charakterwerten Entscheidungen ableiten.
---
---Gefragt wird deshalb die Spezialisierung selbst. Das ist ohnehin die
---bessere Quelle: sie gilt auch fuer eine fremde Spec, fuer die der eigene
---Charakter gar nichts aussagt.
---
---Der Rueckfall ist "primary" und kein geratenes Attribut. Die
---Brustverzauberung fuer alle drei Attribute traegt genau diesen Kennwert,
---also fuehrt der Rueckfall zu einem richtigen Eintrag statt zu einem
---falschen.
---@param specID number|nil nil nimmt die aktive Spezialisierung
---@return string stat "agi", "str", "int" oder "primary"
---@return string source "api" oder "fallback"
function Compat.SpecPrimaryStat(specID)
    local wanted = specID or Compat.CurrentSpec()
    if not wanted then return "primary", "fallback" end

    local byID = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID)
        or GetSpecializationInfoByID
    if byID then
        local ok, _, _, _, _, _, primary = pcall(byID, wanted)
        if ok and STAT_BY_INDEX[primary] then return STAT_BY_INDEX[primary], "api" end
    end
    return "primary", "fallback"
end

---Das Hauptattribut der aktiven Spezialisierung.
---@return string
function Compat.PrimaryStat()
    return (Compat.SpecPrimaryStat(nil))
end

---Die Klasse des Charakters.
---@return number|nil classID
function Compat.PlayerClassID()
    local _, _, classID = UnitClass("player")
    return classID
end

---Alle Klassen, nach Namen sortiert.
---
---`file` ist der englische Klassenschluessel ("WARLOCK"), ueber den die
---Klassenfarbe nachgeschlagen wird. Ohne ihn saehe das Auswahlmenue aus
---wie eine Liste, und nicht wie WoW.
---@return table[] { { id, name, file }, ... }
function Compat.Classes()
    local out = {}
    local info = C_CreatureInfo and C_CreatureInfo.GetClassInfo
    if not info then return out end
    for id = 1, 20 do
        local ok, entry = pcall(info, id)
        if ok and entry and entry.className then
            out[#out + 1] = { id = id, name = entry.className, file = entry.classFile }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

---Die Klassenfarbe als Farbcode fuer Text, ohne fuehrendes |c.
---@param classFile string|nil
---@return string
function Compat.ClassColor(classFile)
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not color then return "ffffff" end
    local function byte(value) return math.floor(value * 255 + 0.5) end
    return ("%02x%02x%02x"):format(byte(color.r), byte(color.g), byte(color.b))
end

---Die Klasse, zu der eine Spezialisierung gehoert.
---@param specID number|nil
---@return number|nil classID
---@return string|nil classFile
function Compat.ClassOfSpec(specID)
    if not specID then return nil end
    for _, entry in ipairs(Compat.Classes()) do
        for _, spec in ipairs(Compat.SpecsForClass(entry.id)) do
            if spec.id == specID then return entry.id, entry.file end
        end
    end
    return nil
end

---Die Spezialisierungen einer Klasse, in der Reihenfolge des Spiels.
---@param classID number
---@return table[] { { id, name, icon }, ... }
function Compat.SpecsForClass(classID)
    local out = {}
    local get = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID)
        or GetSpecializationInfoForClassID
    if not get or not classID then return out end
    for index = 1, 5 do
        local ok, id, name, _, icon = pcall(get, classID, index)
        if not ok or not id then break end
        out[#out + 1] = { id = id, name = name, icon = icon }
    end
    return out
end

---Name einer Spezialisierung, egal ob eigene oder fremde.
---@param specID number|nil
---@return string|nil
function Compat.SpecName(specID)
    if not specID then return nil end
    local activeID, activeName = Compat.CurrentSpec()
    if specID == activeID then return activeName end

    local get = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID)
        or GetSpecializationInfoByID
    if get then
        local ok, _, name = pcall(get, specID)
        if ok and name then return name end
    end
    return nil
end

---Wie viele Stueck eines Gegenstands der Charakter erreichen kann:
---Taschen, Bank, Reagenzienbank und Kriegsmeutenbank.
---
---Die Kriegsmeutenbank zaehlt nur mit, wenn der Client sie kennt UND ihren
---Inhalt schon gesehen hat. Ein zu niedriger Wert setzt hier zu viel auf die
---Liste - das ist die harmlosere Richtung als ein zu hoher.
---@param itemID number
---@return number
function Compat.ItemCount(itemID)
    local get = C_Item and C_Item.GetItemCount or GetItemCount
    if not get then return 0 end
    local ok, count = pcall(get, itemID, true, false, true, true)
    if ok and type(count) == "number" then return count end
    ok, count = pcall(get, itemID, true)
    return (ok and type(count) == "number") and count or 0
end

---Ob der Client seine Taschen schon kennt.
---
---Nach einem Ladebildschirm steht das Bild, bevor der Server die Beutel
---geschickt hat. GetItemCount antwortet dann ueberall null, ohne zu
---sagen, dass es nur noch nichts weiss - und eine Erinnerung meldet
---"nichts in der Tasche", waehrend das Fläschchen im Beutel liegt.
---Der Rucksack hat immer Plaetze; meldet er keine, ist noch nichts da.
---@return boolean
function Compat.BagsKnown()
    local slots = C_Container and C_Container.GetContainerNumSlots
        or GetContainerNumSlots
    -- Gewartet wird nur auf einen klaren Befund.
    --
    -- Antwortet dieser Client auf die Frage nicht - weil er sie nicht
    -- kennt oder etwas anderes zurueckgibt - dann gilt "bekannt". Auf
    -- Unwissen zu warten hiesse, gar nicht mehr zu erinnern.
    if type(slots) ~= "function" then return true end
    local ok, n = pcall(slots, 0)
    if not ok or type(n) ~= "number" then return true end
    return n > 0
end

---Name, Link und Symbol eines Gegenstands - oder nil, solange der Client
---die Daten noch nicht hat.
---@param itemID number
---@return string|nil name
---@return string|nil link
---@return number|nil icon
function Compat.ItemInfo(itemID)
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not get then return nil end
    local name, link, _, _, _, _, _, _, _, icon = get(itemID)
    return name, link, icon
end

---Was der Spieler gerade traegt, als Menge von Gegenstands-IDs.
---Ueber den Link, nicht ueber GetInventoryItemID: der Link ist ueberall
---da, wo auch die Ausruestung gelesen wird, und braucht keinen zweiten
---Weg fuer denselben Platz.
---@return table<number, boolean>
function Compat.EquippedIDs()
    local worn = {}
    for inv = 1, 19 do
        local link = GetInventoryItemLink("player", inv)
        local id = link and tonumber(link:match("item:(%d+)"))
        if id then worn[id] = true end
    end
    return worn
end

---Bittet den Client, die Daten eines Gegenstands nachzuladen.
---@param itemID number
function Compat.RequestItem(itemID)
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

---Die Werte eines Gegenstands anhand seines Links.
---@param link string
---@return table|nil
function Compat.ItemStats(link)
    local get = C_Item and C_Item.GetItemStats or GetItemStats
    if not get then return nil end
    local ok, stats = pcall(get, link)
    return ok and stats or nil
end

-- Die Kampfwertungs-Indizes. Namen statt Zahlen, weil eine 11 im
-- Quelltext nichts erzaehlt.
--
-- Nahkampf- und Zauberwertung sind seit Jahren dieselbe Zahl; genommen
-- wird die Nahkampfvariante, weil sie fuer jede Klasse gefuellt ist.
local RATING_INDEX = {
    crit = CR_CRIT_MELEE or 11,
    haste = CR_HASTE_MELEE or 18,
    -- Meisterschaft hat eine eigene Wertung wie alle anderen.
    --
    -- Hier stand GetMasteryEffect, und das war falsch: die Funktion gibt
    -- den PROZENTWERT zurueck, nicht die Wertung. Im Fenster stand
    -- daraufhin "du hast 1, es fehlen 1014" - eine Zahl, die niemand
    -- glaubt, und zu Recht.
    mastery = CR_MASTERY or 26,
    vers = CR_VERSATILITY_DAMAGE_DONE or 29,
}

---Die eigene Kampfwertung.
---
---NICHT ueber UnitStat: das liefert seit 12.1 geheime Zahlen, die sich
---nicht vergleichen lassen, und genau daran ist das Fenster einmal beim
---Oeffnen gestorben. GetCombatRating gibt eine gewoehnliche Zahl.
---
---Meisterschaft ist der Sonderfall: sie hat keine eigene Wertung in
---dieser Tabelle, sondern eine eigene Abfrage.
---@param key string "crit" | "haste" | "mastery" | "vers"
---@return number|nil rating
function Compat.OwnRating(key)
    local index = RATING_INDEX[key]
    if not index or not GetCombatRating then return nil end
    local ok, value = pcall(GetCombatRating, index)
    if ok and type(value) == "number" then return math.floor(value) end
    return nil
end

---Begegnung und Instanz als Text, in der Sprache des Clients.
---
---Das Abenteuerjournal braucht keinen geladenen Zustand fuer diese beiden
---Abfragen - sie beantworten sich aus den Clientdaten. Sollte eine doch
---einmal nichts liefern, faellt die Zeile stillschweigend weg, statt
---"Unbekannt" zu behaupten.
---@param encounterID number|nil
---@param instanceID number|nil
---@return string|nil
---Der Name einer Begegnung, wie der Client sie nennt.
---
---Warcraft Logs liefert "Nek'zali the Soulcoiler"; im deutschen Spiel
---heisst er anders, und im franzoesischen wieder anders. Die Nummer
---wandert mit den Daten, der Name kommt von hier.
---@param encounterID number|nil
---@return string|nil
function Compat.EncounterName(encounterID)
    if not encounterID or not EJ_GetEncounterInfo then return nil end
    local ok, name = pcall(EJ_GetEncounterInfo, encounterID)
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end

---Der Name einer Instanz, wie der Client sie nennt.
---@param instanceID number|nil
---@return string|nil
function Compat.InstanceName(instanceID)
    if not instanceID or not EJ_GetInstanceInfo then return nil end
    local ok, name = pcall(EJ_GetInstanceInfo, instanceID)
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end

function Compat.DropText(encounterID, instanceID)
    local boss, place
    if encounterID and EJ_GetEncounterInfo then
        local ok, name = pcall(EJ_GetEncounterInfo, encounterID)
        if ok and type(name) == "string" and name ~= "" then boss = name end
    end
    if instanceID and EJ_GetInstanceInfo then
        local ok, name = pcall(EJ_GetInstanceInfo, instanceID)
        if ok and type(name) == "string" and name ~= "" then place = name end
    end
    if boss and place then return boss .. ", " .. place end
    return boss or place
end

---Ein Datumsstempel als Datum.
---
---Die Sammler schreiben 20260923, weil sich das sortieren laesst. Im
---Fenster stand genau das: eine achtstellige Zahl, die niemand als Datum
---liest. Umgerechnet wird erst hier - der Stempel bleibt eine Zahl, die
---man vergleichen kann.
---@param stamp number|nil
---@return string
function Compat.DateText(stamp)
    stamp = tonumber(stamp) or 0
    if stamp < 10000101 then return "?" end
    local year = math.floor(stamp / 10000)
    local month = math.floor(stamp / 100) % 100
    local day = stamp % 100
    -- Der Client weiss, wie herum sein Land das Datum schreibt.
    local format = (GetLocale and GetLocale() == "enUS") and "%d/%d/%d"
        or "%02d.%02d.%d"
    if format == "%d/%d/%d" then
        return format:format(month, day, year)
    end
    return format:format(day, month, year)
end

---Was ein Schluesselstein abwirft.
---
---Die Tabelle steht nicht in diesem Addon und soll es auch nicht: sie
---aendert sich mit jeder Saison, und eine abgeschriebene waere beim
---naechsten Patch still falsch. Der Client kennt sie.
---
---Die Reihenfolge der beiden Rueckgabewerte ist zwischen den Versionen
---nicht verlaesslich dokumentiert. Statt sie zu raten, wird die
---EIGENSCHAFT benutzt, die immer gilt: die Truhe gibt nie weniger als
---der Dungeon.
---@param keyLevel number
---@return number|nil endOfRun, number|nil vault
function Compat.RewardLevels(keyLevel)
    if not C_MythicPlus or not C_MythicPlus.GetRewardLevelForDifficultyLevel then
        return nil
    end
    local ok, a, b = pcall(C_MythicPlus.GetRewardLevelForDifficultyLevel, keyLevel)
    if not ok then return nil end
    -- Eine Null ist keine Stufe.
    --
    -- Mein Trick "der kleinere ist der Dungeon" ging genau hier schief:
    -- gibt der Client fuer einen Wert 0 zurueck, war das Minimum 0, und
    -- im Fenster stand "+2 -> 0 - Tresor 305".
    a, b = tonumber(a), tonumber(b)
    if (a or 0) <= 0 then a = nil end
    if (b or 0) <= 0 then b = nil end
    if not a and not b then return nil end
    if not b then return a, a end
    if not a then return b, b end
    return math.min(a, b), math.max(a, b)
end

---Die Schluesselstufen, die der Client kennt.
---
---Abgefragt statt aufgezaehlt: wo die Saison anfaengt und aufhoert, weiss
---das Spiel. Eine feste Liste von 2 bis 20 waere naechste Saison falsch.
---@return table[] { key, endOfRun, vault }
function Compat.RewardTable()
    local out = {}
    for level = 2, 30 do
        local endOfRun, vault = Compat.RewardLevels(level)
        if endOfRun then
            out[#out + 1] = { key = level, endOfRun = endOfRun, vault = vault }
        end
    end
    return out
end

---Dieselben Stufen, aber nach GEGENSTANDSSTUFE zusammengefasst.
---
---Hier stand vorher ein Abbruch, sobald zwei Schluessel dasselbe gaben -
---und weil +2 und +3 dasselbe geben, blieb genau EIN Eintrag uebrig. Das
---war der Grund, warum das Untermenue leer aussah.
---
---Richtig ist das Gegenteil: mehrere Schluessel, die dieselbe Stufe
---geben, gehoeren in EINE Zeile. Genau so zeigt es KeystoneLoot -
---"295 (+2 +3)" statt zweimal 295.
---@param which string "endOfRun" oder "vault"
---@return table[] { level, keys = {..}, label }
function Compat.RewardSteps(which)
    local byLevel, order = {}, {}
    for _, row in ipairs(Compat.RewardTable()) do
        local level = row[which]
        if level and level > 0 then
            if not byLevel[level] then
                byLevel[level] = { level = level, keys = {} }
                order[#order + 1] = byLevel[level]
            end
            local keys = byLevel[level].keys
            keys[#keys + 1] = row.key
        end
    end
    table.sort(order, function(a, b) return a.level < b.level end)
    for _, step in ipairs(order) do
        -- "+2 +3" statt "+2, +3, +4, +5": bei mehr als zweien wird aus
        -- der Aufzaehlung eine Spanne.
        local keys = step.keys
        if #keys <= 2 then
            local parts = {}
            for _, k in ipairs(keys) do parts[#parts + 1] = "+" .. k end
            step.label = table.concat(parts, " ")
        else
            step.label = ("+%d-%d"):format(keys[1], keys[#keys])
        end
    end
    return order
end

---Ein Link mit genau einer Bonus-ID.
---@param itemID number
---@param bonus number
---@return string
local function trackLink(itemID, bonus)
    return ("item:%d::::::::::::1:%d"):format(itemID, bonus)
end

---Welche Pfade zur laufenden Saison gehoeren.
---
---Der Katalog fuehrt alle - auch die der letzten Saison und die der
---naechsten, die in den Spieldaten schon bereitliegt. Die laufende ist
---die, deren Stufen die Schluesselbelohnungen treffen: ein +2 gibt
---Champion irgendwas, und der Champion-Pfad, der diese Stufe hat, ist
---der richtige. Einmal am Probegegenstand gerechnet, dann gemerkt.
---@param probe number ein Gegenstand, den der Client schon kennt
---@return table<number, boolean>|nil  Index in Catalog.Tracks() -> wahr
local seasonTracks
function Compat.SeasonTracks(probe)
    if seasonTracks then return seasonTracks end
    local tracks = ns.Catalog.Tracks and ns.Catalog.Tracks()
    local read = C_Item and C_Item.GetDetailedItemLevelInfo
    if not tracks or not probe or not read then return nil end
    if not (C_Item.GetItemInfo and C_Item.GetItemInfo(probe)) then return nil end
    local wanted = {}
    for _, row in ipairs(Compat.RewardTable()) do
        if row.endOfRun and row.endOfRun > 0 then wanted[row.endOfRun] = true end
        if row.vault and row.vault > 0 then wanted[row.vault] = true end
    end
    if not next(wanted) then return nil end
    local out, any = {}, false
    for t, track in ipairs(tracks) do
        for _, bonus in ipairs(track.lists or {}) do
            local ok, got = pcall(read, trackLink(probe, bonus))
            if ok and got and wanted[got] then out[t] = true; any = true; break end
        end
    end
    if any then seasonTracks = out end
    return any and out or nil
end

---Pfad und Rang, die einen Gegenstand auf eine Stufe bringen.
---
---Der Client rechnet. Jede Pfad-Bonus-ID wird an den Gegenstand
---gehaengt und die Stufe abgefragt; genommen wird der NIEDRIGSTE Rang,
---der die Stufe erreicht. 305 gibt es als Champion 5 und als Held 1 -
---und ein +6-Schluessel gibt Held 1. So steht es dann auch im Tooltip.
---
---Warum kein fester Tabellenwert: die Stufen je Rang wechseln mit der
---Saison, und der Client weiss sie immer. Gefragt wird pro Gegenstand,
---nicht pro Pfad, damit ein Gegenstand, der aus der Reihe faellt, das
---auch darf.
---@param level number
---@param itemID number ein Gegenstand, den der Client schon kennt
---@return table|nil { bonus, track, rank, level }
function Compat.TrackFor(level, itemID)
    if not level or not itemID then return nil end
    local tracks = ns.Catalog.Tracks and ns.Catalog.Tracks()
    if not tracks or #tracks == 0 then return nil end
    local read = C_Item and C_Item.GetDetailedItemLevelInfo
    if not read then return nil end
    -- Nur die laufende Saison. Ohne den Filter gewann fuer eine Stufe
    -- der Rang 1 eines Pfads der NAECHSTEN Saison gegen den Rang 5
    -- dieser - und im Tooltip stand ein Pfad, den es noch gar nicht gibt.
    local season = Compat.SeasonTracks(ns.Catalog.ProbeItem and ns.Catalog.ProbeItem() or itemID)
    local best
    for t, track in ipairs(tracks) do
        -- Kein "bedingung and pcall(...)": das schneidet die Rueckgabe auf
        -- EINEN Wert, und der zweite - die Stufe - war dann immer nil.
        if not season or season[t] then
            for rank, bonus in ipairs(track.lists or {}) do
                local ok, got = pcall(read, trackLink(itemID, bonus))
                if ok and got == level then
                    -- Gleicher Rang auf zwei Pfaden: der hoehere Pfad, denn
                    -- der ist es, den der Schluessel wirklich gibt.
                    if not best or rank < best.rank
                        or (rank == best.rank and t > best.track) then
                        best = { bonus = bonus, track = t, rank = rank, level = level }
                    end
                end
            end
        end
    end
    return best
end

---Der Name eines Pfads in der Sprache des Fensters.
---@param track number Index in Catalog.Tracks()
---@return string
function Compat.TrackName(track)
    local tracks = ns.Catalog.Tracks and ns.Catalog.Tracks()
    local row = tracks and tracks[track]
    if not row then return "?" end
    return (ns.L and ns.L["TRACK_" .. tostring(row.name)]) or tostring(row.name)
end

---Ein Gegenstandslink auf einer bestimmten Stufe.
---
---Der Client rechnet Stufe und Werte selbst aus, wenn die passende
---Bonus-ID am Link haengt. Ohne sie zeigt das Tooltip die GRUNDstufe -
---bei einem Saisongegenstand waren das "Stufe 28" unter einer Zeile, die
---334 sagte.
---@param itemID number
---@param level number Zielstufe
---@return string|nil link
function Compat.LinkAtLevel(itemID, level)
    if not itemID or not level then return nil end
    local info = C_Item and C_Item.GetItemInfo and { pcall(C_Item.GetItemInfo, itemID) }
    -- GetItemInfo gibt die Grundstufe an vierter Stelle (nach dem
    -- pcall-Erfolg also an fuenfter).
    local base = info and info[1] and tonumber(info[5]) or nil
    if not base or base <= 0 then return nil end

    -- Erst der Aufwertungspfad, dann die Differenz.
    --
    -- Beides bringt den Client auf die richtige Stufe. Aber nur der
    -- Pfad laesst ihn "Held 3/6" ins Tooltip schreiben - er kennt den
    -- Pfad, er kennt den Rang, er schreibt beides hin. Die Differenz
    -- setzt nur die Zahl. Das ist der ganze Unterschied zu KeystoneLoot,
    -- und er liegt nicht in einer Tabelle, sondern in der ART der
    -- Bonus-ID.
    local delta = level - base
    -- Die Grundstufe braucht keinen Bonus - und keinen Pfad.
    if delta == 0 then return "item:" .. itemID end

    local hit = Compat.TrackFor(level, itemID)
    if hit then return trackLink(itemID, hit.bonus) end

    local bonus = ns.Catalog.LevelDeltaBonus(delta)
    if not bonus then return nil end

    -- Die Felder eines Gegenstandslinks bis zur Anzahl der Bonus-IDs.
    -- Dreizehn leere, dann die Zahl, dann die IDs selbst.
    return ("item:%d::::::::::::1:%d"):format(itemID, bonus)
end
