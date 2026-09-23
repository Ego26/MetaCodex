-- Der Adapter. Die EINZIGE Stelle, die Auctionator kennt.
--
-- Zwei Dinge sind an dieser Schnittstelle wichtig und begruenden fast alles,
-- was hier steht:
--
--   1. CreateShoppingList ERSETZT eine Liste vollstaendig. Es gibt kein
--      Anhaengen. Wer den Namen einer fremden Liste traefe, loeschte sie.
--      Deshalb schreibt MetaCodex nur in Listen mit eigenem Praefix.
--   2. Die API ist veroeffentlicht, aber nicht vertraglich. Jeder Aufruf
--      laeuft durch pcall, und was fehlt, wird gemeldet statt geworfen.

local _, ns = ...

local Adapter = {}
ns.Adapter = Adapter

local function api()
    local atr = _G.Auctionator
    return atr and atr.API and atr.API.v1 or nil
end

---@return boolean
function Adapter.Loaded()
    return C_AddOns.IsAddOnLoaded(ns.AUCTIONATOR_ADDON) == true
end

---@param name string
---@return boolean
function Adapter.Has(name)
    local v1 = api()
    return v1 ~= nil and type(v1[name]) == "function"
end

---Der Name der Liste, in die geschrieben wird. Immer mit Praefix.
---@param section string|nil Abschnitt, dessen Liste es ist
---@return string
function Adapter.ListName(section)
    local _, specName = ns.Compat.CurrentSpec()
    local name = ns.LIST_PREFIX .. (specName or UnitName("player") or "?")
    -- Verzauberungen und Verbrauchsgueter sind zwei Listen. Mit EINEM
    -- Namen ueberschrieb die zweite die erste - CreateShoppingList
    -- ersetzt, es haengt nicht an.
    if section then name = name .. " - " .. (ns.L["SECTION_" .. section] or section) end
    return name
end

