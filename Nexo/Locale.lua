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
N.lang = (locale == "esES" or locale == "esMX") and "es" or "en"

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
