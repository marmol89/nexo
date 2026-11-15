-- Alijo: interfaz
local ADDON, ns = ...
if Nexo.Antiguo(ADDON) then return end

local W, H = 780, 560
local PAD = 14
local LIST_W = 480
local ROW_H = 24
local ROWS = 16
local OWNER_ROWS = 9
local OWNER_H = 34

local N = Nexo
local ACC = { 0.36, 0.86, 0.62 }
local ACC_HEX = "|cff5cdb9e"
local DASH = "|cff666666—|r"

-- filter = clave de personaje o nil (todos); loc = sitio; text = búsqueda; sel = objeto elegido
local state = { filter = nil, loc = "all", text = "", sort = "name", asc = true, sel = nil }

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
local K = N.Kit({
    acc = ACC,
    panelBg = { 0.08, 0.10, 0.09, 0.92 }, panelBorder = { 0.16, 0.25, 0.21, 1 },
    btnOn = { 0.08, 0.28, 0.19 }, btnOnText = { 0.78, 1, 0.9 },
    btnOff = { 0.11, 0.13, 0.12 }, btnBorder = { 0.20, 0.30, 0.25 }, btnHover = { 0.28, 0.66, 0.48 },
    winBg = { 0.04, 0.05, 0.04 }, winBorder = { 0.20, 0.55, 0.40 },
    headBg = { 0.05, 0.14, 0.10 }, sub = { 0.5, 0.7, 0.6 },
    closeBg = { 0.06, 0.12, 0.09 }, closeBorder = { 0.18, 0.42, 0.31 }, closeX = { 0.78, 0.95, 0.87 },
})
local Panel, Text, Tex, Button, SectionTitle = K.Panel, K.Text, K.Tex, K.Button, K.SectionTitle
local ShortName, Plural = N.ShortName, N.Plural

local function ClassHex(class) return N.ClassHex(class, "ffcfe8dc") end

local function ClassRGB(class) return N.ClassRGB(class, ACC[1], ACC[2], ACC[3]) end

local QualityRGB, Ago = N.QualityRGB, N.Ago

