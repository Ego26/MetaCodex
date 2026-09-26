-- Deckung: was hat jede Spec in jeder Aktivitaet?
--
--     node Tests/run.js coverage.lua
--
-- Die Testdateien nebenan pruefen Verhalten an einzelnen Beispielen.
-- Diese hier fragt die Daten selbst ab, und zwar vollstaendig: vierzig
-- Speccs mal zehn Aktivitaeten, jedes Mal ueber denselben Weg, den auch
-- das Fenster geht. Sie behauptet nichts ueber "die Talente stimmen" -
-- das kann keine Datei wissen. Sie sagt, wo etwas FEHLT, und das ist
-- die Frage, die man vor einer Veroeffentlichung stellt.
--
-- Der Anlass: in der Bossansicht des Raids stand "keine Quelle liefert
-- einen fertigen String", obwohl raider.io fuer jede Spec einen hatte.
-- Aufgefallen ist das durch Hinsehen im Spiel. So etwas soll eine Liste
-- finden, nicht ein Zufall.

package.path = BASE .. "/Tests/?.lua;" .. package.path
local wow = require("wow_stub")
local say = print

wow.install({
    locale = "enUS",
    classID = 11,
    specID = 105,
    specName = "Restoration",
    stats = { 100, 300, 500, 900 },
    ratings = {},
    auctionator = false,
    gear = {},
    sockets = {},
    owned = {},
})

-- --------------------------------------------------------------- Laden

local ns = {}
local function load(tocText, dir)
    for line in tocText:gmatch("[^\r\n]+") do
        local name = line:match("^([%w\\_]+%.lua)%s*$")
        if name then
            local rel = (dir and (dir .. "/") or "") .. name:gsub("\\", "/")
            local chunk, err = loadfile(BASE .. "/" .. rel)
            if not chunk then error("laden: " .. rel .. ": " .. tostring(err)) end
            local ok, runErr = pcall(chunk, "MetaCodex", ns)
            if not ok then error("laden: " .. rel .. ": " .. tostring(runErr)) end
        end
    end
end

load(TOC)
load(DATA_TOC, "MetaCodex_Data")
load(DUNGEON_TOC, "MetaCodex_Dungeons")
load(PLAYERS_TOC, "MetaCodex_Players")

-- Die Ablage anlegen: ohne sie kann nichts eingestellt werden, und
-- die Pruefung stellt den Modus um.
_G.MetaCodexDB = {}
ns.Profile.Init()

-- ------------------------------------------------------------ Erhebung

local gaps = 0
local function gap(text)
    gaps = gaps + 1
    say("    FEHLT  " .. text)
end

