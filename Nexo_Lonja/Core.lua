local Tr = Nexo.T
Nexo.Dict({
    ["no hay ningún precio guardado que contenga \""] = "there is no saved price containing \"",
    ["Aún no hay precios. Abre la casa de subastas y pulsa \"Escanear subasta\"."] = "No prices yet. Open the auction house and press \"Scan auction\".",
    ["\"Escanear subasta\" para empezar.|r"] = "\"Scan auction\" to start.|r",
    ["objeto de tu lista está"] = "item on your list is",
    ["objetos de tu lista están"] = "items on your list are",
    ["Escaneando página "] = " Scanning page ",
    ["Leyendo subastas: %d%%"] = "Reading auctions: %d%%",
    ["Esperando la lista de subastas..."] = "Waiting for the auction list...",
    ["escaneo completo: "] = "full scan: ",
    [" con precio."] = " with price.",
    ["escaneo interrumpido"] = "scan interrupted",
    [": guardados "] = ": saved ",
    [" de lo que dio tiempo a leer."] = " of what there was time to read.",
    ["parado a mano"] = "stopped manually",
    ["ERROR leyendo: "] = "ERROR reading: ",
    ["error al leer"] = "read error",
    ["el servidor no responde"] = "the server does not respond",
    ["lista rápida: "] = "quick list: ",
    [" subastas"] = " auctions",
    ["réplica: "] = "replica: ",
    ["ya hay un escaneo en marcha."] = "a scan is already running.",
    ["abre la casa de subastas para escanear."] = "open the auction house to scan.",
    ["escaneo automático"] = "automatic scan",
    [" rápido en marcha. El juego puede quedarse parado unos segundos."] = " quick in progress. The game may freeze for a few seconds.",
    ["el escaneo rápido solo se puede usar cada 15 minutos; escaneando página a página (tarda más). "] = "the quick scan can only be used every 15 minutes; scanning page by page (takes longer). ",
    ["No cierres la subasta ni busques nada mientras tanto."] = "Do not close the auction or search for anything meanwhile.",
    ["precios de "] = "prices of ",
    ["; el juego no deja escanear otra vez hasta dentro de "] = "; the game does not let you scan again until within ",
    [" en marcha. Puede tardar un rato en llegar la lista."] = " in progress. It may take a while for the list to arrive.",
    ["este cliente no permite escanear la subasta entera. Los precios se apuntan según vayas buscando."] = "this client does not allow scanning the whole auction. Prices are recorded as you search.",
    ["se cerró la subasta"] = "the auction was closed",
    ["sí"] = "yes",
    ["diagnóstico:"] = "diagnostics:",
    ["  reino: "] = "  realm: ",
    [" · objetos con precio: "] = " · items with price: ",
    [" · último escaneo: "] = " · last scan: ",
    ["  subasta abierta: "] = "  auction open: ",
    [" · API clásica (QueryAuctionItems): "] = " · classic API (QueryAuctionItems): ",
    [" · API moderna (C_AuctionHouse): "] = " · modern API (C_AuctionHouse): ",
    ["  puede consultar: "] = "  can query: ",
    [" · escaneo rápido disponible: "] = " · quick scan available: ",
    ["  réplica (ReplicateItems): "] = "  replica (ReplicateItems): ",
    [" · resultados de búsqueda (GetBrowseResults): "] = " · search results (GetBrowseResults): ",
    ["no hay ningún escaneo en marcha."] = "no scan is running.",
    ["escaneo automático al abrir la subasta "] = "automatic scan when opening the auction ",
    ["precio en el tooltip de los objetos "] = "price in the item tooltip ",
    [" borrados."] = " deleted.",
    ["esto borrará todos los precios guardados de "] = "this will delete all the saved prices of ",
    [". Escribe |cffffff00/lonja reset confirmar|r para hacerlo."] = ". Type |cffffff00/lonja reset confirmar|r to do it.",
    ["  |cffffff00/lonja|r - abrir/cerrar la ventana"] = "  |cffffff00/lonja|r - open/close the window",
    ["  |cffffff00/lonja <texto>|r - abrir buscando ese texto en los precios guardados"] = "  |cffffff00/lonja <texto>|r - open searching that text in the saved prices",
    ["  |cffffff00/lonja escanear|r - escanear la casa de subastas (tiene que estar abierta)"] = "  |cffffff00/lonja escanear|r - scan the auction house (it must be open)",
    ["  |cffffff00/lonja parar|r - parar el escaneo en marcha"] = "  |cffffff00/lonja parar|r - stop the scan in progress",
    ["  |cffffff00/lonja auto|r - activar/desactivar el escaneo automático al abrir la subasta"] = "  |cffffff00/lonja auto|r - turn the automatic scan on opening the auction on/off",
    ["  |cffffff00/lonja comprar|r - ver la lista de compra"] = "  |cffffff00/lonja comprar|r - see the shopping list",
    ["  |cffffff00/lonja comprar <enlace> <precio> <cantidad>|r - apuntar un objeto en la lista de compra"] = "  |cffffff00/lonja comprar <enlace> <precio> <cantidad>|r - add an item to the shopping list",
    ["  |cffffff00/lonja quitar <enlace>|r - quitarlo de la lista de compra"] = "  |cffffff00/lonja quitar <enlace>|r - remove it from the shopping list",
    ["  |cffffff00/lonja tooltip|r - activar/desactivar el precio en el tooltip de los objetos"] = "  |cffffff00/lonja tooltip|r - turn the price in the item tooltip on/off",
    ["  |cffffff00/lonja minimapa|r - mostrar/ocultar el botón del minimapa"] = "  |cffffff00/lonja minimapa|r - show/hide the minimap button",
    ["  |cffffff00/lonja reset|r - borrar los precios guardados de este reino"] = "  |cffffff00/lonja reset|r - delete the saved prices of this realm",
    ["  |cffffff00/lonja diag|r - mostrar qué API de subasta tiene el cliente y los últimos escaneos"] = "  |cffffff00/lonja diag|r - show which auction API the client has and the last scans",
    [" objeto de tu lista está"] = " item on your list is",
    [" objetos de tu lista están"] = " items on your list are",
    [" a tu precio o por debajo:"] = " at your price or below:",
    ["  %s: %s (máximo %s) · quedan %d"] = "  %s: %s (max %s) · %d left",
    ["  Pulsa el botón |cffffff00Lonja: comprar|r de encima de la subasta: cada compra pide un clic tuyo."] = "  Press the |cffffff00Lonja: buy|r button above the auction: each purchase needs one click from you.",
    ["comprado %d × %s por %s."] = "bought %d × %s for %s.",
    [": ya tienes todo lo que querías; sale de la lista de compra."] = ": you already have everything you wanted; it leaves the shopping list.",
    ["no se pudo comprar "] = "could not buy ",
    ["ya no hay nada a tu precio"] = "nothing is at your price anymore",
    ["no te llega el dinero"] = "you don't have enough money",
    [" ha cambiado de precio mientras tanto; vuelve a pulsar para buscarlo otra vez."] = " changed price in the meantime; press again to search for it again.",
    ["Lista de compra: escaneando..."] = "Shopping list: scanning...",
    ["Buscando "] = "Searching ",
    ["Pidiendo precio de "] = "Requesting price of ",
    ["Comprando "] = "Buying ",
    ["Confirmar "] = "Confirm ",
    ["Comprar "] = "Buy ",
    ["Lista de compra: nada a tu precio"] = "Shopping list: nothing at your price",
    ["Buscar "] = "Search ",
    [" a tu precio)"] = " at your price)",
    ["este cliente no deja comprar desde un addon."] = "this client does not allow buying from an addon.",
    ["abre la casa de subastas para comprar."] = "open the auction house to buy.",
    ["espera a que termine el escaneo."] = "wait for the scan to finish.",
    ["la subasta pide esperar un momento; vuelve a pulsar."] = "the auction asks to wait a moment; press again.",
    ["nada de tu lista de compra está a tu precio."] = "nothing on your shopping list is at your price.",
    ["la lista de compra está vacía. Elige un objeto en la ventana de Lonja y ponle precio y cantidad,"] = "the shopping list is empty. Choose an item in the Lonja window and set a price and quantity,",
    ["  o escribe |cffffff00/lonja comprar <enlace del objeto> <precio máximo> <cantidad>|r."] = "  or type |cffffff00/lonja comprar <enlace del objeto> <precio máximo> <cantidad>|r.",
    ["lista de compra:"] = "shopping list:",
    ["  %s: %d a %s como mucho · %s"] = "  %s: %d at %s at most · %s",
    ["ahora a "] = "now at ",
    [" |cff66ff66(a tu precio)|r"] = " |cff66ff66(at your price)|r",
    ["sin precio visto"] = "no price seen",
    ["uso: |cffffff00/lonja comprar <enlace del objeto> <precio máximo por unidad> <cantidad>|r"] = "usage: |cffffff00/lonja comprar <enlace del objeto> <precio máximo por unidad> <cantidad>|r",
    ["  El precio va en oro (|cffffff001.5|r) o con monedas (|cffffff001g 50s|r). Ejemplo: /lonja comprar [Paño de lino] 0.02 40"] = "  The price is in gold (|cffffff001.5|r) or in coins (|cffffff001g 50s|r). Example: /lonja comprar [Paño de lino] 0.02 40",
    ["%s: comprar %d a %s como mucho."] = "%s: buy %d at %s at most.",
    ["ese objeto no está en la lista de compra."] = "that item is not on the shopping list.",
    [" quitado de la lista de compra."] = " removed from the shopping list.",
    ["Precios de la casa de subastas · WoW Forever"] = "Auction house prices · WoW Forever",
    ["Escanear subasta"] = "Scan auction",
    ["Escanear la casa de subastas"] = "Scan the auction house",
    ["Guarda el precio de compra más bajo de cada objeto."] = "Saves the lowest buyout price of each item.",
    ["Tiene que estar abierta la ventana de la subasta."] = "The auction window must be open.",
    ["Lista de compra: precio máximo por unidad y cantidad"] = "Shopping list: max price per unit and quantity",
    ["Oro: 1.5"] = "Gold: 1.5",
    ["Lonja:|r pon el precio máximo por unidad (en oro: 1.5, o 1g 50s) y cuántas unidades quieres."] = "Lonja:|r set the max price per unit (in gold: 1.5, or 1g 50s) and how many units you want.",
    ["Precios guardados"] = "Saved prices",
    ["Objetos con precio"] = "Items with price",
    ["Último escaneo completo"] = "Last full scan",
    ["Escanear al abrir la subasta"] = "Scan when opening the auction",
    ["sí|r"] = "yes|r",
    ["Lista de compra"] = "Shopping list",
    ["Objetos apuntados"] = "Items listed",
    ["A tu precio ahora"] = "At your price now",
    ["Abre la casa de subastas y pulsa|r"] = "Open the auction house and press|r",
    ["Valor de lo guardado"] = "Value of what's saved",
    ["Con Alijo activado verás lo que vale|r"] = "With Alijo enabled you will see what it is worth|r",
    ["lo que tienes en bolsas y bancos.|r"] = "what you have in bags and banks.|r",
    ["Toda la cuenta"] = "Whole account",
    ["Nada de lo que tienes tiene precio.|r"] = "None of what you have has a price.|r",
    ["Mínimo por unidad"] = "Minimum per unit",
    ["sin ver|r"] = "not seen|r",
    ["Unidades a la venta"] = "Units for sale",
    ["Tienes en la cuenta"] = "You have in the account",
    ["Valor de lo tuyo"] = "Value of yours",
    ["Comprar hasta"] = "Buy up to",
    ["Quedan por comprar"] = "Left to buy",
    ["Ahora está a tu precio|r"] = "Now it is at your price|r",
    ["Parar escaneo"] = "Stop scan",
    ["Lonja: parar"] = "Lonja: stop",
    ["Lonja: escanear"] = "Lonja: scan",
    ["  ·  |cff66ff66subasta abierta|r: las búsquedas que hagas también se apuntan"] = "  ·  |cff66ff66auction open|r: the searches you make are also recorded",
    ["  ·  último escaneo "] = "  ·  last scan ",
    ["  ·  Mayús+clic: enlazar en el chat"] = "  ·  Shift+click: link in chat",
    ["Lista de compra de Lonja"] = "Lonja shopping list",
    ["Cada clic da un paso: buscar el objeto, comprarlo y,"] = "Each click takes a step: search the item, buy it and,",
    ["si es un material, confirmar el precio final."] = "if it is a material, confirm the final price.",
    ["El juego no deja comprar a un addon sin un clic tuyo."] = "The game does not let an addon buy without a click from you.",
    ["Resaltado: el siguiente clic gasta dinero."] = "Highlighted: the next click spends money.",
    ["Máximo"] = "Max",
    ["Solo lo que tengo"] = "Only what I have",
    ["Todos los objetos"] = "All items",
    ["Lista de compra ("] = "Shopping list (",
    ["La lista de compra está vacía. Elige un objeto y ponle precio máximo y cantidad."] = "The shopping list is empty. Choose an item and set a max price and quantity.",
    ["Nada de lo que tienes guardado tiene precio en la lonja."] = "None of what you have saved has a price at the auction house.",
    ["Último escaneo"] = "Last scan",
})
-- Lonja: precios de la casa de subastas
--
-- Datos guardados (LonjaDB):
--   realms[reino - facción] = {
--       items[id] = { p = precio mínimo por unidad (cobre), n = unidades a la venta, t = cuándo se vio,
--                     h = { [día] = precio mínimo de ese día }, name, q = calidad, i = icono },
--       lastScan = hora del último escaneo completo, lastCount = objetos distintos que encontró,
--       buy = lista de compra (ver Compra.lua) }
--   settings = { tooltip, pos, auto = false si no se quiere escanear al abrir la subasta }
--   replicateAt = hora en que se pidió la última lista completa (el juego solo la da cada 15 minutos)
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
local FULL_WAIT = 15 * 60 + 10  -- el juego solo da la lista completa cada 15 minutos

