local Tr = Nexo.T
Nexo.Dict({
    ["Vuelo"] = "Flight",
    ["vuelo a |cffffffff"] = "flight to |cffffffff",
    ["unos "] = "about ",
    ["ruta sin medir, se guarda lo que tarde."] = "route not measured, it will save however long it takes.",
    [" medido: |cffffff00"] = " measured: |cffffff00",
    ["contador devuelto a su sitio."] = "counter returned to its place.",
    ["avisos en el chat "] = "chat alerts ",
    ["ruta medida"] = "route measured",
    ["rutas medidas"] = "routes measured",
    ["activados"] = "on",
    ["desactivados"] = "off",
    [". Comandos:"] = ". Commands:",
    ["mostrar/ocultar el contador para colocarlo (se arrastra con el ratón)"] = "show/hide the counter to place it (drag it with the mouse)",
    ["devolver el contador a su sitio"] = "return the counter to its place",
    ["activar/desactivar los avisos en el chat"] = "turn chat alerts on/off",
    ["mostrar/ocultar el botón del minimapa"] = "show/hide the minimap button",
    ["Arrástrame donde quieras"] = "Drag me wherever you want",
    ["a "] = "to ",
    ["En vuelo"] = "In flight",
    ["Tiempo aproximado: esta ruta aún no está medida."] = "Approximate time: this route is not measured yet.",
    ["Ruta sin medir: se guarda lo que tarde."] = "Route not measured: it will save however long it takes.",
    ["|cffffff00Arrastrar|r para mover"] = "|cffffff00Drag|r to move",
    ["estás volando: arrastra el contador para moverlo."] = "you are flying: drag the counter to move it.",
    ["arrastra el contador donde quieras. |cffffff00/vuelo|r otra vez para ocultarlo."] = "drag the counter wherever you want. |cffffff00/vuelo|r again to hide it.",
    ["sin medir"] = "not measured",
    ["Rutas medidas"] = "Routes measured",
    ["Volando a"] = "Flying to",
    ["|cffffff00Clic|r para mostrar el contador y colocarlo"] = "|cffffff00Click|r to show the counter and place it",
})
-- Vuelo: cuánto tarda cada vuelo de los maestros de vuelo
--
-- El juego no dice cuánto dura un vuelo, así que se mide: cada ruta que vuelas queda
-- guardada con lo que tardó. Para las que aún no has volado se calcula un tiempo
-- aproximado con lo que mide la ruta en el mapa de vuelo y la velocidad de los vuelos
-- ya medidos en ese continente.
local ADDON, ns = ...

local N = Nexo
local floor = math.floor
local P = "|cff73ccffVuelo:|r "
ns.P = P

local db

local function InitDB()
    VueloDB = VueloDB or {}
    db = VueloDB
    db.settings = db.settings or {}
    if db.settings.chat == nil then db.settings.chat = true end
    db.times = db.times or {}   -- [facción]["Origen>Destino"] = segundos medidos
    db.speed = db.speed or {}   -- [continente] = { d = distancia en el mapa, t = segundos } de lo medido
    ns.db = db
end

-- 200 -> "3:20"
function ns.Clock(s)
    s = floor(math.max(0, s) + 0.5)
    return ("%d:%02d"):format(floor(s / 60), s % 60)
end

-- "Trinquete, Los Baldíos" -> "Trinquete"
function ns.Place(name) return name and (name:match("^[^,]+") or name) end

---------------------------------------------------------------------------
-- Mapa de vuelo
---------------------------------------------------------------------------
local function Secret(v) return issecretvalue and issecretvalue(v) end

-- Llama a una función global del juego si existe; nil si no existe o falla
local function Call(name, ...)
    local fn = _G[name]
    if type(fn) ~= "function" then return end
    local ok, a, b = pcall(fn, ...)
    if ok and not Secret(a) then return a, b end
end

local function NodeName(slot)
    local name = slot and Call("TaxiNodeName", slot)
    if type(name) == "string" and name ~= "" then return name end
end

local function CurrentSlot()
    for i = 1, tonumber(Call("NumTaxiNodes")) or 0 do
        if Call("TaxiNodeGetType", i) == "CURRENT" then return i end
    end
end

