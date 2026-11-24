local Tr = Nexo.T
Nexo.Dict({
    ["Minerales, hierbas y demás nodos de recolección, con dónde encontrarlos"] = "Ores, herbs and other gathering nodes, with where to find them",
    ["Buscar mineral, hierba..."] = "Search ore, herb...",
    ["Ver en el mapa"] = "Show on map",
    ["Objeto"] = "Item",
    ["Veces"] = "Times",
    ["Zonas"] = "Zones",
    ["Dónde encontrarlo"] = "Where to find it",
    ["Elige un objeto de la lista para ver dónde lo has encontrado."] = "Pick an item from the list to see where you have found it.",
    ["Recolectado "] = "Gathered ",
    [" veces, en "] = " times, in ",
    ["zona"] = "zone", ["zonas"] = "zones",
    ["Objetos distintos"] = "Distinct items",
    ["Puntos en el mapa"] = "Points on the map",
})
-- Cosecha: interfaz (lista con búsqueda, detalle de dónde se ha visto cada objeto, y los
-- puntos sobre el mapa del mundo)
local ADDON, ns = ...

local W, H = 780, 560
local PAD = 14
local LIST_W = 480
local ROW_H = 24
local ROWS = 16

local N = Nexo
local ACC = { 0.70, 0.80, 0.34 }
local ICON = "Interface\\Icons\\Trade_Herbalism"

-- text = búsqueda; sort/asc = orden de la lista; sel = objeto elegido (filtra también el mapa)
local state = { text = "", sort = "name", asc = true, sel = nil }

---------------------------------------------------------------------------
-- Piezas con el tema de Cosecha
---------------------------------------------------------------------------
local K = N.Kit({
    acc = ACC,
    panelBg = { 0.09, 0.10, 0.06, 0.92 }, panelBorder = { 0.23, 0.25, 0.14, 1 },
    btnOn = { 0.24, 0.29, 0.10 }, btnOnText = { 0.92, 1, 0.80 },
    btnOff = { 0.12, 0.13, 0.09 }, btnBorder = { 0.26, 0.28, 0.18 }, btnHover = { 0.56, 0.66, 0.30 },
    winBg = { 0.05, 0.05, 0.03 }, winBorder = { 0.33, 0.40, 0.18 },
    headBg = { 0.09, 0.11, 0.05 }, sub = { 0.62, 0.66, 0.50 },
    closeBg = { 0.08, 0.09, 0.06 }, closeBorder = { 0.26, 0.28, 0.18 }, closeX = { 0.85, 0.90, 0.75 },
})
local Panel, Text, Tex, Button, SectionTitle = K.Panel, K.Text, K.Tex, K.Button, K.SectionTitle
local Plural = N.Plural
local QualityRGB, Ago = N.QualityRGB, N.Ago

---------------------------------------------------------------------------
-- Ventana principal
---------------------------------------------------------------------------
local main, close = K.Window({
    name = "CosechaMainFrame", w = W, h = H, icon = ICON,
    title = Tr("Cosecha"), subtitle = Tr("Minerales, hierbas y demás nodos de recolección, con dónde encontrarlos"),
    settings = function() return ns.db and ns.db.settings end,
})

local list
local function ResetScroll() list:Reset() end

local search = K.Search(main, {
    name = "CosechaSearchBox", x = PAD, y = -62, w = 230, hint = Tr("Buscar mineral, hierba..."),
    bg = { 0.07, 0.08, 0.05 }, border = { 0.23, 0.25, 0.14 }, hintColor = { 0.45, 0.47, 0.37 },
    onChange = function(text)
        state.text = text
        ResetScroll()
        ns.Refresh()
    end,
})

local mapBtn = Button(main, 128, 22, Tr("Ver en el mapa"), function()
    ns.db.settings.map = not ns.db.settings.map
    mapBtn:SetActive(ns.db.settings.map)
    ns.RefreshMapPins()
end)
mapBtn:SetPoint("LEFT", search, "RIGHT", 10, 0)

---------------------------------------------------------------------------
-- Lista de objetos recolectados
---------------------------------------------------------------------------
local TOP_Y = -94
local FOOT_H = 30
local contentH = H + TOP_Y - FOOT_H - 8

