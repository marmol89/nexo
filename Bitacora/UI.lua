-- Bitácora: interfaz
local ADDON, ns = ...

local W, H = 800, 600
local PAD = 14
local LEFT_W = 372
local ROW_H = 21
local SESS_ROWS = 13
local CHART_DAYS = 14
local RANK_ROWS = 10
local RANK_ROW_H = 18
local BAR_W = 70

local BD = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local DAY_NAMES = { "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado" }
local ACC = { 0.40, 0.78, 1.00 }     -- azul: tiempo activo
local AFK = { 0.55, 0.55, 0.62 }     -- gris: tiempo ausente
local GREEN = { 0.29, 0.87, 0.5 }
local DASH = "|cff666666—|r"
local PALETTE = {
    { 0.40, 0.78, 1.00 }, { 1.00, 0.82, 0.00 }, { 0.29, 0.87, 0.50 }, { 0.80, 0.45, 1.00 }, { 0.95, 0.55, 0.20 },
    { 1.00, 0.45, 0.45 }, { 0.55, 0.85, 0.95 }, { 0.95, 0.90, 0.60 }, { 0.40, 0.90, 0.60 }, { 0.60, 0.60, 0.60 },
}

-- filter = clave de personaje o nil (todos)
local state = { filter = nil, period = "week" }

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
local function Panel(parent, bg, border)
    local f = CreateFrame("Frame", nil, parent, TEMPLATE)
    f:SetBackdrop(BD)
    bg = bg or { 0.08, 0.09, 0.11, 0.92 }
    border = border or { 0.16, 0.21, 0.27, 1 }
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

local function ClassRGB(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return 1, 1, 1 end
    return c.r, c.g, c.b
end

local function ShortName(key) return (key:match("^(.-) %- ") or key) end

local function DayLabel(t)
    if ns.DayKey(t) == ns.DayKey() then return "Hoy" end
    if ns.DayKey(t) == ns.DayKey(time() - 86400) then return "Ayer" end
    return DAY_NAMES[tonumber(date("%w", t)) + 1] .. " " .. date("%d/%m", t)
end

local function Plural(n, one, many) return n .. " " .. (n == 1 and one or many) end

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
            self:SetBackdropColor(0.08, 0.22, 0.34, 1)
            self:SetBackdropBorderColor(0.40, 0.78, 1, 1)
            self.text:SetTextColor(0.75, 0.92, 1)
        else
            self:SetBackdropColor(0.11, 0.12, 0.14, 1)
            self:SetBackdropBorderColor(0.20, 0.26, 0.32, 1)
            self.text:SetTextColor(0.85, 0.85, 0.85)
        end
    end
    b:SetActive(false)
    b:SetScript("OnEnter", function(s) if not s.active then s:SetBackdropBorderColor(0.30, 0.60, 0.80, 1) end end)
    b:SetScript("OnLeave", function(s) if not s.active then s:SetBackdropBorderColor(0.20, 0.26, 0.32, 1) end end)
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

---------------------------------------------------------------------------
-- Ventana principal
---------------------------------------------------------------------------
local main = CreateFrame("Frame", "BitacoraMainFrame", UIParent, TEMPLATE)
main:SetSize(W, H)
main:SetPoint("CENTER")
main:SetFrameStrata("HIGH")
main:SetToplevel(true)
main:SetBackdrop(BD)
main:SetBackdropColor(0.04, 0.04, 0.05, 0.96)
main:SetBackdropBorderColor(0.22, 0.48, 0.68, 1)
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
tinsert(UISpecialFrames, "BitacoraMainFrame")

-- Cabecera
local header = Tex(main, "BACKGROUND", 0.05, 0.11, 0.17, 1, 1)
header:SetPoint("TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", -1, -1)
header:SetHeight(50)
local headerLine = Tex(main, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.6)
headerLine:SetHeight(1)
headerLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
headerLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")

local logo = main:CreateTexture(nil, "ARTWORK")
logo:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
logo:SetSize(34, 34)
logo:SetPoint("TOPLEFT", 12, -9)

local title = Text(main, 20, "GameFontNormalLarge")
title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -1)
title:SetText("Bitácora")
title:SetTextColor(ACC[1], ACC[2], ACC[3])

