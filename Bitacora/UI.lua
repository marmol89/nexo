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

local N = Nexo
local DAY_NAMES = N.DAY_NAMES
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
local K = N.Kit({
    acc = ACC,
    panelBg = { 0.08, 0.09, 0.11, 0.92 }, panelBorder = { 0.16, 0.21, 0.27, 1 },
    btnOn = { 0.08, 0.22, 0.34 }, btnOnText = { 0.75, 0.92, 1 },
    btnOff = { 0.11, 0.12, 0.14 }, btnBorder = { 0.20, 0.26, 0.32 }, btnHover = { 0.30, 0.60, 0.80 },
    winBg = { 0.04, 0.04, 0.05 }, winBorder = { 0.22, 0.48, 0.68 },
    headBg = { 0.05, 0.11, 0.17 }, sub = { 0.5, 0.62, 0.72 },
    closeBg = { 0.06, 0.10, 0.14 }, closeBorder = { 0.18, 0.36, 0.50 }, closeX = { 0.75, 0.88, 0.95 },
})
local Panel, Text, Tex, Button, SectionTitle = K.Panel, K.Text, K.Tex, K.Button, K.SectionTitle
local ClassHex, ClassRGB, ShortName, DayLabel, Plural = N.ClassHex, N.ClassRGB, N.ShortName, N.DayLabel, N.Plural

---------------------------------------------------------------------------
-- Ventana principal
---------------------------------------------------------------------------
local main, close = K.Window({
    name = "BitacoraMainFrame", w = W, h = H, icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    title = "Bitácora", subtitle = "Tiempo de juego · WoW Forever",
    settings = function() return ns.db and ns.db.settings end,
})

-- Selector de personaje
local charBtn = K.CharButton(main, close, {
    list = function() return ns.CharList() end,
    get = function() return state.filter end,
    set = function(key)
        state.filter = key
        ns.Refresh()
    end,
    all = true,
})

-- Pestañas de periodo
local periodBtns = K.Tabs(main, ns.PERIODS, 80, function(period)
    state.period = period
    ns.db.settings.period = period
    ns.Refresh()
end)
periodBtns[1]:SetPoint("TOPLEFT", PAD, -62)

local periodHint = Text(main, 11)
periodHint:SetPoint("LEFT", periodBtns[#periodBtns], "RIGHT", 12, 0)
periodHint:SetTextColor(0.6, 0.6, 0.6)

---------------------------------------------------------------------------
-- Tarjetas resumen
---------------------------------------------------------------------------
local cards = K.Cards(main, {
    { "Tiempo total", { 1, 0.82, 0 }, "Interface\\Icons\\INV_Misc_PocketWatch_01" },
    { "En el periodo", ACC, "Interface\\Icons\\INV_Misc_Note_01" },
    { "Media diaria", GREEN, "Interface\\Icons\\INV_Misc_Book_09" },
    { "Sesión actual", { 0.80, 0.45, 1 }, "Interface\\Icons\\Ability_Hunter_EagleEye" },
}, { x = PAD, y = -94, w = W - PAD * 2, valueSize = 16, tint = true })

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
local slots, gridLabels = K.Chart(chart, {
    n = CHART_DAYS, w = LEFT_W, plotH = PLOT_H, plotBottom = PLOT_BOTTOM, today = true,
    build = function(s, slotW)
        local bw = math.max(4, math.floor(slotW - 10))
        s.act = Tex(s, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.95)
        s.act:SetWidth(bw)
        s.act:SetPoint("BOTTOM", s, "BOTTOM", 0, PLOT_BOTTOM + 1)
        s.afk = Tex(s, "ARTWORK", AFK[1], AFK[2], AFK[3], 0.85)
        s.afk:SetWidth(bw)
        s.afk:SetPoint("BOTTOM", s.act, "TOP", 0, 0)
        s.label = Text(s, 9)
        s.label:SetPoint("BOTTOM", 0, 6)
    end,
    tooltip = function(self, e)
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
    end,
})

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

local stats = K.StatGrid(statsBox, { "Sesión más larga", "Día más largo", "Racha actual", "Día favorito" })
local function SetStat(f, value, sub) f:Set(value, sub) end

---------------------------------------------------------------------------
-- Pie
---------------------------------------------------------------------------
local footer = K.Footer(main, { h = FOOT_H, pad = PAD, right = "/bita ayuda" })

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
    charBtn:SetChar(state.filter, ns.db.chars[state.filter])

    periodBtns:Select(state.period)
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

function main:OnOpen() ns.Refresh() end
main:Every(10, function() ns.Refresh() end)

function ns.Toggle()
    main:SetShown(not main:IsShown())
end

---------------------------------------------------------------------------
-- Botón del minimapa
---------------------------------------------------------------------------

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

-- El botón del minimapa es el de Nexo, compartido por todos los addons
N.Register({
    id = "Bitacora", name = "Bitácora", icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", color = ACC, slash = "/bita",
    toggle = function() ns.Toggle() end,
    tooltip = ShowSummaryTooltip,
    data = "BitacoraDB",
})

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
    main:RestorePos()
end
