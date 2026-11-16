local Tr = Nexo.T
Nexo.Dict({
    ["Nivel"] = "Level",
    ["Todo"] = "All",
    ["Hoy"] = "Today",
    ["nivel "] = "level ",
    [" alcanzado. El nivel "] = " reached. Level ",
    [" te llevó "] = " took you ",
    ["aviso al subir de nivel "] = "level-up alert ",
    ["registro de este personaje borrado."] = "log of this character deleted.",
    ["esto borrará TODO el registro de "] = "this will delete ALL the log of ",
    [". Escribe |cffffff00/senda reset confirmar|r para hacerlo."] = ". Type |cffffff00/senda reset confirmar|r to do it.",
    ["botón del minimapa (compartido, Nexo) "] = "minimap button (shared, Nexo) ",
    ["  |cffffff00/senda|r - abrir/cerrar la ventana"] = "  |cffffff00/senda|r - open/close the window",
    ["  |cffffff00/senda avisos|r - activar/desactivar el resumen en el chat al subir de nivel"] = "  |cffffff00/senda avisos|r - turn the chat summary on level-up on/off",
    ["  |cffffff00/senda minimapa|r - mostrar/ocultar el botón del minimapa"] = "  |cffffff00/senda minimapa|r - show/hide the minimap button",
    ["  |cffffff00/senda reset|r - borrar el registro de este personaje"] = "  |cffffff00/senda reset|r - delete this character's log",
    ["Exploración"] = "Exploration",
    ["Sesión"] = "Session",
    ["Nivel "] = "Level ",
    ["  |cff4ade80(en curso)|r"] = "  |cff4ade80(in progress)|r",
    ["Tiempo en el nivel"] = "Time in level",
    ["Experiencia registrada"] = "Experience recorded",
    ["Ritmo medio"] = "Average pace",
    ["Senda se instaló con este nivel ya empezado:"] = "Senda was installed with this level already started:",
    ["el tiempo y la experiencia son parciales."] = "time and experience are partial.",
    ["la experiencia registrada es parcial."] = "the recorded experience is partial.",
    ["Subida de nivel · WoW Forever"] = "Leveling · WoW Forever",
    ["Experiencia por hora"] = "Experience per hour",
    ["Para subir de nivel"] = "To level up",
    ["Esta sesión"] = "This session",
    ["En este nivel"] = "In this level",
    ["Tiempo por nivel"] = "Time per level",
    ["últimos "] = "last ",
    [" niveles"] = " levels",
    ["Aún no hay tiempo registrado"] = "No time recorded yet",
    ["De dónde viene la experiencia"] = "Where the experience comes from",
    ["Muertes con experiencia"] = "Deaths with experience",
    ["Misiones entregadas"] = "Quests turned in",
    ["Ganancias cuyo origen no se pudo identificar."] = "Gains whose source could not be identified.",
    ["|cff4ade80en curso|r"] = "|cff4ade80in progress|r",
    ["|r  |cff888888nivel "] = "|r  |cff888888level ",
    ["Sin experiencia que ganar en este nivel"] = "No experience to gain at this level",
    ["Entra con este personaje para ver su progreso"] = "Log in with this character to see its progress",
    ["|r  |cff888888· faltan "] = "|r  |cff888888· remaining ",
    ["Últimos 15 min: "] = "Last 15 min: ",
    ["Gana experiencia para calcularlo"] = "Gain experience to calculate it",
    ["Nivel máximo"] = "Max level",
    ["Hacia las "] = "Around ",
    [" muertes"] = " deaths",
    ["Faltan "] = "Remaining ",
    [" de experiencia"] = " experience",
    [" · nivel "] = " · level ",
    ["Solo con el personaje conectado"] = "Only with the character logged in",
    ["Descanso: "] = "Rested: ",
    ["Sin experiencia de descanso"] = "No rested experience",
    [" nivel"] = " level",
    ["Sin experiencia registrada todavía"] = "No experience recorded yet",
    ["|cffb88cffHoy|r  ·  "] = "|cffb88cffToday|r  ·  ",
    [" de experiencia en "] = " experience in ",
    [" muertes en la sesión"] = " deaths in the session",
    [" misión"] = " quest",
    [" misiones"] = " quests",
    ["|cffffff00Clic|r para abrir · |cffffff00Arrastrar|r para mover"] = "|cffffff00Click|r to open · |cffffff00Drag|r to move",
})
-- Senda: registro de la subida de nivel
local ADDON, ns = ...
if Nexo.Antiguo(ADDON) then return end
local N = Nexo

local max, min, abs = math.max, math.min, math.abs
local RESUME_GAP = 180    -- si vuelves antes de esto (p. ej. /reload), sigue la misma sesión
local RECENT = 900        -- ventana del ritmo "reciente" (15 min)
local MARK_WINDOW = 1.5   -- margen para relacionar una ganancia con su origen
local P = "|cffb88cffSenda:|r "

