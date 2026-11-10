local _, ns = ...

---Wo faellt, was die Besten tragen?
---
---Die Ausruestungsliste beantwortet die Frage je PLATZ: was traegt man
---am Kopf, was an den Schultern. Wer einen Abend Zeit hat oder sich
---durch Dungeons ziehen laesst, stellt die umgekehrte Frage: wohin gehe
---ich, damit moeglichst viel davon faellt - und zwar von dem, was ich
---noch nicht trage.
---
---Dieselben Zahlen, andere Achse. Gezaehlt wird nichts Neues: jedes
---Stueck steht schon in den Empfehlungen, sein Fundort steht schon im
---Abenteuerjournal, und was am Koerper haengt, weiss der Client.
---
---WAS DIESE DATEI NICHT WEISS. Sie kennt keinen BiS-Gegenstand. Gemessen
---ist, WIE VIELE der Besten ein Stueck tragen - nicht, wieviel es wert
---ist. Ein Dungeon steht darum oben, weil dort viel von dem faellt, was
---verbreitet ist, und nicht, weil er sich "am meisten lohnt". Der
---Unterschied gehoert in die Ueberschrift, nicht in eine Fussnote.
---
---UND SIE VERSCHWEIGT DIE LUECKE NICHT. Etwa ein Drittel der empfohlenen
---Stuecke hat keinen Fundort im Journal: Handwerk, Set-Teile aus dem
---Katalysator, Welt- und Delve-Beute. Wer die stillschweigend weglaesst,
---laesst jeden Dungeon besser aussehen, als er ist. Sie werden deshalb
---gezaehlt und in einer eigenen Zeile genannt.
local Drops = {}
ns.Drops = Drops

---Alles, was zu einem Gegenstand gehoert, den man NICHT im Journal findet.
---@param itemID number
---@param badge string|nil
---@return string "craft" | "set" | "pvp" | "boe" | "world"
local function elsewhere(itemID, badge)
    local origin = ns.Catalog.Origin and ns.Catalog.Origin(itemID)
    if origin == "conquest" or origin == "honor" then return "pvp" end
    if origin == "pvpcraft" then return "craft" end
    if badge == "craft" then return "craft" end
    if badge == "set" then return "set" end
    -- DER KATALOG WEISS ES AUS DEN SPIELDATEN.
    --
    -- Er steht VOR dem Client: was in den Spieldaten markiert ist,
    -- stimmt auch dann, wenn der Client den Gegenstand noch nie
    -- gesehen hat - und beim ersten Oeffnen kennt er die wenigsten.
    if ns.Catalog.IsCrafted and ns.Catalog.IsCrafted(itemID) then return "craft" end
    -- DER CLIENT WEISS ES BESSER ALS UNSERE TABELLEN.
    --
    -- Unter "ohne bekannten Fundort" standen ueberwiegend
    -- Handwerksstuecke: murlok liefert die Marke nur manchmal mit, und
    -- im Katalog stehen sie nicht, weil ihre Nummern nicht in der
    -- Handwerkstabelle auftauchen. Der Client fuehrt aber die
    -- Handwerksqualitaet am Gegenstand selbst - und die hat nur, was
    -- hergestellt wurde.
    --
    -- "Ohne bekannten Fundort" soll heissen: wir wissen es wirklich
    -- nicht. Alles, was wir doch wissen koennen, gehoert vorher
    -- gefragt.
    if ns.Compat and ns.Compat.CraftQuality and ns.Compat.CraftQuality(itemID) then
        return "craft"
    end
    -- UND WAS BINDET, WENN MAN ES ANLEGT, kann man kaufen.
    --
    -- "Jadeauge der gebundenen Schlange" faellt im Schlachtzug von
    -- jedem Boss und steht darum in keiner Bosstabelle. Es im Topf
    -- "ohne bekannten Fundort" zu lassen waere zwar nicht falsch, aber
    -- es verschweigt den einen Weg, der offensteht: das Auktionshaus.
    if ns.Compat and ns.Compat.BindType and ns.Compat.BindType(itemID) == 2 then
        return "boe"
    end
    return "world"
