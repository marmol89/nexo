local Tr = Nexo.T
-- Lonja: interfaz
local ADDON, ns = ...
if Nexo.Antiguo(ADDON) then return end

local W, H = 780, 560
local PAD = 14
local LIST_W = 480
local ROW_H = 24
local ROWS = 16
local LINE_H = 19
local LINES = 20
local BAR_W = W - PAD * 2 - LIST_W - 10 - 20

local N = Nexo
local ACC = { 0.94, 0.47, 0.42 }
local ACC_HEX = "|cfff0786a"
local GREY = "|cff9a9090"
local ICON = "Interface\\Icons\\INV_Hammer_15"

local BUY_H = 58            -- hueco del detalle para apuntar el objeto en la lista de compra
local GREEN = "|cff66ff66"

-- own = solo lo que tienes (según Alijo); buy = solo la lista de compra; sel = objeto elegido
local state = { text = "", own = false, buy = false, sort = "p", asc = false, sel = nil }

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

local function ClassHex(class) return N.ClassHex(class, "ffe8d0cc") end

local QualityRGB, ShowItemTooltip = N.QualityRGB, N.ItemTooltip

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
-- Búsqueda y filtro
---------------------------------------------------------------------------
local list
local function ResetScroll() list:Reset() end

local BOX_BG, BOX_BORDER, BOX_HINT = { 0.09, 0.07, 0.07 }, { 0.34, 0.20, 0.19 }, { 0.5, 0.44, 0.43 }

local search = K.Search(main, {
    name = "LonjaSearchBox", x = PAD, y = -62, hint = Tr("Buscar objeto..."),
    bg = BOX_BG, border = BOX_BORDER, hintColor = BOX_HINT,
    onChange = function(text)
        state.text = text
        ResetScroll()
        ns.Refresh()
    end,
})

local ownBtn = Button(main, 190, 22, "", function()
    state.own = not state.own
    ResetScroll()
    ns.Refresh()
end)
ownBtn:SetPoint("LEFT", search, "RIGHT", 10, 0)

local buyFilter = Button(main, 150, 22, "", function()
    state.buy = not state.buy
    ResetScroll()
    ns.Refresh()
end)

local countText = Text(main, 11)
countText:SetPoint("RIGHT", main, "TOPRIGHT", -PAD, -73)
countText:SetTextColor(0.6, 0.6, 0.6)

---------------------------------------------------------------------------
-- Lista de objetos
---------------------------------------------------------------------------
local TOP_Y = -94
local FOOT_H = 30
local contentH = H + TOP_Y - FOOT_H - 8

-- Columnas: borde derecho de cada una, medido desde la izquierda de la fila
local COL_PRICE, COL_3, COL_4 = 312, 362, 444

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

list = K.List(main, {
    name = "LonjaListScroll", x = PAD, y = TOP_Y, w = LIST_W, h = contentH,
    rows = ROWS, rowH = ROW_H, nameW = 186, emptyW = 360,
    build = function(r)
        r.price = RightText(r, COL_PRICE, 92)
        r.c3 = RightText(r, COL_3, 48)
        r.c3:SetTextColor(0.78, 0.72, 0.70)
        r.c4 = RightText(r, COL_4, 80)
    end,
    fill = function(r, e)
        r.name:SetTextColor(QualityRGB(e.q))
        r.price:SetText(e.p > 0 and Money(e.p, 11) or GREY .. "-|r")
        if state.buy then
            -- En verde lo que ahora mismo está a su precio
            r.c3:SetText((e.p > 0 and e.p <= e.max and GREEN or "") .. e.want)
            r.c4:SetText(Money(e.max, 11))
        elseif alijo then
            r.c3:SetText(e.have > 0 and e.have or GREY .. "-|r")
            r.c4:SetText(e.value > 0 and Money(e.value, 11) or GREY .. "-|r")
        else
            r.c3:SetText(e.n)
            r.c4:SetText(GREY .. Ago(e.t) .. "|r")
        end
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
sorter:Add("name", "Objeto", 36, 150)
sorter:Add("p", "Precio", 6 + COL_PRICE - 90, 90, "RIGHT")
local h3 = sorter:Add(nil, "", 6 + COL_3 - 48, 48, "RIGHT")   -- su clave y su texto dependen de si está Alijo
local h4 = sorter:Add(nil, "", 6 + COL_4 - 80, 80, "RIGHT")


---------------------------------------------------------------------------
-- Panel derecho: resumen o detalle del objeto elegido
---------------------------------------------------------------------------
local detail = Panel(main)
detail:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 10, 0)
detail:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, TOP_Y)
detail:SetHeight(contentH)
local dTitle = SectionTitle(detail, "Resumen")

local dIcon, dName = K.DetailHead(detail)
local dSub = Text(detail, 11)
dSub:SetPoint("BOTTOMLEFT", dIcon, "BOTTOMRIGHT", 8, 0)
dSub:SetTextColor(0.72, 0.64, 0.62)