-- Formato: el del núcleo
ns.Dur, ns.Num, ns.DayKey = N.Dur, N.Num, N.DayKey
local DayKey = N.DayKey

---------------------------------------------------------------------------
-- Base de datos
---------------------------------------------------------------------------
local db, char, charKey
local session             -- sesión en curso (se guarda en char.session para sobrevivir a un /reload)
local lastXP, lastMax, xpLevel   -- última lectura de experiencia y a qué nivel pertenecía

-- Registro de un nivel:
--   sec = tiempo en el nivel (el real de /played si se conoce), ts = tiempo medido por Senda
--   k/q/e/o = experiencia por muertes, misiones, exploración y otros; nk/nq = nº de muertes y misiones
--   part = se empezó a registrar con el nivel ya empezado; real = sec viene de /played
--   at = cuándo se alcanzó; done = cuándo se completó
local function LevelRec(c, lvl)
    local r = c.levels[lvl]
    if not r then
        r = { sec = 0, ts = 0, k = 0, q = 0, e = 0, o = 0, nk = 0, nq = 0 }
        c.levels[lvl] = r
    end
    return r
end

local function DayRec()
    local dk = DayKey()
    local d = char.days[dk]
    if not d then
        d = { xp = 0, sec = 0 }
        char.days[dk] = d
    end
    return d
end

local function InitDB()
    SendaDB = SendaDB or {}
    db = SendaDB
    db.chars = db.chars or {}
    db.settings = db.settings or {}

    charKey = N.CharKey()
    db.chars[charKey] = db.chars[charKey] or { levels = {}, days = {} }
    char = db.chars[charKey]
    char.levels = char.levels or {}
    char.days = char.days or {}
    local _, class = UnitClass("player")
    char.class = class
    char.name = UnitName("player")
    ns.db, ns.char, ns.charKey = db, char, charKey
end

-- Lectura inicial del personaje (en PLAYER_LOGIN, cuando el nivel ya es fiable)
local function Snapshot()
    local lvl = UnitLevel("player") or 1
    local xp, mx = UnitXP("player") or 0, UnitXPMax("player") or 0
    local isNew = char.levels[lvl] == nil
    local rec = LevelRec(char, lvl)
    if isNew and xp > 0 then rec.part = true end
    char.level, char.xp, char.xpMax = lvl, xp, mx
    char.rested = GetXPExhaustion and GetXPExhaustion() or nil
    char.lastSeen = time()
    lastXP, lastMax, xpLevel = xp, mx, lvl
end

local function StartSession()
    local now = time()
    local s = char.session
    if s and s.last and now >= s.last and (now - s.last) <= RESUME_GAP then
        session = s
    else
        session = { s = now, last = now, sec = 0, xp = 0, k = 0, q = 0, e = 0, o = 0, nk = 0, nq = 0,
            l0 = char.level, l1 = char.level }
        char.session = session
    end
    session.g = session.g or {}
    ns.session = session
end

-- El núcleo avisa cada pocos segundos con el tiempo de juego transcurrido
local function Tick(dt, now)
    if not session then return end

    local rec = LevelRec(char, char.level)
    rec.sec = rec.sec + dt
    rec.ts = rec.ts + dt
    session.sec = session.sec + dt
    session.last = now
    local day = DayRec()
    day.sec = day.sec + dt
    char.lastSeen = now

    local g = session.g
    while g[1] and now - g[1][1] > RECENT do table.remove(g, 1) end
end

---------------------------------------------------------------------------
-- Origen de la experiencia
--
-- El juego solo avisa de "tienes más experiencia"; el origen se deduce de lo
-- que pasa justo antes o después: un mensaje de muerte, una misión entregada
-- o una zona descubierta.
---------------------------------------------------------------------------
local marks = {}   -- [origen] = GetTime() de la última señal

-- Convierte un texto del juego ("%s dies, you gain %d experience.") en un patrón de búsqueda
local function MakePattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local p = fmt:gsub("%%%d?%$?s", "\1")
    p = p:gsub("%%%d?%$?d", "\2")
    p = p:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
    p = p:gsub("\1", ".+")
    p = p:gsub("\2", "%%d+")
    return p
end

local killPat = MakePattern(_G.COMBATLOG_XPGAIN_FIRSTPERSON)
local explorePat = MakePattern(_G.ERR_ZONE_EXPLORED_XP)
local questPat = MakePattern(_G.ERR_QUEST_REWARD_EXP_I)
local hasTurnIn = false   -- si existe el evento QUEST_TURNED_IN

local function Mark(src) marks[src] = GetTime() end

local function Classify(g)
    local best, bestD = "o", MARK_WINDOW
    for src, t in pairs(marks) do
        local d = abs(t - g)
        if d <= bestD then best, bestD = src, d end
    end
    return best
