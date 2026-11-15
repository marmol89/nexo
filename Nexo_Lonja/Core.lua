-- Lonja: precios de la casa de subastas
--
-- Datos guardados (LonjaDB):
--   realms[reino - facción] = {
--       items[id] = { p = precio mínimo por unidad (cobre), n = unidades a la venta, t = cuándo se vio,
--                     h = { [día] = precio mínimo de ese día }, name, q = calidad, i = icono },
--       lastScan = hora del último escaneo completo, lastCount = objetos distintos que encontró }
--   settings = { tooltip, pos }
--
-- Otros addons leen los precios con la tabla global Lonja:
--   Lonja.Price(id)   -> precio por unidad, hora en que se vio, unidades a la venta (nil si no hay precio)
--   Lonja.Money(c)    -> texto con las monedas
local ADDON, ns = ...
if Nexo.Antiguo(ADDON) then return end

local P = "|cfff0786aLonja:|r "
local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)

local HISTORY_DAYS = 14     -- días de historial que se conservan por objeto
local FRESH = 3600          -- una página suelta no sube un precio visto hace menos de esto
local PAGE = 50             -- subastas por página en la API clásica
local CHUNK = 1000          -- subastas que se leen por fotograma en un escaneo rápido

---------------------------------------------------------------------------
-- Formato
---------------------------------------------------------------------------
-- Money(cobre, tamaño, full): el del núcleo. full = todas las monedas; si no, versión compacta
ns.Money = Nexo.Money

function ns.Ago(t) return Nexo.Ago(t, "nunca") end

---------------------------------------------------------------------------
-- Base de datos
---------------------------------------------------------------------------
local db, realm, realmKey
local indexCache

local function InitDB()
    LonjaDB = LonjaDB or {}
    db = LonjaDB
    db.realms = db.realms or {}
    db.settings = db.settings or {}

    -- Cada facción tiene su propia casa de subastas
    realmKey = GetRealmName() .. " - " .. (UnitFactionGroup("player") or "Neutral")
    db.realms[realmKey] = db.realms[realmKey] or {}
    realm = db.realms[realmKey]
    realm.items = realm.items or {}
    ns.db, ns.realm, ns.realmKey = db, realm, realmKey
    indexCache = nil
end

local function Changed()
    indexCache = nil
    if ns.OnDataChanged then ns.OnDataChanged() end
end

-- Rastro de lo último que ha pasado, guardado en LonjaDB.debug para poder diagnosticar fallos
local function Trace(msg)
    db.debug = db.debug or {}
    table.insert(db.debug, 1, date("%H:%M:%S ") .. msg)
    for i = #db.debug, 16, -1 do db.debug[i] = nil end
end

---------------------------------------------------------------------------
-- Guardar lo observado
---------------------------------------------------------------------------
-- obs[id] = { p = precio mínimo por unidad, n = unidades, name, q, i }
local function Observe(obs, id, count, buyout, name, quality, icon)
    if not id or id == 0 or not buyout or buyout <= 0 then return end   -- sin precio de compra no cuenta
    count = (count and count > 0) and count or 1
    local unit = max(1, floor(buyout / count + 0.5))
    local o = obs[id]
    if not o then
        o = { p = unit, n = 0 }
        obs[id] = o
    end
    if unit < o.p then o.p = unit end
    o.n = o.n + count
    if name and name ~= "" then o.name = name end
    o.q = quality or o.q
    o.i = icon or o.i
end

-- full = lo observado es toda la casa de subastas (manda sobre lo guardado);
-- si no, es solo una parte y no puede subir un precio reciente
local function Apply(obs, full)
    local now, day = time(), Nexo.DayKey()
    local cutoff = Nexo.DayKey(now - HISTORY_DAYS * 86400)
    local count = 0
    for id, o in pairs(obs) do
        count = count + 1
        local it = realm.items[id]
        if not it then
            it = {}
            realm.items[id] = it
        end
        if full or not it.p or o.p < it.p or now - (it.t or 0) > FRESH then it.p = o.p end
        if full or not it.n or o.n > it.n or now - (it.t or 0) > FRESH then it.n = o.n end
        it.t = now
        it.name, it.q, it.i = o.name or it.name, o.q or it.q, o.i or it.i
        it.h = it.h or {}
        it.h[day] = (full or not it.h[day]) and o.p or min(it.h[day], o.p)
        for d in pairs(it.h) do
            if d < cutoff then it.h[d] = nil end
        end
    end
    return count
