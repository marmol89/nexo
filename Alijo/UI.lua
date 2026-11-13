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

local BD = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local ACC = { 0.36, 0.86, 0.62 }
local ACC_HEX = "|cff5cdb9e"
local DASH = "|cff666666—|r"

-- filter = clave de personaje o nil (todos); loc = sitio; text = búsqueda; sel = objeto elegido
local state = { filter = nil, loc = "all", text = "", sort = "name", asc = true, sel = nil }

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
local function Panel(parent, bg, border)
    local f = CreateFrame("Frame", nil, parent, TEMPLATE)
    f:SetBackdrop(BD)
    bg = bg or { 0.08, 0.10, 0.09, 0.92 }
    border = border or { 0.16, 0.25, 0.21, 1 }
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
    if not c then return "ffcfe8dc" end
    return ("ff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
end

local function ClassRGB(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return ACC[1], ACC[2], ACC[3] end
    return c.r, c.g, c.b
end

local function QualityRGB(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function ShortName(key) return (key:match("^(.-) %- ") or key) end

local function Plural(n, one, many) return n .. " " .. (n == 1 and one or many) end

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
            self:SetBackdropColor(0.08, 0.28, 0.19, 1)
            self:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 1)
            self.text:SetTextColor(0.78, 1, 0.9)
        else
            self:SetBackdropColor(0.11, 0.13, 0.12, 1)
            self:SetBackdropBorderColor(0.20, 0.30, 0.25, 1)
            self.text:SetTextColor(0.85, 0.85, 0.85)
        end
    end
    b:SetActive(false)
    b:SetScript("OnEnter", function(s) if not s.active then s:SetBackdropBorderColor(0.28, 0.66, 0.48, 1) end end)
    b:SetScript("OnLeave", function(s) if not s.active then s:SetBackdropBorderColor(0.20, 0.30, 0.25, 1) end end)
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
local main = CreateFrame("Frame", "AlijoMainFrame", UIParent, TEMPLATE)
main:SetSize(W, H)
main:SetPoint("CENTER")
main:SetFrameStrata("HIGH")
main:SetToplevel(true)
main:SetBackdrop(BD)
main:SetBackdropColor(0.04, 0.05, 0.04, 0.96)
main:SetBackdropBorderColor(0.20, 0.55, 0.40, 1)
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
tinsert(UISpecialFrames, "AlijoMainFrame")

-- Cabecera
local header = Tex(main, "BACKGROUND", 0.05, 0.14, 0.10, 1, 1)
header:SetPoint("TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", -1, -1)
header:SetHeight(50)
local headerLine = Tex(main, "ARTWORK", ACC[1], ACC[2], ACC[3], 0.6)
headerLine:SetHeight(1)
headerLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
headerLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")

local logo = main:CreateTexture(nil, "ARTWORK")
logo:SetTexture("Interface\\Icons\\INV_Box_01")
logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
logo:SetSize(34, 34)
logo:SetPoint("TOPLEFT", 12, -9)

local title = Text(main, 20, "GameFontNormalLarge")
title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -1)
title:SetText("Alijo")
title:SetTextColor(ACC[1], ACC[2], ACC[3])

local subtitle = Text(main, 11)
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
subtitle:SetTextColor(0.5, 0.7, 0.6)
subtitle:SetText("Inventario de la cuenta · WoW Forever")

-- Botón cerrar
local close = CreateFrame("Button", nil, main, TEMPLATE)
close:SetSize(24, 24)
close:SetPoint("TOPRIGHT", -12, -13)
close:SetBackdrop(BD)
close:SetBackdropColor(0.06, 0.12, 0.09, 1)
close:SetBackdropBorderColor(0.18, 0.42, 0.31, 1)
local closeX1 = Tex(close, "ARTWORK", 0.78, 0.95, 0.87, 1)
closeX1:SetSize(14, 2)
closeX1:SetPoint("CENTER")
closeX1:SetRotation(math.rad(45))
local closeX2 = Tex(close, "ARTWORK", 0.78, 0.95, 0.87, 1)
closeX2:SetSize(14, 2)
closeX2:SetPoint("CENTER")
closeX2:SetRotation(math.rad(-45))
close:SetScript("OnEnter", function(s)
    s:SetBackdropColor(0.55, 0.12, 0.10, 1)
    s:SetBackdropBorderColor(1, 0.4, 0.3, 1)
end)
close:SetScript("OnLeave", function(s)
    s:SetBackdropColor(0.06, 0.12, 0.09, 1)
    s:SetBackdropBorderColor(0.18, 0.42, 0.31, 1)
end)
close:SetScript("OnClick", function() main:Hide() end)

-- Selector de personaje
local ResetScroll
local charBtn
charBtn = Button(main, 210, 24, "", function(_, mouse)
    local list = ns.CharList()
    local idx = 0
    for i, k in ipairs(list) do if k == state.filter then idx = i end end
    if mouse == "RightButton" then idx = idx - 1 else idx = idx + 1 end
    if idx > #list then idx = 0 elseif idx < 0 then idx = #list end
    state.filter = list[idx]
    ResetScroll()
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
local mb = CreateFrame("Button", "AlijoMinimapButton", Minimap)
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
mbIcon:SetTexture("Interface\\Icons\\INV_Box_01")
mbIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
mbIcon:SetPoint("TOPLEFT", 7, -6)
local mbBorder = mb:CreateTexture(nil, "OVERLAY")
mbBorder:SetSize(53, 53)
mbBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mbBorder:SetPoint("TOPLEFT")

local function PlaceMinimap()
    local a = math.rad(ns.db.settings.minimap.angle or 260)
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

mb:SetScript("OnClick", function() ns.Toggle() end)
mb:SetScript("OnEnter", function(self) ShowSummaryTooltip(self) end)
mb:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Menú de complementos (AddonCompartment)
function Alijo_OnCompartmentClick() ns.Toggle() end
function Alijo_OnCompartmentEnter(_, button) ShowSummaryTooltip(button or UIParent, "ANCHOR_LEFT") end
function Alijo_OnCompartmentLeave() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Inicio
---------------------------------------------------------------------------
function ns.OnInit()
    local pos = ns.db.settings.pos
    if pos then
        main:ClearAllPoints()
        main:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
    HookTooltips()
    ns.UpdateMinimapButton()
    Minimap:HookScript("OnSizeChanged", PlaceMinimap)
    C_Timer.After(1, PlaceMinimap)
end