end

---Passt dieses Stueck zur gewaehlten Hervorhebung?
---
---DREI ANTWORTEN, nicht zwei. `nil` heisst "weiss nicht": entweder ist
---gar nichts gewaehlt, oder der Client kennt das Stueck noch nicht und
---damit auch seine Werte nicht. Das Raster blendet dann weder ab noch
---hebt es hervor - eine Vermutung als Tatsache zu zeigen waere hier
---besonders teuer, denn gesucht wird ja gerade das Stueck mit den
---richtigen Werten.
---
---@param stats table|nil  { crit = true, ... } oder nil
---@param wunsch table|nil  gewaehlte Werte, dazu "none"
---@param kombi boolean|nil  true: alle gewaehlten muessen drauf sein
---@return boolean|nil
function Drops.Matches(stats, wunsch, kombi, fav, top)
    wunsch = wunsch or {}
    local gewaehlt, nurBekannt = 0, true
    for k in pairs(wunsch) do
        gewaehlt = gewaehlt + 1
        if k ~= "fav" and k ~= "top" then nurBekannt = false end
    end
    if gewaehlt == 0 then return nil end
    -- Need und "meistgetragen" sind keine Werte des Gegenstands,
    -- sondern Auskuenfte ueber den Spieler und die Messung - die haben
    -- wir immer, auch wenn der Client das Stueck noch nicht kennt.
    local bekannt = { fav = fav and true or false, top = top and true or false }
    for k, ja in pairs(bekannt) do
        if wunsch[k] and ja and not kombi then return true end
        if wunsch[k] and not ja and kombi then return false end
    end
    if nurBekannt then return kombi and true or false end
    if not stats then return nil end

    local hatWelche = false
    for _, k in ipairs(ns.SECONDARY) do
        if stats[k] then hatWelche = true end
    end

    if kombi then
        -- UND: jeder gewaehlte Wert muss drauf sein.
        for _, k in ipairs(ns.SECONDARY) do
            if wunsch[k] and not stats[k] then return false end
        end
        -- "Keine Zweitwerte" und ein Wert zugleich gibt es nicht.
        if wunsch.none and hatWelche then return false end
        return true
    end

    -- ODER: einer genuegt.
    for _, k in ipairs(ns.SECONDARY) do
        if wunsch[k] and stats[k] then return true end
    end
    if wunsch.none and not hatWelche then return true end
    return false
end

-- Der Platz eines Gegenstands, in den Namen der Ausruestungsliste.
--
-- Erst aus dem Gegenstand selbst (sofort, ohne Cache), dann aus dem
-- Filter des Journals. Was keinen Platz hat - Reittiere, Rezepte,
-- Setmarken -, steht nicht im Raster: es ist keine Ausruestung.
local PLATZ = {
    INVTYPE_HEAD = "Head", INVTYPE_NECK = "Neck", INVTYPE_SHOULDER = "Shoulders",
    INVTYPE_CLOAK = "Back", INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest",
    INVTYPE_WRIST = "Wrist", INVTYPE_HAND = "Hands", INVTYPE_WAIST = "Waist",
    INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet", INVTYPE_FINGER = "Rings",
    INVTYPE_TRINKET = "Trinkets", INVTYPE_WEAPON = "Main Hand",
    INVTYPE_2HWEAPON = "Main Hand", INVTYPE_WEAPONMAINHAND = "Main Hand",
    INVTYPE_RANGED = "Main Hand", INVTYPE_RANGEDRIGHT = "Main Hand",
    INVTYPE_WEAPONOFFHAND = "Off Hand", INVTYPE_SHIELD = "Off Hand",
    INVTYPE_HOLDABLE = "Off Hand",
}
local FILTER = {
    Head = "Head", Neck = "Neck", Shoulder = "Shoulders", Cloak = "Back",
    Chest = "Chest", Wrist = "Wrist", Hand = "Hands", Waist = "Waist",
    Legs = "Legs", Feet = "Feet", MainHand = "Main Hand", OffHand = "Off Hand",
    Finger = "Rings", Trinket = "Trinkets",
}
local REIHE = {}
for i, platz in ipairs({ "Head", "Neck", "Shoulders", "Back", "Chest", "Wrist", "Hands",
    "Waist", "Legs", "Feet", "Rings", "Trinkets", "Main Hand", "Off Hand" }) do
    REIHE[platz] = i
