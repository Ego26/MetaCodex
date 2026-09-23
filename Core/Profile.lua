-- SavedVariables: was der Spieler gewaehlt hat, je Spezialisierung.
--
-- Bewusst KEINE mitgelieferten Empfehlungen. Welcher Zweitwert fuer eine
-- Spec richtig ist, weiss dieses Addon (noch) nicht - und eine erfundene
-- Vorgabe waere schlimmer als eine leere Auswahl, weil man ihr glaubt.
-- Sobald der Sammler aus Phase 2 laeuft, fuellt er genau diese Felder vor.

local _, ns = ...

local Profile = {}
ns.Profile = Profile

local DEFAULTS = {
    main = nil,        -- Hauptwert: crit | haste | mastery | vers
    second = nil,      -- Nebenwert des Steins, darf gleich main sein
    tertiary = nil,    -- speed | leech | avoid
    weapon = nil,      -- Item-ID der gewaehlten Waffenverzauberung
    legs = nil,        -- Item-ID der gewaehlten Beinverstaerkung
    cheap = false,     -- guenstigere Handwerksstufe statt der hoechsten

    -- Bewusst aus: die Liste soll zeigen, WAS draufgehoert, nicht nur, was
    -- fehlt. Wer alles verzaubert hat, bekam sonst ein leeres Fenster und
    -- die Meldung "nichts zu kaufen" - und damit keine Antwort auf die
    -- Frage, ob das Richtige drauf ist. Der Haken filtert, er ist nicht
    -- die Grundeinstellung.
    onlyMissing = false,
}

function Profile.Init()
    MetaCodexDB = MetaCodexDB or {}
    local db = MetaCodexDB
    db.version = db.version or ns.DB_VERSION
    db.lang = db.lang or "auto"
    db.specs = db.specs or {}

    -- Schema 1 hatte "nur was fehlt" als Vorgabe. Das war falsch herum
    -- gedacht: wer alles verzaubert hat, sah ein leeres Fenster statt der
    -- Antwort auf "gehoert das Richtige drauf". Eine geaenderte Vorgabe
    -- erreicht bereits gespeicherte Profile aber nie - die tragen ihren
    -- alten Wert weiter. Also einmal zuruecksetzen.
    if db.version < 2 then
        for _, entry in pairs(db.specs) do entry.onlyMissing = false end
        db.version = 2
    end

    ns.SetLanguage(db.lang)
end

---Welche Spezialisierung das Fenster gerade zeigt.
---
---Ohne Auswahl ist das die aktive - so muss niemand etwas einstellen, um
---die eigene Liste zu sehen. Gewaehlt wird nur, wer fuer einen anderen
---Spec einkauft, und genau dafuer ist das Addon gedacht.
---@return number specID
function Profile.SelectedSpec()
    local db = MetaCodexDB or {}
    return db.selectedSpec or ns.Compat.CurrentSpec() or 0
end

---Der gewaehlte Spielmodus.
---
---Er haengt am Konto und nicht an der Spezialisierung: wer fuer den
---Raidabend einkauft, tut das fuer alle seine Speccs, und nicht fuer
---einen davon M+ und fuer den naechsten Raid.
---@return string
function Profile.Mode()
    local db = MetaCodexDB or {}
    return db.mode or ns.MODES[1].key
end

---@param mode string
function Profile.SetMode(mode)
    MetaCodexDB.mode = mode
    -- Der Dungeon gehoert zum Modus. Bleibt er beim Wechsel stehen, zeigt
    -- das Fenster gleich Raiddaten unter einem Dungeonnamen.
    MetaCodexDB.dungeon = nil
    MetaCodexDB.dungeons = nil
end

---@return number|nil classID
function Profile.SelectedClass()
    local db = MetaCodexDB or {}
    return db.selectedClass or ns.Compat.PlayerClassID()
end

---@param classID number
---@param specID number
function Profile.Select(classID, specID)
    MetaCodexDB.selectedClass = classID
    MetaCodexDB.selectedSpec = specID
end

---Zurueck auf die aktive Spezialisierung.
function Profile.SelectActive()
    MetaCodexDB.selectedClass = nil
    MetaCodexDB.selectedSpec = nil
