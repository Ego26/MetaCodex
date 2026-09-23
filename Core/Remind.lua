-- Erinnerung: was fehlt, bevor es losgeht.
--
-- Der Anlass war ein sehr konkreter: der Schluesselstein startet, und erst
-- dann faellt auf, dass keine Praetraenke mehr da sind. Danach ist es zu
-- spaet - man kann nicht mehr zum Auktionshaus.
--
-- Deshalb prueft diese Datei beim BETRETEN, nicht beim Start. Und sie
-- prueft gegen die Beutel, nicht gegen eine Liste: was zaehlt, ist was
-- wirklich da ist.

local _, ns = ...
local L = ns.L

local Remind = {}
ns.Remind = Remind

-- Welcher Modus zu welcher Instanz gehoert. Mehr Faelle gibt es nicht:
-- Arena und Schlachtfeld haben eigene Typen, und dort erinnert das Addon
-- nicht, weil es dort nichts zu kaufen gibt, was vorher fehlen koennte.
local MODE_BY_INSTANCE = {
    party = "mplus",
    raid = "raid",
}

-- Die Reihenfolge der Arten im Reiter, dieselbe wie unter Verbrauchsgueter.
local KIND_ORDER = { "flask", "food", "potion", "heal", "oil", "other", "vantus" }

---Der Stand je Art: das haeufigste Stueck, was man davon hat, was man
---haben will, und ob das reicht.
---
---Das ist die Auskunft hinter der Chatzeile. Dort steht nur, was fehlt;
---hier steht alles, auch was in Ordnung ist - sonst weiss niemand, OB
---die Erinnerung ueberhaupt etwas prueft.
---@param mode string
---@return table[] { kind, id, name, owned, need, state }  state: "ok" | "low" | "none"
function Remind.Status(mode)
    local out = {}
    if not ns.Recommend.Ready() then return out end
    local specID = ns.Profile.SelectedSpec()
    if not specID then return out end
    local list = ns.Recommend.Consumables(specID, mode, ns.Recommend.ALL)
    if not list then return out end

    local bestOfKind = {}
    for _, entry in ipairs(list) do
        local kind = (entry.id and ns.Catalog.ConsumableKind(entry.id)) or entry.kind or "other"
        local known = bestOfKind[kind]
        if not known or (entry.pct or 0) > (known.pct or 0) then bestOfKind[kind] = entry end
    end

    local below = ns.Profile.WarnBelow()
    for _, kind in ipairs(KIND_ORDER) do
        local entry = bestOfKind[kind]
        -- Die eigene Wahl schlaegt die Messung: gezaehlt wird, was man
        -- benutzt, nicht was die Besten benutzen.
        local own = ns.Profile.OwnConsumable(kind)
        if own then
            local name = ns.Compat.ItemInfo(own)
            entry = { id = own, name = name, pct = nil, own = true }
        end
        if entry and entry.id then
            local need = ns.Profile.ConsumableTarget(kind)
            -- Hoehere Qualitaet deckt den Bedarf; niedrigere steht dabei.
            local lowerIDs, higherIDs = ns.Catalog.Tiers(entry.id)
            local owned, lower = ns.Compat.ItemCount(entry.id), 0
            for _, other in ipairs(higherIDs) do owned = owned + ns.Compat.ItemCount(other) end
            for _, other in ipairs(lowerIDs) do lower = lower + ns.Compat.ItemCount(other) end
            local state = "ok"
            if owned == 0 then state = lower > 0 and "low" or "none"
            elseif owned < need * below then state = "low" end
            if need > 0 then
                out[#out + 1] = {
                    kind = kind, id = entry.id, own = entry.own,
                    name = ns.Compat.ItemInfo(entry.id) or entry.name,
                    owned = owned, lower = lower, need = need, state = state, pct = entry.pct,
                }
            end
        end
    end
    return out
end

