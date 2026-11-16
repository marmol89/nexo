-- Nexo: piezas de interfaz comunes y botón único del minimapa
local ADDON = ...
local N = Nexo

local BD = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 }
local TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
N.BD, N.TEMPLATE = BD, TEMPLATE

---------------------------------------------------------------------------
-- Piezas sin tema
---------------------------------------------------------------------------
function N.Text(parent, size, template, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlight")
    if size then
        local font, _, flags = fs:GetFont()
        fs:SetFont(font, size, flags)
    end
    return fs
end

function N.Tex(parent, layer, r, g, b, a, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

local Text, Tex = N.Text, N.Tex

-- Hace que un marco se pueda arrastrar con el botón izquierdo y guarda dónde queda en
-- settings().pos. Le añade frame:RestorePos(), que lo lleva a la posición guardada.
function N.Movable(frame, settings)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local st = settings and settings()
        if st then
            local p, _, rp, x, y = s:GetPoint()
            st.pos = { p, rp, x, y }
        end
    end)
    function frame:RestorePos()
        local st = settings and settings()
        local pos = st and st.pos
        if pos then
            self:ClearAllPoints()
            self:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
        end
    end
end

-- Lleva al principio una lista con FauxScrollFrameTemplate
function N.ResetScroll(scroll)
    local name = scroll:GetName()
    local sb = scroll.ScrollBar or (name and _G[name .. "ScrollBar"])
    if sb then sb:SetValue(0) end
    FauxScrollFrame_SetOffset(scroll, 0)
end

-- Pinta las filas de una lista con FauxScrollFrame: rows = filas (todas de alto rowH),
-- data = lista completa. fill(r, e) rellena una fila con su dato; las que no tienen se ocultan.
function N.FillRows(scroll, rows, rowH, data, fill)
    local offset = FauxScrollFrame_GetOffset(scroll)
    FauxScrollFrame_Update(scroll, #data, #rows, rowH)
    for i, r in ipairs(rows) do
        local e = data[offset + i]
        r.data = e
        if e then
            fill(r, e)
            r:Show()
        else
            r:Hide()
        end
    end
end

-- Pone el enlace de un objeto en el cuadro de chat abierto; devuelve true si lo hizo
function N.LinkItem(id)
    local get = GetItemInfo or (C_Item and C_Item.GetItemInfo)
    if not id or not get then return false end
    local _, link = get(id)
    if not link then return false end
    if ChatEdit_InsertLink then
        ChatEdit_InsertLink(link)
    elseif ChatFrameUtil and ChatFrameUtil.InsertLink then
        ChatFrameUtil.InsertLink(link)
    else
        return false
    end
    return true
end

-- Tooltip del juego para un objeto por su id
function N.ItemTooltip(owner, id, anchor)
    if not id then return end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. id)
    GameTooltip:Show()
end

-- Líneas propias en el tooltip de los objetos.
-- fn(tip, id) añade sus líneas y devuelve true si añadió algo; así no se repiten
-- cuando el juego rellena el mismo tooltip más de una vez.
local tipFns = {}

local function RunItemTooltip(tip, id)
    if not id then return end
    local done = tip.nexoDone
    if not done then
        done = {}
        tip.nexoDone = done
    end
    local added = false
    for i, fn in ipairs(tipFns) do
        if not done[i] then
            local ok, res = pcall(fn, tip, id)
            if not ok then
                geterrorhandler()(res)
            elseif res then
                done[i] = true
                added = true
            end
        end
    end
    if added then tip:Show() end
end

local function HookItemTooltips()
    local tips = { GameTooltip, ItemRefTooltip }
    for _, tip in ipairs(tips) do
        tip:HookScript("OnTooltipCleared", function(self) self.nexoDone = nil end)
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data)
            if tip == GameTooltip or tip == ItemRefTooltip then
                RunItemTooltip(tip, data and data.id)
            end
        end)
    else
        for _, tip in ipairs(tips) do
            if tip:HasScript("OnTooltipSetItem") then
                tip:HookScript("OnTooltipSetItem", function(self)
                    local _, link = self:GetItem()
                    RunItemTooltip(self, N.ItemID(link))
                end)
            end
        end
    end
end

