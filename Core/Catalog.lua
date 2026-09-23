-- Zugriff auf Data/Catalog.lua.
--
-- Die EINZIGE Stelle, die das Format der erzeugten Datei kennt. Wenn der
-- Generator sein Format aendert, aendert sich diese Datei - und sonst keine.

local _, ns = ...

local Catalog = {}
ns.Catalog = Catalog

local function data()
    return MetaCodex_Catalog
end

---@return boolean
function Catalog.Ready()
    local c = data()
    return c ~= nil and c.gems ~= nil and c.enchants ~= nil and #c.gems > 0
end

---@return string build, number builtOn
function Catalog.Stamp()
    local c = data()
    if not c then return "?", 0 end
    return c.build or "?", c.builtOn or 0
end

---Alle Verzauberungen eines Platzes, so wie der Generator sie sortiert hat:
---nach Kennwert, darin die staerkste zuerst.
---@param slot string
---@return table[]
function Catalog.EnchantsFor(slot)
    local c = data()
    return (c and c.enchants and c.enchants[slot]) or {}
end

---Die passende Verzauberung fuer einen Platz und einen Kennwert.
---
---Gibt es zwei Zeilen mit demselben Kennwert - und genau das ist in dieser
---Erweiterung bei Ringen der Fall -, gewinnt die mit dem hoeheren
---Skalierungswert. Der steht im Katalog, also muss hier nichts geraten
---werden.
---@param slot string
---@param stat string
---@return table|nil
function Catalog.Enchant(slot, stat)
    local best
    for _, e in ipairs(Catalog.EnchantsFor(slot)) do
        if e.stat == stat and (not best or (e.power or 0) > (best.power or 0)) then
            best = e
        end
    end
    return best
end

---Die Brustverzauberung haengt am Hauptattribut, nicht an der Auswahl:
---es gibt eine Zeile je Attribut und eine, die alle drei abdeckt. Welche
---staerker ist, sagt wieder der Skalierungswert.
---@param primary string "agi", "str" oder "int"
---@return table|nil
function Catalog.ChestEnchant(primary)
    local best
    for _, e in ipairs(Catalog.EnchantsFor("chest")) do
        if e.stat == primary or e.stat == "primary" then
            if not best or (e.power or 0) > (best.power or 0) then best = e end
        end
    end
    return best
end

---Der Stein mit dem gewuenschten Haupt- und Nebenwert.
---
---Reine Steine (ein Wert) tragen denselben Wert zweimal; wer Tempo/Tempo
---waehlt, bekommt also den reinen Tempostein und keinen Mischling.
---@param major string
---@param minor string
---@return table|nil
function Catalog.Gem(major, minor)
    local c = data()
    if not c then return nil end
    local best
    for _, g in ipairs(c.gems) do
        if g.major == major and g.minor == minor and g.q <= 3 then
            if not best or g.q > best.q or (g.q == best.q and g.ilvl > best.ilvl) then
                best = g
            end
        end
    end
    return best
end

---Die guenstigere Stufe desselben Steins: gleiche Werte, geringere Qualitaet.
---@param major string
---@param minor string
---@return table|nil
function Catalog.CheapGem(major, minor)
    local c = data()
    if not c then return nil end
    local best
    for _, g in ipairs(c.gems) do
        if g.major == major and g.minor == minor and g.q <= 2 then
            if not best or g.ilvl > best.ilvl then best = g end
        end
    end
    return best
end

