-- Nexo: núcleo compartido (formato, personajes, reloj de juego y /played)
--
-- Los demás addons lo usan a través de la tabla global Nexo:
--   Nexo.Dur / Num / DayKey / DayLabel ...   formato de tiempos, números y fechas
--   Nexo.Money(cobre) / Ago(hora)            monedas con iconos y "hace 5 min"
--   Nexo.QualityRGB(q) / ItemID(enlace)      color por calidad e id de un enlace de objeto
--   Nexo.Keys(tabla)                         claves ordenadas (listas de personajes)
--   Nexo.Reg(marco, ...)                     registra eventos; los que no existen se ignoran
--   Nexo.Debounce(clave, espera, fn, ...)    muchos avisos seguidos = una sola llamada
--   Nexo.CharKey() / Char() / CharList()     registro de personajes de la cuenta
--   Nexo.InitChar / EachChar / FindChar      trabajo con la tabla de personajes de cada addon
--   Nexo.PERIODS / PERIOD_DAYS               periodos de los resúmenes
--   Nexo.OnTick(fn)                          fn(dt, ahora) cada 5 s de juego
--   Nexo.OnPlayed(fn)                        fn(total, enEsteNivel) con el /played real
--   Nexo.Kit(tema)                           piezas de interfaz (ver UI.lua)
--   Nexo.Register(def)                       apunta el addon en el botón del minimapa
local ADDON = ...

Nexo = Nexo or {}
local N = Nexo
N.version = 3

local floor = math.floor
local DAY = 86400
local TICK = 5
N.DAY = DAY
N.DAY_NAMES = { "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado" }

---------------------------------------------------------------------------
-- Formato y fechas
---------------------------------------------------------------------------
-- 3725 -> "1h 02m"
function N.Dur(s)
    s = floor((s or 0) + 0.5)
    if s <= 0 then return "0 min" end
    if s < 60 then return "<1 min" end
    local d, h, m = floor(s / DAY), floor(s / 3600) % 24, floor(s / 60) % 60
    if d > 0 then return ("%dd %dh"):format(d, h) end
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    return m .. " min"
end

-- 12345 -> "12.345"
function N.Num(n)
    local s, k = tostring(floor((n or 0) + 0.5)), nil
    repeat
        s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1.%2")
    until k == 0
    return s
end

function N.DayKey(t) return date("%Y-%m-%d", t or time()) end

function N.DayKeyToTime(dk)
    local y, m, d = dk:match("(%d+)-(%d+)-(%d+)")
    return time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

function N.MidnightDaysAgo(n)
    local d = date("*t", time() - n * DAY)
    return time({ year = d.year, month = d.month, day = d.day, hour = 0, min = 0, sec = 0 })
end

-- "Hoy", "Ayer" o "Martes 03/11"
function N.DayLabel(t)
    if N.DayKey(t) == N.DayKey() then return "Hoy" end
    if N.DayKey(t) == N.DayKey(time() - DAY) then return "Ayer" end
    return N.DAY_NAMES[tonumber(date("%w", t)) + 1] .. " " .. date("%d/%m", t)
end

function N.Plural(n, one, many) return n .. " " .. (n == 1 and one or many) end

-- Dinero en cobre -> monedas con su icono. full = todas las monedas; si no, versión compacta
local BLN = BreakUpLargeNumbers or tostring
local function Coin(tex, size) return ("|TInterface\\MoneyFrame\\UI-%sIcon:%d:%d:2:0|t"):format(tex, size, size) end