-- "Bolsas 10 · Banco 2 · Equipado 1"
local function LocText(o)
    local parts = {}
    if o.bags > 0 then parts[#parts + 1] = "Bolsas " .. o.bags end
    if o.bank > 0 then parts[#parts + 1] = (o.key == ns.WARBAND_KEY and "Banda " or "Banco ") .. o.bank end
    if o.equip > 0 then parts[#parts + 1] = "Equipado " .. o.equip end
    return table.concat(parts, " · ")
end

---------------------------------------------------------------------------
-- Ventana principal
---------------------------------------------------------------------------
local main, close = K.Window({
    name = "AlijoMainFrame", w = W, h = H, icon = "Interface\\Icons\\INV_Box_01",
    title = "Alijo", subtitle = "Inventario de la cuenta · WoW Forever",
    settings = function() return ns.db and ns.db.settings end,
})

-- Selector de personaje
local list
local function ResetScroll() list:Reset() end
local charBtn = K.CharButton(main, close, {
    list = function() return ns.CharList() end,
    get = function() return state.filter end,
    set = function(key)
        state.filter = key
        ResetScroll()
        ns.Refresh()
    end,
    all = true,
})

---------------------------------------------------------------------------
-- Barra de búsqueda y pestañas de sitio
---------------------------------------------------------------------------
local search = K.Search(main, {
    name = "AlijoSearchBox", x = PAD, y = -62, hint = "Buscar objeto...",
    bg = { 0.07, 0.09, 0.08 }, border = { 0.20, 0.30, 0.25 }, hintColor = { 0.45, 0.5, 0.47 },
    onChange = function(text)
        state.text = text
        ResetScroll()
        ns.Refresh()
    end,
})

local LOCS = { { "all", "Todo" }, { "bags", "Bolsas" }, { "bank", "Banco" }, { "equip", "Equipado" } }
if ns.hasWarband then LOCS[#LOCS + 1] = { "warband", "Banda" } end
local locBtns = K.Tabs(main, LOCS, 72, function(loc)
    state.loc = loc
    ResetScroll()
    ns.Refresh()
end)
locBtns[1]:SetPoint("LEFT", search, "RIGHT", 10, 0)

local countText = Text(main, 11)
countText:SetPoint("RIGHT", main, "TOPRIGHT", -PAD, -73)
countText:SetTextColor(0.6, 0.6, 0.6)

---------------------------------------------------------------------------
-- Lista de objetos
---------------------------------------------------------------------------
local TOP_Y = -94
local FOOT_H = 30
local contentH = H + TOP_Y - FOOT_H - 8

local UpdateDetail

local function OwnersText(e)
    local first = e.owners[1]
    if not first then return "" end
    if state.filter then return "|cff9aa5a0" .. LocText(first) .. "|r" end
    if #e.owners == 1 then
        return "|c" .. ClassHex(first.class) .. first.name .. "|r"
    end
    local parts = {}
    for i = 1, math.min(3, #e.owners) do
        local o = e.owners[i]
        parts[#parts + 1] = "|c" .. ClassHex(o.class) .. o.name .. "|r |cff9aa5a0" .. o.total .. "|r"
    end
    if #e.owners > 3 then parts[#parts + 1] = "|cff9aa5a0...|r" end
    return table.concat(parts, ", ")
end

list = K.List(main, {
    name = "AlijoListScroll", x = PAD, y = TOP_Y, w = LIST_W, h = contentH,
    rows = ROWS, rowH = ROW_H, nameW = 208,
    build = function(r)
        r.count = Text(r, 12)
        r.count:SetPoint("LEFT", 240, 0)
        r.count:SetWidth(54)
        r.count:SetJustifyH("RIGHT")
        r.who = Text(r, 11)
        r.who:SetPoint("LEFT", 304, 0)
        r.who:SetPoint("RIGHT", -4, 0)
        r.who:SetJustifyH("LEFT")
        r.who:SetWordWrap(false)
    end,
    fill = function(r, e)
        r.name:SetTextColor(QualityRGB(e.q))
        r.count:SetText(e.total)
        r.who:SetText(OwnersText(e))
    end,
    item = function(e) return e.id end,
    selected = function(e) return state.sel == e.id end,
    click = function(e)
        state.sel = e.id
        UpdateDetail()
    end,
})
local listPanel, listEmpty = list.panel, list.empty

-- Cabeceras de columna (clic = ordenar)
local sorter = K.Sorter(listPanel, state, function()
    ResetScroll()
    ns.Refresh()
end, { 0.55, 0.7, 0.62 })
sorter:Add("name", "Objeto", 36, 200, "LEFT")
sorter:Add("count", "Cantidad", 232, 74, "RIGHT")
local whereHeader = Text(listPanel, 11, "GameFontNormal")
whereHeader:SetPoint("TOPLEFT", 310, -7)
whereHeader:SetText("Dónde")
whereHeader:SetTextColor(ACC[1], ACC[2], ACC[3])


---------------------------------------------------------------------------
-- Detalle del objeto elegido
---------------------------------------------------------------------------
local detail = Panel(main)
detail:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 10, 0)
detail:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, TOP_Y)
detail:SetHeight(contentH)
SectionTitle(detail, "Quién lo tiene")

local dIcon, dName = K.DetailHead(detail)
local dTotal = Text(detail, 11)
dTotal:SetPoint("TOPLEFT", dIcon, "BOTTOMLEFT", 0, -8)
dTotal:SetTextColor(0.75, 0.75, 0.75)

local ownerRows = {}
for i = 1, OWNER_ROWS do
    local r = CreateFrame("Frame", nil, detail)
    r:SetHeight(OWNER_H - 4)
    r:SetPoint("TOPLEFT", 10, -100 - (i - 1) * OWNER_H)
    r:SetPoint("RIGHT", -10, 0)
    r.name = Text(r, 12)
    r.name:SetPoint("TOPLEFT", 0, 0)
    r.total = Text(r, 12)
    r.total:SetPoint("TOPRIGHT", 0, 0)
    r.sub = Text(r, 10)
    r.sub:SetPoint("TOPLEFT", 0, -14)
    r.sub:SetTextColor(0.6, 0.65, 0.62)
    r.barBg = Tex(r, "BACKGROUND", 1, 1, 1, 0.06)
    r.barBg:SetHeight(3)
    r.barBg:SetPoint("BOTTOMLEFT", 0, 0)
    r.barBg:SetPoint("BOTTOMRIGHT", 0, 0)
    r.bar = Tex(r, "ARTWORK", 1, 1, 1, 0.9)
    r.bar:SetHeight(3)
    r.bar:SetPoint("BOTTOMLEFT", 0, 0)
    ownerRows[i] = r
end

local dMore = Text(detail, 10)
dMore:SetPoint("BOTTOMLEFT", 10, 24)
dMore:SetTextColor(0.55, 0.55, 0.55)

local dEmpty = Text(detail, 12)
dEmpty:SetPoint("CENTER", 0, 0)
dEmpty:SetWidth(210)
dEmpty:SetTextColor(0.5, 0.5, 0.5)
dEmpty:SetText("Elige un objeto de la lista para ver quién lo tiene y dónde.")

local dHint = Text(detail, 10)
dHint:SetPoint("BOTTOMLEFT", 10, 8)
dHint:SetTextColor(0.45, 0.45, 0.45)
dHint:SetText("Mayús+clic en la lista: enlazar en el chat")

function UpdateDetail()
    local owners, total
    if state.sel then owners, total = ns.Owners(state.sel) end
    local has = owners and #owners > 0
    dEmpty:SetShown(not has)
    dIcon:SetShown(has)
    dName:SetShown(has)
    dTotal:SetShown(has)
    dMore:SetText("")
    if not has then
        for _, r in ipairs(ownerRows) do r:Hide() end
        return
    end
    local name, quality, icon = ns.ItemInfo(state.sel)
    dIcon:SetTexture(icon)
    dName:SetText(name)
    dName:SetTextColor(QualityRGB(quality))
    -- Con Lonja, lo que vale en la subasta (lo equipado no cuenta: no se puede vender)
    local price = Lonja and Lonja.Price and Lonja.Price(state.sel)
    local sellable = 0
    for _, o in ipairs(owners) do sellable = sellable + o.bags + o.bank end
    if price and sellable > 0 then
        dTotal:SetText("Total en la cuenta: |cffffffff" .. total .. "|r  ·  vale " .. Lonja.Money(price * sellable, 11))
    else
        dTotal:SetText("Total en la cuenta: |cffffffff" .. total .. "|r  ·  " .. Plural(#owners, "sitio", "sitios"))
    end
    local barW = detail:GetWidth() - 20
    for i, r in ipairs(ownerRows) do
        local o = owners[i]
        if o then
            local cr, cg, cb = ClassRGB(o.class)
            r.name:SetText(o.name)
            r.name:SetTextColor(cr, cg, cb)
            r.total:SetText(o.total)
            r.sub:SetText(LocText(o))
            r.bar:SetColorTexture(cr, cg, cb, 0.9)
            r.bar:SetWidth(math.max(1, o.total / owners[1].total * barW))
            r:Show()
        else
            r:Hide()
        end
    end
    if #owners > OWNER_ROWS then dMore:SetText("y " .. (#owners - OWNER_ROWS) .. " más") end
end

---------------------------------------------------------------------------
-- Pie
---------------------------------------------------------------------------
local footer = K.Footer(main, { h = FOOT_H, pad = PAD, right = "/alijo ayuda" })

local function UpdateFooter()
    local key = state.filter or ns.charKey
    local c = ns.db.chars[key]
    if not c then footer:SetText("") return end
    local parts = { "|c" .. ClassHex(c.class) .. (c.name or ShortName(key)) .. "|r" }
    parts[#parts + 1] = "bolsas vistas " .. (Ago(c.tBags) or "nunca")
    if c.tBank then
        parts[#parts + 1] = "banco visto " .. Ago(c.tBank)
    else
        parts[#parts + 1] = "|cffffb347banco sin registrar: ábrelo con este personaje|r"
    end
    footer:SetText(table.concat(parts, "  ·  "))
end

---------------------------------------------------------------------------
-- Refrescar todo
---------------------------------------------------------------------------
function ns.Refresh()
    if not main:IsShown() or not ns.db then return end
    if state.filter and not ns.db.chars[state.filter] then state.filter = nil end

    charBtn:SetChar(state.filter, ns.db.chars[state.filter], "ffcfe8dc")
    locBtns:Select(state.loc)
    sorter:Update()

    local all = ns.Index(state.filter, state.loc)
    local listData = {}
    local text = state.text
    for _, e in ipairs(all) do
        if text == "" or e.lower:find(text, 1, true) then listData[#listData + 1] = e end
    end
    local asc = state.asc
    if state.sort == "count" then
        table.sort(listData, function(a, b)
            if a.total ~= b.total then
                if asc then return a.total < b.total end
                return a.total > b.total
            end
            return a.lower < b.lower
        end)
    else
        table.sort(listData, function(a, b)
            if a.lower ~= b.lower then
                if asc then return a.lower < b.lower end
                return a.lower > b.lower
            end
            return a.id < b.id
        end)
    end

    if text ~= "" then
        countText:SetText(#listData .. " de " .. Plural(#all, "objeto", "objetos"))
    else
        countText:SetText(Plural(#all, "objeto distinto", "objetos distintos"))
    end
    if #all == 0 then
        listEmpty:SetText("Aquí no hay nada registrado todavía.")
    else
        listEmpty:SetText("Ningún objeto coincide con la búsqueda.")
    end

    list:SetData(listData)
    UpdateDetail()
    UpdateFooter()
end

function ns.OnDataChanged()
    if main:IsShown() then N.Debounce("Alijo.refresh", 0.3, ns.Refresh) end
end

function main:OnOpen() ns.Refresh() end
function main:OnClose() search:ClearFocus() end

function ns.Toggle()
    main:SetShown(not main:IsShown())
end

function ns.OpenSearch(text)
    state.filter = nil
    state.loc = "all"
    main:Show()
    search:SetText(text or "")
    ns.Refresh()
end

---------------------------------------------------------------------------
-- Recuento en el tooltip de los objetos
---------------------------------------------------------------------------
local function AddToTooltip(tip, id)
    if not ns.db or not ns.TooltipEnabled() then return end
    local owners, total = ns.Owners(id)
    if total == 0 then return end
    for i = 1, math.min(6, #owners) do
        local o = owners[i]
        tip:AddDoubleLine("|c" .. ClassHex(o.class) .. o.name .. "|r", o.total .. " |cff9aa5a0(" .. LocText(o) .. ")|r", 1, 1, 1, 1, 1, 1)
    end
    if #owners > 1 then
        tip:AddDoubleLine(ACC_HEX .. "Alijo · total|r", total, 1, 1, 1, ACC[1], ACC[2], ACC[3])
    end
    return true
end

---------------------------------------------------------------------------
-- Botón del minimapa
---------------------------------------------------------------------------

local function ShowSummaryTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    GameTooltip:AddLine("Alijo", ACC[1], ACC[2], ACC[3])
    local chars = ns.CharList()
    GameTooltip:AddDoubleLine("Personajes registrados", #chars, 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Objetos distintos", #ns.Index(nil, "all"), 0.8, 0.8, 0.8, 1, 1, 1)
    local c = ns.char
    if c then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Banco de " .. (c.name or "este personaje"), c.tBank and ("visto " .. Ago(c.tBank)) or "sin registrar", 0.8, 0.8, 0.8, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffff00Clic|r para abrir · |cffffff00Arrastrar|r para mover", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

-- El botón del minimapa es el de Nexo, compartido por todos los addons
N.Register({
    id = "Alijo", name = "Alijo", icon = "Interface\\Icons\\INV_Box_01", color = ACC, slash = "/alijo",
    toggle = function() ns.Toggle() end,
    tooltip = ShowSummaryTooltip,
    data = "AlijoDB",
})

-- Menú de complementos (AddonCompartment)
function Alijo_OnCompartmentClick() ns.Toggle() end
function Alijo_OnCompartmentEnter(_, button) ShowSummaryTooltip(button or UIParent, "ANCHOR_LEFT") end
function Alijo_OnCompartmentLeave() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Inicio
---------------------------------------------------------------------------
function ns.OnInit()
    state.filter = ns.charKey   -- por defecto, el personaje con el que estás jugando
    main:RestorePos()
    N.OnItemTooltip(AddToTooltip)
end