end

---Gehoert die gewaehlte Spec zu einer anderen Klasse?
---
---Dann steht die Ausruestung des Spielers nicht zur Verfuegung: sie ist
---die falsche. Gezaehlt werden kann dann nicht mehr, nur noch aufgezaehlt.
---@return boolean
function Profile.IsForeignClass()
    local own = ns.Compat.PlayerClassID()
    return own ~= nil and Profile.SelectedClass() ~= own
end

---Die Auswahl der gezeigten Spezialisierung. Legt sie beim ersten Zugriff an.
---@return table
function Profile.Current()
    local db = MetaCodexDB or {}
    db.specs = db.specs or {}
    local specID = Profile.SelectedSpec()
    local entry = db.specs[specID]
    if not entry then
        entry = {}
        for key, value in pairs(DEFAULTS) do entry[key] = value end
        db.specs[specID] = entry
    end
    return entry
end

---@param key string
---@param value any
function Profile.Set(key, value)
    Profile.Current()[key] = value
end

---Ob genug bekannt ist, um eine Liste zu bauen.
---
---Zwei Wege fuehren dahin: es gibt Daten fuer diese Spec und diesen Modus,
---oder der Spieler hat selbst einen Hauptwert gewaehlt. Ohne beides gaebe
---es weder Ringverzauberung noch Stein.
---@return boolean
function Profile.Complete()
    if ns.Recommend.For(Profile.SelectedSpec(), Profile.Mode(), Profile.Source()) then return true end
    return Profile.Current().main ~= nil
end

function Profile.Reset()
    if MetaCodexDB then MetaCodexDB.specs = {} end
end

---@param lang string "de", "en" oder "auto"
function Profile.SetLanguage(lang)
    local map = { de = "deDE", en = "enUS", auto = "auto" }
    local value = map[lang]
    if not value then return false end
    MetaCodexDB.lang = value
    ns.SetLanguage(value)
    return true
end

---Die gewaehlte Plattform, oder Recommend.ALL fuer "alle gemittelt".
---
---Voreinstellung ist ALL: wer das Addon zum ersten Mal oeffnet, will eine
---Antwort und keine Quellenfrage. Wer den Unterschied sehen will, waehlt
---eine einzelne - und sieht dann auch, wo die Plattformen sich uneinig
---sind.
---@return string
function Profile.Source()
    local db = MetaCodexDB or {}
    return db.source or ns.Recommend.ALL
end

---@param source string
function Profile.SetSource(source)
    MetaCodexDB.source = source
end

---Welche Abschnitte der Seitenleiste eingeklappt sind.
---@param group string
---@return boolean
function Profile.IsCollapsed(group)
    local db = MetaCodexDB or {}
    return db.collapsed ~= nil and db.collapsed[group] == true
end

---@param group string
function Profile.ToggleCollapsed(group)
    MetaCodexDB.collapsed = MetaCodexDB.collapsed or {}
    MetaCodexDB.collapsed[group] = not MetaCodexDB.collapsed[group]
end

---Die Mindest-Gegenstandsstufe fuer die BiS-Listen. 0 heisst: alles.
---
---Ohne Filter stehen Gegenstaende aus alten Dungeons unkommentiert
---zwischen den aktuellen - murlok fuehrt sie, weil Leute sie tragen, aber
---wer heute einkauft, will sie nicht sehen.
---@return number
function Profile.MinItemLevel()
    local db = MetaCodexDB or {}
    return db.minItemLevel or 0
end

---@param level number
function Profile.SetMinItemLevel(level)
    MetaCodexDB.minItemLevel = level or 0
end

-- ------------------------------------------------------ Verbrauchsgueter

-- Wie viele Stueck man haben will, je Art.
--
-- Diese Zahlen sind KEINE Messung. Die Empfehlungen sagen, was die besten
-- Spieler benutzen - wie viel davon jemand mitnimmt, sagen sie nicht, und
-- eine erfundene Zahl als Beobachtung auszugeben waere die eine Luege, die
-- dieses Addon sich nicht leisten kann. Also: ein Vorschlag, den man
-- aendert, und im Fenster als Ziel benannt.
local TARGETS = {
    flask = 2,
    potion = 20,
    food = 20,
    vantus = 1,
    heal = 5,
    oil = 5,
    other = 5,
}

