-- Nexo: núcleo compartido (formato, personajes, reloj de juego y /played)
--
-- Los demás addons lo usan a través de la tabla global Nexo:
--   Nexo.Dur / Num / DayKey / DayLabel ...   formato de tiempos, números y fechas
--   Nexo.CharKey() / Char() / CharList()     registro de personajes de la cuenta
--   Nexo.OnTick(fn)                          fn(dt, ahora) cada 5 s de juego
--   Nexo.OnPlayed(fn)                        fn(total, enEsteNivel) con el /played real
--   Nexo.Kit(tema)                           piezas de interfaz (ver UI.lua)
--   Nexo.Register(def)                       apunta el addon en el botón del minimapa
local ADDON = ...

Nexo = Nexo or {}
local N = Nexo
N.version = 1

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
    if not db then return end
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

function N.CharList()
    local list = {}
    if db then
        for k in pairs(db.chars) do list[#list + 1] = k end
    end
    table.sort(list)
    return list
end

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

-- /played pedido en silencio, sin ensuciar el chat
local hiddenChat
local function RestoreChat()
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
        C_Timer.After(8, RestoreChat)
    end
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
        C_Timer.After(0.2, RestoreChat)
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

local function Reg(e) pcall(ev.RegisterEvent, ev, e) end
Reg("ADDON_LOADED"); Reg("PLAYER_LOGIN"); Reg("PLAYER_LOGOUT"); Reg("PLAYER_LEVEL_UP"); Reg("TIME_PLAYED_MSG")

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
