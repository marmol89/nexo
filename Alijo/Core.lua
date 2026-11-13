-- Alijo: inventario de toda la cuenta
local ADDON, ns = ...

local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
local IsAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

ns.WARBAND_KEY = "@banda"

---------------------------------------------------------------------------
-- Contenedores (compatible con la API nueva y la antigua)
---------------------------------------------------------------------------
local function NumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    elseif GetContainerNumSlots then
        return GetContainerNumSlots(bag) or 0
    end
    return 0
end

-- Devuelve: itemID, cantidad, enlace, calidad, icono
local function SlotInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            local id = info.itemID or (info.hyperlink and tonumber(info.hyperlink:match("item:(%d+)")))
            return id, info.stackCount or 1, info.hyperlink, info.quality, info.iconFileID
        end
    elseif GetContainerItemInfo then
        local icon, count, _, quality, _, _, link, _, _, id = GetContainerItemInfo(bag, slot)
        if link then
            id = id or tonumber(link:match("item:(%d+)"))
            return id, count or 1, link, quality, icon
        end
    end
end

local BAGS, BANK, WARBAND = {}, {}, {}
do
    local numBags = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, numBags do BAGS[#BAGS + 1] = bag end
    if KEYRING_CONTAINER then BAGS[#BAGS + 1] = KEYRING_CONTAINER end

    local idx = Enum and Enum.BagIndex
    if idx and idx.CharacterBankTab_1 then
        -- banco moderno por pestañas
        for i = 1, 6 do
            local bag = idx["CharacterBankTab_" .. i]
            if bag then BANK[#BANK + 1] = bag end
        end
    else
        BANK[#BANK + 1] = BANK_CONTAINER or -1
        for bag = numBags + 1, numBags + (NUM_BANKBAGSLOTS or 7) do BANK[#BANK + 1] = bag end
        if REAGENTBANK_CONTAINER then BANK[#BANK + 1] = REAGENTBANK_CONTAINER end
    end
    if idx then
        for i = 1, 5 do
            local bag = idx["AccountBankTab_" .. i]
            if bag then WARBAND[#WARBAND + 1] = bag end
        end
    end
end
ns.hasWarband = #WARBAND > 0

---------------------------------------------------------------------------
-- Base de datos
---------------------------------------------------------------------------
local db, char, charKey

local function InitDB()
    AlijoDB = AlijoDB or {}
    db = AlijoDB
    db.chars = db.chars or {}
    db.items = db.items or {}          -- caché: [itemID] = { n = nombre, q = calidad, i = icono }
    db.warband = db.warband or { items = {} }
    db.settings = db.settings or {}

    charKey = Nexo.CharKey()
    db.chars[charKey] = db.chars[charKey] or { bags = {}, bank = {}, equip = {} }
    char = db.chars[charKey]
    local _, class = UnitClass("player")
    char.class = class
    char.name = UnitName("player")
    char.level = UnitLevel("player")
    ns.db, ns.char, ns.charKey = db, char, charKey
end

local function Remember(id, link, quality, icon)
    local it = db.items[id]
    if not it then
        it = {}
        db.items[id] = it
    end
    local name = link and link:match("%[(.-)%]")
    if name and name ~= "" then it.n = name end
    if (not quality or quality < 0) and GetItemInfo then
        local _, _, q = GetItemInfo(id)
        quality = q
    end
    if quality and quality >= 0 then it.q = quality end
    if icon then it.i = icon end
end

local function ScanContainers(list)
    local out = {}
    for _, bag in ipairs(list) do
        for slot = 1, NumSlots(bag) do
            local id, count, link, quality, icon = SlotInfo(bag, slot)
            if id then
                out[id] = (out[id] or 0) + (count or 1)
                Remember(id, link, quality, icon)
            end
        end
    end
    return out
end

local function ScanEquipment()
    local out = {}
    for slot = 1, 19 do
        local id = GetInventoryItemID("player", slot)
        if id then
            out[id] = (out[id] or 0) + 1
            Remember(id, GetInventoryItemLink("player", slot), GetInventoryItemQuality("player", slot), GetInventoryItemTexture("player", slot))
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Escaneo (agrupado: muchos eventos seguidos = un solo escaneo)
---------------------------------------------------------------------------
local bankOpen = false
local dirty = {}
local scheduled = false

local function RunScans()
    scheduled = false
    if not char then return end
    local now = time()
    if dirty.bags then
        char.bags = ScanContainers(BAGS)
        char.tBags = now
    end
    if dirty.equip then
        char.equip = ScanEquipment()
    end
    if dirty.bank and bankOpen then
        char.bank = ScanContainers(BANK)
        char.tBank = now
        if ns.hasWarband then
            db.warband.items = ScanContainers(WARBAND)
            db.warband.t = now
        end
    end
    dirty = {}
    if ns.OnDataChanged then ns.OnDataChanged() end
end

local function Queue(what)
    dirty[what] = true
    if not scheduled then
        scheduled = true
        C_Timer.After(0.4, RunScans)
    end
end

---------------------------------------------------------------------------
-- Consultas
---------------------------------------------------------------------------
function ns.ItemInfo(id)
    local it = db.items[id]
    local name, quality, icon = it and it.n, it and it.q, it and it.i
    if (not name or not quality) and GetItemInfo then
        local n, _, q, _, _, _, _, _, _, tex = GetItemInfo(id)
        name, quality, icon = name or n, quality or q, icon or tex
    end
    return name or ("Objeto " .. id), quality or 1, icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function ns.CharList()
    local list = {}
    for k in pairs(db.chars) do list[#list + 1] = k end
    table.sort(list)
    return list
end

-- Lista de objetos. filter = clave de personaje o nil; loc = all | bags | bank | equip | warband
function ns.Index(filter, loc)
    local map, list = {}, {}
    local function add(id, n, key, c, field)
        local e = map[id]
        if not e then
            local name, quality, icon = ns.ItemInfo(id)
            e = { id = id, name = name, lower = name:lower(), q = quality, icon = icon, total = 0, owners = {}, byKey = {} }
            map[id] = e
            list[#list + 1] = e
        end
        e.total = e.total + n
        local o = e.byKey[key]
        if not o then
            o = { key = key, name = c.name or key, class = c.class, bags = 0, bank = 0, equip = 0, total = 0 }
            e.byKey[key] = o
            e.owners[#e.owners + 1] = o
        end
        o[field] = o[field] + n
        o.total = o.total + n
    end

    if loc ~= "warband" then
        for key, c in pairs(db.chars) do
            if not filter or filter == key then
                if loc == "all" or loc == "bags" then
                    for id, n in pairs(c.bags or {}) do add(id, n, key, c, "bags") end
                end
                if loc == "all" or loc == "bank" then
                    for id, n in pairs(c.bank or {}) do add(id, n, key, c, "bank") end
                end
                if loc == "all" or loc == "equip" then
                    for id, n in pairs(c.equip or {}) do add(id, n, key, c, "equip") end
                end
            end
        end
    end
    if ns.hasWarband and (loc == "warband" or (loc == "all" and not filter)) then
        local w = { name = "Banco de la banda" }
        for id, n in pairs(db.warband.items or {}) do add(id, n, ns.WARBAND_KEY, w, "bank") end
    end
    for _, e in ipairs(list) do
        table.sort(e.owners, function(a, b) return a.total > b.total end)
        e.byKey = nil
    end
    return list
end

-- Quién tiene un objeto concreto (todos los personajes y sitios). Devuelve lista y total.
function ns.Owners(id)
    local list, total = {}, 0
    for key, c in pairs(db.chars) do
        local bags = c.bags and c.bags[id] or 0
        local bank = c.bank and c.bank[id] or 0
        local equip = c.equip and c.equip[id] or 0
        local sum = bags + bank + equip
        if sum > 0 then
            list[#list + 1] = { key = key, name = c.name or key, class = c.class, bags = bags, bank = bank, equip = equip, total = sum }
            total = total + sum
        end
    end
    local w = db.warband.items and db.warband.items[id]
    if w and w > 0 then
        list[#list + 1] = { key = ns.WARBAND_KEY, name = "Banco de la banda", bags = 0, bank = w, equip = 0, total = w }
        total = total + w
    end
    table.sort(list, function(a, b) return a.total > b.total end)
    return list, total
end

-- ¿Añadir el recuento al tooltip de los objetos? Por defecto sí, salvo que Bagnon ya lo haga.
function ns.TooltipEnabled()
    local s = db and db.settings.tooltip
    if s ~= nil then return s end
    return not (IsAddOnLoaded and IsAddOnLoaded("BagBrother"))
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
        C_Timer.After(2, function()
            Queue("bags")
            Queue("equip")
        end)
    elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        Queue("bags")
        if bankOpen then Queue("bank") end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        Queue("equip")
        Queue("bags")
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        Queue("bank")
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
    elseif event == "PLAYER_LEVEL_UP" then
        char.level = ...
    else
        -- PLAYERBANKSLOTS_CHANGED, PLAYERREAGENTBANKSLOTS_CHANGED, BAG_CONTAINER_UPDATE...
        if bankOpen then Queue("bank") end
    end
end)

local function Reg(e) pcall(ev.RegisterEvent, ev, e) end
Reg("ADDON_LOADED"); Reg("PLAYER_LOGIN"); Reg("PLAYER_LEVEL_UP")
Reg("BAG_UPDATE"); Reg("BAG_UPDATE_DELAYED"); Reg("PLAYER_EQUIPMENT_CHANGED")
Reg("BANKFRAME_OPENED"); Reg("BANKFRAME_CLOSED")
Reg("PLAYERBANKSLOTS_CHANGED"); Reg("PLAYERREAGENTBANKSLOTS_CHANGED")

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
SLASH_ALIJO1 = "/alijo"
SlashCmdList.ALIJO = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local low = msg:lower()
    local P = "|cff5cdb9eAlijo:|r "
    if low == "tooltip" then
        db.settings.tooltip = not ns.TooltipEnabled()
        print(P .. "recuento en el tooltip de los objetos " .. (db.settings.tooltip and "activado" or "desactivado") .. ".")
    elseif low == "minimapa" then
        print(P .. "botón del minimapa (compartido, Nexo) " .. (Nexo.ToggleMinimap() and "oculto" or "visible") .. ".")
    elseif low:match("^olvidar%s+%S") then
        local who = low:match("^olvidar%s+(.+)$")
        local found
        for key, c in pairs(db.chars) do
            if key ~= charKey and ((c.name or ""):lower() == who or key:lower() == who) then found = key end
        end
        if found then
            db.chars[found] = nil
            print(P .. "inventario de " .. found .. " borrado.")
            if ns.OnDataChanged then ns.OnDataChanged() end
        else
            print(P .. "no encuentro a otro personaje llamado \"" .. who .. "\".")
        end
    elseif low == "ayuda" or low == "help" then
        print(P .. "comandos:")
        print("  |cffffff00/alijo|r - abrir/cerrar la ventana")
        print("  |cffffff00/alijo <texto>|r - abrir buscando ese texto")
        print("  |cffffff00/alijo tooltip|r - activar/desactivar el recuento en el tooltip de los objetos")
        print("  |cffffff00/alijo minimapa|r - mostrar/ocultar el botón del minimapa")
        print("  |cffffff00/alijo olvidar <personaje>|r - borrar el inventario guardado de otro personaje")
    elseif msg ~= "" then
        if ns.OpenSearch then ns.OpenSearch(msg) end
    else
        if ns.Toggle then ns.Toggle() end
    end
end
