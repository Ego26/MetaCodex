-- Namensraum und Konstanten.
-- Laeuft als erste Datei; alles Weitere haengt sich hier ein.

local ADDON, ns = ...

ns.addonName = ADDON
-- Im Repo steht der Platzhalter @project-version@; der Packager ersetzt ihn
-- erst beim Release. Beim Entwickeln waere er sonst als Version zu sehen.
local version = C_AddOns.GetAddOnMetadata(ADDON, "Version")
ns.version = (version and not version:find("@", 1, true)) and version or "dev"

-- Namen fremder Addons an genau einer Stelle.
ns.AUCTIONATOR_ADDON = "Auctionator"

-- Schemaversion der SavedVariables. Bei jeder brechenden Aenderung erhoehen
-- und in Core/Profile.lua einen Migrationsschritt ergaenzen.
ns.DB_VERSION = 2

-- Praefix JEDER Liste, die dieses Addon in Auctionator anlegt.
--
-- Das ist keine Kosmetik, sondern die wichtigste Schutzregel des Projekts:
-- Auctionators CreateShoppingList ERSETZT eine Liste vollstaendig. Wer den
-- Namen einer selbst gepflegten Liste traefe, loeschte sie. Deshalb schreibt
-- MetaCodex ausschliesslich in Listen, die so heissen - und nirgendwo sonst.
ns.LIST_PREFIX = "MetaCodex: "

-- Kennwerte. Die Zeichenketten sind dieselben, die Data/Catalog.lua benutzt;
-- der Generator kennt sie aus den DB2-Tabellen (ITEM_MOD_*).
ns.SECONDARY = { "crit", "haste", "mastery", "vers" }
ns.TERTIARY  = { "speed", "leech", "avoid" }

-- Ausruestungsplaetze, an denen in dieser Erweiterung etwas zu kaufen ist.
-- `slot` ist der Katalogschluessel, `inv` der Platz am Charakter.
ns.SLOTS = {
    { slot = "helm",      inv = INVSLOT_HEAD },
    { slot = "shoulders", inv = INVSLOT_SHOULDER },
    { slot = "chest",     inv = INVSLOT_CHEST },
    { slot = "legs",      inv = INVSLOT_LEGS },
    { slot = "boots",     inv = INVSLOT_FEET },
    { slot = "ring",      inv = INVSLOT_FINGER1 },
    { slot = "ring",      inv = INVSLOT_FINGER2 },
    { slot = "weapon",    inv = INVSLOT_MAINHAND },
    { slot = "weapon",    inv = INVSLOT_OFFHAND },
}

-- Die Aktivitaeten, in Gruppen.
--
-- M+ und Raid stehen je mehrfach, und das ist kein Versehen: dieselbe
-- Aktivitaet, andere Stichprobe. "M+ (High Keys)" ist die Rangliste -
-- sie enthaelt ausschliesslich +20 und +21. "M+ +7 bis +21" kommt aus
-- den Schluesselstufen-Brackets und deckt die ganze Spanne ab. Beim
-- Raid ist es die Schwierigkeit.
--
-- Was keine Daten hat, steht nirgends zur Wahl - das ist DIE Regel des
-- Fensters (UI.SectionHasData). Die Zuordnung zu Gruppen steht hier und
-- nicht im Fenster, damit eine neue Aktivitaet nur an einer Stelle
-- eingetragen wird.
--
-- "brackets": die Eintraege sind EINE Aktivitaet, verschieden geschnitten.
-- Was in einem Schnitt fehlt, darf aus dem ersten kommen. Die PvP-Gruppe
-- hat das nicht: Solo Shuffle ist nicht 3v3 in anderem Schnitt, und eine
-- 3v3-Rangliste unter "Solo" waere schlicht falsch.
ns.MODE_GROUPS = {
    { label = "M+",   keys = { "mplus", "mplus-keys" }, brackets = true },
    { label = "Raid", keys = { "raid", "raid-mythic", "raid-normal" }, brackets = true },
    { label = "PvP",  keys = { "3v3", "2v2", "solo", "rbg", "blitz" } },
}

ns.MODES = {
    { key = "mplus",       label = "M+ (High Keys)" },
    { key = "mplus-keys",  label = "M+ (+7 - +21)" },
    { key = "raid",        label = "Raid (HC)" },
    { key = "raid-mythic", label = "Raid (Mythic)" },
    { key = "raid-normal", label = "Raid (Normal)" },
    { key = "3v3",         label = "3v3" },
    { key = "2v2",         label = "2v2" },
    { key = "solo",        label = "Solo Shuffle" },
    { key = "rbg",         label = "RBG" },
    { key = "blitz",       label = "RBG Blitz" },
}

-- Wie viele Stueck ein Platz braucht, wenn die Ausruestung NICHT befragt
-- werden kann - also wenn eine fremde Klasse gewaehlt ist. Am eigenen
-- Charakter wird gezaehlt statt geschaetzt.
ns.SLOT_COUNT = {
    helm = 1, shoulders = 1, chest = 1, legs = 1, boots = 1,
    ring = 2, weapon = 1,
}

-- Alle Plaetze, die einen Sockel tragen koennen - also praktisch alle.
-- Gesockelt wird nicht nach Katalog, sondern nach dem, was am Charakter
-- tatsaechlich leer ist.
ns.SOCKETABLE = {
    INVSLOT_HEAD, INVSLOT_NECK, INVSLOT_SHOULDER, INVSLOT_CHEST,
    INVSLOT_WAIST, INVSLOT_LEGS, INVSLOT_FEET, INVSLOT_WRIST,
    INVSLOT_HAND, INVSLOT_FINGER1, INVSLOT_FINGER2,
    INVSLOT_TRINKET1, INVSLOT_TRINKET2, INVSLOT_BACK,
    INVSLOT_MAINHAND, INVSLOT_OFFHAND,
}

---Meldet eine Zeile im Chat, immer mit Absender.
---@param fmt string
---Eine Folgezeile, ohne den Namen davor.
---
---Die Erinnerung nennt mehrere Posten, und die standen als eine Wurst
---in einer Zeile. Untereinander liest man sie; dafuer darf aber nicht
---vor jeder Zeile noch einmal "MetaCodex" stehen.
---@param text string
function ns.PrintPlain(text)
    print(text)
end

function ns.Print(fmt, ...)
    local text = select("#", ...) > 0 and fmt:format(...) or fmt
    print("|cff8a6ff0MetaCodex|r: " .. text)
end
