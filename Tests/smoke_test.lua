-- Laedt das Addon wirklich - in der Reihenfolge der TOC, gegen eine
-- Attrappe der WoW-API - und bedient es danach.
--
-- Der Anlass fuer diese Datei: das Fenster ging im Spiel auf, aber auf den
-- Knoepfen standen die Uebersetzungsschluessel statt der Texte. Ein
-- Syntaxpruefer sieht so etwas nie, und bis zum naechsten /reload auch
-- niemand sonst.

package.path = BASE .. "/Tests/?.lua;" .. package.path
local wow = require("wow_stub")

-- Die Attrappe ersetzt `print`, um zu sehen, was das Addon meldet. Unsere
-- eigene Ausgabe muss also vorher gesichert werden, sonst laeuft der
-- Testbericht in denselben Eimer.
local say = print

local fails = 0
local function check(name, ok, detail)
    if ok then
        say("  ok   " .. name .. (detail and ("  -> " .. detail) or ""))
    else
        fails = fails + 1
        say("  FAIL " .. name .. (detail and ("  -> " .. detail) or ""))
    end
end

-- Ein Link, wie ihn der Client liefert: item:ID:VERZAUBERUNG:STEIN1:STEIN2:...
local function link(id, enchant, gem1, gem2)
    return ("|Hitem:%d:%s:%s:%s:::::80:::::|h[Item]|h"):format(
        id, enchant or "", gem1 or "", gem2 or "")
end

wow.install({
    locale = "deDE",
    classID = 11,                          -- Druide
    specID = 105,                          -- Wiederherstellung
    specName = "Wiederherstellung",
    stats = { 100, 300, 500, 900 },        -- Intelligenz am hoechsten
    -- Die eigenen Kampfwertungen, nach Index. Absichtlich unter jedem
    -- gemessenen Zielwert, damit "es fehlen noch" geprueft werden kann.
    ratings = { [11] = 400, [18] = 500, [26] = 300, [29] = 200 },
    auctionator = true,
    -- Was der Client fuer eine Pfad-Bonus-ID an Stufe meldet. Die Zahlen
    -- passen zur Belohnungstabelle des Stubs: 280 ist +2 am Ende, 292
    -- ist +6, 311 ist +10 aus der Schatzkammer. Zwei Pfade treffen
    -- dieselbe Stufe - genau der Fall, den die Rangregel entscheidet.
    bonusLevels = {
        [12833] = 280,                     -- Champion 1
        [12837] = 292, [12841] = 292,      -- Champion 5 / Held 1
        [12845] = 311, [12849] = 311,      -- Held 5 / Mythisch 1
    },
    equipped = {
        [1]  = link(200001, nil, "111"),   -- Kopf: 2 Sockel, einer belegt
        [3]  = link(200003),               -- Schultern, unverzaubert
        [5]  = link(200005, "7364"),       -- Brust, verzaubert
        [7]  = link(200007),               -- Beine
        [8]  = link(200008),               -- Fuesse
        [11] = link(200011),               -- Ring 1: 1 Sockel, leer
        [12] = link(200012, "7370"),       -- Ring 2, verzaubert
        [16] = link(200016),               -- Waffe
    },
    sockets = { [200001] = 2, [200011] = 1 },
    owned = {},
})

-- --------------------------------------------------------------- Laden

