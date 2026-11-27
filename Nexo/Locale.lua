-- Nexo: idioma de los textos
--
-- El idioma sale del cliente (GetLocale): esES y esMX usan español; cualquier otro, inglés.
-- Los textos del código están escritos en español. Cada texto que se muestra va dentro de Tr:
--   Tr("Todos los personajes")   -> el texto en el idioma del juego
-- En inglés, cada addon añade sus traducciones con Nexo.Dict (texto en español -> inglés):
--   Nexo.Dict({ ["Todos los personajes"] = "All characters" })
-- Si falta una traducción, se muestra el texto en español.
-- Locale.lua se carga antes que Core.lua, que es quien crea la tabla global
Nexo = Nexo or {}
local N = Nexo

local function AutoLang()
    local locale = GetLocale and GetLocale() or "enUS"
    return (locale == "esES" or locale == "esMX") and "es" or "en"
end

-- Calcula N.langPref/N.lang a partir de lo guardado en NexoDB.lang ("auto", "es" o "en").
-- Se llama aquí abajo para tener algo válido cuanto antes (los textos que se crean al cargar
-- Locale.lua y Core.lua ya lo usan), y Core.lua la vuelve a llamar en ADDON_LOADED: en este
-- cliente NexoDB puede no estar todavía disponible en este primer cálculo, aunque sí lo esté más
-- tarde en ADDON_LOADED, que es cuando de verdad hay que fiarse de la preferencia guardada.
local function RecomputeLang()
    local pref = NexoDB and NexoDB.lang
    N.langPref = (pref == "es" or pref == "en") and pref or "auto"
    N.lang = N.langPref == "auto" and AutoLang() or N.langPref
end
N.RefreshLang = RecomputeLang
RecomputeLang()

local dict = {}

-- Añade traducciones al inglés (tabla: texto en español -> texto en inglés)
function N.Dict(t)
    for k, v in pairs(t) do dict[k] = v end
end

-- Texto en el idioma del juego. En español, el mismo texto; en inglés, su traducción
function N.T(s)
    if N.lang == "es" then return s end
    return dict[s] or s
end
local Tr = N.T

-- Nombres de los subcomandos de cada addon en cada idioma (cambian con el idioma elegido).
-- Cada addon tiene su propia tabla (nexo, alijo, bitacora, lonja, oficio, senda, tesorero, vuelo);
-- dentro, una clave en español ("minimapa") sirve de nombre interno estable para pedir la traducción.
local CMDS = {
    es = {
        nexo = { settings = "ajustes", data = "datos", export = "exportar", import = "importar", minimap = "minimapa", errors = "errores", clear = "borrar", help = "ayuda" },
        alijo = { tooltip = "tooltip", minimap = "minimapa", forget = "olvidar", help = "ayuda" },
        bitacora = { reset = "reset", resetConfirm = "reset confirmar", import = "importar", removeEstimated = "quitar estimadas", minimap = "minimapa", help = "ayuda" },
        lonja = { scan = "escanear", stop = "parar", auto = "auto", buy = "comprar", list = "lista", remove = "quitar", deals = "gangas", threshold = "umbral", tooltip = "tooltip", minimap = "minimapa", reset = "reset", resetConfirm = "reset confirmar", diag = "diag", help = "ayuda" },
        oficio = { announce = "avisos", minimap = "minimapa", reset = "reset", resetConfirm = "reset confirmar", forget = "olvidar", diag = "diag", help = "ayuda" },
        senda = { reset = "reset", resetConfirm = "reset confirmar", announce = "avisos", minimap = "minimapa", help = "ayuda" },
        tesorero = { reset = "reset", resetConfirm = "reset confirmar", minimap = "minimapa", help = "ayuda" },
        vuelo = { center = "centro", chat = "chat", minimap = "minimapa", help = "ayuda" },
    },
    en = {
        nexo = { settings = "settings", data = "data", export = "export", import = "import", minimap = "minimap", errors = "errors", clear = "clear", help = "help" },
        alijo = { tooltip = "tooltip", minimap = "minimap", forget = "forget", help = "help" },
        bitacora = { reset = "reset", resetConfirm = "reset confirm", import = "import", removeEstimated = "remove estimated", minimap = "minimap", help = "help" },
        lonja = { scan = "scan", stop = "stop", auto = "auto", buy = "buy", list = "list", remove = "remove", deals = "deals", threshold = "threshold", tooltip = "tooltip", minimap = "minimap", reset = "reset", resetConfirm = "reset confirm", diag = "diag", help = "help" },
        oficio = { announce = "alerts", minimap = "minimap", reset = "reset", resetConfirm = "reset confirm", forget = "forget", diag = "diag", help = "help" },
        senda = { reset = "reset", resetConfirm = "reset confirm", announce = "alerts", minimap = "minimap", help = "help" },
        tesorero = { reset = "reset", resetConfirm = "reset confirm", minimap = "minimap", help = "help" },
        vuelo = { center = "center", chat = "chat", minimap = "minimap", help = "help" },
    },
}

-- Nombre de un subcomando en el idioma en uso: N.Cmd("lonja", "minimap") -> "minimapa" o "minimap"
function N.Cmd(ns, name)
    local t = (CMDS[N.lang] or CMDS.es)[ns] or CMDS.es[ns]
    return t and t[name]
end