end

local function CountKill()
    Mark("k")
    if not session then return end
    session.nk = session.nk + 1
    local rec = LevelRec(char, xpLevel or char.level)
    rec.nk = rec.nk + 1
end

local function CountQuest()
    Mark("q")
    if not session then return end
    session.nq = session.nq + 1
    local rec = LevelRec(char, xpLevel or char.level)
    rec.nq = rec.nq + 1
end

local function OnSystemText(text)
    if type(text) ~= "string" then return end
    if explorePat and text:find(explorePat) then
        Mark("e")
    elseif questPat and text:find(questPat) then
        if hasTurnIn then Mark("q") else CountQuest() end
    end
end

---------------------------------------------------------------------------
-- Subidas de nivel y ganancias
---------------------------------------------------------------------------
local function SetLevel(new)
    if type(new) ~= "number" or not char.level or new <= char.level then return end
    local old = char.level
    local now = time()
    LevelRec(char, old).done = now
    local rec = LevelRec(char, new)
    rec.at = rec.at or now
    char.level = new
    if session then session.l1 = new end

    -- se anuncia un momento después, cuando la última ganancia ya está anotada
    C_Timer.After(1, function()
        if db.settings.announce == false then return end
        local r = char.levels[old]
        if not r then return end
        local msg = Tr("nivel ") .. new .. Tr(" alcanzado. El nivel ") .. old .. Tr(" te llevó ") .. ns.Dur(r.sec)
        local xp = r.k + r.q + r.e + r.o
        if r.ts >= 60 and xp > 0 then
            msg = msg .. " (" .. ns.Num(xp / r.ts * 3600) .. " exp/h)"
        end
        print(P .. msg .. ".")
    end)
end