end

---------------------------------------------------------------------------
-- Lectura de subastas
---------------------------------------------------------------------------
-- Las dos API antiguas (lista de la subasta y réplica) devuelven lo mismo, en el mismo orden
local function ReadOne(getter, i, obs)
    local name, texture, count, quality, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = getter(i)
    Observe(obs, itemID, count, buyout, name, quality, texture)
end

local function LegacyGetter(i) return GetAuctionItemInfo("list", i) end
local function ReplicateGetter(i) return C_AuctionHouse.GetReplicateItemInfo(i) end

local ahOpen = false
local scan            -- escaneo en marcha: { mode, obs, page, total, read, waiting, sent, retries, reading }
local driver = CreateFrame("Frame")

function ns.IsOpen() return ahOpen end
function ns.Scanning() return scan ~= nil end

-- Texto del estado del escaneo, o nil si no hay ninguno en marcha
function ns.ScanStatus()
    if not scan then return nil end
    if scan.mode == "pages" then
        local pages = scan.total and max(1, math.ceil(scan.total / PAGE))
        return "Escaneando página " .. (scan.page + 1) .. (pages and (" de " .. pages) or "") .. "..."
    end
    if scan.reading and scan.total and scan.total > 0 then
        return ("Leyendo subastas: %d%%"):format(floor((scan.read or 0) / scan.total * 100))
    end
    return "Esperando la lista de subastas..."
end

local function StopScan(full, why)
    local s = scan
    scan = nil
    driver:SetScript("OnUpdate", nil)
    if not s then return end
    local count = Apply(s.obs, full)
    if full then
        realm.lastScan, realm.lastCount = time(), count
        print(P .. "escaneo completo: " .. Nexo.Plural(count, "objeto distinto", "objetos distintos") .. " con precio.")
    else
        print(P .. "escaneo interrumpido" .. (why and (" (" .. why .. ")") or "") .. ": guardados " ..
            Nexo.Plural(count, "objeto", "objetos") .. " de lo que dio tiempo a leer.")
    end
    Trace(("fin modo=%s completo=%s objetos=%d %s"):format(s.mode, tostring(full), count, why or ""))
    Changed()
end
function ns.StopScan() StopScan(false, "parado a mano") end

-- Lee de first a last repartido en varios fotogramas, para no congelar el juego
local function ReadChunks(getter, first, last)
    scan.reading, scan.total, scan.read = true, last - first + 1, 0
    local i = first
    local function step()
        local s = scan
        if not s or not s.reading then return end
        local stop = min(i + CHUNK - 1, last)
        local ok, err = pcall(function()
            for k = i, stop do ReadOne(getter, k, s.obs) end
        end)
        if not ok then
            Trace("ERROR leyendo: " .. tostring(err))
            return StopScan(false, "error al leer")
        end
        s.read = stop - first + 1
        i = stop + 1
        if ns.OnScanProgress then ns.OnScanProgress() end
        if i > last then StopScan(true) else C_Timer.After(0, step) end
    end
    step()
end

-- Escaneo por páginas: pide la siguiente cuando el servidor deja
local function PagesTick()
    local s = scan
    if not s or s.mode ~= "pages" then return end
    if s.waiting then
        if GetTime() - s.sent > 15 then
            s.retries = (s.retries or 0) + 1
            if s.retries > 3 then return StopScan(false, "el servidor no responde") end
            s.waiting = false
        end
        return
    end
    if CanSendAuctionQuery and not CanSendAuctionQuery() then return end
    s.waiting, s.sent = true, GetTime()
    QueryAuctionItems("", nil, nil, s.page, nil, nil, false, false, nil)
end

