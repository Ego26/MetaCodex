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

    -- Erst die Spieldaten, dann der Client.
    --
    -- Seit 12.1 kommt aus GetSpecializationInfoByID an dieser Stelle
    -- nichts Brauchbares mehr zurueck, und im Fenster stand
    -- "Hauptattribut" statt "Intelligenz" - mit Folgen fuer die Steine,
    -- die am Hauptattribut haengen. Der Katalog traegt es aus
    -- ChrSpecialization mit, fuer alle vierzig Speccs.
    local fromCatalog = ns.Catalog and ns.Catalog.SpecStat and ns.Catalog.SpecStat(wanted)
    if fromCatalog then return fromCatalog, "catalog" end

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

---Bringt diese Spec ihren Waffenbuff selbst mit?
---
---Der Schamane legt Flammenzunge oder Windfury auf die Waffe, der
---Schurke seine Gifte - und beides belegt denselben Platz wie ein Oel.
---Wer den einen hat, kann den anderen nicht haben, also ist die Frage
---"wie viele Oele willst du" fuer ihn unbeantwortbar. Genau wie die
---Waffenverzauberung beim Todesritter: sie wird nicht gestellt.
---@param specID number|nil
---@return boolean
function Compat.SelfWeaponBuff(specID)
    if not specID then return false end
    local _, classFile = Compat.ClassOfSpec(specID)
    return classFile ~= nil and ns.SELF_WEAPON_BUFF[classFile] == true
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

-- Welche Unterklasse eines Verbrauchsguts welche Art ist. Dieselbe
-- Zuordnung wie im Katalog, nur hier am lebenden Gegenstand: 8 ist die
-- Sammelklasse fuer Runen, Oele und Schleifsteine.
local CONSUM_SUBCLASS = {
    [1] = "potion", [3] = "flask", [5] = "food", [8] = "other", [9] = "vantus",
}

---Was fuer ein Verbrauchsgut das ist - gefragt beim Client.
---
---Der Katalog kennt nur die laufende Erweiterung. Wer eine Rune von
---vorletztem Jahr im Beutel hat, findet sie dort nicht - und stand
---deshalb nicht zur Wahl, obwohl sie im Beutel liegt. Der Client weiss
---es von jedem Gegenstand, auch vom aeltesten.
---@param itemID number|nil
---@return string|nil "potion" | "flask" | "food" | "other" | "vantus"
function Compat.ConsumableKind(itemID)
    if not itemID then return nil end
    local get = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if type(get) ~= "function" then return nil end
    -- GetItemInfoInstant gibt SIEBEN Werte zurueck, und die Klasse
    -- steht an sechster Stelle:
    --
    --   itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID
    --
    -- Ich hatte eine Stelle zu wenig gezaehlt und las das Symbol als
    -- Klasse. Im Spiel kam dabei nie ein Verbrauchsgut heraus.
    local ok, _, _, _, _, _, classID, subclassID = pcall(get, itemID)
    if not ok then return nil end
    -- Klasse 0 ist "Verbrauchbar". Alles andere ist kein Verbrauchsgut,
    -- egal was in der Unterklasse steht.
    if classID ~= 0 then return nil end
    return CONSUM_SUBCLASS[subclassID or -1]
end

