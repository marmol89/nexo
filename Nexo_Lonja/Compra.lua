local Tr = Nexo.T
-- Lonja: lista de compra
--
-- Datos guardados (dentro de cada reino de LonjaDB):
--   buy[id] = { p = precio máximo por unidad (cobre), n = unidades que quedan por comprar }
--
-- El juego no deja a un addon comprar por su cuenta: cada compra tiene que salir de un clic.
-- Lonja prepara la compra (qué objeto, cuántas unidades, a qué precio) y el botón de la
-- subasta la va haciendo paso a paso: buscar -> comprar -> confirmar (solo los materiales).
local ADDON, ns = ...
if Nexo.Antiguo(ADDON) then return end

local P = "|cfff0786aLonja:|r "
local AH = C_AuctionHouse
local floor, min = math.floor, math.min
local WAIT = 6              -- segundos antes de dar por perdida una respuesta de la subasta
local COMMODITY = 2         -- Enum.ItemCommodityStatus.Commodity

local job                   -- compra en marcha: { id, step, t, commodity, qty, cost, auctionID, money }
local skip = {}             -- objetos que al buscarlos ya no estaban a su precio (hasta el próximo escaneo)
local tried = {}            -- subastas por las que ya se ha pujado (para no insistir si falla)
local EMPTY = {}

local function Notify()
    if ns.OnDataChanged then ns.OnDataChanged() end
end

local function Name(id) return (ns.ItemInfo(id)) end

---------------------------------------------------------------------------
-- Dinero escrito a mano
---------------------------------------------------------------------------
-- "1.5" (oro), "1g 50s" o "80s 20c" -> cobre; nil si no se entiende
function ns.ParseMoney(text)
    text = ((text or ""):lower():gsub(",", "."))
    local total
    if text:find("%a") then
        local g = tonumber(text:match("([%d%.]+)%s*[go]")) or 0
        local s = tonumber(text:match("([%d%.]+)%s*[sp]")) or 0
        local c = tonumber(text:match("([%d%.]+)%s*c")) or 0
        total = g * 10000 + s * 100 + c
    else
        total = (tonumber(text) or 0) * 10000
    end
    total = floor(total + 0.5)
    if total > 0 then return total end
end

