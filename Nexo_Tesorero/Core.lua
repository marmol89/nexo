local Tr = Nexo.T
Nexo.Dict({
    ["Hoy"] = "Today",
    ["Sin movimientos todavía.\nGana o gasta algo de oro y aparecerá aquí."] = "No movements yet.\nEarn or spend some gold and it will appear here.",
    ["Ganado"] = "Earned",
    ["Botín"] = "Loot",
    ["Mercader"] = "Vendor",
    ["Subasta"] = "Auction",
    ["Correo"] = "Mail",
    ["Comercio"] = "Trade",
    ["Vuelos"] = "Flights",
    ["Otros"] = "Other",
    ["historial de este personaje borrado."] = "history of this character deleted.",
    ["esto borrará TODO el historial de "] = "this will delete ALL the history of ",
    [". Escribe |cffffff00/tesoro reset confirmar|r para hacerlo."] = ". Type |cffffff00/tesoro reset confirmar|r to do it.",
    ["botón del minimapa (compartido, Nexo) "] = "minimap button (shared, Nexo) ",
    ["  |cffffff00/tesoro|r - abrir/cerrar la ventana"] = "  |cffffff00/tesoro|r - open/close the window",
    ["  |cffffff00/tesoro minimapa|r - mostrar/ocultar el botón del minimapa"] = "  |cffffff00/tesoro minimapa|r - show/hide the minimap button",
    ["  |cffffff00/tesoro reset|r - borrar el historial de este personaje"] = "  |cffffff00/tesoro reset|r - delete this character's history",
    ["Historial de oro · WoW Forever"] = "Gold history · WoW Forever",
    ["Oro actual"] = "Current gold",
    ["Últimos 14 días"] = "Last 14 days",
    ["Sin movimientos en las últimas 2 semanas"] = "No movements in the last 2 weeks",
    ["Por categoría"] = "By category",
    ["clic = filtrar movimientos"] = "click = filter movements",
    ["Clic para quitar el filtro"] = "Click to remove the filter",
    ["Clic para ver solo estos movimientos"] = "Click to see only these movements",
    ["Aún no hay movimientos en este periodo"] = "No movements in this period yet",
    ["Mejor día"] = "Best day",
    ["Media diaria"] = "Daily average",
    ["Mayor ingreso"] = "Biggest income",
    ["Mayor gasto"] = "Biggest expense",
    ["|cffffd100Sesión|r  ·  "] = "|cffffd100Session|r  ·  ",
    ["  ·  |cff888888sin movimientos todavía|r"] = "  ·  |cff888888no movements yet|r",
    ["Neto "] = "Net ",
    [" /hora"] = " /hour",
    ["desde las 00:00 de hoy"] = "since 00:00 today",
    ["últimos 7 días"] = "last 7 days",
    ["últimos 30 días"] = "last 30 days",
    ["desde que instalaste Tesorero"] = "since you installed Tesorero",
    ["Récord: "] = "Record: ",
    [" personaje"] = " character",
    [" personajes"] = " characters",
    ["Sobre todo: "] = "Mostly: ",
    ["Nada todavía"] = "Nothing yet",
    ["Ahorras el %d%%"] = "You save %d%%",
    ["|cffff8a8aGastas más de lo que ganas|r"] = "|cffff8a8aYou spend more than you earn|r",
    ["Sin movimientos"] = "No movements",
    ["1000+ movimientos"] = "1000+ movements",
    [" movimiento"] = " movement",
    [" movimientos"] = " movements",
    [" día activo"] = " active day",
    [" días activos"] = " active days",
    ["  Ganado"] = "  Earned",
    ["  Gastado"] = "  Spent",
    ["Total histórico"] = "Lifetime total",
    ["Oro de la cuenta"] = "Account gold",
    ["|cffffff00Clic|r para abrir · |cffffff00Arrastrar|r para mover"] = "|cffffff00Click|r to open · |cffffff00Drag|r to move",
    ["Ganado"] = "Earned",
    ["Gastado"] = "Spent",
    ["Botín "] = "Loot ",
    ["Oro"] = "Gold",
})
-- Tesorero: registro de ingresos y gastos de oro
local ADDON, ns = ...
if Nexo.Antiguo(ADDON) then return end

local floor, abs = math.floor, math.abs
local DAY = 86400
local MAX_TX = 3500     -- movimientos guardados por personaje (los totales nunca se pierden)
local TRIM_TO = 3000

