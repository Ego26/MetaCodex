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
---@param forSpec number|nil Spec, nach dem gefragt wird; ohne: der aktive
---@return table[] { kind, id, name, owned, need, state }  state: "ok" | "low" | "none"
function Remind.Status(mode, forSpec)
    local out = {}
    if not ns.Recommend.Ready() then return out end
    -- Gefragt wird nach dem Spec, der gleich in den Dungeon geht.
    --
    -- Im Fenster darf man jeden ansehen - dafuer ist es da. Vor dem Pull
    -- ist die Frage aber nicht "was nehmen die besten Elementar-
    -- Schamanen", sondern was DIESER Charakter braucht. Was der Client
    -- sagt, schlaegt deshalb die Ansicht; nur wenn er schweigt, gilt die
    -- Wahl im Fenster.
    local specID = forSpec or ns.Compat.CurrentSpec() or ns.Profile.SelectedSpec()
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
                    name = ns.Compat.ItemInfo(entry.id)
                        or ns.Catalog.ItemName(entry.id) or entry.name,
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
            out[#out + 1] = {
                id = row.id, name = row.name or ("#" .. row.id),
                owned = row.owned, need = row.need, lower = row.lower or 0,
            }
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
---@param mode string
---@param linked boolean|nil Gegenstandslinks statt blosser Namen
function Remind.Lines(mode, linked)
    local parts = {}
    for _, row in ipairs(Remind.Check(mode)) do
        -- Im Chat der echte Gegenstandslink: dann haengt das Tooltip
        -- daran, Shift-Klick setzt ihn in die Suche, und man muss den
        -- Namen nicht abtippen. Ohne geladenen Gegenstand bleibt der
        -- Name - ein Link, der ins Leere zeigt, waere schlimmer.
        local label = row.name
        if linked and row.id then
            local _, link = ns.Compat.ItemInfo(row.id)
            label = link or label
        end
        if row.owned > 0 then
            parts[#parts + 1] = L["REMIND_LOW"]:format(label, row.owned)
        elseif (row.lower or 0) > 0 then
            parts[#parts + 1] = L["REMIND_LOWER"]:format(label, row.lower)
        else
            parts[#parts + 1] = L["REMIND_NONE"]:format(label)
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

---Der Klick-Link, der das Addon oeffnet.
---
---Blizzard laesst eigene Linktypen unter "addon:" zu; wer darauf klickt,
---landet in SetItemRef, und dort faengt MetaCodex ihn ab.
---@param what string
---@param text string
---@return string
function Remind.AddonLink(what, text)
    return "|cff" .. ns.Style:Hex("accent") .. "|Haddon:MetaCodex:" .. what
        .. "|h[" .. text .. "]|h|r"
end

---Sagt es auf den eingestellten Wegen.
---@param text string Fuer Fenster, Warnung und Ton
---@param chatText string|nil Fuer den Chat, mit Links; sonst derselbe
function Remind.Deliver(text, chatText, list)
    if ns.Profile.RemindWay("chat") then ns.Print(chatText or text) end
    if ns.Profile.RemindWay("warning") and RaidNotice_AddMessage and RaidWarningFrame then
        RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo and ChatTypeInfo.RAID_WARNING)
    end
    if ns.Profile.RemindWay("sound") and PlaySound then
        pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
    end
    if ns.Profile.RemindWay("window") and ns.UI and ns.UI.ShowReminder then
        ns.UI.ShowReminder(text, list)
    end
end

function Remind.Announce(mode)
    local parts = Remind.Lines(mode)
    if #parts == 0 then return end
    local linked = Remind.Lines(mode, true)
    Remind.Deliver(
        L["REMIND_MISSING"]:format(table.concat(parts, ", ")),
        L["REMIND_MISSING"]:format(table.concat(linked, ", "))
            -- Der Link fuehrt dorthin, wovon die Zeile handelt: zur
            -- Erinnerung. Die Einkaufsliste ist der naechste Schritt,
            -- nicht die Antwort auf "was fehlt mir".
            .. "  " .. Remind.AddonLink("remind", L["REMIND_OPEN_LIST"]),
        Remind.Check(mode))
end

-- Einmal je Instanz. PLAYER_ENTERING_WORLD feuert auch nach jedem
-- Ladebildschirm innerhalb derselben Instanz, und dreimal dieselbe
-- Warnung ist eine Warnung weniger.
local lastAnnounced = nil

-- Erst fragen, wenn der Client antworten kann.
--
-- PLAYER_ENTERING_WORLD kommt, sobald der Ladebildschirm faellt. Die
-- Beutel schickt der Server danach, und bis dahin zaehlt GetItemCount
-- ueberall null - ohne dazuzusagen, dass es nur noch nichts weiss. Wer
-- in diesem Moment meldet, meldet "nichts in der Tasche", waehrend das
-- Fläschchen im Beutel liegt. Genau das ist beim ersten Dungeon
-- passiert.
--
-- Also wird gewartet: auf BAG_UPDATE_DELAYED, das nach dem Zonen kommt,
-- und darauf, dass der Rucksack ueberhaupt Plaetze meldet. Nach acht
-- Sekunden wird trotzdem gemeldet - lieber spaet als gar nicht, und so
-- lange braucht kein Server.
local waitingMode, bagsSpoke, waited = nil, false, 0

local function tryAnnounce()
    if not waitingMode then return end
    -- Auch auf die Namen wird gewartet.
    --
    -- Auf einem frischen Charakter kennt der Client keinen Gegenstand,
    -- und dann stand "Liquid Luster" neben einem Fragezeichen, wo
    -- "Flüssiger Glanz" hingehoert. Eine Chatzeile laesst sich spaeter
    -- nicht mehr aendern, also wird sie erst geschrieben, wenn die
    -- Namen da sind.
    local unnamed = 0
    for _, row in ipairs(Remind.Status(waitingMode)) do
        if row.id and not ns.Compat.ItemInfo(row.id) then
            unnamed = unnamed + 1
            ns.Compat.RequestItem(row.id)
        end
    end
    local ready = bagsSpoke and ns.Compat.BagsKnown() and unnamed == 0
    if not ready and waited < 8 then
        waited = waited + 0.5
        C_Timer.After(0.5, tryAnnounce)
        return
    end
    local mode = waitingMode
    waitingMode = nil
    Remind.Announce(mode)
end

local bagWatch = CreateFrame("Frame")
bagWatch:RegisterEvent("BAG_UPDATE_DELAYED")
bagWatch:SetScript("OnEvent", function() bagsSpoke = true end)

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
    -- Die Namen, solange noch gewartet wird: wer nie das Fenster
    -- geoeffnet hat, hat noch keinen einzigen.
    ns.Catalog.WarmNames()
    -- Nicht sofort: siehe oben, die Taschen sind noch stumm.
    -- bagsSpoke beginnt bei false, auch wenn der Rucksack schon
    -- Plaetze meldet: die Plaetze kennt der Client aus der Sitzung davor,
    -- den Inhalt schickt der Server erst.
    waitingMode, bagsSpoke, waited = mode, false, 0
    C_Timer.After(0.5, tryAnnounce)
end)

-- Am Auktionshaus: einmal anbieten, nicht aufdraengen.
--
-- Das Fenster von selbst aufzureissen waere die naheliegende Loesung und
-- die falsche - wer zum Verkaufen da ist, hat gerade etwas anderes vor.
-- Eine Zeile im Chat sagt dasselbe und laesst die Entscheidung dort, wo
-- sie hingehoert.
local auctionFrame = CreateFrame("Frame")
auctionFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
auctionFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
auctionFrame:SetScript("OnEvent", function(_, event)
    -- Zu, also weg mit der Liste fuer diesen einen Einkauf.
    if event == "AUCTION_HOUSE_CLOSED" then
        if ns.UI and ns.UI.DropTemporaryList then ns.UI.DropTemporaryList() end
        return
    end
    if not ns.Profile.RemindersOn() then return end
    if not ns.Profile.RemindAtAuctionHouse() then return end
    if ns.UI.IsShown() then return end
    if not ns.Data.Ensure() then return end

    -- Gezaehlt wird gegen die Beutel, nicht gegen eine Liste: die Frage
    -- ist, was JETZT fehlt, nicht was einmal auf einem Zettel stand.
    local rows = ns.List.Build(ns.Gear.Scan())
    local missing = ns.List.BuyCount(rows)
    if missing > 0 then
        -- Auch hier ein Weg hinein, statt "mach mal /mc".
        ns.Print(L["AH_OFFER"]:format(missing)
            .. "  " .. Remind.AddonLink("list", L["REMIND_OPEN_LIST"]))
    end
end)
