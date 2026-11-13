-- Tesorero: interfaz
local ADDON, ns = ...

local W, H = 800, 640
local PAD = 14
local LEFT_W = 372
local ROW_H = 21
local HIST_ROWS = 15
local CHART_DAYS = 14
local CAT_ROW_H = 18

local BD = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local DAY_NAMES = { "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado" }
local GREEN = { 0.29, 0.87, 0.5 }
local RED = { 1, 0.42, 0.42 }

-- filter = clave de personaje o nil (todos); cat = filtro de categoría del historial
local state = { filter = nil, period = "week", cat = nil }

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
local function Panel(parent, bg, border)
    local f = CreateFrame("Frame", nil, parent, TEMPLATE)
    f:SetBackdrop(BD)
    bg = bg or { 0.09, 0.09, 0.11, 0.92 }
    border = border or { 0.22, 0.20, 0.16, 1 }
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

local function DayLabel(t)
    if ns.DayKey(t) == ns.DayKey() then return "Hoy" end
    if ns.DayKey(t) == ns.DayKey(time() - 86400) then return "Ayer" end
    return DAY_NAMES[tonumber(date("%w", t)) + 1] .. " " .. date("%d/%m", t)
end

local function DayKeyToTime(dk)
    local y, m, d = dk:match("(%d+)-(%d+)-(%d+)")
    return time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

local function Button(parent, w, h, label, onClick)
    local b = CreateFrame("Button", nil, parent, TEMPLATE)
    b:SetSize(w, h)
    b:SetBackdrop(BD)
    b.text = Text(b, 12)
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    function b:SetActive(on)
        self.active = on
        if on then
            self:SetBackdropColor(0.35, 0.26, 0.06, 1)
            self:SetBackdropBorderColor(1, 0.82, 0.2, 1)
            self.text:SetTextColor(1, 0.9, 0.5)
        else
            self:SetBackdropColor(0.12, 0.12, 0.14, 1)
            self:SetBackdropBorderColor(0.30, 0.27, 0.20, 1)
            self.text:SetTextColor(0.85, 0.85, 0.85)
        end
    end
    b:SetActive(false)
    b:SetScript("OnEnter", function(s) if not s.active then s:SetBackdropBorderColor(0.8, 0.65, 0.25, 1) end end)
    b:SetScript("OnLeave", function(s) if not s.active then s:SetBackdropBorderColor(0.30, 0.27, 0.20, 1) end end)
    b:SetScript("OnClick", onClick)
    return b
end

local function SectionTitle(parent, label)
    local t = Text(parent, 12, "GameFontNormal")
    t:SetPoint("TOPLEFT", 10, -8)
    t:SetText(label)
    local line = Tex(parent, "ARTWORK", 1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 8, -24)
    line:SetPoint("TOPRIGHT", -8, -24)
    return t
end

---------------------------------------------------------------------------
-- Ventana principal
---------------------------------------------------------------------------
local main = CreateFrame("Frame", "TesoreroMainFrame", UIParent, TEMPLATE)
main:SetSize(W, H)
main:SetPoint("CENTER")
main:SetFrameStrata("HIGH")
main:SetToplevel(true)
main:SetBackdrop(BD)
main:SetBackdropColor(0.04, 0.04, 0.05, 0.96)
main:SetBackdropBorderColor(0.65, 0.52, 0.18, 1)
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
tinsert(UISpecialFrames, "TesoreroMainFrame")

-- Cabecera
local header = Tex(main, "BACKGROUND", 0.16, 0.12, 0.04, 1, 1)
header:SetPoint("TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", -1, -1)
header:SetHeight(50)
local headerLine = Tex(main, "ARTWORK", 1, 0.82, 0, 0.6)
headerLine:SetHeight(1)
headerLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
headerLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")

local logo = main:CreateTexture(nil, "ARTWORK")
logo:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
logo:SetSize(34, 34)
logo:SetPoint("TOPLEFT", 12, -9)

local title = Text(main, 20, "GameFontNormalLarge")
title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -1)
title:SetText("Tesorero")
title:SetTextColor(1, 0.82, 0)

local subtitle = Text(main, 11)
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
subtitle:SetTextColor(0.7, 0.65, 0.5)
subtitle:SetText("Historial de oro · WoW Forever")

