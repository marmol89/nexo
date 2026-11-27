local Tr = Nexo.T
Nexo.Dict({
    -- Cabeceras de las columnas y títulos
    ["Objeto"] = "Item",
    ["Precio"] = "Price",
    ["Vs. hab."] = "vs usual",
    ["Cambio"] = "Change",
    ["Diferencia"] = "Difference",
    ["Variación"] = "Variation",
    ["Venta"] = "Sale",
    ["Visto"] = "Seen",
    ["Tengo"] = "Have",
    ["Valor"] = "Value",
    ["Quiero"] = "Want",
    ["Resumen"] = "Summary",
    ["Mercado"] = "Market",
    -- Vistas
    ["Gangas"] = "Deals",
    ["Caros"] = "Pricey",
    ["Bajan"] = "Falling",
    ["Suben"] = "Rising",
    ["Todos los objetos con precio."] = "All items with a price.",
    ["Precio al menos un %d%% por debajo de lo habitual (la mediana de los días anteriores). Solo lo que estaba a la venta en el último escaneo."] =
        "Price at least %d%% below the usual one (the median of the previous days). Only what was on sale in the last scan.",
    ["Precio al menos un %d%% por encima de lo habitual: buen momento para vender. Solo lo que estaba a la venta en el último escaneo."] =
        "Price at least %d%% above the usual one: a good time to sell. Only what was on sale in the last scan.",
    ["Ha bajado al menos un %d%% desde la vez anterior que se vio. Solo lo que estaba a la venta en el último escaneo."] =
        "It has dropped at least %d%% since the previous time it was seen. Only what was on sale in the last scan.",
    ["Ha subido al menos un %d%% desde la vez anterior que se vio. Solo lo que estaba a la venta en el último escaneo."] =
        "It has risen at least %d%% since the previous time it was seen. Only what was on sale in the last scan.",
    -- Filtros
    ["Clic para ver solo esta calidad"] = "Click to show only this quality",
    ["Se pueden elegir varias."] = "You can pick several.",
    ["Categoría"] = "Category",
    ["Categoría: "] = "Category: ",
    ["Todas"] = "All",
    ["Última vez que se vio el precio"] = "Last time the price was seen",
    ["Visto: "] = "Seen: ",
    ["cualquier fecha"] = "any time",
    ["últimas 24 h"] = "last 24 h",
    ["últimos 3 días"] = "last 3 days",
    ["Mín. (oro)"] = "Min. (gold)",
    ["Máx. (oro)"] = "Max. (gold)",
    ["Precio por unidad"] = "Price per unit",
    ["En oro (1.5) o con monedas (1g 50s)."] = "In gold (1.5) or with coins (1g 50s).",
    ["Quitar filtros"] = "Clear filters",
    ["Ningún objeto cumple todos los filtros. Prueba a quitar alguno."] = "No item meets all the filters. Try removing one.",
    ["Hacen falta %d días de historial para comparar precios: escanea la subasta varios días."] =
        "You need %d days of history to compare prices: scan the auction on several days.",
    -- Detalle del objeto
    ["Cant."] = "Qty.",
    ["Apuntar"] = "Add",
    ["Guardar"] = "Save",
    ["Quitar"] = "Remove",
    ["Precio habitual"] = "Usual price",
    ["faltan días de historial|r"] = "not enough days of history|r",
    ["Cambio reciente"] = "Recent change",
    ["Mín. / máx. (%d d)"] = "Min. / max. (%d d)",
    ["Vendedor (NPC)"] = "Vendor (NPC)",
    ["Ganancia al vender al NPC|r"] = "Profit selling to the NPC|r",
    ["Mínimo por día · línea: precio habitual"] = "Daily minimum · line: usual price",
    ["Mínimo del día"] = "Minimum of the day",
    ["Aún sin historial de este objeto"] = "No history for this item yet",
    -- Resumen
    ["Con %d días de historial verás las gangas|r"] = "With %d days of history you will see the deals|r",
    ["y lo que sube o baja de precio.|r"] = "and what goes up or down in price.|r",
    ["Gangas (%d%% o más)"] = "Deals (%d%% or more)",
    ["Bajan · suben"] = "Falling · rising",
    ["Cambio en 7 días"] = "Change in 7 days",
})
-- Lonja: interfaz
local ADDON, ns = ...
if Nexo.Antiguo(ADDON) then return end

local W, H = 900, 640
local PAD = 14
local LIST_W = 560
local ROW_H = 24
local ROWS = 18
local LINE_H = 19
local LINES = 23
local DETAIL_W = W - PAD * 2 - LIST_W - 10
local BAR_W = DETAIL_W - 20

local N = Nexo
local floor, min, max = math.floor, math.min, math.max
local ACC = { 0.94, 0.47, 0.42 }
local ACC_HEX = "|cfff0786a"
local GREY = "|cff9a9090"
local GREEN, RED = "|cff66ff66", "|cffff6655"
local GOOD, BAD = { 0.40, 1, 0.40 }, { 1, 0.40, 0.33 }    -- barras del gráfico: más baratas / más caras que lo habitual
local ICON = "Interface\\Icons\\INV_Hammer_15"

local BUY_H = 58            -- hueco del detalle para apuntar el objeto en la lista de compra
local STALE = 3 * N.DAY     -- un precio visto hace más que esto se atenúa en la lista

-- own = solo lo que tienes (según Alijo); buy = solo la lista de compra; sel = objeto elegido;
-- view = all | deal | dear | down | up (ver ns.InView); quality = { [calidad] = true } (vacío = todas);
-- class = categoría (Enum.ItemClass) o nil; age = visto en los últimos N días (0 = cuando sea);
-- min / max = precio por unidad en cobre, o nil
local state = { text = "", own = false, buy = false, sort = "p", asc = false, sel = nil,
                view = "all", quality = {}, class = nil, age = 0, min = nil, max = nil }

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
local K = N.Kit({
    acc = ACC,
    panelBg = { 0.10, 0.07, 0.07, 0.92 }, panelBorder = { 0.28, 0.16, 0.15, 1 },
    btnOn = { 0.32, 0.12, 0.10 }, btnOnText = { 1, 0.86, 0.83 },
    btnOff = { 0.13, 0.10, 0.10 }, btnBorder = { 0.34, 0.20, 0.19 }, btnHover = { 0.75, 0.38, 0.34 },
    winBg = { 0.05, 0.035, 0.035 }, winBorder = { 0.62, 0.30, 0.27 },
    headBg = { 0.16, 0.07, 0.06 }, sub = { 0.76, 0.56, 0.53 },
    closeBg = { 0.14, 0.07, 0.06 }, closeBorder = { 0.48, 0.24, 0.21 }, closeX = { 0.97, 0.82, 0.79 },
})
local Panel, Text, Tex, Button, SectionTitle = K.Panel, K.Text, K.Tex, K.Button, K.SectionTitle
local Plural = N.Plural
local Money, Ago = ns.Money, ns.Ago
local P = ACC_HEX .. "Lonja:|r "

