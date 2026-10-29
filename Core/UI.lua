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
-- MINDESTENS SO BREIT WIE DER LAENGSTE EINTRAG (20. Oktober).
--
-- Die Schrift ist STANDARD_TEXT_FONT, und die tauschen UI-Addons wie ElvUI
-- gegen eine eigene. Bei einem Streamer war sie breiter, und "Handwerk &
-- Verzierungen" lief ueber den Rand der Seitenleiste in den Inhalt. Die
-- Breite folgte nur dem Schriftfaktor, nie dem Text. Jetzt misst das
-- Auffrischen die Eintraege (UI.sidebarNeed), und die Leiste waechst mit.
local function sidebarWidth()
    return math.max(math.floor(SIDEBAR * (S.fontScale or 1) + 0.5), UI.sidebarNeed or 0)
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
    folio = true,
    -- Die Gruppen auch: im Altar spielt man anders als in der Arena.
    comps = true }

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
    -- Die Rotation steht neben den Guides: sie beantwortet dieselbe Frage
    -- ("wie spiele ich das?"), nur im Fenster statt auf einer Webseite.
    -- Unter den Talenten stand sie falsch (20. Oktober) - sie ist auf den
    -- Build zugeschnitten, aber selbst keiner.
    { key = "rotation",    group = "GROUP_OVERVIEW" },
    { key = "stats",       group = "GROUP_OVERVIEW" },
    -- Welche Rasse gespielt wird und was sie in der Simulation bringt.
    { key = "races",       group = "GROUP_OVERVIEW" },
    { key = "players",     group = "GROUP_OVERVIEW" },
    -- Mit wem: die Gruppen der Top-Runs. Gehoert zu keiner Spec, darum
    -- am Ende der Uebersicht und nicht bei den Spec-Abschnitten.
    { key = "comps",       group = "GROUP_OVERVIEW" },

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

-- Abschnitte, deren Zahlen an keiner Plattform haengen (26. Oktober): die
-- Rotation kommt aus SimulationCraft und den Logs, die Rassen aus
-- raider.io und bloodmallet zugleich. Dort bringt die Plattformwahl nichts.
local OHNE_QUELLE = { rotation = true, races = true }
---Ob die Plattformwahl in diesem Abschnitt etwas aendert.
function UI.SourceMatters(key) return not OHNE_QUELLE[key] end

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

        -- KEIN "MIT EINKAUFEN FUER" MEHR (24. Oktober): es galt nur fuer die
        -- Einkaufsknoepfe unten im Fenster, und die sind weg - eingekauft
        -- wird am Auktionshaus, mit der Liste daneben.
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
        elseif section.key == "comps" then
            -- Ganze Gruppen, oder eine Rolle.
            key = row.part
            label = key and L["COMP_PART_" .. key]
        elseif section.key == "races" then
            -- Nach Fraktion: wer Horde spielt, waehlt unter der Horde.
            -- "Beide Fraktionen" ist keine Wahl - das waere dasselbe wie
            -- "alle" (19. Oktober). Wer auf beiden Seiten spielbar ist,
            -- steht beim Filtern bei beiden.
            key = row.side ~= "both" and row.side or nil
            label = key and L["RACE_GROUP_" .. key]
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
    if section and section.key == "races" then
        return L["RACE_FACTION"], L["RACE_FACTION_ALL"]
    end
    if section and section.key == "comps" then
        return L["COMP_SHOW"], L["COMP_SHOW_ALL"]
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
    -- Die Schalter AN/AUS stehen unter Einstellungen -> Funktionen, alle
    -- an einer Stelle. Hier bleibt, was die Erinnerung fein einstellt:
    -- auf welchem Weg, ab welcher Schwelle. Ob sie ueberhaupt laeuft,
    -- entscheidet trotzdem weiter mit.
    local on = ns.Profile.RemindersOn()
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