---Aus den Zeilen die Suchbegriffe. Gesucht wird ueber den Namen, den der
---Client geliefert hat - deshalb stimmt er auf jedem Sprachclient.
---
---Gebaut wird der Begriff ueber ConvertToSearchString: Auctionators eigene
---Umwandlung kennt das Format ihrer Suchzeichenkette, und die hat mehr
---Felder als den Namen. Eines davon ist `quantity` - damit steht die
---benoetigte Stueckzahl in der Liste und nicht nur im Kopf des Spielers.
---Welche Zeilen ins Auktionshaus gehen.
---
---Das ist alles, was auf dem Schirm steht - nicht nur, was fehlt. Wer die
---Vollansicht offen hat, will die Preise auch dann sehen, wenn schon alles
---drauf ist; vorher meldete der Knopf dann "nichts zu kaufen" und tat
---nichts. Die Stueckzahl haengt weiter am Fehlbestand: null Fehlende
---heisst kein `quantity`, nicht kein Eintrag.
---@param rows table[]
---@return table[] usable
---@return number missingNames
local function shoppable(rows)
    local out, missing = {}, 0
    for _, row in ipairs(rows) do
        -- Ausruestung faellt heraus, ausser sie ist hergestellt. Ein
        -- Schlachtzugsbeuteteil im Auktionshaus zu suchen liefert keine
        -- Treffer, sondern nur den Eindruck, die Liste sei kaputt.
        local droppedGear = row.kind == "gear" and row.badge ~= "craft"
        -- Alternativen gehoeren nicht auf den Zettel: man kauft EINE
        -- davon, nicht alle drei.
        if row.alt then droppedGear = true end
        if row.id and not row.pending and not droppedGear then
            if row.name then out[#out + 1] = row else missing = missing + 1 end
        end
    end
    return out, missing
end

---@param rows table[]
---@return string[] terms
---@return number missingNames
local function terms(rows)
    local v1 = api()
    local usable, missing = shoppable(rows)
    local out = {}
    for _, row in ipairs(usable) do
        if v1 and type(v1.ConvertToSearchString) == "function" then
            local ok, text = pcall(v1.ConvertToSearchString, ns.addonName, {
                searchString = row.name,
                isExact = true,
                quantity = (row.buy or 0) > 0 and row.buy or nil,
            })
            -- Schlaegt die Umwandlung fehl, ist der blosse Name in
            -- Anfuehrungszeichen immer noch eine gueltige exakte Suche.
            out[#out + 1] = (ok and type(text) == "string") and text
                or ('"' .. row.name .. '"')
        else
            out[#out + 1] = '"' .. row.name .. '"'
        end
    end
    return out, missing
end

---Die blossen Gegenstandsnamen, fuer die Suchfunktionen.
---@param rows table[]
---@return string[] names
---@return number missingNames
local function plainNames(rows)
    local usable, missing = shoppable(rows)
    local out = {}
    for i, row in ipairs(usable) do out[i] = row.name end
    return out, missing
end

---Schreibt die Einkaufsliste.
---@param rows table[]
---@param section string|nil Abschnitt, dessen Liste es ist
---@return boolean ok
---@return string|number message Listenname bei Erfolg, sonst der Fehler
---@return number written
function Adapter.CreateList(rows, section)
    local v1 = api()
    if not v1 then return false, "Auctionator.API.v1", 0 end
    if not Adapter.Has("CreateShoppingList") then
        return false, "CreateShoppingList", 0
    end

    local searchTerms, missing = terms(rows)
    if missing > 0 then return false, "NAMES_PENDING", 0 end
    if #searchTerms == 0 then return false, "NOTHING_TO_BUY", 0 end

    local name = Adapter.ListName(section)
    local ok, err = pcall(v1.CreateShoppingList, ns.addonName, name, searchTerms)
    if not ok then return false, tostring(err), 0 end
    return true, name, #searchTerms
end

---Steht das Auktionshaus offen?
---
---Auctionators Suche setzt es voraus und wirft sonst einen Fehler aus
---seinem eigenen Inneren - "Contact the maintainer of MetaCodex", was der
---Spieler zu Recht als unseren Fehler liest. Er hat recht: gefragt haben
---wir, ohne nachzusehen.
---@return boolean
function Adapter.AuctionHouseOpen()
    if AuctionHouseFrame and AuctionHouseFrame:IsShown() then return true end
    -- Das klassische Fenster gibt es auf manchen Clients noch.
    if AuctionFrame and AuctionFrame:IsShown() then return true end
    return false
end

---Sucht sofort, ohne eine Liste anzulegen.
---
---Welche der beiden Suchfunktionen ein Auctionator mitbringt, unterscheidet
---sich zwischen den Fassungen. Geprueft wird deshalb, was da ist - geraten
---wird nichts.
---@param rows table[]
---@return boolean ok
---@return string message
function Adapter.Search(rows)
    local v1 = api()
    if not v1 then return false, "Auctionator.API.v1" end
    if not Adapter.AuctionHouseOpen() then return false, "AH_CLOSED" end

    local searchTerms, missing = plainNames(rows)
    if missing > 0 then return false, "NAMES_PENDING" end
    if #searchTerms == 0 then return false, "NOTHING_TO_BUY" end

    -- MultiSearchExact setzt die Anfuehrungszeichen selbst und will deshalb
    -- die blossen Namen - NICHT die fertigen Suchzeichenketten von oben.
    if Adapter.Has("MultiSearchExact") then
        local ok, err = pcall(v1.MultiSearchExact, ns.addonName, searchTerms)
        if ok then return true, "" end
        return false, tostring(err)
    end

    if Adapter.Has("MultiSearch") then
        local quoted = {}
        for i, name in ipairs(searchTerms) do quoted[i] = '"' .. name .. '"' end
        local ok, err = pcall(v1.MultiSearch, ns.addonName, quoted)
        if ok then return true, "" end
        return false, tostring(err)
    end

    return false, "MultiSearch"
end