---@param kind string
---@return number
function Profile.ConsumableTarget(kind)
    local db = MetaCodexDB or {}
    local set = db.targets and db.targets[kind]
    if set ~= nil then return set end
    return TARGETS[kind] or 1
end

---Die eigene Wahl je Art - was DIESER Spieler benutzt.
---
---Gemessen wird, was die Besten nehmen; gekauft wird, was man selbst
---nimmt. Wer seine Speise fuer ein Zehntel des Preises kauft, hat nicht
---unrecht, und das Addon hat kein Recht, ihm dafuer "5 fehlen" unter
---eine Speise zu schreiben, die er gar nicht will.
---@param kind string
---@return number|nil itemID
function Profile.OwnConsumable(kind)
    local db = MetaCodexDB or {}
    return db.ownConsum and db.ownConsum[kind] or nil
end

---@param kind string
---@param itemID number|nil
function Profile.SetOwnConsumable(kind, itemID)
    MetaCodexDB.ownConsum = MetaCodexDB.ownConsum or {}
    MetaCodexDB.ownConsum[kind] = itemID
end

---@param kind string
---@param count number
function Profile.SetConsumableTarget(kind, count)
    MetaCodexDB.targets = MetaCodexDB.targets or {}
    MetaCodexDB.targets[kind] = math.max(0, math.floor(count or 0))
end

---Die Erinnerung: warnt beim Betreten von Schlachtzug oder Schluesselstein,
---wenn etwas fehlt.
---@return boolean
function Profile.RemindersOn()
    local db = MetaCodexDB or {}
    if db.reminders == nil then return true end
    return db.reminders and true or false
end

---@param on boolean
function Profile.SetReminders(on)
    MetaCodexDB.reminders = on and true or false
end

---Auch am Auktionshaus erinnern? Eine Chatzeile, nie ein Fenster.
---@return boolean
function Profile.RemindAtAuctionHouse()
    local db = MetaCodexDB or {}
    if db.remindAH == nil then return true end
    return db.remindAH and true or false
end

---@param on boolean
function Profile.SetRemindAtAuctionHouse(on)
    MetaCodexDB.remindAH = on and true or false
end

---Ab wann gewarnt wird: der Anteil des Ziels, unter dem etwas als
---knapp gilt. Wer 18 von 20 Traenken hat, braucht keinen Hinweis.
---@return number 0.25 | 0.5 | 0.75 | 1
function Profile.WarnBelow()
    local db = MetaCodexDB or {}
    return db.warnBelow or 0.5
end

---@param share number
function Profile.SetWarnBelow(share)
    MetaCodexDB.warnBelow = share
end

---Der gewaehlte Dungeon, als Modusschluessel.
---
---Nil heisst "alle" - und das ist etwas anderes als die Summe der
---einzelnen: die Gesamtauswertung stammt aus allen Laeufen, nicht aus
---acht zusammengerechneten Teilen.
---@return string|nil
---Der gewaehlte Dungeon - je Abschnitt einer.
---
---Vorgabe ist ueberall ALLE Dungeons. Ein Dungeon beantwortet eine
---engere Frage ("was nehmen sie HIER"), und wer sie unter Talenten
---stellt, hat sie unter Verbrauchsguetern nicht gestellt. Ein einziger
---gemerkter Dungeon stellte still beide Reiter um.
---@param section string|nil Abschnitt, sonst der laufende
---@return string|nil
function Profile.Dungeon(section)
    local db = MetaCodexDB or {}
    local key = section or db.section
    if not key then return nil end
    return db.dungeons and db.dungeons[key] or nil
end

---@param key string|nil
---@param section string|nil
function Profile.SetDungeon(key, section)
    local db = MetaCodexDB
    local where = section or db.section
    if not where then return end
    db.dungeons = db.dungeons or {}
    db.dungeons[where] = key
end