local function Dist(ax, ay, bx, by)
    if type(ax) ~= "number" or type(ay) ~= "number" or type(bx) ~= "number" or type(by) ~= "number" then return end
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- Lo que mide la ruta hasta slot en el mapa de vuelo: tramo a tramo si el juego los da,
-- y si no en línea recta. nil si no se puede saber.
local function PathLen(slot, current)
    local hops = tonumber(Call("GetNumRoutes", slot)) or 0
    if hops > 0 and hops < 50 then
        local total = 0
        for hop = 1, hops do
            local d = Dist(Call("TaxiGetSrcX", slot, hop), Call("TaxiGetSrcY", slot, hop),
                Call("TaxiGetDestX", slot, hop), Call("TaxiGetDestY", slot, hop))
            if not d then total = nil break end
            total = total + d
        end
        if total and total > 0 then return total end
    end
    if not current then return end
    local ax, ay = Call("TaxiNodePosition", current)
    local bx, by = Call("TaxiNodePosition", slot)
    local d = Dist(ax, ay, bx, by)
    if d and d > 0 then return d end
end

-- Continente en el que está el personaje: la escala del mapa de vuelo cambia de uno a otro
local function Continent()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then return 0 end
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    local continent = Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2
    for _ = 1, 10 do
        if not ok or type(id) ~= "number" or id == 0 then break end
        local ok2, info = pcall(C_Map.GetMapInfo, id)
        if not ok2 or type(info) ~= "table" then break end
        if info.mapType == continent then return id end
        id = info.parentMapID
    end
    return 0
end

-- Segundos por unidad del mapa de vuelo cuando aún no hay ningún vuelo medido en el
-- continente: una cuenta gruesa con su tamaño y la velocidad de los grifos, que deja de
-- usarse en cuanto se mide el primer vuelo.
local SPEED = 30     -- yardas por segundo
local CURVE = 1.3    -- lo que se alarga la ruta real sobre la línea del mapa
local MAP_PART = 0.8 -- parte del alto del continente que cubre el mapa de vuelo
local function DefaultPace(cont)
    if cont == 0 or not (C_Map and C_Map.GetMapWorldSize) then return end
    local ok, w, h = pcall(C_Map.GetMapWorldSize, cont)
    if ok and type(h) == "number" and h > 0 then return h * MAP_PART * CURVE / SPEED end
end

local function Times()
    local faction = UnitFactionGroup and UnitFactionGroup("player") or "?"
    db.times[faction] = db.times[faction] or {}
    return db.times[faction]
end

-- Rutas medidas por la facción de este personaje
function ns.RouteCount()
    local n = 0
    for _ in pairs(Times()) do n = n + 1 end
    return n
end

-- Vuelo desde donde estás hasta la casilla slot del mapa de vuelo (que tiene que estar abierto):
-- { from, to, est = segundos o nil, exact = true si est es un tiempo medido, len, cont }
function ns.Route(slot)
    local current = CurrentSlot()
    local r = { from = NodeName(current), to = NodeName(slot), len = PathLen(slot, current), cont = Continent() }
    local times = Times()
    if r.from and r.to then
        r.est = times[r.from .. ">" .. r.to]
        if r.est then
            r.exact = true
            return r
        end
        r.est = times[r.to .. ">" .. r.from]   -- la vuelta suele tardar parecido
    end
    if not r.est and r.len then
        local sp = db.speed[r.cont]
        local pace = sp and sp.t > 0 and sp.d > 0 and sp.t / sp.d or DefaultPace(r.cont)
        if pace then r.est = r.len * pace end
    end
    if not r.est then
        -- sin nada del mapa con qué calcularla: lo que de media tardan tus vuelos medidos
        local sum, n = 0, 0
        for _, t in pairs(times) do sum, n = sum + t, n + 1 end
        if n > 0 then r.est = sum / n end
    end
    return r
end

---------------------------------------------------------------------------
-- Seguimiento del vuelo
---------------------------------------------------------------------------
local pending   -- vuelo elegido en el mapa que aún no ha despegado
-- ns.flight = vuelo en curso: lo de ns.Route más start (GetTime() al despegar)

local function Changed()
    if ns.OnFlightChanged then ns.OnFlightChanged() end
end

