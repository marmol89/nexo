-- Senda: interfaz
local ADDON, ns = ...

local W, H = 780, 560
local PAD = 14
local LEFT_W = 372
local ROW_H = 20
local LEVEL_ROWS = 13
local CHART_LEVELS = 20
local BAR_FULL = W - PAD * 2 - 24

local BD = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local ACC = { 0.72, 0.55, 1.00 }     -- violeta: experiencia
local REST = { 0.30, 0.62, 1.00 }    -- azul: descanso
local GREEN = { 0.29, 0.87, 0.5 }
local GOLD = { 1, 0.82, 0 }
local DASH = "|cff666666—|r"
local SOURCES = {
    { "k", "Muertes", { 1.00, 0.45, 0.45 } },
    { "q", "Misiones", { 1.00, 0.82, 0.00 } },
    { "e", "Exploración", { 0.29, 0.87, 0.50 } },
    { "o", "Otros", { 0.60, 0.60, 0.66 } },
}
local SCOPES = { { "session", "Sesión" }, { "level", "Nivel" }, { "all", "Todo" } }

-- filter = clave del personaje que se está viendo
local state = { filter = nil, scope = "session" }

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
local function Panel(parent, bg, border)
    local f = CreateFrame("Frame", nil, parent, TEMPLATE)
    f:SetBackdrop(BD)
    bg = bg or { 0.08, 0.09, 0.11, 0.92 }
    border = border or { 0.21, 0.17, 0.28, 1 }
    f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    f:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
    return f
end

