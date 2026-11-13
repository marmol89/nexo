-- Alijo: interfaz
local ADDON, ns = ...

local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)

local W, H = 780, 560
local PAD = 14
local LIST_W = 480
local ROW_H = 24
local ROWS = 16
local OWNER_ROWS = 9
local OWNER_H = 34

local N = Nexo
local BD, TEMPLATE = N.BD, N.TEMPLATE
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

local function QualityRGB(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function Ago(t)
    if not t then return nil end
    local d = time() - t
    if d < 90 then return "ahora mismo" end
    if d < 3600 then return "hace " .. math.floor(d / 60) .. " min" end
    if d < 86400 then return "hace " .. math.floor(d / 3600) .. " h" end
    return "hace " .. Plural(math.floor(d / 86400), "día", "días")
end

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
local ResetScroll
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
local search = CreateFrame("EditBox", "AlijoSearchBox", main, TEMPLATE)
search:SetSize(230, 22)
search:SetPoint("TOPLEFT", PAD, -62)
search:SetBackdrop(BD)
search:SetBackdropColor(0.07, 0.09, 0.08, 1)
search:SetBackdropBorderColor(0.20, 0.30, 0.25, 1)
search:SetAutoFocus(false)
search:SetFontObject(ChatFontNormal)
search:SetTextInsets(8, 8, 0, 0)
search:SetMaxLetters(40)
local placeholder = Text(search, 11)
placeholder:SetPoint("LEFT", 8, 0)
placeholder:SetTextColor(0.45, 0.5, 0.47)
placeholder:SetText("Buscar objeto...")
search:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
search:SetScript("OnEnterPressed", function(s) s:ClearFocus() end)
search:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 1) end)
search:SetScript("OnEditFocusLost", function(s) s:SetBackdropBorderColor(0.20, 0.30, 0.25, 1) end)
search:SetScript("OnTextChanged", function(s)
    local t = s:GetText() or ""
    placeholder:SetShown(t == "")
    state.text = t:lower():gsub("^%s+", ""):gsub("%s+$", "")
    ResetScroll()
    ns.Refresh()
end)

