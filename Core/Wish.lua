local _, ns = ...

---Ein Favorit ist gedroppt - bei jemand anderem.
---
---Gewuenscht am 19. Oktober, nach dem Vorbild von Keystone Loot: wer
---ein Stueck als Favorit markiert hat, soll es merken, wenn es in der
---Gruppe faellt, und den Glueckspilz gleich anfluestern koennen.
---
---Das Spiel meldet jede Beute nach einem Boss und am Ende eines
---Dungeons mit ENCOUNTER_LOOT_RECEIVED - mit Gegenstand, Spieler und
---Klasse. Gezaehlt wird, was ein Favorit IRGENDEINER Spec dieses
---Charakters ist: wer als Heiler laeuft und ein Stueck fuer seinen
---Schaden markiert hat, will es genauso wissen.
---
---Nicht im Kampf: das Fenster wartet, bis der Kampf vorbei ist. Und
---nichts, was das Spiel als geheim markiert, wird angefasst.
local Wish = {}
ns.Wish = Wish

local L = ns.L

-- Was gerade im Fenster steht, und was schon einmal gemeldet wurde.
local offen = {}
local gemeldet = {}
local wartet = false

local function geheim(wert)
    return type(issecretvalue) == "function" and issecretvalue(wert) or false
end

local function kurzName(name)
    return (tostring(name or ""):gsub("%-.*$", ""))
end

---Immer mit Realm (19. Oktober). Das Spiel laesst ihn bei Spielern vom
---eigenen Realm weg, und ohne ihn landet ein Fluestern bei Namensgleichheit
---auf einem anderen Realm beim Falschen.
local function mitRealm(name)
    if tostring(name):find("-", 1, true) then return name end
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if type(realm) == "string" and realm ~= "" then return name .. "-" .. realm end
    return name
end
Wish.WithRealm = mitRealm

---Bin das ich?
local function ich(name)
    local selbst = UnitName and UnitName("player")
    return type(selbst) == "string" and kurzName(name) == selbst
end

---Ist das ein Favorit dieses Charakters, in irgendeiner Spec?
---@param itemID number
---@return boolean
function Wish.IsFavorite(itemID)
    return ns.Profile.NeedAnySpec and ns.Profile.NeedAnySpec(itemID) or false
end

---Eine Beute melden. Gibt zurueck, ob sie ins Fenster kam.
---@param itemID number
---@param link string|nil
---@param player string
---@param classFile string|nil
---@return boolean
function Wish.Seen(itemID, link, player, classFile)
    if not ns.Profile.FavDropAlertOn() then return false end
    if geheim(itemID) or geheim(player) or geheim(link) then return false end
    itemID = tonumber(itemID)
    if not itemID or type(player) ~= "string" or player == "" then return false end
    if ich(player) then return false end
    if not Wish.IsFavorite(itemID) then return false end
    -- Dasselbe Stueck beim selben Spieler nur einmal: manche Beute wird
    -- doppelt gemeldet, und ein zweites Fenster waere Laerm.
    local schluessel = player .. ":" .. itemID
    if gemeldet[schluessel] then return false end
    gemeldet[schluessel] = true
    offen[#offen + 1] = {
        id = itemID,
        link = type(link) == "string" and link or nil,
        player = mitRealm(player),
        class = type(classFile) == "string" and classFile or nil,
    }
    Wish.Show()
    return true
end

---Das Fenster zeigen - oder nach dem Kampf.
function Wish.Show()
    if #offen == 0 then return end
    if InCombatLockdown and InCombatLockdown() then
        wartet = true
        return
    end
    wartet = false
    if ns.UI and ns.UI.ShowFavoriteDrops then ns.UI.ShowFavoriteDrops(offen) end
end

---Was im Fenster steht.
function Wish.Open()
    return offen
end

---Das Fenster wurde geschlossen: die Liste ist erledigt.
function Wish.Clear()
    offen = {}
end