local function Text(parent, size, template, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlight")
    if size then
        local font, _, flags = fs:GetFont()
        fs:SetFont(font, size, flags)
    end
    return fs
end

local function Tex(parent, layer, r, g, b, a, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local function ClassHex(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return "ffffffff" end
    return ("ff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
end

local function ShortName(key) return (key:match("^(.-) %- ") or key) end

local function Pct(v)
    return (("%.1f"):format(v):gsub("%.", ",")) .. " %"
end

local function DateLabel(t)
    if ns.DayKey(t) == ns.DayKey() then return "Hoy " .. date("%H:%M", t) end
    if ns.DayKey(t) == ns.DayKey(time() - 86400) then return "Ayer " .. date("%H:%M", t) end
    return date("%d/%m/%y %H:%M", t)
end

local function Button(parent, w, h, label, onClick, size)
    local b = CreateFrame("Button", nil, parent, TEMPLATE)
    b:SetSize(w, h)
    b:SetBackdrop(BD)
    b.text = Text(b, size or 12)
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    function b:SetActive(on)
        self.active = on
        if on then
            self:SetBackdropColor(0.20, 0.12, 0.34, 1)
            self:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 1)
            self.text:SetTextColor(0.90, 0.82, 1)
        else
            self:SetBackdropColor(0.11, 0.12, 0.14, 1)
            self:SetBackdropBorderColor(0.26, 0.22, 0.32, 1)
            self.text:SetTextColor(0.85, 0.85, 0.85)
        end
    end
    b:SetActive(false)
    b:SetScript("OnEnter", function(s) if not s.active then s:SetBackdropBorderColor(0.55, 0.42, 0.80, 1) end end)
    b:SetScript("OnLeave", function(s) if not s.active then s:SetBackdropBorderColor(0.26, 0.22, 0.32, 1) end end)
    b:SetScript("OnClick", onClick)
    return b
end

local function SectionTitle(parent, label)
    local t = Text(parent, 12, "GameFontNormal")
    t:SetPoint("TOPLEFT", 10, -8)
    t:SetText(label)
    t:SetTextColor(ACC[1], ACC[2], ACC[3])
    local line = Tex(parent, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.25)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 8, -24)
    line:SetPoint("TOPRIGHT", -8, -24)
    return t
end

-- Tooltip común de un nivel (gráfico y lista)
local function LevelTooltip(owner, e, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:AddLine("Nivel " .. e.lvl .. (e.current and "  |cff4ade80(en curso)|r" or ""), ACC[1], ACC[2], ACC[3])
    GameTooltip:AddDoubleLine("Tiempo en el nivel", ns.Dur(e.sec), 0.7, 0.7, 0.7, 1, 1, 1)
    if e.xp > 0 then
        GameTooltip:AddDoubleLine("Experiencia registrada", ns.Num(e.xp), 0.7, 0.7, 0.7, 1, 1, 1)
    end
    if e.rate then
        GameTooltip:AddDoubleLine("Ritmo medio", ns.Num(e.rate) .. " exp/h", 0.7, 0.7, 0.7, 1, 1, 1)
    end
    if e.xp > 0 then
        GameTooltip:AddLine(" ")
        for _, src in ipairs(SOURCES) do
            local v = e[src[1]]
            if v > 0 then
                local label = src[2]
                if src[1] == "k" and e.nk > 0 then label = label .. " (" .. e.nk .. ")" end
                if src[1] == "q" and e.nq > 0 then label = label .. " (" .. e.nq .. ")" end
                GameTooltip:AddDoubleLine(label, ns.Num(v) .. "  " .. math.floor(v / e.xp * 100 + 0.5) .. "%",
                    src[3][1], src[3][2], src[3][3], 1, 1, 1)
            end
        end
    end
    if e.at or e.done then GameTooltip:AddLine(" ") end
    if e.at then GameTooltip:AddDoubleLine("Alcanzado", date("%d/%m/%Y %H:%M", e.at), 0.7, 0.7, 0.7, 1, 1, 1) end
    if e.done then GameTooltip:AddDoubleLine("Completado", date("%d/%m/%Y %H:%M", e.done), 0.7, 0.7, 0.7, 1, 1, 1) end
    if e.partXP then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Senda se instaló con este nivel ya empezado:", 0.6, 0.6, 0.6)
        GameTooltip:AddLine(e.partTime and "el tiempo y la experiencia son parciales." or "la experiencia registrada es parcial.", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Ventana principal
---------------------------------------------------------------------------
local main = CreateFrame("Frame", "SendaMainFrame", UIParent, TEMPLATE)
main:SetSize(W, H)
main:SetPoint("CENTER")
main:SetFrameStrata("HIGH")
main:SetToplevel(true)
main:SetBackdrop(BD)
main:SetBackdropColor(0.04, 0.04, 0.05, 0.96)
main:SetBackdropBorderColor(0.46, 0.34, 0.68, 1)
main:EnableMouse(true)
main:SetMovable(true)
main:SetClampedToScreen(true)
main:RegisterForDrag("LeftButton")
main:SetScript("OnDragStart", main.StartMoving)
main:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    local p, _, rp, x, y = s:GetPoint()
    ns.db.settings.pos = { p, rp, x, y }
end)
main:Hide()
tinsert(UISpecialFrames, "SendaMainFrame")

-- Cabecera
local header = Tex(main, "BACKGROUND", 0.10, 0.07, 0.17, 1, 1)
header:SetPoint("TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", -1, -1)
header:SetHeight(50)
local headerLine = Tex(main, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.6)
headerLine:SetHeight(1)
headerLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
headerLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")

local logo = main:CreateTexture(nil, "ARTWORK")
logo:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
logo:SetSize(34, 34)
logo:SetPoint("TOPLEFT", 12, -9)

local title = Text(main, 20, "GameFontNormalLarge")
title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -1)
title:SetText("Senda")
title:SetTextColor(ACC[1], ACC[2], ACC[3])

local subtitle = Text(main, 11)
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
subtitle:SetTextColor(0.62, 0.55, 0.74)
subtitle:SetText("Subida de nivel · WoW Forever")

-- Botón cerrar
local close = CreateFrame("Button", nil, main, TEMPLATE)
close:SetSize(24, 24)
close:SetPoint("TOPRIGHT", -12, -13)
close:SetBackdrop(BD)
close:SetBackdropColor(0.10, 0.07, 0.15, 1)
close:SetBackdropBorderColor(0.36, 0.27, 0.52, 1)
local closeX1 = Tex(close, "ARTWORK", 0.88, 0.80, 0.98, 1)
closeX1:SetSize(14, 2)
closeX1:SetPoint("CENTER")
closeX1:SetRotation(math.rad(45))
local closeX2 = Tex(close, "ARTWORK", 0.88, 0.80, 0.98, 1)
closeX2:SetSize(14, 2)
closeX2:SetPoint("CENTER")
closeX2:SetRotation(math.rad(-45))
close:SetScript("OnEnter", function(s)
    s:SetBackdropColor(0.55, 0.12, 0.10, 1)
    s:SetBackdropBorderColor(1, 0.4, 0.3, 1)
end)
close:SetScript("OnLeave", function(s)
    s:SetBackdropColor(0.10, 0.07, 0.15, 1)
    s:SetBackdropBorderColor(0.36, 0.27, 0.52, 1)
end)
close:SetScript("OnClick", function() main:Hide() end)

-- Selector de personaje
local charBtn
charBtn = Button(main, 210, 24, "", function(_, mouse)
    local list = ns.CharList()
    if #list == 0 then return end
    local idx = 1
    for i, k in ipairs(list) do if k == state.filter then idx = i end end
    if mouse == "RightButton" then idx = idx - 1 else idx = idx + 1 end
    if idx > #list then idx = 1 elseif idx < 1 then idx = #list end
    state.filter = list[idx]
    ns.Refresh()
end)
charBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
charBtn:SetPoint("RIGHT", close, "LEFT", -10, 0)
local charArrows = Text(charBtn, 11)
charArrows:SetPoint("RIGHT", -8, 0)
charArrows:SetText("|cff888888< >|r")
charBtn:HookScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Personaje")
    GameTooltip:AddLine("Clic izquierdo: siguiente", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Clic derecho: anterior", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
charBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------
-- Barra de progreso del nivel
---------------------------------------------------------------------------
local prog = Panel(main, { 0.08, 0.08, 0.10, 1 })
prog:SetPoint("TOPLEFT", PAD, -62)
prog:SetPoint("TOPRIGHT", -PAD, -62)
prog:SetHeight(54)

local progFrom = Text(prog, 13)
progFrom:SetPoint("TOPLEFT", 12, -9)
progFrom:SetTextColor(ACC[1], ACC[2], ACC[3])
local progTo = Text(prog, 13)
progTo:SetPoint("TOPRIGHT", -12, -9)
progTo:SetTextColor(0.6, 0.6, 0.6)
local progInfo = Text(prog, 11)
progInfo:SetPoint("TOP", 0, -10)

local barBg = Tex(prog, "BACKGROUND", 1, 1, 1, 0.06, 2)
barBg:SetPoint("BOTTOMLEFT", 12, 10)
barBg:SetSize(BAR_FULL, 14)
local barFill = Tex(prog, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.95)
barFill:SetHeight(14)
barFill:SetPoint("LEFT", barBg, "LEFT", 0, 0)
local barRest = Tex(prog, "ARTWORK", REST[1], REST[2], REST[3], 0.45)
barRest:SetHeight(14)
for i = 1, 9 do   -- marcas cada 10 %
    local tick = Tex(prog, "OVERLAY", 0, 0, 0, 0.45)
    tick:SetSize(1, 14)
    tick:SetPoint("LEFT", barBg, "LEFT", BAR_FULL * i / 10, 0)
end

---------------------------------------------------------------------------
-- Tarjetas resumen
---------------------------------------------------------------------------
local cards = {}
local CARD_W = (W - PAD * 2 - 10 * 3) / 4
local cardDefs = {
    { "Experiencia por hora", ACC, "Interface\\Icons\\INV_Misc_PocketWatch_01" },
    { "Para subir de nivel", GOLD, "Interface\\Icons\\INV_Misc_Map_01" },
    { "Esta sesión", GREEN, "Interface\\Icons\\INV_Misc_Note_01" },
    { "En este nivel", REST, "Interface\\Icons\\INV_Misc_Book_09" },
}
for i, def in ipairs(cardDefs) do
    local c = Panel(main, { 0.08, 0.08, 0.10, 1 })
    c:SetSize(CARD_W, 66)
    c:SetPoint("TOPLEFT", PAD + (i - 1) * (CARD_W + 10), -124)
    local accent = Tex(c, "ARTWORK", def[2][1], def[2][2], def[2][3], 1)
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("BOTTOMLEFT", 1, 1)
    accent:SetWidth(3)
    local glow = Tex(c, "BACKGROUND", def[2][1], def[2][2], def[2][3], 0.06, 2)
    glow:SetPoint("TOPLEFT", 4, -1)
    glow:SetPoint("BOTTOMLEFT", 4, 1)
    glow:SetWidth(60)
    local ic = c:CreateTexture(nil, "ARTWORK")
    ic:SetTexture(def[3])
    ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ic:SetSize(22, 22)
    ic:SetPoint("TOPRIGHT", -8, -8)
    ic:SetAlpha(0.85)
    c.label = Text(c, 11)
    c.label:SetPoint("TOPLEFT", 12, -9)
    c.label:SetTextColor(0.65, 0.65, 0.65)
    c.label:SetText(def[1]:upper())
    c.value = Text(c, 16)
    c.value:SetPoint("TOPLEFT", 12, -26)
    c.value:SetPoint("RIGHT", -6, 0)
    c.value:SetJustifyH("LEFT")
    c.value:SetWordWrap(false)
    c.value:SetTextColor(def[2][1], def[2][2], def[2][3])
    c.sub = Text(c, 10)
    c.sub:SetPoint("BOTTOMLEFT", 12, 8)
    c.sub:SetPoint("RIGHT", -6, 0)
    c.sub:SetJustifyH("LEFT")
    c.sub:SetWordWrap(false)
    c.sub:SetTextColor(0.55, 0.55, 0.55)
    cards[i] = c
end

---------------------------------------------------------------------------
-- Gráfico: tiempo por nivel
---------------------------------------------------------------------------
local TOP_Y = -198
local FOOT_H = 30
local contentH = H + TOP_Y - FOOT_H - 8
local CHART_H = 170

local chart = Panel(main)
chart:SetPoint("TOPLEFT", PAD, TOP_Y)
chart:SetSize(LEFT_W, CHART_H)
SectionTitle(chart, "Tiempo por nivel")
local chartHint = Text(chart, 9)
chartHint:SetPoint("TOPRIGHT", -10, -11)
chartHint:SetTextColor(0.45, 0.45, 0.45)
chartHint:SetText("últimos " .. CHART_LEVELS .. " niveles")

local PLOT_H = 104
local PLOT_BOTTOM = 22
local slotW = (LEFT_W - 20) / CHART_LEVELS
local baseLine = Tex(chart, "ARTWORK", 1, 1, 1, 0.15)
baseLine:SetHeight(1)
baseLine:SetPoint("BOTTOMLEFT", 10, PLOT_BOTTOM)
baseLine:SetPoint("BOTTOMRIGHT", -10, PLOT_BOTTOM)

local gridLabels = {}
for i, frac in ipairs({ 0.5, 1 }) do
    local g = Tex(chart, "BACKGROUND", 1, 1, 1, 0.05, 2)
    g:SetHeight(1)
    g:SetPoint("BOTTOMLEFT", 10, PLOT_BOTTOM + PLOT_H * frac)
    g:SetPoint("BOTTOMRIGHT", -10, PLOT_BOTTOM + PLOT_H * frac)
    local l = Text(chart, 9)
    l:SetPoint("BOTTOMRIGHT", g, "TOPRIGHT", 0, 1)
    l:SetTextColor(0.45, 0.45, 0.45)
    gridLabels[i] = { frac = frac, fs = l }
end

local slots = {}
for i = 1, CHART_LEVELS do
    local s = CreateFrame("Frame", nil, chart)
    s:SetSize(slotW, PLOT_H + PLOT_BOTTOM)
    s:SetPoint("BOTTOMLEFT", 10 + (i - 1) * slotW, 0)
    s:EnableMouse(true)
    s.hl = Tex(s, "BACKGROUND", ACC[1], ACC[2], ACC[3], 0.08, 3)
    s.hl:SetPoint("TOPLEFT", 1, 0)
    s.hl:SetPoint("BOTTOMRIGHT", -1, PLOT_BOTTOM)
    s.hl:Hide()
    s.bar = Tex(s, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.95)
    s.bar:SetWidth(math.max(4, math.floor(slotW - 6)))
    s.bar:SetPoint("BOTTOM", s, "BOTTOM", 0, PLOT_BOTTOM + 1)
    s.label = Text(s, 9)
    s.label:SetPoint("BOTTOM", 0, 6)
    s:SetScript("OnEnter", function(self)
        self.hl:Show()
        if self.data then LevelTooltip(self, self.data) end
    end)
    s:SetScript("OnLeave", function(self) self.hl:Hide() GameTooltip:Hide() end)
    slots[i] = s
end

local chartEmpty = Text(chart, 11)
chartEmpty:SetPoint("CENTER", 0, 4)
chartEmpty:SetTextColor(0.5, 0.5, 0.5)
chartEmpty:SetText("Aún no hay tiempo registrado")

---------------------------------------------------------------------------
-- De dónde viene la experiencia
---------------------------------------------------------------------------
local SRC_BAR_W = 96
local srcPanel = Panel(main)
srcPanel:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", 0, -8)
srcPanel:SetSize(LEFT_W, contentH - CHART_H - 8)
SectionTitle(srcPanel, "De dónde viene la experiencia")

local scopeBtns = {}
for i = #SCOPES, 1, -1 do
    local sc = SCOPES[i]
    local b = Button(srcPanel, 50, 17, sc[2], function()
        state.scope = sc[1]
        ns.Refresh()
    end, 10)
    b.key = sc[1]
    if i == #SCOPES then b:SetPoint("TOPRIGHT", -8, -4) else b:SetPoint("RIGHT", scopeBtns[i + 1], "LEFT", -4, 0) end
    scopeBtns[i] = b
end

local srcRows = {}
for i, src in ipairs(SOURCES) do
    local r = CreateFrame("Frame", nil, srcPanel)
    r:SetSize(LEFT_W - 16, 24)
    r:SetPoint("TOPLEFT", 8, -32 - (i - 1) * 25)
    r:EnableMouse(true)
    r.hl = Tex(r, "BACKGROUND", ACC[1], ACC[2], ACC[3], 0.08)
    r.hl:SetAllPoints()
    r.hl:Hide()
    r.swatch = Tex(r, "ARTWORK", src[3][1], src[3][2], src[3][3], 1)
    r.swatch:SetSize(3, 18)
    r.swatch:SetPoint("LEFT", 0, 0)
    r.name = Text(r, 11)
    r.name:SetPoint("LEFT", 9, 0)
    r.name:SetWidth(120)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.name:SetTextColor(src[3][1], src[3][2], src[3][3])
    r.pct = Text(r, 10)
    r.pct:SetPoint("LEFT", 130, 0)
    r.pct:SetWidth(34)
    r.pct:SetJustifyH("RIGHT")
    r.pct:SetTextColor(0.6, 0.6, 0.6)
    r.barBg = Tex(r, "BACKGROUND", 1, 1, 1, 0.05, 2)
    r.barBg:SetSize(SRC_BAR_W, 8)
    r.barBg:SetPoint("LEFT", 172, 0)
    r.bar = Tex(r, "ARTWORK", src[3][1], src[3][2], src[3][3], 0.9)
    r.bar:SetHeight(8)
    r.bar:SetPoint("LEFT", r.barBg, "LEFT", 0, 0)
    r.amount = Text(r, 10)
    r.amount:SetPoint("RIGHT", -4, 0)
    r.amount:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(self)
        self.hl:Show()
        local d = self.data
        if not d then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(src[2], src[3][1], src[3][2], src[3][3])
        GameTooltip:AddDoubleLine("Experiencia", ns.Num(d.xp), 0.7, 0.7, 0.7, 1, 1, 1)
        if d.n and d.n > 0 then
            GameTooltip:AddDoubleLine(src[1] == "k" and "Muertes con experiencia" or "Misiones entregadas", ns.Num(d.n), 0.7, 0.7, 0.7, 1, 1, 1)
            GameTooltip:AddDoubleLine("Media", ns.Num(d.xp / d.n) .. " exp", 0.7, 0.7, 0.7, 1, 1, 1)
        end
        if src[1] == "o" then
            GameTooltip:AddLine("Ganancias cuyo origen no se pudo identificar.", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function(self) self.hl:Hide() GameTooltip:Hide() end)
    srcRows[i] = r
end
local srcEmpty = Text(srcPanel, 11)
srcEmpty:SetPoint("BOTTOM", 0, 6)
srcEmpty:SetTextColor(0.5, 0.5, 0.5)

---------------------------------------------------------------------------
-- Lista de niveles
---------------------------------------------------------------------------
local lv = Panel(main)
lv:SetPoint("TOPLEFT", chart, "TOPRIGHT", 10, 0)
lv:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, TOP_Y)
lv:SetHeight(contentH)
SectionTitle(lv, "Niveles")
local lvCount = Text(lv, 10)
lvCount:SetPoint("TOPRIGHT", -10, -10)
lvCount:SetTextColor(0.55, 0.55, 0.55)

local COLS = { { "NIVEL", 8, 60, "LEFT" }, { "TIEMPO", 72, 70, "RIGHT" }, { "EXP/H", 150, 70, "RIGHT" } }
for _, col in ipairs(COLS) do
    local h = Text(lv, 9)
    h:SetPoint("TOPLEFT", 6 + col[2], -31)
    h:SetWidth(col[3])
    h:SetJustifyH(col[4])
    h:SetTextColor(0.5, 0.5, 0.5)
    h:SetText(col[1])
end
local lvHeadDone = Text(lv, 9)
lvHeadDone:SetPoint("TOPRIGHT", -30, -31)
lvHeadDone:SetTextColor(0.5, 0.5, 0.5)
lvHeadDone:SetText("COMPLETADO")

local scroll = CreateFrame("ScrollFrame", "SendaLevelScroll", lv, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 4, -46)
scroll:SetPoint("BOTTOMRIGHT", -26, 6)

local lvData = {}
local lvRows = {}
local UpdateLevels

for i = 1, LEVEL_ROWS do
    local r = CreateFrame("Frame", nil, lv)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 6, -46 - (i - 1) * ROW_H)
    r:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
    r:EnableMouse(true)
    r.bg = Tex(r, "BACKGROUND", 1, 1, 1, (i % 2 == 0) and 0.03 or 0)
    r.bg:SetAllPoints()
    r.hl = Tex(r, "BACKGROUND", ACC[1], ACC[2], ACC[3], 0.08, 1)
    r.hl:SetAllPoints()
    r.hl:Hide()
    r.level = Text(r, 11)
    r.level:SetPoint("LEFT", COLS[1][2], 0)
    r.level:SetWidth(COLS[1][3])
    r.level:SetJustifyH("LEFT")
    r.time = Text(r, 11)
    r.time:SetPoint("LEFT", COLS[2][2], 0)
    r.time:SetWidth(COLS[2][3])
    r.time:SetJustifyH("RIGHT")
    r.rate = Text(r, 11)
    r.rate:SetPoint("LEFT", COLS[3][2], 0)
    r.rate:SetWidth(COLS[3][3])
    r.rate:SetJustifyH("RIGHT")
    r.done = Text(r, 10)
    r.done:SetPoint("RIGHT", -4, 0)
    r.done:SetJustifyH("RIGHT")
    r.done:SetTextColor(0.6, 0.6, 0.6)
    r:SetScript("OnEnter", function(self)
        self.hl:Show()
        if self.data then LevelTooltip(self, self.data, "ANCHOR_LEFT") end
    end)
    r:SetScript("OnLeave", function(self) self.hl:Hide() GameTooltip:Hide() end)
    lvRows[i] = r
end

function UpdateLevels()
    local offset = FauxScrollFrame_GetOffset(scroll)
    FauxScrollFrame_Update(scroll, #lvData, LEVEL_ROWS, ROW_H)
    for i = 1, LEVEL_ROWS do
        local r = lvRows[i]
        local e = lvData[offset + i]
        r.data = e
        if e then
            r.level:SetText((e.current and "|cff4ade80" or "|cffb88cff") .. "Nivel " .. e.lvl .. "|r")
            r.time:SetText((e.partTime and "|cff8c8c9e" or "") .. ns.Dur(e.sec) .. (e.partTime and "+|r" or ""))
            r.rate:SetText(e.rate and ns.Num(e.rate) or DASH)
            if e.current then
                r.done:SetText("|cff4ade80en curso|r")
            elseif e.done then
                r.done:SetText(DateLabel(e.done))
            else
                r.done:SetText(DASH)
            end
            r:Show()
        else
            r:Hide()
        end
    end
end
scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, UpdateLevels)
end)

