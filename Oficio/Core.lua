-- Oficio: profesiones de toda la cuenta (niveles, recetas y enfriamientos)
--
-- Datos guardados (OficioDB):
--   chars[clave] = { name, class, level,
--                    profs = { [profesión] = { rank, max, main, t, known = { [receta] = dificultad 1-4 } } },
--                    cds   = { [receta] = { prof, ready } } }      ready = hora en que vuelve a estar lista
--   recipes[profesión][receta] = { id = objeto fabricado, i = icono, r = { { id, n, name }, ... } }
local ADDON, ns = ...

local P = "|cffe0a84cOficio:|r "

-- Nombres de profesión conocidos (en minúsculas). true = secundaria.
local KNOWN = {
    ["alquimia"] = false, ["herrería"] = false, ["encantamiento"] = false, ["ingeniería"] = false,
    ["herboristería"] = false, ["peletería"] = false, ["minería"] = false, ["sastrería"] = false,
    ["desuello"] = false, ["cocina"] = true, ["primeros auxilios"] = true, ["pesca"] = true,
    ["alchemy"] = false, ["blacksmithing"] = false, ["enchanting"] = false, ["engineering"] = false,
    ["herbalism"] = false, ["leatherworking"] = false, ["mining"] = false, ["tailoring"] = false,
    ["skinning"] = false, ["cooking"] = true, ["first aid"] = true, ["fishing"] = true,
}
local DIFF = { optimal = 4, medium = 3, easy = 2, trivial = 1 }

---------------------------------------------------------------------------
-- Base de datos
---------------------------------------------------------------------------
local db, char, charKey

local function InitDB()
    OficioDB = OficioDB or {}
    db = OficioDB
    db.chars = db.chars or {}
    db.recipes = db.recipes or {}
    db.profNames = db.profNames or {}     -- profesiones vistas al abrir su ventana
    db.settings = db.settings or {}

    charKey = Nexo.CharKey()
    db.chars[charKey] = db.chars[charKey] or {}
    char = db.chars[charKey]
    char.profs = char.profs or {}
    char.cds = char.cds or {}
    local _, class = UnitClass("player")
    char.class = class
    char.name = UnitName("player")
    char.level = UnitLevel("player")
    ns.db, ns.char, ns.charKey = db, char, charKey
end

local function Prof(name)
    local p = char.profs[name]
    if not p then
        p = { known = {} }
        char.profs[name] = p
    end
    p.known = p.known or {}
    return p
end

local function Changed()
    if ns.OnDataChanged then ns.OnDataChanged() end
end

---------------------------------------------------------------------------
-- Niveles de profesión (pestaña de habilidades)
---------------------------------------------------------------------------
-- WoW Forever usa C_SkillInfo (devuelve una tabla); los clientes Classic, las funciones globales
local function SkillLine(i)
    if C_SkillInfo and C_SkillInfo.GetSkillLineInfo then
        local l = C_SkillInfo.GetSkillLineInfo(i)
        if not l then return end
        return l.name, l.isHeader, not l.isCollapsed, l.rank, l.maxRank, l.isAbandonable, l.skillID
    end
    local name, isHeader, isExpanded, rank, _, _, maxRank, isAbandonable = GetSkillLineInfo(i)
    return name, isHeader, isExpanded, rank, maxRank, isAbandonable
end

local function NumSkillLines()
    if C_SkillInfo and C_SkillInfo.GetNumSkillLines then return C_SkillInfo.GetNumSkillLines() or 0 end
    if GetNumSkillLines and GetSkillLineInfo then return GetNumSkillLines() or 0 end
    return 0
end

-- Identificadores de las líneas de habilidad que son profesiones (solo en la API moderna)
local SECONDARY_ID = { [185] = true, [129] = true, [356] = true }   -- cocina, primeros auxilios, pesca
local function ProfessionIDs()
    local set = {}
    if C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines then
        local ok, ids = pcall(C_TradeSkillUI.GetAllProfessionTradeSkillLines)
        if ok and type(ids) == "table" then
            for _, id in ipairs(ids) do set[id] = true end
        end
    end
    return set
end

