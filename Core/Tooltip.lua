-- Was MetaCodex weiss, dort hinschreiben, wo man das Item anfasst.
--
-- Ein Spieler haelt im Auktionshaus einen Handschuh in der Hand und will
-- eine Antwort auf zwei Fragen, ohne erst ein Fenster zu oeffnen:
-- Sind das die richtigen Zweitwerte fuer mich? Und ist das ueberhaupt
-- das Teil, das die Besten auf diesem Platz tragen?
--
-- Beides steht in den Daten, die das Addon ohnehin mitbringt. Hier wird
-- es an den Tooltip gehaengt: die Rangnummer direkt an die Wertzeile,
-- und darunter eine Zeile zum Platz in der Liste.
--
-- Gefragt wird nach der AKTIVEN Spec, nicht nach der, die das Fenster
-- gerade zeigt. Wer in der Tasche vergleicht, vergleicht fuer den
-- Charakter, auf dem er steht. Die Aktivitaet kommt dagegen aus dem
-- Fenster, denn zwischen Schluesselstein und Schlachtzug unterscheidet
-- sich die Rangfolge.

local _, ns = ...
local L = ns.L

local Tooltip = {}
ns.Tooltip = Tooltip

-- Unsere Schluessel und die Namen, unter denen der Client dieselben
-- Werte fuehrt. GetItemStats gibt eine Tabelle mit genau diesen
-- Schluesseln zurueck.
local MOD = {
    crit    = "ITEM_MOD_CRIT_RATING_SHORT",
    haste   = "ITEM_MOD_HASTE_RATING_SHORT",
    mastery = "ITEM_MOD_MASTERY_RATING_SHORT",
    vers    = "ITEM_MOD_VERSATILITY",
}

---Die Rangfolge der Zweitwerte fuer den Charakter, auf dem man steht.
---@return table|nil rank  { crit = 1, haste = 2, ... }
local function priorityRanks()
    local spec = ns.Compat.CurrentSpec() or ns.Profile.SelectedSpec()
    if not spec then return nil end
    local stats = ns.Recommend.Stats(spec, ns.Profile.Mode(), ns.Recommend.ALL)
    if not stats or not stats.priority then return nil end
    local rank = {}
    for i, key in ipairs(stats.priority) do rank[key] = i end
    return rank
end

---Welche Raenge gelten fuer DIESES Item?
---
---Nur die Werte, die es wirklich traegt. Ein Rang fuer einen Wert, der
---nicht draufsteht, waere eine Zahl ohne Gegenstueck.
---@param link string
---@return table|nil { haste = 2, mastery = 4 }
function Tooltip.StatRanks(link)
    if not link then return nil end
    local stats = ns.Compat.ItemStats(link)
    if not stats then return nil end
    local rank = priorityRanks()
    if not rank then return nil end
    local out, any = {}, false
    for _, key in ipairs(ns.SECONDARY) do
        local value = stats[MOD[key]]
        if rank[key] and type(value) == "number" and value > 0 then
            out[key] = rank[key]
            any = true
        end
    end
    return any and out or nil
end

---Wo steht dieses Item in der Liste seines Platzes?
---
---Platz eins ist das, was die meisten der gemessenen Spieler tragen -
---das, was andere "BiS" nennen. Die Zahl dahinter ist der Anteil, und
---sie gehoert dazu: "Platz 1 mit 92 %" ist etwas anderes als
---"Platz 1 mit 21 %".
---@param itemID number
---@return number|nil rank, number|nil pct, number|nil ofHowMany
function Tooltip.GearRank(itemID)
    if not itemID then return nil end
    local spec = ns.Compat.CurrentSpec() or ns.Profile.SelectedSpec()
    if not spec then return nil end
    local gear = ns.Recommend.Gear(spec, ns.Profile.Mode(), ns.Recommend.ALL)
    if not gear then return nil end
    for _, list in pairs(gear) do
        for i, row in ipairs(list) do
            if row.id == itemID then return i, row.pct, #list end
        end
    end
    return nil
end

-- --------------------------------------------------------------- Anhaengen