-- Botón cerrar propio, dentro de la cabecera
local close = CreateFrame("Button", nil, main, TEMPLATE)
close:SetSize(24, 24)
close:SetPoint("TOPRIGHT", -12, -13)
close:SetBackdrop(BD)
close:SetBackdropColor(0.12, 0.10, 0.06, 1)
close:SetBackdropBorderColor(0.45, 0.36, 0.15, 1)
local closeX1 = Tex(close, "ARTWORK", 0.9, 0.85, 0.7, 1)
closeX1:SetSize(14, 2)
closeX1:SetPoint("CENTER")
closeX1:SetRotation(math.rad(45))
local closeX2 = Tex(close, "ARTWORK", 0.9, 0.85, 0.7, 1)
closeX2:SetSize(14, 2)
closeX2:SetPoint("CENTER")
closeX2:SetRotation(math.rad(-45))
close:SetScript("OnEnter", function(s)
    s:SetBackdropColor(0.55, 0.12, 0.10, 1)
    s:SetBackdropBorderColor(1, 0.4, 0.3, 1)
end)
close:SetScript("OnLeave", function(s)
    s:SetBackdropColor(0.12, 0.10, 0.06, 1)
    s:SetBackdropBorderColor(0.45, 0.36, 0.15, 1)
end)
close:SetScript("OnClick", function() main:Hide() end)