---------------------------------------------------------------------------
-- Categorías
---------------------------------------------------------------------------
ns.CAT_ORDER = { "loot", "quest", "vendor", "repair", "auction", "mail", "trade", "taxi", "trainer", "other" }
ns.CATS = {
    loot    = { name = Tr("Botín"),        color = { 1.00, 0.82, 0.00 }, icon = "Interface\\Icons\\INV_Misc_Coin_02" },
    quest   = { name = "Misiones",     color = { 0.35, 0.75, 1.00 }, icon = "Interface\\Icons\\INV_Misc_Note_01" },
    vendor  = { name = Tr("Mercader"),     color = { 0.95, 0.55, 0.20 }, icon = "Interface\\Icons\\INV_Misc_Bag_10" },
    repair  = { name = "Reparaciones", color = { 0.70, 0.70, 0.75 }, icon = "Interface\\Icons\\Trade_BlackSmithing" },
    auction = { name = Tr("Subasta"),      color = { 0.80, 0.45, 1.00 }, icon = "Interface\\Icons\\INV_Hammer_15" },
    mail    = { name = Tr("Correo"),       color = { 0.95, 0.90, 0.60 }, icon = "Interface\\Icons\\INV_Letter_15" },
    trade   = { name = Tr("Comercio"),     color = { 0.40, 0.90, 0.60 }, icon = "Interface\\Icons\\INV_Misc_Coin_01" },
    taxi    = { name = Tr("Vuelos"),       color = { 0.55, 0.85, 0.95 }, icon = "Interface\\Icons\\Ability_Hunter_EagleEye" },
    trainer = { name = "Entrenador",   color = { 1.00, 0.45, 0.45 }, icon = "Interface\\Icons\\INV_Misc_Book_09" },
    other   = { name = Tr("Otros"),        color = { 0.60, 0.60, 0.60 }, icon = "Interface\\Icons\\INV_Misc_QuestionMark" },
}

---------------------------------------------------------------------------
-- Formato de dinero
---------------------------------------------------------------------------
-- Money(cobre, tamaño, full): el del núcleo. full = todas las monedas; si no, versión compacta
ns.Money = Nexo.Money

function ns.Signed(c, size, full)
    if c > 0 then return "|cff4ade80+" .. ns.Money(c, size, full) .. "|r"
    elseif c < 0 then return "|cffff6b6b-" .. ns.Money(c, size, full) .. "|r" end
    return "|cffaaaaaa" .. ns.Money(0, size, full) .. "|r"
end

---------------------------------------------------------------------------
-- Base de datos
---------------------------------------------------------------------------
local db, char, charKey
ns.session = { i = 0, o = 0, start = time() }

-- Fechas: las del núcleo
local N = Nexo
local DayKey = N.DayKey
ns.DayKey, ns.MidnightDaysAgo = N.DayKey, N.MidnightDaysAgo

local function InitDB()
    TesoreroDB = TesoreroDB or {}
    db = TesoreroDB
    db.chars = db.chars or {}
    db.settings = db.settings or {}
    db.settings.period = db.settings.period or "week"

    char, charKey = N.InitChar(db.chars, { tx = {}, days = {}, totals = {}, firstSeen = time() })
    ns.db, ns.char, ns.charKey = db, char, charKey
end

