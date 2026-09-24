-- Zugriff auf Data/Recommendations.lua.
--
-- Die zweite Datenschicht neben dem Katalog, und die mit dem anderen
-- Wahrheitsanspruch: der Katalog sagt, was es gibt - das ist nachpruefbar.
-- Hier steht, was davon benutzt wird, und das ist eine Beobachtung mit
-- Datum und Quelle. Deshalb liegen beide getrennt.
--
-- Die Daten sind nach Modus UND Quelle abgelegt. Zwei Plattformen, die
-- denselben Spielmodus messen, stehen nebeneinander statt uebereinander -
-- nur so kann der Spieler waehlen, wem er glaubt, und nur so kann man
-- sehen, wo sie sich uneinig sind.
--
-- Fehlt die Datei ganz, funktioniert das Addon weiter: dann waehlt der
-- Spieler die Kennwerte selbst.

local _, ns = ...

local Recommend = {}
ns.Recommend = Recommend

-- Der Schluessel fuer "alle Quellen gemittelt". Keine echte Quelle,
-- deshalb ein Name, den keine Plattform je tragen wird.
Recommend.ALL = "*"

-- Die Dungeon-Modi kommen aus einem zweiten, eigenen Addon. Eingehaengt
-- wird EINMAL, direkt in dieselbe Modustabelle: danach ist ein Dungeon
-- ein Modus wie jeder andere, und keine Abfrage weiter unten muss von
-- seiner Herkunft wissen.
local merged = false

---Loest die Verweise auf die geteilten Knotenlisten auf.
---
---Ein Build sind rund fuenfundsiebzig Knoten, und derselbe Build gilt
---fuer viele Dungeons, Bosse und Held-Baeume. In der Datei steht jede
---Liste deshalb nur EINMAL, und der Build traegt ihre Nummer. Hier
---bekommt er die Tabelle selbst - alle Builds mit derselben Wahl zeigen
---danach auf dieselbe, und genau das spart den Speicher. Fuer alles
---dahinter aendert sich nichts: build.nodes ist eine Liste von Knoten,
---wie eh und je.
---@param tbl table|nil
local function resolveNodes(tbl)
    local pool = tbl and tbl.nodeLists
    if not pool or not tbl.modes then return end
    local function fix(build)
        if build and type(build.nodes) == "number" then
            build.nodes = pool[build.nodes] or {}
        end
    end
    for _, bySource in pairs(tbl.modes) do
        for _, part in pairs(bySource) do
            for _, entry in pairs(part.specs or {}) do
                fix(entry.build)
                for _, h in pairs(entry.hero or {}) do fix(h.build) end
            end
        end
    end
end

local resolved = false

local function data()
    local d = MetaCodex_Recommendations
    if d and not resolved then
        resolved = true
        resolveNodes(d)
    end
    if d and not merged and MetaCodex_Dungeons and MetaCodex_Dungeons.modes then
        merged = true
        -- Erst aufloesen, dann einhaengen: der Dungeonvorrat gehoert zu
        -- seiner eigenen Datei.
        resolveNodes(MetaCodex_Dungeons)
        d.modes = d.modes or {}
        for mode, bySource in pairs(MetaCodex_Dungeons.modes) do
            d.modes[mode] = bySource
        end
    end
    return d
end

---@return boolean
function Recommend.Ready()
    local d = data()
    return d ~= nil and d.modes ~= nil
end

---@return number
function Recommend.BuiltOn()
    local d = data()
    return d and d.builtOn or 0
end

---Alle Quellen, die die Datei kennt.
---@return string[]
function Recommend.Sources()
    local d = data()
    return d and d.sources or {}
end

