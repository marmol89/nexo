Nexo.Dict({
    ["Cosecha"] = "Harvest",
    ["abrir/cerrar la ventana"] = "open/close the window",
    ["abrir buscando ese texto"] = "open searching for that text",
    ["mostrar/ocultar los puntos en el mapa del mundo"] = "show/hide the points on the world map",
    ["mostrar/ocultar el botón del minimapa"] = "show/hide the minimap button",
    ["esto borrará TODO lo recolectado. Escribe "] = "this will delete ALL the gathered data. Type ",
    [" para hacerlo."] = " to do it.",
    ["todo lo recolectado borrado."] = "all the gathered data deleted.",
    ["borrar todo lo recolectado"] = "delete all the gathered data",
})
-- Cosecha: minerales, hierbas y demás nodos de recolección, con dónde los encontraste
--
-- El juego no dice qué hay en un nodo de minería o herboristería hasta que lo recolectas, así
-- que Cosecha apunta el objeto que sale y la posición del personaje en ese momento: justo
-- después de terminar de minar o de recolectar una hierba (el hechizo correspondiente tiene
-- éxito), se mira qué cae en el botín que se abre a continuación. La siguiente vez que pases
-- por la zona, esos puntos salen en el mapa del mundo (ver Nexo_Cosecha/UI.lua) y se pueden
-- buscar por nombre en la ventana.
local ADDON, ns = ...

local N = Nexo
local Tr = N.T

-- Hechizos con los que se recolecta un nodo: son los mismos en cualquier expansión
local MINING, HERBALISM = 2575, 2366

---------------------------------------------------------------------------
-- Base de datos
---------------------------------------------------------------------------
local db

-- Dos puntos a menos de esto (en el mapa, de 0 a 1) se cuentan como el mismo nodo
local GRID = 0.0025
-- Puntos guardados por objeto y mapa; al pasar de aquí se descarta el que hace más que no se ve
local MAX_POINTS = 60

local function InitDB()
    CosechaDB = CosechaDB or {}
    db = CosechaDB
    db.items = db.items or {}      -- caché: [itemID] = { n, q, i } (Nexo.CacheItem)
    db.maps = db.maps or {}        -- [mapID][itemID] = { points = { [clave] = {x, y, n = veces, t = última vez} } }
    db.settings = db.settings or {}
    if db.settings.map == nil then db.settings.map = true end
    ns.db = db
end

local function PointKey(x, y)
    return math.floor(x / GRID + 0.5) .. ":" .. math.floor(y / GRID + 0.5)
end

-- Apunta que acabas de recolectar el objeto id (con su enlace, si lo hay) en (mapID, x, y)
local function Remember(mapID, x, y, id, link)
    Nexo.CacheItem(db.items, id, link)
    local map = db.maps[mapID]
    if not map then map = {}; db.maps[mapID] = map end
    local e = map[id]
    if not e then e = { points = {} }; map[id] = e end

    local key = PointKey(x, y)
    local p = e.points[key]
    if not p then p = { x = x, y = y, n = 0 }; e.points[key] = p end
    p.n, p.t = p.n + 1, time()

    -- demasiados puntos de este objeto en este mapa: fuera el que hace más que no se ve
    local count, oldestKey, oldestT
    for k, pt in pairs(e.points) do
        count = (count or 0) + 1
        if not oldestT or pt.t < oldestT then oldestKey, oldestT = k, pt.t end
    end
    if count and count > MAX_POINTS and oldestKey ~= key then e.points[oldestKey] = nil end
    if ns.OnDataChanged then ns.OnDataChanged() end
end

-- Objetos recolectados: { id, name, lower, icon, q, total, zones = nº de mapas distintos }
function ns.List()
    local totals, zones = {}, {}
    for _, map in pairs(db.maps) do
        for id, e in pairs(map) do
            local t = 0
            for _, p in pairs(e.points) do t = t + p.n end
            totals[id] = (totals[id] or 0) + t
            zones[id] = (zones[id] or 0) + 1
        end
    end
    local list = {}
    for id, it in pairs(db.items) do
        if totals[id] then
            local name = it.n or (Tr("Objeto ") .. id)
            list[#list + 1] = { id = id, name = name, lower = name:lower(), icon = it.i, q = it.q,
                total = totals[id], zones = zones[id] }
        end
    end
    return list