list = K.List(main, {
    name = "CosechaListScroll", x = PAD, y = TOP_Y, w = LIST_W, h = contentH,
    rows = ROWS, rowH = ROW_H, nameW = 260, emptyW = LIST_W - 40,
    build = function(r)
        r.count = Text(r, 11)
        r.count:SetPoint("LEFT", 300, 0)
        r.count:SetWidth(70)
        r.count:SetJustifyH("RIGHT")
        r.zones = Text(r, 11)
        r.zones:SetPoint("LEFT", 380, 0)
        r.zones:SetWidth(70)
        r.zones:SetJustifyH("RIGHT")
    end,
    fill = function(r, e)
        r.name:SetTextColor(QualityRGB(e.q))
        r.count:SetText(e.total)
        r.zones:SetText(e.zones)
    end,
    item = function(e) return e.id end,
    selected = function(e) return state.sel == e.id end,
    click = function(e)
        state.sel = (state.sel == e.id) and nil or e.id
        ns.Refresh()
        ns.RefreshMapPins()
    end,
})
local listPanel, listEmpty = list.panel, list.empty

local sorter = K.Sorter(listPanel, state, function()
    ResetScroll()
    ns.Refresh()
end, { 0.58, 0.62, 0.45 })
sorter:Add("name", Tr("Objeto"), 36, 260, "LEFT")
sorter:Add("count", Tr("Veces"), 300, 70, "RIGHT")
sorter:Add("zones", Tr("Zonas"), 380, 70, "RIGHT")

---------------------------------------------------------------------------
-- Detalle: dónde se ha visto el objeto elegido
---------------------------------------------------------------------------
local detail = Panel(main)
detail:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 10, 0)
detail:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, TOP_Y)
detail:SetHeight(contentH)
SectionTitle(detail, Tr("Dónde encontrarlo"))

local dIcon, dName = K.DetailHead(detail)
local dTotal = Text(detail, 11)
dTotal:SetPoint("TOPLEFT", dIcon, "BOTTOMLEFT", 0, -8)
dTotal:SetTextColor(0.68, 0.70, 0.58)

local LINE_H, LINES = 19, 20
local BAR_W = W - PAD * 2 - LIST_W - 10 - 20
local linesOpt = { n = LINES, lineH = LINE_H, barW = BAR_W, height = contentH, grey = "|cff888888" }
local detailLines = K.Lines(detail, linesOpt)

local dEmpty = Text(detail, 12)
dEmpty:SetPoint("CENTER", 0, 0)
dEmpty:SetWidth(200)
dEmpty:SetTextColor(0.5, 0.5, 0.5)
dEmpty:SetText(Tr("Elige un objeto de la lista para ver dónde lo has encontrado."))