---------------------------------------------------------------------------
-- Pie
---------------------------------------------------------------------------
local footLine = Tex(main, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.2)
footLine:SetHeight(1)
footLine:SetPoint("BOTTOMLEFT", 1, FOOT_H)
footLine:SetPoint("BOTTOMRIGHT", -1, FOOT_H)

local footer = Text(main, 11)
footer:SetPoint("BOTTOMLEFT", PAD, 10)
footer:SetTextColor(0.75, 0.75, 0.75)

local footRight = Text(main, 10)
footRight:SetPoint("BOTTOMRIGHT", -PAD, 10)
footRight:SetTextColor(0.45, 0.45, 0.45)
footRight:SetText("/senda ayuda")

---------------------------------------------------------------------------
-- Refrescar todo
---------------------------------------------------------------------------
function ns.Refresh()
    if not main:IsShown() or not ns.db then return end
    if not state.filter or not ns.db.chars[state.filter] then state.filter = ns.charKey end
    local key = state.filter
    local c = ns.db.chars[key]
    local live = (key == ns.charKey)
    local lvl = c.level or 0
    local xp, mx = c.xp or 0, c.xpMax or 0
    local atMax = mx <= 0
    local rec = c.levels[lvl]

    charBtn.text:SetText("|c" .. ClassHex(c.class) .. ShortName(key) .. "|r  |cff888888nivel " .. (lvl > 0 and lvl or "?") .. "|r")

    -- Barra de progreso
    progFrom:SetText("Nivel " .. (lvl > 0 and lvl or "?"))
    if atMax then
        progTo:SetText("")
        progInfo:SetText(lvl > 0 and "Sin experiencia que ganar en este nivel" or "Entra con este personaje para ver su progreso")
        barFill:Hide()
        barRest:Hide()
    else
        local frac = math.min(1, xp / mx)
        progTo:SetText("Nivel " .. (lvl + 1))
        progInfo:SetText(ns.Num(xp) .. " / " .. ns.Num(mx) .. "  |cffb88cff" .. Pct(frac * 100) .. "|r  |cff888888· faltan " .. ns.Num(mx - xp) .. "|r")
        barFill:SetWidth(math.max(1, BAR_FULL * frac))
        barFill:SetShown(xp > 0)
        local rest = math.min(c.rested or 0, mx - xp)
        barRest:ClearAllPoints()
        barRest:SetPoint("LEFT", barBg, "LEFT", BAR_FULL * frac, 0)
        barRest:SetWidth(math.max(1, BAR_FULL * rest / mx))
        barRest:SetShown(rest > 0)
    end

    -- Tarjetas
    local s = ns.session
    if live and s then
        local rate, recent = ns.Rates()
        if rate > 0 then
            cards[1].value:SetText(ns.Num(rate))
            cards[1].sub:SetText("Últimos 15 min: " .. ns.Num(recent))
        else
            cards[1].value:SetText(DASH)
            cards[1].sub:SetText("Gana experiencia para calcularlo")
        end

        local eta, left = ns.ETA()
        if atMax then
            cards[2].value:SetText(DASH)
            cards[2].sub:SetText("Nivel máximo")
        elseif eta then
            cards[2].value:SetText(ns.Dur(eta))
            local sub = "Hacia las " .. date("%H:%M", time() + eta)
            local kills = ns.KillsLeft()
            if kills then sub = sub .. " · ~" .. ns.Num(kills) .. " muertes" end
            cards[2].sub:SetText(sub)
        else
            cards[2].value:SetText(DASH)
            cards[2].sub:SetText("Faltan " .. ns.Num(left) .. " de experiencia")
        end

        cards[3].value:SetText(ns.Num(s.xp))
        local sub = ns.Dur(s.sec)
        if s.l1 and s.l0 and s.l1 > s.l0 then sub = sub .. " · nivel " .. s.l0 .. " > " .. s.l1 end
        cards[3].sub:SetText(sub)
    else
        for i = 1, 3 do
            cards[i].value:SetText(DASH)
            cards[i].sub:SetText("Solo con el personaje conectado")
        end
    end

    if rec and rec.sec > 0 then
        cards[4].value:SetText(ns.Dur(rec.sec) .. ((rec.part and not rec.real) and "+" or ""))
    else
        cards[4].value:SetText(DASH)
    end
    if not atMax and (c.rested or 0) > 0 then
        cards[4].sub:SetText("Descanso: " .. ns.Num(c.rested) .. " (" .. math.floor(c.rested / mx * 100 + 0.5) .. "%)")
    else
        cards[4].sub:SetText("Sin experiencia de descanso")
    end

    -- Niveles
    lvData = ns.LevelList(key)
    lvCount:SetText(#lvData .. (#lvData == 1 and " nivel" or " niveles"))
    UpdateLevels()

    -- Gráfico
    local byLvl, maxV = {}, 60
    for _, e in ipairs(lvData) do byLvl[e.lvl] = e end
    local first = math.max(1, lvl - CHART_LEVELS + 1)
    local any = false
    for i = 1, CHART_LEVELS do
        local e = byLvl[first + i - 1]
        if e and e.sec > 0 then
            maxV = math.max(maxV, e.sec)
            any = true
        end
    end
    for _, g in ipairs(gridLabels) do g.fs:SetText(any and ns.Dur(maxV * g.frac) or "") end
    chartEmpty:SetShown(not any)
    for i, slot in ipairs(slots) do
        local n = first + i - 1
        local e = byLvl[n]
        slot.data = e
        if n <= lvl and lvl > 0 then
            slot.label:SetText(tostring(n))
            if n == lvl then slot.label:SetTextColor(GREEN[1], GREEN[2], GREEN[3]) else slot.label:SetTextColor(0.55, 0.55, 0.55) end
        else
            slot.label:SetText("")
        end
        if e and e.sec > 0 then
            slot.bar:SetHeight(math.max(1, e.sec / maxV * (PLOT_H - 2)))
            if e.current then
                slot.bar:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.9)
            elseif e.partTime then
                slot.bar:SetColorTexture(0.55, 0.55, 0.62, 0.85)
            else
                slot.bar:SetColorTexture(ACC[1], ACC[2], ACC[3], 0.95)
            end
            slot.bar:Show()
        else
            slot.bar:Hide()
        end
    end

    -- Origen de la experiencia
    local scope = state.scope
    if scope == "session" and not live then scope = "level" end
    for _, b in ipairs(scopeBtns) do
        b:SetActive(b.key == scope)
        b:SetAlpha((b.key == "session" and not live) and 0.4 or 1)
    end
    local src = ns.Sources(key, scope)
    local srcMax = 1
    for _, def in ipairs(SOURCES) do srcMax = math.max(srcMax, src[def[1]]) end
    for i, def in ipairs(SOURCES) do
        local r = srcRows[i]
        local v = src[def[1]]
        local n = (def[1] == "k" and src.nk) or (def[1] == "q" and src.nq) or nil
        r.data = { xp = v, n = n }
        r.name:SetText(def[2] .. ((n and n > 0) and ("  |cff777777" .. ns.Num(n) .. "|r") or ""))
        r.pct:SetText(src.total > 0 and (math.floor(v / src.total * 100 + 0.5) .. "%") or "")
        r.bar:SetWidth(math.max(1, v / srcMax * SRC_BAR_W))
        r.bar:SetShown(v > 0)
        r.amount:SetText(v > 0 and ns.Num(v) or DASH)
    end
    srcEmpty:SetText(src.total > 0 and "" or "Sin experiencia registrada todavía")

    -- Pie
    local todayXP, todaySec = ns.Today(key)
    local parts = { "|cffb88cffHoy|r  ·  " .. ns.Num(todayXP) .. " de experiencia en " .. ns.Dur(todaySec) }
    if live and s and s.nk > 0 then parts[#parts + 1] = ns.Num(s.nk) .. " muertes en la sesión" end
    if live and s and s.nq > 0 then parts[#parts + 1] = s.nq .. (s.nq == 1 and " misión" or " misiones") end
    footer:SetText(table.concat(parts, "  ·  "))
end

-- Los datos cambian a ráfagas (varias ganancias seguidas): refresca como mucho cada 0,3 s
local pending = false
function ns.OnDataChanged()
    if pending or not main:IsShown() then return end
    pending = true
    C_Timer.After(0.3, function()
        pending = false
        ns.Refresh()
    end)
end

main:SetScript("OnShow", function()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839)
    ns.Refresh()
end)
main:SetScript("OnHide", function()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840)
end)
main.elapsed = 0
main:SetScript("OnUpdate", function(self, el)
    self.elapsed = self.elapsed + el
    if self.elapsed > 5 then
        self.elapsed = 0
        ns.Refresh()
    end
end)