---Was in den Taschen liegt: je Gegenstands-ID einmal.
---
---Gebraucht fuer "aus meinen Taschen waehlen". Gezaehlt wird nicht hier
---- die Menge sagt GetItemCount, und die kennt auch die Bank.
---@return number[] itemIDs
function Compat.BagItems()
    local slots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local itemAt = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    if type(slots) ~= "function" or type(itemAt) ~= "function" then return {} end
    local seen, out = {}, {}
    -- 0 ist der Rucksack, 1 bis 5 die angelegten Taschen. Mehr Taschen
    -- gibt es nicht, und die Bank ist nicht gemeint: waehlen kann man
    -- nur, was man dabeihat.
    for bag = 0, 5 do
        local ok, n = pcall(slots, bag)
        if ok and type(n) == "number" then
            for slot = 1, n do
                local fine, id = pcall(itemAt, bag, slot)
                if fine and type(id) == "number" and not seen[id] then
                    seen[id] = true
                    out[#out + 1] = id
                end
            end
        end
    end
    return out
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

---Wie ein Gegenstand bindet: 1 beim Aufheben, 2 beim Anlegen, 3 gar nicht.
---
---GEBRAUCHT FUER DIE FRAGE "muss ich das erfarmen?". Ein Stueck, das
---erst beim Anlegen bindet, faellt zwar irgendwo - aber man kann es
---auch einfach kaufen. Das Abenteuerjournal fuehrt solche Beute nicht
---je Boss (sie faellt von jedem), und darum stand sie bei uns unter
---"ohne bekannten Fundort" - eine Auskunft, die schlechter ist als
---die, die der Client bereithaelt.
---
---Nil heisst: der Client kennt den Gegenstand noch nicht. Nicht
---"bindet nicht".
---@param itemID number|nil
---@return number|nil
function Compat.BindType(itemID)
    if not itemID then return nil end
    local get = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not get then return nil end
    local ok, _, _, _, _, _, _, _, _, _, _, _, _, _, bind = pcall(get, itemID)
    if not ok then return nil end
    return type(bind) == "number" and bind or nil
end

-- Welcher Platz der Ausruestungsliste welchem Platz am Charakter
-- entspricht. ns.SLOTS deckt nur ab, was verzaubert wird - hier geht es
-- um alle.
local INV_OF_SLOT = {
    Head = { 1 }, Neck = { 2 }, Shoulders = { 3 }, Back = { 15 },
    Chest = { 5 }, Wrist = { 9 }, Hands = { 10 }, Waist = { 6 },
    Legs = { 7 }, Feet = { 8 }, Rings = { 11, 12 }, Trinkets = { 13, 14 },
    ["Main Hand"] = { 16 }, ["Off Hand"] = { 17 },
}

---Die Gegenstandsstufe, die auf jedem Platz wirklich am Koerper haengt.
---
---DIE NIEDRIGERE BEI ZWEIEN. Ringe und Schmuck traegt man doppelt; wer
---ein neues Stueck bekommt, ersetzt das schlechtere. An dem ist zu
---messen, ob sich etwas lohnt.
---
---Kennt der Client ein Stueck nicht, fehlt der Platz in der Antwort -
---und "weiss nicht" ist etwas anderes als "traegt nichts".
---@return table<string, number>
function Compat.WornLevels()
    local out = {}
    local read = C_Item and C_Item.GetDetailedItemLevelInfo
    if not read then return out end
    for slot, invs in pairs(INV_OF_SLOT) do
        for _, inv in ipairs(invs) do
            local link = GetInventoryItemLink("player", inv)
            if link then
                local ok, level = pcall(read, link)
                if ok and type(level) == "number" and level > 0 then
                    if not out[slot] or level < out[slot] then out[slot] = level end
                end
            end
        end
    end
    return out
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

---Die Handwerksqualitaet eines Gegenstands: 1 bis 5, oder nil.
---
---Zuerst der Client: er fuehrt sie am Gegenstand selbst, und was er
---sagt, gilt. Schweigt er - eine aeltere Fassung, ein Gegenstand ohne
---Stufen -, zaehlt der Katalog: er kennt die Stufen derselben Ware, und
---wie viele davon unter dieser liegen, ist ihre Nummer.
---@param itemID number|nil
---@return number|nil
function Compat.CraftQuality(itemID)
    if not itemID then return nil end
    if C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
        local ok, quality = pcall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, itemID)
        if ok and type(quality) == "number" and quality > 0 then return quality end
    end
    if ns.Catalog and ns.Catalog.Tiers then
        local lower, higher = ns.Catalog.Tiers(itemID)
        local unten, oben = #(lower or {}), #(higher or {})
        if unten + oben > 0 then return unten + 1 end
    end
    return nil
end