-- 15020 -> "1g 50s 20c", para rellenar el cuadro del precio
function ns.MoneyPlain(c)
    local g, s, cu = floor(c / 10000), floor(c / 100) % 100, c % 100
    local out = {}
    if g > 0 then out[#out + 1] = g .. "g" end
    if s > 0 then out[#out + 1] = s .. "s" end
    if cu > 0 or #out == 0 then out[#out + 1] = cu .. "c" end
    return table.concat(out, " ")
end

---------------------------------------------------------------------------
-- La lista
---------------------------------------------------------------------------
function ns.BuyList()
    local realm = ns.realm
    if not realm then return EMPTY end
    realm.buy = realm.buy or {}
    return realm.buy
end

function ns.BuyGet(id) return id and ns.BuyList()[id] end

function ns.BuyCount()
    local n = 0
    for _ in pairs(ns.BuyList()) do n = n + 1 end
    return n
end

function ns.BuySet(id, price, qty)
    ns.BuyList()[id] = { p = price, n = qty }
    skip[id] = nil
    Notify()
end

function ns.BuyRemove(id)
    ns.BuyList()[id] = nil
    if job and job.id == id then job = nil end
    Notify()
end

-- Objetos de la lista que están a su precio o por debajo: { id, p = precio visto, max, n }
function ns.Deals()
    local list = {}
    for id, b in pairs(ns.BuyList()) do
        local p = ns.Price(id)
        if p and p <= b.p and not skip[id] then
            list[#list + 1] = { id = id, p = p, max = b.p, n = b.n }
        end
    end
    table.sort(list, function(a, b)
        local x, y = (a.max - a.p) * a.n, (b.max - b.p) * b.n      -- primero donde más se ahorra
        if x ~= y then return x > y end
        return a.id < b.id
    end)
    return list
end

local function Announce()
    local deals = ns.Deals()
    if #deals == 0 then return end
    print(P .. Nexo.Plural(#deals, "objeto de tu lista está", "objetos de tu lista están") .. Tr(" a tu precio o por debajo:"))
    for i = 1, min(#deals, 5) do
        local d = deals[i]
        print((Tr("  %s: %s (máximo %s) · quedan %d")):format(Name(d.id), ns.Money(d.p, 12, true), ns.Money(d.max, 12, true), d.n))
    end
    if #deals > 5 then print(Tr("  ... y ") .. (#deals - 5) .. Tr(" más.")) end
    print(Tr("  Pulsa el botón |cffffff00Lonja: comprar|r de encima de la subasta: cada compra pide un clic tuyo."))
end

function ns.OnScanDone()
    wipe(skip)
    Announce()
end

---------------------------------------------------------------------------
-- Comprar
---------------------------------------------------------------------------
local function Bought(id, qty, cost)
    local b = ns.BuyGet(id)
    print(P .. (Tr("comprado %d × %s por %s.")):format(qty, Name(id), ns.Money(cost, 12, true)))
    if not b then return end
    b.n = b.n - qty
    if b.n <= 0 then
        ns.BuyList()[id] = nil
        print(P .. Name(id) .. Tr(": ya tienes todo lo que querías; sale de la lista de compra."))
    end
end

local function Finish(ok)
    local j = job
    job = nil
    if not j then return end
    if ok then
        Bought(j.id, j.qty, j.cost)
    else
        print(P .. Tr("no se pudo comprar ") .. Name(j.id) .. ".")
    end
    Notify()
end

-- Al buscarlo, ya no hay nada a ese precio
local function Nothing(id, why)
    skip[id] = true
    job = nil
    print(P .. Name(id) .. ": " .. (why or Tr("ya no hay nada a tu precio")) .. ".")
    Notify()
end

local function Search(id)
    local order = Enum and Enum.AuctionHouseSortOrder
    local commodity = AH.GetItemCommodityStatus and AH.GetItemCommodityStatus(id) == COMMODITY
    local sorts = order and { { sortOrder = commodity and order.Price or order.Buyout, reverseSort = false } } or {}
    job = { id = id, step = "search", t = GetTime() }
    AH.SendSearchQuery(AH.MakeItemKey(id), sorts, false)
end

-- Materiales: se compran las unidades más baratas hasta el precio máximo, lo que quede por comprar y el dinero que haya
local function OnCommodityResults(id)
    if not job or job.id ~= id or (job.step ~= "search" and job.step ~= "ready") then return end
    local b = ns.BuyGet(id)
    if not b then job = nil return Notify() end
    local qty, cost, money, short = 0, 0, GetMoney(), false
    for i = 1, AH.GetNumCommoditySearchResults(id) or 0 do
        local r = AH.GetCommoditySearchResultInfo(id, i)
        if r and r.unitPrice and r.unitPrice > 0 and r.unitPrice <= b.p then
            local avail = (r.quantity or 0) - (r.numOwnerItems or 0)     -- las tuyas no se pueden comprar
            local afford = floor((money - cost) / r.unitPrice)
            if afford < min(avail, b.n - qty) then short = true end
            local take = min(avail, b.n - qty, afford)
            if take > 0 then
                qty = qty + take
                cost = cost + take * r.unitPrice
            end
        end
    end
    if qty == 0 then return Nothing(id, short and Tr("no te llega el dinero")) end
    job.step, job.commodity, job.qty, job.cost = "ready", true, qty, cost
    Notify()
end

-- Objetos sueltos: la subasta más barata que quepa en el precio y en lo que queda por comprar
local function OnItemResults(itemKey)
    local id = itemKey and itemKey.itemID
    if not job or job.id ~= id or (job.step ~= "search" and job.step ~= "ready") then return end
    local b = ns.BuyGet(id)
    if not b then job = nil return Notify() end
    local best, money, short = nil, GetMoney(), false
    for i = 1, AH.GetNumItemSearchResults(itemKey) or 0 do
        local r = AH.GetItemSearchResultInfo(itemKey, i)
        local q = r and r.quantity or 1
        if r and r.auctionID and r.buyoutAmount and r.buyoutAmount > 0 and not r.containsOwnerItem
            and not tried[r.auctionID] and q <= b.n and r.buyoutAmount / q <= b.p then
            if r.buyoutAmount > money then
                short = true
            elseif not best or r.buyoutAmount / q < best.buyoutAmount / (best.quantity or 1) then
                best = r
            end
        end
    end
    if not best then return Nothing(id, short and Tr("no te llega el dinero")) end
    job.step, job.commodity = "ready", false
    job.auctionID, job.qty, job.cost = best.auctionID, best.quantity or 1, best.buyoutAmount
    Notify()
end

-- El juego dice lo que cuesta de verdad la compra de un material antes de confirmarla
local function OnCommodityPrice(_, total)
    if not job or job.step ~= "quote" then return end
    local b = ns.BuyGet(job.id)
    if not b or not total or total > job.qty * b.p then
        if AH.CancelCommoditiesPurchase then AH.CancelCommoditiesPurchase() end
        local id = job.id
        job = nil
        print(P .. Name(id) .. Tr(" ha cambiado de precio mientras tanto; vuelve a pulsar para buscarlo otra vez."))
    else
        job.step, job.cost = "confirm", total
    end
    Notify()
end

-- Texto del botón de compra y si el siguiente clic gasta dinero. nil si la lista está vacía
function ns.BuyStatus()
    if ns.BuyCount() == 0 then return nil end
    if ns.Scanning() then return Tr("Lista de compra: escaneando..."), false end
    if job then
        local name = Name(job.id)
        if job.step == "search" then return Tr("Buscando ") .. name .. "...", false end
        if job.step == "quote" then return Tr("Pidiendo precio de ") .. name .. "...", false end
        if job.step == "buying" then return Tr("Comprando ") .. name .. "...", false end
        local what = (job.qty > 1 and (job.qty .. " × ") or "") .. name .. " · " .. ns.Money(job.cost, 11)
        return (job.step == "confirm" and Tr("Confirmar ") or Tr("Comprar ")) .. what, true
    end
    local deals = ns.Deals()
    if #deals == 0 then return Tr("Lista de compra: nada a tu precio"), false end
    return Tr("Buscar ") .. Name(deals[1].id) .. " (" .. #deals .. Tr(" a tu precio)"), false
end

-- Un clic = un paso. Tiene que llamarse desde el clic de un botón: el juego no acepta compras de otra forma
function ns.BuyClick()
    if not (AH and AH.SendSearchQuery and AH.MakeItemKey) then
        return print(P .. Tr("este cliente no deja comprar desde un addon."))
    end
    if not ns.IsOpen() then return print(P .. Tr("abre la casa de subastas para comprar.")) end
    if ns.Scanning() then return print(P .. Tr("espera a que termine el escaneo.")) end
    if job and job.step ~= "ready" and job.step ~= "confirm" then
        if GetTime() - job.t < WAIT then return end        -- esperando la respuesta de la subasta
        if job.step == "quote" and AH.CancelCommoditiesPurchase then AH.CancelCommoditiesPurchase() end
        job = nil
    end
    if AH.IsThrottledMessageSystemReady and not AH.IsThrottledMessageSystemReady() then
        return print(P .. Tr("la subasta pide esperar un momento; vuelve a pulsar."))
    end

    if not job then
        local deal = ns.Deals()[1]
        if not deal then return print(P .. Tr("nada de tu lista de compra está a tu precio.")) end
        Search(deal.id)
    elseif job.step == "ready" and job.commodity then
        job.step, job.t = "quote", GetTime()
        AH.StartCommoditiesPurchase(job.id, job.qty)
    elseif job.step == "ready" then
        local j = job
        j.step, j.t, j.money = "buying", GetTime(), GetMoney()
        tried[j.auctionID] = true
        AH.PlaceBid(j.auctionID, j.cost)
        -- Por si el cliente no avisa de la compra: se mira si el dinero ha bajado
        C_Timer.After(4, function()
            if job == j and j.step == "buying" then Finish(GetMoney() <= j.money - j.cost) end
        end)
    else
        job.step, job.t = "buying", GetTime()
        AH.ConfirmCommoditiesPurchase(job.id, job.qty)
    end
    Notify()
end

---------------------------------------------------------------------------
-- Comandos (los reparte Core.lua)
---------------------------------------------------------------------------
function ns.PrintBuyList()
    local list = ns.BuyList()
    if not next(list) then
        print(P .. Tr("la lista de compra está vacía. Elige un objeto en la ventana de Lonja y ponle precio y cantidad,"))
        print(Tr("  o escribe ") .. "|cffffff00/lonja " .. Nexo.Cmd("lonja", "buy") .. Tr(" <enlace del objeto> <precio máximo> <cantidad>|r."))
        return
    end
    print(P .. Tr("lista de compra:"))
    for _, id in ipairs(Nexo.Keys(list)) do
        local b, p = list[id], ns.Price(id)
        print((Tr("  %s: %d a %s como mucho · %s")):format(Name(id), b.n, ns.Money(b.p, 12, true),
            p and (Tr("ahora a ") .. ns.Money(p, 12, true) .. (p <= b.p and Tr(" |cff66ff66(a tu precio)|r") or "")) or Tr("sin precio visto")))
    end
end

-- "<enlace o id> <precio> <cantidad>"
function ns.BuyCommand(text)
    local id, rest = Nexo.ItemID(text), text:match("|h|r%s*(.*)$")
    if not id then
        id, rest = text:match("^(%d+)%s+(.*)$")
        id = tonumber(id)
    end
    local price, qty = (rest or ""):match("^(.-)%s+(%d+)$")
    price, qty = ns.ParseMoney(price), tonumber(qty)
    if not id or not price or not qty or qty < 1 then
        print(P .. Tr("uso: ") .. "|cffffff00/lonja " .. Nexo.Cmd("lonja", "buy") .. Tr(" <enlace del objeto> <precio máximo por unidad> <cantidad>|r"))
        print(Tr("  El precio va en oro (|cffffff001.5|r) o con monedas (|cffffff001g 50s|r). Ejemplo:")
            .. " /lonja " .. Nexo.Cmd("lonja", "buy") .. " [Paño de lino] 0.02 40")
        return
    end
    ns.BuySet(id, price, qty)
    print(P .. (Tr("%s: comprar %d a %s como mucho.")):format(Name(id), qty, ns.Money(price, 12, true)))
end

function ns.BuyRemoveCommand(text)
    local id = Nexo.ItemID(text) or tonumber(text)
    if not id or not ns.BuyGet(id) then return print(P .. Tr("ese objeto no está en la lista de compra.")) end
    ns.BuyRemove(id)
    print(P .. Name(id) .. Tr(" quitado de la lista de compra."))
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")

ev:SetScript("OnEvent", function(self, event, ...)
    if event == "AUCTION_HOUSE_SHOW" then
        -- Si no arranca un escaneo automático, se avisa con los precios que ya había
        C_Timer.After(1.5, function()
            if ns.IsOpen() and not ns.Scanning() then Announce() end
        end)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        job = nil
        wipe(skip)
        wipe(tried)
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        OnCommodityResults(...)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        OnItemResults(...)
    elseif event == "COMMODITY_PRICE_UPDATED" then
        OnCommodityPrice(...)
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        if job and job.commodity and job.step == "buying" then Finish(true) end
    elseif event == "COMMODITY_PURCHASE_FAILED" then
        if job and job.commodity and (job.step == "buying" or job.step == "quote") then Finish(false) end
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        if job and not job.commodity and job.step == "buying" and ... == job.auctionID then Finish(true) end
    end
end)

Nexo.Reg(ev, "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
    "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_PRICE_UPDATED",
    "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED", "AUCTION_HOUSE_PURCHASE_COMPLETED")
