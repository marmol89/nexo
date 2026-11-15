---
name: nexo-sin-duplicados
description: Evita el código duplicado entre los addons de WoW de este repositorio (Nexo, Tesorero, Bitácora, Alijo, Senda, Oficio, Lonja). Úsalo SIEMPRE antes de escribir o cambiar Lua en cualquiera de ellos, al crear un addon nuevo, al añadir una ventana, lista, tooltip, comando, formato de texto o manejo de eventos, y cuando se pida revisar, limpiar o refactorizar código repetido, aunque el usuario no mencione la palabra "duplicado". Dice qué ofrece ya el núcleo Nexo, cuándo y cómo mover código a él, e incluye un detector que señala la duplicación nueva.
---

# Nexo sin duplicados

Este repositorio tiene un núcleo, **Nexo**, y seis addons que dependen de él, en carpetas
`Nexo_<nombre>` (`Nexo_Tesorero`, `Nexo_Alijo`...). Un addon nuevo se llama igual. Todo lo que
necesiten dos addons vive en Nexo y los addons lo usan desde ahí.

Por qué importa: cada addon se escribió copiando el anterior, y las copias se fueron
separando. Un arreglo hecho en una copia no llegaba a las demás (el formato de dinero
estaba en dos sitios, el «hace 5 min» en otros dos, el enganche de tooltips en dos más), y
cada copia era un sitio más donde podía fallar una API del cliente. Con una sola versión,
un arreglo vale para todos.

## Antes de escribir código

1. **Mira qué hay ya en Nexo.** La cabecera de `Nexo/Core.lua` lista las funciones del
   núcleo y `Nexo/UI.lua` documenta las piezas de interfaz encima de cada una. Esos dos
   archivos mandan; la tabla de abajo es solo un mapa para orientarse y puede quedarse atrás.
2. **Mira cómo lo resuelve otro addon.** Si lo que vas a escribir se parece a algo de otro
   addon (una lista con búsqueda, un panel de detalle, un resumen para el minimapa), léelo
   antes. Si ya existe ahí, no lo copies: pásalo a Nexo y úsalo desde los dos.
3. **Escribe solo lo que es propio del addon**: sus datos, sus reglas y su aspecto.

## Qué ofrece Nexo

| Necesitas | Usa |
|---|---|
| Duraciones, números, fechas, plurales | `Nexo.Dur`, `Num`, `DayKey`, `DayKeyToTime`, `MidnightDaysAgo`, `DayLabel`, `Plural` |
| Dinero con iconos, «hace 5 min» | `Nexo.Money(cobre, tamaño, full)`, `Nexo.Ago(hora, textoSiNunca)` |
| Colores de clase y de calidad | `Nexo.ClassHex`, `ClassRGB`, `QualityRGB` |
| Id de un enlace de objeto, claves ordenadas, nombre sin reino | `Nexo.ItemID`, `Keys`, `ShortName` |
| Personaje actual y registro de la cuenta | `Nexo.CharKey`, `Char`, `CharList` |
| Tabla de personajes del propio addon (`db.chars`) | `Nexo.InitChar(chars, nuevo)`, `EachChar(chars, filtro, fn)`, `FindChar(chars, nombre, menosEste)` |
| Periodos de un resumen | `Nexo.PERIODS`, `Nexo.PERIOD_DAYS` |
| Registrar eventos sin fallar si no existen | `Nexo.Reg(marco, ...)` |
| Juntar muchos avisos seguidos en una llamada | `Nexo.Debounce(clave, espera, fn, ...)` |
| Reloj de juego y `/played` | `Nexo.OnTick(fn)`, `OnPlayed(fn)`, `RequestPlayed()` |
| Líneas en el tooltip de los objetos | `Nexo.OnItemTooltip(fn)` — `fn(tip, id)` devuelve `true` si añadió algo |
| Tooltip de un objeto, enlazarlo en el chat | `Nexo.ItemTooltip(marco, id)`, `Nexo.LinkItem(id)` |
| Botón del minimapa | `Nexo.Register(def)` |
| Que los datos del addon se puedan exportar e importar | `data = "MiAddonDB"` en `Nexo.Register`; el resto lo hace Nexo (`/nexo datos`) |
| Tabla a texto y vuelta | `Nexo.Serialize(t)`, `Nexo.Deserialize(s)` |
| Heredar los datos del addon de antes de llamarse `Nexo_<nombre>` | `if Nexo.Antiguo(ADDON) then return end` al principio de cada archivo, y el nombre antiguo en `OptionalDeps`. Solo en los seis addons que existían entonces; uno nuevo no lo necesita |
| Ventana con cabecera, sonido al abrir y refresco periódico | `K.Window` → `main:OnOpen()`, `main:OnClose()`, `main:Every(seg, fn)` |
| Selector de personaje y su texto | `K.CharButton` → `charBtn:SetChar(clave, datos)` |
| Botones excluyentes (periodos, sitios) | `K.Tabs(padre, defs, ancho, alElegir)` → `tabs:Select(clave)` |
| Cuadro de búsqueda | `K.Search` |
| Lista con desplazamiento, selección, tooltip y Mayús+clic | `K.List` → `list:SetData`, `:Update`, `:Reset`; cabeceras con `K.Sorter` |
| Panel de detalle | `K.DetailHead` (icono y nombre), `K.Lines` (líneas con barra) |
| Tarjetas de resumen, gráfico de barras, datos sueltos | `K.Cards`, `K.Chart`, `K.StatGrid` |
| Pie de ventana | `K.Footer` |
| Lo básico | `K.Panel`, `K.Button`, `K.Card`, `K.SectionTitle`, `K.Text`, `K.Tex` |

