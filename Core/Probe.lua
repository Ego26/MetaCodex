-- /mc probe
--
-- Die Sonde sagt, was dieser Client und dieser Auctionator wirklich
-- hergeben. Sie existiert, weil die Auctionator-API veroeffentlicht, aber
-- nicht vertraglich ist: was hier gruen ist, ist geprueft, und der Rest ist
-- eine Vermutung, die man nicht in den Quelltext schreiben sollte.

local _, ns = ...

local Probe = {}
ns.Probe = Probe

local L = ns.L

local function yesno(value)
    return value and L["PROBE_YES"] or L["PROBE_NO"]
end

-- Die Sonde schreibt in den Chat UND in einen Puffer.
--
-- Der Chat ist zum Lesen da, nicht zum Kopieren: lange Zeichenketten
-- brechen um, und wer sie herausholen will, faengt an zu markieren.
-- Deshalb sammelt die Sonde alles mit und legt es am Ende in ein Feld,
-- aus dem man es in einem Stueck nehmen kann.
local buffer = {}

local function line(text, ...)
    local formatted = select('#', ...) > 0 and text:format(...) or text
    -- Farbcodes gehoeren in den Chat, nicht in die Zwischenablage.
    buffer[#buffer + 1] = formatted:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    ns.Print(text, ...)
end

function Probe.Run()
    buffer = {}
    ns.Data.Ensure()
    -- Erst anfordern, dann zaehlen: sonst misst die Sonde nur, dass
    -- noch niemand gefragt hat.
    ns.Catalog.WarmNames()
    local build, builtOn = ns.Catalog.Stamp()
    line(L["PROBE_HEADER"], ns.version, build .. " / " .. tostring(builtOn))

    ns.Print("  %s: %s", L["PROBE_AUCTIONATOR"], yesno(ns.Adapter.Loaded()))
    ns.Print("  %s: %s", L["PROBE_API"], yesno(ns.Adapter.Has("CreateShoppingList")))
    ns.Print("  %s: %s", L["PROBE_SEARCH"],
        yesno(ns.Adapter.Has("MultiSearchExact") or ns.Adapter.Has("MultiSearch")))
    ns.Print("  %s: %s", L["PROBE_CONVERT"],
        yesno(ns.Adapter.Has("ConvertToSearchString")))

    -- Namen sind die Waehrung dieses Addons: ohne sie gibt es keine Suche.
    -- Was nicht aufloest, gehoert benannt und nicht verschwiegen.
    local ids = ns.Catalog.AllIDs()
    local resolved, unresolved = 0, {}
    for _, id in ipairs(ids) do
        if ns.Compat.ItemInfo(id) then
            resolved = resolved + 1
        elseif #unresolved < 8 then
            unresolved[#unresolved + 1] = tostring(id)
        end
    end
    line("  " .. L["PROBE_NAMES"], resolved, #ids)
    if #unresolved > 0 then
        line("  " .. L["PROBE_UNRESOLVED"], table.concat(unresolved, ", "))
        -- Der Client liefert sie nach, nicht sofort.
        line("  " .. L["PROBE_AGAIN"])
    end

    -- Fuer eine fremde Spec kommt das Hauptattribut aus dem Client und
    -- nicht vom Charakter. Welcher Weg gegriffen hat, gehoert sichtbar:
    -- nur so merkt man, wenn der Client die Auskunft nicht gibt.
    local specID = ns.Profile.SelectedSpec()
    local primary, source = ns.Compat.SpecPrimaryStat(specID)
    line("  " .. L["PROBE_SPEC"], ns.Compat.SpecName(specID) or "?", tostring(specID))
    line("  " .. L["PROBE_PRIMARY"] .. " (%s)", L["STAT_" .. primary],
        source == "api" and L["PROBE_STAT_API"]
            or source == "catalog" and L["PROBE_STAT_CATALOG"]
            or L["PROBE_STAT_FALLBACK"])

    local scan = ns.Gear.Scan()
    line("  " .. L["PROBE_SOCKETS"], scan.emptySockets)

    for _, entry in ipairs(scan.slots) do
        ns.Print("    %s: %s", L["SLOT_" .. entry.slot],
            entry.enchanted and L["ALREADY_DONE"] or "|cffffd100-|r")
    end

    -- Was der Client in den Taschen zaehlt, Posten fuer Posten.
    --
    -- Die Erinnerung meldete einmal fuenfmal "nichts in der Tasche",
    -- waehrend alles im Beutel lag: nach dem Ladebildschirm hatte der
    -- Server die Beutel noch nicht geschickt. Wer so etwas wieder sieht,
    -- soll nachsehen koennen statt zu raten - hier steht, ob der Client
    -- seine Taschen ueberhaupt kennt und was er je Posten zaehlt.
    line("  " .. L["PROBE_BAGS"], yesno(ns.Compat.BagsKnown()))
    line("  " .. L["PROBE_STOCK"])
    for _, row in ipairs(ns.Remind.Status(ns.Profile.Mode())) do
        line("    %s (%s): %d / %d", tostring(row.name or "?"),
            tostring(row.id), row.owned or 0, row.need or 0)
    end

    -- Was das Addon wirklich belegt.
    --
    -- Die Anzeigen im Spiel zaehlen mit, was noch nicht aufgeraeumt ist:
    -- direkt nach dem Einlesen der Tabellen steht dort mehr, als
    -- uebrig bleibt. Hier wird erst aufgeraeumt und dann gemessen, und
    -- zwar je Ordner - sonst streitet man ueber Zahlen, die niemand
    -- nachrechnen kann.
    local mem = C_AddOns and C_AddOns.GetAddOnMemoryUsage or GetAddOnMemoryUsage
    local refresh = C_AddOns and C_AddOns.UpdateAddOnMemoryUsage or UpdateAddOnMemoryUsage
    if type(mem) == "function" and type(refresh) == "function" then
        pcall(collectgarbage, "collect")
        pcall(refresh)
        local total = 0
        local parts = {}
        for _, name in ipairs({ "MetaCodex", "MetaCodex_Data",
                                "MetaCodex_Dungeons", "MetaCodex_Players" }) do
            local ok, kb = pcall(mem, name)
            kb = (ok and type(kb) == "number") and kb or 0
            total = total + kb
            parts[#parts + 1] = ("%s %.1f"):format(name:gsub("MetaCodex_?", ""):gsub("^$", "Kern"), kb / 1024)
        end
        line("  " .. L["PROBE_MEMORY"], total / 1024, table.concat(parts, ", "))
    end

    Probe.Level()

    -- Und alles zusammen zum Kopieren.
    if ns.UI and ns.UI.ShowText then
        ns.UI.ShowText(table.concat(buffer, "\n"))
    end
end

---Prueft, ob ein Gegenstandslink die Stufe wirklich verschiebt.
---
---Im Fenster stand "Stufe 305" und im Tooltip "Gegenstandsstufe 72". Ohne
---diese Ausgabe ist nicht zu sehen, an welcher der vier Stellen es
---bricht: Grundstufe, Differenz, Bonus-ID oder Linkaufbau.
function Probe.Level()
    line(L["PROBE_LEVEL_HEADER"])

    -- Die Belohnungstabelle ROH, wie der Client sie gibt. Das Menue
    -- zeigte "+2-8" neben "+4-5", und das kann aus einer richtigen
    -- Tabelle nicht entstehen - also muss man die Tabelle sehen.
    if C_MythicPlus and C_MythicPlus.GetRewardLevelForDifficultyLevel then
        local parts = {}
        for level = 2, 14 do
            local ok, a, b = pcall(C_MythicPlus.GetRewardLevelForDifficultyLevel, level)
            parts[#parts + 1] = ("+%d=%s/%s"):format(level,
                ok and tostring(a) or "err", ok and tostring(b) or "err")
        end
        line("Belohnung roh (a/b): " .. table.concat(parts, "  "))
    end
    local tracks = ns.Catalog.Tracks and ns.Catalog.Tracks()
    local probe = ns.Catalog.ProbeItem and ns.Catalog.ProbeItem()
    if tracks and probe then
        local season = ns.Compat.SeasonTracks(probe)
        local parts = {}
        for t, track in ipairs(tracks) do
            if season and season[t] then
                local levels = {}
                for _, bonus in ipairs(track.lists) do
                    local ok, got = pcall(C_Item.GetDetailedItemLevelInfo,
                        ("item:%d::::::::::::1:%d"):format(probe, bonus))
                    levels[#levels + 1] = ok and tostring(got) or "?"
                end
                parts[#parts + 1] = ns.Compat.TrackName(t) .. ": " .. table.concat(levels, " ")
            end
        end
        line("Pfade der Saison: " .. (#parts > 0 and table.concat(parts, " | ") or "keine erkannt"))
    end

    local rec = ns.Recommend.Gear(ns.Profile.SelectedSpec(),
        ns.Profile.LookupMode(), ns.Profile.Source())
    local itemID, want
    for _, list in pairs(rec or {}) do
        for _, row in ipairs(list) do
            if row.id and (row.ilvl or 0) > 0 then itemID, want = row.id, row.ilvl break end
        end
        if itemID then break end
    end
    if not itemID then
        line("  " .. L["PROBE_LEVEL_NONE"])
        return
    end

    local name = ns.Compat.ItemInfo(itemID) or ("#" .. itemID)
    local info = { pcall(C_Item.GetItemInfo, itemID) }
    local base = info[1] and tonumber(info[5]) or nil
    line("    %s (%d)", name, itemID)
    line("    " .. L["PROBE_LEVEL_BASE"], tostring(base), tostring(want))

    if not base then return end
    local delta = want - base
    local bonus = ns.Catalog.LevelDeltaBonus(delta)
    line("    " .. L["PROBE_LEVEL_DELTA"], delta, tostring(bonus))

    local link = ns.Compat.LinkAtLevel(itemID, want)
    line("    " .. L["PROBE_LEVEL_LINK"], tostring(link))
    if link then
        local got = { pcall(C_Item.GetItemInfo, link) }
        line("    " .. L["PROBE_LEVEL_RESULT"],
            tostring(got[1] and got[5]), tostring(want))
    end
end
