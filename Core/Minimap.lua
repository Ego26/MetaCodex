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
local RADIUS = 80

local button

local function place()
    if not button or not Minimap then return end
    local angle = math.rad(ns.Profile.MinimapAngle())
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
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