-- Selector de personaje
local charBtn
charBtn = Button(main, 210, 24, "", function(_, mouse)
    local list = ns.CharList()
    local idx = 0
    for i, k in ipairs(list) do if k == state.filter then idx = i end end
    if mouse == "RightButton" then idx = idx - 1 else idx = idx + 1 end
    if idx > #list then idx = 0 elseif idx < 0 then idx = #list end
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

-- Pestañas de periodo
local periodBtns = {}
for i, p in ipairs(ns.PERIODS) do
    local b = Button(main, 80, 22, p[2], function()
        state.period = p[1]
        ns.db.settings.period = p[1]
        ns.Refresh()
    end)
    b.key = p[1]
    if i == 1 then b:SetPoint("TOPLEFT", PAD, -62) else b:SetPoint("LEFT", periodBtns[i - 1], "RIGHT", 6, 0) end
    periodBtns[i] = b
end

local periodHint = Text(main, 11)
periodHint:SetPoint("LEFT", periodBtns[#periodBtns], "RIGHT", 12, 0)
periodHint:SetTextColor(0.6, 0.6, 0.6)

---------------------------------------------------------------------------
-- Tarjetas resumen
---------------------------------------------------------------------------
local cards = {}
local CARD_W = (W - PAD * 2 - 10 * 3) / 4
local cardDefs = {
    { "Oro actual", { 1, 0.82, 0 }, "Interface\\Icons\\INV_Misc_Coin_17" },
    { "Ganado", GREEN, "Interface\\Icons\\INV_Misc_Coin_04" },
    { "Gastado", RED, "Interface\\Icons\\INV_Misc_Coin_06" },
    { "Balance", { 0.55, 0.8, 1 }, "Interface\\Icons\\INV_Misc_Bag_11" },
}
for i, def in ipairs(cardDefs) do
    local c = Panel(main, { 0.08, 0.08, 0.10, 1 }, { 0.22, 0.20, 0.16, 1 })
    c:SetSize(CARD_W, 66)
    c:SetPoint("TOPLEFT", PAD + (i - 1) * (CARD_W + 10), -94)
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
    c.value = Text(c, 15)
    c.value:SetPoint("TOPLEFT", 12, -26)
    c.value:SetPoint("RIGHT", -6, 0)
    c.value:SetJustifyH("LEFT")
    c.value:SetWordWrap(false)
    c.sub = Text(c, 10)
    c.sub:SetPoint("BOTTOMLEFT", 12, 8)
    c.sub:SetPoint("RIGHT", -6, 0)
    c.sub:SetJustifyH("LEFT")
    c.sub:SetWordWrap(false)
    c.sub:SetTextColor(0.55, 0.55, 0.55)
    cards[i] = c
end

---------------------------------------------------------------------------
-- Gráfico de los últimos 14 días
---------------------------------------------------------------------------
local TOP_Y = -172
local FOOT_H = 30
local contentH = H + TOP_Y - FOOT_H - 8
local CHART_H = 160

local chart = Panel(main)
chart:SetPoint("TOPLEFT", PAD, TOP_Y)
chart:SetSize(LEFT_W, CHART_H)
SectionTitle(chart, "Últimos 14 días")
local legend = Text(chart, 10)
legend:SetPoint("TOPRIGHT", -10, -10)
legend:SetText("|TInterface\\Buttons\\WHITE8x8:8:8:0:0:8:8:0:8:0:8:74:222:128|t Ganado   |TInterface\\Buttons\\WHITE8x8:8:8:0:0:8:8:0:8:0:8:255:107:107|t Gastado")

local PLOT_H = 96
local PLOT_BOTTOM = 22
local slotW = (LEFT_W - 20) / CHART_DAYS
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
for i = 1, CHART_DAYS do
    local s = CreateFrame("Frame", nil, chart)
    s:SetSize(slotW, PLOT_H + PLOT_BOTTOM)
    s:SetPoint("BOTTOMLEFT", 10 + (i - 1) * slotW, 0)
    s:EnableMouse(true)
    s.hl = Tex(s, "BACKGROUND", 1, 0.82, 0, 0.08, 3)
    s.hl:SetPoint("TOPLEFT", 1, 0)
    s.hl:SetPoint("BOTTOMRIGHT", -1, PLOT_BOTTOM)
    s.hl:Hide()
    local bw = math.max(3, math.floor(slotW / 2 - 3))
    s.inc = Tex(s, "ARTWORK", GREEN[1], GREEN[2], GREEN[3], 0.95)
    s.inc:SetWidth(bw)
    s.inc:SetPoint("BOTTOMRIGHT", s, "BOTTOM", -1, PLOT_BOTTOM + 1)
    s.out = Tex(s, "ARTWORK", RED[1], RED[2], RED[3], 0.95)
    s.out:SetWidth(bw)
    s.out:SetPoint("BOTTOMLEFT", s, "BOTTOM", 1, PLOT_BOTTOM + 1)
    s.label = Text(s, 9)
    s.label:SetPoint("BOTTOM", 0, 6)
    s:SetScript("OnEnter", function(self)
        self.hl:Show()
        if not self.data then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(DAY_NAMES[tonumber(date("%w", self.data.t)) + 1] .. " " .. date("%d/%m/%Y", self.data.t), 1, 0.82, 0)
        GameTooltip:AddDoubleLine("Ganado", ns.Money(self.data.i, 12, true), GREEN[1], GREEN[2], GREEN[3], 1, 1, 1)
        GameTooltip:AddDoubleLine("Gastado", ns.Money(self.data.o, 12, true), RED[1], RED[2], RED[3], 1, 1, 1)
        GameTooltip:AddDoubleLine("Balance", ns.Signed(self.data.i - self.data.o, 12, true), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function(self) if not self.isToday then self.hl:Hide() end GameTooltip:Hide() end)
    slots[i] = s
end
slots[CHART_DAYS].isToday = true
slots[CHART_DAYS].hl:Show()
slots[CHART_DAYS].hl:SetColorTexture(1, 0.82, 0, 0.06)

local chartEmpty = Text(chart, 11)
chartEmpty:SetPoint("CENTER", 0, 4)
chartEmpty:SetTextColor(0.5, 0.5, 0.5)
chartEmpty:SetText("Sin movimientos en las últimas 2 semanas")

---------------------------------------------------------------------------
-- Desglose por categoría
---------------------------------------------------------------------------
local catPanel = Panel(main)
catPanel:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", 0, -8)
catPanel:SetSize(LEFT_W, contentH - CHART_H - 8)
SectionTitle(catPanel, "Por categoría")
local catHint = Text(catPanel, 9)
catHint:SetPoint("TOPRIGHT", -10, -11)
catHint:SetTextColor(0.45, 0.45, 0.45)
catHint:SetText("clic = filtrar movimientos")

-- Barras de composición (de dónde viene / a dónde va el oro)
local STACK_W = LEFT_W - 20 - 62
local stacks = {}
for i, def in ipairs({ { "Ingresos", GREEN }, { "Gastos", RED } }) do
    local y = -34 - (i - 1) * 18
    local lbl = Text(catPanel, 10)
    lbl:SetPoint("TOPLEFT", 10, y - 1)
    lbl:SetTextColor(def[2][1], def[2][2], def[2][3])
    lbl:SetText(def[1])
    local bg = Tex(catPanel, "BACKGROUND", 1, 1, 1, 0.05, 3)
    bg:SetSize(STACK_W, 10)
    bg:SetPoint("TOPLEFT", 72, y)
    local st = { bg = bg, segs = {} }
    for j = 1, #ns.CAT_ORDER do
        local seg = catPanel:CreateTexture(nil, "ARTWORK")
        seg:SetHeight(10)
        seg:Hide()
        st.segs[j] = seg
    end
    stacks[i] = st
end

local function FillStack(st, list, field, total)
    local x = 0
    for j, seg in ipairs(st.segs) do
        local e = list[j]
        local v = e and e.v[field] or 0
        if total > 0 and v > 0 then
            local w = math.max(1, v / total * STACK_W)
            local c = ns.CATS[e.cat].color
            seg:SetColorTexture(c[1], c[2], c[3], 0.9)
            seg:SetWidth(w)
            seg:ClearAllPoints()
            seg:SetPoint("TOPLEFT", st.bg, "TOPLEFT", x, 0)
            seg:Show()
            x = x + w
        else
            seg:Hide()
        end
    end
end

local catRows = {}
local CAT_TOP = -74
for i = 1, #ns.CAT_ORDER do
    local r = CreateFrame("Button", nil, catPanel)
    r:SetSize(LEFT_W - 16, CAT_ROW_H)
    r:SetPoint("TOPLEFT", 8, CAT_TOP - (i - 1) * CAT_ROW_H)
    r.hl = Tex(r, "BACKGROUND", 1, 0.82, 0, 0.08)
    r.hl:SetAllPoints()
    r.hl:Hide()
    r.sel = Tex(r, "BACKGROUND", 1, 0.82, 0, 0.16, 1)
    r.sel:SetAllPoints()
    r.sel:Hide()
    r.swatch = Tex(r, "ARTWORK", 1, 1, 1, 1)
    r.swatch:SetSize(3, CAT_ROW_H - 4)
    r.swatch:SetPoint("LEFT", 0, 0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(15, 15)
    r.icon:SetPoint("LEFT", 6, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = Text(r, 11)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.name:SetWidth(82)
    r.name:SetJustifyH("LEFT")
    r.pct = Text(r, 10)
    r.pct:SetPoint("LEFT", r.icon, "RIGHT", 88, 0)
    r.pct:SetWidth(32)
    r.pct:SetJustifyH("RIGHT")
    r.pct:SetTextColor(0.6, 0.6, 0.6)
    r.barBg = Tex(r, "BACKGROUND", 1, 1, 1, 0.05, 2)
    r.barBg:SetSize(80, 8)
    r.barBg:SetPoint("LEFT", r.icon, "RIGHT", 126, 0)
    r.barI = Tex(r, "ARTWORK", GREEN[1], GREEN[2], GREEN[3], 0.9)
    r.barI:SetHeight(4)
    r.barI:SetPoint("TOPLEFT", r.barBg, "TOPLEFT", 0, 0)
    r.barO = Tex(r, "ARTWORK", RED[1], RED[2], RED[3], 0.9)
    r.barO:SetHeight(4)
    r.barO:SetPoint("BOTTOMLEFT", r.barBg, "BOTTOMLEFT", 0, 0)
    r.amount = Text(r, 10)
    r.amount:SetPoint("RIGHT", -4, 0)
    r.amount:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(self)
        self.hl:Show()
        if not self.data then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.catName, 1, 0.82, 0)
        GameTooltip:AddDoubleLine("Ganado", ns.Money(self.data.i, 12, true), GREEN[1], GREEN[2], GREEN[3], 1, 1, 1)
        GameTooltip:AddDoubleLine("Gastado", ns.Money(self.data.o, 12, true), RED[1], RED[2], RED[3], 1, 1, 1)
        GameTooltip:AddDoubleLine("Neto", ns.Signed(self.data.i - self.data.o, 12, true), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(state.cat == self.cat and "Clic para quitar el filtro" or "Clic para ver solo estos movimientos", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function(self) self.hl:Hide() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        state.cat = (state.cat ~= self.cat) and self.cat or nil
        ns.Refresh()
    end)
    catRows[i] = r
end
local catEmpty = Text(catPanel, 12)
catEmpty:SetPoint("CENTER", 0, -10)
catEmpty:SetTextColor(0.5, 0.5, 0.5)
catEmpty:SetText("Aún no hay movimientos en este periodo")

---------------------------------------------------------------------------
-- Historial de movimientos
---------------------------------------------------------------------------
local STATS_H = 74
local hist = Panel(main)
hist:SetPoint("TOPLEFT", chart, "TOPRIGHT", 10, 0)
hist:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, TOP_Y)
hist:SetHeight(contentH)
SectionTitle(hist, "Movimientos")
local histCount = Text(hist, 10)
histCount:SetPoint("TOPRIGHT", -10, -10)
histCount:SetTextColor(0.55, 0.55, 0.55)

-- "chip" con el filtro de categoría activo
local chip = CreateFrame("Button", nil, hist, TEMPLATE)
chip:SetHeight(16)
chip:SetPoint("LEFT", hist, "TOPLEFT", 100, -15)
chip:SetBackdrop(BD)
chip:SetBackdropColor(0.35, 0.26, 0.06, 1)
chip:SetBackdropBorderColor(1, 0.82, 0.2, 0.8)
chip.text = Text(chip, 10)
chip.text:SetPoint("CENTER")
chip:SetScript("OnClick", function() state.cat = nil ns.Refresh() end)
chip:SetScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_TOP")
    GameTooltip:AddLine("Clic para quitar el filtro", 1, 1, 1)
    GameTooltip:Show()
end)
chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
chip:Hide()

local scroll = CreateFrame("ScrollFrame", "TesoreroHistScroll", hist, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 4, -30)
scroll:SetPoint("BOTTOMRIGHT", -26, STATS_H + 6)

local histData = {}
local histRows = {}
local UpdateHistory

for i = 1, HIST_ROWS do
    local r = CreateFrame("Frame", nil, hist)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 6, -30 - (i - 1) * ROW_H)
    r:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
    r:EnableMouse(true)
    r.bg = Tex(r, "BACKGROUND", 1, 1, 1, (i % 2 == 0) and 0.03 or 0)
    r.bg:SetAllPoints()
    r.hl = Tex(r, "BACKGROUND", 1, 0.82, 0, 0.08, 1)
    r.hl:SetAllPoints()
    r.hl:Hide()
    r.swatch = Tex(r, "ARTWORK", 1, 1, 1, 1)
    r.swatch:SetSize(2, ROW_H - 6)
    r.swatch:SetPoint("LEFT", 0, 0)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(16, 16)
    r.icon:SetPoint("LEFT", 6, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.when = Text(r, 10)
    r.when:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.when:SetWidth(72)
    r.when:SetJustifyH("LEFT")
    r.when:SetTextColor(0.6, 0.6, 0.6)
    r.what = Text(r, 11)
    r.what:SetPoint("LEFT", r.when, "RIGHT", 4, 0)
    r.what:SetPoint("RIGHT", r, "RIGHT", -90, 0)
    r.what:SetJustifyH("LEFT")
    r.what:SetWordWrap(false)
    r.amount = Text(r, 11)
    r.amount:SetPoint("RIGHT", -4, 0)
    r.amount:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(self)
        self.hl:Show()
        local e = self.data
        if not e then return end
        local cat = ns.CATS[e.cat] or ns.CATS.other
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(cat.name, cat.color[1], cat.color[2], cat.color[3])
        GameTooltip:AddLine(ns.Signed(e.d, 13, true))
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Fecha", date("%d/%m/%Y %H:%M:%S", e.t), 0.7, 0.7, 0.7, 1, 1, 1)
        if e.zone and e.zone ~= "" then GameTooltip:AddDoubleLine("Zona", e.zone, 0.7, 0.7, 0.7, 1, 1, 1) end
        GameTooltip:AddDoubleLine("Personaje", "|c" .. ClassHex(e.class) .. e.char .. "|r", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function(self) self.hl:Hide() GameTooltip:Hide() end)
    histRows[i] = r
end

local histEmpty = Text(hist, 12)
histEmpty:SetPoint("CENTER", 0, STATS_H / 2)
histEmpty:SetTextColor(0.5, 0.5, 0.5)
histEmpty:SetText("Sin movimientos todavía.\nGana o gasta algo de oro y aparecerá aquí.")

function UpdateHistory()
    local offset = FauxScrollFrame_GetOffset(scroll)
    FauxScrollFrame_Update(scroll, #histData, HIST_ROWS, ROW_H)
    for i = 1, HIST_ROWS do
        local r = histRows[i]
        local e = histData[offset + i]
        r.data = e
        if e then
            local cat = ns.CATS[e.cat] or ns.CATS.other
            r.icon:SetTexture(cat.icon)
            r.swatch:SetColorTexture(cat.color[1], cat.color[2], cat.color[3], 0.9)
            local dl = DayLabel(e.t)
            if dl == "Hoy" or dl == "Ayer" then
                r.when:SetText(dl .. " " .. date("%H:%M", e.t))
            else
                r.when:SetText(date("%d/%m %H:%M", e.t))
            end
            local label = cat.name
            if not state.filter then
                label = label .. " |c" .. ClassHex(e.class) .. "· " .. e.char .. "|r"
            elseif e.zone and e.zone ~= "" then
                label = label .. " |cff777777· " .. e.zone .. "|r"
            end
            r.what:SetText(label)
            r.amount:SetText(ns.Signed(e.d, 11, true))
            r:Show()
        else
            r:Hide()
        end
    end
    histEmpty:SetShown(#histData == 0)
end
scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, UpdateHistory)
end)

-- Estadísticas al pie del historial
local statsBox = CreateFrame("Frame", nil, hist)
statsBox:SetPoint("BOTTOMLEFT", 6, 6)
statsBox:SetPoint("BOTTOMRIGHT", -6, 6)
statsBox:SetHeight(STATS_H - 4)
local statsLine = Tex(statsBox, "ARTWORK", 1, 0.82, 0, 0.25)
statsLine:SetHeight(1)
statsLine:SetPoint("TOPLEFT", 2, 0)
statsLine:SetPoint("TOPRIGHT", -2, 0)

local stats = {}
local statNames = { "Mejor día", "Media diaria", "Mayor ingreso", "Mayor gasto" }
for i, name in ipairs(statNames) do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local f = CreateFrame("Frame", nil, statsBox)
    f:SetSize(170, 32)
    f:SetPoint("TOPLEFT", 4 + col * 182, -6 - row * 33)
    f.label = Text(f, 9)
    f.label:SetPoint("TOPLEFT", 0, 0)
    f.label:SetTextColor(0.55, 0.55, 0.55)
    f.label:SetText(name:upper())
    f.value = Text(f, 12)
    f.value:SetPoint("TOPLEFT", 0, -11)
    f.value:SetWordWrap(false)
    f.sub = Text(f, 9)
    f.sub:SetPoint("LEFT", f.value, "RIGHT", 6, 0)
    f.sub:SetTextColor(0.5, 0.5, 0.5)
    f.sub:SetWordWrap(false)
    stats[i] = f
end

---------------------------------------------------------------------------
-- Pie: sesión
---------------------------------------------------------------------------
local footLine = Tex(main, "ARTWORK", 1, 0.82, 0, 0.2)
footLine:SetHeight(1)
footLine:SetPoint("BOTTOMLEFT", 1, FOOT_H)
footLine:SetPoint("BOTTOMRIGHT", -1, FOOT_H)

local footer = Text(main, 11)
footer:SetPoint("BOTTOMLEFT", PAD, 10)
footer:SetTextColor(0.75, 0.75, 0.75)

local footRight = Text(main, 10)
footRight:SetPoint("BOTTOMRIGHT", -PAD, 10)
footRight:SetTextColor(0.45, 0.45, 0.45)
footRight:SetText("/tesoro ayuda")

local function UpdateFooter()
    local s = ns.session
    local mins = math.floor((time() - s.start) / 60)
    local dur = mins >= 60 and ("%dh %02dm"):format(math.floor(mins / 60), mins % 60) or (mins .. " min")
    if s.i == 0 and s.o == 0 then
        footer:SetText("|cffffd100Sesión|r  ·  " .. dur .. "  ·  |cff888888sin movimientos todavía|r")
        return
    end
    local net = s.i - s.o
    local hours = math.max((time() - s.start) / 3600, 1 / 60)
    local parts = { "|cffffd100Sesión|r  ·  " .. dur }
    if s.i > 0 then parts[#parts + 1] = "|cff4ade80+" .. ns.Money(s.i, 11) .. "|r" end
    if s.o > 0 then parts[#parts + 1] = "|cffff6b6b-" .. ns.Money(s.o, 11) .. "|r" end
    parts[#parts + 1] = "Neto " .. ns.Signed(net, 11)
    if mins >= 5 then parts[#parts + 1] = ns.Signed(net / hours, 11) .. " /hora" end
    footer:SetText(table.concat(parts, "  ·  "))
end

---------------------------------------------------------------------------
-- Refrescar todo
---------------------------------------------------------------------------
local PERIOD_TEXT = { today = "desde las 00:00 de hoy", week = "últimos 7 días", month = "últimos 30 días", all = "desde que instalaste Tesorero" }

local function SetStat(f, value, sub)
    f.value:SetText(value)
    f.sub:SetText(sub or "")
end

function ns.Refresh()
    if not main:IsShown() or not ns.db then return end
    if state.filter and not ns.db.chars[state.filter] then state.filter = nil end

    -- Botón de personaje
    if state.filter then
        local c = ns.db.chars[state.filter]
        charBtn.text:SetText("|c" .. ClassHex(c.class) .. ShortName(state.filter) .. "|r  |cff888888nivel " .. (c.level or "?") .. "|r")
    else
        charBtn.text:SetText("|cffffd100Todos los personajes|r")
    end

    for _, b in ipairs(periodBtns) do b:SetActive(b.key == state.period) end
    periodHint:SetText(PERIOD_TEXT[state.period])

    -- Tarjetas
    local inc, out, cats = ns.Aggregate(state.filter, state.period)
    local money, n, peak = ns.TotalMoney(state.filter)
    cards[1].value:SetText(ns.Money(money, 14))
    if state.filter then
        cards[1].sub:SetText("Récord: " .. ns.Money(peak, 10))
    else
        cards[1].sub:SetText(n .. (n == 1 and " personaje" or " personajes"))
    end
    cards[2].value:SetText(inc > 0 and ns.Money(inc, 14) or "|cff666666—|r")
    cards[3].value:SetText(out > 0 and ns.Money(out, 14) or "|cff666666—|r")
    cards[4].value:SetText((inc > 0 or out > 0) and ns.Signed(inc - out, 14) or "|cff666666—|r")

    local bestI, bestIc, bestO, bestOc = 0, nil, 0, nil
    for cat, v in pairs(cats) do
        if v.i > bestI then bestI, bestIc = v.i, cat end
        if v.o > bestO then bestO, bestOc = v.o, cat end
    end
    cards[2].sub:SetText(bestIc and ("Sobre todo: " .. ns.CATS[bestIc].name) or "Nada todavía")
    cards[3].sub:SetText(bestOc and ("Sobre todo: " .. ns.CATS[bestOc].name) or "Nada todavía")
    if inc > 0 and out <= inc then
        cards[4].sub:SetText(("Ahorras el %d%%"):format(math.floor((inc - out) / inc * 100 + 0.5)))
    elseif out > inc then
        cards[4].sub:SetText("|cffff8a8aGastas más de lo que ganas|r")
    else
        cards[4].sub:SetText("Sin movimientos")
    end

    -- Gráfico
    local series = ns.DailySeries(state.filter, CHART_DAYS)
    local maxV, any = 1, false
    for _, e in ipairs(series) do
        maxV = math.max(maxV, e.i, e.o)
        if e.i > 0 or e.o > 0 then any = true end
    end
    for _, g in ipairs(gridLabels) do g.fs:SetText(any and ns.Money(maxV * g.frac, 9) or "") end
    chartEmpty:SetShown(not any)
    for i, s in ipairs(slots) do
        local e = series[i]
        s.data = e
        s.inc:SetHeight(math.max(1, e.i / maxV * (PLOT_H - 2)))
        s.out:SetHeight(math.max(1, e.o / maxV * (PLOT_H - 2)))
        s.inc:SetShown(e.i > 0)
        s.out:SetShown(e.o > 0)
        s.label:SetText(date("%d", e.t))
        if i == #slots then s.label:SetTextColor(1, 0.82, 0) else s.label:SetTextColor(0.55, 0.55, 0.55) end
    end

    -- Categorías
    local list = {}
    for _, cat in ipairs(ns.CAT_ORDER) do
        local v = cats[cat]
        if v and (v.i > 0 or v.o > 0) then list[#list + 1] = { cat = cat, v = v } end
    end
    table.sort(list, function(a, b) return (a.v.i + a.v.o) > (b.v.i + b.v.o) end)
    FillStack(stacks[1], list, "i", inc)
    FillStack(stacks[2], list, "o", out)
    local catMax, totalMove = 1, inc + out
    for _, e in ipairs(list) do catMax = math.max(catMax, e.v.i, e.v.o) end
    for i, r in ipairs(catRows) do
        local e = list[i]
        if e then
            local def = ns.CATS[e.cat]
            r.data, r.catName, r.cat = e.v, def.name, e.cat
            r.icon:SetTexture(def.icon)
            r.swatch:SetColorTexture(def.color[1], def.color[2], def.color[3], 1)
            r.name:SetText(def.name)
            r.name:SetTextColor(def.color[1], def.color[2], def.color[3])
            r.pct:SetText(totalMove > 0 and (math.floor((e.v.i + e.v.o) / totalMove * 100 + 0.5) .. "%") or "")
            local wI, wO = e.v.i / catMax * 80, e.v.o / catMax * 80
            r.barI:SetWidth(math.max(0.1, wI)); r.barI:SetShown(wI > 0)
            r.barO:SetWidth(math.max(0.1, wO)); r.barO:SetShown(wO > 0)
            local parts = {}
            if e.v.i > 0 then parts[#parts + 1] = "|cff4ade80+" .. ns.Money(e.v.i, 10) .. "|r" end
            if e.v.o > 0 then parts[#parts + 1] = "|cffff6b6b-" .. ns.Money(e.v.o, 10) .. "|r" end
            r.amount:SetText(table.concat(parts, "  "))
            r.sel:SetShown(state.cat == e.cat)
            r:Show()
        else
            r:Hide()
        end
    end
    catEmpty:SetShown(#list == 0)
    for _, st in ipairs(stacks) do st.bg:SetShown(#list > 0) end

    -- Historial
    histData = ns.History(state.filter, state.period, 1000, state.cat)
    if state.cat then
        local def = ns.CATS[state.cat]
        chip.text:SetText(def.name .. "  |cffffffffx|r")
        chip:SetWidth(chip.text:GetStringWidth() + 16)
        chip:Show()
    else
        chip:Hide()
    end
    histCount:SetText(#histData >= 1000 and "1000+ movimientos" or (#histData .. (#histData == 1 and " movimiento" or " movimientos")))
    UpdateHistory()

    -- Estadísticas
    local ps = ns.PeriodStats(state.filter, state.period)
    if ps.bestDay then
        SetStat(stats[1], ns.Signed(ps.bestNet, 11), DayLabel(DayKeyToTime(ps.bestDay)))
        SetStat(stats[2], ns.Signed(ps.avg, 11), ps.active .. (ps.active == 1 and " día activo" or " días activos"))
    else
        SetStat(stats[1], "|cff666666—|r")
        SetStat(stats[2], "|cff666666—|r")
    end
    local bigI, bigO
    for _, e in ipairs(histData) do
        if e.d > 0 and (not bigI or e.d > bigI.d) then bigI = e end
        if e.d < 0 and (not bigO or e.d < bigO.d) then bigO = e end
    end
    if bigI then SetStat(stats[3], ns.Signed(bigI.d, 11), ns.CATS[bigI.cat].name) else SetStat(stats[3], "|cff666666—|r") end
    if bigO then SetStat(stats[4], ns.Signed(bigO.d, 11), ns.CATS[bigO.cat].name) else SetStat(stats[4], "|cff666666—|r") end

    UpdateFooter()
end

local pending = false
function ns.OnDataChanged()
    if ns.UpdateMinimapTooltip then ns.UpdateMinimapTooltip() end
    if not main:IsShown() or pending then return end
    pending = true
    C_Timer.After(0.2, function() pending = false; ns.Refresh() end)
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
    if self.elapsed > 5 then self.elapsed = 0; UpdateFooter() end
end)

function ns.Toggle()
    main:SetShown(not main:IsShown())
end

---------------------------------------------------------------------------
-- Botón del minimapa
---------------------------------------------------------------------------
local mb = CreateFrame("Button", "TesoreroMinimapButton", Minimap)
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
mbIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
mbIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
mbIcon:SetPoint("TOPLEFT", 7, -6)
local mbBorder = mb:CreateTexture(nil, "OVERLAY")
mbBorder:SetSize(53, 53)
mbBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mbBorder:SetPoint("TOPLEFT")

local function PlaceMinimap()
    local a = math.rad(ns.db.settings.minimap.angle or 200)
    -- radio según el tamaño real del minimapa, para quedar en el borde exterior (como LibDBIcon)
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
    GameTooltip:AddLine("Tesorero", 1, 0.82, 0)
    local key = ns.charKey
    local incT, outT = ns.Aggregate(key, "today")
    local incA, outA = ns.Aggregate(key, "all")
    GameTooltip:AddDoubleLine("Oro actual", ns.Money(GetMoney(), 12, true), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Hoy", 1, 0.82, 0)
    GameTooltip:AddDoubleLine("  Ganado", ns.Money(incT, 12), GREEN[1], GREEN[2], GREEN[3], 1, 1, 1)
    GameTooltip:AddDoubleLine("  Gastado", ns.Money(outT, 12), RED[1], RED[2], RED[3], 1, 1, 1)
    GameTooltip:AddLine("Total histórico", 1, 0.82, 0)
    GameTooltip:AddDoubleLine("  Ganado", ns.Money(incA, 12), GREEN[1], GREEN[2], GREEN[3], 1, 1, 1)
    GameTooltip:AddDoubleLine("  Gastado", ns.Money(outA, 12), RED[1], RED[2], RED[3], 1, 1, 1)
    local all = ns.TotalMoney(nil)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Oro de la cuenta", ns.Money(all, 12), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffff00Clic|r para abrir · |cffffff00Arrastrar|r para mover", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

mb:SetScript("OnClick", function() ns.Toggle() end)
mb:SetScript("OnEnter", function(self) ShowSummaryTooltip(self) end)
mb:SetScript("OnLeave", function() GameTooltip:Hide() end)

function ns.UpdateMinimapTooltip()
    if GameTooltip:IsOwned(mb) then ShowSummaryTooltip(mb) end
end

-- Menú de complementos (AddonCompartment)
function Tesorero_OnCompartmentClick() ns.Toggle() end
function Tesorero_OnCompartmentEnter(_, button) ShowSummaryTooltip(button or UIParent, "ANCHOR_LEFT") end
function Tesorero_OnCompartmentLeave() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Inicio
---------------------------------------------------------------------------
function ns.OnInit()
    state.period = ns.db.settings.period or "week"
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
