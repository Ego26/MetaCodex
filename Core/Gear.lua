-- Was am Charakter haengt: welcher Platz noch unverzaubert ist und wie
-- viele Sockel leer sind.
--
-- Das ist der Unterschied zwischen einem Guide und einem Werkzeug. Ein
-- Guide sagt, was draufgehoert. Hier steht, was tatsaechlich fehlt.

local _, ns = ...

local Gear = {}
ns.Gear = Gear

-- Ein Gegenstandslink traegt seine Verzauberung und seine Steine im
-- Itemstring: item:ID:VERZAUBERUNG:STEIN1:STEIN2:STEIN3:STEIN4:...
local LINK_PATTERN = "item:(%d+):(%d*):(%d*):(%d*):(%d*):(%d*)"

---Zerlegt einen Gegenstandslink.
---@param link string|nil
---@return number|nil itemID
---@return boolean enchanted
---@return number gemsFilled
---@return number[] gems  die IDs der gesockelten Steine
local function parseLink(link)
    if not link then return nil, false, 0, {} end
    local itemID, ench, g1, g2, g3, g4 = link:match(LINK_PATTERN)
    if not itemID then return nil, false, 0, {} end
    local filled, gems = 0, {}
    for _, gem in ipairs({ g1, g2, g3, g4 }) do
        if gem and gem ~= "" and gem ~= "0" then
            filled = filled + 1
            gems[#gems + 1] = tonumber(gem)
        end
    end
    local enchID = tonumber(ench)
    if enchID == 0 then enchID = nil end
    return tonumber(itemID), enchID ~= nil, filled, gems, enchID
end

---Wie viele Sockel ein Gegenstand insgesamt hat.
---
---GetItemStats meldet Sockel als EMPTY_SOCKET_*, und zwar unabhaengig
---davon, ob schon ein Stein drinsteckt - es ist also die Gesamtzahl. Was
---belegt ist, steht im Link. Die Differenz sind die leeren.
---@param link string
---@return number
local function socketCount(link)
    local stats = ns.Compat.ItemStats(link)
    if not stats then
        -- Der Client kennt das Stueck noch nicht - frisch angelegt,
        -- gerade erst gesockelt. Dann liefert er keine Sockel, und
        -- ohne Nachfrage bliebe die Zeile auf diesem Stand stehen:
        -- "0 Sockel" und damit "bereits drauf", obwohl niemand das
        -- geprueft hat. Also anfordern - sein GET_ITEM_INFO_RECEIVED
        -- laesst das Fenster gleich noch einmal rechnen.
        local id = tonumber(tostring(link):match("item:(%d+)"))
        if id and ns.Compat.RequestItem then ns.Compat.RequestItem(id) end
        return 0
    end
    local total = 0
    for key, value in pairs(stats) do
        if type(key) == "string" and key:find("EMPTY_SOCKET", 1, true) then
            total = total + (tonumber(value) or 0)
        end
    end
    return total
end

-- Nebenhand: verzaubert wird nur, was eine Waffe ist. Ein Schild oder ein
-- Zauberbuch traegt in dieser Erweiterung keine Waffenverzauberung, und es
-- auf die Liste zu setzen waere ein verschwendeter Kauf.
local OFFHAND_OK = {
    INVTYPE_WEAPON = true,
    INVTYPE_WEAPONOFFHAND = true,
}

local function offhandEnchantable(link)
    if not link then return false end
    local getInstant = C_Item and C_Item.GetItemInfoInstant
    if not getInstant then return false end
    local ok, _, _, _, equipLoc = pcall(getInstant, link)
    if not ok then return false end
    return OFFHAND_OK[equipLoc] == true
end

---Liest die Ausruestung.
---Die Rune, die auf der Waffe sitzt, wenn eine sitzt.
---@param scan table
---@return number|nil spellID
function Gear.Runeforge(scan)
    for _, entry in ipairs(scan.slots or {}) do
        if entry.slot == "weapon" then
            local spell = ns.Catalog.RuneforgeSpell(entry.enchantID)
            if spell then return spell end
        end
    end
    return nil
end

---@return table scan
function Gear.Scan()
    local slots, seen = {}, {}
    for _, def in ipairs(ns.SLOTS) do
        local link = GetInventoryItemLink("player", def.inv)
        local include = link ~= nil
        if include and def.inv == INVSLOT_OFFHAND then
            include = offhandEnchantable(link)
        end
        if include then
            local itemID, enchanted, _, _, enchantID = parseLink(link)
            slots[#slots + 1] = {
                slot = def.slot,
                inv = def.inv,
                link = link,
                itemID = itemID,
                enchanted = enchanted,
                -- WELCHE Verzauberung, nicht nur OB eine.
                enchantID = enchantID,
            }
            seen[def.slot] = true
        end
    end

    -- Leere UND vorhandene Sockel zaehlen. Die leeren sind der Bedarf; die
    -- gesamten braucht die Anzeige, wenn sie nicht nur das Fehlende zeigt,
    -- sondern die vollstaendige Ausstattung.
    local empty, total = 0, 0
    -- Und WELCHE Steine stecken: der besondere Sockel fragt danach.
    -- "1 leer" bei einem Hals, in dem der Diamant laengst sitzt, war
    -- die Folge, ihn nur zu zaehlen statt anzusehen.
    local socketed = {}
    for _, inv in ipairs(ns.SOCKETABLE) do
        local link = GetInventoryItemLink("player", inv)
        if link then
            local _, _, filled, gems = parseLink(link)
            local count = socketCount(link)
            total = total + count
            if count > filled then empty = empty + (count - filled) end
            for _, gem in ipairs(gems) do socketed[gem] = (socketed[gem] or 0) + 1 end
        end
    end

    return { slots = slots, emptySockets = empty, totalSockets = total, gems = socketed }
end

---Wie viele Sockel NICHT den empfohlenen Stein tragen.
---
---Dieselbe Regel wie bei den Verzauberungen, und aus demselben Grund:
---ein Sockel ist fertig, wenn DER empfohlene Stein drinsitzt - nicht,
---wenn irgendeiner drinsitzt. Gezaehlt wurden bisher nur die leeren,
---und deshalb stand "bereits drauf" auch dann da, wenn in den Sockeln
---etwas ganz anderes sass.
---
---Gelesen wird am angelegten Gegenstand, bei jedem Mal neu: was der
---Charakter JETZT traegt, ist die Antwort.
---@param scan table
---@param wanted number|nil Gegenstands-ID des empfohlenen Steins
---@param same number[]|nil andere Qualitaetsstufen desselben Steins
---@param isMeta fun(id: number): boolean|nil Steine des besonderen Sockels
---@return number missing
---@return number total
---@return number|nil other  der Stein, der stattdessen drinsitzt
function Gear.GemsMissing(scan, wanted, same, isMeta)
    local total = scan.totalSockets or 0
    local empty = scan.emptySockets or 0
    if not wanted then return empty, total, nil end

    local ok = { [wanted] = true }
    for _, id in ipairs(same or {}) do ok[id] = true end

    local wrong, other, most = 0, nil, 0
    for gem, count in pairs(scan.gems or {}) do
        -- Ein Stein des besonderen Sockels gehoert nicht hierher: er hat
        -- seine eigene Zeile, und zweimal gezaehlt waere er zweimal zu
        -- kaufen.
        if not ok[gem] and not (isMeta and isMeta(gem)) then
            wrong = wrong + count
            if count > most then other, most = gem, count end
        end
    end
    -- Leer und anders belegt getrennt zurueck.
    --
    -- Zusammengezaehlt heissen beide "fehlt", und das stimmt fuer den
    -- Einkauf: ein Sockel mit dem falschen Stein braucht denselben Kauf
    -- wie ein leerer. Fuer den SATZ daneben stimmt es nicht - der nannte
    -- einen belegten Sockel "leer".
    return empty + wrong, total, other, empty
end

---Wie viele Plaetze eines Katalogschluessels noch unverzaubert sind.
---@param scan table
---@param slot string
---@return number missing
---@return number total
---@param scan table
---@param slot string
---@param wanted number|nil Gegenstand, der drauf soll
---@return number missing
---@return number total
---@return number|nil other Gegenstand der fremden Verzauberung, wenn eine drauf ist
function Gear.Missing(scan, slot, wanted)
    local missing, total, other = 0, 0, nil
    for _, entry in ipairs(scan.slots) do
        if entry.slot == slot then
            total = total + 1
            if not entry.enchanted then
                missing = missing + 1
            elseif wanted and not ns.Catalog.RuneforgeSpell(entry.enchantID) then
                -- Eine Verzauberung ist drauf - aber ist es die richtige?
                -- Verglichen wird ueber den Gegenstand, denn der steht im
                -- Katalog; im Link steht nur die Zauberkennung.
                --
                -- Eine Runenschmiede ist ausgenommen: sie IST die
                -- Waffenverzauberung des Todesritters, nur gibt es zu ihr
                -- keinen Gegenstand, mit dem man sie vergleichen koennte.
                local onIt = ns.Catalog.EnchantItemOf(entry.enchantID)
                if onIt and onIt ~= wanted then
                    missing = missing + 1
                    other = onIt
                end
            end
        end
    end
    return missing, total, other
end
