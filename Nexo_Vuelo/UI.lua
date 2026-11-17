local Tr = Nexo.T
-- Vuelo: contador en pantalla y tiempo de cada destino en el mapa de vuelo
local ADDON, ns = ...

local N = Nexo
local ACC = { 0.45, 0.80, 1.00 }
local ICON = "Interface\\Icons\\Ability_Mount_Gryphon_01"
local W, H = 176, 48

local K = N.Kit({
    acc = ACC,
    panelBg = { 0.05, 0.07, 0.10, 0.88 }, panelBorder = { 0.20, 0.34, 0.46, 1 },
    btnOn = { 0.10, 0.26, 0.38 }, btnOnText = { 0.80, 0.93, 1 },
    btnOff = { 0.10, 0.12, 0.15 }, btnBorder = { 0.20, 0.30, 0.40 }, btnHover = { 0.40, 0.70, 0.95 },
    winBg = { 0.03, 0.04, 0.06 }, winBorder = { 0.25, 0.50, 0.70 },
    headBg = { 0.05, 0.12, 0.18 }, sub = { 0.55, 0.68, 0.78 },
    closeBg = { 0.06, 0.10, 0.14 }, closeBorder = { 0.20, 0.36, 0.50 }, closeX = { 0.75, 0.88, 0.96 },
})

---------------------------------------------------------------------------
-- Contador
---------------------------------------------------------------------------
local box = K.Panel(UIParent)
box:SetSize(W, H)
box:SetPoint("TOP", 0, -150)
box:SetFrameStrata("MEDIUM")
box:Hide()
N.Movable(box, function() return ns.db and ns.db.settings end)

local icon = box:CreateTexture(nil, "ARTWORK")
icon:SetTexture(ICON)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
icon:SetSize(30, 30)
icon:SetPoint("LEFT", 8, 2)

local label = K.Text(box, 11)
label:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 2)
label:SetPoint("RIGHT", -8, 0)
label:SetJustifyH("LEFT")
label:SetWordWrap(false)
label:SetTextColor(0.62, 0.74, 0.84)

local clock = K.Text(box, 20, "GameFontNormalLarge")
clock:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, -3)
clock:SetTextColor(1, 1, 1)

local barBg = K.Tex(box, "ARTWORK", 0, 0, 0, 0.5)
barBg:SetHeight(3)
barBg:SetPoint("BOTTOMLEFT", 1, 1)
barBg:SetPoint("BOTTOMRIGHT", -1, 1)
local bar = K.Tex(box, "OVERLAY", ACC[1], ACC[2], ACC[3], 1)
bar:SetHeight(3)
bar:SetPoint("BOTTOMLEFT", 1, 1)

local demo = false

local function Paint()
    local f = ns.flight
    if not f then
        -- de muestra, para colocarlo
        label:SetText(Tr("Arrástrame donde quieras"))
        clock:SetText("2:30")
        bar:SetWidth((W - 2) * 0.4)
        bar:Show()
        return
    end
    local gone = GetTime() - f.start
    label:SetText(f.to and (Tr("a ") .. ns.Place(f.to)) or Tr("En vuelo"))
    if not f.est then
        -- ruta sin medir y sin nada con qué calcularla: no se sabe cuánto falta
        clock:SetText("|cffaab4be--:--|r")
        bar:Hide()
        return
    end
    -- cuenta lo que falta, y la barra se vacía al acercarse a la llegada
    local left = f.est - gone
    if left > 0 then
        clock:SetText((f.exact and "" or "|cffaab4be~|r") .. ns.Clock(math.ceil(left)))
    else
        clock:SetText("|cffaab4beLlegando|r")
    end
    bar:SetWidth(math.max(1, (W - 2) * math.min(1, math.max(0, left) / f.est)))
    bar:Show()
end

local wait = 0
box:SetScript("OnUpdate", function(_, el)
    wait = wait - el
    if wait > 0 then return end
    wait = 0.1
    Paint()
end)

box:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Vuelo", ACC[1], ACC[2], ACC[3])
    local f = ns.flight
    if f and f.est and not f.exact then
        GameTooltip:AddLine(Tr("Tiempo aproximado: esta ruta aún no está medida."), 0.8, 0.8, 0.8)
    elseif f and not f.est then
        GameTooltip:AddLine(Tr("Ruta sin medir: se guarda lo que tarde."), 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine(Tr("|cffffff00Arrastrar|r para mover"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
box:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function Refresh()
    if ns.flight or demo then
        wait = 0
        box:Show()
    else
        box:Hide()
    end
end

function ns.OnFlightChanged()
    if ns.flight then demo = false end   -- al despegar deja de ser la muestra
    Refresh()
end

-- Muestra u oculta el contador de muestra, para colocarlo sin estar volando
function ns.Toggle()
    if ns.flight then
        print(ns.P .. Tr("estás volando: arrastra el contador para moverlo."))
        return
    end
    demo = not demo
    Refresh()
    if demo then print(ns.P .. Tr("arrastra el contador donde quieras. |cffffff00/vuelo|r otra vez para ocultarlo.")) end
end

function ns.ResetPos()
    ns.db.settings.pos = nil
    box:ClearAllPoints()
    box:SetPoint("TOP", 0, -150)
end

---------------------------------------------------------------------------
-- Tiempo de cada destino en el mapa de vuelo
---------------------------------------------------------------------------
local function AddTime(slot)
    if not ns.db or not slot or GameTooltip:IsForbidden() then return end
    local r = ns.Route(slot)
    if r.exact then
        GameTooltip:AddDoubleLine("Vuelo", ns.Clock(r.est) .. " min", ACC[1], ACC[2], ACC[3], 1, 1, 1)
    elseif r.est then
        GameTooltip:AddDoubleLine("Vuelo", Tr("unos ") .. ns.Clock(r.est) .. " min", ACC[1], ACC[2], ACC[3], 0.8, 0.8, 0.8)
    else
        GameTooltip:AddDoubleLine("Vuelo", Tr("sin medir"), ACC[1], ACC[2], ACC[3], 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local hooked = {}
local function HookMap()
    -- mapa de vuelo clásico
    if not hooked.classic and _G.TaxiNodeOnButtonEnter then
        hooked.classic = true
        hooksecurefunc("TaxiNodeOnButtonEnter", function(button)
            local slot = button and button.GetID and button:GetID()
            if slot and TaxiNodeGetType and TaxiNodeGetType(slot) == "REACHABLE" then AddTime(slot) end
        end)
    end
    -- mapa de vuelo moderno (se carga la primera vez que se abre)
    local pin = _G.FlightMap_FlightPointPinMixin
    if not hooked.modern and pin and pin.OnMouseEnter then
        hooked.modern = true
        hooksecurefunc(pin, "OnMouseEnter", function(self)
            local d = self.taxiNodeData
            local reachable = Enum and Enum.FlightPathState and Enum.FlightPathState.Reachable
            if d and d.slotIndex and d.state == reachable then AddTime(d.slotIndex) end
        end)
    end
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", HookMap)
N.Reg(ev, "ADDON_LOADED", "TAXIMAP_OPENED")

---------------------------------------------------------------------------
-- Minimapa y menú de complementos
---------------------------------------------------------------------------
local function ShowSummaryTooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    GameTooltip:AddLine("Vuelo", ACC[1], ACC[2], ACC[3])
    GameTooltip:AddDoubleLine(Tr("Rutas medidas"), ns.RouteCount(), 0.8, 0.8, 0.8, 1, 1, 1)
    local f = ns.flight
    if f and f.to then GameTooltip:AddDoubleLine(Tr("Volando a"), ns.Place(f.to), 0.8, 0.8, 0.8, 1, 1, 1) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(Tr("|cffffff00Clic|r para mostrar el contador y colocarlo"), 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

N.Register({
    id = "Vuelo", name = Tr("Vuelo"), icon = ICON, color = ACC, slash = "/vuelo",
    toggle = function() ns.Toggle() end,
    tooltip = ShowSummaryTooltip,
    data = "VueloDB",
})

function Vuelo_OnCompartmentClick() ns.Toggle() end
function Vuelo_OnCompartmentEnter(_, button) ShowSummaryTooltip(button or UIParent, "ANCHOR_LEFT") end
function Vuelo_OnCompartmentLeave() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Inicio
---------------------------------------------------------------------------
function ns.OnInit()
    box:RestorePos()
    HookMap()
end
