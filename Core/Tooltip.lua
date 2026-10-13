-- Was MetaCodex weiss, dort hinschreiben, wo man das Item anfasst.
--
-- Ein Spieler haelt im Auktionshaus einen Handschuh in der Hand und will
-- eine Antwort auf zwei Fragen, ohne erst ein Fenster zu oeffnen:
-- Sind das die richtigen Zweitwerte fuer mich? Und ist das ueberhaupt
-- das Teil, das die Besten auf diesem Platz tragen?
--
-- Beides steht in den Daten, die das Addon ohnehin mitbringt. Hier wird
-- es an den Tooltip gehaengt: die Rangnummer direkt an die Wertzeile,
-- und darunter eine Zeile zum Platz in der Liste.
--
-- Gefragt wird nach der AKTIVEN Spec, nicht nach der, die das Fenster
-- gerade zeigt. Wer in der Tasche vergleicht, vergleicht fuer den
-- Charakter, auf dem er steht. Die Aktivitaet kommt dagegen aus dem
-- Fenster, denn zwischen Schluesselstein und Schlachtzug unterscheidet
-- sich die Rangfolge.

local _, ns = ...
local L = ns.L

local Tooltip = {}
ns.Tooltip = Tooltip

-- Unsere Schluessel und die Namen, unter denen der Client dieselben
-- Werte fuehrt. GetItemStats gibt eine Tabelle mit genau diesen
-- Schluesseln zurueck.
local MOD = {
    crit    = "ITEM_MOD_CRIT_RATING_SHORT",
    haste   = "ITEM_MOD_HASTE_RATING_SHORT",
    mastery = "ITEM_MOD_MASTERY_RATING_SHORT",
    vers    = "ITEM_MOD_VERSATILITY",
}

---Die Rangfolge der Zweitwerte fuer den Charakter, auf dem man steht.
---@return table|nil rank  { crit = 1, haste = 2, ... }
local function priorityRanks()
    local spec = ns.Compat.CurrentSpec() or ns.Profile.SelectedSpec()
    if not spec then return nil end
    local stats = ns.Recommend.Stats(spec, ns.Profile.Mode(), ns.Recommend.ALL)
    if not stats or not stats.priority then return nil end
    local rank = {}
    for i, key in ipairs(stats.priority) do rank[key] = i end
    return rank
end

---Welche Raenge gelten fuer DIESES Item?
---
---Nur die Werte, die es wirklich traegt. Ein Rang fuer einen Wert, der
---nicht draufsteht, waere eine Zahl ohne Gegenstueck.
---@param link string
---@return table|nil { haste = 2, mastery = 4 }
function Tooltip.StatRanks(link)
    if not link then return nil end
    local stats = ns.Compat.ItemStats(link)
    if not stats then return nil end
    local rank = priorityRanks()
    if not rank then return nil end
    local out, any = {}, false
    for _, key in ipairs(ns.SECONDARY) do
        local value = stats[MOD[key]]
        if rank[key] and type(value) == "number" and value > 0 then
            out[key] = rank[key]
            any = true
        end
    end
    return any and out or nil
end

---Welche Zweitwerte dieses Stueck traegt.
---
---Nicht die Rangfolge, sondern das nackte "hat es Krit, ja oder nein".
---Gebraucht von der Hervorhebung im Fundort-Raster: wer auf Krit und
---Meisterschaft spielt, will die Stuecke sehen, die beides haben.
---
---Der Client muss das Stueck kennen. Tut er es nicht, ist die Antwort
---NICHT "hat nichts", sondern "weiss nicht" - und das Raster hebt dann
---weder hervor noch blendet es ab. Eine Vermutung als Tatsache zu
---zeigen waere hier besonders teuer: der Spieler sucht ja gerade das
---eine Stueck mit den richtigen Werten.
---@param link string|nil
---@return table|nil stats  { crit = true, ... }, leer wenn keine
function Tooltip.SecondaryStats(link)
    if not link then return nil end
    local stats = ns.Compat.ItemStats(link)
    if not stats then return nil end
    local out = {}
    for _, key in ipairs(ns.SECONDARY) do
        local value = stats[MOD[key]]
        if type(value) == "number" and value > 0 then out[key] = true end
    end
    return out
end

---Wo steht dieses Item in der Liste seines Platzes?
---
---Platz eins ist das, was die meisten der gemessenen Spieler tragen -
---das, was andere "BiS" nennen. Die Zahl dahinter ist der Anteil, und
---sie gehoert dazu: "Platz 1 mit 92 %" ist etwas anderes als
---"Platz 1 mit 21 %".
---@param itemID number
---@return number|nil rank, number|nil pct, number|nil ofHowMany
function Tooltip.GearRank(itemID)
    if not itemID then return nil end
    local spec = ns.Compat.CurrentSpec() or ns.Profile.SelectedSpec()
    if not spec then return nil end
    local gear = ns.Recommend.Gear(spec, ns.Profile.Mode(), ns.Recommend.ALL)
    if not gear then return nil end
    for _, list in pairs(gear) do
        for i, row in ipairs(list) do
            if row.id == itemID then return i, row.pct, #list end
        end
    end
    return nil