local function TakeOff(f, start)
    f.start = start or GetTime()
    ns.flight = f
    -- por si se recarga la interfaz en pleno vuelo
    db.flying = { from = f.from, to = f.to, est = f.est, exact = f.exact, len = f.len, cont = f.cont,
        at = time() - floor(GetTime() - f.start) }
    if db.settings.chat and not start and f.to then
        local where = Tr("vuelo a |cffffffff") .. ns.Place(f.to) .. "|r: "
        if f.est then
            print(P .. where .. (f.exact and "" or Tr("unos ")) .. "|cffffff00" .. ns.Clock(f.est) .. "|r min.")
        else
            print(P .. where .. Tr("ruta sin medir, se guarda lo que tarde."))
        end
    end
    Changed()
end

local function Land()
    local f = ns.flight
    ns.flight, db.flying = nil, nil
    local took = GetTime() - f.start
    if f.from and f.to and took >= 5 then
        Times()[f.from .. ">" .. f.to] = floor(took + 0.5)
        if f.len and f.cont and not f.exact then
            local sp = db.speed[f.cont] or { d = 0, t = 0 }
            db.speed[f.cont] = sp
            sp.d, sp.t = sp.d + f.len, sp.t + took
        end
        if db.settings.chat and not f.exact then
            print(P .. ns.Place(f.from) .. " > " .. ns.Place(f.to) .. Tr(" medido: |cffffff00") .. ns.Clock(took) .. "|r min.")
        end
    end
    Changed()
end

local function OnTaxi() return UnitOnTaxi and UnitOnTaxi("player") and true or false end

local watch = CreateFrame("Frame")
local wait = 0
watch:SetScript("OnUpdate", function(_, el)
    wait = wait - el
    if wait > 0 then return end
    wait = 0.2
    if not db then return end
    local flying = OnTaxi()
    if ns.flight then
        if not flying then Land() end
    elseif flying then
        -- sin vuelo elegido en el mapa (un vuelo de misión, por ejemplo): solo se cuenta el tiempo
        TakeOff(pending or {})
        pending = nil
    elseif pending and GetTime() - pending.at > 20 then
        pending = nil   -- no llegó a despegar
    end
end)

local function OnTakeNode(slot)
    if not db or ns.flight then return end
    pending = ns.Route(slot)
    pending.at = GetTime()
end

-- Al entrar o recargar en pleno vuelo, sigue con el que había
local function Resume()
    local saved = db.flying
    db.flying = nil
    if ns.flight or not OnTaxi() or type(saved) ~= "table" then return end
    local gone = time() - (saved.at or 0)
    if gone < 0 or gone > 1800 then return end
    saved.at = nil
    TakeOff(saved, GetTime() - gone)
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then
            InitDB()
            if _G.TakeTaxiNode then hooksecurefunc("TakeTaxiNode", OnTakeNode) end
            if ns.OnInit then ns.OnInit() end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        Resume()
    end
end)
N.Reg(ev, "ADDON_LOADED", "PLAYER_ENTERING_WORLD")

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
SLASH_VUELO1 = "/vuelo"
SlashCmdList.VUELO = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local Cmd = function(k) return N.Cmd("vuelo", k) end
    if msg == Cmd("center") then
        ns.ResetPos()
        print(P .. Tr("contador devuelto a su sitio."))
    elseif msg == Cmd("chat") then
        db.settings.chat = not db.settings.chat
        print(P .. Tr("avisos en el chat ") .. (db.settings.chat and Tr("activados") or Tr("desactivados")) .. ".")
    elseif msg == Cmd("minimap") then
        print(P .. Tr("botón del minimapa (compartido, Nexo) ") .. (N.ToggleMinimap() and Tr("oculto") or Tr("visible")) .. ".")
    elseif msg == Cmd("help") then
        print(P .. N.Plural(ns.RouteCount(), Tr("ruta medida"), Tr("rutas medidas")) .. Tr(". Comandos:"))
        print("  |cffffff00/vuelo|r - " .. Tr("mostrar/ocultar el contador para colocarlo (se arrastra con el ratón)"))
        print("  |cffffff00/vuelo " .. Cmd("center") .. "|r - " .. Tr("devolver el contador a su sitio"))
        print("  |cffffff00/vuelo " .. Cmd("chat") .. "|r - " .. Tr("activar/desactivar los avisos en el chat"))
        print("  |cffffff00/vuelo " .. Cmd("minimap") .. "|r - " .. Tr("mostrar/ocultar el botón del minimapa"))
    else
        ns.Toggle()
    end
end