---Die Einstellungen.
---
---ALLE AN/AUS-SCHALTER STEHEN HIER, unter "Funktionen". Frueher stand
---ein Schalter neben dem, was er steuert - und wer gezielt etwas
---abschalten wollte, musste wissen, wo es wohnt: drei im Reiter
---Erinnerung, fuenf hier unter "Wo es aufgeht", obwohl zwei davon den
---Tooltip betrafen. Was eine Funktion FEIN einstellt (Mengen, Wege,
---Schwellen), bleibt neben ihr.
---@return table[] rows
local function settingsRows()
    local rows = {}
    local function switch(label, group, on, apply)
        rows[#rows + 1] = {
            kind = "option", label = label, group = group, on = on,
            choices = boolChoices(), pick = apply,
        }
    end

    -- VIER GRUPPEN statt einer langen Liste "Funktionen" (19. Oktober):
    -- was zusammengehoert, steht zusammen. Die Reihenfolge ist die, in
    -- der man danach sucht - erst, was man sieht, dann, was von selbst
    -- aufgeht.
    local KNOEPFE, TOOLTIP = L["SET_GROUP_BUTTONS"], L["SET_GROUP_TOOLTIP"]
    local BEUTE, ERINNERUNG = L["SET_GROUP_LOOT"], L["SET_GROUP_REMIND"]

    switch(L["SET_MINIMAP"], KNOEPFE, ns.Profile.MinimapOn(), function(value)
        ns.Profile.SetMinimap(value)
        if ns.Minimap then ns.Minimap.Update() end
    end)
    switch(L["SET_CHARBTN"], KNOEPFE, ns.Profile.CharButtonOn(), function(value)
        ns.Profile.SetCharButton(value)
        UI.UpdateCharacterButton()
    end)
    -- Der Knopf am Talentfenster. Er setzt sich ungefragt in fremde
    -- Oberflaeche - an genau die Ecke, an der bei anderen schon
    -- Raider.IO sitzt -, also muss er sich abschalten lassen.
    switch(L["SET_TALENTBTN"], KNOEPFE, ns.Profile.TalentPanel(), function(value)
        ns.Profile.SetTalentPanel(value)
        if not value then UI.HideTalentPanel() end
    end)

    -- Der Tooltip beantwortet zwei Fragen, ohne dass man etwas oeffnet.
    switch(L["SET_TOOLTIP"], TOOLTIP, ns.Profile.TooltipOn(), function(value)
        ns.Profile.SetTooltipOn(value)
    end)
    -- Und die Liste ueber andere Speccs fuer sich. Gefragt auf
    -- CurseForge: wie man "auch getragen von" abschaltet, ohne alles
    -- andere im Tooltip mit abzuschalten.
    switch(L["SET_TOOLTIP_OTHERS"], TOOLTIP, ns.Profile.TooltipOthersOn(), function(value)
        ns.Profile.SetTooltipOthersOn(value)
    end)

    -- Das Fenster, wenn ein Favorit bei jemand anderem droppt.
    switch(L["SET_FAV_ALERT"], BEUTE, ns.Profile.FavDropAlertOn(), function(value)
        ns.Profile.SetFavDropAlertOn(value)
    end)
    -- Nur in der Dev-Version: das Fenster einmal zur Probe, mit dem
    -- Spieler selbst als Empfaenger. Kein Text in den Sprachdateien -
    -- im Paket steht diese Zeile nie.
    if ns.version == "dev" then
        rows[#rows + 1] = {
            kind = "option", label = "DEV: Favorit gedroppt", value = "Testen",
            toggle = function() ns.Wish.Test() end,
            group = BEUTE,
        }
    end

    -- Die Erinnerung, und was an ihr haengt. Das Betreten haengt am
    -- Hauptschalter: ohne ihn steht es aus, auch wenn es fuer sich an
    -- waere.
    local erinnern = ns.Profile.RemindersOn()
    switch(L["REMIND_OPT_ON"], ERINNERUNG, erinnern, function(value)
        ns.Profile.SetReminders(value)
    end)
    switch(L["REMIND_OPT_ENTER"], ERINNERUNG,
        erinnern and ns.Profile.RemindOnEnter(), function(value)
            ns.Profile.SetRemindOnEnter(value)
        end)
    switch(L["REMIND_OPT_AH_PANEL"], ERINNERUNG, ns.Profile.AuctionPanel(), function(value)
        ns.Profile.SetAuctionPanel(value)
        -- Sofort wirksam: wer sie am offenen Auktionshaus abschaltet,
        -- soll nicht erst neu hingehen muessen.
        if not value and ns.UI.HideAuctionPanel then ns.UI.HideAuctionPanel() end
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
    local shown = current == "deDE" and "de" or current == "enUS" and "en"
        or current == "zhCN" and "zh" or "auto"
    rows[#rows + 1] = {
        kind = "option", label = L["SET_LANG"], group = L["SET_GROUP_WINDOW"],
        value = L["SET_LANG_" .. shown:upper()],
        choices = {
            { value = "auto", label = L["SET_LANG_AUTO"] },
            { value = "en", label = L["SET_LANG_EN"] },
            { value = "de", label = L["SET_LANG_DE"] },
            { value = "zh", label = L["SET_LANG_ZH"] },
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
-- Wo eine Reihe fehlt, die verwandten Aktivitaeten - in dieser Folge.
-- Reihe 5 braucht zehn Gemessene je Spec; der Treffsicherheits-Jaeger
-- hatte in den hohen Schluesseln neun, und die Reihe fehlte (20. Oktober).
UI.FOLIO_BORROW = {
    mplus = { "mplus-keys", "raid" },
    ["mplus-keys"] = { "mplus", "raid" },
    raid = { "raid-mythic", "raid-normal", "mplus" },
    ["raid-mythic"] = { "raid", "raid-normal", "mplus" },
    ["raid-normal"] = { "raid", "raid-mythic", "mplus" },
}

function UI.FolioRows(specID, mode, source)
    local eigene, from = ns.Recommend.Folio(specID, mode, source)
    if not eigene then return {}, nil end

    -- JEDE REIHE, notfalls aus der verwandten Aktivitaet. Die Zahl bleibt
    -- gemessen - nur woanders, und der Kopf der Reihe sagt wo.
    local byRow = {}
    for _, row in ipairs(eigene) do byRow[row.row or 0] = row end
    local basis = ns.Recommend.BaseMode and ns.Recommend.BaseMode(mode) or mode
    basis = tostring(basis):match("^([^/]+)") or basis
    for r = 1, 5 do
        if not byRow[r] then
            for _, anders in ipairs(UI.FOLIO_BORROW[basis] or {}) do
                local fremd = ns.Recommend.Folio(specID, anders, ns.Recommend.ALL)
                for _, row in ipairs(fremd or {}) do
                    if row.row == r and not byRow[r] then
                        local kopie = {}
                        for k, v in pairs(row) do kopie[k] = v end
                        kopie.borrowed = anders
                        byRow[r] = kopie
                    end
                end
                if byRow[r] then break end
            end
        end
    end
    local rows = {}
    for r = 1, 5 do if byRow[r] then rows[#rows + 1] = byRow[r] end end

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
        local group = row.borrowed
            and L["FOLIO_ROW_FROM"]:format(row.row or 0, ns.ModeLabel(row.borrowed) or row.borrowed, row.seen or 0)
            or L["FOLIO_ROW"]:format(row.row or 0, row.seen or 0)
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

---Wo die Stuecke fallen, als Raster - wie Keystone Loot.
---
---Jeder Dungeon und jeder Boss mit ALLEN Drops fuer die Spec, und ganz
---unten, was in keiner Instanz faellt. Umgebaut am 15. Oktober:
---vorher standen hier nur die gemessenen Stuecke, verglichen mit dem
---Angelegten.
---
---Oben stand kurz "Wo du hinwillst" mit den Favoriten je Instanz. Das
---wiederholte, was der goldene Ring schon zeigt, und die Hervorhebung
---"Favoriten" blendet alles andere ab - gestrichen am selben Tag. Wo
---die meisten fallen, sagt die Hinweiszeile.
---@return table[] rows
---@return string|nil fromSource
UI.DROP_PLACES = { "dungeon", "raid", "craft", "set", "pvp", "boe", "world" }

function UI.DropRows(specID, mode, source)
    local rows, _, from = ns.Drops.Build(specID, mode, source)
    if #rows == 0 then return {}, nil end

    -- DIE LEGENDE DER RINGE, ueber der Liste.
    --
    -- Drei Farben am Kaestchen sagen nichts, solange niemand weiss,
    -- welche was heisst. Im Menue standen Farbfelder neben den Haken und
    -- sahen selbst wie Haken aus (15. Oktober).
    local function feld(token)
        local r, g, b = S:Color(token)
        return ("|TInterface\\Buttons\\WHITE8X8:10:10:0:0:8:8:0:8:0:8:%d:%d:%d|t "):format(
            math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
    end
    local out = {
        {
            kind = "note", legend = true,
            text = feld("gold") .. L["DROPS_LEGEND_FAV"] .. "      "
                .. feld("brand") .. L["DROPS_LEGEND_TOP"] .. "      "
                .. feld("highlight") .. L["DROPS_LEGEND_STATS"] .. "      "
                .. "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t " .. L["DROPS_LEGEND_OWNED"],
        },
    }
    for _, row in ipairs(rows) do
        if row.place == "dungeon" then
            row.group = L["DROPS_GROUP_DUNGEON"]
        elseif row.place == "raid" then
            row.group = ns.Compat.InstanceName(row.inst) or L["DROPS_PLACE_raid"]
        else
            row.group = L["DROPS_GROUP_ELSEWHERE"]
        end
        out[#out + 1] = row
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
        -- Im laufenden Schluessel kommt der Wert von vorhin (gemerkt = true).
        local mine, gemerkt
        if own then mine, gemerkt = ns.Compat.OwnRating(key) end
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
            memo = gemerkt or nil,
            -- Was ein weiterer Punkt dort noch bringt. Unter 1 nur
            -- hinter einem Knick der Diminishing Returns.
            eff = mine and ns.Compat.RatingEfficiency(key, mine) or nil,
            -- Bis wohin die eigene Bahn gruen bleibt.
            knee = mine and ns.Compat.RatingFirstKnee(key) or nil,
            -- Der Massstab ist fuer alle Zeilen derselbe, sonst
            -- vergleichen die Balken nichts miteinander.
            scale = widest,
            players = stats.players,
        }
    end

    -- DIE ERKLAERUNG DES ABSCHLAGS - NUR, WENN OBEN EINER STEHT.
    --
    -- "nur 90 % je Punkt" allein verstand nicht jeder (14. Oktober).
    -- Darunter in Worten: was gemeint ist, ab welcher Wertung es
    -- anfing, und was 100 Punkte mehr dort noch wert sind. Alles vom
    -- Client; ohne Abschlag kein Wort davon.
    --
    -- Erst standen hier fuenf graue Notizzeilen; eine Karte mit
    -- Tabelle liest sich auf einen Blick (gleicher Tag, im Spiel
    -- angesehen).
    local zeilen = {}
    for _, row in ipairs(rows) do
        local anteil = row.eff and math.floor(row.eff * 100 + 0.5)
        local ab = anteil and anteil < 100 and ns.Compat.RatingKnee(row.statKey, row.mine)
        local wert = ab and ns.Compat.RatingWorth(row.statKey, row.mine, 100)
        if wert then
            zeilen[#zeilen + 1] = { key = row.statKey, from = ab, pct = anteil,
                worth = math.floor(wert + 0.5) }
        end
    end
    if #zeilen > 0 then rows[#rows + 1] = { kind = "drcard", lines = zeilen } end
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

-- DIE KARTE "ABNEHMENDER ERTRAG".
--
-- Eine Flaeche mit rotem Streifen links, Titel, ein Satz, eine
-- kleine Tabelle und ein Fuss. Je Zeile gebaut, wenn sie gebraucht
-- wird, und wie alle Karten in resetRow versteckt.
local drCard = { of = setmetatable({}, { __mode = "k" }), MAX = 4 }

function drCard.build(row)
    if drCard.of[row] then return drCard.of[row] end
    local f = CreateFrame("Frame", nil, row)
    S:Fill(f, "bgRaised")
    S:Border(f, "borderSubtle")
    f.stripe = f:CreateTexture(nil, "ARTWORK")
    f.stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.stripe:SetVertexColor(S:Color("danger"))
    f.stripe:SetPoint("TOPLEFT")
    f.stripe:SetPoint("BOTTOMLEFT")
    f.stripe:SetWidth(S:Pixel(3))
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    f.icon:SetSize(20, 20)
    f.title = S:Text(f, "title", "textPrimary")
    f.sub = S:Text(f, "caption", "textSecondary")
    f.sub:SetWordWrap(true)
    f.rule = f:CreateTexture(nil, "ARTWORK")
    f.rule:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.rule:SetVertexColor(S:Color("borderSubtle"))
    f.rule:SetHeight(S:Pixel(1))
    f.head, f.cells = {}, {}
    for c = 1, 4 do f.head[c] = S:Text(f, "caption", "textMuted") end
    for i = 1, drCard.MAX do
        local zeile = {
            name = S:Text(f, "body", "textPrimary"),
            from = S:Text(f, "body", "textSecondary"),
            pct = S:Text(f, "body", "danger"),
            worth = S:Text(f, "body", "textPrimary"),
        }
        -- Der Anteil auf einer zarten roten Pille, die mit dem Text
        -- waechst.
        zeile.pill = f:CreateTexture(nil, "BORDER")
        zeile.pill:SetTexture("Interface\\Buttons\\WHITE8X8")
        zeile.pill:SetVertexColor(S:Color("danger", 0.16))
        zeile.pill:SetPoint("TOPLEFT", zeile.pct, "TOPLEFT", -6, 3)
        zeile.pill:SetPoint("BOTTOMRIGHT", zeile.pct, "BOTTOMRIGHT", 6, -3)
        f.cells[i] = zeile
    end
    f.foot = S:Text(f, "caption", "textMuted")
    f.foot:SetWordWrap(true)
    drCard.of[row] = f
    return f
end

---Wie hoch die Karte fuer so viele Zeilen ist, ohne Schriftfaktor.
function drCard.height(n)
    return 104 + math.min(n, drCard.MAX) * 24 + 30
end

function drCard.fill(row, lines)
    local f = drCard.build(row)
    local fs = S.fontScale or 1
    local PAD = S.space.lg
    local w = math.max(200, contentWidth() - S.space.sm * 2)
    local innen = w - PAD * 2
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", S.space.sm, -S.space.sm)
    f:SetPoint("BOTTOMRIGHT", -S.space.sm, S.space.sm)

    f.icon:ClearAllPoints()
    f.icon:SetPoint("TOPLEFT", PAD, -14 * fs)
    f.title:ClearAllPoints()
    f.title:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
    f.title:SetText(L["STAT_DR_HEAD"])
    f.sub:ClearAllPoints()
    f.sub:SetPoint("TOPLEFT", PAD, -42 * fs)
    f.sub:SetWidth(innen)
    f.sub:SetText(L["STAT_DR_WHAT"])

    -- Die Spalten: Wert, Grenze, je Punkt, 100 mehr.
    local spalte = { 0, 0.34, 0.56, 0.76 }
    local kopf = { L["STAT_DR_COL_STAT"], L["STAT_DR_COL_FROM"],
        L["STAT_DR_COL_PCT"], L["STAT_DR_COL_WORTH"] }
    for c = 1, 4 do
        f.head[c]:ClearAllPoints()
        f.head[c]:SetPoint("TOPLEFT", PAD + innen * spalte[c], -72 * fs)
        f.head[c]:SetText(drCard.upper(kopf[c]))
    end
    f.rule:ClearAllPoints()
    f.rule:SetPoint("TOPLEFT", PAD, -88 * fs)
    f.rule:SetWidth(innen)

    local n = math.min(#lines, drCard.MAX)
    for i = 1, drCard.MAX do
        local zeile, d = f.cells[i], lines[i]
        local y = -(96 + (i - 1) * 24) * fs
        local felder = {
            zeile.name, zeile.from, zeile.pct, zeile.worth,
        }
        for c, text in ipairs(felder) do
            text:ClearAllPoints()
            text:SetPoint("TOPLEFT", PAD + innen * spalte[c] + (c == 3 and 6 or 0), y)
            text:SetShown(i <= n)
        end
        zeile.pill:SetShown(i <= n)
        if d and i <= n then
            zeile.name:SetText(L["STAT_SHORT_" .. d.key])
            zeile.from:SetText(L["STAT_DR_FROM"]:format(d.from))
            zeile.pct:SetText(("%d%%"):format(d.pct))
            zeile.worth:SetText(L["STAT_DR_WORTH"]:format(d.worth))
        end
    end
    f.foot:ClearAllPoints()
    f.foot:SetPoint("TOPLEFT", PAD, -(96 + n * 24 + 10) * fs)
    f.foot:SetWidth(innen)
    f.foot:SetText(L["STAT_DR_FOOT"])
    f:Show()
    -- Fuer die Pruefung: die Attrappe gibt auf jedes unbekannte Feld
    -- ein Kind zurueck, darum ein eigener, gesetzter Name.
    row.__drCard = f
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

    -- Was hinter der ersten Grenze liegt, rot ueber dem eigenen
    -- Stand - dort bringt jeder Punkt weniger.
    row.barOver = row:CreateTexture(nil, "OVERLAY", nil, 2)
    row.barOver:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.barOver:SetVertexColor(S:Color("danger"))
    row.barOver:SetHeight(S:Pixel(14))
    row.barOver:Hide()
    -- Und die Grenze selbst als Strich, etwas hoeher als die Bahn.
    row.barKnee = row:CreateTexture(nil, "OVERLAY", nil, 3)
    row.barKnee:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.barKnee:SetVertexColor(S:Color("textPrimary", 0.9))
    row.barKnee:SetSize(S:Pixel(2), S:Pixel(20))
    row.barKnee:Hide()

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
        -- Eine Karte, die man nicht anklickt (Rotation, abnehmender
        -- Ertrag), leuchtet nicht als Ganzes auf. Die Rotationskarte wurde
        -- beim Ueberfahren als ganzer Block heller und blieb danach halb
        -- hell stehen (27. Oktober). Die Buildkarte darf: ein Klick
        -- kopiert ihren String.
        self.bg:SetAlpha(rawget(self, "__karte") and 0 or 1)
        -- Eine Rasse: ihre Faehigkeiten, und woher die Zahlen kommen.
        if rawget(self, "raceTip") then
            UI.RaceTooltip(self, rawget(self, "raceTip"))
            return
        end
        -- Eine Gruppe oder Spec der Top-Runs: wer, wie oft, was sie mitbringt.
        if rawget(self, "compTip") then
            UI.CompTooltip(self, rawget(self, "compTip"))
            return
        end
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
        -- rawget, wie bei swapAdded: im Spiel ist ein nicht gesetztes
        -- Feld nil, im Test gibt die Attrappe ein Kind zurueck - und das
        -- ist wahr. Mit self.spellID nahm dort JEDE Zeile diesen Zweig
        -- und kehrte zurueck, auch die mit einem Gegenstand.
        if rawget(self, "spellID") then
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
        --
        -- Frueher kehrte dieser Zweig gleich hier zurueck. Damit lief
        -- alles, was unter dem Tooltip noch dazugehoert - die Set-Boni
        -- der gezeigten Spec - an den Tier-Zeilen vorbei, und
        -- ausgerechnet dort gehoert es hin.
        if self.fullLink then
            link = self.fullLink
        elseif self.itemID and self.wantBonus then
            link = ns.Compat.LinkWith(self.itemID, self.wantBonus, self.statBonus)
        elseif self.itemID and self.wantLevel then
            link = ns.Compat.LinkAtLevel(self.itemID, self.wantLevel, self.statBonus) or link
        elseif self.itemID and self.statBonus then
            link = ns.Compat.LinkWith(self.itemID, self.statBonus)
        end
        if not link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(link)
        -- ERST ZEIGEN, DANN UMSCHREIBEN.
        --
        -- Blizzards Tooltips bauen sich seit 10.0 aus Daten auf, und
        -- Show() laeuft noch einmal darueber. Vorher gesetzter Text war
        -- danach wieder der alte: im Spiel stand weiter der Bonus der
        -- gespielten Spec, waehrend wir dachten, wir haetten ihn
        -- ersetzt - und weil das Ersetzen Erfolg meldete, fiel auch das
        -- Anhaengen weg. Zwei Fehler, die sich gegenseitig verdeckt
        -- haben.
        GameTooltip:Show()

        -- DIE SET-BONI DER GEZEIGTEN SPEC, nicht der gespielten.
        --
        -- Im Tooltip eines Tier-Teils zeichnet Blizzard die Boni der
        -- Spec, die man GERADE SPIELT. Wer als Elementar den
        -- Wiederherstellungs-Schamanen nachschlaegt, liest also die
        -- falschen Boni zum richtigen Teil.
        --
        -- Ersetzen war der Versuch davor und ist wieder draussen:
        -- Blizzards Tooltips bauen sich aus Daten auf, und was man
        -- hineinschreibt, ist beim naechsten Durchlauf wieder weg. Was
        -- bleibt, ist Anhaengen - und dann muss der Block darueber
        -- erklaert werden, sonst liest man ihn als den richtigen.
        --
        -- Nur wenn beide auseinanderfallen. Stimmen sie ueberein,
        -- steht oben ohnehin das Richtige.
        local gezeigt = ns.Profile.SelectedSpec()
        local itemID = rawget(self, "itemID")
        local eigene = ns.Compat.CurrentSpec()
        if itemID and gezeigt and eigene and gezeigt ~= eigene then
            local boni = ns.Compat.SetBonusSpells(gezeigt, itemID)
            if #boni > 0 then
                local hr, hg, hb = S:Color("heading")
                local mr, mg, mb = S:Color("textMuted")
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(
                    L["SET_BONUS_FOR"]:format(ns.Compat.SpecName(gezeigt) or "?"),
                    hr, hg, hb)
                -- WOZU DER BLOCK DARUEBER GEHOERT.
                --
                -- Er traegt keine Beschriftung, und darum liest man
                -- ihn als die Antwort auf die Frage, die man gerade
                -- gestellt hat. Ein Satz genuegt, um das zu drehen.
                GameTooltip:AddLine(
                    L["SET_BONUS_PLAYED"]:format(ns.Compat.SpecName(eigene) or "?"),
                    mr, mg, mb, true)
                for i, spell in ipairs(boni) do
                    local info = C_Spell and C_Spell.GetSpellInfo
                        and C_Spell.GetSpellInfo(spell)
                    local text
                    if C_Spell and C_Spell.GetSpellDescription then
                        local okD, wert = pcall(C_Spell.GetSpellDescription, spell)
                        if okD and type(wert) == "string" and wert ~= "" then
                            text = wert
                        end
                    end
                    -- WIEVIELE TEILE, das steht im Namen des Zaubers.
                    --
                    -- Er heisst "Shaman Restoration 12.1 Class Set 2pc"
                    -- und taugt darum nicht als Zeile - die Zahl darin
                    -- aber schon, und sie kommt aus dem Client statt aus
                    -- einer Annahme ueber die Reihenfolge.
                    --
                    -- Findet sich keine, entscheidet die Stelle: bei
                    -- GENAU ZWEI Boni sind es zwei und vier Teile, so
                    -- ist ein Klassenset gebaut, und in dieser
                    -- Reihenfolge nennt sie auch das Spiel. Bei einer
                    -- anderen Zahl wird nichts behauptet.
                    local name = info and info.name
                    local teile = type(name) == "string"
                        and tonumber(name:match("(%d+)%s*pc")) or nil
                    if not teile and #boni == 2 then teile = i * 2 end
                    if text then
                        text = text:gsub("%s*\n%s*", " ")
                        GameTooltip:AddLine(
                            teile and L["SET_BONUS_PIECES"]:format(teile, text) or text,
                            S:Color("success"))
                    end
                end
                GameTooltip:Show()
            end
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetAlpha((self.__header or rawget(self, "__karte")) and 0 or 0.5)
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
    if drCard.of[row] then drCard.of[row]:Hide() end
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
    row.raceTip = nil
    row.__karte = nil
    if UI.RotationPanelHide then UI.RotationPanelHide(row) end
    -- Die fuenf Spec-Symbole einer Gruppe: sonst standen sie quer ueber
    -- der naechsten Zeile, die diese Zeile wiederverwendet.
    row.compTip = nil
    for _, tex in ipairs(rawget(row, "compIcons") or {}) do tex:Hide() end
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
    row.barOver:Hide()
    row.barKnee:Hide()
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
-- Die Karte steht weiter oben als diese Funktion und holt sie sich hier.
drCard.upper = upperText

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
    -- EIN RAHMEN, in der Farbe der wichtigsten Markierung.
    --
    -- Es waren drei ineinanderliegende Ringe; bei dieser Groesse
    -- verschwammen sie zu einem unruhigen Doppelrand (15. Oktober).
    -- Was sonst noch zutrifft, zeigt der Streifen am Fuss des Symbols.
    c.rings = {}
    for r = 1, 1 do
        local ring = CreateFrame("Frame", nil, c)
        ring.lines = S:Border(ring, "gold")
        ring:Hide()
        c.rings[r] = ring
    end
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
    -- Der Stern liegt UEBER den Ringen. Die Ringe sind eigene Rahmen und
    -- zeichnen damit ueber allem, was am Kaestchen selbst haengt - der
    -- goldene Rand lief quer durch den Stern (im Spiel gesehen, 15. Oktober).
    -- ERST HIER, nachdem es den Stern gibt: einmal stand dieser Block
    -- davor, c.star war nil, und das Fenster ging nicht mehr auf.
    c.badge = CreateFrame("Frame", nil, c)
    c.badge:SetAllPoints()
    c.badge:SetFrameLevel(c:GetFrameLevel() + 4)
    c.star:SetParent(c.badge)
    c.star:SetDrawLayer("OVERLAY", 7)
    -- Der Haken "hast du schon" gehoert ebenfalls nach oben - und nach
    -- UNTEN RECHTS: oben links stehen die Punkte, oben rechts der Stern.
    -- Auf dem oberen Rahmen tritt er auch nicht mit einem abgeblendeten
    -- Symbol zurueck.
    c.mark:SetParent(c.badge)
    c.mark:SetDrawLayer("OVERLAY", 7)
    c.mark:ClearAllPoints()
    c.mark:SetPoint("BOTTOMRIGHT", c.icon, "BOTTOMRIGHT", 4, -4)
    -- PUNKTE fuer, was ausser dem Rahmen noch zutrifft: oben links, je
    -- weitere Markierung einer, mit dunklem Rand, damit er auf jedem
    -- Symbol steht. Ein Streifen am Fuss des Symbols sah aus wie ein
    -- Fehler im Bild (15. Oktober).
    c.pips = {}
    for s = 1, 2 do
        local rand = c.badge:CreateTexture(nil, "OVERLAY", nil, 5)
        rand:SetTexture("Interface\\Buttons\\WHITE8X8")
        rand:SetVertexColor(0, 0, 0, 0.85)
        rand:SetSize(8, 8)
        rand:Hide()
        local punkt = c.badge:CreateTexture(nil, "OVERLAY", nil, 6)
        punkt:SetTexture("Interface\\Buttons\\WHITE8X8")
        punkt:SetSize(6, 6)
        punkt:SetPoint("CENTER", rand, "CENTER", 0, 0)
        punkt:Hide()
        c.pips[s] = { rand = rand, punkt = punkt }
    end
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
        if self.owned then GameTooltip:AddLine(L["DROPS_OWNED"], 0.4, 0.9, 0.4) end
        -- Was ein Klick tut, steht dort, wo man klickt.
        if self.need then
            GameTooltip:AddLine(L["DROPS_NEED_ON"], S:Color("gold"))
        elseif self.spec then
            GameTooltip:AddLine(L["DROPS_NEED_CLICK"], 0.6, 0.6, 0.6)
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
        -- Shift und Strg wie ueberall; jeder andere Klick ist Need an
        -- oder aus. Ein Menue mit einem einzigen Haken waere ein Umweg.
        local _, link = ns.Compat.ItemInfo(self.itemID)
        if link and IsModifiedClick and IsModifiedClick("CHATLINK") then
            if HandleModifiedItemClick then HandleModifiedItemClick(link) end
            return
        elseif link and IsModifiedClick and IsModifiedClick("DRESSUP") then
            if DressUpLink then DressUpLink(link) end
            return
        end
        if not self.spec then return end
        ns.Profile.ToggleNeed(self.itemID, self.spec)
        UI.Refresh()
        -- Der Zeiger zeigt gleich, was der Klick getan hat.
        if GameTooltip.GetOwner and GameTooltip:GetOwner() == self then
            self:GetScript("OnEnter")(self)
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
    -- Im Schlachtzug steht der Boss vorn - der Schlachtzug steht schon
    -- in der Ueberschrift.
    local boss = data.enc and ns.Compat.EncounterName and ns.Compat.EncounterName(data.enc)
    local name = boss or (data.inst and (ns.Compat.InstanceName(data.inst)
        or ("#" .. tostring(data.inst))))
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
    -- Seit dem Umbau: wie viele Drops, wie viele davon gemessen, wie
    -- viele davon Favoriten.
    local text
    if not data.inst then
        text = L["DROPS_ROW_MEASURED"]:format(data.total or 0)
    else
        text = L["DROPS_ROW_ALL"]:format(data.total or 0, data.measured or 0)
        if (data.need or 0) > 0 then
            text = (data.need == 1 and L["DROPS_NEED_1"] or L["DROPS_NEED_N"]:format(data.need))
                .. "  ·  " .. text
        end
        -- Ohne Journal nur das Gemessene - und das steht dabei.
        if data.partial then text = text .. "  ·  " .. L["DROPS_PARTIAL"] end
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
        -- Seit dem Umbau ohne Rangfolge, also ohne Balken: die
        -- Reihenfolge kommt aus "Wo du hinwillst".
        local anteil = 0
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
    -- Die Werte fuer sich: "Muss alle haben" gilt nur fuer sie.
    -- Meistgetragen und Need sind eigene Markierungen daneben.
    local werte, gewaehlt = {}, 0
    for k, ja in pairs(wunsch) do
        if ja and k ~= "top" and k ~= "fav" then werte[k] = true; gewaehlt = gewaehlt + 1 end
    end
    local irgendwas = gewaehlt > 0 or wunsch.top or wunsch.fav
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
        -- Seit dem Umbau steht alles in voller Farbe: nichts wird mehr
        -- mit dem Angelegten verglichen. Der Anteil steht nur unter dem,
        -- was gemessen ist - DAS ist die Hervorhebung.
        c.icon:SetDesaturated(false)
        c.icon:SetAlpha(1)
        c.mark:SetShown(item.owned and true or false)
        c.star:SetShown(item.need and true or false)
        c.stop:Hide()
        c.share:SetText(item.pct and string.format("%d %%", item.pct) or "")
        S:Recolor(c.share, "textSecondary")
        c.itemID, c.pct, c.enc, c.need, c.spec = item.id, item.pct, item.enc, item.need, item.spec
        c.owned = item.owned
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

        -- PASST ES, PASST ES NICHT, ODER WISSEN WIR ES NICHT?
        --
        -- Drei Antworten, nicht zwei. Kennt der Client das Stueck noch
        -- nicht, kennt er auch seine Werte nicht - dann bleibt das
        -- Kaestchen, wie es ist. Es abzublenden hiesse "hat deine
        -- Werte nicht", und das wuerde der Spieler glauben.
        local passt
        if gewaehlt > 0 then
            passt = ns.Drops.Matches(link and ns.Tooltip.SecondaryStats(link),
                werte, kombi)
        end
        local meist = wunsch.top and item.top
        local gewollt = wunsch.fav and item.need
        -- GOLD STICHT DEN AKZENT.
        --
        -- Ein gemerktes Stueck, das auch noch zur Hervorhebung passt,
        -- traegt den goldenen Rahmen: die eigene Wahl ist die seltenere
        -- Auskunft. Dass es zur Hervorhebung passt, sagt schon, dass es
        -- nicht abgeblendet ist.
        -- Die Ringe: Need immer, die beiden anderen, wenn gewaehlt.
        local farben = {}
        if item.need then farben[#farben + 1] = "gold" end
        if meist then farben[#farben + 1] = "brand" end
        if passt == true then farben[#farben + 1] = "highlight" end
        -- Der Rahmen in der ersten Farbe - die Reihenfolge oben ist die
        -- Rangfolge: Favorit, Meistgetragen, Werte.
        local ring = c.rings[1]
        if farben[1] then
            ring:ClearAllPoints()
            ring:SetAllPoints()
            for _, line in pairs(ring.lines) do line:SetVertexColor(S:Color(farben[1])) end
            ring:Show()
        else
            ring:Hide()
        end
        -- Je weitere Markierung ein Punkt oben links - aber nicht bei
        -- Favoriten: Gold und Stern sagen dort genug (15. Oktober).
        for s, pip in ipairs(c.pips) do
            local farbe = not item.need and farben[s + 1]
            if farbe then
                pip.rand:ClearAllPoints()
                pip.rand:SetPoint("TOPLEFT", c.icon, "TOPLEFT", -2 + (s - 1) * 9, 2)
                pip.punkt:SetVertexColor(S:Color(farbe))
                pip.rand:Show()
                pip.punkt:Show()
            else
                pip.rand:Hide()
                pip.punkt:Hide()
            end
        end
        -- Abgeblendet wird nur, was KEINE gewaehlte Markierung traegt -
        -- und nicht, was wir nicht wissen: kennt der Client die Werte
        -- noch nicht, bleibt das Kaestchen, wie es ist.
        local trifft = passt == true or meist or gewollt
        local unbekannt = gewaehlt > 0 and passt == nil
        if irgendwas and not trifft and not unbekannt then
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
            -- Hinter einem Knick sagt die Zeile, was ein Punkt noch
            -- bringt. Davor schweigt sie: die gemessenen Ziele liegen
            -- fast alle vor dem ersten Knick, und eine Warnung, die
            -- nie zutrifft, liest bald niemand mehr.
            local text = L["STAT_YOURS"]:format(data.mine, data.rating or 0)
            if data.memo then text = text .. "  \194\183  " .. L["STAT_MEMO"] end
            local anteil = data.eff and math.floor(data.eff * 100 + 0.5)
            if anteil and anteil < 100 then
                text = text .. "  \194\183  |cff" .. S:Hex("danger")
                    .. L["STAT_DR"]:format(anteil) .. "|r"
                -- Ab der Grenze rot, mit Strich: man sieht, wie viel
                -- der eigenen Wertung schon weniger bringt.
                if data.knee and data.knee < data.mine then
                    local x = BAR_WIDTH * data.knee / scale
                    row.barOver:ClearAllPoints()
                    row.barOver:SetPoint("TOPLEFT", BAR_X + x, -S.space.sm - 6)
                    row.barOver:SetWidth(math.max(1, BAR_WIDTH * (data.mine - data.knee) / scale))
                    row.barOver:Show()
                    row.barKnee:ClearAllPoints()
                    row.barKnee:SetPoint("TOPLEFT", BAR_X + x - 1, -S.space.sm - 3)
                    row.barKnee:Show()
                end
            end
            row.own:SetText(text)
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
        local gebremst = data.eff and math.floor(data.eff * 100 + 0.5) < 100
        if data.mine and data.rating and gebremst then
            -- Ueber der Grenze: das ist die wichtigere Auskunft als
            -- "erreicht", und sie steht in derselben Farbe wie die Bahn.
            row.share:SetText(L["STAT_OVER"])
            S:Recolor(row.share, "danger")
        elseif data.mine and data.rating then
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

    if data.kind == "race" then
        UI.SetRaceRow(row, data)
        return
    end

    if data.kind == "rotpanel" then
        row.__karte = true
        row.bg:SetAlpha(0)
        row.icon:SetTexture(nil)
        row.title:SetText("")
        row.detail:SetText("")
        row.share:SetText("")
        UI.RotationPanelFill(row, data)
        return
    end

    if data.kind == "compgroup" or data.kind == "compspec" then
        UI.SetCompRow(row, data)
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

    if data.kind == "drcard" then
        row.__karte = true
        row.bg:SetAlpha(0)
        row.icon:SetTexture(nil)
        row.title:SetText("")
        row.detail:SetText("")
        row.share:SetText("")
        drCard.fill(row, data.lines or {})
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
    -- Frueher die Reihenfolge der Fundorte, seit deren Umbau die Zielzahl
    -- der Rassen-Simulation.
    local sortButton = makeButton(content, 170, 22, "", function(self)
        UI.OpenRaceTargets(self)
    end)
    frame.sortButton = sortButton

    -- Die Hervorhebung des Fundort-Rasters.
    --
    -- Kein Filter: sie versteckt nichts, sie hebt hervor. Was nicht
    -- passt, bleibt sichtbar und tritt zurueck - sonst weiss man nie,
    -- ob der Dungeon nichts hat oder die Auswahl zu eng war.
    local highlightButton = makeButton(content, 170, 22, "", function(self)
        -- Keine Farbfelder hier: neben den Haken sahen sie selbst wie
        -- Haken aus (im Spiel gesehen). Die Legende steht ueber der Liste.
        local entries = {}
        for _, key in ipairs(ns.SECONDARY) do
            entries[#entries + 1] = {
                label = L["STAT_" .. key],
                on = function() return ns.Profile.DropsStats()[key] == true end,
                toggle = function() ns.Profile.ToggleDropsStat(key) end,
            }
        end
        entries[#entries + 1] = {
            label = L["DROPS_HL_NONE"],
            on = function() return ns.Profile.DropsStats().none == true end,
            toggle = function() ns.Profile.ToggleDropsStat("none") end,
        }
        entries[#entries + 1] = {
            label = L["DROPS_HL_COMBINE"],
            on = function() return ns.Profile.DropsCombine() end,
            toggle = function() ns.Profile.ToggleDropsCombine() end,
        }
        entries[#entries + 1] = { spacer = true }
        entries[#entries + 1] = {
            label = L["DROPS_HL_TOP"],
            on = function() return ns.Profile.DropsStats().top == true end,
            toggle = function() ns.Profile.ToggleDropsStat("top") end,
        }
        entries[#entries + 1] = {
            label = L["DROPS_HL_FAV"],
            on = function() return ns.Profile.DropsStats().fav == true end,
            toggle = function() ns.Profile.ToggleDropsStat("fav") end,
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
    -- Die Flaeche gemerkt: gefaerbt wird SIE, nicht der Rahmen. Hier
    -- stand S:Recolor(self, ...) - das ist fuer Texte, und am Rahmen
    -- fehlt SetFont. Beim Ueberfahren gab es einen Lua-Fehler.
    grip.fill = S:Fill(grip, "borderSubtle")
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
    grip:SetScript("OnEnter", function(self) self.fill:SetVertexColor(S:Color("accent")) end)
    grip:SetScript("OnLeave", function(self)
        if not self.__zieht then self.fill:SetVertexColor(S:Color("borderSubtle")) end
    end)
    grip:SetScript("OnMouseDown", function(self)
        self.__zieht = true
        local _, mausY = GetCursorPosition()
        self.__vonY = mausY
        self.__vonScroll = scroll:GetVerticalScroll() or 0
        self.fill:SetVertexColor(S:Color("accent"))
    end)
    grip:SetScript("OnMouseUp", function(self)
        self.__zieht = false
        self.fill:SetVertexColor(S:Color("borderSubtle"))
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
    -- KEINE EINKAUFSKNOEPFE UNTEN (24. Oktober). "Einkaufsliste anlegen"
    -- und "Jetzt suchen" standen unter jedem Abschnitt, auch unter der
    -- Rotation, und nuetzen nur am Auktionshaus - dort steht die Liste mit
    -- denselben Knoepfen ohnehin daneben (UI.RefreshAuctionPanel), und das
    -- Erinnerungsfenster hat sie auch.
    sourceText:SetWidth(math.max(200, (savedW or WIDTH) - 60))

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
    if not ns.Recommend.Ready() then return ns.Data.Message() end
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
    -- Die Gruppen stehen immer da, sobald es fuer IRGENDEINE Aktivitaet
    -- welche gibt: gesucht wurden sie auch, waehrend Raid gewaehlt war
    -- (20. Oktober). Fehlt der gewaehlten etwas, sagt es die Seite.
    if key == "comps" then return ns.Recommend.HasComps() end
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
-- Die Zeilen der Ausruestung, auch von aussen lesbar.
--
-- Wie UI.DropRows und UI.FolioRows: der Test muss sehen koennen,
-- WELCHE Herkuenfte in den Zeilen stecken, sonst kann er den
-- Herkunftsfilter nur an der Anzahl messen - und die haengt an den
-- Daten der Nacht.
UI.GearRows = gearRows

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
    -- Was der laengste Eintrag braucht: sein Text, sein Einzug, der Rand des
    -- Knopfs links und rechts und der Rand der Leiste.
    local need = 0
    for _, button in ipairs(navButtons) do
        local w = tonumber(button.label:GetStringWidth()) or 0
        local einzug = (button.section and button.section.sub) and 14 or 0
        need = math.max(need, w + einzug + S.space.md * 3 + 4)
    end
    for _, head in ipairs(groupHeads) do
        need = math.max(need, (tonumber(head.label:GetStringWidth()) or 0) + 14 + S.space.md * 3 + 4)
    end
    UI.sidebarNeed = math.ceil(need)
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
    -- Die Gruppen gibt es je Dungeon, nicht je Boss: im Raid zaehlen alle
    -- Kills zusammen.
    if section.key == "comps" and not tostring(base):find("^mplus") then dungeonMatters = false end
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
    -- NUR, WO SIE ETWAS AENDERT (26. Oktober): Rotation und Rassen haengen
    -- an keiner Plattform; "Gruppen & Specs" zaehlt je Aktivitaet eine
    -- (choices bleibt dort 1). Die Aktivitaet waehlt man trotzdem.
    frame.activityButton:SetShown(dataSection)
    frame.sourceButton:SetShown(dataSection and UI.SourceMatters(section.key) and choices >= 2)

    -- Die Katalogangabe stand hier klein und grau und wurde nicht
    -- gelesen. Sie steht jetzt unter "Info", vollstaendig.
    headerText:SetText("")

    -- Ueber S:SetText: dieselbe Zeile traegt im Spielerprofil einen
    -- Namen, der aus Korea kommen kann. Direkt gesetzt, erbte sie dessen
    -- Schrift.
    S:SetText(sectionTitle, section.key == "comps" and UI.CompTitle(base)
        or L["SECTION_" .. section.key])

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
    -- Seit dem Umbau gibt es keine Rangfolge mehr zu waehlen: oben
    -- steht "Wo du hinwillst", darunter die Instanzen nach Namen.
    frame.sortButton:SetShown(section.key == "races" and UI.RaceTargetChoices() ~= nil)
    -- Kurz auf dem Knopf, voll im Menue.
    --
    -- Fuenf Waehler stehen in dieser Ansicht nebeneinander; jedes
    -- ueberfluessige Wort schiebt einen davon in die zweite Zeile, und
    -- ein einzelner Knopf, der dort haengt, sieht aus wie ein Fehler.
    frame.sortButton.label:SetText(UI.RaceTargetLabel(UI.RaceTargets()))
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
        if set.none then teile[#teile + 1] = L["DROPS_HL_NONE"] end
        local alle = {}
        if #teile > 0 then
            alle[1] = table.concat(teile, ns.Profile.DropsCombine() and " + " or " / ")
        end
        if set.top then alle[#alle + 1] = L["DROPS_HL_TOP_S"] end
        if set.fav then alle[#alle + 1] = L["DROPS_HL_FAV"] end
        frame.highlightButton.label:SetText(#alle == 0 and L["DROPS_HL"]
            or table.concat(alle, "  \194\183  "))
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
    elseif section.key == "races" then
        local vorschau
        currentRows, vorschau = UI.RaceRows(specID, mode)
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted)
            or UI.RaceHint(specID, vorschau))
    elseif section.key == "comps" then
        local zaehlung, unter, art
        currentRows, zaehlung, unter, art = UI.CompRows(mode)
        hintText:SetText(#currentRows == 0 and L["COMP_NONE"]
            or UI.CompHint(zaehlung, unter, mode, art))
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
        -- murlok nennt seine Top-Spieler, nicht ihren Median: der Satz
        -- sagt, woher die Zahl ist, und behauptet nichts darueber hinaus.
        local n = currentRows[1] and currentRows[1].players
        local hinweis = n and (fromSource == "murlok.io" and L["STAT_HINT_TOP"] or L["STAT_HINT_N"]):format(n)
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted) or hinweis or L["STAT_HINT"])
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
    elseif section.key == "rotation" then
        currentRows = UI.RotationRows(specID, mode)
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted)
            or UI.RotationHint(specID, mode))
    elseif section.key == "drops" then
        currentRows, fromSource = withFallback(function(source)
            return UI.DropRows(specID, mode, source)
        end)
        -- Der Hinweis nennt die Antwort, nicht die Methode.
        --
        -- "Was die Besten tragen, nach Fundort sortiert" beschreibt,
        -- was die Liste IST. Die Frage war "wo muss ich rein" - und die
        -- beantwortet der Name, der oben steht.
        -- Wo die meisten Favoriten fallen - bei Gleichstand die erste.
        local erste
        for _, row in ipairs(currentRows) do
            if row.inst and (row.need or 0) > ((erste and erste.need) or 0) then erste = row end
        end
        local wohin = erste and ((erste.enc and ns.Compat.EncounterName
            and ns.Compat.EncounterName(erste.enc)) or ns.Compat.InstanceName(erste.inst))
        hintText:SetText(#currentRows == 0 and emptyReason(mode, wanted)
            or (wohin and L["DROPS_TOP_NEED"]:format(wohin))
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
        hintText:SetText("|cff" .. S:Hex("danger") .. ns.Data.Message() .. "|r")
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
                or (section.key == "races") and row.side
                or (section.key == "comps") and row.part
                or row.slot
            -- Eine Rasse beider Seiten passt zu jeder Fraktion.
            if section.key == "races" and row.side == "both" then key = picked end
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
    sourceText:SetWidth(math.max(200, frame:GetWidth() - 60))

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
        elseif data.kind == "rotpanel" then
            place(row, ((data.panelH or 200) + S.space.sm * 2) * (S.fontScale or 1))
        elseif data.kind == "drcard" then
            -- Luft darueber, damit die Karte nicht an der letzten
            -- Bahn klebt.
            place(row, (drCard.height(#(data.lines or {})) + 24) * (S.fontScale or 1))
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
    sectionCount:SetText("")

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
-- "FAVORIT GEDROPPT!"
--
-- Ein kleines Fenster mit je einer Zeile pro Stueck: Symbol, Name, wer
-- es bekommen hat, und ein Knopf zum Anfluestern. Gewuenscht am 19.
-- Oktober nach dem Vorbild von Keystone Loot. Gebaut wird es erst,
-- wenn es gebraucht wird; die Zeilen werden wiederverwendet.
do
    local favFrame
    local ZEILEN, HOEHE = 5, 40

    local function zeile(i)
        local r = favFrame.rows[i]
        if r then return r end
        r = CreateFrame("Frame", nil, favFrame)
        r:SetHeight(HOEHE)
        r:SetPoint("TOPLEFT", S.space.md, -42 - (i - 1) * (HOEHE + 4))
        r:SetPoint("TOPRIGHT", -S.space.md, -42 - (i - 1) * (HOEHE + 4))
        S:Fill(r, "bgRaised")
        S:Border(r, "borderSubtle")
        -- Das Symbol zeigt das Tooltip des Gegenstands.
        r.icon = CreateFrame("Button", nil, r)
        r.icon:SetSize(30, 30)
        r.icon:SetPoint("LEFT", 5, 0)
        r.icon.tex = r.icon:CreateTexture(nil, "ARTWORK")
        r.icon.tex:SetAllPoints()
        r.icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        S:Border(r.icon, "gold")
        r.icon:SetScript("OnEnter", function(self)
            if not self.link and not self.itemID then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.link then GameTooltip:SetHyperlink(self.link)
            else GameTooltip:SetItemByID(self.itemID) end
            GameTooltip:Show()
        end)
        r.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r.name = S:Text(r, "body", "textPrimary")
        r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
        r.name:SetPoint("RIGHT", r, "RIGHT", -112, 0)
        r.name:SetWordWrap(false)
        r.who = S:Text(r, "caption", "textSecondary")
        r.who:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 1)
        r.ask = makeButton(r, 100, 24, L["FAV_DROP_WHISPER_BTN"], function(self)
            if ns.Wish.Whisper(self.entry) then UI.ShowFavoriteDrops(ns.Wish.Open()) end
        end)
        r.ask:SetPoint("RIGHT", -6, 0)
        favFrame.rows[i] = r
        return r
    end

    ---Zeigt die gedroppten Favoriten.
    ---@param list table[]  { id, link, player, class, asked }
    function UI.ShowFavoriteDrops(list)
        if not favFrame then
            favFrame = CreateFrame("Frame", "MetaCodexFavDrops", UIParent)
            favFrame:SetSize(400, 100)
            favFrame:SetFrameStrata("DIALOG")
            favFrame:SetToplevel(true)
            favFrame:EnableMouse(true)
            favFrame:SetMovable(true)
            favFrame:SetClampedToScreen(true)
            favFrame:RegisterForDrag("LeftButton")
            favFrame:SetScript("OnDragStart", favFrame.StartMoving)
            favFrame:SetScript("OnDragStop", favFrame.StopMovingOrSizing)
            favFrame:SetPoint("TOP", UIParent, "TOP", 0, -160)
            S:Fill(favFrame, "bgBase")
            -- Der Rahmen auf einer EIGENEN Ebene ueber allem, zwei Punkte
            -- breit. Am Fenster selbst zeichneten Kopf und Zeilen darueber,
            -- und er war nur stellenweise zu sehen (19. Oktober).
            local rand = CreateFrame("Frame", nil, favFrame)
            rand:SetAllPoints()
            rand:SetFrameLevel(favFrame:GetFrameLevel() + 20)
            local dick = S:Pixel(2)
            for _, seite in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
                local t = rand:CreateTexture(nil, "OVERLAY")
                t:SetTexture("Interface\\Buttons\\WHITE8X8")
                t:SetVertexColor(S:Color("gold"))
                t:SetPoint(seite[1])
                t:SetPoint(seite[2])
                if seite[3] then t:SetHeight(dick) else t:SetWidth(dick) end
            end
            favFrame.rand = rand
            local head = CreateFrame("Frame", nil, favFrame)
            head:SetPoint("TOPLEFT")
            head:SetPoint("TOPRIGHT")
            head:SetHeight(34)
            S:Fill(head, "bgRaised")
            S:Border(head, "borderSubtle", 1, { bottom = true })
            -- Der Text steht fest, der Stern haengt an SEINER Mitte. Vorher
            -- war es umgekehrt, und die Grafik hat oben mehr Rand als unten:
            -- der Stern sass zu hoch (19. Oktober). Die Atlas-Grafik ist eng
            -- geschnitten; die alte Textur bleibt der Rueckfall.
            favFrame.title = S:Text(head, "title", "gold")
            favFrame.title:SetPoint("LEFT", S.space.md + 22, 0)
            favFrame.star = head:CreateTexture(nil, "ARTWORK")
            if not (favFrame.star.SetAtlas
                and pcall(favFrame.star.SetAtlas, favFrame.star, "PetJournal-FavoritesIcon", false)) then
                favFrame.star:SetTexture("Interface\\Common\\FavoritesIcon")
            end
            favFrame.star:SetSize(16, 16)
            favFrame.star:SetPoint("RIGHT", favFrame.title, "LEFT", -6, 0)
            favFrame.title:SetText(L["FAV_DROP_TITLE"])
            favFrame.close = makeButton(head, 22, 22, "X", function()
                favFrame:Hide()
                ns.Wish.Clear()
            end)
            favFrame.close:SetPoint("RIGHT", -S.space.sm, 0)
            favFrame.rows = {}
            tinsert(UISpecialFrames, "MetaCodexFavDrops")
            favFrame:SetScript("OnHide", function() ns.Wish.Clear() end)
        end

        local n = math.min(#(list or {}), ZEILEN)
        for i = 1, ZEILEN do
            local e = list and list[i]
            local r = (i <= n) and zeile(i) or favFrame.rows[i]
            if r and i <= n and e then
                local name, link, icon = ns.Compat.ItemInfo(e.id)
                if not icon then ns.Compat.RequestItem(e.id) end
                r.icon.tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                r.icon.link, r.icon.itemID = e.link or link, e.id
                r.name:SetText(e.link or link or name or ("#" .. e.id))
                local farbe = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
                -- Nur Name-Realm in der Klassenfarbe - "bekommen hat es"
                -- sagte nichts, was die Zeile nicht ohnehin sagt (19. Oktober).
                -- Mit Realm, weil genau dorthin gefluestert wird.
                local wer = e.player
                if farbe and farbe.WrapTextInColorCode then wer = farbe:WrapTextInColorCode(wer) end
                r.who:SetText(wer)
                r.ask.entry = e
                r.ask.label:SetText(e.asked and L["FAV_DROP_ASKED"]
                    or (e.waiting and L["FAV_DROP_WAITING"]) or L["FAV_DROP_WHISPER_BTN"])
                if r.ask.SetEnabled then r.ask:SetEnabled(not e.asked and not e.waiting) end
                r:Show()
            elseif r then
                r:Hide()
            end
        end
        favFrame:SetHeight(42 + n * (HOEHE + 4) + S.space.sm)
        favFrame:Show()
        return favFrame
    end
end

-- DER ABSCHNITT "RASSEN" (19. Oktober).
--
-- Zwei Auskuenfte, und sie werden nicht vermischt: GESPIELT - der Anteil
-- der gemessenen Top-Spieler (raider.io) - und SIMULIERT - was eine Rasse
-- an Schaden bringt, gegenueber der schwaechsten (bloodmallet.com,
-- SimulationCraft). Gruppiert nach Seite, die eigene zuerst: wer Horde
-- spielt, waehlt meist unter der Horde.
do
    -- Welche Zielzahlen je Aktivitaet zur Wahl stehen, und welche zuerst.
    -- Ohne Eintrag (PvP) keine Simulation: ein Patchwerk sagt dort nichts.
    local ZIELE = { mplus = { 1, 3, 5 }, raid = { 1, 3 } }
    local VORGABE = { mplus = 5, raid = 1 }
    -- Unterschiede darunter sind Rauschen: bloodmallet rechnet mit 0,1 %.
    local RAUSCHEN = 0.2

    local function basis()
        local mode = ns.Profile.LookupMode()
        local b = ns.Recommend.BaseMode and ns.Recommend.BaseMode(mode) or mode
        return tostring(b):match("^(%a+)")
    end

    ---Die Zielzahlen der Aktivitaet, oder nil (PvP).
    function UI.RaceTargetChoices()
        return ZIELE[basis() or ""]
    end

    ---Die gewaehlte Zielzahl - oder die Vorgabe der Aktivitaet.
    function UI.RaceTargets()
        local b = basis()
        local wahl = ZIELE[b or ""]
        if not wahl then return nil end
        local n = ns.Profile.RaceTargets(b)
        for _, ok in ipairs(wahl) do if ok == n then return n end end
        return VORGABE[b]
    end

    function UI.RaceTargetLabel(n)
        if not n then return "" end
        return n == 1 and L["RACE_TARGETS_1"] or L["RACE_TARGETS_N"]:format(n)
    end

    function UI.OpenRaceTargets(anchor)
        local wahl = UI.RaceTargetChoices()
        if not wahl then return end
        local entries = {}
        for _, n in ipairs(wahl) do entries[#entries + 1] = { key = n, label = UI.RaceTargetLabel(n) } end
        contextMenu(anchor, L["RACE_TARGETS"], entries, function(entry)
            ns.Profile.SetRaceTargets(basis(), entry.key)
        end)
    end

    -- Wo der Atlas anders heisst als die Datei der Rasse.
    local ATLAS = {
        scourge = { "undead" },
        highmountaintauren = { "highmountain" },
        zandalaritroll = { "zandalari" },
        lightforgeddraenei = { "lightforged" },
        magharorc = { "maghar" },
        earthendwarf = { "earthen" },
        harronir = { "haranir" },
        haranir = { "haranir" },
    }

    ---Der Atlas des Rassensymbols - nur einer, den es wirklich gibt.
    function UI.RaceAtlas(datei)
        if type(datei) ~= "string" or not (C_Texture and C_Texture.GetAtlasInfo) then return nil end
        local klein = datei:lower()
        local namen = { klein }
        for _, n in ipairs(ATLAS[klein] or {}) do namen[#namen + 1] = n end
        for _, n in ipairs(namen) do
            for _, form in ipairs({ "raceicon128-%s-male", "raceicon-%s-male" }) do
                local name = form:format(n)
                local ok, info = pcall(C_Texture.GetAtlasInfo, name)
                if ok and type(info) == "table" then return name end
            end
        end
        return nil
    end

    local function zahl(x)
        local text = ("%.1f"):format(x)
        if GetLocale and GetLocale() == "deDE" then text = text:gsub("%.", ",") end
        return text
    end

    local function rassenName(id)
        local info = C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(id)
        if type(info) == "table" and type(info.raceName) == "string" then return info.raceName, info.clientFileString end
        local r = ns.Catalog.Race(id)
        if not r then return "#" .. id end
        return (GetLocale and GetLocale() == "deDE") and r.nameDE or r.name
    end

    -- DIE DEV-VORSCHAU: Beispieldaten, solange die Nacht noch keine echten
    -- gesammelt hat. Nur ohne Versionsnummer - im Paket steht sie nie.
    local function vorschau()
        local played, sims = { n = 100 }, { ts = "DEV" }
        local ids = ns.Catalog.RaceIDs()
        local pct = { 31, 22, 14, 9, 7, 5, 4, 3, 2, 2, 1 }
        for i, id in ipairs(ids) do
            if pct[i] then played[#played + 1] = { id, pct[i] } end
        end
        for _, n in ipairs({ 1, 3, 5 }) do
            local liste = {}
            for i, id in ipairs(ids) do liste[#liste + 1] = { id, ((i * 7 + n * 3) % 17) / 10 } end
            sims[n] = liste
        end
        return played, sims
    end

    ---Die Zeilen des Abschnitts.
    ---@return table[] rows
    ---@return boolean vorschau
    function UI.RaceRows(specID, mode)
        local played = ns.Recommend.Races(specID, mode)
        local sims = ns.Recommend.RaceSims(specID)
        local preview = false
        if not played and not sims and ns.version == "dev" then
            played, sims = vorschau()
            preview = true
        end
        local ziele = UI.RaceTargets()
        local simRows = (ziele and sims) and sims[ziele] or nil

        -- Je Rasse: Anteil, beste Simulation (bei den Zandalari je Loa die
        -- beste), Seite.
        local byId, order = {}, {}
        local function eintrag(id)
            if not byId[id] then
                byId[id] = { kind = "race", id = id }
                order[#order + 1] = byId[id]
            end
            return byId[id]
        end
        for _, row in ipairs(played or {}) do
            if type(row) == "table" then eintrag(row[1]).pct = row[2] end
        end
        local bestes = 0
        for _, row in ipairs(simRows or {}) do
            local e = eintrag(row[1])
            if e.rel == nil or row[2] > e.rel then e.rel, e.loa = row[2], row[3] end
            if row[2] > bestes then bestes = row[2] end
        end
        -- EINE LISTE, nicht je Fraktion (19. Oktober): wer vorn liegt, soll
        -- man auf einen Blick sehen. Die Seite steht klein in der Zeile, und
        -- der Waehler oben filtert, wer nur in seiner Fraktion schaut.
        local rows = {}
        for _, e in ipairs(order) do
            local r = ns.Catalog.Race(e.id)
            if r then
                e.side = r.side
                -- NICHT "top": das Feld setzt der Zeichner selbst (meistgespielt).
                e.simTop = e.rel ~= nil and (bestes - e.rel) < RAUSCHEN
                e.n = played and played.n or nil
                e.pool = played and played.pool or nil
                e.targets = ziele
                e.ts = sims and sims.ts or nil
                e.preview = preview
                rows[#rows + 1] = e
            end
        end
        -- Nach dem simulierten Vorsprung, der beste zuerst. Ohne Simulation -
        -- Heiler, PvP - nach dem Anteil der Gemessenen.
        table.sort(rows, function(x, y)
            if simRows and (x.rel or -1) ~= (y.rel or -1) then return (x.rel or -1) > (y.rel or -1) end
            if (x.pct or 0) ~= (y.pct or 0) then return (x.pct or 0) > (y.pct or 0) end
            if (x.rel or -1) ~= (y.rel or -1) then return (x.rel or -1) > (y.rel or -1) end
            return x.id < y.id
        end)
        return rows, preview
    end

    ---Der Satz ueber der Liste.
    function UI.RaceHint(specID, preview)
        local sims = ns.Recommend.RaceSims(specID)
        local text = (sims or preview) and UI.RaceTargets() and L["RACE_HINT"] or L["RACE_HINT_NOSIM"]
        if preview then text = "|cffD29922DEV-Vorschau mit Beispieldaten.|r  " .. text end
        return text
    end

    ---Eine Zeile: Name, gespielt, simuliert.
    function UI.SetRaceRow(row, data)
        row.link = nil
        local name, datei = rassenName(data.id)
        row.icon:SetTexture(nil)
        local symbol = false
        -- Erst fragen, ob es den Atlas gibt: ein unbekannter wirft nichts,
        -- und dann blieb das Feld leer (Untote, Zandalari, Hochbergtauren,
        -- Haranir, Irdene - 19. Oktober). Der Name folgt nicht immer der
        -- Datei der Rasse; die bekannten Abweichungen stehen in ATLAS.
        local atlas = UI.RaceAtlas(datei)
        if atlas and row.icon.SetAtlas then
            symbol = pcall(row.icon.SetAtlas, row.icon, atlas, false)
        end
        if not symbol then
            local r = ns.Catalog.Race(data.id)
            local erste = r and r.abilities and r.abilities[1]
            row.icon:SetTexture(erste and erste.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
        row.title:SetText(data.loa and (name .. " (" .. data.loa .. ")") or name)
        -- Die Seite vorn, klein: ohne Gruppen muss die Zeile sie selbst sagen.
        local seite = data.side and L["RACE_GROUP_" .. data.side] or nil
        local gespielt = data.pct and L["RACE_PLAYED"]:format(data.pct)
            or (data.n and L["RACE_NOT_PLAYED"] or nil)
        row.detail:SetText(seite and gespielt and (seite .. "  \194\183  " .. gespielt)
            or seite or gespielt or "")
        if data.rel ~= nil then
            row.share:SetText("+" .. zahl(data.rel) .. " %")
            S:Recolor(row.share, data.simTop and "success" or "textSecondary")
        else
            row.share:SetText("")
        end
        row.raceTip = data
        row.onClick = nil
    end

    ---Der Tooltip: Faehigkeiten, und woher die Zahlen kommen.
    function UI.RaceTooltip(owner, data)
        tipOutside(owner)
        local name = rassenName(data.id)
        GameTooltip:SetText(data.loa and (name .. " (" .. data.loa .. ")") or name, 1, 1, 1)
        local r = ns.Catalog.Race(data.id)
        local de = GetLocale and GetLocale() == "deDE"
        if r and r.abilities and #r.abilities > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["RACE_TIP_ABILITIES"], S:Color("heading"))
            for _, a in ipairs(r.abilities) do
                GameTooltip:AddLine(("|T%d:14:14|t %s"):format(a.icon or 0, de and a.de or a.en), 1, 0.82, 0)
                GameTooltip:AddLine(de and a.deDesc or a.enDesc, 0.9, 0.9, 0.9, true)
            end
        end
        GameTooltip:AddLine(" ")
        if data.pct and data.n then
            GameTooltip:AddLine(L["RACE_TIP_PLAYED"]:format(data.pct, data.n), 0.7, 0.7, 0.7, true)
            -- Zusammengefasst, wo eine Aktivitaet allein zu klein war.
            if data.pool then GameTooltip:AddLine(L["RACE_TIP_POOL"], 0.5, 0.5, 0.5, true) end
        end
        if data.rel ~= nil and data.targets then
            GameTooltip:AddLine(L["RACE_TIP_SIM"]:format(zahl(data.rel), UI.RaceTargetLabel(data.targets)),
                0.7, 0.7, 0.7, true)
            GameTooltip:AddLine(L["RACE_TIP_SOURCE"]:format(tostring(data.ts or "?"):sub(1, 10)), 0.5, 0.5, 0.5, true)
        end
        GameTooltip:Show()
    end
end

-- ------------------------------------------------------------ Rotation
--
-- Aus den Prioritaetslisten von SimulationCraft, gefaltet mit dem
-- gemessenen Build (tools/build-rotation.js). Gespeichert sind nur
-- Zauber-IDs und kleine Bedingungen ({ "up", 260734 }); Name, Symbol und
-- Satz entstehen hier, in der Sprache des Clients.
--
-- Aufgebaut wie bei Wowhead (20. Oktober): Reiter, darueber ein
-- Beispiel-Ablauf um den Pull, darunter die Prioritaet als nummerierte
-- Saetze - "Wirke Sturmhueter, sobald verfuegbar." - mit den Zaubern in
-- Gold und ihrem Symbol im Text.
do
    local function zahl(x)
        if type(x) ~= "number" then return tostring(x or "?") end
        local text = (x % 1 == 0) and tostring(x) or ("%.1f"):format(x)
        if GetLocale and GetLocale() == "deDE" then text = text:gsub("%.", ",") end
        return text
    end

    ---@param label string|nil wie er im Satz heisst ("Xuen den Weissen Tiger" hinter "Beschwoere")
    local function zauber(id, label)
        if label then return label end
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        return type(name) == "string" and name or ("#" .. tostring(id))
    end

    local function symbol(id)
        return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or nil
    end

    -- EIN SYMBOL IM SATZ: so gross wie die Schrift, mittig zur Zeile, der
    -- Rand abgeschnitten. Mit ":0" sass es auf der Grundlinie und ragte nach
    -- oben heraus - nicht mittig neben dem Namen (20. Oktober).
    local function imSatz(tex)
        if not tex then return "" end
        local h = math.floor((S.font and S.font.title or 15) * (S.fontScale or 1) + 0.5)
        return ("|T%s:%d:%d:0:-%d:64:64:5:59:5:59|t "):format(tostring(tex), h, h, math.floor(h * 0.27 + 0.5))
    end

    -- Im Satz: Symbol mittig zur Zeile, Name in Gold.
    -- JEDER NAME EIN LINK (20. Oktober): ein Satz ist ein Textfeld, und der
    -- Zeiger zeigte den Zauber der ganzen Zeile, egal ueber welchem Namen er
    -- stand. Als Link meldet jeder Name sich selbst (OnHyperlinkEnter).
    local function gold(id, label)
        return "|Hspell:" .. tostring(id) .. "|h" .. imSatz(symbol(id)) .. "|cffffd100" .. zauber(id, label) .. "|r|h"
    end

    local function resource(key)
        local text = L["ROT_RES_" .. tostring(key)]
        if text == "ROT_RES_" .. tostring(key) then text = (tostring(key):gsub("_", " ")) end
        return text
    end

    -- Bedingung -> Nebensatz ("Meister der Elemente aktiv ist").
    local SPELL1 = { up = true, down = true, refresh = true, ready = true, notready = true,
        cdsoon = true, prev = true, notprev = true, casting = true, notcasting = true,
        flying = true, notflying = true, stronger = true, notstronger = true, weakdot = true, strongdot = true,
        placed = true, notplaced = true }
    -- Ohne Argument (Verstohlenheit).
    local PLAIN = { stealthed = true, notstealthed = true }

    -- Ein Wert als Hauptwort, fuer Vergleiche zweier Werte.
    local function wert(n, nm)
        if type(n) ~= "table" then return "?" end
        local k = n[1]
        if k == "n" then return zahl(n[2]) end
        if k == "gcd" then return L["ROT_N_gcd"] end
        if k == "res" then return resource(n[2]) end
        if k == "def" then return L["ROT_N_def"]:format(resource(n[2])) end
        if k == "rem" or k == "cd" or k == "chg" or k == "stk" or k == "dots" or k == "full"
            or k == "usable" or k == "casttime" or k == "flyleft" then
            return L["ROT_N_" .. k]:format(nm(n[2]))
        end
        if k == "inflight" or k == "rtb" or k == "tgt" then return L["ROT_N_" .. k] end
        if k == "min" or k == "max" then return L["ROT_N_" .. k]:format(wert(n[2], nm), wert(n[3], nm)) end
        if k == "stat" then
            local stat = L["STAT_" .. tostring(n[2])]
            return L["ROT_N_stat"]:format(stat ~= "STAT_" .. tostring(n[2]) and stat or tostring(n[2]))
        end
        if k == "regen" then return L["ROT_N_regen"]:format(resource(n[2])) end
        -- "2 globale Cooldowns" statt "ein globaler Cooldown × 2".
        if k == "mul" and type(n[2]) == "table" and type(n[3]) == "table" then
            local g, z = n[2], n[3]
            if g[1] == "n" then g, z = z, g end
            if g[1] == "gcd" and z[1] == "n" then return L["ROT_N_gcds"]:format(zahl(z[2])) end
        end
        if k == "mul" or k == "plus" or k == "minus" then
            return L["ROT_N_" .. k]:format(wert(n[2], nm), wert(n[3], nm))
        end
        return "?"
    end
    local SPELLN = { cdunder = true, cdover = true, stackmin = true, stackunder = true, stackis = true,
        remunder = true, remover = true, chargesunder = true, chargesfull = true, doton = true }
    local RESN = { resmin = true, resunder = true, resis = true, respctmin = true, respctunder = true }

    -- AM EIGENEN ZAUBER (26. Oktober): "Erneuere Mondfeuer, wenn noch unter
    -- 12 Sek. uebrig sind" statt "... wenn Mondfeuer in unter 12 Sek.
    -- auslaeuft". Gleich heisst: gleicher Name - der Debuff hat eine andere
    -- ID als der Zauber.
    local function eigen(c, selbst)
        return selbst ~= nil and type(c) == "table" and type(c[2]) == "number"
            and zauber(c[2]) == zauber(selbst) and L["ROT_CS_" .. tostring(c[1])] ~= "ROT_CS_" .. tostring(c[1])
    end
    local function eigenSatz(c)
        local kind, n = c[1], c[3]
        if (kind == "charges" or kind == "chargesnear") and type(n) == "number" and n % 1 ~= 0 then
            kind, n = "chargesnear", math.ceil(n)
        end
        if (kind == "charges" or kind == "chargesnear" or kind == "chargesunder") and n == 1
            and L["ROT_CS_" .. kind .. "1"] ~= "ROT_CS_" .. kind .. "1" then
            return L["ROT_CS_" .. kind .. "1"]
        end
        return (L["ROT_CS_" .. kind]:gsub("%%s", (zahl(n):gsub("%%", "%%%%"))))
    end

    -- ZUSAMMENGEZOGEN (26. Oktober): "wenn Einaeschern aktiv oder bereit
    -- ist", "wenn A und B aktiv sind" - nicht zweimal derselbe Satzbau.
    -- Die festen Tabellen des Satzbaus, in EINER: Lua 5.1 erlaubt einer
    -- Funktion 200 lokale Namen, und dieser Block steht im Hauptteil.
    local K = {
        ADJ = { up = 1, down = 2, ready = 1, cdsoon = 1, notready = 2 },
        NAMENSVERBEN = { "summon", "invoke", "call", "form", "stance" },
        -- Was sich hinter einem Namen sammeln laesst: Aussagen der Form "X ...".
        GRUPPE = { up = true, down = true, refresh = true, ready = true, notready = true, cdsoon = true,
            stackmin = true, stackunder = true, stackis = true, remunder = true, remover = true, charges = true,
            chargesunder = true, chargesfull = true, cdunder = true, cdover = true, doton = true },
        VERB_VON = { stance = "form" },
        ERNEUERN = { refresh = true, remunder = true, stronger = true },
        OHNE = { cd = "ROT_S_oncd", ch = "ROT_S_charges", w = "ROT_S_ready" },
    }
    local verbinde
    -- "A, B oder C" statt "A oder B oder C".
    local function listeOder(parts)
        if #parts <= 1 then return parts[1] or "" end
        return table.concat(parts, ", ", 1, #parts - 1) .. L["ROT_OR"] .. parts[#parts]
    end

    -- WAS DER NAME SAGT (26. Oktober): "Xuen den Weissen Tiger beschwoeren"
    -- ist eine Beschwoerung, "Katzengestalt" eine Gestalt. Die Muster stehen
    -- in der Sprachdatei (ROT_VP_*), die Klammer ist der Name im Satz.
    local function namensverb(id)
        local name = zauber(id)
        for _, art in ipairs(K.NAMENSVERBEN) do
            local muster = L["ROT_VP_" .. art]
            if muster ~= "ROT_VP_" .. art then
                local label = name:match(muster)
                if label then return art, label end
            end
        end
        return nil
    end
    -- Eine Beschwoerung als Bedingung: "du Niuzao den Schwarzen Ochsen
    -- beschworen hast", nicht "Niuzao den Schwarzen Ochsen beschwoeren aktiv ist".
    local function beschwoerung(id)
        local art, label = namensverb(id)
        if art == "summon" or art == "invoke" or art == "call" then return art, label end
        return nil
    end
    local function say(c, top, nm, selbst)
        nm = nm or zauber
        if type(c) ~= "table" then return L["ROT_C_other"] end
        local kind = c[1]
        if kind == "and" then return say(c[2], false, nm, selbst) .. L["ROT_AND"] .. say(c[3], false, nm, selbst) end
        if kind == "or" then
            -- Ein Oder im Oder ist dieselbe Gruppe: eine Klammer, nicht zwei.
            local teile = {}
            local function glied(x)
                if type(x) == "table" and x[1] == "or" then glied(x[2]); glied(x[3]) else teile[#teile + 1] = x end
            end
            glied(c)
            local gruppen = false
            for _, x in ipairs(teile) do if type(x) == "table" and x[1] == "and" then gruppen = true end end
            local saetze = verbinde(teile, false, nm, selbst)
            local text = gruppen and table.concat(saetze, L["ROT_OR_SEP"]) or listeOder(saetze)
            return top and text or ("(" .. text .. ")")
        end
        if eigen(c, selbst) then return eigenSatz(c) end
        if K.ADJ[kind] and type(c[2]) == "number" then
            local art, label = beschwoerung(c[2])
            local key = art and ("ROT_CN_" .. art .. "_" .. kind)
            if key and L[key] ~= key then return L[key]:format(nm(c[2], label)) end
        end
        if kind == "charged" or kind == "notcharged" then return L["ROT_C_" .. kind]:format(zahl(c[2])) end
        if SPELL1[kind] then return L["ROT_C_" .. kind]:format(nm(c[2])) end
        if PLAIN[kind] then return L["ROT_C_" .. kind] end
        -- Wie lange her: vor weniger / mehr als N Sek. gewirkt.
        if kind == "ago" then return L["ROT_C_ago_" .. tostring(c[3])]:format(nm(c[2]), zahl(c[4])) end
        if kind == "castleft" or kind == "castdone" or kind == "multunder" then
            return L["ROT_C_" .. kind]:format(nm(c[2]), zahl(c[3]))
        end
        if kind == "myhpunder" or kind == "myhpover" then return L["ROT_C_" .. kind]:format(zahl(c[2])) end
        -- Dämonenwoge: Woge, Fähigkeit.
        if kind == "surge" or kind == "nosurge" then return L["ROT_C_" .. kind]:format(nm(c[2]), nm(c[3])) end
        -- Zustände über den Kampf: ein Nebensatz in einem Nebensatz.
        if kind == "notyet" or kind == "already" then return L["ROT_C_" .. kind]:format(say(c[2], true, nm)) end
        if kind == "since" or kind == "notsince" then
            return L["ROT_C_" .. kind]:format(say(c[2], true, nm), say(c[3], true, nm))
        end
        -- Eine Aufladung, nicht "1 Aufladungen".
        if kind == "chargesunder" and c[3] == 1 then return L["ROT_C_chargesunder1"]:format(nm(c[2])) end
        if SPELLN[kind] then return L["ROT_C_" .. kind]:format(nm(c[2]), zahl(c[3])) end
        if kind == "charges" then
            if type(c[3]) == "number" and c[3] % 1 ~= 0 then
                local n = math.ceil(c[3])
                if n == 1 then return L["ROT_C_chargesnear1"]:format(nm(c[2])) end
                return L["ROT_C_chargesnear"]:format(nm(c[2]), zahl(n))
            end
            if c[3] == 1 then return L["ROT_C_charges1"]:format(nm(c[2])) end
            return L["ROT_C_charges"]:format(nm(c[2]), zahl(c[3]))
        end
        if kind == "tgtis" or kind == "tgtmin" or kind == "tgtmax"
            or kind == "hpunder" or kind == "hpover" or kind == "timeunder" or kind == "timeover" then
            return L["ROT_C_" .. kind]:format(zahl(c[2]))
        end
        if kind == "resnotcap" or kind == "resfull" then
            -- Erst die Zahl: "dir weniger als 20 Runenmacht zum Maximum fehlen".
            if c[3] then return L["ROT_C_" .. kind .. "n"]:format(zahl(c[3]), resource(c[2])) end
            return L["ROT_C_" .. kind]:format(resource(c[2]))
        end
        if kind == "resenough" then return L["ROT_C_resenough"]:format(resource(c[2])) end
        if kind == "cmp" then
            return L["ROT_CMP_" .. tostring(c[3])]:format(wert(c[2], nm), wert(c[4], nm))
        end
        if RESN[kind] then return L["ROT_C_" .. kind]:format(zahl(c[3]), resource(c[2])) end
        return L["ROT_C_other"]
    end
    UI.RotationSay = say

    -- "A, B und C" statt "A und B und C".
    local function liste(parts)
        if #parts <= 1 then return parts[1] or "" end
        return table.concat(parts, ", ", 1, #parts - 1) .. L["ROT_AND"] .. parts[#parts]
    end

    ---Bedingungen eines Und (und=true) oder eines Oder als Teilsaetze, so
    ---zusammengezogen, wie man es sagt (26. Oktober):
    ---  derselbe Zauber einmal:  "Einaeschern aktiv oder bereit ist",
    ---                           "bereit, aber nicht aktiv",
    ---                           "Knochenschild nicht aktiv ist, in unter 3 Sek.
    ---                            auslaeuft oder weniger als 6 Stapel hat"
    ---  dieselbe Eigenschaft:     "A und B aktiv sind", "A, B oder C aktiv ist"
    ---  gerade gewirkt:           "du gerade A oder B gewirkt hast"
    ---@return string[]
    verbinde = function(conds, und, nm, selbst)
        local function frei(c)
            return type(c) == "table" and type(c[2]) == "number" and c[1] ~= "and" and c[1] ~= "or"
                and not eigen(c, selbst) and not beschwoerung(c[2])
        end
        local function reihe(teile)
            return und and liste(teile) or listeOder(teile)
        end
        local out, weg = {}, {}
        for i, c in ipairs(conds) do
            if not weg[i] then
                -- 1. Derselbe Zauber in mehreren Bedingungen.
                local gruppe = { c }
                if frei(c) and K.GRUPPE[c[1]] then
                    for j = i + 1, #conds do
                        local d = conds[j]
                        if not weg[j] and frei(d) and K.GRUPPE[d[1]] and zauber(d[2]) == zauber(c[2]) then
                            gruppe[#gruppe + 1] = d
                            weg[j] = true
                        end
                    end
                end
                local nurAdj = true
                for _, g in ipairs(gruppe) do if not K.ADJ[g[1]] then nurAdj = false end end
                if #gruppe > 1 and nurAdj then
                    -- Nur Eigenschaften: ein Verb. Das Bejahte zuerst.
                    table.sort(gruppe, function(a, b) return K.ADJ[a[1]] < K.ADJ[b[1]] end)
                    local woerter = {}
                    for _, g in ipairs(gruppe) do woerter[#woerter + 1] = L["ROT_A_" .. g[1]] end
                    local eigenschaft
                    if und and K.ADJ[gruppe[1][1]] ~= K.ADJ[gruppe[#gruppe][1]] then
                        eigenschaft = table.concat(woerter, L["ROT_BUT"])
                    else
                        eigenschaft = reihe(woerter)
                    end
                    out[#out + 1] = L["ROT_J_sg"]:format(nm(c[2]), eigenschaft)
                elseif #gruppe > 1 then
                    -- Verschiedene Aussagen: der Name einmal vorn.
                    local name = nm(c[2])
                    local aussagen = {}
                    for _, g in ipairs(gruppe) do
                        local s = say(g, false, nm, selbst)
                        local vorn = name .. " "
                        aussagen[#aussagen + 1] = (s:sub(1, #vorn) == vorn) and s:sub(#vorn + 1) or s
                    end
                    out[#out + 1] = name .. " " .. reihe(aussagen)
                elseif frei(c) and K.ADJ[c[1]] then
                    -- 2. Dieselbe Eigenschaft anderer Zauber: "A und B aktiv sind".
                    local wer = { c[2] }
                    for j = i + 1, #conds do
                        local d = conds[j]
                        if not weg[j] and frei(d) and d[1] == c[1] then
                            -- Nur, wer nicht selbst noch eine andere Aussage hat.
                            local allein = true
                            for m = j + 1, #conds do
                                local e = conds[m]
                                if not weg[m] and frei(e) and K.GRUPPE[e[1]] and zauber(e[2]) == zauber(d[2]) then allein = false end
                            end
                            if allein then
                                wer[#wer + 1] = d[2]
                                weg[j] = true
                            end
                        end
                    end
                    if #wer == 1 then
                        out[#out + 1] = say(c, false, nm, selbst)
                    else
                        local namen = {}
                        for _, id in ipairs(wer) do namen[#namen + 1] = nm(id) end
                        out[#out + 1] = L[und and "ROT_J_pl" or "ROT_J_sg"]:format(reihe(namen), L["ROT_A_" .. c[1]])
                    end
                elseif (c[1] == "surge" and not und or c[1] == "nosurge" and und) and type(c[2]) == "number" then
                    -- 4. "Daemonenwoge weder fuer A noch fuer B bereit".
                    local partner
                    for j = i + 1, #conds do
                        local d = conds[j]
                        if not partner and not weg[j] and type(d) == "table" and d[1] == c[1] and d[2] == c[2] then
                            partner = j
                        end
                    end
                    if partner then
                        weg[partner] = true
                        out[#out + 1] = L["ROT_C_" .. c[1] .. "_2"]:format(nm(c[2]), nm(c[3]), nm(conds[partner][3]))
                    else
                        out[#out + 1] = say(c, #conds == 1, nm, selbst)
                    end
                elseif frei(c) and c[1] == "prev" and not und then
                    -- 3. "du gerade A oder B gewirkt hast".
                    local namen = { nm(c[2]) }
                    for j = i + 1, #conds do
                        local d = conds[j]
                        if not weg[j] and frei(d) and d[1] == "prev" then
                            namen[#namen + 1] = nm(d[2])
                            weg[j] = true
                        end
                    end
                    out[#out + 1] = L["ROT_C_prev"]:format(listeOder(namen))
                else
                    out[#out + 1] = say(c, #conds == 1, nm, selbst)
                end
            end
        end
        return out
    end

    ---Die Bedingungen einer Zeile als ein Nebensatz.
    local function wann(line, nm)
        local selbst = line.s
        -- "Wechsle in Katzengestalt" sagt schon, dass man nicht darin ist.
        local conds = line.c or {}
        local art = selbst and namensverb(selbst)
        if (art == "form" or art == "stance") and line.a ~= "cd" then
            local ohne = {}
            for _, c in ipairs(conds) do
                if not (c[1] == "down" and eigen(c, selbst)) then ohne[#ohne + 1] = c end
            end
            conds = ohne
        end
        local parts = verbinde(conds, true, nm, selbst)
        if line.any then
            -- Ein Oder neben dem Oder der Gruppen: beide in Klammern, sonst
            -- liest sich "A oder B und (C oder D)" falsch.
            if #conds == 1 and type(conds[1]) == "table" and conds[1][1] == "or" then
                parts = { say(conds[1], false, nm, selbst) }
            end
            -- Die Einzelnen zusammen ("du gerade A oder B gewirkt hast"),
            -- danach die Gruppen.
            local einzeln, opts, gruppen = {}, {}, false
            local function glied(x)
                if type(x) == "table" and x[1] == "or" then glied(x[2]); glied(x[3]) else einzeln[#einzeln + 1] = x end
            end
            for _, g in ipairs(line.any) do
                if #g == 1 then glied(g[1]) else gruppen = true end
            end
            for _, t in ipairs(verbinde(einzeln, false, nm, selbst)) do opts[#opts + 1] = t end
            for _, g in ipairs(line.any) do
                if #g > 1 then opts[#opts + 1] = liste(verbinde(g, true, nm, selbst)) end
            end
            local oder = table.concat(opts, gruppen and L["ROT_OR_SEP"] or L["ROT_OR"])
            parts[#parts + 1] = #parts > 0 and ("(" .. oder .. ")") or oder
        end
        -- Was SimC zusaetzlich rechnet und im Spiel nicht sichtbar ist, steht
        -- nicht als Text im Satz, sondern als "≈" an seinem Ende (21. Oktober).
        return liste(parts)
    end

    ---Der ganze Satz einer Zeile, wie bei Wowhead.
    ---@param line table { s, c, any, t, keepUp }
    ---@param tab string  "st", "aoe" oder "pre"
    ---@param last boolean die letzte Zeile ohne Bedingung ist der Fueller
    ---@param nm function|nil wie ein Zauber heisst (Vorgabe: schlicht)
    -- Ein Gegenstand im Satz: Symbol und Name in Gold, wie ein Zauber.
    local function gegenstand(id, mitSymbol)
        local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
        local tex = mitSymbol and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
        return "|Hitem:" .. tostring(id) .. "|h" .. imSatz(tex) .. "|cffffd100"
            .. (type(name) == "string" and name or L["ROT_I_POTION"]) .. "|r|h"
    end
    local SCHMUCK = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01"

    ---Der Satz einer Zeile im Reiter "Traenke & Schmuck".
    local function gegenstandSatz(line, nm)
        local when = wann(line, nm)
        if line.ik == "potion" then
            local name = gegenstand(line.item, nm ~= zauber)
            local text
            if when ~= "" then text = L["ROT_I_potion_if"]:format(name, when)
            elseif line.pre then text = L["ROT_I_potion_pre"]:format(name)
            else text = L["ROT_I_potion"]:format(name) end
            if line.pre and when ~= "" then text = text .. " " .. L["ROT_I_prepot"] end
            if line.pct then
                text = text .. "  |cff" .. S:Hex("textMuted") .. L["ROT_I_measured"]:format(line.pct) .. "|r"
            end
            return text
        end
        -- Schmuck: welcher, entscheidet die Ausruestung - die Art sagt wann.
        local art = (nm ~= zauber and imSatz(SCHMUCK) or "")
            .. "|cffffd100" .. L["ROT_I_" .. line.ik .. "_name"] .. "|r"
        if when ~= "" then return L["ROT_I_use_if"]:format(art, when) end
        return L["ROT_I_use"]:format(art)
    end

    -- Nur Klares: was SimulationCraft zusaetzlich rechnet, nimmt schon der
    -- Generator heraus (tools/lib/simplify.js) - kein "unter bestimmten
    -- Umstaenden", kein Zeichen dafuer (21. Oktober).
    -- DER HEILER-GUIDE (24. Oktober): gemessen, keine Prioritaet. Was Top-
    -- Heiler wirken, wie oft, und wie sie ihre Cooldowns nutzen
    -- (tools/lib/healing.js).
    local function mmss(sek)
        sek = math.floor((tonumber(sek) or 0) + 0.5)
        return ("%d:%02d"):format(math.floor(sek / 60), sek % 60)
    end
    -- KEINE HAEUFIGKEITEN (26. Oktober): "etwa 2,3× pro Kampf" und
    -- "19× pro Minute" las niemand - ein Guide sagt, was man tut. Die
    -- Messung entscheidet, welcher Satz kommt; sie steht nicht im Text.
    local function nutzung(line, nm)
        -- Ein Gegenstand mit seinem eigenen Symbol und Namen, nicht dem des
        -- Zaubers, den er ausloest (Silbermondheiltrank, 26. Oktober).
        local name = line.item and gegenstand(line.item, true) or nm(line.s)
        -- Mana gibt man, wenn es fehlt; Schaden macht ein Heiler, wenn
        -- gerade wenig zu heilen ist.
        if line.ck == "mana" then return L["ROT_H_cd_mana"]:format(name) end
        -- Fuer einen Einzelnen in Not, wie oft auch immer gebraucht.
        if line.ck == "ext" then return L["ROT_H_cd_ext"]:format(name) end
        -- Schaden, der ueber ein Talent heilt (Tiefer Atem): wenn Heilung gefragt ist.
        if line.via then
            if line.use and line.use >= 85 then return L["ROT_H_oncd_via"]:format(name, nm(line.via)) end
            return L["ROT_H_cd_via"]:format(name, nm(line.via))
        end
        if line.use and line.use >= 85 then return L["ROT_H_cd_on"]:format(name) end
        if line.ck == "dmg" then return L["ROT_H_cd_dmg"]:format(name) end
        if line.use and line.use >= 50 then return L["ROT_H_cd_aim"]:format(name) end
        return L[line.hk == "item" and "ROT_H_item_need" or "ROT_H_cd_need"]:format(name)
    end
    local function heilSatzKern(line, roh)
        -- "Nutze Yu'lon die Jadeschlange", nicht "... beschwoeren auf Abklingzeit".
        local function nm(id)
            local _, label = beschwoerung(id)
            return roh(id, label)
        end
        local k = line.hk
        -- Mehrere in einer Zeile: die Namen als Liste.
        if (k == "dmg" or k == "dmgheal" or k == "sit" or k == "self") and line.list then
            local namen = {}
            for _, id in ipairs(line.list) do namen[#namen + 1] = nm(id) end
            -- Schaden, der ueber ein Talent heilt: das Talent nennt den Grund.
            if k == "dmgheal" and line.via then return L["ROT_H_dmgheal"]:format(nm(line.via), liste(namen)) end
            return L["ROT_H_" .. (k == "dmgheal" and "dmg" or k)]:format(liste(namen))
        end
        if k == "proc" then
            return line.from and L["ROT_H_proc"]:format(nm(line.s), nm(line.from)) or L["ROT_H_proc0"]:format(nm(line.s))
        end
        if k == "oncd" then
            -- Schaden auf Abklingzeit, der ueber ein Talent heilt (Feueratem).
            if line.via and (line.use or 0) >= 85 then return L["ROT_H_oncd_via"]:format(nm(line.s), nm(line.via)) end
            return L[(line.use or 0) >= 85 and "ROT_H_oncd" or "ROT_H_oncd_most"]:format(nm(line.s))
        end
        if k == "keep" then return L["ROT_H_keep"]:format(nm(line.s)) end
        if k == "emp" then return L["ROT_H_emp"]:format(nm(line.s)) end
        if k == "spend" then return L["ROT_H_spend"]:format(resource(line.res), nm(line.s)) end
        if k == "mana" then return L["ROT_H_mana"]:format(nm(line.s)) end
        if k == "reg" then return L["ROT_H_reg"]:format(nm(line.s)) end
        if k == "fill" then
            -- Der erste Fueller fuehrt ein, die anderen kommen mit "Oder".
            local was = line.multi == true and L["ROT_H_multi"] or (line.multi == false and L["ROT_H_single"] or nil)
            local text
            if line.teil then
                -- Je Liste: "deine haeufigste Einzelheilung", nicht die
                -- haeufigste ueberhaupt; ein Ziel oder mehrere sagt die Liste.
                if line.first then
                    text = line.hot and L["ROT_H_fill_first_hot_" .. line.teil]:format(nm(line.s), L["ROT_H_hot"])
                        or L["ROT_H_fill_first_" .. line.teil]:format(nm(line.s))
                else
                    text = line.hot and L["ROT_H_fill_hot"]:format(nm(line.s), L["ROT_H_hot"]) or L["ROT_H_fill0"]:format(nm(line.s))
                end
            elseif line.hot then
                -- Ein HoT wird verteilt (Verjuengung), nicht "gefuellt".
                text = L[line.first and "ROT_H_fill_first_hot" or "ROT_H_fill_hot"]:format(nm(line.s), L["ROT_H_hot"])
            elseif line.first then
                text = was and L["ROT_H_fill_first"]:format(nm(line.s), was) or L["ROT_H_fill_first0"]:format(nm(line.s))
            else
                text = was and L["ROT_H_fill"]:format(nm(line.s), was) or L["ROT_H_fill0"]:format(nm(line.s))
            end
            if line.cost and line.teil then
                -- Ohne "auf ein Ziel" davor: "..., guenstig im Mana" und
                -- "Oder mit X – teuer im Mana".
                text = text .. ((line.first or line.hot) and ", " or " – ") .. L["ROT_H_costw_" .. line.cost]
            elseif line.cost then
                text = text .. L["ROT_H_cost_" .. line.cost]
            end
            text = text .. "."
            return text
        end
        if k == "dmg" then return L["ROT_H_dmg"]:format(nm(line.s)) end
        if k == "sit" then return L["ROT_H_sit"]:format(nm(line.s)) end
        if k == "cd" or k == "item" then return nutzung(line, nm) end
        -- Je Boss eine Ueberschrift, darunter je Cooldown eine Zeile: als
        -- ein Satz je Boss war es eine Textwand (24. Oktober).
        if k == "bosshead" then
            local name = (line.enc and ns.Compat.EncounterName and ns.Compat.EncounterName(line.enc)) or line.name or "?"
            return L["ROT_H_bosshead"]:format(name, mmss(line.dur))
        end
        if k == "bosscd" then
            local zeiten = {}
            for _, t in ipairs(line.t or {}) do zeiten[#zeiten + 1] = mmss(t) end
            return L["ROT_H_bosscd"]:format(nm(line.s), liste(zeiten))
        end
        return ""
    end
    -- WAS ER ERSETZT (26. Oktober): "Halte Wogendes Totem durchgehend
    -- aufrecht – anstelle von Heilender Regen". Wer Heilender Regen sucht,
    -- sieht, warum er nicht dasteht.
    local function heilSatz(line, roh)
        local text = heilSatzKern(line, roh)
        if line.statt and text ~= "" then
            text = (text:gsub("%.$", "")) .. L["ROT_H_statt"]:format(roh(line.statt)) .. "."
        end
        return text
    end

    -- DAS VERB (26. Oktober): "Beschwoere Xuen den Weissen Tiger", nicht
    -- "Wirke Xuen den Weissen Tiger beschwoeren"; "Wechsle in Katzengestalt";
    -- ein grosser Cooldown "Nutze"; ein Dot, der nachlaeuft, "Erneuere".
    local function verb(line, nm)
        local art, label = namensverb(line.s)
        -- Leerengestalt ist ein grosser Cooldown, keine Gestalt zum Wechseln.
        local gestalt = art == "form" or art == "stance"
        if art and not (gestalt and line.a == "cd") then
            return L["ROT_V_" .. (K.VERB_VON[art] or art)]:format(nm(line.s, label))
        end
        -- Erneuern heisst: er laeuft schon und soll weiterlaufen. Ein Buff,
        -- der aktiv sein MUSS, um ihn zu wirken (Hammer des Lichts), wird
        -- nicht erneuert, sondern ausgeloest.
        local erneuern, aktiv = false, false
        for _, c in ipairs(line.c or {}) do
            if K.ERNEUERN[c[1]] and eigen(c, line.s) then erneuern = true end
            if c[1] == "up" and eigen(c, line.s) then aktiv = true end
        end
        if erneuern and not aktiv then return L["ROT_V_renew"]:format(nm(line.s)) end
        if line.a == "cd" then return L["ROT_V_use"]:format(nm(line.s)) end
        return L["ROT_V_cast"]:format(nm(line.s))
    end

    -- OHNE BEDINGUNG, je nach Zauber (26. Oktober): ein grosser Cooldown
    -- "auf Abklingzeit", Aufladungen "bevor sie voll sind", ein Verbraucher
    -- "sobald du genug Zorn hast" - nicht zwoelfmal "sobald verfuegbar".

    local function satz(line, tab, last, nm)
        nm = nm or zauber
        if line.hk then return heilSatz(line, nm) end
        if line.ik and line.ik ~= "racial" then return gegenstandSatz(line, nm) end
        if line.keepUp then return L["ROT_S_keep"]:format(nm(line.s)) end
        local when = wann(line, nm)
        local ziel
        if line.t then
            local k = tostring(line.t[1])
            if zauber(line.t[2]) == zauber(line.s) and L["ROT_TS_" .. k] ~= "ROT_TS_" .. k then
                ziel = L["ROT_TS_" .. k]
            else
                ziel = L["ROT_T_" .. k]:format(nm(line.t[2]))
            end
        end
        -- Ein Fueller hat keine Abklingzeit: Feuerbrandaura am Ende der Liste
        -- ist "bevor die Aufladungen voll sind", keine Luecke (26. Oktober).
        -- Ein Verbraucher am Ende (Todesstoss) fuellt keine Luecken: er
        -- kommt, sobald die Ressource reicht.
        if last and not ziel and when == "" and (tab == "st" or tab == "aoe") and not K.OHNE[line.a]
            and not (line.a == "r" and line.r) then
            return L["ROT_S_filler"]:format(nm(line.s))
        end
        local v = verb(line, nm)
        if ziel and when ~= "" then return L["ROT_S_target_if"]:format(v, ziel, when) end
        if ziel then return L["ROT_S_target"]:format(v, ziel) end
        if when ~= "" then return L["ROT_S_if"]:format(v, when) end
        if tab == "pre" then return L["ROT_S_pre"]:format(v) end
        if K.OHNE[line.a] then return L[K.OHNE[line.a]]:format(v) end
        if line.a == "r" and line.r then return L["ROT_S_res"]:format(v, resource(line.r)) end
        return L["ROT_S_cd"]:format(v)
    end
    UI.RotationSentence = satz

    -- Die Reiter, in der Reihenfolge wie bei Wowhead.
    local TABS = { "st", "aoe", "pre", "items" }
    -- EINZEL- UND GRUPPENHEILUNG (26. Oktober): wen ein Zauber heilt, sagt
    -- sein Text; wann Top-Heiler ihn druecken, messen die Logs nicht - jede
    -- Liste behaelt die gemessene Reihenfolge.
    local HEAL_TABS = { "single", "group", "cds", "bosses", "items" }
    -- Alle Knoepfe einer Karte, in Anzeigereihenfolge; gezeigt werden die
    -- der Art (Schaden/Tank oder Heiler).
    local ALL_TABS = { "st", "aoe", "pre", "single", "group", "cds", "bosses", "items" }
    local function reiterVon(r) return (r and r.heal) and HEAL_TABS or TABS end
    local function hatReiter(r, key)
        for _, k in ipairs(reiterVon(r)) do if k == key then return true end end
        return false
    end

    ---Die Zeilen eines Reiters beim Heiler.
    -- EINE ZEILE FUER VIELE (26. Oktober): "Zwischendurch fuer Schaden:
    -- Leerenschlag, Gedankenschlag und Heilige Pein" statt dreimal
    -- "Zwischendurch X fuer Schaden"; ebenso, was je nach Lage kommt.
    local SAMMELN = { dmg = true, dmgheal = true, sit = true, self = true }
    local function sammeln(out, zeile)
        local vorige = out[#out]
        if vorige and vorige.hk == zeile.hk and SAMMELN[zeile.hk] and vorige.via == zeile.via then
            vorige.list[#vorige.list + 1] = zeile.s
            return
        end
        if SAMMELN[zeile.hk] then
            zeile.list = { zeile.s }
        end
        out[#out + 1] = zeile
    end
    local function heilZeilen(r, tab)
        local out = {}
        if tab == "core" or tab == "single" or tab == "group" then
            -- Was niemanden selbst heilt (Donnerfokustee, Schaden, Mana,
            -- Werkzeuge), steht in beiden Listen.
            local teil = tab ~= "core" and tab or nil
            local erster = true
            for _, x in ipairs(r.prio or {}) do
                if not teil or x.multi == nil or (x.multi == true) == (teil == "group") then
                    local first = x.first
                    if teil and x.k == "fill" then first = erster or nil; erster = false end
                    sammeln(out, { hk = x.k, s = x.s, via = x.via, pct = x.pct, cpm = x.cpm, use = x.use, from = x.from, res = x.res,
                        first = first, multi = x.multi, hot = x.hot, cost = x.cost, m = r.m, teil = teil, statt = x.statt })
                end
            end
        elseif tab == "cds" then
            -- Werkzeuge (Spurt, Massenbannung) sind keine Heil-Cooldowns:
            -- eine Zeile am Ende.
            for _, x in ipairs(r.cds or {}) do
                if x.k == "tool" then
                    sammeln(out, { hk = "sit", s = x.s, m = r.m })
                elseif x.k == "self" then
                    -- Der eigene Schutz: eine Zeile (Baumrinde, Goettlicher Schutz).
                    sammeln(out, { hk = "self", s = x.s, m = r.m })
                else
                    out[#out + 1] = { hk = "cd", s = x.s, pct = x.pct, per = x.per, use = x.use, m = r.m, ck = x.k, via = x.via }
                end
            end
        elseif tab == "bosses" then
            for _, b in ipairs(r.bosses or {}) do
                out[#out + 1] = { hk = "bosshead", name = b.name, enc = b.enc, dur = b.dur }
                for _, c in ipairs(b.cds or {}) do out[#out + 1] = { hk = "bosscd", s = c.s, t = c.t } end
            end
        elseif tab == "items" then
            for _, x in ipairs(r.items or {}) do
                if x.item and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, x.item) end
                out[#out + 1] = { hk = "item", s = x.s, item = x.item, pct = x.pct, per = x.per, use = x.use, m = r.m }
            end
        end
        return out
    end

    ---Die Zeilen eines Reiters.
    local function zeilenVon(r, tab)
        if r and r.heal then return heilZeilen(r, tab) end
        -- Traenke & Schmuck: der gemessene Trank, die beiden Arten Schmuck,
        -- und die Volksfaehigkeit, die dieser Charakter kennt.
        if tab == "items" then
            local it, out = r.items or {}, {}
            if it.potion then
                -- Den Namen anfordern, falls der Client ihn noch nicht kennt.
                if it.potion.item and C_Item and C_Item.RequestLoadItemDataByID then
                    pcall(C_Item.RequestLoadItemDataByID, it.potion.item)
                end
                out[#out + 1] = { ik = "potion", item = it.potion.item, pct = it.potion.pct,
                    pre = it.potion.pre, c = it.potion.c }
            end
            if it.buff then out[#out + 1] = { ik = "buff", c = it.buff.c } end
            if it.dmg then out[#out + 1] = { ik = "dmg", c = it.dmg.c } end
            for _, v in ipairs(it.racial or {}) do
                local kennt
                for _, id in ipairs(v.s or {}) do
                    if IsPlayerSpell and IsPlayerSpell(id) then kennt = id end
                end
                if kennt then out[#out + 1] = { ik = "racial", s = kennt, c = v.c } end
            end
            return out
        end
        if tab == "pre" then
            local pre = {}
            for _, id in ipairs(r.keep or {}) do pre[#pre + 1] = { s = id, keepUp = true } end
            -- Zweimal Zorn vor dem Pull ist eine Zeile, nicht zwei gleiche.
            for _, line in ipairs(r.pre or {}) do
                local vorher = pre[#pre]
                if not (vorher and vorher.s == line.s and not vorher.c and not line.c) then pre[#pre + 1] = line end
            end
            return pre
        end
        -- "Wechsle in Baerengestalt, wann immer es geht": eine Gestalt ohne
        -- jede Bedingung ist keine Zeile der Prioritaet (der Waechter steht
        -- ohnehin darin; 26. Oktober).
        local out = {}
        for _, line in ipairs(r[tab] or {}) do
            local art = line.s and namensverb(line.s)
            local leer = (art == "form" or art == "stance") and line.a ~= "cd" and not line.any and not line.t
            if leer then
                for _, c in ipairs(line.c or {}) do
                    if not (c[1] == "down" and eigen(c, line.s)) then leer = false end
                end
            end
            if not leer then out[#out + 1] = line end
        end
        return out
    end
    UI.RotationLines = zeilenVon

    ---Welcher Reiter offen ist. Einer ohne Zeilen wird nicht gezeigt.
    function UI.RotationTab(r)
        local tab = MetaCodexDB and MetaCodexDB.rotationTab or "st"
        if r and (not hatReiter(r, tab) or #zeilenVon(r, tab) == 0) then
            for _, t in ipairs(reiterVon(r)) do if #zeilenVon(r, t) > 0 then return t end end
        end
        return tab
    end

    ---Der Beispiel-Ablauf: vor dem Pull aus der Liste, danach gemessen.
    ---
    ---Was vor dem Pull gewirkt wird, sagt SimulationCraft. Was danach kommt,
    ---sagt es nicht - das kaeme aus den Logs (r.opener). KEIN PLATZHALTER
    ---(20. Oktober): die ersten Zeilen der Prioritaet sind keine Reihenfolge,
    ---und als Ablauf gelesen stand Sturmhueter zweimal und Flammenschock
    ---doppelt da. Ohne Messung endet der Ablauf am Pull.
    ---@return table vor, table nach
    function UI.RotationTimeline(r)
        local vor = {}
        for _, line in ipairs(zeilenVon(r, "pre")) do vor[#vor + 1] = line.s end
        local o = r.opener
        if type(o) == "table" and type(o.post) == "table" and #o.post > 0 then
            -- Davor: die Vorkampf-Liste - Schild und Waffe wirkt man lange vor
            -- dem Pull, das steht in keinem Log -, und dahinter, an der Marke,
            -- jeder gemessene Precast, der dort noch fehlt.
            local schon = {}
            for _, id in ipairs(vor) do schon[id] = true end
            for _, id in ipairs(type(o.pre) == "table" and o.pre or {}) do
                if not schon[id] then vor[#vor + 1] = id; schon[id] = true end
            end
            return vor, o.post
        end
        return vor, {}
    end

    ---EINE Zeile fuer den ganzen Abschnitt: die Karte (20. Oktober). Als
    ---Liste stand jeder Zauber auf zwei Zeilen untereinander, und man musste
    ---scrollen; die Rotation will man auf einen Blick.
    ---WELCHER HELDENBAUM (20. Oktober, wie Wowheads Schalter): gewaehlt, sonst
    ---der eigene aktive, wenn man diese Spec spielt, sonst der meistgespielte.
    ---@return table variant  die Rotation dieses Heldenbaums
    function UI.RotationVariant(specID, r)
        if not r or type(r.heroes) ~= "table" or #r.heroes == 0 then return r end
        local function finde(id)
            for _, v in ipairs(r.heroes) do if v.hero == id then return v end end
        end
        local gewaehlt = MetaCodexDB and MetaCodexDB.rotationHero and MetaCodexDB.rotationHero[specID]
        if gewaehlt and finde(gewaehlt) then return finde(gewaehlt) end
        local eigene = ns.Compat and ns.Compat.ActiveSpecID and ns.Compat.ActiveSpecID()
        if eigene == specID and C_ClassTalents and C_ClassTalents.GetActiveHeroTalentSpec then
            local ok, aktiv = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
            if ok and aktiv and finde(aktiv) then return finde(aktiv) end
        end
        return r.heroes[1]
    end

    function UI.RotationRows(specID, mode)
        local r = ns.Recommend.Rotation(specID, mode)
        if not r then return {} end
        return { { kind = "rotpanel", rot = r, spec = specID } }
    end

    function UI.RotationHint(specID, mode)
        local alle = ns.Recommend.Rotation(specID, mode) or {}
        local r = UI.RotationVariant(specID, ns.Recommend.Rotation(specID, mode))
        if not r then return "" end
        if r.heal then
            local text = L["ROT_H_HINT"]:format(r.n or 0)
            -- Fuer welchen Heldenbaum: die Messung ist nur seine (24. Oktober).
            local held = r.hero and ns.Catalog.SubTreeName and ns.Catalog.SubTreeName(r.hero)
            if held then text = L["ROT_H_HINT_HERO"]:format(held) .. "  " .. text end
            -- Zeitpunkte gibt es nur im Raid: ein Key hat viele Pulls.
            -- Nur, wo es Bosszeiten gibt: ohne sie stand der Satz im Raid
            -- ueber einer Karte ohne einen einzigen Zeitpunkt (26. Oktober).
            if r.bosses and #r.bosses > 0 then text = text .. " " .. L["ROT_H_HINT_TIMES"] end
            -- Zu wenige Spieler in dieser Stufe: alle Stufen zusammen, und das steht da.
            if r.alle or alle.alle then text = text .. " " .. L["ROT_ALL_LEVELS"] end
            if ns.version == "dev" then text = "|cffD29922DEV-Vorschau.|r  " .. text
            else text = "|cffD29922" .. L["ROT_BETA"] .. "|r  " .. text end
            return text
        end
        local held = r.hero and ns.Catalog.SubTreeName and ns.Catalog.SubTreeName(r.hero) or "?"
        local text = L["ROT_HINT"]:format(held, r.n or 0) .. "  " .. L["ROT_NO_TRINKET"]
        if r.set then text = text .. "  " .. L["ROT_SET"] end
        if r.alleZiele then text = text .. "  " .. L["ROT_ALL_TARGETS"] end
        if alle.alle then text = text .. "  " .. L["ROT_ALL_LEVELS"] end
        -- Neu und noch nicht in jeder Zeile geprueft: das steht da.
        if ns.version == "dev" then text = "|cffD29922DEV-Vorschau.|r  " .. text
        else text = "|cffD29922" .. L["ROT_BETA"] .. "|r  " .. text end
        return text
    end

    -- Die Karte: je Zeile der Liste gebaut, wenn sie gebraucht wird, und
    -- beim Zuruecksetzen der Zeile versteckt - wie die anderen Karten.
    local panelOf = setmetatable({}, { __mode = "k" })
    local PAD, TAB_H, TL_ICON, TL_STEP = 18, 30, 40, 56
    -- Das Raster der Prioritaet: Einzug der Nummer und des Satzes, Abstand
    -- zwischen zwei Punkten, Zeilenabstand innerhalb eines Satzes.
    local NR_W, TEXT_X, GAP, LEADING = 30, 40, 10, 4

    local function linie(f)
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        t:SetVertexColor(S:Color("borderSubtle"))
        t:SetHeight(S:Pixel(1))
        return t
    end

    -- Eine Ueberschrift wie bei Wowhead: Wort in der Mitte, Linien links
    -- und rechts.
    local function ueberschrift(f)
        local h = { text = S:Text(f, "display", "accent"), links = linie(f), rechts = linie(f) }
        return h
    end

    -- IN DER FARBE DER KLASSE (26. Oktober): die Ueberschriften der Karte
    -- tragen die Farbe der gezeigten Spec, nicht die eigene - Elementar ist
    -- blau, auch wenn ein Druide nachschlaegt.
    local klassenFarbe
    local function setzeUeberschrift(h, text, y, innen)
        if klassenFarbe then
            h.text:SetTextColor(klassenFarbe.r, klassenFarbe.g, klassenFarbe.b)
        end
        h.text:ClearAllPoints()
        h.text:SetPoint("TOP", h.text:GetParent(), "TOP", 0, -y)
        h.text:SetText(upperText(text))
        local tw = tonumber(h.text:GetStringWidth()) or 80
        local seite = math.max(0, (innen - tw) / 2 - 14)
        h.links:ClearAllPoints()
        h.links:SetPoint("TOPLEFT", PAD, -(y + 12))
        h.links:SetWidth(seite)
        h.rechts:ClearAllPoints()
        h.rechts:SetPoint("TOPRIGHT", -PAD, -(y + 12))
        h.rechts:SetWidth(seite)
        for _, t in pairs(h) do t:Show() end
    end

    local function zeigeUeberschrift(h, an)
        for _, t in pairs(h) do t:SetShown(an) end
    end

    -- Ein Feld mit Zauber-Tooltip: Symbol der Zeitleiste oder Satz.
    local function tooltipAn(frame)
        frame:SetScript("OnEnter", function(self)
            if self.hl then self.hl:SetAlpha(1) end
            local d = rawget(self, "rotData")
            if not d or not (d.spell or d.item) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if d.item then
                if GameTooltip.SetItemByID then GameTooltip:SetItemByID(d.item) end
            elseif GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(d.spell)
            else
                GameTooltip:SetHyperlink("spell:" .. d.spell)
            end
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function(self)
            if self.hl then self.hl:SetAlpha(0) end
            GameTooltip:Hide()
        end)
        -- Die Namen im Satz: ueber einem Namen sein Tooltip, daneben wieder
        -- der der Zeile.
        if type(frame.SetHyperlinksEnabled) == "function" then frame:SetHyperlinksEnabled(true) end
        frame:SetScript("OnHyperlinkEnter", function(self, link)
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end)
        frame:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
    end

    local function eintrag(f, i)
        if f.entries[i] then return f.entries[i] end
        local e = CreateFrame("Button", nil, f)
        e.hl = S:Fill(e, "bgHover", 0)
        e.nr = S:Text(e, "title", "textPrimary")
        e.nr:SetPoint("TOPRIGHT", e, "TOPLEFT", NR_W, 0)
        e.nr:SetJustifyH("RIGHT")
        e.text = S:Text(e, "title", "textPrimary")
        e.text:SetPoint("TOPLEFT", TEXT_X, 0)
        e.text:SetJustifyH("LEFT")
        e.text:SetWordWrap(true)
        if e.text.SetSpacing then e.text:SetSpacing(LEADING) end
        tooltipAn(e)
        -- KEIN TOOLTIP FUER DIE GANZE ZEILE (20. Oktober): er zeigte den
        -- gewirkten Zauber, egal ueber welchem Namen der Zeiger stand. Die
        -- Zeile wird nur hinterlegt; ihre Namen haben jeder ihren eigenen.
        e:SetScript("OnEnter", function(self) self.hl:SetAlpha(1) end)
        f.entries[i] = e
        return e
    end

    local function zeitIcon(f, i)
        if f.tl.icons[i] then return f.tl.icons[i] end
        local b = CreateFrame("Button", nil, f)
        b:SetSize(TL_ICON, TL_ICON)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        S:Border(b, "borderStrong")
        tooltipAn(b)
        f.tl.icons[i] = b
        return b
    end

    -- REITER UND SCHALTER WIE IN EINER APP (27. Oktober). Vorher waren
    -- beide gleiche graue Kaesten, der offene nur eine Nuance heller, und
    -- zwei Zeilen davon sahen aus wie ein Formular. Jetzt: die Reiter sind
    -- Text, der offene mit einem Strich in der Klassenfarbe darunter -
    -- ohne Grundlinie, denn gleich darunter zieht die Ueberschrift ihre
    -- eigenen Linien; der Heldenbaum ist ein Dropdown rechts in derselben
    -- Zeile. Eine eigene Zeile dafuer (erst Knoepfe, dann ein
    -- Segment-Schalter) war zu viel Gewicht fuer eine Wahl, die die
    -- meisten nie aendern.
    --
    -- In EINER Tabelle: die Datei steht an Luas Grenze von 200 lokalen
    -- Namen, und die neuen Funktionen hier haben sie gerissen.
    local Knopf = { DROP_H = 26 }

    function Knopf.farbeAktiv()
        if klassenFarbe then return klassenFarbe.r, klassenFarbe.g, klassenFarbe.b end
        return S:Color("accent")
    end

    function Knopf.reiter(f, key, onClick)
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(TAB_H)
        b.key = key
        b.label = S:Text(b, "title", "textSecondary")
        b.label:SetPoint("CENTER", 0, 1)
        b.strich = b:CreateTexture(nil, "ARTWORK")
        b.strich:SetTexture("Interface\\Buttons\\WHITE8X8")
        b.strich:SetPoint("BOTTOMLEFT")
        b.strich:SetPoint("BOTTOMRIGHT")
        b.strich:SetHeight(S:Pixel(2))
        b.strich:Hide()
        b:SetScript("OnEnter", function(self) S:Recolor(self.label, "textPrimary") end)
        b:SetScript("OnLeave", function(self)
            S:Recolor(self.label, self.__active and "textPrimary" or "textSecondary")
        end)
        b:SetScript("OnClick", onClick)
        return b
    end

    function Knopf.reiterAktiv(b, aktiv)
        b.__active = aktiv and true or false
        S:Recolor(b.label, aktiv and "textPrimary" or "textSecondary")
        b.strich:SetVertexColor(Knopf.farbeAktiv())
        b.strich:SetShown(aktiv and true or false)
    end

    function Knopf.heldName(v)
        return v.hero and ns.Catalog.SubTreeName and ns.Catalog.SubTreeName(v.hero) or "?"
    end

    ---Das Menue des Dropdowns: jeder Baum mit Anteil, der gezeigte markiert.
    function Knopf.heldMenue(b)
        local varianten, spec = b.varianten or {}, b.spec
        local function waehle(hero)
            MetaCodexDB.rotationHero = MetaCodexDB.rotationHero or {}
            MetaCodexDB.rotationHero[spec] = hero
            UI.Refresh()
        end
        -- Ohne Menue-API: zum naechsten Baum weiterschalten.
        if not (MenuUtil and MenuUtil.CreateContextMenu) then
            for i, v in ipairs(varianten) do
                if v.hero == b.hero then waehle(varianten[i % #varianten + 1].hero) return end
            end
            return
        end
        MenuUtil.CreateContextMenu(b, function(_, root)
            root:CreateTitle(L["LBL_HERO"])
            for _, v in ipairs(varianten) do
                local text = v.pct and L["HERO_ENTRY"]:format(Knopf.heldName(v), tonumber(v.pct) or 0)
                    or Knopf.heldName(v)
                root:CreateRadio(text, function(hero) return hero == b.hero end, waehle, v.hero)
            end
        end)
    end

    function Knopf.heldWahl(f)
        local b = CreateFrame("Button", nil, f)
        b:SetHeight(Knopf.DROP_H)
        b.bg = S:Fill(b, "bgOverlay")
        S:Border(b, "borderSubtle")
        b.label = S:Text(b, "body", "textPrimary")
        b.label:SetPoint("CENTER")
        -- KEIN PFEIL (27. Oktober): die Knoepfe oben fuer Spec und
        -- Aktivitaet oeffnen auch ein Menue und haben keinen. Einer hier
        -- allein - erst Blizzards Grafik, zu klein, dann zwei gezeichnete
        -- Striche, pixelig - passte zu nichts.
        b:SetScript("OnEnter", function(self) self.bg:SetVertexColor(S:Color("bgHover")) end)
        b:SetScript("OnLeave", function(self) self.bg:SetVertexColor(S:Color("bgOverlay")) end)
        b:SetScript("OnClick", Knopf.heldMenue)
        return b
    end

    local function bauen(row)
        if panelOf[row] then return panelOf[row] end
        local f = CreateFrame("Frame", nil, row)
        S:Fill(f, "bgRaised")
        S:Border(f, "borderSubtle")
        f.tabs = {}
        for i, key in ipairs(ALL_TABS) do
            f.tabs[i] = Knopf.reiter(f, key, function()
                MetaCodexDB.rotationTab = key
                UI.Refresh()
            end)
        end
        f.heroPick = Knopf.heldWahl(f)
        f.headTl = ueberschrift(f)
        f.headPrio = ueberschrift(f)
        f.tl = { icons = {} }
        f.tl.track = f:CreateTexture(nil, "BORDER")
        f.tl.track:SetTexture("Interface\\Buttons\\WHITE8X8")
        f.tl.track:SetVertexColor(S:Color("borderSubtle"))
        f.tl.track:SetHeight(6)
        f.tl.pull = f:CreateTexture(nil, "ARTWORK")
        f.tl.pull:SetTexture("Interface\\Buttons\\WHITE8X8")
        f.tl.pull:SetVertexColor(S:Color("textSecondary"))
        f.tl.pull:SetSize(3, TL_ICON + 4)
        f.tl.pullText = S:Text(f, "title", "textPrimary")
        f.tl.endText = S:Text(f, "body", "textSecondary")
        f.tl.endText:SetJustifyH("CENTER")
        f.tl.endText:SetWordWrap(true)
        f.tl.note = S:Text(f, "body", "textMuted")
        f.entries = {}
        -- IN BEWEGUNG: eine eigene Karte mit Ueberschrift und Akzentstreifen.
        -- Als Satz unter einer Linie wirkte er wie ein vergessener Rest
        -- (20. Oktober).
        f.move = CreateFrame("Frame", nil, f)
        tooltipAn(f.move)
        S:Fill(f.move, "bgOverlay")
        f.move.stripe = f.move:CreateTexture(nil, "ARTWORK")
        f.move.stripe:SetTexture("Interface\\Buttons\\WHITE8X8")
        f.move.stripe:SetVertexColor(S:Color("accent"))
        f.move.stripe:SetPoint("TOPLEFT")
        f.move.stripe:SetPoint("BOTTOMLEFT")
        f.move.stripe:SetWidth(S:Pixel(3))
        f.move.title = S:Text(f.move, "caption", "accent")
        f.foot = S:Text(f.move, "title", "textPrimary")
        f.foot:SetJustifyH("LEFT")
        f.foot:SetWordWrap(true)
        if f.foot.SetSpacing then f.foot:SetSpacing(LEADING) end
        panelOf[row] = f
        return f
    end

    function UI.RotationPanelHide(row)
        if panelOf[row] then panelOf[row]:Hide() end
    end

    ---Die Zeitleiste zeichnen; gibt die neue Hoehe zurueck.
    local function zeitleiste(f, r, y, innen)
        local vor, nach = UI.RotationTimeline(r)
        local tl = f.tl
        local alle = {}
        for _, id in ipairs(vor) do alle[#alle + 1] = id end
        for _, id in ipairs(nach) do alle[#alle + 1] = id end
        if #alle == 0 then
            zeigeUeberschrift(f.headTl, false)
            for _, b in ipairs(tl.icons) do b:Hide() end
            for _, k in ipairs({ "track", "pull", "pullText", "endText", "note" }) do tl[k]:Hide() end
            return y
        end
        setzeUeberschrift(f.headTl, L["ROT_TIMELINE"], y, innen)
        y = y + 40
        -- Die Pull-Marke steht zwischen dem letzten Zauber davor und dem
        -- ersten danach.
        -- Ohne Messung danach: Platz fuer "weiter nach Prioritaet" rechts der Marke.
        local breite = #alle * TL_STEP + 12 + (#nach == 0 and 150 or 0)
        local x0 = PAD + math.max(0, (innen - breite) / 2)
        tl.pullText:ClearAllPoints()
        tl.pullText:SetText(L["ROT_PULL"])
        local iconY = y + 24
        tl.track:ClearAllPoints()
        tl.track:SetPoint("TOPLEFT", x0 - 10, -(iconY + TL_ICON / 2 - 3))
        tl.track:SetWidth(breite + 8)
        tl.track:Show()
        local x = x0
        for i, id in ipairs(alle) do
            if i == #vor + 1 then
                tl.pull:ClearAllPoints()
                tl.pull:SetPoint("TOPLEFT", x - 2, -(iconY - 2))
                tl.pullText:SetPoint("BOTTOM", tl.pull, "TOP", 0, 3)
                x = x + 12
            end
            local b = zeitIcon(f, i)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", x, -iconY)
            b.icon:SetTexture(symbol(id) or "Interface\\Icons\\INV_Misc_QuestionMark")
            b.rotData = { spell = id }
            b:Show()
            x = x + TL_STEP
        end
        for i = #alle + 1, #tl.icons do tl.icons[i]:Hide() end
        -- Alles vor dem Pull: die Marke steht hinter dem letzten.
        if #vor == #alle then
            tl.pull:ClearAllPoints()
            tl.pull:SetPoint("TOPLEFT", x - 2, -(iconY - 2))
            tl.pullText:SetPoint("BOTTOM", tl.pull, "TOP", 0, 3)
        end
        tl.pull:Show()
        tl.pullText:Show()
        -- Weiter mit der Prioritaet: unter dem letzten gemessenen Zauber,
        -- ohne Messung gleich rechts neben der Pull-Marke.
        tl.endText:ClearAllPoints()
        if #nach > 0 then
            tl.endText:SetPoint("TOP", tl.icons[#alle], "BOTTOM", 0, -6)
            tl.endText:SetWidth(TL_STEP + 40)
            tl.endText:SetJustifyH("CENTER")
            tl.endText:SetText(r.heal and L["ROT_H_CONTINUE"] or L["ROT_CONTINUE"])
            tl.endText:Show()
            y = iconY + TL_ICON + 6 + (tonumber(tl.endText:GetStringHeight()) or 28)
        else
            tl.endText:SetPoint("LEFT", tl.pull, "RIGHT", 12, 0)
            tl.endText:SetWidth(150)
            tl.endText:SetJustifyH("LEFT")
            tl.endText:SetText(r.heal and L["ROT_H_CONTINUE"] or L["ROT_CONTINUE"])
            tl.endText:Show()
            y = iconY + TL_ICON
        end
        -- Woher der Ablauf kommt, unter ihm.
        local o = r.opener
        if #nach > 0 and type(o) == "table" and o.n then
            tl.note:ClearAllPoints()
            tl.note:SetPoint("TOP", f, "TOP", 0, -(y + 8))
            tl.note:SetText(L["ROT_TIMELINE_FROM"]:format(o.n))
            tl.note:Show()
            y = y + 8 + (tonumber(tl.note:GetStringHeight()) or 14)
        else
            tl.note:Hide()
        end
        return y + 18
    end

    ---Fuellt die Karte und sagt, wie hoch sie ist (data.panelH, ohne Schriftfaktor).
    function UI.RotationPanelFill(row, data)
        local alle = data.rot
        local r = UI.RotationVariant(data.spec, alle)
        local f = bauen(row)
        local _, klasse = ns.Compat.ClassOfSpec(data.spec)
        klassenFarbe = klasse and RAID_CLASS_COLORS and RAID_CLASS_COLORS[klasse] or nil
        local fs = S.fontScale or 1
        local w = math.max(240, contentWidth() - S.space.sm * 2)
        local innen = w - PAD * 2
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", S.space.sm, -S.space.sm)
        f:SetPoint("BOTTOMRIGHT", -S.space.sm, S.space.sm)

        -- Die Reiter.
        local tab = UI.RotationTab(r)
        local tabY = PAD
        local x = PAD
        for _, b in ipairs(f.tabs) do
            local n = hatReiter(r, b.key) and #zeilenVon(r, b.key) or 0
            -- Ab wie vielen Zielen die AoE-Liste gilt: aus SimCs eigener Liste.
            if b.key == "aoe" and tonumber(r.aoeAb) then
                b.label:SetText(L["ROT_TAB_aoe_n"]:format(tonumber(r.aoeAb)))
            elseif b.key == "st" and r.alleZiele then
                -- Eine Liste fuer ein und viele Ziele (Braumeister).
                b.label:SetText(L["ROT_TAB_st_all"])
            else
                b.label:SetText(L["ROT_TAB_" .. b.key])
            end
            local bw = (tonumber(b.label:GetStringWidth()) or 80) + 28
            b:SetWidth(bw)
            b.x = x
            b:SetShown(n > 0)
            Knopf.reiterAktiv(b, b.key == tab)
            if n > 0 then x = x + bw + 4 end
        end

        -- Der Heldenbaum: ein Dropdown rechts in der Reiterzeile, nur wo
        -- mehr als ein Baum gemessen ist. Der Anteil steht gedaempft hinter
        -- dem Namen - er erklaert, er ist nicht der Name.
        local varianten = (type(alle.heroes) == "table" and #alle.heroes > 1) and alle.heroes or {}
        local wahl = f.heroPick
        if #varianten > 0 then
            wahl.varianten, wahl.hero, wahl.spec = varianten, r.hero, data.spec
            wahl.label:SetText(r.pct and (Knopf.heldName(r) .. "   |cff" .. S:Hex("textMuted")
                .. r.pct .. " %|r") or Knopf.heldName(r))
            local dw = (tonumber(wahl.label:GetStringWidth()) or 100) + 32
            wahl:SetWidth(dw)
            wahl:ClearAllPoints()
            -- Passt er nicht neben die Reiter, steht er rechts ueber ihnen.
            if x - 4 + 24 > w - PAD - dw then
                wahl:SetPoint("TOPRIGHT", -PAD, -PAD)
                tabY = PAD + Knopf.DROP_H + 10
            else
                wahl:SetPoint("TOPRIGHT", -PAD, -(tabY + (TAB_H - Knopf.DROP_H) / 2))
            end
            wahl:Show()
        else
            wahl:Hide()
        end
        for _, b in ipairs(f.tabs) do
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", b.x, -tabY)
        end
        local y = tabY + TAB_H + 22

        -- Der Beispiel-Ablauf, nur beim Einzelziel - wie bei Wowhead.
        if tab == "st" or tab == "core" or tab == "single" then
            y = zeitleiste(f, r, y, innen)
        else
            zeitleiste(f, { st = {} }, y, innen)
        end

        -- Die Prioritaet.
        local kopf = r.heal and L["ROT_H_HEAD_" .. tab]
            or ((tab == "pre" or tab == "items") and L["ROT_TAB_" .. tab] or L["ROT_PRIORITY"])
        setzeUeberschrift(f.headPrio, kopf, y, innen)
        y = y + 24 + 16
        local lines = zeilenVon(r, tab)
        local nr = 0
        local satzW = innen - TEXT_X
        for i, line in ipairs(lines) do
            local e = eintrag(f, i)
            e:ClearAllPoints()
            e:SetPoint("TOPLEFT", PAD, -y)
            e:SetWidth(innen)
            nr = nr + 1
            -- Beim Heiler keine Rangfolge: nach Haeufigkeit, nicht Prioritaet.
            -- Eine Boss-Ueberschrift steht ohne Punkt am linken Rand, mit
            -- Luft zum Boss davor.
            local kopfzeile = line.hk == "bosshead"
            if kopfzeile and i > 1 then
                y = y + 8
                e:ClearAllPoints()
                e:SetPoint("TOPLEFT", PAD, -y)
            end
            -- Die Prioritaet des Heilers ist eine Rangfolge: Nummern. Die
            -- anderen Reiter sind Listen: Punkte.
            local nummer = not r.heal or tab == "core" or tab == "single" or tab == "group"
            e.nr:SetText(kopfzeile and "" or (nummer and ("|cffffd100" .. nr .. ".|r") or "|cffffd100•|r"))
            e.text:ClearAllPoints()
            e.text:SetPoint("TOPLEFT", kopfzeile and 0 or TEXT_X, 0)
            e.text:SetWidth(kopfzeile and innen or satzW)
            local letzte = i == #lines and not line.c and not line.any and not line.t
            e.text:SetText(satz(line, tab, letzte, gold))
            local h = math.ceil(tonumber(e.text:GetStringHeight()) or 16)
            e:SetHeight(h)
            e.rotData = { spell = line.s, item = line.item, line = line, tab = tab, nr = nr }
            e:Show()
            y = y + h + GAP
        end
        for i = #lines + 1, #f.entries do f.entries[i]:Hide() end

        -- In Bewegung: die Karte unter der Prioritaet.
        local mv = {}
        if tab == "st" or tab == "aoe" then
            for _, id in ipairs(r.mv or {}) do mv[#mv + 1] = gold(id) end
        end
        if #mv > 0 then
            local INNEN = 14
            f.move.title:ClearAllPoints()
            f.move.title:SetPoint("TOPLEFT", INNEN, -10)
            f.move.title:SetText(upperText(L["ROT_MOVE_TITLE"]))
            local titelH = math.ceil(tonumber(f.move.title:GetStringHeight()) or 12)
            f.foot:ClearAllPoints()
            f.foot:SetPoint("TOPLEFT", INNEN, -(10 + titelH + 6))
            f.foot:SetWidth(innen - INNEN * 2)
            f.foot:SetText(L["ROT_S_move"]:format(liste(mv)))
            f.foot:Show()
            local h = 10 + titelH + 6 + math.ceil(tonumber(f.foot:GetStringHeight()) or 16) + 12
            f.move:ClearAllPoints()
            f.move:SetPoint("TOPLEFT", PAD, -(y + 4))
            f.move:SetSize(innen, h)
            f.move:Show()
            y = y + 4 + h + GAP
        else
            f.move:Hide()
        end
        f:Show()
        row.__rotPanel = f
        data.panelH = (y - GAP + PAD) / fs
        return f
    end
end

-- DER ABSCHNITT "GRUPPEN & SPECS" (20. und 23. Oktober).
--
-- Wer mit wem spielt, je Aktivitaet so weit, wie die Quelle es weiss:
-- in M+ die haeufigsten ganzen Gruppen der Top-Runs und darunter je Rolle
-- die Specs (hohe Keys von raider.io, +7 bis +21 von Warcraft Logs); im
-- Raid die Aufstellung der Top-Kills; in PvP nur, welche Specs oben
-- stehen - Ranglisten fuehren keine Teams. Beliebt heisst nicht bewiesen
-- stark - der Satz ueber der Liste sagt das, damit niemand eine
-- Rangliste der Klassen daraus liest.
--
-- Aus den Daten kommen nur Spec-Nummern. Name, Symbol und Klasse fragt
-- das Fenster beim Client: dann stimmen sie in jeder Sprache, und eine
-- Nummer kann nicht unter dem falschen Namen stehen.
do
    -- Wer Kampfrausch bzw. Heldentum mitbringt, und wer im Kampf
    -- wiederbeleben kann. Beides haengt an der Klasse, nicht an der Spec.
    local LUST = { SHAMAN = true, MAGE = true, HUNTER = true, EVOKER = true }
    local BREZ = { DRUID = true, DEATHKNIGHT = true, WARLOCK = true, PALADIN = true }
    local ROLES = { "tank", "healer", "dps" }
    -- Die Symbole einer Gruppe: Groesse und Abstand.
    local ICON, GAP = 26, 3

    local cache = {}
    local function specInfo(specID)
        if cache[specID] then return cache[specID] end
        local classID, classFile = ns.Compat.ClassOfSpec(specID)
        local name, icon
        for _, s in ipairs(classID and ns.Compat.SpecsForClass(classID) or {}) do
            if s.id == specID then name, icon = s.name, s.icon end
        end
        name = name or ns.Compat.SpecName(specID)
        local info = {
            name = name or ("#" .. tostring(specID)),
            icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
            classFile = classFile,
            className = ns.Compat.ClassName(classID) or "",
        }
        -- Nur merken, was der Client schon kannte - sonst bliebe "#250"
        -- fuer die ganze Sitzung stehen.
        if name then cache[specID] = info end
        return info
    end

    ---"Blut Todesritter" in der Farbe der Klasse.
    local function coloredName(info)
        local text = info.className ~= "" and (info.name .. " " .. info.className) or info.name
        return ("|cff%s%s|r"):format(ns.Compat.ClassColor(info.classFile), text)
    end

    ---Was eine Gruppe mitbringt: Kampfrausch, Kampf-Wiederbelebung.
    local function brings(specs)
        local lust, brez = false, false
        for _, spec in ipairs(specs) do
            local file = specInfo(spec).classFile
            if file and LUST[file] then lust = true end
            if file and BREZ[file] then brez = true end
        end
        return lust, brez
    end

    ---Die Unterzeile: was dabei ist, und in Warnfarbe, was fehlt.
    local function bringsText(specs, onlyPresent)
        local lust, brez = brings(specs)
        local teile = {}
        if lust then
            teile[#teile + 1] = L["COMP_LUST"]
        elseif not onlyPresent then
            teile[#teile + 1] = "|cff" .. S:Hex("warning") .. L["COMP_NO_LUST"] .. "|r"
        end
        if brez then
            teile[#teile + 1] = L["COMP_BREZ"]
        elseif not onlyPresent then
            teile[#teile + 1] = "|cff" .. S:Hex("warning") .. L["COMP_NO_BREZ"] .. "|r"
        end
        return table.concat(teile, "  \194\183  ")
    end

    ---Eine Zahl mit einer Stelle, im deutschen Client mit Komma.
    local function zahl(x)
        local text = (math.floor((tonumber(x) or 0) * 10 + 0.5) % 10 == 0)
            and ("%d"):format(math.floor((tonumber(x) or 0) + 0.5)) or ("%.1f"):format(tonumber(x) or 0)
        if GetLocale and GetLocale() == "deDE" then text = text:gsub("%.", ",") end
        return text
    end

    ---Ueberschrift je Aktivitaet: was die Seite dort zeigt.
    ---@param base string  die gewaehlte Aktivitaet
    function UI.CompTitle(base)
        local b = tostring(base or "")
        if b:find("^mplus") then return L["COMP_TITLE_mplus"] end
        if b:find("^raid") then return L["COMP_TITLE_raid"] end
        return L["COMP_TITLE_pvp"]
    end

    ---Die Zeilen des Abschnitts.
    ---
    ---Je Aktivitaet etwas anderes: in M+ ganze Gruppen und darunter die
    ---Specs je Rolle; im Raid die Aufstellung und je Spec Anteil und Anzahl;
    ---in PvP nur die Specs - eine Rangliste fuehrt keine Teams.
    ---@param mode string  Aktivitaet oder Dungeon ("mplus/kings-rest")
    ---@return table[] rows
    ---@return table|nil entry  die Zaehlung, fuer den Satz darueber
    ---@return string|nil key   unter welchem Modus sie stand
    ---@return string|nil art   "mplus", "raid" oder "pvp"
    function UI.CompRows(mode)
        local c, key, art = ns.Recommend.Comps(mode)
        if not c then return {}, nil, nil, nil end
        local rows = {}
        if art == "mplus" then
            for _, g in ipairs(c.groups or {}) do
                rows[#rows + 1] = {
                    kind = "compgroup", art = art, part = "groups", group = L["COMP_PART_groups"],
                    specs = g.specs, n = g.n, pct = g.pct, maxKey = g.maxKey, runs = c.runs, source = c.source,
                }
            end
        elseif art == "raid" and c.setup then
            -- Eine Zeile vorweg: wie ein Kill im Schnitt aufgestellt ist.
            rows[#rows + 1] = {
                kind = "info", part = "setup", group = L["COMP_PART_setup"],
                label = L["COMP_SETUP"]:format(zahl(c.setup.tank), zahl(c.setup.healer), zahl(c.setup.dps)),
                note = L["COMP_SETUP_NOTE"]:format(zahl(c.size), c.kills or 0),
            }
        end
        for _, role in ipairs(ROLES) do
            for _, r in ipairs(c[role] or {}) do
                local row = {
                    kind = "compspec", art = art, part = role, group = L["COMP_PART_" .. role], role = role,
                    spec = r[1], pct = r[2], source = c.source,
                    runs = c.runs, kills = c.kills, players = c.players,
                }
                -- Das dritte Feld: in M+ der hoechste Key, im Raid die
                -- Anzahl je Kill. PvP hat keines.
                if art == "mplus" then row.maxKey = r[3] elseif art == "raid" then row.avg = r[3] end
                rows[#rows + 1] = row
            end
        end
        return rows, c, key, art
    end

    ---Der Satz ueber der Liste.
    function UI.CompHint(entry, key, mode, art)
        if not entry then return "" end
        if art == "raid" then
            -- Je Schwierigkeit; sprang "alle zusammen" ein, steht es dabei.
            if key == "@raid" then return L["COMP_FALLBACK_RAID"] .. "  " .. L["COMP_HINT_RAID_ALL"]:format(entry.kills or 0) end
            return L["COMP_HINT_RAID"]:format(entry.kills or 0, ns.ModeLabel(key) or tostring(key))
        end
        if art == "pvp" then return L["COMP_HINT_PVP"]:format(entry.players or 0) end
        local text = (entry.source == "raider.io" and L["COMP_HINT"] or L["COMP_HINT_WCL"]):format(
            entry.runs or 0, entry.minKey or 0, entry.maxKey or 0, entry.distinct or 0)
        -- Ein Dungeon war gewaehlt, aber zu klein fuer eine eigene Zaehlung.
        if mode and tostring(mode):find("/") and key and not tostring(key):find("/") then
            text = L["COMP_FALLBACK"] .. "  " .. text
        end
        return text
    end

    ---Eine Zeile: eine ganze Gruppe oder eine Spec ihrer Rolle.
    function UI.SetCompRow(row, data)
        row.link = nil
        row.icon:SetTexture(nil)
        if data.kind == "compspec" then
            local info = specInfo(data.spec)
            row.icon:SetTexture(info.icon)
            row.title:SetText(coloredName(info))
            local teile = {}
            if data.art == "mplus" then
                teile[#teile + 1] = L["COMP_UP_TO"]:format(data.maxKey or 0)
            elseif data.art == "raid" then
                teile[#teile + 1] = L["COMP_AVG"]:format(zahl(data.avg))
            end
            -- Kampfrausch und Wiederbelebung zaehlen in M+ und im Raid; in
            -- der Arena hat beides niemand im Sinn.
            if data.art ~= "pvp" then
                local mit = bringsText({ data.spec }, true)
                if mit ~= "" then teile[#teile + 1] = mit end
            end
            if data.spec == ns.Profile.SelectedSpec() then
                teile[#teile + 1] = "|cff" .. S:Hex("accent") .. L["COMP_YOURS"] .. "|r"
            end
            row.detail:SetText(table.concat(teile, "  \194\183  "))
        else
            -- Fuenf Symbole statt eines, und der Text rueckt dahinter.
            local icons = rawget(row, "compIcons")
            if not icons then
                icons = {}
                for i = 1, 5 do
                    local tex = row:CreateTexture(nil, "ARTWORK")
                    tex:SetSize(ICON, ICON)
                    tex:SetPoint("LEFT", S.space.sm + (i - 1) * (ICON + GAP), 0)
                    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    icons[i] = tex
                end
                row.compIcons = icons
            end
            for i, tex in ipairs(icons) do
                local spec = data.specs[i]
                if spec then
                    tex:SetTexture(specInfo(spec).icon)
                    tex:Show()
                else
                    tex:Hide()
                end
            end
            local links = S.space.sm + 5 * (ICON + GAP) + 6
            row.title:ClearAllPoints()
            row.title:SetPoint("TOPLEFT", links, -S.space.sm)
            row.__textW = math.max(80, contentWidth() - links - 110)
            row.title:SetText(L["COMP_GROUP_RUNS"]:format(data.n or 0, data.maxKey or 0))
            -- Darunter, WER es ist: die Specs in Klassenfarbe. Kampfrausch
            -- und Wiederbelebung nur, wenn sie FEHLEN - fast jede Top-Gruppe
            -- hat beides, und zehnmal derselbe Satz sagt nichts (20. Oktober).
            local namen = {}
            for _, spec in ipairs(data.specs) do
                local info = specInfo(spec)
                namen[#namen + 1] = ("|cff%s%s|r"):format(ns.Compat.ClassColor(info.classFile), info.name)
            end
            local lust, brez = brings(data.specs)
            if not lust then namen[#namen + 1] = "|cff" .. S:Hex("warning") .. L["COMP_NO_LUST"] .. "|r" end
            if not brez then namen[#namen + 1] = "|cff" .. S:Hex("warning") .. L["COMP_NO_BREZ"] .. "|r" end
            row.detail:SetText(table.concat(namen, "  \194\183  "))
        end
        row.share:SetText((data.pct or 0) .. " %")
        S:Recolor(row.share, data.top and "accent" or "textSecondary")
        row.compTip = data
        row.onClick = nil
    end

    ---Der Tooltip: wer genau, wie oft, und was die Gruppe mitbringt.
    function UI.CompTooltip(owner, data)
        tipOutside(owner)
        local mr, mg, mb = S:Color("textMuted")
        if data.kind == "compgroup" then
            GameTooltip:SetText(L["COMP_TIP_GROUP"], 1, 1, 1)
            for i, spec in ipairs(data.specs) do
                local info = specInfo(spec)
                local role = i == 1 and "tank" or (i == 2 and "healer" or "dps")
                GameTooltip:AddDoubleLine(("|T%s:16:16|t %s"):format(tostring(info.icon), coloredName(info)),
                    L["COMP_ROLE_" .. role], 1, 1, 1, mr, mg, mb)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["COMP_TIP_RUNS"]:format(data.n or 0, data.runs or 0, data.pct or 0),
                0.9, 0.9, 0.9, true)
        else
            local info = specInfo(data.spec)
            GameTooltip:SetText(coloredName(info), 1, 1, 1)
            if data.art == "raid" then
                GameTooltip:AddLine(L["COMP_TIP_RAID"]:format(data.pct or 0, data.kills or 0, zahl(data.avg)),
                    0.9, 0.9, 0.9, true)
            elseif data.art == "pvp" then
                GameTooltip:AddLine(L["COMP_TIP_PVP"]:format(data.pct or 0, data.players or 0), 0.9, 0.9, 0.9, true)
            else
                GameTooltip:AddLine(L["COMP_TIP_SPEC"]:format(data.pct or 0, data.runs or 0), 0.9, 0.9, 0.9, true)
                if data.role == "dps" then GameTooltip:AddLine(L["COMP_TIP_DPS"], mr, mg, mb, true) end
            end
        end
        if data.maxKey then GameTooltip:AddLine(L["COMP_TIP_KEY"]:format(data.maxKey), 0.9, 0.9, 0.9) end
        if data.art ~= "pvp" then
            local mit = bringsText(data.kind == "compgroup" and data.specs or { data.spec }, data.kind ~= "compgroup")
            if mit ~= "" then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L["COMP_TIP_BRINGS"] .. ": " .. mit, 0.9, 0.9, 0.9, true)
            end
        end
        local stamp = ns.Recommend.CompsStamp()
        if stamp > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["COMP_TIP_SOURCE"]:format(tostring(data.source or "?"), ("%d-%02d-%02d"):format(
                math.floor(stamp / 10000), math.floor(stamp / 100) % 100, stamp % 100)), mr, mg, mb, true)
        end
        GameTooltip:Show()
    end
end

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

-- IM KAMPF NICHT (19. Oktober).
--
-- Gesehen: tot, die Gruppe kaempft noch - und MetaCodex ging auf. Ein
-- toter Spieler ist selbst nicht "im Kampf"; seine Gruppe schon. Also
-- zaehlt: ich ODER jemand aus der Gruppe.
--
-- NICHT "die Werte sind geheim". So stand es erst da, und dann ging
-- MetaCodex in einem laufenden Schluessel ueberhaupt nicht mehr auf: dort
-- haelt das Spiel die Werte den ganzen Lauf lang geheim, auch zwischen
-- den Pulls. Ohne eigene Werte stehen die Zielwerte dann eben ohne
-- "du hast".
local function kaempft(unit)
    if not UnitAffectingCombat then return false end
    local ok, ja = pcall(UnitAffectingCombat, unit)
    if not ok then return false end
    -- Eine geheime Antwort ist keine: lieber auf als falsch zu.
    if type(issecretvalue) == "function" and issecretvalue(ja) then return false end
    return ja == true
end

-- NUR DER EIGENE KAMPF (19. Oktober, am Abend). Die Gruppe mitzuzaehlen
-- hielt das Fenster zu, solange irgendwer pullte - auch wenn man selbst
-- daneben stand. Der Grund dafuer war das leere Fenster mit geheimen
-- Werten, und das gibt es nicht mehr: die Werte werden gemerkt.
function UI.InFight()
    -- Zweiter Rueckgabewert: WELCHE Pruefung - fuer die Dev-Version, die es
    -- im Chat dazuschreibt.
    if InCombatLockdown and InCombatLockdown() then return true, "InCombatLockdown" end
    if kaempft("player") then return true, "UnitAffectingCombat" end
    return false
end

---Die Meldung "im Kampf", in der Dev-Version mit dem Grund.
function UI.SayInFight()
    local _, grund = UI.InFight()
    ns.Print(L["OPEN_COMBAT"] .. ((ns.version == "dev" and grund) and (" (DEV: " .. grund .. ")") or ""))
end

function UI.Toggle()
    -- Zu geht immer; auf nur ausserhalb des Kampfes.
    if not (frame and frame:IsShown()) and UI.InFight() then
        UI.SayInFight()
        return
    end
    if not frame then build() end
    local ok, reason = ns.Data.Ensure()
    if not ok then ns.Print(ns.Data.Message()) end
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

    -- UEBER ALLES, WAS IM FENSTER SCHON LIEGT.
    --
    -- Der Knopf lag auf "Fensterebene plus zwanzig". Zog man ihn ueber
    -- den Wertekasten, war er dahinter - und wer darueber zeichnet,
    -- bekommt auch die Maus: der Knopf liess sich dann nicht einmal mehr
    -- wegziehen. Eine Sackgasse, aus der nur Umschalt-Rechtsklick half,
    -- und den kennt niemand, der gerade nicht weiterkommt.
    --
    -- Zwanzig war geraten. Gemessen wird jetzt, wie hoch die Rahmen in
    -- diesem Fenster wirklich liegen - zwei Ebenen tief, das deckt
    -- Blizzards Kaesten und deren Inhalt - und fuenf darueber ist der
    -- Knopf. Verschiebt ein Patch die Ebenen, verschiebt sich der Knopf
    -- mit.
    local hoechste = tonumber((host.GetFrameLevel and host:GetFrameLevel())) or 0
    local function schau(eltern, tiefe)
        if tiefe > 2 or not (eltern and eltern.GetChildren) then return end
        for _, kind in ipairs({ eltern:GetChildren() }) do
            -- Uns selbst nicht mitzaehlen: sonst stiege der Knopf bei
            -- jedem Aufruf um weitere fuenf Ebenen.
            if kind ~= button then
                local ebene = tonumber((kind.GetFrameLevel and kind:GetFrameLevel()))
                if ebene and ebene > hoechste then hoechste = ebene end
                schau(kind, tiefe + 1)
            end
        end
    end
    schau(host, 0)
    -- Und eine Lage hoeher als das Fenster selbst: liegt es in MEDIUM,
    -- reicht die Ebene allein nicht gegen Kinder in HIGH.
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(hoechste + 5)
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

do
    local wache = CreateFrame("Frame")
    wache:RegisterEvent("PLAYER_REGEN_DISABLED")
    wache:SetScript("OnEvent", function()
        if frame and frame:IsShown() then frame:Hide() end
    end)
end

---Zeigt einen Abschnitt - gebraucht vom Minimap-Knopf, der auf den
---Schalter fuer sich selbst zeigt.
---@param key string
function UI.OpenSection(key)
    -- Auch dieser Weg ins Fenster nicht im Kampf (siehe UI.InFight).
    if not (frame and frame:IsShown()) and UI.InFight() then
        UI.SayInFight()
        return
    end
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
    --
    -- NUR AUF DEM REITER "CHARAKTER" (28. Oktober). Am ganzen Fenster
    -- haengend stand er auch unter "Ruf" und "Abzeichen" - und weil das
    -- Fenster dort schmaler wird, schwebte er neben ihm in der Welt. Der
    -- Reiter selbst ist sein Elternrahmen: zu mit ihm, unsichtbar auf den
    -- anderen. Die Lage zaehlt weiter vom ganzen Fenster aus.
    local button = CreateFrame("Button", "MetaCodexCharacterButton", PaperDollFrame or host)
    button:SetSize(40, 40)
    -- Lage und Ebene setzt placeCharacterButton, gemessen am Fenster.
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
-- Die beiden Fenster am Talentbaum und das, was sie fuellt. Hier
-- angekuendigt, weil RefreshTalentPanel weiter oben steht als ihr Aufbau
-- - in Lua muss ein Local deklariert sein, bevor jemand es ruft.
local talentPanel, pvpPanel, zeigePvp
-- DIE MASSE DER BUILDLISTE, in einer Tabelle statt als zehn Locals.
--
-- Lua 5.1 erlaubt 200 lokale Variablen je Funktion, und die
-- Hauptebene dieser Datei ist eine. Jede neue Konstante kostet davon
-- eine; zusammengefasst kostet der ganze Satz eine einzige. Dieselbe
-- Rechnung wie bei MASS weiter oben.
--
-- WIDTH: breit genug, dass ein Buildname mehr als zwei Woerter zeigt.
-- Bei 260 stand in jeder Zeile "Totemische Projektion, Wolfsaffinitaet
-- d..." - sieben Zeilen, die alle an derselben Stelle aufhoeren,
-- unterscheiden nichts. Breiter als 320 wird die Leiste zum zweiten
-- Fenster.
--
-- HEAD_H: eine Ueberschrift traegt ein Wort, keine Entscheidung, und
-- braucht darum keine 38 Pixel.
local TP = {
    WIDTH = 320,
    -- Der Vorrat an Zeilen; wie viele davon stehen, entscheidet die
    -- Liste, und die Hoehe folgt ihr.
    ROWS = 10,
    ROW_H = 38,
    HEAD_H = 20,
    ICON = 20,
    -- Der Stern zum Festhalten, rechts in jeder Zeile.
    PIN = 18,
    -- Wo die erste Zeile anfaengt: unter Titel und Waehler.
    TOP = 62,
    -- Und im PvP-Fenster, das nur einen Titel hat.
    PVP_TOP = 34,
}

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
-- Die Hoehe bei sieben Zeilen - fuer die Frage, ob die Liste nach
-- unten noch auf den Bildschirm passt. Gefuellt rechnet sie ihre
-- wirkliche Hoehe selbst aus.
TP.HEIGHT = TP.TOP + 7 * (TP.ROW_H + 2) + 46

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
    -- Die Spec des Baums daneben, nicht die im grossen Fenster gewaehlte.
    local specID = ns.Profile.TalentFrameSpec()
    -- Derselbe Schluessel wie die Talentseite im grossen Fenster: wer
    -- dort einen Dungeon gewaehlt hat, meint ihn hier auch.
    if ns.Profile.Dungeon("talents") and ns.Data.EnsureDungeons then
        ns.Data.EnsureDungeons()
    end
    local mode = ns.Profile.LookupMode("talents")
    if not specID or not mode then return {} end
    local hero = ns.Profile.HeroTree(specID)
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
    -- MIT RANG, nicht nur die Nummer. Die Vorschau rechnet gegen
    -- deinen Baum, und dort hat ein Talent ein, zwei oder drei
    -- Raenge; ohne sie sieht sie nicht, womit ein Build bezahlt.
    local basis = {}
    for _, node in ipairs((build and build.nodes) or {}) do
        local spell = tonumber(node) or tonumber(node and node.spell)
        if spell then
            basis[#basis + 1] = { spell = spell, rank = tonumber(node and node.rank) or 1 }
        end
    end

    ---@param added number[]|nil
    ---@param removed number[]|nil
    ---@return number[]
    local function listeMit(added, removed)
        if #basis == 0 then return {} end
        local weg = {}
        for _, spell in ipairs(removed or {}) do weg[spell] = true end
        local liste = {}
        for _, eintrag in ipairs(basis) do
            if not weg[eintrag.spell] then liste[#liste + 1] = eintrag end
        end
        -- Was eine Alternative dazunimmt, steht in den Daten ohne
        -- Rang. Einer ist die ehrliche Annahme - und sie steht hier,
        -- damit sie nicht in der Vorschau als Messung durchgeht.
        for _, spell in ipairs(added or {}) do
            liste[#liste + 1] = { spell = spell, rank = 1 }
        end
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

    -- DIE PVP-TALENTE GEHOEREN DAZU - aber nicht in diese Liste.
    --
    -- Blizzards Importkette enthaelt sie nicht: sie sitzen in drei
    -- eigenen Plaetzen, nicht im Baum. Ein Build laedt sie also nie, und
    -- die Vorschau kann sie nicht einrahmen. Wer in einer PvP-Klammer
    -- vor dieser Liste steht, hat sie aber trotzdem zu waehlen - und
    -- gemessen sind sie.
    --
    -- Sie standen zuerst unter den Builds, mit einer Ueberschrift
    -- dazwischen. Dann waren es elf Zeilen, und die untersten standen
    -- ueber dem Bildschirmrand hinaus. Also bekommen sie ein eigenes
    -- Fenster daneben - und werden hier getrennt zurueckgegeben.
    local pvp = {}
    for _, pick in ipairs(picks or {}) do
        -- Drei Plaetze hat man, mehr als sechs zur Auswahl zu zeigen
        -- waere eine Liste statt einer Antwort.
        if pick.pvp and #pvp < 6 then
            local info = C_Spell and C_Spell.GetSpellInfo
                and C_Spell.GetSpellInfo(pick.spell)
            pvp[#pvp + 1] = {
                name = (info and info.name) or ("#" .. tostring(pick.spell)),
                note = L["TP_PVP_SHARE"]:format(pick.pct or 0),
                spellID = pick.spell,
                icon = tonumber(info and info.iconID),
            }
        end
    end
    return out, pvp
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
            and ns.Recommend.HasSection(ns.Profile.TalentFrameSpec(), mode.key,
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
    p:SetWidth(TP.WIDTH)
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

    -- NICHT ZIEHBAR. Sie haengt am Knopf, und der ist es.
    --
    -- Eine Zeitlang war sie es auch, mit eigener gemerkter Lage. Dann
    -- gab es zwei Dinge, die sich unabhaengig verschieben liessen - und
    -- wer den Knopf nach oben zog, hatte die Liste unten stehen, ohne
    -- sichtbaren Zusammenhang. Eine Sache zum Verschieben genuegt.
    p:EnableMouse(true)

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
    p.pick = makeButton(p, TP.WIDTH - S.space.md * 2, 22, "", function(self)
        openTalentModePicker(self)
    end)
    p.pick:SetPoint("TOPLEFT", S.space.md, -S.space.md - 22)

    p.rows = {}
    for i = 1, TP.ROWS do
        local r = CreateFrame("Button", nil, p)
        r:SetHeight(TP.ROW_H)
        r.bg = S:Fill(r, "bgOverlay", 0)
        -- EIN SYMBOL, wo es eines gibt. Ein PvP-Talent erkennt man im
        -- Spiel am Bild; ein Build hat keines, denn er ist kein Zauber.
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(TP.ICON, TP.ICON)
        r.icon:SetPoint("LEFT", S.space.sm, 0)
        r.icon:Hide()
        r.name = S:Text(r, "body", "textPrimary")
        r.name:SetPoint("RIGHT", -S.space.sm - TP.PIN, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.note = S:Text(r, "caption", "textSecondary")
        r.note:SetPoint("RIGHT", -S.space.sm - TP.PIN, 0)
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
        r.pin:SetSize(TP.PIN, TP.PIN)
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
            -- Ein PvP-Talent ist ein Zauber, kein Build: dann zeigt der
            -- Zeiger, was Blizzard selbst darueber sagt.
            local zauber = rawget(self, "spellID")
            if zauber and GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(zauber)
                GameTooltip:Show()
                return
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
    local rows, pvpListe = talentPanelRows()
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

    -- DIE ZEILEN SETZEN SICH SELBST.
    --
    -- Vorher sass jede an i mal Zeilenhoehe. Das geht, solange alle
    -- gleich hoch sind - eine Ueberschrift ist es nicht: sie traegt ein
    -- Wort, keine Entscheidung, und 38 Pixel dafuer sind ein Loch in
    -- der Liste.
    local y = TP.TOP
    for i, r in ipairs(talentPanel.rows) do
        local row = rows[i]
        if row then
            local kopf = row.head == true
            local hoch = kopf and TP.HEAD_H or TP.ROW_H
            r:SetHeight(hoch)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", S.space.sm, -y)
            r:SetPoint("TOPRIGHT", -S.space.sm, -y)
            y = y + hoch + 2

            -- Das Symbol, wo es eines gibt - und der Text rueckt dann
            -- nach rechts, damit er nicht darauf liegt.
            local bild = tonumber(row.icon)
            r.icon:SetShown(bild ~= nil)
            if bild then r.icon:SetTexture(bild) end
            local ein = S.space.sm + (bild and (TP.ICON + S.space.sm) or 0)

            r.name:ClearAllPoints()
            r.note:ClearAllPoints()
            r.note:SetShown(not kopf)
            if kopf then
                -- Eine Ueberschrift sitzt mittig in ihrer Zeile, klein
                -- und ruhig: sie trennt, sie wirbt nicht.
                S:ApplyRole(r.name, "head")
                r.name:SetPoint("LEFT", S.space.sm, 0)
                r.name:SetPoint("RIGHT", -S.space.sm, 0)
            else
                S:ApplyRole(r.name, "title")
                r.name:SetPoint("TOPLEFT", ein, -4)
                r.name:SetPoint("RIGHT", -S.space.sm - TP.PIN, 0)
                r.note:SetPoint("TOPLEFT", ein, -20)
                r.note:SetPoint("RIGHT", -S.space.sm - TP.PIN, 0)
            end
            -- Eine Ueberschrift ist kein Knopf.
            r:EnableMouse(not kopf)

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
            r.spellID = row.spellID
            -- Eine Zeile ohne Talentliste gibt es nichts festzuhalten:
            -- ein Stern, der nichts tut, ist ein kaputter Stern.
            r.pin:SetShown(row.spells ~= nil)
            r:Show()
        else
            r:Hide()
        end
    end
    UI.UpdateTalentPins()
    -- Und die PvP-Talente daneben, wo es welche gibt.
    zeigePvp(pvpListe or {})
    -- So hoch, wie die Liste wirklich ist: in einer PvP-Klammer kommen
    -- bis zu vier Zeilen dazu, und eine feste Hoehe liesse sie entweder
    -- abgeschnitten oder mit einem leeren Streifen darunter stehen.
    talentPanel:SetHeight(y + 46 - 2)
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

---Wo der Knopf hin soll, wenn ihn noch niemand gezogen hat.
---
---NICHT GERATEN, SONDERN NACHGESEHEN. Die Vorgabe war 12/12 von der
---linken unteren Ecke, und Spieler meldeten, dass der Knopf dort auf
---Blizzards Belegungsauswahl liegt. Im Client gemessen: unten links
---stehen zwei Felder auf derselben Hoehe - die Auswahl (x+48, y+26,
---200x30) und das Suchfeld (x+268, y+26, 183x30). Ein 30 Pixel hoher
---Knopf auf y+12 schneidet beide an.
---
---UND NEBEN ALLES, NICHT NUR NEBEN BLIZZARDS. Die erste Fassung setzte
---ihn ueber die Leiste - also genau dorthin, wo bei vielen schon der
---Knopf von Raider.IO steht. Das war derselbe Fehler eine Etage
---hoeher: fremde Oberflaeche zudecken, nur eine andere.
---
---Also: eine Zeile ueber der Leiste, und von links nach rechts an
---allem vorbei, was dort schon liegt - egal von wem. Gefunden wird es
---ueber die Rahmen selbst, nicht ueber Namen: ein Addon, das wir nicht
---kennen, zaehlt genauso. Was an UIParent haengt statt am
---Talentfenster, sehen wir nicht - dann hilft nur Ziehen, und das geht.
---@param f table  das Talentfenster
---@param tf table|nil  der Talentbaum darin
---@param breit number  wie breit unser Knopf ist
---@param hoch number  und wie hoch
---@return number x, number y
local function freierPlatz(f, tf, breit, hoch)
    local bezug = tf or f
    local unten = tonumber((bezug and bezug.GetBottom and bezug:GetBottom()))
    local links = tonumber((bezug and bezug.GetLeft and bezug:GetLeft()))
    if not (unten and links) then return 12, 12 end

    -- Alles Flache unten einsammeln, aus beiden Rahmen: Blizzards
    -- Felder haengen am Baum, fremde Knoepfe oft am Fenster.
    local kaesten = {}
    for _, wirt in ipairs({ f, tf }) do
        if wirt and wirt.GetChildren then
            for _, kind in ipairs({ wirt:GetChildren() }) do
                local y = tonumber((kind.GetBottom and kind:GetBottom()))
                local x = tonumber((kind.GetLeft and kind:GetLeft()))
                local w = tonumber((kind.GetWidth and kind:GetWidth()))
                local h = tonumber((kind.GetHeight and kind:GetHeight()))
                local sichtbar = kind.IsShown and kind:IsShown()
                -- Flach und unten. Der Baum selbst ist hoch und faellt
                -- heraus, ohne dass wir ihn kennen muessen.
                if y and x and w and h and sichtbar and h <= 44
                    and (y - unten) < 130 then
                    kaesten[#kaesten + 1] = {
                        x = x - links, y = y - unten, w = w, h = h,
                    }
                end
            end
        end
    end
    if #kaesten == 0 then return 12, 12 end

    -- Die Leiste ist, was ganz unten liegt. Darueber faengt unsere
    -- Zeile an.
    local leiste, linkeste = 0, nil
    for _, k in ipairs(kaesten) do
        if k.y < 60 then
            if k.y + k.h > leiste then leiste = k.y + k.h end
            if not linkeste or k.x < linkeste then linkeste = k.x end
        end
    end
    local y = leiste > 0 and (leiste + S.space.sm) or 12
    local x = linkeste or 12

    -- Und jetzt nach rechts an allem vorbei, was in dieser Zeile schon
    -- liegt. Hoechstens zehn Schritte: ein Rahmen, der sich beim
    -- Messen bewegt, soll keine Endlosschleife ergeben.
    for _ = 1, 10 do
        local stoerer
        for _, k in ipairs(kaesten) do
            local trifftY = (k.y < y + hoch) and (k.y + k.h > y)
            local trifftX = (k.x < x + breit) and (k.x + k.w > x)
            if trifftY and trifftX then
                if not stoerer or (k.x + k.w) > stoerer then stoerer = k.x + k.w end
            end
        end
        if not stoerer then break end
        x = stoerer + S.space.sm
    end
    return math.floor(x), math.floor(y)
end
-- EIN EIGENES FENSTER FUER DIE PVP-TALENTE.
--
-- Sie standen zuerst unter den Builds, mit einer Ueberschrift
-- dazwischen. In einer Klammer wurden daraus elf Zeilen, und die
-- untersten standen ueber dem Bildschirmrand hinaus - abgeschnitten,
-- ohne dass man es der Liste ansah.
--
-- Daneben statt darunter: dieselbe Reihe wie sonst - Knopf, Builds,
-- PvP-Talente -, und keine der beiden Listen wird laenger, weil die
-- andere etwas zu sagen hat.

local function buildPvpPanel()
    if pvpPanel then return pvpPanel end
    local p = CreateFrame("Frame", "MetaCodexPvpTalents", UIParent)
    p:SetWidth(TP.WIDTH)
    p:SetFrameStrata("DIALOG")
    S:Fill(p, "bgBase")
    S:Border(p, "borderSubtle")
    p:Hide()

    p.title = S:Text(p, "title", "textPrimary")
    p.title:SetPoint("TOPLEFT", S.space.md, -S.space.md)
    p.title:SetText(L["TALENT_PVP"])

    p.rows = {}
    for i = 1, 6 do
        local r = CreateFrame("Button", nil, p)
        r:SetHeight(TP.ROW_H)
        r:SetPoint("TOPLEFT", S.space.sm, -TP.PVP_TOP - (i - 1) * (TP.ROW_H + 2))
        r:SetPoint("TOPRIGHT", -S.space.sm, -TP.PVP_TOP - (i - 1) * (TP.ROW_H + 2))
        r.bg = S:Fill(r, "bgOverlay", 0)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(TP.ICON, TP.ICON)
        r.icon:SetPoint("LEFT", S.space.sm, 0)
        r.name = S:Text(r, "body", "textPrimary")
        r.name:SetPoint("TOPLEFT", S.space.sm + TP.ICON + S.space.sm, -4)
        r.name:SetPoint("RIGHT", -S.space.sm, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.note = S:Text(r, "caption", "textSecondary")
        r.note:SetPoint("TOPLEFT", S.space.sm + TP.ICON + S.space.sm, -20)
        r.note:SetPoint("RIGHT", -S.space.sm, 0)
        r.note:SetJustifyH("LEFT")
        r.note:SetWordWrap(false)
        -- Ein PvP-Talent ist ein Zauber: der Zeiger zeigt, was
        -- Blizzard selbst darueber sagt.
        r:SetScript("OnEnter", function(self)
            self.bg:SetAlpha(0.6)
            local id = rawget(self, "spellID")
            if not (id and GameTooltip.SetSpellByID) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(id)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(self)
            self.bg:SetAlpha(0)
            GameTooltip:Hide()
        end)
        r:Hide()
        p.rows[i] = r
    end

    p.hint = S:Text(p, "caption", "textMuted")
    p.hint:SetPoint("BOTTOMLEFT", S.space.md, S.space.md)
    p.hint:SetPoint("BOTTOMRIGHT", -S.space.md, S.space.md)
    p.hint:SetWordWrap(true)
    p.hint:SetJustifyH("LEFT")
    p.hint:SetText(L["TP_PVP_HINT"])
    pvpPanel = p
    return p
end

---Die PvP-Talente neben die Builds stellen - oder wegraeumen.
---@param liste table[]
zeigePvp = function(liste)
    if #liste == 0 then
        if pvpPanel then pvpPanel:Hide() end
        return
    end
    local p = buildPvpPanel()
    for i, r in ipairs(p.rows) do
        local row = liste[i]
        if row then
            r.spellID = row.spellID
            r.name:SetText(row.name or "")
            r.note:SetText(row.note or "")
            local bild = tonumber(row.icon)
            r.icon:SetShown(bild ~= nil)
            if bild then r.icon:SetTexture(bild) end
            r:Show()
        else
            r:Hide()
        end
    end
    p:SetHeight(TP.PVP_TOP + math.min(#liste, #p.rows) * (TP.ROW_H + 2) + 34)
    -- Rechts neben die Builds, oben buendig. Ist dort kein Platz mehr,
    -- auf die andere Seite - dieselbe Regel wie fuer die Liste selbst.
    p:ClearAllPoints()
    local rechts = tonumber((talentPanel and talentPanel.GetRight and talentPanel:GetRight()))
    local schirm = tonumber((UIParent and UIParent.GetRight and UIParent:GetRight()))
    local passt = not (rechts and schirm) or (schirm - rechts) >= (TP.WIDTH + S.space.md)
    if passt then
        p:SetPoint("TOPLEFT", talentPanel, "TOPRIGHT", S.space.md, 0)
    else
        p:SetPoint("TOPRIGHT", talentPanel, "TOPLEFT", -S.space.md, 0)
    end
    p:SetShown(talentPanel and talentPanel:IsShown() and true or false)
end

---Die Buildliste oeffnen - vom Knopf aus.
function UI.ShowTalentPanel()
    local f = talentFrame()
    if not f then return end
    local p = buildTalentPanel()
    p:ClearAllPoints()
    p:SetHeight(TP.HEIGHT)

    -- SIE HAENGT AM KNOPF. IMMER.
    --
    -- Vorher suchte sie sich ihren Platz selbst - aussen neben das
    -- Talentfenster, wenn dort Platz war, sonst neben den Knopf - und
    -- liess sich zusaetzlich frei verschieben. Damit gab es zwei
    -- ziehbare Dinge, die auseinanderlaufen konnten: wer den Knopf
    -- nach oben zog, hatte seine Liste unten stehen und keinen
    -- Zusammenhang mehr zwischen beiden.
    --
    -- Eine Regel statt vier: rechts neben dem Knopf, auf seiner Hoehe
    -- beginnend. Verschoben wird der Knopf, die Liste kommt mit.
    local b = talentButton
    if not b then
        p:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
    else
        -- OBEN BUENDIG, NACH UNTEN AUFGEHEND.
        --
        -- Unten buendig wuchs sie nach oben - also genau in den Baum
        -- hinein, ueber dem der Knopf steht. Oben am Knopf angesetzt
        -- haengt sie unter ihm, und wer sie aus dem Weg haben will,
        -- zieht den Knopf nach oben: die Liste folgt nach unten, wo
        -- weniger steht.
        local links = tonumber(b.GetLeft and b:GetLeft())
        local rechts = tonumber(b.GetRight and b:GetRight())
        local oben = tonumber(b.GetTop and b:GetTop())
        local breit = tonumber(UIParent and UIParent.GetRight and UIParent:GetRight())
        local nachRechts = not (rechts and breit)
            or (breit - rechts) >= (TP.WIDTH + S.space.md)
        -- Und nach oben nur dann, wenn nach unten der Bildschirm zu Ende
        -- ist. Eine Liste, die halb draussen steht, ist keine.
        local nachUnten = not oben or (oben - TP.HEIGHT) >= 0

        local meine = nachUnten and "TOP" or "BOTTOM"
        local seine = meine .. (nachRechts and "RIGHT" or "LEFT")
        local abstand = nachRechts and S.space.md or -S.space.md
        p:SetPoint(meine .. (nachRechts and "LEFT" or "RIGHT"), b, seine, abstand, 0)
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
    if not (x and y) then
        x, y = freierPlatz(f, f.TalentsFrame,
            tonumber((b:GetWidth())) or 160, tonumber((b:GetHeight())) or 30)
    end
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

    -- UND EIN BERICHT, DER SEINEN EIGENEN FEHLER MITBRINGT.
    --
    -- Eine Sonde, die stirbt, sagt gar nichts - und ausgerechnet die
    -- Stelle, an der sie stirbt, ist die interessanteste. Was bis
    -- dahin gemessen wurde, steht trotzdem im Fenster, und darunter,
    -- woran es lag.
    local function sammeln()

    -- UND EIN BERICHT, DER SEINEN EIGENEN FEHLER MITBRINGT.
    --
    -- Eine Sonde, die stirbt, sagt gar nichts - und ausgerechnet die
    -- Stelle, an der sie stirbt, ist die interessanteste. Was bis
    -- dahin gemessen wurde, steht trotzdem im Fenster, und darunter,
    -- woran es lag.
    local function sammeln()
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

    -- WAS UNTEN LINKS IM TALENTFENSTER SCHON STEHT.
    --
    -- Unsere Vorgabe setzt den Knopf auf 12/12 von der linken unteren
    -- Ecke - und Spieler melden, dass er dort auf Blizzards eigener
    -- Belegungsauswahl liegt. Welcher Rahmen das ist, kann nur der
    -- Client sagen; eine Zahl, die bei mir passt, ist keine Vorgabe.
    if tab and tab.GetChildren then
        zeile(" ")
        zeile("Rahmen unten links im Talentbaum:")
        local unten = tonumber(tab.GetBottom and tab:GetBottom()) or 0
        local links = tonumber(tab.GetLeft and tab:GetLeft()) or 0
        local kinder = { tab:GetChildren() }
        local gefunden = 0
        for _, kind in ipairs(kinder) do
            local ok = type(kind) == "table" and kind.GetBottom and kind.IsShown
            -- Klammern: siehe Core/Tree.lua. Ein Aufruf ohne
            -- Rueckgabe liefert sonst kein Argument statt nil.
            local y = ok and tonumber((kind:GetBottom()))
            local x = ok and tonumber((kind:GetLeft()))
            -- Nur was wirklich unten links steht und zu sehen ist.
            if y and x and kind:IsShown() and (y - unten) < 120 and (x - links) < 400 then
                gefunden = gefunden + 1
                zeile(("  %-28s x+%-5d y+%-5d %dx%d"):format(
                    tostring(kind.GetName and kind:GetName() or "ohne Namen"),
                    math.floor(x - links), math.floor(y - unten),
                    math.floor(tonumber((kind:GetWidth())) or 0),
                    math.floor(tonumber((kind:GetHeight())) or 0)))
            end
        end
        if gefunden == 0 then zeile("  nichts gefunden") end
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

    end

    local ok, fehler = pcall(sammeln)
    if not ok then
        zeile(" ")
        zeile("ABGEBROCHEN: " .. tostring(fehler))
    end

    end

    local ok, fehler = pcall(sammeln)
    if not ok then
        zeile(" ")
        zeile("ABGEBROCHEN: " .. tostring(fehler))
    end

    local okV, fehlerV = pcall(function()

    -- WARUM EIN TALENT GRUEN STEHT, DAS LAENGST GESKILLT IST.
    --
    -- Gemeldet am 13. Oktober: "5 gruen dazu, 0 rot weg", und die fuenf
    -- Rahmen sassen auf Talenten, die der Spieler hat. Fuenf dazu ohne
    -- einen einzigen weg kann in einem vollen Baum nicht stimmen - die
    -- Punkte muessten ja irgendwo herkommen.
    --
    -- Der Verdacht: derselbe Knoten traegt in unseren Daten eine andere
    -- Zauber-ID als beim Client. Dann faellt er auf der einen Seite als
    -- "fehlt" und auf der anderen nicht als "weg" auf. Hier steht beides
    -- nebeneinander, Talent fuer Talent.
    zeile(" ")
    zeile("Vorschau: was als gruen gezaehlt wird")
    do
        local worn = (ns.Tree and ns.Tree.Worn and ns.Tree.Worn()) or {}
        local geskillt = 0
        for _ in pairs(worn) do geskillt = geskillt + 1 end
        zeile(("%-46s %d"):format("geskillte Zauber laut Client", geskillt))

        local specID = ns.Profile.SelectedSpec()
        local okT, _, build = pcall(ns.Recommend.Talents, specID,
            ns.Profile.LookupMode("talents"), ns.Recommend.ALL, ns.Profile.HeroTree())
        local knoten = (okT and build and build.nodes) or {}
        zeile(("%-46s %d"):format("Knoten im haeufigsten Build", #knoten))

        local cfg = C_ClassTalents and C_ClassTalents.GetActiveConfigID
            and C_ClassTalents.GetActiveConfigID()
        local gruen = 0
        for _, node in ipairs(knoten) do
            local spell = tonumber(node) or tonumber(node and node.spell)
            if spell and not worn[spell] then
                gruen = gruen + 1
                if gruen <= 12 then
                    local nodeID = ns.Tree.NodeFor and ns.Tree.NodeFor(spell)
                    local info = C_Spell and C_Spell.GetSpellInfo
                        and C_Spell.GetSpellInfo(spell)
                    -- Was der Client an GENAU DIESEM Knoten stehen hat.
                    local raenge, beimClient = 0, nil
                    if nodeID and cfg and C_Traits then
                        local ok2, n = pcall(C_Traits.GetNodeInfo, cfg, nodeID)
                        n = ok2 and n or nil
                        raenge = tonumber(n and n.ranksPurchased) or 0
                        local aktiv = n and n.activeEntry and n.activeEntry.entryID
                        if aktiv then
                            local ok3, e = pcall(C_Traits.GetEntryInfo, cfg, aktiv)
                            local defID = ok3 and e and e.definitionID
                            if defID then
                                local ok4, d = pcall(C_Traits.GetDefinitionInfo, defID)
                                beimClient = ok4 and d and tonumber(d.spellID) or nil
                            end
                        end
                    end
                    zeile(("  %-28s uns %-9s Knoten %-7s Raenge %d  Client %s")
                        :format(((info and info.name) or "?"):sub(1, 28),
                            tostring(spell), tostring(nodeID), raenge,
                            tostring(beimClient)))
                end
            end
        end
        zeile(("%-46s %d"):format("davon als gruen gezaehlt", gruen))
    end
    end)
    if not okV then zeile("Vorschau-Teil abgebrochen: " .. tostring(fehlerV)) end

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
    if pvpPanel then pvpPanel:Hide() end
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