---------------------------------------------------------------------------
-- Formato
---------------------------------------------------------------------------
-- Money(cobre, tamaño, full): el del núcleo. full = todas las monedas; si no, versión compacta
ns.Money = Nexo.Money

function ns.Ago(t) return Nexo.Ago(t, Tr("nunca")) end

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
    Nexo.Trace(db.debug, msg, 15)
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
        return Tr("Escaneando página ") .. (scan.page + 1) .. (pages and (" de " .. pages) or "") .. "..."
    end
    if scan.reading and scan.total and scan.total > 0 then
        return (Tr("Leyendo subastas: %d%%")):format(floor((scan.read or 0) / scan.total * 100))
    end
    return Tr("Esperando la lista de subastas...")
end

local function StopScan(full, why)
    local s = scan
    scan = nil
    driver:SetScript("OnUpdate", nil)
    if not s then return end
    local count = Apply(s.obs, full)
    if full then
        realm.lastScan, realm.lastCount = time(), count
        print(P .. Tr("escaneo completo: ") .. Nexo.Plural(count, Tr("objeto distinto"), Tr("objetos distintos")) .. Tr(" con precio."))
    else
        print(P .. Tr("escaneo interrumpido") .. (why and (" (" .. why .. ")") or "") .. Tr(": guardados ") ..
            Nexo.Plural(count, "objeto", "objetos") .. Tr(" de lo que dio tiempo a leer."))
    end
    Trace(("fin modo=%s completo=%s objetos=%d %s"):format(s.mode, tostring(full), count, why or ""))
    if full and ns.OnScanDone then ns.OnScanDone() end
    Changed()