---Jede ID, die im Katalog vorkommt. Gebraucht, um die Namen vorzuladen -
---ohne Namen gibt es keine Suche im Auktionshaus.
---@return number[]
function Catalog.AllIDs()
    local c = data()
    local ids = {}
    if not c then return ids end
    for _, list in pairs(c.enchants) do
        for _, e in ipairs(list) do
            ids[#ids + 1] = e.id
            if e.alt then ids[#ids + 1] = e.alt end
        end
    end
    for _, g in ipairs(c.gems) do ids[#ids + 1] = g.id end
    return ids
end

---Die anderen Qualitaetsstufen desselben Gegenstands.
---
---Handwerksware gibt es in Bronze, Silber und Gold, und jede Stufe hat
---ihre eigene ID - die Empfehlung nennt eine davon. Wer die Silberstufe
---im Beutel hat, hat den Trank trotzdem, nur schwaecher; wer Gold hat,
---braucht Silber nicht. Zusammengehoerig ist, was gleich heisst und
---von derselben Art ist; die Reihenfolge sagt die Gegenstandsstufe.
---@param id number
---@return number[] lower   IDs geringerer Qualitaet
---@return number[] higher  IDs hoeherer Qualitaet
function Catalog.Tiers(id)
    local c = data()
    if not c then return {}, {} end
    local lower, higher = {}, {}
    local function collect(list, me)
        for _, e in ipairs(list) do
            if e.id ~= me.id and e.name == me.name then
                local mine = me.ilvl or me.id
                local other = e.ilvl or e.id
                if other < mine then lower[#lower + 1] = e.id
                elseif other > mine then higher[#higher + 1] = e.id end
            end
        end
    end
    for _, g in ipairs(c.gems) do
        if g.id == id then collect(c.gems, g) return lower, higher end
    end
    for _, list in pairs(c.consumables or {}) do
        for _, e in ipairs(list) do
            if e.id == id then collect(list, e) return lower, higher end
        end
    end
    -- Verzauberungen fuehren ihre guenstigere Stufe als `alt`.
    for _, list in pairs(c.enchants or {}) do
        for _, e in ipairs(list) do
            if e.id == id and e.alt then lower[1] = e.alt return lower, higher end
            if e.alt == id then higher[1] = e.id return lower, higher end
        end
    end
    return lower, higher
end

---Ein Stein anhand seiner ID. Gebraucht, um eine Empfehlung einzuordnen,
---ohne dass die Empfehlungsschicht das Katalogformat kennen muss.
---@param id number
---@return table|nil
function Catalog.GemByID(id)
    local c = data()
    if not c then return nil end
    for _, gem in ipairs(c.gems) do
        if gem.id == id then return gem end
    end
    return nil
end

---Eine Verzauberung anhand ihrer ID, ueber alle Plaetze.
---@param id number
---@return table|nil entry
---@return string|nil slot
function Catalog.EnchantByID(id)
    local c = data()
    if not c then return nil end
    for slot, list in pairs(c.enchants) do
        for _, entry in ipairs(list) do
            if entry.id == id or entry.alt == id then return entry, slot end
        end
    end
    return nil
end

---Verbrauchsgueter einer Art, so wie der Generator sie sortiert hat:
---hoechster Rang zuerst.
---
---Warum das im Katalog steht und nicht bei den Beobachtungen: welcher Art
---ein Gegenstand ist, gehoert zum Gegenstand. Sonst haette dieselbe
---Auskunft zwei Quellen, und eine geaenderte Einteilung braeuchte einen
---neuen Sammellauf statt eines neuen Katalogs.
---@param kind string "flask", "food", "potion", "heal", "other" oder "vantus"
---@return table[]
function Catalog.Consumables(kind)
    local c = data()
    return (c and c.consumables and c.consumables[kind]) or {}
end


---Der Gegenstand zu einer Verzauberung.
---
---Im Link eines getragenen Stuecks steht die Zauberkennung, im Katalog
---stehen Gegenstaende. Ohne diese Karte weiss das Addon nur, DASS etwas
---drauf ist.
---@param enchantID number|nil
---@return number|nil itemID
function Catalog.EnchantItemOf(enchantID)
    if not enchantID then return nil end
    local c = data()
    return c and c.enchantItem and c.enchantItem[enchantID] or nil
end

---Die Gegenstaende einer Art, die der Spieler wirklich dabeihat.
---
---Gebraucht fuer die Wahl "das nehme ich": eine Liste von 192 Speisen
---waere ein Katalog zum Durchscrollen, der Beutel ist die Antwort auf
---"was benutze ich denn".
---@param kind string
---@return table[] entries
function Catalog.OwnedOfKind(kind)
    local out = {}
    for _, entry in ipairs(Catalog.Consumables(kind)) do
        if ns.Compat.ItemCount(entry.id) > 0 then out[#out + 1] = entry end
    end
    return out
end

---Woher ein Gegenstand kommt.
---
---Gibt IDs zurueck, keine Namen. Der Client loest sie ueber das
---Abenteuerjournal auf und trifft damit seine eigene Sprache - dieselbe
---Regel wie bei allem anderen hier.
---@param itemID number
---@return number|nil encounterID
---@return number|nil instanceID
function Catalog.DropSource(itemID)
    local c = data()
    local where = c and c.drops and c.drops[itemID]
    -- Nicht im Katalog? Vielleicht in den Empfehlungen: die tragen den
    -- Fundort fuer Beute aus aelteren Erweiterungen mit.
    if not where and ns.Recommend and ns.Recommend.Drop then where = ns.Recommend.Drop(itemID) end
    if not where then return nil end
    return where.enc, where.inst
end

---PvP-Ware: Eroberung, Ehre oder das Handwerksstueck dazu.
---@param itemID number
---@return string|nil "conquest" | "honor" | "pvpcraft"
function Catalog.Origin(itemID)
    local c = data()
    return c and c.origins and c.origins[itemID] or nil
end

---Set-Teil oder Handwerksstueck?
---
---Eigenschaft des Gegenstands, nicht der Beobachtung. murlok liefert sie
---mit, Warcraft Logs nicht - und statt einer Auskunft aus zwei Quellen,
---die einander irgendwann widersprechen, steht sie hier einmal.
---@param itemID number
---@return string|nil "set" oder "craft"
function Catalog.ItemKind(itemID)
    local c = data()
    return c and c.kinds and c.kinds[itemID] or nil
end

local kindByItem  -- einmal gebaut, dann nachgeschlagen

---Welche Art von Verbrauchsgut ein Gegenstand ist.
---@param itemID number
---@return string|nil
function Catalog.ConsumableKind(itemID)
    local c = data()
    if not c or not c.consumables then return nil end
    -- Einmal umdrehen statt bei jeder Zeile achthundert Eintraege
    -- durchzugehen. Die Tabelle aendert sich zur Laufzeit nicht.
    if not kindByItem then
        kindByItem = {}
        for kind, list in pairs(c.consumables) do
            for _, entry in ipairs(list) do kindByItem[entry.id] = kind end
        end
    end
    return kindByItem[itemID]
end

---Die englischen Bezeichner einer Spec.
---
---Gebraucht fuer Guide-Adressen. Der Client nennt die Spec in seiner
---Sprache; "gleichgewicht" ergaebe eine Adresse, die es nicht gibt.
---@param specID number
---@return string|nil class, string|nil spec
function Catalog.SpecSlug(specID)
    local c = data()
    local entry = c and c.specs and c.specs[specID]
    if not entry then return nil end
    return entry.cls, entry.spec
end

---Die Bonus-ID, die einen Gegenstand um so viele Stufen verschiebt.
---
---Damit laesst sich ein Gegenstand auf einer ANDEREN Stufe zeigen, mit
---richtigen Werten - genau das, was KeystoneLoot macht. Die Grundstufe
---kennt der Client selbst; gebraucht wird nur der Weg von dort zum Ziel.
---@param delta number
---@return number|nil
function Catalog.LevelDeltaBonus(delta)
    local c = data()
    return c and c.levelDelta and c.levelDelta[delta] or nil
end

---Der Name eines Held-Baums, in der Sprache des Fensters.
---
---Aus dem Katalog, nicht vom Client: der kann einen Held-Baum einer
---fremden Spec nicht benennen, und die eigene ist nicht die einzige.
---@param subTreeID number
---@return string
function Catalog.SubTreeName(subTreeID)
    local c = data()
    local row = c and c.subtrees and c.subtrees[subTreeID]
    if not row then return "#" .. tostring(subTreeID) end
    if ns.CurrentLocale() == "deDE" then return row.de or row.en end
    return row.en
end

---Die Runen des Omnium Folio, Zeile fuer Zeile.
---@return table[]|nil rows  je Zeile { { spell, auras }, ... }
function Catalog.Folio()
    local c = data()
    return c and c.folio or nil
end

---Die Aufwertungspfade der laufenden Saison.
---
---Je Pfad die Bonus-IDs in Rangfolge. Was sie an Stufe bringen, steht
---nicht hier - das rechnet der Client, siehe Compat.TrackFor.
---@return table[]|nil { path, name, lists }
function Catalog.Tracks()
    local c = data()
    return c and c.tracks or nil
end

---Irgendein Gegenstand der Saison, um den Client rechnen zu lassen.
---
---Fuer die Menuebeschriftung braucht es EINEN Gegenstand, an den man
---eine Pfad-Bonus-ID haengen kann. Welcher, ist egal; dass es immer
---derselbe ist, nicht - sonst schwankt die Beschriftung.
---@return number|nil itemID
function Catalog.ProbeItem()
    local c = data()
    if not c or not c.drops then return nil end
    local best
    for id in pairs(c.drops) do
        if not best or id < best then best = id end
    end
    return best
end