---Die Beschriftungen, unter denen die Werte im Tooltip stehen.
---
---Vom Client, nicht von uns: auf einem deutschen Spiel steht dort
---"Tempo", auf einem franzoesischen etwas anderes. Sortiert wird nach
---Laenge, absteigend - "Tempo" steckt in "Tempolauf", und wer kurz
---zuerst sucht, haengt die Zahl an den falschen Wert.
local function labels()
    local out = {}
    for _, key in ipairs(ns.SECONDARY) do
        local text = _G[MOD[key]]
        if type(text) == "string" and text ~= "" then
            out[#out + 1] = { key = key, text = text }
        end
    end
    table.sort(out, function(a, b) return #a.text > #b.text end)
    return out
end

---Haengt die Rangnummern an die Wertzeilen des Tooltips.
---@param tip table
---@param ranks table
local function markStats(tip, ranks)
    local name = tip.GetName and tip:GetName()
    if not name or not tip.NumLines then return 0 end
    local order = labels()
    local marked = 0
    for i = 2, tip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        local text = line and line.GetText and line:GetText()
        -- Eine Wertzeile faengt mit ihrer Zahl an: "+56 Meisterschaft".
        -- Ein Satz, in dem "Tempo" vorkommt - ein Set-Bonus, ein
        -- Anlegeeffekt -, ist keine, und dort haette die Nummer nichts
        -- zu suchen.
        local isStatLine = type(text) == "string" and text:find("^%+?[%d%.,%s]+%a") ~= nil
        if isStatLine and not text:find("|cff", 1, true) then
            for _, entry in ipairs(order) do
                if ranks[entry.key] and text:find(entry.text, 1, true) then
                    -- Hausfarbe, nicht Klassenfarbe: die Nummer soll
                    -- erkennbar von hier kommen, und der Akzent wandert
                    -- mit der angesehenen Klasse.
                    line:SetText(text .. "  |cff" .. ns.Style:Hex("brand")
                        .. "#" .. ranks[entry.key] .. "|r")
                    ranks[entry.key] = nil
                    marked = marked + 1
                    break
                end
            end
        end
    end
    return marked
end

---Der ganze Anbau an einen Gegenstands-Tooltip.
---@param tip table
---@param link string|nil
function Tooltip.Decorate(tip, link)
    if not ns.Profile.TooltipOn() then return end
    if not link then return end
    -- Erst laden, dann fragen - nicht umgekehrt.
    --
    -- Hier stand die Bereitschaftspruefung VOR dem Laden, und die kann
    -- vor dem Laden gar nicht wahr sein: die Tabellen liegen im
    -- nachladbaren Addon. Wer nie das Fenster oeffnete, sah deshalb nie
    -- eine Zahl im Tooltip - die Zeile stieg immer vorher aus. Das
    -- Fenster einmal aufmachen zu muessen, damit ein Tooltip etwas
    -- sagt, waere eine Zumutung.
    --
    -- Im Kampf wird allerdings nicht geladen: die Tabellen sind
    -- Megabytes, ihr Einlesen kostet einen Moment, und der gehoert
    -- nicht in einen Pull. Wer waehrend des Kampfes ueber ein Item
    -- faehrt, sieht dann eben nichts - nach dem Kampf holt es der
    -- naechste Tooltip nach.
    if not ns.Recommend.Ready() then
        if InCombatLockdown and InCombatLockdown() then return end
        if not ns.Data.Ensure() then return end
    end

    local itemID = tonumber(link:match("item:(%d+)"))

    -- Markiert wird, was im Tooltip STEHT - nicht, was die
    -- Gegenstandsschnittstelle zum Link zu sagen hat.
    --
    -- Der Unterschied ist kein Feinschliff. Ein Handwerksstueck traegt
    -- seine Zweitwerte ueber Bonus-IDs; fragt man den nackten Link,
    -- antwortet das Spiel mit "Zufallswert 1" und "Zufallswert 2", und
    -- die Rangnummern fielen genau dort weg, wo der Spieler sie sieht.
    -- Dasselbe beim Vergleichstooltip, dessen Link wir nicht kennen.
    -- Im Tooltip dagegen steht, was das Stueck wirklich hat - und die
    -- Reihenfolge der Werte haengt ohnehin an der Spec, nicht am
    -- Gegenstand.
    local marked = 0
    local all = priorityRanks()
    if all then marked = markStats(tip, all) end

    -- Fuer die Ersatzzeile weiter unten zaehlt weiter, was das Item
    -- laut Schnittstelle traegt: dort sollen nicht vier Werte stehen,
    -- wenn es zwei hat.
    local ranks = Tooltip.StatRanks(link)

    -- Keine Wertzeile getroffen, aber Raenge vorhanden?
    --
    -- Die Beschriftungen kommen vom Client, und wenn eine davon anders
    -- lautet als im Tooltip, faende die Suche nichts. Dann stehen die
    -- Raenge eben in einer eigenen Zeile - lieber so als gar nicht.
    local spare
    if ranks and marked == 0 then
        local parts = {}
        for _, key in ipairs(ns.SECONDARY) do
            if ranks[key] then
                parts[#parts + 1] = L["STAT_" .. key] .. " #" .. ranks[key]
            end
        end
        if #parts > 0 then spare = table.concat(parts, "  ") end
    end

    local rank, pct, total = Tooltip.GearRank(itemID)
    if rank then
        local text
        if rank == 1 then
            text = L["TIP_TOP"]:format(pct or 0)
        else
            text = L["TIP_RANK"]:format(rank, total or rank, pct or 0)
        end
        tip:AddLine("|cff" .. ns.Style:Hex("brand") .. "MetaCodex|r  " .. text, 1, 1, 1)
    end
    -- Wo das Item NICHT in der Liste steht, kommt auch keine Zeile
    -- dazu.
    --
    -- Hier stand ein Satz, der die Rangnummern erklaerte, und der stand
    -- dann unter jedem Gruenzeug, das man je anfasst. Einmal gelesen
    -- ist er verstanden, danach ist er Laerm. Die Nummern tragen die
    -- Hausfarbe, das genuegt als Absender.
    if spare then
        tip:AddLine("|cff" .. ns.Style:Hex("brand") .. "MetaCodex|r  " .. spare, 1, 1, 1)
    end
end

-- ------------------------------------------------------------------ Haken

-- Zwei Wege, denselben Anbau zu machen.
--
-- Der neue Client reicht Tooltips durch TooltipDataProcessor; der alte
-- feuert OnTooltipSetItem. Es wird genommen, was da ist - und nur eines
-- von beiden, sonst stuende die Zeile zweimal da.
local hooked = false
---Welcher Gegenstand steht in diesem Tooltip?
---
---GetItem beantwortet das fuer den Tooltip unter dem Zeiger. Fuer die
---VERGLEICHS-Tooltips daneben antwortet es nicht: die werden nicht
---"gesetzt", sondern mit Daten gefuellt, und deshalb standen die
---Rangnummern nur am angefassten Stueck und nicht an dem, das man
---anhat - also genau dort nicht, wo verglichen wird.
---
---Die Daten des Tooltips kennen den Gegenstand aber. Sie sind der
---zweite Weg.
---@param tip table
---@param data table|nil
---@return string|nil
local function linkOf(tip, data)
    if tip and tip.GetItem then
        local ok, _, link = pcall(tip.GetItem, tip)
        if ok and type(link) == "string" and link ~= "" then return link end
    end
    if data then
        if type(data.hyperlink) == "string" and data.hyperlink ~= "" then
            return data.hyperlink
        end
        if data.id then return "item:" .. data.id end
    end
    return nil
end

function Tooltip.Hook()
    if hooked then return end
    hooked = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,
            function(tip, data)
                local link = linkOf(tip, data)
                if link then pcall(Tooltip.Decorate, tip, link) end
            end)
    elseif GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetItem", function(tip)
            local link = linkOf(tip, nil)
            if link then pcall(Tooltip.Decorate, tip, link) end
        end)
        -- Die beiden Vergleichsfenster des alten Clients haben eigene
        -- Haken; ohne sie bliebe die Zahl dort aus.
        for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do
            local shop = _G[name]
            if shop and shop.HookScript then
                shop:HookScript("OnTooltipSetItem", function(tip)
                    local link = linkOf(tip, nil)
                    if link then pcall(Tooltip.Decorate, tip, link) end
                end)
            end
        end
    end
end