end

local function platzVon(itemID, filter)
    local get = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(get) == "function" then
        local ok, _, _, _, ort = pcall(get, itemID)
        if ok and PLATZ[ort] then return PLATZ[ort] end
    end
    local arten = Enum and Enum.ItemSlotFilterType
    if filter ~= nil and type(arten) == "table" then
        for name, wert in pairs(arten) do
            if wert == filter and FILTER[name] then return FILTER[name] end
        end
    end
    return nil
end

---Was gemessen ist, je Gegenstand: der hoechste Anteil und sein Platz.
-- Wie viele Stuecke an einem Platz "am haeufigsten getragen" sind:
-- Ringe und Schmuck traegt man zu zweit.
local ZWEI = { Rings = true, Trinkets = true }

local function gemessen(gear)
    local out = {}
    for platz, liste in pairs(gear or {}) do
        local reihe = {}
        for _, item in ipairs(liste) do reihe[#reihe + 1] = item end
        table.sort(reihe, function(a, b) return (a.pct or 0) > (b.pct or 0) end)
        for rang, item in ipairs(reihe) do
            local da = item.id and out[item.id]
            local oben = rang <= (ZWEI[platz] and 2 or 1)
            if item.id and (not da or (item.pct or 0) > (da.pct or 0)) then
                out[item.id] = { pct = item.pct or 0, slot = platz, ilvl = item.ilvl,
                    kind = item.kind, top = oben or (da and da.top) or false }
            elseif da and oben then
                da.top = true
            end
        end
    end
    return out
end

---Die Fundorte einer Spec: jede Instanz mit ALLEN Drops.
---
---Seit dem 15. Oktober wie Keystone Loot. Vorher standen hier nur die
---Stuecke, die die Besten tragen, verglichen mit dem, was man schon
---anhat. Jetzt: jede laufende Instanz, jeder Drop fuer die Spec aus dem
---Journal. Was gemessen ist, traegt seinen Anteil - das ist die
---Hervorhebung, die zaehlt. Was man haben will, markiert man als Need.
---
---Dungeons und Schlachtzug stehen IMMER beide da, egal welche Aktivitaet
---oben gewaehlt ist (entschieden am 15. Oktober). Die Anteile kommen fuer
---Dungeons aus M+, fuer den Schlachtzug aus dem Raid - die gewaehlte
---Aktivitaet zuerst, wenn sie passt.
---
---Antwortet das Journal nicht (es ist offen, oder ein Client ohne die
---Abfrage), steht die Instanz trotzdem da, mit dem Gemessenen, und die
---Zeile sagt es.
---
---@param specID number|nil
---@param mode string
---@param source string|nil
---@param opts table|nil  loot / slot / need zum Pruefen ueberschreibbar
---@return table[] rows
---@return table summary
---@return string|nil fromSource
function Drops.Build(specID, mode, source, opts)
    opts = opts or {}
    local summary = { total = 0, craft = 0, set = 0, pvp = 0, boe = 0, world = 0,
        past = 0, need = 0, journal = 0, partial = 0 }
    local hier, from = ns.Recommend.Gear(specID, mode, source)

    local basis = tostring(ns.Recommend.BaseMode and ns.Recommend.BaseMode(mode) or mode or "")
    local imRaid = basis:find("^raid") ~= nil
    local inMplus = basis:find("^mplus") ~= nil
    local function anderswo(m)
        return ns.Recommend.Gear(specID, m, source) or ns.Recommend.Gear(specID, m, ns.Recommend.ALL)
    end
    local mess = {
        dungeon = gemessen(inMplus and hier or anderswo("mplus")),
        raid = gemessen(imRaid and hier or anderswo("raid")),
    }

    local nurPlatz = opts.slot
    if nurPlatz == nil and ns.Profile and ns.Profile.GearSlot then nurPlatz = ns.Profile.GearSlot() end
    local need = opts.need or function(id) return ns.Profile.Need(id, specID) end
    -- WAS DU SCHON HAST: angelegt, oder irgendwo in Taschen und Banken.
    -- Das Angelegte einmal je Aufbau, nicht je Kaestchen.
    local angelegt = opts.equipped or (ns.Compat.EquippedIDs and ns.Compat.EquippedIDs()) or {}
    local hast = opts.owned or function(id)
        return angelegt[id] or (ns.Compat.ItemCount and ns.Compat.ItemCount(id) > 0) or false
    end
    local holen = opts.loot or (ns.Loot and ns.Loot.Items)

    -- Die Instanzen: aus dem Katalog, sonst aus der Messung.
    local instanzen = ns.Catalog.CurrentInstances and ns.Catalog.CurrentInstances() or {}
    if #instanzen == 0 then
        local schon = {}
        for _, art in ipairs({ "dungeon", "raid" }) do
            for id in pairs(mess[art]) do
                local _, inst = ns.Catalog.DropSource(id)
                if inst and ns.Catalog.InstanceCurrent(inst) ~= false and not schon[inst] then
                    schon[inst] = true
                    instanzen[#instanzen + 1] = inst
                end
            end
        end
        table.sort(instanzen)
    end

    ---Ein Kaestchen bauen - oder nil, wenn es nicht ins Raster gehoert.
    local function kaestchen(id, enc, filter, m)
        local platz = (m and m.slot) or platzVon(id, filter)
        if not platz then return nil end
        if nurPlatz and nurPlatz ~= platz then return nil end
        return {
            id = id, slot = platz, enc = enc, spec = specID,
            pct = m and m.pct or nil, ilvl = m and m.ilvl or nil,
            measured = m ~= nil, need = need(id) and true or false,
            top = m and m.top or false,
            owned = hast(id) and true or false,
        }
    end

    local function ordnen(items)
        table.sort(items, function(a, b)
            if a.measured ~= b.measured then return a.measured end
            if (a.pct or 0) ~= (b.pct or 0) then return (a.pct or 0) > (b.pct or 0) end
            local ra, rb = REIHE[a.slot] or 99, REIHE[b.slot] or 99
            if ra ~= rb then return ra < rb end
            return (a.id or 0) < (b.id or 0)
        end)
    end

    local function zaehlen(row)
        local n, gem, bestes = 0, 0, 0
        for _, c in ipairs(row.items) do
            if c.need then n = n + 1 end
            if c.measured then
                gem = gem + 1
                if (c.pct or 0) > bestes then bestes = c.pct or 0 end
            end
        end
        row.total, row.need, row.measured, row.best = #row.items, n, gem, bestes
        summary.need = summary.need + n
        summary.total = summary.total + #row.items
    end

    local dungeons, raids = {}, {}
    for _, inst in ipairs(instanzen) do
        local art = ns.Catalog.InstanceKind(inst)
            or (ns.Recommend.InstanceKind and ns.Recommend.InstanceKind(inst)) or "dungeon"
        if art ~= "raid" then art = "dungeon" end
        local m = mess[art]
        local beute, vollstaendig
        if holen then beute, vollstaendig = holen(inst, specID) end
        local items, gesehen = {}, {}
        for _, e in ipairs(beute or {}) do
            if not gesehen[e.id] then
                gesehen[e.id] = true
                local c = kaestchen(e.id, e.enc, e.filter, m[e.id])
                if c then items[#items + 1] = c end
            end
        end
        -- Was gemessen ist und hier faellt, steht immer da - auch wenn
        -- das Journal es fuer diese Spec nicht fuehrt.
        for id, mm in pairs(m) do
            local enc, wo = ns.Catalog.DropSource(id)
            if wo == inst and not gesehen[id] then
                gesehen[id] = true
                local c = kaestchen(id, enc, nil, mm)
                if c then items[#items + 1] = c end
            end
        end
        if beute then summary.journal = summary.journal + 1 else summary.partial = summary.partial + 1 end
        local teilweise = not beute or vollstaendig == false

        if art == "dungeon" then
            local row = { kind = "droprow", inst = inst, place = "dungeon", items = items,
                partial = teilweise }
            ordnen(items)
            zaehlen(row)
            if #items > 0 then dungeons[#dungeons + 1] = row end
        else
            -- Im Schlachtzug je Boss eine Zeile, in der Reihenfolge des
            -- Journals. Was keinem bekannten Boss gehoert, haengt hinten.
            local jeBoss, reihe = {}, {}
            for _, enc in ipairs(ns.Catalog.Bosses(inst) or {}) do
                jeBoss[enc] = {}
                reihe[#reihe + 1] = enc
            end
            for _, c in ipairs(items) do
                local enc = c.enc or 0
                if not jeBoss[enc] then jeBoss[enc] = {}; reihe[#reihe + 1] = enc end
                table.insert(jeBoss[enc], c)
            end
            for _, enc in ipairs(reihe) do
                if #jeBoss[enc] > 0 then
                    local row = { kind = "droprow", inst = inst, enc = enc ~= 0 and enc or nil,
                        place = "raid", items = jeBoss[enc], partial = teilweise }
                    ordnen(row.items)
                    zaehlen(row)
                    raids[#raids + 1] = row
                end
            end
        end
    end

    -- Dungeons nach Namen: man sucht einen Dungeon, man rechnet nicht.
    local function name(inst)
        return (ns.Compat.InstanceName and ns.Compat.InstanceName(inst)) or ("#" .. tostring(inst))
    end
    table.sort(dungeons, function(a, b)
        local na, nb = name(a.inst), name(b.inst)
        if na ~= nb then return na < nb end
        return a.inst < b.inst
    end)

    -- WAS IN KEINER INSTANZ FAELLT, aus der gewaehlten Aktivitaet:
    -- Handwerk, Set-Teile, PvP, Auktionshaus, Welt. Nur Gemessenes -
    -- dafuer gibt es kein Journal.
    local woanders, wReihe = {}, {}
    for id, mm in pairs(gemessen(hier)) do
        local enc, inst = ns.Catalog.DropSource(id)
        if inst and ns.Catalog.InstanceCurrent(inst) == false then
            summary.past = summary.past + 1
        elseif not inst then
            local wo = elsewhere(id, mm.kind)
            local c = kaestchen(id, enc, nil, mm)
            if c then
                if not woanders[wo] then
                    woanders[wo] = { kind = "droprow", place = wo, items = {} }
                end
                table.insert(woanders[wo].items, c)
                summary[wo] = (summary[wo] or 0) + 1
            end
        end
    end
    for _, wo in ipairs({ "craft", "set", "pvp", "boe", "world" }) do
        local row = woanders[wo]
        if row then ordnen(row.items); zaehlen(row); wReihe[#wReihe + 1] = row end
    end

    local out = {}
    for _, row in ipairs(dungeons) do out[#out + 1] = row end
    for _, row in ipairs(raids) do out[#out + 1] = row end
    for _, row in ipairs(wReihe) do out[#out + 1] = row end
    return out, summary, from
end
