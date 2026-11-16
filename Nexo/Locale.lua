-- Nexo: idioma de los textos
--
-- El idioma sale del cliente (GetLocale): esES y esMX usan español; cualquier otro, inglés.
-- Los textos del código están escritos en español. Cada texto que se muestra va dentro de Tr:
--   Tr("Todos los personajes")   -> el texto en el idioma del juego
-- En inglés, cada addon añade sus traducciones con Nexo.Dict (texto en español -> inglés):
--   Nexo.Dict({ ["Todos los personajes"] = "All characters" })
-- Si falta una traducción, se muestra el texto en español.
local N = Nexo

local locale = GetLocale and GetLocale() or "enUS"
local auto = (locale == "esES" or locale == "esMX") and "es" or "en"

-- Preferencia de Ajustes: "auto", "es" o "en". Se lee aquí, antes de cargar los demás archivos,
-- para que los textos que se crean al cargar salgan ya en el idioma elegido.
local pref = NexoDB and NexoDB.lang
N.langPref = (pref == "es" or pref == "en") and pref or "auto"
N.lang = N.langPref == "auto" and auto or N.langPref

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