function ns.Toggle()
    main:SetShown(not main:IsShown())
end

---------------------------------------------------------------------------
-- Botón del minimapa
---------------------------------------------------------------------------
local mb = CreateFrame("Button", "SendaMinimapButton", Minimap)
mb:SetSize(31, 31)
mb:SetFrameStrata("MEDIUM")
mb:SetFrameLevel(8)
mb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mb:RegisterForDrag("LeftButton")
mb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local mbBg = mb:CreateTexture(nil, "BACKGROUND")
mbBg:SetSize(20, 20)
mbBg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
mbBg:SetPoint("TOPLEFT", 7, -5)
local mbIcon = mb:CreateTexture(nil, "ARTWORK")
mbIcon:SetSize(18, 18)
mbIcon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
mbIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
mbIcon:SetPoint("TOPLEFT", 7, -6)
local mbBorder = mb:CreateTexture(nil, "OVERLAY")
mbBorder:SetSize(53, 53)
mbBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mbBorder:SetPoint("TOPLEFT")

local function PlaceMinimap()
    local a = math.rad(ns.db.settings.minimap.angle or 200)
    local rx = (Minimap:GetWidth() / 2) + 10
    local ry = (Minimap:GetHeight() / 2) + 10
    local x, y = math.cos(a), math.sin(a)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        local m = math.max(math.abs(x), math.abs(y))
        x, y = x / m, y / m
    end
    mb:ClearAllPoints()
    mb:SetPoint("CENTER", Minimap, "CENTER", x * rx, y * ry)
