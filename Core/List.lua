-- Soll minus Ist. Erzeugt aus Katalog, Empfehlung, Auswahl und Ausruestung
-- die Zeilen, die Oberflaeche und Auctionator-Adapter gemeinsam benutzen.
--
-- Die Rangfolge ist ueberall dieselbe und steht nur an einer Stelle
-- (`resolve`): erst die Empfehlung fuer Spec und Spielmodus, dann die
-- eigene Wahl des Spielers, dann gar nichts. Eine Zeile "gar nichts" ist
-- kein Fehler - sie fragt nach, statt zu raten.

local _, ns = ...

local List = {}
ns.List = List

local Catalog, Gear, Compat = ns.Catalog, ns.Gear, ns.Compat

---Fuellt eine Zeile mit allem, was der Client dazu weiss.
---
---`need` und `missing` sind NICHT dasselbe, und das ist der Kern der
---Vollansicht: gezeigt werden alle Plaetze, gekauft wird nur fuer die
---offenen. Sonst stuende bei einer laengst verzauberten Brust "1 kaufen".
---@param row table
local function fill(row)
    local name, link, icon = Compat.ItemInfo(row.id)
    row.name = name
    row.link = link
    row.icon = icon
    row.owned = Compat.ItemCount(row.id)
    -- Dieselbe Ware in anderer Qualitaet: Gold deckt Silber, Silber
    -- deckt Gold nicht - steht aber dabei, damit man weiss, was da ist.
    local lower, higher = Catalog.Tiers(row.id)
    row.ownedLower, row.ownedHigher = 0, 0
    for _, other in ipairs(lower) do row.ownedLower = row.ownedLower + Compat.ItemCount(other) end
    for _, other in ipairs(higher) do row.ownedHigher = row.ownedHigher + Compat.ItemCount(other) end
    row.buy = math.max(0, (row.missing or 0) - row.owned - row.ownedHigher)
    return row
end

---Die Verzauberung eines Platzes, in der gewuenschten Handwerksstufe.
---@param entry table|nil
---@param cheap boolean
---@return number|nil
local function pickID(entry, cheap)
    if not entry then return nil end
    if cheap and entry.alt then return entry.alt end
    return entry.id
end

---@param list table[]
---@param id number
---@return table|nil
local function byID(list, id)
    for _, e in ipairs(list) do
        if e.id == id or e.alt == id then return e end
    end
    return nil
end

---Baut die Einkaufsliste.
---@param scan table Ergebnis von Gear.Scan()
---@return table[] rows
function List.Build(scan)
    local p = ns.Profile.Current()
    local specID = ns.Profile.SelectedSpec()
    local rec = ns.Recommend.For(specID, ns.Profile.Mode(), ns.Profile.Source())
    local primary = Compat.SpecPrimaryStat(specID)
    local foreign = ns.Profile.IsForeignClass()
    local rows = {}

    -- Liefert zwei Zahlen: wie viele Plaetze die Zeile zeigt, und wie
    -- viele davon noch offen sind.
    --
    -- Fuer eine fremde Klasse ist die eigene Ausruestung die falsche. Dann
    -- wird nicht gezaehlt, sondern aufgezaehlt - und alles gilt als offen,
    -- weil das Gegenteil nicht feststellbar ist.
    ---@param slot string
    ---@param wanted number|nil Gegenstand, der drauf soll
    ---@return number need
    ---@return number missing
    ---@return number|nil other Fremde Verzauberung auf dem Platz
    local function counts(slot, wanted)
        if foreign then
            local n = ns.SLOT_COUNT[slot] or 1
            return n, n
        end
        local missing, total, other = Gear.Missing(scan, slot, wanted)
        if p.onlyMissing then return missing, missing, other end
        return total, missing, other
    end

    ---Empfehlung schlaegt eigene Wahl.
    ---@param slot string
    ---@param fallback table|nil Katalogeintrag aus der eigenen Wahl
    ---@return number|nil id
    ---@return table|nil entry
    ---@return number|nil pct
    local function resolve(slot, fallback)
        local pick = ns.Recommend.Enchant(rec, slot)
        if pick then
            local entry = Catalog.EnchantByID(pick.id)
            return pickID(entry, p.cheap) or pick.id, entry, pick.pct
        end
        if not fallback then return nil end
        return pickID(fallback, p.cheap), fallback, nil
    end

