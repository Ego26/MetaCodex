-- Startet den Ablauf. Laedt als letzte Datei.

local ADDON, ns = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("SOCKET_INFO_CLOSE")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

-- Ein Auffrischen je Ereignis waere Verschwendung: beim Anlegen einer
-- Ruestung kommen Dutzende GET_ITEM_INFO_RECEIVED hintereinander. Gesammelt
-- wird deshalb auf den naechsten Rahmen.
local pending = false
local function requestRefresh()
    if pending or not ns.UI.IsShown() then return end
    pending = true
    C_Timer.After(0.1, function()
        pending = false
        ns.UI.Refresh()
    end)
end

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- Bewusst NICHT die Daten laden: sie liegen im nachladbaren
        -- MetaCodex_Data und werden beim ersten Oeffnen des Fensters
        -- geholt. Beim Login zu parsen, was die meisten Spieler an dem
        -- Abend nie oeffnen, ist genau die Ladezeit, die Addons
        -- verrufen macht.
        ns.Profile.Init()
        -- Der Knopf im Charakterfenster: das Fenster gibt es ab jetzt.
        ns.UI.AttachCharacterButton()
    else
        requestRefresh()
    end
end)

-- Knopf in der Addon-Leiste der Minimap.
function MetaCodex_OnCompartmentClick()
    ns.UI.Toggle()
end