## Cuándo va algo a Nexo

- **Lo usan (o lo van a usar) dos addons** → va a Nexo. No esperes a la tercera copia: la
  segunda ya es la que se desincroniza.
- **Se parece pero cambia un detalle** (un color, un texto, una espera, qué columna empieza
  ordenada) → una sola función en Nexo con ese detalle como parámetro. `K.Sorter` recibe
  el color apagado y `Nexo.Ago` el texto para «nunca»; por eso sirven a todos.
- **Solo tiene sentido en un addon** (clasificar un movimiento de oro, escanear la subasta)
  → se queda en ese addon.
- **Un addon necesita datos de otro** → no copies su lógica: usa la tabla global que el otro
  publica (`Lonja.Price`, `Alijo.Have`) comprobando que existe, porque puede no estar instalado.
  Si el dato que necesitas no está publicado, añádelo a esa tabla en el addon que lo guarda.

No es duplicación que cada addon tenga sus propias `Refresh`, `Toggle`, `OnInit`, `InitDB`
u `OnDataChanged`: es la misma forma con contenido distinto. Tampoco lo son las tablas de
colores del tema, las constantes de tamaño de cada ventana ni el arranque de eventos de cada
`Core.lua`; el detector los señala y están en la base por eso.

## Cómo mover algo a Nexo

1. Escribe la función en `Nexo/Core.lua` (lógica) o `Nexo/UI.lua` (interfaz), con un
   comentario de una o dos líneas que diga qué recibe y qué devuelve.
2. Añádela a la cabecera de `Nexo/Core.lua` y a la tabla de funciones del `README.md`.
3. Cambia **todos** los addons que tenían su copia y borra las copias. Una copia que se
   queda es peor que no haber movido nada: parece que ya está resuelto.
4. Conserva el comportamiento. Si las copias diferían, decide cuál es el correcto y dilo al
   usuario; no lo cambies en silencio.
5. Sube `N.version` en `Nexo/Core.lua` y la versión de `Nexo/Nexo.toc`.

## Comprobar que no entra duplicación nueva

Ejecuta el detector desde la raíz del repositorio al terminar cualquier cambio en los `.lua`:

```bash
node .claude/skills/nexo-sin-duplicados/scripts/duplicados.js .
```

Compara los addons entre sí y avisa de los bloques de 5 o más líneas iguales. Hay una
**base** guardada (`scripts/duplicados.base.json`) con la duplicación que ya existía, así
que solo marca como `NUEVO` lo que no estaba. Sale con código 1 si hay bloques nuevos.

- **Sale algo `NUEVO`** → es código que acabas de repetir. Muévelo a Nexo antes de dar el
  trabajo por terminado. Si de verdad no es duplicación (dos listas que coinciden por
  casualidad), explícaselo al usuario en vez de callarlo.
- **Has quitado duplicación antigua** → guarda la base para que no vuelva a colarse:

  ```bash
  node .claude/skills/nexo-sin-duplicados/scripts/duplicados.js . --guardar-base
  ```

  No guardes la base para hacer desaparecer un `NUEVO`: eso esconde el problema.
- **Quieres ver todo lo pendiente** (para una limpieza) → añade `--todo`. El resumen por
  parejas de addons dice dónde está el grueso; la lista de funciones con el mismo nombre
  en varios addons es una pista de por dónde seguir, no una prueba.

El detector compara texto: no ve dos funciones que hacen lo mismo escritas de forma
distinta. Por eso el primer paso sigue siendo leer Nexo y el addon vecino antes de escribir.

## Al informar al usuario

Di qué has reutilizado de Nexo, qué has movido a Nexo (y desde qué addons) y qué ha dicho
el detector. Si queda duplicación que no has tocado porque no era parte del encargo, dilo
en una línea en vez de arreglarla sin que te lo pidan.
