-- /mc

local _, ns = ...

local L = ns.L

local function help()
    ns.Print(L["SLASH_HELP"])
    ns.Print("  " .. L["SLASH_OPEN"])
    ns.Print("  " .. L["SLASH_PROBE"])
    ns.Print("  " .. L["SLASH_LANG"])
    ns.Print("  " .. L["SLASH_REMIND"])
    ns.Print("  " .. L["SLASH_SCALE"])
    ns.Print("  " .. L["SLASH_RESET"])
end

local handlers = {
    probe = function() ns.Probe.Run() end,
    help = help,
    reset = function()
        ns.Profile.Reset()
        ns.Print(L["RESET_DONE"])
        ns.UI.Refresh()
    end,
    -- Ein- und Ausschalten statt einer Zahl: wer die Erinnerung nicht
    -- will, will sie ganz weg, nicht seltener.
    remind = function()
        local on = not ns.Profile.RemindersOn()
        ns.Profile.SetReminders(on)
        ns.Print(on and L["REMIND_ON"] or L["REMIND_OFF"])
    end,
    -- Groesse als Faktor. "1" ist die gebaute Groesse, "1.3" ist fuer
    -- den grossen Schirm, "0.8" fuer den kleinen.
    scale = function(argument)
        if ns.Profile.SetWindowScale(argument) then
            ns.UI.ApplyScale()
            ns.Print(L["SCALE_SET"], ns.Profile.WindowScale())
        else
            ns.Print(L["SLASH_SCALE"])
        end
    end,
    lang = function(argument)
        if ns.Profile.SetLanguage(argument) then
            ns.Print(L["LANG_SET"], argument)
            ns.Print("|cff808080/reload|r")
        else
            ns.Print(L["SLASH_LANG"])
        end
    end,
}

SLASH_METACODEX1 = "/mc"
SLASH_METACODEX2 = "/metacodex"

SlashCmdList.METACODEX = function(input)
    local command, argument = (input or ""):lower():match("^%s*(%S*)%s*(%S*)%s*$")
    if command == "" then
        ns.UI.Toggle()
        return
    end
    local handler = handlers[command]
    if handler then
        handler(argument)
    else
        help()
    end
end