---Das Zeichen zu einer Qualitaetsstufe - der Name eines Atlas, oder nil.
---
---Blizzard fuehrt mehrere Saetze davon, und welcher in dieser Fassung
---des Spiels existiert, weiss nur der Client. Also wird er gefragt,
---statt einen Namen zu raten: ein Atlas, den es nicht gibt, zeichnet
---nichts, und niemand erfaehrt warum.
---@param quality number|nil
---@return string|nil
function Compat.QualityAtlas(quality)
    if type(quality) ~= "number" or quality < 1 or quality > 5 then return nil end
    local namen = {
        ("Professions-Icon-Quality-Tier%d-Small"):format(quality),
        ("Professions-ChatIcon-Quality-Tier%d"):format(quality),
        ("Professions-Icon-Quality-Tier%d"):format(quality),
    }
    if not (C_Texture and C_Texture.GetAtlasInfo) then return namen[2] end
    for _, name in ipairs(namen) do
        local ok, info = pcall(C_Texture.GetAtlasInfo, name)
        if ok and info then return name end
    end
    return nil
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

-- WAS EIN SCHLUESSEL AM DUNGEONENDE GIBT.
--
-- Diese Tabelle ist die einzige Zahlenreihe im Addon, die weder
-- gemessen noch aus den Spieldaten gelesen ist. Der Grund steht in den
-- Spieldaten selbst: MythicPlusSeasonRewardLevels fuehrt eine Spalte
-- EndOfRunRewardLevel, und Blizzard laesst sie diese Saison leer - alle
-- dreissig Zeilen null. Der Client antwortet deshalb nur mit dem
-- Tresorwert, und wer daraus eine Dungeonstufe macht, liegt zwei
-- Raenge zu hoch.
--
-- Gespeichert wird PFAD UND RANG, nicht die Stufe: die Stufe rechnet
-- der Client aus der Bonus-ID des Rangs, und damit bleibt sie richtig,
-- wenn Blizzard an den Stufen dreht.
--
-- NACHPRUEFBAR IM SPIEL: die Truhe am Ende eines +10 sagt selbst, dass
-- sie Held 3 gibt. Wer hier etwas aendert, kann es dort ansehen.
--
-- ZU PRUEFEN JEDE SAISON. Der Katalogbau meldet es, sobald die Spalte
-- wieder gefuellt ist; dann kann diese Tabelle weg.
---Der nackte Wert des Clients zu einer Schluesselstufe.
---
---OHNE JEDE EIGENE RECHNUNG, und das ist hier der Zweck: auf diesen
---Wert stuetzt sich die Frage "welche Pfade laufen gerade", und die
---darf ihrerseits nichts fragen, was wieder von ihr abhaengt. Genau so
---entstand ein Kreis, der den Lua-Stapel gesprengt hat.
---@param keyLevel number
---@return number|nil
local function rawRewardLevel(keyLevel)
    if not C_MythicPlus or not C_MythicPlus.GetRewardLevelForDifficultyLevel then
        return nil
    end
    local ok, a, b = pcall(C_MythicPlus.GetRewardLevelForDifficultyLevel, keyLevel)
    if not ok then return nil end
    a, b = tonumber(a) or 0, tonumber(b) or 0
    local hoch = math.max(a, b)
    return hoch > 0 and hoch or nil
end

local TRACK_CHAMPION, TRACK_HERO = 973, 974
local RUN_REWARD = {
    [0]  = { track = TRACK_CHAMPION, rank = 1 },
    [2]  = { track = TRACK_CHAMPION, rank = 2 },
    [3]  = { track = TRACK_CHAMPION, rank = 2 },
    [4]  = { track = TRACK_CHAMPION, rank = 3 },
    [5]  = { track = TRACK_CHAMPION, rank = 4 },
    [6]  = { track = TRACK_HERO, rank = 1 },
    [7]  = { track = TRACK_HERO, rank = 1 },
    [8]  = { track = TRACK_HERO, rank = 2 },
    [9]  = { track = TRACK_HERO, rank = 2 },
    [10] = { track = TRACK_HERO, rank = 3 },
}

