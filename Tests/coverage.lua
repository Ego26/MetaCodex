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