end

function ns.UpdateMinimapButton()
    PlaceMinimap()
    mb:SetShown(not ns.db.settings.minimap.hide)
end

mb:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        ns.db.settings.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
        PlaceMinimap()
    end)
end)
mb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

local function ShowSummaryTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    GameTooltip:AddLine("Senda", ACC[1], ACC[2], ACC[3])
    local c = ns.char
    if c and c.level then
        local mx = c.xpMax or 0
        if mx > 0 then
            GameTooltip:AddDoubleLine("Nivel " .. c.level, Pct((c.xp or 0) / mx * 100), 0.8, 0.8, 0.8, 1, 1, 1)
        else
            GameTooltip:AddDoubleLine("Nivel", tostring(c.level), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        local rate = ns.Rates()
        if rate > 0 then GameTooltip:AddDoubleLine("Experiencia por hora", ns.Num(rate), 0.8, 0.8, 0.8, 1, 1, 1) end
        local eta = ns.ETA()
        if eta then GameTooltip:AddDoubleLine("Para subir de nivel", ns.Dur(eta), 0.8, 0.8, 0.8, 1, 0.82, 0) end
        if ns.session then
            GameTooltip:AddDoubleLine("Esta sesión", ns.Num(ns.session.xp) .. " exp", 0.8, 0.8, 0.8, 1, 1, 1)
        end
        GameTooltip:AddDoubleLine("Hoy", ns.Num((ns.Today(ns.charKey))) .. " exp", 0.8, 0.8, 0.8, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffff00Clic|r para abrir · |cffffff00Arrastrar|r para mover", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

mb:SetScript("OnClick", function() ns.Toggle() end)
mb:SetScript("OnEnter", function(self) ShowSummaryTooltip(self) end)
mb:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Menú de complementos (AddonCompartment)
function Senda_OnCompartmentClick() ns.Toggle() end
function Senda_OnCompartmentEnter(_, button) ShowSummaryTooltip(button or UIParent, "ANCHOR_LEFT") end
function Senda_OnCompartmentLeave() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Inicio
---------------------------------------------------------------------------
function ns.OnInit()
    state.filter = ns.charKey
    local pos = ns.db.settings.pos
    if pos then
        main:ClearAllPoints()
        main:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
    ns.UpdateMinimapButton()
    Minimap:HookScript("OnSizeChanged", PlaceMinimap)
    C_Timer.After(1, PlaceMinimap)
end