local subtitle = Text(main, 11)
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
subtitle:SetTextColor(0.5, 0.62, 0.72)
subtitle:SetText("Tiempo de juego · WoW Forever")

-- Botón cerrar
local close = CreateFrame("Button", nil, main, TEMPLATE)
close:SetSize(24, 24)
close:SetPoint("TOPRIGHT", -12, -13)
close:SetBackdrop(BD)
close:SetBackdropColor(0.06, 0.10, 0.14, 1)
close:SetBackdropBorderColor(0.18, 0.36, 0.50, 1)
local closeX1 = Tex(close, "ARTWORK", 0.75, 0.88, 0.95, 1)
closeX1:SetSize(14, 2)
closeX1:SetPoint("CENTER")
closeX1:SetRotation(math.rad(45))
local closeX2 = Tex(close, "ARTWORK", 0.75, 0.88, 0.95, 1)
closeX2:SetSize(14, 2)
closeX2:SetPoint("CENTER")
closeX2:SetRotation(math.rad(-45))
close:SetScript("OnEnter", function(s)
    s:SetBackdropColor(0.55, 0.12, 0.10, 1)
    s:SetBackdropBorderColor(1, 0.4, 0.3, 1)
end)
close:SetScript("OnLeave", function(s)
    s:SetBackdropColor(0.06, 0.10, 0.14, 1)
    s:SetBackdropBorderColor(0.18, 0.36, 0.50, 1)
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
    { "Tiempo total", { 1, 0.82, 0 }, "Interface\\Icons\\INV_Misc_PocketWatch_01" },
    { "En el periodo", ACC, "Interface\\Icons\\INV_Misc_Note_01" },
    { "Media diaria", GREEN, "Interface\\Icons\\INV_Misc_Book_09" },
    { "Sesión actual", { 0.80, 0.45, 1 }, "Interface\\Icons\\Ability_Hunter_EagleEye" },
}
for i, def in ipairs(cardDefs) do
    local c = Panel(main, { 0.08, 0.08, 0.10, 1 })
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
legend:SetText("|TInterface\\Buttons\\WHITE8x8:8:8:0:0:8:8:0:8:0:8:102:199:255|t Activo   |TInterface\\Buttons\\WHITE8x8:8:8:0:0:8:8:0:8:0:8:140:140:158|t Ausente")

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
    s.hl = Tex(s, "BACKGROUND", ACC[1], ACC[2], ACC[3], 0.08, 3)
    s.hl:SetPoint("TOPLEFT", 1, 0)
    s.hl:SetPoint("BOTTOMRIGHT", -1, PLOT_BOTTOM)
    s.hl:Hide()
    local bw = math.max(4, math.floor(slotW - 10))
    s.act = Tex(s, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.95)
    s.act:SetWidth(bw)
    s.act:SetPoint("BOTTOM", s, "BOTTOM", 0, PLOT_BOTTOM + 1)
    s.afk = Tex(s, "ARTWORK", AFK[1], AFK[2], AFK[3], 0.85)
    s.afk:SetWidth(bw)
    s.afk:SetPoint("BOTTOM", s.act, "TOP", 0, 0)
    s.label = Text(s, 9)
    s.label:SetPoint("BOTTOM", 0, 6)
    s:SetScript("OnEnter", function(self)
        self.hl:Show()
        local e = self.data
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(DAY_NAMES[tonumber(date("%w", e.t)) + 1] .. " " .. date("%d/%m/%Y", e.t), ACC[1], ACC[2], ACC[3])
        GameTooltip:AddDoubleLine("Jugado", ns.Dur(e.s), 0.8, 0.8, 0.8, 1, 1, 1)
        if e.a > 0 then
            GameTooltip:AddDoubleLine("Activo", ns.Dur(e.s - e.a), ACC[1], ACC[2], ACC[3], 1, 1, 1)
            GameTooltip:AddDoubleLine("Ausente (AFK)", ns.Dur(e.a), AFK[1], AFK[2], AFK[3], 1, 1, 1)
        end
        if e.est > 0 then
            GameTooltip:AddDoubleLine("Estimado (Tesorero)", "~" .. ns.Dur(e.est), 0.6, 0.6, 0.6, 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    s:SetScript("OnLeave", function(self) if not self.isToday then self.hl:Hide() end GameTooltip:Hide() end)
    slots[i] = s
end
slots[CHART_DAYS].isToday = true
slots[CHART_DAYS].hl:Show()
slots[CHART_DAYS].hl:SetColorTexture(ACC[1], ACC[2], ACC[3], 0.06)

local chartEmpty = Text(chart, 11)
chartEmpty:SetPoint("CENTER", 0, 4)
chartEmpty:SetTextColor(0.5, 0.5, 0.5)
chartEmpty:SetText("Sin tiempo registrado en las últimas 2 semanas")

---------------------------------------------------------------------------
-- Ranking: por personaje (vista "Todos") o por zona (un personaje)
---------------------------------------------------------------------------
local rank = Panel(main)
rank:SetPoint("TOPLEFT", chart, "BOTTOMLEFT", 0, -8)
rank:SetSize(LEFT_W, contentH - CHART_H - 8)
local rankTitle = SectionTitle(rank, "Por zona")
local rankHint = Text(rank, 9)
rankHint:SetPoint("TOPRIGHT", -10, -11)
rankHint:SetTextColor(0.45, 0.45, 0.45)

local rankRows = {}
for i = 1, RANK_ROWS do
    local r = CreateFrame("Button", nil, rank)
    r:SetSize(LEFT_W - 16, RANK_ROW_H)
    r:SetPoint("TOPLEFT", 8, -30 - (i - 1) * RANK_ROW_H)
    r.hl = Tex(r, "BACKGROUND", ACC[1], ACC[2], ACC[3], 0.08)
    r.hl:SetAllPoints()
    r.hl:Hide()
    r.swatch = Tex(r, "ARTWORK", 1, 1, 1, 1)
    r.swatch:SetSize(3, RANK_ROW_H - 4)
    r.swatch:SetPoint("LEFT", 0, 0)
    r.name = Text(r, 11)
    r.name:SetPoint("LEFT", 9, 0)
    r.name:SetWidth(150)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.pct = Text(r, 10)
    r.pct:SetPoint("LEFT", 162, 0)
    r.pct:SetWidth(32)
    r.pct:SetJustifyH("RIGHT")
    r.pct:SetTextColor(0.6, 0.6, 0.6)
    r.barBg = Tex(r, "BACKGROUND", 1, 1, 1, 0.05, 2)
    r.barBg:SetSize(BAR_W, 8)
    r.barBg:SetPoint("LEFT", 202, 0)
    r.bar = Tex(r, "ARTWORK", 1, 1, 1, 0.9)
    r.bar:SetHeight(8)
    r.bar:SetPoint("LEFT", r.barBg, "LEFT", 0, 0)
    r.amount = Text(r, 10)
    r.amount:SetPoint("RIGHT", -4, 0)
    r.amount:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(self)
        self.hl:Show()
        local e = self.data
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if e.key then
            GameTooltip:AddLine("|c" .. ClassHex(e.class) .. e.name .. "|r")
            GameTooltip:AddDoubleLine("Nivel", tostring(e.level or "?"), 0.7, 0.7, 0.7, 1, 1, 1)
            GameTooltip:AddDoubleLine("Jugado en el periodo", ns.Dur(e.sec), 0.7, 0.7, 0.7, 1, 1, 1)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Clic para ver solo este personaje", 0.6, 0.6, 0.6)
        else
            GameTooltip:AddLine(e.name, 1, 1, 1)
            GameTooltip:AddDoubleLine("Tiempo en la zona", ns.Dur(e.sec), 0.7, 0.7, 0.7, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function(self) self.hl:Hide() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        if self.data and self.data.key then
            state.filter = self.data.key
            ns.Refresh()
        end
    end)
    rankRows[i] = r
end
local rankEmpty = Text(rank, 12)
rankEmpty:SetPoint("CENTER", 0, -10)
rankEmpty:SetTextColor(0.5, 0.5, 0.5)
rankEmpty:SetText("Aún no hay tiempo registrado en este periodo")

---------------------------------------------------------------------------
-- Sesiones
---------------------------------------------------------------------------
local STATS_H = 74
local sess = Panel(main)
sess:SetPoint("TOPLEFT", chart, "TOPRIGHT", 10, 0)
sess:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, TOP_Y)
sess:SetHeight(contentH)
SectionTitle(sess, "Sesiones")
local sessCount = Text(sess, 10)
sessCount:SetPoint("TOPRIGHT", -10, -10)
sessCount:SetTextColor(0.55, 0.55, 0.55)

local scroll = CreateFrame("ScrollFrame", "BitacoraSessScroll", sess, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 4, -30)
scroll:SetPoint("BOTTOMRIGHT", -26, STATS_H + 6)

local sessData = {}
local sessRows = {}
local UpdateSessions

local function LevelText(e)
    if e.l0 and e.l1 and e.l1 > e.l0 then return ("nivel %d > %d"):format(e.l0, e.l1) end
end

for i = 1, SESS_ROWS do
    local r = CreateFrame("Frame", nil, sess)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 6, -30 - (i - 1) * ROW_H)
    r:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
    r:EnableMouse(true)
    r.bg = Tex(r, "BACKGROUND", 1, 1, 1, (i % 2 == 0) and 0.03 or 0)
    r.bg:SetAllPoints()
    r.hl = Tex(r, "BACKGROUND", ACC[1], ACC[2], ACC[3], 0.08, 1)
    r.hl:SetAllPoints()
    r.hl:Hide()
    r.swatch = Tex(r, "ARTWORK", 1, 1, 1, 1)
    r.swatch:SetSize(2, ROW_H - 6)
    r.swatch:SetPoint("LEFT", 0, 0)
    r.when = Text(r, 10)
    r.when:SetPoint("LEFT", 8, 0)
    r.when:SetWidth(74)
    r.when:SetJustifyH("LEFT")
    r.when:SetTextColor(0.6, 0.6, 0.6)
    r.what = Text(r, 11)
    r.what:SetPoint("LEFT", r.when, "RIGHT", 4, 0)
    r.what:SetPoint("RIGHT", r, "RIGHT", -70, 0)
    r.what:SetJustifyH("LEFT")
    r.what:SetWordWrap(false)
    r.amount = Text(r, 11)
    r.amount:SetPoint("RIGHT", -4, 0)
    r.amount:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(self)
        self.hl:Show()
        local e = self.data
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(e.live and "Sesión en curso" or (e.est and "Sesión estimada" or "Sesión"), ACC[1], ACC[2], ACC[3])
        GameTooltip:AddDoubleLine("Personaje", "|c" .. ClassHex(e.class) .. e.char .. "|r", 0.7, 0.7, 0.7)
        GameTooltip:AddDoubleLine("Inicio", date("%d/%m/%Y %H:%M", e.s), 0.7, 0.7, 0.7, 1, 1, 1)
        if not e.live then GameTooltip:AddDoubleLine("Fin", date("%d/%m/%Y %H:%M", e.s + e.d), 0.7, 0.7, 0.7, 1, 1, 1) end
        GameTooltip:AddDoubleLine("Duración", ns.Dur(e.d), 0.7, 0.7, 0.7, 1, 1, 1)
        if e.a > 0 then GameTooltip:AddDoubleLine("Ausente (AFK)", ns.Dur(e.a), 0.7, 0.7, 0.7, 1, 1, 1) end
        if e.z and e.z ~= "" then GameTooltip:AddDoubleLine("Zona principal", e.z, 0.7, 0.7, 0.7, 1, 1, 1) end
        local lt = LevelText(e)
        if lt then GameTooltip:AddDoubleLine("Subida", lt, 0.7, 0.7, 0.7, 1, 0.82, 0) end
        if e.est then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Calculada con los movimientos de oro de Tesorero.", 0.6, 0.6, 0.6)
            GameTooltip:AddLine("La duración real pudo ser mayor.", 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function(self) self.hl:Hide() GameTooltip:Hide() end)
    sessRows[i] = r
