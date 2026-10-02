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

-- Die Breite der Scrollleiste.
--
-- Vier Pixel sahen gut aus und waren mit der Maus nicht zu fassen: ein
-- Ziel, das man dreimal verfehlt, ist kein Bedienteil, sondern eine
-- Anzeige. Zehn sind schmal genug, um nicht aufzutragen, und breit
-- genug, um sie im ersten Anlauf zu treffen.
local SCROLLBAR_WIDTH = 10
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
-- Wie hoch ein Waehler der Kopfreihe ist. Steht hier, weil zwei
-- Rechnungen davon abhaengen: wo die Reihe umbricht, und wo der
-- Hinweis darunter anfaengt.
local HEADER_BUTTON_H = 22
local ROW_HEIGHT = 46
local CARD_HEIGHT = 96
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
local DUNGEON_SECTIONS = { talents = true, consumables = true, enchants = true,
    -- Der Foliant gehoert dazu: er wird in denselben Kaempfen gemessen
    -- und je Dungeon mitgezaehlt, ohne eine einzige Abfrage mehr.
    folio = true }

-- Wessen Profil gerade offen ist, statt eines Abschnitts. Gesetzt vom
-- Klick auf eine Zeile der Rangliste, geloescht vom Zurueck-Knopf oder
-- von jedem Wechsel, der die Rangliste austauscht: Abschnitt,
-- Aktivitaet, Spec. Darum merkt sich der Eintrag, woraus er kam.
local viewingPlayer

-- Welche Ausruestungsplaetze gerade aufgeklappt sind.
--
-- Sechzehn Plaetze mal fuenf Vorschlaege sind neunzig Zeilen, und
-- neunzig Zeilen sind keine Liste mehr, sondern eine Wurst: was man
-- sucht, steht immer irgendwo in der Mitte. Zu sehen ist darum je Platz
-- das meistgetragene Stueck, und ein Klick zeigt den Rest.
--
-- Der Merker lebt nur, solange das Fenster offen ist: aufgeklappt ist
-- ein Blick, keine Vorliebe.
local gearUnfolded = {}


-- Das Fenster der Erinnerung. Eines fuer alle Ansagen, nicht eines je
-- Ansage: zwei uebereinander waeren schlimmer als keines.
local remindFrame

-- Die Gliederung des Menues.
--
-- Gruppiert wird nach der FRAGE, die ein Abschnitt beantwortet, nicht
-- nach der Art seiner Daten. "Verzauberungen", "Verbrauchsgueter" und
-- "Erinnerung" standen unter Ausruestung, weil sie mit Gegenstaenden zu
-- tun haben - sie beantworten aber alle dieselbe andere Frage: bin ich
-- bereit? Die Erinnerung sagt es woertlich ("Fehlt vor dem Start").
--
-- Keine Gruppe mit einem einzigen Eintrag: eine Ueberschrift, unter der
-- genau eine Zeile steht, wiederholt sich nur selbst.
local SECTIONS = {
    { key = "guides",      group = "GROUP_OVERVIEW" },
    { key = "stats",       group = "GROUP_OVERVIEW" },
    { key = "players",     group = "GROUP_OVERVIEW" },

    { key = "talents",     group = "GROUP_TALENTS" },
    -- Der Foliant haengt unter den Talenten, weil er einer ist: fuenf
    -- Reihen, je Reihe eine Wahl. Eigener Eintrag statt eines Reiters
    -- innerhalb der Talente, weil er aus einer anderen Messung stammt
    -- und eine eigene Grundlage ausweist.
    { key = "folio",       group = "GROUP_TALENTS" },

    { key = "gear",        group = "GROUP_GEAR" },
    -- Dieselben Zahlen, andere Achse: die Ausruestung fragt "was traegt
    -- man am Kopf", diese Ansicht "wohin gehe ich dafuer".
    { key = "drops",       group = "GROUP_GEAR" },
    { key = "tier",        group = "GROUP_GEAR" },
    -- Die Verzierungen stehen MIT dem Handwerk auf einer Seite.
    --
    -- Eine Verzierung ist kein eigener Gegenstand, sondern ein Zusatz
    -- auf einem hergestellten Stueck. Zwei Menuepunkte dafuer hiessen,
    -- dieselbe Entscheidung an zwei Stellen zu treffen: welches Stueck
    -- stelle ich her, und was kommt darauf.
    { key = "crafted",     group = "GROUP_GEAR" },

    { key = "enchants",    group = "GROUP_PREP" },
    { key = "consumables", group = "GROUP_PREP" },
    { key = "remind",      group = "GROUP_PREP" },

    { key = "settings",    group = "GROUP_ABOUT" },
    { key = "info",        group = "GROUP_ABOUT" },
}

local GROUPS = { "GROUP_OVERVIEW", "GROUP_TALENTS", "GROUP_GEAR",
    "GROUP_PREP", "GROUP_ABOUT" }

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

---Einem Knopf einen Hinweis geben, der seinen Zustand erklaert.
---
---Ein grauer Knopf ohne Erklaerung ist eine Sackgasse: man sieht, dass
---es nicht geht, und nicht warum. "Jetzt suchen" ist grau, solange das
---Auktionshaus zu ist - das weiss nur, wer es gebaut hat.
---
---Der Text wird bei jedem Ueberfahren neu geholt, nicht einmal gesetzt:
---der Zustand aendert sich, waehrend das Fenster steht.
---@param button table
---@param holen fun(): string|nil, string|nil Titel und Text
local function buttonHint(button, holen)
    -- Ein grauer Knopf bekommt sonst GAR KEINE Mausereignisse.
    --
    -- Genau daran ist der erste Versuch gescheitert: der Hinweis war
    -- gebaut, im Test gruen, und im Spiel kam nichts. WoW schaltet einem
    -- deaktivierten Knopf die Bewegungsskripte ab, und OnEnter feuert
    -- nie - ausgerechnet bei dem Knopf, dessen Zustand erklaert werden
    -- soll.
    if button.SetMotionScriptsWhileDisabled then
        button:SetMotionScriptsWhileDisabled(true)
    end
    button:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(S:Color("bgHover"))
        local titel, text = holen()
        if not titel then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(titel, 1, 1, 1)
        if text then GameTooltip:AddLine(text, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(S:Color(self.__active and "bgHover" or "bgOverlay"))
        GameTooltip:Hide()
    end)
end

---Die beiden Hinweise zur Uebergabe ans Auktionshaus.
---
---An einer Stelle, weil es drei Knoepfe an drei Orten sind: im Fenster,
---in der Erinnerung und in der Liste neben dem Auktionshaus.
local function handoverHints(create, search)
    buttonHint(create, function()
        return L["BTN_CREATE_LIST"], L["HINT_CREATE_LIST"]
    end)
    buttonHint(search, function()
        if ns.Adapter and ns.Adapter.AuctionHouseOpen() then
            return L["BTN_SEARCH"], L["HINT_SEARCH"]
        end
        return L["BTN_SEARCH"], L["HINT_SEARCH_CLOSED"]
    end)
end

local function setButtonActive(button, active)
    button.__active = active and true or false
    button.bg:SetVertexColor(S:Color(active and "bgHover" or "bgOverlay"))
    S:Recolor(button.label, active and "textPrimary" or "textSecondary")
end

local function makeStatRow(parent, labelKey, key, values, y)
    local caption = S:Text(parent, "caption", "textSecondary")
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

---Ein Menue mit Haken statt Knoepfen.
---
---Mehrfachauswahl braucht Haken: wer Krit UND Meisterschaft will,
---soll nicht zweimal ein Menue aufmachen muessen. Das Menue bleibt
---dabei offen - Blizzards Menue-API macht das von selbst, solange der
---Rueckruf true liefert.
---
---Ohne Menue-API bleibt Durchschalten: dieselbe Notloesung wie beim
---einfachen Menue, damit ein Client ohne MenuUtil nicht stehenbleibt.
local function checkMenu(anchor, title, entries)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, root)
            root:CreateTitle(title)
            for _, entry in ipairs(entries) do
                if entry.spacer then
                    root:CreateDivider()
                else
                    root:CreateCheckbox(entry.label,
                        function() return entry.on() end,
                        function()
                            entry.toggle()
                            UI.Refresh()
                            return MenuResponse and MenuResponse.Refresh or true
                        end)
                end
            end
        end)
        return
    end
    if #entries == 0 then return end
    entries[1].toggle()
    UI.Refresh()
end

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

-- Welcher Platz zweimal da ist.
--
-- Ringe und Schmuckstuecke traegt man zu zweit, und das sind zwei
-- Entscheidungen, nicht eine. In der Liste stand darueber nur "RINGE",
-- und wer die Prozente las, konnte meinen, es gehe um einen Ring. Die
-- Waffenhaende stehen ohnehin schon als zwei eigene Ueberschriften da.
local GEAR_SLOTS = { ["Rings"] = 2, ["Trinkets"] = 2 }

---"1 Platz" oder "2 Plaetze" - und nicht "1 Platz/Plaetze".
---@param n number|nil
---@return string
local function slotCount(n)
    n = tonumber(n) or 0
    if n == 1 then return L["SLOT_COUNT_ONE"] end
    return L["SLOT_COUNT"]:format(n)
end

---Dasselbe fuer Sockel: "1 socket", nicht "1 sockets".
---
---Im Deutschen heisst beides "Sockel", im Englischen nicht - und dort
---stand am besonderen Sockel, von dem es nur einen gibt, dauerhaft
---"1 sockets, 0 empty".
---@param n number|nil
---@return string
local function socketCount(n)
    n = tonumber(n) or 0
    if n == 1 then return L["SOCKET_COUNT_ONE"] end
    return L["SOCKET_COUNT"]:format(n)