local ns = {}
local FILES = {}
for line in TOC:gmatch("[^\r\n]+") do
    local path = line:match("^([%w\\_]+%.lua)%s*$")
    if path then FILES[#FILES + 1] = path:gsub("\\", "/") end
end
check("TOC gelesen", #FILES >= 14, #FILES .. " Dateien")

for _, path in ipairs(FILES) do
    local chunk, err = loadfile(BASE .. "/" .. path)
    if not chunk then
        check("laden: " .. path, false, tostring(err))
    else
        local ok, runErr = pcall(chunk, "MetaCodex", ns)
        check("laden: " .. path, ok, ok and nil or tostring(runErr))
    end
end
-- Das Datenaddon wird im Spiel erst beim Oeffnen des Fensters geladen.
-- Hier wird es gleich mitgeladen, damit die Pruefungen gegen echte Daten
-- laufen - aber ueber dieselbe TOC, damit ein vergessener Dateieintrag
-- auffaellt.
check("Datenaddon vorhanden", DATA_TOC ~= nil and DATA_TOC ~= "")
if DATA_TOC and DATA_TOC ~= "" then
    local count = 0
    for line in DATA_TOC:gmatch("[^\r\n]+") do
        local name = line:match("^([%w_]+%.lua)%s*$")
        if name then
            local chunk, err = loadfile(BASE .. "/MetaCodex_Data/" .. name)
            if not chunk then
                check("laden: " .. name, false, tostring(err))
            else
                local ok, runErr = pcall(chunk, "MetaCodex_Data", {})
                check("laden: " .. name, ok, ok and nil or tostring(runErr))
                count = count + 1
            end
        end
    end
    check("Datendateien geladen", count == 2, count .. " Dateien")
end

-- Das Dungeon-Addon ist freiwillig. Hier wird es mitgeladen, damit die
-- Dungeon-Pruefungen ueberhaupt etwas zu pruefen haben; im Spiel laedt es
-- erst, wenn jemand einen Dungeon waehlt.
-- Das Spieler-Addon ebenso: im Spiel laedt es beim ersten Klick auf
-- einen Spieler, hier vorab, damit die Ansicht etwas zu zeigen hat.
if PLAYERS_TOC and PLAYERS_TOC ~= "" then
    for line in PLAYERS_TOC:gmatch("[^\r\n]+") do
        local name = line:match("^([%w_]+%.lua)%s*$")
        if name then
            local chunk = loadfile(BASE .. "/MetaCodex_Players/" .. name)
            check("laden: " .. name, chunk ~= nil)
            if chunk then
                check("ausfuehren: " .. name, pcall(chunk, "MetaCodex_Players", {}))
            end
        end
    end
end

if DUNGEON_TOC and DUNGEON_TOC ~= "" then
    for line in DUNGEON_TOC:gmatch("[^\r\n]+") do
        local name = line:match("^([%w_]+%.lua)%s*$")
        if name then
            local chunk = loadfile(BASE .. "/MetaCodex_Dungeons/" .. name)
            check("laden: " .. name, chunk ~= nil)
            if chunk then
                check("ausfuehren: " .. name, pcall(chunk, "MetaCodex_Dungeons", {}))
            end
        end
    end
end

if fails > 0 then
    say("\nAbbruch: das Addon laedt nicht.")
    os.exit(1)
end

-- ------------------------------------------------------------- Anmeldung

wow.fire("PLAYER_LOGIN")
check("SavedVariables angelegt", type(MetaCodexDB) == "table")

-- Der Fehler, der diese Datei ausgeloest hat: mehrere RegisterLocale-
-- Aufrufe je Sprache duerfen sich nicht gegenseitig ausloeschen.
local L = ns.L
check("Uebersetzung erster Block", L["TITLE"] ~= "TITLE", L["TITLE"])
check("Uebersetzung zweiter Block", L["STATSHORT_crit"] ~= "STATSHORT_crit", L["STATSHORT_crit"])
check("Uebersetzung dritter Block", L["SPEC_ACTIVE"] ~= "SPEC_ACTIVE", L["SPEC_ACTIVE"])
check("Formatstring erhalten", L["DATA_AS_OF"]:find("%%s") ~= nil, L["DATA_AS_OF"])
local missingKeys = {}
for _, key in ipairs({ "BTN_CREATE_LIST", "BTN_SEARCH", "PICK_HINT", "LBL_MAIN_STAT",
                       "SLOT_ring", "STAT_haste", "OPT_CHEAP", "NEED", "PROBE_HEADER",
                       "FOREIGN_CLASS", "SHOW_ALL_HINT", "PROBE_SPEC" }) do
    if L[key] == key then missingKeys[#missingKeys + 1] = key end
end
check("keine offenen Schluessel", #missingKeys == 0, table.concat(missingKeys, ", "))

-- --------------------------------------------------------- Ausruestung

local scan = ns.Gear.Scan()
check("Ausruestung gelesen", #scan.slots == 8, #scan.slots .. " Plaetze")
check("leere Sockel gezaehlt", scan.emptySockets == 2, tostring(scan.emptySockets))
check("alle Sockel gezaehlt", scan.totalSockets == 3, tostring(scan.totalSockets))
local ringMissing, ringTotal = ns.Gear.Missing(scan, "ring")
check("ein Ring noch unverzaubert", ringMissing == 1 and ringTotal == 2,
    ringMissing .. " von " .. ringTotal)
check("Brust zaehlt als erledigt", ns.Gear.Missing(scan, "chest") == 0)
check("Hauptattribut erkannt", ns.Compat.PrimaryStat() == "int", ns.Compat.PrimaryStat())

-- ------------------------------------------------------------- Liste

ns.Profile.Set("main", "haste")
ns.Profile.Set("second", "crit")
ns.Profile.Set("tertiary", "leech")

-- Die EMPFEHLUNG je Platz, nicht die Alternativen darunter.
--
-- Unter jeder Empfehlung stehen jetzt bis zu zwei Alternativen mit
-- demselben Platz. Ohne diese Unterscheidung ueberschriebe die letzte
-- Alternative die Zeile, um die es geht - und alle Stueckzahlen waeren
-- ploetzlich null.
local function bySlot(rows)
    local map = {}
    for _, row in ipairs(rows) do
        if not row.alt and not map[row.slot] then map[row.slot] = row end
    end
    return map
end

-- Vollansicht ist die Vorgabe: sie beantwortet "gehoert das Richtige
-- drauf", nicht nur "was fehlt noch".
check("Vollansicht ist Vorgabe", ns.Profile.Current().onlyMissing == false)
local full = bySlot(ns.List.Build(scan))
check("Vollansicht zeigt die verzauberte Brust", full.chest ~= nil)
check("Vollansicht zaehlt beide Ringe", full.ring and full.ring.need == 2,
    full.ring and tostring(full.ring.need))
check("Vollansicht zaehlt alle Sockel", full.gems and full.gems.need == 3,
    full.gems and tostring(full.gems.need))
check("erledigte Zeile braucht keinen Kauf", full.chest and full.chest.buy == 0
    and full.chest.missing == 0, full.chest and ("buy " .. full.chest.buy))

-- Mit Haken bleibt nur, was fehlt.
ns.Profile.Set("onlyMissing", true)
local rows = ns.List.Build(scan)
local only = bySlot(rows)
check("Filter laesst die Brust weg", only.chest == nil)
check("Filter zaehlt nur den offenen Ring", only.ring and only.ring.need == 1)
-- Im Kopf sitzt ein fremder Stein (111). Er fuellt den Sockel, aber er
-- ist nicht der empfohlene - und damit ist dort noch etwas zu tun.
-- Frueher zaehlten nur die leeren, und die Zeile sagte "bereits drauf",
-- waehrend in den Sockeln etwas ganz anderes sass.
check("Filter zaehlt die Sockel ohne den empfohlenen Stein",
    only.gems and only.gems.need == 3,
    only.gems and tostring(only.gems.need))
-- ------------------------------------------------------- Empfehlungen

check("Empfehlungen geladen", ns.Recommend.Ready())
check("M+ hat Daten", ns.Recommend.HasMode("mplus") == true)
check("Raid hat Daten", ns.Recommend.HasMode("raid") == true)
-- Hier stand einmal "solo". Den Modus gibt es inzwischen - murlok
-- fuehrt Solo Shuffle unter /solo. Also ein Name, der keiner werden kann.
check("unbekannter Modus hat keine", ns.Recommend.HasMode("gibtsnicht") == false)
local sources = table.concat(ns.Recommend.Sources(), ", ")
check("beide Quellen benannt",
    sources:find("murlok") ~= nil and sources:find("warcraftlogs") ~= nil, sources)
check("Stempel je Modus", ns.Recommend.Stamp("mplus") > 0,
    tostring(ns.Recommend.Stamp("mplus")))

-- Die Quellen stehen nebeneinander, nicht uebereinander. Bei M+ messen
-- inzwischen beide, und genau das ist der Fall, der frueher gefaehrlich
-- war: waere nach Modus zusammengefasst worden, haette die eine die
-- andere ueberschrieben. Beide muessen einzeln abrufbar bleiben.
local mplusSources = table.concat(ns.Recommend.SourcesFor("mplus"), ",")
check("M+ kennt beide Quellen",
    mplusSources:find("murlok") ~= nil
        and mplusSources:find("warcraftlogs") ~= nil, mplusSources)
-- Und die Trennung haelt: den Arenamodus messen murlok und die
-- Battle.net-Rangliste. raider.io steht dabei fuer die verifizierten
-- Strings aus den Profilen. Warcraft Logs hat dort nichts zu suchen -
-- und die Reihenfolge ist fest: murlok zuerst, Battle.net zuletzt.
do
    local arena = table.concat(ns.Recommend.SourcesFor("2v2"), ",")
    check("2v2: murlok, raider.io, Battle.net - kein Warcraft Logs",
        arena:find("warcraftlogs") == nil and arena:sub(1, 9) == "murlok.io"
            and (arena:find("Battle.net") == nil or arena:sub(-10) == "Battle.net"),
        arena)
end
-- raider.io steht beim Raid dabei, seit die Ketten aus den Profilen der
-- geloggten Spieler kommen - geprueft gegen die Talente des Kampfes.
check("Raid: Warcraft Logs misst, raider.io liefert verifizierte Ketten",
    table.concat(ns.Recommend.SourcesFor("raid"), ",") == "raider.io,warcraftlogs.com",
    table.concat(ns.Recommend.SourcesFor("raid"), ","))

-- Eine einzelne Quelle und "alle gemittelt" muessen beide etwas liefern.
local single = ns.Recommend.For(105, "mplus", "murlok.io")
local merged = ns.Recommend.For(105, "mplus", ns.Recommend.ALL)
check("einzelne Quelle liefert", single ~= nil and single.enchants ~= nil)
check("gemittelt liefert", merged ~= nil and merged.enchants ~= nil)
-- Eine Quelle, die diesen Modus nicht misst, liefert nichts - und zwar
-- nichts statt irgendetwas. Battle.net fuehrt nur PvP-Ranglisten; frueher
-- stand hier Warcraft Logs, das M+ inzwischen vollstaendig misst.
check("Quelle ohne diesen Modus liefert nichts",
    ns.Recommend.For(105, "mplus", "Battle.net") == nil)
check("erfundene Quelle liefert nichts",
    ns.Recommend.For(105, "mplus", "example.invalid") == nil)

-- Mit Daten entfaellt die Rueckfrage nach Waffe und Beinen - genau das ist
-- der Zweck der zweiten Datenschicht.
check("Waffe kommt aus den Daten",
    only.weapon and only.weapon.id ~= nil and only.weapon.pct ~= nil,
    only.weapon and (tostring(only.weapon.fallback) .. " " .. tostring(only.weapon.pct) .. "%"))
check("Beine kommen aus den Daten",
    only.legs and only.legs.id ~= nil and only.legs.pct ~= nil,
    only.legs and tostring(only.legs.fallback))
check("Kopf kommt aus den Daten, nicht aus dem Drittwert",
    only.helm and only.helm.pct ~= nil)

-- Raid kommt aus den Logs statt von murlok. Hier stand einmal, die
-- Beinverstaerkung fehle dort - das war falsch. Warcraft Logs meldet sie
-- ganz normal; der Katalog kannte sie nur nicht, weil er Verzauberungen
-- aus Namen der Form "Enchant Legs - X" baute und ein Spellthread nicht
-- so heisst. Seit der Katalog ueber die Wirkung geht, ist der Platz
-- belegt, und dieser Test haelt ihn belegt.
ns.Profile.SetMode("raid")
local raid = bySlot(ns.List.Build(scan))
check("Raid liefert die Waffe", raid.weapon and raid.weapon.pct ~= nil,
    raid.weapon and (tostring(raid.weapon.fallback) .. " " .. tostring(raid.weapon.pct) .. "%"))
check("Raid liefert den Ring", raid.ring and raid.ring.pct ~= nil)
check("Raid liefert die Beinverstaerkung", raid.legs and raid.legs.pct ~= nil,
    raid.legs and tostring(raid.legs.pending))
ns.Profile.SetMode("mplus")

local nameless = {}
for _, row in ipairs(rows) do
    if not row.pending and not row.name then nameless[#nameless + 1] = tostring(row.id) end
end
check("alle Namen aufgeloest", #nameless == 0, table.concat(nameless, ", "))

-- ------------------------------------------------------ Spezialisierung

check("ohne Auswahl die aktive Spec", ns.Profile.SelectedSpec() == 105,
    tostring(ns.Profile.SelectedSpec()))
check("Specname aufgeloest", ns.Compat.SpecName(102) == "Balance",
    tostring(ns.Compat.SpecName(102)))
check("Speccs der eigenen Klasse", #ns.Compat.SpecsForClass(11) == 3,
    #ns.Compat.SpecsForClass(11) .. " gefunden")

ns.Profile.Select(11, 102)
check("andere Spec gewaehlt", ns.Profile.SelectedSpec() == 102)
check("eigene Klasse bleibt eigen", ns.Profile.IsForeignClass() == false)
check("jede Spec hat eigene Auswahl", ns.Profile.Current().main == nil)

ns.Profile.Select(1, 71)                   -- Krieger, Waffen
check("fremde Klasse erkannt", ns.Profile.IsForeignClass() == true)
local stat, source = ns.Compat.SpecPrimaryStat(71)
-- Aus den Spieldaten, nicht vom Client.
--
-- Seit 12.1 gibt GetSpecializationInfoByID an dieser Stelle nichts mehr
-- her, und im Fenster stand "Hauptattribut" statt "Staerke" - mit
-- Folgen fuer die Steine, die daran haengen. ChrSpecialization fuehrt
-- es, der Katalog traegt es mit.
check("Hauptattribut fremder Spec", stat == "str", stat .. " / " .. source)
-- Woher es kommt, haengt am Datenstand: ein Katalog, der noch vor
-- dieser Aenderung gebaut wurde, traegt das Attribut nicht. Dann darf
-- der Client einspringen. Nur wenn der Katalog es hat, MUSS es von dort
-- kommen - sonst faellt der Rueckgriff still wieder auf einen Aufruf
-- zurueck, der seit 12.1 nichts mehr liefert.
if ns.Catalog.SpecStat and ns.Catalog.SpecStat(71) then
    check("und zwar aus den Spieldaten", source == "catalog", source)
end
if ns.Catalog.SpecStat and ns.Catalog.SpecStat(62) then
    local all = { [62] = "int", [105] = "int", [250] = "str", [259] = "agi",
                  [262] = "int", [268] = "agi", [577] = "agi", [1473] = "int" }
    local wrong = {}
    for id, want in pairs(all) do
        local got = ns.Compat.SpecPrimaryStat(id)
        if got ~= want then wrong[#wrong + 1] = id .. ": " .. tostring(got) end
    end
    check("und fuer jede Art von Spec richtig", #wrong == 0,
        #wrong == 0 and "acht geprueft" or table.concat(wrong, ", "))
end
ns.Profile.Set("main", "crit")
local foreignRows = bySlot(ns.List.Build(scan))
check("fremde Klasse ohne Steine", foreignRows.gems == nil)
check("fremde Klasse zaehlt beide Ringe", foreignRows.ring and foreignRows.ring.need == 2,
    foreignRows.ring and tostring(foreignRows.ring.need))

ns.Profile.SelectActive()
check("zurueck auf die aktive Spec", ns.Profile.SelectedSpec() == 105)

-- Die Wahl bleibt bei dem, der sie getroffen hat.
--
-- Die Ablage haengt am Konto, und die Wahl hing frueher darin: wer auf
-- dem Schamanen Elementar angesehen hatte und sich dann mit dem
-- Hexenmeister in einen Dungeon stellte, bekam dessen Erinnerung.
-- /mc probe meldete "Elementar (262)" auf einem Charakter, der keiner
-- ist.
do
    local realName = UnitName
    ns.Profile.Select(1, 71)                   -- Krieger, Waffen
    check("dieser Charakter hat gewaehlt", ns.Profile.SelectedSpec() == 71)
    UnitName = function() return "EinAnderer" end
    check("der naechste Charakter erbt sie nicht",
        ns.Profile.SelectedSpec() == 105, tostring(ns.Profile.SelectedSpec()))
    check("und auch nicht die fremde Klasse",
        ns.Profile.IsForeignClass() == false)
    -- Und der erste findet sie wieder.
    UnitName = realName
    check("der erste findet seine Wahl wieder", ns.Profile.SelectedSpec() == 71)
    ns.Profile.SelectActive()

    -- Dasselbe fuer "das nehme ich": gewaehlt wird aus den eigenen
    -- Taschen, und was der eine trinkt, kann der andere nicht.
    ns.Profile.SetOwnConsumable("flask", 241326)
    check("die eigene Wahl steht", ns.Profile.OwnConsumable("flask") == 241326)
    UnitName = function() return "EinAnderer" end
    check("der naechste Charakter erbt sie nicht",
        ns.Profile.OwnConsumable("flask") == nil,
        tostring(ns.Profile.OwnConsumable("flask")))
    UnitName = realName
    check("und der erste hat sie noch", ns.Profile.OwnConsumable("flask") == 241326)
    ns.Profile.SetOwnConsumable("flask", nil)
end

-- Vor dem Pull zaehlt, was dieser Charakter spielt - nicht, was im
-- Fenster angesehen wird.
do
    local function ids(rows)
        local out = {}
        for _, row in ipairs(rows) do out[#out + 1] = tostring(row.id) end
        table.sort(out)
        return table.concat(out, ",")
    end
    local realCurrent = ns.Compat.CurrentSpec
    -- Im Fenster steht ein fremder Spec. Die Erinnerung darf ihm nicht
    -- folgen, sondern dem, was der Client als aktiv meldet.
    ns.Profile.Select(1, 71)
    ns.Compat.CurrentSpec = function() return 105 end
    local active105 = ids(ns.Remind.Status("mplus"))
    ns.Compat.CurrentSpec = function() return 71 end
    local active71 = ids(ns.Remind.Status("mplus"))
    ns.Compat.CurrentSpec = realCurrent
    ns.Profile.SelectActive()
    check("die Erinnerung folgt der aktiven Spec, nicht der Ansicht",
        active105 ~= "" and active105 ~= active71,
        "105: " .. active105 .. "  |  71: " .. active71)
end

-- ------------------------------------------------------- Auctionator

local handed
_G.Auctionator = {
    API = { v1 = {
        CreateShoppingList = function(callerID, name, searchStrings)
            handed = { caller = callerID, name = name, terms = searchStrings }
        end,
        ConvertToSearchString = function(_, term)
            return ("%s;;;;;;;;;;;;;%s"):format(
                term.isExact and ('"' .. term.searchString .. '"') or term.searchString,
                tostring(term.quantity or ""))
        end,
        MultiSearchExact = function() end,
    } },
}

local ok, listName, written = ns.Adapter.CreateList(rows)
check("Liste uebergeben", ok, ok and (written .. " Eintraege") or tostring(listName))
check("Praefix eingehalten", ok and listName:find("^MetaCodex: ") ~= nil, tostring(listName))
check("callerID gesetzt", handed and handed.caller == "MetaCodex")
check("exakte Suche", handed and handed.terms[1]:find('^"') ~= nil, handed and handed.terms[1])
check("Stueckzahl uebergeben", handed and handed.terms[1]:find(";3$") ~= nil,
    handed and handed.terms[1])

-- Die Suche braucht ein offenes Auktionshaus.
--
-- Ohne diese Pruefung wirft Auctionator einen Fehler aus seinem eigenen
-- Inneren, der mit "Contact the maintainer of MetaCodex" endet - und der
-- Spieler liest das zu Recht als unseren Fehler. Er hat recht: gefragt
-- haben wir, ohne nachzusehen.
_G.AuctionHouseFrame = nil
local searchOk, searchWhy = ns.Adapter.Search(rows)
check("geschlossenes Auktionshaus wird erkannt",
    searchOk == false and searchWhy == "AH_CLOSED", tostring(searchWhy))
check("und der Grund ist uebersetzt", L["AH_CLOSED"] ~= "AH_CLOSED")

_G.AuctionHouseFrame = { IsShown = function() return true end }
check("offenes Auktionshaus sucht", (ns.Adapter.Search(rows)) == true)
_G.AuctionHouseFrame = nil

-- Der Knopf soll uebergeben, was auf dem Schirm steht - nicht nur, was
-- fehlt. Sonst meldet er "nichts zu kaufen" und tut nichts, sobald alles
-- verzaubert ist.
ns.Profile.Set("onlyMissing", false)
local fullRows = ns.List.Build(scan)
local okFull, _, writtenFull = ns.Adapter.CreateList(fullRows)
check("Vollansicht wird uebergeben", okFull and writtenFull > written,
    tostring(writtenFull) .. " statt " .. tostring(written))

local doneTerm
for _, term in ipairs(handed.terms) do
    if term:find(";$") then doneTerm = term break end
end
check("erledigte Zeile ohne Stueckzahl", doneTerm ~= nil, tostring(doneTerm))
ns.Profile.Set("onlyMissing", true)

-- Schema 1 trug "nur was fehlt" als Vorgabe. Bereits gespeicherte Profile
-- muessen davon befreit werden, sonst greift die neue Vorgabe nie.
MetaCodexDB.version = 1
MetaCodexDB.specs[105].onlyMissing = true
ns.Profile.Init()
check("Migration loescht den alten Filter", MetaCodexDB.specs[105].onlyMissing == false)
check("Schemaversion erhoeht", MetaCodexDB.version == 2, tostring(MetaCodexDB.version))

-- ---------------------------------------------------------- Oberflaeche

_G.SlashCmdList.METACODEX("")
wow.runTimers()

local frame = _G.MetaCodexFrame
check("Fenster gebaut", frame ~= nil)
check("Fenster offen", frame and frame:IsShown() == true)
check("Titel gesetzt", frame and frame.titleText:GetText() == L["TITLE"],
    frame and tostring(frame.titleText:GetText()))
-- Der Knopf traegt die Klassenfarbe, also steht der Name in einem
-- Farbcode. Geprueft wird der Text darin, nicht die Verpackung.
local specLabel = frame and frame.specButton.label:GetText() or ""
check("Spec steht auf dem Knopf",
    specLabel:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") == "Wiederherstellung",
    specLabel)

-- Der zweite Grund fuer diese Datei: die Zeilen sollen UNTEREINANDER
-- stehen. Ein vergessenes ClearAllPoints legt sie sonst uebereinander
-- oder nebeneinander, und das sieht man erst im Spiel.
local uiRows = wow.rows()
check("Zeilen erzeugt", #uiRows > 0, #uiRows .. " Zeilen")

local shown, badAnchor, offsets = 0, {}, {}
for _, row in ipairs(uiRows) do
    if row:IsShown() then
        shown = shown + 1
        if #row.__points ~= 1 then
            badAnchor[#badAnchor + 1] = #row.__points .. " Punkte"
        else
            local point = row.__points[1]
            if point[1] ~= "TOPLEFT" or point[2] ~= 0 then
                badAnchor[#badAnchor + 1] = tostring(point[1]) .. "/" .. tostring(point[2])
            end
            offsets[#offsets + 1] = point[3]
        end
    end
end
check("sichtbare Zeilen", shown > 0, shown .. " sichtbar")
check("je genau ein Anker, links oben", #badAnchor == 0, table.concat(badAnchor, ", "))

table.sort(offsets, function(a, b) return a > b end)
local overlapping = {}
for i = 2, #offsets do
    if offsets[i] == offsets[i - 1] then overlapping[#overlapping + 1] = tostring(offsets[i]) end
end
check("keine Zeile liegt auf einer anderen", #overlapping == 0,
    #overlapping > 0 and table.concat(overlapping, ", ") or (#offsets .. " Hoehen"))

-- ----------------------------------------------- Neue Abschnitte

---Zaehlt die sichtbaren Zeilen eines Abschnitts.
local function rowsInSection(key)
    MetaCodexDB.section = key
    ns.UI.Refresh()
    local shown = 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() then shown = shown + 1 end
    end
    return shown
end

check("Zielwerte zeigen Zeilen", rowsInSection("stats") >= 4,
    rowsInSection("stats") .. " Zeilen")
check("Ausruestung zeigt Zeilen", rowsInSection("gear") > 10,
    rowsInSection("gear") .. " Zeilen")

-- Je Platz eine Zeile, und der Rest auf Klick.
--
-- Sechzehn Plaetze mal fuenf Vorschlaege waren neunzig Zeilen. Was
-- geprueft wird, ist nicht die Zahl - die haengt an den Daten -,
-- sondern dass ueberhaupt gefaltet ist, dass ein Klick aufmacht und
-- derselbe Klick wieder zu.
do
    local shownIn = function()
        local n = 0
        for _, row in ipairs(wow.rows()) do if row:IsShown() then n = n + 1 end end
        return n
    end
    local findFold = function(word)
        for _, row in ipairs(wow.rows()) do
            local text = row.title:GetText() or ""
            if row:IsShown() and row.onClick and text:find(word, 1, true) then return row end
        end
    end
    local compact = rowsInSection("gear")
    -- Das Wort hinter der Zahl: "weitere", "more". Der fertige Text
    -- traegt eine Zahl, die niemand vorher kennt.
    local word = L["GEAR_MORE"]:match("%%d%s*(.+)") or "?"
    local more = findFold(word)
    check("Ausruestung ist gefaltet", more ~= nil, compact .. " Zeilen")
    if more then
        more.onClick(more, "LeftButton")
        local open = shownIn()
        check("ein Klick klappt den Platz auf", open > compact,
            compact .. " -> " .. open)
        local less = findFold(L["GEAR_LESS"])
        check("die Zeile bietet jetzt das Zuklappen an", less ~= nil)
        if less then
            less.onClick(less, "LeftButton")
            check("und zugeklappt sind es wieder so viele wie vorher",
                shownIn() == compact, shownIn() .. " statt " .. compact)
        end
    end
end

-- Und der Fundort laesst sich als ganze Gruppe waehlen.
--
-- Vorher standen zehn Dungeons, das Handwerk, die Set-Teile und
-- "nicht im Journal" in einer alphabetischen Reihe, und wer wissen
-- wollte, was in Dungeons faellt, konnte nur einen einzelnen anklicken.
do
    ns.Profile.SetCategory("gearSource", nil)
    local all = rowsInSection("gear")
    ns.Profile.SetCategory("gearSource", "group:dungeon")
    local some = rowsInSection("gear")
    check("die Gruppe Dungeons bleibt gewaehlt",
        ns.Profile.Category("gearSource") == "group:dungeon", some .. " Zeilen")
    check("und zeigt weniger als alles", some > 0 and some < all,
        some .. " von " .. all)
    check("der Knopf nennt die Gruppe",
        ns.UI.Frame().originButton.label:GetText() == L["ORIGIN_GALL_dungeon"],
        tostring(ns.UI.Frame().originButton.label:GetText()))
    ns.Profile.SetCategory("gearSource", nil)
    check("ohne Filter sind es wieder alle", rowsInSection("gear") == all)
end

-- Tier-Set und Handwerk: dieselben Daten, andere Frage.
--
-- Nicht "was ziehe ich an diesen Platz", sondern "welches Set-Teil
-- tragen die Besten ueberhaupt". Also nach Anteil sortiert, jedes
-- Stueck einmal, und nur Stuecke der jeweiligen Art.
do
    -- Die Art steht an zwei Stellen: die Quelle darf sie mitliefern,
    -- und wo sie schweigt, sagen es die Spieldaten. Geprueft wird
    -- gegen beide - eine Zeile ist richtig, wenn EINE von beiden sie
    -- so nennt.
    local kindOf = {}
    do
        local gear = ns.Recommend.Gear(ns.Profile.SelectedSpec(), ns.Profile.Mode(),
            ns.Recommend.ALL)
        for _, list in pairs(gear or {}) do
            for _, item in ipairs(list) do
                kindOf[item.id] = item.kind or ns.Catalog.ItemKind(item.id)
            end
        end
    end
    for _, probe in ipairs({ { key = "tier", badge = "set" },
                             { key = "crafted", badge = "craft" } }) do
        local n = rowsInSection(probe.key)
        check("Abschnitt " .. probe.key .. " zeigt Zeilen", n > 0, n .. " Zeilen")
        local last, fallend, doppelt, fremd = nil, true, 0, 0
        local seen = {}
        for _, row in ipairs(wow.rows()) do
            if row:IsShown() and row.itemID then
                if seen[row.itemID] then doppelt = doppelt + 1 end
                seen[row.itemID] = true
                if kindOf[row.itemID] ~= probe.badge then fremd = fremd + 1 end
                local pct = tonumber((row.share:GetText() or ""):match("(%d+)%%") or "")
                if pct and last and pct > last then fallend = false end
                last = pct or last
            end
        end
        check("  nach Anteil sortiert", fallend)
        check("  jedes Stueck einmal", doppelt == 0, doppelt .. " doppelt")
        check("  und nur " .. probe.badge, fremd == 0, fremd .. " fremd")
    end
end

-- Gleiche Rolle, gleiche Farbe.
--
-- Zeilen werden wiederverwendet, und die Unterzeile setzte ihre Farbe
-- nicht zurueck: was einmal gedaempft oder rot war, blieb es im
-- naechsten Abschnitt an einem ganz anderen Gegenstand. Im Fenster sah
-- das aus wie Zufall, und es war auch einer.
do
    local erlaubt = { textSecondary = true, warning = true }
    local schief, geprueft = {}, 0
    for _, key in ipairs({ "gear", "tier", "crafted", "enchants", "consumables",
                           "remind", "stats", "talents", "players", "settings",
                           "info", "guides" }) do
        rowsInSection(key)
        for _, row in ipairs(wow.rows()) do
            local text = row:IsShown() and row.detail and (row.detail:GetText() or "") or ""
            if text ~= "" then
                geprueft = geprueft + 1
                local token = rawget(row.detail, "__token")
                if token and not erlaubt[token] then
                    schief[#schief + 1] = key .. ": " .. token
                end
            end
            -- Und die Hauptzeile: grau darf sie sein, aber dann in der
            -- kleinen Schrift. Ein grauer Titel in Titelgroesse sieht
            -- aus wie ein Titel, der vergessen wurde - genau das stand
            -- unter "Talente" neben weissen.
            local kopf = row:IsShown() and row.title and (row.title:GetText() or "") or ""
            if kopf ~= "" and not rawget(row, "__header") then
                local token = rawget(row.title, "__token")
                local size = rawget(row.title, "__fontPoints")
                geprueft = geprueft + 1
                if token == "textSecondary" and size ~= ns.Style.font.caption then
                    schief[#schief + 1] = key .. ": grauer Titel in Groesse " .. tostring(size)
                elseif token == "textMuted" then
                    schief[#schief + 1] = key .. ": Titel in textMuted"
                end
            end
        end
    end
    check("jede Zeile traegt die Farbe ihrer Rolle", #schief == 0 and geprueft > 40,
        geprueft .. " Zeilen geprueft" .. (#schief > 0 and (": " .. table.concat(schief, ", ")) or ""))
end

-- Verzierungen und die Werte der Handwerksstuecke.
--
-- Beides steht nur in den Bonus-IDs der gemessenen Spieler. Was hier
-- geprueft wird, ist nicht die Zahl - die haengt an den Daten -,
-- sondern dass der Weg von der Bonus-ID bis in die Zeile haelt: eine
-- Verzierung hat einen Namen, ein Handwerksstueck hat ein Wertepaar,
-- und der Link traegt es mit.
do
    local n = rowsInSection("embellish")
    check("Abschnitt Verzierungen zeigt Zeilen", n > 0, n .. " Zeilen")
    local ohneName = 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and not rawget(row, "__header") then
            local text = row.title:GetText() or ""
            if text == "" or text:find("^#%d+$") then ohneName = ohneName + 1 end
        end
    end
    check("  jede Verzierung hat einen Namen", ohneName == 0, ohneName .. " ohne")

    -- Zwei Verzierungen, zwei Tooltips.
    --
    -- Eine Zeile, aber zwei Entscheidungen: wer wissen will, was die
    -- Kombination kann, muss beide lesen koennen. Vorher zeigte die
    -- Zeile gar keins - ein Tooltip zum ersten von zweien waere eine
    -- halbe Auskunft gewesen, also stand dort keines.
    -- Eine Spec suchen, die wirklich zwei traegt: nicht jede tut es,
    -- und ein Test, der bei der falschen still nichts prueft, ist
    -- keiner.
    local pair
    local mine = ns.Profile.SelectedSpec()
    for _, spec in ipairs({ mine, 62, 102, 70, 71, 65 }) do
        local list = ns.Recommend.Embellish(spec, "mplus", ns.Recommend.ALL)
        local hat = false
        for _, entry in ipairs(list or {}) do
            if #(entry.ids or {}) > 1 then hat = true break end
        end
        if hat then
            local klasse = ns.Compat.ClassOfSpec(spec)
            if klasse then ns.Profile.Select(klasse, spec) end
            rowsInSection("embellish")
            for _, row in ipairs(wow.rows()) do
                local ids = row:IsShown() and rawget(row, "ids") or nil
                if ids and #ids > 1 then pair = row break end
            end
        end
        if pair then break end
    end
    check("  eine Spec traegt zwei Verzierungen", pair ~= nil)
    if pair then
        local first, second
        GameTooltip.SetHyperlink = function(_, link) first = link end
        pair.__scripts.OnEnter(pair)
        local tip2 = _G["MetaCodexTooltipTwo"]
        check("  der zweite Tooltip entsteht", tip2 ~= nil)
        if tip2 then
            tip2.SetHyperlink = function(_, link) second = link end
            pair.__scripts.OnEnter(pair)
            check("  beide Gegenstaende bekommen ihr Tooltip",
                first == "item:" .. pair.ids[1] and second == "item:" .. pair.ids[2],
                tostring(first) .. "  /  " .. tostring(second))
            tip2.SetHyperlink = nil
        end
        GameTooltip.SetHyperlink = nil
    end
    do
        local klasse = ns.Compat.ClassOfSpec(mine)
        if klasse then ns.Profile.Select(klasse, mine) else ns.Profile.SelectActive() end
    end

    -- Und das Handwerk traegt sein Wertepaar.
    rowsInSection("crafted")
    local mitWerten, mitBonusImLink = 0, 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and type(row.link) == "string" then
            local text = (row.detail:GetText() or "")
            if text:find(L["STAT_haste"], 1, true) or text:find(L["STAT_crit"], 1, true)
                or text:find(L["STAT_mastery"], 1, true) or text:find(L["STAT_vers"], 1, true) then
                mitWerten = mitWerten + 1
                -- Die Bonus-ID gehoert IN den Link, sonst zeigt das
                -- Tooltip "Zufallswert 1".
                for id in row.link:gmatch(":(%d+)") do
                    if ns.Catalog.StatsOfBonus(tonumber(id)) then
                        mitBonusImLink = mitBonusImLink + 1
                        break
                    end
                end
            end
        end
    end
    check("  Handwerk nennt seine Werte", mitWerten > 0, mitWerten .. " Zeilen")
    check("  und der Link traegt sie mit", mitBonusImLink == mitWerten,
        mitBonusImLink .. " von " .. mitWerten)

    -- Und zwar als GANZE Liste, nicht als einzelne ID.
    --
    -- Eine Werte-ID allein reicht dem Client nicht: ein Handwerksstueck
    -- traegt Qualitaet, Aufwertung und Verzierung in derselben Liste,
    -- und ohne sie steht im Tooltip weiter "Zufallswert 1". Genau so
    -- sah es im Spiel aus.
    local gemessen, voll = 0, 0
    for _, row in ipairs(wow.rows()) do
        local id = row:IsShown() and rawget(row, "itemID") or nil
        local levels = id and ns.Recommend.CraftLevels(id) or nil
        if levels and #levels > 0 and type(rawget(row, "fullLink")) == "string" then
            gemessen = gemessen + 1
            local n = 0
            for _ in rawget(row, "fullLink"):gmatch(":%d+") do n = n + 1 end
            -- item:ID plus Anzahl plus die IDs selbst: bei einer
            -- gemessenen Liste sind das mehr als drei Zahlen.
            if n > 3 then voll = voll + 1 end
        end
    end
    check("  und zwar als ganze gemessene Liste", gemessen == 0 or voll == gemessen,
        voll .. " von " .. gemessen)

    -- Eine gewaehlte Kombination schlaegt die gemessene.
    local choices = ns.Catalog.CraftStatChoices()
    if #choices > 0 then
        ns.Profile.SetCraftStats(choices[1].bonus)
        rowsInSection("crafted")
        local fremd, passend = 0, 0
        for _, row in ipairs(wow.rows()) do
            if row:IsShown() and type(row.link) == "string" then
                for id in row.link:gmatch(":(%d+)") do
                    local stats = ns.Catalog.StatsOfBonus(tonumber(id))
                    if stats then
                        if tonumber(id) == choices[1].bonus then passend = passend + 1
                        else fremd = fremd + 1 end
                    end
                end
            end
        end
        check("  die gewaehlte Kombination gilt ueberall",
            fremd == 0 and passend > 0, passend .. " passend, " .. fremd .. " andere")
        ns.Profile.SetCraftStats(nil)
    end
end

check("Verzauberungen zeigen weiter Zeilen", rowsInSection("enchants") > 0)
-- Hier stand einmal "leerer Abschnitt bleibt leer" und meinte Guides.
-- Inzwischen ist keiner der sechs Abschnitte mehr leer.
check("Guides zeigen Zeilen", rowsInSection("guides") > 0,
    rowsInSection("guides") .. " Zeilen")

-- Die Adressen werden aus den ENGLISCHEN Bezeichnern gebaut. Auf einem
-- deutschen Client ergaebe der Clientname eine Adresse, die es nicht gibt.
local links = ns.Guides.For(105)
check("Guide-Adressen gebaut", #links > 0, #links .. " Verweise")
if links[1] then
    check("Adresse nutzt den englischen Bezeichner",
        links[1].url:find("druid") ~= nil and links[1].url:find("restoration") ~= nil,
        links[1].url)
    check("jede Adresse nennt ihre Quelle", links[1].site ~= nil, links[1].site)

    -- Jede Zeile braucht ihren Text, sonst steht dort der Schluessel.
    -- Genau so faellt eine neu hinzugefuegte Quelle ohne Uebersetzung auf.
    local ohneText = {}
    for _, link in ipairs(links) do
        local key = "GUIDE_" .. link.key:upper()
        if L[key] == key then ohneText[#ohneText + 1] = key end
    end
    check("jede Quelle hat einen Text", #ohneText == 0, table.concat(ohneText, ", "))

    -- Jede Zeile traegt ihr eigenes Symbol. Sechs gleiche Buecher
    -- untereinander waren eine Tapete.
    local ohneIcon = 0
    for _, link in ipairs(links) do
        if not link.icon then ohneIcon = ohneIcon + 1 end
    end
    check("jede Quelle hat ein Symbol", ohneIcon == 0, ohneIcon .. " ohne")

    -- Und mehr als eine Ueberschrift: nach Seite gruppiert, nicht alles
    -- unter eine.
    local seiten = {}
    for _, link in ipairs(links) do seiten[link.site] = true end
    local anzahl = 0
    for _ in pairs(seiten) do anzahl = anzahl + 1 end
    check("nach Seite gruppiert", anzahl > 1, anzahl .. " Quellen")

    -- Und keine darf offensichtlich unfertig sein. Die Archon-Adresse war
    -- es: mir fehlte der Seitenname, und im Browser kam 404.
    local kaputt = {}
    for _, link in ipairs(links) do
        if link.url:find("//", 9, true) or link.url:sub(-1) == "/" then
            kaputt[#kaputt + 1] = link.url
        end
    end
    check("keine Adresse hat eine Luecke", #kaputt == 0, table.concat(kaputt, " "))

    -- Der Kopierdialog muss einen eigenen Hintergrund haben. Er hatte
    -- keinen: S:Card ERZEUGT einen Rahmen, es verziert keinen, und der
    -- Aufruf S:Card(linkFrame) baute einen unsichtbaren Kindrahmen. Der
    -- Dialog stand durchsichtig ueber der Liste.
    ns.UI.ShowLink(links[1].url)
    local dialog
    for _, f in ipairs(wow.frames) do
        if rawget(f, "box") then dialog = f end
    end
    check("Kopierdialog erscheint", dialog ~= nil and dialog:IsShown())
    if dialog then
        check("Kopierdialog hat einen Hintergrund",
            #dialog.__textures > 0, #dialog.__textures .. " Texturen")
        check("Kopierdialog zeigt die Adresse",
            dialog.box.__url == links[1].url, tostring(dialog.box.__url))
        dialog:Hide()
    end
end
MetaCodexDB.section = "enchants"
ns.UI.Refresh()

-- --------------------------------- Umschalten muss etwas aendern

-- Bei "alle Plattformen" gewinnt die GEMESSENE Quelle, nicht die erste.
--
-- Vorher nahm Stats schlicht die erste, die etwas hatte - und das war
-- murlok. Also zeigten "alle Plattformen" und "murlok.io" dasselbe, und
-- ein Wechsel zwischen ihnen sah aus, als sei der Knopf kaputt.
do
    local sources = ns.Recommend.SourcesFor("mplus")
    local gemessen, geordnet
    for _, name in ipairs(sources) do
        local st = ns.Recommend.Stats(262, "mplus", name)
        if st then
            if (st.players or 0) > 0 then gemessen = name else geordnet = name end
        end
    end
    if gemessen and geordnet then
        local _, fromAll = ns.Recommend.Stats(262, "mplus", ns.Recommend.ALL)
        check("alle Plattformen nehmen die gemessene Quelle",
            fromAll == gemessen, tostring(fromAll) .. " statt " .. geordnet)

        local a = ns.Recommend.Stats(262, "mplus", ns.Recommend.ALL)
        local b = ns.Recommend.Stats(262, "mplus", geordnet)
        check("und zeigen etwas anderes als die geordnete",
            a.values.crit.rating ~= b.values.crit.rating,
            a.values.crit.rating .. " gegen " .. b.values.crit.rating)
    end
end

-- ------------------------------------------------ Anteile sind Anteile

-- Kein Anteil ueber hundert Prozent, in keiner Tabelle.
--
-- Es gab zwei Wege dorthin, und beide standen im Fenster: eine Rune
-- wurde als Aura UND als Wirkung gezaehlt (135 %), und bei den
-- Zielwerten hiess "pct" je nach Quelle etwas anderes (756 %).
local ueber = {}
local function pruefe(was, liste)
    for _, row in ipairs(liste or {}) do
        if (row.pct or 0) > 100 then ueber[#ueber + 1] = was .. " " .. row.pct end
    end
end
for _, mode in ipairs({ "mplus", "raid" }) do
    for _, source in ipairs(ns.Recommend.SourcesFor(mode)) do
        for _, spec in ipairs({ 105, 262, 266, 71 }) do
            local rec = ns.Recommend.For(spec, mode, source)
            if rec then
                pruefe("Stein", rec.gems)
                pruefe("Verbrauch", rec.consumables)
                pruefe("Talent", rec.talents)
                for slot, list in pairs(rec.enchants or {}) do pruefe(slot, list) end
                for _, value in pairs((rec.stats or {}).values or {}) do
                    if (value.pct or 0) > 100 then
                        ueber[#ueber + 1] = "Zielwert " .. value.pct
                    end
                end
            end
        end
    end
end
check("kein Anteil ueber hundert Prozent", #ueber == 0,
    table.concat(ueber, ", "):sub(1, 80))

-- ------------------------------------------ Jeder Knopf laesst sich druecken

-- Dreimal an einem Abend derselbe Fehler: eine local-Funktion, die
-- weiter unten steht, aber weiter oben in einem Klickhaken benutzt wird.
-- Lua sieht dort eine globale Leere, und der Knopf tut NICHTS - ohne
-- Fehlermeldung, solange niemand klickt.
--
-- Also klickt dieser Test. Auf jeden Kopfknopf, in jedem Abschnitt.
do
    local buttons = {
        { name = "Spec", get = function() return frame and frame.specButton end },
        { name = "Aktivitaet", get = function() return frame and frame.activityButton end },
        { name = "Quelle", get = function() return frame and frame.sourceButton end },
        { name = "Schluessel", get = function() return frame and frame.levelButton end },
        { name = "Platz", get = function() return frame and frame.slotButton end },
        { name = "Kategorie", get = function() return frame and frame.categoryButton end },
        { name = "Dungeon", get = function() return frame and frame.dungeonButton end },
    }
    local frame = nil
    for _, f in ipairs(wow.frames) do
        if rawget(f, "sourceButton") then frame = f end
    end
    check("Kopfknoepfe gefunden", frame ~= nil)
    -- Und er muss wirklich geklickt haben, sonst ist er gruen, weil er
    -- nichts tut - die Sorte Test, die schlimmer ist als keiner.
    local geklickt = 0

    local kaputt = {}
    for _, section in ipairs({ "guides", "stats", "talents", "gear",
                              "enchants", "consumables", "info" }) do
        MetaCodexDB.section = section
        ns.UI.Refresh()
        for _, entry in ipairs(buttons) do
            local button = entry.get()
            local click = button and button.__scripts and button.__scripts.OnClick
            if click then
                geklickt = geklickt + 1
                local ok, err = pcall(click, button, "LeftButton")
                if not ok then
                    kaputt[#kaputt + 1] = section .. "/" .. entry.name
                        .. ": " .. tostring(err):sub(-40)
                end
            end
        end
    end
    check("wirklich geklickt", geklickt > 10, geklickt .. " Klicks")
    check("kein Kopfknopf laeuft auf einen Fehler", #kaputt == 0,
        table.concat(kaputt, " | "):sub(1, 120))
end
MetaCodexDB.section = "enchants"
ns.UI.Refresh()

-- ------------------------------------------- Stufe im Gegenstandslink

-- Ohne Bonus-ID zeigt das Tooltip die GRUNDstufe: "Stufe 28" unter einer
-- Zeile, die 334 sagt. Die Tabelle dafuer steht im Katalog.
check("Katalog kennt Stufendifferenzen",
    ns.Catalog.LevelDeltaBonus(10) ~= nil,
    tostring(ns.Catalog.LevelDeltaBonus(10)))
check("und auch nach unten", ns.Catalog.LevelDeltaBonus(-10) ~= nil)
check("Null braucht keine", ns.Catalog.LevelDeltaBonus(0) ~= nil
    or ns.Catalog.LevelDeltaBonus(0) == nil)

-- Der Stub meldet Grundstufe 12345 fuer jeden Gegenstand; entscheidend
-- ist, dass ueberhaupt ein Link mit Bonus-ID entsteht.
local link = ns.Compat.LinkAtLevel(200001, 210)
check("Link traegt eine Bonus-ID",
    link ~= nil and link:find("::1:") ~= nil, tostring(link))
-- Aufwertungspfade: der Client rechnet die Stufe, gewaehlt wird der
-- niedrigste Rang, der sie erreicht. Das ist der Unterschied zwischen
-- "Stufe 292" und "Held 1/8" im Tooltip.
local season = ns.Compat.SeasonTracks(200001)
check("laufende Saison erkannt", season ~= nil and next(season) ~= nil)
local hit = ns.Compat.TrackFor(292, 200001)
check("292 ist Held 1, nicht Champion 5", hit ~= nil and hit.bonus == 12841,
    hit and (hit.bonus .. " Rang " .. hit.rank) or "nichts")
check("und der Pfad heisst so", hit ~= nil and ns.Compat.TrackName(hit.track) == "Held",
    hit and ns.Compat.TrackName(hit.track))
local vault = ns.Compat.TrackFor(311, 200001)
check("311 ist Mythisch 1, nicht Held 5", vault ~= nil and vault.bonus == 12849,
    vault and (vault.bonus .. " Rang " .. vault.rank) or "nichts")
local onTrack = ns.Compat.LinkAtLevel(200001, 292)
check("Link auf 292 traegt den Pfad", onTrack ~= nil and onTrack:find(":1:12841$") ~= nil,
    tostring(onTrack))
check("ohne Pfad bleibt die Differenz", link:find(":1:128") == nil, link)

local same = ns.Compat.LinkAtLevel(200001, 200)
check("gleiche Stufe braucht keinen Bonus",
    same == "item:200001", tostring(same))
check("ohne Gegenstand kein Link", ns.Compat.LinkAtLevel(nil, 300) == nil)

-- --------------------------------------------- Belohnungsstufen

-- Die Tabelle steht NICHT in diesem Addon: sie aendert sich mit jeder
-- Saison, und eine abgeschriebene waere beim naechsten Patch still
-- falsch. Der Client kennt sie.
local rewards = ns.Compat.RewardTable()
check("Belohnungstabelle kommt vom Client", #rewards > 0, #rewards .. " Stufen")
if rewards[1] then
    check("jede Stufe nennt beide Werte",
        rewards[1].endOfRun > 0 and rewards[1].vault > 0,
        rewards[1].endOfRun .. " / " .. rewards[1].vault)
    -- Die Eigenschaft, auf die ich mich verlasse, statt die Reihenfolge
    -- der Rueckgabewerte zu raten: die Truhe gibt nie weniger.
    local verdreht = 0
    for _, row in ipairs(rewards) do
        if row.vault < row.endOfRun then verdreht = verdreht + 1 end
    end
    check("Tresor gibt nie weniger als der Dungeon", verdreht == 0,
        verdreht .. " verdreht")
    -- Und sie steigt.
    check("hoehere Schluessel geben mehr",
        rewards[#rewards].endOfRun > rewards[1].endOfRun,
        rewards[1].endOfRun .. " -> " .. rewards[#rewards].endOfRun)
end
check("unsinnige Stufe ergibt nichts", ns.Compat.RewardLevels(0) == nil)

-- Die Auswahl merkt sich.
ns.Profile.SetKeyLevel(10)
check("Schluesselstufe gemerkt", ns.Profile.KeyLevel() == 10)
ns.Profile.SetKeyLevel(nil)
check("und wieder abwaehlbar", ns.Profile.KeyLevel() == nil)

-- ---------------------------------------------------------- Datum

-- Die Sammler schreiben 20260923, weil sich das sortieren laesst. Im
-- Fenster stand genau diese Zahl - eine Wurst, die niemand als Datum
-- liest.
check("Stempel wird zum Datum", ns.Compat.DateText(20260923):find("2026") ~= nil,
    ns.Compat.DateText(20260923))
check("Datum ist nicht die Zahl", ns.Compat.DateText(20260923) ~= "20260923",
    ns.Compat.DateText(20260923))
check("ohne Stempel kein Datum", ns.Compat.DateText(0) == "?",
    ns.Compat.DateText(0))
check("Unsinn ergibt kein Datum", ns.Compat.DateText(nil) == "?")

-- ------------------------------------------- Knopf folgt dem Auktionshaus

-- Ein grauer Knopf, der grau bleibt, obwohl die Bedingung erfuellt ist,
-- sieht aus wie ein kaputter Knopf.
MetaCodexDB.section = "enchants"
_G.AuctionHouseFrame = nil
if not ns.UI.IsShown() then ns.UI.Toggle() end
ns.UI.Refresh()
local suchen
for _, f in ipairs(wow.frames) do
    if rawget(f, "label") and f.label.__text == L["BTN_SEARCH"] then suchen = f end
end
if suchen then
    check("bei geschlossenem Auktionshaus grau", suchen:IsEnabled() == false)
    _G.AuctionHouseFrame = { IsShown = function() return true end }
    wow.fire("AUCTION_HOUSE_SHOW")
    check("wird beim Oeffnen von selbst aktiv", suchen:IsEnabled() == true)
    _G.AuctionHouseFrame = nil
    wow.fire("AUCTION_HOUSE_CLOSED")
    check("und beim Schliessen wieder grau", suchen:IsEnabled() == false)
end

-- ------------------------------------ Rueckfall auf eine andere Quelle

-- Eine Plattform, die zu einem Abschnitt nichts hat, soll nicht in eine
-- leere Seite fuehren. raider.io fuehrt keine Verbrauchsgueter und wird
-- es auch nicht; das im Kopf zu behalten ist Arbeit des Fensters.
-- Geprueft wird an einer Spec, bei der ueberhaupt eine Quelle etwas hat -
-- sonst prueft der Test die Reichweite der letzten Sammlung statt den
-- Rueckfall.
ns.Profile.SetMode("mplus")
local quellen = ns.Recommend.SourcesFor("mplus")
local mitSpec, mitQuelle, ohneQuelle
for _, name in ipairs(quellen) do
    for _, spec in ipairs(ns.Compat.SpecsForClass(ns.Compat.PlayerClassID())) do
        if ns.Recommend.Consumables(spec.id, "mplus", name) then
            mitSpec = mitSpec or spec.id
            mitQuelle = mitQuelle or name
        end
    end
end
if mitSpec then
    for _, name in ipairs(quellen) do
        if not ns.Recommend.Consumables(mitSpec, "mplus", name) then ohneQuelle = name end
    end
end
if mitSpec and ohneQuelle then
    ns.Profile.Select(ns.Compat.PlayerClassID(), mitSpec)
    ns.Profile.SetSource(ohneQuelle)
    MetaCodexDB.section = "consumables"
    ns.UI.Refresh()
    local zeilen = 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() then zeilen = zeilen + 1 end
    end
    check("leere Quelle faellt auf eine andere zurueck", zeilen > 0,
        ohneQuelle .. " statt " .. mitQuelle .. " -> " .. zeilen .. " Zeilen")
end
ns.Profile.SelectActive()
ns.Profile.SetSource(ns.Recommend.ALL)
MetaCodexDB.section = "enchants"
ns.UI.Refresh()

-- ------------------------------------------- Kategorie je Abschnitt

-- Jeder Abschnitt hat eine EIGENE Auswahl. Eine gemeinsame waere beim
-- Wechsel jedes Mal ungueltig - ein Platz bei den Verbrauchsguetern, eine
-- Art bei den Verzauberungen.
ns.Profile.SetMode("raid")
ns.Profile.SetCategory("enchants", "ring")
ns.Profile.SetCategory("consumables", "flask")
check("Auswahl je Abschnitt getrennt",
    ns.Profile.Category("enchants") == "ring"
        and ns.Profile.Category("consumables") == "flask",
    tostring(ns.Profile.Category("enchants")) .. " / "
        .. tostring(ns.Profile.Category("consumables")))

-- Und sie filtert wirklich.
ns.Profile.SetCategory("enchants", nil)
local alleVerz = rowsInSection("enchants")
ns.Profile.SetCategory("enchants", "ring")
local nurRinge = rowsInSection("enchants")
check("Verzauberungen lassen sich filtern", nurRinge > 0 and nurRinge < alleVerz,
    nurRinge .. " statt " .. alleVerz)

ns.Profile.SetCategory("consumables", nil)
local alleVerbr = rowsInSection("consumables")
ns.Profile.SetCategory("consumables", "flask")
local nurFlask = rowsInSection("consumables")
check("Verbrauchsgueter lassen sich filtern", nurFlask > 0 and nurFlask < alleVerbr,
    nurFlask .. " statt " .. alleVerbr)

-- Eine Kategorie, die es im Abschnitt nicht gibt, faellt weg.
ns.Profile.SetCategory("consumables", "gibtsnicht")
ns.UI.Refresh()
check("unbekannte Kategorie faellt weg",
    ns.Profile.Category("consumables") == nil,
    tostring(ns.Profile.Category("consumables")))
ns.Profile.SetCategory("enchants", nil)
ns.Profile.SetMode("mplus")

-- -------------------------------------------------- Platz bei Ausruestung

-- Siebzehn Plaetze zu je fuenf Zeilen sind fuenfundachtzig Zeilen. Wer
-- wissen will, welcher Schmuck oben steht, scrollt daran vorbei.
ns.Profile.SetMode("mplus")
ns.Profile.SetGearSlot(nil)
local alleZeilen = rowsInSection("gear")
check("ohne Filter alle Plaetze", alleZeilen > 10, alleZeilen .. " Zeilen")

-- Einen Platz waehlen, der in den Daten vorkommt.
local gear = ns.Recommend.Gear(ns.Profile.SelectedSpec(), "mplus", ns.Recommend.ALL)
local einPlatz
for slot, list in pairs(gear or {}) do
    if #list > 0 then einPlatz = slot break end
end
if einPlatz then
    ns.Profile.SetGearSlot(einPlatz)
    local wenige = rowsInSection("gear")
    check("mit Filter deutlich weniger", wenige < alleZeilen,
        wenige .. " statt " .. alleZeilen)
    check("und nicht leer", wenige > 0, wenige .. " Zeilen")

    -- Ein Platz, den es nicht gibt, darf nicht haengen bleiben: sonst
    -- steht er im Knopf und darunter nichts.
    ns.Profile.SetGearSlot("Gibtsnicht")
    ns.UI.Refresh()
    check("unbekannter Platz faellt weg", ns.Profile.GearSlot() == nil,
        tostring(ns.Profile.GearSlot()))
end
ns.Profile.SetGearSlot(nil)

-- ------------------------------------------- Zeilen werden aufgeraeumt

-- Zeilen werden wiederverwendet. Dieselbe Zeile ist erst ein Zielwert mit
-- zwei Balken, gleich darauf eine Ueberschrift - und der Balken blieb
-- stehen, quer ueber der Ueberschrift des naechsten Abschnitts.
--
-- Geprueft wird der Wechsel selbst, nicht der Endzustand: erst Zielwerte
-- zeichnen (damit Balken da sind), dann woanders hin, dann nachsehen.
ns.Profile.SetMode("mplus")
MetaCodexDB.section = "stats"
ns.UI.Refresh()
local drawnBars = 0
for _, row in ipairs(wow.rows()) do
    if row:IsShown() and row.barTarget and row.barTarget:IsShown() then
        drawnBars = drawnBars + 1
    end
end
check("Zielwerte zeichnen Balken", drawnBars > 0, drawnBars .. " Balken")

for _, section in ipairs({ "talents", "enchants", "guides", "consumables" }) do
    MetaCodexDB.section = section
    ns.UI.Refresh()
    local leftover = 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.barTarget and row.barTarget:IsShown() then
            leftover = leftover + 1
        end
    end
    check("kein Balken bleibt in '" .. section .. "'", leftover == 0,
        leftover .. " uebrig")
end
MetaCodexDB.section = "enchants"
ns.UI.Refresh()

-- ------------------------------------------------ Talent-Importkette

-- Es gibt keinen eigenen Kodierer mehr. Jede Kette im Fenster stammt
-- aus dem Client eines echten Spielers (raider.io). Was hier zu
-- pruefen bleibt: dass keine Zeile eine Kette anbietet, die es nicht
-- gibt, und dass keine Zeile den Mittelpunkt als "9483" schreibt.
check("kein Kodierer mehr im Namensraum", ns.Loadout == nil)
do
    ns.Profile.SetMode("mplus")
    rowsInSection("players")
    local broken = 0
    for _, row in ipairs(wow.rows()) do
        local text = row:IsShown() and row.detail and row.detail.GetText and row.detail:GetText()
        if text and text:find("9483", 1, true) then broken = broken + 1 end
    end
    check("Spielerzeilen tragen den Mittelpunkt, nicht 9483", broken == 0, broken .. " kaputt")
end

-- --------------------------------------------------- Mehrere Speccs

-- Die allererste Bitte an dieses Addon: ein Gang zum Auktionshaus fuer
-- Heal, Tank und DPS. Das Fenster zeigt weiter eine Spec; die LISTE darf
-- mehrere abdecken.
ns.Profile.SetMode("mplus")
ns.Profile.SelectActive()
local ownSpecs = ns.Compat.SpecsForClass(ns.Compat.PlayerClassID())
check("eigene Klasse hat mehrere Speccs", #ownSpecs > 1, #ownSpecs .. " Speccs")

local alone = ns.List.BuildMany(scan, ns.Profile.ShoppingSpecs())
check("ohne Zusatzauswahl genau eine Spec", #ns.Profile.ShoppingSpecs() == 1,
    #ns.Profile.ShoppingSpecs() .. " Speccs")

-- Eine zweite Spec dazunehmen.
local second
for _, spec in ipairs(ownSpecs) do
    if spec.id ~= ns.Profile.SelectedSpec() then second = spec.id break end
end
ns.Profile.ToggleListSpec(second)
local specs = ns.Profile.ShoppingSpecs()
check("zwei Speccs im Einkauf", #specs == 2, #specs .. " Speccs")

local many = ns.List.BuildMany(scan, specs)
check("zusammengefuehrte Liste ist nicht leer", #many > 0, #many .. " Zeilen")

-- Kein Gegenstand darf doppelt auftauchen - sonst stuende er zweimal im
-- Auktionshaus und die Stueckzahl waere geraten.
local seenIDs, doubled = {}, 0
for _, row in ipairs(many) do
    if seenIDs[row.id] then doubled = doubled + 1 end
    seenIDs[row.id] = true
end
check("kein Gegenstand doppelt", doubled == 0, doubled .. " doppelt")

-- Was beide Speccs brauchen, muss sich ADDIEREN. Das Maximum zu nehmen
-- waere falsch: wer je Spec zwei Ringe verzaubert, braucht vier Rollen.
local shared
for _, row in ipairs(many) do
    if (row.specs or 1) > 1 then shared = row break end
end
if shared then
    check("gemeinsamer Posten zaehlt fuer beide", (shared.specs or 1) == 2,
        tostring(shared.name) .. " fuer " .. tostring(shared.specs))
end

-- Und die Auswahl darf die Anzeige nicht verstellen.
local before = ns.Profile.SelectedSpec()
ns.List.BuildMany(scan, specs)
check("Anzeige bleibt auf ihrer Spec", ns.Profile.SelectedSpec() == before,
    tostring(before) .. " -> " .. tostring(ns.Profile.SelectedSpec()))

ns.Profile.ToggleListSpec(second)
check("wieder abwaehlbar", #ns.Profile.ShoppingSpecs() == 1)

-- ------------------------------------------------ Arten von Verbrauch

-- Heil- und Kampftrank gehoeren derselben Unterklasse an; getrennt werden
-- sie ueber die WIRKUNG (Effekt 10, Heilung). Ueber den Namen waere es
-- falsch: "Refreshing Serum" heisst nicht Heiltrank und ist einer.
local healPotions = ns.Catalog.Consumables("heal")
local combatPotions = ns.Catalog.Consumables("potion")
check("Heiltraenke getrennt", #healPotions > 0, #healPotions .. " Heiltraenke")
check("Kampftraenke bleiben uebrig", #combatPotions > #healPotions,
    #combatPotions .. " Kampftraenke")

-- Keiner darf in beiden Listen stehen.
local doubled = 0
for _, h in ipairs(healPotions) do
    for _, p in ipairs(combatPotions) do
        if h.id == p.id then doubled = doubled + 1 end
    end
end
check("kein Trank in beiden Listen", doubled == 0, doubled .. " doppelt")

if healPotions[1] then
    check("Art ist nachschlagbar",
        ns.Catalog.ConsumableKind(healPotions[1].id) == "heal",
        tostring(ns.Catalog.ConsumableKind(healPotions[1].id)))
end
check("unbekannter Gegenstand hat keine Art", ns.Catalog.ConsumableKind(1) == nil)

-- ------------------------------------------------------- Set / Handwerk

-- Die Marke kommt aus dem Katalog, nicht aus der Beobachtung. Warcraft
-- Logs liefert nur eine Gegenstands-ID; ohne diesen Weg blieben Set- und
-- Handwerksteile dort unmarkiert, waehrend murlok sie zeigt.
local setCount, craftCount = 0, 0
for _, kind in pairs(MetaCodex_Catalog.kinds or {}) do
    if kind == "set" then setCount = setCount + 1 end
    if kind == "craft" then craftCount = craftCount + 1 end
end
check("Katalog kennt Set-Teile", setCount > 0, setCount .. " Set-Teile")
check("Katalog kennt Handwerksteile", craftCount > 0, craftCount .. " Handwerksteile")
local anyKind
for id in pairs(MetaCodex_Catalog.kinds or {}) do anyKind = id break end
if anyKind then
    check("Marke ist abrufbar", ns.Catalog.ItemKind(anyKind) ~= nil,
        tostring(ns.Catalog.ItemKind(anyKind)))
end
check("unbekannter Gegenstand hat keine Marke", ns.Catalog.ItemKind(1) == nil)

-- ------------------------------------------------------------- Fundort

-- Woher ein Gegenstand kommt, steht im Katalog als ID-Paar. Den Namen
-- holt der Client - sonst stuende im deutschen Spiel ein englischer
-- Bossname.
local probeDrop
for id in pairs(MetaCodex_Catalog.drops or {}) do probeDrop = id break end
if probeDrop then
    local enc, inst = ns.Catalog.DropSource(probeDrop)
    check("Fundort ist ein ID-Paar", type(enc) == "number" and type(inst) == "number",
        tostring(enc) .. "/" .. tostring(inst))
    check("Fundort wird zu Text", ns.Compat.DropText(enc, inst) ~= nil,
        tostring(ns.Compat.DropText(enc, inst)))
end
-- Ohne Angaben darf nichts behauptet werden.
check("ohne IDs kein Fundort", ns.Compat.DropText(nil, nil) == nil)

-- ---------------------------------------------------------- Zielwerte

-- Die eigenen Werte kommen aus GetCombatRating, nicht aus UnitStat. Der
-- Unterschied ist kein Stilfrage: UnitStat liefert seit 12.1 geheime
-- Zahlen, die sich nicht vergleichen lassen, und das Fenster ist daran
-- einmal beim Oeffnen gestorben.
check("eigene Wertung lesbar", ns.Compat.OwnRating("haste") == 500,
    tostring(ns.Compat.OwnRating("haste")))
check("Meisterschaft ist eine Wertung wie die anderen", ns.Compat.OwnRating("mastery") == 300,
    tostring(ns.Compat.OwnRating("mastery")))

-- In M+, weil dort beide Quellen Zielwerte fuehren. Im Raid kamen sie
-- lange nur von murlok, und murlok misst keinen Raid.
ns.Profile.SetMode("mplus")
MetaCodexDB.section = "stats"
ns.UI.Refresh()
local statLines = 0
for _, row in ipairs(wow.rows()) do
    if row:IsShown() and row.barTarget and row.barTarget:IsShown() then
        statLines = statLines + 1
    end
end
check("Zielwerte zeichnen Balken", statLines >= 4, statLines .. " Balken")

-- --------------------------------------------------------- Top-Spieler

-- Der Abschnitt ist der einzige ohne Empfehlung, und darum der einzige,
-- dessen Zeilen niemand sonst prueft: keine Prozentzahl, kein Gegenstand,
-- nur eine Adresse. Wenn murlok sie liefert, muss er sie zeigen.
ns.Profile.SetMode("mplus")
local top = ns.Recommend.Players(105, "mplus", ns.Recommend.ALL)
if top then
    check("Top-Spieler haben einen Platz",
        type(top[1].rank) == "number" and top[1].rank > 0, tostring(top[1].rank))
    check("Top-Spieler haben Name und Realm",
        (top[1].name or "") ~= "" and (top[1].realm or "") ~= "",
        (top[1].name or "?") .. " / " .. (top[1].realm or "?"))
    check("Abschnitt Top-Spieler zeigt Zeilen", rowsInSection("players") > 0,
        rowsInSection("players") .. " Zeilen")
    -- Die Raenge sind eine Rangliste, keine Menge. Doppelte waeren ein
    -- Zeichen dafuer, dass der Parser zweimal dieselbe Karte gelesen hat.
    local seen, twice = {}, 0
    for _, one in ipairs(top) do
        local key = one.url or (one.name .. "@" .. tostring(one.realm))
        if seen[key] then twice = twice + 1 end
        seen[key] = true
    end
    check("kein Spieler doppelt", twice == 0, twice .. " doppelt")
    -- Eine Zeile ohne Adresse ist ein Knopf, der nichts tut - und das
    -- faellt im Spiel erst auf, wenn jemand darauf klickt.
    local ohne = 0
    for _, p in ipairs(top) do
        if type(p.url) ~= "string" or not p.url:match("^https://")
            then ohne = ohne + 1 end
    end
    check("jeder Spieler hat eine Profiladresse", ohne == 0, ohne .. " ohne")
else
    check("Abschnitt Top-Spieler bleibt leer statt zu stuerzen",
        rowsInSection("players") == 0, "noch keine Rangliste gesammelt")
end

check("Grundmodus einer Klammer", ns.Recommend.BaseMode("mplus-keys") == "mplus",
    ns.Recommend.BaseMode("mplus-keys"))
check("Grundmodus behaelt den Dungeon",
    ns.Recommend.BaseMode("mplus-keys/altar-of-fangs") == "mplus/altar-of-fangs",
    ns.Recommend.BaseMode("mplus-keys/altar-of-fangs"))
check("Solo Shuffle ist keine Klammer von 3v3", ns.Recommend.BaseMode("solo") == "solo",
    ns.Recommend.BaseMode("solo"))
check("Raid mythisch faellt auf Raid zurueck", ns.Recommend.BaseMode("raid-mythic") == "raid")

-- Die Rangliste haengt an der Aktivitaet, nicht an der Schluesselklammer.
local keyed = ns.Recommend.Players(105, "mplus-keys", ns.Recommend.ALL)
check("Top-Spieler auch unter M+ (+7 - +21)", keyed ~= nil and #keyed > 0,
    keyed and (#keyed .. " Zeilen") or "leer")

-- Die Schluesselklammer kommt nur aus den Logs und hat keine Kette; der
-- Build wird vom Grundmodus geliehen, und die Ueberschrift sagt es.
local kp, kb = ns.Recommend.Talents(105, "mplus-keys", ns.Recommend.ALL)
if kp then
    check("Klammer hat einen Build mit Kette", kb ~= nil and kb.text ~= nil and kb.text ~= "",
        kb and (kb.text and (#kb.text .. " Zeichen") or "ohne Kette") or "kein Build")
    check("und er ist als geliehen markiert", kb ~= nil and kb.fromBase == true)
    ns.Profile.SetMode("mplus-keys")
    check("Klammer zeigt den Kopierknopf", rowsInSection("talents") > 0,
        rowsInSection("talents") .. " Zeilen")
end

-- ------------------------------------------------------ Herkunft & Listen

-- PvP-Ware am Namen: "Venomous Gladiator's Silk Cap" ist Eroberung.
check("Katalog kennt PvP-Herkunft", ns.Catalog.Origin(270620) == "conquest",
    tostring(ns.Catalog.Origin(270620)))
-- Und die Beute alter Saisondungeons kommt aus dem Journal ueber die
-- Empfehlungen: "Fireproof Drape" (Dragonflight) hat einen Boss.
do
    local enc, inst = ns.Catalog.DropSource(193763)
    check("alter Dungeon hat einen Fundort", enc ~= nil and enc > 0,
        tostring(enc) .. " / " .. tostring(inst))
end
-- Kein Gegenstand traegt mehr "gesehen in ..." als Herkunft.
do
    ns.Profile.SetMode("mplus")
    local seen = 0
    rowsInSection("gear")
    for _, row in ipairs(wow.rows()) do
        local text = row:IsShown() and row.detail and row.detail.GetText and row.detail:GetText()
        if text and text:find("gesehen") then seen = seen + 1 end
    end
    check("keine Zeile sagt 'gesehen in'", seen == 0, seen .. " Zeilen")
end

-- Zwei Abschnitte, zwei Listen. Mit einem Namen ueberschrieb die eine
-- die andere.
check("Liste je Abschnitt verschieden",
    ns.Adapter.ListName("enchants") ~= ns.Adapter.ListName("consumables"),
    ns.Adapter.ListName("enchants") .. " | " .. ns.Adapter.ListName("consumables"))

-- ------------------------------------------------------- Spieleransicht

-- Ein Klick auf einen Spieler oeffnet sein Profil im Fenster: Kette,
-- Adresse, Ausruestung mit allen Bonus-IDs.
if MetaCodex_Players and MetaCodex_Players.modes then
    local anyMode, anySpec, anyList
    for mode, bySpec in pairs(MetaCodex_Players.modes) do
        for spec, list in pairs(bySpec) do
            if #list > 0 then anyMode, anySpec, anyList = mode, spec, list; break end
        end
        if anyList then break end
    end
    if anyList then
        local first = anyList[1]
        local profile = ns.Recommend.Player(anyMode, anySpec, first.name, first.realm)
        check("Profil wird gefunden", profile ~= nil, anyMode .. "/" .. anySpec .. " " .. first.name)
        check("Profil hat Ausruestung", profile ~= nil and #(profile.gear or {}) >= 10,
            profile and (#(profile.gear or {}) .. " Teile") or "?")
        local withBonus = 0
        for _, piece in ipairs(profile and profile.gear or {}) do
            if piece.b and #piece.b > 0 then withBonus = withBonus + 1 end
        end
        check("Ausruestung traegt Bonus-IDs", withBonus > 0, withBonus .. " mit Bonus")
    end
end

-- --------------------------------------------- Nichts zeigen, was fehlt

-- Die eine Regel: kein Abschnitt, keine Aktivitaet, keine Plattform, zu
-- der es nichts gibt. PvP hat keine Verbrauchsgueter - keine Quelle
-- misst sie -, also steht der Abschnitt dort nicht.
check("PvP hat keine Verbrauchsgueter", not ns.UI.SectionHasData("consumables", "2v2"))
-- Ueber Recommend und mit Spec 264: der Test-Charakter ist Resto-Druide,
-- und den hat die M+-Stichprobe der Logs nicht erwischt. Das ist eine
-- Datenluecke (collect-all zieht jetzt 400 Berichte), keine Regelluecke.
check("M+ hat Verbrauchsgueter",
    ns.Recommend.HasSection(264, "mplus", ns.Recommend.ALL, "consumables"))
check("Guides sind immer da", ns.UI.SectionHasData("guides", "2v2"))
-- Steht man auf Verbrauchsguetern und wechselt zu 2v2, springt der
-- Abschnitt - statt eine leere Seite mit Kopfzeile zu zeigen.
ns.Profile.SetMode("mplus")
rowsInSection("consumables")
ns.Profile.SetMode("2v2")
ns.UI.Refresh()
check("Abschnitt springt bei 2v2 weg von Verbrauchsguetern",
    MetaCodexDB.section ~= "consumables", tostring(MetaCodexDB.section))
-- Guides: keine Aktivitaets- und keine Plattformwahl.
rowsInSection("guides")
check("Guides ohne Aktivitaetswahl", not _G.MetaCodexFrame.activityButton:IsShown())
check("Guides ohne Plattformwahl", not _G.MetaCodexFrame.sourceButton:IsShown())
rowsInSection("gear")
check("Ausruestung mit Aktivitaetswahl", _G.MetaCodexFrame.activityButton:IsShown())
ns.Profile.SetMode("mplus")

-- ---------------------------------------------------------- Erinnerung

-- Der Reiter zeigt, was die Chatzeile prueft: je Art eine Zeile mit
-- Stand, dazu drei Einstellungen. Fuer PvP gibt es ihn nicht - dort
-- misst niemand Verbrauchsgueter.
-- Raid statt M+: der Test-Charakter ist Resto-Druide, und dessen M+-
-- Verbrauchsgueter hat die Stichprobe der Logs nicht erwischt. Dort ist
-- der Reiter regelkonform ausgeblendet.
ns.Profile.SetMode("raid")
do
    local shown = rowsInSection("remind")
    check("Erinnerung zeigt Stand und Einstellungen", shown >= 5, shown .. " Zeilen")
    local status = ns.Remind.Status("raid")
    check("Stand kennt jede Art mit Ziel", #status >= 3, #status .. " Arten")
    local states = 0
    for _, row in ipairs(status) do
        if row.state == "ok" or row.state == "low" or row.state == "none" then states = states + 1 end
    end
    check("jeder Stand hat einen Zustand", states == #status)
    -- Die Schwelle laesst sich umschalten und die Chatzeile folgt ihr.
    ns.Profile.SetWarnBelow(1)
    local strict = #ns.Remind.Check("raid")
    ns.Profile.SetWarnBelow(0.25)
    local lax = #ns.Remind.Check("raid")
    check("strengere Schwelle meldet nicht weniger", strict >= lax, strict .. " >= " .. lax)
    ns.Profile.SetWarnBelow(0.5)
    check("Einkaufsknoepfe auch im Reiter", _G.MetaCodexFrame.createButton:IsShown())
    -- Die Verzauberungen stehen mit drin: der Test-Charakter hat
    -- unverzauberte Plaetze, also muessen offene Zeilen erscheinen.
    rowsInSection("remind")
    local enchantRows = 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.share and row.share.GetText and (row.share:GetText() or ""):find("%d") then
            enchantRows = enchantRows + 1
        end
    end
    check("offene Verzauberungen stehen im Reiter", ns.List.BuyCount(ns.List.Build(ns.Gear.Scan())) > 0
        and enchantRows > #status, enchantRows .. " Zeilen mit Fehlmenge")
    -- Und die Chatzeile beim Betreten nennt sie mit - beim NAMEN.
    --
    -- Hier stand einmal "1 Verzauberungen oder Steine offen", und die
    -- Pruefung suchte nach dem Wort "offen". Eine Zahl sagt nicht, was
    -- fehlt; im Erinnerungsfenster war sie ausserdem ein blosser Satz
    -- ohne Symbol und ohne Tooltip, zwischen Zeilen, die beides haben.
    wow.printed = {}
    ns.Remind.Announce("raid")
    local said = table.concat(wow.printed, " ")
    local offen
    for _, row in ipairs(ns.List.Build(ns.Gear.Scan())) do
        if not row.pending and not row.alt and (row.buy or 0) > 0 then
            offen = row.id
            break
        end
    end
    check("die Chatzeile nennt die offene Verzauberung beim Namen",
        offen ~= nil and said:find(tostring(offen), 1, true) ~= nil,
        tostring(offen) .. " gesucht in " .. #said .. " Zeichen")
end
check("Erinnerung fehlt bei PvP", not ns.UI.SectionHasData("remind", "2v2"))

-- ------------------------------------------------------- Held-Baeume

-- Die Namen der Held-Baeume kommen aus dem Katalog, in der Sprache des
-- Fensters.
check("Held-Baum hat einen deutschen Namen", ns.Catalog.SubTreeName(40) == "Zauberer", ns.Catalog.SubTreeName(40))
ns.SetLanguage("enUS")
check("und einen englischen", ns.Catalog.SubTreeName(40) == "Spellslinger", ns.Catalog.SubTreeName(40))
ns.SetLanguage("deDE")
do
    ns.Profile.SetMode("mplus")
    local trees = ns.Recommend.HeroTrees(105, "mplus", ns.Recommend.ALL)
    if #trees > 1 then
        rowsInSection("talents")
        check("Held-Knopf steht bei den Talenten", _G.MetaCodexFrame.heroButton:IsShown())
        ns.Profile.SetHeroTree(trees[1].id)
        local picks, build = ns.Recommend.Talents(105, "mplus", ns.Recommend.ALL, trees[1].id)
        check("Talente je Held-Baum", picks ~= nil and build ~= nil, tostring(build and build.pct))
        ns.Profile.SetHeroTree(nil)
    else
        check("ohne Held-Daten kein Knopf", true)
    end
end

-- ---------------------------------------------------------- Fundort-Filter

-- "Was faellt hier": die Ausruestung laesst sich auf eine Instanz oder
-- eine Art eingrenzen. Die Auswahl kommt aus den Zeilen selbst.
do
    ns.Profile.SetMode("mplus")
    ns.Profile.SetCategory("gearSource", nil)
    local all = rowsInSection("gear")
    local frame = _G.MetaCodexFrame
    check("Fundort-Knopf steht bei der Ausruestung", frame.originButton:IsShown())
    local sources = frame.__sources or {}
    check("mehrere Fundorte zur Wahl", #sources > 1, #sources .. " Fundorte")
    if sources[1] then
        ns.Profile.SetCategory("gearSource", sources[1].key)
        local some = rowsInSection("gear")
        check("Filter laesst weniger uebrig", some < all and some > 0, some .. " von " .. all)
        check("Knopf zeigt den Fundort", frame.originButton.label:GetText() == sources[1].label,
            tostring(frame.originButton.label:GetText()))
        ns.Profile.SetCategory("gearSource", nil)
    end
    -- Kein Gegenstand heisst mehr "kein Instanzdrop": was nicht aus
    -- Instanz, PvP oder Handwerk kommt, kommt aus Welt, Quest oder Haendler.
    rowsInSection("gear")
    local none = 0
    for _, row in ipairs(wow.rows()) do
        local t = row:IsShown() and row.detail and row.detail.GetText and row.detail:GetText()
        if t and t:find(ns.L["ORIGIN_NONE"], 1, true) then none = none + 1 end
    end
    check("kein Instanzdrop steht nirgends mehr", none == 0, none .. " Zeilen")
end

-- ----------------------------------------------- Fundort: Gruppen und Bosse

-- Ein Schlachtzug ist eine Auswahl wie die Dungeons eine sind: acht Bosse,
-- acht Fragen. Und eine Gruppe mit einem einzigen Eintrag bleibt eine
-- Gruppe - vorher stand der eine Schlachtzug nackt zwischen "Dungeons" und
-- "Sonstiges" und sah aus wie eine dritte Art.
do
    ns.Profile.SetMode("raid")
    ns.Profile.SetCategory("gearSource", nil)
    local all = rowsInSection("gear")
    local frame = _G.MetaCodexFrame
    local sources = frame.__sources or {}

    -- Die Gruppe eines Schlachtzugs heisst auch "raid".
    local raid, groups = nil, {}
    for _, src in ipairs(sources) do
        groups[src.group or "other"] = (groups[src.group or "other"] or 0) + 1
        if src.group == "raid" and #(src.bosses or {}) > (raid and #raid.bosses or 0) then
            raid = src
        end
    end
    check("im Schlachtzug steht ein Schlachtzug zur Wahl",
        (groups.raid or 0) > 0, tostring(groups.raid))
    -- Jeder Schlachtzug klappt auf, auch der mit einem einzigen Boss:
    -- zwei Eintraege, die dasselbe filtern, sagen immerhin, WER ihn
    -- fallen laesst - und einer, der sich mal oeffnet und mal nicht,
    -- ist schwerer zu lesen als einer, der es immer tut.
    local stumm = 0
    for _, src in ipairs(sources) do
        if src.group == "raid" and #(src.bosses or {}) == 0 then stumm = stumm + 1 end
    end
    check("jeder Schlachtzug nennt seine Bosse", stumm == 0,
        stumm .. " ohne Boss")

    -- Und er traegt seine Bosse.
    if raid then
        check("der Schlachtzug zeigt seine Bosse", #raid.bosses > 1,
            raid.label .. ": " .. #raid.bosses .. " Bosse")
        -- Und zwar ALLE, aus dem Journal - nicht nur die, von denen
        -- diese Woche jemand etwas traegt.
        local inst = tonumber(raid.key:match("^inst:(%d+)$"))
        local ausKatalog = inst and ns.Catalog.Bosses(inst)
        check("und zwar alle, die das Journal kennt",
            ausKatalog ~= nil and #raid.bosses == #ausKatalog,
            #raid.bosses .. " gezeigt, " .. tostring(ausKatalog and #ausKatalog) .. " im Journal")
        -- Ein Boss, von dem niemand etwas traegt, ist erlaubt - dann
        -- steht dort ein Satz und kein leeres Fenster.
        --
        -- Geprueft wird das an einem Boss, von dem nichts stammen KANN,
        -- und nicht mehr an einem, von dem gerade zufaellig nichts
        -- stammt. Vorher suchte die Pruefung einen solchen Boss in den
        -- Daten; in der Nacht auf den 28.09. gab es keinen, die Pruefung
        -- schlug fehl, und mit ihr der ganze Lauf - fuenfeinhalb Stunden
        -- Sammelarbeit kamen nirgends an. Was hier gelten soll, ist eine
        -- Eigenschaft des Fensters und keine der Messung.
        --
        -- Der Waehler nimmt seine Bossliste aus dem Katalog, also
        -- bekommt der Katalog fuer einen Moment einen Boss mehr. Damit
        -- ist die Wahl gueltig - sonst wuerfe das Fenster sie weg - und
        -- kein Gegenstand kann von ihm kommen.
        local echteBosse = ns.Catalog.Bosses
        local erfunden = 9999999
        ns.Catalog.Bosses = function(id)
            local list = echteBosse(id)
            if id ~= inst or type(list) ~= "table" then return list end
            local mehr = {}
            for i = 1, #list do mehr[i] = list[i] end
            mehr[#mehr + 1] = erfunden
            return mehr
        end
        ns.Profile.SetCategory("gearSource", "enc:" .. erfunden)
        rowsInSection("gear")
        local leer
        for _, row in ipairs(wow.rows()) do
            local t = row:IsShown() and row.title and row.title:GetText() or nil
            if t == ns.L["ORIGIN_EMPTY"] then leer = t end
        end
        ns.Catalog.Bosses = echteBosse
        ns.Profile.SetCategory("gearSource", nil)
        check("ein Boss ohne Messung sagt es", leer ~= nil, tostring(leer))

        -- Jeder Boss ist einzeln waehlbar, und die Liste wird kuerzer.
        --
        -- Genommen wird einer, von dem wirklich etwas stammt. Welcher
        -- das ist, sagen die Daten - fest auf den ersten zu zeigen hiesse
        -- wieder hoffen.
        local boss = raid.bosses[1]
        for _, b in ipairs(raid.bosses) do
            ns.Profile.SetCategory("gearSource", b.key)
            rowsInSection("gear")
            local echte = 0
            for _, row in ipairs(wow.rows()) do
                local text = row:IsShown() and row.detail and row.detail:GetText() or nil
                if text and text ~= "" then echte = echte + 1 end
            end
            if echte > 0 then boss = b break end
        end
        ns.Profile.SetCategory("gearSource", boss.key)
        local some = rowsInSection("gear")
        check("ein einzelner Boss laesst weniger uebrig", some > 0 and some < all,
            some .. " von " .. all)
        check("der Knopf nennt den Boss",
            frame.originButton.label:GetText() == boss.label,
            tostring(frame.originButton.label:GetText()))
        -- Und was uebrig bleibt, nennt WIRKLICH diesen Boss - gelesen
        -- aus dem, was im Fenster steht, nicht aus einem Feld daneben.
        local fremd, gelesen = 0, 0
        for _, row in ipairs(wow.rows()) do
            local text = row:IsShown() and row.detail and row.detail:GetText() or nil
            if text and text ~= "" then
                gelesen = gelesen + 1
                if not text:find(boss.label, 1, true) then fremd = fremd + 1 end
            end
        end
        check("und jede gezeigte Zeile nennt diesen Boss",
            gelesen > 0 and fremd == 0, fremd .. " von " .. gelesen)
        ns.Profile.SetCategory("gearSource", nil)
    end

    -- Die Instanzart kommt aus dem Katalog, nicht aus der Messung: der
    -- Katalog kennt jede Instanz des Spiels, der Sammler nur die, in
    -- denen gemessen wurde.
    local kinds = {}
    for _, src in ipairs(sources) do
        if src.key:find("^inst:") then
            local inst = tonumber(src.key:match("^inst:(%d+)$"))
            local kind = inst and ns.Catalog.InstanceKind(inst)
            if kind then kinds[kind] = (kinds[kind] or 0) + 1 end
        end
    end
    -- Und nur laufender Inhalt steht unter Dungeons oder Schlachtzuegen.
    --
    -- Die Feuerlande liefen vorige Woche als Zeitwanderung, jemand
    -- traegt seitdem ein Stueck von dort. Gemessen ist das - unter
    -- "Schlachtzuege" sucht es aber niemand.
    local alt = {}
    for _, src in ipairs(sources) do
        local inst = tostring(src.key):match("^inst:(%d+)$")
        if inst and (src.group == "raid" or src.group == "dungeon")
            and not ns.Catalog.InstanceCurrent(tonumber(inst)) then
            alt[#alt + 1] = src.label
        end
    end
    check("unter Dungeons und Schlachtzuegen steht nur laufender Inhalt",
        #alt == 0, table.concat(alt, ", "))
    check("der Katalog kennt die Art der Instanz",
        (kinds.raid or 0) + (kinds.dungeon or 0) > 0,
        tostring(kinds.raid) .. " Schlachtzuege, " .. tostring(kinds.dungeon) .. " Dungeons")
    ns.Profile.SetMode("mplus")
end

-- ------------------------------------------------------------ Raid je Boss

-- Die Bosse stehen in derselben Auswahl wie die Dungeons - und heissen
-- dort Bosse. Talente je Boss liegen mit Build vor.
do
    local bosses = ns.Recommend.Dungeons("raid")
    check("Raid kennt seine Bosse", #bosses >= 4, #bosses .. " Bosse")
    ns.Profile.SetMode("raid")
    rowsInSection("talents")
    check("Auswahl heisst im Raid 'Alle Bosse'",
        _G.MetaCodexFrame.dungeonButton.label:GetText() == ns.L["BOSS_ALL"],
        tostring(_G.MetaCodexFrame.dungeonButton.label:GetText()))
    if bosses[1] then
        local picks, build = ns.Recommend.Talents(105, bosses[1].key, ns.Recommend.ALL)
        check("Talente je Boss mit Build", picks ~= nil and build ~= nil and #build.nodes > 10,
            bosses[1].name .. ": " .. (build and #build.nodes or 0) .. " Knoten")
        -- Und eine Kette zum Kopieren.
        --
        -- Die Logs liefern Knoten, keine Kette; die Kette hat raider.io
        -- fuer die AKTIVITAET. In der Bossansicht stand deshalb "keine
        -- Quelle liefert einen fertigen String", obwohl eine danebenlag:
        -- der Rueckgriff fragte nur die Grundschwierigkeit, und "Raid
        -- (HC)" IST die Grundschwierigkeit. Jetzt geht er die ganze
        -- Leiter bis zur Aktivitaet ohne Boss.
        check("auch die Bossansicht hat eine Kette",
            build ~= nil and type(build.text) == "string" and #build.text > 20,
            build and (build.text and ("geliehen aus " .. tostring(build.fromMode))
                or "keine Kette") or "kein Build")
    end
    -- Ein Knopf muss tragen, was auf ihm steht.
    --
    -- Die Breiten der Kopfzeile waren feste Zahlen, geschaetzt an
    -- englischen Woertern. Sobald die Bossnamen aus dem Client kamen,
    -- stand "Nek'zali die Seelenwinderin" ueber dem Rand hinaus.
    if bosses[1] then
        -- Der Client nennt den Boss, und zwar auf Deutsch. Genau daran
        -- ist der Knopf zu kurz geworden.
        local realEJ = _G.EJ_GetEncounterInfo
        _G.EJ_GetEncounterInfo = function() return "Nek'zali die Seelenwinderin" end
        ns.Profile.SetDungeon(bosses[1].key)
        rowsInSection("talents")
        local button = _G.MetaCodexFrame.dungeonButton
        check("der Boss heisst, wie der Client ihn nennt",
            button.label:GetText() == "Nek'zali die Seelenwinderin",
            tostring(button.label:GetText()))
        local need = button.label:GetStringWidth()
        check("der Knopf traegt seine Beschriftung", button:GetWidth() >= need,
            math.floor(button:GetWidth()) .. " breit, Text " .. math.floor(need))
        _G.EJ_GetEncounterInfo = realEJ
        ns.Profile.SetDungeon(nil)
    end

    -- Und die Knotenlisten sind geteilt, nicht verdoppelt.
    --
    -- In der Datei steht jede Liste einmal, der Build traegt ihre
    -- Nummer, und Recommend haengt beim Laden die Tabelle selbst ein.
    -- Zweierlei muss danach stimmen: keine Nummer darf uebrig bleiben -
    -- sonst zeigt das Fenster eine Zahl statt der Talente -, und zwei
    -- Ansichten mit derselben Wahl muessen auf DIESELBE Tabelle zeigen.
    do
        local views, distinct, numbers = 0, {}, 0
        local count = 0
        for _, boss in ipairs(bosses) do
            local _, build = ns.Recommend.Talents(105, boss.key, ns.Recommend.ALL)
            if build then
                views = views + 1
                if type(build.nodes) ~= "table" then numbers = numbers + 1 end
                if not distinct[build.nodes] then
                    distinct[build.nodes] = true
                    count = count + 1
                end
            end
        end
        check("kein Build traegt noch eine Nummer", numbers == 0, numbers .. " offen")
        check("gleiche Wahl, dieselbe Tabelle", views > count,
            views .. " Ansichten, " .. count .. " Listen")
    end

    -- Die Buildkarte bleibt nicht im naechsten Abschnitt stehen.
    --
    -- Zeilen werden wiederverwendet. Die Karte hing an einer Zeile, und
    -- als dieselbe Zeile unter Top-Spielern wieder auftauchte, lag sie
    -- quer ueber dem Namen.
    do
        ns.Profile.SetMode("mplus")
        rowsInSection("talents")
        local withCard = ns.UI.VisibleCards()
        rowsInSection("players")
        check("die Karte wandert nicht in den naechsten Abschnitt",
            withCard >= 1 and ns.UI.VisibleCards() == 0,
            withCard .. " bei Talenten, " .. ns.UI.VisibleCards() .. " bei Top-Spielern")
    end

    ns.Profile.SetMode("mplus")
    rowsInSection("talents")
    check("und in M+ 'Alle Dungeons'",
        _G.MetaCodexFrame.dungeonButton.label:GetText() == ns.L["DUNGEON_ALL"])
end

-- --------------------------------------------------------- Fenstergroesse

-- Ziehbar: nach dem Loslassen des Griffs folgen Zeilen, Hinweis und
-- Scrollkind der neuen Breite, und die Groesse ist gemerkt.
do
    local f = _G.MetaCodexFrame
    f:SetSize(1200, 720)
    f.grip:GetScript("OnMouseUp")(f.grip)
    local w, h = ns.Profile.WindowSize()
    check("Groesse wird gemerkt", w == 1200 and h == 720, tostring(w) .. "x" .. tostring(h))
    rowsInSection("gear")
    local expected = 1200 - 196 - 48 - 20
    local wrong = 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row:GetWidth() ~= expected then wrong = wrong + 1 end
    end
    check("Zeilen folgen der Breite", wrong == 0, wrong .. " Zeilen falsch, erwartet " .. expected)
    f:SetSize(960, 640)
    f.grip:GetScript("OnMouseUp")(f.grip)
    rowsInSection("gear")
    wrong = 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row:GetWidth() ~= 960 - 196 - 48 - 20 then wrong = wrong + 1 end
    end
    check("und wieder zurueck", wrong == 0, wrong .. " Zeilen falsch")
end


-- /mc scale merkt sich den Faktor und wendet ihn sofort an; Unsinn
-- wird abgelehnt statt uebernommen.
check("Faktor wird gemerkt", ns.Profile.SetWindowScale("1.2") and ns.Profile.WindowScale() == 1.2)
check("Unsinn wird abgelehnt", not ns.Profile.SetWindowScale("5") and ns.Profile.WindowScale() == 1.2)
do
    local vorher = ns.UI.Frame().hintText.__fontSize
    ns.UI.ApplyScale()
    -- Die SCHRIFT traegt den Faktor, nicht das Fenster: dessen Groesse
    -- zieht man am Rand, und eine Einstellung soll eine Wirkung haben.
    check("das Fenster behaelt seine Groesse", _G.MetaCodexFrame:GetScale() == 1,
        tostring(_G.MetaCodexFrame:GetScale()))
    local nachher = ns.UI.Frame().hintText.__fontSize
    check("die Schrift waechst mit", nachher > vorher, vorher .. " -> " .. nachher)
    ns.Profile.SetWindowScale(1)
    ns.UI.ApplyScale()
    check("und wieder zurueck", ns.UI.Frame().hintText.__fontSize == vorher,
        tostring(ns.UI.Frame().hintText.__fontSize))
end

-- Mit groesserer Schrift darf sich nichts ueberlappen: die Abstaende in
-- der Seitenleiste und die Zeilenhoehen muessen mitwachsen.
do
    local function navGaps()
        local ys = {}
        for _, fr in ipairs(wow.frames) do
            if rawget(fr, "label") and rawget(fr, "section") and fr:IsShown() then
                local p = fr.__points[#fr.__points]
                -- Gemessen wird die SCHRIFT, nicht der Knopf: waechst nur
                -- sie, liegt der Text im Nachbarn, obwohl die Kaesten
                -- noch Abstand haetten.
                if p then
                    ys[#ys + 1] = { y = p[3], h = fr.label:GetStringHeight() or 12 }
                end
            end
        end
        table.sort(ys, function(a, b) return a.y > b.y end)
        return ys
    end
    local function overlaps(list)
        local bad = 0
        for i = 2, #list do
            -- Der naechste Eintrag muss UNTER der Unterkante des vorigen
            -- beginnen.
            if list[i].y > list[i - 1].y - list[i - 1].h then bad = bad + 1 end
        end
        return bad
    end
    rowsInSection("gear")
    check("Seitenleiste ohne Ueberlappung", overlaps(navGaps()) == 0)
    ns.Profile.SetWindowScale(1.4)
    ns.UI.ApplyScale()
    rowsInSection("gear")
    check("auch bei 140 Prozent Schrift", overlaps(navGaps()) == 0,
        overlaps(navGaps()) .. " ueberlappen")
    -- Und die Listenzeilen wachsen mit, statt sich zu ueberdecken.
    local tall = 0
    for _, r in ipairs(wow.rows()) do
        if r:IsShown() and r:GetHeight() > 46 then tall = tall + 1 end
    end
    check("Zeilen wachsen mit der Schrift", tall > 0, tall .. " hoehere Zeilen")
    -- Die Seitenleiste wird breiter, und der Spec-Knopf haengt hinter dem
    -- Titel statt auf festem Platz - sonst stand "MetaCodex" auf ihm.
    local f2 = ns.UI.Frame()
    check("die Seitenleiste waechst mit", f2.sidebar:GetWidth() > 196,
        tostring(f2.sidebar:GetWidth()))
    local p = f2.specButton.__points[#f2.specButton.__points]
    check("der Spec-Knopf haengt am Titel",
        p ~= nil and p[2] == f2.titleText and p[3] == "RIGHT",
        p and tostring(p[3]) or "kein Anker")
    -- Und das Fenster ist mindestens so breit, wie sein Inhalt braucht.
    check("das Fenster faellt nicht unter sein Mindestmass",
        f2:GetWidth() >= 760 * 1.4 - 1, tostring(f2:GetWidth()))
    ns.Profile.SetWindowScale(1)
    ns.UI.ApplyScale()
end

-- ---------------------------------------------------------- Shift-Klick

-- Shift-Klick auf eine Zeile mit Gegenstand verlinkt ihn - in den Chat,
-- oder ins Suchfeld des Auktionshauses, wenn das offen ist. Der
-- gewoehnliche Klick tut weiter, was er vorher tat.
ns.Profile.SetMode("raid")
do
    rowsInSection("consumables")
    local target
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.link then target = row break end
    end
    check("eine Zeile mit Gegenstand gefunden", target ~= nil)
    if target then
        wow.shift, wow.inserted = true, nil
        target:GetScript("OnClick")(target, "LeftButton")
        check("Shift-Klick fuegt den Link ein", type(wow.inserted) == "string"
            and wow.inserted:find("item:", 1, true) ~= nil, tostring(wow.inserted))
        wow.shift, wow.inserted = false, nil
        target:GetScript("OnClick")(target, "LeftButton")
        check("ohne Shift wird nichts eingefuegt", wow.inserted == nil)
    end
    -- Auch eine Ausruestungszeile: dort ist der Link ein nackter
    -- Itemstring, verlinkt wird trotzdem der volle.
    rowsInSection("gear")
    local gearRow
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.itemID then gearRow = row break end
    end
    if gearRow then
        wow.shift, wow.inserted = true, nil
        gearRow:GetScript("OnClick")(gearRow, "LeftButton")
        check("Ausruestung verlinkt den vollen Link", type(wow.inserted) == "string"
            and wow.inserted:find("|H", 1, true) ~= nil, tostring(wow.inserted))
        wow.shift = false
    end
end

-- ------------------------------------------------------------- Talente

ns.Profile.SetMode("raid")
local picks, build = ns.Recommend.Talents(105, "raid", ns.Recommend.ALL)
if picks then
    check("Talente haben Zauber-IDs",
        picks[1] and type(picks[1].spell) == "number" and picks[1].spell > 0,
        picks[1] and tostring(picks[1].spell))
    -- Nur Umstrittenes: was fast alle oder fast niemand nimmt, ist keine
    -- Entscheidung und gehoert nicht in die Liste.
    local outside = 0
    for _, pick in ipairs(picks) do
        if pick.pct < 15 or pick.pct > 85 then outside = outside + 1 end
    end
    check("nur umstrittene Talente", outside == 0, outside .. " ausserhalb 15-85%")
    check("ein vollstaendiger Build", build ~= nil and #build.nodes > 10,
        build and (#build.nodes .. " Knoten bei " .. build.pct .. "%"))
    check("Talentabschnitt zeigt Zeilen", rowsInSection("talents") > 0,
        rowsInSection("talents") .. " Zeilen")
end

-- ------------------------------------------------------------ Dungeons

-- Die Dungeonliste kommt als Tabelle aus den Daten, nicht aus einem
-- Namensmuster. Wer den Trenner aendert, soll hier scheitern und nicht
-- stillschweigend eine leere Auswahl ausliefern.
-- "mplus" und nicht "mplus-keys": welche Variante gesammelt wurde,
-- haengt am letzten Lauf, und ein Test darf nicht davon abhaengen.
local dungeons = ns.Recommend.Dungeons("mplus")
if #dungeons > 0 then
    check("Dungeons haben Schluessel und Namen",
        dungeons[1].key ~= nil and dungeons[1].name ~= nil,
        tostring(dungeons[1] and dungeons[1].name))
    check("Dungeonschluessel ist ein eigener Modus",
        ns.Recommend.HasMode(dungeons[1].key), dungeons[1].key)

    -- Ohne Auswahl der Modus selbst, mit Auswahl der Dungeon.
    ns.Profile.SetMode("mplus")
    check("ohne Auswahl der Modus", ns.Profile.LookupMode() == "mplus",
        ns.Profile.LookupMode())
    ns.Profile.SetDungeon(dungeons[1].key)
    check("mit Auswahl der Dungeon", ns.Profile.LookupMode() == dungeons[1].key,
        ns.Profile.LookupMode())

    -- Ein Moduswechsel muss die Auswahl fallen lassen, sonst stehen
    -- Raiddaten unter einem Dungeonnamen.
    ns.Profile.SetMode("raid")
    check("Moduswechsel loescht den Dungeon", ns.Profile.Dungeon() == nil,
        tostring(ns.Profile.Dungeon()))
end

-- ------------------------------------------------- Verbrauchsgueter

-- Im Raid, nicht in M+: der M+-Datensatz deckt nicht jede Spec ab, und
-- ein Test, der an der Reichweite einer Sammlung haengt, prueft nicht den
-- Code, sondern das Wetter.
ns.Profile.SetMode("raid")
check("Verbrauchsgueter zeigen Zeilen", rowsInSection("consumables") > 0,
    rowsInSection("consumables") .. " Zeilen")

-- Der Katalog muss Speisen fuehren, sonst hat die Speisenzeile nichts
-- anzubieten - und genau das war der Zustand, bevor die Verbrauchsgueter
-- hineinkamen.
-- Der Katalog fuehrt weiter alle Speisen - fuer die Einteilung nach Art
-- und fuer die Erinnerung. Die AUSWAHL daraus ist weg: welche Speise
-- benutzt wird, ist gemessen.
local foods = ns.Catalog.Consumables("food")
check("Katalog kennt Speisen", #foods > 0, #foods .. " Speisen")
check("Speisen haben IDs", foods[1] and type(foods[1].id) == "number")

-- Die Zielmengen sind eine Einstellung, keine Messung. Wer sie aendert,
-- muss sie wiederfinden.
local before = ns.Profile.ConsumableTarget("flask")
check("Zielmenge hat eine Vorgabe", before > 0, tostring(before))
ns.Profile.SetConsumableTarget("flask", 5)
check("Zielmenge gemerkt", ns.Profile.ConsumableTarget("flask") == 5)
ns.Profile.SetConsumableTarget("flask", before)

-- Die Fensterposition ueberlebt. Gespeichert wird der ANKER, nicht die
-- Bildschirmkoordinate - sonst liegt das Fenster nach einem Aufloesungs-
-- wechsel neben dem Bild.
ns.Profile.SetWindowPoint("TOPLEFT", 120, -80)
local point, wx, wy = ns.Profile.WindowPoint()
check("Fensterposition gemerkt",
    point == "TOPLEFT" and wx == 120 and wy == -80,
    tostring(point) .. " " .. tostring(wx) .. "/" .. tostring(wy))

-- ------------------------------------------------------------ Erinnerung

-- Kein Flaeschchen im Beutel, also muss die Erinnerung etwas sagen.
ns.Profile.SetMode("raid")
local missing = ns.Remind.Check("raid")
check("Erinnerung findet Fehlendes", #missing > 0, #missing .. " Posten")
check("Fehlendes hat einen Namen", missing[1] and type(missing[1].name) == "string",
    missing[1] and missing[1].name)

-- Speisen brauchen keine Sonderbehandlung mehr.
--
-- Hier stand einmal: "ohne getroffene Wahl keine Speisenwarnung", weil
-- die Logs angeblich nicht sagen konnten, WELCHE Speise. Sie koennen es -
-- ueber die Wirkung statt ueber die Aura. Damit ist eine Speise ein
-- Posten wie jeder andere, und die Erinnerung warnt davor wie vor einem
-- fehlenden Flaeschchen.
local foodWarned = false
for _, row in ipairs(missing) do
    if ns.Catalog.ConsumableKind(row.id or 0) == "food" then foodWarned = true end
end
-- Sie MUSS nicht warnen (vielleicht ist keine Speise im Datensatz), aber
-- wenn sie es tut, dann mit einem kaufbaren Gegenstand.
for _, row in ipairs(missing) do
    check("jeder gemeldete Posten hat einen Namen", type(row.name) == "string")
    break
end

-- Ausserhalb einer Instanz meldet sich nichts.
wow.instance = nil
wow.printed = {}
wow.fire("PLAYER_ENTERING_WORLD")
check("draussen bleibt sie still", #wow.printed == 0,
    table.concat(wow.printed, " | "))

-- Drinnen schon - aber erst, wenn die Taschen geantwortet haben.
--
-- Beim ersten Dungeon stand im Fenster fuenfmal "nichts in der Tasche",
-- obwohl alles im Beutel lag: PLAYER_ENTERING_WORLD kommt, sobald der
-- Ladebildschirm faellt, und bis der Server die Beutel schickt, zaehlt
-- der Client ueberall null.
wow.instance = "raid"
wow.instanceID = 42
wow.printed = {}
wow.fire("PLAYER_ENTERING_WORLD")
wow.runTimers()
check("nach dem Ladebildschirm schweigt sie noch", #wow.printed == 0,
    table.concat(wow.printed, " | "))

-- Sobald die Beutel da sind, sagt sie es.
wow.fire("BAG_UPDATE_DELAYED")
wow.runTimers()
check("im Schlachtzug warnt sie", #wow.printed > 0,
    table.concat(wow.printed, " | "))
-- Und zwar untereinander, nicht als Wurst.
--
-- Ueberschrift, je Posten eine Zeile, zum Schluss der Weg hinein. In
-- einer einzigen Zeile hintereinander war es im Chat nicht zu lesen.
do
    local head, bullets = 0, 0
    for _, line in ipairs(wow.printed) do
        if line:find(ns.L["REMIND_MISSING_HEAD"], 1, true) then head = head + 1 end
        if line:find("•", 1, true) then bullets = bullets + 1 end
    end
    check("eine Ueberschrift und je Posten eine Zeile",
        head == 1 and bullets >= 3 and #wow.printed == bullets + 1,
        #wow.printed .. " Zeilen, " .. bullets .. " Posten")
end

-- Aber nur einmal. PLAYER_ENTERING_WORLD feuert nach jedem
-- Ladebildschirm, und dreimal dieselbe Warnung ist eine Warnung weniger.
wow.printed = {}
wow.fire("PLAYER_ENTERING_WORLD")
wow.runTimers()
check("kein zweites Mal in derselben Instanz", #wow.printed == 0,
    table.concat(wow.printed, " | "))

-- Am Auktionshaus meldet sie sich einmal, wenn etwas fehlt. Nicht das
-- Fenster aufreissen: wer dort steht, hat meist etwas anderes vor.
wow.instance = nil
ns.Profile.SetMode("mplus")
MetaCodexDB.section = "enchants"
-- Bei offenem Fenster schweigt sie: die Liste liegt dann schon vor.
if ns.UI.IsShown() then ns.UI.Toggle() end
wow.printed = {}
wow.fire("AUCTION_HOUSE_SHOW")
check("Auktionshaus bietet an", #wow.printed > 0,
    table.concat(wow.printed, " | ") .. "  (fehlend: "
        .. ns.List.BuyCount(ns.List.Build(ns.Gear.Scan())) .. ")")

-- Steht das Fenster offen, meldet sie sich nicht noch einmal.
ns.UI.Toggle()
wow.printed = {}
wow.fire("AUCTION_HOUSE_SHOW")
check("bei offenem Fenster still", #wow.printed == 0,
    table.concat(wow.printed, " | "))
ns.UI.Toggle()

-- Abgeschaltet schweigt sie auch drinnen.
ns.Profile.SetReminders(false)
wow.instanceID = 43
wow.instance = "party"
wow.printed = {}
wow.fire("PLAYER_ENTERING_WORLD")
check("abgeschaltet bleibt sie still", #wow.printed == 0,
    table.concat(wow.printed, " | "))
ns.Profile.SetReminders(true)
wow.instance = nil

ns.Profile.SetMode("mplus")
MetaCodexDB.section = "enchants"
ns.UI.Refresh()

-- --------------------------------------------------------------- Sonde

wow.printed = {}
_G.SlashCmdList.METACODEX("probe")
local probeText = table.concat(wow.printed, "\n")
check("Sonde laeuft", #wow.printed > 5, #wow.printed .. " Zeilen")
-- Die Sonde legt ihren Bericht zum Kopieren hin. Der Chat ist zum
-- Lesen da: lange Zeichenketten brechen dort um, und genau die will man
-- herausholen.
local bericht
for _, f in ipairs(wow.frames) do
    if rawget(f, "box") and f.box.__text then bericht = f end
end
check("Sonde legt den Bericht zum Kopieren hin", bericht ~= nil)
if bericht then
    check("der Bericht ist mehrzeilig",
        bericht.box.__text:find("\n") ~= nil,
        tostring(#bericht.box.__text) .. " Zeichen")
    -- Farbcodes gehoeren in den Chat, nicht in die Zwischenablage.
    check("ohne Farbcodes", bericht.box.__text:find("|c") == nil)
    bericht:Hide()
end

check("Sonde ohne offene Schluessel", probeText:find("PROBE_") == nil)

wow.printed = {}
_G.SlashCmdList.METACODEX("quatsch")
check("unbekannter Befehl zeigt Hilfe", #wow.printed >= 4, #wow.printed .. " Zeilen")

-- ---------------------------------------------- Sockel und Qualitaet

-- Welche Steine stecken, nicht nur wie viele: der Kopf traegt Stein 111.
check("gesockelte Steine gelesen", scan.gems ~= nil and scan.gems[111] == 1,
    tostring(scan.gems and scan.gems[111]))

-- Der besondere Sockel gilt als belegt, sobald ein Stein mit Hauptattribut
-- steckt - vorher stand "1 leer" bei einem Hals, in dem der Diamant sass.
do
    ns.Profile.SetMode("mplus")
    ns.Profile.Set("onlyMissing", false)
    local rec = ns.Recommend.For(105, ns.Profile.Mode(), ns.Profile.Source())
    local metaPick = ns.Recommend.MetaGem(rec)
    if metaPick then
        local before = bySlot(ns.List.Build(scan))
        check("besonderer Sockel offen ohne Diamant",
            before.meta ~= nil and before.meta.missing == 1,
            before.meta and tostring(before.meta.missing) or "keine Zeile")
        local realLink = GetInventoryItemLink
        GetInventoryItemLink = function(unit, slot)
            if slot == 2 then return ("|Hitem:200002::%d::::::80:::::|h[Hals]|h"):format(metaPick.id) end
            return realLink(unit, slot)
        end
        local withGem = ns.Gear.Scan()
        check("Diamant im Hals gesehen", withGem.gems[metaPick.id] == 1)
        local after = bySlot(ns.List.Build(withGem))
        check("besonderer Sockel belegt, nichts zu kaufen",
            after.meta ~= nil and after.meta.missing == 0 and after.meta.buy == 0,
            after.meta and ("missing " .. after.meta.missing .. ", buy " .. after.meta.buy) or "keine Zeile")
        ns.Profile.Set("onlyMissing", true)
        local only = bySlot(ns.List.Build(withGem))
        check("Filter laesst den belegten besonderen Sockel weg", only.meta == nil)
        ns.Profile.Set("onlyMissing", false)
        GetInventoryItemLink = realLink
    else
        check("kein besonderer Stein empfohlen - Pruefung uebersprungen", true)
    end
end

-- Qualitaetsstufen: gleicher Name, andere Gegenstandsstufe, eigene ID.
do
    local c = MetaCodex_Catalog
    local a, b
    for i, g in ipairs(c.gems) do
        for j = i + 1, #c.gems do
            local h = c.gems[j]
            if h.name == g.name and h.ilvl ~= g.ilvl then a, b = g, h break end
        end
        if a then break end
    end
    if a then
        if a.ilvl > b.ilvl then a, b = b, a end
        local lower, higher = ns.Catalog.Tiers(a.id)
        check("Stein kennt seine hoehere Qualitaet", #lower == 0 and higher[1] == b.id,
            a.name .. ": " .. table.concat(higher, ","))
        local l2, h2 = ns.Catalog.Tiers(b.id)
        check("Stein kennt seine niedrigere Qualitaet", l2[1] == a.id and #h2 == 0)
    else
        check("kein Stein in zwei Qualitaeten im Katalog", true)
    end
    local ench
    for _, list in pairs(c.enchants) do
        for _, e in ipairs(list) do if e.alt then ench = e break end end
        if ench then break end
    end
    if ench then
        local l3 = ns.Catalog.Tiers(ench.id)
        check("Verzauberung kennt die guenstigere Stufe", l3[1] == ench.alt, tostring(l3[1]))
        local _, h4 = ns.Catalog.Tiers(ench.alt)
        check("guenstigere Stufe kennt die bessere", h4[1] == ench.id, tostring(h4[1]))
    end
    local none, none2 = ns.Catalog.Tiers(999999)
    check("ohne Geschwister leer", #none == 0 and #none2 == 0)
end

-- Besitz in anderer Qualitaet: Gold deckt Silber; Silber steht dabei,
-- deckt aber nicht.
do
    local full = bySlot(ns.List.Build(scan))
    local gem = full.gems
    -- "gem and f()" kuerzt auf EINEN Rueckgabewert - deshalb getrennt.
    local lower, higher = {}, {}
    if gem then lower, higher = ns.Catalog.Tiers(gem.id) end
    local other = gem and (higher[1] or lower[1])
    if other then
        local realCount = C_Item.GetItemCount
        C_Item.GetItemCount = function(id, ...)
            if id == other then return 2 end
            return realCount(id, ...)
        end
        local again = bySlot(ns.List.Build(scan)).gems
        if higher[1] then
            check("hoehere Qualitaet deckt den Bedarf",
                again.ownedHigher == 2 and again.buy == math.max(0, gem.buy - 2),
                "ownedHigher " .. tostring(again.ownedHigher) .. ", buy " .. tostring(again.buy))
        else
            check("niedrigere Qualitaet steht dabei, deckt aber nicht",
                again.ownedLower == 2 and again.buy == gem.buy,
                "ownedLower " .. tostring(again.ownedLower) .. ", buy " .. tostring(again.buy))
        end
        C_Item.GetItemCount = realCount
    else
        check("Stein ohne zweite Qualitaet - Besitzpruefung uebersprungen", true)
    end
end

-- Die Erinnerung: nur die niedrigere Qualitaet im Beutel ist "wenig",
-- nicht "nichts", und die Ansage sagt es so.
do
    local status = ns.Remind.Status("mplus")
    local pick, lowerID
    for _, row in ipairs(status) do
        local lower = ns.Catalog.Tiers(row.id)
        if lower[1] then pick, lowerID = row, lower[1] break end
    end
    if pick then
        local realCount = C_Item.GetItemCount
        C_Item.GetItemCount = function(id, ...)
            if id == lowerID then return 3 end
            return realCount(id, ...)
        end
        local again
        for _, row in ipairs(ns.Remind.Status("mplus")) do
            if row.id == pick.id then again = row end
        end
        check("nur niedrigere Qualitaet ist wenig, nicht nichts",
            again ~= nil and again.state == "low" and again.lower == 3 and again.owned == 0,
            again and (again.state .. " / lower " .. tostring(again.lower)) or "Zeile fehlt")
        local said = false
        for _, row in ipairs(ns.Remind.Check("mplus")) do
            if row.name == pick.name and row.lower == 3 then said = true end
        end
        check("Ansage kennt die niedrigere Qualitaet", said)
        C_Item.GetItemCount = realCount
    else
        check("kein Verbrauchsgut in zwei Qualitaeten - Erinnerung uebersprungen", true)
    end
end

-- --------------------------------------------- Besitz bei Ausruestung

-- Ein empfohlenes Stueck, das man traegt, sagt es; eines im Gepaeck
-- auch. Die Zeile sieht sonst aus, als fehlte alles.
do
    ns.Profile.SetMode("mplus")
    rowsInSection("gear")
    local ids, seen = {}, {}
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and type(row.itemID) == "number" and not seen[row.itemID] then
            ids[#ids + 1] = row.itemID
            seen[row.itemID] = true
        end
    end
    check("Ausruestungszeilen tragen IDs", #ids >= 2, #ids .. " IDs")
    if #ids >= 2 then
        local wornID, bagID = ids[1], ids[2]
        local realLink, realCount = GetInventoryItemLink, C_Item.GetItemCount
        GetInventoryItemLink = function(unit, slot)
            if slot == 1 then return ("|Hitem:%d::::::::80:::::|h[Kopf]|h"):format(wornID) end
            return realLink(unit, slot)
        end
        C_Item.GetItemCount = function(id, ...)
            if id == bagID then return 1 end
            return realCount(id, ...)
        end
        rowsInSection("gear")
        local wornText, bagText
        for _, row in ipairs(wow.rows()) do
            if row:IsShown() and row.itemID == wornID and not wornText then wornText = row.detail:GetText() end
            if row:IsShown() and row.itemID == bagID and not bagText then bagText = row.detail:GetText() end
        end
        check("getragenes Stueck sagt angelegt", wornText ~= nil and wornText:find(L["GEAR_WORN"], 1, true) ~= nil, tostring(wornText))
        check("Stueck im Gepaeck sagt es", bagText ~= nil and bagText:find(L["IN_BAGS"], 1, true) ~= nil, tostring(bagText))
        GetInventoryItemLink, C_Item.GetItemCount = realLink, realCount
        rowsInSection("gear")
        local plain
        for _, row in ipairs(wow.rows()) do
            if row:IsShown() and row.itemID == wornID and not plain then plain = row.detail:GetText() end
        end
        check("ohne Besitz kein Hinweis", plain ~= nil and plain:find(L["GEAR_WORN"], 1, true) == nil, tostring(plain))
    end
end

-- Der Heiltrank in Silber (271883) zaehlt als niedrigere Stufe des
-- goldenen (271884) - genau der Fall aus dem Spiel, in dem nichts stand.
do
    local lower = ns.Catalog.Tiers(271884)
    check("Silber-Heiltrank ist die niedrigere Stufe", lower[1] == 271883, tostring(lower[1]))
    ns.Profile.SetMode("mplus")
    ns.Profile.Set("onlyMissing", false)
    local realCount = C_Item.GetItemCount
    C_Item.GetItemCount = function(id, ...)
        if id == 271883 then return 23 end
        return realCount(id, ...)
    end
    -- Die Zeile kommt aus dem Reiter, nicht aus List.Build - dort lag
    -- der Fehler. Gesucht wird ueber die Speccs, bis eine den Trank
    -- empfiehlt.
    local wasSpec = MetaCodexDB.selectedSpec
    local hint = L["OWNED_LOWER"]:format(23)
    local found, saidLower, buyText
    for specID in pairs(MetaCodex_Catalog.specs) do
        MetaCodexDB.selectedSpec = specID
        rowsInSection("consumables")
        for _, row in ipairs(wow.rows()) do
            if row:IsShown() and row.title:GetText() == "Item 271884" then
                found = specID
                local text = row.detail:GetText() or ""
                saidLower = text:find(hint, 1, true) ~= nil
                buyText = text
                break
            end
        end
        if found then break end
    end
    MetaCodexDB.selectedSpec = wasSpec
    C_Item.GetItemCount = realCount
    check("eine Spec empfiehlt den Heiltrank", found ~= nil, tostring(found))
    if found then
        check("Heiltrank sagt: 23 in Silber vorhanden", saidLower == true, buyText)
        check("Silber deckt Gold nicht - es fehlt weiter", buyText:find(L["NEED"]:format(5), 1, true) ~= nil, buyText)
    end
end

-- Und die Suche traegt die Stueckzahl: vierzig fehlende Heiltraenke sind
-- keine Suche nach einem.
do
    ns.Profile.SetMode("raid")
    ns.Profile.SetConsumableTarget("heal", 40)
    local gesucht
    local realSearch = ns.Adapter.Search
    ns.Adapter.Search = function(rows)
        gesucht = rows
        return true, ""
    end
    ns.UI.HandoverMissing(true)
    ns.Adapter.Search = realSearch
    local mitMenge = 0
    for _, r in ipairs(gesucht or {}) do
        if (r.buy or 0) > 1 then mitMenge = mitMenge + 1 end
    end
    check("die Suche bekommt die Fehlmengen mit", mitMenge > 0,
        mitMenge .. " von " .. #(gesucht or {}))
    ns.Profile.SetConsumableTarget("heal", 5)
end

-- ----------------------------------- Die FALSCHE Verzauberung

-- "Bereits drauf" hiess bisher nur: irgendetwas ist drauf. Auf der Hose
-- sass eine andere Verzauberung, und die Zeile behauptete, alles sei
-- getan. Jetzt wird verglichen, welche es ist.
do
    ns.Profile.SetMode("mplus")
    ns.Profile.Set("onlyMissing", false)

    -- Die empfohlene Verzauberung fuer die Beine, und eine andere aus
    -- demselben Platz.
    local rec = ns.Recommend.For(105, "mplus", ns.Recommend.ALL)
    local pick = rec and ns.Recommend.Enchant(rec, "legs")
    check("es gibt eine Empfehlung fuer die Beine", pick ~= nil)
    if pick then
        -- Die Zauberkennung, die zu DIESEM Gegenstand gehoert, und eine,
        -- die zu einem anderen gehoert.
        local mine, foreignEnch
        for enchID, itemID in pairs(MetaCodex_Catalog.enchantItem) do
            if itemID == pick.id and not mine then mine = enchID end
            if itemID ~= pick.id and not foreignEnch then
                -- Nur eine, die der Katalog auch als Beinverzauberung fuehrt:
                -- sonst vergleicht der Test etwas, das dort nie sitzt.
                for _, e in ipairs(ns.Catalog.EnchantsFor("legs")) do
                    if e.id == itemID and itemID ~= pick.id then foreignEnch = enchID end
                end
            end
        end
        check("die Karte kennt die empfohlene Verzauberung", mine ~= nil, tostring(mine))
        check("und eine andere fuer denselben Platz", foreignEnch ~= nil, tostring(foreignEnch))

        local realLink = GetInventoryItemLink
        local function legsWith(enchID)
            GetInventoryItemLink = function(unit, slot)
                if slot == 7 then
                    return ("|Hitem:200007:%d::::::80:::::|h[Beine]|h"):format(enchID)
                end
                return realLink(unit, slot)
            end
            local rows = ns.List.Build(ns.Gear.Scan())
            for _, row in ipairs(rows) do
                if row.slot == "legs" and not row.alt then return row end
            end
        end

        if mine then
            local right = legsWith(mine)
            check("die richtige Verzauberung gilt als erledigt",
                right ~= nil and right.missing == 0 and right.other == nil,
                right and ("missing " .. tostring(right.missing)) or "keine Zeile")
        end
        if foreignEnch then
            local wrong = legsWith(foreignEnch)
            check("eine fremde Verzauberung zaehlt als offen",
                wrong ~= nil and wrong.missing == 1,
                wrong and ("missing " .. tostring(wrong.missing)) or "keine Zeile")
            check("und die Zeile nennt sie beim Namen",
                wrong ~= nil and wrong.other ~= nil and wrong.other ~= pick.id,
                wrong and tostring(wrong.other) or "nichts")
        end
        GetInventoryItemLink = realLink
    end
end

-- ------------------------------- Ausruestungswechsel im Fenster

-- Wer ein Stueck tauscht, waehrend das Fenster offen steht, bekam die
-- Antwort auf den Stand von vorher: "bereits drauf" unter einer frisch
-- angelegten, unverzauberten Schulter. Das Auffrischen wartete 0,1
-- Sekunden nach dem ERSTEN Ereignis - und zu dem Zeitpunkt fuehrte der
-- Client noch das alte Stueck.
do
    ns.Profile.SetMode("mplus")
    ns.Profile.Set("onlyMissing", false)
    if not ns.UI.IsShown() then ns.UI.Toggle() end
    rowsInSection("enchants")

    local function schulterZeile()
        for _, r in ipairs(wow.rows()) do
            if r:IsShown() and (r.detail:GetText() or ""):find(L["SLOT_shoulders"], 1, true) then
                return r
            end
        end
    end
    local vorher = schulterZeile()
    check("die Schulterzeile steht da", vorher ~= nil)
    check("und sie ist noch offen", vorher ~= nil
        and (vorher.detail:GetText() or ""):find(L["ALREADY_DONE"], 1, true) == nil,
        vorher and tostring(vorher.detail:GetText()))

    -- Jetzt haengt eine verzauberte Schulter am Spieler.
    local echterLink = GetInventoryItemLink
    GetInventoryItemLink = function(unit, slot)
        if slot == 3 then return "|Hitem:200003:7654::::::80:::::|h[Schultern]|h" end
        return echterLink(unit, slot)
    end

    -- Eine Folge von Ereignissen, wie sie beim Anlegen wirklich kommt.
    wow.fire("PLAYER_EQUIPMENT_CHANGED")
    wow.fire("GET_ITEM_INFO_RECEIVED")
    wow.fire("UNIT_INVENTORY_CHANGED")
    wow.runTimers()

    local nachher = schulterZeile()
    check("nach dem Wechsel sagt sie: bereits drauf", nachher ~= nil
        and (nachher.detail:GetText() or ""):find(L["ALREADY_DONE"], 1, true) ~= nil,
        nachher and tostring(nachher.detail:GetText()))

    GetInventoryItemLink = echterLink
    wow.fire("PLAYER_EQUIPMENT_CHANGED")
    wow.runTimers()
    check("und danach wieder offen", (schulterZeile() ~= nil)
        and (schulterZeile().detail:GetText() or ""):find(L["ALREADY_DONE"], 1, true) == nil,
        schulterZeile() and tostring(schulterZeile().detail:GetText()))
end

-- ------------------------------------------ Eigene Zielmenge

-- Die Stufen im Menue decken den Normalfall. Wer zwoelf Flaeschchen will,
-- soll sie eintippen koennen statt zwischen zehn und zwanzig zu waehlen.
do
    ns.Profile.SetMode("raid")
    rowsInSection("consumables")
    local row
    for _, r in ipairs(wow.rows()) do
        if r:IsShown() and rawget(r, "onClick") and (r.detail:GetText() or ""):find(L["CONSUM_TARGET"]:format(0):gsub("%d+", ""), 1, true) then
            row = r break
        end
    end
    if not row then
        for _, r in ipairs(wow.rows()) do
            if r:IsShown() and rawget(r, "onClick") then row = r break end
        end
    end
    check("eine Verbrauchsgut-Zeile gefunden", row ~= nil)
    if row then
        row.onClick(row)
        -- Welche Art die Zeile ist, verraet der Titel des Menues.
        local kind
        for _, k in ipairs({ "flask", "food", "potion", "heal", "oil", "other", "vantus" }) do
            if wow.menu() and wow.menu().title == L["CONSUM_" .. k] then kind = k end
        end
        check("das Menue nennt die Art", kind ~= nil, wow.menu() and tostring(wow.menu().title))
        check("das Menue bietet eine eigene Zahl an", wow.pick(L["CONSUM_TARGET_OWN"]),
            wow.menu() and #wow.menu().items .. " Eintraege" or "kein Menue")
        local box = _G.MetaCodexNumber
        check("das Eingabefenster steht da", box ~= nil and box:IsShown())
        if box then
            box.box:SetText("12")
            box.ok.__scripts.OnClick(box.ok)
            check("die eigene Zahl wird uebernommen",
                kind ~= nil and ns.Profile.ConsumableTarget(kind) == 12,
                kind and tostring(ns.Profile.ConsumableTarget(kind)) or "keine Art")
            check("und das Fenster ist wieder zu", not box:IsShown())
        end
    end
    -- Die Zielmenge zurueck auf einen ueblichen Wert, damit die
    -- folgenden Pruefungen nicht auf zwoelf Flaeschchen rechnen.
    ns.Profile.SetConsumableTarget("flask", 2)
    -- Und ueber der Liste steht, was ein Klick tut.
    rowsInSection("consumables")
    -- Und dazu, was die Prozentzahl daneben ueberhaupt zaehlt. Zwei
    -- Abschnitte, zwei Bezugsgroessen: genau daran ist heute ein
    -- falscher Vergleich entstanden.
    local hint = ns.UI.Frame().hintText:GetText() or ""
    check("der Hinweis erklaert den Klick",
        hint:find(L["CONSUM_HINT"], 1, true) ~= nil, hint)
    check("und sagt, worauf die Prozente sich beziehen",
        hint:find(L["SHARE_CONSUM"], 1, true) ~= nil, hint)
end

-- ------------------------------------ Sprache und gemerkte Wahl

-- Eine gespeicherte Auswahl darf ihren TEXT nicht mitbringen: nach einem
-- Sprachwechsel stand "Held 3 - 311" in einem englischen Fenster.
do
    -- Ein Pfad, der in beiden Sprachen anders heisst: "Held" und "Hero".
    local held
    for i, row in ipairs(ns.Catalog.Tracks() or {}) do
        if row.name == 974 and not held then held = i end
    end
    check("der Held-Pfad steht im Katalog", held ~= nil, tostring(held))
    ns.Profile.SetTarget({ level = 311, bonus = 12345, track = held or 5, rank = 3 })
    ns.SetLanguage("deDE")
    local de = ns.Profile.TargetLabel()
    ns.SetLanguage("enUS")
    local en = ns.Profile.TargetLabel()
    check("die Wahl spricht die Sprache des Fensters", de ~= en,
        tostring(de) .. " / " .. tostring(en))
    check("und nennt dieselbe Stufe",
        tostring(de):find("311", 1, true) ~= nil and tostring(en):find("311", 1, true) ~= nil,
        tostring(en))
    -- Und eine Wahl aus einer aelteren Fassung, die nur ihren deutschen
    -- Text und die Bonus-ID trug: sie wird zurueckgerechnet.
    local pfad = ns.Catalog.Tracks()[held or 5]
    ns.Profile.SetTarget({ level = 311, bonus = pfad.lists[3], label = "Held 3 - 311" })
    ns.SetLanguage("enUS")
    local alt = ns.Profile.TargetLabel()
    check("eine alte Wahl spricht wieder mit",
        type(alt) == "string" and alt:find("Held", 1, true) == nil, tostring(alt))
    check("und der Text ist aus den Variablen verschwunden",
        ns.Profile.Target().label == nil, tostring(ns.Profile.Target().label))
    ns.SetLanguage("deDE")
    ns.Profile.SetTarget(nil)
end

-- ------------------------------------------------- Die Fusszeile

-- Unten stand, woher die Daten kommen und von wann - eine Auskunft ueber
-- das Addon, nicht ueber den Spieler, und im Info-Reiter steht sie
-- vollstaendiger. Jetzt steht dort, was dem Charakter noch fehlt.
do
    ns.Profile.SetMode("mplus")
    ns.Profile.Set("onlyMissing", false)
    rowsInSection("enchants")
    local text = ns.UI.FooterText()
    check("die Fusszeile nennt den Urheber", text == L["CREDIT"], text)
    check("und nicht die Quelle", text:find("murlok", 1, true) == nil, text)
    -- Die Quelle ist nicht verloren, sie haengt am Zeiger.
    check("die Herkunft steht im Zeiger",
        tostring(ns.UI.Frame().__provenance or ""):find("murlok", 1, true) ~= nil,
        tostring(ns.UI.Frame().__provenance))
end

-- --------------------------------------------------- Info-Reiter

-- Fehlt Auctionator, sagt die Zeile nicht nur "fehlt", sondern gibt die
-- Adresse her - ein Klick, ein Feld, Strg+C. Von selbst laedt nichts.
do
    rowsInSection("info")
    local row
    for _, r in ipairs(wow.rows()) do
        if r:IsShown() and r.title:GetText() == "Auctionator" then row = r end
    end
    check("die Auctionator-Zeile steht im Info-Reiter", row ~= nil)
    if row then
        local installed = ns.Adapter.Loaded()
        if installed then
            -- rawget: ein unbekanntes Feld liefert im Stub ein Kind.
            check("installiert: kein Link noetig", rawget(row, "onClick") == nil)
        else
            check("nicht installiert: rot", (row.share:GetText() or "") ~= "")
            check("und ein Weg zum Addon", rawget(row, "onClick") ~= nil,
                tostring(row.detail:GetText()))
            check("der Hinweis sagt, was der Klick tut",
                (row.detail:GetText() or "") == L["INFO_AUCTIONATOR_GET"],
                tostring(row.detail:GetText()))
        end
    end
end

-- ------------------------------------------- Eigenes Verbrauchsgut

-- Wer seine Speise selbst waehlt - weil sie ein Zehntel kostet -, soll
-- nicht unter einer fremden Speise "5 fehlen" lesen. Die eigene Wahl
-- steht oben, zaehlt im Bestand und in der Erinnerung.
do
    ns.Profile.SetMode("raid")
    ns.Profile.SetConsumableTarget("food", 5)
    local mine = 255847 -- Impossibly Royal Roast, in keiner Rangliste
    local realCount = C_Item.GetItemCount
    C_Item.GetItemCount = function(id, ...)
        if id == mine then return 3 end
        return realCount(id, ...)
    end
    ns.Profile.SetOwnConsumable("food", mine)
    rowsInSection("consumables")
    local myName = ns.Compat.ItemInfo(mine)
    local row
    for _, r in ipairs(wow.rows()) do
        if r:IsShown() and r.title:GetText() == myName and not row then row = r end
    end
    check("die eigene Speise steht in der Liste", row ~= nil, tostring(myName))
    if row then
        local text = row.detail:GetText() or ""
        check("sie ist als eigene Wahl benannt", text:find(L["CONSUM_MINE"], 1, true) ~= nil, text)
        check("sie ist keine Alternative", text:find(L["ALT_ROW"], 1, true) == nil, text)
        check("ihr Bestand wird gezaehlt", text:find(L["OWNED"]:format(3), 1, true) ~= nil, text)
        check("gekauft werden nur die fehlenden",
            text:find(L["NEED"]:format(2), 1, true) ~= nil, text)
    end
    -- Die Erinnerung zaehlt dieselbe Speise.
    local status
    for _, r in ipairs(ns.Remind.Status("raid")) do
        if r.kind == "food" then status = r end
    end
    check("die Erinnerung nimmt die eigene Wahl",
        status ~= nil and status.id == mine and status.owned == 3,
        status and (status.id .. " / " .. status.owned) or "keine Zeile")
    -- Und zurueck zur Messung.
    ns.Profile.SetOwnConsumable("food", nil)
    rowsInSection("consumables")
    local back
    for _, r in ipairs(wow.rows()) do
        if r:IsShown() and r.title:GetText() == myName then back = r end
    end
    check("ohne eigene Wahl ist sie wieder weg", back == nil)
    C_Item.GetItemCount = realCount
end

-- ------------------------------------------ Wie die Erinnerung meldet

-- Vier Wege, einzeln schaltbar, und eine Vorschau, die genau das zeigt,
-- was im Ernstfall kaeme. Zwei Texte, die dasselbe sagen sollen, laufen
-- sonst auseinander.
do
    ns.Profile.SetMode("raid")
    check("ab Werk: Chatzeile und Fenster",
        ns.Profile.RemindWay("chat") and ns.Profile.RemindWay("window")
            and not ns.Profile.RemindWay("warning") and not ns.Profile.RemindWay("sound"))
    rowsInSection("remind")
    local ways, preview = {}, nil
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() then
            for _, way in ipairs({ "chat", "window", "warning", "sound" }) do
                if row.title:GetText() == L["REMIND_WAY_" .. way:upper()] then ways[way] = row end
            end
            if row.title:GetText() == L["REMIND_PREVIEW"] then preview = row end
        end
    end
    check("alle vier Wege stehen im Reiter",
        ways.chat and ways.window and ways.warning and ways.sound ~= nil)
    check("die Vorschau steht dabei", preview ~= nil)
    if ways.window then
        ways.window.onClick(ways.window)
        check("das Fenster laesst sich abschalten",
            wow.pick(L["OPTION_OFF"]) and ns.Profile.RemindWay("window") == false)
        ways.window.onClick(ways.window)
        check("und wieder an",
            wow.pick(L["OPTION_ON"]) and ns.Profile.RemindWay("window") == true)
    end
    -- Die Vorschau zeigt WAS ANLIEGT, nicht einen erfundenen Text.
    if preview then
        local said = nil
        local realPrint = ns.Print
        ns.Print = function(text) said = text end
        preview.onClick(preview)
        ns.Print = realPrint
        -- Im Chat stehen Gegenstandslinks, damit man sie anklicken kann,
        -- und ein Link, der das Addon oeffnet.
        local parts = ns.Remind.Lines("raid", true)
        local expected = #parts > 0
            and L["REMIND_MISSING"]:format(table.concat(parts, ", "))
            or L["REMIND_PREVIEW_EMPTY"]
        check("die Vorschau sagt dasselbe wie der Ernstfall",
            said ~= nil and said:sub(1, #expected) == expected, tostring(said))
        check("im Chat stehen Gegenstandslinks",
            #parts == 0 or (said:find("|Hitem:", 1, true) ~= nil), tostring(said))
        -- Und zwar zur Erinnerung: davon handelt die Zeile. Die
        -- Einkaufsliste ist der naechste Schritt, nicht die Antwort.
        check("und ein Weg zur Erinnerung",
            said:find("|Haddon:MetaCodex:remind|h", 1, true) ~= nil, tostring(said))
        -- Und das Fenster steht wirklich da, als Liste mit Symbolen.
        local window
        for _, f in ipairs(wow.frames) do
            if rawget(f, "body") and rawget(f, "title")
                and f.title:GetText() == L["REMIND_WINDOW_TITLE"] then window = f end
        end
        check("das Erinnerungsfenster steht da", window ~= nil and window:IsShown())
        -- Und zwar VOR dem grossen Fenster: die Vorschau ging vorher
        -- dahinter auf, angefordert aus eben diesem Fenster.
        check("es steht vor dem grossen Fenster",
            window ~= nil and window.__strata == "DIALOG"
                and ns.UI.Frame().__strata ~= "DIALOG",
            tostring(window and window.__strata))
        if window then
            local lines, named = 0, 0
            for _, r in ipairs(ns.UI.ReminderRows()) do
                if r:IsShown() then
                    lines = lines + 1
                    if (r.title:GetText() or "") ~= "" then named = named + 1 end
                end
            end
            check("es zeigt die Gegenstaende als Zeilen", lines > 0 and named == lines,
                lines .. " Zeilen, " .. named .. " benannt")

            -- Auch die offene Verzauberung ist eine Zeile mit Symbol.
            --
            -- Sie war ein Satz: "1 Verzauberungen oder Steine offen" -
            -- kein Symbol, kein Tooltip, kein Shift-Klick, und sie sagte
            -- nicht, WAS fehlt. Eine Zahl kann man nicht kaufen.
            local offen
            for _, row in ipairs(ns.List.Build(ns.Gear.Scan())) do
                if not row.pending and not row.alt and (row.buy or 0) > 0 then
                    offen = row.id
                    break
                end
            end
            local alsZeile = false
            for _, r in ipairs(ns.UI.ReminderRows()) do
                if r:IsShown() and rawget(r, "itemID") == offen then alsZeile = true end
            end
            check("die offene Verzauberung steht als eigene Zeile", alsZeile,
                tostring(offen) .. " unter " .. lines .. " Zeilen")
            -- Der Titel braucht eine rechte Kante.
            --
            -- Ohne sie nimmt er sich die ganze Zeile, und
            -- "Konzentrierter Silbermondheiltrank" lief quer durch das
            -- "39 in niedrigerer Qualität" daneben. Im Bild sah das aus
            -- wie ein kaputtes Fenster.
            local bounded = 0
            for _, r in ipairs(ns.UI.ReminderRows()) do
                if r:IsShown() then
                    for _, point in ipairs(r.title.__points or {}) do
                        if point[1] == "RIGHT" then bounded = bounded + 1 break end
                    end
                end
            end
            check("der Titel endet vor dem Zustand", bounded == lines,
                bounded .. " von " .. lines .. " begrenzt")
            -- Der Suchknopf folgt dem Auktionshaus, auch wenn es erst
            -- aufgeht, waehrend das Fenster schon steht.
            local realOpen = ns.Adapter.AuctionHouseOpen
            ns.Adapter.AuctionHouseOpen = function() return false end
            ns.UI.UpdateReminderButtons()
            check("ohne Auktionshaus ist Suchen grau", window.search:IsEnabled() == false)
            ns.Adapter.AuctionHouseOpen = function() return true end
            wow.fire("AUCTION_HOUSE_SHOW")
            check("mit offenem Auktionshaus ist Suchen da", window.search:IsEnabled() == true)
            ns.Adapter.AuctionHouseOpen = realOpen
            -- Der Knopf uebergibt, was JETZT fehlt - nicht das, was im
            -- grossen Fenster gerade offen ist.
            do
                MetaCodexDB.section = "talents"
                local sent
                local realCreate = ns.Adapter.CreateList
                ns.Adapter.CreateList = function(rows, section)
                    sent = { rows = rows, section = section }
                    return true, "Liste", #rows
                end
                window.create.__scripts.OnClick(window.create)
                ns.Adapter.CreateList = realCreate
                check("die Liste kommt aus der Erinnerung",
                    sent ~= nil and sent.section == "remind", sent and sent.section or "nichts")
                local fehlt = 0
                for _, r in ipairs(sent and sent.rows or {}) do
                    if (r.buy or 0) > 0 then fehlt = fehlt + 1 end
                end
                check("und enthaelt nur, was fehlt",
                    sent ~= nil and #sent.rows > 0 and fehlt == #sent.rows,
                    fehlt .. " von " .. #(sent and sent.rows or {}))
                -- Sie ist fuer diesen einen Einkauf: schliesst das
                -- Auktionshaus, raeumt sie sich weg.
                -- Temporaer ist sie nur, wo Auctionator loeschen kann.
                -- Kann es das nicht, bleibt sie stehen - und das Addon
                -- behauptet dann auch nichts anderes.
                local geloescht
                local realDelete = ns.Adapter.DeleteList
                local realHas = ns.Adapter.Has
                ns.Adapter.DeleteList = function(name) geloescht = name return true end
                ns.Adapter.Has = function(what)
                    if what == "DeleteShoppingList" then return true end
                    return realHas(what)
                end
                window.create.__scripts.OnClick(window.create)
                wow.fire("AUCTION_HOUSE_CLOSED")
                check("mit Loeschfunktion ist die Liste temporaer",
                    type(geloescht) == "string" and geloescht:find("MetaCodex", 1, true) ~= nil,
                    tostring(geloescht))
                geloescht = nil
                ns.Adapter.Has = function(what)
                    if what == "DeleteShoppingList" then return false end
                    return realHas(what)
                end
                window.create.__scripts.OnClick(window.create)
                wow.fire("AUCTION_HOUSE_CLOSED")
                check("ohne Loeschfunktion bleibt sie stehen", geloescht == nil)
                ns.Adapter.Has = realHas
                -- Und nur einmal: ein zweites Schliessen loescht nichts.
                geloescht = nil
                wow.fire("AUCTION_HOUSE_CLOSED")
                check("ohne Liste wird nichts geloescht", geloescht == nil)
                ns.Adapter.DeleteList = realDelete
            end
            check("und hat beide Knoepfe",
                window.create ~= nil and window.search ~= nil
                    and window.create.label:GetText() == L["BTN_CREATE_LIST"]
                    and window.search.label:GetText() == L["BTN_SEARCH"])
        end
    end
end

-- --------------------------------------------- Talente erklaeren

-- Eine Talentzeile zeigt das Tooltip ihres Zaubers, und der Anteil sagt,
-- was er bedeutet. Vorher stand dort eine Zahl ohne Frage und ein Name
-- ohne Erklaerung.
do
    ns.Profile.SetMode("mplus")
    rowsInSection("talents")
    local talent
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and rawget(row, "spellID") then talent = row break end
    end
    check("eine Talentzeile kennt ihren Zauber", talent ~= nil,
        talent and tostring(talent.spellID) or "keine")
    -- Der erklaerende Satz steht IN der Gruppe, die er meint, nicht ueber
    -- der ganzen Seite: dort stand er auch ueber den Builds.
    local oben = ns.UI.Frame().hintText:GetText() or ""
    check("oben steht keine Erklaerung mehr zu einer Gruppe",
        oben:find(L["TALENT_PICKS_HINT"], 1, true) == nil, oben)
    local drin = false
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.title:GetText() == L["TALENT_PICKS_HINT"] then drin = true end
    end
    check("sie steht bei den einzelnen Talenten", drin)
    if talent then
        local shown = false
        local realOwner, realSpell = GameTooltip.SetOwner, GameTooltip.SetSpellByID
        GameTooltip.SetSpellByID = function(_, id) shown = (id == talent.spellID) end
        talent.__scripts.OnEnter(talent)
        GameTooltip.SetSpellByID, GameTooltip.SetOwner = realSpell, realOwner
        check("der Zeiger zeigt das Tooltip des Zaubers", shown)
        check("der Anteil sagt, was er bedeutet",
            (talent.detail:GetText() or ""):find("%%") ~= nil,
            tostring(talent.detail:GetText()))
    end
end

-- ------------------------------------ Rangliste nach dem Neuladen

-- Stand beim Abmelden noch ein Dungeon in der Auswahl, suchte der
-- Abschnitt "Top-Spieler" die Rangliste nur unter diesem Dungeon - und
-- dort fuehrt keine Quelle eine. Der Reiter war leer, bis man die
-- Aktivitaet wechselte (was den Dungeon loescht).
do
    ns.Profile.SetMode("mplus")
    local withoutDungeon = rowsInSection("players")
    check("Rangliste ohne Dungeon", withoutDungeon > 0, withoutDungeon .. " Zeilen")
    MetaCodexDB.dungeon = "mplus/kings-rest"
    local withDungeon = rowsInSection("players")
    check("Rangliste auch mit gewaehltem Dungeon", withDungeon == withoutDungeon,
        withDungeon .. " statt " .. withoutDungeon)
    -- Dasselbe bei den Verbrauchsguetern: auch dort stand nach einem
    -- Neuladen nichts, solange ein Dungeon in der Auswahl hing.
    local ohne = rowsInSection("consumables")
    MetaCodexDB.dungeon = "mplus/kings-rest"
    local mit = rowsInSection("consumables")
    check("Verbrauchsgueter auch mit gewaehltem Dungeon", mit > 0,
        mit .. " statt " .. ohne)
    MetaCodexDB.dungeon = nil
end

-- ------------------------------------------- Schmales Fenster

-- Das Fenster ist ziehbar. Wird es schmal, passt die Knopfreihe nicht
-- mehr neben den Abschnittstitel - dann gehoert sie darunter, nicht
-- darauf.
do
    local f = ns.UI.Frame()
    local wasWidth = f:GetWidth()
    local function buttonY()
        local p = f.levelButton.__points[#f.levelButton.__points]
        return p and p[3] or 0
    end
    f:SetWidth(960)
    rowsInSection("gear")
    local wide = buttonY()
    check("breit: Knoepfe stehen neben dem Titel", wide > -30, tostring(wide))
    f:SetWidth(520)
    rowsInSection("gear")
    local narrow = buttonY()
    check("schmal: Knoepfe rutschen unter den Titel", narrow <= wide - 20,
        narrow .. " statt " .. wide)
    check("schmal: die Liste folgt nach unten",
        (function()
            -- Der letzte Punkt ist inzwischen die untere rechte Ecke;
            -- gesucht ist die obere linke.
            for i = #f.scroll.__points, 1, -1 do
                local p = f.scroll.__points[i]
                if p[1] == "TOPLEFT" then return p[3] < 0 end
            end
            return false
        end)())
    -- Kein Knopf darf ueber den linken Rand hinausragen, auch nicht bei
    -- der kleinsten erlaubten Breite.
    f:SetWidth(760)
    rowsInSection("gear")
    local over = 0
    for _, pair in ipairs({ { f.levelButton, 175 }, { f.slotButton, 150 },
        { f.originButton, 170 }, { f.heroButton, 170 },
        { f.categoryButton, 170 }, { f.dungeonButton, 160 } }) do
        if pair[1]:IsShown() then
            local p = pair[1].__points[#pair[1].__points]
            if p and -p[2] + pair[2] > f:GetWidth() - 196 - 24 - 20 then over = over + 1 end
        end
    end
    check("kleinste Breite: kein Knopf ragt hinaus", over == 0, over .. " zu weit")
    f:SetWidth(wasWidth)
    rowsInSection("gear")
    check("wieder breit: Knoepfe stehen wieder oben", buttonY() == wide, tostring(buttonY()))
    -- Und der Hinweis draengt sich nicht mit der Liste: ein Satz, der
    -- umbricht, schiebt sie nach unten, statt unter ihr zu liegen.
    local function listTop()
        for i = #f.scroll.__points, 1, -1 do
            local p = f.scroll.__points[i]
            if p[1] == "TOPLEFT" then return p[3] end
        end
    end
    -- Einstellungen: dort steht immer ein Satz unter dem Titel, an dem
    -- sich der Abstand messen laesst.
    rowsInSection("settings")
    local mitHinweis = listTop()
    -- Ziehen ordnet sofort neu an, ohne neu nachzuschlagen: dieselben
    -- Zeilen, andere Breite. Vorher sprang das Fenster erst beim
    -- Loslassen in Form.
    do
        local vorher = {}
        for _, r in ipairs(wow.rows()) do
            if r:IsShown() then vorher[#vorher + 1] = r.title:GetText() end
        end
        f:SetWidth(1200)
        ns.UI.Relayout()
        local breite, nachher = 0, {}
        for _, r in ipairs(wow.rows()) do
            if r:IsShown() then
                nachher[#nachher + 1] = r.title:GetText()
                breite = math.max(breite, r:GetWidth())
            end
        end
        check("Ziehen ordnet die Zeilen sofort neu an", breite > 800, breite .. " breit")
        check("und sagt dabei dasselbe wie vorher",
            table.concat(vorher, "|") == table.concat(nachher, "|"))
        f:SetWidth(960)
        ns.UI.Relayout()
        mitHinweis = listTop()
    end
    local hint = f.hintText
    check("die Liste beginnt unter dem Hinweis",
        mitHinweis ~= nil and math.abs(mitHinweis) > math.abs(hint.__points[#hint.__points][3]),
        tostring(mitHinweis))
    -- Und der Abstand reicht wirklich fuer den ganzen Satz: die Liste
    -- beginnt unter der Unterkante des Hinweises, nicht 16 Pixel unter
    -- seiner Oberkante.
    local hintY = hint.__points[#hint.__points][3]
    check("der Hinweis passt zwischen Titel und Liste",
        math.abs(listTop()) >= math.abs(hintY) + hint:GetStringHeight(),
        math.abs(listTop()) .. " >= " .. (math.abs(hintY) + hint:GetStringHeight()))
    rowsInSection("gear")
end

-- ------------------------------------------------- Einstellungen

-- Der Reiter "Einstellungen" steht immer zur Verfuegung, auch wenn zur
-- Aktivitaet sonst nichts vorliegt: er haengt an keiner Messung.
do
    check("Einstellungen sind immer da", ns.UI.SectionHasData("settings") == true)
    local shown = rowsInSection("settings")
    check("Einstellungen zeigen Zeilen", shown >= 4, shown .. " Zeilen")
    local labels = {}
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() then labels[row.title:GetText() or ""] = row end
    end
    check("Schalter fuer den Minimap-Knopf", labels[L["SET_MINIMAP"]] ~= nil)
    check("Schalter fuer den Charakterknopf", labels[L["SET_CHARBTN"]] ~= nil)
    check("Fenstergroesse steht dabei", labels[L["SET_SCALE"]] ~= nil)
    check("Sprache steht dabei", labels[L["SET_LANG"]] ~= nil)
    check("Zuruecksetzen steht dabei", labels[L["SET_RESET"]] ~= nil)
    check("Startaktivitaet steht dabei", labels[L["SET_START"]] ~= nil)
    -- Ab Werk an, und der Klick schaltet wirklich um.
    check("Minimap-Knopf ist ab Werk an", ns.Profile.MinimapOn() == true)
    local row = labels[L["SET_MINIMAP"]]
    if row and row.onClick then
        row.onClick(row)
        check("Klick oeffnet eine Auswahl", wow.menu() ~= nil and #wow.menu().items == 2,
            wow.menu() and #wow.menu().items .. " Eintraege" or "kein Menue")
        check("die Auswahl heisst wie die Zeile", wow.menu().title == L["SET_MINIMAP"],
            tostring(wow.menu().title))
        check("Aus waehlen schaltet den Minimap-Knopf ab",
            wow.pick(L["OPTION_OFF"]) and ns.Profile.MinimapOn() == false)
        -- Die Zeile sagt danach "Aus" - ein Schalter ohne sichtbaren Stand
        -- ist keiner.
        rowsInSection("settings")
        local again
        for _, r in ipairs(wow.rows()) do
            if r:IsShown() and r.title:GetText() == L["SET_MINIMAP"] then again = r end
        end
        check("die Zeile zeigt den neuen Stand",
            again ~= nil and again.share:GetText() == L["OPTION_OFF"],
            again and tostring(again.share:GetText()) or "Zeile fehlt")
        again.onClick(again)
        check("und wieder an", wow.pick(L["OPTION_ON"]) and ns.Profile.MinimapOn() == true)
    end
    -- Die Fenstergroesse laeuft in Stufen im erlaubten Bereich.
    local sizeRow = labels[L["SET_SCALE"]]
    if sizeRow and sizeRow.onClick then
        sizeRow.onClick(sizeRow)
        check("Fenstergroessen stehen zur Wahl", #wow.menu().items == 6,
            #wow.menu().items .. " Stufen")
        check("eine Stufe waehlen wirkt sofort",
            wow.pick("125 %") and math.abs(ns.Profile.WindowScale() - 1.25) < 0.001,
            tostring(ns.Profile.WindowScale()))
        -- Jede angebotene Stufe liegt im erlaubten Bereich - eine, die
        -- SetWindowScale ablehnt, waere ein Eintrag ins Leere.
        local bad = 0
        sizeRow.onClick(sizeRow)
        for _, entry in ipairs(wow.menu().items) do
            entry.run()
            if ns.Profile.WindowScale() < 0.6 or ns.Profile.WindowScale() > 1.6 then bad = bad + 1 end
        end
        check("jede angebotene Stufe ist erlaubt", bad == 0, bad .. " daneben")
        ns.Profile.SetWindowScale(1)
    end
end

-- Zuruecksetzen vergisst Lage und Groesse wirklich, statt sie auf einen
-- Ersatzwert zu setzen: sonst stuende nach einem Umbau des Fensters eine
-- alte Zahl da, die niemand mehr gewaehlt hat.
do
    ns.Profile.SetWindowPoint("TOPLEFT", 40, -40)
    ns.Profile.SetWindowSize(1200, 800)
    ns.Profile.SetWindowScale(1.25)
    rowsInSection("settings")
    local reset
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.title:GetText() == L["SET_RESET"] then reset = row end
    end
    check("Zeile zum Zuruecksetzen gefunden", reset ~= nil)
    if reset then
        reset.onClick(reset)
        check("Lage vergessen", ns.Profile.WindowPoint() == nil)
        check("Groesse vergessen", ns.Profile.WindowSize() == nil)
        check("Skalierung wieder auf eins", ns.Profile.WindowScale() == 1,
            tostring(ns.Profile.WindowScale()))
    end
end

-- Die Startaktivitaet: ohne Wahl bleibt, was zuletzt offen war; mit Wahl
-- geht das Fenster immer damit auf.
do
    check("ohne Wahl keine Startaktivitaet", ns.Profile.StartMode() == nil)
    ns.Profile.SetMode("mplus")
    ns.Profile.SetStartMode("2v2")
    if ns.UI.IsShown() then ns.UI.Toggle() end
    ns.UI.Toggle()
    check("Fenster geht mit der gewaehlten Aktivitaet auf", ns.Profile.Mode() == "2v2",
        ns.Profile.Mode())
    ns.Profile.SetStartMode(nil)
    ns.Profile.SetMode("mplus")
    ns.UI.Toggle()
    ns.UI.Toggle()
    check("ohne Wahl bleibt die letzte stehen", ns.Profile.Mode() == "mplus", ns.Profile.Mode())
    -- Der Schalter laeuft durch alle Aktivitaeten und wieder zu "zuletzt".
    rowsInSection("settings")
    local startRow
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.title:GetText() == L["SET_START"] then startRow = row end
    end
    if startRow then
        startRow.onClick(startRow)
        check("alle Aktivitaeten stehen zur Wahl", #wow.menu().items == #ns.MODES + 1,
            #wow.menu().items .. " Eintraege")
        check("eine Aktivitaet waehlen setzt sie",
            wow.pick(ns.MODES[3].label) and ns.Profile.StartMode() == ns.MODES[3].key,
            tostring(ns.Profile.StartMode()))
        startRow.onClick(startRow)
        check("zurueck auf zuletzt benutzt",
            wow.pick(L["SET_START_LAST"]) and ns.Profile.StartMode() == nil,
            tostring(ns.Profile.StartMode()))
    end
end

-- Die Chatzeile beim Betreten ist getrennt von der am Auktionshaus
-- schaltbar - beide haengen weiter am Hauptschalter.
do
    check("Erinnerung beim Betreten ist ab Werk an", ns.Profile.RemindOnEnter() == true)
    -- Raid statt M+: der Test-Charakter ist Resto-Druide, dessen
    -- M+-Verbrauchsgueter die Stichprobe nicht erwischt hat - dort ist der
    -- Reiter regelkonform ausgeblendet.
    ns.Profile.SetMode("raid")
    rowsInSection("remind")
    local enter, ah
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.title:GetText() == L["REMIND_OPT_ENTER"] then enter = row end
        if row:IsShown() and row.title:GetText() == L["REMIND_OPT_AH"] then ah = row end
    end
    check("beide Schalter stehen im Erinnerungsreiter", enter ~= nil and ah ~= nil,
        (enter and "Betreten da" or "Betreten fehlt") .. ", "
        .. (ah and "AH da" or "AH fehlt") .. " in " .. tostring(MetaCodexDB.section))
    if enter and ah then
        enter.onClick(enter)
        check("Aus waehlen schaltet das Betreten ab",
            wow.pick(L["OPTION_OFF"]) and ns.Profile.RemindOnEnter() == false)
        check("das Auktionshaus bleibt davon unberuehrt", ns.Profile.RemindAtAuctionHouse() == true)
        enter.onClick(enter)
        check("und wieder an", wow.pick(L["OPTION_ON"]) and ns.Profile.RemindOnEnter() == true)
    end
end

-- Der Knopf an der Minimap. Im Stub gibt es keine Minimap, also stellen
-- wir eine hin - gebaut wird er nur, wenn es eine gibt.
do
    check("ohne Minimap kein Knopf", ns.Minimap.Button() == nil)
    Minimap = CreateFrame("Frame", "Minimap")
    -- Eine Minimap MIT Groesse: der Knopf sitzt an ihrem Rand, und
    -- welcher das ist, kann er nur von ihr erfahren.
    Minimap:SetSize(198, 198)
    Minimap.GetCenter = function() return 100, 100 end
    Minimap.GetEffectiveScale = function() return 1 end
    ns.Profile.SetMinimap(true)
    local button = ns.Minimap.Update()
    check("Minimap-Knopf gebaut", button ~= nil and button:IsShown())
    check("er traegt das Logo",
        button ~= nil and tostring(button.icon.__texture or ""):find("logo", 1, true) ~= nil,
        button and tostring(button.icon.__texture) or "kein Knopf")
    -- Er sitzt auf dem Ring: der gemerkte Winkel wird zu einem Punkt um
    -- den Mittelpunkt, nicht zu einer Bildschirmkoordinate.
    local p = button.__points[#button.__points]
    check("er haengt an der Minimap", p ~= nil and p[2] == Minimap and p[3] == "CENTER",
        p and tostring(p[3]) or "kein Anker")
    -- Gemessen, nicht geraten: halbe Breite plus der Abstand, den ein
    -- Knopf zum Rand haelt. Frueher stand hier eine feste 80 - die Zahl
    -- der Blizzard-Minimap in ihrer Standardgroesse. Wer sie skaliert
    -- oder ElvUI benutzt, bekam den Knopf mitten ins Bild.
    local rand = 198 / 2 + 5
    local dist = p and math.floor(math.sqrt(p[4] * p[4] + p[5] * p[5]) + 0.5)
    check("er sitzt am Rand DIESER Minimap", dist == rand,
        tostring(dist) .. " statt " .. rand)
    -- Ein anderer Winkel verschiebt ihn, der Abstand bleibt.
    ns.Profile.SetMinimapAngle(0)
    ns.Minimap.Update()
    local q = button.__points[#button.__points]
    check("ein anderer Winkel, derselbe Rand",
        math.floor(q[4] + 0.5) == rand and math.floor(q[5] + 0.5) == 0,
        math.floor(q[4] + 0.5) .. "/" .. math.floor(q[5] + 0.5))

    -- Eine groessere Minimap schiebt ihn weiter nach aussen.
    Minimap:SetSize(280, 280)
    ns.Minimap.Update()
    local g = button.__points[#button.__points]
    check("eine groessere Minimap, ein weiterer Rand",
        math.floor(g[4] + 0.5) == 280 / 2 + 5,
        tostring(math.floor(g[4] + 0.5)))

    -- Und eine ECKIGE Minimap - ElvUI sagt das ueber GetMinimapShape.
    -- Auf der Diagonale liegt die Ecke weiter draussen als der Kreis;
    -- der Knopf folgt der Kante, statt im Bild zu landen.
    GetMinimapShape = function() return "SQUARE" end
    ns.Profile.SetMinimapAngle(45)
    ns.Minimap.Update()
    local e = button.__points[#button.__points]
    local halb = 280 / 2 + 5
    -- Nicht GENAU in die Ecke: die Ecke eines Quadrats liegt weiter
    -- draussen als sein Rand, und ein Knopf, der dort klebt, haengt in
    -- der Luft. Er geht auf der Diagonale aber deutlich ueber den Kreis
    -- hinaus - genau das ist der Unterschied zur runden Minimap.
    local aufDemKreis = halb * math.cos(math.rad(45))
    check("eckige Minimap: der Knopf geht Richtung Ecke",
        math.abs(e[4] - e[5]) < 1 and e[4] > aufDemKreis + 5 and e[4] <= halb,
        math.floor(e[4] + 0.5) .. "/" .. math.floor(e[5] + 0.5)
            .. " (Kreis waere " .. math.floor(aufDemKreis + 0.5) .. ")")
    -- Auf der Seite bleibt er auf der Kante, nicht davor.
    ns.Profile.SetMinimapAngle(0)
    ns.Minimap.Update()
    local k = button.__points[#button.__points]
    check("eckige Minimap: und auf der Seite auf der Kante",
        math.floor(k[4] + 0.5) == halb and math.floor(k[5] + 0.5) == 0,
        math.floor(k[4] + 0.5) .. "/" .. math.floor(k[5] + 0.5))
    GetMinimapShape = nil
    Minimap:SetSize(198, 198)
    ns.Profile.SetMinimapAngle(0)
    ns.Minimap.Update()
    -- Linksklick oeffnet, Rechtsklick fuehrt zu den Einstellungen.
    local before = ns.UI.IsShown()
    button.__scripts.OnClick(button, "LeftButton")
    check("Klick an der Minimap schaltet das Fenster um", ns.UI.IsShown() ~= before)
    button.__scripts.OnClick(button, "LeftButton")
    button.__scripts.OnClick(button, "RightButton")
    check("Rechtsklick zeigt die Einstellungen", MetaCodexDB.section == "settings")
    -- Abgeschaltet verschwindet er, ohne zerstoert zu werden.
    ns.Profile.SetMinimap(false)
    ns.Minimap.Update()
    check("abgeschaltet ist er weg", not button:IsShown())
    ns.Profile.SetMinimap(true)
    ns.Minimap.Update()
    check("wieder an ist er da", button:IsShown())
end

-- ---------------------------------------------- Charakterfenster

-- Der Knopf im Charakterfenster oeffnet und schliesst das Fenster. Das
-- Charakterfenster gibt es im Stub nicht - hier steht ein Platzhalter
-- mit Schliessen-Kreuz, damit die Verankerung denselben Weg nimmt.
do
    CharacterFrame = CreateFrame("Frame", "CharacterFrame")
    CharacterFrame.CloseButton = CreateFrame("Button", nil, CharacterFrame)
    local button = ns.UI.AttachCharacterButton()
    check("Knopf im Charakterfenster gebaut", button ~= nil and button.icon ~= nil)
    check("ein zweiter Aufruf baut keinen zweiten", ns.UI.AttachCharacterButton() == button)
    if button then
        check("das Symbol ist das Logo", tostring(button.icon.__texture or ""):find("logo", 1, true) ~= nil,
            tostring(button.icon.__texture))
        local before = ns.UI.IsShown()
        button.__scripts.OnClick(button, "LeftButton")
        check("Klick schaltet das Fenster um", ns.UI.IsShown() ~= before)
        button.__scripts.OnClick(button, "LeftButton")
        check("zweiter Klick schaltet zurueck", ns.UI.IsShown() == before)
        -- Rechtsklick ohne Umschalt tut nichts; mit Umschalt setzt er die
        -- gemerkte Lage zurueck.
        MetaCodexDB.charButton = { x = 123, y = 45 }
        IsShiftKeyDown = function() return false end
        button.__scripts.OnClick(button, "RightButton")
        check("Rechtsklick allein laesst die Lage", MetaCodexDB.charButton ~= nil and ns.UI.IsShown() == before)
        IsShiftKeyDown = function() return true end
        button.__scripts.OnClick(button, "RightButton")
        check("Umschalt-Rechtsklick setzt die Lage zurueck", MetaCodexDB.charButton == nil)
        -- Ohne eigene Wahl haengt er am rechten Rand, nicht am linken:
        -- links lag er hinter der Rahmenkante.
        local anchor = button.__points[#button.__points]
        check("Vorgabeplatz ist rechts", anchor ~= nil and anchor[3] == "TOPRIGHT",
            anchor and tostring(anchor[3]) or "kein Anker")
        IsShiftKeyDown = nil
        -- Tooltip nennt beides: oeffnen und verschieben.
        GameTooltip.__lines = {}
        GameTooltip.AddLine = function(self, text) self.__lines[#self.__lines + 1] = text end
        button.__scripts.OnEnter(button)
        check("Tooltip erklaert den Knopf", #GameTooltip.__lines == 3 and GameTooltip.__lines[3] == L["CHARBTN_MOVE"],
            table.concat(GameTooltip.__lines, " / "))
        if not ns.UI.IsShown() then ns.UI.Toggle() end
        -- Und er folgt seinem Schalter in den Einstellungen.
        ns.Profile.SetCharButton(false)
        ns.UI.UpdateCharacterButton()
        check("abgeschaltet ist der Charakterknopf weg", not button:IsShown())
        ns.Profile.SetCharButton(true)
        ns.UI.UpdateCharacterButton()
        check("wieder an ist er da", button:IsShown())
    end
end

-- ------------------------------------------------- Spieleransicht

-- Zurueck ist ein Knopf im Kopf, keine Zeile in der Liste; ein einzelnes
-- Stueck traegt Namen und keinen Anteil - "0 %" hat niemand gemessen.
if top then
    ns.Profile.SetMode("mplus")
    rowsInSection("players")
    local first
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.onClick and row.title:GetText() == top[1].name then
            first = row
            break
        end
    end
    check("Spielerzeile gefunden", first ~= nil, top[1].name)
    if first then
        first.onClick(first, "LeftButton")
        local backRows, zeroPct, unnamed, shown = 0, 0, 0, 0
        for _, row in ipairs(wow.rows()) do
            if row:IsShown() then
                shown = shown + 1
                if row.title:GetText() == L["PLAYER_BACK"] then backRows = backRows + 1 end
                if row.share and row.share:GetText() == "0%" then zeroPct = zeroPct + 1 end
                if tostring(row.title:GetText() or ""):match("^#%d+$") then unnamed = unnamed + 1 end
            end
        end
        check("Spieleransicht zeigt Zeilen", shown > 0, shown .. " Zeilen")
        check("Zurueck ist keine Zeile mehr", backRows == 0, backRows .. " Zeilen")
        check("kein 0 % in der Spieleransicht", zeroPct == 0, zeroPct .. " Zeilen")
        check("jedes Stueck hat einen Namen", unnamed == 0, unnamed .. " ohne")
        -- Was auf den Stuecken sitzt, steht darunter. Vorher sah die
        -- Ansicht aus, als spielte der Beste ohne Verzauberungen.
        local ench, gems = 0, 0
        for _, r in ipairs(wow.rows()) do
            if r:IsShown() then
                -- Die Unterzeilen tragen ihre Beschriftung klein IM Titel;
                -- eine eigene Detailzeile haetten sie nur, waeren sie so
                -- gross wie ein Ausruestungsstueck.
                local text = (r.title:GetText() or "") .. " " .. (r.detail:GetText() or "")
                if text:find(L["PLAYER_ENCHANT"], 1, true) then ench = ench + 1 end
                if text:find(L["PLAYER_GEM"], 1, true) then gems = gems + 1 end
            end
        end
        check("Verzauberungen des Spielers stehen dabei", ench > 0, ench .. " Zeilen")
        check("Steine des Spielers stehen dabei", gems > 0, gems .. " Zeilen")
        -- Klein, nicht gleich gross: das Zubehoer soll die Liste nicht
        -- aussehen lassen, als truege der Spieler drei Haelse.
        local big, small = 0, 0
        for _, r in ipairs(wow.rows()) do
            if r:IsShown() then
                local text = r.title:GetText() or ""
                if text:find(L["PLAYER_GEM"], 1, true) or text:find(L["PLAYER_ENCHANT"], 1, true) then
                    small = small + 1
                    if r:GetHeight() >= 40 then big = big + 1 end
                end
            end
        end
        check("Zubehoer steht in kleinen Zeilen", small > 0 and big == 0, big .. " zu gross")
        -- Und was auf dem Stueck sitzt, steht auch im Link - damit das
        -- Tooltip es zeigt und nicht nur unsere Zeile es behauptet.
        local withEnchant = 0
        for _, r in ipairs(wow.rows()) do
            if r:IsShown() and type(r.link) == "string" then
                local _, ench = r.link:match("^item:(%d+):(%d+)")
                if ench and ench ~= "0" then withEnchant = withEnchant + 1 end
            end
        end
        check("der Link traegt die Verzauberung", withEnchant > 0, withEnchant .. " Stuecke")
        -- Und er hat die richtige Form. Ein Feld zu wenig, und die Zahl
        -- der Bonus-IDs steht im Feld daneben: der Client verwirft den
        -- Link, das Tooltip bleibt leer - genau so war es.
        local schief = 0
        for _, r in ipairs(wow.rows()) do
            if r:IsShown() and type(r.link) == "string" and r.link:find("^item:") then
                local parts = {}
                for piece in (r.link .. ":"):gmatch("([^:]*):") do parts[#parts + 1] = piece end
                -- 1 item, 2 ID, 3 Verzauberung, 4-7 Steine, 8-13 Rest,
                -- 14 Zahl der Bonus-IDs, danach die Bonus-IDs selbst.
                local count = tonumber(parts[14]) or 0
                if #parts < 14 then schief = schief + 1
                elseif count > 0 and #parts ~= 14 + count then schief = schief + 1 end
            end
        end
        check("jeder Link hat die richtige Form", schief == 0, schief .. " schief")
        local button
        for _, f in ipairs(wow.frames) do
            if rawget(f, "label") and f.label:GetText() == L["PLAYER_BACK"] then button = f end
        end
        check("Zurueck-Knopf sichtbar", button ~= nil and button:IsShown())
        -- Der Hinweis unter dem Titel endet vor dem Knopf - vorher lag
        -- "Zurueck zu Top-Spieler" auf dem Satz.
        local hint = ns.UI.Frame().hintText
        local full = ns.UI.Frame():GetWidth() - 196 - 24 * 2 - 20
        check("Hinweis weicht dem Zurueck-Knopf aus", hint ~= nil and (tonumber(hint:GetWidth()) or 0) > 0 and tonumber(hint:GetWidth()) <= full - 175,
            hint and (hint:GetWidth() .. " von " .. full) or "kein Hinweis")
        if button then
            button.__scripts.OnClick(button)
            check("Zurueck-Knopf versteckt nach dem Klick", not button:IsShown())
        end
    end
end

-- Ein Spieler gehoert zu EINER Rangliste. Wer oben die Aktivitaet oder
-- die Spec wechselt, will die Besten der neuen Wahl sehen - und nicht
-- weiter den Spieler aus der alten, der aussieht, als taete der Knopf
-- nichts. Genau das war der Fehler.
if top then
    local function backButton()
        local found
        for _, fr in ipairs(wow.frames) do
            if rawget(fr, "label") and fr.label:GetText() == L["PLAYER_BACK"] then found = fr end
        end
        return found
    end
    local function openFirst()
        ns.Profile.SetMode("mplus")
        rowsInSection("players")
        for _, row in ipairs(wow.rows()) do
            if row:IsShown() and row.onClick and row.title:GetText() == top[1].name then
                row.onClick(row, "LeftButton")
                return true
            end
        end
        return false
    end

    local other
    for _, entry in ipairs(ns.MODES) do
        if entry.key ~= "mplus" and ns.Recommend.HasMode(entry.key) then
            other = entry.key
            break
        end
    end
    if other and openFirst() then
        local open = backButton()
        check("Spieler ist offen", open ~= nil and open:IsShown())
        ns.Profile.SetMode(other)
        ns.UI.Refresh()
        local closed = backButton()
        check("Aktivitaetswechsel fuehrt zurueck in die Liste",
            closed == nil or not closed:IsShown(), other)
    end

    -- Und dasselbe fuer die Spec: der Beste seiner Spec ist nicht der
    -- Beste der naechsten.
    local mine = ns.Profile.SelectedSpec()
    if openFirst() then
        ns.Profile.Select(1, mine == 71 and 72 or 71)
        ns.UI.Refresh()
        local closed = backButton()
        check("Specwechsel fuehrt zurueck in die Liste",
            closed == nil or not closed:IsShown())
    end
    -- Und die Auswahl wieder herstellen, damit die naechsten Pruefungen
    -- dieselbe Spec sehen wie vorher.
    local mineClass = ns.Compat.ClassOfSpec(mine)
    if mineClass then ns.Profile.Select(mineClass, mine) else ns.Profile.SelectActive() end
    ns.Profile.SetMode("mplus")
end

-- ------------------------------------------------- Gegenstands-Tooltip

-- Was der Tooltip sagen soll, ohne den Tooltip selbst.
--
-- Zwei Fragen hat jemand, der ein Item unter dem Zeiger haelt: taugen
-- die Zweitwerte fuer meine Spec, und ist das ueberhaupt das Teil, das
-- die Besten tragen? Die Antworten rechnet Tooltip aus. Das Anhaengen
-- an die Zeilen braucht den laufenden Client und steht in /mc probe.
do
    ns.Profile.SetMode("mplus")
    local stats = ns.Recommend.Stats(105, "mplus", ns.Recommend.ALL)
    check("Rangfolge der Zweitwerte liegt vor",
        stats ~= nil and stats.priority ~= nil and #stats.priority >= 2,
        stats and stats.priority and table.concat(stats.priority, " > "))

    local real = ns.Compat.ItemStats
    ns.Compat.ItemStats = function()
        return { ITEM_MOD_HASTE_RATING_SHORT = 800, ITEM_MOD_MASTERY_RATING_SHORT = 500 }
    end
    local ranks = ns.Tooltip.StatRanks("|Hitem:200001|h[Item]|h")
    ns.Compat.ItemStats = real

    local want = {}
    for i, key in ipairs(stats and stats.priority or {}) do want[key] = i end
    check("nur die Werte, die das Item traegt",
        ranks ~= nil and ranks.haste ~= nil and ranks.mastery ~= nil
            and ranks.crit == nil and ranks.vers == nil,
        ranks and ("haste=" .. tostring(ranks.haste) .. " mastery=" .. tostring(ranks.mastery)
            .. " crit=" .. tostring(ranks.crit)) or "nichts")
    check("und mit der gemessenen Rangnummer",
        ranks ~= nil and ranks.haste == want.haste and ranks.mastery == want.mastery,
        ranks and (tostring(ranks.haste) .. " von " .. tostring(want.haste)) or "-")

    -- Platz in der Liste: das meistgetragene Stueck eines Platzes ist
    -- das, was andere "BiS" nennen.
    local gear = ns.Recommend.Gear(105, "mplus", ns.Recommend.ALL)
    local firstID, listLen
    for _, list in pairs(gear or {}) do
        if list[1] and list[1].id then firstID, listLen = list[1].id, #list break end
    end
    if firstID then
        local rank, pct, total = ns.Tooltip.GearRank(firstID)
        check("das meistgetragene Stueck ist Platz eins",
            rank == 1 and type(pct) == "number" and total == listLen,
            "Platz " .. tostring(rank) .. " von " .. tostring(total) .. ", " .. tostring(pct) .. " %")
    end
    check("ein Stueck ausserhalb der Liste bekommt keinen Platz",
        ns.Tooltip.GearRank(1) == nil)

    -- Und die Nummern haengen an den Zeilen, die der Tooltip zeigt.
    --
    -- Ein Handwerksstueck traegt seine Zweitwerte ueber Bonus-IDs. Der
    -- nackte Link antwortet dann mit "Zufallswert 1/2", und genau dort
    -- fehlten die Nummern - sichtbar im Abschnitt Handwerk. Gelesen
    -- wird deshalb der Tooltip selbst.
    do
        ITEM_MOD_CRIT_RATING_SHORT = "Kritischer Trefferwert"
        ITEM_MOD_HASTE_RATING_SHORT = "Tempo"
        ITEM_MOD_MASTERY_RATING_SHORT = "Meisterschaft"
        ITEM_MOD_VERSATILITY = "Vielseitigkeit"
        local shown = {
            "Plattenarmschienen des Weltenwanderers",
            "Gegenstandsstufe 331",
            "+103 Intelligenz",
            "+56 Kritischer Trefferwert",
            "+56 Meisterschaft",
            "Anlegen: Eure Zauber erhoehen euer Tempo um 5%.",
        }
        for i, text in ipairs(shown) do
            local slot = { __text = text }
            function slot:GetText() return self.__text end
            function slot:SetText(value) self.__text = value end
            _G["MCProbeTipTextLeft" .. i] = slot
        end
        local tip = { added = {} }
        function tip:GetName() return "MCProbeTip" end
        function tip:NumLines() return #shown end
        function tip:AddLine(text) self.added[#self.added + 1] = text end
        -- Der Link ist der nackte Gegenstand, wie ihn unsere Liste hat.
        local realStats = ns.Compat.ItemStats
        ns.Compat.ItemStats = function() return nil end
        ns.Tooltip.Decorate(tip, "|Hitem:244584|h[Handwerk]|h")
        ns.Compat.ItemStats = realStats
        local crit = _G["MCProbeTipTextLeft4"]:GetText()
        local mast = _G["MCProbeTipTextLeft5"]:GetText()
        local satz = _G["MCProbeTipTextLeft6"]:GetText()
        check("die Wertzeile bekommt ihre Nummer",
            crit:find("#%d") ~= nil and mast:find("#%d") ~= nil, crit .. " / " .. mast)
        check("der Satz mit dem Wertnamen bekommt keine",
            satz:find("#%d") == nil, satz)
        check("und die Zeile mit dem Hauptwert auch nicht",
            _G["MCProbeTipTextLeft3"]:GetText():find("#%d") == nil)
    end

    -- Und abgeschaltet haengt es nichts an.
    ns.Profile.SetTooltipOn(false)
    check("abgeschaltet bleibt der Tooltip unberuehrt",
        ns.Profile.TooltipOn() == false)
    ns.Profile.SetTooltipOn(true)
end






-- Ein Klick auf "+N weitere" darf den Fundort-Filter nicht wegwerfen.
--
-- Gefaltet wird NACH dem Filtern, aufgeklappt wird per Merker - beides
-- soll sich nicht in die Quere kommen. Geprueft wird mit jeder Wahl, die
-- es gibt: ganze Gruppe, einzelne Instanz, einzelner Boss. Bei welcher
-- ueberhaupt etwas zu falten ist, entscheiden die Daten.
do
    ns.Profile.SetMode("mplus")
    ns.Profile.SetCategory("gearSource", nil)
    rowsInSection("gear")
    local frame = _G.MetaCodexFrame
    local candidates = {}
    for _, src in ipairs(frame.__sources or {}) do
        candidates[#candidates + 1] = "group:" .. (src.group or "other")
        candidates[#candidates + 1] = src.key
        for _, boss in ipairs(src.bosses or {}) do candidates[#candidates + 1] = boss.key end
    end

    local geprueft, verloren, wuchs = 0, 0, 0
    for _, pick in ipairs(candidates) do
        ns.Profile.SetCategory("gearSource", pick)
        local before = rowsInSection("gear")
        local head
        for _, row in ipairs(wow.rows()) do
            local t = row:IsShown() and row.title and row.title:GetText() or nil
            if t and row.onClick and t:find(ns.L["GEAR_LESS"], 1, true) == nil
                and t:find("|cff", 1, true) and not head then head = row end
        end
        if head then
            geprueft = geprueft + 1
            head.onClick(head)
            local after = 0
            for _, row in ipairs(wow.rows()) do if row:IsShown() then after = after + 1 end end
            if ns.Profile.Category("gearSource") ~= pick then verloren = verloren + 1 end
            if after > before then wuchs = wuchs + 1 end
            -- wieder zuklappen, damit die naechste Wahl sauber anfaengt
            head = nil
            for _, row in ipairs(wow.rows()) do
                local t = row:IsShown() and row.title and row.title:GetText() or nil
                if t and row.onClick and t:find(ns.L["GEAR_LESS"], 1, true) and not head then
                    head = row
                end
            end
            if head then head.onClick(head) end
        end
    end
    ns.Profile.SetCategory("gearSource", nil)
    check("es gab ueberhaupt etwas zum Aufklappen", geprueft > 0,
        geprueft .. " von " .. #candidates .. " Wahlen")
    check("der Filter ueberlebt jedes Aufklappen", verloren == 0,
        verloren .. " verloren")
    check("und das Aufklappen zeigt wirklich mehr", wuchs > 0,
        wuchs .. " von " .. geprueft)
end

-- Der Platz-Filter darf sich nicht selbst wegraeumen.
--
-- Zwei Waehler lagen auf demselben Schluessel: der Platz speicherte unter
-- "gear", und die allgemeine Kategorie-Pruefung sah genau dort nach,
-- fand in einem Abschnitt ohne Kategorien nichts und loeschte die Wahl.
-- Sichtbar wurde das erst beim naechsten Auffrischen: der Knopf sagte
-- wieder "Alle Plaetze", und die gefaltete Zeile erschien, obwohl ein
-- Platz gewaehlt war.
do
    ns.Profile.SetMode("mplus")
    ns.Profile.SetCategory("gearSource", nil)
    ns.Profile.SetGearSlot(nil)
    local alle = rowsInSection("gear")
    local frame = _G.MetaCodexFrame
    ns.Profile.SetGearSlot("Trinkets")
    local erst = rowsInSection("gear")
    check("ein Platz laesst weniger uebrig", erst > 0 and erst < alle,
        erst .. " von " .. alle)
    check("und der Knopf nennt ihn",
        frame.slotButton.label:GetText() == ns.L["GEARSLOT_Trinkets"],
        tostring(frame.slotButton.label:GetText()))
    -- Und jetzt noch einmal auffrischen, ohne irgendetwas zu aendern.
    local nochmal = rowsInSection("gear")
    check("der Platz ueberlebt das naechste Auffrischen",
        ns.Profile.GearSlot() == "Trinkets",
        tostring(ns.Profile.GearSlot()))
    check("und die Liste bleibt gefiltert", nochmal == erst,
        erst .. " -> " .. nochmal)
    -- Mit gewaehltem Platz wird nicht gefaltet: wer "Schmuck" sagt, hat
    -- schon gesagt, dass er den Schmuck sehen will.
    local gefaltet = 0
    for _, row in ipairs(wow.rows()) do
        local t = row:IsShown() and row.title and row.title:GetText() or nil
        if t and row.onClick and t:find("|cff", 1, true) then gefaltet = gefaltet + 1 end
    end
    check("und nichts ist zusammengeklappt", gefaltet == 0, gefaltet .. " Zeilen")
    ns.Profile.SetGearSlot(nil)
end

-- Ein Name aus Korea braucht eine Schrift, die Korea kann.
--
-- In der Rangliste stehen koreanische Namen neben europaeischen. Die
-- Standardschrift des Clients zeichnet die einen als leere Kaestchen -
-- die Zeichen sind richtig angekommen, die Schrift kann sie nur nicht.
do
    local S = ns.Style
    -- "Hangul" auf Koreanisch, als Bytes geschrieben, damit diese Datei
    -- reines ASCII bleibt.
    local koreanisch = "\237\149\156\234\184\128"
    check("Latein braucht keine eigene Schrift", S:ScriptOf("Nettspend") == nil)
    check("Koreanisch schon", S:ScriptOf(koreanisch) == "korean",
        tostring(S:ScriptOf(koreanisch)))
    check("und ein gemischter Text auch",
        S:ScriptOf("Viness " .. koreanisch) == "korean")
    -- Chinesisch ist eine EIGENE Frage: die koreanische Schrift zeichnet
    -- Hangul, aber keine chinesischen Zeichen. In der Rangliste standen
    -- die Namen von TW und CN deshalb weiter als Kaestchen da.
    local chinesisch = "\230\136\145\231\154\132"
    check("Chinesisch ist ein anderes Schriftsystem",
        S:ScriptOf(chinesisch) == "chinese", tostring(S:ScriptOf(chinesisch)))

    local fs2 = S:Text(ns.UI.Frame(), "body", "textPrimary")
    S:SetText(fs2, koreanisch)
    local pfad = fs2:GetFont()
    check("der Text bekommt die Schrift, die ihn zeichnen kann",
        tostring(pfad):find("2002", 1, true) ~= nil, tostring(pfad))
    -- Und die Zeile wird wiederverwendet: die naechste ist lateinisch.
    S:SetText(fs2, "Felphis")
    local zurueck = fs2:GetFont()
    check("und gibt sie wieder her",
        tostring(zurueck):find("2002", 1, true) == nil, tostring(zurueck))
    check("der Text steht trotzdem da", fs2:GetText() == "Felphis")

    -- Und sie bleibt an keiner Zeile haengen, die weiterbenutzt wird.
    --
    -- Genau daran ist es gescheitert: wer das Profil eines koreanischen
    -- Spielers ansah und zurueckging, bekam die Ueberschrift in
    -- koreanischer Schrift - "Zielwerte" stand da zu breit und mit
    -- seltsamen Abstaenden, wie "Zie l werte".
    local titel = ns.UI.Frame().sectionTitle
    S:SetText(titel, koreanisch)
    check("die Ueberschrift nimmt die fremde Schrift an",
        tostring(titel:GetFont()):find("2002", 1, true) ~= nil,
        tostring(titel:GetFont()))
    rowsInSection("stats")
    check("und gibt sie beim naechsten Abschnitt wieder her",
        tostring(titel:GetFont()):find("2002", 1, true) == nil,
        tostring(titel:GetFont()))
    check("die Ueberschrift heisst wieder, wie der Abschnitt heisst",
        titel:GetText() == ns.L["SECTION_stats"], tostring(titel:GetText()))

    -- Dasselbe fuer eine Zeile: sie traegt erst einen koreanischen
    -- Namen und danach einen Gegenstand.
    rowsInSection("gear")
    local zeile
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and not zeile then zeile = row end
    end
    if zeile then
        S:SetText(zeile.title, koreanisch)
        rowsInSection("gear")
        check("und eine Zeile gibt sie ebenso wieder her",
            tostring(zeile.title:GetFont()):find("2002", 1, true) == nil,
            tostring(zeile.title:GetFont()))
    end
end

-- Im Reiter "Tier-Set" steht nur das Set DIESER Saison.
--
-- "Set-Teil" heisst nur: gehoert irgendeinem Set an. Unter den Sets
-- dieser Erweiterung stehen auch das Klassenset der vorigen Saison, die
-- PvP-Ruestungen und kleine Schmucksets aus den Dungeons - und so
-- standen sie alle im Reiter, ein Ring mittendrin.
do
    local gezeigt, fremd, ringe = 0, 0, 0
    for _, aktivitaet in ipairs({ "raid", "raid-normal", "mplus", "3v3" }) do
        ns.Profile.SetMode(aktivitaet)
        rowsInSection("tier")
        for _, row in ipairs(wow.rows()) do
            local text = row:IsShown() and row.title and row.title:GetText() or nil
            if text and text ~= "" then gezeigt = gezeigt + 1 end
        end
        -- Und an den Zeilen selbst: jede traegt ihre Gegenstands-ID.
        for _, row in ipairs(wow.rows()) do
            local id = row:IsShown() and rawget(row, "itemID") or nil
            if type(id) == "number" then
                gezeigt = gezeigt + 1
                if not ns.Catalog.IsCurrentTier(id) then fremd = fremd + 1 end
            end
        end
    end
    check("der Reiter zeigt Zeilen", gezeigt > 0, gezeigt .. " Zeilen")
    check("und keine davon ist aus einem fremden Set", fremd == 0,
        fremd .. " fremde")

    -- Die engere Frage beantwortet der Katalog, und sie ist WIRKLICH
    -- enger: es gibt Set-Teile, die nicht zum laufenden Tier gehoeren.
    local set, tier = 0, 0
    local gear = ns.Recommend.Gear(ns.Profile.SelectedSpec(), "raid", ns.Recommend.ALL)
    for _, liste in pairs(gear or {}) do
        for _, item in ipairs(liste) do
            local kind = item.kind or ns.Catalog.ItemKind(item.id)
            if kind == "set" then
                set = set + 1
                if ns.Catalog.IsCurrentTier(item.id) then tier = tier + 1 end
            end
        end
    end
    if set > 0 then
        check("das laufende Tier ist ein TEIL der Set-Teile",
            tier > 0 and tier < set, tier .. " von " .. set)
    end
    ns.Profile.SetMode("mplus")
end

-- Die Handwerksstufe am Symbol, wie im Beutel.
--
-- Drei Sorten Heiltrank stehen mit demselben Namen untereinander; ohne
-- das Zeichen unterscheidet sie nur der Prozentwert.
do
    -- Der Client kennt die Stufen: was er sagt, gilt.
    C_TradeSkillUI = { GetItemCraftedQualityByItemInfo = function(id)
        return id == 4242 and 3 or 0
    end }
    C_Texture = { GetAtlasInfo = function(name)
        return tostring(name):find("Tier", 1, true) and { name = name } or nil
    end }

    check("der Client sagt die Stufe", ns.Compat.CraftQuality(4242) == 3,
        tostring(ns.Compat.CraftQuality(4242)))

    -- Der Katalog fuehrt Stufe UND Zeichen so, wie das Spiel sie fuehrt.
    -- Geraten wurde vorher: gezaehlt, wie viele Stufen derselben Ware
    -- darunter liegen - und die Gegenstands-IDs stehen nicht in der
    -- Reihenfolge der Stufen. In dieser Erweiterung hat eine Ware
    -- ausserdem zwei Stufen, nicht drei, und ihre Zeichen heissen anders.
    local tier1, icon1 = ns.Catalog.Quality(271883)
    local tier2, icon2 = ns.Catalog.Quality(271884)
    check("der Katalog kennt die Stufen derselben Ware",
        tier1 == 1 and tier2 == 2, tostring(tier1) .. " / " .. tostring(tier2))
    check("und die Zeichen dieser Erweiterung",
        type(icon2) == "string" and icon2:find("12-Tier2", 1, true) ~= nil,
        tostring(icon2))
    -- Und zwar die Variante, die der Beutel auf das Symbol zeichnet.
    check("es ist das Zeichen aus dem Beutel",
        type(icon2) == "string" and icon2:find("-Inv", 1, true) ~= nil,
        tostring(icon2))
    check("die erste Stufe traegt das erste Zeichen",
        type(icon1) == "string" and icon1:find("12-Tier1", 1, true) ~= nil,
        tostring(icon1))

    -- Und die Reihenfolge der Stufen folgt der Stufe, nicht der ID.
    local unten = ns.Catalog.Tiers(271884)
    local drin = false
    for _, id in ipairs(unten or {}) do if id == 271883 then drin = true end end
    check("die niedrigere Stufe steht unter der hoeheren", drin,
        table.concat(unten or {}, ", "))
    local atlas = ns.Compat.QualityAtlas(3)
    check("und es gibt ein Zeichen dazu",
        type(atlas) == "string" and atlas:find("Tier3", 1, true) ~= nil,
        tostring(atlas))
    check("ohne Stufe kein Zeichen", ns.Compat.QualityAtlas(nil) == nil)
    check("und keine erfundene Stufe", ns.Compat.QualityAtlas(9) == nil)

    -- Schweigt der Client, zaehlt der Katalog die Stufen derselben Ware.
    C_TradeSkillUI = nil
    local mitStufen
    ns.Profile.SetMode("mplus")
    for _, eintrag in ipairs(ns.Recommend.Consumables(ns.Profile.SelectedSpec(),
        "mplus", ns.Recommend.ALL) or {}) do
        if eintrag.id and not mitStufen then
            local lower, higher = ns.Catalog.Tiers(eintrag.id)
            if #(lower or {}) + #(higher or {}) > 0 then mitStufen = eintrag.id end
        end
    end
    check("es gibt Ware mit mehreren Stufen", mitStufen ~= nil,
        tostring(mitStufen))
    if mitStufen then
        check("ohne Client zaehlt der Katalog die Stufen",
            type(ns.Compat.CraftQuality(mitStufen)) == "number",
            tostring(ns.Compat.CraftQuality(mitStufen)))
    end

    -- Und im Fenster steht es wirklich an den Zeilen.
    C_TradeSkillUI = { GetItemCraftedQualityByItemInfo = function() return 2 end }
    rowsInSection("consumables")
    local mitZeichen = 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.quality and row.quality:IsShown() then
            mitZeichen = mitZeichen + 1
        end
    end
    check("die Zeilen tragen das Zeichen", mitZeichen > 0, mitZeichen .. " Zeilen")

    -- Eine wiederverwendete Zeile traegt es nicht weiter: das Zeichen
    -- des Vorgaengers auf einem anderen Gegenstand waere eine Luege.
    C_TradeSkillUI = { GetItemCraftedQualityByItemInfo = function() return 0 end }
    rowsInSection("gear")
    local uebrig = 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.quality and row.quality:IsShown() then
            uebrig = uebrig + 1
        end
    end
    check("und gibt es wieder her", uebrig == 0, uebrig .. " Zeilen")
    C_TradeSkillUI = nil
    C_Texture = nil
end

-- Die Verzierungen tragen dasselbe Zeichen wie die Verbrauchsgueter.
--
-- Das Reagenz gibt es je Handwerksstufe einmal - gleicher Name, andere
-- ID. Ohne das Zeichen am Symbol sieht man der Zeile nicht an, welche
-- der beiden an ihr haengt, und im Tooltip stand die Stufe schon immer.
--
-- Geraten wird dabei nichts: gezeigt wird die Stufe DES REAGENZ, das
-- verlinkt ist. Mit welcher Stufe die gemessenen Spieler gearbeitet
-- haben, steht in keiner Bonus-ID.
do
    C_Texture = { GetAtlasInfo = function(name) return { name = name } end }
    rowsInSection("embellish")
    local mitStufe, mitZeichen = 0, 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.itemID and ns.Catalog.Quality(row.itemID) then
            mitStufe = mitStufe + 1
            if row.quality and row.quality:IsShown() then
                mitZeichen = mitZeichen + 1
            end
        end
    end
    check("die Verzierungen tragen das Zeichen am Symbol",
        mitStufe > 0 and mitZeichen == mitStufe,
        mitZeichen .. " von " .. mitStufe .. " mit Handwerksstufe")
    C_Texture = nil
    ns.Profile.SetMode("mplus")
end

-- "Bereits drauf" heisst: DER empfohlene Stein sitzt drin.
--
-- Gezaehlt wurden frueher nur die leeren Sockel. Wer einen fremden
-- Stein trug, bekam "bereits drauf" - und die Zeile log ueber genau die
-- Ausruestung, die sie beschreiben sollte.
do
    local dreiSockel = {
        totalSockets = 3, emptySockets = 1,
        gems = { [222] = 1, [111] = 1 },
    }
    local fehlt, gesamt, anderer = ns.Gear.GemsMissing(dreiSockel, 222, {}, nil)
    check("ein leerer und ein fremder Sockel fehlen", fehlt == 2 and gesamt == 3,
        fehlt .. " von " .. gesamt)
    check("und der fremde Stein wird benannt", anderer == 111, tostring(anderer))

    -- Eine andere Qualitaetsstufe ist derselbe Stein.
    local fehlt2, _, anderer2 = ns.Gear.GemsMissing(dreiSockel, 222, { 111 }, nil)
    check("eine andere Stufe desselben Steins zaehlt als drin", fehlt2 == 1,
        tostring(fehlt2))
    check("dann gibt es auch keinen fremden", anderer2 == nil, tostring(anderer2))

    -- Der Stein des besonderen Sockels gehoert nicht in diese Zeile: er
    -- hat seine eigene, und zweimal gezaehlt waere er zweimal zu kaufen.
    local istMeta = function(id) return id == 111 end
    local fehlt3 = ns.Gear.GemsMissing(dreiSockel, 222, {}, istMeta)
    check("der besondere Stein zaehlt hier nicht mit", fehlt3 == 1,
        tostring(fehlt3))

    -- Ohne Empfehlung bleibt es bei der alten Frage: wie viele sind leer.
    local fehlt4 = ns.Gear.GemsMissing(dreiSockel, nil, nil, nil)
    check("ohne Empfehlung zaehlen die leeren", fehlt4 == 1, tostring(fehlt4))

    -- Leer und anders belegt kommen getrennt heraus.
    --
    -- Zusammengezaehlt heissen beide "fehlt" - richtig fuer den Einkauf,
    -- falsch fuer den Satz daneben. Der setzte die Summe in "davon %d
    -- leer" ein und nannte damit einen Sockel leer, in dem ein Stein
    -- sitzt. Wer zwei Sockel bewusst anders besetzt hat, las von zwei
    -- leeren Sockeln.
    local _, _, _, wirklichLeer = ns.Gear.GemsMissing(dreiSockel, 222, {}, nil)
    check("die wirklich leeren werden einzeln gemeldet", wirklichLeer == 1,
        tostring(wirklichLeer))
    check("und die Fehlmenge bleibt die Summe", fehlt == wirklichLeer + 1,
        fehlt .. " = " .. wirklichLeer .. " + 1")
end

-- Die Zielwerte sagen, was sie sind - und wie einig die Gemessenen sind.
--
-- "Die hat von den Top-Spielern keiner" stimmt, und deshalb steht es
-- jetzt dabei: vier Mediane nebeneinander sind kein Build eines
-- Spielers. Jede Zahl fuer sich ist die Mitte der Gemessenen, und die
-- Spanne dahinter sagt, wie weit sie auseinanderliegen.
do
    ns.Profile.SetMode("mplus")
    rowsInSection("stats")
    local hinweis = ns.UI.Frame().hintText:GetText() or ""
    check("ueber den Zielwerten steht, was sie sind", hinweis ~= "", hinweis)
    check("und dass es kein Build eines Spielers ist",
        hinweis:find(ns.L["STAT_HINT"]:sub(1, 20), 1, true) ~= nil
            or hinweis:find("%d") ~= nil, hinweis)

    -- Die Spanne steht an der Zeile, wenn sie gemessen wurde.
    local echt = ns.Recommend.Stats
    ns.Recommend.Stats = function()
        return {
            players = 40,
            priority = { "crit", "haste" },
            values = {
                crit = { pct = 30, rating = 1000, low = 900, high = 1100 },
                haste = { pct = 25, rating = 800 },
            },
        }, "warcraftlogs"
    end
    rowsInSection("stats")
    -- Die Spanne steht NICHT mehr an der Zeile.
    --
    -- Sie stand dort einmal, und zwar links unter dem Namen. Dort passte
    -- sie nicht: zweihundert Pixel tragen keine sechzig Zeichen, und die
    -- Bahn liegt senkrecht genau darueber - im Fenster lief "die
    -- mittlere Haelfte liegt bei 1133 bis 1260" quer durch den Balken.
    -- Dass der Zielwert ein Median mit Streuung ist, steht im Kopf der
    -- Seite; an der Zeile zaehlt der eigene Stand.
    local mitSpanne, zuBreit = 0, 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.detail then
            local text = row.detail:GetText() or ""
            if text:find("900", 1, true) and text:find("1100", 1, true) then
                mitSpanne = mitSpanne + 1
            end
            -- Und die Spalte bleibt schmal genug, um die Bahn nicht zu
            -- beruehren. Ohne Breite laeuft ein FontString so weit, wie
            -- sein Text lang ist - genau das war der Fehler.
            local breite = row.detail:GetWidth()
            if type(breite) == "number" and breite > 0 and breite >= 250 then
                zuBreit = zuBreit + 1
            end
        end
    end
    check("die Spanne steht nicht mehr an der Zeile", mitSpanne == 0,
        mitSpanne .. " Zeilen")
    check("und die linke Spalte reicht nicht in die Bahn", zuBreit == 0,
        zuBreit .. " Zeilen")
    local mitZahl = ns.UI.Frame().hintText:GetText() or ""
    check("der Hinweis nennt die Zahl der Gemessenen",
        mitZahl:find("40", 1, true) ~= nil, mitZahl)
    ns.Recommend.Stats = echt
    rowsInSection("stats")
end

-- "Aus meinen Taschen waehlen" fragt die TASCHEN, nicht den Katalog.
--
-- Der Katalog fuehrt nur die laufende Erweiterung. Eine Rune von
-- vorletztem Jahr steht nicht darin - und fehlte deshalb in der
-- Auswahl, obwohl sie genau dort im Beutel lag.
do
    local alteRune = 224572
    local echtesContainer = C_Container
    C_Container = {
        GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
        GetContainerItemID = function(bag, slot)
            if bag == 0 and slot == 1 then return alteRune end
            if bag == 0 and slot == 2 then return 200001 end
            return nil
        end,
    }
    local echtesInstant = C_Item.GetItemInfoInstant
    C_Item.GetItemInfoInstant = function(id)
        -- SO antwortet der Client, mit allen sieben Werten:
        --   itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID
        -- Die Attrappe MUSS dieselbe Form haben. Sie hatte einen Wert
        -- zu wenig - und bestaetigte damit genau den Zaehlfehler im
        -- Addon, statt ihn zu finden.
        --
        -- Klasse 0 ist "Verbrauchbar", Unterklasse 8 die Sammelklasse
        -- fuer Runen, Oele und Schleifsteine.
        if id == alteRune then return id, "Verbrauchbar", "Sonstiges", "", 1, 0, 8 end
        -- Und ein Ruestungsteil, damit klar ist, dass nicht alles
        -- aus dem Beutel in der Liste landet.
        if id == 200001 then return id, "Ruestung", "Stoff", "INVTYPE_HEAD", 1, 4, 1 end
        return echtesInstant(id)
    end

    check("der Client ordnet die alte Rune ein",
        ns.Compat.ConsumableKind(alteRune) == "other",
        tostring(ns.Compat.ConsumableKind(alteRune)))
    check("und ein Ruestungsteil ist kein Verbrauchsgut",
        ns.Compat.ConsumableKind(200001) == nil,
        tostring(ns.Compat.ConsumableKind(200001)))
    check("die Taschen werden gelesen", #ns.Compat.BagItems() == 2,
        #ns.Compat.BagItems() .. " Gegenstaende")

    local ausDemBeutel = ns.Catalog.OwnedOfKind("other")
    local drin, ruestung = false, false
    for _, eintrag in ipairs(ausDemBeutel) do
        if eintrag.id == alteRune then drin = true end
        if eintrag.id == 200001 then ruestung = true end
    end
    check("die alte Rune steht zur Wahl", drin, #ausDemBeutel .. " Eintraege")
    check("das Ruestungsteil nicht", not ruestung)

    C_Container = echtesContainer
    C_Item.GetItemInfoInstant = echtesInstant
end

-- Zweimal dieselbe Verzierung ist eine eigene Wahl - und oft die
-- haeufigste. Gezaehlt wurde sie als EINE: eine Menge kennt kein
-- Zweimal. Im Fenster stand dann "eine Verzierung" mit 93 %, wo die
-- meisten in Wahrheit zwei gleiche tragen.
do
    local echt = ns.Recommend.Embellish
    ns.Recommend.Embellish = function()
        return {
            { ids = { 240166, 240166 }, pct = 50 },
            { ids = { 240166, 273059 }, pct = 36 },
            { ids = { 240166 }, pct = 4 },
        }, "raider.io"
    end
    ns.Profile.SetMode("mplus")
    rowsInSection("embellish")
    local doppelt, beide, einzeln
    for _, row in ipairs(wow.rows()) do
        local ids = row:IsShown() and rawget(row, "ids") or nil
        if type(ids) == "table" then
            if #ids == 2 and ids[1] == ids[2] then doppelt = row
            elseif #ids == 2 then beide = row
            elseif #ids == 1 then einzeln = row end
        end
    end
    check("die doppelte Verzierung steht als eigene Zeile", doppelt ~= nil)
    if doppelt then
        local name = ns.Compat.ItemInfo(240166) or "#240166"
        check("sie wird einmal genannt, mit x2",
            doppelt.title:GetText() == ns.L["EMBELLISH_TWICE"]:format(name),
            tostring(doppelt.title:GetText()))
        check("und traegt beide IDs fuer die Tooltips",
            #rawget(doppelt, "ids") == 2)
    end
    check("zwei verschiedene stehen weiter nebeneinander", beide ~= nil)
    check("und eine einzelne bleibt eine einzelne", einzeln ~= nil)
    ns.Recommend.Embellish = echt
end

-- Hervorgehoben wird der erste Platz, nicht die 50 %.
--
-- Diese Schwelle kannten die Daten nicht. Ein Stueck mit 48 % ist
-- genauso das meistgetragene wie eines mit 51 % - und bei einem breiten
-- Feld blieb die ganze Liste grau, obwohl es sehr wohl einen
-- Spitzenreiter gab. Genau so sah es im Bild aus: 48, 36, 9, 4, 3, und
-- keine einzige Zahl hob sich ab.
do
    local echt = ns.Recommend.Embellish
    local function hervorgehoben()
        local wie_viele, erste = 0, nil
        for _, row in ipairs(wow.rows()) do
            if row:IsShown() and type(rawget(row, "ids")) == "table"
                and rawget(row.share, "__token") == "accent" then
                wie_viele = wie_viele + 1
                erste = erste or row.share:GetText()
            end
        end
        return wie_viele, erste
    end

    ns.Recommend.Embellish = function()
        return {
            { ids = { 240166 }, pct = 48 },
            { ids = { 273059 }, pct = 36 },
            { ids = { 251490 }, pct = 16 },
        }, "raider.io"
    end
    ns.Profile.SetMode("mplus")
    rowsInSection("embellish")
    local wie_viele, erste = hervorgehoben()
    check("der erste Platz steht vorn, auch unter 50 %",
        wie_viele == 1 and erste == "48%",
        wie_viele .. " hervorgehoben, " .. tostring(erste))

    -- Gleichstand: welche von zwei gleichen Zahlen die erste ist, sagt
    -- die Messung nicht - also stehen beide vorn.
    ns.Recommend.Embellish = function()
        return {
            { ids = { 240166 }, pct = 40 },
            { ids = { 273059 }, pct = 40 },
            { ids = { 251490 }, pct = 20 },
        }, "raider.io"
    end
    rowsInSection("embellish")
    local gleich = hervorgehoben()
    check("bei Gleichstand stehen beide vorn", gleich == 2,
        gleich .. " hervorgehoben")

    ns.Recommend.Embellish = echt
    rowsInSection("embellish")
end

-- Zwei Ringe, zwei Schmuckstuecke - und das steht auch da.
--
-- Ueber der Liste stand nur "RINGE". Wer die Prozente las, konnte meinen,
-- es gehe um einen Ring. Es sind zwei Plaetze und damit zwei
-- Entscheidungen. Die Waffenhaende stehen ohnehin als zwei eigene
-- Ueberschriften da, also brauchen sie den Zusatz nicht.
do
    ns.Profile.SetLanguage("de")
    ns.Profile.SetMode("mplus")
    rowsInSection("gear")
    local mitZahl, ohneZahl = {}, {}
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and rawget(row, "__header") then
            local text = row.title:GetText() or ""
            if text:find("2 PL", 1, true) then
                mitZahl[#mitZahl + 1] = text
            else
                ohneZahl[#ohneZahl + 1] = text
            end
        end
    end
    check("die doppelten Plaetze sagen, dass es zwei sind", #mitZahl == 2,
        table.concat(mitZahl, " | "))
    check("und die einfachen sagen nichts dergleichen", #ohneZahl > 0,
        #ohneZahl .. " Ueberschriften")

    -- Und die Umlaute stehen gross da.
    --
    -- string.upper geht byteweise und kennt nur a-z: "Fuesse" mit Umlaut
    -- blieb "FueSSE" mit kleinem Umlaut mitten in Grossbuchstaben.
    local klein = 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and rawget(row, "__header") then
            local text = row.title:GetText() or ""
            -- Die zweiten Bytes der kleinen Umlaute und des scharfen s.
            if text:find("\195[\164\182\188\159]") then klein = klein + 1 end
        end
    end
    check("keine kleinen Umlaute in den Ueberschriften", klein == 0,
        klein .. " Ueberschriften")

    -- Und es stehen auch zwei da.
    --
    -- Gefaltet wurde auf EINE Zeile je Platz. Bei Ringen und Schmuck
    -- versteckte das den zweiten Ring hinter "+4 weitere", als waere er
    -- ein Ersatz - er ist aber das zweite Stueck, das man gleichzeitig
    -- traegt.
    local function zeilenMit(anfang)
        local n = 0
        for _, row in ipairs(wow.rows()) do
            if row:IsShown() and not rawget(row, "__header") then
                local text = row.detail and row.detail:GetText() or ""
                if text:sub(1, #anfang) == anfang then n = n + 1 end
            end
        end
        return n
    end
    check("bei den Ringen stehen zwei Zeilen", zeilenMit(ns.L["GEARSLOT_Rings"]) == 2,
        zeilenMit(ns.L["GEARSLOT_Rings"]) .. " Zeilen")
    check("beim Schmuck auch", zeilenMit(ns.L["GEARSLOT_Trinkets"]) == 2,
        zeilenMit(ns.L["GEARSLOT_Trinkets"]) .. " Zeilen")
    check("und bei den Beinen nur eine", zeilenMit(ns.L["GEARSLOT_Legs"]) == 1,
        zeilenMit(ns.L["GEARSLOT_Legs"]) .. " Zeilen")
    ns.Profile.SetLanguage("auto")
end

-- Ignorieren heisst: nicht mehr ansprechen - nicht "nicht mehr messen".
--
-- Wer seine Sockel bewusst auf Tempo und Vielseitigkeit stellt, hat
-- nichts vergessen. Ein Addon, das ihn vor jedem Pull daran erinnert,
-- nennt eine Entscheidung einen Fehler. In den Reitern steht weiter, was
-- die Gemessenen tragen; nur zur Sprache kommt es nicht mehr.
do
    ns.Profile.SetLanguage("de")
    ns.Profile.SetMode("mplus")
    local vorher = ns.Remind.Check("mplus")
    local opfer = vorher[1] and vorher[1].id
    check("es gibt ueberhaupt etwas zu ignorieren", opfer ~= nil, tostring(opfer))
    if opfer then
        ns.Profile.SetIgnored(opfer, true)

        local nachher = ns.Remind.Check("mplus")
        local drin = false
        for _, row in ipairs(nachher) do if row.id == opfer then drin = true end end
        check("die Erinnerung nennt es nicht mehr", not drin,
            #nachher .. " Posten statt " .. #vorher)

        -- Und die Ansage auch nicht.
        local gesagt = table.concat(ns.Remind.Lines("mplus"), " | ")
        check("und die Ansage auch nicht",
            gesagt:find(tostring(opfer), 1, true) == nil, gesagt:sub(1, 80))

        -- Gemessen bleibt gemessen.
        local gemessen = false
        for _, row in ipairs(ns.Remind.Status("mplus")) do
            if row.id == opfer then gemessen = true end
        end
        for _, row in ipairs(ns.List.Build(ns.Gear.Scan())) do
            if row.id == opfer then gemessen = true end
        end
        check("die Messung steht weiter da", gemessen)

        -- Und es steht im eigenen Abschnitt, zum Zurueckholen. Eine
        -- Einstellung, die man nicht mehr sieht, ist eine Falle.
        rowsInSection("remind")
        local sichtbar = false
        for _, row in ipairs(wow.rows()) do
            local text = row:IsShown() and row.detail and row.detail:GetText() or ""
            if text:find(ns.L["IGNORE_HINT"], 1, true) then sichtbar = true end
        end
        check("es steht unter Ignoriert", sichtbar)

        ns.Profile.SetIgnored(opfer, false)
        local zurueck = false
        for _, row in ipairs(ns.Remind.Check("mplus")) do
            if row.id == opfer then zurueck = true end
        end
        check("und laesst sich zurueckholen", zurueck)
    end
    ns.Profile.SetLanguage("auto")
end

-- Eine Liste ist keine Wahl: unter "Sonstiges" hat jeder seine Menge.
--
-- Die Zielmenge hing an der ART. Wer an den Trommeln "2" einstellte,
-- stellte damit die Verstaerkungsrune auf 2 - und umgekehrt. Und weil
-- nur das Haeufigste je Art ein Posten war, standen die Trommeln als
-- "Alternative" da, ohne Menge und ohne Nachkauf, obwohl man sie NEBEN
-- der Rune traegt und nicht statt ihrer.
do
    ns.Profile.SetMode("mplus")
    check("Sonstiges ist eine Liste", ns.Profile.KindIsList("other") == true)
    check("Flaeschchen sind eine Wahl", ns.Profile.KindIsList("flask") == false)

    -- Zwei Gegenstaende derselben Art, zwei verschiedene Mengen.
    local a, b = 244639, 259085
    ns.Profile.SetConsumableTarget("other", 2, a)
    ns.Profile.SetConsumableTarget("other", 7, b)
    check("jeder Gegenstand behaelt seine eigene Menge",
        ns.Profile.ItemTarget(a) == 2 and ns.Profile.ItemTarget(b) == 7,
        tostring(ns.Profile.ItemTarget(a)) .. " / " .. tostring(ns.Profile.ItemTarget(b)))
    check("und die Art selbst bleibt unberuehrt",
        ns.Profile.ConsumableTarget("other") ~= 2 or ns.Profile.ConsumableTarget("other") ~= 7)

    -- Bei einer Wahl bleibt es bei der Art: drei Flaeschchen sind ein
    -- Einkauf, nicht drei.
    ns.Profile.SetConsumableTarget("flask", 3, 999999)
    check("bei einer Wahl zaehlt weiter die Art",
        ns.Profile.ConsumableTarget("flask") == 3 and ns.Profile.ItemTarget(999999) == nil,
        tostring(ns.Profile.ConsumableTarget("flask")))

    -- Und die Erinnerung prueft die zweite Menge wirklich.
    local gefunden = {}
    for _, row in ipairs(ns.Remind.Status("mplus")) do
        if row.id == a or row.id == b then gefunden[row.id] = row.need end
    end
    check("die Erinnerung kennt beide Mengen",
        gefunden[a] == 2 and gefunden[b] == 7,
        tostring(gefunden[a]) .. " / " .. tostring(gefunden[b]))

    -- Und ohne eigene Menge steht nur der oberste auf der Liste.
    --
    -- Das ist die Regel: vorgeschlagen wird, was die Gemessenen meist
    -- nehmen. Alles andere kommt erst dazu, wenn jemand es sagt.
    ns.Profile.SetConsumableTarget("other", 0, a)
    ns.Profile.SetConsumableTarget("other", 0, b)
    local nurEiner = 0
    for _, row in ipairs(ns.Remind.Status("mplus")) do
        if row.kind == "other" then nurEiner = nurEiner + 1 end
    end
    check("ohne eigene Menge steht nur einer auf der Liste", nurEiner <= 1,
        nurEiner .. " Posten")

    ns.Profile.SetConsumableTarget("other", 0, a)
    ns.Profile.SetConsumableTarget("other", 0, b)
end

-- Wer seinen Waffenbuff selbst auflegt, wird nicht nach Oel gefragt.
--
-- Beim Schamanen stand "Thalassisches Phoenixoel - 0 von 5 - leer", und
-- die Einkaufsliste wollte fuenf Oele, die er nie benutzen kann:
-- Flammenzunge belegt denselben Platz. Dieselbe Sorte Frage wie die
-- Waffenverzauberung des Todesritters, und dieselbe Antwort.
do
    ns.Profile.SetMode("mplus")
    check("der Schamane bringt seinen Waffenbuff mit",
        ns.Compat.SelfWeaponBuff(262) == true)
    check("der Magier nicht", ns.Compat.SelfWeaponBuff(62) == false)

    local function oelZeilen(spec, modus)
        local n = 0
        for _, row in ipairs(ns.Remind.Status(modus or "mplus", spec)) do
            if row.kind == "oil" then n = n + 1 end
        end
        return n
    end

    -- Erst einen Modus suchen, in dem es ueberhaupt Oele gibt. Ohne das
    -- prueft die Frage nichts: 0 Zeilen sind auch dann 0, wenn die
    -- Sperre gar nicht greift - und genau so ist mir der Fehler einmal
    -- durchgerutscht.
    local modus, beiAnderen
    for _, m in ipairs({ "mplus", "raid", "mplus-keys" }) do
        local n = oelZeilen(105, m)
        if n > 0 then modus, beiAnderen = m, n break end
    end
    check("es gibt einen Modus mit Oelen", modus ~= nil,
        tostring(modus) .. ": " .. tostring(beiAnderen))
    if modus then
        check("beim Schamanen steht kein Oel auf der Erinnerung",
            oelZeilen(262, modus) == 0, oelZeilen(262, modus) .. " Zeilen")
    end
end

-- Eigene Posten: was in keiner Messung steht, kann man selbst dazunehmen.
--
-- Ein Reparaturhammer, eine Vantusrune, das Kabel fuer den Kampf-Res:
-- benutzt werden sie, gemessen sind sie nicht. "Nicht gemessen" heisst
-- nicht "gibt es nicht" - es heisst nur, dass niemand es beobachtet hat.
do
    -- Bewusst eine ID, die in KEINER Messung steht: genau das ist der
    -- Fall, um den es geht. Ein gemessener Gegenstand haette eine
    -- zweite Zeile im Fenster, und die Pruefung haette die erwischt.
    local eigenes = 999001
    ns.Profile.SetOwnItem(eigenes, true)
    ns.Profile.SetConsumableTarget("other", 3, eigenes)
    check("es gilt als selbst gesetzt", ns.Profile.IsOwnItem(eigenes) == true)

    local dabei
    for _, row in ipairs(ns.Remind.Status("mplus")) do
        if row.id == eigenes then dabei = row end
    end
    check("die Erinnerung nimmt es auf", dabei ~= nil and dabei.need == 3,
        dabei and tostring(dabei.need) or "fehlt")

    -- Und im Reiter steht es in einem eigenen Abschnitt, ohne Prozent.
    ns.Profile.SetLanguage("de")
    rowsInSection("remind")
    local wieHeisst = ns.Compat.ItemInfo(eigenes) or ("#" .. eigenes)
    local zeile, mitProzent = false, false
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and (row.title:GetText() or "") == wieHeisst then
            zeile = true
            if (row.share:GetText() or ""):find("%%") then mitProzent = true end
        end
    end
    check("es steht als eigene Zeile im Reiter", zeile)
    check("und ohne Prozentwert - gemessen hat das niemand", not mitProzent)

    -- Entfernen nimmt die Menge mit: kein unsichtbarer Bedarf.
    ns.Profile.SetOwnItem(eigenes, false)
    check("entfernen loescht auch die Menge",
        not ns.Profile.IsOwnItem(eigenes) and ns.Profile.ItemTarget(eigenes) == nil,
        tostring(ns.Profile.ItemTarget(eigenes)))
    ns.Profile.SetLanguage("auto")
end

-- Was die Klasse selbst auf die Waffe legt, steht unter Waffenbuffs.
--
-- Beim Schamanen ist das Flammenzunge, beim Schurken sein Gift. In den
-- Berichten steht es an derselben Stelle wie ein Oel - im Waffenteil
-- unter "temporaryEnchant" -, nur gibt es dazu nichts zu kaufen. Bisher
-- fiel es heraus, und die Spalte blieb leer, obwohl 96 % der Gemessenen
-- etwas drauf haben.
--
-- Die Zahlen kommen aus dem naechsten Sammellauf; geprueft wird hier der
-- Weg vom gemessenen Wert bis in die Zeile.
do
    check("der Katalog kennt Flammenzunge",
        ns.Catalog.WeaponBuffSpell(5400) == 319778,
        tostring(ns.Catalog.WeaponBuffSpell(5400)))
    check("und eine erfundene Kennung ergibt nichts",
        ns.Catalog.WeaponBuffSpell(999999) == nil)

    local echt = ns.Recommend.Enchant
    ns.Recommend.Enchant = function(entry, slot)
        if slot == "weaponbuff" then return { id = 5400, pct = 96 } end
        return echt(entry, slot)
    end
    ns.Profile.SetMode("mplus")
    rowsInSection("consumables")
    local gefunden
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and rawget(row, "spellID") == 319778 then
            gefunden = row.share:GetText()
        end
    end
    check("der gemessene Waffenbuff steht als Zeile", gefunden == "96%",
        tostring(gefunden))
    ns.Recommend.Enchant = echt
    rowsInSection("consumables")
end

-- Das Eingabefenster zeigt, WAS die Zahl ist.
--
-- Eine sechsstellige Zahl blind zu bestaetigen ist keine Auswahl,
-- sondern ein Versuch. Beim Tippen steht deshalb Symbol und Name daneben
-- - und wenn der Client den Gegenstand nicht kennt, steht das auch da
-- statt eines leeren Feldes.
do
    ns.Profile.SetLanguage("de")
    local genommen
    local f = ns.UI.AskNumber(ns.L["OWN_ADD_ID"], 0,
        function(v) genommen = v end, 8, ns.L["OWN_ADD_HINT"], true)
    check("das Fenster steht da", f ~= nil and f:IsShown())
    check("der Hinweis steht darunter",
        (f.hint:GetText() or "") == ns.L["OWN_ADD_HINT"], tostring(f.hint:GetText()))
    check("die Vorschau ist sichtbar", f.vorschau:IsShown())
    check("und das Feld nimmt acht Stellen", f.box.__maxLetters == 8
        or f.box:GetMaxLetters() == 8, tostring(f.box.__maxLetters))

    -- Eine Zahl eintippen: die Vorschau sagt, was es ist.
    f.box:SetText("240892")
    if f.box:GetScript("OnTextChanged") then
        f.box:GetScript("OnTextChanged")(f.box)
    end
    local gezeigt = f.vorschau.text:GetText() or ""
    check("die Vorschau nennt den Gegenstand", gezeigt ~= "" ,
        gezeigt)

    -- Der Zeiger zeigt das ganze Tooltip.
    --
    -- Name und Symbol sagen, DASS es der richtige Gegenstand ist; ob man
    -- ihn haben will, sagt erst die Wirkung.
    rawset(_G.GameTooltip, "__link", nil)
    if f.vorschau:GetScript("OnEnter") then
        f.vorschau:GetScript("OnEnter")(f.vorschau)
    end
    local gezeigtesItem = rawget(_G.GameTooltip, "__link")
    check("der Zeiger zeigt das Tooltip",
        (gezeigtesItem or ""):find("item:240892", 1, true) ~= nil,
        tostring(gezeigtesItem))

    -- Aber nicht zu einer Zahl, die es nicht gibt: ein leeres Tooltip
    -- sieht aus wie ein Fehler.
    rawset(_G.GameTooltip, "__link", nil)
    f.box:SetText("0")
    if f.vorschau:GetScript("OnEnter") then
        f.vorschau:GetScript("OnEnter")(f.vorschau)
    end
    check("und zu einer leeren Eingabe keines",
        rawget(_G.GameTooltip, "__link") == nil,
        tostring(rawget(_G.GameTooltip, "__link")))

    -- Bei einer Zielmenge bleibt es ein schlichtes Zahlenfeld.
    local g = ns.UI.AskNumber("Menge", 2, function() end)
    check("ohne Gegenstand keine Vorschau", not g.vorschau:IsShown())
    g:Hide()
    ns.Profile.SetLanguage("auto")
end

-- ---------------------------------------------------- Der Omnium-Foliant
--
-- Die Daten dafuer entstehen erst im naechsten Nachtlauf, also bekommt
-- der Zugriff hier fuer einen Moment eine gemessene Antwort. Geprueft
-- wird nicht, DASS Zahlen da sind - das waere eine Pruefung der
-- Attrappe -, sondern was das Fenster aus ihnen macht.
do
    local echterFoliant = ns.Recommend.Folio
    ns.Recommend.Folio = function()
        return {
            { row = 1, seen = 812, picks = {
                { spell = 1286970, pct = 71 }, { spell = 1287425, pct = 29 } } },
            -- Reihe 3 hat nur eine Rune. Sie steht da, kostet aber
            -- keine Messung und traegt keinen Anteil.
            { row = 3, only = 1287555 },
            { row = 4, seen = 790, picks = {
                { spell = 1287772, pct = 58 }, { spell = 1287774, pct = 26 },
                { spell = 1287771, pct = 16 } } },
            -- Reihe 5, so wie sie wirklich aussieht: Ueberladung am
            -- verdoppelten Treffer gemessen, Echos an ihrem Zauber -
            -- und nur Restenergie als Rest.
            { row = 5, seen = 812, picks = {
                { spell = 1279614, pct = 92 },
                { spell = 1279615, pct = 5, derived = true },
                { spell = 1279616, pct = 3 } } },
        }, "warcraftlogs.com"
    end

    local gezeigt = rowsInSection("folio")
    check("der Foliant zeigt Zeilen", gezeigt >= 5, gezeigt .. " Zeilen")

    -- Gruppenkoepfe sind selbst Zeilen, keine Beschriftung an einer
    -- anderen - deshalb steht hier alles Sichtbare in einem Topf.
    local texte, anteile = {}, 0
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() then
            if row.title and row.title:GetText() then
                texte[#texte + 1] = row.title:GetText()
            end
            local s = row.share and row.share:GetText()
            if s and s ~= "" then anteile = anteile + 1 end
        end
    end
    local alleTexte = table.concat(texte, " | ")

    -- Die Grundlage muss dastehen. Ein Anteil ohne sie laedt zum
    -- falschen Vergleich ein: die Reihe misst nie alle Spieler.
    check("die Reihe nennt ihre Grundlage",
        alleTexte:find("812", 1, true) ~= nil, alleTexte:sub(1, 60))

    -- Genau EINE Zeile ist gerechnet - die Restenergie. Waere die
    -- Ueberladung auch gekennzeichnet, stuende die groesste Zahl der
    -- Reihe als Schaetzung da, obwohl sie gemessen ist.
    local gerechnet, gemessen = {}, {}
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.detail then
            local t = row.detail:GetText() or ""
            if t:find(ns.L["FOLIO_DERIVED"], 1, true) then
                gerechnet[#gerechnet + 1] = row.title:GetText() or "?"
            elseif row.share and (row.share:GetText() or "") ~= "" then
                gemessen[#gemessen + 1] = row.title:GetText() or "?"
            end
        end
    end
    check("genau eine gerechnete Zeile", #gerechnet == 1,
        table.concat(gerechnet, " | "))
    if #gerechnet == 1 then
        local rest = (C_Spell.GetSpellInfo(1279615) or {}).name or "#1279615"
        check("und es ist die Restenergie",
            gerechnet[1]:find(rest, 1, true) ~= nil, gerechnet[1])
    end

    -- Die Ueberladung dagegen ist gemessen und muss es auch sagen.
    local ueber = (C_Spell.GetSpellInfo(1279614) or {}).name or "#1279614"
    local ueberGemessen = false
    for _, t in ipairs(gemessen) do
        if t:find(ueber, 1, true) then ueberGemessen = true end
    end
    check("die Ueberladung steht als gemessen da", ueberGemessen,
        table.concat(gemessen, " | "))

    -- Und KEIN erklaerender Absatz mehr. Er stand einmal darunter und
    -- erklaerte, warum diese Rune keine Spur hinterlaesst - vier Zeilen,
    -- die einen Spieler nicht weiterbringen. Was er wissen muss, steht
    -- an der Zeile: "Gerechnet, nicht gesehen".
    local absatz = false
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.title
            and (row.title:GetText() or ""):find("hinterl", 1, true) then
            absatz = true
        end
    end
    check("kein erklaerender Absatz mehr", absatz == false)

    -- Acht Anteile fuer acht gewaehlte Runen. Reihe 3 ist die neunte
    -- Zeile und traegt KEINEN - "100 %" waere dort nur eine
    -- umstaendliche Art, "die einzige" zu sagen.
    check("jede gewaehlte Rune traegt genau einen Anteil",
        anteile == 8, anteile .. " Anteile")

    local einzige
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.detail
            and (row.detail:GetText() or "") == ns.L["FOLIO_ONLY"] then
            einzige = row
        end
    end
    -- Keine Zeile wiederholt den Prozentwert, der rechts schon steht.
    local doppelt = {}
    for _, row in ipairs(wow.rows()) do
        if row:IsShown() and row.detail and row.share then
            local d, s = row.detail:GetText() or "", row.share:GetText() or ""
            local zahl = s:match("^(%d+)%%$")
            if zahl and d:find(zahl, 1, true) then doppelt[#doppelt + 1] = d end
        end
    end
    check("kein Anteil steht zweimal in derselben Zeile", #doppelt == 0,
        table.concat(doppelt, " | "))

    check("die Reihe ohne Wahl steht da", einzige ~= nil)
    if einzige then
        check("und zwar ohne Prozentwert",
            (einzige.share:GetText() or "") == "",
            tostring(einzige.share:GetText()))
    end

    -- Ohne Daten darf der Punkt gar nicht erst im Menueband stehen -
    -- sonst fuehrt er in eine leere Seite.
    ns.Recommend.Folio = function() return nil end
    check("ohne Messung kein Menuepunkt",
        ns.UI.SectionHasData("folio") == false)

    ns.Recommend.Folio = echterFoliant
    MetaCodexDB.section = "talents"
    ns.UI.Refresh()
end

-- ------------------------------------------ Der Knopf am Auktionshaus
--
-- Die Einkaufsliste und "Jetzt suchen" gab es laengst; was fehlte, war
-- der Weg dorthin, wenn man vor dem Auktionshaus steht. Der Knopf muss
-- deshalb zweierlei koennen: die Zahl dessen nennen, was fehlt, und die
-- Erinnerung oeffnen.
do
    -- Das Auktionshaus-Fenster wird im Spiel nachgeladen. Frueher im
    -- Test wurde es schon mehrfach gesetzt und wieder genommen, der
    -- Knopf kann also an einer aelteren Fassung haengen - gesucht wird
    -- er darum an seiner Beschriftung, nicht am Elternteil.
    if not _G.AuctionHouseFrame then
        _G.AuctionHouseFrame = CreateFrame("Frame", "AuctionHouseFrame", UIParent)
    end

    local vorher = MetaCodexDB.section
    MetaCodexDB.section = "talents"

    local erreicht = wow.fire("AUCTION_HOUSE_SHOW")
    check("jemand hoert auf das Auktionshaus", erreicht > 0, erreicht .. " Rahmen")

    local knopf
    for _, f in ipairs(wow.frames) do
        local text = f.label and f.label.GetText and f.label:GetText()
        if type(text) == "string" and text:find("MetaCodex", 1, true)
            and f.GetScript and f:GetScript("OnClick") then
            knopf = f
        end
    end
    check("am Auktionshaus steht ein Knopf", knopf ~= nil)
    if knopf then
        check("und er nennt die Zahl oder die Liste",
            (knopf.label:GetText() or ""):find("MetaCodex", 1, true) ~= nil,
            knopf.label:GetText())

        -- Und er fuehrt zur Erinnerung, nicht irgendwohin.
        knopf:GetScript("OnClick")(knopf)
        check("und oeffnet die Erinnerung",
            MetaCodexDB.section == "remind", tostring(MetaCodexDB.section))
    end
    MetaCodexDB.section = vorher
    ns.UI.Refresh()
end

-- ------------------------------------------------------- Die Scrollleiste
--
-- Sie darf nur dastehen, wenn es etwas zu schieben gibt. Blizzards
-- Vorlage blendet ihre Pfeilknoepfe nie aus; auf einer kurzen Seite
-- sehen sie aus, als gaebe es noch etwas, das man nicht findet.
do
    -- Die EIGENE Leiste, nicht Blizzards. Deren Teile sind beim Aufbau
    -- stillgelegt worden und duerfen nie wieder auftauchen.
    local blizz = _G["MetaCodexScrollScrollBar"]
    if blizz then
        check("Blizzards Leiste bleibt verborgen", blizz:IsShown() == false,
            tostring(blizz:IsShown()))
    end

    local leiste = ns.UI.Frame().scrollRail
    check("die eigene Scrollleiste gibt es", leiste ~= nil)
    if leiste then
        -- Eine lange Seite: die Ausruestung hat mehr Zeilen als Platz.
        rowsInSection("gear")
        local langeSeite = leiste:IsShown()

        -- Und eine kurze: der Foliant mit zwei Zeilen.
        local echterFoliant = ns.Recommend.Folio
        ns.Recommend.Folio = function()
            return { { row = 1, seen = 500, picks = {
                { spell = 1286970, pct = 98 } } } }, "warcraftlogs.com"
        end
        rowsInSection("folio")
        local kurzeSeite = leiste:IsShown()
        ns.Recommend.Folio = echterFoliant

        check("bei langer Liste ist sie da", langeSeite == true,
            tostring(langeSeite))
        check("bei kurzer Liste nicht", kurzeSeite == false,
            tostring(kurzeSeite))

        MetaCodexDB.section = "talents"
        ns.UI.Refresh()
    end
end

-- ------------------------------------------------- Die 60-Upvalue-Grenze
--
-- WoWs Lua laesst einer Funktion hoechstens 60 Upvalues. UI.Refresh sitzt
-- dicht darunter, und eine einzige zusaetzliche Lokale auf Dateiebene
-- hebt sie darueber. Dann laedt UI.lua NICHT MEHR, ns.UI bleibt leer und
-- das Fenster geht gar nicht auf - ein Totalausfall aus einer Zeile.
--
-- Genau das ist am 28.09. passiert, und keine Pruefung hat es gesehen:
-- die Test-VM ist neuer als das Spiel und kennt die Grenze nicht. Also
-- wird sie hier von Hand nachgehalten.
if debug and debug.getinfo then
    local info = debug.getinfo(ns.UI.Refresh, "u")
    local n = info and info.nups or 0
    check("UI.Refresh bleibt unter der 60-Upvalue-Grenze", n > 0 and n <= 60,
        n .. " Upvalues")
    -- Und eine Warnung, bevor es knapp wird: wer bei 57 noch eine
    -- Lokale anlegt, merkt es sonst erst im Spiel.
    if n > 52 and n <= 60 then
        say("  ! UI.Refresh hat " .. n .. " von 60 Upvalues - wenig Luft")
    end
end

say(fails == 0 and "\nalles gruen" or ("\n" .. fails .. " Fehler"))
os.exit(fails == 0 and 0 or 1)