local function ScanSkills()
    if not char then return end
    local n = NumSkillLines()
    if n == 0 then return end
    local ids = ProfessionIDs()
    local seen, collapsed = {}, false
    for i = 1, n do
        local name, isHeader, isExpanded, rank, maxRank, isAbandonable, skillID = SkillLine(i)
        if isHeader then
            if not isExpanded then collapsed = true end
        elseif name then
            local secondary = KNOWN[name:lower()]
            if secondary == nil and skillID and SECONDARY_ID[skillID] then secondary = true end
            if isAbandonable or secondary ~= nil or db.profNames[name] or (skillID and ids[skillID]) then
                local p = Prof(name)
                p.rank, p.max = rank or 0, maxRank or 0
                p.id = skillID or p.id
                p.main = not secondary
                p.t = time()
                seen[name] = true
            end
        end
    end
    -- Con todas las cabeceras abiertas, lo que no aparece es que se ha abandonado
    if not collapsed then
        for name in pairs(char.profs) do
            if not seen[name] then
                char.profs[name] = nil
                for recipe, cd in pairs(char.cds) do
                    if cd.prof == name then char.cds[recipe] = nil end
                end
            end
        end
    end
    Changed()
end

---------------------------------------------------------------------------
-- Recetas (ventana de profesión; encantamiento usa la ventana "Craft")
---------------------------------------------------------------------------
local function ItemID(link) return link and tonumber(link:match("item:(%d+)")) end

-- Guarda una receta conocida por este personaje, con sus datos compartidos y su enfriamiento
local function StoreRecipe(p, prof, name, diff, itemID, icon, reags, cd)
    p.known[name] = diff
    db.recipes[prof] = db.recipes[prof] or {}
    local r = db.recipes[prof][name] or {}
    db.recipes[prof][name] = r
    r.id = itemID or r.id
    r.i = icon or r.i
    if reags and #reags > 0 then r.r = reags end
    if cd and cd > 0 then
        char.cds[name] = { prof = prof, ready = time() + cd }
    elseif char.cds[name] then
        char.cds[name].ready = 0
    end
end

