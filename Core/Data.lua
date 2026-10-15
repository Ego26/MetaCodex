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
    -- ABGESCHALTET IST KEIN ZUSTAND, DEN JEMAND WILL.
    --
    -- Ohne den Datenordner ist MetaCodex ein leeres Fenster. Wer ihn in
    -- der Addon-Liste abgehakt hat, hat das kaum mit Absicht getan - also
    -- wird er fuer diesen Charakter wieder eingeschaltet und noch einmal
    -- geladen. Gemeldet am 15. Oktober von einem Spieler, der nach der
    -- Erstinstallation nur eine Entwicklermeldung sah.
    if not loaded and reason == "DISABLED" and type(C_AddOns.EnableAddOn) == "function" then
        local wer = UnitName and UnitName("player")
        pcall(C_AddOns.EnableAddOn, ns.DATA_ADDON, wer)
        loaded, reason = C_AddOns.LoadAddOn(ns.DATA_ADDON)
    end
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

---Was der Spieler tun kann, wenn die Daten nicht da sind.
---
---Die alte Meldung nannte ein Skript ("Run tools/build-catalog.js") -
---eine Auskunft fuer den, der das Addon baut, nicht fuer den, der es
---spielt. Jetzt je Grund ein Satz, der sagt, was zu tun ist.
---@return string
function Data.Message()
    local L = ns.L
    local grund = type(state) == "string" and state or nil
    if grund == "MISSING" then return L["NO_DATA_MISSING"] end
    if grund == "DISABLED" then return L["NO_DATA_DISABLED"] end
    if grund == "INTERFACE_VERSION" then return L["NO_DATA_OUTDATED"] end
    return L["NO_DATA_OTHER"]:format(grund or "EMPTY")
end

---Vergisst den letzten Versuch - fuer die Pruefung.
function Data.Forget()
    state = nil
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
