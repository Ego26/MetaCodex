-- Minimale Lokalisierung: L["Schluessel"] gibt die Uebersetzung zurueck,
-- sonst den Schluessel selbst. Fehlende Strings fallen so nie hart aus.

local _, ns = ...

local locale = GetLocale()
local translations = {}
local override

ns.L = setmetatable({}, {
    __index = function(_, key)
        local entry = translations[key]
        if entry == nil then return key end
        return entry
    end,
})

local registered = {}

---Traegt Uebersetzungen fuer eine Sprache ein.
---enUS ist die Basis und wird immer angewendet, damit kein Schluessel fehlt.
---@param localeName string Sprachkuerzel, z. B. "deDE"
---@param entries table<string, string>
---Mehrere Aufrufe je Sprache sind ausdruecklich erlaubt und werden
---zusammengefuehrt. Ein Ersetzen waere die naheliegende Zeile und genau
---der Fehler, der hier schon einmal drinstand: ein zweiter Aufruf mit ein
---paar Kurzlabels hat den ganzen ersten Block weggeworfen, und im Spiel
---standen dann die Schluessel statt der Texte auf den Knoepfen.
function ns.RegisterLocale(localeName, entries)
    local bucket = registered[localeName]
    if not bucket then
        bucket = {}
        registered[localeName] = bucket
    end
    for key, value in pairs(entries) do
        bucket[key] = value
    end

    if localeName ~= "enUS" and localeName ~= locale then return end
    for key, value in pairs(entries) do
        translations[key] = value
    end
end

---Die Sprache, die gerade gilt - fuer Texte, die nicht in L stehen,
---sondern aus den Spieldaten kommen (Namen der Held-Baeume).
---@return string "deDE" | "enUS" | ...
function ns.CurrentLocale()
    return override or locale
end

---Schaltet die Sprache der Oberflaeche um, unabhaengig vom Client.
---Wer auf einem englischen Client deutsch spielt, soll das koennen.
---@param localeName string "deDE", "enUS" oder "auto"
function ns.SetLanguage(localeName)
    override = localeName ~= "auto" and localeName or nil
    wipe(translations)
    for key, value in pairs(registered.enUS or {}) do translations[key] = value end
    local want = override or locale
    if want ~= "enUS" and registered[want] then
        for key, value in pairs(registered[want]) do translations[key] = value end
    end
end
