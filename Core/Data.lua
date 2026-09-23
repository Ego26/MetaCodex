-- Laedt die Datentabellen nach.
--
-- Katalog und Empfehlungen sind zusammen fast ein Megabyte Lua-Quelltext.
-- Beim Login geparst kostet das Ladezeit fuer etwas, das die meisten
-- Spieler einmal am Abend oeffnen - und mit Talenten je Dungeon wird es
-- ein Vielfaches. Deshalb liegen sie im nachladbaren Addon
-- MetaCodex_Data, und hier steht der eine Griff, der es holt.
--
-- Jeder Einstieg, der Daten braucht, ruft Ensure() auf: das Fenster, die
-- Sonde, das Vorladen der Namen. Der Aufruf ist billig, sobald es einmal
-- geklappt hat.

local _, ns = ...

local Data = {}
ns.Data = Data

ns.DATA_ADDON = "MetaCodex_Data"

local state  -- nil = nicht versucht, true = geladen, string = Fehlergrund

---Laedt das Datenaddon, wenn noetig.
---@return boolean ok
---@return string|nil reason
function Data.Ensure()
    if state == true then return true end
    if type(state) == "string" then return false, state end

    if C_AddOns.IsAddOnLoaded(ns.DATA_ADDON) then
        state = true
        return true
    end

    local loaded, reason = C_AddOns.LoadAddOn(ns.DATA_ADDON)
    if loaded then
        state = true
        return true
    end

    -- Der Grund wird gemerkt und gemeldet, statt es bei jedem Klick erneut
    -- zu versuchen. Ein fehlendes Addon wird nicht dadurch da, dass man
    -- hundertmal fragt.
    state = reason or "MISSING"
    return false, state
end

---Ob die Daten bereits im Speicher sind, ohne sie zu laden.
---@return boolean
function Data.Loaded()
    return state == true
end

ns.DUNGEON_ADDON = "MetaCodex_Dungeons"

local dungeonState

---Laedt die Auswertung je Dungeon.
---
---Ein eigenes Addon, weil es fast so viel wiegt wie alles uebrige und die
---meisten nie einen einzelnen Dungeon waehlen. Fehlt es, faellt nur die
---Dungeon-Auswahl weg - nicht das Addon.
---@return boolean ok
function Data.EnsureDungeons()
    if dungeonState == true then return true end
    if dungeonState == false then return false end

    if C_AddOns.IsAddOnLoaded(ns.DUNGEON_ADDON) then
        dungeonState = true
        return true
    end
    local loaded = C_AddOns.LoadAddOn(ns.DUNGEON_ADDON)
    dungeonState = loaded and true or false
    return dungeonState
end

---@return boolean
function Data.DungeonsLoaded()
    return dungeonState == true
end