local function OnLegacyList()
    local batch, total = GetNumAuctionItems("list")
    batch, total = batch or 0, total or 0
    if scan and scan.mode == "getall" then
        if scan.reading then return end
        Trace("lista rápida: " .. batch .. " subastas")
        if batch == 0 then return StopScan(true) end
        return ReadChunks(LegacyGetter, 1, batch)
    elseif scan and scan.mode == "pages" then
        if not scan.waiting then return end
        for i = 1, batch do ReadOne(LegacyGetter, i, scan.obs) end
        scan.total, scan.retries = total, 0
        if ns.OnScanProgress then ns.OnScanProgress() end
        if batch == 0 or (scan.page + 1) * PAGE >= total then return StopScan(true) end
        scan.page = scan.page + 1
        scan.waiting = false
    elseif not scan and batch > 0 and batch <= PAGE * 4 then
        -- Una búsqueda tuya en la subasta: se apunta lo que se ve en la página
        local obs = {}
        for i = 1, batch do ReadOne(LegacyGetter, i, obs) end
        if next(obs) then
            Apply(obs, false)
            Changed()
        end
    end
end

local function OnReplicateList()
    if not scan or scan.mode ~= "replicate" or scan.reading then return end
    local n = C_AuctionHouse.GetNumReplicateItems() or 0
    Trace("réplica: " .. n .. " subastas")
    if n == 0 then return StopScan(true) end
    ReadChunks(ReplicateGetter, 0, n - 1)
end

-- Devuelve true si el escaneo ha empezado
function ns.StartScan()
    if scan then
        print(P .. "ya hay un escaneo en marcha.")
        return false
    end
    if not ahOpen then
        print(P .. "abre la casa de subastas para escanear.")
        return false
    end
    if QueryAuctionItems and GetNumAuctionItems and GetAuctionItemInfo then
        local canAll = false
        if CanSendAuctionQuery then canAll = select(2, CanSendAuctionQuery()) end
        if canAll then
            scan = { mode = "getall", obs = {} }
            print(P .. "escaneo rápido en marcha. El juego puede quedarse parado unos segundos.")
            QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)
        else
            scan = { mode = "pages", obs = {}, page = 0 }
            print(P .. "el escaneo rápido solo se puede usar cada 15 minutos; escaneando página a página (tarda más). " ..
                "No cierres la subasta ni busques nada mientras tanto.")
            driver:SetScript("OnUpdate", PagesTick)
        end
    elseif C_AuctionHouse and C_AuctionHouse.ReplicateItems then
        scan = { mode = "replicate", obs = {} }
        print(P .. "escaneo en marcha. Puede tardar un rato en llegar la lista.")
        C_AuctionHouse.ReplicateItems()
    else
        print(P .. "este cliente no permite escanear la subasta entera. Los precios se apuntan según vayas buscando.")
        return false
    end
    Trace("inicio modo=" .. scan.mode)
    if ns.OnScanProgress then ns.OnScanProgress() end
    return true
end

-- API moderna (C_AuctionHouse): se apunta lo que vas viendo al buscar
local function OnBrowseResults()
    local obs = {}
    for _, r in ipairs(C_AuctionHouse.GetBrowseResults() or {}) do
        local id = r.itemKey and r.itemKey.itemID
        if id and r.minPrice and r.minPrice > 0 then
            obs[id] = { p = r.minPrice, n = r.totalQuantity or 0 }
        end
    end
    if next(obs) then
        Apply(obs, false)
        Changed()
    end
end

local function OnCommodityResults(id)
    local n = id and C_AuctionHouse.GetNumCommoditySearchResults(id) or 0
    local obs = {}
    for i = 1, n do
        local r = C_AuctionHouse.GetCommoditySearchResultInfo(id, i)
        if r and r.unitPrice then
            local q = r.quantity or 1
            Observe(obs, id, q, r.unitPrice * q)
        end
    end
    if next(obs) then
        Apply(obs, true)      -- la lista de un material es completa: manda sobre lo guardado
        Changed()
    end
end

local function OnItemResults(itemKey)
    local id = itemKey and itemKey.itemID
    local n = id and C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    local obs = {}
    for i = 1, n do
        local r = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        if r then Observe(obs, id, r.quantity or 1, r.buyoutAmount) end
    end
    if next(obs) then
        Apply(obs, false)
        Changed()
    end
end

-- Muchos eventos seguidos = una sola lectura
local function Queue(what, fn, ...)
    Nexo.Debounce("Lonja." .. what, 0.3, function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            Trace("ERROR " .. what .. ": " .. tostring(err))
            error(err, 0)   -- Nexo lo pasa al gestor de errores
        end
    end, ...)
