-- Startet den Ablauf. Laedt als letzte Datei.

local ADDON, ns = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("SOCKET_INFO_CLOSE")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
-- Auch das: es meldet den Wechsel am Spieler, wenn das andere Ereignis
-- nur den Platz nennt.
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")

-- Ein Auffrischen je Ereignis waere Verschwendung: beim Anlegen einer
-- Ruestung kommen Dutzende GET_ITEM_INFO_RECEIVED hintereinander.
--
-- Gewartet wird bis zum LETZTEN davon, nicht bis 0,1 Sekunden nach dem
-- ersten. Das war der Unterschied zwischen "bereits drauf" und der
-- Wahrheit: wer ein Stueck tauschte, bekam die Antwort auf den Stand von
-- vor dem Tausch, weil der Client zum Zeitpunkt des ersten Ereignisses
-- noch das alte Stueck fuehrte.
local pendingTimer
local function requestRefresh()
    if not ns.UI.IsShown() then return end
    if pendingTimer and pendingTimer.Cancel then pendingTimer:Cancel() end
    if C_Timer.NewTimer then
        pendingTimer = C_Timer.NewTimer(0.2, function()
            pendingTimer = nil
            ns.UI.Refresh()
        end)
    else
        C_Timer.After(0.2, function() ns.UI.Refresh() end)
    end
end

---Laedt die Tabellen still, wenn gerade nichts los ist.
---
---Nicht im Kampf: das Einlesen kostet einen Moment, und der gehoert
---nicht in einen Pull. Klappt es nicht, wird es spaeter noch einmal
---versucht - hoechstens dreimal, danach holt es der erste Tooltip.
local warmTries = 0
local function warmUp()
    if not ns.Profile.TooltipOn() then return end
    if ns.Recommend.Ready() then return end
    warmTries = warmTries + 1
    if warmTries > 3 then return end
    if InCombatLockdown and InCombatLockdown() then
        C_Timer.After(30, warmUp)
        return
    end
    ns.Data.Ensure()
end

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        -- Bewusst NICHT die Daten laden: sie liegen im nachladbaren
        -- MetaCodex_Data und werden beim ersten Oeffnen des Fensters
        -- geholt. Beim Login zu parsen, was die meisten Spieler an dem
        -- Abend nie oeffnen, ist genau die Ladezeit, die Addons
        -- verrufen macht.
        ns.Profile.Init()
        -- Die beiden Knoepfe: das Charakterfenster und die Minimap gibt
        -- es ab jetzt, und beide sind ab Werk an.
        ns.UI.UpdateCharacterButton()
        ns.Minimap.Update()
        -- Und der Anbau an die Gegenstands-Tooltips.
        ns.Tooltip.Hook()
        -- Ein ruhiger Start, wenn der Tooltip etwas sagen soll.
        --
        -- Die Tabellen liegen im nachladbaren Addon, und wer sie beim
        -- Anmelden einliest, zahlt Ladezeit fuer etwas, das er
        -- vielleicht nie braucht. Beim Tooltip sieht das anders aus: ihn
        -- trifft man unweigerlich, und dann ruckelt es genau in dem
        -- Moment, in dem man ueber ein Item faehrt. Also wird ein paar
        -- Sekunden nach dem Anmelden im Leerlauf geladen, ausserhalb des
        -- Kampfes - und nur dann, wenn der Anbau ueberhaupt an ist. Wer
        -- ihn abschaltet, zahlt weiterhin nichts.
        C_Timer.After(15, warmUp)
    else
        requestRefresh()
    end
end)

-- Klick auf den Link in der Chatzeile.
--
-- Blizzard ruft SetItemRef fuer jeden Link im Chat; eigene Linktypen
-- stehen unter "addon:". Gehakt statt ersetzt - andere Addons haengen
-- an derselben Funktion.
if hooksecurefunc then
    hooksecurefunc("SetItemRef", function(link)
        local what = tostring(link or ""):match("^addon:MetaCodex:(.+)$")
        if not what then return end
        if what == "remind" then
            ns.UI.OpenSection("remind")
        elseif what == "list" then
            ns.UI.OpenSection("consumables")
        else
            ns.UI.Toggle()
        end
    end)
end

-- Knopf in der Addon-Leiste der Minimap.
function MetaCodex_OnCompartmentClick()
    ns.UI.Toggle()
end
