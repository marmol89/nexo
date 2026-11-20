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
--   Nexo.Movable(marco, ajustes)             marco que se arrastra y recuerda dónde se dejó
--   Nexo.Register(def)                       apunta el addon en el botón del minimapa
--   Nexo.Export(ids) / ReadExport / Import   datos de los addons como texto, para cambiar de ordenador
--   Nexo.WhenLabel(t, año)                   "Hoy 14:05", "Ayer 09:30" o "03/11 14:05" (año = true: "03/11/26 14:05")
--   Nexo.Trace(log, msg, max)                línea con la hora al principio de una lista guardada
--   Nexo.FillRows(scroll, filas, alto, datos, rellenar)   lista con FauxScrollFrame (UI.lua)
--   Nexo.Serialize(t) / Deserialize(s)       tabla <-> texto compacto
--   Nexo.Antiguo(addon)                      ¿sigue cargado el addon con el nombre de antes de Nexo_<nombre>?
local ADDON = ...

Nexo = Nexo or {}
local N = Nexo
N.version = 8

local floor = math.floor
local DAY = 86400
local TICK = 5
N.DAY = DAY

N.Dict({
    ["no encuentro a otro personaje llamado \""] = "I cannot find another character named \"",
    ["Objeto "] = "Item ",
    ["Banco de la banda"] = "Warband bank",
    ["botón del minimapa (compartido, Nexo) "] = "minimap button (shared, Nexo) ",
    [" borrado."] = " deleted.",
    ["Buscar objeto..."] = "Search item...",
    ["Todo"] = "All",
    [" de "] = " of ",
    ["objeto distinto"] = "distinct item",
    ["objetos distintos"] = "distinct items",
    ["Ningún objeto coincide con la búsqueda."] = "No item matches the search.",
    ["visto "] = "seen ",
    ["|cffffff00Clic|r para abrir · |cffffff00Arrastrar|r para mover"] = "|cffffff00Click|r to open · |cffffff00Drag|r to move",
    ["registro de este personaje borrado."] = "log of this character deleted.",
    ["esto borrará TODO el registro de "] = "this will delete ALL the log of ",
    ["Media diaria"] = "Daily average",
    ["Últimos 14 días"] = "Last 14 days",
    ["Sesión"] = "Session",
    ["desde las 00:00 de hoy"] = "since 00:00 today",
    ["últimos 7 días"] = "last 7 days",
    ["últimos 30 días"] = "last 30 days",
    ["Nada todavía"] = "Nothing yet",
    ["  ·  |cffffb347recetas sin registrar: "] = "  ·  |cffffb347recipes not recorded: ",
    ["  ... y "] = "  ... and ",
    [" más."] = " more.",
    ["nivel "] = "level ",
    ["activado"] = "on",
    ["desactivado"] = "off",
    ["nunca"] = "never",
    ["escaneo"] = "scan",
    ["no"] = "No",
    ["Domingo"] = "Sunday", ["Lunes"] = "Monday", ["Martes"] = "Tuesday", ["Miércoles"] = "Wednesday",
    ["Jueves"] = "Thursday", ["Viernes"] = "Friday", ["Sábado"] = "Saturday",
    ["Hoy"] = "Today", ["Ayer"] = "Yesterday", ["Siempre"] = "All time",
    ["7 días"] = "7 days", ["30 días"] = "30 days",
    ["día"] = "day", ["días"] = "days", ["ahora mismo"] = "just now",
    ["El texto está incompleto o cambiado: cópialo entero otra vez."] = "The text is incomplete or changed: copy it again in full.",
    ["No es un texto exportado por Nexo."] = "This is not a text exported by Nexo.",
    ["Este cliente no puede leer texto comprimido."] = "This client cannot read compressed text.",
    ["No se ha podido descomprimir el texto."] = "The text could not be decompressed.",
    ["El texto no se puede leer."] = "The text cannot be read.",
    ["los addons ahora se llaman"] = "the addons are now called",
    ["nombre"] = "name",
    ["Tus datos de"] = "Your data for",
    ["se conservan: recarga la interfaz (|cffffff00/reload|r) para terminar el cambio."] = "is kept: reload the UI (|cffffff00/reload|r) to finish the change.",
    ["Después puedes borrar de Interface\\AddOns las carpetas antiguas:"] = "Afterwards you can delete the old folders from Interface\\AddOns:",
    ["Los addons de Nexo ahora se llaman Nexo_<nombre>."] = "The Nexo addons are now called Nexo_<name>.",
    ["Tus datos se conservan. Recarga la interfaz para terminar el cambio."] = "Your data is kept. Reload the UI to finish the change.",
    ["Recargar"] = "Reload", ["Luego"] = "Later",
    ["comandos:"] = "commands:",
    ["lista de addons conectados"] = "list of connected addons",
    ["abrir/cerrar la ventana de exportar e importar datos"] = "open/close the export and import data window",
    ["abrirla para sacar los datos como texto (cambiar de ordenador)"] = "open it to get the data as text (to change computer)",
    ["abrirla para pegar el texto exportado en otro ordenador"] = "open it to paste the text exported on another computer",
    ["mostrar/ocultar el botón del minimapa"] = "show/hide the minimap button",
    ["esta lista"] = "this list",
    ["comandos de Nexo"] = "Nexo commands",
    ["addons conectados:"] = "connected addons:",
    ["botón del minimapa"] = "minimap button",
    ["oculto"] = "hidden", ["visible"] = "visible",
    ["Ajustes"] = "Settings",
    ["Idioma y opciones de Nexo"] = "Language and Nexo options",
    ["Idioma"] = "Language",
    ["Automático"] = "Automatic",
    ["Minimapa"] = "Minimap",
    ["Mostrar botón"] = "Show button",
    ["Ocultar botón"] = "Hide button",
    ["Datos"] = "Data",
    ["Idioma cambiado."] = "Language changed.",
    ["Recarga la interfaz para aplicarlo."] = "Reload the UI to apply it.",
    ["abrir/cerrar la ventana de ajustes (idioma y opciones)"] = "open/close the settings window (language and options)",
    ["Restablecer posición"] = "Reset position",
    ["Tooltip"] = "Tooltip",
    ["Sonidos"] = "Sounds",
    ["Ventanas"] = "Windows",
})
local Tr = N.T