---Der Satz, der gefluestert wird.
---@param entry table
---@return string
function Wish.Message(entry)
    local link = entry.link or (ns.Compat.ItemInfo and select(2, ns.Compat.ItemInfo(entry.id)))
        or ("item " .. tostring(entry.id))
    return L["FAV_WHISPER"]:format(link)
end

---Den Spieler anfluestern - ueber die Chatzeile.
---
---Direkt senden tat im Spiel nichts (19. Oktober): der Versand lief
---still ins Leere. Jetzt oeffnet der Klick die Chatzeile mit dem
---fertigen Fluestern, und Enter schickt es ab. Das geht immer, denn
---der Spieler sendet selbst - und kann den Satz vorher aendern.
---@param entry table
---@return boolean
-- Der Rueckfall: die Chatzeile mit dem fertigen Fluestern.
local function chatzeile(entry)
    local oeffnen = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    if type(oeffnen) ~= "function" then return false end
    return (pcall(oeffnen, "/w " .. entry.player .. " " .. Wish.Message(entry)))
end

-- Was gerade direkt gesendet wird - falls das Spiel es blockiert.
local imVersand

function Wish.Whisper(entry)
    if not entry or entry.asked then return false end
    -- ERST DIREKT: ein Klick, und es ist raus.
    local senden = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if type(senden) == "function" then
        imVersand = entry
        local ok, fehler = pcall(senden, Wish.Message(entry), "WHISPER", nil, entry.player)
        imVersand = nil
        if ok then
            entry.asked = true
            return true
        end
        -- Der Grund steht im Chat, nicht in einem verschluckten Fehler.
        ns.Print(L["FAV_WHISPER_FAILED"]:format(tostring(fehler)))
    end
    -- SONST die Chatzeile: Enter schickt es ab.
    if chatzeile(entry) then
        entry.asked = true
        return true
    end
    return false
end

---Ein gespielter Drop, nur fuer die Dev-Version.
---
---Ein eigener Favorit, wenn es einen gibt, sonst das erste empfohlene
---Stueck - und als Empfaenger der Spieler SELBST: so laesst sich das
---Anfluestern ausprobieren, ohne jemand Fremdes anzuschreiben.
function Wish.Test()
    local id = ns.Profile.AnyNeed()
    if not id then
        local gear = ns.Recommend.Gear(ns.Profile.SelectedSpec(), ns.Profile.Mode(), ns.Recommend.ALL)
        for _, liste in pairs(gear or {}) do
            if liste[1] and liste[1].id then id = liste[1].id; break end
        end
    end
    if not id then return false end
    local name = UnitName and UnitName("player") or "?"
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    local _, classFile = UnitClass and UnitClass("player")
    offen[#offen + 1] = {
        id = id,
        link = select(2, ns.Compat.ItemInfo(id)),
        player = (type(realm) == "string" and realm ~= "") and (name .. "-" .. realm) or name,
        class = classFile,
    }
    Wish.Show()
    return true
end

-- Das Ohr am Spiel.
local ohr = CreateFrame("Frame")
ohr:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
ohr:RegisterEvent("PLAYER_REGEN_ENABLED")
-- Blockiert das Spiel den Versand, meldet es das hier und nicht als
-- Fehler. Dann steht der Grund im Chat, und die Chatzeile geht auf.
ohr:RegisterEvent("ADDON_ACTION_BLOCKED")
ohr:RegisterEvent("ADDON_ACTION_FORBIDDEN")
ohr:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_LOOT_RECEIVED" then
        local _, itemID, link, _, player, classFile = ...
        pcall(Wish.Seen, itemID, link, player, classFile)
    elseif event == "PLAYER_REGEN_ENABLED" and wartet then
        Wish.Show()
    elseif (event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN") and imVersand then
        local addon, was = ...
        ns.Print(L["FAV_WHISPER_FAILED"]:format(tostring(event) .. " " .. tostring(addon) .. " " .. tostring(was)))
        chatzeile(imVersand)
    end
end)
-- Fuer die Pruefung.
Wish.__ohr = ohr