function N.Money(c, size, full)
    size = size or 12
    c = floor(math.abs(c or 0) + 0.5)
    local g, s, cu = floor(c / 10000), floor(c / 100) % 100, c % 100
    local out = {}
    if g > 0 then out[#out + 1] = BLN(g) .. Coin("Gold", size) end
    if s > 0 and (full or g < 1000) then out[#out + 1] = s .. Coin("Silver", size) end
    if (cu > 0 and (full or g == 0)) or #out == 0 then out[#out + 1] = cu .. Coin("Copper", size) end
    return table.concat(out, " ")
end

-- "ahora mismo", "hace 5 min", "hace 3 h", "hace 2 días"; sin hora devuelve never (o nil)
function N.Ago(t, never)
    if not t then return never end
    local d = time() - t
    if d < 90 then return "ahora mismo" end
    if d < 3600 then return "hace " .. floor(d / 60) .. " min" end
    if d < DAY then return "hace " .. floor(d / 3600) .. " h" end
    return "hace " .. N.Plural(floor(d / DAY), "día", "días")
end

function N.QualityRGB(q)
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

function N.ItemID(link) return link and tonumber(link:match("item:(%d+)")) end

-- Claves de una tabla, ordenadas
function N.Keys(t)
    local list = {}
    if t then
        for k in pairs(t) do list[#list + 1] = k end
    end
    table.sort(list)
    return list
end

-- "Nombre - Reino" -> "Nombre"
function N.ShortName(key) return (key:match("^(.-) %- ") or key) end

function N.ClassHex(class, fallback)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return fallback or "ffffffff" end
    return ("ff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
end

function N.ClassRGB(class, r, g, b)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return r or 1, g or 1, b or 1 end
    return c.r, c.g, c.b
end

---------------------------------------------------------------------------
-- Personajes
---------------------------------------------------------------------------
local db

function N.CharKey() return UnitName("player") .. " - " .. GetRealmName() end

local function UpdateChar()
    if not db or not UnitName("player") then return end   -- aún sin datos del personaje: se repite al entrar
    local key = N.CharKey()
    local c = db.chars[key] or {}
    db.chars[key] = c
    local _, class = UnitClass("player")
    c.name, c.realm, c.class = UnitName("player"), GetRealmName(), class
    local lvl = UnitLevel("player")
    if lvl and lvl > 0 then c.level = lvl end
    c.lastSeen = time()
    N.charKey = key
end

local function InitDB()
    NexoDB = NexoDB or {}
    db = NexoDB
    db.chars = db.chars or {}
    db.minimap = db.minimap or { angle = 200, hide = false }
    N.db = db
    UpdateChar()
end

-- Datos de un personaje: { name, realm, class, level, lastSeen }
function N.Char(key) return db and db.chars[key or N.charKey] end

function N.CharList() return N.Keys(db and db.chars) end

-- Lo que sigue trabaja sobre la tabla de personajes de cada addon (su db.chars), no sobre la de Nexo.

-- Entrada del personaje actual en chars, con clase, nombre y nivel al día.
-- new = tabla con la que se crea si aún no existe. Devuelve la entrada y su clave.
function N.InitChar(chars, new)
    local key = N.CharKey()
    local c = chars[key] or new or {}
    chars[key] = c
    local _, class = UnitClass("player")
    c.class, c.name, c.level = class, UnitName("player"), UnitLevel("player")
    return c, key
end

-- fn(datos, clave) para el personaje filter, o para todos si filter es nil
function N.EachChar(chars, filter, fn)
    if filter then
        if chars[filter] then fn(chars[filter], filter) end
    else
        for k, c in pairs(chars) do fn(c, k) end
    end
end

-- Clave del personaje que se llama who (nombre suelto o "Nombre - Reino"), sin contar except
function N.FindChar(chars, who, except)
    who = who:lower()
    for key, c in pairs(chars) do
        if key ~= except and ((c.name or ""):lower() == who or key:lower() == who) then return key end
    end
end

-- Periodos de los resúmenes: { clave, texto } y los días que abarca cada uno ("all" no tiene límite)
N.PERIODS = { { "today", "Hoy" }, { "week", "7 días" }, { "month", "30 días" }, { "all", "Siempre" } }
N.PERIOD_DAYS = { today = 1, week = 7, month = 30 }

---------------------------------------------------------------------------
-- Reloj de juego y /played
---------------------------------------------------------------------------
local tickFns, playedFns = {}, {}
local lastTick

local function Fire(list, ...)
    for _, fn in ipairs(list) do
        local ok, err = pcall(fn, ...)
        if not ok then geterrorhandler()(err) end   -- un fallo en un addon no para a los demás
    end
end

-- fn(dt, ahora): dt son los segundos de juego transcurridos desde el aviso anterior
function N.OnTick(fn) tickFns[#tickFns + 1] = fn end

-- fn(total, enEsteNivel): tiempo jugado real del personaje, en segundos
function N.OnPlayed(fn) playedFns[#playedFns + 1] = fn end

local function Tick()
    if not lastTick then return end
    local now = time()
    local dt = now - lastTick
    lastTick = now
    if dt <= 0 then return end
    if dt > 300 then dt = TICK end   -- el equipo estuvo suspendido: no lo cuentes
    Fire(tickFns, dt, now)
end

-- Registra eventos en un marco; los que no existen en este cliente se ignoran.
-- Devuelve true si se registraron todos.
function N.Reg(frame, ...)
    local all = true
    for i = 1, select("#", ...) do
        if not pcall(frame.RegisterEvent, frame, (select(i, ...))) then all = false end
    end
    return all
end

-- Muchos avisos seguidos con la misma clave = una sola llamada a fn(...) pasada la espera
local waiting = {}
function N.Debounce(key, delay, fn, ...)
    if waiting[key] then return end
    waiting[key] = true
    local a, b = ...
    C_Timer.After(delay, function()
        waiting[key] = nil
        local ok, err = pcall(fn, a, b)
        if not ok then geterrorhandler()(err) end
    end)
end

-- /played pedido en silencio, sin ensuciar el chat.
-- El chat se destapa cuando han llegado todas las respuestas pedidas, o a los 8 s de la
-- última petición si alguna no llega.
local hiddenChat
local playedPending, playedSeq = 0, 0
local function RestoreChat()
    playedPending = 0
    if not hiddenChat then return end
    for _, f in ipairs(hiddenChat) do f:RegisterEvent("TIME_PLAYED_MSG") end
    hiddenChat = nil
end

function N.RequestPlayed()
    if not RequestTimePlayed then return end
    if not hiddenChat then
        hiddenChat = {}
        for i = 1, (NUM_CHAT_WINDOWS or 10) do
            local f = _G["ChatFrame" .. i]
            if f and f.IsEventRegistered and f:IsEventRegistered("TIME_PLAYED_MSG") then
                f:UnregisterEvent("TIME_PLAYED_MSG")
                hiddenChat[#hiddenChat + 1] = f
            end
        end
    end
    playedPending = playedPending + 1
    playedSeq = playedSeq + 1
    local seq = playedSeq
    C_Timer.After(8, function()
        if seq == playedSeq then RestoreChat() end
    end)
    RequestTimePlayed()
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")

ev:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then
            InitDB()
            if N.InitUI then N.InitUI() end
        end
    elseif event == "PLAYER_LOGIN" then
        UpdateChar()
        lastTick = time()
        C_Timer.After(3, function()
            if #playedFns > 0 then N.RequestPlayed() end
        end)
    elseif event == "PLAYER_LEVEL_UP" then
        local c = N.Char()
        local lvl = ...
        if c and type(lvl) == "number" then c.level = lvl end
    elseif event == "TIME_PLAYED_MSG" then
        local total, level = ...
        if type(total) == "number" then Fire(playedFns, total, level or 0) end
        if playedPending > 0 then playedPending = playedPending - 1 end
        if playedPending == 0 then
            local seq = playedSeq
            C_Timer.After(0.2, function()
                if seq == playedSeq then RestoreChat() end   -- si entretanto se pidió otro, sigue tapado
            end)
        end
    elseif event == "PLAYER_LOGOUT" then
        Tick()
    end
end)

local acc = 0
ev:SetScript("OnUpdate", function(self, el)
    acc = acc + el
    if acc >= TICK then
        acc = 0
        Tick()
    end
end)

N.Reg(ev, "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "PLAYER_LEVEL_UP", "TIME_PLAYED_MSG")

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
SLASH_NEXO1 = "/nexo"
SlashCmdList.NEXO = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local P = "|cffd9d9e6Nexo:|r "
    if msg == "minimapa" then
        local hidden = N.ToggleMinimap()
        print(P .. "botón del minimapa " .. (hidden and "oculto" or "visible") .. ".")
    else
        print(P .. "addons conectados:")
        for _, def in ipairs(N.addons or {}) do
            print("  " .. def.name .. (def.slash and ("  |cffffff00" .. def.slash .. "|r") or ""))
        end
        print("  |cffffff00/nexo minimapa|r - mostrar/ocultar el botón del minimapa")
    end
end
