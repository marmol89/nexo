-- Senda: interfaz
local ADDON, ns = ...

local W, H = 780, 560
local PAD = 14
local LEFT_W = 372
local ROW_H = 20
local LEVEL_ROWS = 13
local CHART_LEVELS = 20
local BAR_FULL = W - PAD * 2 - 24

local N = Nexo
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
local K = N.Kit({
    acc = ACC,
    panelBg = { 0.08, 0.09, 0.11, 0.92 }, panelBorder = { 0.21, 0.17, 0.28, 1 },
    btnOn = { 0.20, 0.12, 0.34 }, btnOnText = { 0.90, 0.82, 1 },
    btnOff = { 0.11, 0.12, 0.14 }, btnBorder = { 0.26, 0.22, 0.32 }, btnHover = { 0.55, 0.42, 0.80 },
    winBg = { 0.04, 0.04, 0.05 }, winBorder = { 0.46, 0.34, 0.68 },
    headBg = { 0.10, 0.07, 0.17 }, sub = { 0.62, 0.55, 0.74 },
    closeBg = { 0.10, 0.07, 0.15 }, closeBorder = { 0.36, 0.27, 0.52 }, closeX = { 0.88, 0.80, 0.98 },
})
local Panel, Text, Tex, Button, SectionTitle = K.Panel, K.Text, K.Tex, K.Button, K.SectionTitle
local ClassHex, ShortName = N.ClassHex, N.ShortName

local function Pct(v)
    return (("%.1f"):format(v):gsub("%.", ",")) .. " %"
end

local function DateLabel(t)
    if ns.DayKey(t) == ns.DayKey() then return "Hoy " .. date("%H:%M", t) end
    if ns.DayKey(t) == ns.DayKey(time() - 86400) then return "Ayer " .. date("%H:%M", t) end
    return date("%d/%m/%y %H:%M", t)
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
local main, close = K.Window({
    name = "SendaMainFrame", w = W, h = H, icon = "Interface\\Icons\\INV_Misc_Map_01",
    title = "Senda", subtitle = "Subida de nivel · WoW Forever",
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
})

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
local cards = K.Cards(main, {
    { "Experiencia por hora", ACC, "Interface\\Icons\\INV_Misc_PocketWatch_01" },
    { "Para subir de nivel", GOLD, "Interface\\Icons\\INV_Misc_Map_01" },
    { "Esta sesión", GREEN, "Interface\\Icons\\INV_Misc_Note_01" },
    { "En este nivel", REST, "Interface\\Icons\\INV_Misc_Book_09" },
}, { x = PAD, y = -124, w = W - PAD * 2, valueSize = 16, tint = true })

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
local slots, gridLabels = K.Chart(chart, {
    n = CHART_LEVELS, w = LEFT_W, plotH = PLOT_H, plotBottom = PLOT_BOTTOM,
    build = function(s, slotW)
        s.bar = Tex(s, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.95)
        s.bar:SetWidth(math.max(4, math.floor(slotW - 6)))
        s.bar:SetPoint("BOTTOM", s, "BOTTOM", 0, PLOT_BOTTOM + 1)
        s.label = Text(s, 9)
        s.label:SetPoint("BOTTOM", 0, 6)
    end,
    tooltip = function(s, e) LevelTooltip(s, e) end,
})

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
local footer = K.Footer(main, { h = FOOT_H, pad = PAD, right = "/senda ayuda" })

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
function ns.OnDataChanged()
    if main:IsShown() then Nexo.Debounce("Senda.refresh", 0.3, ns.Refresh) end
end

function main:OnOpen() ns.Refresh() end
main:Every(5, function() ns.Refresh() end)

function ns.Toggle()
    main:SetShown(not main:IsShown())
end

---------------------------------------------------------------------------
-- Botón del minimapa
---------------------------------------------------------------------------

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

-- El botón del minimapa es el de Nexo, compartido por todos los addons
N.Register({
    id = "Senda", name = "Senda", icon = "Interface\\Icons\\INV_Misc_Map_01", color = ACC, slash = "/senda",
    toggle = function() ns.Toggle() end,
    tooltip = ShowSummaryTooltip,
    data = "SendaDB",
})

-- Menú de complementos (AddonCompartment)
function Senda_OnCompartmentClick() ns.Toggle() end
function Senda_OnCompartmentEnter(_, button) ShowSummaryTooltip(button or UIParent, "ANCHOR_LEFT") end
function Senda_OnCompartmentLeave() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Inicio
---------------------------------------------------------------------------
function ns.OnInit()
    state.filter = ns.charKey
    main:RestorePos()
end
