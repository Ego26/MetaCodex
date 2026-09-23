-- Die visuelle Sprache. Uebernommen aus egoUI (Core/Style.lua und
-- docs/02-UIUX-Konzept.md), damit beide Addons nebeneinander nicht wie
-- zwei Fremde aussehen.
--
-- Grundsatz, derselbe wie dort: kein Farbwert, keine Schriftgroesse und
-- keine Rahmenstaerke direkt im uebrigen Quelltext. Alles ueber ns.Style.
-- Sonst erfindet jeder Abschnitt sein eigenes Aussehen, und aus einem
-- Fenster werden sechs.
--
-- Was hier NICHT uebernommen wurde: egoUIs Mediensystem und seine
-- Profile. MetaCodex ist ein eigenstaendiges Addon und darf egoUI nicht
-- voraussetzen; wo dort `ego.Media` steht, steht hier der Rueckfall auf
-- Blizzards Schriften.

local _, ns = ...

local Style = {}
ns.Style = Style

local WHITE = "Interface\\Buttons\\WHITE8X8"

-- ------------------------------------------------------------- Farben

local PALETTE = {
    bgBase       = "0E1116",
    bgRaised     = "151A21",
    bgOverlay    = "1C222B",
    bgInset      = "0A0D11",
    bgHover      = "1E252F",

    borderSubtle = "232A34",
    borderStrong = "39424F",

    textPrimary   = "E8ECF1",
    textSecondary = "A3AEBD",
    textMuted     = "6B7786",

    accent      = "4C8DFF",
    accentHover = "6BA1FF",
    success     = "3FB950",
    warning     = "D29922",
    danger      = "F04D4D",
}

Style.tokens = {}

local function hexToParts(value)
    return tonumber(value:sub(1, 2), 16) / 255,
           tonumber(value:sub(3, 4), 16) / 255,
           tonumber(value:sub(5, 6), 16) / 255
end

local function setToken(name, hex)
    local r, g, b = hexToParts(hex)
    Style.tokens[name] = { r = r, g = g, b = b, hex = hex }
end

for name, hex in pairs(PALETTE) do setToken(name, hex) end

---@param token string
---@param alpha number|nil
---@return number r, number g, number b, number a
function Style:Color(token, alpha)
    local color = Style.tokens[token] or Style.tokens.textPrimary
    return color.r, color.g, color.b, alpha or 1
end

---Fuer Farbcodes im Text.
---@param token string
---@return string
function Style:Hex(token)
    local color = Style.tokens[token] or Style.tokens.textPrimary
    return color.hex
end

---Faerbt den Akzent auf die Klassenfarbe um.
---
---Ein Addon, das fuer eine bestimmte Klasse eingekauft wird, darf ruhig
---deren Farbe tragen - das ist hier keine Spielerei, sondern zeigt auf
---einen Blick, fuer wen die Liste gerade gilt.
---@param classFile string|nil "WARLOCK" o. ae., nil nimmt die Grundfarbe
function Style:SetAccentFromClass(classFile)
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if not color then
        setToken("accent", PALETTE.accent)
        setToken("accentHover", PALETTE.accentHover)
        return
    end
    -- %x will eine ganze Zahl. Ohne das Runden bricht die Formatierung,
    -- sobald eine Klassenfarbe keinen glatten Wert hat - also fast immer.
    local function byte(value) return math.floor(value * 255 + 0.5) end
    Style.tokens.accent = { r = color.r, g = color.g, b = color.b,
        hex = ("%02x%02x%02x"):format(byte(color.r), byte(color.g), byte(color.b)) }
    Style.tokens.accentHover = {
        r = math.min(1, color.r + 0.15),
        g = math.min(1, color.g + 0.15),
        b = math.min(1, color.b + 0.15),
        hex = Style.tokens.accent.hex,
    }
end

-- --------------------------------------------------------------- Masse

-- Basiseinheit 4 px, alle Abstaende sind Vielfache davon.
Style.space = { xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32 }

Style.font = { display = 20, title = 15, body = 13, caption = 11 }

-- ------------------------------------------------------------ Bausteine

