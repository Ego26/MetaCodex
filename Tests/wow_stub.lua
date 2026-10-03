-- Eine Attrappe der WoW-API, gerade gross genug, um das Addon zu laden.
--
-- Sie bildet NICHT nach, was Blizzards Funktionen bedeuten - das kann sie
-- nicht, und wer es versucht, testet am Ende seine eigene Attrappe. Sie
-- beantwortet nur die eine Frage, die ein Syntaxpruefer nicht beantwortet:
-- laeuft der Quelltext von oben bis unten durch, ohne auf ein nil zu
-- greifen?
--
-- Dazu merkt sich jeder Rahmen, was mit ihm gemacht wurde - Ankerpunkte,
-- Texte, Ereignisse. Damit laesst sich hinterher pruefen, ob die Zeilen
-- untereinander stehen und ob auf den Knoepfen Text steht.

local M = {}

-- ------------------------------------------------------------- Attrappe

local Mock = {}
Mock.methods = {}

Mock.__call = function() return Mock.new("ret") end
Mock.__index = function(t, key)
    local known = Mock.methods[key]
    if known then return known end
    -- Alles Unbekannte wird zu einem Kind, das selbst wieder aufrufbar
    -- ist. So ueberleben sowohl `frame:Irgendwas()` als auch
    -- `frame.Irgendwas:NochWas()`.
    local children = rawget(t, "__children")
    local child = children[key]
    if not child then
        child = Mock.new(tostring(key))
        children[key] = child
    end
    return child
end

function Mock.new(name)
    return setmetatable({
        __name = name,
        __children = {},
        __points = {},
        __scripts = {},
        __text = false,
        __shown = false,
        __checked = false,
        __enabled = true,
        __parent = false,
    }, Mock)
end