N.DAY_NAMES = { Tr("Domingo"), Tr("Lunes"), Tr("Martes"), Tr("Miércoles"), Tr("Jueves"), Tr("Viernes"), Tr("Sábado") }

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
    if N.DayKey(t) == N.DayKey() then return Tr("Hoy") end
    if N.DayKey(t) == N.DayKey(time() - DAY) then return Tr("Ayer") end
    return N.DAY_NAMES[tonumber(date("%w", t)) + 1] .. " " .. date("%d/%m", t)
end

-- "Hoy 14:05", "Ayer 09:30" o "03/11 14:05"; con year = true, "03/11/26 14:05" en vez de "03/11 14:05"
function N.WhenLabel(t, year)
    local dl = N.DayLabel(t)
    if dl == Tr("Hoy") or dl == Tr("Ayer") then return dl .. " " .. date("%H:%M", t) end
    return date(year and "%d/%m/%y %H:%M" or "%d/%m %H:%M", t)
end

function N.Plural(n, one, many) return n .. " " .. (n == 1 and Tr(one) or Tr(many)) end

-- Añade una línea con la hora al principio de log (lista guardada) y deja como mucho max
function N.Trace(log, msg, max)
    table.insert(log, 1, date("%H:%M:%S ") .. msg)
    for i = #log, max + 1, -1 do log[i] = nil end
end

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
-- En inglés la frase va al revés: "5 min ago"
local function Hace(txt)
    if N.lang == "es" then return "hace " .. txt end
    return txt .. " ago"
end

function N.Ago(t, never)
    if not t then return never end
    local d = time() - t
    if d < 90 then return Tr("ahora mismo") end
    if d < 3600 then return Hace(floor(d / 60) .. " min") end
    if d < DAY then return Hace(floor(d / 3600) .. " h") end
    return Hace(N.Plural(floor(d / DAY), "día", "días"))
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