-- UND WAS DIE SCHATZKAMMER GIBT.
--
-- Dieselbe Art Tabelle aus demselben Grund: die Spieldaten fuehren
-- ihre Stufen zwar (WeeklyRewardLevel), aber nur als ZAHL. Eine Zahl
-- reicht nicht, weil dieselbe Stufe in zwei Pfaden vorkommt - 305 ist
-- Held 1 und Champion 5. Ueber die Zahl beschriftet stand deshalb
-- "Tresor +2 +3" an einem Champion-Rang, den die Schatzkammer nie gibt.
--
-- Nachpruefbar im Spiel: die Schatzkammer zeigt am Mittwoch, welchen
-- Rang sie fuer welchen Schluessel anbietet.
local TRACK_MYTH_V = 978
local VAULT_REWARD = {
    [2]  = { track = TRACK_HERO, rank = 1 },
    [3]  = { track = TRACK_HERO, rank = 1 },
    [4]  = { track = TRACK_HERO, rank = 2 },
    [5]  = { track = TRACK_HERO, rank = 2 },
    [6]  = { track = TRACK_HERO, rank = 3 },
    [7]  = { track = TRACK_HERO, rank = 4 },
    [8]  = { track = TRACK_HERO, rank = 4 },
    [9]  = { track = TRACK_HERO, rank = 4 },
    [10] = { track = TRACK_MYTH_V, rank = 1 },
}

