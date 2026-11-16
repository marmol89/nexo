#!/usr/bin/env node
// Servidor MCP (stdio, sin dependencias) para CurseForge de World of Warcraft.
// Usa la API de autor (wow.curseforge.com/api) con el token CF_API_KEY.
//
// Herramientas:
//   cf_game_versions  lista las versiones de juego que acepta CurseForge
//   cf_upload_file    sube un .zip como nueva versión de un proyecto
//
// Lo que la API pública NO permite (por eso no hay herramienta para ello):
// editar la descripción, imágenes, categorías o enlaces de la página del proyecto,
// ni borrar o modificar archivos ya subidos. Eso se hace en authors.curseforge.com.
//
// Variables de entorno:
//   CF_API_KEY     token de https://authors.curseforge.com/account/api-tokens
//   CF_PROJECT_ID  número de proyecto (opcional si se pasa project_id en cada llamada)

import { readFile, stat } from "node:fs/promises";
import { basename, extname, resolve } from "node:path";
import { createInterface } from "node:readline";

const API = "https://wow.curseforge.com/api";
const SERVER = { name: "curseforge", version: "1.0.0" };
const PROTOCOL = "2024-11-05";

const apiKey = process.env.CF_API_KEY || "";
const defaultProject = process.env.CF_PROJECT_ID || "";

const tools = [
  {
    name: "cf_game_versions",
    description:
      "Lista las versiones de juego de WoW que acepta CurseForge (id y nombre). " +
      "Úsala para saber qué nombre exacto poner en versiones_juego de cf_upload_file.",
    inputSchema: {
      type: "object",
      properties: {
        filtro: { type: "string", description: "Texto que debe contener el nombre, p. ej. '11.' (opcional)" },
      },
      additionalProperties: false,
    },
  },
  {
    name: "cf_upload_file",
    description:
      "Sube un .zip como nueva versión (archivo) de un proyecto de CurseForge. " +
      "Es pública e irreversible desde aquí: úsala solo cuando el usuario lo pida.",
    inputSchema: {
      type: "object",
      properties: {
        ruta: { type: "string", description: "Ruta al .zip (absoluta o relativa al directorio de trabajo)" },
        nombre: { type: "string", description: "Nombre visible de la versión, p. ej. 'Nexo 1.6.1'" },
        versiones_juego: {
          type: "array",
          items: { type: "string" },
          description: "Nombres exactos de versión de juego, p. ej. ['11.1.0']. Ver cf_game_versions.",
        },
        changelog: { type: "string", description: "Notas de cambios" },
        formato_changelog: {
          type: "string",
          enum: ["markdown", "html", "text"],
          description: "Formato de las notas. Por defecto markdown.",
        },
        tipo: { type: "string", enum: ["release", "beta", "alpha"], description: "Por defecto release." },
        project_id: { type: "string", description: "Número de proyecto. Por defecto CF_PROJECT_ID." },
      },
      required: ["ruta", "nombre", "versiones_juego"],
      additionalProperties: false,
    },
  },
];

async function cfFetch(path, init = {}) {
  if (!apiKey) throw new Error("Falta CF_API_KEY en el entorno del servidor MCP.");
  const res = await fetch(API + path, {
    ...init,
    headers: { "X-Api-Token": apiKey, ...(init.headers || {}) },
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`CurseForge respondió ${res.status}: ${text.slice(0, 500)}`);
  return text;
}

async function gameVersions() {
  return JSON.parse(await cfFetch("/game/versions"));
}

async function cfGameVersions({ filtro = "" }) {
  const lista = (await gameVersions())
    .filter((v) => !filtro || v.name.includes(filtro))
    .sort((a, b) => b.id - a.id);
  if (lista.length === 0) return "Ninguna versión de juego coincide.";
  return lista.map((v) => `${v.id}\t${v.name}`).join("\n");
}

async function cfUploadFile(args) {
  const projectId = args.project_id || defaultProject;
  if (!projectId) throw new Error("Falta project_id o la variable CF_PROJECT_ID.");

  const ruta = resolve(args.ruta);
  if (extname(ruta).toLowerCase() !== ".zip") throw new Error("Solo se suben archivos .zip.");
  const info = await stat(ruta);

  const todas = await gameVersions();
  const ids = [];
  const noReconocidas = [];
  for (const nombre of args.versiones_juego) {
    const v = todas.find((x) => x.name === nombre);
    if (v) ids.push(v.id);
    else noReconocidas.push(nombre);
  }
  if (noReconocidas.length > 0) {
    throw new Error(
      `Versión(es) de juego no reconocidas: ${noReconocidas.join(", ")}. Usa cf_game_versions para ver los nombres.`,
    );
  }

  const metadata = {
    changelog: args.changelog || "",
    changelogType: args.formato_changelog || "markdown",
    displayName: args.nombre,
    gameVersions: ids,
    releaseType: args.tipo || "release",
  };

  const form = new FormData();
  form.append("metadata", JSON.stringify(metadata));
  form.append("file", new Blob([await readFile(ruta)], { type: "application/zip" }), basename(ruta));

  const body = await cfFetch(`/projects/${encodeURIComponent(projectId)}/upload-file`, {
    method: "POST",
    body: form,
  });
  return `Subido ${basename(ruta)} (${(info.size / 1024).toFixed(0)} KB) como "${args.nombre}".\nRespuesta: ${body}`;
}

const handlers = { cf_game_versions: cfGameVersions, cf_upload_file: cfUploadFile };

function send(msg) {
  process.stdout.write(JSON.stringify(msg) + "\n");
}
function reply(id, result) {
  send({ jsonrpc: "2.0", id, result });
}
function fail(id, code, message) {
  send({ jsonrpc: "2.0", id, error: { code, message } });
}

async function handle(msg) {
  if (msg.id === undefined) return; // notificaciones (p. ej. notifications/initialized)
  switch (msg.method) {
    case "initialize":
      return reply(msg.id, {
        protocolVersion: msg.params?.protocolVersion || PROTOCOL,
        capabilities: { tools: {} },
        serverInfo: SERVER,
      });
    case "ping":
      return reply(msg.id, {});
    case "tools/list":
      return reply(msg.id, { tools });
    case "tools/call": {
      const handler = handlers[msg.params?.name];
      if (!handler) return fail(msg.id, -32602, `Herramienta desconocida: ${msg.params?.name}`);
      try {
        const text = await handler(msg.params.arguments || {});
        return reply(msg.id, { content: [{ type: "text", text }] });
      } catch (e) {
        return reply(msg.id, { content: [{ type: "text", text: String(e.message || e) }], isError: true });
      }
    }
    default:
      return fail(msg.id, -32601, `Método no soportado: ${msg.method}`);
  }
}

createInterface({ input: process.stdin }).on("line", (line) => {
  if (!line.trim()) return;
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    return;
  }
  handle(msg).catch((e) => {
    if (msg.id !== undefined) fail(msg.id, -32603, String(e));
  });
});