local LOCS = { { "all", "Todo" }, { "bags", "Bolsas" }, { "bank", "Banco" }, { "equip", "Equipado" } }
if ns.hasWarband then LOCS[#LOCS + 1] = { "warband", "Banda" } end
local locBtns = {}
for i, l in ipairs(LOCS) do
    local b = Button(main, 72, 22, l[2], function()
        state.loc = l[1]
        ResetScroll()
        ns.Refresh()
    end)
    b.key = l[1]
    if i == 1 then b:SetPoint("LEFT", search, "RIGHT", 10, 0) else b:SetPoint("LEFT", locBtns[i - 1], "RIGHT", 6, 0) end
    locBtns[i] = b
end

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

-- Cabeceras de columna (clic = ordenar)
local sortBtns = {}
local function SortHeader(key, label, x, width, justify)
    local b = CreateFrame("Button", nil, listPanel)
    b:SetSize(width, 18)
    b:SetPoint("TOPLEFT", x, -4)
    b.text = Text(b, 11, "GameFontNormal")
    b.text:SetPoint(justify, 0, 0)
    b.label = label
    b.key = key
    b:SetScript("OnClick", function()
        if state.sort == key then
            state.asc = not state.asc
        else
            state.sort = key
            state.asc = (key == "name")
        end
        ResetScroll()
        ns.Refresh()
    end)
    sortBtns[#sortBtns + 1] = b
    return b
end
SortHeader("name", "Objeto", 36, 200, "LEFT")
SortHeader("count", "Cantidad", 232, 74, "RIGHT")
local whereHeader = Text(listPanel, 11, "GameFontNormal")
whereHeader:SetPoint("TOPLEFT", 310, -7)
whereHeader:SetText("Dónde")
whereHeader:SetTextColor(ACC[1], ACC[2], ACC[3])

local scroll = CreateFrame("ScrollFrame", "AlijoListScroll", listPanel, "FauxScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 4, -30)
scroll:SetPoint("BOTTOMRIGHT", -26, 10)

function ResetScroll()
    local sb = scroll.ScrollBar or _G["AlijoListScrollScrollBar"]
    if sb then sb:SetValue(0) end
    FauxScrollFrame_SetOffset(scroll, 0)
end

local listData = {}
local rows = {}
local UpdateList, UpdateDetail

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
    r.name:SetWidth(208)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.count = Text(r, 12)
    r.count:SetPoint("LEFT", 240, 0)
    r.count:SetWidth(54)
    r.count:SetJustifyH("RIGHT")
    r.who = Text(r, 11)
    r.who:SetPoint("LEFT", 304, 0)
    r.who:SetPoint("RIGHT", -4, 0)
    r.who:SetJustifyH("LEFT")
    r.who:SetWordWrap(false)
    r:SetScript("OnEnter", function(self)
        self.hl:Show()
        if not self.data then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.data.id)
        GameTooltip:Show()
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
        state.sel = e.id
        UpdateList()
        UpdateDetail()
    end)
    rows[i] = r
end

local listEmpty = Text(listPanel, 12)
listEmpty:SetPoint("CENTER", -10, 0)
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
            r.count:SetText(e.total)
            r.who:SetText(OwnersText(e))
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
-- Detalle del objeto elegido
---------------------------------------------------------------------------
local detail = Panel(main)
detail:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 10, 0)
detail:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, TOP_Y)
detail:SetHeight(contentH)
SectionTitle(detail, "Quién lo tiene")

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
    dTotal:SetText("Total en la cuenta: |cffffffff" .. total .. "|r  ·  " .. Plural(#owners, "sitio", "sitios"))
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
footRight:SetText("/alijo ayuda")

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

    if state.filter then
        local c = ns.db.chars[state.filter]
        charBtn.text:SetText("|c" .. ClassHex(c.class) .. ShortName(state.filter) .. "|r  |cff888888nivel " .. (c.level or "?") .. "|r")
    else
        charBtn.text:SetText(ACC_HEX .. "Todos los personajes|r")
    end
    for _, b in ipairs(locBtns) do b:SetActive(b.key == state.loc) end
    for _, b in ipairs(sortBtns) do
        if state.sort == b.key then
            b.text:SetText(b.label .. (state.asc and " |cffffffff+|r" or " |cffffffff-|r"))
            b.text:SetTextColor(ACC[1], ACC[2], ACC[3])
        else
            b.text:SetText(b.label)
            b.text:SetTextColor(0.55, 0.7, 0.62)
        end
    end

    local all = ns.Index(state.filter, state.loc)
    listData = {}
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

    UpdateList()
    UpdateDetail()
    UpdateFooter()
end

local pending = false
function ns.OnDataChanged()
    if not main:IsShown() or pending then return end
    pending = true
    C_Timer.After(0.3, function() pending = false; ns.Refresh() end)
end

main:SetScript("OnShow", function()
    PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839)
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
    if not id or not ns.db or tip.alijoDone or not ns.TooltipEnabled() then return end
    local owners, total = ns.Owners(id)
    if total == 0 then return end
    tip.alijoDone = true
    for i = 1, math.min(6, #owners) do
        local o = owners[i]
        tip:AddDoubleLine("|c" .. ClassHex(o.class) .. o.name .. "|r", o.total .. " |cff9aa5a0(" .. LocText(o) .. ")|r", 1, 1, 1, 1, 1, 1)
    end
    if #owners > 1 then
        tip:AddDoubleLine(ACC_HEX .. "Alijo · total|r", total, 1, 1, 1, ACC[1], ACC[2], ACC[3])
    end
    tip:Show()
end

local function HookTooltips()
    local tips = { GameTooltip, ItemRefTooltip }
    for _, tip in ipairs(tips) do
        if tip then
            tip:HookScript("OnTooltipCleared", function(self) self.alijoDone = nil end)
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
    HookTooltips()
end