---Welche Schluessel einen Pfad-Rang in der Schatzkammer geben.
---@param trackName number
---@param rank number
---@return number[]|nil
function Compat.VaultKeysForRank(trackName, rank)
    local out
    for key, want in pairs(VAULT_REWARD) do
        if want.track == trackName and want.rank == rank then
            out = out or {}
            out[#out + 1] = key
        end
    end
    if out then table.sort(out) end
    return out
end

---Die Stufe, die ein Schluessel in der Schatzkammer gibt.
---@param keyLevel number
---@return number|nil
function Compat.VaultLevel(keyLevel)
    local want = VAULT_REWARD[keyLevel]
    if not want then return nil end
    return Compat.TrackLevel(want.track, want.rank)
end

---Welche Schluessel einen Pfad-Rang am Dungeonende geben.
---
---Die Frage stellt das Menue je RANG - und genau so muss sie
---beantwortet werden. Ueber die Stufe zu gehen war der Fehler: 311
---steht im Held-Pfad auf Rang 3 und im Champion-Pfad auf Rang 7, und
---dann stand "+10" in beiden Zeilen.
---@param trackName number
---@param rank number
---@return number[]|nil  aufsteigend, nil wenn kein Schluessel ihn gibt
function Compat.KeysForRank(trackName, rank)
    local out
    for key, want in pairs(RUN_REWARD) do
        if want.track == trackName and want.rank == rank then
            out = out or {}
            out[#out + 1] = key
        end
    end
    if out then table.sort(out) end
    return out
end

---Die Stufe, die ein Schluessel am Dungeonende gibt.
---
---Aus Pfad und Rang, vom Client gerechnet. Kennt er den Pfad dieser
---Saison nicht, gibt es keine Antwort - und dann behauptet das Fenster
---auch keine.
---@param keyLevel number
---@return number|nil
function Compat.RunLevel(keyLevel)
    local want = RUN_REWARD[keyLevel]
    if not want then return nil end
    local tracks = ns.Catalog.Tracks and ns.Catalog.Tracks()
    local read = C_Item and C_Item.GetDetailedItemLevelInfo
    local probe = ns.Catalog.ProbeItem and ns.Catalog.ProbeItem()
    if not tracks or not read or not probe then return nil end
    local season = Compat.SeasonTracks(probe)
    for t, track in ipairs(tracks) do
        -- Denselben Pfad gibt es aus mehreren Saisons. Gemeint ist der,
        -- der JETZT laeuft.
        if track.name == want.track and (not season or season[t]) then
            local bonus = (track.lists or {})[want.rank]
            if bonus then
                -- Der Link von Hand: trackLink() steht weiter unten in
                -- der Datei und ist hier noch nicht bekannt.
                local link = ("item:%d::::::::::::1:%d"):format(probe, bonus)
                local ok, level = pcall(read, link)
                if ok and type(level) == "number" and level > 0 then return level end
            end
        end
    end
    return nil
end

-- Die drei Pfade, an denen sich die Farbe einer Stufe entscheidet.
local TRACK_MYTH = 978
-- Bis zu welchem Rang des Mythisch-Pfads ein Schlachtzugsboss faellt.
-- Darueber gibt es nur noch Aufwertung - und das ist die Grenze, ab
-- der eine Stufe nicht mehr erreichbar, sondern erarbeitet ist.
local MYTH_DROP_RANKS = 4

---Die Stufe des ersten Rangs eines Pfads dieser Saison.
---@param trackName number  SharedString-ID des Pfads
---@param rank number|nil  Vorgabe: der erste
---@return number|nil
function Compat.TrackLevel(trackName, rank)
    local tracks = ns.Catalog.Tracks and ns.Catalog.Tracks()
    local read = C_Item and C_Item.GetDetailedItemLevelInfo
    local probe = ns.Catalog.ProbeItem and ns.Catalog.ProbeItem()
    if not tracks or not read or not probe then return nil end
    local season = Compat.SeasonTracks(probe)
    for t, track in ipairs(tracks) do
        if track.name == trackName and (not season or season[t]) then
            local bonus = (track.lists or {})[rank or 1]
            if bonus then
                local ok, level = pcall(read, ("item:%d::::::::::::1:%d"):format(probe, bonus))
                if ok and type(level) == "number" and level > 0 then return level end
            end
        end
    end
    return nil
end

---Welche Qualitaet eine Gegenstandsstufe in DIESER Saison bedeutet.
---
---Nicht die Qualitaet eines bestimmten Gegenstands - die steht am
---Gegenstand. Gemeint ist, wo eine Stufe zwischen den Pfaden liegt:
---unterhalb von Champion ist sie belanglos, ab Held wird es
---interessant, ab Mythisch selten, und ueber dem hoechsten Rang, den
---ein Boss noch fallen laesst, ist sie nur noch durch Aufwertung zu
---haben.
---
---Die Grenzen werden NICHT eingetragen, sondern an den Pfaden dieser
---Saison abgelesen. Damit stimmen sie auch, wenn Blizzard die Stufen
---verschiebt.
---@param level number|nil
---@return number|nil quality  Enum.ItemQuality
function Compat.LevelQuality(level)
    if not level then return nil end
    local champion = Compat.TrackLevel(TRACK_CHAMPION)
    local hero = Compat.TrackLevel(TRACK_HERO)
    local myth = Compat.TrackLevel(TRACK_MYTH)
    local mythTop = Compat.TrackLevel(TRACK_MYTH, MYTH_DROP_RANKS)
    if mythTop and level > mythTop then return 5 end
    if myth and level >= myth then return 4 end
    if hero and level >= hero then return 3 end
    if champion and level >= champion then return 2 end
    return 1
end

---Eine Stufe als eingefaerbter Text.
---@param level number|nil
---@return string
function Compat.LevelText(level)
    if not level then return "" end
    local quality = Compat.LevelQuality(level)
    local get = C_Item and C_Item.GetItemQualityColor
    if quality and get then
        local ok, r, g, b = pcall(get, quality)
        if ok and type(r) == "number" then
            return ("|cff%02x%02x%02x%d|r"):format(r * 255, g * 255, b * 255, level)
        end
    end
    return tostring(level)
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
---
---UND EINE FEHLENDE ZAHL WIRD NICHT ERFUNDEN.
---
---In dieser Saison antwortet GetRewardLevelForDifficultyLevel nur noch
---mit EINEM Wert - der Schatzkammer -, der zweite ist null. Hier stand
---dann "return a, a": die Tresorstufe galt auch als Dungeonstufe. Im
---Menue las man darum "311 (+6)", wo "311 (+10)" richtig ist, und jede
---Stufe hing am falschen Schluessel.
---
---Die Dungeonstufe kennt eine zweite Schnittstelle. Gibt es sie nicht,
---bleibt die Dungeonstufe NIL - und das Menue sagt dann eben
---"Schatzkammer +10" statt etwas zu behaupten.
---@param keyLevel number
---@return number|nil endOfRun, number|nil vault
function Compat.RewardLevels(keyLevel)
    if not C_MythicPlus or not C_MythicPlus.GetRewardLevelForDifficultyLevel then
        return nil
    end
    local ok, a, b = pcall(C_MythicPlus.GetRewardLevelForDifficultyLevel, keyLevel)
    if not ok then return nil end
    -- Die Dungeonstufe aus Pfad und Rang. Die zweite Schnittstelle des
    -- Clients wurde probiert und half nicht: sie nennt dieselbe
    -- Tresorstufe wie die erste.
    local run = Compat.RunLevel and Compat.RunLevel(keyLevel) or nil
    -- Eine Null ist keine Stufe.
    --
    -- Mein Trick "der kleinere ist der Dungeon" ging genau hier schief:
    -- gibt der Client fuer einen Wert 0 zurueck, war das Minimum 0, und
    -- im Fenster stand "+2 -> 0 - Tresor 305".
    a, b = tonumber(a), tonumber(b)
    if (a or 0) <= 0 then a = nil end
    if (b or 0) <= 0 then b = nil end
    if not a and not b then return run, run end
    -- Beide da: die kleinere ist der Dungeon, die groessere die Truhe.
    if a and b then return math.min(a, b), math.max(a, b) end
    -- Nur eine: sie ist die Schatzkammer. Der Dungeon kommt aus der
    -- zweiten Schnittstelle - oder gar nicht.
    -- Die Schatzkammer aus unserer Tabelle; was der Client sagt, bleibt
    -- der Rueckfall, solange sie den Schluessel nicht kennt.
    local vault = Compat.VaultLevel and Compat.VaultLevel(keyLevel) or nil
    vault = vault or a or b
    if run and vault and run > vault then return vault, run end
    return run, vault
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
        -- Auch eine Zeile ohne Dungeonstufe: die Schatzkammer allein ist
        -- eine Auskunft. Vorher fiel sie ganz heraus, und das Menue war
        -- leer statt halb.
        if endOfRun or vault then
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
---Baut einen Gegenstandslink mit Bonus-IDs.
---
---Die Felder bis zur ANZAHL der Bonus-IDs sind leer; dann kommt die
---Anzahl, dann die IDs. Ein Feld zu wenig, und der Client liest die
---Anzahl als etwas anderes und verwirft den Link - das Tooltip bleibt
---dann leer.
---@param itemID number
---@param ... number Bonus-IDs, nil wird uebersprungen
---@return string
local function linkWith(itemID, ...)
    local ids = {}
    for i = 1, select("#", ...) do
        local id = select(i, ...)
        if id then ids[#ids + 1] = id end
    end
    if #ids == 0 then return "item:" .. itemID end
    return ("item:%d::::::::::::%d:%s"):format(itemID, #ids, table.concat(ids, ":"))
end

local function trackLink(itemID, bonus)
    return linkWith(itemID, bonus)
end

---Ein Link aus einer gemessenen Bonus-Liste.
---
---Die Liste bleibt, wie sie war - sie traegt Qualitaet, Aufwertung und
---Verzierung, und jede davon fehlt im Tooltip, wenn man sie wegwirft.
---Nur die Wertewahl wird ersetzt, und nur wenn eine gewaehlt ist.
---@param itemID number
---@param ids number[] die gemessene Liste
---@param wantStat number|nil die gewuenschte Werte-Bonus-ID
---@param statSet table<number, boolean>|nil welche IDs Werte setzen
---@return string
function Compat.LinkWithList(itemID, ids, wantStat, statSet)
    if not itemID or type(ids) ~= "table" or #ids == 0 then return nil end
    local out, replaced = {}, false
    for _, id in ipairs(ids) do
        if wantStat and statSet and statSet[id] then
            if not replaced then
                out[#out + 1] = wantStat
                replaced = true
            end
        else
            out[#out + 1] = id
        end
    end
    -- Gewuenscht, aber keine im Stueck: dann kommt sie dazu.
    if wantStat and not replaced then out[#out + 1] = wantStat end
    if #out == 0 then return "item:" .. itemID end
    return ("item:%d::::::::::::%d:%s"):format(itemID, #out, table.concat(out, ":"))
end

---Ein Gegenstandslink mit beliebigen Bonus-IDs.
---@param itemID number
---@param ... number
---@return string
function Compat.LinkWith(itemID, ...)
    return linkWith(itemID, ...)
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
    -- Der rohe Clientwert, nicht die fertige Tabelle: die haengt
    -- inzwischen an den Pfaden, die hier erst bestimmt werden.
    local wanted = {}
    for level = 2, 30 do
        local got = rawRewardLevel(level)
        if got then wanted[got] = true end
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
---@param extra number|nil eine zusaetzliche Bonus-ID (die Wertewahl
---eines Handwerksstuecks - ohne sie steht im Tooltip "Zufallswert 1")
function Compat.LinkAtLevel(itemID, level, extra)
    if not itemID then return nil end
    -- Ohne Zielstufe bleibt der Gegenstand, wie er ist - seine Werte
    -- gehoeren trotzdem in den Link.
    if not level then return extra and linkWith(itemID, extra) or nil end
    local info = C_Item and C_Item.GetItemInfo and { pcall(C_Item.GetItemInfo, itemID) }
    -- GetItemInfo gibt die Grundstufe an vierter Stelle (nach dem
    -- pcall-Erfolg also an fuenfter).
    local base = info and info[1] and tonumber(info[5]) or nil
    -- Ohne Grundstufe koennen wir die Stufe nicht setzen - die Werte
    -- aber schon, und die sind das Wichtigere: ohne sie steht im
    -- Tooltip "Zufallswert 1", und die Rangnummern fallen weg. Der
    -- Client kennt die Grundstufe eines Gegenstands erst, wenn er ihn
    -- vom Server geholt hat; beim Aufbau der Liste hat er die wenigsten.
    if not base or base <= 0 then
        return extra and linkWith(itemID, extra) or nil
    end

    -- Erst der Aufwertungspfad, dann die Differenz.
    --
    -- Beides bringt den Client auf die richtige Stufe. Aber nur der
    -- Pfad laesst ihn "Held 3/6" ins Tooltip schreiben - er kennt den
    -- Pfad, er kennt den Rang, er schreibt beides hin. Die Differenz
    -- setzt nur die Zahl. Das ist der ganze Unterschied zu KeystoneLoot,
    -- und er liegt nicht in einer Tabelle, sondern in der ART der
    -- Bonus-ID.
    -- Der Effekt reist mit, wo es einen gibt.
    --
    -- Er haengt an einer eigenen Bonus-Liste, nicht am Gegenstand: ohne
    -- sie zeigt der Client den Helm ohne seine Wirkung, weil im Link
    -- nichts davon steht.
    local effect = ns.Catalog.EffectBonus and ns.Catalog.EffectBonus(itemID) or nil
    local delta = level - base
    -- Die Grundstufe braucht keinen Bonus - und keinen Pfad. Die
    -- Wertewahl aber schon: sie haengt nicht an der Stufe.
    if delta == 0 then return linkWith(itemID, extra, effect) end

    local hit = Compat.TrackFor(level, itemID)
    if hit then return linkWith(itemID, hit.bonus, extra, effect) end

    local bonus = ns.Catalog.LevelDeltaBonus(delta)
    if not bonus then return linkWith(itemID, extra, effect) end

    return linkWith(itemID, bonus, extra, effect)
end
