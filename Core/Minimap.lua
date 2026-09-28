-- Der Knopf an der Minimap.
--
-- Ohne Bibliothek. LibDBIcon kann mehr, als dieses Addon braucht, und
-- jede mitgelieferte Bibliothek ist eine, die in einer anderen Version
-- schon im Speicher liegt. Was hier steht, ist der ganze Bedarf: ein
-- rundes Symbol auf dem Ring, ziehbar, und ein Schalter dafuer.
--
-- Die Lage ist ein WINKEL, keine Bildschirmkoordinate. Die Minimap
-- wandert mit der Aufloesung, ein gemerkter Punkt waere danach woanders;
-- ein Winkel sitzt immer auf demselben Fleck des Rings.

local _, ns = ...

local Minimap_ = {}
ns.Minimap = Minimap_

local ICON = "Interface\\AddOns\\MetaCodex\\Media\\Textures\\logo"

-- Wie weit der Knopf vom Mittelpunkt sitzt: knapp AUSSERHALB des Randes.
local GAP = 5

-- Welche Ecken einer Minimap rund sind.
--
-- Eine runde Minimap hat auf jedem Winkel denselben Abstand zur Mitte -
-- eine eckige nicht, und eine halbrunde erst recht nicht. Wer die Form
-- veraendert, sagt es ueber GetMinimapShape; das ist die Absprache, auf
-- die sich Addons seit Jahren verlassen. Die vier Eintraege stehen fuer
-- die vier Viertel, gegen den Uhrzeigersinn ab rechts unten.
local SHAPES = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local button

---Wo der Knopf zu einem Winkel sitzt.
---
---GEMESSEN, nicht geraten. Hier stand eine 80: der halbe Durchmesser
---der Blizzard-Minimap in ihrer Standardgroesse, plus ein bisschen. Wer
---sie skaliert oder ElvUI benutzt, bekam den Knopf mitten ins Bild -
---und bei einer eckigen Minimap sass er ueberhaupt nicht mehr am Rand.
---Also fragen wir die Minimap nach ihrer Groesse und ihrer Form.
---@param deg number Winkel in Grad
---@return number x
---@return number y
local function spotFor(deg)
    local angle = math.rad(deg)
    local x, y = math.cos(angle), math.sin(angle)

    -- In welchem Viertel liegt der Winkel.
    local quarter = 1
    if x < 0 then quarter = quarter + 1 end
    if y > 0 then quarter = quarter + 2 end

    local shape = (GetMinimapShape and GetMinimapShape()) or "ROUND"
    local round = SHAPES[shape] or SHAPES["ROUND"]

    -- tonumber, nicht "or 0": was die Minimap antwortet, ist nicht
    -- garantiert eine Zahl. Im Spiel ist sie es immer - aber ein
    -- Rechenfehler beim Anmelden nimmt das ganze Addon mit, und die
    -- Frage kostet nichts.
    local w = (tonumber(Minimap:GetWidth()) or 0) / 2 + GAP
    local h = (tonumber(Minimap:GetHeight()) or 0) / 2 + GAP
    -- Eine Minimap ohne Groesse gibt es nicht - ausser, sie ist noch
    -- nicht gebaut. Dann die alte Zahl, damit der Knopf irgendwo sitzt.
    if w <= GAP then w = 80 end
    if h <= GAP then h = 80 end

    if round[quarter] then
        return x * w, y * h
    end
    -- Eckiges Viertel: der Knopf laeuft die Kante entlang statt im Kreis.
    local diagW = math.sqrt(2 * w * w) - 10
    local diagH = math.sqrt(2 * h * h) - 10
    return math.max(-w, math.min(x * diagW, w)),
        math.max(-h, math.min(y * diagH, h))
end

local function place()
    if not button or not Minimap then return end
    local x, y = spotFor(ns.Profile.MinimapAngle())
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Der Winkel unter dem Mauszeiger, vom Mittelpunkt der Minimap aus.
local function angleAtCursor()
    if not Minimap or not GetCursorPosition then return nil end
    local mx, my = Minimap:GetCenter()
    if not mx then return nil end
    local scale = Minimap:GetEffectiveScale()
    if not scale or scale == 0 then scale = 1 end
    local cx, cy = GetCursorPosition()
    if not cx then return nil end
    -- atan2 gibt es in Lua 5.1 unter diesem Namen, spaeter nimmt atan
    -- zwei Argumente. Beides kommt vor, also beides annehmen.
    local atan2 = math.atan2 or math.atan
    return math.deg(atan2(cy / scale - my, cx / scale - mx))
end

local function build()
    if button or not Minimap then return end

    button = CreateFrame("Button", "MetaCodexMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap.GetFrameLevel and Minimap:GetFrameLevel() or 0) + 8)
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    button.background:SetSize(20, 20)
    button.background:SetPoint("CENTER")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(ICON)
    button.icon:SetSize(19, 19)
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
    button.ring:SetSize(53, 53)
    button.ring:SetPoint("TOPLEFT")

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            -- Rechtsklick fuehrt dorthin, wo der Knopf abzuschalten ist -
            -- das ist die ehrlichere Antwort als ein stilles Nichts.
            ns.UI.OpenSection("settings")
            return
        end
        ns.UI.Toggle()
    end)

    -- Ziehen: waehrend die Taste haengt, folgt der Knopf dem Zeiger auf
    -- dem Ring. Kein StartMoving - der Knopf soll den Ring nicht
    -- verlassen koennen.
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local angle = angleAtCursor()
            if angle then
                ns.Profile.SetMinimapAngle(angle)
                place()
            end
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("MetaCodex")
        GameTooltip:AddLine(ns.L["MINIMAP_CLICK"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(ns.L["MINIMAP_DRAG"], 0.4, 1, 0.4)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Aendert jemand die Groesse der Minimap - ElvUI beim Laden seines
    -- Profils, der Spieler ueber einen Regler -, sitzt der Knopf sonst
    -- weiter dort, wo der Rand frueher war.
    if Minimap.HookScript then
        Minimap:HookScript("OnSizeChanged", function() place() end)
    end

    place()
end

---Baut den Knopf, wenn er an ist, und zeigt oder versteckt ihn.
---Wird beim Login gerufen und jedes Mal, wenn der Schalter umgelegt wird.
function Minimap_.Update()
    if ns.Profile.MinimapOn() then
        build()
        if button then
            place()
            button:Show()
        end
    elseif button then
        button:Hide()
    end
    return button
end

---Nur fuer Tests und /mc probe: der Knopf, falls es ihn gibt.
function Minimap_.Button()
    return button
end