-- api = { line, count, info, link, icon, nReag, reag, reagLink, cooldown }
local function ScanRecipes(api)
    if not char or not api.line or not api.count or not api.info then return end
    local prof, rank, maxRank = api.line()
    if not prof or prof == "" or prof == "UNKNOWN" then return end
    local count = api.count() or 0
    if count == 0 then return end

    db.profNames[prof] = true
    local p = Prof(prof)
    if rank and rank > 0 then p.rank, p.max = rank, maxRank or p.max or 0 end
    if p.main == nil then p.main = not KNOWN[prof:lower()] end
    p.t = time()

    for i = 1, count do
        local name, kind = api.info(i)
        if name and kind ~= "header" then
            local reags = {}
            for j = 1, (api.nReag and api.nReag(i) or 0) do
                local rname, _, rcount = api.reag(i, j)
                local rid = ItemID(api.reagLink and api.reagLink(i, j))
                if rname or rid then reags[#reags + 1] = { id = rid, n = rcount or 1, name = rname } end
            end
            StoreRecipe(p, prof, name, DIFF[kind] or 1, ItemID(api.link and api.link(i)),
                api.icon and api.icon(i), reags, api.cooldown and api.cooldown(i))
        end
    end
    Changed()
end

-- API moderna (WoW Forever y Retail): C_TradeSkillUI
local MODERN_DIFF
local function ModernDiff(v)
    if not MODERN_DIFF then
        MODERN_DIFF = {}
        local codes = { Optimal = 4, Medium = 3, Easy = 2, Trivial = 1 }
        for k, id in pairs(Enum and Enum.TradeskillRelativeDifficulty or {}) do MODERN_DIFF[id] = codes[k] end
    end
    return v and MODERN_DIFF[v] or 1
end

-- Rastro de los últimos escaneos, guardado en OficioDB.debug para poder diagnosticar fallos
local function Trace(msg)
    db.debug = db.debug or {}
    table.insert(db.debug, 1, date("%H:%M:%S ") .. msg)
    for i = #db.debug, 13, -1 do db.debug[i] = nil end
end
ns.Trace = Trace

-- Nombre con el que ya está guardada la profesión que tiene ese identificador
local function NameByID(id)
    if not id then return end
    for name, p in pairs(char.profs) do
        if p.id == id then return name end
    end
end

local function ScanModernUnsafe()
    local T = C_TradeSkillUI
    if not char or not T or not T.GetAllRecipeIDs or not T.GetRecipeInfo then return Trace("sin API C_TradeSkillUI") end
    -- Solo tus propias profesiones: ni las enlazadas por otro jugador, ni las de hermandad, ni las de un PNJ
    if T.IsTradeSkillLinked and T.IsTradeSkillLinked() then return Trace("omitido: enlazada") end
    if T.IsTradeSkillGuild and T.IsTradeSkillGuild() then return Trace("omitido: hermandad") end
    if T.IsNPCCrafting and T.IsNPCCrafting() then return Trace("omitido: PNJ") end

    local base = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo() or {}
    local child = T.GetChildProfessionInfo and T.GetChildProfessionInfo() or {}
    local prof = NameByID(base.professionID) or NameByID(child.professionID) or NameByID(child.parentProfessionID)
    local function ok(v) return type(v) == "string" and v ~= "" and v end
    prof = prof or ok(base.professionName) or ok(child.parentProfessionName) or ok(child.professionName)
    local ids = T.GetAllRecipeIDs()
    local ready = T.IsTradeSkillReady and T.IsTradeSkillReady()
    Trace(("prof=%s baseID=%s base=%s child=%s recetas=%s lista=%s"):format(tostring(prof), tostring(base.professionID),
        tostring(base.professionName), tostring(child.professionName), type(ids) == "table" and #ids or tostring(ids), tostring(ready)))
    if not prof or type(ids) ~= "table" or #ids == 0 then return false end

    local rank = (base.skillLevel and base.skillLevel > 0 and base.skillLevel) or child.skillLevel
    local maxRank = (base.maxSkillLevel and base.maxSkillLevel > 0 and base.maxSkillLevel) or child.maxSkillLevel

    db.profNames[prof] = true
    local p = Prof(prof)
    if rank and rank > 0 and not p.rank then p.rank, p.max = rank, maxRank or 0 end
    if p.main == nil then p.main = not KNOWN[prof:lower()] end
    p.t = time()

    local learned = 0
    for _, id in ipairs(ids) do
        local info = T.GetRecipeInfo(id)
        if info and info.learned and info.name then
            learned = learned + 1
            local sch
            if T.GetRecipeSchematic then
                local good, res = pcall(T.GetRecipeSchematic, id, false)
                if good then sch = res end
            end
            local reags = {}
            for _, slot in ipairs(sch and sch.reagentSlotSchematics or {}) do
                local first = slot.reagents and slot.reagents[1]
                if slot.required ~= false and first and first.itemID then
                    reags[#reags + 1] = { id = first.itemID, n = slot.quantityRequired or 1 }
                end
            end
            local cd
            if T.GetRecipeCooldown then
                local good, res = pcall(T.GetRecipeCooldown, id)
                if good then cd = res end
            end
            StoreRecipe(p, prof, info.name, ModernDiff(info.relativeDifficulty),
                sch and sch.outputItemID, info.icon or (sch and sch.icon), reags, cd)
        end
    end
    Trace("guardadas " .. learned .. " recetas de " .. prof)
    Changed()
    return learned > 0
end

-- Devuelve true si se ha guardado alguna receta
local function ScanModern()
    local good, res = pcall(ScanModernUnsafe)
    if not good then
        Trace("ERROR: " .. tostring(res))
        geterrorhandler()(res)
        return false
    end
    return res
end

local function ScanTrade()
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then return ScanModern() end
    ScanRecipes({
        line = GetTradeSkillLine, count = GetNumTradeSkills, info = GetTradeSkillInfo,
        link = GetTradeSkillItemLink, icon = GetTradeSkillIcon,
        nReag = GetTradeSkillNumReagents, reag = GetTradeSkillReagentInfo,
        reagLink = GetTradeSkillReagentItemLink, cooldown = GetTradeSkillCooldown,
    })
end

local function ScanCraft()
    if not GetCraftInfo then return end
    ScanRecipes({
        line = GetCraftDisplaySkillLine, count = GetNumCrafts,
        info = function(i)
            local name, _, kind = GetCraftInfo(i)
            return name, kind
        end,
        link = GetCraftItemLink, icon = GetCraftIcon,
        nReag = GetCraftNumReagents, reag = GetCraftReagentInfo,
        reagLink = GetCraftReagentItemLink,
    })
end

-- Muchos eventos seguidos = un solo escaneo
local pending = {}
local function Queue(what, fn)
    if pending[what] then return end
    pending[what] = true
    C_Timer.After(0.5, function()
        pending[what] = nil
        fn()
    end)
end

---------------------------------------------------------------------------
-- Consultas
---------------------------------------------------------------------------
function ns.CharList()
    local list = {}
    for k in pairs(db.chars) do list[#list + 1] = k end
    table.sort(list)
    return list
end

-- Profesiones de un personaje, las principales primero
function ns.Profs(key)
    local c = db.chars[key or charKey]
    local list = {}
    for name, p in pairs(c and c.profs or {}) do
        local n = 0
        for _ in pairs(p.known or {}) do n = n + 1 end
        list[#list + 1] = { name = name, rank = p.rank or 0, max = p.max or 0, main = p.main, t = p.t, recipes = n }
    end
    table.sort(list, function(a, b)
        if a.main ~= b.main then return a.main and true or false end
        return a.name < b.name
    end)
    return list
end

-- Quién sabe hacer una receta: { key, name, class, diff }
function ns.Makers(prof, recipe)
    local list = {}
    for key, c in pairs(db.chars) do
        local p = c.profs and c.profs[prof]
        local d = p and p.known and p.known[recipe]
        if d then list[#list + 1] = { key = key, name = c.name or key, class = c.class, diff = d, rank = p.rank or 0 } end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Todas las recetas. filter = clave de personaje o nil; prof = profesión o nil
function ns.Index(filter, prof)
    local map, list = {}, {}
    for key, c in pairs(db.chars) do
        if not filter or filter == key then
            for pname, p in pairs(c.profs or {}) do
                if not prof or prof == pname then
                    for recipe in pairs(p.known or {}) do
                        local id = pname .. "\001" .. recipe
                        local e = map[id]
                        if not e then
                            local info = db.recipes[pname] and db.recipes[pname][recipe] or {}
                            e = { prof = pname, name = recipe, lower = recipe:lower(), item = info.id,
                                  icon = info.i or "Interface\\Icons\\INV_Misc_QuestionMark", reagents = info.r or {}, makers = 0 }
                            map[id] = e
                            list[#list + 1] = e
                        end
                        e.makers = e.makers + 1
                    end
                end
            end
        end
    end
    return list
end

-- Enfriamientos de toda la cuenta, los que antes acaban primero
function ns.Cooldowns()
    local list, now = {}, time()
    for key, c in pairs(db.chars) do
        for recipe, cd in pairs(c.cds or {}) do
            list[#list + 1] = { key = key, name = c.name or key, class = c.class, recipe = recipe, prof = cd.prof,
                                ready = cd.ready or 0, left = math.max(0, (cd.ready or 0) - now) }
        end
    end
    table.sort(list, function(a, b)
        if a.left ~= b.left then return a.left < b.left end
        return a.recipe < b.recipe
    end)
    return list
end

-- Nombre de un material; la API moderna solo da el identificador, así que se pide al juego
local GetItemInfo = GetItemInfo or (C_Item and C_Item.GetItemInfo)
function ns.ReagName(rg)
    if not rg.name and rg.id and GetItemInfo then
        rg.name = GetItemInfo(rg.id)      -- nil hasta que el cliente tenga el objeto en caché
    end
    return rg.name or ("Objeto " .. (rg.id or "?"))
end

-- Cuántas unidades de un objeto hay en la cuenta según Alijo (nil si Alijo no está)
function ns.Have(id)
    if not id or not AlijoDB or not AlijoDB.chars then return nil end
    local total = 0
    for _, c in pairs(AlijoDB.chars) do
        total = total + (c.bags and c.bags[id] or 0) + (c.bank and c.bank[id] or 0)
    end
    return total
end

-- Precio por unidad de un objeto en la subasta según Lonja (nil si Lonja no está o no lo ha visto)
function ns.Price(id)
    if id and Lonja and Lonja.Price then return (Lonja.Price(id)) end
end

local function AnnounceCooldowns()
    if db.settings.announce == false then return end
    local ready = {}
    for _, cd in ipairs(ns.Cooldowns()) do
        if cd.left == 0 then
            ready[#ready + 1] = "|c" .. Nexo.ClassHex(cd.class) .. cd.name .. "|r (" .. cd.recipe .. ")"
        end
    end
    if #ready > 0 then print(P .. "enfriamientos listos: " .. table.concat(ready, ", ") .. ".") end
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
        C_Timer.After(3, ScanSkills)
        C_Timer.After(6, AnnounceCooldowns)
    elseif event == "PLAYER_LEVEL_UP" then
        char.level = ...
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" or event == "TRADE_SKILL_LIST_UPDATE"
        or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "NEW_RECIPE_LEARNED" then
        Trace("evento " .. event)
        Queue("trade", ScanTrade)
        if event == "TRADE_SKILL_SHOW" then C_Timer.After(2, ScanTrade) end   -- por si la lista tarda en llegar
    elseif event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then
        Queue("craft", ScanCraft)
    else
        -- SKILL_LINES_CHANGED, CHAT_MSG_SKILL
        Queue("skills", ScanSkills)
    end
end)

local function Reg(e) pcall(ev.RegisterEvent, ev, e) end
Reg("ADDON_LOADED"); Reg("PLAYER_LOGIN"); Reg("PLAYER_LEVEL_UP")
Reg("SKILL_LINES_CHANGED"); Reg("CHAT_MSG_SKILL")
Reg("TRADE_SKILL_SHOW"); Reg("TRADE_SKILL_UPDATE"); Reg("CRAFT_SHOW"); Reg("CRAFT_UPDATE")
Reg("TRADE_SKILL_LIST_UPDATE"); Reg("TRADE_SKILL_DATA_SOURCE_CHANGED"); Reg("NEW_RECIPE_LEARNED")

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------
local function PrintSummary()
    local profs = ns.Profs()
    if #profs == 0 then
        print(P .. "todavía no hay profesiones registradas en este personaje.")
        return
    end
    print(P .. "profesiones de " .. (char.name or charKey) .. ":")
    for _, p in ipairs(profs) do
        print(("  %s  |cffffffff%d/%d|r  ·  %s"):format(p.name, p.rank, p.max, Nexo.Plural(p.recipes, "receta", "recetas")))
    end
    for _, cd in ipairs(ns.Cooldowns()) do
        print("  |c" .. Nexo.ClassHex(cd.class) .. cd.name .. "|r · " .. cd.recipe .. ": " ..
            (cd.left == 0 and "|cff66ff66listo|r" or ("en " .. Nexo.Dur(cd.left))))
    end
end

local function PrintSearch(text)
    local low, n = text:lower(), 0
    for _, e in ipairs(ns.Index(nil, nil)) do
        if e.lower:find(low, 1, true) then
            local names = {}
            for _, m in ipairs(ns.Makers(e.prof, e.name)) do
                names[#names + 1] = "|c" .. Nexo.ClassHex(m.class) .. m.name .. "|r"
            end
            n = n + 1
            if n <= 15 then print("  " .. e.name .. " |cff888888(" .. e.prof .. ")|r: " .. table.concat(names, ", ")) end
        end
    end
    if n == 0 then
        print(P .. "nadie sabe fabricar nada que contenga \"" .. text .. "\".")
    elseif n > 15 then
        print("  ... y " .. (n - 15) .. " más.")
    end
end

SLASH_OFICIO1 = "/oficio"
SlashCmdList.OFICIO = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local low = msg:lower()
    if low == "avisos" then
        db.settings.announce = (db.settings.announce == false)
        print(P .. "aviso de enfriamientos al entrar " .. (db.settings.announce and "activado" or "desactivado") .. ".")
    elseif low == "minimapa" then
        print(P .. "botón del minimapa (compartido, Nexo) " .. (Nexo.ToggleMinimap() and "oculto" or "visible") .. ".")
    elseif low == "reset confirmar" then
        db.chars[charKey] = nil
        InitDB()
        ScanSkills()
        print(P .. "registro de " .. charKey .. " borrado.")
    elseif low == "reset" then
        print(P .. "esto borrará las profesiones y recetas guardadas de " .. charKey .. ". Escribe |cffffff00/oficio reset confirmar|r para hacerlo.")
    elseif low:match("^olvidar%s+%S") then
        local who = low:match("^olvidar%s+(.+)$")
        local found
        for key, c in pairs(db.chars) do
            if key ~= charKey and ((c.name or ""):lower() == who or key:lower() == who) then found = key end
        end
        if found then
            db.chars[found] = nil
            print(P .. "profesiones de " .. found .. " borradas.")
            Changed()
        else
            print(P .. "no encuentro a otro personaje llamado \"" .. who .. "\".")
        end
    elseif low == "diag" then
        ScanTrade()
        print(P .. "últimos escaneos (con la ventana de la profesión abierta):")
        for _, line in ipairs(db.debug or {}) do print("  " .. line) end
    elseif low == "ayuda" or low == "help" then
        print(P .. "comandos:")
        print("  |cffffff00/oficio|r - abrir/cerrar la ventana")
        print("  |cffffff00/oficio <texto>|r - quién sabe fabricar algo con ese nombre")
        print("  |cffffff00/oficio avisos|r - activar/desactivar el aviso de enfriamientos al entrar")
        print("  |cffffff00/oficio minimapa|r - mostrar/ocultar el botón del minimapa")
        print("  |cffffff00/oficio olvidar <personaje>|r - borrar lo guardado de otro personaje")
        print("  |cffffff00/oficio reset|r - borrar lo guardado de este personaje")
        print("  |cffffff00/oficio diag|r - mostrar qué ha leído de la profesión abierta")
    elseif msg ~= "" then
        if ns.OpenSearch then ns.OpenSearch(msg) else PrintSearch(msg) end
    else
        if ns.Toggle then ns.Toggle() else PrintSummary() end
    end
end
