# Servidor MCP de CurseForge (WoW)

Permite a Claude listar versiones de juego y subir un `.zip` como nueva versión de Nexo en CurseForge.

## Configurar

1. Crea un token en <https://authors.curseforge.com/account/api-tokens>.
2. Define las variables de entorno (en Windows, en tu perfil de usuario):

   ```bash
   setx CF_API_KEY "tu-token"
   setx CF_PROJECT_ID "numero-del-proyecto"
   ```

3. Reinicia Claude Code. El archivo [`.mcp.json`](../../.mcp.json) de la raíz ya registra el servidor `curseforge`.

El token nunca se guarda en el repositorio: `.mcp.json` solo lee `${CF_API_KEY}` del entorno.

## Herramientas

- `cf_game_versions`: lista las versiones de juego aceptadas (nombre e id).
- `cf_upload_file`: sube un `.zip` con nombre, notas, versiones de juego, tipo (`release`, `beta`, `alpha`) y project_id opcional. Pide confirmación antes de ejecutarse.

## Límites

La API de autor de CurseForge solo sirve para subir archivos. **No permite** editar la descripción, imágenes, categorías ni enlaces de la página del proyecto, ni modificar o borrar archivos ya subidos. Esos cambios se hacen en <https://authors.curseforge.com>.
