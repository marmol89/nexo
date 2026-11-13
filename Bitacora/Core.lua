-- Bitácora: registro del tiempo de juego
local ADDON, ns = ...
local N = Nexo

local floor = math.floor
local DAY = 86400
local RESUME_GAP = 180    -- si vuelves antes de esto (p. ej. /reload), sigue la misma sesión
local MIN_SESSION = 60    -- las sesiones más cortas no se guardan
local MAX_SESSIONS = 600  -- sesiones guardadas por personaje (los totales por día nunca se pierden)
local TRIM_TO = 500

---------------------------------------------------------------------------
-- Formato y fechas: los del núcleo
---------------------------------------------------------------------------
ns.Dur, ns.DayKey, ns.DayKeyToTime, ns.MidnightDaysAgo = N.Dur, N.DayKey, N.DayKeyToTime, N.MidnightDaysAgo
local DayKey = N.DayKey

-- Número de día correlativo (para calcular rachas sin líos de cambio de hora)
local function DayNum(dk)
    local y, m, d = dk:match("(%d+)-(%d+)-(%d+)")
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if m <= 2 then y, m = y - 1, m + 12 end
    return 365 * y + floor(y / 4) - floor(y / 100) + floor(y / 400) + floor((153 * (m - 3) + 2) / 5) + d
end

---------------------------------------------------------------------------
-- Base de datos
---------------------------------------------------------------------------
local db, char, charKey
local session            -- sesión en curso (es también la última entrada de char.sessions)
local zoneTime = {}      -- segundos por zona en esta sesión

local function InitDB()
    BitacoraDB = BitacoraDB or {}
    db = BitacoraDB
    db.chars = db.chars or {}
    db.settings = db.settings or {}
    db.settings.period = db.settings.period or "week"

    char, charKey = N.InitChar(db.chars, { days = {}, sessions = {}, firstSeen = time() })
    -- desde cuándo se mide de verdad este personaje (lo anterior solo puede estimarse)
    if not char.tracked then
        char.tracked = char.fromImport and time() or (char.firstSeen or time())
    end
    ns.db, ns.char, ns.charKey = db, char, charKey
end

local function CurrentZone()
    local z = GetRealZoneText()
    if not z or z == "" then z = "Desconocido" end
    return z
end