local function ClassHex(class) return N.ClassHex(class, "ffe8d0cc") end

local QualityRGB = N.QualityRGB

local function QualityHex(q)
    local r, g, b = QualityRGB(q)
    return ("|cff%02x%02x%02x"):format(floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

-- La diferencia como porcentaje con color: más barato (o, con invert, más valor) en verde y lo contrario en rojo
local function Pct(x, invert)
    if not x then return GREY .. "-|r" end
    local v = floor(math.abs(x) * 100 + 0.5)
    if v == 0 then return "0%" end
    local up = x > 0
    return ((up == (invert or false)) and GREEN or RED) .. (up and "+" or "-") .. min(v, 999) .. "%|r"
end

-- El elemento que sigue (dir = 1) o el que precede (dir = -1) a cur en una lista, dando la vuelta
local function Next(values, cur, dir)
    local idx = 1
    for i, v in ipairs(values) do
        if v == cur then idx = i end
    end
    return values[(idx - 1 + dir) % #values + 1]
end

---------------------------------------------------------------------------
-- Ventana principal
---------------------------------------------------------------------------
local main, close = K.Window({
    name = "LonjaMainFrame", w = W, h = H, icon = ICON,
    title = Tr("Lonja"), subtitle = Tr("Precios de la casa de subastas · WoW Forever"),
    settings = function() return ns.db and ns.db.settings end,
})

local function ScanClick()
    if ns.Scanning() then ns.StopScan() else ns.StartScan() end
end

local scanBtn = Button(main, 170, 24, Tr("Escanear subasta"), ScanClick)
scanBtn:SetPoint("RIGHT", close, "LEFT", -10, 0)
scanBtn:HookScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(Tr("Escanear la casa de subastas"))
    GameTooltip:AddLine(Tr("Guarda el precio de compra más bajo de cada objeto."), 0.8, 0.8, 0.8)
    GameTooltip:AddLine(Tr("Tiene que estar abierta la ventana de la subasta."), 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
scanBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------
-- Búsqueda y filtros
---------------------------------------------------------------------------
local list
local clearing = false      -- mientras se vacían los filtros no se repinta por cada cuadro
local function ResetScroll() list:Reset() end

-- Ha cambiado un filtro: volver arriba y repintar
local function OnFilter()
    if clearing then return end
    ResetScroll()
    ns.Refresh()
end

local BOX_BG, BOX_BORDER, BOX_HINT = { 0.09, 0.07, 0.07 }, { 0.34, 0.20, 0.19 }, { 0.5, 0.44, 0.43 }

-- Cuadro de texto pequeño sin colocar (el que llama lo ancla)
local function Box(parent, name, w, hint, onChange)
    local box = K.Search(parent, {
        name = name, x = 0, y = 0, w = w, hint = hint,
        bg = BOX_BG, border = BOX_BORDER, hintColor = BOX_HINT, onChange = onChange or function() end,
    })
    box:ClearAllPoints()
    return box
end

-- Primera fila: búsqueda, lo que tengo, lista de compra y las vistas
local search = K.Search(main, {
    name = "LonjaSearchBox", x = PAD, y = -62, w = 190, hint = Tr("Buscar objeto..."),
    bg = BOX_BG, border = BOX_BORDER, hintColor = BOX_HINT,
    onChange = function(text)
        state.text = text
        OnFilter()
    end,
})

local ownBtn = Button(main, 160, 22, "", function()
    state.own = not state.own
    OnFilter()
end)
ownBtn:SetPoint("LEFT", search, "RIGHT", 8, 0)

local buyFilter = Button(main, 150, 22, "", function()
    state.buy = not state.buy
    OnFilter()
end)

-- Vistas: qué objetos se destacan según cómo está su precio ahora comparado con su historial
local VIEWS = { { "all", Tr("Todo") }, { "deal", Tr("Gangas") }, { "dear", Tr("Caros") }, { "down", Tr("Bajan") }, { "up", Tr("Suben") } }
local VIEW_HELP = {
    all = "Todos los objetos con precio.",
    deal = "Precio al menos un %d%% por debajo de lo habitual (la mediana de los días anteriores). Solo lo que estaba a la venta en el último escaneo.",
    dear = "Precio al menos un %d%% por encima de lo habitual: buen momento para vender. Solo lo que estaba a la venta en el último escaneo.",
    down = "Ha bajado al menos un %d%% desde la vez anterior que se vio. Solo lo que estaba a la venta en el último escaneo.",
    up = "Ha subido al menos un %d%% desde la vez anterior que se vio. Solo lo que estaba a la venta en el último escaneo.",
}
-- Al elegir una vista se ordena por lo que más interesa en ella, que es lo que más dinero mueve por unidad
-- (el porcentaje por sí solo sube objetos baratos cuyo precio salta de un día a otro): { columna, de menor a mayor }
local VIEW_SORT = { deal = { "diff", true }, dear = { "diff", false }, down = { "step", true }, up = { "step", false } }

local TAB_W = 62
local viewTabs = K.Tabs(main, VIEWS, TAB_W, function(view)
    state.view = view
    local sort = VIEW_SORT[view]
    if sort then state.sort, state.asc = sort[1], sort[2] end
    OnFilter()
end)
viewTabs[1]:SetPoint("TOPLEFT", main, "TOPLEFT", W - PAD - (#VIEWS * TAB_W + (#VIEWS - 1) * 6), -62)
for _, b in ipairs(viewTabs) do
    b:HookScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(s.text:GetText())
        GameTooltip:AddLine((Tr(VIEW_HELP[s.key])):format(ns.Threshold()), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Segunda fila: calidad, categoría, antigüedad del precio y rango de precio
local chips = {}
for i = 0, 5 do
    local c = CreateFrame("Button", nil, main, N.TEMPLATE)
    c:SetSize(20, 22)
    c:SetBackdrop(N.BD)
    c.fill = Tex(c, "ARTWORK", 1, 1, 1, 1)
    c.fill:SetPoint("TOPLEFT", 4, -4)
    c.fill:SetPoint("BOTTOMRIGHT", -4, 4)
    c.q = i
    if i == 0 then
        c:SetPoint("TOPLEFT", main, "TOPLEFT", PAD, -90)
    else
        c:SetPoint("LEFT", chips[i], "RIGHT", 4, 0)
    end
    c:SetScript("OnClick", function()
        state.quality[i] = (not state.quality[i]) or nil
        OnFilter()
    end)
    c:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(_G["ITEM_QUALITY" .. i .. "_DESC"] or tostring(i), QualityRGB(i))
        GameTooltip:AddLine(Tr("Clic para ver solo esta calidad"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(Tr("Se pueden elegir varias."), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    chips[i + 1] = c
end

local function PaintChips()
    for _, c in ipairs(chips) do
        local r, g, b = QualityRGB(c.q)
        local on = state.quality[c.q]
        c.fill:SetColorTexture(r, g, b, on and 1 or 0.3)
        c:SetBackdropColor(0.09, 0.07, 0.07, 1)
        if on then
            c:SetBackdropBorderColor(r, g, b, 1)
        else
            c:SetBackdropBorderColor(BOX_BORDER[1], BOX_BORDER[2], BOX_BORDER[3], 1)
        end
    end
end

local catList = { 0 }       -- 0 = todas las categorías, y las que hay ahora en la lista
local catBtn = K.Cycle(main, 170, 22, Tr("Categoría"), function(dir)
    local c = Next(catList, state.class or 0, dir)
    state.class = c ~= 0 and c or nil
    OnFilter()
end, 11)
catBtn:SetPoint("LEFT", chips[#chips], "RIGHT", 10, 0)

local AGE_ORDER = { 0, 1, 3, 7 }
local AGE_NAMES = { [0] = "cualquier fecha", [1] = "últimas 24 h", [3] = "últimos 3 días", [7] = "últimos 7 días" }
local ageBtn = K.Cycle(main, 150, 22, Tr("Última vez que se vio el precio"), function(dir)
    state.age = Next(AGE_ORDER, state.age, dir)
    OnFilter()
end, 11)
ageBtn:SetPoint("LEFT", catBtn, "RIGHT", 6, 0)

local minBox, maxBox
local function ReadPrices()
    state.min, state.max = ns.ParseMoney(minBox:GetText()), ns.ParseMoney(maxBox:GetText())
end
local function OnPrice()
    if clearing then return end
    ReadPrices()
    OnFilter()
end
minBox = Box(main, "LonjaMinPrice", 66, Tr("Mín. (oro)"), OnPrice)
minBox:SetPoint("LEFT", ageBtn, "RIGHT", 10, 0)
maxBox = Box(main, "LonjaMaxPrice", 66, Tr("Máx. (oro)"), OnPrice)
maxBox:SetPoint("LEFT", minBox, "RIGHT", 4, 0)
for _, box in ipairs({ minBox, maxBox }) do
    box:HookScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(Tr("Precio por unidad"))
        GameTooltip:AddLine(Tr("En oro (1.5) o con monedas (1g 50s)."), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    box:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Cuántos filtros hay puestos (la búsqueda cuenta como uno)
local function ActiveCount()
    local n = 0
    for _, on in ipairs({ state.text ~= "", state.own, state.buy, state.view ~= "all", next(state.quality) ~= nil,
                          state.class ~= nil, state.age ~= 0, state.min ~= nil, state.max ~= nil }) do
        if on then n = n + 1 end
    end
    return n
end

local function ClearFilters()
    clearing = true
    state.own, state.buy, state.view = false, false, "all"
    state.quality, state.class, state.age, state.min, state.max = {}, nil, 0, nil, nil
    state.text = ""
    search:SetText("")
    minBox:SetText("")
    maxBox:SetText("")
    clearing = false
end

local clearBtn = Button(main, 100, 22, Tr("Quitar filtros"), function()
    ClearFilters()
    ResetScroll()
    ns.Refresh()
end, 11)
clearBtn:SetPoint("LEFT", maxBox, "RIGHT", 10, 0)

local countText = Text(main, 11)
countText:SetPoint("RIGHT", main, "TOPRIGHT", -PAD, -101)
countText:SetTextColor(0.6, 0.6, 0.6)

---------------------------------------------------------------------------
-- Lista de objetos
---------------------------------------------------------------------------
local TOP_Y = -120
local FOOT_H = 30
local contentH = H + TOP_Y - FOOT_H - 8

-- Columnas: borde derecho de cada una, medido desde la izquierda de la fila
local COL_PRICE, COL_2, COL_3, COL_4 = 296, 358, 414, 516

local alijo = false
local UpdateDetail

local function RightText(r, edge, width, size)
    local fs = Text(r, size or 11)
    fs:SetPoint("RIGHT", r, "LEFT", edge, 0)
    fs:SetWidth(width)
    fs:SetJustifyH("RIGHT")
    fs:SetWordWrap(false)
    return fs
end

-- Dinero con signo: en verde si ahora es menos (más barato), en rojo si es más
local function Signed(c)
    if not c then return GREY .. "-|r" end
    if c == 0 then return "0" end
    return (c < 0 and GREEN .. "-" or RED .. "+") .. Money(math.abs(c), 11) .. "|r"
end

-- Lo que enseña cada columna que cambia según la vista: su cabecera y cómo se escribe (el orden usa e[clave])
local COLS = {
    dev = { label = Tr("Vs. hab."), text = function(e) return Pct(e.dev) end },
    chg = { label = Tr("Cambio"), text = function(e) return Pct(e.chg) end },
    diff = { label = Tr("Diferencia"), text = function(e) return Signed(e.diff) end },
    step = { label = Tr("Variación"), text = function(e) return Signed(e.step) end },
    n = { label = Tr("Venta"), text = function(e) return e.n end },
    t = { label = Tr("Visto"), text = function(e) return GREY .. Ago(e.t) .. "|r" end },
    have = { label = Tr("Tengo"), text = function(e) return e.have > 0 and e.have or GREY .. "-|r" end },
    value = { label = Tr("Valor"), text = function(e) return e.value > 0 and Money(e.value, 11) or GREY .. "-|r" end },
    -- En verde lo que ahora mismo está a su precio
    want = { label = Tr("Quiero"), text = function(e) return ((e.p > 0 and e.p <= e.max) and GREEN or "") .. e.want end },
    max = { label = Tr("Máximo"), text = function(e) return Money(e.max, 11) end },
}
local cols = { COLS.dev, COLS.n, COLS.t }      -- las tres columnas de la derecha ahora mismo

-- Qué enseñan las tres columnas de la derecha según la vista y los filtros: la diferencia con lo habitual
-- (o con la vez anterior, en las bajadas y subidas) en porcentaje y en dinero, y lo demás según lo que se mire
local function ColumnKeys()
    local view = state.view
    local moves = view == "down" or view == "up"
    local c2 = moves and "chg" or "dev"
    if state.buy then return c2, "want", "max" end
    if view ~= "all" then return c2, (view == "dear" and alijo) and "have" or "n", moves and "step" or "diff" end
    if alijo then return c2, "have", "value" end
    return c2, "n", "t"
end

-- El precio, apagado si hace tiempo que no se ve
local function PriceText(e)
    if e.p <= 0 then return GREY .. "-|r" end
    local text = Money(e.p, 11)
    if time() - e.t > STALE then return GREY .. text .. "|r" end
    return text
end

list = K.List(main, {
    name = "LonjaListScroll", x = PAD, y = TOP_Y, w = LIST_W, h = contentH,
    rows = ROWS, rowH = ROW_H, nameW = 164, emptyW = 420,
    build = function(r)
        r.price = RightText(r, COL_PRICE, 92)
        r.c2 = RightText(r, COL_2, 56)
        r.c3 = RightText(r, COL_3, 50)
        r.c3:SetTextColor(0.78, 0.72, 0.70)
        r.c4 = RightText(r, COL_4, 92)
    end,
    fill = function(r, e)
        r.name:SetTextColor(QualityRGB(e.q))
        r.price:SetText(PriceText(e))
        r.c2:SetText(cols[1].text(e))
        r.c3:SetText(cols[2].text(e))
        r.c4:SetText(cols[3].text(e))
    end,
    item = function(e) return e.id end,
    selected = function(e) return state.sel == e.id end,
    click = function(e)
        state.sel = (state.sel ~= e.id) and e.id or nil     -- segundo clic: volver al resumen
        UpdateDetail()
    end,
})
local listPanel, listEmpty = list.panel, list.empty

-- Los números se ordenan primero de mayor a menor; el nombre, de la A a la Z
local sorter = K.Sorter(listPanel, state, function()
    ResetScroll()
    ns.Refresh()
end, { 0.76, 0.56, 0.53 })
sorter:Add("name", Tr("Objeto"), 36, 140)
sorter:Add("p", Tr("Precio"), 6 + COL_PRICE - 92, 92, "RIGHT")
-- Su clave y su texto dependen de la vista (ver ColumnKeys)
local h2 = sorter:Add(nil, "", 6 + COL_2 - 56, 56, "RIGHT")
local h3 = sorter:Add(nil, "", 6 + COL_3 - 50, 50, "RIGHT")
local h4 = sorter:Add(nil, "", 6 + COL_4 - 92, 92, "RIGHT")

---------------------------------------------------------------------------
-- Panel derecho: resumen o detalle del objeto elegido
---------------------------------------------------------------------------
local detail = Panel(main)
detail:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 10, 0)
detail:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, TOP_Y)
detail:SetHeight(contentH)
local dTitle = SectionTitle(detail, Tr("Resumen"))

local dIcon, dName = K.DetailHead(detail)
local dSub = Text(detail, 11)
dSub:SetPoint("BOTTOMLEFT", dIcon, "BOTTOMRIGHT", 8, 0)
dSub:SetTextColor(0.72, 0.64, 0.62)

-- Líneas genéricas: { l = texto izquierdo, r = texto derecho, bar = 0..1, color = {r, g, b}, item = id }.
-- Las de arriba van encima del gráfico (o ocupan todo el panel en el resumen) y las de abajo debajo.
local topOpt = { n = LINES, lineH = LINE_H, barW = BAR_W, height = contentH, grey = GREY, items = true }
local topLines = K.Lines(detail, topOpt)
local botOpt = { n = 8, lineH = LINE_H, barW = BAR_W, height = contentH, grey = GREY }
local botLines = K.Lines(detail, botOpt)

-- height = hasta dónde llega el hueco de las líneas, medido desde arriba del panel
local function RenderTop(lines, top, height)
    topOpt.height = height
    topLines:Render(lines, top)
end

local function Title(text) return { l = ACC_HEX .. text .. "|r" } end

-- Pie del detalle: precio máximo y cantidad para la lista de compra
local buyBox = CreateFrame("Frame", nil, detail)
buyBox:SetPoint("BOTTOMLEFT", 6, 6)
buyBox:SetPoint("BOTTOMRIGHT", -6, 6)
buyBox:SetHeight(BUY_H - 8)
local buyHint = Text(buyBox, 10)
buyHint:SetPoint("TOPLEFT", 2, -2)
buyHint:SetTextColor(0.72, 0.64, 0.62)
buyHint:SetText(Tr("Lista de compra: precio máximo por unidad y cantidad"))

local buyPrice = Box(buyBox, "LonjaBuyPrice", 78, Tr("Oro: 1.5"))
buyPrice:SetPoint("BOTTOMLEFT", 0, 0)
local buyQty = Box(buyBox, "LonjaBuyQty", 50, Tr("Cant."))
buyQty:SetPoint("LEFT", buyPrice, "RIGHT", 4, 0)

local filledFor     -- objeto con el que se rellenaron los cuadros: no se pisan mientras escribes

local buySave = Button(buyBox, 64, 22, Tr("Apuntar"), function()
    local price, qty = ns.ParseMoney(buyPrice:GetText()), tonumber(buyQty:GetText())
    if not price or not qty or qty < 1 then
        print(ACC_HEX .. Tr("Lonja:|r pon el precio máximo por unidad (en oro: 1.5, o 1g 50s) y cuántas unidades quieres."))
        return
    end
    buyPrice:ClearFocus()
    buyQty:ClearFocus()
    filledFor = nil
    ns.BuySet(state.sel, price, floor(qty))
end, 11)
buySave:SetPoint("LEFT", buyQty, "RIGHT", 4, 0)

local buyDrop = Button(buyBox, 56, 22, Tr("Quitar"), function()
    filledFor = nil
    ns.BuyRemove(state.sel)
end, 11)
buyDrop:SetPoint("LEFT", buySave, "RIGHT", 4, 0)

local function UpdateBuyBox(id)
    buyBox:SetShown(id ~= nil)
    if not id then
        filledFor = nil
        return
    end
    local b = ns.BuyGet(id)
    buySave.text:SetText(b and Tr("Guardar") or Tr("Apuntar"))
    buyDrop:SetShown(b ~= nil)
    if filledFor ~= id then
        filledFor = id
        buyPrice:SetText(b and ns.MoneyPlain(b.p) or "")
        buyQty:SetText(b and b.n or "")
    end
end

-- Gráfico del historial: el precio mínimo de cada día, con una línea en el precio habitual
local CHART_DAYS = ns.HISTORY_DAYS
local TOP_LINES = 5                             -- líneas que caben encima del gráfico
local CHART_TOP = 84 + TOP_LINES * LINE_H + 4
local CHART_H = 104
local PLOT_H, PLOT_BOTTOM = 70, 16
local chartUsual                                -- precio habitual del objeto elegido (para el tooltip de cada barra)

local chartBox = Panel(detail, { 0.08, 0.06, 0.06, 0.9 }, { 0.22, 0.13, 0.12, 1 })
chartBox:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -CHART_TOP)
chartBox:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -8, -CHART_TOP)
chartBox:SetHeight(CHART_H)
local chartTitle = Text(chartBox, 10)
chartTitle:SetPoint("TOPLEFT", 8, -6)
chartTitle:SetTextColor(0.62, 0.56, 0.55)
chartTitle:SetText(Tr("Mínimo por día · línea: precio habitual"))

local slots, gridLabels = K.Chart(chartBox, {
    n = CHART_DAYS, w = DETAIL_W - 16, plotH = PLOT_H, plotBottom = PLOT_BOTTOM, today = true,
    build = function(s, slotW)
        s.bar = Tex(s, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.95)
        s.bar:SetWidth(max(3, floor(slotW - 6)))
        s.bar:SetPoint("BOTTOM", s, "BOTTOM", 0, PLOT_BOTTOM + 1)
        s.label = Text(s, 9)
        s.label:SetPoint("BOTTOM", 0, 3)
    end,
    tooltip = function(self, e)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(N.DayLabel(e.t), ACC[1], ACC[2], ACC[3])
        GameTooltip:AddDoubleLine(Tr("Mínimo del día"), Money(e.p, 12, true), 0.8, 0.8, 0.8, 1, 1, 1)
        if chartUsual then
            GameTooltip:AddDoubleLine(Tr("Precio habitual"), Money(chartUsual, 12, true) .. "  " .. Pct(e.p / chartUsual - 1), 0.8, 0.8, 0.8, 1, 1, 1)
        end
        GameTooltip:Show()
    end,
})

-- La línea del precio habitual va en un marco propio, creado después de las barras para que quede por encima
-- (un marco sin ratón no tapa los tooltips de las barras)
local lineFrame = CreateFrame("Frame", nil, chartBox)
lineFrame:SetAllPoints()
local usualLine = Tex(lineFrame, "OVERLAY", 1, 1, 1, 0.55)
usualLine:SetHeight(1)

local chartEmpty = Text(chartBox, 11)
chartEmpty:SetPoint("CENTER", 0, 4)
chartEmpty:SetTextColor(0.5, 0.5, 0.5)
chartEmpty:SetText(Tr("Aún sin historial de este objeto"))

-- s = estadísticas del objeto (ns.Stats), o nil si no tiene precio
local function UpdateChart(id, s)
    local series = ns.Series(id, CHART_DAYS)
    local top, n = 0, 0
    for _, e in ipairs(series) do
        if e.p then n, top = n + 1, max(top, e.p) end
    end
    chartUsual = s and s.usual
    if chartUsual then top = max(top, chartUsual) end
    local thr = ns.Threshold() / 100
    chartEmpty:SetShown(n == 0)
    for _, g in ipairs(gridLabels) do g.fs:SetText(top > 0 and Money(top * g.frac, 9) or "") end
    for i, slot in ipairs(slots) do
        local e = series[i]
        slot.data = e.p and e or nil
        slot.bar:SetShown(e.p ~= nil)
        if e.p then
            slot.bar:SetHeight(max(1, e.p / top * (PLOT_H - 2)))
            local c = ACC
            if chartUsual then
                if e.p <= chartUsual * (1 - thr) then c = GOOD elseif e.p >= chartUsual * (1 + thr) then c = BAD end
            end
            slot.bar:SetColorTexture(c[1], c[2], c[3], 0.95)
        end
        slot.label:SetText(date("%d", e.t))
        if i == #slots then slot.label:SetTextColor(ACC[1], ACC[2], ACC[3]) else slot.label:SetTextColor(0.55, 0.55, 0.55) end
    end
    if chartUsual and top > 0 then
        local y = PLOT_BOTTOM + 1 + chartUsual / top * (PLOT_H - 2)
        usualLine:ClearAllPoints()
        usualLine:SetPoint("BOTTOMLEFT", chartBox, "BOTTOMLEFT", 10, y)
        usualLine:SetPoint("BOTTOMRIGHT", chartBox, "BOTTOMRIGHT", -10, y)
        usualLine:Show()
    else
        usualLine:Hide()
    end
end

-- Las mejores gangas de ahora, la que más ahorra por unidad primero
local function BestDeals(k)
    local out = {}
    for _, e in ipairs(ns.Index()) do
        if ns.InView("deal", e) then out[#out + 1] = e end
    end
    table.sort(out, function(a, b)
        if a.diff ~= b.diff then return a.diff < b.diff end
        return a.id < b.id
    end)
    for i = #out, k + 1, -1 do out[i] = nil end
    return out
end

-- Resumen: cuántos precios hay, cómo está el mercado, la lista de compra y lo que vale lo guardado en la cuenta
local function OverviewLines()
    local count = ns.Count()
    local lines = {
        Title(Tr("Precios guardados")),
        { l = Tr("Objetos con precio"), r = "|cffffffff" .. N.Num(count) .. "|r" },
        { l = Tr("Último escaneo completo"), r = Ago(ns.realm.lastScan) },
    }
    lines[#lines + 1] = { l = Tr("Escanear al abrir la subasta"), r = ns.AutoScan() and GREEN .. Tr("sí|r") or GREY .. "no|r" }
    if count == 0 then
        lines[#lines + 1] = {}
        lines[#lines + 1] = { l = GREY .. Tr("Abre la casa de subastas y pulsa|r") }
        lines[#lines + 1] = { l = GREY .. Tr("\"Escanear subasta\" para empezar.|r") }
        local wanted = ns.BuyCount()
        if wanted > 0 then
            lines[#lines + 1] = {}
            lines[#lines + 1] = Title(Tr("Lista de compra"))
            lines[#lines + 1] = { l = Tr("Objetos apuntados"), r = "|cffffffff" .. wanted .. "|r" }
        end
        return lines
    end

    -- Mercado: lo que se sale de lo habitual
    local market = ns.Market()
    lines[#lines + 1] = {}
    lines[#lines + 1] = Title(Tr("Mercado"))
    if market.known == 0 then
        lines[#lines + 1] = { l = GREY .. (Tr("Con %d días de historial verás las gangas|r")):format(ns.MIN_BASE + 1) }
        lines[#lines + 1] = { l = GREY .. Tr("y lo que sube o baja de precio.|r") }
    else
        lines[#lines + 1] = { l = (Tr("Gangas (%d%% o más)")):format(ns.Threshold()), r = (market.deal > 0 and GREEN or GREY) .. market.deal .. "|r" }
        lines[#lines + 1] = { l = Tr("Bajan · suben"), r = market.down .. GREY .. " · |r" .. market.up }
        for _, e in ipairs(BestDeals(4)) do
            lines[#lines + 1] = {
                l = QualityHex(e.q) .. e.name .. "|r", r = Pct(e.dev) .. GREY .. " · |r" .. Money(e.p, 11), item = e.id,
            }
        end
    end

    local wanted = ns.BuyCount()
    if wanted > 0 then
        lines[#lines + 1] = {}
        lines[#lines + 1] = Title(Tr("Lista de compra"))
        lines[#lines + 1] = { l = Tr("Objetos apuntados"), r = "|cffffffff" .. wanted .. "|r" }
        lines[#lines + 1] = { l = Tr("A tu precio ahora"), r = GREEN .. #ns.Deals() .. "|r" }
    end

    lines[#lines + 1] = {}
    lines[#lines + 1] = Title(Tr("Valor de lo guardado"))
    local total, chars = ns.AccountValue()
    if not total then
        lines[#lines + 1] = { l = GREY .. Tr("Con Alijo activado verás lo que vale|r") }
        lines[#lines + 1] = { l = GREY .. Tr("lo que tienes en bolsas y bancos.|r") }
        return lines
    end
    lines[#lines + 1] = { l = Tr("Toda la cuenta"), r = Money(total, 11) }
    local now, before = ns.AccountTrend(7)
    if now and before > 0 then
        lines[#lines + 1] = { l = Tr("Cambio en 7 días"), r = Pct(now / before - 1, true) }
    end
    for _, c in ipairs(chars) do
        lines[#lines + 1] = {
            l = "|c" .. ClassHex(c.class) .. c.name .. "|r", r = Money(c.value, 11),
            bar = c.value / chars[1].value,
        }
    end
    if #chars == 0 then
        lines[#lines + 1] = { l = GREY .. Tr("Nada de lo que tienes tiene precio.|r") }
    end
    return lines
end

-- Detalle de un objeto, en dos tandas: lo que va encima del gráfico (precio y lo que dice su historial)
-- y lo que va debajo (lo que tienes, la lista de compra y el vendedor). s = ns.Stats(id), o nil
local function ItemLines(id, s)
    local p, _, n = ns.Price(id)
    local top = {
        { l = Tr("Mínimo por unidad"), r = p and Money(p, 11, true) or GREY .. Tr("sin ver|r") },
    }
    if s and s.usual then
        top[#top + 1] = { l = Tr("Precio habitual"), r = Money(s.usual, 11, true) .. "  " .. Pct(s.dev) }
    else
        top[#top + 1] = { l = Tr("Precio habitual"), r = GREY .. Tr("faltan días de historial|r") }
    end
    if s and s.chg then top[#top + 1] = { l = Tr("Cambio reciente"), r = Pct(s.chg) } end
    if s and s.lo and s.days > 1 then
        top[#top + 1] = {
            l = (Tr("Mín. / máx. (%d d)")):format(s.days), r = Money(s.lo, 11) .. GREY .. " / |r" .. Money(s.hi, 11),
        }
    end
    top[#top + 1] = { l = Tr("Unidades a la venta"), r = "|cffffffff" .. N.Num(n or 0) .. "|r" }

    local bot = {}
    local have = ns.Have(id)
    if have then
        local worth = (have > 0 and p) and (GREY .. " · |r" .. Money(have * p, 11)) or ""
        bot[#bot + 1] = { l = Tr("Tienes en la cuenta"), r = "|cffffffff" .. N.Num(have) .. "|r" .. worth }
    end
    local b = ns.BuyGet(id)
    if b then
        bot[#bot + 1] = Title(Tr("Lista de compra"))
        bot[#bot + 1] = { l = Tr("Comprar hasta"), r = Money(b.p, 11, true) }
        bot[#bot + 1] = { l = Tr("Quedan por comprar"), r = "|cffffffff" .. N.Num(b.n) .. "|r" }
        if p and p <= b.p then bot[#bot + 1] = { l = GREEN .. Tr("Ahora está a tu precio|r") } end
    end
    -- Lo que paga el vendedor: si en la subasta cuesta menos, comprarlo para venderlo da ganancia
    local vendor = p and ns.Vendor(id)
    if vendor then
        bot[#bot + 1] = { l = Tr("Vendedor (NPC)"), r = Money(vendor, 11) }
        if p < vendor then
            bot[#bot + 1] = { l = GREEN .. Tr("Ganancia al vender al NPC|r"), r = GREEN .. Money(vendor - p, 11) .. "|r" }
        end
    end
    return top, bot
end

function UpdateDetail()
    local has = state.sel ~= nil and (ns.Price(state.sel) ~= nil or ns.BuyGet(state.sel) ~= nil)
    dIcon:SetShown(has)
    dName:SetShown(has)
    dSub:SetShown(has)
    chartBox:SetShown(has)
    UpdateBuyBox(has and state.sel or nil)
    if not has then
        dTitle:SetText(Tr("Resumen"))
        botLines:Render({}, 0)
        RenderTop(OverviewLines(), 32, contentH)
        return
    end
    local id = state.sel
    local name, quality, icon = ns.ItemInfo(id)
    local _, t = ns.Price(id)
    dTitle:SetText(Tr("Objeto"))
    dIcon:SetTexture(icon)
    dName:SetText(name)
    dName:SetTextColor(QualityRGB(quality))
    dSub:SetText(Tr("visto ") .. Ago(t))
    local s = ns.Stats(id)
    local top, bot = ItemLines(id, s)
    RenderTop(top, 84, 84 + #top * LINE_H + 8)
    UpdateChart(id, s)
    botOpt.height = contentH - BUY_H
    botLines:Render(bot, CHART_TOP + CHART_H + 6)
end

---------------------------------------------------------------------------
-- Pie
---------------------------------------------------------------------------
local footer = K.Footer(main, { h = FOOT_H, pad = PAD, right = "/lonja " .. Nexo.Cmd("lonja", "help") })

-- Botones que se añaden a la ventana de la subasta: escanear y comprar lo de la lista
local ahBtn, ahBuy

local function UpdateBuyState()
    if not ahBuy then return end
    local label, spends = ns.BuyStatus()
    ahBuy:SetShown(label ~= nil)
    ahBuy.text:SetText(label or "")
    ahBuy:SetActive(spends or false)
end

local function UpdateScanState()
    local status = ns.ScanStatus()
    local label = status and Tr("Parar escaneo") or Tr("Escanear subasta")
    scanBtn.text:SetText(label)
    scanBtn:SetActive(status ~= nil)
    if ahBtn then
        ahBtn.text:SetText(status and Tr("Lonja: parar") or Tr("Lonja: escanear"))
        ahBtn:SetActive(status ~= nil)
    end
    UpdateBuyState()
    if not main:IsShown() or not ns.realm then return end
    if status then
        footer:SetText(ACC_HEX .. status .. "|r")
    elseif ns.IsOpen() then
        footer:SetText(ns.realmKey .. Tr("  ·  |cff66ff66subasta abierta|r: las búsquedas que hagas también se apuntan"))
    else
        footer:SetText(ns.realmKey .. Tr("  ·  último escaneo ") .. Ago(ns.realm.lastScan) .. Tr("  ·  Mayús+clic: enlazar en el chat"))
    end
end
ns.OnScanProgress = UpdateScanState

function ns.OnAuctionShow()
    -- La ventana de la subasta se carga con el propio evento: espera a que exista
    C_Timer.After(0, function()
        local parent = AuctionFrame or AuctionHouseFrame
        if ahBtn or not parent then return end
        ahBtn = Button(parent, 120, 22, Tr("Lonja: escanear"), ScanClick, 11)
        ahBtn:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", -6, 2)
        ahBuy = Button(parent, 300, 22, "", function() ns.BuyClick() end, 11)
        ahBuy:SetPoint("RIGHT", ahBtn, "LEFT", -6, 0)
        ahBuy:HookScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_TOP")
            GameTooltip:AddLine(Tr("Lista de compra de Lonja"))
            GameTooltip:AddLine(Tr("Cada clic da un paso: buscar el objeto, comprarlo y,"), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(Tr("si es un material, confirmar el precio final."), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(Tr("El juego no deja comprar a un addon sin un clic tuyo."), 0.8, 0.8, 0.8)
            GameTooltip:AddLine(Tr("Resaltado: el siguiente clic gasta dinero."), ACC[1], ACC[2], ACC[3])
            GameTooltip:Show()
        end)
        ahBuy:HookScript("OnLeave", function() GameTooltip:Hide() end)
        UpdateScanState()
    end)
end

---------------------------------------------------------------------------
-- Refrescar todo
---------------------------------------------------------------------------
-- ¿Pasa e (una entrada de ns.Index) todos los filtros? b = su entrada en la lista de compra, si la tiene
local function Passes(e, b, now)
    if state.own and e.have <= 0 then return false end
    if state.buy and not b then return false end
    if state.text ~= "" and not e.lower:find(state.text, 1, true) then return false end
    if next(state.quality) and not state.quality[min(e.q, 5)] then return false end
    if state.class and e.cls ~= state.class then return false end
    if state.min or state.max then
        if e.p <= 0 then return false end
        if state.min and e.p < state.min then return false end
        if state.max and e.p > state.max then return false end
    end
    if state.age > 0 and (e.t == 0 or now - e.t > state.age * N.DAY) then return false end
    return ns.InView(state.view, e)
end

-- Pone al día los controles de filtro: lo que se ve, lo que está pulsado y las categorías que hay
local function UpdateControls(all)
    ownBtn:SetShown(alijo)
    ownBtn.text:SetText(state.own and Tr("Solo lo que tengo") or Tr("Todos los objetos"))
    ownBtn:SetActive(state.own)

    buyFilter:ClearAllPoints()
    buyFilter:SetPoint("LEFT", alijo and ownBtn or search, "RIGHT", 8, 0)
    buyFilter.text:SetText(Tr("Lista de compra (") .. ns.BuyCount() .. ")")
    buyFilter:SetActive(state.buy)

    viewTabs:Select(state.view)
    PaintChips()

    -- Categorías de los objetos que hay: la elegida deja de valer si ya no hay ninguno
    local seen = {}
    catList = { 0 }
    for _, e in ipairs(all) do
        if e.cls and not seen[e.cls] then
            seen[e.cls] = true
            catList[#catList + 1] = e.cls
        end
    end
    table.sort(catList)
    if state.class and not seen[state.class] then state.class = nil end
    catBtn.text:SetText(Tr("Categoría: ") .. (state.class and ns.ClassName(state.class) or Tr("Todas")))
    catBtn:SetActive(state.class ~= nil)

    ageBtn.text:SetText(Tr("Visto: ") .. Tr(AGE_NAMES[state.age]))
    ageBtn:SetActive(state.age ~= 0)

    clearBtn:SetShown(ActiveCount() > 0)
end

function ns.Refresh()
    if not main:IsShown() or not ns.realm then return end
    alijo = ns.HasAlijo()
    if not alijo then state.own = false end

    -- Las tres columnas de la derecha cambian con la vista: sus cabeceras y el orden las siguen
    local k2, k3, k4 = ColumnKeys()
    cols[1], cols[2], cols[3] = COLS[k2], COLS[k3], COLS[k4]
    h2.key, h2.label = k2, COLS[k2].label
    h3.key, h3.label = k3, COLS[k3].label
    h4.key, h4.label = k4, COLS[k4].label
    if not sorter:Has(state.sort) then state.sort, state.asc = "p", false end
    sorter:Update()

    local all = ns.Index()
    UpdateControls(all)

    local buy, now = ns.BuyList(), time()
    local text = state.text
    local listData = {}
    local priced = {}
    local function add(e)
        local b = buy[e.id]
        e.want, e.max = b and b.n or 0, b and b.p or 0
        if Passes(e, b, now) then listData[#listData + 1] = e end
    end
    for _, e in ipairs(all) do
        priced[e.id] = true
        add(e)
    end
    -- Lo apuntado para comprar que nunca se ha visto en la subasta
    for id in pairs(state.buy and buy or {}) do
        if not priced[id] then
            local name, quality, icon = ns.ItemInfo(id)
            add({ id = id, name = name, lower = name:lower(), q = quality, icon = icon,
                  p = 0, t = 0, n = 0, have = ns.Have(id) or 0, value = 0 })
        end
    end
    -- Lo que no tiene dato (sin precio habitual, por ejemplo) va siempre al final, ordenes como ordenes
    local key, asc = state.sort, state.asc
    table.sort(listData, function(a, b)
        local x, y = a[key], b[key]
        if key == "name" then x, y = a.lower, b.lower end
        if x ~= y then
            if x == nil then return false end
            if y == nil then return true end
            if asc then return x < y end
            return x > y
        end
        if a.lower ~= b.lower then return a.lower < b.lower end
        return a.id < b.id
    end)

    if #listData ~= #all then
        countText:SetText(#listData .. Tr(" de ") .. Plural(#all, Tr("objeto"), Tr("objetos")))
    else
        countText:SetText(Plural(#all, Tr("objeto"), Tr("objetos")))
    end
    -- Por qué no hay nada que enseñar
    local active = ActiveCount()
    if state.buy and ns.BuyCount() == 0 then
        listEmpty:SetText(Tr("La lista de compra está vacía. Elige un objeto y ponle precio máximo y cantidad."))
    elseif #all == 0 then
        listEmpty:SetText(Tr("Aún no hay precios. Abre la casa de subastas y pulsa \"Escanear subasta\"."))
    elseif state.view ~= "all" and ns.Market().known == 0 then
        listEmpty:SetText((Tr("Hacen falta %d días de historial para comparar precios: escanea la subasta varios días."))
            :format(ns.MIN_BASE + 1))
    elseif active == 1 and state.own then
        listEmpty:SetText(Tr("Nada de lo que tienes guardado tiene precio en la lonja."))
    elseif active == 1 and text ~= "" then
        listEmpty:SetText(Tr("Ningún objeto coincide con la búsqueda."))
    else
        listEmpty:SetText(Tr("Ningún objeto cumple todos los filtros. Prueba a quitar alguno."))
    end

    list:SetData(listData)
    UpdateDetail()
    UpdateScanState()
end

function ns.OnDataChanged()
    UpdateBuyState()
    if main:IsShown() then N.Debounce("Lonja.refresh", 0.3, ns.Refresh) end
end

function main:OnOpen()
    ns.Invalidate()     -- lo que tienes puede haber cambiado desde la última vez
    ns.Refresh()
end
function main:OnClose()
    search:ClearFocus()
    minBox:ClearFocus()
    maxBox:ClearFocus()
end

function ns.Toggle()
    main:SetShown(not main:IsShown())
end

-- Abrir buscando un texto, sin otros filtros que lo escondan
function ns.OpenSearch(text)
    ClearFilters()
    main:Show()
    search:SetText(text or "")
    ns.Refresh()
end

-- Abrir con una vista puesta (ver VIEWS): "deal" para las gangas
function ns.OpenView(view)
    ClearFilters()
    state.view = view
    local sort = VIEW_SORT[view]
    if sort then state.sort, state.asc = sort[1], sort[2] end
    main:Show()
    ResetScroll()
    ns.Refresh()
end

-- Abrir con un objeto elegido
function ns.OpenItem(id)
    local name = ns.ItemInfo(id)
    if not ns.Price(id) and not ns.BuyGet(id) then
        print(P .. Tr("no hay ningún precio guardado de ") .. name .. ".")
        return
    end
    ClearFilters()
    state.sel = id
    main:Show()
    search:SetText(name)
    ns.Refresh()
end

---------------------------------------------------------------------------
-- Precio en el tooltip de los objetos
---------------------------------------------------------------------------
local function AddToTooltip(tip, id)
    if not ns.realm or not ns.TooltipEnabled() then return end
    local p, t = ns.Price(id)
    if not p then return end
    tip:AddDoubleLine(ACC_HEX .. "Lonja|r", Money(p, 12, true) .. " " .. GREY .. "(" .. Ago(t) .. ")|r", 1, 1, 1, 1, 1, 1)
    local s = ns.Stats(id)
    if s and s.usual then
        tip:AddDoubleLine(GREY .. Tr("Precio habitual") .. "|r", Money(s.usual, 12, true) .. "  " .. Pct(s.dev), 1, 1, 1, 1, 1, 1)
    end
    if s and s.lo and s.days > 1 then
        tip:AddDoubleLine(GREY .. (Tr("Mín. / máx. (%d d)")):format(s.days) .. "|r",
            Money(s.lo, 12) .. GREY .. " / |r" .. Money(s.hi, 12), 1, 1, 1, 1, 1, 1)
    end
    return true
end

---------------------------------------------------------------------------
-- Botón del minimapa (el de Nexo, compartido)
---------------------------------------------------------------------------
local function ShowSummaryTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    GameTooltip:AddLine("Lonja", ACC[1], ACC[2], ACC[3])
    if ns.realm then
        GameTooltip:AddDoubleLine(Tr("Objetos con precio"), N.Num(ns.Count()), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(Tr("Último escaneo"), Ago(ns.realm.lastScan), 0.8, 0.8, 0.8, 1, 1, 1)
        local market = ns.Market()
        if market.deal > 0 then
            GameTooltip:AddDoubleLine(Tr("Gangas"), GREEN .. market.deal .. "|r", 0.8, 0.8, 0.8, 1, 1, 1)
        end
        local total = ns.AccountValue()
        if total and total > 0 then
            GameTooltip:AddDoubleLine(Tr("Valor de lo guardado"), Money(total, 12), 0.8, 0.8, 0.8, 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(Tr("|cffffff00Clic|r para abrir · |cffffff00Arrastrar|r para mover"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

N.Register({
    id = "Lonja", name = Tr("Lonja"), icon = ICON, color = ACC, slash = "/lonja",
    toggle = function() ns.Toggle() end,
    tooltip = ShowSummaryTooltip,
    data = "LonjaDB",
})

-- Menú de complementos (AddonCompartment)
function Lonja_OnCompartmentClick() ns.Toggle() end
function Lonja_OnCompartmentEnter(_, button) ShowSummaryTooltip(button or UIParent, "ANCHOR_LEFT") end
function Lonja_OnCompartmentLeave() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Inicio
---------------------------------------------------------------------------
function ns.OnInit()
    main:RestorePos()
    N.OnItemTooltip(AddToTooltip)
end
