-- Lonja: interfaz
local ADDON, ns = ...

local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)

local W, H = 780, 560
local PAD = 14
local LIST_W = 480
local ROW_H = 24
local ROWS = 16
local LINE_H = 19
local LINES = 20
local BAR_W = W - PAD * 2 - LIST_W - 10 - 20

local N = Nexo
local BD, TEMPLATE = N.BD, N.TEMPLATE
local ACC = { 0.94, 0.47, 0.42 }
local ACC_HEX = "|cfff0786a"
local GREY = "|cff9a9090"
local ICON = "Interface\\Icons\\INV_Hammer_15"

-- own = solo lo que tienes (según Alijo); sel = objeto elegido
local state = { text = "", own = false, sort = "p", asc = false, sel = nil }

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

local function QualityRGB(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

---------------------------------------------------------------------------
-- Ventana principal
---------------------------------------------------------------------------
local main, close = K.Window({
    name = "LonjaMainFrame", w = W, h = H, icon = ICON,
    title = "Lonja", subtitle = "Precios de la casa de subastas · WoW Forever",
    settings = function() return ns.db and ns.db.settings end,
})

local function ScanClick()
    if ns.Scanning() then ns.StopScan() else ns.StartScan() end
end

local scanBtn = Button(main, 170, 24, "Escanear subasta", ScanClick)
scanBtn:SetPoint("RIGHT", close, "LEFT", -10, 0)
scanBtn:HookScript("OnEnter", function(s)
    GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Escanear la casa de subastas")
    GameTooltip:AddLine("Guarda el precio de compra más bajo de cada objeto.", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Tiene que estar abierta la ventana de la subasta.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
scanBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------
-- Búsqueda y filtro
---------------------------------------------------------------------------
local ResetScroll

local search = CreateFrame("EditBox", "LonjaSearchBox", main, TEMPLATE)
search:SetSize(230, 22)
search:SetPoint("TOPLEFT", PAD, -62)
search:SetBackdrop(BD)
search:SetBackdropColor(0.09, 0.07, 0.07, 1)
search:SetBackdropBorderColor(0.34, 0.20, 0.19, 1)
search:SetAutoFocus(false)
search:SetFontObject(ChatFontNormal)
search:SetTextInsets(8, 8, 0, 0)
search:SetMaxLetters(40)
local placeholder = Text(search, 11)
placeholder:SetPoint("LEFT", 8, 0)
placeholder:SetTextColor(0.5, 0.44, 0.43)
placeholder:SetText("Buscar objeto...")
search:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
search:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
search:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 1) end)
search:SetScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(0.34, 0.20, 0.19, 1) end)
search:SetScript("OnTextChanged", function(s)
    local t = s:GetText() or ""
    placeholder:SetShown(t == "")
    state.text = t:lower():gsub("^%s+", ""):gsub("%s+$", "")
    ResetScroll()
    ns.Refresh()
end)

local ownBtn = Button(main, 190, 22, "", function()
    state.own = not state.own
    ResetScroll()
    ns.Refresh()
end)
ownBtn:SetPoint("LEFT", search, "RIGHT", 10, 0)

local countText = Text(main, 11)
countText:SetPoint("RIGHT", main, "TOPRIGHT", -PAD, -73)
countText:SetTextColor(0.6, 0.6, 0.6)

---------------------------------------------------------------------------
-- Lista de objetos
---------------------------------------------------------------------------
local TOP_Y = -94
local FOOT_H = 30
local contentH = H + TOP_Y - FOOT_H - 8

local listPanel = Panel(main)
listPanel:SetPoint("TOPLEFT", PAD, TOP_Y)
listPanel:SetSize(LIST_W, contentH)
local listLine = Tex(listPanel, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.25)
listLine:SetHeight(1)
listLine:SetPoint("TOPLEFT", 8, -24)
listLine:SetPoint("TOPRIGHT", -8, -24)

-- Columnas: borde derecho de cada una, medido desde la izquierda de la fila
local COL_PRICE, COL_3, COL_4 = 312, 362, 444