-- Reino del personaje. Al cargar el addon, GetRealmName() a veces aún devuelve "", y la clave
-- quedaba "Nombre - " (el mismo personaje aparecía dos veces). Por eso se recuerda el último
-- reino bueno de cada personaje y se usa cuando el juego todavía no lo da.
local function RealmOf(name)
    local realm = GetRealmName()
    if realm and realm ~= "" then
        if NexoDB then
            NexoDB.realmOf = NexoDB.realmOf or {}
            NexoDB.realmOf[name] = realm
        end
        return realm
    end
    if NexoDB and NexoDB.realmOf and NexoDB.realmOf[name] then return NexoDB.realmOf[name] end
    -- Sin reino del juego ni memoria: si las entradas ya guardadas de este nombre tienen un
    -- único reino, es ese (el mismo personaje, no otro).
    local first = name:match("^(%S+)") or name
    local found, many = nil, false
    for k in pairs(NexoDB and NexoDB.chars or {}) do
        local nm, rl = k:match("^(.-) %- (.*)$")
        if rl and rl ~= "" and (nm == name or nm == first) then
            if found and found ~= rl then many = true end
            found = rl
        end
    end
    if found and not many then return found end
    return ""
end

-- Nombre completo del personaje. En WoW Forever UnitName devuelve nombre y apellido por
-- separado ("Pola", "Kola"); usar solo el primero dejaba el personaje como "Pola".
function N.FullName()
    local first, last = UnitName("player")
    if not first then return nil end
    if last and last ~= "" then return first .. " " .. last end
    return first
end

function N.CharKey()
    local name = N.FullName() or ""
    return name .. " - " .. RealmOf(name)
end