Mock.methods.SetPoint = function(self, ...)
    self.__points[#self.__points + 1] = { ... }
end
Mock.methods.ClearAllPoints = function(self)
    for i = #self.__points, 1, -1 do self.__points[i] = nil end
end
-- Welche Schriftgroesse wirklich gesetzt wurde: daran haengt, ob die
-- Einstellung "Schriftgroesse" etwas tut.
Mock.methods.SetFont = function(self, path, size, flags)
    self.__fontPath, self.__fontSize, self.__fontFlags = path, size, flags
end
Mock.methods.GetFont = function(self) return self.__fontPath, self.__fontSize, self.__fontFlags end
Mock.methods.SetText = function(self, text) self.__text = text end
Mock.methods.GetText = function(self) return self.__text end
-- Die Feldlaenge merkt sich der Stub, weil genau sie einmal falsch war:
-- vier Stellen fuer eine sechsstellige Gegenstands-ID, und die Eingabe
-- brach ab, ohne dass jemand sah, warum.
-- Ob ein Text umbrechen darf. Gemerkt, weil genau das einmal falsch
-- war: ein langer Gegenstandsname brach um, und die zweite Zeile lag
-- auf dem Fortschrittsbalken darunter.
--
-- rawget, nicht self.__wrap: ein Mock beantwortet jeden unbekannten
-- Zugriff mit einem Kind-Mock, und der ist immer wahr.
Mock.methods.SetWordWrap = function(self, v) self.__wrap = v and true or false end
Mock.methods.CanWordWrap = function(self) return rawget(self, "__wrap") ~= false end
Mock.methods.SetMaxLetters = function(self, n) self.__maxLetters = n end
Mock.methods.GetMaxLetters = function(self) return self.__maxLetters end
-- Und was ein Tooltip zeigen soll. Sonst laesst sich nicht pruefen, ob
-- der Zeiger wirklich den Gegenstand zeigt oder nur so tut.
Mock.methods.SetHyperlink = function(self, link) self.__link = link end
Mock.methods.Show = function(self) self.__shown = true end
Mock.methods.Hide = function(self) self.__shown = false end
Mock.methods.IsShown = function(self) return self.__shown == true end
Mock.methods.SetShown = function(self, v) self.__shown = v and true or false end
Mock.methods.SetScript = function(self, name, fn) self.__scripts[name] = fn end
Mock.methods.GetScript = function(self, name) return self.__scripts[name] end
Mock.methods.SetScale = function(self, scale) self.__scale = scale end
Mock.methods.SetResizable = function() end
Mock.methods.SetResizeBounds = function() end
Mock.methods.StartSizing = function() end
Mock.methods.SetFrameStrata = function(self, strata) self.__strata = strata end
Mock.methods.GetFrameStrata = function(self) return self.__strata or "MEDIUM" end
Mock.methods.Raise = function() end
Mock.methods.SetFrameLevel = function() end
Mock.methods.GetFrameLevel = function() return 1 end
-- Echte Masse: das Fenster ist ziehbar, und alles, was daran haengt,
-- rechnet mit der Breite. Ein Mock, der auf GetWidth ein Kind
-- zurueckgibt, liesse die Rechnung mit einem Laufzeitfehler sterben.
Mock.methods.SetSize = function(self, w, h) self.__w, self.__h = w, h end
Mock.methods.SetWidth = function(self, w) self.__w = w end
Mock.methods.SetHeight = function(self, h) self.__h = h end
Mock.methods.GetWidth = function(self) return rawget(self, "__w") or 0 end
-- rawget, nicht self.__h.
--
-- Ein Mock beantwortet JEDEN unbekannten Zugriff mit einem Kind-Mock.
-- Eine nie gesetzte Hoehe kam darum als Tabelle zurueck statt als
-- Zahl, und der erste Code, der damit rechnen wollte, ist gescheitert.
Mock.methods.GetHeight = function(self) return rawget(self, "__h") or 0 end
-- Durchsichtigkeit ist ein Zustand, den das Addon liest, nicht nur
-- setzt: ein festgehaltener Knopf ist voll da, ein ruhender halb. Ohne
-- diese beiden gab GetAlpha ein Kind zurueck, und jeder Vergleich mit
-- einer Zahl starb.
Mock.methods.SetAlpha = function(self, a) self.__alpha = a end
Mock.methods.GetAlpha = function(self) return rawget(self, "__alpha") or 1 end
-- WER UEBER WEM LIEGT. Das Addon hebt seinen Knopf im
-- Charakterfenster ueber dessen Inhalt - ohne diese beiden kam auf
-- GetFrameLevel ein Kind zurueck, und jeder Vergleich war wahr, egal
-- was das Addon gesetzt hatte.
Mock.methods.SetFrameLevel = function(self, l) self.__level = l end
Mock.methods.GetFrameLevel = function(self) return rawget(self, "__level") or 1 end
-- Und die Kinder eines Rahmens, in der Reihenfolge ihrer Entstehung.
Mock.methods.GetChildren = function(self)
    local kinder = rawget(self, "__kids") or {}
    -- NICHT "unpack and unpack(k) or table.unpack(k)": ein oder schneidet
    -- den Aufruf auf einen Wert, und dann hat jeder Rahmen genau ein
    -- Kind. Dieselbe Falle wie bei tonumber(f:GetLeft()).
    local aus = unpack or table.unpack
    return aus(kinder)
end
-- Der Elternrahmen, und zwar DERSELBE: ohne diese Zeile beantwortete
-- der Mock GetParent mit einem frischen Kind, und jeder Vergleich
-- "gehoert dieser Knopf zu jener Zeile" war falsch - im Spiel aber
-- richtig. Ein Test, der an einer Stelle anders antwortet als das Spiel,
-- misst sich selbst.
Mock.methods.GetParent = function(self) return rawget(self, "__parent") or nil end
-- Wie hoch ein Text gesetzt waere: das Erinnerungsfenster waechst mit
-- ihm, und ein Mock, der hier ein Kind zurueckgibt, liesse die Rechnung
-- mit einem Laufzeitfehler sterben.
Mock.methods.GetStringHeight = function(self)
    local text = tostring(self.__text or "")
    -- Zeilen mal Zeilenhoehe, und die haengt an der gesetzten Schrift.
    local size = tonumber(self.__fontSize) or 12
    return size * 1.2 * math.max(1, math.ceil(#text / 60))
end
Mock.methods.GetScale = function(self) return self.__scale or 1 end
Mock.methods.HookScript = function(self, name, fn) self.__scripts[name] = fn end
-- Texturen werden am Elternrahmen vermerkt.
--
-- Klingt nach Buchhaltung ohne Zweck, ist aber der einzige Weg, "hat
-- dieser Rahmen einen Hintergrund" zu pruefen - und genau das fehlte,
-- als der Kopierdialog durchsichtig ueber der Liste stand.
Mock.methods.CreateTexture = function(self)
    local texture = Mock.new("texture")
    self.__textures = self.__textures or {}
    self.__textures[#self.__textures + 1] = texture
    return texture
end
Mock.methods.CreateFontString = function() return Mock.new("fontstring") end
-- Welche Textur gesetzt wurde - damit ein Test fragen kann, ob das
-- Logo dran ist und nicht ein Fragezeichen.
Mock.methods.SetTexture = function(self, texture) self.__texture = texture end
-- Breite eines Textes: die Oberflaeche entscheidet an ihr, ob eine
-- Knopfreihe neben den Titel passt. Sieben Pixel je Zeichen ist grob,
-- aber es waechst mit dem Text, und darauf kommt es an.
Mock.methods.GetStringWidth = function(self) return #tostring(self.__text or "") * 7 end
Mock.methods.GetTexture = function(self) return self.__texture end
Mock.methods.GetChecked = function(self) return self.__checked == true end
Mock.methods.SetChecked = function(self, v) self.__checked = v and true or false end
Mock.methods.SetEnabled = function(self, v) self.__enabled = v and true or false end
-- Ob ein Knopf auch im grauen Zustand auf die Maus hoert.
--
-- WoW schaltet einem deaktivierten Knopf die Bewegungsskripte ab: kein
-- OnEnter, kein Tooltip. Wer erklaeren will, WARUM ein Knopf grau ist,
-- muss das hier einschalten - und ein Test, der es nicht sieht, haelt
-- einen Hinweis fuer vorhanden, den im Spiel niemand zu Gesicht bekommt.
Mock.methods.SetMotionScriptsWhileDisabled = function(self, v)
    self.__motionWhileDisabled = v and true or false
end
Mock.methods.IsEnabled = function(self) return self.__enabled == true end
-- Ereignisse merken, statt sie wegzuwerfen.
--
-- Das Spiel ruft OnEvent; hier muss ein Test das selbst tun koennen, und
-- dafuer muss er den Rahmen finden, der auf dieses Ereignis hoert. Ohne
-- das laesst sich kein ereignisgesteuerter Teil pruefen - etwa der Knopf,
-- der beim Oeffnen des Auktionshauses entsteht.
Mock.methods.RegisterEvent = function(self, event)
    local liste = rawget(self, "__events")
    if not liste then liste = {}; rawset(self, "__events", liste) end
    liste[event] = true
end
Mock.methods.UnregisterEvent = function(self, event)
    local liste = rawget(self, "__events")
    if liste then liste[event] = nil end
end
Mock.methods.RegisterForDrag = function() end
Mock.methods.RegisterForClicks = function() end
Mock.methods.StartMoving = function() end
Mock.methods.StopMovingOrSizing = function() end
Mock.methods.SetMovable = function() end
Mock.methods.EnableMouse = function() end
Mock.methods.SetFocus = function() end
Mock.methods.HighlightText = function() end
Mock.methods.SetAutoFocus = function() end
Mock.methods.SetMultiLine = function() end
Mock.methods.SetCursorPosition = function() end
Mock.methods.SetToplevel = function() end
Mock.methods.SetFontObject = function() end
Mock.methods.SetScrollChild = function(self, child) self.__child = child end
Mock.methods.GetObjectType = function() return "Frame" end

M.Mock = Mock

-- ------------------------------------------------------------- Globale

M.frames = {}

---Baut die Globalen auf, die das Addon anfasst.
---@param opts table Ausruestung, Werte und Katalogpfad
function M.install(opts)
    local G = _G

    G.UIParent = Mock.new("UIParent")
    -- Die Stilschicht rechnet mit der Skalierung; eine Attrappe, die dort
    -- ein Objekt statt einer Zahl liefert, laesst sie beim Vergleich
    -- auflaufen.
    G.UIParent.GetEffectiveScale = function() return 1 end
    G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    G.RAID_CLASS_COLORS = {
        WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
        DRUID = { r = 1.0, g = 0.49, b = 0.04 },
    }
    G.UISpecialFrames = {}
    G.GameTooltip = Mock.new("GameTooltip")
    G.GameTooltip_Hide = function() end
    G.SlashCmdList = {}

    G.CreateFrame = function(art, name, parent, template)
        local frame = Mock.new(name or "anon")
        frame.__parent = parent or false
        -- Beim Elternteil eintragen, damit GetChildren etwas zu sagen
        -- hat: das Addon durchsucht das Charakterfenster nach dem,
        -- was schon darin liegt.
        if type(parent) == "table" then
            -- NICHT __children: so heisst im Mock schon die Ablage fuer
            -- unbekannte Felder, und eine Liste von Rahmen gehoert nicht
            -- in dieselbe Tabelle wie Platzhalter.
            local liste = rawget(parent, "__kids")
            if not liste then liste = {}; parent.__kids = liste end
            liste[#liste + 1] = frame
        end
        M.frames[#M.frames + 1] = frame
        if name then G[name] = frame end
        -- Blizzards Scroll-Vorlage bringt eine Leiste und zwei
        -- Pfeilknoepfe mit, benannt nach dem Rahmen. Das Addon blendet
        -- sie aus, wenn nichts zu schieben ist - ohne diese Kinder im
        -- Stub laeuft diese Stelle im Test ins Leere und die Pruefung
        -- waere eine Attrappe, die sich selbst bestaetigt.
        -- Im Spiel bekommt der Scroll-Bereich seine Hoehe aus zwei
        -- Ankerpunkten, nicht aus SetHeight - hier waere sie also null,
        -- und dann passte nie etwas hinein. Ein realistischer Wert macht
        -- die Frage "muss gescrollt werden?" ueberhaupt erst stellbar.
        if art == "ScrollFrame" then frame:SetHeight(420) end
        if name and template and tostring(template):find("ScrollFrame", 1, true) then
            local leiste = Mock.new(name .. "ScrollBar")
            G[name .. "ScrollBar"] = leiste
            M.frames[#M.frames + 1] = leiste
            for _, endung in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
                local knopf = Mock.new(name .. "ScrollBar" .. endung)
                G[name .. "ScrollBar" .. endung] = knopf
                M.frames[#M.frames + 1] = knopf
            end
        end
        return frame
    end

    -- Ausruestungsplaetze, mit denselben Zahlen wie im Spiel.
    G.INVSLOT_HEAD, G.INVSLOT_NECK, G.INVSLOT_SHOULDER = 1, 2, 3
    G.INVSLOT_BODY, G.INVSLOT_CHEST, G.INVSLOT_WAIST = 4, 5, 6
    G.INVSLOT_LEGS, G.INVSLOT_FEET, G.INVSLOT_WRIST = 7, 8, 9
    G.INVSLOT_HAND, G.INVSLOT_FINGER1, G.INVSLOT_FINGER2 = 10, 11, 12
    G.INVSLOT_TRINKET1, G.INVSLOT_TRINKET2, G.INVSLOT_BACK = 13, 14, 15
    G.INVSLOT_MAINHAND, G.INVSLOT_OFFHAND = 16, 17

    -- Blizzards Menue-API, so weit das Addon sie benutzt: ein Titel und
    -- Knoepfe. Was gebaut wird, bleibt stehen, damit ein Test einen
    -- Eintrag waehlen kann.
    G.MenuUtil = {
        CreateContextMenu = function(anchor, builder)
            local items = {}
            -- Ein Knoten des Menues. Ein Knopf OHNE Funktion ist ein
            -- Untermenue - so benutzt Blizzards API es, und so muss der
            -- Nachbau es koennen, sonst stirbt jeder Waehler mit
            -- Untermenues im Test.
            local function node()
                local self = {}
                function self:CreateTitle(text) M.lastMenu.title = M.lastMenu.title or text end
                function self:CreateDivider() end
                function self:CreateButton(label, fn)
                    if fn then
                        items[#items + 1] = { label = label, run = fn }
                        return node()
                    end
                    return node()
                end
                function self:CreateRadio(label, isSet, fn, value)
                    items[#items + 1] = {
                        label = label,
                        run = function() if fn then fn(value) end end,
                        set = isSet and isSet(value) or false,
                    }
                    return node()
                end
                function self:CreateCheckbox(label, isSet, fn, value)
                    return self:CreateRadio(label, isSet, fn, value)
                end
                return self
            end
            M.lastMenu = { title = nil, items = items, anchor = anchor }
            builder(anchor, node())
            M.lastMenu.items = items
        end,
    }

    G.GetLocale = function() return opts.locale or "enUS" end
    G.UnitName = function() return "Tester" end

    -- Klassen und Spezialisierungen. Bewusst nur eine Handvoll: der Test
    -- prueft die Auswahl, nicht Blizzards Datenbank.
    local classes = opts.classes or {
        [1]  = { className = "Warrior", classFile = "WARRIOR", classID = 1 },
        -- Der Schamane ist dabei, weil er eine eigene Frage stellt: er
        -- legt seinen Waffenbuff selbst auf und darf deshalb nicht nach
        -- Oel gefragt werden. Ohne ihn im Stub laesst sich das nicht
        -- pruefen - und genau das war der Fall, als es im Spiel schieflief.
        [7]  = { className = "Shaman", classFile = "SHAMAN", classID = 7 },
        [11] = { className = "Druid", classFile = "DRUID", classID = 11 },
        -- Der Todesritter stellt auch eine eigene Frage: er schmiedet
        -- seine Waffenverzauberung selbst, kauft sie also nicht. Ohne
        -- ihn im Stub laesst sich die Runenschmiede nicht pruefen - und
        -- genau das war der Fall, als sie "bereits drauf" sagte,
        -- waehrend eine ganz andere Rune auf der Waffe sass.
        [6]  = { className = "Death Knight", classFile = "DEATHKNIGHT", classID = 6 },
    }
    local specs = opts.specs or {
        [1] = {
            { id = 71, name = "Arms", primary = 1 },
            { id = 73, name = "Protection", primary = 1 },
        },
        [7] = {
            { id = 262, name = "Elemental", primary = 4 },
            { id = 263, name = "Enhancement", primary = 2 },
            { id = 264, name = "Restoration", primary = 4 },
        },
        [6] = {
            { id = 250, name = "Blood", primary = 2 },
            { id = 251, name = "Frost", primary = 2 },
            { id = 252, name = "Unholy", primary = 2 },
        },
        [11] = {
            { id = 102, name = "Balance", primary = 4 },
            { id = 103, name = "Feral", primary = 2 },
            { id = 105, name = "Restoration", primary = 4 },
        },
    }
    M.classes, M.specs = classes, specs

    G.UnitClass = function()
        local entry = classes[opts.classID or 11]
        return entry.className, entry.classFile, entry.classID
    end

    G.C_CreatureInfo = { GetClassInfo = function(id) return classes[id] end }

    G.GetSpecializationInfoForClassID = function(classID, index)
        local entry = (specs[classID] or {})[index]
        if not entry then return nil end
        return entry.id, entry.name, "", 12345, "DAMAGER"
    end

    G.GetSpecializationInfoByID = function(specID)
        for _, list in pairs(specs) do
            for _, entry in ipairs(list) do
                if entry.id == specID then
                    return entry.id, entry.name, "", 12345, "DAMAGER", entry.primary
                end
            end
        end
        return nil
    end
    -- UnitStat gibt es hier mit ABSICHT nicht.
    --
    -- Seit 12.1 liefert der Aufruf "secret numbers"; wer sie vergleicht,
    -- bekommt im Spiel einen Laufzeitfehler, und das Fenster geht gar
    -- nicht mehr auf. Genau das ist einmal passiert. Indem die Attrappe
    -- den Aufruf weglaesst, faellt jeder neue Gebrauch hier sofort auf -
    -- und nicht erst bei jemandem, der das Addon benutzt.

    G.GetInventoryItemLink = function(_, slot)
        return (opts.equipped or {})[slot]
    end

    G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    G.tinsert = table.insert
    G.strjoin = function(sep, ...) return table.concat({ ... }, sep) end

    -- Das Datenaddon gilt als geladen, sobald der Test seine Dateien
    -- selbst ausgefuehrt hat - genau wie im Spiel nach LoadAddOn.
    M.loadedAddons = { }
    G.C_AddOns = {
        GetAddOnMetadata = function() return "1.0.0-test" end,
        IsAddOnLoaded = function(addon)
            -- Ein Test darf Auctionator auch mittendrin verschwinden
            -- lassen: die Knoepfe zur Uebergabe haengen daran, und ob
            -- sie dann weg sind, laesst sich sonst nicht pruefen.
            if addon == "Auctionator" then
                if M.auctionatorGone then return false end
                return opts.auctionator == true
            end
            return M.loadedAddons[addon] == true
        end,
        LoadAddOn = function(addon)
            M.loadedAddons[addon] = true
            return true
        end,
    }

    -- Zeitgeber, die sich abbrechen lassen: das Auffrischen wartet auf
    -- das LETZTE Ereignis einer Folge und bricht dafuer den vorigen ab.
    G.C_Timer = {
        After = function(_, fn) M.pendingTimers[#M.pendingTimers + 1] = fn end,
        NewTimer = function(_, fn)
            local slot = #M.pendingTimers + 1
            M.pendingTimers[slot] = fn
            return {
                Cancel = function() M.pendingTimers[slot] = false end,
                IsCancelled = function() return M.pendingTimers[slot] == false end,
            }
        end,
    }

    G.C_SpecializationInfo = {
        GetSpecialization = function() return 1 end,
        GetSpecializationInfo = function() return opts.specID or 262, opts.specName or "Elemental" end,
    }

    -- Wo der Spieler steht. Die Erinnerung haengt daran, und ohne
    -- Attrappe wuerde sie beim ersten Ereignis auflaufen - was sie beim
    -- ersten Versuch auch tat.
    -- Ueber M.instance, nicht ueber opts: ein Test muss den Ort WECHSELN
    -- koennen, sonst laesst sich nicht pruefen, dass die Erinnerung
    -- drinnen anschlaegt und draussen schweigt.
    G.IsInInstance = function()
        local kind = M.instance
        if not kind then return false, "none" end
        return true, kind
    end
    G.GetInstanceInfo = function()
        local kind = M.instance or "none"
        return M.instanceName or "Testinstanz", kind,
            0, "", 0, 0, false, M.instanceID or 1
    end

    -- Talente tragen nur eine Zauber-ID; Name und Symbol holt der
    -- Client. Genau das soll die Attrappe nachstellen - und wenn sie
    -- fehlt, soll der Abschnitt sofort auffallen, nicht leer bleiben.
    -- Die eigenen Kampfwertungen. Ausdruecklich NICHT ueber UnitStat -
    -- das liefert seit 12.1 geheime Zahlen und fehlt hier bewusst.
    G.CR_CRIT_MELEE = 11
    G.CR_HASTE_MELEE = 18
    G.CR_VERSATILITY_DAMAGE_DONE = 29
    G.GetCombatRating = function(index)
        return (opts.ratings or {})[index] or 0
    end
    G.CR_MASTERY = 26

    -- Das Abenteuerjournal. Liefert die Namen zu Begegnung und Instanz;
    -- gespeichert sind nur deren IDs, damit die Sprache vom Client kommt.
    G.EJ_GetEncounterInfo = function(id)
        if not id or id == 0 then return nil end
        return "Begegnung " .. tostring(id)
    end
    G.EJ_GetInstanceInfo = function(id)
        if not id or id == 0 then return nil end
        return "Instanz " .. tostring(id)
    end

    -- Der Talentbaum.
    --
    -- Nachgebaut, weil der Kodierer fuer die Importzeichenkette sonst
    -- ungeprueft ausgeliefert wuerde - und eine Zeichenkette, die das
    -- Spiel ablehnt, faellt dem Spieler erst im Talentfenster auf.
    --
    -- Der Strom rechnet wie Blizzards ExportUtil: Werte werden in einen
    -- Bitstrom geschrieben und am Ende zu Base64. Hier genuegt, dass
    -- beide Seiten - unser Kodierer und die Attrappe des Spiels -
    -- dieselbe Rechnung machen; geprueft wird ihre Uebereinstimmung.
    local TREE = opts.tree or {
        { node = 101, entries = { { entry = 1001, spell = 500001, maxRanks = 1 } } },
        { node = 102, entries = { { entry = 1002, spell = 500002, maxRanks = 2 } } },
        { node = 103, entries = {
            { entry = 1003, spell = 500003, maxRanks = 1 },
            { entry = 1004, spell = 500004, maxRanks = 1 },
        } },
        { node = 104, entries = { { entry = 1005, spell = 500005, maxRanks = 3 } } },
        -- ZWEI HELD-BAEUME, einer gewaehlt. Held-Talente sind keine
        -- eigenen Baeume, sondern Knoten mit einer subTreeID im selben;
        -- von mehreren je Spec ist einer aktiv, und die Knoten der
        -- anderen werden gar nicht gezeichnet. Ohne diesen Fall konnte
        -- kein Test bemerken, dass ein Build einen anderen Held-Baum
        -- spielt als der Spieler.
        { node = 105, sub = 11, entries = { { entry = 1006, spell = 500006, maxRanks = 1 } } },
        { node = 106, sub = 12, entries = { { entry = 1007, spell = 500007, maxRanks = 1 } } },
        -- Zwei Knoten, EIN Name: 900004 heisst wie 900003. Ueber den
        -- Namen darf dann nichts gefunden werden - ein Rahmen um den
        -- falschen Knoten sieht aus wie eine Auskunft.
        { node = 107, entries = { { entry = 1008, spell = 900003, maxRanks = 1 } } },
        { node = 108, entries = { { entry = 1009, spell = 900004, maxRanks = 1 } } },
    }
    -- Was der Spieler gerade gewaehlt hat.
    -- Knoten 102 ist GESCHENKT: aktiv, aber nicht gekauft. Genau dieser
    -- Fall hat ein Bit je Knoten verschoben und die Importkette im Spiel
    -- unbrauchbar gemacht - ohne ihn prueft die Attrappe ihn nie.
    local PICKED = opts.picked or {
        [101] = { index = 1, rank = 1 },
        [102] = { index = 1, rank = 0, granted = true },
        [103] = { index = 2, rank = 1 },
        [104] = { index = 1, rank = 2 },
    }

    local function makeStream()
        local bits = {}
        return {
            AddValue = function(self, width, value)
                for i = width - 1, 0, -1 do
                    bits[#bits + 1] = (math.floor(value / 2 ^ i) % 2)
                end
            end,
            GetExportString = function()
                local out = {}
                for i = 1, #bits, 6 do
                    local v = 0
                    for j = 0, 5 do v = v * 2 + (bits[i + j] or 0) end
                    out[#out + 1] = string.char(65 + v % 26)
                end
                return table.concat(out)
            end,
        }
    end
    G.ExportUtil = { MakeExportDataStream = makeStream }

    local byNode = {}
    for _, n in ipairs(TREE) do byNode[n.node] = n end
    local byEntry = {}
    for _, n in ipairs(TREE) do
        for i, e in ipairs(n.entries) do byEntry[e.entry] = { e = e, node = n, index = i } end
    end

    G.Enum = G.Enum or {}
    G.Enum.TraitNodeType = { Single = 0, Tiered = 1, Selection = 2 }

    G.C_Traits = {
        GetConfigInfo = function() return { treeIDs = { 7 } } end,
        GetTreeNodes = function()
            local ids = {}
            for _, n in ipairs(TREE) do ids[#ids + 1] = n.node end
            return ids
        end,
        GetNodeInfo = function(_, nodeID)
            local n = byNode[nodeID]
            if not n then return nil end
            local ids = {}
            for _, e in ipairs(n.entries) do ids[#ids + 1] = e.entry end
            local picked = PICKED[nodeID]
            return {
                entryIDs = ids,
                -- Der Knoten nennt seinen eigenen Hoechstrang. Er kann
                -- vom Eintrag abweichen, und genau daran hing ein Bit.
                maxRanks = n.entries[1] and n.entries[1].maxRanks or 1,
                type = (#ids > 1) and G.Enum.TraitNodeType.Selection or G.Enum.TraitNodeType.Single,
                ranksPurchased = picked and picked.rank or 0,
                -- Aktiv ist auch, was geschenkt wurde.
                activeRank = picked and (picked.granted and 1 or picked.rank) or 0,
                activeEntry = picked and { entryID = n.entries[picked.index].entry } or nil,
                subTreeID = n.sub,
            }
        end,
        GetEntryInfo = function(_, entryID)
            local hit = byEntry[entryID]
            if not hit then return nil end
            return { definitionID = entryID, maxRanks = hit.e.maxRanks }
        end,
        GetDefinitionInfo = function(defID)
            local hit = byEntry[defID]
            return hit and { spellID = hit.e.spell } or nil
        end,
        -- Welcher Held-Baum gilt. 11 ist gewaehlt, 12 nicht.
        GetSubTreeInfo = function(_, subTreeID)
            if subTreeID == 11 then return { name = "Sturmbringer", isActive = true } end
            if subTreeID == 12 then return { name = "Totemist", isActive = false } end
            return nil
        end,
        GetTreeHash = function() return { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 } end,
        GetLoadoutSerializationVersion = function() return 2 end,
        -- Das Spiel baut dieselbe Zeichenkette aus dem aktiven Build. Die
        -- Attrappe tut es auf demselben Weg wie der Kodierer - das ist die
        -- Probe: beide muessen zum selben Ergebnis kommen.
        GenerateImportString = function()
            local stream = makeStream()
            stream:AddValue(8, 2)
            stream:AddValue(16, opts.specID or 262)
            for i = 1, 16 do stream:AddValue(8, i) end
            for _, n in ipairs(TREE) do
                local picked = PICKED[n.node]
                if not picked then
                    stream:AddValue(1, 0)
                else
                    stream:AddValue(1, 1)
                    -- Nach "ausgewaehlt" das Bit "gekauft". Geschenkte
                    -- Knoten enden hier.
                    if picked.granted then
                        stream:AddValue(1, 0)
                    else
                        stream:AddValue(1, 1)
                        local maxRanks = n.entries[picked.index].maxRanks
                        local partial = picked.rank ~= maxRanks
                        stream:AddValue(1, partial and 1 or 0)
                        if partial then stream:AddValue(6, picked.rank) end
                        local isChoice = #n.entries > 1
                        stream:AddValue(1, isChoice and 1 or 0)
                        if isChoice then stream:AddValue(2, picked.index - 1) end
                    end
                end
            end
            return stream:GetExportString()
        end,
    }
    G.C_ClassTalents = { GetActiveConfigID = function() return 1 end }

    -- Die Belohnungstabelle der Saison. Nachgebaut mit derselben
    -- Eigenschaft wie im Spiel: die Truhe gibt nie weniger als der
    -- Dungeon, und ab einer gewissen Stufe steigt nichts mehr.
    G.C_MythicPlus = {
        GetRewardLevelForDifficultyLevel = function(level)
            if not level or level < 2 then return nil end
            local capped = math.min(level, 12)
            local endOfRun = 280 + (capped - 2) * 3
            return endOfRun + 7, endOfRun
        end,
    }

    -- Shift-Klick: der Test setzt M.shift und liest, was eingefuegt wurde.
    M.shift = false
    M.inserted = nil
    G.IsModifiedClick = function(kind) return kind == "CHATLINK" and M.shift == true end
    G.ChatEdit_InsertLink = function(text) M.inserted = text; return true end
    G.HandleModifiedItemClick = function(text)
        if M.shift then return G.ChatEdit_InsertLink(text) end
        return false
    end

    G.C_Spell = {
        -- ZWEI NUMMERN, EIN NAME.
        --
        -- Im Spiel gemessen: der Baum traegt 443454 "Schnelligkeit der
        -- Ahnen", die Messdaten 448861 - gleicher Name, andere Nummer,
        -- und GetOverrideSpell verbindet die beiden nicht. Hier heisst
        -- 900001 wie 500001 (im Baum) und 900003 wie 900004, damit auch
        -- der mehrdeutige Fall geprueft werden kann.
        GetSpellInfo = function(id)
            if not id then return nil end
            local heisst = id
            if id == 900001 then heisst = 500001 end
            if id == 900004 then heisst = 900003 end
            if id == 900005 then heisst = 900003 end
            return { name = "Zauber " .. tostring(heisst), iconID = 134400, spellID = id }
        end,
        -- Was ein Talent tut. Im Spiel ein ganzer Satz, hier einer, an
        -- dem ein Test ihn wiedererkennt.
        GetSpellDescription = function(id)
            if not id then return nil end
            -- Lang genug, dass das Kuerzen im Zeiger geprueft werden
            -- kann: im Spiel sind Talentbeschreibungen zwei bis vier
            -- Zeilen, und genau daran haengt die Entscheidung, ab wann
            -- sie abgeschnitten werden.
            return "Wirkung von " .. tostring(id)
                .. ", und zwar in aller Ausfuehrlichkeit beschrieben, damit"
                .. " der Zeiger etwas zu kuerzen hat, wenn ein Build sich in"
                .. " vielen Talenten unterscheidet."
        end,
    }

    G.C_Item = {
        GetItemInfo = function(id)
            if opts.unknownItems and opts.unknownItems[id] then return nil end
            -- Die vierte Stelle ist die GEGENSTANDSSTUFE. Sie stand
            -- hier auf 0, und damit konnte kein Test bemerken, dass ein
            -- Link auf anderer Stufe gar nicht zustande kam.
            return "Item " .. tostring(id), "|Hitem:" .. tostring(id) .. "|h",
                3, (opts.baseLevel or 200), 0, "", "", 1, "", 12345
        end,
        GetItemCount = function(id) return (opts.owned or {})[id] or 0 end,
        -- Die Farbe einer Qualitaetsstufe. Gebraucht, seit die
        -- Gegenstandsstufen im Waehler eingefaerbt sind - ohne sie
        -- faellt der Code auf den nackten Text zurueck, und der Test
        -- saehe nicht, ob ueberhaupt gefaerbt wird.
        GetItemQualityColor = function(quality)
            local toene = { [1] = 1, [2] = 0.12, [3] = 0.0, [4] = 0.64, [5] = 1 }
            local g = toene[quality] or 1
            return g, g, g, "ffffffff"
        end,
        RequestLoadItemDataByID = function() end,
        -- Die Stufe, die der Client aus einem Link errechnet. Eine
        -- Pfad-Bonus-ID kennt der Test aus opts.bonusLevels; eine
        -- Differenz-ID kennt er nicht und gibt die Grundstufe zurueck -
        -- so faellt auf, wenn ein Link den falschen Weg nimmt.
        GetDetailedItemLevelInfo = function(link)
            local bonus = tonumber(tostring(link):match(":1:(%d+)$"))
            local known = bonus and (opts.bonusLevels or {})[bonus]
            return known or (opts.baseLevel or 200), false, (opts.baseLevel or 200)
        end,
        GetItemStats = function(link)
            local id = tonumber(link:match("item:(%d+)"))
            local sockets = (opts.sockets or {})[id]
            if not sockets then return {} end
            return { EMPTY_SOCKET_PRISMATIC = sockets }
        end,
        GetItemInfoInstant = function(link)
            local id = tonumber(link:match("item:(%d+)"))
            return id, "", "", (opts.equipLoc or {})[id] or "INVTYPE_WEAPON"
        end,
    }

    M.printed = {}
    G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        M.printed[#M.printed + 1] = table.concat(parts, " ")
    end
end

M.pendingTimers = {}

---Laesst alle anstehenden C_Timer.After-Rueckrufe laufen.
function M.runTimers()
    local pending = M.pendingTimers
    M.pendingTimers = {}
    -- Abgebrochene stehen als false darin und laufen nicht.
    for i = 1, #pending do
        local fn = pending[i]
        if type(fn) == "function" then fn() end
    end
end

---Feuert ein Ereignis auf jedem Rahmen, der einen OnEvent-Haken hat.
---@param event string
function M.fire(event, ...)
    -- Nur an die, die sich dafuer angemeldet haben - und sagen, wie
    -- viele es waren. Vorher bekam JEDER Rahmen mit einem OnEvent-Haken
    -- jedes Ereignis, und ein Test konnte nicht unterscheiden, ob
    -- niemand zuhoert oder ob der Haken nichts tut.
    local n = 0
    for _, frame in ipairs(M.frames) do
        local liste = rawget(frame, "__events")
        local handler = frame.__scripts.OnEvent
        -- Wer sich nie angemeldet hat, bekommt es wie bisher: manche
        -- Rahmen im Addon haengen ihren Haken vor der Anmeldung ein.
        if handler and (not liste or liste[event]) then
            n = n + 1
            handler(frame, event, ...)
        end
    end
    return n
end

---Das zuletzt geoeffnete Auswahlmenue: Titel und Eintraege.
---
---Ohne das koennte ein Test nur pruefen, DASS ein Menue aufgeht, nicht
---was darin steht - und genau das ist bei einer Einstellung die Frage.
---@return table|nil
function M.menu()
    return M.lastMenu
end

---Einen Eintrag des offenen Menues waehlen, an seiner Beschriftung.
---@param label string
---@return boolean gefunden
function M.pick(label)
    local menu = M.lastMenu
    if not menu then return false end
    for _, entry in ipairs(menu.items) do
        if entry.label == label then entry.run() return true end
    end
    return false
end

---Alle Rahmen, die wie eine Listenzeile aussehen.
---@return table[]
function M.rows()
    local found = {}
    for _, frame in ipairs(M.frames) do
        -- Symbol, Titel UND Anteil: das ist eine Zeile der grossen Liste.
        -- Die Zeilen des Erinnerungsfensters haben keinen Anteil und
        -- gehoeren nicht dazu - sie folgen auch nicht seiner Breite.
        if rawget(frame, "icon") and rawget(frame, "title") and rawget(frame, "share") then
            found[#found + 1] = frame
        end
    end
    return found
end

return M
