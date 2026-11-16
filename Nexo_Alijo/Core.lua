local Tr = Nexo.T
Nexo.Dict({
    ["Banco"] = "Bank",
    ["Equipado"] = "Equipped",
    ["recuento en el tooltip de los objetos "] = "count in the item tooltip ",
    ["inventario de "] = "inventory of ",
    ["  |cffffff00/alijo|r - abrir/cerrar la ventana"] = "  |cffffff00/alijo|r - open/close the window",
    ["  |cffffff00/alijo <texto>|r - abrir buscando ese texto"] = "  |cffffff00/alijo <texto>|r - open searching for that text",
    ["  |cffffff00/alijo tooltip|r - activar/desactivar el recuento en el tooltip de los objetos"] = "  |cffffff00/alijo tooltip|r - turn the item tooltip count on/off",
    ["  |cffffff00/alijo minimapa|r - mostrar/ocultar el botón del minimapa"] = "  |cffffff00/alijo minimapa|r - show/hide the minimap button",
    ["  |cffffff00/alijo olvidar <personaje>|r - borrar el inventario guardado de otro personaje"] = "  |cffffff00/alijo olvidar <personaje>|r - delete the saved inventory of another character",
    ["Bolsas "] = "Bags ",
    ["Banda "] = "Warband ",
    ["Banco "] = "Bank ",
    ["Equipado "] = "Equipped ",
    ["Inventario de la cuenta · WoW Forever"] = "Account inventory · WoW Forever",
    ["Bolsas"] = "Bags",
    ["Dónde"] = "Where",
    ["Quién lo tiene"] = "Who has it",
    ["Elige un objeto de la lista para ver quién lo tiene y dónde."] = "Pick an item from the list to see who has it and where.",
    ["Mayús+clic en la lista: enlazar en el chat"] = "Shift+click in the list: link in chat",
    ["Total en la cuenta: |cffffffff"] = "Total in the account: |cffffffff",
    ["|r  ·  vale "] = "|r  ·  worth ",
    ["y "] = "and ",
    [" más"] = " more",
    ["bolsas vistas "] = "bags seen ",
    ["banco visto "] = "bank seen ",
    ["|cffffb347banco sin registrar: ábrelo con este personaje|r"] = "|cffffb347bank not recorded: open it with this character|r",
    ["objeto"] = "item",
    ["objetos"] = "items",
    ["sitio"] = "place",
    ["sitios"] = "places",
    ["Aquí no hay nada registrado todavía."] = "Nothing recorded here yet.",
    ["Personajes registrados"] = "Registered characters",
    ["Objetos distintos"] = "Distinct items",
    ["Banco de "] = "Bank of ",
    ["este personaje"] = "this character",
    ["sin registrar"] = "not recorded",
})
-- Alijo: inventario de toda la cuenta
local ADDON, ns = ...
if Nexo.Antiguo(ADDON) then return end

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

    char, charKey = Nexo.InitChar(db.chars, { bags = {}, bank = {}, equip = {} })
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
local function RunScans()
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
    Nexo.Debounce("Alijo.scan", 0.4, RunScans)
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
    return name or (Tr("Objeto ") .. id), quality or 1, icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

function ns.CharList() return Nexo.Keys(db.chars) end

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
        local w = { name = Tr("Banco de la banda") }
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
        list[#list + 1] = { key = ns.WARBAND_KEY, name = Tr("Banco de la banda"), bags = 0, bank = w, equip = 0, total = w }
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

-- Para los demás addons
Alijo = {
    -- Unidades de un objeto en bolsas y bancos de toda la cuenta (lo equipado no cuenta);
    -- warband = sumar también el banco de la banda. nil si aún no hay datos.
    Have = function(id, warband)
        if not id or not db then return nil end
        local total = 0
        for _, c in pairs(db.chars) do
            total = total + (c.bags and c.bags[id] or 0) + (c.bank and c.bank[id] or 0)
        end
        local w = warband and db.warband and db.warband.items
        return total + (w and w[id] or 0)
    end,
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

Nexo.Reg(ev, "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LEVEL_UP",
    "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED",
    "PLAYERBANKSLOTS_CHANGED", "PLAYERREAGENTBANKSLOTS_CHANGED")

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
        print(P .. Tr("recuento en el tooltip de los objetos ") .. (db.settings.tooltip and Tr("activado") or Tr("desactivado")) .. ".")
    elseif low == "minimapa" then
        print(P .. Tr("botón del minimapa (compartido, Nexo) ") .. (Nexo.ToggleMinimap() and Tr("oculto") or Tr("visible")) .. ".")
    elseif low:match("^olvidar%s+%S") then
        local who = low:match("^olvidar%s+(.+)$")
        local found = Nexo.FindChar(db.chars, who, charKey)
        if found then
            db.chars[found] = nil
            print(P .. Tr("inventario de ") .. found .. Tr(" borrado."))
            if ns.OnDataChanged then ns.OnDataChanged() end
        else
            print(P .. Tr("no encuentro a otro personaje llamado \"") .. who .. "\".")
        end
    elseif low == "ayuda" or low == "help" then
        print(P .. "comandos:")
        print(Tr("  |cffffff00/alijo|r - abrir/cerrar la ventana"))
        print(Tr("  |cffffff00/alijo <texto>|r - abrir buscando ese texto"))
        print(Tr("  |cffffff00/alijo tooltip|r - activar/desactivar el recuento en el tooltip de los objetos"))
        print(Tr("  |cffffff00/alijo minimapa|r - mostrar/ocultar el botón del minimapa"))
        print(Tr("  |cffffff00/alijo olvidar <personaje>|r - borrar el inventario guardado de otro personaje"))
    elseif msg ~= "" then
        if ns.OpenSearch then ns.OpenSearch(msg) end
    else
        if ns.Toggle then ns.Toggle() end
    end
end
