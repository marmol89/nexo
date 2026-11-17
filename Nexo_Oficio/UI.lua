local Tr = Nexo.T
-- Oficio: interfaz
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
local ACC = { 0.88, 0.66, 0.30 }
local ACC_HEX = "|cffe0a84c"
local GREY = "|cff9a958c"
local ICON = "Interface\\Icons\\Trade_BlackSmithing"

-- Dificultad de una receta: 4 naranja, 3 amarillo, 2 verde, 1 gris
local DIFF = {
    [4] = "|cffff8040naranja|r", [3] = "|cffffff00amarillo|r",
    [2] = "|cff40bf40verde|r", [1] = "|cff808080gris|r",
}
-- Profesiones sin ventana de recetas: no hay nada que registrar en ellas
local NO_RECIPES = {
    ["herboristería"] = true, ["desuello"] = true, ["pesca"] = true,
    ["herbalism"] = true, ["skinning"] = true, ["fishing"] = true,
}

-- filter = clave de personaje o nil (todos); prof = profesión o nil (todas);
-- selProf / selName = receta elegida
local state = { filter = nil, prof = nil, text = "", sort = "name", asc = true, selProf = nil, selName = nil }

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
local K = N.Kit({
    acc = ACC,
    panelBg = { 0.10, 0.09, 0.07, 0.92 }, panelBorder = { 0.27, 0.21, 0.13, 1 },
    btnOn = { 0.30, 0.21, 0.07 }, btnOnText = { 1, 0.92, 0.75 },
    btnOff = { 0.13, 0.12, 0.10 }, btnBorder = { 0.32, 0.26, 0.17 }, btnHover = { 0.70, 0.52, 0.24 },
    winBg = { 0.05, 0.045, 0.035 }, winBorder = { 0.58, 0.43, 0.19 },
    headBg = { 0.15, 0.11, 0.05 }, sub = { 0.72, 0.62, 0.45 },
    closeBg = { 0.13, 0.10, 0.06 }, closeBorder = { 0.45, 0.34, 0.16 }, closeX = { 0.96, 0.88, 0.74 },
})
local Panel, Text, Tex, Button, SectionTitle = K.Panel, K.Text, K.Tex, K.Button, K.SectionTitle
local ShortName, Plural = N.ShortName, N.Plural

local function ClassHex(class) return N.ClassHex(class, "ffe8dcc8") end

