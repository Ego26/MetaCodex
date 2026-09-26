-- Das Fenster.
--
-- Aufbau nach egoUIs UI-Konzept: eine feste Grundflaeche, persistente
-- Navigation links, Inhalt rechts, Statuszeile unten. Kein Blizzard-Rahmen,
-- keine aufpoppenden Zweitfenster.
--
-- Zwei Dinge entscheiden hier ueber den Eindruck, und beide sind
-- unscheinbar: der 1-px-Rahmen muss auf jeder Aufloesung ein Pixel sein
-- (ns.Style.Pixel), und es duerfen nicht mehr Schriftgroessen vorkommen,
-- als in ns.Style.font stehen. Wer davon abweicht, baut wieder ein
-- Addon-Optionsfenster aus 2012.

local _, ns = ...

local UI = {}
ns.UI = UI

local L = ns.L
local S = ns.Style

-- Vorwaerts angekuendigt, und zwar GANZ oben.
--
-- Dreimal derselbe Fehler an diesem Abend: eine local-Funktion, die
-- weiter unten steht, aber weiter oben in einem Klickhaken benutzt wird.
-- Lua sieht dort dann eine globale Leere, und der Knopf tut nichts -
-- ohne Fehlermeldung, solange niemand klickt.
--
-- Hier stehen alle, die aus mehreren Richtungen gebraucht werden.
local activeSection

local linkFrame
local textFrame
local frame, rows, scrollChild
local navButtons, groupHeads = {}, {}
local statButtons, optionChecks = { main = {}, second = {}, tertiary = {} }, {}
local headerText, hintText, sourceText, sectionTitle, sectionCount

-- Die gebaute Groesse - und die Grenzen, in denen man zieht. Unter 760
-- Pixeln passt die Kopfzeile nicht mehr, ueber 1600 liest niemand mehr.
local WIDTH, HEIGHT = 960, 640
local MIN_W, MIN_H, MAX_W, MAX_H = 760, 480, 1600, 1100

-- Die nutzbare Breite einer Zeile - aus der FENSTERBREITE, nicht aus
-- einer Zahl. Sie MUSS der Breite des Scrollkindes entsprechen: einmal
-- war die Zeile zwanzig Pixel breiter als ihr Behaelter, und genau diese
-- zwanzig Pixel trug die Prozentspalte - aus "78%" wurde "78".
--
-- Als Funktion, weil das Fenster ziehbar ist. Jede Breite, die von
-- ihr abhaengt, wird beim Auffrischen neu gesetzt.
local SIDEBAR = 196
---Die Seitenleiste ist so breit, wie ihre Schrift es braucht.
---
---Feste 196 Pixel waren richtig, solange die Schrift fest war. Bei
---125 % stand "Verzauberungen & Steine" bis an die Kante.
local function sidebarWidth()
    return math.floor(SIDEBAR * (S.fontScale or 1) + 0.5)
end

local function contentWidth()
    local w = frame and frame:GetWidth()
    if type(w) ~= "number" or w <= 0 then w = WIDTH end
    return w - sidebarWidth() - 24 * 2 - 20
end

-- Wo die Zielwert-Bahn beginnt und wie breit sie ist.
local BAR_X = 24 + 26 + 200
local function barWidth()
    return contentWidth() - BAR_X - 96
end

-- Zielwerte brauchen mehr Hoehe als eine Einkaufszeile: Bahn UND Zahl.
local STAT_ROW_HEIGHT = 46
local HEADER, FOOTER = 56, 48
-- Hoehe der zweiten Kopfzeile, in die die Knoepfe rutschen, wenn sie neben
-- dem Titel nicht mehr passen.
local HEADER_ROW = 28
local ROW_HEIGHT = 46
-- Zubehoer einer Zeile - Verzauberung, Stein - steht klein darunter.
local SUB_ROW_HEIGHT = 24


-- Aus welchen Abschnitten man etwas kauft.
--
-- Talente kauft man nicht, Zielwerte auch nicht, und Ausruestung faellt -
-- ausser dem Handwerksteil - im Dungeon. Die beiden Knoepfe unten gehoeren
-- deshalb nur hierher; ueberall sonst waren sie eine Einladung zu einer
-- Suche, die nichts findet.
local SHOPPING = { enchants = true, consumables = true, remind = true }

-- Wo ein einzelner Dungeon die Antwort aendert: nur bei den Talenten.
--
-- Bei der Ausruestung war er auch, und dort unnoetig: welcher Gegenstand
-- oben steht, entscheidet die Spec und nicht der Dungeon - und wo er
-- FAELLT, steht in jeder Zeile.
-- Welche Abschnitte ein Dungeon wirklich veraendert.
--
-- Talente, Verbrauchsgueter, Verzauberungen und Steine: alle misst
-- Warcraft Logs je Dungeon UND ueber alle - wie Archon es auch zeigt.
-- Die Vorgabe ist ueberall "Alle Dungeons"; der Dungeon beantwortet die
-- engere Frage, wenn jemand sie stellt.
local DUNGEON_SECTIONS = { talents = true, consumables = true, enchants = true }

-- Wessen Profil gerade offen ist, statt eines Abschnitts. Gesetzt vom
-- Klick auf eine Zeile der Rangliste, geloescht vom Zurueck-Knopf oder
-- vom Wechsel des Abschnitts.
local viewingPlayer

-- Das Fenster der Erinnerung. Eines fuer alle Ansagen, nicht eines je
-- Ansage: zwei uebereinander waeren schlimmer als keines.
local remindFrame

local SECTIONS = {
    { key = "guides",      group = "GROUP_KNOW" },
    { key = "stats",       group = "GROUP_KNOW" },
    { key = "talents",     group = "GROUP_KNOW" },
    { key = "players",     group = "GROUP_KNOW" },

    { key = "gear",        group = "GROUP_GEAR" },
    { key = "enchants",    group = "GROUP_GEAR" },
    { key = "consumables", group = "GROUP_GEAR" },
    { key = "remind",      group = "GROUP_GEAR" },
    { key = "settings",    group = "GROUP_ABOUT" },
    { key = "info",        group = "GROUP_ABOUT" },
}

local GROUPS = { "GROUP_KNOW", "GROUP_GEAR", "GROUP_ABOUT" }

-- ------------------------------------------------------------- Bausteine

local function makeButton(parent, width, height, label, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button.bg = S:Fill(button, "bgOverlay")
    button.border = S:Border(button, "borderSubtle")
    button.label = S:Text(button, "body", "textPrimary")
    button.label:SetPoint("CENTER")
    button.label:SetJustifyH("CENTER")
    button.label:SetText(label or "")
    button:SetScript("OnEnter", function(self) self.bg:SetVertexColor(S:Color("bgHover")) end)
    button:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(S:Color(self.__active and "bgHover" or "bgOverlay"))
    end)
    if onClick then button:SetScript("OnClick", onClick) end
    return button
end

local function setButtonActive(button, active)
    button.__active = active and true or false
    button.bg:SetVertexColor(S:Color(active and "bgHover" or "bgOverlay"))
    S:Recolor(button.label, active and "textPrimary" or "textSecondary")
end

local function makeStatRow(parent, labelKey, key, values, y)
    local caption = S:Text(parent, "caption", "textMuted")
    caption:SetPoint("TOPLEFT", S.space.lg, y)
    caption:SetWidth(84)
    caption:SetText(L["LBL_" .. labelKey])

    local x = S.space.lg + 88
    for _, value in ipairs(values) do
        local button = makeButton(parent, 76, 22, L["STATSHORT_" .. value], function()
            local current = ns.Profile.Current()
            ns.Profile.Set(key, current[key] == value and nil or value)
            if key == "main" and not current.second then
                ns.Profile.Set("second", current.main)
            end
            UI.Refresh()
        end)
        button:SetPoint("TOPLEFT", x, y + 4)
        statButtons[key][value] = button
        x = x + 80
    end
    return y - 28
end

local function makeCheck(parent, labelKey, key, x, y)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", x, y)
    check:SetSize(20, 20)
    check.text = S:Text(check, "caption", "textSecondary")
    check.text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.text:SetText(L[labelKey])
    check:SetScript("OnClick", function(self)
        ns.Profile.Set(key, self:GetChecked() and true or false)
        UI.Refresh()
    end)
    optionChecks[key] = check
    return check
end

-- An oder aus, als Auswahl. Dieselben zwei Eintraege ueberall, damit
-- kein Schalter anders bedient wird als der daneben.
local function boolChoices()
    return {
        { value = true, label = L["OPTION_ON"] },
        { value = false, label = L["OPTION_OFF"] },
    }
end

-- ---------------------------------------------------------------- Menues

local function contextMenu(anchor, title, entries, onPick)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, root)
            root:CreateTitle(title)
            for _, entry in ipairs(entries) do
                root:CreateButton(entry.label, function() onPick(entry) UI.Refresh() end)
            end
        end)
        return
    end
    -- Ohne Menue-API bleibt Weiterschalten. Nicht schoen, aber es fuehrt
    -- zum selben Ziel und bricht nicht.
    if #entries == 0 then return end
    onPick(entries[1])
    UI.Refresh()
end

---Klasse und Spezialisierung waehlen.
---@param anchor table
function UI.OpenSpecPicker(anchor)
    local ownClass = ns.Compat.PlayerClassID()

    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        local specs = ns.Compat.SpecsForClass(ownClass)
        if #specs == 0 then return end
        local current, index = ns.Profile.SelectedSpec(), 1
        for i, spec in ipairs(specs) do
            if spec.id == current then index = i % #specs + 1 break end
        end
        ns.Profile.Select(ownClass, specs[index].id)
        UI.Refresh()
        return
    end

    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(L["LBL_SPEC"])
        root:CreateButton(L["SPEC_ACTIVE"], function()
            ns.Profile.SelectActive()
            UI.Refresh()
        end)

        -- Weitere Speccs fuer die EINKAUFSLISTE, nicht fuer die Anzeige.
        -- Der Unterschied steht in der Ueberschrift, sonst sucht jemand
        -- vergeblich nach zwei Spalten im Fenster.
        local own = ns.Compat.SpecsForClass(ownClass)
        if #own > 1 then
            local sub = root:CreateButton(L["SPEC_ALSO_BUY"])
            for _, spec in ipairs(own) do
                sub:CreateCheckbox(spec.name, function()
                    return ns.Profile.ListSpecs()[spec.id] == true
                end, function()
                    ns.Profile.ToggleListSpec(spec.id)
                    UI.Refresh()
                    return MenuResponse and MenuResponse.Refresh or nil
                end)
            end
        end
        -- Klassenfarbe und Specsymbol: in WoW erkennt man eine Klasse an
        -- ihrer Farbe, lange bevor man ihren Namen gelesen hat. Ein
        -- schwarz-weisses Menue waere hier schlicht langsamer zu bedienen.
        local function addClass(entry)
            local specs = ns.Compat.SpecsForClass(entry.id)
            if #specs == 0 then return end
            local color = ns.Compat.ClassColor(entry.file)
            local submenu = root:CreateButton(("|cff%s%s|r"):format(color, entry.name))
            for _, spec in ipairs(specs) do
                local icon = spec.icon and ("|T%d:16:16:0:0|t "):format(spec.icon) or ""
                submenu:CreateButton(("%s|cff%s%s|r"):format(icon, color, spec.name), function()
                    ns.Profile.Select(entry.id, spec.id)
                    UI.Refresh()
                end)
            end
        end
        local classes = ns.Compat.Classes()
        for _, entry in ipairs(classes) do if entry.id == ownClass then addClass(entry) end end
        for _, entry in ipairs(classes) do if entry.id ~= ownClass then addClass(entry) end end
    end)
end