local function UpdateDetail()
    local it = state.sel and ns.db.items[state.sel]
    dEmpty:SetShown(not it)
    dIcon:SetShown(it ~= nil)
    dName:SetShown(it ~= nil)
    dTotal:SetShown(it ~= nil)
    if not it then
        detailLines:Render({}, 66)
        return
    end
    dIcon:SetTexture(it.i)
    dName:SetText(it.n or ("#" .. state.sel))
    dName:SetTextColor(QualityRGB(it.q))

    local zones = ns.Zones(state.sel)
    local total = 0
    for _, z in ipairs(zones) do total = total + z.points end
    dTotal:SetText(Tr("Recolectado ") .. total .. Tr(" veces, en ") .. Plural(#zones, Tr("zona"), Tr("zonas")))

    local lines, max = {}, (zones[1] and zones[1].points) or 1
    for _, z in ipairs(zones) do
        lines[#lines + 1] = { l = ns.MapName(z.mapID), r = z.points .. "  |cff888888" .. (Ago(z.last) or "") .. "|r", bar = z.points / max }
    end
    detailLines:Render(lines, 66)
end

---------------------------------------------------------------------------
-- Pie y refrescar todo
---------------------------------------------------------------------------
local footer = K.Footer(main, { h = FOOT_H, pad = PAD, right = "/cosecha " .. Nexo.Cmd("cosecha", "help") })

function ns.Refresh()
    if not main:IsShown() or not ns.db then return end
    mapBtn:SetActive(ns.db.settings.map)
    sorter:Update()

    local all = ns.List()
    local listData, text = {}, state.text
    for _, e in ipairs(all) do
        if text == "" or e.lower:find(text, 1, true) then listData[#listData + 1] = e end
    end
    local asc = state.asc
    table.sort(listData, function(a, b)
        if state.sort == "count" or state.sort == "zones" then
            local av, bv = a[state.sort], b[state.sort]
            if av ~= bv then
                if asc then return av < bv end
                return av > bv
            end
            return a.lower < b.lower
        end
        if a.lower ~= b.lower then
            if asc then return a.lower < b.lower end
            return a.lower > b.lower
        end
        return a.id < b.id
    end)

    listEmpty:SetText(#all == 0 and Tr("Nada todavía") or Tr("Ningún objeto coincide con la búsqueda."))
    list:SetData(listData)
    UpdateDetail()
end

function main:OnOpen() ns.Refresh() end
function main:OnClose() search:ClearFocus() end

function ns.Toggle() main:SetShown(not main:IsShown()) end

function ns.OpenSearch(text)
    main:Show()
    search:SetText(text or "")
    ns.Refresh()
end

function ns.OnDataChanged()
    if main:IsShown() then N.Debounce("Cosecha.refresh", 0.3, ns.Refresh) end
    ns.RefreshMapPins()
end

---------------------------------------------------------------------------
-- Puntos sobre el mapa del mundo
---------------------------------------------------------------------------
-- Nombre de un mapa (zona, continente...), o "?" si ahora no se puede saber
function ns.MapName(mapID)
    if C_Map and C_Map.GetMapInfo then
        local ok, info = pcall(C_Map.GetMapInfo, mapID)
        if ok and info and type(info.name) == "string" and not Nexo.Secret(info.name) then return info.name end
    end
    return "?"
end

local pins, pinCount = {}, 0
local function GetPin(i)
    local p = pins[i]
    if p then return p end
    local canvas = WorldMapFrame:GetCanvas()
    p = CreateFrame("Frame", nil, canvas)
    p:SetSize(15, 15)
    p:SetFrameLevel(canvas:GetFrameLevel() + 10)
    p.icon = p:CreateTexture(nil, "OVERLAY")
    p.icon:SetAllPoints()
    p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p:EnableMouse(true)
    p:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.itemName or "", 1, 1, 1)
        if self.last then GameTooltip:AddLine(Tr("visto ") .. Ago(self.last), 0.8, 0.8, 0.8) end
        GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pins[i] = p
    return p
end

-- Pinta (o quita) los puntos guardados del mapa que se está viendo ahora mismo
function ns.RefreshMapPins()
    if not (WorldMapFrame and WorldMapFrame:IsShown() and ns.db) then return end
    local canvas = WorldMapFrame:GetCanvas()
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    local n = 0
    if ns.db.settings.map and w and w > 0 then
        local mapID = WorldMapFrame:GetMapID()
        local map = mapID and ns.db.maps[mapID]
        if map then
            for id, e in pairs(map) do
                if not state.sel or state.sel == id then
                    local it = ns.db.items[id]
                    for _, p in pairs(e.points) do
                        n = n + 1
                        local pin = GetPin(n)
                        pin:ClearAllPoints()
                        pin:SetPoint("CENTER", canvas, "TOPLEFT", p.x * w, -p.y * h)
                        pin.icon:SetTexture((it and it.i) or "Interface\\Icons\\INV_Misc_QuestionMark")
                        pin.itemName = (it and it.n) or ("#" .. id)
                        pin.last = p.t
                        pin:Show()
                    end
                end
            end
        end
    end
    for i = n + 1, pinCount do pins[i]:Hide() end
    pinCount = n
end

local mapHooked = false
local function HookWorldMap()
    if mapHooked or not (WorldMapFrame and WorldMapFrame.GetCanvas) then return end
    mapHooked = true
    WorldMapFrame:HookScript("OnShow", ns.RefreshMapPins)
    hooksecurefunc(WorldMapFrame, "SetMapID", ns.RefreshMapPins)
    WorldMapFrame:GetCanvas():HookScript("OnSizeChanged", ns.RefreshMapPins)
end

---------------------------------------------------------------------------
-- Botón del minimapa
---------------------------------------------------------------------------
local function ShowSummaryTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    GameTooltip:AddLine("Cosecha", ACC[1], ACC[2], ACC[3])
    GameTooltip:AddDoubleLine(Tr("Objetos distintos"), #ns.List(), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine(Tr("Puntos en el mapa"), ns.db.settings.map and Tr("activados") or Tr("desactivados"), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(Tr("|cffffff00Clic|r para abrir · |cffffff00Arrastrar|r para mover"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

N.Register({
    id = "Cosecha", name = Tr("Cosecha"), icon = ICON, color = ACC, slash = "/cosecha",
    toggle = function() ns.Toggle() end,
    tooltip = ShowSummaryTooltip,
    data = "CosechaDB",
})

function Cosecha_OnCompartmentClick() ns.Toggle() end
function Cosecha_OnCompartmentEnter(_, button) ShowSummaryTooltip(button or UIParent, "ANCHOR_LEFT") end
function Cosecha_OnCompartmentLeave() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Inicio
---------------------------------------------------------------------------
function ns.OnInit()
    main:RestorePos()
    HookWorldMap()
end