-- Une en chars[key] las entradas viejas de este personaje: las que tienen solo el primer
-- nombre ("Pola - Reino") o no tienen reino ("Pola - "). Para cada dato que tengan los dos
-- gana el registro más reciente (lastSeen o tBags); los datos que solo tiene uno se conservan.
function N.MergeEmptyRealm(chars, key, fullName)
    local realm = key:match(" %- (.*)$") or ""
    local first = fullName:match("^(%S+)") or fullName
    local stale = {}
    for k in pairs(chars) do
        if k ~= key then
            local nm, rl = k:match("^(.-) %- (.*)$")
            if (nm == fullName or nm == first) and (rl == "" or rl == realm) then stale[#stale + 1] = k end
        end
    end
    table.sort(stale)
    local function Seen(c) return c.lastSeen or c.tBags or 0 end
    for _, k in ipairs(stale) do
        local src = chars[k]
        chars[k] = nil
        local dst = chars[key]
        if not dst then
            chars[key] = src
        else
            local srcNewer = Seen(src) > Seen(dst)
            for f, v in pairs(src) do
                if dst[f] == nil or srcNewer then dst[f] = v end
            end
        end
    end
    if chars[key] then chars[key].name = fullName end   -- el nombre bueno, no el de la entrada vieja
end

local function UpdateChar()
    if not db or not UnitName("player") then return end   -- aún sin datos del personaje: se repite al entrar
    local key = N.CharKey()
    N.MergeEmptyRealm(db.chars, key, N.FullName())
    local c = db.chars[key] or {}
    db.chars[key] = c
    local _, class = UnitClass("player")
    c.name, c.realm, c.class = N.FullName(), GetRealmName(), class
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
    N.RefreshLang()  -- NexoDB ya es de fiar aquí; antes (al cargar Locale.lua) puede no estarlo
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
    N.MergeEmptyRealm(chars, key, N.FullName())
    local c = chars[key] or new or {}
    chars[key] = c
    local _, class = UnitClass("player")
    c.class, c.name, c.level = class, N.FullName(), UnitLevel("player")
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
N.PERIODS = { { "today", Tr("Hoy") }, { "week", Tr("7 días") }, { "month", Tr("30 días") }, { "all", Tr("Siempre") } }
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
-- Exportar e importar datos (para cambiar de ordenador)
--
-- Un addon no puede leer ni escribir archivos: los datos salen como un texto que se copia
-- y se pega. Cada addon dice cuál es su variable guardada con def.data al registrarse.
--
-- El texto es  NEXO1<z|p>:<suma>:<cuerpo>   z = cuerpo comprimido y en base64, p = tal cual
---------------------------------------------------------------------------
local ESC = { ["\\"] = "\\\\", ['"'] = "\\q", ["|"] = "\\p", ["\n"] = "\\n", ["\r"] = "\\r" }
local UNESC = { ["\\"] = "\\", q = '"', p = "|", n = "\n", r = "\r" }
local PLAIN = { number = true, string = true, boolean = true, table = true }

local function Escape(c) return ESC[c] or ("\\c" .. string.char(c:byte() + 64)) end
local function Unescape(x)
    if #x == 2 then return string.char(x:byte(2) - 64) end
    return UNESC[x] or x
end

local function Put(buf, v, depth)
    local tv = type(v)
    if tv == "number" then
        if v ~= v or v == math.huge or v == -math.huge then
            buf[#buf + 1] = "0"
        elseif v == floor(v) and v > -1e15 and v < 1e15 then
            buf[#buf + 1] = ("%.0f"):format(v)
        else
            buf[#buf + 1] = ("%.17g"):format(v)
        end
    elseif tv == "string" then
        buf[#buf + 1] = '"' .. v:gsub('[%c\\"|]', Escape) .. '"'
    elseif tv == "boolean" then
        buf[#buf + 1] = v and "T" or "F"
    else
        if depth > 60 then error("datos demasiado anidados") end
        buf[#buf + 1] = "{"
        local n, some = 0, false
        while PLAIN[type(v[n + 1])] do n = n + 1 end
        for i = 1, n do
            if some then buf[#buf + 1] = "," end
            some = true
            Put(buf, v[i], depth + 1)
        end
        for k, x in pairs(v) do
            local tk = type(k)
            local inList = tk == "number" and k >= 1 and k <= n and k == floor(k)
            if not inList and (tk == "number" or tk == "string") and PLAIN[type(x)] then
                if some then buf[#buf + 1] = "," end
                some = true
                if tk == "string" and k:find("^[%a_][%w_]*$") then
                    buf[#buf + 1] = k
                else
                    Put(buf, k, depth + 1)
                end
                buf[#buf + 1] = "="
                Put(buf, x, depth + 1)
            end
        end
        buf[#buf + 1] = "}"
    end
end

-- Tabla (solo números, textos, booleanos y tablas) -> texto compacto
function N.Serialize(t)
    local buf = {}
    Put(buf, t, 0)
    return table.concat(buf)
end

local function Parse(s, pos)
    local c = s:byte(pos)
    if c == 123 then                                    -- {
        local t, n = {}, 0
        pos = pos + 1
        if s:byte(pos) == 125 then return t, pos + 1 end
        while true do
            local k, v
            local _, e, name = s:find("^([%a_][%w_]*)=", pos)
            if e then
                k = name
                v, pos = Parse(s, e + 1)
            else
                v, pos = Parse(s, pos)
                if s:byte(pos) == 61 then               -- =
                    k = v
                    if type(k) ~= "number" and type(k) ~= "string" then error("clave no válida") end
                    v, pos = Parse(s, pos + 1)
                else
                    n = n + 1
                    k = n
                end
            end
            t[k] = v
            c = s:byte(pos)
            if c == 125 then return t, pos + 1 end      -- }
            if c ~= 44 then error("texto cortado") end  -- ,
            pos = pos + 1
        end
    elseif c == 34 then                                 -- "
        local e = s:find('"', pos + 1, true)
        if not e then error("texto cortado") end
        local str = s:sub(pos + 1, e - 1)
        if str:find("\\", 1, true) then str = str:gsub("\\(c?.)", Unescape) end
        return str, e + 1
    elseif c == 84 then
        return true, pos + 1
    elseif c == 70 then
        return false, pos + 1
    end
    local a, b = s:find("^[-+%d%.eE]+", pos)
    local num = a and tonumber(s:sub(a, b))
    if not num then error("texto cortado") end
    return num, b + 1
end

-- Texto de N.Serialize -> tabla (lanza un error si el texto no es válido)
function N.Deserialize(s)
    local v, pos = Parse(s, 1)
    if pos <= #s then error("sobra texto") end
    return v
end

local function Checksum(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + s:byte(i)) % 65521
        b = (b + a) % 65521
    end
    return ("%04x%04x"):format(b, a)
end

local function Codec()
    local E = C_EncodingUtil
    if E and E.CompressString and E.DecompressString and E.EncodeBase64 and E.DecodeBase64 then return E end
end

-- Addons con datos que se pueden exportar: { { id, name, data = nombre de la variable guardada }, ... }
function N.DataAddons()
    local list = { { id = "Nexo", name = "Nexo", data = "NexoDB" } }
    for _, def in ipairs(N.addons or {}) do
        if def.data then list[#list + 1] = def end
    end
    return list
end

-- Texto para copiar con los datos de los addons de ids ({ id = true }; nil = todos).
-- Devuelve el texto y si va comprimido.
function N.Export(ids)
    local pack = { v = 1, t = time(), from = N.charKey, data = {} }
    for _, def in ipairs(N.DataAddons()) do
        local saved = _G[def.data]
        if type(saved) == "table" and (not ids or ids[def.id]) then pack.data[def.id] = saved end
    end
    local body, flag = N.Serialize(pack), "p"
    local E = Codec()
    if E then
        -- solo se usa la compresión del cliente si devuelve lo mismo al deshacerla
        local ok, z = pcall(function()
            local out = E.EncodeBase64(E.CompressString(body))
            if E.DecompressString(E.DecodeBase64(out)) ~= body then error("no coincide") end
            return out
        end)
        if ok and type(z) == "string" then body, flag = z, "z" end
    end
    return "NEXO1" .. flag .. ":" .. Checksum(body) .. ":" .. body, flag == "z"
end

-- Lee un texto de N.Export. Devuelve { t = cuándo, from = personaje, data = { id = tabla } },
-- o nil y el motivo.
function N.ReadExport(text)
    text = text or ""
    -- sin patrones que recorran todo el texto: puede ser de cientos de KB
    local first, last = text:find("%S"), #text
    while last > 0 and text:find("^%s", last) do last = last - 1 end
    local flag, sum, from = text:match("^NEXO1([zp]):(%x+):()", first or 1)
    if not flag then return nil, Tr("No es un texto exportado por Nexo.") end
    local body = text:sub(from, last)
    if Checksum(body) ~= sum then return nil, Tr("El texto está incompleto o cambiado: cópialo entero otra vez.") end
    if flag == "z" then
        local E = Codec()
        if not E then return nil, Tr("Este cliente no puede leer texto comprimido.") end
        local ok, plain = pcall(function() return E.DecompressString(E.DecodeBase64(body)) end)
        if not ok or type(plain) ~= "string" then return nil, Tr("No se ha podido descomprimir el texto.") end
        body = plain
    end
    local ok, pack = pcall(N.Deserialize, body)
    if not ok or type(pack) ~= "table" or type(pack.data) ~= "table" then
        return nil, Tr("El texto no se puede leer.")
    end
    return pack
end

-- Sustituye los datos guardados por los de pack (solo los addons de ids, y solo los instalados).
-- Devuelve los nombres de los addons cambiados. Después hay que recargar la interfaz: los
-- addons siguen trabajando con las tablas antiguas hasta entonces.
function N.Import(pack, ids)
    local done = {}
    for _, def in ipairs(N.DataAddons()) do
        local saved = pack.data[def.id]
        if type(saved) == "table" and (not ids or ids[def.id]) then
            _G[def.data] = saved
            done[#done + 1] = def.name
        end
    end
    return done
end

---------------------------------------------------------------------------
-- Addons con el nombre antiguo (antes de llamarse Nexo_<nombre>)
---------------------------------------------------------------------------
-- El juego guarda los datos en un archivo con el nombre de la carpeta del addon, así que
-- Nexo_Tesorero no lee lo que guardó Tesorero. Si la carpeta antigua sigue instalada, carga
-- antes (OptionalDeps en el .toc) y deja sus datos en la variable global. El addon nuevo no
-- arranca esa vez, para no apuntarlo todo dos veces, pero su .toc declara la misma variable
-- y el juego la guarda también en su archivo al recargar o salir. Nexo desactiva el antiguo
-- y, desde la carga siguiente, el nuevo sigue con los datos de siempre.
local IsLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
local Disable = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
local SaveAddOns = (C_AddOns and C_AddOns.SaveAddOns) or SaveAddOns
local oldLoaded = {}

-- ¿Está cargado el addon antiguo de este ("Nexo_Tesorero" -> "Tesorero")? Los addons lo
-- preguntan al principio de cada archivo: if Nexo.Antiguo(ADDON) then return end
function N.Antiguo(addon)
    local old = addon:match("^Nexo_(.+)$")
    if not old or not IsLoaded or not IsLoaded(old) then return false end
    if not oldLoaded[old] then
        oldLoaded[old] = true
        oldLoaded[#oldLoaded + 1] = old
    end
    return true
end

-- Al entrar: desactiva los antiguos que se hayan cargado y pide recargar para terminar
local function RetireOld()
    if #oldLoaded == 0 then return end
    for _, old in ipairs(oldLoaded) do
        if Disable then pcall(Disable, old) end
    end
    if SaveAddOns then pcall(SaveAddOns) end
    local names = table.concat(oldLoaded, ", ")
    print("|cffd9d9e6Nexo:|r " .. Tr("los addons ahora se llaman") .. " |cffffff00Nexo_<" .. Tr("nombre") .. ">|r. "
        .. Tr("Tus datos de") .. " " .. names .. " " .. Tr("se conservan: recarga la interfaz (|cffffff00/reload|r) para terminar el cambio.")
        .. " " .. Tr("Después puedes borrar de Interface\\AddOns las carpetas antiguas:") .. " " .. names .. ".")
    StaticPopupDialogs.NEXO_RENOMBRADO = {
        text = Tr("Los addons de Nexo ahora se llaman Nexo_<nombre>.") .. "\n\n" .. Tr("Tus datos se conservan. Recarga la interfaz para terminar el cambio.") .. "\n\n"
            .. Tr("Después puedes borrar de Interface\\AddOns las carpetas antiguas:") .. "\n" .. names,
        button1 = Tr("Recargar"), button2 = Tr("Luego"),
        OnAccept = function() ReloadUI() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("NEXO_RENOMBRADO")
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
        C_Timer.After(2, RetireOld)
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
    -- Los nombres de los subcomandos dependen del idioma (N.Cmd): /nexo ajustes en español, /nexo settings en inglés
    if msg == N.Cmd("nexo", "minimap") then
        local hidden = N.ToggleMinimap()
        print(P .. Tr("botón del minimapa") .. " " .. (hidden and Tr("oculto") or Tr("visible")) .. ".")
    elseif msg == N.Cmd("nexo", "data") or msg == N.Cmd("nexo", "export") or msg == N.Cmd("nexo", "import") then
        N.ToggleData(msg == N.Cmd("nexo", "import") and "import" or "export")
    elseif msg == N.Cmd("nexo", "settings") then
        N.ToggleSettings()
    elseif msg == N.Cmd("nexo", "help") then
        print(P .. Tr("comandos:"))
        print("  |cffffff00/nexo|r - " .. Tr("lista de addons conectados"))
        print("  |cffffff00/nexo " .. N.Cmd("nexo", "settings") .. "|r - " .. Tr("abrir/cerrar la ventana de ajustes (idioma y opciones)"))
        print("  |cffffff00/nexo " .. N.Cmd("nexo", "data") .. "|r - " .. Tr("abrir/cerrar la ventana de exportar e importar datos"))
        print("  |cffffff00/nexo " .. N.Cmd("nexo", "export") .. "|r - " .. Tr("abrirla para sacar los datos como texto (cambiar de ordenador)"))
        print("  |cffffff00/nexo " .. N.Cmd("nexo", "import") .. "|r - " .. Tr("abrirla para pegar el texto exportado en otro ordenador"))
        print("  |cffffff00/nexo " .. N.Cmd("nexo", "minimap") .. "|r - " .. Tr("mostrar/ocultar el botón del minimapa"))
        print("  |cffffff00/nexo " .. N.Cmd("nexo", "help") .. "|r - " .. Tr("esta lista"))
    else
        print(P .. Tr("addons conectados:"))
        for _, def in ipairs(N.addons or {}) do
            print("  " .. def.name .. (def.slash and ("  |cffffff00" .. def.slash .. "|r") or ""))
        end
        print("  |cffffff00/nexo " .. N.Cmd("nexo", "help") .. "|r - " .. Tr("comandos de Nexo"))
    end
end
