---
name: nexo-traducido
description: Todo texto que vea el jugador en los addons de este repositorio (Nexo, Tesorero, Bitácora, Alijo, Senda, Oficio, Lonja) tiene que poder salir en español y en inglés. Úsalo SIEMPRE al escribir o cambiar Lua en cualquiera de ellos: texto nuevo en print/SetText/tooltips, nombre de un addon, de una ventana o de un subcomando de barra (/addon algo), y cuando se pida traducir, revisar el idioma o arreglar algo que "no cambia de idioma", aunque el usuario no use la palabra "traducir". Explica el mecanismo (Tr, N.Dict, N.Cmd), cuándo N.lang todavía no es de fiar, y qué repasar antes de dar un texto por terminado.
---

# Nexo traducido

Este repositorio tiene un **núcleo**, Nexo, y addons que dependen de él. El idioma es uno
solo para todos (`Nexo.lang`, "es" o "en"), elegido en `/nexo ajustes` (o `/nexo settings`)
y guardado en `NexoDB.lang`. Ningún texto que vea el jugador puede quedarse fijo en español:
tiene que pasar por el mecanismo de traducción para que cambie con esa preferencia.

Por qué importa: un texto fijo en español es invisible hasta que alguien juega en inglés, y
entonces parece que el cambio de idioma "no funciona" aunque el resto sí traduzca. Ya ha
pasado dos veces en este repositorio: los nombres de los subcomandos (`/alijo olvidar` sin su
versión `/alijo forget`) y los nombres de los addons en el menú del minimapa (solo Bitácora
se tradujo a Logbook; Alijo, Lonja, Oficio, Senda, Tesorero y Vuelo se quedaron en español).

## El mecanismo

- **Texto normal**: escríbelo en español y envuélvelo en `Tr("...")` (local a `Nexo.T` en
  cada archivo). En español se devuelve igual; en inglés busca la traducción.
- **Traducción al inglés**: cada addon la añade con `Nexo.Dict({ ["texto en español"] =
  "texto en inglés" })`, normalmente al principio de su `Core.lua`. Si falta la entrada,
  `Tr()` devuelve el español sin avisar — por eso hay que acordarse de añadirla, no hay
  error que lo señale.
- **Nombre de un subcommando de barra** (`/addon algo`, no el propio `/addon`): no lo
  compares ni lo escribas como texto fijo. Usa `N.Cmd("espacio_de_nombres", "clave")`
  (definido en `Nexo/Locale.lua`): una clave interna estable (`"minimap"`, `"reset"`...) que
  da la palabra en español o en inglés según `N.lang`. Si el addon es nuevo, añade su tabla
  de comandos ahí, en los dos idiomas.
- **Nombre del propio addon** (el que aparece en el menú del minimapa y en el título de su
  ventana): también es texto, va en `Tr("Alijo")` / `title = Tr("Alijo")`, con su traducción
  en el `Dict` del addon (`["Alijo"] = "Stash"`). No lo trates como si fuera una marca que no
  se toca: en este repositorio los nombres de los addons son palabras españolas con
  significado (Alijo, Lonja, Oficio, Senda, Tesorero, Vuelo) y se traducen igual que el resto.

## N.lang no siempre es de fiar nada más cargarse el archivo

`Nexo/Locale.lua` calcula `N.lang` en cuanto se carga, pero en este cliente (WoW Forever)
`NexoDB` puede no estar disponible todavía en ese momento: por eso `Nexo/Core.lua` vuelve a
calcularlo con `N.RefreshLang()` dentro de `InitDB()`, que corre en `ADDON_LOADED` —el
momento en que `NexoDB` sí es de fiar.

Esto importa para dónde escribes un `Tr(...)` o lees `N.lang`/`N.Cmd(...)`:

- **Dentro de una función** que se llama más tarde (al abrir una ventana, al escribir un
  comando, en un evento) → siempre correcto, da igual el addon: para cuando se llama, el
  idioma ya está bien calculado (los addons dependen de Nexo, así que su propio
  `ADDON_LOADED`, y por tanto `N.RefreshLang()`, ya ha pasado).
- **Fuera de una función, en una tabla o variable que se crea nada más cargar el archivo**
  (`local FILAS = { nombre = Tr("Exportar / importar") }`, `local OPCIONES = { { "k",
  Tr("Texto") } }`): en los addons que no son Nexo da igual, por la misma razón de arriba.
  **Solo en los propios archivos de Nexo** (`Nexo/Core.lua`, `Nexo/UI.lua`) puede ejecutarse
  antes de que `N.RefreshLang()` haya corrido. Si necesitas un texto así ahí, no lo guardes
  ya traducido: guarda la clave en español y tradúcelo cada vez que se use (como
  `DATA_ROW.key` / `SETTINGS_ROW.key` en `Nexo/UI.lua`, traducidos en `ShowMenu()` cada vez
  que se abre el menú, no una sola vez al cargar).

## Antes de dar un texto o comando por terminado

1. ¿Está envuelto en `Tr(...)`? ¿Tiene su entrada en algún `Nexo.Dict({...})` (del propio
   addon, o de Nexo si es un texto compartido)?
2. Si es un subcomando de barra, ¿usa `N.Cmd(espacio, clave)` en vez de la palabra fija, en
   la comparación **y** en el texto de ayuda/los avisos que lo mencionan?
3. Si el texto está en una tabla o variable fuera de cualquier función, ¿en qué archivo
   está? Si es de Nexo, ¿se traduce al usarse o se quedó fijada al cargar?
4. Compruébalo en los dos idiomas. Sin el juego a mano, se puede simular Lua suelto: cargar
   `Nexo/Locale.lua` y `Nexo/Core.lua` con `NexoDB = { lang = "en" }` ya puesto, y llamar a
   `Nexo.T("tu texto")` o `Nexo.Cmd("addon", "clave")` para ver qué devuelven.

## Al informar al usuario

Di qué textos o comandos nuevos tradujiste y dónde quedó la entrada del diccionario. Si
dejaste algo sin traducir porque no era parte del encargo, dilo en una línea en vez de
arreglarlo sin que te lo pidan.