local function AddRecord(delta, cat)
    if delta == 0 then return end
    local t = time()
    local tx = char.tx
    tx[#tx + 1] = { t, delta, cat, GetRealZoneText() or "" }
    if #tx > MAX_TX then
        local keep = {}
        for i = #tx - TRIM_TO + 1, #tx do keep[#keep + 1] = tx[i] end
        char.tx = keep
    end

    local dk = DayKey(t)
    local day = char.days[dk] or {}; char.days[dk] = day
    local dc = day[cat] or { i = 0, o = 0 }; day[cat] = dc
    local tc = char.totals[cat] or { i = 0, o = 0 }; char.totals[cat] = tc
    if delta > 0 then
        dc.i, tc.i = dc.i + delta, tc.i + delta
        ns.session.i = ns.session.i + delta
    else
        dc.o, tc.o = dc.o - delta, tc.o - delta
        ns.session.o = ns.session.o - delta
    end

    if ns.OnDataChanged then ns.OnDataChanged() end
end

---------------------------------------------------------------------------
-- Agregados para la interfaz
---------------------------------------------------------------------------
local PERIOD_DAYS = N.PERIOD_DAYS
ns.PERIODS = N.PERIODS

function ns.CharList() return N.Keys(db.chars) end

local function EachChar(filter, fn) N.EachChar(db.chars, filter, fn) end

-- Devuelve: ingresos, gastos, porCategoria{cat={i,o}}
function ns.Aggregate(filter, period)
    local inc, out, cats = 0, 0, {}
    local function add(cat, v)
        local c = cats[cat] or { i = 0, o = 0 }; cats[cat] = c
        c.i, c.o = c.i + v.i, c.o + v.o
        inc, out = inc + v.i, out + v.o
    end
    EachChar(filter, function(c)
        if period == "all" then
            for cat, v in pairs(c.totals) do add(cat, v) end
        else
            for n = 0, PERIOD_DAYS[period] - 1 do
                local day = c.days[DayKey(time() - n * DAY)]
                if day then for cat, v in pairs(day) do add(cat, v) end end
            end
        end
    end)
    return inc, out, cats
end

-- Estadísticas del periodo: mejor día, media diaria, días con actividad
function ns.PeriodStats(filter, period)
    local byDay = {}
    EachChar(filter, function(c)
        for dk, day in pairs(c.days) do
            local e = byDay[dk] or { i = 0, o = 0 }; byDay[dk] = e
            for _, v in pairs(day) do e.i, e.o = e.i + v.i, e.o + v.o end
        end
    end)
    local valid
    if period ~= "all" then
        valid = {}
        for n = 0, PERIOD_DAYS[period] - 1 do valid[DayKey(time() - n * DAY)] = true end
    end
    local best, bestKey, sumNet, active = nil, nil, 0, 0
    for dk, e in pairs(byDay) do
        if not valid or valid[dk] then
            local net = e.i - e.o
            if e.i > 0 or e.o > 0 then
                active = active + 1
                sumNet = sumNet + net
                if not best or net > best then best, bestKey = net, dk end
            end
        end
    end
    return {
        bestNet = best or 0, bestDay = bestKey,
        avg = active > 0 and sumNet / active or 0, active = active,
    }
end

-- Serie diaria de los últimos n días (antiguo -> reciente)
function ns.DailySeries(filter, n)
    local series = {}
    for i = n - 1, 0, -1 do
        local t = time() - i * DAY
        local dk = DayKey(t)
        local e = { t = t, i = 0, o = 0 }
        EachChar(filter, function(c)
            local day = c.days[dk]
            if day then for _, v in pairs(day) do e.i, e.o = e.i + v.i, e.o + v.o end end
        end)
        series[#series + 1] = e
    end
    return series
end

function ns.History(filter, period, limit, catFilter)
    local since = (period == "all") and 0 or ns.MidnightDaysAgo(PERIOD_DAYS[period] - 1)
    local list = {}
    EachChar(filter, function(c, k)
        for i = #c.tx, 1, -1 do
            local e = c.tx[i]
            if e[1] < since then break end
            if not catFilter or e[3] == catFilter then
                list[#list + 1] = { t = e[1], d = e[2], cat = e[3], zone = e[4], char = c.name or k, class = c.class }
            end
        end
    end)
    table.sort(list, function(a, b) return a.t > b.t end)
    if #list > limit then for i = #list, limit + 1, -1 do list[i] = nil end end
    return list
end

function ns.TotalMoney(filter)
    local sum, n, peak = 0, 0, 0
    EachChar(filter, function(c)
        sum = sum + (c.money or 0); n = n + 1
        peak = peak + (c.peak or 0)
    end)
    return sum, n, peak
end

---------------------------------------------------------------------------
-- Detección del origen del dinero
---------------------------------------------------------------------------
local open, stamp = {}, {}
local mailCat
local function Recent(k, w) return stamp[k] and (GetTime() - stamp[k]) <= (w or 1.5) end
local function Mark(k) stamp[k] = GetTime() end

local function Classify(delta)
    if Recent("repair", 1.5) or (open.vendor and delta < 0 and InRepairMode and InRepairMode()) then return "repair" end
    if open.quest or Recent("quest", 2) then return "quest" end
    if open.loot or Recent("loot", 1.5) then return "loot" end
    if open.taxi or Recent("taxi", 3) then return "taxi" end
    if open.trainer then return "trainer" end
    if open.auction then return "auction" end
    if open.mail or Recent("mail", 1) then
        if delta > 0 and mailCat then local c = mailCat; mailCat = nil; return c end
        return "mail"
    end
    if open.trade or Recent("trade", 3) then return "trade" end
    if open.vendor or Recent("vendor", 1) then return "vendor" end
    return "other"
end

local OPEN = {
    MERCHANT_SHOW = "vendor", MAIL_SHOW = "mail", TRADE_SHOW = "trade", TAXIMAP_OPENED = "taxi",
    TRAINER_SHOW = "trainer", AUCTION_HOUSE_SHOW = "auction", LOOT_OPENED = "loot", QUEST_COMPLETE = "quest",
}
local CLOSE = {
    MERCHANT_CLOSED = "vendor", MAIL_CLOSED = "mail", TRADE_CLOSED = "trade", TAXIMAP_CLOSED = "taxi",
    TRAINER_CLOSED = "trainer", AUCTION_HOUSE_CLOSED = "auction", LOOT_CLOSED = "loot", QUEST_FINISHED = "quest",
}
local STAMP = { QUEST_TURNED_IN = "quest", CHAT_MSG_MONEY = "loot" }

local function HookSafe(name, fn) if _G[name] then hooksecurefunc(name, fn) end end

local function InstallHooks()
    HookSafe("RepairAllItems", function() Mark("repair") end)
    HookSafe("TakeTaxiNode", function() Mark("taxi") end)
    HookSafe("TakeInboxMoney", function(index)
        local sender = select(3, GetInboxHeaderInfo(index))
        sender = sender and sender:lower() or ""
        mailCat = (sender:find("subasta") or sender:find("auction")) and "auction" or "mail"
    end)
    HookSafe("AutoLootMailItem", function(index)
        local sender = select(3, GetInboxHeaderInfo(index))
        sender = sender and sender:lower() or ""
        mailCat = (sender:find("subasta") or sender:find("auction")) and "auction" or "mail"
    end)
end

local ev = CreateFrame("Frame")
local lastMoney

local function OnMoney()
    local now = GetMoney()
    if not lastMoney then lastMoney = now return end
    local delta = now - lastMoney
    lastMoney = now
    char.money = now
    if now > (char.peak or 0) then char.peak = now end
    if delta == 0 then return end

    local cat = Classify(delta)
    if cat == "other" and C_Timer then
        -- a veces el mensaje de botín llega justo después: reintenta un instante
        C_Timer.After(0.3, function() AddRecord(delta, Classify(delta)) end)
    else
        AddRecord(delta, cat)
    end
end

ev:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then
            InitDB()
            InstallHooks()
            if ns.OnInit then ns.OnInit() end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not lastMoney then
            lastMoney = GetMoney()
            char.money = lastMoney
            char.level = UnitLevel("player")
            if lastMoney > (char.peak or 0) then char.peak = lastMoney end
        end
    elseif event == "PLAYER_MONEY" then
        OnMoney()
    elseif OPEN[event] then
        open[OPEN[event]] = true
    elseif CLOSE[event] then
        open[CLOSE[event]] = nil
        Mark(CLOSE[event])
    elseif STAMP[event] then
        Mark(STAMP[event])
    elseif event == "PLAYER_LEVEL_UP" then
        char.level = ...
    end
end)

N.Reg(ev, "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_MONEY", "PLAYER_LEVEL_UP")
for e in pairs(OPEN) do N.Reg(ev, e) end
for e in pairs(CLOSE) do N.Reg(ev, e) end
for e in pairs(STAMP) do N.Reg(ev, e) end

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
SLASH_TESORERO1, SLASH_TESORERO2 = "/tesorero", "/tesoro"
SlashCmdList.TESORERO = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local P = "|cffffd100Tesorero:|r "
    if msg == "reset confirmar" then
        db.chars[charKey] = nil
        InitDB()
        char.money, char.peak = GetMoney(), GetMoney()
        print(P .. Tr("historial de este personaje borrado."))
        if ns.OnDataChanged then ns.OnDataChanged() end
    elseif msg == "reset" then
        print(P .. Tr("esto borrará TODO el historial de ") .. charKey .. Tr(". Escribe |cffffff00/tesoro reset confirmar|r para hacerlo."))
    elseif msg == "minimapa" then
        print(P .. Tr("botón del minimapa (compartido, Nexo) ") .. (N.ToggleMinimap() and "oculto" or "visible") .. ".")
    elseif msg == "ayuda" or msg == "help" then
        print(P .. "comandos:")
        print(Tr("  |cffffff00/tesoro|r - abrir/cerrar la ventana"))
        print(Tr("  |cffffff00/tesoro minimapa|r - mostrar/ocultar el botón del minimapa"))
        print(Tr("  |cffffff00/tesoro reset|r - borrar el historial de este personaje"))
    else
        if ns.Toggle then ns.Toggle() end
    end
end
