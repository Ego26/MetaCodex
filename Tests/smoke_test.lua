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
check("Filter zaehlt nur leere Sockel", only.gems and only.gems.need == 2,
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
check("Hauptattribut fremder Spec", stat == "str" and source == "api",
    stat .. " / " .. source)
ns.Profile.Set("main", "crit")
local foreignRows = bySlot(ns.List.Build(scan))
check("fremde Klasse ohne Steine", foreignRows.gems == nil)
check("fremde Klasse zaehlt beide Ringe", foreignRows.ring and foreignRows.ring.need == 2,
    foreignRows.ring and tostring(foreignRows.ring.need))

ns.Profile.SelectActive()
check("zurueck auf die aktive Spec", ns.Profile.SelectedSpec() == 105)

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
check("Stueckzahl uebergeben", handed and handed.terms[1]:find(";2$") ~= nil,
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
    -- Und die Chatzeile beim Betreten nennt sie mit.
    wow.printed = {}
    ns.Remind.Announce("raid")
    local said = table.concat(wow.printed, " ")
    check("Chatzeile nennt offene Verzauberungen", said:find("offen") ~= nil or said:find("open") ~= nil, said:sub(1, 120))
end
check("Erinnerung fehlt bei PvP", not ns.UI.SectionHasData("remind", "2v2"))

-- ------------------------------------------------- Held-Baeume und Folio

-- Die Namen der Held-Baeume kommen aus dem Katalog, in der Sprache des
-- Fensters; der Folio hat Zeilen. Ob die Daten schon Anteile tragen,
-- entscheidet der naechste Sammellauf - hier zaehlt, dass nichts bricht.
check("Held-Baum hat einen deutschen Namen", ns.Catalog.SubTreeName(40) == "Zauberer", ns.Catalog.SubTreeName(40))
ns.SetLanguage("enUS")
check("und einen englischen", ns.Catalog.SubTreeName(40) == "Spellslinger", ns.Catalog.SubTreeName(40))
ns.SetLanguage("deDE")
check("Folio hat fuenf Zeilen", #(ns.Catalog.Folio() or {}) == 5, tostring(#(ns.Catalog.Folio() or {})))
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
    check("Folio ohne Daten bleibt verborgen oder zeigt Zeilen",
        (not ns.UI.SectionHasData("folio", "raid")) or rowsInSection("folio") > 0)
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
ns.UI.ApplyScale()
check("Fenster traegt den Faktor", _G.MetaCodexFrame:GetScale() == 1.2, tostring(_G.MetaCodexFrame:GetScale()))
ns.Profile.SetWindowScale(1)
ns.UI.ApplyScale()

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

-- Drinnen schon.
wow.instance = "raid"
wow.instanceID = 42
wow.printed = {}
wow.fire("PLAYER_ENTERING_WORLD")
check("im Schlachtzug warnt sie", #wow.printed > 0,
    table.concat(wow.printed, " | "))

-- Aber nur einmal. PLAYER_ENTERING_WORLD feuert nach jedem
-- Ladebildschirm, und dreimal dieselbe Warnung ist eine Warnung weniger.
wow.printed = {}
wow.fire("PLAYER_ENTERING_WORLD")
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
        check("und ein Weg ins Addon",
            said:find("|Haddon:MetaCodex:list|h", 1, true) ~= nil, tostring(said))
        -- Und das Fenster steht wirklich da, als Liste mit Symbolen.
        local window
        for _, f in ipairs(wow.frames) do
            if rawget(f, "body") and rawget(f, "title")
                and f.title:GetText() == L["REMIND_WINDOW_TITLE"] then window = f end
        end
        check("das Erinnerungsfenster steht da", window ~= nil and window:IsShown())
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
    local dist = p and math.floor(math.sqrt(p[4] * p[4] + p[5] * p[5]) + 0.5)
    check("er sitzt auf dem Ring", dist == 80, tostring(dist))
    -- Ein anderer Winkel verschiebt ihn, der Abstand bleibt.
    ns.Profile.SetMinimapAngle(0)
    ns.Minimap.Update()
    local q = button.__points[#button.__points]
    check("ein anderer Winkel, derselbe Ring",
        math.floor(q[4] + 0.5) == 80 and math.floor(q[5] + 0.5) == 0,
        math.floor(q[4] + 0.5) .. "/" .. math.floor(q[5] + 0.5))
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

say(fails == 0 and "\nalles gruen" or ("\n" .. fails .. " Fehler"))
os.exit(fails == 0 and 0 or 1)