end

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
        -- Und wohin der Fundort im Waehler gehoert. Unbekannt heisst
        -- "sonstiges", nicht "Dungeon": ein falsch einsortierter
        -- Schlachtzug fuehrt in eine leere Liste.
        -- Erst der Katalog, dann die Messung: der Katalog kennt jede
        -- Instanz des Spiels, der Sammler nur die, in denen gemessen
        -- wurde.
        local kind = inst and (ns.Catalog.InstanceKind(inst)
            or ns.Recommend.InstanceKind(inst)) or nil
        -- Aber nur, solange es laufender Inhalt ist. Eine Zeitwanderung
        -- in den Feuerlanden ist ein gemessener Fundort und gehoert in
        -- die Liste - unter "Schlachtzuege" sucht sie aber niemand.
        if kind and ns.Catalog.InstanceCurrent(inst) == false then
            kind = nil
        end
        -- Und bei einem Schlachtzug auch der Boss: acht Bosse sind acht
        -- Abende, und die Frage "was faellt bei diesem" ist dieselbe
        -- Frage wie "was faellt in diesem Dungeon".
        local bossKey, bossLabel = nil, nil
        if kind == "raid" and enc then
            bossKey = "enc:" .. tostring(enc)
            bossLabel = ns.Compat.DropText(enc, nil)
        end
        return text, "inst:" .. tostring(inst or enc), place, kind or "other",
            bossKey, bossLabel
    end
    -- PvP-Ware, am englischen Namen im Katalog erkannt.
    local origin = ns.Catalog.Origin and ns.Catalog.Origin(itemID)
    if origin == "conquest" then return L["ORIGIN_CONQUEST"], "conquest", L["ORIGIN_CONQUEST"], "other" end
    if origin == "honor" then return L["ORIGIN_HONOR"], "honor", L["ORIGIN_HONOR"], "other" end
    if origin == "pvpcraft" then return L["ORIGIN_PVPCRAFT"], "craft", L["ORIGIN_CRAFT"], "other" end
    if badge == "set" then return L["ORIGIN_SET"], "set", L["ORIGIN_SET"], "other" end
    if badge == "craft" then return L["ORIGIN_CRAFT"], "craft", L["ORIGIN_CRAFT"], "other" end
    -- Was uebrig bleibt, steht in Blizzards Abenteuerjournal nicht.
    --
    -- Das ist die Auskunft, die wir haben, und sie ist nachgeprueft: die
    -- Journaltabelle kennt diese Gegenstaende nicht, Blizzards
    -- Gegenstands-Schnittstelle nennt keine Quelle, und eine Tabelle fuer
    -- Haendler, Quests oder Ruf gibt es nicht. Die Zeile sagt deshalb
    -- zuerst, was bekannt ist, und erst danach, was daraus folgt.
    return L["ORIGIN_WORLD"], "world", L["ORIGIN_WORLD"], "other"
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
                local drop, sourceKey, sourceLabel, sourceGroup, bossKey, bossLabel
                    = originText(item.id, badge, mode)
                rows[#rows + 1] = {
                    kind = "gear", id = item.id, pct = item.pct,
                    drop = drop, sourceKey = sourceKey, sourceLabel = sourceLabel,
                    sourceGroup = sourceGroup,
                    sourceBossKey = bossKey, sourceBossLabel = bossLabel,
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
                    -- Ohne gewaehlte Stufe die gemessene: in der Zeile
                    -- steht "Stufe 311", und der Zeiger darf nicht 28
                    -- sagen.
                    atLevel = atLevel, wantLevel = yours or item.ilvl,
                    wantBonus = yoursBonus,
                    name = name or item.name, link = link, icon = icon,
                    group = L["GEARSLOT_" .. slot:gsub("%s", "")],
                    -- Der Platz selbst, nicht nur seine Ueberschrift:
                    -- danach wird gefaltet.
                    slot = slot,
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

---Welche Stufen es bei den Handwerksstuecken dieser Spec gibt.
---
---Aus den Stuecken selbst, nicht aus den Zeilen: die Knoepfe stehen
---fest, bevor die Liste gebaut ist, und ein Wert von der vorigen
---Ansicht waere ein Flackern zwischen zwei Abschnitten.
---@return number[] aufsteigend
local function craftLevelsFor(specID, mode, source)
    local gear = ns.Recommend.Gear(specID, mode, source)
    local seen, out = {}, {}
    for _, list in pairs(gear or {}) do
        for _, item in ipairs(list) do
            for _, entry in ipairs(ns.Recommend.CraftLevels(item.id) or {}) do
                if not seen[entry.ilvl] then
                    seen[entry.ilvl] = true
                    out[#out + 1] = entry.ilvl
                end
            end
        end
    end
    table.sort(out)
    return out
end

---Die haeufigsten Stuecke EINER Art: Set-Teile oder Handwerk.
---
---Nicht nach Platz, sondern nach Anteil. Die Platzliste beantwortet
---"was ziehe ich an diesen Platz"; hier ist die Frage eine andere -
---"welches Set-Teil tragen die Besten ueberhaupt" und "welches
---Handwerksstueck lohnt sich" -, und darauf antwortet eine Reihenfolge
---nach Haeufigkeit.
---
---Gezaehlt wird nichts neu: die Art steht im Katalog am Gegenstand, die
---Anteile stehen in denselben Daten, aus denen die Platzliste kommt.
---@param want string "set" oder "craft"
---@return table[] rows
---@return string|nil fromSource
local function kindRows(specID, mode, source, want)
    local worn = ns.Compat.EquippedIDs()
    local gear, from = ns.Recommend.Gear(specID, mode, source)
    if not gear then return {}, nil end

    local minLevel = ns.Profile.MinItemLevel()
    -- Dieselbe Stufe wie in der Platzliste. Ohne sie zeigte das Tooltip
    -- den nackten Gegenstand - bei einem Handwerksstueck "Stufe 44" und
    -- "Zufallswert 1", wo die Zeile 331 sagt.
    local yours, yoursBonus = ns.Profile.TargetLevel()
    -- Die gewaehlte Wertekombination, wenn eine gewaehlt ist.
    local pickedStats = want == "craft" and ns.Profile.CraftStats() or nil
    local rows, seen = {}, {}
    for _, slot in ipairs(GEAR_ORDER) do
        for _, item in ipairs(gear[slot] or {}) do
            local badge = item.kind or ns.Catalog.ItemKind(item.id)
            -- Im Reiter "Tier-Set" steht nur das Set DIESER Saison.
            --
            -- "Set-Teil" heisst nur: gehoert irgendeinem Set an. Das
            -- sind auch das Set der vorigen Saison, die PvP-Ruestung und
            -- die kleinen Schmucksets aus den Dungeons - und so standen
            -- sie alle in der Liste, ein Ring mittendrin.
            local passt = badge == want
            if want == "set" and passt then
                passt = ns.Catalog.IsCurrentTier(item.id)
            end
            -- Ein Stueck, das an zwei Plaetzen vorkommt - Ringe,
            -- Schmuckstuecke -, steht einmal da, mit seinem besten Wert.
            if passt and (item.ilvl or 0) >= minLevel and not seen[item.id] then
                seen[item.id] = true
                -- Gewaehlt schlaegt gemessen: wer oben ein Wertepaar
                -- gewaehlt hat, will sehen, wie SEIN Stueck aussaehe.
                local statBonus = pickedStats or item.sb
                -- Der Link aus der GEMESSENEN Liste, nicht aus einer
                -- einzelnen Bonus-ID: sie traegt Qualitaet, Aufwertung
                -- und Verzierung mit. Nur so zeigt das Tooltip, was die
                -- Besten wirklich tragen, statt "Zufallswert 1".
                local levels = ns.Recommend.CraftLevels(item.id)
                local fromLevels, atIlvl = nil, nil
                if levels and #levels > 0 then
                    local wanted = ns.Profile.CraftLevel()
                    local pick = levels[#levels]
                    for _, row in ipairs(levels) do
                        if row.ilvl == wanted then pick = row break end
                    end
                    atIlvl = pick.ilvl
                    fromLevels = ns.Compat.LinkWithList(item.id, pick.ids,
                        pickedStats, ns.Catalog.CraftStatBonuses())
                end
                local name, link, icon = ns.Compat.ItemInfo(item.id)
                if not name then ns.Compat.RequestItem(item.id) end
                local drop, sourceKey, sourceLabel, sourceGroup, bossKey, bossLabel
                    = originText(item.id, badge, mode)
                rows[#rows + 1] = {
                    kind = "gear", id = item.id, pct = item.pct,
                    drop = drop, sourceKey = sourceKey, sourceLabel = sourceLabel,
                    sourceGroup = sourceGroup,
                    sourceBossKey = bossKey, sourceBossLabel = bossLabel,
                    badge = nil,
                    ilvl = atIlvl or yours or item.ilvl, maxKey = item.maxKey,
                    -- Die Wertewahl gehoert IN den Link. Ohne sie steht
                    -- im Tooltip "Zufallswert 1" und "Zufallswert 2" -
                    -- ein Handwerksstueck bekommt seine Zweitwerte erst
                    -- beim Herstellen, ueber eine Bonus-ID.
                    statBonus = statBonus,
                    stats = ns.Catalog.StatsOfBonus(statBonus),
                    statPct = (not pickedStats) and item.sbPct or nil,
                    atLevel = fromLevels
                        or ns.Compat.LinkAtLevel(item.id, yours or item.ilvl, statBonus),
                    -- Der volle Link ersetzt auch die Stufe: sie steht
                    -- schon drin.
                    fullLink = fromLevels,
                    -- Und welche Stufen es zu diesem Stueck ueberhaupt
                    -- gibt - daraus wird die Auswahl oben gebaut.
                    levels = levels,
                    wantLevel = yours, wantBonus = yoursBonus,
                    name = name or item.name, link = link, icon = icon,
                    -- Der Platz steht in der Zeile, aber er ordnet sie
                    -- nicht: gruppiert wird hier nach nichts, sortiert
                    -- wird nach Anteil.
                    slotLabel = L["GEARSLOT_" .. slot:gsub("%s", "")],
                    worn = worn[item.id] == true,
                    owned = ns.Compat.ItemCount(item.id) > 0,
                }
            end
        end
    end
    table.sort(rows, function(a, b)
        if (a.pct or 0) ~= (b.pct or 0) then return (a.pct or 0) > (b.pct or 0) end
        return (a.name or "") < (b.name or "")
    end)
    return rows, from
end

---Die Verzierungen, als Paar.
---
---Eine Zeile ist eine Kombination, kein Gegenstand: deshalb traegt sie
---beide Namen und nur dann einen Link, wenn es wirklich nur einer ist.
---Ein Tooltip zum ersten von zweien waere eine halbe Auskunft.
---@return table[] rows
---@return string|nil fromSource
local function embellishRows(specID, mode, source)
    local list, from = ns.Recommend.Embellish(specID, mode, source)
    if not list then return {}, nil end
    local rows = {}
    for _, entry in ipairs(list) do
        local names, icon, link = {}, nil, nil
        for _, id in ipairs(entry.ids or {}) do
            local name, itemLink, itemIcon = ns.Compat.ItemInfo(id)
            if not name then ns.Compat.RequestItem(id) end
            names[#names + 1] = name or ("#" .. id)
            icon = icon or itemIcon
            link = link or itemLink
        end
        if #names > 0 then
            local single = #entry.ids == 1
            -- Zweimal dasselbe: einmal nennen und dazuschreiben, wie
            -- oft. "Arkanostofffutter + Arkanostofffutter" sagt nichts,
            -- was "Arkanostofffutter  x2" nicht kuerzer sagt.
            local doppelt = #entry.ids == 2 and entry.ids[1] == entry.ids[2]
            rows[#rows + 1] = {
                kind = "gear", pct = entry.pct,
                id = entry.ids[1],
                -- Beide, damit der Zeiger beide Tooltips zeigt.
                ids = entry.ids,
                link = single and link or nil,
                name = doppelt and L["EMBELLISH_TWICE"]:format(names[1])
                    or table.concat(names, "  +  "),
                icon = icon,
                slotLabel = single and L["EMBELLISH_ONE"] or L["EMBELLISH_TWO"],
                owned = single and ns.Compat.ItemCount(entry.ids[1]) > 0 or false,
            }
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
        elseif section.key == "drops" then
            -- Gefiltert wird nach der ART des Fundorts, nicht nach der
            -- einzelnen Instanz: "zeig mir nur Dungeons" ist die
            -- Frage, "zeig mir nur Mördergasse" beantwortet die Zeile
            -- selbst.
            key = row.place
            label = key and L["DROPS_PLACE_" .. key]
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
local ORIGIN_GROUPS = { "dungeon", "raid", "other" }
local ORIGIN_RANK = { dungeon = 1, raid = 2, other = 3 }

local function sourcesIn(rows)
    local seen, out = {}, {}
    for _, row in ipairs(rows or {}) do
        if row.sourceKey and not seen[row.sourceKey] then
            seen[row.sourceKey] = true
            out[#out + 1] = {
                key = row.sourceKey, label = row.sourceLabel or row.sourceKey,
                group = row.sourceGroup or "other",
                bosses = {}, bossSeen = {},
            }
            seen[row.sourceKey] = out[#out]
        end
        -- Die Bosse, von denen in dieser Liste etwas stammt. Sie sind
        -- der Rueckfall, falls der Katalog zu dieser Instanz nichts
        -- fuehrt - die ganze Liste kommt gleich aus ihm.
        local at = seen[row.sourceKey]
        if type(at) == "table" and row.sourceBossKey and not at.bossSeen[row.sourceBossKey] then
            at.bossSeen[row.sourceBossKey] = true
            at.bosses[#at.bosses + 1] = {
                key = row.sourceBossKey,
                label = row.sourceBossLabel or row.sourceBossKey,
            }
        end
    end

    -- Und jetzt die VOLLE Bossliste aus dem Katalog.
    --
    -- Gezeigt werden alle Bosse des Schlachtzugs, nicht nur die, von
    -- denen diese Woche jemand etwas traegt. Ein Schlachtzug, der mal
    -- sechs und mal acht Bosse zeigt, ist keine Auswahl, sondern ein
    -- Raetsel.
    for _, src in ipairs(out) do
        if src.group == "raid" then
            local inst = tonumber(tostring(src.key):match("^inst:(%d+)$"))
            local all = inst and ns.Catalog.Bosses(inst)
            if all and #all > 0 then
                local list = {}
                for _, enc in ipairs(all) do
                    list[#list + 1] = {
                        key = "enc:" .. enc,
                        label = ns.Compat.DropText(enc, nil) or ("#" .. enc),
                    }
                end
                src.bosses = list
            end
        end
        src.bossSeen = nil
    end
    -- Erst die Gruppe, dann der Name: so stehen die Dungeons beieinander
    -- und Handwerk nicht zwischen zweien von ihnen.
    table.sort(out, function(a, b)
        local ra, rb = ORIGIN_RANK[a.group] or 9, ORIGIN_RANK[b.group] or 9
        if ra ~= rb then return ra < rb end
        return a.label < b.label
    end)
    return out
end

---Die Stufe eines Handwerksstuecks waehlen.
---
---Aus den gemessenen Stufen, nicht aus der Belohnungstabelle der
---Dungeons: ein Handwerksstueck wird beim Herstellen und mit Mistcrests
---aufgewertet, und die Tabelle der Schluesselbelohnungen sagt ueber es
---nichts. Was hier steht, hat jemand wirklich getragen.
local function openCraftLevelPicker(anchor, levels)
    local chosen = function() return ns.Profile.CraftLevel() end
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, root)
            root:CreateTitle(L["LBL_CRAFTLEVEL"])
            root:CreateRadio(L["CRAFTLEVEL_BEST"], function() return chosen() == nil end,
                function() ns.Profile.SetCraftLevel(nil); UI.Refresh() end)
            for i = #levels, 1, -1 do
                local ilvl = levels[i]
                root:CreateRadio(L["ILVL"]:format(ilvl), function() return chosen() == ilvl end,
                    function() ns.Profile.SetCraftLevel(ilvl); UI.Refresh() end)
            end
        end)
        return
    end
    local entries = { { key = false, label = L["CRAFTLEVEL_BEST"] } }
    for i = #levels, 1, -1 do
        entries[#entries + 1] = { key = levels[i], label = L["ILVL"]:format(levels[i]) }
    end
    contextMenu(anchor, L["LBL_CRAFTLEVEL"], entries, function(entry)
        ns.Profile.SetCraftLevel(entry.key or nil)
    end)
end

---Die Werte eines Handwerksstuecks waehlen.
---
---Sechs Paare gibt es, mehr nicht: aus vier Zweitwerten. Oben steht,
---was gemessen wurde - das ist die Vorgabe und der ehrlichste Eintrag.
---Darunter die sechs, fuer den, der etwas anderes plant und sehen will,
---wie sein Stueck dann aussaehe.
local function openCraftStatPicker(anchor)
    local choices = ns.Catalog.CraftStatChoices()
    local label = function(entry)
        return L["STAT_" .. entry.stats[1]] .. "  ·  " .. L["STAT_" .. entry.stats[2]]
    end
    local chosen = function() return ns.Profile.CraftStats() end

    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, root)
            root:CreateTitle(L["LBL_CRAFTSTATS"])
            root:CreateRadio(L["CRAFTSTATS_MEASURED"], function() return chosen() == nil end,
                function() ns.Profile.SetCraftStats(nil); UI.Refresh() end)
            for _, entry in ipairs(choices) do
                root:CreateRadio(label(entry), function() return chosen() == entry.bonus end,
                    function() ns.Profile.SetCraftStats(entry.bonus); UI.Refresh() end)
            end
        end)
        return
    end

    local entries = { { key = false, label = L["CRAFTSTATS_MEASURED"] } }
    for _, entry in ipairs(choices) do
        entries[#entries + 1] = { key = entry.bonus, label = label(entry) }
    end
    contextMenu(anchor, L["LBL_CRAFTSTATS"], entries, function(entry)
        ns.Profile.SetCraftStats(entry.key or nil)
    end)
end

---Fundort waehlen: "was faellt hier", nicht nur "wo faellt das".
---
---In Gruppen, und die Gruppe selbst ist waehlbar. Vorher standen zehn
---Dungeons, das Handwerk, die Set-Teile und "nicht im Journal" in EINER
---alphabetischen Reihe - man musste wissen, welcher Name ein Dungeon
---ist, um die Liste zu lesen. Und wer "was faellt in Dungeons" fragte,
---konnte nur einen einzelnen anklicken.
local function openSourcePickerGear(anchor, sources)
    local groups = {}
    for _, src in ipairs(sources) do
        local key = src.group or "other"
        groups[key] = groups[key] or {}
        table.insert(groups[key], src)
    end
    local chosen = function() return ns.Profile.Category("gearSource") end

    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, root)
            root:CreateTitle(L["LBL_ORIGIN"])
            root:CreateRadio(L["SOURCE_ANY"], function() return chosen() == nil end,
                function() ns.Profile.SetCategory("gearSource", nil); UI.Refresh() end)
            for _, group in ipairs(ORIGIN_GROUPS) do
                local list = groups[group]
                -- Auch eine Gruppe mit einem einzigen Eintrag bleibt eine
                -- Gruppe. Vorher stand ein einzelner Schlachtzug nackt
                -- zwischen "Dungeons" und "Sonstiges" - und sah aus wie
                -- eine dritte Art, nicht wie der eine Schlachtzug, den es
                -- gerade gibt.
                if list and #list > 0 then
                    local sub = root:CreateButton(L["ORIGIN_G_" .. group])
                    local all = "group:" .. group
                    sub:CreateRadio(L["ORIGIN_GALL_" .. group], function() return chosen() == all end,
                        function() ns.Profile.SetCategory("gearSource", all); UI.Refresh() end)
                    for _, src in ipairs(list) do
                        if #(src.bosses or {}) > 0 then
                            -- Ein Schlachtzug ist eine Auswahl wie die
                            -- Dungeons eine sind: acht Bosse, acht
                            -- Fragen. Die Instanz selbst steht oben.
                            --
                            -- Auch bei EINEM Boss. Zwei Eintraege, die
                            -- dasselbe filtern, sehen nach Verschwendung
                            -- aus - sie sagen aber, wer ihn fallen laesst,
                            -- und das steht sonst nirgends. Und ein
                            -- Schlachtzug, der sich mal oeffnet und mal
                            -- nicht, ist schwerer zu lesen als einer, der
                            -- es immer tut.
                            local inst = sub:CreateButton(src.label)
                            inst:CreateRadio(L["ORIGIN_ALL_BOSSES"],
                                function() return chosen() == src.key end,
                                function() ns.Profile.SetCategory("gearSource", src.key); UI.Refresh() end)
                            for _, boss in ipairs(src.bosses) do
                                inst:CreateRadio(boss.label, function() return chosen() == boss.key end,
                                    function() ns.Profile.SetCategory("gearSource", boss.key); UI.Refresh() end)
                            end
                        else
                            sub:CreateRadio(src.label, function() return chosen() == src.key end,
                                function() ns.Profile.SetCategory("gearSource", src.key); UI.Refresh() end)
                        end
                    end
                end
            end
        end)
        return
    end

    -- Ohne MenuUtil bleibt die flache Liste, aber die ganze Gruppe steht
    -- vor ihren Eintraegen und ist selbst waehlbar.
    local entries = { { key = false, label = L["SOURCE_ANY"] } }
    for _, group in ipairs(ORIGIN_GROUPS) do
        local list = groups[group]
        if list and #list > 0 then
            entries[#entries + 1] = { key = "group:" .. group, label = L["ORIGIN_GALL_" .. group] }
        end
        for _, src in ipairs(list or {}) do
            entries[#entries + 1] = { key = src.key, label = src.label }
            for _, boss in ipairs(src.bosses or {}) do
                entries[#entries + 1] = { key = boss.key, label = "   " .. boss.label }
            end
        end
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
-- Wie der Waehler und seine Vorgabe heissen - je Abschnitt.
--
-- "Anzeigen: Alles" ist nichtssagend, sobald die Liste etwas
-- Bestimmtes gruppiert. Im Fundort-Raster stehen dort Dungeons,
-- Schlachtzuege und Handwerk: das ist ein FUNDORT, und so heisst der
-- Waehler dann auch.
local function categoryWords(section)
    if section and section.key == "drops" then
        return L["LBL_ORIGIN"], L["SOURCE_ANY"]
    end
    return L["LBL_CATEGORY"], L["CATEGORY_ALL"]
end

local function openCategoryPicker(anchor, section, categories)
    local titel, alle = categoryWords(section)
    local entries = { { key = false, label = alle } }
    for _, cat in ipairs(categories) do
        entries[#entries + 1] = { key = cat.key, label = cat.label }
    end
    contextMenu(anchor, titel, entries, function(entry)
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
        -- "Alle" steht oben, weil es die weiteste Wahl ist: keine
        -- Stufe, keine Abblendung, nichts versteckt. Wer eine Stufe
        -- waehlt, verengt - und das ist die Bewegung nach unten.
        root:CreateRadio(L["KEY_ALL"], function()
            return ns.Profile.AllLevels()
        end, function()
            ns.Profile.SetAllLevels(true)
            UI.Refresh()
        end)
        -- "Wie die Besten spielen" gibt es nicht mehr.
        --
        -- Der Zustand dahinter war "keine Stufe gewaehlt", und der hat
        -- nie eine Frage beantwortet, die jemand stellt: im Tooltip
        -- stand dann die Stufe, auf der irgendein gemessener Spieler das
        -- Stueck trug. Ohne Wahl gilt jetzt, was ein +10 gibt - das
        -- laeuft fast jeder, und die Zahl kommt vom Client, nicht aus
        -- einer Tabelle, die naechste Saison falsch ist.

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
                        sub:CreateRadio(L["KEY_STEP"]:format(
                            ns.Compat.LevelText(step.level), step.label), function()
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
                -- Gibt ein Schluessel irgendeinen Rang dieses Pfads, ist
                -- es sein Pfad; sonst ist es die Schatzkammer.
                local viaRank, viaTresor = false, false
                for _, r in ipairs(ranks) do
                    if ns.Compat.KeysForRank(track.name, r.rank) then viaRank = true end
                    if ns.Compat.VaultKeysForRank(track.name, r.rank) then viaTresor = true end
                end
                if viaRank or viaTresor then
                    local title = (viaRank and ns.Compat.TrackName(t)) or L["KEY_GROUP_VAULT"]
                    local sub = root:CreateButton(title)
                    for _, r in ipairs(ranks) do
                        -- Die Stufe in der Farbe ihrer Qualitaet: man
                        -- sieht am Ton, ob eine Zeile noch Held ist oder
                        -- schon Mythisch, ohne die Zahlen zu vergleichen.
                        local zahl = ns.Compat.LevelText(r.level)
                        -- WELCHE SCHLUESSEL DIESEN RANG GEBEN - gefragt
                        -- am Rang, nicht an der Stufe. Dieselbe Stufe
                        -- gibt es in zwei Pfaden, und dann stand "+10"
                        -- zweimal da: einmal richtig, einmal daneben.
                        local amRang = ns.Compat.KeysForRank(track.name, r.rank)
                        local imTresor = ns.Compat.VaultKeysForRank(track.name, r.rank)
                        local label
                        if amRang then
                            label = L["KEY_STEP"]:format(zahl, keyText(amRang))
                        elseif imTresor then
                            -- In der Gruppe "Grosse Schatzkammer" steht
                            -- das Wort schon in der Ueberschrift; es
                            -- davor noch einmal zu setzen, sagt nichts
                            -- Zweites.
                            label = (viaRank and L["KEY_STEP_VAULT"] or L["KEY_STEP"])
                                :format(zahl, keyText(imTresor))
                        else
                            label = L["KEY_STEP_UPGRADE"]:format(zahl)
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
    -- Welche Menge diese Zeile gerade hat.
    --
    -- Bei einer Liste steht sie am Gegenstand, sonst an der Art. Vorher
    -- stand sie immer an der Art: wer an den Trommeln "2" einstellte,
    -- stellte damit die Verstaerkungsrune auf 2.
    local function ziel()
        if ns.Profile.KindIsList(kind) then
            return ns.Profile.ItemTarget(id) or 0
        end
        return ns.Profile.ConsumableTarget(kind)
    end
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
                function() return ziel() == count end,
                function() ns.Profile.SetConsumableTarget(kind, count, id) UI.Refresh() end)
        end
        -- Und eine eigene Zahl, fuer alles dazwischen.
        amount:CreateButton(L["CONSUM_TARGET_OWN"], function()
            UI.AskNumber(L["CONSUM_" .. kind], ziel(),
                function(value) ns.Profile.SetConsumableTarget(kind, value, id) end)
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

    -- Wer seinen Waffenbuff selbst auflegt, sieht keine Oele.
    --
    -- Flammenzunge und Gifte belegen denselben Platz wie ein Oel. Eine
    -- Zeile "Ziel 5, 5 fehlen" unter einem Gegenstand, den diese Klasse
    -- nie benutzen kann, ist keine Auskunft, sondern ein Auftrag ins
    -- Leere. Was die Klasse STATTDESSEN auflegt, steht in den Pull-Auren
    -- der Berichte - das ist eine Messung fuer sich und keine hier.
    local eigenerBuff = ns.Compat.SelfWeaponBuff(specID)

    local rows = {}

    -- Was die Klasse selbst auf die Waffe legt.
    --
    -- Gemessen wie alles andere: in den Berichten steht es an der Waffe
    -- unter "temporaryEnchant", genau dort, wo bei anderen das Oel
    -- steht. Nur gibt es dazu nichts zu kaufen - also ist es keine
    -- Einkaufszeile, sondern eine Auskunft. Archon fuehrt es unter
    -- "Weapon Buff", und dort gehoert es auch hin.
    local rec = ns.Recommend.For(specID, mode, source)
    local buff = rec and ns.Recommend.Enchant(rec, "weaponbuff")
    local buffSpell = buff and ns.Catalog.WeaponBuffSpell(buff.id)
    if buffSpell then
        rows[#rows + 1] = {
            kind = "runeforge", slot = "weapon", spell = buffSpell,
            pct = buff.pct, need = 0, missing = 0, buy = 0,
            group = L["CONSUM_oil"],
        }
    end

    for _, kind in ipairs(CONSUM_ORDER) do
        if not (kind == "oil" and eigenerBuff) then
        -- Nur das haeufigste je Art ist ein Posten; der Rest sind
        -- Alternativen.
        --
        -- Vorher stand unter jedem Flaeschchen "Ziel 2 - 2 fehlen", auch
        -- unter denen, die man gar nicht will. Drei Flaeschchen je zwei
        -- Stueck ist nicht, was jemand einkauft - man nimmt EINES.
        -- Eine Liste ist keine Wahl.
        --
        -- Unter "Sonstiges" steht nebeneinander, was man nebeneinander
        -- traegt: eine Verstaerkungsrune UND Trommeln UND einen
        -- Reparaturhammer. Die Regel "nur das Haeufigste ist ein Posten"
        -- machte daraus eine Rune mit Menge und zwei Alternativen ohne -
        -- die Trommeln standen da, waren aber nicht zu kaufen.
        local alsListe = ns.Profile.KindIsList(kind)
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
            local istPosten = alsListe or first
            -- Die Menge haengt bei einer Liste am GEGENSTAND.
            --
            -- Sie hing an der Art, und die Art hat nur eine Zahl: wer an
            -- den Trommeln "2" einstellte, stellte damit die Rune auf 2.
            --
            -- Vorgeschlagen wird eine Menge nur fuer den, den die
            -- Gemessenen wirklich meist nehmen. Bei den uebrigen steht
            -- keine, bis jemand eine setzt - wie viele Trommeln jemand
            -- mitnimmt, hat niemand gemessen.
            local target
            if alsListe then
                target = ns.Profile.ItemTarget(id)
                    or (first and ns.Profile.ConsumableTarget(kind) or 0)
            else
                target = ns.Profile.ConsumableTarget(kind)
            end
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
                alt = not istPosten or nil, own = entry.own,
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
    end
    return rows, from
end

---Der Reiter "Erinnerung": was die Erinnerung prueft, und wie.
---
---Oben der Stand je Art - gruen, gelb, rot -, darunter die drei
---Einstellungen, die es gibt. Die Zeilen tragen Gegenstand und
---Fehlmenge, deshalb funktionieren die beiden Einkaufsknoepfe unten
---hier genauso wie unter Verbrauchsguetern.
---Einen Gegenstand selbst auf die Erinnerung setzen.
---
---Nicht alles, was man vor dem Pull dabeihaben will, steht in einer
---Messung: ein Reparaturhammer, eine Vantusrune, das Kabel fuer den
---Kampf-Res. Benutzt werden sie, gemessen sind sie nicht - und "nicht
---gemessen" heisst nicht "gibt es nicht".
---
---Zwei Wege hinein: die Gegenstands-ID, oder ein Griff in die eigenen
---Taschen. Was so dazukommt, steht ohne Prozentwert da; eine Zahl
---daneben waere erfunden.
---@param anchor table
local function openAddOwnItem(anchor)
    local function nimm(id)
        if not id or id <= 0 then return end
        ns.Profile.SetOwnItem(id, true)
        if not ns.Profile.ItemTarget(id) then
            ns.Profile.SetConsumableTarget("other", 1, id)
        end
        ns.Compat.RequestItem(id)
        UI.Refresh()
    end
    local function ueberID()
        UI.AskNumber(L["OWN_ADD_ID"], 0, nimm, 8, L["OWN_ADD_HINT"], true)
    end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        ueberID()
        return
    end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(L["OWN_ADD"])
        root:CreateButton(L["OWN_ADD_ID"], ueberID)
        -- Und was gerade im Beutel liegt. Nur Verbrauchsgueter: eine
        -- Liste aus hundert Gegenstaenden waere kein Menue mehr.
        local ausDemBeutel = {}
        for _, id in ipairs(ns.Compat.BagItems()) do
            if ns.Compat.ConsumableKind(id) and not ns.Profile.IsOwnItem(id) then
                local name = ns.Compat.ItemInfo(id)
                if name then ausDemBeutel[#ausDemBeutel + 1] = { id = id, name = name } end
            end
        end
        table.sort(ausDemBeutel, function(a, b) return a.name < b.name end)
        if #ausDemBeutel > 0 then
            local beutel = root:CreateButton(L["CONSUM_FROM_BAGS"])
            for i, eintrag in ipairs(ausDemBeutel) do
                if i > 40 then break end
                beutel:CreateButton(eintrag.name, function() nimm(eintrag.id) end)
            end
        end
    end)
end

---Was an einer Zeile der Erinnerung einzustellen ist.
---
---Mit Auswahl, nicht mit einem Klick, der sofort etwas tut. Ein Klick,
---der eine Zeile verschwinden laesst, ist eine Falle: wer ihn aus
---Versehen macht, sucht danach, wo sie geblieben ist.
---
---"Ignorieren" heisst: nicht mehr ansprechen. Es heisst nicht "nicht
---mehr messen". In den Reitern steht weiter, was die Gemessenen tragen
---und wie weit die eigene Ausruestung davon weg ist - nur vor dem Pull
---kommt es nicht mehr zur Sprache. Wer seine Sockel bewusst auf Tempo
---und Vielseitigkeit stellt, hat nichts vergessen.
---@param anchor table
---@param data table
local function openRemindMenu(anchor, data)
    local id = data.id
    local ignoriert = ns.Profile.Ignored(id)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        -- Ohne Menue-API bleibt das Umschalten. Nicht schoen, aber es
        -- fuehrt zum selben Ziel und bricht nicht.
        if id then
            ns.Profile.SetIgnored(id, not ignoriert)
            UI.Refresh()
        end
        return
    end
    local name = (id and ns.Compat.ItemInfo(id)) or data.name or data.fallback
    -- Ein selbst gesetzter Posten traegt seine Menge immer am
    -- Gegenstand: er steht fuer sich und nicht als eine von mehreren
    -- Wahlmoeglichkeiten einer Art.
    local amGegenstand = data.ownItem
        or (data.ckind and ns.Profile.KindIsList(data.ckind)) or false
    local function zielDavon()
        if amGegenstand then
            return ns.Profile.ItemTarget(id) or 0
        end
        return data.ckind and ns.Profile.ConsumableTarget(data.ckind) or 0
    end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(name or L["REMIND_WINDOW_TITLE"])
        -- Bei einem Verbrauchsgut bleibt die Zielmenge, wo sie war.
        if data.ckind then
            local amount = root:CreateButton(L["CONSUM_TARGET_MENU"])
            for _, count in ipairs({ 0, 1, 2, 3, 5, 10, 20, 40 }) do
                amount:CreateRadio(tostring(count),
                    function() return zielDavon() == count end,
                    function()
                        ns.Profile.SetConsumableTarget(data.ckind, count,
                            amGegenstand and id or nil)
                        UI.Refresh()
                    end)
            end
            amount:CreateButton(L["CONSUM_TARGET_OWN"], function()
                UI.AskNumber(L["CONSUM_" .. data.ckind], zielDavon(),
                    function(value)
                        ns.Profile.SetConsumableTarget(data.ckind, value,
                            amGegenstand and id or nil)
                    end)
            end)
        end
        -- Einen selbst gesetzten Posten wieder loswerden.
        if id and ns.Profile.IsOwnItem(id) then
            root:CreateButton(L["OWN_REMOVE"], function()
                ns.Profile.SetOwnItem(id, false)
                UI.Refresh()
            end)
        end
        if id then
            root:CreateButton(ignoriert and L["IGNORE_OFF"] or L["IGNORE_ON"], function()
                ns.Profile.SetIgnored(id, not ignoriert)
                UI.Refresh()
            end)
        end
    end)
end

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
        if not ns.Profile.Ignored(row.id) then
            local name, link, icon = ns.Compat.ItemInfo(row.id)
            if not name then ns.Compat.RequestItem(row.id) end
            rows[#rows + 1] = {
                kind = "remind", ckind = row.kind, id = row.id,
                name = name or row.name, link = link, icon = icon,
                owned = row.owned, need = row.need, state = row.state,
                buy = math.max(0, row.need - row.owned),
                group = L["REMIND_GROUP_STATUS"],
                remindMenu = true,
            }
        end
    end
    -- Und die Verzauberungen und Steine, die am Charakter noch fehlen.
    -- Dieselben Zeilen wie unter "Verzauberungen & Steine", nur auf
    -- das Offene gekuerzt - damit man hier sieht, was noch zu kaufen
    -- ist, und es mit den Knoepfen unten gleich tut.
    local open = 0
    if ns.Profile.Complete() and not ns.Profile.IsForeignClass() then
        for _, row in ipairs(ns.List.Build(ns.Gear.Scan())) do
            if not row.pending and not row.alt and (row.buy or 0) > 0
                and not ns.Profile.Ignored(row.id) then
                row.group = L["REMIND_GROUP_ENCHANTS"]
                row.remindMenu = true
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

    -- Und was dieser Charakter nicht mehr hoeren will.
    --
    -- Eigener Abschnitt, damit nichts spurlos verschwindet: wer etwas
    -- ignoriert hat, findet es hier wieder und kann es zurueckholen.
    -- Eine Einstellung, die man nicht mehr sieht, ist eine Falle.
    -- Was jemand selbst dazugenommen hat.
    --
    -- Ohne Prozentwert: gemessen hat das niemand, und eine Zahl daneben
    -- waere erfunden. Dass es eine eigene Wahl ist, steht an der Zeile.
    for _, id in ipairs(ns.Profile.OwnItems()) do
        local name, link, icon = ns.Compat.ItemInfo(id)
        if not name then ns.Compat.RequestItem(id) end
        local target = ns.Profile.ItemTarget(id) or 1
        local owned = ns.Compat.ItemCount(id)
        rows[#rows + 1] = {
            kind = "consumable", ckind = ns.Compat.ConsumableKind(id) or "other",
            id = id, name = name or ("#" .. tostring(id)), link = link, icon = icon,
            own = true, pct = nil,
            need = target, owned = owned, ownedLower = 0, ownedHigher = 0,
            buy = math.max(0, target - owned),
            group = L["REMIND_GROUP_OWN"],
            remindMenu = true, ownItem = true,
        }
    end
    -- Und die Zeile, mit der man einen dazunimmt.
    rows[#rows + 1] = {
        kind = "option", label = L["OWN_ADD"], value = "",
        toggle = function() end, addOwn = true,
        group = L["REMIND_GROUP_OWN"],
    }

    for _, id in ipairs(ns.Profile.IgnoredList()) do
        local name, link, icon = ns.Compat.ItemInfo(id)
        if not name then ns.Compat.RequestItem(id) end
        rows[#rows + 1] = {
            kind = "gear", id = id, name = name or ("#" .. tostring(id)),
            link = link, icon = icon,
            slotLabel = L["IGNORE_HINT"],
            group = L["REMIND_GROUP_IGNORED"],
            remindMenu = true,
        }
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
        kind = "option", label = L["REMIND_OPT_AH_PANEL"],
        on = ns.Profile.AuctionPanel(),
        choices = boolChoices(),
        pick = function(value)
            ns.Profile.SetAuctionPanel(value)
            -- Sofort wirksam: wer sie am offenen Auktionshaus abschaltet,
            -- soll nicht erst neu hingehen muessen.
            if not value and ns.UI.HideAuctionPanel then ns.UI.HideAuctionPanel() end
        end,
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
    -- UND DER FUENFTE: der Knopf am Talentfenster.
    --
    -- Er setzt sich ungefragt in fremde Oberflaeche - an genau die
    -- Ecke, an der bei anderen schon Raider.IO sitzt. Wer ihn nicht
    -- will, hatte bisher keine Stelle, an der er ihn abschalten konnte;
    -- der Schalter war da, nur nirgends zu sehen.
    switch(L["SET_TALENTBTN"], L["SET_GROUP_OPEN"], ns.Profile.TalentPanel(), function(value)
        ns.Profile.SetTalentPanel(value)
        if not value then UI.HideTalentPanel() end
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
    if not profile then
        -- Ohne Profil bleibt wenigstens die Adresse: wer hier landet,
        -- will den Spieler nachschlagen, und das geht im Browser auch
        -- dann, wenn raider.io uns gerade nichts gibt.
        rows[#rows + 1] = { kind = "note", text = L[why == "loading" and "PLAYER_LOADING" or "PLAYER_NO_PROFILE"] }
        rows[#rows + 1] = { kind = "link", url = who.url, realm = who.realm,
            group = L["PLAYER_PROFILE_GROUP"] }
        return rows
    end
    if profile.text and profile.text ~= "" then
        -- Dieselbe Karte wie unter "Talente", nur traegt sie die
        -- Kette DIESES Spielers. Geprueft oder nicht steht darunter,
        -- denn eine Kette aus einem Profil ist nicht automatisch der
        -- Build, mit dem er den Lauf gespielt hat.
        rows[#rows + 1] = {
            kind = "buildcard", text = profile.text, specID = who.specID,
            nodes = {}, count = 0,
            cardTitle = L["PLAYER_LOADOUT"],
            cardNote = who.rank and L["CARD_RANK"]:format(who.rank,
                ns.Compat.SpecName(who.specID) or "") or ns.Compat.SpecName(who.specID),
            cardBody = profile.verified and L["LOADOUT_PASTE"]
                or (L["LOADOUT_PASTE"] .. "  " .. L["PLAYER_UNVERIFIED"]),
            group = L["SECTION_talents"],
        }
    end
    rows[#rows + 1] = { kind = "link", url = who.url, realm = who.realm,
        group = L["PLAYER_PROFILE_GROUP"] }
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
            kind = "buildcard", nodes = build.nodes, specID = specID,
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

---Der Omnium-Foliant: fuenf Reihen, je Reihe eine Wahl.
---
---VIER REIHEN STEHEN HIER, DIE FUENFTE NICHT - und das ist keine
---Nachlaessigkeit, sondern das Ergebnis.
---
---Die Runen stehen nicht in den Kampfdaten, aus denen jeder andere
---Abschnitt lebt. Erkannt werden sie an ihrer Wirkung. Fuer die Reihen
---eins bis vier geht das: nachgemessen wurden vier von fuenf Spielern.
---Fuer Reihe fuenf geht es nicht - keine ihrer drei Runen hinterlaesst
---irgendeine Spur, auch nicht im rohen Kampflog.
---
---Man koennte sie ausrechnen: wer in einer Reihe mit drei Wahlmoeglich-
---keiten bei keiner der beiden sichtbaren auftaucht, hat die dritte.
---Das waere eine Zahl, die wie eine Messung aussieht und keine ist -
---wer seine Rune traegt und nie ausloest, faellt in denselben Topf.
---Also steht dort ein Satz statt einer Zahl.
---@return table[] rows
---@return string|nil fromSource
-- An UI gehaengt statt als weitere Datei-Lokale.
--
-- WoWs Lua laesst einer Funktion hoechstens 60 Upvalues, und die
-- Zeichenschleife weiter unten sass schon knapp darunter. Eine
-- zusaetzliche Lokale auf Dateiebene hat sie ueber die Grenze
-- gehoben - dann laedt UI.lua nicht mehr, ns.UI bleibt leer und das
-- Fenster geht gar nicht mehr auf. UI ist ohnehin ein Upvalue;
-- darueber kostet die Funktion keines mehr.
--
-- Die Tests haben es nicht gesehen: die Test-VM kennt diese Grenze
-- nicht. Gemerkt hat es das Spiel.
function UI.FolioRows(specID, mode, source)
    local rows, from = ns.Recommend.Folio(specID, mode, source)
    if not rows then return {}, nil end

    local out = {}

    for _, row in ipairs(rows) do
        -- Eine Reihe mit nur einer Rune ist keine Wahl. Sie steht
        -- trotzdem da, sonst klafft zwischen zwei und vier eine Luecke,
        -- die wie ein Fehler aussieht - und sie traegt keinen
        -- Prozentwert, weil "100 %" hier nichts misst.
        if row.only then
            out[#out + 1] = {
                kind = "talent", spell = row.only, single = true,
                group = L["FOLIO_ROW_ONE"]:format(row.row or 0),
            }
        else

        -- Die Grundlage steht im Gruppenkopf, nicht im Kleingedruckten:
        -- wer den Anteil liest, soll im selben Blick sehen, worauf er
        -- ruht.
        local group = L["FOLIO_ROW"]:format(row.row or 0, row.seen or 0)
        for _, pick in ipairs(row.picks or {}) do
            if pick.derived then
                -- Diese eine Rune hinterlaesst im Kampf nichts. Ihre
                -- Zahl ist der Rest - und die Zeile sagt es.
                out[#out + 1] = {
                    kind = "talent", spell = pick.spell, pct = pick.pct,
                    derived = true, group = group,
                }
            else
                -- Ohne die Zeile "98 % der Besten nehmen es": rechts
                -- steht schon "98 %". Zweimal dieselbe Zahl in einer
                -- Zeile macht sie nicht wahrer, nur breiter.
                out[#out + 1] = {
                    kind = "talent", spell = pick.spell, pct = pick.pct,
                    bare = true, group = group,
                }
            end
        end
        end
    end
    if #out == 0 then return {}, nil end

    -- KEIN erklaerender Absatz mehr.
    --
    -- Dort standen vier Zeilen darueber, warum diese Rune keine Spur
    -- hinterlaesst und wie die Zahl zustande kommt. Das ist richtig und
    -- fuer einen Spieler trotzdem uninteressant - er will wissen, welche
    -- Rune er nehmen soll. Was er wissen MUSS, steht an der Zeile selbst:
    -- "Gerechnet, nicht gesehen".
    return out, from
end

---Wo die Stuecke fallen, als Raster.
---
---Eine Zeile je Instanz, ein Kaestchen je Stueck - Dungeons zuerst,
---denn das ist die Frage, die man vor einem Abend stellt. Der
---Schlachtzug steht darunter, weil er jede Liste anfuehren wuerde: aus
---ihm faellt mehr als aus allen acht Dungeons zusammen, und das ist
---keine Auskunft, sondern eine Binsenweisheit.
---
---Die letzte Zeile nennt, was in KEINER Instanz faellt. Ohne sie sieht
---jeder Dungeon besser aus, als er ist.
---@return table[] rows
---@return string|nil fromSource
UI.DROP_PLACES = { "dungeon", "raid", "craft", "set", "pvp", "boe", "world" }

function UI.DropRows(specID, mode, source)
    local rows, summary, from = ns.Drops.Build(specID, mode, source)
    if #rows == 0 then return {}, nil end

    local out = {}
    local wie = ns.Profile.DropsSort()
    -- Die Reihenfolge der Gruppen steht hier und nur hier: erst die
    -- Dungeons, weil das die Frage vor einem Abend ist, dann der
    -- Schlachtzug, dann alles, was nirgends faellt.
    for _, want in ipairs(UI.DROP_PLACES) do
        local gruppe = {}
        for _, row in ipairs(rows) do
            -- Was der Katalog nicht einordnet, steht bei den Dungeons:
            -- dort sucht man es, und eine Gruppe mit einer einzigen
            -- Zeile ist keine Gliederung.
            local place = row.place
            local eigene = place == "raid" or place == "craft" or place == "set"
                or place == "pvp" or place == "boe" or place == "world"
            if not eigene then place = "dungeon" end
            if place == want then
                row.place = place
                row.group = L["DROPS_PLACE_" .. want]
                gruppe[#gruppe + 1] = row
            end
        end
        -- Gemessen wird INNERHALB der Gruppe.
        --
        -- Der Schlachtzug laesst mehr fallen als alle acht Dungeons
        -- zusammen; an ihm gemessen waere jeder Dungeonbalken ein
        -- Strich. Die Frage lautet aber "welcher Dungeon", nicht
        -- "Dungeon oder Schlachtzug".
        local hoechst = 0
        for _, row in ipairs(gruppe) do
            local wert = wie == "best" and (row.best or 0) or (row.score or 0)
            if wert > hoechst then hoechst = wert end
        end
        for _, row in ipairs(gruppe) do
            local wert = wie == "best" and (row.best or 0) or (row.score or 0)
            row.rel = hoechst > 0 and (wert / hoechst) or 0
            out[#out + 1] = row
        end
    end

    -- Was nirgends faellt, in einer Zeile.
    local fehlt = {}
    if (summary.craft or 0) > 0 then fehlt[#fehlt + 1] = L["DROPS_E_CRAFT"]:format(summary.craft) end
    if (summary.set or 0) > 0 then fehlt[#fehlt + 1] = L["DROPS_E_SET"]:format(summary.set) end
    if (summary.pvp or 0) > 0 then fehlt[#fehlt + 1] = L["DROPS_E_PVP"]:format(summary.pvp) end
    if (summary.boe or 0) > 0 then fehlt[#fehlt + 1] = L["DROPS_E_BOE"]:format(summary.boe) end
    if (summary.world or 0) > 0 then fehlt[#fehlt + 1] = L["DROPS_E_WORLD"]:format(summary.world) end
    if #fehlt > 0 then
        local offen = (summary.total or 0) - (summary.known or 0)
        out[#out + 1] = {
            kind = "note",
            text = (offen == 1 and L["DROPS_ELSEWHERE_1"] or L["DROPS_ELSEWHERE"]):format(
                offen, summary.total or 0,
                table.concat(fehlt, ", ")),
        }
    end
    return out, from
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
            -- Wie weit die Gemessenen auseinanderliegen: das mittlere
            -- Viertel unter und ueber der Mitte. Ohne diese Spanne ist
            -- eine Zielzahl eine Behauptung ueber alle.
            low = value and value.low or nil,
            high = value and value.high or nil,
            players = stats.players,
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

---Zwei Karten nebeneinander: dein Build und der, auf den es hinauslaeuft.
---
---Eine Zeile mit zwei Zahlen beantwortet die Frage "worin unterscheide
---ich mich" zwar, aber sie sieht nicht danach aus, dass man etwas tun
---soll. Zwei Karten mit einem Pfeil dazwischen tun das: links, wie du
---spielst, rechts, wohin es geht, und darunter, was dafuer zu tun ist.
---
---Der Hintergrund ist das Bild der Spezialisierung, wie es der Client
---selbst im Spezialisierungsfenster zeigt. Es liegt als Atlas vor,
---"spec-thumbnail-<klasse>-<spec>", und zwar fuer alle vierzig - die
---Namen stehen in den Spieldaten und wurden abgezaehlt. Die
---Katalog-Bezeichner heissen fast genauso; nur die Bindestriche muessen
---weg, denn der Atlas kennt "deathknight", nicht "death-knight".
local function specAtlas(specID)
    local cls, spec = ns.Catalog.SpecSlug(specID)
    if not cls or not spec then return nil end
    -- Das BREITE Bild, nicht die Miniatur.
    --
    -- Die Miniatur ist 306 mal 186 und damit fast quadratisch; auf einer
    -- langen flachen Karte sah sie gezogen aus. Der Hintergrund des
    -- Talentbaums ist 1612 mal 774 und passt in der Form. Beide gibt es
    -- fuer alle vierzig Speccs, nachgezaehlt in den Spieldaten.
    local slug = ("%s-%s"):format(cls:gsub("%-", ""), spec:gsub("%-", ""))
    return "talents-background-" .. slug, "spec-thumbnail-" .. slug
end

---Legt ein Bild in die Karte, ohne es zu ziehen.
---
---Es wird so vergroessert, dass es die Karte deckt, und der Rest wird
---abgeschnitten - wie ein Hintergrundbild, das "cover" heisst. Gestreckt
---sah der Drache aus wie eine Wurst.
local function fitArt(card, atlas, width, height)
    if not atlas or not card.art.SetAtlas then card.art:Hide() return end
    if not pcall(card.art.SetAtlas, card.art, atlas, false) then card.art:Hide() return end
    local aw, ah = 1612, 774
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    if type(info) == "table" and tonumber(info.width) and tonumber(info.height)
        and tonumber(info.width) > 0 and tonumber(info.height) > 0 then
        aw, ah = tonumber(info.width), tonumber(info.height)
    end
    local scale = math.max(width / aw, height / ah)
    card.art:ClearAllPoints()
    card.art:SetPoint("CENTER")
    card.art:SetSize(aw * scale, ah * scale)
    card.art:Show()
end

---Die Karte fuer den haeufigsten Build - einmal gebaut, dann benutzt.
---
---Vorher stand hier eine Zeile wie jede andere, und sie sah aus wie
---Zubehoer. Der haeufigste Build ist aber das, wofuer die meisten den
---Abschnitt ueberhaupt oeffnen. Also bekommt er eine Karte mit dem Bild
---seiner Spezialisierung, und ein Klick darauf legt die Importkette
---zum Kopieren hin.
-- Die Karten liegen NEBEN den Zeilen, nicht in ihnen.
--
-- "if row.card then" waere der naheliegende Weg und in den Tests eine
-- Falle: die Attrappe der WoW-API gibt auf jedes unbekannte Feld ein
-- Kind zurueck, also ist row.card dort immer wahr - und zurueck kaeme
-- eine Attrappe statt der Karte. Eine eigene Tabelle kennt nur, was
-- wirklich hineingelegt wurde. Schwach, damit sie nichts festhaelt.
local cardOf = setmetatable({}, { __mode = "k" })
-- Die Kaestchen des Fundort-Rasters, je Zeile.
--
-- Hier oben und nicht dort, wo sie gebaut werden: resetRow muss sie
-- verstecken koennen. Genau das fehlte, und dann lagen die Kaestchen
-- des Rasters mitten in der Ausruestungsliste - Zeilen werden
-- wiederverwendet, ihre Kinder auch.
local cellsOf = setmetatable({}, { __mode = "k" })
-- Und die Bahn, die im Fundort-Raster zeigt, wie ergiebig eine Zeile
-- gegen die beste ihrer Gruppe ist. Die Reihenfolge allein sagt nur,
-- WER vorne liegt - nicht, ob mit Abstand oder um Haaresbreite.
local barOf = setmetatable({}, { __mode = "k" })

local function buildCard(row)
    if cardOf[row] then return cardOf[row] end
    local f = CreateFrame("Frame", nil, row)
    S:Fill(f, "bgRaised")
    S:Border(f, "borderSubtle")
    -- Drei Ebenen, und die Reihenfolge ist der ganze Trick.
    --
    -- Ein Kindrahmen zeichnet UEBER seinem Elternteil, und zwar alles,
    -- was in ihm liegt. Das Bild sass deshalb ueber der Schrift und hat
    -- sie abgedunkelt. Also: unten der Rahmen, der abschneidet, mit Bild
    -- und Schleier darin; darueber ein eigener Rahmen, in dem nur der
    -- Text liegt.
    local base = f:GetFrameLevel()

    f.clip = CreateFrame("Frame", nil, f)
    f.clip:SetAllPoints()
    f.clip:SetFrameLevel(base + 1)
    if f.clip.SetClipsChildren then pcall(f.clip.SetClipsChildren, f.clip, true) end
    f.art = f.clip:CreateTexture(nil, "BACKGROUND")
    f.art:SetAlpha(0.85)

    -- Der Schleier verlaeuft, statt alles gleich zu decken.
    --
    -- Vorher lief das Bild auf 40 Prozent und darueber lag noch ein
    -- schwarzer Schleier - zusammen blieb vom Drachen kaum etwas uebrig.
    -- Gebraucht wird die Deckung aber nur links, wo der Text steht.
    -- Rechts darf das Bild sein, wie es ist. Kennt ein Client den
    -- Verlauf nicht, deckt der Schleier eben gleichmaessig, nur
    -- schwaecher als zuvor.
    f.veil = f.clip:CreateTexture(nil, "ARTWORK")
    f.veil:SetAllPoints(f.clip)
    f.veil:SetColorTexture(1, 1, 1, 1)
    local gradient = f.veil.SetGradient and CreateColor and pcall(f.veil.SetGradient, f.veil,
        "HORIZONTAL", CreateColor(0, 0, 0, 0.88), CreateColor(0, 0, 0, 0.05))
    if not gradient then f.veil:SetColorTexture(0, 0, 0, 0.35) end

    f.fg = CreateFrame("Frame", nil, f)
    f.fg:SetAllPoints()
    f.fg:SetFrameLevel(base + 2)
    f.title = S:Text(f.fg, "title", "textPrimary")
    f.title:SetPoint("TOPLEFT", S.space.lg, -S.space.md)
    f.title:SetJustifyH("LEFT")
    f.note = S:Text(f.fg, "body", "heading")
    f.note:SetPoint("TOPLEFT", S.space.lg, -S.space.md - 24)
    f.note:SetJustifyH("LEFT")
    f.body = S:Text(f.fg, "caption", "textSecondary")
    f.body:SetPoint("TOPLEFT", S.space.lg, -S.space.md - 46)
    f.body:SetPoint("RIGHT", -S.space.lg, 0)
    f.body:SetJustifyH("LEFT")
    f.body:SetWordWrap(true)
    cardOf[row] = f
    return f
end

-- Der zweite Tooltip. Einer fuer alle Zeilen, erst gebaut, wenn ihn
-- jemand braucht: die meisten Zeilen haben nur einen Gegenstand.
local secondFrame
local function secondTooltip()
    if not secondFrame then
        secondFrame = CreateFrame("GameTooltip", "MetaCodexTooltipTwo",
            UIParent, "GameTooltipTemplate")
    end
    return secondFrame
end

-- Der Zeiger gehoert NEBEN das Fenster.
--
-- Ein Kaestchen steht mitten im Fenster, und "ANCHOR_RIGHT" haengt den
-- Zeiger an das Kaestchen - also mitten auf die Liste, die man gerade
-- liest. Bei einem Gegenstand kommen Vergleichstooltip und Vorschau
-- dazu, und dann ist vom Raster nichts mehr zu sehen.
--
-- Also aussen: rechts vom Fenster, wenn dort Platz ist, sonst links.
-- Fragt der Client keine Masse heraus - in den Tests etwa -, bleibt es
-- beim gewohnten Verhalten.
local function tipOutside(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    local rechts = frame and tonumber(frame:GetRight())
    local schirm = UIParent and tonumber(UIParent:GetRight())
    -- WAAGRECHT neben dem Fenster, SENKRECHT auf Hoehe des Kaestchens.
    --
    -- Nur neben dem Fenster hiess: oben rechts an der Fensterecke -
    -- also am anderen Ende des Bildschirms als das Kaestchen, auf das
    -- man zeigt. Ein Zeiger, den man suchen muss, ist keiner.
    local obenF = frame and tonumber(frame:GetTop())
    local obenO = tonumber(owner:GetTop())
    local hoch = (obenF and obenO) and (obenO - obenF) or 0
    if rechts and schirm and (schirm - rechts) < 360 then
        GameTooltip:SetPoint("TOPRIGHT", frame, "TOPLEFT", -S.space.sm, hoch)
    elseif rechts then
        GameTooltip:SetPoint("TOPLEFT", frame, "TOPRIGHT", S.space.sm, hoch)
    else
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    end
end

---Was ein Alternativbuild gegen was tauscht - mit Namen und Wirkung.
---
---WELCHES GEGEN WELCHES, das ist die Frage. In der Zeile steht
---"Totemische Projektion, Wolfsaffinitaet der Ahnen" und mehr passt da
---auch nicht hin; welches Talent dafuer weichen muss und was die beiden
---ueberhaupt tun, stand nirgends. Also hier: links, was dazukommt,
---darunter, was dafuer faellt, jeweils mit der Beschreibung aus dem
---Spiel.
---
---JEDES TALENT BEKOMMT TEXT, LANGE NUR WENIGE. Ein Build kann sich in
---zehn Talenten unterscheiden, und zehn volle Beschreibungen sind
---laenger als der Bildschirm. Vorher fielen sie darum ab sieben Talenten
---ganz weg - mit dem Ergebnis, dass manche Zeilen eine Wirkung nannten
---und andere nicht, ohne dass man sah, warum. Jetzt steht ueberall
---etwas; bei vielen eben gekuerzt, mit Auslassungspunkten, damit man
---das Kuerzen sieht statt es zu erraten.
---@param added number[]|nil  Zauber-IDs, die dieser Build zusaetzlich nimmt
---@param removed number[]|nil  Zauber-IDs, die er dafuer nicht nimmt
---@return boolean  ob etwas geschrieben wurde
local function swapLines(added, removed)
    -- MIT SYMBOL. Im Talentbaum erkennt man ein Talent am Bild, nicht am
    -- Namen - und der Zeiger steht neben genau diesem Baum. Die Nummer
    -- kommt aus derselben Abfrage wie der Name, es wird nichts geraten;
    -- fehlt sie, steht der Name eben allein da.
    local function spellName(id)
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
        local name = info and info.name
        name = type(name) == "string" and name or ("#" .. tostring(id))
        local icon = tonumber(info and info.iconID)
        if icon then return ("|T%d:16:16:0:0|t %s"):format(icon, name) end
        return name
    end
    local function spellText(id)
        local get = C_Spell and C_Spell.GetSpellDescription
        if not get then return nil end
        local ok, text = pcall(get, id)
        if ok and type(text) == "string" and text ~= "" then return text end
        return nil
    end

    local n = #(added or {}) + #(removed or {})
    if n == 0 then return false end
    -- Wie viel Text je Talent noch hineinpasst. Bei sechsen die ganze
    -- Beschreibung, darueber die ersten neunzig Zeichen - das sind ein
    -- bis zwei Zeilen, und auch bei zehn Talenten bleibt der Zeiger
    -- kuerzer als der Bildschirm.
    local deckel = (n <= 6) and 0 or 90

    ---Auf ganze Woerter gekuerzt, mit sichtbarem Schnitt.
    ---@param text string
    ---@return string
    local function kuerzen(text)
        if deckel == 0 or #text <= deckel then return text end
        local kurz = text:sub(1, deckel)
        -- Bis zum letzten Leerzeichen zurueck: mitten im Wort
        -- abzuschneiden liest sich wie ein Fehler.
        local luecke = kurz:find("%s[^%s]*$")
        if luecke and luecke > deckel / 2 then kurz = kurz:sub(1, luecke - 1) end
        return kurz .. "\226\128\166"
    end

    local function block(list, token, heading)
        if #(list or {}) == 0 then return end
        local hr, hg, hb = S:Color("textMuted")
        local r, g, b = S:Color(token)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(heading, hr, hg, hb)
        for _, id in ipairs(list) do
            GameTooltip:AddLine(spellName(id), r, g, b, true)
            local text = spellText(id)
            if text then
                -- Zeilenumbrueche der Spielbeschreibung weg: sie trennen
                -- Rangstufen, und hier steht ohnehin nur ein Auszug.
                text = text:gsub("%s*\n%s*", " ")
                GameTooltip:AddLine(kuerzen(text), 0.7, 0.7, 0.7, true)
            end
        end
    end

    block(added, "success", L["SWAP_TAKES"])
    block(removed, "danger", L["SWAP_DROPS"])
    return true
end

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
    row.own = S:Text(row, "caption", "textSecondary")
    row.own:SetPoint("TOPLEFT", BAR_X, -S.space.sm - 24)
    row.own:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(30, 30)
    row.icon:SetPoint("LEFT", S.space.sm, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Die Handwerksstufe in der Ecke des Symbols - dieselbe Ecke und
    -- dasselbe Zeichen wie im Beutel. Wer zwei Sorten desselben
    -- Heiltranks im Fenster stehen hat, unterscheidet sie sonst nur am
    -- Prozentwert.
    row.quality = row:CreateTexture(nil, "OVERLAY")
    row.quality:SetSize(15, 15)
    row.quality:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -2, 2)
    row.quality:Hide()

    row.title = S:Text(row, S.role.title.size, S.role.title.token)
    row.title:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm)
    row.title:SetWidth(contentWidth() - 140)

    -- Ein Grau fuer alle Unterzeilen. Sie tragen keine Deko, sondern
    -- Platz, Stufe, Fundort und "angelegt" - das liest man, und dunkler
    -- als die Notiz daneben zu sein hatte keinen Grund ausser der
    -- Reihenfolge, in der die Zeilen entstanden sind.
    row.detail = S:Text(row, S.role.detail.size, S.role.detail.token)
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
        -- Die Zeile des Fundort-Rasters traegt keinen Gegenstand,
        -- sondern einen Namen, der abgeschnitten sein kann.
        if type(self.dropName) == "string" then
            tipOutside(self)
            GameTooltip:SetText(self.dropName, 1, 1, 1)
            if type(self.dropNote) == "string" then
                GameTooltip:AddLine(self.dropNote, 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
            return
        end
        -- Ein Alternativbuild: was er gegen was tauscht.
        --
        -- RAWGET, wie bei __textW. Im Spiel gibt ein Rahmen fuer ein
        -- nicht gesetztes Feld nil zurueck; im Test gibt der Mock fuer
        -- jedes unbekannte Feld ein Kind zurueck, und das ist wahr. Mit
        -- self.swapAdded fiel jede Zeile in diesen Zweig - die
        -- Verzierungen verloren ihr zweites Tooltip und ein Talent sein
        -- eigenes.
        if rawget(self, "swapAdded") or rawget(self, "swapRemoved") then
            tipOutside(self)
            GameTooltip:SetText(self.title:GetText() or "", 1, 1, 1)
            local note = self.detail:GetText()
            if type(note) == "string" and note ~= "" then
                GameTooltip:AddLine(note, 0.7, 0.7, 0.7)
            end
            swapLines(rawget(self, "swapAdded"), rawget(self, "swapRemoved"))
            GameTooltip:Show()
            return
        end
        -- Zwei Gegenstaende in einer Zeile: eine Kombination aus zwei
        -- Verzierungen. Ein Tooltip zum ersten von zweien waere eine
        -- halbe Auskunft - also beide, der zweite unter dem ersten.
        if self.ids and #self.ids > 1 then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. self.ids[1])
            GameTooltip:Show()
            local second = secondTooltip()
            second:SetOwner(self, "ANCHOR_NONE")
            second:ClearAllPoints()
            second:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", 0, -6)
            second:SetHyperlink("item:" .. self.ids[2])
            second:Show()
            return
        end
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
        -- Ein fertiger Link aus gemessenen Bonus-IDs wird NICHT neu
        -- gebaut: er traegt schon Stufe, Qualitaet, Verzierung und
        -- Werte, und jeder Nachbau verliert davon etwas.
        if self.fullLink then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.fullLink)
            GameTooltip:Show()
            return
        end
        if self.itemID and self.wantBonus then
            link = ns.Compat.LinkWith(self.itemID, self.wantBonus, self.statBonus)
        elseif self.itemID and self.wantLevel then
            link = ns.Compat.LinkAtLevel(self.itemID, self.wantLevel, self.statBonus) or link
        elseif self.itemID and self.statBonus then
            link = ns.Compat.LinkWith(self.itemID, self.statBonus)
        end
        if not link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetAlpha(self.__header and 0 or 0.5)
        GameTooltip:Hide()
        if secondFrame then secondFrame:Hide() end
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
---Setzt das Qualitaetszeichen auf das Symbol einer Zeile - oder raeumt
---es ab. Beides immer: eine Zeile wird wiederverwendet, und das Zeichen
---des Vorgaengers auf einem anderen Gegenstand waere eine Luege.
---@param row table
---@param itemID number|nil
local function setQuality(row, itemID)
    if not row.quality then return end
    -- Erst der Katalog: er fuehrt Stufe UND Zeichen so, wie das Spiel
    -- sie fuehrt. Erst wenn er den Gegenstand nicht kennt, wird
    -- geschaetzt.
    local _, fromCatalog = ns.Catalog.Quality(itemID)
    local atlas = fromCatalog or ns.Compat.QualityAtlas(ns.Compat.CraftQuality(itemID))
    if atlas and row.quality.SetAtlas then
        row.quality:SetAtlas(atlas)
        row.quality:Show()
    else
        row.quality:Hide()
    end
end

local function resetRow(row)
    -- Eine Karte gehoert zu genau EINER Art Zeile.
    --
    -- Zeilen werden wiederverwendet, und eine vergessene Karte lag sonst
    -- mitten in einem anderen Abschnitt: unter Top-Spielern stand die
    -- Buildkarte quer ueber den Namen. Hier ist die eine Stelle, durch
    -- die jede Zeile laeuft, bevor sie neu gefuellt wird - vorher stand
    -- das Verstecken im Zeichner, und der kehrt fuer Kennwerte, Notizen
    -- und Runenschmieden vorher um.
    if cardOf[row] then cardOf[row]:Hide() end
    -- Dasselbe fuer die Kaestchen des Rasters: sonst steht das
    -- Fundort-Raster quer ueber der Ausruestung, sobald man den
    -- Abschnitt wechselt.
    for _, cell in ipairs(cellsOf[row] or {}) do cell:Hide() end
    if barOf[row] then
        barOf[row].track:Hide()
        barOf[row].fill:Hide()
    end
    -- Und den Namen, an dem der Zeiger der Zeile haengt.
    --
    -- Er stand in setHeaderRow, und das ist NUR die Ueberschrift - die
    -- gewoehnlichen Zeilen liefen nie dadurch. In der Ausruestung
    -- zeigte der Zeiger deshalb "Moerdergasse, 6 von 6 noch offen"
    -- ueber einem Helm. Hier laeuft jede Zeile durch.
    row.dropName = nil
    row.dropNote = nil
    -- Auch der Tausch: eine wiederverwendete Zeile zeigte sonst den
    -- Zeiger ihres Vorgaengers.
    row.swapAdded = nil
    row.swapRemoved = nil

    -- UND DIE BREITE DER TEXTSPALTEN.
    --
    -- Sie gehoert der Zeilenart, nicht der Zeile: das Fundort-Raster
    -- macht den Titel schmal, damit rechts die Kaestchen Platz haben.
    -- Der Zeichner setzt die Breite nur neu, wenn sich die
    -- FENSTERBREITE geaendert hat - beim Wechsel des Abschnitts
    -- aendert sie sich nicht. Also behielt in der Ausruestung jede
    -- Zeile die schmale Spalte des Rasters, und die Namen standen
    -- abgeschnitten da, obwohl rechts Platz war.
    row.__textW = nil
    local w = tonumber(contentWidth())
    if w and w > 0 then
        row.title:SetWidth(math.max(80, w - 140))
        row.detail:SetWidth(math.max(80, w - 140))
    end
    row.link = nil
    -- Auch das, woraus der Link beim Hovern entsteht. Eine Zeile wird
    -- wiederverwendet, und eine vergessene Gegenstands-ID zeigte sonst
    -- das Tooltip des Vorgaengers.
    row.itemID, row.wantLevel, row.wantBonus = nil, nil, nil
    -- Und die Wertewahl und die zweite Gegenstands-ID: eine
    -- wiederverwendete Zeile zeigte sonst das Tooltip des Vorgaengers.
    row.statBonus, row.ids = nil, nil
    row.fullLink = nil
    -- Und den Zauber: eine Talentzeile zeigt sein Tooltip, und eine
    -- wiederverwendete Zeile zeigte sonst den Zauber des Vorgaengers.
    row.spellID = nil
    -- Und eine fremde Schrift: eine Zeile, die eben einen koreanischen
    -- Namen trug, zeichnet den naechsten Gegenstandsnamen sonst in
    -- koreanischer Schrift - zu breit und mit seltsamen Abstaenden.
    S:ClearScript(row.title)
    S:ClearScript(row.detail)
    if row.quality then row.quality:Hide() end
    row.barTrack:Hide()
    row.barTarget:Hide()
    row.barMine:Hide()
    row.own:Hide()
    row.onClick = nil
end

-- Grossbuchstaben, die auch die Umlaute treffen.
--
-- string.upper geht byteweise und kennt nur a-z. Ein Umlaut besteht aus
-- zwei Bytes, von denen keines in diesem Bereich liegt - er bleibt also
-- klein stehen. "Fuesse" mit Umlaut wurde dadurch zu "FueSSE" mit
-- kleinem Umlaut mitten in einer Ueberschrift aus Grossbuchstaben,
-- ebenso "Ruecken" und "Haende". Drei von vierzehn Ueberschriften.
--
-- Also die vier deutschen Sonderzeichen vorher von Hand, dann den Rest.
-- Koreanisch und Chinesisch kennen keine Gross- und Kleinschreibung und
-- bleiben unberuehrt.
local UPPER = {
    ["\195\164"] = "\195\132",   -- a-Umlaut
    ["\195\182"] = "\195\150",   -- o-Umlaut
    ["\195\188"] = "\195\156",   -- u-Umlaut
    ["\195\159"] = "SS",         -- scharfes s
}

---@param text string|nil
---@return string
local function upperText(text)
    return (tostring(text or ""):gsub("\195[\164\182\188\159]", UPPER)):upper()
end

local function setHeaderRow(row, text)
    resetRow(row)
    row.__header = true
    row.bg:SetAlpha(0)
    row.icon:SetTexture(nil)
    S:ApplyRole(row.title, "head")
    row.title:ClearAllPoints()
    row.title:SetPoint("BOTTOMLEFT", S.space.sm, 4)
    row.title:SetText(upperText(text))
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

-- Das Raster der Fundorte.
--
-- Eine Zeile traegt links den Namen der Instanz und rechts bis zu zehn
-- Kaestchen. Die Kaestchen haengen an der Zeile und werden mit ihr
-- wiederverwendet - Zeilen werden im Fenster recycelt, und ein
-- Kaestchen, das bei jedem Bildlauf neu entsteht, waere ein Leck.
local DROP_ROW_HEIGHT = 54
local DROP_CELL_W, DROP_CELL_H = 38, 46

-- DIE NAMENSSPALTE WAECHST MIT DEM FENSTER.
--
-- Sie war fest 150 breit. Das reicht fuer "Moerdergasse" und schneidet
-- "Der Tempel von Sethraliss" mittendrin ab - und zwar auch dann, wenn
-- rechts neben den Kaestchen noch vierhundert Punkte leer stehen: ein
-- Dungeon hat drei Kaestchen, der Raid vierzehn, und die Spalte war fuer
-- den Raid bemessen.
--
-- Jetzt nimmt sie knapp ein Drittel der Breite, nie weniger als vorher
-- und nie mehr als 300 - darueber hinaus hilft sie keinem Namen mehr,
-- und die Kaestchen sollen nicht umbrechen muessen, nur damit die Spalte
-- Luft hat. Was dann immer noch nicht passt, wird gekuerzt und steht im
-- Zeiger vollstaendig.
local DROP_NAME_MIN = 150
local function dropNameW()
    local w = tonumber(contentWidth()) or 0
    return math.max(DROP_NAME_MIN, math.min(300, math.floor(w * 0.3)))
end

local function dropCell(row, i)
    local list = cellsOf[row]
    if not list then list = {}; cellsOf[row] = list end
    if list[i] then return list[i] end

    local c = CreateFrame("Button", nil, row)
    c:SetSize(DROP_CELL_W, DROP_CELL_H)
    c.bg = S:Fill(c, "bgOverlay", 0)
    -- Der Rahmen der Hervorhebung. Einmal gebaut, sonst versteckt.
    c.hl = S:Border(c, "accent")
    -- Und der goldene fuer Gemerktes. Zwei Rahmen auf demselben
    -- Rechteck: es ist immer nur einer zu sehen, und welcher, steht
    -- unten in setDropRow.
    c.favBorder = S:Border(c, "gold")
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(30, 30)
    c.icon:SetPoint("TOP", 0, -2)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Der Haken fuer "hast du schon".
    c.mark = c:CreateTexture(nil, "OVERLAY")
    c.mark:SetSize(16, 16)
    -- Links oben, weil rechts oben jetzt der Stern sitzt. Beides kann
    -- gleichzeitig zutreffen: man kann sich etwas merken, das man
    -- schon traegt - zum Beispiel, um es in einer hoeheren Stufe zu
    -- holen.
    c.mark:SetPoint("TOPLEFT", c.icon, "TOPLEFT", -4, 4)
    c.mark:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    c.mark:Hide()
    -- Der Stern: DEINE Wahl, nicht die Messung. Er sitzt links oben,
    -- der Haken rechts oben - beides kann gleichzeitig zutreffen.
    c.star = c:CreateTexture(nil, "OVERLAY")
    c.star:SetSize(20, 20)
    c.star:SetPoint("TOPRIGHT", c.icon, "TOPRIGHT", 6, 6)
    c.star:SetTexture("Interface\\Common\\FavoritesIcon")
    c.star:Hide()
    -- Und das Kreuz fuer Ignoriertes. Es bleibt stehen, damit man
    -- sieht, warum in diesem Dungeon wenig offen ist - und damit man
    -- es hier auch wieder zuruecknehmen kann.
    c.stop = c:CreateTexture(nil, "OVERLAY")
    c.stop:SetSize(16, 16)
    c.stop:SetPoint("CENTER", c.icon, "CENTER", 0, 0)
    c.stop:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    c.stop:Hide()
    c.share = S:Text(c, "caption", "textSecondary")
    c.share:SetPoint("TOP", c.icon, "BOTTOM", 0, -2)
    c.share:SetWidth(DROP_CELL_W)
    c.share:SetJustifyH("CENTER")
    c.share:SetWordWrap(false)

    c:SetScript("OnEnter", function(self)
        self.bg:SetAlpha(0.7)
        if not self.itemID then return end
        tipOutside(self)
        -- Erst die gewaehlte Stufe, dann der nackte Gegenstand.
        local link
        if self.wantBonus then
            link = ns.Compat.LinkWith(self.itemID, self.wantBonus)
        elseif self.wantLevel then
            link = ns.Compat.LinkAtLevel(self.itemID, self.wantLevel)
        end
        if link then
            GameTooltip:SetHyperlink(link)
        elseif GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(self.itemID)
        else
            GameTooltip:SetHyperlink("item:" .. self.itemID)
        end
        -- KEINE zweite Prozentzahl.
        --
        -- Der Tooltip-Haken von MetaCodex haengt an JEDEM Gegenstand
        -- und schreibt den Rang samt Anteil schon hinein. Eine eigene
        -- Zeile daneben sagte dasselbe ein zweites Mal - zwei Zahlen,
        -- die dasselbe meinen, lesen sich wie zwei Auskuenfte.
        --
        -- Was dort NICHT steht, ist der Boss. Und der ist der Grund,
        -- warum man hier ueberhaupt hinsieht.
        local wo = self.enc and ns.Compat.DropText(self.enc, nil)
        if wo then GameTooltip:AddLine(L["DROPS_FROM"]:format(wo), 1, 0.82, 0) end
        if self.worn then GameTooltip:AddLine(L["DROPS_WORN"], 0.4, 0.9, 0.4) end
        -- Warum das Kaestchen zurueckgetreten ist. Ohne diese Zeile
        -- sieht es aus wie ein Fehler: ein Stueck, das 43 % der Besten
        -- tragen, und es ist grau.
        if self.better and self.wornLevel then
            GameTooltip:AddLine(L["DROPS_HAVE_BETTER"]:format(self.wornLevel),
                0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function(self)
        self.bg:SetAlpha(0)
        GameTooltip:Hide()
    end)
    -- Shift-Klick verlinkt, Ctrl-Klick zieht an - dieselben Griffe wie
    -- in jeder anderen Zeile des Fensters.
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c:SetScript("OnClick", function(self, button)
        if not self.itemID then return end
        -- Rechtsklick: was DU zu dem Stueck sagst. Zwei Haken, und das
        -- Menue bleibt offen - man setzt selten nur einen.
        if button == "RightButton" then
            local id = self.itemID
            checkMenu(self, ns.Compat.ItemInfo(id) or ("#" .. id), {
                {
                    label = L["DROPS_FAV"],
                    on = function() return ns.Profile.Favorite(id) end,
                    toggle = function() ns.Profile.ToggleFavorite(id) end,
                },
                {
                    label = L["DROPS_IGNORE"],
                    on = function() return ns.Profile.Ignored(id) end,
                    toggle = function()
                        ns.Profile.SetIgnored(id, not ns.Profile.Ignored(id))
                    end,
                },
            })
            return
        end
        local _, link = ns.Compat.ItemInfo(self.itemID)
        if not link then return end
        if IsModifiedClick and IsModifiedClick("CHATLINK") then
            if HandleModifiedItemClick then HandleModifiedItemClick(link) end
        elseif IsModifiedClick and IsModifiedClick("DRESSUP") then
            if DressUpLink then DressUpLink(link) end
        end
    end)
    list[i] = c
    return c
end

---Eine Zeile des Rasters fuellen.
-- Schmaler als die Textspalte: ein Balken, der bis an ihren Rand
-- laeuft, liest sich wie ein Fortschritt, der gleich voll ist.
local function dropBarW() return dropNameW() - 40 end

local function dropBar(row)
    local b = barOf[row]
    if b then return b end
    b = {}
    b.track = row:CreateTexture(nil, "ARTWORK")
    b.track:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.track:SetVertexColor(S:Color("bgOverlay"))
    b.track:SetHeight(S:Pixel(3))
    b.track:SetPoint("TOPLEFT", S.space.sm, -40)
    b.fill = row:CreateTexture(nil, "OVERLAY")
    b.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.fill:SetHeight(S:Pixel(3))
    b.fill:SetPoint("TOPLEFT", S.space.sm, -40)
    barOf[row] = b
    return b
end

local function setDropRow(row, data)
    row.link = nil
    row.onClick = nil
    row.icon:SetTexture(nil)
    row.icon:SetSize(0, 0)
    row.share:SetText("")

    -- Eine Instanz hat einen Namen im Spiel; "Handwerk" hat keinen -
    -- da steht, was die Gruppe ist.
    local name = data.inst and (ns.Compat.InstanceName(data.inst)
        or ("#" .. tostring(data.inst)))
        or L["DROPS_PLACE_" .. tostring(data.place)] or "?"
    -- Lange Namen werden gekuerzt - "Die Gezeitengebundene..." -, also
    -- muss der Zeiger den ganzen zeigen. Dieselbe Regel wie in der
    -- Einkaufsliste: nichts abschneiden, ohne es lesbar zu lassen.
    row.dropName = name
    row.title:ClearAllPoints()
    row.title:SetPoint("TOPLEFT", S.space.sm, -S.space.sm)
    -- Die eigene Spalte gilt auch dann noch, wenn der Zeichner gleich
    -- die Zeilenbreite neu setzt.
    local nameW = dropNameW()
    row.__textW = nameW
    row.title:SetWidth(nameW)
    row.title:SetWordWrap(false)
    row.title:SetText(name)

    -- Die zweite Zeile zaehlt das OFFENE, nicht das Vorhandene: wer
    -- schon alles traegt, soll das lesen und weitergehen.
    row.detail:ClearAllPoints()
    row.detail:SetPoint("TOPLEFT", S.space.sm, -S.space.sm - 16)
    row.detail:SetWidth(nameW)
    row.detail:SetWordWrap(false)
    -- WIEVIEL und WIE GUT in einer Zeile.
    --
    -- "3 von 3 noch offen" sagt nur das erste. Welches Stueck dort auf
    -- einen wartet - eines, das fast alle Besten tragen, oder drei, die
    -- kaum jemand hat -, stand nirgends.
    local text = data.open == 0
        and L["DROPS_ALL_WORN"]:format(data.total or 0)
        or L["DROPS_ROW"]:format(data.open or 0, math.floor(data.best or 0))
    -- Was ignoriert ist, wird GENANNT, nicht verschwiegen: sonst
    -- wundert man sich, warum ein Dungeon so wenig hergibt.
    if (data.better or 0) > 0 then
        text = text .. "  ·  " .. L["DROPS_BETTER_N"]:format(data.better)
    end
    if (data.ignored or 0) > 0 then
        text = text .. "  ·  " .. L["DROPS_IGNORED_N"]:format(data.ignored)
    end
    row.detail:SetText(text)
    row.dropNote = row.detail:GetText()

    -- WIEVIELE KAESTCHEN IN EINE REIHE PASSEN, entscheidet die
    -- Fensterbreite. Was nicht mehr hineinpasst, kommt in die naechste
    -- Reihe - es wird nichts weggelassen.
    --
    -- Vorher stand am Ende ein Kaestchen "+6". Das war ein leerer
    -- Rahmen mit einer Zahl darin: es sah kaputt aus, und es
    -- beantwortete die Frage nicht, die es aufwarf - WELCHE sechs. Ein
    -- Umbruch beantwortet sie, ohne etwas zu verstecken.
    -- Der Balken: dieselbe Zahl, nach der sortiert wird, gemessen am
    -- Besten der Gruppe. Damit beantwortet die Zeile "mit Abstand oder
    -- knapp" - und das ist die Frage, die eine Reihenfolge offen
    -- laesst.
    do
        local b = dropBar(row)
        local anteil = tonumber(data.rel) or 0
        local barW = dropBarW()
        b.track:SetWidth(barW)
        if anteil > 0 then
            b.track:Show()
            b.fill:SetWidth(math.max(1, barW * math.min(1, anteil)))
            -- Die Zeile, an der man gemessen hat, traegt die
            -- Akzentfarbe; alles darunter die ruhige.
            -- Gedaempft, nicht bunt. Die Zeile oben traegt die
            -- Akzentfarbe, aber halb durchsichtig - sie soll den Blick
            -- fuehren, nicht ihn fangen.
            b.fill:SetVertexColor(S:Color(anteil >= 1 and "accent" or "textMuted",
                anteil >= 1 and 0.75 or 0.5))
            b.fill:Show()
        else
            b.track:Hide()
            b.fill:Hide()
        end
    end

    local stufe, stufenBonus = ns.Profile.TargetLevel()
    -- Die Hervorhebung: einmal je Zeile gelesen, nicht je Kaestchen.
    local wunsch = ns.Profile.DropsStats()
    local kombi = ns.Profile.DropsCombine()
    local gewaehlt = 0
    for _ in pairs(wunsch) do gewaehlt = gewaehlt + 1 end
    local frei = (contentWidth() or 0) - nameW - S.space.md - S.space.lg
    local proReihe = math.max(1, math.floor(frei / (DROP_CELL_W + 2)))
    local shown = 0
    for i, item in ipairs(data.items or {}) do
        local reihe = math.floor((i - 1) / proReihe)
        local spalte = (i - 1) % proReihe
        local c = dropCell(row, i)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", nameW + S.space.md + spalte * (DROP_CELL_W + 2),
            -4 - reihe * (DROP_CELL_H + 2))
        local _, link, icon = ns.Compat.ItemInfo(item.id)
        if not icon then ns.Compat.RequestItem(item.id) end
        c.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        -- Getragenes bleibt sichtbar und tritt zurueck: es erklaert,
        -- warum in diesem Dungeon wenig offen ist.
        -- Drei Zustaende am selben Kaestchen: getragen, ignoriert,
        -- gewuenscht. Ignoriert tritt am weitesten zurueck - es zaehlt
        -- nicht mehr mit.
        local zurueck = item.worn or item.ignored or item.better
        c.icon:SetDesaturated(zurueck and true or false)
        c.icon:SetAlpha(item.ignored and 0.25 or (zurueck and 0.4 or 1))
        c.mark:SetShown(item.worn and not item.ignored and true or false)
        c.star:SetShown(item.fav and true or false)
        c.stop:SetShown(item.ignored and true or false)
        c.share:SetText(string.format("%d %%", item.pct or 0))
        S:Recolor(c.share, item.worn and "textMuted" or "textSecondary")
        c.itemID, c.pct, c.enc, c.worn = item.id, item.pct, item.enc, item.worn
        c.link = link
        -- Die Stufe reist als ZAHL mit, nicht als fertiger Link: den
        -- baut erst das Hovern, weil der Client die Grundstufe beim
        -- Aufbau der Liste meist noch nicht hat.
        -- OHNE GEWAEHLTE STUFE DIE GEMESSENE.
        --
        -- "Wie die Besten spielen" heisst nicht "ohne Stufe": es heisst
        -- die Stufe, auf der wir es gemessen haben. Ohne diesen Rueckfall
        -- baute niemand einen Link, und der Zeiger zeigte die GRUNDstufe
        -- des Gegenstands - "Gegenstandsstufe 28" unter einem Ring, den
        -- die Besten auf 311 tragen.
        c.wantLevel, c.wantBonus = stufe or item.ilvl, stufe and stufenBonus or nil
        c.better, c.wornLevel = item.better, item.wornLevel

        -- PASST ES, PASST ES NICHT, ODER WISSEN WIR ES NICHT?
        --
        -- Drei Antworten, nicht zwei. Kennt der Client das Stueck noch
        -- nicht, kennt er auch seine Werte nicht - dann bleibt das
        -- Kaestchen, wie es ist. Es abzublenden hiesse "hat deine
        -- Werte nicht", und das wuerde der Spieler glauben.
        local passt
        if gewaehlt > 0 then
            passt = ns.Drops.Matches(link and ns.Tooltip.SecondaryStats(link),
                wunsch, kombi, item.fav)
        end
        -- GOLD STICHT DEN AKZENT.
        --
        -- Ein gemerktes Stueck, das auch noch zur Hervorhebung passt,
        -- traegt den goldenen Rahmen: die eigene Wahl ist die seltenere
        -- Auskunft. Dass es zur Hervorhebung passt, sagt schon, dass es
        -- nicht abgeblendet ist.
        for _, line in pairs(c.favBorder or {}) do
            line:SetShown(item.fav and not item.ignored and true or false)
        end
        for _, line in pairs(c.hl or {}) do
            line:SetShown(passt == true and not item.fav)
        end
        if passt == false then
            c.icon:SetDesaturated(true)
            c.icon:SetAlpha(0.3)
            S:Recolor(c.share, "textMuted")
        end

        c:Show()
        shown = i
    end
    -- Wie hoch die Zeile wird, entscheidet sich HIER und wird
    -- mitgegeben: der Zeichner setzt die Hoehe erst nach diesem
    -- Aufruf, und er kann nicht wissen, wie oft umgebrochen wurde.
    data.dropLines = math.max(1, math.ceil(shown / proReihe))
    for i = shown + 1, #(cellsOf[row] or {}) do cellsOf[row][i]:Hide() end
end

local function setItemRow(row, data)
    resetRow(row)
    row.__header = false
    row.bg:SetAlpha(0.5)
    -- Zielwerte setzen eine groessere Schrift; ohne diese Zeile behielte
    -- sie die naechste Zeile, die dieselbe Zeile wiederverwendet.
    S:ApplyRole(row.title, "title")
    -- Auch die Unterzeile. Ohne das erbt sie die Farbe der Zeile, die
    -- vorher an dieser Stelle stand - eine Warnung bleibt rot, ein
    -- gedaempfter Hinweis bleibt gedaempft, und zwar im naechsten
    -- Abschnitt an einem ganz anderen Gegenstand.
    S:ApplyRole(row.detail, "detail")
    row.title:ClearAllPoints()
    row.title:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm)
    row:SetHeight(ROW_HEIGHT)

    -- Das Fundort-Raster baut seine Zeile selbst: links der Name, rechts
    -- die Kaestchen. Eigene Funktion, damit setItemRow nicht noch einmal
    -- zwanzig Upvalues dazubekommt.
    if data.kind == "droprow" then
        setDropRow(row, data)
        return
    end

    -- Zielwerte haben keinen Gegenstand: statt eines Symbols traegt die
    -- Zeile ihren Rang, und statt einer Stueckzahl den Prozentwert und das
    -- Rating.
    if data.kind == "stat" then
        row.link = nil
        row.icon:SetTexture(nil)
        row.title:ClearAllPoints()
        -- KEINE EINRUECKUNG FUER EIN SYMBOL, DAS ES NICHT GIBT.
        --
        -- Die 26 Pixel waren fuer den Rang, der hier einmal links
        -- stand; er steht laengst rechts, wo die wichtigere Zahl hin
        -- gehoert. Die Luecke blieb - und eine Luecke am Zeilenanfang
        -- liest sich als fehlendes Symbol. Fuer Zweitwerte gibt es
        -- keines: das Spiel fuehrt in 19 643 Atlas-Elementen kein
        -- einziges fuer Krit, Tempo, Meisterschaft oder
        -- Vielseitigkeit.
        row.title:SetPoint("TOPLEFT", S.space.md, -S.space.sm)
        row.title:SetText(L["STAT_" .. data.statKey])
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.md, -S.space.sm - 16)
        -- Die linke Spalte hoert dort auf, wo die Bahn anfaengt.
        --
        -- Ohne Breite laeuft ein FontString so weit nach rechts, wie sein
        -- Text lang ist. Die Bahn liegt senkrecht genau darueber - von
        -- -14 bis -28, die Zeile bei -24 -, also lief der Text mitten
        -- durch den Balken: "die mittlere Haelfte liegt bei 1133 bis
        -- 1260" quer ueber die Fuellung.
        row.detail:SetWidth(BAR_X - S.space.md * 2)
        row.detail:SetWordWrap(false)

        -- Eine Bahn, die sich fuellt. Der gemeinsame Massstab bleibt,
        -- damit sichtbar ist, dass ein Kritziel groesser ist als ein
        -- Vielseitigkeitsziel - und darin steht, wie weit man selbst ist.
        row:SetHeight(STAT_ROW_HEIGHT)
        S:ApplyRole(row.title, "big")

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

        -- Nur der Anteil am Gesamtwert. Die Spanne der Gemessenen stand
        -- hier auch - "die mittlere Haelfte liegt bei 1133 bis 1260" -
        -- und ist zweimal gescheitert: sie passte nicht in die Spalte
        -- und lief quer durch die Bahn, und sie beantwortet eine Frage,
        -- die hier niemand stellt. Dass der Zielwert ein Median mit
        -- Streuung ist und keine BiS-Zahl, steht im Kopf der Seite.
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
        -- Ueber S:SetText, nicht direkt: in dieser Liste stehen Namen
        -- aus Korea neben Namen aus Europa, und die Standardschrift
        -- zeichnet die einen als leere Kaestchen.
        S:SetText(row.title, data.name or "?")
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm - 16)
        -- Der Realm traegt die Region schon: "Trollbane (EU)".
        S:SetText(row.detail, (data.realm or "") .. "  \194\183  " .. L["PLAYER_COPY"])
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
                -- Sein Platz, den die Karte traegt.
                rank = data.rank,
                -- Und woraus er geoeffnet wurde: Aktivitaet und Spec.
                -- Nicht data.mode - das ist der Fundort, der bei einer
                -- Ersatzquelle ein anderer ist als die Auswahl oben.
                openedIn = ns.Profile.Mode(), openedSpec = data.specID,
            }
            UI.Refresh()
        end
        return
    end

    if data.kind == "remind" then
        row.link = data.link
        row.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        setQuality(row, data.id)
        row.title:SetText(data.name or ("#" .. tostring(data.id)))
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm - 16)
        local token = data.state == "ok" and "success" or data.state == "low" and "warning" or "danger"
        -- "REICHT" NEBEN "6 FEHLEN" IST EIN WIDERSPRUCH.
        --
        -- "ok" heisst nicht, dass der Vorrat die Zielmenge erfuellt - es
        -- heisst, dass nicht gewarnt wird. Die Schwelle dafuer steht
        -- unter Einstellungen und liegt ab Werk bei der Haelfte. Wer 14
        -- von 20 hatte, las darum "14 von 20 · reicht" und daneben "6
        -- fehlen", und beides war nach seiner eigenen Lesart wahr.
        --
        -- Die Zahl bleibt, das Wort wird genau: "reicht" nur, wenn es
        -- wirklich reicht, sonst "kein Hinweis" - was der Zustand
        -- tatsaechlich bedeutet.
        local wort = data.state
        if wort == "ok" and (tonumber(data.owned) or 0) < (tonumber(data.need) or 0) then
            wort = "quiet"
        end
        row.detail:SetText(("%s  \194\183  %s  \194\183  |cff%s%s|r"):format(
            L["CONSUM_" .. data.ckind], L["REMIND_HAVE"]:format(data.owned, data.need),
            S:Hex(token), L["REMIND_STATE_" .. wort:upper()]))
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
        -- Der Realm steht hier, seit ueber der Zeile "Profil" steht
        -- und nicht mehr der Name mit seinem Realm.
        row.detail:SetText(data.realm
            and (data.realm .. "  \194\183  " .. L["GUIDE_COPY"]) or L["GUIDE_COPY"])
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
        S:ApplyRole(row.title, "note", data.tone == "ok" and "success" or nil)
        row.detail:SetText("")
        row.share:SetText("")
        row.onClick = nil
        return
    end

    if data.kind == "buildcard" then
        local card = buildCard(row)
        row.bg:SetAlpha(0)
        row.icon:SetTexture(nil)
        row.title:SetText("")
        row.detail:SetText("")
        row.share:SetText("")
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", S.space.sm, -S.space.sm)
        card:SetPoint("BOTTOMRIGHT", -S.space.sm, S.space.sm)
        local wide, small = specAtlas(data.specID)
        local w = math.max(1, contentWidth() - S.space.sm * 2)
        local h = CARD_HEIGHT * (S.fontScale or 1)
        fitArt(card, wide or small, w, h)
        card.title:SetText(data.cardTitle or L["CARD_TARGET"])
        -- Der Titel steht schon darueber; die Zeile darunter traegt die
        -- Zahl, nicht noch einmal den Namen.
        card.note:SetText(data.cardNote or L["CARD_SHARE"]:format(data.pct or 0))
        -- Ohne Kette waere die Karte ein Knopf, der nichts tut. Dann
        -- sagt sie das, statt zum Klicken einzuladen.
        local ready = data.text ~= nil and data.text ~= ""
        local hint = data.cardBody or (ready and L["LOADOUT_HINT"]:format(data.count)
            or L["LOADOUT_NO_STRING"])
        if data.fromBase then
            local whence
            for _, entry in ipairs(ns.MODES) do
                if entry.key == data.fromMode then whence = entry.label break end
            end
            hint = hint .. "  ·  " .. L["LOADOUT_FROM_BASE"]:format(whence or "?")
        end
        if data.fromSource then
            hint = hint .. "  ·  " .. L["LOADOUT_FROM_SOURCE"]:format(data.fromSource)
        end
        card.body:SetText(hint)
        S:Recolor(card.body, (ready or data.cardBody) and "textSecondary" or "warning")
        card:Show()
        -- Was der Klick hinlegt, sagt die Zeile: die Buildkarte ihre
        -- Kette, die Spielerkarte seine Adresse.
        local what = data.url or (ready and data.text) or nil
        row.onClick = what and function() UI.ShowLink(what) end or nil
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
            -- Die Zeile zeigt zwei Namen, der Zeiger alle - mit dem,
            -- was sie tun, und mit dem, was dafuer weicht.
            row.swapAdded = data.added
            row.swapRemoved = data.removed
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
        -- "Bereits drauf" nur, wenn DIESE Rune drauf ist.
        --
        -- Sitzt eine andere auf der Waffe, wird sie beim Namen genannt -
        -- dieselbe Sprache wie bei einem belegten Sockel. Vorher stand
        -- an der empfohlenen Rune "bereits drauf", sobald irgendeine
        -- Rune da war.
        if data.wornMatches then
            parts[#parts + 1] = "|cff" .. S:Hex("success") .. L["ALREADY_DONE"] .. "|r"
        elseif data.worn then
            local drauf = C_Spell and C_Spell.GetSpellInfo
                and C_Spell.GetSpellInfo(data.worn)
            parts[#parts + 1] = L["OTHER_ENCHANT"]:format(
                (drauf and drauf.name) or ("#" .. tostring(data.worn)))
        end
        row.detail:SetText(table.concat(parts, "  \194\183  "))
        row.share:SetText(data.pct and (data.pct .. "%") or "")
        S:Recolor(row.share, data.top and "accent" or "textMuted")
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
        -- Eine gerechnete Zahl sagt das an ihrer Zeile, nicht im
        -- Kleingedruckten am Seitenende.
        if data.single then parts[#parts + 1] = L["FOLIO_ONLY"]
        elseif data.derived then parts[#parts + 1] = L["FOLIO_DERIVED"]
        -- "bare" heisst: der Anteil steht schon rechts in der Zeile.
        elseif data.pct and not data.bare then
            parts[#parts + 1] = L["TALENT_SHARE"]:format(data.pct)
        end
        row.detail:SetText(table.concat(parts, "  \194\183  "))
        -- Steht nichts darunter, gehoert der Name in die Mitte.
        --
        -- Die Zeile ist fuer zwei Textzeilen gebaut: Name oben, Erklaerung
        -- darunter. Faellt die Erklaerung weg - und im Folianten faellt
        -- sie weg, weil sie nur den Prozentwert wiederholt hat -, dann
        -- klebt der Name an der Oberkante und darunter gaehnt eine
        -- Luecke, die aussieht, als fehle etwas.
        row.title:ClearAllPoints()
        if #parts == 0 then
            row.title:SetPoint("LEFT", S.space.sm + 38, 0)
        else
            row.title:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm)
        end
        row.share:SetText(data.pct and (data.pct .. "%") or "")
        -- Die Auszeichnung gehoert dem, was gemessen wurde - auch wenn
        -- die gerechnete Zahl groesser waere.
        S:Recolor(row.share, (data.top and not data.derived) and "accent" or "textMuted")
        row.onClick = nil
        return
    end

    if data.kind == "consumable" then
        row.link = data.link
        row.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        setQuality(row, data.id)
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
        end
        row.title:SetAlpha(data.alt and 0.75 or 1)
        row.icon:SetAlpha(data.alt and 0.6 or 1)

        row.share:SetText(data.pct and (data.pct .. "%") or "")
        S:Recolor(row.share, data.top and "accent" or "textMuted")
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
        row.statBonus, row.ids = data.statBonus, data.ids
        row.fullLink = data.fullLink
        -- Den Gegenstand anfordern, damit er beim Hovern da ist.
        if data.id and C_Item and C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, data.id)
        end
        row.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        -- Die Handwerksmarke, wenn der Gegenstand eine hat.
        --
        -- Dieselbe Ecke wie bei den Verbrauchsguetern, dieselbe wie im
        -- Beutel. Die meisten Ausruestungsstuecke tragen keine: ihre
        -- Stufe steht in den Bonus-IDs, nicht am Gegenstand, und dann
        -- bleibt die Ecke leer.
        --
        -- Bei den Verzierungen sitzt sie am Reagenz. Das ist die Stufe
        -- DES REAGENZ, das hier verlinkt ist - nicht die eines
        -- gemessenen Spielers. Mit welcher Stufe die gearbeitet haben,
        -- steht in keiner Bonus-ID und ist von aussen nicht zu sehen.
        setQuality(row, data.id)
        row.title:SetText(data.name or ("#" .. tostring(data.id)))
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", S.space.sm + 38, -S.space.sm - 16)
        -- Set- und Handwerksteile werden benannt. Ohne das sehen Kopf
        -- und Schultern aus, als gaebe es nur Tier - die Alternativen
        -- stehen unkommentiert daneben.
        local detail = data.slotLabel or data.group or ""
        -- Welche Zweitwerte auf diesem Stueck stehen. Beim Handwerk ist
        -- das die Antwort auf die Frage, mit der man in die Liste geht.
        if data.stats then
            detail = detail .. "  ·  " .. L["STAT_" .. data.stats[1]]
                .. "/" .. L["STAT_" .. data.stats[2]]
            if data.statPct then
                detail = detail .. " " .. L["CRAFTSTATS_SHARE"]:format(data.statPct)
            end
        end
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
        S:Recolor(row.share, data.top and "accent" or "textMuted")
        -- Der Hinweis steht IM Titel und nicht in der Unterzeile: die
        -- ist mit Stufe, Marke, Fundort und "angelegt" schon voll, und
        -- was man anklicken soll, gehoert nach vorn.
        if data.more then
            row.title:SetText((data.name or ("#" .. tostring(data.id)))
                .. "  |cff" .. S:Hex("textSecondary")
                .. (data.open and L["GEAR_LESS"] or L["GEAR_MORE"]:format(data.more))
                .. "|r")
            row.onClick = function()
                gearUnfolded[data.slot] = (not gearUnfolded[data.slot]) or nil
                ns.UI.Refresh()
            end
        else
            row.onClick = nil
        end
        return
    end

    if data.pending then
        row.link = nil
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.title:SetText(L["PICK_" .. data.pending:upper()])
        S:Recolor(row.title, "warning")
        row.detail:SetText(L["SLOT_" .. data.slot] .. "  ·  " .. slotCount(data.need))
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
        S:Recolor(row.share, data.top and "accent" or "textMuted")
    else
        row.share:SetText("")
    end

    local parts = { L["SLOT_" .. data.slot] }
    if data.kind == "gem" then
        -- Leer und anders belegt sind zweierlei.
        --
        -- Hier stand die Fehlmenge als "davon %d leer" - und die ist leer
        -- PLUS falsch belegt. Wer zwei Sockel bewusst anders besetzt hat,
        -- las von zwei leeren Sockeln. Fuer den Einkauf bleibt es
        -- dieselbe Zahl; der Satz sagt jetzt, woraus sie besteht.
        local leer = data.empty or data.missing or 0
        local anders = math.max(0, (data.missing or 0) - leer)
        local wieviele = socketCount(data.need)
        if leer > 0 and anders > 0 then
            parts[#parts + 1] = L["SOCKETS_BOTH"]:format(wieviele, leer, anders)
        elseif anders > 0 then
            parts[#parts + 1] = L["SOCKETS_OTHER"]:format(wieviele, anders)
        else
            parts[#parts + 1] = L["SOCKETS"]:format(wieviele, leer)
        end
    else
        parts[#parts + 1] = slotCount(data.need)
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
        head.label:SetText(upperText(L[group]))
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
        -- Ein Untereintrag rueckt ein und traegt einen Haken davor.
        -- Ohne beides sieht er aus wie ein gleichrangiger Punkt, und
        -- dann ist die Ordnung, die er ausdruecken soll, nicht zu sehen.
        button.label:SetPoint("LEFT", S.space.md + (section.sub and 14 or 0), 0)
        button.label:SetText((section.sub and "\194\183 " or "")
            .. L["SECTION_" .. section.key])
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
    -- Am Rahmen, damit /mc probe und die Tests sie lesen koennen.
    frame.sectionTitle = sectionTitle

    -- Der Stufenfilter gehoert in den Abschnitt, nicht in die ohnehin
    -- volle Kopfzeile: er gilt nur fuer die Ausruestung.
    local levelButton = makeButton(content, 175, 22, "", function(self)
        -- Beim Handwerk ist es eine andere Frage: ein Handwerksstueck
        -- wird nicht mit einem Schluesselstein aufgewertet.
        if activeSection().key == "crafted" then
            openCraftLevelPicker(self, rawget(frame, "__craftLevels") or {})
        else
            openKeyPicker(self)
        end
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

    -- Wonach das Fundort-Raster sortiert.
    local sortButton = makeButton(content, 170, 22, "", function(self)
        contextMenu(self, L["DROPS_SORT"], {
            { key = "sum", label = L["DROPS_SORT_SUM"] },
            { key = "best", label = L["DROPS_SORT_BEST"] },
        }, function(entry) ns.Profile.SetDropsSort(entry.key) end)
    end)
    frame.sortButton = sortButton

    -- Die Hervorhebung des Fundort-Rasters.
    --
    -- Kein Filter: sie versteckt nichts, sie hebt hervor. Was nicht
    -- passt, bleibt sichtbar und tritt zurueck - sonst weiss man nie,
    -- ob der Dungeon nichts hat oder die Auswahl zu eng war.
    local highlightButton = makeButton(content, 170, 22, "", function(self)
        local entries = {}
        for _, key in ipairs(ns.SECONDARY) do
            entries[#entries + 1] = {
                label = L["STAT_" .. key],
                on = function() return ns.Profile.DropsStats()[key] == true end,
                toggle = function() ns.Profile.ToggleDropsStat(key) end,
            }
        end
        entries[#entries + 1] = {
            label = L["DROPS_HL_FAV"],
            on = function() return ns.Profile.DropsStats().fav == true end,
            toggle = function() ns.Profile.ToggleDropsStat("fav") end,
        }
        entries[#entries + 1] = {
            label = L["DROPS_HL_NONE"],
            on = function() return ns.Profile.DropsStats().none == true end,
            toggle = function() ns.Profile.ToggleDropsStat("none") end,
        }
        entries[#entries + 1] = { spacer = true }
        entries[#entries + 1] = {
            label = L["DROPS_HL_COMBINE"],
            on = function() return ns.Profile.DropsCombine() end,
            toggle = function() ns.Profile.ToggleDropsCombine() end,
        }
        checkMenu(self, L["DROPS_HL"], entries)
    end)
    frame.highlightButton = highlightButton

    local originButton = makeButton(content, 170, 22, "", function(self)
        openSourcePickerGear(self, frame.__sources or {})
    end)
    frame.originButton = originButton

    -- Die Wertewahl eines Handwerksstuecks. Nur dort sichtbar, wo sie
    -- etwas aendert: ein Set-Teil hat seine Werte, ein Handwerksstueck
    -- bekommt sie beim Herstellen.
    local statButton = makeButton(content, 170, 22, "", function(self)
        openCraftStatPicker(self)
    end)
    frame.statButton = statButton

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

    -- Eine eigene Leiste, weil Blizzards nicht hierher gehoert.
    --
    -- UIPanelScrollFrameTemplate bringt eine Leiste mit zwei Pfeil-
    -- knoepfen mit, in Blizzards Metall-Optik. In einem Fenster, das
    -- sonst aus flaechigen Toenen und duennen Linien besteht, sieht das
    -- aus wie ein Ersatzteil aus einem anderen Geraet. Die Vorlage
    -- bleibt - sie kann das Scrollen -, ihre Sichtbarkeit nicht.
    for _, teil in ipairs({ "", "ScrollUpButton", "ScrollDownButton" }) do
        local k = _G["MetaCodexScrollScrollBar" .. teil]
        if k then k:Hide(); k:SetAlpha(0); k:EnableMouse(false) end
    end

    -- Schiene und Griff: zwei Flaechen, mehr braucht es nicht.
    local rail = CreateFrame("Frame", nil, content)
    rail:SetWidth(SCROLLBAR_WIDTH)
    -- An der LINKEN Kante verankert, nicht an der rechten.
    --
    -- Vorher hing sie mit ihrer rechten Kante zwoelf Pixel neben dem
    -- Inhalt - bei vier Pixel Breite blieben davon acht Abstand, bei
    -- zehn nur noch zwei, und sie klebte an den Zeilen. So haengt der
    -- Abstand nicht mehr an der Breite: links immer zwoelf, egal wie
    -- breit die Leiste wird.
    rail:SetPoint("TOPLEFT", scroll, "TOPRIGHT", S.space.md, 0)
    rail:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", S.space.md, 0)
    S:Fill(rail, "bgOverlay")
    rail:Hide()
    frame.scrollRail = rail

    local grip = CreateFrame("Frame", nil, rail)
    grip:SetWidth(SCROLLBAR_WIDTH)
    grip:SetPoint("TOP", rail, "TOP", 0, 0)
    grip:SetHeight(40)
    S:Fill(grip, "borderSubtle")
    frame.scrollGrip = grip

    -- Ein Klick auf die Schiene springt dorthin.
    --
    -- Wer danebengreift, will trotzdem dorthin - und eine Leiste, bei
    -- der nur der Griff etwas tut, fuehlt sich kaputt an.
    rail:EnableMouse(true)
    rail:SetScript("OnMouseDown", function(self)
        local inhalt = tonumber(scrollChild:GetHeight()) or 0
        local sichtbar = tonumber(scroll:GetHeight()) or 0
        local weg = inhalt - sichtbar
        local schiene = tonumber(self:GetHeight()) or 0
        if weg <= 0 or schiene <= 0 then return end
        local _, mausY = GetCursorPosition()
        local skala = UIParent:GetEffectiveScale() / (frame:GetEffectiveScale() or 1)
        local oben = (self:GetTop() or 0)
        local wo = (oben - mausY * skala) / schiene
        if wo < 0 then wo = 0 elseif wo > 1 then wo = 1 end
        scroll:SetVerticalScroll(wo * weg)
    end)

    -- Der Griff folgt auch dem Mausrad, nicht nur dem Auffrischen.
    -- Sonst steht er still, waehrend die Liste unter ihm wandert.
    scroll:SetScript("OnVerticalScroll", function(self)
        if not rail:IsShown() then return end
        local schiene = tonumber(rail:GetHeight()) or 0
        local inhalt = tonumber(scrollChild:GetHeight()) or 0
        local sichtbar = tonumber(self:GetHeight()) or 0
        local weg = inhalt - sichtbar
        if weg <= 0 or schiene <= 0 then return end
        local laenge = tonumber(grip:GetHeight()) or 24
        local wo = (tonumber(self:GetVerticalScroll()) or 0) / weg
        if wo < 0 then wo = 0 elseif wo > 1 then wo = 1 end
        grip:ClearAllPoints()
        grip:SetPoint("TOP", rail, "TOP", 0, -wo * (schiene - laenge))
    end)

    -- Ziehen. Ohne das waere die Leiste eine Anzeige und kein Bedienteil.
    grip:EnableMouse(true)
    grip:SetScript("OnEnter", function(self) S:Recolor(self, "accent") end)
    grip:SetScript("OnLeave", function(self)
        if not self.__zieht then S:Recolor(self, "borderSubtle") end
    end)
    grip:SetScript("OnMouseDown", function(self)
        self.__zieht = true
        local _, mausY = GetCursorPosition()
        self.__vonY = mausY
        self.__vonScroll = scroll:GetVerticalScroll() or 0
        S:Recolor(self, "accent")
    end)
    grip:SetScript("OnMouseUp", function(self)
        self.__zieht = false
        S:Recolor(self, "borderSubtle")
    end)
    grip:SetScript("OnUpdate", function(self)
        if not self.__zieht then return end
        local hoehe = tonumber(rail:GetHeight()) or 0
        local inhalt = tonumber(scrollChild:GetHeight()) or 0
        local sichtbar = tonumber(scroll:GetHeight()) or 0
        local weg = inhalt - sichtbar
        if weg <= 0 or hoehe <= 0 then return end
        local _, mausY = GetCursorPosition()
        -- Der Zeiger bewegt sich in Bildschirmpunkten, die Leiste in
        -- Fensterpunkten - der Massstab des Fensters bringt beides
        -- zusammen.
        local skala = UIParent:GetEffectiveScale() / (frame:GetEffectiveScale() or 1)
        local verschoben = ((self.__vonY or 0) - mausY) * skala
        local anteil = verschoben / hoehe
        local neu = (self.__vonScroll or 0) + anteil * inhalt
        if neu < 0 then neu = 0 elseif neu > weg then neu = weg end
        scroll:SetVerticalScroll(neu)
    end)

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
    handoverHints(create, search)

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

-- Die Zeilenbauer in einer Tabelle.
--
-- NICHT aus Ordnungsliebe: WoWs Lua laesst einer Funktion hoechstens
-- 60 Upvalues, und UI.Refresh ruft ein Dutzend dieser Funktionen auf -
-- jede davon kostete eines. Ueber die Tabelle kostet der ganze Satz
-- nur noch ein einziges. Am 28.09. hat eine einzige zusaetzliche
-- Lokale die Grenze gerissen, und dann laedt UI.lua nicht mehr: kein
-- Fehler im Fenster, sondern gar kein Fenster.
--
-- Die Funktionen bleiben, wo sie sind - anderswo werden sie direkt
-- aufgerufen. Nur Refresh geht ueber diesen Umweg.
local BAU = {
    statRows = statRows,
    talentRows = talentRows,
    consumableRows = consumableRows,
    playerRows = playerRows,
    remindRows = remindRows,
    settingsRows = settingsRows,
    infoRows = infoRows,
    guideRows = guideRows,
    gearRows = gearRows,
    embellishRows = embellishRows,
    kindRows = kindRows,
    playerViewRows = playerViewRows,
}
-- Masse und feste Tabellen in EINEM Verzeichnis.
--
-- NICHT aus Ordnungsliebe, sondern aus demselben Grund wie BAU: WoWs
-- Lua laesst einer Funktion hoechstens 60 Upvalues, und UI.Refresh
-- fasst ein Dutzend Zahlen an, die alle einzeln zaehlen. Ueber dieses
-- Verzeichnis kostet der ganze Satz eines.
--
-- Die Locals bleiben stehen: die uebrigen Funktionen benutzen sie
-- unveraendert weiter, und zwei Namen fuer dieselbe Zahl gibt es
-- nicht - hier steht die Zahl selbst, einmal zugewiesen.
local MASS = {
    SECTIONS = SECTIONS, sidebarWidth = sidebarWidth,
    HEADER = HEADER, FOOTER = FOOTER,
    DUNGEON_SECTIONS = DUNGEON_SECTIONS, GEAR_SLOTS = GEAR_SLOTS,
    HEADER_ROW = HEADER_ROW, HEADER_BUTTON_H = HEADER_BUTTON_H,
    SUB_ROW_HEIGHT = SUB_ROW_HEIGHT, CARD_HEIGHT = CARD_HEIGHT,
    DROP_ROW_HEIGHT = DROP_ROW_HEIGHT, DROP_CELL_H = DROP_CELL_H,
    STAT_ROW_HEIGHT = STAT_ROW_HEIGHT, ROW_HEIGHT = ROW_HEIGHT,
    SHOPPING = SHOPPING,
    MIN_W = MIN_W, MIN_H = MIN_H, MAX_W = MAX_W, MAX_H = MAX_H,
}

function UI.Refresh()
    if not frame then return end

    local profile = ns.Profile.Current()
    local section = activeSection()
    if not UI.SectionHasData(section.key) then
        for _, candidate in ipairs(MASS.SECTIONS) do
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
    frame.sidebar:SetWidth(MASS.sidebarWidth())
    frame.content:ClearAllPoints()
    frame.content:SetPoint("TOPLEFT", MASS.sidebarWidth(), -MASS.HEADER)
    frame.content:SetPoint("BOTTOMRIGHT", 0, MASS.FOOTER)
    for _, button in ipairs(navButtons) do
        button:SetWidth(MASS.sidebarWidth() - S.space.md * 2)
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

    -- DAS MENUE BESTIMMT DIE MINDESTHOEHE.
    --
    -- Die Leiste wird nicht abgeschnitten und sie scrollt nicht: sie
    -- laeuft einfach weiter, und bei einem kleingezogenen Fenster stand
    -- die Haelfte davon ueber dem Spiel. Aufgefallen ist es erst, als
    -- aus drei Gruppen fuenf wurden - die feste Zahl von 480 Pixeln
    -- stammte aus einer Zeit, in der das Menue kuerzer war.
    --
    -- Gerechnet statt geschaetzt: was die Leiste gerade braucht, plus
    -- Kopf und Fuss. Damit stimmt die Grenze auch, wenn jemand eine
    -- Gruppe zuklappt oder die Schrift groesser stellt.
    do
        local braucht = math.ceil(-y + MASS.HEADER + MASS.FOOTER)
        local fsx = S.fontScale or 1
        local minH = math.max(math.floor(MASS.MIN_H * fsx), braucht)
        if frame.SetResizeBounds then
            frame:SetResizeBounds(math.floor(MASS.MIN_W * fsx), minH,
                MASS.MAX_W, MASS.MAX_H)
        end
        -- Ein Fenster, das schon kleiner ist, waechst einmal nach. Die
        -- Grenze allein holt es nicht zurueck.
        if (tonumber(frame:GetHeight()) or 0) + 1 < minH then
            -- Nur wachsen, NICHT merken: die gespeicherte Groesse ist
            -- die Wahl des Spielers. Unsere Korrektur darf nicht zu
            -- seiner werden - sonst haette ein Zuruecksetzen, das die
            -- Groesse vergisst, gleich wieder eine.
            frame:SetHeight(minH)
        end
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
    local mode = MASS.DUNGEON_SECTIONS[section.key] and ns.Profile.LookupMode(section.key)
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
    local dungeonMatters = MASS.DUNGEON_SECTIONS[section.key] == true
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

    -- Ueber S:SetText: dieselbe Zeile traegt im Spielerprofil einen
    -- Namen, der aus Korea kommen kann. Direkt gesetzt, erbte sie dessen
    -- Schrift.
    S:SetText(sectionTitle, L["SECTION_" .. section.key])

    -- Die Schluesselstufe gilt fuer alles, was Ausruestung zeigt - auch
    -- fuer Tier-Set und Handwerk. Vergleichen kann nur, wer beide auf
    -- derselben Stufe sieht.
    -- Auch ueber dem Fundort-Raster: dort stehen dieselben Stuecke,
    -- und ohne den Waehler zeigte ihr Zeiger die Grundstufe.
    local gearLike = section.key == "gear" or section.key == "tier"
        or section.key == "drops"
    local craftLevels = section.key == "crafted"
        and craftLevelsFor(specID, mode, wanted) or {}
    frame.__craftLevels = craftLevels
    frame.levelButton:SetShown(not viewingPlayer and (
        (gearLike and #ns.Compat.RewardTable() > 0)
        or (section.key == "crafted" and #craftLevels > 0)))
    if section.key == "crafted" then
        local pick = ns.Profile.CraftLevel()
        local list = craftLevels
        -- Eine Stufe, die es bei diesen Stuecken nicht gibt, faellt weg.
        local valid = pick == nil
        for _, ilvl in ipairs(list) do if ilvl == pick then valid = true end end
        if not valid then pick = nil; ns.Profile.SetCraftLevel(nil) end
        frame.levelButton.label:SetText(pick and L["ILVL"]:format(pick)
            or L["CRAFTLEVEL_BEST"])
    end

    -- Die Wertewahl nur beim Handwerk: nur dort ist sie eine Wahl.
    frame.statButton:SetShown(section.key == "crafted" and not viewingPlayer
        and #ns.Catalog.CraftStatChoices() > 0)
    local craftPick = ns.Profile.CraftStats()
    local craftStats = ns.Catalog.StatsOfBonus(craftPick)
    frame.statButton.label:SetText(craftStats
        and (L["STAT_" .. craftStats[1]] .. "  ·  " .. L["STAT_" .. craftStats[2]])
        or L["CRAFTSTATS_MEASURED"])
    local targetLabel = section.key ~= "crafted" and ns.Profile.TargetLabel() or nil
    if section.key == "crafted" then
        -- steht schon oben
    elseif targetLabel then
        frame.levelButton.label:SetText(targetLabel)
    elseif ns.Profile.KeyLevel() then
        local level = ns.Profile.TargetLevel()
        frame.levelButton.label:SetText(level
            and L["KEY_SHORT"]:format(ns.Profile.KeyLevel(), level) or "")
    elseif ns.Profile.AllLevels() then
        frame.levelButton.label:SetText(L["KEY_ALL"])
    else
        -- Die Vorgabe steht als das da, was sie ist: eine Stufe mit
        -- Pfad und Rang, genau wie eine gewaehlte. Ein eigenes Wort
        -- dafuer ("Vorgabe", "Standard") waere eine zweite Sprache fuer
        -- dieselbe Sache.
        local level = ns.Profile.TargetLevel()
        local probe = ns.Catalog.ProbeItem and ns.Catalog.ProbeItem()
        local hit = level and probe and ns.Compat.TrackFor(level, probe)
        frame.levelButton.label:SetText(
            (hit and L["KEY_LABEL"]:format(ns.Compat.TrackName(hit.track), hit.rank, level))
            or (level and L["KEY_LEVEL_ONLY"]:format(level))
            or "")
    end

    -- Die Hervorhebung gehoert nur zum Fundort-Raster.
    --
    -- Der Knopf sagt, WAS hervorgehoben wird, nicht nur DASS etwas
    -- hervorgehoben wird: "Krit + Meisterschaft" ist die Auskunft,
    -- "Hervorhebung (2)" waere ein Raetsel.
    frame.highlightButton:SetShown(section.key == "drops")
    frame.sortButton:SetShown(section.key == "drops")
    -- Kurz auf dem Knopf, voll im Menue.
    --
    -- Fuenf Waehler stehen in dieser Ansicht nebeneinander; jedes
    -- ueberfluessige Wort schiebt einen davon in die zweite Zeile, und
    -- ein einzelner Knopf, der dort haengt, sieht aus wie ein Fehler.
    frame.sortButton.label:SetText(ns.Profile.DropsSort() == "best"
        and L["DROPS_SORT_BEST_S"] or L["DROPS_SORT_SUM_S"])
    do
        local set = ns.Profile.DropsStats()
        local teile = {}
        -- Kurze Namen auf dem Knopf.
        --
        -- "Kritische Trefferwertung · Meisterschaft" ist zweihundert
        -- Pixel breit und schiebt die halbe Kopfreihe in die naechste
        -- Zeile. Im Menue steht der ganze Name, dort ist Platz.
        for _, key in ipairs(ns.SECONDARY) do
            if set[key] then teile[#teile + 1] = L["STAT_SHORT_" .. key] end
        end
        if set.fav then teile[#teile + 1] = L["DROPS_HL_FAV"] end
        if set.none then teile[#teile + 1] = L["DROPS_HL_NONE"] end
        frame.highlightButton.label:SetText(#teile == 0 and L["DROPS_HL"]
            or table.concat(teile, ns.Profile.DropsCombine() and " + " or " / "))
    end

    -- Der Platzwaehler gehoert zur Ausruestung UND zum Fundort-Raster.
    --
    -- Dort beantwortet er die engere Frage: nicht "wo faellt am
    -- meisten", sondern "wo faellt der Helm". Dieselbe Einstellung wie
    -- in der Ausruestungsliste - wer dort den Kopf gewaehlt hat, meint
    -- ihn hier auch.
    local slots = (section.key == "gear" or section.key == "drops")
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

    -- Ein Wechsel schliesst das Profil.
    --
    -- Nicht nur der des Abschnitts: auch Aktivitaet und Spec. Ein
    -- Spieler steht in genau EINER Rangliste, und wer oben auf Raid
    -- umstellt, sieht sonst weiter den M+-Spieler und denkt, der Knopf
    -- sei kaputt. Zurueck geht es in die Liste der neuen Auswahl.
    if viewingPlayer and (viewingPlayer.section ~= section.key
        or viewingPlayer.openedIn ~= base
        or viewingPlayer.openedSpec ~= specID) then
        viewingPlayer = nil
    end
    frame.backButton:SetShown(viewingPlayer ~= nil)

    local fromSource
    if layoutOnly then
        -- Die Zeilen von eben, nur neu gesetzt.
        fromSource = frame.__fromSource
    elseif viewingPlayer then
        currentRows = BAU.playerViewRows(viewingPlayer)
        -- Auch die Ueberschrift: der Name, dessen Profil offen ist,
        -- kann aus jedem Land kommen.
        S:SetText(sectionTitle, viewingPlayer.name)
        hintText:SetText(L["PLAYER_VIEW_HINT"])
    elseif section.key == "gear" then
        currentRows, fromSource = withFallback(function(source)
            return BAU.gearRows(specID, mode, source)
        end)
        -- Prozente bedeuten nicht ueberall dasselbe, und das gehoert
        -- dazugesagt: hier der Anteil der gemessenen Spieler, bei den
        -- Verzauberungen der Anteil am Platz, bei den Steinen der an
        -- allen Steinen. Ohne diesen Satz vergleicht man Zahlen, die
        -- verschiedene Fragen beantworten.
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted)
            or L["SHARE_GEAR"])
    elseif section.key == "tier" or section.key == "crafted" then
        local want = section.key == "tier" and "set" or "craft"
        currentRows, fromSource = withFallback(function(source)
            return BAU.kindRows(specID, mode, source, want)
        end)
        -- Und darunter, was auf diese Stuecke daraufkommt.
        --
        -- Eine eigene Ueberschrift, keine zweite Seite: die Frage
        -- "welches Stueck stelle ich her" und die Frage "was kommt
        -- darauf" gehoeren zusammen, und wer die zweite beantwortet,
        -- hat die erste gerade gestellt.
        if section.key == "crafted" then
            local verzierungen = BAU.embellishRows(specID, mode, wanted)
            if #verzierungen > 0 then
                for _, row in ipairs(verzierungen) do
                    row.group = L["SECTION_embellish"]
                    currentRows[#currentRows + 1] = row
                end
            end
        end
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted)
            or L["SHARE_GEAR"])
    elseif section.key == "stats" then
        currentRows, fromSource = withFallback(function(source)
            return BAU.statRows(specID, mode, source)
        end)
        -- Was die Zahl IST, gehoert ueber die Zahl.
        --
        -- Hier stand nichts, und ohne Erklaerung liest sich eine
        -- Zielzahl als Vorschrift. Sie ist die Mitte der Gemessenen je
        -- Wert - nicht der Build eines bestimmten Spielers, und die vier
        -- zusammen traegt so vermutlich niemand. Wer das weiss, weiss
        -- auch, wie er sie zu lesen hat.
        local n = currentRows[1] and currentRows[1].players
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted)
            or (n and L["STAT_HINT_N"]:format(n) or L["STAT_HINT"]))
    elseif section.key == "consumables" then
        currentRows, fromSource = withFallback(function(source)
            return BAU.consumableRows(specID, mode, source)
        end)
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted)
            or (L["CONSUM_HINT"] .. "  " .. L["SHARE_CONSUM"]))
    elseif section.key == "talents" then
        currentRows, fromSource = withFallback(function(source)
            return BAU.talentRows(specID, mode, source)
        end)
        -- EIN SATZ WIE AUF JEDER ANDEREN SEITE.
        --
        -- Hier stand "Gemessen fuer ..." - das wusste man schon, es steht
        -- oben im Waehler. Entfernt blieb ein Loch: Titel, Leerzeile,
        -- Waehler. Was hier fehlt, ist nicht die Wiederholung der
        -- Auswahl, sondern wofuer die Prozente stehen - genau wie bei
        -- Beliebt und bei den Verbrauchsguetern.
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted)
            or L["SHARE_TALENTS"])
    elseif section.key == "folio" then
        currentRows, fromSource = withFallback(function(source)
            return UI.FolioRows(specID, mode, source)
        end)
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted)
            or L["FOLIO_HINT"])
    elseif section.key == "drops" then
        currentRows, fromSource = withFallback(function(source)
            return UI.DropRows(specID, mode, source)
        end)
        -- Der Hinweis nennt die Antwort, nicht die Methode.
        --
        -- "Was die Besten tragen, nach Fundort sortiert" beschreibt,
        -- was die Liste IST. Die Frage war "wo muss ich rein" - und die
        -- beantwortet der Name, der oben steht.
        local erste
        for _, row in ipairs(currentRows) do
            if row.kind == "droprow" and row.inst and not erste then erste = row end
        end
        local wohin = erste and ns.Compat.InstanceName(erste.inst)
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted)
            or (wohin and (ns.Profile.DropsSort() == "best"
                and L["DROPS_TOP_BEST"] or L["DROPS_TOP_SUM"]):format(wohin))
            or L["DROPS_HINT"])
    elseif section.key == "players" then
        currentRows, fromSource = withFallback(function(source)
            return BAU.playerRows(specID, mode, source)
        end)
        hintText:SetText(#currentRows > 0 and L["PLAYER_HINT"] or L["NO_PLAYERS"])
    elseif section.key == "remind" then
        currentRows = BAU.remindRows(mode)
        hintText:SetText(#currentRows > 3 and L["REMIND_HINT"] or emptyReason(mode, wanted))
    elseif section.key == "settings" then
        currentRows = BAU.settingsRows()
        hintText:SetText(L["SET_HINT"])
    elseif section.key == "info" then
        currentRows = BAU.infoRows()
        hintText:SetText("")
    elseif section.key == "guides" then
        currentRows = BAU.guideRows(specID)
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
    -- Zwei Abschnitte haben keine Kategorien: die Ausruestung hat ihren
    -- eigenen Platzwaehler, die Erinnerung ihre festen Gruppen. Sie
    -- laufen deshalb GAR NICHT durch diesen Block - auch nicht durch
    -- seine Pruefung. Sie hat hier einmal eine Wahl geloescht, die einem
    -- anderen Waehler gehoerte.
    local hasCategories = section.key ~= "gear" and section.key ~= "remind"
    local categories = hasCategories and categoriesIn(section, currentRows) or {}
    frame.__categories = categories
    frame.categoryButton:SetShown(#categories > 1)

    local picked = hasCategories and ns.Profile.Category(section.key) or nil
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
        local _, alle = categoryWords(section)
        frame.categoryButton.label:SetText(alle)
    end

    if picked then
        local kept = {}
        for _, row in ipairs(currentRows) do
            local key = (section.key == "consumables") and row.ckind
                or (section.key == "drops") and row.place
                or row.slot
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
    -- Eine ganze Gruppe statt eines Fundorts: "group:dungeon".
    local wantGroup = type(pickedSource) == "string"
        and pickedSource:match("^group:(.+)$") or nil
    local validSource = pickedSource == nil
    for _, src in ipairs(sources) do
        if wantGroup then
            -- Gueltig, solange die Gruppe ueberhaupt noch vorkommt.
            if src.group == wantGroup then
                validSource = true
                frame.originButton.label:SetText(L["ORIGIN_GALL_" .. wantGroup] or wantGroup)
            end
        elseif src.key == pickedSource then
            validSource = true
            frame.originButton.label:SetText(src.label)
        else
            -- Ein einzelner Boss ist auch eine Wahl.
            for _, boss in ipairs(src.bosses or {}) do
                if boss.key == pickedSource then
                    validSource = true
                    frame.originButton.label:SetText(boss.label)
                end
            end
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
            local hit = wantGroup and (row.sourceGroup or "other") == wantGroup
                or row.sourceKey == pickedSource
                or row.sourceBossKey == pickedSource
            if hit then kept[#kept + 1] = row end
        end
        -- Nichts von dieser Quelle ist eine Antwort, kein leeres Fenster.
        --
        -- Seit der Waehler ALLE Bosse eines Schlachtzugs zeigt, kann man
        -- einen anklicken, von dem niemand etwas traegt. Genau das ist
        -- die Auskunft - sie muss nur dastehen.
        if #kept == 0 then
            kept[1] = { kind = "note", text = L["ORIGIN_EMPTY"] }
        end
        currentRows = kept
    end

    -- Und jetzt falten: je Platz eine Zeile, der Rest auf Klick.
    --
    -- Ein einzeln gewaehlter Platz bleibt offen. Wer oben "Ring" sagt,
    -- hat schon gesagt, dass er die Ringe sehen will.
    if section.key == "gear" and not viewingPlayer and not ns.Profile.GearSlot() then
        local kept, head, offen = {}, nil, 0
        for _, row in ipairs(currentRows) do
            if head and head.slot == row.slot then
                -- So viele, wie man davon traegt.
                --
                -- Bei Ringen und Schmuck ist die zweitbeste Wahl keine
                -- Alternative, sondern das zweite Stueck: man traegt
                -- beide gleichzeitig. Eine einzelne Zeile mit "+4
                -- weitere" verlangte, den zweiten Ring hinter einem Klick
                -- zu suchen, als waere er ein Ersatz.
                if offen < (MASS.GEAR_SLOTS[row.slot] or 1) then
                    offen = offen + 1
                    kept[#kept + 1] = row
                else
                    head.more = (head.more or 0) + 1
                    if gearUnfolded[row.slot] then kept[#kept + 1] = row end
                end
            else
                head = row.slot and row or nil
                offen = 1
                if head then head.open = gearUnfolded[row.slot] == true end
                kept[#kept + 1] = row
            end
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
    -- Die Zahl daneben ist die MINDESTbreite, nicht die Breite.
    --
    -- fitted() misst den Text und macht den Knopf so breit, wie er sein
    -- muss. Eine hohe Mindestbreite kostet also nur Platz, ohne etwas
    -- zu gewinnen - und im Fundort-Raster stehen vier Waehler
    -- nebeneinander. Bei 170 brach die Reihe um und ein einzelner
    -- Knopf hing in der zweiten Zeile.
    local ROW = {
        { frame.backButton, 175 }, { frame.levelButton, 120 },
        { frame.statButton, 170 },
        { frame.slotButton, 110 }, { frame.originButton, 170 },
        { frame.heroButton, 170 }, { frame.categoryButton, 110 },
        { frame.highlightButton, 110 }, { frame.sortButton, 110 },
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
    -- Wo die Knopfreihe sitzt. Bei einer eigenen Reihe unter dem
    -- Hinweis, sonst neben dem Titel.
    local eigenerAbstand = 0
    local function rowOffset()
        return -S.space.lg - 2 - headerRows * MASS.HEADER_ROW - eigenerAbstand
    end


    -- DIE WAEHLER STEHEN IMMER AN DERSELBEN STELLE.
    --
    -- Vorher hingen sie rechts neben dem Titel - und wanderten damit
    -- mit ihrer Zahl: bei einem Waehler ganz rechts, bei dreien weiter
    -- links, bei fuenfen in eine zweite Zeile. Wer zwischen zwei
    -- Abschnitten wechselt, sucht sie dann jedes Mal neu.
    --
    -- Jetzt hat jeder Abschnitt denselben Aufbau: Titel, darunter der
    -- Satz, der die Frage beantwortet, darunter die Waehler - links
    -- beginnend, jeder so breit wie sein Text. Der erste steht immer an
    -- derselben Stelle, egal wie viele folgen.
    local sichtbar = {}
    for _, pair in ipairs(ROW) do
        if pair[1]:IsShown() then sichtbar[#sichtbar + 1] = pair end
    end

    -- KEINE WAEHLER, KEINE ZEILE DAFUER.
    --
    -- Die Erinnerung hat keinen einzigen - dort stand die Liste
    -- siebzig Pixel tiefer als noetig, mit einem leeren Streifen
    -- darueber, in dem bei anderen Abschnitten etwas steht.
    local hatWaehler = #sichtbar > 0
    headerRows = hatWaehler and 1 or 0
    -- Platz fuer den Hinweis, der ueber der Reihe steht.
    eigenerAbstand = hatWaehler and S.space.xl or 0

    local x, zeile = S.space.xl, 0
    local breite = contentWidth() - S.space.xl
    for _, pair in ipairs(sichtbar) do
        -- Passt der naechste nicht mehr, faengt eine zweite Reihe an.
        -- Lieber umbrechen als ueber den Rand laufen.
        if x + pair[2] > breite and x > S.space.xl then
            zeile = zeile + 1
            x = S.space.xl
        end
        pair[1]:ClearAllPoints()
        pair[1]:SetPoint("TOPLEFT", x, rowOffset() - zeile * MASS.HEADER_ROW)
        x = x + pair[2] + gap
    end
    headerRows = headerRows + zeile
    local wrapped = true
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
        + headerRows * MASS.HEADER_ROW
    -- UND ER ENDET NIE AUF DER KNOPFREIHE.
    --
    -- Bricht die Reihe um - drei Waehler und ein Titel passen in ein
    -- schmales Fenster nicht nebeneinander -, steht sie in einer
    -- eigenen Zeile UNTER dem Titel. Genau dort stand bisher auch der
    -- Hinweis: die Rechnung zaehlte die Zeilen der Knopfreihe mit, aber
    -- nicht die Hoehe der Knoepfe selbst, und vier Pixel davon lagen
    -- uebereinander.
    --
    -- Ausgerechnet statt geschaetzt: Oberkante der Reihe plus
    -- Knopfhoehe plus ein Abstand, minus dem Rand, den das Setzen
    -- ohnehin dazugibt.
    if false then
        local unten = S.space.lg + 2 + headerRows * MASS.HEADER_ROW
            + MASS.HEADER_BUTTON_H + S.space.sm - S.space.xl
        if unten > hintTop then hintTop = unten end
    end
    -- Bei einer eigenen Knopfreihe steht der Hinweis DARUEBER: direkt
    -- unter dem Titel, wo man ihn liest, bevor man die Waehler
    -- anfasst. Er beantwortet ja die Frage, die die Waehler nur
    -- verstellen.
    hintTop = S.space.md + 2
    hintText:ClearAllPoints()
    hintText:SetPoint("TOPLEFT", S.space.xl, -S.space.xl - hintTop)
    local hintHeight = 0
    if (hintText:GetText() or "") ~= "" then
        hintHeight = math.max(14, hintText:GetStringHeight() or 14)
    end
    local scrollTop = hintTop + hintHeight + (hintHeight > 0 and S.space.md or S.space.sm)
    if hatWaehler then
        -- Unter der Knopfreihe, nicht unter dem Hinweis: die Reihe
        -- steht zwischen beiden.
        local unten = S.space.lg + 2 + headerRows * MASS.HEADER_ROW + eigenerAbstand
            + MASS.HEADER_BUTTON_H + S.space.md - S.space.xl
        if unten > scrollTop then scrollTop = unten end
    end
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
            --
            -- AUSSER die Zeilenart sagt etwas anderes. Das
            -- Fundort-Raster haelt seine beiden Textspalten schmal,
            -- weil rechts die Kaestchen stehen; hier nachtraeglich
            -- verbreitert, lief die Unterzeile quer durch sie hindurch.
            local textW = rawget(row, "__textW") or math.max(80, width - 140)
            row.title:SetWidth(textW)
            row.detail:SetWidth(textW)
        end
        -- AUF GANZE BILDSCHIRMPIXEL.
        --
        -- Die Hoehe haengt an der Schriftskala und ist darum krumm:
        -- 46,8 statt 46. Jede zweite Zeilenkante landet dann auf einem
        -- halben Bildschirmpixel, und der Client verteilt die Flaeche
        -- ueber zwei Pixel - im Fenster sah das aus, als waere jede
        -- zweite Zeile ausgegraut. Es war keine Farbe, es war eine
        -- Kante.
        --
        -- S:Pixel rechnet in die Aufloesung des Bildschirms und zurueck,
        -- also stimmt es auch bei einer anderen UI-Skalierung.
        height = S:Pixel(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -S:Snap(offset))
        -- Die Zeile ist so hoch, wie sie Platz bekommt. Ohne das blieb
        -- jede Zeile 46 Pixel hoch, auch wo nur 24 gezaehlt wurden - und
        -- die Klickflaeche lag ueber der naechsten Zeile.
        row:SetHeight(height)
        row:Show()
        offset = offset + height
    end

    -- Wer in seiner Gruppe vorn liegt.
    --
    -- Hervorgehoben wurde bisher ab 50 %. Diese Schwelle kennen die
    -- Daten nicht: ein Stueck mit 48 % ist genauso das meistgetragene
    -- wie eines mit 51 %. Und bei einem breiten Feld - 31, 24, 19, 14 -
    -- bliebe die ganze Liste grau, obwohl es sehr wohl einen
    -- Spitzenreiter gibt. Die Spieler- und die Talentliste gehen
    -- laengst nach Rang; jetzt geht das Fenster ueberall so vor.
    --
    -- Je Gruppe, nicht je Liste: unter "Alle Plaetze" stehen mehrere
    -- Ueberschriften untereinander, und jede hat ihren eigenen ersten
    -- Platz. Derselbe Schluessel wie fuer die Ueberschrift, sonst
    -- leuchtet die Zeile in der falschen Gruppe.
    --
    -- Gleichstand hebt beide hervor: welcher von zwei Zeilen mit
    -- demselben Anteil der erste ist, sagt die Messung nicht.
    do
        local best = {}
        for _, data in ipairs(shown) do
            -- Unterzeilen nicht: eine Verzauberung ist Zubehoer der
            -- Zeile darueber und steht in keinem Wettbewerb.
            if data.pct and not data.sub then
                local key = data.group or (data.slot and L["SLOT_" .. data.slot]) or ""
                if not best[key] or data.pct > best[key] then best[key] = data.pct end
            end
        end
        for _, data in ipairs(shown) do
            local key = data.group or (data.slot and L["SLOT_" .. data.slot]) or ""
            data.top = data.pct ~= nil and not data.sub and data.pct == best[key]
        end
    end

    for _, data in ipairs(shown) do
        -- Ueberschrift, wenn die Gruppe wechselt. Zielwerte tragen keine,
        -- weil eine einzige Ueberschrift ueber vier Zeilen nur den
        -- Abschnittstitel wiederholen wuerde.
        local group = data.group or (data.slot and L["SLOT_" .. data.slot])
        -- Wo es zwei davon gibt, steht es in der Ueberschrift.
        local zweimal = group and data.slot and MASS.GEAR_SLOTS[data.slot]
        if zweimal then group = group .. "  ·  " .. slotCount(zweimal) end
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
        -- Im Reiter "Erinnerung" oeffnet jede Zeile dasselbe Menue.
        --
        -- Danach, nicht davor: die Zeilenarten setzen ihren eigenen
        -- Klick, und hier zaehlt, wo die Zeile steht, nicht was sie ist.
        if data.addOwn then
            row.onClick = function(self) openAddOwnItem(self) end
        elseif data.remindMenu then
            row.onClick = function(self) openRemindMenu(self, data) end
        end
        -- Eine Unterzeile ist halb so hoch und rueckt ein; die volle
        -- Hoehe bekaeme sonst Zubehoer, das nur mitlaeuft.
        if data.sub then
            row.icon:SetSize(16, 16)
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", S.space.sm + 38, 0)
            row.title:ClearAllPoints()
            row.title:SetPoint("LEFT", S.space.sm + 58, 0)
            S:ApplyRole(row.title, "detail")
            place(row, MASS.SUB_ROW_HEIGHT * (S.fontScale or 1))
        elseif data.kind == "buildcard" then
            place(row, (MASS.CARD_HEIGHT + 16) * (S.fontScale or 1))
        elseif data.kind == "droprow" then
            place(row, (MASS.DROP_ROW_HEIGHT
                + ((data.dropLines or 1) - 1) * (MASS.DROP_CELL_H + 2)) * (S.fontScale or 1))
        elseif data.kind == "note" then
            -- Eine Notiz ist eine Zeile Text, kein Gegenstand: Symbol
            -- klein, Text daneben auf halber Hoehe.
            row.icon:SetSize(data.tone == "ok" and 18 or 0, data.tone == "ok" and 18 or 0)
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", S.space.md, 0)
            row.title:ClearAllPoints()
            row.title:SetPoint("LEFT", data.tone == "ok" and (S.space.md + 24) or S.space.md, 0)
            S:ApplyRole(row.title, "note", data.tone == "ok" and "success" or nil)
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
            local height = (data.kind == "stat" and MASS.STAT_ROW_HEIGHT or MASS.ROW_HEIGHT) * fs
            -- Das Fundort-Raster NICHT: es setzt seine beiden
            -- Textspalten selbst und schmal, weil rechts die Kaestchen
            -- stehen. Hier nachtraeglich ueber die ganze Zeile
            -- gespannt, lief die Unterzeile quer durch sie hindurch -
            -- bei einem schmalen Fenster stand "1 hast du besser"
            -- mitten in den Symbolen.
            if data.kind ~= "stat" and data.kind ~= "droprow"
                and (row.detail:GetText() or "") ~= "" then
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

    -- Keine Leiste, wo es nichts zu schieben gibt.
    --
    -- Blizzards UIPanelScrollFrameTemplate blendet ihre beiden
    -- Pfeilknoepfe nie aus. Auf einer kurzen Seite stehen sie dann da
    -- und laden zu einer Bewegung ein, die nichts bewirkt - und schlimmer:
    -- sie sehen aus, als waere noch etwas da, das man nicht findet.
    --
    -- Die Vorlage benennt ihre Teile nach dem Rahmen, darum die Namen.
    -- Fehlt eines davon in einer kuenftigen Spielversion, passiert
    -- nichts weiter: dann bleibt es einfach sichtbar wie bisher.
    local sichtbar = tonumber(frame.scroll:GetHeight()) or 0
    local passt = offset <= sichtbar + 1
    -- Blizzards Leiste bleibt in jedem Fall weg; sie wurde beim Aufbau
    -- stillgelegt und wird hier nur nicht wieder geweckt.
    local rail, grip = frame.scrollRail, frame.scrollGrip
    if rail and grip then
        if passt then
            rail:Hide()
        else
            rail:Show()
            -- Der Griff ist so lang, wie der sichtbare Teil am Ganzen
            -- ausmacht - so sieht man an ihm, wieviel noch kommt.
            local schiene = tonumber(rail:GetHeight()) or 0
            local anteil = sichtbar / offset
            local laenge = math.max(24, schiene * anteil)
            grip:SetHeight(laenge)
            local weg = offset - sichtbar
            local wo = weg > 0
                and ((tonumber(frame.scroll:GetVerticalScroll()) or 0) / weg) or 0
            if wo < 0 then wo = 0 elseif wo > 1 then wo = 1 end
            grip:ClearAllPoints()
            grip:SetPoint("TOP", rail, "TOP", 0, -wo * (schiene - laenge))
        end
    end

    -- Und sagen, wenn eine andere Quelle geantwortet hat.
    if fellBack then
        hintText:SetText(L["SOURCE_FELL_BACK"]:format(
            wanted, type(fellBack) == "string" and fellBack or L["SOURCE_ALL"]))
        S:Recolor(hintText, "warning")
    end

    -- KEINE ZAHL MEHR OBEN RECHTS.
    --
    -- "2 zu kaufen" stand ueber einer Liste, in der jede Zeile selbst
    -- sagt, wie viel ihr fehlt. Zweimal dieselbe Auskunft, und die
    -- obere hing in der Ecke, wo sonst nichts steht.
    --
    -- WAS BLEIBT, ist der Hinweis auf mehrere Speccs: der sagt etwas,
    -- das in keiner Zeile steht - dass der Knopf unten mehr einkauft,
    -- als diese Seite zeigt.
    local specCount = #ns.Profile.ShoppingSpecs()
    local countText = ""
    if specCount > 1 and MASS.SHOPPING[section.key] then
        countText = L["COUNT_SPECS"]:format(specCount)
    end
    sectionCount:SetText(countText)

    -- "Nichts zu kaufen" nur dort, wo es ueberhaupt etwas zu kaufen gibt.
    --
    -- Die Meldung stand unter JEDEM leeren Abschnitt, auch unter den
    -- Talenten - und dort ist sie nicht nur falsch, sondern verwirrend:
    -- sie beantwortet eine Frage, die niemand gestellt hat.
    local shopping = MASS.SHOPPING[section.key] == true
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
    -- Ohne Auctionator gar nicht erst zeigen.
    --
    -- Grau heisst "geht, nur gerade nicht" - das ist beim geschlossenen
    -- Auktionshaus richtig, denn das kann man aendern. Fehlt Auctionator,
    -- geht es ueberhaupt nicht; ein grauer Knopf sieht dann aus wie ein
    -- kaputter. Warum er fehlt, steht unter "Info".
    frame.createButton:SetShown(usable and true or false)
    frame.searchButton:SetShown(usable and true or false)
    frame.createButton:SetEnabled(usable)
    frame.searchButton:SetEnabled(canSearch)
    frame.createButton:SetAlpha(1)
    frame.searchButton:SetAlpha(canSearch and 1 or 0.4)

    -- Die Liste am Auktionshaus zieht mit.
    --
    -- Wer dort steht und im Fenster etwas ignoriert oder eine Zielmenge
    -- aendert, will das Ergebnis sofort daneben sehen - nicht erst beim
    -- naechsten Besuch. Hier statt an jeder einzelnen Stelle: so ist
    -- jede Aenderung erfasst, auch die, an die heute niemand denkt.
    --
    -- Kostet nichts, wenn die Liste zu ist: sie rechnet erst, wenn sie
    -- sichtbar ist.
    if UI.RefreshAuctionPanel then UI.RefreshAuctionPanel() end
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

        local hint = S:Text(linkFrame, "caption", "textSecondary")
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
    row.title = S:Text(row, S.role.title.size, S.role.title.token)
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

---Wie viele Karten gerade sichtbar sind - fuer die Tests.
---
---Eine Karte, die nach dem Abschnittswechsel stehen bleibt, liegt quer
---ueber der naechsten Liste. Genau das ist passiert, und genau das
---zaehlt diese Auskunft.
---@return number
function UI.VisibleCards()
    local n = 0
    for _, card in pairs(cardOf) do
        if card.IsShown and card:IsShown() then n = n + 1 end
    end
    return n
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
    remindFrame.create:SetShown(usable and true or false)
    remindFrame.search:SetShown(usable and true or false)
    remindFrame.create:SetEnabled(usable and true or false)
    remindFrame.create:SetAlpha(1)
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
        handoverHints(remindFrame.create, remindFrame.search)
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
        if entry.gear then
            -- Eine offene Verzauberung ist nicht "nichts in der Tasche":
            -- sie gehoert auf ein Ausruestungsstueck, nicht in den Beutel.
            row.state:SetText(L["REMIND_WIN_GEAR"])
        elseif entry.owned > 0 then
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
---@param hinweis string|nil Ein Satz unter dem Titel
---@param alsGegenstand boolean|nil Zeigt, welcher Gegenstand die Zahl ist
function UI.AskNumber(title, current, accept, stellen, hinweis, alsGegenstand)
    if not numberFrame then
        numberFrame = CreateFrame("Frame", "MetaCodexNumber", UIParent)
        numberFrame:SetSize(380, 190)
        numberFrame:SetPoint("CENTER")
        numberFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        numberFrame:SetToplevel(true)
        numberFrame:EnableMouse(true)
        -- Ziehbar wie jedes andere Fenster hier: es geht in der Mitte
        -- auf, und dort steht manchmal genau das, was man ablesen will.
        numberFrame:SetMovable(true)
        numberFrame:RegisterForDrag("LeftButton")
        numberFrame:SetScript("OnDragStart", numberFrame.StartMoving)
        numberFrame:SetScript("OnDragStop", numberFrame.StopMovingOrSizing)
        S:Fill(numberFrame, "bgBase")
        S:Border(numberFrame, "borderStrong")

        -- Eigene Kopfzeile, wie beim Erinnerungsfenster.
        local head = CreateFrame("Frame", nil, numberFrame)
        head:SetPoint("TOPLEFT")
        head:SetPoint("TOPRIGHT")
        head:SetHeight(34)
        S:Fill(head, "bgRaised")
        S:Border(head, "borderSubtle", 1, { bottom = true })
        numberFrame.title = S:Text(head, "title", "textPrimary")
        numberFrame.title:SetPoint("LEFT", S.space.lg, 0)
        numberFrame.close = makeButton(head, 22, 22, "X", function() numberFrame:Hide() end)
        numberFrame.close:SetPoint("RIGHT", -S.space.sm, 0)

        numberFrame.hint = S:Text(numberFrame, "caption", "textSecondary")
        numberFrame.hint:SetPoint("TOPLEFT", S.space.lg, -44)
        numberFrame.hint:SetPoint("TOPRIGHT", -S.space.lg, -44)
        numberFrame.hint:SetJustifyH("LEFT")
        numberFrame.hint:SetWordWrap(true)

        local box = CreateFrame("EditBox", nil, numberFrame)
        box:SetAutoFocus(true)
        box:SetNumeric(true)
        box:SetMaxLetters(8)
        box:SetFontObject("GameFontHighlightLarge")
        box:SetHeight(30)
        box:SetTextInsets(S.space.sm, S.space.sm, 0, 0)
        S:Fill(box, "bgOverlay")
        S:Border(box, "borderSubtle")
        box:SetScript("OnEscapePressed", function() numberFrame:Hide() end)
        box:SetScript("OnEnterPressed", function() numberFrame.ok:Click() end)
        numberFrame.box = box

        -- Wer eine Gegenstands-ID eintippt, sieht beim Tippen, was es
        -- ist. Eine sechsstellige Zahl blind zu bestaetigen ist keine
        -- Auswahl, sondern ein Versuch.
        local vorschau = CreateFrame("Frame", nil, numberFrame)
        vorschau:SetHeight(38)
        S:Fill(vorschau, "bgRaised")
        S:Border(vorschau, "borderSubtle")
        vorschau.icon = vorschau:CreateTexture(nil, "ARTWORK")
        vorschau.icon:SetSize(26, 26)
        vorschau.icon:SetPoint("LEFT", S.space.sm, 0)
        vorschau.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        vorschau.text = S:Text(vorschau, "body", "textPrimary")
        vorschau.text:SetPoint("LEFT", vorschau.icon, "RIGHT", S.space.sm, 0)
        vorschau.text:SetPoint("RIGHT", -S.space.sm, 0)
        vorschau.text:SetJustifyH("LEFT")
        -- Und der Zeiger zeigt das ganze Tooltip.
        --
        -- Name und Symbol sagen, DASS es der richtige Gegenstand ist;
        -- ob man ihn haben will, sagt erst das Tooltip - Wirkung, Stufe,
        -- Stapelgroesse. Wer eine Zahl von Wowhead abtippt, will genau
        -- das nachsehen koennen, bevor er sie bestaetigt.
        vorschau:EnableMouse(true)
        vorschau:SetScript("OnEnter", function(self)
            if not numberFrame.zeigtGegenstand then return end
            local id = tonumber(numberFrame.box:GetText())
            if not id or id <= 0 then return end
            -- Nur wenn der Client den Gegenstand wirklich kennt: ein
            -- Tooltip zu einer Zahl, die es nicht gibt, bleibt leer
            -- stehen und sieht aus wie ein Fehler.
            if not ns.Compat.ItemInfo(id) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("item:" .. id)
            GameTooltip:Show()
        end)
        vorschau:SetScript("OnLeave", function() GameTooltip:Hide() end)
        numberFrame.vorschau = vorschau

        box:SetScript("OnTextChanged", function(self)
            if not numberFrame.zeigtGegenstand then return end
            local id = tonumber(self:GetText())
            if not id or id <= 0 then
                vorschau.icon:SetTexture(nil)
                S:SetText(vorschau.text, L["OWN_ADD_NONE"])
                S:Recolor(vorschau.text, "textMuted")
                return
            end
            local name, _, icon = ns.Compat.ItemInfo(id)
            if not name then ns.Compat.RequestItem(id) end
            vorschau.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            S:SetText(vorschau.text, name or L["OWN_ADD_WAIT"])
            S:Recolor(vorschau.text, name and "textPrimary" or "textMuted")
        end)

        numberFrame.ok = makeButton(numberFrame, 110, 26, L["NUMBER_OK"], function()
            local value = tonumber(numberFrame.box:GetText())
            numberFrame:Hide()
            if value and numberFrame.accept then numberFrame.accept(math.max(0, math.floor(value))) end
            UI.Refresh()
        end)
        numberFrame.ok:SetPoint("BOTTOMRIGHT", -S.space.lg, S.space.lg)
        numberFrame.cancel = makeButton(numberFrame, 110, 26, L["LINK_CLOSE"], function()
            numberFrame:Hide()
        end)
        numberFrame.cancel:SetPoint("BOTTOMRIGHT", numberFrame.ok, "BOTTOMLEFT", -S.space.sm, 0)
    end

    numberFrame.title:SetText(title)
    numberFrame.zeigtGegenstand = alsGegenstand == true
    numberFrame.hint:SetText(hinweis or "")
    local oben = (hinweis and hinweis ~= "")
        and (44 + math.max(14, numberFrame.hint:GetStringHeight() or 14) + S.space.sm)
        or 48
    numberFrame.box:ClearAllPoints()
    numberFrame.box:SetPoint("TOPLEFT", S.space.lg, -oben)
    numberFrame.box:SetPoint("TOPRIGHT", -S.space.lg, -oben)
    numberFrame.vorschau:ClearAllPoints()
    numberFrame.vorschau:SetPoint("TOPLEFT", S.space.lg, -oben - 38)
    numberFrame.vorschau:SetPoint("TOPRIGHT", -S.space.lg, -oben - 38)
    numberFrame.vorschau:SetShown(numberFrame.zeigtGegenstand)
    numberFrame:SetHeight(oben + 30 + (numberFrame.zeigtGegenstand and 46 or 8) + 26 + S.space.lg * 2)

    -- Mengen sind kurz, Gegenstands-IDs sechsstellig. Ohne das hier
    -- schnitt das Feld eine ID nach vier Ziffern ab.
    numberFrame.box:SetMaxLetters(stellen or 4)
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

        local hint = S:Text(textFrame, "caption", "textSecondary")
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
---Alles, was auf den Einkaufszettel gehoert.
---
---ZWEI QUELLEN, und das ist der Grund, warum es diese Funktion gibt.
---Verbrauchsgueter stehen in Remind.Status, Verzauberungen und Steine
---in List.Build. Die Uebergabe an Auctionator fragte beide, die Liste
---neben dem Auktionshaus nur die zweite - und stand leer da, waehrend
---im Fenster fuenf Dinge fehlten.
---
---Die Verbrauchsgueter bekommen Symbol und Link gleich mit: die Liste
---zeigt sie, und Remind.Status fuehrt nur Nummer und Name.
---@return table[] rows
function UI.ShoppingRows()
    local rows = {}
    for _, row in ipairs(ns.Remind.Status(ns.Profile.Mode())) do
        local buy = math.max(0, (row.need or 0) - (row.owned or 0))
        -- Ignoriertes gehoert nicht hinein. Es stand im Fenster nicht
        -- mehr und wurde trotzdem an Auctionator weitergereicht.
        if buy > 0 and not ns.Profile.Ignored(row.id) then
            local name, link, icon = ns.Compat.ItemInfo(row.id)
            if not name then ns.Compat.RequestItem(row.id) end
            rows[#rows + 1] = {
                kind = "consumable", id = row.id,
                name = name or row.name, link = link, icon = icon,
                buy = buy, need = row.need, owned = row.owned,
            }
        end
    end
    if ns.Profile.Complete() and not ns.Profile.IsForeignClass() then
        for _, row in ipairs(ns.List.Build(ns.Gear.Scan())) do
            if ns.List.Wanted(row) then rows[#rows + 1] = row end
        end
    end
    return rows
end

function UI.HandoverMissing(searchNow)
    if not ns.Adapter.Loaded() then
        ns.Print(L["NO_AUCTIONATOR"])
        return
    end
    local rows = UI.ShoppingRows()

    local ok, message, written
    if searchNow then
        ok, message = ns.Adapter.Search(rows)
    else
        -- ZUERST der Reiter, DANN die Liste.
        --
        -- CreateShoppingList feuert ein Ereignis, auf das Auctionators
        -- Einkaufsreiter hoert und die neue Liste auswaehlt - aber nur,
        -- wenn er in dieser Sitzung schon einmal offen war. War er es
        -- nie, hoert niemand zu: die Liste entstand, blieb aber
        -- unausgewaehlt, und erst der zweite Klick zeigte sie.
        --
        -- Andersherum ist der Reiter wach, wenn das Ereignis kommt.
        ns.Adapter.ShowShoppingTab()
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
-- Eine schmale Einkaufsliste neben dem Auktionshaus.
--
-- Erst war es ein Knopf oben im Auktionshaus-Fenster. Der sass mitten
-- in Blizzards eigenen Bedienelementen - und bei ElvUI, das dieses
-- Fenster umbaut, erst recht. Feste Koordinaten INNERHALB eines fremden
-- Fensters sind eine Wette darauf, dass niemand es anfasst.
--
-- Aussen angedockt haengt das Panel nur an der rechten Aussenkante, und
-- die behaelt auch ein umgebautes Auktionshaus. Nebenbei ist es das,
-- was man eigentlich will: die Liste NEBEN dem Haus, nicht ein Knopf,
-- der ein zweites Fenster darueberlegt.
local ahPanel
local AH_PANEL_ROWS = 11
local AH_ROW_HEIGHT = 34
local AH_PANEL_W = 250
-- Die Breiten werden GERECHNET, nicht gemessen.
--
-- GetWidth() liefert erst etwas, wenn die Oberflaeche einmal gerechnet
-- hat - beim ersten Zeichnen also null, und dann bleibt der Balken weg.
-- Das grosse Fenster macht es bei den Zielwerten genauso.
--
-- UND SIE HAENGEN ANEINANDER. Die Bahn hatte eine gesetzte Breite, die
-- Zahl daneben keine: "20 von 40" wuchs nach links auf den Balken. Wer
-- hier eine Zahl aendert, aendert die andere mit, weil sie sich aus
-- derselben Zeilenbreite ergeben.
local AH_ROW_W = AH_PANEL_W - 2 * S.space.sm  -- Zeile im Panel
local AH_TEXT_X = 34                          -- rechts vom Symbol
local AH_COUNT_W = 62                         -- "20 von 40"
local AH_TRACK_W = AH_ROW_W - AH_TEXT_X - AH_COUNT_W - S.space.sm

---Die Zeilen, die wirklich zu kaufen sind.
local function auctionRows()
    if not (ns.Data and ns.Data.Ensure and ns.Data.Ensure()) then return {} end
    -- Dieselbe Zusammenstellung wie die Uebergabe an Auctionator.
    -- Vorher stand hier eine eigene, die nur die halbe Quelle kannte.
    local ok, rows = pcall(UI.ShoppingRows)
    if not ok or type(rows) ~= "table" then return {} end
    return rows
end

local function buildAuctionPanel()
    if ahPanel then return ahPanel end
    -- An UIParent, nicht am Auktionshaus: ein Kind wird mitgeschnitten,
    -- wenn das Elternfenster kleiner ist als das Kind - und genau das
    -- ist es hier, denn das Panel steht daneben.
    local p = CreateFrame("Frame", "MetaCodexAuctionList", UIParent)
    p:SetWidth(AH_PANEL_W)
    p:SetFrameStrata("HIGH")
    S:Fill(p, "bgBase")
    S:Border(p, "borderSubtle")
    p:Hide()
    ahPanel = p

    p.title = S:Text(p, "title", "textPrimary")
    p.title:SetPoint("TOPLEFT", S.space.md, -S.space.md)
    p.title:SetText(L["AH_PANEL_TITLE"])

    p.count = S:Text(p, "caption", "textSecondary")
    p.count:SetPoint("TOPLEFT", S.space.md, -S.space.md - 20)

    -- Zu, aber nur fuer diesen Besuch: beim naechsten Auktionshaus ist
    -- es wieder da. Wer es nie will, schaltet es in den Einstellungen
    -- ab; wer es gerade nicht braucht, klickt hier.
    p.close = makeButton(p, 20, 20, "X", function() p:Hide() end)
    p.close:SetPoint("TOPRIGHT", -S.space.sm, -S.space.sm)

    p.rows = {}
    for i = 1, AH_PANEL_ROWS do
        -- Zwei Zeilen statt einer: oben der Name, darunter ein Balken
        -- mit "2/5". In einer Zeile drangen sich Name, Zahl und Wort um
        -- denselben Platz, und bei langen Namen gewann keiner.
        local r = CreateFrame("Button", nil, p)
        r:SetHeight(AH_ROW_HEIGHT)
        r:SetPoint("TOPLEFT", S.space.sm, -46 - (i - 1) * (AH_ROW_HEIGHT + 2))
        r:SetPoint("TOPRIGHT", -S.space.sm, -46 - (i - 1) * (AH_ROW_HEIGHT + 2))
        r.bg = S:Fill(r, "bgOverlay", 0)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(26, 26)
        r.icon:SetPoint("LEFT", S.space.xs, 0)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.name = S:Text(r, "body", "textPrimary")
        r.name:SetPoint("TOPLEFT", AH_TEXT_X, -4)
        r.name:SetPoint("RIGHT", -S.space.xs, 0)
        r.name:SetJustifyH("LEFT")
        -- EINE Zeile, sonst keine.
        --
        -- "Konzentrierter Alchemistischer Trank" passte nicht in die
        -- Breite, brach um - und die zweite Zeile lag auf dem Balken.
        -- Ohne Umbruch kuerzt das Spiel selbst mit "..." ab; den
        -- ganzen Namen zeigt der Zeiger.
        r.name:SetWordWrap(false)

        -- Die Bahn: wie weit man ist, nicht wieviel fehlt. Dasselbe
        -- Bild wie bei den Zielwerten, nur kleiner.
        r.track = r:CreateTexture(nil, "ARTWORK")
        r.track:SetTexture("Interface\\Buttons\\WHITE8X8")
        r.track:SetVertexColor(S:Color("bgOverlay"))
        r.track:SetHeight(S:Pixel(6))
        r.track:SetWidth(AH_TRACK_W)
        r.track:SetPoint("TOPLEFT", AH_TEXT_X, -21)
        r.fill = r:CreateTexture(nil, "OVERLAY")
        r.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
        r.fill:SetHeight(S:Pixel(6))
        r.fill:SetPoint("TOPLEFT", AH_TEXT_X, -21)

        r.count = S:Text(r, "caption", "textSecondary")
        r.count:SetPoint("RIGHT", -S.space.xs, -6)
        -- Ein eigenes Feld, rechtsbuendig: so endet die Zahl immer an
        -- derselben Kante und faengt nie dort an, wo der Balken noch
        -- laeuft.
        r.count:SetWidth(AH_COUNT_W)
        r.count:SetJustifyH("RIGHT")
        r.count:SetWordWrap(false)
        -- Der Zeiger zeigt IMMER etwas.
        --
        -- Ein abgeschnittener Name ist nur dann keine Zumutung, wenn
        -- man ihn irgendwo ganz lesen kann. Beim gekauften Gegenstand
        -- steht er ohnehin im Gegenstandsfenster; bei allem anderen -
        -- Verzauberung, Stein, Rune - gibt es keinen Link, und dort
        -- zeigen wir Namen und Stand selbst an.
        r:SetScript("OnEnter", function(self)
            self.bg:SetAlpha(0.6)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            if self.link then
                GameTooltip:SetHyperlink(self.link)
            elseif self.fullName then
                GameTooltip:SetText(self.fullName, 1, 1, 1)
                if self.countText then
                    GameTooltip:AddLine(self.countText, 0.7, 0.7, 0.7)
                end
            else
                return
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(self)
            self.bg:SetAlpha(0)
            GameTooltip:Hide()
        end)
        -- Shift-Klick gehoert dem Spiel: es haengt den Link in den Chat.
        -- Ein schlichter Klick sucht die Ware im Auktionshaus.
        r:SetScript("OnClick", function(self)
            if self.link and IsModifiedClick and IsModifiedClick("CHATLINK") then
                if HandleModifiedItemClick then HandleModifiedItemClick(self.link) end
                return
            end
            if self.itemName then UI.SearchAuctionHouse(self.itemName) end
        end)
        r:Hide()
        p.rows[i] = r
    end

    p.more = S:Text(p, "caption", "textMuted")
    p.more:SetPoint("TOPLEFT", S.space.md, -46 - AH_PANEL_ROWS * (AH_ROW_HEIGHT + 2) - 4)

    local foot = CreateFrame("Frame", nil, p)
    p.foot = foot
    foot:SetHeight(34)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    S:Fill(foot, "bgRaised")
    S:Border(foot, "borderSubtle", 1, { top = true })
    p.search = makeButton(foot, 72, 22, L["AH_PANEL_SEARCH"], function()
        UI.HandoverMissing(true)
    end)
    p.search:SetPoint("RIGHT", -S.space.sm, 0)
    p.create = makeButton(foot, 104, 22, L["AH_PANEL_LIST"], function()
        UI.HandoverMissing(false)
    end)
    p.create:SetPoint("RIGHT", p.search, "LEFT", -S.space.xs, 0)
    handoverHints(p.create, p.search)
    return p
end

---Was die Zeilen WIRKLICH messen - im Spiel, nicht in der Attrappe.
---
---Gebaut, weil ein Fehler nicht zu finden war, den man sieht: jede
---zweite Zeile wirkte heller. Haelfte, Hoehe und Lage lassen sich hier
---ausrechnen; was der Client daraus macht, sagt nur er selbst.
---@return nil
function UI.Pixel()
    local scale = UIParent:GetEffectiveScale()
    ns.Print(("Skalierung: %.4f  Fensterskala: %.4f"):format(
        scale or 0, (frame and frame:GetEffectiveScale()) or 0))
    local gezeigt = 0
    for _, row in ipairs(rows or {}) do
        if row:IsShown() then
            gezeigt = gezeigt + 1
            if gezeigt <= 8 then
                local hoehe = tonumber(row:GetHeight()) or 0
                local oben = tonumber(row:GetTop()) or 0
                -- In Bildschirmpixeln, denn darum geht es.
                local alpha = row.bg and row.bg.GetAlpha and row.bg:GetAlpha() or -1
                ns.Print(("%2d  hoehe %7.3f (%8.3f px)  oben %9.3f (%9.3f px)  bg %.2f"):
                    format(gezeigt, hoehe, hoehe * scale, oben, oben * scale, alpha))
            end
        end
    end
    ns.Print(("Zeilen sichtbar: %d"):format(gezeigt))
end

---Die Einkaufsliste am Auktionshaus schliessen.
---
---Gebraucht von der Einstellung: wer sie am offenen Auktionshaus
---abschaltet, soll nicht erst wieder hingehen muessen.
function UI.HideAuctionPanel()
    if ahPanel then ahPanel:Hide() end
end

---Das Panel mit dem aktuellen Stand fuellen.
function UI.RefreshAuctionPanel()
    if not ahPanel or not ahPanel:IsShown() then return end
    local rows = auctionRows()
    local fehltName = false
    -- Eine Sache ist kein "1 Dinge".
    local kopf = L["AH_PANEL_EMPTY"]
    if #rows == 1 then kopf = L["AH_PANEL_COUNT_1"]
    elseif #rows > 1 then kopf = L["AH_PANEL_COUNT"]:format(#rows) end
    ahPanel.count:SetText(kopf)
    for i, r in ipairs(ahPanel.rows) do
        local row = rows[i]
        if row then
            r.link = row.link
            r.itemName = row.name
            r.icon:SetTexture(row.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            -- Kennt der Client den Gegenstand noch nicht, steht hier
            -- seine Nummer - und wir fordern ihn an. Der Haken weiter
            -- unten zeichnet neu, sobald der Name da ist.
            if not row.name and ns.Compat and ns.Compat.RequestItem then
                ns.Compat.RequestItem(row.id)
                fehltName = true
            end
            -- Der ungekuerzte Name fuer den Zeiger: im Feld steht
            -- vielleicht nur "Konzentrierter Alchemisti...".
            r.fullName = row.name or ("#" .. tostring(row.id))
            r.name:SetText(r.fullName)

            -- "2 von 5": was da ist, gegen das, was gebraucht wird.
            -- Gerechnet aus denselben Zahlen wie die Zeile im grossen
            -- Fenster, damit nicht zwei Stellen verschiedenes sagen.
            local habe = row.owned or 0
            local will = habe + (row.buy or 0)
            r.countText = L["AH_PANEL_OF"]:format(habe, will)
            r.count:SetText(r.countText)
            if will > 0 then
                r.fill:SetWidth(math.max(1, AH_TRACK_W * math.min(1, habe / will)))
                -- Voll ist gruen, sonst die Warnfarbe. Hier steht nur,
                -- was noch offen ist, also ist es nie voll - aber wer
                -- waehrend des Einkaufs zusieht, soll es umschlagen
                -- sehen.
                r.fill:SetVertexColor(S:Color(habe >= will and "success" or "warning"))
                r.fill:Show()
            else
                r.fill:Hide()
            end
            r:Show()
        else
            r:Hide()
        end
    end
    ahPanel.more:SetText(#rows > AH_PANEL_ROWS
        and L["AH_PANEL_MORE"]:format(#rows - AH_PANEL_ROWS) or "")

    local usable = ns.Adapter and ns.Adapter.Loaded()
    local canSearch = usable and ns.Adapter.AuctionHouseOpen()
    -- Und mit ihnen die Fussleiste: zwei versteckte Knoepfe hinterlassen
    -- sonst einen leeren Streifen, der wie ein Fehler aussieht.
    ahPanel.foot:SetShown(usable and true or false)
    ahPanel.create:SetShown(usable and true or false)
    ahPanel.search:SetShown(usable and true or false)
    ahPanel.create:SetEnabled(usable and true or false)
    ahPanel.create:SetAlpha(1)
    ahPanel.search:SetEnabled(canSearch and true or false)
    ahPanel.search:SetAlpha(canSearch and 1 or 0.4)
end

---Einen Namen in das Suchfeld des Auktionshauses schreiben.
---
---Blizzards Feld heisst je nach Spielstand anders, und ElvUI baut das
---Fenster um - gefunden wird es deshalb ueber mehrere Wege, und wenn
---keiner traegt, passiert nichts. Ein Fehler aus fremdem Code waere das
---schlechtere Ende.
---@param name string
function UI.SearchAuctionHouse(name)
    if not name or name == "" then return end
    local box = AuctionHouseFrame and (AuctionHouseFrame.SearchBar
        and AuctionHouseFrame.SearchBar.SearchBox)
    if not box then box = _G["AuctionHouseFrameSearchBar"] end
    if box and box.SetText then
        box:SetText(name)
        if box.GetScript and box:GetScript("OnEnterPressed") then
            box:GetScript("OnEnterPressed")(box)
        end
        return true
    end
    -- Kein Feld gefunden: dann wenigstens sagen, wonach zu suchen ist.
    ns.Print(L["AH_PANEL_SEARCH_FALLBACK"]:format(name))
    return false
end

local function showAuctionPanel()
    if not AuctionHouseFrame then return end
    -- Abgeschaltet heisst abgeschaltet - und das gilt auch, wenn die
    -- Erinnerungen als Ganzes aus sind.
    if ns.Profile and ns.Profile.AuctionPanel and not ns.Profile.AuctionPanel() then
        if ahPanel then ahPanel:Hide() end
        return
    end
    local p = buildAuctionPanel()
    -- Bei jedem Oeffnen neu andocken: ElvUI und Blizzard setzen das
    -- Fenster verschieden, und wer es verschiebt, will das Panel
    -- mitnehmen.
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 4, 0)
    local h = tonumber(AuctionHouseFrame.GetHeight and AuctionHouseFrame:GetHeight()) or 0
    p:SetHeight(h > 200 and h or 520)
    p:Show()
    UI.RefreshAuctionPanel()
end

local ahWatch = CreateFrame("Frame")
ahWatch:RegisterEvent("AUCTION_HOUSE_SHOW")
ahWatch:RegisterEvent("AUCTION_HOUSE_CLOSED")
ahWatch:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        showAuctionPanel()
    elseif ahPanel then
        ahPanel:Hide()
    end
    if frame and frame:IsShown() then UI.Refresh() end
end)
-- Namen treffen nachtraeglich ein.
--
-- Der Client kennt einen Gegenstand erst, wenn er ihn vom Server geholt
-- hat; bis dahin steht in der Liste seine Nummer. Boot.lua hoert zwar
-- auf GET_ITEM_INFO_RECEIVED, steigt aber aus, wenn das grosse Fenster
-- zu ist - und beim Einkaufen ist es das meistens. Darum hoert das Panel
-- selbst.
--
-- Mit Verzoegerung: beim Oeffnen kommen Dutzende dieser Ereignisse
-- hintereinander, und jedes einzeln zu zeichnen waere Verschwendung.
local ahNames = CreateFrame("Frame")
ahNames:RegisterEvent("GET_ITEM_INFO_RECEIVED")
ahNames:SetScript("OnEvent", function(self)
    if not (ahPanel and ahPanel:IsShown()) then return end
    if self.timer and self.timer.Cancel then self.timer:Cancel() end
    if C_Timer and C_Timer.NewTimer then
        self.timer = C_Timer.NewTimer(0.2, function()
            self.timer = nil
            UI.RefreshAuctionPanel()
        end)
    else
        UI.RefreshAuctionPanel()
    end
end)

local ahBags = CreateFrame("Frame")
ahBags:RegisterEvent("BAG_UPDATE_DELAYED")
ahBags:SetScript("OnEvent", function()
    if ahPanel and ahPanel:IsShown() then UI.RefreshAuctionPanel() end
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


-- ----------------------------------------- Builds am Talentfenster
--
-- DER ORT ENTSCHEIDET. Die Frage "welchen Build nehme ich" stellt sich
-- im Talentfenster, nicht in unserem. Der Weg dahin war bisher: Addon
-- oeffnen, Build suchen, String kopieren, Talentfenster, Importieren,
-- einfuegen. Fuenf Schritte fuer etwas, das zwischen zwei Dungeons
-- passiert - und je Dungeon ein anderer Build.
--
-- NEBEN dem Fenster, nicht darin. Blizzards Talentoberflaeche ist
-- geschuetzt; wer in ihr etwas anfasst, riskiert "Diese Aktion ist
-- gesperrt" - und zwar irgendwann spaeter, an einer ganz anderen
-- Stelle. Dieses Panel haengt an UIParent und dockt nur an die
-- Aussenkante an, genau wie die Einkaufsliste am Auktionshaus.
local talentPanel
-- Breit genug, dass ein Buildname mehr als zwei Woerter zeigt. Bei 260
-- stand in jeder Zeile "Totemische Projektion, Wolfsaffinitaet d..." -
-- sieben Zeilen, die alle an derselben Stelle aufhoeren, unterscheiden
-- nichts. Breiter als 320 wird die Leiste zum zweiten Fenster.
local TP_WIDTH = 320
local TP_ROWS = 7
local TP_ROW_H = 38
-- Der Knopf zum Festhalten, rechts in jeder Zeile.
local TP_PIN = 18

---Schreibt in den Zeiger, was im Baum keinen Rahmen bekommen hat.
---@param fehlt table  aus Tree.Show: { { spell, why, hero } }
local function treeGaps(fehlt)
    if type(fehlt) ~= "table" or #fehlt == 0 then return end

    local function name(id)
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
        local n = info and info.name
        return type(n) == "string" and n or ("#" .. tostring(id))
    end

    -- Nach Grund gebuendelt: drei Zeilen "gehoert zu Totemist" sind eine
    -- Zeile mit drei Namen.
    local heroNames, heroWhich, andere = {}, nil, {}
    for _, gap in ipairs(fehlt) do
        if gap.why == "hero" then
            heroNames[#heroNames + 1] = name(gap.spell)
            heroWhich = heroWhich or gap.hero
        else
            andere[#andere + 1] = name(gap.spell)
        end
    end

    local wr, wg, wb = S:Color("warning")
    if #heroNames > 0 then
        GameTooltip:AddLine(L["TREE_OTHER_HERO"]:format(
            heroWhich or "?", table.concat(heroNames, ", ")), wr, wg, wb, true)
    end
    if #andere > 0 then
        GameTooltip:AddLine(L["TREE_NOT_DRAWN"]:format(
            table.concat(andere, ", ")), wr, wg, wb, true)
    end
end
-- Welche Zeile gerade festgehalten wird. Nil heisst: keine, und dann
-- gilt wieder der Zeiger.
local pinnedRow
-- So hoch, wie die Liste braucht: Kopf, Waehler, sieben Zeilen, Fuss.
-- Wo die erste Zeile anfaengt: unter Titel und Waehler.
local TP_TOP = 62
local TP_HEIGHT = TP_TOP + 7 * (38 + 2) + 46

---Blizzards Talentfenster, wie es in dieser Fassung heisst.
---
---Seit 11.0 heisst es PlayerSpellsFrame, davor ClassTalentFrame. Beide
---werden nachgeladen, also gibt es sie beim Start noch gar nicht.
---@return table|nil
local function talentFrame()
    return _G.PlayerSpellsFrame or _G.ClassTalentFrame
end

---Die Builds, die wir gerade empfehlen.
---@return table[] rows
local function talentPanelRows()
    -- ERST DIE DATEN, DANN DIE FRAGE.
    --
    -- Beide Datenaddons werden bei Bedarf geladen, und "bei Bedarf"
    -- hiess bisher: wenn jemand das grosse Fenster oeffnet. Wer nach
    -- einem /reload direkt ins Talentfenster geht, hatte keines von
    -- beiden - und das Panel sagte "nichts gemessen", obwohl alles da
    -- war.
    if not (ns.Data and ns.Data.Ensure and ns.Data.Ensure()) then return {} end
    local specID = ns.Profile.SelectedSpec()
    -- Derselbe Schluessel wie die Talentseite im grossen Fenster: wer
    -- dort einen Dungeon gewaehlt hat, meint ihn hier auch.
    if ns.Profile.Dungeon("talents") and ns.Data.EnsureDungeons then
        ns.Data.EnsureDungeons()
    end
    local mode = ns.Profile.LookupMode("talents")
    if not specID or not mode then return {} end
    local hero = ns.Profile.HeroTree()
    -- Woher die Builds stammen - dasselbe Etikett, das auf dem Waehler
    -- steht, und spaeter der Name der angelegten Talentbelegung.
    local modeLabel
    for _, entry in ipairs(ns.MODES or {}) do
        if entry.key == ns.Profile.Mode() then modeLabel = entry.label end
    end
    local dungeon = ns.Profile.Dungeon("talents")
    for _, d in ipairs(ns.Recommend.Dungeons(ns.Profile.Mode()) or {}) do
        if d.key == dungeon then modeLabel = unitName(d) end
    end
    local ok, picks, build = pcall(ns.Recommend.Talents, specID, mode,
        ns.Recommend.ALL, hero)
    if not ok or not picks then return {} end

    -- DIE GANZE TALENTLISTE, nicht nur der Unterschied.
    --
    -- Fuer die Vorschau im Baum braucht es die vollstaendige Liste eines
    -- Builds: gruen ist, was du nicht hast, rot, was du hast und er
    -- nicht. In den Daten steht sie beim haeufigsten Build (im Mittel 76
    -- Knoten); eine Alternative ist diese Liste plus ihre Zugaenge,
    -- minus ihre Abgaenge. So traegt jede Zeile ihre eigene,
    -- vollstaendige Liste, und die Vorschau rechnet gegen DEINEN Baum
    -- statt gegen den haeufigsten Build.
    local basis = {}
    for _, node in ipairs((build and build.nodes) or {}) do
        local spell = tonumber(node) or tonumber(node and node.spell)
        if spell then basis[#basis + 1] = spell end
    end

    ---@param added number[]|nil
    ---@param removed number[]|nil
    ---@return number[]
    local function listeMit(added, removed)
        if #basis == 0 then return {} end
        local weg = {}
        for _, spell in ipairs(removed or {}) do weg[spell] = true end
        local liste = {}
        for _, spell in ipairs(basis) do
            if not weg[spell] then liste[#liste + 1] = spell end
        end
        for _, spell in ipairs(added or {}) do liste[#liste + 1] = spell end
        return liste
    end

    local out = {}
    if build and build.text and build.text ~= "" then
        out[#out + 1] = {
            name = L["TALENT_BUILD"]:format(build.pct or 0),
            note = L["TP_NODES"]:format(#(build.nodes or {})),
            text = build.text,
            label = modeLabel,
            spells = listeMit(nil, nil),
        }
    end
    local okOther, others = pcall(ns.Recommend.OtherBuilds, specID, mode,
        ns.Recommend.ALL, hero)
    for _, other in ipairs((okOther and others) or {}) do
        if other.text and other.text ~= "" then
            -- Ein Alternativbuild sagt, WORIN er abweicht - das ist die
            -- Auskunft, nicht seine blosse Existenz.
            --
            -- Und zwar mit NAMEN: in den Daten stehen Zauber-Nummern,
            -- und "108287, 382197, 462817" ist keine Auskunft, sondern
            -- eine Zumutung.
            local worin = {}
            for _, spell in ipairs(other.added or {}) do
                if #worin >= 2 then break end
                local info = C_Spell and C_Spell.GetSpellInfo
                    and C_Spell.GetSpellInfo(spell)
                worin[#worin + 1] = (info and info.name) or ("#" .. tostring(spell))
            end
            out[#out + 1] = {
                label = (modeLabel or "") .. " " .. (worin[1] or ""),
                name = L["TP_OTHER"]:format(other.pct or 0),
                note = (#worin > 0 and table.concat(worin, ", ")
                    or L["TP_NODES"]:format(other.count or 0)),
                text = other.text,
                -- Fuer den Zeiger: welches Talent gegen welches.
                added = other.added, removed = other.removed,
                -- Und fuer die Vorschau im Baum die ganze Liste.
                spells = listeMit(other.added, other.removed),
            }
        end
    end
    return out
end

---Aktivitaet, Dungeon und Boss fuer das Panel waehlen.
---
---DIESELBE GLIEDERUNG WIE IM FENSTER: M+, Raid, PvP als Gruppen,
---darunter die Stichproben, und darunter - wo es sie gibt - die
---Dungeons und Bosse. Flach untereinander waeren das zwanzig Zeilen,
---die sich wie eine Aufzaehlung lesen statt wie eine Auswahl.
local function openTalentModePicker(anchor)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    local byKey = {}
    for _, mode in ipairs(ns.MODES or {}) do byKey[mode.key] = mode end

    -- Was keine Talente hat, steht nicht zur Wahl.
    local function has(mode)
        return mode and ns.Recommend.HasMode(mode.key)
            and ns.Recommend.HasSection(ns.Profile.SelectedSpec(), mode.key,
                ns.Recommend.ALL, "talents")
    end

    local function waehle(modeKey, dungeonKey)
        -- ERST LADEN, DANN WAEHLEN.
        --
        -- Die Daten je Dungeon stehen in einem eigenen Addon, das erst
        -- bei Bedarf geladen wird. Ohne diesen Aufruf stand im Panel
        -- "nichts gemessen", obwohl das Fenster daneben die Builds
        -- zeigte - es hatte sie geladen, wir nicht.
        if dungeonKey and not ns.Data.EnsureDungeons() then
            ns.Print(L["NO_DUNGEON_DATA"])
            return
        end
        ns.Profile.SetMode(modeKey)
        ns.Profile.SetDungeon(dungeonKey, "talents")
        UI.RefreshTalentPanel()
        if frame and frame:IsShown() then UI.Refresh() end
    end

    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(L["LBL_ACTIVITY"])
        for _, group in ipairs(ns.MODE_GROUPS or {}) do
            local any = false
            for _, key in ipairs(group.keys) do
                if has(byKey[key]) then any = true end
            end
            local sub = any and root:CreateButton(group.label) or nil
            for _, key in ipairs(group.keys) do
                local mode = byKey[key]
                if sub and has(mode) then
                    local einzeln = ns.Recommend.Dungeons and ns.Recommend.Dungeons(mode.key)
                    if einzeln and #einzeln > 0 then
                        -- Eine Stichprobe MIT Einzelauswahl bekommt ein
                        -- weiteres Untermenue: oben sie selbst, darunter
                        -- ihre Dungeons oder Bosse.
                        local tief = sub:CreateButton(mode.label)
                        local allKey = unitLabels(mode.key)
                        tief:CreateRadio(L[allKey], function()
                            return ns.Profile.Mode() == mode.key
                                and not ns.Profile.Dungeon("talents")
                        end, function() waehle(mode.key, nil) end)
                        -- Bosse gehoeren unter ihren Schlachtzug: zwei
                        -- Raids nebeneinander, neun Bosse flach - das
                        -- waere eine Liste zum Raten.
                        local gruppen, reihe = {}, {}
                        for _, entry in ipairs(einzeln) do
                            local g = entry.group and unitGroup(entry) or false
                            if not gruppen[g] then gruppen[g] = {}; reihe[#reihe + 1] = g end
                            table.insert(gruppen[g], entry)
                        end
                        for _, g in ipairs(reihe) do
                            local ziel = tief
                            if g then ziel = tief:CreateButton(g) end
                            for _, entry in ipairs(gruppen[g]) do
                                ziel:CreateRadio(unitName(entry), function()
                                    return ns.Profile.Dungeon("talents") == entry.key
                                end, function() waehle(mode.key, entry.key) end)
                            end
                        end
                    else
                        sub:CreateRadio(mode.label, function()
                            return ns.Profile.Mode() == mode.key
                                and not ns.Profile.Dungeon("talents")
                        end, function() waehle(mode.key, nil) end)
                    end
                end
            end
        end
    end)
end
local function buildTalentPanel()
    if talentPanel then return talentPanel end
    local p = CreateFrame("Frame", "MetaCodexTalentList", UIParent)
    p:SetWidth(TP_WIDTH)
    -- Ueber den Rahmen der Vorschau, die auf HIGH liegen: was hinter
    -- dieser Liste steckt, soll nicht durch sie hindurchleuchten.
    p:SetFrameStrata("DIALOG")
    S:Fill(p, "bgBase")
    S:Border(p, "borderSubtle")
    p:Hide()
    talentPanel = p

    p.title = S:Text(p, "title", "textPrimary")
    p.title:SetPoint("TOPLEFT", S.space.md, -S.space.md)
    p.title:SetText(L["TP_TITLE"])

    -- ZIEHBAR, und die Lage wird gemerkt.
    --
    -- Von selbst stellt sich die Liste neben das Talentfenster. Ist das
    -- aber fast so breit wie der Bildschirm - und bei manchem ist es
    -- das -, bleibt aussen kein Platz, und dann deckt sie etwas zu, egal
    -- wohin wir sie stellen. Welche Stelle am wenigsten stoert, sieht
    -- nur der, der davorsitzt.
    p:SetMovable(true)
    p:EnableMouse(true)
    p:RegisterForDrag("LeftButton")
    p:SetScript("OnDragStart", function(self) self:StartMoving() end)
    p:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local ziel = talentFrame()
        if not ziel then return end
        -- Gemerkt wird der Abstand zur Ecke des Talentfensters, nicht
        -- die Bildschirmkoordinate: das Fenster steht nicht immer
        -- gleich, und die Liste soll mitwandern.
        local dx = (tonumber(self:GetLeft()) or 0) - (tonumber(ziel:GetLeft()) or 0)
        local dy = (tonumber(self:GetBottom()) or 0) - (tonumber(ziel:GetBottom()) or 0)
        ns.Profile.SetTalentPanelPos(dx, dy)
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", ziel, "BOTTOMLEFT", dx, dy)
    end)

    -- KEINE ZEILE "GEMESSEN FUER".
    --
    -- Darunter stand ein Knopf, auf dem die Aktivitaet steht. Die
    -- Ueberschrift dazu sagte nichts, was der Knopf nicht selbst sagt -
    -- und kostete die Zeile, die das Panel schmaler haette machen
    -- koennen.

    p.close = makeButton(p, 20, 20, "X", function() p:Hide() end)
    p.close:SetPoint("TOPRIGHT", -S.space.sm, -S.space.sm)

    -- DIE AKTIVITAET GEHOERT HIERHER, nicht nur ins grosse Fenster.
    --
    -- Je Dungeon ein anderer Build - das ist der ganze Grund, warum
    -- dieses Panel neben dem Talentfenster steht. Wer dafuer erst in
    -- unser Fenster wechseln muesste, koennte auch gleich dort den
    -- String kopieren.
    p.pick = makeButton(p, TP_WIDTH - S.space.md * 2, 22, "", function(self)
        openTalentModePicker(self)
    end)
    p.pick:SetPoint("TOPLEFT", S.space.md, -S.space.md - 22)

    p.rows = {}
    for i = 1, TP_ROWS do
        local r = CreateFrame("Button", nil, p)
        r:SetHeight(TP_ROW_H)
        r:SetPoint("TOPLEFT", S.space.sm, -TP_TOP - (i - 1) * (TP_ROW_H + 2))
        r:SetPoint("TOPRIGHT", -S.space.sm, -TP_TOP - (i - 1) * (TP_ROW_H + 2))
        r.bg = S:Fill(r, "bgOverlay", 0)
        r.name = S:Text(r, "body", "textPrimary")
        r.name:SetPoint("TOPLEFT", S.space.sm, -4)
        r.name:SetPoint("RIGHT", -S.space.sm - TP_PIN, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.note = S:Text(r, "caption", "textSecondary")
        r.note:SetPoint("TOPLEFT", S.space.sm, -20)
        r.note:SetPoint("RIGHT", -S.space.sm - TP_PIN, 0)
        r.note:SetJustifyH("LEFT")
        r.note:SetWordWrap(false)

        -- FESTHALTEN, damit man im Baum nachsehen kann.
        --
        -- Die Vorschau hing am Zeiger: man sah die Rahmen nur, solange
        -- die Maus auf der Zeile stand - und genau dann konnte man nicht
        -- hinauffahren und ein markiertes Talent anschauen. Was Blizzard
        -- selbst ueber ein Talent sagt, steht an seinem Symbol; dorthin
        -- muss man kommen duerfen.
        r.pin = CreateFrame("Button", nil, r)
        r.pin:SetSize(TP_PIN, TP_PIN)
        r.pin:SetPoint("RIGHT", -S.space.sm, 0)
        r.pin.icon = r.pin:CreateTexture(nil, "ARTWORK")
        r.pin.icon:SetAllPoints()
        r.pin.icon:SetTexture("Interface\\Common\\FavoritesIcon")
        r.pin.icon:SetAlpha(0.3)
        r.pin:SetScript("OnClick", function()
            local zeile = r
            if pinnedRow == zeile then
                pinnedRow = nil
                if ns.Tree then ns.Tree.Hide() end
            else
                pinnedRow = zeile
                if ns.Tree then ns.Tree.Show(rawget(zeile, "spells")) end
            end
            UI.UpdateTalentPins()
        end)
        r.pin:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["TP_PIN"], 1, 1, 1)
            GameTooltip:AddLine(L["TP_PIN_HINT"], 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        r.pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- GEKUERZT HEISST NICHT UNLESBAR.
        --
        -- "Totemische Projektion, Wolfsaffinitaet der Ahnen statt
        -- Kettenheilung" passt in keine Leiste, die neben ein
        -- Talentfenster soll. Dieselbe Regel wie in der Einkaufsliste
        -- und im Fundort-Raster: was abgeschnitten wird, steht im Zeiger
        -- vollstaendig.
        r:SetScript("OnEnter", function(self)
            self.bg:SetAlpha(0.6)
            local voll = self.name:GetText()
            if type(voll) ~= "string" or voll == "" then return end

            -- DER ZEIGER STEHT NEBEN DER LISTE, nicht neben der Zeile.
            --
            -- ANCHOR_RIGHT setzt ihn an die rechte obere Ecke der Zeile
            -- und laesst ihn von dort nach oben wachsen. Bei einem
            -- Zeiger mit vierzehn Zeilen heisst das: er schiesst ueber
            -- die Liste hinaus mitten in den Baum, und man liest zwei
            -- Dinge an zwei weit auseinanderliegenden Stellen.
            --
            -- Fest an die Liste, oben buendig: Knopf, Liste, Zeiger -
            -- drei Sachen nebeneinander, immer an derselben Stelle. Und
            -- wenn rechts kein Platz mehr ist, auf die andere Seite.
            local p = talentPanel
            if p then
                GameTooltip:SetOwner(self, "ANCHOR_NONE")
                GameTooltip:ClearAllPoints()
                local rechts = tonumber(p.GetRight and p:GetRight())
                local schirm = tonumber(UIParent and UIParent.GetRight and UIParent:GetRight())
                if rechts and schirm and (schirm - rechts) < 320 then
                    GameTooltip:SetPoint("TOPRIGHT", p, "TOPLEFT", -S.space.sm, 0)
                else
                    GameTooltip:SetPoint("TOPLEFT", p, "TOPRIGHT", S.space.sm, 0)
                end
            else
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            end
            GameTooltip:SetText(voll, 1, 1, 1, 1, true)
            local note = self.note:GetText()
            if type(note) == "string" and note ~= "" then
                GameTooltip:AddLine(note, 0.7, 0.7, 0.7, true)
            end
            -- KEINE LISTE "NIMMT / STATT" MEHR.
            --
            -- Sie stand hier mit Namen, Symbolen und Beschreibungen -
            -- und sagte damit dasselbe wie der Baum daneben, nur
            -- schlechter: im Baum steht an jedem Talent Blizzards
            -- eigenes Tooltip, vollstaendig, mit Rangstufen. Zwei
            -- Auskuenfte zur selben Frage, von denen eine die bessere
            -- ist, sind eine zu viel. Im grossen Fenster bleibt sie: da
            -- gibt es keinen Baum, in den man schauen koennte.

            -- DIE VORSCHAU IM BAUM, waehrend der Zeiger hier steht.
            --
            -- Sie ist das eigentliche Mittel: zwei Namen in einer Zeile
            -- sagen nicht, wo man hinklicken muss. Nur beim Hovern, und
            -- sie aendert nichts - wer die Maus wegnimmt, hat denselben
            -- Baum wie vorher.
            if ns.Tree then
                local plus, minus, fehlt = ns.Tree.Show(rawget(self, "spells"))
                if plus + minus > 0 then
                    local mr, mg, mb = S:Color("textMuted")
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L["TREE_PREVIEW"]:format(plus, minus), mr, mg, mb)
                end
                -- WAS KEINEN RAHMEN BEKAM, WIRD BEIM NAMEN GENANNT.
                --
                -- "1 davon ist gerade nicht im Baum gezeichnet" ist
                -- wahr und nutzlos: es sagt weder welches noch warum.
                -- Und der haeufigste Grund ist die wichtigste Auskunft
                -- ueberhaupt - dieser Build spielt einen anderen
                -- Held-Baum als du. Das sieht man dem Baum nicht an,
                -- weil der andere gar nicht gezeichnet wird.
                treeGaps(fehlt)
            end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(self)
            self.bg:SetAlpha(0)
            GameTooltip:Hide()
            -- Was festgehalten ist, bleibt stehen. Sonst waere das
            -- Festhalten sinnlos: man nimmt die Maus ja gerade weg, um
            -- im Baum nachzusehen.
            if not ns.Tree then return end
            if pinnedRow then
                ns.Tree.Show(rawget(pinnedRow, "spells"))
            else
                ns.Tree.Hide()
            end
        end)
        r:SetScript("OnClick", function(self)
            if not self.text then return end
            -- Shift kopiert, wie ueberall im Addon. Ohne Shift wird
            -- geladen - das ist, wozu man hergekommen ist.
            if IsShiftKeyDown and IsShiftKeyDown() then
                UI.ShowLink(self.text)
            else
                UI.LoadBuild(self.text, self.buildName)
            end
        end)
        r:Hide()
        p.rows[i] = r
    end

    p.hint = S:Text(p, "caption", "textMuted")
    p.hint:SetPoint("BOTTOMLEFT", S.space.md, S.space.md)
    p.hint:SetPoint("BOTTOMRIGHT", -S.space.md, S.space.md)
    p.hint:SetWordWrap(true)
    p.hint:SetJustifyH("LEFT")
    p.hint:SetText(L["TP_HINT2"])
    return p
end

---Zeigt an, welche Zeile gerade festgehalten wird.
function UI.UpdateTalentPins()
    if not talentPanel then return end
    for _, r in ipairs(talentPanel.rows or {}) do
        if r.pin then
            local an = (pinnedRow == r)
            r.pin.icon:SetAlpha(an and 1 or 0.3)
            if an then
                local pr, pg, pb = S:Color("gold")
                r.pin.icon:SetVertexColor(pr, pg, pb)
            else
                r.pin.icon:SetVertexColor(1, 1, 1)
            end
        end
    end
end

---Das Panel mit dem aktuellen Stand fuellen.
function UI.RefreshTalentPanel()
    if not talentPanel or not talentPanel:IsShown() then return end
    -- Eine andere Aktivitaet heisst andere Builds: was festgehalten war,
    -- steht jetzt vielleicht gar nicht mehr in der Liste.
    pinnedRow = nil
    if ns.Tree then ns.Tree.Hide() end
    local rows = talentPanelRows()
    -- Woraus die Builds stammen, steht dabei: eine Kette ohne ihre
    -- Aktivitaet ist eine Zahl ohne Frage.
    local label
    for _, entry in ipairs(ns.MODES or {}) do
        if entry.key == ns.Profile.Mode() then label = entry.label end
    end

    -- Auf dem Knopf steht, wonach gerade nachgeschlagen wird: der
    -- Dungeon, wenn einer gewaehlt ist, sonst die Aktivitaet.
    local dungeon = ns.Profile.Dungeon("talents")
    local dLabel
    for _, d in ipairs(ns.Recommend.Dungeons(ns.Profile.Mode()) or {}) do
        if d.key == dungeon then dLabel = unitName(d) end
    end
    talentPanel.pick.label:SetText(dLabel or label or ns.Profile.Mode() or "")
    for i, r in ipairs(talentPanel.rows) do
        local row = rows[i]
        if row then
            r.name:SetText(row.name or "")
            r.note:SetText(row.note or "")
            r.text = row.text
            -- Der Name, unter dem er angelegt wird: woher er stammt,
            -- nicht "Build 1". Wer drei davon hat, muss sie
            -- unterscheiden koennen.
            --
            -- NICHT "label": so heisst im ganzen Addon die Beschriftung
            -- eines Knopfes, und die ist ein FontString. Wer Rahmen
            -- danach durchsucht - der Test tut es -, ruft darauf
            -- GetText auf und findet eine Zeichenkette.
            r.buildName = row.label
            r.swapAdded = row.added
            r.swapRemoved = row.removed
            r.spells = row.spells
            r:Show()
        else
            r:Hide()
        end
    end
    UI.UpdateTalentPins()
    if #rows == 0 then
        talentPanel.hint:SetText(L["TP_EMPTY"])
    else
        talentPanel.hint:SetText(L["TP_HINT2"])
    end
end

-- EIN KNOPF, KEIN AUFSPRINGENDES FENSTER.
--
-- Die erste Fassung dockte die Liste rechts an das Talentfenster an.
-- Das uebersieht man - oder es steht im Weg, je nach Bildschirm. Ein
-- Knopf unten links ist da, wo man ihn sucht, und zeigt die Liste erst
-- auf Klick: wer sie nicht braucht, sieht sie nicht.
local talentButton

local function buildTalentButton(f)
    if talentButton then return talentButton end
    -- An UIParent, nicht am Talentfenster: ein Kind von Blizzards
    -- geschuetzter Oberflaeche ist der erste Schritt zu "Diese Aktion
    -- ist gesperrt". Angedockt wird nur die Lage.
    local b = makeButton(UIParent, 160, 30, "", function()
        if talentPanel and talentPanel:IsShown() then
            talentPanel:Hide()
        else
            UI.ShowTalentPanel()
        end
    end)
    b:SetFrameStrata("HIGH")

    -- DAS ZEICHEN STATT DES NAMENS.
    --
    -- "MetaCodex: Builds" sagt zweimal dasselbe: dass es von uns ist,
    -- sieht man am Zeichen. Uebrig bleibt das Wort, um das es geht -
    -- und der Knopf wird schmal genug, um in jede Ecke zu passen.
    b.logo = b:CreateTexture(nil, "ARTWORK")
    -- Gross genug, um es zu erkennen: bei 16 Pixeln war das Zeichen
    -- nur noch ein Fleck. Der Knopf waechst mit, damit es Luft hat.
    b.logo:SetSize(22, 22)
    b.logo:SetPoint("LEFT", S.space.sm, 0)
    b.logo:SetTexture("Interface\\AddOns\\MetaCodex\\Media\\Textures\\logo")

    -- Eine schmale Kante in der Hausfarbe. Sie macht aus einem grauen
    -- Kasten etwas, das erkennbar zu einem Fenster gehoert.
    b.kante = b:CreateTexture(nil, "OVERLAY")
    b.kante:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.kante:SetVertexColor(S:Color("brand"))
    b.kante:SetWidth(S:Pixel(2))
    b.kante:SetPoint("TOPLEFT")
    b.kante:SetPoint("BOTTOMLEFT")

    -- LINKSBUENDIG NEBEN DEM ZEICHEN, nicht mittig.
    --
    -- Mittig gesetzt landete der Text zwischen zwei Pixeln und sah
    -- unscharf aus - dieselbe halbe Kante wie bei den Zeilen. Und neben
    -- einem Zeichen ist Mitte ohnehin die falsche Achse: das Auge
    -- erwartet den Text dort, wo er anfaengt.
    b.label:ClearAllPoints()
    b.label:SetPoint("LEFT", b.logo, "RIGHT", S.space.sm, 0)
    b.label:SetJustifyH("LEFT")
    b.label:SetText(L["TP_BUTTON"])
    b.label:SetWordWrap(false)

    -- So breit, wie der Text braucht - auf ganze Pixel.
    local breit = tonumber(b.label.GetStringWidth and b.label:GetStringWidth()) or 100
    b:SetWidth(S:Pixel(breit + 22 + S.space.sm * 3))

    -- ZIEHBAR, und die Lage wird gemerkt.
    --
    -- Am Talentfenster sitzen je nach Addon-Sammlung schon andere
    -- Knoepfe; unsere Vorgabe lag genau auf einem davon. Welche Ecke
    -- frei ist, kann nur der Spieler sehen.
    b:SetMovable(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local ziel = talentFrame()
        if not ziel then return end
        -- Gemerkt wird der Abstand zur Ecke des Talentfensters, nicht
        -- die Bildschirmkoordinate: das Fenster steht nicht immer
        -- gleich, und der Knopf soll mitwandern.
        -- tonumber, nicht "or 0": GetLeft kann nil liefern, solange die
        -- Oberflaeche noch nicht gerechnet hat - und in der Attrappe
        -- kommt ein Kindrahmen zurueck, der wahr ist und sich nicht
        -- subtrahieren laesst.
        local bx, by = tonumber(self:GetLeft()), tonumber(self:GetBottom())
        local zx, zy = tonumber(ziel:GetLeft()), tonumber(ziel:GetBottom())
        if not (bx and by and zx and zy) then return end
        local dx, dy = bx - zx, by - zy
        -- UND ER BLEIBT AM FENSTER.
        --
        -- Ziehbar hiess bisher ueberallhin: der Knopf liess sich mitten
        -- auf den Bildschirm schieben, wo er zu nichts mehr gehoert -
        -- und beim naechsten Oeffnen stand er dort wieder, ohne dass
        -- man noch wuesste, warum.
        local breit = (tonumber(ziel:GetWidth()) or 0) - (tonumber(self:GetWidth()) or 0)
        local hoch = (tonumber(ziel:GetHeight()) or 0) - (tonumber(self:GetHeight()) or 0)
        ns.Profile.SetTalentButtonPos(dx, dy, breit, hoch)
        dx, dy = ns.Profile.TalentButtonPos()
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", ziel, "BOTTOMLEFT", dx, dy)
        -- Die Liste haengt am Knopf und zieht mit.
        if talentPanel and talentPanel:IsShown() then UI.ShowTalentPanel() end
    end)
    -- Und ein Wort dazu, denn ein ziehbarer Knopf sieht aus wie jeder
    -- andere.
    b:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(S:Color("bgHover"))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("MetaCodex", 1, 1, 1)
        GameTooltip:AddLine(L["TP_TOOLTIP"], 1, 1, 1)
        GameTooltip:AddLine(L["TP_DRAG"], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(S:Color("bgOverlay"))
        GameTooltip:Hide()
    end)

    talentButton = b
    return b
end

-- Jeder Build, den wir anlegen, traegt dieses Praeposition im Namen.
--
-- NICHT ZUR ZIERDE: daran erkennen wir unsere eigenen wieder. Loeschen
-- duerfen wir nur, was wir selbst angelegt haben - eine fremde
-- Talentbelegung anzufassen waere ein Uebergriff, und zwar einer, den
-- niemand rueckgaengig machen kann.
local TP_PREFIX = "MetaCodex: "

---Einen gleichnamigen Build von uns finden.
---@param name string
---@return number|nil configID
local function ownLoadout(name)
    if not (C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID
        and C_Traits and C_Traits.GetConfigInfo) then return nil end
    local specID = ns.Compat.CurrentSpec and ns.Compat.CurrentSpec()
    if not specID then return nil end
    local ok, ids = pcall(C_ClassTalents.GetConfigIDsBySpecID, specID)
    if not ok or type(ids) ~= "table" then return nil end
    for _, id in ipairs(ids) do
        local gotInfo, info = pcall(C_Traits.GetConfigInfo, id)
        local vorhanden = gotInfo and info and info.name
        -- Nur unsere: der Name muss mit unserem Praefix anfangen UND
        -- genau der gesuchte sein.
        if vorhanden == name and name:sub(1, #TP_PREFIX) == TP_PREFIX then
            return id
        end
    end
    return nil
end

---Einen Build in Blizzards Talentfenster laden.
---
---UEBER BLIZZARDS EIGENEN WEG. PlayerSpellsFrame.TalentsFrame:
---ImportLoadout ist die Methode, die auch ihr Import-Dialog aufruft;
---sie liest die Kette, legt eine Talentbelegung an und waehlt sie aus.
---Wir bauen nichts nach und fassen nichts Geschuetztes an.
---
---UND SIE KANN SCHEITERN. Im Kampf geht es nicht, und eine Fassung,
---die diese Methode nicht hat, gibt es auch. Dann faellt es auf den
---Kopierdialog zurueck - der Weg, der immer geht.
---@param text string  die Importkette
---@param label string  woher der Build stammt, fuer den Namen
function UI.LoadBuild(text, label)
    if type(text) ~= "string" or text == "" then return end
    local name = TP_PREFIX .. (label or "")

    if InCombatLockdown and InCombatLockdown() then
        ns.Print(L["TP_COMBAT"])
        return
    end

    local f = talentFrame()
    local tf = f and f.TalentsFrame
    if not (tf and tf.ImportLoadout) then
        UI.ShowLink(text)
        ns.Print(L["TP_NO_IMPORT"])
        return
    end

    -- Zweimal derselbe Name waeren zwei Eintraege, die gleich heissen.
    -- Unseren alten raeumen wir weg; fremde bleiben unberuehrt.
    local alt = ownLoadout(name)
    if alt and C_ClassTalents.DeleteConfig then
        pcall(C_ClassTalents.DeleteConfig, alt)
    end

    local ok, err = pcall(tf.ImportLoadout, tf, text, name)
    if ok then
        ns.Print(L["TP_LOADED"], name)
    else
        -- Gescheitert heisst nicht ratlos: die Kette gibt es noch.
        UI.ShowLink(text)
        ns.Print(L["TP_IMPORT_FAILED"], tostring(err))
    end
end

---Die Buildliste oeffnen - vom Knopf aus.
function UI.ShowTalentPanel()
    local f = talentFrame()
    if not f then return end
    local p = buildTalentPanel()
    p:ClearAllPoints()
    p:SetHeight(TP_HEIGHT)

    -- WER SIE EINMAL HINGESCHOBEN HAT, HAT ENTSCHIEDEN.
    local gx, gy = ns.Profile.TalentPanelPos()
    if gx and gy then
        p:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", gx, gy)
        p:Show()
        UI.RefreshTalentPanel()
        return
    end

    -- NEBEN DAS FENSTER, NICHT DARAUF.
    --
    -- Ueber dem Knopf wachsend stand die Liste mitten im Talentbaum -
    -- und zwar genau dort, wo die Vorschau ihre Rahmen zeichnet. Man
    -- deckte mit dem Lesen zu, was man sehen wollte.
    --
    -- Also an die AUSSENKANTE, dieselbe Regel wie bei der Einkaufsliste
    -- am Auktionshaus: an die Seite, auf der der Knopf steht, und wenn
    -- dort kein Platz mehr ist, auf die andere. Der Bildschirm gehoert
    -- dem Spieler, nicht uns.
    local links = tonumber(f.GetLeft and f:GetLeft())
    local rechts = tonumber(f.GetRight and f:GetRight())
    local schirm = tonumber(UIParent and UIParent.GetRight and UIParent:GetRight())
    local luft = TP_WIDTH + S.space.md

    local platzLinks = (links or 0) >= luft
    local platzRechts = (schirm and rechts) and (schirm - rechts) >= luft or false

    local nachLinks = false
    if platzLinks or platzRechts then
        -- Auf welcher Seite steht der Knopf? Dort sucht der Blick die
        -- Liste. Aber Platz geht vor Gewohnheit.
        local knopfX = talentButton and tonumber(talentButton.GetLeft and talentButton:GetLeft())
        local mitte = (links and rechts) and (links + rechts) / 2 or nil
        nachLinks = (knopfX and mitte) and (knopfX < mitte) or false
        if nachLinks and not platzLinks then nachLinks = false end
        if not nachLinks and not platzRechts then nachLinks = true end
    end

    if not (platzLinks or platzRechts) then
        -- NIRGENDS PLATZ: ein fast bildschirmbreites Talentfenster laesst
        -- aussen keine 100 Pixel.
        --
        -- Dann NEBEN den Knopf, nicht ueber ihn. Ueber ihm wuchs die
        -- Liste senkrecht in den Baum hinein und deckte die Spalte zu,
        -- vor der man gerade steht. Rechts daneben, auf seiner Hoehe
        -- beginnend, bleibt die Leiste unten frei und die Liste steht
        -- neben dem Baum statt darin - soweit sie reicht. Ganz ohne
        -- Ueberdeckung geht es bei einem Fenster dieser Groesse nicht,
        -- und darum ist sie ziehbar.
        if talentButton then
            p:SetPoint("BOTTOMLEFT", talentButton, "BOTTOMRIGHT", S.space.md, 0)
        else
            p:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
        end
    elseif nachLinks then
        p:SetPoint("TOPRIGHT", f, "TOPLEFT", -S.space.md, 0)
    else
        p:SetPoint("TOPLEFT", f, "TOPRIGHT", S.space.md, 0)
    end
    p:Show()
    UI.RefreshTalentPanel()
end

local function showTalentPanel()
    local f = talentFrame()
    if not f then return end
    -- Nur ueber dem Talentbaum. Steht gerade ein anderer Reiter da,
    -- hat der Knopf dort nichts verloren.
    local tf = f.TalentsFrame
    if tf and tf.IsShown and not tf:IsShown() then
        UI.HideTalentPanel()
        return
    end
    if ns.Profile and ns.Profile.TalentPanel and not ns.Profile.TalentPanel() then
        if talentButton then talentButton:Hide() end
        if talentPanel then talentPanel:Hide() end
        return
    end
    local b = buildTalentButton(f)
    -- Bei jedem Oeffnen neu andocken: wer das Fenster verschiebt, will
    -- den Knopf mitnehmen.
    b:ClearAllPoints()
    local x, y = ns.Profile.TalentButtonPos()
    b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, y)
    b:Show()
end

---Was der Client zum Laden eines Builds anbietet.
---
---Gebaut, bevor wir irgendetwas laden: Blizzards Talentoberflaeche ist
---geschuetzt, und welcher Weg in DIESER Fassung offensteht, sagt nur
---der Client. Was es hier nicht gibt, wird auch nicht aufgerufen.
function UI.TalentAPIs()
    -- IN EIN FENSTER, NICHT IN DEN CHAT.
    --
    -- Dreissig Zeilen Messwerte im Chat liest niemand, und
    -- herauskopieren kann man sie dort schon gar nicht - genau wie beim
    -- Probe-Bericht, der denselben Weg geht.
    local zeilen = {}
    local function zeile(text) zeilen[#zeilen + 1] = text end
    local function sag(name, wert)
        zeile(("%-46s %s"):format(name, wert and "ja" or "nein"))
    end
    sag("PlayerSpellsFrame", _G.PlayerSpellsFrame ~= nil)
    sag("ClassTalentFrame", _G.ClassTalentFrame ~= nil)
    local tf = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame
    sag("PlayerSpellsFrame.TalentsFrame", tf ~= nil)
    sag("  :ImportLoadout", tf and tf.ImportLoadout ~= nil)
    sag("  :ShowImportDialog", tf and tf.ShowImportDialog ~= nil)
    sag("  :LoadConfigInternal", tf and tf.LoadConfigInternal ~= nil)
    sag("  :SetSelectedSavedConfigID", tf and tf.SetSelectedSavedConfigID ~= nil)
    sag("ClassTalentLoadoutImportDialog", _G.ClassTalentLoadoutImportDialog ~= nil)
    sag("C_ClassTalents", C_ClassTalents ~= nil)
    sag("  .ImportLoadout", C_ClassTalents and C_ClassTalents.ImportLoadout ~= nil)
    sag("  .LoadConfig", C_ClassTalents and C_ClassTalents.LoadConfig ~= nil)
    sag("  .SaveConfig", C_ClassTalents and C_ClassTalents.SaveConfig ~= nil)
    sag("  .GetConfigIDsBySpecID", C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID ~= nil)
    sag("C_Traits.GenerateImportString", C_Traits and C_Traits.GenerateImportString ~= nil)
    sag("C_Traits.GetConfigInfo", C_Traits and C_Traits.GetConfigInfo ~= nil)

    -- WAS DER BAUM SELBST HERGIBT.
    --
    -- Fuer eine Vorschau IM Baum - gruen, was dazukaeme, rot, was
    -- wegfiele - brauchen wir zweierlei: die Uebersetzung von einer
    -- Zauber-Nummer auf einen Knoten, und den Rahmen, der diesen Knoten
    -- zeichnet. Beides kann nur der Client beantworten, und beides
    -- aendert sich mit jeder Fassung. Also wird es hier nicht
    -- aufgezaehlt, sondern einmal gegangen.
    zeile(" ")
    local tab = tf
    sag("  :GetTalentButtonByNodeID", tab and tab.GetTalentButtonByNodeID ~= nil)
    sag("  :EnumerateAllTalentButtons", tab and tab.EnumerateAllTalentButtons ~= nil)
    sag("  .nodeIDToButton", tab and rawget(tab, "nodeIDToButton") ~= nil)
    sag("C_Traits.GetTreeNodes", C_Traits and C_Traits.GetTreeNodes ~= nil)
    sag("C_Traits.GetNodeInfo", C_Traits and C_Traits.GetNodeInfo ~= nil)
    sag("C_Traits.GetEntryInfo", C_Traits and C_Traits.GetEntryInfo ~= nil)
    sag("C_Traits.GetDefinitionInfo", C_Traits and C_Traits.GetDefinitionInfo ~= nil)

    local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID
        and C_ClassTalents.GetActiveConfigID()
    zeile(("%-46s %s"):format("aktive Konfiguration", tostring(configID)))

    if configID and C_Traits and C_Traits.GetConfigInfo then
        local info = C_Traits.GetConfigInfo(configID)
        local baeume = info and info.treeIDs or {}
        zeile(("%-46s %d"):format("Baeume", #baeume))

        -- WELCHE SIGNATUR, DAS SAGT DER CLIENT.
        --
        -- Der erste Versuch rief GetTreeNodes(configID, treeID) auf und
        -- bekam null Knoten zurueck - kein Fehler, nur eine leere
        -- Liste, und eine leere Liste sieht aus wie "gibt es nicht".
        -- Also werden beide Formen probiert und BEIDE Zahlen gemeldet;
        -- welche von beiden stimmt, ist dann keine Meinung mehr.
        local treeID = baeume[1]
        if treeID and C_Traits.GetTreeNodes then
            local okA, a = pcall(C_Traits.GetTreeNodes, configID, treeID)
            local okB, b = pcall(C_Traits.GetTreeNodes, treeID)
            zeile(("%-46s %d"):format("GetTreeNodes(configID, treeID)",
                (okA and type(a) == "table") and #a or -1))
            zeile(("%-46s %d"):format("GetTreeNodes(treeID)",
                (okB and type(b) == "table") and #b or -1))
        end

        -- Und der Weg ueber die Rahmen, die der Baum schon gebaut hat.
        -- Er braucht gar keine Knotenliste: wer einen Rahmen hat, hat
        -- auch dessen Knoten.
        if tab and tab.EnumerateAllTalentButtons then
            local n, beispiel = 0, nil
            local ok = pcall(function()
                for b in tab:EnumerateAllTalentButtons() do
                    n = n + 1
                    if not beispiel then
                        local nodeID = b.GetNodeID and b:GetNodeID() or rawget(b, "nodeID")
                        beispiel = tonumber(nodeID)
                    end
                end
            end)
            zeile(("%-46s %s"):format("EnumerateAllTalentButtons",
                ok and (n .. " Rahmen") or "stolpert"))
            zeile(("%-46s %s"):format("  erster Knoten daraus", tostring(beispiel)))
        end

        -- Einmal die ganze Kette: Baum -> Knoten -> Eintrag ->
        -- Definition -> Zauber. Gezaehlt wird, wie viele Zauber dabei
        -- herauskommen, wie viele davon einen Rahmen im Baum haben und
        -- wie viele gerade geskillt sind - das letzte, weil die Vorschau
        -- gegen den eigenen Baum rechnen soll, nicht gegen einen leeren.
        -- Die Form, die etwas liefert, gewinnt.
        local function knotenVon(tree)
            local ok, list = pcall(C_Traits.GetTreeNodes, configID, tree)
            if ok and type(list) == "table" and #list > 0 then return list end
            ok, list = pcall(C_Traits.GetTreeNodes, tree)
            if ok and type(list) == "table" and #list > 0 then return list end
            return {}
        end

        local knoten, zauber, rahmen, geskillt, erster = 0, 0, 0, 0, nil
        for _, treeID in ipairs(baeume) do
            for _, nodeID in ipairs(knotenVon(treeID)) do
                knoten = knoten + 1
                local node = C_Traits.GetNodeInfo(configID, nodeID)
                if node and (tonumber(node.ranksPurchased) or 0) > 0 then
                    geskillt = geskillt + 1
                end
                for _, entryID in ipairs((node and node.entryIDs) or {}) do
                    local entry = C_Traits.GetEntryInfo(configID, entryID)
                    local def = entry and entry.definitionID
                        and C_Traits.GetDefinitionInfo(entry.definitionID)
                    if def and def.spellID then
                        zauber = zauber + 1
                        if not erster then
                            erster = { nodeID = nodeID, spellID = def.spellID }
                        end
                    end
                end
                if tab and tab.GetTalentButtonByNodeID then
                    local ok, b = pcall(tab.GetTalentButtonByNodeID, tab, nodeID)
                    if ok and b then rahmen = rahmen + 1 end
                end
            end
        end
        zeile(("%-46s %d"):format("Knoten gesamt", knoten))
        zeile(("%-46s %d"):format("davon mit Zauber-Nummer", zauber))
        zeile(("%-46s %d"):format("davon mit sichtbarem Rahmen", rahmen))
        zeile(("%-46s %d"):format("davon gerade geskillt", geskillt))
        if erster then
            zeile(("%-46s Knoten %d = Zauber %d"):format("Beispiel",
                erster.nodeID, erster.spellID))
        end

        -- DER HELD-BAUM.
        --
        -- Er ist kein eigener Baum, sondern ein Unterbaum im selben:
        -- seine Knoten tragen eine subTreeID. Und es gibt mehrere je
        -- Spec, von denen nur einer gewaehlt ist - was die Luecke
        -- zwischen 282 Knoten und 121 Rahmen zum Teil erklaert. Ob die
        -- Knoten des GEWAEHLTEN einen Rahmen haben, ist die Frage, und
        -- sie wird hier gestellt statt beantwortet.
        zeile(" ")
        sag("C_Traits.GetSubTreeInfo", C_Traits.GetSubTreeInfo ~= nil)
        sag("  .HeroTalentsContainer", tab and rawget(tab, "HeroTalentsContainer") ~= nil)

        local imUnter, mitRahmen, aktiv, aktivRahmen, aktivGeskillt = 0, 0, {}, 0, 0
        for _, treeID in ipairs(baeume) do
            for _, nodeID in ipairs(knotenVon(treeID)) do
                local ok2, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                node = ok2 and node or nil
                local sub = node and tonumber(node.subTreeID)
                if sub then
                    imUnter = imUnter + 1
                    local hatRahmen = false
                    if tab and tab.GetTalentButtonByNodeID then
                        local okB, b = pcall(tab.GetTalentButtonByNodeID, tab, nodeID)
                        hatRahmen = okB and b ~= nil
                    end
                    if hatRahmen then mitRahmen = mitRahmen + 1 end
                    -- Welcher Unterbaum gerade gilt, sagt der Client.
                    local istAktiv = false
                    if C_Traits.GetSubTreeInfo then
                        local okS, sInfo = pcall(C_Traits.GetSubTreeInfo, configID, sub)
                        istAktiv = okS and sInfo and sInfo.isActive or false
                        if okS and sInfo then aktiv[sub] = sInfo.name or tostring(sub) end
                    end
                    if istAktiv then
                        if hatRahmen then aktivRahmen = aktivRahmen + 1 end
                        if (tonumber(node.ranksPurchased) or 0) > 0 then
                            aktivGeskillt = aktivGeskillt + 1
                        end
                    end
                end
            end
        end
        zeile(("%-46s %d"):format("Knoten im Held-Baum", imUnter))
        zeile(("%-46s %d"):format("  davon mit Rahmen", mitRahmen))
        zeile(("%-46s %d"):format("  im GEWAEHLTEN mit Rahmen", aktivRahmen))
        zeile(("%-46s %d"):format("  im GEWAEHLTEN geskillt", aktivGeskillt))
        local namen = {}
        for id, name in pairs(aktiv) do namen[#namen + 1] = name .. " (" .. id .. ")" end
        zeile(("%-46s %s"):format("Held-Baeume", table.concat(namen, ", ")))
    end

    -- UND DIE ENTSCHEIDENDE ZAHL: was von einem echten Build ankommt.
    --
    -- Alles davor sind Eigenschaften des Baumes. Was der Spieler sieht,
    -- haengt daran, wie viele Talente UNSERER Empfehlung einen Rahmen
    -- bekommen - und das misst nur dieser Durchlauf.
    zeile(" ")
    local reihen = talentPanelRows()
    local erste = reihen[1]
    zeile(("%-46s %d"):format("Builds in der Liste", #reihen))
    zeile(("%-46s %d"):format("Talente im ersten Build",
        #((erste and erste.spells) or {})))
    if erste and erste.spells and ns.Tree then
        local plus, minus, fehlt = ns.Tree.Show(erste.spells)
        ns.Tree.Hide()
        zeile(("%-46s %d"):format("  gruen gezeigt", plus))
        zeile(("%-46s %d"):format("  rot gezeigt", minus))
        zeile(("%-46s %d"):format("  ohne Rahmen geblieben", #fehlt))
        local map = ns.Tree.Map() or {}
        local ohneKnoten, ueberNamen = 0, 0
        for _, spell in ipairs(erste.spells) do
            if not ns.Tree.NodeFor(spell) then
                ohneKnoten = ohneKnoten + 1
            elseif not map[spell] then
                -- Gefunden, aber nicht ueber die Nummer: dasselbe Talent
                -- traegt im Baum eine andere. Wie oft das vorkommt,
                -- gehoert gemessen - danach richtet sich, wie sehr diese
                -- Bruecke traegt.
                ueberNamen = ueberNamen + 1
            end
        end
        zeile(("%-46s %d"):format("  davon ohne Knoten ueberhaupt", ohneKnoten))
        zeile(("%-46s %d"):format("  ueber den Namen gefunden", ueberNamen))

        -- WARUM EIN TALENT KEINEN KNOTEN FINDET.
        --
        -- "Schnelligkeit der Ahnen" steht im Baum, unsere Zuordnung
        -- kennt sie nicht. Der Zauber ersetzt laut Tooltip einen
        -- anderen - die Vermutung ist also, dass der Knoten den
        -- ERSETZTEN traegt und die Messdaten den ersetzenden. Statt das
        -- zu glauben, wird hier je fehlendem Zauber ausgegeben, was der
        -- Client ueber ihn sagt und ob irgendein Knoten denselben NAMEN
        -- traegt.
        local nameOf = function(id)
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
            return (info and info.name) or "?"
        end
        local fehlende = {}
        for _, spell in ipairs(erste.spells) do
            if not ns.Tree.NodeFor(spell) and #fehlende < 6 then
                fehlende[#fehlende + 1] = spell
            end
        end
        if #fehlende > 0 then
            zeile(" ")
            zeile("Zauber ohne Knoten, einzeln:")
        end
        for _, spell in ipairs(fehlende) do
            local gesucht = nameOf(spell)
            zeile(("  %d  %s"):format(spell, gesucht))

            local ueber
            if C_Spell and C_Spell.GetOverrideSpell then
                local okU, wert = pcall(C_Spell.GetOverrideSpell, spell)
                if okU then ueber = wert end
            end
            zeile(("    %-38s %s"):format("GetOverrideSpell", tostring(ueber)))

            -- Traegt ein Zauber IM BAUM denselben Namen? Dann ist es
            -- derselbe Knoten unter anderer Nummer.
            local zwilling
            for kandidat in pairs(map) do
                if kandidat ~= spell and nameOf(kandidat) == gesucht then
                    zwilling = kandidat
                    break
                end
            end
            zeile(("    %-38s %s"):format("gleicher Name im Baum", tostring(zwilling)))
            if zwilling then
                zeile(("    %-38s %s"):format("dessen Knoten", tostring(map[zwilling])))
            end
        end
    end

    -- Und alles zusammen zum Kopieren, wie beim Probe-Bericht.
    local ganz = table.concat(zeilen, "\n")
    if UI.ShowText then
        UI.ShowText(ganz)
    else
        for _, z in ipairs(zeilen) do ns.Print(z) end
    end
end

---Knopf und Liste am Talentfenster schliessen.
function UI.HideTalentPanel()
    if talentPanel then talentPanel:Hide() end
    if talentButton then talentButton:Hide() end
    -- Und die Vorschau mit, festgehalten oder nicht. Sonst bleiben
    -- gruene Rahmen auf einem Baum stehen, dessen Liste nicht mehr da
    -- ist.
    pinnedRow = nil
    if ns.Tree then ns.Tree.Hide() end
    UI.UpdateTalentPins()
end

-- Angehaengt wird NUR ueber HookScript.
--
-- Das setzt kein Skript, es haengt sich an das bestehende an - der
-- Unterschied zwischen "danebenstehen" und "hineinfassen".
local talentHooked = false
local function hookTalentFrame()
    if talentHooked then return end
    local f = talentFrame()
    if not f or not f.HookScript then return end
    -- DER KNOPF GEHOERT ZUM TALENTBAUM, NICHT ZUM FENSTER.
    --
    -- Dasselbe Fenster zeigt drei Reiter: Spezialisierung, Talente,
    -- Zauberbuch. Am Fenster angehaengt stand der Knopf ueberall -
    -- auch ueber dem Zauberbuch, wo er nichts zu suchen hat. Der
    -- Talentbaum ist ein eigener Rahmen und wird mit dem Reiter
    -- gezeigt und versteckt.
    local tf = f.TalentsFrame
    if tf and tf.HookScript then
        tf:HookScript("OnShow", showTalentPanel)
        tf:HookScript("OnHide", function() UI.HideTalentPanel() end)
    else
        -- Aeltere Fassungen kennen den Unterrahmen nicht.
        f:HookScript("OnShow", showTalentPanel)
    end
    -- Und mit dem Fenster geht er in jedem Fall zu.
    f:HookScript("OnHide", function() UI.HideTalentPanel() end)
    talentHooked = true
    -- Schon offen? Dann jetzt - aber nur, wenn der Talentbaum steht.
    local offen = (tf and tf.IsShown and tf:IsShown()) or (not tf and f:IsShown())
    if offen then showTalentPanel() end
end

local talentWatch = CreateFrame("Frame")
talentWatch:RegisterEvent("ADDON_LOADED")
talentWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
talentWatch:SetScript("OnEvent", function(_, event, name)
    -- Das Talentfenster wird nachgeladen. Welches Addon es mitbringt,
    -- hat zwischen den Erweiterungen gewechselt, also werden beide
    -- Namen abgewartet - und bei jedem Betreten der Welt noch einmal
    -- nachgesehen, falls es laengst da ist.
    if event == "ADDON_LOADED" and name ~= "Blizzard_PlayerSpells"
        and name ~= "Blizzard_ClassTalentUI" then
        return
    end
    hookTalentFrame()
end)