end


-- Wie viele fremde Specs ohne Umschalt genannt werden.
--
-- Der Median liegt bei drei Specs je Stueck, und 468 der 1580 gemessenen
-- Stuecke betreffen ueberhaupt nur eine - fuer die grosse Mehrheit ist
-- die Liste also von Natur aus kurz. Die 163 Stuecke mit mehr als zehn
-- Specs sind der Grund fuer die Grenze: Class Codex schreibt dort
-- siebenundzwanzig Zeilen hin und schiebt damit die Werte des
-- Gegenstands aus dem Bild.
local WORN_ZEILEN = 2

-- Bis zu welchem Rang ein Wert noch "passt".
--
-- Zwei, und zwar beide: ein Stueck mit Meisterschaft und
-- Vielseitigkeit passt zu einer Spec, wenn genau das ihre beiden
-- hoechsten sind. Bei drei waere fast jedes Stueck fuer fast jede
-- Spec "passend" - an einem Schmuckstueck standen damit
-- achtunddreissig Zeilen.
local WERT_TOP = 2

---Die Zeilen "auch getragen von" zu einem Gegenstand.
---
---Gegeben werden FELDER, keine fertigen Zeichenketten: der Tooltip
---setzt daraus zwei Spalten, und dafuer muss er Name und Zahl getrennt
---bekommen. Vierzehn Zeilen mit ragged rechtem Rand waren das erste,
---was im Spiel auffiel.
---
---Sortiert wird nach AKTIVITAET in Gruppen, die Gruppen nach ihrem
---besten Anteil. Rein nach Anteil sortiert sprang die Aktivitaet
---zwischen zwei Zeilen hin und her, und dann steht ueber jeder zweiten
---Zeile eine Ueberschrift - oder sie steht vierzehnmal daneben.
---
---Die eigene Spec faellt weg: ueber die steht schon die Zeile darueber.
---@param itemID number|nil
---@param alle boolean|nil  true = vollstaendig, sonst gekuerzt
---@return table[] zeilen  je { name, pct, mode }
---@return number uebrig  wie viele nicht genannt wurden
function Tooltip.WornLines(itemID, alle)
    local liste = ns.Recommend.WornBy(itemID)
    if not liste or #liste == 0 then return {}, 0 end

    local eigene = ns.Compat.CurrentSpec() or ns.Profile.SelectedSpec()

    -- ERST BENENNEN, DANN KUERZEN.
    --
    -- Ohne Namen keine Zeile: eine Spec-Nummer sagt niemandem etwas, und
    -- "Spec 262" im Tooltip waere schlechter als nichts. Wer hier
    -- herausfaellt, darf aber auch nicht in der Restzahl weiterleben -
    -- sonst stehen null Zeilen da und darunter "und 26 weitere".
    local fremde = {}
    for _, row in ipairs(liste) do
        local specID = row[1]
        if specID ~= eigene then
            local name = ns.Compat.SpecName(specID)
            if name then
                local classID, classFile = ns.Compat.ClassOfSpec(specID)
                local className = ns.Compat.ClassName(classID)
                local text = className and (name .. " " .. className) or name
                if classFile then
                    text = ("|cff%s%s|r"):format(ns.Compat.ClassColor(classFile), text)
                end
                fremde[#fremde + 1] = {
                    name = text, pct = row[2],
                    mode = ns.ModeLabel(row[3]) or row[3],
                }
            end
        end
    end
    if #fremde == 0 then return {}, 0 end

    -- Nach Aktivitaet gruppieren, die Gruppen nach ihrem besten Anteil.
    local besteDerGruppe, reihenfolge = {}, {}
    for _, e in ipairs(fremde) do
        if besteDerGruppe[e.mode] == nil then
            besteDerGruppe[e.mode] = e.pct
            reihenfolge[#reihenfolge + 1] = e.mode
        elseif e.pct > besteDerGruppe[e.mode] then
            besteDerGruppe[e.mode] = e.pct
        end
    end
    table.sort(reihenfolge, function(a, b)
        if besteDerGruppe[a] ~= besteDerGruppe[b] then
            return besteDerGruppe[a] > besteDerGruppe[b]
        end
        -- Bei Gleichstand der Name: eine Reihenfolge, die sich zwischen
        -- zwei Tooltips nicht dreht.
        return a < b
    end)
    local rang = {}
    for i, mode in ipairs(reihenfolge) do rang[mode] = i end
    table.sort(fremde, function(a, b)
        if a.mode ~= b.mode then return rang[a.mode] < rang[b.mode] end
        if a.pct ~= b.pct then return a.pct > b.pct end
        return a.name < b.name
    end)

    local wieviele = alle and #fremde or math.min(#fremde, WORN_ZEILEN)
    local zeilen = {}
    for i = 1, wieviele do zeilen[i] = fremde[i] end
    return zeilen, #fremde - wieviele
end

-- --- Passen die Werte zu einer anderen Spec? -------------------------
--
-- Die Frage hinter jedem kriegsmeutegebundenen Drop: aufheben fuer einen
-- Twink oder zerlegen? Sie ist eine ANDERE als "wer traegt das" - die
-- beantwortet nur, was in M+ und Raid gemessen wurde, und ein Stueck aus
-- einer Tiefe steht dort nie. Diese hier haengt allein am Gegenstand und
-- an gemessenen Wertzielen und gilt deshalb fuer jedes Item, das der
-- Client kennt.
--
-- WELCHE KLASSE WELCHE RUESTUNG TRAEGT.
--
-- Die einzige von Hand geschriebene Tabelle in dieser Kette, und das
-- widerwillig: der Client beantwortet "darf Klasse X das anlegen" nur
-- fuer den Charakter, auf dem man steht. Die Zuordnung ist seit zwanzig
-- Jahren dieselbe, und die Pruefung haelt fest, dass jede Klasse genau
-- einmal vorkommt - eine neue Klasse faellt damit sofort auf.
local ARMOR = {
    [1] = { MAGE = true, PRIEST = true, WARLOCK = true },
    [2] = { ROGUE = true, DRUID = true, MONK = true, DEMONHUNTER = true },
    [3] = { HUNTER = true, SHAMAN = true, EVOKER = true },
    [4] = { WARRIOR = true, PALADIN = true, DEATHKNIGHT = true },
}

-- Hauptwerte, wie GetItemStats sie benennt.
local PRIMARY = {
    str = "ITEM_MOD_STRENGTH_SHORT",
    agi = "ITEM_MOD_AGILITY_SHORT",
    int = "ITEM_MOD_INTELLECT_SHORT",
}

-- Alle Speccs, einmal gesammelt. Ein Tooltip feuert bei jedem
-- Ueberfahren einer Tasche; dreizehn Klassen dabei jedes Mal neu
-- durchzufragen waere Arbeit fuer eine Antwort, die sich nie aendert.
local alleSpecs
local function specList()
    if alleSpecs then return alleSpecs end
    local out = {}
    for _, klasse in ipairs(ns.Compat.Classes()) do
        for _, spec in ipairs(ns.Compat.SpecsForClass(klasse.id)) do
            out[#out + 1] = { id = spec.id, file = klasse.file }
        end
    end
    if #out > 0 then alleSpecs = out end
    return out
end


-- Welche Spec fuehrt welchen Waffentyp?
--
-- Fuer Ruestung steht die Zuordnung oben als Tabelle; fuer Waffen waere
-- sie dreimal so lang, aendert sich mit jeder Erweiterung und muesste von
-- Hand gepflegt werden. Also wird sie GEMESSEN: wer in unseren Daten
-- einen Streitkolben traegt, kann offensichtlich einen fuehren.
--
-- Die Antwort steht nicht in den Daten, sondern beim Client - er kennt zu
-- jeder Gegenstandsnummer ihre Unterklasse. Gefragt wird einmal, beim
-- ersten Waffentooltip, und dann nie wieder: dreitausend Abfragen sind
-- einmal ein Wimpernschlag und bei jedem Ueberfahren einer Tasche eine
-- Zumutung.
local waffenSpecs

local function waffenKarte()
    if waffenSpecs then return waffenSpecs end
    local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(info) ~= "function" then return {} end
    local out = {}
    for _, spec in ipairs(specList()) do
        for _, mode in ipairs(ns.MODES or {}) do
            local gear = ns.Recommend.Gear(spec.id, mode.key, ns.Recommend.ALL)
            for _, liste in pairs(gear or {}) do
                for _, row in ipairs(liste) do
                    if row.id then
                        local ok, _, _, _, _, _, classID, subClassID =
                            pcall(info, row.id)
                        if ok and classID == 2 and subClassID then
                            out[subClassID] = out[subClassID] or {}
                            out[subClassID][spec.id] = true
                        end
                    end
                end
            end
        end
    end
    waffenSpecs = out
    return out
end

---Welche Speccs diese Waffenart in der Messung tragen.
---@param subClassID number
---@return table<number, boolean>
function Tooltip.WeaponSpecs(subClassID)
    return waffenKarte()[subClassID] or {}
end

---Welche Hauptwerte traegt dieses Stueck?
---
---ZWEI QUELLEN, und die zweite ist nicht Luxus: GetItemStats loest
---ein aufwertbares Stueck fuer den Charakter auf, der davorsteht. Die
---Druidin bekommt Intelligenz gemeldet, waehrend im Tooltip daneben
---grau "+135 Staerke" steht. Wer nur die Schnittstelle fragt, haelt
---eine Brustplatte fuer Zauberwerk.
---@param tip table|nil
---@param stats table|nil
---@return table<string, boolean> set, boolean irgendeiner
function Tooltip.Primaries(tip, stats)
    local out, einer = {}, false
    for key, mod in pairs(PRIMARY) do
        local wert = stats and stats[mod]
        if type(wert) == "number" and wert > 0 then
            out[key] = true
            einer = true
        end
    end
    -- Und was im Tooltip steht, auch wenn es grau ist.
    local name = tip and tip.GetName and tip:GetName()
    if name and tip.NumLines then
        for i = 2, tip:NumLines() do
            local line = _G[name .. "TextLeft" .. i]
            local text = line and line.GetText and line:GetText()
            if type(text) == "string" then
                for key, mod in pairs(PRIMARY) do
                    local wort = _G[mod]
                    if wort and wort ~= "" and text:find(wort, 1, true) then
                        out[key] = true
                        einer = true
                    end
                end
            end
        end
    end
    return out, einer
end

---Fuer welche Speccs passen die Zweitwerte dieses Stuecks?
---
---Gefiltert, bevor gerechnet wird: wer die Ruestungsart nicht traegt
---oder einen anderen Hauptwert hat, steht gar nicht erst zur Debatte.
---Ein Plattenteil mit Staerke taucht beim Schurken nicht auf.
---
---Sortiert nach der Summe der Raenge - das ist eine Reihenfolge und
---keine Behauptung. "Krit #1, Meisterschaft #2" sagt, wo die Werte
---dieses Stuecks in den GEMESSENEN Zielen jener Spec stehen; ob das
---Stueck ein Upgrade ist, sagt es nicht. Dafuer muesste das Addon
---wissen, was dort gerade getragen wird.
---@param link string|nil
---@param alle boolean|nil  true = vollstaendig, sonst gekuerzt
---@return table[] zeilen  je { name, text }
---@return number uebrig
function Tooltip.StatFit(link, alle, tip)
    if not link then return {}, 0 end
    local stats = ns.Compat.ItemStats(link)
    if not stats then return {}, 0 end

    -- Ruestung aus der Tabelle, Waffen aus der Messung. Alles andere -
    -- Steine, Verbrauchsgueter, Rezepte - beantwortet die Frage nicht.
    local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(info) ~= "function" then return {}, 0 end
    local ok, _, _, _, platz, _, classID, subClassID = pcall(info, link)
    if not ok or (classID ~= 4 and classID ~= 2) then return {}, 0 end

    -- EIN SCHMUCKSTUECK IST SEIN EFFEKT.
    --
    -- Was es taugt, entscheidet fast immer der Anlegeeffekt, und den
    -- misst hier niemand. Nach Werten geurteilt landet ein
    -- Tank-Schmuck bei der Eule, weil beide Meisterschaft oben
    -- messen. Wo ein Schmuckstueck wirklich getragen wird, steht es
    -- im Block darueber - der ist gemessen.
    if platz == "INVTYPE_TRINKET" then return {}, 0 end

    -- Umhaenge tragen die Unterklasse "Stoff", und jede Klasse traegt
    -- einen. Die Ruestungsart sagt hier nichts.
    local erlaubt = nil
    if classID == 4 and platz ~= "INVTYPE_CLOAK" then
        erlaubt = ARMOR[subClassID]
    end
    local fuehrt = classID == 2 and (waffenKarte()[subClassID] or {}) or nil
    -- Eine Waffenart, die in keiner Messung vorkommt, beantwortet die
    -- Frage nicht - dann schweigen wir, statt sie zu erfinden.
    if fuehrt and not next(fuehrt) then return {}, 0 end

    -- Traegt das Stueck Hauptwerte, muss EINER davon zur Spec passen.
    --
    -- Mehrzahl mit Absicht: ein aufwertbares Kriegsmeutenstueck fuehrt
    -- Staerke UND Intelligenz, bis es angelegt wird. Wer sich hier
    -- einen merkt, haelt eine Brustplatte fuer Zauberwerk und zeigt
    -- gar nichts mehr.
    --
    -- Ringe, Hals und Schmuck tragen keinen - dann faellt die Pruefung
    -- weg.
    local haupt, hatHaupt = Tooltip.Primaries(tip, stats)

    local mode = ns.Profile.Mode()
    local treffer = {}
    for _, spec in ipairs(specList()) do
        local passt = (not erlaubt) or erlaubt[spec.file]
        if fuehrt then passt = fuehrt[spec.id] == true end
        if passt and hatHaupt and not haupt[ns.Catalog.SpecStat(spec.id)] then
            passt = false
        end
        if passt then
            local ziele = ns.Recommend.Stats(spec.id, mode, ns.Recommend.ALL)
            local reihe = ziele and ziele.priority
            if reihe then
                local rang, summe, teile = {}, 0, {}
                for i, key in ipairs(reihe) do rang[key] = i end
                local draussen = false
                for _, key in ipairs(ns.SECONDARY) do
                    local wert = stats[MOD[key]]
                    if type(wert) == "number" and wert > 0 then
                        -- Ein Wert ohne Rang ist einer, den diese Spec
                        -- gar nicht misst: dann passt das Stueck nicht.
                        if not rang[key] or rang[key] > WERT_TOP then
                            draussen = true
                        else
                            summe = summe + rang[key]
                            teile[#teile + 1] = L["STAT_" .. key] .. " #" .. rang[key]
                        end
                    end
                end
                if #teile > 0 and not draussen then
                    local name = ns.Compat.SpecName(spec.id)
                    local className = ns.Compat.ClassName(select(1, ns.Compat.ClassOfSpec(spec.id)))
                    if name then
                        local text = className and (name .. " " .. className) or name
                        treffer[#treffer + 1] = {
                            specID = spec.id,
                            name = ("|cff%s%s|r"):format(ns.Compat.ClassColor(spec.file), text),
                            text = table.concat(teile, "  \194\183  "),
                            summe = summe, sortName = text,
                        }
                    end
                end
            end
        end
    end

    table.sort(treffer, function(a, b)
        if a.summe ~= b.summe then return a.summe < b.summe end
        return a.sortName < b.sortName
    end)

    local wieviele = alle and #treffer or math.min(#treffer, WORN_ZEILEN)
    local zeilen = {}
    for i = 1, wieviele do zeilen[i] = treffer[i] end
    return zeilen, #treffer - wieviele
end

-- Kann dieses Stueck ueberhaupt noch zu einem anderen Charakter?
--
-- Die Frage entscheidet, ob eine Zeile ueber FREMDE Speccs etwas nuetzt.
-- Was seelengebunden im Beutel liegt, erreicht keinen Twink mehr - dort
-- ist "auch gut fuer Schutz-Paladin" nur Laerm. Was kriegsmeutegebunden
-- ist, beim Anlegen bindet oder gar nicht bindet, kann wandern.
--
-- Gelesen wird Blizzards EIGENE Beschriftung, nicht unsere Uebersetzung:
-- ITEM_ACCOUNTBOUND_UNTIL_EQUIP heisst auf einem deutschen Client
-- "Kriegsmeutegebunden bis zum Ausruesten" und auf einem franzoesischen
-- etwas anderes. Wer den Text selbst hinschreibt, hat ihn in zwei
-- Sprachen falsch.
local BINDUNG_FREI = {
    "ITEM_ACCOUNTBOUND_UNTIL_EQUIP",
    "ITEM_BIND_ON_EQUIP",
    "ITEM_ACCOUNTBOUND",
    "ITEM_BNETACCOUNTBOUND",
}
local BINDUNG_FEST = {
    "ITEM_SOULBOUND",
    "ITEM_BIND_ON_PICKUP",
}

---Darf dieses Stueck noch wandern?
---
---Steht keine der Zeilen da, bindet es gar nicht - dann kann es ohnehin
---weitergegeben werden. Im Zweifel also ja: ein Stueck, ueber das wir
---nichts wissen, soll nicht stillschweigend eine Auskunft verlieren.
---@param tip table
---@return boolean
function Tooltip.CanMove(tip)
    local name = tip and tip.GetName and tip:GetName()
    if not name or not tip.NumLines then return true end
    local bis = math.min(tip:NumLines(), 8)
    for i = 2, bis do
        local line = _G[name .. "TextLeft" .. i]
        local text = line and line.GetText and line:GetText()
        if type(text) == "string" then
            for _, key in ipairs(BINDUNG_FREI) do
                if _G[key] and text == _G[key] then return true end
            end
            for _, key in ipairs(BINDUNG_FEST) do
                if _G[key] and text == _G[key] then return false end
            end
        end
    end
    return true
end

---Warum unter DIESEM Gegenstand nichts steht.
---
---Die Rechnung dahinter hat fuenf Stufen, und jede kann der Grund sein.
---Offline stimmten sie alle; im Spiel stand trotzdem nichts. Also sagt
---der Befehl Stufe fuer Stufe, was der Client hergibt - mit der Maus
---ueber dem Stueck, dann /mc fit.
function Tooltip.Why()
    local link = GameTooltip and GameTooltip.GetItem and select(2, GameTooltip:GetItem())
    if not link then
        ns.Print("Kein Gegenstand unter der Maus - Tooltip offen lassen und /mc fit.")
        return
    end
    local function sag(was, wert) ns.Print(("  %-26s %s"):format(was, tostring(wert))) end

    ns.Print("|cff8a6ff0MetaCodex|r  Warum steht da nichts?")
    sag("Link", (link:gsub("|", "||")))

    local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local ok, itemID, _, _, platz, _, classID, subClassID = pcall(info, link)
    sag("GetItemInfoInstant", ok and "ja" or "FEHLER")
    sag("  Gegenstand", tostring(itemID))
    sag("  Klasse / Unterklasse", tostring(classID) .. " / " .. tostring(subClassID))
    sag("  Platz", tostring(platz))

    local stats = ns.Compat.ItemStats(link)
    sag("GetItemStats", stats and "ja" or "NICHTS")
    if stats then
        local teile = {}
        for schluessel, wert in pairs(stats) do
            teile[#teile + 1] = schluessel .. "=" .. tostring(wert)
        end
        table.sort(teile)
        sag("  Werte", table.concat(teile, "  "))
    end

    sag("darf wandern", tostring(Tooltip.CanMove(GameTooltip)))
    local getragen = ns.Recommend.WornBy(itemID)
    sag("gemessen getragen von", #getragen .. " Speccs")

    local zeilen, uebrig = Tooltip.StatFit(link, true, GameTooltip)
    sag("Werte passen zu", #zeilen .. " Speccs (+" .. uebrig .. ")")
    for i = 1, math.min(#zeilen, 5) do
        sag("  " .. (zeilen[i].sortName or "?"), zeilen[i].text)
    end

    -- Und wo es haengt: drei Speccs einzeln durchgerechnet.
    local mode = ns.Profile.Mode()
    sag("Aktivitaet", tostring(mode))
    for _, specID in ipairs({ 70, 251, 102 }) do
        local ziele = ns.Recommend.Stats(specID, mode, ns.Recommend.ALL)
        local reihe = ziele and ziele.priority
        sag("  Spec " .. specID .. " Hauptwert",
            tostring(ns.Catalog.SpecStat(specID))
            .. "  Rangfolge: " .. (reihe and table.concat(reihe, ",") or "KEINE"))
    end
end

-- --------------------------------------------------------------- Anhaengen

---Die Beschriftungen, unter denen die Werte im Tooltip stehen.
---
---Vom Client, nicht von uns: auf einem deutschen Spiel steht dort
---"Tempo", auf einem franzoesischen etwas anderes. Sortiert wird nach
---Laenge, absteigend - "Tempo" steckt in "Tempolauf", und wer kurz
---zuerst sucht, haengt die Zahl an den falschen Wert.
local function labels()
    local out = {}
    for _, key in ipairs(ns.SECONDARY) do
        local text = _G[MOD[key]]
        if type(text) == "string" and text ~= "" then
            out[#out + 1] = { key = key, text = text }
        end
    end
    table.sort(out, function(a, b) return #a.text > #b.text end)
    return out
end

---Haengt die Rangnummern an die Wertzeilen des Tooltips.
---@param tip table
---@param ranks table
local function markStats(tip, ranks)
    local name = tip.GetName and tip:GetName()
    if not name or not tip.NumLines then return 0 end
    local order = labels()
    local marked = 0
    for i = 2, tip:NumLines() do
        local line = _G[name .. "TextLeft" .. i]
        local text = line and line.GetText and line:GetText()
        -- Eine Wertzeile faengt mit ihrer Zahl an: "+56 Meisterschaft".
        -- Ein Satz, in dem "Tempo" vorkommt - ein Set-Bonus, ein
        -- Anlegeeffekt -, ist keine, und dort haette die Nummer nichts
        -- zu suchen.
        local isStatLine = type(text) == "string" and text:find("^%+?[%d%.,%s]+%a") ~= nil
        if isStatLine and not text:find("|cff", 1, true) then
            for _, entry in ipairs(order) do
                if ranks[entry.key] and text:find(entry.text, 1, true) then
                    -- Hausfarbe, nicht Klassenfarbe: die Nummer soll
                    -- erkennbar von hier kommen, und der Akzent wandert
                    -- mit der angesehenen Klasse.
                    line:SetText(text .. "  |cff" .. ns.Style:Hex("brand")
                        .. "#" .. ranks[entry.key] .. "|r")
                    ranks[entry.key] = nil
                    marked = marked + 1
                    break
                end
            end
        end
    end
    return marked
end

---Der ganze Anbau an einen Gegenstands-Tooltip.
---@param tip table
---@param link string|nil
function Tooltip.Decorate(tip, link)
    if not ns.Profile.TooltipOn() then return end
    if not link then return end
    -- Erst laden, dann fragen - nicht umgekehrt.
    --
    -- Hier stand die Bereitschaftspruefung VOR dem Laden, und die kann
    -- vor dem Laden gar nicht wahr sein: die Tabellen liegen im
    -- nachladbaren Addon. Wer nie das Fenster oeffnete, sah deshalb nie
    -- eine Zahl im Tooltip - die Zeile stieg immer vorher aus. Das
    -- Fenster einmal aufmachen zu muessen, damit ein Tooltip etwas
    -- sagt, waere eine Zumutung.
    --
    -- Im Kampf wird allerdings nicht geladen: die Tabellen sind
    -- Megabytes, ihr Einlesen kostet einen Moment, und der gehoert
    -- nicht in einen Pull. Wer waehrend des Kampfes ueber ein Item
    -- faehrt, sieht dann eben nichts - nach dem Kampf holt es der
    -- naechste Tooltip nach.
    if not ns.Recommend.Ready() then
        if InCombatLockdown and InCombatLockdown() then return end
        if not ns.Data.Ensure() then return end
    end

    local itemID = tonumber(link:match("item:(%d+)"))

    -- Markiert wird, was im Tooltip STEHT - nicht, was die
    -- Gegenstandsschnittstelle zum Link zu sagen hat.
    --
    -- Der Unterschied ist kein Feinschliff. Ein Handwerksstueck traegt
    -- seine Zweitwerte ueber Bonus-IDs; fragt man den nackten Link,
    -- antwortet das Spiel mit "Zufallswert 1" und "Zufallswert 2", und
    -- die Rangnummern fielen genau dort weg, wo der Spieler sie sieht.
    -- Dasselbe beim Vergleichstooltip, dessen Link wir nicht kennen.
    -- Im Tooltip dagegen steht, was das Stueck wirklich hat - und die
    -- Reihenfolge der Werte haengt ohnehin an der Spec, nicht am
    -- Gegenstand.
    local marked = 0
    local all = priorityRanks()
    if all then marked = markStats(tip, all) end

    -- Fuer die Ersatzzeile weiter unten zaehlt weiter, was das Item
    -- laut Schnittstelle traegt: dort sollen nicht vier Werte stehen,
    -- wenn es zwei hat.
    local ranks = Tooltip.StatRanks(link)

    -- Keine Wertzeile getroffen, aber Raenge vorhanden?
    --
    -- Die Beschriftungen kommen vom Client, und wenn eine davon anders
    -- lautet als im Tooltip, faende die Suche nichts. Dann stehen die
    -- Raenge eben in einer eigenen Zeile - lieber so als gar nicht.
    local spare
    if ranks and marked == 0 then
        local parts = {}
        for _, key in ipairs(ns.SECONDARY) do
            if ranks[key] then
                parts[#parts + 1] = L["STAT_" .. key] .. " #" .. ranks[key]
            end
        end
        if #parts > 0 then spare = table.concat(parts, "  ") end
    end

    local rank, pct, total = Tooltip.GearRank(itemID)
    if rank then
        local text
        if rank == 1 then
            text = L["TIP_TOP"]:format(pct or 0)
        else
            text = L["TIP_RANK"]:format(rank, total or rank, pct or 0)
        end
        tip:AddLine("|cff" .. ns.Style:Hex("brand") .. "MetaCodex|r  " .. text, 1, 1, 1)
    end

    -- UND WER ES SONST NOCH TRAEGT.
    --
    -- Die Frage hinter jedem Stueck, das in die Kriegsmeute faellt:
    -- taugt es einem meiner anderen Charaktere? Gekuerzt, weil 163
    -- der gemessenen Stuecke von mehr als zehn Speccs getragen
    -- werden - die volle Liste gibt es auf Umschalt.
    -- NUR, WO DAS STUECK NOCH WANDERN KANN.
    --
    -- Beide Bloecke darunter beantworten dieselbe Frage: taugt das
    -- einem anderen Charakter? An einem seelengebundenen Stueck im
    -- eigenen Beutel ist die Frage gegenstandslos - und die Antwort
    -- darauf war der haeufigste Vorwurf am Tooltip: zu voll.
    local alle = IsShiftKeyDown and IsShiftKeyDown()
    local wandert = Tooltip.CanMove(tip)
    local zeilen, uebrig = {}, 0
    if wandert then zeilen, uebrig = Tooltip.WornLines(itemID, alle) end
    if #zeilen > 0 then
        -- Steht alles Gezeigte in derselben Aktivitaet, gehoert sie in
        -- die Ueberschrift. Bei zwei Zeilen ist das fast immer so, und
        -- eine eigene Zeile fuer ein einziges Wort ist Verschwendung.
        local eineGruppe = zeilen[1].mode
        for _, zeile in ipairs(zeilen) do
            if zeile.mode ~= eineGruppe then eineGruppe = nil end
        end
        tip:AddLine("|cff" .. ns.Style:Hex("brand") .. "MetaCodex|r  "
            .. L["TIP_WORN"]
            .. (eineGruppe and ("  \194\183  " .. eineGruppe) or ""), 1, 1, 1)
        -- Was die Zahlen darunter bedeuten - einmal, nicht je Zeile.
        tip:AddLine("  " .. L["TIP_WORN_HINT"], 0.6, 0.6, 0.6)
        -- Zwei Spalten: links die Spec, rechts ihr Anteil. Der Tooltip
        -- richtet die rechte Spalte selbst aus, und erst dadurch stehen
        -- vierzehn Zahlen untereinander statt hinter unterschiedlich
        -- langen Namen.
        local letzteGruppe
        for _, zeile in ipairs(zeilen) do
            if not eineGruppe and zeile.mode ~= letzteGruppe then
                tip:AddLine("  " .. zeile.mode, 0.6, 0.6, 0.6)
                letzteGruppe = zeile.mode
            end
            tip:AddDoubleLine("  " .. zeile.name, zeile.pct .. " %",
                1, 1, 1, 1, 1, 1)
        end
        if uebrig > 0 then
            tip:AddLine("  " .. L["TIP_WORN_MORE"]:format(uebrig), 0.6, 0.6, 0.6)
        end
    end

    -- UND FUER WEN DIE WERTE TAUGEN.
    --
    -- Die Zeile darueber sagt, wer das Stueck in M+ und Raid wirklich
    -- traegt; diese sagt, zu wessen gemessenen Wertzielen seine
    -- Zweitwerte passen. Das ist der Unterschied zwischen "gesehen"
    -- und "wuerde passen" - und nur die zweite Frage laesst sich bei
    -- einem Stueck aus einer Tiefe ueberhaupt stellen.
    -- NUR, WO DIE MESSUNG SCHWEIGT.
    --
    -- Steht oben schon, WER das Stueck traegt, ist das die bessere
    -- Auskunft - sie beruht auf Kaempfen und nicht auf der Vermutung,
    -- dass Werte passen koennten. Zwei Bloecke uebereinander waren im
    -- Spiel schlicht zu viel.
    local passend, passtUebrig = {}, 0
    if wandert and #zeilen == 0 then
        passend, passtUebrig = Tooltip.StatFit(link, alle, tip)
    end
    if #passend > 0 then
        tip:AddLine("|cff" .. ns.Style:Hex("brand") .. "MetaCodex|r  "
            .. L["TIP_FIT"], 1, 1, 1)
        for _, zeile in ipairs(passend) do
            tip:AddDoubleLine("  " .. zeile.name, zeile.text, 1, 1, 1, 1, 1, 1)
        end
        if passtUebrig > 0 then
            tip:AddLine("  " .. L["TIP_WORN_MORE"]:format(passtUebrig), 0.6, 0.6, 0.6)
        end
    end
    -- Wo das Item NICHT in der Liste steht, kommt auch keine Zeile
    -- dazu.
    --
    -- Hier stand ein Satz, der die Rangnummern erklaerte, und der stand
    -- dann unter jedem Gruenzeug, das man je anfasst. Einmal gelesen
    -- ist er verstanden, danach ist er Laerm. Die Nummern tragen die
    -- Hausfarbe, das genuegt als Absender.
    if spare then
        tip:AddLine("|cff" .. ns.Style:Hex("brand") .. "MetaCodex|r  " .. spare, 1, 1, 1)
    end
end

-- ------------------------------------------------------------------ Haken

-- Zwei Wege, denselben Anbau zu machen.
--
-- Der neue Client reicht Tooltips durch TooltipDataProcessor; der alte
-- feuert OnTooltipSetItem. Es wird genommen, was da ist - und nur eines
-- von beiden, sonst stuende die Zeile zweimal da.
local hooked = false
---Welcher Gegenstand steht in diesem Tooltip?
---
---GetItem beantwortet das fuer den Tooltip unter dem Zeiger. Fuer die
---VERGLEICHS-Tooltips daneben antwortet es nicht: die werden nicht
---"gesetzt", sondern mit Daten gefuellt, und deshalb standen die
---Rangnummern nur am angefassten Stueck und nicht an dem, das man
---anhat - also genau dort nicht, wo verglichen wird.
---
---Die Daten des Tooltips kennen den Gegenstand aber. Sie sind der
---zweite Weg.
---@param tip table
---@param data table|nil
---@return string|nil
local function linkOf(tip, data)
    if tip and tip.GetItem then
        local ok, _, link = pcall(tip.GetItem, tip)
        if ok and type(link) == "string" and link ~= "" then return link end
    end
    if data then
        if type(data.hyperlink) == "string" and data.hyperlink ~= "" then
            return data.hyperlink
        end
        if data.id then return "item:" .. data.id end
    end
    return nil
end

function Tooltip.Hook()
    if hooked then return end
    hooked = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,
            function(tip, data)
                local link = linkOf(tip, data)
                if link then pcall(Tooltip.Decorate, tip, link) end
            end)
    elseif GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetItem", function(tip)
            local link = linkOf(tip, nil)
            if link then pcall(Tooltip.Decorate, tip, link) end
        end)
        -- Die beiden Vergleichsfenster des alten Clients haben eigene
        -- Haken; ohne sie bliebe die Zahl dort aus.
        for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do
            local shop = _G[name]
            if shop and shop.HookScript then
                shop:HookScript("OnTooltipSetItem", function(tip)
                    local link = linkOf(tip, nil)
                    if link then pcall(Tooltip.Decorate, tip, link) end
                end)
            end
        end
    end
end