local function OnXP()
    local xp, mx, lvl = UnitXP("player") or 0, UnitXPMax("player") or 0, UnitLevel("player") or 0
    if not lastXP then
        lastXP, lastMax, xpLevel = xp, mx, lvl
        return
    end
    -- la experiencia nunca baja: si baja (o cambia el máximo) es que has subido de nivel
    local wrapped = lvl > xpLevel or xp < lastXP or (lastMax > 0 and mx ~= lastMax)
    local gain
    if wrapped then
        gain = max(0, lastMax - lastXP) + xp
    else
        gain = xp - lastXP
    end

    local rec = LevelRec(char, xpLevel)   -- la ganancia cuenta para el nivel en el que se consiguió
    lastXP, lastMax = xp, mx
    if wrapped then
        xpLevel = max(lvl, xpLevel + 1)
        SetLevel(xpLevel)
    end
    char.xp, char.xpMax = xp, mx
    char.rested = GetXPExhaustion and GetXPExhaustion() or nil

    if gain <= 0 or not session then
        if ns.OnDataChanged then ns.OnDataChanged() end
        return
    end

    local s, g = session, GetTime()
    s.xp = s.xp + gain
    s.g[#s.g + 1] = { time(), gain }
    local day = DayRec()
    day.xp = day.xp + gain

    -- el origen se decide un instante después: la señal puede llegar antes o después de la ganancia
    C_Timer.After(0.4, function()
        local src = Classify(g)
        rec[src] = (rec[src] or 0) + gain
        s[src] = (s[src] or 0) + gain
        if ns.OnDataChanged then ns.OnDataChanged() end
    end)
    if ns.OnDataChanged then ns.OnDataChanged() end
end

---------------------------------------------------------------------------
-- Reloj y /played: los da el núcleo
---------------------------------------------------------------------------
N.OnTick(Tick)

-- El tiempo real en el nivel actual sustituye al medido (cubre lo anterior a instalar Senda)
N.OnPlayed(function(_, levelTime)
    if not session or type(levelTime) ~= "number" then return end
    local rec = LevelRec(char, char.level)
    rec.sec, rec.real = levelTime, true
    if ns.OnDataChanged then ns.OnDataChanged() end
end)

---------------------------------------------------------------------------
-- Consultas para la interfaz
---------------------------------------------------------------------------
function ns.CharList() return Nexo.Keys(db.chars) end

-- Ritmo de la sesión y ritmo de los últimos 15 minutos (experiencia por hora)
function ns.Rates()
    local s = session
    if not s or s.sec < 30 then return 0, 0 end
    local now, sum = time(), 0
    for _, e in ipairs(s.g) do
        if now - e[1] <= RECENT then sum = sum + e[2] end
    end
    return s.xp / s.sec * 3600, sum / min(RECENT, s.sec) * 3600
end

-- Segundos estimados para subir de nivel (nil si no se puede calcular) y experiencia que falta
function ns.ETA()
    local left = (char.xpMax or 0) - (char.xp or 0)
    local rate, recent = ns.Rates()
    local use = recent > 0 and recent or rate
    if use <= 0 or left <= 0 then return nil, left end
    return left / use * 3600, left
end

-- Muertes que faltan para subir, según la media de esta sesión
function ns.KillsLeft()
    local s = session
    if not s or s.nk < 3 or s.k <= 0 then return nil end
    local left = (char.xpMax or 0) - (char.xp or 0)
    if left <= 0 then return nil end
    return math.ceil(left / (s.k / s.nk))
end

-- Niveles registrados de un personaje, del más alto al más bajo
function ns.LevelList(key)
    local c = db.chars[key]
    local list = {}
    if not c then return list end
    for lvl, r in pairs(c.levels) do
        local xp = r.k + r.q + r.e + r.o
        local current = (lvl == c.level)
        if current or r.sec > 0 or xp > 0 then
            list[#list + 1] = {
                lvl = lvl, sec = r.sec, xp = xp, k = r.k, q = r.q, e = r.e, o = r.o, nk = r.nk, nq = r.nq,
                rate = (r.ts >= 60 and xp > 0) and (xp / r.ts * 3600) or nil,
                at = r.at, done = r.done, current = current,
                partTime = r.part and not r.real, partXP = r.part,
            }
        end
    end
    table.sort(list, function(a, b) return a.lvl > b.lvl end)
    return list
end

-- Reparto de la experiencia por origen. scope = "session" | "level" | "all"
function ns.Sources(key, scope)
    local c = db.chars[key]
    local t = { k = 0, q = 0, e = 0, o = 0, nk = 0, nq = 0, total = 0 }
    if not c then return t end
    local function add(r)
        if not r then return end
        t.k, t.q, t.e, t.o = t.k + (r.k or 0), t.q + (r.q or 0), t.e + (r.e or 0), t.o + (r.o or 0)
        t.nk, t.nq = t.nk + (r.nk or 0), t.nq + (r.nq or 0)
    end
    if scope == "session" then
        if key == charKey then add(session) end
    elseif scope == "level" then
        add(c.levels[c.level])
    else
        for _, r in pairs(c.levels) do add(r) end
    end
    t.total = t.k + t.q + t.e + t.o
    return t
end

function ns.Today(key)
    local c = db.chars[key]
    local d = c and c.days[DayKey()]
    return d and d.xp or 0, d and d.sec or 0
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
        Snapshot()
        StartSession()
    elseif event == "PLAYER_XP_UPDATE" then
        if session then OnXP() end
    elseif event == "PLAYER_LEVEL_UP" then
        if session then SetLevel((...)) end
    elseif event == "UPDATE_EXHAUSTION" then
        if char then char.rested = GetXPExhaustion and GetXPExhaustion() or nil end
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        local text = ...
        if not killPat or (type(text) == "string" and text:find(killPat)) then CountKill() end
    elseif event == "QUEST_TURNED_IN" then
        CountQuest()
    elseif event == "CHAT_MSG_SYSTEM" then
        OnSystemText((...))
    elseif event == "UI_INFO_MESSAGE" then
        local a, b = ...
        OnSystemText(type(b) == "string" and b or a)
    end
end)

Nexo.Reg(ev, "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
    "UPDATE_EXHAUSTION", "CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_SYSTEM", "UI_INFO_MESSAGE")
hasTurnIn = Nexo.Reg(ev, "QUEST_TURNED_IN")

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
SLASH_SENDA1 = "/senda"
SlashCmdList.SENDA = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "reset confirmar" then
        db.chars[charKey] = nil
        InitDB()
        session = nil
        Snapshot()
        StartSession()
        print(P .. Tr("registro de este personaje borrado."))
        if ns.Refresh then ns.Refresh() end
    elseif msg == "reset" then
        print(P .. Tr("esto borrará TODO el registro de ") .. charKey .. Tr(". Escribe |cffffff00/senda reset confirmar|r para hacerlo."))
    elseif msg == "avisos" then
        db.settings.announce = (db.settings.announce == false)
        print(P .. Tr("aviso al subir de nivel ") .. (db.settings.announce and "activado" or "desactivado") .. ".")
    elseif msg == "minimapa" then
        print(P .. Tr("botón del minimapa (compartido, Nexo) ") .. (N.ToggleMinimap() and "oculto" or "visible") .. ".")
    elseif msg == "ayuda" or msg == "help" then
        print(P .. "comandos:")
        print(Tr("  |cffffff00/senda|r - abrir/cerrar la ventana"))
        print(Tr("  |cffffff00/senda avisos|r - activar/desactivar el resumen en el chat al subir de nivel"))
        print(Tr("  |cffffff00/senda minimapa|r - mostrar/ocultar el botón del minimapa"))
        print(Tr("  |cffffff00/senda reset|r - borrar el registro de este personaje"))
    else
        if ns.Toggle then ns.Toggle() end
    end
end