end

local sessEmpty = Text(sess, 12)
sessEmpty:SetPoint("CENTER", 0, STATS_H / 2)
sessEmpty:SetTextColor(0.5, 0.5, 0.5)
sessEmpty:SetText("Sin sesiones en este periodo.")

function UpdateSessions()
    local offset = FauxScrollFrame_GetOffset(scroll)
    FauxScrollFrame_Update(scroll, #sessData, SESS_ROWS, ROW_H)
    for i = 1, SESS_ROWS do
        local r = sessRows[i]
        local e = sessData[offset + i]
        r.data = e
        if e then
            local cr, cg, cb = ClassRGB(e.class)
            if e.live then cr, cg, cb = GREEN[1], GREEN[2], GREEN[3] end
            r.swatch:SetColorTexture(cr, cg, cb, 0.9)
            local dl = DayLabel(e.s)
            if dl == "Hoy" or dl == "Ayer" then
                r.when:SetText(dl .. " " .. date("%H:%M", e.s))
            else
                r.when:SetText(date("%d/%m %H:%M", e.s))
            end
            local label = (e.z and e.z ~= "") and e.z or "Sesión"
            if not state.filter then
                label = "|c" .. ClassHex(e.class) .. e.char .. "|r |cff777777· " .. label .. "|r"
            end
            local lt = LevelText(e)
            if lt then label = label .. " |cffffd100· " .. lt .. "|r" end
            r.what:SetText(label)
            if e.live then
                r.amount:SetText("|cff4ade80" .. ns.Dur(e.d) .. "|r")
            elseif e.est then
                r.amount:SetText("|cff8c8c9e~" .. ns.Dur(e.d) .. "|r")
            else
                r.amount:SetText(ns.Dur(e.d))
            end
            r:Show()
        else
            r:Hide()
        end
    end
    sessEmpty:SetShown(#sessData == 0)
end
scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, UpdateSessions)
end)