-- Wie viele Alternativen unter der Empfehlung stehen.
    --
    -- Eine einzige Zeile beantwortet "was kaufe ich", aber nicht "was
    -- spielen die anderen". Der Unterschied zwischen 45 % und 13 % ist
    -- eine Auskunft. Zwei reichen: ab der dritten Alternative liest man
    -- die Prozentwerte nicht mehr, sondern ueberfliegt sie.
    local ALTERNATIVES = 2

    ---Die naechsthaeufigsten Verzauberungen eines Platzes.
    ---
    ---Sie tragen KEINE Stueckzahl: man kauft eine davon, nicht alle. Ohne
    ---diese Unterscheidung stuenden drei Rollen je Platz auf dem Zettel.
    local function addAlternatives(slot, chosenID)
        local shown = 0
        for _, row in ipairs(ns.Recommend.Enchants(rec, slot)) do
            if row.id ~= chosenID and shown < ALTERNATIVES then
                local entry = Catalog.EnchantByID(row.id)
                rows[#rows + 1] = fill({
                    kind = "enchant", slot = slot, id = row.id,
                    stat = entry and entry.stat or nil,
                    fallback = entry and entry.name or nil,
                    pct = row.pct, maxKey = row.maxKey,
                    need = 0, missing = 0, alt = true,
                })
                shown = shown + 1
            end
        end
    end

    local function add(slot, id, entry, pct, count, open, other)
        rows[#rows + 1] = fill({
            kind = "enchant", slot = slot, id = id,
            stat = entry and entry.stat or nil,
            fallback = entry and entry.name or nil,
            pct = pct, need = count, missing = open,
            -- Was STATTDESSEN drauf ist, wenn es nicht das Empfohlene ist.
            other = other,
        })
        addAlternatives(slot, id)
    end

    -- Steine zuerst: sie sind die groesste Zahl auf dem Zettel und der
    -- Posten, den man am haeufigsten vergisst.
    do
        local gemPick = ns.Recommend.Gem(rec)
        local gem, pct
        if gemPick then
            gem, pct = Catalog.GemByID(gemPick.id), gemPick.pct
        elseif p.main then
            gem = p.cheap and Catalog.CheapGem(p.main, p.second or p.main)
                or Catalog.Gem(p.main, p.second or p.main)
        end
        -- Ohne Haken bei "nur was fehlt" zaehlen alle Sockel, nicht nur die
        -- leeren: die Frage ist dann "welcher Stein gehoert hier rein",
        -- nicht "wie viele muss ich noch kaufen".
        local sockets = p.onlyMissing and scan.emptySockets or scan.totalSockets
        if gem and not foreign and (sockets or 0) > 0 then
            rows[#rows + 1] = fill({
                kind = "gem", slot = "gems", id = gem.id,
                stat = gem.major, minor = gem.minor, pct = pct,
                fallback = gem.name, need = sockets, missing = scan.emptySockets,
            })
            -- Auch hier die naechsthaeufigsten.
            local shown = 0
            for _, row in ipairs(ns.Recommend.Gems(rec)) do
                if row.id ~= gem.id and shown < ALTERNATIVES then
                    local other = Catalog.GemByID(row.id)
                    if other then
                        rows[#rows + 1] = fill({
                            kind = "gem", slot = "gems", id = other.id,
                            stat = other.major, minor = other.minor,
                            pct = row.pct, maxKey = row.maxKey,
                            fallback = other.name,
                            need = 0, missing = 0, alt = true,
                        })
                        shown = shown + 1
                    end
                end
            end
        end

        -- Der besondere Sockel hat seinen eigenen Stein.
        --
        -- Steine mit dem Hauptattribut werden aus den normalen Sockeln
        -- ausdruecklich herausgehalten - und fielen dabei ganz aus dem
        -- Fenster. Archon fuehrt sie als eigene Tabelle, und das ist
        -- richtig: eigener Platz, eigene Auswahl.
        local metaPick = ns.Recommend.MetaGem(rec)
        local meta = metaPick and Catalog.GemByID(metaPick.id)
        -- Sitzt schon einer? Jeder Stein mit Hauptattribut zaehlt, nicht
        -- nur der empfohlene: der Sockel ist dann nicht leer.
        local metaSet = 0
        for gemID, count in pairs(scan.gems or {}) do
            local g = Catalog.GemByID(gemID)
            if g and g.major == "primary" then metaSet = metaSet + count end
        end
        local metaMissing = metaSet > 0 and 0 or 1
        if meta and not foreign and not (p.onlyMissing and metaMissing == 0) then
            rows[#rows + 1] = fill({
                kind = "gem", slot = "meta", id = meta.id,
                stat = meta.major, minor = meta.minor, pct = metaPick.pct,
                maxKey = metaPick.maxKey,
                fallback = meta.name, need = 1, missing = metaMissing,
            })
            -- Auch der besondere Sockel hat eine Auswahl. Archon zeigt
            -- dort drei, und der Abstand zwischen 42 % und 7 % ist
            -- genauso eine Auskunft wie bei den uebrigen Sockeln.
            local shown = 0
            for _, row in ipairs(ns.Recommend.MetaGems(rec)) do
                if row.id ~= meta.id and shown < ALTERNATIVES then
                    local other = Catalog.GemByID(row.id)
                    if other then
                        rows[#rows + 1] = fill({
                            kind = "gem", slot = "meta", id = other.id,
                            stat = other.major, minor = other.minor,
                            pct = row.pct, maxKey = row.maxKey,
                            fallback = other.name,
                            need = 0, missing = 0, alt = true,
                        })
                        shown = shown + 1
                    end
                end
            end
        end
    end

    -- Ringe folgen dem Hauptwert, wenn keine Empfehlung vorliegt.
    do
        -- Erst die Frage "was gehoert drauf", dann "was ist drauf":
        -- ohne den Wunsch kann der Vergleich nicht stattfinden.
        local id, entry, pct = resolve("ring", p.main and Catalog.Enchant("ring", p.main) or nil)
        local count, open, other = counts("ring", id)
        if count > 0 and id then add("ring", id, entry, pct, count, open, other) end
    end

    -- Brust: haengt sonst am Hauptattribut, nicht an der Auswahl.
    do
        local id, entry, pct = resolve("chest", Catalog.ChestEnchant(primary))
        local count, open, other = counts("chest", id)
        if count > 0 and id then add("chest", id, entry, pct, count, open, other) end
    end

    -- Kopf, Schultern, Fuesse teilen sich den Drittwert.
    for _, slot in ipairs({ "helm", "shoulders", "boots" }) do
        local id, entry, pct = resolve(slot,
            p.tertiary and Catalog.Enchant(slot, p.tertiary) or nil)
        local count, open, other = counts(slot, id)
        if count > 0 then
            if id then
                add(slot, id, entry, pct, count, open, other)
            else
                rows[#rows + 1] = { kind = "enchant", slot = slot, need = count, pending = "tertiary" }
            end
        end
    end

    -- Beine und Waffe kann das Addon ohne Daten nicht ableiten: die
    -- Beinverstaerkung haengt an der Ruestungsklasse, die
    -- Waffenverzauberung an der Spec. Liegt eine Empfehlung vor, entfaellt
    -- die Frage.
    for _, def in ipairs({ { slot = "legs", key = "legs" }, { slot = "weapon", key = "weapon" } }) do
        local chosen = p[def.key]
        local fallback = chosen and byID(Catalog.EnchantsFor(def.slot), chosen) or nil
        local id, entry, pct = resolve(def.slot, fallback)
        local count, open, other = counts(def.slot, id)
        if count > 0 then
            if id then
                add(def.slot, id, entry, pct, count, open, other)
            else
                rows[#rows + 1] = { kind = "enchant", slot = def.slot, need = count, pending = def.key }
            end
        end
    end

    return rows
end

---Wie viele Zeilen wirklich gekauft werden muessen.
---@param rows table[]
---@return number
function List.BuyCount(rows)
    local n = 0
    for _, row in ipairs(rows) do
        if not row.pending and not row.alt and (row.buy or 0) > 0 then n = n + 1 end
    end
    return n
end

---Die Einkaufszeilen fuer MEHRERE Speccs, zu einer Liste verschmolzen.
---
---Der urspruengliche Wunsch an dieses Addon: ein Gang zum Auktionshaus
---fuer Heal, Tank und DPS. Zwei Speccs brauchen oft dieselbe Verzauberung
---und manchmal verschiedene - beides muss stimmen.
---
---Verschmolzen wird ueber die Gegenstands-ID, und die Stueckzahlen werden
---ADDIERT. Das Maximum zu nehmen waere falsch: wer zwei Ringe je Spec
---verzaubert, braucht vier Rollen, nicht zwei.
---
---Der eigene Bestand wird dabei nur EINMAL abgezogen. Er liegt einmal im
---Beutel, egal fuer wie viele Speccs eingekauft wird.
---@param scan table
---@param specIDs number[]
---@return table[] rows
function List.BuildMany(scan, specIDs)
    if #specIDs <= 1 then return List.Build(scan) end

    local shown = ns.Profile.SelectedSpec()
    local selectedClass = ns.Profile.SelectedClass()
    local merged, order = {}, {}

    for _, specID in ipairs(specIDs) do
        -- Die Auswahl wandert kurz weiter; List.Build liest sie von dort.
        -- Danach wird sie zurueckgestellt, sonst zeigt das Fenster nach
        -- einem Klick auf den Knopf eine andere Spec als vorher.
        ns.Profile.Select(ns.Compat.ClassOfSpec(specID) or selectedClass, specID)
        for _, row in ipairs(List.Build(scan)) do
            if row.id and not row.pending then
                local have = merged[row.id]
                if have then
                    have.need = (have.need or 0) + (row.need or 0)
                    have.missing = (have.missing or 0) + (row.missing or 0)
                    -- Der Bestand zaehlt einmal, also wird er hier nicht
                    -- erneut abgezogen: was fehlt, addiert sich.
                    have.buy = math.max(0, (have.buy or 0) + (row.buy or 0))
                    have.specs = (have.specs or 1) + 1
                else
                    local copy = {}
                    for key, value in pairs(row) do copy[key] = value end
                    copy.specs = 1
                    merged[row.id] = copy
                    order[#order + 1] = copy
                end
            end
        end
    end

    if selectedClass then
        ns.Profile.Select(selectedClass, shown)
    else
        ns.Profile.SelectActive()
    end
    return order
end