local sortBtns = {}
local function SortHeader(label, x, width, right)
    local b = CreateFrame("Button", nil, listPanel)
    b:SetSize(width, 18)
    b:SetPoint("TOPLEFT", x, -4)
    b.text = Text(b, 11, "GameFontNormal")
    b.text:SetPoint(right and "RIGHT" or "LEFT", 0, 0)
    b.label = label
    b:SetScript("OnClick", function(self)
        if state.sort == self.key then
            state.asc = not state.asc
        else
            state.sort = self.key
            state.asc = self.key == "name"     -- los números, de mayor a menor
        end
        ResetScroll()
        ns.Refresh()
    end)
    sortBtns[#sortBtns + 1] = b
    return b
end
local hName = SortHeader("Objeto", 36, 150)
local hPrice = SortHeader("Precio", 6 + COL_PRICE - 90, 90, true)
local h3 = SortHeader("", 6 + COL_3 - 48, 48, true)
local h4 = SortHeader("", 6 + COL_4 - 80, 80, true)
hName.key, hPrice.key = "name", "p"

local scroll = CreateFrame("ScrollFrame", "LonjaListScroll", listPanel, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 4, -30)
scroll:SetPoint("BOTTOMRIGHT", -26, 10)

function ResetScroll()
    local sb = scroll.ScrollBar or _G["LonjaListScrollScrollBar"]
    if sb then sb:SetValue(0) end
    FauxScrollFrame_SetOffset(scroll, 0)
end

local listData = {}
local rows = {}
local alijo = false
local UpdateList, UpdateDetail

local function ShowItemTooltip(owner, id)
    if not id then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. id)
    GameTooltip:Show()
end

local function RightText(r, edge, width, size)
    local fs = Text(r, size or 11)
    fs:SetPoint("RIGHT", r, "LEFT", edge, 0)
    fs:SetWidth(width)
    fs:SetJustifyH("RIGHT")
    fs:SetWordWrap(false)
    return fs
end

for i = 1, ROWS do
    local r = CreateFrame("Button", nil, listPanel)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 6, -30 - (i - 1) * ROW_H)
    r:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
    r.bg = Tex(r, "BACKGROUND", 1, 1, 1, (i % 2 == 0) and 0.03 or 0)
    r.bg:SetAllPoints()
    r.hl = Tex(r, "BACKGROUND", ACC[1], ACC[2], ACC[3], 0.08, 1)
    r.hl:SetAllPoints()
    r.hl:Hide()
    r.sel = Tex(r, "BACKGROUND", ACC[1], ACC[2], ACC[3], 0.16, 2)
    r.sel:SetAllPoints()
    r.sel:Hide()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT", 4, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = Text(r, 12)
    r.name:SetPoint("LEFT", 30, 0)
    r.name:SetWidth(186)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.price = RightText(r, COL_PRICE, 92)
    r.c3 = RightText(r, COL_3, 48)
    r.c3:SetTextColor(0.78, 0.72, 0.70)
    r.c4 = RightText(r, COL_4, 80)
    r:SetScript("OnEnter", function(self)
        self.hl:Show()
        if self.data then ShowItemTooltip(self, self.data.id) end
    end)
    r:SetScript("OnLeave", function(self) self.hl:Hide() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        local e = self.data
        if not e then return end
        if IsShiftKeyDown() and GetItemInfo then
            local _, link = GetItemInfo(e.id)
            if link then
                if ChatEdit_InsertLink then
                    ChatEdit_InsertLink(link)
                elseif ChatFrameUtil and ChatFrameUtil.InsertLink then
                    ChatFrameUtil.InsertLink(link)
                end
            end
            return
        end
        state.sel = (state.sel ~= e.id) and e.id or nil     -- segundo clic: volver al resumen
        UpdateList()
        UpdateDetail()
    end)
    rows[i] = r
end

local listEmpty = Text(listPanel, 12)
listEmpty:SetPoint("CENTER", -10, 0)
listEmpty:SetWidth(360)
listEmpty:SetTextColor(0.5, 0.5, 0.5)