---Was gerade fehlt.
---
---Gibt Zeilen zurueck, keine fertigen Saetze - wer sie anzeigt,
---entscheidet selbst, wie laut.
---@param mode string
---@return table[] missing  { name, owned, need }
function Remind.Check(mode)
    local out = {}
    if not ns.Recommend.Ready() then return out end

    -- Dieselbe Pruefung wie im Reiter "Erinnerung" - eine Stelle, nicht
    -- zwei, die sich auseinanderentwickeln. Gemeldet wird, was knapp
    -- oder leer ist.
    for _, row in ipairs(Remind.Status(mode)) do
        if row.state ~= "ok" then
            out[#out + 1] = { name = row.name or ("#" .. row.id), owned = row.owned, need = row.need, lower = row.lower or 0 }
        end
    end
    table.sort(out, function(a, b) return a.owned < b.owned end)
    return out
end

---Prueft und meldet. Still, wenn alles da ist.
---@param mode string
---Die Zeilen, die eine Ansage ausmachen wuerde - ohne sie zu machen.
---
---Getrennt von Announce, weil die Vorschau in den Einstellungen dasselbe
---zeigen muss wie der Ernstfall. Zwei Texte, die dasselbe sagen sollen,
---laufen sonst auseinander.
---@param mode string
---@return string[] parts
function Remind.Lines(mode)
    local parts = {}
    for _, row in ipairs(Remind.Check(mode)) do
        if row.owned > 0 then
            parts[#parts + 1] = L["REMIND_LOW"]:format(row.name, row.owned)
        elseif (row.lower or 0) > 0 then
            parts[#parts + 1] = L["REMIND_LOWER"]:format(row.name, row.lower)
        else
            parts[#parts + 1] = L["REMIND_NONE"]:format(row.name)
        end
    end
    -- Auch die offenen Verzauberungen und Steine - gezaehlt gegen
    -- die Ausruestung, wie im Reiter. Vor dem Pull ist der letzte
    -- Moment, an dem man das noch aendern kann.
    local open = 0
    if ns.Profile.Complete() and not ns.Profile.IsForeignClass() then
        open = ns.List.BuyCount(ns.List.Build(ns.Gear.Scan()))
    end
    if open > 0 then parts[#parts + 1] = L["REMIND_ENCHANTS"]:format(open) end
    return parts
end

---Sagt es auf den eingestellten Wegen.
---@param text string
function Remind.Deliver(text)
    if ns.Profile.RemindWay("chat") then ns.Print(text) end
    if ns.Profile.RemindWay("warning") and RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo and ChatTypeInfo.RAID_WARNING)
    end
    if ns.Profile.RemindWay("sound") and PlaySound then
        pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
    end
    if ns.Profile.RemindWay("window") and ns.UI and ns.UI.ShowReminder then
        ns.UI.ShowReminder(text)
    end
end

function Remind.Announce(mode)
    local parts = Remind.Lines(mode)
    if #parts == 0 then return end
    Remind.Deliver(L["REMIND_MISSING"]:format(table.concat(parts, ", ")))
end

-- Einmal je Instanz. PLAYER_ENTERING_WORLD feuert auch nach jedem
-- Ladebildschirm innerhalb derselben Instanz, und dreimal dieselbe
-- Warnung ist eine Warnung weniger.
local lastAnnounced = nil

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:SetScript("OnEvent", function()
    if not ns.Profile.RemindersOn() then return end
    if not ns.Profile.RemindOnEnter() then return end

    local inside, kind = IsInInstance()
    local mode = inside and MODE_BY_INSTANCE[kind] or nil
    if not mode then
        lastAnnounced = nil
        return
    end

    local here = GetInstanceInfo and select(8, GetInstanceInfo()) or kind
    if lastAnnounced == here then return end
    lastAnnounced = here

    -- Die Daten liegen im nachladbaren Addon. Wer nie das Fenster
    -- geoeffnet hat, hat sie noch nicht - hier ist der Moment, in dem
    -- sie gebraucht werden.
    if not ns.Data.Ensure() then return end
    Remind.Announce(mode)
end)

-- Am Auktionshaus: einmal anbieten, nicht aufdraengen.
--
-- Das Fenster von selbst aufzureissen waere die naheliegende Loesung und
-- die falsche - wer zum Verkaufen da ist, hat gerade etwas anderes vor.
-- Eine Zeile im Chat sagt dasselbe und laesst die Entscheidung dort, wo
-- sie hingehoert.
local auctionFrame = CreateFrame("Frame")
auctionFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
auctionFrame:SetScript("OnEvent", function()
    if not ns.Profile.RemindersOn() then return end
    if not ns.Profile.RemindAtAuctionHouse() then return end
    if ns.UI.IsShown() then return end
    if not ns.Data.Ensure() then return end

    -- Gezaehlt wird gegen die Beutel, nicht gegen eine Liste: die Frage
    -- ist, was JETZT fehlt, nicht was einmal auf einem Zettel stand.
    local rows = ns.List.Build(ns.Gear.Scan())
    local missing = ns.List.BuyCount(rows)
    if missing > 0 then
        ns.Print(L["AH_OFFER"]:format(missing))
    end
end)
