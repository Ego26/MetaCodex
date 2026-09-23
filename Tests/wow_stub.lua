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
Mock.methods.SetText = function(self, text) self.__text = text end
Mock.methods.GetText = function(self) return self.__text end
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
Mock.methods.SetFrameLevel = function() end
Mock.methods.GetFrameLevel = function() return 1 end
-- Echte Masse: das Fenster ist ziehbar, und alles, was daran haengt,
-- rechnet mit der Breite. Ein Mock, der auf GetWidth ein Kind
-- zurueckgibt, liesse die Rechnung mit einem Laufzeitfehler sterben.
Mock.methods.SetSize = function(self, w, h) self.__w, self.__h = w, h end
Mock.methods.SetWidth = function(self, w) self.__w = w end
Mock.methods.SetHeight = function(self, h) self.__h = h end
Mock.methods.GetWidth = function(self) return self.__w or 0 end
Mock.methods.GetHeight = function(self) return self.__h or 0 end
-- Wie hoch ein Text gesetzt waere: das Erinnerungsfenster waechst mit
-- ihm, und ein Mock, der hier ein Kind zurueckgibt, liesse die Rechnung
-- mit einem Laufzeitfehler sterben.
Mock.methods.GetStringHeight = function(self)
    local text = tostring(self.__text or "")
    return 14 * math.max(1, math.ceil(#text / 60))
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
Mock.methods.IsEnabled = function(self) return self.__enabled == true end
Mock.methods.RegisterEvent = function() end
Mock.methods.UnregisterEvent = function() end
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

    G.CreateFrame = function(_, name, parent)
        local frame = Mock.new(name or "anon")
        frame.__parent = parent or false
        M.frames[#M.frames + 1] = frame
        if name then G[name] = frame end
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
        [11] = { className = "Druid", classFile = "DRUID", classID = 11 },
    }
    local specs = opts.specs or {
        [1] = {
            { id = 71, name = "Arms", primary = 1 },
            { id = 73, name = "Protection", primary = 1 },
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
            if addon == "Auctionator" then return opts.auctionator == true end
            return M.loadedAddons[addon] == true
        end,
        LoadAddOn = function(addon)
            M.loadedAddons[addon] = true
            return true
        end,
    }

    G.C_Timer = {
        After = function(_, fn) M.pendingTimers[#M.pendingTimers + 1] = fn end,
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
        GetSpellInfo = function(id)
            if not id then return nil end
            return { name = "Zauber " .. tostring(id), iconID = 134400, spellID = id }
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
    for _, fn in ipairs(pending) do fn() end
end

---Feuert ein Ereignis auf jedem Rahmen, der einen OnEvent-Haken hat.
---@param event string
function M.fire(event, ...)
    for _, frame in ipairs(M.frames) do
        local handler = frame.__scripts.OnEvent
        if handler then handler(frame, event, ...) end
    end
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