---Rundet auf ganze Bildschirmpixel. Genau daran liegt es, wenn eine
---Oberflaeche verwaschen aussieht: ein 1-px-Rahmen, der keine ganze
---Pixelreihe trifft, wird grau statt scharf.
---@param value number
---@return number
function Style:Pixel(value)
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then return value end
    return math.max(1 / scale, math.floor(value * scale + 0.5) / scale)
end

---Vollflaechige Farbtextur.
---@param parent table
---@param token string
---@param alpha number|nil
---@param layer string|nil
---@return table
function Style:Fill(parent, token, alpha, layer)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetTexture(WHITE)
    texture:SetAllPoints(parent)
    texture:SetVertexColor(Style:Color(token, alpha))
    return texture
end

---Genau 1 px starker Rahmen aus vier Einzeltexturen.
---
---Blizzards Rahmengrafiken bringen ihre eigene Optik mit; vier Linien
---bringen keine.
---@param parent table
---@param token string
---@param alpha number|nil
---@param edges table|nil { top, bottom, left, right }
---@return table
function Style:Border(parent, token, alpha, edges)
    edges = edges or { top = true, bottom = true, left = true, right = true }
    local thickness = Style:Pixel(1)
    local lines = {}

    local function line(point1, point2, horizontal)
        local texture = parent:CreateTexture(nil, "BORDER")
        texture:SetTexture(WHITE)
        texture:SetVertexColor(Style:Color(token, alpha))
        texture:SetPoint(point1)
        texture:SetPoint(point2)
        if horizontal then texture:SetHeight(thickness) else texture:SetWidth(thickness) end
        return texture
    end

    if edges.top    then lines.top    = line("TOPLEFT", "TOPRIGHT", true) end
    if edges.bottom then lines.bottom = line("BOTTOMLEFT", "BOTTOMRIGHT", true) end
    if edges.left   then lines.left   = line("TOPLEFT", "BOTTOMLEFT", false) end
    if edges.right  then lines.right  = line("TOPRIGHT", "BOTTOMRIGHT", false) end
    return lines
end

---Eine Flaeche mit Grund und Rahmen - die Karte aus dem UI-Konzept.
---@param parent table
---@param bgToken string|nil
---@return table
function Style:Card(parent, bgToken)
    local frame = CreateFrame("Frame", nil, parent)
    frame.bg = Style:Fill(frame, bgToken or "bgRaised")
    frame.border = Style:Border(frame, "borderSubtle")
    return frame
end

-- ------------------------------------------------------------- Schrift

---Setzt Schrift, Groesse und Farbe.
---
---Die Kontur haengt an der Helligkeit: WoWs OUTLINE ist immer schwarz und
---nicht einfaerbbar - auf dunkler Schrift verschmilzt sie mit den Glyphen
---zu einem Klumpen.
---@param fontString table
---@param size number|string Punktzahl oder Rolle aus Style.font
---@param token string|nil
function Style:ApplyFont(fontString, size, token)
    local points = type(size) == "string" and Style.font[size] or size or Style.font.body
    local r, g, b = Style:Color(token or "textPrimary")

    local path = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local outline = (0.2126 * r + 0.7152 * g + 0.0722 * b) > 0.5

    fontString.__size = points
    fontString.__token = token or "textPrimary"

    fontString:SetFont(path, Style:Pixel(points), outline and "OUTLINE" or "")
    fontString:SetTextColor(r, g, b)
    fontString:SetShadowOffset(0, 0)
    if not outline then fontString:SetShadowColor(0, 0, 0, 0) end
end

---Erzeugt einen Text in einem Rahmen.
---@param parent table
---@param size number|string
---@param token string|nil
---@return table
function Style:Text(parent, size, token)
    local fontString = parent:CreateFontString(nil, "ARTWORK")
    Style:ApplyFont(fontString, size, token)
    fontString:SetJustifyH("LEFT")
    return fontString
end

---Faerbt um und entscheidet die Kontur neu. Nie SetTextColor direkt
---benutzen - sonst behaelt dunkler Text die schwarze Kontur.
---@param fontString table
---@param token string
function Style:Recolor(fontString, token)
    Style:ApplyFont(fontString, fontString.__size, token)
end