-- Líneas genéricas: { l = texto izquierdo, r = texto derecho, bar = 0..1, color = {r, g, b} }
local linesOpt = { n = LINES, lineH = LINE_H, barW = BAR_W, height = contentH, grey = GREY }
local detailLines = K.Lines(detail, linesOpt)
-- reserve = alto que se deja libre al pie del panel
local function RenderLines(lines, top, reserve)
    linesOpt.height = contentH - (reserve or 0)
    detailLines:Render(lines, top)
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

local function Input(name, w, hint)
    local box = K.Search(buyBox, {
        name = name, x = 0, y = 0, w = w, hint = hint,
        bg = BOX_BG, border = BOX_BORDER, hintColor = BOX_HINT, onChange = function() end,
    })
    box:ClearAllPoints()
    return box
end
local buyPrice = Input("LonjaBuyPrice", 78, Tr("Oro: 1.5"))
buyPrice:SetPoint("BOTTOMLEFT", 0, 0)
local buyQty = Input("LonjaBuyQty", 50, "Cant.")
buyQty:SetPoint("LEFT", buyPrice, "RIGHT", 4, 0)

local filledFor     -- objeto con el que se rellenaron los cuadros: no se pisan mientras escribes

local buySave = Button(buyBox, 64, 22, "Apuntar", function()
    local price, qty = ns.ParseMoney(buyPrice:GetText()), tonumber(buyQty:GetText())
    if not price or not qty or qty < 1 then
        print(ACC_HEX .. Tr("Lonja:|r pon el precio máximo por unidad (en oro: 1.5, o 1g 50s) y cuántas unidades quieres."))
        return
    end
    buyPrice:ClearFocus()
    buyQty:ClearFocus()
    filledFor = nil
    ns.BuySet(state.sel, price, math.floor(qty))
end, 11)
buySave:SetPoint("LEFT", buyQty, "RIGHT", 4, 0)