-- Alle Speccs, aus dem Katalog.
--
-- Nicht ueber ns.Compat.Classes: das fragt den Client, und die Attrappe
-- kennt nur die eine Klasse, mit der sie eingerichtet wurde. Der Katalog
-- stammt aus den Spieltabellen und kennt alle vierzig - genau deshalb
-- taugt er als Massstab fuer "was fehlt".
local specs = {}
for id = 1, 2000 do
    local cls, spec = ns.Catalog.SpecSlug(id)
    if cls then specs[#specs + 1] = { id = id, name = cls .. " / " .. spec } end
end
say("Speccs im Katalog: " .. #specs)
say("")

local total = { picks = 0, build = 0, text = 0, cells = 0 }

for _, mode in ipairs(ns.MODES) do
    local withPicks, withBuild, withText, borrowed = 0, 0, 0, 0
    local missing = {}
    for _, spec in ipairs(specs) do
        total.cells = total.cells + 1
        local picks, build = ns.Recommend.Talents(spec.id, mode.key, ns.Recommend.ALL)
        local hasPicks = picks ~= nil and #picks > 0
        local hasBuild = build ~= nil and build.nodes ~= nil and #build.nodes > 0
        local hasText = build ~= nil and type(build.text) == "string" and #build.text > 20
        if hasPicks then withPicks = withPicks + 1; total.picks = total.picks + 1 end
        if hasBuild then withBuild = withBuild + 1; total.build = total.build + 1 end
        if hasText then
            withText = withText + 1
            total.text = total.text + 1
            if build.fromBase or build.fromSource then borrowed = borrowed + 1 end
        end
        if not hasPicks or not hasBuild or not hasText then
            local what = {}
            if not hasPicks then what[#what + 1] = "Anteile" end
            if not hasBuild then what[#what + 1] = "Build" end
            if not hasText then what[#what + 1] = "String" end
            missing[#missing + 1] = spec.name .. " (" .. table.concat(what, ", ") .. ")"
        end
    end
    say(("%-14s  Anteile %2d/%d   Build %2d/%d   String %2d/%d   (davon geliehen %d)")
        :format(mode.label, withPicks, #specs, withBuild, #specs, withText, #specs, borrowed))
    for _, line in ipairs(missing) do gap(mode.label .. ": " .. line) end
end

-- Und jetzt jeder Abschnitt, den das Fenster anbietet.
--
-- Die Frage ist nicht nur "gibt es Talente", sondern: bietet das Fenster
-- einen Abschnitt an, und steht dann auch etwas darin? Ein angebotener
-- Abschnitt, der leer bleibt, ist der schlimmere Fall - er verspricht
-- etwas und haelt es nicht. Gefragt wird ueber dieselbe Funktion, die
-- auch die Seitenleiste fragt.
say("")
say("Abschnitte je Aktivitaet (angeboten / davon leer):")
local SECTIONS = {
    { key = "talents",    label = "Talente" },
    { key = "gear",       label = "Ausruestung" },
    { key = "tier",       label = "Tier-Set" },
    { key = "crafted",    label = "Handwerk" },
    { key = "enchants",   label = "VZ & Steine" },
    { key = "consumables", label = "Verbrauchsgueter" },
    { key = "remind",     label = "Erinnerung" },
    { key = "stats",      label = "Zielwerte" },
    { key = "players",    label = "Top-Spieler" },
}

---Steht in diesem Abschnitt wirklich etwas?
local function filled(section, specID, mode)
    if section == "talents" then
        local picks, build = ns.Recommend.Talents(specID, mode, ns.Recommend.ALL)
        return (picks and #picks > 0) or (build and build.nodes and #build.nodes > 0)
    elseif section == "gear" then
        local gear = ns.Recommend.Gear(specID, mode, ns.Recommend.ALL)
        if not gear then return false end
        for _, list in pairs(gear) do if #list > 0 then return true end end
        return false
    elseif section == "tier" or section == "crafted" then
        -- Angeboten wird er nur, wenn etwas drinsteht - die Pruefung
        -- steht in HasSection und muss hier nicht zweimal stehen.
        return true
    elseif section == "enchants" then
        local entry = ns.Recommend.For(specID, mode, ns.Recommend.ALL)
        if not entry then return false end
        local slots = 0
        for _ in pairs(entry.enchants or {}) do slots = slots + 1 end
        return slots > 0 or #(entry.gems or {}) > 0
    elseif section == "consumables" or section == "remind" then
        local list = ns.Recommend.Consumables(specID, mode, ns.Recommend.ALL)
        return list ~= nil and #list > 0
    elseif section == "stats" then
        local st = ns.Recommend.Stats(specID, mode, ns.Recommend.ALL)
        return st ~= nil and st.values ~= nil and next(st.values) ~= nil
    elseif section == "players" then
        local list = ns.Recommend.Players(specID, mode, ns.Recommend.ALL)
        return list ~= nil and #list > 0
    end
    return true
end

for _, mode in ipairs(ns.MODES) do
    local parts = {}
    for _, section in ipairs(SECTIONS) do
        local offered, empty = 0, {}
        for _, spec in ipairs(specs) do
            if ns.Recommend.HasSection(spec.id, mode.key, ns.Recommend.ALL, section.key) then
                offered = offered + 1
                if not filled(section.key, spec.id, mode.key) then
                    empty[#empty + 1] = spec.name
                end
            end
        end
        parts[#parts + 1] = ("%s %d/%d%s"):format(section.label, offered, #specs,
            #empty > 0 and (" LEER:" .. #empty) or "")
        for _, name in ipairs(empty) do
            gap(mode.label .. " / " .. section.label .. ": " .. name .. " wird angeboten, ist aber leer")
        end
    end
    say("  " .. mode.label)
    say("     " .. table.concat(parts, "   "))
end

-- Der Tooltip: haette jede Spec dort etwas zu sagen?
--
-- Er braucht zweierlei: die Rangfolge der Zweitwerte fuer die Spec, auf
-- der man steht, und die Ausruestungsliste ihres Platzes. Gefragt wird
-- ueber denselben Weg wie im Spiel - die aktive Spec wird dafuer
-- untergeschoben, sonst pruefte man immer dieselbe.
say("")
say("Gegenstands-Tooltip (Rangnummern / Platz in der Liste):")
do
    local realSpec = ns.Compat.CurrentSpec
    local realStats = ns.Compat.ItemStats
    ns.Compat.ItemStats = function()
        -- Ein Item, das alle vier Zweitwerte traegt: so zeigt sich, ob
        -- die Rangfolge vollstaendig ist.
        return {
            ITEM_MOD_CRIT_RATING_SHORT = 100, ITEM_MOD_HASTE_RATING_SHORT = 100,
            ITEM_MOD_MASTERY_RATING_SHORT = 100, ITEM_MOD_VERSATILITY = 100,
        }
    end
    for _, mode in ipairs(ns.MODES) do
        ns.Profile.SetMode(mode.key)
        local withRanks, withGear = 0, 0
        local missing = {}
        for _, spec in ipairs(specs) do
            ns.Compat.CurrentSpec = function() return spec.id end
            local ranks = ns.Tooltip.StatRanks("|Hitem:200001|h[Item]|h")
            local full = ranks ~= nil
            if full then
                for _, key in ipairs(ns.SECONDARY) do
                    if not ranks[key] then full = false end
                end
            end
            if full then withRanks = withRanks + 1 end
            local gear = ns.Recommend.Gear(spec.id, mode.key, ns.Recommend.ALL)
            local any = false
            for _, list in pairs(gear or {}) do if #list > 0 then any = true end end
            if any then withGear = withGear + 1 end
            if not full or not any then
                missing[#missing + 1] = spec.name
                    .. (not full and " (Rangfolge)" or "") .. (not any and " (Liste)" or "")
            end
        end
        say(("  %-14s Rangnummern %2d/%d   Platz %2d/%d")
            :format(mode.label, withRanks, #specs, withGear, #specs))
        for _, line in ipairs(missing) do gap("Tooltip " .. mode.label .. ": " .. line) end
    end
    ns.Compat.CurrentSpec = realSpec
    ns.Compat.ItemStats = realStats
end

-- Und dasselbe je Dungeon und je Boss: dort waehlt der Spieler, und dort
-- war der Fehler.
say("")
for _, mode in ipairs(ns.MODES) do
    local list = ns.Recommend.Dungeons(mode.key)
    if #list > 0 then
        local cells, withText = 0, 0
        local missing = {}
        for _, entry in ipairs(list) do
            for _, spec in ipairs(specs) do
                cells = cells + 1
                local _, build = ns.Recommend.Talents(spec.id, entry.key, ns.Recommend.ALL)
                if build and type(build.text) == "string" and #build.text > 20 then
                    withText = withText + 1
                else
                    missing[#missing + 1] = entry.name .. " - " .. spec.name
                end
            end
        end
        say(("%-14s  %d Unterpunkte, String %d/%d"):format(mode.label, #list, withText, cells))
        -- Nur die ersten paar nennen, sonst ertrinkt der Bericht.
        for i = 1, math.min(#missing, 5) do gap(mode.label .. ": " .. missing[i]) end
        if #missing > 5 then
            say("    ... und " .. (#missing - 5) .. " weitere")
            gaps = gaps + (#missing - 5)
        end
    end
end

say("")
say(("Zellen geprueft: %d, davon mit Anteilen %d, mit Build %d, mit String %d")
    :format(total.cells, total.picks, total.build, total.text))
if gaps > 0 then
    say(gaps .. " Luecken")
else
    say("keine Luecken")
end