---Der Modus, unter dem nachgeschlagen wird: der Dungeon, wenn einer
---gewaehlt ist, sonst der Modus selbst.
---@return string
---@param section string|nil
function Profile.LookupMode(section)
    local mode = Profile.Mode()
    local dungeon = Profile.Dungeon(section)
    if not dungeon then return mode end
    -- Ein Dungeon aus einem anderen Modus waere eine stille Falsch-
    -- auskunft: die Auswahl steht noch, die Daten passen nicht mehr.
    if dungeon:sub(1, #mode + 1) ~= (mode .. "/") then return mode end
    return dungeon
end

---Wo das Fenster zuletzt stand.
---
---Gespeichert wird der Anker, nicht die Bildschirmkoordinate: wer mit
---einem zweiten Monitor spielt oder die Aufloesung aendert, faende sein
---Fenster sonst irgendwann ausserhalb des Bildes wieder.
---@return string|nil point, number x, number y
function Profile.WindowPoint()
    local db = MetaCodexDB or {}
    local w = db.window
    if not w or not w.point then return nil end
    return w.point, w.x or 0, w.y or 0
end

---@param point string
---@param x number
---@param y number
function Profile.SetWindowPoint(point, x, y)
    MetaCodexDB.window = MetaCodexDB.window or {}
    MetaCodexDB.window.point, MetaCodexDB.window.x, MetaCodexDB.window.y = point, x, y
end

---Die gemerkte Fenstergroesse, oder nil fuer die gebaute.
---@return number|nil width, number|nil height
function Profile.WindowSize()
    local db = MetaCodexDB or {}
    local w = db.window
    if not w or not w.width then return nil end
    return w.width, w.height
end

---@param width number
---@param height number
function Profile.SetWindowSize(width, height)
    MetaCodexDB.window = MetaCodexDB.window or {}
    MetaCodexDB.window.width = math.floor(width + 0.5)
    MetaCodexDB.window.height = math.floor(height + 0.5)
end

---Wie gross das Fenster ist, als Faktor. 1 ist die gebaute Groesse.
---
---Kein freies Ziehen: alle Breiten im Fenster leiten sich aus einer
---Konstante ab, und ein Faktor skaliert sie alle zusammen - das ist
---das, was auf einem 4K-Schirm fehlt, und es kostet eine Zeile.
---@return number
---Fensterlage und -groesse vergessen. Die Werte werden nicht auf einen
---Ersatz gesetzt, sondern geloescht - dann greift wieder das, was das
---Fenster von sich aus mitbringt, und zwar auch nach einem Umbau.
function Profile.ResetWindow()
    MetaCodexDB.window = nil
    MetaCodexDB.scale = nil
end

---Wo das Erinnerungsfenster steht. Wie beim Hauptfenster der Anker und
---nicht die Bildschirmkoordinate.
---@return string|nil point, number x, number y
function Profile.RemindPoint()
    local db = MetaCodexDB or {}
    local w = db.remindWindow
    if not w or not w.point then return nil end
    return w.point, w.x or 0, w.y or 0
end

---@param point string
---@param x number
---@param y number
function Profile.SetRemindPoint(point, x, y)
    MetaCodexDB.remindWindow = { point = point, x = x, y = y }
end

---Auf welchem Weg erinnert wird. Mehrere gleichzeitig sind erlaubt:
---die Chatzeile geht im Pull-Countdown unter, ein Fenster mitten im
---Bild ist manchen zu viel - das soll jeder selbst entscheiden.
---@param way string "chat" | "window" | "warning" | "sound"
---@return boolean
function Profile.RemindWay(way)
    local db = MetaCodexDB or {}
    local ways = db.remindWays
    if not ways or ways[way] == nil then
        -- Ab Werk: Chatzeile und eigenes Fenster. Die Bildschirmmitte
        -- und der Ton bleiben aus, bis jemand sie will.
        return way == "chat" or way == "window"
    end
    return ways[way] and true or false
end

---@param way string
---@param on boolean
function Profile.SetRemindWay(way, on)
    local db = MetaCodexDB
    db.remindWays = db.remindWays or {}
    db.remindWays[way] = on and true or false
end

---Die Chatzeile beim Betreten einer Instanz. Getrennt von der am
---Auktionshaus schaltbar: die eine kommt mitten im Pull-Countdown, die
---andere, wenn man ohnehin einkauft.
---@return boolean
function Profile.RemindOnEnter()
    local db = MetaCodexDB or {}
    if db.remindEnter == nil then return true end
    return db.remindEnter and true or false
end

---@param on boolean
function Profile.SetRemindOnEnter(on)
    MetaCodexDB.remindEnter = on and true or false
end

---Die Aktivitaet, mit der das Fenster aufgeht, oder nil fuer die zuletzt
---benutzte.
---@return string|nil
function Profile.StartMode()
    local db = MetaCodexDB or {}
    return db.startMode
end

---@param mode string|nil
function Profile.SetStartMode(mode)
    MetaCodexDB.startMode = mode
end

---Der Knopf an der Minimap. An, solange niemand ihn abschaltet: wer ein
---Addon installiert, will es finden, ohne einen Befehl zu kennen.
---@return boolean
function Profile.MinimapOn()
    local db = MetaCodexDB or {}
    if db.minimap == nil then return true end
    return db.minimap and true or false
end

---@param on boolean
function Profile.SetMinimap(on)
    MetaCodexDB.minimap = on and true or false
end

---Wo auf dem Ring der Knopf sitzt, in Grad.
---@return number
function Profile.MinimapAngle()
    local db = MetaCodexDB or {}
    return tonumber(db.minimapAngle) or 202
end

---@param angle number
function Profile.SetMinimapAngle(angle)
    MetaCodexDB.minimapAngle = tonumber(angle) or 202
end

---Der Knopf im Charakterfenster. Ebenfalls an.
---@return boolean
function Profile.CharButtonOn()
    local db = MetaCodexDB or {}
    if db.charButtonOn == nil then return true end
    return db.charButtonOn and true or false
end

---@param on boolean
function Profile.SetCharButton(on)
    MetaCodexDB.charButtonOn = on and true or false
end

function Profile.WindowScale()
    local db = MetaCodexDB or {}
    return db.scale or 1
end

---@param scale number 0.6 bis 1.6
---@return boolean ok
function Profile.SetWindowScale(scale)
    scale = tonumber(scale)
    if not scale or scale < 0.6 or scale > 1.6 then return false end
    MetaCodexDB.scale = scale
    return true
end

-- --------------------------------------------------------- Mehrere Speccs

-- Fuer welche Speccs die Einkaufsliste gilt.
--
-- Das war die allererste Bitte an dieses Addon: eine Liste fuer Heal, Tank
-- und DPS in einem Gang zum Auktionshaus. Das FENSTER zeigt weiter eine
-- Spec - zwei Empfehlungen nebeneinander waeren keine Antwort, sondern
-- eine Frage. Die LISTE darf mehrere abdecken, denn dort zaehlt nur, was
-- im Beutel landen soll.

---Die zusaetzlich eingeschlossenen Speccs.
---@return table<number, boolean>
function Profile.ListSpecs()
    local db = MetaCodexDB or {}
    return db.listSpecs or {}
end

---@param specID number
---@return boolean jetztDrin
function Profile.ToggleListSpec(specID)
    MetaCodexDB.listSpecs = MetaCodexDB.listSpecs or {}
    local on = not MetaCodexDB.listSpecs[specID]
    MetaCodexDB.listSpecs[specID] = on or nil
    return on
end

---Alle Speccs, fuer die eingekauft wird: die gezeigte und die
---zusaetzlich gewaehlten, jede genau einmal.
---@return number[]
function Profile.ShoppingSpecs()
    local out, seen = {}, {}
    local shown = Profile.SelectedSpec()
    if shown and shown > 0 then
        out[#out + 1] = shown
        seen[shown] = true
    end
    for specID in pairs(Profile.ListSpecs()) do
        if not seen[specID] then
            out[#out + 1] = specID
            seen[specID] = true
        end
    end
    return out
end

---Die gewaehlte Kategorie eines Abschnitts.
---
---Je Abschnitt eine eigene: bei der Ausruestung ist es ein Platz, bei
---den Verzauberungen auch einer, bei den Verbrauchsguetern eine Art.
---Eine gemeinsame Auswahl waere beim Wechsel jedes Mal ungueltig.
---@param section string
---@return string|nil
function Profile.Category(section)
    local db = MetaCodexDB or {}
    return db.category and db.category[section] or nil
end

---@param section string
---@param value string|nil
function Profile.SetCategory(section, value)
    MetaCodexDB.category = MetaCodexDB.category or {}
    MetaCodexDB.category[section] = value
end

---Der gewaehlte Ausruestungsplatz.
---
---Nil heisst "alle". Siebzehn Plaetze zu je fuenf Zeilen sind
---fuenfundachtzig Zeilen, und wer wissen will, welcher Schmuck oben
---steht, scrollt daran vorbei.
---@return string|nil
function Profile.GearSlot()
    return Profile.Category("gear")
end

---@param slot string|nil
function Profile.SetGearSlot(slot)
    Profile.SetCategory("gear", slot)
end

---Welchen Schluesselstein man selbst laeuft.
---
---Nicht dasselbe wie ein Filter: die Frage ist nicht "verstecke, was
---darunter liegt", sondern "welche Stufe bekomme ICH fuer dieses Teil".
---Nil heisst: zeig, was die Besten tragen.
---@return number|nil
function Profile.KeyLevel()
    local db = MetaCodexDB or {}
    return db.keyLevel
end

---@param level number|nil
function Profile.SetKeyLevel(level, source)
    MetaCodexDB.keyLevel = level
    -- Dungeonende oder Schatzkammer: dieselbe Schluesselstufe gibt zwei
    -- verschiedene Gegenstandsstufen, und welche gemeint ist, steht
    -- nicht in der Zahl.
    MetaCodexDB.keySource = level and source or nil
end

---Die Zielstufe fuer die Ausruestung: eine Gegenstandsstufe und der
---Aufwertungspfad, der sie ergibt.
---
---Vorher stand hier eine Schluesselstufe, und die Stufe wurde daraus
---gerechnet - ueber eine Belohnungstabelle, die zwei Werte ohne Namen
---liefert. Jetzt waehlt man die Stufe selbst, wie in KeystoneLoot:
---"Held 3 - 311". Der Schluessel steht nur noch als Beschriftung dabei.
---@return table|nil { level, bonus, label }
function Profile.Target()
    local db = MetaCodexDB or {}
    return db.keyTarget
end

---@param target table|nil { level, bonus, label }
function Profile.SetTarget(target)
    MetaCodexDB.keyTarget = target
    -- Die alte Schluesselwahl gilt damit nicht mehr; sonst zoegen zwei
    -- Einstellungen an derselben Anzeige.
    if target then MetaCodexDB.keyLevel, MetaCodexDB.keySource = nil, nil end
end

---Die Stufe, auf der die Ausruestung gezeigt wird - oder nil fuer
---"wie die Besten".
---@return number|nil level
---@return number|nil bonus  Pfad-Bonus-ID, wenn gewaehlt
function Profile.TargetLevel()
    local target = Profile.Target()
    if target and target.level then return target.level, target.bonus end
    -- Rueckfall auf die alte Schluesselwahl, solange sie noch gesetzt ist.
    local key = Profile.KeyLevel()
    if not key then return nil end
    local endOfRun, vault = ns.Compat.RewardLevels(key)
    return (Profile.KeySource() == "vault") and vault or endOfRun, nil
end

---@return string|nil Beschriftung des Knopfs
function Profile.TargetLabel()
    local target = Profile.Target()
    return target and target.label or nil
end

---Der gewaehlte Held-Baum der GEZEIGTEN Spec. Nil heisst: alle.
---
---Je Spec gemerkt: Sturmbringer ist eine Wahl des Verstaerkungs-
---Schamanen und sagt ueber den Wiederherstellungs-Druiden nichts.
---@return number|nil subTreeID
function Profile.HeroTree()
    local db = MetaCodexDB or {}
    local by = db.hero
    return by and by[Profile.SelectedSpec()] or nil
end

---@param subTreeID number|nil
function Profile.SetHeroTree(subTreeID)
    MetaCodexDB.hero = MetaCodexDB.hero or {}
    MetaCodexDB.hero[Profile.SelectedSpec()] = subTreeID
end

---@return string "endOfRun" oder "vault"
function Profile.KeySource()
    local db = MetaCodexDB or {}
    return db.keySource or "endOfRun"
end