local buyDrop = Button(buyBox, 46, 22, "Quitar", function()
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
    buySave.text:SetText(b and "Guardar" or "Apuntar")
    buyDrop:SetShown(b ~= nil)
    if filledFor ~= id then
        filledFor = id
        buyPrice:SetText(b and ns.MoneyPlain(b.p) or "")
        buyQty:SetText(b and b.n or "")
    end
end

-- Resumen: cuántos precios hay, cuándo se escaneó y lo que vale lo guardado en la cuenta
local function OverviewLines()
    local count = ns.Count()
    local lines = {
        Title(Tr("Precios guardados")),
        { l = Tr("Objetos con precio"), r = "|cffffffff" .. N.Num(count) .. "|r" },
        { l = Tr("Último escaneo completo"), r = Ago(ns.realm.lastScan) },
    }
    lines[#lines + 1] = { l = Tr("Escanear al abrir la subasta"), r = ns.AutoScan() and GREEN .. Tr("sí|r") or GREY .. "no|r" }
    local wanted = ns.BuyCount()
    if wanted > 0 then
        lines[#lines + 1] = {}
        lines[#lines + 1] = Title(Tr("Lista de compra"))
        lines[#lines + 1] = { l = Tr("Objetos apuntados"), r = "|cffffffff" .. wanted .. "|r" }
        lines[#lines + 1] = { l = Tr("A tu precio ahora"), r = GREEN .. #ns.Deals() .. "|r" }
    end
    if count == 0 then
        lines[#lines + 1] = {}
        lines[#lines + 1] = { l = GREY .. Tr("Abre la casa de subastas y pulsa|r") }
        lines[#lines + 1] = { l = GREY .. Tr("\"Escanear subasta\" para empezar.|r") }
        return lines
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

-- Detalle de un objeto: precio, lo que tienes y el historial por días
local function ItemLines(id)
    local p, t, n = ns.Price(id)
    local lines = {
        Title("Precio"),
        { l = Tr("Mínimo por unidad"), r = p and Money(p, 11, true) or GREY .. Tr("sin ver|r") },
        { l = Tr("Unidades a la venta"), r = "|cffffffff" .. N.Num(n or 0) .. "|r" },
    }
    local have = ns.Have(id)
    if have then
        lines[#lines + 1] = { l = Tr("Tienes en la cuenta"), r = "|cffffffff" .. N.Num(have) .. "|r" }
        if have > 0 and p then lines[#lines + 1] = { l = Tr("Valor de lo tuyo"), r = Money(have * p, 11) } end
    end
    local b = ns.BuyGet(id)
    if b then
        lines[#lines + 1] = {}
        lines[#lines + 1] = Title(Tr("Lista de compra"))
        lines[#lines + 1] = { l = Tr("Comprar hasta"), r = Money(b.p, 11, true) }
        lines[#lines + 1] = { l = Tr("Quedan por comprar"), r = "|cffffffff" .. N.Num(b.n) .. "|r" }
        if p and p <= b.p then lines[#lines + 1] = { l = GREEN .. Tr("Ahora está a tu precio|r") } end
    end

    local history = ns.History(id)
    if #history > 0 then
        lines[#lines + 1] = {}
        lines[#lines + 1] = Title("Historial")
        local top = 0
        for _, h in ipairs(history) do top = math.max(top, h.p) end
        for _, h in ipairs(history) do
            lines[#lines + 1] = { l = N.DayLabel(N.DayKeyToTime(h.day)), r = Money(h.p, 11), bar = h.p / top }
        end
    end
    return lines
end

function UpdateDetail()
    local has = state.sel ~= nil and (ns.Price(state.sel) ~= nil or ns.BuyGet(state.sel) ~= nil)
    dIcon:SetShown(has)
    dName:SetShown(has)
    dSub:SetShown(has)
    UpdateBuyBox(has and state.sel or nil)
    if not has then
        dTitle:SetText("Resumen")
        RenderLines(OverviewLines(), 32)
        return
    end
    local name, quality, icon = ns.ItemInfo(state.sel)
    local _, t = ns.Price(state.sel)
    dTitle:SetText("Objeto")
    dIcon:SetTexture(icon)
    dName:SetText(name)
    dName:SetTextColor(QualityRGB(quality))
    dSub:SetText(Tr("visto ") .. Ago(t))
    RenderLines(ItemLines(state.sel), 84, BUY_H)
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
function ns.Refresh()
    if not main:IsShown() or not ns.realm then return end
    alijo = ns.HasAlijo()
    if not alijo then state.own = false end

    -- Sin Alijo, las dos últimas columnas pasan a ser las unidades a la venta y la antigüedad
    -- y con la lista de compra, las unidades que quieres y tu precio máximo
    if state.buy then
        h3.label, h3.key, h4.label, h4.key = "Quiero", "want", Tr("Máximo"), "max"
    else
        h3.label, h3.key = alijo and "Tengo" or "Venta", alijo and "have" or "n"
        h4.label, h4.key = alijo and "Valor" or "Visto", alijo and "value" or "t"
    end
    if not sorter:Has(state.sort) then state.sort, state.asc = "p", false end
    sorter:Update()

    ownBtn:SetShown(alijo)
    ownBtn.text:SetText(state.own and Tr("Solo lo que tengo") or Tr("Todos los objetos"))
    ownBtn:SetActive(state.own)

    local buy = ns.BuyList()
    buyFilter:ClearAllPoints()
    buyFilter:SetPoint("LEFT", alijo and ownBtn or search, "RIGHT", 10, 0)
    buyFilter.text:SetText(Tr("Lista de compra (") .. ns.BuyCount() .. ")")
    buyFilter:SetActive(state.buy)

    local all = ns.Index()
    local listData = {}
    local text = state.text
    local priced = {}
    local function add(e)
        local b = buy[e.id]
        e.want, e.max = b and b.n or 0, b and b.p or 0
        if (not state.own or e.have > 0) and (not state.buy or b) and (text == "" or e.lower:find(text, 1, true)) then
            listData[#listData + 1] = e
        end
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
    local key, asc = state.sort, state.asc
    table.sort(listData, function(a, b)
        local x, y = a[key], b[key]
        if key == "name" then x, y = a.lower, b.lower end
        if x ~= y then
            if asc then return x < y end
            return x > y
        end
        if a.lower ~= b.lower then return a.lower < b.lower end
        return a.id < b.id
    end)

    if #listData ~= #all then
        countText:SetText(#listData .. " de " .. Plural(#all, "objeto", "objetos"))
    else
        countText:SetText(Plural(#all, "objeto", "objetos"))
    end
    if state.buy and text == "" then
        listEmpty:SetText(Tr("La lista de compra está vacía. Elige un objeto y ponle precio máximo y cantidad."))
    elseif #all == 0 then
        listEmpty:SetText(Tr("Aún no hay precios. Abre la casa de subastas y pulsa \"Escanear subasta\"."))
    elseif state.own and text == "" then
        listEmpty:SetText(Tr("Nada de lo que tienes guardado tiene precio en la lonja."))
    else
        listEmpty:SetText(Tr("Ningún objeto coincide con la búsqueda."))
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
function main:OnClose() search:ClearFocus() end

function ns.Toggle()
    main:SetShown(not main:IsShown())
end

function ns.OpenSearch(text)
    state.own = false
    main:Show()
    search:SetText(text or "")
    ns.Refresh()
end

---------------------------------------------------------------------------
-- Precio en el tooltip de los objetos
---------------------------------------------------------------------------
local function AddToTooltip(tip, id)
    if not ns.realm or not ns.TooltipEnabled() then return end
    local p, t = ns.Price(id)
    if not p then return end
    tip:AddDoubleLine(ACC_HEX .. "Lonja|r", Money(p, 12, true) .. " |cff9a9090(" .. Ago(t) .. ")|r", 1, 1, 1, 1, 1, 1)
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