function UpdateList()
    local offset = FauxScrollFrame_GetOffset(scroll)
    FauxScrollFrame_Update(scroll, #listData, ROWS, ROW_H)
    for i = 1, ROWS do
        local r = rows[i]
        local e = listData[offset + i]
        r.data = e
        if e then
            r.icon:SetTexture(e.icon)
            r.name:SetText(e.name)
            r.name:SetTextColor(QualityRGB(e.q))
            r.price:SetText(Money(e.p, 11))
            if alijo then
                r.c3:SetText(e.have > 0 and e.have or GREY .. "-|r")
                r.c4:SetText(e.value > 0 and Money(e.value, 11) or GREY .. "-|r")
            else
                r.c3:SetText(e.n)
                r.c4:SetText(GREY .. Ago(e.t) .. "|r")
            end
            r.sel:SetShown(state.sel == e.id)
            r:Show()
        else
            r:Hide()
        end
    end
    listEmpty:SetShown(#listData == 0)
end
scroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, UpdateList)
end)

---------------------------------------------------------------------------
-- Panel derecho: resumen o detalle del objeto elegido
---------------------------------------------------------------------------
local detail = Panel(main)
detail:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 10, 0)
detail:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, TOP_Y)
detail:SetHeight(contentH)
local dTitle = SectionTitle(detail, "Resumen")

local dIcon = detail:CreateTexture(nil, "ARTWORK")
dIcon:SetSize(36, 36)
dIcon:SetPoint("TOPLEFT", 10, -34)
dIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local dName = Text(detail, 13)
dName:SetPoint("TOPLEFT", dIcon, "TOPRIGHT", 8, 0)
dName:SetPoint("RIGHT", -10, 0)
dName:SetJustifyH("LEFT")
dName:SetJustifyV("TOP")
if dName.SetMaxLines then dName:SetMaxLines(2) end
local dSub = Text(detail, 11)
dSub:SetPoint("BOTTOMLEFT", dIcon, "BOTTOMRIGHT", 8, 0)
dSub:SetTextColor(0.72, 0.64, 0.62)

-- Líneas genéricas: { l = texto izquierdo, r = texto derecho, bar = 0..1, color = {r, g, b} }
local lineRows = {}
for i = 1, LINES do
    local r = CreateFrame("Frame", nil, detail)
    r:SetHeight(LINE_H)
    r.r = Text(r, 11)
    r.r:SetPoint("RIGHT", 0, 1)
    r.r:SetJustifyH("RIGHT")
    r.l = Text(r, 11)
    r.l:SetPoint("LEFT", 0, 1)
    r.l:SetPoint("RIGHT", r.r, "LEFT", -6, 0)
    r.l:SetJustifyH("LEFT")
    r.l:SetWordWrap(false)
    r.barBg = Tex(r, "BACKGROUND", 1, 1, 1, 0.06)
    r.barBg:SetHeight(2)
    r.barBg:SetPoint("BOTTOMLEFT", 0, 0)
    r.barBg:SetPoint("BOTTOMRIGHT", 0, 0)
    r.bar = Tex(r, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.9)
    r.bar:SetHeight(2)
    r.bar:SetPoint("BOTTOMLEFT", 0, 0)
    lineRows[i] = r
end

