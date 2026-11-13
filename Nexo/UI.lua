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
    local K = { acc = acc, Text = Text, Tex = Tex }

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
        main:EnableMouse(true)
        main:SetMovable(true)
        main:SetClampedToScreen(true)
        main:RegisterForDrag("LeftButton")
        main:SetScript("OnDragStart", main.StartMoving)
        main:SetScript("OnDragStop", function(s)
            s:StopMovingOrSizing()
            local settings = o.settings and o.settings()
            if settings then
                local p, _, rp, x, y = s:GetPoint()
                settings.pos = { p, rp, x, y }
            end
        end)
        main:Hide()
        tinsert(UISpecialFrames, o.name)

        function main:RestorePos()
            local settings = o.settings and o.settings()
            local pos = settings and settings.pos
            if pos then
                self:ClearAllPoints()
                self:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
            end
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
        return b
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

    return K
end

---------------------------------------------------------------------------
-- Registro de addons y botón único del minimapa
--
-- def = { id, name, icon, color = {r, g, b}, slash = "/comando",
--         toggle = function() end,                 -- abrir/cerrar su ventana
--         tooltip = function(owner, anchor) end }  -- resumen al pasar el ratón
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

local function ShowMenu()
    for i, def in ipairs(addons) do
        local r = MenuRow(i)
        r.def = def
        r.icon:SetTexture(def.icon)
        r.name:SetText(def.name)
        local c = def.color or { 1, 1, 1 }
        r.name:SetTextColor(c[1], c[2], c[3])
        r:Show()
    end
    for i = #addons + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(MENU_W, #addons * ROW_H + 8)
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
-- Inicio (lo llama Core.lua cuando los datos guardados están cargados)
---------------------------------------------------------------------------
function N.InitUI()
    UpdateMinimapButton()
    Minimap:HookScript("OnSizeChanged", PlaceMinimap)
    C_Timer.After(1, UpdateMinimapButton)
end