end

---------------------------------------------------------------------------
-- Consultas
---------------------------------------------------------------------------
-- Precio por unidad, hora en que se vio y unidades a la venta
function ns.Price(id)
    local it = id and realm and realm.items[id]
    if it and it.p then return it.p, it.t, it.n end
end

function ns.ItemInfo(id)
    local it = realm.items[id]
    local name, quality, icon = it and it.name, it and it.q, it and it.i
    if (not name or not quality or not icon) and GetItemInfo then
        local n, _, q, _, _, _, _, _, _, tex = GetItemInfo(id)   -- nil hasta que el cliente tenga el objeto en caché
        name, quality, icon = name or n, quality or q, icon or tex
        if it and n then it.name, it.q, it.i = name, quality, icon end
    end
    return name or ("Objeto " .. id), quality or 1, icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Unidades de un objeto en bolsas y bancos de la cuenta según Alijo (nil si Alijo no está)
function ns.Have(id)
    if Alijo and Alijo.Have then return Alijo.Have(id, true) end
end

function ns.HasAlijo() return AlijoDB ~= nil and AlijoDB.chars ~= nil end

-- Todos los objetos con precio: { id, name, lower, q, icon, p, t, n, have, value }
function ns.Index()
    if indexCache then return indexCache end
    local list = {}
    for id, it in pairs(realm.items) do
        if it.p then
            local name, quality, icon = ns.ItemInfo(id)
            local have = ns.Have(id) or 0
            list[#list + 1] = { id = id, name = name, lower = name:lower(), q = quality, icon = icon,
                                p = it.p, t = it.t, n = it.n or 0, have = have, value = have * it.p }
        end
    end
    indexCache = list
    return list
end

-- Lo que tienes cambia sin que Lonja se entere: la ventana lo pide al abrirse
function ns.Invalidate() indexCache = nil end

function ns.Count()
    local n = 0
    for _, it in pairs(realm.items) do
        if it.p then n = n + 1 end
    end
    return n
end