---Die Quellen, die fuer diesen Spielmodus wirklich Daten haben.
---
---Nicht jede Plattform misst jeden Modus: murlok fuehrt kein Raid,
---Warcraft Logs liefert kein PvP-Bracket. Ein Waehler, der trotzdem alle
---anbietet, fuehrt in leere Listen.
---@param mode string
---@return string[]
function Recommend.SourcesFor(mode)
    local d = data()
    local byMode = d and d.modes and d.modes[mode]
    local out = {}
    if not byMode then return out end
    for _, source in ipairs(Recommend.Sources()) do
        if byMode[source] then out[#out + 1] = source end
    end
    return out
end

---@param mode string
---@return boolean
function Recommend.HasMode(mode)
    return #Recommend.SourcesFor(mode) > 0
end

---Wann der Datensatz gebaut wurde.
---@param mode string
---@param source string|nil
---@return number
---Worauf die Prozente einer Quelle ruhen.
---
---Ein Anteil ohne seine Grundlage laedt zum falschen Vergleich ein:
---57 % aus 54 Beobachtungen und 9 % aus zehntausend sehen im Fenster
---gleich aus und sind es nicht. Zurueck kommt, wie viele Messungen
---hinter dieser Spec stehen und aus welchen Schluesseln sie stammen.
---@param specID number
---@param mode string
---@param source string|nil
---@return number|nil sample, number|nil keyFrom, number|nil keyTo
function Recommend.Sample(specID, mode, source)
    local d = data()
    local byMode = d and d.modes and d.modes[mode]
    if not byMode then return nil end
    local best, keys
    for _, name in ipairs(Recommend.SourcesFor(mode)) do
        if not source or source == Recommend.ALL or source == name then
            local part = byMode[name]
            local entry = part and part.specs and part.specs[specID]
            local n = entry and entry.sample or nil
            if n and (not best or n > best) then
                best, keys = n, part.keys
            end
        end
    end
    if not best then return nil end
    return best, keys and keys[1] or nil, keys and keys[2] or nil
end

function Recommend.Stamp(mode, source)
    local d = data()
    local byMode = d and d.modes and d.modes[mode]
    if not byMode then return Recommend.BuiltOn() end
    if source and source ~= Recommend.ALL and byMode[source] then
        return byMode[source].builtOn or 0
    end
    local newest = 0
    for _, part in pairs(byMode) do newest = math.max(newest, part.builtOn or 0) end
    return newest
end

-- ------------------------------------------------------------ Mischen

---Legt mehrere Listen desselben Platzes uebereinander.
---
---Gemittelt wird ueber die Quellen, die den Platz ueberhaupt fuehren -
---nicht ueber alle. Sonst zieht eine Plattform, die einen Slot gar nicht
---misst, den Anteil der anderen rechnerisch nach unten, und ein Eintrag
---mit 90 Prozent bei der einzigen Quelle, die ihn kennt, stuende
---ploetzlich bei 45.
---@param lists table[][]
---@return table[]
local function mergeRows(lists)
    local sum, count = {}, {}
    for _, list in ipairs(lists) do
        for _, row in ipairs(list) do
            sum[row.id] = (sum[row.id] or 0) + row.pct
            count[row.id] = (count[row.id] or 0) + 1
        end
    end
    local out = {}
    for id, total in pairs(sum) do
        out[#out + 1] = { id = id, pct = math.floor(total / count[id] + 0.5) }
    end
    table.sort(out, function(a, b) return a.pct > b.pct end)
    return out
end

---@param entries table[]
---@return table
local function mergeEntries(entries)
    if #entries == 1 then return entries[1] end

    local slots, gemLists = {}, {}
    for _, entry in ipairs(entries) do
        for slot, rows in pairs(entry.enchants or {}) do
            slots[slot] = slots[slot] or {}
            slots[slot][#slots[slot] + 1] = rows
        end
        if entry.gems then gemLists[#gemLists + 1] = entry.gems end
    end

    local merged = { enchants = {}, gems = mergeRows(gemLists) }
    for slot, lists in pairs(slots) do merged.enchants[slot] = mergeRows(lists) end
    return merged
end

---Der Datensatz fuer eine Spezialisierung.
---@param specID number|nil
---@param mode string
---@param source string|nil nil oder Recommend.ALL mittelt ueber alle
---@return table|nil
function Recommend.For(specID, mode, source)
    local d = data()
    if not d or not d.modes or not specID then return nil end

    for _, which in ipairs(Recommend.ModeChain(mode)) do
        local byMode = d.modes[which]
        if byMode then
            if source and source ~= Recommend.ALL then
                local part = byMode[source]
                local entry = part and part.specs and part.specs[specID]
                if entry then return entry end
            else
                local entries = {}
                for _, name in ipairs(Recommend.SourcesFor(which)) do
                    local entry = byMode[name].specs and byMode[name].specs[specID]
                    if entry then entries[#entries + 1] = entry end
                end
                if #entries > 0 then return mergeEntries(entries) end
            end
        end
    end
    return nil
end

-- ------------------------------------------------------------ Auswahl

---Die haeufigste Zeile einer Liste.
---
---Gesucht wird das Maximum statt der ersten Zeile: auf eine Sortierung zu
---vertrauen, die anderswo entsteht, ist genau die Art Annahme, die still
---bricht.
---@param list table[]|nil
---@param reject function|nil
---@return table|nil
local function best(list, reject)
    local top
    for _, entry in ipairs(list or {}) do
        if not reject or not reject(entry) then
            if not top or entry.pct > top.pct then top = entry end
        end
    end
    return top
end

---@param entry table|nil
---@param slot string
---@return table|nil
function Recommend.Enchant(entry, slot)
    if not entry or not entry.enchants then return nil end
    return best(entry.enchants[slot])
end

---Der haeufigste Stein fuer die normalen Sockel.
---
---Steine mit dem Hauptattribut ("Eversong Diamond") gehoeren in den einen
---besonderen Sockel und nicht in die uebrigen. Sie hier mitzuzaehlen
---wuerde bei manchen Speccs den falschen Stein nach oben spuelen.
---@param entry table|nil
---@return table|nil
function Recommend.Gem(entry)
    if not entry then return nil end
    return best(entry.gems, function(row)
        local gem = ns.Catalog.GemByID(row.id)
        return gem ~= nil and gem.major == "primary"
    end)
end

-- ------------------------------------------------- Werte und Ausruestung

---Die Zielwerte einer Spezialisierung.
---
---Anders als Steine und Verzauberungen wird hier NICHT gemittelt: eine
---Rangfolge ist keine Zahl, die man halbieren kann. Bei "alle Plattformen"
---gewinnt deshalb die erste Quelle, die welche hat - und die Oberflaeche
---sagt, welche das war.
---@param specID number|nil
---@param mode string
---@param source string|nil
---@return table|nil stats
---@return string|nil fromSource
function Recommend.Stats(specID, mode, source)
    local d = data()
    local byMode = d and d.modes and d.modes[mode]
    if not byMode or not specID then return nil end

    if source and source ~= Recommend.ALL then
        local part = byMode[source]
        local entry = part and part.specs and part.specs[specID]
        if entry and entry.stats then return entry.stats, source end
        return nil
    end

    -- Bei "alle Plattformen" gewinnt die GEMESSENE Quelle.
    --
    -- Hier stand "die erste, die etwas hat", und das war murlok - also
    -- zeigten "alle Plattformen" und "murlok.io" dasselbe, und ein
    -- Wechsel zwischen ihnen sah aus, als passiere nichts.
    --
    -- Gemittelt wird trotzdem nicht: murlok liefert eine Rangfolge,
    -- Warcraft Logs den Median echter Wertungen. Das sind zwei
    -- verschiedene Dinge, und ihr Mittelwert waere keins von beiden.
    -- Wer misst, gewinnt - erkennbar am Stichprobenumfang.
    local best, bestFrom, bestCount
    for _, name in ipairs(Recommend.SourcesFor(mode)) do
        local part = byMode[name]
        local entry = part and part.specs and part.specs[specID]
        if entry and entry.stats then
            local count = entry.stats.players or 0
            if not best or count > bestCount then
                best, bestFrom, bestCount = entry.stats, name, count
            end
        end
    end
    return best, bestFrom
end

---Die Ausruestung einer Spezialisierung, Platz fuer Platz.
---
---Dieselbe Regel wie bei den Zielwerten: nicht gemittelt. Zwei Plattformen
---mit verschiedenen Gegenstaenden auf demselben Platz zu verrechnen ergaebe
---einen Gegenstand, den niemand traegt.
---@param specID number|nil
---@param mode string
---@param source string|nil
---@return table|nil gear
---@return string|nil fromSource
function Recommend.Gear(specID, mode, source)
    local d = data()
    local byMode = d and d.modes and d.modes[mode]
    if not byMode or not specID then return nil end

    local names = (source and source ~= Recommend.ALL) and { source }
        or Recommend.SourcesFor(mode)
    for _, name in ipairs(names) do
        local part = byMode[name]
        local entry = part and part.specs and part.specs[specID]
        if entry and entry.gear and next(entry.gear) then return entry.gear, name end
    end
    return nil
end

---Die Verbrauchsgueter einer Spezialisierung.
---
---Nicht gemittelt, aus demselben Grund wie bei Ausruestung und Zielwerten:
---zwei Plattformen mit verschiedenen Fläschchen zu verrechnen ergaebe ein
---Fläschchen, das niemand trinkt.
---@param specID number|nil
---@param mode string
---@param source string|nil
---@return table|nil list
---@return string|nil fromSource
function Recommend.Consumables(specID, mode, source)
    local d = data()
    if not d or not d.modes or not specID then return nil end

    for _, which in ipairs(Recommend.ModeChain(mode)) do
        local byMode = d.modes[which]
        if byMode then
            local names = (source and source ~= Recommend.ALL) and { source }
                or Recommend.SourcesFor(which)
            for _, name in ipairs(names) do
                local part = byMode[name]
                local entry = part and part.specs and part.specs[specID]
                if entry and entry.consumables and #entry.consumables > 0 then
                    return entry.consumables, name
                end
            end
        end
    end
    return nil
end

---Die Dungeons, die zu einem Modus einzeln vorliegen.
---
---Kommt als fertige Liste aus den Daten, nicht aus einem Namensmuster:
---die Oberflaeche soll nichts zerlegen muessen. Der `key` ist selbst ein
---Modusschluessel und kann ueberall dort stehen, wo sonst "mplus" steht.
---@param mode string
---@return table[] { key, name }
function Recommend.Dungeons(mode)
    local d = data()
    return (d and d.dungeons and d.dungeons[mode]) or {}
end

---Talente: die einzelnen Anteile und der haeufigste ganze Build.
---
---Nicht gemittelt, aus demselben Grund wie Zielwerte und Ausruestung: ein
---Build ist eine Auswahl, kein Durchschnitt. Zwei Plattformen zu halbieren
---ergaebe einen Build, den niemand spielt.
---@param specID number
---@param mode string
---@param source string|nil
---@return table[]|nil picks  { spell, rank, pct }
---@return table|nil build    { pct, nodes }
---@return string|nil fromSource
function Recommend.Talents(specID, mode, source, hero)
    local d = data()
    local byMode = d and d.modes and d.modes[mode]
    if not byMode or not specID then return nil end

    -- Mit Held-Baum zaehlt nur, was die Quelle fuer DIESEN Baum hat.
    -- "Verstaerkung" und "Verstaerkung mit Sturmbringer" sind zwei
    -- Builds; gemischt stand einer als 22 % da, wo es zwei zu 45 % waren.
    local function view(entry)
        if not hero then return entry end
        return entry and entry.hero and entry.hero[hero] or nil
    end

    local function has(entry, what)
        if not entry then return false end
        if what == "picks" then return entry.talents ~= nil and #entry.talents > 0 end
        return entry.build ~= nil and entry.build.nodes ~= nil and #entry.build.nodes > 0
    end
    local function copyWith(build, extra)
        local out = {}
        for k, v in pairs(build) do out[k] = v end
        for k, v in pairs(extra) do out[k] = v end
        return out
    end

    -- Zwei Fragen, zwei Quellen. "Worin gehen die Meinungen auseinander"
    -- beantwortet die Quelle mit den Einzelanteilen - murlok bei PvP.
    -- "Was stelle ich ein" beantwortet die Quelle mit fertiger Kette -
    -- raider.io. Vorher musste EINE Quelle beides haben, und bei PvP
    -- hatte das keine: murlok fuehrt keine Kette, raider.io keine
    -- Anteile. Also stand nichts da.
    local picks, picksFrom, build, buildFrom
    local names = (source and source ~= Recommend.ALL) and { source } or Recommend.SourcesFor(mode)
    for _, name in ipairs(names) do
        local part = byMode[name]
        local entry = view(part and part.specs and part.specs[specID])
        if not picks and has(entry, "picks") then picks, picksFrom = entry.talents, name end
        if has(entry, "build") then
            if entry.build.text and not (build and build.text) then
                build, buildFrom = entry.build, name
            elseif not build then
                build, buildFrom = entry.build, name
            end
        end
    end

    -- Eine einzelne Quelle ohne Kette: die Kette kommt von "alle
    -- Plattformen", und die Zeile sagt, von wem. Das ist die Regel
    -- fuer alles - was eine Plattform nicht hat, holt sie sich dort.
    if source and source ~= Recommend.ALL and (picks or build) and not (build and build.text) then
        local _, allBuild, _, allFrom = Recommend.Talents(specID, mode, Recommend.ALL, hero)
        if allBuild and allBuild.text and allFrom ~= source then
            build, buildFrom = copyWith(allBuild, { fromSource = allFrom }), allFrom
        end
    end

    -- Keine Kette in dieser Ansicht? Dann die naechstgroessere.
    --
    -- Gefragt wird die ganze Leiter, nicht nur eine Sprosse: erst die
    -- Klammer ohne Dungeon, dann die Aktivitaet selbst. Vorher stand
    -- hier nur BaseMode, und das half beim Raid nicht - "Raid (HC)" IST
    -- schon die Grundschwierigkeit, also zeigte die Bossansicht
    -- "keine Quelle liefert einen fertigen String", obwohl raider.io
    -- fuer die Aktivitaet fuer jede Spec einen hat. Die Einzelanteile
    -- bleiben dabei die der engeren Ansicht: geliehen wird die Kette,
    -- nicht die Messung.
    if (picks or build) and not (build and build.text) then
        for _, other in ipairs(Recommend.ModeChain(mode)) do
            if other ~= mode then
                local _, otherBuild, _, otherFrom =
                    Recommend.Talents(specID, other, Recommend.ALL, hero)
                if otherBuild and otherBuild.text then
                    build, buildFrom =
                        copyWith(otherBuild, { fromBase = true, fromMode = other }), otherFrom
                    break
                end
            end
        end
    end

    -- Gar nichts in dieser Ansicht? Dann die naechstgroessere, ganz.
    --
    -- Eine Spec, die in einem bestimmten Dungeon nie unter den besten
    -- Laeufen auftauchte, hatte dort gar keine Talente - der Abschnitt
    -- blieb leer, obwohl fuer M+ als Ganzes alles vorliegt. Die
    -- Deckungspruefung fand das 156 Mal. Jetzt gilt dieselbe Leiter wie
    -- bei Verbrauchsguetern und Spielern, und die Zeile sagt, aus
    -- welcher Ansicht die Zahlen stammen.
    if not picks and not build then
        for _, other in ipairs(Recommend.ModeChain(mode)) do
            if other ~= mode then
                local otherPicks, otherBuild, otherFrom =
                    Recommend.Talents(specID, other, source, hero)
                if otherPicks or otherBuild then
                    if otherBuild then
                        otherBuild = copyWith(otherBuild, { fromBase = true, fromMode = other })
                    end
                    return otherPicks or {}, otherBuild, otherFrom, otherFrom
                end
            end
        end
    end

    if not picks and not build then return nil end
    if build and buildFrom and picksFrom and buildFrom ~= picksFrom and not build.fromSource and not build.fromBase then
        build = copyWith(build, { fromSource = buildFrom })
    end
    return picks or {}, build, picksFrom or buildFrom, buildFrom
end

---Der Fundort eines Gegenstands aus den Empfehlungen selbst.
---
---Der Katalog kennt nur die laufende Erweiterung; die Beute der alten
---Saisondungeons steht im Journal, aber nicht dort. Der Zusammenbau legt
---sie deshalb neben die Empfehlungen - nur die, die genannt werden.
---@param itemID number
---@return table|nil { enc, inst }
function Recommend.Drop(itemID)
    local d = data()
    return d and d.drops and d.drops[itemID] or nil
end
---Der Stein fuer den BESONDEREN Sockel.
---
---Steine mit dem Hauptattribut ("Eversong Diamond") gehoeren dorthin und
---nirgendwo sonst. Recommend.Gem wirft sie ausdruecklich weg, damit sie
---die normalen Sockel nicht verstellen - und dabei fielen sie ganz aus
---dem Fenster. Archon fuehrt sie als eigene Tabelle "Epic Gems", und zu
---Recht: es ist ein eigener Platz mit eigener Auswahl.
---@param entry table|nil
---@return table|nil
function Recommend.MetaGem(entry)
    if not entry then return nil end
    local top
    for _, row in ipairs(entry.gems or {}) do
        local gem = ns.Catalog.GemByID(row.id)
        if gem and gem.major == "primary" then
            if not top or row.pct > top.pct then top = row end
        end
    end
    return top
end

---Alle Verzauberungen eines Platzes, haeufigste zuerst.
---
---Gebraucht fuer die Alternativen: eine einzige Zeile beantwortet "was
---soll ich kaufen", aber nicht "was spielen die anderen". Archon zeigt
---drei je Platz, und der Unterschied zwischen 45 % und 13 % ist eine
---Auskunft, keine Deko.
---@param entry table|nil
---@param slot string
---@return table[]
function Recommend.Enchants(entry, slot)
    if not entry or not entry.enchants then return {} end
    local list = entry.enchants[slot] or {}
    local out = {}
    for _, row in ipairs(list) do out[#out + 1] = row end
    table.sort(out, function(a, b) return (a.pct or 0) > (b.pct or 0) end)
    return out
end

---Alle Steine fuer die normalen Sockel, haeufigste zuerst.
---@param entry table|nil
---@return table[]
function Recommend.Gems(entry)
    if not entry then return {} end
    local out = {}
    for _, row in ipairs(entry.gems or {}) do
        local gem = ns.Catalog.GemByID(row.id)
        if not (gem and gem.major == "primary") then out[#out + 1] = row end
    end
    table.sort(out, function(a, b) return (a.pct or 0) > (b.pct or 0) end)
    return out
end

---Alle Steine fuer den besonderen Sockel, haeufigste zuerst.
---
---Das Gegenstueck zu Recommend.Gems: dort wird das Hauptattribut
---weggelassen, hier ist es die Bedingung.
---@param entry table|nil
---@return table[]
function Recommend.MetaGems(entry)
    if not entry then return {} end
    local out = {}
    for _, row in ipairs(entry.gems or {}) do
        local gem = ns.Catalog.GemByID(row.id)
        if gem and gem.major == "primary" then out[#out + 1] = row end
    end
    table.sort(out, function(a, b) return (a.pct or 0) > (b.pct or 0) end)
    return out
end

---Hat diese Quelle etwas fuer diesen Abschnitt?
---
---Gebraucht, um es VOR dem Klick zu sagen. Ein Waehler, der alle Quellen
---gleich aussehen laesst, von denen die Haelfte nichts liefert, macht aus
---jeder Auswahl einen Versuch.
---@param specID number
---@param mode string
---@param source string
---@param section string
---@return boolean
function Recommend.HasSection(specID, mode, source, section)
    if section == "stats" then
        return Recommend.Stats(specID, mode, source) ~= nil
    elseif section == "consumables" or section == "remind" then
        return Recommend.Consumables(specID, mode, source) ~= nil
    elseif section == "talents" then
        return Recommend.Talents(specID, mode, source) ~= nil
    elseif section == "gear" then
        return Recommend.Gear(specID, mode, source) ~= nil
    elseif section == "players" then
        return Recommend.Players(specID, mode, source) ~= nil
    elseif section == "enchants" then
        local entry = Recommend.For(specID, mode, source)
        return entry ~= nil and (entry.enchants ~= nil or entry.gems ~= nil)
    end
    -- Guides und Info haengen an keiner Quelle.
    return true
end

---Die Spieler, die eine Quelle oben fuehrt.
---
---Beantwortet, was keine Prozentzahl beantwortet: WER spielt das
---eigentlich so. Gespeichert ist nur, was zur Adresse gehoert - die Seite
---holt sich der Spieler im Browser.
---@param specID number
---@param mode string
---@param source string|nil
---@return table[]|nil, string|nil
---Der Grundmodus einer Aktivitaet.
---
---"M+ (+7 - +21)" und "M+ (High Keys)" sind dieselbe Aktivitaet, nur
---anders geschnitten - und manches haengt am Schnitt, anderes nicht.
---Eine Rangliste der besten Spieler gehoert zur Aktivitaet: wer in M+
---oben steht, steht dort nicht je Schluesselklammer neu.
---@param mode string
---@return string
function Recommend.BaseMode(mode)
    -- "mplus-keys/altar-of-fangs" -> "mplus/altar-of-fangs": der Dungeon
    -- bleibt, nur die Klammer faellt weg. Sonst haette die Dungeonsicht
    -- der Klammer keinen Build, obwohl derselbe Dungeon im Grundmodus
    -- einen mit Kette hat.
    local head, tail = mode:match("^([^/]+)(/.*)$")
    head = head or mode
    tail = tail or ""
    for _, group in ipairs(ns.MODE_GROUPS or {}) do
        if group.brackets then
            for _, key in ipairs(group.keys) do
                if key == head then return group.keys[1] .. tail end
            end
        end
    end
    return mode
end

---Die Modi, in denen eine Auskunft gesucht wird - vom genauesten zum
---allgemeinsten: der gewaehlte, seine Klammer, dann dasselbe ohne
---Dungeon.
---
---Warum es die Kette braucht: die Auswahl eines Dungeons bleibt ueber
---das Abmelden stehen. Wo die Stichprobe dieses Dungeons einen Spec
---nicht erwischt hat, stand danach ein leerer Reiter - und er blieb leer,
---bis man die Aktivitaet wechselte, was den Dungeon loescht. Ein Dungeon
---praezisiert eine Auskunft; fehlt sie dort, ist die des Modus immer noch
---richtig.
---@param mode string
---@return string[]
function Recommend.ModeChain(mode)
    local plain = mode:match("^([^/]+)") or mode
    local out, seen = {}, {}
    for _, which in ipairs({ mode, Recommend.BaseMode(mode), plain, Recommend.BaseMode(plain) }) do
        if which and not seen[which] then
            seen[which] = true
            out[#out + 1] = which
        end
    end
    return out
end

function Recommend.Players(specID, mode, source)
    local d = data()
    if not d or not d.modes or not specID then return nil end
    -- Erst die gewaehlte Aktivitaet, dann ihr Grundmodus. Sonst stand
    -- der Abschnitt bei "M+ (+7 - +21)" leer da, obwohl murlok die
    -- M+-Rangliste sehr wohl fuehrt - sie haengt nur nicht am Schluessel.
    -- Erst die Klammer, dann der Grundmodus - auch wenn die Klammer
    -- existiert. Sie existiert naemlich (aus den Logs), nur ohne
    -- Rangliste; der erste Anlauf prueft nur, OB es den Modus gibt.
    local names = (source and source ~= Recommend.ALL) and { source } or nil
    -- Und zuletzt ohne Dungeon. Eine Rangliste gehoert zur Aktivitaet,
    -- nicht zu einem einzelnen Dungeon - murlok fuehrt die besten
    -- M+-Spieler, nicht die besten von Kings Rest. Stand nach einem
    -- Neuladen noch ein Dungeon in der Auswahl, suchte der Abschnitt
    -- nur dort und fand nichts: leer, bis man die Aktivitaet wechselte.
    for _, which in ipairs(Recommend.ModeChain(mode)) do
        local byMode = d.modes[which]
        if byMode then
            for _, name in ipairs(names or Recommend.SourcesFor(which)) do
                local part = byMode[name]
                local entry = part and part.specs and part.specs[specID]
                if entry and entry.players and #entry.players > 0 then
                    -- Auch den Modus, in dem sie gefunden wurden: unter
                    -- ihm liegen die Profile.
                    return entry.players, name, which
                end
            end
        end
    end
    return nil
end

---Das Profil eines Spielers aus der Rangliste.
---
---Liegt im eigenen Addon MetaCodex_Players, das erst beim ersten Klick
---geladen wird - zwei Megabyte Ausruestung fremder Leute traegt nicht,
---wer nie hinschaut.
---@param mode string
---@param specID number
---@param name string
---@param realm string|nil
---@return table|nil profile
---@return string|nil why  "loading" | "missing"
function Recommend.Player(mode, specID, name, realm)
    if not MetaCodex_Players then
        local loader = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
        if loader then pcall(loader, "MetaCodex_Players") end
        if not MetaCodex_Players then return nil, "missing" end
    end
    local byMode = MetaCodex_Players.modes and MetaCodex_Players.modes[mode]
    local list = byMode and byMode[specID]
    if not list then return nil, "missing" end
    for _, profile in ipairs(list) do
        if profile.name == name and (not realm or profile.realm == realm) then
            return profile
        end
    end
    return nil, "missing"
end

---Die naechsthaeufigsten Builds, je als Unterschied zum haeufigsten.
---
---"Zwanzig Prozent spielen genau diesen" heisst auch: achtzig Prozent
---nicht. Die naechsten sagen, WORIN sie abweichen - und das ist die
---Frage hinter jedem Talentvergleich.
---@param specID number
---@param mode string
---@param source string|nil
---@return table[]|nil
function Recommend.OtherBuilds(specID, mode, source, hero)
    local d = data()
    local byMode = d and d.modes and d.modes[mode]
    if not byMode or not specID then return nil end
    local names = (source and source ~= Recommend.ALL) and { source }
        or Recommend.SourcesFor(mode)
    for _, name in ipairs(names) do
        local part = byMode[name]
        local entry = part and part.specs and part.specs[specID]
        if hero then entry = entry and entry.hero and entry.hero[hero] or nil end
        if entry and entry.builds and #entry.builds > 0 then return entry.builds end
    end
    return nil
end

---Die Held-Baeume, die fuer diese Spec und Aktivitaet gespielt werden.
---
---Aus den Daten, nicht aus einer Liste: welcher Baum vorkommt und wie
---oft, sagt die Messung. Die Anteile der ersten Quelle, die sie hat.
---@param specID number
---@param mode string
---@param source string|nil
---@return table[] { id, pct, players }  haeufigster zuerst
function Recommend.HeroTrees(specID, mode, source)
    local d = data()
    local byMode = d and d.modes and d.modes[mode]
    if not byMode or not specID then return {} end
    local names = (source and source ~= Recommend.ALL) and { source }
        or Recommend.SourcesFor(mode)
    local out = {}
    for _, name in ipairs(names) do
        local part = byMode[name]
        local entry = part and part.specs and part.specs[specID]
        if entry and entry.hero and next(entry.hero) then
            for id, h in pairs(entry.hero) do
                out[#out + 1] = { id = id, pct = h.pct or 0, players = h.players or 0 }
            end
            break
        end
    end
    table.sort(out, function(a, b) return a.pct > b.pct end)
    return out
end