local function ProfNames()
    local set, list = {}, {}
    for key, c in pairs(ns.db.chars) do
        if not state.filter or state.filter == key then
            for name in pairs(c.profs or {}) do
                if not set[name] then
                    set[name] = true
                    list[#list + 1] = name
                end
            end
        end
    end
    table.sort(list)
    return list
end

---------------------------------------------------------------------------
-- Ventana principal
---------------------------------------------------------------------------
local main, close = K.Window({
    name = "OficioMainFrame", w = W, h = H, icon = ICON,
    title = Tr("Oficio"), subtitle = Tr("Profesiones de la cuenta · WoW Forever"),
    settings = function() return ns.db and ns.db.settings end,
})

local list
local function ResetScroll() list:Reset() end
local charBtn = K.CharPicker(main, close, state, ns.CharList, function() ResetScroll() ns.Refresh() end, true)

---------------------------------------------------------------------------
-- Búsqueda y filtro de profesión
---------------------------------------------------------------------------
local search = K.Search(main, {
    name = "OficioSearchBox", x = PAD, y = -62, hint = Tr("Buscar receta o material..."),
    bg = { 0.09, 0.08, 0.07 }, border = { 0.32, 0.26, 0.17 }, hintColor = { 0.5, 0.47, 0.42 },
    onChange = function(text)
        state.text = text
        ResetScroll()
        ns.Refresh()
    end,
})

-- Clic izquierdo: profesión siguiente; derecho: anterior; la primera opción es "todas"
local profBtn = Button(main, 190, 22, "", function(_, mouse)
    local list = ProfNames()
    local idx = 0
    for i, name in ipairs(list) do if name == state.prof then idx = i end end
    if mouse == "RightButton" then idx = idx - 1 else idx = idx + 1 end
    if idx > #list then idx = 0 elseif idx < 0 then idx = #list end
    state.prof = list[idx]
    ResetScroll()
    ns.Refresh()
end)
profBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
profBtn:SetPoint("LEFT", search, "RIGHT", 10, 0)
local profArrows = Text(profBtn, 11)
profArrows:SetPoint("RIGHT", -8, 0)
profArrows:SetText("|cff888888< >|r")

local countText = Text(main, 11)
countText:SetPoint("RIGHT", main, "TOPRIGHT", -PAD, -73)
countText:SetTextColor(0.6, 0.6, 0.6)

---------------------------------------------------------------------------
-- Lista de recetas
---------------------------------------------------------------------------
local TOP_Y = -94
local FOOT_H = 30
local contentH = H + TOP_Y - FOOT_H - 8

local UpdateDetail

local function MakersText(e)
    local parts = {}
    local makers = ns.Makers(e.prof, e.name)
    for i = 1, math.min(3, #makers) do
        parts[#parts + 1] = "|c" .. ClassHex(makers[i].class) .. makers[i].name .. "|r"
    end
    if #makers > 3 then parts[#parts + 1] = GREY .. "...|r" end
    return table.concat(parts, ", ")
end

list = K.List(main, {
    name = "OficioListScroll", x = PAD, y = TOP_Y, w = LIST_W, h = contentH,
    rows = ROWS, rowH = ROW_H, nameW = 196, emptyW = 360,
    build = function(r)
        r.prof = Text(r, 11)
        r.prof:SetPoint("LEFT", 230, 0)
        r.prof:SetWidth(100)
        r.prof:SetJustifyH("LEFT")
        r.prof:SetWordWrap(false)
        r.prof:SetTextColor(0.72, 0.68, 0.6)
        r.who = Text(r, 11)
        r.who:SetPoint("LEFT", 334, 0)
        r.who:SetPoint("RIGHT", -4, 0)
        r.who:SetJustifyH("LEFT")
        r.who:SetWordWrap(false)
    end,
    fill = function(r, e)
        r.prof:SetText(e.prof)
        r.who:SetText(MakersText(e))
    end,
    item = function(e) return e.item end,
    selected = function(e) return state.selProf == e.prof and state.selName == e.name end,
    click = function(e)
        if state.selProf == e.prof and state.selName == e.name then
            state.selProf, state.selName = nil, nil     -- segundo clic: volver al resumen
        else
            state.selProf, state.selName = e.prof, e.name
        end
        UpdateDetail()
    end,
})
local listPanel, listEmpty = list.panel, list.empty

local sorter = K.Sorter(listPanel, state, function()
    ResetScroll()
    ns.Refresh()
end, { 0.72, 0.62, 0.45 })
sorter:Add("name", "Receta", 36, 190, "LEFT", true)
sorter:Add("prof", Tr("Profesión"), 236, 100, "LEFT", true)
local whoHeader = Text(listPanel, 11, "GameFontNormal")
whoHeader:SetPoint("TOPLEFT", 340, -7)
whoHeader:SetText(Tr("Quién"))
whoHeader:SetTextColor(ACC[1], ACC[2], ACC[3])


---------------------------------------------------------------------------
-- Panel derecho: resumen de profesiones o detalle de la receta elegida
---------------------------------------------------------------------------
local detail = Panel(main)
detail:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 10, 0)
detail:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, TOP_Y)
detail:SetHeight(contentH)
local dTitle = SectionTitle(detail, "Profesiones")

local dIcon, dName = K.DetailHead(detail)
local dSub = Text(detail, 11)
dSub:SetPoint("BOTTOMLEFT", dIcon, "BOTTOMRIGHT", 8, 0)
dSub:SetTextColor(0.72, 0.68, 0.6)

-- Líneas genéricas: { l = texto izquierdo, r = texto derecho, bar = 0..1, color = {r, g, b}, item = id }
local detailLines = K.Lines(detail, { n = LINES, lineH = LINE_H, barW = BAR_W, height = contentH, grey = GREY, items = true })
local function RenderLines(lines, top) detailLines:Render(lines, top) end

local function Title(text) return { l = ACC_HEX .. text .. "|r" } end

-- Resumen: profesiones y enfriamientos del personaje elegido (o de todos)
local function OverviewLines()
    local lines = {}
    local keys = state.filter and { state.filter } or ns.CharList()
    for _, key in ipairs(keys) do
        local c = ns.db.chars[key]
        local profs = ns.Profs(key)
        if c and #profs > 0 then
            if #lines > 0 then lines[#lines + 1] = {} end
            lines[#lines + 1] = {
                l = "|c" .. ClassHex(c.class) .. (c.name or ShortName(key)) .. "|r",
                r = GREY .. Tr("nivel ") .. (c.level or "?") .. "|r",
            }
            for _, p in ipairs(profs) do
                local right = "|cffffffff" .. p.rank .. "|r" .. GREY .. "/" .. p.max .. "|r"
                if p.recipes > 0 then right = GREY .. p.recipes .. " rec. · |r" .. right end
                lines[#lines + 1] = {
                    l = p.name, r = right,
                    bar = p.max > 0 and p.rank / p.max or 0,
                    color = p.main and ACC or { 0.55, 0.62, 0.70 },
                }
            end
        end
    end
    if #lines == 0 then
        lines[1] = { l = GREY .. Tr("Sin profesiones registradas.|r") }
    end

    local first = true
    for _, cd in ipairs(ns.Cooldowns()) do
        if not state.filter or state.filter == cd.key then
            if first then
                lines[#lines + 1] = {}
                lines[#lines + 1] = Title("Enfriamientos")
                first = false
            end
            local who = state.filter and "" or ("|c" .. ClassHex(cd.class) .. cd.name .. "|r · ")
            lines[#lines + 1] = {
                l = who .. cd.recipe,
                r = cd.left == 0 and "|cff66ff66listo|r" or N.Dur(cd.left),
            }
        end
    end
    return lines
end

-- Detalle de una receta: quién la fabrica y qué materiales lleva
local function RecipeLines(prof, name, makers)
    local lines = { Title(Tr("Quién lo fabrica")) }
    for _, m in ipairs(makers) do
        lines[#lines + 1] = {
            l = "|c" .. ClassHex(m.class) .. m.name .. "|r " .. GREY .. m.rank .. "|r",
            r = DIFF[m.diff] or "",
        }
    end
    local info = ns.db.recipes[prof] and ns.db.recipes[prof][name]
    local reags = info and info.r or {}
    if #reags > 0 then
        lines[#lines + 1] = {}
        lines[#lines + 1] = Title("Materiales")
        local alijo = false
        local cost, priced = 0, 0
        for _, rg in ipairs(reags) do
            local have = ns.Have(rg.id)
            local right
            if have then
                alijo = true
                right = (have >= rg.n and "|cff66ff66" or "|cffff6655") .. have .. "|r" .. GREY .. Tr(" en la cuenta|r")
            end
            local price = ns.Price(rg.id)
            if price then
                cost, priced = cost + price * rg.n, priced + 1
                right = (right and (right .. GREY .. " · |r") or "") .. Lonja.Money(price * rg.n, 11)
            end
            lines[#lines + 1] = { l = rg.n .. " x " .. ns.ReagName(rg), r = right, item = rg.id }
        end
        if not alijo then
            lines[#lines + 1] = { l = GREY .. Tr("Con Alijo activado verás cuántos tienes.|r") }
        end

        -- Con Lonja: lo que cuestan los materiales en la subasta y por cuánto se vende lo fabricado
        if priced > 0 then
            lines[#lines + 1] = {}
            lines[#lines + 1] = Title(Tr("En la lonja"))
            local partial = priced < #reags
            lines[#lines + 1] = {
                l = "Materiales" .. (partial and (GREY .. " (" .. priced .. Tr(" de ") .. #reags .. Tr(" con precio)|r")) or ""),
                r = Lonja.Money(cost, 11),
            }
            local sale = ns.Price(info.id)
            if sale then
                lines[#lines + 1] = { l = Tr("Se vende por"), r = Lonja.Money(sale, 11), item = info.id }
                if not partial then
                    local diff = sale - cost
                    lines[#lines + 1] = {
                        l = diff >= 0 and "Ganancia" or Tr("Pérdida"),
                        r = (diff >= 0 and "|cff66ff66" or "|cffff6655") .. Lonja.Money(diff, 11) .. "|r",
                    }
                end
            end
        end
    end
    return lines
end

function UpdateDetail()
    local makers = state.selName and ns.Makers(state.selProf, state.selName)
    local has = makers and #makers > 0
    dIcon:SetShown(has)
    dName:SetShown(has)
    dSub:SetShown(has)
    if not has then
        dTitle:SetText(state.filter and "Profesiones" or Tr("Profesiones de la cuenta"))
        RenderLines(OverviewLines(), 32)
        return
    end
    local info = ns.db.recipes[state.selProf] and ns.db.recipes[state.selProf][state.selName] or {}
    dTitle:SetText("Receta")
    dIcon:SetTexture(info.i or "Interface\\Icons\\INV_Misc_QuestionMark")
    dName:SetText(state.selName)
    dSub:SetText(state.selProf)
    RenderLines(RecipeLines(state.selProf, state.selName, makers), 84)
end

---------------------------------------------------------------------------
-- Pie
---------------------------------------------------------------------------
local footer = K.Footer(main, { h = FOOT_H, pad = PAD, right = "/oficio " .. Nexo.Cmd("oficio", "help") })

-- Avisa de las profesiones cuya ventana aún no se ha abierto con este personaje
local function UpdateFooter()
    local key = state.filter or ns.charKey
    local c = ns.db.chars[key]
    if not c then footer:SetText("") return end
    local missing = {}
    for _, p in ipairs(ns.Profs(key)) do
        if p.recipes == 0 and not NO_RECIPES[p.name:lower()] then missing[#missing + 1] = p.name end
    end
    local who = "|c" .. ClassHex(c.class) .. (c.name or ShortName(key)) .. "|r"
    if #missing > 0 then
        footer:SetText(who .. Tr("  ·  |cffffb347recetas sin registrar: ") .. table.concat(missing, ", ") .. Tr(" (abre su ventana)|r"))
    else
        footer:SetText(who .. Tr("  ·  Mayús+clic en la lista: enlazar en el chat"))
    end
end

---------------------------------------------------------------------------
-- Refrescar todo
---------------------------------------------------------------------------
local function Matches(e, text)
    if e.lower:find(text, 1, true) then return true end
    for _, rg in ipairs(e.reagents) do
        if ns.ReagName(rg):lower():find(text, 1, true) then return true end
    end
    return false
end

function ns.Refresh()
    if not main:IsShown() or not ns.db then return end
    if state.filter and not ns.db.chars[state.filter] then state.filter = nil end

    charBtn:SetChar(state.filter, ns.db.chars[state.filter], "ffe8dcc8")

    if state.prof then
        local ok = false
        for _, name in ipairs(ProfNames()) do if name == state.prof then ok = true end end
        if not ok then state.prof = nil end
    end
    profBtn.text:SetText(state.prof or Tr("Todas las profesiones"))
    profBtn:SetActive(state.prof ~= nil)

    sorter:Update()

    local all = ns.Index(state.filter, state.prof)
    local listData = {}
    local text = state.text
    for _, e in ipairs(all) do
        if text == "" or Matches(e, text) then listData[#listData + 1] = e end
    end
    local asc, byProf = state.asc, state.sort == "prof"
    table.sort(listData, function(a, b)
        if byProf and a.prof ~= b.prof then
            if asc then return a.prof < b.prof end
            return a.prof > b.prof
        end
        if a.lower ~= b.lower then
            if asc or byProf then return a.lower < b.lower end
            return a.lower > b.lower
        end
        return a.prof < b.prof
    end)

    if text ~= "" then
        countText:SetText(#listData .. Tr(" de ") .. Plural(#all, "receta", "recetas"))
    else
        countText:SetText(Plural(#all, "receta", "recetas"))
    end
    if #all == 0 then
        listEmpty:SetText(Tr("Aún no hay recetas. Abre la ventana de cada profesión una vez para registrarlas."))
    else
        listEmpty:SetText(Tr("Ninguna receta coincide con la búsqueda."))
    end

    list:SetData(listData)
    UpdateDetail()
    UpdateFooter()
end

function ns.OnDataChanged()
    if main:IsShown() then N.Debounce("Oficio.refresh", 0.3, ns.Refresh) end
end

function main:OnOpen() ns.Refresh() end
function main:OnClose() search:ClearFocus() end

function ns.Toggle()
    main:SetShown(not main:IsShown())
end

function ns.OpenSearch(text)
    state.filter = nil
    state.prof = nil
    main:Show()
    search:SetText(text or "")
    ns.Refresh()
end

---------------------------------------------------------------------------
-- Botón del minimapa (el de Nexo, compartido)
---------------------------------------------------------------------------
local function ShowSummaryTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    GameTooltip:AddLine("Oficio", ACC[1], ACC[2], ACC[3])
    if ns.db then
        local profs = ns.Profs()
        for _, p in ipairs(profs) do
            GameTooltip:AddDoubleLine(p.name, p.rank .. "/" .. p.max, 0.8, 0.8, 0.8, 1, 1, 1)
        end
        if #profs == 0 then GameTooltip:AddLine(Tr("Sin profesiones registradas"), 0.6, 0.6, 0.6) end
        local first = true
        for _, cd in ipairs(ns.Cooldowns()) do
            if first then
                GameTooltip:AddLine(" ")
                first = false
            end
            GameTooltip:AddDoubleLine("|c" .. ClassHex(cd.class) .. cd.name .. "|r · " .. cd.recipe,
                cd.left == 0 and "|cff66ff66listo|r" or N.Dur(cd.left), 0.8, 0.8, 0.8, 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(Tr("|cffffff00Clic|r para abrir · |cffffff00Arrastrar|r para mover"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

N.Register({
    id = "Oficio", name = Tr("Oficio"), icon = ICON, color = ACC, slash = "/oficio",
    toggle = function() ns.Toggle() end,
    tooltip = ShowSummaryTooltip,
    data = "OficioDB",
})

-- Menú de complementos (AddonCompartment)
function Oficio_OnCompartmentClick() ns.Toggle() end
function Oficio_OnCompartmentEnter(_, button) ShowSummaryTooltip(button or UIParent, "ANCHOR_LEFT") end
function Oficio_OnCompartmentLeave() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Inicio
---------------------------------------------------------------------------
function ns.OnInit()
    state.filter = ns.charKey   -- por defecto, el personaje con el que estás jugando
    main:RestorePos()
end