end
function ns.StopScan() StopScan(false, Tr("parado a mano")) end

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
            Trace(Tr("ERROR leyendo: ") .. tostring(err))
            return StopScan(false, Tr("error al leer"))
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
            if s.retries > 3 then return StopScan(false, Tr("el servidor no responde")) end
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
        Trace(Tr("lista rápida: ") .. batch .. Tr(" subastas"))
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
    Trace(Tr("réplica: ") .. n .. Tr(" subastas"))
    if n == 0 then return StopScan(true) end
    ReadChunks(ReplicateGetter, 0, n - 1)
end

function ns.AutoScan() return db and db.settings.auto ~= false end

-- Devuelve true si el escaneo ha empezado.
-- auto = lo ha pedido Lonja al abrirse la subasta: solo arranca si puede ser el escaneo rápido, y sin protestar
function ns.StartScan(auto)
    local function say(text) if not auto then print(P .. text) end end
    if scan then
        say(Tr("ya hay un escaneo en marcha."))
        return false
    end
    if not ahOpen then
        say(Tr("abre la casa de subastas para escanear."))
        return false
    end
    local head = auto and Tr("escaneo automático") or Tr("escaneo")
    if QueryAuctionItems and GetNumAuctionItems and GetAuctionItemInfo then
        local canAll = false
        if CanSendAuctionQuery then canAll = select(2, CanSendAuctionQuery()) end
        if canAll then
            scan = { mode = "getall", obs = {} }
            print(P .. head .. Tr(" rápido en marcha. El juego puede quedarse parado unos segundos."))
            QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)
        elseif auto then
            return false
        else
            scan = { mode = "pages", obs = {}, page = 0 }
            print(P .. Tr("el escaneo rápido solo se puede usar cada 15 minutos; escaneando página a página (tarda más). ") ..
                Tr("No cierres la subasta ni busques nada mientras tanto."))
            driver:SetScript("OnUpdate", PagesTick)
        end
    elseif C_AuctionHouse and C_AuctionHouse.ReplicateItems then
        -- Dentro de los 15 minutos el juego no contesta: el automático espera a la próxima vez
        local last = max(db.replicateAt or 0, realm.lastScan or 0)
        if auto and time() - last < FULL_WAIT then
            print(P .. Tr("precios de ") .. ns.Ago(last) .. Tr("; el juego no deja escanear otra vez hasta dentro de ") ..
                Nexo.Dur(max(60, FULL_WAIT - (time() - last))) .. ".")
            return false
        end
        scan = { mode = "replicate", obs = {} }
        db.replicateAt = time()
        print(P .. head .. Tr(" en marcha. Puede tardar un rato en llegar la lista."))
        C_AuctionHouse.ReplicateItems()
    else
        say(Tr("este cliente no permite escanear la subasta entera. Los precios se apuntan según vayas buscando."))
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
    return name or (Tr("Objeto ") .. id), quality or 1, icon or "Interface\\Icons\\INV_Misc_QuestionMark"
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
        list[#list + 1] = { key = "@banda", name = Tr("Banco de la banda"), value = w }
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
        if ns.AutoScan() then
            -- Un momento después: al abrirse, la subasta todavía no acepta consultas
            C_Timer.After(1, function()
                if ahOpen and not scan then ns.StartScan(true) end
            end)
        end
        Changed()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ahOpen = false
        if scan then StopScan(false, Tr("se cerró la subasta")) end
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
        print(P .. Tr("no hay ningún precio guardado que contenga \"") .. text .. "\".")
    elseif n > 15 then
        print(Tr("  ... y ") .. (n - 15) .. Tr(" más."))
    end
end

local function PrintDiag()
    local function has(v) return v and Tr("sí") or Tr("no") end
    print(P .. Tr("diagnóstico:"))
    print(Tr("  reino: ") .. realmKey .. Tr(" · objetos con precio: ") .. ns.Count() .. Tr(" · último escaneo: ") .. ns.Ago(realm.lastScan))
    print(Tr("  subasta abierta: ") .. has(ahOpen) .. Tr(" · API clásica (QueryAuctionItems): ") .. has(QueryAuctionItems) ..
        Tr(" · API moderna (C_AuctionHouse): ") .. has(C_AuctionHouse))
    if CanSendAuctionQuery then
        local can, canAll = CanSendAuctionQuery()
        print(Tr("  puede consultar: ") .. has(can) .. Tr(" · escaneo rápido disponible: ") .. has(canAll))
    end
    if C_AuctionHouse then
        print(Tr("  réplica (ReplicateItems): ") .. has(C_AuctionHouse.ReplicateItems) ..
            Tr(" · resultados de búsqueda (GetBrowseResults): ") .. has(C_AuctionHouse.GetBrowseResults))
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
        if scan then ns.StopScan() else print(P .. Tr("no hay ningún escaneo en marcha.")) end
    elseif low == "auto" then
        db.settings.auto = not ns.AutoScan()
        print(P .. Tr("escaneo automático al abrir la subasta ") .. (db.settings.auto and Tr("activado") or Tr("desactivado")) .. ".")
    elseif low == "comprar" or low == "lista" then
        ns.PrintBuyList()
    elseif low:find("^comprar%s") then
        ns.BuyCommand(msg:sub(9):gsub("^%s+", ""))
    elseif low:find("^quitar%s") then
        ns.BuyRemoveCommand(msg:sub(8):gsub("^%s+", ""))
    elseif low == "tooltip" then
        db.settings.tooltip = not ns.TooltipEnabled()
        print(P .. Tr("precio en el tooltip de los objetos ") .. (db.settings.tooltip and Tr("activado") or Tr("desactivado")) .. ".")
    elseif low == "minimapa" then
        print(P .. Tr("botón del minimapa (compartido, Nexo) ") .. (Nexo.ToggleMinimap() and Tr("oculto") or Tr("visible")) .. ".")
    elseif low == "reset confirmar" then
        local buy = realm.buy       -- la lista de compra no son precios: se conserva
        db.realms[realmKey] = nil
        InitDB()
        realm.buy = buy
        Changed()
        print(P .. Tr("precios de ") .. realmKey .. Tr(" borrados."))
    elseif low == "reset" then
        print(P .. Tr("esto borrará todos los precios guardados de ") .. realmKey .. Tr(". Escribe |cffffff00/lonja reset confirmar|r para hacerlo."))
    elseif low == "diag" then
        PrintDiag()
    elseif low == "ayuda" or low == "help" then
        print(P .. "comandos:")
        print(Tr("  |cffffff00/lonja|r - abrir/cerrar la ventana"))
        print(Tr("  |cffffff00/lonja <texto>|r - abrir buscando ese texto en los precios guardados"))
        print(Tr("  |cffffff00/lonja escanear|r - escanear la casa de subastas (tiene que estar abierta)"))
        print(Tr("  |cffffff00/lonja parar|r - parar el escaneo en marcha"))
        print(Tr("  |cffffff00/lonja auto|r - activar/desactivar el escaneo automático al abrir la subasta"))
        print(Tr("  |cffffff00/lonja comprar|r - ver la lista de compra"))
        print(Tr("  |cffffff00/lonja comprar <enlace> <precio> <cantidad>|r - apuntar un objeto en la lista de compra"))
        print(Tr("  |cffffff00/lonja quitar <enlace>|r - quitarlo de la lista de compra"))
        print(Tr("  |cffffff00/lonja tooltip|r - activar/desactivar el precio en el tooltip de los objetos"))
        print(Tr("  |cffffff00/lonja minimapa|r - mostrar/ocultar el botón del minimapa"))
        print(Tr("  |cffffff00/lonja reset|r - borrar los precios guardados de este reino"))
        print(Tr("  |cffffff00/lonja diag|r - mostrar qué API de subasta tiene el cliente y los últimos escaneos"))
    elseif msg ~= "" then
        if ns.OpenSearch then ns.OpenSearch(msg) else PrintSearch(msg) end
    else
        if ns.Toggle then ns.Toggle() else PrintSearch("") end
    end
end