local function RenderLines(lines, top)
    local maxLines = math.min(LINES, math.floor((contentH - top - 8) / LINE_H))
    if #lines > maxLines then
        lines[maxLines] = { l = GREY .. "y " .. (#lines - maxLines + 1) .. " líneas más|r" }
        for i = #lines, maxLines + 1, -1 do lines[i] = nil end
    end
    for i, r in ipairs(lineRows) do
        local d = lines[i]
        if d then
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", detail, "TOPLEFT", 10, -(top + (i - 1) * LINE_H))
            r:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
            r.l:SetText(d.l or "")
            r.r:SetText(d.r or "")
            local hasBar = d.bar ~= nil
            r.barBg:SetShown(hasBar)
            r.bar:SetShown(hasBar)
            if hasBar then
                local c = d.color or ACC
                r.bar:SetColorTexture(c[1], c[2], c[3], 0.9)
                r.bar:SetWidth(math.max(1, math.min(1, d.bar) * BAR_W))
            end
            r:Show()
        else
            r:Hide()
        end
    end
end

local function Title(text) return { l = ACC_HEX .. text .. "|r" } end

-- Resumen: cuántos precios hay, cuándo se escaneó y lo que vale lo guardado en la cuenta
local function OverviewLines()
    local count = ns.Count()
    local lines = {
        Title("Precios guardados"),
        { l = "Objetos con precio", r = "|cffffffff" .. N.Num(count) .. "|r" },
        { l = "Último escaneo completo", r = Ago(ns.realm.lastScan) },
    }
    if count == 0 then
        lines[#lines + 1] = {}
        lines[#lines + 1] = { l = GREY .. "Abre la casa de subastas y pulsa|r" }
        lines[#lines + 1] = { l = GREY .. "\"Escanear subasta\" para empezar.|r" }
        return lines
    end

    lines[#lines + 1] = {}
    lines[#lines + 1] = Title("Valor de lo guardado")
    local total, chars = ns.AccountValue()
    if not total then
        lines[#lines + 1] = { l = GREY .. "Con Alijo activado verás lo que vale|r" }
        lines[#lines + 1] = { l = GREY .. "lo que tienes en bolsas y bancos.|r" }
        return lines
    end
    lines[#lines + 1] = { l = "Toda la cuenta", r = Money(total, 11) }
    for _, c in ipairs(chars) do
        lines[#lines + 1] = {
            l = "|c" .. ClassHex(c.class) .. c.name .. "|r", r = Money(c.value, 11),
            bar = c.value / chars[1].value,
        }
    end
    if #chars == 0 then
        lines[#lines + 1] = { l = GREY .. "Nada de lo que tienes tiene precio.|r" }
    end
    return lines
end

-- Detalle de un objeto: precio, lo que tienes y el historial por días
local function ItemLines(id)
    local p, t, n = ns.Price(id)
    local lines = {
        Title("Precio"),
        { l = "Mínimo por unidad", r = Money(p, 11, true) },
        { l = "Unidades a la venta", r = "|cffffffff" .. N.Num(n or 0) .. "|r" },
    }
    local have = ns.Have(id)
    if have then
        lines[#lines + 1] = { l = "Tienes en la cuenta", r = "|cffffffff" .. N.Num(have) .. "|r" }
        if have > 0 then lines[#lines + 1] = { l = "Valor de lo tuyo", r = Money(have * p, 11) } end
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
    local has = state.sel and ns.Price(state.sel) ~= nil
    dIcon:SetShown(has)
    dName:SetShown(has)
    dSub:SetShown(has)
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
    dSub:SetText("visto " .. Ago(t))
    RenderLines(ItemLines(state.sel), 84)
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
footRight:SetText("/lonja ayuda")

-- Botón que se añade a la ventana de la subasta
local ahBtn

local function UpdateScanState()
    local status = ns.ScanStatus()
    local label = status and "Parar escaneo" or "Escanear subasta"
    scanBtn.text:SetText(label)
    scanBtn:SetActive(status ~= nil)
    if ahBtn then
        ahBtn.text:SetText(status and "Lonja: parar" or "Lonja: escanear")
        ahBtn:SetActive(status ~= nil)
    end
    if not main:IsShown() or not ns.realm then return end
    if status then
        footer:SetText(ACC_HEX .. status .. "|r")
    elseif ns.IsOpen() then
        footer:SetText(ns.realmKey .. "  ·  |cff66ff66subasta abierta|r: las búsquedas que hagas también se apuntan")
    else
        footer:SetText(ns.realmKey .. "  ·  último escaneo " .. Ago(ns.realm.lastScan) .. "  ·  Mayús+clic: enlazar en el chat")
    end
end
ns.OnScanProgress = UpdateScanState

function ns.OnAuctionShow()
    -- La ventana de la subasta se carga con el propio evento: espera a que exista
    C_Timer.After(0, function()
        local parent = AuctionFrame or AuctionHouseFrame
        if ahBtn or not parent then return end
        ahBtn = Button(parent, 120, 22, "Lonja: escanear", ScanClick, 11)
        ahBtn:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", -6, 2)
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
    h3.label, h3.key = alijo and "Tengo" or "Venta", alijo and "have" or "n"
    h4.label, h4.key = alijo and "Valor" or "Visto", alijo and "value" or "t"
    local known = false
    for _, b in ipairs(sortBtns) do known = known or b.key == state.sort end
    if not known then state.sort, state.asc = "p", false end
    for _, b in ipairs(sortBtns) do
        if state.sort == b.key then
            b.text:SetText(b.label .. (state.asc and " |cffffffff+|r" or " |cffffffff-|r"))
            b.text:SetTextColor(ACC[1], ACC[2], ACC[3])
        else
            b.text:SetText(b.label)
            b.text:SetTextColor(0.76, 0.56, 0.53)
        end
    end

    ownBtn:SetShown(alijo)
    ownBtn.text:SetText(state.own and "Solo lo que tengo" or "Todos los objetos")
    ownBtn:SetActive(state.own)

    local all = ns.Index()
    listData = {}
    local text = state.text
    for _, e in ipairs(all) do
        if (not state.own or e.have > 0) and (text == "" or e.lower:find(text, 1, true)) then
            listData[#listData + 1] = e
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
    if #all == 0 then
        listEmpty:SetText("Aún no hay precios. Abre la casa de subastas y pulsa \"Escanear subasta\".")
    elseif state.own and text == "" then
        listEmpty:SetText("Nada de lo que tienes guardado tiene precio en la lonja.")
    else
        listEmpty:SetText("Ningún objeto coincide con la búsqueda.")
    end

    UpdateList()
    UpdateDetail()
    UpdateScanState()
end

local pending = false
function ns.OnDataChanged()
    if not main:IsShown() or pending then return end
    pending = true
    C_Timer.After(0.3, function() pending = false; ns.Refresh() end)
end

main:SetScript("OnShow", function()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839)
    ns.Invalidate()     -- lo que tienes puede haber cambiado desde la última vez
    ns.Refresh()
end)
main:SetScript("OnHide", function()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840)
    search:ClearFocus()
end)

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
    if not id or not ns.realm or tip.lonjaDone or not ns.TooltipEnabled() then return end
    local p, t = ns.Price(id)
    if not p then return end
    tip.lonjaDone = true
    tip:AddDoubleLine(ACC_HEX .. "Lonja|r", Money(p, 12, true) .. " |cff9a9090(" .. Ago(t) .. ")|r", 1, 1, 1, 1, 1, 1)
    tip:Show()
end

local function HookTooltips()
    local tips = { GameTooltip, ItemRefTooltip }
    for _, tip in ipairs(tips) do
        if tip then
            tip:HookScript("OnTooltipCleared", function(self) self.lonjaDone = nil end)
        end
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data)
            if tip == GameTooltip or tip == ItemRefTooltip then
                AddToTooltip(tip, data and data.id)
            end
        end)
    else
        for _, tip in ipairs(tips) do
            if tip and tip:HasScript("OnTooltipSetItem") then
                tip:HookScript("OnTooltipSetItem", function(self)
                    local _, link = self:GetItem()
                    AddToTooltip(self, link and tonumber(link:match("item:(%d+)")))
                end)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Botón del minimapa (el de Nexo, compartido)
---------------------------------------------------------------------------
local function ShowSummaryTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    GameTooltip:AddLine("Lonja", ACC[1], ACC[2], ACC[3])
    if ns.realm then
        GameTooltip:AddDoubleLine("Objetos con precio", N.Num(ns.Count()), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine("Último escaneo", Ago(ns.realm.lastScan), 0.8, 0.8, 0.8, 1, 1, 1)
        local total = ns.AccountValue()
        if total and total > 0 then
            GameTooltip:AddDoubleLine("Valor de lo guardado", Money(total, 12), 0.8, 0.8, 0.8, 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffff00Clic|r para abrir · |cffffff00Arrastrar|r para mover", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

N.Register({
    id = "Lonja", name = "Lonja", icon = ICON, color = ACC, slash = "/lonja",
    toggle = function() ns.Toggle() end,
    tooltip = ShowSummaryTooltip,
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
    HookTooltips()
end