-- Historial de un objeto, del día más reciente al más antiguo: { day, p }
function ns.History(id)
    local it = realm.items[id]
    local list = {}
    for day, p in pairs(it and it.h or {}) do list[#list + 1] = { day = day, p = p } end
    table.sort(list, function(a, b) return a.day > b.day end)
    return list
end

-- Lo que vale en la lonja lo guardado en bolsas y bancos, según Alijo.
-- Devuelve el total y la lista por personaje: { key, name, class, value }
function ns.AccountValue()
    if not ns.HasAlijo() then return nil end
    local total, list = 0, {}
    local function sum(items)
        local v = 0
        for id, n in pairs(items or {}) do
            local p = ns.Price(id)
            if p then v = v + p * n end
        end
        return v
    end
    for key, c in pairs(AlijoDB.chars) do
        local v = sum(c.bags) + sum(c.bank)
        if v > 0 then
            list[#list + 1] = { key = key, name = c.name or Nexo.ShortName(key), class = c.class, value = v }
            total = total + v
        end
    end
    local w = AlijoDB.warband and sum(AlijoDB.warband.items) or 0
    if w > 0 then
        list[#list + 1] = { key = "@banda", name = "Banco de la banda", value = w }
        total = total + w
    end
    table.sort(list, function(a, b) return a.value > b.value end)
    return total, list
end

function ns.TooltipEnabled() return db and db.settings.tooltip ~= false end

-- Para los demás addons
Lonja = {
    Price = function(id) if realm then return ns.Price(id) end end,
    Money = ns.Money,
}

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
        -- La facción puede no saberse todavía al cargar el addon
        if realmKey ~= GetRealmName() .. " - " .. (UnitFactionGroup("player") or "Neutral") then
            InitDB()
            Changed()
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        ahOpen = true
        if ns.OnAuctionShow then ns.OnAuctionShow() end
        Changed()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ahOpen = false
        if scan then StopScan(false, "se cerró la subasta") end
        Changed()
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then
        if GetNumAuctionItems then Queue("legacy", OnLegacyList) end
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        Queue("replicate", OnReplicateList)
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        Queue("browse", OnBrowseResults)
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        Queue("commodity", OnCommodityResults, ...)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        Queue("item", OnItemResults, ...)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if indexCache then Queue("names", Changed) end
    end
end)

Nexo.Reg(ev, "ADDON_LOADED", "PLAYER_LOGIN", "GET_ITEM_INFO_RECEIVED",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_ITEM_LIST_UPDATE",
    "REPLICATE_ITEM_LIST_UPDATE", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED")

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
local function PrintSearch(text)
    local low, n = text:lower(), 0
    local list = ns.Index()
    table.sort(list, function(a, b) return a.lower < b.lower end)
    for _, e in ipairs(list) do
        if e.lower:find(low, 1, true) then
            n = n + 1
            if n <= 15 then print("  " .. e.name .. ": " .. ns.Money(e.p, 12, true) .. " |cff888888(" .. ns.Ago(e.t) .. ")|r") end
        end
    end
    if n == 0 then
        print(P .. "no hay ningún precio guardado que contenga \"" .. text .. "\".")
    elseif n > 15 then
        print("  ... y " .. (n - 15) .. " más.")
    end
end

local function PrintDiag()
    local function has(v) return v and "sí" or "no" end
    print(P .. "diagnóstico:")
    print("  reino: " .. realmKey .. " · objetos con precio: " .. ns.Count() .. " · último escaneo: " .. ns.Ago(realm.lastScan))
    print("  subasta abierta: " .. has(ahOpen) .. " · API clásica (QueryAuctionItems): " .. has(QueryAuctionItems) ..
        " · API moderna (C_AuctionHouse): " .. has(C_AuctionHouse))
    if CanSendAuctionQuery then
        local can, canAll = CanSendAuctionQuery()
        print("  puede consultar: " .. has(can) .. " · escaneo rápido disponible: " .. has(canAll))
    end
    if C_AuctionHouse then
        print("  réplica (ReplicateItems): " .. has(C_AuctionHouse.ReplicateItems) ..
            " · resultados de búsqueda (GetBrowseResults): " .. has(C_AuctionHouse.GetBrowseResults))
    end
    for _, line in ipairs(db.debug or {}) do print("  " .. line) end
end

SLASH_LONJA1 = "/lonja"
SlashCmdList.LONJA = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local low = msg:lower()
    if low == "escanear" then
        ns.StartScan()
    elseif low == "parar" then
        if scan then ns.StopScan() else print(P .. "no hay ningún escaneo en marcha.") end
    elseif low == "tooltip" then
        db.settings.tooltip = not ns.TooltipEnabled()
        print(P .. "precio en el tooltip de los objetos " .. (db.settings.tooltip and "activado" or "desactivado") .. ".")
    elseif low == "minimapa" then
        print(P .. "botón del minimapa (compartido, Nexo) " .. (Nexo.ToggleMinimap() and "oculto" or "visible") .. ".")
    elseif low == "reset confirmar" then
        db.realms[realmKey] = nil
        InitDB()
        Changed()
        print(P .. "precios de " .. realmKey .. " borrados.")
    elseif low == "reset" then
        print(P .. "esto borrará todos los precios guardados de " .. realmKey .. ". Escribe |cffffff00/lonja reset confirmar|r para hacerlo.")
    elseif low == "diag" then
        PrintDiag()
    elseif low == "ayuda" or low == "help" then
        print(P .. "comandos:")
        print("  |cffffff00/lonja|r - abrir/cerrar la ventana")
        print("  |cffffff00/lonja <texto>|r - abrir buscando ese texto en los precios guardados")
        print("  |cffffff00/lonja escanear|r - escanear la casa de subastas (tiene que estar abierta)")
        print("  |cffffff00/lonja parar|r - parar el escaneo en marcha")
        print("  |cffffff00/lonja tooltip|r - activar/desactivar el precio en el tooltip de los objetos")
        print("  |cffffff00/lonja minimapa|r - mostrar/ocultar el botón del minimapa")
        print("  |cffffff00/lonja reset|r - borrar los precios guardados de este reino")
        print("  |cffffff00/lonja diag|r - mostrar qué API de subasta tiene el cliente y los últimos escaneos")
    elseif msg ~= "" then
        if ns.OpenSearch then ns.OpenSearch(msg) else PrintSearch(msg) end
    else
        if ns.Toggle then ns.Toggle() else PrintSearch("") end
    end
end
