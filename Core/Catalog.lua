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
                -- Erst die Stufe, wie das Spiel sie fuehrt.
                --
                -- Sonst die Gegenstandsstufe, und ohne sie die ID. Die
                -- ID ist der schlechteste Massstab: sie wird NICHT in
                -- der Reihenfolge der Handwerksstufen vergeben. Bei
                -- drei Stufen derselben Ware steht die hoechste
                -- manchmal auf der kleinsten Zahl - und dann stand im
                -- Fenster "in niedrigerer Qualitaet vorhanden" ueber
                -- der besseren.
                local mineTier = Catalog.Quality(me.id)
                local otherTier = Catalog.Quality(e.id)
                local mine = mineTier or me.ilvl or me.id
                local other = otherTier or e.ilvl or e.id
                -- Nur vergleichbare Masse vergleichen: eine Stufe 2 ist
                -- nicht kleiner als eine Gegenstandsstufe 300.
                if (mineTier ~= nil) == (otherTier ~= nil) then
                    if other < mine then lower[#lower + 1] = e.id
                    elseif other > mine then higher[#higher + 1] = e.id end
                end
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


---Der Zauber zu einer Runenschmiede.
---
---Eine Rune ist eine Verzauberung ohne Gegenstand: der Todesritter
---schmiedet sie an die Waffe, gekauft wird nichts. Gespeichert ist die
---Zauber-ID, den Namen holt der Client.
---@param enchantID number|nil
---@return number|nil spellID
---Der Zauber hinter einem zeitweiligen Waffenbuff - oder nil.
---
---Ein Oel kann man kaufen, Flammenzunge nicht: der Schamane legt sie
---selbst auf, der Schurke sein Gift. In den Berichten steht beides an
---derselben Stelle, nur gibt es zum einen einen Gegenstand und zum
---anderen nur einen Zauber. Den Namen holt der Client.
---@param enchantID number|nil
---@return number|nil spellID
function Catalog.WeaponBuffSpell(enchantID)
    if not enchantID then return nil end
    local c = data()
    return c and c.weaponBuff and c.weaponBuff[enchantID] or nil
end

function Catalog.RuneforgeSpell(enchantID)
    if not enchantID then return nil end
    local c = data()
    return c and c.runeforge and c.runeforge[enchantID] or nil
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
    local out, seen = {}, {}
    for _, entry in ipairs(Catalog.Consumables(kind)) do
        if ns.Compat.ItemCount(entry.id) > 0 then
            seen[entry.id] = true
            out[#out + 1] = entry
        end
    end
    -- Und was sonst noch im Beutel liegt.
    --
    -- Der Katalog fuehrt nur die laufende Erweiterung. Eine Rune von
    -- vorletztem Jahr steht nicht darin - und fehlte deshalb unter "aus
    -- meinen Taschen waehlen", obwohl sie genau dort lag. Gefragt wird
    -- jetzt der Beutel selbst, und was fuer eine Art es ist, sagt der
    -- Client.
    for _, id in ipairs(ns.Compat.BagItems()) do
        if not seen[id] and ns.Compat.ConsumableKind(id) == kind then
            seen[id] = true
            out[#out + 1] = { id = id, name = ns.Compat.ItemInfo(id) }
        end
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

---Die Handwerksstufe eines Gegenstands und ihr Zeichen.
---
---Aus den Spieldaten, nicht gezaehlt. Gezaehlt wurde vorher, wie viele
---Stufen derselben Ware darunter liegen - das setzt voraus, dass die
---Gegenstands-IDs in der Reihenfolge der Stufen vergeben sind, und das
---stimmt nicht. In dieser Erweiterung hat eine Ware ausserdem ZWEI
---Stufen, nicht drei, und ihre Zeichen heissen anders als die alten.
---@param itemID number|nil
---@return number|nil tier
---@return string|nil atlas
function Catalog.Quality(itemID)
    if not itemID then return nil end
    local c = data()
    local set = c and c.quality and c.quality[itemID]
    local entry = set and c.qualitySets and c.qualitySets[set]
    if not entry then return nil end
    return entry.tier, entry.icon
end

---Die Bonus-ID, die einem Stueck seinen "Anlegen:"-Effekt gibt.
---
---Bei den besonderen Stuecken dieser Saison haengt die Wirkung nicht am
---Gegenstand, sondern an einer Bonus-Liste, die mit der Beute kommt.
---Wir bauen den Link aber selbst, damit die GEWAEHLTE Stufe im Tooltip
---steht - und ohne diese Liste fiel der Effekt dabei heraus. Im Fenster
---stand dann ein Helm ohne die Zeile, die ihn ueberhaupt interessant
---macht.
---@param itemID number|nil
---@return number|nil
function Catalog.EffectBonus(itemID)
    if not itemID then return nil end
    local c = data()
    return c and c.effectBonus and c.effectBonus[itemID] or nil
end

---Wird dieses Stueck hergestellt?
---
---Aus den Spieldaten, nicht aus der Beobachtung: ItemSparse markiert
---hergestellte Ausruestung mit einem eigenen Flag. Gegengeprueft an
---allen Stuecken der Erweiterung - kein einziges davon steht im
---Abenteuerjournal, und umgekehrt.
---
---GEBRAUCHT IM FUNDORT-RASTER. Dort standen die Handwerksstuecke unter
---"ohne bekannten Fundort", weil niemand sie als Handwerk gemeldet
---hatte: murlok liefert die Marke nur manchmal mit, ein Rezept-Zauber
---erzeugt sie nicht mehr, und fallen tun sie nirgends.
---@param itemID number|nil
---@return boolean
function Catalog.IsCrafted(itemID)
    if not itemID then return false end
    local c = data()
    return (c and c.crafted and c.crafted[itemID]) and true or false
end

---Gehoert dieses Stueck zum Tier-Set der laufenden Saison?
---
---"Set-Teil" ist die weitere Frage und bleibt, was sie ist: der
---Gegenstand gehoert IRGENDEINEM Set an. Diese hier ist die engere -
---und sie ist die, die der Reiter "Tier-Set" stellt. Dort standen sonst
---das Set der vorigen Saison, die PvP-Ruestung und ein Ring aus einem
---Schmuckset daneben.
---@param itemID number|nil
---@return boolean
function Catalog.IsCurrentTier(itemID)
    if not itemID then return false end
    local c = data()
    return (c and c.tierNow and c.tierNow[itemID]) and true or false
end

---Dungeon oder Schlachtzug?
---
---Aus den Spieldaten: die Karte hinter der Instanz fuehrt ihre Art
---(Map.InstanceType, 1 Gruppeninstanz, 2 Schlachtzug). Das Journal
---selbst sagt es nicht - sein Flag mischt beides.
---
---Warum hier und nicht beim Sammler: der Sammler kennt nur die
---Instanzen, in denen gemessen wurde. Ein Schlachtzug, aus dem niemand
---einen Bericht hochgeladen hat, waere fuer ihn kein Schlachtzug - und
---landete im Waehler unter "Sonstiges".
---@param inst number|nil Journal-Instanz
---@return string|nil "dungeon" | "raid"
function Catalog.InstanceKind(inst)
    if not inst then return nil end
    local c = data()
    return c and c.instKind and c.instKind[inst] or nil
end

---Gehoert diese Instanz zum laufenden Inhalt?
---
---Gemeint ist: steht sie im Journal unter der laufenden Erweiterung oder
---im Pool der laufenden Schluesselsteinsaison. Beides zusammen, weil
---drei der acht Saisondungeons aus aelteren Erweiterungen stammen.
---
---Gebraucht wird das im Fundort-Waehler. Die Feuerlande liefen vorige
---Woche als Zeitwanderung, jemand traegt seitdem ein Stueck von dort -
---gemessen ist das, aber unter "Schlachtzuege" sucht es niemand. Es
---steht deshalb unter "Sonstiges", mit seinem Namen.
---Drei Antworten, nicht zwei: true, false und "weiss nicht".
---
---Ohne die Tabelle - ein Katalog von gestern, gebaut bevor es sie gab -
---darf die Frage nicht mit "nein" beantwortet werden. Dann landete
---jeder Dungeon unter "Sonstiges", und aus einer Verbesserung waere
---ueber Nacht ein Schaden geworden.
---@param inst number|nil
---@return boolean|nil
function Catalog.InstanceCurrent(inst)
    if not inst then return nil end
    local c = data()
    if not (c and c.instCurrent) then return nil end
    return c.instCurrent[inst] and true or false
end

---Die Bosse eines Schlachtzugs, in der Reihenfolge des Journals.
---
---ALLE, nicht nur die, von denen wir etwas gemessen haben. Ein
---Schlachtzug mit acht Bossen, der mal sechs und mal sieben zeigt, ist
---keine Auswahl, sondern ein Raetsel: wer den fehlenden sucht, weiss
---nicht, ob er ihn uebersehen hat oder ob dort nichts faellt. Die
---Antwort "von dem traegt niemand etwas" ist selbst eine Auskunft, und
---sie steht in der leeren Liste.
---@param inst number|nil Journal-Instanz
---@return number[]|nil Begegnungs-IDs
function Catalog.Bosses(inst)
    if not inst then return nil end
    local c = data()
    return c and c.bosses and c.bosses[inst] or nil
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

---Welche Zweitwerte eine Werte-Bonus-ID setzt.
---
---Ein Handwerksstueck bekommt seine Zweitwerte beim Herstellen, ueber
---eine Bonus-ID. Am Gegenstand selbst steht "Zufallswert 1" und
---"Zufallswert 2" - und genau das zeigte das Tooltip, solange wir die
---ID nicht mitgaben.
---@param bonus number|nil
---@return table|nil { "crit", "haste" }
function Catalog.StatsOfBonus(bonus)
    if not bonus then return nil end
    local c = data()
    return c and c.craftStats and c.craftStats[bonus] or nil
end

---Welche Bonus-IDs ueberhaupt Werte setzen.
---
---Gebraucht zum Austauschen: in einer gemessenen Liste steht die
---Wertewahl des Spielers, der sie trug. Wer eine andere sehen will,
---ersetzt genau diese eine ID - und laesst alles andere stehen.
---@return table<number, boolean>
function Catalog.CraftStatBonuses()
    local c = data()
    local out = {}
    for bonus in pairs((c and c.craftStats) or {}) do out[bonus] = true end
    return out
end

---Alle Wertepaare, zur Auswahl.
---
---Aus vier Zweitwerten gibt es sechs Paare, und das Spiel fuehrt genau
---diese sechs. Sortiert wird nach den Namen, damit die Liste bei jedem
---Oeffnen gleich aussieht.
---@return table[] { { bonus = 8790, stats = { "crit", "haste" } }, ... }
function Catalog.CraftStatChoices()
    local c = data()
    local out = {}
    for bonus, keys in pairs((c and c.craftStats) or {}) do
        out[#out + 1] = { bonus = bonus, stats = keys }
    end
    table.sort(out, function(a, b)
        if a.stats[1] ~= b.stats[1] then return a.stats[1] < b.stats[1] end
        return (a.stats[2] or "") < (b.stats[2] or "")
    end)
    return out
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

local warmed = false

---Fordert die Namen aller Katalogeintraege beim Client an.
---
---Der Client kennt einen Gegenstand erst, wenn er ihn einmal gesehen
---hat, und liefert ihn auf Anfrage nach. Ohne Namen gibt es keine Suche
---im Auktionshaus und im Fenster steht eine Nummer.
---
---Frueher hing das am ersten Oeffnen des Fensters. Wer nur die
---Erinnerung vor dem Dungeon sah, hatte nie geoeffnet: /mc probe meldete
---9 von 175 aufgeloesten Namen, und im Erinnerungsfenster stand
---"#271884". Angefordert wird jetzt, sobald der Katalog da ist - vom
---Fenster, von der Erinnerung und von der Sonde.
function Catalog.WarmNames()
    if warmed or not Catalog.Ready() then return end
    warmed = true
    for _, id in ipairs(Catalog.AllIDs()) do ns.Compat.RequestItem(id) end
    -- Und den Probegegenstand: an ihm rechnet der Client aus, welcher
    -- Aufwertungspfad welche Stufe ist.
    local probe = Catalog.ProbeItem and Catalog.ProbeItem()
    if probe then ns.Compat.RequestItem(probe) end
end

local nameByItem  -- einmal gebaut, dann nachgeschlagen

---Der Name eines Gegenstands aus dem Katalog.
---
---Der Client kennt einen Gegenstand erst, wenn er ihn einmal gesehen
---hat; bis dahin gibt GetItemInfo nichts zurueck, und im Fenster stand
---"#271884". Der Katalog stammt aus den DB2-Tabellen desselben Spiels
---und weiss den Namen immer - englisch zwar, aber ein Name ist besser
---als eine Nummer.
---@param itemID number
---@return string|nil
function Catalog.ItemName(itemID)
    local c = data()
    if not c then return nil end
    if not nameByItem then
        nameByItem = {}
        for _, list in pairs(c.consumables or {}) do
            for _, entry in ipairs(list) do
                if entry.name then nameByItem[entry.id] = entry.name end
            end
        end
        for _, entry in ipairs(c.gems or {}) do
            if entry.name then nameByItem[entry.id] = entry.name end
        end
        for _, list in pairs(c.enchants or {}) do
            for _, entry in ipairs(list) do
                if entry.name then nameByItem[entry.id] = entry.name end
            end
        end
    end
    return nameByItem[itemID]
end

---Die englischen Bezeichner einer Spec.
---
---Gebraucht fuer Guide-Adressen. Der Client nennt die Spec in seiner
---Sprache; "gleichgewicht" ergaebe eine Adresse, die es nicht gibt.
---@param specID number
---@return string|nil class, string|nil spec
---Das Hauptattribut einer Spec, aus den Spieldaten.
---
---Der Client beantwortet die Frage seit 12.1 nicht mehr verlaesslich.
---Die Spieltabellen tun es, und sie aendern sich nur mit dem Spiel.
---@param specID number
---@return string|nil "str" | "agi" | "int"
function Catalog.SpecStat(specID)
    local c = data()
    local entry = c and c.specs and c.specs[specID]
    return entry and entry.stat or nil
end

function Catalog.SpecSlug(specID)
    local c = data()
    local entry = c and c.specs and c.specs[specID]
    if not entry then return nil end
    return entry.cls, entry.spec
end

---Die Rolle einer Spezialisierung: "tank", "healer" oder "dps".
---
---AUS DEN SPIELDATEN, nicht vom Client. Der liefert seit 12.1 schon das
---Hauptattribut nicht mehr heraus, und was einmal leer zurueckkam, ist
---als Quelle verbrannt. In ChrSpecialization steht sie als Zahl, und
---die ist gegengerechnet: acht Nullen sind genau die acht Tanks, sieben
---Einsen genau die sieben Heiler.
---
---Gebraucht wird sie fuer Wowheads Guide-Adresse, die seit Midnight auf
---die Rolle endet.
---@param specID number
---@return string|nil
function Catalog.SpecRole(specID)
    local c = data()
    local entry = c and c.specs and c.specs[specID]
    return entry and entry.role or nil
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