---Aktivitaet waehlen. Nur die, zu denen es fuer diesen Abschnitt etwas
---gibt - siehe UI.SectionHasData.
local function openActivityPicker(anchor)
    -- Nach Gruppen, nicht als Liste von acht.
    --
    -- M+ hat zwei Stichproben, Raid drei Schwierigkeiten, PvP fuenf
    -- Klammern. Flach untereinander liest sich das wie eine Aufzaehlung;
    -- in Untermenues wie eine Auswahl.
    local byKey = {}
    for _, mode in ipairs(ns.MODES) do byKey[mode.key] = mode end

    -- Was keine Daten hat, steht nicht zur Wahl.
    --
    -- Hier stand ein "(keine Daten)" hinter dem Namen. Das war ehrlich
    -- und trotzdem falsch: es fuellt eine Liste mit Zeilen, die nichts
    -- tun. Eine Aktivitaet ohne Daten ist keine Aktivitaet, die man
    -- auswaehlen koennte.
    local function has(mode)
        if not ns.Recommend.HasMode(mode.key) then return false end
        -- Und sie muss zu DIESEM Abschnitt etwas haben. "2v2" unter
        -- Verbrauchsguetern fuehrt auf eine leere Seite - also steht
        -- es dort nicht.
        return UI.SectionHasData(activeSection().key, mode.key)
    end

    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, root)
            root:CreateTitle(L["LBL_ACTIVITY"])
            local current = ns.Profile.Mode()
            for _, group in ipairs(ns.MODE_GROUPS) do
                -- Eine Gruppe, in der nichts uebrig bleibt, wird gar
                -- nicht erst aufgemacht.
                local any = false
                for _, key in ipairs(group.keys) do
                    if byKey[key] and has(byKey[key]) then any = true end
                end
                local sub = any and root:CreateButton(group.label) or nil
                for _, key in ipairs(group.keys) do
                    local mode = byKey[key]
                    if sub and mode and has(mode) then
                        -- Ein Haken zeigt, wo man gerade steht. Ohne ihn
                        -- muss man das Untermenue aufklappen, um es zu
                        -- sehen - und dafuer ist es das falsche Werkzeug.
                        sub:CreateRadio(mode.label, function()
                            return ns.Profile.Mode() == mode.key
                        end, function()
                            ns.Profile.SetMode(mode.key)
                            UI.Refresh()
                        end)
                    end
                end
            end
        end)
        return
    end

    -- Ohne Menue-API bleibt Weiterschalten.
    local order = {}
    for _, group in ipairs(ns.MODE_GROUPS) do
        for _, key in ipairs(group.keys) do
            if byKey[key] and has(byKey[key]) then order[#order + 1] = key end
        end
    end
    local at = 1
    for i, key in ipairs(order) do
        if key == ns.Profile.Mode() then at = i % #order + 1 break end
    end
    if order[at] then
        ns.Profile.SetMode(order[at])
        UI.Refresh()
    end
end

---Dungeon waehlen.
---
---"Alle" ist nicht die Summe der einzelnen: die Gesamtauswertung stammt
---aus allen Laeufen, die einzelne nur aus denen dieses Dungeons. Wer
---beides addierte, kaeme auf andere Zahlen.
---Ob die Einzelauswahl einer Aktivitaet Bosse oder Dungeons sind.
---
---Dieselbe Mechanik, andere Woerter: im Raid steht je Boss ein eigener
---Datensatz, in M+ je Dungeon. "Alle Dungeons" ueber einer Bossliste
---waere die Art Beschriftung, die niemand ernst nimmt.
---@param mode string
---@return string allKey, string titleKey
local function unitLabels(mode)
    if ns.Recommend.BaseMode(mode):sub(1, 4) == "raid" then
        return "BOSS_ALL", "LBL_BOSS"
    end
    return "DUNGEON_ALL", "LBL_DUNGEON"
end

---Wie ein Dungeon oder Boss im Fenster heisst.
---
---Aus dem Journal des Clients, wenn die Daten seine Nummer tragen -
---sonst der englische Name aus der Quelle. Vorher stand im deutschen
---Fenster "Nek'zali the Soulcoiler", weil Warcraft Logs so heisst und
---niemand nachgefragt hatte.
---@param entry table
---@return string
local function unitName(entry)
    return (entry.enc and ns.Compat.EncounterName(entry.enc))
        or (not entry.enc and entry.inst and ns.Compat.InstanceName(entry.inst))
        or entry.name
end

---Und wie der Raid heisst, zu dem er gehoert.
---@param entry table
---@return string|nil
local function unitGroup(entry)
    if not entry.group then return nil end
    return (entry.inst and ns.Compat.InstanceName(entry.inst)) or entry.group
end

local function openDungeonPicker(anchor)
    local mode = ns.Profile.Mode()
    local allKey, titleKey = unitLabels(mode)
    local list = ns.Recommend.Dungeons(mode)
    local function pick(key)
        -- Erst hier laden. Wer nie einen Dungeon waehlt, zahlt nie dafuer.
        if key and not ns.Data.EnsureDungeons() then
            ns.Print(L["NO_DUNGEON_DATA"])
            return
        end
        ns.Profile.SetDungeon(key or nil)
    end

    -- Zwei Raids nebeneinander: dann je Raid ein Untermenue mit seinen
    -- Bossen. Neun Bosse flach untereinander, ohne zu sagen, welcher
    -- wohin gehoert, waeren eine Liste zum Raten.
    local groups, order = {}, {}
    for _, entry in ipairs(list) do
        if entry.group then
            if not groups[entry.group] then groups[entry.group] = {}; order[#order + 1] = entry.group end
            table.insert(groups[entry.group], entry)
        end
    end
    if #order > 0 and MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, root)
            root:CreateTitle(L[titleKey])
            root:CreateRadio(L[allKey], function() return ns.Profile.Dungeon() == nil end,
                function() pick(nil); UI.Refresh() end)
            for _, name in ipairs(order) do
                local sub = root:CreateButton(unitGroup(groups[name][1]) or name)
                for _, entry in ipairs(groups[name]) do
                    sub:CreateRadio(unitName(entry), function() return ns.Profile.Dungeon() == entry.key end,
                        function() pick(entry.key); UI.Refresh() end)
                end
            end
            -- Was keinem Raid zugeordnet ist, steht darunter.
            for _, entry in ipairs(list) do
                if not entry.group then
                    root:CreateRadio(unitName(entry), function() return ns.Profile.Dungeon() == entry.key end,
                        function() pick(entry.key); UI.Refresh() end)
                end
            end
        end)
        return
    end

    local entries = { { key = false, label = L[allKey] } }
    for _, dungeon in ipairs(list) do
        entries[#entries + 1] = {
            key = dungeon.key,
            label = unitGroup(dungeon)
                and (unitGroup(dungeon) .. ": " .. unitName(dungeon)) or unitName(dungeon),
        }
    end
    contextMenu(anchor, L[titleKey], entries, function(entry) pick(entry.key) end)
end

---Plattform waehlen.
---
---Angeboten werden nur Quellen, die diesen Spielmodus wirklich messen -
---murlok fuehrt kein Raid, Warcraft Logs kein PvP-Bracket. Ein Waehler,
---der trotzdem alle anbietet, fuehrt in leere Listen.
---
---"Alle" steht oben und ist die Voreinstellung: wer das Addon oeffnet,
---will eine Antwort und keine Quellenfrage.
local function openSourcePicker(anchor)
    -- Die Quellen haengen an der AKTIVITAET, nicht am gewaehlten Dungeon:
    -- wer einen Dungeon waehlt, wechselt nicht die Plattform.
    local available = ns.Recommend.SourcesFor(ns.Profile.Mode())
    local section = activeSection()
    local specID = ns.Profile.SelectedSpec()
    local mode = ns.Profile.LookupMode()

    -- Was hier nichts liefert, steht gar nicht erst zur Wahl.
    --
    -- Erst habe ich solche Quellen still uebersprungen (dann sah
    -- Umschalten aus wie "passiert nichts"), dann gekennzeichnet (dann
    -- standen tote Eintraege in der Liste). Beides war Beiwerk um eine
    -- Auswahl herum, die es nicht gibt: raider.io fuehrt keine
    -- Zielwerte und wird es auch nicht.
    local entries = { { key = ns.Recommend.ALL, label = L["SOURCE_ALL"] } }
    for _, source in ipairs(available) do
        if ns.Recommend.HasSection(specID, mode, source, section.key) then
            entries[#entries + 1] = { key = source, label = source }
        end
    end
    contextMenu(anchor, L["LBL_SOURCE"], entries, function(entry)
        ns.Profile.SetSource(entry.key)
    end)
end

-- -------------------------------------------------------- Zeilenquellen

-- Die Reihenfolge der Ausruestungsplaetze. murlok liefert sie als Text
-- ("Main Hand"), und sortiert man nach Namen, steht die Waffe zwischen
-- Hals und Schultern. Am Charakter hat die Reihenfolge einen Sinn - also
-- steht sie hier.
local GEAR_ORDER = {
    "Head", "Neck", "Shoulders", "Back", "Chest", "Wrist", "Hands",
    "Waist", "Legs", "Feet", "Rings", "Trinkets", "Main Hand", "Off Hand",
}

---Woher ein Gegenstand kommt - in absteigender Sicherheit.
---
---1. Das Abenteuerjournal: Boss und Instanz. Auch fuer die alten
---   Saisondungeons, deren Beute der Zusammenbau aus dem ganzen Journal
---   neben die Empfehlungen legt.
---2. PvP-Ware, am englischen Namen im Katalog erkannt: Eroberung, Ehre,
---   Handwerk.
---3. Set-Teil: dann kommt es aus dem Schlachtzug oder dem Tresor.
---4. Handwerk: dann stellt man es her.
---5. Sonst "kein Instanzdrop". Welt-, Ruf- und Delve-Beute steht in
---   keiner Tabelle, die von aussen lesbar waere; sie zu erfinden waere
---   schlimmer als sie so zu benennen.
---@param itemID number
---@param badge string|nil
---@param mode string
---@return string|nil
---@return string|nil text   Fundort als Text
---@return string|nil key    Schluessel fuer den Fundort-Filter
---@return string|nil label  Name der Filtergruppe (Instanz oder Art)
local function originText(itemID, badge, mode)
    local enc, inst = ns.Catalog.DropSource(itemID)
    local text = ns.Compat.DropText(enc, inst)
    if text then
        -- Gefiltert wird nach INSTANZ, nicht nach Boss: "was faellt in
        -- diesem Dungeon" ist die Frage, die jemand stellt.
        local place = inst and ns.Compat.DropText(nil, inst) or text
        return text, "inst:" .. tostring(inst or enc), place
    end
    -- PvP-Ware, am englischen Namen im Katalog erkannt.
    local origin = ns.Catalog.Origin and ns.Catalog.Origin(itemID)
    if origin == "conquest" then return L["ORIGIN_CONQUEST"], "conquest", L["ORIGIN_CONQUEST"] end
    if origin == "honor" then return L["ORIGIN_HONOR"], "honor", L["ORIGIN_HONOR"] end
    if origin == "pvpcraft" then return L["ORIGIN_PVPCRAFT"], "craft", L["ORIGIN_CRAFT"] end
    if badge == "set" then return L["ORIGIN_SET"], "set", L["ORIGIN_SET"] end
    if badge == "craft" then return L["ORIGIN_CRAFT"], "craft", L["ORIGIN_CRAFT"] end
    -- Was uebrig bleibt, steht in Blizzards Abenteuerjournal nicht.
    --
    -- Das ist die Auskunft, die wir haben, und sie ist nachgeprueft: die
    -- Journaltabelle kennt diese Gegenstaende nicht, Blizzards
    -- Gegenstands-Schnittstelle nennt keine Quelle, und eine Tabelle fuer
    -- Haendler, Quests oder Ruf gibt es nicht. Die Zeile sagt deshalb
    -- zuerst, was bekannt ist, und erst danach, was daraus folgt.
    return L["ORIGIN_WORLD"], "world", L["ORIGIN_WORLD"]
end

---Die haeufigste Ausruestung je Platz.
---@return table[] rows
---@return string|nil fromSource
local function gearRows(specID, mode, source)
    -- Was schon am Koerper haengt, einmal je Aufbau - nicht je Zeile.
    local worn = ns.Compat.EquippedIDs()
    local gear, from = ns.Recommend.Gear(specID, mode, source)
    if not gear then return {}, nil end

    local minLevel = ns.Profile.MinItemLevel()
    -- Ein einzelner Platz statt aller. Nicht "hinspringen", sondern
    -- filtern: die Liste scrollt ohnehin, und wer den Schmuck sucht,
    -- will den Rest gar nicht sehen.
    local only = ns.Profile.GearSlot()
    -- Einmal ausgerechnet statt je Zeile: die Belohnungsstufe haengt am
    -- Schluessel, nicht am Gegenstand.
    -- Welche Stufe gemeint ist: die vom Dungeonende oder die aus der
    -- Schatzkammer. Ohne diese Unterscheidung zeigte die Truhenauswahl
    -- dieselbe Zahl wie das Dungeonende.
    -- Stufe UND Pfad: "305" ist Champion 5 oder Held 1, und welcher
    -- gemeint ist, hat der Spieler im Menue gesagt.
    local yours, yoursBonus = ns.Profile.TargetLevel()
    local rows = {}
    for _, slot in ipairs(GEAR_ORDER) do
        local list = (not only or only == slot) and gear[slot] or nil
        local shown = 0
        for _, item in ipairs(list or {}) do
            -- Der Filter greift VOR der Begrenzung auf drei. Sonst
            -- verbrauchen drei alte Gegenstaende die Plaetze, und der
            -- aktuelle faellt hinten heraus.
            if (item.ilvl or 0) >= minLevel then
                shown = shown + 1
                -- Drei je Platz. Wer den vierthaeufigsten Gegenstand
                -- traegt, braucht keine Liste, sondern einen eigenen Kopf.
                if shown > 5 then break end
                local name, link, icon = ns.Compat.ItemInfo(item.id)
                -- Noch nicht im Zwischenspeicher: anfordern. Boot.lua
                -- hoert auf GET_ITEM_INFO_RECEIVED und frischt auf.
                if not name then ns.Compat.RequestItem(item.id) end
                -- Woher es kommt. Steht nicht in den Empfehlungen,
                -- sondern im Katalog: das ist Spieldatum, keine
                -- Beobachtung, und es gehoert zum Gegenstand, nicht zum
                -- Modus.
                local badge = item.kind or ns.Catalog.ItemKind(item.id)
                -- Auf der gewaehlten Stufe, wenn eine gewaehlt ist.
                --
                -- Der Link traegt die Bonus-ID fuer die Stufendifferenz;
                -- Stufe und Werte rechnet der Client. Ohne ihn stand im
                -- Tooltip die Grundstufe - "Stufe 28" unter einer Zeile,
                -- die 334 sagt.
                local showLevel = yours or item.ilvl
                local atLevel = yours and ns.Compat.LinkAtLevel(item.id, yours) or nil
                local drop, sourceKey, sourceLabel = originText(item.id, badge, mode)
                rows[#rows + 1] = {
                    kind = "gear", id = item.id, pct = item.pct,
                    drop = drop, sourceKey = sourceKey, sourceLabel = sourceLabel,
                    -- Die Quelle darf es sagen; wenn sie schweigt,
                    -- sagen es die Spieldaten. murlok liefert die Marke
                    -- mit, Warcraft Logs nicht - und ein Set-Teil bleibt
                    -- eines, egal wer es beobachtet hat.
                    badge = badge,
                    ilvl = showLevel, maxKey = item.maxKey,
                    -- Die Stufe reist als ZAHL mit, nicht nur als
                    -- fertiger Link. Warum: GetItemInfo schweigt,
                    -- solange der Client den Gegenstand nicht vom
                    -- Server hat, und beim Aufbau der Liste hat er die
                    -- wenigsten. Dann kam kein Link zustande und das
                    -- Tooltip zeigte die Grundstufe - "71" unter einer
                    -- Zeile, die 318 sagt. Beim Hovern ist er da.
                    atLevel = atLevel, wantLevel = yours, wantBonus = yoursBonus,
                    name = name or item.name, link = link, icon = icon,
                    group = L["GEARSLOT_" .. slot:gsub("%s", "")],
                    -- Ob man es schon hat: angelegt oder im Gepaeck.
                    -- Die Zahl ist egal, ein Stueck traegt man einmal.
                    worn = worn[item.id] == true,
                    owned = ns.Compat.ItemCount(item.id) > 0,
                }
            end
        end
    end
    return rows, from
end

---Die Ausruestungsplaetze, zu denen es ueberhaupt etwas gibt.
---
---Aus den Daten, nicht aus einer festen Liste: eine Spec ohne Schild
---soll keinen leeren Schildeintrag im Waehler haben.
---@return string[] in der Reihenfolge der Anzeige
local function slotsInGear(specID, mode, source)
    local gear = ns.Recommend.Gear(specID, mode, source)
    local out = {}
    for _, slot in ipairs(GEAR_ORDER) do
        if gear and gear[slot] and #gear[slot] > 0 then out[#out + 1] = slot end
    end
    return out
end

---Die Kategorien eines Abschnitts, aus seinen eigenen Zeilen.
---
---Abgeleitet, nicht aufgezaehlt: eine feste Liste waere falsch, sobald
---eine Spec einen Platz nicht hat oder eine Quelle eine Art nicht fuehrt.
---Die Zeilen wissen es besser als jede Tabelle im Quelltext.
---@param section table
---@param rows table[] die ungefilterten Zeilen des Abschnitts
---@return table[] { key, label }
local function categoriesIn(section, rows)
    local seen, out = {}, {}
    for _, row in ipairs(rows or {}) do
        local key, label
        if section.key == "consumables" then
            key = row.ckind
            label = key and L["CONSUM_" .. key]
        else
            key = row.slot
            label = key and L["SLOT_" .. key]
        end
        if key and not seen[key] then
            seen[key] = true
            out[#out + 1] = { key = key, label = label or key }
        end
    end
    return out
end

---Die Fundorte, die in dieser Liste vorkommen: Instanzen und Arten.
---@param rows table[]
---@return table[] { key, label }
local function sourcesIn(rows)
    local seen, out = {}, {}
    for _, row in ipairs(rows or {}) do
        if row.sourceKey and not seen[row.sourceKey] then
            seen[row.sourceKey] = true
            out[#out + 1] = { key = row.sourceKey, label = row.sourceLabel or row.sourceKey }
        end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

---Fundort waehlen: "was faellt hier", nicht nur "wo faellt das".
local function openSourcePickerGear(anchor, sources)
    local entries = { { key = false, label = L["SOURCE_ANY"] } }
    for _, src in ipairs(sources) do
        entries[#entries + 1] = { key = src.key, label = src.label }
    end
    contextMenu(anchor, L["LBL_ORIGIN"], entries, function(entry)
        ns.Profile.SetCategory("gearSource", entry.key or nil)
    end)
end

---Held-Baum waehlen: alle, oder einer - mit seinem Anteil.
local function openHeroPicker(anchor, trees)
    local entries = { { key = false, label = L["HERO_ALL"] } }
    for _, t in ipairs(trees) do
        entries[#entries + 1] = {
            key = t.id,
            label = L["HERO_ENTRY"]:format(ns.Catalog.SubTreeName(t.id), t.pct),
        }
    end
    contextMenu(anchor, L["LBL_HERO"], entries, function(entry)
        ns.Profile.SetHeroTree(entry.key or nil)
    end)
end

---Ausruestungsplatz waehlen.
local function openSlotPicker(anchor, specID, mode, source)
    local entries = { { slot = false, label = L["SLOT_ALL"] } }
    for _, slot in ipairs(slotsInGear(specID, mode, source)) do
        entries[#entries + 1] = {
            slot = slot, label = L["GEARSLOT_" .. slot:gsub("%s", "")],
        }
    end
    contextMenu(anchor, L["LBL_GEARSLOT"], entries, function(entry)
        ns.Profile.SetGearSlot(entry.slot or nil)
    end)
end

---Kategorie eines beliebigen Abschnitts waehlen.
local function openCategoryPicker(anchor, section, categories)
    local entries = { { key = false, label = L["CATEGORY_ALL"] } }
    for _, cat in ipairs(categories) do
        entries[#entries + 1] = { key = cat.key, label = cat.label }
    end
    contextMenu(anchor, L["LBL_CATEGORY"], entries, function(entry)
        ns.Profile.SetCategory(section.key, entry.key or nil)
    end)
end

---Die Gegenstandsstufen, die in dieser Liste ueberhaupt vorkommen.
---
---Abgeleitet statt festgeschrieben: eine fest verdrahtete Stufenliste
---waere in der naechsten Saison falsch, und niemand wuerde es merken.
---@return number[] absteigend
local function levelsInGear(specID, mode, source)
    local gear = ns.Recommend.Gear(specID, mode, source)
    local seen, out = {}, {}
    for _, list in pairs(gear or {}) do
        for _, item in ipairs(list) do
            local level = item.ilvl or 0
            if level > 0 and not seen[level] then
                seen[level] = true
                out[#out + 1] = level
            end
        end
    end
    table.sort(out, function(a, b) return a > b end)
    return out
end

---Welchen Schluesselstein man selbst laeuft.
---
---Hier stand ein Filter "ab Stufe X aufwaerts", und der beantwortete die
---falsche Frage. Interessant ist nicht, was man ausblendet, sondern was
---man SELBST bekommt: wer +10 laeuft, sieht in einer Liste voller 334er
---Gegenstaende nicht, dass daraus bei ihm 311 wird.
---
---Die Stufen kommen aus dem Spiel, nicht aus einer Liste hier: sie
---aendern sich mit jeder Saison, und eine abgeschriebene Tabelle waere
---beim naechsten Patch still falsch.
local function openKeyPicker(anchor)
    local rewards = ns.Compat.RewardTable()
    if #rewards == 0 then return end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end

    -- Welche Schluessel eine Stufe geben - am Ende des Dungeons und in
    -- der Schatzkammer. Nur Beschriftung: gewaehlt wird die Stufe.
    local keysAt = { endOfRun = {}, vault = {} }
    for _, row in ipairs(rewards) do
        for _, which in ipairs({ "endOfRun", "vault" }) do
            local level = row[which]
            if level and level > 0 then
                local list = keysAt[which][level] or {}
                keysAt[which][level] = list
                list[#list + 1] = row.key
            end
        end
    end
    local function keyText(keys)
        table.sort(keys)
        if #keys <= 2 then
            local parts = {}
            for _, k in ipairs(keys) do parts[#parts + 1] = "+" .. k end
            return table.concat(parts, " ")
        end
        return ("+%d-%d"):format(keys[1], keys[#keys])
    end

    local probe = ns.Catalog.ProbeItem and ns.Catalog.ProbeItem()
    local tracks = ns.Catalog.Tracks and ns.Catalog.Tracks()
    local season = probe and tracks and ns.Compat.SeasonTracks(probe)
    local read = C_Item and C_Item.GetDetailedItemLevelInfo

    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(L["LBL_KEY"])
        root:CreateRadio(L["KEY_BEST"], function()
            return ns.Profile.Target() == nil and ns.Profile.KeyLevel() == nil
        end, function()
            ns.Profile.SetTarget(nil)
            ns.Profile.SetKeyLevel(nil)
            UI.Refresh()
        end)

        -- Ohne Pfade (Probegegenstand noch nicht geladen): die Stufen
        -- nach Herkunft, wie bisher.
        if not (season and read) then
            for _, group in ipairs({
                { label = L["KEY_GROUP_RUN"], which = "endOfRun" },
                { label = L["KEY_GROUP_VAULT"], which = "vault" },
            }) do
                local steps = ns.Compat.RewardSteps(group.which)
                if #steps > 0 then
                    local sub = root:CreateButton(group.label)
                    for _, step in ipairs(steps) do
                        local key, which = step.keys[1], group.which
                        sub:CreateRadio(L["KEY_STEP"]:format(step.level, step.label), function()
                            return ns.Profile.KeyLevel() == key and ns.Profile.KeySource() == which
                        end, function()
                            ns.Profile.SetKeyLevel(key, which)
                            UI.Refresh()
                        end)
                    end
                end
            end
            return
        end

        -- Je Pfad ein Untermenue mit ALLEN Raengen - genau wie
        -- KeystoneLoot. Der Client rechnet die Stufe je Rang; daneben
        -- steht, welcher Schluessel sie gibt, oder "Aufwertung", wenn
        -- keiner. Ein Pfad, den nur die Schatzkammer erreicht, heisst
        -- so wie sie.
        for t, track in ipairs(tracks) do
            if season[t] then
                local ranks = {}
                local viaRun, viaVault = false, false
                for rank, bonus in ipairs(track.lists or {}) do
                    local ok, level = pcall(read, ("item:%d::::::::::::1:%d"):format(probe, bonus))
                    if ok and level and level > 0 then
                        local run, vault = keysAt.endOfRun[level], keysAt.vault[level]
                        if run then viaRun = true end
                        if vault then viaVault = true end
                        ranks[#ranks + 1] = { rank = rank, bonus = bonus, level = level, run = run, vault = vault }
                    end
                end
                if viaRun or viaVault then
                    local title = (viaRun and ns.Compat.TrackName(t)) or L["KEY_GROUP_VAULT"]
                    local sub = root:CreateButton(title)
                    for _, r in ipairs(ranks) do
                        local label
                        if r.run then
                            label = L["KEY_STEP"]:format(r.level, keyText(r.run))
                        elseif r.vault then
                            label = L["KEY_STEP_VAULT"]:format(r.level, keyText(r.vault))
                        else
                            label = L["KEY_STEP_UPGRADE"]:format(r.level)
                        end
                        -- Gemerkt wird der Pfad, nicht seine Beschriftung.
                        --
                        -- Vorher stand der fertige Text in den
                        -- SavedVariables, und nach einem Sprachwechsel
                        -- las man "Held 3 - 311" in einem englischen
                        -- Fenster: gespeicherte Uebersetzungen altern.
                        local target = { level = r.level, bonus = r.bonus, track = t, rank = r.rank }
                        sub:CreateRadio(label, function()
                            local cur = ns.Profile.Target()
                            return cur ~= nil and cur.bonus == r.bonus
                        end, function()
                            ns.Profile.SetTarget(target)
                            UI.Refresh()
                        end)
                    end
                end
            end
        end
    end)
end


-- Die Reihenfolge der Gruppen. Fest, damit der Blick nicht wandert:
-- das Flaeschchen steht immer oben, weil es immer gebraucht wird.
-- Dieselbe Aufteilung, die Archon zeigt, und in derselben Reihenfolge:
-- Flaeschchen, Speise, Trank, Waffenoel. Wer beide Seiten nebeneinander
-- legt, soll nicht uebersetzen muessen.
local CONSUM_ORDER = { "flask", "food", "potion", "heal", "oil", "other", "vantus" }

---Wie viele Stueck man haben will.
---
---Die Zahlen sind eine Einstellung, keine Messung - das steht auch in der
---Zeile. Die Empfehlungen sagen, WAS die Besten benutzen; wie viel davon
---jemand mitnimmt, sagen sie nicht, und eine erfundene Zahl als Messung
---auszugeben waere die eine Luege, die dieses Addon sich nicht leisten
---kann.
local function openTargetPicker(anchor, kind)
    local entries = {}
    for _, count in ipairs({ 0, 1, 2, 3, 5, 10, 20, 40 }) do
        entries[#entries + 1] = { count = count, label = tostring(count) }
    end
    entries[#entries + 1] = { own = true, label = L["CONSUM_TARGET_OWN"] }
    contextMenu(anchor, L["CONSUM_" .. kind], entries, function(entry)
        if entry.own then
            UI.AskNumber(L["CONSUM_" .. kind], ns.Profile.ConsumableTarget(kind),
                function(value) ns.Profile.SetConsumableTarget(kind, value) end)
            return
        end
        ns.Profile.SetConsumableTarget(kind, entry.count)
    end)
end

---Was an einer Verbrauchsgut-Zeile einzustellen ist: die Menge, und
---welchen Gegenstand man selbst benutzt.
---
---Der zweite Punkt ist der wichtigere. Gemessen wird, was die Besten
---nehmen - gekauft wird, was man selbst nimmt. Wer seine Speise fuer ein
---Zehntel des Preises kauft, soll nicht unter einer fremden Speise "5
---fehlen" lesen.
---@param anchor table
---@param kind string
---@param id number|nil Gegenstand DIESER Zeile
local function openConsumableMenu(anchor, kind, id)
    local own = ns.Profile.OwnConsumable(kind)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        openTargetPicker(anchor, kind)
        return
    end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(L["CONSUM_" .. kind])

        -- Die Menge.
        local amount = root:CreateButton(L["CONSUM_TARGET_MENU"])
        for _, count in ipairs({ 0, 1, 2, 3, 5, 10, 20, 40 }) do
            amount:CreateRadio(tostring(count),
                function() return ns.Profile.ConsumableTarget(kind) == count end,
                function() ns.Profile.SetConsumableTarget(kind, count) UI.Refresh() end)
        end
        -- Und eine eigene Zahl, fuer alles dazwischen.
        amount:CreateButton(L["CONSUM_TARGET_OWN"], function()
            UI.AskNumber(L["CONSUM_" .. kind], ns.Profile.ConsumableTarget(kind),
                function(value) ns.Profile.SetConsumableTarget(kind, value) end)
        end)

        -- Diese Zeile als eigene Wahl.
        if id and own ~= id then
            root:CreateButton(L["CONSUM_USE_THIS"], function()
                ns.Profile.SetOwnConsumable(kind, id)
                UI.Refresh()
            end)
        end

        -- Oder etwas aus dem Beutel - dort steht, was man wirklich
        -- benutzt, und das sind selten mehr als eine Handvoll.
        local owned = ns.Catalog.OwnedOfKind(kind)
        if #owned > 0 then
            local mine = root:CreateButton(L["CONSUM_FROM_BAGS"])
            for _, entry in ipairs(owned) do
                local name = ns.Compat.ItemInfo(entry.id) or entry.name
                mine:CreateRadio(name .. "  (" .. ns.Compat.ItemCount(entry.id) .. ")",
                    function() return ns.Profile.OwnConsumable(kind) == entry.id end,
                    function() ns.Profile.SetOwnConsumable(kind, entry.id) UI.Refresh() end)
            end
        end

        if own then
            root:CreateButton(L["CONSUM_USE_MEASURED"], function()
                ns.Profile.SetOwnConsumable(kind, nil)
                UI.Refresh()
            end)
        end
    end)
end

---Verbrauchsgueter mit Bestand im Beutel.
---
---Die Anteile sind gemessen, die Zielmengen nicht - jene sind eine
---Einstellung und heissen im Fenster auch so. Siehe Profile.ConsumableTarget.
---@return table[] rows
---@return string|nil fromSource
local function consumableRows(specID, mode, source)
    local list, from = ns.Recommend.Consumables(specID, mode, source)
    if not list then return {}, nil end

    local byKind = {}
    for _, entry in ipairs(list) do
        -- Der Katalog zuerst: dort steht, WAS der Gegenstand ist, und
        -- eine geaenderte Einteilung wirkt sofort statt erst beim
        -- naechsten Sammellauf. Die Beobachtung ist der Rueckfall.
        local kind = (entry.id and ns.Catalog.ConsumableKind(entry.id))
            or entry.kind or "other"
        byKind[kind] = byKind[kind] or {}
        table.insert(byKind[kind], entry)
    end

    -- Die eigene Wahl steht oben und ist der Posten; was gemessen wurde,
    -- rutscht darunter zu den Alternativen. Ist sie in der Messung gar
    -- nicht aufgetaucht - der billige Braten kommt in keiner Rangliste
    -- vor -, kommt sie aus dem Katalog dazu.
    for _, kind in ipairs(CONSUM_ORDER) do
        local own = ns.Profile.OwnConsumable(kind)
        if own then
            local list2 = byKind[kind] or {}
            local found
            for i, entry in ipairs(list2) do
                if entry.id == own then found = table.remove(list2, i) break end
            end
            if not found then
                local known
                for _, entry in ipairs(ns.Catalog.Consumables(kind)) do
                    if entry.id == own then known = entry break end
                end
                found = { id = own, name = known and known.name or nil, pct = nil }
            end
            found.own = true
            table.insert(list2, 1, found)
            byKind[kind] = list2
        end
    end

    local rows = {}
    for _, kind in ipairs(CONSUM_ORDER) do
        -- Nur das haeufigste je Art ist ein Posten; der Rest sind
        -- Alternativen.
        --
        -- Vorher stand unter jedem Flaeschchen "Ziel 2 - 2 fehlen", auch
        -- unter denen, die man gar nicht will. Drei Flaeschchen je zwei
        -- Stueck ist nicht, was jemand einkauft - man nimmt EINES.
        local first = true
        for _, entry in ipairs(byKind[kind] or {}) do
            -- Speisen brauchen hier keine Sonderbehandlung mehr.
            --
            -- Sie hatten eine: solange ich glaubte, die Logs koennten die
            -- Speise nicht nennen, fragte die Zeile zurueck und der
            -- Spieler waehlte aus dem Katalog. Sie koennen es - ueber die
            -- Wirkung statt ueber die Aura. Damit ist eine Speise eine
            -- Zeile wie ein Flaeschchen, und der Notbehelf faellt weg.
            local id = entry.id
            local target = ns.Profile.ConsumableTarget(kind)
            local owned = id and ns.Compat.ItemCount(id) or 0
            -- Dieselbe Ware in anderer Qualitaet, wie bei Steinen und
            -- Verzauberungen: Gold deckt Silber, Silber steht nur dabei.
            -- Diese Zeilen gehen nicht durch List.fill - deshalb stand
            -- beim Heiltrank nichts, obwohl 23 in Silber im Beutel lagen.
            local ownedLower, ownedHigher = 0, 0
            if id then
                local lower, higher = ns.Catalog.Tiers(id)
                for _, other in ipairs(lower) do ownedLower = ownedLower + ns.Compat.ItemCount(other) end
                for _, other in ipairs(higher) do ownedHigher = ownedHigher + ns.Compat.ItemCount(other) end
            end
            local name, link, icon
            if id then
                name, link, icon = ns.Compat.ItemInfo(id)
                if not name then ns.Compat.RequestItem(id) end
            end
            local group = L["CONSUM_" .. kind]
            rows[#rows + 1] = {
                kind = "consumable", ckind = kind,
                alt = not first or nil, own = entry.own,
                id = id, pct = entry.pct,
                name = name or entry.name,
                link = link, icon = icon,
                owned = owned, need = target,
                ownedLower = ownedLower, ownedHigher = ownedHigher,
                maxKey = entry.maxKey,
                buy = first and math.max(0, target - owned - ownedHigher) or 0,
                group = group,
            }
            first = false
        end
    end
    return rows, from
end

---Der Reiter "Erinnerung": was die Erinnerung prueft, und wie.
---
---Oben der Stand je Art - gruen, gelb, rot -, darunter die drei
---Einstellungen, die es gibt. Die Zeilen tragen Gegenstand und
---Fehlmenge, deshalb funktionieren die beiden Einkaufsknoepfe unten
---hier genauso wie unter Verbrauchsguetern.
---@return table[] rows
local function remindRows(mode)
    local rows = {}
    -- Der Reiter folgt der Ansicht, die Ansage dem Charakter.
    --
    -- Wer im Fenster einen anderen Spec ansieht, will hier dessen
    -- Verbrauchsgueter sehen - gezaehlt gegen die eigenen Taschen. Vor
    -- dem Dungeon ist die Frage eine andere, und dort gilt der aktive
    -- Spec.
    for _, row in ipairs(ns.Remind.Status(mode, ns.Profile.SelectedSpec())) do
        local name, link, icon = ns.Compat.ItemInfo(row.id)
        if not name then ns.Compat.RequestItem(row.id) end
        rows[#rows + 1] = {
            kind = "remind", ckind = row.kind, id = row.id,
            name = name or row.name, link = link, icon = icon,
            owned = row.owned, need = row.need, state = row.state,
            buy = math.max(0, row.need - row.owned),
            group = L["REMIND_GROUP_STATUS"],
        }
    end
    -- Und die Verzauberungen und Steine, die am Charakter noch fehlen.
    -- Dieselben Zeilen wie unter "Verzauberungen & Steine", nur auf
    -- das Offene gekuerzt - damit man hier sieht, was noch zu kaufen
    -- ist, und es mit den Knoepfen unten gleich tut.
    local open = 0
    if ns.Profile.Complete() and not ns.Profile.IsForeignClass() then
        for _, row in ipairs(ns.List.Build(ns.Gear.Scan())) do
            if not row.pending and not row.alt and (row.buy or 0) > 0 then
                row.group = L["REMIND_GROUP_ENCHANTS"]
                rows[#rows + 1] = row
                open = open + 1
            end
        end
        if open == 0 then
            rows[#rows + 1] = {
                kind = "note", tone = "ok", text = L["REMIND_ENCHANTS_OK"],
                group = L["REMIND_GROUP_ENCHANTS"],
            }
        end
    end
    local on = ns.Profile.RemindersOn()
    rows[#rows + 1] = {
        kind = "option", label = L["REMIND_OPT_ON"], on = on,
        choices = boolChoices(), pick = function(value) ns.Profile.SetReminders(value) end,
        group = L["REMIND_GROUP_SETTINGS"],
    }
    rows[#rows + 1] = {
        kind = "option", label = L["REMIND_OPT_ENTER"], on = on and ns.Profile.RemindOnEnter(),
        choices = boolChoices(), pick = function(value) ns.Profile.SetRemindOnEnter(value) end,
        group = L["REMIND_GROUP_SETTINGS"],
    }
    rows[#rows + 1] = {
        kind = "option", label = L["REMIND_OPT_AH"], on = on and ns.Profile.RemindAtAuctionHouse(),
        choices = boolChoices(), pick = function(value) ns.Profile.SetRemindAtAuctionHouse(value) end,
        group = L["REMIND_GROUP_SETTINGS"],
    }
    -- Auf welchem Weg erinnert wird. Mehrere gleichzeitig sind erlaubt.
    for _, way in ipairs({ "chat", "window", "warning", "sound" }) do
        rows[#rows + 1] = {
            kind = "option", label = L["REMIND_WAY_" .. way:upper()],
            on = on and ns.Profile.RemindWay(way),
            choices = boolChoices(),
            pick = function(value) ns.Profile.SetRemindWay(way, value) end,
            group = L["REMIND_GROUP_WAYS"],
        }
    end
    -- Und einmal ansehen, wie es aussieht. Eine Einstellung, deren
    -- Wirkung man erst im Ernstfall sieht, stellt niemand bewusst ein.
    rows[#rows + 1] = {
        kind = "option", label = L["REMIND_PREVIEW"], value = L["REMIND_PREVIEW_DO"],
        toggle = function()
            local parts = ns.Remind.Lines(ns.Profile.Mode())
            local linked = ns.Remind.Lines(ns.Profile.Mode(), true)
            local text = #parts > 0
                and L["REMIND_MISSING"]:format(table.concat(parts, ", "))
                or L["REMIND_PREVIEW_EMPTY"]
            local chat = #linked > 0
                and L["REMIND_MISSING"]:format(table.concat(linked, ", "))
                or L["REMIND_PREVIEW_EMPTY"]
            ns.Remind.Deliver(text,
                chat .. "  " .. ns.Remind.AddonLink("remind", L["REMIND_OPEN_LIST"]),
                ns.Remind.Check(ns.Profile.Mode()))
        end,
        group = L["REMIND_GROUP_WAYS"],
    }

    local below = ns.Profile.WarnBelow()
    local shares = {}
    for _, step in ipairs({ 0.25, 0.5, 0.75, 1 }) do
        shares[#shares + 1] = { value = step, label = ("%d %%"):format(math.floor(step * 100 + 0.5)) }
    end
    rows[#rows + 1] = {
        kind = "option", label = L["REMIND_OPT_BELOW"],
        value = ("%d %%"):format(math.floor(below * 100 + 0.5)),
        choices = shares, pick = function(value) ns.Profile.SetWarnBelow(value) end,
        group = L["REMIND_GROUP_SETTINGS"],
    }
    return rows
end

---Die Einstellungen, die nicht zu einem einzelnen Abschnitt gehoeren.
---
---Was den Reiter "Erinnerung" angeht, steht dort und nicht hier: eine
---Einstellung gehoert neben das, was sie steuert. Hier stehen die drei
---Dinge, die das ganze Addon betreffen - wo man es aufmacht, wie gross
---es ist, in welcher Sprache es spricht.
---@return table[] rows
local function settingsRows()
    local rows = {}
    local function switch(label, group, on, apply)
        rows[#rows + 1] = {
            kind = "option", label = label, group = group, on = on,
            choices = boolChoices(), pick = apply,
        }
    end

    switch(L["SET_MINIMAP"], L["SET_GROUP_OPEN"], ns.Profile.MinimapOn(), function(value)
        ns.Profile.SetMinimap(value)
        if ns.Minimap then ns.Minimap.Update() end
    end)
    switch(L["SET_CHARBTN"], L["SET_GROUP_OPEN"], ns.Profile.CharButtonOn(), function(value)
        ns.Profile.SetCharButton(value)
        UI.UpdateCharacterButton()
    end)
    -- Der Tooltip ist der vierte Weg ins Addon, auch wenn er kein Knopf
    -- ist: er beantwortet zwei Fragen, ohne dass man etwas oeffnet.
    switch(L["SET_TOOLTIP"], L["SET_GROUP_OPEN"], ns.Profile.TooltipOn(), function(value)
        ns.Profile.SetTooltipOn(value)
    end)

    -- Schriftgroesse: dieselben Stufen wie /mc scale, zum Auswaehlen.
    --
    -- Sie heisst nicht "Fenstergroesse": die stellt man am Rand ein, und
    -- zwar frei. Was hier skaliert, ist alles IM Fenster - Schrift,
    -- Symbole, Zeilenhoehe.
    local scale = ns.Profile.WindowScale()
    local sizes = {}
    for _, step in ipairs({ 0.8, 0.9, 1, 1.1, 1.25, 1.4 }) do
        sizes[#sizes + 1] = { value = step, label = ("%d %%"):format(math.floor(step * 100 + 0.5)) }
    end
    rows[#rows + 1] = {
        kind = "option", label = L["SET_SCALE"], group = L["SET_GROUP_WINDOW"],
        value = ("%d %%"):format(math.floor(scale * 100 + 0.5)),
        choices = sizes,
        pick = function(value)
            ns.Profile.SetWindowScale(value)
            UI.ApplyScale()
        end,
    }

    -- Sprache. Die Beschriftungen, die schon stehen, wechseln erst nach
    -- /reload - das sagt die Zeile, statt es den Spieler merken zu lassen.
    local current = (MetaCodexDB and MetaCodexDB.lang) or "auto"
    local shown = current == "deDE" and "de" or current == "enUS" and "en" or "auto"
    rows[#rows + 1] = {
        kind = "option", label = L["SET_LANG"], group = L["SET_GROUP_WINDOW"],
        value = L["SET_LANG_" .. shown:upper()],
        choices = {
            { value = "auto", label = L["SET_LANG_AUTO"] },
            { value = "en", label = L["SET_LANG_EN"] },
            { value = "de", label = L["SET_LANG_DE"] },
        },
        pick = function(value)
            ns.Profile.SetLanguage(value)
            ns.Print(L["SET_LANG_RELOAD"])
        end,
    }
    rows[#rows + 1] = {
        kind = "note", text = L["SET_LANG_RELOAD"], group = L["SET_GROUP_WINDOW"],
    }
    -- Zuruecksetzen ist keine Wahl, sondern eine Handlung: ein Menue mit
    -- einem Eintrag waere Theater.
    rows[#rows + 1] = {
        kind = "option", label = L["SET_RESET"], value = L["SET_RESET_DO"],
        toggle = function() UI.ResetWindow() end,
        group = L["SET_GROUP_WINDOW"],
    }

    -- Womit das Fenster aufgeht. Ohne Wahl: mit dem, was zuletzt offen
    -- war - wer immer dasselbe tut, waehlt hier einmal.
    local start = ns.Profile.StartMode()
    local startLabel = L["SET_START_LAST"]
    local modes = { { value = false, label = L["SET_START_LAST"] } }
    for _, m in ipairs(ns.MODES) do
        modes[#modes + 1] = { value = m.key, label = m.label }
        if m.key == start then startLabel = m.label end
    end
    rows[#rows + 1] = {
        kind = "option", label = L["SET_START"], group = L["SET_GROUP_START"],
        value = startLabel, choices = modes,
        pick = function(value) ns.Profile.SetStartMode(value or nil) end,
    }
    return rows
end

---Was dieses Addon gerade ist: Stand der Daten, und was es braucht.
---
---Diese Angaben standen klein und grau in der Kopf- und Fusszeile. Dort
---las sie niemand, und Platz nahmen sie trotzdem. Hier stehen sie
---vollstaendig - vor allem die eine, die vorher NIRGENDS stand: dass die
---Uebergabe ans Auktionshaus Auctionator braucht.
---@return table[] rows
local function infoRows()
    local rows = {}
    local function line(label, value, token)
        rows[#rows + 1] = {
            kind = "info", label = label, value = value, token = token,
            group = L["INFO_GROUP"],
        }
    end

    -- Der Satz, der auf dem Banner steht - hier, wo er hingehoert. In
    -- der Kopfzeile waere er eine vierte Sache neben Name, Spec,
    -- Aktivitaet und Quelle, und die erste, die man nicht mehr liest.
    rows[#rows + 1] = {
        kind = "note", text = L["SLOGAN"], group = L["INFO_GROUP"],
    }

    line(L["INFO_VERSION"], tostring(ns.version or "?"))

    local build, builtOn = ns.Catalog.Stamp()
    line(L["INFO_CATALOG"], build .. "  ·  " .. ns.Compat.DateText(builtOn))

    -- Je Quelle, wann sie zuletzt gemessen hat. Eine Zahl, die drei
    -- Wochen alt ist, sieht genauso aus wie eine von heute - bis man
    -- nachsieht.
    local mode = ns.Profile.LookupMode()
    for _, source in ipairs(ns.Recommend.SourcesFor(mode)) do
        local stamp = ns.Recommend.Stamp(mode, source)
        line(source, ns.Compat.DateText(stamp))
    end

    -- Die Auskunft, die gefehlt hat.
    --
    -- Fehlt Auctionator, hilft der Satz "wird gebraucht" wenig - die
    -- naechste Frage ist "wo bekomme ich es". Die Zeile gibt dann die
    -- Adresse her, wie jede andere Adresse in diesem Addon auch: ein
    -- Klick, ein Feld, Strg+C. Von selbst laedt hier nichts.
    local has = ns.Adapter.Loaded()
    rows[#rows + 1] = {
        kind = "info", label = "Auctionator",
        value = has and L["INFO_AUCTIONATOR_OK"] or L["INFO_AUCTIONATOR_MISSING"],
        token = has and "success" or "danger",
        note = has and L["INFO_AUCTIONATOR_WHY"] or L["INFO_AUCTIONATOR_GET"],
        url = (not has) and "https://www.curseforge.com/wow/addons/auctionator" or nil,
        group = L["INFO_NEEDS"],
    }
    return rows
end

---Verweise auf geschriebene Guides.
---
---Der eine Abschnitt ohne Messung, und der einzige, der fremde Arbeit
---nennt statt sie zu zeigen.
---@return table[] rows
local function guideRows(specID)
    local rows = {}
    for _, link in ipairs(ns.Guides.For(specID)) do
        rows[#rows + 1] = {
            kind = "guide", key = link.key, site = link.site,
            url = link.url, icon = link.icon,
            -- Die Quelle ALS Ueberschrift, nicht in jeder Zeile. Sechsmal
            -- "von X" untereinander wiederholte sich nur; einmal oben
            -- ordnet es.
            group = link.site,
        }
    end
    return rows
end

---Das Profil eines Spielers als Zeilen: Kette, Adresse, Ausruestung.
---
---Die Ausruestung traegt jede Bonus-ID, die raider.io gesehen hat. Der
---Link ist damit DAS Stueck, das der Spieler traegt - Stufe, Pfad,
---Sockel - und das Tooltip zeigt genau das.
---@param who table { mode, specID, name, realm, rank, url }
---@return table[] rows
local RIO_SLOT = {
    head = "Head", neck = "Neck", shoulder = "Shoulders", back = "Back",
    chest = "Chest", waist = "Waist", wrist = "Wrist", hands = "Hands",
    legs = "Legs", feet = "Feet", finger1 = "Rings", finger2 = "Rings",
    trinket1 = "Trinkets", trinket2 = "Trinkets", mainhand = "MainHand", offhand = "OffHand",
}
local RIO_ORDER = { "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist",
    "legs", "feet", "finger1", "finger2", "trinket1", "trinket2", "mainhand", "offhand" }
local function playerViewRows(who)
    local rows = {}
    local profile, why = ns.Recommend.Player(who.mode, who.specID, who.name, who.realm)
    rows[#rows + 1] = { kind = "link", url = who.url, group = who.name .. " \194\183 " .. (who.realm or "") }
    if not profile then
        rows[#rows + 1] = { kind = "note", text = L[why == "loading" and "PLAYER_LOADING" or "PLAYER_NO_PROFILE"] }
        return rows
    end
    if profile.text and profile.text ~= "" then
        rows[#rows + 1] = {
            kind = "loadout", text = profile.text, specID = who.specID,
            nodes = {}, count = 0, pct = nil,
            verified = profile.verified, playerRow = true,
            group = L["SECTION_talents"],
        }
    end
    local bySlot = {}
    for _, piece in ipairs(profile.gear or {}) do bySlot[piece.slot] = piece end
    for _, slot in ipairs(RIO_ORDER) do
        local piece = bySlot[slot]
        if piece then
            -- Der Link traegt Verzauberung und Steine an ihren festen
            -- Plaetzen: item:ID:Verzauberung:Stein1..4:...
            -- Damit steht im Tooltip, was auf dem Stueck sitzt - und
            -- zwar so, wie der Client es schreibt, nicht wie wir es
            -- nacherzaehlen wuerden.
            -- Der Itemstring hat feste Felder, und zwar ELF zwischen der
            -- ID und der Zahl der Bonus-IDs: Verzauberung, vier Steine,
            -- Suffix, Unique, Stufe, Spec, Maske, Kontext. Eines zu wenig,
            -- und die Zahl steht im Feld daneben - der Client wirft den
            -- ganzen Link weg, und das Tooltip bleibt leer.
            local gems = piece.gems or {}
            local fields = {
                piece.enchant or "",
                gems[1] or "", gems[2] or "", gems[3] or "", gems[4] or "",
                "", "", "", "", "", "",
            }
            local link = "item:" .. piece.id .. ":" .. table.concat(fields, ":")
            if piece.b and #piece.b > 0 then
                link = link .. ":" .. #piece.b .. ":" .. table.concat(piece.b, ":")
            else
                link = link .. ":"
            end
            -- Name und Symbol wie in jeder Ausruestungszeile; fehlt der
            -- Name noch, wird er angefordert und die Ansicht frischt auf.
            local name, _, icon = ns.Compat.ItemInfo(piece.id)
            if not name then ns.Compat.RequestItem(piece.id) end
            local group = L["GEARSLOT_" .. (RIO_SLOT[slot] or "Head")]
            rows[#rows + 1] = {
                kind = "gear", id = piece.id, name = name, icon = icon,
                pct = nil, ilvl = piece.ilvl,
                badge = ns.Catalog.ItemKind(piece.id),
                drop = originText(piece.id, ns.Catalog.ItemKind(piece.id), who.mode),
                link = link, atLevel = nil, wantLevel = nil,
                group = group,
            }
            -- Was auf dem Stueck sitzt, steht darunter: erst die
            -- Verzauberung, dann die Steine. Beides stand in den Daten
            -- und wurde nirgends gezeigt - die Ansicht sah aus, als
            -- spielte der Beste unverzaubert.
            -- Klein und eingerueckt: sie gehoeren zum Stueck darueber
            -- und sind nicht selbst eines. Gleich gross nebeneinander
            -- sah die Liste aus, als truege der Spieler drei Haelse.
            local function piecePart(id, labelKey)
                if not id or id == 0 then return end
                local pname, plink, picon = ns.Compat.ItemInfo(id)
                if not pname then ns.Compat.RequestItem(id) end
                rows[#rows + 1] = {
                    kind = "gear", sub = true, id = id, name = pname, icon = picon,
                    link = plink, pct = nil, ilvl = nil,
                    drop = L[labelKey], group = group,
                }
            end
            piecePart(piece.ench, "PLAYER_ENCHANT")
            for _, gem in ipairs(piece.gems or {}) do piecePart(gem, "PLAYER_GEM") end
        end
    end
    return rows
end

---Die Spieler, die eine Quelle gerade oben fuehrt.
---
---Der einzige Abschnitt, der keine Empfehlung ist. Er beantwortet die
---Frage hinter jeder Prozentzahl - WER spielt das so - und ueberlaesst
---die Antwort dem Profil, das die Quelle ohnehin oeffentlich fuehrt.
---@return table[] rows
---@return string|nil fromSource
local function playerRows(specID, mode, source)
    local players, from, foundIn = ns.Recommend.Players(specID, mode, source)
    if not players then return {}, nil end
    local rows = {}
    for _, player in ipairs(players) do
        rows[#rows + 1] = {
            kind = "player", rank = player.rank, rating = player.rating,
            name = player.name,
            realm = player.realm, mode = foundIn, specID = specID,
            -- Die Adresse kommt fertig aus den Daten. Sie hier noch
            -- einmal zusammenzusetzen hiesse, ein Format an zwei
            -- Stellen zu pflegen - und diese haette es falsch gehabt.
            url = player.url,
        }
    end
    return rows, from
end

---Talente: erst der haeufigste ganze Build, dann die Einzelanteile.
---
---Zwei Gruppen, weil es zwei Fragen sind. "Was stelle ich ein" beantwortet
---der Build; "lohnt sich das eine Talent" beantworten die Anteile. Der
---Build ist nicht die Liste der haeufigsten Einzeltalente - die schliessen
---einander teilweise aus und ergaeben zusammen etwas, das so niemand
---spielt.
---@return table[] rows
---@return string|nil fromSource
local function talentRows(specID, mode, source)
    local hero = ns.Profile.HeroTree()
    local picks, build, from = ns.Recommend.Talents(specID, mode, source, hero)
    if not picks then return {}, nil end

    local rows = {}

    -- Der Build als EINE Zeile, nicht als sechsundsiebzig.
    --
    -- Vorher standen hier alle Knoten untereinander. Das sah nach Inhalt
    -- aus und war keiner: niemand tippt einen Build ab. Gebraucht wird
    -- die Importkette - ein Klick, einfuegen, fertig.
    if build and build.nodes and #build.nodes > 0 then
        rows[#rows + 1] = {
            kind = "loadout", nodes = build.nodes, specID = specID,
            -- Die fertige Kette der Quelle, wenn es eine gibt.
            text = build.text,
            pct = build.pct, count = #build.nodes,
            fromBase = build.fromBase, fromMode = build.fromMode,
            fromSource = build.fromSource,
            group = L["TALENT_BUILD"]:format(build.pct or 0),
        }
    end

    -- Und die naechsthaeufigsten, je mit dem Unterschied.
    for _, other in ipairs(ns.Recommend.OtherBuilds(specID, mode, source, hero) or {}) do
        rows[#rows + 1] = {
            kind = "loadout", specID = specID, text = other.text,
            nodes = build and build.nodes or {},
            pct = other.pct, added = other.added, removed = other.removed,
            -- Ein Alternativbuild traegt nur seinen Unterschied, keine
            -- Knotenliste - "0 Talente" darunter war darum wahr und
            -- nutzlos. Gezaehlt wird, worin er abweicht.
            count = #(other.added or {}) + #(other.removed or {}), diff = true,
            group = L["TALENT_OTHERS"],
        }
    end

    -- Darunter nur, wo es wirklich etwas zu entscheiden gibt.
    -- PvP-Talente in eigener Gruppe: sie sitzen in einem anderen
    -- Fenster und sind eine andere Entscheidung.
    -- Der Satz erklaert DIESE Gruppe und steht darum in ihr. Ueber der
    -- ganzen Seite stand er auch ueber den Builds, die er nicht meint.
    local firstPick = true
    for _, pick in ipairs(picks) do
        if not pick.pvp then
            if firstPick then
                rows[#rows + 1] = {
                    kind = "note", text = L["TALENT_PICKS_HINT"],
                    group = L["TALENT_PICKS"],
                }
                firstPick = false
            end
            rows[#rows + 1] = {
                kind = "talent", spell = pick.spell, rank = pick.rank,
                pct = pick.pct, group = L["TALENT_PICKS"],
            }
        end
    end
    for _, pick in ipairs(picks) do
        if pick.pvp then
            rows[#rows + 1] = {
                kind = "talent", spell = pick.spell, rank = pick.rank,
                pct = pick.pct, group = L["TALENT_PVP"],
            }
        end
    end
    return rows, from
end

---Zielwerte als Rangfolge mit den beobachteten Zahlen.
---@return table[] rows
---@return string|nil fromSource
local function statRows(specID, mode, source)
    local stats, from = ns.Recommend.Stats(specID, mode, source)
    if not stats then return {}, nil end

    -- Die eigenen Werte nur fuer die eigene Spec. Fuer eine fremde
    -- Klasse waere "du hast 8421" schlicht falsch - es sind die Werte
    -- des Charakters, der gerade eingeloggt ist.
    local own = not ns.Profile.IsForeignClass()

    local rows = {}
    local widest = 0
    for _, key in ipairs(stats.priority or {}) do
        local value = (stats.values or {})[key]
        widest = math.max(widest, (value and value.rating) or 0)
    end
    for rank, key in ipairs(stats.priority or {}) do
        local value = (stats.values or {})[key]
        local target = value and value.rating or nil
        local mine = own and ns.Compat.OwnRating(key) or nil
        widest = math.max(widest, mine or 0)
        rows[#rows + 1] = {
            kind = "stat", statKey = key, rank = rank,
            pct = value and value.pct or nil,
            rating = target,
            mine = mine,
            -- Der Massstab ist fuer alle Zeilen derselbe, sonst
            -- vergleichen die Balken nichts miteinander.
            scale = widest,
            players = stats.players,
        }
    end
    return rows, from
end

-- ----------------------------------------------------------------- Zeilen

local function acquireRow(index)
    rows = rows or {}
    if rows[index] then return rows[index] end

    local row = CreateFrame("Button", nil, scrollChild)
    row:SetSize(contentWidth(), ROW_HEIGHT)
    -- Auch die rechte Taste: bei Verbrauchsguetern waehlt sie die
    -- Zielmenge. Ohne das kaeme OnClick nur bei Linksklick.
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.bg = S:Fill(row, "bgRaised", 0)

    -- Die beiden Balken der Zielwerte. Sie gehoeren zu jeder Zeile, weil
    -- Zeilen wiederverwendet werden; gezeigt werden sie nur dort, wo ein
    -- Zielwert steht.
    -- Drei Lagen statt zweier Striche.
    --
    -- Vorher lagen zwei vier Pixel hohe Linien uebereinander, und beide
    -- sahen nach Beiwerk aus. Eine Bahn, die sich fuellt, beantwortet
    -- "wie weit bin ich" beim Hinsehen; die Zahlen begruenden es nur.
    row.barTrack = row:CreateTexture(nil, "ARTWORK")
    row.barTrack:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.barTrack:SetVertexColor(S:Color("bgOverlay"))
    row.barTrack:SetHeight(S:Pixel(14))
    row.barTrack:SetPoint("TOPLEFT", BAR_X, -S.space.sm - 6)
    row.barTrack:Hide()

    -- Das Ziel: wie weit die Bahn gefuellt sein SOLL.
    row.barTarget = row:CreateTexture(nil, "ARTWORK")
    row.barTarget:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.barTarget:SetVertexColor(S:Color("accent", 0.30))
    row.barTarget:SetHeight(S:Pixel(14))
    row.barTarget:SetPoint("TOPLEFT", BAR_X, -S.space.sm - 6)
    row.barTarget:Hide()

    -- Der eigene Stand, darueber und voll deckend.
    row.barMine = row:CreateTexture(nil, "OVERLAY")
    row.barMine:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.barMine:SetHeight(S:Pixel(14))
    row.barMine:SetPoint("TOPLEFT", BAR_X, -S.space.sm - 6)
    row.barMine:Hide()

    -- Der eigene Wert als Zahl, unter der Bahn.
    row.own = S:Text(row, "caption", "textMuted")
    row.own:SetPoint("TOPLEFT", BAR_X, -S.space.sm - 24)
    row.own:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(30, 30)
    row.icon:SetPoint("LEFT", S.space.sm, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.title = S:Text(row, "body", "textPrimary")
    row.title:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm)
    row.title:SetWidth(contentWidth() - 140)

    row.detail = S:Text(row, "caption", "textMuted")
    row.detail:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm - 16)
    row.detail:SetWidth(contentWidth() - 140)

    row.share = S:Text(row, "body", "textSecondary")
    row.share:SetPoint("RIGHT", -S.space.md, 0)
    row.share:SetJustifyH("RIGHT")


    -- EIN Klickhaken je Zeile. Was die Zeile beim Klick tut, steht in
    -- row.onClick; davor kommt, was jede Zeile mit Gegenstand kann:
    -- Shift-Klick verlinkt ihn, wie ueberall in WoW. In den Chat als
    -- Link - und steht das Auktionshaus offen, setzt Blizzards eigene
    -- Logik den Namen ins Suchfeld. Ctrl-Klick zeigt ihn im Ankleideraum.
    row:SetScript("OnClick", function(self, button)
        if self.itemID or self.link then
            local link = self.link
            -- Der volle Link, nicht der nackte Itemstring: nur der
            -- traegt Farbe und Namen, und nur der ist im Chat ein Link.
            if self.itemID then
                local _, full = ns.Compat.ItemInfo(self.itemID)
                link = full or link
            end
            if link and IsModifiedClick and (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP")) then
                if HandleModifiedItemClick and HandleModifiedItemClick(link) then return end
                if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return end
            end
        end
        if self.onClick then self.onClick(self, button) end
    end)

    row:SetScript("OnEnter", function(self)
        self.bg:SetAlpha(1)
        -- Der Link wird JETZT gebaut, nicht beim Aufbau der Liste.
        -- Zu dem Zeitpunkt kennt der Client die Grundstufe meist noch
        -- nicht, und ohne Grundstufe gibt es keine Differenz und keine
        -- Bonus-ID. Beim Hovern kennt er sie.
        -- Ein Talent hat keinen Gegenstand, aber ein Tooltip: das des
        -- Zaubers. Vorher stand man ueber "Winde von Al'Akir" und erfuhr
        -- nichts darueber, was es tut.
        if self.spellID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(self.spellID)
            else
                GameTooltip:SetHyperlink("spell:" .. self.spellID)
            end
            GameTooltip:Show()
            return
        end
        local link = self.link
        if self.itemID and self.wantBonus then
            link = ("item:%d::::::::::::1:%d"):format(self.itemID, self.wantBonus)
        elseif self.itemID and self.wantLevel then
            link = ns.Compat.LinkAtLevel(self.itemID, self.wantLevel) or link
        end
        if not link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetAlpha(self.__header and 0 or 0.5)
        GameTooltip:Hide()
    end)

    rows[index] = row
    return row
end

---Alles, was eine Zeile aus ihrem vorigen Leben mitbringt.
---
---Zeilen werden wiederverwendet: dieselbe Zeile ist erst ein Zielwert mit
---zwei Balken, gleich darauf eine Ueberschrift. Was nicht ausdruecklich
---zurueckgesetzt wird, bleibt stehen - und genau das ist passiert: der
---blaue Balken der Zielwerte hing danach quer ueber der Ueberschrift der
---Talente.
---
---Deshalb EINE Stelle statt zweier, die sich auseinanderentwickeln. Wer
---hier etwas ergaenzt, ergaenzt es fuer beide Zeilenarten.
local function resetRow(row)
    row.link = nil
    -- Auch das, woraus der Link beim Hovern entsteht. Eine Zeile wird
    -- wiederverwendet, und eine vergessene Gegenstands-ID zeigte sonst
    -- das Tooltip des Vorgaengers.
    row.itemID, row.wantLevel, row.wantBonus = nil, nil, nil
    -- Und den Zauber: eine Talentzeile zeigt sein Tooltip, und eine
    -- wiederverwendete Zeile zeigte sonst den Zauber des Vorgaengers.
    row.spellID = nil
    row.barTrack:Hide()
    row.barTarget:Hide()
    row.barMine:Hide()
    row.own:Hide()
    row.onClick = nil
end

local function setHeaderRow(row, text)
    resetRow(row)
    row.__header = true
    row.bg:SetAlpha(0)
    row.icon:SetTexture(nil)
    S:Recolor(row.title, "heading")
    row.title:ClearAllPoints()
    row.title:SetPoint("BOTTOMLEFT", S.space.sm, 4)
    row.title:SetText(text:upper())
    row.detail:SetText("")
    row.share:SetText("")
    row:SetHeight(26)
    row.onClick = nil
end

local function openPicker(row, slot, key)
    local entries = {}
    for _, entry in ipairs(ns.Catalog.EnchantsFor(slot)) do
        entries[#entries + 1] = {
            id = entry.id,
            label = ns.Compat.ItemInfo(entry.id) or entry.name,
        }
    end
    contextMenu(row, L["SLOT_" .. slot], entries, function(entry)
        ns.Profile.Set(key, entry.id)
    end)
end

local function setItemRow(row, data)
    resetRow(row)
    row.__header = false
    row.bg:SetAlpha(0.5)
    -- Zielwerte setzen eine groessere Schrift; ohne diese Zeile behielte
    -- sie die naechste Zeile, die dieselbe Zeile wiederverwendet.
    S:ApplyFont(row.title, "body", "textPrimary")
    row.title:ClearAllPoints()
    row.title:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm)
    row:SetHeight(ROW_HEIGHT)

    -- Zielwerte haben keinen Gegenstand: statt eines Symbols traegt die
    -- Zeile ihren Rang, und statt einer Stueckzahl den Prozentwert und das
    -- Rating.
    if data.kind == "stat" then
        row.link = nil
        row.icon:SetTexture(nil)
        row.title:ClearAllPoints()
        row.title:SetPoint("TOPLEFT", S.space.md + 26, -S.space.sm)
        row.title:SetText(L["STAT_" .. data.statKey])
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.md + 26, -S.space.sm - 16)

        -- Eine Bahn, die sich fuellt. Der gemeinsame Massstab bleibt,
        -- damit sichtbar ist, dass ein Kritziel groesser ist als ein
        -- Vielseitigkeitsziel - und darin steht, wie weit man selbst ist.
        row:SetHeight(STAT_ROW_HEIGHT)
        S:ApplyFont(row.title, "title", "textPrimary")

        local scale = math.max(data.scale or 0, 1)
        local BAR_WIDTH = barWidth()
        row.barTrack:SetWidth(BAR_WIDTH)
        row.barTrack:Show()
        row.barTarget:SetWidth(math.max(1, BAR_WIDTH * (data.rating or 0) / scale))
        row.barTarget:Show()

        local reached = data.mine ~= nil and data.mine >= (data.rating or 0)
        if data.mine then
            row.barMine:SetWidth(math.max(1, BAR_WIDTH * data.mine / scale))
            row.barMine:SetVertexColor(S:Color(reached and "success" or "warning"))
            row.barMine:Show()
            row.own:SetText(L["STAT_YOURS"]:format(data.mine, data.rating or 0))
            row.own:Show()
        end

        row.detail:SetText(L["STAT_SHARE"]:format(data.pct or 0))

        -- Rechts steht, was zaehlt: was fehlt. Dort stand der Rang, und
        -- der ist die kleinere Auskunft - die Rangfolge liest man an der
        -- Reihenfolge ab.
        if data.mine and data.rating then
            row.share:SetText(reached and L["STAT_DONE"]
                or L["STAT_GAP"]:format(data.rating - data.mine))
            S:Recolor(row.share, reached and "success" or "warning")
        else
            row.share:SetText("#" .. data.rank)
            S:Recolor(row.share, data.rank == 1 and "accent" or "textMuted")
        end
        return
    end

    if data.kind == "info" then
        row.link = nil
        row.icon:SetTexture(nil)
        row.title:ClearAllPoints()
        row.title:SetPoint("TOPLEFT", S.space.md, -S.space.sm)
        row.title:SetText(data.label)
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.md, -S.space.sm - 16)
        row.detail:SetText(data.note or "")
        row.share:SetText(data.value or "")
        S:Recolor(row.share, data.token or "textSecondary")
        -- Eine Auskunft mit Adresse ist anklickbar; eine ohne nicht.
        row.onClick = data.url and function() UI.ShowLink(data.url) end or nil
        return
    end

    if data.kind == "guide" then
        row.link = nil
        row.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_Book_09")
        row.title:SetText(L["GUIDE_" .. data.key:upper()])
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm - 16)
        -- Die Quelle steht schon in der Ueberschrift; hier steht, was
        -- der Klick tut.
        row.detail:SetText(L["GUIDE_COPY"])
        row.share:SetText("")
        -- Ein Addon kann keinen Browser oeffnen. Es kann die Adresse aber
        -- zum Kopieren hinlegen, und das ist ein Klick mehr, kein Hindernis.
        row.onClick = function() UI.ShowLink(data.url) end
        return
    end

    if data.kind == "player" then
        row.link = nil
        row.icon:SetTexture("Interface\\Icons\\Achievement_PVP_A_A")
        row.title:SetText(data.name or "?")
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm - 16)
        -- Der Realm traegt die Region schon: "Trollbane (EU)".
        row.detail:SetText((data.realm or "") .. "  \194\183  " .. L["PLAYER_COPY"])
        -- Der Platz steht rechts, wo sonst der Anteil steht: beides
        -- ist die Zahl, nach der die Zeile sortiert ist.
        -- Battle.net traegt die Wertung: dann steht sie neben dem Platz.
        local place = data.rank and ("#" .. data.rank) or ""
        if data.rating then place = place .. "  " .. data.rating end
        row.share:SetText(place)
        S:Recolor(row.share, (data.rank or 99) <= 3 and "accent" or "textMuted")
        -- Klick oeffnet das Profil im Fenster; die Adresse gibt es dort.
        row.onClick = function()
            viewingPlayer = {
                mode = data.mode, specID = data.specID, name = data.name,
                realm = data.realm, url = data.url, section = activeSection().key,
            }
            UI.Refresh()
        end
        return
    end

    if data.kind == "remind" then
        row.link = data.link
        row.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.title:SetText(data.name or ("#" .. tostring(data.id)))
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm - 16)
        local token = data.state == "ok" and "success" or data.state == "low" and "warning" or "danger"
        row.detail:SetText(("%s  \194\183  %s  \194\183  |cff%s%s|r"):format(
            L["CONSUM_" .. data.ckind], L["REMIND_HAVE"]:format(data.owned, data.need),
            S:Hex(token), L["REMIND_STATE_" .. data.state:upper()]))
        row.share:SetText(data.buy > 0 and L["NEED"]:format(data.buy) or "")
        S:Recolor(row.share, token)
        -- Wie unter Verbrauchsguetern: Klick waehlt die Zielmenge.
        row.onClick = function(self) openTargetPicker(self, data.ckind) end
        return
    end

    if data.kind == "option" then
        row.link = nil
        row.icon:SetTexture(nil)
        row.title:ClearAllPoints()
        row.title:SetPoint("TOPLEFT", S.space.md, -S.space.sm)
        row.title:SetText(data.label)
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.md, -S.space.sm - 16)
        row.detail:SetText(data.choices and L["OPTION_PICK"] or L["OPTION_CLICK"])
        -- Rechts steht der Wert: "An", "Aus" oder eine Zahl. Ein
        -- Schalter, dessen Stand man nicht sieht, ist keiner.
        if data.value then
            row.share:SetText(data.value)
            S:Recolor(row.share, "accent")
        else
            row.share:SetText(data.on and L["OPTION_ON"] or L["OPTION_OFF"])
            S:Recolor(row.share, data.on and "success" or "textMuted")
        end
        row.onClick = function(self)
            if data.choices then
                -- Auswahl statt Weiterschalten: wer von 80 auf 125 will,
                -- soll nicht viermal klicken und dabei zusehen.
                contextMenu(self, data.label, data.choices, function(entry)
                    data.pick(entry.value)
                end)
            else
                data.toggle()
                UI.Refresh()
            end
        end
        return
    end

    if data.kind == "link" then
        row.link = nil
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_06")
        row.title:SetText(L["PLAYER_PROFILE"])
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm - 16)
        row.detail:SetText(L["GUIDE_COPY"])
        row.share:SetText("")
        row.onClick = function() UI.ShowLink(data.url) end
        return
    end

    if data.kind == "note" then
        row.link = nil
        -- Eine erledigte Meldung bekommt den gruenen Haken. Ohne ihn sah
        -- "Alles verzaubert und gesockelt" aus wie eine Zeile, der das
        -- Symbol fehlt.
        row.icon:SetTexture(data.tone == "ok"
            and "Interface\\RaidFrame\\ReadyCheck-Ready" or nil)
        row.title:SetText(data.text or "")
        S:Recolor(row.title, data.tone == "ok" and "success" or "textSecondary")
        row.detail:SetText("")
        row.share:SetText("")
        row.onClick = nil
        return
    end

    if data.kind == "loadout" then
        row.link = nil
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
        -- Ein Alternativbuild sagt, WORIN er abweicht - nicht, dass er
        -- existiert. "Statt X nimm Y" ist die Auskunft; die Kette ist
        -- nur der Knopf darunter.
        if data.added or data.removed then
            local function names(list, limit)
                local out = {}
                for _, spell in ipairs(list or {}) do
                    if #out >= (limit or 2) then break end
                    local info = C_Spell and C_Spell.GetSpellInfo
                        and C_Spell.GetSpellInfo(spell)
                    out[#out + 1] = (info and info.name) or ("#" .. spell)
                end
                return table.concat(out, ", ")
            end
            local plus, minus = names(data.added), names(data.removed)
            if plus ~= "" and minus ~= "" then
                row.title:SetText(L["TALENT_SWAP"]:format(plus, minus))
            elseif plus ~= "" then
                row.title:SetText(L["TALENT_PLUS"]:format(plus))
            else
                row.title:SetText(L["TALENT_MINUS"]:format(minus))
            end
        elseif data.playerRow then
            row.title:SetText(L["PLAYER_LOADOUT"])
        else
            row.title:SetText(L["LOADOUT_TITLE"])
        end
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm - 16)

        -- Nur eine Kette, die eine Quelle fertig mitliefert. Sie stammt
        -- aus dem Client eines echten Spielers, und damit ist sie richtig
        -- - auch naechsten Dienstag, wenn der Baum-Hash sich aendert.
        -- Ohne Kette sagt die Zeile das, statt einen Knopf zu zeigen,
        -- der nichts tut.
        local ready = data.text ~= nil and data.text ~= ""
        local usable = ready
        local hint = ready and L[data.diff and "LOADOUT_DIFF_HINT" or "LOADOUT_HINT"]:format(data.count)
            or L["LOADOUT_NO_STRING"]
        -- Geliehen? Dann steht es hier, kurz - nicht in der Ueberschrift,
        -- wo es umbrach und abgeschnitten wurde.
        if data.playerRow then
            hint = L[data.verified and "PLAYER_VERIFIED" or "PLAYER_UNVERIFIED"]
        end
        if data.fromBase then
            -- Aus welcher Ansicht geliehen wurde. Hier stand fest
            -- "M+ gesamt", und das war falsch, sobald eine
            -- Bossansicht im Raid sich die Kette der Aktivitaet holte.
            local whence
            for _, entry in ipairs(ns.MODES) do
                if entry.key == data.fromMode then whence = entry.label break end
            end
            hint = hint .. "  \194\183  "
                .. L["LOADOUT_FROM_BASE"]:format(whence or "?")
        end
        if data.fromSource then hint = hint .. "  \194\183  " .. L["LOADOUT_FROM_SOURCE"]:format(data.fromSource) end
        row.detail:SetText(hint)
        S:Recolor(row.detail, usable and "textSecondary" or "warning")
        row.share:SetText(data.pct and (data.pct .. "%") or "")
        S:Recolor(row.share, "accent")

        row.onClick = usable and function(self)
            UI.ShowLink(data.text)
        end or nil
        return
    end


    if data.kind == "runeforge" then
        row.link = nil
        local info = data.spell and C_Spell and C_Spell.GetSpellInfo
            and C_Spell.GetSpellInfo(data.spell)
        row.spellID = data.spell
        row.icon:SetTexture((info and info.iconID) or "Interface\\Icons\\Spell_DeathKnight_RuneTap")
        row.title:SetText((info and info.name) or L["RUNEFORGE_PICK"])
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm - 16)
        local parts = { L["SLOT_weapon"], L["RUNEFORGE_NOTE"] }
        if data.worn then
            parts[#parts + 1] = "|cff" .. S:Hex("success") .. L["ALREADY_DONE"] .. "|r"
        end
        row.detail:SetText(table.concat(parts, "  \194\183  "))
        row.share:SetText(data.pct and (data.pct .. "%") or "")
        S:Recolor(row.share, (data.pct or 0) >= 50 and "accent" or "textMuted")
        row.onClick = nil
        return
    end

    if data.kind == "talent" then
        row.link = nil
        -- Name und Symbol holt der Client aus der Zauber-ID. Gespeichert
        -- ist nur die Zahl, und darum stimmt die Zeile auf jedem Client,
        -- egal in welcher Sprache er laeuft.
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(data.spell)
        local name = info and info.name
        row.icon:SetTexture((info and info.iconID)
            or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.spellID = data.spell
        row.title:SetText(name or ("#" .. tostring(data.spell)))
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm - 16)
        -- Was der Anteil bedeutet, steht in der Zeile und nicht nur in
        -- der Ueberschrift: "82 % der Besten nehmen es".
        local parts = {}
        if (data.rank or 1) > 1 then parts[#parts + 1] = L["TALENT_RANK"]:format(data.rank) end
        if data.pct then parts[#parts + 1] = L["TALENT_SHARE"]:format(data.pct) end
        row.detail:SetText(table.concat(parts, "  \194\183  "))
        row.share:SetText(data.pct and (data.pct .. "%") or "")
        S:Recolor(row.share, (data.pct or 0) >= 50 and "accent" or "textMuted")
        row.onClick = nil
        return
    end

    if data.kind == "consumable" then
        row.link = data.link
        row.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.title:SetText(data.name or ("#" .. tostring(data.id)))
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm - 16)

        local parts = {}
        if data.own then parts[#parts + 1] = L["CONSUM_MINE"] end
        if data.alt then parts[#parts + 1] = L["ALT_ROW"] end
        if data.maxKey and data.maxKey > 0 then
            parts[#parts + 1] = L["MAX_KEY"]:format(data.maxKey)
        end
        if not data.alt then
            parts[#parts + 1] = L["CONSUM_TARGET"]:format(data.need)
        end
        -- Die Zielmenge ist der eine Wert im Fenster, der nicht gemessen
        -- ist. Deshalb steht neben ihr, dass man sie aendern kann.
        if data.owned > 0 then parts[#parts + 1] = L["OWNED"]:format(data.owned) end
        if (data.ownedHigher or 0) > 0 then parts[#parts + 1] = L["OWNED_HIGHER"]:format(data.ownedHigher) end
        if (data.ownedLower or 0) > 0 then parts[#parts + 1] = L["OWNED_LOWER"]:format(data.ownedLower) end
        local status, token
        if data.alt then
            status, token = nil, nil
        elseif data.buy > 0 then
            status, token = L["NEED"]:format(data.buy), "warning"
        else
            status, token = L["IN_BAGS"], "success"
        end
        -- Eine Alternative hat keinen Zustand: sie ist nichts, was
        -- fehlt, sondern etwas, das andere stattdessen nehmen.
        if status then
            row.detail:SetText(("%s  ·  |cff%s%s|r"):format(
                table.concat(parts, "  ·  "), S:Hex(token), status))
        else
            row.detail:SetText(table.concat(parts, "  ·  "))
            S:Recolor(row.detail, "textMuted")
        end
        row.title:SetAlpha(data.alt and 0.75 or 1)
        row.icon:SetAlpha(data.alt and 0.6 or 1)

        row.share:SetText(data.pct and (data.pct .. "%") or "")
        S:Recolor(row.share, (data.pct or 0) >= 50 and "accent" or "textMuted")
        -- Nur die Speisenzeile fragt zurueck. Ein Flaeschchen ist
        -- gemessen; daran gibt es nichts zu waehlen.
        -- Zu waehlen ist nur noch die Menge. Was benutzt wird, ist
        -- gemessen - bei Speisen inzwischen genauso wie bei allem anderen.
        row.onClick = function(self)
            openConsumableMenu(self, data.ckind, data.id)
        end
        return
    end

    if data.kind == "gear" then
        -- Eine Unterzeile - Verzauberung oder Stein - ist keine eigene
        -- Empfehlung, sondern Zubehoer der Zeile darueber. Kleines
        -- Symbol, kleine Schrift, eingerueckt.
        if data.sub then
            row.link = data.link
            row.itemID, row.wantLevel, row.wantBonus = data.id, nil, nil
            if data.id and C_Item and C_Item.RequestLoadItemDataByID then
                pcall(C_Item.RequestLoadItemDataByID, data.id)
            end
            row.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.title:SetText((data.name or ("#" .. tostring(data.id)))
                .. "  |cff808080" .. (data.drop or "") .. "|r")
            row.detail:SetText("")
            row.share:SetText("")
            row.onClick = nil
            return
        end
        -- Der Link auf der gewaehlten Stufe hat Vorrang: an ihm haengt
        -- das Tooltip.
        row.link = data.atLevel or data.link
        row.itemID, row.wantLevel, row.wantBonus = data.id, data.wantLevel, data.wantBonus
        -- Den Gegenstand anfordern, damit er beim Hovern da ist.
        if data.id and C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, data.id)
        end
        row.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.title:SetText(data.name or ("#" .. tostring(data.id)))
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm - 16)
        -- Set- und Handwerksteile werden benannt. Ohne das sehen Kopf
        -- und Schultern aus, als gaebe es nur Tier - die Alternativen
        -- stehen unkommentiert daneben.
        local detail = data.group or ""
        if (data.ilvl or 0) > 0 then
            detail = detail .. "  ·  " .. L["ILVL"]:format(data.ilvl)
        end
        -- Die hoechste Schluesselstufe, bei der es noch getragen wurde.
        -- Beantwortet etwas, das ein Prozentwert nicht kann: ob es auch
        -- oben noch mitgeht oder nur in der Breite beliebt ist.
        if (data.maxKey or 0) > 0 then
            detail = detail .. "  ·  " .. L["MAX_KEY"]:format(data.maxKey)
        end
        if data.badge then
            detail = detail .. "  ·  |cff" .. S:Hex("accent")
                .. L["BADGE_" .. data.badge:upper()] .. "|r"
        end
        -- Schon im Besitz: angelegt zaehlt mehr als im Gepaeck.
        if data.worn then
            detail = detail .. "  ·  |cff" .. S:Hex("success") .. L["GEAR_WORN"] .. "|r"
        elseif data.owned then
            detail = detail .. "  ·  |cff" .. S:Hex("success") .. L["IN_BAGS"] .. "|r"
        end
        -- Der Fundort steht zuletzt, weil er der laengste Teil ist und
        -- die kurzen Angaben sonst nach rechts rutschen.
        if data.drop then
            detail = detail .. "  ·  " .. data.drop
        end
        row.detail:SetText(detail)
        -- Ohne Anteil (das Stueck EINES Spielers) steht rechts nichts -
        -- "0 %" waere eine Aussage, die niemand gemessen hat.
        row.share:SetText(data.pct and (data.pct .. "%") or "")
        S:Recolor(row.share, (data.pct or 0) >= 50 and "accent" or "textMuted")
        row.onClick = nil
        return
    end

    if data.pending then
        row.link = nil
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.title:SetText(L["PICK_" .. data.pending:upper()])
        S:Recolor(row.title, "warning")
        row.detail:SetText(L["SLOT_" .. data.slot] .. "  ·  " .. L["SLOT_COUNT"]:format(data.need or 0))
        row.share:SetText("")
        if data.pending == "tertiary" then
            row.onClick = nil
        else
            row.onClick = function(self) openPicker(self, data.slot, data.pending) end
        end
        return
    end

    row.link = data.link
    row.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_Gem_01")
    row.title:SetText(data.name or data.fallback or ("#" .. tostring(data.id)))

    -- Der Anteil steht rechts und in einer eigenen Spalte: er ist die
    -- Antwort auf "warum das und nicht das andere", und in der Zeile
    -- mitlaufend waere er nur ein weiteres Wort.
    if data.pct then
        row.share:SetText(data.pct .. "%")
        S:Recolor(row.share, data.pct >= 50 and "accent" or "textMuted")
    else
        row.share:SetText("")
    end

    local parts = { L["SLOT_" .. data.slot] }
    if data.kind == "gem" then
        parts[#parts + 1] = L["SOCKETS"]:format(data.need, data.missing or 0)
    else
        parts[#parts + 1] = L["SLOT_COUNT"]:format(data.need)
    end
    if (data.owned or 0) > 0 then parts[#parts + 1] = L["OWNED"]:format(data.owned) end
    if (data.ownedHigher or 0) > 0 then parts[#parts + 1] = L["OWNED_HIGHER"]:format(data.ownedHigher) end
    if (data.ownedLower or 0) > 0 then parts[#parts + 1] = L["OWNED_LOWER"]:format(data.ownedLower) end
    -- Es sitzt etwas anderes auf dem Platz. Nicht "bereits drauf" und
    -- auch nicht "nichts drauf" - beides waere falsch.
    if data.other then
        local otherName = ns.Compat.ItemInfo(data.other)
        if not otherName then ns.Compat.RequestItem(data.other) end
        parts[#parts + 1] = L["OTHER_ENCHANT"]:format(otherName or ("#" .. data.other))
    end

    -- Eine Alternative traegt keinen Zustand: sie ist nichts, was man
    -- noch braucht, sondern etwas, das andere stattdessen nehmen.
    if data.alt then
        local parts = { L["ALT_ROW"] }
        if data.maxKey and data.maxKey > 0 then
            parts[#parts + 1] = L["MAX_KEY"]:format(data.maxKey)
        end
        row.detail:SetText(table.concat(parts, "  ·  "))
        S:Recolor(row.detail, "textMuted")
        row.title:SetAlpha(0.75)
        row.icon:SetAlpha(0.6)
        row.onClick = nil
        return
    end
    row.title:SetAlpha(1)
    row.icon:SetAlpha(1)

    local status, token
    if (data.missing or 0) == 0 then
        status, token = L["ALREADY_DONE"], "success"
    elseif (data.buy or 0) > 0 then
        status, token = L["NEED"]:format(data.buy), "warning"
    else
        status, token = L["IN_BAGS"], "success"
    end
    row.detail:SetText(("%s  ·  |cff%s%s|r"):format(
        table.concat(parts, "  ·  "), S:Hex(token), status))

    if data.slot == "weapon" or data.slot == "legs" then
        row.onClick = function(self) openPicker(self, data.slot, data.slot) end
    else
        row.onClick = nil
    end
end

-- ------------------------------------------------------------- Aufbau

local function build()
    frame = CreateFrame("Frame", "MetaCodexFrame", UIParent)
    -- So gross wie zuletzt gezogen, sonst wie gebaut.
    local savedW, savedH = ns.Profile.WindowSize()
    frame:SetSize(savedW or WIDTH, savedH or HEIGHT)
    -- Dort, wo es zuletzt stand. Beim ersten Mal in der Mitte.
    local point, px, py = ns.Profile.WindowPoint()
    if point then
        frame:SetPoint(point, UIParent, point, px, py)
    else
        frame:SetPoint("CENTER")
    end
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Der Anker und nicht die Bildschirmkoordinate: bei anderer
        -- Aufloesung faende man das Fenster sonst neben dem Bild wieder.
        local anchor, _, _, x, y = self:GetPoint(1)
        if anchor then
            ns.Profile.SetWindowPoint(anchor, math.floor(x + 0.5), math.floor(y + 0.5))
        end
    end)
    S:SetFontScale(ns.Profile.WindowScale())
    frame:SetScale(1)
    -- Ziehbar, in Grenzen. Der Griff sitzt unten rechts; waehrend des
    -- Ziehens zeichnet nichts neu - erst beim Loslassen, einmal.
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H) end
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:Hide()
    tinsert(UISpecialFrames, "MetaCodexFrame")

    S:Fill(frame, "bgBase")
    S:Border(frame, "borderStrong")

    -- --- Kopfzeile ---------------------------------------------------
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER)
    S:Fill(header, "bgRaised")
    S:Border(header, "borderSubtle", 1, { bottom = true })

    -- Das Logo neben dem Namen. Dieselbe Datei wie an der Minimap und
    -- am Charakterfenster - drei Stellen, ein Bild.
    frame.logo = header:CreateTexture(nil, "ARTWORK")
    frame.logo:SetSize(26, 26)
    frame.logo:SetPoint("LEFT", S.space.lg, 0)
    frame.logo:SetTexture("Interface\\AddOns\\MetaCodex\\Media\\Textures\\logo")
    frame.logo:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    frame.titleText = S:Text(header, "display", "textPrimary")
    frame.titleText:SetPoint("LEFT", frame.logo, "RIGHT", S.space.sm, 0)
    frame.titleText:SetText(L["TITLE"])

    local specButton = makeButton(header, 180, 26, "", function(self) UI.OpenSpecPicker(self) end)
    specButton:SetPoint("LEFT", frame.titleText, "RIGHT", S.space.lg, 0)
    frame.specButton = specButton

    local activityButton = makeButton(header, 140, 26, "", function(self) openActivityPicker(self) end)
    activityButton:SetPoint("LEFT", specButton, "RIGHT", S.space.sm, 0)
    frame.activityButton = activityButton

    local sourceButton = makeButton(header, 150, 26, "", function(self) openSourcePicker(self) end)
    sourceButton:SetPoint("LEFT", activityButton, "RIGHT", S.space.sm, 0)
    frame.sourceButton = sourceButton

    headerText = S:Text(header, "caption", "textMuted")
    headerText:SetPoint("RIGHT", -44, 0)
    headerText:SetJustifyH("RIGHT")

    local close = makeButton(header, 26, 26, "X", function() frame:Hide() end)
    close:SetPoint("RIGHT", -S.space.md, 0)

    -- --- Seitenleiste -------------------------------------------------
    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetPoint("TOPLEFT", 0, -HEADER)
    sidebar:SetPoint("BOTTOMLEFT", 0, FOOTER)
    sidebar:SetWidth(sidebarWidth())
    frame.sidebar = sidebar
    S:Fill(sidebar, "bgInset")
    S:Border(sidebar, "borderSubtle", 1, { right = true })

    -- Gruppenkoepfe sind Knoepfe, keine Beschriftungen: sie klappen ihre
    -- Eintraege weg. Die Position der Eintraege wird beim Auffrischen neu
    -- gesetzt, weil sie davon abhaengt, was darueber eingeklappt ist.
    for _, group in ipairs(GROUPS) do
        local head = CreateFrame("Button", nil, sidebar)
        head:SetSize(SIDEBAR - S.space.md * 2, 22)
        head.chevron = S:Text(head, "caption", "heading")
        head.chevron:SetPoint("LEFT", 0, 0)
        head.label = S:Text(head, "caption", "heading")
        head.label:SetPoint("LEFT", 14, 0)
        head.label:SetText(L[group]:upper())
        head.group = group
        head:SetScript("OnEnter", function(self) S:Recolor(self.label, "textPrimary") end)
        head:SetScript("OnLeave", function(self) S:Recolor(self.label, "heading") end)
        head:SetScript("OnClick", function(self)
            ns.Profile.ToggleCollapsed(self.group)
            UI.Refresh()
        end)
        groupHeads[#groupHeads + 1] = head
    end

    for _, section in ipairs(SECTIONS) do
        local button = CreateFrame("Button", nil, sidebar)
        button:SetSize(sidebarWidth() - S.space.md * 2, 28)
        button.bg = S:Fill(button, "bgOverlay", 0)
        button.marker = button:CreateTexture(nil, "ARTWORK")
        button.marker:SetTexture("Interface\\Buttons\\WHITE8X8")
        button.marker:SetPoint("LEFT")
        button.marker:SetSize(S:Pixel(2), 18)
        button.marker:SetVertexColor(S:Color("accent"))
        button.marker:Hide()
        button.label = S:Text(button, "body", "textSecondary")
        button.label:SetPoint("LEFT", S.space.md, 0)
        button.label:SetText(L["SECTION_" .. section.key])
        button.section = section
        button:SetScript("OnEnter", function(self) self.bg:SetAlpha(0.6) end)
        button:SetScript("OnLeave", function(self) self.bg:SetAlpha(self.__active and 1 or 0) end)
        button:SetScript("OnClick", function(self)
            MetaCodexDB.section = self.section.key
            UI.Refresh()
        end)
        navButtons[#navButtons + 1] = button
    end

    -- --- Inhalt --------------------------------------------------------
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", sidebarWidth(), -HEADER)
    frame.content = content
    content:SetPoint("BOTTOMRIGHT", 0, FOOTER)

    sectionTitle = S:Text(content, "title", "textPrimary")
    sectionTitle:SetPoint("TOPLEFT", S.space.xl, -S.space.lg)

    -- Der Stufenfilter gehoert in den Abschnitt, nicht in die ohnehin
    -- volle Kopfzeile: er gilt nur fuer die Ausruestung.
    local levelButton = makeButton(content, 175, 22, "", function(self)
        openKeyPicker(self)
    end)
    levelButton:SetPoint("TOPRIGHT", -S.space.xl, -S.space.lg - 2)
    frame.levelButton = levelButton

    -- Zurueck aus der Spieleransicht: ein Knopf an derselben Stelle,
    -- nicht eine Zeile in der Liste, die aussah wie ein Gegenstand.
    local backButton = makeButton(content, 175, 22, L["PLAYER_BACK"], function()
        viewingPlayer = nil
        UI.Refresh()
    end)
    backButton:SetPoint("TOPRIGHT", -S.space.xl, -S.space.lg - 2)
    backButton:Hide()
    frame.backButton = backButton

    -- Der Dungeonwaehler steht beim Abschnitt, nicht in der Kopfzeile:
    -- dort draengen sich schon Spec, Aktivitaet und Quelle, und ein
    -- vierter Knopf waere der, den man nicht mehr sieht.
    local categoryButton = makeButton(content, 170, 22, "", function(self)
        openCategoryPicker(self, activeSection(), frame.__categories or {})
    end)
    frame.categoryButton = categoryButton

    local slotButton = makeButton(content, 150, 22, "", function(self)
        openSlotPicker(self, ns.Profile.SelectedSpec(),
            ns.Profile.LookupMode(), ns.Profile.Source())
    end)
    frame.slotButton = slotButton

    local originButton = makeButton(content, 170, 22, "", function(self)
        openSourcePickerGear(self, frame.__sources or {})
    end)
    frame.originButton = originButton

    local heroButton = makeButton(content, 170, 22, "", function(self)
        openHeroPicker(self, frame.__heroTrees or {})
    end)
    frame.heroButton = heroButton

    local dungeonButton = makeButton(content, 160, 22, "", function(self)
        openDungeonPicker(self)
    end)
    dungeonButton:SetPoint("TOPRIGHT", -S.space.xl, -S.space.lg - 2)
    frame.dungeonButton = dungeonButton

    sectionCount = S:Text(content, "caption", "textMuted")
    sectionCount:SetJustifyH("RIGHT")

    local controls = CreateFrame("Frame", nil, content)
    controls:SetPoint("TOPLEFT", 0, -S.space.xl - 18)
    controls:SetPoint("TOPRIGHT", 0, -S.space.xl - 18)
    controls:SetHeight(112)

    local cy = -S.space.sm
    cy = makeStatRow(controls, "MAIN_STAT", "main", ns.SECONDARY, cy)
    cy = makeStatRow(controls, "SECOND_STAT", "second", ns.SECONDARY, cy)
    cy = makeStatRow(controls, "TERTIARY", "tertiary", ns.TERTIARY, cy)
    makeCheck(controls, "OPT_ONLY_MISSING", "onlyMissing", S.space.lg, cy)
    makeCheck(controls, "OPT_CHEAP", "cheap", S.space.lg + 220, cy)
    frame.controls = controls

    hintText = S:Text(content, "caption", "textSecondary")
    hintText:SetPoint("TOPLEFT", S.space.xl, -S.space.xl - 140)
    hintText:SetWidth(contentWidth())
    hintText:SetWordWrap(true)
    frame.hintText = hintText

    local scroll = CreateFrame("ScrollFrame", "MetaCodexScroll", content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", S.space.xl, -S.space.xl - 156)
    scroll:SetPoint("BOTTOMRIGHT", -S.space.xl - 20, S.space.md)
    scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(contentWidth(), 1)
    scroll:SetScrollChild(scrollChild)
    frame.scroll = scroll

    -- --- Statuszeile ---------------------------------------------------
    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT")
    footer:SetPoint("BOTTOMRIGHT")
    footer:SetHeight(FOOTER)
    S:Fill(footer, "bgRaised")
    S:Border(footer, "borderSubtle", 1, { top = true })

    sourceText = S:Text(footer, "caption", "textMuted")
    sourceText:SetPoint("LEFT", S.space.lg, 0)
    -- Woher die Zahlen stammen, steht im Zeiger darueber - und
    -- vollstaendig unter "Info". Die Zeile selbst gehoert dem Spieler.
    local sourceHover = CreateFrame("Frame", nil, footer)
    sourceHover:SetPoint("TOPLEFT", sourceText, "TOPLEFT", 0, 2)
    sourceHover:SetPoint("BOTTOMRIGHT", sourceText, "BOTTOMRIGHT", 0, -2)
    sourceHover:EnableMouse(true)
    sourceHover:SetScript("OnEnter", function(self)
        local text = frame and frame.__provenance
        if not text or text == "" then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(text, 1, 1, 1)
        GameTooltip:Show()
    end)
    sourceHover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.sourceHover = sourceHover
    sourceText:SetWidth(math.max(200, (savedW or WIDTH) - 360))

    local search = makeButton(footer, 150, 28, L["BTN_SEARCH"], function() UI.Handover(true) end)
    search:SetPoint("RIGHT", -S.space.lg, 0)
    frame.searchButton = search

    local create = makeButton(footer, 170, 28, L["BTN_CREATE_LIST"], function() UI.Handover(false) end)
    create:SetPoint("RIGHT", search, "LEFT", -S.space.sm, 0)
    frame.createButton = create

    -- Der Griff. Ein kleines Dreieck in der Ecke, wie es jedes Fenster
    -- hat, das man ziehen kann - ohne es sucht niemand danach.
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(frame:GetFrameLevel() + 10)
    grip.tex = grip:CreateTexture(nil, "OVERLAY")
    grip.tex:SetAllPoints()
    grip.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
        -- Waehrend des Ziehens laeuft die Anordnung mit. Vorher sprang
        -- das Fenster erst beim Loslassen in Form, und bis dahin zog man
        -- einen leeren Rahmen ueber die Liste.
        frame:SetScript("OnUpdate", function(self)
            local now = GetTime and GetTime() or 0
            -- Nicht jeden Bildwechsel: zwanzigmal die Sekunde sieht
            -- fluessig aus und rechnet ein Drittel.
            if self.__lastLayout and now - self.__lastLayout < 0.05 then return end
            self.__lastLayout = now
            UI.Relayout()
        end)
    end)
    grip:SetScript("OnMouseUp", function()
        frame:SetScript("OnUpdate", nil)
        frame:StopMovingOrSizing()
        ns.Profile.SetWindowSize(frame:GetWidth(), frame:GetHeight())
        UI.Refresh()
    end)
    frame.grip = grip
end

-- ------------------------------------------------------------ Auffrischen

local currentRows = {}
-- Waehrend am Rand gezogen wird, wird nur neu ANGEORDNET, nicht neu
-- nachgeschlagen: dieselben Zeilen, andere Breite. Was sie sagen, haengt
-- nicht an der Fenstergroesse.
local layoutOnly = false

---Warum ein Abschnitt leer ist.
---
---Frueher stand unter jedem leeren Abschnitt "Noch nicht gebaut" - ein
---Satz, der zur Haelfte gelogen war, sobald die Abschnitte fertig waren.
---Leer heisst jetzt fast immer etwas anderes: diese Plattform misst
---diesen Modus nicht, oder sie misst ihn und kennt diese Spec nicht.
---@param mode string
---@param source string
---@return string
local function emptyReason(mode, source)
    if not ns.Recommend.Ready() then return L["NO_CATALOG"] end
    if not ns.Recommend.HasMode(mode) then return L["NO_MODE_DATA"] end
    if source ~= ns.Recommend.ALL then
        return L["NO_SOURCE_SECTION"]:format(source)
    end
    return L["NO_SPEC_SECTION"]
end

---Hat ein Abschnitt fuer die gewaehlte Aktivitaet ueberhaupt Daten?
---
---DIE Regel des Fensters: nichts anzeigen, was es nicht gibt. Ein
---Abschnitt ohne Daten steht nicht in der Leiste, eine Aktivitaet ohne
---Daten nicht im Waehler, eine Plattform ohne Daten nicht zur Wahl.
---Guides und Info haengen an keiner Messung und sind immer da.
---@param key string
---@param mode string|nil  Vorgabe: die gewaehlte Aktivitaet
---@return boolean
function UI.SectionHasData(key, mode)
    if key == "guides" or key == "info" or key == "settings" then return true end
    if not ns.Recommend.Ready() then return true end
    return ns.Recommend.HasSection(ns.Profile.SelectedSpec(),
        mode or ns.Profile.Mode(), ns.Recommend.ALL, key)
end

function activeSection()
    -- Vorgabe ist der Abschnitt, der etwas zeigt. Auf einem leeren zu
    -- starten waere der schlechteste erste Eindruck, den das Addon machen
    -- kann.
    local key = MetaCodexDB and MetaCodexDB.section or "enchants"
    for _, section in ipairs(SECTIONS) do
        if section.key == key then return section end
    end
    for _, section in ipairs(SECTIONS) do
        if section.key == "enchants" then return section end
    end
    return SECTIONS[1]
end

function UI.Refresh()
    if not frame then return end

    local profile = ns.Profile.Current()
    local section = activeSection()
    if not UI.SectionHasData(section.key) then
        for _, candidate in ipairs(SECTIONS) do
            if UI.SectionHasData(candidate.key) then
                MetaCodexDB.section = candidate.key
                section = candidate
                break
            end
        end
    end

    for key, buttons in pairs(statButtons) do
        for value, button in pairs(buttons) do
            setButtonActive(button, profile[key] == value)
        end
    end
    for key, check in pairs(optionChecks) do
        check:SetChecked(profile[key] and true or false)
    end
    -- Seitenleiste: Gruppen und ihre Eintraege werden bei jedem Auffrischen
    -- neu gestapelt. Ihre Hoehe haengt davon ab, was darueber eingeklappt
    -- ist - feste Positionen aus dem Aufbau waeren nach dem ersten Klick
    -- falsch.
    -- Die Abstaende folgen der Schriftgroesse. Feste 24 und 30 Pixel
    -- waren richtig, solange die Schrift fest war; mit 140 % lagen die
    -- Eintraege uebereinander.
    local fs = S.fontScale or 1
    -- Die Seitenleiste und der Inhalt folgen der Schrift. Ohne das lag
    -- bei 125 % der Titel auf dem Spec-Knopf und der Text der
    -- Seitenleiste auf ihrer Kante.
    frame.logo:SetSize(26 * fs, 26 * fs)
    frame.sidebar:SetWidth(sidebarWidth())
    frame.content:ClearAllPoints()
    frame.content:SetPoint("TOPLEFT", sidebarWidth(), -HEADER)
    frame.content:SetPoint("BOTTOMRIGHT", 0, FOOTER)
    for _, button in ipairs(navButtons) do
        button:SetWidth(sidebarWidth() - S.space.md * 2)
    end
    local y = -S.space.md
    for _, head in ipairs(groupHeads) do
        local collapsed = ns.Profile.IsCollapsed(head.group)
        head:ClearAllPoints()
        head:SetPoint("TOPLEFT", S.space.md, y)
        head:SetHeight(24 * fs)
        head:Show()
        head.chevron:SetText(collapsed and "+" or "-")
        y = y - 24 * fs

        for _, button in ipairs(navButtons) do
            if button.section.group == head.group then
                if collapsed or not UI.SectionHasData(button.section.key) then
                    button:Hide()
                else
                    local active = button.section.key == section.key
                    button.__active = active
                    button.bg:SetAlpha(active and 1 or 0)
                    button.marker:SetShown(active)
                    S:Recolor(button.label, active and "textPrimary" or "textSecondary")
                    button:ClearAllPoints()
                    button:SetPoint("TOPLEFT", S.space.md, y)
                    button:SetHeight(28 * fs)
                    button:Show()
                    -- Der Abstand waechst mit, samt Luft dazwischen.
                    y = y - (28 * fs + 4)
                end
            end
        end
        y = y - S.space.sm
    end

    local specID = ns.Profile.SelectedSpec()
    local foreign = ns.Profile.IsForeignClass()
    local specName = ns.Compat.SpecName(specID)
    local _, classFile = ns.Compat.ClassOfSpec(specID)
    frame.specButton.label:SetText(("|cff%s%s|r%s"):format(
        ns.Compat.ClassColor(classFile),
        specName or L["SPEC_ACTIVE"],
        foreign and " *" or ""))
    -- Die Akzentfarbe folgt der GEZEIGTEN Klasse, nicht der eigenen:
    -- wer fuer den Magier einkauft, sieht das Fenster in Magierblau.
    if classFile then ns.Style:SetAccentFromClass(classFile) end

    -- Zwei Modi, und der Unterschied ist wichtig: `base` ist die
    -- Aktivitaet, unter der die Knoepfe beschriftet werden, `mode` der
    -- Schluessel, unter dem nachgeschlagen wird. Bei gewaehltem Dungeon
    -- sind sie verschieden.
    local base = ns.Profile.Mode()
    -- Ein Modus ohne Daten bleibt nicht stehen: sonst zeigt das Fenster
    -- eine Aktivitaet an, zu der es nichts gibt, und der Waehler bietet
    -- sie nicht einmal mehr an.
    if not ns.Recommend.HasMode(base) and ns.Recommend.Ready() then
        for _, entry in ipairs(ns.MODES) do
            if ns.Recommend.HasMode(entry.key) then
                ns.Profile.SetMode(entry.key)
                base = entry.key
                break
            end
        end
    end
    -- Nachgeschlagen wird unter dem Dungeon DIESES Abschnitts, und nur
    -- wo ein Dungeon ueberhaupt etwas aendert.
    local mode = DUNGEON_SECTIONS[section.key] and ns.Profile.LookupMode(section.key)
        or ns.Profile.Mode()
    for _, entry in ipairs(ns.MODES) do
        if entry.key == base then frame.activityButton.label:SetText(entry.label) end
    end

    -- Steht die Auswahl noch, muessen die Daten auch nach einem
    -- Neuladen wieder da sein - sonst zeigt das Fenster einen
    -- Dungeonnamen und darunter nichts.
    if ns.Profile.Dungeon(section.key) then ns.Data.EnsureDungeons() end
    local dungeons = ns.Recommend.Dungeons(base)
    -- Nur wo der Dungeon wirklich etwas aendert. Eine Verzauberung ist in
    -- jedem Dungeon dieselbe, und "Alle Dungeons" ueber der Steinliste
    -- beantwortet eine Frage, die dort niemand stellt.
    local dungeonMatters = DUNGEON_SECTIONS[section.key] == true
    frame.dungeonButton:SetShown(#dungeons > 0 and dungeonMatters)
    local chosen = ns.Profile.Dungeon(section.key)
    local dungeonLabel = L[(unitLabels(base))]
    for _, dungeon in ipairs(dungeons) do
        if dungeon.key == chosen then
            -- Nur der Boss. Der Raid steht im Menue darueber, und zweimal
            -- dasselbe passt in keinen Knopf: "Der Giftige Abgrund:
            -- Nek'zali die Seelenwinderin" ragte rechts heraus.
            dungeonLabel = unitName(dungeon)
        end
    end
    frame.dungeonButton.label:SetText(dungeonLabel)

    -- Der Held-Baum: nur bei den Talenten, und nur, wo die Daten mehr
    -- als einen kennen. Eine Wahl, die es fuer diese Spec nicht gibt,
    -- faellt weg statt stehenzubleiben.
    local heroTrees = (section.key == "talents" and not viewingPlayer)
        and ns.Recommend.HeroTrees(specID, mode, ns.Profile.Source()) or {}
    frame.__heroTrees = heroTrees
    frame.heroButton:SetShown(#heroTrees > 1)
    local chosenHero = ns.Profile.HeroTree()
    local heroValid = chosenHero == nil
    for _, t in ipairs(heroTrees) do if t.id == chosenHero then heroValid = true end end
    if not heroValid then chosenHero = nil; ns.Profile.SetHeroTree(nil) end
    frame.heroButton.label:SetText(chosenHero and ns.Catalog.SubTreeName(chosenHero) or L["HERO_ALL"])

    -- Eine Quelle, die diesen Modus nicht misst, darf nicht gewaehlt
    -- bleiben - sonst steht im Kopf eine Plattform und in der Liste nichts.
    local wanted = ns.Profile.Source()
    local available = ns.Recommend.SourcesFor(base)
    local valid = wanted == ns.Recommend.ALL
    for _, name in ipairs(available) do if name == wanted then valid = true end end
    -- Und sie muss zu DIESEM Abschnitt etwas haben. Sonst zurueck auf
    -- "alle Plattformen": eine Quelle im Knopf, die hier nichts liefert,
    -- ist keine Auswahl, sondern eine Irrefuehrung.
    if valid and wanted ~= ns.Recommend.ALL then
        valid = ns.Recommend.HasSection(specID, mode, wanted, section.key)
    end
    if not valid then
        wanted = ns.Recommend.ALL
        ns.Profile.SetSource(wanted)
    end
    frame.sourceButton.label:SetText(
        wanted == ns.Recommend.ALL and L["SOURCE_ALL"] or wanted)
    -- Guides und Info messen nichts: dort gibt es weder Aktivitaet noch
    -- Plattform zu waehlen, also stehen die Knoepfe nicht da. Und eine
    -- Plattformwahl mit nur einem Eintrag ist keine.
    local dataSection = section.key ~= "guides" and section.key ~= "info"
    local choices = 0
    for _, name in ipairs(available) do
        if ns.Recommend.HasSection(specID, mode, name, section.key) then choices = choices + 1 end
    end
    frame.activityButton:SetShown(dataSection)
    frame.sourceButton:SetShown(dataSection and choices >= 2)

    -- Die Katalogangabe stand hier klein und grau und wurde nicht
    -- gelesen. Sie steht jetzt unter "Info", vollstaendig.
    headerText:SetText("")

    sectionTitle:SetText(L["SECTION_" .. section.key])

    -- Die Schluesselstufe gilt fuer die Ausruestung, und nur wenn das
    -- Spiel die Belohnungstabelle ueberhaupt kennt.
    frame.levelButton:SetShown(section.key == "gear" and not viewingPlayer
        and #ns.Compat.RewardTable() > 0)
    local targetLabel = ns.Profile.TargetLabel()
    if targetLabel then
        frame.levelButton.label:SetText(targetLabel)
    elseif ns.Profile.KeyLevel() then
        local level = ns.Profile.TargetLevel()
        frame.levelButton.label:SetText(level
            and L["KEY_SHORT"]:format(ns.Profile.KeyLevel(), level) or L["KEY_BEST"])
    else
        frame.levelButton.label:SetText(L["KEY_BEST"])
    end

    -- Der Platzwaehler gehoert nur zur Ausruestung.
    local slots = (section.key == "gear")
        and slotsInGear(specID, mode, wanted) or {}
    frame.slotButton:SetShown(#slots > 1)
    local pickedSlot = ns.Profile.GearSlot()
    -- Eine Auswahl, die es in diesem Modus nicht gibt, faellt weg -
    -- sonst steht ein Platz im Knopf und darunter nichts.
    local valid = pickedSlot == nil
    for _, slot in ipairs(slots) do if slot == pickedSlot then valid = true end end
    if not valid then
        pickedSlot = nil
        ns.Profile.SetGearSlot(nil)
    end
    frame.slotButton.label:SetText(pickedSlot
        and L["GEARSLOT_" .. pickedSlot:gsub("%s", "")] or L["SLOT_ALL"])


    -- Die Kennwertknoepfe sind nur dann eine Frage, wenn keine Daten
    -- vorliegen. Mit Empfehlung waeren sie eine Einladung, etwas zu
    -- aendern, das ohnehin ueberschrieben wird.
    local rec = ns.Recommend.For(specID, mode, wanted)
    -- Nur unter Verzauberungen: dort baut die Wahl die Einkaufsliste.
    -- Unter Talenten oder Spielern haette sie nichts zu tun.
    frame.controls:SetShown(section.key == "enchants" and rec == nil)

    -- Woher die Daten kommen, haengt jetzt am Zeiger; unten steht, was
    -- dem Charakter fehlt.
    local provenance = ""
    if rec then
        local names = wanted == ns.Recommend.ALL
            and table.concat(available, ", ") or wanted
        provenance = UI.ProvenanceLine(names, specID, mode, wanted)
    end
    frame.__provenance = provenance
    -- Unten steht, wer es gemacht hat. Woher die Zahlen stammen, haengt
    -- am Zeiger darueber und steht vollstaendig unter "Info"; was dem
    -- Charakter fehlt, steht in seinen eigenen Abschnitten.
    if ns.Recommend.Ready() and not rec then
        sourceText:SetText("|cff" .. S:Hex("warning") .. L["NO_MODE_DATA"] .. "|r")
    else
        sourceText:SetText(L["CREDIT"])
        S:Recolor(sourceText, "textMuted")
    end

    -- Jeder Abschnitt hat seine eigene Quelle fuer Zeilen. Nur der
    -- Einkaufsabschnitt geht ueber List.Build, weil nur dort die
    -- Ausruestung des Spielers gegengerechnet wird.
    -- Wenn die gewaehlte Plattform zu diesem Abschnitt nichts hat, wird
    -- gefragt, wer etwas hat.
    --
    -- Vorher stand dort eine leere Seite mit einem Hinweis, man moege eine
    -- andere Plattform waehlen. Das ist eine Arbeitsanweisung, keine
    -- Antwort: raider.io fuehrt keine Verbrauchsgueter und wird es auch
    -- nicht, und niemand soll das im Kopf behalten muessen.
    --
    -- Die Statuszeile nennt danach die Quelle, die tatsaechlich geantwortet
    -- hat - sonst waere es eine stille Vertauschung.
    -- Ob der Rueckfall gegriffen hat. Er muss sichtbar sein.
    --
    -- Sonst sieht ein Wechsel der Plattform aus, als passiere nichts:
    -- man waehlt raider.io, und weil die keine Verbrauchsgueter fuehrt,
    -- steht weiter dieselbe Liste da. Still das Richtige zu zeigen ist
    -- gut; still etwas anderes zu zeigen, als oben im Knopf steht, ist es
    -- nicht.
    local fellBack = nil
    local function withFallback(builder)
        local rows, from = builder(wanted)
        if (not rows or #rows == 0) and wanted ~= ns.Recommend.ALL then
            rows, from = builder(ns.Recommend.ALL)
            if rows and #rows > 0 then fellBack = from or true end
        end
        return rows or {}, from
    end

    -- Ein Abschnittswechsel schliesst das Profil.
    if viewingPlayer and viewingPlayer.section ~= section.key then viewingPlayer = nil end
    frame.backButton:SetShown(viewingPlayer ~= nil)

    local fromSource
    if layoutOnly then
        -- Die Zeilen von eben, nur neu gesetzt.
        fromSource = frame.__fromSource
    elseif viewingPlayer then
        currentRows = playerViewRows(viewingPlayer)
        sectionTitle:SetText(viewingPlayer.name)
        hintText:SetText(L["PLAYER_VIEW_HINT"])
    elseif section.key == "gear" then
        currentRows, fromSource = withFallback(function(source)
            return gearRows(specID, mode, source)
        end)
        -- Prozente bedeuten nicht ueberall dasselbe, und das gehoert
        -- dazugesagt: hier der Anteil der gemessenen Spieler, bei den
        -- Verzauberungen der Anteil am Platz, bei den Steinen der an
        -- allen Steinen. Ohne diesen Satz vergleicht man Zahlen, die
        -- verschiedene Fragen beantworten.
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted)
            or L["SHARE_GEAR"])
    elseif section.key == "stats" then
        currentRows, fromSource = withFallback(function(source)
            return statRows(specID, mode, source)
        end)
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted) or "")
    elseif section.key == "consumables" then
        currentRows, fromSource = withFallback(function(source)
            return consumableRows(specID, mode, source)
        end)
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted)
            or (L["CONSUM_HINT"] .. "  " .. L["SHARE_CONSUM"]))
    elseif section.key == "talents" then
        currentRows, fromSource = withFallback(function(source)
            return talentRows(specID, mode, source)
        end)
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted) or "")
    elseif section.key == "players" then
        currentRows, fromSource = withFallback(function(source)
            return playerRows(specID, mode, source)
        end)
        hintText:SetText(#currentRows > 0 and L["PLAYER_HINT"] or L["NO_PLAYERS"])
    elseif section.key == "remind" then
        currentRows = remindRows(mode)
        hintText:SetText(#currentRows > 3 and L["REMIND_HINT"] or emptyReason(mode, wanted))
    elseif section.key == "settings" then
        currentRows = settingsRows()
        hintText:SetText(L["SET_HINT"])
    elseif section.key == "info" then
        currentRows = infoRows()
        hintText:SetText("")
    elseif section.key == "guides" then
        currentRows = guideRows(specID)
        hintText:SetText(#currentRows > 0 and L["GUIDE_HINT"] or L["SOON_GUIDES"])
    elseif section.empty then
        hintText:SetText(L[section.empty])
        currentRows = {}
    elseif not ns.Catalog.Ready() then
        hintText:SetText("|cff" .. S:Hex("danger") .. L["NO_CATALOG"] .. "|r")
        currentRows = {}
    elseif not ns.Profile.Complete() then
        hintText:SetText(L["PICK_HINT"])
        currentRows = {}
    else
        hintText:SetText(foreign and L["FOREIGN_CLASS"]
            or (section.key == "enchants" and L["SHARE_ENCHANTS"] or ""))
        currentRows = ns.List.Build(ns.Gear.Scan())
    end
    frame.__fromSource = fromSource

    -- Wo eine einzelne Quelle geantwortet hat, gehoert ihr Name in die
    -- Statuszeile: bei "alle Plattformen" wird hier nicht gemittelt,
    -- sondern die erste genommen, die etwas hat.
    if fromSource then
        frame.__provenance = UI.ProvenanceLine(fromSource, specID, mode, fromSource)
    end

    -- Die Kategorien kommen aus den Zeilen selbst, also erst hier. Ein
    -- Waehler, der Plaetze anbietet, die es in dieser Spec nicht gibt,
    -- fuehrt in leere Listen.
    local categories = (section.key ~= "gear" and section.key ~= "remind")
        and categoriesIn(section, currentRows) or {}
    frame.__categories = categories
    frame.categoryButton:SetShown(#categories > 1)

    local picked = ns.Profile.Category(section.key)
    local validCat = picked == nil
    for _, cat in ipairs(categories) do
        if cat.key == picked then
            validCat = true
            frame.categoryButton.label:SetText(cat.label)
        end
    end
    if not validCat then
        picked = nil
        ns.Profile.SetCategory(section.key, nil)
    end
    if picked == nil then
        frame.categoryButton.label:SetText(L["CATEGORY_ALL"])
    end

    if picked then
        local kept = {}
        for _, row in ipairs(currentRows) do
            local key = (section.key == "consumables") and row.ckind or row.slot
            if key == picked then kept[#kept + 1] = row end
        end
        currentRows = kept
    end

    -- Der Fundort-Filter der Ausruestung. Erst NACH dem Platzfilter:
    -- die Auswahl soll nur zeigen, was in der sichtbaren Liste steht.
    local sources = (section.key == "gear" and not viewingPlayer) and sourcesIn(currentRows) or {}
    frame.__sources = sources
    frame.originButton:SetShown(#sources > 1)
    local pickedSource = ns.Profile.Category("gearSource")
    local validSource = pickedSource == nil
    for _, src in ipairs(sources) do
        if src.key == pickedSource then
            validSource = true
            frame.originButton.label:SetText(src.label)
        end
    end
    if not validSource then
        pickedSource = nil
        ns.Profile.SetCategory("gearSource", nil)
    end
    if pickedSource == nil then frame.originButton.label:SetText(L["SOURCE_ANY"]) end
    if pickedSource then
        local kept = {}
        for _, row in ipairs(currentRows) do
            if row.sourceKey == pickedSource then kept[#kept + 1] = row end
        end
        currentRows = kept
    end

    -- Die Knopfreihe rechts oben, von rechts nach links.
    --
    -- ERST HIER, und das ist der Punkt: die Kategorien stehen erst fest,
    -- wenn die Zeilen gebaut sind. Vorher gesetzt, war der Kategorie-
    -- knopf noch vom vorigen Abschnitt sichtbar, verbrauchte hundert-
    -- siebzig Pixel und schob den Dungeonknopf bis neben den Titel.
    --
    -- Feste Abstaende waeren ohnehin falsch, sobald ein Knopf wegfaellt -
    -- und zwar unsichtbar falsch: Text unter Knopf.
    local edge, gap = -S.space.xl, S.space.sm
    local ROW = {
        { frame.backButton, 175 }, { frame.levelButton, 175 },
        { frame.slotButton, 150 }, { frame.originButton, 170 },
        { frame.heroButton, 170 }, { frame.categoryButton, 170 },
        { frame.dungeonButton, 160 },
    }

    -- Ein Knopf ist so breit wie das, was darauf steht.
    --
    -- Die Zahlen oben waren Schaetzungen in Pixeln, und sie stimmten fuer
    -- englische Beschriftungen. "Nek'zali die Seelenwinderin" ist
    -- laenger, und der Text stand ueber dem Rand. Gemessen wird jetzt,
    -- und die Zahl oben ist nur noch die Untergrenze: schmaler wird kein
    -- Knopf, breiter darf er werden, bis 340 - danach bricht die Reihe
    -- ohnehin um.
    local function fitted(button, least)
        if not button or not button:IsShown() then return least end
        local text = 0
        if button.label then
            local ok, w = pcall(button.label.GetStringWidth, button.label)
            if ok and type(w) == "number" then text = w end
        end
        local want = math.max(least, math.min(340, math.ceil(text + S.space.lg * 2)))
        button:SetWidth(want)
        return want
    end
    for _, pair in ipairs(ROW) do pair[2] = fitted(pair[1], pair[2]) end

    -- Erst messen, dann setzen.
    --
    -- Neben dem Titel ist nur Platz, solange das Fenster breit genug ist.
    -- Wer es schmal zieht, sah vorher "Ausruestung" halb unter dem ersten
    -- Knopf verschwinden. Passt die Reihe nicht, rueckt sie in eine eigene
    -- Zeile darunter - und alles darunter folgt.
    local strip = 0
    for _, pair in ipairs(ROW) do
        if pair[1]:IsShown() then strip = strip + pair[2] + gap end
    end
    local titleRoom = (sectionTitle:GetStringWidth() or 0) + S.space.xl + S.space.lg
    local avail = contentWidth() - S.space.xl
    -- Zeile 0 teilt sich der Titel mit den Knoepfen; ab Zeile 1 gehoert
    -- die Breite ihnen allein. Passen sie auch dann nicht, geht es eine
    -- Zeile tiefer weiter - bei 760 Pixeln Fensterbreite stehen drei
    -- Waehler eben nicht nebeneinander.
    local headerRows = (strip > 0 and (titleRoom + strip + S.space.xl) > contentWidth()) and 1 or 0
    local function rowOffset() return -S.space.lg - 2 - headerRows * HEADER_ROW end

    local function placeRight(widget, width)
        if not widget:IsShown() then return end
        if (-edge) + width > avail then
            headerRows = headerRows + 1
            edge = -S.space.xl
        end
        widget:ClearAllPoints()
        widget:SetPoint("TOPRIGHT", edge, rowOffset())
        edge = edge - width - gap
    end
    for _, pair in ipairs(ROW) do placeRight(pair[1], pair[2]) end
    local wrapped = headerRows > 0
    sectionCount:ClearAllPoints()
    sectionCount:SetPoint("TOPRIGHT", edge, rowOffset() - 1)

    local shown = currentRows

    -- Die Breite kann sich seit dem letzten Mal geaendert haben - das
    -- Fenster ist ziehbar. Alles, was an ihr haengt, folgt hier nach;
    -- die Zeilen selbst gleich beim Setzen.
    local width = contentWidth()
    scrollChild:SetWidth(width)
    -- Ohne die Kennwert-Zeilen steht der Hinweis direkt unter dem Titel,
    -- auf der Hoehe der Knopfreihe. Dann endet er, wo die Knoepfe
    -- beginnen - sonst liegt "Zurueck zu Top-Spieler" auf dem Satz.
    local reserved = (frame.controls:IsShown() or wrapped) and 0
        or (-S.space.xl - edge)
    hintText:SetWidth(math.max(120, width - reserved))
    sourceText:SetWidth(math.max(200, frame:GetWidth() - 360))

    -- Erst den Hinweis setzen, dann die Liste darunter.
    --
    -- Die Liste begann auf fester Hoehe, der Hinweis stand 16 Pixel
    -- darueber - Platz fuer GENAU EINE Zeile. Ein Satz, der umbrach,
    -- lag auf der ersten Ueberschrift. Jetzt misst der Hinweis sich
    -- selbst und die Liste faengt darunter an.
    local hintTop = 140 + (frame.controls:IsShown() and 0 or -128)
        + headerRows * HEADER_ROW
    hintText:ClearAllPoints()
    hintText:SetPoint("TOPLEFT", S.space.xl, -S.space.xl - hintTop)
    local hintHeight = 0
    if (hintText:GetText() or "") ~= "" then
        hintHeight = math.max(14, hintText:GetStringHeight() or 14)
    end
    local scrollTop = hintTop + hintHeight + (hintHeight > 0 and S.space.md or S.space.sm)
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", S.space.xl, -S.space.xl - scrollTop)
    frame.scroll:SetPoint("BOTTOMRIGHT", -S.space.xl - 20, S.space.md)

    local index, offset, lastSlot = 0, 0, nil
    local function place(row, height)
        if row:GetWidth() ~= width then
            row:SetWidth(width)
            -- Platz fuer das Symbol links und den Anteil rechts. Bei
            -- einem schmalen Fenster ist das der Unterschied zwischen
            -- Umbruch und Text unter dem Prozentwert.
            row.title:SetWidth(math.max(80, width - 140))
            row.detail:SetWidth(math.max(80, width - 140))
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -offset)
        -- Die Zeile ist so hoch, wie sie Platz bekommt. Ohne das blieb
        -- jede Zeile 46 Pixel hoch, auch wo nur 24 gezaehlt wurden - und
        -- die Klickflaeche lag ueber der naechsten Zeile.
        row:SetHeight(height)
        row:Show()
        offset = offset + height
    end

    for _, data in ipairs(shown) do
        -- Ueberschrift, wenn die Gruppe wechselt. Zielwerte tragen keine,
        -- weil eine einzige Ueberschrift ueber vier Zeilen nur den
        -- Abschnittstitel wiederholen wuerde.
        local group = data.group or (data.slot and L["SLOT_" .. data.slot])
        if group and group ~= lastSlot then
            index = index + 1
            local header = acquireRow(index)
            setHeaderRow(header, group)
            place(header, 26 * (S.fontScale or 1))
            lastSlot = group
        end
        index = index + 1
        local row = acquireRow(index)
        setItemRow(row, data)
        -- Eine Unterzeile ist halb so hoch und rueckt ein; die volle
        -- Hoehe bekaeme sonst Zubehoer, das nur mitlaeuft.
        if data.sub then
            row.icon:SetSize(16, 16)
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", S.space.sm + 38, 0)
            row.title:ClearAllPoints()
            row.title:SetPoint("LEFT", S.space.sm + 58, 0)
            S:ApplyFont(row.title, "caption", "textSecondary")
            place(row, SUB_ROW_HEIGHT * (S.fontScale or 1))
        elseif data.kind == "note" then
            -- Eine Notiz ist eine Zeile Text, kein Gegenstand: Symbol
            -- klein, Text daneben auf halber Hoehe.
            row.icon:SetSize(data.tone == "ok" and 18 or 0, data.tone == "ok" and 18 or 0)
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", S.space.md, 0)
            row.title:ClearAllPoints()
            row.title:SetPoint("LEFT", data.tone == "ok" and (S.space.md + 24) or S.space.md, 0)
            S:ApplyFont(row.title, "body", data.tone == "ok" and "success" or "textSecondary")
            place(row, 30)
        else
            row.icon:SetSize(30, 30)
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", S.space.sm, 0)
            -- Schrift und Einrueckung stehen schon: setItemRow setzt sie
            -- am Anfang zurueck, und die Zeile selbst hat danach
            -- entschieden, was sie braucht. Sie hier ein zweites Mal zu
            -- setzen hiess, jede Absicht zu ueberschreiben - graue
            -- Hinweise wurden weiss, und eine Zeile ohne Symbol rueckte
            -- ein, als fehlte eines.
            -- Die zweite Zeile haengt unter der ersten, nicht auf fester
            -- Hoehe.
            --
            -- Ein langer Buildname bricht um, sobald das Fenster schmal
            -- ist - und lag dann auf der Zeile darunter. Was sich
            -- ueberlappt, ist nicht mehr lesbar, und unlesbar ist
            -- schlimmer als abgeschnitten.
            local fs = S.fontScale or 1
            local height = (data.kind == "stat" and STAT_ROW_HEIGHT or ROW_HEIGHT) * fs
            if data.kind ~= "stat" and (row.detail:GetText() or "") ~= "" then
                row.detail:ClearAllPoints()
                row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
                row.detail:SetPoint("RIGHT", row, "RIGHT", -60, 0)
                local titleH = row.title:GetStringHeight() or 14
                local detailH = row.detail:GetStringHeight() or 12
                height = math.max(height, S.space.sm + titleH + 2 + detailH + S.space.sm)
            end
            place(row, height)
        end
    end

    for i = index + 1, #(rows or {}) do rows[i]:Hide() end
    scrollChild:SetHeight(math.max(offset, 1))

    -- Und sagen, wenn eine andere Quelle geantwortet hat.
    if fellBack then
        hintText:SetText(L["SOURCE_FELL_BACK"]:format(
            wanted, type(fellBack) == "string" and fellBack or L["SOURCE_ALL"]))
        S:Recolor(hintText, "warning")
    end

    local missing = ns.List.BuyCount(shown)
    local countText = missing > 0 and L["COUNT_MISSING"]:format(missing) or ""
    -- Deckt die Liste mehr als die gezeigte Spec ab, muss das sichtbar
    -- sein: sonst drueckt jemand den Knopf und bekommt mehr, als er sieht.
    local specCount = #ns.Profile.ShoppingSpecs()
    if specCount > 1 and SHOPPING[section.key] then
        countText = L["COUNT_SPECS"]:format(specCount)
            .. (missing > 0 and ("  ·  " .. L["COUNT_MISSING"]:format(missing)) or "")
    end
    sectionCount:SetText(countText)

    -- "Nichts zu kaufen" nur dort, wo es ueberhaupt etwas zu kaufen gibt.
    --
    -- Die Meldung stand unter JEDEM leeren Abschnitt, auch unter den
    -- Talenten - und dort ist sie nicht nur falsch, sondern verwirrend:
    -- sie beantwortet eine Frage, die niemand gestellt hat.
    local shopping = SHOPPING[section.key] == true
    if shopping and #shown == 0 and ns.Profile.Complete() and ns.Catalog.Ready() then
        hintText:SetText("|cff" .. S:Hex("success") .. L["NOTHING_TO_BUY"] .. "|r"
            .. (profile.onlyMissing and ("  " .. L["SHOW_ALL_HINT"]) or ""))
    end

    -- Die Knoepfe erscheinen nur, wo es etwas zu kaufen gibt.
    frame.createButton:SetShown(shopping)
    frame.searchButton:SetShown(shopping)

    -- "Jetzt suchen" braucht ausserdem ein offenes Auktionshaus. Grau
    -- statt eines Fehlers aus Auctionators Innerem, den der Spieler zu
    -- Recht als unseren liest.
    local usable = ns.Adapter.Loaded()
    local canSearch = usable and ns.Adapter.AuctionHouseOpen()
    frame.createButton:SetEnabled(usable)
    frame.searchButton:SetEnabled(canSearch)
    frame.createButton:SetAlpha(usable and 1 or 0.4)
    frame.searchButton:SetAlpha(canSearch and 1 or 0.4)
end

---Legt eine Adresse zum Kopieren hin.
---
---Ein Addon darf keinen Browser oeffnen - das ist eine Grenze des Spiels,
---keine Bequemlichkeit. Also ein Eingabefeld, in dem der Text schon
---markiert ist: Strg+C, fertig.
---@param url string
function UI.ShowLink(url)
    if not linkFrame then
        linkFrame = CreateFrame("Frame", nil, UIParent)
        -- Breit genug fuer eine ganze Adresse. Die laengste hier ist
        -- ueber achtzig Zeichen lang, und ein Feld, das nur die Mitte
        -- zeigt, ist schlimmer als keines.
        linkFrame:SetSize(620, 128)
        linkFrame:SetPoint("CENTER")
        linkFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        linkFrame:SetToplevel(true)
        linkFrame:EnableMouse(true)

        -- Hintergrund und Rahmen DIREKT auf diesen Rahmen.
        --
        -- Hier stand S:Card(linkFrame) - und das war falsch: Card ERZEUGT
        -- einen Rahmen und gibt ihn zurueck, es verziert keinen. Der
        -- Aufruf hat also einen unsichtbaren Kindrahmen gebaut und
        -- weggeworfen, und der Dialog stand durchsichtig ueber der Liste.
        S:Fill(linkFrame, "bgBase")
        S:Border(linkFrame, "borderStrong")

        local title = S:Text(linkFrame, "title", "textPrimary")
        title:SetPoint("TOPLEFT", S.space.lg, -S.space.lg)
        title:SetText(L["LINK_TITLE"])

        -- Ein eigener Kasten um das Feld: ohne ihn schwebt der Text im
        -- Nichts und sieht nicht nach "hier steht etwas zum Kopieren" aus.
        local well = CreateFrame("Frame", nil, linkFrame)
        well:SetPoint("TOPLEFT", S.space.lg, -S.space.lg - 26)
        well:SetPoint("TOPRIGHT", -S.space.lg, -S.space.lg - 26)
        well:SetHeight(28)
        S:Fill(well, "bgRaised")
        S:Border(well, "borderSubtle")

        local box = CreateFrame("EditBox", nil, well)
        box:SetPoint("TOPLEFT", S.space.sm, -S.space.xs)
        box:SetPoint("BOTTOMRIGHT", -S.space.sm, S.space.xs)
        box:SetAutoFocus(true)
        box:SetFontObject("GameFontHighlightSmall")
        box:SetScript("OnEscapePressed", function() linkFrame:Hide() end)
        box:SetScript("OnEnterPressed", function() linkFrame:Hide() end)
        -- Nicht aenderbar, aber markierbar: was hier steht, soll
        -- herauskopiert und nicht verstellt werden.
        box:SetScript("OnTextChanged", function(self, byUser)
            if byUser then self:SetText(self.__url or "") end
        end)
        linkFrame.box = box

        local hint = S:Text(linkFrame, "caption", "textMuted")
        hint:SetPoint("TOPLEFT", S.space.lg, -S.space.lg - 64)
        hint:SetPoint("TOPRIGHT", -S.space.lg, -S.space.lg - 64)
        hint:SetJustifyH("LEFT")
        hint:SetText(L["LINK_HINT"])

        local close = makeButton(linkFrame, 90, 22, L["LINK_CLOSE"],
            function() linkFrame:Hide() end)
        close:SetPoint("BOTTOMRIGHT", -S.space.lg, S.space.md)
    end

    linkFrame.box.__url = url
    linkFrame.box:SetText(url)
    -- Erst an den Anfang, dann markieren: sonst steht der Cursor am Ende,
    -- das Feld ist dorthin gescrollt, und man sieht die Mitte der Adresse
    -- statt ihres Anfangs.
    linkFrame.box:SetCursorPosition(0)
    linkFrame.box:HighlightText()
    linkFrame.box:SetFocus()
    linkFrame:Show()
end

---Zeigt mehrzeiligen Text zum Kopieren.
---
---Das Gegenstueck zu ShowLink: dort eine Adresse, hier ein ganzer
---Bericht. Der Chat ist zum Lesen da, nicht zum Herausholen - lange
---Zeilen brechen um, und wer sie kopieren will, faengt an zu markieren.
---@param text string
---Das Erinnerungsfenster: eine Zeile, gross genug, dass man sie im
---Pull-Countdown sieht, und klein genug, dass sie nicht das Bild nimmt.
---
---Es ist ziehbar und merkt sich, wohin es geschoben wurde. Es schliesst
---sich nach zwoelf Sekunden von selbst - eine Erinnerung, die stehen
---bleibt, wird zur Tapete.
---@param text string
local REMIND_ROW = 30
-- Der Zeilenvorrat des Erinnerungsfensters liegt HIER und nicht am
-- Rahmen. Ein Feld am Rahmen waere bequemer, aber der Rahmen gehoert
-- Blizzard, und was man dort ablegt, kann jederzeit jemand anders
-- heissen.
local remindRows = {}

---Eine Zeile des Erinnerungsfensters: Symbol, Name, was fehlt.
local function remindWindowRow(parent, index)
    if remindRows[index] then return remindRows[index] end
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(REMIND_ROW)
    row:SetPoint("LEFT", S.space.lg, 0)
    row:SetPoint("RIGHT", -S.space.lg, 0)
    row:RegisterForClicks("LeftButtonUp")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.title = S:Text(row, "body", "textPrimary")
    row.title:SetPoint("LEFT", 28, 0)
    row.state = S:Text(row, "caption", "warning")
    row.state:SetPoint("RIGHT")
    row.state:SetJustifyH("RIGHT")
    -- Und der Titel hoert dort auf, wo der Zustand anfaengt.
    --
    -- "Concentrated Silvermoon Health Potion" lief quer durch die Zahl
    -- daneben: der Titel war nur links verankert und nahm sich die
    -- ganze Zeile. Jetzt hat er eine rechte Kante und kuerzt sich
    -- selbst, statt fremden Text zu ueberschreiben.
    row.title:SetPoint("RIGHT", row.state, "LEFT", -S.space.md, 0)
    row.title:SetWordWrap(false)
    -- Dasselbe wie ueberall: Tooltip beim Zeigen, Shift-Klick verlinkt.
    row:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if self.link and IsModifiedClick and IsModifiedClick("CHATLINK") then
            if HandleModifiedItemClick then HandleModifiedItemClick(self.link) end
        end
    end)
    remindRows[index] = row
    return row
end

---Der Satz unter dem Zeiger: Quelle, Datum, Grundlage.
---
---Die Grundlage stand lange nicht dabei, und das war ein Fehler. Bei
---Daemonologie in hohen Keys zeigte das Fenster 57 % fuer einen Trank,
---eine bekannte Seite 9 % - beides "Warcraft Logs", aber nicht dieselbe
---Frage: hier die Bestenliste (+20 bis +22), dort alles ab einer
---Schwelle. Eine Prozentzahl ohne ihre Stichprobe laedt genau zu
---diesem Vergleich ein.
---@param names string
---@param specID number
---@param mode string
---@param source string|nil
---@return string
function UI.ProvenanceLine(names, specID, mode, source)
    local line = L["SOURCE_LINE"]:format(
        names, ns.Compat.DateText(ns.Recommend.Stamp(mode, source)))
    local sample, from, to = ns.Recommend.Sample(specID, mode, source)
    if not sample then return line end
    line = line .. "  " .. L["SOURCE_SAMPLE"]:format(sample)
    if from and to then line = line .. " " .. L["SOURCE_KEYS"]:format(from, to) end
    return line
end

---Der Zeilenvorrat - nur fuer Tests und /mc probe.
function UI.ReminderRows()
    return remindRows
end

---Traegt Namen und Symbol nach, sobald der Client sie schickt.
---
---Auf einem frischen Charakter kennt er keinen einzigen Gegenstand.
---Das Fenster stand dann mit dem englischen Katalognamen und einem
---Fragezeichen da - richtig in der Sache, falsch im Bild. Der Client
---meldet jeden nachgelieferten Gegenstand einzeln; hier wird genau die
---Zeile nachgezogen, die darauf gewartet hat.
function UI.RefreshReminderNames()
    for _, row in ipairs(remindRows) do
        if row:IsShown() and row.itemID and not row.named then
            local name, link, icon = ns.Compat.ItemInfo(row.itemID)
            if name then
                row.named = true
                row.link = link
                row.title:SetText(name)
                if icon then row.icon:SetTexture(icon) end
            end
        end
    end
end

---Das Erinnerungsfenster: was fehlt, als Liste mit Symbolen, und die
---beiden Knoepfe, die etwas dagegen tun.
---
---Ein Textblock mitten im Bild sagte zwar dasselbe, aber man konnte
---nichts damit anfangen: kein Tooltip, kein Shift-Klick, kein Weg zur
---Einkaufsliste. Jetzt ist es ein kleines Fenster mit denselben
---Handgriffen wie das grosse.
-- Die Liste, die die Erinnerung fuer einen Einkauf angelegt hat.
local remindListName

---Raeumt die Liste der Erinnerung weg, wenn es eine gibt.
function UI.DropTemporaryList()
    if not remindListName then return end
    local name = remindListName
    remindListName = nil
    if ns.Adapter.DeleteList(name) then ns.Print(L["LIST_DROPPED"], name) end
end

---Die beiden Knoepfe des Erinnerungsfensters, nach dem aktuellen Stand.
---
---"Jetzt suchen" braucht Auctionator UND ein offenes Auktionshaus. Beides
---kann sich aendern, waehrend das Fenster schon steht - wer es beim
---Betreten des Dungeons gesehen hat und dann zum Auktionshaus reitet,
---sass sonst vor einem grauen Knopf neben einem offenen Auktionshaus.
function UI.UpdateReminderButtons()
    if not remindFrame then return end
    local usable = ns.Adapter and ns.Adapter.Loaded()
    local canSearch = usable and ns.Adapter.AuctionHouseOpen()
    remindFrame.create:SetEnabled(usable and true or false)
    remindFrame.create:SetAlpha(usable and 1 or 0.4)
    remindFrame.search:SetEnabled(canSearch and true or false)
    remindFrame.search:SetAlpha(canSearch and 1 or 0.4)
end

---@param text string Fuer den Fall, dass es keine Zeilen gibt
---@param list table[]|nil Zeilen aus Remind.Check
function UI.ShowReminder(text, list)
    if not remindFrame then
        remindFrame = CreateFrame("Frame", "MetaCodexReminder", UIParent)
        remindFrame:SetSize(420, 120)
        -- Ueber dem grossen Fenster, nicht darunter.
        --
        -- Beide standen auf HIGH, und wer zuletzt gezeigt wird, gewinnt -
        -- die Vorschau ging also hinter dem Fenster auf, aus dem man sie
        -- angefordert hat.
        remindFrame:SetFrameStrata("DIALOG")
        remindFrame:SetToplevel(true)
        remindFrame:EnableMouse(true)
        remindFrame:SetMovable(true)
        remindFrame:SetClampedToScreen(true)
        remindFrame:RegisterForDrag("LeftButton")
        remindFrame:SetScript("OnDragStart", remindFrame.StartMoving)
        remindFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local anchor, _, _, x, y = self:GetPoint(1)
            if anchor then ns.Profile.SetRemindPoint(anchor, math.floor(x + 0.5), math.floor(y + 0.5)) end
        end)
        S:Fill(remindFrame, "bgBase")
        S:Border(remindFrame, "borderStrong")

        local head = CreateFrame("Frame", nil, remindFrame)
        head:SetPoint("TOPLEFT")
        head:SetPoint("TOPRIGHT")
        head:SetHeight(34)
        S:Fill(head, "bgRaised")
        S:Border(head, "borderSubtle", 1, { bottom = true })
        remindFrame.title = S:Text(head, "title", "warning")
        remindFrame.title:SetPoint("LEFT", S.space.lg, 0)
        remindFrame.title:SetText(L["REMIND_WINDOW_TITLE"])
        remindFrame.close = makeButton(head, 22, 22, "X", function() remindFrame:Hide() end)
        remindFrame.close:SetPoint("RIGHT", -S.space.sm, 0)

        remindFrame.body = S:Text(remindFrame, "body", "textPrimary")
        remindFrame.body:SetPoint("TOPLEFT", S.space.lg, -42)
        remindFrame.body:SetPoint("TOPRIGHT", -S.space.lg, -42)
        remindFrame.body:SetJustifyH("LEFT")
        remindFrame.body:SetWordWrap(true)

        local foot = CreateFrame("Frame", nil, remindFrame)
        foot:SetPoint("BOTTOMLEFT")
        foot:SetPoint("BOTTOMRIGHT")
        foot:SetHeight(40)
        S:Fill(foot, "bgRaised")
        S:Border(foot, "borderSubtle", 1, { top = true })
        remindFrame.search = makeButton(foot, 130, 24, L["BTN_SEARCH"], function()
            UI.HandoverMissing(true)
        end)
        remindFrame.search:SetPoint("RIGHT", -S.space.md, 0)
        remindFrame.create = makeButton(foot, 150, 24, L["BTN_CREATE_LIST"], function()
            UI.HandoverMissing(false)
        end)
        remindFrame.create:SetPoint("RIGHT", remindFrame.search, "LEFT", -S.space.sm, 0)
        -- Solange der Zeiger darauf liegt, laeuft die Uhr nicht: ein
        -- Fenster, das unter der Hand verschwindet, ist aergerlich.
        remindFrame:SetScript("OnEnter", function(self)
            if self.timer then self.timer:Cancel() self.timer = nil end
        end)
        -- Das Auktionshaus kann aufgehen, waehrend das Fenster schon
        -- steht. Dann sind die Knoepfe neu zu bewerten.
        remindFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
        remindFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
        remindFrame:RegisterEvent("ADDON_LOADED")
        -- Was drinsteht, kann sich aendern, waehrend es dasteht.
        --
        -- Die Beutel melden sich nach einem Ladebildschirm verspaetet,
        -- und wer waehrend des Laufs einen Trank kauft oder trinkt,
        -- soll nicht auf eine Zahl von vorhin sehen. Zaehlt wird neu,
        -- nicht nachgetragen.
        remindFrame:RegisterEvent("BAG_UPDATE_DELAYED")
        -- Und die Namen, die der Client nachreicht.
        remindFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        -- Escape schliesst es, wie jedes Fenster in diesem Spiel.
        tinsert(UISpecialFrames, "MetaCodexReminder")
        remindFrame:SetScript("OnEvent", function(self, event)
            UI.UpdateReminderButtons()
            if event == "AUCTION_HOUSE_CLOSED" then UI.DropTemporaryList() end
            if event == "BAG_UPDATE_DELAYED" and self:IsShown() and self.__text then
                UI.ShowReminder(self.__text, ns.Remind.Check(ns.Profile.Mode()))
            end
            -- Nur die eine Zeile, nicht das ganze Fenster: dieses
            -- Ereignis kommt nach dem Vorladen hundertfach.
            if event == "GET_ITEM_INFO_RECEIVED" and self:IsShown() then
                UI.RefreshReminderNames()
            end
        end)
    end

    remindFrame.__text = text

    local point, x, y = ns.Profile.RemindPoint()
    remindFrame:ClearAllPoints()
    if point then
        remindFrame:SetPoint(point, UIParent, point, x, y)
    else
        remindFrame:SetPoint("TOP", UIParent, "TOP", 0, -180)
    end

    -- Die Zeilen. Ohne Liste bleibt der Satz - die Vorschau ohne
    -- Fehlendes sagt genau das.
    local shown = 0
    local y0 = -42
    for i, entry in ipairs(list or {}) do
        local row = remindWindowRow(remindFrame, i)
        local name, link, icon = ns.Compat.ItemInfo(entry.id)
        if not name and entry.id then ns.Compat.RequestItem(entry.id) end
        row.link = link
        row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.itemID = entry.id
        -- Was der Client noch nicht kennt, traegt
        -- UI.RefreshReminderNames nach, sobald er es schickt.
        row.named = name ~= nil
        row.title:SetText(name or entry.name or ("#" .. tostring(entry.id)))
        -- Eigene Schluessel fuer das Fenster. Sie hiessen einmal wie die
        -- des Reiters, und weil Lua bei doppelten Schluesseln den letzten
        -- nimmt, stand im Reiter "%d von %d" statt "knapp".
        if entry.owned > 0 then
            row.state:SetText(L["REMIND_WIN_LOW"]:format(entry.owned, entry.need))
        elseif (entry.lower or 0) > 0 then
            row.state:SetText(L["REMIND_WIN_LOWER"]:format(entry.lower))
        else
            row.state:SetText(L["REMIND_WIN_NONE"])
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", S.space.lg, y0)
        row:SetPoint("TOPRIGHT", -S.space.lg, y0)
        row:Show()
        y0 = y0 - REMIND_ROW
        shown = i
    end
    for i = shown + 1, #remindRows do remindRows[i]:Hide() end

    -- Das Fenster richtet sich nach seiner laengsten Zeile.
    --
    -- Bei 420 Punkten Breite lief "Konzentrierter Silbermondheiltrank"
    -- in die Zahl daneben. Kuerzen waere die schlechtere Antwort: der
    -- Name ist die Auskunft. Also waechst das Fenster mit, bis 640 -
    -- darueber steht es im Bild und nicht mehr daneben.
    local function stringWidth(text)
        local ok, w = pcall(text.GetStringWidth, text)
        return (ok and type(w) == "number") and w or 0
    end
    local needed = 420
    for i = 1, shown do
        local row = remindRows[i]
        local w = 28 + stringWidth(row.title) + S.space.md
            + stringWidth(row.state) + S.space.lg * 2 + S.space.md
        if w > needed then needed = w end
    end
    remindFrame:SetWidth(math.min(needed, 640))

    if shown > 0 then
        remindFrame.body:SetText("")
        remindFrame:SetHeight(42 + shown * REMIND_ROW + 48)
    else
        remindFrame.body:SetText(text)
        remindFrame:SetHeight(42 + math.max(20, remindFrame.body:GetStringHeight() or 20) + 48)
    end

    UI.UpdateReminderButtons()

    remindFrame:Show()
    if remindFrame.Raise then remindFrame:Raise() end
    if remindFrame.timer then remindFrame.timer:Cancel() end
    if C_Timer and C_Timer.NewTimer then
        remindFrame.timer = C_Timer.NewTimer(20, function() remindFrame:Hide() end)
    end
    return remindFrame
end

local numberFrame

---Fragt nach einer Zahl.
---
---Die Stufen im Menue decken den Normalfall; wer zwoelf Fläschchen will,
---soll nicht zwischen zehn und zwanzig waehlen muessen.
---@param title string
---@param current number
---@param accept function(number)
function UI.AskNumber(title, current, accept)
    if not numberFrame then
        numberFrame = CreateFrame("Frame", "MetaCodexNumber", UIParent)
        numberFrame:SetSize(280, 120)
        numberFrame:SetPoint("CENTER")
        numberFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        numberFrame:SetToplevel(true)
        numberFrame:EnableMouse(true)
        S:Fill(numberFrame, "bgBase")
        S:Border(numberFrame, "borderStrong")

        numberFrame.title = S:Text(numberFrame, "title", "textPrimary")
        numberFrame.title:SetPoint("TOPLEFT", S.space.lg, -S.space.lg)

        local box = CreateFrame("EditBox", nil, numberFrame)
        box:SetAutoFocus(true)
        box:SetNumeric(true)
        box:SetMaxLetters(4)
        box:SetFontObject("GameFontHighlightLarge")
        box:SetSize(80, 24)
        box:SetPoint("TOPLEFT", S.space.lg, -S.space.lg - 30)
        S:Fill(box, "bgOverlay")
        S:Border(box, "borderSubtle")
        box:SetScript("OnEscapePressed", function() numberFrame:Hide() end)
        box:SetScript("OnEnterPressed", function() numberFrame.ok:Click() end)
        numberFrame.box = box

        numberFrame.ok = makeButton(numberFrame, 90, 24, L["NUMBER_OK"], function()
            local value = tonumber(numberFrame.box:GetText())
            numberFrame:Hide()
            if value and numberFrame.accept then numberFrame.accept(math.max(0, math.floor(value))) end
            UI.Refresh()
        end)
        numberFrame.ok:SetPoint("BOTTOMRIGHT", -S.space.lg, S.space.md)
        numberFrame.cancel = makeButton(numberFrame, 90, 24, L["LINK_CLOSE"], function()
            numberFrame:Hide()
        end)
        numberFrame.cancel:SetPoint("BOTTOMRIGHT", numberFrame.ok, "BOTTOMLEFT", -S.space.sm, 0)
    end
    numberFrame.title:SetText(title)
    numberFrame.accept = accept
    numberFrame.box:SetText(tostring(current or 0))
    numberFrame.box:HighlightText()
    numberFrame:Show()
    if numberFrame.Raise then numberFrame:Raise() end
    numberFrame.box:SetFocus()
    return numberFrame
end

function UI.ShowText(text)
    if not textFrame then
        textFrame = CreateFrame("Frame", nil, UIParent)
        textFrame:SetSize(700, 420)
        textFrame:SetPoint("CENTER")
        textFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        textFrame:SetToplevel(true)
        textFrame:EnableMouse(true)
        textFrame:SetMovable(true)
        textFrame:RegisterForDrag("LeftButton")
        textFrame:SetScript("OnDragStart", textFrame.StartMoving)
        textFrame:SetScript("OnDragStop", textFrame.StopMovingOrSizing)
        S:Fill(textFrame, "bgBase")
        S:Border(textFrame, "borderStrong")

        local title = S:Text(textFrame, "title", "textPrimary")
        title:SetPoint("TOPLEFT", S.space.lg, -S.space.lg)
        title:SetText(L["TEXT_TITLE"])

        local hint = S:Text(textFrame, "caption", "textMuted")
        hint:SetPoint("TOPLEFT", S.space.lg, -S.space.lg - 22)
        hint:SetText(L["TEXT_HINT"])

        local scroll = CreateFrame("ScrollFrame", nil, textFrame,
            "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", S.space.lg, -S.space.lg - 48)
        scroll:SetPoint("BOTTOMRIGHT", -S.space.xl - 8, S.space.lg + 30)

        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFontObject("GameFontHighlightSmall")
        box:SetWidth(620)
        box:SetScript("OnEscapePressed", function() textFrame:Hide() end)
        -- Nicht aenderbar, aber markierbar.
        box:SetScript("OnTextChanged", function(self, byUser)
            if byUser then self:SetText(self.__text or "") end
        end)
        scroll:SetScrollChild(box)
        textFrame.box = box

        local close = makeButton(textFrame, 90, 22, L["LINK_CLOSE"],
            function() textFrame:Hide() end)
        close:SetPoint("BOTTOMRIGHT", -S.space.lg, S.space.md)
    end

    textFrame.box.__text = text
    textFrame.box:SetText(text)
    textFrame.box:HighlightText()
    textFrame.box:SetFocus()
    textFrame:Show()
end

---Uebergibt die Liste an Auctionator.
---@param searchNow boolean
---Was JETZT fehlt, ans Auktionshaus - aus dem Erinnerungsfenster.
---
---Nicht dasselbe wie der Knopf im grossen Fenster: der uebergibt, was
---auf dem Schirm steht, also den offenen Abschnitt. Vom Erinnerungs-
---fenster aus waere das die falsche Liste - dort steht die Frage "was
---fehlt mir vor dem Pull", und die Antwort sind die knappen
---Verbrauchsgueter UND die offenen Verzauberungen und Steine.
---@param searchNow boolean
function UI.HandoverMissing(searchNow)
    if not ns.Adapter.Loaded() then
        ns.Print(L["NO_AUCTIONATOR"])
        return
    end
    local rows = {}
    for _, row in ipairs(ns.Remind.Status(ns.Profile.Mode())) do
        local buy = math.max(0, (row.need or 0) - (row.owned or 0))
        if buy > 0 then
            rows[#rows + 1] = {
                kind = "consumable", id = row.id, name = row.name,
                buy = buy, need = row.need, owned = row.owned,
            }
        end
    end
    if ns.Profile.Complete() and not ns.Profile.IsForeignClass() then
        for _, row in ipairs(ns.List.Build(ns.Gear.Scan())) do
            if not row.pending and not row.alt and (row.buy or 0) > 0 then
                rows[#rows + 1] = row
            end
        end
    end

    local ok, message, written
    if searchNow then
        ok, message = ns.Adapter.Search(rows)
    else
        ok, message, written = ns.Adapter.CreateList(rows, "remind")
    end
    if ok then
        if not searchNow then
            ns.Print(L["LIST_CREATED"], written, message)
            -- Versprochen wird nur, was auch gehalten wird.
            --
            -- Auctionators Schnittstelle kennt das Loeschen erst in
            -- neueren Fassungen. Wo es fehlt, bleibt die Liste stehen -
            -- dann steht das auch da, statt "nur fuer diesen Einkauf".
            if ns.Adapter.Has("DeleteShoppingList") then
                remindListName = message
                ns.Print(L["LIST_TEMPORARY"])
            else
                ns.Print(L["LIST_STAYS"])
            end
        end
    elseif L[message] ~= message then
        ns.Print(L[message])
    else
        ns.Print(L["LIST_FAILED"], message)
    end
end

function UI.Handover(searchNow)
    if not ns.Adapter.Loaded() then
        ns.Print(L["NO_AUCTIONATOR"])
        return
    end
    if not ns.Profile.Complete() then
        ns.Print(L["PICK_HINT"])
        return
    end
    -- Die Liste darf mehrere Speccs abdecken, das Fenster zeigt eine.
    -- Ohne Zusatzauswahl ist `rows` genau das, was auf dem Schirm steht -
    -- wer nichts eingestellt hat, bekommt also nichts Ueberraschendes.
    local specs = ns.Profile.ShoppingSpecs()
    local rows = currentRows
    if #specs > 1 and SHOPPING[activeSection().key] then
        rows = ns.List.BuildMany(ns.Gear.Scan(), specs)
    end

    local ok, message, written
    if searchNow then
        ok, message = ns.Adapter.Search(rows)
    else
        ok, message, written = ns.Adapter.CreateList(rows, activeSection().key)
    end
    if ok then
        if not searchNow then ns.Print(L["LIST_CREATED"], written, message) end
    elseif L[message] ~= message then
        ns.Print(L[message])
    else
        ns.Print(L["LIST_FAILED"], message)
    end
end

local warmNames = function() ns.Catalog.WarmNames() end

-- Das Auktionshaus geht auf und zu, waehrend das Fenster offen steht.
--
-- "Jetzt suchen" braucht ein offenes Auktionshaus und war deshalb grau -
-- blieb es aber auch, nachdem man es geoeffnet hatte, weil niemand neu
-- zeichnete. Ein grauer Knopf, der grau bleibt, obwohl die Bedingung
-- erfuellt ist, sieht aus wie ein kaputter Knopf.
local ahWatch = CreateFrame("Frame")
ahWatch:RegisterEvent("AUCTION_HOUSE_SHOW")
ahWatch:RegisterEvent("AUCTION_HOUSE_CLOSED")
ahWatch:SetScript("OnEvent", function()
    if frame and frame:IsShown() then UI.Refresh() end
end)

---Die eingestellte Startaktivitaet anwenden, wenn es eine gibt.
local function applyStartMode()
    local start = ns.Profile.StartMode()
    if start and start ~= ns.Profile.Mode() then ns.Profile.SetMode(start) end
end

function UI.Toggle()
    if not frame then build() end
    local ok, reason = ns.Data.Ensure()
    if not ok then ns.Print(L["NO_CATALOG"] .. " (" .. tostring(reason) .. ")") end
    warmNames()
    if frame:IsShown() then
        frame:Hide()
    else
        applyStartMode()
        UI.Refresh()
        frame:Show()
    end
end

---Dieselben Zeilen, neue Breite. Fuer das Ziehen am Rand.
function UI.Relayout()
    if not frame or layoutOnly then return end
    layoutOnly = true
    local ok, err = pcall(UI.Refresh)
    layoutOnly = false
    if not ok then error(err) end
end

---Was gerade in der Fusszeile steht. Fuer Tests und /mc probe.
---@return string
function UI.FooterText()
    return sourceText and sourceText:GetText() or ""
end

function UI.IsShown()
    return frame ~= nil and frame:IsShown()
end

---Ein Knopf im Charakterfenster, neben dem Schliessen-Kreuz.
---
---Wer seine Ausruestung ansieht, fragt sich als naechstes, was fehlt -
---der Weg dorthin soll ein Klick sein, nicht ein Befehl. Der Knopf
---haengt am Fenster selbst und geht mit ihm auf und zu.
function UI.Frame() return frame end

local CHAR_ICON = "Interface\\AddOns\\MetaCodex\\Media\\Textures\\logo"
-- Wo der Knopf ohne eigene Wahl sitzt: am linken Rand, im unteren Drittel,
-- halb ueber der Kante - wie die runden Knoepfe an der Minimap.
-- Ohne eigene Wahl: am RECHTEN Rand, unter dem Zahnrad, halb ueber der
-- Kante. Links lag er hinter dem Rahmenrand und war praktisch unsichtbar.
local CHAR_DEFAULT_X, CHAR_DEFAULT_Y = -4, -232

local function placeCharacterButton(button, host)
    local saved = MetaCodexDB and MetaCodexDB.charButton
    button:ClearAllPoints()
    if saved and saved.x and saved.y then
        -- Selbst geschoben: die Lage ist am linken unteren Eck gemerkt,
        -- weil sie von dort aus in beide Richtungen zaehlt.
        button:SetPoint("CENTER", host, "BOTTOMLEFT", saved.x, saved.y)
    else
        button:SetPoint("CENTER", host, "TOPRIGHT", CHAR_DEFAULT_X, CHAR_DEFAULT_Y)
    end
end

---Fenster auf Anfang: Lage, Groesse und Skalierung wie beim ersten Mal.
function UI.ResetWindow()
    ns.Profile.ResetWindow()
    if not frame then return end
    frame:SetSize(WIDTH, HEIGHT)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    frame:SetScale(1)
    UI.Refresh()
end

---Zeigt einen Abschnitt - gebraucht vom Minimap-Knopf, der auf den
---Schalter fuer sich selbst zeigt.
---@param key string
function UI.OpenSection(key)
    if MetaCodexDB then MetaCodexDB.section = key end
    if not frame then UI.Toggle() return end
    UI.Refresh()
    if not frame:IsShown() then frame:Show() end
end

---Zeigt oder versteckt den Knopf im Charakterfenster, wie eingestellt.
function UI.UpdateCharacterButton()
    local button = UI.AttachCharacterButton()
    if button then button:SetShown(ns.Profile.CharButtonOn()) end
    return button
end

function UI.AttachCharacterButton()
    local host = CharacterFrame
    -- rawget: das Feld soll fehlen duerfen, ohne dass ein Stellvertreter
    -- fuer ein Kind gehalten wird.
    if not host then return nil end
    if rawget(host, "MetaCodexButton") then return host.MetaCodexButton end

    -- Ein rundes Symbol im Stil der Minimap-Knoepfe: Hintergrund, Logo,
    -- Ring, Leuchten beim Hovern. Ein Textkaestchen ging in der Kopfzeile
    -- unter; das Logo erkennt man aus dem Augenwinkel.
    local button = CreateFrame("Button", "MetaCodexCharacterButton", host)
    button:SetSize(40, 40)
    -- Ueber die Rahmenkunst: das Charakterfenster zeichnet seinen Rand
    -- zuletzt, und darunter war vom Knopf nur ein Rand zu sehen.
    button:SetFrameStrata(host.GetFrameStrata and host:GetFrameStrata() or "MEDIUM")
    button:SetFrameLevel((host.GetFrameLevel and host:GetFrameLevel() or 0) + 20)
    button:SetMovable(true)
    button:SetClampedToScreen(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button.background:SetSize(26, 26)
    button.background:SetPoint("CENTER")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(CHAR_ICON)
    button.icon:SetSize(24, 24)
    button.icon:SetPoint("CENTER")
    button.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    if button.CreateMaskTexture then
        local mask = button:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        mask:SetAllPoints(button.icon)
        button.icon:AddMaskTexture(mask)
    end

    button.ring = button:CreateTexture(nil, "OVERLAY")
    button.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.ring:SetSize(68, 68)
    button.ring:SetPoint("TOPLEFT")

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then
            -- Umschalt-Rechtsklick: zurueck an den Platz ohne Wahl.
            if IsShiftKeyDown and IsShiftKeyDown() then
                if MetaCodexDB then MetaCodexDB.charButton = nil end
                placeCharacterButton(self, host)
            end
            return
        end
        UI.Toggle()
    end)
    -- Umschalt-Ziehen verschiebt; die Lage wird relativ zum Fenster
    -- gemerkt, damit der Knopf mit ihm wandert.
    button:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown and IsShiftKeyDown() then self:StartMoving() end
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local cx, cy = self:GetCenter()
        local hx, hy = host:GetLeft(), host:GetBottom()
        if cx and cy and hx and hy and MetaCodexDB then
            MetaCodexDB.charButton = { x = cx - hx, y = cy - hy }
        end
        placeCharacterButton(self, host)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("MetaCodex")
        GameTooltip:AddLine(L["CHARBTN_CLICK"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["CHARBTN_MOVE"], 0.4, 1, 0.4)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    placeCharacterButton(button, host)
    button:SetShown(ns.Profile.CharButtonOn())
    host.MetaCodexButton = button
    return button
end

---Wendet die gemerkte Groesse an - nach /mc scale sofort, nicht erst
---beim naechsten Oeffnen.
function UI.ApplyScale()
    -- Die Schrift skaliert, nicht das Fenster: dessen Groesse zieht man
    -- am Rand. Aber schmaler als sein Inhalt darf es nicht sein - sonst
    -- steht der Titel auf dem ersten Knopf.
    local scale = ns.Profile.WindowScale()
    S:SetFontScale(scale)
    if not frame then return end
    frame:SetScale(1)
    local minW, minH = math.floor(MIN_W * scale), math.floor(MIN_H * scale)
    if frame.SetResizeBounds then frame:SetResizeBounds(minW, minH, MAX_W, MAX_H) end
    local w, h = frame:GetWidth(), frame:GetHeight()
    if w < minW or h < minH then
        frame:SetSize(math.max(w, minW), math.max(h, minH))
        ns.Profile.SetWindowSize(frame:GetWidth(), frame:GetHeight())
    end
    UI.Refresh()
end