end

-- Mapas donde se ha visto el objeto id: { { mapID, points = veces, spots = nº de sitios, last = hora }, ... },
-- del más visto al menos visto
function ns.Zones(id)
    local out = {}
    for mapID, map in pairs(db.maps) do
        local e = map[id]
        if e then
            local points, spots, last = 0, 0, nil
            for _, p in pairs(e.points) do
                points, spots = points + p.n, spots + 1
                if not last or p.t > last then last = p.t end
            end
            out[#out + 1] = { mapID = mapID, points = points, spots = spots, last = last }
        end
    end
    table.sort(out, function(a, b) return a.points > b.points end)
    return out
end

---------------------------------------------------------------------------
-- Detectar la recolección: hechizo de minería/herboristería con éxito -> botín que se abre
-- justo después. GetTime() (no time(), que es en segundos reales) porque lo que importa es
-- lo poco que tardan los dos eventos en llegar, no la hora del reloj.
---------------------------------------------------------------------------
local pending   -- { mapID, x, y, t } mientras se espera el botín de un nodo recién recolectado

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then
            InitDB()
            if ns.OnInit then ns.OnInit() end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" and (spellID == MINING or spellID == HERBALISM) then
            local mapID, x, y = N.PlayerMapPos()
            pending = mapID and { mapID = mapID, x = x, y = y, t = GetTime() } or nil
        end
    elseif event == "LOOT_OPENED" then
        if pending and GetTime() - pending.t < 5 and GetNumLootItems and GetLootSlotLink then
            for slot = 1, GetNumLootItems() do
                local link = GetLootSlotLink(slot)
                local id = Nexo.ItemID(link)
                if id then Remember(pending.mapID, pending.x, pending.y, id, link) end
            end
        end
        pending = nil
    end
end)
N.Reg(ev, "ADDON_LOADED", "UNIT_SPELLCAST_SUCCEEDED", "LOOT_OPENED")

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
SLASH_COSECHA1 = "/cosecha"
SlashCmdList.COSECHA = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local low = msg:lower()
    local P = "|cff9fd45cCosecha:|r "
    local Cmd = function(k) return N.Cmd("cosecha", k) end
    if low == Cmd("map") then
        db.settings.map = not db.settings.map
        print(P .. Tr("puntos en el mapa ") .. (db.settings.map and Tr("activados") or Tr("desactivados")) .. ".")
        if ns.RefreshMapPins then ns.RefreshMapPins() end
    elseif low == Cmd("minimap") then
        print(P .. Tr("botón del minimapa (compartido, Nexo) ") .. (N.ToggleMinimap() and Tr("oculto") or Tr("visible")) .. ".")
    elseif low == Cmd("resetConfirm") then
        db.items, db.maps = {}, {}
        print(P .. Tr("todo lo recolectado borrado."))
        if ns.Refresh then ns.Refresh() end
        if ns.RefreshMapPins then ns.RefreshMapPins() end
    elseif low == Cmd("reset") then
        print(P .. Tr("esto borrará TODO lo recolectado. Escribe ") .. "|cffffff00/cosecha " .. Cmd("resetConfirm") .. "|r" .. Tr(" para hacerlo."))
    elseif low == Cmd("help") then
        print(P .. Tr("comandos:"))
        print("  |cffffff00/cosecha|r - " .. Tr("abrir/cerrar la ventana"))
        print("  |cffffff00/cosecha <texto>|r - " .. Tr("abrir buscando ese texto"))
        print("  |cffffff00/cosecha " .. Cmd("map") .. "|r - " .. Tr("mostrar/ocultar los puntos en el mapa del mundo"))
        print("  |cffffff00/cosecha " .. Cmd("minimap") .. "|r - " .. Tr("mostrar/ocultar el botón del minimapa"))
        print("  |cffffff00/cosecha " .. Cmd("reset") .. "|r - " .. Tr("borrar todo lo recolectado"))
    elseif msg ~= "" then
        if ns.OpenSearch then ns.OpenSearch(msg) end
    else
        if ns.Toggle then ns.Toggle() end
    end
end