local function StartSession()
    local now = time()
    local ss = char.sessions
    local last = ss[#ss]
    zoneTime = {}
    if last and not last.est and now >= last.s and (now - (last.s + last.d)) <= RESUME_GAP then
        session = last
    else
        if last and last.d < MIN_SESSION then ss[#ss] = nil end
        local lvl = UnitLevel("player")
        session = { s = now, d = 0, a = 0, l0 = lvl, l1 = lvl, z = CurrentZone() }
        ss[#ss + 1] = session
        if #ss > MAX_SESSIONS then
            local keep = {}
            for i = #ss - TRIM_TO + 1, #ss do keep[#keep + 1] = ss[i] end
            char.sessions = keep
        end
    end
    ns.session = session
end

-- El núcleo avisa cada pocos segundos con el tiempo de juego transcurrido
local function Tick(dt, now)
    if not session then return end

    local day = char.days[DayKey(now)]
    if not day then
        day = { t = 0, a = 0, z = {} }
        char.days[DayKey(now)] = day
    end
    local zone = CurrentZone()
    day.t = day.t + dt
    day.z[zone] = (day.z[zone] or 0) + dt
    session.d = session.d + dt
    if UnitIsAFK and UnitIsAFK("player") then
        day.a = day.a + dt
        session.a = session.a + dt
    end

    zoneTime[zone] = (zoneTime[zone] or 0) + dt
    if zoneTime[zone] >= (zoneTime[session.z] or 0) then session.z = zone end

    if char.played then
        char.played = char.played + dt
        char.playedLevel = (char.playedLevel or 0) + dt
    end
    char.lastSeen = now
end

---------------------------------------------------------------------------
-- Historial anterior, estimado a partir de Tesorero
--
-- Tesorero guarda cada movimiento de oro con su hora y su zona. Los movimientos
-- cercanos entre sí se agrupan en una sesión estimada (del primero al último).
-- Solo se usa lo anterior a que Bitácora empezara a medir ese personaje.
---------------------------------------------------------------------------
local EST_GAP = 1800   -- más de 30 min sin movimientos = otra sesión
local EST_MIN = 300    -- duración mínima que se da a una sesión estimada

local function AddEstimatedSpan(c, s, d, zone)
    while d > 0 do
        local dt = date("*t", s)
        local nextMidnight = time({ year = dt.year, month = dt.month, day = dt.day, hour = 0, min = 0, sec = 0 }) + DAY
        local chunk = math.min(d, math.max(1, nextMidnight - s))
        local dk = DayKey(s)
        local day = c.days[dk]
        if not day then
            day = { t = 0, a = 0, z = {} }
            c.days[dk] = day
        end
        day.e = (day.e or 0) + chunk
        day.ez = day.ez or {}
        day.t = day.t + chunk
        day.z[zone] = (day.z[zone] or 0) + chunk
        day.ez[zone] = (day.ez[zone] or 0) + chunk
        s, d = s + chunk, d - chunk
    end
end

-- Devuelve cuántas sesiones estimadas se han añadido, o nil si Tesorero no está
function ns.ImportTesorero()
    local src = _G.TesoreroDB
    if type(src) ~= "table" or type(src.chars) ~= "table" then return nil end
    local added = 0
    for key, tc in pairs(src.chars) do
        local c = db.chars[key]
        local cutoff = c and c.tracked or math.huge
        local from = c and c.imp or 0
        local list = {}
        if type(tc.tx) == "table" then
            for _, e in ipairs(tc.tx) do
                local t = e[1]
                if type(t) == "number" and t > from and t < cutoff then
                    local zone = e[4]
                    if type(zone) ~= "string" or zone == "" then zone = "Desconocido" end
                    list[#list + 1] = { t = t, z = zone }
                end
            end
        end
        if #list > 0 then
            table.sort(list, function(a, b) return a.t < b.t end)
            if not c then
                c = {
                    days = {}, sessions = {}, firstSeen = list[1].t, fromImport = true,
                    name = tc.name, class = tc.class, level = tc.level,
                }
                db.chars[key] = c
            end
            local first = 1
            for i = 1, #list do
                if i == #list or list[i + 1].t - list[i].t > EST_GAP then
                    local s = list[first].t
                    local d = list[i].t - s
                    local zsec = {}
                    for j = first, i - 1 do
                        local span = list[j + 1].t - list[j].t
                        if span > 0 then
                            AddEstimatedSpan(c, list[j].t, span, list[j].z)
                            zsec[list[j].z] = (zsec[list[j].z] or 0) + span
                        end
                    end
                    if d < EST_MIN then
                        local pad = EST_MIN - d
                        AddEstimatedSpan(c, list[i].t, pad, list[i].z)
                        zsec[list[i].z] = (zsec[list[i].z] or 0) + pad
                        d = EST_MIN
                    end
                    local best, bestSec = list[first].z, -1
                    for zone, sec in pairs(zsec) do
                        if sec > bestSec then best, bestSec = zone, sec end
                    end
                    c.sessions[#c.sessions + 1] = { s = s, d = d, a = 0, z = best, est = true }
                    added = added + 1
                    first = i + 1
                end
            end
            c.imp = list[#list].t
            table.sort(c.sessions, function(a, b) return a.s < b.s end)
        end
    end
    return added
end

-- Quita todo lo estimado y deja solo lo medido de verdad
function ns.RemoveEstimated()
    local removed = 0
    for key, c in pairs(db.chars) do
        local keep = {}
        for _, e in ipairs(c.sessions) do
            if e.est then removed = removed + 1 else keep[#keep + 1] = e end
        end
        c.sessions = keep
        for dk, day in pairs(c.days) do
            if day.e then
                day.t = day.t - day.e
                for zone, sec in pairs(day.ez or {}) do
                    local left = (day.z[zone] or 0) - sec
                    day.z[zone] = left > 0 and left or nil
                end
                day.e, day.ez = nil, nil
                if day.t <= 0 then c.days[dk] = nil end
            end
        end
        c.imp = nil
        if c.fromImport and not c.tracked then db.chars[key] = nil end
    end
    return removed
end

---------------------------------------------------------------------------
-- Reloj y /played real: los da el núcleo
---------------------------------------------------------------------------
N.OnTick(Tick)

N.OnPlayed(function(total, level)
    if not char then return end
    char.played, char.playedLevel = total, level or 0
    if ns.Refresh then ns.Refresh() end
end)

---------------------------------------------------------------------------
-- Agregados para la interfaz
---------------------------------------------------------------------------
local PERIOD_DAYS = N.PERIOD_DAYS
ns.PERIODS = N.PERIODS

function ns.CharList() return N.Keys(db.chars) end

local function EachChar(filter, fn) N.EachChar(db.chars, filter, fn) end

-- Conjunto de días válidos del periodo (nil = todos)
local function ValidDays(period)
    if period == "all" then return nil end
    local v = {}
    for n = 0, PERIOD_DAYS[period] - 1 do v[DayKey(time() - n * DAY)] = true end
    return v
end

local function TrackedTotal(c)
    local sum = 0
    for _, day in pairs(c.days) do sum = sum + day.t end
    return sum
end

-- Tiempo total (el /played real si se conoce; si no, lo registrado), nº de personajes, tiempo en el nivel
function ns.TotalPlayed(filter)
    local sum, n, lvl = 0, 0, 0
    EachChar(filter, function(c)
        sum = sum + (c.played or TrackedTotal(c))
        lvl = lvl + (c.playedLevel or 0)
        n = n + 1
    end)
    return sum, n, lvl
end

-- Resumen del periodo: total, AFK, días jugados, mejor día, día de la semana favorito y rachas
function ns.Summary(filter, period)
    local valid = ValidDays(period)
    local byDay, played = {}, {}
    EachChar(filter, function(c)
        for dk, day in pairs(c.days) do
            if day.t > 0 then played[dk] = true end
            if not valid or valid[dk] then
                local e = byDay[dk] or { t = 0, a = 0 }; byDay[dk] = e
                e.t, e.a = e.t + day.t, e.a + day.a
            end
        end
    end)

    local r = { total = 0, afk = 0, days = 0, bestT = 0, weekdayT = 0, streak = 0, bestStreak = 0 }
    local wd = {}
    for dk, e in pairs(byDay) do
        if e.t > 0 then
            r.total, r.afk, r.days = r.total + e.t, r.afk + e.a, r.days + 1
            if e.t > r.bestT then r.bestT, r.bestDay = e.t, dk end
            local w = tonumber(date("%w", ns.DayKeyToTime(dk))) + 1
            wd[w] = (wd[w] or 0) + e.t
        end
    end
    for w, t in pairs(wd) do
        if t > r.weekdayT then r.weekdayT, r.weekday = t, w end
    end

    -- Rachas de días seguidos (sobre todo el historial, no solo el periodo)
    local nums, has = {}, {}
    for dk in pairs(played) do
        local n = DayNum(dk)
        nums[#nums + 1] = n
        has[n] = true
    end
    table.sort(nums)
    local run = 0
    for i, n in ipairs(nums) do
        run = (i > 1 and nums[i - 1] == n - 1) and run + 1 or 1
        if run > r.bestStreak then r.bestStreak = run end
    end
    local d = DayNum(DayKey())
    if not has[d] then d = d - 1 end
    while has[d] do
        r.streak = r.streak + 1
        d = d - 1
    end
    return r
end

-- Serie diaria de los últimos n días (antiguo -> reciente)
function ns.DailySeries(filter, n)
    local series = {}
    for i = n - 1, 0, -1 do
        local t = time() - i * DAY
        local dk = DayKey(t)
        local e = { t = t, s = 0, a = 0, est = 0 }
        EachChar(filter, function(c)
            local day = c.days[dk]
            if day then e.s, e.a, e.est = e.s + day.t, e.a + day.a, e.est + (day.e or 0) end
        end)
        series[#series + 1] = e
    end
    return series
end

-- Tiempo por zona en el periodo, de mayor a menor
function ns.Zones(filter, period)
    local valid = ValidDays(period)
    local sum = {}
    EachChar(filter, function(c)
        for dk, day in pairs(c.days) do
            if (not valid or valid[dk]) and day.z then
                for zone, s in pairs(day.z) do sum[zone] = (sum[zone] or 0) + s end
            end
        end
    end)
    local list = {}
    for zone, s in pairs(sum) do list[#list + 1] = { name = zone, sec = s } end
    table.sort(list, function(a, b) return a.sec > b.sec end)
    return list
end

-- Tiempo por personaje en el periodo, de mayor a menor
function ns.CharRanking(period)
    local valid = ValidDays(period)
    local list = {}
    for k, c in pairs(db.chars) do
        local s = 0
        for dk, day in pairs(c.days) do
            if not valid or valid[dk] then s = s + day.t end
        end
        if s > 0 then
            list[#list + 1] = { key = k, name = c.name or k, class = c.class, level = c.level, sec = s }
        end
    end
    table.sort(list, function(a, b) return a.sec > b.sec end)
    return list
end

-- Sesiones del periodo, de la más reciente a la más antigua
function ns.Sessions(filter, period, limit)
    local since = (period == "all") and 0 or ns.MidnightDaysAgo(PERIOD_DAYS[period] - 1)
    local list = {}
    EachChar(filter, function(c, k)
        for i = #c.sessions, 1, -1 do
            local e = c.sessions[i]
            if e.s + e.d < since then break end
            if e.d >= MIN_SESSION or e == session then
                list[#list + 1] = {
                    s = e.s, d = e.d, a = e.a or 0, l0 = e.l0, l1 = e.l1, z = e.z,
                    char = c.name or k, class = c.class, live = (e == session), est = e.est,
                }
            end
        end
    end)
    table.sort(list, function(a, b) return a.s > b.s end)
    if #list > limit then for i = #list, limit + 1, -1 do list[i] = nil end end
    return list
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")

ev:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then
            InitDB()
            if ns.OnInit then ns.OnInit() end
        end
    elseif event == "PLAYER_LOGIN" then
        char.level = UnitLevel("player")
        if db.settings.import ~= false then
            local n = ns.ImportTesorero()
            if n and n > 0 then
                print("|cff66c7ffBitácora:|r " .. n .. (n == 1 and " sesión pasada estimada" or " sesiones pasadas estimadas") .. " a partir de Tesorero. Para quitarlas: |cffffff00/bita quitar estimadas|r")
            end
        end
        StartSession()
    elseif event == "PLAYER_LEVEL_UP" then
        local lvl = ...
        char.level = lvl
        if char.played then char.playedLevel = 0 end
        if session then session.l1 = lvl end
    end
end)

N.Reg(ev, "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LEVEL_UP")

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
SLASH_BITACORA1, SLASH_BITACORA2 = "/bitacora", "/bita"
SlashCmdList.BITACORA = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local P = "|cff66c7ffBitácora:|r "
    if msg == "reset confirmar" then
        db.chars[charKey] = nil
        InitDB()
        session = nil
        StartSession()
        N.RequestPlayed()
        print(P .. "registro de este personaje borrado.")
        if ns.Refresh then ns.Refresh() end
    elseif msg == "reset" then
        print(P .. "esto borrará TODO el registro de " .. charKey .. ". Escribe |cffffff00/bita reset confirmar|r para hacerlo.")
    elseif msg == "importar" then
        db.settings.import = true
        local n = ns.ImportTesorero()
        if not n then
            print(P .. "no encuentro datos de Tesorero (¿está instalado y activado?).")
        elseif n == 0 then
            print(P .. "no hay nada nuevo que importar de Tesorero.")
        else
            print(P .. n .. (n == 1 and " sesión estimada añadida" or " sesiones estimadas añadidas") .. " a partir de Tesorero.")
        end
        if ns.Refresh then ns.Refresh() end
    elseif msg == "quitar estimadas" then
        db.settings.import = false
        local n = ns.RemoveEstimated()
        print(P .. n .. (n == 1 and " sesión estimada eliminada" or " sesiones estimadas eliminadas") .. ". No se volverá a importar hasta que escribas |cffffff00/bita importar|r.")
        if ns.Refresh then ns.Refresh() end
    elseif msg == "minimapa" then
        print(P .. "botón del minimapa (compartido, Nexo) " .. (N.ToggleMinimap() and "oculto" or "visible") .. ".")
    elseif msg == "ayuda" or msg == "help" then
        print(P .. "comandos:")
        print("  |cffffff00/bita|r - abrir/cerrar la ventana")
        print("  |cffffff00/bita minimapa|r - mostrar/ocultar el botón del minimapa")
        print("  |cffffff00/bita importar|r - estimar el historial anterior a partir de Tesorero")
        print("  |cffffff00/bita quitar estimadas|r - borrar lo estimado y dejar solo lo medido")
        print("  |cffffff00/bita reset|r - borrar el registro de este personaje")
    else
        if ns.Toggle then ns.Toggle() end
    end
end