function N.OnItemTooltip(fn)
    if #tipFns == 0 then HookItemTooltips() end
    tipFns[#tipFns + 1] = fn
end

---------------------------------------------------------------------------
-- Kit con tema: cada addon pide el suyo con sus colores
--
-- tema = {
--   acc         = color de acento {r, g, b}
--   panelBg     = fondo de los paneles {r, g, b, a}      panelBorder = su borde
--   btnOn       = fondo del botón activo                 btnOnText   = su texto
--   btnOff      = fondo del botón normal                 btnBorder   = su borde
--   btnHover    = borde del botón con el ratón encima
--   winBg       = fondo de la ventana                    winBorder   = su borde
--   headBg      = fondo de la cabecera                   sub         = color del subtítulo
--   closeBg / closeBorder / closeX = botón de cerrar
-- }
---------------------------------------------------------------------------
function N.Kit(t)
    local acc = t.acc
    local accHex = ("|cff%02x%02x%02x"):format(
        math.floor(acc[1] * 255 + 0.5), math.floor(acc[2] * 255 + 0.5), math.floor(acc[3] * 255 + 0.5))
    local K = { acc = acc, accHex = accHex, Text = Text, Tex = Tex }

    function K.Panel(parent, bg, border)
        local f = CreateFrame("Frame", nil, parent, TEMPLATE)
        f:SetBackdrop(BD)
        bg = bg or t.panelBg
        border = border or t.panelBorder
        f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        f:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
        return f
    end

    function K.Button(parent, w, h, label, onClick, size)
        local b = CreateFrame("Button", nil, parent, TEMPLATE)
        b:SetSize(w, h)
        b:SetBackdrop(BD)
        b.text = Text(b, size or 12)
        b.text:SetPoint("CENTER")
        b.text:SetText(label)
        function b:SetActive(on)
            self.active = on
            if on then
                self:SetBackdropColor(t.btnOn[1], t.btnOn[2], t.btnOn[3], 1)
                self:SetBackdropBorderColor(acc[1], acc[2], acc[3], 1)
                self.text:SetTextColor(t.btnOnText[1], t.btnOnText[2], t.btnOnText[3])
            else
                self:SetBackdropColor(t.btnOff[1], t.btnOff[2], t.btnOff[3], 1)
                self:SetBackdropBorderColor(t.btnBorder[1], t.btnBorder[2], t.btnBorder[3], 1)
                self.text:SetTextColor(0.85, 0.85, 0.85)
            end
        end
        b:SetActive(false)
        b:SetScript("OnEnter", function(s)
            if not s.active then s:SetBackdropBorderColor(t.btnHover[1], t.btnHover[2], t.btnHover[3], 1) end
        end)
        b:SetScript("OnLeave", function(s)
            if not s.active then s:SetBackdropBorderColor(t.btnBorder[1], t.btnBorder[2], t.btnBorder[3], 1) end
        end)
        b:SetScript("OnClick", onClick)
        return b
    end

    function K.SectionTitle(parent, label)
        local fs = Text(parent, 12, "GameFontNormal")
        fs:SetPoint("TOPLEFT", 10, -8)
        fs:SetText(label)
        fs:SetTextColor(acc[1], acc[2], acc[3])
        local line = Tex(parent, "ARTWORK", acc[1], acc[2], acc[3], 0.25)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", 8, -24)
        line:SetPoint("TOPRIGHT", -8, -24)
        return fs
    end

    -- Ventana principal con cabecera (icono, título, subtítulo) y botón de cerrar.
    -- o = { name, w, h, icon, title, subtitle, settings = function() return tablaDeAjustes end }
    -- La posición se guarda en settings().pos. Devuelve la ventana y el botón de cerrar.
    function K.Window(o)
        local main = CreateFrame("Frame", o.name, UIParent, TEMPLATE)
        main:SetSize(o.w, o.h)
        main:SetPoint("CENTER")
        main:SetFrameStrata("HIGH")
        main:SetToplevel(true)
        main:SetBackdrop(BD)
        main:SetBackdropColor(t.winBg[1], t.winBg[2], t.winBg[3], 0.96)
        main:SetBackdropBorderColor(t.winBorder[1], t.winBorder[2], t.winBorder[3], 1)
        N.Movable(main, o.settings)
        main:Hide()
        tinsert(UISpecialFrames, o.name)

        -- Sonido al abrir y cerrar. El addon puede definir main:OnOpen() y main:OnClose().
        main:SetScript("OnShow", function(s)
            PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839)
            if s.OnOpen then s:OnOpen() end
        end)
        main:SetScript("OnHide", function(s)
            PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840)
            if s.OnClose then s:OnClose() end
        end)

        -- Llama a fn cada sec segundos mientras la ventana está abierta
        function main:Every(sec, fn)
            local el = 0
            self:SetScript("OnUpdate", function(_, dt)
                el = el + dt
                if el > sec then
                    el = 0
                    fn()
                end
            end)
        end

        local header = Tex(main, "BACKGROUND", t.headBg[1], t.headBg[2], t.headBg[3], 1, 1)
        header:SetPoint("TOPLEFT", 1, -1)
        header:SetPoint("TOPRIGHT", -1, -1)
        header:SetHeight(50)
        local headerLine = Tex(main, "ARTWORK", acc[1], acc[2], acc[3], 0.6)
        headerLine:SetHeight(1)
        headerLine:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
        headerLine:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")

        local logo = main:CreateTexture(nil, "ARTWORK")
        logo:SetTexture(o.icon)
        logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        logo:SetSize(34, 34)
        logo:SetPoint("TOPLEFT", 12, -9)

        local title = Text(main, 20, "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -1)
        title:SetText(o.title)
        title:SetTextColor(acc[1], acc[2], acc[3])

        local subtitle = Text(main, 11)
        subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
        subtitle:SetTextColor(t.sub[1], t.sub[2], t.sub[3])
        subtitle:SetText(o.subtitle)

        local close = CreateFrame("Button", nil, main, TEMPLATE)
        close:SetSize(24, 24)
        close:SetPoint("TOPRIGHT", -12, -13)
        close:SetBackdrop(BD)
        close:SetBackdropColor(t.closeBg[1], t.closeBg[2], t.closeBg[3], 1)
        close:SetBackdropBorderColor(t.closeBorder[1], t.closeBorder[2], t.closeBorder[3], 1)
        for _, angle in ipairs({ 45, -45 }) do
            local x = Tex(close, "ARTWORK", t.closeX[1], t.closeX[2], t.closeX[3], 1)
            x:SetSize(14, 2)
            x:SetPoint("CENTER")
            x:SetRotation(math.rad(angle))
        end
        close:SetScript("OnEnter", function(s)
            s:SetBackdropColor(0.55, 0.12, 0.10, 1)
            s:SetBackdropBorderColor(1, 0.4, 0.3, 1)
        end)
        close:SetScript("OnLeave", function(s)
            s:SetBackdropColor(t.closeBg[1], t.closeBg[2], t.closeBg[3], 1)
            s:SetBackdropBorderColor(t.closeBorder[1], t.closeBorder[2], t.closeBorder[3], 1)
        end)
        close:SetScript("OnClick", function() main:Hide() end)

        return main, close
    end

    -- Selector de personaje de la cabecera (clic izquierdo: siguiente; derecho: anterior).
    -- o = { list = function() return claves end, get = function() return clave end,
    --       set = function(clave) end, all = true si existe la opción "todos" (clave nil) }
    function K.CharButton(main, close, o)
        local lo = o.all and 0 or 1
        local b = K.Button(main, 210, 24, "", function(_, mouse)
            local list = o.list()
            if #list == 0 then return end
            local cur = o.get()
            local idx = lo
            for i, k in ipairs(list) do if k == cur then idx = i end end
            if mouse == "RightButton" then idx = idx - 1 else idx = idx + 1 end
            if idx > #list then idx = lo elseif idx < lo then idx = #list end
            o.set(list[idx])
        end)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetPoint("RIGHT", close, "LEFT", -10, 0)
        local arrows = Text(b, 11)
        arrows:SetPoint("RIGHT", -8, 0)
        arrows:SetText("|cff888888< >|r")
        b:HookScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
            GameTooltip:AddLine("Personaje")
            GameTooltip:AddLine("Clic izquierdo: siguiente", 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Clic derecho: anterior", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)

        -- Pinta el personaje elegido (c = sus datos, con .class y .level) o, si key es nil,
        -- "Todos los personajes". fallback = color "ffrrggbb" si no se conoce la clase.
        function b:SetChar(key, c, fallback)
            if key then
                self.text:SetText("|c" .. N.ClassHex(c and c.class, fallback) .. N.ShortName(key)
                    .. "|r  |cff888888nivel " .. ((c and c.level) or "?") .. "|r")
            else
                self.text:SetText(accHex .. "Todos los personajes|r")
            end
        end
        return b
    end

    -- Ventana con selector de personaje y pestañas de periodo ya colocados (Tesorero, Bitácora).
    -- o = K.Window + { state, list, all, pad, onChange() }. El periodo elegido se guarda en
    -- state.period y en settings().period, y luego se llama a onChange().
    -- Devuelve main, close, charBtn, periodBtns y periodHint.
    function K.Dashboard(o)
        local main, close = K.Window(o)
        local charBtn = K.CharPicker(main, close, o.state, o.list, o.onChange, o.all)
        local periodBtns, periodHint = K.Periods(main, o.pad, -62, function(period)
            o.state.period = period
            local st = o.settings and o.settings()
            if st then st.period = period end
            o.onChange()
        end)
        return main, close, charBtn, periodBtns, periodHint
    end

    -- Pestañas de periodo (N.PERIODS) en (x, y) y, a su derecha, un texto de ayuda.
    -- onPick(periodo). Devuelve las pestañas y el texto.
    function K.Periods(main, x, y, onPick)
        local tabs = K.Tabs(main, N.PERIODS, 80, onPick)
        tabs[1]:SetPoint("TOPLEFT", x, y)
        local hint = Text(main, 11)
        hint:SetPoint("LEFT", tabs[#tabs], "RIGHT", 12, 0)
        hint:SetTextColor(0.6, 0.6, 0.6)
        return tabs, hint
    end

    -- Selector de personaje sobre state.filter (nil = todos si all). list() = claves del addon
    -- (su ns.CharList); onChange() al cambiarlo.
    function K.CharPicker(main, close, state, list, onChange, all)
        return K.CharButton(main, close, {
            list = list,
            get = function() return state.filter end,
            set = function(key)
                state.filter = key
                onChange()
            end,
            all = all,
        })
    end

    -- Fila de botones excluyentes. defs = { { clave, texto }, ... }; onPick(clave) al pulsar uno.
    -- Devuelve los botones (el primero lo coloca el addon) con tabs:Select(clave).
    function K.Tabs(parent, defs, w, onPick)
        local tabs = {}
        for i, d in ipairs(defs) do
            local b = K.Button(parent, w, 22, d[2], function() onPick(d[1]) end)
            b.key = d[1]
            if i > 1 then b:SetPoint("LEFT", tabs[i - 1], "RIGHT", 6, 0) end
            tabs[i] = b
        end
        function tabs:Select(key)
            for _, b in ipairs(self) do b:SetActive(b.key == key) end
        end
        return tabs
    end

    -- Fila de tarjetas de resumen que ocupa un ancho dado.
    -- defs = { { etiqueta, color, icono }, ... }; o = { x, y, w = ancho total, valueSize, tint }
    function K.Cards(parent, defs, o)
        local gap = 10
        local cw = (o.w - gap * (#defs - 1)) / #defs
        local cards = {}
        for i, def in ipairs(defs) do
            local c = K.Card(parent, cw, def[1], def[2], def[3], o.valueSize, o.tint)
            c:SetPoint("TOPLEFT", o.x + (i - 1) * (cw + gap), o.y)
            cards[i] = c
        end
        return cards
    end

    -- Gráfico de barras por casillas dentro de un panel: línea base, dos líneas de escala y
    -- n casillas que se resaltan con el ratón.
    -- o = { n = casillas, w = ancho del panel, plotH, plotBottom,
    --       hl = color del resalte (por defecto el acento), today = true si la última casilla
    --       queda siempre marcada, build = function(s, slotW) crea las barras de la casilla,
    --       tooltip = function(s, datos) con el ratón encima de una casilla con datos (s.data) }
    -- Devuelve las casillas (cada una con .hl y .data) y las etiquetas de escala ({ frac, fs }).
    function K.Chart(chart, o)
        local hl = o.hl or acc
        local slotW = (o.w - 20) / o.n
        local baseLine = Tex(chart, "ARTWORK", 1, 1, 1, 0.15)
        baseLine:SetHeight(1)
        baseLine:SetPoint("BOTTOMLEFT", 10, o.plotBottom)
        baseLine:SetPoint("BOTTOMRIGHT", -10, o.plotBottom)

        local gridLabels = {}
        for i, frac in ipairs({ 0.5, 1 }) do
            local g = Tex(chart, "BACKGROUND", 1, 1, 1, 0.05, 2)
            g:SetHeight(1)
            g:SetPoint("BOTTOMLEFT", 10, o.plotBottom + o.plotH * frac)
            g:SetPoint("BOTTOMRIGHT", -10, o.plotBottom + o.plotH * frac)
            local l = Text(chart, 9)
            l:SetPoint("BOTTOMRIGHT", g, "TOPRIGHT", 0, 1)
            l:SetTextColor(0.45, 0.45, 0.45)
            gridLabels[i] = { frac = frac, fs = l }
        end

        local slots = {}
        for i = 1, o.n do
            local s = CreateFrame("Frame", nil, chart)
            s:SetSize(slotW, o.plotH + o.plotBottom)
            s:SetPoint("BOTTOMLEFT", 10 + (i - 1) * slotW, 0)
            s:EnableMouse(true)
            s.hl = Tex(s, "BACKGROUND", hl[1], hl[2], hl[3], 0.08, 3)
            s.hl:SetPoint("TOPLEFT", 1, 0)
            s.hl:SetPoint("BOTTOMRIGHT", -1, o.plotBottom)
            s.hl:Hide()
            if o.build then o.build(s, slotW) end
            s:SetScript("OnEnter", function(self)
                self.hl:Show()
                if self.data and o.tooltip then o.tooltip(self, self.data) end
            end)
            s:SetScript("OnLeave", function(self)
                if not self.isToday then self.hl:Hide() end
                GameTooltip:Hide()
            end)
            slots[i] = s
        end
        if o.today then
            local last = slots[o.n]
            last.isToday = true
            last.hl:Show()
            last.hl:SetColorTexture(hl[1], hl[2], hl[3], 0.06)
        end
        return slots, gridLabels
    end

    -- Rejilla de datos sueltos en dos columnas: etiqueta pequeña, valor y nota al lado.
    -- Devuelve una lista; cada dato tiene :Set(valor, nota).
    function K.StatGrid(parent, names)
        local stats = {}
        for i, name in ipairs(names) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local f = CreateFrame("Frame", nil, parent)
            f:SetSize(170, 32)
            f:SetPoint("TOPLEFT", 4 + col * 182, -6 - row * 33)
            f.label = Text(f, 9)
            f.label:SetPoint("TOPLEFT", 0, 0)
            f.label:SetTextColor(0.55, 0.55, 0.55)
            f.label:SetText(name:upper())
            f.value = Text(f, 12)
            f.value:SetPoint("TOPLEFT", 0, -11)
            f.value:SetWordWrap(false)
            f.sub = Text(f, 9)
            f.sub:SetPoint("LEFT", f.value, "RIGHT", 6, 0)
            f.sub:SetTextColor(0.5, 0.5, 0.5)
            f.sub:SetWordWrap(false)
            function f:Set(value, sub)
                self.value:SetText(value)
                self.sub:SetText(sub or "")
            end
            stats[i] = f
        end
        return stats
    end

    -- Pie de la ventana: línea, texto a la izquierda y ayuda a la derecha.
    -- o = { h = alto del pie, pad = margen lateral, right = texto de la derecha }
    -- Devuelve el texto de la izquierda y el de la derecha.
    function K.Footer(main, o)
        local line = Tex(main, "ARTWORK", acc[1], acc[2], acc[3], 0.2)
        line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT", 1, o.h)
        line:SetPoint("BOTTOMRIGHT", -1, o.h)
        local left = Text(main, 11)
        left:SetPoint("BOTTOMLEFT", o.pad, 10)
        left:SetTextColor(0.75, 0.75, 0.75)
        local right = Text(main, 10)
        right:SetPoint("BOTTOMRIGHT", -o.pad, 10)
        right:SetTextColor(0.45, 0.45, 0.45)
        right:SetText(o.right or "")
        return left, right
    end

    -- Cuadro de búsqueda.
    -- o = { name = nombre global, x, y, w, hint = texto cuando está vacío,
    --       bg, border, hintColor = colores {r, g, b},
    --       onChange = function(texto) con el texto en minúsculas y sin espacios en los extremos }
    function K.Search(parent, o)
        local bg, border, hc = o.bg, o.border, o.hintColor
        local s = CreateFrame("EditBox", o.name, parent, TEMPLATE)
        s:SetSize(o.w or 230, 22)
        s:SetPoint("TOPLEFT", o.x, o.y)
        s:SetBackdrop(BD)
        s:SetBackdropColor(bg[1], bg[2], bg[3], 1)
        s:SetBackdropBorderColor(border[1], border[2], border[3], 1)
        s:SetAutoFocus(false)
        s:SetFontObject(ChatFontNormal)
        s:SetTextInsets(8, 8, 0, 0)
        s:SetMaxLetters(40)
        local hint = Text(s, 11)
        hint:SetPoint("LEFT", 8, 0)
        hint:SetTextColor(hc[1], hc[2], hc[3])
        hint:SetText(o.hint)
        s:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        s:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        s:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(acc[1], acc[2], acc[3], 1) end)
        s:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(border[1], border[2], border[3], 1) end)
        s:SetScript("OnTextChanged", function(self)
            local text = self:GetText() or ""
            hint:SetShown(text == "")
            o.onChange((text:lower():gsub("^%s+", ""):gsub("%s+$", "")))
        end)
        return s
    end

    -- Lista con barra de desplazamiento en su propio panel. Cada fila trae icono y nombre.
    -- o = { name = nombre global de la barra, x, y, w, h, rows = filas visibles, rowH,
    --       nameW = ancho del nombre, emptyW = ancho del aviso de lista vacía,
    --       build = function(r, i)   crea las columnas propias de la fila
    --       fill = function(r, e)    las rellena con el dato e (icono y nombre ya puestos)
    --       item = function(e)       id del objeto de la fila: tooltip y Mayús+clic para enlazarlo
    --       selected = function(e)   ¿es la fila elegida?
    --       click = function(e) }    al pulsar la fila
    -- Devuelve la lista: .panel, .empty (aviso), :SetData(datos), :Update(), :Reset() (volver arriba).
    function K.List(parent, o)
        local list = { data = {}, rows = {} }
        local panel = K.Panel(parent)
        panel:SetPoint("TOPLEFT", o.x, o.y)
        panel:SetSize(o.w, o.h)
        local line = Tex(panel, "ARTWORK", acc[1], acc[2], acc[3], 0.25)
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", 8, -24)
        line:SetPoint("TOPRIGHT", -8, -24)
        list.panel = panel

        local scroll = CreateFrame("ScrollFrame", o.name, panel, "FauxScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 4, -30)
        scroll:SetPoint("BOTTOMRIGHT", -26, 10)
        list.scroll = scroll

        for i = 1, o.rows do
            local r = CreateFrame("Button", nil, panel)
            r:SetHeight(o.rowH)
            r:SetPoint("TOPLEFT", 6, -30 - (i - 1) * o.rowH)
            r:SetPoint("RIGHT", scroll, "RIGHT", 0, 0)
            r.bg = Tex(r, "BACKGROUND", 1, 1, 1, (i % 2 == 0) and 0.03 or 0)
            r.bg:SetAllPoints()
            r.hl = Tex(r, "BACKGROUND", acc[1], acc[2], acc[3], 0.08, 1)
            r.hl:SetAllPoints()
            r.hl:Hide()
            r.sel = Tex(r, "BACKGROUND", acc[1], acc[2], acc[3], 0.16, 2)
            r.sel:SetAllPoints()
            r.sel:Hide()
            r.icon = r:CreateTexture(nil, "ARTWORK")
            r.icon:SetSize(20, 20)
            r.icon:SetPoint("LEFT", 4, 0)
            r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            r.name = Text(r, 12)
            r.name:SetPoint("LEFT", 30, 0)
            r.name:SetWidth(o.nameW)
            r.name:SetJustifyH("LEFT")
            r.name:SetWordWrap(false)
            if o.build then o.build(r, i) end
            r:SetScript("OnEnter", function(self)
                self.hl:Show()
                if self.data and o.item then N.ItemTooltip(self, o.item(self.data)) end
            end)
            r:SetScript("OnLeave", function(self)
                self.hl:Hide()
                GameTooltip:Hide()
            end)
            r:SetScript("OnClick", function(self)
                local e = self.data
                if not e then return end
                local id = o.item and o.item(e)
                if id and IsShiftKeyDown() then
                    N.LinkItem(id)
                    return
                end
                if o.click then o.click(e) end
                list:Update()
            end)
            list.rows[i] = r
        end

        list.empty = Text(panel, 12)
        list.empty:SetPoint("CENTER", -10, 0)
        if o.emptyW then list.empty:SetWidth(o.emptyW) end
        list.empty:SetTextColor(0.5, 0.5, 0.5)

        function list:Update()
            local data = self.data
            local offset = FauxScrollFrame_GetOffset(scroll)
            FauxScrollFrame_Update(scroll, #data, o.rows, o.rowH)
            for i, r in ipairs(self.rows) do
                local e = data[offset + i]
                r.data = e
                if e then
                    r.icon:SetTexture(e.icon)
                    r.name:SetText(e.name)
                    if o.fill then o.fill(r, e) end
                    r.sel:SetShown(o.selected ~= nil and o.selected(e) or false)
                    r:Show()
                else
                    r:Hide()
                end
            end
            self.empty:SetShown(#data == 0)
        end

        function list:SetData(data)
            self.data = data
            self:Update()
        end

        function list:Reset() N.ResetScroll(scroll) end

        scroll:SetScript("OnVerticalScroll", function(self, offset)
            FauxScrollFrame_OnVerticalScroll(self, offset, o.rowH, function() list:Update() end)
        end)
        return list
    end

    -- Cabecera de un panel de detalle: icono grande y, a su derecha, el nombre en dos líneas como mucho
    function K.DetailHead(detail)
        local icon = detail:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("TOPLEFT", 10, -34)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local name = Text(detail, 13)
        name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
        name:SetPoint("RIGHT", -10, 0)
        name:SetJustifyH("LEFT")
        name:SetJustifyV("TOP")
        if name.SetMaxLines then name:SetMaxLines(2) end
        return icon, name
    end

    -- Tarjeta de resumen: etiqueta, valor grande y línea secundaria (card.label / .value / .sub)
    function K.Card(parent, w, label, color, icon, valueSize, tint)
        local c = K.Panel(parent, { 0.08, 0.08, 0.10, 1 })
        c:SetSize(w, 66)
        local accent = Tex(c, "ARTWORK", color[1], color[2], color[3], 1)
        accent:SetPoint("TOPLEFT", 1, -1)
        accent:SetPoint("BOTTOMLEFT", 1, 1)
        accent:SetWidth(3)
        local glow = Tex(c, "BACKGROUND", color[1], color[2], color[3], 0.06, 2)
        glow:SetPoint("TOPLEFT", 4, -1)
        glow:SetPoint("BOTTOMLEFT", 4, 1)
        glow:SetWidth(60)
        local ic = c:CreateTexture(nil, "ARTWORK")
        ic:SetTexture(icon)
        ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ic:SetSize(22, 22)
        ic:SetPoint("TOPRIGHT", -8, -8)
        ic:SetAlpha(0.85)
        c.label = Text(c, 11)
        c.label:SetPoint("TOPLEFT", 12, -9)
        c.label:SetTextColor(0.65, 0.65, 0.65)
        c.label:SetText(label:upper())
        c.value = Text(c, valueSize or 16)
        c.value:SetPoint("TOPLEFT", 12, -26)
        c.value:SetPoint("RIGHT", -6, 0)
        c.value:SetJustifyH("LEFT")
        c.value:SetWordWrap(false)
        if tint then c.value:SetTextColor(color[1], color[2], color[3]) end
        c.sub = Text(c, 10)
        c.sub:SetPoint("BOTTOMLEFT", 12, 8)
        c.sub:SetPoint("RIGHT", -6, 0)
        c.sub:SetJustifyH("LEFT")
        c.sub:SetWordWrap(false)
        c.sub:SetTextColor(0.55, 0.55, 0.55)
        return c
    end

    -- Cabeceras de columna que ordenan una lista al pulsarlas.
    -- state = tabla con .sort (clave de la columna) y .asc; onSort() se llama al cambiar el orden;
    -- off = color {r, g, b} de las cabeceras que no mandan.
    --   s:Add(key, label, x, width, justify, ascFirst)   crea una cabecera y la devuelve
    --       (.key y .label se pueden cambiar después); ascFirst = empieza de menor a mayor
    --       (si se omite, solo lo hace la columna "name")
    --   s:Has(key)   ¿hay una cabecera con esa clave?
    --   s:Update()   pinta cuál manda y en qué sentido
    function K.Sorter(parent, state, onSort, off)
        local s = { btns = {} }

        function s:Add(key, label, x, width, justify, ascFirst)
            local b = CreateFrame("Button", nil, parent)
            b:SetSize(width, 18)
            b:SetPoint("TOPLEFT", x, -4)
            b.text = Text(b, 11, "GameFontNormal")
            b.text:SetPoint(justify or "LEFT", 0, 0)
            b.key, b.label = key, label
            b:SetScript("OnClick", function(self)
                if state.sort == self.key then
                    state.asc = not state.asc
                else
                    state.sort = self.key
                    if ascFirst == nil then state.asc = self.key == "name" else state.asc = ascFirst end
                end
                onSort()
            end)
            self.btns[#self.btns + 1] = b
            return b
        end

        function s:Has(key)
            for _, b in ipairs(self.btns) do
                if b.key == key then return true end
            end
            return false
        end

        function s:Update()
            for _, b in ipairs(self.btns) do
                if state.sort == b.key then
                    b.text:SetText(b.label .. (state.asc and " |cffffffff+|r" or " |cffffffff-|r"))
                    b.text:SetTextColor(acc[1], acc[2], acc[3])
                else
                    b.text:SetText(b.label)
                    b.text:SetTextColor(off[1], off[2], off[3])
                end
            end
        end

        return s
    end

    -- Líneas de un panel de detalle: texto a la izquierda, texto a la derecha y barra opcional.
    -- o = { n = líneas como mucho, lineH = alto de cada una, barW = ancho de la barra llena,
    --       height = alto del panel, grey = color "|cff..." del aviso de líneas que no caben,
    --       items = true si al pasar el ratón enseñan el objeto de la línea }
    --   l:Render(lines, top)   lines = { { l, r, bar = 0..1, color = {r, g, b}, item = id }, ... }
    function K.Lines(parent, o)
        local rows = {}
        for i = 1, o.n do
            local r = CreateFrame("Frame", nil, parent)
            r:SetHeight(o.lineH)
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
            r.bar = Tex(r, "ARTWORK", acc[1], acc[2], acc[3], 0.9)
            r.bar:SetHeight(2)
            r.bar:SetPoint("BOTTOMLEFT", 0, 0)
            if o.items then
                r:EnableMouse(true)
                r:SetScript("OnEnter", function(self) N.ItemTooltip(self, self.item) end)
                r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
            r:Hide()
            rows[i] = r
        end

        local l = { rows = rows }
        function l:Render(lines, top)
            local fit = math.max(1, math.min(o.n, math.floor((o.height - top - 8) / o.lineH)))
            if #lines > fit then
                lines[fit] = { l = (o.grey or "|cff888888") .. "y " .. (#lines - fit + 1) .. " líneas más|r" }
                for i = #lines, fit + 1, -1 do lines[i] = nil end
            end
            for i, r in ipairs(rows) do
                local d = lines[i]
                if d then
                    r:ClearAllPoints()
                    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -(top + (i - 1) * o.lineH))
                    r:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
                    r.l:SetText(d.l or "")
                    r.r:SetText(d.r or "")
                    r.item = d.item
                    local hasBar = d.bar ~= nil
                    r.barBg:SetShown(hasBar)
                    r.bar:SetShown(hasBar)
                    if hasBar then
                        local c = d.color or acc
                        r.bar:SetColorTexture(c[1], c[2], c[3], 0.9)
                        r.bar:SetWidth(math.max(1, math.min(1, d.bar) * o.barW))
                    end
                    r:Show()
                else
                    r:Hide()
                end
            end
        end
        return l
    end

    return K
end

---------------------------------------------------------------------------
-- Registro de addons y botón único del minimapa
--
-- def = { id, name, icon, color = {r, g, b}, slash = "/comando",
--         toggle = function() end,                 -- abrir/cerrar su ventana
--         tooltip = function(owner, anchor) end,   -- resumen al pasar el ratón
--         data = "MiAddonDB" }                     -- variable guardada, para exportar e importar
---------------------------------------------------------------------------
local GEAR = "Interface\\Icons\\INV_Misc_Gear_01"
N.addons = {}
local addons = N.addons

local mb = CreateFrame("Button", "NexoMinimapButton", Minimap)
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
mbIcon:SetTexture(GEAR)
mbIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
mbIcon:SetPoint("TOPLEFT", 7, -6)
local mbBorder = mb:CreateTexture(nil, "OVERLAY")
mbBorder:SetSize(53, 53)
mbBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
mbBorder:SetPoint("TOPLEFT")
mb:Hide()

local function PlaceMinimap()
    if not N.db then return end
    local a = math.rad(N.db.minimap.angle or 200)
    -- radio según el tamaño real del minimapa, para quedar en el borde exterior
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

local function UpdateMinimapButton()
    if not N.db then return end
    PlaceMinimap()
    mbIcon:SetTexture(#addons == 1 and addons[1].icon or GEAR)
    mb:SetShown(#addons > 0 and not N.db.minimap.hide)
end

-- Muestra u oculta el botón; devuelve true si queda oculto
function N.ToggleMinimap()
    N.db.minimap.hide = not N.db.minimap.hide
    UpdateMinimapButton()
    return N.db.minimap.hide
end

-- Menú con los addons registrados
local ROW_H, MENU_W = 24, 160
local menu = CreateFrame("Frame", "NexoMenu", UIParent, TEMPLATE)
menu:SetFrameStrata("DIALOG")
menu:SetBackdrop(BD)
menu:SetBackdropColor(0.05, 0.05, 0.06, 0.97)
menu:SetBackdropBorderColor(0.32, 0.32, 0.38, 1)
menu:SetClampedToScreen(true)
menu:EnableMouse(true)
menu:Hide()
menu.rows = {}
menu.away = 0
menu:SetScript("OnUpdate", function(self, el)
    if self:IsMouseOver() or mb:IsMouseOver() then
        self.away = 0
    else
        self.away = self.away + el
        if self.away > 1 then self:Hide() end
    end
end)
menu:SetScript("OnHide", function() GameTooltip:Hide() end)

local function MenuRow(i)
    local r = menu.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, menu)
    r:SetSize(MENU_W - 8, ROW_H)
    r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * ROW_H)
    r.hl = Tex(r, "BACKGROUND", 1, 1, 1, 0.08)
    r.hl:SetAllPoints()
    r.hl:Hide()
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(18, 18)
    r.icon:SetPoint("LEFT", 4, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = Text(r, 12)
    r.name:SetPoint("LEFT", 28, 0)
    r:SetScript("OnEnter", function(self)
        self.hl:Show()
        if self.def and self.def.tooltip then self.def.tooltip(self, "ANCHOR_LEFT") end
    end)
    r:SetScript("OnLeave", function(self) self.hl:Hide() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        menu:Hide()
        if self.def and self.def.toggle then self.def.toggle() end
    end)
    menu.rows[i] = r
    return r
end

-- Última fila del menú: la ventana de exportar e importar
local DATA_ROW = { name = "Exportar / importar", icon = GEAR, color = { 0.85, 0.85, 0.90 },
    toggle = function() N.ToggleData() end }

local function ShowMenu()
    local n = #addons + 1
    for i = 1, n do
        local def = addons[i] or DATA_ROW
        local r = MenuRow(i)
        r.def = def
        r.icon:SetTexture(def.icon)
        r.name:SetText(def.name)
        local c = def.color or { 1, 1, 1 }
        r.name:SetTextColor(c[1], c[2], c[3])
        r:Show()
    end
    for i = n + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(MENU_W, n * ROW_H + 8)
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", mb, "BOTTOMLEFT", 6, 6)
    menu.away = 0
    GameTooltip:Hide()
    menu:Show()
end

function N.Register(def)
    for i, d in ipairs(addons) do
        if d.id == def.id then addons[i] = def; UpdateMinimapButton() return end
    end
    addons[#addons + 1] = def
    table.sort(addons, function(a, b) return a.name < b.name end)
    UpdateMinimapButton()
end

mb:SetScript("OnDragStart", function(self)
    menu:Hide()
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        N.db.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
        PlaceMinimap()
    end)
end)
mb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
mb:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)   -- ocultado a medio arrastrar

mb:SetScript("OnClick", function()
    if #addons == 1 then
        if addons[1].toggle then addons[1].toggle() end
    elseif menu:IsShown() then
        menu:Hide()
    else
        ShowMenu()
    end
end)

mb:SetScript("OnEnter", function(self)
    if menu:IsShown() then return end
    if #addons == 1 and addons[1].tooltip then
        addons[1].tooltip(self, "ANCHOR_LEFT")
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Nexo", 0.85, 0.85, 0.90)
    for _, def in ipairs(addons) do
        local c = def.color or { 1, 1, 1 }
        GameTooltip:AddLine("|T" .. def.icon .. ":14:14:0:0:64:64:5:59:5:59|t " .. def.name, c[1], c[2], c[3])
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffff00Clic|r para elegir · |cffffff00Arrastrar|r para mover", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
mb:SetScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------
-- Ventana de exportar e importar (/nexo datos)
--
-- Exportar: se eligen los addons, se genera el texto y se copia con Ctrl+C.
-- Importar: se pega el texto, se comprueba y, al confirmar, sustituye los datos y recarga.
---------------------------------------------------------------------------
local DW, DH, DPAD = 560, 300, 14
local BIG = 400 * 1024   -- a partir de aquí pegar el texto de una vez puede fallar
local dataWin

local function BuildData()
    local K = N.Kit({
        acc = { 0.85, 0.85, 0.90 },
        panelBg = { 0.08, 0.08, 0.10, 0.92 }, panelBorder = { 0.22, 0.22, 0.27, 1 },
        btnOn = { 0.24, 0.25, 0.32 }, btnOnText = { 1, 1, 1 },
        btnOff = { 0.11, 0.11, 0.13 }, btnBorder = { 0.27, 0.27, 0.33 }, btnHover = { 0.60, 0.60, 0.70 },
        winBg = { 0.05, 0.05, 0.06 }, winBorder = { 0.32, 0.32, 0.38 },
        headBg = { 0.10, 0.10, 0.13 }, sub = { 0.62, 0.62, 0.70 },
        closeBg = { 0.10, 0.10, 0.12 }, closeBorder = { 0.32, 0.32, 0.38 }, closeX = { 0.90, 0.90, 0.95 },
    })
    local main = K.Window({ name = "NexoDatos", w = DW, h = DH, icon = GEAR, title = "Datos",
        subtitle = "Exportar e importar para cambiar de ordenador",
        settings = function() return N.db end })
    main:RestorePos()

    local defs = N.DataAddons()
    local mode, sel = "export", {}
    local pack, exported, zipped, err, armed   -- lo leído al importar; lo generado al exportar
    local box, Refresh

    local function Has(def)
        if mode == "export" then return type(_G[def.data]) == "table" end
        return pack ~= nil and type(pack.data[def.id]) == "table"
    end

    local function AnyPicked()
        for _, def in ipairs(defs) do
            if sel[def.id] and Has(def) then return true end
        end
        return false
    end

    local tabs = K.Tabs(main, { { "export", "Exportar" }, { "import", "Importar" } }, 110,
        function(key) main:SetMode(key) end)
    tabs[1]:SetPoint("TOPLEFT", DPAD, -62)

    -- Un botón por addon: marcado = entra en la exportación o en la importación
    local gap = 6
    local bw = (DW - 2 * DPAD - gap * (#defs - 1)) / #defs
    local picks = {}
    for i, def in ipairs(defs) do
        local b = K.Button(main, bw, 22, def.name, function()
            if not Has(def) then return end
            sel[def.id] = not sel[def.id] or nil
            armed = false
            if mode == "export" then
                exported = nil
                box:SetText("")
            end
            Refresh()
        end, 11)
        b:SetPoint("TOPLEFT", DPAD + (i - 1) * (bw + gap), -94)
        picks[i] = b
    end

    local hint = Text(main, 11)
    hint:SetPoint("TOPLEFT", DPAD, -128)
    hint:SetPoint("RIGHT", -DPAD, 0)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(0.70, 0.70, 0.75)

    local boxPanel = K.Panel(main)
    boxPanel:SetPoint("TOPLEFT", DPAD, -148)
    boxPanel:SetPoint("RIGHT", -DPAD, 0)
    boxPanel:SetHeight(26)

    -- De una sola línea: el texto no lleva saltos y así el juego no tiene que pintarlo entero
    box = CreateFrame("EditBox", "NexoDatosBox", boxPanel)
    box:SetPoint("TOPLEFT", 8, 0)
    box:SetPoint("BOTTOMRIGHT", -8, 0)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetMaxLetters(0)
    if box.SetMaxBytes then box:SetMaxBytes(0) end

    local status = Text(main, 12)
    status:SetPoint("TOPLEFT", DPAD, -186)
    status:SetPoint("RIGHT", -DPAD, 0)
    status:SetJustifyH("LEFT")
    status:SetJustifyV("TOP")
    status:SetSpacing(3)

    local action = K.Button(main, 250, 26, "", function()
        if not AnyPicked() then return end
        if mode == "export" then
            local ok, text, z = pcall(N.Export, sel)
            if ok then
                exported, zipped, err = text, z, nil
                box:SetText(text)
                box:SetCursorPosition(0)
                box:SetFocus()
                box:HighlightText()
            else
                exported, err = nil, "No se han podido exportar los datos: " .. tostring(text)
            end
            Refresh()
        elseif not armed then
            armed = true
            Refresh()
        else
            N.Import(pack, sel)
            local reload = C_UI and C_UI.Reload or ReloadUI
            reload()
        end
    end)
    action:SetPoint("BOTTOMLEFT", DPAD, DPAD)

    local function ReadPasted(text)
        if mode ~= "import" then return end
        pack, err, armed, sel = nil, nil, false, {}
        if text:find("%S") then
            pack, err = N.ReadExport(text)
            if pack then
                for _, def in ipairs(defs) do
                    if Has(def) then sel[def.id] = true end
                end
            end
        end
        Refresh()
    end

    box:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    box:SetScript("OnEditFocusGained", function(s)
        if mode == "export" then s:HighlightText() end
    end)
    box:SetScript("OnTextChanged", function(s, user)
        if not user or mode ~= "export" then return end
        -- el texto exportado no se edita: si se toca, vuelve a como estaba
        s:SetText(exported or "")
        s:SetCursorPosition(0)
        s:HighlightText()
    end)

    -- Pegar: si el cuadro recibe cientos de KB, el juego lo recoloca letra a letra y se cuelga.
    -- Al importar el cuadro está limitado a unos pocos bytes (ver SetMode), pero las letras
    -- pegadas siguen llegando a OnChar: se juntan aquí y se leen en el fotograma siguiente.
    local pasted, count
    local function PasteDone(s)
        s:SetScript("OnUpdate", nil)
        local text = table.concat(pasted, "", 1, count)
        pasted, count = nil, nil
        s:SetText("")
        s:ClearFocus()
        ReadPasted(text)
    end
    box:SetScript("OnChar", function(s, c)
        if mode ~= "import" then return end
        if not pasted then
            pasted, count = {}, 0
            s:SetScript("OnUpdate", PasteDone)
        end
        count = count + 1
        pasted[count] = c
    end)

    function Refresh()
        tabs:Select(mode)
        for i, def in ipairs(defs) do
            local has = Has(def)
            picks[i]:SetActive(has and sel[def.id] or false)
            picks[i]:SetAlpha(has and 1 or 0.35)
        end
        action:SetAlpha(AnyPicked() and 1 or 0.4)

        local msg = err and ("|cffff6655" .. err .. "|r") or ""
        if mode == "export" then
            hint:SetText("Marca los addons que quieres llevarte y genera el texto.")
            action.text:SetText("Generar texto")
            if exported then
                msg = ("|cff66dd88Texto listo|r: %s KB%s. Está seleccionado: pulsa |cffffff00Ctrl+C|r y pégalo en un "
                    .. "archivo de texto. En el otro ordenador, pégalo en |cffffff00/nexo importar|r.")
                    :format(N.Num(#exported / 1024), zipped and ", comprimido" or "")
                if #exported > BIG then
                    msg = msg .. "\n|cffffcc55Es mucho texto para pegarlo de una vez. Si falla, lleva Lonja aparte.|r"
                end
            end
        else
            hint:SetText("Haz clic en el cuadro y pega con Ctrl+V el texto exportado. El cuadro se queda vacío: es normal.")
            action.text:SetText(armed and "Pulsa otra vez para confirmar" or "Importar y recargar")
            if pack then
                msg = ("|cff66dd88Texto leído.|r Exportado por %s el %s.\nLos datos de los addons marcados se |cffffcc55sustituyen|r por los "
                    .. "del texto (no se mezclan) y la interfaz se recarga.")
                    :format(tostring(pack.from or "?"), type(pack.t) == "number" and date("%d/%m/%Y %H:%M", pack.t) or "?")
            end
        end
        status:SetText(msg)
    end

    function main:SetMode(key)
        mode, self.mode = key, key
        pack, exported, err, armed, sel = nil, nil, nil, false, {}
        if key == "export" then
            for _, def in ipairs(defs) do sel[def.id] = true end
        end
        box:SetScript("OnUpdate", nil)
        pasted, count = nil, nil
        box:SetText("")
        if box.SetMaxBytes then box:SetMaxBytes(key == "import" and 2500 or 0) end
        if key == "import" then box:SetFocus() else box:ClearFocus() end
        Refresh()
    end

    function main:OnClose()   -- no dejar el texto (puede ser grande) en memoria
        pack, exported = nil, nil
        box:SetText("")
    end

    return main
end

-- Abre la ventana en mode ("export" o "import"); si ya está abierta así, la cierra
function N.ToggleData(mode)
    if not dataWin then dataWin = BuildData() end
    if dataWin:IsShown() and (not mode or mode == dataWin.mode) then
        dataWin:Hide()
        return
    end
    dataWin:SetMode(mode or dataWin.mode or "export")
    dataWin:Show()
end

---------------------------------------------------------------------------
-- Inicio (lo llama Core.lua cuando los datos guardados están cargados)
---------------------------------------------------------------------------
function N.InitUI()
    UpdateMinimapButton()
    Minimap:HookScript("OnSizeChanged", PlaceMinimap)
    C_Timer.After(1, UpdateMinimapButton)
end