-- Estadísticas al pie
local statsBox = CreateFrame("Frame", nil, sess)
statsBox:SetPoint("BOTTOMLEFT", 6, 6)
statsBox:SetPoint("BOTTOMRIGHT", -6, 6)
statsBox:SetHeight(STATS_H - 4)
local statsLine = Tex(statsBox, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.25)
statsLine:SetHeight(1)
statsLine:SetPoint("TOPLEFT", 2, 0)
statsLine:SetPoint("TOPRIGHT", -2, 0)

local stats = {}
local statNames = { "Sesión más larga", "Día más largo", "Racha actual", "Día favorito" }
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

local function SetStat(f, value, sub)
    f.value:SetText(value)
    f.sub:SetText(sub or "")
end

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
footRight:SetText("/bita ayuda")

local function TodayTotal(filter)
    local series = ns.DailySeries(filter, 1)
    return series[1].s
end

local function UpdateFooter()
    local s = ns.session
    if not s then footer:SetText("") return end
    local parts = {
        "|cff66c7ffSesión|r  ·  " .. ns.Dur(s.d),
        "desde las " .. date("%H:%M", s.s),
        "Hoy con este personaje: |cffffffff" .. ns.Dur(TodayTotal(ns.charKey)) .. "|r",
    }
    if s.a > 0 then parts[#parts + 1] = "|cff8c8c9e" .. ns.Dur(s.a) .. " ausente|r" end
    footer:SetText(table.concat(parts, "  ·  "))
end

---------------------------------------------------------------------------
-- Refrescar todo
---------------------------------------------------------------------------
local PERIOD_TEXT = { today = "desde las 00:00 de hoy", week = "últimos 7 días", month = "últimos 30 días", all = "desde que instalaste Bitácora" }

function ns.Refresh()
    if not main:IsShown() or not ns.db then return end
    if state.filter and not ns.db.chars[state.filter] then state.filter = nil end

    -- Botón de personaje
    if state.filter then
        local c = ns.db.chars[state.filter]
        charBtn.text:SetText("|c" .. ClassHex(c.class) .. ShortName(state.filter) .. "|r  |cff888888nivel " .. (c.level or "?") .. "|r")
    else
        charBtn.text:SetText("|cff66c7ffTodos los personajes|r")
    end

    for _, b in ipairs(periodBtns) do b:SetActive(b.key == state.period) end
    periodHint:SetText(PERIOD_TEXT[state.period])

    -- Tarjetas
    local sum = ns.Summary(state.filter, state.period)
    local played, n, lvlTime = ns.TotalPlayed(state.filter)
    cards[1].value:SetText(ns.Dur(played))
    if state.filter then
        cards[1].sub:SetText(lvlTime > 0 and (ns.Dur(lvlTime) .. " en este nivel") or "Tiempo /played")
    else
        cards[1].sub:SetText(Plural(n, "personaje", "personajes"))
    end

    if sum.total > 0 then
        cards[2].value:SetText(ns.Dur(sum.total))
        if sum.afk >= 60 then
            cards[2].sub:SetText(("%d%% ausente (AFK)"):format(math.floor(sum.afk / sum.total * 100 + 0.5)))
        else
            cards[2].sub:SetText("Sin tiempo ausente")
        end
        cards[3].value:SetText(ns.Dur(sum.total / sum.days))
        cards[3].sub:SetText(Plural(sum.days, "día jugado", "días jugados"))
    else
        cards[2].value:SetText(DASH)
        cards[2].sub:SetText("Nada todavía")
        cards[3].value:SetText(DASH)
        cards[3].sub:SetText("Sin días jugados")
    end

    local s = ns.session
    if s then
        cards[4].value:SetText(ns.Dur(s.d))
        local lt = LevelText(s)
        cards[4].sub:SetText("Desde las " .. date("%H:%M", s.s) .. (lt and (" · " .. lt) or ""))
    else
        cards[4].value:SetText(DASH)
        cards[4].sub:SetText("")
    end

    -- Gráfico
    local series = ns.DailySeries(state.filter, CHART_DAYS)
    local maxV, any = 60, false
    for _, e in ipairs(series) do
        maxV = math.max(maxV, e.s)
        if e.s > 0 then any = true end
    end
    for _, g in ipairs(gridLabels) do g.fs:SetText(any and ns.Dur(maxV * g.frac) or "") end
    chartEmpty:SetShown(not any)
    for i, slot in ipairs(slots) do
        local e = series[i]
        slot.data = e
        local active = math.max(0, e.s - e.a)
        slot.act:SetHeight(math.max(0.5, active / maxV * (PLOT_H - 2)))
        slot.afk:SetHeight(math.max(0.5, e.a / maxV * (PLOT_H - 2)))
        slot.act:SetShown(e.s > 0)
        slot.afk:SetShown(e.a > 0)
        slot.label:SetText(date("%d", e.t))
        if i == #slots then slot.label:SetTextColor(ACC[1], ACC[2], ACC[3]) else slot.label:SetTextColor(0.55, 0.55, 0.55) end
    end

    -- Ranking
    local list
    if state.filter then
        rankTitle:SetText("Por zona")
        rankHint:SetText("dónde pasas el tiempo")
        list = ns.Zones(state.filter, state.period)
        if #list > RANK_ROWS then
            local rest = 0
            for i = #list, RANK_ROWS, -1 do
                rest = rest + list[i].sec
                list[i] = nil
            end
            list[RANK_ROWS] = { name = "Otras zonas", sec = rest }
        end
    else
        rankTitle:SetText("Por personaje")
        rankHint:SetText("clic = ver ese personaje")
        list = ns.CharRanking(state.period)
    end
    local rankMax, rankTotal = 1, 0
    for _, e in ipairs(list) do
        rankMax = math.max(rankMax, e.sec)
        rankTotal = rankTotal + e.sec
    end
    for i, r in ipairs(rankRows) do
        local e = list[i]
        r.data = e
        if e then
            local cr, cg, cb
            if e.key then
                cr, cg, cb = ClassRGB(e.class)
            else
                local c = PALETTE[(i - 1) % #PALETTE + 1]
                cr, cg, cb = c[1], c[2], c[3]
            end
            r.swatch:SetColorTexture(cr, cg, cb, 1)
            r.bar:SetColorTexture(cr, cg, cb, 0.9)
            r.bar:SetWidth(math.max(1, e.sec / rankMax * BAR_W))
            r.name:SetText(e.name)
            r.name:SetTextColor(cr, cg, cb)
            r.pct:SetText(rankTotal > 0 and (math.floor(e.sec / rankTotal * 100 + 0.5) .. "%") or "")
            r.amount:SetText(ns.Dur(e.sec))
            r:Show()
        else
            r:Hide()
        end
    end
    rankEmpty:SetShown(#list == 0)

    -- Sesiones
    sessData = ns.Sessions(state.filter, state.period, 500)
    sessCount:SetText(#sessData >= 500 and "500+ sesiones" or Plural(#sessData, "sesión", "sesiones"))
    UpdateSessions()

    -- Estadísticas
    local longest
    for _, e in ipairs(sessData) do
        if not longest or e.d > longest.d then longest = e end
    end
    if longest and longest.d >= 60 then
        SetStat(stats[1], ns.Dur(longest.d), DayLabel(longest.s))
    else
        SetStat(stats[1], DASH)
    end
    if sum.bestDay then
        SetStat(stats[2], ns.Dur(sum.bestT), DayLabel(ns.DayKeyToTime(sum.bestDay)))
    else
        SetStat(stats[2], DASH)
    end
    if sum.streak > 0 then
        SetStat(stats[3], Plural(sum.streak, "día", "días"), "récord: " .. sum.bestStreak)
    else
        SetStat(stats[3], DASH, sum.bestStreak > 0 and ("récord: " .. sum.bestStreak) or nil)
    end
    if sum.weekday then
        SetStat(stats[4], DAY_NAMES[sum.weekday], ns.Dur(sum.weekdayT))
    else
        SetStat(stats[4], DASH)
    end

    UpdateFooter()
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
    if self.elapsed > 10 then
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
local mb = CreateFrame("Button", "BitacoraMinimapButton", Minimap)
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
mbIcon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
mbIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
mbIcon:SetPoint("TOPLEFT", 7, -6)
local mbBorder = mb:CreateTexture(nil, "OVERLAY")
mbBorder:SetSize(53, 53)
mbBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mbBorder:SetPoint("TOPLEFT")

local function PlaceMinimap()
    local a = math.rad(ns.db.settings.minimap.angle or 230)
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
    GameTooltip:AddLine("Bitácora", ACC[1], ACC[2], ACC[3])
    local key = ns.charKey
    local s = ns.session
    if s then GameTooltip:AddDoubleLine("Sesión actual", ns.Dur(s.d), 0.8, 0.8, 0.8, 1, 1, 1) end
    GameTooltip:AddDoubleLine("Hoy", ns.Dur(TodayTotal(key)), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Últimos 7 días", ns.Dur(ns.Summary(key, "week").total), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Total del personaje", ns.Dur((ns.TotalPlayed(key))), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Hoy en toda la cuenta", ns.Dur(TodayTotal(nil)), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Total de la cuenta", ns.Dur((ns.TotalPlayed(nil))), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffff00Clic|r para abrir · |cffffff00Arrastrar|r para mover", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

mb:SetScript("OnClick", function() ns.Toggle() end)
mb:SetScript("OnEnter", function(self) ShowSummaryTooltip(self) end)
mb:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Menú de complementos (AddonCompartment)
function Bitacora_OnCompartmentClick() ns.Toggle() end
function Bitacora_OnCompartmentEnter(_, button) ShowSummaryTooltip(button or UIParent, "ANCHOR_LEFT") end
function Bitacora_OnCompartmentLeave() GameTooltip:Hide() end

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
