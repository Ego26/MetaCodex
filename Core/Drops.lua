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
function Drops.Matches(stats, wunsch, kombi, fav)
    local gewaehlt = 0
    for _ in pairs(wunsch or {}) do gewaehlt = gewaehlt + 1 end
    if gewaehlt == 0 then return nil end
    -- Der Stern ist kein Wert des Gegenstands, sondern eine Auskunft
    -- ueber den Spieler - die haben wir immer, auch wenn der Client das
    -- Stueck noch nicht kennt.
    if (wunsch or {}).fav and not kombi and fav then return true end
    if (wunsch or {}).fav and kombi and not fav then return false end
    if gewaehlt == 1 and (wunsch or {}).fav then return fav and true or false end
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

---Die Fundorte einer Spec, nach Instanz.
---
---@param specID number|nil
---@param mode string
---@param source string|nil
---@param opts table|nil  worn / minLevel zum Pruefen ueberschreibbar
---@return table[] rows   je Instanz eine Zeile, die ergiebigste zuerst
---@return table summary  wie viele Stuecke woanders herkommen
---@return string|nil fromSource
function Drops.Build(specID, mode, source, opts)
    opts = opts or {}
    local summary = { known = 0, craft = 0, set = 0, pvp = 0, boe = 0, world = 0, past = 0, total = 0 }
    local gear, from = ns.Recommend.Gear(specID, mode, source)
    if not gear then return {}, summary, nil end

    -- Einmal je Aufbau, nicht je Gegenstand: der Client wird sonst
    -- sechzig Mal nach denselben neunzehn Plaetzen gefragt.
    local worn = opts.worn or (ns.Compat and ns.Compat.EquippedIDs and ns.Compat.EquippedIDs()) or {}
    local minLevel = opts.minLevel
        or (ns.Profile and ns.Profile.MinItemLevel and ns.Profile.MinItemLevel()) or 0
    -- EIN EINZELNER PLATZ, wenn einer gewaehlt ist.
    --
    -- Gefiltert wird in der RECHNUNG, nicht erst in der Anzeige: wer
    -- nach dem Kopf fragt, will auch die Reihenfolge nach Koepfen
    -- sortiert haben. Ein Dungeon, der drei Ringe und keinen Helm hat,
    -- steht sonst oben, waehrend die Zeile darunter leer ist.
    --
    -- Derselbe Waehler wie in der Ausruestung, und das mit Absicht: wer
    -- dort den Kopf gewaehlt hat, meint ihn hier auch.
    -- WAS SCHLECHTER IST ALS DAS GETRAGENE, IST KEIN UPGRADE.
    --
    -- Der Abschnitt heisst so, also muss er das auch beantworten. Die
    -- Stufe, auf die es ankommt, ist die aus dem Waehler - dieselbe,
    -- die im Tooltip steht: "auf Held 3 waere das 311". Ohne Wahl
    -- zaehlt die gemessene Stufe des Stuecks.
    --
    -- ES WIRD NICHTS VERSTECKT. Ein Set-Teil oder ein Stueck mit
    -- Anlegen-Effekt kann auch eine Stufe tiefer noch lohnen; das
    -- Kaestchen bleibt darum stehen und tritt nur zurueck.
    local wornLevel = opts.wornLevel
    if wornLevel == nil and ns.Compat and ns.Compat.WornLevels then
        wornLevel = ns.Compat.WornLevels()
    end
    wornLevel = wornLevel or {}
    local zielStufe = opts.level
    if zielStufe == nil and ns.Profile and ns.Profile.TargetLevel then
        zielStufe = ns.Profile.TargetLevel()
    end

    local nurPlatz = opts.slot
    if nurPlatz == nil and ns.Profile and ns.Profile.GearSlot then
        nurPlatz = ns.Profile.GearSlot()
    end

    local byKey, order = {}, {}

    ---Eine Zeile anlegen oder finden.
    ---
    ---Instanz oder Art - beides sind Gruppen von Beute, und beide
    ---sehen im Raster gleich aus. Ein Handwerksstueck faellt nirgends,
    ---aber die Frage "welche sind das" ist dieselbe.
    local function zeile(key, place, inst)
        local row = byKey[key]
        if not row then
            row = {
                kind = "droprow", inst = inst, place = place,
                items = {}, seen = {}, total = 0, have = 0, score = 0,
            }
            byKey[key] = row
            order[#order + 1] = row
        end
        return row
    end

    ---Ein Stueck in eine Zeile legen.
    local function lege(row, item, slot, enc)
        -- Derselbe Gegenstand steht in zwei Listen, wenn er auf zwei
        -- Plaetze passt - ein Ring gehoert an beide Haende. Zweimal
        -- dasselbe Kaestchen waere keine zweite Auskunft.
        local schon = row.seen[item.id]
        if schon then
            if (item.pct or 0) > (schon.pct or 0) then
                schon.pct = item.pct
                schon.slot = slot
            end
            return
        end
        local cell = {
            id = item.id, slot = slot, pct = item.pct or 0,
            ilvl = item.ilvl, enc = enc,
            worn = worn[item.id] and true or false,
            -- Was der Spieler dazu gesagt hat: der Stern ist seine
            -- Wahl, das Ignorieren auch. Beides steht neben der
            -- Messung, nicht in ihr.
            fav = ns.Profile.Favorite and ns.Profile.Favorite(item.id) or false,
            ignored = ns.Profile.Ignored and ns.Profile.Ignored(item.id) or false,
        }
        -- Auf welcher Stufe es bei DIR ankaeme, und was dort schon
        -- haengt. Fehlt eines von beidem, wird nicht geurteilt.
        local waere = zielStufe or cell.ilvl
        local haengt = wornLevel[slot]
        cell.better = (waere and haengt and waere < haengt) or false
        cell.wornLevel = haengt
        row.seen[item.id] = cell
        row.items[#row.items + 1] = cell
        row.total = row.total + 1
        if cell.worn then row.have = row.have + 1 end
    end
    -- Gezaehlt werden STUECKE, nicht Eintraege.
    --
    -- Ein Ring steht in zwei Platzlisten, und die Zeile unter dem
    -- Raster sagt "x von y Stuecken". Zaehlte sie Eintraege, stuende
    -- dort eine Zahl, die kein Spieler nachzaehlen kann.
    local gezaehlt = {}
    for slot, list in pairs(gear) do
        for _, item in ipairs((not nurPlatz or nurPlatz == slot) and list or {}) do
            if item.id and (item.ilvl or 0) >= minLevel then
                local erstmals = not gezaehlt[item.id]
                gezaehlt[item.id] = true
                local enc, inst = ns.Catalog.DropSource(item.id)
                -- Eine Instanz, die es laut Katalog nicht mehr gibt,
                -- gehoert nicht in eine Liste "wohin soll ich laufen".
                -- Unbekannt ist nicht dasselbe wie vorbei: ein Katalog
                -- von gestern weiss es nicht, und dann zeigen wir sie.
                local gone = inst and ns.Catalog.InstanceCurrent(inst) == false
                -- Was in einer vergangenen Instanz faellt, ist weder ein
                -- Ziel noch "ohne Fundort". Es steht nirgends - auch
                -- nicht in der Zahl darunter, die sonst so aussaehe,
                -- als fehlte uns die Auskunft.
                if gone then
                    if erstmals then summary.past = (summary.past or 0) + 1 end
                elseif inst then
                    if erstmals then
                        summary.total = summary.total + 1
                        summary.known = summary.known + 1
                    end
                    local place = ns.Catalog.InstanceKind(inst)
                        or (ns.Recommend.InstanceKind and ns.Recommend.InstanceKind(inst))
                        or "other"
                    lege(zeile("inst:" .. inst, place, inst), item, slot, enc)
                else
                    -- WAS NIRGENDS FAELLT, bekommt trotzdem eine Zeile.
                    --
                    -- Vorher stand darunter nur eine Zahl: "8 aus dem
                    -- Handwerk". Das ist wahr und nutzlos - es sagt
                    -- nicht, WELCHE acht. Als eigene Zeile steht das
                    -- Handwerk neben den Dungeons, mit denselben
                    -- Kaestchen, und laesst sich mit demselben Waehler
                    -- herausgreifen.
                    local wo = elsewhere(item.id, item.kind)
                    if erstmals then
                        summary.total = summary.total + 1
                        summary[wo] = (summary[wo] or 0) + 1
                    end
                    lege(zeile(wo, wo, nil), item, slot, nil)
                end
            end
        end
    end

    for _, row in ipairs(order) do
        row.seen = nil
        -- Das haeufigste Stueck zuerst: wer das Kaestchen ganz links
        -- ansieht, soll das wichtigste sehen.
        table.sort(row.items, function(a, b)
            -- Ignoriertes ans Ende: es steht noch da, damit man sieht,
            -- warum wenig offen ist - aber es draengt sich nicht mehr
            -- vor das, was zaehlt.
            if a.ignored ~= b.ignored then return b.ignored end
            if a.better ~= b.better then return b.better end
            if a.pct ~= b.pct then return a.pct > b.pct end
            return (a.id or 0) < (b.id or 0)
        end)
        -- WAS DEN AUSSCHLAG GIBT, ist das Fehlende.
        --
        -- Ein Dungeon, aus dem man schon alles traegt, ist kein Ziel
        -- mehr - egal wie gut seine Beute ist. Getragene Stuecke zaehlen
        -- deshalb nicht in die Reihenfolge; sie bleiben sichtbar, damit
        -- man sieht, warum dort wenig offen ist.
        local score, offen, bestes, weg, schon = 0, 0, 0, 0, 0
        for _, cell in ipairs(row.items) do
            -- Ignoriertes zaehlt NICHT. Sonst stuende ein Dungeon oben
            -- wegen eines Stuecks, das man nie holen will.
            if cell.ignored then weg = weg + 1
            -- Und was schlechter ist als das Getragene, auch nicht.
            elseif cell.better then schon = schon + 1
            elseif not cell.worn then
                score = score + (cell.pct or 0)
                offen = offen + 1
                if (cell.pct or 0) > bestes then bestes = cell.pct or 0 end
            end
        end
        row.score = score
        row.open = offen
        row.ignored = weg
        row.better = schon
        -- Der hoechste Anteil, den man dort noch NICHT traegt.
        --
        -- Zwei Fragen, zwei Zahlen: "wo hole ich am meisten heraus"
        -- beantwortet die Summe, "wo liegt das Stueck, das die meisten
        -- Besten tragen" dieser Wert. Welche davon die Reihenfolge
        -- bestimmt, entscheidet der Spieler im Waehler - und nicht wir
        -- fuer ihn, denn beide Fragen sind vernuenftig.
        row.best = bestes
    end

    -- Wonach sortiert wird, sagt die Einstellung.
    local wie = opts.sort or (ns.Profile.DropsSort and ns.Profile.DropsSort()) or "sum"
    table.sort(order, function(a, b)
        local ea, eb = a.score, b.score
        if wie == "best" then ea, eb = a.best or 0, b.best or 0 end
        if ea ~= eb then return ea > eb end
        -- Gleichstand: die andere Zahl entscheidet, und erst danach die
        -- Nummer - damit die Reihenfolge stabil ist und nicht bei jedem
        -- Auffrischen springt.
        if (a.score or 0) ~= (b.score or 0) then return (a.score or 0) > (b.score or 0) end
        if a.open ~= b.open then return a.open > b.open end
        return (a.inst or 0) < (b.inst or 0)
    end)

    return order, summary, from
end

